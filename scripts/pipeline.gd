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

	var publish := await _stage("publish", "publisher", request,
		Prompts.publisher(lang, niche),
		"Script:\n%s\n\nResearch notes:\n%s" % [script, research])

	await _stage("review", "director", request,
		Prompts.director_review(lang, niche),
		"Research:\n%s\n\nScript:\n%s\n\nCaptions:\n%s\n\nPublish plan:\n%s" % [research, script, captions, publish])

	var out_dir: String = OutputWriter.write_package(request, results)
	TaskQueue.finish(request)
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

	var out: String = await Claude.complete(system_prompt, user_prompt, stage)
	if out.is_empty():
		out = "(stage '%s' produced no output — check the log)" % stage
	results[stage] = out
	EventBus.stage_completed.emit(stage, role, request, out)
	return out


func _describe(request: Dictionary) -> String:
	var lines: Array[String] = []
	for key in ["topic", "audience", "duration_sec", "platform", "notes", "language", "niche"]:
		if request.has(key):
			lines.append("%s: %s" % [key, str(request[key])])
	return "\n".join(lines)
