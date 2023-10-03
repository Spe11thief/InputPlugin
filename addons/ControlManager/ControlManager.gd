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

func init_maps():
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
					commit_action_input_to_map(action, device, INPUT_TYPE.AXIS, i, action.axii[i].deadzone)
		control_maps.append(config.default_control_map.duplicate(true))
	print(InputMap.get_actions())
	
func build_input_name(device: int, action_name: String, input_type: INPUT_TYPE, index: int):
	return "p" + str(device) + "_" + action_name + "_" + input_dic[input_type] + "_" + str(index)

func commit_action_input_to_map(action: Action, device: int, input_type: INPUT_TYPE, input_index: int, deadzone: float = 0):
	var input_name = build_input_name(device, action.name, INPUT_TYPE.KEY, input_index)
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
			
func record_input_buffer():
	#TODO: Make this when get raw is complete
	pass

func _ready():
	init_maps()
	init_buffer()

func _process(delta):
	#Was commented out in the other game for some reason? Maybe performance issues
	clean_input_buffer()
	
func get_action_by_name(name: String, control_code: int = -1):
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
		var input_name = build_input_name(device, action_name, INPUT_TYPE.KEY, index)
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
	
func _input(event: InputEvent):
	if !event.is_pressed(): return
	print(event.device)
	print(event.as_text())

