#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULTS = ROOT / "config/defaults.json"
USER = ROOT / "config/user.json"
ROOMS = json.loads((ROOT/"config/rooms/rooms.json").read_text())
ENVS = json.loads((ROOT/"config/rooms/environments.json").read_text())
THEMES = json.loads((ROOT/"config/themes/themes.json").read_text())

def deep_merge(a,b):
    out = json.loads(json.dumps(a))
    for k,v in b.items():
        if isinstance(v,dict) and isinstance(out.get(k),dict):
            out[k]=deep_merge(out[k],v)
        else:
            out[k]=v
    return out

def config():
    base=json.loads(DEFAULTS.read_text())
    if USER.exists():
        base=deep_merge(base,json.loads(USER.read_text()))
    return base

def saved_settings():
    """Where the app keeps the settings changed inside it, per user."""
    if sys.platform=="win32":
        base=Path(os.environ.get("APPDATA",Path.home()/"AppData"/"Roaming"))/"Godot"
    elif sys.platform=="darwin":
        base=Path.home()/"Library"/"Application Support"/"Godot"
    else:
        base=Path(os.environ.get("XDG_DATA_HOME",Path.home()/".local"/"share"))/"godot"
    return base/"app_userdata"/"ELI VR"/"eli_vr"/"settings.json"

def save(data, change):
    USER.write_text(json.dumps(data,indent=2)+"\n")
    # The app loads its own saved settings last, so a change made only here
    # would be overruled by them. Make the same change there too.
    saved=saved_settings()
    if saved.exists():
        try:
            current=json.loads(saved.read_text())
        except (OSError, ValueError):
            return
        saved.write_text(json.dumps(deep_merge(current,change),indent="\t"))
        print(f"Updated {saved}")

def set_path(data,path,value):
    cur=data
    parts=path.split(".")
    for p in parts[:-1]:
        cur=cur.setdefault(p,{})
    cur[parts[-1]]=value

def find_godot():
    # GODOT_BIN wins, matching the launch/ scripts on every OS.
    env=os.getenv("GODOT_BIN")
    if env and Path(env).exists(): return env
    for name in ("godot","godot4","Godot"):
        p=shutil.which(name)
        if p: return p
    mac=Path("/Applications/Godot.app/Contents/MacOS/Godot")
    if mac.exists(): return str(mac)
    return None

def main():
    ap=argparse.ArgumentParser(prog="eli-vr",description="ELI VR standalone project CLI")
    sub=ap.add_subparsers(dest="cmd",required=True)

    sub.add_parser("show")
    sub.add_parser("reset")
    sub.add_parser("rooms")
    sub.add_parser("environments")
    sub.add_parser("themes")

    p=sub.add_parser("room"); p.add_argument("id",choices=sorted(ROOMS))
    p=sub.add_parser("environment"); p.add_argument("id",choices=["default"]+sorted(ENVS))
    p=sub.add_parser("theme"); p.add_argument("id",choices=sorted(THEMES))
    p=sub.add_parser("quality"); p.add_argument("id",choices=["low","medium","high","ultra"])
    p=sub.add_parser("xr"); p.add_argument("mode",choices=["auto","on","off"])
    p=sub.add_parser("desktop"); p.add_argument("mode",choices=["on","off"])
    p=sub.add_parser("eli"); p.add_argument("mode",choices=["on","off"])
    p=sub.add_parser("model"); p.add_argument("name",help="a model ELI has, by name, or 'any' for whichever he has loaded")
    p=sub.add_parser("set"); p.add_argument("path"); p.add_argument("value")

    p=sub.add_parser("launch")
    p.add_argument("--xr",action="store_true")
    p.add_argument("--flat",action="store_true")
    p.add_argument("--compat",action="store_true")

    args=ap.parse_args()
    data=config()

    if args.cmd=="show":
        print(json.dumps(data,indent=2)); return
    if args.cmd=="reset":
        USER.unlink(missing_ok=True); print("Removed config/user.json"); return
    if args.cmd=="rooms":
        for k,v in ROOMS.items(): print(f"{k:22} {v['name']} — {v['purpose']}")
        return
    if args.cmd=="environments":
        for k,v in ENVS.items(): print(f"{k:22} {v['name']}")
        return
    if args.cmd=="themes":
        for k in THEMES: print(k)
        return

    # Each command is one small change, applied to the project override and
    # to the settings the app has saved for this user.
    change={}
    if args.cmd=="room":
        change={"world":{"room":args.id,"environment_override":""}}
    elif args.cmd=="environment":
        change={"world":{"environment_override":"" if args.id=="default" else args.id}}
    elif args.cmd=="theme":
        change={"world":{"theme":args.id}}
    elif args.cmd=="quality":
        change=json.loads((ROOT/f"config/profiles/{args.id}.json").read_text())
    elif args.cmd=="xr":
        change={"xr":{"mode":args.mode}}
    elif args.cmd=="desktop":
        change={"desktop":{"enabled":args.mode=="on"}}
    elif args.cmd=="eli":
        change={"eli_bridge":{"enabled":args.mode=="on"}}
    elif args.cmd=="model":
        change={"eli_bridge":{"model":"" if args.name.lower()=="any" else args.name}}
    elif args.cmd=="set":
        raw=args.value
        try: val=json.loads(raw)
        except Exception: val=raw
        set_path(change,args.path,val)
    elif args.cmd=="launch":
        godot=find_godot()
        if not godot:
            raise SystemExit("Godot not found. Set GODOT_BIN or install Godot 4.7.2.")
        cmd=[godot,"--path",str(ROOT)]
        if args.xr: cmd += ["--xr-mode","on"]
        if args.flat: cmd += ["--xr-mode","off"]
        if args.compat: cmd += ["--rendering-method","gl_compatibility"]
        # os.execv does not replace the process on Windows; wait for Godot instead.
        if os.name=="nt": sys.exit(subprocess.call(cmd))
        os.execv(godot,cmd)

    if args.cmd!="launch":
        save(deep_merge(data,change), change)
        print(f"Updated {USER}")

if __name__=="__main__":
    main()
