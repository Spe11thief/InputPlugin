extends CharacterBody2D


const SPEED = 300.0

func _physics_process(_delta):
	var direction = Controls.get_vector("Left", "Right", "Up", "Down")
	velocity = direction * SPEED
	move_and_slide()

func _input(event):
	if event.is_echo(): return
