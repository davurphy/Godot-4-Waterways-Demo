extends Node

## Autoload: Captures all Godot output (print, push_error, push_warning) via OS.add_logger.
## Writes to project/debugger/godot_debug.txt. Also syncs user://logs/godot.log.

@warning_ignore("unused_private_class_variable")
static var _early_registered := _register_early()

static func _register_early() -> bool:
	var project_root := ProjectSettings.globalize_path("res://")
	var log_path := project_root.path_join("debugger").path_join("godot_debug.txt")
	OS.add_logger(CustomFileLogger.new(log_path))
	return true

func _init() -> void:
	pass

## Writes directly to godot_debug.txt. Use for output that should appear in the file during Editor Run.
func log(msg: String) -> void:
	_log_to_file(msg)

static func log_line(msg: String) -> void:
	_log_to_file(msg)

static func _log_to_file(msg: String) -> void:
	var project_root := ProjectSettings.globalize_path("res://")
	var log_path := project_root.path_join("debugger").path_join("godot_debug.txt")
	var dir := log_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line("[LOG] %s" % msg)
		f.close()

func _ready() -> void:
	call_deferred("_sync_builtin_log")
	_sync_log_timer()

func _sync_log_timer() -> void:
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(_sync_builtin_log)
	add_child(t)
	t.start()

func _sync_builtin_log() -> void:
	var src := "user://logs/godot.log"
	var project_root := ProjectSettings.globalize_path("res://")
	var dst := project_root.path_join("debugger").path_join("godot_debug.txt")
	if not FileAccess.file_exists(src):
		return
	var dir := dst.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var content := FileAccess.get_file_as_string(src)
	if content.is_empty():
		return
	var existing := ""
	if FileAccess.file_exists(dst):
		existing = FileAccess.get_file_as_string(dst)
	if content.length() <= existing.length():
		return
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()


class CustomFileLogger extends Logger:
	var _mutex: Mutex
	var _log_path: String

	func _init(log_path: String) -> void:
		_mutex = Mutex.new()
		_log_path = log_path
		_init_log_file()

	func _init_log_file() -> void:
		var dir := _log_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(_log_path, FileAccess.WRITE)
		if f:
			f.store_line("=== Session started at %s ===" % Time.get_datetime_string_from_system())
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
