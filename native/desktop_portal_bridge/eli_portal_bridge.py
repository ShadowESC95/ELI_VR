#!/usr/bin/env python3
"""ELI VR Linux Wayland capture adapter.

XDG Desktop Portal ScreenCast -> PipeWire -> GStreamer -> loopback RGBA.
The transport binds before portal negotiation so Godot can distinguish a live
local adapter from a missing process. No remote network access is used.

With the portal's RemoteDesktop (GNOME and KDE have it) the same session also
takes the pointer: ELI VR sends one JSON line per event over the same loopback
connection ({"kind": "move", "x", "y"} with x and y from 0 to 1 across the
screen, {"kind": "button", "button": "left"|"right", "down"}, {"kind": "scroll",
"steps"}), and they reach the desktop through the portal, which asks the user
once. Without it, or if the user says no, the screen is shown and not touched.
"""
import argparse, json, os, socket, struct, threading
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
REMOTE = "org.freedesktop.portal.RemoteDesktop"
BUTTONS = {"left": 0x110, "right": 0x111, "middle": 0x112}       # BTN_LEFT, BTN_RIGHT, BTN_MIDDLE
REQUEST = "org.freedesktop.portal.Request"
PROPERTIES = "org.freedesktop.DBus.Properties"

class Bridge:
    def __init__(self, bind, width, fps, token_file, take_input=True):
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
        self.remote_version = 0
        self.take_input = take_input        # ask for the pointer as well as the screen
        self.node_id = None
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
            threading.Thread(target=self.read_input, args=(c,), daemon=True).start()

    def read_input(self, c):
        """Pointer events from ELI VR, one JSON line each, handed to the portal on its own loop."""
        pending = b""
        while True:
            try:
                chunk = c.recv(4096)
            except OSError:
                return
            if not chunk:
                return
            pending += chunk
            while b"\n" in pending:
                line, pending = pending.split(b"\n", 1)
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                if isinstance(event, dict):
                    GLib.idle_add(self.handle_input, event)

    def handle_input(self, event):
        if not (self.take_input and self.session and self.node_id is not None and self.source_size):
            return False
        remote = dbus.Interface(self.portal, REMOTE)
        none = dbus.Dictionary({}, signature='sv')
        try:
            kind = event.get("kind")
            if kind == "move":
                x = min(1.0, max(0.0, float(event.get("x", 0.0)))) * self.source_size[0]
                y = min(1.0, max(0.0, float(event.get("y", 0.0)))) * self.source_size[1]
                remote.NotifyPointerMotionAbsolute(self.session, none, dbus.UInt32(self.node_id), dbus.Double(x), dbus.Double(y))
            elif kind == "button" and event.get("button") in BUTTONS:
                remote.NotifyPointerButton(self.session, none, dbus.Int32(BUTTONS[event["button"]]),
                                           dbus.UInt32(1 if event.get("down") else 0))
            elif kind == "scroll":
                steps = int(event.get("steps", 0))
                if steps:
                    remote.NotifyPointerAxisDiscrete(self.session, none, dbus.UInt32(0), dbus.Int32(steps))
        except (dbus.DBusException, TypeError, ValueError) as exc:
            print(f"ELI portal: input not passed on: {exc}", flush=True)
        return False

    def init_portal(self):
        self.bus = dbus.SessionBus()
        self.portal = self.bus.get_object(PORTAL_BUS, PORTAL_PATH)
        props = dbus.Interface(self.portal, PROPERTIES)
        try:
            self.portal_version = int(props.Get(SCREENCAST, 'version'))
        except Exception:
            self.portal_version = 0
        try:
            self.remote_version = int(props.Get(REMOTE, 'version'))
        except Exception:
            self.remote_version = 0
        if not self.remote_version:
            self.take_input = False
        print(f"ELI portal: ScreenCast interface version={self.portal_version} RemoteDesktop interface version={self.remote_version}"
              f" input={'asked for' if self.take_input else 'off'}", flush=True)

    def token(self, prefix):
        self.seq += 1
        return f"eli_{prefix}_{os.getpid()}_{self.seq}"

    def request_path(self, token):
        sender = self.bus.get_unique_name()[1:].replace('.', '_')
        return f"/org/freedesktop/portal/desktop/request/{sender}/{token}"

    def request(self, method_name, callback, args=(), options=None, interface=SCREENCAST):
        options = dict(options or {})
        handle_token = self.token("req")
        options['handle_token'] = handle_token
        path = self.request_path(handle_token)
        self.bus.add_signal_receiver(
            callback, signal_name='Response', dbus_interface=REQUEST, path=path
        )
        iface = dbus.Interface(self.portal, interface)
        getattr(iface, method_name)(*(tuple(args) + (dbus.Dictionary(options, signature='sv'),)))

    def start_portal(self):
        session_token = self.token("session")
        self.request('CreateSession', self.on_create, options={'session_handle_token': session_token},
                     interface=REMOTE if self.take_input else SCREENCAST)

    def without_input(self, why):
        """The pointer was refused or failed: show the screen alone, as before input was asked for."""
        print(f"ELI portal: {why}; sharing the screen without the pointer", flush=True)
        self.take_input = False
        self.session = None
        self.start_portal()

    def on_create(self, response, results):
        if int(response) != 0:
            if self.take_input:
                return self.without_input(f"RemoteDesktop CreateSession rejected ({int(response)})")
            print(f"ELI portal: CreateSession rejected ({int(response)})", flush=True)
            self.loop.quit(); return
        self.session = results['session_handle']
        if self.take_input:
            devices = {'types': dbus.UInt32(3)}        # keyboard and pointer
            if self.remote_version >= 2:
                devices['persist_mode'] = dbus.UInt32(2)
                token = self.remote_token_file().read_text().strip() if self.remote_token_file().exists() else ""
                if token:
                    devices['restore_token'] = token
            self.request('SelectDevices', self.on_devices, args=(self.session,), options=devices, interface=REMOTE)
            return
        self.select_sources()

    def remote_token_file(self):
        return self.token_file.with_name(self.token_file.name + ".remote")

    def on_devices(self, response, results):
        if int(response) != 0:
            return self.without_input(f"SelectDevices rejected ({int(response)})")
        self.select_sources()

    def select_sources(self):
        options = {'multiple': False, 'types': dbus.UInt32(1), 'cursor_mode': dbus.UInt32(2)}
        if self.portal_version >= 4 and not self.take_input:
            options['persist_mode'] = dbus.UInt32(2)
            if self.token_file.exists():
                token = self.token_file.read_text().strip()
                if token:
                    options['restore_token'] = token
        self.request('SelectSources', self.on_select, args=(self.session,), options=options)

    def on_select(self, response, results):
        if int(response) != 0 and self.take_input:
            return self.without_input(f"SelectSources rejected ({int(response)})")
        if int(response) != 0:
            print(f"ELI portal: SelectSources rejected ({int(response)})", flush=True)
            self.token_file.unlink(missing_ok=True)
            self.loop.quit(); return
        print("ELI portal: source selection accepted", flush=True)
        self.request('Start', self.on_start, args=(self.session, ''), options={},
                     interface=REMOTE if self.take_input else SCREENCAST)

    def on_start(self, response, results):
        if int(response) != 0:
            if self.take_input:
                self.remote_token_file().unlink(missing_ok=True)
                return self.without_input(f"RemoteDesktop Start rejected/cancelled ({int(response)})")
            print(f"ELI portal: Start rejected/cancelled ({int(response)})", flush=True)
            self.loop.quit(); return
        restore = results.get('restore_token')
        if restore:
            kept = self.remote_token_file() if self.take_input else self.token_file
            kept.parent.mkdir(parents=True, exist_ok=True)
            kept.write_text(str(restore))
        if self.take_input:
            print(f"ELI portal: pointer granted (devices={int(results.get('devices', 0))})", flush=True)
        streams = results.get('streams', [])
        if not streams:
            print('ELI portal: no PipeWire streams returned', flush=True)
            self.loop.quit(); return
        node_id = int(streams[0][0])
        self.node_id = node_id
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
        size = f"width={self.width}" if self.width > 0 else ""
        if self.source_size:
            src_w, src_h = self.source_size
            width = min(self.width, src_w) if self.width > 0 else src_w      # 0: the screen's own width
            height = max(2, round(width * src_h / src_w / 2) * 2)
            size = f"width={width},height={height}"
        desc = (
            f"pipewiresrc fd={fd} path={node_id} do-timestamp=true ! "
            "queue max-size-buffers=1 leaky=downstream ! "
            "videoconvert ! videoscale ! videorate ! "
            f"video/x-raw,format=RGBA,{size + ',' if size else ''}framerate={self.fps}/1 ! "
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
    ap.add_argument('--width', type=int, default=0, help="frame width; 0 sends the screen at its own width")
    ap.add_argument('--fps', type=int, default=18)
    ap.add_argument('--token-file', default='~/.local/state/eli-vr-standalone/portal-restore-token')
    ap.add_argument('--no-input', action='store_true', help="share the screen only; never ask for the pointer")
    args = ap.parse_args()
    DBusGMainLoop(set_as_default=True)
    Gst.init(None)
    try:
        Bridge(args.bind, 0 if args.width <= 0 else max(640, args.width), max(5, min(args.fps, 30)), args.token_file,
               take_input=not args.no_input).run()
    except Exception as exc:
        print(f"ELI portal fatal: {type(exc).__name__}: {exc}", flush=True)
        raise

if __name__ == '__main__':
    main()
