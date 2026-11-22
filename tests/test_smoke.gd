extends GdUnitTestSuite

## M0 验收：测试框架可用 + 输入映射齐全（plan.md T2/T3）

func test_framework_ready() -> void:
	assert_that(true).is_true()


func test_input_actions_registered() -> void:
	var required: Array[String] = [
		"move_forward", "move_back", "move_left", "move_right",
		"jump", "sprint", "shoot", "weapon_1", "weapon_2",
	]
	for action in required:
		assert_bool(InputMap.has_action(action)).override_failure_message(
			"缺少输入动作: %s" % action).is_true()
