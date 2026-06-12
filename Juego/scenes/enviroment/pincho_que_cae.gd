extends Area2D

@export var velocidad_caida: float = 400.0
@export var dano: int = 7
@export var distancia_maxima: float = 500.0

var posicion_inicial_y: float = 0.0

func _ready():
	posicion_inicial_y = global_position.y
	call_deferred("_try_play_sound")


func _try_play_sound():
	if _player_near_spike_zone():
		var sfx = AudioStreamPlayer2D.new()
		sfx.stream = load("res://music/scenes/torre_vacio/trampa_pinchos.ogg")
		sfx.bus = &"EFX"
		sfx.volume_db = -8.0
		sfx.max_distance = 600.0
		sfx.finished.connect(sfx.queue_free)
		add_child(sfx)
		sfx.play()


func _player_near_spike_zone() -> bool:
	var tree = get_tree()
	if not tree:
		return false
	var player = tree.get_first_node_in_group("player")
	if not player:
		return false
	for zone in tree.get_nodes_in_group("spike_camera_zone"):
		var area = zone as Area2D
		if area and area.overlaps_body(player):
			return true
		if area and area.global_position.distance_to(player.global_position) < 800.0:
			return true
	return false

func _physics_process(delta):
	position.y += velocidad_caida * delta
	
	if global_position.y - posicion_inicial_y >= distancia_maxima:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("player_hurtbox"):
		
		var jugador = area.owner 
		
		var health = jugador.get_node_or_null("Health")
		if health and health.has_method("take_damage"): 
			health.take_damage(dano)
			
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
