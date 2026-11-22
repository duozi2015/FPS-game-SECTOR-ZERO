extends Node

## 全局 Hit-Stop（autoload 单例）：击杀瞬间时间冻结（design.md §5）
## 用法：HitStop.trigger(0.06) —— 真实时间 60ms，游戏内近冻结

func trigger(duration := 0.06, scale := 0.05) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
