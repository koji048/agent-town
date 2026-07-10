## Claude API client (Anthropic Messages API) using Godot's HTTPRequest.
## Retries with exponential backoff on transient errors. In simulate mode
## (no API key) it returns canned demo content so the town still runs.
extends Node

const API_URL := "https://api.anthropic.com/v1/messages"
const API_VERSION := "2023-06-01"
const MAX_RETRIES := 4
const NON_RETRYABLE := [400, 401, 403, 404, 413]

const SIM_TEXT := {
	"plan": "[demo] Production brief\n- Hook angle: speed + surprise\n- Researcher: find 3 pain points\n- Writer: 45s script, Thai VO, EN hook\n- Editor: caption-capped subs\n- Publisher: title + hashtags TH/EN",
	"research": "[demo] Research notes\n- Hook: \"90% ของคนตัดต่อช้าเพราะข้อนี้\"\n- Fact: batch editing saves ~40% time\n- Angle: before/after demo works best for how-to Reels",
	"script": "[demo] Script (45s)\n[0-3s] HOOK (EN): Stop editing the slow way.\n[3-15s] ปัญหา: ตัดต่อทีละคลิปเสียเวลามาก\n[15-35s] วิธีทำ 3 ขั้นตอน...\n[35-45s] CTA: เซฟไว้ลองทำตามได้เลย",
	"edit": "[demo] Captions (SRT)\n1\n00:00:00,000 --> 00:00:03,000\nStop editing the slow way\n\n2\n00:00:03,000 --> 00:00:07,000\nตัดต่อทีละคลิป = เสียเวลา",
	"publish": "[demo] Publish package\nTitle: ตัดต่อไวขึ้น 2 เท่าใน 3 ขั้นตอน\nHashtags: #ตัดต่อวิดีโอ #HowTo #ReelsTips #ContentCreator",
	"review": "[demo] Director review: GO ✅\nHook is strong, pacing fits 45s, captions readable. Ship it.",
}


signal _cli_finished(text: String, code: int)


## Sends one completion request. Returns the text result, or "" on failure.
## Provider chain: claude-code CLI -> Anthropic API -> simulate.
## PARALLEL-SAFE: every call gets its own temp files and its own result
## slot — agents never wait for EACH OTHER, only a person waits for
## their own previous task (per-role locks live in RoleLocks).
## Circuit breaker (Anthropic multi-agent lesson: classify failures,
## never let agents grind against a dead provider). When the CLI says
## the session quota is gone we remember WHEN it returns and every
## caller can check limited() instead of burning more calls.
var limit_until := 0


func limited() -> bool:
	return limit_until > int(Time.get_unix_time_from_system())


func _note_failure(text: String) -> void:
	var lower := text.to_lower()
	if not (lower.contains("hit your session limit") or lower.contains("rate limit")
			or lower.contains("usage limit")):
		return
	var was := limited()
	var until := int(Time.get_unix_time_from_system()) + 30 * 60
	var re := RegEx.new()
	re.compile("resets? (\\d{1,2}):(\\d{2})\\s*(am|pm)")
	var mres := re.search(lower)
	if mres:
		var hh := int(mres.get_string(1)) % 12
		if mres.get_string(3) == "pm":
			hh += 12
		var d := Time.get_datetime_dict_from_system()
		d["hour"] = hh
		d["minute"] = int(mres.get_string(2))
		d["second"] = 0
		# from_datetime_dict assumes UTC; correct with the local bias
		var bias := int(Time.get_unix_time_from_system()) \
			- int(Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system()))
		var t := int(Time.get_unix_time_from_datetime_dict(d)) + bias
		if t <= int(Time.get_unix_time_from_system()):
			t += 24 * 3600
		until = t + 90
	limit_until = until
	if not was:
		EventBus.provider_limited.emit(text.left(120), until)


## Local wall-clock "HH:MM" for the moment the quota returns.
func limit_reset_text() -> String:
	var off: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(limit_until + off).substr(11, 5)


func complete(system_prompt: String, user_prompt: String, sim_stage: String = "") -> String:
	if Config.provider_resolved == "simulate":
		await get_tree().create_timer(randf_range(2.5, 5.0)).timeout
		return SIM_TEXT.get(sim_stage, "[demo] done.")
	return await _complete_live(system_prompt, user_prompt)


func _complete_live(system_prompt: String, user_prompt: String) -> String:
	if Config.provider_resolved == "claude-code":
		var cli_text := await _cli_complete(system_prompt, user_prompt)
		if not cli_text.is_empty():
			return cli_text
		EventBus.log_line.emit("claude-code call failed — trying API fallback")
		if Config.api_key.is_empty():
			return ""

	for attempt in MAX_RETRIES:
		var http := HTTPRequest.new()
		add_child(http)
		http.timeout = 180.0
		var headers := PackedStringArray([
			"content-type: application/json",
			"x-api-key: " + Config.api_key,
			"anthropic-version: " + API_VERSION,
		])
		var body := JSON.stringify({
			"model": Config.model,
			"max_tokens": Config.max_tokens,
			"system": system_prompt,
			"messages": [{"role": "user", "content": user_prompt}],
		})
		var err := http.request(API_URL, headers, HTTPClient.METHOD_POST, body)
		if err != OK:
			http.queue_free()
			EventBus.log_line.emit("HTTP request error %d — retrying" % err)
			await get_tree().create_timer(2.0 * (attempt + 1)).timeout
			continue

		var result: Array = await http.request_completed
		http.queue_free()
		var status: int = result[1]
		var response: PackedByteArray = result[3]

		if result[0] == HTTPRequest.RESULT_SUCCESS and status == 200:
			var data: Variant = JSON.parse_string(response.get_string_from_utf8())
			if data is Dictionary and data.has("content"):
				var text := ""
				for block in data["content"]:
					if block is Dictionary and block.get("type", "") == "text":
						text += str(block["text"])
				return text
			EventBus.log_line.emit("Unexpected API response shape")
			return ""

		EventBus.log_line.emit("Claude API HTTP %d (attempt %d/%d)" % [status, attempt + 1, MAX_RETRIES])
		if status in NON_RETRYABLE:
			var detail: Variant = JSON.parse_string(response.get_string_from_utf8())
			if detail is Dictionary and detail.has("error"):
				EventBus.log_line.emit(str(detail["error"].get("message", "")).left(120))
			return ""
		await get_tree().create_timer(pow(2.0, attempt + 1)).timeout
	return ""


var _next_call_id := 0
var _call_results: Dictionary = {}


## Headless Claude Code session (production brain): runs `claude -p` in a
## worker thread so the office never blocks, using the owner's login.
## Everything (prompts AND the invocation) travels via files on disk —
## Godot's OS.execute pipe path mangles shell metacharacters in args, so
## no generated content may ever appear in the argument list. Each call
## gets UNIQUE temp files + its own result slot: fully concurrent.
func _cli_complete(system_prompt: String, user_prompt: String) -> String:
	if limited():
		return ""    # quota outage: fail fast, callers park the job
	var id := _next_call_id
	_next_call_id += 1
	var user_res := "user://cli_user_%d.txt" % id
	var sys_res := "user://cli_sys_%d.txt" % id
	var run_res := "user://cli_run_%d.zsh" % id
	var user_f := ProjectSettings.globalize_path(user_res)
	var sys_f := ProjectSettings.globalize_path(sys_res)
	var run_f := ProjectSettings.globalize_path(run_res)
	var fu := FileAccess.open(user_res, FileAccess.WRITE)
	fu.store_string(user_prompt)
	fu.close()
	var fs := FileAccess.open(sys_res, FileAccess.WRITE)
	fs.store_string(system_prompt)
	fs.close()
	var fr := FileAccess.open(run_res, FileAccess.WRITE)
	fr.store_string("exec " + _shq(Config.cli_path)
		+ " -p \"$(cat " + _shq(user_f) + ")\""
		+ " --append-system-prompt \"$(cat " + _shq(sys_f) + ")\""
		+ " --output-format text < /dev/null\n")
	fr.close()
	var th := Thread.new()
	th.start(func() -> void:
		var out: Array = []
		var code := OS.execute("/bin/zsh", PackedStringArray([run_f]), out, true)
		var text := ""
		for line in out:
			text += str(line)
		call_deferred("_store_result", id, text, code))
	while not _call_results.has(id):
		await get_tree().create_timer(0.15).timeout
	var res: Array = _call_results[id]
	_call_results.erase(id)
	th.wait_to_finish()
	for tmp in [user_res, sys_res, run_res]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	var text := str(res[0]).strip_edges()
	var code := int(res[1])
	if code != 0:
		printerr("claude-code FAIL code=%d out=%s" % [code, text.left(300)])
		_note_failure(text)
		EventBus.log_line.emit("claude-code exited %d: %s" % [code, text.left(80)])
		return ""
	if text.is_empty():
		printerr("claude-code EMPTY output (code 0)")
	return text


func _store_result(id: int, text: String, code: int) -> void:
	_call_results[id] = [text, code]


## Single-quote shell escaping for zsh -c command strings.
func _shq(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"
