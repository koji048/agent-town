# Layout Plan v2 — "The Production Loop"

Research-first redesign proposal. Status: **proposed, not yet built.**

## Research base

Space-planning: zoning groups related functions; an **adjacency matrix** turns
collaboration needs into spatial priorities; **circulation** must be wide,
clear, intuitive, no dead ends; **activity-based working** = zones per task
mode (focus / collaborate / social / restore), not one open field.
Production-studio specifics: **edit suites enclosed and acoustically
separated**, **editing adjacent to the shooting area** (footage travel),
**control room keeps line of sight** over the floor.

Sources: tallyworkspace.com, vantagespace.com, firstinarchitecture.co.uk,
elia.io (space planning); coohom.com, edwardsandhill.com, rios.com,
tvstudiodesign.com (production studios).

## Critique of the current L-shape (v1)

| Finding | Severity | Note |
|---|---|---|
| Pipeline zigzags: Editor (west row) → Publisher (far NE) crosses the whole plan; Director review returns NW — the cascade walks a Z, twice over the spine | 🔴 | Adjacency inverted for the most frequent handoffs |
| No entrance/reception — requests "appear"; the queue (the product's heartbeat) is invisible in the space | 🔴 | The story of the office starts nowhere |
| Emphasis inverted: town hall (used once per request) is the largest, most colorful mass; the production row (used constantly) is visually weakest | 🟡 | Hierarchy should follow use |
| Relax lounge now occupies the geometric center, adjacent to the circulation spine — restorative zone in the noisiest spot | 🟡 | v1 grew by accretion; this was the last free bay, not the right bay |
| Edit bay is an open desk — research says enclosed, dark, acoustic | 🟡 | Also the ring-light "studio" is a corner of publishing, not a room |
| No focus booth (was in the owner interview), no growth bays for the 60-role roadmap, three redundant benches | 🟡 | Program gaps |
| Courtyard reads well but only two doors, both far from the desks that need breaks most | 🟢 | Biophilia not distributed |

What works and is kept: the courtyard as biophilic anchor, glass director
office, coffee bar as social anchor, the new lounge kit-of-parts (slat
screens, copper pendants), Scandinavian palette + coral accent.

## The proposal: a courtyard building where the floor plan IS the pipeline

One rectangular building (24×20 grid) wrapping a **central courtyard**; a
single **racetrack loop corridor** rings it (no dead ends, everything opens
off the loop, every zone gets courtyard glass). A request physically travels
the loop counterclockwise — watching the office = reading the pipeline:

1. **Reception + intake** (NE, the front door): queue kanban wall — pending
   requests appear here as cards
2. **Director's glass office** (north-center): line of sight down both
   corridors and across the courtyard (control-room principle)
3. **Research library** (west, quiet band)
4. **Writers' room** (west, quiet band)
5. **Focus booths ×2** (SW corner): acoustic pods, bookable by any agent
6. **Edit bay** (south, enclosed + dark + acoustic partition)
7. **Studio** (south-center): green screen, ring light, 9:16 phone rig —
   directly beside the edit bay (footage adjacency)
8. **Publishing** (SE): straight out of the studio, hashtags + upload
   → the finished package travels up the east corridor **past the town-hall
   amphitheater** back to the Director for review

Social band on the east: **coffee bar at the loop midpoint** (all daily paths
pass it — collision point), **relax lounge** below it on the courtyard glass
(quiet side, garden view — the v1 lounge kit moves here intact).
**Town hall = amphitheater tiers on the courtyard's south rim** facing a
screen wall (Google-campus move): celebration happens IN the garden, the
space works as lounge seating between all-hands, and no indoor floor is
spent on a once-per-request event.

West + south bands each carry **one spare desk bay** for Phase-3 hireable
roles; the roadmap's trading room and TikTok multi-map become a second
building on the campus grass later.

## Adjacency wins (walk distance in grid cells, stage → next stage)

| Handoff | v1 | v2 |
|---|---|---|
| Editor → Publisher | ~17 | ~4 |
| Publisher → Director (review) | ~14 | ~8 (past the amphitheater) |
| Queue intake → Director | n/a (invisible) | 5 |
| Any desk → coffee | 6–14 | ≤7 (loop midpoint) |
| Any desk → courtyard door | 4–16 | ≤4 (four loop doors) |

## Implementation sketch

1. `tools/generate_assets.py`: new 24×20 map, wall runs for the rectangle +
   courtyard cutout, building anchors per zone, `blocked_chars` unchanged
2. `office_3d.gd`: rebuild `_furnish()` per zone (reusing the lounge kit,
   pendant, slat screen, credenza helpers and all SURFACE_SPECS materials);
   amphitheater = the town-hall tier code moved to the courtyard rim
3. Reception: new queue-wall visual driven by `queue/pending/*` count
4. `TOWNHALL_SPOTS` → amphitheater spots; workstation anchors per zone
5. Screenshot-iterate at viewing size; update README hero; CI must stay green
