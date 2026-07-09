# Agent Town — Command Interface UX Audit

*Reviewer stance: strategy/management-game UX. Benchmarks: RimWorld
(order queues visible on the pawn's inspect pane; every order
revocable), The Sims (direct manipulation + queued intents shown as
icons), Two Point Hospital (room/staff assignment always inspectable),
and the "juice" doctrine (every input earns a response within ~100 ms;
toasts linger 2–5 s).*

## Ratings

| Area | Score | Evidence |
|---|---|---|
| Command input (multi-modal) | **8/10** | Chat-to-Director with intent detection, idea pin, drag-drop video onto the window, AirDrop watcher, praise/coach per agent. Rich and genuinely novel. |
| Input acknowledgement | **7/10** | Pop FX, sounds, director replies — but between "send" and the director's LLM reply there are silent seconds with no typing indicator on the command path. |
| Job status display | **8/10** | PM board with %, PIC, filters, project list; overhead progress bars; follow-up answers in chat; overdue watchdog self-reports. Best-in-class for this genre slice. |
| **Delegation flow visibility** | **4/10** | The killer gap. When the Director hands work to the Writer, the human sees *implicit* signals (agent walks, kanban card moves) but never the handoff itself: no Director→Writer moment, no pipeline map showing where the baton is and where it goes next. RimWorld's rule: queued/assigned work must be *inspectable as a chain*, not inferred. |
| Job control (cancel/pause) | **3/10** | No way to cancel or pause a running job from the UI. Strategy-game table stakes: every order must be revocable (RimWorld cancel designation). Only post-delivery revision exists. |
| Copy & learnability | **5/10** | HUD idle text says "drop a .json into queue/pending/" — engineering jargon leaking into the player surface. No first-run hints. |
| Legibility / a11y | **7/10** | Anuphan Thai type, outlines, big bars — good. Some in-world labels still small at default zoom. |

**Overall: 6.5/10** — world-class *observability*, mid-tier *control*,
weak *flow storytelling*.

## Improvement plan (priority order)

### P1 — Show the delegation flow (the assignment brief's core ask)
1. **Pipeline strip per project**: 6 nodes (วางแผน → ค้นคว้า → เขียน →
   ตัดต่อ → เผยแพร่ → ตรวจ) with the PIC's role color, active node
   pulsing, % beneath, checkmarks behind. Lives on the PM-board card
   (expanded) and as a compact strip under the HUD NOW line.
2. **Visible handoff beat in the world**: on `stage_started`, the
   previous PIC walks the work doc to the next PIC (or the doc flies
   with a trail), plus a chat-feed system line: "ผู้กำกับ → ทีมเขียน:
   มอบหมายสคริปต์ 'X'". The org chart becomes something you *watch*.

### P2 — Order revocation
Cancel (and pause) per project from the PM board card. Pipeline checks
a cancel flag between stages; in-flight CLI call finishes, then the job
folds gracefully with a chronicle entry.

### P3 — Humanize the player surface
Idle HUD copy → "ว่าง — คุยกับผู้กำกับ, ปักไอเดีย หรือลากคลิปมาวางได้เลย".
NOW line → one chip per parallel job (3 max), not a single line.

### P4 — Close the input-ack gap
Instant paper-rustle + "รับเรื่องแล้ว กำลังอ่าน..." bubble the moment a
chat message or idea is submitted, before the LLM responds.

### P5 — First-run coach marks
Three dismissable hints on first boot: chat button, board button, drag-
drop zone. Fade forever after one use each (UI-fade doctrine).

## Sources
- RimWorld order-queue conventions: rimworldwiki.com/wiki/Orders, /wiki/Work
- Feedback-timing & juice: uichallenges.design guide, gameuidatabase.com
  (Maintenance & Management pattern set), justinmind.com game-UI principles
