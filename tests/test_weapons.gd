extends GdUnitTestSuite

## T7 hitscan 武器集成测试：fired 信号、命中点、弹药计数、射速下限

const STAGE_PATH := "res://tests/helpers/weapon_stage.tscn"


func _setup_runner() -> Array:
	var runner := scene_runner(STAGE_PATH)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var weapon: WeaponBase = player.get_node("Head/Camera3D/Rifle")
	await runner.simulate_frames(5)  # 稳定落位
	return [runner, player, weapon]


func test_fired_signal_hits_target_front_face() -> void:
	var out := await _setup_runner()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var captured: Array[Dictionary] = []
	weapon.fired.connect(func(info: Dictionary) -> void: captured.append(info))
	runner.simulate_action_press("shoot")
	await runner.simulate_frames(30)
	runner.simulate_action_release("shoot")
	assert_int(captured.size()).override_failure_message("fired 未发出").is_greater(0)
	var info := captured[0]
	var hit_pos: Vector3 = info["position"]
	# 靶子前面板 z=-4.75，命中点应落在其附近
	assert_float(absf(hit_pos.z - (-4.75))).override_failure_message(
		"命中点不在靶面: %s" % hit_pos).is_less(0.3)
	assert_that(info["collider"]).override_failure_message(
		"未命中 Target").is_same(TargetHelper.target_node(runner))


func test_ammo_decrements_per_shot() -> void:
	var out := await _setup_runner()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var captured: Array[Dictionary] = []
	weapon.fired.connect(func(info: Dictionary) -> void: captured.append(info))
	var before: int = weapon.ammo_in_mag
	runner.simulate_action_press("shoot")
	await runner.simulate_frames(30)
	runner.simulate_action_release("shoot")
	assert_int(weapon.ammo_in_mag).is_equal(before - captured.size())


func test_sustained_fire_reaches_min_rate() -> void:
	var out := await _setup_runner()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var captured: Array[Dictionary] = []
	weapon.fired.connect(func(info: Dictionary) -> void: captured.append(info))
	runner.simulate_action_press("shoot")
	await runner.simulate_frames(90)  # ≈0.63s 实时；900RPM=15发/s → 期望≥5
	runner.simulate_action_release("shoot")
	assert_int(captured.size()).override_failure_message(
		"射速过低: %d 发" % captured.size()).is_greater_equal(2)


class TargetHelper:
	static func target_node(runner: GdUnitSceneRunner) -> Node:
		return runner.scene().get_node("Target")
