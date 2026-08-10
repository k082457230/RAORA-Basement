# CLAUDE.md — 爬井 spike

跨專案底線在全域 `~/.claude/CLAUDE.md`，**本檔不複製，只補這個 spike 專屬的條款**。

## 這是什麼

**2026-08-10 起定位轉正**：原本是拋棄式原型，現已籌備先發到 itch.io、會持續小更新——治理規則按「可能是第一份正式作品」對待，不再是「用完即丟」。
核心玩法：爬井（滑鼠拖曳移動、跳躍、射線鞭子、Raora 階梯干擾）。
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
7. **稽核必須走真實路徑**：邊玩邊生成／回收的東西，稽核要自己模擬那條路，不能只驗
   「生完看起來對不對」（見 `smoke.gd` 的 `_audit_streaming_wormholes`）。

## 任務路由表

| 要做的事 | 先讀 |
|---|---|
| 改可調數值 | `autoload/spike_config.gd`，Grep 常數名，不逐檔翻 |
| 查現行規則跟 PILLARS_2.md 哪裡不一樣 | [.claude/docs/deviations.md](.claude/docs/deviations.md) |
| 查某個偏離為什麼這樣改 | [../HANDOFF_ARCHIVE.md](../HANDOFF_ARCHIVE.md)「偏離表沿革／理由存底」，Grep 項目名稱 |
| 新增／換角色貼圖 | skill `/import-art-asset`，完成後登記進 [.claude/docs/art-assets.md](.claude/docs/art-assets.md) |
| 接手 session | `../HANDOFF.md` |

## 建置工具

`tools/` 有 `.gdignore`，Godot 完全不看它，也不會進匯出包。
`tools/subset_font.py` 掃全部 `.gd` 的中文字，把 11.9MB 的完整 Noto Sans TC 子集成 ~300KB。
**改過任何中文文案後要重跑**，否則新字在 Web 版是豆腐方塊。

## 執行方式

```
C:/Users/gnt0233/Downloads/Godot_v4.6.1-stable_win64.exe --path <spike_well 絕對路徑>
```

跑正式數值前確認 `spike_config.gd` 的 `ACTIVE_PRESET` 是 `Preset.SPEC`（不是測試用的其他 preset）。
