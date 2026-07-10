## Thai/English UI toggle. All chrome strings live here; nodes register
## and are re-labeled live on toggle. UI font: Anuphan (SIL OFL, Thai +
## Latin) — assets/fonts/. Agent-generated CONTENT keeps its own
## language (that's the content config, not the chrome).
extends Node

signal changed

const S := {
	"hud_title": {"en": "AGENT TOWN — virtual office", "th": "AGENT TOWN — ออฟฟิศเสมือน"},
	"status_idle": {"en": "Idle — chat with the Director, pin an idea, or drop a clip anywhere", "th": "ว่าง — คุยกับผู้กำกับ ปักไอเดีย หรือลากคลิปมาวางได้เลย"},
	"role_director": {"en": "Director", "th": "ผู้กำกับ"},
	"role_researcher": {"en": "Researcher", "th": "ทีมค้นคว้า"},
	"role_writer": {"en": "Writer", "th": "ทีมเขียน"},
	"role_editor": {"en": "Editor", "th": "ทีมตัดต่อ"},
	"role_publisher": {"en": "Publisher", "th": "ทีมเผยแพร่"},
	"handoff_line": {"en": "→ hands '%s' to %s (%s)", "th": "→ ส่งงาน '%s' ต่อให้%s (ขั้น%s)"},
	"job_cancelled": {"en": "Understood — '%s' is cancelled, no hard feelings.", "th": "รับทราบครับ ยกเลิกงาน '%s' เรียบร้อย"},
	"btn_cancel_job": {"en": "✕ Cancel", "th": "✕ ยกเลิกงาน"},
	"btn_archive": {"en": "Archive", "th": "เก็บเข้าคลัง"},
	"btn_scope": {"en": "Change scope", "th": "ปรับ scope"},
	"prompt_scope": {"en": "New direction for this job (applies to every remaining stage)", "th": "ทิศทางใหม่ของงานนี้ (มีผลกับทุกขั้นที่เหลือ)"},
	"say_scope": {"en": "Scope updated: %s — the rest of the line will follow it.", "th": "รับทราบ ปรับ scope: %s — ขั้นที่เหลือจะยึดตามนี้ครับ"},
	"ack_thinking": {"en": "One sec — let me think...", "th": "ขอคิดแป๊บนึงครับ..."},
	"ack_idea": {"en": "Idea received — we'll pick it up shortly! 📌", "th": "เห็นไอเดียแล้วครับ เดี๋ยวทีมหยิบขึ้นมาทำ 📌"},
	"hint_title": {"en": "Three ways to run this office", "th": "สั่งงานออฟฟิศนี้ได้ 3 ทาง"},
	"hint_body": {"en": "💬 Chat — click any agent and talk (the Director takes commissions)\n📌 New idea — pin a topic for the team\n🎬 Drop a video anywhere for subtitles + a cut", "th": "💬 แชท — คลิกตัวละครแล้วพิมพ์คุย (สั่งงานผ่านผู้กำกับ)\n📌 ไอเดียใหม่ — ปักหัวข้อให้ทีมทำ\n🎬 ลากวิดีโอมาวางตรงไหนก็ได้ เดี๋ยวได้ซับ+คลิปตัด"},
	"btn_got_it": {"en": "Got it", "th": "เข้าใจแล้ว"},
	"side_board": {"en": "  Board", "th": "  บอร์ดงาน"},
	"side_chat": {"en": "  Team chat", "th": "  แชททีม"},
	"side_team": {"en": "  Team", "th": "  ทีมงาน"},
	"side_system": {"en": "  System", "th": "  ระบบ"},
	"side_build": {"en": "  Build mode", "th": "  จัดห้อง"},
	"build_hint": {"en": "BUILD: click a piece to pick it up · move mouse · R rotate · click to set down · Esc cancel", "th": "จัดห้อง: คลิกของเพื่อหยิบ · เลื่อนเมาส์ · R หมุน · คลิกวาง · Esc คืนที่เดิม"},
	"side_done": {"en": "  Deliverables", "th": "  งานที่เสร็จ"},
	"side_settings": {"en": "  Settings", "th": "  ตั้งค่า"},
	"team_panel_title": {"en": "TEAM — grow your people", "th": "ทีมงาน — ดูแลและพัฒนาทีม"},
	"team_xp": {"en": "%d memories · bond %d%%", "th": "ประสบการณ์ %d เรื่อง · สนิทกับคุณ %d%%"},
	"team_note": {"en": "Coaching writes into an agent's memory and changes future work — that IS the skill system today. Praise deepens the bond.", "th": "การ 'สอนงาน' จะฝังเข้าความจำและเปลี่ยนวิธีทำงานครั้งถัดไป — นี่คือระบบอัปสกิลปัจจุบัน ส่วนการชมช่วยเพิ่มความสนิท"},
	"btn_dress": {"en": "Dress", "th": "แต่งตัว"},
	"sys_title": {"en": "SYSTEM — the real flow", "th": "ระบบ — งานที่วิ่งจริง"},
	"sys_none": {"en": "No jobs in flight.", "th": "ตอนนี้ไม่มีงานวิ่งอยู่"},
	"sys_tokens": {"en": "Tokens spent:", "th": "โทเคนที่ใช้:"},
	"sys_fps": {"en": "FPS", "th": "FPS"},
	"sys_uptime": {"en": "· up", "th": "· เปิดมา"},
	"sys_min": {"en": "min", "th": "นาที"},
	"sys_display": {"en": "Display:", "th": "จอแสดงผล:"},
	"sys_on": {"en": "on", "th": "ทำงาน"},
	"sys_off": {"en": "sleeping (background)", "th": "พัก (อยู่เบื้องหลัง)"},
	"set_title": {"en": "SETTINGS", "th": "ตั้งค่า"},
	"set_lang": {"en": "Language", "th": "ภาษา"},
	"set_charset": {"en": "Character set", "th": "ชุดตัวละคร"},
	"set_office": {"en": "Office branches", "th": "สาขาออฟฟิศ"},
	"office_current": {"en": "● Reels Studio (current)", "th": "● สตูดิโอ Reels (ปัจจุบัน)"},
	"office_soon1": {"en": "○ Marketing Agency — coming soon", "th": "○ เอเจนซี่การตลาด — เร็วๆ นี้"},
	"office_soon2": {"en": "○ Newsroom — coming soon", "th": "○ ห้องข่าว — เร็วๆ นี้"},
	"studio_title": {"en": "🎬 CAPTION REVIEW STUDIO — check every line before the burn", "th": "🎬 ห้องตรวจซับ — เช็คทุกบรรทัดก่อนเผาลงคลิป"},
	"studio_hint": {"en": "Click a line to jump · drag the timeline to scrub · edit below and save", "th": "คลิกบรรทัดเพื่อกระโดดไปฟัง · ลาก timeline เลื่อนดู · แก้ข้อความด้านล่างแล้วบันทึก"},
	"studio_font": {"en": "Font", "th": "ฟอนต์"},
	"studio_size": {"en": "Size", "th": "ขนาด"},
	"studio_color": {"en": "Colour", "th": "สี"},
	"btn_save_cue": {"en": "✏ Save this line (writes the real .srt)", "th": "✏ บันทึกบรรทัดนี้ (เขียนลง .srt จริง)"},
	"btn_burn_custom": {"en": "🔥 Burn — exactly what you see", "th": "🔥 Burn ตามที่เห็นบนจอ"},
	"studio_auto": {"en": "No touch: burns the current look in %d s", "th": "ไม่กดอะไร จะ burn ตามที่ตั้งไว้ใน %d วิ"},
	"say_studio": {"en": "Captions are up for your check, %s — in the studio!", "th": "ซับพร้อมให้ตรวจแล้วครับ %s — เชิญที่ห้องตรวจซับ!"},
	"tv_intake": {"en": "🎬 ON AIR — footage coming in...", "th": "🎬 ON AIR — รับคลิปเข้าห้องตัด..."},
	"tv_cutting": {"en": "🎬 ON AIR — cutting EP%d", "th": "🎬 ON AIR — กำลังตัด EP%d"},
	"tv_done": {"en": "✓ EP%d shipped — check 05_EXPORTS", "th": "✓ EP%d เสร็จแล้ว — ไฟล์อยู่ใน 05_EXPORTS"},
	"tv_done_plain": {"en": "✓ Clip shipped", "th": "✓ คลิปเสร็จแล้ว"},
	"dock_command": {"en": "  Brief the Director  ", "th": "  สั่งงานผู้กำกับ  "},
	"prompt_command": {"en": "Talk to the Director — a real commission queues automatically", "th": "พิมพ์คุยกับผู้กำกับได้เลย — ถ้าเป็นงาน ทีมจะรับเข้าคิวอัตโนมัติ"},
	"btn_costumes": {"en": "  Costumes  ", "th": "  ตัวละคร  "},
	"btn_idea": {"en": "  New idea  ", "th": "  ไอเดียใหม่  "},
	"btn_deliver": {"en": "  Deliverables  ", "th": "  งานที่เสร็จ  "},
	"btn_board": {"en": "  Board  ", "th": "  บอร์ดงาน  "},
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
	# inner-voice lines (thoughts): no addressee -> no polite particles
	"say_plan": {"en": "new job... brief first", "th": "งานใหม่เข้า... ร่างบรีฟก่อนละกัน"},
	"say_research": {"en": "where are the hooks in this...", "th": "ฮุคของเรื่องนี้อยู่ตรงไหนนะ..."},
	"say_script": {"en": "okay, this script wants to be good", "th": "เอาละ สคริปต์นี้ต้องปัง"},
	"say_edit": {"en": "trim these captions tight...", "th": "ตัดแคปชันให้เป๊ะกว่านี้..."},
	"say_publish": {"en": "package it up for posting...", "th": "แพ็กของเตรียมโพสต์..."},
	"say_review": {"en": "one last quality pass...", "th": "ตรวจอีกรอบให้ชัวร์..."},
	"say_onit": {"en": "right, let's do this", "th": "เอาละ ลุย"},
	"say_fail": {"en": "ugh... that one slipped", "th": "พลาดจนได้... เซ็งเลย"},
	"say_thanks": {"en": "Thanks, %s!", "th": "ขอบคุณครับ %s!"},
	"say_noted": {"en": "Noted, %s.", "th": "รับทราบครับ %s"},
	"say_chat_sim": {"en": "Good to see you, %s! Heads-down today, but ask me anything.", "th": "ดีใจที่แวะมาครับ %s! วันนี้งานแน่นแต่ถามได้เลย"},
	"say_lost": {"en": "Sorry %s — lost my train of thought there.", "th": "ขอโทษครับ %s — เมื่อกี้หลุดโฟกัสไปแป๊บ"},
	"say_greet": {"en": "Morning, %s! Good to have you in the office.", "th": "สวัสดีครับ %s! ดีใจที่เข้ามาที่ออฟฟิศนะครับ"},
	"say_meeting": {"en": "Team huddle! New job: '%s'", "th": "ประชุมด่วน! งานใหม่: '%s'"},
	"say_intent": {"en": "My reading of your brief: %s — correct me if I'm off!", "th": "ผมตีความโจทย์ว่า: %s — ถ้าคลาดเคลื่อนทักมาได้เลยครับ"},
	"say_overdue": {"en": "'%s' is taking longer than usual — on it, sorry!", "th": "งาน '%s' ช้ากว่าปกติ กำลังเร่งอยู่ครับ ขอโทษด้วย!"},
	# short stage names for the overhead status chip
	"stg_plan": {"en": "brief", "th": "บรีฟ"},
	"stg_research": {"en": "research", "th": "วิจัย"},
	"stg_script": {"en": "script", "th": "เขียน"},
	"stg_edit": {"en": "edit", "th": "ตัดต่อ"},
	"stg_publish": {"en": "publish", "th": "เผยแพร่"},
	"stg_review": {"en": "review", "th": "ตรวจ"},
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
	"btn_chat_feed": {"en": "  Team chat  ", "th": "  แชททีม  "},
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
