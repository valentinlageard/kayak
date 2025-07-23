extends Area2D
@export var body_repulsive_force = 50.0
@export var body_velocity_force = 100.0
@export var anchor_pull_strength = 3.0
@export_range(0.0, 1.0) var random_movement = 0.5
@export_range(0.0, 60.0) var damping = 50.0
@export_range(0.0, 1.0) var flower_frequency = 0.4

@onready var sprite = $Waterlilysimple
@onready var perlin_noise = FastNoiseLite.new()
var velocity = Vector2.ZERO         # The lily's current movement speed and direction.
var anchor_position = Vector2.ZERO  # The starting position the lily tries to return to.
@onready var num_frames = 0

func _ready() -> void:
	# Save original position
	anchor_position = global_position
	# Seed the noise
	perlin_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	perlin_noise.seed = randi()
	# Pick random waterlily texture
	var random_texture_picker = randi() % 100
	if random_texture_picker <= flower_frequency * 100 * 0.3:
		sprite.texture = preload("res://waterlilydouble.png")
	elif random_texture_picker <= flower_frequency * 100:
		sprite.texture = preload("res://waterlilysimple.png")
	else:
		sprite.texture = preload("res://waterlilynoflower.png")
	# random rotation
	sprite.rotate(randf() * 2 * PI)
	
	
#VERSION 1
func _physics_process(delta):
	num_frames+=1
	var current_force = Vector2.ZERO;
	# add noise
	var noise_x = perlin_noise.get_noise_2d(Time.get_ticks_msec()/0.02, 0) * random_movement * 10
	var noise_y = perlin_noise.get_noise_2d(0, Time.get_ticks_msec()/0.02) * random_movement * 10
	
	# add body (player, npcs) repulsion
	var colliding_bodies = get_overlapping_bodies()
	for body in colliding_bodies:
		if body.is_in_group("player") or body.is_in_group("npc"):
			var body_velocity = 0;
			# Get body velocity depending on type
			if body is CharacterBody2D:
				body_velocity = body.velocity.length()
			elif body is RigidBody2D:
				body_velocity = body.linear_velocity.length()
			var vector_from_body = global_position - body.global_position
			var body_velocity_coeff = 2 * (1 / (1 + exp(- 0.01 * body_velocity)) - 0.5) # logistic with coeffs to get it between 0 and 1
			# The final force is a combination of 1/log(distance), the parameter body_repulsive_force, and the body_velocity_coefficient computed above
			var body_force_vector = body_repulsive_force * ( min(1 / log(vector_from_body.length()+1), 5.0) + body_velocity_force * max(body_velocity_coeff-0.2, 0) * 1 / (vector_from_body.length_squared()+0.01) )# + max(body_velocity_coeff-0.5, 0) * min(1 / (vector_from_body.length()+0.1), 5.0))
			print(1000 * max(body_velocity_coeff-0.2, 0) * 1 / (vector_from_body.length_squared()+0.01) )
			current_force += vector_from_body.normalized() * body_force_vector
			
	# add anchor attraction
	var vector_to_anchor = (anchor_position - global_position)
	var distance_from_anchor = vector_to_anchor.length()
	if distance_from_anchor > 1.0:
		current_force += vector_to_anchor.normalized() * vector_to_anchor.length() * anchor_pull_strength

	current_force = current_force.lerp(Vector2.ZERO, damping * delta)
	current_force += Vector2(noise_x, noise_y)

	global_position += current_force * delta
