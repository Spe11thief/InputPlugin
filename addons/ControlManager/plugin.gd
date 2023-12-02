@tool
extends EditorPlugin

var control_manager_name := "Controls"

func _enter_tree():
	add_autoload_singleton(control_manager_name, "res://addons/ControlManager/Controls.tscn")


func _exit_tree():
	remove_autoload_singleton(control_manager_name)
