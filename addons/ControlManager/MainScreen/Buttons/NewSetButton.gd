@tool
extends Button

@onready var text_edit_container = $"../AddSetTextEditContainer"
@onready var text_edit = $"../AddSetTextEditContainer/NewSetTextEdit"

func _on_pressed():
	visible = false
	text_edit_container.visible = true
	text_edit.grab_focus()
