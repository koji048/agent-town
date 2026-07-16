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
var FONTS: Array = []   # [family, path] pairs, discovered from assets/fonts/
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
const ZOOM := 1.2         # studio renders at a fixed 120%
const TITLE_SEC := 2.5    # EP title card shows over the first 2.5s (matches burn)

var cues: Array = []
var _srt_path := ""
var _frames_dir := ""
var _frame_total := 0
var _duration := 1.0
var _t := 0.0
var _playing := false
var _sel := -1
var _tex_cache: Dictionary = {}
var _margin_v := 360.0    # burn-canvas px from the bottom; owner-draggable

var _audio: AudioStreamPlayer
var _wave: PackedFloat32Array
var _frame_rect: TextureRect
var _cap_label: Label
var _title_label: Label
var _title_edit: TextEdit
var _title_text := ""
var _title_color := Color(1.0, 0.9, 0.15)
var _title_pos := Vector2(162.0, 200.0)  # preview-px centre of the title box
var _title_font_idx := 0
var _title_start := 0.0    # EP title window start on the timeline, seconds
var _title_dur := TITLE_SEC   # EP title window length, seconds; owner-resizable
var _title_inspector: HBoxContainer
var _title_font_pick: OptionButton
var _timeline: TimelineView
var _time_label: Label
var _play_btn: Button
var _cue_edit: TextEdit
var _start_spin: SpinBox
var _end_spin: SpinBox
var _syncing := false
var _auto_label: Label
var _font_pick: OptionButton
var _size_pick: OptionButton
var _color_idx := 0
var _color_btns: Array = []
var _use_custom := false      # a free-picked colour overrides the presets
var _custom_color := Color(1, 1, 1)
var _list_toggle: CheckButton
var _list_scroll: ScrollContainer
var _list_box: VBoxContainer


func _ready() -> void:
	visible = false
	FONTS = _discover_fonts()
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
	# Instagram Reels safe-zone guides (yellow, CapCut-style) — the areas IG's
	# own UI covers; keep captions/logos out of them. Research (1080x1920):
	# bottom ~420px (caption, @handle, audio, CTA), top ~250px (progress +
	# profile), right ~130px action-button column. Mouse-transparent.
	var ps := PREVIEW_SCALE
	var fill := Color(1.0, 0.85, 0.12, 0.13)
	var edge := Color(1.0, 0.88, 0.22, 0.85)
	# bottom band + top edge line
	_ig_guide(frame_holder, Control.PRESET_BOTTOM_WIDE, 0, -420.0 * ps, 0, 0, fill)
	_ig_guide(frame_holder, Control.PRESET_BOTTOM_WIDE, 0, -420.0 * ps, 0, -420.0 * ps + 2.0, edge)
	# top band + bottom edge line
	_ig_guide(frame_holder, Control.PRESET_TOP_WIDE, 0, 0, 0, 250.0 * ps, fill)
	_ig_guide(frame_holder, Control.PRESET_TOP_WIDE, 0, 250.0 * ps - 2.0, 0, 250.0 * ps, edge)
	# right action-button column (lower) + left edge line
	_ig_guide(frame_holder, Control.PRESET_RIGHT_WIDE, -130.0 * ps, 770.0 * ps, 0, -420.0 * ps, fill)
	_ig_guide(frame_holder, Control.PRESET_RIGHT_WIDE, -130.0 * ps, 770.0 * ps, -130.0 * ps + 2.0, -420.0 * ps, edge)
	var ig_lbl := Label.new()
	ig_lbl.text = "IG safe zone"
	ig_lbl.add_theme_font_size_override("font_size", 10)
	ig_lbl.modulate = Color(1.0, 0.9, 0.4, 0.9)
	ig_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ig_lbl.offset_top = 250.0 * ps + 2.0
	ig_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ig_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_holder.add_child(ig_lbl)
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
	# EP title: a 2D-draggable, styleable text box (CapCut-like); its text /
	# font / colour come from the EP Title strip in the right column
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.size = Vector2(300, 64)
	_title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_title_label.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			_title_pos += (ev as InputEventMouseMotion).relative
			_place_title())
	_title_label.visible = false
	frame_holder.add_child(_title_label)
	_apply_title_style()
	_place_title()
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
			_use_custom = false
			_style_color_btns()
			_apply_style())
		cr.add_child(cb)
		_color_btns.append(cb)
	# free colour pick — any colour, not just the presets
	var custom_pick := ColorPickerButton.new()
	custom_pick.custom_minimum_size = Vector2(44, 0)
	custom_pick.color = Color(1, 1, 1)
	custom_pick.color_changed.connect(func(col: Color) -> void:
		_use_custom = true
		_custom_color = col
		_style_color_btns()
		_apply_style())
	cr.add_child(custom_pick)
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
	# ---- EP Title strip: its own text + font + colour, separate from captions
	_title_inspector = HBoxContainer.new()
	var title_row := _title_inspector
	title_row.add_theme_constant_override("separation", 6)
	var tlbl := Label.new()
	tlbl.text = "EP Title:"
	tlbl.add_theme_font_size_override("font_size", 13)
	tlbl.modulate = Color(1.0, 0.9, 0.4)
	title_row.add_child(tlbl)
	_title_edit = TextEdit.new()
	_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_edit.custom_minimum_size = Vector2(0, 48)
	_title_edit.placeholder_text = "EP title text"
	_title_edit.scroll_fit_content_height = true
	_title_edit.text_changed.connect(func() -> void:
		var t := _title_edit.text
		_title_text = t
		if _title_label:
			_title_label.text = t
		if _timeline:
			_timeline.title_text = t
		_apply_title_style()
		_place_title()
		_show_time())
	title_row.add_child(_title_edit)
	_title_font_pick = OptionButton.new()
	var tfp := _title_font_pick
	for fdef in FONTS:
		tfp.add_item(str(fdef[0]))
	tfp.item_selected.connect(func(i: int) -> void:
		_title_font_idx = i
		_apply_title_style())
	title_row.add_child(tfp)
	var tcp := ColorPickerButton.new()
	tcp.custom_minimum_size = Vector2(40, 0)
	tcp.color = _title_color
	tcp.color_changed.connect(func(col: Color) -> void:
		_title_color = col
		_apply_title_style())
	title_row.add_child(tcp)
	right.add_child(title_row)
	_title_inspector.visible = false
	_cue_edit = TextEdit.new()
	_cue_edit.custom_minimum_size = Vector2(0, 84)
	_cue_edit.add_theme_font_size_override("font_size", 16)
	right.add_child(_cue_edit)
	# type exact start/end seconds for the selected cue
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	var tl := Label.new()
	tl.text = "⏱"
	trow.add_child(tl)
	_start_spin = SpinBox.new()
	_start_spin.step = 0.05
	_start_spin.min_value = 0.0
	_start_spin.max_value = 99999.0
	_start_spin.suffix = "s"
	_start_spin.custom_minimum_size = Vector2(96, 0)
	_start_spin.value_changed.connect(func(_v: float) -> void:
		if not _syncing:
			_apply_time_fields())
	trow.add_child(_start_spin)
	var arrow := Label.new()
	arrow.text = "→"
	trow.add_child(arrow)
	_end_spin = SpinBox.new()
	_end_spin.step = 0.05
	_end_spin.min_value = 0.0
	_end_spin.max_value = 99999.0
	_end_spin.suffix = "s"
	_end_spin.custom_minimum_size = Vector2(96, 0)
	_end_spin.value_changed.connect(func(_v: float) -> void:
		if not _syncing:
			_apply_time_fields())
	trow.add_child(_end_spin)
	right.add_child(trow)
	var save := Button.new()
	I18n.reg(save, "text", "btn_save_cue")
	save.pressed.connect(_save_cue)
	right.add_child(save)
	_list_toggle = CheckButton.new()
	_list_toggle.text = "📋 รายการซับ"
	_list_toggle.toggled.connect(func(on: bool) -> void:
		_list_scroll.visible = on
		if on:
			_rebuild_list_view())
	right.add_child(_list_toggle)
	_list_scroll = ScrollContainer.new()
	_list_scroll.visible = false
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.custom_minimum_size = Vector2(0, 240)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list_box)
	right.add_child(_list_scroll)
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

	# ---- bottom: 3-row timeline (Title / Caption / Media)
	_timeline = TimelineView.new()
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.cue_selected.connect(_on_cue_selected)
	_timeline.cue_time_changed.connect(_on_cue_time_changed)
	_timeline.edit_committed.connect(_on_edit_committed)
	_timeline.cue_split.connect(_on_cue_split)
	_timeline.cue_deleted.connect(_on_cue_deleted)
	_timeline.seek.connect(_seek)
	_timeline.title_selected.connect(_on_title_selected)
	_timeline.selection_cleared.connect(_on_selection_cleared)
	_timeline.title_time_changed.connect(_on_title_time_changed)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	var cut_btn := Button.new()
	cut_btn.text = "✂️ ตัด (S)"
	cut_btn.pressed.connect(func() -> void: _timeline.cut_at_playhead())
	tools.add_child(cut_btn)
	var del_btn := Button.new()
	del_btn.text = "🗑 ลบ (Del)"
	del_btn.pressed.connect(func() -> void: _timeline.delete_selected())
	tools.add_child(del_btn)
	var all_btn := Button.new()
	all_btn.text = "⬚ เลือกทั้งหมด"
	all_btn.pressed.connect(func() -> void: _timeline.select_all())
	tools.add_child(all_btn)
	var thint := Label.new()
	thint.text = "ตัด/ลบที่หัวอ่าน · เลือกทั้งหมดแล้วลากเพื่อเลื่อนทั้งชุด"
	thint.add_theme_font_size_override("font_size", 11)
	thint.modulate = Color(0.7, 0.7, 0.76)
	tools.add_child(thint)
	root.add_child(tools)
	root.add_child(_timeline)
	# Timing is edited on the TimelineView strip below (drag/trim/cut/delete),
	# not a scrollable cue list — there is no cue list in this layout.
	add_child(root)
	# fixed 120% zoom, scaled from the top edge so the top never leaves screen
	pivot_offset = Vector2(custom_minimum_size.x / 2.0, 0.0)
	scale = Vector2(ZOOM, ZOOM)
	_style_color_btns()


func open_clip(srt_path: String, frames_dir: String, title := "") -> void:
	_srt_path = srt_path
	_title_text = title
	if _title_label:
		_title_label.text = title
	if _title_edit:
		_title_edit.text = title
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
	# reset only the position per clip; font / size / colour persist across clips
	_margin_v = 360.0
	_place_caption()
	if _start_spin:
		_start_spin.max_value = _duration
		_end_spin.max_value = _duration
	_title_start = 0.0
	_title_dur = TITLE_SEC
	_timeline.cues = cues
	_timeline.duration = _duration
	_timeline.wave = _wave
	_timeline.frames = _sample_strip()
	_timeline.title_text = _title_text
	_timeline.title_start = _title_start
	_timeline.title_dur = _title_dur
	_timeline.sel_kind = "none"
	_timeline.sel_cue = -1
	_show_inspector("none")
	_apply_style()
	_show_time()
	visible = true
	Sfx.play_ui("paper", -8.0)
	_refresh_list()


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
	if _title_label:
		_title_label.visible = not _title_text.is_empty()
	_timeline.playhead = _t
	_timeline.title_start = _title_start
	_timeline.title_dur = _title_dur
	_timeline.queue_redraw()


func _cue_text_at(t: float) -> String:
	for c in cues:
		if t >= float(c["start"]) and t <= float(c["end"]):
			return str(c["text"])
	return ""


## Up to 12 evenly-spaced filmstrip thumbnails for the timeline's Media row.
func _sample_strip() -> Array:
	var out: Array = []
	if _frame_total <= 0:
		return out
	var count := mini(12, _frame_total)
	for k in count:
		var idx := clampi(int(float(k) / count * _frame_total) + 1, 1, _frame_total)
		var img := Image.new()
		if img.load(_frames_dir.path_join("f_%05d.jpg" % idx)) == OK:
			out.append(ImageTexture.create_from_image(img))
	return out


## A caption box was clicked: load it into the Inspector and seek to its start.
func _on_cue_selected(i: int) -> void:
	_sel = i
	_cue_edit.text = str(cues[i]["text"])
	_sync_time_fields()
	_show_inspector("caption")
	_seek(float(cues[i]["start"]))
	_refresh_list()


## Live drag of a caption edge/body: reflect timing into the spins + preview.
func _on_cue_time_changed(i: int, _s: float, _e: float) -> void:
	if i == _sel:
		_sync_time_fields()
	_show_time()


## Drag/keyboard edit finished: persist the cues to the .srt.
func _on_edit_committed() -> void:
	PreviewMaker.write_srt(cues, _srt_path)


## A caption was split: persist, keep the left half selected, refresh Inspector.
func _on_cue_split(i: int, _at: float) -> void:
	PreviewMaker.write_srt(cues, _srt_path)
	_on_cue_selected(i)
	_refresh_list()


## A caption was deleted: persist and clear the Inspector.
func _on_cue_deleted(_i: int) -> void:
	PreviewMaker.write_srt(cues, _srt_path)
	_sel = -1
	_show_inspector("none")
	_refresh_list()


## The title box was clicked: show the EP Title strip in the Inspector.
func _on_title_selected() -> void:
	_sel = -1
	_show_inspector("title")


## Empty space was clicked: nothing selected, show just the hint.
func _on_selection_cleared() -> void:
	_sel = -1
	_show_inspector("none")


## Live drag/resize of the title box: reflect its new start + duration.
func _on_title_time_changed(start: float, dur: float) -> void:
	_title_start = start
	_title_dur = dur
	_show_time()


## Push the spin values into the selected cue (clamped), persist, redraw.
func _apply_time_fields() -> void:
	if _sel < 0 or _sel >= cues.size():
		return
	var sp := TimelineView.clamp_span(cues, _sel, _start_spin.value, _end_spin.value, _duration)
	cues[_sel]["start"] = sp[0]
	cues[_sel]["end"] = sp[1]
	PreviewMaker.write_srt(cues, _srt_path)
	_sync_time_fields()
	_show_time()
	_refresh_list()


## Reflect the selected cue's start/end into the spins without re-triggering.
func _sync_time_fields() -> void:
	if not _start_spin or _sel < 0 or _sel >= cues.size():
		return
	_syncing = true
	_start_spin.value = float(cues[_sel]["start"])
	_end_spin.value = float(cues[_sel]["end"])
	_syncing = false


func _save_cue() -> void:
	if _sel < 0 or _sel >= cues.size():
		return
	cues[_sel]["text"] = _cue_edit.text.strip_edges()
	PreviewMaker.write_srt(cues, _srt_path)
	EventBus.log_line.emit("✏ Caption %d fixed -> %s" % [_sel + 1, _srt_path.get_file()])
	Sfx.play_ui("paper", -10.0)
	_timeline.title_text = _title_text
	_timeline.queue_redraw()
	_show_time()
	_refresh_list()


## Discover every font file in assets/fonts/ so the picker offers them all —
## drop a .ttf/.otf in that folder to add a choice. The ASS Fontname must be
## the FAMILY, so strip the style suffix Godot appends (e.g. "Kanit SemiBold"
## -> "Kanit"); libass matches the family via the same fontsdir.
func _discover_fonts() -> Array:
	var out: Array = []
	var d := DirAccess.open("res://assets/fonts")
	if d:
		var files := d.get_files()
		files.sort()
		for f in files:
			if f.get_extension().to_lower() in ["ttf", "otf"]:
				var path := "res://assets/fonts/" + f
				var ff := FontFile.new()
				if ff.load_dynamic_font(path) == OK:
					var fam := ff.get_font_name()
					var sty := ff.get_font_style_name()
					if sty != "" and sty != "Regular" and fam.ends_with(" " + sty):
						fam = fam.trim_suffix(" " + sty)
					out.append([fam, path])
	if out.is_empty():
		out = [["Anuphan", "res://assets/fonts/Anuphan.ttf"]]
	return out


## A mouse-transparent guide rect for a safe-zone overlay.
func _ig_guide(parent: Control, at: int, l: float, t: float, r: float, b: float, col: Color) -> void:
	var g := ColorRect.new()
	g.set_anchors_preset(at)
	g.offset_left = l
	g.offset_top = t
	g.offset_right = r
	g.offset_bottom = b
	g.color = col
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)


## libass sizes text by the GDI CELL height (OS/2 winAscent+winDescent), Godot
## by em — so at the same number the burn renders SMALLER than a Godot Label,
## by upem/(winAsc+winDesc), which varies per font (Anuphan 0.69, ChakraPetch
## 0.55, Charmonman 0.39; measured: Fontsize 72 burns 40px tall vs Godot 60px).
## Parse that ratio from the font file so the preview matches the real burn.
## (sfnt tables are BIG-endian; PackedByteArray decode_* is little-endian.)
static func ass_font_ratio(path: String) -> float:
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 12:
		return 1.0
	var ntab := _be16(b, 4)
	var head := -1
	var os2 := -1
	for i in ntab:
		var off := 12 + i * 16
		if off + 16 > b.size():
			return 1.0
		var tag := b.slice(off, off + 4).get_string_from_ascii()
		if tag == "head":
			head = _be32(b, off + 8)
		elif tag == "OS/2":
			os2 = _be32(b, off + 8)
	if head < 0 or os2 < 0 or head + 20 > b.size() or os2 + 78 > b.size():
		return 1.0
	var upem := _be16(b, head + 18)
	var cell := _be16(b, os2 + 74) + _be16(b, os2 + 76)
	if upem == 0 or cell == 0:
		return 1.0
	return float(upem) / float(cell)


static func _be16(b: PackedByteArray, o: int) -> int:
	return (b[o] << 8) | b[o + 1]


static func _be32(b: PackedByteArray, o: int) -> int:
	return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]


var _ratio_cache: Dictionary = {}


func _font_ratio(path: String) -> float:
	if not _ratio_cache.has(path):
		_ratio_cache[path] = ass_font_ratio(path)
	return float(_ratio_cache[path])


## Style the title text box from the title state (font, colour, size).
func _apply_title_style() -> void:
	if not _title_label:
		return
	var ls := LabelSettings.new()
	var font := FontFile.new()
	font.load_dynamic_font(str(FONTS[_title_font_idx][1]))
	ls.font = font
	ls.font_size = int(round(100.0 * PREVIEW_SCALE * _font_ratio(str(FONTS[_title_font_idx][1]))))
	ls.font_color = _title_color
	ls.outline_size = 3
	ls.outline_color = Color(0, 0, 0)
	_title_label.label_settings = ls


## Position the title box centred on _title_pos (preview px).
func _place_title() -> void:
	if _title_label:
		_title_label.position = _title_pos - _title_label.size / 2.0


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
	ls.font_size = int(round(int(SIZES[_size_pick.selected][1]) * PREVIEW_SCALE \
		* _font_ratio(str(FONTS[_font_pick.selected][1]))))
	ls.font_color = _custom_color if _use_custom else (COLORS[_color_idx][3] as Color)
	ls.outline_size = maxi(1, int(round(3.0 * PREVIEW_SCALE)))
	ls.outline_color = Color(0, 0, 0) if _use_custom else (COLORS[_color_idx][4] as Color)
	_cap_label.label_settings = ls
	_show_time()


func _style_color_btns() -> void:
	for i in _color_btns.size():
		(_color_btns[i] as Button).text = (" ◉ " if (i == _color_idx and not _use_custom) else " ") \
			+ str(COLORS[i][0]) + " "


func style_dict() -> Dictionary:
	return {
		"font_name": str(FONTS[_font_pick.selected][0]),
		"size": int(SIZES[_size_pick.selected][1]),
		"primary": _ass_color(_custom_color) if _use_custom else str(COLORS[_color_idx][1]),
		"outline_col": "&H00000000" if _use_custom else str(COLORS[_color_idx][2]),
		"margin_v": int(round(_margin_v)),
		# EP title element: its own text, font, colour and 2D position
		"title_text": _title_text,
		"title_font": str(FONTS[_title_font_idx][0]),
		"title_size": 100,
		"title_primary": _ass_color(_title_color),
		"title_x": int(round(_title_pos.x / PREVIEW_SCALE)),
		"title_y": int(round(_title_pos.y / PREVIEW_SCALE)),
		"title_start": _title_start,
		"title_end": _title_start + _title_dur,
	}


## Godot Color -> ASS &H00BBGGRR (opaque; libass colours are BGR).
func _ass_color(c: Color) -> String:
	return "&H00%02X%02X%02X" % [c.b8, c.g8, c.r8]


func _resolve(action: String) -> void:
	visible = false
	_playing = false
	_audio.stop()
	EventBus.clip_review_resolved.emit(action,
		style_dict() if action == "custom" else {})


## Read-only list of every cue; click a row to select + seek it. Rebuilt only
## while the panel is visible.
func _rebuild_list_view() -> void:
	if not _list_box:
		return
	for ch in _list_box.get_children():
		ch.queue_free()
	for i in cues.size():
		var c: Dictionary = cues[i]
		var b := Button.new()
		b.text = "%d:%04.1f  %s" % [int(float(c["start"])) / 60, fmod(float(c["start"]), 60.0), str(c["text"]).left(40)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		if i == _sel:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		var idx := i
		b.pressed.connect(func() -> void:
			_timeline.sel_kind = "cue"
			_timeline.sel_cue = idx
			_on_cue_selected(idx)
			_timeline.queue_redraw())
		_list_box.add_child(b)


## Rebuild the list only if it is currently shown.
func _refresh_list() -> void:
	if _list_scroll and _list_scroll.visible:
		_rebuild_list_view()


## Show only the editor widgets for the current selection.
##   "caption" -> text edit + timing spins (+ the shared style bar on the left)
##   "title"   -> the EP Title strip (text + font + colour)
##   "none"    -> neither; just the hint
func _show_inspector(kind: String) -> void:
	_cue_edit.visible = kind == "caption"
	_start_spin.get_parent().visible = kind == "caption"
	if _title_inspector:
		_title_inspector.visible = kind == "title"
