#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""突變測試批次驅動：一次呼叫驗完整張突變表，取代「一條一條手動改壞再改回」。

## 為什麼有這支

`.claude/docs/evergreen.md` 第 6 條要求「稽核本身也可能是壞的」，所以每條新稽核都要做突變測試
（改壞 → 跑 → 確認紅 → 改回 → 再跑）。手動做的話每條 4 次來回，20 條就是 80 次；
2026-08-14 實測那 80 次來回（不是 smoke 本身的執行時間）才是驗證成本的大宗——
完整 smoke 只要 4~8 秒，單組 2~3 秒。這支把 80 次來回壓成 1 次。

## 用法

    python tools/mutation_check.py                    # 跑整張表
    python tools/mutation_check.py --id invuln-grace  # 只跑一條（可重複給）
    python tools/mutation_check.py --list             # 只列表，不執行
    python tools/mutation_check.py --godot <exe path> # 覆寫 Godot 執行檔位置

## 判決

    RED-OK    突變後該組稽核變紅 → 這條稽核真的抓得到問題（要的結果）
    MISS      突變後仍然綠 → **稽核是假的**，要修的是稽核不是遊戲
    BADPATCH  find 字串在檔裡找不到或不只一個 → 突變表過期了，改表
    PRERED    還沒突變該組就是紅的 → 基準壞了，先修好再談突變

退出碼：全部 RED-OK ＝ 0，否則 1。

## 刻意的取捨

- 只驗「expect_red 列的組會變紅」，**不驗「其他組不會紅」**——後者要跑全套、雜訊大，
  而且一個常數牽動多組稽核本來就正常。想確認波及範圍就自己跑一次全套。
- 還原走「開跑前把整個檔案原文存進記憶體，finally 寫回」，不靠反向字串替換：
  中途 Ctrl-C 或 Godot 卡死也還原得回來。⚠ 但**執行期間不要同時手改這些檔**，會被蓋掉。
- stdout 一律 ASCII（Windows console 是 cp950，中文必亂碼）；中文說明只寫進
  tools/out/mutation_report.txt（UTF-8），要看細節去讀那個檔。
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TABLE = ROOT / "tools" / "mutations.json"
DEFAULT_GODOT = r"C:/Users/gnt0233/Downloads/Godot_v4.6.1-stable_win64_console.exe"
OUT_DIR = ROOT / "tools" / "out"
REPORT = OUT_DIR / "mutation_report.txt"


# ============================================================
# 檔案讀寫（newline="" ＝ 原樣保留 CRLF/LF，避免整檔被改成另一種換行）
# ============================================================

def read_raw(path: Path) -> str:
    with open(path, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write_raw(path: Path, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


# ============================================================
# 跑 smoke
# ============================================================

def run_smoke(godot: str, group: str) -> tuple:
    """回傳 (是否綠, 輸出全文)。exit 0 ＝ 綠；1 ＝ 有稽核紅；2 ＝ 組名打錯。"""
    cmd = [godot, "--headless", "--path", str(ROOT), "res://smoke.tscn", "--", "--only=" + group]
    p = subprocess.run(cmd, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    return p.returncode == 0, (p.stdout or "") + (p.stderr or "")


def fail_lines(text: str) -> list:
    """挑出診斷用的行：稽核自己印的 !! 與最後的 [SMOKE] 彙總。"""
    return [ln.strip() for ln in text.splitlines()
            if "!!" in ln or "[SMOKE]" in ln]


# ============================================================
# 突變
# ============================================================

def apply_mutation(mut: dict) -> str:
    """把 find 換成 replace。回傳空字串＝成功，否則回傳錯誤原因。"""
    path = ROOT / mut["file"]
    if not path.exists():
        return "file not found: %s" % mut["file"]
    text = read_raw(path)
    hits = text.count(mut["find"])
    if hits != 1:
        return "find matched %d times (need exactly 1)" % hits
    write_raw(path, text.replace(mut["find"], mut["replace"]))
    return ""


def main() -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--table", default=str(DEFAULT_TABLE))
    ap.add_argument("--id", action="append", default=[])
    ap.add_argument("--godot", default=os.environ.get("GODOT_BIN", DEFAULT_GODOT))
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    table = json.loads(read_raw(Path(args.table)))
    if args.id:
        wanted = set(args.id)
        unknown = wanted - {m["id"] for m in table}
        if unknown:
            print("unknown --id: %s" % ", ".join(sorted(unknown)))
            return 2
        table = [m for m in table if m["id"] in wanted]

    if args.list:
        for m in table:
            print("%-24s %-12s %s" % (m["id"], ",".join(m["expect_red"]), m["file"]))
        return 0

    if not Path(args.godot).exists():
        print("godot not found: %s  (use --godot or set GODOT_BIN)" % args.godot)
        return 2

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    started = time.time()

    # 開跑前把會動到的檔案原文全部存起來，finally 一律寫回（見檔頭「刻意的取捨」）。
    originals = {}
    for m in table:
        p = ROOT / m["file"]
        if p.exists() and p not in originals:
            originals[p] = read_raw(p)

    baseline = {}   # group -> 是否綠（每組只跑一次，之後重用）
    rows = []       # (id, group, base, mut, verdict)
    detail = []     # 寫進報告檔的中文細節

    try:
        for m in table:
            for group in m["expect_red"]:
                if group not in baseline:
                    ok, out = run_smoke(args.godot, group)
                    baseline[group] = ok
                    if not ok:
                        detail.append("[PRERED] 組 %s 在未突變狀態就是紅的：\n    %s"
                                      % (group, "\n    ".join(fail_lines(out))))
                if not baseline[group]:
                    rows.append((m["id"], group, "RED", "-", "PRERED"))
                    continue

                err = apply_mutation(m)
                if err:
                    rows.append((m["id"], group, "green", "-", "BADPATCH"))
                    detail.append("[BADPATCH] %s：%s\n    find = %r"
                                  % (m["id"], err, m["find"]))
                    continue
                try:
                    ok, out = run_smoke(args.godot, group)
                finally:
                    write_raw(ROOT / m["file"], originals[ROOT / m["file"]])

                if ok:
                    rows.append((m["id"], group, "green", "green", "MISS"))
                    detail.append("[MISS] %s：把 %s 改成 %s 之後，組 %s 仍然全綠"
                                  " ← 這條稽核抓不到，要修的是稽核\n    %s"
                                  % (m["id"], m["find"], m["replace"], group,
                                     m.get("note", "")))
                else:
                    rows.append((m["id"], group, "green", "RED", "RED-OK"))
                    detail.append("[RED-OK] %s（%s）抓到了：\n    %s"
                                  % (m["id"], m.get("note", ""),
                                     "\n    ".join(fail_lines(out))))
    finally:
        for path, text in originals.items():
            write_raw(path, text)

    # 還原後再驗一次：確認檔案真的回到原狀（不然後面的稽核結果全部不可信）
    restore_ok = True
    for group in sorted(baseline):
        if not baseline[group]:
            continue
        ok, out = run_smoke(args.godot, group)
        if not ok:
            restore_ok = False
            detail.append("[RESTORE-FAIL] 還原後組 %s 竟然是紅的：\n    %s"
                          % (group, "\n    ".join(fail_lines(out))))

    print("")
    print("%-26s %-11s %-6s %-6s %s" % ("ID", "GROUP", "BASE", "MUT", "VERDICT"))
    print("-" * 68)
    for r in rows:
        print("%-26s %-11s %-6s %-6s %s" % r)
    tally = {}
    for r in rows:
        tally[r[4]] = tally.get(r[4], 0) + 1
    good = tally.get("RED-OK", 0) == len(rows) and restore_ok
    print("-" * 68)
    print("MUTATION-CHECK: %s | restore=%s | %.1fs -> %s"
          % (", ".join("%d %s" % (v, k) for k, v in sorted(tally.items())),
             "ok" if restore_ok else "FAIL",
             time.time() - started,
             "PASS" if good else "FAIL"))
    print("detail (UTF-8, 中文在這裡): %s" % REPORT)

    write_raw(REPORT, "\n\n".join(detail) + "\n")
    return 0 if good else 1


if __name__ == "__main__":
    sys.exit(main())
