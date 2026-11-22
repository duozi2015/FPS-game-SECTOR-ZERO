extends GdUnitTestSuite

## M3 城市室外场景验收：刷怪闭环复用（波次 → 清波 → 下一波）

const CITY := "res://scenes/arena/city.tscn"


func test_city_wave_loop_runs() -> void:
	var runner := scene_runner(CITY)
	var wm := runner.scene().get_node("WaveManager") as WaveManager
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and wm.alive == 0:
		await runner.simulate_frames(1)
	assert_int(wm.alive).override_failure_message("城市场景未刷怪").is_greater(0)
	# 清完第一波
	var clear_deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < clear_deadline and (wm.alive > 0 or wm.pending > 0):
		for enemy in runner.scene().get_tree().get_nodes_in_group("enemies"):
			(enemy.get_node("Damageable") as Damageable).apply_damage({"damage": 999.0})
		await runner.simulate_frames(5)
	deadline = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and wm.wave < 2:
		await runner.simulate_frames(1)
	assert_int(wm.wave).override_failure_message(
		"城市场景清波后未推进到第 2 波").is_greater_equal(2)


func test_city_has_buildings_as_cover() -> void:
	var runner := scene_runner(CITY)
	await runner.simulate_frames(2)
	# 城市至少 6 栋楼（StaticBody3D 数量含地面/障碍，按命名找 B* 前缀）
	var buildings := 0
	for body in runner.scene().find_children("B*", "StaticBody3D", true, false):
		buildings += 1
	assert_int(buildings).override_failure_message("楼房数量不足").is_greater_equal(6)
