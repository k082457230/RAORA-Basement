"""把 Noto Sans CJK TC 子集化成「這個專案真的用得到的字」。

為什麼要做：Web 匯出必須內嵌字型（瀏覽器沙盒讀不到系統字型，SystemFont 會 fallback
到不含 CJK 的 Godot 內建字型 ⇒ 整頁豆腐方塊）。但完整的 Noto Sans CJK TC 是 15.7MB，
itch.io 上等於讓玩家先下載 16MB 才看得到標題畫面。

用 CJK 版（而非單純的 Noto Sans TC）是因為它同時涵蓋日文平假名／片假名與部分韓文，
留一條路給未來的日文版——否則換語言就要整頁豆腐方塊重演一次。子集化之後兩者輸出
大小差不多，Web 下載量幾乎不受影響。

做法：掃過所有 .gd 的**全文**（含註解，不只字串字面值），把出現過的 CJK 字挑出來，
再加上 ASCII 與遊戲會用到的符號。掃全文是刻意的——漏一個字就是一個豆腐方塊，
而多收幾百個字只是多幾十 KB，兩邊的代價差很多。

⚠ 改過任何中文文案之後要重跑這支腳本，否則新字會變豆腐。

用法（專案根目錄或任意位置皆可）：
    python spike_well/tools/subset_font.py
"""

import pathlib

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "NotoSansCJKtc-Regular.otf"
DST = ROOT / "assets" / "fonts" / "NotoSansCJKtc.otf"

# UI 會用到但可能不出現在 .gd 全文裡的符號（等級圓點、破折號、全形標點…）
EXTRA = "●○◎★☆—–…「」『』、。，；：！？（）〈〉《》【】％＋－×÷→←↑↓⚠✓✗　"


def collect_chars() -> set:
    chars = {chr(c) for c in range(0x20, 0x7F)}
    chars.update(EXTRA)
    for gd in ROOT.rglob("*.gd"):
        if ".godot" in gd.parts:
            continue
        for ch in gd.read_text(encoding="utf-8"):
            if ord(ch) > 0x2000:  # 全形標點與 CJK 一律收
                chars.add(ch)
    return chars


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"找不到來源字型：{SRC}")

    chars = collect_chars()
    DST.parent.mkdir(parents=True, exist_ok=True)

    font = TTFont(SRC)
    # 先把 variable font 固定成 Regular：spike 只用一種字重，
    # 留著 wght 軸等於白白背著所有中間字重的插值資料。
    if "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": 400}, inplace=False)

    options = subset.Options()
    options.layout_features = ["kern", "liga"]
    options.drop_tables += ["DSIG"]
    options.name_IDs = [1, 2, 3, 4, 5, 6]
    options.notdef_outline = True
    options.recalc_bounds = True

    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text="".join(sorted(chars)))
    subsetter.subset(font)
    font.save(DST)

    src_mb = SRC.stat().st_size / 1024 / 1024
    dst_kb = DST.stat().st_size / 1024
    print(f"字元數 : {len(chars)}")
    print(f"來源   : {src_mb:.1f} MB")
    print(f"輸出   : {dst_kb:.0f} KB  -> {DST}")


if __name__ == "__main__":
    main()
