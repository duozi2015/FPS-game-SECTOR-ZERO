extends EnemyBase

## Shooter 持枪手：主角同款步枪（大削版 hitscan）
## 削弱项：单发 4 伤（主角 25）、射速 2.2s 一发、0.6s 发光前摇、5° 瞄准误差、
## 无视线不开枪（掩体有效）
const RIFLE_SCENE := preload("res://scenes/weapons/rifle.tscn")

@export var aim_error_degrees := 5.0  ## 瞄准误差（度），远程自然脱靶


func _init() -> void:
	move_speed = 3.5
	attack_damage = 4.0
	attack_range = 40.0  # hitscan 远程
	attack_cooldown = 2.2
	attack_windup = 0.6  # 发光前摇，清晰可读
	attack_knockback = 1.5
	knockback_resist = 0.35
	stop_distance = 9.0


func _ready() -> void:
	super._ready()
	# 主角同款步枪模型（仅视觉，敌方开火逻辑在 _execute_attack）
	var rifle := RIFLE_SCENE.instantiate()
	add_child(rifle)
	rifle.position = Vector3(0.12, 0.65, -0.55)
	rifle.scale = Vector3(1.15, 1.15, 1.15)


## 覆写：削版 hitscan 步枪（掩体挡伤害，但弹道+枪声保留压制感）
func _execute_attack() -> void:
	if not _target_valid():
		return
	var from := global_position + Vector3(0, 0.8, 0) - global_transform.basis.z * 0.4
	var aim := target.global_position + Vector3(0, 1.2, 0)
	var dir := (aim - from).normalized()
	dir = dir.rotated(global_transform.basis.x, deg_to_rad(randf_range(-aim_error_degrees, aim_error_degrees)))
	dir = dir.rotated(Vector3.UP, deg_to_rad(randf_range(-aim_error_degrees, aim_error_degrees)))

	var space := get_world_3d().direct_space_state
	var los := PhysicsRayQueryParameters3D.create(from, from + dir * 45.0)
	los.exclude = [get_rid()]
	var hit := space.intersect_ray(los)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	var end: Vector3 = hit["position"]
	# 只有命中玩家才造成伤害
	var p_dmg := target.get_node_or_null("Damageable") as Damageable
	if collider == target and p_dmg:
		p_dmg.apply_damage({
			"damage": attack_damage,
			"position": from,
			"knockback": attack_knockback,
		})
	Tracer.spawn(get_tree().root, from, end)
	# 3D 定位枪声（音量调低：大削版听感）
	var s := AudioStreamPlayer3D.new()
	s.stream = preload("res://assets/audio/rifle_shot.wav")
	s.volume_db = -12.0
	get_parent().add_child(s)
	s.global_position = from
	s.play()
	var t := s.create_tween()
	t.tween_interval(0.4)
	t.tween_callback(s.queue_free)
