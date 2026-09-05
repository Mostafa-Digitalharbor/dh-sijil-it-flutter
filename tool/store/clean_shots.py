# -*- coding: utf-8 -*-
"""Prepare the raw device captures for the store.

Two things happen here. The status bar is repainted so every frame reads 10:10
with Wi-Fi, signal and battery full, and the asset list's red "expired" badges
are swapped for the green "Warranty valid" badge cut from the same screenshot --
so the type, spacing and colour stay the app's own rather than something drawn
on top of it.

Phone and tablet captures have completely different chrome, so each is described
by a profile keyed on the capture's pixel size.
"""
import glob
import os
from PIL import Image, ImageDraw, ImageFont
import numpy as np

SRC = 'live-assets'
OUT = 'store-assets/clean'
ARCHIVO = 'assets/fonts/Archivo-Variable.ttf'

CARD_BG = (16, 26, 56)
PILL_OK = (20, 50, 69)                      # green pill background
PILL_BAD = [(45, 36, 59), (45, 45, 57)]     # red and amber pill backgrounds
WHITE = (255, 255, 255)

PROFILES = {
    # phone, 1080 x 2400 portrait
    (1080, 2400): dict(
        bar=dict(boxes=[(0, 1080)], height=115, src_row=120),
        punch=(539.5, 67.5, 34),
        clock=dict(x=47, top=54, cap=30),
        icons=dict(style='phone', right=1035, y0=51, y1=84),
        pill_x=(440, 980), pill_h=(45, 62), pill_w=(120, 520), pill_y=(600, 2000),
        tile_x=(73, 174), tile_y=(600, 2149),
        fold=(60, 2118, 1020, 2149),
        gesture=None,
    ),
    # tablet, 2560 x 1600 landscape
    (2560, 1600): dict(
        # Only the two side boxes are repainted, and only down to row 55 --
        # the rail's nav button starts at 64 and the header actions at 58.
        bar=dict(boxes=[(0, 211), (2330, 2560)], height=56, src_row=56),
        punch=None,
        # x is pulled in from the capture's own 9px: the store frame rounds the
        # device corners, and at this height the arc would eat the first digit.
        # y is 14px lower than the capture's, which sat hard against the edge.
        clock=dict(x=62, top=27, cap=21),
        icons=dict(style='tablet', right=2511, y0=25, y1=50),
        pill_x=(1000, 1450), pill_h=(32, 50), pill_w=(100, 400), pill_y=(400, 1500),
        tile_x=(729, 808), tile_y=(400, 1599),
        fold=(820, 1558, 2012, 1599),
        # the system home indicator sits on top of the list and has to go back
        gesture=(1060, 1564, 1499, 1571),
    ),
}


def archivo(size, weight=500):
    f = ImageFont.truetype(ARCHIVO, int(size))
    f.set_variation_by_axes([weight, 100])
    return f


def fit_cap(text, target_cap, weight=500):
    lo, hi = 8, 140
    while lo < hi:
        mid = (lo + hi + 1) // 2
        bb = archivo(mid, weight).getbbox(text)
        if (bb[3] - bb[1]) <= target_cap:
            lo = mid
        else:
            hi = mid - 1
    return lo


# -- status bar -----------------------------------------------------------
def draw_icons(d, spec):
    """Wi-Fi, signal and battery, all at full."""
    y0, y1, right = spec['y0'], spec['y1'], spec['right']
    h = y1 - y0

    if spec['style'] == 'phone':
        bx1, bx0 = right, right - 21
        d.rectangle([(bx0 + bx1) // 2 - 5, y0, (bx0 + bx1) // 2 + 5, y0 + 6], fill=WHITE)
        d.rounded_rectangle([bx0, y0 + 5, bx1, y1], radius=5, fill=WHITE)
        sx1 = bx0 - 14
        sx0 = sx1 - 34
        d.polygon([(sx0, y1), (sx1, y1), (sx1, y0)], fill=WHITE)
        wx1 = sx0 - 8
        wx0 = wx1 - 34
    else:
        # battery reads as a horizontal pill with a nub on the cap end
        bx1, bx0 = right, right - 52
        d.rounded_rectangle([bx0, y0, bx1 - 7, y1], radius=h // 3, fill=WHITE)
        d.rounded_rectangle([bx1 - 9, y0 + h // 3, bx1, y1 - h // 3], radius=2, fill=WHITE)
        wx1 = bx0 - 13
        wx0 = wx1 - 31
        # four ascending bars, every one of them lit
        bar_w, gap = 5, 10
        for i in range(4):
            x = wx0 - 13 - (3 - i) * gap - bar_w
            d.rounded_rectangle([x, y1 - h * (0.38 + 0.21 * i), x + bar_w, y1],
                                radius=1, fill=WHITE)

    wcx, wcy = (wx0 + wx1) / 2, y1
    wr = (wx1 - wx0) / 2 * 1.42
    d.pieslice([wcx - wr, wcy - wr, wcx + wr, wcy + wr], 226, 314, fill=WHITE)


def redraw_status_bar(im, prof):
    """Clear the strip the system drew its bar in, then draw ours.

    The strip is rebuilt by tiling one clean background row from just below it,
    not by flooding a rectangle with a single sampled colour. On the tablet the
    background behind the bar is two colours -- the nav rail to x=160, the page
    beyond it -- and a flat fill puts that seam in the wrong place, which shows
    as a block of rail colour hanging in the page.
    """
    a = np.array(im)
    d = ImageDraw.Draw(im)
    bar = prof['bar']
    src = a[bar['src_row'], :, :3]
    for x0, x1 in bar['boxes']:
        w = x1 - x0
        strip = np.tile(src[x0:x1], (bar['height'], 1)).reshape(bar['height'], w, 3)
        im.paste(Image.fromarray(strip.astype('uint8')), (x0, 0))

    if prof['punch']:
        cx, cy, r = prof['punch']
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0))

    c = prof['clock']
    f = archivo(fit_cap('10:10', c['cap']), 500)
    bb = f.getbbox('10:10')
    d.text((c['x'] - bb[0], c['top'] - bb[1]), '10:10', font=f, fill=WHITE)
    draw_icons(d, prof['icons'])
    return im


# -- status badges --------------------------------------------------------
def find_pills(a, bg, prof):
    """Pills only: the right-hand badge column, at badge height and width. That
    box is what keeps the search off the icon tiles, which carry the same tint
    when an asset is available or in maintenance."""
    m = (np.abs(a[:, :, :3].astype(int) - np.array(bg)).sum(axis=2) <= 6)
    m[:prof['pill_y'][0]] = False
    m[prof['pill_y'][1]:] = False
    m[:, :prof['pill_x'][0]] = False
    m[:, prof['pill_x'][1]:] = False
    ys = np.where(m.any(axis=1))[0]
    if not len(ys):
        return []
    groups, start, prev = [], ys[0], ys[0]
    for y in ys[1:]:
        if y - prev > 8:
            groups.append((start, prev))
            start = y
        prev = y
    groups.append((start, prev))
    out = []
    for y0, y1 in groups:
        if not (prof['pill_h'][0] <= y1 - y0 <= prof['pill_h'][1]):
            continue
        xs = np.where(m[y0:y1 + 1].any(axis=0))[0]
        if not (prof['pill_w'][0] <= xs.max() - xs.min() <= prof['pill_w'][1]):
            continue
        out.append((int(xs.min()), int(y0), int(xs.max()), int(y1)))
    return out


def positive_badges(im, prof):
    a = np.array(im)
    good = find_pills(a, PILL_OK, prof)
    bad = [b for c in PILL_BAD for b in find_pills(a, c, prof)]
    if not good or not bad:
        return im, 0
    gx0, gy0, gx1, gy1 = good[0]
    sprite = im.crop((gx0, gy0, gx1 + 1, gy1 + 1))
    d = ImageDraw.Draw(im)
    for x0, y0, x1, y1 in bad:
        d.rectangle([x0 - 3, y0 - 3, x1 + 3, y1 + 3], fill=CARD_BG)
        im.paste(sprite, (x0, y0))
    d.rectangle(list(prof['fold']), fill=CARD_BG)   # the half-drawn row at the fold
    if prof.get('gesture'):
        d.rounded_rectangle(list(prof['gesture']), radius=4, fill=(237, 238, 241))
    return im, len(bad) + 1


# -- icon tiles -----------------------------------------------------------
def cool_icon_tiles(im, prof):
    """The list tints an asset's icon tile amber while it is in maintenance. One
    warm tile in an otherwise green list is the first thing the eye lands on."""
    a = np.array(im).astype(int)
    x0, x1 = prof['tile_x']
    m = (np.abs(a[:, :, :3] - np.array(CARD_BG)).sum(axis=2) > 18)
    m[:prof['tile_y'][0]] = False
    m[prof['tile_y'][1]:] = False
    m[:, :x0] = False
    m[:, x1 + 1:] = False
    ys = np.where(m.any(axis=1))[0]
    if not len(ys):
        return im, 0
    groups, start, prev = [], ys[0], ys[0]
    for y in ys[1:]:
        if y - prev > 10:
            groups.append((start, prev))
            start = y
        prev = y
    groups.append((start, prev))
    warm, cool = [], []
    for y0, y1 in groups:
        if not (60 <= y1 - y0 <= 115):
            continue
        patch = a[y0:y1 + 1, x0:x1 + 1]
        # the tint lives in the glyph, not the tile fill, so count warm pixels
        # rather than averaging -- an average is dominated by the dark ground
        hot = int(((patch[..., 0] - patch[..., 2]) > 40).sum())
        (warm if hot > 150 else cool).append((y0, y1))
    if not warm or not cool:
        return im, 0
    cy0 = cool[0][0]
    for y0, y1 in warm:
        im.paste(im.crop((x0, cy0, x1 + 1, cy0 + y1 - y0 + 1)), (x0, y0))
    return im, len(warm)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for f in sorted(glob.glob(SRC + '/*.png')):
        name = os.path.basename(f)
        im = Image.open(f).convert('RGB')
        prof = PROFILES.get(im.size)
        if prof is None:
            print(name + ': no profile for ' + str(im.size) + ' -- skipped')
            continue
        im = redraw_status_bar(im, prof)
        im, n = positive_badges(im, prof)
        im, t = cool_icon_tiles(im, prof)
        im.save(OUT + '/' + name)
        print('%-34s %s  status bar redrawn, %d badge(s) fixed, %d tile(s) cooled'
              % (name, im.size, n, t))
