#!/usr/bin/env python3
"""Prepares raw source artwork for the Flutter bundle.

Reads the untouched artwork in assets/Eggbound_Rush_APPLICATION_* and writes a
clean, density-aware asset tree into assets/app. Source files are never
modified.
"""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC_GAMEPLAY = ROOT / "assets" / "Eggbound_Rush_APPLICATION_gameplay_assets"
SRC_EXTRA = ROOT / "assets" / "Eggbound_Rush_APPLICATION_additional_assets"
OUT = ROOT / "assets" / "app"

ALPHA_THRESHOLD = 8
TRIM_PADDING = 2
DENSITIES = (1, 2, 3)


@dataclass(frozen=True)
class Sprite:
    source: str
    name: str
    logical_width: int


@dataclass(frozen=True)
class SpriteSheet:
    source: str
    names: tuple[str, ...]
    logical_width: int


SPRITES = (
    Sprite("white_egg_asset", "egg_white", 52),
    Sprite("golden_egg_asset", "egg_golden", 52),
    Sprite("patterned_egg_asset", "egg_patterned", 52),
    Sprite("wooden_nest_asset", "nest", 96),
    Sprite("feed_trough_asset", "feed_trough", 112),
    Sprite("water_trough_asset", "water_trough", 112),
    Sprite("wooden_fence_asset", "fence", 140),
    Sprite("wooden_signpost_asset", "signpost", 96),
    Sprite("small_basket_asset", "basket", 88),
    Sprite("hay_bale_asset", "hay_bale", 112),
    Sprite("pasture_bush_asset", "bush", 96),
    Sprite("grass_tuft_asset", "grass_tuft", 72),
    Sprite("small_flower_asset", "flower", 48),
    Sprite("wildflower_cluster_asset", "wildflowers", 96),
    Sprite("field_rock_asset", "rock", 80),
    Sprite("soft_cloud_asset", "cloud", 140),
    Sprite("stylized_sun_asset", "sun", 120),
)

SHEETS = (
    SpriteSheet(
        "white_chicken_set_asset",
        ("chicken_idle", "chicken_walk", "chicken_peck", "chicken_nesting"),
        120,
    ),
    SpriteSheet(
        "gold_coin_set_asset",
        ("point_badge", "point_badge_tilt", "point_badge_stack"),
        56,
    ),
)

BACKGROUNDS = {
    "bg1_asset": "pasture_green_meadow",
    "bg2_asset": "pasture_sunny_field",
    "bg3_asset": "pasture_flower_meadow",
}


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def content_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    mask = image.split()[3].point(lambda p: 255 if p > ALPHA_THRESHOLD else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError("image has no visible pixels")
    return bbox


def trim(image: Image.Image) -> Image.Image:
    left, top, right, bottom = content_bbox(image)
    left = max(0, left - TRIM_PADDING)
    top = max(0, top - TRIM_PADDING)
    right = min(image.width, right + TRIM_PADDING)
    bottom = min(image.height, bottom + TRIM_PADDING)
    return image.crop((left, top, right, bottom))


def opaque_runs(values: list[int]) -> list[tuple[int, int]]:
    """Returns inclusive-exclusive ranges where the projection has content."""
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for index, value in enumerate(values):
        if value > 0 and start is None:
            start = index
        elif value == 0 and start is not None:
            runs.append((start, index))
            start = None
    if start is not None:
        runs.append((start, len(values)))
    return runs


def split_sheet(image: Image.Image) -> list[Image.Image]:
    """Splits a sheet into cells using empty rows/columns as separators."""
    mask = image.split()[3].point(lambda p: 255 if p > ALPHA_THRESHOLD else 0)
    pixels = mask.load()

    row_sums = [
        sum(pixels[x, y] for x in range(mask.width)) for y in range(mask.height)
    ]
    cells: list[Image.Image] = []
    for top, bottom in opaque_runs(row_sums):
        band = image.crop((0, top, image.width, bottom))
        band_mask = band.split()[3].point(lambda p: 255 if p > ALPHA_THRESHOLD else 0)
        band_pixels = band_mask.load()
        column_sums = [
            sum(band_pixels[x, y] for y in range(band_mask.height))
            for x in range(band_mask.width)
        ]
        for left, right in opaque_runs(column_sums):
            cells.append(trim(band.crop((left, 0, right, band.height))))
    return cells


def fit_logical_width(desired: int, source_width: int) -> int:
    """Caps the logical width so the highest density stays natively rendered.

    Flutter derives an image's logical size from its density folder, so a 3.0x
    file that is not exactly three times the logical width would be laid out at
    the wrong size.
    """
    return max(1, min(desired, source_width // DENSITIES[-1]))


def write_densities(
    image: Image.Image,
    name: str,
    logical_width: int,
    densities: tuple[int, ...] = DENSITIES,
) -> list[str]:
    """Writes one PNG per density, never upscaling beyond the source."""
    lines: list[str] = []
    for density in densities:
        width = max(1, logical_width * density)
        height = max(1, round(image.height * width / image.width))
        resized = image.resize((width, height), Image.LANCZOS)
        folder = OUT / "images" if density == 1 else OUT / "images" / f"{density}.0x"
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / f"{name}.png"
        resized.save(target, "PNG", optimize=True)
        lines.append(f"{target.relative_to(ROOT)}  {width}x{height}")
    return lines


def build_sprites() -> list[str]:
    report: list[str] = []
    for sprite in SPRITES:
        image = trim(load_rgba(SRC_GAMEPLAY / f"{sprite.source}.webp"))
        logical = fit_logical_width(sprite.logical_width, image.width)
        report += write_densities(image, sprite.name, logical)
    return report


def build_sheets() -> list[str]:
    report: list[str] = []
    for sheet in SHEETS:
        cells = split_sheet(load_rgba(SRC_GAMEPLAY / f"{sheet.source}.webp"))
        if len(cells) != len(sheet.names):
            raise ValueError(
                f"{sheet.source}: expected {len(sheet.names)} cells, found {len(cells)}"
            )
        # One shared scale for the whole sheet, so poses keep their relative size.
        widest = max(cell.width for cell in cells)
        group_logical = fit_logical_width(sheet.logical_width, widest)
        for cell, name in zip(cells, sheet.names):
            logical = max(1, round(cell.width * group_logical / widest))
            report += write_densities(cell, name, logical)
    return report


def build_backgrounds() -> list[str]:
    folder = OUT / "backgrounds"
    folder.mkdir(parents=True, exist_ok=True)
    report: list[str] = []
    for source, name in BACKGROUNDS.items():
        image = Image.open(SRC_GAMEPLAY / f"{source}.webp").convert("RGB")
        target = folder / f"{name}.webp"
        image.save(target, "WEBP", quality=88, method=6)
        report.append(f"{target.relative_to(ROOT)}  {image.width}x{image.height}")
    return report


def build_branding() -> list[str]:
    folder = OUT / "branding"
    folder.mkdir(parents=True, exist_ok=True)
    report: list[str] = []

    for source, name in (
        ("Vertical_Loading_Screen", "loading_portrait"),
        ("Horizontal_Loading_Screen", "loading_landscape"),
    ):
        image = Image.open(SRC_EXTRA / f"{source}.webp").convert("RGB")
        target = folder / f"{name}.webp"
        image.save(target, "WEBP", quality=90, method=6)
        report.append(f"{target.relative_to(ROOT)}  {image.width}x{image.height}")

    # The wordmark source tops out at ~460px, so it ships at 1x/2x only and
    # Flutter falls back to the 2x file on 3x screens.
    logo = trim(load_rgba(SRC_EXTRA / "Game_Name.webp"))
    wordmark_densities = (1, 2)
    report += write_densities(
        logo, "wordmark", logo.width // wordmark_densities[-1], wordmark_densities
    )
    for density in wordmark_densities:
        source_dir = OUT / "images" if density == 1 else OUT / "images" / f"{density}.0x"
        target_dir = folder if density == 1 else folder / f"{density}.0x"
        target_dir.mkdir(parents=True, exist_ok=True)
        shutil.move(str(source_dir / "wordmark.png"), str(target_dir / "wordmark.png"))
    report = [line.replace("app/images", "app/branding") for line in report]
    return report


def rounded_mask(size: int, radius: int, feather: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(feather))


def build_icons() -> list[str]:
    folder = OUT / "icon"
    folder.mkdir(parents=True, exist_ok=True)
    report: list[str] = []

    source = Image.open(SRC_EXTRA / "Icon.png").convert("RGBA")
    master = source.resize((1024, 1024), Image.LANCZOS)

    # App Store rejects icons that carry an alpha channel.
    ios_icon = Image.new("RGB", (1024, 1024), (255, 255, 255))
    ios_icon.paste(master, (0, 0), master)
    ios_target = folder / "app_icon_ios_1024.png"
    ios_icon.save(ios_target, "PNG", optimize=True)
    report.append(f"{ios_target.relative_to(ROOT)}  1024x1024 no-alpha")

    # Adaptive icon: artwork kept inside the 66/108 safe zone, edges extended
    # with a blurred copy of itself so the mask never reveals empty corners.
    background = master.convert("RGB").filter(ImageFilter.GaussianBlur(48))
    background = background.resize((1152, 1152), Image.LANCZOS).crop(
        (64, 64, 1088, 1088)
    )
    background_target = folder / "app_icon_adaptive_background.png"
    background.save(background_target, "PNG", optimize=True)
    report.append(f"{background_target.relative_to(ROOT)}  1024x1024")

    inner = 660
    scaled = master.resize((inner, inner), Image.LANCZOS)
    scaled.putalpha(rounded_mask(inner, radius=int(inner * 0.28), feather=10))
    foreground = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    offset = (1024 - inner) // 2
    foreground.paste(scaled, (offset, offset), scaled)
    foreground_target = folder / "app_icon_adaptive_foreground.png"
    foreground.save(foreground_target, "PNG", optimize=True)
    report.append(f"{foreground_target.relative_to(ROOT)}  1024x1024 safe-zone")

    return report


def build_contact_sheet() -> Path:
    files = sorted((OUT / "images" / "3.0x").glob("*.png"))
    columns = 6
    cell = 200
    rows = (len(files) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * cell, rows * cell), (245, 245, 240))
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(files):
        image = Image.open(path).convert("RGBA")
        image.thumbnail((cell - 30, cell - 40), Image.LANCZOS)
        x = (index % columns) * cell + (cell - image.width) // 2
        y = (index // columns) * cell + (cell - 30 - image.height) // 2
        sheet.paste(image, (x, y), image)
        draw.text(
            ((index % columns) * cell + 6, (index // columns) * cell + cell - 22),
            path.stem,
            fill=(40, 40, 40),
        )
    target = ROOT / "tools" / "preview" / "contact_sheet.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(target, "PNG")
    return target


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    report: list[str] = []
    report += build_sheets()
    report += build_sprites()
    report += build_backgrounds()
    report += build_branding()
    report += build_icons()
    print("\n".join(report))
    print(f"\ncontact sheet: {build_contact_sheet().relative_to(ROOT)}")
    total = sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file())
    print(f"total: {total / 1_048_576:.2f} MB")


if __name__ == "__main__":
    main()
