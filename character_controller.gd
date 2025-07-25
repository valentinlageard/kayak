extends CharacterBody2D

@onready var animated_sprite: AnimationPlayer = $AnimationPlayer
@onready var paddle_sound_player: AudioStreamPlayer2D = $PaddleSoundPlayer
@onready var particles_front_left: CPUParticles2D = $ParticlesFrontLeft
@onready var particles_front_right: CPUParticles2D = $ParticlesFrontRight
@onready var particles_back_left: CPUParticles2D = $ParticlesBackLeft
@onready var particles_back_right: CPUParticles2D = $ParticlesBackRight
@onready var particles_middle_left: CPUParticles2D = $ParticlesMiddleLeft
@onready var particles_middle_right: CPUParticles2D = $ParticlesMiddleRight

@export_group("Player Control")
@export var acceleration: float = 150.0
@export var turn_speed: float = 15.0
@export var min_break_strength: float = 20.0
@export var break_friction_strength: float = 0.01
@export var break_turn_power: float = 0.04
@export var max_velocity: float = 800.0
@export var paddle_duration: float = 0.7
@export var paddle_acceleration_curve: Curve
@export var friction: float = 0.015
@export var bounciness: float = 0.4
@export var align_velocity_to_rotation_strength: float = 0.08
@export var align_rotation_to_velocity_strength: float = 0.03
@export var min_particles_velocity_threshold: float = 5
@export var max_particles_velocity_threshold: float = 40

@export_group("Flow Field")
@export var field_influence_strength: float = 100.0
@export var flow_torque_strength: float = 2.0


enum State { IDLE, PADDLE_RIGHT, PADDLE_LEFT, BREAK_LEFT, BREAK_RIGHT }
var current_state: State = State.IDLE
var paddle_timer: float = 0.0

func _ready() -> void:
	_transition_to_idle()

func _physics_process(delta: float) -> void:
	# --- 1. HANDLE INPUT & STATE TRANSITIONS ---
	_handle_input()

	# --- 2. GET FLOW FIELD FORCE ---
	var flow_force = FlowfieldManager.get_force_at_position(global_position)

	# --- 3. EXECUTE CURRENT STATE LOGIC ---
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.PADDLE_RIGHT:
			_paddle_right_state(delta)
		State.PADDLE_LEFT:
			_paddle_left_state(delta)
		State.BREAK_LEFT:
			_break_state(delta, -1.0) # Pass direction
		State.BREAK_RIGHT:
			_break_state(delta, 1.0)  # Pass direction

	# --- 4. HANDLE PASSIVE ROTATION ---
	var forward_direction = Vector2.UP.rotated(rotation)
	if flow_force.length_squared() > 0.01:
		var flow_direction = flow_force.normalized()
		var torque = forward_direction.cross(flow_direction)
		rotation += torque * flow_torque_strength * delta
	if velocity.length_squared() > 10.0:
		var target_angle = velocity.angle() + PI / 2
		rotation = lerp_angle(rotation, target_angle, align_rotation_to_velocity_strength)

	# --- 5. HANDLE VELOCITY & FORCES ---
	velocity = velocity.lerp(forward_direction * velocity.length(), align_velocity_to_rotation_strength)
	velocity += flow_force * field_influence_strength * delta
	if current_state != State.BREAK_LEFT and current_state != State.BREAK_RIGHT:
		velocity = velocity.lerp(Vector2.ZERO, friction)
	velocity = velocity.limit_length(max_velocity)
	paddle_sound_player.volume_db = paddle_sound_player.volume_db_ref + velocity.length()/100

	# --- 6. MOVE AND HANDLE COLLISIONS ---
	move_and_slide()
	if get_slide_collision_count() > 0:
		var collision = get_last_slide_collision()
		var normal = collision.get_normal()
		velocity = velocity.bounce(normal)
		velocity *= bounciness
	
	# Manage particles
	var amount = remap(velocity.length(), min_particles_velocity_threshold, max_particles_velocity_threshold, 0, 1)
	particles_back_right.color_initial_ramp.set_color(1, Color(Color.WHITE, amount))
	particles_back_left.color_initial_ramp.set_color(1, Color(Color.WHITE, amount))
	particles_front_right.color_initial_ramp.set_color(1, Color(Color.WHITE, amount))
	particles_front_left.color_initial_ramp.set_color(1, Color(Color.WHITE, amount))
	particles_middle_right.color_initial_ramp.set_color(1, Color(Color.WHITE, amount))
	particles_middle_left.color_initial_ramp.set_color(1, Color(Color.WHITE, amount))

	MusicPlayer.update_player_state(self.velocity, self.global_position)

# --- INPUT HANDLING ---
func _handle_input() -> void:
	# Check for actions that should interrupt the current state
	if Input.is_action_just_pressed("paddle_right"):
		_transition_to_paddle_right()
	elif Input.is_action_just_pressed("paddle_left"):
		_transition_to_paddle_left()
	elif Input.is_action_just_pressed("break_left"):
		_transition_to_break_left()
	elif Input.is_action_just_pressed("break_right"):
		_transition_to_break_right()


# --- STATE TRANSITION METHODS ---
func _transition_to_idle() -> void:
	current_state = State.IDLE
	animated_sprite.play("idle")

func _transition_to_paddle_right() -> void:
	current_state = State.PADDLE_RIGHT
	paddle_timer = 0.0
	animated_sprite.play("paddle_right")

func _transition_to_paddle_left() -> void:
	current_state = State.PADDLE_LEFT
	paddle_timer = 0.0
	animated_sprite.play("paddle_left")

func _transition_to_break_left() -> void:
	current_state = State.BREAK_LEFT
	animated_sprite.play('break_left')

func _transition_to_break_right() -> void:
	current_state = State.BREAK_RIGHT
	animated_sprite.play('break_right')


# --- STATE IMPLEMENTATIONS ---
func _idle_state(_delta: float) -> void:
	# Idle state has no active logic, it waits for input to transition.
	pass

func _paddle_right_state(delta: float) -> void:
	if Input.is_action_just_released("paddle_right") or paddle_timer >= paddle_duration:
		_transition_to_idle()
		return
		
	paddle_timer += delta
	var paddle_strength = paddle_acceleration_curve.sample(paddle_timer / paddle_duration)
	var forward_direction = Vector2.UP.rotated(rotation)
	velocity += forward_direction * acceleration * paddle_strength * delta
	rotation -= turn_speed * 0.1 * paddle_strength * delta

func _paddle_left_state(delta: float) -> void:
	if Input.is_action_just_released("paddle_left") or paddle_timer >= paddle_duration:
		_transition_to_idle()
		return
		
	paddle_timer += delta
	var paddle_strength = paddle_acceleration_curve.sample(paddle_timer / paddle_duration)
	var forward_direction = Vector2.UP.rotated(rotation)
	velocity += forward_direction * acceleration * paddle_strength * delta
	rotation += turn_speed * 0.1 * paddle_strength * delta

func _break_state(delta: float, direction: float) -> void:
	var action_name = "break_right" if direction > 0 else "break_left"
	if Input.is_action_just_released(action_name):
		_transition_to_idle()
		return
	
	velocity = velocity.lerp(Vector2.ZERO, break_friction_strength)
	var turn_amount = direction * break_turn_power * (velocity.length() + min_break_strength) * delta
	rotation += turn_amount
