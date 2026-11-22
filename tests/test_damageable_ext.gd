extends GdUnitTestSuite

## T14b [RED] Damageable 扩展：heal() 治疗 + 击退载荷透传（M2 掉落/霰弹枪的地基）

func _dmg(max_hp := 100.0) -> Damageable:
	var d: Damageable = auto_free(Damageable.new())
	d.max_health = max_hp
	d.health = max_hp
	return d


func test_heal_restores_health() -> void:
	var d := _dmg()
	d.apply_damage({"damage": 60.0})
	d.heal(25.0)
	assert_float(d.health).is_equal(65.0)


func test_heal_clamps_at_max() -> void:
	var d := _dmg()
	d.heal(999.0)
	assert_float(d.health).is_equal(100.0)


func test_heal_ignored_when_dead() -> void:
	var d := _dmg()
	d.apply_damage({"damage": 999.0})
	d.heal(50.0)
	assert_float(d.health).is_equal(0.0)
	assert_bool(d.is_dead).is_true()


func test_knockback_passes_through_payload() -> void:
	var d := _dmg()
	var last_info := [{}]  # lambda 按值捕获变量，用数组槽位承载引用
	d.damaged.connect(func(info: Dictionary) -> void: last_info[0] = info)
	d.apply_damage({"damage": 10.0, "knockback": 6.5, "position": Vector3(1, 2, 3)})
	assert_float(last_info[0]["knockback"]).is_equal(6.5)


func test_knockback_defaults_zero() -> void:
	var d := _dmg()
	var last_info := [{}]
	d.damaged.connect(func(info: Dictionary) -> void: last_info[0] = info)
	d.apply_damage({"damage": 10.0})
	assert_float(last_info[0]["knockback"]).is_equal(0.0)
