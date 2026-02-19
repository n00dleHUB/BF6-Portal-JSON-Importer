@tool
extends Control

# UI References
@onready var file_path_line_edit = $VBoxContainer/HBoxContainer/FilePath
@onready var rebuild_button = $VBoxContainer/GridContainer/RebuildButton
@onready var create_tscn_button = $VBoxContainer/GridContainer/CreateTscnButton
@onready var open_folder_button = $VBoxContainer/OpenFolderButton

@onready var status_label = $VBoxContainer/StatusLabel
@onready var file_dialog = $FileDialog

# Cache for asset paths: { "asset_name": "res://path/to/asset.tscn" }
var asset_library = {}

func _init():
	print("DEBUG: Import Dock _init script instance created.")

func _enter_tree():
	print("DEBUG: Import Dock _enter_tree.")
	# Defer signal connection to ensure children are ready
	call_deferred("_connect_signals_safe")

func _ready():
	print("DEBUG: Import Dock _ready.")
	
	if file_path_line_edit:
		file_path_line_edit.editable = true
	else:
		print("DEBUG ERROR: file_path_line_edit is null in _ready")
	
	_connect_signals_safe()

func _connect_signals_safe():
	print("DEBUG: Attempting to connect signals...")
	
	var browse_btn = get_node_or_null("VBoxContainer/HBoxContainer/BrowseButton")
	if browse_btn:
		if not browse_btn.pressed.is_connected(_on_browse_pressed):
			browse_btn.pressed.connect(_on_browse_pressed)
			print("DEBUG: Connected BrowseButton")
	else:
		print("DEBUG ERROR: BrowseButton node not found at VBoxContainer/HBoxContainer/BrowseButton")

	if rebuild_button:
		if not rebuild_button.pressed.is_connected(_on_rebuild_pressed):
			rebuild_button.pressed.connect(_on_rebuild_pressed)
			print("DEBUG: Connected RebuildButton")
	else:
		print("DEBUG ERROR: RebuildButton node not found")

	if create_tscn_button:
		if not create_tscn_button.pressed.is_connected(_on_create_tscn_pressed):
			create_tscn_button.pressed.connect(_on_create_tscn_pressed)
			print("DEBUG: Connected CreateTscnButton")
	else:
		print("DEBUG ERROR: CreateTscnButton node not found")
		
	if open_folder_button:
		if not open_folder_button.pressed.is_connected(_on_open_folder_pressed):
			open_folder_button.pressed.connect(_on_open_folder_pressed)
			print("DEBUG: Connected OpenFolderButton")
	else:
		print("DEBUG ERROR: OpenFolderButton node not found")
	
	if file_dialog:
		if not file_dialog.file_selected.is_connected(_on_file_selected):
			file_dialog.file_selected.connect(_on_file_selected)
			print("DEBUG: Connected FileDialog")
	else:
		print("DEBUG ERROR: FileDialog node not found")

func _on_browse_pressed():
	print("DEBUG: Browse Button Pressed")
	if file_dialog:
		file_dialog.popup_centered()
	else:
		print("DEBUG ERROR: FileDialog is missing during browse press")

func _on_file_selected(path):
	print("DEBUG: File Selected: ", path)
	if file_path_line_edit:
		file_path_line_edit.text = path
	status_label.text = "File selected: " + path.get_file()

func _on_open_folder_pressed():
	print("DEBUG: Open Folder Pressed")
	var json_path = ""
	if file_path_line_edit:
		json_path = file_path_line_edit.text
	
	if json_path == "":
		status_label.text = "No file selected."
		print("DEBUG: No file selected for open folder.")
		return
	
	var folder = json_path.get_base_dir()
	print("DEBUG: Opening folder: ", folder)
	var global_path = ProjectSettings.globalize_path(folder)
	OS.shell_open(global_path)

func _on_create_tscn_pressed():
	print("DEBUG: Create TSCN Pressed")
	await _process_import(false)

func _on_rebuild_pressed():
	print("DEBUG: Rebuild Pressed")
	await _process_import(true)

func _process_import(add_to_scene: bool):
	print("DEBUG: Processing import. AddToScene: ", add_to_scene)
	var json_path = ""
	if file_path_line_edit:
		json_path = file_path_line_edit.text
		
	if not FileAccess.file_exists(json_path):
		status_label.text = "Error: File not found!"
		print("DEBUG ERROR: JSON file not found at: ", json_path)
		return
	
	status_label.text = "Indexing assets..."
	await get_tree().process_frame
	_index_assets()
	
	status_label.text = "Parsing JSON..."
	await get_tree().process_frame
	
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		print("DEBUG ERROR: Failed to open file.")
		return
		
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error != OK:
		status_label.text = "JSON Parse Error: line " + str(json.get_error_line())
		print("DEBUG ERROR: JSON Parse Error")
		return
		
	var data = json.get_data()
	
	# Generate and Build the Node Hierarchy
	# This function now returns the container AND the map of created nodes
	var result = _generate_hierarchy(data)
	var root_node = result["root"]
	var nodes_by_path = result["nodes"]
	
	if add_to_scene:
		var scene_root = get_tree().get_edited_scene_root()
		if not scene_root:
			status_label.text = "Error: No active scene open to rebuild into!"
			print("DEBUG ERROR: No active scene root")
			root_node.free()
			return
			
		scene_root.add_child(root_node)
		root_node.owner = scene_root
		
		# FIX: Only set owner for nodes WE created/imported. 
		# Do NOT recurse into their children (which unpacks scenes).
		for path in nodes_by_path:
			var node = nodes_by_path[path]
			if node != root_node:
				node.owner = scene_root
		
		status_label.text = "Done! Rebuilt in current scene."
		print("DEBUG: Rebuild complete.")
	else:
		# Save as TSCN
		# For saving a branch, the root of the branch must be the owner of all children
		# Here we ONLY want to save the structure we built.
		for path in nodes_by_path:
			var node = nodes_by_path[path]
			if node != root_node:
				node.owner = root_node
		
		var packed_scene = PackedScene.new()
		var result_pack = packed_scene.pack(root_node)
		if result_pack == OK:
			var save_path = json_path.get_base_dir().path_join(json_path.get_file().get_basename() + ".tscn")
			var result_save = ResourceSaver.save(packed_scene, save_path)
			if result_save == OK:
				status_label.text = "Saved: " + save_path.get_file()
				print("DEBUG: Saved TSCN to ", save_path)
			else:
				status_label.text = "Error saving TSCN: " + str(result_save)
				print("DEBUG ERROR: ResourceSaver failed: ", result_save)
		else:
			status_label.text = "Error packing scene: " + str(result_pack)
			print("DEBUG ERROR: Scene packing failed: ", result_pack)
			
		root_node.free()

func _set_owner_recursive(node, new_owner):
	if node != new_owner:
		node.owner = new_owner
	for child in node.get_children():
		_set_owner_recursive(child, new_owner)

func _index_assets():
	asset_library.clear()
	# Scan all relevant folders for assets
	var clean_paths = ["res://objects/", "res://addons/", "res://static/", "res://levels/"]
	
	for path in clean_paths:
		if DirAccess.dir_exists_absolute(path):
			_recursive_scan(path)

	print("DEBUG: Indexed ", asset_library.size(), " assets.")

func _recursive_scan(path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_recursive_scan(path.path_join(file_name))
			else:
				if file_name.ends_with(".tscn"):
					# Store filename without extension as key
					# Note: This overwrites duplicates. First found wins.
					var key = file_name.get_basename()
					# If key already exists, we might want to prefer one path over another?
					# For now, last found wins or first found wins depending on order.
					if not asset_library.has(key):
						asset_library[key] = path.path_join(file_name)
			file_name = dir.get_next()
	else:
		# print("An error occurred when trying to access the path: " + path)
		pass

func _generate_hierarchy(data):
	# Create a container node for the import
	var container = Node3D.new()
	container.name = "Imported_" + str(Time.get_ticks_msec())
	
	# 1. Collect and Map IDs
	var items_by_id = {}
	var all_paths = {}
	
	for category in data.keys():
		var items = data[category]
		if typeof(items) == TYPE_ARRAY:
			var counter = 0
			for item in items:
				if typeof(item) != TYPE_DICTIONARY:
					counter += 1
					continue
					
				var id = item.get("id", "")
				if id == "":
					id = category + "/" + item.get("name", "Unknown_" + str(counter))
				items_by_id[id] = item
				counter += 1
				
				var current_path = id
				while current_path != "":
					all_paths[current_path] = true
					var parent_dir = current_path.get_base_dir()
					if parent_dir == current_path: break
					current_path = parent_dir
	
	# 2. Create Nodes
	var nodes_by_path = {}
	for path in all_paths.keys():
		var node = null
		if items_by_id.has(path):
			node = _create_asset_node(items_by_id[path])
		else:
			node = Node3D.new()
			node.name = path.get_file()
		nodes_by_path[path] = node
	
	# 3. Build Tree Structure
	for path in nodes_by_path.keys():
		var node = nodes_by_path[path]
		var parent_path = path.get_base_dir()
		
		if parent_path == "" or parent_path == ".":
			container.add_child(node)
		elif nodes_by_path.has(parent_path):
			nodes_by_path[parent_path].add_child(node)
		else:
			container.add_child(node)
		
	# 4. Apply Transforms (SORTED PARENT-FIRST)
	# FIX: Manually calculate Local Transforms from Global JSON data.
	# We cannot rely on 'node.global_transform' setters on orphaned nodes (returns 0/Identity).
	# So we track the global transforms ourselves as we descend the tree.
	var sorted_paths = nodes_by_path.keys()
	sorted_paths.sort_custom(func(a, b): return a.length() < b.length())
	
	var global_transform_cache = {} # path -> Transform3D
	
	for path in sorted_paths:
		var node = nodes_by_path[path]
		var item_data = items_by_id.get(path, {})
		
		# 1. Determine Target Global Transform from JSON (or Identity if folder)
		var target_global = Transform3D()
		if item_data.has("position"):
			var right = _vec3_from_dict(item_data.get("right", {"x":1, "y":0, "z":0}))
			var up = _vec3_from_dict(item_data.get("up", {"x":0, "y":1, "z":0}))
			var front = _vec3_from_dict(item_data.get("front", {"x":0, "y":0, "z":1}))
			var pos = _vec3_from_dict(item_data.get("position", {"x":0, "y":0, "z":0}))
			target_global = Transform3D(Basis(right, up, front), pos)
		else:
			# Folders/Groups usually usually implied to be at (0,0,0) global relative to parent?
			# No, if a folder is empty in JSON, it usually effectively inherits parent or is at identity.
			# But we're building GLOBAL cache.
			# If a node has no JSON data, where is it?
			# Usually 0,0,0 relative to parent.
			# So TargetGlobal = ParentGlobal * Identity = ParentGlobal.
			pass
			
		# 2. Get Parent Global Transform
		var parent_global = Transform3D()
		var parent_path = path.get_base_dir()
		if global_transform_cache.has(parent_path):
			parent_global = global_transform_cache[parent_path]
		
		# 3. Handle Missing Data Case (Folders)
		if not item_data.has("position"):
			# If no data, we assume it's simply attached to parent (Local Identity)
			target_global = parent_global
		
		# 4. Calculate Local Transform
		# Local = ParentInv * Global
		var local_transform = parent_global.affine_inverse() * target_global
		node.transform = local_transform
		
		# 5. Cache for Children
		global_transform_cache[path] = target_global
		node.set_meta("_calculated_global_transform", target_global)

	# 5. Apply Properties
	for path in nodes_by_path.keys():
		if items_by_id.has(path):
			_apply_properties(nodes_by_path[path], items_by_id[path], nodes_by_path)
			
	return {"root": container, "nodes": nodes_by_path}

func _create_asset_node(item_data):
	var asset_name = ""
	if "type" in item_data: asset_name = item_data["type"]
	elif "name" in item_data: asset_name = item_data["name"]
	
	var resource_path = _find_asset_path(asset_name)
	var node = null
	
	if resource_path != "":
		var res = load(resource_path)
		if res: node = res.instantiate()
	
	if node == null:
		node = Node3D.new()
		node.set_meta("_missing_asset_type", asset_name)
	
	# Set basic identity
	if "name" in item_data: node.name = item_data["name"]
	
	return node



func _apply_properties(node, item_data, all_nodes_map):
	for key in item_data.keys():
		if key in ["name", "type", "id", "right", "up", "front", "position"]:
			continue
			
		var raw_value = item_data[key]
		var converted_value = _convert_json_value(raw_value)
		converted_value = _resolve_references(converted_value, all_nodes_map)
		
		if key in node:
			var current_val = node.get(key)
			var target_type = typeof(current_val)
			
			if target_type == TYPE_PACKED_VECTOR2_ARRAY and (typeof(converted_value) == TYPE_ARRAY or typeof(converted_value) == TYPE_PACKED_VECTOR3_ARRAY):
				var v2_array = PackedVector2Array()
				
				# Get the reliable global transform we calculated manually
				var global_xform = Transform3D()
				if node.has_meta("_calculated_global_transform"):
					global_xform = node.get_meta("_calculated_global_transform")
				else:
					global_xform = node.global_transform # Fallback (unreliable on orphans)

				var global_inv = global_xform.affine_inverse()
				
				for item in converted_value:
					if item is Vector3:
						# Manual to_local: Local = GlobalInv * GlobalPoint
						var local_point = global_inv * item
						v2_array.append(Vector2(local_point.x, local_point.z))
					elif item is Dictionary and item.has("x") and item.has("z"):
						var world_point = Vector3(item.x, item.get("y", 0.0), item.z)
						var local_point = global_inv * world_point
						v2_array.append(Vector2(local_point.x, local_point.z))
				node.set(key, v2_array)
			
			elif target_type == TYPE_INT and typeof(converted_value) == TYPE_STRING:
				# FIX: Fuzzy Enum Matching
				var script = node.get_script()
				var handled = false
				
				if script:
					for prop in script.get_script_property_list():
						if prop.name == key and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
							if prop.hint == PROPERTY_HINT_ENUM:
								var options = prop.hint_string.split(",")
								
								# 1. Try Exact Match
								var index = options.find(converted_value)
								
								# 2. Try Fuzzy Match
								if index == -1:
									var search_key = converted_value.to_lower().replace("_", "").replace(" ", "")
									for i in range(options.size()):
										var opt_raw = options[i]
										var opt_clean = opt_raw.split(":")[0].strip_edges().to_lower().replace("_", "").replace(" ", "")
										
										if opt_clean == search_key:
											index = i
											break
									
									# Extra Debug if still failing
									if index == -1 and "VehicleType" in key:
										print("DEBUG WARN: Fuzzy match failed for '", converted_value, "' against ", options)
								
								if index != -1:
									node.set(key, index)
									handled = true
							break

				
				if not handled:
					if converted_value.is_valid_int():
						node.set(key, converted_value.to_int())
					else:
						print("Warning: Could not map string '", converted_value, "' to int property '", key, "' on ", node.name)
						# Store as meta for debugging
						node.set_meta(key, converted_value)
			else:
				node.set(key, converted_value)
		else:
			node.set_meta(key, converted_value)

func _resolve_references(value, all_nodes_map):
	if typeof(value) == TYPE_STRING:
		if all_nodes_map.has(value):
			return all_nodes_map[value]
		return value
	elif typeof(value) == TYPE_ARRAY:
		var new_array = []
		var changed = false
		for item in value:
			var resolved = _resolve_references(item, all_nodes_map)
			new_array.append(resolved)
			if resolved != item:
				changed = true
		if changed:
			return new_array
		return value
	elif typeof(value) == TYPE_DICTIONARY:
		var new_dict = {}
		for k in value.keys():
			new_dict[k] = _resolve_references(value[k], all_nodes_map)
		return new_dict
	return value

func _find_asset_path(raw_name):
	# 1. Exact match
	if asset_library.has(raw_name):
		return asset_library[raw_name]
	
	# 2. Try removing common prefixes/suffixes if needed
	var simple_name = raw_name.get_file().get_basename()
	if asset_library.has(simple_name):
		return asset_library[simple_name]
		
	return ""

func _vec3_from_dict(d):
	return Vector3(d.get("x", 0.0), d.get("y", 0.0), d.get("z", 0.0))

func _convert_json_value(value):
	# Recursively convert JSON types to Godot types
	
	if typeof(value) == TYPE_DICTIONARY:
		# Check if it looks like a Vector3
		if value.has_all(["x", "y", "z"]) and value.size() == 3:
			return Vector3(value.x, value.y, value.z)
		
		var new_dict = {}
		for k in value.keys():
			new_dict[k] = _convert_json_value(value[k])
		return new_dict
		
	elif typeof(value) == TYPE_ARRAY:
		var new_array = []
		var all_vector3 = true
		
		for item in value:
			var converted_item = _convert_json_value(item)
			new_array.append(converted_item)
			if typeof(converted_item) != TYPE_VECTOR3:
				all_vector3 = false
		
		if all_vector3 and not new_array.is_empty():
			return PackedVector3Array(new_array)
			
		return new_array
		
	else:
		return value
