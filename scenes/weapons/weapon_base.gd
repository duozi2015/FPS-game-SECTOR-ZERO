class_name WeaponBase
extends Node3D

## hitscan 武器基类（design.md §7）
## tracer / 枪声 / hit-stop 等反馈由订阅 fired 信号的 FX 系统实现
## 子类（霰弹枪等）只覆写 _apply_spread / _raycast 或调参数

signal fired(info: Dictionary)

@export var damage := 25.0
@export var fire_rate_rpm := 900.0
@export var spread_degrees := 1.0
@export var magazine_size := 30
@export var max_range := 200.0

@export_group("Spread Bloom")
@export var spread_bloom_per_shot := 0.5  ## 每发增加的散布（度）
@export var spread_recover_per_sec := 3.0  ## 每秒回落
@export var spread_bloom_max := 3.0

## 由 Player 在 _ready 注入，用于从射线中排除自己
var shooter_body: PhysicsBody3D

var ammo_in_mag := 0
var current_bloom := 0.0  ## 当前累计散布增量（度），准星联动读它

var _cooldown := 0.0

@onready var _shot_sound: AudioStreamPlayer3D = $ShotSound
@onready var _muzzle: Marker3D = $Muzzle


func _ready() -> void:
	ammo_in_mag = magazine_size


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	current_bloom = maxf(current_bloom - spread_recover_per_sec * delta, 0.0)


func try_fire() -> bool:
	if _cooldown > 0.0 or ammo_in_mag <= 0:
		return false
	_cooldown = 60.0 / fire_rate_rpm
	ammo_in_mag -= 1
	current_bloom = minf(current_bloom + spread_bloom_per_shot, spread_bloom_max)
	var info := _raycast(_apply_spread(_muzzle_dir()))
	_apply_hit(info)
	_spawn_muzzle_fx()
	Tracer.spawn(get_tree().root, _muzzle.global_position, info["position"])
	_shot_sound.play()
	fired.emit(info)
	return true


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


func _muzzle_dir() -> Vector3:
	return -global_transform.basis.z


func _apply_spread(dir: Vector3) -> Vector3:
	var total := spread_degrees + current_bloom
	var rad := deg_to_rad(total)
	var b := global_transform.basis
	return dir \
		.rotated(b.x, randf_range(-rad, rad)) \
		.rotated(b.y, randf_range(-rad, rad))


## 枪口火光：暖色点光 + 发光小球，50ms 内消失
func _spawn_muzzle_fx() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 4.0
	light.omni_range = 4.0
	light.position = _muzzle.position
	add_child(light)
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
	add_child(flash)
	for n: Node in [light, flash]:
		var t := n.create_tween()
		t.tween_interval(0.05)
		t.tween_callback(n.queue_free)


func _raycast(dir: Vector3) -> Dictionary:
	var origin := global_position
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range)
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
