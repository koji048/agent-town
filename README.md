# Agent Town

An ambient isometric virtual office, built in **Godot 4**, where a crew
of AI agents produces short-form video content (Reels / TikTok / Shorts) for
real. The room is true 3D — white walls, glass partitions, real furniture,
soft shadows and ambient occlusion — viewed through an orthographic isometric
camera at full resolution. The agents are animated 3D chibi characters in
Ragnarok-style job classes — the Director is a Knight, the Researcher a Mage,
the Writer a hooded Rogue, the Editor a Rogue and the Publisher a Barbarian —
with real walk / work / cheer animations (KayKit Adventurers, CC0). Design rationale in
[docs/ISOMETRIC_STUDY.md](docs/ISOMETRIC_STUDY.md).

Drop a request file into a folder — the **Director** picks it up, writes a brief,
and cascades the work through **Researcher → Scriptwriter → Editor → Publisher**,
each powered by a live **Claude API** call. Agents walk to their workstations,
work at their desks, chat in speech bubbles, and the finished reel package lands
on your disk. No clicking required. You just watch the office live.

![Agent Town — 3D isometric office](docs/screenshot_3d.png)

The building is **"The Production Loop"** ([plan](docs/LAYOUT_PLAN.md)): a
rectangle wrapping a central courtyard garden, ringed by a racetrack
corridor — the floor plan IS the pipeline. A request enters at the
**reception intake wall** (NE), gets briefed in the **director's glass
office** (north, mural backdrop, sight line over the loop), travels the
quiet west band (**research library → writers' room → focus booths**) into
the south production band (**enclosed edit bay → green-screen studio →
publishing**), and returns up the social band (**coffee bar at the loop
midpoint, slat-screened relax lounge**) past the **courtyard amphitheater**,
where the crew celebrates every finished reel under the ALL-HANDS screen.
Agents wear MMO-style nameplates with live state pills, and stage
transitions pop `!` / `+` / `x` effects above their heads — ideas studied
from [BagIdea Office](https://github.com/bagidea/bagidea-office)
([notes](docs/BAGIDEA_STUDY.md)).

## How it works

```mermaid
flowchart LR
    Q[queue/pending/*.json] --> D1[Director\nplan]
    D1 --> R[Researcher\nhooks and facts]
    R --> W[Scriptwriter\ntimecoded script]
    W --> E[Editor\nSRT captions]
    E --> P[Publisher\ntitles and hashtags]
    P --> D2[Director\nfinal review]
    D2 --> O[output/timestamp_slug/]
```

Every stage is a real Claude call — through the **Claude Code CLI** (your
login, no separate API key) when installed, else the Anthropic API, else
canned demo text. The pipeline waits for each agent to physically walk to its workstation
before the call fires — the town state is the pipeline state.

| Agent | Workstation | Deliverable |
|---|---|---|
| Director | Glass office under the mural (north) | `00_plan.md`, `05_review.md` |
| Researcher | Research library (west quiet band) | `01_research.md` |
| Scriptwriter | Writers' room (pinned pages + a HIRING desk) | `02_script.md` |
| Editor | Enclosed edit bay (acoustic partition, 3 monitors) | `03_captions.srt` |
| Publisher | Publishing, beside the green-screen studio | `04_publish.md` |

The Editor follows the same caption rules as the `reels-pipeline` workflow:
~32 chars per caption, no mid-word breaks (Thai-aware), phrase-boundary
wrapping, blank during silence — so its SRT drops straight into an editor.

## Quick start

1. **Install Godot 4.3+** — download from [godotengine.org](https://godotengine.org/download) (no other dependencies needed to run).
2. **Clone and open**
   ```bash
   git clone https://github.com/<you>/agent-town.git
   ```
   Open the folder in Godot (Import → select `project.godot`) and press ▶.
3. **First run works instantly** — with no API key the town starts in **DEMO
   mode** (simulated content) and processes the included
   `queue/pending/welcome_reel.json` so you can watch the full cascade.
4. **Go live with Claude**
   ```bash
   cp user_config.example.cfg user_config.cfg
   # edit user_config.cfg and paste your Anthropic API key
   ```
   (or just set the `ANTHROPIC_API_KEY` environment variable). Restart the
   scene — the HUD shows `MODE: LIVE`.
5. **Feed the town** — drop a JSON file into `queue/pending/`:
   ```json
   {
     "topic": "วิธีตั้งกล้องถ่าย Reels ให้ดูโปร ด้วยมือถือเครื่องเดียว",
     "audience": "Beginner Thai creators",
     "duration_sec": 60,
     "platform": "Instagram Reels"
   }
   ```
   Only `topic` is required. Full schema in [`queue/README.md`](queue/README.md).

Results appear in `output/<timestamp>_<slug>/` — research notes, a timecoded
Thai/English script, caption-capped SRT subtitles, a publish package with
hashtags, and the Director's QC verdict.

## Configuration

`user_config.cfg` (gitignored — your key stays local):

| Key | Default | Meaning |
|---|---|---|
| `claude/provider` | `auto` | `auto` prefers the Claude Code CLI (your login), then API key, then demo |
| `claude/api_key` | — | Anthropic API key (or `ANTHROPIC_API_KEY` env var) — only needed without Claude Code |
| `claude/model` | `claude-sonnet-5` | Model for all agents |
| `claude/max_tokens` | `3000` | Max tokens per stage |
| `town/poll_interval` | `4.0` | Queue polling seconds |
| `town/simulate` | `false` | Force demo mode (no API calls) |
| `content/language` | Thai + EN hooks | Output language for the crew |
| `content/niche` | Education / how-to | The channel's niche |

Per-request `language` / `niche` fields override the config.

## Project layout

```
agent-town/
├── project.godot            Godot 4 project (pixel-perfect rendering)
├── scenes/main.tscn         Single scene — everything is built in code
├── scripts/
│   ├── autoload/            Config, EventBus, Claude client, queue, writer
│   ├── pipeline.gd          The boss→subagent cascade
│   ├── prompts.gd           System prompts per role
│   ├── office_3d.gd         3D office builder + A* pathfinding
│   ├── agent_3d.gd          Billboard agent FSM: wander / walk / work / speak
│   └── main.gd              Boot, ortho camera, lighting, HUD
├── assets/                  Generated 16-bit pixel art + map.json
├── tools/generate_assets.py Deterministic art generator (Pillow)
├── tools/ci_check.gd        Headless validation (used by CI)
├── queue/                   pending/ → processing/ → done/
└── output/                  Finished reel packages
```

## Sound & liveness

The office is foley'd procedurally — keyboard clatter while agents work,
footsteps that change with the floor material (carpet / wood / concrete /
grass), chair scrapes, paper shuffles, HVAC room tone, courtyard birds,
and a soft chime + confetti reserved for the publish celebration. Agents
carry their deliverable as a physical document to the next desk, finished
pages pile up on desks, and the reception **kanban wall is live**: one
card per request slides column to column as the real pipeline advances,
with pending requests waiting as gray cards. All sounds are synthesized
deterministically by `tools/generate_assets.py` (no external audio
assets). Design rationale: [docs/CREATIVE_DIRECTION.md](docs/CREATIVE_DIRECTION.md).

## Regenerating the art

All sprites, the campus map, and the README preview are generated by one
deterministic script — tweak the palette or map layout and re-run:

```bash
pip install pillow
python3 tools/generate_assets.py
```

## Controls

Pan with WASD / arrow keys, zoom with the mouse wheel, and press **C** for
the costume panel — per-agent class, headgear, hand items, bracers and cape,
with one-click **Office** and **Adventure** presets (saved to
`user://costumes.json`). Everything else is ambient — the town runs itself.

## CI

GitHub Actions validates every push with headless Godot 4.6: regenerates the
assets, imports resources, loads every script and scene, and verifies the map.

## Roadmap ideas

- Live web research for the Researcher (search API tool use)
- Hand-off to a rendering pipeline that burns the SRT into a vertical video
- Multiple concurrent requests with a visible task board in the atrium
- More crew: Analyst agent reading post performance and pitching topics

## Credits

Furniture from [KayKit Furniture Bits](https://github.com/KayKit-Game-Assets/KayKit-Furniture-Bits-1.0)
and characters from the
[KayKit Adventurers pack](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0)
(both CC0 by Kay Lousberg), with tech and kitchen props from the
[Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit) (CC0) —
all loaded at runtime from `assets/models/`.
UI typeface: [Anuphan](https://fonts.google.com/specimen/Anuphan)
(SIL Open Font License) — the interface toggles Thai/English live.
Textures, audio and the map are generated by `tools/generate_assets.py`.

## License

[MIT](LICENSE)
