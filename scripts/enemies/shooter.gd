extends EnemyBase

## Shooter 炮塔机：保持 8m 距离，0.8s 发光前摇后射弹道（design.md §8）

const PROJECTILE_SCENE := preload("res://scenes/enemies/projectile.tscn")

@export var projectile_speed := 12.0


func _init() -> void:
	move_speed = 3.5
	attack_damage = 15.0
	attack_range = 30.0  # 远程：在攻击距离内就会开火
	attack_cooldown = 2.4
	attack_windup = 0.8  # 发光前摇，清晰可读
	attack_knockback = 0.0
	knockback_resist = 0.35
	stop_distance = 8.0


## 覆写：发射投射物而非近战
func _execute_attack() -> void:
	if not _target_valid():
		return
	var p := PROJECTILE_SCENE.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 0.7, 0) - global_transform.basis.z * 0.5
	p.launch(target.global_position + Vector3(0, 1.2, 0), projectile_speed, attack_damage)
