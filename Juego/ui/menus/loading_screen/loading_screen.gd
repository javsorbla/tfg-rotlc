extends LoadingScreen

func _ready() -> void:
	# Wait one frame before applying progression
	await get_tree().process_frame
	MenuProgressionHelper.apply_progress_to_node(self)
