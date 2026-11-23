"""Four FITNS logo concepts, drawn on a 100-unit canvas, rendered as PNGs."""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
FONT = 'assets/fonts/Inter-Variable.ttf'
ORANGE = (234, 88, 12, 255)
ORANGE_D = (194, 65, 12, 255)
WHITE = (255, 255, 255, 255)
SS = 8  # supersampling


def canvas(px):
    big = px * SS
    return Image.new('RGBA', (big, big), (0, 0, 0, 0)), big / 100


def tile(px, mark_fn):
    img, u = canvas(px)
    d = ImageDraw.Draw(img)
    big = px * SS
    # Orange tile with a soft top-left light.
    for y in range(big):
        t = y / big
        col = tuple(int(ORANGE[i] + (ORANGE_D[i] - ORANGE[i]) * t * 0.6) for i in range(3)) + (255,)
        d.line([(0, y), (big, y)], fill=col)
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=big * 0.23, fill=255)
    base = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    base.paste(img, (0, 0), mask)
    mark_fn(ImageDraw.Draw(base), u, base)
    return base.resize((px, px), Image.LANCZOS)


def line(d, u, a, b, w, col=WHITE):
    d.line([(a[0] * u, a[1] * u), (b[0] * u, b[1] * u)], fill=col, width=round(w * u))
    for x, y in (a, b):
        d.ellipse(((x - w / 2) * u, (y - w / 2) * u, (x + w / 2) * u, (y + w / 2) * u), fill=col)


def dot(d, u, c, r, col=WHITE):
    d.ellipse(((c[0] - r) * u, (c[1] - r) * u, (c[0] + r) * u, (c[1] + r) * u), fill=col)


def poly(d, u, pts, col=WHITE):
    d.polygon([(x * u, y * u) for x, y in pts], fill=col)


# 1. Constellation — the F drawn as points joined by lines, the way a
# tracker joins days into a picture of progress.
def constellation(d, u, img):
    a, b, c, e, f = (37, 76), (37, 29), (67, 29), (37, 53), (59, 53)
    for p, q in ((a, b), (b, c), (e, f)):
        line(d, u, p, q, 5.5)
    for p, r in ((a, 7.5), (b, 7.5), (c, 7.5), (f, 7.5)):
        dot(d, u, p, r)
    # The joint where the middle bar leaves the stem, hollow.
    dot(d, u, e, 6.5)
    dot(d, u, e, 3.2, ORANGE)


# 2. Staircase — a solid flight of stairs climbing to the right, with a
# dot standing on the top step: getting there, one step a day.
def staircase(d, u, img):
    pts = [(20, 80), (20, 64), (36, 64), (36, 50), (52, 50), (52, 36), (80, 36), (80, 80)]
    poly(d, u, pts)
    dot(d, u, (66, 23), 7)


# 3. Plate — a weight plate seen face on, its grip slot cut as an F.
def plate(d, u, img):
    dot(d, u, (50, 50), 31)
    o = ORANGE
    # The F, cut out of the plate.
    d.rounded_rectangle((40 * u, 32 * u, 49 * u, 70 * u), radius=3 * u, fill=o)
    d.rounded_rectangle((40 * u, 32 * u, 64 * u, 41 * u), radius=3 * u, fill=o)
    d.rounded_rectangle((40 * u, 48 * u, 58 * u, 56 * u), radius=3 * u, fill=o)
    # The plate's rim.
    r = 26.5
    d.ellipse(((50 - r) * u, (50 - r) * u, (50 + r) * u, (50 + r) * u), outline=ORANGE, width=round(2.2 * u))


# 4. Lift-off — an F whose top bar becomes an arrow, climbing up and away.
def liftoff(d, u, img):
    sk = 0.28  # slant
    def sl(x, y):
        return (x + (60 - y) * sk, y)
    stem = [sl(32, 78), sl(43, 78), sl(43, 30), sl(32, 30)]
    poly(d, u, stem)
    # Top bar rising to an arrowhead.
    bar = [sl(32, 30), sl(58, 22), sl(60, 31), sl(43, 37)]
    poly(d, u, bar)
    tip = [sl(54, 13), sl(72, 19), sl(61, 34)]
    poly(d, u, tip)
    mid = [sl(43, 50), sl(58, 46), sl(60, 55), sl(43, 59)]
    poly(d, u, mid)


OPTIONS = [
    ('1-constellation', 'Constellation', 'An F drawn as points joined by\nlines: days tracked, joined into\na picture of progress.', constellation),
    ('2-staircase', 'Staircase', 'A flight of stairs climbing to\nthe right, a dot on the top step:\ngetting there, a step a day.', staircase),
    ('3-plate', 'Plate', 'A weight plate seen face on,\nits grip slot cut as an F.', plate),
    ('4-liftoff', 'Lift-off', 'A slanted F whose top bar turns\ninto an arrow, climbing up\nand away.', liftoff),
]

for key, name, _, fn in OPTIONS:
    tile(512, fn).save(OUT / f'fitns-logo-{key}.png', optimize=True)

# The overview: each option big, then at launcher sizes on light and dark.
W, H = 1600, 1030
sheet = Image.new('RGBA', (W, H), (247, 247, 250, 255))
d = ImageDraw.Draw(sheet)
title = ImageFont.truetype(FONT, 46); title.set_variation_by_axes([32, 800])
name_f = ImageFont.truetype(FONT, 34); name_f.set_variation_by_axes([24, 800])
body_f = ImageFont.truetype(FONT, 19); body_f.set_variation_by_axes([14, 450])
d.text((60, 50), 'FITNS logo options', font=title, fill=(17, 17, 20, 255))
d.text((60, 108), 'Concepts only — the app keeps its current logo.', font=body_f, fill=(110, 110, 115, 255))
col = W // 4
for i, (key, name, desc, fn) in enumerate(OPTIONS):
    x0 = i * col + 40
    sheet.alpha_composite(tile(300, fn), (x0, 170))
    d.text((x0, 495), f'{i + 1}. {name}', font=name_f, fill=(17, 17, 20, 255))
    d.multiline_text((x0, 540), desc, font=body_f, fill=(90, 90, 96, 255), spacing=6)
    # Launcher sizes on light and dark.
    y = 660
    d.rounded_rectangle((x0 - 10, y - 10, x0 + 330, y + 120), radius=20, fill=(255, 255, 255, 255))
    d.rounded_rectangle((x0 - 10, y + 140, x0 + 330, y + 270), radius=20, fill=(28, 28, 32, 255))
    for yy in (y, y + 150):
        xx = x0 + 10
        for s in (96, 64, 40, 24):
            sheet.alpha_composite(tile(s, fn), (xx, yy + (100 - s) // 2))
            xx += s + 18
sheet.convert('RGB').save(OUT / 'fitns-logo-options.png', optimize=True)
print('ok')
