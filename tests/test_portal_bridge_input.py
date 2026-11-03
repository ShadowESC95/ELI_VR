"""The Wayland desktop helper: the key a client must give, the screen sent as tiles (all of them,
then only what changed), and ELI VR's pointer passed to the desktop through the portal.

Nothing here touches the real desktop: the portal is a stand-in that records what it is asked,
and the key is kept in a folder of the test's own.
"""
import importlib.util
import os
import socket
import stat
import struct
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "native" / "desktop_portal_bridge" / "eli_portal_bridge.py"


def _load():
    try:
        import dbus  # noqa: F401
        import gi  # noqa: F401
    except ImportError:
        raise unittest.SkipTest("the helper's D-Bus and GStreamer bindings are not installed here")
    spec = importlib.util.spec_from_file_location("eli_portal_bridge", HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeRemote:
    def __init__(self):
        self.asked = []

    def NotifyPointerMotionAbsolute(self, session, options, stream, x, y):
        self.asked.append(("move", str(session), int(stream), float(x), float(y)))

    def NotifyPointerButton(self, session, options, button, state):
        self.asked.append(("button", int(button), int(state)))

    def NotifyPointerAxisDiscrete(self, session, options, axis, steps):
        self.asked.append(("scroll", int(axis), int(steps)))


class Input(unittest.TestCase):
    def setUp(self):
        self.helper = _load()
        self.bridge = self.helper.Bridge("127.0.0.1:0", 0, 18, "/nonexistent/token")
        self.bridge.session = "/org/freedesktop/portal/desktop/session/1_1/eli"
        self.bridge.node_id = 57
        self.bridge.source_size = (2560, 1440)
        self.remote = FakeRemote()
        self.enterContext(mock.patch.object(self.helper.dbus, "Interface", lambda obj, iface: self.remote))

    def test_a_point_on_the_panel_is_that_point_on_the_screen(self):
        self.bridge.handle_input({"kind": "move", "x": 0.5, "y": 0.25})
        self.assertEqual(self.remote.asked, [("move", self.bridge.session, 57, 1280.0, 360.0)])

    def test_a_point_off_the_screen_is_held_to_its_edge(self):
        self.bridge.handle_input({"kind": "move", "x": 1.7, "y": -0.2})
        self.assertEqual(self.remote.asked[0][3:], (2560.0, 0.0))

    def test_clicks_and_scrolling_reach_the_desktop(self):
        for event in ({"kind": "button", "button": "left", "down": True}, {"kind": "button", "button": "left", "down": False},
                      {"kind": "button", "button": "right", "down": True}, {"kind": "scroll", "steps": -2},
                      {"kind": "button", "button": "sideways", "down": True}, {"kind": "type", "text": "rm -rf"}):
            self.bridge.handle_input(event)
        self.assertEqual(self.remote.asked, [("button", 0x110, 1), ("button", 0x110, 0), ("button", 0x111, 1), ("scroll", 0, -2)],
                         "a button it does not know, and anything that is not pointing, clicking or scrolling, is not passed on")

    def test_nothing_reaches_the_desktop_without_a_granted_session(self):
        self.bridge.take_input = False
        self.bridge.handle_input({"kind": "button", "button": "left", "down": True})
        self.bridge.take_input = True
        self.bridge.node_id = None
        self.bridge.handle_input({"kind": "move", "x": 0.5, "y": 0.5})
        self.assertEqual(self.remote.asked, [])

    def test_lines_from_elivr_are_read_and_handed_on_after_its_key(self):
        handed = []
        self.enterContext(mock.patch.object(self.helper.GLib, "idle_add", lambda fn, event: handed.append(event)))
        self.bridge.key = "the-key"
        ours, theirs = socket.socketpair()
        reader = threading.Thread(target=self.bridge.read_input, args=(ours,), daemon=True)
        reader.start()
        theirs.sendall(b'{"kind": "hello", "key": "the-key"}\n{"kind": "move", "x": 0.1, "y": 0.2}\n{not json}\n{"kind": "scroll", "st')
        theirs.sendall(b'eps": 1}\n')
        theirs.close()
        reader.join(5)
        self.assertEqual(handed, [{"kind": "move", "x": 0.1, "y": 0.2}, {"kind": "scroll", "steps": 1}])
        self.assertIs(self.bridge.client, ours)

    def test_without_the_key_a_connection_is_closed_and_nothing_handed_on(self):
        handed = []
        self.enterContext(mock.patch.object(self.helper.GLib, "idle_add", lambda fn, event: handed.append(event)))
        self.bridge.key = "the-key"
        for hello in (b'{"kind": "hello", "key": "a-guess"}\n', b'GET / HTTP/1.1\n', b'{"kind": "move", "x": 0.5, "y": 0.5}\n'):
            ours, theirs = socket.socketpair()
            reader = threading.Thread(target=self.bridge.read_input, args=(ours,), daemon=True)
            reader.start()
            theirs.sendall(hello + b'{"kind": "button", "button": "left", "down": true}\n')
            reader.join(5)
            theirs.settimeout(5)
            self.assertEqual(theirs.recv(1), b"", hello)
            theirs.close()
        self.assertEqual(handed, [])
        self.assertIsNone(self.bridge.client)


class Screen(unittest.TestCase):
    """The screen as tiles, in the same messages as the native helper (native/desktop_bridge/src/screen.rs)."""

    def setUp(self):
        self.helper = _load()

    def test_the_tiles_cover_the_screen_once(self):
        for w, h in ((3840, 2160), (1366, 768), (1, 1), (17, 5)):
            every = self.helper.tiles(w, h)
            self.assertEqual(sum(tw * th for _, _, tw, th in every), w * h, (w, h))
            self.assertTrue(all(x + tw <= w and y + th <= h for x, y, tw, th in every))

    def test_a_new_client_gets_everything_a_still_screen_nothing_and_a_change_its_tile(self):
        before = bytes(64 * 40 * 4)
        now = bytearray(before)
        now[(22 * 64 + 37) * 4] = 255                   # one pixel, in the 4-pixel tile at (36, 20)
        self.assertEqual(self.helper.changed(None, before, 64, 40), self.helper.tiles(64, 40))
        self.assertEqual(self.helper.changed(before, before, 64, 40), [])
        self.assertEqual(self.helper.changed(before, bytes(now), 64, 40), [(36, 20, 4, 4)])

    def test_a_message_carries_each_tile_and_its_rows(self):
        now = bytes(range(32))                          # a 4 by 2 screen
        message = self.helper.encode(now, 4, 2, [(1, 0, 2, 2)])
        self.assertEqual(message[:4], b"ELIT")
        self.assertEqual(struct.unpack("!7I", message[4:32]), (4, 2, 1, 1, 0, 2, 2))
        self.assertEqual(message[32:], now[4:12] + now[20:28])

    def test_elivr_is_sent_the_whole_screen_then_only_what_changed(self):
        bridge = self.helper.Bridge("127.0.0.1:0", 0, 30, "/nonexistent/token")
        ours, theirs = socket.socketpair()
        self.addCleanup(ours.close)
        self.addCleanup(theirs.close)
        bridge.client, bridge.fresh = ours, True
        threading.Thread(target=bridge.send_loop, daemon=True).start()
        still = bytes(64 * 40 * 4)
        bridge.send_frame(64, 40, still)
        theirs.settimeout(5)

        def message():
            head = self._read(theirs, 16)
            count = struct.unpack("!I", head[12:])[0]
            rects = []
            for _ in range(count):
                x, y, w, h = struct.unpack("!4I", self._read(theirs, 16))
                self._read(theirs, w * h * 4)
                rects.append((x, y, w, h))
            return rects

        self.assertEqual(len(message()), len(self.helper.tiles(64, 40)))
        bridge.send_frame(64, 40, still)                # nothing changed: nothing is sent
        moved = bytearray(still)
        moved[0] = 9
        bridge.send_frame(64, 40, bytes(moved))
        self.assertEqual(message(), [(0, 0, 4, 4)])

    @staticmethod
    def _read(sock, n):
        out = b""
        while len(out) < n:
            chunk = sock.recv(n - len(out))
            if not chunk:
                raise AssertionError("the helper stopped sending")
            out += chunk
        return out

    def test_the_key_is_kept_for_this_account_alone(self):
        with tempfile.TemporaryDirectory() as run, mock.patch.dict(os.environ, {"XDG_RUNTIME_DIR": run}):
            key = self.helper.issue_key()
            path = self.helper.key_path()
            self.assertEqual(path.parent, Path(run))
            self.assertEqual(path.read_text(), key)
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertNotEqual(self.helper.issue_key(), key, "a new key each start")
            self.assertTrue(self.helper.admits(b'{"kind": "hello", "key": "%s"}' % path.read_text().encode(), path.read_text()))


if __name__ == "__main__":
    unittest.main()
