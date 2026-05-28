extends RefCounted
class_name EnemyResetUtils


static func capture_collider_state(hitbox: CollisionObject2D, hurtbox: CollisionObject2D) -> Dictionary:
	return {
		"hitbox_layer": hitbox.collision_layer if hitbox != null else 0,
		"hitbox_mask": hitbox.collision_mask if hitbox != null else 0,
		"hurtbox_layer": hurtbox.collision_layer if hurtbox != null else 0,
		"hurtbox_mask": hurtbox.collision_mask if hurtbox != null else 0,
	}


static func restore_collider_state(hitbox: CollisionObject2D, hurtbox: CollisionObject2D, state: Dictionary) -> void:
	if hitbox != null:
		hitbox.set_deferred("collision_layer", int(state.get("hitbox_layer", hitbox.collision_layer)))
		hitbox.set_deferred("collision_mask", int(state.get("hitbox_mask", hitbox.collision_mask)))
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)

	if hurtbox != null:
		hurtbox.set_deferred("collision_layer", int(state.get("hurtbox_layer", hurtbox.collision_layer)))
		hurtbox.set_deferred("collision_mask", int(state.get("hurtbox_mask", hurtbox.collision_mask)))
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)


static func despawn(node: Node2D) -> void:
	if node == null or not node.visible:
		return
	node.visible = false
	node.set_physics_process(false)