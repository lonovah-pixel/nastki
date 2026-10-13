#!/usr/bin/env python3
"""Сборка архива релиза STALKER RP.

    python3 tools/build_release.py                 # dist/stalker-rp-<версия>.zip
    python3 tools/build_release.py --with-darkrp   # + gamemodes/darkrp с GitHub (нужен git)

Структура архива повторяет папку сервера:
    garrysmod/addons/<аддоны сборки>
    garrysmod/cfg/server.cfg
    garrysmod/gamemodes/darkrp        (только с --with-darkrp)
    README.md, CHANGELOG.md
"""
import argparse
import os
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DARKRP_REPO = "https://github.com/FPtje/DarkRP.git"
EXTRA_ADDONS = ["darkrpmodification", "ulib", "ulx"]
SKIP_NAMES = {".git", ".github", ".gitignore", ".gitattributes", ".editorconfig", "__pycache__"}
SKIP_SUFFIXES = (".build", ".pyc")


def addon_dirs():
    names = [n for n in sorted(os.listdir(ROOT)) if n.startswith("stalker_")] + EXTRA_ADDONS
    out = []
    for name in names:
        path = os.path.join(ROOT, name)
        if not os.path.isdir(os.path.join(path, "lua")):
            sys.exit("Аддон без папки lua/: " + name)
        out.append(name)
    return out


def copy_tree(src, dst):
    for base, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_NAMES)
        rel = os.path.relpath(base, src)
        target = os.path.join(dst, rel) if rel != "." else dst
        os.makedirs(target, exist_ok=True)
        for f in sorted(files):
            if f in SKIP_NAMES or f.endswith(SKIP_SUFFIXES):
                continue
            shutil.copy2(os.path.join(base, f), os.path.join(target, f))


def fetch_darkrp(dst):
    tmp = dst + ".clone"
    shutil.rmtree(tmp, ignore_errors=True)
    subprocess.run(["git", "clone", "--depth", "1", DARKRP_REPO, tmp], check=True)
    copy_tree(tmp, dst)
    shutil.rmtree(tmp, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--with-darkrp", action="store_true", help="добавить игровой режим DarkRP с GitHub")
    parser.add_argument("--out", default=os.path.join(ROOT, "dist"), help="папка результата")
    args = parser.parse_args()

    version = open(os.path.join(ROOT, "VERSION"), encoding="utf-8").read().strip()
    name = "stalker-rp-" + version + ("-darkrp" if args.with_darkrp else "")
    stage = os.path.join(args.out, name)
    shutil.rmtree(stage, ignore_errors=True)
    gmod = os.path.join(stage, "garrysmod")

    addons = addon_dirs()
    for addon in addons:
        copy_tree(os.path.join(ROOT, addon), os.path.join(gmod, "addons", addon))
    os.makedirs(os.path.join(gmod, "cfg"), exist_ok=True)
    shutil.copy2(os.path.join(ROOT, "server", "cfg", "server.cfg"), os.path.join(gmod, "cfg", "server.cfg"))
    for doc in ("README.md", "CHANGELOG.md", "VERSION"):
        shutil.copy2(os.path.join(ROOT, doc), os.path.join(stage, doc))
    if args.with_darkrp:
        fetch_darkrp(os.path.join(gmod, "gamemodes", "darkrp"))

    archive = os.path.join(args.out, name + ".zip")
    if os.path.exists(archive):
        os.remove(archive)
    count = 0
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for base, _, files in os.walk(stage):
            for f in sorted(files):
                full = os.path.join(base, f)
                z.write(full, os.path.relpath(full, args.out))
                count += 1
    print("Аддоны:", ", ".join(addons))
    print("Файлов:", count)
    print("Архив:", archive)


if __name__ == "__main__":
    main()
