## One agent in the office: a real animated 3D character (KayKit
## Adventurers, CC0) — Ragnarok-style job classes for our crew. Same FSM
## as ever: wander when idle, walk to the workstation when its stage
## starts, play a work animation during the LLM call, Cheer when done.
class_name TownAgent3D
extends Node3D

enum State { IDLE, WALKING, WORKING }

const CHAR_H := 1.35
const SPEED := 1.7
const TURN_SPEED := 10.0

## Ragnarok-style job mapping per role.
const JOB_MODEL := {
	"director": "Knight",
	"researcher": "Mage",
	"writer": "Rogue_Hooded",
	"editor": "Rogue",
	"publisher": "Barbarian",
}

const WORK_ANIM := {
	"director": "Interact",
	"researcher": "Spellcasting",
	"writer": "Use_Item",
	"editor": "1H_Melee_Attack_Slice_Horizontal",
	"publisher": "Use_Item",
}

const SAY_START := {
	"plan": "New request! Drafting the brief...",
	"research": "Digging for hooks and facts...",
	"script": "Writing the script...",
	"edit": "Cutting captions to size...",
	"publish": "Packaging for publish...",
	"review": "Final quality check...",
}

const STATE_STYLE := {
	State.IDLE: ["IDLE", Color(0.72, 0.76, 0.72)],
	State.WALKING: ["WALKING", Color(0.55, 0.75, 1.0)],
	State.WORKING: ["WORKING", Color(1.0, 0.72, 0.32)],
}

var role: String = ""
var office: Office3D
var grid_pos := Vector2i.ZERO
var state := State.IDLE

var _waypoints: Array[Vector3] = []
var _cells: Array[Vector2i] = []
var _target_is_work := false
var _model: Node3D
var _anim: AnimationPlayer
var _target_yaw := 0.0
var _bubble: Label3D
var _bubble_timer: Timer
var _wander_timer: Timer
var _plate_state: Label3D


func _ready() -> void:
	_model = _load_character(str(JOB_MODEL.get(role, "Knight")))
	add_child(_model)
	_play("Idle")

	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.font_size = 64
	_bubble.outline_size = 18
	_bubble.pixel_size = 0.0042
	_bubble.modulate = Color(0.98, 0.97, 0.94)
	_bubble.outline_modulate = Color(0.13, 0.12, 0.16)
	_bubble.position = Vector3(0, CHAR_H + 0.72, 0)
	_bubble.visible = false
	add_child(_bubble)

	# nameplate: role name (gold for the boss) + live state pill
	var plate_name := _make_plate(role.to_upper(), 64,
		Color(1.0, 0.85, 0.35) if role == "director" else Color(0.96, 0.96, 0.92))
	plate_name.position = Vector3(0, CHAR_H + 0.5, 0)
	_plate_state = _make_plate("IDLE", 44, Color(0.72, 0.76, 0.72))
	_plate_state.position = Vector3(0, CHAR_H + 0.28, 0)

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
	# smooth turning toward the travel direction
	if _model:
		_model.rotation.y = lerp_angle(_model.rotation.y, _target_yaw, TURN_SPEED * delta)
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
		_target_yaw = atan2(to_target.x, to_target.z)


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
	_set_state(State.WALKING)
	_play("Walking_A")


func _on_path_done() -> void:
	if _target_is_work:
		_set_state(State.WORKING)
		_play(str(WORK_ANIM.get(role, "Interact")))
		# face the desk (north) while working
		_target_yaw = PI
		EventBus.agent_arrived.emit(role)
	else:
		_set_state(State.IDLE)
		_play("Idle")
		_restart_wander()


func _on_stage_started(stage: String, r: String, _request: Dictionary) -> void:
	if r != role:
		return
	_target_is_work = true
	_wander_timer.stop()
	_pop_fx("!", Color(1.0, 0.78, 0.3))
	_say(str(SAY_START.get(stage, "On it...")))
	walk_to(office.workstation(role))


func _on_stage_completed(_stage: String, r: String, _request: Dictionary, result: String) -> void:
	if r != role:
		return
	_target_is_work = false
	_set_state(State.IDLE)
	if result.begins_with("(stage"):
		_pop_fx("x", Color(1.0, 0.42, 0.42))
		_say("That one failed...")
		_play("Idle")
	else:
		_pop_fx("+", Color(0.45, 1.0, 0.55))
		_say("Done!")
		_play_once_then_idle("Cheer")
	_restart_wander()


func _wander() -> void:
	if state == State.IDLE and not _target_is_work:
		walk_to(office.random_walkable())
	_restart_wander()


func _restart_wander() -> void:
	_wander_timer.start(randf_range(4.0, 10.0))


func _say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_timer.start(4.0)


func _set_state(s: State) -> void:
	state = s
	if _plate_state:
		var style: Array = STATE_STYLE[s]
		_plate_state.text = style[0]
		_plate_state.modulate = style[1]


# ------------------------------------------------------------ character

func _load_character(model_name: String) -> Node3D:
	var root := Node3D.new()
	var path := "res://assets/models/characters/%s.glb" % model_name
	if not FileAccess.file_exists(path):
		push_warning("missing character model: " + path)
		return root
	var doc := GLTFDocument.new()
	var state_g := GLTFState.new()
	if doc.append_from_file(path, state_g) != OK:
		push_warning("failed to parse " + path)
		return root
	var node := doc.generate_scene(state_g) as Node3D
	# normalize height to CHAR_H, feet at y=0
	var aabb := _combined_aabb(node, Transform3D.IDENTITY)
	if aabb.size.y > 0.001:
		var s := CHAR_H / aabb.size.y
		node.scale = Vector3.ONE * s
		node.position = Vector3(
			-(aabb.position.x + aabb.size.x / 2.0) * s,
			-aabb.position.y * s,
			-(aabb.position.z + aabb.size.z / 2.0) * s)
	root.add_child(node)
	_anim = node.find_children("*", "AnimationPlayer", true, false)[0] if not node.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	return root


func _play(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	# ensure sustained states loop
	if anim_name == "Idle" or anim_name.begins_with("Walking") or WORK_ANIM.values().has(anim_name):
		var a := _anim.get_animation(anim_name)
		a.loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name, 0.25)


func _play_once_then_idle(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		_play("Idle")
		return
	var a := _anim.get_animation(anim_name)
	a.loop_mode = Animation.LOOP_NONE
	_anim.play(anim_name, 0.25)
	var cb := func(finished: StringName) -> void:
		if finished == StringName(anim_name) and state != State.WORKING:
			_play("Idle")
	_anim.animation_finished.connect(cb, CONNECT_ONE_SHOT)


func _combined_aabb(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var has := false
	var local_xf := xf
	if node is Node3D:
		local_xf = xf * (node as Node3D).transform
	if node is MeshInstance3D:
		result = local_xf * (node as MeshInstance3D).get_aabb()
		has = true
	for child in node.get_children():
		var sub := _combined_aabb(child, local_xf)
		if sub.size.length() > 0.0001:
			result = result.merge(sub) if has else sub
			has = true
	return result


# ------------------------------------------------------------ HUD bits

func _make_plate(text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = size / 4
	l.pixel_size = 0.0032
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.1, 0.13, 0.9)
	add_child(l)
	return l


## Event FX: a symbol pops above the head, floats up, fades.
func _pop_fx(symbol: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = symbol
	l.font_size = 72
	l.outline_size = 18
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.1, 0.13)
	l.position = Vector3(0, CHAR_H + 0.9, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 0.6, 1.1)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1)
	tw.tween_callback(l.queue_free)
