@tool
extends Button

@onready var main_screen = find_parent("MainScreen")

func _on_pressed():
	main_screen.selected_set = get_parent().control_set
