# PathFlowFieldSource.gd (With Advanced Editor Visualization)
@tool
extends Path2D

# --- Configuration ---
@export_group("Flow Field Properties")
@export var strength: float = 300.0
@export var width: float = 100.0
@export var strength_curve: Curve

@export_group("Turbulence")
@export var noise_strength: float = 0.5
@export var noise_curve: Curve
@export var noise_scale_force: float = 0.1
@export var noise_scale_rotation: float = 1.0

# --- Editor Visualization ---
@export_group("Debug Visualization")
@export var base_debug_color: Color = Color(0.2, 0.8, 1.0, 0.4)
@export var noise_debug_color: Color = Color(1.0, 0.5, 0.2, 0.6) # Orange/Red for high noise
@export var show_speed_arrows: bool = true
@export var arrow_size: float = 15.0
@export var fast_arrow_spacing: float = 25.0 # Spacing when flow is FAST (strength = 1.0)
@export var slow_arrow_spacing: float = 200.0 # Spacing when flow is SLOW (strength = 0.0)

var noise = FastNoiseLite.new()
func _draw():
	if not Engine.is_editor_hint() or not curve or curve.get_point_count() < 2:
		return

	# --- 1. VISUALIZE PATH WIDTH AND NOISE STRENGTH (No Changes) ---
	var baked_points = curve.get_baked_points()
	if baked_points:
		for i in range(baked_points.size() - 1):
			var p1 = baked_points[i]
			var p2 = baked_points[i+1]
			var segment_midpoint = (p1 + p2) / 2.0
			var offset = curve.get_closest_offset(segment_midpoint)
			var progress = offset / curve.get_baked_length()
			var noise_multiplier = 1.0
			if noise_curve:
				noise_multiplier = noise_curve.sample(progress)
			var segment_color = base_debug_color.lerp(noise_debug_color, noise_multiplier)
			var tangent = (p2 - p1).normalized()
			var normal = tangent.orthogonal()
			draw_line(p1 + normal * width / 2, p2 + normal * width / 2, segment_color, 3.0)
			draw_line(p1 - normal * width / 2, p2 - normal * width / 2, segment_color, 3.0)

	# --- 2. VISUALIZE SPEED WITH SPACED ARROWS ---
	if show_speed_arrows:
		var total_length = curve.get_baked_length()
		if total_length < fast_arrow_spacing: # Use the minimum possible spacing for this check
			return

		var current_offset = 0.0
		while current_offset < total_length:
			var progress = current_offset / total_length
			var strength_multiplier = 1.0
			if strength_curve:
				strength_multiplier = strength_curve.sample(progress)
			
			# --- THE CRITICAL FIX ---
			# We now lerp from the SLOW spacing to the FAST spacing.
			# When strength is high (1.0), we get fast_arrow_spacing (dense).
			# When strength is low (0.0), we get slow_arrow_spacing (sparse).
			var step = lerp(slow_arrow_spacing, fast_arrow_spacing, strength_multiplier)
			
			var path_transform = curve.sample_baked_with_rotation(current_offset)
			var position = path_transform.origin
			var direction = path_transform.x
			
			_draw_arrow(position, direction)
			
			if step < 1.0: break
			current_offset += step

# --- HELPER FUNCTION FOR DRAWING ---
# Moved the drawing logic into its own function for clarity.
func _draw_arrow(position: Vector2, direction: Vector2):
	var arrow_tip = position
	var arrow_base = arrow_tip - direction * arrow_size
	draw_line(arrow_base, arrow_tip, Color.WHITE, 2.0)
	draw_line(arrow_tip, arrow_tip - direction.rotated(0.5) * arrow_size * 0.5, Color.WHITE, 2.0)
	draw_line(arrow_tip, arrow_tip - direction.rotated(-0.5) * arrow_size * 0.5, Color.WHITE, 2.0)


# --- Registration with Manager (No changes needed) ---
func _ready():
	if Engine.is_editor_hint(): return
	print("[", self.name, "] Attempting to register as a PathFlowFieldSource...")
	FlowfieldManager.register_source(self)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if Engine.is_editor_hint(): return
		FlowfieldManager.unregister_source(self)

# --- Core Logic Functions (required by the manager) ---
func is_position_in_field(world_position: Vector2) -> bool:
	# (No changes needed in this function)
	if not curve or curve.get_point_count() < 2:
		return false
	var closest_offset = curve.get_closest_offset(to_local(world_position))
	var closest_point_on_path = curve.sample_baked(closest_offset)
	return to_local(world_position).distance_to(closest_point_on_path) < width / 2.0

func get_vector_at(world_position: Vector2) -> Vector2:
	if not curve or curve.get_point_count() < 2:
		return Vector2.ZERO

	var local_pos = to_local(world_position)
	var closest_offset = curve.get_closest_offset(local_pos)
	var path_transform = curve.sample_baked_with_rotation(closest_offset)
	var path_progress = closest_offset / curve.get_baked_length()

	# 1. Get the base direction from the path's tangent
	var base_direction = path_transform.x
	
	# 2. Calculate the final noise strength for this point on the path
	var current_noise_strength = noise_strength
	if noise_curve:
		current_noise_strength *= noise_curve.sample(path_progress)

	# 3. Add turbulence using Perlin noise if enabled
	if current_noise_strength > 0:
		var noise_x = noise.get_noise_2d(world_position.x * noise_scale_rotation, world_position.y * noise_scale_rotation)
		var noise_y = noise.get_noise_2d(world_position.x * noise_scale_rotation + 1000.0, world_position.y * noise_scale_rotation)
		var rotation_offset_angle = Vector2(noise_x, noise_y).angle()
		
		# Rotate the base direction by the noise angle, scaled by the current noise strength
		base_direction = base_direction.rotated(rotation_offset_angle * current_noise_strength)
		
		var force_noise = noise.get_noise_2d(world_position.x * noise_scale_force, world_position.y * noise_scale_force)
		base_direction += Vector2(force_noise, force_noise) * current_noise_strength
		
		base_direction = base_direction.normalized()

	# 4. Calculate the final force strength
	var final_strength = strength
	if strength_curve:
		final_strength *= strength_curve.sample(path_progress)

	return base_direction * final_strength
