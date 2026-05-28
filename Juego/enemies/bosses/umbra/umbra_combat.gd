extends Node

const DARKNESS_ZONE_SCRIPT := preload("res://enemies/bosses/umbra/darkness_zone.gd")

@onready var umbra = get_parent()
@onready var attack_hitbox: Area2D = umbra.get_node("AttackHitbox")
var _darkness_container: Node2D


func setup() -> void:
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	_ensure_darkness_container()
	if not attack_hitbox.body_entered.is_connected(_on_attack_hitbox_body_entered):
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	if not attack_hitbox.area_entered.is_connected(_on_attack_hitbox_area_entered):
		attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)


func process_timers(delta: float) -> void:
	if umbra._darkness_cooldown_timer > 0.0:
		umbra._darkness_cooldown_timer -= delta
	if umbra._darkness_try_timer > 0.0:
		umbra._darkness_try_timer -= delta


func handle_darkness_attack() -> void:
	var darkness_power_gate: bool = (not bool(umbra.darkness_requires_power)) or bool(umbra.color_manager._is_power_active())
	var darkness_power_type_gate: bool = bool(umbra.darkness_available_in_all_powers) or String(umbra.current_power) == "red"
	var darkness_allowed: bool = bool(umbra._allow_darkness_cast) and darkness_power_gate and darkness_power_type_gate
	if darkness_allowed:
		if umbra._darkness_try_timer <= 0.0:
			umbra._darkness_try_timer = umbra._darkness_cast_interval_runtime
			_try_cast_darkness_zone()
	else:
		umbra._darkness_try_timer = minf(umbra._darkness_try_timer, 0.6)


func process(delta: float) -> void:
	if umbra.is_dashing:
		return

	if umbra.is_attacking:
		umbra.velocity.x = 0.0
		umbra.attack_timer -= delta
		if umbra.attack_timer <= 0.0:
			umbra.is_attacking = false
			attack_hitbox.monitoring = false
			attack_hitbox.monitorable = false
		return

	var auto_attack := false
	var player: Node2D = umbra.get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var rel: Vector2 = player.global_position - umbra.global_position
		auto_attack = absf(rel.x) <= umbra.AUTO_ATTACK_DISTANCE_X and absf(rel.y) <= umbra.AUTO_ATTACK_DISTANCE_Y
		if auto_attack and absf(rel.x) > 6.0:
			umbra.last_direction = signi(int(rel.x))

	if (umbra.ai_should_attack or auto_attack) and umbra.attack_cooldown_timer <= 0.0:
		umbra.is_attacking = true
		umbra.ai_move_direction = 0
		umbra.attack_timer = umbra.ATTACK_DURATION
		umbra.attack_cooldown_timer = umbra._attack_cooldown_runtime
		attack_hitbox.monitoring = true
		attack_hitbox.monitorable = true
		attack_hitbox.position = Vector2(14 * umbra.last_direction, 0)
		if umbra.debug_combat_logs:
			print("Umbra ATTACK start | ai=", umbra.ai_should_attack, " auto=", auto_attack, " dir=", umbra.last_direction)


func cancel_attack_state() -> void:
	umbra.is_attacking = false
	umbra.attack_timer = 0.0
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false


func _ensure_darkness_container() -> void:
	if _darkness_container != null and is_instance_valid(_darkness_container):
		return

	var scene_root := umbra.get_tree().current_scene
	if scene_root == null:
		scene_root = umbra.get_tree().root

	_darkness_container = scene_root.get_node_or_null("DarknessContainer") as Node2D
	if _darkness_container != null:
		return

	_darkness_container = Node2D.new()
	_darkness_container.name = "DarknessContainer"
	scene_root.call_deferred("add_child", _darkness_container)


func _try_cast_darkness_zone() -> void:
	if umbra._darkness_cooldown_timer > 0.0:
		return

	var player: Node2D = umbra.get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var dist: float = umbra.global_position.distance_to(player.global_position)
	if not umbra.darkness_relax_distance_checks and (dist < umbra.darkness_min_cast_distance or dist > umbra.darkness_max_cast_distance):
		return

	if umbra.darkness_try_chance < 0.999 and randf() > umbra.darkness_try_chance:
		return

	var spawn_pos := player.global_position + Vector2(umbra.darkness_spawn_offset_x, umbra.darkness_spawn_offset_y)
	_spawn_darkness_zone(spawn_pos)
	umbra._darkness_cooldown_timer = umbra._darkness_cooldown_runtime

	if umbra.debug_darkness_logs:
		print("Umbra CAST darkness @", spawn_pos)


func _spawn_darkness_zone(spawn_pos: Vector2) -> void:
	var player: Node2D = umbra.get_tree().get_first_node_in_group("player") as Node2D
	var spawn_parent: Node = null
	if player != null and player.get_parent() != null:
		spawn_parent = player.get_parent()
	else:
		if _darkness_container == null or not is_instance_valid(_darkness_container) or not _darkness_container.is_inside_tree():
			_ensure_darkness_container()
		spawn_parent = _darkness_container

	if spawn_parent == null:
		return

	var zone := DARKNESS_ZONE_SCRIPT.new() as Area2D
	if zone == null:
		zone = Area2D.new()
		zone.script = DARKNESS_ZONE_SCRIPT
	zone.top_level = false
	zone.z_as_relative = false
	zone.z_index = 100
	zone.collision_layer = 16
	zone.collision_mask = 4

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = umbra.darkness_zone_radius
	shape.shape = circle
	zone.add_child(shape)

	if zone.has_method("configure"):
		zone.configure(
			umbra.darkness_zone_tick_damage,
			umbra.darkness_zone_tick_interval,
			umbra.darkness_zone_duration,
			umbra.darkness_zone_arming_delay
		)

	spawn_parent.call_deferred("add_child", zone)
	zone.set_deferred("global_position", spawn_pos)


func _on_attack_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if umbra.debug_combat_logs:
			print("Umbra HIT player")
		if body.has_method("get"):
			var health_node = body.get("health")
			if health_node and health_node.has_method("take_damage"):
				health_node.take_damage(umbra.color_manager.get_attack_damage())


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_hurtbox"):
		return

	var owner = area.get_parent()
	if owner and owner.is_in_group("player"):
		if umbra.debug_combat_logs:
			print("Umbra HIT player hurtbox")
		if owner.has_method("get"):
			var health_node = owner.get("health")
			if health_node and health_node.has_method("take_damage"):
				health_node.take_damage(umbra.color_manager.get_attack_damage())
