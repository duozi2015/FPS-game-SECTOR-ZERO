extends GdUnitTestSuite

## T8/T9 集成：靶场场景 + 射击木桩 → Damageable 扣血 → 死亡（M1 核心闭环）

const RANGE_PATH := "res://scenes/arena/shooting_range.tscn"


func test_scene_has_three_dummies() -> void:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(2)
	var count := 0
	for body in runner.scene().find_children("*", "StaticBody3D", true, false):
		if body.has_node("Damageable"):
			count += 1
	assert_int(count).is_equal(3)


func test_shooting_dummy_applies_damage_and_kills() -> void:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	var dummy := runner.scene().get_node("Dummy2")  # 正前方 z=-8
	var dmg: Damageable = dummy.get_node("Damageable")
	var hit_count := [0]
	dmg.damaged.connect(func(_info: Dictionary) -> void: hit_count[0] += 1)
	var deaths := [0]
	dmg.died.connect(func() -> void: deaths[0] += 1)
	# 步枪 25 伤害 × 4 发 = 100 血；120 帧 ≈ 0.85s 实时 → 至少 10 发
	runner.simulate_action_press("shoot")
	await runner.simulate_frames(120)
	runner.simulate_action_release("shoot")
	assert_int(hit_count[0]).override_failure_message("命中次数不足").is_greater_equal(4)
	assert_int(deaths[0]).override_failure_message("木桩未死亡").is_equal(1)
	assert_float(dmg.health).is_equal(0.0)
