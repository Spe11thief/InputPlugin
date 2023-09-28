extends Resource
class_name Axis

enum DIR {
	NEGATIVE = -1,
	POSATIVE = 1,
}

@export var axis : JoyAxis
@export var direction : DIR
@export var deadzone : float
