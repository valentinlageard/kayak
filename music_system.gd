# MusicSystem.gd
class_name MusicSystem
extends Node

static var instance = null

# --- Configuration ---
@export_group("Audio Tracks")
@export var track_a: AudioStream # The "calm" or "base" track
@export var track_b: AudioStream # The "intense" or "action" track

@export_group("Crossfade Control")
# Determines the max values used for mapping speed/flow to the 0-1 mix range.
@export var max_speed_for_mix: float = 800.0
@export var max_flow_for_mix: float = 500.0

# These control how much each factor contributes to the final mix.
@export var speed_sensitivity: float = 0.5
@export var flow_sensitivity: float = 0.5

# How quickly the audio crossfades. Higher = faster.
@export var smoothing_speed: float = 2.0

# --- Internal State ---
@onready var track_a_player: AudioStreamPlayer = $TrackA_Player
@onready var track_b_player: AudioStreamPlayer = $TrackB_Player
@onready var turtle_players = [
		$TurtlePlayers/TurtlePlayer1,
		$TurtlePlayers/TurtlePlayer2,
		$TurtlePlayers/TurtlePlayer3,
		$TurtlePlayers/TurtlePlayer4,
		$TurtlePlayers/TurtlePlayer5,
	]

var target_mix_value: float = 0.0 # The "goal" mix (0-1), calculated each frame
var current_mix_value: float = 0.0 # The actual, smoothed mix value applied to volume
var current_turtle_number:int = 0.0
var target_turtles_mix_value = 0.0
var current_turtles_mix_value = 0.0

# We need to get these values from the player/environment
var _player_velocity: Vector2 = Vector2.ZERO
var _player_position: Vector2 = Vector2.ZERO

func _ready():
	instance = self
	GlobalSignals.turtle_started_following.connect(_on_turtle_started_following)
	GlobalSignals.turtle_stopped_following.connect(_on_turtle_stopped_following)
	
	# Assign the audio files to the players
	track_a_player.stream = track_a
	track_b_player.stream = track_b
	
	# Start both tracks playing at the same time. They must be synchronized!
	track_a_player.play()
	track_b_player.play()
	
	# Start the turtle tracks !
	for player in turtle_players:
		player.volume_db = linear_to_db(0.0001)
		player.play()
	
	# Immediately set the initial volume state
	_apply_crossfade(current_mix_value)

func _process(delta: float) -> void:
	# --- 1. Calculate Target Mix Value ---
	# Get player speed factor (0-1)
	var speed_factor = clamp( _player_velocity.length() / max_speed_for_mix, 0.0, 1.0)
	
	# Get flow field strength factor (0-1)
	var flow_strength = FlowfieldManager.get_force_at_position(_player_position).length()
	var flow_factor = clamp(flow_strength / max_flow_for_mix, 0.0, 1.0)
	
	# Combine factors based on their sensitivity
	if flow_factor == 0.0:
		target_mix_value = 0
	else:
		target_mix_value = clamp(
			(speed_factor * speed_sensitivity) + (flow_factor * flow_sensitivity),
			0.0,
			1.0
		)

	# --- 2. Smooth the Mix Value ---
	# This prevents jarring, instant changes in the music.
	current_mix_value = lerp(current_mix_value, target_mix_value, smoothing_speed * delta)
	
	_apply_crossfade(current_mix_value)
	
func _apply_crossfade(mix: float) -> void:
	# A 'mix' of 0 means 100% Track A, 0% Track B
	# A 'mix' of 1 means 0% Track A, 100% Track B
	var volume_a = 1.0 - mix
	var volume_b = mix
	
	# CRITICAL: Godot uses decibels for volume. We must convert our linear 0-1 value.
	# We add a tiny epsilon value to prevent -inf dB when volume is exactly 0.
	var epsilon = 0.0001
	track_a_player.volume_db = linear_to_db(volume_a + epsilon)
	track_b_player.volume_db = linear_to_db(volume_b + epsilon)

func _on_turtle_started_following():
	current_turtle_number += 1
	target_turtles_mix_value = max(1.0, current_turtle_number / len(turtle_players))
	if current_turtle_number <= len(turtle_players):
		turtle_players[current_turtle_number - 1].volume_db = linear_to_db(0.4)
	print('began following...')
	print(current_turtle_number)
	for player in turtle_players:
		print(player.stream, player.volume_db)


func _on_turtle_stopped_following():
	current_turtle_number -= 1
	target_turtles_mix_value = max(1.0, current_turtle_number /  len(turtle_players))
	for i in range(len(turtle_players) - current_turtle_number):
		turtle_players[len(turtle_players) - i - 1].volume_db = linear_to_db(0.0001)
	print('stopped following...')
	print(current_turtle_number)
	for player in turtle_players:
		print(player.stream, player.volume_db)


# --- Public API ---
# The player controller will call this function every frame.
func update_player_state(player_velocity: Vector2, player_position: Vector2):
	_player_velocity = player_velocity
	_player_position = player_position
