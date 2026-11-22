extends GdUnitTestSuite

## T11 枪械手感验收：视觉后坐上抬 + 散布 bloom/回落 + 三层枪声挂载

const RANGE_PATH := "res://scenes/arena/shooting_range.tscn"


func _context() -> Array:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var weapon: WeaponBase = player.weapon
	return [runner, player, weapon]


func test_recoil_kicks_camera_up() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var player: CharacterBody3D = out[1]
	runner.simulate_action_press("shoot")
	await runner.simulate_frames(15)  # ≈2 发
	runner.simulate_action_release("shoot")
	# head.rotation.x = _pitch - recoil → 开火后应比纯鼠标 pitch 更负（抬头）
	var kick: float = -player.head.rotation.x - (-player._pitch)
	assert_float(kick).override_failure_message("镜头没有后坐上抬").is_greater(0.0)
	await runner.simulate_frames(60)  # ≈0.42s 后坐应回落
	var kick_late: float = -player.head.rotation.x - (-player._pitch)
	assert_float(kick_late).override_failure_message("后坐未回落").is_less(kick)


func test_spread_blooms_and_recovers() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var shots := [0]
	weapon.fired.connect(func(_i: Dictionary) -> void: shots[0] += 1)
	# headless 下帧耗时受 FX 影响，物理 tick 与 idle 帧不同步 →
	# 事件驱动：数到 6 发即停，不依赖帧数估算
	runner.simulate_action_press("shoot")
	for i in 600:
		await runner.simulate_frames(1)
		if shots[0] >= 6:
			break
	runner.simulate_action_release("shoot")
	assert_int(shots[0]).override_failure_message("未打出足够发数").is_greater_equal(3)
	assert_float(weapon.current_bloom).override_failure_message(
		"连射未扩大散布").is_greater(0.3)
	var recovered := false
	for i in 700:  # 上限约 5s（快） / 30s（慢），命中 <0.3 即通过
		await runner.simulate_frames(1)
		if weapon.current_bloom < 0.3:
			recovered = true
			break
	assert_bool(recovered).override_failure_message("散布未回落").is_true()


func test_shot_sound_assigned() -> void:
	var out := await _context()
	var weapon: WeaponBase = out[2]
	assert_object(weapon._shot_sound.stream).override_failure_message(
		"枪声未配置").is_not_null()
