extends StaticBody3D

## 靶场木桩：受击 → 伤害数字 + 命中音；击杀 → hit-stop + 碎片弹飞 + 震动（T12）

const DEBRIS_COUNT := 5
const KILL_SOUND := preload("res://assets/audio/kill.wav")
const DEBRIS_MESH_COLOR := Color(0.55, 0.5, 0.45)

@onready var _damageable: Damageable = $Damageable
@onready var _hit_sound: AudioStreamPlayer3D = $HitSound


func _ready() -> void:
	_damageable.damaged.connect(_on_damaged)
	_damageable.died.connect(_on_died)


func _on_damaged(info: Dictionary) -> void:
	# 挂到父节点（竞技场根）：木桩死后数字仍可存活
	DamageNumber.spawn(get_parent(), info["position"], info["amount"])
	_hit_sound.play()


func _on_died() -> void:
	HitStop.trigger(0.06)
	get_tree().call_group("fx_camera_shake", "trigger", 0.4)
	get_tree().call_group("ui_crosshair", "flash_kill")
	var container := Node3D.new()
	get_parent().add_child(container)
	container.global_position = global_position + Vector3(0, 1.0, 0)
	for i in DEBRIS_COUNT:
		container.add_child(_make_debris())
	var sound := AudioStreamPlayer3D.new()
	sound.stream = KILL_SOUND
	container.add_child(sound)
	sound.play()
	# 容器 2s 后整体清理（碎片各自 1.5s 后消失）
	var t := container.create_tween()
	t.tween_interval(2.0)
	t.tween_callback(container.queue_free)
	# 木桩本体退场
	queue_free()


func _make_debris() -> RigidBody3D:
	var rb := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	shape.shape = box
	rb.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DEBRIS_MESH_COLOR
	box_mesh.material = mat
	mesh.mesh = box_mesh
	rb.add_child(mesh)
	rb.position = Vector3(
		randf_range(-0.3, 0.3), randf_range(0.0, 0.5), randf_range(-0.3, 0.3))
	rb.linear_velocity = Vector3(
		randf_range(-3.0, 3.0), randf_range(3.0, 6.0), randf_range(-3.0, 3.0))
	rb.angular_velocity = Vector3(
		randf_range(-5.0, 5.0), randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
	var t := rb.create_tween()
	t.tween_interval(1.5)
	t.tween_callback(rb.queue_free)
	return rb
