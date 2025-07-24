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

func play_paddle_sound():
	if self.playing:
		self.stop()
	self.stream = paddle_sounds.pick_random()
	self.play()

func play_backpaddle_sound():
	if self.playing:
		self.stop()
	self.stream = backpaddle_sounds.pick_random()
	self.play()
