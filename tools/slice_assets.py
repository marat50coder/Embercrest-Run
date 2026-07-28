"""Slice every sprite sheet into individual sprites and export a manifest.

The sheets are grid-like but a plain gutter scan is not enough: some sprites
touch their neighbour with no transparent gap, whole grid rows touch
vertically, and some sprites have detached debris that must stay part of the
same sprite. So the number of grid rows is declared per sheet (that is the part
no heuristic can recover), rows are cut at the emptiest scanline near each
boundary, and within a row sprites are found by gutter scan, then debris is
merged back and multi-sprite blobs are split at the emptiest column.
"""
import os
import json
from statistics import median
from PIL import Image, ImageDraw

SRC = r"D:\flutter_proj\Embercrest Run\assets"
OUT_DIR = r"D:\flutter_proj\Embercrest Run\build_assets\sprites"
PREVIEW = r"D:\flutter_proj\Embercrest Run\tools\preview"

# Near-transparent halo pixels bridge the gutters, so cuts are chosen from
# solid pixels only while the final bounding box keeps the soft glow.
ALPHA_SPLIT = 70
ALPHA_KEEP = 10

ROWS = {
    "ancient_altars_asset": 3,
    "ancient_volcanic_cores_asset": 2,
    "decorative_elements_asset": 3,
    "effects_vfx_asset": 5,
    "Embercrest_Road_conditions_asset": 1,
    "enemyes_asset": 4,
    "magmatic_roads_asset": 4,
    "Magma_abilities_asset": 2,
    "main_character_with_skins_asset": 2,
    "resources_asset": 2,
    "types_destroy_roads_asset": 2,
    "types_magma_asset": 2,
    "volcanic_obstacles_asset": 3,
    "vulcanic_island_asset": 3,
    "vulcanic_plants_asset": 3,
}

EXPECTED_TOTAL = {
    "ancient_altars_asset": 18,
    "ancient_volcanic_cores_asset": 10,
    "decorative_elements_asset": 18,
    "effects_vfx_asset": 49,
    "Embercrest_Road_conditions_asset": 10,
    "enemyes_asset": 40,
    "magmatic_roads_asset": 40,
    "Magma_abilities_asset": 10,
    "main_character_with_skins_asset": 10,
    "resources_asset": 12,
    "types_destroy_roads_asset": 15,
    "types_magma_asset": 10,
    "volcanic_obstacles_asset": 16,
    "vulcanic_island_asset": 15,
    "vulcanic_plants_asset": 16,
}


def runs(flags):
    out, s = [], None
    for i, v in enumerate(flags):
        if v and s is None:
            s = i
        elif not v and s is not None:
            out.append((s, i))
            s = None
    if s is not None:
        out.append((s, len(flags)))
    return out


def occupied_span(profile):
    nz = [i for i, p in enumerate(profile) if p > 0]
    return nz[0], nz[-1] + 1


def reference_width(cells):
    """Typical width of a single sprite, ignoring debris specks."""
    widths = sorted(c[1] - c[0] for c in cells)
    return median(widths[len(widths) // 2:])


def cut_rows(profile, lo, hi, n):
    """Divide [lo,hi) into n bands, snapping each cut to the emptiest scanline."""
    if n <= 1:
        return [(lo, hi)]
    pitch = (hi - lo) / n
    bounds = [lo]
    for k in range(1, n):
        target = lo + pitch * k
        a = int(max(lo + 1, target - pitch * 0.30))
        b = int(min(hi - 1, target + pitch * 0.30))
        bounds.append(min(range(a, b), key=lambda i: (profile[i], abs(i - target))))
    bounds.append(hi)
    return [(bounds[k], bounds[k + 1]) for k in range(n)]


def split_columns(profile, lo, hi):
    """Find sprite x-ranges inside one row band."""
    cells = [(lo + a, lo + b) for a, b in runs([profile[x] > 0 for x in range(lo, hi)])]
    if len(cells) <= 1:
        return cells
    wref = reference_width(cells)

    # pull detached debris back into the sprite it belongs to
    merged = True
    while merged and len(cells) > 1:
        merged = False
        for i in range(len(cells) - 1):
            a, b = cells[i], cells[i + 1]
            if b[1] - a[0] <= 1.30 * wref and b[0] - a[1] < 0.40 * wref:
                cells[i:i + 2] = [(a[0], b[1])]
                wref = reference_width(cells)
                merged = True
                break

    # split blobs that are really several touching sprites
    out = []
    for a, b in cells:
        n = int(round((b - a) / wref))
        if n <= 1:
            out.append((a, b))
            continue
        pitch = (b - a) / n
        bounds = [a]
        for k in range(1, n):
            target = a + pitch * k
            lo2 = int(max(a + 1, target - pitch * 0.30))
            hi2 = int(min(b - 1, target + pitch * 0.30))
            bounds.append(min(range(lo2, hi2),
                             key=lambda x: (profile[x], abs(x - target))))
        bounds.append(b)
        out += [(bounds[k], bounds[k + 1]) for k in range(n)]
    return out


def slice_sheet(name, n_rows):
    im = Image.open(os.path.join(SRC, name + ".webp")).convert("RGBA")
    w, h = im.size
    px = im.split()[3].load()
    solid = [[px[x, y] > ALPHA_SPLIT for x in range(w)] for y in range(h)]
    keep = [[px[x, y] > ALPHA_KEEP for x in range(w)] for y in range(h)]

    row_profile = [sum(1 for x in range(w) if solid[y][x]) for y in range(h)]
    ry0, ry1 = occupied_span(row_profile)

    cells = []
    for y0, y1 in cut_rows(row_profile, ry0, ry1, n_rows):
        col_profile = [sum(1 for y in range(y0, y1) if solid[y][x]) for x in range(w)]
        cx0, cx1 = occupied_span(col_profile)
        for x0, x1 in split_columns(col_profile, cx0, cx1):
            bx0, by0, bx1, by1 = x1, y1, x0, y0
            for y in range(y0, y1):
                row = keep[y]
                for x in range(x0, x1):
                    if row[x]:
                        bx0 = min(bx0, x)
                        bx1 = max(bx1, x + 1)
                        by0 = min(by0, y)
                        by1 = max(by1, y + 1)
            if bx1 > bx0 and by1 > by0:
                cells.append([bx0, by0, bx1 - bx0, by1 - by0])
    return im, cells


def main():
    os.makedirs(PREVIEW, exist_ok=True)
    manifest = {}
    all_ok = True
    for name, n_rows in ROWS.items():
        im, cells = slice_sheet(name, n_rows)
        manifest[name] = cells
        expected = EXPECTED_TOTAL[name]
        ok = len(cells) == expected
        all_ok &= ok
        print(f"{'OK ' if ok else 'BAD'} {name}: {len(cells)}/{expected}")

        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        bg.alpha_composite(im)
        d = ImageDraw.Draw(bg)
        for i, (x, y, cw, ch) in enumerate(cells):
            d.rectangle([x, y, x + cw - 1, y + ch - 1], outline=(255, 0, 0), width=3)
            d.text((x + 6, y + 4), str(i), fill=(0, 0, 255))
        bg.convert("RGB").resize((im.width // 2, im.height // 2)).save(
            os.path.join(PREVIEW, "cells_" + name + ".png"))

    with open(os.path.join(PREVIEW, "cells.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    print("ALL SHEETS OK" if all_ok else "MISMATCHES")


main()
