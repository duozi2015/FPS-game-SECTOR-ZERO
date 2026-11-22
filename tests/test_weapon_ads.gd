extends GdUnitTestSuite

## M1.6 开镜/检视验收（plan.md T15c-T15f）

const RANGE_PATH := "res://scenes/arena/shooting_range.tscn"


func _context() -> Array:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var weapon := player.weapon as WeaponBase
	var cam := player.get_node("Head/Camera3D") as Camera3D
	return [runner, player, weapon, cam]


func test_ads_zooms_fov_and_restores() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var cam: Camera3D = out[3]
	runner.simulate_action_press("aim")
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and weapon.ads_blend < 0.8:
		await runner.simulate_frames(1)
	assert_float(weapon.ads_blend).override_failure_message("开镜未完成").is_greater(0.8)
	assert_float(cam.fov).override_failure_message(
		"开镜 FOV 未收缩: %.1f" % cam.fov).is_less(80.0)
	runner.simulate_action_release("aim")
	deadline = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and weapon.ads_blend > 0.2:
		await runner.simulate_frames(1)
	assert_float(weapon.ads_blend).is_less(0.2)
	# FOV 以 8/s 速率回升，需继续等它真正回到基础值
	deadline = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and cam.fov < 87.0:
		await runner.simulate_frames(1)
	assert_float(cam.fov).override_failure_message("FOV 未恢复").is_greater(87.0)


func test_ads_reduces_spread_and_speed() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var player := out[1] as CharacterBody3D
	var weapon: WeaponBase = out[2]
	runner.simulate_action_press("aim")
	runner.simulate_action_press("move_forward")
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and weapon.ads_blend < 1.0:
		await runner.simulate_frames(1)
	await runner.simulate_frames(20)  # 速度稳定
	assert_float(weapon.effective_spread_multiplier()).override_failure_message(
		"开镜散布未收缩").is_less(0.4)
	assert_float(player.velocity.length()).override_failure_message(
		"开镜移速未收缩: %.1f" % player.velocity.length()).is_less(5.5)
	runner.simulate_action_release("aim")
	runner.simulate_action_release("move_forward")


func test_inspect_plays_and_blocks_aim() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	# F 触发检视
	runner.simulate_action_press("inspect")
	await runner.simulate_frames(2)
	runner.simulate_action_release("inspect")
	assert_bool(weapon._inspecting).override_failure_message("检视未启动").is_true()
	# 检视期间开镜被拒绝
	weapon.set_aiming(true)
	assert_bool(weapon.aiming).override_failure_message("检视期间开镜应被拒绝").is_false()
	# 等检视结束（约 1.6s）
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline and weapon._inspecting:
		await runner.simulate_frames(1)
	assert_bool(weapon._inspecting).override_failure_message("检视未结束").is_false()
	weapon.set_aiming(false)
	weapon.set_aiming(true)
	assert_bool(weapon.aiming).override_failure_message("检视后开镜仍不可用").is_true()
	weapon.set_aiming(false)


func test_vignette_follows_ads() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var crosshair := runner.scene().get_node("CrosshairLayer/Control")
	var vignette: TextureRect = crosshair.get_node("../Vignette")  # Vignette 是 Control 的兄弟节点
	runner.simulate_action_press("aim")
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and weapon.ads_blend < 0.9:
		await runner.simulate_frames(1)
	assert_float(vignette.modulate.a).override_failure_message(
		"开镜暗角未出现").is_greater(0.3)
	runner.simulate_action_release("aim")


func test_ads_spread_actually_tightens_shot() -> void:
	## 端到端：开镜后连射 12 发应全部命中正前方靶子（散布收紧的实质效果）
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var dummy := runner.scene().get_node("Dummy2")
	var dmg: Damageable = dummy.get_node("Damageable")
	dmg.max_health = 1000.0  # 血量抬高到 12 发打不死，专测散布命中率
	dmg.health = 1000.0
	var hits := [0]
	dmg.damaged.connect(func(_i: Dictionary) -> void: hits[0] += 1)
	runner.simulate_action_press("aim")
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and weapon.ads_blend < 1.0:
		await runner.simulate_frames(1)
	runner.simulate_action_press("shoot")
	deadline = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and hits[0] < 12:
		await runner.simulate_frames(1)
	runner.simulate_action_release("shoot")
	runner.simulate_action_release("aim")
	assert_int(hits[0]).override_failure_message(
		"开镜命中数不足: %d" % hits[0]).is_greater_equal(12)
