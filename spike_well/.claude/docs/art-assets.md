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

**08-11（使用者從四種方案挑 C）：蟲洞的常駐金光升級成「方向性逆光」**。原本是均勻兩層描邊，讀起來像霓虹燈管；改成光源硬定在左上的四件套——背後暖色徑向光暈（`_draw_radial_bloom`）＋偏光側的四層漸層描邊（`WORMHOLE_GLOW_LAYERS`／`_BIAS_DIRS`）＋全向淡底邊＋最內層白熱邊（`C_WORMHOLE_HOT`）。常數全在 `spike_config.gd` SECTION 4c。⚠ 徑向光暈每圈的 alpha 是從「目標累積曲線」反推的，不是每圈給同一個值（固定 alpha 疊 N 圈中心會直接飽和成實心色塊，實測踩過）。

## 例外四（2026-08-10 續，使用者拍板）：`assets/sprites/pameloe1.png` / `pameloe2.png`

Pameloe 本體換成真實美術，兩張立繪按 80% / 20% 抽取（`PAMELOE_RARE_ART_CHANCE`，08-10 三訂由 10% 調到 20%）。來源檔名的拼法是 `pemaloe`，程式端一律沿用既有的 `PAMELOE` 拼法，不為了對齊檔名去改一整套識別字。

## 例外五（2026-08-10 續，使用者拍板）：`assets/sprites/pickup_coin.png` / `pickup_fuel.png`

金幣與燃料補給換成真實美術，另加沿 alpha 輪廓 +2px 的白光（共用 `WellWorld._draw_sprite_outline`）與上下漂浮。

⚠⚠ **這兩張的 art 尺寸基準跟前四條例外不同**：怪物那組是「art 畫布 ＝ 判定 ×2」，這組是「art 的 **alpha 內容** ＝ 判定 ×2」——來源圖四周有大片透明留白（coin 的 60 畫布裡只有 52 有東西），照畫布算會讓玩家看到的東西整整小一圈。抄前面那組會錯，推導與稽核見 `spike_config.gd` 的 `COIN_ART_SIZE` ⚠⚠ 與 `tests/audit_levels.gd` `_audit_pickup_art`。

**08-10 三訂（使用者拍板「大小 -50%」）**：來源 PNG 不換檔，改用 `PICKUP_ART_SCALE` 在畫的時候整體縮小，判定與 `PICKUP_HOVER` 跟著等比減半。細節見 [deviations.md](deviations.md)「物資（金幣／燃料）尺寸」列。

## 例外六（2026-08-10 續，使用者拍板）：`assets/sprites/platform_normal.png` / `platform_break.png` / `platform_jump.png` / `platform_move.png`

平台四態貼圖（一般 STATIC／碎裂 FRAGILE／彈射 LAUNCHER／移動 MOVING），`well_world._draw_platform`。⚠ 08-11 使用者拍板兩件事定案（原始版本 VERTICAL／CIRCULAR／EXPLOSIVE 三種都沿用 normal.png，已更正）：
- **會動的三種統一沿用 `platform_move.png`**：MOVING（左右）／VERTICAL（上下）／CIRCULAR（圓形）不另外做專用圖，靠 `WellPlatform.color()` 既有的 modulate 顏色分辨方向，這是刻意的，不是妥協。
- **EXPLOSIVE 沿用 `platform_normal.png`**，且未觸發（`fuse_timer < 0`）前跟 STATIC 拿一模一樣的底色（`C_PLATFORM`，不特別上色）——唯一的視覺差異是踩下去引信燒起來那段「越來越亮」（`C_PLATFORM`→`C_EXPLOSIVE_HOT` 內插）。

⚠⚠ 尺寸基準跟前面幾條例外都不同：不是量畫布也不是量單張圖各自的 alpha 內容，而是**統一取 `platform_normal.png` 的內容佔畫布比例**（寬 246/297≈0.8283、高 57/94≈0.6064）當基準，四張圖共用同一組比例換算縮放——同角色多姿勢共用同一比例，是這個專案既有的慣例。錨點是**頂部對齊**（貼圖矩形頂部貼齊碰撞箱頂部、水平置中），不是腳底錨點（那是給角色/怪物用的）也不是置中疊加——平台是被站的東西，它的「接觸面」就是碰撞箱頂緣。終點平台（`is_goal`）寬度＝整個井寬，例外改用 `_draw_platform_tiled` 手動迴圈貼磚鋪滿，不整張拉伸。⚠⚠ 不是 Godot 內建 `draw_texture_rect(tile=true)`——那個貼磚是照貼圖原生像素尺寸鋪、不會縮放配 rect，套視覺尺寸傳進去會整個爆版（磚塊比預期大好幾倍、往下溢出畫面），實測抓到才改手動迴圈。推導與稽核見 `well_world._draw_platform` 與 `spike_config.gd` SECTION 4「平台不再靠加寬」。

**08-11 追加兩項純視覺**（細節見 [deviations.md](deviations.md)「平台的純視覺回饋」列）：踩踏晃動、隨機上下／左右鏡像。⚠ 鏡像只套 `platform_normal.png` 那組；上下翻之所以安全，是因為這張圖的 alpha 內容幾乎垂直置中（bbox y 18~75 / 畫布 94，中心只差 0.5px）——**換這張素材要重新確認這件事**，不然翻完木板會跟碰撞箱錯開。

同一批把平台的 solo／起跳寬度倍率（`PLATFORM_WIDTH_MULT_SOLO`／`START_PLATFORM_WIDTH_MULT`）拿掉了——加寬會把貼圖拉伸變形，平台尺寸現在全面統一，solo 區間的安全性改由 `MONSTER_PATROL_RANGE_SOLO`／`SOLO_FOOTHOLD_MIN` 負責。

**08-11 修正（使用者回報「怪物／蟲洞／Kaela 跟木板之間有空隙」）**：查證怪物／蟲洞／Kaela
三顆腳底錨點常數跟目前真實 PNG 的 alpha bbox 底邊量測值完全吻合，不是它們的問題——根因在
平台：`normal.png` 畫布最上緣到木板本體（alpha 內容頂邊）之間有 18/94≈19% 留白，但
`draw_pos.y` 原本直接拿「畫布頂邊」貼碰撞箱頂緣，木板本體因此比碰撞箱頂緣低了一截。
改成扣掉這截留白（`well_world.PLATFORM_TEX_CONTENT_TOP_FRAC`），讓「木板本體頂邊」對齊
碰撞箱頂緣。四張圖共用同一顆比例（同 `CONTENT_FRAC_W`／`CANVAS_ASPECT` 的既有慣例）。
驗證：`anchor_check_monster.png`／`anchor_check_wormhole.png` 肉眼確認貼合、`smoke.tscn`
0 error。

## 例外七（2026-08-11，使用者拍板）：`assets/sprites/bg_backroom_tile.png`

0~500m 井背景，`well_world._draw_background`。使用者提供參考素材 `12.webp`（720×960，本身就是規律
排版的橄欖色人字紋，不是隨手拍的照片）；用 autocorrelation 量出基礎週期＝33×50px，從
`(300,400)` 裁下正好一個週期當 tile，6×6 貼磚 mosaic 放大 4 倍肉眼確認四邊無縫後才存檔——
沒有另外做偏移拼接／修補（來源本身已是規律圖案，不需要那道工序）。

500m 以上暫時維持原本純色 `C_BG`（`BG_TRANSITION_HEIGHT_M`，`spike_config.gd` SECTION 9d），
等使用者準備紅磚素材才會補第二段＋交界處理（目前規劃是 crossfade，不是硬切）。

⚠⚠ 這裡刻意用內建 `draw_texture_rect(tile=true)`，不是仿平台那組手動雙迴圈——平台當年
改手動迴圈是因為要把貼圖「縮放」成特定視覺尺寸，`tile=true` 只認原生像素尺寸鋪，兩者對不上
（見「平台貼圖與尺寸」條）。背景不縮放，原生像素就是目標視覺尺寸，這個情境反而是
`tile=true` 的正確用法。
⚠ `rect` 的 position／size 一定要整段固定在世界座標（這裡是 `[WELL_LEFT, WELL_RIGHT] ×
[start_y-band_h, start_y]`），不能用每幀變動的 `top`/`bot` 當 rect 起點——貼磚起點鎖在傳入的
`rect.position`，起點跟著相機每幀重算的話，圖案在畫面上會變成貼在螢幕頂端不動，而不是跟著
世界捲動。整段 500m 高的 rect 只定義一次，可視範圍外的部分由渲染器自然裁掉。
驗證：`visual_check.gd` 的 `bg_check_top/mid/beyond_500m.png` 三張（井頂邊界、中段無縫、
500m 後正確退回純色）。

**08-11 續（濾鏡）**：使用者反映貼圖太銳利、跟前景物件（木板、怪物）視覺上會打架，且想要
圖三參考照那種地下室潮濕朦朧感。列了 6 種濾鏡方向現場合成給使用者比對（模糊用「3×3 超貼
再裁中間」做無縫處理，不會在貼磚時看到接縫），使用者選 **D：中度模糊＋螢光黃綠色偏＋淡暗角**。
- **模糊＋色偏烤進 `bg_backroom_tile.png` 本體**（seamless_blur 1.8px → tint(214,206,150,22%)
  → 對比 ×0.85）：這兩項是「貼圖內容」，貼磚不受影響，可以直接改檔案。
- **暗角另外做成 `bg_vignette.png`**（512×512 徑向漸層，中心透明→邊緣暗，強度 0.35）疊圖，
  不能烤進會貼磚的 tile——暗角烤進 33×50 的小 tile 裡貼磚會變成每塊磚都暗一圈，讀起來像
  格子紋不像鏡頭暗角。這張改用 `tile=false`、每幀依目前可視範圍重新拉伸貼一次（screen-space），
  暗角中心才會跟著鏡頭走。見 `well_world._draw_background` 與 `BG_VIGNETTE_TEX_PATH` 的 ⚠。

## 字型（現況）

`assets/fonts/NotoSansCJKtc.otf`（原本 `NotoSansTC.ttf`）。使用者拍板（v17）：TC 版不含平假名／片假名，日文版會整頁豆腐。⚠ 子集只收「`.gd` 裡真的出現過的字」，換字型檔記得重跑 `tools/subset_font.py` ＋ `--import`（見 spike_well/CLAUDE.md「建置工具」）。
