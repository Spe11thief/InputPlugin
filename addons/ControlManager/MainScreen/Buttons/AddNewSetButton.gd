@tool
extends Button

@onready var text_edit_container = $".."
@onready var new_set_button = $"../../NewSetButton"
@onready var new_set_text_edit = $"../NewSetTextEdit"
@onready var main_screen = $"../../../../../../../../../.."

func _on_pressed():
	var new_set = ControlSet.new()
	new_set.name = new_set_text_edit.text
	new_set_text_edit.text = ""
	
	ResourceSaver.save(new_set, "res://addons/ControlManager/Controls/Sets/" + new_set.name + ".tres")
	main_screen.load_sets()
	main_screen.select_set_by_name(new_set.name)
	text_edit_container.visible = false
	new_set_button.visible = true
	new_set_button.grab_focus()
