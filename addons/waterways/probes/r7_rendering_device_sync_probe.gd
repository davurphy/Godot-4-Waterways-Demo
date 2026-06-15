# River-refactor R7 validation-only RenderingDevice sync/readback stress probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_rendering_device_sync_probe.gd -- iterations=97 repeats=20 out=res://.codex-research/r7-baselines/sync
#
# Success marker: R7_RENDERING_DEVICE_SYNC_OK
extends SceneTree

const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/sync"
const REPORT_FILE_NAME := "r7_rendering_device_sync.txt"
const DEFAULT_ITERATIONS := 97
const DEFAULT_REPEATS := 20
const ELEMENT_COUNT := 257
const LOCAL_SIZE := 64
const ASYNC_WAIT_FRAMES := 180
const UINT32_MOD := 4294967296

const PING_PONG_SHADER_TEMPLATE := """
#version 450

layout(local_size_x = $LOCAL_SIZE, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) readonly restrict buffer SourceBuffer {
	uint values[];
}
source_buffer;
layout(set = 0, binding = 1, std430) writeonly restrict buffer DestinationBuffer {
	uint values[];
}
destination_buffer;

const uint ELEMENT_COUNT = $ELEMENT_COUNTu;

void main() {
	uint index = gl_GlobalInvocationID.x;
	if (index >= ELEMENT_COUNT) {
		return;
	}
	uint value = source_buffer.values[index];
	destination_buffer.values[index] = value * 1664525u + 1013904223u + index * 747796405u;
}
"""

var _errors := PackedStringArray()
var _report_lines := PackedStringArray()
var _async_buffer_data := PackedByteArray()
var _async_buffer_called := false
var _written_report := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var iterations := max(1, int(args.get("iterations", str(DEFAULT_ITERATIONS))))
	var repeats := max(1, int(args.get("repeats", str(DEFAULT_REPEATS))))
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))

	_report_lines.append("R7_RENDERING_DEVICE_SYNC_DUMP v1")
	_report_lines.append("iterations=" + str(iterations))
	_report_lines.append("repeats=" + str(repeats))
	_report_lines.append("element_count=" + str(ELEMENT_COUNT))
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())

	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		_errors.append("R7_RENDERING_DEVICE_SYNC_SKIPPED local RenderingDevice unavailable; run this probe windowed under Forward+/Vulkan.")
		_write_report(out_dir.path_join(REPORT_FILE_NAME))
		_finish()
		return

	_report_lines.append("local_rd_device_name=" + rd.get_device_name())
	_report_lines.append("local_rd_device_vendor=" + rd.get_device_vendor_name())
	_report_lines.append("local_rd_device_total_memory=" + str(rd.get_device_total_memory()))
	_report_lines.append("limit_push_constant_size=" + str(rd.limit_get(RenderingDevice.LIMIT_MAX_PUSH_CONSTANT_SIZE)))
	_report_lines.append("limit_compute_shared_memory=" + str(rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_SHARED_MEMORY_SIZE)))
	_report_lines.append("limit_max_compute_workgroup_invocations=" + str(rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_INVOCATIONS)))
	_report_lines.append("limit_max_compute_workgroup_size_x=" + str(rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_SIZE_X)))

	var shader := _compile_compute_shader(rd, _shader_source(), "r7_sync_ping_pong")
	if shader.is_valid():
		var pipeline := rd.compute_pipeline_create(shader)
		if pipeline.is_valid():
			await _run_repeated_submit_sync_case(rd, shader, pipeline, iterations, repeats)
			_run_intra_list_barrier_case(rd, shader, pipeline)
			await _run_async_readback_case(rd, shader, pipeline, iterations)
			_run_cleanup_case(rd, shader, pipeline)
			rd.free_rid(pipeline)
		else:
			_errors.append("Could not create sync probe compute pipeline.")
		rd.free_rid(shader)
	rd.free()

	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _finish() -> void:
	if _errors.is_empty():
		print("R7_RENDERING_DEVICE_SYNC_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_repeated_submit_sync_case(rd: RenderingDevice, shader: RID, pipeline: RID, iterations: int, repeats: int) -> void:
	var owned_rids: Array[RID] = []
	var byte_size := ELEMENT_COUNT * 4
	var initial_a := _make_initial_bytes(0)
	var zero_bytes := PackedByteArray()
	zero_bytes.resize(byte_size)
	var buffer_a := rd.storage_buffer_create(byte_size, initial_a)
	var buffer_b := rd.storage_buffer_create(byte_size, zero_bytes)
	if not buffer_a.is_valid() or not buffer_b.is_valid():
		_errors.append("Could not create repeated-submit buffers.")
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(buffer_a)
	owned_rids.append(buffer_b)
	var set_ab := _make_ping_pong_uniform_set(rd, shader, buffer_a, buffer_b)
	var set_ba := _make_ping_pong_uniform_set(rd, shader, buffer_b, buffer_a)
	if not set_ab.is_valid() or not set_ba.is_valid():
		_errors.append("Could not create repeated-submit uniform sets.")
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(set_ab)
	owned_rids.append(set_ba)

	var worst_checksum := 0
	for repeat_index in repeats:
		var seed := repeat_index * 9973 + 17
		var initial_values := _make_initial_values(seed)
		rd.buffer_update(buffer_a, 0, byte_size, _u32_array_to_bytes(initial_values))
		rd.buffer_update(buffer_b, 0, byte_size, zero_bytes)
		var expected_values := initial_values.duplicate()
		for iteration in iterations:
			var use_ab := iteration % 2 == 0
			_record_dispatch(rd, pipeline, set_ab if use_ab else set_ba)
			expected_values = _advance_values(expected_values)
		rd.submit()
		for _frame_index in 3:
			await process_frame
		rd.sync()
		var final_buffer := buffer_a if iterations % 2 == 0 else buffer_b
		var actual_bytes := rd.buffer_get_data(final_buffer, 0, byte_size)
		var actual_values := _bytes_to_u32_array(actual_bytes, ELEMENT_COUNT)
		_verify_values("repeated_submit repeat=" + str(repeat_index), expected_values, actual_values)
		worst_checksum = maxi(worst_checksum, _checksum_u32(actual_values))
	_report_lines.append("repeated_submit_sync.repeats=" + str(repeats))
	_report_lines.append("repeated_submit_sync.iterations=" + str(iterations))
	_report_lines.append("repeated_submit_sync.submit_pattern=record_all_compute_lists_once_then_submit_wait_3_frames_sync")
	_report_lines.append("repeated_submit_sync.final_checksum_sample=" + str(worst_checksum))
	_free_owned_rids(rd, owned_rids)
	_free_owned_rids(rd, owned_rids)


func _run_intra_list_barrier_case(rd: RenderingDevice, shader: RID, pipeline: RID) -> void:
	var barrier_match := _run_two_dispatch_single_list(rd, shader, pipeline, true)
	var no_barrier_match := _run_two_dispatch_single_list(rd, shader, pipeline, false)
	_report_lines.append("intra_list_barrier.with_barrier_match=" + str(barrier_match))
	_report_lines.append("intra_list_barrier.without_barrier_match_report_only=" + str(no_barrier_match))
	_expect(barrier_match, "Intra-list dependent dispatch with compute_list_add_barrier did not match expected values.")


func _run_two_dispatch_single_list(rd: RenderingDevice, shader: RID, pipeline: RID, use_barrier: bool) -> bool:
	var owned_rids: Array[RID] = []
	var byte_size := ELEMENT_COUNT * 4
	var initial_values := _make_initial_values(777 if use_barrier else 888)
	var zero_bytes := PackedByteArray()
	zero_bytes.resize(byte_size)
	var buffer_a := rd.storage_buffer_create(byte_size, _u32_array_to_bytes(initial_values))
	var buffer_b := rd.storage_buffer_create(byte_size, zero_bytes)
	if not buffer_a.is_valid() or not buffer_b.is_valid():
		_errors.append("Could not create intra-list buffers.")
		return false
	owned_rids.append(buffer_a)
	owned_rids.append(buffer_b)
	var set_ab := _make_ping_pong_uniform_set(rd, shader, buffer_a, buffer_b)
	var set_ba := _make_ping_pong_uniform_set(rd, shader, buffer_b, buffer_a)
	if not set_ab.is_valid() or not set_ba.is_valid():
		_errors.append("Could not create intra-list uniform sets.")
		_free_owned_rids(rd, owned_rids)
		return false
	owned_rids.append(set_ab)
	owned_rids.append(set_ba)

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, set_ab, 0)
	rd.compute_list_dispatch(compute_list, _group_count_1d(), 1, 1)
	if use_barrier:
		rd.compute_list_add_barrier(compute_list)
	rd.compute_list_bind_uniform_set(compute_list, set_ba, 0)
	rd.compute_list_dispatch(compute_list, _group_count_1d(), 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()

	var expected := _advance_values(_advance_values(initial_values))
	var actual := _bytes_to_u32_array(rd.buffer_get_data(buffer_a, 0, byte_size), ELEMENT_COUNT)
	var matches := _values_match(expected, actual)
	_report_lines.append("intra_list." + ("with_barrier" if use_barrier else "without_barrier") + ".checksum=" + str(_checksum_u32(actual)))
	_free_owned_rids(rd, owned_rids)
	_free_owned_rids(rd, owned_rids)
	return matches


func _run_async_readback_case(rd: RenderingDevice, shader: RID, pipeline: RID, iterations: int) -> void:
	var owned_rids: Array[RID] = []
	var byte_size := ELEMENT_COUNT * 4
	var initial_values := _make_initial_values(4242)
	var zero_bytes := PackedByteArray()
	zero_bytes.resize(byte_size)
	var buffer_a := rd.storage_buffer_create(byte_size, _u32_array_to_bytes(initial_values))
	var buffer_b := rd.storage_buffer_create(byte_size, zero_bytes)
	if not buffer_a.is_valid() or not buffer_b.is_valid():
		_errors.append("Could not create async-readback buffers.")
		return
	owned_rids.append(buffer_a)
	owned_rids.append(buffer_b)
	var set_ab := _make_ping_pong_uniform_set(rd, shader, buffer_a, buffer_b)
	var set_ba := _make_ping_pong_uniform_set(rd, shader, buffer_b, buffer_a)
	if not set_ab.is_valid() or not set_ba.is_valid():
		_errors.append("Could not create async-readback uniform sets.")
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(set_ab)
	owned_rids.append(set_ba)

	var expected_values := initial_values.duplicate()
	for iteration in iterations:
		var use_ab := iteration % 2 == 0
		_record_dispatch(rd, pipeline, set_ab if use_ab else set_ba)
		expected_values = _advance_values(expected_values)
	rd.submit()
	var final_buffer := buffer_a if iterations % 2 == 0 else buffer_b
	_async_buffer_called = false
	_async_buffer_data = PackedByteArray()
	var err := rd.buffer_get_data_async(final_buffer, Callable(self, "_on_async_buffer_data"), 0, byte_size)
	if err != OK:
		_report_lines.append("async_readback.request_error=" + error_string(err))
		rd.sync()
		var fallback_values := _bytes_to_u32_array(rd.buffer_get_data(final_buffer, 0, byte_size), ELEMENT_COUNT)
		_verify_values("async_readback_fallback_after_request_error", expected_values, fallback_values)
		_free_owned_rids(rd, owned_rids)
		return
	for _frame_index in ASYNC_WAIT_FRAMES:
		if _async_buffer_called:
			break
		await process_frame
	if not _async_buffer_called:
		_report_lines.append("async_readback.callback_received=false")
		_report_lines.append("async_readback.callback_timeout_frames=" + str(ASYNC_WAIT_FRAMES))
		_report_lines.append("async_readback.selected_for_production=false")
		rd.sync()
		var fallback_values := _bytes_to_u32_array(rd.buffer_get_data(final_buffer, 0, byte_size), ELEMENT_COUNT)
		_verify_values("async_readback_delayed_sync_fallback", expected_values, fallback_values)
		_report_lines.append("async_readback.delayed_sync_fallback_checksum=" + str(_checksum_u32(fallback_values)))
		_free_owned_rids(rd, owned_rids)
		return
	var actual_values := _bytes_to_u32_array(_async_buffer_data, ELEMENT_COUNT)
	_verify_values("async_readback", expected_values, actual_values)
	rd.sync()
	_report_lines.append("async_readback.callback_received=true")
	_report_lines.append("async_readback.selected_for_production=false")
	_report_lines.append("async_readback.byte_size=" + str(_async_buffer_data.size()))
	_report_lines.append("async_readback.checksum=" + str(_checksum_u32(actual_values)))
	_free_owned_rids(rd, owned_rids)
	_free_owned_rids(rd, owned_rids)


func _on_async_buffer_data(data: PackedByteArray) -> void:
	_async_buffer_called = true
	_async_buffer_data = data


func _run_cleanup_case(rd: RenderingDevice, shader: RID, pipeline: RID) -> void:
	var owned_rids: Array[RID] = []
	var byte_size := ELEMENT_COUNT * 4
	var texture_format := RDTextureFormat.new()
	texture_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	texture_format.width = 4
	texture_format.height = 4
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.samples = RenderingDevice.TEXTURE_SAMPLES_1
	texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	var texture := rd.texture_create(texture_format, RDTextureView.new(), [])
	var buffer := rd.storage_buffer_create(byte_size, _make_initial_bytes(66))
	var uniform_set := _make_ping_pong_uniform_set(rd, shader, buffer, buffer) if buffer.is_valid() else RID()
	if texture.is_valid():
		owned_rids.append(texture)
	if buffer.is_valid():
		owned_rids.append(buffer)
	if uniform_set.is_valid():
		owned_rids.append(uniform_set)
	var texture_was_valid := texture.is_valid() and rd.texture_is_valid(texture)
	_free_owned_rids(rd, owned_rids)
	_free_owned_rids(rd, owned_rids)
	var texture_valid_after_free := texture.is_valid() and rd.texture_is_valid(texture)
	_report_lines.append("cleanup.texture_was_valid=" + str(texture_was_valid))
	_report_lines.append("cleanup.texture_valid_after_double_free=" + str(texture_valid_after_free))
	_report_lines.append("cleanup.double_free_completed=true")
	_expect(texture_was_valid, "Cleanup subcase could not create a texture RID.")
	_expect(not texture_valid_after_free, "Texture RID stayed valid after cleanup.")
	# Keep these parameters used in the probe context so future edits notice if the
	# cleanup case stops sharing the production pipeline/shader lifetime.
	_report_lines.append("cleanup.pipeline_rid_valid_during_case=" + str(pipeline.is_valid()))


func _compile_compute_shader(rd: RenderingDevice, code: String, shader_name: String) -> RID:
	var shader_source := RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = code
	var spirv: RDShaderSPIRV = rd.shader_compile_spirv_from_source(shader_source, false)
	var compile_error := spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if not compile_error.is_empty():
		_errors.append("Compute shader compile failed for " + shader_name + ": " + compile_error)
		return RID()
	var shader := rd.shader_create_from_spirv(spirv, shader_name)
	if not shader.is_valid():
		_errors.append("shader_create_from_spirv returned invalid RID for " + shader_name)
	return shader


func _shader_source() -> String:
	return PING_PONG_SHADER_TEMPLATE.replace("$LOCAL_SIZE", str(LOCAL_SIZE)).replace("$ELEMENT_COUNT", str(ELEMENT_COUNT))


func _make_ping_pong_uniform_set(rd: RenderingDevice, shader: RID, source_buffer: RID, destination_buffer: RID) -> RID:
	var source_uniform := RDUniform.new()
	source_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	source_uniform.binding = 0
	source_uniform.add_id(source_buffer)
	var destination_uniform := RDUniform.new()
	destination_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	destination_uniform.binding = 1
	destination_uniform.add_id(destination_buffer)
	return rd.uniform_set_create([source_uniform, destination_uniform], shader, 0)


func _record_dispatch(rd: RenderingDevice, pipeline: RID, uniform_set: RID) -> void:
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, _group_count_1d(), 1, 1)
	rd.compute_list_end()


func _group_count_1d() -> int:
	return int(ceil(float(ELEMENT_COUNT) / float(LOCAL_SIZE)))


func _make_initial_bytes(seed: int) -> PackedByteArray:
	return _u32_array_to_bytes(_make_initial_values(seed))


func _make_initial_values(seed: int) -> Array:
	var values := []
	values.resize(ELEMENT_COUNT)
	var value := _u32(seed * 1664525 + 1013904223)
	for index in ELEMENT_COUNT:
		value = _u32(value * 1103515245 + 12345 + index * 97)
		values[index] = value
	return values


func _advance_values(values: Array) -> Array:
	var next_values := []
	next_values.resize(values.size())
	for index in values.size():
		next_values[index] = _u32(int(values[index]) * 1664525 + 1013904223 + index * 747796405)
	return next_values


func _u32_array_to_bytes(values: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(values.size() * 4)
	for index in values.size():
		bytes.encode_u32(index * 4, int(values[index]))
	return bytes


func _bytes_to_u32_array(bytes: PackedByteArray, count: int) -> Array:
	var values := []
	values.resize(count)
	if bytes.size() < count * 4:
		_errors.append("Readback byte array was too short: " + str(bytes.size()) + " < " + str(count * 4))
		return values
	for index in count:
		values[index] = int(bytes.decode_u32(index * 4))
	return values


func _verify_values(label: String, expected: Array, actual: Array) -> void:
	if expected.size() != actual.size():
		_errors.append(label + ": expected/actual size mismatch.")
		return
	for index in expected.size():
		if int(expected[index]) != int(actual[index]):
			_errors.append(label + ": mismatch at index " + str(index) + " expected=" + str(expected[index]) + " actual=" + str(actual[index]))
			return


func _values_match(expected: Array, actual: Array) -> bool:
	if expected.size() != actual.size():
		return false
	for index in expected.size():
		if int(expected[index]) != int(actual[index]):
			return false
	return true


func _checksum_u32(values: Array) -> int:
	var checksum := 0
	for value in values:
		checksum = _u32(checksum + int(value))
	return checksum


func _u32(value: int) -> int:
	return int(value % UINT32_MOD)


func _free_owned_rids(rd: RenderingDevice, rids: Array[RID]) -> void:
	for reverse_index in rids.size():
		var rid := rids[rids.size() - 1 - reverse_index]
		if rid.is_valid():
			rd.free_rid(rid)
	rids.clear()


func _write_report(file_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var parent := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_errors.append("Could not create output parent " + parent + ": " + error_string(dir_error))
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write " + absolute_path + ": " + error_string(FileAccess.get_open_error()))
		return
	file.store_string("\n".join(_report_lines) + "\n")
	file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args
