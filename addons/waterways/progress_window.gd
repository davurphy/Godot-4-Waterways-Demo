# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends Window


@onready var _progress_bar = $VBoxContainer/ProgressBar


func show_progress(message, progress) -> void:
	title = message
	_progress_bar.value = progress
