"""Pack the sliced sprites into atlas pages plus a manifest.

The game draws sprites with Canvas.drawAtlas, which batches every sprite that
shares one texture into a single draw call, so the whole frame costs a handful
of calls instead of hundreds. Sprites are grouped by sheet and packed with
MaxRects into 2048px pages.
"""
import os
import json
from PIL import Image

SRC = r"D:\flutter_proj\Embercrest Run\assets"
PREVIEW = r"D:\flutter_proj\Embercrest Run\tools\preview"
OUT = r"D:\flutter_proj\Embercrest Run\assets\atlas"

PAGE = 2048
PAD = 2
# gameplay sprites never render larger than ~200px, so half size is plenty and
# keeps the atlas down to a single page
SCALE = 0.62

# drawAtlas can only scale a sprite uniformly, so every sprite used as a piece
# of road is baked to one fixed size here.
#
# The road is drawn as a chain of these pieces, so a piece must tile against
# its neighbours: only the straight-sided middle band of each source sprite is
# kept, dropping the rounded caps that would otherwise repeat down the path as
# visible lumps. The band is kept short so a piece covers only a little more
# than the segment spacing, which keeps the cooling gradient smooth.
ROAD_PIECE = (112, 72)
ROAD_BAND = 0.62  # band height as a fraction of the source sprite's width
ROAD_SHEETS = {
    "Embercrest_Road_conditions_asset": "road",
    "types_destroy_roads_asset": "roadbreak",
    "Magma_abilities_asset": "roadmagma",
}


class MaxRects:
    def __init__(self, w, h):
        self.free = [(0, 0, w, h)]
        self.w, self.h = w, h

    def insert(self, w, h):
        best, best_score = None, None
        for (fx, fy, fw, fh) in self.free:
            if fw >= w and fh >= h:
                score = (min(fw - w, fh - h), max(fw - w, fh - h))
                if best_score is None or score < best_score:
                    best, best_score = (fx, fy, w, h), score
        if best is None:
            return None
        self._split(best)
        return best

    def _split(self, used):
        ux, uy, uw, uh = used
        out = []
        for (fx, fy, fw, fh) in self.free:
            if ux >= fx + fw or ux + uw <= fx or uy >= fy + fh or uy + uh <= fy:
                out.append((fx, fy, fw, fh))
                continue
            if ux > fx:
                out.append((fx, fy, ux - fx, fh))
            if ux + uw < fx + fw:
                out.append((ux + uw, fy, fx + fw - (ux + uw), fh))
            if uy > fy:
                out.append((fx, fy, fw, uy - fy))
            if uy + uh < fy + fh:
                out.append((fx, uy + uh, fw, fy + fh - (uy + uh)))
        # drop rectangles fully contained in another
        pruned = []
        for i, a in enumerate(out):
            if not any(i != j and self._contains(b, a) for j, b in enumerate(out)):
                pruned.append(a)
        self.free = pruned

    @staticmethod
    def _contains(a, b):
        return (a[0] <= b[0] and a[1] <= b[1]
                and a[0] + a[2] >= b[0] + b[2] and a[1] + a[3] >= b[1] + b[3])


def main():
    with open(os.path.join(PREVIEW, "cells.json")) as f:
        cells = json.load(f)

    items = []
    sheets = {}
    for name, rects in cells.items():
        sheets[name] = Image.open(os.path.join(SRC, name + ".webp")).convert("RGBA")
        road_key = ROAD_SHEETS.get(name)
        key = road_key or name.replace("_asset", "")
        for i, (x, y, w, h) in enumerate(rects):
            if road_key:
                band = max(8, round(w * ROAD_BAND))
                y = y + (h - band) // 2
                h = band
                sw, sh = ROAD_PIECE
            else:
                sw = max(1, round(w * SCALE))
                sh = max(1, round(h * SCALE))
            items.append({"name": f"{key}/{i:02d}", "sheet": name,
                          "src": (x, y, w, h), "w": sw, "h": sh})

    items.sort(key=lambda it: -max(it["w"], it["h"]))

    pages, manifest = [], {}
    for it in items:
        placed = None
        for pi, (packer, img) in enumerate(pages):
            placed = packer.insert(it["w"] + PAD * 2, it["h"] + PAD * 2)
            if placed:
                page_index = pi
                break
        if not placed:
            packer = MaxRects(PAGE, PAGE)
            img = Image.new("RGBA", (PAGE, PAGE), (0, 0, 0, 0))
            pages.append((packer, img))
            page_index = len(pages) - 1
            placed = packer.insert(it["w"] + PAD * 2, it["h"] + PAD * 2)
            if not placed:
                raise SystemExit(f"sprite too large for a page: {it['name']}")

        x, y, _, _ = placed
        x, y = x + PAD, y + PAD
        sx, sy, sw, sh = it["src"]
        sprite = sheets[it["sheet"]].crop((sx, sy, sx + sw, sy + sh))
        sprite = sprite.resize((it["w"], it["h"]), Image.LANCZOS)
        pages[page_index][1].paste(sprite, (x, y), sprite)
        manifest[it["name"]] = {"p": page_index, "x": x, "y": y,
                                "w": it["w"], "h": it["h"]}

    os.makedirs(OUT, exist_ok=True)
    for i, (_, img) in enumerate(pages):
        # crop unused bottom space so the texture upload stays small
        bbox = img.getbbox()
        height = 1
        while height < bbox[3]:
            height *= 2
        img = img.crop((0, 0, PAGE, height))
        img.save(os.path.join(OUT, f"atlas_{i}.png"), optimize=True)
        print(f"atlas_{i}.png  {PAGE}x{height}")

    with open(os.path.join(OUT, "atlas.json"), "w") as f:
        json.dump({"pages": len(pages), "sprites": manifest}, f, separators=(",", ":"))
    print(f"{len(manifest)} sprites in {len(pages)} page(s)")


main()
