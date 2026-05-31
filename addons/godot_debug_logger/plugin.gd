@tool
extends EditorPlugin

## Captures editor-side output (errors, warnings, debugger panel) when playing in editor.
## Complements the runtime_logger Autoload which captures game output.

var _logger: EditorFileLogger
var _debugger_plugin: DebuggerCapturePlugin
var _log_path: String
var _sync_timer: Timer
var _output_connect_timer: Timer
var _connected_debugger: Object
var _output_callback: Callable
var _last_errors_text: String = ""
var _log_mutex: Mutex

func _enter_tree() -> void:
	_log_mutex = Mutex.new()
	var project_root := ProjectSettings.globalize_path("res://")
	_log_path = project_root.path_join("debugger").path_join("godot_debug.txt")
	_logger = EditorFileLogger.new(_log_path)
	OS.add_logger(_logger)
	_debugger_plugin = DebuggerCapturePlugin.new(self)
	add_debugger_plugin(_debugger_plugin)
	_output_callback = _on_debugger_output
	_sync_timer = Timer.new()
	_sync_timer.wait_time = 2.0
	_sync_timer.timeout.connect(_sync_debugger_errors)
	add_child(_sync_timer)
	_sync_timer.start()
	_output_connect_timer = Timer.new()
	_output_connect_timer.wait_time = 0.3
	_output_connect_timer.timeout.connect(_try_connect_debugger_output)
	add_child(_output_connect_timer)

func _exit_tree() -> void:
	if _output_connect_timer:
		_output_connect_timer.stop()
		_output_connect_timer.queue_free()
	_disconnect_debugger_output()
	if _sync_timer:
		_sync_timer.stop()
		_sync_timer.queue_free()
	if _debugger_plugin:
		remove_debugger_plugin(_debugger_plugin)
	_logger = null

func _process(_delta: float) -> void:
	if get_editor_interface().is_playing_scene():
		if _output_connect_timer.is_stopped() and _connected_debugger == null:
			_output_connect_timer.start()
	else:
		_output_connect_timer.stop()
		_disconnect_debugger_output()

func _try_connect_debugger_output() -> void:
	if _connected_debugger != null:
		return
	var base := get_editor_interface().get_base_control()
	if base == null:
		return
	for node in base.find_children("*", "Control", true, false):
		if node.has_signal("output"):
			if not node.output.is_connected(_output_callback):
				node.output.connect(_output_callback)
			_connected_debugger = node
			_output_connect_timer.stop()
			break

func _disconnect_debugger_output() -> void:
	if _connected_debugger != null and _connected_debugger.has_signal("output"):
		if _connected_debugger.output.is_connected(_output_callback):
			_connected_debugger.output.disconnect(_output_callback)
		_connected_debugger = null

func _on_debugger_output(msg: String, _level: int) -> void:
	_append_to_log(msg)

func _append_to_log(line: String) -> void:
	_log_mutex.lock()
	var dir := _log_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()
	_log_mutex.unlock()

func _sync_debugger_errors() -> void:
	if not get_editor_interface().is_playing_scene():
		_last_errors_text = ""
		return
	var text := _get_debugger_errors_tree_text()
	if text.is_empty() or text.length() > 200000 or text == _last_errors_text:
		return
	_last_errors_text = text
	_log_mutex.lock()
	var dir := _log_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line("=== Debugger Errors/Warnings ===")
		f.store_string(text)
		f.store_line("")
		f.close()
	_log_mutex.unlock()

func _get_debugger_errors_tree_text() -> String:
	if _connected_debugger != null:
		for node in _connected_debugger.find_children("*", "Tree", true, false):
			var t := node as Tree
			if t == null or not t.is_inside_tree() or t.get_columns() != 2:
				continue
			var p := t.get_parent()
			while p != null and p != _connected_debugger:
				if "Errors" in p.name or "Fehler" in p.name:
					var root := t.get_root()
					if root != null:
						var lines: PackedStringArray = []
						_collect_tree_items(root, lines, 0, 2)
						return "\n".join(lines)
				p = p.get_parent()
	var base := get_editor_interface().get_base_control()
	if base == null:
		return ""
	for node in base.find_children("*", "Tree", true, false):
		var t := node as Tree
		if t == null or not t.is_inside_tree():
			continue
		if not _is_errors_tree(t):
			continue
		var root := t.get_root()
		if root == null:
			continue
		var lines: PackedStringArray = []
		_collect_tree_items(root, lines, 0, t.get_columns())
		return "\n".join(lines)
	return ""

func _is_errors_tree(tree: Tree) -> bool:
	var p := tree.get_parent()
	while p != null:
		var n := p.name
		if "Errors" in n or "Fehler" in n:
			return true
		p = p.get_parent()
	p = tree.get_parent()
	if p != null:
		for c in p.get_children():
			if c is Button:
				var txt := (c as Button).text
				if "Clear" in txt or "Löschen" in txt or "Expand" in txt or "Ausklappen" in txt or "Collapse" in txt or "Einklappen" in txt:
					return true
	return false

func _collect_tree_items(item: TreeItem, lines: PackedStringArray, depth: int, columns: int) -> void:
	if item == null:
		return
	var prefix := "\t".repeat(depth)
	var col0 := item.get_text(0)
	var col1 := ""
	if columns >= 2:
		col1 = item.get_text(1)
	var line := prefix + col0
	if not col1.is_empty():
		line += ": " + col1
	if not line.strip_edges().is_empty():
		lines.append(line)
	var child := item.get_first_child()
	while child != null:
		_collect_tree_items(child, lines, depth + 1, columns)
		child = child.get_next()


class DebuggerCapturePlugin extends EditorDebuggerPlugin:
	var _plugin: EditorPlugin
	var _mutex: Mutex

	func _init(plugin: EditorPlugin) -> void:
		_plugin = plugin
		_mutex = Mutex.new()

	func _has_capture(capture: String) -> bool:
		return capture.begins_with("custom:") or capture.contains(":")

	func _capture(message: String, data: Array, _session_id: int) -> bool:
		_mutex.lock()
		if _plugin and _plugin.has_method("_append_to_log"):
			_plugin._append_to_log("[DEBUGGER] %s | %s" % [message, str(data)])
		_mutex.unlock()
		return false


class EditorFileLogger extends Logger:
	var _mutex: Mutex
	var _log_path: String

	func _init(log_path: String) -> void:
		_mutex = Mutex.new()
		_log_path = log_path
		_init_log_file()

	func _init_log_file() -> void:
		var dir := _log_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(_log_path, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
			f.store_line("=== Editor session started at %s ===" % Time.get_datetime_string_from_system())
			f.close()

	func _append_line(line: String) -> void:
		_mutex.lock()
		var f := FileAccess.open(_log_path, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
			f.store_line(line)
			f.close()
		_mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		var prefix := "[ERR] " if error else "[LOG] "
		_append_line(prefix + message)

	func _log_error(
		_function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		script_backtraces: Array
	) -> void:
		var prefix := "ERROR" if error_type == 0 else "WARNING"
		var loc := "%s:%d in %s" % [file, line, _function]
		var msg := rationale if rationale else code
		_append_line("[%s] %s: %s" % [prefix, loc, msg])
		for bt in script_backtraces:
			if bt is ScriptBacktrace and bt.format():
				_append_line("  " + bt.format().replace("\n", "\n  "))
