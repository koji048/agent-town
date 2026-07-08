## Builds the 3D diorama office: walls from assets/map.json, real
## furniture from CC0 Kenney Furniture Kit models (assets/models/*.glb,
## loaded at runtime with procedural fallbacks) — plus the AStarGrid2D
## pathfinding agents use.
##
## Layout v2 "The Production Loop" (docs/LAYOUT_PLAN.md): a rectangular
## building wrapping a central courtyard garden. A racetrack loop corridor
## rings the courtyard and the request physically travels it,
## counterclockwise: reception/intake (NE) -> director's glass office (N)
## -> research library -> writers' room -> focus booths (W, quiet band)
## -> edit bay (enclosed, acoustic) -> studio (green screen) ->
## publishing (S band) -> up the social band (coffee bar, relax lounge)
## past the courtyard amphitheater back to the director for review.
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

# repaint Kenney models into the white/oak/beige palette
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

# Extra blocked cells (furniture + courtyard features; station anchors add
# their own 2x2 blocks). Grouped by zone.
const BLOCKED_CELLS: Array = [
	# director glass office rims (door gap at 11,4)
	[8, 4], [9, 4], [10, 4], [12, 4], [13, 4],
	[14, 1], [14, 2], [14, 3], [14, 4],
	# meeting nook table + chairs
	[3, 1], [4, 1], [3, 2], [4, 2],
	# reception: counter + plant
	[19, 2], [20, 2], [17, 1],
	# library reading chair
	[1, 8],
	# writers' room spare desk (growth bay)
	[4, 10], [5, 10],
	# focus booths
	[1, 14], [2, 14], [1, 15], [2, 15], [1, 16], [2, 16],
	# edit bay acoustic partition (entrance at x8)
	[4, 14], [5, 14], [6, 14], [7, 14],
	# studio: green screen, softbox, ring light, tripod, cart
	[10, 14], [11, 14], [12, 14], [13, 14],
	[10, 16], [12, 16], [13, 16], [14, 17],
	# publishing: storage + copier + boxes
	[20, 14], [21, 15], [21, 16],
	# coffee bar island + fridge
	[19, 6], [20, 6], [21, 5],
	# relax lounge: screens, sofa, pouf, armchair, bench, credenza, plant
	[18, 9], [19, 9], [20, 9], [21, 9],
	[18, 10], [19, 10], [20, 10], [19, 11], [18, 12],
	[17, 10], [17, 11], [17, 12],
	[20, 13], [21, 13], [17, 13],
	# courtyard features: stage/screen, amphitheater tiers, pond, trees
	[11, 7], [12, 7], [13, 7],
	[10, 11], [11, 11], [12, 11], [13, 11], [14, 11],
	[10, 12], [11, 12], [12, 12], [13, 12], [14, 12],
	[14, 8], [14, 9], [15, 8], [15, 9],
	[9, 7], [15, 7], [9, 12], [15, 12],
]

## Gathering spots on the courtyard grass, between the amphitheater
## tiers and the stage (agents celebrate here after each request).
const TOWNHALL_SPOTS: Array = [
	Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9),
	Vector2i(10, 10), Vector2i(12, 10),
]

# Courtyard region (walkable garden; used to skip ceiling luminaires)
const COURTYARD := Rect2i(9, 7, 7, 6)

## Smart objects (The Sims): the furniture advertises need satisfaction;
## agents score ads locally — zero LLM cost, zero aimless idling.
const SMART_OBJECTS: Array = [
	{"cell": Vector2i(19, 7), "need": "energy", "amount": 0.55, "line": "Espresso o'clock."},
	{"cell": Vector2i(18, 6), "need": "energy", "amount": 0.50, "line": "Coffee first, then genius."},
	{"cell": Vector2i(18, 11), "need": "social", "amount": 0.50, "line": "Five-minute couch break."},
	{"cell": Vector2i(20, 11), "need": "social", "amount": 0.50, "line": "So, how's your part going?"},
	{"cell": Vector2i(21, 10), "need": "social", "amount": 0.40, "line": "Lounge check-in."},
	{"cell": Vector2i(11, 9), "need": "inspiration", "amount": 0.60, "line": "The garden helps me think."},
	{"cell": Vector2i(10, 10), "need": "inspiration", "amount": 0.55, "line": "Fresh air, fresh hooks."},
	{"cell": Vector2i(3, 14), "need": "inspiration", "amount": 0.50, "line": "Focus booth. No pings."},
	{"cell": Vector2i(2, 8), "need": "inspiration", "amount": 0.45, "line": "A chapter from the library."},
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
	return Vector2i(11, 9)


# ------------------------------------------------------------ materials/mesh

## Measured surface physics, researched before applying (docs/MATERIAL_STUDY.md).
## Sources: physicallybased.info (albedo / IOR / metalness) + PBR roughness
## field guides. Format: [roughness, metallic, specular(F0 scale)].
const SURFACE_SPECS := {
	# glazing & water — dielectrics, near-mirror smooth
	"glass": [0.05, 0.0, 0.5],           # soda-lime, IOR 1.52
	"podglass": [0.05, 0.0, 0.5],
	"pond": [0.02, 0.0, 0.25],           # water IOR 1.333 -> F0 ~2%
	# metals — F0 comes from albedo when metallic
	"steel": [0.35, 1.0, 0.5],           # brushed stainless 0.3-0.45
	"pendant_shade": [0.45, 0.6, 0.5],   # painted metal shade
	# varnished / sealed wood: 0.3-0.45
	"oak": [0.40, 0.0, 0.5],
	"stage_top": [0.40, 0.0, 0.5],
	"tier_top": [0.45, 0.0, 0.5],
	"floor_deck": [0.45, 0.0, 0.5],
	"floor_atrium": [0.45, 0.0, 0.5],
	"studio_floor": [0.85, 0.0, 0.4],    # matte charcoal stage floor
	# mineral: sealed concrete / stone 0.7-0.9
	"floor_concrete": [0.80, 0.0, 0.5],
	"floor_concrete_dark": [0.80, 0.0, 0.5],
	"slab": [0.85, 0.0, 0.5],
	"stone": [0.85, 0.0, 0.5],
	"stone_step": [0.85, 0.0, 0.5],
	"stone_bench": [0.85, 0.0, 0.5],
	# textile — fibers scatter everything: roughness ~1, low specular
	"floor_carpet": [1.0, 0.0, 0.25],
	"partition": [0.92, 0.0, 0.3],       # felt acoustic panel
	"booth_felt": [0.92, 0.0, 0.3],
	"chair_mesh": [0.90, 0.0, 0.3],      # breathable mesh back
	"chair_seat": [0.90, 0.0, 0.3],
	"sofa_": [0.92, 0.0, 0.3],           # upholstery volumes
	"shell_": [0.40, 0.0, 0.5],          # molded shell chairs
	"spine_": [0.60, 0.0, 0.5],          # book spines
	"bench_cushion": [0.92, 0.0, 0.3],
	"cushion_": [0.92, 0.0, 0.3],
	"beanbag_": [0.95, 0.0, 0.3],
	"speaker_box": [0.85, 0.0, 0.4],     # fabric grille
	# painted drywall 0.6-0.75; laminate / coated plastic 0.3-0.5
	"wall_face": [0.70, 0.0, 0.5],
	"wall_white": [0.70, 0.0, 0.5],
	"baseboard": [0.60, 0.0, 0.5],
	"blind": [0.50, 0.0, 0.5],
	"counter_white": [0.35, 0.0, 0.5],
	"pantry_tray": [0.35, 0.0, 0.5],
	"trim_coral": [0.50, 0.0, 0.5],
	"chip_": [0.50, 0.0, 0.5],
	"printer": [0.45, 0.0, 0.5],
	"ringlight": [0.40, 0.0, 0.5],
	"screen_frame": [0.40, 0.0, 0.5],    # ABS bezel
	"screen_glow": [0.20, 0.0, 0.5],
	"pendant_bulb": [0.30, 0.0, 0.5],
	"chroma": [0.85, 0.0, 0.35],         # green-screen fabric
	"softbox": [0.60, 0.0, 0.5],
	# paper / cork pinboards
	"kanban": [0.75, 0.0, 0.5],
	"meet_art": [0.75, 0.0, 0.5],
	"mural_art": [0.75, 0.0, 0.5],
	# vegetation: waxy leaf vs matte bark/grass
	"floor_grass": [0.95, 0.0, 0.3],
	"grass": [0.95, 0.0, 0.3],
	"leafA": [0.70, 0.0, 0.4],
	"leafB": [0.70, 0.0, 0.4],
	"trunk": [0.90, 0.0, 0.5],
	# relax lounge (docs/RELAX_AREA_STUDY.md)
	"copper": [0.12, 1.0, 0.5],          # polished copper pendant globes
	"marble": [0.25, 0.0, 0.5],          # honed marble credenza top
	"walnut": [0.40, 0.0, 0.5],          # oiled walnut casework
	"slat_wood": [0.55, 0.0, 0.5],       # raw fir slats, unfinished
	"black_frame": [0.55, 0.5, 0.5],     # powder-coated steel
	"leather_tan": [0.45, 0.0, 0.4],
	"rug_ivory": [1.0, 0.0, 0.25],
	"plaid": [0.92, 0.0, 0.3],
	"plaid_band": [0.92, 0.0, 0.3],
	"basket": [0.85, 0.0, 0.35],         # woven seagrass
	"kilim_": [0.90, 0.0, 0.3],
}


func _spec_for(key: String) -> Array:
	if SURFACE_SPECS.has(key):
		return SURFACE_SPECS[key]
	for prefix in ["chip_", "cushion_", "beanbag_", "kilim_", "sofa_", "shell_", "spine_"]:
		if key.begins_with(prefix):
			return SURFACE_SPECS[prefix]
	return []


func _mat(key: String, color: Color, tex_path: String = "", emission: Color = Color.BLACK,
		transparent: bool = false, uv_scale: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if not tex_path.is_empty():
		m.albedo_texture = load(tex_path)
		var normal_path := tex_path.replace(".png", "_n.png")
		if FileAccess.file_exists(normal_path):
			m.normal_enabled = true
			m.normal_texture = load(normal_path)
			m.normal_scale = 0.8
			m.roughness = 0.62
	m.uv1_scale = uv_scale
	if m.roughness == 0.0 or not m.normal_enabled:
		m.roughness = 0.9
	var spec := _spec_for(key)
	if not spec.is_empty():
		m.roughness = spec[0]
		m.metallic = spec[1]
		m.metallic_specular = spec[2]
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
						m.roughness = 0.6   # satin-painted furniture surface
					else:
						m.albedo_color = Color(0.32, 0.32, 0.35)
						m.metallic = 0.85   # dark parts are steel legs/frames
						m.roughness = 0.4
					mi.set_surface_override_material(i, m)
	for child in node.get_children():
		_tint_meshes(child, tint)


func _instantiate_glb(model: String) -> Node3D:
	var path := "res://assets/models/%s.glb" % model
	if not FileAccess.file_exists(path):
		path = "res://assets/models/%s.gltf" % model
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


func _combined_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi: MeshInstance3D = node
		result = xform * mi.transform * mi.mesh.get_aabb()
		first = false
	var child_xform: Transform3D = xform
	if node is Node3D:
		child_xform = xform * (node as Node3D).transform
	for child in node.get_children():
		var child_aabb := _combined_aabb(child, child_xform if node is Node3D else xform)
		if child_aabb.size.length() > 0.0001:
			if first:
				result = child_aabb
				first = false
			else:
				result = result.merge(child_aabb)
	return result


# ------------------------------------------------------------ floor & walls

func _build_floor_cell(gx: int, gy: int) -> void:
	var c := str(map_rows[gy])[gx]
	var tex := "concrete"
	match c:
		",":
			tex = "concrete_dark"
		"r":
			tex = "carpet"
		"#":
			tex = "deck"
		"P":
			tex = "atrium"
		"g":
			tex = "grass"
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
	var wallmat := _mat("wall_face", Color(0.80, 0.79, 0.76))
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


# ------------------------------------------------------------ furnishing

func _furnish() -> void:
	_zone_director()
	_zone_meeting_nook()
	_zone_reception()
	_zone_library()
	_zone_writers()
	_zone_focus_booths()
	_zone_edit_bay()
	_zone_studio()
	_zone_publishing()
	_zone_coffee_bar()
	_relax_area()
	_zone_courtyard()
	_wayfinding()
	_ceiling_grid()
	_exterior()


# ============ WAYFINDING (flooring-as-wayfinding research: a high-contrast
# line marks the loop; hanging signs name every zone's purpose) ============
func _wayfinding() -> void:
	# coral guideline tracing the loop corridor's inner edge
	var line := _mat("loop_line", CORAL * 0.9, "", CORAL * 0.25)
	_box(Vector3(8.2, 0.012, 0.06), Vector3(12.5, 0.055, 6.6), line, self, false)   # north
	_box(Vector3(8.2, 0.012, 0.06), Vector3(12.5, 0.055, 13.4), line, self, false)  # south
	_box(Vector3(0.06, 0.012, 6.86), Vector3(8.4, 0.055, 10.0), line, self, false)  # west
	_box(Vector3(0.06, 0.012, 6.86), Vector3(16.6, 0.055, 10.0), line, self, false) # east
	# stone border framing the courtyard grass (crisp garden edge)
	var edge := _mat("stone_step", Color(0.78, 0.77, 0.74))
	_box(Vector3(7.2, 0.05, 0.18), Vector3(12.5, 0.028, 7.05), edge, self, false)
	_box(Vector3(7.2, 0.05, 0.18), Vector3(12.5, 0.028, 12.95), edge, self, false)
	_box(Vector3(0.18, 0.05, 6.1), Vector3(9.05, 0.028, 10.0), edge, self, false)
	_box(Vector3(0.18, 0.05, 6.1), Vector3(15.95, 0.028, 10.0), edge, self, false)
	# floor-standing zone signs at each threshold: every room declares
	# its purpose (posts sit against furniture/partitions, off the paths)
	var signs := [
		["z_reception", 21.3, 3.7], ["z_director", 12.7, 4.85], ["z_meeting", 5.5, 1.1],
		["z_library", 3.3, 5.15], ["z_writers", 3.3, 9.15], ["z_focus", 1.5, 13.35],
		["z_editbay", 8.45, 14.35], ["z_studio", 10.15, 15.1], ["z_publishing", 16.4, 14.3],
		["z_coffee", 18.5, 5.3], ["z_lounge", 21.9, 10.6],
	]
	for s in signs:
		_zone_sign(str(s[0]), Vector3(float(s[1]), 0.0, float(s[2])))


## A floor-standing signage stanchion: steel base + post, charcoal plate
## angled toward the camera, label on top.
func _zone_sign(text: String, pos: Vector3) -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	_box(Vector3(0.16, 0.03, 0.16), pos + Vector3(0, 0.015, 0), steel, self, false)
	_box(Vector3(0.025, 1.42, 0.025), pos + Vector3(0, 0.73, 0), steel, self, false)
	var plate := _box(Vector3(0.98, 0.28, 0.03), pos + Vector3(0, 1.56, 0),
		_mat("sign_plate", Color(0.14, 0.14, 0.17)), self, false)
	plate.rotation_degrees = Vector3(0, 45, 0)
	var l := Label3D.new()
	l.font = I18n.ui_font
	I18n.reg(l, "text", text)
	l.font_size = 52
	l.outline_size = 10
	l.pixel_size = 0.0046
	l.modulate = Color(0.97, 0.96, 0.92)
	l.position = pos + Vector3(0.016, 1.56, 0.016)
	l.rotation_degrees = Vector3(0, 45, 0)
	add_child(l)


# ============ 2. DIRECTOR'S GLASS OFFICE (north-center, mural backdrop,
# sight line over the loop and the courtyard) ============
func _zone_director() -> void:
	var glass := _mat("podglass", Color(0.75, 0.86, 0.94, 0.25), "", Color.BLACK, true)
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	# glass front (south) with the door gap at x11..12
	for seg in [[8.0, 11.0], [12.0, 14.5]]:
		var wdt: float = seg[1] - seg[0]
		_box(Vector3(wdt, 2.0, 0.07), Vector3((seg[0] + seg[1]) / 2.0, 1.0, 4.5), glass, self, false)
	# glass east wall
	_box(Vector3(0.07, 2.0, 4.35), Vector3(14.5, 1.0, 2.3), glass, self, false)
	for post in [[8.0, 4.5], [11.0, 4.5], [12.0, 4.5], [14.5, 4.5], [14.5, 0.25]]:
		_box(Vector3(0.09, 2.05, 0.09), Vector3(post[0], 1.02, post[1]), steel)
	# mural artwork on the north wall
	_box(Vector3(3.9, 1.5, 0.05), Vector3(10.0, 1.9, 0.21),
		_mat("mural_art", Color.WHITE, "res://assets/textures/mural_full.png"), self, false)
	_prop("kaykit/rug_rectangle_A", 10.6, 2.3, 0, 2.6)
	_modern_desk(9.5, 1.7, 1.8)
	_prop("computerScreen", 9.2, 1.6, 165, 1.0, DESK_H + 0.18, 0.40)
	_prop("computerKeyboard", 9.7, 1.95, 165, 0.3, DESK_H + 0.03)
	_task_chair(10.0, 2.6, 205)
	_credenza(13.8, 1.0, 1.3)
	_prop("kaykit/cactus_small_A", 12.9, 0.8, 0, 1.0, 0.0, 0.42)
	_pendant(Vector3(10.5, 2.4, 2.5))


# ============ MEETING NOOK (kickoff table beside the director) ============
func _zone_meeting_nook() -> void:
	_round_table(3.5, 2.0)
	_shell_chair(3.5, 1.1, 0, Color(0.88, 0.87, 0.84))
	_shell_chair(2.6, 2.7, 135, CORAL)
	_shell_chair(4.4, 2.7, 225, Color(0.35, 0.62, 0.62))
	_prop("laptop", 3.6, 1.9, 210, 0.3, DESK_H + 0.02)
	_prop("kaykit/pictureframe_large_A", 3.5, 0.24, 0, 1.0, 1.55, 0.65)
	_pendant(Vector3(3.5, 2.4, 2.0))


# ============ 1. RECEPTION + INTAKE (NE, the front door: the queue made
# visible — requests enter the building here) ============
func _zone_reception() -> void:
	var white := _mat("counter_white", Color(0.82, 0.81, 0.78))
	# INTAKE: the LIVE kanban wall — real queue state as physical cards
	var board := KanbanBoard.new()
	board.position = Vector3(19.7, 1.95, 0.22)
	add_child(board)
	# TEAM board: what every agent is doing right now
	var team := TeamBoard.new()
	team.position = Vector3(15.85, 1.95, 0.22)
	add_child(team)
	var sign := Label3D.new()
	sign.text = "INTAKE"
	sign.font_size = 64
	sign.outline_size = 14
	sign.pixel_size = 0.004
	sign.modulate = Color(0.95, 0.94, 0.9)
	sign.position = Vector3(19.7, 2.62, 0.24)
	add_child(sign)
	# reception counter: white monolith on a shadow-gap kick
	_box(Vector3(1.9, 0.08, 0.5), Vector3(19.9, 0.04, 2.9),
		_mat("black_frame", Color(0.13, 0.13, 0.14)), self, false)
	_box(Vector3(2.0, 0.86, 0.55), Vector3(19.9, 0.51, 2.9), white)
	_box(Vector3(2.1, 0.05, 0.62), Vector3(19.9, 0.965, 2.9),
		_mat("marble", Color(0.83, 0.79, 0.75)), self, false)
	_prop("laptop", 19.6, 2.8, 10, 0.32, 0.97)
	_task_chair(19.9, 2.2, 0)
	# coral doormat at the NE entrance
	var mat1 := _prop("rugDoormat", 22.4, 2.0, 90, 1.0)
	_tint_meshes(mat1, CORAL)
	_prop("pottedPlant", 17.5, 1.2, 0, 1.0, 0.0, 1.15)
	_prop("kaykit/pictureframe_medium", 17.6, 0.24, 0, 1.0, 1.7, 0.5)
	_pendant(Vector3(19.9, 2.4, 2.6))


## A modern sit-stand desk (workstation research: minimal white worktop,
## two precision steel lifting columns on widened feet, hidden cable tray).
func _modern_desk(x: float, z: float, w: float = 1.7) -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	_box(Vector3(w, 0.045, 0.78), Vector3(x, DESK_H, z),
		_mat("counter_white", Color(0.82, 0.81, 0.78)))
	for cx in [-w / 2.0 + 0.28, w / 2.0 - 0.28]:
		_box(Vector3(0.07, DESK_H - 0.06, 0.07),
			Vector3(x + cx, (DESK_H - 0.06) / 2.0, z), steel)
		_box(Vector3(0.10, 0.035, 0.58), Vector3(x + cx, 0.018, z), steel, self, false)
	_box(Vector3(w - 0.55, 0.07, 0.12), Vector3(x, DESK_H - 0.085, z - 0.27),
		_mat("black_frame", Color(0.13, 0.13, 0.14)), self, false)


## A modern ergonomic task chair: mesh back with lumbar, slim arms,
## gas lift on a five-star base. Front faces +Z (KayKit convention).
func _task_chair(x: float, z: float, rot_deg: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	root.rotation_degrees = Vector3(0, rot_deg, 0)
	add_child(root)
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	var mesh := _mat("chair_mesh", Color(0.20, 0.21, 0.24))
	var seatm := _mat("chair_seat", Color(0.26, 0.27, 0.30))
	for i in 5:
		var ang := i * TAU / 5.0
		var leg := _box(Vector3(0.27, 0.035, 0.05),
			Vector3(cos(ang) * 0.13, 0.03, sin(ang) * 0.13), steel, root, false)
		leg.rotation_degrees = Vector3(0, -rad_to_deg(ang), 0)
	_box(Vector3(0.05, 0.30, 0.05), Vector3(0, 0.21, 0), steel, root)
	_box(Vector3(0.46, 0.07, 0.44), Vector3(0, 0.45, 0), seatm, root)
	var back := _box(Vector3(0.44, 0.56, 0.045), Vector3(0, 0.77, -0.21), mesh, root)
	back.rotation_degrees = Vector3(6, 0, 0)
	_box(Vector3(0.38, 0.10, 0.03), Vector3(0, 0.60, -0.185), seatm, root, false)
	for sx in [-0.25, 0.25]:
		_box(Vector3(0.04, 0.15, 0.05), Vector3(sx, 0.545, 0.03), steel, root, false)
		_box(Vector3(0.06, 0.025, 0.24), Vector3(sx, 0.63, 0.0), seatm, root, false)


## Permanence (juice doctrine): each finished stage leaves a page on the
## agent's desk — the set dressing becomes a readable progress record.
var _desk_papers: Dictionary = {}


func add_desk_paper(role: String) -> void:
	var ws := workstation(role)
	if not _desk_papers.has(role):
		_desk_papers[role] = []
	var stack: Array = _desk_papers[role]
	if stack.size() >= 6:
		var oldest: Node = stack.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var paper := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.16, 0.008, 0.22)
	paper.mesh = pm
	paper.material_override = _mat("desk_paper", Color(0.92, 0.91, 0.87))
	var desk := grid_to_world(ws) + Vector3(randf_range(-0.45, -0.25), DESK_H + 0.03 + stack.size() * 0.009, randf_range(-1.15, -0.95))
	paper.position = desk
	paper.rotation_degrees = Vector3(0, randf_range(-25, 25), 0)
	add_child(paper)
	Juice.pop_in(paper)
	stack.append(paper)


# ---- the rest of the modern kit (procedural, measured materials) ----

## Round meeting table: white top on a steel pedestal with a disc base.
func _round_table(x: float, z: float, r: float = 0.55) -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	var top := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.04
	top.mesh = cyl
	top.material_override = _mat("counter_white", Color(0.82, 0.81, 0.78))
	top.position = Vector3(x, DESK_H, z)
	add_child(top)
	_box(Vector3(0.07, DESK_H - 0.05, 0.07), Vector3(x, (DESK_H - 0.05) / 2.0, z), steel)
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.26
	bc.bottom_radius = 0.30
	bc.height = 0.03
	base.mesh = bc
	base.material_override = steel
	base.position = Vector3(x, 0.015, z)
	add_child(base)


## Molded shell side chair on slim steel legs. Front faces +Z.
func _shell_chair(x: float, z: float, rot_deg: float, col: Color) -> void:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	root.rotation_degrees = Vector3(0, rot_deg, 0)
	add_child(root)
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	var shell := _mat("shell_%02x%02x" % [int(col.r * 255), int(col.g * 255)], col)
	for lx in [-0.16, 0.16]:
		for lz in [-0.15, 0.15]:
			_box(Vector3(0.028, 0.42, 0.028), Vector3(lx, 0.21, lz), steel, root, false)
	_box(Vector3(0.42, 0.05, 0.40), Vector3(0, 0.44, 0), shell, root)
	var back := _box(Vector3(0.40, 0.40, 0.045), Vector3(0, 0.66, -0.19), shell, root)
	back.rotation_degrees = Vector3(8, 0, 0)


## Open shelving: black steel frame, oak shelves, colored book spines.
func _shelving(x: float, z: float, rot_deg: float, w: float = 1.1, h: float = 1.8) -> void:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	root.rotation_degrees = Vector3(0, rot_deg, 0)
	add_child(root)
	var frame := _mat("black_frame", Color(0.13, 0.13, 0.14))
	var oak := _mat("oak", Color.WHITE, "res://assets/textures/deck.png")
	var spine_cols := [Color(0.77, 0.30, 0.30), Color(0.30, 0.48, 0.68),
		Color(0.86, 0.70, 0.34), Color(0.36, 0.60, 0.44), Color(0.55, 0.42, 0.62)]
	for sx in [-w / 2.0, w / 2.0]:
		_box(Vector3(0.04, h, 0.30), Vector3(sx, h / 2.0, 0), frame, root)
	for i in 4:
		var sy := 0.22 + i * (h - 0.34) / 3.0
		_box(Vector3(w - 0.06, 0.035, 0.30), Vector3(0, sy, 0), oak, root)
		if i < 3:
			var bx := -w / 2.0 + 0.14
			for b in 6:
				var bh := 0.17 + fmod(float(b * 7 + i * 3), 5.0) * 0.012
				_box(Vector3(0.042, bh, 0.15), Vector3(bx, sy + bh / 2.0 + 0.02, 0),
					_mat("spine_%d" % ((b + i) % 5), spine_cols[(b + i) % 5]), root, false)
				bx += 0.058
	_box(Vector3(0.22, 0.16, 0.16), Vector3(w / 2.0 - 0.2, h - 0.12 + 0.10, 0),
		_mat("basket", Color(0.72, 0.58, 0.38)), root, false)


## Low-profile modern sofa: boxy fabric volumes on slim steel legs,
## two throw pillows. Front faces +Z.
func _modern_sofa(x: float, z: float, rot_deg: float, col: Color, w: float = 1.75) -> void:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	root.rotation_degrees = Vector3(0, rot_deg, 0)
	add_child(root)
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	var fab := _mat("sofa_%02x%02x" % [int(col.r * 255), int(col.g * 255)], col)
	for lx in [-w / 2.0 + 0.08, w / 2.0 - 0.08]:
		for lz in [-0.3, 0.3]:
			_box(Vector3(0.03, 0.12, 0.03), Vector3(lx, 0.06, lz), steel, root, false)
	_box(Vector3(w, 0.16, 0.80), Vector3(0, 0.20, 0), fab, root)
	for cx in [-w / 4.0 + 0.02, w / 4.0 - 0.02]:
		_box(Vector3(w / 2.0 - 0.1, 0.11, 0.60), Vector3(cx, 0.33, 0.06), fab, root, false)
	_box(Vector3(w, 0.36, 0.16), Vector3(0, 0.46, -0.32), fab, root)
	for ax in [-w / 2.0 + 0.06, w / 2.0 - 0.06]:
		_box(Vector3(0.12, 0.28, 0.78), Vector3(ax, 0.42, 0), fab, root, false)
	var pil_cols := [CORAL, Color(0.30, 0.36, 0.55)]
	for i in 2:
		var p := _box(Vector3(0.30, 0.30, 0.10), Vector3(-w / 4.0 + i * w / 2.0, 0.50, -0.22),
			_mat("kilim_%d" % i, pil_cols[i]), root, false)
		p.rotation_degrees = Vector3(-10, 0, i * 8 - 4)


## Modern lounge armchair: the sofa language at one-seat width.
func _modern_armchair(x: float, z: float, rot_deg: float, col: Color) -> void:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	root.rotation_degrees = Vector3(0, rot_deg, 0)
	add_child(root)
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	var fab := _mat("sofa_%02x%02x" % [int(col.r * 255), int(col.g * 255)], col)
	for lx in [-0.32, 0.32]:
		for lz in [-0.28, 0.28]:
			_box(Vector3(0.03, 0.12, 0.03), Vector3(lx, 0.06, lz), steel, root, false)
	_box(Vector3(0.80, 0.16, 0.74), Vector3(0, 0.20, 0), fab, root)
	_box(Vector3(0.54, 0.11, 0.56), Vector3(0, 0.33, 0.04), fab, root, false)
	_box(Vector3(0.80, 0.34, 0.15), Vector3(0, 0.45, -0.29), fab, root)
	for ax in [-0.34, 0.34]:
		_box(Vector3(0.12, 0.26, 0.72), Vector3(ax, 0.41, 0), fab, root, false)


## Bar stool: steel disc base + post, round seat.
func _bar_stool(x: float, z: float) -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	for part in [[0.15, 0.025, 0.0125], [0.025, 0.60, 0.31]]:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = part[0]
		cyl.bottom_radius = part[0]
		cyl.height = part[1]
		mi.mesh = cyl
		mi.material_override = steel
		mi.position = Vector3(x, part[2], z)
		add_child(mi)
	var seat := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.17
	sc.bottom_radius = 0.17
	sc.height = 0.05
	seat.mesh = sc
	seat.material_override = _mat("chair_seat", Color(0.26, 0.27, 0.30))
	seat.position = Vector3(x, 0.63, z)
	add_child(seat)


## Small desk task lamp: steel base + angled arm + white head.
func _task_lamp(x: float, z: float, rot_deg: float, y: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(x, y, z)
	root.rotation_degrees = Vector3(0, rot_deg, 0)
	add_child(root)
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	_box(Vector3(0.09, 0.02, 0.09), Vector3(0, 0.01, 0), steel, root, false)
	var arm := _box(Vector3(0.018, 0.28, 0.018), Vector3(0.04, 0.15, 0), steel, root, false)
	arm.rotation_degrees = Vector3(0, 0, -22)
	_box(Vector3(0.13, 0.035, 0.05), Vector3(0.12, 0.285, 0),
		_mat("softbox", Color(0.95, 0.94, 0.9), "", Color(0.9, 0.88, 0.8)), root, false)


## Floor lamp: steel pole + drum shade with a warm pool.
func _floor_lamp(x: float, z: float) -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	_box(Vector3(0.18, 0.02, 0.18), Vector3(x, 0.01, z), steel, self, false)
	_box(Vector3(0.03, 1.45, 0.03), Vector3(x, 0.725, z), steel, self, false)
	var shade := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.16
	cyl.height = 0.22
	shade.mesh = cyl
	shade.material_override = _mat("pendant_bulb", Color(1.0, 0.9, 0.7) * 0.8, "", Color(1.0, 0.88, 0.65))
	shade.position = Vector3(x, 1.42, z)
	add_child(shade)
	var light := OmniLight3D.new()
	light.position = Vector3(x, 1.3, z)
	light.light_color = Color(1.0, 0.9, 0.72)
	light.omni_range = 2.4
	light.light_energy = 0.6
	light.shadow_enabled = false
	add_child(light)


## Walnut credenza with honed-marble top on black steel legs.
func _credenza(x: float, z: float, w: float = 1.5) -> void:
	_box(Vector3(w, 0.52, 0.42), Vector3(x, 0.44, z), _mat("walnut", Color(0.36, 0.25, 0.18)))
	_box(Vector3(w + 0.06, 0.04, 0.48), Vector3(x, 0.72, z),
		_mat("marble", Color(0.83, 0.79, 0.75)), self, false)
	for lp in [[-w / 2.0 + 0.1, -0.14], [-w / 2.0 + 0.1, 0.14], [w / 2.0 - 0.1, -0.14], [w / 2.0 - 0.1, 0.14]]:
		_box(Vector3(0.04, 0.18, 0.04), Vector3(x + lp[0], 0.09, z + lp[1]),
			_mat("black_frame", Color(0.13, 0.13, 0.14)), self, false)


## A standard agent station: felt partition with coral trim + role chip,
## modern sit-stand desk with dual monitors on arms, keyboard, task lamp,
## mesh task chair, trashcan. Tech props stay Kenney (KayKit has none).
func _station(role: String, sx: float, sz: float) -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	_box(Vector3(1.95, 1.25, 0.07), Vector3(sx, 0.72, sz - 0.55), _mat("partition", Color(0.82, 0.81, 0.78)))
	_box(Vector3(1.95, 0.06, 0.10), Vector3(sx, 1.38, sz - 0.55),
		_mat("trim_coral", CORAL, "", CORAL * 0.4), self, false)
	_box(Vector3(0.3, 0.06, 0.11), Vector3(sx, 1.44, sz - 0.55),
		_mat("chip_" + role, ROLE_ACCENT[role], "", (ROLE_ACCENT[role] as Color) * 0.5), self, false)
	_modern_desk(sx, sz, 1.7)
	_prop("computerScreen", sx - 0.25, sz - 0.1, 0, 1.0, DESK_H + 0.18, 0.38)
	_prop("computerScreen", sx + 0.3, sz - 0.1, 5, 1.0, DESK_H + 0.18, 0.38)
	for arm in [[sx - 0.25, sz - 0.1], [sx + 0.3, sz - 0.1]]:
		_box(Vector3(0.03, 0.22, 0.03), Vector3(arm[0], DESK_H + 0.11, arm[1]), steel, self, false)
	_prop("computerKeyboard", sx - 0.2, sz + 0.2, 180, 0.28, DESK_H + 0.03)
	_task_lamp(sx + 0.6, sz - 0.15, 200, DESK_H + 0.02)
	_task_chair(sx, sz + 0.9, 175 + randf_range(-15.0, 15.0))
	_prop("trashcan", sx - 0.75, sz + 0.85, 0, 1.0, 0.0, 0.35)


# ============ 3. RESEARCH LIBRARY (west quiet band) ============
func _zone_library() -> void:
	_station("researcher", 2.0, 6.0)
	# steel-frame shelving along the west wall + books
	_shelving(0.75, 5.6, 90)
	_shelving(0.75, 7.2, 90)
	_prop("kaykit/book_set", 2.4, 5.85, 15, 0.3, DESK_H + 0.02)
	# reading chair + floor lamp in the window corner
	_modern_armchair(1.6, 8.4, 55, Color(0.42, 0.52, 0.44))
	_floor_lamp(2.7, 8.6)
	_prop("kaykit/cactus_medium_A", 3.5, 8.5, 0, 1.0, 0.0, 0.6)


# ============ 4. WRITERS' ROOM (west quiet band) ============
func _zone_writers() -> void:
	_station("writer", 2.0, 10.0)
	# pinned pages on the partition + pinboard on the west wall
	for i in 3:
		_box(Vector3(0.16, 0.22, 0.02), Vector3(1.4 + i * 0.5, 1.05, 9.41),
			_mat("page_%d" % i, Color(0.96, 0.95, 0.9)), self, false)
	_box(Vector3(0.03, 0.6, 0.9), Vector3(0.20, 1.9, 11.0),
		_mat("kanban", Color(0.30, 0.30, 0.36)), self, false)
	# spare growth desk (Phase-3 hireable role)
	_modern_desk(4.8, 10.0, 1.6)
	_prop("kaykit/lamp_table", 5.1, 9.85, 160, 1.0, DESK_H + 0.02, 0.30)
	var hire := Label3D.new()
	hire.text = "HIRING"
	hire.font_size = 40
	hire.outline_size = 10
	hire.pixel_size = 0.004
	hire.modulate = Color(0.8, 0.78, 0.72)
	hire.position = Vector3(4.8, 1.35, 10.0)
	hire.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(hire)


# ============ 5. FOCUS BOOTHS (SW: acoustic pods, from the owner
# interview) ============
func _zone_focus_booths() -> void:
	var felt := _mat("booth_felt", Color(0.45, 0.48, 0.52))
	for bz in [14.6, 16.2]:
		_box(Vector3(0.07, 1.5, 1.15), Vector3(1.0, 0.75, bz), felt)
		_box(Vector3(1.1, 1.5, 0.07), Vector3(1.55, 0.75, bz - 0.57), felt)
		_box(Vector3(1.1, 1.5, 0.07), Vector3(1.55, 0.75, bz + 0.57), felt)
		_box(Vector3(0.9, 0.42, 0.5), Vector3(1.5, 0.21, bz + 0.22), _mat("oak", Color.WHITE, "res://assets/textures/deck.png"))
		_box(Vector3(0.9, 0.08, 0.5), Vector3(1.5, 0.46, bz + 0.22),
			_mat("bench_cushion", Color(0.88, 0.86, 0.82)), self, false)
		_box(Vector3(0.5, 0.04, 0.3), Vector3(1.4, 0.85, bz - 0.3),
			_mat("counter_white", Color(0.82, 0.81, 0.78)), self, false)
		var bl := OmniLight3D.new()
		bl.position = Vector3(1.5, 1.7, bz)
		bl.light_color = Color(1.0, 0.9, 0.72)
		bl.omni_range = 1.8
		bl.light_energy = 0.7
		bl.shadow_enabled = false
		add_child(bl)


# ============ 6. EDIT BAY (south band: enclosed, dark, acoustic —
# production-studio research) ============
func _zone_edit_bay() -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	# acoustic partition along the north edge (entrance at x8)
	_box(Vector3(4.0, 1.6, 0.09), Vector3(6.0, 0.8, 14.45), _mat("partition", Color(0.82, 0.81, 0.78)))
	_box(Vector3(4.0, 0.06, 0.12), Vector3(6.0, 1.63, 14.45),
		_mat("trim_coral", CORAL, "", CORAL * 0.4), self, false)
	_box(Vector3(0.3, 0.06, 0.13), Vector3(6.0, 1.70, 14.45),
		_mat("chip_editor", ROLE_ACCENT["editor"], "", (ROLE_ACCENT["editor"] as Color) * 0.5), self, false)
	# acoustic foam tiles on the partition's south face
	for i in 5:
		_box(Vector3(0.5, 0.5, 0.04), Vector3(4.4 + i * 0.8, 0.85, 14.52),
			_mat("booth_felt", Color(0.45, 0.48, 0.52)), self, false)
	# the editor's desk: triple monitors, waveform glow
	_modern_desk(6.0, 16.0, 1.8)
	var glow_cols := [Color(0.55, 0.47, 1.0), Color(0.35, 0.86, 0.86), Color(1.0, 0.59, 0.7)]
	for i in 3:
		var mx := 5.45 + i * 0.55
		_prop("computerScreen", mx, 15.9, i * 4 - 4, 1.0, DESK_H + 0.18, 0.38)
		_box(Vector3(0.03, 0.22, 0.03), Vector3(mx, DESK_H + 0.11, 15.9), steel, self, false)
		_box(Vector3(0.26, 0.15, 0.01), Vector3(mx, DESK_H + 0.30, 15.83),
			_mat("wave_%d" % i, glow_cols[i] * 0.5, "", glow_cols[i] * 0.7), self, false)
	_prop("computerKeyboard", 5.9, 16.25, 180, 0.28, DESK_H + 0.03)
	_task_chair(6.0, 16.9, 178)
	_prop("trashcan", 4.6, 17.5, 0, 1.0, 0.0, 0.35)
	# dim warm pendant instead of office panels (dark room)
	_pendant(Vector3(6.0, 2.3, 17.0))


# ============ 7. STUDIO (south-center: green screen, ring light, 9:16
# phone rig — right beside the edit bay) ============
func _zone_studio() -> void:
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	var chroma := _mat("chroma", Color(0.28, 0.78, 0.31))
	# matte charcoal stage floor zones the studio off the concrete
	_box(Vector3(5.0, 0.015, 4.9), Vector3(12.0, 0.008, 16.5),
		_mat("studio_floor", Color(0.24, 0.24, 0.27)), self, false)
	# green-screen backdrop with floor spill
	_box(Vector3(4.0, 2.2, 0.09), Vector3(12.0, 1.1, 14.45), chroma)
	_box(Vector3(4.0, 0.02, 1.3), Vector3(12.0, 0.022, 15.15), chroma, self, false)
	var onair := Label3D.new()
	onair.text = "ON AIR"
	onair.font_size = 52
	onair.outline_size = 12
	onair.pixel_size = 0.004
	onair.modulate = CORAL
	onair.position = Vector3(12.0, 2.42, 14.52)
	add_child(onair)
	# ring light + vertical phone rig
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.21
	ring.mesh = torus
	ring.material_override = _mat("ringlight", Color(1.0, 0.9, 0.7) * 0.7, "", Color(1.0, 0.9, 0.7))
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(12.5, 1.25, 16.4)
	add_child(ring)
	_box(Vector3(0.04, 1.05, 0.04), Vector3(12.5, 0.52, 16.4), steel)
	_box(Vector3(0.10, 0.2, 0.02), Vector3(12.5, 1.25, 16.36),
		_mat("screen_frame", Color(0.16, 0.16, 0.19)), self, false)
	# softbox on a stand
	_box(Vector3(0.04, 1.5, 0.04), Vector3(10.6, 0.75, 16.4), steel)
	var soft := _box(Vector3(0.5, 0.65, 0.06), Vector3(10.75, 1.62, 16.25),
		_mat("softbox", Color(0.95, 0.94, 0.9), "", Color(0.9, 0.88, 0.8)))
	soft.rotation_degrees = Vector3(-18, 25, 0)
	var skey := OmniLight3D.new()
	skey.position = Vector3(11.4, 1.5, 15.9)
	skey.light_color = Color(1.0, 0.96, 0.88)
	skey.omni_range = 2.6
	skey.light_energy = 0.8
	skey.shadow_enabled = false
	add_child(skey)
	# tripod camera
	for leg in 3:
		var ang := leg * TAU / 3.0
		var lb := _box(Vector3(0.03, 1.0, 0.03),
			Vector3(13.5 + cos(ang) * 0.18, 0.5, 16.6 + sin(ang) * 0.18), steel)
		lb.rotation_degrees = Vector3(cos(ang) * 12, 0, sin(ang) * 12)
	_box(Vector3(0.22, 0.16, 0.3), Vector3(13.5, 1.05, 16.6),
		_mat("screen_frame", Color(0.16, 0.16, 0.19)))
	# steel equipment cart
	for px in [-0.22, 0.22]:
		for pz in [-0.18, 0.18]:
			_box(Vector3(0.025, 0.72, 0.025), Vector3(14.5 + px, 0.36, 17.5 + pz), steel)
	for sy in [0.12, 0.70]:
		_box(Vector3(0.52, 0.03, 0.42), Vector3(14.5, sy, 17.5), steel, self, false)
	_prop("cardboardBoxOpen", 14.5, 17.5, 20, 0.5, 0.72)


# ============ 8. PUBLISHING (SE: straight out of the studio) ============
func _zone_publishing() -> void:
	_station("publisher", 18.0, 16.0)
	# storage + copier along the east side
	_shelving(20.5, 14.55, 0)
	_box(Vector3(0.55, 0.72, 0.5), Vector3(21.6, 0.36, 15.5),
		_mat("counter_white", Color(0.82, 0.81, 0.78)))
	_box(Vector3(0.5, 0.4, 0.55), Vector3(21.6, 0.95, 15.5), _mat("printer", Color(0.86, 0.85, 0.82)))
	_prop("cardboardBoxClosed", 21.5, 16.6, 15, 0.55)
	_pendant(Vector3(18.0, 2.4, 15.6))


# ============ COFFEE BAR (east band, the loop midpoint — every daily
# path passes it) ============
func _zone_coffee_bar() -> void:
	# island counter: white body on a shadow-gap kick, oak worktop
	_box(Vector3(1.9, 0.08, 0.58), Vector3(19.7, 0.04, 6.2),
		_mat("black_frame", Color(0.13, 0.13, 0.14)), self, false)
	_box(Vector3(2.1, 0.82, 0.70), Vector3(19.7, 0.49, 6.2),
		_mat("counter_white", Color(0.82, 0.81, 0.78)))
	_box(Vector3(2.2, 0.05, 0.80), Vector3(19.7, 0.925, 6.2),
		_mat("oak", Color.WHITE, "res://assets/textures/deck.png"), self, false)
	_prop("kitchenCoffeeMachine", 19.2, 6.2, 0, 1.0, 0.95, 0.35)
	_box(Vector3(0.5, 0.16, 0.3), Vector3(20.2, 1.03, 6.15),
		_mat("pantry_tray", Color(0.85, 0.80, 0.72)), self, false)
	_prop("kitchenFridgeSmall", 21.7, 5.5, 180, 1.0, 0.0, 1.1)
	_bar_stool(19.2, 7.3)
	_bar_stool(20.2, 7.3)
	_bar_stool(18.3, 6.3)
	_pendant(Vector3(19.7, 2.4, 6.2))
	_pendant(Vector3(21.0, 2.4, 5.6))


# ------------------------------------------------------------ relax lounge
# From the user's reference photo (industrial-Scandinavian breakout area) +
# breakout-space research (docs/RELAX_AREA_STUDY.md). In v2 it sits on the
# social deck against the courtyard: slat screens close the north edge,
# the window bench looks west over the garden.
func _relax_area() -> void:
	var oak := _mat("oak", Color.WHITE, "res://assets/textures/deck.png")
	var steel := _mat("steel", Color(0.42, 0.42, 0.46))
	# oval rug under the seating group
	_prop("kaykit/rug_oval_A", 19.5, 11.4, 0, 2.6)
	# diagonal wood-slat screens (north edge, semi-enclosure from coffee)
	_slat_screen(Vector3(18.45, 0, 9.42), 1.8)
	_slat_screen(Vector3(20.3, 0, 9.42), 1.8)
	# modern sofa with throw pillows, back to the screens
	_modern_sofa(19.5, 10.15, 0, Color(0.55, 0.54, 0.53))
	var kilim_cols := [Color(0.80, 0.35, 0.28), Color(0.85, 0.66, 0.30), Color(0.30, 0.36, 0.55)]
	# indigo lounge armchair + tan leather ottoman
	_modern_armchair(18.05, 12.15, 75, Color(0.30, 0.38, 0.62))
	_box(Vector3(0.5, 0.26, 0.4), Vector3(18.85, 0.16, 12.35),
		_mat("leather_tan", Color(0.62, 0.44, 0.28)), self, false)
	# plaid round pouf at the center of the group
	var pouf := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.34
	pc.bottom_radius = 0.36
	pc.height = 0.34
	pouf.mesh = pc
	pouf.material_override = _mat("plaid", Color(0.78, 0.60, 0.42))
	pouf.position = Vector3(19.5, 0.17, 11.55)
	add_child(pouf)
	_box(Vector3(0.52, 0.02, 0.52), Vector3(19.5, 0.345, 11.55),
		_mat("plaid_band", Color(0.55, 0.38, 0.30)), self, false)
	# copper globe pendant cluster (staggered drops) + one warm pool
	for g in [[19.2, 2.25, 11.2, 0.15], [19.55, 2.02, 11.5, 0.18], [19.92, 2.3, 11.8, 0.13]]:
		var globe := MeshInstance3D.new()
		var gs := SphereMesh.new()
		gs.radius = g[3]
		gs.height = g[3] * 2.0
		globe.mesh = gs
		globe.material_override = _mat("copper", Color(0.93, 0.62, 0.52))
		globe.position = Vector3(g[0], g[1], g[2])
		add_child(globe)
		_box(Vector3(0.02, 3.0 - g[1] - g[3], 0.02),
			Vector3(g[0], (3.0 + g[1] + g[3]) / 2.0, g[2]), steel, self, false)
	var warm := OmniLight3D.new()
	warm.position = Vector3(19.55, 1.8, 11.5)
	warm.light_color = Color(1.0, 0.85, 0.65)
	warm.omni_range = 3.4
	warm.light_energy = 0.7
	warm.shadow_enabled = false
	add_child(warm)
	# window bench facing the courtyard (prospect over the garden)
	_box(Vector3(0.55, 0.42, 2.4), Vector3(17.45, 0.21, 11.5), oak)
	_box(Vector3(0.55, 0.10, 2.4), Vector3(17.45, 0.47, 11.5),
		_mat("bench_cushion", Color(0.88, 0.86, 0.82)), self, false)
	var wp1 := _prop("kaykit/pillow_A", 17.45, 10.65, 70, 0.4, 0.52)
	_tint_meshes(wp1, kilim_cols[0])
	var wp2 := _prop("kaykit/pillow_B", 17.45, 12.35, -70, 0.4, 0.52)
	_tint_meshes(wp2, kilim_cols[2])
	# walnut credenza with honed-marble top on black steel legs
	_credenza(20.9, 13.42)
	_prop("kaykit/cactus_small_A", 20.5, 13.42, 0, 1.0, 0.74, 0.24)
	# woven basket + the big biophilic corner plant
	var bask := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.22
	bc.bottom_radius = 0.16
	bc.height = 0.36
	bask.mesh = bc
	bask.material_override = _mat("basket", Color(0.72, 0.58, 0.38))
	bask.position = Vector3(21.9, 0.18, 13.35)
	add_child(bask)
	_prop("pottedPlant", 17.3, 13.3, 0, 1.0, 0.0, 1.15)


# ============ THE COURTYARD (walkable garden core: stage + screen on the
# north rim, amphitheater tiers on the south — the town hall lives in the
# garden, Google-campus style) ============
func _zone_courtyard() -> void:
	var oak := _mat("oak", Color.WHITE, "res://assets/textures/deck.png")
	# stage on the north rim
	_box(Vector3(3.0, 0.26, 1.0), Vector3(12.5, 0.13, 7.5), oak)
	_box(Vector3(3.1, 0.05, 1.1), Vector3(12.5, 0.28, 7.5),
		_mat("stage_top", Color(0.80, 0.75, 0.67)), self, false)
	_prop("laptop", 11.4, 7.5, 180, 0.32, 0.31)
	# the big screen facing the tiers (the TGIF backdrop)
	_box(Vector3(3.2, 1.9, 0.09), Vector3(12.5, 1.55, 7.1), _mat("screen_frame", Color(0.16, 0.16, 0.19)))
	_box(Vector3(2.9, 1.6, 0.04), Vector3(12.5, 1.55, 7.17),
		_mat("screen_glow", Color(0.35, 0.42, 0.55) * 0.8, "", Color(0.45, 0.55, 0.75)), self, false)
	_box(Vector3(2.4, 0.28, 0.05), Vector3(12.5, 2.6, 7.14),
		_mat("trim_coral", CORAL, "", CORAL * 0.4), self, false)
	var hall_title := Label3D.new()
	hall_title.text = "ALL-HANDS"
	hall_title.font_size = 96
	hall_title.outline_size = 20
	hall_title.pixel_size = 0.004
	hall_title.modulate = Color(0.95, 0.94, 0.9)
	hall_title.position = Vector3(12.5, 1.55, 7.22)
	add_child(hall_title)
	# speakers flanking the stage
	_box(Vector3(0.35, 0.95, 0.35), Vector3(10.6, 0.47, 7.4), _mat("speaker_box", Color(0.2, 0.2, 0.23)))
	_box(Vector3(0.35, 0.95, 0.35), Vector3(14.4, 0.47, 7.4), _mat("speaker_box", Color(0.2, 0.2, 0.23)))
	# two amphitheater tiers facing the stage, Google-color cushions
	var cushion_cols := [Color(0.26, 0.52, 0.96), Color(0.92, 0.26, 0.21), Color(0.98, 0.74, 0.02), Color(0.20, 0.66, 0.33)]
	for tier in 2:
		var tz := 11.5 + tier
		var th := 0.24 * (2 - tier)
		_box(Vector3(5.0, th, 1.0), Vector3(12.5, th / 2.0, tz), oak)
		_box(Vector3(5.05, 0.05, 1.02), Vector3(12.5, th + 0.02, tz),
			_mat("tier_top", Color(0.83, 0.68, 0.5)), self, false)
		for ci in 4:
			_box(Vector3(0.6, 0.07, 0.55), Vector3(10.7 + ci * 1.25, th + 0.07, tz),
				_mat("cushion_%d" % ((ci + tier) % 4), cushion_cols[(ci + tier) % 4]), self, false)
	# pond on the east side + stones
	var pond := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 1.05
	pcyl.bottom_radius = 1.05
	pcyl.height = 0.06
	pond.mesh = pcyl
	pond.material_override = _mat("pond", Color(0.47, 0.67, 0.76))
	pond.position = Vector3(15.0, 0.03, 9.0)
	add_child(pond)
	for i in 8:
		var ang := i * TAU / 8.0
		_bush_stone(Vector3(15.0 + cos(ang) * (1.12 + randf_range(0.0, 0.1)), 0.03,
			9.0 + sin(ang) * (1.12 + randf_range(0.0, 0.1))))
	# corner trees + bushes
	_tree(Vector3(9.5, 0.0, 7.5), 0.95)
	_tree(Vector3(15.5, 0.0, 7.4), 0.85)
	_tree(Vector3(9.5, 0.0, 12.5), 1.05)
	_tree(Vector3(15.5, 0.0, 12.5), 0.9)
	_bush(Vector3(9.6, 0.0, 9.6))
	_bush(Vector3(13.9, 0.0, 10.3))
	# stepping stones from the west and east entries toward the center
	for step in [[9.4, 10.1], [10.2, 10.0], [11.0, 9.9], [13.6, 9.7], [14.2, 10.3]]:
		_box(Vector3(0.6, 0.06, 0.45), Vector3(step[0], 0.03, step[1]),
			_mat("stone_step", Color(0.78, 0.77, 0.74)), self, false)


# ============ CEILING LIGHT GRID (invisible office luminaires; none over
# the open courtyard, dim in the edit bay) ============
func _ceiling_grid() -> void:
	for lx in [2.0, 5.0, 8.0, 11.0, 14.0, 17.0, 20.0, 22.5]:
		for lz in [2.0, 6.0, 10.0, 14.0, 17.5]:
			if COURTYARD.has_point(Vector2i(int(lx), int(lz))):
				continue
			if lx > 3.9 and lx < 8.6 and lz > 13.9:
				continue  # edit bay keeps its own dim pendant
			_ceiling_panel(Vector3(lx, 2.92, lz))


# ============ EXTERIOR LANDSCAPE ============
func _exterior() -> void:
	_box(Vector3(76.0, 0.06, 76.0), Vector3(12.0, -0.58, 10.0),
		_mat("grass", Color(0.42, 0.54, 0.31)), self, false)
	for tx in [2.5, 6.5, 10.0, 14.5, 18.0, 21.5]:
		_tree(Vector3(tx, -0.55, -1.6), randf_range(0.9, 1.25))
	for tz in [3.0, 7.5, 12.0, 16.5]:
		_tree(Vector3(-1.7, -0.55, tz), randf_range(0.9, 1.2))
	_tree(Vector3(25.6, -0.55, 2.5), 1.1)
	_tree(Vector3(6.0, -0.55, 21.9), 1.25)
	_tree(Vector3(16.0, -0.55, 21.5), 1.0)
	for bpos in [[1.2, -0.9], [8.5, -0.9], [16.0, -0.9], [-0.9, 5.5], [-0.9, 9.8], [-0.9, 14.5], [3.5, 20.9], [20.5, 20.5]]:
		_bush(Vector3(bpos[0], -0.55, bpos[1]))
	# entrance path from the world to the reception door (NE)
	for i in 3:
		_box(Vector3(0.9, 0.08, 0.6), Vector3(24.6 + i * 0.9, -0.51, 2.0),
			_mat("stone_step", Color(0.78, 0.77, 0.74)), self, false)


## A slat privacy screen: black powder-coated frame, parallel diagonal
## fir slats (the reference's signature divider).
func _slat_screen(pos: Vector3, w: float) -> void:
	var frame := _mat("black_frame", Color(0.13, 0.13, 0.14))
	var slat := _mat("slat_wood", Color(0.78, 0.62, 0.42))
	var h := 1.9
	for sx in [-w / 2.0, w / 2.0]:
		_box(Vector3(0.06, h, 0.06), pos + Vector3(sx, h / 2.0, 0), frame)
	_box(Vector3(w, 0.05, 0.05), pos + Vector3(0, h - 0.025, 0), frame, self, false)
	_box(Vector3(w, 0.05, 0.05), pos + Vector3(0, 0.025, 0), frame, self, false)
	for row in 3:
		var ry := 0.45 + row * 0.5
		var xo := fmod(row * 0.14, 0.28)
		var x := -w / 2.0 + 0.18 + xo
		while x < w / 2.0 - 0.12:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.62, 0.045, 0.03)
			mi.mesh = bm
			mi.material_override = slat
			mi.position = pos + Vector3(x, ry, 0)
			mi.rotation_degrees = Vector3(0, 0, -38)
			add_child(mi)
			x += 0.28


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
	light.light_energy = 0.7
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


## An invisible office luminaire: soft warm-neutral pool from the ceiling
## plane (no fixture geometry — the diorama has no ceiling). Energy tuned
## for ~300-500 lux office feel: overlapping fixtures stack, so each one
## stays gentle.
func _ceiling_panel(pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, -0.2, 0)
	l.light_color = Color(1.0, 0.97, 0.9)
	l.omni_range = 4.2
	l.light_energy = 0.55
	l.shadow_enabled = false
	add_child(l)
