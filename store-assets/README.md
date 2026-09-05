# Store screenshots

Generated from the device captures in `../live-assets/` — four phone captures
(1080 × 2400 portrait) and four tablet captures (2560 × 1600 landscape) of the
same four screens.

## Sets

| Folder | Size (px) | Built from | For |
|---|---|---|---|
| `android-phone/` | 1080 × 1920 | phone captures | Google Play — phone |
| `ios-6.5/` | 1242 × 2688 | phone captures | App Store — 6.5" iPhone |
| `android-tablet/` | 2560 × 1600 | tablet captures | Google Play — 7" and 10" tablet |
| `ipad-13/` | 2732 × 2048 | tablet captures | App Store — 13" iPad |

The tablet sets are **landscape** because the app's tablet layout is landscape —
a left nav rail with a wide content column. On a portrait canvas that capture
would sit as a thin strip in the middle of the page; landscape lets it fill the
frame. Both stores accept landscape screenshots at these sizes.

Four images per set, in listing order:

1. `01` Dashboard — *Your whole fleet, at a glance*
2. `02` Assets — *Find any asset in seconds*
3. `03` Asset details — *Every device, fully documented*
4. `04` Maintenance — *Maintenance that stays on track*

## What was changed in the captures

`clean/` holds the retouched frames; the store sets are built from those.

**Status bar** — repainted on every frame, phone and tablet: clock set to 10:10,
Wi-Fi, signal and battery drawn full, the phone's camera cut-out kept where the
device has it. The system recording dot was dropped.

The strip is rebuilt by tiling one clean background row from just below it, not
by flooding a rectangle with a single colour. That matters on the tablet, where
the ground behind the bar is two colours — the nav rail to x=160, the page
beyond it — and a flat fill put the seam 40px too far right, leaving a block of
rail colour hanging in the page.

On the tablet the bar also sits 14px lower than the capture had it, so it is
clear of the store frame's rounded corners rather than jammed against the top
edge, and the clock is pulled in from the left for the same reason. Clock and
icons share a centre line. The strip is only repainted down to row 55 — the
rail's first nav button starts at 64 and the header actions at 58.

**Asset list (`02`, both sets)** — the demo database had warranties in a bad
state, which put red and amber badges through the list. Replaced with the green
*Warranty valid* badge lifted from the same screenshot, so the type, spacing and
colour are the app's own:

- ThinkPad L15 Gen 3 — *Expired 50 days ago* → *Warranty valid*
- HP LaserJet Pro M404dn — *Expired 22 days ago* → *Warranty valid*
- Logitech Brio 4K — *Expires in 4 days* → *Warranty valid*
- Dell OptiPlex 7010 Micro — amber maintenance icon tile swapped for the blue
  laptop tile, and the half-drawn badge row at the fold cleared. On the tablet
  the system home indicator is redrawn on top afterwards, since it sits in that
  same strip.

**Left as they are** — the two amber tiles on the dashboard (*8 Warranty ends
&lt;30 days*, *3 Open maintenance*) and the *New Request* chip on the
maintenance screen. These are the product doing its job, not failures; zeroing
them would make the app look empty.

## Play listing page

`play/` holds the other two graphics the store listing page asks for, and
`LISTING.md` the text for it.

| File | Size | Field |
|---|---|---|
| `play/icon-512.png` | 512 × 512 | رمز التطبيق |
| `play/feature-graphic-1024x500.png` | 1024 × 500 | رسم مميز |
| `play/feature-graphic-1024x500-no-device.png` | 1024 × 500 | رسم مميز — alternative |

The icon is `assets/icon/app-icon.png` resized: square, full-bleed and opaque,
because Play applies its own rounded mask and an alpha channel or pre-rounded
corners would show as a dark halo inside it.

Two feature graphics because Google's guidance for apps in the running for
editorial featuring is to keep screenshots and device frames out of that slot.
The default one carries the dashboard on a phone; `-no-device` is brand and
tagline only. Either is fine for an ordinary listing.

`LISTING.md` has the app name, short description and full description in English
and Arabic, all inside Play's 30 / 80 / 4000 character limits. It contains three
`<PRIVACY_URL>` placeholders — replace them with the public address the privacy
policy is hosted at before pasting.

## Rebuilding

    python tool/store/clean_shots.py     # live-assets/ -> store-assets/clean/
    python tool/store/store_frames.py    # clean/       -> the four store sets
    PYTHONPATH=tool/store python tool/store/play_graphics.py   # -> play/

Captions live in `SHOTS` at the top of `store_frames.py`; canvas sizes in
`TARGETS` just above it. `clean_shots.py` picks a profile by the capture's pixel
size, so a new device size needs an entry in `PROFILES`.
