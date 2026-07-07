## In-game costume panel (toggle with C): per-agent equipment slots —
## class, headgear, right/left hand, bracers, cape — plus Office and
## Adventure presets. Changes apply live and persist to user://costumes.json.
class_name CostumePanel
extends PanelContainer

signal costume_changed(role: String, costume: Dictionary)

const ROLES := ["director", "researcher", "writer", "editor", "publisher"]
const SLOTS := [
	["class", "Class", Costumes.CLASSES],
	["headgear", "Headgear", Costumes.HEADGEAR],
	["right", "Right hand", Costumes.RIGHT_HAND],
	["left", "Left hand", Costumes.LEFT_HAND],
]

var costumes: Dictionary = {}
var current_role := "director"

var _role_buttons: Dictionary = {}
var _value_labels: Dictionary = {}
var _bracers_check: CheckBox
var _cape_check: CheckBox


func _ready() -> void:
	costumes = Costumes.load_all()
	for r in ROLES:
		if not costumes.has(r):
			costumes[r] = Costumes.OFFICE_PRESET[r].duplicate(true)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.11, 0.92)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	var title := Label.new()
	title.text = "COSTUMES  —  press C to close"
	title.add_theme_font_size_override("font_size", 15)
	vb.add_child(title)

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 4)
	vb.add_child(role_row)
	for r in ROLES:
		var b := Button.new()
		b.text = r.to_upper()
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(_on_role_selected.bind(r))
		role_row.add_child(b)
		_role_buttons[r] = b

	for slot in SLOTS:
		var key: String = slot[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vb.add_child(row)
		var name_l := Label.new()
		name_l.text = str(slot[1]) + ":"
		name_l.custom_minimum_size = Vector2(90, 0)
		name_l.add_theme_font_size_override("font_size", 12)
		row.add_child(name_l)
		var prev := Button.new()
		prev.text = "<"
		prev.pressed.connect(_cycle.bind(key, -1))
		row.add_child(prev)
		var val := Label.new()
		val.custom_minimum_size = Vector2(150, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 12)
		row.add_child(val)
		_value_labels[key] = val
		var next := Button.new()
		next.text = ">"
		next.pressed.connect(_cycle.bind(key, 1))
		row.add_child(next)

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 16)
	vb.add_child(toggles)
	_bracers_check = CheckBox.new()
	_bracers_check.text = "Bracers"
	_bracers_check.toggled.connect(func(on: bool) -> void: _set_value("bracers", on))
	toggles.add_child(_bracers_check)
	_cape_check = CheckBox.new()
	_cape_check.text = "Cape"
	_cape_check.toggled.connect(func(on: bool) -> void: _set_value("cape", on))
	toggles.add_child(_cape_check)

	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	vb.add_child(presets)
	var office_btn := Button.new()
	office_btn.text = "Office preset (all)"
	office_btn.pressed.connect(_apply_preset.bind(Costumes.OFFICE_PRESET))
	presets.add_child(office_btn)
	var adv_btn := Button.new()
	adv_btn.text = "Adventure preset (all)"
	adv_btn.pressed.connect(_apply_preset.bind(Costumes.ADVENTURE_PRESET))
	presets.add_child(adv_btn)

	_on_role_selected(current_role)


func _on_role_selected(r: String) -> void:
	current_role = r
	for key in _role_buttons:
		(_role_buttons[key] as Button).button_pressed = key == r
	_refresh()


func _refresh() -> void:
	var c: Dictionary = costumes[current_role]
	for slot in SLOTS:
		var key: String = slot[0]
		(_value_labels[key] as Label).text = Costumes.label_for(str(c.get(key, "none")))
	_bracers_check.set_pressed_no_signal(bool(c.get("bracers", false)))
	_cape_check.set_pressed_no_signal(bool(c.get("cape", false)))


func _cycle(key: String, dir: int) -> void:
	var options: Array = []
	for slot in SLOTS:
		if slot[0] == key:
			options = slot[2]
			break
	var c: Dictionary = costumes[current_role]
	var idx := options.find(str(c.get(key, options[0])))
	idx = (idx + dir + options.size()) % options.size()
	_set_value(key, str(options[idx]))


func _set_value(key: String, value: Variant) -> void:
	var c: Dictionary = costumes[current_role]
	c[key] = value
	_refresh()
	Costumes.save_all(costumes)
	costume_changed.emit(current_role, c)


func _apply_preset(preset: Dictionary) -> void:
	for r in ROLES:
		costumes[r] = (preset[r] as Dictionary).duplicate(true)
		costume_changed.emit(r, costumes[r])
	Costumes.save_all(costumes)
	_refresh()
