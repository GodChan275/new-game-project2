"""Build a scaled contact sheet from generated sprites for visual review."""
import os, struct, zlib, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "Assets", "Sprites")


def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos = 8
    w = h = 0
    idat = b""
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + ln]
        if tag == b"IHDR":
            w, h, depth, ctype, comp, filt, inter = struct.unpack(">IIBBBBB", payload)
            assert depth == 8 and ctype == 6 and inter == 0, (path, depth, ctype, inter)
        elif tag == b"IDAT":
            idat += payload
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * 4
    rows = []
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p + stride]); p += stride
        if f == 1:
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        rows.append(bytes(line))
        prev = line
    return w, h, rows


def write_png(path, w, h, rows):
    raw = bytearray()
    for r in rows:
        raw.append(0)
        raw += r
    def chunk(tag, d):
        return struct.pack(">I", len(d)) + tag + d + struct.pack(">I", zlib.crc32(tag + d) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main(names, scale=4, cols=8, pad=8):
    imgs = []
    for n in names:
        p = os.path.join(SPR, n + ".png")
        if not os.path.exists(p):
            continue
        imgs.append((n, read_png(p)))
    cell_w = max(i[1][0] for i in imgs) * scale
    cell_h = max(i[1][1] for i in imgs) * scale
    rows_n = (len(imgs) + cols - 1) // cols
    W = cols * (cell_w + pad) + pad
    H = rows_n * (cell_h + pad) + pad
    canvas = [bytearray(b"\x30\x34\x3c\xff" * W) for _ in range(H)]
    for idx, (n, (w, h, rows)) in enumerate(imgs):
        cx = pad + (idx % cols) * (cell_w + pad)
        cy = pad + (idx // cols) * (cell_h + pad)
        for y in range(H):
            pass
        for y in range(h):
            r = rows[y]
            for x in range(w):
                px = r[x * 4:x * 4 + 4]
                if px[3] < 8:
                    continue
                for dy in range(scale):
                    row = canvas[cy + y * scale + dy]
                    for dx in range(scale):
                        o = (cx + x * scale + dx) * 4
                        row[o:o + 4] = px
    write_png(os.path.join(ROOT, "tools", "sheet.png"), W, H, canvas)
    print("wrote tools/sheet.png", W, H, len(imgs), "sprites")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args:
        main(args)
    else:
        main(["bin_organic", "bin_hazard", "bin_general", "bin_recycle", "tree", "bush", "rock",
              "house", "shack", "car", "barrel", "crate", "dumpster", "silo", "shop_stall", "garbage_pile",
              "waste_banana", "waste_apple_core", "waste_coffee", "waste_wrapper", "waste_tissue", "waste_chipbag",
              "waste_cup", "waste_battery", "waste_tube", "waste_chemcan", "waste_circuit", "waste_bottle",
              "waste_glass", "waste_can", "waste_cardboard", "waste_drum"], scale=4, cols=8)
