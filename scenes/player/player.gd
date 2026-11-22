class_name Player
extends CharacterBody3D

## 玩家控制器 —— 手感参数全部来自 MovementConfig（design.md §5-6）
## 调手感优先改 movement_config.gd，不改这里

@export var config: MovementConfig

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: WeaponBase = $Head/Camera3D/Rifle

var _jump_buffer := 0.0
var _coyote := 0.0
var _pitch := 0.0
var _landing_dip := 0.0  ## 落地镜头下压角（度），自动回弹


func _ready() -> void:
	add_to_group("player")
	if config == null:
		config = MovementConfig.new()
	weapon.shooter_body = self


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * config.mouse_sensitivity)
		_pitch = clampf(
			_pitch - motion.relative.y * config.mouse_sensitivity,
			-deg_to_rad(89.0), deg_to_rad(89.0))
		head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	# 射击输入（T7）
	if Input.is_action_pressed("shoot"):
		weapon.try_fire()

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint") and input.length_squared() > 0.0
	var speed := config.sprint_speed if sprinting else config.walk_speed

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

	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	move_and_slide()

	# 落地 dip：从空中落到地面的瞬间，镜头下压后回弹
	if not was_on_floor and is_on_floor() and fall_speed < -3.0:
		_landing_dip = config.landing_dip_degrees
	_landing_dip = lerpf(_landing_dip, 0.0, minf(10.0 * delta, 1.0))
	camera.rotation.x = deg_to_rad(-_landing_dip)

	# FOV 拉伸：速度感（design.md §6）
	var target_fov := config.sprint_fov if sprinting else config.base_fov
	camera.fov = lerpf(camera.fov, target_fov, minf(8.0 * delta, 1.0))
