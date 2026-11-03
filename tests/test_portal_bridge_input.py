"""The Wayland desktop helper passing ELI VR's pointer to the desktop through the portal.

Nothing here touches the real desktop: the portal is a stand-in that records what it is asked.
"""
import importlib.util
import socket
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

    def test_lines_from_elivr_are_read_and_handed_on(self):
        handed = []
        self.enterContext(mock.patch.object(self.helper.GLib, "idle_add", lambda fn, event: handed.append(event)))
        ours, theirs = socket.socketpair()
        reader = threading.Thread(target=self.bridge.read_input, args=(ours,), daemon=True)
        reader.start()
        theirs.sendall(b'{"kind": "move", "x": 0.1, "y": 0.2}\n{not json}\n{"kind": "scroll", "st')
        theirs.sendall(b'eps": 1}\n')
        theirs.close()
        reader.join(5)
        self.assertEqual(handed, [{"kind": "move", "x": 0.1, "y": 0.2}, {"kind": "scroll", "steps": 1}])


if __name__ == "__main__":
    unittest.main()
