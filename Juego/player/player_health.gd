extends Node

signal died(owner: Node)

const BASE_MAX_HEALTH = 3
const INVINCIBILITY_DURATION = 1.0
const FLASH_DURATION = 0.1

var MAX_HEALTH = BASE_MAX_HEALTH
var current_health = MAX_HEALTH
var is_invincible = false
var invincibility_timer = 0.0
var flash_timer = 0.0
var death_callback: Callable

@onready var player = get_parent()
@onready var hurtbox = get_parent().get_node("Hurtbox")
@onready var sprite = get_parent().get_node("AnimatedSprite2D")
@onready var camera = get_tree().get_first_node_in_group("camera")
@onready var heal_particles = get_parent().get_node("HealParticles")


func _ready():
	hurtbox.monitorable = true
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	call_deferred("_init_hud")


func _init_hud():
	_sync_max_health_from_progress()
	current_health = MAX_HEALTH
	Hud.update_hearts(current_health, MAX_HEALTH)


func process(delta):
	_handle_invincibility(delta)
	_handle_flash(delta)


func take_damage(amount: int, bypass_shield: bool = false):
	if (player.is_shielding and not bypass_shield) or is_invincible:
		return
	current_health -= amount
	Hud.update_hearts(current_health, MAX_HEALTH)
	is_invincible = true
	invincibility_timer = INVINCIBILITY_DURATION
	flash_timer = FLASH_DURATION
	if camera:
		camera.shake()
	Hud.update_hearts(current_health, MAX_HEALTH)
	if current_health <= 0:
		die()


func set_death_callback(callback: Callable) -> void:
	death_callback = callback

func die():
	_invoke_death_callback()
	_reset_player()

func _reset_player():
	_sync_max_health_from_progress()
	current_health = MAX_HEALTH
	is_invincible = true
	invincibility_timer = 0.6
	flash_timer = 0.0
	if sprite.material:
		sprite.material.set_shader_parameter("flash_amount", 0.0)
	sprite.visible = true
	hurtbox.set_deferred("monitorable", false)
	player.global_position = GameState.spawn_position
	player.velocity = Vector2.ZERO
	player.can_double_jump = false
	player.is_dashing = false
	player.is_shielding = false
	player.can_jump = true
	var color_manager = player.get_node_or_null("ColorManager")
	if color_manager and color_manager.has_method("reset_for_respawn"):
		color_manager.reset_for_respawn()
	Hud.reset_for_respawn()
	GameState.level_reset.emit()


func _invoke_death_callback() -> void:
	if death_callback.is_valid():
		death_callback.call()

func _handle_invincibility(delta):
	if is_invincible:
		invincibility_timer -= delta
		hurtbox.set_deferred("monitorable", false)
		sprite.visible = not sprite.visible if fmod(invincibility_timer, 0.2) < 0.1 else true
		if invincibility_timer <= 0:
			is_invincible = false
			hurtbox.set_deferred("monitorable", true)
			sprite.visible = true

func _handle_flash(delta):
	if sprite.material == null:
		return
	if flash_timer > 0:
		flash_timer -= delta
		sprite.material.set_shader_parameter("flash_amount", 1.0)
	else:
		sprite.material.set_shader_parameter("flash_amount", 0.0)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		take_damage(enemy.DAMAGE)

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("spikes"):
		take_damage(1)
		
func heal(amount: int):
	current_health = min(current_health + amount, MAX_HEALTH)
	Hud.update_hearts(current_health, MAX_HEALTH)
	if heal_particles:
		heal_particles.restart()


func apply_prism_core_upgrade() -> bool:
	var was_collected := GameState.collect_prism_core(GameState.current_level)
	_sync_max_health_from_progress()
	current_health = MAX_HEALTH
	Hud.update_hearts(current_health, MAX_HEALTH)
	if heal_particles:
		heal_particles.restart()
	return was_collected


func _sync_max_health_from_progress() -> void:
	if GameState.has_method("get_player_max_health"):
		MAX_HEALTH = int(GameState.get_player_max_health())
	else:
		MAX_HEALTH = BASE_MAX_HEALTH
