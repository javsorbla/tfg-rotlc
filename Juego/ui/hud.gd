extends CanvasLayer

var hearts = []
var heart_container: HBoxContainer
var heart_template: TextureRect
var power_nodes = {}
var power_overlays = {}
var heart_full: Texture2D = preload("res://assets/ui/heart.png")
var heart_empty: Texture2D = preload("res://assets/ui/heart_empty.png")
var duration_bars = {}

const MAX_DURATIONS = {
	"cyan": 6.0,
	"red": 5.0,
	"yellow": 3.0
}

const MAX_COOLDOWNS = {
	"cyan": 3.0,
	"red": 5.0,
	"yellow": 7.0
}


func _ready():
	heart_container = $Control/Hearts
	heart_template = $Control/Hearts/Heart1
	hearts = [heart_template]
	for i in range(2, 4):
		var existing_heart := heart_container.get_node_or_null("Heart%d" % i)
		if existing_heart != null:
			hearts.append(existing_heart)
	for heart in hearts:
		if heart != null:
			heart.texture = heart_full
	power_nodes = {
		"cyan": $Control/Powers/Cyan/RechargeBar,
		"red": $Control/Powers/Red/RechargeBar,
		"yellow": $Control/Powers/Yellow/RechargeBar
	}
	power_overlays = power_nodes  
	show()
	update_hearts(GameState.get_player_max_health(), GameState.get_player_max_health())
	for power in power_overlays:
		power_overlays[power].visible = false
		
	duration_bars = {
		"cyan": $Control/Powers/Cyan/DurationBar,
		"red": $Control/Powers/Red/DurationBar,
		"yellow": $Control/Powers/Yellow/DurationBar
	}
	for power in duration_bars:
		duration_bars[power].visible = false
	hide()


func show_hud():
	show()


func hide_hud():
	hide()


func update_hearts(current: int, maximum: int):
	_ensure_heart_slots(maximum)
	for i in hearts.size():
		if hearts[i] != null:
			var was_full = hearts[i].texture == heart_full
			var is_full = i < current
			if was_full and not is_full:
				var lose_particles = hearts[i].get_node_or_null("ParticlesLose")
				if lose_particles != null:
					lose_particles.restart()
			elif not was_full and is_full:
				var gain_particles = hearts[i].get_node_or_null("ParticlesGain")
				if gain_particles != null:
					gain_particles.restart()
			if is_full:
				hearts[i].texture = heart_full
			else:
				hearts[i].texture = heart_empty


func reset_for_respawn() -> void:
	var max_health := GameState.get_player_max_health()
	update_hearts(max_health, max_health)
	for power in power_overlays:
		if power_overlays[power] != null:
			power_overlays[power].visible = false
	for power in duration_bars:
		if duration_bars[power] != null:
			duration_bars[power].visible = false


func _ensure_heart_slots(maximum: int) -> void:
	if heart_container == null or heart_template == null:
		return

	var target := maxi(1, maximum)
	while hearts.size() < target:
		var new_heart := heart_template.duplicate(DUPLICATE_SIGNALS | DUPLICATE_GROUPS | DUPLICATE_SCRIPTS)
		new_heart.name = "Heart%d" % (hearts.size() + 1)
		heart_container.add_child(new_heart)
		hearts.append(new_heart)

	while hearts.size() > target:
		var removed_heart = hearts.pop_back()
		if removed_heart != null:
			removed_heart.queue_free()


func update_powers(active_power: String, unlocked: Dictionary):
	for power in power_nodes:
		if power_nodes[power] != null:
			if not unlocked[power]:
				power_nodes[power].modulate = Color(0.3, 0.3, 0.3, 1)
			elif active_power == power:
				power_nodes[power].modulate = Color(1, 1, 1, 1)
			else:
				power_nodes[power].modulate = Color(0.2, 0.2, 0.2, 1)


func update_cooldowns(cooldown_timers: Dictionary, active_power: String, unlocked: Dictionary, power_timer: float = 0.0):
	for power in power_nodes:
		if power_nodes[power] == null:
			continue
		if not unlocked[power]:
			continue
		var remaining = cooldown_timers[power]
		var ratio = 1.0 - (remaining / MAX_COOLDOWNS[power])
		
		if active_power == power:
			# Usando: icono brilla y barra vaciandose para indicar tiempo restante
			var duration_ratio = power_timer / MAX_DURATIONS[power]
			power_nodes[power].modulate = Color(1, 1, 1, 1)
			power_overlays[power].visible = true
			power_overlays[power].value = duration_ratio
			power_overlays[power].modulate = Color(1.2, 1.2, 1.2, 1)
			duration_bars[power].visible = false
		elif remaining > 0:
			# Cooldown: icono transparente y barra subiendo
			power_nodes[power].modulate = Color(1, 1, 1, 1)
			power_overlays[power].visible = true
			power_overlays[power].value = ratio
			power_overlays[power].modulate = Color(0.6, 0.6, 0.6, 1)
			duration_bars[power].visible = false
		else:
			# Sin usar: icono apagado
			power_nodes[power].modulate = Color(1, 1, 1, 1)
			power_overlays[power].visible = true
			power_overlays[power].value = 1.0
			power_overlays[power].modulate = Color(0.6, 0.6, 0.6, 1)
			duration_bars[power].visible = false
