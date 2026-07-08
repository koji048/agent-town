## The human's project board (Asana/Jira-style): a real kanban over the
## REAL pipeline. BACKLOG = queue/pending files, IN PROGRESS = the
## active request with its current stage + assignee, REVIEW = waiting
## at the approval desk, DONE = shipped packages (click to open).
class_name BoardPanel
extends PanelContainer

const ROLE_COLOR := {
	"director": Color(0.85, 0.67, 0.24),
	"researcher": Color(0.17, 0.48, 0.32),
	"writer": Color(0.84, 0.49, 0.17),
	"editor": Color(0.35, 0.86, 0.86),
	"publisher": Color(0.77, 0.24, 0.26),
}

var _cols: Dictionary = {}
var _active_topic := ""
var _active_stage := ""
var _active_role := ""
var _in_review := false


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.96)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	position = Vector2(160, 90)
	custom_minimum_size = Vector2(1600, 640)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	var title := Label.new()
	I18n.reg(title, "text", "board_title")
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	I18n.reg(close, "text", "btn_close")
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	root.add_child(head)

	var lanes := HBoxContainer.new()
	lanes.add_theme_constant_override("separation", 14)
	lanes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Asana/Jira pattern: PROJECT LIST sidebar + kanban lanes to its right
	var lane_specs := [["PROJECTS", "lane_projects", 300],
		["BACKLOG", "lane_backlog", 316], ["IN PROGRESS", "lane_progress", 316],
		["REVIEW", "lane_review", 316], ["DONE", "lane_done", 316]]
	for spec in lane_specs:
		var lane := VBoxContainer.new()
		lane.custom_minimum_size = Vector2(spec[2], 0)
		lane.add_theme_constant_override("separation", 8)
		var lane_head := Label.new()
		I18n.reg(lane_head, "text", str(spec[1]))
		lane_head.add_theme_font_size_override("font_size", 15)
		lane_head.modulate = Color(0.95, 0.45, 0.33)
		lane.add_child(lane_head)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(spec[2], 520)
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 8)
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(holder)
		lane.add_child(scroll)
		lanes.add_child(lane)
		_cols[spec[0]] = holder
	root.add_child(lanes)
	add_child(root)
	I18n.changed.connect(func() -> void:
		if visible:
			_refresh())

	EventBus.stage_started.connect(func(stage: String, role: String, request: Dictionary) -> void:
		_active_topic = str(request.get("topic", "untitled"))
		_active_stage = stage
		_active_role = role
		_in_review = false
		if visible:
			_refresh())
	EventBus.approval_requested.connect(func(_r, _p) -> void:
		_in_review = true
		if visible:
			_refresh())
	EventBus.approval_resolved.connect(func(_a) -> void:
		_in_review = false
		if visible:
			_refresh())
	EventBus.request_completed.connect(func(_r, _o) -> void:
		_active_topic = ""
		_active_stage = ""
		_in_review = false
		if visible:
			_refresh())
	var t := Timer.new()
	t.wait_time = 4.0
	t.timeout.connect(func() -> void:
		if visible:
			_refresh())
	add_child(t)
	t.start()
	visibility_changed.connect(func() -> void:
		if visible:
			_refresh())


func _clear(holder: VBoxContainer) -> void:
	for c in holder.get_children():
		c.queue_free()


func _card(holder: VBoxContainer, title_text: String, sub: String, accent: Color,
		open_path: String = "") -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.13, 0.18)
	sb.border_color = accent
	sb.border_width_left = 4
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	var l := Label.new()
	l.text = title_text
	l.add_theme_font_size_override("font_size", 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	if not sub.is_empty():
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 12)
		s.modulate = Color(0.75, 0.75, 0.8)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(s)
	if not open_path.is_empty():
		var b := Button.new()
		b.text = I18n.t("btn_open_files")
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func() -> void:
			OS.shell_open(ProjectSettings.globalize_path(open_path)))
		vb.add_child(b)
	card.add_child(vb)
	holder.add_child(card)


## One row in the PROJECTS sidebar: status dot + name, click to open.
func _project_row(name_text: String, status_col: Color, open_path: String = "") -> void:
	var row := Button.new()
	row.text = "●  " + name_text.left(30)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_color_override("font_color", status_col)
	row.add_theme_font_size_override("font_size", 13)
	if not open_path.is_empty():
		row.pressed.connect(func() -> void:
			OS.shell_open(ProjectSettings.globalize_path(open_path)))
	_cols["PROJECTS"].add_child(row)


func _refresh() -> void:
	# PROJECTS sidebar: every project, one glance — queued (gray),
	# active (amber), shipped (green, click to open)
	_clear(_cols["PROJECTS"])
	# BACKLOG: pending queue files
	var backlog: VBoxContainer = _cols["BACKLOG"]
	_clear(backlog)
	var dir := DirAccess.open("res://queue/pending")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"):
				var data: Variant = JSON.parse_string(
					FileAccess.get_file_as_string("res://queue/pending/" + f))
				var topic := f
				if data is Dictionary:
					topic = str(data.get("topic", f))
				_card(backlog, topic.left(70), I18n.t("waiting_director"),
					Color(0.55, 0.55, 0.6))
				_project_row(topic, Color(0.62, 0.62, 0.66))

	# IN PROGRESS / REVIEW: the active request
	var prog: VBoxContainer = _cols["IN PROGRESS"]
	var review: VBoxContainer = _cols["REVIEW"]
	_clear(prog)
	_clear(review)
	if not _active_topic.is_empty():
		var accent: Color = ROLE_COLOR.get(_active_role, Color.GRAY)
		if _in_review:
			_card(review, _active_topic.left(70), I18n.t("review_wait"),
				Color(0.95, 0.45, 0.33))
		else:
			_card(prog, _active_topic.left(70),
				I18n.t("card_stage") % [_active_stage, _active_role], accent)
		_project_row(_active_topic, Color(1.0, 0.72, 0.32))

	# DONE: shipped packages, newest first
	var done: VBoxContainer = _cols["DONE"]
	_clear(done)
	var out := DirAccess.open("res://output")
	if out:
		var dirs: Array = []
		for d in out.get_directories():
			dirs.append(d)
		dirs.sort()
		dirs.reverse()
		for i in dirs.size():
			var d: String = dirs[i]
			var topic := d.get_slice("_", 1).replace("-", " ")
			if i < 8:
				_card(done, topic.left(70), d, Color(0.45, 0.85, 0.5),
					"res://output/" + d)
			_project_row(topic, Color(0.45, 0.85, 0.5), "res://output/" + d)
