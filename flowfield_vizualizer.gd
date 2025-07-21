# FlowFieldVisualizer.gd (With Absolute Grid Snapping)
extends Node2D

@export var cell_size: int = 40
@export var grid_extents: Vector2i = Vector2i(50, 30) # Total cells (width, height)
@export var line_length_multiplier: float = 0.1
@export var target_node: NodePath
@export var line_color: Color

var cached_vectors: Dictionary = {}
var target: Node2D

func _ready():
	# Find the node from the path we set in the editor.
	if not target_node.is_empty():
		target = get_node(target_node)
	
	if not target is Node2D:
		push_error("Visualizer target is not set or is not a Node2D.")
		set_process(false)
		if has_node("Timer"): $Timer.stop()
		return
	
	# Initial cache update is now handled by the Timer via Autostart.

# The visualizer itself no longer needs a _process function.
# Its position will be updated just before the cache is rebuilt.

# This function is called by the Timer every second.
func update_field_cache():
	if not is_instance_valid(target):
		return

	var target_world_position = target.global_position
	
	var snapped_center_x = snapped(target_world_position.x, cell_size)
	var snapped_center_y = snapped(target_world_position.y, cell_size)
	var grid_center_world_pos = Vector2(snapped_center_x, snapped_center_y)
	
	self.global_position = grid_center_world_pos
	
	cached_vectors.clear()
	var half_extents = grid_extents / 2

	for y in range(-half_extents.y, half_extents.y):
		for x in range(-half_extents.x, half_extents.x):
			var grid_pos = Vector2i(x, y)
			
			var world_pos_to_sample = grid_center_world_pos + Vector2(x * cell_size, y * cell_size)
			
			cached_vectors[grid_pos] = FlowfieldManager.get_force_at_position(world_pos_to_sample)

	queue_redraw()

func _draw():
	for grid_pos in cached_vectors:
		var force_vector = cached_vectors[grid_pos]
		if force_vector.length_squared() > 0.01:
			var local_start_pos = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
			var local_end_pos = local_start_pos + (force_vector * line_length_multiplier)
			
			draw_line(local_start_pos, local_end_pos, line_color, 0.2)
