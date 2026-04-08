extends CanvasLayer

@onready var hearts = [$Hearts/Heart1, $Hearts/Heart2, $Hearts/Heart3]
var heart_full: Texture2D = preload("res://assets//ui/heart.png")
var heart_empty: Texture2D = preload("res://assets//ui/heart_empty.png")

func _ready():
	show()
	update_hearts(3, 3)

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
