## The live kanban wall at reception: real queue state made physical
## (docs/CREATIVE_DIRECTION.md, pillar 1). One card per request slides
## column to column as the actual pipeline stage changes; pending
## requests wait as gray cards in the QUEUE column.
class_name KanbanBoard
extends Node3D

const STAGES := ["queue", "plan", "research", "script", "edit", "publish", "review"]
const STAGE_LABEL := {
	"queue": "QUEUE", "plan": "PLAN", "research": "RSRCH", "script": "SCRIPT",
	"edit": "EDIT", "publish": "PUB", "review": "QC",
}
const CARD_W := 0.30
const COL_W := 0.37

# parallel jobs: one card per active request, stacked in rows
var _cards: Dictionary = {}
var _rows: Array = []
var _pending_cards: Array = []
var _poll: Timer


func _ready() -> void:
	# board frame on the reception north wall (replaces the static notes)
	_panel()
	EventBus.stage_started.connect(_on_stage_started)
	EventBus.request_completed.connect(_on_request_completed)
	_poll = Timer.new()
	_poll.wait_time = 3.0
	_poll.timeout.connect(_refresh_pending)
	add_child(_poll)
	_poll.start()
	_refresh_pending()


func _panel() -> void:
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.75, 1.05, 0.04)
	bg.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.30, 0.36)
	m.roughness = 0.75
	bg.material_override = m
	add_child(bg)
	for i in STAGES.size():
		var l := Label3D.new()
		l.text = str(STAGE_LABEL[STAGES[i]])
		l.font_size = 30
		l.outline_size = 6
		l.pixel_size = 0.0032
		l.modulate = Color(0.9, 0.89, 0.85)
		l.position = _col_pos(i) + Vector3(0, 0.42, 0.03)
		add_child(l)
		var tick := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.30, 0.015, 0.01)
		tick.mesh = tm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.95, 0.45, 0.33)
		tick.material_override = mm
		tick.position = _col_pos(i) + Vector3(0, 0.34, 0.025)
		add_child(tick)


func _col_pos(i: int) -> Vector3:
	return Vector3(-1.11 + i * COL_W, 0.0, 0.0)


func _make_card(topic: String, col: Color) -> Node3D:
	var card := Node3D.new()
	var quad := MeshInstance3D.new()
	var qm := BoxMesh.new()
	qm.size = Vector3(CARD_W, 0.20, 0.015)
	quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.6
	quad.material_override = m
	card.add_child(quad)
	var l := Label3D.new()
	l.text = topic.left(9)
	l.font_size = 22
	l.outline_size = 4
	l.pixel_size = 0.0030
	l.modulate = Color(0.12, 0.12, 0.14)
	l.position = Vector3(0, 0, 0.012)
	card.add_child(l)
	add_child(card)
	return card


func _on_stage_started(stage: String, _role: String, request: Dictionary) -> void:
	var idx := STAGES.find(stage)
	if idx < 0:
		return
	var topic := str(request.get("topic", "reel"))
	if not _cards.has(topic):
		var card := _make_card(topic, Color(0.95, 0.45, 0.33))
		card.position = _col_pos(0) + Vector3(0, _row_y(_rows.size()), 0.035)
		_cards[topic] = card
		_rows.append(topic)
		Juice.pop_in(card)
	var row := _rows.find(topic)
	Juice.slide_to(_cards[topic], _col_pos(idx) + Vector3(0, _row_y(row), 0.035), 0.5)
	Sfx.play_at(self, "paper", -14.0)


func _row_y(row: int) -> float:
	return 0.16 - row * 0.24


func _on_request_completed(request: Dictionary, _output_dir: String) -> void:
	var topic := str(request.get("topic", "reel"))
	if _cards.has(topic):
		Juice.pop_out(_cards[topic], 0.4)
		_cards.erase(topic)
		_rows.erase(topic)
		# reflow the remaining cards upward
		for i in _rows.size():
			var c: Node3D = _cards.get(_rows[i])
			if c:
				Juice.slide_to(c, Vector3(c.position.x, _row_y(i), c.position.z), 0.4)


func _refresh_pending() -> void:
	var count := 0
	var dir := DirAccess.open("res://queue/pending")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"):
				count += 1
	count = mini(count, 3)
	while _pending_cards.size() > count:
		var c: Node = _pending_cards.pop_back()
		if is_instance_valid(c):
			c.queue_free()
	while _pending_cards.size() < count:
		var card := _make_card("...", Color(0.62, 0.62, 0.66))
		card.position = _col_pos(0) + Vector3(0, -0.13 - _pending_cards.size() * 0.075, 0.03)
		Juice.pop_in(card)
		_pending_cards.append(card)
