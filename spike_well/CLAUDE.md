# CLAUDE.md — 爬井 spike

跨專案底線在全域 `~/.claude/CLAUDE.md`，**本檔不複製，只補這個 spike 專屬的條款**。

## 這是什麼

**2026-08-10 起定位轉正**：原本是拋棄式原型，現已籌備先發到 itch.io、會持續小更新——治理規則按「可能是第一份正式作品」對待，不再是「用完即丟」。
核心玩法：爬井（鍵盤移動、跳躍、射線鞭子、Raora 階梯干擾）。滑鼠拖曳仍是可切換的輸入模式
（`SpikeConfig.ACTIVE_INPUT_MODE`，未來觸控的地基），但目前預設＝鍵盤。
設計規格唯一的家：`../PILLARS_2.md`（P4 ＋ 逃脫結構）。進度唯一的家：`../HANDOFF.md`。
刻意偏離規格已全數確認、清楚代價，不重新調查——現行規則見 [.claude/docs/deviations.md](.claude/docs/deviations.md)。

## 硬規則

1. **所有可調數值一律進 `autoload/spike_config.gd`**，不准散落在其他檔。
2. **SSOT——同一份資訊只有一個家**：CLAUDE.md 只放規則綱要；細節資料表分散到
   `.claude/docs/*.md`，重複性操作流程做成 `.claude/skills/` 底下的 skill（按需加載，不占
   CLAUDE.md 篇幅）。要記的進度事寫回 `../HANDOFF.md`，別處只指向不複製。
3. **不手刻 .tscn**。節點一律程式建構，`Main.tscn` 永遠只有 3 行。
4. **placeholder 美術**：純色矩形 ＋ `_draw()`，不引入美術資源檔。已量產的例外清單唯一的家：
   [.claude/docs/art-assets.md](.claude/docs/art-assets.md)。新增／換素材走 skill `/import-art-asset`。
5. **按鍵不准出現字面值**（`KEY_A`、`KEY_SPACE`…），一律走 `SpikeKeys.key_of()` / `is_action_pressed()`。
   預設值住 `spike_config.gd` 的 `DEFAULT_KEYS`，設定頁改的是覆寫層。
6. 驗證 = headless import 0 error ＋ 實跑。`--headless --quit` 通過不等於玩得動。
   **這次改動該跑到哪一格**（改動類型 → 最小驗證集、各手段實測耗時、突變測試怎麼跑）唯一的
   家＝[.claude/docs/verification-matrix.md](.claude/docs/verification-matrix.md)。開發途中跑
   最小集、收工前跑一次全套。
7. **稽核必須走真實路徑**：邊玩邊生成／回收的東西，稽核要自己模擬那條路，不能只驗
   「生完看起來對不對」（見 `smoke.gd` 的 `_audit_streaming_wormholes`）。
8. **同一頁面內的殼位置固定，不隨分頁內容跳動**：這是遊戲 HUD 的一致性要求，不是網頁排版
   可以隨便的地方——玩家在同一頁面切分頁／切分類時，標題、分頁鈕列、底部按鈕這類「殼」
   元素必須釘在同一個像素位置，不能因為各分頁內容多寡不同就跟著整段上下跳，也不能有的
   分頁沒有殼（例如某個選項變成整頁跳轉、其他選項留在原頁）。做法：內容區包一個固定
   高度的容器（`custom_minimum_size.y` 訂在最高的那個分頁之上，矮的分頁下面留白），不要
   讓外層容器隨內容自適應高度；同一組選項要嘛全部是「切分頁」要嘛全部是「跳頁面」，
   不要混著來。實例見 `spike_ui.gd _build_settings_panel`（`SETTINGS_CONTENT_HEIGHT`）。

## 任務路由表

| 要做的事 | 先讀 |
|---|---|
| 改可調數值 | `autoload/spike_config.gd`，Grep 常數名，不逐檔翻 |
| 查現行規則跟 PILLARS_2.md 哪裡不一樣 | [.claude/docs/deviations.md](.claude/docs/deviations.md) |
| 查某個偏離為什麼這樣改 | [../HANDOFF_ARCHIVE.md](../HANDOFF_ARCHIVE.md)「偏離表沿革／理由存底」，Grep 項目名稱 |
| 新增／換角色貼圖 | skill `/import-art-asset`，完成後登記進 [.claude/docs/art-assets.md](.claude/docs/art-assets.md) |
| 新增／換音效 | skill `/import-sound-asset`，完成後登記進 [.claude/docs/audio-assets.md](.claude/docs/audio-assets.md) |
| 動任何系統前先確認有沒有踩過的坑 | [.claude/docs/evergreen.md](.claude/docs/evergreen.md)（常青認知唯一的家） |
| 決定這次改動要跑哪些驗證 | [.claude/docs/verification-matrix.md](.claude/docs/verification-matrix.md) |
| 新增稽核後做突變測試 | `python tools/mutation_check.py`（突變點加一列進 `tools/mutations.json`） |
| 接手 session | `../HANDOFF.md` |

## 建置工具

`tools/` 有 `.gdignore`，Godot 完全不看它，也不會進匯出包。
`tools/subset_font.py` 掃全部 `.gd` 的中文字，把 11.9MB 的完整 Noto Sans TC 子集成 ~300KB。
**改過任何中文文案後要重跑**，否則新字在 Web 版是豆腐方塊。
`tools/mutation_check.py` ＋ `tools/mutations.json`：突變測試批次驅動，一次呼叫驗完整張表
（自動改壞 → 跑 → 判紅 → 還原 → 驗回綠）。**新增稽核時加一列進表，不要手動改壞再改回**；
用法與「哪些突變點驗不出東西」見 [.claude/docs/verification-matrix.md](.claude/docs/verification-matrix.md)。
兩支都隨 repo 提供，不需另外安裝（只依賴系統 Python ＋ Godot 執行檔）。

## 執行方式

```
C:/Users/gnt0233/Downloads/Godot_v4.6.1-stable_win64.exe --path <spike_well 絕對路徑>
```

跑正式數值前確認 `spike_config.gd` 的 `ACTIVE_PRESET` 是 `Preset.SPEC`（不是測試用的其他 preset）。

**回歸測試**（七組稽核 ＋ headless bot 4 局；各組項數以實跑輸出為準）。
**實測全套只要 4~8 秒**（2026-08-14），別再以為它貴到需要跳過收尾那一次：

```
C:/Users/gnt0233/Downloads/Godot_v4.6.1-stable_win64_console.exe --headless --path <spike_well 絕對路徑> res://smoke.tscn
```

開發途中只跑相關那組（約 2 秒、輸出 3~10 行）；組名用 `-- --list` 看，打錯組名會 exit 2：

```
C:/Users/gnt0233/Downloads/Godot_v4.6.1-stable_win64_console.exe --headless --path <spike_well 絕對路徑> res://smoke.tscn -- --only=mechanics
```

⚠ **輸出一律導檔、只讀 `[SMOKE]` 與 `!!` 行**（全套 97 行裡有 90 行對「確認沒壞」零資訊量，
卻會永久佔住 context）。哪種改動配哪一格驗證：見上面硬規則 6 指的那張表。

- ⚠ Windows console 是 cp950，中文必亂碼但**資料本身正常**——導進檔案再讀回來驗，別重跑追亂碼。
- ⚠ 目視版面用**不加 `--headless` 跑 `res://visual_check.tscn`**（headless 下畫面是空白）；
  數字算得到的版面優先寫成稽核斷言。做法見 skill `/import-art-asset`。
- ⚠ Win32 合成滑鼠點擊戳遊戲視窗**行不通**（hover 會亮但按鈕不觸發），別再花時間在那條路上。
- ⚠ 換字型檔要多跑一次 `Godot ... --headless --path <spike_well> --import`，否則
  `ResourceLoader.exists()` 會是 false、UI 靜默退回 SystemFont。

**動態錄影驗證**（驗「動起來對不對」：移動中的姿勢切換、特效接線、干擾演出、死亡動畫）：

```
C:/Users/gnt0233/Downloads/Godot_v4.6.1-stable_win64_console.exe --path <spike_well 絕對路徑> res://record.tscn --write-movie tools/out/rec/frame.png --fixed-fps 60 -- --secs=20
```

- ⚠⚠ **一定不能加 `--headless`**（同 visual_check 那個坑：會寫出一整批空白 PNG）。
- 井是**固定 seed**（`record.gd` 的 `DEFAULT_SEED`）＝每次同一座井，兩次錄影可逐格比對；
  改那個常數等於換井，舊錄影就不能拿來比了。`-- --seed=1234` 可臨時指定別的井。
- 輸出 `tools/out/rec/frame*.png`（不進版控）。事後挑頭／中／尾幾張回讀即可，別整批看。
- ⚠ 干擾 67s 才登場，預設 20 秒錄影**看不到任何干擾** → 要驗干擾演出得加 `-- --stress`。
- ⚠ 錄的是 `WellWorld` 本身、**不含 HUD／UI 層**（未接 main.gd 流程）。UI 版面走
  `visual_check.tscn` ＋ `tests/audit_ui.gd`。
- ⚠ Movie Maker 會順手產一個沒用的 `frame.wav`（本專案零音效系統），可直接刪。
- 編碼成本約 190ms/格：20 秒錄影（1200 格）要跑約 4 分鐘，不是即時的。

**怎麼讀這三個大檔（省 token）**——三個都有檔頭索引，讀索引再定位，別整檔讀
（讀進 context 的東西之後**每一次**工具呼叫都重付一次那個字數）：
- 改參數：讀 `spike_config.gd` 檔頭索引（前 45 行）→ `Grep "SECTION 4b —"` → `Read` 帶
  offset/limit。索引刻意不寫行號（行號一改就過期，過期的索引比沒有更糟）。
- 改遊戲層邏輯／繪製：讀 `src/well_world.gd` 檔頭索引 → Grep 段落標題（如 `^# 主迴圈`）或
  函式名（`func _draw_<東西>`）→ Read 帶 offset/limit。全檔 3400 行，近一半是 `_draw_*`。
- 改稽核：讀 `smoke.gd` 檔頭索引 → 開對應的 `tests/*.gd` → Grep 函式名。
