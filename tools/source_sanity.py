#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
bad = False

# These patterns are not legitimate string escapes; they indicate that an
# entire source-code block was serialized into one physical line with "\n"
# characters instead of actual newlines.
patterns = [
    re.compile(r"->\s*[A-Za-z0-9_\[\]]+\s*:\\n"),
    re.compile(r"\\nfunc\s+"),
    re.compile(r"\\n\s{4}(?:var|if|for|while|match|return|_[A-Za-z])"),
]

for path in sorted((ROOT / "scripts").rglob("*.gd")):
    text = path.read_text(encoding="utf-8", errors="replace")
    for pattern in patterns:
        match = pattern.search(text)
        if match:
            line_no = text.count("\n", 0, match.start()) + 1
            print(
                f"SOURCE SANITY ERROR: {path.relative_to(ROOT)}:{line_no}: "
                f"literal escaped-newline code block"
            )
            bad = True
            break

if bad:
    sys.exit(1)

print("ELI VR source sanity: OK")
