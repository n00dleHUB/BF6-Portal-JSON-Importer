@tool
extends EditorPlugin

var dock

func _enter_tree():
	var base_dir = get_script().get_path().get_base_dir()
	dock = load(base_dir.path_join("import_dock.tscn")).instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
