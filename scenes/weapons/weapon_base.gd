class_name WeaponBase
extends Node3D

## hitscan 武器基类（design.md §7 + M1.6 开镜/检视）
## 节点结构：Rifle → Rig(位姿+bob+sway) → Twist(检视动画) → 部件
## tracer / 枪声 / hit-stop 等反馈由订阅 fired 信号的 FX 系统实现

signal fired(info: Dictionary)
signal ammo_changed(current: int)
signal reloaded()
signal inspect_finished()

@export var damage := 25.0
@export var fire_rate_rpm := 900.0
@export var spread_degrees := 1.0
@export var magazine_size := 30
@export var max_range := 200.0
@export var reload_time := 1.6  ## 自动换弹时长（秒）
@export var pellets := 1  ## 每次扣扳机的弹丸数（霰弹枪=8）
@export var pellet_damage := 12.0  ## 多弹丸时的单弹丸伤害

@export_group("Spread Bloom")
@export var spread_bloom_per_shot := 0.5  ## 每发增加的散布（度）
@export var spread_recover_per_sec := 3.0  ## 每秒回落
@export var spread_bloom_max := 3.0

@export_group("ADS")
@export var hip_position := Vector3(0.25, -0.22, -0.5)
@export var hip_rotation_deg := Vector3(0, -8, 2)
@export var ads_position := Vector3(0, -0.125, -0.3)  ## 与机械瞄具对齐
@export var ads_time := 0.18  ## 开镜过渡时长（秒）
@export var ads_spread_multiplier := 0.3  ## 开镜散布系数

@export_group("Weapon Feel")
@export var bob_amplitude := 0.014  ## 走路 bob 幅度（米）
@export var bob_frequency := 9.0
@export var sway_scale := 0.045  ## 鼠标甩动幅度（米）
@export var sway_lerp_speed := 8.0

## 由 Player 在 _ready 注入，用于从射线中排除自己
var shooter_body: PhysicsBody3D

var ammo_in_mag := 0
var current_bloom := 0.0  ## 当前累计散布增量（度），准星联动读它
var aiming := false
var ads_blend := 0.0  ## 0=腰射 1=开镜，平滑过渡

var _cooldown := 0.0
var _reloading := false
var _inspecting := false
var _bob_t := 0.0
var _sway := Vector2.ZERO  ## 当前 sway 偏移
var _sway_target := Vector2.ZERO

@onready var _rig: Node3D = $Rig
@onready var _twist: Node3D = $Rig/Twist
@onready var _shot_sound: AudioStreamPlayer3D = $ShotSound
@onready var _empty_sound: AudioStreamPlayer3D = $EmptySound
@onready var _reload_sound: AudioStreamPlayer3D = $ReloadSound
@onready var _muzzle: Marker3D = $Rig/Twist/Muzzle


func _ready() -> void:
	ammo_in_mag = magazine_size


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	current_bloom = maxf(current_bloom - spread_recover_per_sec * delta, 0.0)


func _process(delta: float) -> void:
	_update_ads_blend(delta)
	_update_pose(delta)


func set_aiming(enabled: bool) -> void:
	aiming = enabled and not _inspecting  ## 检视期间禁止开镜


## 切换式开镜（触控板友好）：按一下开、再按一下关
func toggle_aim() -> void:
	if _inspecting:
		return
	set_aiming(not aiming)


## 开镜散布系数（准星/命中共用）
func effective_spread_multiplier() -> float:
	return lerpf(1.0, ads_spread_multiplier, ads_blend)


## 检视动画：F 触发，Tween 序列转枪展示（M1.6）
func trigger_inspect() -> void:
	if _inspecting or aiming:
		return
	_inspecting = true
	var t := create_tween()
	t.tween_property(_twist, "rotation_degrees", Vector3(-14, 150, 12), 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_interval(0.35)
	t.tween_property(_twist, "rotation_degrees", Vector3(6, -40, -8), 0.4) \
		.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_twist, "rotation_degrees", Vector3.ZERO, 0.35) \
		.set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_inspecting = false
		inspect_finished.emit())


## 鼠标甩动输入（由 Player 转发）
func add_look_delta(motion: Vector2) -> void:
	_sway_target = Vector2(
		clampf(-motion.x * 0.003, -sway_scale, sway_scale),
		clampf(-motion.y * 0.003, -sway_scale, sway_scale))


func try_fire() -> bool:
	if _cooldown > 0.0:
		return false
	if ammo_in_mag <= 0:
		_start_reload()
		return false
	_cooldown = 60.0 / fire_rate_rpm
	ammo_in_mag -= 1
	current_bloom = minf(current_bloom + spread_bloom_per_shot, spread_bloom_max)
	ammo_changed.emit(ammo_in_mag)
	_spawn_muzzle_fx()
	_shot_sound.play()
	# 多弹丸（霰弹枪）：每弹丸独立射线/命中/信号
	for i in pellets:
		var info := _raycast(_apply_spread(_muzzle_dir()))
		if pellets > 1:
			info["damage"] = pellet_damage
		_apply_hit(info)
		Tracer.spawn(get_tree().root, _muzzle.global_position, info["position"])
		fired.emit(info)
	return true


## 补满弹匣（弹药拾取用），并取消进行中的换弹
func refill() -> void:
	_reloading = false
	ammo_in_mag = magazine_size
	ammo_changed.emit(ammo_in_mag)


## 空仓自动换弹（design.md §5：资源循环需要明确的弹药反馈）
func _start_reload() -> void:
	if _reloading:
		return
	_reloading = true
	_empty_sound.play()
	var t := create_tween()
	t.tween_interval(reload_time)
	t.tween_callback(func() -> void:
		_reloading = false
		ammo_in_mag = magazine_size
		ammo_changed.emit(ammo_in_mag)
		_reload_sound.play()
		reloaded.emit())


func _update_ads_blend(delta: float) -> void:
	var target := 1.0 if aiming else 0.0
	ads_blend = move_toward(ads_blend, target, delta / maxf(ads_time, 0.01))


## 位姿合成：hip/ads 插值 + 走路 bob + 鼠标 sway + 待机呼吸
func _update_pose(delta: float) -> void:
	# 一元 smoothstep（端点减速，开镜手感更顺）
	var b := ads_blend * ads_blend * (3.0 - 2.0 * ads_blend)
	var vel := Vector3.ZERO
	var on_floor := false
	if shooter_body is CharacterBody3D:
		vel = (shooter_body as CharacterBody3D).velocity
		on_floor = (shooter_body as CharacterBody3D).is_on_floor()

	# 走路 bob：水平速度驱动，开镜时衰减 80%
	var hspeed := Vector2(vel.x, vel.z).length()
	if on_floor and hspeed > 0.5:
		_bob_t += delta * bob_frequency * clampf(hspeed / 7.5, 0.5, 1.6)
	var bob_amp := bob_amplitude * (1.0 - b * 0.8) * clampf(hspeed / 7.5, 0.0, 1.2)
	var bob := Vector3(cos(_bob_t * 0.5) * bob_amp * 0.6,
		sin(_bob_t) * bob_amp, 0)

	# 待机呼吸：静止时极轻微起伏
	var idle := Vector3(0, sin(Time.get_ticks_msec() / 1000.0 * 1.7) * 0.0025 * (1.0 - b * 0.7), 0)

	# sway 回中
	_sway = _sway.lerp(_sway_target, minf(sway_lerp_speed * delta, 1.0))
	_sway_target = _sway_target.lerp(Vector2.ZERO, minf(sway_lerp_speed * 0.6 * delta, 1.0))

	_rig.position = hip_position.lerp(ads_position, b) + bob + idle + Vector3(_sway.x, _sway.y, 0)
	var base_rot := hip_rotation_deg.lerp(Vector3.ZERO, b)
	_rig.rotation_degrees = Vector3(
		base_rot.x + _sway.y * 40.0,
		base_rot.y + _sway.x * 40.0,
		base_rot.z)


func _muzzle_dir() -> Vector3:
	return -global_transform.basis.z


func _apply_spread(dir: Vector3) -> Vector3:
	var total := (spread_degrees + current_bloom) * effective_spread_multiplier()
	var rad := deg_to_rad(total)
	var b := global_transform.basis
	return dir \
		.rotated(b.x, randf_range(-rad, rad)) \
		.rotated(b.y, randf_range(-rad, rad))


## 命中结算：collider 自身可受击，或其子节点挂 Damageable
func _apply_hit(info: Dictionary) -> void:
	var collider: Object = info["collider"]
	if collider is not Node:
		return
	var body := collider as Node
	if body.has_method("apply_damage"):
		body.apply_damage(info)
		info["damageable"] = body
		return
	for child in body.find_children("*", "Damageable", false, false):
		child.apply_damage(info)
		info["damageable"] = child
		return


## 枪口火光：暖色点光 + 发光小球，50ms 内消失
func _spawn_muzzle_fx() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 4.0
	light.omni_range = 4.0
	light.position = _muzzle.position
	_twist.add_child(light)
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mesh.material = mat
	flash.mesh = mesh
	flash.position = _muzzle.position
	_twist.add_child(flash)
	for n: Node in [light, flash]:
		var t := n.create_tween()
		t.tween_interval(0.05)
		t.tween_callback(n.queue_free)


func _raycast(dir: Vector3) -> Dictionary:
	# 射线从相机中心发出（准星精确）；tracer 从枪口画只是视觉效果
	var origin := global_position
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + dir * max_range)
	if shooter_body:
		query.exclude = [shooter_body.get_rid()]
	var result := space.intersect_ray(query)
	if result:
		return {
			"position": result.position,
			"normal": result.normal,
			"collider": result.collider,
			"damage": damage,
		}
	return {
		"position": origin + dir * max_range,
		"normal": Vector3.ZERO,
		"collider": null,
		"damage": damage,
	}
