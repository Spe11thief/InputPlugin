extends Node

func _process(delta):
	if Input.is_key_pressed(KEY_ESCAPE):
		$Control/Pause.visible = true
		get_tree().paused = true
