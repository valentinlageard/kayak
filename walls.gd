@tool
extends Polygon2D

@export var generate_collider: bool = false:
	set(value):
		if value:
			_generate_static_body()
			notify_property_list_changed()

func _ready():
	if not Engine.is_editor_hint():
		call_deferred("_generate_static_body")

func _generate_static_body():
	if polygon.size() < 3:
		print("Cannot generate collider: Polygon needs at least 3 vertices.")
		return
		
	var body_name = "GeneratedStaticBody"
	if has_node(body_name):
		var existing_body = get_node(body_name)
		var existing_collision_shape = existing_body.get_node("CollisionShape")
		existing_collision_shape.polygon = self.polygon
		existing_body.global_transform = self.global_transform
		print("Updated existing StaticBody.")
		return

	print("Generating new StaticBody.")
	var static_body = StaticBody2D.new()
	var collision_polygon = CollisionPolygon2D.new()

	static_body.name = body_name
	collision_polygon.name = "CollisionShape"

	collision_polygon.polygon = self.polygon

	static_body.add_child(collision_polygon)
	add_child(static_body)

	static_body.transform = Transform2D.IDENTITY
