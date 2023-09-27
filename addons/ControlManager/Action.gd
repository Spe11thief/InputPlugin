extends Resource
class_name Action

enum AXII {
	Left
}

@export var action := ""
@export var keys : Array[Key] = []
@export var mouse_buttons : Array[MouseButton] = []
@export var joy_buttons : Array[JoyButton] = []
@export var axii : Array[AXII] = []
