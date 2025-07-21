extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export_group("Player Control")
@export var acceleration: float = 180.0
@export var turn_speed: float = 15.0
@export var min_break_strength: float = 0.1
@export var break_friction_strength: float = 0.08 
@export var break_turn_power: float = 0.005
@export var max_velocity: float = 800.0
@export var paddle_duration: float = 0.5
@export var paddle_acceleration_curve: float = 0.5
@export var friction: float = 0.05
@export var bounciness: float = 0.75
@export var align_velocity_to_rotation_strength: float = 0.05
@export var align_rotation_to_velocity_strength: float = 0.05

@export_group("Flow Field")
@export var field_influence_strength: float = 100.0
@export var flow_torque_strength: float = 2.0

enum State { IDLE, PADDLE_RIGHT, PADDLE_LEFT, BREAK_LEFT, BREAK_RIGHT }
var current_state: State = State.IDLE
var paddle_timer: float = 0.0

func _ready() -> void:
	animated_sprite.play("idle")

func _physics_process(delta: float) -> void:
	# --- 1. GET FLOW FIELD FORCE ---
	# We get this early as it's needed by multiple systems.
	var flow_force = FlowfieldManager.get_force_at_position(global_position)

	# --- 2. STATE MACHINE ---
	# Pass the flow_force to the state functions that need it.
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.PADDLE_RIGHT:
			_paddle_right_state(delta)
		State.PADDLE_LEFT:
			_paddle_left_state(delta)
		State.BREAK_LEFT:
			_break_state(delta, flow_force, -1.0) # Pass direction
		State.BREAK_RIGHT:
			_break_state(delta, flow_force, 1.0) # Pass direction

	# --- 3. HANDLE PASSIVE ROTATION ---
	var forward_direction = Vector2.UP.rotated(rotation)
	# A. Apply torque from the flow field
	if flow_force.length_squared() > 0.01:
		var flow_direction = flow_force.normalized()
		var torque = forward_direction.cross(flow_direction)
		rotation += torque * flow_torque_strength * delta
	# B. Align rotation to velocity
	if velocity.length_squared() > 10.0:
		var target_angle = velocity.angle() + PI / 2
		rotation = lerp_angle(rotation, target_angle, align_rotation_to_velocity_strength)

	# --- 4. HANDLE VELOCITY & FORCES ---
	# The state machine now handles most velocity changes. This section is for passive forces.
	# A. Align velocity to the kayak's forward direction
	velocity = velocity.lerp(forward_direction * velocity.length(), align_velocity_to_rotation_strength)
	# B. Add base force from the flow field
	velocity += flow_force * field_influence_strength * delta
	# C. Apply base friction
	if current_state != State.BREAK_LEFT and current_state != State.BREAK_RIGHT:
		velocity = velocity.lerp(Vector2.ZERO, friction)
	# D. Clamp max speed
	velocity = velocity.limit_length(max_velocity)

	# --- 5. MOVE AND HANDLE COLLISIONS ---
	move_and_slide()
	if get_slide_collision_count() > 0:
		var collision = get_last_slide_collision()
		var normal = collision.get_normal()
		velocity = velocity.bounce(normal)
		velocity = velocity * bounciness

	MusicPlayer.update_player_state(self.velocity, self.global_position)
# --- STATE IMPLEMENTATIONS ---

func _idle_state(_delta: float) -> void:
	if Input.is_action_just_pressed("paddle_right"):
		current_state = State.PADDLE_RIGHT
		paddle_timer = 0.0
		animated_sprite.play("paddle_right")
	elif Input.is_action_just_pressed("paddle_left"):
		current_state = State.PADDLE_LEFT
		paddle_timer = 0.0
		animated_sprite.play("paddle_left")
	elif Input.is_action_pressed("break_left"):
		current_state = State.BREAK_LEFT
		animated_sprite.play('break_left')
	elif Input.is_action_pressed("break_right"):
		current_state = State.BREAK_RIGHT
		animated_sprite.play('break_right')

# PADDLE STATES (Unchanged)
func _paddle_right_state(delta: float) -> void:
	if Input.is_action_just_released("paddle_right") or paddle_timer >= paddle_duration:
		animated_sprite.play("idle")
		current_state = State.IDLE;
		return
	paddle_timer += delta
	var paddle_strength = ease(paddle_timer / paddle_duration, paddle_acceleration_curve)
	var forward_direction = Vector2.UP.rotated(rotation)
	velocity += forward_direction * acceleration * paddle_strength * delta
	rotation -= turn_speed * 0.1 * paddle_strength * delta

func _paddle_left_state(delta: float) -> void:
	if Input.is_action_just_released("paddle_left") or paddle_timer >= paddle_duration:
		animated_sprite.play("idle")
		current_state = State.IDLE;
		return
	paddle_timer += delta
	var paddle_strength = ease(paddle_timer / paddle_duration, paddle_acceleration_curve)
	var forward_direction = Vector2.UP.rotated(rotation)
	velocity += forward_direction * acceleration * paddle_strength * delta
	rotation += turn_speed * 0.1 * paddle_strength * delta

func _break_state(delta: float, flow_force: Vector2, direction: float) -> void:
	var action_name = "break_right" if direction > 0 else "break_left"
	if Input.is_action_just_released(action_name):
		current_state = State.IDLE
		return
	
	velocity = velocity.lerp(Vector2.ZERO, break_friction_strength)

	# The amount of turn is proportional to our current speed.
	# A faster kayak turns more sharply when the rudder is applied.
	var turn_amount = direction * break_turn_power * (velocity.length() + min_break_strength) * delta
	rotation += turn_amount
