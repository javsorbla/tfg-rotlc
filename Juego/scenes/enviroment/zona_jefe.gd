extends Node2D

@onready var trigger: Area2D = $Trigger
@onready var pared_izquierda_collision: CollisionShape2D = $ParedIzquierda/CollisionShape2D
@onready var pared_derecha_collision: CollisionShape2D = $ParedDerecha/CollisionShape2D

var _room_key: String = ""
var _active_boss: Node
var _pending_rearm_after_reset: bool = false
var _camera_zoom_tween: Tween

func _ready():
	add_to_group("boss_room")
	_room_key = _build_room_key()
	trigger.body_entered.connect(_on_trigger_entered)
	trigger.body_exited.connect(_on_trigger_exited)
	call_deferred("_check_player_inside_trigger")
	if not GameState.level_reset.is_connected(_on_level_reset):
		GameState.level_reset.connect(_on_level_reset)

	if GameState.is_boss_room_cleared(_room_key):
		_deactivate_trigger_permanently()
		pared_izquierda_collision.set_deferred("disabled", true)
		pared_derecha_collision.set_deferred("disabled", true)
		_remove_room_boss_if_present()
		return

	pared_izquierda_collision.set_deferred("disabled", true)
	pared_derecha_collision.set_deferred("disabled", true)


func _physics_process(_delta: float) -> void:
	if not _pending_rearm_after_reset:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null or not _is_player_inside_trigger(player):
		_finish_trigger_rearm_after_reset()


func _check_player_inside_trigger() -> void:
	if GameState.is_boss_room_cleared(_room_key):
		return

	var player := get_tree().get_first_node_in_group("player")
	if player != null and trigger.overlaps_body(player):
		_on_trigger_entered(player)

func _on_trigger_entered(body):
	if _pending_rearm_after_reset or GameState.is_boss_room_cleared(_room_key):
		return
	if body.is_in_group("player"):
		pared_izquierda_collision.set_deferred("disabled", false)
		pared_derecha_collision.set_deferred("disabled", false)
		trigger.set_deferred("monitoring", false)
		
		var camera = get_tree().get_first_node_in_group("camera")
		if camera:
			# Desactivar seguimiento del jugador
			camera.boss_room_mode = true
			camera.boss_room_target = $Centro.global_position
			_tween_camera_zoom(camera, Vector2(0.5, 0.5), 2.5)
		
		# Activar el boss asociado a esta sala (no el primer boss global de la escena).
		var boss := _get_nearest_boss_to_room_center()
		_active_boss = boss
		if boss != null and boss.has_signal("defeated"):
			var defeated_callable := Callable(self, "_on_boss_defeated_signal")
			if not boss.is_connected("defeated", defeated_callable):
				boss.connect("defeated", defeated_callable)
		if boss != null and boss.has_method("activate"):
			boss.activate()

func _get_nearest_boss_to_room_center() -> Node:
	var center_pos: Vector2 = $Centro.global_position
	var nearest_boss: Node = null
	var best_dist_sq: float = INF

	for candidate in get_tree().get_nodes_in_group("boss"):
		var node2d := candidate as Node2D
		if node2d == null:
			continue
		var dist_sq: float = node2d.global_position.distance_squared_to(center_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			nearest_boss = node2d

	return nearest_boss
			
func on_boss_defeated():
	trigger.set_deferred("monitoring", false)
	trigger.set_deferred("monitorable", false)
	for child in trigger.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
	$ParedIzquierda/CollisionShape2D.set_deferred("disabled", true)
	$ParedDerecha/CollisionShape2D.set_deferred("disabled", true)
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.boss_room_mode = false
		_tween_camera_zoom(camera, Vector2(1.0, 1.0), 0.5)

	GameState.mark_boss_room_cleared(_room_key)

func _on_boss_defeated_signal(umbra_won: bool) -> void:
	if umbra_won:
		return
	on_boss_defeated()


func _build_room_key() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return GameState.make_boss_room_key(str(scene.scene_file_path), str(get_path()))


func _deactivate_trigger_permanently() -> void:
	trigger.set_deferred("monitoring", false)
	trigger.set_deferred("monitorable", false)
	for child in trigger.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)


func _remove_room_boss_if_present() -> void:
	var boss := _get_nearest_boss_to_room_center()
	if boss != null:
		boss.call_deferred("queue_free")


func _on_level_reset() -> void:
	if GameState.is_boss_room_cleared(_room_key):
		return

	# Keep the trigger disabled until the player leaves the area again.
	pared_izquierda_collision.set_deferred("disabled", true)
	pared_derecha_collision.set_deferred("disabled", true)
	_pending_rearm_after_reset = true
	trigger.monitoring = false
	trigger.set_deferred("monitoring", false)
	trigger.set_deferred("monitorable", true)
	call_deferred("_try_rearm_trigger_after_reset")

	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.boss_room_mode = false
		camera.boss_room_target = Vector2.ZERO
		_tween_camera_zoom(camera, Vector2(1.0, 1.0), 0.25)

	_active_boss = null


func _on_trigger_exited(body) -> void:
	if not _pending_rearm_after_reset:
		return
	if not body.is_in_group("player"):
		return
	call_deferred("_try_rearm_trigger_after_reset")


func _try_rearm_trigger_after_reset() -> void:
	if not _pending_rearm_after_reset:
		return
	if GameState.is_boss_room_cleared(_room_key):
		_pending_rearm_after_reset = false
		return

	var player := get_tree().get_first_node_in_group("player")
	if player != null and _is_player_inside_trigger(player):
		return

	_finish_trigger_rearm_after_reset()


func _finish_trigger_rearm_after_reset() -> void:
	_pending_rearm_after_reset = false
	trigger.set_deferred("monitorable", true)
	trigger.set_deferred("monitoring", true)


func _is_player_inside_trigger(player: Node) -> bool:
	if player == null:
		return false

	var shape_node := trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		var player_node := player as Node2D
		if player_node == null:
			return trigger.overlaps_body(player)
		var rect_shape := shape_node.shape as RectangleShape2D
		var local_point := shape_node.to_local(player_node.global_position)
		var half_size := rect_shape.size * 0.5
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y

	return trigger.overlaps_body(player)


func _tween_camera_zoom(camera: Node, target_zoom: Vector2, duration: float) -> void:
	if camera == null:
		return
	if _camera_zoom_tween != null and is_instance_valid(_camera_zoom_tween):
		_camera_zoom_tween.kill()
	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.tween_property(camera, "zoom", target_zoom, duration)
