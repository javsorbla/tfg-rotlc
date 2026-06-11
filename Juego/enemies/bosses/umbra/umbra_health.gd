extends Node

@onready var umbra = get_parent()
@onready var hurtbox: Area2D = umbra.get_node("Hurtbox")

# Contador de golpes para dropear orbes de luz
var hits_until_orb := 3
var hits_received := 0
const MAX_ACTIVE_ORBS := 4

const ORBE_LUZ_SCENE := preload("res://objects/OrbeDeLuz.tscn")

const DAMAGE_FLASH_TIME := 0.08
var _damage_flash_tween: Tween = null


func setup() -> void:
	hurtbox.set_deferred("monitorable", true)
	if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	# Resetear contador de golpes cuando el jugador muere
	if not GameState.level_reset.is_connected(_on_level_reset):
		GameState.level_reset.connect(_on_level_reset)


func process_timers(delta: float) -> void:
	if umbra.invincibility_timer > 0.0:
		umbra.invincibility_timer -= delta
		if umbra.invincibility_timer <= 0.0:
			umbra.is_invincible = false
			hurtbox.set_deferred("monitorable", true)


func take_damage(amount: int) -> void:
	if umbra.is_invincible:
		return

	umbra.current_health -= amount
	_play_damage_flash()
	umbra.is_invincible = true
	umbra.invincibility_timer = umbra.INVINCIBILITY_DURATION
	hurtbox.set_deferred("monitorable", false)
	
	# Incrementar contador de golpes y dropear orbe cada 3 impactos
	hits_received += 1
	if hits_received >= hits_until_orb:
		_spawn_healing_orb()
		hits_received = 0
	
	if umbra.current_health <= 0:
		umbra.die()


func _play_damage_flash() -> void:
	var sprite: AnimatedSprite2D = umbra.get_node("AnimatedSprite2D")
	if sprite == null or sprite.material == null:
		return
	if _damage_flash_tween:
		_damage_flash_tween.kill()
	sprite.material.set_shader_parameter("flash_amount", 1.0)
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_method(
		func(v: float): sprite.material.set_shader_parameter("flash_amount", v),
		1.0, 0.0, DAMAGE_FLASH_TIME
	)


func _spawn_healing_orb() -> void:
	if ORBE_LUZ_SCENE == null:
		return

	const BOSS_ZONE_RADIUS := 900.0
	var active_orbs := get_tree().get_nodes_in_group("light_orb")
	var local_orb_count := 0
	for orb in active_orbs:
		if is_instance_valid(orb) and orb.global_position.distance_to(umbra.global_position) <= BOSS_ZONE_RADIUS:
			local_orb_count += 1
	if local_orb_count >= MAX_ACTIVE_ORBS:
		return

	# No dropear durante entrenamiento
	var sync_node = get_tree().get_first_node_in_group("sync_node")
	if sync_node != null and sync_node.control_mode == 1:
		return

	var scene_root = get_tree().root.get_child(0)
	if scene_root == null:
		return

	var orbe = ORBE_LUZ_SCENE.instantiate()
	orbe.is_spawned = true
	orbe.global_position = umbra.global_position + Vector2(randf_range(-40, 40), -40)
	scene_root.call_deferred("add_child", orbe)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var attacker := area.get_parent()

		var damage := 1
		if attacker and attacker.is_in_group("player"):
			var combat_node := attacker.get_node_or_null("Combat")
			if combat_node != null and combat_node.has_method("get"):
				if not bool(combat_node.get("is_attacking")):
					return
			if attacker.has_method("get"):
				var attacker_multiplier = float(attacker.get("damage_multiplier"))
				damage = maxi(1, int(round(attacker_multiplier)))

		take_damage(damage)


func _on_level_reset() -> void:
	hits_received = 0
	umbra.is_invincible = false
	umbra.invincibility_timer = 0.0
	hurtbox.set_deferred("monitorable", true)

	# Limpiar orbes que hayan quedado en escena al reiniciar.
	for orb in get_tree().get_nodes_in_group("light_orb"):
		if is_instance_valid(orb) and orb.has_method("get") and bool(orb.get("is_spawned")):
			orb.queue_free()
