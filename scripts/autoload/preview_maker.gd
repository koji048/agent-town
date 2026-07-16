## Media prep for the Caption Review Studio: extracts a 2 fps filmstrip
## + a mono WAV from the footage (so the studio can scrub video+audio
## like CapCut without needing an mp4 decoder in-engine), parses SRT,
## writes ASS with the chosen style, and runs custom burns.
## All ffmpeg work happens on worker threads — the town never blocks.
extends Node

signal _job_done(out: String, code: int)

const FRAME_FPS := 8.0  # CapCut-feel scrubbing (2 fps read as broken)

## Matches the reels-pipeline ASS recipe; PrimaryColour/OutlineColour
## become parameters so the studio's colour picker is honoured.
const ASS_HEADER := """[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,{font},{size},{primary},&H000000FF,{outline_col},&H78000000,0,0,0,0,100,100,0,0,1,{outline},1,2,70,70,{margin_v},1
Style: Title,{title_font},{title_size},{title_primary},&H00000000,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,4,0,5,60,60,60,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""


func ffmpeg_bin() -> String:
	for p in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]:
		if FileAccess.file_exists(p):
			return p
	return "ffmpeg"


func ffprobe_bin() -> String:
	for p in ["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe"]:
		if FileAccess.file_exists(p):
			return p
	return "ffprobe"


func available() -> bool:
	var out: Array = []
	return OS.execute(ffmpeg_bin(), PackedStringArray(["-version"]), out) == 0


## Threaded command runner (ReelRunner pattern, single-flight is fine —
## clips are exclusive in the queue).
func run_cmd(bin: String, args: PackedStringArray) -> Array:
	var th := Thread.new()
	th.start(func() -> void:
		var out: Array = []
		var code := OS.execute(bin, args, out, true)
		var text := ""
		for line in out:
			text += str(line)
		call_deferred("emit_signal", "_job_done", text, code))
	var r: Array = await _job_done
	th.wait_to_finish()
	return r


## Extract filmstrip frames + preview audio. Returns true when usable.
func prepare(video: String, out_dir: String) -> bool:
	if not available():
		return false
	DirAccess.make_dir_recursive_absolute(out_dir)
	var r: Array = await run_cmd(ffmpeg_bin(), PackedStringArray([
		"-y", "-i", video, "-vf", "fps=%s,scale=432:-2" % FRAME_FPS,
		"-q:v", "5", out_dir.path_join("f_%05d.jpg")]))
	if int(r[1]) != 0:
		return false
	r = await run_cmd(ffmpeg_bin(), PackedStringArray([
		"-y", "-i", video, "-vn", "-ac", "1", "-ar", "22050",
		"-acodec", "pcm_s16le", out_dir.path_join("preview.wav")]))
	return int(r[1]) == 0 and FileAccess.file_exists(out_dir.path_join("preview.wav"))


func frame_count(dir_path: String) -> int:
	var d := DirAccess.open(dir_path)
	if d == null:
		return 0
	var n := 0
	for f in d.get_files():
		if f.begins_with("f_") and f.ends_with(".jpg"):
			n += 1
	return n


## Is the footage portrait AFTER rotation metadata (reel_common.probe)?
func probe_portrait(video: String) -> bool:
	var out: Array = []
	OS.execute(ffprobe_bin(), PackedStringArray([
		"-v", "quiet", "-select_streams", "v:0", "-print_format", "json",
		"-show_entries", "stream=width,height,side_data_list", video]), out, true)
	var data: Variant = JSON.parse_string("".join(PackedStringArray(out)))
	if not (data is Dictionary) or not data.has("streams") or data["streams"].is_empty():
		return true
	var s: Dictionary = data["streams"][0]
	var w := int(s.get("width", 1080))
	var h := int(s.get("height", 1920))
	var rot := 0
	for sd in s.get("side_data_list", []):
		if sd is Dictionary and sd.has("rotation"):
			rot = int(sd["rotation"])
	if absi(rot) % 180 == 90:
		var tmp := w
		w = h
		h = tmp
	return w <= h


## ---- SRT <-> cues ----
func parse_srt(text: String) -> Array:
	var cues: Array = []
	var re := RegEx.new()
	re.compile("(\\d+):(\\d+):(\\d+)[,.](\\d+)")
	for block in text.replace("\r", "").split("\n\n"):
		var lines: PackedStringArray = block.strip_edges().split("\n")
		var tl := -1
		for i in lines.size():
			if lines[i].contains("-->"):
				tl = i
				break
		if tl < 0 or tl + 1 >= lines.size():
			continue
		var parts: PackedStringArray = lines[tl].split("-->")
		var cue_text := ""
		for i in range(tl + 1, lines.size()):
			cue_text += ("\n" if not cue_text.is_empty() else "") + lines[i]
		var sm := re.search(parts[0])
		var em := re.search(parts[1])
		if sm == null or em == null or cue_text.strip_edges().is_empty():
			continue
		cues.append({
			"start": _ts(sm), "end": _ts(em), "text": cue_text.strip_edges(),
		})
	return cues


func _ts(m: RegExMatch) -> float:
	return int(m.get_string(1)) * 3600.0 + int(m.get_string(2)) * 60.0 \
		+ int(m.get_string(3)) + int(m.get_string(4)) / 1000.0


func write_srt(cues: Array, path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	for i in cues.size():
		var c: Dictionary = cues[i]
		f.store_string("%d\n%s --> %s\n%s\n\n" % [
			i + 1, _fmt_srt(float(c["start"])), _fmt_srt(float(c["end"])),
			str(c["text"])])


func _fmt_srt(t: float) -> String:
	var ms := int(round(t * 1000.0))
	return "%02d:%02d:%02d,%03d" % [ms / 3600000, (ms / 60000) % 60,
		(ms / 1000) % 60, ms % 1000]


func _fmt_ass(t: float) -> String:
	var cs := int(round(t * 100.0))
	return "%d:%02d:%02d.%02d" % [cs / 360000, (cs / 6000) % 60,
		(cs / 100) % 60, cs % 100]


func write_ass(cues: Array, style: Dictionary, path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(ASS_HEADER.format({
		"font": str(style.get("font_name", "Anuphan")),
		"size": int(style.get("size", 72)),
		"primary": str(style.get("primary", "&H00FFFFFF")),
		"outline_col": str(style.get("outline_col", "&H00000000")),
		"outline": 3,
		"margin_v": int(style.get("margin_v", 360)),
		"title_font": str(style.get("title_font", "Anuphan")),
		"title_size": int(style.get("title_size", 100)),
		"title_primary": str(style.get("title_primary", "&H0000FFFF")),
	}))
	# EP opening title card over the first 2.5s: the studio's edited text (else
	# EP.. : topic), styled by the Title style, placed at its chosen centre via \pos
	var title_text: String = str(style.get("title_text", ""))
	if title_text.is_empty():
		var ep: int = int(style.get("ep", 0))
		var ttl: String = str(style.get("title", ""))
		if ep > 0 and not ttl.is_empty():
			title_text = "EP%02d : %s" % [ep, ttl.left(60)]
	if not title_text.is_empty():
		var tx: int = int(style.get("title_x", 540))
		var ty: int = int(style.get("title_y", 960))
		var t_start: float = float(style.get("title_start", 0.0))
		var t_end: float = float(style.get("title_end", t_start + 2.5))
		f.store_string("Dialogue: 0,%s,%s,Title,,0,0,0,,{\\pos(%d,%d)}%s\n" % [
			_fmt_ass(t_start), _fmt_ass(t_end), tx, ty, title_text.left(80).replace("\n", "\\N")])
	for c in cues:
		f.store_string("Dialogue: 0,%s,%s,Default,,0,0,0,,%s\n" % [
			_fmt_ass(float(c["start"])), _fmt_ass(float(c["end"])),
			str(c["text"]).replace("\n", "\\N")])


## Custom burn: the reel_common.build_vf recipe verbatim, our ASS on top.
func burn_custom(video: String, cues: Array, style: Dictionary, final_mp4: String) -> Array:
	var ass := "/tmp/at_studio.ass"
	write_ass(cues, style, ass)
	var vf := ""
	if probe_portrait(video):
		vf = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30"
	else:
		vf = "crop=ih*9/16:ih:(iw-ih*9/16)/2+0:0,scale=1080:1920,setsar=1,fps=30"
	vf += ",subtitles=filename=%s:fontsdir=%s" % [ass,
		ProjectSettings.globalize_path("res://assets/fonts")]
	# Audio normalized for TikTok/IG Android players: 48 kHz stereo (platform
	# spec; 44.1k passthrough correlated with Android-only silence on a posted
	# EP) and timestamps starting at 0 (iPhone sources carry a negative-pts
	# edit list that some Android decoders mute on). Mirrors burn.py.
	return await run_cmd(ffmpeg_bin(), PackedStringArray([
		"-y", "-i", video, "-vf", vf,
		"-c:v", "libx264", "-preset", "medium", "-crf", "20",
		"-pix_fmt", "yuv420p", "-movflags", "+faststart",
		"-af", "aresample=async=1:first_pts=0",
		"-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
		"-r", "30", final_mp4]))


## ---- runtime WAV (16-bit PCM mono) ----
func load_wav(path: String) -> AudioStreamWAV:
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 44:
		return null
	var pos := 12
	var data_off := -1
	var data_len := 0
	while pos + 8 <= b.size():
		var tag := b.slice(pos, pos + 4).get_string_from_ascii()
		var size := b.decode_u32(pos + 4)
		if tag == "data":
			data_off = pos + 8
			data_len = size
			break
		pos += 8 + size + (size & 1)
	if data_off < 0:
		return null
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = 22050
	s.stereo = false
	s.data = b.slice(data_off, data_off + data_len)
	return s


## Peak-per-bucket waveform for the timeline strip.
func wave_buckets(path: String, buckets: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 44:
		return out
	var pos := 12
	var data_off := -1
	var data_len := 0
	while pos + 8 <= b.size():
		var tag := b.slice(pos, pos + 4).get_string_from_ascii()
		var size := b.decode_u32(pos + 4)
		if tag == "data":
			data_off = pos + 8
			data_len = size
			break
		pos += 8 + size + (size & 1)
	if data_off < 0:
		return out
	var samples := data_len / 2
	var step := maxi(samples / buckets, 1)
	out.resize(buckets)
	for i in buckets:
		var peak := 0
		var start := data_off + i * step * 2
		for j in range(0, step, 8):  # sparse sampling is plenty for a strip
			var o := start + j * 2
			if o + 1 >= b.size():
				break
			peak = maxi(peak, absi(b.decode_s16(o)))
		out[i] = clampf(peak / 32768.0, 0.0, 1.0)
	return out
