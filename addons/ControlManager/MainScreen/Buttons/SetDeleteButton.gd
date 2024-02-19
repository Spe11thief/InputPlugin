@tool
extends Button

@onready var main_screen = find_parent("MainScreen")

func _on_pressed():
	print("deleting " + get_parent().control_set.name)
	if main_screen.selected_set == get_parent().control_set:
		main_screen.selected_set = null
	var path = "res://addons/ControlManager/Controls/Sets/" + get_parent().control_set.name + ".tres"
	var dir = DirAccess.open(path)
	dir.remove(path)
	main_screen.load_sets()
