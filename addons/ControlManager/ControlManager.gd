extends Node

enum INPUT_TYPE {
	KEY,
	MOUSE_BUTTON,
	JOY_BUTTON,
	AXIS,
}

var input_dic = [
	"key", "mouse_button", "joy_button", "axis"
]

@onready var config: ControlManagerConfiguaration = preload("res://addons/ControlManager/ControlConfig.tres")

var buffer = {}

var control_maps: Array[Map] = []

var godot_action_key = {}

func clear_godot_input_map():
	var actions = InputMap.get_actions()

func init_maps():
	clear_godot_input_map()
	#run initialization for keyboard + mouse and each controller
	for device in config.device_count + 1:
		for action in config.default_control_map.actions:
			#run if keyboard + mouse
			if device == 0:
				for i in range(action.keys.size()):
					commit_action_input_to_map(action, device, INPUT_TYPE.KEY, i)
				for i in range(action.mouse_buttons.size()):
					commit_action_input_to_map(action, device, INPUT_TYPE.MOUSE_BUTTON, i)
					
			#run if controller
			else:
				for i in range(action.joy_buttons.size()):
					commit_action_input_to_map(action, device, INPUT_TYPE.JOY_BUTTON, i)
				for i in range(action.axii.size()):
					commit_action_input_to_map(action, device, INPUT_TYPE.AXIS, i, action.deadzone)
		control_maps.append(config.default_control_map.duplicate(true))
	#print(InputMap.get_actions())
	
func build_input_name(device: int, action_name: String, input_type: INPUT_TYPE, index: int):
	return "p" + str(device) + "_" + action_name + "_" + input_dic[input_type] + "_" + str(index)

func commit_action_input_to_map(action: Action, device: int, input_type: INPUT_TYPE, input_index: int, deadzone: float = 0):
	var input_name = build_input_name(device, action.name, input_type, input_index)
	if InputMap.has_action(input_name):
		InputMap.erase_action(input_name)
	InputMap.add_action(input_name, deadzone)
	# Build and commit event
	var ev
	match input_type:
		INPUT_TYPE.KEY:
			ev = InputEventKey.new()
			ev.keycode = action.keys[input_index]
		INPUT_TYPE.MOUSE_BUTTON:
			ev = InputEventMouseButton.new()
			ev.button_index = action.mouse_buttons[input_index]
		INPUT_TYPE.JOY_BUTTON:
			ev = InputEventJoypadButton.new()
			ev.button_index = action.joy_buttons[input_index]
		INPUT_TYPE.AXIS:
			ev = InputEventJoypadMotion.new()
			ev.axis = action.axii[input_index].axis
			ev.axis_value = action.axii[input_index].direction
	InputMap.action_add_event(input_name, ev)
	
func init_buffer():
	for device in config.device_count + 1:
		for action in config.default_control_map.actions:
			buffer["p" + str(device) + "_" + action.name] = [{"strength" : 0, "time": 0}]
			
func clean_input_buffer():
	for control_action in buffer:
		var current_time = Time.get_ticks_msec()
		for input in buffer[control_action]:
			if input.time + config.buffer > current_time and buffer[control_action].size() > 1:
				buffer[control_action].erase(input)

func build_action_buffer_name(action_name: String, control_code: int):
	return "p" + str(control_code) + "_" + action_name
	
func build_event_buffer_action_names(event):
	var action_names = []
	for i in range(control_maps.size()):
		var map := control_maps[i]
		for action in map.actions:
			if action_has_event(action.name, event):
				action_names.append(build_action_buffer_name(action.name, i))
	#print(action_names)
	return action_names

# TODO: Come back once get control_code is a thing
func record_input_buffer(event: InputEvent):
	if event.is_echo(): return
	var action_buffer_names = build_event_buffer_action_names(event)
	for action_name in action_buffer_names:
		var device = action_name[1] as int
		var action = action_name.get_slice("_",1)
		var input_strength = Controls.get_action_raw_strength(action, device)
		if buffer[action_name].size() > 0 and buffer[action_name][0].strength == input_strength: break
		buffer[action_name].push_front({"strength" = input_strength, "time" = Time.get_ticks_msec()})

func _ready():
	init_maps()
	init_buffer()

func _process(delta):
	#Was commented out in the other game for some reason? Maybe performance issues
	clean_input_buffer()
	pass
	
func _input(event):
	record_input_buffer(event)
	pass
	
func get_action_by_name(name: String, control_code: int = -1) -> Action:
	if !range(control_maps.size()).has(control_code):
		for action in control_maps[control_code].actions:
			if action.name.match(name):
				return action
		push_error("Action " + name + " does not exist for device" + str(control_code))
	else:
		for controller in range(control_maps.size()):
			for action in control_maps[controller].actions:
				if action.name.match(name):
					return action
		push_error("Action " + name + " does not exist in current control maps") 
	return null

# USED FOR ACTION_NAME_HAS_EVENT
func input_has_event(device: int, action_name: String, input_type: INPUT_TYPE, index: int, event: InputEvent):
		var input_name = build_input_name(device, action_name, input_type, index)
		if InputMap.action_has_event(input_name, event):
			return true
		else:
			return false

# USED FOR ACTION_NAME_HAS_EVENT
func map_has_event(map: Map, device: int, action_name: String, event: InputEvent):
	for action in map.actions:
		if device == 0:
			for i in range(action.keys.size()):
				if input_has_event(device, action_name, INPUT_TYPE.KEY, i, event):
					return true
			for i in range(action.mouse_buttons.size()):
				if input_has_event(device, action_name, INPUT_TYPE.MOUSE_BUTTON, i, event):
					return true
		else:
			for i in range(action.joy_buttons.size()):
				if input_has_event(device, action_name, INPUT_TYPE.JOY_BUTTON, i, event):
					return true
			for i in range(action.axii.size()):
				if input_has_event(device, action_name, INPUT_TYPE.AXIS, i, event):
					return true

func map_has_action(map: Map, action_name: String):
	#TODO: Use this to catch checking maps for actions that don't exist.
	for action in map.actions:
		if action.name == action_name:
			return true
	return false

# Check for input with action name
func action_has_event(action_name: String, event: InputEvent, control_code: int = -1):
	if !range(control_maps.size()).has(control_code):
		for device in control_maps.size():
			var map := control_maps[device]
			if map_has_event(map, device, action_name, event):
				return true
	else:
		var map := control_maps[control_code]
		if map_has_event(map, control_code, action_name, event):
			return true
	return false
	
# USED FOR IS_ACTION_JUST_PRESSED
func is_input_just_pressed(device: int, action_name: String, input_type: INPUT_TYPE, index: int):
	var input_name = build_input_name(device, action_name, input_type, index)
	return Input.is_action_just_pressed(input_name)

# USED FOR IS_ACTION_JUST_PRESSED
func is_map_action_just_pressed(map: Map, device: int, action_name: String):
	var action: Action = get_action_by_name(action_name, device)
	if device == 0:
		for i in range(action.keys.size()):
			if is_input_just_pressed(device, action_name, INPUT_TYPE.KEY, i):
				return true
		for i in range(action.mouse_buttons.size()):
			if is_input_just_pressed(device, action_name, INPUT_TYPE.MOUSE_BUTTON, i):
				return true
	else:
		for i in range(action.joy_buttons.size()):
			if is_input_just_pressed(device, action_name, INPUT_TYPE.JOY_BUTTON, i):
				return true
		for i in range(action.axii.size()):
			if is_input_just_pressed(device, action_name, INPUT_TYPE.AXIS, i):
				return true
	return false

func is_action_just_pressed(action_name: String, control_code: = -1, event: InputEvent = null):
	#Clear extra input events
	if event:
		if !action_has_event(action_name, event, control_code):
			return
	
	#If control code is outside possible range, check all controllers
	if !range(control_maps.size()).has(control_code):
		for device in control_maps.size():
			var map := control_maps[device]
			if is_map_action_just_pressed(map, device, action_name):
				return true
	else:
		var map := control_maps[control_code]
		return is_map_action_just_pressed(map, control_code, action_name)

# USED FOR IS_ACTION_PRESSED
func is_input_pressed(device: int, action_name: String, input_type: INPUT_TYPE, index: int):
	var input_name = build_input_name(device, action_name, input_type, index)
	return Input.is_action_pressed(input_name)

# USED FOR IS_ACTION_PRESSED
func is_map_action_pressed(map: Map, device: int, action_name: String):
	var action: Action = get_action_by_name(action_name, device)
	if device == 0:
		for i in range(action.keys.size()):
			if is_input_pressed(device, action_name, INPUT_TYPE.KEY, i):
				return true
		for i in range(action.mouse_buttons.size()):
			if is_input_pressed(device, action_name, INPUT_TYPE.MOUSE_BUTTON, i):
				return true
	else:
		for i in range(action.joy_buttons.size()):
			if is_input_pressed(device, action_name, INPUT_TYPE.JOY_BUTTON, i):
				return true
		for i in range(action.axii.size()):
			if is_input_pressed(device, action_name, INPUT_TYPE.AXIS, i):
				return true
	return false

func is_action_pressed(action_name: String, control_code: = -1, event: InputEvent = null):
	#Clear extra input events
	if event:
		if !action_has_event(action_name, event, control_code):
			return
	if !range(control_maps.size()).has(control_code):
		for device in control_maps.size():
			var map := control_maps[device]
			if is_map_action_pressed(map, device, action_name):
				return true
	else:
		var map := control_maps[control_code]
		return is_map_action_pressed(map, control_code, action_name)

# USED FOR IS_ACTION_JUST_RELEASED
func is_input_just_released(device: int, action_name: String, input_type: INPUT_TYPE, index: int):
	var input_name = build_input_name(device, action_name, input_type, index)
	return Input.is_action_just_released(input_name)

# USED FOR IS_ACTION_JUST_RELEASED
func is_map_action_just_released(map: Map, device: int, action_name: String):
	var action: Action = get_action_by_name(action_name, device)
	if device == 0:
		for i in range(action.keys.size()):
			if is_input_just_released(device, action_name, INPUT_TYPE.KEY, i):
				return true
		for i in range(action.mouse_buttons.size()):
			if is_input_just_released(device, action_name, INPUT_TYPE.MOUSE_BUTTON, i):
				return true
	else:
		for i in range(action.joy_buttons.size()):
			if is_input_just_released(device, action_name, INPUT_TYPE.JOY_BUTTON, i):
				return true
		for i in range(action.axii.size()):
			if is_input_just_released(device, action_name, INPUT_TYPE.AXIS, i):
				return true
	return false

func is_action_just_released(action_name: String, control_code: = -1, event: InputEvent = null):
	#Clear extra input events
	if event:
		if !action_has_event(action_name, event, control_code):
			return
	if !range(control_maps.size()).has(control_code):
		for device in control_maps.size():
			var map := control_maps[device]
			if is_map_action_just_released(map, device, action_name):
				return true
	else:
		var map := control_maps[control_code]
		return is_map_action_just_released(map, control_code, action_name)

func get_input_raw_strength(device: int, action_name: String, input_type: INPUT_TYPE, index: int):
	var input_name = build_input_name(device, action_name, input_type, index)
	return Input.get_action_raw_strength(input_name)

func get_map_action_raw_strength(map: Map, device: int, action_name: String):
	var action: Action = get_action_by_name(action_name, device)
	var strength: float = 0
	if device == 0:
		for i in range(action.keys.size()):
			var input_strength: float = get_input_raw_strength(device, action_name, INPUT_TYPE.KEY, i)
			if abs(input_strength)  > strength:
				strength = input_strength
		for i in range(action.mouse_buttons.size()):
			var input_strength: float = get_input_raw_strength(device, action_name, INPUT_TYPE.MOUSE_BUTTON, i)
			if abs(input_strength)  > strength:
				strength = input_strength
	else:
		for i in range(action.joy_buttons.size()):
			var input_strength: float = get_input_raw_strength(device, action_name, INPUT_TYPE.JOY_BUTTON, i)
			if abs(input_strength)  > strength:
				strength = input_strength
		for i in range(action.axii.size()):
			var input_strength: float = get_input_raw_strength(device, action_name, INPUT_TYPE.AXIS, i)
			if abs(input_strength)  > strength:
				strength = input_strength
	return strength

func get_action_raw_strength(action_name: String, control_code: = -1, event: InputEvent = null):
		#Clear extra input events
	if event:
		if !action_has_event(action_name, event, control_code):
			return
	var strength: float = 0
	if !range(control_maps.size()).has(control_code):
		for device in control_maps.size():
			var map := control_maps[device]
			var input_strength = get_map_action_raw_strength(map, device, action_name)
			if abs(input_strength) > strength:
				strength = input_strength
	else:
		var map := control_maps[control_code]
		var input_strength = get_map_action_raw_strength(map, control_code, action_name)
		if abs(input_strength) > strength:
			strength = input_strength
	return strength

func get_input_strength(device: int, action_name: String, input_type: INPUT_TYPE, index: int):
	var input_name = build_input_name(device, action_name, input_type, index)
	return Input.get_action_strength(input_name)

func get_map_action_strength(map: Map, device: int, action_name: String):
	var action: Action = get_action_by_name(action_name, device)
	var strength: float = 0
	if device == 0:
		for i in range(action.keys.size()):
			var input_strength: float = get_input_strength(device, action_name, INPUT_TYPE.KEY, i)
			if abs(input_strength)  > strength:
				strength = input_strength
		for i in range(action.mouse_buttons.size()):
			var input_strength: float = get_input_strength(device, action_name, INPUT_TYPE.MOUSE_BUTTON, i)
			if abs(input_strength)  > strength:
				strength = input_strength
	else:
		for i in range(action.joy_buttons.size()):
			var input_strength: float = get_input_strength(device, action_name, INPUT_TYPE.JOY_BUTTON, i)
			if abs(input_strength)  > strength:
				strength = input_strength
		for i in range(action.axii.size()):
			var input_strength: float = get_input_strength(device, action_name, INPUT_TYPE.AXIS, i)
			if abs(input_strength)  > strength:
				strength = input_strength
	return strength

func get_action_strength(action_name: String, control_code: = -1, event: InputEvent = null):
	if event:
		if !action_has_event(action_name, event, control_code):
			return
	var strength: float = 0
	if !range(control_maps.size()).has(control_code):
		for device in control_maps.size():
			var map := control_maps[device]
			var input_strength = get_map_action_strength(map, device, action_name)
			if abs(input_strength) > strength:
				strength = input_strength
	else:
		var map := control_maps[control_code]
		var input_strength = get_map_action_strength(map, control_code, action_name)
		if abs(input_strength) > strength:
			strength = input_strength
	return strength

func get_axis(action_pos_name: String, action_neg_name: String, control_code: = -1, deadzone: float = .1, event: InputEvent = null):
	if event:
		if !action_has_event(action_pos_name, event, control_code) && !action_has_event(action_neg_name, event, control_code):
			printerr("neither action has event")
			return
	var axis: float = 0
	if !range(control_maps.size()).has(control_code):
		for device in control_maps.size():
			var pos_deadzone = get_action_by_name(action_pos_name, device).deadzone
			var neg_deadzone = get_action_by_name(action_neg_name, device).deadzone
			var avg_deadzone = (pos_deadzone + neg_deadzone) / 2
			var final_deadzone = max(avg_deadzone, deadzone)
			var pos = get_action_raw_strength(action_pos_name, device)
			var neg = get_action_raw_strength(action_neg_name, device)
			var new_axis = pos - neg
			if abs(new_axis) > abs(axis) and (new_axis < -final_deadzone or new_axis > final_deadzone):
				axis = pos - neg
	else:
		var pos_deadzone = get_action_by_name(action_pos_name, control_code).deadzone
		var neg_deadzone = get_action_by_name(action_neg_name, control_code).deadzone
		var avg_deadzone = (pos_deadzone + neg_deadzone) / 2
		var final_deadzone = max(avg_deadzone, deadzone)
		var pos = get_action_raw_strength(action_pos_name, control_code)
		var neg = get_action_raw_strength(action_neg_name, control_code)
		if abs(axis) > abs(axis) and axis > -final_deadzone and axis < final_deadzone:
			axis = pos - neg
	return axis

func get_vector(action_up_name: String, action_down_name: String, action_left_name: String, action_right_name: String, control_code := -1, deadzone: float = .1, event: InputEvent = null):
	if event:
		if !action_has_event(action_up_name, event, control_code) && !action_has_event(action_down_name, event, control_code) && !action_has_event(action_left_name, event, control_code) && !action_has_event(action_right_name, event, control_code):
			printerr("no action hasevent")
			return
	var vector: Vector2 = Vector2.ZERO
	if !range(control_maps.size()).has(control_code):
		for device in control_maps.size():
			var up_deadzone = get_action_by_name(action_up_name, device).deadzone
			var down_deadzone = get_action_by_name(action_down_name, device).deadzone
			var left_deadzone = get_action_by_name(action_left_name, device).deadzone
			var right_deadzone = get_action_by_name(action_right_name, device).deadzone
			var avg_deadzone = (up_deadzone + down_deadzone + left_deadzone + right_deadzone) / 4
			var final_deadzone = max(avg_deadzone, deadzone)
			var real_deadzone = sqrt((final_deadzone * final_deadzone) * 2)
			var up = get_action_raw_strength(action_up_name, device)
			var down = get_action_raw_strength(action_down_name, device)
			var left = get_action_raw_strength(action_left_name, device)
			var right = get_action_raw_strength(action_right_name, device)
			var new_vector = Vector2(right - left, down - up)
			if vector.length_squared() < new_vector.length_squared() and new_vector.length() > real_deadzone:
				vector = new_vector
	else:
		var up_deadzone = get_action_by_name(action_up_name, control_code).deadzone
		var down_deadzone = get_action_by_name(action_down_name, control_code).deadzone
		var left_deadzone = get_action_by_name(action_left_name, control_code).deadzone
		var right_deadzone = get_action_by_name(action_right_name, control_code).deadzone
		var avg_deadzone = (up_deadzone + down_deadzone + left_deadzone + right_deadzone) / 4
		var final_deadzone = max(avg_deadzone, deadzone)
		var real_deadzone = sqrt((final_deadzone * final_deadzone) * 2)
		var up = get_action_raw_strength(action_up_name, control_code)
		var down = get_action_raw_strength(action_down_name, control_code)
		var left = get_action_raw_strength(action_left_name, control_code)
		var right = get_action_raw_strength(action_right_name, control_code)
		var new_vector = Vector2(right - left, down - up)
		if vector.length_squared() < new_vector.length_squared() and new_vector.length() > real_deadzone:
			vector = new_vector
	return vector

func get_event_action_names(event, control_code := -1):
	var action_names = []
	for i in range(control_maps.size()):
		var map := control_maps[i]
		for action in map.actions:
			if action_has_event(action.name, event):
				action_names.append(action.name)
	return action_names

func get_event_device(event):
	for i in range(control_maps.size()):
		var map := control_maps[i]
		for action in map.actions:
			if action_has_event(action.name, event):
				return i
	return -1

func check_buffer_for_action_flick(action_name: String, deadzone := .1, flick_strength := .9, flick_window := .1, control_code := -1, event: InputEvent = null):
	var current_strength = get_action_strength(action_name, control_code, event)
	if abs(current_strength) < flick_strength: return false
	var current_time = Time.get_ticks_msec()
	var starting_time = current_time - (flick_window * 1000)
	var buffer_name = build_action_buffer_name(action_name, control_code)
	var final_deadzone = max(deadzone, get_action_by_name(action_name, control_code).deadzone)
	for buffer_frame in buffer[buffer_name]:
		#print(buffer_frame)
		if buffer_frame.time >= starting_time and abs(buffer_frame.strength) < final_deadzone:
			return true
	return false

func is_action_just_flicked(action_name: String, deadzone := .1, flick_strength := .9, flick_window := .1, control_code := -1, event: InputEvent = null):
	if event:
		if !action_has_event(action_name, event, control_code):
			printerr("action does not have event")
			return
	if !range(control_maps.size()).has(control_code):
		for device in control_maps.size():
			if check_buffer_for_action_flick(action_name, deadzone, flick_strength, flick_window, device, event):
				return true
	else:
		if check_buffer_for_action_flick(action_name, deadzone, flick_strength, flick_window, control_code, event):
			return true
	return false
