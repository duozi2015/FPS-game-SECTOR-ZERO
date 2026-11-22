extends CanvasLayer

## M1.5 最小 HUD：连击计数 + 弹药显示（T21 会扩展为完整 HUD）

const TIER_COLORS: Array[Color] = [
	Color(0.92, 0.92, 0.92),  # ×1-2 白
	Color(1.0, 0.85, 0.3),    # ×3-5 黄
	Color(1.0, 0.55, 0.2),    # ×6-9 橙
	Color(1.0, 0.25, 0.2),    # ×10+ 红
]

@onready var _combo_label: Label = $Control/ComboLabel
@onready var _ammo_label: Label = $Control/AmmoLabel


func _ready() -> void:
	var combo := get_tree().get_first_node_in_group("combo_system")
	if combo:
		(combo as ComboSystem).combo_changed.connect(_on_combo_changed)
	_combo_label.visible = false
	var player := get_tree().get_first_node_in_group("player")
	if player and "weapon" in player:
		var weapon := player.weapon as WeaponBase
		weapon.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(weapon.ammo_in_mag)


func _on_combo_changed(count: int) -> void:
	if count <= 0:
		_combo_label.visible = false
		return
	_combo_label.visible = true
	_combo_label.text = "COMBO ×%d" % count
	var tier := mini((count - 1) / 3, TIER_COLORS.size() - 1)
	_combo_label.add_theme_color_override("font_color", TIER_COLORS[tier])
	# 弹跳强调：越大越夸张
	_combo_label.pivot_offset = _combo_label.size / 2.0
	_combo_label.scale = Vector2.ONE * (1.0 + mini(count, 10) * 0.02)
	var t := _combo_label.create_tween()
	t.tween_property(_combo_label, "scale", Vector2.ONE, 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_ammo_changed(current: int) -> void:
	_ammo_label.text = "%d / 30" % current
	if current == 0:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	elif current <= 10:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	else:
		_ammo_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
