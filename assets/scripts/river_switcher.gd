extends Node3D

@onready var water_river = $"WaterSystem/Water River"
@onready var lava_river = $"WaterSystem/Lava River"


func _input(event : InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_swap_river()
				MOUSE_BUTTON_WHEEL_DOWN:
					_swap_river()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("next"):
		_swap_river()

func _swap_river() -> void:
	water_river.visible = !water_river.visible
	lava_river.visible = !lava_river.visible
