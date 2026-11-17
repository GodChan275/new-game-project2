"""Environment art for the forest-village map (Sprout Lands inspired).

Pure stdlib PNG writer. Outputs 16px-scale props + a 16x16 ground atlas into
Assets/Sprites. Run: python tools/gen_env.py
"""
import math
import os
import random
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets", "Sprites")
os.makedirs(OUT, exist_ok=True)


def h(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


OUTLINE = h("2c3a30")
GRASS = h("6fbf4e"); GRASS_L = h("8ad45f"); GRASS_D = h("58a63f"); GRASS_DD = h("3f8232")
LEAF = h("3f8f3a"); LEAF_L = h("58ad45"); LEAF_D = h("2c6b31"); LEAF_DD = h("1f4f26")
TRUNK = h("9a6a44"); TRUNK_D = h("74502f"); TRUNK_L = h("b98554")
WATER = h("6fd2c8"); WATER_D = h("47b3ad"); WATER_L = h("a6e7df")
SAND = h("e8d9a4"); SAND_D = h("cfbc84")
STONE = h("9fada5"); STONE_D = h("7b8a82"); STONE_L = h("c0ccc2")
WOOD = h("b98554"); WOOD_D = h("96683f"); WOOD_L = h("d2a26d")
PLANK = h("c08e5b")
PINK = h("f0a2bf"); WHITE = h("f4f0e2"); YELLOW = h("f2d05a")
MUD = h("7a6248"); MUD_D = h("63503a")
SHADOW = h("4b8f3f")


class Canvas:
    def __init__(self, w, hgt):
        self.w = w
        self.h = hgt
        self.d = bytearray(w * hgt * 4)

    def px(self, x, y, col):
        x = int(x); y = int(y)
        if 0 <= x < self.w and 0 <= y < self.h and col[3] > 0:
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

    def outline(self, col=OUTLINE):
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

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                c = other.get(x, y)
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

    def save(self, name, scale=1):
        c = self.scaled(scale) if scale > 1 else self
        raw = bytearray()
        w = c.w
        for y in range(c.h):
            raw.append(0)
            raw += c.d[y * w * 4:(y + 1) * w * 4]

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", c.w, c.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(os.path.join(OUT, name + ".png"), "wb") as f:
            f.write(png)


def with_shadow(c, shadow_w=None, shadow_h=4, y=None):
    """Composite a soft ground shadow beneath an already-drawn sprite."""
    w = c.w
    sw = shadow_w if shadow_w else int(w * 0.36)
    sy = y if y is not None else c.h - 5
    out = Canvas(w, c.h)
    out.ellipse(w / 2, sy, sw, shadow_h, SHADOW)
    out.blit(c, 0, 0)
    return out


# ------------------------------------------------------------------ ground
def make_ground():
    c = Canvas(16 * 6, 16 * 3)
    rng = random.Random(11)
    for i in range(18):
        ox, oy = (i % 6) * 16, (i // 6) * 16
        kind = i
        if kind in (0, 1, 2, 3, 4, 5):
            base = GRASS if kind != 3 else GRASS_D
            c.rect(ox, oy, 16, 16, base)
            for _ in range(70):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16),
                     rng.choice([GRASS_D, GRASS_L, GRASS_DD, GRASS]))
            for _ in range(5 if kind == 4 else 0):
                fx, fy = rng.randrange(2, 14), rng.randrange(2, 14)
                c.px(ox + fx, oy + fy, YELLOW)
                c.px(ox + fx + 1, oy + fy, PINK if rng.random() < 0.5 else YELLOW)
            if kind == 5:
                for _ in range(16):
                    c.px(ox + rng.randrange(16), oy + rng.randrange(16), h("6aa84a"))
        elif kind in (6, 7, 8):
            c.rect(ox, oy, 16, 16, h("b99a6b"))
            for _ in range(60):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16),
                     rng.choice([h("a98a5c"), h("c8ab7c"), h("9a7c52")]))
            for _ in range(3 if kind == 7 else 0):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), STONE)
        elif kind == 9:
            c.rect(ox, oy, 16, 16, SAND)
            for _ in range(50):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([SAND_D, h("f0e2b4")]))
        elif kind == 10:
            c.rect(ox, oy, 16, 16, MUD)
            for _ in range(55):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([MUD_D, h("8a7050")]))
        elif kind == 11:
            c.rect(ox, oy, 16, 16, GRASS_D)
            for _ in range(40):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([GRASS_DD, GRASS]))
        elif kind == 12:
            c.rect(ox, oy, 16, 16, WATER)
            for _ in range(40):
                x, y = rng.randrange(16), rng.randrange(16)
                c.px(ox + x, oy + y, rng.choice([WATER_D, WATER_L]))
        elif kind == 13:
            c.rect(ox, oy, 16, 16, WATER_D)
            for _ in range(30):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), WATER)
        elif kind in (14, 15):
            c.rect(ox, oy, 16, 16, h("c8c2ae"))
            for _ in range(45):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([h("b5ae99"), h("dad4c0")]))
            if kind == 15:
                c.hline(ox, oy, 16, h("b5ae99"))
                c.vline(ox + 7, oy, 16, h("b5ae99"))
        elif kind == 16:
            c.rect(ox, oy, 16, 16, h("8e948a"))
            for _ in range(45):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), rng.choice([h("7b827a"), h("a3a99f")]))
        else:
            c.rect(ox, oy, 16, 16, GRASS_D)
            c.rect(ox, oy, 16, 8, GRASS)
            for _ in range(30):
                c.px(ox + rng.randrange(16), oy + rng.randrange(16), GRASS_DD)
    c.save("ground")


# ------------------------------------------------------------------ trees
def clump(cx, cy, rx, ry, rng, dark=False):
    """One outlined foliage clump; stacked clumps give the reference look."""
    w = int(rx * 2) + 6
    hgt = int(ry * 2) + 6
    cc = Canvas(w, hgt)
    base = LEAF_D if dark else LEAF
    cc.ellipse(w / 2, hgt / 2, rx, ry, base)
    cc.ellipse(w / 2 - rx * 0.12, hgt / 2 - ry * 0.22, rx * 0.74, ry * 0.60, base if dark else LEAF_L)
    for _ in range(max(3, int(rx * 1.4))):
        cc.rect(w / 2 - rx * 0.62 + rng.random() * rx * 1.0,
                hgt / 2 - ry * 0.58 + rng.random() * ry * 0.75, 2, 2, LEAF_L if not dark else LEAF)
    for _ in range(max(2, int(rx * 1.2))):
        cc.px(w / 2 - rx * 0.7 + rng.random() * rx * 1.4,
              hgt / 2 + ry * 0.10 + rng.random() * ry * 0.65, LEAF_DD)
    cc.outline(OUTLINE)
    return cc


def canopy(c, cx, cy, rx, ry, rng, flower=False):
    spots = [
        (0.0, 0.02, 1.0, 0.94), (-0.52, 0.30, 0.60, 0.58), (0.54, 0.28, 0.60, 0.58),
        (-0.30, -0.50, 0.62, 0.56), (0.32, -0.52, 0.56, 0.52), (0.0, 0.52, 0.60, 0.50),
        (-0.66, -0.12, 0.44, 0.44), (0.66, -0.14, 0.44, 0.44), (0.05, -0.72, 0.42, 0.40),
    ]
    for i, (ox, oy, sx, sy) in enumerate(spots):
        cl = clump(0, 0, rx * sx, ry * sy, rng, dark=(i < 3))
        c.blit(cl, cx + ox * rx - cl.w / 2, cy + oy * ry - cl.h / 2)
    if flower:
        for _ in range(9):
            a = rng.random() * math.tau
            d = rng.random() * 0.62
            px = cx + math.cos(a) * rx * d
            py = cy + math.sin(a) * ry * d - ry * 0.1
            c.px(px, py, PINK); c.px(px + 1, py, WHITE); c.px(px, py + 1, WHITE)


def make_tree(seed, w, hgt, flower=False):
    rng = random.Random(seed)
    c = Canvas(w, hgt)
    tx = w // 2
    trunk_top = int(hgt * 0.54)
    tw = max(6, int(w * 0.13))
    th = hgt - trunk_top - 5
    c.rect(tx - tw // 2, trunk_top, tw, th, TRUNK)
    c.rect(tx - tw // 2, trunk_top, max(2, tw // 3), th, TRUNK_L)
    c.rect(tx + tw // 2 - 2, trunk_top, 2, th, TRUNK_D)
    for _ in range(4):
        yy = trunk_top + rng.randrange(2, max(3, th - 2))
        c.hline(tx - tw // 2 + 1, yy, tw - 2, TRUNK_D)
    c.rect(tx - tw // 2 - 3, hgt - 6, tw + 6, 3, TRUNK_D)
    c.px(tx - tw // 2 - 4, hgt - 5, TRUNK_D)
    c.px(tx + tw // 2 + 3, hgt - 5, TRUNK_D)
    # canopy
    canopy(c, tx, int(hgt * 0.34), int(w * 0.44), int(hgt * 0.32), rng, flower)
    c.outline()
    # shadow ellipse under
    out = Canvas(w, hgt)
    out.ellipse(tx, hgt - 4, int(w * 0.34), 3, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_dead_tree(seed):
    rng = random.Random(seed)
    w, hgt = 34, 54
    c = Canvas(w, hgt)
    tx = w // 2
    c.rect(tx - 2, 16, 5, hgt - 20, TRUNK_D)
    c.rect(tx - 2, 16, 2, hgt - 20, TRUNK)
    for _ in range(5):
        y = rng.randrange(18, 38)
        side = rng.choice([-1, 1])
        c.line(tx, y, tx + side * rng.randrange(6, 12), y - rng.randrange(4, 10), TRUNK_D)
    c.outline()
    out = Canvas(w, hgt)
    out.ellipse(tx, hgt - 3, 8, 2, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_stump(seed):
    rng = random.Random(seed)
    c = Canvas(20, 16)
    c.ellipse(10, 10, 8, 5, TRUNK_D)
    c.ellipse(10, 8, 7, 4, TRUNK)
    c.ellipse(10, 7, 5, 3, TRUNK_L)
    c.px(8, 7, TRUNK_D); c.px(12, 8, TRUNK_D)
    c.outline()
    out = Canvas(20, 16)
    out.ellipse(10, 13, 8, 2, h("4c9140"))
    out.blit(c, 0, 0)
    return out


# ------------------------------------------------------------------ plants
def make_bush(seed, flower=False):
    rng = random.Random(seed)
    w, hgt = 30, 22
    c = Canvas(w, hgt)
    for (bx, by, rx, ry, dark) in ((9, 14, 8, 6, True), (21, 14, 8, 6, True), (15, 10, 9, 6, False), (10, 8, 5, 4, False)):
        cl = clump(0, 0, rx, ry, rng, dark)
        c.blit(cl, bx - cl.w / 2, by - cl.h / 2)
    if flower:
        for _ in range(6):
            x, y = rng.randrange(5, 26), rng.randrange(4, 16)
            c.px(x, y, PINK); c.px(x + 1, y, WHITE)
    out = Canvas(w, hgt)
    out.ellipse(15, hgt - 2, 10, 2, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_flowers(seed, pink=True):
    rng = random.Random(seed)
    c = Canvas(18, 14)
    for _ in range(4):
        x, y = rng.randrange(2, 15), rng.randrange(4, 12)
        c.line(x, y, x, y + 3, GRASS_D)
        col = PINK if pink else WHITE
        c.px(x, y, col); c.px(x - 1, y, col); c.px(x + 1, y, col); c.px(x, y - 1, col)
        c.px(x, y + 1, YELLOW)
    c.save_dummy = True
    return c


def make_tuft(seed):
    rng = random.Random(seed)
    c = Canvas(14, 12)
    for _ in range(5):
        x = rng.randrange(3, 11)
        c.line(x, 11, x + rng.randrange(-2, 3), rng.randrange(3, 8), GRASS_D)
    c.px(rng.randrange(4, 10), 4, GRASS_L)
    return c


def make_mushroom(seed):
    rng = random.Random(seed)
    c = Canvas(16, 14)
    c.rect(7, 8, 2, 5, WHITE)
    c.ellipse(8, 7, 6, 4, h("c9503f"))
    c.ellipse(6, 5, 2, 1, WHITE)
    c.ellipse(10, 6, 1, 1, WHITE)
    c.outline()
    return c


def make_log(seed):
    rng = random.Random(seed)
    c = Canvas(30, 18)
    c.ellipse(15, 12, 13, 5, TRUNK_D)
    c.ellipse(15, 10, 12, 4, TRUNK)
    c.ellipse(24, 10, 4, 4, TRUNK_L)
    c.ellipse(24, 10, 2, 2, TRUNK_D)
    c.line(6, 9, 20, 9, TRUNK_L)
    c.outline()
    out = Canvas(30, 18)
    out.ellipse(15, 16, 12, 2, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_rock(seed, big=True):
    rng = random.Random(seed)
    w, hgt = (26, 20) if big else (16, 12)
    c = Canvas(w, hgt)
    c.ellipse(w / 2, hgt * 0.62, w * 0.44, hgt * 0.38, STONE_D)
    c.ellipse(w / 2, hgt * 0.55, w * 0.38, hgt * 0.32, STONE)
    c.ellipse(w * 0.42, hgt * 0.46, w * 0.18, hgt * 0.14, STONE_L)
    c.outline()
    out = Canvas(w, hgt)
    out.ellipse(w / 2, hgt - 2, w * 0.36, 2, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_pebbles(seed):
    rng = random.Random(seed)
    c = Canvas(18, 12)
    for _ in range(4):
        x, y = rng.randrange(2, 15), rng.randrange(2, 10)
        c.ellipse(x, y, rng.randrange(1, 3), 1, STONE)
        c.px(x, y - 1, STONE_L)
    return c


# ------------------------------------------------------------------ pond
def make_pond(seed=5):
    rng = random.Random(seed)
    w, hgt = 224, 160
    c = Canvas(w, hgt)
    cx, cy = w / 2, hgt / 2
    # sand rim (irregular)
    c.ellipse(cx, cy, 106, 74, SAND)
    c.ellipse(cx, cy + 2, 100, 70, SAND_D)
    c.ellipse(cx, cy, 98, 68, SAND)
    # water
    c.ellipse(cx, cy, 92, 62, WATER_D)
    c.ellipse(cx, cy - 2, 88, 58, WATER)
    c.ellipse(cx - 6, cy - 6, 78, 48, WATER)
    # ripple highlights
    for _ in range(26):
        a = rng.random() * math.tau
        d = rng.random() * 0.85
        x = cx + math.cos(a) * 78 * d
        y = cy + math.sin(a) * 46 * d
        c.hline(x, y, rng.randrange(3, 9), WATER_L)
    # lily pads
    for (lx, ly, r) in ((cx - 34, cy - 14, 9), (cx + 20, cy + 12, 11), (cx + 46, cy - 20, 7),
                        (cx - 12, cy + 24, 8), (cx + 8, cy - 30, 6)):
        c.ellipse(lx, ly, r, r * 0.72, h("4f9d3f"))
        c.ellipse(lx, ly - 1, r - 2, r * 0.55, h("66bd4e"))
        c.rect(lx, ly, int(r * 0.7), 1, WATER)
    # reed clumps at edges
    for _ in range(9):
        a = rng.random() * math.tau
        x = cx + math.cos(a) * 96
        y = cy + math.sin(a) * 66
        for k in range(3):
            c.line(x + k, y, x + k, y - rng.randrange(4, 8), GRASS_D)
    # edge stones
    for _ in range(12):
        a = rng.random() * math.tau
        x = cx + math.cos(a) * 101
        y = cy + math.sin(a) * 71
        c.ellipse(x, y, 3, 2, STONE)
        c.px(x, y - 1, STONE_L)
    c.save("pond")


def make_deck(seed=3):
    w, hgt = 104, 72
    c = Canvas(w, hgt)
    # legs
    c.rect(10, 44, 5, 26, WOOD_D)
    c.rect(88, 44, 5, 26, WOOD_D)
    c.rect(4, 66, 96, 4, h("6b4a30"))
    # platform
    c.rect(4, 26, 96, 24, PLANK)
    for x in range(4, 100, 12):
        c.rect(x, 26, 11, 24, WOOD if (x // 12) % 2 else PLANK)
        c.vline(x + 11, 26, 24, WOOD_D)
    c.rect(4, 24, 96, 3, WOOD_L)
    c.rect(4, 47, 96, 3, WOOD_D)
    c.outline()
    out = Canvas(w, hgt)
    out.ellipse(w / 2, hgt - 2, 44, 3, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_sign(seed=2):
    c = Canvas(22, 30)
    c.rect(9, 12, 4, 16, WOOD_D)
    c.rect(2, 4, 18, 10, WOOD)
    c.rect(2, 4, 18, 2, WOOD_L)
    c.rect(4, 7, 14, 1, WOOD_D)
    c.rect(4, 10, 9, 1, WOOD_D)
    c.outline()
    out = Canvas(22, 30)
    out.ellipse(11, 28, 6, 2, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_ruin(seed=9):
    """Abandoned cottage with vines and a collapsed roof."""
    rng = random.Random(seed)
    w, hgt = 104, 88
    c = Canvas(w, hgt)
    # walls
    c.rect(8, 40, 88, 40, h("d8ccae"))
    c.rect(8, 40, 88, 3, h("c2b696"))
    c.rect(8, 76, 88, 4, h("b0a488"))
    for x in range(12, 92, 16):
        c.vline(x, 44, 32, h("c8bc9e"))
    # roof (broken)
    for i in range(20):
        c.rect(4 + i, 40 - i, 96 - 2 * i, 2, h("8a5a44") if i % 4 else h("a3735a"))
    c.rect(56, 6, 30, 22, (0, 0, 0, 0))
    for yy in range(8, 30):
        for xx in range(58, 84):
            if (xx - 58) + (yy - 8) < 24:
                c.px(xx, yy, (0, 0, 0, 0))
    # door + window
    c.rect(42, 56, 18, 24, h("5a4230"))
    c.rect(44, 58, 14, 22, h("3a2c20"))
    c.rect(20, 50, 14, 12, h("7fa6b4"))
    c.rect(20, 50, 14, 2, h("a8ccd8"))
    c.line(20, 50, 34, 62, WOOD_D)
    # vines
    for _ in range(7):
        x = rng.randrange(10, 92)
        y0 = rng.randrange(30, 46)
        for k in range(rng.randrange(6, 16)):
            c.px(x + int(math.sin(k * 0.6) * 2), y0 + k, h("4f9d3f"))
            if k % 4 == 0:
                c.px(x + 1 + int(math.sin(k * 0.6) * 2), y0 + k, h("66bd4e"))
    c.outline()
    out = Canvas(w, hgt)
    out.ellipse(w / 2, hgt - 2, 46, 4, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_station(seed=4):
    """Recycling station: green awning, sorting table, crates."""
    c = Canvas(84, 72)
    c.rect(6, 30, 72, 34, WOOD)
    c.rect(6, 30, 72, 3, WOOD_L)
    for x in range(8, 78, 9):
        c.vline(x, 33, 29, WOOD_D)
    # awning
    for i in range(8):
        c.rect(2 + i * 10, 14, 10, 14, h("4f9d3f") if i % 2 == 0 else WHITE)
    c.rect(0, 12, 84, 3, h("37702c"))
    c.rect(0, 26, 84, 3, h("37702c"))
    # posts
    c.rect(4, 26, 3, 38, WOOD_D)
    c.rect(76, 26, 3, 38, WOOD_D)
    # counter goods: bins/crates
    c.rect(12, 40, 12, 12, h("4078c8"))
    c.rect(12, 38, 12, 3, h("2a5590"))
    c.rect(30, 42, 12, 10, h("e8c832"))
    c.rect(48, 40, 14, 12, WOOD_L)
    c.line(48, 40, 62, 52, WOOD_D)
    c.line(62, 40, 48, 52, WOOD_D)
    c.rect(14, 56, 14, 4, h("37702c"))
    c.outline()
    out = Canvas(84, 72)
    out.ellipse(42, 68, 36, 4, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_shed(seed=6):
    c = Canvas(58, 62)
    c.rect(6, 22, 46, 34, WOOD)
    for x in range(8, 52, 7):
        c.vline(x, 22, 34, WOOD_D)
    c.rect(4, 16, 50, 8, h("8a5a44"))
    c.rect(4, 14, 50, 3, h("a3735a"))
    c.rect(24, 34, 12, 22, h("5a4230"))
    c.rect(25, 35, 10, 20, h("3a2c20"))
    c.px(33, 45, YELLOW)
    c.outline()
    out = Canvas(58, 62)
    out.ellipse(29, 58, 25, 3, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def make_fence_broken(seed=8):
    rng = random.Random(seed)
    c = Canvas(32, 22)
    c.rect(3, 6, 3, 15, WOOD_D)
    c.rect(24, 8, 3, 13, WOOD_D)
    c.rect(2, 9, 26, 2, WOOD)
    c.rect(2, 15, 26, 2, WOOD)
    c.rect(12, 8, 2, 4, (0, 0, 0, 0))
    del rng
    c.outline()
    out = Canvas(32, 22)
    out.ellipse(16, 20, 12, 2, h("4c9140"))
    out.blit(c, 0, 0)
    return out


def main():
    make_ground()
    for i, (w, hgt) in enumerate(((64, 88), (58, 78), (50, 68), (42, 58), (64, 96)), start=1):
        make_tree(100 + i, w, hgt, flower=(i == 5)).save("tree_%d" % i)
    make_dead_tree(21).save("tree_dead_1")
    make_dead_tree(22).save("tree_dead_2")
    make_stump(31).save("stump")
    for i in range(1, 4):
        make_bush(40 + i).save("bush_%d" % i)
    make_bush(44, flower=True).save("bush_flower")
    make_flowers(51, True).save("flowers_pink")
    make_flowers(52, False).save("flowers_white")
    make_tuft(61).save("tuft_1")
    make_tuft(62).save("tuft_2")
    make_mushroom(71).save("mushroom")
    make_log(81).save("log")
    make_rock(91).save("rock_1")
    make_rock(92).save("rock_2")
    make_rock(93, False).save("rock_small")
    make_pebbles(95).save("pebbles")
    make_pond()
    make_deck()
    make_sign()
    make_ruin().save("house_ruin")
    make_station().save("station")
    make_shed().save("shed")
    make_fence_broken().save("fence_broken")

    # preview sheet (3x) for review
    names = ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5", "tree_dead_1", "bush_1",
             "bush_flower", "rock_1", "log", "stump", "mushroom", "flowers_pink", "tuft_1"]
    sheet = Canvas(3 * 560, 3 * 200)
    x = 6
    for n in names:
        path = os.path.join(OUT, n + ".png")
        if not os.path.exists(path):
            continue
        # read back png is overkill: rebuild via stored canvas is not kept; skip decode
        del path
    del sheet, x
    print("environment sprites written:", len([f for f in os.listdir(OUT) if f.endswith('.png')]))


if __name__ == "__main__":
    main()
