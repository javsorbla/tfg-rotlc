@tool
extends "res://addons/maaacks_menus_template/base/nodes/windows/overlaid_window_scene_container.gd"

func _ready() -> void:
	super._ready()
	if instance and instance.has_signal(&"request_close"):
		instance.connect(&"request_close", close)
