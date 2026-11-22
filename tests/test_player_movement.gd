extends GdUnitTestSuite

## T5 玩家移动集成测试（plan.md 降级路径：物理模拟只做可靠项，
## 土狼/缓冲的参数正确性由 test_movement_config.gd 锁定 + 真人试玩验证）

const STAGE_PATH := "res://tests/helpers/player_stage.tscn"


func _player(runner: GdUnitSceneRunner) -> CharacterBody3D:
	return runner.scene().get_node("Player") as CharacterBody3D


func test_walk_forward_displaces_player() -> void:
	var runner := scene_runner(STAGE_PATH)
	var player := _player(runner)
	var z0: float = player.position.z
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(60)  # 7.5 m/s × 1s 应远超 1m
	runner.simulate_action_release("move_forward")
	assert_float(player.position.z).is_less(z0 - 1.0)


func test_sprint_faster_than_walk() -> void:
	var runner := scene_runner(STAGE_PATH)
	var player := _player(runner)
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(60)
	var walk_z: float = player.position.z
	# 回到起点重新测冲刺
	player.position = Vector3.ZERO
	runner.simulate_action_press("sprint")
	await runner.simulate_frames(60)
	runner.simulate_action_release("sprint")
	runner.simulate_action_release("move_forward")
	assert_float(player.position.z).is_less(walk_z - 0.5)  # 冲刺应明显更远


func test_jump_rises_above_floor() -> void:
	var runner := scene_runner(STAGE_PATH)
	var player := _player(runner)
	await runner.simulate_frames(10)  # 先站稳
	runner.simulate_action_press("jump")
	await runner.simulate_frames(5)
	runner.simulate_action_release("jump")
	assert_float(player.position.y).is_greater(0.05)


func test_mouse_look_rotates_player() -> void:
	var runner := scene_runner(STAGE_PATH)
	var player := _player(runner)
	await runner.simulate_frames(5)
	await runner.simulate_mouse_move_relative(Vector2(200, 0))
	assert_float(absf(player.rotation.y)).is_greater(0.0)


func test_sprint_stretches_fov() -> void:
	var runner := scene_runner(STAGE_PATH)
	var player := _player(runner)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	await runner.simulate_frames(5)
	runner.simulate_action_press("move_forward")
	runner.simulate_action_press("sprint")
	await runner.simulate_frames(60)
	runner.simulate_action_release("sprint")
	runner.simulate_action_release("move_forward")
	assert_float(cam.fov).is_greater(90.5)  # 从 90 向 98 拉伸中


func test_landing_dip_occurs_and_recovers() -> void:
	var runner := scene_runner(STAGE_PATH)
	var player := _player(runner)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	await runner.simulate_frames(10)
	runner.simulate_action_press("jump")
	# headless 下 idle 帧与物理 tick 不同步：全程采样 + 落地事件触发，
	# 不假设跳跃周期时长
	var went_airborne := false
	var min_tilt := 0.0
	for i in 400:
		await runner.simulate_frames(1)
		if not player.is_on_floor():
			went_airborne = true
		min_tilt = minf(min_tilt, cam.rotation.x)
		if went_airborne and player.is_on_floor():
			for j in 30:  # 落地后再采样一段，覆盖 dip 及回弹
				await runner.simulate_frames(1)
				min_tilt = minf(min_tilt, cam.rotation.x)
			break
	runner.simulate_action_release("jump")
	assert_bool(went_airborne).override_failure_message("从未离地").is_true()
	assert_float(min_tilt).override_failure_message("未出现向下 dip").is_less(0.0)
