#!/usr/bin/env python3
"""Иконки предметов STALKER Crafting (192x128 PNG, прозрачный фон) в стиле иконок STALKER Zone.

Рисование — класс Icon из tools/gen_icons.py (тот же размер, суперсэмплинг и тень).
Запуск из корня репозитория:  python3 tools/gen_icons_crafting.py
Результат: stalker_crafting/materials/stalker_craft/items/<id>.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_icons  # noqa: E402
from gen_icons import DARK, METAL, OUT_LINE, WOOD, Icon, shade  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "stalker_crafting", "materials", "stalker_craft", "items")
K = gen_icons.K
MEAT = (150, 72, 52, 255)
CRUST = (120, 66, 36, 255)
FAT = (226, 196, 160, 255)


# --- Инструменты и наборы ---------------------------------------------------------
def toolkit():
    """Потёртый кейс с ключом и отвёрткой."""
    i = Icon()
    i.rect(76, 20, 116, 34, None, 4, DARK, 4)
    i.rect(30, 32, 162, 108, (96, 92, 70, 255), 6, OUT_LINE)
    i.rect(30, 32, 162, 46, shade((96, 92, 70, 255), .8), 6, OUT_LINE)
    for x in (44, 148):
        i.rect(x - 4, 40, x + 4, 52, METAL, 2, OUT_LINE)
    # Гаечный ключ.
    i.line([(52, 92), (120, 60)], OUT_LINE, 11)
    i.line([(52, 92), (120, 60)], METAL, 7)
    i.ellipse(114, 50, 136, 72, METAL, OUT_LINE)
    i.ellipse(122, 56, 132, 66, (96, 92, 70, 255))
    # Отвёртка.
    i.line([(84, 98), (150, 80)], OUT_LINE, 6)
    i.line([(84, 98), (150, 80)], (200, 200, 196, 255), 3)
    i.line([(132, 85), (154, 79)], OUT_LINE, 12)
    i.line([(132, 85), (154, 79)], (190, 140, 40, 255), 8)
    return i


def armor_kit():
    """Свёрток кожи, пластина и тюбик клея."""
    i = Icon()
    i.poly([(28, 70), (90, 46), (126, 62), (66, 92)], (124, 92, 60, 255), OUT_LINE)
    i.poly([(28, 70), (66, 92), (66, 104), (28, 82)], shade((124, 92, 60, 255), .75), OUT_LINE)
    i.poly([(66, 92), (126, 62), (126, 74), (66, 104)], shade((124, 92, 60, 255), .6), OUT_LINE)
    for k in range(4):
        i.line([(40 + k * 18, 74 - k * 7), (52 + k * 18, 80 - k * 7)], (90, 64, 40, 255), 2)
    # Бронепластина.
    i.poly([(104, 30), (156, 22), (166, 66), (116, 76)], (110, 118, 112, 255), OUT_LINE)
    i.line([(112, 38), (154, 32)], (160, 168, 160, 255), 2)
    for x, y in ((112, 36), (152, 30), (160, 62), (120, 70)):
        i.ellipse(x - 3, y - 3, x + 3, y + 3, DARK)
    # Клей.
    i.rect(132, 84, 176, 100, (210, 170, 60, 255), 4, OUT_LINE)
    i.rect(118, 88, 134, 96, METAL, 2, OUT_LINE)
    i.text(154, 92, "КЛЕЙ", 6, (60, 44, 20, 255))
    return i


def weapon_kit():
    """Оружейная маслёнка, пружина и шомпол."""
    i = Icon()
    i.rect(34, 86, 160, 110, (70, 82, 60, 255), 4, OUT_LINE)
    i.line([(40, 98), (154, 98)], shade((70, 82, 60, 255), .7), 2)
    # Маслёнка.
    i.rect(48, 40, 84, 88, (160, 140, 60, 255), 6, OUT_LINE)
    i.poly([(58, 40), (74, 40), (70, 22), (62, 22)], METAL, OUT_LINE)
    i.line([(66, 22), (66, 10)], OUT_LINE, 3)
    i.rect(52, 56, 80, 72, (60, 50, 30, 255))
    i.text(66, 64, "МАСЛО", 5, (230, 210, 140, 255))
    # Пружина.
    pts = []
    for k in range(40):
        t = k / 39
        pts.append((96 + t * 60, 60 + math.sin(t * math.pi * 10) * 9))
    i.line(pts, OUT_LINE, 5)
    i.line(pts, (200, 200, 196, 255), 2.5)
    # Шомпол.
    i.line([(92, 34), (170, 26)], OUT_LINE, 6)
    i.line([(92, 34), (170, 26)], METAL, 3)
    i.ellipse(164, 20, 178, 34, None, METAL, 3)
    return i


def campfire_kit():
    """Таблетки сухого горючего, решётка и спички."""
    i = Icon()
    # Складная решётка.
    i.rect(32, 30, 112, 86, None, 3, OUT_LINE, 6)
    i.rect(32, 30, 112, 86, None, 3, METAL, 3)
    for x in range(44, 112, 12):
        i.line([(x, 32), (x, 84)], METAL, 2)
    # Упаковка горючего.
    i.rect(100, 58, 170, 110, (190, 60, 40, 255), 4, OUT_LINE)
    i.rect(106, 70, 164, 90, (240, 220, 190, 255))
    i.text(135, 80, "СУХОЕ", 6, (120, 40, 30, 255))
    i.glow(140, 40, 18, (255, 150, 60, 255), 200)
    i.poly([(140, 22), (150, 40), (144, 52), (136, 52), (130, 40)], (255, 170, 70, 255))
    i.poly([(140, 32), (145, 44), (140, 50), (135, 44)], (255, 230, 150, 255))
    # Спичка.
    i.line([(118, 54), (138, 50)], (220, 200, 150, 255), 3)
    return i


# --- Блюда ------------------------------------------------------------------------
def meat_piece(i, cx, cy, color, crust, scale=1.0, burnt=False):
    r = 1.0 * scale
    pts = [(cx - 40 * r, cy + 4 * r), (cx - 30 * r, cy - 18 * r), (cx + 4 * r, cy - 24 * r), (cx + 36 * r, cy - 12 * r),
           (cx + 42 * r, cy + 10 * r), (cx + 18 * r, cy + 24 * r), (cx - 24 * r, cy + 22 * r)]
    i.poly(pts, crust, OUT_LINE)
    inner = [(x * .78 + cx * .22, y * .72 + cy * .28) for x, y in pts]
    i.poly(inner, color)
    i.line([(cx - 20 * r, cy - 4 * r), (cx + 18 * r, cy - 10 * r)], FAT, 3 * scale)
    if burnt:
        for x, y in ((cx - 18 * r, cy + 10 * r), (cx + 14 * r, cy + 6 * r), (cx + 26 * r, cy - 6 * r)):
            i.ellipse(x - 5 * r, y - 3 * r, x + 5 * r, y + 3 * r, (40, 30, 24, 255))


def meat_fried():
    i = Icon()
    i.ellipse(36, 70, 156, 112, (90, 92, 88, 255), OUT_LINE)
    i.ellipse(44, 74, 148, 104, (130, 132, 126, 255))
    meat_piece(i, 96, 66, MEAT, CRUST, 1.1, True)
    for x in (70, 96, 122):
        i.line([(x, 34), (x - 4, 22), (x + 2, 12)], (200, 196, 186, 120), 3)
    return i


def meat_dubious():
    i = Icon()
    i.glow(96, 64, 46, (140, 220, 80, 255), 150)
    i.ellipse(36, 70, 156, 112, (90, 92, 88, 255), OUT_LINE)
    i.ellipse(44, 74, 148, 104, (120, 124, 112, 255))
    meat_piece(i, 96, 66, (120, 100, 60, 255), (86, 74, 40, 255), 1.1, True)
    for x, y in ((80, 60), (108, 70), (118, 54)):
        i.ellipse(x - 5, y - 5, x + 5, y + 5, (150, 210, 80, 255))
    i.text(150, 28, "☢", 20, (220, 200, 60, 255))
    return i


def shashlik():
    i = Icon()
    i.line([(20, 96), (176, 34)], OUT_LINE, 7)
    i.line([(20, 96), (176, 34)], METAL, 3)
    i.ellipse(170, 26, 184, 40, None, METAL, 3)
    for k, (x, y) in enumerate(((56, 82), (90, 68), (124, 55), (152, 44))):
        c = MEAT if k % 2 == 0 else shade(MEAT, .85)
        i.ellipse(x - 17, y - 15, x + 17, y + 15, CRUST, OUT_LINE)
        i.ellipse(x - 12, y - 10, x + 10, y + 9, c)
        i.ellipse(x - 6, y - 7, x + 1, y - 2, FAT)
    i.line([(72, 76), (76, 72)], (90, 140, 60, 255), 4)
    i.line([(138, 50), (142, 47)], (90, 140, 60, 255), 4)
    return i


def stew():
    i = Icon()
    # Котелок с дужкой.
    i.d.arc([52 * K, 4 * K, 140 * K, 92 * K], start=200, end=340, fill=METAL, width=3 * K)
    i.poly([(46, 46), (146, 46), (138, 104), (54, 104)], (70, 72, 70, 255), OUT_LINE)
    i.ellipse(44, 38, 148, 58, (80, 82, 80, 255), OUT_LINE)
    i.ellipse(52, 41, 140, 55, (150, 100, 52, 255))
    for x, y, c in ((72, 47, MEAT), (98, 50, (210, 170, 100, 255)), (120, 46, MEAT), (86, 44, (120, 160, 70, 255))):
        i.ellipse(x - 7, y - 4, x + 7, y + 4, c)
    for x in (70, 96, 122):
        i.line([(x, 34), (x - 5, 22), (x + 2, 10)], (200, 196, 186, 120), 3)
    # Огонь под котелком.
    i.glow(96, 112, 22, (255, 150, 60, 255), 200)
    for x in (78, 96, 114):
        i.poly([(x - 7, 118), (x, 100), (x + 7, 118)], (255, 170, 70, 255))
    return i


def tea():
    i = Icon()
    # Эмалированная кружка.
    i.ellipse(122, 50, 160, 92, None, OUT_LINE, 9)
    i.ellipse(122, 50, 160, 92, None, (210, 214, 210, 255), 5)
    i.poly([(56, 38), (134, 38), (128, 112), (62, 112)], (210, 214, 210, 255), OUT_LINE)
    i.ellipse(54, 30, 136, 48, (180, 184, 180, 255), OUT_LINE)
    i.ellipse(60, 33, 130, 45, (150, 90, 36, 255))
    i.rect(62, 98, 128, 104, (60, 100, 150, 255))
    i.line([(118, 30), (150, 16)], (230, 220, 190, 255), 2)
    i.rect(146, 12, 162, 26, (240, 220, 120, 255), 2, OUT_LINE)
    for x in (78, 96, 112):
        i.line([(x, 28), (x - 5, 16), (x + 2, 4)], (220, 216, 206, 120), 3)
    return i


ICONS = {"toolkit": toolkit, "armor_kit": armor_kit, "weapon_kit": weapon_kit, "campfire_kit": campfire_kit,
         "meat_fried": meat_fried, "meat_dubious": meat_dubious, "shashlik": shashlik, "stew": stew, "tea": tea}


def main(names):
    os.makedirs(OUT, exist_ok=True)
    # Icon.save пишет в gen_icons.OUT: направляем его в папку аддона крафта.
    gen_icons.OUT = OUT
    for name in names or sorted(ICONS):
        ICONS[name]().save(name)
    print("icons:", len(names or ICONS), "->", OUT)


if __name__ == "__main__":
    main(sys.argv[1:])
