"""Composite the generated environment sprites into one review sheet (2x)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_env as g

items = [
    g.make_tree(101, 64, 88), g.make_tree(102, 58, 78), g.make_tree(103, 50, 68),
    g.make_tree(104, 42, 58), g.make_tree(105, 64, 96, True),
    g.make_dead_tree(21), g.make_stump(31), g.make_bush(41), g.make_bush(44, True),
    g.make_rock(91), g.make_rock(93, False), g.make_log(81), g.make_mushroom(71),
    g.make_flowers(51, True), g.make_tuft(61), g.make_fence_broken(8),
    g.make_sign(2), g.make_deck(3), g.make_station(4), g.make_shed(6), g.make_ruin(9),
]

SHEET_W = 800
canvas = g.Canvas(SHEET_W, 460)
canvas.rect(0, 0, SHEET_W, 460, g.GRASS)
for _ in range(2400):
    import random
    rng = random.Random(_)
    canvas.px(rng.randrange(SHEET_W), rng.randrange(460), rng.choice([g.GRASS_D, g.GRASS_L]))

x, y, rowh = 6, 6, 0
for c in items:
    c2 = c.scaled(2)
    if x + c2.w + 6 > SHEET_W:
        x = 6
        y += rowh + 6
        rowh = 0
    canvas.blit(c2, x, y)
    x += c2.w + 6
    rowh = max(rowh, c2.h)
canvas.save("preview_env")
print("ok", canvas.w, canvas.h)
