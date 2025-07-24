extends AudioStreamPlayer2D

enum SoundType {
	PADDLE,
	BACKPADDLE
}

@onready var paddle_sounds = [
		preload('res://assets/sfx/row1.ogg'),
		preload('res://assets/sfx/row2.ogg'),
		preload('res://assets/sfx/row3.ogg'),
		preload('res://assets/sfx/row4.ogg'),
	]

@onready var backpaddle_sounds = [
		preload('res://assets/sfx/backpaddle1.ogg')
	]

func play_random(type: SoundType) -> void:
	if self.playing:
		return
	match type:
		SoundType.PADDLE:
			self.stream = paddle_sounds.pick_random()
			self.play()
		SoundType.BACKPADDLE:
			self.stream = backpaddle_sounds.pick_random()
			self.play()
