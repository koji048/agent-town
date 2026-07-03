# BagIdea Office — study notes

Study of [bagidea/bagidea-office](https://github.com/bagidea/bagidea-office)
("a living 2.5D Claude Office that runs as your desktop wallpaper", by
BAGIDEA INNOVATION CO., LTD., Thailand) — what it gets right architecturally,
and what Agent Town should adopt from it.

## What it is

A Windows-11 desktop-wallpaper office where Claude agents are pixel-art
employees. Real Claude Code sessions (headless `claude -p`) drive the world:
agents walk to desks when work starts, walk to a Security desk when they need
an ungranted tool, hold meetings, split into "ghost" sub-agents, propose their
own projects, and learn skills over time. Renderer is Godot 4 in HD-2D style —
the same 3D-room + billboarded-pixel-sprites approach Agent Town uses.

## The big architectural lesson: truth lives outside the renderer

BagIdea is **three independent processes**:

```
overlay (web UI)  ⇄  DAEMON (Node, WS hub)  ⇄  Godot renderer
                      • journal.jsonl (event log, replayed on connect)
                      • registry.json (the staff)
                      • spawns real `claude -p` sessions
```

Their phrase: *"Truth lives in the daemon; the world is a renderer of truth."*
The renderer can crash and rebuild the entire world state from the journal.
The daemon keeps agents working even if rendering dies.

Agent Town currently runs everything inside Godot (EventBus + pipeline in
GDScript). That's simpler, but it means: no state survival across restarts, no
external UI, nothing else can feed the world, and the office only works while
the game window runs.

## The event protocol is the whole integration story

One JSON shape (`{type, agent, task?, tool?, text?, ts}`) over one WebSocket.
Everything — Claude sessions, hooks from the user's own Claude Code work,
custom scripts, `curl` — can `POST /event` and the world reacts. Event types
map 1:1 to choreography (`task.started` → walk to desk; `perm.requested` →
walk to Security; `subagent.split` → ghost clones ascend to the Ghost Deck).

Agent Town's EventBus signals are already shaped like this
(stage_started/stage_completed ≈ task.started/task.completed) — they're just
trapped inside the process.

## Claude Code CLI instead of raw API

BagIdea does not call the Anthropic API directly. It spawns **headless Claude
Code** (`claude -p`, stream-json, `--resume` for persistent threads) with a
persona, a skills list and a tool allowlist per agent. Wins:

- Uses the user's existing Claude Code login/plan — no separate API key
- Tools for free: agents read/write real files, run commands, work *inside
  real project folders* with resumable sessions
- `PreToolUse` hooks become the **spatialized permission system**: the hook
  long-polls the daemon until the human clicks Allow/Deny in the overlay —
  meanwhile the character visibly waits at the Security desk
- Protocol-in-text conventions parsed from replies: `DELEGATE: <agent> @
  <project> :: <job>` (cascade), `SUB: <job>` (parallel ghost clones),
  `PROJECT:` (self-created projects) — the same cascade idea as Agent Town's
  Director, but expressed as lines the model writes, so delegation is dynamic
  rather than a fixed pipeline

## World-design ideas worth stealing

- **Day/night follows the real local clock** — sunset ~17:00, lights at night;
  manual override for screenshots. Cheap, huge "alive" factor.
- **Swappable room grid**: rooms are identical jigsaw cells; furniture, agent
  anchors and the nav graph move when rooms swap. (Agent Town's map.json is
  one step away from this.)
- **Nameplates**: MMO-style HUD plates — portrait, role, live state pill
  (IDLE/WORKING/MEETING/BLOCKED/OFFLINE), rank dressing for boss tiers.
- **Event FX flipbooks**: ✅ on completion, ❗ at security, 🎵 while speaking,
  golden burst on a learned skill — tiny sprites, big legibility.
- **Idle society**: idle agents gather in the cafeteria, chat, and sometimes a
  conversation crystallizes into a written project proposal the human
  approves/rejects. Ambience that occasionally produces real work.
- **Honesty contract** (from their design docs): *nothing tagged is fake* —
  every visual state maps to a true system state. Mission board cards, the
  lobby "daemon connected" totem — truth, not decoration.
- **Ghost Deck**: sub-agent parallelism made visible — translucent clones work
  on a floating platform, then dissolve back into their owner.

## Gap analysis: Agent Town vs BagIdea Office

| Dimension | Agent Town (now) | BagIdea Office |
|---|---|---|
| Renderer | Godot 4, 3D iso + pixel billboards ✓ same idea | + IBL, SSR floors, tilt-shift, day/night |
| Brain | Anthropic API from GDScript | headless Claude Code sessions w/ tools |
| Truth | inside the Godot process | daemon + journal + registry (replayable) |
| Cascade | fixed 6-stage pipeline | dynamic `DELEGATE:` graph + sub-agent `SUB:` |
| Permissions | n/a (no tools) | spatialized security desk, hook-driven |
| Input | queue folder (ambient) ✓ | chat, CLI, Telegram/LINE/Discord, voice |
| Persistence | output files only | threads, memory files, skills, journal |
| Platform | macOS window | Windows wallpaper (WorkerW) |

## Adoption plan (ranked, each independently shippable)

1. **Day/night cycle from the real clock** — light direction/color/energy
   driven by `Time.get_time_dict_from_system()`. Small, transformative.
2. **Nameplates + event FX** — role/state plates above agents; ✅/❗ pops on
   stage transitions. Makes the pipeline legible at a glance.
3. **Daemon split**: move TaskQueue/Pipeline/Claude calls into a small
   zero-dep Node (or Python) daemon with `journal.jsonl` + WebSocket; Godot
   keeps only choreography. Unlocks 4–6.
4. **Claude Code adapter**: spawn `claude -p` per stage instead of raw API —
   agents gain real tools and the user's login; enables working inside real
   project folders (e.g. the reels-pipeline production tree).
5. **Claude Code hooks → office**: the user's own coding sessions animate the
   Director's desk. One PostToolUse hook posting to the daemon.
6. **Dynamic delegation**: let the Director's reply contain `DELEGATE:` lines
   parsed into real stages, replacing the fixed pipeline order.
7. **macOS wallpaper mode** — BagIdea lists macOS as unshipped ("planned");
   a borderless always-on-bottom window under desktop icons is the closest
   sanctioned approach on macOS. Genuinely hard; lowest priority.

## Sources

- [bagidea/bagidea-office README](https://github.com/bagidea/bagidea-office)
- [Plugin template](https://github.com/bagidea/bagidea-office-template) ·
  [calculator plugin](https://github.com/bagidea/bagidea-office-calculator-plugin) ·
  [music player plugin](https://github.com/bagidea/bagidea-office-music-player-plugin)
- [BAGIDEA on GitHub](https://github.com/bagidea) ·
  [Thanawat Suriya on LinkedIn](https://www.linkedin.com/in/bagidea/)
