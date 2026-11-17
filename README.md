# Toxic Wasteland: Survive & Recycle

A top-down pixel-art survival / cleanup RPG for **Godot 4.7**.
Wander a compact abandoned forest village, collect litter, sort it into the right
bins, fight invaders, keep the pollution down and finish seven days.

---

## Running

1. Open the folder in **Godot 4.7** (`project.godot`).
2. Press **F5** — the game starts on the main menu (`GameEntry.tscn`).

Viewport 480×270 with `canvas_items` stretch: the layout is identical at 1280×720,
1600×900 and 1920×1080. Nearest-neighbour filtering, pixel-perfect art.

## Web build (HTML5)

The **Web** export preset writes a browser build to `build/web/`:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
python tools/serve_web.py 8099        # → http://127.0.0.1:8099/index.html
```

It runs on the **Compatibility** renderer (WebGL 2), which Godot forces for the
web platform, so the `Forward+` desktop look is approximated by the 2D canvas
path. Open it through a server — `file://` cannot load the `.wasm`/`.pck`
modules. Thread support is off in the preset, so no COOP/COEP headers are needed.
The generated `index.html` plus `index.js`, `index.wasm` and `index.pck` must keep
those exact names.

## The map

A hand-placed **56×56 tile** village (16 px tiles, 896×896 world) — small enough to
cross in seconds, dense enough to explore.

| Area | Thai | Contents |
| --- | --- | --- |
| Safe clearing | พื้นที่ปลอดภัย | Shop stall, storage shed, four bins, lamps, signs, starting point |
| Forest | พื้นที่ป่า | Five tree varieties, dead trees, bushes, stones, logs, mushrooms, flowers |
| Pond | สระน้ำ | Sand-rimmed pond with lily pads, reeds and a wooden deck |
| Ruins | พื้นที่ร้าง | Collapsed cottage with vines, broken fences, wrecked car, litter |
| Waste yard | พื้นที่จัดการขยะ | Recycling station, four bins, dumpsters, drums, garbage piles, silo |
| Toxic ground | พื้นที่พิษ | Mud, dead grass, invader spawns and toxic spills |

Dirt paths link the shop, the recycling station, the ruins, the pond and the toxic
zone. Ground is a `TileMapLayer` with 18 tiles (grass variants, dirt, path, sand,
water, concrete, rubble); everything else is reusable sprite props with baked
shadows, sorted by `y_sort`.

Art is generated procedurally:

```
python tools/gen_env.py       # ground atlas, trees, bushes, pond, deck, ruin, station…
python tools/gen_waste_icons.py  # extra waste icons (orange peel, bulb, newspaper, foam, bag, veg)
python tools/gen_ui_icons.py      # HUD/touch action icons (bag, quest, map, shop, pause, keyboard, phone)
python tools/preview_env.py   # 2x contact sheet of the environment props
```

## Camera

`Script/CameraController.gd` on the `Camera` node:

- smooth follow with look-ahead (`position_smoothing` replaced by a lerp),
- **mouse wheel** zoom, 0.8× – 1.85×, eased, stepped in 0.12 increments,
- clamped to the map bounds so the void is never visible,
- ignores wheel input while a panel is open.

## HUD — gameplay first

Small, semi-transparent chips anchored to the corners, text with dark outlines:
the world stays the dominant element. The permanent layer covers roughly 4 % of
the screen instead of the old ~18 %.

| Region | Element |
| --- | --- |
| Top left | Compact status, 55×16 (≈220×65 at 1080p): portrait, name, level, HP and stamina. Click for a details card (HP/energy numbers, weapon, bag, pollution) that closes itself after 6 s. Below 30 % HP the border pulses. |
| Left | Borderless quest tracker: at most three objectives with title + counter, collapsible with the ▾ header. A finished objective shows ✓ and disappears after 1.6 s. `J` opens the book. |
| Top right | One-line **วันที่ · เวลา · เงิน** strip. Click it for phase, pollution bar, main objective and counters; it closes after 6 s and steps the minimap aside while open. |
| Top right, below | 34×34 minimap (zones, bins, shop, station, storage, litter, invaders, player). Click to expand to 96×96, click again to collapse. `M` fades it out. |
| Bottom centre | Six icon-only hotbar slots with `1`–`6` labels, gold selection, cooldown fills and a Med Kit count. |
| Above the hotbar | Context prompt that exists only next to something usable — `E เก็บ ขวดพลาสติก`, `E ทิ้งขยะ · F คัดแยก` — and fades the moment you walk away. |
| Bottom right | Four 12 px icon buttons: map, bag, shop, pause. |

Secondary HUD (tracker and status strip) fades to 50 % after five still seconds and
returns on movement, interaction, invasion or low HP; HP itself is never dimmed.
`Esc` → pause → **ขนาดหน้าจอ** cycles the HUD scale 85 / 100 / 115 / 130 %.

A small animated notification appears at the upper centre when a quest completes:
**“ภารกิจสำเร็จ!”** + **“ได้รับเงินรางวัล ฿N”** (or “รางวัล ฿N · กด J เพื่อรับ” for
main/special quests).

## Quests

`Script/QuestManager.gd` runs four categories:

- **ภารกิจหลัก** — the day's main objective (collect 12 + 3·day pieces), reward ฿140, claimed from the book.
- **ภารกิจประจำวัน** — five missions: collect 10, sort 5 recyclables, sort 3 hazardous,
  kill 5 invaders, drop pollution below 30 % (targets scale daily). Auto-paid.
- **ภารกิจเสริม** — buy a tool, clean spills, survive an invasion. Auto-paid.
- **ภารกิจพิเศษ** — lifetime goals (25 kills, 150 collected, survive 3 days), reward ฿220.

Progress updates live from pickups, sorting, kills, cleaning, purchases, pollution
changes and surviving an invasion. `J` opens the **quest book**:

```
สมุดภารกิจ
┌────────────┬──────────────────┬───────────────────────┐
│ ภารกิจหลัก  │ ✓ เก็บขยะ 10 ชิ้น │ category · title       │
│ ประจำวัน    │ □ แยกขยะรีไซเคิล 5│ description            │
│ เสริม       │ □ กำจัดศัตรู 5 ตัว │ progress bar + 3/10    │
│ พิเศษ       │ …                │ reward + XP · รับรางวัล │
└────────────┴──────────────────┴───────────────────────┘
         รับรางวัลทั้งหมด                          ✕
```

## Platform selection (PC / touch)

The first launch opens **CHOOSE YOUR PLATFORM** (`DeviceSelection.tscn`): two
parchment cards, the matching device marked แนะนำ, and the pick is stored in
`user://toxic_wasteland.cfg`. Later launches skip the screen.

| Mode | Movement | Actions |
| --- | --- | --- |
| PC / DESKTOP | WASD / arrows, mouse aim | E, F, Q, I, J, M, Esc, 1–6 |
| MOBILE | analog joystick, lower-left, 360°, multi-touch | attack + interact circles, skill, item, bag, quest, map, pause |

Mobile aims along the joystick, uses touch wording in the prompt
(`แตะ เก็บ …`), hides the desktop shortcut column and keeps the lower corners
free for the overlay. Layout comes from `AdaptiveHUD.gd`, so both modes share
one table — Mobile is not a scaled-down desktop HUD.

Switch any time in **ตั้งค่า › โหมดควบคุม** or the pause panel
(อัตโนมัติ / PC / มือถือ). The mode only changes input and layout, so position,
inventory, quests and world state carry over. Saved alongside it: HUD scale,
joystick/button size, button opacity and movement sensitivity. Touch detection
only sets the recommendation; it never forces a mode.

## Controls

| Input | Action |
| --- | --- |
| `WASD` / arrows | Move |
| Mouse | Aim |
| Left mouse | Attack |
| Wheel | Zoom in / out |
| `Shift` | Sprint |
| `E` | Collect · sort at a bin · shop · clean a spill |
| `Space` | Same contextual interaction |
| `F` | Bulk sort / use a Med Kit |
| `Q` | Sweep skill (hits nearby enemies, pulls litter in; 9 s cooldown) |
| `I` / `Tab` | Inventory |
| `J` | Quest book |
| `M` | Hide / show the minimap (UI only) |
| `1`–`6` | Action bar slots |
| `Esc` | Pause / close panel |

## Garbage identification

Every litter object carries its own id, so the prompt and the bag show the real
item — not the category:

```
E เก็บ ขวดพลาสติก            E เก็บ หลอดไฟ
E ทิ้งขยะ · F คัดแยก         E เก็บ เปลือกส้ม
```

Pickup: **“เก็บขวดพลาสติกแล้ว”**. Correct bin: **“ทิ้งขวดพลาสติกถูกต้อง!”**
plus **“ได้รับเงิน +฿10”**. Wrong bin: **“ทิ้งขยะผิดประเภท!”** (fine + pollution).
The bag groups stacks and labels each with the item name and `×N`.

## Background music

Two loops, both shipped in `Assets/Music/`:

| Track | When |
| --- | --- |
| `Day_Song.mp3` | Morning — exploring, collecting, sorting |
| `Night_song.mp3` | Invasion — night lighting, invaders, flashlight |

`Music` (autoload) listens to `GameManager.phase_changed` and **crossfades over
2 s** between them, using two players so neither track drops out. The music
survives scene changes (menu → game → menu), loops at load, and sits at −19 dB
under the SFX; the settings volume controls it together with the SFX, and
`Music.play_day()` / `Music.play_night()` force a track.

Replace either file with your own `.mp3`/`.ogg`/`.wav` of the same name — looping
and the crossfade are applied at load, no code change needed.

## Waste categories

| Bin | Thai | Examples | Pay |
| --- | --- | --- | --- |
| Green | ขยะเปียก | peels, food scraps, coffee grounds | low |
| Orange | ขยะอันตราย | batteries, tubes, chemicals, e-waste | high |
| Blue | ขยะทั่วไป | wrappers, tissues, mixed trash | low |
| Yellow | ขยะรีไซเคิล | bottles, cans, cardboard | medium |

Correct bin pays and grants XP; a wrong bin refuses the item, fines you and adds
pollution. `F` bulk-sorts everything belonging to the bin you face. Gloves gate
hazardous items, the Industrial Kit gates drums.

## Pollution

Ground litter (full weight), carried litter (reduced), toxic spills and penalties.
Bands: 0–30 สิ่งแวดล้อมสะอาด, 31–60 มลพิษปานกลาง, 61–80 มลพิษสูง, 81–100 พิษระบาด
(critical warning, spreading spills, hazard damage). Boots and mask cut toxic damage;
gloves let you clean spills for money.

## Fonts

`Assets/Fonts` ships with **Noto Sans Thai** (Thai) and **Silkscreen** (pixel Latin).
Thai is a per-glyph fallback, so Thai and English mix without missing-glyph boxes.

The requested **Pixel Game.otf** and **Pixel Game Extrude.otf** are not in the
project. Drop them into `Assets/Fonts/` with those exact names and they are used
automatically on the next launch (body and title) — no code changes.

## Project layout

```
GameEntry.tscn / .gd            entry scene, hosts the menu
MainMenu.tscn / .gd             cinematic forest menu, settings, help, credits
Main.tscn / .gd                 game root, spawner, camera + world wiring
HUD.tscn / HUD.gd               HUD host: layout, minimap, overlays, quest notifications
PlayerStatusPanel · QuestPanel · ObjectivePanel · ActionBar (.tscn/.gd)  — compact HUD
MobileControls.tscn / .gd      touch joystick + action buttons
DeviceSelection.tscn / .gd     first-run platform chooser
AdaptiveHUD.gd                 PC / mobile layout table
QuestMenu.tscn / .gd            quest book
Map.tscn / Map.gd               compact village map, zones, props, bins, spawns
CameraController.gd             smooth follow + wheel zoom
Player.tscn / PlayerController.gd
Enemy.tscn / EnemyAI.gd · Garbage*.tscn · ToxicZone.tscn · GarbageBin.tscn
Shop.tscn / ShopUI.gd · Inventory.tscn / InventoryUI.gd
Script/ autoloads: UI · InputSetup · Platform · InputHub · Art · Sfx · Music · ItemDB · Economy · Inventory ·
  Garbage · Pollution · Sorting · Shop · DayNight · Quests · Combat · GameManager
tools/gen_art.py · tools/gen_env.py · tools/preview_env.py
```

## Tuning

- `Map.gd` — `W`/`H`, zone rects, `_paths`, `_setup_regions`, prop placement.
- `CameraController.gd` — `ZOOM_MIN`, `ZOOM_MAX`, `FOLLOW_SPEED`.
- `QuestManager.gd` — `DAILY_POOL`, `MAIN_REWARD`, `SPECIAL_REWARD`, rewards.
- `GameManager.gd` — `morning_duration`, `invasion_duration`, `TOTAL_DAYS`.
- `ItemDB.gd` — waste, weapons, equipment, prices, Thai names and descriptions.
- `EnemyAI.STATS`, `PollutionManager.capacity()`, `PlayerController.SKILL_COOLDOWN`.
