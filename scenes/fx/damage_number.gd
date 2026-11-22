class_name DamageNumber
extends Label3D

## 浮动伤害数字（design.md §5 击中反馈）
## 用法：DamageNumber.spawn(挂载节点, 世界位置, 数值)

var _rise_target := Vector3.ZERO


static func spawn(parent: Node, pos: Vector3, amount: float) -> void:
	var n := DamageNumber.new()
	n.text = "%.0f" % amount
	n.position = pos + Vector3(
		randf_range(-0.15, 0.15),
		randf_range(0.0, 0.2),
		randf_range(-0.1, 0.1))
	n._rise_target = n.position + Vector3(0, 1.0, 0)
	parent.add_child(n)


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 64
	outline_size = 14
	outline_modulate = Color(0, 0, 0, 0.85)
	modulate = Color(1.0, 0.9, 0.3)
	var tween := create_tween()
	tween.tween_property(self, "position", _rise_target, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.3)
	tween.tween_callback(queue_free)
