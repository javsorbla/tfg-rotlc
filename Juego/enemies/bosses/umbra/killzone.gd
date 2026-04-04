extends Area2D

@onready var training = get_parent()

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	training._reset()
