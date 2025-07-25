@tool
extends Polygon2D

@export var node_scenes: Array[PackedScene]
@export var sprites_count: int = 50
@export var random_seed: bool = true
@export var noise_seed: int = 1337:
	set(value):
		noise_seed = value; _update_tool_preview()

@export_group("Rendering")
@export_range(0.0, 1.0) var noise_threshold: float = 0.5
@export_range(0.0, 1.0) var threshold_strength: float = 0.5
@export_range(0.0, 1.0) var edge_smoothing: float = 0.5
@export var prime_number_1: int = 2
@export var prime_number_2: int = 3

# --- NOISE CONTROLS ---
@export_group("Noise Parameters")
@export var noise_pattern: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_PERLIN:
	set(value):
		noise_pattern = value; _update_tool_preview()
@export_range(0.001, 0.5, 0.001) var noise_frequency: float = 0.04:
	set(value):
		noise_frequency = value; _update_tool_preview()
@export_range(1, 10) var noise_octaves: int = 2:
	set(value):
		noise_octaves = value; _update_tool_preview()

# --- FRACTAL CONTROLS ---
@export_group("Fractal (for Perlin, Simplex, etc.)")
@export var fractal_type: FastNoiseLite.FractalType = FastNoiseLite.FRACTAL_FBM:
	set(value):
		fractal_type = value; _update_tool_preview()

@export_range(1, 10) var fractal_octaves: int = 3:
	set(value):
		fractal_octaves = value; _update_tool_preview()

@export_range(0.1, 5.0) var fractal_lacunarity: float = 2.0:
	set(value):
		fractal_lacunarity = value; _update_tool_preview()

@export_range(0.1, 2.0) var fractal_gain: float = 0.5:
	set(value):
		fractal_gain = value; _update_tool_preview()

@export_range(0.0, 2.0) var fractal_weighted_strength: float = 0.0:
	set(value):
		fractal_weighted_strength = value; _update_tool_preview()

# --- CELLULAR NOISE CONTROLS ---
@export_group("Cellular (for Cellular noise)")
@export var cellular_distance_function: FastNoiseLite.CellularDistanceFunction = FastNoiseLite.CellularDistanceFunction.DISTANCE_EUCLIDEAN:
	set(value):
		cellular_distance_function = value; _update_tool_preview()

@export var cellular_return_type: FastNoiseLite.CellularReturnType = FastNoiseLite.CellularReturnType.RETURN_CELL_VALUE:
	set(value):
		cellular_return_type = value; _update_tool_preview()

@export_range(0.0, 2.0) var cellular_jitter: float = 1.0:
	set(value):
		cellular_jitter = value; _update_tool_preview()

# --- DOMAIN WARP CONTROLS ---
@export_group("Domain Warp")
@export var domain_warp_enabled: bool = false:
	set(value):
		domain_warp_enabled = value; _update_tool_preview()

@export var domain_warp_type: FastNoiseLite.DomainWarpType = FastNoiseLite.DOMAIN_WARP_SIMPLEX:
	set(value):
		domain_warp_type = value; _update_tool_preview()

@export_range(0.1, 200.0) var domain_warp_amplitude: float = 30.0:
	set(value):
		domain_warp_amplitude = value; _update_tool_preview()

@export_range(0.001, 0.5, 0.001) var domain_warp_frequency: float = 0.005:
	set(value):
		domain_warp_frequency = value; _update_tool_preview()


var noise_generator: FastNoiseLite


func _ready():
	noise_generator = FastNoiseLite.new()
	if random_seed:
		noise_generator.seed = randi()
	if Engine.is_editor_hint():
		_update_tool_preview()
	else:
		self.color.a = 0.0
		_spawn_nodes()

func _update_tool_preview():
	if not Engine.is_editor_hint(): return
	_configure_noise()

func _resize_texture():
	var bounds = Rect2(self.polygon[0], Vector2.ZERO)
	for point in self.polygon:
		bounds = bounds.expand(point)
	texture_offset = Vector2(-bounds.position.x, -bounds.position.y)
	texture = ImageTexture.create_from_image(noise_generator.get_image(bounds.size.x, bounds.size.y))

func _on_draw() -> void:
	await get_tree().create_timer(0.2).timeout
	_resize_texture()

func _configure_noise():
	if noise_generator == null: noise_generator = FastNoiseLite.new()
	noise_generator.noise_type = noise_pattern
	noise_generator.frequency = noise_frequency
	noise_generator.fractal_octaves = noise_octaves

	# Noise Shape
	noise_generator.noise_type = noise_pattern
	noise_generator.seed = noise_seed
	noise_generator.frequency = noise_frequency

	# Fractal
	noise_generator.fractal_type = fractal_type
	noise_generator.fractal_octaves = fractal_octaves
	noise_generator.fractal_lacunarity = fractal_lacunarity
	noise_generator.fractal_gain = fractal_gain
	noise_generator.fractal_weighted_strength = fractal_weighted_strength

	# Cellular
	noise_generator.cellular_distance_function = cellular_distance_function
	noise_generator.cellular_return_type = cellular_return_type
	noise_generator.cellular_jitter = cellular_jitter
	
	# Domain Warp
	noise_generator.domain_warp_enabled = domain_warp_enabled
	noise_generator.domain_warp_type = domain_warp_type
	noise_generator.domain_warp_amplitude = domain_warp_amplitude
	noise_generator.domain_warp_frequency = domain_warp_frequency
	noise_generator.seed = randi()
	_resize_texture()
	
# List of prime numbers for the halton distribution
# 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71,73, 79, 83, 89, 97, 101,
# 103, 107, 109, 113,127, 131, 137, 139, 149, 151, 157, 163, 167, 173,179, 181, 191, 193, 197, 199,
# 211, 223, 227, 229,233, 239, 241, 251, 257, 263, 269, 271, 277, 281,283, 293, 307, 311, 313, 317,
# 331, 337, 347, 349,353, 359, 367, 373, 379, 383, 389, 397, 401, 409,419, 421, 431, 433, 439, 443,
# 449, 457, 461, 463,467, 479, 487, 491, 499, 503, 509, 521, 523, 541,547, 557, 563, 569, 571, 577

func _get_halton_distribution_2D(n: int, rect: Rect2) -> Array:
	var samples = []
	for i in range(1, n + 1):
		var x = _halton_number(prime_number_1, i) * rect.size.x + rect.position.x
		var y = _halton_number(prime_number_2, i) * rect.size.y + rect.position.y
		samples.append(Vector2(x, y))
	return samples

func _halton_number(b: int, index: int) -> float:
	var result = 0.0
	var f = 1.0
	while index > 0:
		f /= float(b)
		result += f * float(index % b)
		index = int(index / b)
	return result

func _spawn_nodes():
	for child in get_children():
		child.queue_free()

	if node_scenes.is_empty() or self.polygon.size() < 3: return

	var points = self.polygon
	var bounds = Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	var candidates = _get_halton_distribution_2D(sprites_count * 5, bounds)
	var valid_candidates = []
	for point in candidates:
		if valid_candidates.size() >= sprites_count: break
		if not Geometry2D.is_point_in_polygon(point, points): continue
		
		var noise_value = (noise_generator.get_noise_2d(point.x, point.y) + 1.0) / 2.0
		if threshold_strength * noise_value + (1- threshold_strength) * randf() < noise_threshold: continue
		
		var dist_left = point.x - bounds.position.x
		var dist_right = bounds.end.x - point.x
		var dist_top = point.y - bounds.position.y
		var dist_bottom = bounds.end.y - point.y
		print(bounds.end, bounds.position)
		if randf() * bounds.size.x * edge_smoothing > dist_left: continue
		if randf() * bounds.size.x * edge_smoothing > dist_right: continue
		if randf() * bounds.size.y * edge_smoothing > dist_top: continue
		if randf() * bounds.size.y * edge_smoothing > dist_bottom: continue
		
		valid_candidates.append(point)

	var final_positions = valid_candidates

	print('Targeted number of spawns: ', sprites_count)
	print('Realised spawns: ', len(final_positions))

	for pos in final_positions:
		var scene_to_instance = node_scenes.pick_random()
		if not scene_to_instance: continue
		var new_instance = scene_to_instance.instantiate()
		if new_instance is Node2D:
			new_instance.position = pos
		add_child(new_instance)
