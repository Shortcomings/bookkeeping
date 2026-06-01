"""Generate icon preview composite image with phone mockup."""
from PIL import Image, ImageDraw, ImageFont
import os

# Find Chinese font
font_path = None
for fp in ['C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simsun.ttc', 'C:/Windows/Fonts/simhei.ttf']:
    if os.path.exists(fp):
        font_path = fp
        break

font_sm = ImageFont.truetype(font_path, 13)
font_md = ImageFont.truetype(font_path, 16)
font_lg = ImageFont.truetype(font_path, 22)
font_title = ImageFont.truetype(font_path, 28)

img_src = Image.open('assets/icon/app_icon_source.png')
fg_src = Image.open('assets/icon/ic_foreground.png')

W, H = 1300, 950
canvas = Image.new('RGBA', (W, H), (242, 242, 248, 255))
draw = ImageDraw.Draw(canvas)

# Title bar
draw.rectangle([(0, 0), (W, 60)], fill=(92, 107, 192))
draw.text((30, 14), 'App Icon Preview - Bookkeeping', fill=(255, 255, 255), font=font_title)

y = 80

# === Row 1: Source icon large ===
draw.text((30, y), 'Source (1024x1024)', fill=(80, 80, 100), font=font_md)
thumb = img_src.resize((180, 180), Image.LANCZOS)
canvas.paste(thumb, (30, y + 25), thumb)

# === Row 1 right: All density sizes ===
draw.text((240, y), 'Android Mipmap Densities', fill=(80, 80, 100), font=font_md)
densities = [
    ('mdpi', 48),
    ('hdpi', 72),
    ('xhdpi', 96),
    ('xxhdpi', 144),
    ('xxxhdpi', 192),
]
x = 240
for name, size in densities:
    card = Image.new('RGBA', (130, 200), (255, 255, 255, 255))
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle([(2, 2), (127, 197)], radius=10, fill=(255, 255, 255), outline=(220, 220, 230), width=1)
    icon_sized = img_src.resize((size, size), Image.LANCZOS)
    ox = (130 - size) // 2
    oy = (170 - size) // 2
    card.paste(icon_sized, (ox, oy), icon_sized)
    card_draw.text((10, 8), name, fill=(100, 100, 120), font=font_sm)
    card_draw.text((10, 175), f'{size}x{size}', fill=(150, 150, 160), font=font_sm)
    canvas.paste(card, (x, y + 25), card)
    x += 145

y += 260

# === Row 2: Simulated Phone Home Screen ===
draw.text((30, y), 'Simulated Home Screen', fill=(80, 80, 100), font=font_md)

phone_w, phone_h = 360, 640
phone = Image.new('RGBA', (phone_w, phone_h), (0, 0, 0, 0))
phone_draw = ImageDraw.Draw(phone)
phone_draw.rounded_rectangle([(0, 0), (phone_w-1, phone_h-1)], radius=36, fill=(20, 20, 32))
phone_draw.text((20, 22), '10:42', fill=(210, 210, 220), font=font_sm)
phone_draw.text((phone_w - 70, 22), '85%', fill=(210, 210, 220), font=font_sm)

# Wallpaper
for wy in range(80, phone_h):
    t = (wy - 80) / (phone_h - 80)
    r = int(20 + 15 * t)
    g = int(20 + 12 * t)
    b = int(32 + 25 * t)
    phone_draw.line([(10, wy), (phone_w-10, wy)], fill=(r, g, b))

app_grid_y = 300
app_spacing_x = 78
app_spacing_y = 90
app_icon_size = 60
app_colors = [(70, 130, 210), (220, 80, 70), (80, 180, 110), (240, 150, 30)]
app_names = ['Photos', 'Settings', 'Camera', 'Calendar', 'Clock']

our_icon = img_src.resize((app_icon_size, app_icon_size), Image.LANCZOS)

for idx in range(8):
    col = idx % 4
    row = idx // 4
    ix = 42 + col * app_spacing_x
    iy = app_grid_y + row * app_spacing_y
    if idx == 4:
        phone.paste(our_icon, (ix, iy), our_icon)
        phone_draw.text((ix + 4, iy + app_icon_size + 4), 'Bookkeep', fill=(200, 200, 210), font=font_sm)
    else:
        fake = Image.new('RGBA', (app_icon_size, app_icon_size), app_colors[idx % 4])
        fake_draw = ImageDraw.Draw(fake)
        fake_draw.rounded_rectangle([(0, 0), (app_icon_size-1, app_icon_size-1)], radius=12, fill=app_colors[idx % 4])
        phone.paste(fake, (ix, iy), fake)
        phone_draw.text((ix + 6, iy + app_icon_size + 4), app_names[min(idx, 4)], fill=(180, 180, 190), font=font_sm)

# Dock
phone_draw.rounded_rectangle([(20, phone_h - 120), (phone_w - 20, phone_h - 30)], radius=18, fill=(50, 50, 65, 128))

canvas.paste(phone, (30, y + 25), phone)

# === Right side: Adaptive Icon layers ===
ax = 420
draw.text((ax, y), 'Android Adaptive Icon (API 26+)', fill=(80, 80, 100), font=font_md)

layers_y = y + 35

# Background
bg_card = Image.new('RGBA', (140, 190), (255, 255, 255, 255))
bg_card_draw = ImageDraw.Draw(bg_card)
bg_card_draw.rounded_rectangle([(2, 2), (137, 187)], radius=10, fill=(255, 255, 255), outline=(220, 220, 230))
bg_color = Image.new('RGBA', (100, 100), (92, 107, 192, 255))
bg_cd2 = ImageDraw.Draw(bg_color)
bg_cd2.rounded_rectangle([(0, 0), (99, 99)], radius=20, fill=(92, 107, 192))
bg_card.paste(bg_color, (20, 50), bg_color)
bg_card_draw.text((25, 15), 'Background', fill=(100, 100, 120), font=font_sm)
bg_card_draw.text((30, 160), '#5C6BC0 solid', fill=(130, 130, 150), font=font_sm)
canvas.paste(bg_card, (ax, layers_y), bg_card)

# Foreground
fg_card = Image.new('RGBA', (140, 190), (255, 255, 255, 255))
fg_card_draw = ImageDraw.Draw(fg_card)
fg_card_draw.rounded_rectangle([(2, 2), (137, 187)], radius=10, fill=(255, 255, 255), outline=(220, 220, 230))
fg_thumb = fg_src.resize((100, 100), Image.LANCZOS)
dark_bg = Image.new('RGBA', (100, 100), (60, 60, 60, 255))
dark_bg.paste(fg_thumb, (0, 0), fg_thumb)
fg_card.paste(dark_bg, (20, 50), dark_bg)
fg_card_draw.text((22, 15), 'Foreground', fill=(100, 100, 120), font=font_sm)
fg_card_draw.text((25, 160), 'Transparent + symbol', fill=(130, 130, 150), font=font_sm)
canvas.paste(fg_card, (ax + 155, layers_y), fg_card)

# Combined
combo_card = Image.new('RGBA', (200, 190), (255, 255, 255, 255))
combo_card_draw = ImageDraw.Draw(combo_card)
combo_card_draw.rounded_rectangle([(2, 2), (197, 187)], radius=10, fill=(255, 255, 255), outline=(100, 180, 100), width=2)
combo = Image.new('RGBA', (100, 100), (92, 107, 192, 255))
combo_cd = ImageDraw.Draw(combo)
combo_cd.rounded_rectangle([(0, 0), (99, 99)], radius=20, fill=(92, 107, 192))
combo.paste(fg_thumb, (0, 0), fg_thumb)
combo_card.paste(combo, (50, 50), combo)
combo_card_draw.text((45, 15), 'Combined', fill=(60, 130, 60), font=font_md)
combo_card_draw.text((48, 165), 'Final launcher icon', fill=(130, 150, 130), font=font_sm)
canvas.paste(combo_card, (ax + 310, layers_y), combo_card)

# === Bottom: Light/Dark mode ===
y2 = y + phone_h + 50
draw.text((30, y2), 'Light / Dark Mode', fill=(80, 80, 100), font=font_md)

# Light mode
light_card = Image.new('RGBA', (200, 180), (255, 255, 255, 255))
light_draw = ImageDraw.Draw(light_card)
light_draw.rounded_rectangle([(2, 2), (197, 177)], radius=12, fill=(255, 255, 255), outline=(220, 220, 230))
light_icon = img_src.resize((96, 96), Image.LANCZOS)
light_card.paste(light_icon, (52, 50), light_icon)
light_draw.text((60, 15), 'Light', fill=(100, 100, 120), font=font_md)
canvas.paste(light_card, (30, y2 + 25), light_card)

# Dark mode
dark_card = Image.new('RGBA', (200, 180), (40, 40, 50, 255))
dark_draw = ImageDraw.Draw(dark_card)
dark_draw.rounded_rectangle([(2, 2), (197, 177)], radius=12, fill=(40, 40, 50), outline=(80, 80, 90))
dark_icon = img_src.resize((96, 96), Image.LANCZOS)
dark_card.paste(dark_icon, (52, 50), dark_icon)
dark_draw.text((55, 15), 'Dark', fill=(200, 200, 210), font=font_md)
canvas.paste(dark_card, (250, y2 + 25), dark_card)

# Save as JPG (better compatibility)
canvas = canvas.convert('RGB')
canvas.save('assets/icon/preview.jpg', quality=92)
print(f'Preview saved: assets/icon/preview.jpg ({W}x{H})')
