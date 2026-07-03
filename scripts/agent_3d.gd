## One agent in the 3D office: a 2D pixel-art spritesheet rendered as a
## Y-billboard (Octopath style), casting real shadows. Same FSM as ever:
## wander when idle, walk to the workstation when its stage starts, play
## the work animation while the LLM call runs, chat via a floating label.
class_name TownAgent3D
extends Node3D

enum State { IDLE, WALKING, WORKING }

const FRAME_W := 32
const FRAME_H := 48
const PIXEL_SIZE := 0.032
const SPEED := 1.7

const SAY_START := {
	"plan": "New request! Drafting the brief...",
	"research": "Digging for hooks and facts...",
	"script": "Writing the script...",
	"edit": "Cutting captions to size...",
	"publish": "Packaging for publish...",
	"review": "Final quality check...",
}

var role: String = ""
var office: Office3D
var grid_pos := Vector2i.ZERO
var state := State.IDLE

var _waypoints: Array[Vector3] = []
var _cells: Array[Vector2i] = []
var _target_is_work := false
var _sprite: AnimatedSprite3D
var _bubble: Label3D
var _bubble_timer: Timer
var _wander_timer: Timer


func _ready() -> void:
	_sprite = AnimatedSprite3D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector3(0, FRAME_H * PIXEL_SIZE / 2.0, 0)
	_sprite.play("idle")
	add_child(_sprite)

	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.font_size = 40
	_bubble.outline_size = 14
	_bubble.pixel_size = 0.006
	_bubble.modulate = Color(0.98, 0.97, 0.94)
	_bubble.outline_modulate = Color(0.13, 0.12, 0.16)
	_bubble.position = Vector3(0, FRAME_H * PIXEL_SIZE + 0.45, 0)
	_bubble.visible = false
	add_child(_bubble)

	_bubble_timer = Timer.new()
	_bubble_timer.one_shot = true
	_bubble_timer.timeout.connect(func() -> void: _bubble.visible = false)
	add_child(_bubble_timer)

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
	to_target.y = 0.0
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
	var path := office.find_path(grid_pos, cell)
	if path.size() < 2:
		_on_path_done()
		return
	_waypoints.clear()
	_cells.clear()
	for i in range(1, path.size()):
		_cells.append(path[i])
		_waypoints.append(office.grid_to_world(path[i]))
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
	walk_to(office.workstation(role))


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
		walk_to(office.random_walkable())
	_restart_wander()


func _restart_wander() -> void:
	_wander_timer.start(randf_range(4.0, 10.0))


func _face(dir: Vector3) -> void:
	## Map world movement to spritesheet facing under the fixed iso camera:
	## +x reads as down-right (east), +z as down-left (south).
	var anim := "walk_s"
	if absf(dir.x) > absf(dir.z):
		anim = "walk_e" if dir.x > 0 else "walk_w"
	else:
		anim = "walk_s" if dir.z > 0 else "walk_n"
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _say(text: String) -> void:
	_bubble.text = text
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
