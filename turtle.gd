extends RigidBody2D

@export_group("Movement")
# The acceleration curve when wandering.
@export var wandering_acceleration_curve: Curve
# The acceleration curve when following.
@export var following_acceleration_curve: Curve
# The maximum force to apply when the acceleration curve is at its peak (Y=1).
@export var max_acceleration_force: float = 800.0
# The name of the animation in the AnimatedSprite2D that triggers movement.
@export var move_animation_name: String = "swim"
# The friction applied
@export var friction: float = 0.1

@export_group("Rotation")
# When wandering, the maximum random angle deviation in degrees.
@export var wandering_max_angle_deviation: float = 25.0
# The strength of the random turning impulse on each animation loop.
@export var wandering_turn_force: float = 1.0
# When following the player, the maximum random angle deviation in degrees.
@export var following_max_angle_deviation: float = 45
# The strength of the turning impulse when following the player, on each animation loop.
@export var following_turn_force: float = 1.0
# The strength of the corrective turning force when following the player.
@export var following_constant_force: float = 1.0

@export_group("Wall Avoidance")
# How far ahead the whiskers will check for walls.
@export var whisker_length: float = 20.0
# The angle of the side whiskers in degrees.
@export var whisker_angle: float = 20.0
# The strength of the corrective turning force when avoiding a wall.
@export var avoidance_force: float = 10.0

@export_group("Player collision")
@export var knockback_impulse_strength: float = 10.0

enum MovementState {
	WANDERING,
	FOLLOWING,
}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var movement_state: MovementState = MovementState.WANDERING
@onready var attach_area: Area2D = $AttachArea2D
@onready var detach_area: Area2D = $DetachArea2D
var player_to_follow: CharacterBody2D = null

var is_moving: bool = false
var animation_progress: float = 0.0

func _ready() -> void:
	# Start the turtle moving at the beginning
	animated_sprite.play(move_animation_name)
	is_moving = true
	
	if not wandering_acceleration_curve:
		printerr("Acceleration curve not set for the turtle!")
		wandering_acceleration_curve = Curve.new()
		wandering_acceleration_curve.add_point(Vector2(0, 0))
		wandering_acceleration_curve.add_point(Vector2(1, 1))
		
	if not following_acceleration_curve:
		following_acceleration_curve = wandering_acceleration_curve

# When entering AttachArea2D
func _on_attach_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body.is_in_group('player'):
		player_to_follow = body
		if movement_state == MovementState.WANDERING:
				movement_state = MovementState.FOLLOWING
				GlobalSignals.turtle_started_following.emit()

# When exiting DetachArea2D
func _on_detach_area_2d_body_shape_exited(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body.is_in_group('player'):
		player_to_follow = null
		if movement_state == MovementState.FOLLOWING:
			movement_state = MovementState.WANDERING
			GlobalSignals.turtle_stopped_following.emit()
	
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Apply friction
	var friction_force = -state.linear_velocity * friction
	state.apply_central_force(friction_force)
	
	# Apply movement
	if is_moving:
		var acceleration_multiplier = _get_animation_progress_multiplier()
		var forward_direction = state.transform.x				
		var current_force = forward_direction * max_acceleration_force * acceleration_multiplier
		state.apply_central_force(current_force)

	# Apply wall avoidance and constant turn to follow the player
	var avoidance_torque = _get_avoidance_torque(state)
	state.apply_torque(avoidance_torque)
	
	if movement_state == MovementState.FOLLOWING:
		var angle_to_player = self.get_angle_to(player_to_follow.global_position)
		var direction =(player_to_follow.global_position - self.global_position)
		state.apply_torque(angle_to_player)
		state.apply_central_force(direction.normalized() * following_constant_force)
	
	
	


# Helper function to calculate the current acceleration multiplier based on animation
func _get_animation_progress_multiplier() -> float:
	var total_frames = animated_sprite.sprite_frames.get_frame_count(move_animation_name)
	if total_frames > 1:
		animation_progress = float(animated_sprite.frame) / (total_frames - 1)
	else:
		animation_progress = 1.0
	
	match movement_state:
		MovementState.WANDERING:
			return wandering_acceleration_curve.sample(animation_progress)
		MovementState.FOLLOWING:
			return following_acceleration_curve.sample(animation_progress)
		_:
			return wandering_acceleration_curve.sample(animation_progress)

	
# [NEW] This is the core of the avoidance logic and following logic
func _get_avoidance_torque(state: PhysicsDirectBodyState2D) -> float:
	var total_torque = 0.0
	var forward_dir = state.transform.x
	var origin = state.transform.origin
	
	## AVOIDANCE
	# Get the physics space to perform raycasts in
	var space_state = get_world_2d().direct_space_state
	
	# Define the directions for the three whiskers
	var whisker_directions = [
		forward_dir, # Center whisker
		forward_dir.rotated(deg_to_rad(whisker_angle)), # Right whisker
		forward_dir.rotated(deg_to_rad(-whisker_angle))  # Left whisker
	]
	
	var to_exclude_from_avoidance = [self]
	if movement_state == MovementState.FOLLOWING:
		to_exclude_from_avoidance.append(player_to_follow) # Exclude the player from the avoidance if the turtle is following
		
	for direction in whisker_directions:
		# Create the parameters for the raycast query
		var query = PhysicsRayQueryParameters2D.create(origin, origin + direction * whisker_length)
		# Make the ray ignore the turtle itself (and the player if following it)
		query.exclude = to_exclude_from_avoidance
		
		var result = space_state.intersect_ray(query)
		
		if result:
			# A whisker hit a wall. Calculate a steering force away from the wall's normal.
			# The cross product gives us a signed float indicating which way to turn.
			var turn_away_direction = forward_dir.cross(result.normal)
			total_torque += turn_away_direction * avoidance_force
			
	return total_torque

func _on_animation_finished() -> void:
	if animated_sprite.animation == move_animation_name:
		is_moving = false
		animated_sprite.play("idle") # Assumes you have an "idle" animationq

func _on_animation_looped() -> void:
	if animated_sprite.animation == move_animation_name:
		is_moving = true
		match movement_state:
			MovementState.WANDERING: # On each loop, give a small random turn to keep movement interesting
				var random_angle = deg_to_rad(randf_range(-wandering_max_angle_deviation, wandering_max_angle_deviation))
				apply_torque_impulse(random_angle * wandering_turn_force)
			MovementState.FOLLOWING: # On each loop, find the best angle possible towards the player
				var angle_to_player = clamp(
						self.get_angle_to(player_to_follow.global_position),
						-deg_to_rad(following_max_angle_deviation),
						deg_to_rad(following_max_angle_deviation)
					)
				apply_torque_impulse(angle_to_player * following_turn_force)
					
