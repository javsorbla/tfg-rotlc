extends ProyectilBase

func _ready() -> void:
	super._ready()
	$AnimatedSprite2D.play("orb")

func get_speed() -> float:
	return 200.0

func get_damage() -> int:
	return 2
