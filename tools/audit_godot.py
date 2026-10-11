#!/usr/bin/env python3
"""
ELI VR / Godot diagnostic audit.
Read-only: does not modify the project or Godot configuration.

Run from the project root:
    python3 tools/audit_godot.py

Or:
    python3 audit_godot.py /path/to/project

Creates:
    build/godot-audit-YYYYMMDD-HHMMSS/
    build/godot-audit-YYYYMMDD-HHMMSS.tar.gz
"""
from __future__ import annotations

import datetime as dt
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path


MAX_TEXT = 300_000
TIMEOUT = 30


def run(cmd, cwd=None, timeout=TIMEOUT):
    try:
        p = subprocess.run(
            cmd,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            env=os.environ.copy(),
        )
        return {"cmd": cmd, "returncode": p.returncode, "output": p.stdout[-MAX_TEXT:]}
    except FileNotFoundError as e:
        return {"cmd": cmd, "returncode": 127, "output": str(e)}
    except subprocess.TimeoutExpired as e:
        data = e.stdout or ""
        if isinstance(data, bytes):
            data = data.decode(errors="replace")
        return {"cmd": cmd, "returncode": 124, "output": f"TIMEOUT after {timeout}s\n{data[-MAX_TEXT:]}"}
    except Exception as e:
        return {"cmd": cmd, "returncode": 125, "output": repr(e)}


def write_text(path: Path, text: str):
    path.write_text(text[-MAX_TEXT:], encoding="utf-8", errors="replace")


def redact_env(env):
    # Only collect variables relevant to graphics/Godot/OpenXR/session.
    prefixes = (
        "GODOT", "XR_", "XDG_", "WAYLAND", "DISPLAY", "VK_", "MESA_",
        "__GL_", "NVIDIA", "DRI_", "SDL_", "PIPEWIRE", "PULSE"
    )
    return {k: v for k, v in sorted(env.items()) if k.startswith(prefixes)}


def find_project_root(arg=None):
    if arg:
        p = Path(arg).expanduser().resolve()
        if (p / "project.godot").exists():
            return p
        raise SystemExit(f"No project.godot in: {p}")
    p = Path.cwd().resolve()
    for candidate in [p, *p.parents]:
        if (candidate / "project.godot").exists():
            return candidate
    raise SystemExit("Could not find project.godot. Run from the project root or pass the project path.")


def safe_read(path: Path, max_bytes=MAX_TEXT):
    try:
        data = path.read_bytes()[:max_bytes]
        return data.decode("utf-8", errors="replace")
    except Exception as e:
        return f"<could not read: {e!r}>"


def main():
    root = find_project_root(sys.argv[1] if len(sys.argv) > 1 else None)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    audit_dir = root / "build" / f"godot-audit-{stamp}"
    audit_dir.mkdir(parents=True, exist_ok=True)

    godot = shutil.which("godot") or shutil.which("godot4")
    report = {
        "timestamp": dt.datetime.now().astimezone().isoformat(),
        "project_root": str(root),
        "platform": platform.platform(),
        "python": sys.version,
        "godot": godot,
        "env": redact_env(os.environ),
        "checks": {},
    }

    # Core files
    for rel in ("project.godot", "export_presets.cfg"):
        p = root / rel
        if p.exists():
            write_text(audit_dir / f"{rel}.txt", safe_read(p))

    # High-value project metadata
    godot_dir = root / ".godot"
    report["checks"]["godot_cache_exists"] = godot_dir.exists()
    report["checks"]["godot_cache_size_bytes"] = sum(
        p.stat().st_size for p in godot_dir.rglob("*") if p.is_file()
    ) if godot_dir.exists() else 0

    # Executable / symlink chain
    if godot:
        gp = Path(godot)
        try:
            report["godot_realpath"] = str(gp.resolve())
        except Exception:
            pass
        report["checks"]["godot_version"] = run([godot, "--version"], cwd=root)
        report["checks"]["godot_help"] = run([godot, "--help"], cwd=root, timeout=10)

        real = Path(os.path.realpath(godot))
        if real.exists():
            report["checks"]["godot_file"] = run(["file", str(real)])
            report["checks"]["godot_ldd"] = run(["ldd", str(real)], timeout=10)

        # Parse-only / startup tests. These are read-only from the script's point of view,
        # though Godot itself may refresh its .godot import/cache directory.
        report["checks"]["headless_project_start"] = run(
            [godot, "--headless", "--path", str(root), "--quit-after", "1"],
            cwd=root, timeout=30
        )
        report["checks"]["headless_editor_start"] = run(
            [godot, "--headless", "--editor", "--path", str(root), "--quit-after", "1"],
            cwd=root, timeout=45
        )

        # Compatibility renderer can distinguish Vulkan/driver failures from project failures.
        report["checks"]["headless_compatibility_start"] = run(
            [godot, "--headless", "--path", str(root), "--rendering-method", "gl_compatibility",
             "--quit-after", "1"],
            cwd=root, timeout=30
        )
    else:
        report["checks"]["godot_version"] = {
            "returncode": 127,
            "output": "godot/godot4 not found in PATH"
        }

    # Graphics stack
    for name, cmd in {
        "nvidia_smi": ["nvidia-smi"],
        "vulkaninfo_summary": ["vulkaninfo", "--summary"],
        "glxinfo_brief": ["glxinfo", "-B"],
        "loginctl_session": ["loginctl", "show-session", os.environ.get("XDG_SESSION_ID", ""),
                             "-p", "Type", "-p", "Desktop", "-p", "Remote"],
    }.items():
        if not cmd[-1] and name == "loginctl_session":
            continue
        report["checks"][name] = run(cmd, timeout=15)

    # OpenXR manifests and key runtime paths
    xr_candidates = []
    for base in (
        Path.home() / ".config/openxr/1",
        Path("/etc/xdg/openxr/1"),
        Path("/usr/local/share/openxr/1"),
        Path("/usr/share/openxr/1"),
    ):
        if base.exists():
            for p in sorted(base.glob("*.json")):
                xr_candidates.append(str(p))
                write_text(audit_dir / ("openxr-" + p.name + ".txt"), safe_read(p))
    report["openxr_manifests"] = xr_candidates

    # Project script inventory + obvious parse-sensitive files.
    scripts = []
    for ext in ("*.gd", "*.gdshader", "*.cs"):
        scripts.extend(root.rglob(ext))
    report["script_count"] = len(scripts)
    report["scripts"] = [str(p.relative_to(root)) for p in sorted(scripts)[:5000]]

    # Git status/diff if available.
    if (root / ".git").exists() and shutil.which("git"):
        report["checks"]["git_status"] = run(["git", "status", "--short"], cwd=root)
        report["checks"]["git_diff_stat"] = run(["git", "diff", "--stat"], cwd=root)
        report["checks"]["git_diff"] = run(["git", "diff", "--", "project.godot", "*.gd", "*.gdshader"], cwd=root)

    # Recent Godot logs, if present.
    log_roots = [
        Path.home() / ".local/share/godot/app_userdata",
        Path.home() / ".config/godot",
    ]
    logs = []
    for base in log_roots:
        if base.exists():
            for p in base.rglob("*.log"):
                try:
                    logs.append((p.stat().st_mtime, p))
                except OSError:
                    pass
    for i, (_, p) in enumerate(sorted(logs, reverse=True)[:8], 1):
        write_text(audit_dir / f"recent-godot-log-{i}-{p.name}.txt", safe_read(p))

    # Human-readable triage summary.
    problems = []
    for k in ("godot_version", "headless_project_start", "headless_editor_start",
              "headless_compatibility_start", "vulkaninfo_summary"):
        item = report["checks"].get(k)
        if item and item.get("returncode") not in (0, None):
            problems.append(f"{k}: rc={item.get('returncode')}")

    summary = [
        "ELI VR / Godot audit",
        f"Project: {root}",
        f"Godot: {godot or 'NOT FOUND'}",
        f"Platform: {platform.platform()}",
        f"Session: {os.environ.get('XDG_SESSION_TYPE', '')}",
        f"XR_RUNTIME_JSON: {os.environ.get('XR_RUNTIME_JSON', '')}",
        "",
        "Potential failing checks:",
        *(["  none detected"] if not problems else [f"  {x}" for x in problems]),
        "",
        "Inspect report.json and the captured command output for ERROR, SCRIPT ERROR,",
        "Vulkan, OpenXR, renderer, parse, missing library, and crash messages.",
    ]
    write_text(audit_dir / "SUMMARY.txt", "\n".join(summary) + "\n")

    (audit_dir / "report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )

    archive = root / "build" / f"godot-audit-{stamp}.tar.gz"
    with tarfile.open(archive, "w:gz") as tf:
        tf.add(audit_dir, arcname=audit_dir.name)

    print("\n".join(summary))
    print(f"\nAudit directory: {audit_dir}")
    print(f"Archive: {archive}")


if __name__ == "__main__":
    main()
