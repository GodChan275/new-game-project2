"""Extra pixel-art UI icons (24x24), drawn with the same Canvas and palette as
gen_art.py so the HUD shortcuts and the touch buttons stop using letters and
borrowed equipment icons.

Run: python tools/gen_ui_icons.py
Writes Assets/Sprites/icon_{bag,quest,map,shop,pause,keyboard,phone}.png
plus a 4x contact sheet (tools/../Assets/Sprites/ui_icons_preview.png) for review.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_art as ga  # noqa: E402


def icon_bag(c):
    c.rect(6, 7, 12, 13, ga.h("7a5c3e"))
    c.rect(7, 8, 4, 11, ga.h("8f6d4c"))
    c.rect(8, 3, 8, 5, ga.h("6b4426"))
    c.rect(9, 4, 6, 2, ga.h("8a5a34"))
    c.rect(10, 5, 4, 1, ga.GOLD)
    c.rect(9, 17, 6, 1, ga.h("5e4530"))


def icon_quest(c):
    c.rect(5, 3, 14, 17, ga.CREAM)
    c.rect(5, 3, 14, 3, ga.h("d8c8a8"))
    c.rect(5, 18, 14, 2, ga.h("b8a878"))
    c.rect(8, 8, 8, 1, ga.h("7c7a74"))
    c.rect(8, 11, 8, 1, ga.h("7c7a74"))
    c.rect(8, 14, 5, 1, ga.h("7c7a74"))
    c.rect(14, 13, 4, 4, ga.GOLD)
    c.rect(15, 14, 2, 2, ga.h("b88a18"))


def icon_map(c):
    c.rect(3, 4, 18, 16, ga.CREAM)
    c.rect(3, 4, 18, 2, ga.h("d8c8a8"))
    c.vline(9, 4, 16, ga.h("b8a878"))
    c.vline(15, 4, 16, ga.h("b8a878"))
    c.rect(4, 8, 4, 3, ga.h("4a9d42"))
    c.rect(11, 12, 3, 3, ga.h("4a9d42"))
    c.rect(16, 7, 3, 3, ga.h("4a9d42"))
    c.rect(4, 15, 3, 2, ga.h("2f6f8f"))
    c.rect(17, 14, 2, 4, ga.h("7a5c3e"))
    c.rect(7, 9, 2, 2, ga.RED)
    c.rect(13, 16, 2, 2, ga.RED)


def icon_shop(c):
    for i in range(4):
        c.rect(3 + i * 5, 4, 5, 4, ga.RED if i % 2 == 0 else ga.CREAM)
    c.rect(3, 8, 18, 2, ga.WOOD_D)
    c.rect(4, 10, 16, 9, ga.WOOD)
    c.rect(4, 10, 16, 1, ga.WOOD_L)
    c.rect(9, 12, 6, 7, ga.h("5e4530"))
    c.rect(15, 13, 3, 3, ga.GOLD)


def icon_pause(c):
    c.rect(7, 4, 4, 16, ga.CREAM)
    c.rect(13, 4, 4, 16, ga.CREAM)
    c.rect(7, 4, 1, 16, ga.h("b8b4a4"))
    c.rect(13, 4, 1, 16, ga.h("b8b4a4"))


def icon_keyboard(c):
    c.rect(2, 7, 20, 11, ga.METAL_D)
    c.rect(3, 8, 18, 8, ga.METAL)
    for row in range(3):
        for key in range(6):
            c.rect(4 + key * 3, 9 + row * 2, 2, 1, ga.STEEL_D)
    c.rect(9, 15, 6, 1, ga.STEEL_D)
    c.rect(3, 16, 18, 1, ga.METAL_L)


def icon_phone(c):
    c.rect(7, 2, 10, 20, ga.h("3a424c"))
    c.rect(8, 4, 8, 14, ga.h("2f4a35"))
    c.rect(9, 5, 6, 1, ga.h("6ea8c8"))
    c.rect(9, 8, 3, 3, ga.h("4a9d42"))
    c.rect(13, 12, 2, 2, ga.GOLD)
    c.rect(11, 19, 2, 1, ga.CREAM)


ICONS = [
    ("bag", icon_bag),
    ("quest", icon_quest),
    ("map", icon_map),
    ("shop", icon_shop),
    ("pause", icon_pause),
    ("keyboard", icon_keyboard),
    ("phone", icon_phone),
]


def make_slash_ring():
	"""Soft white ring used for the 360 degree mobile sweep."""
	size = 96
	c = ga.Canvas(size, size)
	cx = cy = (size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			d = math.hypot(x - cx, y - cy)
			if 28.0 <= d <= 47.0:
				t = max(0.0, 1.0 - abs(d - 37.0) / 9.0)
				a = int(225 * (t ** 1.3))
				if a > 4:
					c.px(x, y, (226, 244, 255, a))
	c.save("slash_ring")
	print("wrote Assets/Sprites/slash_ring.png")


def contact_sheet(canvases, scale=4):
    cell = 24 * scale
    sheet = ga.Canvas(cell * len(canvases), cell)
    sheet.rect(0, 0, sheet.w, sheet.h, ga.h("2c3a30"))
    for i, c in enumerate(canvases):
        for y in range(24):
            for x in range(24):
                col = c.get(x, y)
                if col[3] > 127:
                    sheet.rect(i * cell + x * scale, y * scale, scale, scale, col)
    sheet.save("ui_icons_preview")


def main():
    canvases = []
    for name, fn in ICONS:
        c = ga.Canvas(24, 24)
        fn(c)
        c.outline(ga.INK)
        c.save("icon_" + name)
        canvases.append(c)
        print("wrote Assets/Sprites/icon_%s.png" % name)
    make_slash_ring()
    contact_sheet(canvases)


if __name__ == "__main__":
    main()
