extends EnemyBase

## Grunt 无人机狗：高速冲脸近战，最脆，吃满击退（design.md §8）


func _init() -> void:
	move_speed = 5.5
	attack_damage = 10.0
	attack_range = 1.7
	attack_cooldown = 1.0
	attack_windup = 0.0  # 贴脸立刻咬
	attack_knockback = 2.0
	knockback_resist = 0.1


func _kill_pitch() -> float:
	return 1.3  # 小体型的尖锐击杀音
