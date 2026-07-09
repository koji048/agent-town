## The orchestration heart of Agent Town.
## The Director receives a request, plans it, then cascades work through
## Researcher -> Scriptwriter -> Editor -> Publisher and finally reviews
## the result. Each stage waits for the agent to physically reach its
## workstation before the LLM call fires.
class_name Pipeline
extends Node

const ARRIVAL_TIMEOUT := 15.0


func _ready() -> void:
	EventBus.request_received.connect(_on_request)


func _on_request(request: Dictionary) -> void:
	_run(request)


func _run(request: Dictionary) -> void:
	# kickoff huddle first (per the owner): the Director gathers the
	# crew at the meeting nook before anyone touches the work
	EventBus.meeting_called.emit(request)
	EventBus.agent_say.emit("director",
		I18n.f("say_meeting", [str(request.get("topic", "")).left(36)]))
	await get_tree().create_timer(8.0).timeout
	if request.has("clip"):
		await _run_clip(request)
		return
	var results: Dictionary = {}
	var topic := str(request.get("topic", "untitled"))
	var lang := str(request.get("language", Config.language))
	var niche := str(request.get("niche", Config.niche))
	var brief := _describe(request)

	var plan := await _stage("plan", "director", request,
		Prompts.director_plan(lang, niche),
		"Content request:\n%s" % brief, results)
	if TaskQueue.take_cancel(request):
		_cancel_job(request)
		return

	var research := await _stage("research", "researcher", request,
		Prompts.researcher(lang, niche),
		"Request:\n%s\n\nDirector's brief:\n%s" % [brief, plan], results)
	if TaskQueue.take_cancel(request):
		_cancel_job(request)
		return

	var script := await _stage("script", "writer", request,
		Prompts.scriptwriter(lang, niche),
		"Request:\n%s\n\nDirector's brief:\n%s\n\nResearch notes:\n%s" % [brief, plan, research], results)
	if TaskQueue.take_cancel(request):
		_cancel_job(request)
		return

	var captions := await _stage("edit", "editor", request,
		Prompts.editor(lang, niche),
		"Script:\n%s" % script, results)
	if TaskQueue.take_cancel(request):
		_cancel_job(request)
		return

	# ---- the approval desk: work WAITS for the human at a designed
	# checkpoint (Devin's lesson: the cheapest intervention is a gate,
	# not a popup). Auto-approves after a timeout so ambient mode lives.
	if not await _await_approval(request, script):
		EventBus.log_line.emit("✍ Revision requested — the Writer takes another pass.")
		Memory.remember("writer", "The reviewer sent my script for '%s' back. Round two." % topic, 7.0)
		Memory.nudge_affinity("writer", "director", -0.03)
		script = await _stage("script", "writer", request,
			Prompts.scriptwriter(lang, niche),
			"Request:\n%s\n\nDirector's brief:\n%s\n\nResearch notes:\n%s\n\nREVIEWER FEEDBACK: tighten the hook, cut anything slow, keep it punchy. Revise the script." % [brief, plan, research], results)
		captions = await _stage("edit", "editor", request,
			Prompts.editor(lang, niche),
			"Script:\n%s" % script, results)

	var publish := await _stage("publish", "publisher", request,
		Prompts.publisher(lang, niche),
		"Script:\n%s\n\nResearch notes:\n%s" % [script, research], results)
	if TaskQueue.take_cancel(request):
		_cancel_job(request)
		return

	await _stage("review", "director", request,
		Prompts.director_review(lang, niche),
		"Research:\n%s\n\nScript:\n%s\n\nCaptions:\n%s\n\nPublish plan:\n%s" % [research, script, captions, publish], results)

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


## THE CLIP WORKFLOW — follows the owner's reels-pipeline skill EXACTLY
## when its scripts are installed: reel.sh ingest (EP auto-number, batch
## folders, footage renamed) -> reel.sh subs (faster-whisper large-v3,
## pythainlp wrapping, glossary) -> Claude review pass written back to
## 05_EXPORTS -> owner approval -> reel.sh burn (9:16 reframe + subs).
## Falls back to the built-in Whisper flow if the skill isn't installed.
func _run_clip(request: Dictionary) -> void:
	if ReelRunner.available():
		await _run_clip_reels(request)
		return
	await _run_clip_legacy(request)


func _run_clip_reels(request: Dictionary) -> void:
	var results: Dictionary = {}
	var topic := str(request.get("topic", "clip"))
	var clip := str(request.get("clip", ""))
	var lang := str(request.get("language", Config.language))
	var niche := str(request.get("niche", Config.niche))

	# 1) Director: reel.sh ingest — EP number, batch folders, renaming
	await _walk_stage("plan", "director", request)
	EventBus.log_line.emit("🎬 reel.sh ingest %s ..." % clip.get_file())
	ReelRunner.run(PackedStringArray(["ingest", clip]))
	var r: Array = await ReelRunner.finished
	var ingest_out := str(r[0])
	if int(r[1]) != 0:
		EventBus.log_line.emit("ingest failed — falling back to built-in flow")
		EventBus.stage_completed.emit("plan", "director", request, "(ingest failed)")
		await _run_clip_legacy(request)
		return
	var batch := ReelRunner.latest_batch()
	var ep_re := RegEx.new()
	ep_re.compile("EP(\\d+)")
	var ep_m := ep_re.search(ingest_out)
	var ep := int(ep_m.get_string(1)) if ep_m else 0
	var brief := "EP%d ingested by the book:\n%s" % [ep, ingest_out.strip_edges().left(400)]
	results["plan"] = brief
	Memory.remember("director", I18n.f("mem_clip_routed", [Config.owner_name, clip.get_file()]), 6.0)
	EventBus.stage_completed.emit("plan", "director", request, brief)

	# 2) Editor: reel.sh subs — the skill's transcription, exactly
	await _walk_stage("edit", "editor", request)
	var slug := _slugify(clip.get_file().get_basename(), ep)
	EventBus.log_line.emit("🎙 reel.sh subs %s (large-v3, Thai word-aware)..." % slug)
	ReelRunner.run(PackedStringArray(["subs", slug, "--prompt", topic]))
	r = await ReelRunner.finished
	var exports := batch.path_join("05_EXPORTS")
	var srt_path := ReelRunner.newest_file(exports, "-clean.srt")
	if int(r[1]) != 0 or srt_path.is_empty():
		results["edit"] = "(reel.sh subs failed)\n" + str(r[0]).right(400)
		EventBus.stage_completed.emit("edit", "editor", request, str(results["edit"]))
	else:
		var srt := FileAccess.get_file_as_string(srt_path)
		results["script"] = srt
		# the skill's mandated Claude REVIEW pass — written back to the
		# same 05_EXPORTS file, so the editor export stays the truth
		var reviewed := srt
		if Config.provider_resolved != "simulate":
			var c: String = await Claude.complete(
				Prompts.editor(lang, niche),
				("Review this cleaned SRT per the reels-pipeline rules: fix " +
				"mis-hears, keep English tech terms as-is, keep ALL timing and " +
				"numbering exactly. Return ONLY the corrected SRT:\n\n") + srt.left(6000),
				"edit")
			if not c.is_empty() and c.contains("-->"):
				reviewed = c.strip_edges() + "\n"
				var wf := FileAccess.open(srt_path, FileAccess.WRITE)
				if wf:
					wf.store_string(reviewed)
		results["edit"] = reviewed
		Memory.remember("editor", I18n.f("mem_clip_edited", [Config.owner_name, clip.get_file()]), 7.0)
		EventBus.stage_completed.emit("edit", "editor", request, reviewed)

		# 3) CAPTION REVIEW STUDIO — the human checks captions the way an
		# editor would in CapCut: filmstrip + audio scrub + style pick.
		# Falls back to the plain approval desk if ffmpeg can't prep.
		var footage := _first_file(batch.path_join("01_FOOTAGE"))
		var action := "default"
		var style: Dictionary = {}
		var prev_dir := "/tmp/at_preview_%d" % int(Time.get_unix_time_from_system())
		var prepared := false
		if not footage.is_empty():
			EventBus.log_line.emit("🎞 Preparing studio preview (frames + audio)...")
			prepared = await PreviewMaker.prepare(footage, prev_dir)
		if prepared:
			EventBus.agent_say.emit("editor", I18n.f("say_studio", [Config.owner_name]))
			var decided: Array = [false, "default", {}]
			var cb := func(a: String, s: Dictionary) -> void:
				decided[0] = true
				decided[1] = a
				decided[2] = s
			EventBus.clip_review_resolved.connect(cb)
			EventBus.clip_review_requested.emit(request, srt_path, prev_dir)
			while not decided[0]:
				await get_tree().create_timer(0.25).timeout
			EventBus.clip_review_resolved.disconnect(cb)
			action = str(decided[1])
			style = decided[2]
			# studio edits wrote the srt — refresh what publish reports
			results["edit"] = FileAccess.get_file_as_string(srt_path)
		else:
			await _await_approval(request, reviewed)

		# 4) burn — reel.sh (skill standard) or the studio's chosen style
		var mp4 := ""
		if action == "custom":
			EventBus.log_line.emit("🔥 burn with studio style (1080x1920)...")
			var base := srt_path.get_file().trim_suffix("-clean.srt")
			mp4 = exports.path_join(base + ".mp4")
			var cues: Array = PreviewMaker.parse_srt(FileAccess.get_file_as_string(srt_path))
			r = await PreviewMaker.burn_custom(footage, cues, style, mp4)
			if int(r[1]) != 0 or not FileAccess.file_exists(mp4):
				mp4 = ""
		else:
			EventBus.log_line.emit("🔥 reel.sh burn (1080x1920)...")
			ReelRunner.run(PackedStringArray(["burn"]))
			r = await ReelRunner.finished
			mp4 = ReelRunner.newest_file(exports, ".mp4")
		if not mp4.is_empty():
			results["publish"] = "Burned reel: %s\n\n%s" % [mp4.get_file(), str(r[0]).right(300)]
			EventBus.log_line.emit("🎞 Cut file: %s" % mp4.get_file())
		else:
			results["publish"] = "(burn produced no mp4 — import the .srt in your editor)\n" + str(r[0]).right(300)

	results["review"] = "EP%d files live in:\n%s" % [ep, batch]
	request["_batch"] = batch  # so a typed fix can revise the REAL files
	var out_dir: String = OutputWriter.write_package(request, results)
	var done_dest := clip.get_base_dir().path_join("done").path_join(clip.get_file())
	if FileAccess.file_exists(clip):
		DirAccess.rename_absolute(clip, done_dest)
	TaskQueue.finish(request)
	# deliver the REAL folder: the batch 05_EXPORTS, not the town package
	EventBus.request_completed.emit(request, out_dir)
	EventBus.log_line.emit("📦 EP%d -> %s" % [ep, batch.path_join("05_EXPORTS")])
	OS.shell_open(batch.path_join("05_EXPORTS"))


## Newest media file inside a folder (the ingested footage).
func _first_file(dir_path: String) -> String:
	var d := DirAccess.open(dir_path)
	if d == null:
		return ""
	var best := ""
	var best_t := 0
	for f in d.get_files():
		if f.get_extension().to_lower() in ["mov", "mp4", "m4v", "mkv", "webm"]:
			var t := FileAccess.get_modified_time(dir_path.path_join(f))
			if t > best_t:
				best_t = t
				best = dir_path.path_join(f)
	return best


func _slugify(name: String, ep: int) -> String:
	var s := name.to_lower().replace(" ", "-")
	var re := RegEx.new()
	re.compile("[^a-z0-9\\-]")
	s = re.sub(s, "", true).left(40)
	while s.contains("--"):
		s = s.replace("--", "-")
	s = s.trim_prefix("-").trim_suffix("-")
	return s if s.length() >= 3 else "reel-ep%d" % ep


func _run_clip_legacy(request: Dictionary) -> void:
	var results: Dictionary = {}
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
				"Transcript of the owner's real clip:\n%s" % raw_srt.left(4000), results)

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


func _stage(stage: String, role: String, request: Dictionary, system_prompt: String,
		user_prompt: String, results: Dictionary) -> String:
	# delegation made VISIBLE (UX audit P1): every change of hands is a
	# real event the HUD, chat feed and world can show
	var prev_role := str(request.get("_last_role", ""))
	if not prev_role.is_empty() and prev_role != role:
		EventBus.handoff.emit(prev_role, role, stage, request)
	request["_last_role"] = role
	# the owner's rule: nobody waits for anyone else — a person only
	# queues behind THEIR OWN previous task
	await RoleLocks.acquire(role)
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
	RoleLocks.release(role)
	return out


## Fold a cancelled job gracefully: queue bookkeeping, one calm line
## from the Director, and every board clears its card.
func _cancel_job(request: Dictionary) -> void:
	var topic := str(request.get("topic", "untitled"))
	TaskQueue.finish(request)
	EventBus.request_cancelled.emit(request)
	EventBus.agent_say.emit("director", I18n.f("job_cancelled", [topic.left(30)]))
	EventBus.log_line.emit("✕ Cancelled: %s" % topic.left(48))


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
	# one desk: concurrent jobs take turns waiting for the owner
	await RoleLocks.acquire("approval_desk")
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
		# auto-approve IS a resolution: emit so the HUD panel closes
		# (cb is already disconnected, so this can't loop back here)
		EventBus.approval_resolved.emit(true)
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
	RoleLocks.release("approval_desk")
	return decided[1]


## A typed fix after delivery becomes real work (the team asked for it):
## clip jobs revise the actual clean.srt + re-burn in the same batch;
## idea jobs re-queue with the feedback baked into the brief.
func revise(request: Dictionary, feedback: String) -> void:
	var topic := str(request.get("topic", "")).left(40)
	Memory.remember_all(I18n.f("mem_feedback_fix", [Config.owner_name, topic, feedback.left(80)]), 8.0)
	EventBus.agent_say.emit("director", I18n.f("say_feedback_fix", [Config.owner_name]))
	if request.has("_batch"):
		_revise_clip(str(request["_batch"]), feedback, request)
		return
	# idea job: a revision request with the feedback in the notes
	var path := "res://queue/pending/fix_%d.json" % int(Time.get_unix_time_from_system())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"topic": "แก้ไข: %s" % topic,
			"notes": "REVISION requested by %s of a delivered package. Feedback: %s. Improve on the previous version accordingly." % [Config.owner_name, feedback],
		}, "  "))
		EventBus.log_line.emit("✍ Revision queued: %s" % topic)


func _revise_clip(batch: String, feedback: String, request: Dictionary) -> void:
	var exports := batch.path_join("05_EXPORTS")
	var srt_path := ReelRunner.newest_file(exports, "-clean.srt")
	if srt_path.is_empty():
		EventBus.log_line.emit("(no clean.srt found to revise)")
		return
	await _walk_stage("edit", "editor", request)
	var srt := FileAccess.get_file_as_string(srt_path)
	var fixed := srt
	if Config.provider_resolved != "simulate":
		var c: String = await Claude.complete(
			Prompts.editor(Config.language, Config.niche),
			("The owner reviewed this SRT and asked: \"%s\". Apply the fix, " +
			"keep ALL timing and numbering exactly, return ONLY the corrected SRT:\n\n%s") % [
			feedback, srt.left(6000)], "edit")
		if not c.is_empty() and c.contains("-->"):
			fixed = c.strip_edges() + "\n"
			var wf := FileAccess.open(srt_path, FileAccess.WRITE)
			if wf:
				wf.store_string(fixed)
	EventBus.stage_completed.emit("edit", "editor", request, fixed)
	EventBus.log_line.emit("🔥 re-burn after revision...")
	ReelRunner.run(PackedStringArray(["burn", "--batch", batch]))
	await ReelRunner.finished
	Memory.remember("editor", I18n.f("mem_clip_edited", [Config.owner_name, batch.get_file()]), 7.0)
	EventBus.log_line.emit("📦 Revised files -> %s" % exports)
	OS.shell_open(exports)


func _describe(request: Dictionary) -> String:
	var lines: Array[String] = []
	for key in ["topic", "audience", "duration_sec", "platform", "notes", "language", "niche"]:
		if request.has(key):
			lines.append("%s: %s" % [key, str(request[key])])
	return "\n".join(lines)
