## Thai/English UI toggle. All chrome strings live here; nodes register
## and are re-labeled live on toggle. UI font: Anuphan (SIL OFL, Thai +
## Latin) — assets/fonts/. Agent-generated CONTENT keeps its own
## language (that's the content config, not the chrome).
extends Node

signal changed

const S := {
	"hud_title": {"en": "AGENT TOWN — virtual office", "th": "AGENT TOWN — ออฟฟิศเสมือน"},
	"status_idle": {"en": "IDLE — drop a .json into queue/pending/ or pin an idea", "th": "ว่าง — วางไฟล์ใน queue/pending/ หรือปักไอเดียใหม่"},
	"btn_costumes": {"en": "  Costumes  ", "th": "  ชุดตัวละคร  "},
	"btn_idea": {"en": "  📌 New idea  ", "th": "  📌 ไอเดียใหม่  "},
	"btn_deliver": {"en": "  📦 Deliverables  ", "th": "  📦 งานที่เสร็จ  "},
	"btn_board": {"en": "  📋 Board  ", "th": "  📋 บอร์ดงาน  "},
	"board_title": {"en": "AGENT TOWN — PROJECT BOARD", "th": "AGENT TOWN — บอร์ดโปรเจกต์"},
	"lane_projects": {"en": "PROJECTS", "th": "โปรเจกต์"},
	"lane_backlog": {"en": "BACKLOG", "th": "คิวงาน"},
	"lane_progress": {"en": "IN PROGRESS", "th": "กำลังทำ"},
	"lane_review": {"en": "REVIEW", "th": "รออนุมัติ"},
	"lane_done": {"en": "DONE", "th": "เสร็จแล้ว"},
	"btn_close": {"en": "  ✕ Close  ", "th": "  ✕ ปิด  "},
	"btn_open_files": {"en": "  Open files  ", "th": "  เปิดไฟล์  "},
	"btn_approve": {"en": "  Approve [Y]  ", "th": "  อนุมัติ [Y]  "},
	"btn_revise": {"en": "  Request revision [N]  ", "th": "  ขอแก้ไข [N]  "},
	"btn_praise": {"en": " ♥ Praise ", "th": " ♥ ชมเชย "},
	"btn_coach": {"en": " ✎ Coach ", "th": " ✎ แนะนำ "},
	"btn_chat": {"en": " 💬 Chat ", "th": " 💬 คุย "},
	"btn_send": {"en": "  Send  ", "th": "  ส่ง  "},
	"btn_cancel": {"en": "  Cancel  ", "th": "  ยกเลิก  "},
	"btn_open_pkg": {"en": "  Open package  ", "th": "  เปิดแพ็กเกจ  "},
	"btn_later": {"en": "  Later  ", "th": "  ไว้ก่อน  "},
	"team_title": {"en": "TEAM", "th": "ทีมงาน"},
	"remembers": {"en": "Remembers:", "th": "ความทรงจำ:"},
	"need_energy": {"en": "ENERGY", "th": "พลังงาน"},
	"need_social": {"en": "SOCIAL", "th": "สังคม"},
	"need_inspiration": {"en": "INSPIRATION", "th": "แรงบันดาลใจ"},
	"task_available": {"en": "available", "th": "ว่าง"},
	"task_heading": {"en": "heading to desk", "th": "กำลังไปโต๊ะ"},
	"task_break": {"en": "break", "th": "พักเบรก"},
	"waiting_director": {"en": "waiting for the Director", "th": "รอผู้กำกับรับงาน"},
	"card_stage": {"en": "stage: %s · assignee: %s", "th": "ขั้นตอน: %s · ผู้ทำ: %s"},
	"review_wait": {"en": "waiting at the approval desk — decide in the game window", "th": "รออนุมัติที่โต๊ะ — ตัดสินใจในหน้าต่างเกม"},
	"state_idle": {"en": "IDLE", "th": "ว่าง"},
	"state_walking": {"en": "WALKING", "th": "กำลังเดิน"},
	"state_working": {"en": "WORKING", "th": "กำลังทำงาน"},
	# board v2: filters + PIC
	"filter_search": {"en": "Search...", "th": "ค้นหา..."},
	"filter_all": {"en": " All ", "th": " ทั้งหมด "},
	"pic": {"en": "PIC", "th": "ผู้ทำ"},
	"stage_file": {"en": "%s (by %s)", "th": "%s (โดย %s)"},
	# agent speech — the conversation follows the toggle too
	"say_plan": {"en": "New request! Drafting the brief...", "th": "งานใหม่เข้า! กำลังร่างบรีฟ..."},
	"say_research": {"en": "Digging for hooks and facts...", "th": "กำลังขุดหาฮุคกับข้อมูล..."},
	"say_script": {"en": "Writing the script...", "th": "กำลังเขียนสคริปต์..."},
	"say_edit": {"en": "Cutting captions to size...", "th": "กำลังตัดแคปชันให้พอดี..."},
	"say_publish": {"en": "Packaging for publish...", "th": "กำลังแพ็กงานเตรียมโพสต์..."},
	"say_review": {"en": "Final quality check...", "th": "ตรวจคุณภาพรอบสุดท้าย..."},
	"say_onit": {"en": "On it...", "th": "จัดให้..."},
	"say_fail": {"en": "That one failed...", "th": "งานนี้พลาดซะแล้ว..."},
	"say_thanks": {"en": "Thanks, %s!", "th": "ขอบคุณครับ %s!"},
	"say_noted": {"en": "Noted, %s.", "th": "รับทราบครับ %s"},
	"say_chat_sim": {"en": "Good to see you, %s! Heads-down today, but ask me anything.", "th": "ดีใจที่แวะมาครับ %s! วันนี้งานแน่นแต่ถามได้เลย"},
	"say_lost": {"en": "Sorry %s — lost my train of thought there.", "th": "ขอโทษครับ %s — เมื่อกี้หลุดโฟกัสไปแป๊บ"},
	"say_greet": {"en": "Morning, %s! Good to have you in the office.", "th": "สวัสดีครับ %s! ดีใจที่เข้ามาที่ออฟฟิศนะครับ"},
	"say_meeting": {"en": "Team huddle! New job: '%s'", "th": "ประชุมด่วน! งานใหม่: '%s'"},
	"chat_feed_title": {"en": "OFFICE CHAT", "th": "แชทออฟฟิศ"},
	"clip_received": {"en": "🎬 Got the clip — sending it to the team!", "th": "🎬 รับคลิปแล้ว — ส่งให้ทีมเลย!"},
	"clip_found": {"en": "New clip in Downloads: %s — send it to the team?", "th": "เจอคลิปใหม่ใน Downloads: %s — ส่งให้ทีมทำเลยไหม?"},
	"btn_send_team": {"en": "  Send to the team  ", "th": "  ส่งให้ทีม  "},
	"btn_not_work": {"en": "  Not a work clip  ", "th": "  ไม่ใช่คลิปงาน  "},
	"ask_feedback": {"en": "The team asks: anything to fix in '%s'? (type it, or say it's good)", "th": "ทีมขอถามครับ: งาน '%s' มีตรงไหนให้แก้ไหม? (พิมพ์บอกได้เลย หรือกดว่าดีแล้ว)"},
	"btn_good": {"en": "  Looks good ✓  ", "th": "  ดีแล้ว ✓  "},
	"btn_send_fix": {"en": "  Send the fix  ", "th": "  ส่งให้แก้  "},
	"say_feedback_good": {"en": "%s says it's good — nice work everyone!", "th": "%s บอกว่าดีแล้ว — เก่งมากทุกคน!"},
	"say_feedback_fix": {"en": "%s wants changes — back to it, team.", "th": "%s ขอให้แก้ — ลุยต่อทีม"},
	"mem_feedback_good": {"en": "%s reviewed '%s' and said it was good.", "th": "%s ดูงาน '%s' แล้วบอกว่าดีแล้ว"},
	"mem_feedback_fix": {"en": "%s asked us to fix '%s': \"%s\"", "th": "%s ขอให้แก้งาน '%s': \"%s\""},
	"btn_chat_feed": {"en": "  💬 Chat  ", "th": "  💬 แชท  "},
	"say_celebrate_1": {"en": "Great work, team!", "th": "สุดยอดมากทีม!"},
	"say_celebrate_2": {"en": "We shipped it!", "th": "งานออกแล้วโว้ย!"},
	"say_celebrate_3": {"en": "To the town hall!", "th": "ไปฉลองที่ลานกัน!"},
	# casual smalltalk pools (fallback when the LLM isn't writing lines)
	"small_1a": {"en": "Coffee's actually decent today.", "th": "วันนี้กาแฟดีกว่าทุกวันแฮะ"},
	"small_1b": {"en": "Right? Someone changed the beans.", "th": "ใช่ป่ะ สงสัยมีคนเปลี่ยนเมล็ด"},
	"small_2a": {"en": "That last job went smoother than I thought.", "th": "งานเมื่อกี้ลื่นกว่าที่คิดว่ะ"},
	"small_2b": {"en": "Told you we're getting faster.", "th": "บอกแล้วว่าพวกเราเร็วขึ้นเรื่อยๆ"},
	"small_3a": {"en": "The garden's nice this hour.", "th": "ช่วงนี้สวนบรรยากาศดีนะ"},
	"small_3b": {"en": "Best thinking spot in the office.", "th": "ที่คิดงานเวิร์กสุดในออฟฟิศละ"},
	"small_4a": {"en": "Any word from %s today?", "th": "วันนี้ %s ว่าไงบ้าง"},
	"small_4b": {"en": "Quiet so far. Storm's coming, probably.", "th": "ยังเงียบอยู่ เดี๋ยวงานคงถล่มมา"},
	"ask_stuck": {"en": "My %s stage for '%s' came up empty. Any direction for the retry?", "th": "ขั้นตอน %s ของงาน '%s' ออกมาว่างเปล่า ช่วยชี้ทางให้หน่อยได้ไหมครับ?"},
	"lang_directive": {"en": "Reply in casual English.", "th": "ตอบเป็นภาษาไทยแบบเพื่อนร่วมงาน สั้น กระชับ"},
	# storyteller events
	"st_trend_say": {"en": "Heads up team — %s!", "th": "ทีมฟังทางนี้ — %s!"},
	"st_espresso_down": {"en": "Who broke the espresso machine?!", "th": "ใครทำเครื่องกาแฟพัง?!"},
	"st_espresso_up": {"en": "Coffee's back. We live again.", "th": "กาแฟกลับมาแล้ว รอดตาย!"},
	"st_rush_say": {"en": "Next one's a rush job — tight and sharp, people.", "th": "งานหน้าเป็นงานด่วน — กระชับและคมนะทุกคน"},
	# smart-object break lines
	"line_espresso": {"en": "Espresso o'clock.", "th": "ได้เวลาเอสเพรสโซ่"},
	"line_coffee": {"en": "Coffee first, then genius.", "th": "กาแฟก่อน แล้วค่อยอัจฉริยะ"},
	"line_couch": {"en": "Five-minute couch break.", "th": "พักโซฟาห้านาที"},
	"line_howgoing": {"en": "So, how's your part going?", "th": "งานส่วนนายไปถึงไหนแล้ว?"},
	"line_lounge": {"en": "Lounge check-in.", "th": "แวะเลานจ์หน่อย"},
	"line_garden": {"en": "The garden helps me think.", "th": "สวนช่วยให้คิดออก"},
	"line_freshair": {"en": "Fresh air, fresh hooks.", "th": "อากาศใหม่ ฮุคใหม่"},
	"line_focus": {"en": "Focus booth. No pings.", "th": "ตู้โฟกัส ห้ามใครกวน"},
	"line_library": {"en": "A chapter from the library.", "th": "อ่านสักบทจากห้องสมุด"},
	# memory templates (written in the current language)
	"mem_stage_done": {"en": "I finished the %s stage for '%s'.", "th": "ฉันทำขั้นตอน %s ของ '%s' เสร็จแล้ว"},
	"mem_stage_fail": {"en": "My %s stage failed on '%s'. Frustrating.", "th": "ขั้นตอน %s ของ '%s' พลาด หงุดหงิดจริง"},
	"mem_shipped": {"en": "We shipped the reel '%s' and celebrated in the garden.", "th": "พวกเราส่งรีล '%s' สำเร็จ แล้วไปฉลองกันที่สวน"},
	"mem_praised": {"en": "%s praised my work%s. Felt great.", "th": "%s ชมผลงานของฉัน%s รู้สึกดีมาก"},
	"mem_coached": {"en": "%s coached me: \"%s\" — I'll apply that next time.", "th": "%s แนะนำฉันว่า \"%s\" — คราวหน้าจะทำตามนั้น"},
	"mem_owner_said": {"en": "%s said to me: \"%s\"", "th": "%s พูดกับฉันว่า \"%s\""},
	"mem_i_told": {"en": "I told %s: \"%s\"", "th": "ฉันบอก %s ว่า \"%s\""},
	"mem_approved": {"en": "%s approved my script for '%s' at the desk!", "th": "%s อนุมัติสคริปต์ '%s' ของฉันที่โต๊ะ!"},
	"mem_rejected": {"en": "%s sent my script for '%s' back for revision.", "th": "%s ส่งสคริปต์ '%s' กลับมาให้แก้"},
	"mem_guided": {"en": "%s helped me through a stuck %s stage: \"%s\"", "th": "%s ช่วยชี้ทางตอนขั้นตอน %s ติดขัด: \"%s\""},
	"mem_gossip_heard": {"en": "The %s told me: %s", "th": "%s เล่าให้ฟังว่า: %s"},
	"mem_gossip_chat": {"en": "Chatted with the %s on a break.", "th": "คุยเล่นกับ%sตอนพัก"},
	"mem_break": {"en": "Took a break (%s). It helped.", "th": "พักเบรก (%s) แล้วรู้สึกดีขึ้น"},
	"mem_trend": {"en": "Trend alert from the Director: %s.", "th": "ผู้กำกับแจ้งเทรนด์: %s"},
	"mem_espresso_down": {"en": "The espresso machine broke down. Morale wobbled.", "th": "เครื่องกาแฟพัง ขวัญกำลังใจสั่นคลอน"},
	"mem_espresso_up": {"en": "The espresso machine got fixed. Small victories.", "th": "เครื่องกาแฟซ่อมเสร็จแล้ว ชัยชนะเล็กๆ"},
	"mem_rush": {"en": "The Director warned us: the next reel is a rush job.", "th": "ผู้กำกับเตือนว่า งานรีลตัวต่อไปเป็นงานด่วน"},
	"mem_praise_about": {"en": " — about: %s", "th": " — เรื่อง: %s"},
	"mem_clip_routed": {"en": "%s sent real footage '%s' — I routed it to the edit bay.", "th": "%s ส่งฟุตเทจจริง '%s' มา — ฉันส่งต่อให้ห้องตัดต่อ"},
	"mem_clip_edited": {"en": "I transcribed and captioned %s's real clip '%s'.", "th": "ฉันถอดเสียงและทำแคปชันคลิปจริงของ %s เรื่อง '%s'"},
	# zone signs
	"z_reception": {"en": "RECEPTION", "th": "ต้อนรับ"},
	"z_director": {"en": "DIRECTOR", "th": "ผู้กำกับ"},
	"z_meeting": {"en": "MEETING", "th": "ห้องประชุม"},
	"z_library": {"en": "LIBRARY", "th": "ห้องสมุด"},
	"z_writers": {"en": "WRITERS", "th": "ทีมเขียน"},
	"z_focus": {"en": "FOCUS", "th": "โฟกัส"},
	"z_editbay": {"en": "EDIT BAY", "th": "ห้องตัดต่อ"},
	"z_studio": {"en": "STUDIO", "th": "สตูดิโอ"},
	"z_publishing": {"en": "PUBLISHING", "th": "ทีมเผยแพร่"},
	"z_coffee": {"en": "COFFEE", "th": "กาแฟ"},
	"z_lounge": {"en": "LOUNGE", "th": "เลานจ์"},
}

var lang := "en"
var ui_font: FontFile
var _bindings: Array = []


func _ready() -> void:
	ui_font = load("res://assets/fonts/Anuphan.ttf")
	if FileAccess.file_exists("user://ui_lang.txt"):
		var saved := FileAccess.get_file_as_string("user://ui_lang.txt").strip_edges()
		if saved in ["en", "th"]:
			lang = saved


func t(key: String) -> String:
	var entry: Dictionary = S.get(key, {})
	return str(entry.get(lang, entry.get("en", key)))


## Formatted template in the current language: I18n.f("mem_praised", [..]).
func f(key: String, args: Array) -> String:
	return t(key) % args


## Strip markdown for on-screen display (panels and bubbles show human
## text, not markup). Keeps the words, drops the syntax.
func strip_md(s: String) -> String:
	var out := s
	var re := RegEx.new()
	re.compile("```[a-z]*\\n?")            # code fences
	out = re.sub(out, "", true)
	re.compile("(?m)^#{1,6}\\s*")          # headers
	out = re.sub(out, "", true)
	re.compile("\\*\\*([^*]*)\\*\\*")      # bold
	out = re.sub(out, "$1", true)
	re.compile("(?m)^\\s*[-*]\\s+")        # list bullets -> dot
	out = re.sub(out, "• ", true)
	re.compile("\\[([^\\]]*)\\]\\([^)]*\\)")  # links -> text
	out = re.sub(out, "$1", true)
	out = out.replace("`", "").replace("*", "").replace("> ", "")
	return out.strip_edges()


## Bind a node property to a string key — set now, re-set on toggle.
func reg(node: Object, prop: String, key: String) -> void:
	node.set(prop, t(key))
	_bindings.append([weakref(node), prop, key])


func toggle() -> void:
	lang = "th" if lang == "en" else "en"
	var f := FileAccess.open("user://ui_lang.txt", FileAccess.WRITE)
	if f:
		f.store_string(lang)
	var alive: Array = []
	for b in _bindings:
		var node: Object = b[0].get_ref()
		if node:
			node.set(b[1], t(b[2]))
			alive.append(b)
	_bindings = alive
	changed.emit()
