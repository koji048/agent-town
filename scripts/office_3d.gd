## Builds the 3D open-plan office from assets/map.json: floor zones,
## perimeter walls with glass windows and the mural, furniture stations,
## props, lamps — plus the same AStarGrid2D pathfinding the 2D version
## used. Rendered through an orthographic camera for the isometric look.
class_name Office3D
extends Node3D

const CELL := 1.0
const WALL_H := 3.0
const WALL_T := 0.15

var cols: int = 0
var rows: int = 0
var map_rows: Array = []
var buildings: Dictionary = {}
var astar := AStarGrid2D.new()

var _mats: Dictionary = {}

const ROLE_ACCENT := {
	"director": Color(0.85, 0.67, 0.24),
	"researcher": Color(0.17, 0.48, 0.32),
	"writer": Color(0.84, 0.49, 0.17),
	"editor": Color(0.35, 0.86, 0.86),
	"publisher": Color(0.77, 0.24, 0.26),
}


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
			_build_floor_cell(c, gx, gy)
			_build_cell_object(c, gx, gy, row)

	for bname in buildings:
		var b: Dictionary = buildings[bname]
		var ax := int(b["anchor"][0])
		var ay := int(b["anchor"][1])
		for dx in 2:
			for dy in 2:
				astar.set_point_solid(Vector2i(ax + dx, ay + dy), true)
		_build_station(bname, str(b["role"]), ax, ay)


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
	for _i in 40:
		var g := Vector2i(randi() % cols, randi() % rows)
		if not is_blocked(g):
			return g
	return Vector2i(10, 6)


# ------------------------------------------------------------ mesh helpers

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


# ------------------------------------------------------------ floor

func _build_floor_cell(c: String, gx: int, gy: int) -> void:
	var tex := "concrete"
	match c:
		",": tex = "concrete_dark"
		"#": tex = "deck"
		"P": tex = "atrium"
		"r": tex = "carpet"
		"~": tex = "concrete"
	var m := _mat("floor_" + tex, Color.WHITE, "res://assets/textures/%s.png" % tex)
	_box(Vector3(CELL, 0.1, CELL), Vector3((gx + 0.5) * CELL, -0.05, (gy + 0.5) * CELL), m, self, false)


# ------------------------------------------------------------ cell objects

func _build_cell_object(c: String, gx: int, gy: int, row: String) -> void:
	var w := grid_to_world(Vector2i(gx, gy))
	match c:
		"w", "W", "M":
			_wall_segment(c, Vector3(w.x, 0, WALL_T / 2.0), true, gx, row)
		"v", "V":
			_wall_segment(c, Vector3(WALL_T / 2.0, 0, w.z), false, gx, row)
		"c":
			_wall_segment("w", Vector3(w.x, 0, WALL_T / 2.0), true, gx, row)
			_wall_segment("v", Vector3(WALL_T / 2.0, 0, w.z), false, gx, row)
		"~":
			_planter(w)
		"t":
			_plant(w)
		"d":
			_desk_cluster(w)
		"l":
			_lamp(w)


func _wall_segment(kind: String, pos: Vector3, ne: bool, gx: int, row: String) -> void:
	var size := Vector3(CELL, WALL_H, WALL_T) if ne else Vector3(WALL_T, WALL_H, CELL)
	var wood := _mat("wallwood", Color.WHITE, "res://assets/textures/wallwood.png",
		Color.BLACK, false, Vector3(1, 3, 1))
	if kind == "w" or kind == "v":
		_box(size, pos + Vector3(0, WALL_H / 2.0, 0), wood)
		return
	if kind == "M":
		_box(size, pos + Vector3(0, WALL_H / 2.0, 0), wood)
		# one mural quad per 4-tile run, placed at the run's start tile
		if _mural_run_index(row, gx) == 0:
			var quad := MeshInstance3D.new()
			var mesh := QuadMesh.new()
			mesh.size = Vector2(4.0 * CELL, 2.4)
			quad.mesh = mesh
			quad.material_override = _mat("mural", Color.WHITE, "res://assets/textures/mural_full.png")
			quad.position = Vector3(pos.x + 2.0 * CELL - CELL / 2.0, 1.5, WALL_T + 0.01)
			add_child(quad)
		return
	# window segment: sill + lintel + glass + mullion
	var sill_size := Vector3(CELL, 0.9, WALL_T) if ne else Vector3(WALL_T, 0.9, CELL)
	var lintel_size := Vector3(CELL, 0.6, WALL_T) if ne else Vector3(WALL_T, 0.6, CELL)
	var glass_size := Vector3(CELL, 1.5, 0.05) if ne else Vector3(0.05, 1.5, CELL)
	var mull_size := Vector3(0.06, 1.5, WALL_T) if ne else Vector3(WALL_T, 1.5, 0.06)
	_box(sill_size, pos + Vector3(0, 0.45, 0), wood)
	_box(lintel_size, pos + Vector3(0, 2.7, 0), wood)
	var glass := _mat("glass", Color(0.72, 0.86, 0.95, 0.30), "", Color.BLACK, true)
	_box(glass_size, pos + Vector3(0, 1.65, 0), glass, self, false)
	var steel := _mat("steel", Color(0.20, 0.20, 0.23))
	_box(mull_size, pos + Vector3(0, 1.65, 0), steel)


func _mural_run_index(row: String, gx: int) -> int:
	var i := 0
	while gx - i - 1 >= 0 and row[gx - i - 1] == "M":
		i += 1
	return i


func _planter(w: Vector3) -> void:
	var rim := _mat("planter_rim", Color(0.45, 0.32, 0.22))
	var soil := _mat("garden", Color.WHITE, "res://assets/textures/garden.png")
	_box(Vector3(CELL, 0.3, CELL), w + Vector3(0, 0.15, 0), rim)
	_box(Vector3(CELL - 0.12, 0.06, CELL - 0.12), w + Vector3(0, 0.31, 0), soil, self, false)
	_foliage(w + Vector3(0.18, 0.55, 0.12), 0.20)
	_foliage(w + Vector3(-0.2, 0.62, -0.15), 0.24)


func _plant(w: Vector3) -> void:
	var pot := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.17
	cyl.bottom_radius = 0.12
	cyl.height = 0.28
	pot.mesh = cyl
	pot.material_override = _mat("pot", Color(0.72, 0.4, 0.27))
	pot.position = w + Vector3(0, 0.14, 0)
	add_child(pot)
	_foliage(w + Vector3(0, 0.55, 0), 0.28)
	_foliage(w + Vector3(0.05, 0.82, 0.04), 0.19)


func _foliage(pos: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.7
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = _mat("leaf", Color(0.24, 0.48, 0.28))
	mi.position = pos
	add_child(mi)


func _desk(parent: Node3D, pos: Vector3, w: float = 1.2, depth: float = 0.6) -> void:
	var top := _mat("deskwood", Color.WHITE, "res://assets/textures/deck.png")
	var steel := _mat("steel", Color(0.20, 0.20, 0.23))
	_box(Vector3(w, 0.05, depth), pos + Vector3(0, 0.72, 0), top, parent)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.05, 0.7, 0.05),
				pos + Vector3(sx * (w / 2 - 0.06), 0.35, sz * (depth / 2 - 0.06)), steel, parent)


func _laptop(parent: Node3D, pos: Vector3, glow: Color) -> void:
	var steel := _mat("steel", Color(0.20, 0.20, 0.23))
	_box(Vector3(0.3, 0.02, 0.22), pos, steel, parent)
	_box(Vector3(0.3, 0.22, 0.02), pos + Vector3(0, 0.11, -0.1), steel, parent)
	_box(Vector3(0.26, 0.18, 0.012), pos + Vector3(0, 0.11, -0.093),
		_mat("screen_" + str(glow), glow * 0.6, "", glow), parent, false)


func _monitor(parent: Node3D, pos: Vector3, glow: Color) -> void:
	var steel := _mat("steel", Color(0.20, 0.20, 0.23))
	_box(Vector3(0.42, 0.28, 0.03), pos + Vector3(0, 0.2, 0), steel, parent)
	_box(Vector3(0.38, 0.24, 0.012), pos + Vector3(0, 0.2, 0.022),
		_mat("screen_" + str(glow), glow * 0.6, "", glow), parent, false)
	_box(Vector3(0.05, 0.12, 0.05), pos + Vector3(0, 0, 0), steel, parent)


func _desk_cluster(w: Vector3) -> void:
	var group := Node3D.new()
	group.position = w
	add_child(group)
	_desk(group, Vector3.ZERO)
	_laptop(group, Vector3(0, 0.755, 0.05), Color(0.45, 0.85, 1.0))


func _lamp(w: Vector3) -> void:
	var steel := _mat("steel", Color(0.20, 0.20, 0.23))
	_box(Vector3(0.06, 1.6, 0.06), w + Vector3(0, 0.8, 0), steel)
	_box(Vector3(0.26, 0.14, 0.26), w + Vector3(0, 1.68, 0),
		_mat("lampshade", Color(1.0, 0.84, 0.47) * 0.7, "", Color(1.0, 0.84, 0.47)), self, false)
	var light := OmniLight3D.new()
	light.position = w + Vector3(0, 1.55, 0)
	light.light_color = Color(1.0, 0.87, 0.6)
	light.omni_range = 4.0
	light.light_energy = 1.6
	light.shadow_enabled = false
	add_child(light)


# ------------------------------------------------------------ stations

func _build_station(bname: String, role: String, ax: int, ay: int) -> void:
	var group := Node3D.new()
	group.position = Vector3((ax + 1.0) * CELL, 0, (ay + 1.0) * CELL)
	add_child(group)
	var accent: Color = ROLE_ACCENT.get(role, Color.WHITE)
	var wood := _mat("wallwood", Color.WHITE, "res://assets/textures/wallwood.png",
		Color.BLACK, false, Vector3(1, 3, 1))
	var steel := _mat("steel", Color(0.20, 0.20, 0.23))

	# area rug
	_box(Vector3(1.9, 0.02, 1.9), Vector3(0, 0.012, 0),
		_mat("rug_" + role, Color(accent.r * 0.35 + 0.18, accent.g * 0.35 + 0.18, accent.b * 0.35 + 0.20)),
		group, false)

	# back panels (cubicle-style) along north and west edges
	var glass := _mat("podglass", Color(0.72, 0.86, 0.95, 0.28), "", Color.BLACK, true)
	var panel_mat := glass if role == "director" else wood
	if role == "editor":
		panel_mat = _mat("darkpanel", Color(0.24, 0.23, 0.28))
	_box(Vector3(2.0, 1.6, 0.07), Vector3(0, 0.8, -0.96), panel_mat, group, role != "director")
	_box(Vector3(0.07, 1.6, 2.0), Vector3(-0.96, 0.8, 0), panel_mat, group, role != "director")
	# accent trim on panel tops
	_box(Vector3(2.0, 0.05, 0.09), Vector3(0, 1.62, -0.96),
		_mat("trim_" + role, accent, "", accent * 0.5), group, false)
	_box(Vector3(0.09, 0.05, 2.0), Vector3(-0.96, 1.62, 0),
		_mat("trim_" + role, accent, "", accent * 0.5), group, false)

	_desk(group, Vector3(0, 0, -0.4), 1.4, 0.65)

	match role:
		"director":
			_monitor(group, Vector3(-0.25, 0.75, -0.45), Color(0.5, 0.8, 1.0))
			_monitor(group, Vector3(0.25, 0.75, -0.45), Color(0.65, 0.9, 1.0))
		"researcher":
			# bookshelf rows on the north panel
			var spines := [Color(0.77, 0.24, 0.26), Color(0.17, 0.48, 0.32),
				Color(0.24, 0.39, 0.66), Color(0.85, 0.67, 0.24), Color(0.49, 0.28, 0.66)]
			for shelf in 2:
				_box(Vector3(1.8, 0.04, 0.16), Vector3(0, 0.7 + shelf * 0.5, -0.88), wood, group)
				for i in 10:
					var col: Color = spines[(i + shelf) % spines.size()]
					_box(Vector3(0.09, 0.26 + 0.04 * ((i + shelf) % 3), 0.12),
						Vector3(-0.8 + i * 0.17, 0.86 + shelf * 0.5, -0.88),
						_mat("spine_%d" % ((i + shelf) % spines.size()), col), group)
			_laptop(group, Vector3(-0.2, 0.755, -0.35), Color(0.65, 0.95, 0.8))
		"writer":
			for i in 3:
				_box(Vector3(0.22, 0.3, 0.015), Vector3(-0.5 + i * 0.5, 1.0, -0.92),
					_mat("paper", Color(0.95, 0.94, 0.9)), group, false)
			_laptop(group, Vector3(-0.3, 0.755, -0.4), Color(0.98, 0.95, 0.8))
			_laptop(group, Vector3(0.3, 0.755, -0.4), Color(0.98, 0.95, 0.8))
		"editor":
			_monitor(group, Vector3(-0.45, 0.75, -0.5), Color(0.55, 0.47, 1.0))
			_monitor(group, Vector3(0.0, 0.78, -0.52), Color(0.35, 0.86, 0.86))
			_monitor(group, Vector3(0.45, 0.75, -0.5), Color(1.0, 0.59, 0.7))
		"publisher":
			var notes := [Color(1.0, 0.84, 0.47), Color(1.0, 0.59, 0.7),
				Color(0.35, 0.86, 0.86), Color(0.66, 0.94, 0.78)]
			for r in 3:
				for cn in 4:
					_box(Vector3(0.13, 0.13, 0.015),
						Vector3(-0.45 + cn * 0.3, 1.25 - r * 0.25, -0.92),
						_mat("note_%d" % ((r + cn) % 4), notes[(r + cn) % 4]), group, false)
			# ring light on a stand
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.16
			torus.outer_radius = 0.22
			ring.mesh = torus
			ring.material_override = _mat("ringlight", Color(1.0, 0.9, 0.7) * 0.7, "", Color(1.0, 0.9, 0.7))
			ring.rotation_degrees = Vector3(90, 0, 0)
			ring.position = Vector3(0.45, 1.25, -0.3)
			group.add_child(ring)
			_box(Vector3(0.04, 1.05, 0.04), Vector3(0.45, 0.52, -0.3), steel, group)
			_box(Vector3(0.12, 0.24, 0.03), Vector3(0.45, 1.25, -0.3),
				_mat("phone", Color(0.3, 0.6, 0.9) * 0.6, "", Color(0.45, 0.85, 1.0)), group, false)

	# a warm pool of light over every station
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.2, 0)
	light.light_color = Color(1.0, 0.9, 0.75)
	light.omni_range = 3.2
	light.light_energy = 1.1
	light.shadow_enabled = false
	group.add_child(light)
