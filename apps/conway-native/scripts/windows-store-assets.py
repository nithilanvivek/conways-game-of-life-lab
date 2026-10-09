#!/usr/bin/env python3
"""Export MSIX variants directly from the large original artwork, without upscaling.

This exports packaging assets; it does not redraw or alter the app's artwork.
Requires Pillow. Generated assets and the inspection sheet belong in dist/.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "shared/app-icon-rounded.png"
SCALES = (100, 125, 150, 200, 250, 300, 400)
TARGETS = (16, 20, 24, 30, 32, 36, 40, 44, 48, 60, 64, 72, 80, 96, 256)
BASES = {
    "Square44x44Logo": (44, 44),
    "Square150x150Logo": (150, 150),
    "Square71x71Logo": (71, 71),
    "Square310x310Logo": (310, 310),
    "Wide310x150Logo": (310, 150),
    "StoreLogo": (50, 50),
}
ICO_SIZES = sorted(set(TARGETS) | {128, 160, 176})


def export_icon(source, size):
    width, height = size
    edge = min(size)
    if edge > min(source.size):
        raise ValueError(f"Refusing to upscale {source.size} to {size}")
    # Resample each variant from the master, never from another small export.
    icon = source.resize((edge, edge), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(icon, ((width - edge) // 2, (height - edge) // 2))
    return canvas


def specs():
    variants = {}
    for name, base in BASES.items():
        variants[f"{name}.png"] = base
        for scale in SCALES:
            size = tuple(round(edge * scale / 100) for edge in base)
            variants[f"{name}.scale-{scale}.png"] = size
    for size in TARGETS:
        for qualifier in ("", "_altform-unplated", "_altform-lightunplated"):
            variants[f"Square44x44Logo.targetsize-{size}{qualifier}.png"] = (size, size)
    return variants


def verify(assets):
    for name, expected in specs().items():
        with Image.open(assets / name) as image:
            image.load()
            if image.format != "PNG" or image.mode != "RGBA" or image.size != expected:
                raise ValueError(f"Bad MSIX variant {name}: {image.format}, {image.mode}, {image.size}; expected {expected}")
            if not image.getbbox() or image.getextrema()[3][0] != 0:
                raise ValueError(f"Empty or non-transparent app asset: {name}")
    print(f"PASS: {len(specs())} PNG variants, exact dimensions and transparent backgrounds")


def preview(assets, output):
    # Native pixel sizes on both desktop themes; small icons aren't enlarged here.
    sheet = Image.new("RGB", (1040, 900), "#e6e6e6")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=17)
    draw.text((20, 12), "Conway MSIX icons: native pixels, from the full-size master", fill="black", font=font)
    for row, background in enumerate(("#121212", "#ffffff")):
        top = 52 + row * 236
        draw.rectangle((0, top, 1039, top + 226), fill=background)
        x = 20
        for size in (16, 24, 32, 44, 48, 64, 96, 176):
            icon = Image.open(assets / f"Square44x44Logo.scale-{400 if size == 176 else 100}.png") if size == 176 else Image.open(assets / f"Square44x44Logo.targetsize-{size}_altform-unplated.png")
            sheet.paste(icon, (x, top + 34), icon)
            draw.text((x, top + 8), f"{size}px", fill="white" if row == 0 else "black", font=font)
            x += size + 26
    for name, x, y in (("Square150x150Logo.scale-200.png", 20, 565), ("StoreLogo.scale-400.png", 370, 565), ("Square44x44Logo.targetsize-256_altform-unplated.png", 610, 565)):
        image = Image.open(assets / name)
        sheet.paste(image, (x, y), image)
        draw.text((x, y - 30), name.split(".")[0] + f" ({image.width}px)", fill="black", font=font)
    sheet.save(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--write-ico", action="store_true", help="Regenerate the app's multi-resolution shell icon")
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if args.verify_only:
        verify(args.output)
        return
    assets = args.output / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    with Image.open(SOURCE) as original:
        source = original.convert("RGBA")
    if source.width != source.height or source.width < 1240:
        raise ValueError("Use the square full-size master, not a previously resized icon")
    for name, size in specs().items():
        export_icon(source, size).save(assets / name, optimize=True)
    if args.write_ico:
        source.save(ROOT / "windows/AppIcon.ico", format="ICO", sizes=[(size, size) for size in ICO_SIZES])
    listing = args.output / "Store-listing"
    listing.mkdir(exist_ok=True)
    for size in (300, 1080):
        export_icon(source, (size, size)).save(listing / f"Conway-Store-icon-{size}.png", optimize=True)
    verify(assets)
    preview(assets, args.output / "icon-inspection.png")
    report = {
        "source": "apps/conway-native/shared/app-icon-rounded.png",
        "source_size": list(source.size),
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "resampling": "Each variant directly downsampled from source with Lanczos; no upscaling",
        "scale_percentages": SCALES,
        "taskbar_target_sizes": TARGETS,
        "assets": {name: {"size": size, "sha256": hashlib.sha256((assets / name).read_bytes()).hexdigest()} for name, size in specs().items()},
    }
    (args.output / "icon-report.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
