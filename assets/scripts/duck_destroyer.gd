extends Area3D


var duck_spawner: Node

func _ready() -> void:
	connect("body_entered", Callable(self, "on_body_entered"))
	duck_spawner = get_parent().get_node_or_null("Camera/DuckSpawner")

func on_body_entered(body) -> void:
	if body is RigidBody3D and duck_spawner != null:
		duck_spawner.ducks.erase(body)
		body.queue_free()
