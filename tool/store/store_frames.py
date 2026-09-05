# -*- coding: utf-8 -*-
"""Build store screenshots: caption over a framed device on a dark gradient.

Phone targets use the portrait phone captures, tablet targets the landscape
tablet ones -- and because the tablet capture is landscape, the tablet canvases
are landscape too, so the device fills the frame instead of floating as a strip
in the middle of a tall page.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

ARCHIVO = 'assets/fonts/Archivo-Variable.ttf'
CLEAN = 'store-assets/clean'

PHONE = 'phone'
TABLET = 'tablet'

# folder -> (width, height, which capture set)
TARGETS = {
    'android-phone':  (1080, 1920, PHONE),
    'ios-6.5':        (1242, 2688, PHONE),
    'android-tablet': (2560, 1600, TABLET),
    'ipad-13':        (2732, 2048, TABLET),
}

# (phone capture, tablet capture, headline, sub-headline)
SHOTS = [
    ('Screenshot_1788436818.png', 'Screenshot_1788439953.png',
     'Your whole fleet, at a glance',
     'Assignments, warranties and maintenance in a single view.'),
    ('Screenshot_1788436834.png', 'Screenshot_1788439966.png',
     'Find any asset in seconds',
     'Search by name, tag, serial or model — or just scan the code.'),
    ('Screenshot_1788436978.png', 'Screenshot_1788440027.png',
     'Every device, fully documented',
     'Owner, warranty and history — hand it back in one tap.'),
    ('Screenshot_1788436950.png', 'Screenshot_1788440013.png',
     'Maintenance that stays on track',
     'Log the job, attach photos, follow it through to done.'),
]

INK = (255, 255, 255)
MUTED = (150, 175, 196)
ACCENT_A = (47, 227, 168)
ACCENT_B = (56, 140, 232)


def font(size, weight=500):
    f = ImageFont.truetype(ARCHIVO, int(size))
    f.set_variation_by_axes([weight, 100])
    return f


def _screen(a, b):
    x, y = np.asarray(a).astype(float), np.asarray(b).astype(float)
    return (255 - (255 - x) * (255 - y * 0.62) / 255).clip(0, 255).astype('uint8')


def background(W, H):
    """Deep navy, a teal bloom top-left and a blue one lower right."""
    bg = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(bg)
    top, bot = (8, 18, 27), (3, 6, 11)
    for y in range(H):
        t = y / max(1, H - 1)
        d.line([(0, y), (W, y)],
               fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    glow = Image.new('RGB', (W, H), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r1 = W * 0.62
    gd.ellipse([W * 0.30 - r1, H * 0.10 - r1, W * 0.30 + r1, H * 0.10 + r1],
               fill=(8, 52, 60))
    r2 = W * 0.55
    gd.ellipse([W * 1.02 - r2, H * 0.62 - r2, W * 1.02 + r2, H * 0.62 + r2],
               fill=(10, 30, 64))
    glow = glow.filter(ImageFilter.GaussianBlur(W // 6))
    return Image.fromarray(_screen(bg, glow))


def rounded_mask(size, radius, ss=4):
    w, h = size
    m = Image.new('L', (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * ss - 1, h * ss - 1],
                                        radius=radius * ss, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def wrap(draw, text, f, max_w):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if draw.textlength(t, font=f) <= max_w or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def balanced(draw, text, f, max_w):
    """Split into two lines at the point that leaves them closest in width."""
    words = text.split()
    best, score = None, None
    for i in range(1, len(words)):
        a, b = ' '.join(words[:i]), ' '.join(words[i:])
        wa, wb = draw.textlength(a, font=f), draw.textlength(b, font=f)
        if max(wa, wb) > max_w:
            continue
        s = abs(wa - wb)
        if score is None or s < score:
            best, score = [a, b], s
    return best or wrap(draw, text, f, max_w)


def fit_lines(draw, text, max_w, start, weight):
    """One line if it can be had at a readable size; otherwise two even ones."""
    size = start
    while size >= start * 0.74:
        f = font(size, weight)
        if draw.textlength(text, font=f) <= max_w:
            return f, [text]
        size -= 2
    f = font(start * 0.86, weight)
    return f, balanced(draw, text, f, max_w)


def accent_bar(canvas, cx, y, w, h):
    bar = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(bar)
    for x in range(w):
        t = x / max(1, w - 1)
        d.line([(x, 0), (x, h)],
               fill=tuple(int(ACCENT_A[i] + (ACCENT_B[i] - ACCENT_A[i]) * t)
                          for i in range(3)))
    canvas.paste(bar, (int(cx - w // 2), int(y)), rounded_mask((w, h), h // 2))


def device(shot, frame_w):
    """Device body with the capture inset behind a thin bezel. Corner radius and
    bezel key off the frame's short side, so a landscape tablet does not end up
    with the corner rounding of a phone stretched across it."""
    ratio = shot.height / shot.width
    short = frame_w * min(1.0, ratio)
    pad = max(6, int(short * 0.020))
    inner_w = frame_w - 2 * pad
    inner_h = int(round(inner_w * ratio))
    frame_h = inner_h + 2 * pad
    radius = int(min(frame_w, frame_h) * 0.075)

    body = Image.new('RGBA', (frame_w, frame_h), (0, 0, 0, 0))
    plate = Image.new('RGB', (frame_w, frame_h), (13, 20, 28))
    body.paste(plate, (0, 0), rounded_mask((frame_w, frame_h), radius))

    screen = shot.resize((inner_w, inner_h), Image.LANCZOS).convert('RGB')
    body.paste(screen, (pad, pad),
               rounded_mask((inner_w, inner_h), max(2, radius - pad)))

    edge = Image.new('RGBA', (frame_w, frame_h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [1, 1, frame_w - 2, frame_h - 2], radius=radius,
        outline=(126, 178, 200, 120), width=max(2, min(frame_w, frame_h) // 320))
    return Image.alpha_composite(body, edge)


def compose(W, H, shot_path, head, sub):
    canvas = background(W, H).convert('RGBA')
    d = ImageDraw.Draw(canvas)
    cx = W // 2

    # Type scales off the short edge, so a wide landscape canvas does not get a
    # headline three times the size of the phone one.
    base = W if H >= W else int(H * 0.82)
    text_w = min(int(W * 0.83), int(base * 1.72))

    hf, hlines = fit_lines(d, head, text_w, base * 0.078, 800)
    sf, slines = fit_lines(d, sub, int(text_w * 0.92), base * 0.033, 400)

    y = int(H * 0.048)
    for ln in hlines:
        bb = hf.getbbox(ln)
        d.text((cx - d.textlength(ln, font=hf) / 2, y - bb[1]), ln, font=hf, fill=INK)
        y += int((bb[3] - bb[1]) * 1.34)
    y += int(H * 0.012)
    for ln in slines:
        bb = sf.getbbox(ln)
        d.text((cx - d.textlength(ln, font=sf) / 2, y - bb[1]), ln, font=sf, fill=MUTED)
        y += int((bb[3] - bb[1]) * 1.5)

    y += int(H * 0.014)
    bar_h = max(5, int(base * 0.005))
    accent_bar(canvas, cx, y, int(base * 0.10), bar_h)
    y += bar_h

    shot = Image.open(shot_path).convert('RGB')
    landscape = shot.width > shot.height
    band_top = y + int(H * (0.060 if landscape else 0.048))
    band_bot = H - int(H * 0.040)

    dev = device(shot, int(W * (0.88 if landscape else 0.64)))
    if dev.height > band_bot - band_top:
        dev = device(shot, int(dev.width * (band_bot - band_top) / dev.height))

    dx = cx - dev.width // 2
    dy = band_top + max(0, (band_bot - band_top - dev.height) // 2)

    halo = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).rounded_rectangle(
        [dx - 14, dy - 14, dx + dev.width + 14, dy + dev.height + 14],
        radius=int(min(dev.width, dev.height) * 0.09), fill=(22, 84, 108, 95))
    canvas = Image.alpha_composite(canvas, halo.filter(ImageFilter.GaussianBlur(W // 22)))
    canvas.alpha_composite(dev, (dx, dy))
    return canvas.convert('RGB')


if __name__ == '__main__':
    for folder, (W, H, source) in TARGETS.items():
        out = 'store-assets/' + folder
        os.makedirs(out, exist_ok=True)
        for i, (phone_f, tablet_f, head, sub) in enumerate(SHOTS, 1):
            src = phone_f if source == PHONE else tablet_f
            compose(W, H, CLEAN + '/' + src, head, sub).save('%s/%02d.png' % (out, i))
        print('%-16s %d images at %dx%d  (%s captures)'
              % (folder, len(SHOTS), W, H, source))
