#!/usr/bin/env python3
import json,os,platform,shutil,socket,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def cmd(a):
    try:return subprocess.run(a,text=True,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=4).stdout.strip()
    except Exception:return ""
def find(ns):
    for n in ns:
        p=shutil.which(n)
        if p:return p
    return ""
r={"eli_vr_version":(ROOT/"VERSION").read_text().strip(),"os":platform.platform(),"machine":platform.machine(),"python":platform.python_version(),"cpu":{"logical":os.cpu_count()},"tools":{"godot":find(["godot","godot4"]),"cargo":find(["cargo"]),"rustc":find(["rustc"]),"ffmpeg":find(["ffmpeg"])},"openxr":{"XR_RUNTIME_JSON":os.getenv("XR_RUNTIME_JSON","")}}
if sys.platform.startswith("linux"):
    r["gpu"]=cmd(["bash","-lc","nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || lspci | grep -Ei 'VGA|3D' | head -3"]); r["session_type"]=os.getenv("XDG_SESSION_TYPE",""); r["openxr"]["manifests"]=[str(x) for p in [Path("/usr/share/openxr/1"),Path("/usr/local/share/openxr/1")] if p.exists() for x in p.glob("*.json")]
elif sys.platform=="win32":r["gpu"]=cmd(["powershell","-NoProfile","-Command","Get-CimInstance Win32_VideoController | Select-Object -Expand Name"])
else:r["gpu"]=cmd(["system_profiler","SPDisplaysDataType"])[:1200]
bridge=ROOT/"native/desktop_bridge/target/release/eli-vr-desktop-bridge"
if sys.platform=="win32":bridge=bridge.with_suffix(".exe")
r["desktop_bridge_built"]=bridge.exists()
try:s=socket.create_connection(("127.0.0.1",47831),timeout=.2);s.close();r["desktop_bridge_running"]=True
except Exception:r["desktop_bridge_running"]=False
# Reports get pasted into bug reports: never record the user's home directory.
text=json.dumps(r,indent=2).replace(json.dumps(str(Path.home()))[1:-1],"~")
out=ROOT/"build/doctor-report.json";out.parent.mkdir(exist_ok=True);out.write_text(text);print(text);print("\nReport:",out)
