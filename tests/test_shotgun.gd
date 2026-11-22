extends GdUnitTestSuite

## T18 霰弹枪验收：8 弹丸齐射 / 单发低伤 / 拾取补弹

const STAGE := "res://tests/helpers/weapon_stage.tscn"
const SHOTGUN := preload("res://scenes/weapons/shotgun.tscn")


func test_shotgun_fires_eight_pellets() -> void:
	var runner := scene_runner(STAGE)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var dummy := runner.scene().get_node("Target")  # weapon_stage 的靶子名
	var dmg := dummy.get_node("Damageable") as Damageable
	dmg.max_health = 1000.0
	dmg.health = 1000.0
	var sg := SHOTGUN.instantiate()
	runner.scene().add_child(sg)
	sg.global_position = player.global_position + Vector3(0, 1.6, 0)  # 相机位置
	sg.shooter_body = player
	var fired_count := [0]
	var damages: Array[float] = []
	sg.fired.connect(func(info: Dictionary) -> void:
		fired_count[0] += 1
		if info.get("damageable") != null:
			damages.append(info["damage"]))
	var hits := [0]
	dmg.damaged.connect(func(_i: Dictionary) -> void: hits[0] += 1)
	sg.try_fire()
	await runner.simulate_frames(2)
	assert_int(fired_count[0]).override_failure_message(
		"弹丸数不是 8: %d" % fired_count[0]).is_equal(8)
	assert_int(hits[0]).override_failure_message(
		"命中数不足: %d" % hits[0]).is_greater_equal(5)
	for d in damages:
		assert_float(d).is_equal(12.0)  # 单弹丸伤害
	sg.queue_free()


func test_ammo_pickup_refills_weapon() -> void:
	var runner := scene_runner(STAGE)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var weapon := player.weapon as WeaponBase
	weapon.ammo_in_mag = 5
	var pickup_scene: PackedScene = load("res://scenes/systems/pickup.tscn")
	var pickup := pickup_scene.instantiate()
	pickup.kind = "ammo"
	runner.scene().add_child(pickup)
	pickup.global_position = player.global_position + Vector3(0, 0.6, -1)
	# 磁吸拾取 → 弹匣回满
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and weapon.ammo_in_mag != 30:
		await runner.simulate_frames(1)
	assert_int(weapon.ammo_in_mag).override_failure_message(
		"弹药拾取未补满").is_equal(30)


func test_health_pickup_heals_player() -> void:
	var runner := scene_runner(STAGE)
	await runner.simulate_frames(5)
	var player := runner.scene().get_node("Player") as CharacterBody3D
	var dmg := player.get_node("Damageable") as Damageable
	dmg.apply_damage({"damage": 50.0})
	var pickup_scene: PackedScene = load("res://scenes/systems/pickup.tscn")
	var pickup := pickup_scene.instantiate()
	pickup.kind = "health"
	runner.scene().add_child(pickup)
	pickup.global_position = player.global_position + Vector3(0, 0.6, -1)
	# 磁吸拾取 → 回血 25（50 → 75）
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and dmg.health != 75.0:
		await runner.simulate_frames(1)
	assert_float(dmg.health).override_failure_message(
		"血包未回血: %.0f" % dmg.health).is_equal(75.0)
