#!/usr/bin/env python3
"""Иконки предметов STALKER Events (192x128 PNG, прозрачный фон) в стиле иконок STALKER Zone.

Рисование — класс Icon из tools/gen_icons.py (тот же размер, суперсэмплинг и тень).
Запуск из корня репозитория:  python3 tools/gen_icons_events.py
Результат: stalker_events/materials/stalker_events/items/<id>.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_icons  # noqa: E402
from gen_icons import DARK, METAL, OUT_LINE, Icon  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "stalker_events", "materials", "stalker_events", "items")


def beacon():
    """Радиомаячок: корпус на опоре, антенна и проблесковый огонь."""
    i = Icon()
    # Сигнальные дуги за корпусом.
    for k, r in enumerate((26, 38, 50)):
        a = 200 - k * 55
        i.d.arc([(134 - r) * gen_icons.K, (34 - r) * gen_icons.K, (134 + r) * gen_icons.K, (34 + r) * gen_icons.K],
                start=-60, end=20, fill=(110, 200, 255, a), width=3 * gen_icons.K)
    # Опора и корпус.
    i.poly([(64, 112), (128, 112), (116, 100), (76, 100)], DARK, OUT_LINE)
    i.rect(70, 50, 122, 102, (92, 98, 88, 255), 6, OUT_LINE)
    i.rect(78, 60, 114, 78, (24, 32, 26, 255), 3, OUT_LINE)
    for k in range(3):
        i.rect(82 + k * 11, 66, 88 + k * 11, 72, (110, 200, 255, 255))
    i.ellipse(80, 84, 90, 94, (150, 60, 40, 255))
    i.rect(96, 86, 112, 92, METAL, 2)
    # Антенна и лампа.
    i.line([(116, 52), (134, 22)], OUT_LINE, 4)
    i.line([(116, 52), (134, 22)], METAL, 2)
    i.rect(84, 38, 108, 50, DARK, 3, OUT_LINE)
    i.glow(96, 32, 26, (110, 200, 255, 255), 230)
    i.ellipse(87, 23, 105, 41, (170, 230, 255, 255), OUT_LINE)
    i.ellipse(92, 27, 98, 33, (240, 250, 255, 255))
    return i


ICONS = {"beacon": beacon}


def main(names):
    os.makedirs(OUT, exist_ok=True)
    # Icon.save пишет в gen_icons.OUT: направляем его в папку аддона событий.
    gen_icons.OUT = OUT
    for name in names or sorted(ICONS):
        ICONS[name]().save(name)
    print("icons:", len(names or ICONS), "->", OUT)


if __name__ == "__main__":
    main(sys.argv[1:])
