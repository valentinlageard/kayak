@tool
extends Polygon2D

@export var node_scenes: Array[PackedScene]

var list_of_primes = [
		2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71,73, 79, 83, 89, 97, 101,
		103, 107, 109, 113,127, 131, 137, 139, 149, 151, 157, 163, 167, 173,179, 181, 191, 193, 197, 199,
		211, 223, 227, 229,233, 239, 241, 251, 257, 263, 269, 271, 277, 281,283, 293, 307, 311, 313, 317,
		331, 337, 347, 349,353, 359, 367, 373, 379, 383, 389, 397, 401, 409,419, 421, 431, 433, 439, 443,
		449, 457, 461, 463,467, 479, 487, 491, 499, 503, 509, 521, 523, 541,547, 557, 563, 569, 571, 577,
	]

func _halton_number(b: int, index: int) -> float:
	var result = 0.0
	var f = 1.0
	while index > 0:
		f = f / float(b);
		result += f * float(index % b)
		index = index / b
	return result

func _get_halton_distribution_2D(n: int, min: float = 0, max: float = 1):
	var p1 = list_of_primes.pick_random()
	var p2 = list_of_primes.pick_random()
	while p1 == p2:
		p2 = list_of_primes.pick_random()
	var samples = []
	var start = 1
	for i in range(start, n + start):
		samples.append(Vector2(_halton_number(2, i) * (max - min) + min, _halton_number(3, i) * (max - min) + min))
	return samples


@export var sprites_count: int = 50

#
#@export var editor_preview_count: int = 50:
	#set(value):
		#editor_preview_count = max(0, value)
		#_update_tool_preview()
		#
## --- PLACEMENT CONTROLS ---
#@export var grid_step: int = 50:
	#set(value):
		#grid_step = max(value, 1) # Prevent division by zero
		#_update_tool_preview()
##
@export var min_distance: float = 4.0
	#set(value):
		#min_distance = value
		#_update_tool_preview()

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

@export_range(0.0, 1.0) var noise_threshold: float = 0.5
@export var apply_force: bool = true

var noise_generator: FastNoiseLite
var MAX_ITERATIONS = 10
var number_sprites_to_find = 0

func _ready():
	noise_generator = FastNoiseLite.new()
	if Engine.is_editor_hint():
		_update_tool_preview()
	else:
		number_sprites_to_find = sprites_count
		_update_tool_preview()
		self.color.a = 0.0
		_spawn_nodes()

func _update_tool_preview():
	if not Engine.is_editor_hint():
		return
	_configure_noise()
	texture = ImageTexture.create_from_image(noise_generator.get_image(1024, 1024))
	#_spawn_nodes()

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
	for child in get_children():
		child.queue_free()

	if node_scenes.is_empty() or self.polygon.size() < 3:
		return

	var bounds = Rect2(self.polygon[0], Vector2.ZERO)
	for p in self.polygon:
		bounds = bounds.expand(p)

	var candidates = _get_halton_distribution_2D(number_sprites_to_find * 5, min(bounds.position.x, bounds.position.y), max(bounds.end.x, bounds.end.y))
	candidates.shuffle()
	var candidates_length = len(candidates)
	var valid_candidates_number = 0
	var valid_candidates = []
	var noise_buffer = []
	## PASS 1: GATHER ALL POSSIBLE SPAWN POINTS
	for ITER in range(MAX_ITERATIONS):
		print(ITER)
		print(len(valid_candidates))
		for i in range(candidates_length):
			if valid_candidates_number == number_sprites_to_find:
				break
			var potential_point = candidates[i]
			if potential_point == null:
				continue
			if not Geometry2D.is_point_in_polygon(potential_point, self.polygon):
				candidates[i] = null
				continue
			var noise_value = ((noise_generator.get_noise_2d(potential_point.x, potential_point.y) + 1.0) / 2.0)
			noise_buffer.append(noise_value)
			if noise_value < noise_threshold or noise_value < randf() :
				continue
			valid_candidates.append(potential_point)
			candidates[i] = null
			valid_candidates_number += 1
	var new_positions = []
	## PASS 2: apply repulsive force to sprites	
	if apply_force:
		print('apply force')
		var displacement = []
		for i in range(valid_candidates_number):
			displacement.append(Vector2.ZERO)
			new_positions.append(Vector2.ZERO)
		var k = sqrt((bounds.end.x - bounds.position.x) * (bounds.end.y - bounds.position.y)) /8
		var t = 1.0
		for ITER in range(50):
			print( ITER )
			for i in range(valid_candidates_number):
				var candidate_i = valid_candidates[i]
				var noise_value_i = ((noise_generator.get_noise_2d(candidate_i.x, candidate_i.y) + 1.0) / 2.0)
				for j in range(i+1, valid_candidates_number):
					var candidate_j = valid_candidates[j]
					var delta = candidate_i - candidate_j
					var distance = delta.length() + 0.01
					var noise_value_j = ((noise_generator.get_noise_2d(candidate_i.x, candidate_i.y) + 1.0) / 2.0)
					var repulsive_force = k ** 2 / distance * 10
					
					displacement[i] += delta * repulsive_force
					displacement[j] -= delta * repulsive_force
				valid_candidates[i] += displacement[i]
				new_positions[i] = valid_candidates[i]

			t = max(0, t-1/50)
	else:
		new_positions = valid_candidates

	var num_to_spawn = min(number_sprites_to_find, valid_candidates.size())
	print('number to find: ', number_sprites_to_find)
	print('number found: ', len(valid_candidates))
	if not Engine.is_editor_hint():
		for i in range(num_to_spawn):
			var scene_to_instance = node_scenes.pick_random()
			if not scene_to_instance: continue
			
			var new_instance = scene_to_instance.instantiate()
			if new_instance is Node2D:
				new_instance.position = new_positions[i]
			add_child(new_instance)
