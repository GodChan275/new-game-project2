"""Procedural 16-bit style pixel art + chiptune SFX generator.

Pure stdlib (zlib/struct/wave/math/random) so it runs anywhere.
Outputs to Assets/Sprites/ and Assets/Sfx/.
Run: python tools/gen_art.py
"""
import math
import os
import random
import struct
import wave
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets", "Sprites")
SND = os.path.join(ROOT, "Assets", "Sfx")
os.makedirs(OUT, exist_ok=True)
os.makedirs(SND, exist_ok=True)


def h(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


INK = h("1a1622")
GRASS = h("4a7c3f"); GRASS_D = h("3f6b36"); GRASS_L = h("5d9150"); GRASS_DK = h("35592e")
DIRT = h("7a5c3e"); DIRT_D = h("5e4530"); DIRT_L = h("8f6d4c")
ROAD = h("6b6b6f"); ROAD_D = h("58585c"); ROAD_L = h("7d7d82")
ASPH = h("46464c"); ASPH_D = h("383840"); ASPH_L = h("565660")
CONC = h("96948d"); CONC_D = h("7c7a74"); CONC_L = h("aeaca4")
WATER = h("2f6f8f"); WATER_D = h("255a75"); WATER_L = h("4b8fae")
WOOD = h("8a5a34"); WOOD_D = h("6b4426"); WOOD_L = h("a87549")
LEAF = h("2f7d32"); LEAF_D = h("225f28"); LEAF_L = h("4a9d42")
BARK = h("6b4a2e"); BARK_D = h("503520")
METAL = h("a8acb2"); METAL_D = h("787c82"); METAL_L = h("c6cad0")
ORGANIC = h("4caf50"); HAZARD = h("e67828"); GENERAL = h("4078c8"); RECYCLE = h("e8c832")
WHITE = h("f0eee6"); CREAM = h("ddd8c8"); RED = h("c0392b"); GOLD = h("e8b93a")
TOXIC = h("8ad02a"); TOXIC_D = h("5f9a18")
PURPLE = h("7a4fa8"); MAGENTA = h("c04fa0"); BONE = h("e8e2cf")
STEEL = h("6e7a88"); STEEL_D = h("4d5762")


class Canvas:
    def __init__(self, w, hgt):
        self.w = w
        self.h = hgt
        self.d = bytearray(w * hgt * 4)

    def px(self, x, y, col):
        x = int(x); y = int(y)
        if 0 <= x < self.w and 0 <= y < self.h and col[3] > 127:
            i = (y * self.w + x) * 4
            self.d[i] = col[0]; self.d[i + 1] = col[1]; self.d[i + 2] = col[2]; self.d[i + 3] = 255

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 4
            return (self.d[i], self.d[i + 1], self.d[i + 2], self.d[i + 3])
        return (0, 0, 0, 0)

    def rect(self, x, y, w, hgt, col):
        for yy in range(int(y), int(y + hgt)):
            for xx in range(int(x), int(x + w)):
                self.px(xx, yy, col)

    def hline(self, x, y, w, col):
        self.rect(x, y, w, 1, col)

    def vline(self, x, y, hgt, col):
        self.rect(x, y, 1, hgt, col)

    def ellipse(self, cx, cy, rx, ry, col):
        for yy in range(int(cy - ry), int(cy + ry) + 1):
            for xx in range(int(cx - rx), int(cx + rx) + 1):
                dx = (xx - cx) / max(rx, 0.01)
                dy = (yy - cy) / max(ry, 0.01)
                if dx * dx + dy * dy <= 1.0:
                    self.px(xx, yy, col)

    def line(self, x0, y0, x1, y1, col):
        x0 = int(x0); y0 = int(y0); x1 = int(x1); y1 = int(y1)
        dx = abs(x1 - x0); dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            self.px(x0, y0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy; x0 += sx
            if e2 < dx:
                err += dx; y0 += sy

    def outline(self, col=INK):
        """Dark outline around every opaque cluster (adds the 16-bit look)."""
        src = bytearray(self.d)
        w = self.w
        for y in range(self.h):
            for x in range(w):
                i = (y * w + x) * 4
                if src[i + 3] > 127:
                    continue
                near = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < self.h:
                        j = (ny * w + nx) * 4
                        if src[j + 3] > 127:
                            near = True
                            break
                if near:
                    self.px(x, y, col)

    def shade_col(self, x, y, amt):
        c = self.get(x, y)
        if c[3] == 0:
            return
        r = max(0, min(255, c[0] + amt)); g = max(0, min(255, c[1] + amt)); b = max(0, min(255, c[2] + amt))
        self.px(x, y, (r, g, b, 255))

    def shade_rect(self, x, y, w, hgt, amt):
        for yy in range(int(y), int(y + hgt)):
            for xx in range(int(x), int(x + w)):
                self.shade_col(xx, yy, amt)

    def dither(self, x, y, w, hgt, col, phase=0):
        for yy in range(int(y), int(y + hgt)):
            for xx in range(int(x), int(x + w)):
                if (xx + yy + phase) % 2 == 0:
                    self.px(xx, yy, col)

    def blit(self, other, ox, oy, flip=False):
        for y in range(other.h):
            for x in range(other.w):
                c = other.get(other.w - 1 - x if flip else x, y)
                if c[3] > 127:
                    self.px(ox + x, oy + y, c)

    def scaled(self, k):
        out = Canvas(self.w * k, self.h * k)
        for y in range(self.h):
            for x in range(self.w):
                c = self.get(x, y)
                if c[3] > 127:
                    out.rect(x * k, y * k, k, k, c)
        return out

    def save(self, name):
        raw = bytearray()
        w = self.w
        for y in range(self.h):
            raw.append(0)
            raw += self.d[y * w * 4:(y + 1) * w * 4]

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(os.path.join(OUT, name + ".png"), "wb") as f:
            f.write(png)


# ---------------------------------------------------------------- terrain tiles
def make_tiles():
    names = ["grass_a", "grass_b", "grass_c", "dirt_a", "dirt_b", "road_a", "road_b", "concrete", "asphalt", "water"]
    c = Canvas(16 * 5, 16 * 2)
    rng = random.Random(7)
    for i, nm in enumerate(names):
        ox, oy = (i % 5) * 16, (i // 5) * 16
        if nm.startswith("grass"):
            c.rect(ox, oy, 16, 16, GRASS)
            for _ in range(90):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([GRASS_D, GRASS_L, GRASS_DK]))
            for _ in range(4):
                bx, by = rng.randrange(2, 14), rng.randrange(2, 14)
                c.px(ox + bx, oy + by, GRASS_L)
                c.px(ox + bx, oy + by + 1, GRASS_DK)
                c.px(ox + bx + 1, oy + by, GRASS_DK)
        elif nm.startswith("dirt"):
            c.rect(ox, oy, 16, 16, DIRT)
            for _ in range(80):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([DIRT_D, DIRT_L, BARK_D]))
        elif nm.startswith("road"):
            base = ROAD if nm == "road_a" else ROAD_D
            c.rect(ox, oy, 16, 16, base)
            for _ in range(60):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([ROAD_L, ROAD_D, ASPH]))
        elif nm == "concrete":
            c.rect(ox, oy, 16, 16, CONC)
            for _ in range(66):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([CONC_D, CONC_L]))
            if rng.random() < 0.45:
                c.line(ox + rng.randrange(1, 8), oy + rng.randrange(1, 15),
                       ox + rng.randrange(8, 15), oy + rng.randrange(1, 15), CONC_D)
        elif nm == "asphalt":
            c.rect(ox, oy, 16, 16, ASPH)
            for _ in range(70):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([ASPH_D, ASPH_L]))
        else:
            c.rect(ox, oy, 16, 16, WATER)
            for _ in range(50):
                x = rng.randrange(16); y = rng.randrange(16)
                c.px(ox + x, oy + y, rng.choice([WATER_D, WATER_L]))
                if rng.random() < 0.3:
                    c.hline(ox + x, oy + y, 2, WATER_L)
    c.save("tiles")


# ---------------------------------------------------------------- props
def make_tree(dead=False):
    c = Canvas(48, 64)
    if dead:
        c = Canvas(32, 48)
        c.rect(14, 18, 5, 30, BARK_D)
        for (x0, y0, x1, y1) in ((16, 22, 6, 12), (17, 26, 26, 14), (16, 32, 8, 26), (17, 36, 25, 30)):
            c.line(x0, y0, x1, y1, BARK_D)
            c.line(x0 + 1, y0, x1 + 1, y1, BARK)
        c.outline(INK)
        c.save("dead_tree")
        return
    c = Canvas(48, 64)
    c.rect(21, 38, 7, 22, BARK)
    c.rect(26, 38, 2, 22, BARK_D)
    for (cx, cy, rx, ry) in ((16, 30, 13, 12), (33, 30, 13, 12), (24, 38, 12, 10), (24, 18, 15, 13)):
        c.ellipse(cx, cy, rx, ry, LEAF_D)
    for (cx, cy, rx, ry) in ((15, 28, 11, 10), (32, 28, 11, 10), (24, 18, 13, 11)):
        c.ellipse(cx, cy, rx, ry, LEAF)
    for (cx, cy, rx, ry) in ((14, 24, 7, 6), (27, 14, 8, 6), (34, 24, 6, 5)):
        c.ellipse(cx, cy, rx, ry, LEAF_L)
    c.outline(INK)
    c.save("tree")


def make_bush():
    c = Canvas(26, 18)
    c.ellipse(9, 11, 8, 6, LEAF_D)
    c.ellipse(17, 11, 8, 6, LEAF_D)
    c.ellipse(13, 8, 8, 6, LEAF)
    c.ellipse(11, 7, 4, 3, LEAF_L)
    c.outline(INK)
    c.save("bush")


def make_rock():
    c = Canvas(24, 18)
    c.ellipse(12, 11, 11, 7, CONC_D)
    c.ellipse(11, 10, 9, 5, CONC)
    c.ellipse(9, 8, 5, 3, CONC_L)
    c.outline(INK)
    c.save("rock")


def make_house():
    c = Canvas(112, 96)
    # walls
    c.rect(8, 44, 96, 50, CREAM)
    c.rect(8, 44, 5, 50, h("c9c3b2"))
    c.dither(12, 70, 88, 22, h("cfc9b8"), 1)
    # roof
    for i in range(24):
        c.rect(4 + i, 44 - i, 104 - 2 * i, 2, h("8a4b3a") if i % 4 else h("a05a45"))
    c.rect(4, 42, 104, 3, h("6d382b"))
    # door
    c.rect(46, 58, 20, 36, WOOD_D)
    c.rect(48, 60, 16, 34, WOOD)
    c.rect(58, 76, 3, 3, GOLD)
    # windows
    for wx in (20, 78):
        c.rect(wx, 56, 16, 14, h("8fb6c4"))
        c.rect(wx, 56, 16, 3, h("b8d6e0"))
        c.rect(wx + 7, 56, 2, 14, WOOD_D)
        c.rect(wx, 62, 16, 2, WOOD_D)
        c.rect(wx - 1, 55, 18, 16, WOOD_D) if False else None
    # boarded window detail
    c.line(20, 56, 35, 69, WOOD_D)
    c.line(20, 69, 35, 56, WOOD_D)
    c.outline(INK)
    c.save("house")


def make_shack():
    c = Canvas(64, 64)
    for x in range(8, 56, 8):
        c.rect(x, 20, 7, 40, WOOD if (x // 8) % 2 else WOOD_D)
    c.rect(4, 12, 56, 10, METAL_D)
    c.rect(4, 12, 56, 2, METAL)
    c.rect(26, 34, 16, 26, h("3a3028"))
    c.rect(44, 32, 12, 10, h("8fb6c4"))
    c.outline(INK)
    c.save("shack")


def make_car():
    c = Canvas(52, 30)
    c.rect(4, 12, 44, 12, h("a04a3a"))
    c.rect(4, 12, 44, 3, h("c05f4a"))
    c.rect(14, 5, 22, 9, h("a04a3a"))
    c.rect(16, 7, 18, 6, h("8fb6c4"))
    c.rect(4, 22, 44, 3, h("6d3028"))
    for wx in (11, 37):
        c.ellipse(wx, 25, 4, 3, h("2a2620"))
        c.px(wx, 24, METAL_D)
    c.rect(45, 14, 3, 3, GOLD)
    c.outline(INK)
    c.save("car")


def make_barrel():
    c = Canvas(18, 24)
    c.rect(2, 4, 14, 18, h("3f6b4a"))
    c.rect(2, 4, 14, 2, h("578a61"))
    c.rect(2, 9, 14, 2, h("2c4d36"))
    c.rect(2, 16, 14, 2, h("2c4d36"))
    c.rect(4, 20, 10, 2, h("1e3326"))
    c.outline(INK)
    c.save("barrel")


def make_crate():
    c = Canvas(20, 20)
    c.rect(1, 1, 18, 18, WOOD)
    c.rect(1, 1, 18, 2, WOOD_L)
    c.line(1, 1, 18, 18, WOOD_D)
    c.line(18, 1, 1, 18, WOOD_D)
    c.outline(INK)
    c.save("crate")


def make_fence():
    c = Canvas(16, 20)
    c.rect(2, 4, 3, 16, WOOD_D)
    c.rect(1, 8, 14, 2, WOOD)
    c.rect(1, 13, 14, 2, WOOD)
    c.outline(INK)
    c.save("fence")


def make_garbage_pile():
    c = Canvas(34, 24)
    c.ellipse(17, 18, 15, 6, h("4a4438"))
    c.ellipse(11, 14, 8, 7, h("6d6757"))
    c.ellipse(23, 13, 8, 8, h("7c7462"))
    c.ellipse(17, 10, 7, 6, h("8a8170"))
    c.rect(5, 15, 4, 4, h("a04a3a"))
    c.rect(24, 8, 3, 5, h("4078c8"))
    c.rect(15, 6, 4, 3, GOLD)
    c.px(20, 10, h("c8c0b0"))
    c.outline(INK)
    c.save("garbage_pile")


def make_lamp():
    c = Canvas(14, 48)
    c.rect(5, 10, 4, 36, METAL_D)
    c.rect(3, 6, 8, 5, METAL)
    c.rect(2, 2, 10, 5, h("4a4450"))
    c.rect(4, 4, 6, 3, h("f2e6a0"))
    c.outline(INK)
    c.save("lamp")


def make_silo():
    c = Canvas(40, 72)
    c.rect(6, 16, 28, 50, METAL_D)
    for y in range(20, 66, 8):
        c.rect(6, y, 28, 2, METAL)
    c.ellipse(20, 16, 14, 6, METAL)
    c.rect(18, 4, 4, 12, METAL_D)
    c.rect(10, 70, 22, 2, h("3a3a40"))
    c.rect(6, 16, 4, 50, METAL_L)
    c.outline(INK)
    c.save("silo")


def make_dumpster():
    c = Canvas(40, 28)
    c.rect(2, 8, 36, 18, h("3f6b4a"))
    c.rect(2, 6, 36, 4, h("578a61"))
    c.rect(6, 12, 28, 8, h("2c4d36"))
    c.rect(2, 24, 4, 4, h("2a2620")); c.rect(34, 24, 4, 4, h("2a2620"))
    c.outline(INK)
    c.save("dumpster")


def make_shop_stall():
    c = Canvas(72, 64)
    # stall body
    c.rect(4, 26, 64, 34, WOOD)
    c.rect(4, 26, 64, 4, WOOD_L)
    for x in range(4, 68, 8):
        c.rect(x, 30, 1, 30, WOOD_D)
    # awning stripes
    for i in range(8):
        c.rect(2 + i * 9, 10, 9, 14, h("c0392b") if i % 2 == 0 else CREAM)
    c.rect(0, 8, 72, 3, INK)
    c.rect(0, 24, 72, 3, h("8f2b20"))
    # counter + goods
    c.rect(6, 34, 60, 5, WOOD_L)
    c.rect(12, 38, 6, 8, METAL)
    c.rect(24, 39, 5, 7, h("4078c8"))
    c.rect(36, 38, 7, 8, GOLD)
    c.rect(50, 40, 6, 6, ORGANIC)
    c.outline(INK)
    c.save("shop_stall")


# ---------------------------------------------------------------- bins
CATS = [("organic", ORGANIC, h("2e7d32")), ("hazard", HAZARD, h("a4521a")),
        ("general", GENERAL, h("2a5590")), ("recycle", RECYCLE, h("b99a1c"))]


def make_bins():
    for key, col, dark in CATS:
        c = Canvas(22, 28)
        body = col
        c.rect(3, 7, 16, 19, dark)
        c.rect(4, 8, 14, 17, body)
        c.rect(4, 8, 3, 17, h("%02x%02x%02x" % (min(255, col[0] + 30), min(255, col[1] + 30), min(255, col[2] + 30))))
        # lid
        c.rect(1, 3, 20, 5, dark)
        c.rect(2, 4, 18, 3, body)
        c.rect(9, 1, 4, 3, dark)
        # label plate
        c.rect(6, 12, 10, 9, h("f0eee6"))
        if key == "organic":  # leaf
            c.ellipse(11, 16, 3, 2, h("2e7d32"))
            c.line(8, 19, 13, 15, h("2e7d32"))
        elif key == "hazard":  # warning triangle
            for i in range(4):
                c.rect(8 + i, 15 - i // 2, 6 - 2 * i, 1, h("e67828"))
            c.px(10, 16, INK); c.px(10, 17, INK)
        elif key == "general":  # dots
            for (x, y) in ((9, 15), (12, 17), (10, 18)):
                c.px(x, y, h("2a5590"))
                c.px(x + 1, y, h("2a5590"))
        else:  # recycle arrows
            c.rect(9, 14, 5, 2, h("2e7d32")); c.rect(9, 18, 5, 2, h("2e7d32"))
            c.rect(9, 15, 2, 3, h("2e7d32")); c.rect(12, 16, 2, 3, h("2e7d32"))
        # wheels
        c.rect(4, 26, 4, 2, INK)
        c.rect(14, 26, 4, 2, INK)
        c.outline(INK)
        c.save("bin_" + key)


# ---------------------------------------------------------------- waste items (14x14)
def make_waste():
    # banana peel
    c = Canvas(14, 14)
    c.line(3, 4, 7, 9, GOLD); c.line(7, 9, 11, 12, h("c9a227"))
    c.line(3, 5, 6, 9, h("f2d35c")); c.line(8, 10, 11, 12, h("f2d35c"))
    c.line(4, 10, 7, 11, GOLD); c.px(2, 3, h("5a4a20"))
    c.outline(INK); c.save("waste_banana")
    # apple core
    c = Canvas(14, 14)
    c.rect(5, 3, 4, 9, h("d9d2b8"))
    c.rect(4, 4, 1, 7, h("b03a2e")); c.rect(9, 4, 1, 7, h("b03a2e"))
    c.rect(4, 4, 6, 2, h("e8e2cf"))
    c.rect(6, 1, 1, 3, h("4a3a22")); c.px(8, 2, LEAF)
    c.outline(INK); c.save("waste_apple_core")
    # coffee grounds
    c = Canvas(14, 14)
    c.rect(2, 6, 10, 6, h("4a3520"))
    c.ellipse(7, 7, 5, 3, h("6b4a2e"))
    c.rect(3, 3, 8, 3, h("e8e2cf"))
    c.rect(3, 3, 8, 1, h("c9c3b2"))
    c.px(5, 8, h("8a6440")); c.px(9, 9, h("8a6440"))
    c.outline(INK); c.save("waste_coffee")
    # dirty wrapper
    c = Canvas(14, 14)
    c.rect(2, 4, 10, 8, h("b8b29c"))
    c.rect(4, 2, 6, 3, h("cfc9b4"))
    c.rect(5, 6, 5, 4, h("8a7a5a"))
    c.px(9, 5, h("6b5c40")); c.px(4, 9, h("6b5c40"))
    c.outline(INK); c.save("waste_wrapper")
    # tissue
    c = Canvas(14, 14)
    c.ellipse(7, 8, 5, 4, WHITE)
    c.ellipse(9, 6, 3, 3, CREAM)
    c.px(5, 9, h("cfc9b8")); c.px(8, 10, h("cfc9b8"))
    c.outline(INK); c.save("waste_tissue")
    # chip bag
    c = Canvas(14, 14)
    c.rect(3, 2, 8, 11, h("c9cdd2"))
    c.rect(3, 2, 8, 2, h("9aa0a6"))
    c.rect(4, 5, 6, 4, RED)
    c.px(4, 12, h("9aa0a6"))
    c.outline(INK); c.save("waste_chipbag")
    # foam cup
    c = Canvas(14, 14)
    c.rect(4, 4, 6, 9, WHITE)
    c.rect(3, 2, 8, 3, CREAM)
    c.rect(5, 6, 2, 5, h("d0cabb"))
    c.outline(INK); c.save("waste_cup")
    # hazard: battery
    c = Canvas(14, 14)
    c.rect(3, 3, 8, 9, h("2a2a30"))
    c.rect(3, 3, 8, 3, h("4fa83a"))
    c.rect(3, 10, 8, 2, h("8a8f96"))
    c.rect(9, 1, 2, 2, METAL)
    c.rect(5, 6, 1, 3, WHITE); c.rect(7, 6, 1, 3, WHITE); c.px(6, 7, WHITE)
    c.outline(INK); c.save("waste_battery")
    # hazard: fluorescent tube
    c = Canvas(14, 14)
    c.rect(1, 6, 12, 3, WHITE)
    c.rect(1, 6, 12, 1, h("bfe6f0"))
    c.rect(0, 6, 2, 3, METAL_D); c.rect(12, 6, 2, 3, METAL_D)
    c.line(3, 9, 4, 11, h("9aa0a6"))
    c.outline(INK); c.save("waste_tube")
    # hazard: chemical can
    c = Canvas(14, 14)
    c.rect(3, 3, 8, 10, h("b03a2e"))
    c.rect(3, 3, 8, 2, h("d4533f"))
    c.rect(6, 1, 3, 2, h("8a2a20"))
    c.rect(5, 6, 4, 4, h("f0eee6"))
    c.px(6, 8, h("b03a2e")); c.px(7, 8, h("b03a2e")); c.px(7, 7, h("b03a2e"))
    c.outline(INK); c.save("waste_chemcan")
    # hazard: circuit board
    c = Canvas(14, 14)
    c.rect(2, 3, 10, 8, h("2f6b3a"))
    c.rect(2, 3, 10, 1, h("3f8a4a"))
    c.rect(4, 5, 3, 2, h("d4b552")); c.rect(8, 7, 3, 2, h("d4b552"))
    c.rect(2, 10, 10, 1, GOLD)
    c.outline(INK); c.save("waste_circuit")
    # recycle: plastic bottle
    c = Canvas(14, 14)
    c.rect(5, 4, 4, 8, h("bfe0ea"))
    c.rect(5, 4, 1, 8, h("e8f4f8"))
    c.rect(5, 2, 4, 2, h("2a7fa8"))
    c.rect(6, 1, 2, 1, h("2a7fa8"))
    c.rect(4, 8, 6, 2, h("8ac5d8"))
    c.outline(INK); c.save("waste_bottle")
    # recycle: glass bottle
    c = Canvas(14, 14)
    c.rect(5, 5, 4, 7, h("2e7d4a"))
    c.rect(5, 5, 1, 7, h("4aa86a"))
    c.rect(6, 1, 2, 4, h("2e7d4a"))
    c.rect(5, 11, 4, 1, h("1d5230"))
    c.outline(INK); c.save("waste_glass")
    # recycle: aluminium can
    c = Canvas(14, 14)
    c.rect(4, 3, 6, 9, h("c6cad0"))
    c.rect(4, 3, 2, 9, h("e2e6ea"))
    c.rect(4, 5, 6, 3, RED)
    c.rect(5, 2, 4, 1, METAL_D)
    c.outline(INK); c.save("waste_can")
    # recycle: cardboard
    c = Canvas(14, 14)
    c.rect(2, 4, 10, 8, WOOD)
    c.rect(2, 4, 10, 1, WOOD_L)
    c.rect(6, 4, 2, 8, h("c9b48a"))
    c.rect(4, 7, 2, 2, h("2e7d32")); c.px(8, 8, h("2e7d32"))
    c.outline(INK); c.save("waste_cardboard")
    # special: industrial drum
    c = Canvas(14, 14)
    c.rect(3, 2, 8, 11, h("3f6b4a"))
    c.rect(3, 4, 8, 1, h("2c4d36")); c.rect(3, 9, 8, 1, h("2c4d36"))
    c.rect(5, 6, 4, 3, GOLD)
    c.px(6, 7, INK); c.px(7, 7, INK)
    c.outline(INK); c.save("waste_drum")


# ---------------------------------------------------------------- enemies (strips of 4)
def enemy_sheet(name, w, hgt, fn):
    c = Canvas(w * 4, hgt)
    for f in range(4):
        part = Canvas(w, hgt)
        fn(part, f)
        c.blit(part, f * w, 0)
    c.save(name)


def enemy_runner(c, f):
    bob = 1 if f in (1, 3) else 0
    body = h("8a5a9e"); dark = h("5e3a6e"); light = h("a870bc")
    for i, lx in enumerate((5, 8, 14, 17)):
        off = ((f + i) % 2) * 2
        c.rect(lx, 15 - off, 2, 5 + off, dark)
    c.ellipse(12, 11 - bob, 7, 6, dark)
    c.ellipse(12, 10 - bob, 6, 5, body)
    c.ellipse(10, 8 - bob, 3, 2, light)
    c.rect(9, 6 - bob, 2, 2, MAGENTA)
    c.rect(14, 6 - bob, 2, 2, MAGENTA)
    c.px(9, 6 - bob, WHITE); c.px(14, 6 - bob, WHITE)


def enemy_brute(c, f):
    bob = 1 if f in (1, 3) else 0
    body = h("6e6a5a"); dark = h("4a4738"); light = h("8a8470")
    c.rect(6, 24, 8, 6, dark); c.rect(18, 24, 8, 6, dark)
    c.rect(4, 12 - bob, 24, 14, dark)
    c.rect(6, 10 - bob, 20, 14, body)
    c.rect(6, 10 - bob, 6, 14, light)
    c.rect(10, 4 - bob, 12, 8, dark)
    c.rect(11, 5 - bob, 10, 6, body)
    c.rect(12, 7 - bob, 2, 2, GOLD); c.rect(18, 7 - bob, 2, 2, GOLD)
    c.rect(3, 14 - bob, 3, 10, dark); c.rect(26, 14 - bob, 3, 10, dark)


def enemy_toxic(c, f):
    bob = 1 if f in (1, 3) else 0
    body = h("7ab82a"); dark = h("54861a"); light = h("a8e04a")
    c.ellipse(14, 20, 10, 6, dark)
    c.ellipse(14, 18 - bob, 9, 7, body)
    c.ellipse(11, 15 - bob, 4, 3, light)
    c.rect(10, 15 - bob, 2, 2, INK); c.rect(16, 15 - bob, 2, 2, INK)
    c.rect(9, 21, 2, 3, dark); c.rect(17, 22, 2, 4, dark)
    for (x, y, r) in ((6, 12, 2), (22, 13, 2), (14, 8, 1)):
        c.ellipse(x, y - bob, r, r, light)


def enemy_swarm(c, f):
    bob = 1 if f in (1, 3) else 0
    body = h("4a4258"); dark = h("2e2838"); light = h("6b5f7c")
    for dx in (-5, 5):
        c.line(8 + dx // 2, 9 - bob, 8 + dx, 7 - bob, dark)
        c.line(8 + dx // 2, 11 - bob, 8 + dx, 13 - bob, dark)
    c.ellipse(8, 10 - bob, 5, 4, dark)
    c.ellipse(8, 9 - bob, 4, 3, body)
    c.rect(6, 8 - bob, 2, 1, h("e04a4a"))
    c.px(5, 7 - bob, light)


# ---------------------------------------------------------------- icons (24x24)
def icon(name, fn):
    c = Canvas(24, 24)
    fn(c)
    c.outline(INK)
    c.save("icon_" + name)


def icon_baton(c):
    c.rect(11, 4, 3, 13, METAL_D)
    c.rect(11, 4, 2, 12, METAL)
    c.rect(12, 2, 2, 3, h("4a90c8"))
    c.rect(9, 16, 7, 4, STEEL_D)
    c.rect(10, 17, 5, 2, STEEL)


def icon_ion_baton(c):
    c.rect(11, 4, 3, 13, STEEL_D)
    c.rect(11, 4, 2, 12, h("6ec8e8"))
    c.rect(8, 2, 9, 3, h("2f8fc0"))
    c.rect(9, 16, 7, 5, STEEL_D)
    c.rect(10, 17, 5, 2, h("4a90c8"))
    c.px(15, 3, h("a8e8ff"))


def icon_servo_maul(c):
    c.rect(10, 8, 4, 13, STEEL_D)
    c.rect(3, 1, 18, 8, METAL_D)
    c.rect(4, 2, 16, 6, METAL)
    c.rect(4, 2, 16, 2, METAL_L)
    c.rect(12, 8, 3, 3, h("d04a3a"))


def icon_shield(c):
    c.rect(5, 4, 14, 10, h("3f6b8a"))
    c.rect(5, 4, 14, 2, h("6ea8c8"))
    for i in range(6):
        c.rect(6 + i, 14 + i // 2, 12 - 2 * i, 1, h("3f6b8a"))
    c.rect(10, 7, 4, 7, h("a8d8e8"))


def icon_armor(c):
    c.rect(5, 4, 14, 12, h("5a6470"))
    c.rect(5, 4, 5, 12, h("7a8490"))
    c.rect(9, 3, 6, 4, h("8a94a0"))
    c.rect(8, 8, 8, 2, h("3a424c"))
    c.rect(10, 12, 4, 3, GOLD)


def icon_flashlight(c):
    c.rect(4, 10, 10, 5, STEEL_D)
    c.rect(4, 10, 10, 2, STEEL)
    c.rect(14, 8, 5, 9, h("3a424c"))
    c.rect(18, 9, 3, 7, h("f2e6a0"))
    c.rect(5, 15, 8, 2, h("2a3038"))


def icon_grabber(c):
    c.line(4, 20, 16, 6, METAL_D); c.line(5, 20, 17, 6, METAL)
    c.line(16, 6, 20, 3, METAL_D); c.line(16, 6, 13, 2, METAL_D)
    c.rect(3, 19, 4, 4, h("c04a3a"))
    c.rect(19, 2, 2, 2, h("c04a3a")); c.rect(12, 1, 2, 2, h("c04a3a"))


def icon_gloves(c):
    c.rect(7, 8, 10, 10, h("d8a83a"))
    c.rect(7, 8, 3, 10, h("f0c45a"))
    for i, x in enumerate((8, 11, 14, 17)):
        c.rect(x, 3 + (i % 2), 2, 6, h("d8a83a"))
        c.rect(x, 3 + (i % 2), 1, 5, h("f0c45a"))
    c.rect(6, 17, 12, 3, h("b88a28"))


def icon_bags(c):
    c.rect(6, 6, 12, 14, h("2a2a30"))
    c.rect(6, 6, 3, 14, h("3c3c46"))
    c.rect(9, 3, 6, 4, h("4a4a56"))
    c.rect(8, 10, 8, 5, h("8ad02a"))
    c.px(10, 12, INK); c.px(13, 12, INK)


def icon_trolley(c):
    c.rect(4, 8, 16, 9, h("3f6b4a"))
    c.rect(4, 8, 16, 2, h("578a61"))
    c.line(4, 8, 2, 4, METAL_D); c.line(20, 8, 22, 4, METAL_D)
    c.ellipse(7, 19, 3, 3, INK); c.ellipse(17, 19, 3, 3, INK)
    c.rect(9, 11, 6, 4, h("2c4d36"))


def icon_broom(c):
    c.line(4, 20, 18, 4, WOOD); c.line(5, 20, 19, 4, WOOD_D)
    c.rect(3, 14, 8, 8, h("8a7a5a"))
    c.rect(4, 15, 6, 7, h("b8a878"))
    c.rect(15, 5, 8, 4, METAL_D)
    c.rect(16, 6, 6, 2, METAL)


def icon_sortbox(c):
    c.rect(3, 7, 18, 12, h("4a6f8a"))
    c.rect(3, 7, 18, 3, h("6ea8c8"))
    c.rect(3, 11, 9, 8, h("e8c832"))
    c.rect(13, 11, 8, 8, h("4caf50"))
    c.rect(9, 12, 1, 7, INK)


def icon_boots(c):
    c.rect(6, 5, 8, 10, h("3f8a4a"))
    c.rect(6, 5, 3, 10, h("5aa864"))
    c.rect(6, 14, 14, 5, h("2a5c32"))
    c.rect(6, 18, 14, 2, h("1e3d24"))


def icon_mask(c):
    c.rect(5, 8, 14, 9, WHITE)
    c.rect(5, 8, 14, 2, CREAM)
    c.line(5, 8, 1, 5, CREAM); c.line(19, 8, 23, 5, CREAM)
    c.rect(8, 11, 8, 4, h("d8d4c4"))
    c.rect(9, 12, 6, 2, h("b8b4a4"))


def icon_cart(c):
    c.rect(3, 6, 14, 10, h("3f6b8a"))
    c.rect(3, 6, 14, 2, h("6ea8c8"))
    c.rect(3, 11, 14, 5, h("e8c832"))
    c.line(17, 8, 22, 8, METAL_D); c.line(22, 8, 22, 16, METAL_D)
    c.ellipse(6, 19, 3, 3, INK); c.ellipse(14, 19, 3, 3, INK)


def icon_ikit(c):
    c.rect(3, 8, 18, 12, h("3a424c"))
    c.rect(3, 8, 18, 3, h("5a6470"))
    c.rect(9, 5, 6, 4, h("5a6470"))
    c.rect(10, 12, 4, 4, GOLD)
    c.px(10, 13, INK); c.px(11, 13, INK); c.px(10, 14, INK); c.px(11, 14, INK)
    c.rect(5, 15, 2, 2, h("d04a3a")); c.rect(17, 15, 2, 2, h("4aa84a"))


def icon_medkit(c):
    c.rect(3, 7, 18, 12, WHITE)
    c.rect(3, 7, 18, 2, CREAM)
    c.rect(10, 10, 4, 7, RED)
    c.rect(8, 12, 8, 3, RED)
    c.rect(9, 5, 6, 3, h("c9c3b2"))


def icon_scrap(c):
    c.rect(4, 9, 16, 7, METAL_D)
    c.rect(5, 10, 14, 5, METAL)
    c.rect(7, 6, 5, 4, METAL_D)
    c.rect(13, 13, 5, 4, METAL_D)
    c.px(9, 12, h("d8dce2")); c.px(16, 11, h("d8dcce"))


def icon_coin(c):
    c.ellipse(12, 12, 9, 9, h("b88a18"))
    c.ellipse(12, 12, 7, 7, GOLD)
    c.rect(10, 8, 4, 8, h("f2d05a"))
    c.rect(10, 8, 1, 8, h("fff0b0"))


def icon_recycle(c):
    c.ellipse(12, 12, 10, 10, h("2e7d32"))
    c.ellipse(12, 12, 8, 8, h("4caf50"))
    c.line(8, 15, 12, 8, WHITE); c.line(12, 8, 16, 15, WHITE); c.line(9, 16, 15, 16, WHITE)


# ---------------------------------------------------------------- effects
def make_light():
    sz = 256
    c = Canvas(sz, sz)
    cx = cy = sz / 2
    for y in range(sz):
        for x in range(sz):
            d = math.hypot(x - cx, y - cy) / (sz / 2)
            a = max(0.0, 1.0 - d)
            a = a * a * 255
            if a > 1:
                c.px(x, y, (255, 240, 200, int(a)))
    c.save("light")


def make_dot():
    c = Canvas(6, 6)
    c.ellipse(3, 3, 2.5, 2.5, WHITE)
    c.save("dot")


def make_shadow():
    c = Canvas(20, 10)
    c.ellipse(10, 5, 9, 4, (0, 0, 0, 90))
    for y in range(10):
        for x in range(20):
            col = c.get(x, y)
            if col[3] > 127:
                c.px(x, y, (20, 16, 24, 90))
    c.save("shadow")


def make_toxic_spot():
    c = Canvas(64, 64)
    rng = random.Random(11)
    c.ellipse(32, 32, 30, 24, (95, 154, 24, 210))
    c.ellipse(32, 32, 26, 20, (138, 208, 42, 210))
    c.ellipse(30, 30, 18, 13, (168, 224, 74, 210))
    for _ in range(40):
        a = rng.random() * math.tau
        r = rng.random() * 24
        x = 32 + math.cos(a) * r
        y = 32 + math.sin(a) * r * 0.75
        c.ellipse(x, y, 2, 2, (78, 132, 18, 210))
    for _ in range(12):
        c.ellipse(rng.randrange(14, 50), rng.randrange(18, 46), 2, 1, (208, 240, 120, 210))
    c.save("toxic_spot")


def make_swing():
    # 3-frame arc swipe
    c = Canvas(64 * 3, 64)
    for f in range(3):
        part = Canvas(64, 64)
        r0 = 12 + f * 5
        r1 = 22 + f * 5
        span = math.radians(70 + f * 20)
        steps = 40
        for i in range(steps):
            a = -span / 2 + span * i / steps
            x = 32 + math.cos(a) * (r0 + r1) / 2
            y = 32 + math.sin(a) * (r0 + r1) / 2
            part.ellipse(x, y, 3, 3, (255, 255, 255, 210 - f * 40))
            part.ellipse(x, y, 1, 1, (200, 240, 255, 255))
        c.blit(part, f * 64, 0)
    c.save("swing")


# ---------------------------------------------------------------- audio
SR = 22050


def write_wav(name, samples):
    path = os.path.join(SND, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))


def env(i, n, atk=0.01, dec=3.0):
    t = i / SR
    a = min(1.0, i / max(1, atk * SR))
    return a * math.exp(-dec * t)


def sfx_tone(name, f0, f1, dur, kind="square", dec=6.0, vol=0.4, noise=0.0):
    n = int(SR * dur)
    out = []
    rng = random.Random(hash(name) & 0xFFFF)
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (i / n)
        ph = math.sin(math.tau * f * t)
        if kind == "square":
            v = 1.0 if ph > 0 else -1.0
            v *= 0.7
        elif kind == "saw":
            v = (f * t) % 1.0 * 2 - 1
        else:
            v = ph
        if noise:
            v = v * (1 - noise) + (rng.random() * 2 - 1) * noise
        out.append(v * env(i, n, 0.004, dec) * vol)
    write_wav(name, out)


def sfx_hit(name):
    n = int(SR * 0.16)
    out = []
    rng = random.Random(5)
    for i in range(n):
        t = i / SR
        noise = (rng.random() * 2 - 1) * math.exp(-30 * t)
        tone = math.sin(math.tau * (150 - 60 * i / n) * t) * math.exp(-14 * t)
        out.append((noise * 0.5 + tone * 0.5) * 0.5)
    write_wav(name, out)


def make_audio():
    sfx_tone("pick", 620, 980, 0.08, "square", 10, 0.28)
    sfx_tone("sort_ok", 700, 700, 0.06, "square", 12, 0.26)
    sfx_tone("buy", 880, 1500, 0.16, "square", 7, 0.28)
    sfx_tone("sort_bad", 200, 90, 0.24, "saw", 6, 0.32)
    sfx_tone("swing", 420, 180, 0.1, "saw", 12, 0.22, noise=0.6)
    sfx_tone("hurt", 260, 110, 0.22, "square", 8, 0.3, noise=0.25)
    sfx_tone("die", 420, 60, 0.5, "square", 4, 0.28, noise=0.15)
    sfx_tone("phase", 180, 400, 0.7, "square", 2, 0.24)
    sfx_tone("levelup", 520, 1240, 0.45, "square", 3, 0.28)
    sfx_tone("clean", 300, 900, 0.3, "sine", 5, 0.26)
    sfx_tone("click", 900, 900, 0.04, "square", 20, 0.2)
    sfx_tone("alarm", 300, 300, 0.5, "saw", 1.5, 0.22)
    sfx_hit("hit")
    sfx_hit("enemy_die")


def main():
    make_tiles()
    make_tree()
    make_tree(dead=True)
    make_bush()
    make_rock()
    make_house()
    make_shack()
    make_car()
    make_barrel()
    make_crate()
    make_fence()
    make_garbage_pile()
    make_lamp()
    make_silo()
    make_dumpster()
    make_shop_stall()
    make_bins()
    make_waste()
    enemy_sheet("enemy_runner", 20, 22, enemy_runner)
    enemy_sheet("enemy_brute", 32, 32, enemy_brute)
    enemy_sheet("enemy_toxic", 28, 28, enemy_toxic)
    enemy_sheet("enemy_swarm", 16, 16, enemy_swarm)
    icon("baton", icon_baton)
    icon("ion_baton", icon_ion_baton)
    icon("servo_maul", icon_servo_maul)
    icon("shield", icon_shield)
    icon("armor", icon_armor)
    icon("flashlight", icon_flashlight)
    icon("grabber", icon_grabber)
    icon("gloves", icon_gloves)
    icon("bags", icon_bags)
    icon("trolley", icon_trolley)
    icon("broom", icon_broom)
    icon("sortbox", icon_sortbox)
    icon("boots", icon_boots)
    icon("mask", icon_mask)
    icon("cart", icon_cart)
    icon("ikit", icon_ikit)
    icon("medkit", icon_medkit)
    icon("scrap", icon_scrap)
    icon("coin", icon_coin)
    icon("recycle", icon_recycle)
    make_light()
    make_dot()
    make_shadow()
    make_toxic_spot()
    make_swing()
    make_audio()
    files = sorted(os.listdir(OUT))
    print("sprites:", len(files))
    print("sfx:", len(os.listdir(SND)))


if __name__ == "__main__":
    main()
