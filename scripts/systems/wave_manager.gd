class_name WaveManager
extends Node

## 波次调度（design.md §9）：刷怪、波间休整、同屏上限、对象池语义（复用即重生成）
## 敌人场景通过 spawner_scene 注册表映射；刷怪点由 arena 场景提供

signal wave_started(wave: int, total: int)
signal wave_cleared(wave: int)
signal enemy_killed()
signal enemies_changed(alive: int, pending: int)

const INTERMISSION := 5.0
const MAX_ALIVE := 15

## 敌人类型 → 场景路径（惰性加载，避免解析期依赖；arena 可覆写）
@export var enemy_scene_paths := {
	"grunt": "res://scenes/enemies/grunt.tscn",
	"shooter": "res://scenes/enemies/shooter.tscn",
	"brute": "res://scenes/enemies/brute.tscn",
}

## 刷怪点（arena 里拖入 Marker3D）
@export var spawn_points: Array[Node3D] = []
@export var auto_start := true  ## 进入场景即开波（测试可关）

var wave := 0
var alive := 0
var pending := 0
var _pending_types: Array[String] = []
var _intermission := 0.0
var _running := false


## 组合规则（纯函数，被 test_wave_manager.gd 锁定）：
## total = 3 + wave*2；brutes = wave/3；shooters 从第 2 波起 = min(wave-1, int(total*0.35))
static func compose_wave(wave_num: int) -> Dictionary:
	var total := 3 + wave_num * 2
	var brutes := int(wave_num / 3.0)
	var shooters := 0
	if wave_num >= 2:
		shooters = mini(wave_num - 1, int(total * 0.35))
	var grunts := total - brutes - shooters
	return {
		"total": total,
		"grunt": grunts,
		"shooter": shooters,
		"brute": brutes,
	}


func _ready() -> void:
	add_to_group("wave_manager")
	if spawn_points.is_empty():
		# 健壮自查：父场景下找 "Spawns" 容器，其子节点即刷怪点
		var spawns := get_parent().get_node_or_null("Spawns")
		if spawns:
			for child in spawns.get_children():
				if child is Node3D:
					spawn_points.append(child as Node3D)
	if auto_start:
		start()


func start() -> void:
	_running = true
	_next_wave()


func stop() -> void:
	_running = false


func _physics_process(delta: float) -> void:
	if not _running:
		return
	# 刷怪：alive 未达上限且队列有货 → 逐帧补
	if pending > 0 and alive < MAX_ALIVE:
		_spawn_one()
	# 波间休整
	if pending == 0 and alive == 0 and wave > 0:
		_intermission -= delta
		if _intermission <= 0.0:
			_next_wave()


func _next_wave() -> void:
	wave += 1
	var comp := compose_wave(wave)
	_pending_types.clear()
	for i in comp["grunt"]:
		_pending_types.append("grunt")
	for i in comp["shooter"]:
		_pending_types.append("shooter")
	for i in comp["brute"]:
		_pending_types.append("brute")
	pending = _pending_types.size()
	_intermission = INTERMISSION
	wave_started.emit(wave, comp["total"])
	enemies_changed.emit(alive, pending)


func _spawn_one() -> void:
	if spawn_points.is_empty():
		return
	var type: String = _pending_types.pop_back()
	pending -= 1
	var scene: PackedScene = load(enemy_scene_paths.get(type, enemy_scene_paths["grunt"]))
	var enemy := scene.instantiate()
	get_parent().add_child(enemy)
	# 轮询刷怪点 + 少量随机偏移，避免同点堆叠（必须入树后再设 global_position）
	var point := spawn_points[wave % spawn_points.size()]
	enemy.global_position = point.global_position + Vector3(
		randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	alive += 1
	var dmg: Damageable = enemy.get_node_or_null("Damageable")
	if dmg:
		dmg.died.connect(_on_enemy_died)
	enemies_changed.emit(alive, pending)


func _on_enemy_died() -> void:
	alive = maxi(alive - 1, 0)
	enemy_killed.emit()
	enemies_changed.emit(alive, pending)
	if pending == 0 and alive == 0:
		wave_cleared.emit(wave)
		_intermission = INTERMISSION
