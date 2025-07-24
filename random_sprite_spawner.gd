@tool
extends Polygon2D

@export var node_scenes: Array[PackedScene]

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
		number_sprites_to_find = number_of_sprites
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

func _spawn_nodes():
	for child in get_children():
		child.queue_free()

	if node_scenes.is_empty() or self.polygon.size() < 3:
		return

	var points = self.polygon
	var bounds = Rect2(points[0], Vector2.ZERO)
	
	for p in points:
		bounds = bounds.expand(p)

	var valid_candidates = []
	var valid_candidates_number = 0
	var number_iterations = 0

	# PASS 1: GATHER ALL POSSIBLE SPAWN POINTS
	while number_iterations < MAX_ITERATIONS && valid_candidates_number < number_sprites_to_find: 
		number_iterations += 1
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var jitter = Vector2(randf_range(-1 / 2.0, 1 / 2.0), randf_range(-1 / 2.0, 1 / 2.0))
				var potential_point = Vector2(x, y) + jitter

				if not Geometry2D.is_point_in_polygon(potential_point, points):
					continue

				var noise_value = (noise_generator.get_noise_2d(potential_point.x, potential_point.y) + 1.0) / 2.0
				var draw_value = randf()
				if draw_value > noise_value:
					continue
				
				var is_valid_distance = true
				#for existing_point in valid_candidates:
					#if potential_point.distance_to(existing_point) < min_distance:
						#is_valid_distance = false
						#break
				
				if is_valid_distance:
					valid_candidates.append(potential_point)
					valid_candidates_number += 1

	# PASS 2: SELECT AND SPAWN FROM THE CANDIDATE LIST
	valid_candidates.shuffle()

	var num_to_spawn = min(number_sprites_to_find, valid_candidates.size())

	for i in range(num_to_spawn):
		var spawn_point = valid_candidates[i]
		
		var scene_to_instance = node_scenes.pick_random()
		if not scene_to_instance: continue
		
		var new_instance = scene_to_instance.instantiate()
		if new_instance is Node2D:
			new_instance.position = spawn_point
		
		if Engine.is_editor_hint():
			new_instance.owner = self

		add_child(new_instance)
