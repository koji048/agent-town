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
	if request.get("_partial") is Dictionary:   # parked run: keep paid work
		results = request["_partial"]
		request.erase("_partial")
	var topic := str(request.get("topic", "untitled"))
	var lang := str(request.get("language", Config.language))
	var niche := str(request.get("niche", Config.niche))
	var brief := _describe(request)

	# DIRECTOR TRIAGE (orchestrator-worker, the Anthropic pattern): ONE
	# call reads the request and decides WHICH specialists this job
	# actually needs, with a one-line brief for each. The office is no
	# longer a fixed assembly line — a caption-only ask runs the
	# Publisher alone; a script ask never wastes a publish pass.
	var stages: Array = ["plan", "research", "script", "edit", "publish"]
	var sbriefs: Dictionary = {}
	if Config.provider_resolved != "simulate":
		var tri: String = await Claude.complete(
			"You are the Director of a Reels production office, triaging one incoming request. "
			+ "Decide the MINIMAL set of stages this job truly needs and reply with STRICT JSON only:\n"
			+ "{\"intent\": \"1-3 short lines, same language as the owner: core message, angle, must-haves\",\n"
			+ " \"stages\": [subset of \"plan\",\"research\",\"script\",\"edit\",\"publish\", kept in this order],\n"
			+ " \"briefs\": {stage: one-line brief for that specialist}}\n"
			+ "Rules: caption/post-only asks -> [\"publish\"]. Script without posting -> [\"plan\",\"research\",\"script\"]. "
			+ "Full reel content -> all five. \"edit\" only ever accompanies \"script\". NO text outside the JSON.",
			"Owner's request:\n%s" % brief, "plan")
		if tri.is_empty() and Claude.limited():
			_park_job(request, results)
			return
		var parsed := _parse_triage(tri)
		if not parsed.is_empty():
			stages = parsed["stages"]
			sbriefs = parsed.get("briefs", {})
			request["intent"] = str(parsed.get("intent", ""))
			if not str(request["intent"]).is_empty():
				brief += "\n\nDIRECTOR'S READING OF THE OWNER'S INTENT:\n" + str(request["intent"])
				EventBus.agent_say.emit("director", I18n.f("say_intent", [str(request["intent"]).left(140)]))
			EventBus.agent_say.emit("director", I18n.f("say_workplan", [_stages_thai(stages)]))
			EventBus.log_line.emit("🗺 Work plan: %s" % " → ".join(PackedStringArray(stages)))

	var role_of := {"plan": "director", "research": "researcher",
		"script": "writer", "edit": "editor", "publish": "publisher"}
	for st in ["plan", "research", "script", "edit", "publish"]:
		if not stages.has(st):
			continue
		var out := await _stage(str(st), str(role_of[st]), request,
			_sys_prompt(str(st), lang, niche),
			_user_prompt(str(st), brief, results, str(sbriefs.get(st, ""))), results)
		if TaskQueue.take_cancel(request):
			_cancel_job(request)
			return
		if out.is_empty():
			_park_job(request, results)
			return
		# the approval desk gates the script (skipped on caption-only jobs)
		if str(st) == "edit" and stages.has("script"):
			if not await _await_approval(request, str(results.get("script", ""))):
				EventBus.log_line.emit("✍ Revision requested — the Writer takes another pass.")
				Memory.remember("writer", "The reviewer sent my script for '%s' back. Round two." % topic, 7.0)
				Memory.nudge_affinity("writer", "director", -0.03)
				results.erase("script")
				results.erase("edit")
				var s2 := await _stage("script", "writer", request, _sys_prompt("script", lang, niche),
					_user_prompt("script", brief, results,
					"REVIEWER FEEDBACK: tighten the hook, cut anything slow, keep it punchy."), results)
				if s2.is_empty():
					_park_job(request, results)
					return
				var e2 := await _stage("edit", "editor", request, _sys_prompt("edit", lang, niche),
					_user_prompt("edit", brief, results, ""), results)
				if e2.is_empty():
					_park_job(request, results)
					return

	# DIRECTOR'S REVIEW WITH REAL AUTHORITY (LLM-as-judge, ONE bounded
	# fix round — Anthropic: give the judge teeth but a stopping rule)
	var verdict := await _stage("review", "director", request,
		Prompts.director_review(lang, niche)
		+ "\nStart your reply with exactly GO or FIX <stage>: <what to fix>, stage one of plan/research/script/edit/publish.",
		_user_prompt("review", brief, results, ""), results)
	if verdict.is_empty() and Claude.limited():
		_park_job(request, results)
		return
	var fix_re := RegEx.new()
	fix_re.compile("^FIX\\s+(plan|research|script|edit|publish)\\s*:?\\s*(.*)")
	var fm := fix_re.search(verdict.strip_edges())
	if fm and stages.has(fm.get_string(1)):
		var fst := fm.get_string(1)
		var fnote := fm.get_string(2).left(300)
		EventBus.agent_say.emit("director", I18n.f("say_fix_stage", [_stages_thai([fst]), fnote.left(80)]))
		EventBus.log_line.emit("🔧 Director orders a fix on %s: %s" % [fst, fnote.left(60)])
		results.erase(fst)
		var fixed := await _stage(fst, str(role_of[fst]), request, _sys_prompt(fst, lang, niche),
			_user_prompt(fst, brief, results,
			"DIRECTOR'S FIX ORDER (address this precisely): " + fnote), results)
		if fixed.is_empty() and Claude.limited():
			_park_job(request, results)
			return

	# the PRIMARY deliverable is whatever this job was really about —
	# ship nothing unless it is genuinely there
	var primary := "script"
	for cand in ["publish", "edit", "script", "research", "plan"]:
		if stages.has(cand):
			primary = cand
			break
	if not _valid(primary, str(results.get(primary, ""))):
		_park_job(request, results)
		return
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
## Parse the Director's triage JSON defensively (strict subset, edit
## requires script); {} on any malformed reply -> full pipeline.
func _parse_triage(text: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("(?s)\\{.*\\}")
	var mres := re.search(text)
	if mres == null:
		return {}
	var d: Variant = JSON.parse_string(mres.get_string(0))
	if not (d is Dictionary):
		return {}
	var stages: Array = []
	for s in d.get("stages", []):
		var ss := str(s)
		if ss in ["plan", "research", "script", "edit", "publish"] and not stages.has(ss):
			stages.append(ss)
	if stages.is_empty():
		return {}
	if stages.has("edit") and not stages.has("script"):
		stages.erase("edit")
	var briefs: Dictionary = {}
	if d.get("briefs") is Dictionary:
		briefs = d["briefs"]
	return {"stages": stages, "briefs": briefs, "intent": str(d.get("intent", ""))}


const STAGE_TH := {"plan": "วางแผน", "research": "ค้นคว้า", "script": "เขียนสคริปต์",
	"edit": "ทำแคปชั่น", "publish": "แพ็กโพสต์"}


func _stages_thai(stages: Array) -> String:
	var names: Array[String] = []
	for s in stages:
		names.append(str(STAGE_TH.get(str(s), str(s))))
	return " → ".join(names)


func _sys_prompt(stage: String, lang: String, niche: String) -> String:
	match stage:
		"plan": return Prompts.director_plan(lang, niche)
		"research": return Prompts.researcher(lang, niche)
		"script": return Prompts.scriptwriter(lang, niche)
		"edit": return Prompts.editor(lang, niche)
		"publish": return Prompts.publisher(lang, niche)
	return Prompts.director_review(lang, niche)


## Context injection: each specialist sees the request + exactly the
## upstream results that exist, never a blind chain of assumptions.
func _user_prompt(stage: String, brief: String, results: Dictionary, extra: String) -> String:
	var p := "Request:\n" + brief
	var ups: Dictionary = {"plan": [], "research": ["plan"], "script": ["plan", "research"],
		"edit": ["script"], "publish": ["script", "research"],
		"review": ["research", "script", "edit", "publish"]}
	for up in ups.get(stage, []):
		var txt := str(results.get(up, ""))
		if not txt.is_empty():
			p += "\n\n%s STAGE RESULT:\n%s" % [str(up).to_upper(), txt]
	if stage == "publish" and not results.has("script"):
		p += "\n\nThere is NO script for this job — write the publish package directly from the request and intent above."
	if not extra.strip_edges().is_empty():
		p += "\n\nDIRECTOR'S STAGE BRIEF: " + extra.strip_edges()
	return p


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
	var opts: Dictionary = request.get("clip_opts", {})
	var want_burn := bool(opts.get("burn", true))
	var want_caption := bool(opts.get("caption", true))

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

		if not want_burn:
			EventBus.log_line.emit("⏭ no-burn mode: delivering the .srt only, as ordered")
		else:
			# a clip burns ONLY on an explicit owner OK (studio Burn click,
			# or Yes at the fallback desk) — no auto-pass
			var do_burn := true
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
				var approved := await _await_approval(request, reviewed, false)
				if not approved:
					do_burn = false
					EventBus.log_line.emit("🛑 Subtitles rejected — no burn. The clean .srt is ready to fix.")

			# 4) burn — reel.sh (skill standard) or the studio's chosen style
			if do_burn:
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
					results["burn_note"] = "Burned reel: %s\n\n%s" % [mp4.get_file(), str(r[0]).right(300)]
					EventBus.log_line.emit("🎞 Cut file: %s" % mp4.get_file())
				else:
					results["burn_note"] = "(burn produced no mp4 — import the .srt in your editor)\n" + str(r[0]).right(300)
			else:
				results["burn_note"] = "(subtitles rejected — no burn; the clean .srt is delivered for manual fixing)"

		# 5) optional Publisher: a REAL paste-ready caption from the
		# actual transcript (only when the owner asked for it)
		if want_caption and Config.provider_resolved != "simulate":
			await _walk_stage("publish", "publisher", request)
			EventBus.log_line.emit("✏ Writing the Reel caption from the real transcript...")
			var cap: String = await Claude.complete(Prompts.publisher(lang, niche),
				"Write the publish package for this reel. Full subtitle transcript:\n\n"
				+ str(results.get("edit", "")).left(5000), "publish")
			if not cap.is_empty():
				results["publish"] = cap
				EventBus.stage_completed.emit("publish", "publisher", request, cap)
		elif not want_caption:
			results.erase("publish")

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
		if not await _await_approval(request, cleaned, false):
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


## Quality gate (Anthropic lesson: validate at checkpoints, an empty
## deliverable must FAIL loudly, never ship as a placeholder).
const STAGE_MIN := {"plan": 60, "research": 150, "script": 150,
	"edit": 60, "publish": 60, "review": 30}


func _valid(stage: String, out: String) -> bool:
	return out.strip_edges().length() >= int(STAGE_MIN.get(stage, 40))


## Park a job that hit the quota wall: keep every finished stage as a
## checkpoint, requeue, clear the boards, and the Director tells the
## owner exactly when work resumes. NOTHING fake gets delivered.
func _park_job(request: Dictionary, results: Dictionary) -> void:
	var topic := str(request.get("topic", "untitled"))
	request["_partial"] = results
	TaskQueue.park(request)
	EventBus.request_cancelled.emit(request)
	EventBus.agent_say.emit("director",
		I18n.f("say_parked", [topic.left(30), Claude.limit_reset_text()]))
	EventBus.log_line.emit("⏸ Parked (quota): %s — resumes ~%s" % [topic.left(40), Claude.limit_reset_text()])


func _stage(stage: String, role: String, request: Dictionary, system_prompt: String,
		user_prompt: String, results: Dictionary) -> String:
	# checkpoint reuse (resume-from-failure, not restart): a parked run
	# already paid for this stage — keep it
	if _valid(stage, str(results.get(stage, ""))):
		EventBus.log_line.emit("↻ %s: reusing checkpoint from the parked run" % stage)
		return str(results[stage])
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
	# mid-flight scope change: the owner's newest direction overrides
	# everything upstream for every stage still to run
	var scope := str(TaskQueue.scope_notes.get(topic, ""))
	if not scope.is_empty():
		user_prompt += "\n\nOWNER'S MID-FLIGHT SCOPE UPDATE (overrides earlier direction): " + scope
	var out: String = await Claude.complete(
		system_prompt + Memory.context_for(role, topic), user_prompt, stage)
	if not _valid(stage, out) and Claude.limited():
		# quota outage: do not interrogate the owner, do not fabricate —
		# release the desk and let the caller park the whole job
		RoleLocks.release(role)
		return ""
	if not _valid(stage, out):
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
	if not _valid(stage, out):
		# still broken after the retry: honest failure — no placeholder
		Memory.remember(role, I18n.f("mem_stage_fail", [stage, topic]), 7.0)
		Memory.nudge_affinity(role, "director", -0.04)
		RoleLocks.release(role)
		return ""
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
func _await_approval(request: Dictionary, preview: String, allow_auto := true) -> bool:
	# one desk: concurrent jobs take turns waiting for the owner
	await RoleLocks.acquire("approval_desk")
	var decided := [false, true]
	var cb := func(approved: bool) -> void:
		decided[0] = true
		decided[1] = approved
	EventBus.approval_resolved.connect(cb)
	EventBus.approval_requested.emit(request, preview)
	var waited := 0.0
	while not decided[0] and (not allow_auto or waited < 45.0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	EventBus.approval_resolved.disconnect(cb)
	if not decided[0] and allow_auto:
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
	# INTENT DISCRIMINATION: "the files are empty / broken" is an ops
	# complaint, not content feedback. Re-running "แก้ไข: <topic>" on a
	# dead provider just fails again — instead requeue the ORIGINAL
	# brief as a fresh run that starts when the provider is healthy.
	var lowfb := feedback.to_lower()
	for kw in ["ว่างเปล่า", "ไฟล์เปล่า", "ไม่มีเนื้อหา", "ไฟล์เสีย", "empty", "blank", "no output", "พัง", "error"]:
		if lowfb.contains(kw):
			var clean_topic := str(request.get("topic", ""))
			while clean_topic.begins_with("แก้ไข: "):
				clean_topic = clean_topic.trim_prefix("แก้ไข: ")
			var clean_notes := str(request.get("notes", ""))
			if clean_notes.begins_with("REVISION requested"):
				clean_notes = ""
			TaskQueue.park({"topic": clean_topic, "notes": clean_notes})
			EventBus.agent_say.emit("director", I18n.t("say_ops_retry"))
			EventBus.log_line.emit("♻ Ops complaint detected — fresh rerun queued: %s" % clean_topic.left(40))
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
