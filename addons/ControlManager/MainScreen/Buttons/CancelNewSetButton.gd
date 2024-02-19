@tool
extends Button

@onready var text_edit_container = $".."
@onready var new_set_button = $"../../NewSetButton"

func _on_pressed():
	text_edit_container.visible = false
	new_set_button.visible = true
	new_set_button.grab_focus()
