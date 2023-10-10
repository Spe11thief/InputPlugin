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

var action_key = {}

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
	print(action_key)
	
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
	
	#Add built action_name to action_key
	if action_key.has(action.name):
		if action_key[action.name].has(device):
			action_key[action.name][device].append(input_name)
		else:
			action_key[action.name][device] = [input_name]
	else:
		action_key[action.name] = {}
		action_key[action.name][device] = [input_name]
	if !action_key[action.name].has("deadzones"):
		action_key[action.name].deadzones = {}
	else:
		if !action_key[action.name].deadzones.has(device):
			action_key[action.name].deadzones[device] = 0
		action_key[action.name].deadzones[device] = max(deadzone, action_key[action.name].deadzones.has(device) if action_key[action.name].deadzones[device] else 0)
	
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
	
func get_action_by_name(name: String, control_code := -1) -> Action:
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

func is_specific_controller(control_code) -> bool:
	return range(control_maps.size()).has(control_code)

func controller_action_has_event(action_name: String, event: InputEvent, control_code :int = -1) -> bool:
	var actions = action_key[action_name][control_code]
	for action in actions:
		if InputMap.action_has_event(action, event):
			return true
	return false

func action_has_event(action_name: String, event: InputEvent, control_code := -1) -> bool:
	if is_specific_controller(control_code): return controller_action_has_event(action_name, event, control_code)
	for device in control_maps.size():
		if controller_action_has_event(action_name, event, device):
			return true
	return false

func is_controller_action_just_pressed(action_name: String, control_code := -1) -> bool:
	var actions = action_key[action_name][control_code]
	for action in actions:
		if Input.is_action_just_pressed(action):
			return true
	return false

func is_action_just_pressed(action_name: String, control_code := -1) -> bool:
	if is_specific_controller(control_code): return is_controller_action_just_pressed(action_name, control_code)
	for device in control_maps.size():
		if is_controller_action_just_pressed(action_name, device):
			return true
	return false

func is_controller_action_pressed(action_name: String, control_code := -1) -> bool:
	var actions = action_key[action_name][control_code]
	for action in actions:
		if Input.is_action_pressed(action):
			return true
	return false

func is_action_pressed(action_name: String, control_code := -1) -> bool:
	if is_specific_controller(control_code): return is_controller_action_just_pressed(action_name, control_code)
	for device in control_maps.size():
		if is_controller_action_pressed(action_name, device):
			return true
	return false

func is_controller_action_just_released(action_name: String, control_code := -1) -> bool:
	var actions = action_key[action_name][control_code]
	for action in actions:
		if Input.is_action_just_released(action):
			return true
	return false

func is_action_just_released(action_name: String, control_code := -1) -> bool:
	if is_specific_controller(control_code): return is_controller_action_just_pressed(action_name, control_code)
	for device in control_maps.size():
		if is_controller_action_just_released(action_name, device):
			return true
	return false

func get_controller_action_raw_strength(action_name : String, control_code : int) -> float:
	var actions = action_key[action_name][control_code]
	var strengths = []
	for action in actions:
		strengths.append(Input.get_action_raw_strength(action))
	return strengths.max()

func get_action_raw_strength(action_name: String, control_code := -1) -> float:
	if is_specific_controller(control_code): return get_controller_action_raw_strength(action_name, control_code)
	var strengths = []
	for device in control_maps.size():
		strengths.append(get_controller_action_raw_strength(action_name, device))
	return strengths.max()
		
func get_controller_action_strength(action_name : String, control_code : int) -> float:
	var actions = action_key[action_name][control_code]
	var strengths = []
	for action in actions:
		strengths.append(Input.get_action_strength(action))
	return strengths.max()

func get_action_strength(action_name: String, control_code := -1) -> float:
	if is_specific_controller(control_code): return get_controller_action_strength(action_name, control_code)
	var strengths = []
	for device in control_maps.size():
		strengths.append(get_controller_action_strength(action_name, device))
	return strengths.max()

func get_controller_axis(neg_action_name : String, pos_action_name, control_code : int) -> float:
	return get_action_strength(pos_action_name, control_code) - get_action_strength(neg_action_name, control_code)

func get_axis(neg_action_name : String, pos_action_name, control_code := -1) -> float:
	if is_specific_controller(control_code): return get_controller_axis(neg_action_name, pos_action_name, control_code)
	var axii = []
	for device in control_maps.size():
		axii.append(get_controller_axis(neg_action_name, pos_action_name, device))
	return axii.reduce(func(max, val): return val if abs(val) > abs(max) else max)

func action_get_deadzone(action_name : String, control_code : int):
	return action_key[action_name].deadzones[control_code]
		

func get_controller_vector(neg_x_action_name : String, pos_x_action_name : String, neg_y_action_name : String, pos_y_action_name : String, control_code : int, deadzone = null):
	var vector = Vector2(get_action_raw_strength(pos_x_action_name, control_code) - get_action_raw_strength(neg_x_action_name, control_code), get_action_raw_strength(pos_y_action_name, control_code) - get_action_raw_strength(neg_y_action_name, control_code))
	if !deadzone:
		deadzone = max(
		action_get_deadzone(neg_x_action_name, control_code),
		action_get_deadzone(pos_x_action_name, control_code),
		action_get_deadzone(neg_y_action_name, control_code),
		action_get_deadzone(pos_y_action_name, control_code),
		)
	if vector.length() < deadzone: return Vector2(0,0)
	return vector
	

func get_vector(neg_x_action_name : String, pos_x_action_name : String, neg_y_action_name : String, pos_y_action_name : String, control_code := -1, deadzone = null):
	if is_specific_controller(control_code): return get_controller_vector(neg_x_action_name, pos_x_action_name, neg_y_action_name, pos_y_action_name, control_code, deadzone)
	var vectors = []
	for device in control_maps.size():
		vectors.append(get_controller_vector(neg_x_action_name, pos_x_action_name, neg_y_action_name, pos_y_action_name, device, deadzone)) 
	return vectors.reduce(func(max : Vector2, val : Vector2): return val if abs(val.length_squared()) > abs(max.length_squared()) else max)

func get_event_device(event):
	for i in range(control_maps.size()):
		var map := control_maps[i]
		for action in map.actions:
			if action_has_event(action.name, event):
				return i
	return -1

func check_buffer_for_action_flick(action_name: String, deadzone := .1, flick_strength := .9, flick_window := .1, control_code := -1, event: InputEvent = null):
	var current_strength = get_action_strength(action_name, control_code)
	if abs(current_strength) < flick_strength: return false
	var current_time = Time.get_ticks_msec()
	var starting_time = current_time - (flick_window * 1000)
	var buffer_name = build_action_buffer_name(action_name, control_code)
	var final_deadzone = max(deadzone, get_action_by_name(action_name, control_code).deadzone)
	for buffer_frame in buffer[buffer_name]:
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
