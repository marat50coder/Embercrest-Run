"""Print the natural gutter structure of a sheet so grid layouts can be checked."""
import sys
from PIL import Image

name = sys.argv[1]
gap = int(sys.argv[2]) if len(sys.argv) > 2 else 40

im = Image.open(rf"D:\flutter_proj\Embercrest Run\assets\{name}.webp").convert("RGBA")
w, h = im.size
px = im.split()[3].load()
solid = [[px[x, y] > 70 for x in range(w)] for y in range(h)]


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


def cluster(groups, gap):
    out = []
    for a, b in groups:
        if out and a - out[-1][1] < gap:
            out[-1] = (out[-1][0], b)
        else:
            out.append((a, b))
    return out


rp = [sum(1 for x in range(w) if solid[y][x]) for y in range(h)]
bands = cluster(runs([p > 0 for p in rp]), 6)
print(f"{name}: {len(bands)} row bands {bands}")
for y0, y1 in bands:
    cp = [sum(1 for y in range(y0, y1) if solid[y][x]) for x in range(w)]
    g = cluster(runs([p > 0 for p in cp]), gap)
    widths = [b - a for a, b in g]
    print(f"  y {y0}-{y1} (h={y1-y0}): {len(g)} groups, widths {widths}")
    print(f"    {g}")
