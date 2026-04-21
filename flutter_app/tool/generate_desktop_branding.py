#!/usr/bin/env python3

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
BRANDING_DIR = ROOT / "assets" / "branding"
WEB_DIR = ROOT / "web"
WEB_ICONS_DIR = WEB_DIR / "icons"
MAC_ICON_DIR = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WINDOWS_ICON_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
LINUX_ICON_DIR = ROOT / "linux" / "runner" / "resources"
ANDROID_RES_DIR = ROOT / "android" / "app" / "src" / "main" / "res"
SERVER_PUBLIC_DIR = ROOT.parent / "server" / "public"
SERVER_PUBLIC_ICONS_DIR = SERVER_PUBLIC_DIR / "icons"

ACCENT = (143, 109, 62)
ACCENT_ALT = (47, 125, 110)
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def gradient_background(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    px = img.load()
    for y in range(size):
      for x in range(size):
        tx = x / max(size - 1, 1)
        ty = y / max(size - 1, 1)
        t = (tx + ty) / 2
        px[x, y] = (
            int(lerp(ACCENT[0], ACCENT_ALT[0], t)),
            int(lerp(ACCENT[1], ACCENT_ALT[1], t)),
            int(lerp(ACCENT[2], ACCENT_ALT[2], t)),
            255,
        )
    return img


def logo_paths(size: int, padding_ratio: float = 0.18):
    pad = size * padding_ratio
    inner = size - pad * 2
    def point(x: float, y: float) -> tuple[float, float]:
        return (pad + inner * x, pad + inner * y)

    top = [point(0.5, 0.08), point(0.1, 0.3), point(0.5, 0.52), point(0.9, 0.3)]
    middle = [point(0.1, 0.52), point(0.5, 0.74), point(0.9, 0.52)]
    bottom = [point(0.1, 0.72), point(0.5, 0.94), point(0.9, 0.72)]
    return top, middle, bottom, inner


def draw_logo(draw: ImageDraw.ImageDraw, size: int, color: tuple[int, int, int, int]) -> None:
    top, middle, bottom, inner = logo_paths(size)
    stroke = max(2, round(inner * 0.08))
    draw.polygon(top, fill=color)
    draw.line(middle, fill=color, width=stroke, joint="curve")
    draw.line(bottom, fill=color, width=stroke, joint="curve")


def make_app_icon(size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), TRANSPARENT)

    shadow = Image.new("RGBA", (size, size), TRANSPARENT)
    shadow_draw = ImageDraw.Draw(shadow)
    offset_y = size * 0.02
    corner = round(size * 0.34)
    shadow_draw.rounded_rectangle(
        (size * 0.07, size * 0.07 + offset_y, size * 0.93, size * 0.93 + offset_y),
        radius=corner,
        fill=(0, 0, 0, 72),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(2, size * 0.04)))
    canvas.alpha_composite(shadow)

    base_mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(base_mask)
    base_rect = (size * 0.08, size * 0.08, size * 0.92, size * 0.92)
    mask_draw.rounded_rectangle(base_rect, radius=corner, fill=255)

    base = gradient_background(size)
    clipped = Image.new("RGBA", (size, size), TRANSPARENT)
    clipped.paste(base, mask=base_mask)
    canvas.alpha_composite(clipped)

    ring = Image.new("RGBA", (size, size), TRANSPARENT)
    ring_draw = ImageDraw.Draw(ring)
    ring_draw.rounded_rectangle(
        base_rect,
        radius=corner,
        outline=(255, 255, 255, 36),
        width=max(1, round(size * 0.012)),
    )
    canvas.alpha_composite(ring)

    glyph = Image.new("RGBA", (size, size), TRANSPARENT)
    draw = ImageDraw.Draw(glyph)
    draw_logo(draw, size, WHITE)
    canvas.alpha_composite(glyph)
    return canvas


def make_tray_template(size: int = 64) -> Image.Image:
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    draw = ImageDraw.Draw(img)
    draw_logo(draw, size, (0, 0, 0, 255))
    return img


def ensure_dirs() -> None:
    BRANDING_DIR.mkdir(parents=True, exist_ok=True)
    WEB_ICONS_DIR.mkdir(parents=True, exist_ok=True)
    MAC_ICON_DIR.mkdir(parents=True, exist_ok=True)
    LINUX_ICON_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_PUBLIC_ICONS_DIR.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def copy_png(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    save_png(image, path, size)


def write_favicon_svg(path: Path) -> None:
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#{ACCENT[0]:02x}{ACCENT[1]:02x}{ACCENT[2]:02x}"/>
      <stop offset="100%" stop-color="#{ACCENT_ALT[0]:02x}{ACCENT_ALT[1]:02x}{ACCENT_ALT[2]:02x}"/>
    </linearGradient>
  </defs>
  <rect x="2.5" y="2.5" width="27" height="27" rx="9" ry="9" fill="url(#bg)" stroke="#ffffff" stroke-opacity="0.16" stroke-width="1"/>
  <polygon points="16,5.7 5.2,11.6 16,17.6 26.8,11.6" fill="white"/>
  <polyline points="5.2,17.6 16,23.5 26.8,17.6" fill="none" stroke="white" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
  <polyline points="5.2,22.7 16,28.1 26.8,22.7" fill="none" stroke="white" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"""
    write_text(path, svg)


def save_png(image: Image.Image, path: Path, size: int) -> None:
    image.resize((size, size), Image.Resampling.LANCZOS).save(path, format="PNG")


def main() -> None:
    ensure_dirs()
    master = make_app_icon(1024)

    save_png(master, BRANDING_DIR / "app_icon_1024.png", 1024)
    save_png(master, BRANDING_DIR / "app_icon_512.png", 512)
    save_png(master, BRANDING_DIR / "app_icon_256.png", 256)
    save_png(master, BRANDING_DIR / "app_icon_192.png", 192)
    save_png(master, BRANDING_DIR / "app_icon_128.png", 128)
    save_png(master, BRANDING_DIR / "app_icon_64.png", 64)
    save_png(master, BRANDING_DIR / "app_icon_32.png", 32)

    tray = make_tray_template(64)
    save_png(tray, BRANDING_DIR / "tray_icon_template.png", 64)

    icon_sizes = {
        16: "app_icon_16.png",
        32: "app_icon_32.png",
        64: "app_icon_64.png",
        128: "app_icon_128.png",
        256: "app_icon_256.png",
        512: "app_icon_512.png",
        1024: "app_icon_1024.png",
    }
    for size, filename in icon_sizes.items():
        save_png(master, MAC_ICON_DIR / filename, size)

    save_png(master, LINUX_ICON_DIR / "app_icon.png", 256)

    master_for_ico = master.resize((256, 256), Image.Resampling.LANCZOS)
    master_for_ico.save(
        WINDOWS_ICON_PATH,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    web_icon_sizes = {
        192: "Icon-192.png",
        512: "Icon-512.png",
    }
    for size, filename in web_icon_sizes.items():
        copy_png(master, WEB_ICONS_DIR / filename, size)
        copy_png(master, WEB_ICONS_DIR / filename.replace("Icon-", "Icon-maskable-"), size)
        copy_png(master, SERVER_PUBLIC_ICONS_DIR / filename, size)
        copy_png(master, SERVER_PUBLIC_ICONS_DIR / filename.replace("Icon-", "Icon-maskable-"), size)

    copy_png(master, WEB_DIR / "favicon.png", 32)
    copy_png(master, SERVER_PUBLIC_DIR / "favicon.png", 32)
    write_favicon_svg(WEB_DIR / "favicon.svg")
    write_favicon_svg(SERVER_PUBLIC_DIR / "favicon.svg")

    android_icon_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_icon_sizes.items():
        copy_png(master, ANDROID_RES_DIR / folder / "ic_launcher.png", size)


if __name__ == "__main__":
    main()
