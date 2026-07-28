import os
from PIL import Image

SRC = r"D:\flutter_proj\Embercrest Run\assets"
OUT = r"D:\flutter_proj\Embercrest Run\tools\preview"
os.makedirs(OUT, exist_ok=True)

for name in sorted(os.listdir(SRC)):
    path = os.path.join(SRC, name)
    if not os.path.isfile(path):
        continue
    try:
        im = Image.open(path).convert("RGBA")
    except Exception as e:
        print(f"{name}: ERROR {e}")
        continue
    base = os.path.splitext(name)[0]
    # full-size png
    im.save(os.path.join(OUT, base + ".png"))
    print(f"{name}: {im.size[0]}x{im.size[1]}")
