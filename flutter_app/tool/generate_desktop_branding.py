#!/usr/bin/env python3

from __future__ import annotations

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
STATIC_IMG_DIR = ROOT.parent / "static" / "img"
LANDING_LOGO_PATH = ROOT.parent / "landing" / "assets" / "logo.svg"
EXTENSION_LOGO_PATH = ROOT.parent / "extensions" / "chrome-browser" / "icons" / "logo.svg"

ACCENT = (104, 78, 44)
ACCENT_ALT = (35, 92, 82)
ACCENT_DARK = (158, 128, 82)
ACCENT_ALT_DARK = (67, 144, 129)
SYMBOL_LIGHT = (255, 247, 232, 255)
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix_channel(value: int, target: int, amount: float) -> int:
    return max(0, min(255, round(lerp(value, target, amount))))


def mix_color(color: tuple[int, int, int], target: int, amount: float) -> tuple[int, int, int]:
    return (
        mix_channel(color[0], target, amount),
        mix_channel(color[1], target, amount),
        mix_channel(color[2], target, amount),
    )


def gradient_background(
    size: int,
    start: tuple[int, int, int],
    end: tuple[int, int, int],
) -> Image.Image:
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    px = img.load()
    for y in range(size):
      for x in range(size):
        tx = x / max(size - 1, 1)
        ty = y / max(size - 1, 1)
        diagonal = (tx * 0.58) + (ty * 0.42)
        glow = max(0.0, 1.0 - (((tx - 0.25) ** 2 + (ty - 0.18) ** 2) ** 0.5) / 0.58)
        shade = max(0.0, 1.0 - (((tx - 0.86) ** 2 + (ty - 0.94) ** 2) ** 0.5) / 0.72)
        t = min(1.0, max(0.0, diagonal + glow * 0.12 - shade * 0.08))
        base = (
            int(lerp(start[0], end[0], t)),
            int(lerp(start[1], end[1], t)),
            int(lerp(start[2], end[2], t)),
        )
        lit = mix_color(base, 255, glow * 0.14)
        final = mix_color(lit, 0, shade * 0.16)
        px[x, y] = (
            final[0],
            final[1],
            final[2],
            255,
        )
    return img


def logo_paths(size: int, padding_ratio: float = 0.16):
    pad = size * padding_ratio
    inner = size - pad * 2
    def point(x: float, y: float) -> tuple[float, float]:
        return (pad + inner * x, pad + inner * y)

    top = [point(0.5, 0.08), point(0.92, 0.35), point(0.5, 0.53), point(0.08, 0.35)]
    middle = [point(0.5, 0.43), point(0.9, 0.64), point(0.5, 0.76), point(0.1, 0.64)]
    bottom = [point(0.5, 0.67), point(0.86, 0.86), point(0.5, 0.96), point(0.14, 0.86)]
    return top, middle, bottom


def draw_logo(draw: ImageDraw.ImageDraw, size: int, color: tuple[int, int, int, int]) -> None:
    top, middle, bottom = logo_paths(size)
    draw.polygon(top, fill=color)
    draw.polygon(middle, fill=color)
    draw.polygon(bottom, fill=color)


def make_app_icon(size: int, *, light: bool = False) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), TRANSPARENT)
    start = ACCENT if light else ACCENT_DARK
    end = ACCENT_ALT if light else ACCENT_ALT_DARK
    symbol = SYMBOL_LIGHT if light else WHITE

    shadow = Image.new("RGBA", (size, size), TRANSPARENT)
    shadow_draw = ImageDraw.Draw(shadow)
    corner = round(size * 0.3)
    shadow_draw.rounded_rectangle(
        (size * 0.075, size * 0.09, size * 0.925, size * 0.94),
        radius=corner,
        fill=(0, 0, 0, 64 if light else 86),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(2, size * 0.035)))
    canvas.alpha_composite(shadow)

    base_mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(base_mask)
    base_rect = (size * 0.08, size * 0.08, size * 0.92, size * 0.92)
    mask_draw.rounded_rectangle(base_rect, radius=corner, fill=255)

    base = gradient_background(size, start, end)
    clipped = Image.new("RGBA", (size, size), TRANSPARENT)
    clipped.paste(base, mask=base_mask)
    canvas.alpha_composite(clipped)

    shine = Image.new("RGBA", (size, size), TRANSPARENT)
    shine_draw = ImageDraw.Draw(shine)
    shine_draw.ellipse(
        (size * -0.12, size * -0.18, size * 0.78, size * 0.58),
        fill=(255, 255, 255, 30 if light else 42),
    )
    shine.putalpha(Image.composite(shine.getchannel("A"), Image.new("L", (size, size), 0), base_mask))
    canvas.alpha_composite(shine)

    lower_glaze = Image.new("RGBA", (size, size), TRANSPARENT)
    lower_draw = ImageDraw.Draw(lower_glaze)
    lower_draw.rounded_rectangle(
        base_rect,
        radius=corner,
        fill=(0, 0, 0, 18 if light else 12),
    )
    lower_mask = Image.new("L", (size, size), 0)
    lower_mask_draw = ImageDraw.Draw(lower_mask)
    lower_mask_draw.rectangle((0, size * 0.55, size, size), fill=255)
    lower_glaze.putalpha(Image.composite(lower_glaze.getchannel("A"), Image.new("L", (size, size), 0), lower_mask))
    canvas.alpha_composite(lower_glaze)

    ring = Image.new("RGBA", (size, size), TRANSPARENT)
    ring_draw = ImageDraw.Draw(ring)
    ring_draw.rounded_rectangle(
        base_rect,
        radius=corner,
        outline=(255, 255, 255, 58 if light else 48),
        width=max(1, round(size * 0.012)),
    )
    inset = size * 0.018
    ring_draw.rounded_rectangle(
        (
            base_rect[0] + inset,
            base_rect[1] + inset,
            base_rect[2] - inset,
            base_rect[3] - inset,
        ),
        radius=max(1, corner - round(inset)),
        outline=(0, 0, 0, 26 if light else 20),
        width=max(1, round(size * 0.006)),
    )
    canvas.alpha_composite(ring)

    glyph_shadow = Image.new("RGBA", (size, size), TRANSPARENT)
    shadow_draw = ImageDraw.Draw(glyph_shadow)
    draw_logo(shadow_draw, size, (0, 0, 0, 76 if light else 58))
    glyph_shadow = glyph_shadow.transform(
        glyph_shadow.size,
        Image.Transform.AFFINE,
        (1, 0, 0, 0, 1, size * 0.018),
        resample=Image.Resampling.BICUBIC,
    )
    glyph_shadow = glyph_shadow.filter(ImageFilter.GaussianBlur(radius=max(1, size * 0.006)))
    canvas.alpha_composite(glyph_shadow)

    glyph = Image.new("RGBA", (size, size), TRANSPARENT)
    draw = ImageDraw.Draw(glyph)
    draw_logo(draw, size, symbol)
    canvas.alpha_composite(glyph)

    glyph_highlight = Image.new("RGBA", (size, size), TRANSPARENT)
    highlight_draw = ImageDraw.Draw(glyph_highlight)
    draw_logo(highlight_draw, size, (255, 255, 255, 26 if light else 34))
    glyph_highlight = glyph_highlight.transform(
        glyph_highlight.size,
        Image.Transform.AFFINE,
        (1, 0, 0, 0, 1, -size * 0.012),
        resample=Image.Resampling.BICUBIC,
    )
    canvas.alpha_composite(glyph_highlight)
    return canvas


def make_tray_template(
    size: int = 64,
    color: tuple[int, int, int, int] = (0, 0, 0, 255),
) -> Image.Image:
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    draw = ImageDraw.Draw(img)
    draw_logo(draw, size, color)
    return img


def ensure_dirs() -> None:
    BRANDING_DIR.mkdir(parents=True, exist_ok=True)
    WEB_ICONS_DIR.mkdir(parents=True, exist_ok=True)
    MAC_ICON_DIR.mkdir(parents=True, exist_ok=True)
    LINUX_ICON_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_PUBLIC_ICONS_DIR.mkdir(parents=True, exist_ok=True)
    STATIC_IMG_DIR.mkdir(parents=True, exist_ok=True)
    LANDING_LOGO_PATH.parent.mkdir(parents=True, exist_ok=True)
    EXTENSION_LOGO_PATH.parent.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def copy_png(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    save_png(image, path, size)


def write_favicon_svg(path: Path, *, light: bool = False) -> None:
    start = ACCENT if light else ACCENT_DARK
    end = ACCENT_ALT if light else ACCENT_ALT_DARK
    symbol = "#fff9ed" if light else "#ffffff"
    stroke = "#000000" if light else "#ffffff"
    stroke_opacity = "0.24" if light else "0.16"
    glow = "#ffffff" if light else "#fff4d8"
    top_opacity = "0.20" if light else "0.24"
    shade_opacity = "0.12" if light else "0.08"
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#{start[0]:02x}{start[1]:02x}{start[2]:02x}"/>
      <stop offset="100%" stop-color="#{end[0]:02x}{end[1]:02x}{end[2]:02x}"/>
    </linearGradient>
    <radialGradient id="shine" cx="24%" cy="15%" r="70%">
      <stop offset="0%" stop-color="{glow}" stop-opacity="{top_opacity}"/>
      <stop offset="100%" stop-color="{glow}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect x="2.5" y="2.5" width="27" height="27" rx="9" ry="9" fill="url(#bg)" stroke="{stroke}" stroke-opacity="{stroke_opacity}" stroke-width="1"/>
  <rect x="2.5" y="2.5" width="27" height="27" rx="9" ry="9" fill="url(#shine)"/>
  <path d="M2.5 17h27v3.5c0 5-4 9-9 9h-9c-5 0-9-4-9-9Z" fill="#000000" opacity="{shade_opacity}"/>
  <rect x="3" y="3" width="26" height="26" rx="8.5" ry="8.5" fill="none" stroke="#ffffff" stroke-opacity="0.18" stroke-width="1"/>
  <path d="M16 6.25 26.15 12.3 16 16.3 5.85 12.3Z" fill="#000000" opacity="0.20" transform="translate(0 0.65)"/>
  <path d="M16 14.75 25.85 19.45 16 22.25 6.15 19.45Z" fill="#000000" opacity="0.20" transform="translate(0 0.65)"/>
  <path d="M16 20.45 24.85 24.75 16 26.85 7.15 24.75Z" fill="#000000" opacity="0.20" transform="translate(0 0.65)"/>
  <path d="M16 5.7 26.8 12.1 16 16.5 5.2 12.1Z" fill="{symbol}"/>
  <path d="M16 14.2 26.5 19.3 16 22.4 5.5 19.3Z" fill="{symbol}"/>
  <path d="M16 20 25.4 24.6 16 27 6.6 24.6Z" fill="{symbol}"/>
</svg>
"""
    write_text(path, svg)


def save_png(image: Image.Image, path: Path, size: int) -> None:
    image.resize((size, size), Image.Resampling.LANCZOS).save(path, format="PNG")


def main() -> None:
    ensure_dirs()
    master = make_app_icon(1024)
    light_master = make_app_icon(1024, light=True)

    save_png(master, BRANDING_DIR / "app_icon_1024.png", 1024)
    save_png(master, BRANDING_DIR / "app_icon_512.png", 512)
    save_png(master, BRANDING_DIR / "app_icon_256.png", 256)
    save_png(master, BRANDING_DIR / "app_icon_192.png", 192)
    save_png(master, BRANDING_DIR / "app_icon_128.png", 128)
    save_png(master, BRANDING_DIR / "app_icon_64.png", 64)
    save_png(master, BRANDING_DIR / "app_icon_32.png", 32)
    save_png(light_master, BRANDING_DIR / "app_icon_light_1024.png", 1024)
    save_png(light_master, BRANDING_DIR / "app_icon_light_512.png", 512)
    save_png(light_master, BRANDING_DIR / "app_icon_light_256.png", 256)
    save_png(light_master, BRANDING_DIR / "app_icon_light_192.png", 192)
    save_png(light_master, BRANDING_DIR / "app_icon_light_128.png", 128)
    save_png(light_master, BRANDING_DIR / "app_icon_light_64.png", 64)
    save_png(light_master, BRANDING_DIR / "app_icon_light_32.png", 32)

    tray = make_tray_template(64)
    save_png(tray, BRANDING_DIR / "tray_icon_template.png", 64)
    light_tray = make_tray_template(64, WHITE)
    save_png(light_tray, BRANDING_DIR / "tray_icon_light_template.png", 64)

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
        copy_png(light_master, WEB_ICONS_DIR / filename.replace(".png", "-light.png"), size)
        copy_png(light_master, WEB_ICONS_DIR / filename.replace("Icon-", "Icon-maskable-").replace(".png", "-light.png"), size)
        copy_png(master, SERVER_PUBLIC_ICONS_DIR / filename, size)
        copy_png(master, SERVER_PUBLIC_ICONS_DIR / filename.replace("Icon-", "Icon-maskable-"), size)

    copy_png(master, WEB_DIR / "favicon.png", 32)
    copy_png(master, SERVER_PUBLIC_DIR / "favicon.png", 32)
    write_favicon_svg(WEB_DIR / "favicon.svg")
    write_favicon_svg(WEB_DIR / "favicon_light.svg", light=True)
    write_favicon_svg(SERVER_PUBLIC_DIR / "favicon.svg")
    write_favicon_svg(SERVER_PUBLIC_DIR / "favicon_light.svg", light=True)
    write_favicon_svg(LANDING_LOGO_PATH, light=True)
    write_favicon_svg(EXTENSION_LOGO_PATH)
    copy_png(master, STATIC_IMG_DIR / "app_icon.png", 512)
    copy_png(light_master, STATIC_IMG_DIR / "app_icon_light.png", 512)
    copy_png(master, SERVER_PUBLIC_DIR / "assets" / "assets" / "branding" / "app_icon_256.png", 256)
    copy_png(tray, SERVER_PUBLIC_DIR / "assets" / "assets" / "branding" / "tray_icon_template.png", 64)
    copy_png(master, SERVER_PUBLIC_DIR / "assets" / "web" / "icons" / "Icon-192.png", 192)

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
