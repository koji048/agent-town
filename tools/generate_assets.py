#!/usr/bin/env python3
"""Agent Town asset generator.

Generates every 16-bit-style isometric asset the Godot project uses.
Art direction: a modern creative-studio campus — warm timber, black
steel, white walls, glass, indoor plants, desk clusters and a mural
wall — rendered as chunky 16-bit isometric pixel art.

Everything is drawn at half resolution and nearest-neighbour upscaled
2x. Re-run any time; output is deterministic.

Usage:  python3 tools/generate_assets.py
"""
from __future__ import annotations

import json
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")

# Half-res tile size (final = 2x)
TW, TH = 32, 16
SCALE = 2

# ---------------------------------------------------------------- palette
FLOOR = (209, 205, 197)        # polished concrete
FLOOR_D = (194, 190, 182)
FLOOR_SPECK = (222, 218, 210)
DECK = (186, 138, 90)          # timber walkway
DECK_D = (156, 112, 70)
ATRIUM = (204, 160, 108)       # lighter wood, central atrium
ATRIUM_D = (176, 134, 86)
GARDEN = (62, 96, 66)          # planted courtyard
GARDEN_HI = (104, 148, 96)
TIMBER = (198, 150, 98)
TIMBER_D = (164, 120, 76)
STEEL = (52, 52, 58)
WHITE_WALL = (240, 237, 230)
GLASS = (158, 202, 226)
OUTLINE = (34, 30, 42)

ROLE_PAL = {
    "director":   {"shirt": (36, 62, 122),  "hair": (52, 42, 38),   "skin": (232, 190, 158), "accent": (218, 172, 62)},
    "researcher": {"shirt": (44, 122, 82),  "hair": (94, 66, 40),   "skin": (238, 198, 166), "accent": (230, 230, 230)},
    "writer":     {"shirt": (214, 126, 44), "hair": (40, 36, 40),   "skin": (224, 178, 146), "accent": (250, 244, 210)},
    "editor":     {"shirt": (124, 72, 168), "hair": (206, 172, 88), "skin": (240, 202, 172), "accent": (90, 220, 220)},
    "publisher":  {"shirt": (196, 60, 66),  "hair": (60, 46, 60),   "skin": (228, 186, 152), "accent": (250, 210, 90)},
}

BUILDING_STYLE = {
    "town_hall": {"wall": WHITE_WALL, "roof": STEEL, "trim": (218, 172, 62), "mural": True},
    "library":   {"wall": TIMBER,     "roof": STEEL, "trim": (68, 148, 96),  "mural": False},
    "studio":    {"wall": WHITE_WALL, "roof": (166, 120, 76), "trim": (214, 126, 44), "mural": False},
    "edit_bay":  {"wall": (212, 210, 216), "roof": STEEL, "trim": (90, 220, 220), "mural": False},
    "tower":     {"wall": TIMBER,     "roof": (60, 56, 64), "trim": (196, 60, 66), "mural": False},
}

# ---------------------------------------------------------------- town map
# 24 x 20 tiles. Legend:
#   .  concrete floor    ,  floor (dark variant)   #  timber walkway
#   P  atrium deck       ~  planted courtyard (blocked)
#   t  potted plant (blocked)    d  desk cluster (blocked)
#   l  floor lamp (blocked)
# Room anchors (occupy 2x2 tiles from anchor, blocked):
#   H director's office   L research corner   S writers' room
#   E edit bay            T publishing deck
MAP_ROWS = [
    "t.,......t.......t....,.",
    "........................",
    "...H........L..........t",
    ".......................~",
    "....#########.........~~",
    "t...#.......#........~~~",
    "....#.......#.......~~~~",
    "....#..PPP..#........~~~",
    "#####..PPP..#####.....~~",
    "....#..PPP......#......~",
    "....#.......#####.dd....",
    "....#.......#....dd.t...",
    "t...#########...........",
    "........#....l..........",
    "...S....#....E..........",
    "........#...............",
    ".....t..#.......t......,",
    "....l...#....T..........",
    ",.......#........dd.....",
    "t...........,.....t.....",
]

BUILDINGS = {
    "town_hall": {"anchor": [3, 2],   "role": "director",   "name": "Director's Office"},
    "library":   {"anchor": [12, 2],  "role": "researcher", "name": "Research Corner"},
    "studio":    {"anchor": [3, 14],  "role": "writer",     "name": "Writers' Room"},
    "edit_bay":  {"anchor": [13, 14], "role": "editor",     "name": "Edit Bay"},
    "tower":     {"anchor": [13, 17], "role": "publisher",  "name": "Publishing Deck"},
}

BLOCKED_CHARS = "~tdl"


def up(img: Image.Image) -> Image.Image:
    return img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)


def save(img: Image.Image, *path: str) -> None:
    p = os.path.join(ASSETS, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    up(img).save(p)
    print("wrote", os.path.relpath(p, ROOT))


def diamond(d: ImageDraw.ImageDraw, ox: int, oy: int, fill, outline=None) -> None:
    d.polygon([(ox + TW // 2, oy), (ox + TW - 1, oy + TH // 2),
               (ox + TW // 2, oy + TH - 1), (ox, oy + TH // 2)],
              fill=fill, outline=outline)


# ---------------------------------------------------------------- tiles
def make_tiles() -> None:
    rng = random.Random(7)
    # concrete floor, two variants
    for name, base, speck in [("floor", FLOOR, FLOOR_SPECK), ("floor_dark", FLOOR_D, FLOOR)]:
        im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        diamond(d, 0, 0, base)
        for _ in range(8):
            x, y = rng.randrange(6, TW - 6), rng.randrange(3, TH - 3)
            if im.getpixel((x, y))[3]:
                d.point((x, y), speck)
        save(im, "tiles", f"{name}.png")

    # timber walkway and atrium deck, with plank lines
    for name, base, dark in [("deck", DECK, DECK_D), ("atrium", ATRIUM, ATRIUM_D)]:
        im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        diamond(d, 0, 0, base)
        d.line([(TW // 2, TH - 1), (TW - 1, TH // 2)], dark)
        d.line([(0, TH // 2), (TW // 2, TH - 1)], dark)
        d.line([(TW // 4, TH // 4 + 2), (TW * 3 // 4 - 2, TH * 3 // 4)], dark)
        d.line([(TW // 4 + 6, TH // 4), (TW * 3 // 4 + 4, TH * 3 // 4 - 2)], dark)
        save(im, "tiles", f"{name}.png")

    # planted courtyard, 2 shimmer frames
    for frame in range(2):
        im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        diamond(d, 0, 0, GARDEN)
        rng2 = random.Random(11 + frame)
        for _ in range(9):
            x, y = rng2.randrange(6, TW - 6), rng2.randrange(3, TH - 3)
            if im.getpixel((x, y))[3]:
                d.point((x, y), GARDEN_HI)
                d.point((x + 1, y), (86, 128, 82))
        save(im, "tiles", f"garden_{frame}.png")


# ---------------------------------------------------------------- props
def make_props() -> None:
    # potted plants (monstera-ish), 2 variants
    for name, foliage in [("plant", (58, 122, 68)), ("plant_dark", (46, 104, 58))]:
        im = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.polygon([(8, 22), (15, 22), (14, 30), (9, 30)], (188, 98, 66), outline=OUTLINE)  # pot
        d.ellipse([4, 8, 19, 23], foliage, outline=OUTLINE)
        d.ellipse([7, 3, 16, 13], tuple(min(c + 26, 255) for c in foliage))
        d.line([(11, 12), (11, 22)], (36, 84, 46))
        save(im, "props", f"{name}.png")

    # modern floor lamp: black stem, warm shade
    im = Image.new("RGBA", (12, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([5, 6, 6, 23], STEEL)
    d.rectangle([3, 23, 8, 24], STEEL)
    d.polygon([(2, 1), (9, 1), (8, 6), (3, 6)], (255, 214, 120), outline=OUTLINE)
    save(im, "props", "lamp.png")

    # desk cluster: iso desk, black legs, laptop + screen glow
    im = Image.new("RGBA", (30, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(15, 6), (28, 12), (15, 18), (2, 12)], TIMBER, outline=OUTLINE)  # top
    d.polygon([(2, 12), (15, 18), (15, 21), (2, 15)], TIMBER_D)                 # front-left edge
    d.polygon([(15, 18), (28, 12), (28, 15), (15, 21)], (140, 96, 60))          # front-right edge
    d.rectangle([4, 14, 5, 22], STEEL)
    d.rectangle([24, 14, 25, 22], STEEL)
    d.rectangle([14, 19, 15, 23], STEEL)
    d.polygon([(12, 5), (18, 8), (18, 12), (12, 9)], STEEL)                     # laptop screen
    d.polygon([(13, 6), (17, 8), (17, 11), (13, 9)], (120, 220, 255))
    save(im, "props", "desk.png")


# ---------------------------------------------------------------- rooms
def make_building(name: str, style: dict, floors: int = 1) -> None:
    # 2x2 tile footprint -> half-res canvas 64 wide
    wall_h = 18 * floors
    w, h = TW * 2, TH * 2 + wall_h + 22
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wall, roof, trim = style["wall"], style["roof"], style["trim"]
    wall_l = tuple(max(c - 30, 0) for c in wall)
    roof_d = tuple(max(c - 26, 0) for c in roof)
    base_y = h - TH  # top of base diamond
    cx = w // 2

    # left wall face
    d.polygon([(0, base_y - wall_h + TH // 2), (cx, base_y - wall_h + TH),
               (cx, base_y + TH), (0, base_y + TH // 2)], wall_l, outline=OUTLINE)
    # right wall face
    d.polygon([(cx, base_y - wall_h + TH), (w - 1, base_y - wall_h + TH // 2),
               (w - 1, base_y + TH // 2), (cx, base_y + TH)], wall, outline=OUTLINE)
    # flat steel roof with fascia
    ry = base_y - wall_h
    d.polygon([(cx, ry - 8), (w - 1, ry + TH // 2 - 4), (cx, ry + TH - 1), (0, ry + TH // 2 - 4)],
              roof, outline=OUTLINE)
    d.polygon([(0, ry + TH // 2 - 4), (cx, ry + TH - 1), (cx, ry + TH + 2), (0, ry + TH // 2 - 1)],
              roof_d, outline=OUTLINE)
    d.polygon([(cx, ry + TH - 1), (w - 1, ry + TH // 2 - 4), (w - 1, ry + TH // 2 - 1), (cx, ry + TH + 2)],
              roof_d, outline=OUTLINE)

    if style.get("mural"):
        # colorful mural on the left wall face (nod to the studio mural)
        my = base_y - wall_h + 8
        d.ellipse([4, my, 16, my + 10], (238, 150, 96))
        d.ellipse([12, my + 4, 24, my + 14], (240, 196, 120))
        d.ellipse([2, my + 8, 12, my + 16], (222, 110, 100))
        d.ellipse([18, my - 2, 26, my + 6], (246, 226, 200))
    else:
        # tall glass window on the left face
        d.rectangle([6, base_y - wall_h + 8, 22, base_y + 2], GLASS, outline=STEEL)
        d.line([(14, base_y - wall_h + 8), (14, base_y + 2)], STEEL)

    # glass door on right face, steel frame
    dx = cx + 8
    d.rectangle([dx, base_y - 4, dx + 9, base_y + 10], GLASS, outline=STEEL)
    d.line([(dx + 4, base_y - 4), (dx + 4, base_y + 10)], STEEL)
    # windows on right face
    for wx in (cx + 22,):
        face_y = base_y - wall_h + 7
        d.rectangle([wx, face_y, wx + 6, face_y + 8], GLASS, outline=STEEL)
    # role-colored trim band under the roof
    d.rectangle([cx - 12, base_y - wall_h + 2, cx + 11, base_y - wall_h + 4], trim)
    if name == "tower":
        # broadcast antenna
        d.rectangle([cx - 1, ry - 20, cx, ry - 6], (90, 90, 100))
        d.ellipse([cx - 3, ry - 24, cx + 2, ry - 19], (255, 90, 90), outline=OUTLINE)
    save(im, "buildings", f"{name}.png")


# ---------------------------------------------------------------- characters
FRAME_W, FRAME_H = 16, 24  # half-res; final 32x48
FACINGS = ["s", "w", "e", "n"]  # sheet rows 0-3; row 4 = work


def draw_char(d: ImageDraw.ImageDraw, ox: int, oy: int, facing: str, frame: int,
              pal: dict, work: bool = False) -> None:
    skin, shirt, hair, accent = pal["skin"], pal["shirt"], pal["hair"], pal["accent"]
    pants = (52, 54, 70)
    phase = [0, 1, 0, -1][frame % 4]
    if work:
        phase = 0
    # legs
    d.rectangle([ox + 5, oy + 17 + max(0, phase), ox + 6, oy + 21], pants)
    d.rectangle([ox + 9, oy + 17 + max(0, -phase), ox + 10, oy + 21], pants)
    # body
    d.rectangle([ox + 4, oy + 10, ox + 11, oy + 17], shirt, outline=OUTLINE)
    # arms
    if work:
        lift = 2 if frame % 2 == 0 else 0
        d.rectangle([ox + 2, oy + 9 - lift, ox + 3, oy + 13 - lift], shirt)
        d.rectangle([ox + 12, oy + 9 - (2 - lift), ox + 13, oy + 13 - (2 - lift)], shirt)
        d.rectangle([ox + 5, oy + 13, ox + 10, oy + 15], accent)  # held item
    else:
        d.rectangle([ox + 3, oy + 11 + phase, ox + 3, oy + 15 + phase], shirt)
        d.rectangle([ox + 12, oy + 11 - phase, ox + 12, oy + 15 - phase], shirt)
    # head
    d.rectangle([ox + 4, oy + 3, ox + 11, oy + 9], skin, outline=OUTLINE)
    d.rectangle([ox + 4, oy + 2, ox + 11, oy + 4], hair)
    if facing == "n":
        d.rectangle([ox + 4, oy + 3, ox + 11, oy + 8], hair)
    elif facing == "s" or work:
        d.point((ox + 6, oy + 6), OUTLINE)
        d.point((ox + 9, oy + 6), OUTLINE)
    elif facing == "w":
        d.rectangle([ox + 9, oy + 3, ox + 11, oy + 8], hair)
        d.point((ox + 6, oy + 6), OUTLINE)
    elif facing == "e":
        d.rectangle([ox + 4, oy + 3, ox + 6, oy + 8], hair)
        d.point((ox + 9, oy + 6), OUTLINE)


def make_characters() -> None:
    for role, pal in ROLE_PAL.items():
        sheet = Image.new("RGBA", (FRAME_W * 4, FRAME_H * 5), (0, 0, 0, 0))
        d = ImageDraw.Draw(sheet)
        for row, facing in enumerate(FACINGS):
            for f in range(4):
                draw_char(d, f * FRAME_W, row * FRAME_H, facing, f, pal)
        for f in range(4):
            draw_char(d, f * FRAME_W, 4 * FRAME_H, "s", f, pal, work=True)
        save(sheet, "characters", f"{role}.png")


# ---------------------------------------------------------------- ui icon
def make_icon() -> None:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(32, 14), (58, 30), (32, 46), (6, 30)], DECK, outline=OUTLINE)
    d.polygon([(20, 24), (32, 18), (44, 24), (44, 34), (32, 40), (20, 34)],
              WHITE_WALL, outline=OUTLINE)
    d.polygon([(18, 24), (32, 12), (46, 24), (32, 30)], STEEL, outline=OUTLINE)
    d.rectangle([30, 30, 34, 38], GLASS)
    save(im, "ui", "icon.png")


# ---------------------------------------------------------------- map.json
def validate_map() -> None:
    assert len(MAP_ROWS) == 20, "map must be 20 rows"
    for i, row in enumerate(MAP_ROWS):
        assert len(row) == 24, f"row {i} must be 24 chars, got {len(row)}"
    blocked = set()
    for b in BUILDINGS.values():
        ax, ay = b["anchor"]
        for dx in range(2):
            for dy in range(2):
                blocked.add((ax + dx, ay + dy))
    for bname, b in BUILDINGS.items():
        ax, ay = b["anchor"]
        wx, wy = ax + 1, ay + 2
        c = MAP_ROWS[wy][wx]
        assert c in ".,#P" and (wx, wy) not in blocked, \
            f"workstation for {bname} at ({wx},{wy}) is not walkable ('{c}')"


def make_map_json() -> None:
    validate_map()
    data = {
        "tile_w": TW * SCALE,
        "tile_h": TH * SCALE,
        "rows": MAP_ROWS,
        "blocked_chars": BLOCKED_CHARS,
        "buildings": {
            name: {**b, "workstation": [b["anchor"][0] + 1, b["anchor"][1] + 2]}
            for name, b in BUILDINGS.items()
        },
    }
    p = os.path.join(ASSETS, "map.json")
    with open(p, "w") as f:
        json.dump(data, f, indent=2)
    print("wrote", os.path.relpath(p, ROOT))


# ---------------------------------------------------------------- preview
def make_preview() -> None:
    """Composite the whole campus into docs/preview.png (for the README)."""
    cols, rows_n = 24, 20
    W = (cols + rows_n) * TW // 2 + TW
    H = (cols + rows_n) * TH // 2 + 140
    im = Image.new("RGBA", (W, H), (28, 28, 36, 255))
    ox = rows_n * TW // 2

    def screen(gx: int, gy: int) -> tuple[int, int]:
        return ox + (gx - gy) * TW // 2, 80 + (gx + gy) * TH // 2

    def sprite(p: str) -> Image.Image:
        s = Image.open(os.path.join(ASSETS, p))
        return s.resize((s.width // SCALE, s.height // SCALE), Image.NEAREST)

    def paste(p: str, gx: int, gy: int, anchor_h: int | None = None) -> None:
        spr = sprite(p)
        if anchor_h is None:
            anchor_h = spr.height - TH  # buildings: base diamond at bottom
        sx, sy = screen(gx, gy)
        im.alpha_composite(spr, (sx + (TW - spr.width) // 2, sy - anchor_h))

    tile_map = {".": "tiles/floor.png", ",": "tiles/floor_dark.png", "#": "tiles/deck.png",
                "P": "tiles/atrium.png", "~": "tiles/garden_0.png",
                "t": "tiles/floor.png", "l": "tiles/floor.png", "d": "tiles/floor.png"}
    for gy in range(rows_n):
        for gx in range(cols):
            paste(tile_map.get(MAP_ROWS[gy][gx], "tiles/floor.png"), gx, gy, 0)

    draw_order: list[tuple[str, int, int]] = []
    for gy in range(rows_n):
        for gx in range(cols):
            c = MAP_ROWS[gy][gx]
            if c == "t":
                draw_order.append(("props/plant.png" if (gx + gy) % 2 else "props/plant_dark.png", gx, gy))
            elif c == "l":
                draw_order.append(("props/lamp.png", gx, gy))
            elif c == "d":
                draw_order.append(("props/desk.png", gx, gy))
    for name, b in BUILDINGS.items():
        ax, ay = b["anchor"]
        draw_order.append((f"buildings/{name}.png", ax + 1, ay + 1))
    spots = [(9, 8), (8, 9), (10, 9), (5, 8), (9, 12)]
    for role, (gx, gy) in zip(ROLE_PAL.keys(), spots):
        draw_order.append((f"characters/{role}.png", gx, gy))
    draw_order.sort(key=lambda t: t[1] + t[2])
    for p, gx, gy in draw_order:
        if p.startswith("characters"):
            sheet = Image.open(os.path.join(ASSETS, p))
            spr = sheet.crop((0, 0, FRAME_W * SCALE, FRAME_H * SCALE))
            spr = spr.resize((FRAME_W, FRAME_H), Image.NEAREST)
            sx, sy = screen(gx, gy)
            im.alpha_composite(spr, (sx + (TW - FRAME_W) // 2, sy + TH - 22))
        elif p.startswith("props"):
            spr = sprite(p)
            sx, sy = screen(gx, gy)
            im.alpha_composite(spr, (sx + (TW - spr.width) // 2, sy + TH - spr.height + 2))
        else:
            paste(p, gx, gy)
    out = im.resize((W * 2, H * 2), Image.NEAREST)
    p = os.path.join(ROOT, "docs", "preview.png")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    out.save(p)
    print("wrote docs/preview.png")


if __name__ == "__main__":
    make_tiles()
    make_props()
    for bname, bstyle in BUILDING_STYLE.items():
        make_building(bname, bstyle, floors=2 if bname == "tower" else 1)
    make_characters()
    make_icon()
    make_map_json()
    make_preview()
    print("all assets generated.")
