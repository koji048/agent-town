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
func complete(system_prompt: String, user_prompt: String, sim_stage: String = "") -> String:
	if Config.provider_resolved == "simulate":
		await get_tree().create_timer(randf_range(2.5, 5.0)).timeout
		return SIM_TEXT.get(sim_stage, "[demo] done.")

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


## Headless Claude Code session (production brain): runs `claude -p` in a
## worker thread so the office never blocks, using the owner's login.
func _cli_complete(system_prompt: String, user_prompt: String) -> String:
	# run through zsh with stdin closed (the CLI otherwise waits 3s on a pipe)
	var cmd := "%s -p %s --append-system-prompt %s --output-format text < /dev/null" % [
		_shq(Config.cli_path), _shq(user_prompt), _shq(system_prompt)]
	var th := Thread.new()
	th.start(func() -> void:
		var out: Array = []
		var code := OS.execute("/bin/zsh", PackedStringArray(["-c", cmd]), out, true)
		var text := ""
		for line in out:
			text += str(line)
		call_deferred("emit_signal", "_cli_finished", text, code))
	var res: Array = await _cli_finished
	th.wait_to_finish()
	var text := str(res[0]).strip_edges()
	var code := int(res[1])
	if code != 0:
		EventBus.log_line.emit("claude-code exited %d: %s" % [code, text.left(80)])
		return ""
	return text


## Single-quote shell escaping for zsh -c command strings.
func _shq(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"
