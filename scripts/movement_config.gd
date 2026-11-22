class_name MovementConfig
extends Resource

## 玩家移动手感参数（design.md 第 6 节）
## 调手感只改这里；数值经 test_movement_config.gd 锁定

@export_group("Speed")
@export var walk_speed := 7.5
@export var sprint_speed := 10.5

@export_group("Jump")
@export var jump_velocity := 4.8  ## 约 1.2m 跳高 (g=9.8)
@export var jump_buffer_time := 0.10
@export var coyote_time := 0.12

@export_group("Camera")
@export var base_fov := 90.0
@export var sprint_fov := 98.0
@export var mouse_sensitivity := 0.002
@export var landing_dip_degrees := 5.0

@export_group("ADS")
@export var ads_fov := 55.0  ## 开镜视野（design.md M1.6）
@export var ads_move_multiplier := 0.6  ## 开镜移速系数
@export var ads_sensitivity_scale := 0.5  ## 开镜灵敏度系数
