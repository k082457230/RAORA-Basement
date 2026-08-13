"""量測角色貼圖的「腳底錨點比例」，取代人工拿尺量的流程。

為什麼要做：`import-art-asset` skill 第 4 步要求同一角色的多張姿勢貼圖共用同一個
腳底錨點（alpha bbox 底邊 / 畫布高度），寫進 `autoload/spike_config.gd` 當常數
（如 KAELA_FEET_ANCHOR_FRAC）。人工拿圖片編輯器量這個比例容易手滑，08-10 就因為
量錯／量錯基準檔（原始檔而非縮圖後的檔）讓怪物與蟲洞貼圖沉進平台。這支腳本把
量測本身自動化：算 alpha bbox、驗證多姿勢畫布尺寸一致、印出可以直接貼進
spike_config.gd 的常數行。

⚠ 量測基準一定要用「縮圖之後」實際會被 `load()` 的檔案（即 assets/sprites/ 底下
那份），不要拿 AI 原始輸出檔量——縮放取整有 1~2px 誤差，兩者對不齊。

用法（專案根目錄或任意位置皆可執行）：
    python spike_well/tools/measure_anchor.py assets/sprites/kaela_steady.png
    python spike_well/tools/measure_anchor.py assets/sprites/kaela_*.png --anchor assets/sprites/kaela_steady.png --const-name KAELA_FEET_ANCHOR_FRAC
    python spike_well/tools/measure_anchor.py assets/sprites  # 整個目錄

多檔案時只確認同一次呼叫傳進來的畫布尺寸是否完全一致；不同角色請分開跑。
"""

from __future__ import annotations

import argparse
import glob as globmod
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow (PIL) is not installed. Run: pip install Pillow")
    sys.exit(1)


def resolve_inputs(args: list[str]) -> list[Path]:
    """把 CLI 參數（檔案 / glob / 目錄）展開成實際 PNG 檔案清單，保留順序、去重。"""
    resolved: list[Path] = []
    seen: set[Path] = set()

    for raw in args:
        candidates: list[Path] = []
        p = Path(raw)

        if p.is_dir():
            candidates = sorted(p.glob("*.png"))
        elif any(ch in raw for ch in "*?["):
            candidates = [Path(m) for m in sorted(globmod.glob(raw))]
        elif p.exists():
            candidates = [p]
        else:
            print(f"ERROR: path not found: {raw}")
            sys.exit(1)

        if not candidates:
            print(f"ERROR: no PNG files matched: {raw}")
            sys.exit(1)

        for c in candidates:
            if c.suffix.lower() != ".png":
                continue
            resolved_path = c.resolve()
            if resolved_path not in seen:
                seen.add(resolved_path)
                resolved.append(c)

    if not resolved:
        print("ERROR: no PNG files resolved from arguments.")
        sys.exit(1)

    return resolved


class Measurement:
    def __init__(self, path: Path, size: tuple[int, int], bbox, feet_frac, alpha_note: str):
        self.path = path
        self.size = size          # (width, height)
        self.bbox = bbox          # (left, top, right, bottom) or None
        self.feet_frac = feet_frac  # float or None
        self.alpha_note = alpha_note


def measure_file(path: Path) -> Measurement:
    """算單張圖的畫布尺寸、alpha bbox、腳底錨點比例。"""
    img = Image.open(path)
    width, height = img.size

    alpha_note = ""
    if img.mode != "RGBA":
        # 沒有 alpha channel 的圖轉成 RGBA 後視為全不透明（bbox = 整張畫布）。
        alpha_note = f"no alpha channel (mode={img.mode}), treated as fully opaque"
        img = img.convert("RGBA")

    alpha = img.split()[-1]
    bbox = alpha.getbbox()  # (left, top, right, bottom), right/bottom 為 exclusive

    if bbox is None:
        # 邊界情況：完全透明的圖，不能除以零或亂算一個比例出來。
        return Measurement(path, (width, height), None, None, "fully transparent image, no visible pixels")

    _, _, _, bottom = bbox
    feet_frac = bottom / height if height > 0 else 0.0

    return Measurement(path, (width, height), bbox, feet_frac, alpha_note)


def derive_const_name(anchor_path: Path) -> str:
    """從檔名猜一個常數名，僅供起手參考——最終命名由使用者確認/修改。"""
    stem = anchor_path.stem
    # 去掉常見的姿勢後綴，取角色本體當前綴（猜測用，不保證正確）。
    for suffix in ("_steady", "_idle", "_stand", "_jump", "_jetpack"):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    return f"{stem.upper()}_FEET_ANCHOR_FRAC"


ANCHOR_HINTS = ("steady", "idle", "stand", "platform")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Measure feet-anchor fraction (alpha bbox bottom / canvas height) for character sprites."
    )
    parser.add_argument("paths", nargs="+", help="PNG file(s), glob pattern(s), or directory(ies).")
    parser.add_argument(
        "--anchor",
        default=None,
        help="Which file's feet_frac becomes the printed const value (path or basename). "
        "Defaults to the first resolved file if omitted.",
    )
    parser.add_argument(
        "--const-name",
        default=None,
        help="GDScript const name to print. Defaults to a filename-derived guess "
        "(edit it before pasting into spike_config.gd).",
    )
    args = parser.parse_args()

    files = resolve_inputs(args.paths)

    measurements: list[Measurement] = []
    for f in files:
        try:
            measurements.append(measure_file(f))
        except Exception as exc:  # noqa: BLE001 - report and continue so one bad file doesn't kill a batch
            print(f"ERROR: failed to read {f}: {exc}")
            sys.exit(1)

    print("=" * 70)
    print(f"Measured {len(measurements)} file(s):")
    print("=" * 70)
    for m in measurements:
        w, h = m.size
        hint = " <- likely anchor pose (stands on platform)" if any(
            key in m.path.name.lower() for key in ANCHOR_HINTS
        ) else ""
        print(f"file       : {m.path}{hint}")
        print(f"canvas     : {w} x {h}")
        if m.bbox is None:
            print(f"alpha bbox : NONE ({m.alpha_note})")
            print("feet_frac  : N/A")
        else:
            left, top, right, bottom = m.bbox
            note = f"  ({m.alpha_note})" if m.alpha_note else ""
            print(f"alpha bbox : left={left} top={top} right={right} bottom={bottom}{note}")
            print(f"feet_frac  : {m.feet_frac:.6f}  ({bottom}.0 / {h}.0)")
        print("-" * 70)

    # ----- 一致性檢查（SKILL.md 硬要求，不是建議）：同一次呼叫的畫布尺寸必須完全一致 -----
    distinct_sizes = {m.size for m in measurements}
    if len(distinct_sizes) > 1:
        print("CONSISTENCY CHECK: FAIL")
        print("Canvas sizes differ across the files passed in this run:")
        for m in measurements:
            print(f"  {m.size[0]} x {m.size[1]}  <- {m.path.name}")
        print("Fix the resize step (same character must share one canvas size) before")
        print("trusting any feet_frac value below. Refusing to print a const line.")
        sys.exit(1)

    if len(measurements) > 1:
        print("CONSISTENCY CHECK: PASS (all canvas sizes identical)")

    # ----- 決定用哪一張當基準 -----
    valid = [m for m in measurements if m.feet_frac is not None]
    if not valid:
        print("ERROR: every input image is fully transparent; nothing to measure.")
        sys.exit(1)

    if args.anchor:
        anchor_arg = Path(args.anchor)
        chosen = None
        for m in valid:
            if m.path == anchor_arg or m.path.name == anchor_arg.name or m.path.resolve() == anchor_arg.resolve():
                chosen = m
                break
        if chosen is None:
            print(f"ERROR: --anchor {args.anchor!r} did not match any measured file.")
            sys.exit(1)
    else:
        chosen = valid[0]

    const_name = args.const_name or derive_const_name(chosen.path)

    print("=" * 70)
    print(f"ANCHOR SOURCE : {chosen.path}")
    if not args.anchor:
        print("              (defaulted to first argument - pass --anchor <file> to pick")
        print("               the pose that MUST fit the platform precisely, per SKILL.md step 4)")
    print(f"const {const_name} := {chosen.bbox[3]}.0 / {chosen.size[1]}.0   # = {chosen.feet_frac:.6f}, measured from {chosen.path.name}")
    print("=" * 70)
    if len(measurements) > 1:
        others = [m.path.name for m in measurements if m.path != chosen.path]
        print(f"Other pose(s) reuse this same fraction (do NOT re-measure them): {', '.join(others)}")


if __name__ == "__main__":
    main()
