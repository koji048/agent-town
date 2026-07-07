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

# Extra blocked cells (furniture + courtyard region; station anchors add
# their own 2x2 blocks)
const BLOCKED_CELLS: Array = [
	# director glass office walls (door gap at 2,3)
	[3, 1], [3, 2], [1, 3],
	# meeting nook table
	[5, 1], [6, 1],
	# production row storage (east end)
	[9, 5], [9, 6],
	# coffee bar + fridge + seats
	[1, 10], [1, 11], [1, 12], [4, 10], [4, 11], [4, 12],
	# publishing dept: storage, copier, ring light, window bench
	[18, 1], [19, 1], [19, 2], [16, 2], [13, 6], [14, 6], [15, 6],
	# interior plants
	[10, 1], [10, 12], [12, 5],
	# town hall: stage strip + speakers (x1), bleacher tiers (x6..8), beanbags
	[1, 14], [1, 15], [1, 16], [1, 17], [1, 18],
	[6, 15], [6, 16], [6, 17], [7, 15], [7, 16], [7, 17], [8, 15], [8, 16], [8, 17],
	[10, 14], [10, 18],
]

## Gathering spots on the town-hall floor (agents celebrate here).
const TOWNHALL_SPOTS: Array = [
	Vector2i(3, 16), Vector2i(4, 15), Vector2i(4, 17), Vector2i(5, 16), Vector2i(3, 14),
]

# Courtyard region (the L-notch garden) — outdoor scenery, not walkable
const COURTYARD := Rect2i(12, 7, 8, 12)


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
	for cx in range(COURTYARD.position.x, COURTYARD.end.x):
		for cy in range(COURTYARD.position.y, COURTYARD.end.y):
			astar.set_point_solid(Vector2i(cx, cy), true)

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
	# L-shape: courtyard notch is grass; north wing warm wood; the
	# production row sits on carpet; runners mark the circulation spine.
	if COURTYARD.has_point(Vector2i(gx, gy)):
		var gmat := _mat("grass", Color(0.55, 0.66, 0.42))
		_box(Vector3(CELL, 0.1, CELL), Vector3((gx + 0.5) * CELL, -0.05, (gy + 0.5) * CELL), gmat, self, false)
		_box(Vector3(CELL, 0.42, CELL), Vector3((gx + 0.5) * CELL, -0.31, (gy + 0.5) * CELL),
			_mat("slab", Color(0.55, 0.53, 0.50)), self, false)
		return
	var tex := "concrete"
	if gy <= 6 and gx >= 12:
		tex = "deck"
	elif gy >= 14:
		tex = "deck"          # town hall: warm wood agora
	elif gy >= 5 and gy <= 7 and gx <= 9:
		tex = "carpet"
	if (gy == 8 and gx >= 3 and gx <= 11) or (gx == 11 and gy >= 3 and gy <= 8):
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
# L-shaped building wrapping a garden courtyard (owner interview):
# west wing = director's glass office, meeting nook, a right-sized
# production row (Research / Write / Edit), coffee bar (the one social
# anchor); north wing = publishing department with storage, mission board
# and a window bench over the garden. The courtyard notch (SE) holds the
# pond, stone path and trees, visible from both wings.

func _furnish() -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	var glass := _mat("podglass", Color(0.75, 0.86, 0.94, 0.25), "", Color.BLACK, true)
	var white := _mat("counter_white", Color(0.94, 0.93, 0.90))
	var oak := _mat("oak", Color.WHITE, "res://assets/textures/deck.png")
	var wallwhite := _mat("wall_white", Color(0.92, 0.91, 0.88))
	var spine_cols := [Color(0.77, 0.30, 0.30), Color(0.30, 0.48, 0.68), Color(0.86, 0.70, 0.34),
		Color(0.36, 0.60, 0.44), Color(0.55, 0.42, 0.62), Color(0.88, 0.86, 0.82)]

	# ============ DIRECTOR'S GLASS OFFICE (west wing, NW corner) ============
	_box(Vector3(0.07, 2.0, 1.0), Vector3(3.5, 1.0, 1.5), glass, self, false)
	_box(Vector3(0.07, 2.0, 1.0), Vector3(3.5, 1.0, 2.5), glass, self, false)
	_box(Vector3(1.0, 2.0, 0.07), Vector3(1.5, 1.0, 3.5), glass, self, false)
	for post in [[3.5, 3.0], [3.5, 0.6], [1.0, 3.5]]:
		_box(Vector3(0.09, 2.05, 0.09), Vector3(post[0], 1.02, post[1]), steel)
	_prop("rugRectangle", 2.0, 2.0, 0, 2.0)
	_prop("deskCorner", 1.6, 1.6, 180, 1.0, 0.0, 0.74)
	_prop("computerScreen", 1.4, 1.7, 155, 1.0, DESK_H, 0.40)
	_prop("computerKeyboard", 1.8, 1.95, 155, 0.3, DESK_H)
	_prop("chairDesk", 2.4, 2.4, 210, 1.0, 0.0, 1.0)
	_prop("plantSmall2", 2.8, 1.35, 0, 1.0, DESK_H, 0.26)
	_pendant(Vector3(2.2, 2.4, 2.0))

	# ============ MEETING NOOK (right-sized: table + three chairs) ============
	_prop("tableRound", 5.8, 1.6, 0, 1.0, 0.0, 0.72)
	_prop("chair", 5.8, 0.85, 180, 1.0, 0.0, 0.9)
	_prop("chair", 5.0, 1.9, 110, 1.0, 0.0, 0.9)
	_prop("chair", 6.6, 1.9, 250, 1.0, 0.0, 0.9)
	_prop("laptop", 5.9, 1.55, 210, 0.3, DESK_H)
	_box(Vector3(0.9, 0.6, 0.04), Vector3(5.8, 2.05, 0.21), _mat("meet_art", CORAL), self, false)
	_pendant(Vector3(5.8, 2.4, 1.6))

	# ============ PRODUCTION ROW (Research / Write / Edit) ============
	var stations := [["researcher", 1.0], ["writer", 4.0], ["editor", 7.0]]
	for st in stations:
		var role: String = st[0]
		var sx: float = st[1]
		# divider behind the desk with coral trim + role chip
		_box(Vector3(1.95, 1.25, 0.07), Vector3(sx + 1.0, 0.72, 5.45), _mat("partition", Color(0.93, 0.92, 0.89)))
		_box(Vector3(1.95, 0.06, 0.10), Vector3(sx + 1.0, 1.38, 5.45),
			_mat("trim_coral", CORAL, "", CORAL * 0.4), self, false)
		_box(Vector3(0.3, 0.06, 0.11), Vector3(sx + 1.0, 1.44, 5.45),
			_mat("chip_" + role, ROLE_ACCENT[role], "", (ROLE_ACCENT[role] as Color) * 0.5), self, false)
		_prop("desk", sx + 1.0, 6.0, 180, 1.0, 0.0, 0.74)
		_prop("computerScreen", sx + 0.75, 5.9, 0, 1.0, DESK_H + 0.18, 0.38)
		_prop("computerScreen", sx + 1.3, 5.9, 5, 1.0, DESK_H + 0.18, 0.38)
		for arm in [[sx + 0.75, 5.9], [sx + 1.3, 5.9]]:
			_box(Vector3(0.03, 0.22, 0.03), Vector3(arm[0], DESK_H + 0.11, arm[1]), steel, self, false)
		_prop("computerKeyboard", sx + 0.8, 6.2, 180, 0.28, DESK_H)
		_prop("lampSquareTable", sx + 1.6, 5.85, 200, 1.0, DESK_H, 0.26)
		_prop("chairDesk", sx + 1.0, 6.9, 175 + randf_range(-15.0, 15.0), 1.0, 0.0, 1.0)
		_prop("trashcan", sx + 0.25, 6.85, 0, 1.0, 0.0, 0.35)
	# shared low storage closing the row (east end)
	_prop("bookcaseOpenLow", 9.6, 5.9, 90, 1.0, 0.0, 0.62)
	_prop("books", 9.6, 5.7, 15, 0.28, 0.64)
	_prop("books", 9.6, 6.2, -20, 0.24, 0.64)

	# ============ COFFEE BAR (the social anchor, west wall) ============
	_prop("kitchenBar", 1.45, 10.5, 90, 1.0, 0.0, 0.95)
	_prop("kitchenBar", 1.45, 11.5, 90, 1.0, 0.0, 0.95)
	_prop("kitchenCoffeeMachine", 1.45, 10.5, 90, 1.0, 0.95, 0.35)
	_box(Vector3(0.3, 0.18, 0.5), Vector3(1.45, 1.04, 11.4), _mat("pantry_tray", Color(0.85, 0.80, 0.72)), self, false)
	_prop("kitchenCabinetUpperDouble", 0.38, 10.6, 90, 1.0, 1.85, 0.55)
	_prop("kitchenCabinetUpper", 0.38, 11.5, 90, 1.0, 1.85, 0.55)
	_prop("stoolBar", 2.35, 10.7, 100, 1.0, 0.0, 0.75)
	_prop("stoolBar", 2.35, 11.6, 80, 1.0, 0.0, 0.75)
	_prop("kitchenFridgeSmall", 1.4, 12.5, 90, 1.0, 0.0, 1.1)
	_prop("tableCoffee", 4.6, 11.5, 90, 1.0, 0.0, 0.42)
	_prop("benchCushionLow", 4.6, 12.3, 180, 1.0, 0.0, 0.42)
	_prop("loungeChair", 4.6, 10.6, 0, 1.0, 0.0, 0.8)
	_pendant(Vector3(1.9, 2.4, 11.0))

	# wall frames (west wall, coral family)
	var frame_cols := [CORAL, Color(0.98, 0.72, 0.55), Color(0.96, 0.89, 0.78)]
	for i in 3:
		_box(Vector3(0.03, 0.5, 0.42), Vector3(0.20, 2.0, 7.9 + i * 0.9),
			_mat("frame_%d" % i, frame_cols[i]), self, false)
		_box(Vector3(0.02, 0.56, 0.48), Vector3(0.19, 2.0, 7.9 + i * 0.9), steel, self, false)

	# ============ NORTH WING: PUBLISHING DEPARTMENT ============
	# publisher station under the windows
	_box(Vector3(1.95, 1.25, 0.07), Vector3(15.0, 0.72, 1.45), _mat("partition", Color(0.93, 0.92, 0.89)))
	_box(Vector3(1.95, 0.06, 0.10), Vector3(15.0, 1.38, 1.45),
		_mat("trim_coral", CORAL, "", CORAL * 0.4), self, false)
	_box(Vector3(0.3, 0.06, 0.11), Vector3(15.0, 1.44, 1.45),
		_mat("chip_publisher", ROLE_ACCENT["publisher"], "", (ROLE_ACCENT["publisher"] as Color) * 0.5), self, false)
	_prop("desk", 15.0, 2.0, 180, 1.0, 0.0, 0.74)
	_prop("computerScreen", 14.75, 1.9, 0, 1.0, DESK_H + 0.18, 0.38)
	_prop("computerScreen", 15.3, 1.9, 5, 1.0, DESK_H + 0.18, 0.38)
	for arm2 in [[14.75, 1.9], [15.3, 1.9]]:
		_box(Vector3(0.03, 0.22, 0.03), Vector3(arm2[0], DESK_H + 0.11, arm2[1]), steel, self, false)
	_prop("computerKeyboard", 14.8, 2.2, 180, 0.28, DESK_H)
	_prop("chairDesk", 15.0, 2.9, 175, 1.0, 0.0, 1.0)
	# ring light + phone rig (it's a publishing dept after all)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.19
	ring.mesh = torus
	ring.material_override = _mat("ringlight", Color(1.0, 0.9, 0.7) * 0.7, "", Color(1.0, 0.9, 0.7))
	ring.rotation_degrees = Vector3(90, 20, 0)
	ring.position = Vector3(16.4, 1.25, 2.6)
	add_child(ring)
	_box(Vector3(0.04, 1.05, 0.04), Vector3(16.4, 0.52, 2.6), steel)
	# storage + copier along the east end
	_prop("bookcaseClosedWide", 18.2, 1.5, 0, 1.0, 0.0, 1.9)
	_prop("sideTableDrawers", 19.3, 1.5, 0, 1.0, 0.0, 0.75)
	_box(Vector3(0.55, 0.42, 0.5), Vector3(19.3, 0.95, 1.5), _mat("printer", Color(0.86, 0.85, 0.82)))
	_prop("cardboardBoxClosed", 19.4, 2.4, 15, 0.55)
	# mission board (kanban) on the north wall
	var note_cols := [Color(1.0, 0.84, 0.47), Color(1.0, 0.59, 0.7), Color(0.35, 0.86, 0.86), Color(0.66, 0.94, 0.78)]
	_box(Vector3(1.4, 0.8, 0.04), Vector3(12.9, 2.0, 0.20), _mat("kanban", Color(0.30, 0.30, 0.36)))
	for r in 3:
		for cn in 4:
			_box(Vector3(0.18, 0.18, 0.02), Vector3(12.45 + cn * 0.31, 2.26 - r * 0.26, 0.23),
				_mat("note_%d" % ((r + cn) % 4), note_cols[(r + cn) % 4]), self, false)
	# window bench overlooking the courtyard (refuge with prospect)
	_box(Vector3(2.9, 0.42, 0.55), Vector3(14.0, 0.21, 6.55), oak)
	_box(Vector3(2.9, 0.10, 0.55), Vector3(14.0, 0.47, 6.55), _mat("bench_cushion", Color(0.88, 0.86, 0.82)), self, false)
	_prop("pillow", 13.2, 6.55, 20, 0.4, 0.52)
	_prop("pillow", 14.8, 6.55, -15, 0.4, 0.52)
	_pendant(Vector3(15.0, 2.4, 2.2))
	_pendant(Vector3(18.4, 2.4, 1.8))

	# ============ COURTYARD-FACING LOW WALLS + GLASS ============
	# south face of the north wing (x12..19 at z=7) with a door gap at x=16
	for wx in [12, 13, 14, 15, 17, 18, 19]:
		_box(Vector3(1.0, 0.85, 0.12), Vector3(wx + 0.5, 0.425, 7.0), wallwhite)
		_box(Vector3(1.0, 0.9, 0.05), Vector3(wx + 0.5, 1.3, 7.0), glass, self, false)
	_box(Vector3(0.09, 2.0, 0.12), Vector3(16.0, 1.0, 7.0), steel)
	_box(Vector3(0.09, 2.0, 0.12), Vector3(17.0, 1.0, 7.0), steel)
	# east face of the west wing (z7..13 at x=12) with a door gap at z=9
	for wz in [7, 8, 10, 11, 12, 13]:
		_box(Vector3(0.12, 0.85, 1.0), Vector3(12.0, 0.425, wz + 0.5), wallwhite)
		_box(Vector3(0.05, 0.9, 1.0), Vector3(12.0, 1.3, wz + 0.5), glass, self, false)
	_box(Vector3(0.12, 2.0, 0.09), Vector3(12.0, 1.0, 9.0), steel)
	_box(Vector3(0.12, 2.0, 0.09), Vector3(12.0, 1.0, 10.0), steel)
	# coral doormats at both courtyard doors
	var mat1 := _prop("rugDoormat", 16.5, 6.5, 0, 1.0)
	_tint_meshes(mat1, CORAL)
	var mat2 := _prop("rugDoormat", 11.5, 9.5, 90, 1.0)
	_tint_meshes(mat2, CORAL)

	# ============ THE COURTYARD GARDEN (the notch) ============
	# stone path: door (16,7) south, turning west to door (12,9)
	for step in [[16.5, 8.0], [16.4, 9.0], [16.0, 10.0], [15.3, 10.6], [14.4, 10.3], [13.5, 9.8], [12.8, 9.5]]:
		_box(Vector3(0.75, 0.07, 0.55), Vector3(step[0], 0.035, step[1]),
			_mat("stone_step", Color(0.78, 0.77, 0.74)), self, false)
	# pond
	var pond := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 1.35
	pcyl.bottom_radius = 1.35
	pcyl.height = 0.06
	pond.mesh = pcyl
	var pmat := _mat("pond", Color(0.47, 0.67, 0.76))
	pmat.roughness = 0.15
	pond.material_override = pmat
	pond.position = Vector3(17.8, 0.03, 11.2)
	add_child(pond)
	for i in 9:
		var ang := i * TAU / 9.0
		_bush_stone(Vector3(17.8 + cos(ang) * (1.42 + randf_range(0.0, 0.12)), 0.03, 11.2 + sin(ang) * (1.42 + randf_range(0.0, 0.12))))
	# courtyard trees + bushes
	_tree(Vector3(13.6, 0.0, 12.2), 1.05)
	_tree(Vector3(14.8, 0.0, 16.0), 1.2)
	_tree(Vector3(18.4, 0.0, 17.2), 0.9)
	_bush(Vector3(16.4, 0.0, 15.0))
	_tree(Vector3(18.6, 0.0, 8.6), 0.85)
	_bush(Vector3(12.8, 0.0, 11.4))
	_bush(Vector3(15.2, 0.0, 12.6))
	_bush(Vector3(19.2, 0.0, 9.6))
	# outdoor stone bench facing the pond
	_box(Vector3(1.1, 0.16, 0.4), Vector3(14.8, 0.28, 11.6), _mat("stone_bench", Color(0.80, 0.79, 0.76)))
	_box(Vector3(0.16, 0.24, 0.36), Vector3(14.45, 0.12, 11.6), _mat("stone_bench", Color(0.80, 0.79, 0.76)))
	_box(Vector3(0.16, 0.24, 0.36), Vector3(15.15, 0.12, 11.6), _mat("stone_bench", Color(0.80, 0.79, 0.76)))

	# ============ interior plants ============
	_prop("pottedPlant", 10.6, 1.0, 0, 1.0, 0.0, 1.15)
	_prop("pottedPlant", 10.6, 12.6, 0, 1.0, 0.0, 1.15)
	_prop("plantSmall1", 6.4, 12.6, 0, 1.0, 0.0, 0.5)
	_prop("pottedPlant", 12.6, 5.6, 0, 1.0, 0.0, 1.15)

	# ============ TOWN HALL (Google-style all-hands: stage 20% /
	# open agora floor 25% / tiered bleachers 55% of the depth) ============
	var hall_z := 16.5
	# stage platform + podium against the west wall
	_box(Vector3(1.7, 0.26, 4.6), Vector3(1.75, 0.13, hall_z), oak)
	_box(Vector3(1.8, 0.05, 4.7), Vector3(1.75, 0.28, hall_z), _mat("stage_top", Color(0.88, 0.83, 0.74)), self, false)
	_box(Vector3(0.4, 0.9, 0.5), Vector3(1.5, 0.73, 15.3), oak)
	_prop("laptop", 1.5, 15.3, 90, 0.32, 1.2)
	# big screen on the west wall (the TGIF backdrop)
	_box(Vector3(0.08, 2.0, 4.2), Vector3(0.24, 1.85, hall_z), _mat("screen_frame", Color(0.16, 0.16, 0.19)))
	_box(Vector3(0.04, 1.7, 3.8), Vector3(0.30, 1.85, hall_z),
		_mat("screen_glow", Color(0.35, 0.42, 0.55) * 0.8, "", Color(0.45, 0.55, 0.75)), self, false)
	_box(Vector3(0.05, 0.3, 2.4), Vector3(0.33, 2.45, hall_z),
		_mat("trim_coral", CORAL, "", CORAL * 0.4), self, false)
	var hall_title := Label3D.new()
	hall_title.text = "ALL-HANDS"
	hall_title.font_size = 96
	hall_title.outline_size = 20
	hall_title.pixel_size = 0.004
	hall_title.modulate = Color(0.95, 0.94, 0.9)
	hall_title.position = Vector3(0.38, 1.85, hall_z)
	hall_title.rotation_degrees = Vector3(0, 90, 0)
	add_child(hall_title)
	# speakers flanking the stage
	_box(Vector3(0.4, 1.1, 0.4), Vector3(1.4, 0.55, 14.4), _mat("speaker_box", Color(0.2, 0.2, 0.23)))
	_box(Vector3(0.4, 1.1, 0.4), Vector3(1.4, 0.55, 18.6), _mat("speaker_box", Color(0.2, 0.2, 0.23)))
	# three wooden bleacher tiers with Google-color cushions
	var cushion_cols := [Color(0.26, 0.52, 0.96), Color(0.92, 0.26, 0.21), Color(0.98, 0.74, 0.02), Color(0.20, 0.66, 0.33)]
	for tier in 3:
		var tx := 6.5 + tier
		var th := 0.24 * (tier + 1)
		_box(Vector3(1.0, th, 4.9), Vector3(tx, th / 2.0, hall_z), oak)
		_box(Vector3(1.02, 0.05, 5.0), Vector3(tx, th + 0.02, hall_z), _mat("tier_top", Color(0.83, 0.68, 0.5)), self, false)
		for ci in 4:
			_box(Vector3(0.55, 0.07, 0.6), Vector3(tx - 0.1, th + 0.07, 14.7 + ci * 1.25),
				_mat("cushion_%d" % ((ci + tier) % 4), cushion_cols[(ci + tier) % 4]), self, false)
	# beanbags at the back corners
	for bb in [[10.4, 14.4, 0], [10.4, 18.5, 2]]:
		var bag := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.42
		bs.height = 0.5
		bag.mesh = bs
		bag.material_override = _mat("beanbag_%d" % int(bb[2]), cushion_cols[int(bb[2])])
		bag.position = Vector3(bb[0], 0.22, bb[1])
		add_child(bag)
	_pendant(Vector3(4.0, 2.4, 15.2))
	_pendant(Vector3(4.0, 2.4, 17.8))
	_prop("pottedPlant", 10.6, 16.5, 0, 1.0, 0.0, 1.15)

	# ============ EXTERIOR LANDSCAPE ============
	_box(Vector3(70.0, 0.06, 70.0), Vector3(10.0, -0.58, 7.0),
		_mat("grass", Color(0.55, 0.66, 0.42)), self, false)
	for tx in [2.5, 6.5, 10.0, 14.5, 18.0]:
		_tree(Vector3(tx, -0.55, -1.6), randf_range(0.9, 1.25))
	for tz in [3.0, 7.5, 12.0]:
		_tree(Vector3(-1.7, -0.55, tz), randf_range(0.9, 1.2))
	_tree(Vector3(21.6, -0.55, 2.5), 1.1)
	_tree(Vector3(6.0, -0.55, 20.9), 1.25)
	for bpos in [[1.2, -0.9], [8.5, -0.9], [16.0, -0.9], [-0.9, 5.5], [-0.9, 9.8], [3.5, 19.9]]:
		_bush(Vector3(bpos[0], -0.55, bpos[1]))
	# entrance path from the courtyard out to the world (south-east)
	for i in 3:
		_box(Vector3(0.9, 0.08, 0.6), Vector3(16.6 + i * 0.3, -0.51, 14.5 + i * 0.9),
			_mat("stone_step", Color(0.78, 0.77, 0.74)), self, false)


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
