"""The release scan stops personal data, and lets the licence publish its contact."""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import make_release  # noqa: E402

# Built here rather than written out, so this file is not itself a finding.
ADDRESS = "licensor" + "@" + "example.org"
HOME = "/" + "home/somebody"


class ReleaseScan(unittest.TestCase):
    def _scan(self, name, text):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / name).parent.mkdir(parents=True, exist_ok=True)
            (root / name).write_text(text, encoding="utf-8")
            old = make_release.ROOT
            make_release.ROOT = root
            try:
                return make_release.scan([root / name])
            finally:
                make_release.ROOT = old

    def test_the_licence_may_publish_a_contact_address(self):
        self.assertEqual(self._scan("LICENSE", f"Contact: {ADDRESS}\n"), [])

    def test_an_address_anywhere_else_is_still_a_finding(self):
        found = self._scan("docs/notes.md", f"mail {ADDRESS}\n")
        self.assertEqual(len(found), 1)
        self.assertIn("e-mail address", found[0])

    def test_the_licence_is_still_checked_for_everything_else(self):
        found = self._scan("LICENSE", f"built in {HOME}/eli-vr\n")
        self.assertEqual(len(found), 1)
        self.assertIn("home directory path", found[0])


if __name__ == "__main__":
    unittest.main()
