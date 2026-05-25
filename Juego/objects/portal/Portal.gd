extends Area2D

@export var target_scene_path: String = ""
@export var auto_change_scene: bool = true

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	# Load portal visual
	var tex = load("res://assets/environment/portal_sheet.png")
	if tex and sprite:
		sprite.texture = tex
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		body_entered.connect(Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	GameState.coming_from_transition = true
	if auto_change_scene and target_scene_path != "":
		get_tree().change_scene_to_file(target_scene_path)
	else:
		emit_signal("portal_entered", target_scene_path)
