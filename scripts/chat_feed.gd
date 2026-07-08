## The office group chat (AI Village's lesson: real agent chatter in
## one feed is what makes watching magnetic). Everything anyone says —
## agents and the owner — flows into a role-colored, timestamped,
## auto-scrolling timeline.
class_name ChatFeed
extends PanelContainer

const MAX_ROWS := 100
const ROLE_COLOR := {
	"director": Color(1.0, 0.85, 0.35),
	"researcher": Color(0.55, 0.85, 0.65),
	"writer": Color(1.0, 0.72, 0.45),
	"editor": Color(0.55, 0.9, 0.9),
	"publisher": Color(1.0, 0.6, 0.6),
}

var _rows: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.93)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	position = Vector2(1370, 60)
	custom_minimum_size = Vector2(530, 560)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var title := Label.new()
	I18n.reg(title, "text", "chat_feed_title")
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	root.add_child(head)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(506, 500)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	root.add_child(_scroll)
	add_child(root)

	EventBus.chat_line.connect(_add_line)


func _add_line(speaker: String, text: String) -> void:
	var t := Time.get_time_dict_from_system()
	var row := RichTextLabel.new()
	row.bbcode_enabled = true
	row.fit_content = true
	row.scroll_active = false
	row.custom_minimum_size = Vector2(500, 0)
	row.add_theme_font_size_override("normal_font_size", 13)
	var col: Color = ROLE_COLOR.get(speaker, Color(0.8, 0.9, 1.0))
	var who := speaker.to_upper() if ROLE_COLOR.has(speaker) else speaker
	row.text = "[color=#777]%02d:%02d[/color] [b][color=#%s]%s[/color][/b]  %s" % [
		t.hour, t.minute, col.to_html(false), who, text.replace("[", "(").replace("]", ")")]
	_rows.add_child(row)
	while _rows.get_child_count() > MAX_ROWS:
		_rows.get_child(0).queue_free()
	# autoscroll to the newest line
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
