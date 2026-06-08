extends GdUnitTestSuite


func test_nucleo_prisma_ready_sets_group() -> void:
	var n = auto_free(load("res://objects/NucleoDePrisma.tscn").instantiate())
	add_child(n)
	assert_bool(n.is_in_group("prism_core")).is_true()


func test_nucleo_prisma_bob_animation_moves_position() -> void:
	var n = auto_free(load("res://objects/NucleoDePrisma.tscn").instantiate())
	add_child(n)
	n._base_local_position = n.position
	var start_pos = n.position

	n._process(1.0)

	assert_bool(n.position != start_pos).is_true()
