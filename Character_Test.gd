extends CharacterBody2D


const SPEED = 300.0

func _physics_process(_delta):
	
	var direction = Controls.get_vector("Up", "Down", "Left", "Right")
	velocity = direction * SPEED
	if direction == Vector2.ZERO:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)
#	if Controls.is_action_pressed("Left", 0):
#		velocity.x = SPEED
#	else:
#		velocity.x = move_toward(velocity.x, 0, SPEED)
	if Controls.is_action_just_flicked("Left"):
		print("Flicked Left")
	
	if Controls.is_action_just_flicked("Right"):
		print("Flicked Right")


	move_and_slide()
