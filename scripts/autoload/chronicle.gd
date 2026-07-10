## The Dwarf Fortress lesson (docs/CREATIVE_DIRECTION.md, pillar 5):
## everything is recorded, and the world memorializes itself. A legends
## log persists every named event; every shipped episode adds a framed
## poster to the wall and a block to the amphitheater skyline — the
## office visibly accumulates history across sessions.
extends Node

const LOG_PATH := "user://chronicle.jsonl"
const STATS_PATH := "user://town_stats.json"

var episodes := 0
var _office: Node3D


func _ready() -> void:
	_load_stats()
	EventBus.request_completed.connect(_on_shipped)


## Called by main once the office exists — rebuilds past memorials.
func attach_office(office: Node3D) -> void:
	_office = office
	if Config.office_branch != "studio":
		return   # the episode memorial wall is the STUDIO's trophy case
	for n in episodes:
		_spawn_memorial(n + 1, "", false)


func record(kind: String, text: String) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(JSON.stringify({
			"t": Time.get_datetime_string_from_system(),
			"kind": kind,
			"text": text,
		}))
	EventBus.log_line.emit("📜 %s" % text)


func _on_shipped(request: Dictionary, _out_dir: String) -> void:
	episodes += 1
	_save_stats()
	var topic := str(request.get("topic", "untitled")).left(40)
	record("shipped", "EP%02d — '%s' shipped. The crew celebrated." % [episodes, topic])
	_spawn_memorial(episodes, topic, true)


## A framed EP poster on the north wall + a skyline block on the stage.
func _spawn_memorial(n: int, _topic: String, animate: bool) -> void:
	if Config.office_branch != "studio" or _office == null:
		return
	if _office == null:
		return
	var palette := [Color(0.26, 0.52, 0.96), Color(0.92, 0.26, 0.21),
		Color(0.98, 0.74, 0.02), Color(0.20, 0.66, 0.33), Color(0.95, 0.45, 0.33)]
	var col: Color = palette[(n - 1) % palette.size()]
	# wall poster (two rows of eight along the meeting-nook wall)
	if n <= 16:
		var poster := Node3D.new()
		var slot := n - 1
		poster.position = Vector3(1.0 + (slot % 8) * 0.55, 2.55 - (slot / 8) * 0.55, 0.22)
		_office.add_child(poster)
		var frame := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.42, 0.42, 0.03)
		frame.mesh = fm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.16, 0.16, 0.19)
		frame.material_override = mm
		poster.add_child(frame)
		var art := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.34, 0.34, 0.02)
		art.mesh = am
		var amat := StandardMaterial3D.new()
		amat.albedo_color = col
		amat.roughness = 0.6
		art.material_override = amat
		art.position = Vector3(0, 0, 0.01)
		poster.add_child(art)
		var l := Label3D.new()
		l.text = "EP%02d" % n
		l.font_size = 40
		l.outline_size = 8
		l.pixel_size = 0.0032
		l.modulate = Color(0.98, 0.97, 0.94)
		l.position = Vector3(0, 0, 0.03)
		poster.add_child(l)
		if animate:
			Juice.pop_in(poster, 0.4)
	# skyline block on the front lip of the amphitheater stage
	var block := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var h := 0.14 + (n % 4) * 0.05
	bm.size = Vector3(0.16, h, 0.16)
	block.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = col
	bmat.roughness = 0.55
	block.material_override = bmat
	block.position = Vector3(11.15 + ((n - 1) % 16) * 0.18, 0.31 + h / 2.0, 7.92)
	_office.add_child(block)
	if animate:
		Juice.pop_in(block, 0.4)


func _save_stats() -> void:
	var f := FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"episodes": episodes}))


func _load_stats() -> void:
	if FileAccess.file_exists(STATS_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATS_PATH))
		if data is Dictionary:
			episodes = int(data.get("episodes", 0))
