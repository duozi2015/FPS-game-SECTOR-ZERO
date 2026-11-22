extends GdUnitTestSuite

## T15 敌人系统验收：追击伤害 / 远程弹道 / 抗击退 / 死亡清理

const STAGE := "res://tests/helpers/enemy_stage.tscn"
const GRUNT := preload("res://scenes/enemies/grunt.tscn")
const SHOOTER := preload("res://scenes/enemies/shooter.tscn")
const BRUTE := preload("res://scenes/enemies/brute.tscn")


func _player_hp(runner: GdUnitSceneRunner) -> Damageable:
	var player := runner.scene().get_node("Player") as CharacterBody3D
	return player.get_node("Damageable") as Damageable


func _spawn(runner: GdUnitSceneRunner, scene: PackedScene, pos: Vector3) -> CharacterBody3D:
	var enemy := scene.instantiate()
	runner.scene().add_child(enemy)
	enemy.global_position = pos
	return enemy


func _await_player_hp_below(runner: GdUnitSceneRunner, threshold: float, timeout_ms := 8000) -> bool:
	var dmg := _player_hp(runner)
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await runner.simulate_frames(1)
		if dmg.health < threshold:
			return true
	return false


func test_grunt_chases_and_damages_player() -> void:
	var runner := scene_runner(STAGE)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var grunt := _spawn(runner, GRUNT, player.global_position + Vector3(3, 0, 0))
	var reached := await _await_player_hp_below(runner, 100.0)
	assert_bool(reached).override_failure_message(
		"Grunt 未能追击并伤害玩家").is_true()
	grunt.queue_free()


func test_shooter_projectile_hits_player() -> void:
	var runner := scene_runner(STAGE)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var shooter := _spawn(runner, SHOOTER, player.global_position + Vector3(0, 0, -8))
	var reached := await _await_player_hp_below(runner, 100.0, 10000)
	assert_bool(reached).override_failure_message(
		"Shooter 弹道未能命中玩家").is_true()
	shooter.queue_free()


func test_brute_knockback_resist() -> void:
	var runner := scene_runner(STAGE)
	await runner.simulate_frames(5)
	var brute := _spawn(runner, BRUTE, Vector3(0, 0, 0))
	await runner.simulate_frames(3)
	# 无抗性时 10 击退应产生 ~10 m/s 速度；0.85 抗性 → ~1.5
	(brute.get_node("Damageable") as Damageable).apply_damage(
		{"damage": 10.0, "knockback": 10.0, "position": Vector3(0, 0, 3)})
	# idle 帧可能不含物理 tick：轮询等击退速度出现
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and absf(brute.velocity.z) < 0.1:
		await runner.simulate_frames(1)
	assert_float(brute.velocity.z).override_failure_message(
		"抗击退未生效: vz=%.2f" % brute.velocity.z).is_greater(-3.0)
	assert_float(brute.velocity.z).is_less(-0.2)
	brute.queue_free()


func test_enemy_death_frees_and_counts() -> void:
	var runner := scene_runner(STAGE)
	await runner.simulate_frames(5)
	var brute := _spawn(runner, BRUTE, Vector3(0, 0, 0))
	var dmg := brute.get_node("Damageable") as Damageable
	var deaths := [0]
	dmg.died.connect(func() -> void: deaths[0] += 1)
	dmg.apply_damage({"damage": 999.0})
	await runner.simulate_frames(3)
	assert_int(deaths[0]).is_equal(1)
	# 死亡即释放（碎片/掉落已托付给场景根）
	var still_there := is_instance_valid(brute) and not brute.is_queued_for_deletion()
	assert_bool(still_there).override_failure_message("死亡敌人未被清理").is_false()


func test_states_progress() -> void:
	var runner := scene_runner(STAGE)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var grunt := _spawn(runner, GRUNT, player.global_position + Vector3(1.5, 0, 0))
	# 贴脸（<attack_range 1.7m）→ 第一帧即进入 ATTACK（windup=0 立即执行完回 CHASE）
	var saw_attack := [false]
	grunt.state_changed.connect(func(s: int) -> void:
		if s == EnemyBase.State.ATTACK:
			saw_attack[0] = true)
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and not saw_attack[0]:
		await runner.simulate_frames(1)
	assert_bool(saw_attack[0]).override_failure_message("未进入攻击状态").is_true()
	grunt.queue_free()
