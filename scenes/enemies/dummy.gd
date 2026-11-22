extends StaticBody3D

## 靶场木桩：受击 → 伤害数字 + 命中音（T10）；击杀反馈 T12 接入

@onready var _damageable: Damageable = $Damageable
@onready var _hit_sound: AudioStreamPlayer3D = $HitSound


func _ready() -> void:
	_damageable.damaged.connect(_on_damaged)


func _on_damaged(info: Dictionary) -> void:
	# 挂到父节点（竞技场根）：木桩死后数字仍可存活
	DamageNumber.spawn(get_parent(), info["position"], info["amount"])
	_hit_sound.play()
