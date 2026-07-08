## The orchestration heart of Agent Town.
## The Director receives a request, plans it, then cascades work through
## Researcher -> Scriptwriter -> Editor -> Publisher and finally reviews
## the result. Each stage waits for the agent to physically reach its
## workstation before the LLM call fires.
class_name Pipeline
extends Node

const ARRIVAL_TIMEOUT := 15.0

var results: Dictionary = {}


func _ready() -> void:
	EventBus.request_received.connect(_on_request)


func _on_request(request: Dictionary) -> void:
	_run(request)


func _run(request: Dictionary) -> void:
	results = {}
	var topic := str(request.get("topic", "untitled"))
	var lang := str(request.get("language", Config.language))
	var niche := str(request.get("niche", Config.niche))
	var brief := _describe(request)

	var plan := await _stage("plan", "director", request,
		Prompts.director_plan(lang, niche),
		"Content request:\n%s" % brief)

	var research := await _stage("research", "researcher", request,
		Prompts.researcher(lang, niche),
		"Request:\n%s\n\nDirector's brief:\n%s" % [brief, plan])

	var script := await _stage("script", "writer", request,
		Prompts.scriptwriter(lang, niche),
		"Request:\n%s\n\nDirector's brief:\n%s\n\nResearch notes:\n%s" % [brief, plan, research])

	var captions := await _stage("edit", "editor", request,
		Prompts.editor(lang, niche),
		"Script:\n%s" % script)

	# ---- the approval desk: work WAITS for the human at a designed
	# checkpoint (Devin's lesson: the cheapest intervention is a gate,
	# not a popup). Auto-approves after a timeout so ambient mode lives.
	if not await _await_approval(request, script):
		EventBus.log_line.emit("✍ Revision requested — the Writer takes another pass.")
		Memory.remember("writer", "The reviewer sent my script for '%s' back. Round two." % topic, 7.0)
		Memory.nudge_affinity("writer", "director", -0.03)
		script = await _stage("script", "writer", request,
			Prompts.scriptwriter(lang, niche),
			"Request:\n%s\n\nDirector's brief:\n%s\n\nResearch notes:\n%s\n\nREVIEWER FEEDBACK: tighten the hook, cut anything slow, keep it punchy. Revise the script." % [brief, plan, research])
		captions = await _stage("edit", "editor", request,
			Prompts.editor(lang, niche),
			"Script:\n%s" % script)

	var publish := await _stage("publish", "publisher", request,
		Prompts.publisher(lang, niche),
		"Script:\n%s\n\nResearch notes:\n%s" % [script, research])

	await _stage("review", "director", request,
		Prompts.director_review(lang, niche),
		"Research:\n%s\n\nScript:\n%s\n\nCaptions:\n%s\n\nPublish plan:\n%s" % [research, script, captions, publish])

	var out_dir: String = OutputWriter.write_package(request, results)
	TaskQueue.finish(request)
	# the whole crew remembers shipping this one (Smallville: shared
	# events become each agent's own memory), and bonds strengthen
	Memory.remember_all("We shipped the reel '%s' and celebrated in the garden." % topic, 8.0)
	for i in Memory.ROLES.size():
		for j in range(i + 1, Memory.ROLES.size()):
			Memory.nudge_affinity(Memory.ROLES[i], Memory.ROLES[j], 0.03)
	EventBus.request_completed.emit(request, out_dir)
	EventBus.log_line.emit("Done: %s -> %s" % [topic, out_dir.get_file()])


func _stage(stage: String, role: String, request: Dictionary, system_prompt: String, user_prompt: String) -> String:
	# Listen BEFORE emitting: an agent already standing at its workstation
	# emits agent_arrived synchronously during stage_started.
	var arrived := [false]
	var cb := func(r: String) -> void:
		if r == role:
			arrived[0] = true
	EventBus.agent_arrived.connect(cb)
	EventBus.stage_started.emit(stage, role, request)
	var waited := 0.0
	while not arrived[0] and waited < ARRIVAL_TIMEOUT:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	EventBus.agent_arrived.disconnect(cb)

	# memories + team dynamics color every call (retrieval by topic)
	var topic := str(request.get("topic", ""))
	var out: String = await Claude.complete(
		system_prompt + Memory.context_for(role, topic), user_prompt, stage)
	if out.is_empty():
		out = "(stage '%s' produced no output — check the log)" % stage
	if out.begins_with("(stage"):
		Memory.remember(role, "My %s stage failed on '%s'. Frustrating." % [stage, topic], 7.0)
		Memory.nudge_affinity(role, "director", -0.04)
	else:
		Memory.remember(role, "I finished the %s stage for '%s'." % [stage, topic], 6.0)
	results[stage] = out
	EventBus.stage_completed.emit(stage, role, request, out)
	return out


## Wait at the approval desk: Y approves, N requests one revision,
## silence auto-approves after 45 s. Returns true when approved.
func _await_approval(request: Dictionary, preview: String) -> bool:
	var decided := [false, true]
	var cb := func(approved: bool) -> void:
		decided[0] = true
		decided[1] = approved
	EventBus.approval_resolved.connect(cb)
	EventBus.approval_requested.emit(request, preview)
	var waited := 0.0
	while not decided[0] and waited < 45.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	EventBus.approval_resolved.disconnect(cb)
	if not decided[0]:
		EventBus.log_line.emit("⏱ Auto-approved (no reviewer at the desk).")
	return decided[1]


func _describe(request: Dictionary) -> String:
	var lines: Array[String] = []
	for key in ["topic", "audience", "duration_sec", "platform", "notes", "language", "niche"]:
		if request.has(key):
			lines.append("%s: %s" % [key, str(request[key])])
	return "\n".join(lines)
