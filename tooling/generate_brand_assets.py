from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "images"

BG = (11, 18, 32, 255)
SURFACE = (17, 24, 39, 255)
CARD = (26, 34, 52, 255)
INDIGO = (79, 70, 229, 255)
INDIGO_2 = (99, 102, 241, 255)
PURPLE = (124, 58, 237, 255)
WHITE = (248, 250, 252, 255)


def lerp(a, b, t):
    return int(a + (b - a) * t)


def gradient(size, start, end, diagonal=True):
    image = Image.new("RGBA", (size, size), start)
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            t = ((x + y) / (size * 2)) if diagonal else (y / size)
            pixels[x, y] = tuple(lerp(start[i], end[i], t) for i in range(4))
    return image


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def draw_mark(size=1024, transparent=False, adaptive=False):
    scale = 4
    canvas_size = size * scale
    image = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))

    if not transparent:
        base = gradient(canvas_size, BG, (31, 23, 73, 255))
        mask = rounded_mask(canvas_size, int(canvas_size * 0.22))
        image.alpha_composite(base)
        image.putalpha(mask)

    draw = ImageDraw.Draw(image)
    inset = int(canvas_size * (0.18 if adaptive else 0.12))
    box = (inset, inset, canvas_size - inset, canvas_size - inset)
    panel_radius = int(canvas_size * 0.14)

    shadow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (box[0], box[1] + int(canvas_size * 0.04), box[2], box[3] + int(canvas_size * 0.04)),
        radius=panel_radius,
        fill=(0, 0, 0, 90),
    )
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(int(canvas_size * 0.055))))

    panel = gradient(canvas_size, INDIGO_2, PURPLE)
    panel_mask = Image.new("L", (canvas_size, canvas_size), 0)
    panel_draw = ImageDraw.Draw(panel_mask)
    panel_draw.rounded_rectangle(box, radius=panel_radius, fill=255)
    image.alpha_composite(Image.composite(panel, Image.new("RGBA", panel.size), panel_mask))

    draw = ImageDraw.Draw(image)
    line_w = int(canvas_size * 0.050)
    points = [
        (box[0] + int(canvas_size * 0.18), box[1] + int(canvas_size * 0.48)),
        (box[0] + int(canvas_size * 0.30), box[1] + int(canvas_size * 0.36)),
        (box[0] + int(canvas_size * 0.42), box[1] + int(canvas_size * 0.47)),
        (box[0] + int(canvas_size * 0.58), box[1] + int(canvas_size * 0.28)),
    ]
    draw.line(points, fill=WHITE, width=line_w, joint="curve")
    draw.line(
        [
            (box[0] + int(canvas_size * 0.18), box[1] + int(canvas_size * 0.60)),
            (box[0] + int(canvas_size * 0.34), box[1] + int(canvas_size * 0.49)),
            (box[0] + int(canvas_size * 0.48), box[1] + int(canvas_size * 0.61)),
            (box[0] + int(canvas_size * 0.68), box[1] + int(canvas_size * 0.38)),
        ],
        fill=(224, 231, 255, 220),
        width=int(line_w * 0.70),
        joint="curve",
    )

    draw.rounded_rectangle(
        (
            box[0] + int(canvas_size * 0.12),
            box[1] + int(canvas_size * 0.14),
            box[0] + int(canvas_size * 0.31),
            box[1] + int(canvas_size * 0.18),
        ),
        radius=int(canvas_size * 0.02),
        fill=(224, 231, 255, 150),
    )
    draw.rounded_rectangle(
        (
            box[0] + int(canvas_size * 0.58),
            box[1] + int(canvas_size * 0.70),
            box[0] + int(canvas_size * 0.77),
            box[1] + int(canvas_size * 0.74),
        ),
        radius=int(canvas_size * 0.02),
        fill=(224, 231, 255, 145),
    )

    return image.resize((size, size), Image.Resampling.LANCZOS)


def font(size, bold=False):
    names = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ]
    for name in names:
        path = Path(name)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def logo_png(path, transparent=True):
    image = Image.new("RGBA", (1400, 420), (0, 0, 0, 0) if transparent else BG)
    mark = draw_mark(260, transparent=False)
    image.alpha_composite(mark, (70, 80))
    draw = ImageDraw.Draw(image)
    draw.text((380, 112), "CashPilot AI", font=font(88, bold=True), fill=WHITE)
    draw.text(
        (384, 225),
        "AI-powered personal finance",
        font=font(34),
        fill=(186, 196, 214, 255),
    )
    image.save(path)


def notification(path):
    image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    w = 38
    pts = [(130, 276), (205, 198), (272, 266), (376, 144)]
    draw.line(pts, fill=(255, 255, 255, 255), width=w, joint="curve")
    draw.line([(136, 340), (230, 280), (306, 344), (394, 246)], fill=(255, 255, 255, 220), width=28)
    image.save(path)


def svg(path):
    path.write_text(
        """<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 512\" role=\"img\" aria-label=\"CashPilot AI\">
<rect width=\"512\" height=\"512\" rx=\"112\" fill=\"#0B1220\"/>
<rect x=\"64\" y=\"64\" width=\"384\" height=\"384\" rx=\"72\" fill=\"url(#g)\"/>
<path d=\"M154 270 L218 206 L282 270 L374 160\" fill=\"none\" stroke=\"#F8FAFC\" stroke-width=\"28\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>
<path d=\"M158 326 L236 278 L302 332 L392 238\" fill=\"none\" stroke=\"#E0E7FF\" stroke-width=\"20\" stroke-linecap=\"round\" stroke-linejoin=\"round\" opacity=\".9\"/>
<rect x=\"122\" y=\"124\" width=\"98\" height=\"18\" rx=\"9\" fill=\"#E0E7FF\" opacity=\".65\"/>
<rect x=\"316\" y=\"356\" width=\"98\" height=\"18\" rx=\"9\" fill=\"#E0E7FF\" opacity=\".65\"/>
<defs><linearGradient id=\"g\" x1=\"64\" y1=\"64\" x2=\"448\" y2=\"448\"><stop stop-color=\"#6366F1\"/><stop offset=\"1\" stop-color=\"#7C3AED\"/></linearGradient></defs>
</svg>
""",
        encoding="utf-8",
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    draw_mark(1024).save(OUT / "app_icon.png")
    draw_mark(1024, transparent=True).save(OUT / "app_icon_transparent.png")
    draw_mark(1024, transparent=True, adaptive=True).save(OUT / "app_icon_adaptive_foreground.png")
    Image.new("RGBA", (1024, 1024), BG).save(OUT / "app_icon_adaptive_background.png")
    draw_mark(512).save(OUT / "favicon.png")
    draw_mark(512, transparent=True).save(OUT / "splash_logo.png")
    logo_png(OUT / "app_logo.png", transparent=False)
    logo_png(OUT / "app_logo_transparent.png", transparent=True)
    notification(OUT / "notification_icon.png")
    svg(OUT / "app_logo.svg")


if __name__ == "__main__":
    main()
