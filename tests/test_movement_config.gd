extends GdUnitTestSuite

## T4 [RED] 移动参数验收 —— 值必须来自 MovementConfig（design.md 第 6 节）
## RED 阶段：MovementConfig 尚为占位值，本测试应失败

func _cfg() -> Resource:
	return MovementConfig.new()


func test_walk_speed_is_fast() -> void:
	assert_float(_cfg().walk_speed).is_equal(7.5)


func test_sprint_speed() -> void:
	assert_float(_cfg().sprint_speed).is_equal(10.5)


func test_jump_buffer_time() -> void:
	assert_float(_cfg().jump_buffer_time).is_equal(0.10)


func test_coyote_time() -> void:
	assert_float(_cfg().coyote_time).is_equal(0.12)


func test_fov_base_and_sprint() -> void:
	assert_float(_cfg().base_fov).is_equal(90.0)
	assert_float(_cfg().sprint_fov).is_equal(98.0)


func test_fov_delta_is_positive() -> void:
	var cfg := _cfg()
	assert_float(cfg.sprint_fov - cfg.base_fov).is_greater(0.0)


func test_mouse_sensitivity_nonzero() -> void:
	assert_float(_cfg().mouse_sensitivity).is_greater(0.0)


func test_ads_params() -> void:
	## M1.6：开镜三参数锁定（design.md plan.md T15a）
	assert_float(_cfg().ads_fov).is_equal(55.0)
	assert_float(_cfg().ads_move_multiplier).is_equal(0.6)
	assert_float(_cfg().ads_sensitivity_scale).is_equal(0.5)


func test_ads_actions_registered() -> void:
	## aim(RMB) / inspect(F) 输入映射
	assert_bool(InputMap.has_action("aim")).is_true()
	assert_bool(InputMap.has_action("inspect")).is_true()
