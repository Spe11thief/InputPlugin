@tool
extends EditorPlugin

var control_manager_name := "Controls"

const MainScreen = preload("res://addons/ControlManager/MainScreen/MainScreen.tscn")
var main_screen_instance : Control

func _enter_tree():
	main_screen_instance = MainScreen.instantiate() as Control
	EditorInterface.get_editor_main_screen().add_child(main_screen_instance)
	_make_visible(false)
	
	add_autoload_singleton(control_manager_name, "res://addons/ControlManager/Controls.tscn")

func _has_main_screen():
	return true
	
func _make_visible(visible):
	if main_screen_instance:
		main_screen_instance.visible = visible
	
func _get_plugin_name():
	return "Controls"
	
func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon("Button", "EditorIcons")

func _exit_tree():
	if main_screen_instance:
		main_screen_instance.queue_free()
	remove_autoload_singleton(control_manager_name)
