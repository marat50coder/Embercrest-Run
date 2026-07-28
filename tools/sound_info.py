import os

BR = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
SR = [44100, 48000, 32000]


def duration(path):
    d = open(path, "rb").read()
    i = 0
    if d[:3] == b"ID3":
        size = ((d[6] & 0x7F) << 21 | (d[7] & 0x7F) << 14
                | (d[8] & 0x7F) << 7 | (d[9] & 0x7F))
        i = 10 + size
    t = 0.0
    while i < len(d) - 4:
        if d[i] == 0xFF and (d[i + 1] & 0xE0) == 0xE0:
            bi = (d[i + 2] >> 4) & 0xF
            si = (d[i + 2] >> 2) & 0x3
            pad = (d[i + 2] >> 1) & 1
            if bi in (0, 15) or si == 3:
                i += 1
                continue
            rate = SR[si]
            t += 1152 / rate
            i += int(144 * BR[bi] * 1000 / rate) + pad
        else:
            i += 1
    return t


folder = r"D:\flutter_proj\Embercrest Run\sounds"
for f in sorted(os.listdir(folder)):
    print(f"{duration(os.path.join(folder, f)):6.2f}s  {f}")
