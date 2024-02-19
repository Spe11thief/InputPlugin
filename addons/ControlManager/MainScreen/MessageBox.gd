@tool
extends CenterContainer

@onready var main_screen = find_parent("MainScreen")

func _process(delta):
	if main_screen.selected_set: visible = false
	else: visible = true
