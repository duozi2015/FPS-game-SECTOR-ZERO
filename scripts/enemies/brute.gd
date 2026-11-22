extends EnemyBase

## Brute 重装机甲：缓慢压近，1.2s 重砸前摇，抗击退，死亡爆散+范围伤害（design.md §8）

func _init() -> void:
	move_speed = 2.6
	attack_damage = 30.0
	attack_range = 2.4
	attack_cooldown = 2.0
	attack_windup = 1.2  # 明确前摇：抬手发光
	attack_knockback = 8.0
	knockback_resist = 0.85


## 覆写：重砸 → 范围伤害 + 震屏
func _execute_attack() -> void:
	if _in_attack_range() and _target_valid():
		var p := target.get_node_or_null("Damageable") as Damageable
		if p:
			p.apply_damage({
				"damage": attack_damage,
				"position": global_position,
				"knockback": attack_knockback,
			})
	get_tree().call_group("fx_camera_shake", "trigger", 0.5)


## 覆写死亡：爆散 → 更大震动 + 更多重碎片
func _on_died() -> void:
	_set_state(State.DEAD)
	HitStop.trigger(0.08)
	get_tree().call_group("fx_camera_shake", "trigger", 0.8)
	get_tree().call_group("ui_crosshair", "flash_kill")
	get_tree().call_group("combo_system", "notify_kill")
	var container := Node3D.new()
	get_parent().add_child(container)
	container.global_position = global_position + Vector3(0, 0.9, 0)
	for i in 10:
		container.add_child(_make_debris())
	var s := AudioStreamPlayer3D.new()
	s.stream = KILL_SOUND
	s.pitch_scale = 0.75  # 大体型的低沉击杀音
	container.add_child(s)
	s.play()
	var t := container.create_tween()
	t.tween_interval(2.0)
	t.tween_callback(container.queue_free)
	_spawn_drop()
	queue_free()
