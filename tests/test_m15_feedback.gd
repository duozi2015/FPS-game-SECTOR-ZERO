extends GdUnitTestSuite

## M1.5 返工验收：连击计数/清零、弹药信号/自动换弹、木桩受击闪光

const RANGE_PATH := "res://scenes/arena/shooting_range.tscn"


func _context() -> Array:
	var runner := scene_runner(RANGE_PATH)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var weapon := player.weapon as WeaponBase
	var combo := runner.scene().get_node("ComboSystem") as ComboSystem
	return [runner, player, weapon, combo]


func test_combo_increments_on_kill_and_resets() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var combo: ComboSystem = out[3]
	var dead := [false]
	var dummy := runner.scene().get_node("Dummy2")
	(dummy.get_node("Damageable") as Damageable).died.connect(
		func() -> void: dead[0] = true)
	runner.simulate_action_press("shoot")
	for i in 900:
		await runner.simulate_frames(1)
		if dead[0]:
			break
	runner.simulate_action_release("shoot")
	assert_bool(dead[0]).override_failure_message("木桩没死").is_true()
	assert_int(combo.count).override_failure_message(
		"击杀未计入连击").is_greater_equal(1)
	var reset := false
	for i in 700:  # 3s 清零（事件驱动轮询）
		await runner.simulate_frames(1)
		if combo.count == 0:
			reset = true
			break
	assert_bool(reset).override_failure_message(
		"连击未清零: %d" % combo.count).is_true()


func test_ammo_signal_fires_per_shot() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var events := [0]
	weapon.ammo_changed.connect(func(_c: int) -> void: events[0] += 1)
	runner.simulate_action_press("shoot")
	for i in 600:
		await runner.simulate_frames(1)
		if events[0] >= 1:
			break
	runner.simulate_action_release("shoot")
	assert_int(events[0]).override_failure_message(
		"ammo_changed 未发出").is_greater(0)


func test_empty_mag_auto_reloads() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var reloaded := [false]
	weapon.reloaded.connect(func() -> void: reloaded[0] = true)
	# 只留 1 发：打空立刻触发 reload 流程；缩短 reload_time 让窗口确定性
	weapon.reload_time = 0.3
	weapon.ammo_in_mag = 1
	runner.simulate_action_press("shoot")
	for i in 1000:  # 0.3s 真实时间 + 充足余量
		await runner.simulate_frames(1)
		if reloaded[0]:
			break
	runner.simulate_action_release("shoot")
	assert_bool(reloaded[0]).override_failure_message(
		"未自动换弹 (frames=%d)" % 700).is_true()
	assert_int(weapon.ammo_in_mag).is_equal(30)


func test_dummy_hit_flash_activates() -> void:
	var out := await _context()
	var runner: GdUnitSceneRunner = out[0]
	var weapon: WeaponBase = out[2]
	var dummy := runner.scene().get_node("Dummy2")
	var mesh := dummy.get_node("MeshInstance3D") as MeshInstance3D
	var hit := [false]
	(dummy.get_node("Damageable") as Damageable).damaged.connect(
		func(_i: Dictionary) -> void: hit[0] = true)
	runner.simulate_action_press("shoot")
	for i in 600:
		await runner.simulate_frames(1)
		if hit[0]:
			break
	runner.simulate_action_release("shoot")
	# 0.15s 衰减窗口内采样 emissive 能量 > 0
	var max_energy := 0.0
	for i in 30:
		await runner.simulate_frames(1)
		var mat := mesh.material_override as StandardMaterial3D
		if mat:
			max_energy = maxf(max_energy, mat.emission_energy_multiplier)
	assert_float(max_energy).override_failure_message(
		"受击无发光脉冲").is_greater(0.0)
