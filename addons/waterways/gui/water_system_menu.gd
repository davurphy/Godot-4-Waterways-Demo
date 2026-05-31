# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends MenuButton

signal generate_system_maps
signal validate_map_sampling

enum WATER_SYSTEM_MENU {
	GENERATE_SYSTEM_MAPS,
	VALIDATE_MAP_SAMPLING
}


func _enter_tree() -> void:
	get_popup().clear()
	get_popup().connect("id_pressed", Callable(self, "_menu_item_selected"))
	get_popup().add_item("Generate System Maps", WATER_SYSTEM_MENU.GENERATE_SYSTEM_MAPS)
	get_popup().add_item("Validate Map Sampling", WATER_SYSTEM_MENU.VALIDATE_MAP_SAMPLING)


func _exit_tree() -> void:
	get_popup().disconnect("id_pressed", Callable(self, "_menu_item_selected"))


func _menu_item_selected(index : int) -> void:
	match index:
		WATER_SYSTEM_MENU.GENERATE_SYSTEM_MAPS:
			emit_signal("generate_system_maps")
		WATER_SYSTEM_MENU.VALIDATE_MAP_SAMPLING:
			emit_signal("validate_map_sampling")
