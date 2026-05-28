extends Area2D

@export var next_scene: String = ""
@export var auto_call_parent: bool = true
@export var auto_change_scene: bool = false 
signal activated(body)
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var sfx: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")
var is_transitioning: bool = false
var _entered_body: Node = null

func _ready() -> void:
	add_to_group("portal")
	connect("body_entered", Callable(self, "_on_body_entered"))
	if anim:
		# Ensure idle animation plays continuously if available
		if anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
			anim.sprite_frames.set_animation_loop("idle", true)
			anim.play("idle")
		else:
			anim.stop()

func _on_body_entered(body: Node) -> void:
	if is_transitioning:
		return

	var player_body: Node = null
	var candidate := body
	while candidate != null:
		if candidate.is_in_group("player"):
			player_body = candidate
			break
		candidate = candidate.get_parent()

	if player_body == null:
		return

	is_transitioning = true
	_entered_body = player_body
	if sfx:
		sfx.play()
	emit_signal("activated", _entered_body)
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("enter"):
		anim.sprite_frames.set_animation_loop("enter", false)
		anim.play("enter")
	var p = get_parent()
	if p and p.has_method("_on_final_body_entered"):
		var handler := Callable(p, "_on_final_body_entered")
		if not is_connected("activated", handler):
			connect("activated", handler)
		if auto_call_parent and not is_connected("body_entered", handler):
			p.call_deferred("_on_final_body_entered", _entered_body)

	# If configured to auto change scene and next_scene is set, request it (fallback)
	if auto_change_scene and next_scene != "":
		if Engine.has_singleton("GameState") and GameState.has_method("request_level_change"):
			GameState.request_level_change(next_scene)
		else:
			get_tree().call_deferred("change_scene_to_file", next_scene)

func _on_anim_finished() -> void:
	emit_signal("activated", _entered_body)

func _request_level_change() -> void:
	var target := next_scene
	if target == "" and Engine.has_singleton("GameState") and GameState.has_method("get_next_level_scene"):
		target = GameState.get_next_level_scene()

	if Engine.has_singleton("GameState") and GameState.has_method("request_level_change"):
		GameState.request_level_change(target)
	else:
		if target != "":
			get_tree().change_scene(target)
