# Agent Town — Creative Direction

*Chief Creative Director's bible. Built from three benchmark studies:
agent-simulation AI, game craft, and AI-work UX. Every claim below is
grounded in a named best-in-class exemplar; sources at the end.*

## Vision

**The first agent simulation where the drama is real.**

Every celebrated agent sim fakes the work: Smallville's agents plan
parties, The Sims cook imaginary dinners, ChatDev's "company" is a
terminal log. Agent Town's crew ships real content — real research,
real Thai scripts, real SRT files, real publish packages. Nobody else
holds that card. The direction, therefore: wrap the believability
architecture of Stanford's Generative Agents, the legibility of The
Sims, the pacing of RimWorld's storyteller, and the craft of Unpacking
around a pipeline whose output you can post to Instagram.

In one line: **RimWorld's pacing around a ChatDev pipeline, rendered
like The Sims, foley'd like Unpacking.**

## The five pillars

### 1. Real work, made visible
The differentiator. Work must have a body: briefs, drafts, redlines and
SRTs as physical objects agents carry between desks (MetaGPT's typed
artifacts + CrewAI's role handoffs as theater). The INTAKE wall becomes
a live kanban driven by actual queue state. Finished packages accrete
into shelves and a courtyard skyline (GitHub Skyline: data
physicalization = pride objects). AI Village proved people watch real
agent work for hours when stakes are real and artifacts are visible.

### 2. Alive, not scripted
Smallville's three-layer architecture at 5-agent depth: a memory stream
per agent (recency × importance × relevance retrieval), nightly
reflection that turns events into opinions, and plans decomposed to
5-15 minute visible actions. The Sims' decaying needs + smart objects
(the espresso machine advertises Energy) guarantee zero idle standing
at zero LLM cost. Water-cooler gossip diffuses real pipeline news
between agents. Relationships persist: the Writer remembers the
Editor's third rejection.

### 3. Calm craft (audio first)
The unanimous verdict of the craft study: **a silent diorama is a
screenshot; a foley'd diorama is a place.** Unpacking shipped 14,000
foley files for a zen game. Priority order: contact foley (keyboards,
chairs, footsteps-per-material, paper) → positional walla + room tone →
Animal Crossing-style time-of-day music stems with silence gaps. Then
the soft half of juice doctrine: everything eases (never pops), squash
on spawns, permanence (desks accumulate cups and stickies) — and
screenshake/hitstop reserved for exactly one event: the publish
celebration, at 10% action-game intensity.

### 4. Legible trust
Devin/Claude Code lessons in diegetic form. Honest status states:
working (green), needs-input (agent walks toward camera with a "?"),
failed (smoke, slumped posture, error one click away) — never a silent
stall. Every speech bubble quotes REAL output, clickable down to the
actual artifact (LangSmith's rule: every behavior drills to ground
truth). Cost as a diegetic instrument: a spinning electric meter during
API calls, per-agent daily spend on the nameplate, end-of-day invoice.
An approval desk where work physically waits at designed checkpoints
(plan approval, pre-publish) — a place, not a popup.

### 5. Drama, paced
RimWorld's insight: agents shouldn't schedule the drama; a storyteller
should. A director node (not an agent) injects events on a tension
curve scaled to recent success — revision demands, trend alerts, tool
outages — followed by *enforced calm* so moments land. Every named
event enters a Dwarf Fortress-style chronicle; milestones spawn
permanent props (framed EP posters, amphitheater plaques). Failure is
content: retries and escalations are dramatized, not hidden
(TheAgentCompany: ~30% long-horizon completion is normal — design for
it).

## Scorecard vs. world class (honest, July 2026)

| Discipline | World-class bar | Agent Town today | Grade |
|---|---|---|---|
| Pipeline realness | AI Village: real stakes, real output | Live Claude Code, real packages on disk | **A−** |
| Environment art | Two Point readability + archviz | Researched materials/lighting, Production Loop plan, modern furniture | **B** |
| Work legibility | Devin panes, live task lists | Stages visible, static kanban, no artifacts/costs/approval | **C** |
| Presentation | Cities:Skylines cinematic, tilt-shift | Good stills; static camera, no DoF, no day drama | **C+** |
| Juice / feel | Tiny Glade tactility | Pop FX + cheer only; things appear without easing | **C−** |
| Agent believability | Smallville memory/reflection | Random wander, no memory, no needs, no gossip | **D+** |
| Drama & pacing | RimWorld storyteller | Pipeline order only; no events, no chronicle | **D** |
| Audio | Unpacking: 14k foley files | **None** | **F** |

### 6. The human is a character (added after the human-interaction study)

The first five pillars treat the viewer as an operator. The research
says the deepest attachment comes from being a *participant*:

- **Mixed initiative** (Horvitz lineage): when the system can't resolve
  ambiguity safely, a short clarifying question beats a confident wrong
  answer. Initiative must flow BOTH ways — agents should sometimes ask
  the human, not only wait to be told. Autonomy is a dial, not a switch;
  interventions must be low-friction and reversible.
- **Majesty's law**: influence through incentives, never commands. The
  human pins weighted topic cards; the Director decides — in character.
- **Black & White's law**: teach through feedback on outcomes (praise /
  scold after the fact), and the creature *remembers being taught*.
  Feedback works because it lands on a specific recent action.
- **Animal Crossing's law**: presence. Villagers know the player exists,
  greet them, reference them when they're away. The strongest documented
  player-character relationship type is *nurturing* (~42% of players) —
  guardian-role attachment to characters whose growth you're
  responsible for.
- **Tamagotchi effect**: attachment forms toward named individuals with
  visible needs whose wellbeing responds to your care.

Agent Town translation: the human (the owner, by name) is a member of
this studio — greeted on arrival, asked real clarifying questions when
stages are ambiguous or failing, able to praise or coach any agent
about the thing they just did (which becomes a memory and shapes
affinity toward the OWNER, a sixth node in the relationship graph), and
able to chat in natural language with any agent who answers from their
actual memories. The keyboard appears exactly where it should: when the
human has something to say.

## Commissioned sprints

*Status: Sprints 1-4 shipped (audio/juice/kanban/artifacts; memory/
needs/gossip/relationships; storyteller/chronicle/event camera;
approval desk/cost meter/day-night/LLM gossip) plus interactivity and
UI-legibility passes. Scorecard: no discipline below B−.*

**Sprint 5 — "The human joins the town" (from the interaction study)**
1. Click-to-chat: click an agent → typed message → in-character reply
   built from their real memories, needs, and relationships; the
   exchange is remembered by the agent (both directions of initiative)
2. Owner presence: the owner is a named sixth character in the
   relationship graph; agents greet them at boot, reference them in
   gossip, and remember approvals/rejections as coming from THEM
3. Praise / coach buttons on the inspector card, targeting the agent's
   most recent action (Black & White: feedback lands on outcomes) —
   praise lifts mood + owner affinity; coaching writes a corrective
   memory that colors the next same-stage prompt
4. The ideas corkboard: pin topic cards with a priority weight in-world
   instead of dropping JSON files (Majesty: incentives, not commands);
   the Director picks up cards in character
5. Agents ask back: on stage failure or ambiguous briefs the agent
   walks toward the camera with a "?" and asks ONE clarifying question;
   the typed answer feeds the retry (mixed initiative, Morae-style
   proactive pause)

**Sprint 6 — candidates**
Adaptive music stems · clickable artifact shelves (open the real files)
· session replay · walkable owner avatar · voice.

**Sprint 1 — "It sounds alive and the work is visible"**
1. Audio layer: contact foley (typing, chairs, steps per floor material,
   paper), positional room tone + murmur walla, publish-celebration
   stinger; AudioStreamRandomizer, pitch ±10%, round-robin (CC0 sources)
2. Juice autoload: pop_in/squash tween helpers; nothing appears or
   changes state without a 0.2-0.4s eased tween + a sound
3. Live kanban wall: one physical card per request, sliding column to
   column as the real pipeline stage changes
4. Artifact handoffs: stage outputs as carried document meshes, placed
   on the next desk; rejections walk back with red marks
5. Honest status: thinking animations during Claude calls (never
   freeze), needs-input and failed states with visible causes

**Sprint 2 — "They remember and they talk"**
Memory stream + retrieval + nightly reflection; needs + smart objects;
water-cooler gossip with anti-loop cooldowns (a16z AI Town); pairwise
relationships feeding prompt context; status bubbles quoting real output.

**Sprint 3 — "It's a show"**
Storyteller node with tension curve; chronicle + physical memorials;
event camera (slow push-ins, tilt-shift DoF); interior-safe time-of-day;
cost meters + approval desk; courtyard skyline of shipped episodes.

## Non-goals (opinionated cuts, from the research)
No 1000-agent emergence (depth-per-agent beats scale at 5). No
node-graph orchestration view (the office IS the graph). No per-tool
permission popups (approval desk only). No decorative idle bustle —
every animation caused by real state, or trust dies. No over-juicing —
calm is the product.

## Sources
Agent simulation: arxiv.org/abs/2304.03442 (Generative Agents),
arxiv.org/abs/2411.00114 (Project Sid), goodai.com (AI People),
gmtk.substack.com (Sims AI), rimworldwiki.com/wiki/AI_Storytellers,
github.com/a16z-infra/ai-town, theaidigest.org/village,
arxiv.org/abs/2412.14161 (TheAgentCompany), arxiv.org/pdf/2308.00352
(MetaGPT).
Game craft: GDC "Juice it or Lose it" + Vlambeer screenshake,
asoundeffect.com/unpacking-game-audio, Animal Crossing hourly-music
analyses, beyondsims.com (SimCity zoom audio), Tiny Glade sound diary,
paradoxinteractive.com (CS2 cinematic camera), Rusty's Retirement
analyses, en.wikipedia.org/wiki/Miniature_faking.
AI-work UX: docs.devin.ai + cognition.com/blog, lucumr.pocoo.org (plan
mode), developers.openai.com/codex, cursor.com/blog/2-0,
langchain.com/langsmith, k9scli.io, GitHub Skyline,
arxiv.org/html/2603.10664v1 ("Terminal Is All You Need").
