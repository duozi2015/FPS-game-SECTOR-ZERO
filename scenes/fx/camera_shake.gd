class_name CameraShake
extends Node

## 镜头震动：挂在 Camera3D 下，用 h/v_offset 抖动（不与玩家转向逻辑冲突）
## 触发：get_tree().call_group("fx_camera_shake", "trigger", 强度)

@export var amplitude_scale := 0.08  ## 强度 1.0 对应的位移幅度（米）

var _camera: Camera3D
var _intensity := 0.0


func _ready() -> void:
	add_to_group("fx_camera_shake")
	_camera = get_parent() as Camera3D


func trigger(intensity := 0.4) -> void:
	_intensity = maxf(_intensity, intensity)


func _process(delta: float) -> void:
	if _camera == null:
		return
	if _intensity > 0.001:
		_camera.h_offset = randf_range(-1.0, 1.0) * _intensity * amplitude_scale
		_camera.v_offset = randf_range(-1.0, 1.0) * _intensity * amplitude_scale
		_intensity = maxf(_intensity - delta * 2.5, 0.0)
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
