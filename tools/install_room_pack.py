#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK_ROOT = ROOT / "assets" / "user_packs"

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def safe_extract(z: zipfile.ZipFile, target: Path) -> None:
    base = target.resolve()
    for member in z.infolist():
        out = (target / member.filename).resolve()
        if base not in out.parents and out != base:
            raise SystemExit(f"Unsafe archive path: {member.filename}")
    z.extractall(target)

def main() -> None:
    ap = argparse.ArgumentParser(
        description="Install a LOCAL ELI VR room/environment pack. No network access is used."
    )
    ap.add_argument("pack", help="Path to a local .zip room pack")
    ap.add_argument("--replace", action="store_true")
    args = ap.parse_args()

    pack = Path(args.pack).expanduser().resolve()
    if "://" in args.pack:
        raise SystemExit("URLs are not accepted. Provide a local file path.")
    if not pack.is_file():
        raise SystemExit(f"Pack not found: {pack}")
    if pack.suffix.lower() != ".zip":
        raise SystemExit("Room packs must be local .zip files.")

    PACK_ROOT.mkdir(parents=True, exist_ok=True)
    temp = PACK_ROOT / ".installing"
    if temp.exists():
        shutil.rmtree(temp)
    temp.mkdir()

    with zipfile.ZipFile(pack) as z:
        safe_extract(z, temp)

    manifests = list(temp.rglob("manifest.json"))
    if len(manifests) != 1:
        shutil.rmtree(temp, ignore_errors=True)
        raise SystemExit("Pack must contain exactly one manifest.json.")

    manifest = json.loads(manifests[0].read_text())
    pack_id = str(manifest.get("id", "")).strip()
    if not pack_id or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" for c in pack_id):
        shutil.rmtree(temp, ignore_errors=True)
        raise SystemExit("Invalid or missing pack id.")

    final = PACK_ROOT / pack_id
    if final.exists():
        if not args.replace:
            shutil.rmtree(temp, ignore_errors=True)
            raise SystemExit(f"Pack already installed: {pack_id}. Use --replace.")
        shutil.rmtree(final)

    source_root = manifests[0].parent
    shutil.move(str(source_root), str(final))
    shutil.rmtree(temp, ignore_errors=True)

    record = {
        "id": pack_id,
        "source_filename": pack.name,
        "source_sha256": sha256(pack),
        "manifest": manifest,
    }
    (final / ".install-record.json").write_text(json.dumps(record, indent=2) + "\n")

    print(f"Installed local room pack: {pack_id}")
    print(f"Location: {final}")
    print("Network used: NO")

if __name__ == "__main__":
    main()
