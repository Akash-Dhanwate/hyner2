#!/usr/bin/env python3
"""Render the existing Hyner vector geometry as antialiased PNGs (stdlib only)."""
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
GREEN = (23, 92, 70)


def rounded(x, y, left, top, right, bottom, radius):
    if not (left <= x <= right and top <= y <= bottom):
        return False
    dx = x - max(left + radius, min(right - radius, x))
    dy = y - max(top + radius, min(bottom - radius, y))
    return dx * dx + dy * dy <= radius * radius


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)


def render(path, edge, maskable=False):
    # Geometry matches assets/branding/hyner-mark.svg, sampled 4x per axis.
    points = [[(pixel + (sub + .5) / 4) * 100 / edge for sub in range(4)] for pixel in range(edge)]
    raw = bytearray()
    for ys in points:
        raw.append(0)  # PNG filter: none
        for xs in points:
            coverage = white = 0
            for y in ys:
                for x in xs:
                    if maskable or rounded(x, y, 0, 0, 100, 100, 25):
                        coverage += 1
                        if (rounded(x, y, 25, 23, 40, 77, 3.5) or
                            rounded(x, y, 60, 23, 75, 77, 3.5) or
                            (35 <= x <= 65 and 49 - (x - 35) * 14 / 30 <= y <= 66 - (x - 35) * 14 / 30)):
                            white += 1
            if coverage:
                raw.extend(round((c * (coverage - white) + 255 * white) / coverage) for c in GREEN)
                raw.append(round(255 * coverage / 16))
            else:
                raw.extend((0, 0, 0, 0))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', edge, edge, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    (ROOT / path).write_bytes(png)


if __name__ == '__main__':
    for density, edge in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        render(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', edge)
    render('assets/branding/hyner-icon.png', 512)
    render('web/favicon.png', 32)
    for edge in [192, 512]:
        render(f'web/icons/Icon-{edge}.png', edge)
        render(f'web/icons/Icon-maskable-{edge}.png', edge, maskable=True)
    print('Rendered Android, web and branding PNGs with no external dependencies.')
