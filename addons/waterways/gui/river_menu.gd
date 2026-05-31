# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends MenuButton

signal generate_flowmap
signal generate_mesh
signal validate_data_textures
signal validate_filter_renderer

enum RIVER_MENU {
	GENERATE,
	GENERATE_MESH,
	VALIDATE_DATA_TEXTURES,
	VALIDATE_FILTER_RENDERER
}


func _enter_tree() -> void:
	get_popup().clear()
	get_popup().connect("id_pressed", Callable(self, "_menu_item_selected"))
	get_popup().add_item("Generate Flow & Foam Map", RIVER_MENU.GENERATE)
	get_popup().add_item("Generate MeshInstance3D Sibling", RIVER_MENU.GENERATE_MESH)
	get_popup().add_item("Validate Data Textures", RIVER_MENU.VALIDATE_DATA_TEXTURES)
	get_popup().add_item("Validate Filter Renderer", RIVER_MENU.VALIDATE_FILTER_RENDERER)


func _exit_tree() -> void:
	get_popup().disconnect("id_pressed", Callable(self, "_menu_item_selected"))


func _menu_item_selected(index : int) -> void:
	match index:
		RIVER_MENU.GENERATE:
			emit_signal("generate_flowmap")
		RIVER_MENU.GENERATE_MESH:
			emit_signal("generate_mesh")
		RIVER_MENU.VALIDATE_DATA_TEXTURES:
			emit_signal("validate_data_textures")
		RIVER_MENU.VALIDATE_FILTER_RENDERER:
			emit_signal("validate_filter_renderer")
