extends GdUnitTestSuite

## T12 击杀爽感包验收：碎片弹飞 + hit-stop 恢复 + 镜头震动 + 击杀音（design.md §5）

const RANGE_PATH := "res://scenes/arena/shooting_range.tscn"


func _kill_dummy2(runner: GdUnitSceneRunner) -> Dictionary:
	var dummy := runner.scene().get_node("Dummy2")
	var dmg: Damageable = dummy.get_node("Damageable")
	var dead := [false]
	dmg.died.connect(func() -> void: dead[0] = true)
	runner.simulate_action_press("shoot")
	for i in 900:  # 事件驱动：等死，不猜帧数
		await runner.simulate_frames(1)
		if dead[0]:
			break
	runner.simulate_action_release("shoot")
	# 注意：死亡后 dummy 与 dmg 都会被释放，只能访问标志位
	return {"dead": dead[0]}


func test_kill_spawns_debris_bodies() -> void:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	var out := await _kill_dummy2(runner)
	assert_bool(out["dead"]).override_failure_message("木桩没死").is_true()
	var debris := runner.scene().find_children("*", "RigidBody3D", true, false)
	assert_int(debris.size()).override_failure_message(
		"击杀碎片未生成").is_greater_equal(5)


func test_hitstop_restores_time_scale() -> void:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	await _kill_dummy2(runner)
	# hit-stop 60ms 真实时间后必须恢复 1.0（留 0.4s 余量）
	var restored := false
	for i in 300:
		await runner.simulate_frames(1)
		if Engine.time_scale == 1.0:
			restored = true
			break
	assert_bool(restored).override_failure_message(
		"Engine.time_scale 未恢复: %f" % Engine.time_scale).is_true()


func test_camera_shake_activates_on_kill() -> void:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var cam := player.get_node("Head/Camera3D") as Camera3D
	await _kill_dummy2(runner)
	# 击杀后震动窗口内采样：h/v_offset 应出现非零抖动
	var max_offset := 0.0
	for i in 60:
		await runner.simulate_frames(1)
		max_offset = maxf(max_offset, absf(cam.h_offset))
	assert_float(max_offset).override_failure_message(
		"镜头未震动").is_greater(0.0)


func test_kill_sound_plays() -> void:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	await _kill_dummy2(runner)
	var sounds := runner.scene().find_children("*", "AudioStreamPlayer3D", true, false)
	var found_kill := false
	for s in sounds:
		if s.stream and (s.stream.resource_path.contains("kill.wav")):
			found_kill = true
	assert_bool(found_kill).override_failure_message("击杀音未就位").is_true()
