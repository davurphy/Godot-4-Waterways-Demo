extends Node3D


@export_file("*.tscn") var spawn_object_path: String
@export_range(0.0, 50.0) var throw_force := 10.0
@export_range(0.0, 10.0) var random_rotation_force := 1.0
@export var max_ducks: int = 10

var ducks: Array[RigidBody3D] = []

var _spawn_object: PackedScene

func _ready() -> void:
	_spawn_object = load(spawn_object_path) as PackedScene


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_spawn_duck()
	

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_select"):
		_spawn_duck()


func _spawn_duck() -> void:
	if _spawn_object == null:
		return
	var obj = _spawn_object.instantiate() as RigidBody3D
	owner.add_child(obj)
	obj.position = global_transform.origin
	obj.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	obj.apply_central_impulse(global_transform.basis.z * -throw_force)
	obj.angular_velocity = Vector3((-0.5 + randf()) * random_rotation_force, (-0.5 + randf()) * random_rotation_force, (-0.5 + randf()) * random_rotation_force)
	ducks.push_front(obj)
	if ducks.size() >= max_ducks:
		ducks[ducks.size() -1].queue_free()
		ducks.pop_back()
