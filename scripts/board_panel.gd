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

const STAGE_PIC := {
	"00_plan.md": "director", "01_research.md": "researcher",
	"02_script.md": "writer", "03_captions.srt": "editor",
	"04_publish.md": "publisher", "05_review.md": "director",
}

## The delegation flow, in order (UX audit P1): who the baton passes to.
const STAGE_ORDER := ["plan", "research", "script", "edit", "publish", "review"]
const STAGE_ROLE := {
	"plan": "director", "research": "researcher", "script": "writer",
	"edit": "editor", "publish": "publisher", "review": "director",
}

var _cols: Dictionary = {}
# parallel jobs: topic -> {"stage": String, "role": String, "review": bool}
var _active: Dictionary = {}
# quick filters (Jira avatar-filter pattern) + selected project
var _filter_text := ""
var _filter_role := ""
var _selected_project := ""
var _search: LineEdit
var _role_btns: Dictionary = {}


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

	# quick filters: text search + PIC avatar chips (Jira pattern)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	_search = LineEdit.new()
	I18n.reg(_search, "placeholder_text", "filter_search")
	_search.custom_minimum_size = Vector2(260, 0)
	_search.text_changed.connect(func(t: String) -> void:
		_filter_text = t.to_lower()
		_refresh())
	filters.add_child(_search)
	var all_btn := Button.new()
	I18n.reg(all_btn, "text", "filter_all")
	all_btn.pressed.connect(func() -> void:
		_filter_role = ""
		_selected_project = ""
		_search.text = ""
		_filter_text = ""
		_style_role_buttons()
		_refresh())
	filters.add_child(all_btn)
	for role in ROLE_COLOR:
		var rb := Button.new()
		rb.text = " ● " + role.left(5) + " "
		rb.add_theme_color_override("font_color", ROLE_COLOR[role])
		rb.pressed.connect(func() -> void:
			_filter_role = "" if _filter_role == role else role
			_style_role_buttons()
			_refresh())
		filters.add_child(rb)
		_role_btns[role] = rb
	root.add_child(filters)

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
		var topic := str(request.get("topic", "untitled"))
		_active[topic] = {"stage": stage, "role": role, "review": false}
		if visible:
			_refresh())
	EventBus.approval_requested.connect(func(request: Dictionary, _p) -> void:
		var topic := str(request.get("topic", "untitled"))
		if _active.has(topic):
			_active[topic]["review"] = true
		if visible:
			_refresh())
	EventBus.approval_resolved.connect(func(_a) -> void:
		for t in _active:
			_active[t]["review"] = false
		if visible:
			_refresh())
	EventBus.request_completed.connect(func(request: Dictionary, _o) -> void:
		_active.erase(str(request.get("topic", "untitled")))
		if visible:
			_refresh())
	EventBus.request_cancelled.connect(func(request: Dictionary) -> void:
		_active.erase(str(request.get("topic", "untitled")))
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
		open_path: String = "", pic: String = "", pct: int = -1,
		stage: String = "", cancel_topic: String = "") -> void:
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
	if not stage.is_empty():
		_flow_strip(vb, stage)
	_pic_line(vb, pic)
	if pct >= 0:
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = pct
		bar.show_percentage = true
		bar.custom_minimum_size = Vector2(0, 16)
		vb.add_child(bar)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	if not open_path.is_empty():
		var b := Button.new()
		b.text = I18n.t("btn_open_files")
		b.pressed.connect(func() -> void:
			OS.shell_open(ProjectSettings.globalize_path(open_path)))
		btn_row.add_child(b)
	if not cancel_topic.is_empty():
		var cb := Button.new()
		cb.text = I18n.t("btn_cancel_job")
		cb.add_theme_color_override("font_color", Color(0.95, 0.55, 0.5))
		cb.pressed.connect(func() -> void:
			TaskQueue.cancel(cancel_topic)
			cb.disabled = true
			cb.text = "⏳")
		btn_row.add_child(cb)
	if btn_row.get_child_count() > 0:
		vb.add_child(btn_row)
	card.add_child(vb)
	holder.add_child(card)


## The delegation-flow strip (UX audit P1): six nodes in pipeline order,
## done ✓ in role color, the ACTIVE stage named and bright, the rest dim
## — RimWorld's rule that assigned work reads as an inspectable chain.
func _flow_strip(vb: VBoxContainer, stage: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var cur := STAGE_ORDER.find(stage)
	for i in STAGE_ORDER.size():
		var s: String = STAGE_ORDER[i]
		var role: String = STAGE_ROLE[s]
		var n := Label.new()
		if i < cur:
			n.text = "✓"
			n.add_theme_color_override("font_color",
				ROLE_COLOR.get(role, Color.GRAY).darkened(0.15))
		elif i == cur:
			n.text = "▶" + I18n.t("stg_" + s)
			n.add_theme_color_override("font_color", ROLE_COLOR.get(role, Color.WHITE))
		else:
			n.text = "○"
			n.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52))
		n.add_theme_font_size_override("font_size", 12)
		row.add_child(n)
		if i < STAGE_ORDER.size() - 1:
			var arrow := Label.new()
			arrow.text = "–"
			arrow.add_theme_font_size_override("font_size", 12)
			arrow.add_theme_color_override("font_color", Color(0.4, 0.4, 0.46))
			row.add_child(arrow)
	vb.add_child(row)


func _style_role_buttons() -> void:
	for role in _role_btns:
		var rb: Button = _role_btns[role]
		rb.text = (" ◉ " if _filter_role == role else " ● ") + role.left(5) + " "


## Does a card pass the quick filters?
func _passes(title_text: String, pic: String) -> bool:
	if not _filter_text.is_empty() and not title_text.to_lower().contains(_filter_text):
		return false
	if not _filter_role.is_empty() and pic != _filter_role:
		return false
	return true


## The PIC chip line appended to a card (research: assignee on-card).
func _pic_line(vb: VBoxContainer, pic: String) -> void:
	if pic.is_empty():
		return
	var l := Label.new()
	l.text = "%s  ● %s" % [I18n.t("pic"), pic]
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", ROLE_COLOR.get(pic, Color(0.7, 0.7, 0.75)))
	vb.add_child(l)


## One row in the PROJECTS sidebar: click SELECTS the project — the
## kanban lanes filter to it (the Asana/Jira link the owner asked for).
func _project_row(name_text: String, status_col: Color) -> void:
	var row := Button.new()
	var selected := _selected_project == name_text
	row.text = ("▸ " if selected else "●  ") + name_text.left(30)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_color_override("font_color",
		Color(1, 1, 1) if selected else status_col)
	row.add_theme_font_size_override("font_size", 13)
	row.pressed.connect(func() -> void:
		_selected_project = "" if _selected_project == name_text else name_text
		_refresh())
	_cols["PROJECTS"].add_child(row)


func _project_visible(topic: String) -> bool:
	return _selected_project.is_empty() or _selected_project == topic


func _refresh() -> void:
	_clear(_cols["PROJECTS"])
	# BACKLOG: pending queue files (PIC: the Director picks up)
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
				_project_row(topic, Color(0.62, 0.62, 0.66))
				if _project_visible(topic) and _passes(topic, "director"):
					_card(backlog, topic.left(70), I18n.t("waiting_director"),
						Color(0.55, 0.55, 0.6), "", "director")

	# IN PROGRESS / REVIEW: every running request (PIC: live assignee)
	var prog: VBoxContainer = _cols["IN PROGRESS"]
	var review: VBoxContainer = _cols["REVIEW"]
	_clear(prog)
	_clear(review)
	for topic in _active:
		var info: Dictionary = _active[topic]
		var a_role := str(info["role"])
		_project_row(topic, Color(1.0, 0.72, 0.32))
		if _project_visible(topic) and _passes(topic, a_role):
			var accent: Color = ROLE_COLOR.get(a_role, Color.GRAY)
			var pct := int(TaskQueue.jobs.get(topic, {}).get("pct", 50))
			if bool(info["review"]):
				_card(review, str(topic).left(70), I18n.t("review_wait"),
					Color(0.95, 0.45, 0.33), "", a_role, 75,
					str(info["stage"]), str(topic))
			else:
				_card(prog, str(topic).left(70),
					I18n.t("card_stage") % [str(info["stage"]), a_role],
					accent, "", a_role, pct, str(info["stage"]), str(topic))

	# DONE: shipped packages, titled by their REAL topic (request.json)
	# with a readable date — not the timestamp digits (owner's note).
	# Selecting a shipped project EXPANDS it into its stage deliverables.
	var done: VBoxContainer = _cols["DONE"]
	_clear(done)
	var out := DirAccess.open("res://output")
	if out:
		var dirs: Array = []
		for d in out.get_directories():
			dirs.append(d)
		dirs.sort()
		dirs.reverse()
		var shown := 0
		for dv in dirs:
			var d: String = str(dv)
			var info := _package_title(d)
			var topic: String = info[0]
			_project_row(topic, Color(0.45, 0.85, 0.5))
			if not _project_visible(topic):
				continue
			if _selected_project == topic:
				# expanded: one card per stage file, with PIC
				var pdir := DirAccess.open("res://output/" + d)
				if pdir:
					for sf in pdir.get_files():
						var pic: String = STAGE_PIC.get(sf, "")
						if pic.is_empty() or not _passes(sf, pic):
							continue
						_card(done, I18n.t("stage_file") % [sf, pic], "",
							ROLE_COLOR.get(pic, Color.GRAY),
							"res://output/" + d + "/" + sf, pic)
			elif shown < 8 and _passes(topic, ""):
				_card(done, topic.left(70), str(info[1]), Color(0.45, 0.85, 0.5),
					"res://output/" + d, "")
				shown += 1


## Human title + date for a package folder: the real topic lives in
## request.json ("YYYYMMDD_HHMMSS_slug" digits told the owner nothing).
func _package_title(d: String) -> Array:
	var topic := ""
	var meta: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://output/" + d + "/request.json"))
	if meta is Dictionary:
		topic = str((meta as Dictionary).get("topic", "")).strip_edges()
	if topic.is_empty():
		topic = d.get_slice("_", 2).replace("-", " ")
	if topic.strip_edges().is_empty():
		topic = d
	var date_str := ""
	var p: PackedStringArray = d.split("_")
	if p.size() >= 2 and p[0].length() == 8 and p[1].length() >= 4:
		date_str = "%s/%s · %s:%s" % [p[0].substr(6, 2), p[0].substr(4, 2),
			p[1].substr(0, 2), p[1].substr(2, 2)]
	return [topic, date_str]
