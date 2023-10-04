extends Node


func _input(event):
	if Controls.is_action_just_pressed("Left"):
		print("Left was just pressed")
	if Controls.is_action_just_released("Right"):
		print("Right was just released")
