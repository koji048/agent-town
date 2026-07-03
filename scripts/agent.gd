## One townsperson. Wanders when idle; when its pipeline stage starts it
## walks to its workstation, plays the work animation while the LLM call
## runs, and chats via a speech bubble.
class_name TownAgent
extends Node2D

enum State { IDLE, WALKING, WORKING }

const FRAME_W := 32
const FRAME_H := 48
const SPEED := 75.0

const SAY_START := {
	"plan": "New request! Drafting the brief...",
	"research": "Digging for hooks and facts...",
	"script": "Writing the script...",
	"edit": "Cutting captions to size...",
	"publish": "Packaging for publish...",
	"review": "Final quality check...",
}

var role: String = ""
var town: Town
var grid_pos := Vector2i.ZERO
var state := State.IDLE

var _waypoints: Array[Vector2] = []
var _cells: Array[Vector2i] = []
var _target_is_work := false
var _sprite: AnimatedSprite2D
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_timer: Timer
var _wander_timer: Timer


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.offset = Vector2(0, -FRAME_H / 2.0)
	_sprite.play("idle")
	add_child(_sprite)
	_build_bubble()

	_wander_timer = Timer.new()
	_wander_timer.one_shot = true
	_wander_timer.timeout.connect(_wander)
	add_child(_wander_timer)
	_restart_wander()

	EventBus.stage_started.connect(_on_stage_started)
	EventBus.stage_completed.connect(_on_stage_completed)
	EventBus.agent_say.connect(func(r: String, text: String) -> void:
		if r == role:
			_say(text))


func _process(delta: float) -> void:
	if _waypoints.is_empty():
		return
	var target := _waypoints[0]
	var to_target := target - position
	var step := SPEED * delta
	if to_target.length() <= step:
		position = target
		grid_pos = _cells[0]
		_waypoints.remove_at(0)
		_cells.remove_at(0)
		if _waypoints.is_empty():
			_on_path_done()
	else:
		position += to_target.normalized() * step
		_face(to_target)


func walk_to(cell: Vector2i) -> void:
	if cell == grid_pos:
		_on_path_done()
		return
	var path := town.find_path(grid_pos, cell)
	if path.size() < 2:
		_on_path_done()
		return
	_waypoints.clear()
	_cells.clear()
	for i in range(1, path.size()):
		_cells.append(path[i])
		_waypoints.append(town.tile_center(path[i]))
	state = State.WALKING


func _on_path_done() -> void:
	if _target_is_work:
		state = State.WORKING
		_sprite.play("work")
		EventBus.agent_arrived.emit(role)
	else:
		state = State.IDLE
		_sprite.play("idle")
		_restart_wander()


func _on_stage_started(stage: String, r: String, _request: Dictionary) -> void:
	if r != role:
		return
	_target_is_work = true
	_wander_timer.stop()
	_say(str(SAY_START.get(stage, "On it...")))
	walk_to(town.workstation(role))


func _on_stage_completed(_stage: String, r: String, _request: Dictionary, _result: String) -> void:
	if r != role:
		return
	_target_is_work = false
	state = State.IDLE
	_sprite.play("idle")
	_say("Done!")
	_restart_wander()


func _wander() -> void:
	if state == State.IDLE and not _target_is_work:
		walk_to(town.random_walkable())
	_restart_wander()


func _restart_wander() -> void:
	_wander_timer.start(randf_range(4.0, 10.0))


func _face(dir: Vector2) -> void:
	var anim := "walk_s"
	if absf(dir.x) > absf(dir.y) * 2.0:
		anim = "walk_e" if dir.x > 0 else "walk_w"
	else:
		if dir.y < 0:
			anim = "walk_n" if dir.x >= 0 else "walk_w"
		else:
			anim = "walk_s" if dir.x <= 0 else "walk_e"
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _say(text: String) -> void:
	_bubble_label.text = text
	_bubble.visible = true
	_bubble_timer.start(4.0)


func _build_frames() -> SpriteFrames:
	var tex: Texture2D = load("res://assets/characters/%s.png" % role)
	var frames := SpriteFrames.new()
	var anims := ["walk_s", "walk_w", "walk_e", "walk_n", "work"]
	for row in anims.size():
		var anim: String = anims[row]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 6.0)
		frames.set_animation_loop(anim, true)
		for f in 4:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
			frames.add_frame(anim, at)
	frames.add_animation("idle")
	var idle := AtlasTexture.new()
	idle.atlas = tex
	idle.region = Rect2(0, 0, FRAME_W, FRAME_H)
	frames.add_frame("idle", idle)
	return frames


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.97, 0.94, 0.95)
	sb.border_color = Color(0.13, 0.12, 0.16)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(5)
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_size_override("font_size", 11)
	_bubble_label.add_theme_color_override("font_color", Color(0.13, 0.12, 0.16))
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(110, 0)
	_bubble.add_child(_bubble_label)
	_bubble.position = Vector2(-62, -FRAME_H - 34)
	_bubble.z_index = 100
	_bubble.visible = false
	add_child(_bubble)
	_bubble_timer = Timer.new()
	_bubble_timer.one_shot = true
	_bubble_timer.timeout.connect(func() -> void: _bubble.visible = false)
	add_child(_bubble_timer)
