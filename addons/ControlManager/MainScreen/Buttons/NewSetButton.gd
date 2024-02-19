@tool
extends Button

@onready var text_edit_container = $"../HBoxContainer2"
@onready var text_edit = $"../HBoxContainer2/NewSetTextEdit"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_pressed():
	visible = false
	text_edit_container.visible = true
	text_edit.grab_focus()
