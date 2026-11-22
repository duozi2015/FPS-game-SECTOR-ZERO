class_name Projectile
extends Area3D

## Shooter 的能量弹：直线飞行，命中玩家扣血，3s 自毁

var velocity := Vector3.ZERO
var damage := 15.0

const LIFETIME := 3.0


func launch(target_pos: Vector3, speed: float, dmg: float) -> void:
	damage = dmg
	var dir := (target_pos - global_position).normalized()
	velocity = dir * speed
	# 面向飞行方向（视觉）
	look_at(target_pos)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var t := create_tween()
	t.tween_interval(LIFETIME)
	t.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	position += velocity * delta


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		return  # 不打自己人
	var node := body as Node
	var dmg: Damageable = null
	if node and node.has_method("apply_damage"):
		dmg = node as Damageable
	elif node and node.has_node("Damageable"):
		dmg = node.get_node("Damageable") as Damageable
	if dmg:
		dmg.apply_damage({
			"damage": damage,
			"position": global_position,
			"knockback": 1.5,
		})
	queue_free()
