# FlowFieldAffected.gd
extends Node

# How much the flow field affects this object
@export var align_with_field: bool = true
@export var influence_strength: float = 5.0
@export var rotation_speed: float = 1.0

var parent_body: CharacterBody2D

func _ready():
	parent_body = get_parent()
	if not "velocity" in parent_body:
		push_error("FlowFieldAffected parent must be a physics body with a 'velocity' property!")
		queue_free()

func _physics_process(delta):
	var pos = parent_body.global_position
	var force = FlowfieldManager.get_force_at_position(pos)
	parent_body.position += force * influence_strength * delta
	
	if align_with_field:
		# We only try to align if the force is significant, to avoid snapping to zero.
		if force.length_squared() > 0.01:
			# Get the angle of the force vector. This is our target direction.
			var target_angle = force.angle()
			
			# Smoothly rotate the parent towards the target angle.
			# lerp_angle is essential because it correctly handles wrapping around from 2*PI to 0.
			parent_body.rotation = lerp_angle(parent_body.rotation, target_angle+PI/2, rotation_speed * delta)
