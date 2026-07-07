# Agent Town — product roadmap

Target vision (from the owner's spec): *instead of typing at an AI in a
chat box, you walk around a 3D office, give work to a team of agents in
plain language, and real deliverables come back — code, articles, images,
video, reports.*

## Where we are today

A Godot 4 diorama office (L-shape + courtyard + Google-style town hall)
where five fixed agents (Director/Knight → Researcher/Mage →
Writer/Rogue → Editor/Rogue → Publisher/Barbarian) run a fixed 6-stage
Reels pipeline through direct Anthropic API calls, fed by a JSON queue
folder. Costume system, gathering behavior, CI on every push. Truth
lives inside the Godot process.

## Architecture target (the production-grade shape)

Adopted from the BagIdea study (docs/BAGIDEA_STUDY.md): **truth lives in
a daemon; the world is a renderer of truth.**

```
┌─ Web/overlay UI ──────────┐      ┌─ Godot renderer ──────────────┐
│ chat · threads · kanban   │      │ office · agents · choreography │
│        ▲ WebSocket        │      │        ▲ WebSocket             │
└────────┼──────────────────┘      └────────┼───────────────────────┘
┌────────┴───────────────────────────────────┴──────────────────────┐
│ DAEMON (Node, zero-dep)                                            │
│ • event journal (replay on connect) • agent registry (roles/skills)│
│ • provider adapters: claude-code CLI · Anthropic API · (more CLIs) │
│ • queue + jobs + threads + permission broker                       │
└────────────────────────────────────────────────────────────────────┘
```

## Phases

### Phase 1 — Production brain (foundation)
| Feature (spec) | How | Size |
|---|---|---|
| BYOK + multiple CLI providers 🔌 | Provider abstraction in the daemon: `claude-code` (headless `claude -p`, stream-json, `--resume`) as primary — uses the owner's login, no API billing split; `anthropic-api` and `simulate` as fallbacks; config per agent | M |
| Real skills that trigger per job | Claude Code runs with per-agent persona + skill files + tool allowlist; skills live in `agents/<role>/skills/` | M |
| Daemon split + journal + registry | Node daemon owning queue/pipeline/threads; Godot becomes a WS client that renders events; state survives restarts | L |

### Phase 2 — The walkable office
| Feature (spec) | How | Size |
|---|---|---|
| Walk the office 🕹 (WASD/click-move) | Player avatar (6th character), click-to-move via the existing A* grid, camera follow | M |
| Click an agent to talk 💬 | Proximity + click → chat panel bound to that agent's thread | M |
| Org chart + auto-cascade 🧭 | Director replies may contain `DELEGATE: <agent> :: <job>` lines parsed into real dispatches (replaces the fixed pipeline); org tree in registry | M |
| Thai/English full 🌏 | String table for all UI/HUD; content language already per-request | S |

### Phase 3 — A real team
| Feature (spec) | How | Size |
|---|---|---|
| Hire 14 tracks / 60 roles 🧑‍💼 | Role catalog (title, persona, skills, tools, model choice); hire/fire UI; desks assigned dynamically from a pool; KayKit + more CC0 packs for looks | L |
| Multi-conversation per agent + context compression | Named resumable threads per agent (`--resume`); rolling summary memo per thread (Hermes-style memory from the BagIdea study) | M |
| In-world Kanban 🗂 | Board mesh in the office mirroring daemon tasks (pending/in-progress/done cards); the same data drives a web board | M |

### Phase 4 — Real work surfaces
| Feature (spec) | How | Size |
|---|---|---|
| Developer agents in real projects (git worktree + review gate) | Each dev job runs `claude -p` inside a per-task `git worktree`; finished diffs go to a review queue; human Approve = merge/push, Reject = feedback loop. Never direct-to-main | L |
| Multiple rooms/maps + decoration 🎨 | Map registry (office/cafe/rooftop/trading floor as map.json variants); the costume-panel pattern generalized to a room decorator | L |

### Phase 5 — Verticals
| Feature (spec) | How | Size |
|---|---|---|
| Video → TikTok (draft) 🎬 | Bridge to the owner's reels-pipeline: Editor's SRT + script → burn pipeline → TikTok draft upload via API; human approves before post | L |
| Trading room (paper trade) 📊 | Analyst agents + market data feed; positions ledger is strictly paper; human-only execution by design | M |

## Production-grade engineering track (parallel)
- Versioned releases (`VERSION` file), self-update check, one-shot installer
- Test suite: daemon unit tests + headless Godot smoke tests (extend ci_check)
- Permission broker for tool approvals (spatialized: agent walks to a
  security desk — already designed in BAGIDEA_STUDY notes)
- Crash-safe: journal replay proves the renderer can die freely

## Order of attack (recommended)
1. Phase 1 provider adapter (`claude-code` CLI) inside the current Godot
   app — smallest change with the biggest capability jump
2. Daemon split once the adapter works
3. Phase 2 player + click-to-chat (makes it a *product*, not a diorama)
4. Then 3 → 4 → 5 in order

## Prerequisites on the owner's machine
- Install Claude Code CLI (`npm install -g @anthropic-ai/claude-code`) and
  run `claude` once to log in — required for Phase 1's primary provider.
