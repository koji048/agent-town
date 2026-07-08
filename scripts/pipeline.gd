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
	if request.has("clip"):
		await _run_clip(request)
		return
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
	Memory.remember_all(I18n.f("mem_shipped", [topic]), 8.0)
	for i in Memory.ROLES.size():
		for j in range(i + 1, Memory.ROLES.size()):
			Memory.nudge_affinity(Memory.ROLES[i], Memory.ROLES[j], 0.03)
	EventBus.request_completed.emit(request, out_dir)
	EventBus.log_line.emit("Done: %s -> %s" % [topic, out_dir.get_file()])


## THE CLIP WORKFLOW (one door: talk to the Director — or AirDrop into
## inbox/ and the Director routes it): Director plans, Editor runs REAL
## Whisper transcription + caption cleanup, owner approves at the desk,
## Publisher packages titles/hashtags, SRT ships EP-numbered.
func _run_clip(request: Dictionary) -> void:
	results = {}
	var topic := str(request.get("topic", "clip"))
	var clip := str(request.get("clip", ""))
	var lang := str(request.get("language", Config.language))
	var niche := str(request.get("niche", Config.niche))

	# 1) the Director routes the footage
	await _walk_stage("plan", "director", request)
	var brief := ("Footage from %s: %s\nRouting: transcribe in the edit bay, " +
		"clean captions to house rules, owner approval, EP-numbered export.") % [
		Config.owner_name, clip.get_file()]
	results["plan"] = brief
	Memory.remember("director", I18n.f("mem_clip_routed", [Config.owner_name, clip.get_file()]), 6.0)
	EventBus.stage_completed.emit("plan", "director", request, brief)

	# 2) the Editor transcribes for real
	await _walk_stage("edit", "editor", request)
	EventBus.log_line.emit("🎙 Transcribing %s (Whisper large-v3-turbo)..." % clip.get_file())
	Transcriber.transcribe(clip)
	var r: Array = await Transcriber.done
	var raw_srt: String = r[0]
	if not bool(r[1]):
		results["edit"] = "(transcription failed — see whisper install)"
		EventBus.stage_completed.emit("edit", "editor", request, results["edit"])
	else:
		results["script"] = raw_srt
		var cleaned := raw_srt
		if Config.provider_resolved != "simulate":
			var c: String = await Claude.complete(
				Prompts.editor(lang, niche) + Memory.context_for("editor", topic),
				("Raw Whisper SRT of the owner's real clip. Re-cut into caption-capped " +
				"SRT per your rules — keep the timing, fix obvious mishearings:\n\n") +
				raw_srt.left(6000), "edit")
			if not c.is_empty():
				cleaned = c
		results["edit"] = cleaned
		Memory.remember("editor", I18n.f("mem_clip_edited", [Config.owner_name, clip.get_file()]), 7.0)
		EventBus.stage_completed.emit("edit", "editor", request, cleaned)

		# 3) the approval desk (one revision pass when live)
		if not await _await_approval(request, cleaned):
			if Config.provider_resolved != "simulate":
				EventBus.log_line.emit("✍ Caption revision — the Editor tightens the cut.")
				await _walk_stage("edit", "editor", request)
				var c2: String = await Claude.complete(
					Prompts.editor(lang, niche),
					"REVIEWER FEEDBACK: tighten further, shorter captions, punchier. Revise:\n\n" +
					cleaned.left(6000), "edit")
				if not c2.is_empty():
					results["edit"] = c2
				EventBus.stage_completed.emit("edit", "editor", request, str(results["edit"]))

		# 4) the Publisher packages it (live only)
		if Config.provider_resolved != "simulate":
			await _stage("publish", "publisher", request,
				Prompts.publisher(lang, niche),
				"Transcript of the owner's real clip:\n%s" % raw_srt.left(4000))

	results["review"] = "Cleared for export by %s's desk." % Config.owner_name
	var out_dir: String = OutputWriter.write_package(request, results)
	var done_dest := clip.get_base_dir().path_join("done").path_join(clip.get_file())
	DirAccess.rename_absolute(clip, done_dest)
	TaskQueue.finish(request)
	EventBus.request_completed.emit(request, out_dir)
	EventBus.log_line.emit("Done: %s -> %s" % [topic, out_dir.get_file()])


## Send the agent to its desk and wait for arrival (listen BEFORE
## emitting: an agent already at its station arrives synchronously).
func _walk_stage(stage: String, role: String, request: Dictionary) -> void:
	var arrived := [false]
	var cb := func(rr: String) -> void:
		if rr == role:
			arrived[0] = true
	EventBus.agent_arrived.connect(cb)
	EventBus.stage_started.emit(stage, role, request)
	var waited := 0.0
	while not arrived[0] and waited < ARRIVAL_TIMEOUT:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	EventBus.agent_arrived.disconnect(cb)


func _stage(stage: String, role: String, request: Dictionary, system_prompt: String, user_prompt: String) -> String:
	await _walk_stage(stage, role, request)

	# memories + team dynamics color every call (retrieval by topic)
	var topic := str(request.get("topic", ""))
	var out: String = await Claude.complete(
		system_prompt + Memory.context_for(role, topic), user_prompt, stage)
	if out.is_empty():
		# mixed initiative: the agent asks the owner ONE clarifying
		# question, and the typed guidance feeds a single retry
		var guidance := await _ask_owner(role, I18n.f("ask_stuck", [stage, topic]))
		var retry_prompt := user_prompt
		if not guidance.is_empty():
			retry_prompt += "\n\nGUIDANCE FROM %s: %s" % [Config.owner_name.to_upper(), guidance]
			Memory.remember(role, I18n.f("mem_guided", [Config.owner_name, stage, guidance.left(60)]), 8.0)
			Memory.nudge_affinity(role, "owner", 0.06)
		out = await Claude.complete(
			system_prompt + Memory.context_for(role, topic), retry_prompt, stage)
	if out.is_empty():
		out = "(stage '%s' produced no output — check the log)" % stage
	if out.begins_with("(stage"):
		Memory.remember(role, I18n.f("mem_stage_fail", [stage, topic]), 7.0)
		Memory.nudge_affinity(role, "director", -0.04)
	else:
		Memory.remember(role, I18n.f("mem_stage_done", [stage, topic]), 6.0)
	results[stage] = out
	EventBus.stage_completed.emit(stage, role, request, out)
	return out


## Pose one clarifying question to the owner; 40 s of silence = "".
func _ask_owner(role: String, question: String) -> String:
	var answer := [false, ""]
	var cb := func(text: String) -> void:
		answer[0] = true
		answer[1] = text
	EventBus.guidance_given.connect(cb)
	EventBus.agent_question.emit(role, question)
	var waited := 0.0
	while not answer[0] and waited < 40.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	EventBus.guidance_given.disconnect(cb)
	return str(answer[1])


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
	elif decided[1]:
		# presence: the approval is remembered as coming from a PERSON
		var topic := str(request.get("topic", "")).left(40)
		Memory.remember("writer", I18n.f("mem_approved", [Config.owner_name, topic]), 7.0)
		Memory.nudge_affinity("writer", "owner", 0.05)
	else:
		var topic2 := str(request.get("topic", "")).left(40)
		Memory.remember("writer", I18n.f("mem_rejected", [Config.owner_name, topic2]), 7.0)
		Memory.nudge_affinity("writer", "owner", -0.02)
	return decided[1]


func _describe(request: Dictionary) -> String:
	var lines: Array[String] = []
	for key in ["topic", "audience", "duration_sec", "platform", "notes", "language", "niche"]:
		if request.has(key):
			lines.append("%s: %s" % [key, str(request[key])])
	return "\n".join(lines)
