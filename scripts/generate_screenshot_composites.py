#!/usr/bin/env python3
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

COPY = {
    "arPlacement": "Place the solar system in your room",
    "sceneExperience": "Explore space without AR",
    "scaleControls": "Compare true scale or readable scale",
    "objectDetail": "Learn facts, orbit data, and physical scale",
    "apod": "A new NASA image every day",
    "exploreLibrary": "Planets, moons, satellites, and NASA icons",
    "home": "Home with today's space highlights",
    "macMainWindow": "Explore Luna on Mac",
}


def font(size, bold=False):
    names = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def wrapped(draw, text, font_obj, max_width):
    words = text.split()
    lines = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        width = draw.textbbox((0, 0), candidate, font=font_obj)[2]
        if width <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def composite(source, destination, caption):
    image = Image.open(source).convert("RGB")
    width, height = image.size
    top_band = max(180, int(height * 0.16))
    canvas = Image.new("RGB", (width, height + top_band), (14, 18, 28))
    canvas.paste(image, (0, top_band))

    draw = ImageDraw.Draw(canvas)
    title_font = font(max(42, int(width * 0.045)), bold=True)
    lines = wrapped(draw, caption, title_font, int(width * 0.84))
    line_height = int(title_font.size * 1.18)
    total_height = line_height * len(lines)
    y = int((top_band - total_height) / 2)
    for line in lines:
        text_width = draw.textbbox((0, 0), line, font=title_font)[2]
        draw.text(((width - text_width) / 2, y), line, fill=(245, 248, 255), font=title_font)
        y += line_height

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination)


def screen_id(path):
    stem = path.stem
    for key in COPY:
        if key in stem:
            return key
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    input_root = Path(args.input)
    output_root = Path(args.output)

    for source in input_root.rglob("*.png"):
        key = screen_id(source)
        if not key:
            continue
        platform = source.parent.name
        destination = output_root / platform / f"{key}.png"
        composite(source, destination, COPY[key])


if __name__ == "__main__":
    main()
