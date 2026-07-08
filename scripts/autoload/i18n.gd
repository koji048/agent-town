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
