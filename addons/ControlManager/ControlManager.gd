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

var map_file_path := "user://control_maps/"
@export var clear_saved_maps := false

@onready var config: ControlManagerConfiguaration = preload("res://addons/ControlManager/ControlConfig.tres")

var buffer = {}
@export var control_maps: Array[Map] = []
var action_key = {}

func _ready():
	if !clear_saved_maps: load_user_maps()
	else: delete_user_maps()
	apply_current_maps()
	
func save_current_user_maps():
	var dir = DirAccess.open(map_file_path)
	if !dir:
		print("Creating control maps directory")
		DirAccess.make_dir_absolute(map_file_path)
		return
	for map_slot in control_maps.size():
		var success = ResourceSaver.save(control_maps[map_slot], map_file_path + "player_" + str(map_slot + 1) + "_control_map.tres")
		if success != OK: push_error("Failed to save map_" + str(map_slot))

func load_user_maps():
	var dir := DirAccess.open(map_file_path)
	if !dir:
		print("No control maps directory")
		return
	var map_slot = 0
	for file in dir.get_files().size():
		var resource = ResourceLoader.load(map_file_path + "player_" + str(map_slot + 1) + "_control_map.tres", "Map")
		if !resource is Map: continue
		if control_maps.size() > map_slot:
			control_maps[map_slot] = resource
			map_slot += 1
		else:
			control_maps.append(resource)
			map_slot += 1
			
func delete_user_maps():
	var dir := DirAccess.open(map_file_path)
	if !dir:
		print("No control maps directory")
		return
	var map_slot = 0
	for file in dir.get_files().size():
		var success = dir.remove(map_file_path + "player_" + str(map_slot + 1) + "_control_map.tres")
		
func apply_current_maps():
	print("Applying Maps")
	init_maps()
	init_buffer()
	save_current_user_maps()
	
func init_buffer():
	buffer = {}
	for i in control_maps.size():
		var map = control_maps[i]
		for action in map.actions:
			if !buffer.has(action.name):
				buffer[action.name] = {}
			if !buffer[action.name].has(i):
				buffer[action.name][i] = [{"time": 0, "strength": 0}]

func clear_godot_input_map():
	var actions := InputMap.get_actions()
	for action in actions:
		InputMap.erase_action(action)

func create_control_map_inputs(device : int):
	var map := control_maps[device]
	for action in map.actions:
		if device == 0:
			for i in range(action.keys.size()):
				commit_action_input_to_map(action, device, INPUT_TYPE.KEY, i)
			for i in range(action.mouse_buttons.size()):
				commit_action_input_to_map(action, device, INPUT_TYPE.MOUSE_BUTTON, i)
		else:
			for i in range(action.joy_buttons.size()):
				commit_action_input_to_map(action, device, INPUT_TYPE.JOY_BUTTON, i)
			for i in range(action.axii.size()):
				commit_action_input_to_map(action, device, INPUT_TYPE.AXIS, i, action.deadzone)

func init_maps():
	clear_godot_input_map()
	for device in control_maps.size():
		create_control_map_inputs(device)
	
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
	ev.device = device - 1
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
		action_key[action.name].deadzones[device] = max(deadzone, (action_key[action.name].deadzones[device] if action_key[action.name].deadzones.has(device) else 0))

func clear_action_mappings(map_slot : int, action_name : String):
	var map : Map = control_maps[map_slot]
	var action : Action
	for act in map.actions:
		if act.name == action_name: action = act
	if !action: return false
	action.keys.clear()
	action.mouse_buttons.clear()
	action.joy_buttons.clear()
	action.axii.clear()
	action_key[action_name][map_slot] = []

func add_action_mapping(map_slot : int, action_name : String, event : InputEvent):
	var action : Action = get_action_by_name(action_name, map_slot)
	if !action or action_has_event(action_name, event, map_slot):
		push_error("Action already has event assigned" + event.as_text())
		print(action.keys)
		return
	
	if event is InputEventKey:
		var mapping = event.keycode
		prints("Adding", event.as_text(), "to", action_name)
		action.keys.append(mapping)
	if event is InputEventMouseButton:
		var mapping = event.button_index
		prints("Adding", event.as_text(), "to", action_name)
		action.mouse_buttons.append(mapping)
	if event is InputEventJoypadButton:
		var mapping = event.button_index
		prints("Adding", event.as_text(), "to", action_name)
		action.joy_buttons.append(mapping)
	if event is InputEventJoypadMotion:
		if !abs(event.axis_value) > .9: return
		var mapping = event.axis
		var direction = sign(event.axis_value)
		prints("Adding", event.as_text(), "to", action_name)
		var new_axis = Axis.new()
		new_axis.axis = mapping
		new_axis.direction = direction
		action.axii.append(new_axis)

func remove_action_mapping(map_slot : int, action_name : String, event : InputEvent):
	var action : Action = get_action_by_name(action_name, map_slot)
	if !action or !action_has_event(action_name, event, map_slot): return
	
	if event is InputEventKey:
		var mapping = event.keycode
		action.keys.erase(mapping)
	if event is InputEventMouseButton:
		var mapping = event.button_index
		action.mouse_buttons.erase(mapping)
	if event is InputEventJoypadButton:
		var mapping = event.button_index
		action.joy_buttons.erase(mapping)
	if event is InputEventJoypadMotion:
		var mapping = event.axis
		var direction = sign(event.axis_value)
		var new_axis = Axis.new()
		new_axis.axis = mapping
		new_axis.direction = direction
		action.axii.erase(new_axis)

func record_event_in_buffer(event : InputEvent):
	# This might need to get streamlined into a single function to reduce comp times
	var action_name = get_event_action_name(event)
	if !action_name: return
	var device = get_event_device(event)
	buffer[action_name][device].append({"time": Time.get_ticks_msec(), "strength": get_action_raw_strength(action_name, device)})

func clean_buffer():
	for action in buffer.keys():
		for device in buffer[action].keys():
			for input in buffer[action][device]:
				if input.time < Time.get_ticks_msec() - config.buffer and buffer[action][device].size() > 2:
					buffer[action][device].erase(input)

func _input(event):
	record_event_in_buffer(event)
	
func _process(_delta):
	clean_buffer()
	
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
	if is_specific_controller(control_code): return is_controller_action_just_released(action_name, control_code)
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

func action_get_deadzone(action_name : String, control_code : int) -> float:
	if !action_key.has(action_name):
		push_error("Action '" + action_name + "' is not defined in the actions key")
		return 0.0
	if !action_key[action_name].deadzones.has(control_code):
		push_error("Action '" + action_name + "' does not have any deadzones for map " + str(control_code))
		return 0.0
	return action_key[action_name].deadzones[control_code]
		
func get_controller_action_strongest_input(action_name : String, control_code : int):
	var inputs = action_key[action_name][control_code]
	var strengths = []
	for input in inputs:
		strengths.append({"input": input, "strength": Input.get_action_raw_strength(input)})
	return get_strongest_strength(strengths)

func get_action_strongest_input(action_name : String, control_code := -1):
	if is_specific_controller(control_code): return get_controller_action_strongest_input(action_name, control_code)
	var strengths = []
	for device in control_maps.size():
		strengths.append(get_controller_action_strongest_input(action_name, device))
	return get_strongest_strength(strengths)

func get_strongest_strength(strengths):
	#Finish get_vector using only axis or buttons, update strongest_input functions to use new InputStrength class
	var strongest_input = null
	for strength in strengths:
		if !strongest_input:
			strongest_input = strength
		else:
			if strongest_input.strength < strength.strength:
				strongest_input = strength
	return strongest_input

func is_input_axis(input) -> bool:
	return input.input.contains("axis")

func get_controller_vector(neg_x_action_name : String, pos_x_action_name : String, neg_y_action_name : String, pos_y_action_name : String, control_code : int, deadzone = null):
	var inputs = {
		"neg_x": get_controller_action_strongest_input(neg_x_action_name, control_code),
		"pos_x": get_controller_action_strongest_input(pos_x_action_name, control_code),
		"neg_y": get_controller_action_strongest_input(neg_y_action_name, control_code),
		"pos_y": get_controller_action_strongest_input(pos_y_action_name, control_code)
	}
	var is_axis := false
	var strongest_input = null
	for input in inputs.keys():
		if !strongest_input:
			strongest_input = inputs[input]
		if strongest_input.strength < inputs[input].strength:
			strongest_input = inputs[input]
	if is_input_axis(strongest_input): is_axis = true
	var strengths = {
		"neg_x": 0,
		"pos_x": 0,
		"neg_y": 0,
		"pos_y": 0
	}
	for key in inputs.keys():
		if is_input_axis(inputs[key]) == is_axis:
			strengths[key] = inputs[key].strength

	var vector = Vector2(strengths.pos_x - strengths.neg_x, strengths.pos_y - strengths.neg_y)
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
	var vectors : Array[Vector2] = []
	for device in control_maps.size():
		vectors.append(get_controller_vector(neg_x_action_name, pos_x_action_name, neg_y_action_name, pos_y_action_name, device, deadzone))
	return vectors.reduce(func(max : Vector2, val : Vector2): return val if abs(val.length_squared()) > abs(max.length_squared()) else max)

func get_controller_raw_vector(neg_x_action_name : String, pos_x_action_name : String, neg_y_action_name : String, pos_y_action_name : String, control_code : int):
	var vector = Vector2(get_action_raw_strength(pos_x_action_name, control_code) - get_action_raw_strength(neg_x_action_name, control_code), get_action_raw_strength(pos_y_action_name, control_code) - get_action_raw_strength(neg_y_action_name, control_code))
	return vector

func get_raw_vector(neg_x_action_name : String, pos_x_action_name : String, neg_y_action_name : String, pos_y_action_name : String, control_code := -1):
	if is_specific_controller(control_code): return get_controller_raw_vector(neg_x_action_name, pos_x_action_name, neg_y_action_name, pos_y_action_name, control_code)
	var vectors = []
	for device in control_maps.size():
		vectors.append(get_controller_raw_vector(neg_x_action_name, pos_x_action_name, neg_y_action_name, pos_y_action_name, device)) 
	return vectors.reduce(func(max : Vector2, val : Vector2): return val if abs(val.length_squared()) > abs(max.length_squared()) else max)

func get_event_device(event : InputEvent) -> int:
	for i in range(control_maps.size()):
		var map := control_maps[i]
		for action in map.actions:
			if action_has_event(action.name, event, i):
				return i
	return -1

func get_event_action_name(event : InputEvent):
	for i in range(control_maps.size()):
		var map:= control_maps[i]
		for action in map.actions:
			if action_has_event(action.name, event):
				return action.name

func is_controller_action_flicked(action_name : String, control_code : int, min_flick_strength : float) -> bool:
	var strength = get_action_raw_strength(action_name, control_code)
	if strength < min_flick_strength: return false
	var deadzone = action_get_deadzone(action_name, control_code)
	for input in buffer[action_name][control_code]:
		if abs(input.strength) <= deadzone:
			for sub_input in buffer[action_name][control_code]:
				buffer[action_name][control_code].clear()
			return true
	return false

func is_action_flicked(action_name : String, control_code := -1, min_flick_strength := 0.9) -> bool:
	if is_specific_controller(control_code): return is_controller_action_flicked(action_name, control_code, min_flick_strength)
	for device in control_maps.size():
		if is_controller_action_flicked(action_name, device, min_flick_strength):
			return true
	return false
