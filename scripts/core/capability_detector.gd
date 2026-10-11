class_name CapabilityDetector
extends RefCounted

func detect() -> Dictionary:
    var xr: XRInterface = XRServer.find_interface("OpenXR")
    var memory: Dictionary = OS.get_memory_info()

    var physical_bytes: int = int(memory.get("physical", -1))
    var available_bytes: int = int(memory.get("available", -1))
    var ram_total_gb: float = (
        float(physical_bytes) / 1073741824.0
        if physical_bytes > 0
        else -1.0
    )
    var ram_available_gb: float = (
        float(available_bytes) / 1073741824.0
        if available_bytes > 0
        else -1.0
    )

    var gpu_type: int = int(RenderingServer.get_video_adapter_type())
    var cpu_threads: int = OS.get_processor_count()

    var result: Dictionary = {
        "os": OS.get_name(),
        "cpu_threads": cpu_threads,
        "cpu_name": OS.get_processor_name(),
        "ram_total_gb": ram_total_gb,
        "ram_available_gb": ram_available_gb,
        "gpu": RenderingServer.get_video_adapter_name(),
        "gpu_vendor": RenderingServer.get_video_adapter_vendor(),
        "gpu_type": gpu_type,
        "gpu_api": RenderingServer.get_video_adapter_api_version(),
        "renderer": RenderingServer.get_current_rendering_method(),
        "openxr_registered": xr != null,
        "openxr_initialized": xr != null and xr.is_initialized(),
        "desktop_bridge_supported": OS.get_name() in ["Linux", "Windows", "macOS"],
        "desktop_capture_backend": _desktop_capture_backend(),
        "touchscreen": DisplayServer.is_touchscreen_available(),
    }

    result["recommended_quality"] = _recommended_quality(
        cpu_threads,
        ram_total_gb,
        gpu_type
    )
    result["hardware_class"] = _hardware_class(
        str(result["recommended_quality"])
    )
    return result

func _desktop_capture_backend() -> String:
    match OS.get_name():
        "Windows":
            return "windows_graphics_capture"
        "macOS":
            return "screencapturekit"
        "Linux":
            var session_type: String = OS.get_environment("XDG_SESSION_TYPE").to_lower()
            if session_type == "wayland":
                return "xdg_portal_pipewire"
            return "x11_capture"
        "Android":
            return "android_remote_or_mediaprojection"
        "iOS":
            return "ios_remote_or_replaykit"
        "Web":
            return "browser_capture"
        _:
            return "platform_adapter_required"

func _recommended_quality(
    cpu_threads: int,
    ram_total_gb: float,
    gpu_type: int
) -> String:
    var score: int = 0

    if cpu_threads >= 16:
        score += 2
    elif cpu_threads >= 8:
        score += 1
    elif cpu_threads <= 4:
        score -= 1

    if ram_total_gb >= 31.0:
        score += 2
    elif ram_total_gb >= 15.0:
        score += 1
    elif ram_total_gb > 0.0 and ram_total_gb < 8.0:
        score -= 1

    if gpu_type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
        score += 2
    elif gpu_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
        score -= 1
    elif gpu_type == RenderingDevice.DEVICE_TYPE_CPU:
        score -= 3

    if score >= 5:
        return "ultra"
    if score >= 3:
        return "high"
    if score >= 1:
        return "medium"
    return "low"

func _hardware_class(quality: String) -> String:
    match quality:
        "ultra":
            return "enthusiast"
        "high":
            return "performance"
        "medium":
            return "balanced"
        _:
            return "conservative"
