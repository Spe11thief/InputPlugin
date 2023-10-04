extends CharacterBody2D


const SPEED = 300.0

func _physics_process(delta):
	
	var direction = Controls.get_action_strength("Right") - Controls.get_action_strength("Left")
	velocity.x = direction * SPEED
	if direction == 0:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
