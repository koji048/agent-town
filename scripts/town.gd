## Builds the isometric studio campus from assets/map.json:
## ground tiles, rooms, props, pathfinding grid, and a y-sorted world
## layer that agents live in.
class_name Town
extends Node2D

var tile_w: int = 64
var tile_h: int = 32
var cols: int = 0
var rows: int = 0
var map_rows: Array = []
var buildings: Dictionary = {}
var world: Node2D
var astar := AStarGrid2D.new()

var _bounds_min := Vector2(1e9, 1e9)
var _bounds_max := Vector2(-1e9, -1e9)
var _garden_sprites: Array[Sprite2D] = []
var _garden_tex: Array[Texture2D] = []
var _garden_frame := 0


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map.json"))
	assert(data is Dictionary, "assets/map.json missing — run tools/generate_assets.py")
	tile_w = int(data["tile_w"])
	tile_h = int(data["tile_h"])
	map_rows = data["rows"]
	buildings = data["buildings"]
	rows = map_rows.size()
	cols = str(map_rows[0]).length()
	var blocked_chars: String = str(data.get("blocked_chars", "~tdl"))

	var ground := Node2D.new()
	ground.name = "Ground"
	add_child(ground)
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	_garden_tex = [load("res://assets/tiles/garden_0.png"), load("res://assets/tiles/garden_1.png")]
	var tile_tex := {
		".": load("res://assets/tiles/floor.png"),
		",": load("res://assets/tiles/floor_dark.png"),
		"#": load("res://assets/tiles/deck.png"),
		"P": load("res://assets/tiles/atrium.png"),
	}
	var floor_tex: Texture2D = tile_tex["."]

	# --- pathfinding grid
	astar.region = Rect2i(0, 0, cols, rows)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	# --- ground + props
	for gy in rows:
		var row := str(map_rows[gy])
		for gx in cols:
			var c := row[gx]
			var center := tile_center(Vector2i(gx, gy))
			_bounds_min = _bounds_min.min(center)
			_bounds_max = _bounds_max.max(center)
			var spr := Sprite2D.new()
			if c == "~":
				spr.texture = _garden_tex[0]
				_garden_sprites.append(spr)
			else:
				spr.texture = tile_tex.get(c, floor_tex)
			spr.position = center
			ground.add_child(spr)
			if blocked_chars.contains(c):
				astar.set_point_solid(Vector2i(gx, gy), true)
			match c:
				"t":
					_prop("res://assets/props/plant.png" if (gx + gy) % 2 == 1 else "res://assets/props/plant_dark.png", center)
				"l":
					_prop("res://assets/props/lamp.png", center)
				"d":
					_prop("res://assets/props/desk.png", center)

	# --- rooms
	for bname in buildings:
		var b: Dictionary = buildings[bname]
		var ax := int(b["anchor"][0])
		var ay := int(b["anchor"][1])
		for dx in 2:
			for dy in 2:
				astar.set_point_solid(Vector2i(ax + dx, ay + dy), true)
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/buildings/%s.png" % bname)
		var px := (ax - ay) * tile_w / 2.0
		var pyb := (ax + ay + 4) * tile_h / 2.0
		spr.position = Vector2(px, pyb - 4.0)
		spr.offset = Vector2(0, -spr.texture.get_height() / 2.0 + 4.0)
		world.add_child(spr)

	# --- courtyard shimmer
	var t := Timer.new()
	t.wait_time = 0.7
	t.timeout.connect(_animate_garden)
	add_child(t)
	t.start()


func tile_center(g: Vector2i) -> Vector2:
	return Vector2((g.x - g.y) * tile_w / 2.0, (g.x + g.y) * tile_h / 2.0 + tile_h / 2.0)


func is_blocked(g: Vector2i) -> bool:
	return not astar.is_in_boundsv(g) or astar.is_point_solid(g)


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if is_blocked(from) or is_blocked(to):
		return []
	return astar.get_id_path(from, to)


func workstation(role: String) -> Vector2i:
	for bname in buildings:
		var b: Dictionary = buildings[bname]
		if str(b["role"]) == role:
			return Vector2i(int(b["workstation"][0]), int(b["workstation"][1]))
	return Vector2i.ZERO


func random_walkable() -> Vector2i:
	for _i in 40:
		var g := Vector2i(randi() % cols, randi() % rows)
		if not is_blocked(g):
			return g
	return Vector2i(9, 8)


func center() -> Vector2:
	return (_bounds_min + _bounds_max) / 2.0


func _prop(path: String, tile_pos: Vector2) -> void:
	var spr := Sprite2D.new()
	spr.texture = load(path)
	spr.position = tile_pos
	spr.offset = Vector2(0, -spr.texture.get_height() / 2.0 + 6.0)
	world.add_child(spr)


func _animate_garden() -> void:
	_garden_frame = (_garden_frame + 1) % 2
	for spr in _garden_sprites:
		spr.texture = _garden_tex[_garden_frame]
