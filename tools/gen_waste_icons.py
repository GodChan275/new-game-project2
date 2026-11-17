"""Extra 14x14 waste item icons (matches the existing waste art style).

Pure stdlib PNG writer, same conventions as tools/gen_art.py.
Run: python tools/gen_waste_icons.py
"""
import os
import struct
import zlib

OUT = os.path.join("Assets", "Sprites")

CLEAR = (0, 0, 0, 0)
INK = (38, 34, 30, 255)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[CLEAR for _ in range(w)] for _ in range(h)]

    def dot(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[int(y)][int(x)] = c

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.dot(xx, yy, c)

    def disc(self, cx, cy, r, c):
        for yy in range(self.h):
            for xx in range(self.w):
                if (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r:
                    self.dot(xx, yy, c)

    def outline(self, c=INK):
        src = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x][3] != 0:
                    continue
                near = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[ny][nx][3] > 0:
                        near = True
                        break
                if near:
                    self.px[y][x] = c
        return self

    def save(self, name):
        raw = b""
        for row in self.px:
            raw += b"\x00" + b"".join(bytes(p) for p in row)
        def chunk(tag, data):
            body = tag + data
            return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(raw, 9))
        png += chunk(b"IEND", b"")
        with open(os.path.join(OUT, name + ".png"), "wb") as f:
            f.write(png)


def orange_peel():
    c = Canvas(14, 14)
    # crescent peel: outer rind, inner pith, flesh segments
    for y in range(4, 13):
        for x in range(2, 13):
            d = ((x - 7.5) / 5.4) ** 2 + ((y - 7.0) / 4.6) ** 2
            if 0.55 <= d <= 1.0 and y >= 6:
                c.dot(x, y, (214, 108, 34, 255))
            elif d < 0.55 and y >= 7:
                c.dot(x, y, (247, 186, 92, 255))
    for x in range(4, 11, 2):
        for y in range(8, 12):
            if ((x - 7.5) / 5.4) ** 2 + ((y - 7.0) / 4.6) ** 2 < 0.5:
                c.dot(x, y, (236, 148, 52, 255))
    return c.outline().save("waste_orange")


def vegetable_scraps():
    c = Canvas(14, 14)
    c.rect(6, 7, 2, 6, (96, 128, 58, 255))       # stem
    for y in range(1, 8):
        w = 6 - abs(y - 3)
        for x in range(7 - w, 7 + w + 1):
            if (x + y) % 5 != 0:
                c.dot(x, y, (74, 138, 60, 255))
    for x in range(2, 7):
        for y in range(4, 9):
            if (x - y) % 4 != 0:
                c.dot(x, y, (108, 168, 72, 255))
    c.rect(3, 9, 4, 2, (150, 92, 48, 255))       # carrot chunk
    return c.outline().save("waste_veg")


def light_bulb():
    c = Canvas(14, 14)
    c.disc(7, 5.5, 4.0, (246, 232, 168, 255))
    c.disc(6, 4.5, 1.6, (255, 250, 214, 255))
    c.rect(5, 9, 4, 1, (156, 152, 138, 255))
    c.rect(5, 10, 4, 1, (128, 124, 112, 255))
    c.rect(5, 11, 4, 1, (156, 152, 138, 255))
    c.rect(6, 12, 2, 1, (96, 92, 86, 255))
    return c.outline().save("waste_bulb")


def newspaper():
    c = Canvas(14, 14)
    c.rect(2, 3, 10, 8, (236, 232, 214, 255))
    c.rect(2, 3, 10, 1, (206, 202, 184, 255))
    c.rect(3, 5, 4, 1, (120, 118, 110, 255))
    c.rect(3, 7, 8, 1, (150, 148, 138, 255))
    c.rect(3, 9, 8, 1, (150, 148, 138, 255))
    c.rect(8, 4, 3, 2, (188, 186, 172, 255))
    return c.outline().save("waste_newspaper")


def foam_box():
    c = Canvas(14, 14)
    c.rect(2, 5, 10, 7, (240, 240, 232, 255))
    c.rect(1, 4, 12, 2, (250, 250, 244, 255))
    c.rect(2, 9, 10, 1, (214, 214, 204, 255))
    c.rect(6, 4, 2, 2, (222, 222, 212, 255))
    return c.outline().save("waste_foambox")


def plastic_bag():
    c = Canvas(14, 14)
    c.rect(3, 5, 8, 7, (214, 224, 230, 255))
    c.rect(4, 3, 2, 2, (196, 208, 216, 255))
    c.rect(8, 3, 2, 2, (196, 208, 216, 255))
    c.rect(5, 4, 4, 1, (170, 186, 196, 255))
    c.rect(5, 7, 2, 2, (168, 186, 196, 255))
    c.rect(8, 9, 2, 2, (168, 186, 196, 255))
    return c.outline().save("waste_bag")


if __name__ == "__main__":
    orange_peel()
    vegetable_scraps()
    light_bulb()
    newspaper()
    foam_box()
    plastic_bag()
    print("wrote 6 waste icons to", OUT)
