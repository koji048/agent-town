# Isometric game construction — study notes

Working notes for rebuilding the Agent Town virtual office correctly.
Sources at the bottom.

## 1. Projection: games don't actually use isometric

True isometric projection puts the three axes at 120° apart (30° from
horizontal). Almost every "isometric" game — SimCity 2000, Age of Empires,
Diablo, Stardew-style interiors — actually uses **2:1 dimetric**: axes at
26.565° (`arctan(1/2)`). Reason: a line that goes 2 pixels across for every
1 pixel down renders perfectly clean on a pixel grid, with no jaggies, and
the math becomes integer-friendly. That's why classic tiles are 64x32,
128x64, etc.

The two transforms everything hangs on (tile size `tw x th`, 2:1):

```
screen_x = (gx - gy) * tw/2          gx = (sx/(tw/2) + sy/(th/2)) / 2
screen_y = (gx + gy) * th/2          gy = (sy/(th/2) - sx/(tw/2)) / 2
```

Left: world grid → screen (rendering). Right: screen → grid (mouse picking).
Game logic (pathfinding, occupancy, distances) stays on the square cartesian
grid; the diamond look is purely a render-time transform.

**Anchoring convention:** every object is positioned by the point where it
touches the ground — a character's feet, a table's base, a wall's bottom
edge. Sprites hang upward from their anchor. Getting this consistent is 90%
of avoiding alignment bugs.

## 2. Depth sorting — the hard part of 2D isometric

Painter's algorithm: draw back-to-front. For single-tile objects the sort
key `gx + gy` (equivalently screen `y` of the anchor) is enough — this is
what Godot's **Y-sort** automates.

It breaks down for:

- **Tall sprites** (walls, shelves): a sprite anchored on one tile visually
  covers others; neighbors with a *smaller* key can still be visually in
  front.
- **Multi-tile objects** (our 2x2 workstations): one sprite, one sort key,
  but it spans several depth rows. A character standing beside it can be
  wrongly hidden.

Professional fixes, in increasing order of robustness:

1. **Slice big objects into per-tile sprites** (one column of the object
   per tile), so every piece sorts like a normal tile. This is the
   industry-standard answer and what tile-based engines expect.
2. **Author objects into the tileset** as multi-cell tiles with a correct
   origin; the tilemap sorts cells, not objects.
3. **Topological sort** on "A overlaps and is behind B" relationships —
   correct but complex; only needed for free-moving large objects.
4. **Go 3D** — the z-buffer solves depth per-pixel, exactly. All sorting
   bugs vanish by construction.

Our current build uses one sprite per 2x2 station with an epsilon nudge on
the sort key. It works because stations sit against walls with a walkway in
front, but it is the naive approach — slicing (1) or 3D (4) is the correct
fix.

## 3. Interiors specifically (Sims-style rooms)

- Only the two **back walls** (north-west and north-east edges) are drawn
  at full height. South/east walls are omitted, drawn as short "stubs," or
  **cut away dynamically** as in The Sims (walls between camera and
  characters drop to knee height or fade to transparent; the wall's cut
  face gets a solid fill color so it reads as a solid object).
- When a character walks **behind** furniture or a wall, good games keep
  them readable: either fade the occluder to ~50% alpha or draw a colored
  **silhouette** of the character through the obstacle (a simple shader).
- Interior realism comes from *grounding*: contact shadows under furniture
  and characters (a soft dark ellipse is enough in 2D), baseboards where
  walls meet floor, and rugs/floor-material zones breaking up large areas.

## 4. Godot 4 specifics

**Proper 2D way** (vs. our hand-rolled Sprite2D placement):

- `TileMapLayer` with Tile Shape = Isometric, tile size 64x32. Multiple
  layers: ground (Y-sort OFF), walls/props (Y-sort ON), one parent Node2D
  with Y-sort ON so tilemap cells and characters interleave correctly.
- Tiles get **texture origins** so tall tiles anchor at their base;
  multi-tile furniture should be sliced per tile or authored as scenes.
- 2D dynamic lighting is available: `PointLight2D` + occluder shapes +
  normal maps on tiles give convincing lamp pools and window light; light
  masks stop shadows landing where they shouldn't.
- `AStarGrid2D` on the logic grid (we already do this) — unchanged either
  way.

**3D way ("3D isometric")**: build the room from real geometry, render with
an **orthographic Camera3D** pitched about -30° and yawed 45°.

- Depth, occlusion and wall cutaway become trivial or per-pixel exact.
- Real lights and shadows for free: a `DirectionalLight3D` through the
  windows, warm `OmniLight3D` desk lamps, SSAO for corner shading.
- The 16-bit look is preserved by rendering into a **low-resolution
  viewport (e.g. 480x270) with nearest-neighbor upscale**, flat-shaded
  blocky meshes and a restricted palette — the "pixelated 3D" style.
- Characters can stay as our existing 2D spritesheets via `Sprite3D`
  billboards (classic Doom/Ragnarok approach) — best of both worlds.
- Costs: meshes must be modeled (or generated as voxel-style boxes), and
  Godot 3D has a steeper scene setup (materials, environment, cameras).

## 5. Decision matrix for the virtual office

| | A. 2D done right | B. True 3D ortho | C. Hybrid 3D + sprite people |
|---|---|---|---|
| Depth correctness | good (sliced tiles) | perfect (z-buffer) | perfect |
| Lighting mood | fair (2D lights) | best (shadows, SSAO) | best |
| Wall cutaway | manual fade logic | trivial | trivial |
| Mezzanine / stairs like the reference photo | hard | natural | natural |
| Keeps current art pipeline | yes | no (meshes) | characters yes |
| Effort from current state | low-medium | high | medium-high |
| 16-bit fidelity | native | via low-res viewport | via low-res viewport |

Recommendation: **C** if the reference photo's feel (light through windows,
mezzanine depth, camera orbit) is the goal; **A** if shipping speed and pure
pixel-art authenticity matter most.

## Sources

- [Pikuma — Isometric Projection in Game Development](https://pikuma.com/blog/isometric-projection-in-games)
- [Demystifying Isometric Projection in 2D Games](https://medium.com/@kavierim/demystifying-isometric-projection-in-2d-games-with-python-bbcc2038a620)
- [Grid Maker Pro — the 2:1 dimetric grid at 26.57°](https://gridmakerpro.com/grids/perspective/dimetric/)
- [Creating Isometric Worlds: A Primer (Envato Tuts+)](https://code.tutsplus.com/creating-isometric-worlds-a-primer-for-game-developers--gamedev-6511t)
- [Isometric tiles for a pixel art game in Godot 4.3](https://stephan-bester.medium.com/isometric-tiles-for-a-pixel-art-game-in-godot-4-3-94b09846c9df)
- [Godot Forum — Y-sort with isometric TileMapLayer](https://forum.godotengine.org/t/is-this-the-correct-way-to-use-ysort-properties-with-isometric-tilemaplayer-in-godot-4-4/120705)
- [Realtime 2D lighting with shadows on isometric tiles in Godot 4.4](https://www.connorwolf.com/post/realtime-2d-lighting-with-shadows-on-isometric-tiles-in-godot-4-4)
- [Godot Forum — isometric game with 3D world, 2D character sprites](https://forum.godotengine.org/t/isometric-game-with-3d-world-but-2d-character-sprites/26916)
- [Rendering a 2D game in 3D (The Recall Singularity)](https://medium.com/@recallsingularity/rendering-a-2d-game-in-3d-bd24ddbee6eb)
- [Unity discussion — The Sims 4 wall cut-away effect](https://forum.unity.com/threads/how-could-one-create-the-wall-cut-away-effect-that-the-sims-4-has.381034/)
