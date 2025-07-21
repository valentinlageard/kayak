class_name FlowFieldSource
extends Area2D

@export var min_strength: float = 1.0
@export var max_strength: float = 10.0

# --- Registration with Manager ---
func _ready():
	print("[", self.name, "] Attempting to register with manager...")
	FlowfieldManager.register_source(self)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if FlowfieldManager:
			FlowfieldManager.unregister_source(self)

# --- Virtual Method (to be implemented by children) ---
# This is the core function that child classes MUST override.
func get_vector_at(_world_position: Vector2) -> Vector2:
	# Base implementation returns zero. Child classes provide the real logic.
	# We multiply by strength here as a final step.
	return Vector2.ZERO

# --- Helper Function ---
# Checks if a point is inside our CollisionShape2D.
func is_position_in_field(world_position: Vector2) -> bool:
	# This uses the physics server for a precise check against our shape.
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collision_mask = self.collision_layer # Make sure it only checks against itself
	var result = space_state.intersect_point(query)
	
	# Check if any of the results match this specific Area2D instance.
	for r in result:
		if r.collider == self:
			return true
	return false

	
