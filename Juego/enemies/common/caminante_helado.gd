extends CharacterBody2D

var target: Node2D = null
var detection_range = 180.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	target = _find_player_target()

func _physics_process(_delta):
	if not target:
		target = _find_player_target()
		return

	_update_animation_state()

func _update_animation_state():
	if not target:
		animated_sprite.play("idle")
		return

	var distance_to_target = global_position.distance_to(target.global_position)
	var dx = target.global_position.x - global_position.x

	if distance_to_target > detection_range:
		animated_sprite.play("idle")
	elif dx < 0:
		animated_sprite.play("walk_left")
	elif dx > 0:
		animated_sprite.play("walk_right")
	else:
		animated_sprite.play("idle")

func _find_player_target() -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		if node != self and node is Node2D and node.name == "Player":
			return node as Node2D
	for node in get_tree().get_nodes_in_group("player"):
		if node != self and node is Node2D:
			return node as Node2D
	return null

# ==========================================
# PARCHE DE SEGURIDAD PARA EVITAR CRASHEOS
# ==========================================
func take_damage(amount: int):
	# "pass" le dice a Godot: "Sé que me has llamado, pero no hagas nada".
	# Así el juego no se cierra cuando tu jugador le pega.
	pass