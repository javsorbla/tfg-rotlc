extends Node2D

@onready var trigger: Area2D = $Trigger
@onready var pared_izquierda_collision: CollisionShape2D = $ParedIzquierda/CollisionShape2D
@onready var pared_derecha_collision: CollisionShape2D = $ParedDerecha/CollisionShape2D

func _ready():
	trigger.body_entered.connect(_on_trigger_entered)
	pared_izquierda_collision.set_deferred("disabled", true)
	pared_derecha_collision.set_deferred("disabled", true)

func _on_trigger_entered(body):
	if body.is_in_group("player"):
		pared_izquierda_collision.set_deferred("disabled", false)
		pared_derecha_collision.set_deferred("disabled", false)
		trigger.monitoring = false
		
		var camera = get_tree().get_first_node_in_group("camera")
		if camera:
			# Desactivar seguimiento del jugador
			camera.boss_room_mode = true
			camera.boss_room_target = $Centro.global_position
			
			var tween = create_tween()
			tween.tween_property(camera, "zoom", Vector2(0.5, 0.5), 2.5)

func on_boss_defeated():
	$ParedIzquierda/CollisionShape2D.disabled = true
	$ParedDerecha/CollisionShape2D.disabled = true
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.boss_room_mode = false
		var tween = create_tween()
		tween.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.5)
