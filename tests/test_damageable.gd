extends GdUnitTestSuite

## T9 [RED] Damageable 组件验收 —— design.md §8「挨打有反应」的地基
## RED 阶段：Damageable 尚未实现（占位 0 血），本测试应失败

const AMMO_INFO := {"damage": 25.0, "position": Vector3.ZERO, "normal": Vector3.ZERO}


func _dmg() -> Damageable:
	return auto_free(Damageable.new())


func test_initial_health_is_full() -> void:
	assert_float(_dmg().health).is_equal(_dmg().max_health)


func test_apply_damage_reduces_health() -> void:
	var d := _dmg()
	d.apply_damage(AMMO_INFO)
	assert_float(d.health).is_equal(d.max_health - 25.0)


func test_damaged_signal_carries_amount() -> void:
	var d := _dmg()
	var amounts: Array[float] = []
	d.damaged.connect(func(info: Dictionary) -> void: amounts.append(info["amount"]))
	d.apply_damage(AMMO_INFO)
	assert_int(amounts.size()).is_equal(1)
	assert_float(amounts[0]).is_equal(25.0)


func test_health_clamps_at_zero_on_overkill() -> void:
	var d := _dmg()
	d.apply_damage({"damage": 999.0})
	assert_float(d.health).is_equal(0.0)


func test_dies_at_zero_health() -> void:
	var d := _dmg()
	var deaths := [0]  # lambda 按值捕获 int，用数组计数
	d.died.connect(func() -> void: deaths[0] += 1)
	d.apply_damage({"damage": 999.0})
	assert_bool(d.is_dead).is_true()
	assert_int(deaths[0]).is_equal(1)


func test_damage_after_death_is_ignored() -> void:
	var d := _dmg()
	var deaths := [0]
	d.died.connect(func() -> void: deaths[0] += 1)
	d.apply_damage({"damage": 999.0})
	d.apply_damage(AMMO_INFO)
	assert_int(deaths[0]).is_equal(1)  # 只死一次
	assert_float(d.health).is_equal(0.0)
