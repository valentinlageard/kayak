extends AudioStreamPlayer2D

@onready var paddle_sounds = [
		preload('res://assets/sfx/row1.ogg'),
		preload('res://assets/sfx/row2.ogg'),
		preload('res://assets/sfx/row3.ogg'),
	]

@onready var backpaddle_sounds = [
		preload('res://assets/sfx/backpaddle1.ogg'),
		preload('res://assets/sfx/backpaddle2.ogg'),
	]
	
var volume_db_ref = -6.0

func _ready():
	self.volume_db = volume_db_ref

func play_paddle_sound():
	if self.playing:
		self.stop()
	self.stream = paddle_sounds.pick_random()
	self.pitch_scale = randf_range(0.5, 2)
	self.play()

func play_backpaddle_sound():
	if self.playing:
		self.stop()
	self.stream = backpaddle_sounds.pick_random()
	self.pitch_scale = randf_range(0.5, 2)
	self.play()
