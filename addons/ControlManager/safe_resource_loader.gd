#MIT License
#
#Copyright (c) 2023 Jan Thomä
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

class_name SafeResourceLoader

## Safely loads resource files (.tres) by scanning them for any
## embedded GDScript resources. If such resources are found, the
## loading will be aborted so embedded scripts cannote be executed.
## If loading fails for any reason, an error message will be printed
## and this function returns null.
static func load(path:String, type_hint:String = "", \
		cache_mode:ResourceLoader.CacheMode = ResourceLoader.CacheMode.CACHE_MODE_REUSE) -> Resource:
	
	# We only really support .tres files, so refuse to load anything else.
	if not path.ends_with(".tres"):
		push_error("This resource loader only supports .tres files.")
		return null	
	
	# Also refuse to load anything within res:// as it should be safe and also
	# will not be readable after export anyways.
	if path.begins_with("res://"):
		push_error("This resource loader is intended for loading resources from unsafe " + \
				"origins (e.g. saved games downloaded from the internet). Using it on safe resources " + \
				"inside res:// will just slow down loading for no benefit. In addition it will not work " + \
				"on exported games as resources are packed and no longer readable from the file system.")
		return null
		
	# Check if the file exists.
	if not FileAccess.file_exists(path):
		push_error("Cannot load resource '" + path + "' because it does not exist or is not accessible.")
		return null
	
	# Load it as text content, only. This will not execute any scripts.
	var file = FileAccess.open(path, FileAccess.READ)
	var file_as_text = file.get_as_text()
	file.close()

	# Use a regex to find any instance of an embedded GDScript resource.
	var regex:RegEx = RegEx.new()
	regex.compile("type\\s*=\\s*\"GDScript\"\\s*")	
	
	# If we found one, bail out.
	if regex.search(file_as_text) != null:
		push_warning("Resource '" + path + "' contains inline GDScripts, will not load it.")
		return null

	# Check all ext resources, and verify that all their paths start with res://
	# This is to prevent loading resources from outside the game directory.
	#
	# Format is: 
	# [ext_resource type="Script" path="res://safe_resource_loader_example/saved_game.gd" id="1_on72l"]
	# there can be arbitrary whitespace between [] or the key/value pairs. the order of the key/value pairs is arbitrary.
	# we want to match the path key, and then check that the value starts with res:// 
	# the type doesn't matter, as resources themselves could contain further resources, which in turn could contain
	# scripts, so we flat-out refuse to load ANY resource that isn't in res://

	var extResourceRegex:RegEx = RegEx.new()
	extResourceRegex.compile("\\[\\s*ext_resource\\s*.*?path\\s*=\\s*\"([^\"]*)\".*?\\]")
	var matches:Array = extResourceRegex.search_all(file_as_text)
	for match in matches:
		var resourcePath:String = match.get_string(1)
		if not resourcePath.begins_with("res://"):
			push_warning("Resource '" + path + "' contains an ext_resource with a path\n outside 'res://' (path is: '" + resourcePath + "'), will not load it.")
			return null

	# otherwise use the normal resource loader to load it.
	return ResourceLoader.load(path, type_hint, cache_mode)
