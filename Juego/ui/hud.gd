extends CanvasLayer

@onready var hearts = [$Hearts/Heart1, $Hearts/Heart2, $Hearts/Heart3]

var heart_full: Texture2D = preload("res://assets//ui/heart.png")
var heart_empty: Texture2D = preload("res://assets//ui/heart_empty.png")

func update_hearts(current: int, maximum: int):
	for i in hearts.size():
		if i < hearts.size() and hearts[i] != null:
			if i < current:
				hearts[i].texture = heart_full
			else:
				hearts[i].texture = heart_empty
