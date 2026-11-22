extends Control

## 准星 + hitmarker + 开镜暗角（design.md §5 / M1.6）
## 通过 group("player") 找到武器并订阅 fired；击杀闪光接入 combo

var _hit_alpha := 0.0
var _kill_alpha := 0.0
var _spread_px := 6.0  ## 准星间隙，随武器散布 bloom 联动

var _weapon: WeaponBase

@onready var _vignette: TextureRect = get_node("../Vignette")


func _ready() -> void:
	add_to_group("ui_crosshair")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	var player := get_tree().get_first_node_in_group("player")
	if player and "weapon" in player:
		_weapon = player.weapon as WeaponBase
		_weapon.fired.connect(_on_weapon_fired)


func flash_hit() -> void:
	_hit_alpha = 1.0


func flash_kill() -> void:
	_kill_alpha = 1.0


func _on_weapon_fired(info: Dictionary) -> void:
	if info.get("damageable"):
		flash_hit()


func _process(delta: float) -> void:
	# 散布 bloom → 准星间隙实时联动；开镜暗角渐入
	if _weapon:
		_spread_px = 6.0 + _weapon.current_bloom * 3.0
		_vignette.modulate.a = _weapon.ads_blend * 0.85
	_hit_alpha = maxf(_hit_alpha - delta * 5.0, 0.0)
	_kill_alpha = maxf(_kill_alpha - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var aiming := _weapon and _weapon.ads_blend > 0.5
	# 开镜时隐藏十字（用机械瞄具），保留中心参考点
	if not aiming:
		var gap := _spread_px
		var arm := 7.0
		var white := Color(1, 1, 1, 0.9)
		draw_line(c + Vector2(gap, 0), c + Vector2(gap + arm, 0), white, 2.0)
		draw_line(c + Vector2(-gap, 0), c + Vector2(-gap - arm, 0), white, 2.0)
		draw_line(c + Vector2(0, gap), c + Vector2(0, gap + arm), white, 2.0)
		draw_line(c + Vector2(0, -gap), c + Vector2(0, -gap - arm), white, 2.0)
	else:
		draw_circle(c, 1.8, Color(1, 1, 1, 0.85))
	# 击中 hitmarker：四条斜线闪白
	if _hit_alpha > 0.0:
		_draw_marker(c, Color(1, 1, 1, _hit_alpha), 5.0, 12.0, 2.5)
	# 击杀 hitmarker：红色放大
	if _kill_alpha > 0.0:
		_draw_marker(c, Color(1.0, 0.25, 0.2, _kill_alpha), 6.0, 16.0, 3.0)


func _draw_marker(c: Vector2, col: Color, d1: float, d2: float, width: float) -> void:
	for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		draw_line(c + s * d1, c + s * d2, col, width)
