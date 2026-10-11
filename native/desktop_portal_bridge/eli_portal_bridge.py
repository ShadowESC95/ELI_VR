#!/usr/bin/env python3
"""ELI VR Linux Wayland capture adapter.

XDG Desktop Portal ScreenCast -> PipeWire -> GStreamer -> loopback RGBA.
The transport binds before portal negotiation so Godot can distinguish a live
local adapter from a missing process. No remote network access is used.
"""
import argparse, os, socket, struct, threading
from pathlib import Path

import dbus
from dbus.mainloop.glib import DBusGMainLoop
import gi
gi.require_version("GLib", "2.0")
gi.require_version("Gst", "1.0")
gi.require_version("GstVideo", "1.0")
from gi.repository import GLib, Gst, GstVideo

PORTAL_BUS = "org.freedesktop.portal.Desktop"
PORTAL_PATH = "/org/freedesktop/portal/desktop"
SCREENCAST = "org.freedesktop.portal.ScreenCast"
REQUEST = "org.freedesktop.portal.Request"
PROPERTIES = "org.freedesktop.DBus.Properties"

class Bridge:
    def __init__(self, bind, width, fps, token_file):
        self.bind = bind
        self.width = width
        self.fps = fps
        self.token_file = Path(token_file).expanduser()
        self.client = None
        self.client_lock = threading.Lock()
        self.loop = GLib.MainLoop()
        self.seq = 0
        self.session = None
        self.pipeline = None
        self.listener = None
        self.bus = None
        self.portal = None
        self.portal_version = 0
        self.source_size = None

    def open_listener(self):
        host, port_s = self.bind.rsplit(':', 1)
        if host not in ('127.0.0.1', 'localhost'):
            raise SystemExit('ELI desktop bridge refuses non-loopback bind')
        self.listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.listener.bind(('127.0.0.1', int(port_s)))
        self.listener.listen(2)
        print(f"ELI portal bridge listening on 127.0.0.1:{port_s}", flush=True)

    def serve(self):
        while True:
            c, addr = self.listener.accept()
            c.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            with self.client_lock:
                if self.client:
                    try: self.client.close()
                    except OSError: pass
                self.client = c
            print(f"ELI portal: Godot/client connected {addr}", flush=True)

    def init_portal(self):
        self.bus = dbus.SessionBus()
        self.portal = self.bus.get_object(PORTAL_BUS, PORTAL_PATH)
        props = dbus.Interface(self.portal, PROPERTIES)
        try:
            self.portal_version = int(props.Get(SCREENCAST, 'version'))
        except Exception:
            self.portal_version = 0
        print(f"ELI portal: ScreenCast interface version={self.portal_version}", flush=True)

    def token(self, prefix):
        self.seq += 1
        return f"eli_{prefix}_{os.getpid()}_{self.seq}"

    def request_path(self, token):
        sender = self.bus.get_unique_name()[1:].replace('.', '_')
        return f"/org/freedesktop/portal/desktop/request/{sender}/{token}"

    def request(self, method_name, callback, args=(), options=None):
        options = dict(options or {})
        handle_token = self.token("req")
        options['handle_token'] = handle_token
        path = self.request_path(handle_token)
        self.bus.add_signal_receiver(
            callback, signal_name='Response', dbus_interface=REQUEST, path=path
        )
        iface = dbus.Interface(self.portal, SCREENCAST)
        getattr(iface, method_name)(*(tuple(args) + (dbus.Dictionary(options, signature='sv'),)))

    def start_portal(self):
        session_token = self.token("session")
        self.request('CreateSession', self.on_create, options={'session_handle_token': session_token})

    def on_create(self, response, results):
        if int(response) != 0:
            print(f"ELI portal: CreateSession rejected ({int(response)})", flush=True)
            self.loop.quit(); return
        self.session = results['session_handle']
        options = {'multiple': False, 'types': dbus.UInt32(1), 'cursor_mode': dbus.UInt32(2)}
        if self.portal_version >= 4:
            options['persist_mode'] = dbus.UInt32(2)
            if self.token_file.exists():
                token = self.token_file.read_text().strip()
                if token:
                    options['restore_token'] = token
        self.request('SelectSources', self.on_select, args=(self.session,), options=options)

    def on_select(self, response, results):
        if int(response) != 0:
            print(f"ELI portal: SelectSources rejected ({int(response)})", flush=True)
            self.token_file.unlink(missing_ok=True)
            self.loop.quit(); return
        print("ELI portal: source selection accepted", flush=True)
        self.request('Start', self.on_start, args=(self.session, ''), options={})

    def on_start(self, response, results):
        if int(response) != 0:
            print(f"ELI portal: Start rejected/cancelled ({int(response)})", flush=True)
            self.loop.quit(); return
        restore = results.get('restore_token')
        if restore:
            self.token_file.parent.mkdir(parents=True, exist_ok=True)
            self.token_file.write_text(str(restore))
        streams = results.get('streams', [])
        if not streams:
            print('ELI portal: no PipeWire streams returned', flush=True)
            self.loop.quit(); return
        node_id = int(streams[0][0])
        stream_props = dict(streams[0][1]) if len(streams[0]) > 1 else {}
        print(f"ELI portal: PipeWire node={node_id} properties={stream_props}", flush=True)
        size = stream_props.get('size')
        if size and int(size[0]) > 0 and int(size[1]) > 0:
            self.source_size = (int(size[0]), int(size[1]))
        fd_obj = dbus.Interface(self.portal, SCREENCAST).OpenPipeWireRemote(
            self.session, dbus.Dictionary({}, signature='sv')
        )
        self.start_gstreamer(fd_obj.take(), node_id)

    def start_gstreamer(self, fd, node_id):
        # Pin the height too. With only a width, the scaler keeps the monitor's
        # height and sends a stretched, far larger frame.
        size = f"width={self.width}"
        if self.source_size:
            src_w, src_h = self.source_size
            width = min(self.width, src_w)
            height = max(2, round(width * src_h / src_w / 2) * 2)
            size = f"width={width},height={height}"
        desc = (
            f"pipewiresrc fd={fd} path={node_id} do-timestamp=true ! "
            "queue max-size-buffers=1 leaky=downstream ! "
            "videoconvert ! videoscale ! videorate ! "
            f"video/x-raw,format=RGBA,{size},framerate={self.fps}/1 ! "
            "appsink name=sink emit-signals=true max-buffers=1 drop=true sync=false"
        )
        self.pipeline = Gst.parse_launch(desc)
        sink = self.pipeline.get_by_name('sink')
        sink.connect('new-sample', self.on_sample)
        bus = self.pipeline.get_bus()
        bus.add_signal_watch()
        bus.connect('message::error', self.on_gst_error)
        self.pipeline.set_state(Gst.State.PLAYING)
        print('ELI portal: live desktop capture streaming', flush=True)

    def on_gst_error(self, bus, message):
        err, dbg = message.parse_error()
        print(f"ELI portal GStreamer error: {err}; {dbg}", flush=True)
        self.loop.quit()

    def on_sample(self, sink):
        sample = sink.emit('pull-sample')
        if sample is None:
            return Gst.FlowReturn.ERROR
        caps = sample.get_caps()
        structure = caps.get_structure(0)
        width = int(structure.get_value('width'))
        height = int(structure.get_value('height'))
        # VideoInfo().from_caps() no longer fills the object it is called on
        # in current GStreamer; it left the stride at 0 and crashed the bridge.
        stride = width * 4
        if hasattr(GstVideo.VideoInfo, 'new_from_caps'):
            info = GstVideo.VideoInfo.new_from_caps(caps)
            if info is not None and int(info.stride[0]) > 0:
                stride = int(info.stride[0])
        buf = sample.get_buffer()
        ok, mapping = buf.map(Gst.MapFlags.READ)
        if not ok:
            return Gst.FlowReturn.OK
        try:
            src = bytes(mapping.data)
            row_bytes = width * 4
            if stride == row_bytes:
                payload = src[:row_bytes * height]
            else:
                packed = bytearray(row_bytes * height)
                for y in range(height):
                    packed[y*row_bytes:(y+1)*row_bytes] = src[y*stride:y*stride+row_bytes]
                payload = bytes(packed)
            self.send_frame(width, height, payload)
        finally:
            buf.unmap(mapping)
        return Gst.FlowReturn.OK

    def send_frame(self, width, height, payload):
        with self.client_lock:
            c = self.client
            if c is None:
                return
            try:
                c.sendall(struct.pack('!4sIII', b'ELIR', width, height, len(payload)))
                c.sendall(payload)
            except OSError:
                try: c.close()
                except OSError: pass
                self.client = None

    def run(self):
        self.open_listener()
        threading.Thread(target=self.serve, daemon=True).start()
        self.init_portal()
        self.start_portal()
        self.loop.run()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bind', default='127.0.0.1:47831')
    ap.add_argument('--width', type=int, default=1280)
    ap.add_argument('--fps', type=int, default=18)
    ap.add_argument('--token-file', default='~/.local/state/eli-vr-standalone/portal-restore-token')
    args = ap.parse_args()
    DBusGMainLoop(set_as_default=True)
    Gst.init(None)
    try:
        Bridge(args.bind, max(640,min(args.width,2560)), max(5,min(args.fps,30)), args.token_file).run()
    except Exception as exc:
        print(f"ELI portal fatal: {type(exc).__name__}: {exc}", flush=True)
        raise

if __name__ == '__main__':
    main()
