#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tool" / "branding_source"
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
EXTENSION_ICON_DIR = ROOT.parent / "extensions" / "chrome-browser" / "icons"
EXTENSION_LOGO_PATH = EXTENSION_ICON_DIR / "logo.svg"

SOURCE_SVG = SOURCE_DIR / "neoagent-icon.svg"
SOURCE_PNG_SIZES = (16, 32, 48, 64, 128, 180, 192, 256, 512, 1024)
TRANSPARENT = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)


def ensure_dirs() -> None:
    BRANDING_DIR.mkdir(parents=True, exist_ok=True)
    WEB_ICONS_DIR.mkdir(parents=True, exist_ok=True)
    MAC_ICON_DIR.mkdir(parents=True, exist_ok=True)
    LINUX_ICON_DIR.mkdir(parents=True, exist_ok=True)
    SERVER_PUBLIC_ICONS_DIR.mkdir(parents=True, exist_ok=True)
    STATIC_IMG_DIR.mkdir(parents=True, exist_ok=True)
    LANDING_LOGO_PATH.parent.mkdir(parents=True, exist_ok=True)
    EXTENSION_ICON_DIR.mkdir(parents=True, exist_ok=True)


def source_png_path(size: int) -> Path:
    return SOURCE_DIR / f"neoagent-icon-{size}.png"


def load_source_icon(size: int) -> Image.Image:
    if size in SOURCE_PNG_SIZES and source_png_path(size).exists():
        return Image.open(source_png_path(size)).convert("RGBA")
    source = Image.open(source_png_path(1024)).convert("RGBA")
    return source.resize((size, size), Image.Resampling.LANCZOS)


def save_icon(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = load_source_icon(size)
    if image.size != (size, size):
        image = image.resize((size, size), Image.Resampling.LANCZOS)
    image.save(path, format="PNG")


def write_source_svg(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    svg = SOURCE_SVG.read_text(encoding="utf-8")
    svg = svg.replace(
        'stroke="rgba(255,255,255,0.16)"',
        'stroke="#ffffff" stroke-opacity="0.16"',
    )
    path.write_text(svg, encoding="utf-8")


def draw_scaled_circle(
    draw: ImageDraw.ImageDraw,
    size: int,
    center_x: float,
    center_y: float,
    radius: float,
    color: tuple[int, int, int, int],
) -> None:
    scale = size / 100
    draw.ellipse(
        (
            (center_x - radius) * scale,
            (center_y - radius) * scale,
            (center_x + radius) * scale,
            (center_y + radius) * scale,
        ),
        fill=color,
    )


def make_tray_template(
    size: int = 64,
    color: tuple[int, int, int, int] = BLACK,
) -> Image.Image:
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    draw = ImageDraw.Draw(img)
    scale = size / 100
    width = max(2, round(size * 0.078))
    center = 50 * scale

    draw.arc(
        (
            (50 - 30) * scale,
            (50 - 30) * scale,
            (50 + 30) * scale,
            (50 + 30) * scale,
        ),
        start=158,
        end=444,
        fill=color,
        width=width,
    )
    draw.arc(
        (
            (50 - 17) * scale,
            (50 - 17) * scale,
            (50 + 17) * scale,
            (50 + 17) * scale,
        ),
        start=68,
        end=330,
        fill=color,
        width=width,
    )
    draw_scaled_circle(draw, size, 50, 50, 7, color)
    draw_scaled_circle(draw, size, 50, 20, 5.6, color)

    # Slightly round arc ends so the template keeps the supplied logo's soft tube feel.
    end_radius = width / 2
    for x, y in ((77.2, 74.8), (80.0, 41.2), (32.0, 29.7), (68.8, 39.2)):
        draw.ellipse(
            (
                x * scale - end_radius,
                y * scale - end_radius,
                x * scale + end_radius,
                y * scale + end_radius,
            ),
            fill=color,
        )

    # Keep the symbol optically centered inside the menu-bar bounds.
    return img.crop((0, 2, size, size + 2))


def main() -> None:
    ensure_dirs()

    for size in (1024, 512, 256, 192, 128, 64, 32):
        save_icon(BRANDING_DIR / f"app_icon_{size}.png", size)
        save_icon(BRANDING_DIR / f"app_icon_light_{size}.png", size)

    make_tray_template(64).save(BRANDING_DIR / "tray_icon_template.png", format="PNG")
    make_tray_template(64, WHITE).save(BRANDING_DIR / "tray_icon_light_template.png", format="PNG")

    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_icon(MAC_ICON_DIR / f"app_icon_{size}.png", size)

    save_icon(LINUX_ICON_DIR / "app_icon.png", 256)

    load_source_icon(256).save(
        WINDOWS_ICON_PATH,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    web_icon_sizes = {
        192: "Icon-192.png",
        512: "Icon-512.png",
    }
    for size, filename in web_icon_sizes.items():
        save_icon(WEB_ICONS_DIR / filename, size)
        save_icon(WEB_ICONS_DIR / filename.replace("Icon-", "Icon-maskable-"), size)
        save_icon(WEB_ICONS_DIR / filename.replace(".png", "-light.png"), size)
        save_icon(WEB_ICONS_DIR / filename.replace("Icon-", "Icon-maskable-").replace(".png", "-light.png"), size)
        save_icon(SERVER_PUBLIC_ICONS_DIR / filename, size)
        save_icon(SERVER_PUBLIC_ICONS_DIR / filename.replace("Icon-", "Icon-maskable-"), size)

    save_icon(WEB_DIR / "favicon.png", 32)
    save_icon(SERVER_PUBLIC_DIR / "favicon.png", 32)
    write_source_svg(WEB_DIR / "favicon.svg")
    write_source_svg(WEB_DIR / "favicon_light.svg")
    write_source_svg(SERVER_PUBLIC_DIR / "favicon.svg")
    write_source_svg(SERVER_PUBLIC_DIR / "favicon_light.svg")
    write_source_svg(LANDING_LOGO_PATH)
    write_source_svg(EXTENSION_LOGO_PATH)

    for size in (16, 48, 128):
        save_icon(EXTENSION_ICON_DIR / f"icon{size}.png", size)

    save_icon(STATIC_IMG_DIR / "app_icon.png", 512)
    save_icon(STATIC_IMG_DIR / "app_icon_light.png", 512)
    save_icon(SERVER_PUBLIC_DIR / "assets" / "assets" / "branding" / "app_icon_256.png", 256)
    make_tray_template(64).save(
        SERVER_PUBLIC_DIR / "assets" / "assets" / "branding" / "tray_icon_template.png",
        format="PNG",
    )
    save_icon(SERVER_PUBLIC_DIR / "assets" / "web" / "icons" / "Icon-192.png", 192)

    android_icon_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_icon_sizes.items():
        save_icon(ANDROID_RES_DIR / folder / "ic_launcher.png", size)


if __name__ == "__main__":
    main()
