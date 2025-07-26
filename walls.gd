@tool
extends Polygon2D

@export var generate_collider: bool = false:
	set(value):
		if value:
			_generate_static_body()
			# This is not strictly necessary as Godot 4 auto-updates, but it's good practice.
			notify_property_list_changed()

func _ready():
	# Only generate the body when the game is running, not in the editor preview.
	if not Engine.is_editor_hint():
		# Use call_deferred to avoid modifying the scene tree during the _ready phase.
		call_deferred("_generate_static_body")

func _generate_static_body():
	if polygon.size() < 3:
		print("Cannot generate collider: Polygon needs at least 3 vertices.")
		return
		
	var body_name = "GeneratedStaticBody"
	if has_node(body_name):
		# --- Part 1: Update existing body ---
		var existing_body = get_node(body_name)
		var existing_collision_shape = existing_body.get_node("CollisionShape")
		existing_collision_shape.polygon = self.polygon
		existing_body.global_transform = self.global_transform
		
		# [MODIFIED] Set the collision layer and mask on the existing body.
		existing_body.collision_layer = 2
		existing_body.collision_mask = 1
		
		print("Updated existing StaticBody and set collision layer=2, mask=1.")
		return

	# --- Part 2: Generate new body ---
	var static_body = StaticBody2D.new()
	var collision_polygon = CollisionPolygon2D.new()

	# Layer 2 (walls)
	static_body.collision_layer = 2
	# Mask 1 (player)
	static_body.collision_mask = 1

	static_body.name = body_name
	collision_polygon.name = "CollisionShape"

	collision_polygon.polygon = self.polygon

	static_body.add_child(collision_polygon)
	add_child(static_body)

	# Reset the transform of the static body relative to the polygon.
	# This ensures the collision shape is perfectly aligned.
	static_body.transform = Transform2D.IDENTITY
