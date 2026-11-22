extends CanvasLayer

## 主菜单：标题 + 地图选择 + 退出（M3）
## 键盘：方向键选择、回车确认（Button 焦点链原生支持）

@onready var _btn_arena: Button = $Root/Buttons/BtnArena
@onready var _btn_city: Button = $Root/Buttons/BtnCity
@onready var _btn_quit: Button = $Root/Buttons/BtnQuit


func _ready() -> void:
	# 菜单需要可见光标
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_btn_arena.pressed.connect(_start.bind("res://scenes/arena/arena.tscn"))
	_btn_city.pressed.connect(_start.bind("res://scenes/arena/city.tscn"))
	_btn_quit.pressed.connect(func() -> void: get_tree().quit())
	_btn_arena.grab_focus()  # 键盘默认焦点


func _start(scene_path: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(scene_path)
