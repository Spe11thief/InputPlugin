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

func action_has_event(action_name: String, event: InputEvent, control_code: int = -1, control_map: Map = null):
	#Left off here. Okay sooo... Basically we're going to need to iterate through all of the actions on all controllers. Then have a case where if the controller is specified, it only checks that.
	#currently we're just starting to go through all controllers regardless of case. We can probably drop control_map because that should be derived from the controller.
	#current controller maps should be held in an array with the index matching the control_code
	var map = control_map
	if control_map == null:
		map = config.default_control_map
	for device in config.device_count + 1:
		for action in map.actions:
			if device == 0:
				for i in range(action.keys.size()):
					pass
					

func action_has_eventOLD(action_name: String, event: InputEvent):
	#REWRITE
	#Sigh... event.device returns 0 for the first controller as well.
	var device = event.device
	var action: Action = get_action_by_name(action_name)
	if device == 0:
		for i in range(action.keys.size()):
			var godot_action_name = build_input_name(device, action.name, INPUT_TYPE.KEY, i)
			if InputMap.action_has_event(godot_action_name, event):
				return true
		for i in range(action.mouse_buttons.size()):
			var godot_action_name = build_input_name(device, action.name, INPUT_TYPE.MOUSE_BUTTON, i)
			if InputMap.action_has_event(godot_action_name, event):
				return true
	else:
		for i in range(action.joy_buttons.size()):
			var godot_action_name = build_input_name(device, action.name, INPUT_TYPE.JOY_BUTTON, i)
			if InputMap.action_has_event(godot_action_name, event):
				return true
		for i in range(action.axii.size()):
			var godot_action_name = build_input_name(device, action.name, INPUT_TYPE.AXIS, i)
			if InputMap.action_has_event(godot_action_name, event):
				return true
	return false
	
func _input(event: InputEvent):
	if !event.is_pressed(): return
	print(event.device)
	print(event.as_text())

