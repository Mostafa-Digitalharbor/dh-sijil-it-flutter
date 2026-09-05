# -*- coding: utf-8 -*-
"""The two graphics Play asks for on the store listing page.

  icon-512.png                 512 x 512, opaque -- Play masks and rounds it
  feature-graphic-1024x500.png 1024 x 500, the banner shown when Play features
                               the app

Both are built from the brand assets already in the repo, on the same dark
gradient as the store screenshots, so the listing reads as one set.
"""
import os
from PIL import Image, ImageDraw

from store_frames import background, device, font, MUTED, ACCENT_A, ACCENT_B

OUT = 'store-assets/play'
ICON_SRC = 'assets/icon/app-icon.png'          # full-bleed square, no alpha
LOCKUP = 'assets/sijil-lockup-dark.png'        # light artwork, for dark grounds
HERO_SHOT = 'store-assets/clean/Screenshot_1788436818.png'

# Two explicit lines rather than a wrap: the em dash would otherwise dangle
# at the end of line one, which is the one place it reads as a typo.
TAGLINE = ['IT assets, people and maintenance,', 'live from your Odoo.']
TAGLINE_ONE = 'IT assets, people and maintenance — live from your Odoo.'


def play_icon():
    """512 x 512, opaque. Play rounds the corners itself, so this stays square
    and full-bleed; an alpha channel or pre-rounded corners would show as a
    dark halo inside Play's own mask."""
    im = Image.open(ICON_SRC).convert('RGB').resize((512, 512), Image.LANCZOS)
    im.save(OUT + '/icon-512.png')
    return im.size


def feature_graphic():
    W, H = 1024, 500
    canvas = background(W, H).convert('RGBA')
    d = ImageDraw.Draw(canvas)

    # The device bleeds off the bottom-right: it fills the right third without
    # having to shrink the screenshot to something illegible.
    shot = Image.open(HERO_SHOT).convert('RGB')
    dev = device(shot, 236)
    canvas.alpha_composite(dev, (W - dev.width - 78, 66))

    lock = Image.open(LOCKUP).convert('RGBA')
    lw = 392
    lock = lock.resize((lw, int(lw * lock.height / lock.width)), Image.LANCZOS)
    lx, ly = 68, 138
    canvas.alpha_composite(lock, (lx, ly))

    y = ly + lock.height + 34
    bar_w, bar_h = 96, 5
    bar = Image.new('RGB', (bar_w, bar_h))
    bd = ImageDraw.Draw(bar)
    for x in range(bar_w):
        t = x / (bar_w - 1)
        bd.line([(x, 0), (x, bar_h)],
                fill=tuple(int(ACCENT_A[i] + (ACCENT_B[i] - ACCENT_A[i]) * t)
                           for i in range(3)))
    canvas.paste(bar, (lx + 4, y))

    y += bar_h + 30
    f = font(27, 400)
    for line in TAGLINE:
        bb = f.getbbox(line)
        d.text((lx + 4, y - bb[1]), line, font=f, fill=MUTED)
        y += int((bb[3] - bb[1]) * 1.55)

    out = canvas.convert('RGB')
    out.save(OUT + '/feature-graphic-1024x500.png')
    return out.size


def feature_graphic_clean():
    """Same banner without the device.

    Google's guidance for apps in the running for editorial featuring is to keep
    screenshots and device frames out of the feature graphic. This is that
    version -- brand and promise only -- for whichever way that call goes."""
    W, H = 1024, 500
    canvas = background(W, H).convert('RGBA')
    d = ImageDraw.Draw(canvas)
    cx = W // 2

    lock = Image.open(LOCKUP).convert('RGBA')
    lw = 520
    lock = lock.resize((lw, int(lw * lock.height / lock.width)), Image.LANCZOS)
    ly = 104
    canvas.alpha_composite(lock, (cx - lw // 2, ly))

    y = ly + lock.height + 40
    bar_w, bar_h = 110, 5
    bar = Image.new('RGB', (bar_w, bar_h))
    bd = ImageDraw.Draw(bar)
    for x in range(bar_w):
        t = x / (bar_w - 1)
        bd.line([(x, 0), (x, bar_h)],
                fill=tuple(int(ACCENT_A[i] + (ACCENT_B[i] - ACCENT_A[i]) * t)
                           for i in range(3)))
    canvas.paste(bar, (cx - bar_w // 2, y))

    y += bar_h + 34
    f = font(30, 400)
    line = TAGLINE_ONE
    bb = f.getbbox(line)
    d.text((cx - d.textlength(line, font=f) / 2, y - bb[1]), line, font=f, fill=MUTED)

    out = canvas.convert('RGB')
    out.save(OUT + '/feature-graphic-1024x500-no-device.png')
    return out.size


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    print('icon-512.png                  %s' % (play_icon(),))
    print('feature-graphic-1024x500.png  %s' % (feature_graphic(),))
    print('feature-graphic-1024x500-no-device.png  %s' % (feature_graphic_clean(),))
