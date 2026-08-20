# 美術資產現況（placeholder 原則的例外清單）

硬規則：spike 預設 placeholder 美術（純色矩形 ＋ `_draw()`），不引入美術資源檔。
以下例外**只開放給已經量產出來、使用者確認要接的貼圖**，不是「以後想加什麼美術都可以直接加」——新素材要不要比照辦理，還是回去問使用者。
新增素材照這裡的模式走，SOP 見 skill `/import-art-asset`。

## 索引（查東西先讀這張，不要整檔讀）

⚠ **尺寸基準每組都不一樣，「抄隔壁那組」是這份文件最常見的錯**——動手前先確認自己那一列。

| 素材 | 掛點 | 尺寸基準／錨點 | 詳情 |
|---|---|---|---|
| `kaela_*.png`（3 姿勢） | `well_world._draw_player_sprite` | 判定 ×2、腳底錨點 | 例外二 |
| `monster_chattini.png` | 怪物 `_draw` | 判定 ×2、腳底錨點 | 例外三 |
| `wormhole_the_sheep.png` | 蟲洞 | 判定 ×2、腳底錨點 ＋ 方向性逆光四件套 | 例外三 |
| `projectile_cucumber.png` | 投擲物 | 判定 ×2 | 例外三 |
| `pameloe1/2.png` | Pameloe（懸浮，80/20 抽） | **中心對齊**——它沒有腳底 | 例外四 |
| `pickup_coin/fuel.png` | 物資 | **alpha 內容** ×2（**不是畫布**）＋ `PICKUP_ART_SCALE` 減半 | 例外五 |
| `platform_normal/break/jump/move.png` | `_draw_platform` | 四張共用 `normal.png` 的內容佔畫布比例、**頂部對齊** | 例外六 |
| `bg_backroom_tile.png` | `_draw_background` | 原生像素＝目標視覺尺寸，`tile=true` | 例外七 |
| `bg_vignette.png` | `_draw_background` | screen-space 每幀拉伸，`tile=false` | 例外七 |
| `buff_*.png`（7 種，含 08-19 補的 petrify） | 世界 orb ＋ HUD 格子（**共用同一份檔**） | `BUFF_ORB_ART_SIZE` 56 ／ HUD 格 48 | 例外八 |
| `icon_*.png`（4 顆） | HUD 格子 ＋ 主頁右上 toggle ＋ 破關解鎖蒙版（**UI-only**，手套／懷錶兩顆） | HUD 格 48 ／ `TOGGLE_ICON_SIZE` 56 ／ `UNLOCK_ICON_SIZE` 132（內縮 `UNLOCK_ICON_ART_PAD` 24） | 例外八 |
| `pickup_loot_bag.png` | `_draw_loot_bag` | 判定 ×2（32） | 例外八 |
| `monster_pebbles1/2/3.png` | 怪物變體（80/10/10） | `MONSTER_ART_SIZE` 67×84 鎖高；**自己的**腳底錨點，不共用 chattini 的 | 例外八 |
| `doom1/2/3.png` | 黑洞三張輪播 | `DOOM_ART_SIZE` 474×313，**中心對齊**（無腳底）；核心 alpha 直徑對齊 `DOOM_RADIUS*2` | 例外九 |
| `pickup_loot_bag.png`（來源 08-17 版 tcg.png） | `_draw_loot_bag` | 60×60 直接縮到 32×32，同例外八既有做法 | 例外九 |
| `tail1/2/3.png` | 甩尾三變體（80/10/10） | 鎖寬 1100（＝井寬，伸長滿格時貼齊對牆）；**出手端錨點**（貼圖右緣＝根部，非置中／腳底） | 例外十 |
| `story_intro_1/2/3/4.png` | 開場漫畫，`SpikeUI.show_story_intro` | 原生 2560×1440＝目標視覺尺寸（同背景磚慣例）；四張**互不重疊**的同畫布透明遮罩，不是四張獨立小圖 | 例外十一 |
| `death_explosion_sheet.png` | 死亡演出，`well_world._draw_death_fx` | `DEATH_EXPLOSION_ART_SIZE` 240×240，**中心對齊**（無腳底）；8×5＝40 格 sprite sheet | 例外十二 |
| `qr_itchio/twitter/youtube.png` | 設定頁工作人員名單分頁，`SpikeUI._build_contact_qr_row` | `QR_DISPLAY_SIZE` 96×96，原生 148~164px 方形，UI-only、三顆各自獨立（非全有全無） | 例外十三 |
| `bg_title.png` | 主頁（`SpikeUI._build_start_panel`）滿版背景 | 原生 2560×1440＝目標視覺尺寸（同 `story_intro_*` 慣例），`STRETCH_KEEP_ASPECT_COVERED` ＋ `EXPAND_IGNORE_SIZE`，UI-only | 例外十四 |
| `NotoSansCJKtc.otf` | `SpikeUI.FONT_PATH` | — | 字型 |

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

## 例外八（2026-08-14，使用者拍板）：`assets/sprites/{buff_*, icon_*, pickup_loot_bag, monster_pebbles*}.png`

一次補 14 張，涵蓋四種各自獨立的掛點：

- **六種增益球**（`buff_random/stone/shield/pizza/time/coingun.png`，來源 128×128 縮到
  112×112，Lanczos）：世界飄的那顆 orb（`WellWorld._draw_buff_orbs`，`BUFF_ORB_ART_SIZE`
  56×56）＋左下角 HUD 格子（`spike_ui.gd` `_buff_rows`，`HUD_CELL_SIZE` 48×48）**共用同一份
  來源檔**，兩處各自用 `draw_texture_rect`／`HudCell.set_icon` 縮到各自的目標尺寸，不必為
  每個顯示尺寸另存一份檔案（Godot 的 mipmap+linear filter 縮小夠乾淨）。
  `"dahlah"` 已退出抽池（見 deviations.md／HANDOFF），沒有配圖的必要。
  ⚠⚠ **08-19 補上 `"petrify"` 時發現 `"stone"` 原本的來源檔配錯**：`"stone"`（石頭藥水，
  desc＝「每次踩上踏板的聲音改變」）當初其實用了 `"petrify"`（石化藥水，desc＝「Kaela
  開始旋轉」）的圖（來源檔 `woohoo.PNG`，醒石圖樣），`"petrify"` 反而一直空著用純色
  placeholder。已更正：`buff_stone.png` 換成正確來源 `biboo_water.PNG`（Downloads/素材，
  128×128→112×112 Lanczos），新增 `buff_petrify.png`（來源 `woohoo.PNG`，同規格）並補進
  `BUFF_TEX_PATHS`（`well_world.gd`）／`BUFF_ICON_PATHS`（`spike_ui.gd`）兩份 key-value。
  兩處都是泛用 `for key in dict` 迭代載入，加 key 不用改載入邏輯。`visual_check.tscn` 的
  `buff_intro_check_layout.png`（世界 orb）與 `hud_check_bottom_left.png`（HUD 格，臨時把
  `grant_buff("pizza")` 換成 `("petrify")` 驗完後改回原樣）都截圖肉眼確認過兩張新圖無 OOB、
  無破圖。**換來源檔後 buff 名稱與角色圖案的對應關係會影響玩家觀感，之後若再拿到同一批
  「XX_water」系列素材，先核對 desc 文字再決定接哪個 key，不要只憑檔名字面猜。**
- **四顆 HUD-only 道具 icon**（`icon_glove/jetpack/pocketwatch/whip.png`，同樣 128→112）：
  左下角格子（手套／噴射／懷錶／鞭子）；手套與懷錶**另外**還接到主頁右上角的 toggle
  （`TOGGLE_ICON_SIZE` 56×56，`_make_toggle_icon` 新增 `icon_tex` 選填參數）。這四顆從來
  沒有世界貼圖——手套／懷錶是商店解鎖的被動裝備，鞭子／噴射也只有 HUD 表示，不是撿到的
  東西，所以只接 UI 層，不用管腳底錨點。
  **08-20 追加第三個掛點**：破關解鎖蒙版（`SpikeUI.show_unlock`）中央那顆圓框 icon，
  手套／懷錶跟 HUD／toggle 共用同一份來源檔（`UNLOCK_ICON_PATHS`），視覺三處一致。
  極限／無盡是遊戲模式沒有實體物件，維持原本圓框 ＋ 文字 glyph 佔位，不強求四個
  UNLOCK_TABLE key 都配圖。圓框內縮見 `UNLOCK_ICON_ART_PAD`（正方形貼圖要留在
  `UNLOCK_ICON_SIZE` 132 的內切圓內，四角才不會探出圓框）。
- **卡包**（`pickup_loot_bag.png`，來源 `tcg.png` 60×60 無透明留白，縮到 32×32＝
  `LOOT_BAG_ART_SIZE`，判定 `LOOT_BAG_SIZE`(16) ×2，同 monster／buff orb 慣例）：
  `WellWorld._draw_loot_bag`，跟金幣／燃料一樣漂浮。
- **pebbles 三變體**（`monster_pebbles1/2/3.png`，來源畫布 145×183——巧合跟
  `chattini.png` 原始尺寸一樣，但**不能**共用腳底錨點，量出來的 bbox 不同，見
  `SpikeConfig.PEBBLES_ART_FEET_FRAC` 的 ⚠⚠）：縮到 67×84（同 `MONSTER_ART_SIZE`，鎖高
  ×2 不雙軸硬拉），三張畫布尺寸與 alpha bbox 完全一致（`tools/measure_anchor.py` 驗過），
  依 `WellMonster.art_variant`（0/1/2＝80/10/10，`PEBBLES_ART_VARIANT_2/3_CHANCE`）切換，
  比照 pameloe 兩變體的既有模式。三張全有才生效，缺一張整組退回 placeholder（同
  `PAMELOE_TEX_PATHS` 的「全有全無」慣例，理由相同：只補到兩張會讓第三種變體變成看不見
  的即死物）。判定框（碰撞規則、`MONSTER_HITBOX_CENTER_OFFSET_Y`）完全比照 chattini 不變，
  只有貼圖畫的位置（腳底錨點）用自己的 `PEBBLES_ART_FEET_FRAC`。

⚠⚠ **`TextureRect` 接 HUD icon 的坑**：Godot 4 的 `TextureRect` 預設
`expand_mode = EXPAND_KEEP_SIZE`，會把節點的最小尺寸釘死在來源貼圖的原生像素——
就算用 anchor/offset 把 rect 縮到 48×48，`EXPAND_KEEP_SIZE` 還是會把它撐回 112×112，
smoke 的通用版面掃描抓到 `[SCAN] OOB`（撐出畫布外）才發現。一定要設
`expand_mode = TextureRect.EXPAND_IGNORE_SIZE` 才會真的縮小，見
`HudCell.set_icon`／`SpikeUI._make_toggle_icon` 的 ⚠⚠。世界貼圖（`draw_texture_rect`）
沒有這個坑——那是直接指定目標 `Rect2`，不吃 Control 的最小尺寸機制。

## 例外九（2026-08-17，使用者拍板）：`assets/sprites/doom1/2/3.png` ／ `pickup_loot_bag.png`（更新）

**黑洞三張輪播**：`well_world._draw_doom` 每 `SpikeConfig.DOOM_FRAME_INTERVAL`（0.05s）切一張，
取代原本純色圓弧的向量畫法（貼圖缺任一張仍會整組退回向量畫法，同其他「全有全無」批次）。
⚠⚠ 三張畫布尺寸統一 846×558，**不各自裁切 alpha bbox**——量測三張的黑核心中心點都落在
畫布中心附近（誤差 x±23px／y±13px），直接整張置中貼在洞心 `d.pos` 就不會在輪播時跳動；
換素材要重新確認這件事，各自裁切會讓核心位置跳來跳去。`DOOM_ART_SIZE`（474×313）的推導：
黑核心（近黑且不透明像素）alpha bbox 直徑量測均值 182px，縮放使核心直徑對齊
`DOOM_RADIUS*2`＝102px（可歸因性：看起來致命的範圍＝真的致命的範圍，同其他即死物的
既有原則），不是隨手選的美術尺寸。

**紅色光暈＋粒子吸入**：範圍＝`DOOM_PULL_RADIUS`（跟吸引力範圍共用同一顆常數，不是另外
挑的好看數字），`well_world._draw_doom_glow` 由外而內疊 `DOOM_GLOW_LAYERS` 層半透明圓
（暖芯冷邊）；持續被吸入核心的微光粒子狀態掛在 `Interference.Doom.particles`（惰性初始化
於 `step()`，見該類別的 ⚠），純表現，用全域 `randf()`（同 `_spawn_sparks`／`_petrify_takeoff`
的既有慣例）。使用者從 5 種柔和放射風格預覽中選定方案 A（基礎柔和暈染），常數與色階見
`spike_config.gd` `DOOM_GLOW_*`／`C_DOOM_GLOW_*`。

**卡包貼圖更新**：使用者提供新版 `tcg.png`（60×60，跟 08-14 那版一樣無透明留白），沿用
既有例外八的做法直接縮到 32×32 覆蓋 `pickup_loot_bag.png`，判定與掛點都不變。

## 例外十（2026-08-17，使用者拍板）：`assets/sprites/tail1/2/3.png`（甩尾，合併原側風＋抽跳板）

**來源**：`Downloads/素材/tail1~3.PNG`，三張畫布統一 2560×1440。`tools/measure_anchor.py` 量出 alpha bbox：
tail1 `left=230 top=384 right=2560 bottom=1002`、tail2 `left=354 top=353 right=2560 bottom=1020`、
tail3 `left=338 top=329 right=2560 bottom=1142`——**三張的 `right` 都剛好等於畫布寬度**，證實三張
圖是同一個設計慣例：內容在畫布**右緣被裁切**（根部／出手端貼齊右緣）、尖端（穗狀／尖狀端）留在
畫布左側偏內。這跟怪物／蟲洞那種「四邊都留白、置中或腳底錨點」的既有慣例不同，甩尾是「一端固定
貼牆、一端隨伸長移動」的橫向物件，錨點策略因此改成**出手端貼齊井壁**，不是置中也不是腳底。

**裁切＋縮放**：先各自裁到 alpha bbox（去掉右緣以外的透明留白，裁完內容寬分別是
2330／2206／2222px），再**鎖寬**縮到 1100px（＝ `WELL_RIGHT - WELL_LEFT`，甩尾伸長滿格時要正好
貼齊對側井壁，寬度由玩法幾何決定，不是美術自訂值），高度依各自來源比例算（不強行套同一顆
高度——三張外型差異大，例外八「監池雙軸不硬拉」的既有原則）：tail1 292px、tail2 333px、
tail3 402px（`SpikeConfig.TAIL_ART_HEIGHTS`）。三張全有才生效，缺一張整組退回純色向量畫法
（同 `PAMELOE_TEX_PATHS`／`monster_pebbles*` 的「全有全無」慣例）。

**渲染**：`well_world._draw_tail_bodies()` 用 `draw_texture_rect_region` 從貼圖**右緣（根部）**
往左漸進露出，不是整張縮放貼上去——那樣伸長動畫會變成貼圖被水平拉伸/壓扁。src region 永遠取
貼圖最靠右緣的一段（隨伸長比例變寬），對應世界座標中從出手牆往對牆生長的尾尖，數學推導見該
函式註解。從**左**井壁出手時整段鏡像（負寬度 dst rect，同 `_draw_pameloe` 依方向翻轉的既有
手法）；從**右**井壁出手時貼圖天生方向（根在右、尖在左）剛好對應世界方向，不用鏡像。

**判定跟視覺脫鉤**：三張外形差異大（尤其厚度：618/667/813px 內容高，換算後 292~402px），但碰撞
判定固定用 `TAIL_HIT_WIDTH`(36px) 的點到線段距離（同 `WellMonster.laser_hits()` 的既有手法），
三張共用同一個寬度常數，不個別量框——沿用「判定寧可鬆給玩家、跟視覺脫鉤」的既有原則，避免三套
不同碰撞框帶來的維護與手感落差。

## 例外十一（2026-08-18，使用者拍板）：`assets/sprites/story_intro_1/2/3/4.png`

**開場劇情從佔位圖＋文字區塊換成真人四格漫畫**（來源 `Downloads/manga/manga1.PNG`，2560×1440，
使用者手繪四格排版：左欄全高一格＋右上兩格＋右下一格，格與格之間是手繪斜線而非規則格線）。
使用者規格：進遊戲第一次自動淡入第一格，之後每次點擊依序淡入下一格；**拿掉底部文字區塊，
只留滿版漫畫圖**（跟 clear_0／clear_1 那組仍在用的「圖＋文字」排版是兩種不同呈現，故意不共用）。

**切格做法**：不是四張各自獨立的小圖，而是四張**同尺寸（2560×1440）全畫布**的透明遮罩——每張
只有自己那一格內容不透明、其餘全透明，四張疊在一起像素級精準拼回原圖（`numpy` diff 驗證
＝0，逐像素相同）。這樣做的理由：原稿格與格之間是**手繪斜線**（不是矩形），四個角色與物件的
線稿還會**跨出格線一小段**（如 Raora 的皇冠尖角壓在斜線分隔線上），若各自裁緊緻的矩形小圖，
要嘛裁掉跨界的線稿、要嘛四張各自的定位錨點要另外算——用全畫布遮罩＋疊圖，讓 Godot 端不用
處理任何位移/縮放對齊，四個 `TextureRect` 全部 `PRESET_FULL_RECT` 疊同一個位置就對了。
分割線座標怎麼量的：先在整張圖疊 100px 網格＋座標標籤存成新圖，切四塊分別讀圖比對格線經過
哪個網格座標，斜線用手動取樣多個 (x,y) 點連成折線（分格線本身是純黑手繪墨線，厚度 12~23px，
遮罩邊界切在墨線正中央——這樣兩側像素都帶著半條墨線，疊起來邊界完全接不出縫，也是 diff＝0
的原因之一）。

**渲染**：`SpikeUI.show_story_intro()` / `_advance_story_intro()`，四個 `TextureRect`
（`STRETCH_KEEP_ASPECT_COVERED` ＋ **`EXPAND_IGNORE_SIZE`**，同例外八 HUD icon 踩過的坑——
不設的話 2560×1440 的原生尺寸會把 `PRESET_FULL_RECT` 撐爆成 OOB）疊在同一個 `_story_intro_root`
下，`modulate.a` 從 0 淡到 1（`STORY_INTRO_FADE_TIME` 0.5s）。⚠ 淡入動畫走 `_process` 手動算
delta，不用 `Tween`——同橫幅淡出（`SpikeUI._process` 檔頭 ⚠）的既有理由：`SpikeUI` 整層
`PROCESS_MODE_ALWAYS`，用 `_process` 才能保證任何暫停狀態下都演得完（雖然 STORY 這個 state 目前
沒有真的暫停樹，但沿用同一套手法而不是引入這個檔案原本零使用的 `Tween`，是刻意的一致性選擇）。
點擊手勢複用 `_on_overlay_gui_input`：淡入中點一下＝跳到全亮（不多推進一格），全亮後再點才推進
下一格，四格都亮之後下一次點擊才真的發 `story_advanced` 交還 `main.gd`——沿用大多數 VN
「先讓玩家看完當前這格，快速連點不會跳過內容」的既有直覺。

**main.gd／spike_config.gd 分流**：`_advance_to_title()` 在查 `SpikeConfig.story_text()` 之前
就先判斷 `_pending_story == STORY_INTRO_ID`，分流到 `show_story_intro()`；`story_text()` 因此
拿掉了 intro 分支（原本的 `STORY_INTRO_PLACEHOLDER` 文字常數已刪除，故事文字表現在只剩
`LEVEL_STORY_PLACEHOLDER` 那兩段通關佔位）。`STORY_INTRO_ID` 本身沒刪——它仍是
`SpikeSave.story_seen_of/mark_story_seen` 的存檔鍵，也是 `main.gd` 判斷「該播哪一種」的分流依據。

## 例外十二（2026-08-18，使用者拍板）：`assets/sprites/death_explosion_sheet.png`

**死亡演出從純向量特效（擴散環＋碎片）換成真人爆炸素材**。來源 `Downloads/explosion (1).mp4`
（540×540，30fps，4.1s，綠幕），這次來源是**影片不是靜圖**，SOP 比照 `/import-art-asset` 但
去背與切幀改用 ffmpeg：

```
ffmpeg -i "explosion (1).mp4" -vf "setpts=PTS/2.05,fps=20,scale=240:240:flags=lanczos,
colorkey=0x0a9602:0.35:0.12,despill=type=green:mix=0.5:expand=0,tile=8x5" -frames:v 1
assets/sprites/death_explosion_sheet.png
```

- **綠幕色值** 取樣素材實際像素量得 `(9,150,2)`≈`0x0a9602`，不是常見的純綠 `0x00ff00`；
  `colorkey` 相似度 0.35／羽化 0.12 先試單張再肉眼比對深色背景合成（避免只看透明棋盤格漏看
  綠色殘留），`despill` 壓掉煙霧邊緣的殘留綠色調——兩者都是先抽樣測試過才定案的參數，不是
  隨手選的預設值。換素材要重新測，不能直接沿用這組數字。
- **時長壓縮不是截斷**：原始 4.1s 完整爆炸演出用 `setpts=PTS/2.05` 整段加速塞進使用者指定的
  ~2 秒（`SpikeConfig.DEATH_FX_DURATION`），20fps 取樣＝剛好 40 幀，`8×5` tile 一次成一張圖，
  不是各自存 40 個檔案（40 個路徑常數會違反現有「全有全無小陣列」的接線慣例，單張 sheet＋
  `draw_texture_rect_region` 切格更合適）。
- **時長常數連動**：`DEATH_EXPLOSION_FRAME_INTERVAL := DEATH_FX_DURATION / FRAME_COUNT`
  （`spike_config.gd` SECTION 6c），改 `DEATH_FX_DURATION` 幀間隔會自動跟著變，不用手動同步。
  ⚠⚠ 這條**覆蓋**了 SECTION 6c 原本「時長是手感，換素材不該連帶改掉節奏」的既有原則——
  使用者這次明確指定新素材要套用約 2 秒，是新的拍板，不是誤觸舊規則。
- **中心對齊**：不像怪物/蟲洞那樣量腳底錨點——這是純特效疊加在死亡位置上，不是站在平台上的
  東西，`_death_fx_pos - art*0.5` 整張置中貼，同 `_draw_doom` 整張置中的既有慣例。畫面上蕈狀雲
  底部因此會落在死亡點下方一截（雲本身在切幀畫布裡不是置中構圖），肉眼可接受，沒有必要為了
  「雲底對齊死亡點」另外量測偏移常數。
- **缺檔 fallback**：`_death_explosion_tex == null` 時 `_draw_death_fx` 整個退回原本的向量
  擴散環＋碎片畫法（`DEATH_FX_RADIUS_*` 等常數仍在，兩套視覺對應同一個
  `DEATH_FX_DURATION`）。
- **收尾淡出**：播放進度超過 `DEATH_EXPLOSION_FADE_OUT_START_T`(0.85) 才開始線性淡出，避免
  播完直接硬切去結算小卡；沒有真人試玩調過這個時間點。
- **驗證**：`visual_check.gd` 手動呼叫 `world._die()` 後撥 `_death_fx_t` 到中段／尾段存兩張
  PNG（`death_explosion_check_mid/late.png`）比對切幀位置與淡出，沒有跑 `record.tscn`——
  這是死亡瞬間的一次性特效不是移動中會反覆切換姿勢的角色貼圖，visual_check 兩張時間點的
  快照已經能看出幀進度與位置對不對，20 秒動態錄影對這個素材的邊際驗證量很低。

## 例外十三（2026-08-19，使用者提供）：`assets/sprites/qr_itchio/twitter/youtube.png`

**來源**：使用者提供 `personal/qrcode/{itchio,twitter,youtube}.png`（148×148／148×148／164×164，
原生方形、無需裁切）。用途是設定頁「工作人員名單」分頁的聯絡方式區塊，讓玩家用手機掃碼直接
連到 itch.io 頁面／X／YouTube，跟旁邊的文字網址並列（沒有 email 用 QR——文字已經是最短形式）。

**尺寸**：`SpikeConfig.QR_DISPLAY_SIZE`（96×96）直接縮小顯示，`TextureRect` 走
`STRETCH_KEEP_ASPECT_CENTERED` ＋ `EXPAND_IGNORE_SIZE`（同例外八 HUD icon 的既有做法，不設
`EXPAND_IGNORE_SIZE` 會把最小尺寸釘在原生像素撐爆版位）。96px 仍保留足夠模數給手機相機掃碼。

**全有全無 vs 各自獨立**：跟 buff icon／pameloe 那類「同一套主題缺一張整組退回」的批次不同，
三顆 QR 是三個互不相關的外部連結，`SpikeUI._build_contact_qr_row` 逐顆呼叫 `_load_icon`，
單顆缺檔就跳過那一顆，不影響其餘兩顆顯示。

**沒有做的事**：QR 只是靜態圖，沒有接 `OS.shell_open` 之類的點擊跳轉——設定頁是純顯示，
外部連結交給玩家自己掃碼或抄網址，不在遊戲內發動對外請求。

## 例外十四（2026-08-20，使用者提供）：`assets/sprites/bg_title.png`

**主頁（標題畫面）從純色 `C_BG` 換成滿版背景圖**，`SpikeUI._build_start_panel`。原生
2560×1440，跟 `VIEW_W×VIEW_H`（1280×720）同為 16:9，`STRETCH_KEEP_ASPECT_COVERED` 縮放後
剛好滿版無裁切，不需要另外裁切或量錨點（跟角色／怪物那類「站在平台上」的素材不同，這張
是純背景，沒有腳底錨點可言）。

**主頁不再共用 `_make_page` 的圓角卡片框**：那個版型的外框只留 `PAGE_MARGIN`(28px) 窄邊，
滿版美術擺在那裡幾乎看不到，所以標題畫面改成自己疊圖（同 `_build_story_panel` 開場漫畫的
既有疊圖手法）——由下而上：純色 `C_BG` fallback（缺圖時退回，同時擋掉點在空白處時穿透到
背景畫面）→ 背景圖 → 半透明暗化層（`Color(C_BG, 0.35)`，讓標題文字／存檔說明這類沒有
自己底色的文字仍可讀，同 `_story_text_box` 既有的半透明手法）→ 原本的金幣徽章／開關
icon／標題／選關列／按鈕／存檔說明，版面座標（`START_*_BAND_*`）完全不動。商店／成就／
設定等其他分頁仍是 `_make_page` 的卡片框，不受影響。

**缺檔 fallback**：`ResourceLoader.exists()` 判斷，缺檔時 `bg` 貼圖為空、退回底下純色
`C_BG` fallback，同其他批次的「缺檔不能讓東西整個消失看不見」既有原則。

⚠ 這批素材是使用者直接提供的圖檔（透過 Google Drive 連結取得，非本機素材夾），沒有另外
核對是否為 AI 生成——若之後要更新 `checklist.md`／`HANDOFF.md` 那份「AI 生成素材數量」
盤點，這張的來源需要回頭跟使用者確認。

驗證：這次施工在沒有本機 Godot 執行檔的環境完成，**未跑過** `--headless --import` 或
`smoke.tscn`／`visual_check.tscn`——正常開發流程下一步是在能跑 Godot 的機器上補跑一次
`--headless --path <spike_well> --import`（新圖沒有 `.import` 檔，不重新匯入
`ResourceLoader.exists()` 會是 false，主頁會靜默退回純色 fallback）後，再跑
`visual_check.tscn` 肉眼確認版面沒有被壓到、文字仍可讀。

## 字型（現況）

`assets/fonts/NotoSansCJKtc.otf`（原本 `NotoSansTC.ttf`）。使用者拍板（v17）：TC 版不含平假名／片假名，日文版會整頁豆腐。⚠ 子集只收「`.gd` 裡真的出現過的字」，換字型檔記得重跑 `tools/subset_font.py` ＋ `--import`（見 spike_well/CLAUDE.md「建置工具」）。
