#!/usr/bin/env python3
"""itch.io Web (HTML5) 上架前檢查 -- 對照 checklist.md §2.1。

只依賴標準函式庫。用法：
    python tools/check_web_zip.py <zip 路徑>

逐條印 PASS / FAIL + 實際數值；只要有一條 FAIL，結束時 exit code = 1。
"""

import os
import re
import sys
import zipfile

MAX_FILES = 1000
MAX_TOTAL_BYTES = 500 * 1024 * 1024
MAX_SINGLE_FILE_BYTES = 200 * 1024 * 1024
MAX_PATH_LEN = 240

# 掃 html/js 內容找絕對路徑引用：src="/..."、href="/..."、fetch("/...")
# 排除 "//" 開頭的 protocol-relative URL、data: URI。
ABS_PATH_RE = re.compile(
    r"""(?:\b(?:src|href)\s*=\s*|fetch\s*\(\s*|import\s*\(\s*)
        ["'](?P<path>/(?!/)[^"']*)["']""",
    re.VERBOSE,
)

# 從 html/js 內容裡抓「看起來像本地資源檔名」的相對引用，用來做大小寫比對。
# 抓 src=/href=/fetch(/含常見副檔名的字串。
ASSET_REF_RE = re.compile(
    r"""["'](?P<ref>(?:\./|\.\./)?[A-Za-z0-9_./-]+\.
        (?:html|js|wasm|pck|png|jpg|jpeg|json|css|worklet\.js|ico|svg))["']""",
    re.VERBOSE,
)

SCANNABLE_EXTS = (".html", ".js")


def fail(msg):
    print(f"  FAIL - {msg}")
    return False


def ok(msg):
    print(f"  PASS - {msg}")
    return True


def check_extension(zip_path):
    print("[1] 副檔名是 .zip")
    if zip_path.lower().endswith(".zip"):
        return ok(f"{zip_path}")
    return fail(f"副檔名不是 .zip：{zip_path}")


def check_index_at_root(names):
    print("[2] index.html 在 zip 根目錄")
    candidates = [n for n in names if n.split("/")[-1] == "index.html" and not n.endswith("/")]
    root_hit = "index.html" in names
    if root_hit:
        return ok("index.html 存在於根目錄")
    if candidates:
        return fail(f"index.html 存在但不在根目錄：{candidates}")
    return fail("zip 內找不到 index.html")


def check_file_count(infos):
    print("[3] 解壓後檔案數 <= 1000")
    files = [i for i in infos if not i.filename.endswith("/")]
    n = len(files)
    if n <= MAX_FILES:
        return ok(f"{n} 個檔案")
    return fail(f"{n} 個檔案，超過上限 {MAX_FILES}")


def check_sizes(infos):
    print("[4] 解壓後總容量 <= 500MB、單一檔案 <= 200MB")
    files = [i for i in infos if not i.filename.endswith("/")]
    total = sum(i.file_size for i in files)
    biggest = max(files, key=lambda i: i.file_size) if files else None
    total_mb = total / (1024 * 1024)
    passed = True
    if total <= MAX_TOTAL_BYTES:
        ok(f"總容量 {total_mb:.2f} MB")
    else:
        passed = fail(f"總容量 {total_mb:.2f} MB，超過上限 500 MB")
    if biggest is not None:
        big_mb = biggest.file_size / (1024 * 1024)
        if biggest.file_size <= MAX_SINGLE_FILE_BYTES:
            ok(f"最大單一檔案 {biggest.filename} = {big_mb:.2f} MB")
        else:
            passed = fail(f"最大單一檔案 {biggest.filename} = {big_mb:.2f} MB，超過上限 200 MB")
    return passed


def check_path_length(names):
    print("[5] 含路徑的檔名長度 <= 240 字元")
    too_long = [(n, len(n)) for n in names if len(n) > MAX_PATH_LEN]
    if not too_long:
        longest = max(names, key=len) if names else ""
        return ok(f"最長 {len(longest)} 字元（{longest}）")
    for n, l in too_long:
        print(f"    - {l} 字元：{n}")
    return fail(f"{len(too_long)} 個檔名超過 {MAX_PATH_LEN} 字元")


def check_utf8_filenames(infos):
    print("[6] 檔名使用 UTF-8 編碼")
    suspicious = []
    for i in infos:
        has_non_ascii = any(ord(c) > 127 for c in i.filename)
        utf8_flag = bool(i.flag_bits & 0x800)
        if has_non_ascii and not utf8_flag:
            suspicious.append(i.filename)
        # 保險起見再驗一次能不能無誤地編碼成 UTF-8
        try:
            i.filename.encode("utf-8")
        except UnicodeEncodeError:
            suspicious.append(i.filename)
    if not suspicious:
        return ok("全部檔名可正常以 UTF-8 編碼／解碼")
    for n in suspicious:
        print(f"    - 疑似非 UTF-8 檔名：{n!r}")
    return fail(f"{len(suspicious)} 個檔名疑似非 UTF-8（可能是 cp437 亂碼）")


def _read_text(zf, name):
    try:
        raw = zf.read(name)
    except KeyError:
        return None
    return raw.decode("utf-8", errors="replace")


def check_absolute_paths(zf, names):
    print("[7] 資源引用不可用 / 開頭的絕對路徑")
    hits = []
    for n in names:
        if not n.lower().endswith(SCANNABLE_EXTS):
            continue
        text = _read_text(zf, n)
        if text is None:
            continue
        for m in ABS_PATH_RE.finditer(text):
            hits.append((n, m.group("path")))
    if not hits:
        return ok(f"掃了 {sum(1 for n in names if n.lower().endswith(SCANNABLE_EXTS))} 個 html/js 檔，沒有 / 開頭的絕對路徑引用")
    for n, p in hits:
        print(f"    - {n} 內發現絕對路徑引用：{p}")
    return fail(f"{len(hits)} 處絕對路徑引用（會在 itch.io CDN 子目錄下 404）")


def check_case_consistency(zf, names):
    print("[8] 檔名大小寫一致性（zip 內檔名 vs. html/js 內的引用）")
    name_set = set(names)
    lower_map = {}
    for n in names:
        lower_map.setdefault(n.lower(), []).append(n)

    mismatches = []
    checked_refs = 0
    for n in names:
        if not n.lower().endswith(SCANNABLE_EXTS):
            continue
        text = _read_text(zf, n)
        if text is None:
            continue
        base_dir = n.rsplit("/", 1)[0] + "/" if "/" in n else ""
        for m in ASSET_REF_RE.finditer(text):
            ref = m.group("ref")
            if ref.startswith(("http://", "https://", "//")):
                continue
            ref_norm = ref.lstrip("./")
            # 嘗試對照：先看是不是根目錄檔名，再看是不是同目錄相對檔名
            candidates_exact = {ref_norm, base_dir + ref_norm}
            checked_refs += 1
            if candidates_exact & name_set:
                continue  # 精確匹配到，大小寫沒問題
            # 精確沒中，看看是不是「忽略大小寫」能中
            found_ci = None
            for cand in candidates_exact:
                hits = lower_map.get(cand.lower())
                if hits:
                    found_ci = (cand, hits)
                    break
            if found_ci:
                mismatches.append((n, ref, found_ci[1]))
    if not mismatches:
        return ok(f"比對了 {checked_refs} 處資源引用，大小寫均一致（或未在 zip 內找到對應項可比對）")
    for src, ref, actual in mismatches:
        print(f"    - {src} 引用 {ref!r}，zip 內實際檔名為 {actual}（大小寫不符）")
    return fail(f"{len(mismatches)} 處檔名大小寫不一致")


def main():
    if len(sys.argv) != 2:
        print(f"用法：python {sys.argv[0]} <zip 路徑>")
        return 2
    zip_path = sys.argv[1]

    results = []
    results.append(check_extension(zip_path))

    if not os.path.isfile(zip_path):
        print(f"  FAIL - 檔案不存在：{zip_path}")
        return 1

    if not zipfile.is_zipfile(zip_path):
        print("  FAIL - 不是有效的 zip 檔")
        return 1

    with zipfile.ZipFile(zip_path, "r") as zf:
        infos = zf.infolist()
        names = zf.namelist()

        results.append(check_index_at_root(names))
        results.append(check_file_count(infos))
        results.append(check_sizes(infos))
        results.append(check_path_length(names))
        results.append(check_utf8_filenames(infos))
        results.append(check_absolute_paths(zf, names))
        results.append(check_case_consistency(zf, names))

    print()
    if all(results):
        print(f"總結：全部 {len(results)} 條 PASS")
        return 0
    n_fail = sum(1 for r in results if not r)
    print(f"總結：{len(results)} 條中有 {n_fail} 條 FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
