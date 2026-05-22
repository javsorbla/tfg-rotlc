extends Node2D

@export var escena_pincho: PackedScene
@export var tiempo_entre_pinchos: float = 1.5
@export var ancho_generacion: float = 600.0
@export var separacion_pinchos: float = 32.0 # Distancia en píxeles entre cada pincho

@onready var timer = $Timer

func _ready():
	timer.wait_time = tiempo_entre_pinchos
	timer.start()

func _on_timer_timeout():
	if escena_pincho == null:
		return
		
	# Calculamos cuántos pinchos caben en la zona que has definido
	var cantidad_pinchos = int(ancho_generacion / separacion_pinchos)
	
	# Calculamos dónde empieza el extremo izquierdo de la zona
	var inicio_x = -ancho_generacion / 2.0
	
	# Bucle: Repite la creación de pinchos tantas veces como quepan en la fila
	for i in range(cantidad_pinchos + 1):
		var nuevo_pincho = escena_pincho.instantiate()
		
		# Los colocamos en fila india sumando la separación
		var posicion_x = inicio_x + (i * separacion_pinchos)
		nuevo_pincho.position = Vector2(posicion_x, 0)
		
		add_child(nuevo_pincho)