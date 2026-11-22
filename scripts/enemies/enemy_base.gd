class_name EnemyBase
extends CharacterBody3D

## 敌人基类：简单状态机 Chase/Attack/Hurt/Dead（design.md §8）
## 寻路策略：直线追击 + move_and_slide 滑墙（竞技场平坦，NavigationAgent 暂缓）
## 子类通过 _init 调参 + 覆写 _execute_attack()

signal state_changed(new_state: int)

enum State { CHASE, ATTACK, HURT, DEAD }

@export var move_speed := 4.0
@export var attack_damage := 10.0
@export var attack_range := 1.7
@export var attack_cooldown := 1.2
@export var attack_windup := 0.0  ## 攻击前摇（秒），期间发光预警
@export var attack_knockback := 2.0
@export var knockback_resist := 0.0  ## 0=全吃击退，1=免疫
@export var stop_distance := 0.0  ## 保持距离型（Shooter 用）
@export var points_worth := 1

var state: State = State.CHASE
var target: CharacterBody3D

var _cooldown := 0.0
var _windup := 0.0
var _windup_total := 0.0
var _hurt_time := 0.0
var _knockback_vel := Vector3.ZERO

@onready var _damageable: Damageable = $Damageable
@onready var _core: MeshInstance3D = $Core

const DEBRIS_COLOR := Color(0.45, 0.42, 0.4)
const KILL_SOUND := preload("res://assets/audio/kill.wav")


func _ready() -> void:
	add_to_group("enemies")
	target = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_damageable.damaged.connect(_on_damaged)
	_damageable.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	match state:
		State.CHASE:
			_do_chase(delta)
		State.ATTACK:
			_do_attack(delta)
		State.HURT:
			_do_hurt(delta)
		State.DEAD:
			return
	# 公共：重力 + 击退衰减 + 位移
	if not is_on_floor():
		velocity.y -= get_gravity().length() * delta
	velocity += _knockback_vel
	_knockback_vel = _knockback_vel.lerp(Vector3.ZERO, minf(8.0 * delta, 1.0))
	move_and_slide()


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)


func _target_valid() -> bool:
	return target != null and not target.is_queued_for_deletion()


func _do_chase(delta: float) -> void:
	if not _target_valid() or _player_dead():
		velocity.x = move_toward(velocity.x, 0, move_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * 8.0 * delta)
		return
	var to_target := _horizontal_to(target.global_position)
	var dist := to_target.length()
	if dist <= attack_range and _cooldown <= 0.0:
		_windup = attack_windup
		_windup_total = maxf(attack_windup, 0.01)
		_set_state(State.ATTACK)
		return
	if dist > stop_distance:
		var dir := to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * 8.0 * delta)


func _do_attack(delta: float) -> void:
	if not _target_valid() or _player_dead():
		_set_state(State.CHASE)
		return
	_face_target(delta)
	var dist := _horizontal_to(target.global_position).length()
	if dist > attack_range * 1.3:
		_set_state(State.CHASE)  # 目标脱离 → 放弃攻击
		return
	if _windup > 0.0:
		_windup -= delta
		_set_windup_glow(1.0 - _windup / _windup_total)
		if _windup <= 0.0:
			_set_windup_glow(0.0)
			_execute_attack()
			_cooldown = attack_cooldown
			_set_state(State.CHASE)
	else:
		# 无前摇（Grunt 贴脸即咬）：立即执行
		_execute_attack()
		_cooldown = attack_cooldown
		_set_state(State.CHASE)


func _do_hurt(delta: float) -> void:
	_hurt_time -= delta
	if _hurt_time <= 0.0:
		_set_state(State.CHASE)


func _face_target(delta: float) -> void:
	if not _target_valid():
		return
	var to_target := _horizontal_to(target.global_position)
	if to_target.length() > 0.1:
		var target_yaw := atan2(-to_target.x, -to_target.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(10.0 * delta, 1.0))


func _horizontal_to(pos: Vector3) -> Vector3:
	var v := pos - global_position
	v.y = 0
	return v


func _in_attack_range() -> bool:
	return _target_valid() and _horizontal_to(target.global_position).length() <= attack_range


func _player_dead() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	if p and "damageable" in p:
		return (p.damageable as Damageable).is_dead
	return false


## 受击：短暂硬直 + 击退 + 发光脉冲
func _on_damaged(info: Dictionary) -> void:
	_hurt_time = 0.12
	_set_state(State.HURT)
	var kb: float = info.get("knockback", 0.0) * (1.0 - knockback_resist)
	if kb > 0.0:
		var away: Vector3 = info.get("position", global_position)
		var dir := global_position - away
		dir.y = 0
		if dir.length() > 0.05:
			_knockback_vel += dir.normalized() * kb
	_flash_hit()


## 受击发光脉冲（子类可复用 _core）
func _flash_hit() -> void:
	_pulse_core(2.5)


func _set_windup_glow(progress: float) -> void:
	var mat := _ensure_override()
	mat.emission_energy_multiplier = progress * 3.5


func _pulse_core(energy: float) -> void:
	var mat := _ensure_override()
	mat.emission_energy_multiplier = energy
	var t := create_tween()
	t.tween_property(mat, "emission_energy_multiplier", 0.0, 0.15)


func _pulse_core_zero() -> void:
	_ensure_override()


func _ensure_override() -> StandardMaterial3D:
	if _core.material_override == null:
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.45, 0.2)
		mat.emission_energy_multiplier = 0.0
		_core.material_override = mat
	return _core.material_override as StandardMaterial3D


## 攻击执行（子类覆写）
func _execute_attack() -> void:
	if _in_attack_range() and _target_valid():
		var p := target.get_node_or_null("Damageable") as Damageable
		if p:
			p.apply_damage({
				"damage": attack_damage,
				"position": global_position,
				"knockback": attack_knockback,
			})


## 死亡：碎片 + hit-stop + 震动 + 连击 + 掉落（T17）
func _on_died() -> void:
	_set_state(State.DEAD)
	HitStop.trigger(0.06)
	get_tree().call_group("fx_camera_shake", "trigger", 0.4)
	get_tree().call_group("ui_crosshair", "flash_kill")
	get_tree().call_group("combo_system", "notify_kill")
	_spawn_debris()
	_spawn_drop()
	_play_kill_sound()
	queue_free()


func _spawn_debris() -> void:
	var container := Node3D.new()
	get_parent().add_child(container)
	container.global_position = global_position + Vector3(0, 0.8, 0)
	for i in 5:
		container.add_child(_make_debris())
	var t := container.create_tween()
	t.tween_interval(2.0)
	t.tween_callback(container.queue_free)


func _make_debris() -> RigidBody3D:
	var rb := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.25, 0.25, 0.25)
	shape.shape = box
	rb.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.25, 0.25, 0.25)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DEBRIS_COLOR
	box_mesh.material = mat
	mesh.mesh = box_mesh
	rb.add_child(mesh)
	rb.position = Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.4), randf_range(-0.3, 0.3))
	rb.linear_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(3.0, 6.0), randf_range(-3.0, 3.0))
	rb.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	var t := rb.create_tween()
	t.tween_interval(1.5)
	t.tween_callback(rb.queue_free)
	return rb


## 掉落规则（design.md §9：资源只从击杀出）——45% 血 / 45% 弹药 / 10% 无
func _spawn_drop() -> void:
	var roll := randf()
	var kind := ""
	if roll < 0.45:
		kind = "health"
	elif roll < 0.9:
		kind = "ammo"
	if kind == "":
		return
	var scene: PackedScene = load("res://scenes/systems/pickup.tscn")
	var pickup := scene.instantiate()
	pickup.kind = kind
	get_parent().add_child(pickup)
	pickup.global_position = global_position + Vector3(0, 0.6, 0)


func _play_kill_sound() -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = KILL_SOUND
	s.pitch_scale = _kill_pitch()
	get_parent().add_child(s)
	s.global_position = global_position
	s.play()
	var t := s.create_tween()
	t.tween_interval(0.6)
	t.tween_callback(s.queue_free)


func _kill_pitch() -> float:
	return 1.0
