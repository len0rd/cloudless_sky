#!/usr/bin/env python3
"""
Generate the iOS app icons from ios/icon_source.png

source should be at least 1024x1024

generates all of them into ios/icon/ icon_<size><scale>.png
"""

from pathlib import Path

from PIL import Image

IOS_DIR = Path(__file__).parent

# sizes for every entry in love's AppIcon.appiconset
ICONS = [
    ("20x20", (1, 2, 3)),
    ("29x29", (1, 2, 3)),
    ("40x40", (1, 2, 3)),
    ("60x60", (2, 3)),
    ("76x76", (1, 2)),
    ("83.5x83.5", (2,)),
    ("1024x1024", (1,)),
]


def main():
    # Apple rejects icons with an alpha channel
    source = Image.open(IOS_DIR / "icon_source.png").convert("RGB")
    out_dir = IOS_DIR / "icon"
    out_dir.mkdir(exist_ok=True)
    for size, scales in ICONS:
        points = float(size.split("x")[0])
        for scale in scales:
            pixels = int(points * scale)
            suffix = "" if scale == 1 else f"@{scale}x"
            icon = source.resize((pixels, pixels), Image.LANCZOS)
            icon.save(out_dir / f"icon_{size}{suffix}.png")


if __name__ == "__main__":
    main()
