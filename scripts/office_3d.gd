## Builds the 3D diorama office: walls from assets/map.json, real
## furniture from CC0 Kenney Furniture Kit models (assets/models/*.glb,
## loaded at runtime with procedural fallbacks), replicating the user's
## reference floor plan — plus the AStarGrid2D pathfinding agents use.
class_name Office3D
extends Node3D

const CELL := 1.0
const WALL_H := 3.0
const WALL_T := 0.15
const DESK_H := 0.72
const CORAL := Color(0.95, 0.45, 0.33)

var cols: int = 0
var rows: int = 0
var map_rows: Array = []
var buildings: Dictionary = {}
var astar := AStarGrid2D.new()

var _mats: Dictionary = {}
var _gltf_cache: Dictionary = {}

# repaint Kenney models into the reference's white/oak/beige palette
const TINT := {
	"chairDesk": Color(0.93, 0.92, 0.89),
	"chair": Color(0.93, 0.92, 0.89),
	"chairModernCushion": Color(0.90, 0.89, 0.86),
	"loungeChair": Color(0.80, 0.72, 0.60),
	"loungeSofa": Color(0.80, 0.72, 0.60),
	"benchCushionLow": Color(0.92, 0.91, 0.88),
	"rugRectangle": Color(0.83, 0.81, 0.77),
	"rugRound": Color(0.83, 0.81, 0.77),
}

const ROLE_ACCENT := {
	"director": Color(0.85, 0.67, 0.24),
	"researcher": Color(0.17, 0.48, 0.32),
	"writer": Color(0.84, 0.49, 0.17),
	"editor": Color(0.35, 0.86, 0.86),
	"publisher": Color(0.77, 0.24, 0.26),
}

# Extra blocked cells (furniture outside the 2x2 station anchors)
const BLOCKED_CELLS: Array = [
	# left studio wing: west counter (cells not covered by the writer anchor)
	[1, 2], [1, 5], [1, 6], [1, 7], [1, 8],
	# left studio wing: north counter
	[2, 1], [3, 1], [4, 1], [5, 1],
	# interior partition x=7 (door gap at y 6-7)
	[7, 1], [7, 2], [7, 3], [7, 4], [7, 5], [7, 8], [7, 9],
	# director office glass (door gap at 9,3)
	[8, 3], [10, 1], [10, 2],
	# meeting room: table + glass south wall (door at 13,4) + east wall
	[12, 2], [13, 2], [11, 4], [12, 4], [14, 4], [15, 4],
	[16, 1], [16, 2], [16, 3],
	# lounge seating + plants
	[17, 2], [18, 3], [19, 2], [17, 4], [19, 1], [16, 5],
	# reception L (vertical leg, faces the entrance)
	[17, 10], [17, 11],
	# work pod grid (editor's pod is covered by its anchor)
	[12, 7], [13, 7], [12, 8], [13, 8],
	[9, 10], [10, 10], [9, 11], [10, 11],
	[12, 10], [13, 10], [12, 11], [13, 11],
	# ottomans + entrance plants
	[14, 12], [19, 11],
	# focus booth (east side)
	[19, 8], [19, 9],
	# plants
	[6, 11], [19, 6],
]


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map.json"))
	assert(data is Dictionary, "assets/map.json missing — run tools/generate_assets.py")
	map_rows = data["rows"]
	buildings = data["buildings"]
	rows = map_rows.size()
	cols = str(map_rows[0]).length()
	var blocked_chars: String = str(data.get("blocked_chars", "~tdlcwWMvV"))

	astar.region = Rect2i(0, 0, cols, rows)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	for gy in rows:
		var row := str(map_rows[gy])
		for gx in cols:
			var c := row[gx]
			if blocked_chars.contains(c):
				astar.set_point_solid(Vector2i(gx, gy), true)
			_build_floor_cell(gx, gy)
			_build_wall_cell(c, gx, gy, row)

	for bname in buildings:
		var b: Dictionary = buildings[bname]
		var ax := int(b["anchor"][0])
		var ay := int(b["anchor"][1])
		for dx in 2:
			for dy in 2:
				astar.set_point_solid(Vector2i(ax + dx, ay + dy), true)
	for cell in BLOCKED_CELLS:
		astar.set_point_solid(Vector2i(int(cell[0]), int(cell[1])), true)

	_furnish()


# ------------------------------------------------------------ grid helpers

func grid_to_world(g: Vector2i) -> Vector3:
	return Vector3((g.x + 0.5) * CELL, 0.0, (g.y + 0.5) * CELL)


func center() -> Vector3:
	return Vector3(cols * CELL / 2.0, 0.0, rows * CELL / 2.0)


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
	for _i in 60:
		var g := Vector2i(randi() % cols, randi() % rows)
		if not is_blocked(g):
			return g
	return Vector2i(10, 12)


# ------------------------------------------------------------ materials/mesh

func _mat(key: String, color: Color, tex_path: String = "", emission: Color = Color.BLACK,
		transparent: bool = false, uv_scale: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if not tex_path.is_empty():
		m.albedo_texture = load(tex_path)
	m.uv1_scale = uv_scale
	m.roughness = 0.9
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.4
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D, parent: Node3D = self,
		shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------ GLB props

## Load a Kenney model, normalized: scaled so its footprint is `fit`
## metres (or, when `fit_h` > 0, so its HEIGHT is `fit_h` metres),
## grounded at y=0, centered on origin. Falls back to a box if missing.
func _prop(model: String, x: float, z: float, rot_deg: float = 0.0, fit: float = 1.0,
		y: float = 0.0, fit_h: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	root.rotation_degrees = Vector3(0, rot_deg, 0)
	add_child(root)
	var node := _instantiate_glb(model)
	if node == null:
		_box(Vector3(fit, fit * 0.8, fit * 0.8), Vector3(0, fit * 0.4, 0),
			_mat("fallback", Color(0.72, 0.5, 0.78)), root)
		return root
	var aabb := _combined_aabb(node, Transform3D.IDENTITY)
	if aabb.size.length() > 0.0001:
		var s: float
		if fit_h > 0.0:
			s = fit_h / maxf(aabb.size.y, 0.0001)
		else:
			s = fit / maxf(maxf(aabb.size.x, aabb.size.z), 0.0001)
		node.scale = Vector3.ONE * s
		node.position = Vector3(
			-(aabb.position.x + aabb.size.x / 2.0) * s,
			-aabb.position.y * s,
			-(aabb.position.z + aabb.size.z / 2.0) * s)
	if TINT.has(model):
		_tint_meshes(node, TINT[model])
	root.add_child(node)
	return root


## Repaint a model: light surfaces take the tint, dark parts become steel.
func _tint_meshes(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(i)
				if src is StandardMaterial3D:
					var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
					if m.albedo_color.v > 0.45:
						m.albedo_color = tint
					else:
						m.albedo_color = Color(0.32, 0.32, 0.35)
					mi.set_surface_override_material(i, m)
	for child in node.get_children():
		_tint_meshes(child, tint)


func _instantiate_glb(model: String) -> Node3D:
	var path := "res://assets/models/%s.glb" % model
	if not _gltf_cache.has(model):
		if not FileAccess.file_exists(path):
			push_warning("missing model: " + path)
			return null
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			push_warning("failed to parse " + path)
			return null
		_gltf_cache[model] = [doc, state]
	var pair: Array = _gltf_cache[model]
	return pair[0].generate_scene(pair[1]) as Node3D


func _combined_aabb(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var has := false
	var local_xf := xf
	if node is Node3D:
		local_xf = xf * (node as Node3D).transform
	if node is MeshInstance3D:
		result = local_xf * (node as MeshInstance3D).get_aabb()
		has = true
	for child in node.get_children():
		var sub := _combined_aabb(child, local_xf)
		if sub.size.length() > 0.0001:
			result = result.merge(sub) if has else sub
			has = true
	return result


# ------------------------------------------------------------ floor & walls

func _build_floor_cell(gx: int, gy: int) -> void:
	# left studio wing gets warm wood; everything else large light tiles.
	# A darker runner marks the circulation spine: entrance -> pod field ->
	# partition door into the studio wing.
	var tex := "deck" if (gx <= 7 and gy <= 9) else "concrete"
	if (gy == 6 and gx >= 7 and gx <= 16) or (gx == 16 and gy >= 6 and gy <= 12):
		tex = "concrete_dark"
	var m := _mat("floor_" + tex, Color.WHITE, "res://assets/textures/%s.png" % tex)
	var cx := (gx + 0.5) * CELL
	var cz := (gy + 0.5) * CELL
	_box(Vector3(CELL, 0.1, CELL), Vector3(cx, -0.05, cz), m, self, false)
	# diorama slab under the floor
	_box(Vector3(CELL, 0.42, CELL), Vector3(cx, -0.31, cz),
		_mat("slab", Color(0.55, 0.53, 0.50)), self, false)


func _build_wall_cell(c: String, gx: int, gy: int, row: String) -> void:
	var w := grid_to_world(Vector2i(gx, gy))
	match c:
		"w", "W", "M":
			_wall_segment(c, Vector3(w.x, 0, WALL_T / 2.0), true, gx, row)
		"v", "V":
			_wall_segment(c, Vector3(WALL_T / 2.0, 0, w.z), false, gx, row)
		"c":
			_wall_segment("w", Vector3(w.x, 0, WALL_T / 2.0), true, gx, row)
			_wall_segment("v", Vector3(WALL_T / 2.0, 0, w.z), false, gx, row)


func _wall_segment(kind: String, pos: Vector3, ne: bool, gx: int, row: String) -> void:
	var size := Vector3(CELL, WALL_H, WALL_T) if ne else Vector3(WALL_T, WALL_H, CELL)
	var wallmat := _mat("wall_face", Color(0.93, 0.92, 0.89))
	if kind == "w" or kind == "v" or kind == "M":
		_box(size, pos + Vector3(0, WALL_H / 2.0, 0), wallmat)
		var bb := Vector3(CELL, 0.12, 0.05) if ne else Vector3(0.05, 0.12, CELL)
		var bb_off := Vector3(0, 0.06, WALL_T / 2.0 + 0.03) if ne else Vector3(WALL_T / 2.0 + 0.03, 0.06, 0)
		_box(bb, pos + bb_off, _mat("baseboard", Color(0.72, 0.68, 0.62)), self, false)
		return
	# window segment with blinds look: sill + lintel + glass + mullion
	var sill_size := Vector3(CELL, 0.9, WALL_T) if ne else Vector3(WALL_T, 0.9, CELL)
	var lintel_size := Vector3(CELL, 0.6, WALL_T) if ne else Vector3(WALL_T, 0.6, CELL)
	var glass_size := Vector3(CELL, 1.5, 0.05) if ne else Vector3(0.05, 1.5, CELL)
	var mull_size := Vector3(0.06, 1.5, WALL_T) if ne else Vector3(WALL_T, 1.5, 0.06)
	_box(sill_size, pos + Vector3(0, 0.45, 0), wallmat)
	_box(lintel_size, pos + Vector3(0, 2.7, 0), wallmat)
	var glass := _mat("glass", Color(0.78, 0.88, 0.95, 0.35), "", Color.BLACK, true)
	_box(glass_size, pos + Vector3(0, 1.65, 0), glass, self, false)
	_box(mull_size, pos + Vector3(0, 1.65, 0), _mat("steel", Color(0.42, 0.42, 0.46)))
	# venetian blinds over the top half of the glass
	for i in 5:
		var slat := Vector3(CELL - 0.12, 0.035, 0.02) if ne else Vector3(0.02, 0.035, CELL - 0.12)
		var slat_off := Vector3(0, 2.32 - i * 0.13, WALL_T / 2.0 + 0.03) if ne else Vector3(WALL_T / 2.0 + 0.03, 2.32 - i * 0.13, 0)
		_box(slat, pos + slat_off, _mat("blind", Color(0.90, 0.90, 0.88)), self, false)


func _mural_run_index(row: String, gx: int) -> int:
	var i := 0
	while gx - i - 1 >= 0 and row[gx - i - 1] == "M":
		i += 1
	return i


# ------------------------------------------------------------ furnishing
# Layout replicated from the user's reference floor plan: left studio wing
# (wood floor, built-in counters, wall shelves), glass director office and
# glass meeting room under the windows, lounge with armchairs and notice
# board on the right, an L-shaped reception counter, and two double-desk
# work pods on the open tile floor.

func _furnish() -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	var glass := _mat("podglass", Color(0.75, 0.86, 0.94, 0.25), "", Color.BLACK, true)
	var white := _mat("counter_white", Color(0.94, 0.93, 0.90))
	var oak := _mat("oak", Color.WHITE, "res://assets/textures/deck.png")
	var wallwhite := _mat("wall_white", Color(0.92, 0.91, 0.88))
	var spine_cols := [Color(0.77, 0.30, 0.30), Color(0.30, 0.48, 0.68), Color(0.86, 0.70, 0.34),
		Color(0.36, 0.60, 0.44), Color(0.55, 0.42, 0.62), Color(0.88, 0.86, 0.82)]

	# ============ LEFT STUDIO WING (wood floor) ============
	# built-in counter along the west wall (cells 1,2..8)
	_box(Vector3(0.75, 0.70, 7.0), Vector3(0.85, 0.35, 5.5), white)
	_box(Vector3(0.85, 0.05, 7.1), Vector3(0.88, 0.74, 5.5), _mat("countertop", Color(0.97, 0.96, 0.94)), self, false)
	for wz in [3.0, 5.0, 7.0]:
		_prop("computerScreen", 0.85, wz, 90, 1.0, 0.77, 0.38)
		_prop("computerKeyboard", 1.15, wz, 90, 0.28, 0.77)
		_prop("chairDesk", 1.9, wz + 0.25, 250 + randf_range(-20.0, 20.0), 1.0, 0.0, 1.0)
	# counter along the north wall (cells 2..5,1)
	_box(Vector3(4.0, 0.70, 0.75), Vector3(4.0, 0.35, 0.85), white)
	_box(Vector3(4.1, 0.05, 0.85), Vector3(4.0, 0.74, 0.88), _mat("countertop", Color(0.97, 0.96, 0.94)), self, false)
	for wx in [3.0, 5.0]:
		_prop("computerScreen", wx, 0.85, 180, 1.0, 0.77, 0.38)
		_prop("computerKeyboard", wx, 1.15, 180, 0.28, 0.77)
		_prop("chairDesk", wx - 0.2, 1.9, 10 + randf_range(-15.0, 15.0), 1.0, 0.0, 1.0)
	# wall shelves with binders/books (west + north walls)
	for sy in [1.65, 2.15]:
		_box(Vector3(0.28, 0.05, 6.4), Vector3(0.35, sy, 5.2), wallwhite, self, false)
		for i in 14:
			var col: Color = spine_cols[(i * 7 + int(sy * 10)) % spine_cols.size()]
			_box(Vector3(0.2, 0.34, 0.10), Vector3(0.36, sy + 0.20, 2.25 + i * 0.42),
				_mat("spine_%d_%d" % [i % 6, int(sy)], col), self, false)
		_box(Vector3(4.0, 0.05, 0.28), Vector3(4.0, sy, 0.35), wallwhite, self, false)
		for i in 9:
			var col2: Color = spine_cols[(i * 5 + int(sy * 10) + 2) % spine_cols.size()]
			_box(Vector3(0.10, 0.34, 0.2), Vector3(2.25 + i * 0.42, sy + 0.20, 0.36),
				_mat("spine_n%d_%d" % [i % 6, int(sy)], col2), self, false)

	# researcher's freestanding desk (center of the wing)
	_prop("desk", 4.0, 6.0, 180, 1.0, 0.0, 0.74)
	_prop("computerScreen", 4.0, 5.85, 0, 1.0, DESK_H, 0.40)
	_prop("computerKeyboard", 4.0, 6.18, 0, 0.28, DESK_H)
	_prop("chairDesk", 4.25, 6.9, 175, 1.0, 0.0, 1.0)
	_prop("plantSmall2", 4.6, 5.8, 0, 1.0, DESK_H, 0.24)

	# interior partition x=7 (white, wood door frame at the gap y 6..8)
	for pz in [1, 2, 3, 4, 5, 8, 9]:
		_box(Vector3(0.14, 2.4, 1.0), Vector3(7.5, 1.2, pz + 0.5), wallwhite)
	_box(Vector3(0.20, 2.5, 0.12), Vector3(7.5, 1.25, 5.95), oak)
	_box(Vector3(0.20, 2.5, 0.12), Vector3(7.5, 1.25, 8.05), oak)
	_box(Vector3(0.20, 0.12, 2.2), Vector3(7.5, 2.44, 7.0), oak)
	# posters/boards on the partition's east face
	var poster_cols := [Color(0.90, 0.88, 0.84), Color(0.80, 0.85, 0.88), Color(0.92, 0.84, 0.72)]
	for i in 3:
		_box(Vector3(0.03, 0.55, 0.42), Vector3(7.60, 1.65, 1.8 + i * 1.1),
			_mat("poster_%d" % i, poster_cols[i]), self, false)

	# ============ DIRECTOR'S GLASS OFFICE (x8..10, y1..3) ============
	_box(Vector3(1.0, 2.0, 0.07), Vector3(8.5, 1.0, 3.5), glass, self, false)
	_box(Vector3(0.07, 2.0, 1.0), Vector3(10.5, 1.0, 1.5), glass, self, false)
	_box(Vector3(0.07, 2.0, 1.0), Vector3(10.5, 1.0, 2.5), glass, self, false)
	for post in [[9.0, 3.5], [10.5, 3.0], [10.5, 0.6]]:
		_box(Vector3(0.09, 2.05, 0.09), Vector3(post[0], 1.02, post[1]), steel)
	_prop("rugRectangle", 9.3, 2.0, 90, 1.7)
	_prop("desk", 8.9, 1.8, 90, 1.0, 0.0, 0.74)
	_prop("computerScreen", 8.85, 1.8, 90, 1.0, DESK_H, 0.40)
	_prop("chairDesk", 9.7, 1.9, 265, 1.0, 0.0, 1.0)
	_prop("bookcaseOpen", 8.45, 2.7, 90, 1.0, 0.0, 1.5)
	_prop("plantSmall1", 8.9, 1.35, 0, 1.0, DESK_H, 0.24)

	# ============ GLASS MEETING ROOM (x11..15, y1..4) ============
	for gz in [[11.5, 4.5], [12.5, 4.5], [14.5, 4.5], [15.5, 4.5]]:
		_box(Vector3(1.0, 2.0, 0.07), Vector3(gz[0], 1.0, gz[1]), glass, self, false)
	for post2 in [[11.0, 4.5], [13.0, 4.5], [14.0, 4.5], [16.0, 4.5]]:
		_box(Vector3(0.09, 2.05, 0.09), Vector3(post2[0], 1.02, post2[1]), steel)
	# east dividing wall to the lounge
	for wz2 in [1, 2, 3]:
		_box(Vector3(0.14, 2.4, 1.0), Vector3(16.5, 1.2, wz2 + 0.5), wallwhite)
	_prop("tableRound", 13.0, 2.4, 0, 1.0, 0.0, 0.74)
	_prop("chair", 13.0, 1.35, 180, 1.0, 0.0, 0.9)
	_prop("chair", 13.0, 3.5, 0, 1.0, 0.0, 0.9)
	_prop("chair", 11.9, 2.4, 90, 1.0, 0.0, 0.9)
	_prop("chair", 14.1, 2.4, 270, 1.0, 0.0, 0.9)
	_prop("laptop", 13.15, 2.35, 210, 0.32, DESK_H)
	# picture on the wall behind
	_box(Vector3(0.9, 0.6, 0.04), Vector3(13.0, 2.05, 0.21), _mat("meet_art", CORAL), self, false)

	# ============ LOUNGE (right wing) ============
	# big framed notice board on the north wall
	_box(Vector3(2.5, 1.35, 0.05), Vector3(18.1, 2.05, 0.21), wallwhite, self, false)
	_box(Vector3(2.34, 1.2, 0.04), Vector3(18.1, 2.05, 0.235), _mat("board_bg", Color(0.80, 0.80, 0.78)), self, false)
	for r in 2:
		for cn in 4:
			_box(Vector3(0.34, 0.44, 0.02), Vector3(17.25 + cn * 0.56, 2.32 - r * 0.55, 0.25),
				_mat("board_doc", Color(0.96, 0.96, 0.94)), self, false)
	_prop("loungeChair", 17.4, 2.3, 140, 1.0, 0.0, 0.8)
	_prop("loungeChair", 18.7, 3.4, 320, 1.0, 0.0, 0.8)
	_prop("chairModernCushion", 19.0, 1.9, 215, 1.0, 0.0, 0.85)
	_prop("chairModernCushion", 17.2, 3.6, 35, 1.0, 0.0, 0.85)
	_prop("sideTable", 18.1, 2.8, 0, 1.0, 0.0, 0.48)
	_prop("sideTable", 17.9, 1.6, 0, 1.0, 0.0, 0.48)
	_prop("pottedPlant", 19.4, 1.3, 0, 1.0, 0.0, 1.2)
	_prop("pottedPlant", 16.5, 5.4, 0, 1.0, 0.0, 1.2)

	# ============ RECEPTION (faces the entrance, south-east) ============
	_box(Vector3(2.0, 0.95, 0.85), Vector3(16.0, 0.475, 10.55), oak)
	_box(Vector3(2.1, 0.06, 0.95), Vector3(16.0, 1.0, 10.55), white, self, false)
	_box(Vector3(0.85, 0.95, 1.15), Vector3(17.55, 0.475, 11.4), oak)
	_box(Vector3(0.95, 0.06, 1.25), Vector3(17.55, 1.0, 11.4), white, self, false)
	_prop("computerScreen", 15.7, 10.55, 180, 1.0, 1.03, 0.36)
	_prop("chairDesk", 16.2, 9.7, 170, 1.0, 0.0, 1.05)
	_prop("plantSmall3", 16.9, 10.55, 0, 1.0, 1.03, 0.26)
	_pendant(Vector3(16.0, 2.5, 10.9))

	# ============ ENTRANCE (south-east corner) ============
	var mat_prop := _prop("rugDoormat", 18.4, 12.4, 90, 1.4)
	_tint_meshes(mat_prop, CORAL)
	_prop("pottedPlant", 19.45, 11.4, 0, 1.0, 0.0, 1.2)

	# ============ WORK POD GRID (2 x 2, strict rhythm) ============
	var pods := [[9.0, 7.5, true], [12.0, 7.5, false], [9.0, 10.5, false], [12.0, 10.5, false]]
	for pod in pods:
		var px: float = pod[0]
		var pz: float = pod[1]
		var is_editor: bool = pod[2]
		_prop("desk", px + 0.5, pz - 0.45, 0, 1.0, 0.0, 0.74)
		_prop("desk", px + 0.5, pz + 0.45, 180, 1.0, 0.0, 0.74)
		_prop("computerScreen", px + 0.3, pz - 0.28, 0, 1.0, DESK_H + 0.18, 0.38)
		_prop("computerScreen", px + 0.85, pz - 0.28, 5, 1.0, DESK_H + 0.18, 0.38)
		_prop("computerScreen", px + 0.3, pz + 0.28, 180, 1.0, DESK_H + 0.18, 0.38)
		_prop("computerScreen", px + 0.85, pz + 0.28, 175, 1.0, DESK_H + 0.18, 0.38)
		_prop("computerKeyboard", px + 0.32, pz - 0.62, 0, 0.28, DESK_H)
		_prop("computerKeyboard", px + 0.32, pz + 0.62, 180, 0.28, DESK_H)
		_prop("chairDesk", px + 0.5, pz - 1.25, 5 + randf_range(-15.0, 15.0), 1.0, 0.0, 1.0)
		_prop("chairDesk", px + 0.5, pz + 1.25, 185 + randf_range(-15.0, 15.0), 1.0, 0.0, 1.0)
		var divider_mat := _mat("pod_divider", Color(0.90, 0.89, 0.86))
		_box(Vector3(2.0, 0.9, 0.06), Vector3(px + 0.5, 0.75, pz), divider_mat)
		_box(Vector3(2.0, 0.05, 0.09), Vector3(px + 0.5, 1.22, pz),
			_mat("trim_coral", CORAL, "", CORAL * 0.4), self, false)
		if is_editor:
			_box(Vector3(0.3, 0.05, 0.10), Vector3(px + 0.5, 1.26, pz),
				_mat("trim_editor", ROLE_ACCENT["editor"], "", ROLE_ACCENT["editor"] * 0.5), self, false)
		# monitor arms: slim steel poles lifting the screens off the desk
		var steel2 := _mat("steel", Color(0.42, 0.42, 0.46))
		for arm in [[px + 0.3, pz - 0.28], [px + 0.85, pz - 0.28], [px + 0.3, pz + 0.28], [px + 0.85, pz + 0.28]]:
			_box(Vector3(0.03, 0.22, 0.03), Vector3(arm[0], DESK_H + 0.11, arm[1]), steel2, self, false)
		# task lamps, one per side
		_prop("lampSquareTable", px - 0.35, pz - 0.55, 20, 1.0, DESK_H, 0.28)
		_prop("lampSquareTable", px + 1.35, pz + 0.55, 200, 1.0, DESK_H, 0.28)
	# ottomans by the pod field
	_prop("benchCushionLow", 14.4, 12.3, 20, 1.0, 0.0, 0.42)
	_prop("benchCushionLow", 14.9, 12.7, -10, 1.0, 0.0, 0.42)

	# ============ layered light: pendants over shared zones ============
	_pendant(Vector3(13.0, 2.5, 2.4))
	_pendant(Vector3(18.1, 2.5, 2.8))

	# ============ plants ============
	_prop("pottedPlant", 6.4, 11.3, 0, 1.0, 0.0, 1.2)
	_prop("pottedPlant", 19.4, 6.3, 0, 1.0, 0.0, 1.2)
	_prop("plantSmall1", 5.5, 10.5, 0, 1.0, 0.0, 0.5)

	# ============ FOCUS BOOTH (east edge — prospect & refuge) ============
	var booth := _mat("booth_shell", Color(0.27, 0.27, 0.30))
	_box(Vector3(1.05, 0.05, 2.05), Vector3(19.5, 0.025, 9.0), booth, self, false)
	_box(Vector3(1.0, 2.15, 0.08), Vector3(19.5, 1.08, 8.05), booth)
	_box(Vector3(0.08, 2.15, 2.0), Vector3(19.95, 1.08, 9.0), booth)
	_box(Vector3(0.08, 2.15, 2.0), Vector3(19.05, 1.08, 9.0), booth)
	# glass front faces south (toward the camera) so the interior reads
	_box(Vector3(0.9, 2.0, 0.05), Vector3(19.5, 1.0, 9.95),
		_mat("podglass", Color(0.75, 0.86, 0.94, 0.25), "", Color.BLACK, true), self, false)
	_box(Vector3(1.05, 0.08, 2.05), Vector3(19.5, 2.2, 9.0), booth)
	_box(Vector3(0.9, 0.05, 0.06), Vector3(19.5, 2.12, 9.93),
		_mat("trim_coral", CORAL, "", CORAL * 0.4), self, false)
	_box(Vector3(0.45, 0.05, 0.4), Vector3(19.6, 0.72, 8.45), _mat("counter_white", Color(0.94, 0.93, 0.90)), self)
	_prop("laptop", 19.6, 8.45, 200, 0.3, 0.75)
	_prop("chairModernCushion", 19.5, 9.2, 350, 1.0, 0.0, 0.85)
	var booth_light := OmniLight3D.new()
	booth_light.position = Vector3(19.5, 1.9, 9.0)
	booth_light.light_color = Color(1.0, 0.9, 0.72)
	booth_light.omni_range = 1.8
	booth_light.light_energy = 1.2
	add_child(booth_light)

	# ============ GREEN COURTYARD (landscape) ============
	_box(Vector3(70.0, 0.06, 70.0), Vector3(10.0, -0.58, 7.0),
		_mat("grass", Color(0.55, 0.66, 0.42)), self, false)
	# stone walkway from the entrance
	for i in 4:
		_box(Vector3(0.9, 0.08, 0.6), Vector3(18.4 + (0.15 if i % 2 == 1 else -0.15), -0.51, 14.4 + i * 0.9),
			_mat("stone_step", Color(0.78, 0.77, 0.74)), self, false)
	# trees outside the north and west walls (green through every window)
	for tx in [2.5, 6.0, 10.5, 14.0, 17.5]:
		_tree(Vector3(tx, -0.55, -1.6), randf_range(0.9, 1.25))
	for tz in [3.0, 7.0, 11.0]:
		_tree(Vector3(-1.7, -0.55, tz), randf_range(0.9, 1.2))
	_tree(Vector3(21.8, -0.55, 3.5), 1.1)
	_tree(Vector3(16.5, -0.55, 16.2), 1.3)
	_tree(Vector3(21.5, -0.55, 13.5), 0.95)
	# bushes hugging the walls
	for bz in [[1.2, -0.9], [8.0, -0.9], [15.5, -0.9], [-0.9, 9.5], [-0.9, 12.5], [20.8, 6.0]]:
		_bush(Vector3(bz[0], -0.55, bz[1]))
	# pond with stone edge (south-east of the courtyard)
	var pond := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 1.5
	pcyl.bottom_radius = 1.5
	pcyl.height = 0.06
	pond.mesh = pcyl
	var pmat := _mat("pond", Color(0.47, 0.67, 0.76))
	pmat.roughness = 0.15
	pond.material_override = pmat
	pond.position = Vector3(13.8, -0.52, 16.0)
	add_child(pond)
	for i in 9:
		var ang := i * TAU / 9.0
		var r := 1.55 + randf_range(0.0, 0.15)
		_bush_stone(Vector3(13.8 + cos(ang) * r, -0.53, 16.0 + sin(ang) * r))


## A simple low-poly tree: trunk + two foliage spheres.
func _tree(base: Vector3, s: float) -> void:
	var trunk := MeshInstance3D.new()
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.07 * s
	tcyl.bottom_radius = 0.1 * s
	tcyl.height = 1.0 * s
	trunk.mesh = tcyl
	trunk.material_override = _mat("trunk", Color(0.45, 0.34, 0.26))
	trunk.position = base + Vector3(0, 0.5 * s, 0)
	add_child(trunk)
	_leaf_ball(base + Vector3(0, 1.25 * s, 0), 0.62 * s, "leafA", Color(0.42, 0.58, 0.36))
	_leaf_ball(base + Vector3(0.18 * s, 1.7 * s, 0.1 * s), 0.42 * s, "leafB", Color(0.48, 0.64, 0.40))


func _bush(base: Vector3) -> void:
	_leaf_ball(base + Vector3(0, 0.22, 0), 0.3, "leafA", Color(0.42, 0.58, 0.36))
	_leaf_ball(base + Vector3(0.25, 0.16, 0.1), 0.22, "leafB", Color(0.48, 0.64, 0.40))


func _bush_stone(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = randf_range(0.08, 0.14)
	sph.height = sph.radius * 1.4
	sph.radial_segments = 8
	sph.rings = 4
	mi.mesh = sph
	mi.material_override = _mat("stone", Color(0.72, 0.71, 0.68))
	mi.position = pos
	add_child(mi)


func _leaf_ball(pos: Vector3, r: float, key: String, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = r
	sph.height = r * 1.8
	sph.radial_segments = 10
	sph.rings = 5
	mi.mesh = sph
	mi.material_override = _mat(key, col)
	mi.position = pos
	add_child(mi)


## A small pendant lamp with a warm light pool — layered lighting.
func _pendant(pos: Vector3) -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	_box(Vector3(0.03, 3.0 - pos.y - 0.12, 0.03), Vector3(pos.x, (3.0 + pos.y) / 2.0, pos.z), steel, self, false)
	var shade := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.16
	cyl.height = 0.16
	shade.mesh = cyl
	shade.material_override = _mat("pendant_shade", Color(0.30, 0.30, 0.33))
	shade.position = pos
	add_child(shade)
	var bulb := _mat("pendant_bulb", Color(1.0, 0.9, 0.7) * 0.8, "", Color(1.0, 0.88, 0.65))
	_box(Vector3(0.07, 0.04, 0.07), pos + Vector3(0, -0.09, 0), bulb, self, false)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.2, 0)
	light.light_color = Color(1.0, 0.9, 0.72)
	light.omni_range = 3.0
	light.light_energy = 1.4
	light.shadow_enabled = false
	add_child(light)
