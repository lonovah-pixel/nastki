#!/usr/bin/env python3
"""Генератор иконок предметов STALKER Zone (192x128 PNG, прозрачный фон).

Стиль повторяет иконки STALKER Inventory: плоские приглушённые формы и мягкая тень.
Запуск из корня репозитория:  python3 tools/gen_icons.py
Результат: stalker_zone/materials/stalker_zone/items/<id>.png
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, K = 192, 128, 4  # итоговый размер и коэффициент суперсэмплинга
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "stalker_zone", "materials", "stalker_zone", "items")
FONT_PATHS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
              "C:/Windows/Fonts/arialbd.ttf"]


def font(size):
    for path in FONT_PATHS:
        if os.path.exists(path):
            return ImageFont.truetype(path, size * K)
    return ImageFont.load_default()


def shade(color, k):
    return tuple(max(0, min(255, int(c * k))) for c in color[:3]) + ((color[3],) if len(color) > 3 else (255,))


class Icon:
    def __init__(self):
        self.img = Image.new("RGBA", (W * K, H * K), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    @staticmethod
    def p(points):
        return [(x * K, y * K) for x, y in points]

    def poly(self, pts, fill, outline=None, width=2):
        self.d.polygon(self.p(pts), fill=fill, outline=outline, width=width * K if outline else 0)

    def rect(self, x0, y0, x1, y1, fill, r=0, outline=None, width=2):
        box = [x0 * K, y0 * K, x1 * K, y1 * K]
        if r:
            self.d.rounded_rectangle(box, r * K, fill=fill, outline=outline, width=width * K if outline else 0)
        else:
            self.d.rectangle(box, fill=fill, outline=outline, width=width * K if outline else 0)

    def ellipse(self, x0, y0, x1, y1, fill, outline=None, width=2):
        self.d.ellipse([x0 * K, y0 * K, x1 * K, y1 * K], fill=fill, outline=outline, width=width * K if outline else 0)

    def line(self, pts, fill, width=2):
        self.d.line(self.p(pts), fill=fill, width=int(width * K), joint="curve")

    def text(self, x, y, s, size, fill):
        f = font(size)
        bbox = self.d.textbbox((0, 0), s, font=f)
        self.d.text((x * K - (bbox[2] - bbox[0]) / 2, y * K - (bbox[3] - bbox[1]) / 2 - bbox[1]), s, font=f, fill=fill)

    def glow(self, cx, cy, radius, color, strength=200):
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        g = ImageDraw.Draw(layer)
        for i in range(12, 0, -1):
            r = radius * i / 12
            a = int(strength * (1 - i / 13) ** 1.6)
            g.ellipse([(cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K], fill=color[:3] + (a,))
        layer = layer.filter(ImageFilter.GaussianBlur(4 * K))
        self.img.alpha_composite(layer)

    def save(self, name):
        alpha = self.img.split()[3]
        shadow = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        shadow.putalpha(alpha.point(lambda a: int(a * 0.5)))
        shadow = shadow.filter(ImageFilter.GaussianBlur(3 * K))
        base = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        base.alpha_composite(shadow, (2 * K, 4 * K))
        base.alpha_composite(self.img)
        base = base.resize((W, H), Image.LANCZOS)
        base.save(os.path.join(OUT, name + ".png"), optimize=True)


OUT_LINE = (25, 24, 20, 255)
METAL = (128, 132, 128, 255)
DARK = (58, 60, 56, 255)
WOOD = (118, 78, 46, 255)


# --- Оружие -----------------------------------------------------------------
def crowbar():
    i = Icon()
    i.line([(40, 104), (128, 30), (146, 26), (156, 34)], OUT_LINE, 13)
    i.line([(40, 104), (128, 30), (146, 26), (156, 34)], (168, 42, 34, 255), 9)
    i.line([(36, 100), (46, 110)], (90, 90, 90, 255), 9)
    i.line([(44, 98), (126, 32)], (210, 90, 80, 255), 2)
    return i


def revolver():
    i = Icon()
    i.rect(58, 42, 160, 56, METAL, 3, OUT_LINE)
    i.rect(150, 38, 158, 44, METAL)
    i.ellipse(78, 38, 114, 72, (104, 108, 104, 255), OUT_LINE)
    for k in range(3):
        i.line([(84 + k * 10, 46), (84 + k * 10, 64)], DARK, 2)
    i.poly([(60, 52), (82, 54), (74, 102), (50, 104), (46, 96)], WOOD, OUT_LINE)
    i.line([(84, 66), (92, 80), (102, 70)], DARK, 3)
    return i


def shotgun():
    i = Icon()
    i.rect(54, 46, 178, 54, METAL, 2, OUT_LINE)
    i.rect(70, 55, 150, 63, DARK, 3, OUT_LINE)
    i.rect(104, 56, 140, 66, WOOD, 3, OUT_LINE)
    i.poly([(16, 56), (60, 44), (66, 70), (24, 80)], WOOD, OUT_LINE)
    i.poly([(56, 44), (80, 44), (80, 68), (62, 70)], DARK, OUT_LINE)
    i.line([(70, 70), (74, 80), (84, 72)], DARK, 3)
    return i


def ar2():
    i = Icon()
    i.poly([(20, 64), (60, 50), (150, 46), (176, 52), (172, 64), (110, 70), (64, 76)], (70, 84, 96, 255), OUT_LINE)
    i.rect(150, 50, 184, 58, DARK, 2, OUT_LINE)
    i.ellipse(52, 66, 76, 90, (40, 46, 52, 255), OUT_LINE)
    i.glow(64, 78, 14, (110, 190, 255), 220)
    i.ellipse(58, 72, 70, 84, (160, 220, 255, 255))
    i.poly([(96, 68), (110, 68), (106, 96), (92, 96)], DARK, OUT_LINE)
    i.line([(70, 52), (140, 50)], (120, 140, 160, 255), 2)
    return i


def crossbow():
    i = Icon()
    i.rect(30, 58, 168, 68, WOOD, 3, OUT_LINE)
    i.poly([(18, 58), (40, 56), (44, 84), (22, 88)], WOOD, OUT_LINE)
    i.line([(150, 22), (160, 63), (150, 104)], OUT_LINE, 8)
    i.line([(150, 22), (160, 63), (150, 104)], METAL, 5)
    i.line([(150, 22), (110, 63), (150, 104)], (210, 205, 180, 255), 1.5)
    i.rect(80, 46, 128, 56, DARK, 4, OUT_LINE)
    i.line([(110, 63), (182, 63)], (190, 190, 190, 255), 2)
    return i


def grenade():
    i = Icon()
    i.ellipse(70, 34, 122, 106, (78, 92, 64, 255), OUT_LINE)
    for y in (52, 70, 88):
        i.line([(74, y), (118, y)], (58, 70, 48, 255), 2)
    i.rect(86, 22, 106, 38, METAL, 2, OUT_LINE)
    i.line([(106, 26), (128, 40), (126, 70)], METAL, 4)
    i.ellipse(70, 14, 88, 32, None, METAL, 3)
    return i


# --- Боеприпасы ---------------------------------------------------------------
def ammo_box(color, label, accent=(220, 210, 170, 255)):
    def build():
        i = Icon()
        top = [(30, 54), (112, 36), (166, 52), (84, 72)]
        i.poly([(30, 54), (84, 72), (84, 100), (30, 82)], shade(color, .8), OUT_LINE)
        i.poly([(84, 72), (166, 52), (166, 80), (84, 100)], shade(color, .62), OUT_LINE)
        i.poly(top, color, OUT_LINE)
        i.poly([(92, 78), (158, 62), (158, 74), (92, 90)], accent)
        i.text(125, 76, label, 9, (40, 36, 28, 255))
        return i
    return build


# --- Костюмы ------------------------------------------------------------------
def suit(body, accent, extra=None):
    def build():
        i = Icon()
        i.poly([(56, 30), (76, 22), (116, 22), (136, 30), (166, 54), (150, 84), (134, 72), (134, 112), (58, 112), (58, 72), (42, 84), (26, 54)], body, OUT_LINE)
        i.poly([(78, 22), (96, 40), (114, 22)], shade(body, .7), OUT_LINE)
        i.line([(96, 40), (96, 110)], shade(body, .6), 2)
        i.rect(66, 72, 86, 90, shade(body, .8), 2, OUT_LINE)
        i.rect(106, 72, 126, 90, shade(body, .8), 2, OUT_LINE)
        if accent:
            i.rect(60, 48, 132, 54, accent)
        if extra:
            extra(i, body)
        return i
    return build


def exo_frame(i, body):
    for x in (62, 130):
        i.line([(x, 34), (x, 110)], (40, 40, 40, 255), 4)
    i.rect(80, 46, 112, 70, shade(body, .7), 3, OUT_LINE)
    i.line([(86, 58), (106, 58)], (190, 160, 70, 255), 3)


def seva_hood(i, body):
    i.ellipse(72, 4, 120, 46, shade(body, .9), OUT_LINE)
    i.ellipse(80, 14, 112, 38, (60, 140, 170, 255), OUT_LINE)
    i.line([(86, 20), (98, 18)], (170, 230, 240, 255), 2)


def hazmat_hood(i, body):
    i.ellipse(74, 6, 118, 46, body, OUT_LINE)
    i.ellipse(82, 16, 110, 36, (70, 80, 70, 255), OUT_LINE)
    i.rect(66, 96, 126, 102, (40, 40, 40, 255))


def plates(i, body):
    for y in (60, 76, 92):
        i.rect(70, y, 122, y + 10, shade(body, .75), 2, OUT_LINE)


# --- Шлемы и обувь ----------------------------------------------------------------
def tactical_helmet():
    i = Icon()
    i.d.pieslice([46 * K, 22 * K, 146 * K, 122 * K], 180, 360, fill=(70, 78, 60, 255), outline=OUT_LINE, width=2 * K)
    i.rect(40, 70, 152, 78, (56, 62, 48, 255), 3, OUT_LINE)
    i.rect(64, 50, 128, 66, (60, 80, 90, 200), 4, OUT_LINE)
    i.line([(70, 54), (90, 54)], (160, 200, 210, 255), 2)
    return i


def sphere():
    i = Icon()
    i.ellipse(52, 18, 140, 106, (88, 92, 96, 255), OUT_LINE)
    i.rect(66, 46, 126, 66, (40, 70, 80, 255), 6, OUT_LINE)
    i.ellipse(84, 74, 108, 102, (50, 52, 50, 255), OUT_LINE)
    i.line([(72, 50), (96, 50)], (150, 200, 210, 255), 2)
    return i


def gasmask():
    i = Icon()
    i.ellipse(56, 18, 136, 104, (66, 76, 58, 255), OUT_LINE)
    i.ellipse(64, 36, 90, 62, (40, 56, 60, 255), OUT_LINE)
    i.ellipse(102, 36, 128, 62, (40, 56, 60, 255), OUT_LINE)
    i.ellipse(80, 72, 112, 104, (52, 54, 50, 255), OUT_LINE)
    i.rect(84, 98, 108, 118, (70, 72, 66, 255), 3, OUT_LINE)
    return i


def boots(color):
    def build():
        i = Icon()
        for x in (40, 102):
            i.poly([(x + 6, 18), (x + 38, 18), (x + 38, 86), (x + 50, 96), (x + 50, 108), (x, 108), (x, 86), (x + 6, 80)], color, OUT_LINE)
            i.rect(x, 100, x + 50, 110, (36, 32, 28, 255))
            for y in (30, 42, 54):
                i.line([(x + 14, y), (x + 30, y + 4)], (200, 190, 160, 255), 2)
        return i
    return build


# --- Детекторы ------------------------------------------------------------------
def detector(screen, kind):
    def build():
        i = Icon()
        i.rect(54, 30, 142, 112, (74, 76, 70, 255), 10, OUT_LINE)
        i.rect(66, 42, 130, 82, (24, 32, 26, 255), 4, OUT_LINE)
        if kind == "signal":
            for k, h in enumerate((8, 14, 22, 30)):
                i.rect(74 + k * 14, 76 - h, 82 + k * 14, 76, screen)
        elif kind == "arrow":
            i.poly([(98, 48), (112, 74), (98, 66), (84, 74)], screen)
        else:
            i.ellipse(80, 48, 116, 78, None, screen, 2)
            i.line([(98, 63), (110, 52)], screen, 2)
            i.ellipse(103, 52, 109, 58, screen)
        i.ellipse(70, 90, 82, 102, (150, 60, 40, 255))
        i.ellipse(114, 90, 126, 102, (70, 140, 70, 255))
        i.line([(130, 30), (150, 8)], OUT_LINE, 4)
        i.line([(130, 30), (150, 8)], METAL, 2)
        return i
    return build


# --- Медицина и еда -----------------------------------------------------------------
def medkit(color, cross):
    def build():
        i = Icon()
        i.rect(84, 26, 108, 36, (70, 70, 70, 255), 3, OUT_LINE)
        i.rect(46, 34, 146, 104, color, 8, OUT_LINE)
        i.rect(86, 46, 106, 92, cross)
        i.rect(72, 60, 120, 78, cross)
        return i
    return build


def antirad():
    i = Icon()
    i.line([(36, 96), (140, 32)], OUT_LINE, 16)
    i.line([(36, 96), (140, 32)], (200, 210, 214, 255), 12)
    i.line([(60, 82), (120, 45)], (220, 180, 60, 255), 8)
    i.line([(140, 32), (164, 18)], METAL, 3)
    i.line([(28, 102), (40, 94)], DARK, 10)
    i.text(96, 98, "☢", 18, (220, 180, 60, 255))
    return i


def vodka():
    i = Icon()
    i.rect(86, 10, 106, 32, (200, 200, 190, 255), 3, OUT_LINE)
    i.poly([(84, 32), (108, 32), (124, 52), (124, 116), (68, 116), (68, 52)], (190, 215, 220, 210), OUT_LINE)
    i.rect(70, 62, 122, 96, (200, 60, 40, 255))
    i.text(96, 79, "ВОДКА", 8, (240, 230, 200, 255))
    return i


def energy():
    i = Icon()
    i.rect(72, 20, 120, 112, (40, 120, 70, 255), 8, OUT_LINE)
    i.rect(72, 20, 120, 30, (170, 170, 170, 255), 4, OUT_LINE)
    i.poly([(98, 42), (86, 70), (98, 70), (92, 98), (110, 62), (98, 62), (106, 42)], (230, 220, 80, 255))
    return i


def bread():
    i = Icon()
    i.ellipse(30, 40, 162, 104, (170, 120, 64, 255), OUT_LINE)
    i.ellipse(36, 44, 156, 86, (196, 146, 82, 255))
    for x in (60, 86, 112, 138):
        i.line([(x - 8, 52), (x + 6, 76)], (130, 86, 44, 255), 3)
    return i


def sausage():
    i = Icon()
    i.line([(34, 84), (96, 54), (158, 46)], OUT_LINE, 30)
    i.line([(34, 84), (96, 54), (158, 46)], (168, 70, 70, 255), 26)
    for x, y in ((60, 68), (96, 54), (130, 48)):
        i.ellipse(x - 3, y - 3, x + 3, y + 3, (230, 190, 180, 255))
    i.line([(160, 46), (172, 40)], (210, 200, 160, 255), 3)
    i.line([(30, 86), (20, 94)], (210, 200, 160, 255), 3)
    return i


# --- Артефакты ------------------------------------------------------------------------
def artifact(kind, color):
    def build():
        i = Icon()
        i.glow(96, 64, 50, color, 170)
        c = color[:3] + (255,)
        if kind == "jelly":
            i.d.pieslice([60 * K, 30 * K, 132 * K, 102 * K], 180, 360, fill=c, outline=OUT_LINE, width=2 * K)
            for x in (70, 86, 102, 118):
                i.line([(x, 66), (x - 4, 84), (x + 2, 100)], shade(c, .8), 4)
        elif kind == "star":
            pts = []
            for k in range(10):
                r = 40 if k % 2 == 0 else 16
                a = -math.pi / 2 + k * math.pi / 5
                pts.append((96 + math.cos(a) * r, 64 + math.sin(a) * r))
            i.poly(pts, c, OUT_LINE)
        elif kind == "bubble":
            for x, y, r in ((84, 70, 22), (110, 60, 18), (100, 86, 14), (92, 48, 12)):
                i.ellipse(x - r, y - r, x + r, y + r, shade(c, .9), OUT_LINE)
                i.ellipse(x - r * .5, y - r * .6, x - r * .1, y - r * .2, (255, 255, 240, 160))
        elif kind == "battery":
            i.rect(74, 26, 118, 104, c, 8, OUT_LINE)
            for y in (44, 62, 80):
                i.line([(76, y), (116, y)], shade(c, .6), 3)
            i.rect(88, 18, 104, 28, METAL, 2, OUT_LINE)
        elif kind == "flash":
            pts = []
            for k in range(14):
                r = 38 if k % 2 == 0 else 20
                a = k * math.pi / 7
                pts.append((96 + math.cos(a) * r, 64 + math.sin(a) * r))
            i.poly(pts, c, OUT_LINE)
            i.ellipse(84, 52, 108, 76, (240, 250, 255, 255))
        elif kind == "crystal":
            i.poly([(96, 18), (122, 52), (110, 108), (82, 108), (70, 52)], c, OUT_LINE)
            i.line([(96, 18), (96, 108)], shade(c, .7), 2)
            i.line([(70, 52), (122, 52)], shade(c, .7), 2)
        elif kind == "slime":
            i.poly([(60, 96), (62, 70), (76, 48), (98, 40), (122, 50), (134, 74), (130, 98), (110, 92), (96, 104), (80, 94)], c, OUT_LINE)
            i.ellipse(80, 54, 96, 66, (230, 255, 200, 170))
        elif kind == "soul":
            i.ellipse(66, 34, 100, 74, c, OUT_LINE)
            i.ellipse(92, 34, 126, 74, c, OUT_LINE)
            i.poly([(68, 62), (124, 62), (96, 104)], c)
            i.line([(72, 48), (120, 80)], shade(c, .7), 3)
        elif kind == "fish":
            i.ellipse(60, 40, 128, 88, c, OUT_LINE)
            i.poly([(124, 64), (152, 42), (148, 86)], shade(c, .85), OUT_LINE)
            i.ellipse(74, 54, 84, 64, OUT_LINE)
        elif kind == "compass":
            i.ellipse(56, 24, 136, 104, shade(c, .7), OUT_LINE)
            i.ellipse(66, 34, 126, 94, (40, 34, 28, 255), OUT_LINE)
            i.poly([(96, 38), (104, 64), (96, 90), (88, 64)], c)
            i.ellipse(92, 60, 100, 68, (240, 230, 200, 255))
        return i
    return build


ICONS = {
    "crowbar": crowbar, "revolver": revolver, "shotgun": shotgun, "ar2": ar2, "crossbow": crossbow, "grenade": grenade,
    "ammo_smg": ammo_box((150, 120, 70, 255), "5.45"),
    "ammo_buckshot": ammo_box((150, 60, 50, 255), "12×70"),
    "ammo_357": ammo_box((120, 110, 90, 255), ".357"),
    "ammo_ar2": ammo_box((70, 90, 110, 255), "9×39", (170, 210, 230, 255)),
    "ammo_bolt": ammo_box((100, 90, 70, 255), "БОЛТ"),
    "bandit_jacket": suit((70, 54, 40, 255), None),
    "zarya": suit((96, 110, 70, 255), (150, 130, 70, 255), plates),
    "duty_suit": suit((60, 56, 52, 255), (170, 50, 40, 255), plates),
    "freedom_suit": suit((80, 120, 60, 255), (150, 170, 80, 255)),
    "merc_suit": suit((70, 86, 110, 255), (120, 140, 160, 255), plates),
    "monolith_suit": suit((150, 150, 140, 255), (200, 200, 190, 255), plates),
    "berill": suit((84, 90, 64, 255), (60, 64, 46, 255), plates),
    "seva": suit((150, 120, 60, 255), (90, 140, 150, 255), seva_hood),
    "exo": suit((80, 82, 78, 255), (150, 120, 50, 255), exo_frame),
    "hazmat": suit((200, 170, 50, 255), None, hazmat_hood),
    "gasmask": gasmask, "tactical_helmet": tactical_helmet, "sphere": sphere,
    "army_boots": boots((46, 44, 40, 255)),
    "det_echo": detector((120, 220, 120, 255), "signal"),
    "det_bear": detector((230, 190, 80, 255), "arrow"),
    "det_veles": detector((110, 200, 240, 255), "exact"),
    "medkit_army": medkit((86, 100, 64, 255), (210, 60, 50, 255)),
    "medkit_sci": medkit((220, 224, 226, 255), (60, 120, 200, 255)),
    "antirad": antirad, "vodka": vodka, "energy": energy, "bread": bread, "sausage": sausage,
    "medusa": artifact("jelly", (150, 210, 120, 255)),
    "night_star": artifact("star", (140, 220, 255, 255)),
    "bubble": artifact("bubble", (210, 190, 130, 255)),
    "battery": artifact("battery", (110, 160, 255, 255)),
    "flash": artifact("flash", (150, 200, 255, 255)),
    "crystal": artifact("crystal", (255, 150, 70, 255)),
    "slime": artifact("slime", (140, 230, 90, 255)),
    "soul": artifact("soul", (240, 110, 140, 255)),
    "goldfish": artifact("fish", (255, 205, 80, 255)),
    "compass": artifact("compass", (255, 170, 60, 255)),
}


def main(names):
    os.makedirs(OUT, exist_ok=True)
    for name in names or sorted(ICONS):
        ICONS[name]().save(name)
    print("icons:", len(names or ICONS), "->", OUT)


if __name__ == "__main__":
    main(sys.argv[1:])
