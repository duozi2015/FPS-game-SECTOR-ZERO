extends GdUnitTestSuite

## M3 主菜单验收：加载 + 按钮齐备 + 默认焦点

const MENU := "res://scenes/ui/menu.tscn"


func test_menu_loads_with_buttons() -> void:
	var runner := scene_runner(MENU)
	await runner.simulate_frames(3)
	var root := runner.scene()
	# 回归守卫：菜单脚本曾漏挂到节点导致按钮全死（与 HUD 同类失误）
	var script: Script = root.get_script()
	assert_object(script).override_failure_message(
		"menu.gd 未挂载到 Menu 节点").is_not_null()
	var btn := root.get_node("Root/Buttons/BtnArena") as Button
	assert_int(btn.pressed.get_connections().size()).override_failure_message(
		"开始按钮未接线").is_greater(0)
	assert_object(root.get_node("Root/Buttons/BtnCity")).is_not_null()
	assert_object(root.get_node("Root/Buttons/BtnQuit")).is_not_null()


func test_menu_buttons_keyboard_navigable() -> void:
	var runner := scene_runner(MENU)
	await runner.simulate_frames(3)
	var btn := runner.scene().get_node("Root/Buttons/BtnArena") as Button
	# headless 无窗口焦点系统：改为断言焦点模式可用（真机行为由人工验收覆盖）
	assert_int(btn.focus_mode).override_failure_message(
		"按钮不可键盘聚焦").is_equal(Control.FOCUS_ALL)


func test_main_scene_is_menu() -> void:
	## 主场景必须指向菜单（游戏从菜单进入）
	assert_str(ProjectSettings.get_setting(
		"application/run/main_scene", "")).is_equal("res://scenes/ui/menu.tscn")
