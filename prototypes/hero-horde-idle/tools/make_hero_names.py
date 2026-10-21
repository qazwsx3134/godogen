"""Writes data/hero_names.json: 100 distinct fantasy names, one per hero index (push_sim.gd roster order). Run once;
after that the JSON is the source and can be edited by hand.

    python3 tools/make_hero_names.py      (from prototypes/hero-horde-idle; refuses to overwrite)
"""
import json
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "data" / "hero_names.json"
HEAD = list("艾貝卡黛伊菲格海伊潔凱莉瑪諾奧佩琪羅席塔烏薇溫希雅澤安柏夏蒂恩芙葛赫茵嘉珂蘿梅娜歐")
TAIL = ["琳", "爾", "恩", "娜", "斯", "蘭", "卡", "莉", "倫", "特", "雅", "絲", "德", "薇", "諾", "亞", "妮", "格",
        "瑟", "芙", "洛", "爾德", "莉亞", "文", "坦", "珀", "瑞", "嘉", "蒙", "瑪"]

if __name__ == "__main__":
    if OUT.exists():
        raise SystemExit(f"{OUT} exists; edit it by hand instead")
    rng = random.Random(42)
    names: list[str] = []
    while len(names) < 100:
        name = rng.choice(HEAD) + rng.choice(TAIL)
        if rng.random() < 0.25:
            name += rng.choice(["爾", "娜", "斯", "恩", "特"])
        if name not in names and len(name) <= 4 and all(a != b for a, b in zip(name, name[1:])):
            names.append(name)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"_note": "One name per hero index (push_sim.gd roster order). Edit freely; keep 100 "
                                        "distinct names.", "names": names}, ensure_ascii=False, indent=1) + "\n")
    print("wrote", OUT)
