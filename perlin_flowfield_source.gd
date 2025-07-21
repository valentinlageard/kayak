extends FlowFieldSource

@export var noise_scale: float = 0.05
@export var noise_strength_scale: float = 0.05

var noise = FastNoiseLite.new()

func _ready():
	super._ready() 
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

func get_vector_at(world_position: Vector2) -> Vector2:
	var angle = remap(noise.get_noise_2d(world_position.x * noise_scale, world_position.y * noise_scale), -0.5, 0.5, -TAU, TAU)
	var force = remap(noise.get_noise_2d(world_position.x * noise_strength_scale, world_position.y * noise_strength_scale), 0.0, 1.0, min_strength, max_strength)
	var base_vector = Vector2.from_angle(angle)
	return base_vector * force
