extends GdUnitTestSuite

## T16 波次刷怪集成：开局即刷、同屏上限、清波 → 休整 → 下一波

const ARENA := "res://scenes/arena/arena.tscn"


func test_arena_starts_wave_and_spawns() -> void:
	var runner := scene_runner(ARENA)
	var wm := runner.scene().get_node("WaveManager") as WaveManager
	var started := [0]
	wm.wave_started.connect(func(w: int, _t: int) -> void: started[0] = w)
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and wm.alive == 0:
		await runner.simulate_frames(1)
	assert_int(wm.wave).override_failure_message("第一波未开始").is_greater_equal(1)
	assert_int(wm.alive).override_failure_message("没有敌人被刷出").is_greater(0)
	assert_int(wm.alive).is_less_equal(WaveManager.MAX_ALIVE)
	# 清理：杀到 alive==0 且队列排空（波次是逐帧补刷的，单次遍历杀不干净）
	var clear_deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < clear_deadline and (wm.alive > 0 or wm.pending > 0):
		for enemy in runner.scene().get_tree().get_nodes_in_group("enemies"):
			(enemy.get_node("Damageable") as Damageable).apply_damage({"damage": 999.0})
		await runner.simulate_frames(5)
	# 清波 → 5s 休整 → 第二波
	deadline = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and wm.wave < 2:
		await runner.simulate_frames(1)
	assert_int(wm.wave).override_failure_message(
		"清波后未推进到第 2 波").is_greater_equal(2)
	assert_int(started[0]).is_equal(2)


func test_player_death_shows_game_over_and_stops_waves() -> void:
	var runner := scene_runner(ARENA)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var dmg := player.get_node("Damageable") as Damageable
	var wm := runner.scene().get_node("WaveManager") as WaveManager
	dmg.apply_damage({"damage": 999.0})
	await runner.simulate_frames(5)
	assert_bool(player.dead).override_failure_message("玩家未进入死亡态").is_true()
	var wave_before: int = wm.wave
	await runner.simulate_frames(60)  # 死亡后波次不应推进
	assert_int(wm.wave).override_failure_message("死亡后波次仍在推进").is_equal(wave_before)
	var hud := runner.scene().get_node("HUD")
	var go_label: Label = hud.get_node("Control/GameOverLabel")
	assert_bool(go_label.visible).override_failure_message("GAME OVER 未显示").is_true()
