extends CanvasModulate

@export var velocidad_transicion: float = 2.0
@export var color_default: Color = Color("#aaaaaa")
var color_objetivo: Color
var parallax: Node

func _ready():
	color_objetivo = color
	parallax = get_tree().get_first_node_in_group("parallax")
	
func _process(delta):
	color = color.lerp(color_objetivo, delta * velocidad_transicion)
	if parallax:
		for layer in parallax.get_children():
			for clouds in layer.get_children():
				for sprite in clouds.get_children(): 
					sprite.modulate = color

func cambiar_zona(nuevo_color: Color):
	color_objetivo = nuevo_color
