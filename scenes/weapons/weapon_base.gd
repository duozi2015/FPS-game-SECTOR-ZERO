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

## 由 Player 在 _ready 注入，用于从射线中排除自己
var shooter_body: PhysicsBody3D

var ammo_in_mag := 0

var _cooldown := 0.0


func _ready() -> void:
	ammo_in_mag = magazine_size


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func try_fire() -> bool:
	if _cooldown > 0.0 or ammo_in_mag <= 0:
		return false
	_cooldown = 60.0 / fire_rate_rpm
	ammo_in_mag -= 1
	var info := _raycast(_apply_spread(_muzzle_dir()))
	_apply_hit(info)
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
	var rad := deg_to_rad(spread_degrees)
	var b := global_transform.basis
	return dir \
		.rotated(b.x, randf_range(-rad, rad)) \
		.rotated(b.y, randf_range(-rad, rad))


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
