extends MarginContainer

var action : String = ""
var polling : bool = false
var inputs_down := 0
var mappings = []

func initiate_polling(action_name : String):
	action = action_name
	polling = true
	$Awaiting_Input.visible = true
	visible = false
	prints("Polling for", action)
	Controls.clear_action_mappings(0, action)

func end_polling():
	polling = false
	visible = true
	$Awaiting_Input.visible = false	
	
func _input(event):
	if !polling or !(event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion): return
	if event.is_pressed() and !event.is_echo():
		inputs_down += 1
		Controls.add_action_mapping(0, action, event)
	if event.is_released(): inputs_down -= 1
	if inputs_down == 0:
		end_polling()
	

func _on_remap_up_pressed():
	initiate_polling("Up")

func _on_remap_down_pressed():
	initiate_polling("Down")


func _on_remap_left_pressed():
	initiate_polling("Left")


func _on_remap_right_pressed():
	initiate_polling("Right")


func _on_commit_pressed():
	Controls.apply_current_maps()
	get_parent().visible = false
	get_tree().paused = false
