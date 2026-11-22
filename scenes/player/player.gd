class_name Player
extends CharacterBody3D

## 玩家控制器 —— 手感参数全部来自 MovementConfig（design.md §5-6）
## M2：双武器切枪（1/2）、血量死亡、重开

signal active_weapon_changed(weapon: WeaponBase)
signal player_died()

@export var config: MovementConfig

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var damageable: Damageable = $Damageable

var weapons: Array[WeaponBase] = []
var weapon: WeaponBase  ## 当前激活武器
var dead := false

var _jump_buffer := 0.0
var _coyote := 0.0
var _pitch := 0.0
var _landing_dip := 0.0  ## 落地镜头下压角（度），自动回弹
var _recoil_deg := 0.0  ## 开火视觉上抬（度），自动回落

const RECOIL_KICK_DEG := 1.2  ## 每发上抬
const RECOIL_KICK_MAX := 3.0
const RECOIL_RECOVER_SPEED := 14.0  ## 度/秒回落


func _ready() -> void:
	add_to_group("player")
	if config == null:
		config = MovementConfig.new()
	weapons = [
		$Head/Camera3D/Rifle as WeaponBase,
		$Head/Camera3D/Shotgun as WeaponBase,
	]
	for w in weapons:
		w.shooter_body = self
		w.fired.connect(_on_weapon_fired)
		w.visible = false
	weapon = weapons[0]
	weapon.visible = true
	# FPS 标准鼠标捕获：光标锁定屏幕中心，relative 才连续可靠
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	damageable.died.connect(_on_player_died)


func _switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or weapons[index] == weapon:
		return
	weapon.visible = false
	weapon = weapons[index]
	weapon.visible = true
	active_weapon_changed.emit(weapon)


func _on_weapon_fired(_info: Dictionary) -> void:
	_recoil_deg = minf(_recoil_deg + RECOIL_KICK_DEG, RECOIL_KICK_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		if event.is_action_pressed("restart"):
			get_tree().reload_current_scene()
		elif event.is_action_pressed("menu"):
			get_tree().change_scene_to_file("res://scenes/ui/menu.tscn")
		return
	if event.is_action_pressed("ui_cancel"):
		# Esc 释放/捕获鼠标（释放后可点窗口控制）
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event.is_action_pressed("aim"):
		weapon.toggle_aim()  # 切换式开镜（触控板友好）
		return
	if event.is_action_pressed("inspect"):
		weapon.trigger_inspect()
		return
	if event.is_action_pressed("weapon_1"):
		_switch_weapon(0)
		return
	if event.is_action_pressed("weapon_2"):
		_switch_weapon(1)
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# 开镜时灵敏度按 ads_sensitivity_scale 收缩
		var sens := config.mouse_sensitivity * lerpf(
			1.0, config.ads_sensitivity_scale, weapon.ads_blend)
		rotate_y(-motion.relative.x * sens)
		_pitch = clampf(
			_pitch - motion.relative.y * sens,
			-deg_to_rad(89.0), deg_to_rad(89.0))
		weapon.add_look_delta(motion.relative)


func _on_player_died() -> void:
	dead = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_group("fx_camera_shake", "trigger", 0.8)
	get_tree().call_group("wave_manager", "stop")  # 死亡冻结波次推进
	var wave := 0
	var wm := get_tree().get_first_node_in_group("wave_manager")
	if wm:
		wave = (wm as WaveManager).wave
	get_tree().call_group("ui_hud", "show_game_over", wave)


func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= get_gravity().length() * delta
		move_and_slide()
		return
	# 射击输入（T7）；开镜为 L 切换式，在 _unhandled_input 处理
	if Input.is_action_pressed("shoot"):
		weapon.try_fire()

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint") and input.length_squared() > 0.0
	var speed := config.sprint_speed if sprinting else config.walk_speed
	# 开镜移速收缩（M1.6）
	speed *= lerpf(1.0, config.ads_move_multiplier, weapon.ads_blend)

	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 10.0 * delta)

	# 重力
	if not is_on_floor():
		velocity.y -= get_gravity().length() * delta

	# 跳跃缓冲：起跳意图保留 jump_buffer_time 秒，落地瞬间自动起跳
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = config.jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)

	# 土狼时间：离地后 coyote_time 秒内仍可起跳（悬崖边缘手感）
	if is_on_floor():
		_coyote = config.coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = config.jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0

	# 视角统一写入：基础俯仰 + 开火后坐上抬（rotation.x 负 = 抬头）
	_recoil_deg = maxf(_recoil_deg - RECOIL_RECOVER_SPEED * delta, 0.0)
	head.rotation.x = _pitch - deg_to_rad(_recoil_deg)

	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	move_and_slide()

	# 落地 dip：从空中落到地面的瞬间，镜头下压后回弹
	if not was_on_floor and is_on_floor() and fall_speed < -3.0:
		_landing_dip = config.landing_dip_degrees
	_landing_dip = lerpf(_landing_dip, 0.0, minf(10.0 * delta, 1.0))
	camera.rotation.x = deg_to_rad(-_landing_dip)

	# FOV：速度拉伸 + 开镜缩放（design.md §6 / M1.6）
	var target_fov := config.sprint_fov if sprinting else config.base_fov
	target_fov = lerpf(target_fov, config.ads_fov, weapon.ads_blend)
	camera.fov = lerpf(camera.fov, target_fov, minf(8.0 * delta, 1.0))
