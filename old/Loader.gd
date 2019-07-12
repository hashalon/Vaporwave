extends Node


### LOAD RESOURCES ###

# filter scenes, preload them and store them into a dictionary
static func prepare_scenes(directory:String, scenes:Array)->Dictionary:
	var prepared:Dictionary = {}
	
	for scene in scenes:
		# filter out non scene files
		if scene.ends_with(".tscn"):
			var nm:String=scene.left(scene.length() - 5)
			# prepare scenes in PackedScene
			prepared[nm] = load(directory + scene)
	
	return prepared


# list the files of the directory
static func list_files(path:String)->Array:
	# iterate through the directory
	var dir:Directory = Directory.new()
	if dir.open(path) == OK:
		var list:Array = []
		
		# begin iteration
		dir.list_dir_begin()
		var file_name:String = dir.get_next()
		while (file_name != ""):
			
			# ignore sub-directories
			if not dir.current_is_dir(): list.append(file_name)
			file_name = dir.get_next()
		
		# close iteration and return list of files
		dir.list_dir_end()
		return list
	
	# if we failed to open the directory, return no array
	else: return []