"""Builds the app icon and emblem from the transparent brand logo.

The full logo has the "GitHub+" wordmark under the emblem, which is unreadable
at icon sizes, so the icon uses only the emblem (circle + plus badge).

Usage: python tool/make_icons.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "brand" / "logo_transparent.png"
EMBLEM = ROOT / "assets" / "brand" / "emblem.png"
ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]


def emblem_box(image: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of opaque pixels above the wordmark (top ~68% of the logo)."""
    alpha = image.getchannel("A")
    width, height = image.size
    cutoff = int(height * 0.68)
    top_part = alpha.crop((0, 0, width, cutoff)).point(lambda a: 255 if a > 32 else 0)
    box = top_part.getbbox()
    if box is None:
        raise SystemExit("emblem not found")
    return box


def square(image: Image.Image, box: tuple[int, int, int, int], margin: float) -> Image.Image:
    left, top, right, bottom = box
    side = int(max(right - left, bottom - top) * (1 + margin * 2))
    cx, cy = (left + right) // 2, (top + bottom) // 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    crop = image.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side))
    canvas.alpha_composite(crop)
    return canvas


def main() -> None:
    logo = Image.open(SOURCE).convert("RGBA")
    emblem = square(logo, emblem_box(logo), margin=0.04)
    emblem.resize((512, 512), Image.LANCZOS).save(EMBLEM)
    icon = emblem.resize((256, 256), Image.LANCZOS)
    icon.save(ICO, sizes=[(s, s) for s in ICO_SIZES])
    print(f"emblem {EMBLEM.name}, icon {ICO.name} ({', '.join(map(str, ICO_SIZES))})")


if __name__ == "__main__":
    main()
