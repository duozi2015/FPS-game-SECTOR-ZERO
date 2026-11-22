class_name Damageable
extends Node

## 受伤组件（design.md §8）——挂到任何可被打的节点上
## 武器命中时调用 apply_damage；死亡只触发一次 died

signal damaged(info: Dictionary)  ## {amount, position, normal, ...}
signal died()

@export var max_health := 100.0

var health := 100.0
var is_dead := false


func _ready() -> void:
	health = max_health


func apply_damage(info: Dictionary) -> void:
	if is_dead:
		return
	var amount: float = info.get("damage", 0.0)
	health = maxf(health - amount, 0.0)
	# 规范化载荷：FX 消费统一键名（击退供敌人/玩家物理响应）
	damaged.emit({
		"amount": amount,
		"position": info.get("position", Vector3.ZERO),
		"normal": info.get("normal", Vector3.ZERO),
		"knockback": info.get("knockback", 0.0),
	})
	if health <= 0.0:
		is_dead = true
		died.emit()


## 治疗（拾取回血用）：不溢出、死亡无效
func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(health + amount, max_health)
