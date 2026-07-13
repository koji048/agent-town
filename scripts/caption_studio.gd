## CAPTION REVIEW STUDIO — the CapCut moment inside Agent Town.
## Opens before a clip burns: filmstrip video preview + real audio
## scrubbing on a waveform timeline, cue-by-cue text editing (writes
## straight back to the batch's -clean.srt), and a live-styled caption
## overlay with font / size / colour choices that the burn honours.
## It waits for your explicit Burn click — nothing auto-burns.
class_name CaptionStudio
extends PanelContainer

## [ASS family name, preview ttf] — the ASS Fontname MUST be the font
## FAMILY (libass matches family, not file/full names; "Kanit SemiBold"
## silently fell back to a default font — the owner's "font ยังไม่ได้").
const FONTS := [
	["Anuphan", "res://assets/fonts/Anuphan.ttf"],
	["Kanit", "res://assets/fonts/Kanit-SemiBold.ttf"],
	["Sarabun", "res://assets/fonts/Sarabun-Bold.ttf"],
]
const SIZES := [["S", 58], ["M", 72], ["L", 86]]
## [label, ASS primary (BGR), ASS outline, preview colour, preview outline]
const COLORS := [
	["ขาว", "&H00FFFFFF", "&H00000000", Color(1, 1, 1), Color(0, 0, 0)],
	["เหลือง", "&H004DE1FF", "&H00000000", Color(1.0, 0.88, 0.30), Color(0, 0, 0)],
	["มินต์", "&H00B4E6A8", "&H00000000", Color(0.66, 0.90, 0.70), Color(0, 0, 0)],
	["ดำ", "&H00141414", "&H00FFFFFF", Color(0.08, 0.08, 0.08), Color(1, 1, 1)],
]
const PREVIEW_SCALE := 576.0 / 1920.0  # preview panel vs burn canvas
const MARGIN_MIN := 120.0
const MARGIN_MAX := 1400.0
const CAP_BAND := 160.0   # preview-px height of the caption's grab band

var cues: Array = []
var _srt_path := ""
var _frames_dir := ""
var _frame_total := 0
var _duration := 1.0
var _t := 0.0
var _playing := false
var _sel := -1
var _tex_cache: Dictionary = {}
var _scale_idx := 0
var _margin_v := 360.0    # burn-canvas px from the bottom; owner-draggable

var _audio: AudioStreamPlayer
var _wave: PackedFloat32Array
var _frame_rect: TextureRect
var _cap_label: Label
var _timeline: Control
var _time_label: Label
var _play_btn: Button
var _cue_list: VBoxContainer
var _cue_edit: TextEdit
var _auto_label: Label
var _font_pick: OptionButton
var _size_pick: OptionButton
var _color_idx := 0
var _color_btns: Array = []


func _ready() -> void:
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.97)
	sb.border_color = Color(1.0, 0.78, 0.32)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)
	position = Vector2(310, 40)
	# width fixed; height is driven by the ScrollContainer's cap (below), so
	# the panel wraps the scroll viewport snugly instead of the ~1050px content
	# that used to overrun the screen
	custom_minimum_size = Vector2(1300, 0)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := Label.new()
	I18n.reg(title, "text", "studio_title")
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(1.0, 0.85, 0.4)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	# drag the whole studio by its title bar
	title.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			position += (ev as InputEventMouseMotion).relative)
	head.add_child(title)
	# resize: cycle scale steps (the owner: "มันควรปรับขนาดได้")
	var size_btn := Button.new()
	size_btn.text = " ⤢ 100% "
	size_btn.pressed.connect(func() -> void:
		var steps := [1.0, 1.2, 1.4, 0.8]
		_scale_idx = (_scale_idx + 1) % steps.size()
		var s: float = steps[_scale_idx]
		pivot_offset = size / 2.0
		scale = Vector2(s, s)
		size_btn.text = " ⤢ %d%% " % int(s * 100))
	head.add_child(size_btn)
	root.add_child(head)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 14)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ---- left: the 9:16 preview with the styled caption overlaid
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	var frame_holder := Control.new()
	frame_holder.custom_minimum_size = Vector2(324, 576)
	var black := ColorRect.new()
	black.color = Color(0.03, 0.03, 0.04)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_holder.add_child(black)
	_frame_rect = TextureRect.new()
	_frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_holder.add_child(_frame_rect)
	# Instagram safe-zone guide: a dim band over the bottom ~320px (burn) the
	# app UI covers — drag the caption to sit ABOVE it. Ignores mouse so it
	# never blocks the caption drag.
	var ig_guide := ColorRect.new()
	ig_guide.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ig_guide.offset_top = -320.0 * PREVIEW_SCALE
	ig_guide.color = Color(0, 0, 0, 0.35)
	ig_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_holder.add_child(ig_guide)
	_cap_label = Label.new()
	_cap_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_cap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# drag the caption up/down to choose where it burns (CapCut-style)
	_cap_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_cap_label.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_cap_label.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			var dy := (ev as InputEventMouseMotion).relative.y
			_margin_v = clampf(_margin_v - dy / PREVIEW_SCALE, MARGIN_MIN, MARGIN_MAX)
			_place_caption())
	frame_holder.add_child(_cap_label)
	_place_caption()
	left.add_child(frame_holder)

	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 8)
	_play_btn = Button.new()
	_play_btn.text = "▶"
	_play_btn.custom_minimum_size = Vector2(44, 0)
	_play_btn.pressed.connect(_toggle_play)
	transport.add_child(_play_btn)
	_time_label = Label.new()
	_time_label.text = "0.0 / 0.0s"
	_time_label.add_theme_font_size_override("font_size", 13)
	transport.add_child(_time_label)
	left.add_child(transport)

	# ---- style bar
	var style_box := VBoxContainer.new()
	style_box.add_theme_constant_override("separation", 6)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 6)
	var fl := Label.new()
	I18n.reg(fl, "text", "studio_font")
	fr.add_child(fl)
	_font_pick = OptionButton.new()
	for fdef in FONTS:
		_font_pick.add_item(str(fdef[0]))
	_font_pick.item_selected.connect(func(_i: int) -> void: _apply_style())
	fr.add_child(_font_pick)
	var sl := Label.new()
	I18n.reg(sl, "text", "studio_size")
	fr.add_child(sl)
	_size_pick = OptionButton.new()
	for sdef in SIZES:
		_size_pick.add_item(str(sdef[0]))
	_size_pick.select(1)
	_size_pick.item_selected.connect(func(_i: int) -> void: _apply_style())
	fr.add_child(_size_pick)
	style_box.add_child(fr)
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 6)
	var cl := Label.new()
	I18n.reg(cl, "text", "studio_color")
	cr.add_child(cl)
	for i in COLORS.size():
		var cb := Button.new()
		cb.text = " " + str(COLORS[i][0]) + " "
		cb.add_theme_color_override("font_color", COLORS[i][3] as Color)
		cb.pressed.connect(func() -> void:
			_color_idx = i
			_style_color_btns()
			_apply_style())
		cr.add_child(cb)
		_color_btns.append(cb)
	style_box.add_child(cr)
	left.add_child(style_box)
	mid.add_child(left)

	# ---- right: cue list + editor + actions
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	I18n.reg(hint, "text", "studio_hint")
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.7, 0.7, 0.76)
	right.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	_cue_list = VBoxContainer.new()
	_cue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cue_list)
	right.add_child(scroll)
	_cue_edit = TextEdit.new()
	_cue_edit.custom_minimum_size = Vector2(0, 84)
	_cue_edit.add_theme_font_size_override("font_size", 16)
	right.add_child(_cue_edit)
	var save := Button.new()
	I18n.reg(save, "text", "btn_save_cue")
	save.pressed.connect(_save_cue)
	right.add_child(save)
	# ONE burn button: what the preview shows is exactly what burns
	# (two buttons made the font choice look ignored)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var burn_btn := Button.new()
	I18n.reg(burn_btn, "text", "btn_burn_custom")
	burn_btn.add_theme_font_size_override("font_size", 17)
	burn_btn.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	burn_btn.pressed.connect(func() -> void: _resolve("custom"))
	actions.add_child(burn_btn)
	right.add_child(actions)
	_auto_label = Label.new()
	_auto_label.add_theme_font_size_override("font_size", 12)
	_auto_label.modulate = Color(0.75, 0.7, 0.6)
	I18n.reg(_auto_label, "text", "studio_waiting")
	right.add_child(_auto_label)
	mid.add_child(right)
	root.add_child(mid)

	# ---- bottom: waveform timeline with cue blocks + playhead
	_timeline = Control.new()
	_timeline.custom_minimum_size = Vector2(0, 96)
	_timeline.draw.connect(_draw_timeline)
	_timeline.gui_input.connect(_timeline_input)
	root.add_child(_timeline)
	# a fixed-height viewport: content taller than this scrolls, so the
	# Burn button stays reachable (content is ~1050px; screen may be less)
	var scroll_outer := ScrollContainer.new()
	scroll_outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vh := DisplayServer.window_get_size().y
	scroll_outer.custom_minimum_size = Vector2(0, minf(920.0, vh - 120.0))
	scroll_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_outer.add_child(root)
	add_child(scroll_outer)
	_style_color_btns()


func open_clip(srt_path: String, frames_dir: String) -> void:
	_srt_path = srt_path
	_frames_dir = frames_dir
	cues = PreviewMaker.parse_srt(FileAccess.get_file_as_string(srt_path))
	_frame_total = PreviewMaker.frame_count(frames_dir)
	_duration = maxf(_frame_total / PreviewMaker.FRAME_FPS, 1.0)
	if not cues.is_empty():
		_duration = maxf(_duration, float(cues[-1]["end"]))
	var wav := PreviewMaker.load_wav(frames_dir.path_join("preview.wav"))
	if wav:
		_audio.stream = wav
		_duration = maxf(_duration, wav.data.size() / 2.0 / 22050.0)
	_wave = PreviewMaker.wave_buckets(frames_dir.path_join("preview.wav"), 900)
	_t = 0.0
	_sel = -1
	_playing = false
	_tex_cache.clear()
	_margin_v = 360.0
	_place_caption()
	_rebuild_cue_list()
	_apply_style()
	_show_time()
	visible = true
	Sfx.play_ui("paper", -8.0)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _playing:
		_t = _audio.get_playback_position()
		if _t >= _duration - 0.05:
			_playing = false
			_audio.stop()
			_play_btn.text = "▶"
		_show_time()


func _toggle_play() -> void:
	_playing = not _playing
	if _playing:
		_audio.play(_t)
		_play_btn.text = "⏸"
	else:
		_audio.stop()
		_play_btn.text = "▶"


func _seek(t: float) -> void:
	_t = clampf(t, 0.0, _duration)
	if _playing:
		_audio.play(_t)
	_show_time()


func _show_time() -> void:
	_time_label.text = "%.1f / %.1fs" % [_t, _duration]
	var idx := clampi(int(_t * PreviewMaker.FRAME_FPS) + 1, 1, maxi(_frame_total, 1))
	if _frame_total > 0:
		if not _tex_cache.has(idx):
			var img := Image.new()
			if img.load(_frames_dir.path_join("f_%05d.jpg" % idx)) == OK:
				_tex_cache[idx] = ImageTexture.create_from_image(img)
		if _tex_cache.has(idx):
			_frame_rect.texture = _tex_cache[idx]
	_cap_label.text = _cue_text_at(_t)
	_timeline.queue_redraw()


func _cue_text_at(t: float) -> String:
	for c in cues:
		if t >= float(c["start"]) and t <= float(c["end"]):
			return str(c["text"])
	return ""


func _rebuild_cue_list() -> void:
	for c in _cue_list.get_children():
		c.queue_free()
	for i in cues.size():
		var c: Dictionary = cues[i]
		var b := Button.new()
		b.text = "%s  %s" % [_mmss(float(c["start"])), str(c["text"]).left(44)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		if i == _sel:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		b.pressed.connect(func() -> void:
			_sel = i
			_cue_edit.text = str(cues[i]["text"])
			_seek(float(cues[i]["start"]))
			_rebuild_cue_list())
		_cue_list.add_child(b)


func _mmss(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _save_cue() -> void:
	if _sel < 0 or _sel >= cues.size():
		return
	cues[_sel]["text"] = _cue_edit.text.strip_edges()
	PreviewMaker.write_srt(cues, _srt_path)
	EventBus.log_line.emit("✏ Caption %d fixed -> %s" % [_sel + 1, _srt_path.get_file()])
	Sfx.play_ui("paper", -10.0)
	_rebuild_cue_list()
	_show_time()


## Position the preview caption from _margin_v (burn px), so what you see is
## exactly where it burns.
func _place_caption() -> void:
	_cap_label.offset_bottom = -_margin_v * PREVIEW_SCALE
	_cap_label.offset_top = _cap_label.offset_bottom - CAP_BAND


func _apply_style() -> void:
	var ls := LabelSettings.new()
	var font := FontFile.new()
	font.load_dynamic_font(str(FONTS[_font_pick.selected][1]))
	ls.font = font
	ls.font_size = int(round(int(SIZES[_size_pick.selected][1]) * PREVIEW_SCALE))
	ls.font_color = COLORS[_color_idx][3] as Color
	ls.outline_size = maxi(1, int(round(3.0 * PREVIEW_SCALE)))
	ls.outline_color = COLORS[_color_idx][4] as Color
	_cap_label.label_settings = ls
	_show_time()


func _style_color_btns() -> void:
	for i in _color_btns.size():
		(_color_btns[i] as Button).text = (" ◉ " if i == _color_idx else " ") \
			+ str(COLORS[i][0]) + " "


func style_dict() -> Dictionary:
	return {
		"font_name": str(FONTS[_font_pick.selected][0]),
		"size": int(SIZES[_size_pick.selected][1]),
		"primary": str(COLORS[_color_idx][1]),
		"outline_col": str(COLORS[_color_idx][2]),
		"margin_v": int(round(_margin_v)),
	}


func _resolve(action: String) -> void:
	visible = false
	_playing = false
	_audio.stop()
	EventBus.clip_review_resolved.emit(action,
		style_dict() if action == "custom" else {})


## ---- timeline ----
func _draw_timeline() -> void:
	var size_v := _timeline.size
	_timeline.draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.10, 0.10, 0.14))
	# waveform
	if not _wave.is_empty():
		var n := _wave.size()
		for i in n:
			var x := i * size_v.x / n
			var h := _wave[i] * (size_v.y * 0.52)
			_timeline.draw_line(Vector2(x, size_v.y * 0.55 - h),
				Vector2(x, size_v.y * 0.55 + h), Color(0.35, 0.45, 0.55), 1.0)
	# cue blocks along the bottom
	for i in cues.size():
		var c: Dictionary = cues[i]
		var x0: float = float(c["start"]) / _duration * size_v.x
		var x1: float = float(c["end"]) / _duration * size_v.x
		var col := Color(1.0, 0.78, 0.32, 0.85) if i == _sel else Color(0.55, 0.75, 1.0, 0.6)
		_timeline.draw_rect(Rect2(x0, size_v.y - 14, maxf(x1 - x0 - 1.0, 2.0), 11), col)
	# playhead
	var px := _t / _duration * size_v.x
	_timeline.draw_line(Vector2(px, 0), Vector2(px, size_v.y), Color(0.95, 0.45, 0.33), 2.0)


func _timeline_input(ev: InputEvent) -> void:
	var drag := ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT
	var click := ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
		and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if click or drag:
		var x: float = (ev as InputEventMouse).position.x
		_seek(x / _timeline.size.x * _duration)
