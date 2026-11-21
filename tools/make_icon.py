# Generates the ALMULZIM launcher icon (Midnight Intelligence): night background, glowing padlock.
# Usage: python3 tools/make_icon.py   (writes into android_overlay/app/src/main/res)
from PIL import Image, ImageDraw, ImageFilter
import os

RES = os.path.join(os.path.dirname(__file__), '..', 'android_overlay', 'app', 'src', 'main', 'res')
BG, SURF, PRIMARY, CYAN = (11, 16, 32), (29, 41, 67), (101, 124, 255), (66, 217, 232)
S = 1024  # master canvas (adaptive layer: 108dp, safe zone = central 66%)


def lock_layer():
    """Transparent 1024px layer with the padlock inside the adaptive safe zone."""
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = S // 2
    # shackle (cyan arc)
    w = 64
    d.arc([cx - 150, 250, cx + 150, 560], 180, 360, fill=CYAN + (255,), width=w)
    d.rectangle([cx - 150, 400, cx - 150 + w, 520], fill=CYAN + (255,))
    d.rectangle([cx + 150 - w, 400, cx + 150, 520], fill=CYAN + (255,))
    # body (primary blue)
    d.rounded_rectangle([cx - 215, 480, cx + 215, 790], radius=64, fill=PRIMARY + (255,))
    # keyhole
    d.ellipse([cx - 45, 575, cx + 45, 665], fill=BG + (255,))
    d.rounded_rectangle([cx - 20, 640, cx + 20, 735], radius=14, fill=BG + (255,))
    # soft glow behind
    glow = im.filter(ImageFilter.GaussianBlur(28))
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(im)
    return out


def background():
    im = Image.new('RGB', (S, S), BG)
    glow = Image.new('RGB', (S, S), SURF)
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).ellipse([S * 0.12, S * 0.1, S * 0.88, S * 0.86], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(160))
    im.paste(glow, (0, 0), mask)
    return im


def save(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)


fg = lock_layer()
bg = background()

# legacy launcher PNGs (rounded square)
full = bg.convert('RGBA')
full.alpha_composite(fg)
mask = Image.new('L', (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S, S], radius=int(S * 0.22), fill=255)
full.putalpha(mask)
for name, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
    save(full, f'{RES}/mipmap-{name}/ic_launcher.png', px)

# adaptive icon (Android 8+): solid background colour + foreground layer
save(fg, f'{RES}/drawable-xxxhdpi/ic_launcher_foreground.png', 432)
os.makedirs(f'{RES}/mipmap-anydpi-v26', exist_ok=True)
open(f'{RES}/mipmap-anydpi-v26/ic_launcher.xml', 'w').write(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n')
open(f'{RES}/values/ic_launcher_background.xml', 'w').write(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    '    <color name="ic_launcher_background">#0B1020</color>\n</resources>\n')

# preview for humans
prev = Image.new('RGB', (1024, 1024), BG)
prev.paste(full.resize((1024, 1024)), (0, 0), full.resize((1024, 1024)))
os.makedirs('/mnt/user-data/outputs', exist_ok=True)
prev.resize((512, 512)).save('/mnt/user-data/outputs/almulzim-icon-preview.png')
print('ok')
