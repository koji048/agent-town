## BUILD MODE (The Sims): a full categorized catalog — seating, tables,
## storage, lighting, plants, decor, gadgets, FLOOR PAINT and WALLS.
## Click a card to spawn+carry (R rotate, X delete, Esc cancel), click a
## floor style then paint tiles one click at a time. Existing furniture
## can be picked up too. Everything persists to user:// and is re-applied
## on boot: moved pieces, deletions, purchases, painted floors.
class_name BuildMode
extends Node

const SAVE_PATH := "user://furniture_layout.json"
const SNAP := 0.25

## kinds: chair/sofa/armchair/shelf = procedural office builders,
## prop = Office3D._prop (normalized fit), glb = native-scale model,
## wall = procedural partition, floor = tile paint style.
const CATALOG := [
	["cat_seat", [
		[{"th": "เก้าอี้ทำงาน", "en": "Task chair"}, "chair", {}],
		[{"th": "โซฟาเทา", "en": "Sofa gray"}, "sofa", {"col": "8c8a87"}],
		[{"th": "โซฟาเขียวเสจ", "en": "Sofa sage"}, "sofa", {"col": "9eab91"}],
		[{"th": "อาร์มแชร์น้ำเงิน", "en": "Armchair blue"}, "armchair", {"col": "4d619e"}],
		[{"th": "อาร์มแชร์อิฐ", "en": "Armchair clay"}, "armchair", {"col": "cc8266"}],
		[{"th": "เลานจ์แชร์", "en": "Lounge chair"}, "glb", {"model": "loungeChair"}],
		[{"th": "โซฟาเลานจ์", "en": "Lounge sofa"}, "glb", {"model": "loungeSofa"}],
		[{"th": "เก้าอี้เบาะนวม", "en": "Cushion chair"}, "glb", {"model": "chairModernCushion"}],
		[{"th": "เก้าอี้ไม้", "en": "Chair"}, "glb", {"model": "chair"}],
		[{"th": "เก้าอี้โต๊ะทำงาน", "en": "Desk chair"}, "glb", {"model": "chairDesk"}],
		[{"th": "ม้านั่งเบาะ", "en": "Bench"}, "glb", {"model": "benchCushionLow"}],
		[{"th": "สตูลบาร์", "en": "Bar stool"}, "glb", {"model": "stoolBar"}],
		[{"th": "เก้าอี้คอทเทจ", "en": "Cottage chair"}, "glb", {"model": "kaykit/chair_A"}],
		[{"th": "เก้าอี้ไม้เข้ม", "en": "Wood chair"}, "glb", {"model": "kaykit/chair_A_wood"}],
		[{"th": "เก้าอี้หลังสูง", "en": "Tall chair"}, "glb", {"model": "kaykit/chair_B"}],
		[{"th": "สตูลไม้", "en": "Wood stool"}, "glb", {"model": "kaykit/chair_stool_wood"}],
		[{"th": "อาร์มแชร์หมอน", "en": "Pillow armchair"}, "glb", {"model": "kaykit/armchair_pillows"}],
		[{"th": "โซฟาหมอน", "en": "Pillow couch"}, "glb", {"model": "kaykit/couch_pillows"}],
	]],
	["cat_table", [
		[{"th": "โต๊ะทำงาน", "en": "Desk"}, "glb", {"model": "desk"}],
		[{"th": "โต๊ะเข้ามุม", "en": "Corner desk"}, "glb", {"model": "deskCorner"}],
		[{"th": "โต๊ะอาหาร", "en": "Table"}, "glb", {"model": "table"}],
		[{"th": "โต๊ะกลม", "en": "Round table"}, "glb", {"model": "tableRound"}],
		[{"th": "โต๊ะกาแฟ", "en": "Coffee table"}, "glb", {"model": "tableCoffee"}],
		[{"th": "โต๊ะข้าง", "en": "Side table"}, "glb", {"model": "sideTable"}],
		[{"th": "โต๊ะข้างลิ้นชัก", "en": "Side drawers"}, "glb", {"model": "sideTableDrawers"}],
		[{"th": "โต๊ะเตี้ย", "en": "Low table"}, "glb", {"model": "kaykit/table_low"}],
		[{"th": "โต๊ะกลาง", "en": "Medium table"}, "glb", {"model": "kaykit/table_medium"}],
		[{"th": "โต๊ะยาว", "en": "Long table"}, "glb", {"model": "kaykit/table_medium_long"}],
		[{"th": "โต๊ะเล็ก", "en": "Small table"}, "glb", {"model": "kaykit/table_small"}],
		[{"th": "เคาน์เตอร์บาร์", "en": "Kitchen bar"}, "glb", {"model": "kitchenBar"}],
		[{"th": "ปลายเคาน์เตอร์", "en": "Bar end"}, "glb", {"model": "kitchenBarEnd"}],
	]],
	["cat_store", [
		[{"th": "ชั้นหนังสือ", "en": "Bookshelf"}, "shelf", {}],
		[{"th": "ตู้หนังสือทึบ", "en": "Closed bookcase"}, "glb", {"model": "bookcaseClosedWide"}],
		[{"th": "ตู้หนังสือโปร่ง", "en": "Open bookcase"}, "glb", {"model": "bookcaseOpen"}],
		[{"th": "ตู้หนังสือเตี้ย", "en": "Low bookcase"}, "glb", {"model": "bookcaseOpenLow"}],
		[{"th": "ตู้ทีวี", "en": "TV cabinet"}, "glb", {"model": "cabinetTelevision"}],
		[{"th": "ตู้ครัว", "en": "Kitchen cabinet"}, "glb", {"model": "kitchenCabinet"}],
		[{"th": "ราวแขวนเสื้อ", "en": "Coat rack"}, "glb", {"model": "coatRackStanding"}],
		[{"th": "ตู้เล็ก", "en": "Small cabinet"}, "glb", {"model": "kaykit/cabinet_small"}],
		[{"th": "ตู้กลาง", "en": "Cabinet"}, "glb", {"model": "kaykit/cabinet_medium"}],
		[{"th": "ตู้แต่งลาย", "en": "Decorated cabinet"}, "glb", {"model": "kaykit/cabinet_medium_decorated"}],
		[{"th": "ชั้นใหญ่", "en": "Big shelf"}, "glb", {"model": "kaykit/shelf_A_big"}],
		[{"th": "ชั้นเล็ก", "en": "Small shelf"}, "glb", {"model": "kaykit/shelf_A_small"}],
		[{"th": "ชั้นโชว์ของ", "en": "Display shelf"}, "glb", {"model": "kaykit/shelf_B_large_decorated"}],
		[{"th": "กล่องเปิด", "en": "Open box"}, "prop", {"model": "cardboardBoxOpen", "fit": 0.5}],
		[{"th": "กล่องปิด", "en": "Sealed box"}, "prop", {"model": "cardboardBoxClosed", "fit": 0.55}],
		[{"th": "ถังขยะ", "en": "Trash can"}, "prop", {"model": "trashcan", "fit_h": 0.35}],
	]],
	["cat_light", [
		[{"th": "โคมตั้งพื้นกลม", "en": "Floor lamp"}, "glb", {"model": "lampRoundFloor", "light": 1.4}],
		[{"th": "โคมตั้งพื้นสูง", "en": "Standing lamp"}, "glb", {"model": "kaykit/lamp_standing", "light": 1.5}],
		[{"th": "โคมโต๊ะเหลี่ยม", "en": "Table lamp"}, "glb", {"model": "lampSquareTable", "light": 0.5, "y": 0.74}],
		[{"th": "โคมโต๊ะ", "en": "Desk lamp"}, "glb", {"model": "kaykit/lamp_table", "light": 0.5, "y": 0.74}],
	]],
	["cat_plant", [
		[{"th": "ต้นไม้กระถาง", "en": "Potted plant"}, "prop", {"model": "pottedPlant", "fit_h": 1.15}],
		[{"th": "ไม้กระถางเล็ก 1", "en": "Small plant 1"}, "glb", {"model": "plantSmall1"}],
		[{"th": "ไม้กระถางเล็ก 2", "en": "Small plant 2"}, "glb", {"model": "plantSmall2"}],
		[{"th": "ไม้แขวน", "en": "Hanging plant"}, "glb", {"model": "plantSmall3"}],
		[{"th": "กระบองเพชรเล็ก", "en": "Small cactus"}, "prop", {"model": "kaykit/cactus_small_A", "fit_h": 0.42}],
		[{"th": "กระบองเพชรกลาง", "en": "Cactus"}, "prop", {"model": "kaykit/cactus_medium_A", "fit_h": 0.6}],
	]],
	["cat_decor", [
		[{"th": "พรมผืนใหญ่", "en": "Area rug"}, "glb", {"model": "rugRectangle"}],
		[{"th": "พรมกลม", "en": "Round rug"}, "glb", {"model": "rugRound"}],
		[{"th": "พรมเหลี่ยม", "en": "Square rug"}, "glb", {"model": "rugSquare"}],
		[{"th": "พรมหน้าประตู", "en": "Doormat"}, "glb", {"model": "rugDoormat"}],
		[{"th": "พรมวงรี", "en": "Oval rug"}, "prop", {"model": "kaykit/rug_oval_A", "fit": 2.2}],
		[{"th": "พรมลายทาง", "en": "Striped rug"}, "prop", {"model": "kaykit/rug_rectangle_stripes_A", "fit": 2.4}],
		[{"th": "หมอนขาว", "en": "Pillow"}, "glb", {"model": "pillow"}],
		[{"th": "หมอนน้ำเงิน", "en": "Blue pillow"}, "glb", {"model": "pillowBlue"}],
		[{"th": "หมอนคอทเทจ", "en": "Cottage pillow"}, "glb", {"model": "kaykit/pillow_A"}],
		[{"th": "กองหนังสือ", "en": "Books"}, "glb", {"model": "books", "y": 0.74}],
		[{"th": "หนังสือตั้งโต๊ะ", "en": "Book set"}, "prop", {"model": "kaykit/book_set", "fit": 0.3, "y": 0.74}],
		[{"th": "กรอบรูปตั้งโต๊ะ", "en": "Standing frame"}, "prop", {"model": "kaykit/pictureframe_standing_A", "fit": 0.25, "y": 0.74}],
	]],
	["cat_gear", [
		[{"th": "แล็ปท็อป", "en": "Laptop"}, "prop", {"model": "laptop", "fit": 0.32, "y": 0.74}],
		[{"th": "จอคอม", "en": "Monitor"}, "prop", {"model": "computerScreen", "fit_h": 0.38, "y": 0.74}],
		[{"th": "คีย์บอร์ด", "en": "Keyboard"}, "prop", {"model": "computerKeyboard", "fit": 0.28, "y": 0.74}],
		[{"th": "เมาส์", "en": "Mouse"}, "glb", {"model": "computerMouse", "y": 0.74}],
		[{"th": "ทีวีจอแบน", "en": "Television"}, "glb", {"model": "televisionModern", "y": 0.5}],
		[{"th": "ลำโพงตั้งพื้น", "en": "Speaker"}, "glb", {"model": "speaker"}],
		[{"th": "เครื่องชงกาแฟ", "en": "Coffee machine"}, "glb", {"model": "kitchenCoffeeMachine", "y": 0.9}],
		[{"th": "ตู้เย็นเล็ก", "en": "Small fridge"}, "glb", {"model": "kitchenFridgeSmall"}],
	]],
	["cat_floor", [
		[{"th": "ไม้เด็ค", "en": "Wood deck"}, "floor", {"tex": "deck"}],
		[{"th": "คอนกรีต", "en": "Concrete"}, "floor", {"tex": "concrete"}],
		[{"th": "คอนกรีตเข้ม", "en": "Dark concrete"}, "floor", {"tex": "concrete_dark"}],
		[{"th": "พรมฟ้าเทา", "en": "Blue carpet"}, "floor", {"tex": "carpet"}],
		[{"th": "หินขัด", "en": "Terrazzo"}, "floor", {"tex": "atrium"}],
		[{"th": "หญ้า", "en": "Grass"}, "floor", {"tex": "grass"}],
		[{"th": "หินอ่อนขาว", "en": "White marble"}, "floor", {"col": "e8e6e1"}],
		[{"th": "พรมแดงอิฐ", "en": "Clay carpet"}, "floor", {"col": "b3705c"}],
		[{"th": "พรมเขียวเสจ", "en": "Sage carpet"}, "floor", {"col": "8fa287"}],
		[{"th": "ดำด้าน", "en": "Matte black"}, "floor", {"col": "2b2c30"}],
	]],
	["cat_wall", [
		[{"th": "ผนังทึบ 2 ม.", "en": "Wall 2m"}, "wall", {"w": 2.0}],
		[{"th": "ผนังทึบ 1 ม.", "en": "Wall 1m"}, "wall", {"w": 1.0}],
		[{"th": "ผนังครึ่ง 2 ม.", "en": "Half wall 2m"}, "wall", {"w": 2.0, "half": 1}],
		[{"th": "กระจกกั้น 2 ม.", "en": "Glass 2m"}, "wall", {"w": 2.0, "glass": 1}],
		[{"th": "กระจกกั้น 1 ม.", "en": "Glass 1m"}, "wall", {"w": 1.0, "glass": 1}],
	]],
]

var cam: Camera3D
var office: Node3D
var active := false
var carrying: Node3D = null
var _carry_new := false          # spawned from catalog, not placed yet
var _carry_entry := {}           # pending catalog entry {kind, params}
var _paint := {}                 # active floor style ({} = off)
var _orig: Transform3D
var _ring: MeshInstance3D
var _ui: CanvasLayer
var _grid: GridContainer
var _cat_bar: HFlowContainer
var _cur_cat := 0
var _added_seq := 0
var _icon_cache := {}            # kind+params -> Texture2D (rendered once)
var _icon_gen := 0               # cancels stale async icon fills
var _vp: SubViewport
var _vp_cam: Camera3D
var _vp_root: Node3D

signal mode_changed(on: bool)


func _ready() -> void:
	_build_catalog_ui()


func toggle() -> void:
	if active and carrying:
		cancel_carry()
	_paint = {}
	active = not active
	if _ui:
		_ui.visible = active
	if active:
		_show_cat(_cur_cat)   # regenerate icons (office exists by now)
	mode_changed.emit(active)


## Returns true when the click was consumed by build mode.
func handle_click(mpos: Vector2) -> bool:
	if not active or cam == null:
		return false
	if carrying:
		_place()
		return true
	var p := _floor_point(mpos)
	if not _paint.is_empty():
		_paint_tile(p)
		return true
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
	if not active:
		return false
	if keycode == KEY_ESCAPE and not _paint.is_empty():
		_paint = {}
		return true
	if carrying == null:
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


# ----------------------------------------------------------- floor paint

func _paint_tile(p: Vector3) -> void:
	var cell := Vector2i(int(floorf(p.x / office.CELL)), int(floorf(p.z / office.CELL)))
	if not office.floor_tiles.has(cell):
		return
	var mi := office.floor_tiles[cell] as MeshInstance3D
	mi.material_override = _floor_mat(_paint)
	Sfx.play_ui("paper", -14.0)
	var layout := _load_layout()
	var floors: Dictionary = layout.get("floors", {})
	floors["%d,%d" % [cell.x, cell.y]] = _paint
	layout["floors"] = floors
	_write_layout(layout)


func _floor_mat(style: Dictionary) -> StandardMaterial3D:
	if style.has("tex"):
		return office._mat("floor_" + str(style["tex"]), Color.WHITE,
			"res://assets/textures/%s.png" % str(style["tex"]))
	return office._mat("bfloor_" + str(style.get("col", "ffffff")),
		Color.html(str(style.get("col", "ffffff"))))


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
		"glb":
			return _spawn_glb(params, at)
		"wall":
			return _spawn_wall(params, at)
	return null


## Native-scale model (Kenney/KayKit kits are true-to-life meters) with
## a sanity clamp, optional shelf height and optional real light source.
func _spawn_glb(params: Dictionary, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(at.x, float(params.get("y", 0.0)), at.z)
	office.add_child(root)
	office._movable(root)
	var node: Node3D = office._instantiate_glb(str(params.get("model", "")))
	if node == null:
		root.queue_free()
		return null
	root.add_child(node)
	var aabb: AABB = office._combined_aabb(node, Transform3D.IDENTITY)
	var mx := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if mx > 3.5:
		node.scale = Vector3.ONE * (2.0 / mx)
	elif mx < 0.05 and mx > 0.0001:
		node.scale = Vector3.ONE * (0.4 / mx)
	if params.has("light"):
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, float(params["light"]), 0)
		lamp.light_color = Color(1.0, 0.87, 0.68)
		lamp.light_energy = 1.1
		lamp.omni_range = 3.5
		lamp.shadow_enabled = false
		root.add_child(lamp)
	return root


func _spawn_wall(params: Dictionary, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(at.x, 0, at.z)
	office.add_child(root)
	office._movable(root)
	var w := float(params.get("w", 2.0))
	var h := 1.15 if params.has("half") else 2.55
	var m: StandardMaterial3D
	if params.has("glass"):
		m = StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.84, 0.90, 0.26)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.05
		m.metallic = 0.1
	else:
		m = office._mat("bwall_paint", Color(0.92, 0.91, 0.88))
	office._box(Vector3(w, h, 0.09), Vector3(0, h / 2.0, 0), m, root, false)
	if params.has("glass"):    # slim posts so the pane reads at a glance
		var post: StandardMaterial3D = office._mat("bwall_post", Color(0.30, 0.31, 0.34))
		for px in [-w / 2.0, w / 2.0]:
			office._box(Vector3(0.05, h, 0.06), Vector3(px, h / 2.0, 0), post, root, false)
	return root


func _catalog_pick(kind: String, params: Dictionary) -> void:
	if carrying:
		cancel_carry()
	if kind == "floor":
		_paint = params        # enter paint mode: click tiles to repaint
		return
	_paint = {}
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
		return {"moved": {}, "deleted": [], "added": [], "floors": {}}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (d is Dictionary):
		return {"moved": {}, "deleted": [], "added": [], "floors": {}}
	var dict: Dictionary = d
	if dict.has("moved") or dict.has("added") or dict.has("deleted") or dict.has("floors"):
		for k in ["moved", "floors"]:
			if not dict.has(k):
				dict[k] = {}
		for k in ["deleted", "added"]:
			if not dict.has(k):
				dict[k] = []
		return dict
	return {"moved": dict, "deleted": [], "added": [], "floors": {}}  # phase-1 file


static func _write_layout(layout: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(layout, "  "))


## Boot-time: re-apply the owner's whole layout — moves, deletions,
## purchases and floor paint (called by main once the office is built).
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
	var floors: Dictionary = layout.get("floors", {})
	for key in floors:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 2:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if office.floor_tiles.has(cell):
			(office.floor_tiles[cell] as MeshInstance3D).material_override = \
				_floor_mat(floors[key])


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
	panel.offset_top = 72.0
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
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(238, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	var hint := Label.new()
	I18n.reg(hint, "text", "build_keys")
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.67, 0.72))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(238, 0)
	v.add_child(hint)
	_show_cat(0)


func _show_cat(idx: int) -> void:
	_cur_cat = idx
	_paint = {}
	for i in _cat_bar.get_child_count():
		(_cat_bar.get_child(i) as Button).button_pressed = (i == idx)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var items: Array = CATALOG[idx][1]
	for it in items:
		var names: Dictionary = it[0]
		var kind: String = it[1]
		var params: Dictionary = it[2]
		var b := Button.new()
		b.custom_minimum_size = Vector2(74, 74)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = str(names.get(I18n.lang, names.get("th", "?")))
		b.pressed.connect(func() -> void: _catalog_pick(kind, params))
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 4.0
		tr.offset_top = 4.0
		tr.offset_right = -4.0
		tr.offset_bottom = -4.0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.add_child(tr)
		b.set_meta("icon_rect", tr)
		_grid.add_child(b)
	_icon_gen += 1
	_fill_icons(idx, _icon_gen)


## The Sims sells with pictures: render each piece once from a 3/4
## angle into a tiny viewport, cache the texture, drop it on the card.
func _fill_icons(idx: int, gen: int) -> void:
	var items: Array = CATALOG[idx][1]
	for i in items.size():
		if gen != _icon_gen:
			return
		var it: Array = items[i]
		var tex: Texture2D = await _item_icon(str(it[1]), it[2])
		if gen != _icon_gen or tex == null or i >= _grid.get_child_count():
			continue
		var b := _grid.get_child(i) as Button
		var tr := b.get_meta("icon_rect") as TextureRect
		if tr:
			tr.texture = tex


func _item_icon(kind: String, params: Dictionary) -> Texture2D:
	var key := kind + JSON.stringify(params)
	if _icon_cache.has(key):
		return _icon_cache[key]
	if office == null:
		return null
	_ensure_vp()
	var node: Node3D
	if kind == "floor":            # flat swatch tile, slight angle
		node = Node3D.new()
		_vp_root.add_child(node)
		office._box(Vector3(0.9, 0.06, 0.9), Vector3(0, 0.03, 0), _floor_mat(params), node, false)
	else:
		var seq: int = office._piece_seq
		node = _spawn(kind, params, Vector3.ZERO)
		office._piece_seq = seq      # icon models must not eat piece ids
		if node == null:
			return null
		node.remove_from_group("furniture")
		node.get_parent().remove_child(node)
		_vp_root.add_child(node)
		node.position = Vector3.ZERO
		node.rotation_degrees = Vector3.ZERO
	var aabb: AABB = office._combined_aabb(node, Transform3D.IDENTITY)
	var c := aabb.get_center()
	var r: float = maxf(aabb.size.length() * 0.5, 0.18)
	_vp_cam.look_at_from_position(c + Vector3(1.0, 0.85, 1.0).normalized() * r * 3.9, c)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	node.queue_free()
	# autocrop to the drawn pixels so the piece FILLS its card (no dead
	# margins, nothing cut off — framing is exact regardless of shape)
	var used := img.get_used_rect()
	if used.size.x > 4 and used.size.y > 4:
		img = img.get_region(used.grow(3).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex


func _ensure_vp() -> void:
	if _vp:
		return
	_vp = SubViewport.new()
	_vp.size = Vector2i(160, 160)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_vp_cam = Camera3D.new()
	_vp_cam.fov = 30.0
	_vp.add_child(_vp_cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.25
	_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 142, 0)
	fill.light_energy = 0.55
	_vp.add_child(fill)
	_vp_root = Node3D.new()
	_vp.add_child(_vp_root)
