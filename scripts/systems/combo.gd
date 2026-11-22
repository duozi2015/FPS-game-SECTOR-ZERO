class_name ComboSystem
extends Node

## 连击计数（M1.5 用户追加需求）：击杀 +1，3 秒无击杀清零
## 用法：场景内放置，敌人死亡时 call_group("combo_system", "notify_kill")

signal combo_changed(count: int)

const RESET_TIME := 3.0

var count := 0
var _timer := 0.0


func _ready() -> void:
	add_to_group("combo_system")


func notify_kill() -> void:
	count += 1
	_timer = RESET_TIME
	combo_changed.emit(count)


func _physics_process(delta: float) -> void:
	if count > 0:
		_timer -= delta
		if _timer <= 0.0:
			count = 0
			combo_changed.emit(count)
