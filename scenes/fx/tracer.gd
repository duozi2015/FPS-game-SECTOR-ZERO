class_name Tracer
extends MeshInstance3D

## hitscan 电光轨迹：从枪口到命中点，80ms 内淡出（design.md §5）

static func spawn(parent: Node, from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.1:
		return
	var n := Tracer.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.012
	mesh.bottom_radius = 0.012
	mesh.height = dist
	mesh.radial_segments = 6
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.4, 0.9)
	mesh.material = mat
	n.mesh = mesh
	parent.add_child(n)
	# 圆柱默认沿 Y 轴；先对准再定位
	n.look_at_from_position(from, to)  # -Z 朝向目标 → 需转 90°
	n.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(90))
	n.position = (from + to) * 0.5
	var tween := n.create_tween()
	tween.tween_property(n, "transparency", 1.0, 0.08)
	tween.tween_callback(n.queue_free)
