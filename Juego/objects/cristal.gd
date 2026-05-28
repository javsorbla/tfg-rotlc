extends Area2D

signal collected(level_id: int, variant: int, collector: Node)

@export var visual_variant: int = 0
@export var variants: Array[Texture2D] = []
@export var level_id: int = -1
@export var is_persistent: bool = true
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var glow: PointLight2D = get_node_or_null("PointLight2D")

# Glow parameters
@export var glow_energy: float = 0.75
@export var glow_pulse_enabled: bool = true
@export var glow_pulse_min: float = 0.45
@export var glow_pulse_max: float = 1.0
@export var glow_pulse_speed: float = 1.2
var _glow_pulse_dir: int = 1

@export var follow_player: bool = true
@export var follow_speed: float = 120.0
@export var follow_start_distance: float = 300.0
@export var follow_stop_distance: float = 16.0

@onready var _player_ref: Node2D = null

var _initial_collision_layer: int = 0
var _initial_collision_mask: int = 0

func _ready() -> void:
	_initial_collision_layer = collision_layer
	_initial_collision_mask = collision_mask

	# Seleccionar animación según variante
	if anim != null:
		var names: Array[String] = ["cyan", "red", "yellow"]
		var idx: int = int(clamp(visual_variant, 0, names.size() - 1))
		var anim_name: String = names[idx]
		if anim.sprite_frames != null and anim.sprite_frames.has_animation(anim_name):
			anim.play(anim_name)
		else:
			if anim.sprite_frames != null:
				var anims: Array[String] = anim.sprite_frames.get_animation_names()
				if anims.size() > 0:
					anim.play(anims[0])

	# Identificar como cristal de jefe para consultas rápidas
	if not is_in_group("boss_crystal"):
		add_to_group("boss_crystal")
	body_entered.connect(_on_body_entered)

	# Inicializar glow
	if glow != null:
		glow.energy = glow_energy
		_match_glow_color()

func _physics_process(delta: float) -> void:
	if not follow_player:
		return

	# Cachear referencia al jugador si no existe
	if _player_ref == null or not is_instance_valid(_player_ref):
		var players: Array = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player_ref = players[0] as Node2D
		else:
			return

	if _player_ref == null:
		return

	var dist: float = global_position.distance_to(_player_ref.global_position)
	if dist > follow_start_distance:
		return

	# Si ya estamos muy cerca, no nos movemos
	if dist <= follow_stop_distance:
		return

	var dir: Vector2 = (_player_ref.global_position - global_position).normalized()
	global_position += dir * follow_speed * delta

	# Handle glow pulsing
	if glow != null and glow_pulse_enabled:
		# simple ping-pong pulse
		glow.energy += _glow_pulse_dir * glow_pulse_speed * delta
		if glow.energy >= glow_pulse_max:
			glow.energy = glow_pulse_max
			_glow_pulse_dir = -1
		elif glow.energy <= glow_pulse_min:
			glow.energy = glow_pulse_min
			_glow_pulse_dir = 1


func _match_glow_color() -> void:
	if glow == null:
		return
	var colors: Array[Color] = [Color(0.558801, 0.845454, 0.985056), Color(1.0, 0.2, 0.2), Color(1.0, 0.9, 0.0)]
	var idx: int = int(clamp(visual_variant, 0, colors.size() - 1))
	glow.color = colors[idx]

func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return

	# Resolver el nodo raíz del jugador en caso de que el body detectado sea un hijo
	var player_node: Node = body
	while player_node != null and not player_node.is_in_group("player"):
		player_node = player_node.get_parent()
	if player_node == null:
		return

	var resolved_level := level_id if level_id > 0 else GameState.current_level

	if is_persistent:
		if GameState.has_boss_crystal(resolved_level, visual_variant):
			queue_free()
			return
		GameState.collect_boss_crystal(resolved_level, visual_variant)

		# Desbloquear el poder correspondiente al cristal
		var color_names: Array[String] = ["cyan", "red", "yellow"]
		var color_idx: int = int(clamp(visual_variant, 0, color_names.size() - 1))
		var color_name: String = color_names[color_idx]
		var color_manager = player_node.get_node_or_null("ColorManager")
		if color_manager != null and color_manager.has_method("unlock_power"):
			color_manager.unlock_power(color_name)
			if color_manager.has_method("change_state"):
				match color_name:
					"cyan":
						if color_manager.cyan_state != null:
							color_manager.change_state(color_manager.cyan_state)
					"red":
						if color_manager.red_state != null:
							color_manager.change_state(color_manager.red_state)
					"yellow":
						if color_manager.yellow_state != null:
							color_manager.change_state(color_manager.yellow_state)
		else:
			if GameState.has_method("unlock_power"):
				GameState.unlock_power(color_name)
				var cm2 = player_node.get_node_or_null("ColorManager")
				if cm2 != null and cm2.has_method("apply_unlocked_powers"):
					cm2.apply_unlocked_powers(GameState.get_unlocked_powers())
					if cm2.has_method("change_state"):
						match color_name:
							"cyan":
								if cm2.cyan_state != null:
									cm2.change_state(cm2.cyan_state)
							"red":
								if cm2.red_state != null:
									cm2.change_state(cm2.red_state)
							"yellow":
								if cm2.yellow_state != null:
									cm2.change_state(cm2.yellow_state)

	if player_node.has_method("play_obtain_animation"):
		player_node.call_deferred("play_obtain_animation")

	emit_signal("collected", resolved_level, visual_variant, player_node)
	queue_free()
