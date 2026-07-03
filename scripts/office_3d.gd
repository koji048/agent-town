## Builds the 3D diorama office: walls from assets/map.json, real
## furniture from CC0 Kenney Furniture Kit models (assets/models/*.glb,
## loaded at runtime with procedural fallbacks), a glass director cabin,
## desk pods with partitions, storage, coffee corner and lounge — plus
## the AStarGrid2D pathfinding agents navigate on.
class_name Office3D
extends Node3D

const CELL := 1.0
const WALL_H := 3.0
const WALL_T := 0.15
const DESK_H := 0.72

var cols: int = 0
var rows: int = 0
var map_rows: Array = []
var buildings: Dictionary = {}
var astar := AStarGrid2D.new()

var _mats: Dictionary = {}
var _gltf_cache: Dictionary = {}

const ROLE_ACCENT := {
	"director": Color(0.85, 0.67, 0.24),
	"researcher": Color(0.17, 0.48, 0.32),
	"writer": Color(0.84, 0.49, 0.17),
	"editor": Color(0.35, 0.86, 0.86),
	"publisher": Color(0.77, 0.24, 0.26),
}

# Extra blocked cells (furniture outside the 2x2 station anchors)
const BLOCKED_CELLS: Array = [
	# director cabin glass walls
	[4, 1], [4, 2], [1, 4], [2, 4],
	# north-wall storage row
	[11, 1], [12, 1], [13, 1], [14, 1], [15, 1],
	# coffee corner (west wall)
	[1, 5], [1, 6], [1, 7],
	# lounge
	[1, 9], [1, 10], [2, 10], [4, 11], [1, 12],
	# plants
	[15, 6], [15, 12],
	# meeting corner
	[12, 8], [13, 8], [12, 9], [13, 9],
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
	return Vector2i(10, 11)


# ------------------------------------------------------------ materials/mesh

func _mat(key: String, color: Color, tex_path: String = "", emission: Color = Color.BLACK,
		transparent: bool = false, uv_scale: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if not tex_path.is_empty():
		m.albedo_texture = load(tex_path)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
	root.add_child(node)
	return root


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
	var tex := "carpet"
	if gx <= 5 and gy >= 10:
		tex = "deck"           # lounge: warm wood
	elif gx <= 2 and gy >= 5 and gy <= 8:
		tex = "concrete"       # coffee corner strip
	var m := _mat("floor_" + tex, Color.WHITE, "res://assets/textures/%s.png" % tex)
	var cx := (gx + 0.5) * CELL
	var cz := (gy + 0.5) * CELL
	_box(Vector3(CELL, 0.1, CELL), Vector3(cx, -0.05, cz), m, self, false)
	# diorama slab under the floor
	_box(Vector3(CELL, 0.42, CELL), Vector3(cx, -0.31, cz),
		_mat("slab", Color(0.16, 0.16, 0.20)), self, false)


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
	var wood := _mat("wallwood", Color.WHITE, "res://assets/textures/wallwood.png",
		Color.BLACK, false, Vector3(1, 3, 1))
	if kind == "w" or kind == "v":
		_box(size, pos + Vector3(0, WALL_H / 2.0, 0), wood)
		# baseboard
		var bb := Vector3(CELL, 0.12, 0.05) if ne else Vector3(0.05, 0.12, CELL)
		var bb_off := Vector3(0, 0.06, WALL_T / 2.0 + 0.03) if ne else Vector3(WALL_T / 2.0 + 0.03, 0.06, 0)
		_box(bb, pos + bb_off, _mat("baseboard", Color(0.24, 0.22, 0.26)), self, false)
		return
	if kind == "M":
		_box(size, pos + Vector3(0, WALL_H / 2.0, 0), wood)
		if _mural_run_index(row, gx) == 0:
			var quad := MeshInstance3D.new()
			var mesh := QuadMesh.new()
			mesh.size = Vector2(4.0 * CELL, 2.2)
			quad.mesh = mesh
			quad.material_override = _mat("mural", Color.WHITE, "res://assets/textures/mural_full.png")
			quad.position = Vector3(pos.x + 2.0 * CELL - CELL / 2.0, 1.55, WALL_T + 0.01)
			add_child(quad)
		return
	# window segment
	var sill_size := Vector3(CELL, 0.9, WALL_T) if ne else Vector3(WALL_T, 0.9, CELL)
	var lintel_size := Vector3(CELL, 0.6, WALL_T) if ne else Vector3(WALL_T, 0.6, CELL)
	var glass_size := Vector3(CELL, 1.5, 0.05) if ne else Vector3(0.05, 1.5, CELL)
	var mull_size := Vector3(0.06, 1.5, WALL_T) if ne else Vector3(WALL_T, 1.5, 0.06)
	_box(sill_size, pos + Vector3(0, 0.45, 0), wood)
	_box(lintel_size, pos + Vector3(0, 2.7, 0), wood)
	var glass := _mat("glass", Color(0.72, 0.86, 0.95, 0.30), "", Color.BLACK, true)
	_box(glass_size, pos + Vector3(0, 1.65, 0), glass, self, false)
	_box(mull_size, pos + Vector3(0, 1.65, 0), _mat("steel", Color(0.20, 0.20, 0.23)))


func _mural_run_index(row: String, gx: int) -> int:
	var i := 0
	while gx - i - 1 >= 0 and row[gx - i - 1] == "M":
		i += 1
	return i


# ------------------------------------------------------------ furnishing

func _furnish() -> void:
	var steel := _mat("steel", Color(0.20, 0.20, 0.23))
	var glass := _mat("podglass", Color(0.72, 0.86, 0.95, 0.28), "", Color.BLACK, true)

	# --- director's cabin (glass walls, corner desk)
	_prop("rugRectangle", 2.2, 2.4, 0, 2.4)
	_prop("deskCorner", 1.7, 1.7, 180, 1.0, 0.0, 0.74)
	_prop("chairDesk", 2.5, 2.6, 205, 1.0, 0.0, 0.95)
	_prop("computerScreen", 1.5, 1.7, 335, 1.0, DESK_H, 0.42)
	_prop("computerKeyboard", 1.9, 2.0, 335, 0.32, DESK_H)
	_prop("plantSmall2", 2.9, 1.4, 0, 1.0, DESK_H, 0.26)
	_prop("pottedPlant", 4.0, 0.7, 0, 1.0, 0.0, 1.15)
	var gwall1 := _box(Vector3(0.08, 2.0, 2.0), Vector3(4.5, 1.0, 2.0), glass, self, false)
	gwall1.set_meta("k", 1)
	_box(Vector3(0.10, 2.05, 0.1), Vector3(4.5, 1.02, 3.0), steel)
	_box(Vector3(2.0, 2.0, 0.08), Vector3(2.0, 1.0, 4.5), glass, self, false)
	_box(Vector3(0.1, 2.05, 0.10), Vector3(3.0, 1.02, 4.5), steel)

	# --- crew desk pods (2 rows x 2 pods, facing south)
	var pods := [
		["researcher", 6.0, 5.5], ["writer", 8.0, 5.5],
		["editor", 6.0, 8.5], ["publisher", 8.0, 8.5],
	]
	for pod in pods:
		var role: String = pod[0]
		var px: float = pod[1]
		var pz: float = pod[2]
		var accent: Color = ROLE_ACCENT[role]
		_prop("desk", px, pz, 180, 1.0, 0.0, 0.74)
		# partition behind the desk with a role-colored trim
		_box(Vector3(1.95, 1.25, 0.07), Vector3(px, 0.72, pz - 0.55), _mat("partition", Color(0.93, 0.92, 0.89)))
		_box(Vector3(1.95, 0.07, 0.10), Vector3(px, 1.38, pz - 0.55),
			_mat("trim_" + role, accent, "", accent * 0.5), self, false)
		# low storage behind the partition, with books for color
		_prop("bookcaseOpenLow", px, pz - 1.05, 0, 1.0, 0.0, 0.62)
		_prop("books", px - 0.4, pz - 1.05, randf_range(-25.0, 25.0), 0.3, 0.64)
		_prop("books", px + 0.35, pz - 1.05, randf_range(-25.0, 25.0), 0.26, 0.64)
		# desk gear
		_prop("computerScreen", px - 0.25, pz - 0.12, 0, 1.0, DESK_H, 0.40)
		_prop("computerKeyboard", px - 0.22, pz + 0.20, 0, 0.30, DESK_H)
		_prop("laptop", px + 0.45, pz + 0.08, 20, 0.36, DESK_H)
		_prop("chairDesk", px + 0.15, pz + 0.85, randf_range(150.0, 210.0), 1.0, 0.0, 1.05)
		_prop("trashcan", px - 0.85, pz + 0.75, 0, 1.0, 0.0, 0.4)
	_prop("plantSmall1", 6.0, 4.45, 0, 1.0, 0.64, 0.28)
	_prop("plantSmall3", 8.0, 7.45, 0, 1.0, 0.64, 0.28)

	# --- north wall: storage, copier, boxes + wall dressing
	_prop("bookcaseClosedWide", 11.6, 1.5, 0, 1.0, 0.0, 1.9)
	_prop("bookcaseOpen", 13.0, 1.5, 0, 1.0, 0.0, 1.8)
	_prop("sideTableDrawers", 14.1, 1.5, 0, 1.0, 0.0, 0.75)
	_box(Vector3(0.55, 0.42, 0.5), Vector3(14.1, 0.95, 1.5), _mat("printer", Color(0.86, 0.85, 0.82)))
	_box(Vector3(0.4, 0.1, 0.35), Vector3(14.1, 1.2, 1.5), steel)
	_prop("cardboardBoxClosed", 15.3, 1.4, 15, 0.6)
	_prop("cardboardBoxOpen", 15.5, 2.1, -20, 0.5)
	# wall TV + boards + clock
	_prop("televisionModern", 10.4, 0.45, 180, 1.25, 1.7)
	_box(Vector3(1.3, 0.75, 0.04), Vector3(12.7, 2.0, 0.20), _mat("whiteboard", Color(0.95, 0.95, 0.93)))
	_box(Vector3(1.36, 0.81, 0.03), Vector3(12.7, 2.0, 0.18), steel)
	var note_cols := [Color(1.0, 0.84, 0.47), Color(1.0, 0.59, 0.7), Color(0.35, 0.86, 0.86), Color(0.66, 0.94, 0.78)]
	_box(Vector3(1.0, 0.7, 0.04), Vector3(14.3, 2.0, 0.20), _mat("kanban", Color(0.30, 0.30, 0.36)))
	for r in 3:
		for cn in 3:
			_box(Vector3(0.16, 0.16, 0.02), Vector3(13.98 + cn * 0.32, 2.22 - r * 0.22, 0.23),
				_mat("note_%d" % ((r + cn) % 4), note_cols[(r + cn) % 4]), self, false)
	# clock
	var clock := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.17
	cyl.bottom_radius = 0.17
	cyl.height = 0.05
	clock.mesh = cyl
	clock.material_override = _mat("clockface", Color(0.96, 0.96, 0.93))
	clock.rotation_degrees = Vector3(90, 0, 0)
	clock.position = Vector3(9.5, 2.35, 0.20)
	add_child(clock)
	_box(Vector3(0.03, 0.11, 0.02), Vector3(9.5, 2.39, 0.24), steel)
	_box(Vector3(0.09, 0.03, 0.02), Vector3(9.53, 2.35, 0.24), steel)

	# --- west wall: coffee corner + frames
	_prop("kitchenCabinet", 1.45, 6.0, 90, 1.0, 0.0, 0.9)
	_prop("kitchenCoffeeMachine", 1.45, 6.0, 90, 1.0, 0.9, 0.35)
	_prop("kitchenFridgeSmall", 1.4, 7.15, 90, 1.0, 0.0, 1.1)
	# water cooler (procedural)
	_box(Vector3(0.34, 0.9, 0.34), Vector3(1.4, 0.45, 5.1), _mat("cooler", Color(0.88, 0.90, 0.92)))
	_box(Vector3(0.24, 0.34, 0.24), Vector3(1.4, 1.05, 5.1),
		_mat("coolerjug", Color(0.55, 0.75, 0.95, 0.6), "", Color.BLACK, true), self, false)
	_prop("trashcan", 1.35, 8.1, 0, 0.3)
	var frame_cols := [Color(0.93, 0.59, 0.38), Color(0.87, 0.43, 0.39), Color(0.96, 0.89, 0.78)]
	for i in 3:
		_box(Vector3(0.03, 0.5, 0.42), Vector3(0.20, 2.0, 5.8 + i * 1.1),
			_mat("frame_%d" % i, frame_cols[i]), self, false)
		_box(Vector3(0.02, 0.56, 0.48), Vector3(0.19, 2.0, 5.8 + i * 1.1), steel, self, false)

	# --- lounge (bottom-left)
	_prop("rugRound", 3.2, 10.9, 0, 2.2)
	_prop("loungeSofa", 1.8, 10.6, 90, 1.0, 0.0, 0.85)
	_prop("loungeChair", 4.3, 11.7, -35, 1.0, 0.0, 0.8)
	_prop("tableCoffee", 3.2, 10.9, 90, 1.0, 0.0, 0.42)
	_prop("laptop", 3.2, 10.9, 160, 0.34, 0.43)
	_prop("lampRoundFloor", 1.4, 9.6, 0, 1.0, 0.0, 1.5)
	_prop("pottedPlant", 1.4, 12.3, 0, 1.0, 0.0, 1.15)
	_prop("speaker", 5.2, 12.4, -20, 1.0, 0.0, 0.95)
	var lounge_light := OmniLight3D.new()
	lounge_light.position = Vector3(2.6, 2.0, 10.8)
	lounge_light.light_color = Color(1.0, 0.87, 0.6)
	lounge_light.omni_range = 3.6
	lounge_light.light_energy = 1.2
	lounge_light.shadow_enabled = false
	add_child(lounge_light)

	# --- meeting corner (bottom-right)
	_prop("rugSquare" if FileAccess.file_exists("res://assets/models/rugSquare.glb") else "rugRectangle", 13.0, 9.0, 0, 2.6)
	_prop("table", 13.0, 9.0, 90, 1.0, 0.0, 0.74)
	_prop("chairModernCushion", 12.0, 8.6, 90, 1.0, 0.0, 0.9)
	_prop("chairModernCushion", 12.0, 9.5, 75, 1.0, 0.0, 0.9)
	_prop("chairModernCushion", 14.0, 8.6, 270, 1.0, 0.0, 0.9)
	_prop("chairModernCushion", 14.0, 9.5, 290, 1.0, 0.0, 0.9)
	_prop("laptop", 12.8, 9.0, 100, 0.34, DESK_H)
	_prop("plantSmall1", 13.4, 9.3, 0, 1.0, DESK_H, 0.24)

	# --- scattered plants
	_prop("pottedPlant", 15.4, 6.5, 0, 1.0, 0.0, 1.15)
	_prop("plantSmall2", 15.4, 12.4, 0, 1.0, 0.0, 0.7)
	_prop("coatRackStanding", 5.4, 0.6, 0, 1.0, 0.0, 1.7)

	# --- warm light pools over the pods and cabin
	for lp in [[2.0, 2.0], [7.0, 5.5], [7.0, 8.5], [13.0, 1.8]]:
		var l := OmniLight3D.new()
		l.position = Vector3(lp[0], 2.4, lp[1])
		l.light_color = Color(1.0, 0.9, 0.75)
		l.omni_range = 3.4
		l.light_energy = 1.0
		l.shadow_enabled = false
		add_child(l)
