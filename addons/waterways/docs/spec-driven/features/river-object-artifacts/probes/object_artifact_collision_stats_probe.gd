extends SceneTree

# Prints the stored collision-map statistics of the saved Demo river bake so
# overhang-exemption changes can be compared across bake versions.
# Success marker: OBJECT_ARTIFACT_COLLISION_STATS_OK

const BAKE_PATH := "res://waterways_bakes/Demo/Water_River.river_bake.res"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bake := load(BAKE_PATH) as Resource
	if bake == null:
		push_error("Could not load bake resource: " + BAKE_PATH)
		quit(1)
		return
	var signature = bake.get("source_signature")
	var metadata = bake.get("source_metadata")
	var version = -1
	if typeof(signature) == TYPE_DICTIONARY:
		version = (signature as Dictionary).get("version", -1)
	print("OBJECT_ARTIFACT_COLLISION_STATS signature_version=", version)
	if typeof(metadata) == TYPE_DICTIONARY:
		var metadata_dictionary := metadata as Dictionary
		for key in ["collision_hit_pixel_count", "collision_total_pixel_count", "collision_hit_pixel_percent"]:
			print("  ", key, "=", metadata_dictionary.get(key, "<missing>"))
	print("OBJECT_ARTIFACT_COLLISION_STATS_OK")
	quit(0)
