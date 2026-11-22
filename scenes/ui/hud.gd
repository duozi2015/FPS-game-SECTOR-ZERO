extends CanvasLayer

## HUD：连击 + 弹药 + 血量 + 波次/残敌 + GAME OVER（M2 扩展，M3 打磨）

const TIER_COLORS: Array[Color] = [
	Color(0.92, 0.92, 0.92),  # ×1-2 白
	Color(1.0, 0.85, 0.3),    # ×3-5 黄
	Color(1.0, 0.55, 0.2),    # ×6-9 橙
	Color(1.0, 0.25, 0.2),    # ×10+ 红
]

@onready var _combo_label: Label = $Control/ComboLabel
@onready var _ammo_label: Label = $Control/AmmoLabel
@onready var _health_label: Label = $Control/HealthLabel
@onready var _wave_label: Label = $Control/WaveLabel
@onready var _enemies_label: Label = $Control/EnemiesLabel
@onready var _game_over_label: Label = $Control/GameOverLabel


func _ready() -> void:
	add_to_group("ui_hud")
	var combo := get_tree().get_first_node_in_group("combo_system")
	if combo:
		(combo as ComboSystem).combo_changed.connect(_on_combo_changed)
	_combo_label.visible = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.active_weapon_changed.connect(_on_weapon_changed)
		_bind_weapon(player.weapon as WeaponBase)
		var dmg := player.get_node("Damageable") as Damageable
		dmg.damaged.connect(_on_player_damaged)
		dmg.died.connect(func() -> void: _set_health_text(0))
		_set_health_text(int(dmg.health))
	var wm := get_tree().get_first_node_in_group("wave_manager")
	if wm:
		(wm as WaveManager).wave_started.connect(_on_wave_started)
		(wm as WaveManager).enemies_changed.connect(_on_enemies_changed)
		(wm as WaveManager).wave_cleared.connect(_on_wave_cleared)


func _bind_weapon(weapon: WeaponBase) -> void:
	weapon.ammo_changed.connect(_on_ammo_changed)
	_on_ammo_changed(weapon.ammo_in_mag)


func _on_weapon_changed(weapon: WeaponBase) -> void:
	_bind_weapon(weapon)


func show_game_over(wave: int) -> void:
	_game_over_label.text = "GAME OVER · 撑到第 %d 波 · 按 R 重开" % wave
	_game_over_label.visible = true


func _on_wave_started(wave: int, total: int) -> void:
	_wave_label.text = "WAVE %d" % wave
	_enemies_label.text = "残敌 %d" % total


func _on_enemies_changed(alive: int, pending: int) -> void:
	_enemies_label.text = "残敌 %d" % (alive + pending)


func _on_wave_cleared(_wave: int) -> void:
	_enemies_label.text = "波次肃清！休整中…"


func _on_player_damaged(_info: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var dmg := player.get_node("Damageable") as Damageable
		_set_health_text(int(dmg.health))
		# 低血量警示色
		if dmg.health <= 30.0:
			_health_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
		else:
			_health_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))


func _set_health_text(value: int) -> void:
	_health_label.text = str(value)


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
	var player := get_tree().get_first_node_in_group("player")
	var mag := 30
	if player and "weapon" in player:
		mag = (player.weapon as WeaponBase).magazine_size
	_ammo_label.text = "%d / %d" % [current, mag]
	if current == 0:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	elif current <= mag / 3:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	else:
		_ammo_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
