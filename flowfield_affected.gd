# FlowFieldAffected.gd
extends Node

## How much the flow field affects this object.
# The strength of the force applied to the rigidbody.
@export var influence_strength: float = 5
## If enabled, the object will rotate to align with the flow field's direction.
@export var align_with_field: bool = true
## How quickly the object rotates to align with the flow field.
@export var rotation_speed: float = 5.0

var parent_body: RigidBody2D

func _ready():
	parent_body = get_parent()
	if not parent_body is RigidBody2D:
		push_error("FlowFieldAffected's parent must be a RigidBody2D for physics interactions.")
		queue_free()

func _physics_process(_delta):
	var pos = parent_body.global_position
	var force_direction = FlowfieldManager.get_force_at_position(pos).normalized()
	
	parent_body.apply_central_force(force_direction * influence_strength)
	
	if align_with_field:
		if force_direction.length_squared() > 0:
			var target_angle = force_direction.angle()
			var angle_diff = short_angle_dist(parent_body.rotation, target_angle)
			parent_body.angular_velocity = angle_diff * rotation_speed
			
func short_angle_dist(from, to):
	var max_angle = PI * 2
	var difference = fmod(to - from, max_angle)
	return fmod(2 * difference, max_angle) - difference
