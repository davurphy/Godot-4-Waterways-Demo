# Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends MenuButton

signal debug_view_changed

const QUICK_VIEW_ITEMS := [
	["Normal", 0],
	["Effective Flow Direction (with force)", 1],
	["Final Flow Strength", 8],
	["Foam Mix", 9],
	["Flow Pattern", 6],
	["Flow Arrows", 7],
]

const DEBUG_VIEW_GROUPS := [
	{
		"name": "General",
		"items": [
			["Normal", 0],
			["Surface Steepness / Grade Proxy", 11],
			["Phase Noise (flow_foam_noise A)", 3],
		]
	},
	{
		"name": "Foam",
		"items": [
			["Foam Mask (flow_foam_noise B)", 2],
			["Foam Mix", 9],
			["Bank Friction / Drag (bank_response_features R)", 22],
			["Bank Foam Contribution", 59],
			["Pillow Direct Terrain Anchor Search", 49],
			["Pillow Anchor Foam Contribution", 60],
			["Pillow Visual Mask (Black Zero)", 58],
			["Pillow Visual Foam Contribution", 61],
			["Surface Steepness / Grade Proxy", 11],
			["Grade / Energy Channel (dist_pressure B)", 12],
			["Pillow Material Response Mask", 54],
			["Wake Visual Mask", 30],
			["Eddy-Line Visual Mask", 31],
		]
	},
	{
		"name": "Flow",
		"items": [
			["Raw Flow Direction (flow_foam_noise RG)", 10],
			["Effective Flow Direction (with force)", 1],
			["Final Flow Strength", 8],
			["Distance / Bank Influence (dist_pressure R)", 4],
			["Pressure / Support (dist_pressure G)", 5],
			["Flow Pattern", 6],
			["Flow Arrows", 7],
		]
	},
	{
		"name": "Pillows",
		"items": [
			["Pillow / Impact Mask (obstacle_features R)", 14],
			["Pillow Visual Mask", 26],
			["Pillow Visual Mask (Black Zero)", 58],
			["Pillow No-Reach Mask (Black Zero)", 48],
			["Pillow Direct Terrain Anchor Search", 49],
			["Pillow Bank-Response Anchor Search", 50],
			["Pillow Combined Contact Gate", 51],
			["Pillow Bank-Only Anchor Contribution", 52],
			["Pillow Raw-to-Final Retention", 53],
			["Pillow Material Response Mask", 54],
			["Pillow Material Seam Guard", 55],
			["Pillow Height Seam Guard", 56],
			["Pillow Height Seam Stitch", 57],
			["Pillow Height Influence", 27],
			["Terrain Pillow Height Influence", 28],
			["Obstruction Pillow Height Influence", 29],
		]
	},
	{
		"name": "Wake / Eddy",
		"items": [
			["Wake / Eddy Seed Mask (obstacle_features G)", 15],
			["Eddy-Line / Shear Mask (obstacle_features B)", 16],
			["Wake Visual Mask", 30],
			["Eddy-Line Visual Mask", 31],
			["Wake Edge Thinness", 32],
			["Wake Shared Gate", 33],
			["Gated Eddy-Line Source (B * Wake Gate)", 34],
			["Wake Confidence Gate", 35],
			["Wake Hard/Protrusion Gate", 36],
			["Wake Bank Keep Gate", 37],
			["Wake Energy Gate", 38],
			["Wake Flow Gate", 39],
			["Eddy-Line Context Gate", 40],
			["Experimental Gated Eddy Source", 41],
			["Eddy-Line Raw Low Range (B x4)", 42],
			["Eddy-Line Candidate Gate", 43],
			["Eddy-Line Hard Context Search", 44],
			["Eddy-Line Wake Context Search", 45],
			["Raw Wake-Edge Candidate (from G)", 46],
			["Experimental Wake-Edge Eddy Source", 47],
		]
	},
	{
		"name": "Terrain / Banks",
		"items": [
			["Near-Surface Contact (terrain_contact_features R)", 18],
			["Shallow Depth (terrain_contact_features G)", 19],
			["Protrusion / Intersection (terrain_contact_features B)", 20],
			["Contact Source / Provenance (terrain_contact_features A)", 21],
			["Bank Friction / Drag (bank_response_features R)", 22],
			["Hard-Boundary / Protrusion Response (bank_response_features A)", 25],
		]
	},
	{
		"name": "Bends / Grade",
		"items": [
			["Grade / Energy Channel (dist_pressure B)", 12],
			["Bend Bias Channel (dist_pressure A)", 13],
			["Outside-Bend Wet Pressure (bank_response_features G)", 23],
			["Inside-Bend Deposition (bank_response_features B)", 24],
		]
	},
	{
		"name": "Obstacles",
		"items": [
			["Side Deflection / Obstacle Confidence (obstacle_features A)", 17],
		]
	},
]

const DEBUG_VIEW_ITEMS := [
	["Normal", 0],
	["Raw Flow Direction (flow_foam_noise RG)", 10],
	["Effective Flow Direction (with force)", 1],
	["Final Flow Strength", 8],
	["Foam Mask (flow_foam_noise B)", 2],
	["Foam Mix", 9],
	["Bank Foam Contribution", 59],
	["Pillow Anchor Foam Contribution", 60],
	["Pillow Visual Foam Contribution", 61],
	["Phase Noise (flow_foam_noise A)", 3],
	["Distance / Bank Influence (dist_pressure R)", 4],
	["Pressure / Support (dist_pressure G)", 5],
	["Surface Steepness / Grade Proxy", 11],
	["Grade / Energy Channel (dist_pressure B)", 12],
	["Bend Bias Channel (dist_pressure A)", 13],
	["Pillow / Impact Mask (obstacle_features R)", 14],
	["Pillow Visual Mask", 26],
	["Pillow Visual Mask (Black Zero)", 58],
	["Pillow No-Reach Mask (Black Zero)", 48],
	["Pillow Direct Terrain Anchor Search", 49],
	["Pillow Bank-Response Anchor Search", 50],
	["Pillow Combined Contact Gate", 51],
	["Pillow Bank-Only Anchor Contribution", 52],
	["Pillow Raw-to-Final Retention", 53],
	["Pillow Material Response Mask", 54],
	["Pillow Material Seam Guard", 55],
	["Pillow Height Seam Guard", 56],
	["Pillow Height Seam Stitch", 57],
	["Pillow Height Influence", 27],
	["Terrain Pillow Height Influence", 28],
	["Obstruction Pillow Height Influence", 29],
	["Wake / Eddy Seed Mask (obstacle_features G)", 15],
	["Eddy-Line / Shear Mask (obstacle_features B)", 16],
	["Wake Visual Mask", 30],
	["Eddy-Line Visual Mask", 31],
	["Wake Edge Thinness", 32],
	["Wake Shared Gate", 33],
	["Gated Eddy-Line Source (B * Wake Gate)", 34],
	["Wake Confidence Gate", 35],
	["Wake Hard/Protrusion Gate", 36],
	["Wake Bank Keep Gate", 37],
	["Wake Energy Gate", 38],
	["Wake Flow Gate", 39],
	["Eddy-Line Context Gate", 40],
	["Experimental Gated Eddy Source", 41],
	["Eddy-Line Raw Low Range (B x4)", 42],
	["Eddy-Line Candidate Gate", 43],
	["Eddy-Line Hard Context Search", 44],
	["Eddy-Line Wake Context Search", 45],
	["Raw Wake-Edge Candidate (from G)", 46],
	["Experimental Wake-Edge Eddy Source", 47],
	["Side Deflection / Obstacle Confidence (obstacle_features A)", 17],
	["Near-Surface Contact (terrain_contact_features R)", 18],
	["Shallow Depth (terrain_contact_features G)", 19],
	["Protrusion / Intersection (terrain_contact_features B)", 20],
	["Contact Source / Provenance (terrain_contact_features A)", 21],
	["Bank Friction / Drag (bank_response_features R)", 22],
	["Outside-Bend Wet Pressure (bank_response_features G)", 23],
	["Inside-Bend Deposition (bank_response_features B)", 24],
	["Hard-Boundary / Protrusion Response (bank_response_features A)", 25],
	["Flow Pattern", 6],
	["Flow Arrows", 7]
]

const SUBMENU_NAME_PREFIX := "DebugViewSubmenu"
const BUTTON_TEXT_PREFIX := "Debug View"

var debug_view_menu_selected := 0


func _enter_tree() -> void:
	_update_button_text()
	get_popup().connect("about_to_popup", Callable(self, "_on_about_to_popup"))
	get_popup().connect("id_pressed", Callable(self, "_on_item_selected"))


func _ready() -> void:
	_update_button_text()


func _exit_tree() -> void:
	get_popup().disconnect("about_to_popup", Callable(self, "_on_about_to_popup"))
	get_popup().disconnect("id_pressed", Callable(self, "_on_item_selected"))


func set_debug_view_menu_selected(index: int) -> void:
	debug_view_menu_selected = index
	_update_button_text()


func _on_item_selected(index: int) -> void:
	set_debug_view_menu_selected(index)
	emit_signal("debug_view_changed", index)


func _on_about_to_popup() -> void:
	var popup := get_popup()
	popup.clear()
	for item in QUICK_VIEW_ITEMS:
		popup.add_radio_check_item(String(item[0]), int(item[1]))
	_set_checked_item(popup, debug_view_menu_selected)
	popup.add_separator()
	for group_index in DEBUG_VIEW_GROUPS.size():
		var group: Dictionary = DEBUG_VIEW_GROUPS[group_index]
		var submenu := _get_or_create_submenu(group_index)
		_populate_submenu(submenu, group.get("items", []))
		popup.add_submenu_item(String(group.get("name", "")), submenu.name)


func _get_or_create_submenu(group_index: int) -> PopupMenu:
	var popup := get_popup()
	var submenu_name := SUBMENU_NAME_PREFIX + str(group_index)
	var submenu := popup.get_node_or_null(submenu_name) as PopupMenu
	if submenu != null:
		return submenu
	submenu = PopupMenu.new()
	submenu.name = submenu_name
	submenu.id_pressed.connect(_on_item_selected)
	popup.add_child(submenu)
	return submenu


func _populate_submenu(submenu: PopupMenu, items: Array) -> void:
	submenu.clear()
	for item in items:
		submenu.add_radio_check_item(String(item[0]), int(item[1]))
	_set_checked_item(submenu, debug_view_menu_selected)


func _set_checked_item(popup: PopupMenu, view_id: int) -> void:
	var checked_index := popup.get_item_index(view_id)
	if checked_index >= 0:
		popup.set_item_checked(checked_index, true)


func _update_button_text() -> void:
	text = BUTTON_TEXT_PREFIX + ": " + _debug_view_label_for_id(debug_view_menu_selected)


func _debug_view_label_for_id(view_id: int) -> String:
	for item in DEBUG_VIEW_ITEMS:
		if int(item[1]) == view_id:
			return String(item[0])
	return "Unknown " + str(view_id)
