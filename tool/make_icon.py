# Generates the Spiti Setu app icon: a 3D bold "S" that doubles as a
# suspension bridge (Setu), on a Spiti indigo->teal gradient with snow peaks.
# Full-bleed (no border). Output: assets/icon/app_icon.png (1024x1024)
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W = 1024
FONT = "C:/Windows/Fonts/ariblk.ttf"  # Arial Black — chunky S

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# ---- base layer with vertical gradient (deep indigo sky -> teal) ----
img = Image.new("RGBA", (W, W), (0, 0, 0, 255))
d = ImageDraw.Draw(img)
top = (49, 46, 129)    # deep indigo
mid = (37, 99, 175)    # blue
bot = (13, 148, 136)   # teal
for y in range(W):
    t = y / W
    if t < 0.5:
        c = lerp(top, mid, t / 0.5)
    else:
        c = lerp(mid, bot, (t - 0.5) / 0.5)
    d.line([(0, y), (W, y)], fill=(c[0], c[1], c[2], 255))

# ---- soft glow top-left ----
glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([-260, -320, 560, 420], fill=(255, 255, 255, 60))
glow = glow.filter(ImageFilter.GaussianBlur(120))
img = Image.alpha_composite(img, glow)
d = ImageDraw.Draw(img)

# ---- snow mountain ranges at the bottom ----
far = [(0, W), (0, 760), (170, 600), (330, 720), (520, 560),
       (700, 710), (870, 600), (W, 700), (W, W)]
d.polygon(far, fill=(255, 255, 255, 45))
near = [(0, W), (0, 840), (240, 680), (470, 820), (690, 660),
        (900, 800), (W, 720), (W, W)]
d.polygon(near, fill=(255, 255, 255, 80))
# snow caps on the near range peaks
for (px, py) in [(240, 680), (690, 660)]:
    d.polygon([(px - 46, py + 70), (px, py), (px + 46, py + 70),
               (px + 16, py + 52), (px, py + 64), (px - 16, py + 52)],
              fill=(255, 255, 255, 150))

# ---- the hero "S" (3D extruded) ----
font = ImageFont.truetype(FONT, 760)
text = "S"
bbox = d.textbbox((0, 0), text, font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
cx = (W - tw) // 2 - bbox[0]
cy = (W - th) // 2 - bbox[1] - 28

# extrusion (dark teal copies, offset down-right)
depth = 26
for i in range(depth, 0, -1):
    sh = lerp((6, 78, 59), (4, 47, 46), i / depth)
    d.text((cx + i * 0.9, cy + i * 0.9), text, font=font, fill=(sh[0], sh[1], sh[2], 255))

# front face: white -> light-cyan vertical gradient via mask
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).text((cx, cy), text, font=font, fill=255)
face = Image.new("RGBA", (W, W), (0, 0, 0, 0))
fd = ImageDraw.Draw(face)
c1, c2 = (255, 255, 255), (178, 245, 250)
for y in range(W):
    c = lerp(c1, c2, y / W)
    fd.line([(0, y), (W, y)], fill=(c[0], c[1], c[2], 255))
img.paste(face, (0, 0), mask)

# subtle top highlight on the S
hi = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(hi).text((cx - 4, cy - 4), text, font=font, fill=(255, 255, 255, 90))
hmask = Image.new("L", (W, W), 0)
ImageDraw.Draw(hmask).text((cx - 4, cy - 4), text, font=font, fill=255)
# keep highlight only on upper third
band = Image.new("L", (W, W), 0)
ImageDraw.Draw(band).rectangle([0, 0, W, int(W * 0.42)], fill=255)
from PIL import ImageChops
hmask = ImageChops.multiply(hmask, band)
img.paste(hi, (0, 0), hmask)

# ---- suspension-bridge hint across the S (amber Setu deck + cables) ----
amber = (245, 158, 11, 255)
deck_y = W // 2 + 18
lx, rx = int(W * 0.2), int(W * 0.8)
# towers (pillars)
for tx in (lx, rx):
    d.line([(tx, deck_y - 150), (tx, deck_y + 70)], fill=amber, width=14)
    d.ellipse([tx - 12, deck_y - 166, tx + 12, deck_y - 142], fill=amber)
# deck road
d.line([(lx - 40, deck_y), (rx + 40, deck_y)], fill=amber, width=16)
# suspension cables (catenary-ish via short segments)
import math
def cable(x0, x1, top_y, sag):
    pts = []
    for k in range(0, 21):
        t = k / 20
        x = x0 + (x1 - x0) * t
        y = top_y + sag * math.sin(math.pi * t)
        pts.append((x, y))
    d.line(pts, fill=amber, width=7)
cable(lx, rx, deck_y - 150, 120)        # main cable between towers
cable(lx - 40, lx, deck_y - 150, -30)   # left back-stay
cable(rx, rx + 40, deck_y - 150, -30)   # right back-stay

# ---- round the very corners just a touch (launcher rounds anyway) ----
img.save("assets/icon/app_icon.png")
print("saved assets/icon/app_icon.png", img.size)
