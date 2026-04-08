extends CanvasLayer

var hearts = []
var power_nodes = {}
var power_overlays = {}
var heart_full: Texture2D = preload("res://assets/ui/heart.png")
var heart_empty: Texture2D = preload("res://assets/ui/heart_empty.png")

const MAX_COOLDOWNS = {
	"cyan": 3.0,
	"red": 5.0,
	"yellow": 7.0
}

func _ready():
	hearts = [$Control/Hearts/Heart1, $Control/Hearts/Heart2, $Control/Hearts/Heart3]
	power_nodes = {
		"cyan": $Control/Powers/Cyan,
		"red": $Control/Powers/Red,
		"yellow": $Control/Powers/Yellow
	}
	power_overlays = power_nodes  # Son el mismo nodo ahora
	show()
	update_hearts(3, 3)
	for power in power_overlays:
		power_overlays[power].visible = false

func show_hud():
	show()

func hide_hud():
	hide()

func update_hearts(current: int, maximum: int):
	for i in hearts.size():
		if hearts[i] != null:
			var was_full = hearts[i].texture == heart_full
			var is_full = i < current
			if was_full and not is_full:
				hearts[i].get_node("ParticlesLose").restart()
			elif not was_full and is_full:
				hearts[i].get_node("ParticlesGain").restart()
			if is_full:
				hearts[i].texture = heart_full
			else:
				hearts[i].texture = heart_empty

func update_powers(active_power: String, unlocked: Dictionary):
	for power in power_nodes:
		if power_nodes[power] != null:
			if not unlocked[power]:
				power_nodes[power].modulate = Color(0.3, 0.3, 0.3, 1)
			elif active_power == power:
				power_nodes[power].modulate = Color(1, 1, 1, 1)
			else:
				power_nodes[power].modulate = Color(0.2, 0.2, 0.2, 1)

func update_cooldowns(cooldown_timers: Dictionary, active_power: String, unlocked: Dictionary):
	for power in power_nodes:
		if power_nodes[power] == null:
			continue
		if not unlocked[power]:
			continue
		var remaining = cooldown_timers[power]
		var ratio = 1.0 - (remaining / MAX_COOLDOWNS[power])
		if active_power == power:
			# Usando: brillante
			power_nodes[power].modulate = Color(1, 1, 1, 1)
			power_overlays[power].visible = true
			power_overlays[power].value = 1.0
			power_overlays[power].modulate = Color(1.2, 1.2, 1.2, 1)
		elif remaining > 0:
			# Cooldown: apagado con barra subiendo
			power_nodes[power].modulate = Color(1, 1, 1, 1)
			power_overlays[power].visible = true
			power_overlays[power].value = ratio
			power_overlays[power].modulate = Color(0.6, 0.6, 0.6, 1)
		else:
			# Sin usar: tono apagado
			power_nodes[power].modulate = Color(1, 1, 1, 1)
			power_overlays[power].visible = true
			power_overlays[power].value = 1.0
			power_overlays[power].modulate = Color(0.6, 0.6, 0.6, 1)
