# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends HBoxContainer

var menu

func _enter_tree() -> void:
	menu = $WaterSystemMenu
	custom_minimum_size = Vector2(97.0, 26.0)
	menu.tooltip_text = "WaterSystem tools and bake actions"
