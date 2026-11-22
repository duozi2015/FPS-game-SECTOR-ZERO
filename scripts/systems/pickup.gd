class_name Pickup
extends Area3D

## 击杀掉落物（design.md §9：资源只从击杀出）：血包/弹药，磁吸拾取

const HEALTH_RESTORE := 25.0
const MAGNET_RANGE := 3.0
const MAGNET_SPEED := 9.0
const LIFETIME := 12.0

@export var kind := "health"  ## "health" | "ammo"

var _player: CharacterBody3D
var _collected := false


func _ready() -> void:
	add_to_group("pickups")
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	body_entered.connect(_on_body_entered)
	# 外观按类型区分
	var mesh := $MeshInstance3D as MeshInstance3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.3) if kind == "health" else Color(1.0, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = (Color(1.0, 0.2, 0.15) if kind == "health" else Color(1.0, 0.7, 0.15))
	mat.emission_energy_multiplier = 1.6
	mesh.material_override = mat
	# 12s 后淡出消失
	var t := create_tween()
	t.tween_interval(LIFETIME)
	t.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if _collected or _player == null:
		return
	# 磁吸：接近玩家时飞向玩家
	var to_player := _player.global_position + Vector3(0, 0.9, 0) - global_position
	if to_player.length() < MAGNET_RANGE:
		global_position += to_player.normalized() * MAGNET_SPEED * delta
	else:
		rotate_y(delta * 2.5)  # 待机自转
		# 悬浮
		position.y += sin(Time.get_ticks_msec() / 300.0) * 0.003


func _on_body_entered(body: Node3D) -> void:
	if _collected or body != _player:
		return
	_collected = true
	if kind == "health":
		var d := body.get_node("Damageable") as Damageable
		if d:
			d.heal(HEALTH_RESTORE)
	elif kind == "ammo":
		if "weapon" in body:
			(body.weapon as WeaponBase).refill()
	# 拾取音（不随本节点销毁中断）
	var s := AudioStreamPlayer3D.new()
	s.stream = preload("res://assets/audio/pickup.wav")
	get_parent().add_child(s)
	s.global_position = global_position
	s.play()
	var st := s.create_tween()
	st.tween_interval(0.4)
	st.tween_callback(s.queue_free)
	queue_free()
