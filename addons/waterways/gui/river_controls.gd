# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends HBoxContainer

signal mode
signal options

enum CONSTRAINTS {
	NONE,
	COLLIDERS,
	AXIS_X,
	AXIS_Y,
	AXIS_Z,
	PLANE_YZ,
	PLANE_XZ,
	PLANE_XY,
}

var menu
var debug_view_menu
var constraints

func _enter_tree() -> void:
	menu = $RiverMenu
	debug_view_menu = $DebugViewMenu
	constraints = $Constraints
	_populate_constraint_options()
	custom_minimum_size = Vector2(486.0, 26.0)
	menu.tooltip_text = "River tools and bake actions"
	debug_view_menu.tooltip_text = "Choose the river debug overlay"
	$Select.tooltip_text = "Select and move river points"
	$Add.tooltip_text = "Add a river point"
	$Remove.tooltip_text = "Remove a river point"
	$Constraints.tooltip_text = "Choose how river point movement is constrained"
	$LocalMode.tooltip_text = "Use local curve axes for movement constraints"
	$Select.button_pressed = true


func spatial_gui_input(event: InputEvent) -> bool:
	# This uses the forwarded spatial input in order to not react to events
	# while the spatial editor is not in focus
	if event is InputEventKey and event.is_pressed() and not constraints.disabled:
		
		# Early exit if any of the modifiers (except shift) is pressed to not
		# override default shortcuts like Ctrl + Z
		if event.alt_pressed or event.is_command_or_control_pressed() or event.meta_pressed:
			return false
		
		# Handle local mode keybinding for toggling
		if event.keycode == KEY_T:
			# Set the input as handled to prevent default actions from the keys
			$LocalMode.button_pressed = not $LocalMode.button_pressed
			get_viewport().set_input_as_handled()
			return true
		
		# Fetch the constraint that the user requested to toggle
		var requested: int
		match [event.keycode, event.shift_pressed]:
			[KEY_S, _]: requested = CONSTRAINTS.COLLIDERS
			[KEY_X, false]: requested = CONSTRAINTS.AXIS_X
			[KEY_Y, false]: requested = CONSTRAINTS.AXIS_Y
			[KEY_Z, false]: requested = CONSTRAINTS.AXIS_Z
			[KEY_X, true]: requested = CONSTRAINTS.PLANE_YZ
			[KEY_Y, true]: requested = CONSTRAINTS.PLANE_XZ
			[KEY_Z, true]: requested = CONSTRAINTS.PLANE_XY
			_: return false
		
		# If the user requested the current selection, we toggle it instead to off
		if requested == constraints.selected:
			requested = CONSTRAINTS.NONE
		
		# Update the OptionsButton and call the signal callback as that is
		# only automatically called when the user clicks it
		if requested < 0 or requested >= constraints.item_count:
			return false
		constraints.select(requested)
		_on_constraint_selected(requested)
		
		# Set the input as handled to prevent default actions from the keys
		get_viewport().set_input_as_handled()
		return true
	
	return false


func _on_select() -> void:
	_untoggle_buttons()
	_disable_constraint_ui(false)
	$Select.button_pressed = true
	emit_signal("mode", "select")


func _on_add() -> void:
	_untoggle_buttons()
	_disable_constraint_ui(false)
	$Add.button_pressed = true
	emit_signal("mode", "add")


func _on_remove() -> void:
	_untoggle_buttons()
	_disable_constraint_ui(true)
	$Remove.button_pressed = true
	emit_signal("mode", "remove")


func _on_constraint_selected(index: int) -> void:
	emit_signal("options", "constraint", index)


func _on_local_mode_toggled(enabled: bool) -> void:
	emit_signal("options", "local_mode", enabled)


func _populate_constraint_options() -> void:
	constraints.clear()
	constraints.add_item("No Constraint", CONSTRAINTS.NONE)
	constraints.add_item("Snap to Colliders", CONSTRAINTS.COLLIDERS)
	constraints.add_item("Axis X", CONSTRAINTS.AXIS_X)
	constraints.add_item("Axis Y", CONSTRAINTS.AXIS_Y)
	constraints.add_item("Axis Z", CONSTRAINTS.AXIS_Z)
	constraints.add_item("Plane YZ", CONSTRAINTS.PLANE_YZ)
	constraints.add_item("Plane XZ", CONSTRAINTS.PLANE_XZ)
	constraints.add_item("Plane XY", CONSTRAINTS.PLANE_XY)
	constraints.select(CONSTRAINTS.NONE)


func _disable_constraint_ui(disable: bool) -> void:
	$Constraints.disabled = disable
	$LocalMode.disabled = disable


func _untoggle_buttons() -> void:
	$Select.button_pressed = false
	$Add.button_pressed = false
	$Remove.button_pressed = false
