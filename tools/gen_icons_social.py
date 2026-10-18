#!/usr/bin/env python3
"""Иконки нашивок STALKER Social (64x64 PNG, прозрачный фон).

Рисование — класс Icon из tools/gen_icons.py (суперсэмплинг и сглаживание), размер холста 64x64.
Нашивки группировок не генерируются: аддон берёт эмблемы stalker_factions/materials/stalker_factions/emblems.
Запуск из корня репозитория:  python3 tools/gen_icons_social.py
Результат: stalker_social/materials/stalker_social/patches/<id>.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_icons  # noqa: E402
from gen_icons import OUT_LINE, Icon  # noqa: E402
from PIL import Image, ImageFilter  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "stalker_social", "materials", "stalker_social", "patches")
SIZE = 64
CLOTH = (52, 56, 46, 255)       # ткань нашивки
CLOTH_DARK = (38, 41, 34, 255)
THREAD = (196, 184, 140, 255)   # нить кромки
GOLD = (214, 176, 84, 255)
STEEL = (150, 156, 152, 255)


class Patch(Icon):
    """Холст 64x64 (модуль gen_icons хранит размер в глобальных W/H) и мягкая тень под нашивкой."""

    def __init__(self):
        gen_icons.W, gen_icons.H = SIZE, SIZE
        super().__init__()

    def stitch(self, cx, cy, r, color, n=28):
        """Строчка по кругу: короткие штрихи нитью."""
        for k in range(n):
            a0 = 2 * math.pi * k / n
            a1 = a0 + math.pi / n
            self.line([(cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], color, 1.2)

    def save_to(self, name):
        k = gen_icons.K
        alpha = self.img.split()[3]
        shadow = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        shadow.putalpha(alpha.point(lambda a: int(a * 0.55)))
        shadow = shadow.filter(ImageFilter.GaussianBlur(1.5 * k))
        base = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        base.alpha_composite(shadow, (0, int(1.5 * k)))
        base.alpha_composite(self.img)
        base = base.resize((SIZE, SIZE), Image.LANCZOS)
        base.save(os.path.join(OUT, name + ".png"), optimize=True)


def round_patch(border):
    """Круглая нашивка достижения: ткань, цветная кайма, строчка."""
    i = Patch()
    i.ellipse(4, 4, 60, 60, border, OUT_LINE)
    i.ellipse(9, 9, 55, 55, CLOTH, OUT_LINE, 1)
    i.stitch(32, 32, 25.5, THREAD)
    return i


def shield_patch(border):
    """Щиток награды командира: золотая или цветная кайма."""
    i = Patch()
    outer = [(8, 6), (56, 6), (56, 34), (32, 60), (8, 34)]
    inner = [(13, 11), (51, 11), (51, 32), (32, 53), (13, 32)]
    i.poly(outer, border, OUT_LINE)
    i.poly(inner, CLOTH, OUT_LINE, 1)
    return i


def chevron(i, y, color):
    i.line([(17, y), (32, y - 9), (47, y)], OUT_LINE, 7)
    i.line([(17, y), (32, y - 9), (47, y)], color, 4.5)


def star(i, cx, cy, r, color, outline=OUT_LINE):
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.42
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    i.poly(pts, color, outline, 1)


def rank(n):
    """Звание: прямоугольный шеврон, 1–3 угла, «Мастер» — угол и звезда, «Легенда» — звезда в венке."""
    def draw():
        i = Patch()
        i.rect(10, 4, 54, 60, (88, 92, 70, 255), 5, OUT_LINE)
        i.rect(14, 8, 50, 56, CLOTH_DARK, 3, OUT_LINE, 1)
        for y in range(11, 54, 6):
            i.line([(16, y), (48, y)], (48, 52, 42, 255), 1)
        if n <= 3:
            for k in range(n):
                chevron(i, 30 + k * 10 - (n - 1) * 5 + 8, GOLD)
        elif n == 4:
            star(i, 32, 22, 9, GOLD)
            chevron(i, 46, GOLD)
        else:
            star(i, 32, 30, 13, GOLD)
            for side in (-1, 1):
                for k in range(4):
                    # Венок: листья дугой от низа вверх по обе стороны звезды.
                    a = math.radians(200 - k * 22) if side < 0 else math.radians(-20 + k * 22)
                    x, y = 32 + 17 * math.cos(a), 34 - 17 * math.sin(a)
                    i.ellipse(x - 2.6, y - 1.6, x + 2.6, y + 1.6, (150, 170, 90, 255))
        return i
    return draw


def hunter():
    i = round_patch((150, 52, 40, 255))
    for k, dx in enumerate((-9, 0, 9)):
        i.line([(24 + dx, 18 + abs(dx) * 0.3), (34 + dx, 46 - abs(dx) * 0.3)], OUT_LINE, 5)
        i.line([(24 + dx, 18 + abs(dx) * 0.3), (34 + dx, 46 - abs(dx) * 0.3)], (226, 214, 190, 255), 2.6)
    return i


def seeker():
    i = round_patch((206, 150, 58, 255))
    i.glow(32, 32, 16, (255, 200, 90, 255), 230)
    i.ellipse(23, 23, 41, 41, (232, 178, 70, 255), OUT_LINE)
    i.ellipse(27, 26, 33, 32, (255, 240, 190, 255))
    return i


def survivor():
    i = round_patch((118, 84, 160, 255))
    i.rect(14, 40, 50, 46, (74, 70, 64, 255))
    i.poly([(35, 13), (24, 34), (32, 34), (27, 51), (42, 28), (34, 28), (40, 13)], (220, 210, 250, 255), OUT_LINE, 1)
    return i


def tracker():
    i = round_patch((132, 102, 62, 255))
    for (x, y, a) in ((24, 42, -12), (38, 30, 12), (26, 20, -12)):
        i.ellipse(x - 4, y - 6, x + 4, y + 6, (210, 196, 160, 255), OUT_LINE, 1)
        i.ellipse(x - 2.5 + a * 0.1, y - 11, x + 2.5 + a * 0.1, y - 7, (210, 196, 160, 255))
    return i


def veteran():
    i = round_patch(STEEL)
    for (a, b) in (((18, 46), (46, 18)), ((18, 18), (46, 46))):
        i.line([a, b], OUT_LINE, 6)
        i.line([a, b], (200, 204, 198, 255), 3)
    i.ellipse(27, 27, 37, 37, (150, 52, 40, 255), OUT_LINE, 1)
    return i


def executor():
    i = round_patch((96, 150, 84, 255))
    i.rect(20, 15, 44, 49, (214, 206, 180, 255), 2, OUT_LINE, 1)
    for y in (22, 28, 34):
        i.line([(24, y), (40, y)], (130, 124, 104, 255), 1.4)
    i.line([(24, 40), (30, 46), (44, 30)], OUT_LINE, 5)
    i.line([(24, 40), (30, 46), (44, 30)], (120, 200, 96, 255), 3)
    return i


def cook():
    i = round_patch((206, 112, 48, 255))
    i.rect(18, 30, 46, 46, (150, 156, 152, 255), 3, OUT_LINE, 1)
    i.rect(15, 28, 49, 32, (120, 124, 120, 255), 1, OUT_LINE, 1)
    for x in (26, 32, 38):
        i.line([(x, 25), (x - 3, 20), (x, 15)], (230, 230, 220, 200), 1.6)
    i.glow(32, 50, 8, (255, 140, 40, 255), 200)
    return i


def master():
    i = round_patch((84, 126, 167, 255))
    i.line([(19, 45), (42, 22)], OUT_LINE, 6)
    i.line([(19, 45), (42, 22)], STEEL, 3.4)
    i.ellipse(38, 15, 49, 26, STEEL, OUT_LINE, 1)
    i.ellipse(41, 18, 46, 23, CLOTH)
    i.line([(45, 45), (24, 24)], OUT_LINE, 6)
    i.line([(45, 45), (24, 24)], (130, 90, 56, 255), 3.4)
    i.rect(16, 16, 30, 24, STEEL, 1, OUT_LINE, 1)
    return i


def excellent():
    i = shield_patch(GOLD)
    star(i, 32, 29, 13, GOLD)
    for side in (-1, 1):
        for k in range(3):
            x = 32 + side * (15 - k * 1.5)
            y = 40 - k * 7
            i.ellipse(x - 2.4, y - 1.6, x + 2.4, y + 1.6, (150, 170, 90, 255))
    return i


def medic():
    i = shield_patch((196, 196, 188, 255))
    i.rect(27, 16, 37, 44, (196, 52, 44, 255), 1, OUT_LINE, 1)
    i.rect(18, 25, 46, 35, (196, 52, 44, 255), 1, OUT_LINE, 1)
    i.rect(28, 17, 36, 43, (196, 52, 44, 255))
    return i


def scout():
    i = shield_patch((110, 150, 84, 255))
    i.ellipse(14, 22, 50, 40, (214, 206, 180, 255), OUT_LINE, 1)
    i.ellipse(25, 24, 39, 38, (70, 110, 70, 255), OUT_LINE, 1)
    i.ellipse(29, 28, 35, 34, OUT_LINE)
    i.ellipse(30, 28, 32, 30, (240, 240, 230, 255))
    return i


def assault():
    i = shield_patch((168, 60, 46, 255))
    i.poly([(32, 14), (37, 27), (34, 27), (34, 46), (30, 46), (30, 27), (27, 27)], (226, 214, 190, 255), OUT_LINE, 1)
    i.line([(20, 40), (32, 50), (44, 40)], OUT_LINE, 6)
    i.line([(20, 40), (32, 50), (44, 40)], GOLD, 3.5)
    return i


ICONS = {"ach_hunter": hunter, "ach_seeker": seeker, "ach_survivor": survivor, "ach_tracker": tracker,
         "ach_veteran": veteran, "ach_executor": executor, "ach_cook": cook, "ach_master": master,
         "award_excellent": excellent, "award_medic": medic, "award_scout": scout, "award_assault": assault}
for _n in range(1, 6):
    ICONS["rank_%d" % _n] = rank(_n)


def main(names):
    os.makedirs(OUT, exist_ok=True)
    for name in names or sorted(ICONS):
        ICONS[name]().save_to(name)
    print("patches:", len(names or ICONS), "->", OUT)


if __name__ == "__main__":
    main(sys.argv[1:])
