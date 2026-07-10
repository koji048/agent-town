## BUILD MODE (The Sims, phase 2): a categorized furniture catalog on
## the right edge — click an item to spawn it under the cursor, carry
## with grid snap, R rotates, X deletes, click sets down, Esc cancels.
## Existing pieces can be picked up the same way. Everything persists
## to user:// (moved / added / deleted) and is re-applied on boot.
class_name BuildMode
extends Node

const SAVE_PATH := "user://furniture_layout.json"
const SNAP := 0.25

## kind: chair/sofa/armchair/shelf call the office builders;
## prop goes through Office3D._prop (model + fit/y/fit_h).
const CATALOG := [
	["cat_seat", [
		[{"th": "เก้าอี้ทำงาน", "en": "Task chair"}, "chair", {}],
		[{"th": "โซฟาเทา", "en": "Sofa · gray"}, "sofa", {"col": "8c8a87"}],
		[{"th": "โซฟาเขียวเสจ", "en": "Sofa · sage"}, "sofa", {"col": "9eab91"}],
		[{"th": "อาร์มแชร์น้ำเงิน", "en": "Armchair · blue"}, "armchair", {"col": "4d619e"}],
		[{"th": "อาร์มแชร์อิฐ", "en": "Armchair · clay"}, "armchair", {"col": "cc8266"}],
	]],
	["cat_store", [
		[{"th": "ชั้นหนังสือ", "en": "Bookshelf"}, "shelf", {}],
		[{"th": "กล่องเปิด", "en": "Open box"}, "prop", {"model": "cardboardBoxOpen", "fit": 0.5}],
		[{"th": "กล่องปิด", "en": "Sealed box"}, "prop", {"model": "cardboardBoxClosed", "fit": 0.55}],
		[{"th": "ถังขยะ", "en": "Trash can"}, "prop", {"model": "trashcan", "fit_h": 0.35}],
	]],
	["cat_plant", [
		[{"th": "ต้นไม้กระถาง", "en": "Potted plant"}, "prop", {"model": "pottedPlant", "fit_h": 1.15}],
		[{"th": "กระบองเพชรเล็ก", "en": "Small cactus"}, "prop", {"model": "kaykit/cactus_small_A", "fit_h": 0.42}],
		[{"th": "กระบองเพชรกลาง", "en": "Cactus"}, "prop", {"model": "kaykit/cactus_medium_A", "fit_h": 0.6}],
	]],
	["cat_rug", [
		[{"th": "พรมผืนใหญ่", "en": "Area rug"}, "prop", {"model": "kaykit/rug_rectangle_A", "fit": 2.6}],
		[{"th": "พรมวงรี", "en": "Oval rug"}, "prop", {"model": "kaykit/rug_oval_A", "fit": 2.2}],
		[{"th": "พรมหน้าประตู", "en": "Doormat"}, "prop", {"model": "rugDoormat", "fit": 1.0}],
	]],
	["cat_gear", [
		[{"th": "แล็ปท็อป", "en": "Laptop"}, "prop", {"model": "laptop", "fit": 0.32, "y": 0.74}],
		[{"th": "จอคอม", "en": "Monitor"}, "prop", {"model": "computerScreen", "fit_h": 0.38, "y": 0.9}],
		[{"th": "คีย์บอร์ด", "en": "Keyboard"}, "prop", {"model": "computerKeyboard", "fit": 0.28, "y": 0.75}],
		[{"th": "โคมโต๊ะ", "en": "Desk lamp"}, "prop", {"model": "kaykit/lamp_table", "fit_h": 0.30, "y": 0.74}],
		[{"th": "หนังสือตั้งโต๊ะ", "en": "Book set"}, "prop", {"model": "kaykit/book_set", "fit": 0.3, "y": 0.74}],
	]],
]

var cam: Camera3D
var office: Node3D
var active := false
var carrying: Node3D = null
var _carry_new := false          # spawned from catalog, not placed yet
var _carry_entry := {}           # pending catalog entry {kind, params}
var _orig: Transform3D
var _ring: MeshInstance3D
var _ui: CanvasLayer
var _grid: GridContainer
var _cat_bar: HFlowContainer
var _cur_cat := 0
var _added_seq := 0

signal mode_changed(on: bool)


func _ready() -> void:
	_build_catalog_ui()


func toggle() -> void:
	if active and carrying:
		cancel_carry()
	active = not active
	if _ui:
		_ui.visible = active
	mode_changed.emit(active)


## Returns true when the click was consumed by build mode.
func handle_click(mpos: Vector2) -> bool:
	if not active or cam == null:
		return false
	if carrying:
		_place()
		return true
	var p := _floor_point(mpos)
	var best: Node3D = null
	var bd := 0.9
	for f in get_tree().get_nodes_in_group("furniture"):
		var fp := (f as Node3D).global_position
		var d := Vector2(fp.x - p.x, fp.z - p.z).length()
		if d < bd:
			bd = d
			best = f
	if best:
		_pick(best)
	return true


func handle_key(keycode: int) -> bool:
	if not active or carrying == null:
		return false
	if keycode == KEY_R:
		carrying.rotation_degrees.y = fposmod(carrying.rotation_degrees.y + 90.0, 360.0)
		return true
	if keycode == KEY_X or keycode == KEY_DELETE or keycode == KEY_BACKSPACE:
		_delete_carried()
		return true
	if keycode == KEY_ESCAPE:
		cancel_carry()
		return true
	return false


func _process(_delta: float) -> void:
	if not active or carrying == null or cam == null:
		return
	var p := _floor_point(get_viewport().get_mouse_position())
	carrying.position.x = snappedf(p.x, SNAP)
	carrying.position.z = snappedf(p.z, SNAP)


# ---------------------------------------------------------------- carry

func _pick(piece: Node3D) -> void:
	carrying = piece
	_carry_new = false
	_carry_entry = {}
	_orig = piece.transform
	Sfx.play_ui("paper", -10.0)
	_attach_ring()


func _place() -> void:
	if _carry_new:
		_record_added(carrying, _carry_entry)
	else:
		_save_move(carrying)
	_drop_ring()
	Sfx.play_ui("chair", -8.0)
	carrying = null
	_carry_new = false
	_carry_entry = {}


func cancel_carry() -> void:
	if carrying == null:
		return
	if _carry_new:
		carrying.queue_free()      # never placed — vanish, nothing saved
	else:
		carrying.transform = _orig
	_drop_ring()
	carrying = null
	_carry_new = false
	_carry_entry = {}


func _delete_carried() -> void:
	var id := str(carrying.get_meta("piece_id", ""))
	var layout := _load_layout()
	if _carry_new:
		pass                        # not saved yet — just free it
	elif id.begins_with("a"):       # owner-added earlier: drop its record
		var added: Array = layout.get("added", [])
		for i in range(added.size() - 1, -1, -1):
			if str(added[i].get("id", "")) == id:
				added.remove_at(i)
		layout["added"] = added
		_write_layout(layout)
	else:                           # built-in: remember it's gone
		var del: Array = layout.get("deleted", [])
		if not del.has(id):
			del.append(id)
		layout["deleted"] = del
		layout.get("moved", {}).erase(id)
		_write_layout(layout)
	carrying.queue_free()
	_drop_ring()
	Sfx.play_ui("paper", -12.0)
	carrying = null
	_carry_new = false
	_carry_entry = {}


func _attach_ring() -> void:
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.34
	t.outer_radius = 0.42
	_ring.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.78, 0.32, 0.85)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = m
	_ring.position = Vector3(0, 0.05, 0)
	carrying.add_child(_ring)


func _drop_ring() -> void:
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


func _floor_point(mpos: Vector2) -> Vector3:
	var from := cam.project_ray_origin(mpos)
	var dir := cam.project_ray_normal(mpos)
	if absf(dir.y) < 0.0001:
		return from
	var t := -from.y / dir.y
	return from + dir * t


# ------------------------------------------------------------- catalog

func _spawn(kind: String, params: Dictionary, at: Vector3) -> Node3D:
	if office == null:
		return null
	match kind:
		"chair":
			return office._task_chair(at.x, at.z, 180.0)
		"sofa":
			return office._modern_sofa(at.x, at.z, 0.0,
				Color.html(str(params.get("col", "8c8a87"))))
		"armchair":
			return office._modern_armchair(at.x, at.z, 0.0,
				Color.html(str(params.get("col", "4d619e"))))
		"shelf":
			return office._shelving(at.x, at.z, 0.0)
		"prop":
			return office._prop(str(params.get("model", "")), at.x, at.z, 0.0,
				float(params.get("fit", 1.0)), float(params.get("y", 0.0)),
				float(params.get("fit_h", 0.0)))
	return null


func _catalog_pick(kind: String, params: Dictionary) -> void:
	if carrying:
		cancel_carry()
	var at := _floor_point(get_viewport().get_visible_rect().size * 0.5)
	var node := _spawn(kind, params, at)
	if node == null:
		return
	carrying = node
	_carry_new = true
	_carry_entry = {"kind": kind, "params": params}
	Sfx.play_ui("paper", -10.0)
	_attach_ring()


func _record_added(piece: Node3D, entry: Dictionary) -> void:
	var layout := _load_layout()
	var added: Array = layout.get("added", [])
	var id := str(piece.get_meta("piece_id", ""))
	if not id.begins_with("a"):
		id = "a%03d" % _added_seq
		_added_seq += 1
		piece.set_meta("piece_id", id)
	# already placed once before? update in place
	var found := false
	for e in added:
		if str(e.get("id", "")) == id:
			e["x"] = piece.position.x
			e["z"] = piece.position.z
			e["rot"] = piece.rotation_degrees.y
			found = true
	if not found:
		added.append({"id": id, "kind": entry.get("kind", ""),
			"params": entry.get("params", {}),
			"x": piece.position.x, "z": piece.position.z,
			"rot": piece.rotation_degrees.y})
	layout["added"] = added
	_write_layout(layout)


func _save_move(piece: Node3D) -> void:
	var id := str(piece.get_meta("piece_id", ""))
	var layout := _load_layout()
	if id.begins_with("a"):         # owner-added piece moved again
		_record_added(piece, {})
		return
	var moved: Dictionary = layout.get("moved", {})
	moved[id] = {"x": piece.position.x, "z": piece.position.z,
		"rot": piece.rotation_degrees.y}
	layout["moved"] = moved
	_write_layout(layout)


# --------------------------------------------------------- persistence

static func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"moved": {}, "deleted": [], "added": []}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (d is Dictionary):
		return {"moved": {}, "deleted": [], "added": []}
	var dict: Dictionary = d
	if dict.has("moved") or dict.has("added") or dict.has("deleted"):
		if not dict.has("moved"):
			dict["moved"] = {}
		if not dict.has("deleted"):
			dict["deleted"] = []
		if not dict.has("added"):
			dict["added"] = []
		return dict
	return {"moved": dict, "deleted": [], "added": []}  # phase-1 format


static func _write_layout(layout: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(layout, "  "))


## Boot-time: re-apply the owner's whole layout — moves, deletions and
## catalog purchases (called by main once the office is furnished).
func apply_layout() -> void:
	var layout := _load_layout()
	var deleted: Array = layout.get("deleted", [])
	var moved: Dictionary = layout.get("moved", {})
	for f in get_tree().get_nodes_in_group("furniture"):
		var id := str((f as Node).get_meta("piece_id", ""))
		if deleted.has(id):
			(f as Node).queue_free()
			continue
		if moved.has(id):
			var e: Dictionary = moved[id]
			(f as Node3D).position.x = float(e.get("x", (f as Node3D).position.x))
			(f as Node3D).position.z = float(e.get("z", (f as Node3D).position.z))
			(f as Node3D).rotation_degrees.y = float(e.get("rot", 0.0))
	for e in layout.get("added", []):
		var node := _spawn(str(e.get("kind", "")), e.get("params", {}),
			Vector3(float(e.get("x", 0.0)), 0, float(e.get("z", 0.0))))
		if node:
			node.rotation_degrees.y = float(e.get("rot", 0.0))
			node.set_meta("piece_id", str(e.get("id", "")))
			var n := int(str(e.get("id", "a0")).substr(1))
			_added_seq = maxi(_added_seq, n + 1)


# ------------------------------------------------------------------ UI

func _build_catalog_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 8
	_ui.visible = false
	add_child(_ui)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.14, 0.94)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -278.0
	panel.offset_right = -16.0
	panel.offset_top = 96.0
	panel.custom_minimum_size = Vector2(262, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := Label.new()
	I18n.reg(title, "text", "build_catalog")
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	v.add_child(title)
	_cat_bar = HFlowContainer.new()
	_cat_bar.add_theme_constant_override("h_separation", 4)
	_cat_bar.add_theme_constant_override("v_separation", 4)
	v.add_child(_cat_bar)
	for i in CATALOG.size():
		var b := Button.new()
		I18n.reg(b, "text", str(CATALOG[i][0]))
		b.add_theme_font_size_override("font_size", 12)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: _show_cat(i))
		_cat_bar.add_child(b)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_grid)
	var hint := Label.new()
	I18n.reg(hint, "text", "build_keys")
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.67, 0.72))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	_show_cat(0)


func _show_cat(idx: int) -> void:
	_cur_cat = idx
	for i in _cat_bar.get_child_count():
		(_cat_bar.get_child(i) as Button).button_pressed = (i == idx)
	for c in _grid.get_children():
		c.queue_free()
	var items: Array = CATALOG[idx][1]
	for it in items:
		var names: Dictionary = it[0]
		var kind: String = it[1]
		var params: Dictionary = it[2]
		var b := Button.new()
		b.text = str(names.get(I18n.lang, names.get("th", "?")))
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(115, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: _catalog_pick(kind, params))
		_grid.add_child(b)
