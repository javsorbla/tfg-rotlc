extends Area2D

@export var message: String = ""
@export var duration: float = 3.0
@export var trigger_once: bool = true

var _triggered := false
var _manager: Node = null

func _ready() -> void:
	_manager = get_tree().get_first_node_in_group("tutorial_message_manager")
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if _triggered and trigger_once:
		return
	var candidate := body
	while candidate != null:
		if candidate.is_in_group("player"):
			if message != "":
				if _manager == null:
					_manager = get_tree().get_first_node_in_group("tutorial_message_manager")
				if _manager != null and _manager.has_method("show_message"):
					_manager.show_message(message, duration, false)
			_triggered = true
			break
		candidate = candidate.get_parent()
