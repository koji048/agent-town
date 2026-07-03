## Headless validation used by CI (and locally):
##   godot --headless --path . -s res://tools/ci_check.gd
## Loads every script, the main scene, the map and key assets.
## Exits non-zero on any failure.
extends SceneTree


func _init() -> void:
	var errors: int = 0

	for path in _find_files("res://scripts", "gd"):
		var script: Variant = load(path)
		if script == null:
			push_error("FAILED to load script: " + path)
			errors += 1
		else:
			print("ok script  ", path)

	var scene: Variant = load("res://scenes/main.tscn")
	if scene == null:
		push_error("FAILED to load main.tscn")
		errors += 1
	else:
		print("ok scene   res://scenes/main.tscn")

	var map: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map.json"))
	if not (map is Dictionary and map.has("rows") and map.has("buildings")):
		push_error("FAILED map.json invalid — run tools/generate_assets.py")
		errors += 1
	else:
		print("ok map     %d buildings" % (map["buildings"] as Dictionary).size())
		for bname in map["buildings"]:
			if load("res://assets/buildings/%s.png" % bname) == null:
				push_error("FAILED missing building sprite: " + str(bname))
				errors += 1
	for role in ["director", "researcher", "writer", "editor", "publisher"]:
		if load("res://assets/characters/%s.png" % role) == null:
			push_error("FAILED missing character sheet: " + role)
			errors += 1

	if errors > 0:
		push_error("%d validation error(s)" % errors)
		quit(1)
	else:
		print("all checks passed")
		quit(0)


func _find_files(dir_path: String, ext: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		var full := dir_path.path_join(fname)
		if dir.current_is_dir():
			found.append_array(_find_files(full, ext))
		elif fname.get_extension() == ext:
			found.append(full)
		fname = dir.get_next()
	dir.list_dir_end()
	return found
