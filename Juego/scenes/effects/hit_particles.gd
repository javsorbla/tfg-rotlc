extends GPUParticles2D


func play():
	emitting = true
	# Auto destruirse cuando terminen las partículas
	await get_tree().create_timer(lifetime * 2).timeout
	queue_free()
