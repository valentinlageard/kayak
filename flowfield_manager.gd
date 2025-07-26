extends Node

signal field_changed

var sources: Array[Node] = []
var contributors: Array[Node] = []

func _ready() -> void:
	print("FlowfieldManager instantiated")

func get_force_at_position(world_position: Vector2) -> Vector2:
	var final_force = Vector2.ZERO

	# Pass 1: Accumulate forces from all base sources
	for source in sources:
		if not is_instance_valid(source): continue		
		if source.is_position_in_field(world_position):
			final_force += source.get_vector_at(world_position)

	# Pass 2: Accumulate forces from all local contributors
	for contributor in contributors:
		if not is_instance_valid(contributor): continue
		
		var vector_to_contrib = contributor.get_parent().global_position - world_position
		if vector_to_contrib.length_squared() < contributor.radius * contributor.radius:
			final_force += contributor.get_influence(vector_to_contrib)
	
	return final_force


# --- Registration API ---
func register_source(source: Node):
	if not source in sources:
		sources.append(source)
		print("[FlowFieldManager] Successfully registered source: ", source.name)
		field_changed.emit() # Announce that the field has changed!

func unregister_source(source: Node):
	if source in sources:
		sources.erase(source)
		field_changed.emit() # Announce that the field has changed!
		
func register_contributor(contributor: Node):
	if not contributor in contributors:
		contributors.append(contributor)
		field_changed.emit() # Announce that the field has changed!
		
func unregister_contributor(contributor: Node):
	if contributor in contributors:
		contributors.erase(contributor)
		field_changed.emit() # Announce that the field has changed!
