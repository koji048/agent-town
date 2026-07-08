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

## Short character sketches: constraint is what makes dialogue read as
## a PERSON (Inworld's lesson). Used in gossip + click-chat prompts.
const PERSONA := {
	"director": "the Director: decisive, warm-bossy, ex-agency, secretly sentimental about the team",
	"researcher": "the Researcher: curious, precise, quotes numbers, mildly allergic to hype",
	"writer": "the Writer: playful wordsmith, dramatic about deadlines, lives on garden breaks",
	"editor": "the Editor: dry humor, perfectionist about timing, guards the espresso machine",
	"publisher": "the Publisher: upbeat trend-watcher, speaks in hooks, loves shipping day",
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
var _celebrating := false
var _model: Node3D
var _anim: AnimationPlayer
var _target_yaw := 0.0
var _bubble: Label3D
var _bubble_timer: Timer
var _wander_timer: Timer
var _step_accum := 0.0
var _type_timer: Timer
var _doc: Node3D

## Decaying needs (The Sims): a reason to move, always. Personality
## weights make each role satisfy needs differently.
var needs := {"energy": 1.0, "social": 1.0, "inspiration": 1.0}
const NEED_WEIGHT := {
	"director": {"energy": 1.2, "social": 1.1, "inspiration": 0.8},
	"researcher": {"energy": 0.9, "social": 0.7, "inspiration": 1.3},
	"writer": {"energy": 1.0, "social": 1.0, "inspiration": 1.4},
	"editor": {"energy": 1.3, "social": 0.8, "inspiration": 1.0},
	"publisher": {"energy": 1.0, "social": 1.3, "inspiration": 0.9},
}
var _break_ad: Dictionary = {}
var _meeting := false
## What this agent is doing right now, for the team board.
var current_task := "available"

## Standing spots around the meeting-nook table, one per role.
const MEETING_SPOTS := {
	"director": Vector2i(3, 3), "researcher": Vector2i(2, 2),
	"writer": Vector2i(5, 2), "editor": Vector2i(4, 3),
	"publisher": Vector2i(2, 3),
}
var _plate_state: Label3D

var costume: Dictionary = {}
var _skeleton: Skeleton3D
var _attach_head: BoneAttachment3D
var _attach_r: BoneAttachment3D
var _attach_l: BoneAttachment3D
var _attach_arm_l: BoneAttachment3D
var _attach_arm_r: BoneAttachment3D

static var _item_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("agents")
	costume = Costumes.load_all().get(role, Costumes.OFFICE_PRESET.get(role, {})).duplicate(true)
	if not costume.has("class"):
		costume["class"] = str(JOB_MODEL.get(role, "Knight"))
	_model = _load_character(str(costume["class"]))
	add_child(_model)
	_setup_attachments()
	_apply_costume_parts()
	_play("Idle")

	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.font_size = 66
	_bubble.outline_size = 22
	_bubble.pixel_size = 0.0042
	_bubble.font = I18n.ui_font
	_bubble.modulate = Color(1.0, 0.99, 0.92)
	_bubble.outline_modulate = Color(0.10, 0.09, 0.13)
	# wrapped speech above the head (name/state live at the feet now)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.width = 420.0
	_bubble.position = Vector3(0, CHAR_H + 0.55, 0)
	_bubble.visible = false
	add_child(_bubble)

	# nameplate: role name (gold for the boss) + live state pill
	# (design-at-viewing-size: large glyphs, opaque outline, and the
	# state label only appears when the agent is actually doing something)
	# name + state at the FEET, small and quiet — the speech is the star
	var plate_name := _make_plate(role.to_upper(), 52,
		Color(1.0, 0.85, 0.35, 0.9) if role == "director" else Color(0.96, 0.96, 0.92, 0.85))
	plate_name.position = Vector3(0, 0.28, 0)
	_plate_state = _make_plate("", 34, Color(0.72, 0.76, 0.72, 0.85))
	_plate_state.position = Vector3(0, 0.08, 0)
	_plate_state.visible = false

	_bubble_timer = Timer.new()
	_bubble_timer.one_shot = true
	_bubble_timer.timeout.connect(func() -> void: _bubble.visible = false)
	add_child(_bubble_timer)

	_wander_timer = Timer.new()
	_wander_timer.one_shot = true
	_wander_timer.timeout.connect(_wander)
	add_child(_wander_timer)
	_restart_wander()

	# typing foley while working (Unpacking rule: variants + jitter)
	_type_timer = Timer.new()
	_type_timer.one_shot = true
	_type_timer.timeout.connect(func() -> void:
		if state == State.WORKING:
			Sfx.play_at(self, "key", -10.0, 0.14)
			_type_timer.start(randf_range(0.10, 0.38)))
	add_child(_type_timer)

	EventBus.stage_started.connect(_on_stage_started)
	EventBus.stage_completed.connect(_on_stage_completed)
	EventBus.meeting_called.connect(func(_req: Dictionary) -> void:
		if state == State.WORKING or _target_is_work:
			return
		_meeting = true
		_celebrating = false
		_break_ad = {}
		_wander_timer.stop()
		walk_to(MEETING_SPOTS.get(role, Vector2i(3, 3))))
	EventBus.agent_say.connect(func(r: String, text: String) -> void:
		if r == role:
			_say(text))


func _process(delta: float) -> void:
	# needs decay: working drains energy, everything drifts slowly down
	var drain := 0.006 if state == State.WORKING else 0.0035
	needs["energy"] = clampf(needs["energy"] - drain * delta * 4.0, 0.0, 1.0)
	needs["social"] = clampf(needs["social"] - 0.0030 * delta * 4.0, 0.0, 1.0)
	needs["inspiration"] = clampf(needs["inspiration"] - 0.0026 * delta * 4.0, 0.0, 1.0)
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
		# footsteps: one tap per stride, sound picked by floor material
		_step_accum += step
		if _step_accum >= 0.55:
			_step_accum = 0.0
			Sfx.play_at(self, _floor_step_group(), -14.0, 0.10)


func _floor_step_group() -> String:
	if office == null:
		return "step_hard"
	var row := str(office.map_rows[grid_pos.y])
	match row[grid_pos.x]:
		"r", "g":
			return "step_soft"
		"#", "P":
			return "step_wood"
		_:
			return "step_hard"


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
	if _meeting:
		_meeting = false
		_set_state(State.IDLE)
		_play("Idle")
		# face the meeting table
		var to_table := office.grid_to_world(Vector2i(3, 1)) + Vector3(0.5, 0, 1.0) - position
		_target_yaw = atan2(to_table.x, to_table.z)
		_wander_timer.start(randf_range(9.0, 13.0))
		return
	if _celebrating:
		_celebrating = false
		_set_state(State.IDLE)
		_target_yaw = -PI / 2.0  # face the stage (west)
		_play_once_then_idle("Cheer")
		_wander_timer.start(randf_range(8.0, 12.0))
		return
	if _target_is_work:
		_set_state(State.WORKING)
		_play(str(WORK_ANIM.get(role, "Interact")))
		# face the desk (north) while working
		_target_yaw = PI
		Sfx.play_at(self, "chair", -10.0)
		_drop_doc()
		_type_timer.start(randf_range(0.3, 0.8))
		EventBus.agent_arrived.emit(role)
	elif not _break_ad.is_empty():
		# arrived at a smart object: linger, restore the need, remember
		_set_state(State.IDLE)
		_play("Idle")
		var ad := _break_ad
		_break_ad = {}
		_think(I18n.t(str(ad["line"])))
		var need: String = str(ad["need"])
		current_task = "break (%s)" % need
		get_tree().create_timer(randf_range(5.0, 8.0)).timeout.connect(func() -> void:
			needs[need] = clampf(needs[need] + float(ad["amount"]), 0.0, 1.0)
			if randf() < 0.3:
				Memory.remember(role, I18n.f("mem_break", [need]), 2.0)
			if current_task.begins_with("break"):
				current_task = "available"
			_restart_wander())
	else:
		_set_state(State.IDLE)
		_play("Idle")
		_restart_wander()


func _on_stage_started(stage: String, r: String, _request: Dictionary) -> void:
	if r != role:
		return
	_target_is_work = true
	_wander_timer.stop()
	current_task = "%s — '%s'" % [stage, str(_request.get("topic", "")).left(22)]
	_pop_fx("!", Color(1.0, 0.78, 0.3))
	var say_key := "say_" + stage
	_think(I18n.t(say_key) if I18n.S.has(say_key) else I18n.t("say_onit"))
	_carry_doc()
	walk_to(office.workstation(role))


## The handoff made visible: a document carried in front of the chest
## while walking to the desk (MetaGPT artifacts as theater).
func _carry_doc() -> void:
	_drop_doc()
	_doc = Node3D.new()
	_doc.position = Vector3(0.0, 0.78, 0.22)
	add_child(_doc)
	var page := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.20, 0.025, 0.27)
	page.mesh = pm
	page.material_override = _paper_mat()
	page.rotation_degrees = Vector3(24, 0, 0)
	_doc.add_child(page)
	var clip := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.20, 0.028, 0.05)
	clip.mesh = cm
	clip.material_override = _chip_mat()
	clip.position = Vector3(0, 0.004, -0.11)
	clip.rotation_degrees = Vector3(24, 0, 0)
	_doc.add_child(clip)
	Juice.pop_in(_doc)
	Sfx.play_at(self, "paper", -8.0)


func _drop_doc() -> void:
	if _doc:
		_doc.queue_free()
		_doc = null


func _paper_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.91, 0.87)
	m.roughness = 0.75
	return m


func _chip_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Office3D.ROLE_ACCENT.get(role, Color(0.6, 0.6, 0.6))
	m.roughness = 0.5
	return m


func _on_stage_completed(_stage: String, r: String, _request: Dictionary, result: String) -> void:
	if r != role:
		return
	_target_is_work = false
	_set_state(State.IDLE)
	_type_timer.stop()
	current_task = "available"
	if result.begins_with("(stage"):
		_pop_fx("x", Color(1.0, 0.42, 0.42))
		_think(I18n.t("say_fail"))
		_play("Idle")
	else:
		_pop_fx("+", Color(0.45, 1.0, 0.55))
		# the work itself surfaces as a THOUGHT (rereading your own line)
		var excerpt := I18n.strip_md(result).replace("\n", " ").left(46)
		_think("“%s…”" % excerpt)
		# permanence: the finished page stays on the desk
		if office:
			office.add_desk_paper(role)
		Sfx.play_at(self, "paper", -10.0)
		_play_once_then_idle("Cheer")
	_restart_wander()


## Walk to a town-hall spot and cheer (all-hands gathering).
func celebrate_at(cell: Vector2i) -> void:
	if _target_is_work or state == State.WORKING:
		return
	_celebrating = true
	_wander_timer.stop()
	_say([I18n.t("say_celebrate_1"), I18n.t("say_celebrate_2"),
		I18n.t("say_celebrate_3")].pick_random())
	walk_to(cell)


func _wander() -> void:
	if state != State.IDLE or _target_is_work:
		_restart_wander()
		return
	# 1) social opportunity: gossip with a nearby idle colleague
	if _try_gossip():
		_restart_wander()
		return
	# 2) personal space: if someone's standing on top of us, step away
	if _too_crowded():
		walk_to(_free_spot())
		return
	# 3) needs-driven: score smart-object ads (Sims-style, local + free)
	var w: Dictionary = NEED_WEIGHT.get(role, {})
	var best: Dictionary = {}
	var best_score := 0.0
	for ad in Office3D.SMART_OBJECTS:
		var need: String = str(ad["need"])
		if need == "energy" and Storyteller.espresso_down:
			continue  # the machine is broken — drama by subtraction
		if _spot_taken(office.grid_to_world(ad["cell"])):
			continue  # someone's already using that object
		var deficit: float = (1.0 - float(needs[need])) * float(w.get(need, 1.0))
		if deficit < 0.45:
			continue
		var dist := float((ad["cell"] as Vector2i - grid_pos).length())
		var score: float = deficit * float(ad["amount"]) / (1.0 + dist * 0.04)
		if score > best_score:
			best_score = score
			best = ad
	if not best.is_empty() and not office.is_blocked(best["cell"]):
		_break_ad = best
		walk_to(best["cell"])
		return
	# 4) otherwise: a stroll to somewhere with breathing room
	walk_to(_free_spot())
	_restart_wander()


## Is another agent already at (or heading to) this world position?
func _spot_taken(world_pos: Vector3) -> bool:
	for other in get_tree().get_nodes_in_group("agents"):
		if other == self:
			continue
		var o := other as TownAgent3D
		if o == null:
			continue
		if o.position.distance_to(world_pos) < 0.9:
			return true
		if not o._waypoints.is_empty() and o._waypoints[-1].distance_to(world_pos) < 0.9:
			return true
	return false


func _too_crowded() -> bool:
	for other in get_tree().get_nodes_in_group("agents"):
		if other == self:
			continue
		var o := other as TownAgent3D
		if o and o.state != State.WALKING and position.distance_to(o.position) < 0.85:
			return true
	return false


## A random walkable cell with breathing room from everyone else.
func _free_spot() -> Vector2i:
	for _i in 10:
		var g := office.random_walkable()
		if not _spot_taken(office.grid_to_world(g)):
			return g
	return office.random_walkable()


## Water-cooler gossip: two idle agents near each other trade their top
## memories — the listener REMEMBERS it (information diffusion), and the
## pair warms up. Global cooldown prevents greeting loops (a16z AI Town).
func _try_gossip() -> bool:
	var now := Time.get_unix_time_from_system()
	if now - Memory.last_gossip_at < 90.0:
		return false
	for other in get_tree().get_nodes_in_group("agents"):
		if other == self:
			continue
		var o := other as TownAgent3D
		if o == null or o.state != State.IDLE or o._target_is_work:
			continue
		if position.distance_to(o.position) > 3.2:
			continue
		Memory.last_gossip_at = now
		var to_o := o.position - position
		_target_yaw = atan2(to_o.x, to_o.z)
		o._target_yaw = atan2(-to_o.x, -to_o.z)
		_gossip_with(o)
		return true
	return false


static var _llm_gossips := 0


## The exchange itself: Claude writes a natural multi-turn beat when
## the provider is live — personas + relationship + real memories in,
## colloquial lines out, played with breathing room. Casual smalltalk
## pool as fallback.
func _gossip_with(o: TownAgent3D) -> void:
	var lines: Array = []
	if Config.provider_resolved != "simulate" and _llm_gossips < 24 and randf() < 0.75:
		_llm_gossips += 1
		_think("…")
		var aff := Memory.get_affinity(role, o.role)
		var vibe := "close friends" if aff >= 0.65 else ("a bit tense lately" if aff <= 0.35 else "friendly colleagues")
		var mine := Memory.recall(role, "", 2)
		var theirs := Memory.recall(o.role, "", 2)
		var ctx := "A is %s\nB is %s\nThey are %s.\n" % [
			PERSONA[role], PERSONA[o.role], vibe]
		ctx += "A remembers: "
		for m in mine:
			ctx += str(m["text"]) + " / "
		ctx += "\nB remembers: "
		for m in theirs:
			ctx += str(m["text"]) + " / "
		var sys := ("Write a NATURAL watercooler beat between two coworkers at a Thai " +
			"short-video studio. 3 or 4 alternating lines starting with A:, then B:. " +
			"Colloquial and specific — react to each other, tease, trail off; never " +
			"recite the memory text verbatim, just let it color the chat. " +
			"Each line under 55 characters. %s") % I18n.t("lang_directive")
		var out: String = await Claude.complete(sys, ctx, "gossip")
		for line in out.split("\n", false):
			var s := line.strip_edges()
			if s.begins_with("A:"):
				lines.append([self, s.substr(2).strip_edges()])
			elif s.begins_with("B:"):
				lines.append([o, s.substr(2).strip_edges()])
	if lines.size() < 2:
		# fallback: casual smalltalk, never recited memories
		var pick := randi_range(1, 4)
		var a := I18n.t("small_%da" % pick)
		if a.contains("%s"):
			a = a % Config.owner_name
		lines = [[self, a], [o, I18n.t("small_%db" % pick)]]
	# play the beat with natural pauses
	var delay := 0.0
	for l in lines:
		var who: TownAgent3D = l[0]
		var text: String = l[1]
		if delay == 0.0:
			who._say(text)
		else:
			get_tree().create_timer(delay).timeout.connect(func() -> void:
				if is_instance_valid(who):
					who._say(text))
		delay += randf_range(1.7, 2.4)
	# what B heard from A colors B's memory (information diffusion)
	Memory.remember(o.role, I18n.f("mem_gossip_heard", [role, str(lines[0][1])]), 4.0)
	Memory.remember(role, I18n.f("mem_gossip_chat", [o.role]), 3.0)
	Memory.nudge_affinity(role, o.role, 0.03)
	needs["social"] = clampf(needs["social"] + 0.35, 0.0, 1.0)
	o.needs["social"] = clampf(o.needs["social"] + 0.35, 0.0, 1.0)


# ------------------------------------------------------------ the owner
# (docs/CREATIVE_DIRECTION.md pillar 6: the human is a character)

## Black & White's law: feedback lands on the most recent action, and
## being taught is REMEMBERED.
func praised() -> void:
	var last := Memory.recall(role, "", 1)
	var about := "" if last.is_empty() else I18n.f("mem_praise_about", [str(last[0]["text"]).left(50)])
	Memory.remember(role, I18n.f("mem_praised", [Config.owner_name, about]), 7.0)
	Memory.nudge_affinity(role, "owner", 0.06)
	needs["social"] = clampf(needs["social"] + 0.3, 0.0, 1.0)
	needs["inspiration"] = clampf(needs["inspiration"] + 0.2, 0.0, 1.0)
	_pop_fx("♥", Color(1.0, 0.55, 0.6))
	_say(I18n.f("say_thanks", [Config.owner_name]))
	if state == State.IDLE:
		_play_once_then_idle("Cheer")


func coached(note: String) -> void:
	Memory.remember(role, I18n.f("mem_coached", [Config.owner_name, note]), 8.0)
	Memory.nudge_affinity(role, "owner", 0.03)
	_pop_fx("!", Color(1.0, 0.78, 0.3))
	_say(I18n.f("say_noted", [Config.owner_name]))


## Click-to-chat: an in-character reply built from real memories —
## and the agent TELLS APART casual talk from a work order. A clear
## commission becomes a queued job (routed through the Director's
## desk); chitchat stays chitchat.
func chat_reply(msg: String) -> void:
	Memory.remember(role, I18n.f("mem_owner_said", [Config.owner_name, msg.left(90)]), 5.0)
	if Config.provider_resolved == "simulate":
		_say(I18n.f("say_chat_sim", [Config.owner_name]))
		return
	_think("…")
	var sys := ("You are %s at Agent Town, a small Thai short-video studio. " +
		"Reply to your boss %s IN CHARACTER, one or two short sentences " +
		"(under 140 characters total), warm and specific. %s%s\n\n" +
		"LIVE OFFICE STATUS (answer follow-up questions from THIS, truthfully):\n" +
		TaskQueue.status_text() + "\n\n" +
		"INTENT RULE: only if the boss is CLEARLY commissioning new content " +
		"(e.g. 'ทำรีลเรื่อง...', 'อยากได้คลิปเกี่ยวกับ...', 'make a reel about...') " +
		"add a FINAL line exactly: IDEA: <short topic>. Questions, opinions, " +
		"praise and smalltalk are NOT commissions — then add no IDEA line. " +
		"When you do accept a job, your reply must acknowledge queuing it.") % [
		PERSONA[role], Config.owner_name, I18n.t("lang_directive"), Memory.context_for(role, msg)]
	var out: String = await Claude.complete(sys, msg, "chat")
	if out.is_empty():
		out = I18n.f("say_lost", [Config.owner_name])
	# split off the intent line before showing the reply
	var idea := ""
	var reply_lines: Array[String] = []
	for line in out.split("\n", false):
		if line.strip_edges().begins_with("IDEA:"):
			idea = line.strip_edges().substr(5).strip_edges()
		else:
			reply_lines.append(line)
	_say("\n".join(reply_lines).strip_edges().left(170))
	Memory.remember(role, I18n.f("mem_i_told", [Config.owner_name, out.left(90)]), 4.0)
	if not idea.is_empty():
		_queue_idea(idea)


## A commission heard in chat becomes a real queued request.
func _queue_idea(topic: String) -> void:
	var path := "res://queue/pending/chat_%d.json" % int(Time.get_unix_time_from_system())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"topic": topic,
			"notes": "Commissioned by %s in a chat with the %s." % [Config.owner_name, role],
		}, "  "))
		EventBus.log_line.emit("📌 Commissioned in chat: %s" % topic.left(48))
		Sfx.play_at(self, "paper", -8.0)
		Memory.remember(role, I18n.f("mem_owner_said", [Config.owner_name, topic]), 6.0)


func _restart_wander() -> void:
	_wander_timer.start(randf_range(4.0, 10.0))


## SPEECH: addressed to someone (a colleague, the team, the owner).
## Carries polite particles in Thai, enters the office chat feed.
func _say(text: String) -> void:
	_bubble.modulate = Color(1.0, 0.99, 0.92)
	_bubble.font_size = 66
	if text != "...":
		EventBus.chat_line.emit(role, text)
	_show_bubble(text)


## THOUGHT: inner voice — no addressee, so no polite particles (Thai
## ครับ/ค่ะ mark deference to a LISTENER), never "exclaimed", and it
## does NOT enter the chat feed. Dimmer cloud-toned bubble with 💭.
func _think(text: String) -> void:
	_bubble.modulate = Color(0.80, 0.82, 0.96, 0.95)
	_bubble.font_size = 56
	_show_bubble("💭 " + text)


func _show_bubble(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	# springy scale-in (reset first so overlapping pops never shrink it)
	_bubble.scale = Vector3.ONE
	Juice.pop_in(_bubble, 0.28)
	_bubble_timer.start(4.5)


func _set_state(s: State) -> void:
	state = s
	if _plate_state:
		var style: Array = STATE_STYLE[s]
		_plate_state.text = style[0]
		_plate_state.modulate = style[1]
		# idle agents show only their name — less floating text to parse
		_plate_state.visible = str(style[0]) != "IDLE"


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
	l.font = I18n.ui_font
	l.text = text
	l.font_size = size
	l.outline_size = size / 3
	l.pixel_size = 0.0042
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_modulate = Color(0.08, 0.08, 0.10)
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


# ------------------------------------------------------------ costumes

func apply_costume(c: Dictionary) -> void:
	var need_reload := str(c.get("class", "")) != str(costume.get("class", ""))
	costume = c.duplicate(true)
	if need_reload:
		if _model:
			_model.queue_free()
		_anim = null
		_model = _load_character(str(costume["class"]))
		add_child(_model)
		_setup_attachments()
		_play("Idle")
	_apply_costume_parts()


func _setup_attachments() -> void:
	_skeleton = null
	_attach_head = null
	_attach_r = null
	_attach_l = null
	_attach_arm_l = null
	_attach_arm_r = null
	var sk := _model.find_children("*", "Skeleton3D", true, false)
	if sk.is_empty():
		return
	_skeleton = sk[0]
	_attach_head = _bone_attach("head")
	_attach_r = _bone_attach("handslot.r")
	_attach_l = _bone_attach("handslot.l")
	_attach_arm_l = _bone_attach("lowerarm.l")
	_attach_arm_r = _bone_attach("lowerarm.r")


func _bone_attach(bone: String) -> BoneAttachment3D:
	var idx := _skeleton.find_bone(bone)
	if idx < 0:
		return null
	var ba := BoneAttachment3D.new()
	_skeleton.add_child(ba)
	ba.bone_idx = idx
	return ba


func _apply_costume_parts() -> void:
	# 1. built-in mesh parts (weapons off; helmet/hood/cape per costume)
	var headgear := str(costume.get("headgear", "class"))
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var n := str(mi.name).to_lower()
		if n.begins_with("1h") or n.begins_with("2h") or n.contains("shield") or n.contains("sword"):
			mi.visible = false
		elif n.contains("helmet") or n.contains("hat") or n.contains("hood"):
			mi.visible = headgear == "class"
		elif n.contains("cape"):
			mi.visible = bool(costume.get("cape", false))
	# 2. procedural headgear
	_clear_attach(_attach_head)
	if headgear != "class" and headgear != "none" and _attach_head:
		_build_headgear(headgear, _attach_head)
	# 3. hand items
	_clear_attach(_attach_r)
	_clear_attach(_attach_l)
	_equip_item(str(costume.get("right", "none")), _attach_r)
	_equip_item(str(costume.get("left", "none")), _attach_l)
	# 4. bracers
	_clear_attach(_attach_arm_l)
	_clear_attach(_attach_arm_r)
	if bool(costume.get("bracers", false)):
		for arm in [_attach_arm_l, _attach_arm_r]:
			if arm:
				var b := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.09
				cyl.bottom_radius = 0.1
				cyl.height = 0.22
				b.mesh = cyl
				var bm := StandardMaterial3D.new()
				bm.albedo_color = Color(0.45, 0.42, 0.4)
				b.material_override = bm
				b.position = Vector3(0, 0.12, 0)
				arm.add_child(b)


func _clear_attach(ba: BoneAttachment3D) -> void:
	if ba == null:
		return
	for child in ba.get_children():
		child.queue_free()


func _equip_item(item: String, ba: BoneAttachment3D) -> void:
	if ba == null or item == "none" or item.is_empty():
		return
	var path := "res://assets/models/items/%s.gltf" % item
	if not FileAccess.file_exists(path):
		return
	if not _item_cache.has(item):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(path, st) != OK:
			return
		_item_cache[item] = [doc, st]
	var pair: Array = _item_cache[item]
	var node := pair[0].generate_scene(pair[1]) as Node3D
	ba.add_child(node)


func _build_headgear(kind: String, parent: Node3D) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	match kind:
		"cap":
			_gear_sphere(root, Vector3(0, 0.20, -0.02), Vector3(0.30, 0.20, 0.30), Color(0.36, 0.48, 0.72))
			_gear_box(root, Vector3(0, 0.14, 0.26), Vector3(0.30, 0.04, 0.26), Color(0.36, 0.48, 0.72))
		"headset":
			var band := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.26
			t.outer_radius = 0.30
			band.mesh = t
			band.material_override = _gear_mat(Color(0.22, 0.22, 0.26))
			band.rotation_degrees = Vector3(0, 0, 90)
			band.position = Vector3(0, 0.12, 0)
			root.add_child(band)
			_gear_box(root, Vector3(-0.29, 0.05, 0), Vector3(0.07, 0.16, 0.16), Color(0.22, 0.22, 0.26))
			_gear_box(root, Vector3(0.29, 0.05, 0), Vector3(0.07, 0.16, 0.16), Color(0.22, 0.22, 0.26))
			_gear_box(root, Vector3(-0.24, -0.06, 0.20), Vector3(0.04, 0.04, 0.22), Color(0.22, 0.22, 0.26))
			_gear_box(root, Vector3(-0.2, -0.1, 0.32), Vector3(0.06, 0.06, 0.06), Color(0.95, 0.45, 0.33))
		"glasses":
			for gx in [-0.12, 0.12]:
				var lens := MeshInstance3D.new()
				var lt := TorusMesh.new()
				lt.inner_radius = 0.07
				lt.outer_radius = 0.10
				lens.mesh = lt
				lens.material_override = _gear_mat(Color(0.2, 0.2, 0.24))
				lens.rotation_degrees = Vector3(90, 0, 0)
				lens.position = Vector3(gx, 0.05, 0.27)
				root.add_child(lens)
			_gear_box(root, Vector3(0, 0.05, 0.27), Vector3(0.08, 0.02, 0.02), Color(0.2, 0.2, 0.24))
		"party_hat":
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.15
			cm.height = 0.36
			cone.mesh = cm
			cone.material_override = _gear_mat(Color(0.95, 0.45, 0.33))
			cone.position = Vector3(0, 0.36, 0)
			root.add_child(cone)
		"crown":
			var ring := MeshInstance3D.new()
			var rc := CylinderMesh.new()
			rc.top_radius = 0.22
			rc.bottom_radius = 0.24
			rc.height = 0.12
			ring.mesh = rc
			ring.material_override = _gear_mat(Color(0.95, 0.78, 0.3))
			ring.position = Vector3(0, 0.26, 0)
			root.add_child(ring)
			for i in 4:
				var ang := i * TAU / 4.0
				_gear_box(root, Vector3(cos(ang) * 0.21, 0.36, sin(ang) * 0.21), Vector3(0.05, 0.1, 0.05), Color(0.95, 0.78, 0.3))


func _gear_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	return m


func _gear_box(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	b.mesh = bm
	b.material_override = _gear_mat(col)
	b.position = pos
	parent.add_child(b)


func _gear_sphere(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var sph := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sph.mesh = sm
	sph.scale = size
	sph.material_override = _gear_mat(col)
	sph.position = pos
	parent.add_child(sph)
