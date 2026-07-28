"""Export every detected sprite as its own trimmed PNG plus a contact sheet.

The contact sheet renders each sprite isolated on a checkerboard so that
mis-detected cells (clipped edges, two sprites in one cell) are obvious.
"""
import os
import json
from PIL import Image, ImageDraw

SRC = r"D:\flutter_proj\Embercrest Run\assets"
PREVIEW = r"D:\flutter_proj\Embercrest Run\tools\preview"
OUT = r"D:\flutter_proj\Embercrest Run\build_assets\sprites"

CELL = 190
COLS = 10


def checkerboard(size, step=12):
    img = Image.new("RGB", size, (235, 235, 235))
    d = ImageDraw.Draw(img)
    for y in range(0, size[1], step):
        for x in range(0, size[0], step):
            if (x // step + y // step) % 2:
                d.rectangle([x, y, x + step - 1, y + step - 1], fill=(205, 205, 205))
    return img


def main():
    with open(os.path.join(PREVIEW, "cells.json")) as f:
        manifest = json.load(f)

    os.makedirs(OUT, exist_ok=True)
    index = {}
    for name, cells in manifest.items():
        sheet = Image.open(os.path.join(SRC, name + ".webp")).convert("RGBA")
        folder = os.path.join(OUT, name.replace("_asset", ""))
        os.makedirs(folder, exist_ok=True)

        rows = (len(cells) + COLS - 1) // COLS
        contact = checkerboard((COLS * CELL, rows * CELL))
        d = ImageDraw.Draw(contact)

        entries = []
        for i, (x, y, w, h) in enumerate(cells):
            sprite = sheet.crop((x, y, x + w, y + h))
            sprite.save(os.path.join(folder, f"{i:02d}.png"))
            entries.append({"i": i, "x": x, "y": y, "w": w, "h": h})

            scale = min((CELL - 16) / w, (CELL - 16) / h, 1.0)
            thumb = sprite.resize((max(1, int(w * scale)), max(1, int(h * scale))))
            cx = (i % COLS) * CELL + (CELL - thumb.width) // 2
            cy = (i // COLS) * CELL + (CELL - thumb.height) // 2
            contact.paste(thumb, (cx, cy), thumb)
            d.rectangle([(i % COLS) * CELL, (i // COLS) * CELL,
                         (i % COLS) * CELL + CELL - 1, (i // COLS) * CELL + CELL - 1],
                        outline=(255, 0, 0))
            d.text(((i % COLS) * CELL + 5, (i // COLS) * CELL + 4), str(i),
                   fill=(0, 0, 200))

        contact.save(os.path.join(PREVIEW, "contact_" + name + ".png"))
        index[name] = entries
        print(f"{name}: {len(cells)} sprites -> {folder}")

    with open(os.path.join(OUT, "index.json"), "w") as f:
        json.dump(index, f, indent=1)


main()
