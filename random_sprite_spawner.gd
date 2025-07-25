@tool
extends Polygon2D

@export var node_scenes: Array[PackedScene]

var list_of_primes = [
		2, 3, 5, 7, 11, 13, 17, 19, 23, 29,31, 37, 41, 43, 47, 53, 59, 61, 67, 71,73, 79, 83, 89, 97, 101,
		103, 107, 109, 113,127, 131, 137, 139, 149, 151, 157, 163, 167, 173,179, 181, 191, 193, 197, 199,
		211, 223, 227, 229,233, 239, 241, 251, 257, 263, 269, 271, 277, 281,283, 293, 307, 311, 313, 317,
		331, 337, 347, 349,353, 359, 367, 373, 379, 383, 389, 397, 401, 409,419, 421, 431, 433, 439, 443,
		449, 457, 461, 463,467, 479, 487, 491, 499, 503, 509, 521, 523, 541,547, 557, 563, 569, 571, 577,
	]

func _halton_sequence(p: float, n: int, start: int = 1) -> Array:
	var samples = []
	var current_index = 1
	var multiple_counter = 1
	var p_power = p ** (start + 1)
	var start_loop = p ** start
	var end_loop = n + start_loop
	for i in range(start_loop, end_loop):
		samples.append(current_index / p_power)
		current_index += 1
		multiple_counter += 1
		if (multiple_counter == p):
			if i >= p - 1 && i == current_index - 1:
				multiple_counter = 1
				current_index = 1
				p_power *= p
				continue
			multiple_counter = 1
			current_index += 1
	return samples

func _get_halton_distribution_2D(n: int, min: float = 0, max: float = 1):
	var p1 = list_of_primes.pick_random()
	var p2 = list_of_primes.pick_random()
	while p1 == p2:
		p2 = list_of_primes.pick_random()
	
	var samples = []
	var halton_p1 = _halton_sequence(2, n, 0)
	print(halton_p1)
	var halton_p2 = _halton_sequence(3, n, 0)
	print(halton_p2)
	for i in range(n):
		samples.append(
			Vector2(
				(halton_p1[i]) * (max - min) + min,
				(halton_p2[i]) * (max - min) + min
				))
	
	return samples



@export var sprites_count: int = 50:
	set(value):
		sprites_count = max(0, value)
		_update_tool_preview()

@export var editor_preview_count: int = 50:
	set(value):
		editor_preview_count = max(0, value)
		_update_tool_preview()
		
# --- PLACEMENT CONTROLS ---
@export var grid_step: int = 50:
	set(value):
		grid_step = max(value, 1) # Prevent division by zero
		_update_tool_preview()

@export var min_distance: float = 4.0:
	set(value):
		min_distance = value
		_update_tool_preview()

@export var noise_pattern: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_PERLIN:
	set(value):
		noise_pattern = value
		_update_tool_preview()

@export_range(0.001, 0.1) var noise_frequency: float = 0.04:
	set(value):
		noise_frequency = value
		_update_tool_preview()

@export_range(1, 10) var noise_octaves: int = 2:
	set(value):
		noise_octaves = value
		_update_tool_preview()

@export_range(0.0, 1.0) var noise_threshold: float = 0.5:
	set(value):
		noise_threshold = value
		_update_tool_preview()

var noise_generator: FastNoiseLite
var MAX_ITERATIONS = 10
var number_sprites_to_find = 0

func _ready():
	noise_generator = FastNoiseLite.new()
	if Engine.is_editor_hint():
		number_sprites_to_find = editor_preview_count
		_update_tool_preview()
	else:
		number_sprites_to_find = sprites_count
		self.color.a = 0.0
		_spawn_nodes()

func _update_tool_preview():
	if not Engine.is_editor_hint():
		return

	_configure_noise()
	texture = ImageTexture.create_from_image(noise_generator.get_image(1024, 1024))
	_spawn_nodes()

func _configure_noise():
	if noise_generator == null:
		noise_generator = FastNoiseLite.new()
		
	noise_generator.noise_type = noise_pattern
	noise_generator.frequency = noise_frequency
	noise_generator.fractal_octaves = noise_octaves


# Option to smooth texture borders, calculated from the distance to the edges of the polygon

# Use Halton sequence to get evenly spaced points

# IDEA 1: generate the good number N of points, use attraction force from close points with high noise value

# IDEA 2: use rejection sampling, iterate until we have enough points

# IDEA 3: generate the good number N of points, then sample k times around the points and this gives a probability of going to the other points (Markov chain). Iterate m times
# Grid step




func _spawn_nodes():
	print("spawn checks")
	for child in get_children():
		child.queue_free()

	if node_scenes.is_empty() or self.polygon.size() < 3:
		return
	print("calculating polygon bounds")

	var points = self.polygon
	var bounds = Rect2(points[0], Vector2.ZERO)
	
	print(bounds)
	print(bounds.position)
	for p in points:
		bounds = bounds.expand(p)

	var valid_candidates = []
	var valid_candidates_number = 0
	var number_iterations = 0
	print("calculating halton points")

	var halton_points = _get_halton_distribution_2D(number_sprites_to_find, 0, 1)
	print(halton_points)

	## PASS 1: GATHER ALL POSSIBLE SPAWN POINTS
	#while number_iterations < MAX_ITERATIONS && valid_candidates_number < number_sprites_to_find: 
		#number_iterations += 1
		#for y in range(bounds.position.y, bounds.end.y):
			#for x in range(bounds.position.x, bounds.end.x):
				#var jitter = Vector2(randf_range(-1 / 2.0, 1 / 2.0), randf_range(-1 / 2.0, 1 / 2.0))
				#var potential_point = Vector2(x, y) + jitter
#
				#if not Geometry2D.is_point_in_polygon(potential_point, points):
					#continue
#
				#var noise_value = (noise_generator.get_noise_2d(potential_point.x, potential_point.y) + 1.0) / 2.0
				#var draw_value = randf()
				#if draw_value > noise_value:
					#continue
				#
				#var is_valid_distance = true
				##for existing_point in valid_candidates:
					##if potential_point.distance_to(existing_point) < min_distance:
						##is_valid_distance = false
						##break
				#
				#if is_valid_distance:
					#valid_candidates.append(potential_point)
					#valid_candidates_number += 1
#
	## PASS 2: SELECT AND SPAWN FROM THE CANDIDATE LIST
	#valid_candidates.shuffle()
#
	#var num_to_spawn = min(number_sprites_to_find, valid_candidates.size())

	for i in range(number_sprites_to_find):
		var spawn_point = halton_points[i]
		#print("spawning points")
		bounds

		var scene_to_instance = node_scenes.pick_random()
		if not scene_to_instance: continue
		
		var new_instance = scene_to_instance.instantiate()
		if new_instance is Node2D:
			new_instance.position = spawn_point
		
		if Engine.is_editor_hint():
			new_instance.owner = self

		add_child(new_instance)
