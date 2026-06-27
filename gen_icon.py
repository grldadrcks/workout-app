from PIL import Image, ImageDraw

SIZE = 1024
cx = cy = SIZE // 2

img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background
BG = (220, 80, 20)
RADIUS = int(SIZE * 0.22)
draw.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=RADIUS, fill=BG)

W = (255, 255, 255)

# ── Barbell — fully symmetric, built from centre outward ──────────────────
PLATE_W  = 80    # width of each plate
PLATE_H  = 320   # height of each plate
PLATE_R  = 16

COLLAR_W = 48    # width of each collar
COLLAR_H = 210
COLLAR_R = 10

BAR_H    = 60    # bar thickness
BAR_R    = BAR_H // 2

# Half-widths from centre
HALF_BAR    = 240   # bar extends 240px each side of centre
HALF_COLLAR = HALF_BAR + COLLAR_W        # 288
HALF_PLATE  = HALF_COLLAR + PLATE_W      # 368

def rect(x1, y1, x2, y2, r):
    draw.rounded_rectangle([x1, y1, x2, y2], radius=r, fill=W)

# Bar
rect(cx - HALF_BAR, cy - BAR_H // 2,
     cx + HALF_BAR, cy + BAR_H // 2, BAR_R)

# Left collar
rect(cx - HALF_COLLAR, cy - COLLAR_H // 2,
     cx - HALF_BAR,    cy + COLLAR_H // 2, COLLAR_R)

# Right collar
rect(cx + HALF_BAR,    cy - COLLAR_H // 2,
     cx + HALF_COLLAR, cy + COLLAR_H // 2, COLLAR_R)

# Left plate
rect(cx - HALF_PLATE, cy - PLATE_H // 2,
     cx - HALF_COLLAR, cy + PLATE_H // 2, PLATE_R)

# Right plate
rect(cx + HALF_COLLAR, cy - PLATE_H // 2,
     cx + HALF_PLATE,  cy + PLATE_H // 2, PLATE_R)

img.save('assets/icons/icon.png')
print("Saved assets/icons/icon.png")
