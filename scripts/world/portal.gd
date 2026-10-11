class_name RoomPortal
extends "res://scripts/world/interactable_3d.gd"

func setup_portal(name_text: String, target_room: String, accent: Color) -> void:
    setup(name_text, "room", target_room, accent, Vector2(1.45, 0.42))
    var frame_mat := StandardMaterial3D.new()
    frame_mat.albedo_color = Color(0.02,0.025,0.03)
    frame_mat.metallic = 0.65
    frame_mat.roughness = 0.2
    frame_mat.emission_enabled = true
    frame_mat.emission = accent * 0.35
    for spec in [
        [Vector3(0.10,2.35,0.12),Vector3(-0.86,0.82,0)],
        [Vector3(0.10,2.35,0.12),Vector3(0.86,0.82,0)],
        [Vector3(1.82,0.10,0.12),Vector3(0,1.95,0)]
    ]:
        var n := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = spec[0]
        n.mesh = mesh
        n.position = spec[1]
        n.material_override = frame_mat
        add_child(n)
