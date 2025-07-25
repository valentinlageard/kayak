@tool
extends Polygon2D

## An array to hold the different scenes (e.g., waterlilies, rocks) that can be randomly spawned.
@export var node_scenes: Array[PackedScene]
## The target number of sprites to generate within the polygon.
@export var sprites_count: int = 50
## The fundamental algorithm used to generate the noise (e.g., smooth Perlin, blocky Cellular).
@export var noise_pattern: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_PERLIN:
	set(value):
		noise_pattern = value; _update_tool_preview()
## The "zoom level" of the noise. Higher values create smaller, more frequent features.
@export_range(0.001, 0.5, 0.001) var noise_frequency: float = 0.04:
	set(value):
		noise_frequency = value; _update_tool_preview()
## If true, prints debug statistics on the generation into the output console
@export var print_debug_stats: bool = true

@export_group("Rendering")
## If false, the noise won't be useed in the generation process (pure random Halton generation)
@export var use_noise: bool = true
## The base cutoff for the noise. A point with a noise value below this is less likely to spawn a sprite.
@export_range(0.0, 1.0) var noise_threshold: float = 0.5
## Blends between pure random chance and pure noise-based placement. 1.0 = purely noise-based, 0.0 = purely random.
@export_range(0.0, 1.0) var threshold_strength: float = 0.5
## Controls how strongly sprites are pushed away from the polygon edges. Higher values create a larger empty margin.
@export_range(0.0, 1.0) var edge_smoothing: float = 0.5
## The prime number base for the X-axis of the Halton sequence, affecting the point distribution pattern.
@export var prime_number_1: int = 2
## The prime number base for the Y-axis of the Halton sequence. Should be different from prime_number_1.
@export var prime_number_2: int = 3

# --- NOISE CONTROLS ---
@export_group("Noise Parameters")
## If true, a new random seed will be used every time the game starts.
@export var random_seed: bool = true
## The specific seed for the noise generator. Changing this will produce a different, but repeatable, noise pattern.
@export var noise_seed: int = 1337:
	set(value):
		noise_seed = value; _update_tool_preview()

## The number of noise layers to combine for a more detailed pattern (used by fractal types).
@export_range(1, 10) var noise_octaves: int = 2:
	set(value):
		noise_octaves = value; _update_tool_preview()

# --- FRACTAL CONTROLS ---
@export_group("Fractal (for Perlin, Simplex, etc.)")
## The method used to combine the different noise layers (octaves). FBM is standard, Ridged creates sharp crests.
@export var fractal_type: FastNoiseLite.FractalType = FastNoiseLite.FRACTAL_FBM:
	set(value):
		fractal_type = value; _update_tool_preview()

## The number of noise layers (frequencies) to stack on top of each other for more detail.
@export_range(1, 10) var fractal_octaves: int = 3:
	set(value):
		fractal_octaves = value; _update_tool_preview()

## Controls how much detail is added with each successive octave. Higher values mean finer details.
@export_range(0.1, 5.0) var fractal_lacunarity: float = 2.0:
	set(value):
		fractal_lacunarity = value; _update_tool_preview()

## Controls the influence of each successive octave. Lower values make details fainter.
@export_range(0.1, 2.0) var fractal_gain: float = 0.5:
	set(value):
		fractal_gain = value; _update_tool_preview()

## Tilts the balance of influence toward the lower-frequency octaves.
@export_range(0.0, 2.0) var fractal_weighted_strength: float = 0.0:
	set(value):
		fractal_weighted_strength = value; _update_tool_preview()

# --- CELLULAR NOISE CONTROLS ---
@export_group("Cellular (for Cellular noise)")
## The mathematical formula used to calculate the distance between points, affecting the shape of the cells.
@export var cellular_distance_function: FastNoiseLite.CellularDistanceFunction = FastNoiseLite.CellularDistanceFunction.DISTANCE_EUCLIDEAN:
	set(value):
		cellular_distance_function = value; _update_tool_preview()

## Determines what value the noise returns (e.g., a cell's unique ID, or the distance to its edge).
@export var cellular_return_type: FastNoiseLite.CellularReturnType = FastNoiseLite.CellularReturnType.RETURN_CELL_VALUE:
	set(value):
		cellular_return_type = value; _update_tool_preview()

## How much to randomize the position of the cell points. 0.0 creates a perfect grid.
@export_range(0.0, 2.0) var cellular_jitter: float = 1.0:
	set(value):
		cellular_jitter = value; _update_tool_preview()

# --- DOMAIN WARP CONTROLS ---
@export_group("Domain Warp")
## If true, the noise pattern will be distorted by another, separate noise pattern, creating swirling effects.
@export var domain_warp_enabled: bool = false:
	set(value):
		domain_warp_enabled = value; _update_tool_preview()

## The type of noise used for the distortion field.
@export var domain_warp_type: FastNoiseLite.DomainWarpType = FastNoiseLite.DOMAIN_WARP_SIMPLEX:
	set(value):
		domain_warp_type = value; _update_tool_preview()

## How strongly the domain warp distorts the coordinates.
@export_range(0.1, 200.0) var domain_warp_amplitude: float = 30.0:
	set(value):
		domain_warp_amplitude = value; _update_tool_preview()

## The "zoom level" or frequency of the noise used for the distortion field.
@export_range(0.001, 0.5, 0.001) var domain_warp_frequency: float = 0.005:
	set(value):
		domain_warp_frequency = value; _update_tool_preview()


## The instance of the noise generation object.
var noise_generator: FastNoiseLite


## Called once when the node enters the scene tree, both in the editor and in-game.
## This function serves as the main entry point, directing logic based on the context.
func _ready():
	noise_generator = FastNoiseLite.new()
	if random_seed:
		noise_generator.seed = randi()
	if Engine.is_editor_hint():
		## If we are in the Godot editor, only update the visual preview.
		_update_tool_preview()
	else:
		## If the game is running, hide the polygon shape and run the full, final spawning logic.
		self.color.a = 0.0
		_spawn_nodes()

## This function is called by the setters of the exported variables.
## Its only job is to trigger a regeneration of the editor preview when a parameter is changed.
func _update_tool_preview():
	if not Engine.is_editor_hint(): return
	_configure_noise()

## This function calculates the polygon's bounding box and creates the noise preview
## texture to match its size and position.
func _resize_texture():
	var bounds = Rect2(self.polygon[0], Vector2.ZERO)
	for point in self.polygon:
		bounds = bounds.expand(point)
	texture_offset = Vector2(-bounds.position.x, -bounds.position.y)
	texture = ImageTexture.create_from_image(noise_generator.get_image(bounds.size.x, bounds.size.y))

## A custom function, likely intended to be called when the polygon is drawn or updated.
## It waits briefly before resizing the texture to avoid excessive updates.
func _on_draw() -> void:
	await get_tree().create_timer(0.2).timeout
	_resize_texture()

## This is a central helper function that applies all the exported variables
## to the internal `noise_generator` object, configuring its behavior.
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

## Generates a set of 2D points that are evenly (but not rigidly) distributed
## within a given rectangle using the Halton low-discrepancy sequence.
func _get_halton_distribution_2D(n: int, rect: Rect2) -> Array:
	var samples = []
	for i in range(1, n + 1):
		var x = _halton_number(prime_number_1, i) * rect.size.x + rect.position.x
		var y = _halton_number(prime_number_2, i) * rect.size.y + rect.position.y
		samples.append(Vector2(x, y))
	return samples

## A mathematical helper function that calculates a single number in a 1D Halton
## sequence for a given base. This is the core of the Halton distribution.
func _halton_number(b: int, index: int) -> float:
	var result = 0.0
	var f = 1.0
	while index > 0:
		f /= float(b)
		result += f * float(index % b)
		index = int(index / b)
	return result


var debug_stats = {'target': sprites_count, 'realised': 0, 'rejected': {'out_of_bounds': 0, 'noise_filter': 0, 'edge_smoothing': 0, 'min_distance': 0}}
## This is the main function responsible for the procedural generation.
## It is only called once when the game starts.
func _spawn_nodes():
	## Clear any nodes that might have been spawned in a previous editor preview.
	for child in get_children():
		child.queue_free()

	## Guard clauses to prevent errors if the tool is not set up correctly.
	if node_scenes.is_empty() or self.polygon.size() < 3: return

	## Determine the bounding box of the user-drawn polygon.
	var points = self.polygon
	var bounds = Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	
	## Generate a large pool of well-distributed candidate points.
	var candidates = _get_halton_distribution_2D(sprites_count * 5, bounds)
	var valid_candidates = []
	
	## Filter the candidate points based on a series of rejection sampling rules.
	for point in candidates:
		## Stop once we have found enough sprites.
		if valid_candidates.size() >= sprites_count: break
		## Rule 1: Point must be inside the user-drawn polygon shape.
		if not Geometry2D.is_point_in_polygon(point, points): debug_stats.rejected.out_of_bounds += 1; continue
		
		## Rule 2: Point must pass the noise threshold check.
		if use_noise:
			var noise_value = (noise_generator.get_noise_2d(point.x, point.y) + 1.0) / 2.0
			if threshold_strength * noise_value + (1- threshold_strength) * randf() < noise_threshold: debug_stats.rejected.noise_filter += 1; continue
		
		## Rule 3: Point must pass the edge smoothing check, which rejects points closer to the edge.
		var dist_left = point.x - bounds.position.x
		var dist_right = bounds.end.x - point.x
		var dist_top = point.y - bounds.position.y
		var dist_bottom = bounds.end.y - point.y
		if randf() * bounds.size.x * edge_smoothing > dist_left: debug_stats.rejected.edge_smoothing += 1; continue
		if randf() * bounds.size.x * edge_smoothing > dist_right: debug_stats.rejected.edge_smoothing += 1; continue
		if randf() * bounds.size.y * edge_smoothing > dist_top: debug_stats.rejected.edge_smoothing += 1; continue
		if randf() * bounds.size.y * edge_smoothing > dist_bottom: debug_stats.rejected.edge_smoothing += 1; continue
		
		## If all rules are passed, add the point to the final list.
		valid_candidates.append(point)

	var final_positions = valid_candidates

	## For debugging as an option
	if print_debug_stats: print(debug_stats)

	## Instantiate the chosen scenes at the final calculated positions.
	for pos in final_positions:
		var scene_to_instance = node_scenes.pick_random()
		if not scene_to_instance: continue
		var new_instance = scene_to_instance.instantiate()
		if new_instance is Node2D:
			new_instance.position = pos
		add_child(new_instance)
