"""Generate app icon for 记账 (Bookkeeping) app — clean, modern, minimal."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math

SIZE = 1024
CORNER_RADIUS = 220

# Color palette — indigo gradient
BG_TOP = (99, 114, 198)     # Lighter indigo top
BG_BOT = (57, 73, 171)      # Deeper indigo bottom
FG_WHITE = (255, 255, 255)

img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# --- Gradient background ---
for y in range(SIZE):
    t = y / SIZE
    r = int(BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t)
    g = int(BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t)
    b = int(BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t)
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b), width=1)

# Rounded rect mask
mask = Image.new('L', (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle([(0, 0), (SIZE, SIZE)], radius=CORNER_RADIUS, fill=255)
img.putalpha(mask)

# --- Large centered ¥ symbol ---
cx, cy = SIZE // 2, SIZE // 2
draw = ImageDraw.Draw(img)

# ¥ symbol parameters
y_center = cy + 15  # Slightly below true center for visual balance
stroke_w = 42       # Thick strokes for readability at small sizes
y_height = 200      # Total height of the Y part
top_y = y_center - y_height // 2
bot_y = y_center + y_height // 2

# = Horizontal strokes
# Upper horizontal (the short crossbar of ¥)
upper_bar_y = top_y + 65
upper_bar_w = 130  # Half-width from center
draw.rectangle(
    [(cx - upper_bar_w, upper_bar_y - stroke_w // 2),
     (cx + upper_bar_w, upper_bar_y + stroke_w // 2)],
    fill=FG_WHITE
)

# Lower horizontal (the long bottom bar of ¥)
lower_bar_y = bot_y - 45
lower_bar_w = 165
draw.rectangle(
    [(cx - lower_bar_w, lower_bar_y - stroke_w // 2),
     (cx + lower_bar_w, lower_bar_y + stroke_w // 2)],
    fill=FG_WHITE
)

# = Vertical stroke
draw.rectangle(
    [(cx - stroke_w // 2, top_y + 20),
     (cx + stroke_w // 2, bot_y - 20)],
    fill=FG_WHITE
)

# = Diagonal strokes (left \ and right /, like the bottom of Y)
# These are the two short descending strokes from the center
diag_y_top = bot_y - 20
diag_y_bot = bot_y + 70
diag_offset_x = 100

# Left diagonal
draw.polygon([
    (cx - stroke_w // 2, diag_y_top),
    (cx + stroke_w // 2, diag_y_top),
    (cx - diag_offset_x + stroke_w // 2, diag_y_bot),
    (cx - diag_offset_x - stroke_w // 2, diag_y_bot),
], fill=FG_WHITE)

# Right diagonal
draw.polygon([
    (cx - stroke_w // 2, diag_y_top),
    (cx + stroke_w // 2, diag_y_top),
    (cx + diag_offset_x + stroke_w // 2, diag_y_bot),
    (cx + diag_offset_x - stroke_w // 2, diag_y_bot),
], fill=FG_WHITE)

# --- Ledger/accounting lines behind the ¥ (subtle background detail) ---
# Thin horizontal lines suggesting a ledger page — drawn at reduced opacity
# We'll draw them as solid but thin white lines
ledger_alpha = 60  # Subtle
ledger_color = (255, 255, 255, ledger_alpha)

# Create a separate layer for ledger lines behind ¥
ledger_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
ledger_draw = ImageDraw.Draw(ledger_layer)

ledger_left = cx - 280
ledger_right = cx + 280
ledger_y_start = top_y - 30
ledger_spacing = 35
for i in range(14):
    ly = ledger_y_start + i * ledger_spacing
    if i % 4 == 0:
        # Accent line (slightly thicker / brighter)
        ledger_draw.line([(ledger_left, ly), (ledger_right, ly)], fill=(255, 255, 255, 100), width=3)
    else:
        ledger_draw.line([(ledger_left, ly), (ledger_right, ly)], fill=(255, 255, 255, 55), width=1)

# Composite ledger behind the ¥
img = Image.alpha_composite(img, ledger_layer)
draw = ImageDraw.Draw(img)

# --- ¥ redraw on top to ensure it's crisp over the ledger lines ---
# (Repeating the ¥ drawing code — this is important so ¥ stays crisp and fully opaque)
# Upper horizontal
draw.rectangle(
    [(cx - upper_bar_w, upper_bar_y - stroke_w // 2),
     (cx + upper_bar_w, upper_bar_y + stroke_w // 2)],
    fill=FG_WHITE
)
# Lower horizontal
draw.rectangle(
    [(cx - lower_bar_w, lower_bar_y - stroke_w // 2),
     (cx + lower_bar_w, lower_bar_y + stroke_w // 2)],
    fill=FG_WHITE
)
# Vertical
draw.rectangle(
    [(cx - stroke_w // 2, top_y + 20),
     (cx + stroke_w // 2, bot_y - 20)],
    fill=FG_WHITE
)
# Left diagonal
draw.polygon([
    (cx - stroke_w // 2, diag_y_top),
    (cx + stroke_w // 2, diag_y_top),
    (cx - diag_offset_x + stroke_w // 2, diag_y_bot),
    (cx - diag_offset_x - stroke_w // 2, diag_y_bot),
], fill=FG_WHITE)
# Right diagonal
draw.polygon([
    (cx - stroke_w // 2, diag_y_top),
    (cx + stroke_w // 2, diag_y_top),
    (cx + diag_offset_x + stroke_w // 2, diag_y_bot),
    (cx + diag_offset_x - stroke_w // 2, diag_y_bot),
], fill=FG_WHITE)

# --- Small accent: a tiny rising arrow near top right of ¥ ---
# Subtle upward trend indicator
arrow_x = cx + 230
arrow_y = upper_bar_y - 80
arrow_size = 35
# Upward arrow (triangle)
draw.polygon([
    (arrow_x, arrow_y - arrow_size),
    (arrow_x - arrow_size * 0.7, arrow_y + arrow_size * 0.5),
    (arrow_x + arrow_size * 0.7, arrow_y + arrow_size * 0.5),
], fill=(180, 200, 255))

# Save
img.save('assets/icon/app_icon_source.png')
print(f"Icon saved: assets/icon/app_icon_source.png ({SIZE}x{SIZE})")
print("Design: Large CNY symbol on indigo gradient with subtle ledger lines")
