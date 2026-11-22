extends GdUnitTestSuite

## T10 击中三件套验收：伤害数字 + hitmarker + 命中音（design.md §5：三者同帧）

const RANGE_PATH := "res://scenes/arena/shooting_range.tscn"


func _burst_fire(runner: GdUnitSceneRunner, frames := 120) -> void:
	runner.simulate_action_press("shoot")
	await runner.simulate_frames(frames)
	runner.simulate_action_release("shoot")


func test_hit_spawns_damage_number() -> void:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	await _burst_fire(runner)
	# DamageNumber 是 Label3D 子类，浮空 0.85s 内可查到
	var numbers := runner.scene().find_children("*", "Label3D", true, false)
	assert_int(numbers.size()).override_failure_message(
		"伤害数字未生成").is_greater(0)


func test_hitmarker_flashes_on_hit() -> void:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	var crosshair := runner.scene().get_node("CrosshairLayer/Control")
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var hit_events := [0]
	(player.weapon as WeaponBase).fired.connect(
		func(info: Dictionary) -> void:
			if info.get("damageable"):
				hit_events[0] += 1)
	# 事件驱动：命中即停 → 衰减几乎为零，alpha 必然 > 0
	runner.simulate_action_press("shoot")
	for i in 600:
		await runner.simulate_frames(1)
		if hit_events[0] >= 1:
			break
	runner.simulate_action_release("shoot")
	assert_int(hit_events[0]).override_failure_message("未命中").is_greater(0)
	assert_float(crosshair._hit_alpha).override_failure_message(
		"hitmarker 未闪").is_greater(0.0)


func test_hit_sound_stream_assigned() -> void:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(2)
	var dummy := runner.scene().get_node("Dummy2")
	var sound := dummy.get_node("HitSound") as AudioStreamPlayer3D
	assert_object(sound.stream).override_failure_message(
		"命中音未配置").is_not_null()
