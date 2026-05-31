extends Area2D

@export var color_zona: Color = Color("#1a1a1a")
var canvas_modulate: CanvasModulate

func _ready():
	canvas_modulate = get_tree().get_first_node_in_group("canvas_modulate")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		canvas_modulate.cambiar_zona(color_zona)

func _on_body_exited(body):
	if body.is_in_group("player"):
		canvas_modulate.cambiar_zona(Color("#aaaaaa"))
