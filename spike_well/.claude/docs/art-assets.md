# 美術資產現況（placeholder 原則的例外清單）

硬規則：spike 預設 placeholder 美術（純色矩形 ＋ `_draw()`），不引入美術資源檔。
以下例外**只開放給已經量產出來、使用者確認要接的貼圖**，不是「以後想加什麼美術都可以直接加」——新素材要不要比照辦理，還是回去問使用者。
新增素材照這裡的模式走，SOP 見 skill `/import-art-asset`。

## 例外一：`assets/fonts/NotoSansTC.ttf`（OFL 授權）

Web 匯出讀不到系統字型，`SystemFont` 會 fallback 到不含 CJK 的內建字型 ⇒ 整頁豆腐方塊。這不是美術決定，是相容性。
（2026-08-10 起已升級成 `NotoSansCJKtc.otf`，見下方「字型」條。）

## 例外二（2026-08-09，使用者拍板）：`assets/sprites/kaela_*.png`

玩家正式美術提早試接進 spike（`well_world._draw_player_sprite`），不等正式版。理由：使用者要邊看邊調手感與尺寸，不想等到正式版才第一次看到玩家長什麼樣子。

## 例外三（2026-08-10，使用者拍板）：`assets/sprites/monster_chattini.png` / `wormhole_the_sheep.png` / `projectile_cucumber.png`

怪物、蟲洞、投擲物三種 `_draw()` 換成真實美術，流程與例外二相同。

## 例外四（2026-08-10 續，使用者拍板）：`assets/sprites/pameloe1.png` / `pameloe2.png`

Pameloe 本體換成真實美術，兩張立繪按 80% / 20% 抽取（`PAMELOE_RARE_ART_CHANCE`，08-10 三訂由 10% 調到 20%）。來源檔名的拼法是 `pemaloe`，程式端一律沿用既有的 `PAMELOE` 拼法，不為了對齊檔名去改一整套識別字。

## 例外五（2026-08-10 續，使用者拍板）：`assets/sprites/pickup_coin.png` / `pickup_fuel.png`

金幣與燃料補給換成真實美術，另加沿 alpha 輪廓 +2px 的白光（共用 `WellWorld._draw_sprite_outline`）與上下漂浮。

⚠⚠ **這兩張的 art 尺寸基準跟前四條例外不同**：怪物那組是「art 畫布 ＝ 判定 ×2」，這組是「art 的 **alpha 內容** ＝ 判定 ×2」——來源圖四周有大片透明留白（coin 的 60 畫布裡只有 52 有東西），照畫布算會讓玩家看到的東西整整小一圈。抄前面那組會錯，推導與稽核見 `spike_config.gd` 的 `COIN_ART_SIZE` ⚠⚠ 與 `tests/audit_levels.gd` `_audit_pickup_art`。

**08-10 三訂（使用者拍板「大小 -50%」）**：來源 PNG 不換檔，改用 `PICKUP_ART_SCALE` 在畫的時候整體縮小，判定與 `PICKUP_HOVER` 跟著等比減半。細節見 [deviations.md](deviations.md)「物資（金幣／燃料）尺寸」列。

## 字型（現況）

`assets/fonts/NotoSansCJKtc.otf`（原本 `NotoSansTC.ttf`）。使用者拍板（v17）：TC 版不含平假名／片假名，日文版會整頁豆腐。⚠ 子集只收「`.gd` 裡真的出現過的字」，換字型檔記得重跑 `tools/subset_font.py` ＋ `--import`（見 spike_well/CLAUDE.md「建置工具」）。
