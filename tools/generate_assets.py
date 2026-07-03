#!/usr/bin/env python3
"""Agent Town asset generator.

Generates every 16-bit-style isometric asset the Godot project uses.
Art direction: the INSIDE of a modern creative-studio office — one big
room with wood-clad walls, tall windows, a colorful mural wall, gray
carpet and concrete, timber walkways, desk clusters, indoor plants and
role-specific workstations — rendered as chunky 16-bit isometric pixel
art.

Everything is drawn at half resolution and nearest-neighbour upscaled
2x. Re-run any time; output is deterministic.

Usage:  python3 tools/generate_assets.py
"""
from __future__ import annotations

import json
import os
import random
from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")

# Half-res tile size (final = 2x)
TW, TH = 32, 16
SCALE = 2
WH = 40          # perimeter wall height (half-res)
PH = 22          # workstation back-panel height (half-res)

# ---------------------------------------------------------------- palette
FLOOR = (209, 205, 197)        # polished concrete
FLOOR_D = (194, 190, 182)
FLOOR_SPECK = (222, 218, 210)
CARPET = (106, 112, 126)       # office carpet
CARPET_D = (92, 98, 112)
DECK = (186, 138, 90)          # timber walkway
DECK_D = (156, 112, 70)
ATRIUM = (204, 160, 108)       # lighter wood, central atrium
ATRIUM_D = (176, 134, 86)
GARDEN = (62, 96, 66)          # planted courtyard
GARDEN_HI = (104, 148, 96)
TIMBER = (198, 150, 98)
TIMBER_D = (164, 120, 76)
TIMBER_L = (216, 172, 120)
STEEL = (52, 52, 58)
WHITE_WALL = (240, 237, 230)
GLASS = (158, 202, 226)
SKY = (186, 218, 238)
SKY_LO = (214, 232, 226)
OUTLINE = (34, 30, 42)

ROLE_PAL = {
    "director":   {"shirt": (36, 62, 122),  "hair": (52, 42, 38),   "skin": (232, 190, 158), "accent": (218, 172, 62)},
    "researcher": {"shirt": (44, 122, 82),  "hair": (94, 66, 40),   "skin": (238, 198, 166), "accent": (230, 230, 230)},
    "writer":     {"shirt": (214, 126, 44), "hair": (40, 36, 40),   "skin": (224, 178, 146), "accent": (250, 244, 210)},
    "editor":     {"shirt": (124, 72, 168), "hair": (206, 172, 88), "skin": (240, 202, 172), "accent": (90, 220, 220)},
    "publisher":  {"shirt": (196, 60, 66),  "hair": (60, 46, 60),   "skin": (228, 186, 152), "accent": (250, 210, 90)},
}

STATION_ROLE = {
    "town_hall": "director",
    "library": "researcher",
    "studio": "writer",
    "edit_bay": "editor",
    "tower": "publisher",
}

# ---------------------------------------------------------------- town map
# 24 x 20 tiles. Legend:
#   .  concrete floor    ,  floor (dark variant)   #  timber walkway
#   P  atrium deck       ~  indoor garden (blocked) r  carpet (walkable)
#   t  potted plant      d  desk cluster            l  floor lamp
# Perimeter walls (blocked):
#   c corner   w NE wall wood   W NE wall window   M NE wall mural
#   v NW wall wood   V NW wall window
# Workstation anchors (occupy 2x2 tiles from anchor, blocked):
#   H director   L researcher   S writer   E editor   T publisher
# Compact diorama office (16 x 13): director cabin top-left, two rows of
# desk pods center, storage along the north wall, coffee corner on the west
# wall, lounge bottom-left. Furniture detail is placed by the 3D builder.
MAP_ROWS = [
    "cwwwwWWwwwwwwWWWWWWw",
    "v...................",
    "v...................",
    "v...................",
    "v...................",
    "V...................",
    "V...................",
    "v...................",
    "v...................",
    "v...................",
    "V...................",
    "V...................",
    "v...................",
    "v...................",
]

BUILDINGS = {
    "town_hall": {"anchor": [1, 1],  "role": "director",   "name": "Director's Office"},
    "library":   {"anchor": [1, 5],  "role": "researcher", "name": "Research Station"},
    "studio":    {"anchor": [4, 5],  "role": "writer",     "name": "Writing Station"},
    "edit_bay":  {"anchor": [7, 5],  "role": "editor",     "name": "Edit Station"},
    "tower":     {"anchor": [14, 1], "role": "publisher",  "name": "Publishing Dept"},
}

BLOCKED_CHARS = "~tdlcwWMvV"


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


def masked_draw(canvas: Image.Image, quad: list, draw_fn) -> None:
    """Draw via draw_fn onto a layer, clip it to quad, composite on canvas."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).polygon(quad, fill=255)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), mask))
    canvas.alpha_composite(layer)


# ---------------------------------------------------------------- tiles
def make_tiles() -> None:
    rng = random.Random(7)
    for name, base, speck in [("floor", FLOOR, FLOOR_SPECK), ("floor_dark", FLOOR_D, FLOOR)]:
        im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        diamond(d, 0, 0, base)
        for _ in range(8):
            x, y = rng.randrange(6, TW - 6), rng.randrange(3, TH - 3)
            if im.getpixel((x, y))[3]:
                d.point((x, y), speck)
        save(im, "tiles", f"{name}.png")

    # office carpet with stitch texture
    im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    diamond(d, 0, 0, CARPET)
    for i in range(4):
        y = 4 + i * 3
        d.line([(8 + i, y), (TW - 8 - i, y)], CARPET_D)
    save(im, "tiles", "carpet.png")

    for name, base, dark in [("deck", DECK, DECK_D), ("atrium", ATRIUM, ATRIUM_D)]:
        im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        diamond(d, 0, 0, base)
        d.line([(TW // 2, TH - 1), (TW - 1, TH // 2)], dark)
        d.line([(0, TH // 2), (TW // 2, TH - 1)], dark)
        d.line([(TW // 4, TH // 4 + 2), (TW * 3 // 4 - 2, TH * 3 // 4)], dark)
        d.line([(TW // 4 + 6, TH // 4), (TW * 3 // 4 + 4, TH * 3 // 4 - 2)], dark)
        save(im, "tiles", f"{name}.png")

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


# ---------------------------------------------------------------- walls
# Wall sprites sit on a TW x (TH+WH) canvas whose bottom TH rows hold the
# floor diamond; the face rises WH px above the tile's back edge.
NE_QUAD = [(TW // 2, WH), (TW - 1, WH + TH // 2), (TW - 1, TH // 2), (TW // 2, 0)]
NW_QUAD = [(TW // 2, WH), (0, WH + TH // 2), (0, TH // 2), (TW // 2, 0)]

MURAL_BLOBS = [
    # (x, y, rx, ry, color) in 4-tile run space (x grows +16/tile, y +8/tile)
    (18, 14, 16, 10, (238, 150, 96)),
    (40, 26, 18, 12, (244, 196, 120)),
    (58, 18, 12, 9,  (222, 110, 100)),
    (74, 34, 16, 10, (246, 226, 200)),
    (30, 34, 10, 7,  (222, 110, 100)),
    (66, 44, 12, 8,  (238, 150, 96)),
    (10, 30, 8, 6,   (246, 226, 200)),
]


def _wall_canvas() -> Image.Image:
    return Image.new("RGBA", (TW, TH + WH), (0, 0, 0, 0))


def _wood_face(im: Image.Image, quad: list, ne: bool) -> None:
    def paint(d: ImageDraw.ImageDraw) -> None:
        d.rectangle([0, 0, TW, TH + WH], TIMBER)
        for x in range(0, TW, 4):
            d.line([(x, 0), (x, TH + WH)], TIMBER_D if (x // 4) % 2 else TIMBER_L)
    masked_draw(im, quad, paint)
    ImageDraw.Draw(im).polygon(quad, outline=OUTLINE)
    # baseboard along the bottom edge of the face
    d = ImageDraw.Draw(im)
    if ne:
        d.line([(TW // 2, WH - 1), (TW - 1, WH + TH // 2 - 1)], STEEL)
    else:
        d.line([(TW // 2, WH - 1), (0, WH + TH // 2 - 1)], STEEL)


def _window_face(im: Image.Image, quad: list, ne: bool) -> None:
    def paint(d: ImageDraw.ImageDraw) -> None:
        d.rectangle([0, 0, TW, TH + WH], TIMBER)
        # glass with a soft sky gradient
        for y in range(6, WH - 2):
            f = (y - 6) / max(WH - 8, 1)
            col = tuple(int(SKY[i] + (SKY_LO[i] - SKY[i]) * f) for i in range(3))
            d.line([(0, y), (TW, y)], col)
        d.rectangle([0, 24, TW, 25], STEEL)  # mullion
    masked_draw(im, quad, paint)
    ImageDraw.Draw(im).polygon(quad, outline=STEEL)
    d = ImageDraw.Draw(im)
    if ne:
        d.line([(TW // 2, WH - 1), (TW - 1, WH + TH // 2 - 1)], STEEL)
    else:
        d.line([(TW // 2, WH - 1), (0, WH + TH // 2 - 1)], STEEL)


def _mural_face(im: Image.Image, tile_index: int) -> None:
    ox, oy = tile_index * 16, tile_index * 8

    def paint(d: ImageDraw.ImageDraw) -> None:
        d.rectangle([0, 0, TW, TH + WH], WHITE_WALL)
        for bx, by, rx, ry, col in MURAL_BLOBS:
            x, y = bx - ox, by - oy
            d.ellipse([x - rx, y - ry, x + rx, y + ry], col)
    masked_draw(im, NE_QUAD, paint)
    ImageDraw.Draw(im).polygon(NE_QUAD, outline=OUTLINE)
    ImageDraw.Draw(im).line([(TW // 2, WH - 1), (TW - 1, WH + TH // 2 - 1)], STEEL)


def make_walls() -> None:
    im = _wall_canvas(); _wood_face(im, NE_QUAD, True); save(im, "walls", "wall_ne_wood.png")
    im = _wall_canvas(); _window_face(im, NE_QUAD, True); save(im, "walls", "wall_ne_window.png")
    im = _wall_canvas(); _wood_face(im, NW_QUAD, False); save(im, "walls", "wall_nw_wood.png")
    im = _wall_canvas(); _window_face(im, NW_QUAD, False); save(im, "walls", "wall_nw_window.png")
    im = _wall_canvas(); _wood_face(im, NE_QUAD, True); _wood_face(im, NW_QUAD, False)
    save(im, "walls", "wall_corner.png")
    for i in range(4):
        im = _wall_canvas()
        _mural_face(im, i)
        save(im, "walls", f"mural_{i}.png")


# ---------------------------------------------------------------- props
def make_props() -> None:
    for name, foliage in [("plant", (58, 122, 68)), ("plant_dark", (46, 104, 58))]:
        im = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.polygon([(8, 22), (15, 22), (14, 30), (9, 30)], (188, 98, 66), outline=OUTLINE)
        d.ellipse([4, 8, 19, 23], foliage, outline=OUTLINE)
        d.ellipse([7, 3, 16, 13], tuple(min(c + 26, 255) for c in foliage))
        d.line([(11, 12), (11, 22)], (36, 84, 46))
        save(im, "props", f"{name}.png")

    im = Image.new("RGBA", (12, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([5, 6, 6, 23], STEEL)
    d.rectangle([3, 23, 8, 24], STEEL)
    d.polygon([(2, 1), (9, 1), (8, 6), (3, 6)], (255, 214, 120), outline=OUTLINE)
    save(im, "props", "lamp.png")

    im = Image.new("RGBA", (30, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(15, 6), (28, 12), (15, 18), (2, 12)], TIMBER, outline=OUTLINE)
    d.polygon([(2, 12), (15, 18), (15, 21), (2, 15)], TIMBER_D)
    d.polygon([(15, 18), (28, 12), (28, 15), (15, 21)], (140, 96, 60))
    d.rectangle([4, 14, 5, 22], STEEL)
    d.rectangle([24, 14, 25, 22], STEEL)
    d.rectangle([14, 19, 15, 23], STEEL)
    d.polygon([(12, 5), (18, 8), (18, 12), (12, 9)], STEEL)
    d.polygon([(13, 6), (17, 8), (17, 11), (13, 9)], (120, 220, 255))
    save(im, "props", "desk.png")


# ---------------------------------------------------------------- stations
def _station_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    w, h = TW * 2, TH * 2 + 38
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im), h


def _station_base(im: Image.Image, d: ImageDraw.ImageDraw, h: int, accent) -> None:
    # area rug over the 2x2 footprint
    rug = tuple(int(c * 0.35 + a * 0.25) for c, a in zip(CARPET, accent))
    d.polygon([(32, h - 30), (60, h - 16), (32, h - 3), (3, h - 16)], rug, outline=OUTLINE)


def _panels(im: Image.Image, d: ImageDraw.ImageDraw, h: int, ne_fill, nw_fill, accent) -> tuple:
    """Two low back panels along the NW and NE edges. Returns face quads."""
    ne = [(32, h - 32), (63, h - 16), (63, h - 16 - PH), (32, h - 32 - PH)]
    nw = [(0, h - 16), (32, h - 32), (32, h - 32 - PH), (0, h - 16 - PH)]
    d.polygon(nw, nw_fill, outline=OUTLINE)
    d.polygon(ne, ne_fill, outline=OUTLINE)
    # accent trim on top edge
    d.line([(0, h - 16 - PH), (32, h - 32 - PH)], accent, width=2)
    d.line([(32, h - 32 - PH), (63, h - 16 - PH)], accent, width=2)
    return ne, nw


def _desk_block(d: ImageDraw.ImageDraw, h: int) -> None:
    d.polygon([(32, h - 27), (50, h - 18), (32, h - 9), (14, h - 18)], TIMBER, outline=OUTLINE)
    d.polygon([(14, h - 18), (32, h - 9), (32, h - 6), (14, h - 15)], TIMBER_D)
    d.polygon([(32, h - 9), (50, h - 18), (50, h - 15), (32, h - 6)], (140, 96, 60))
    d.rectangle([16, h - 15, 17, h - 8], STEEL)
    d.rectangle([46, h - 15, 47, h - 8], STEEL)


def _monitor(d: ImageDraw.ImageDraw, x: int, y: int, glow=(120, 220, 255)) -> None:
    d.rectangle([x, y, x + 7, y + 5], STEEL)
    d.rectangle([x + 1, y + 1, x + 6, y + 4], glow)
    d.rectangle([x + 3, y + 6, x + 4, y + 7], STEEL)


def make_stations() -> None:
    rng = random.Random(21)

    # Director's office: glass panels, gold trim, twin monitors
    im, d, h = _station_canvas()
    accent = ROLE_PAL["director"]["accent"]
    _station_base(im, d, h, accent)
    glass = GLASS + (200,)
    ne, nw = _panels(im, d, h, glass, glass, accent)
    d.line([(16, h - 24 - PH // 2), (16, h - 18)], STEEL)
    d.line([(48, h - 24 - PH // 2), (48, h - 18)], STEEL)
    _desk_block(d, h)
    _monitor(d, 24, h - 30)
    _monitor(d, 34, h - 28)
    save(im, "buildings", "town_hall.png")

    # Research corner: bookshelf back panel with colored spines
    im, d, h = _station_canvas()
    accent = ROLE_PAL["researcher"]["accent"]
    _station_base(im, d, h, accent)
    _panels(im, d, h, TIMBER, TIMBER_D, ROLE_PAL["researcher"]["shirt"])
    spine_cols = [(196, 60, 66), (44, 122, 82), (62, 100, 168), (218, 172, 62), (124, 72, 168)]
    for shelf in range(2):
        for i in range(9):
            x = 34 + i * 3
            y = h - 30 - PH + 4 + shelf * 9 + i // 2
            d.rectangle([x, y, x + 1, y + 6], spine_cols[rng.randrange(len(spine_cols))])
    d.line([(32, h - 32 - PH + 12), (63, h - 16 - PH + 12)], TIMBER_D, width=2)
    _desk_block(d, h)
    d.polygon([(24, h - 26), (30, h - 23), (30, h - 19), (24, h - 22)], STEEL)   # laptop
    d.polygon([(25, h - 25), (29, h - 23), (29, h - 20), (25, h - 22)], (170, 240, 200))
    d.rectangle([36, h - 24, 42, h - 21], (196, 60, 66))                          # book stack
    d.rectangle([37, h - 27, 43, h - 24], (62, 100, 168))
    save(im, "buildings", "library.png")

    # Writers' room: wood panel with pinned pages, two laptops
    im, d, h = _station_canvas()
    accent = ROLE_PAL["writer"]["accent"]
    _station_base(im, d, h, accent)
    _panels(im, d, h, TIMBER_L, TIMBER, ROLE_PAL["writer"]["shirt"])
    for i in range(3):
        x = 36 + i * 8
        d.rectangle([x, h - 28 - PH + 4 + i * 2, x + 4, h - 22 - PH + 4 + i * 2], WHITE_WALL, outline=OUTLINE)
    d.rectangle([8, h - 26 - PH + 6, 13, h - 20 - PH + 8], WHITE_WALL, outline=OUTLINE)
    _desk_block(d, h)
    for x, y in [(22, h - 25), (34, h - 26)]:
        d.polygon([(x, y), (x + 6, y + 3), (x + 6, y + 7), (x, y + 4)], STEEL)
        d.polygon([(x + 1, y + 1), (x + 5, y + 3), (x + 5, y + 6), (x + 1, y + 4)], (250, 244, 210))
    save(im, "buildings", "studio.png")

    # Edit bay: dark panel with waveform, triple glowing monitors
    im, d, h = _station_canvas()
    accent = ROLE_PAL["editor"]["accent"]
    _station_base(im, d, h, accent)
    _panels(im, d, h, (64, 62, 74), (50, 48, 58), accent)
    wf = ROLE_PAL["editor"]["accent"]
    prev_y = h - 26 - PH + 8
    for i in range(14):
        x = 34 + i * 2
        y = h - 26 - PH + 8 + rng.randrange(-3, 4) + i // 2
        d.line([(x, prev_y), (x + 2, y)], wf)
        prev_y = y
    _desk_block(d, h)
    _monitor(d, 20, h - 27, (140, 120, 255))
    _monitor(d, 29, h - 30, (90, 220, 220))
    _monitor(d, 38, h - 27, (255, 150, 180))
    save(im, "buildings", "edit_bay.png")

    # Publishing deck: sticky-note board, phone rig + ring light
    im, d, h = _station_canvas()
    accent = ROLE_PAL["publisher"]["accent"]
    _station_base(im, d, h, accent)
    _panels(im, d, h, WHITE_WALL, TIMBER_D, ROLE_PAL["publisher"]["shirt"])
    note_cols = [(255, 214, 120), (255, 150, 180), (90, 220, 220), (170, 240, 200)]
    for row in range(3):
        for col in range(4):
            x = 35 + col * 6
            y = h - 30 - PH + 3 + row * 6 + col * 2
            d.rectangle([x, y, x + 3, y + 3], note_cols[(row + col) % 4])
    _desk_block(d, h)
    d.ellipse([18, h - 34, 30, h - 22], None, outline=(255, 214, 120), width=2)  # ring light
    d.rectangle([23, h - 22, 24, h - 14], STEEL)
    d.rectangle([34, h - 28, 38, h - 20], STEEL)                                  # phone rig
    d.rectangle([35, h - 27, 37, h - 21], (120, 220, 255))
    save(im, "buildings", "tower.png")


# ---------------------------------------------------------------- characters
# Ghibli-inspired (studied, not copied): rounded forms, big emotive eyes,
# button nose, blush, soft two-tone shading, warm outlines, muted palette.
FRAME_W, FRAME_H = 24, 36  # half-res; final 48x72
FACINGS = ["s", "w", "e", "n"]  # sheet rows 0-3; row 4 = work

GHIBLI = {
    "director":   {"shirt": (78, 96, 130),  "hair": (62, 52, 48),   "skin": (247, 221, 198), "accent": (222, 178, 96),  "pants": (58, 56, 66)},
    "researcher": {"shirt": (106, 138, 106),"hair": (112, 82, 56),  "skin": (250, 226, 202), "accent": (238, 234, 224), "pants": (84, 78, 68)},
    "writer":     {"shirt": (214, 150, 98), "hair": (52, 46, 48),   "skin": (243, 214, 188), "accent": (248, 238, 210), "pants": (92, 86, 92)},
    "editor":     {"shirt": (140, 110, 156),"hair": (196, 168, 110),"skin": (250, 228, 206), "accent": (150, 208, 198), "pants": (70, 68, 82)},
    "publisher":  {"shirt": (196, 108, 100),"hair": (76, 60, 62),   "skin": (245, 216, 190), "accent": (240, 206, 120), "pants": (72, 64, 70)},
}
CH_OUTLINE = (88, 62, 52)
BLUSH = (236, 168, 150)
EYE = (56, 46, 44)


def _shade(col, amt=0.82):
    return tuple(int(c * amt) for c in col)


def draw_char_g(d, ox, oy, facing, frame, pal, work=False):
    shirt, hair, skin, accent, pants = pal["shirt"], pal["hair"], pal["skin"], pal["accent"], pal["pants"]
    walk = not work
    phase = [0, 1, 0, -1][frame % 4] if walk else 0
    bob = -1 if (walk and frame % 2 == 1) else 0
    oy = oy + bob

    # ---- legs & shoes (rounded)
    l_dy = max(0, phase)
    r_dy = max(0, -phase)
    d.rounded_rectangle([ox + 7, oy + 26 + l_dy, ox + 11, oy + 33], 2, pants, outline=CH_OUTLINE)
    d.rounded_rectangle([ox + 13, oy + 26 + r_dy, ox + 17, oy + 33], 2, pants, outline=CH_OUTLINE)
    d.rectangle([ox + 7, oy + 32 + l_dy // 2, ox + 11, oy + 33], _shade(pants, 0.6))
    d.rectangle([ox + 13, oy + 32 + r_dy // 2, ox + 17, oy + 33], _shade(pants, 0.6))

    # ---- body: rounded shirt with soft left shading + collar accent
    d.rounded_rectangle([ox + 5, oy + 15, ox + 19, oy + 27], 4, shirt, outline=CH_OUTLINE)
    d.rounded_rectangle([ox + 5, oy + 15, ox + 10, oy + 27], 4, _shade(shirt))
    d.line([(ox + 10, oy + 16), (ox + 10, oy + 26)], _shade(shirt))
    d.rounded_rectangle([ox + 8, oy + 15, ox + 16, oy + 17], 2, accent)

    # ---- arms (swing opposite to legs) or raised when working
    if work:
        lift = 2 if frame % 2 == 0 else 0
        d.rounded_rectangle([ox + 2, oy + 11 - lift, ox + 5, oy + 19 - lift], 2, shirt, outline=CH_OUTLINE)
        d.rounded_rectangle([ox + 19, oy + 11 - (2 - lift), ox + 22, oy + 19 - (2 - lift)], 2, shirt, outline=CH_OUTLINE)
        d.rounded_rectangle([ox + 7, oy + 18, ox + 17, oy + 22], 2, accent, outline=CH_OUTLINE)
    else:
        a_dy = -phase
        d.rounded_rectangle([ox + 3, oy + 16 + a_dy, ox + 5, oy + 24 + a_dy], 2, _shade(shirt), outline=CH_OUTLINE)
        d.rounded_rectangle([ox + 19, oy + 16 - a_dy, ox + 21, oy + 24 - a_dy], 2, shirt, outline=CH_OUTLINE)
        d.rectangle([ox + 3, oy + 23 + a_dy, ox + 5, oy + 24 + a_dy], skin)
        d.rectangle([ox + 19, oy + 23 - a_dy, ox + 21, oy + 24 - a_dy], skin)

    # ---- head: big rounded face
    d.ellipse([ox + 4, oy + 2, ox + 20, oy + 16], skin, outline=CH_OUTLINE)

    if facing == "n":
        # back of head: full hair + a little bun
        d.ellipse([ox + 4, oy + 2, ox + 20, oy + 15], hair, outline=CH_OUTLINE)
        d.ellipse([ox + 9, oy + 1, ox + 15, oy + 5], _shade(hair, 1.18), outline=CH_OUTLINE)
    else:
        # hair cap with soft highlight
        d.ellipse([ox + 4, oy + 1, ox + 20, oy + 10], hair, outline=CH_OUTLINE)
        d.rectangle([ox + 4, oy + 6, ox + 20, oy + 7], hair)
        d.arc([ox + 6, oy + 2, ox + 18, oy + 9], 200, 320, _shade(hair, 1.25), 1)
        # side locks
        d.rounded_rectangle([ox + 4, oy + 6, ox + 6, oy + 12], 1, hair)
        d.rounded_rectangle([ox + 18, oy + 6, ox + 20, oy + 12], 1, hair)

        # scalloped bangs (kept above the eye line)
        for bx in (6, 10, 14):
            d.arc([ox + bx, oy + 5, ox + bx + 4, oy + 9], 0, 180, hair, 1)
        if facing == "s" or work:
            # big Ghibli eyes with catchlights (spaced apart)
            d.ellipse([ox + 7, oy + 9, ox + 9, oy + 12], EYE)
            d.ellipse([ox + 15, oy + 9, ox + 17, oy + 12], EYE)
            d.point((ox + 8, oy + 10), (255, 255, 255))
            d.point((ox + 16, oy + 10), (255, 255, 255))
            # button nose + subtle mouth + blush
            d.point((ox + 12, oy + 13), (196, 140, 120))
            d.line([(ox + 11, oy + 14), (ox + 13, oy + 14)], (176, 116, 100))
            d.rectangle([ox + 5, oy + 12, ox + 6, oy + 13], BLUSH)
            d.rectangle([ox + 18, oy + 12, ox + 19, oy + 13], BLUSH)
        elif facing == "w":
            d.rectangle([ox + 12, oy + 3, ox + 20, oy + 12], hair)
            d.ellipse([ox + 7, oy + 9, ox + 9, oy + 12], EYE)
            d.point((ox + 8, oy + 10), (255, 255, 255))
            d.rectangle([ox + 5, oy + 12, ox + 6, oy + 13], BLUSH)
        elif facing == "e":
            d.rectangle([ox + 4, oy + 3, ox + 12, oy + 12], hair)
            d.ellipse([ox + 15, oy + 9, ox + 17, oy + 12], EYE)
            d.point((ox + 16, oy + 10), (255, 255, 255))
            d.rectangle([ox + 18, oy + 12, ox + 19, oy + 13], BLUSH)


def make_characters() -> None:
    for role, pal in GHIBLI.items():
        sheet = Image.new("RGBA", (FRAME_W * 4, FRAME_H * 5), (0, 0, 0, 0))
        d = ImageDraw.Draw(sheet)
        for row, facing in enumerate(FACINGS):
            for f in range(4):
                draw_char_g(d, f * FRAME_W, row * FRAME_H, facing, f, pal)
        for f in range(4):
            draw_char_g(d, f * FRAME_W, 4 * FRAME_H, "s", f, pal, work=True)
        save(sheet, "characters", f"{role}.png")
    # review strip: all five, front idle, 4x
    strip = Image.new("RGBA", (FRAME_W * 5 * 4, FRAME_H * 4), (236, 232, 224, 255))
    for i, (role, pal) in enumerate(GHIBLI.items()):
        one = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
        draw_char_g(ImageDraw.Draw(one), 0, 0, "s", 0, pal)
        strip.alpha_composite(one.resize((FRAME_W * 4, FRAME_H * 4), Image.NEAREST), (i * FRAME_W * 4, 0))
    p = os.path.join(ROOT, "docs", "chars_preview.png")
    strip.save(p)
    print("wrote docs/chars_preview.png")


# ---------------------------------------------------------------- 3D textures
# Square tiling textures used as StandardMaterial3D albedo maps by the
# 3D office renderer (nearest-filtered for the 16-bit look).
def make_textures_3d() -> None:
    rng = random.Random(31)

    def tex(name: str, size: int, base, painter) -> None:
        im = Image.new("RGBA", (size, size), base + (255,))
        painter(ImageDraw.Draw(im), size)
        p = os.path.join(ASSETS, "textures", f"{name}.png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)
        print("wrote", os.path.relpath(p, ROOT))

    def speckle(cols, n):
        def paint(d: ImageDraw.ImageDraw, size: int) -> None:
            for _ in range(n):
                d.point((rng.randrange(size), rng.randrange(size)), cols[rng.randrange(len(cols))])
        return paint

    tex("concrete", 16, FLOOR, speckle([FLOOR_D, FLOOR_SPECK], 30))
    tex("concrete_dark", 16, FLOOR_D, speckle([FLOOR, (180, 176, 168)], 30))

    def carpet_paint(d: ImageDraw.ImageDraw, size: int) -> None:
        for y in range(0, size, 4):
            d.line([(0, y), (size, y)], CARPET_D)
        speckle([(116, 122, 136)], 14)(d, size)
    tex("carpet", 16, CARPET, carpet_paint)

    def planks(base, dark, light):
        def paint(d: ImageDraw.ImageDraw, size: int) -> None:
            for x in range(0, size, 4):
                d.line([(x, 0), (x, size)], dark if (x // 4) % 2 else light)
            for y in (5, 11):
                d.line([(0, y), (size, y)], dark)
        return paint
    tex("deck", 16, DECK, planks(DECK, DECK_D, (200, 152, 104)))
    tex("atrium", 16, ATRIUM, planks(ATRIUM, ATRIUM_D, (218, 176, 124)))

    tex("garden", 16, GARDEN, speckle([GARDEN_HI, (86, 128, 82), (50, 80, 54)], 40))

    def wallwood_paint(d: ImageDraw.ImageDraw, size: int) -> None:
        for x in range(0, size, 4):
            d.line([(x, 0), (x, size)], TIMBER_D if (x // 4) % 2 else TIMBER_L)
    tex("wallwood", 32, TIMBER, wallwood_paint)

    # full mural artwork for the 3D wall (one quad, 4 tiles wide)
    im = Image.new("RGBA", (128, 56), WHITE_WALL + (255,))
    d = ImageDraw.Draw(im)
    for bx, by, rx, ry, col in MURAL_BLOBS:
        d.ellipse([bx * 1.4 - rx * 1.4, by - ry, bx * 1.4 + rx * 1.4, by + ry], col)
    p = os.path.join(ASSETS, "textures", "mural_full.png")
    im.save(p)
    print("wrote", os.path.relpath(p, ROOT))


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
    width = len(MAP_ROWS[0])
    for i, row in enumerate(MAP_ROWS):
        assert len(row) == width, f"row {i} must be {width} chars, got {len(row)}"
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
        assert c in ".,#Pr" and (wx, wy) not in blocked, \
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
def mural_index(gx: int, gy: int) -> int:
    """Index within a consecutive run of M chars on a row."""
    i = 0
    while gx - i - 1 >= 0 and MAP_ROWS[gy][gx - i - 1] == "M":
        i += 1
    return i % 4


def wall_sprite_for(c: str, gx: int, gy: int) -> str | None:
    match c:
        case "c": return "walls/wall_corner.png"
        case "w": return "walls/wall_ne_wood.png"
        case "W": return "walls/wall_ne_window.png"
        case "v": return "walls/wall_nw_wood.png"
        case "V": return "walls/wall_nw_window.png"
        case "M": return f"walls/mural_{mural_index(gx, gy)}.png"
    return None


def make_preview() -> None:
    """Composite the whole office into docs/preview.png (for the README)."""
    cols, rows_n = len(MAP_ROWS[0]), len(MAP_ROWS)
    W = (cols + rows_n) * TW // 2 + TW
    H = (cols + rows_n) * TH // 2 + 160
    im = Image.new("RGBA", (W, H), (28, 28, 36, 255))
    ox = rows_n * TW // 2

    def screen(gx: int, gy: int) -> tuple[int, int]:
        return ox + (gx - gy) * TW // 2, 110 + (gx + gy) * TH // 2

    def sprite(p: str) -> Image.Image:
        s = Image.open(os.path.join(ASSETS, p))
        return s.resize((s.width // SCALE, s.height // SCALE), Image.NEAREST)

    tile_map = {".": "tiles/floor.png", ",": "tiles/floor_dark.png", "#": "tiles/deck.png",
                "P": "tiles/atrium.png", "~": "tiles/garden_0.png", "r": "tiles/carpet.png"}
    for gy in range(rows_n):
        for gx in range(cols):
            spr = sprite(tile_map.get(MAP_ROWS[gy][gx], "tiles/floor.png"))
            sx, sy = screen(gx, gy)
            im.alpha_composite(spr, (sx + (TW - spr.width) // 2, sy))

    draw_order: list[tuple[str, int, int, str]] = []
    for gy in range(rows_n):
        for gx in range(cols):
            c = MAP_ROWS[gy][gx]
            wall = wall_sprite_for(c, gx, gy)
            if wall:
                draw_order.append((wall, gx, gy, "wall"))
            elif c == "t":
                draw_order.append(("props/plant.png" if (gx + gy) % 2 else "props/plant_dark.png", gx, gy, "prop"))
            elif c == "l":
                draw_order.append(("props/lamp.png", gx, gy, "prop"))
            elif c == "d":
                draw_order.append(("props/desk.png", gx, gy, "prop"))
    for name, b in BUILDINGS.items():
        ax, ay = b["anchor"]
        draw_order.append((f"buildings/{name}.png", ax + 1, ay + 1, "station"))
    spots = [(9, 6), (8, 8), (11, 7), (4, 6), (10, 12)]
    for role, (gx, gy) in zip(ROLE_PAL.keys(), spots):
        draw_order.append((f"characters/{role}.png", gx, gy, "char"))
    draw_order.sort(key=lambda t: t[1] + t[2])

    for p, gx, gy, kind in draw_order:
        sx, sy = screen(gx, gy)
        if kind == "char":
            sheet = Image.open(os.path.join(ASSETS, p))
            spr = sheet.crop((0, 0, FRAME_W * SCALE, FRAME_H * SCALE))
            spr = spr.resize((FRAME_W, FRAME_H), Image.NEAREST)
            im.alpha_composite(spr, (sx + (TW - FRAME_W) // 2, sy + TH - 22))
        else:
            spr = sprite(p)
            dy = sy + TH - spr.height
            if kind == "prop":
                dy += 2
            elif kind == "station":
                dy = sy + TH * 2 - spr.height  # 2x2 footprint bottoms out one row lower
            im.alpha_composite(spr, (sx + (TW - spr.width) // 2, dy))
    out = im.resize((W * 2, H * 2), Image.NEAREST)
    p = os.path.join(ROOT, "docs", "preview.png")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    out.save(p)
    print("wrote docs/preview.png")


if __name__ == "__main__":
    make_tiles()
    make_walls()
    make_props()
    make_stations()
    make_characters()
    make_textures_3d()
    make_icon()
    make_map_json()
    make_preview()
    print("all assets generated.")
