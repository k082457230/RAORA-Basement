# CLAUDE.md — 爬井 spike

跨專案底線在全域 `~/.claude/CLAUDE.md`，**本檔不複製，只補這個 spike 專屬的條款**。

## 這是什麼

**2026-08-10 起定位轉正**：原本是拋棄式原型，現已籌備先發到 itch.io、會持續小更新——治理規則按「可能是第一份正式作品」對待，不再是「用完即丟」。
核心玩法：爬井（滑鼠拖曳移動、跳躍、射線鞭子、Raora 階梯干擾）。
設計規格唯一的家：`../PILLARS_2.md`（P4 ＋ 逃脫結構）。進度唯一的家：`../HANDOFF.md`。
偏離表僅供對照參考，實用價值低——現行規則以表格本身為準，沿革見 `../HANDOFF_ARCHIVE.md`。

## 硬規則

1. **所有可調數值一律進 `autoload/spike_config.gd`**，不准散落在其他檔。理由：未來很可能只抄數字走，抄一個檔就夠。
2. **不建任何額外治理檔**——沒有 PROJECT_MAP、沒有 ADR、沒有 pitfall 檔。要記的事寫回 `../HANDOFF.md`。
3. **不手刻 .tscn**。節點一律程式建構，`Main.tscn` 永遠只有 3 行。
4. **placeholder 美術**：純色矩形 ＋ `_draw()`。不引入任何美術資源檔。
   **例外一：`assets/fonts/NotoSansTC.ttf`**（OFL 授權）。Web 匯出讀不到系統字型，
   `SystemFont` 會 fallback 到不含 CJK 的內建字型 ⇒ 整頁豆腐方塊。這不是美術決定，是相容性。
   **例外二（2026-08-09，使用者拍板）：`assets/sprites/kaela_*.png`**。玩家正式美術提早
   試接進 spike（`well_world._draw_player_sprite`），不等正式版。理由：使用者要邊看邊調
   手感與尺寸，不想等到正式版才第一次看到玩家長什麼樣子。流程與規範見下方「美術素材
   匯入 SOP」。
   **例外三（2026-08-10，使用者拍板）：`assets/sprites/monster_chattini.png` /
   `wormhole_the_sheep.png` / `projectile_cucumber.png`**。怪物、蟲洞、投擲物三種
   `_draw()` 換成真實美術，流程與例外二相同（見「美術素材匯入 SOP」）。
   **例外四（2026-08-10 續，使用者拍板）：`assets/sprites/pameloe1.png` /
   `pameloe2.png`**。Pameloe 本體換成真實美術，兩張立繪按 90% / 10% 抽取
   （`PAMELOE_RARE_ART_CHANCE`）。來源檔名的拼法是 `pemaloe`，程式端一律沿用既有的
   `PAMELOE` 拼法，不為了對齊檔名去改一整套識別字。
   **例外五（2026-08-10 續，使用者拍板）：`assets/sprites/pickup_coin.png` /
   `pickup_fuel.png`**。金幣與燃料補給換成真實美術，另加**沿 alpha 輪廓 +2px 的白光**
   （共用 `WellWorld._draw_sprite_outline`）與**上下漂浮**。
   ⚠⚠ 這兩張的 art 尺寸基準跟前四條例外**不同**：怪物那組是「art 畫布 ＝ 判定 ×2」，
   這組是「art 的 **alpha 內容** ＝ 判定 ×2」——來源圖四周有大片透明留白（coin 的 60
   畫布裡只有 52 有東西），照畫布算會讓玩家看到的東西整整小一圈。抄前面那組會錯，
   推導與稽核見 `spike_config.gd` 的 `COIN_ART_SIZE` ⚠⚠ 與 `tests/audit_levels.gd`
   `_audit_pickup_art`。
   **08-10 三訂（使用者拍板「大小 -50%」）**：來源 PNG 不換檔，改用 `PICKUP_ART_SCALE`
   在畫的時候整體縮小，判定與 `PICKUP_HOVER` 跟著等比減半。細節見偏離表「物資（金幣／
   燃料）尺寸」列。
   ⚠ 這幾條例外**只開放給已經量產出來、使用者確認要接的貼圖**，不是「以後想加什麼美術
   都可以直接加」——新素材要不要比照辦理，還是回去問使用者。
5. **按鍵不准出現字面值**（`KEY_A`、`KEY_SPACE`…），一律走 `SpikeKeys.key_of()` / `is_action_pressed()`。
   預設值住 `spike_config.gd` 的 `DEFAULT_KEYS`，設定頁改的是覆寫層。
6. 驗證 = headless import 0 error ＋ 實跑。`--headless --quit` 通過不等於玩得動。
7. **稽核必須走真實路徑**。v9 的蟲洞是死的卻全綠燈，因為稽核一次生完整座井、
   沒有串流上限也沒有 prune。凡是「邊玩邊生成／邊回收」的東西，稽核就得自己模擬那條路
   （見 `smoke.gd` 的 `_audit_streaming_wormholes`）。

## 建置工具

`tools/` 有 `.gdignore`，Godot 完全不看它，也不會進匯出包。
`tools/subset_font.py` 掃全部 `.gd` 的中文字，把 11.9MB 的完整 Noto Sans TC 子集成 ~300KB。
**改過任何中文文案後要重跑**，否則新字在 Web 版是豆腐方塊。

## 執行方式

```
C:/Users/gnt0233/Downloads/Godot_v4.6.1-stable_win64.exe --path <spike_well 絕對路徑>
```

## 已知的刻意偏離規格

沿革與理由已搬去 [HANDOFF_ARCHIVE.md](../HANDOFF_ARCHIVE.md)「偏離表沿革／理由存底」（Grep 項目名稱定位），此處只留現行規則。

| 項目 | PILLARS_2.md | 現行規則 |
|---|---|---|
| 終點 | 無終點，干擾升壓到必然墜落 | 關卡制＋無盡模式並存：有終點時抵達 `goal_meters` 即成功結算（`cleared`→`_check_end`，任一關卡登頂皆算 cleared）；無盡模式（右上角開關）不設終點爬到死。地形軸於 `DIFFICULTY_RAMP_HEIGHT_M`（1000m）封頂，側風 `SHOCKWAVE_RESPONSE` 不封頂、每 500m ×1.23 |
| 關卡 | 無此概念 | 三關 1000／1500／2000m（`LEVEL_GOALS`）：抵達即結算＋解鎖下一關＋播劇情，已解鎖可重玩，主頁選關列於「開始遊戲」上方。難度→高度對應**預設禁止**隨關卡改變（一律綁 `DIFFICULTY_RAMP_HEIGHT_M`／`PRESSURE_STEP_HEIGHT_M`，不綁 `goal_meters`）；例外須登記進 `SpikeConfig.LEVEL_GATED` 白名單，`tests/audit_levels.gd` 正向驗白名單項目確實隨關卡有差 |
| 無盡模式 | 無此概念 | 主頁右上角第三顆開關（跨局記住）：不在 `goal_meters` 停局，爬到死；與關卡、極限模式各自獨立可任意組合。讀取一律走 `SpikeConfig.eff_has_goal()`。不解鎖下一關、不算登頂成就、不記登頂用時 |
| 局長 | 無干擾期 120s | 短局 67s，四階每隔 20s：67／87／107／127s（`stage_*_offset`，四值須兩兩不等） |
| 干擾種類 | 三種 | 四種（＋黑洞 doom） |
| 鞭子次數 | 初始 10、硬上限 12 | 初始 5、升級上限 +3（＝8） |
| 鞭子拉近 | 「定速拉近」 | 給加速度，過錨點才還控制權 |
| 鞭中怪物 | 「擊退」 | 擊退 ＋ 仍纏住拉過去 |
| jetpack 燃料 | 上限寫死，不得進升級表 | 進升級表，初始砍半（110→55m），升滿回到 110m；消耗倍率 ×1.5（`JETPACK_FUEL_BURN_MULT`） |
| jetpack 噴射的無敵窗與使用間隔 | 無此概念 | 噴射結束無敵餘韻 `JETPACK_INVULN_GRACE`(0.2s，其餘來源仍用共用 `INVULN_GRACE` 0.5s)；噴射結束後另需間隔 `JETPACK_COOLDOWN`(0.6s) 才能再噴，與冷啟動 `JETPACK_SPOOL_TIME`(0.2s) 是兩件事 |
| 蟲洞守門 | v4 提案：出口 2 秒下墜內必有可救落點 | 出口固定綁定一塊不會動的平台 |
| 蟲洞轉場 | 未規定 | 0.5s 順滑過場（相機與玩家共用 `smoothstep`），過場中凍結物理＋全程無敵；干擾計時不停，只 `suppress_spawn` |
| 戰利品商店 | 分數制 ＋ 單次／永久兩檔 | 金幣直接買永久升級，無單次檔 |
| 資源種類 | 只有物資一種 | ＋燃料補給（300m 以上、固定補 7m、滿載不消耗） |
| 攀爬 | 無此概念 | 攀爬手套（商店第 6 項，有／無兩態）：頂點差一點時補一次小跳，成功放白色同心圓特效；不改變生成器可達性判定（仍用基礎 `MAX_JUMP_HEIGHT`） |
| 燃料補給機率 | 無此概念 | 隨高度遞減（0.20 → 0.13） |
| 投擲物 | 「從上方落下」 | 邊落邊轉的長方形 ＋ 落點提前 2s 預警（畫面上方閃紅三角），落點預警當下抽定、不追蹤玩家 |
| 投擲物判定 | 未規定 | 視覺 116×51 旋轉（對齊 `cucumber.png` 比例），判定固定 90×40 矩形（面積鎖 3600，同比例對齊視覺） |
| 干擾預警 | 只規定投擲物要看得到 | 四種干擾各有對應預警：投擲物＝紅三角（事前 2s）、抽跳板＝紅閃爍（事前 0.5s）＋事後削掉四散火花、側風＝每陣風前 2s 綠條閃爍＋吹時常駐淡綠、黑洞＝事前 2s 紫色半透明圈（綁在目標平台上） |
| 側風性質 | 常駐向左的力、無上限遞增 ⇒ 必然墜落 | 間歇陣風：吹 1s、休 9s（`BURST_TIME` 1.0／`CYCLE` 10.0），力道隨時間遞增；但側向速度恆定封頂在 `SHOCKWAVE_RESPONSE`(400px/s)＝玩家全速 29%，陣風之間玩家完全自由 |
| 黑洞（doom） | 無此概念 | 第四種干擾：玩家上方隨機一塊平台（第 2 塊起）開洞，半徑 34 事件視界碰到即死、260px 內向心吸力（上限 520，玩家全速 1400 可逃）、壽命 5s 自塌，無敵狀態碰到即消掉它 |
| 碎裂平台 | 「踩一次即碎」 | 踩到後整段淡出 0.45s，淡出期間仍踩得住 |
| 怪物死亡 | 未規定表現 | 往遠離玩家方向拋物線飛出＋邊轉邊淡出（0.6s），期間退出判定；踩頭／撞飛（不含鞭中）另有 20% 機率鞭子次數 +1 |
| 高度 HUD | 未規定 | 左上只顯示本回合最高抵達高度，不寫分母、無進度條 |
| 極限模式 | 無此概念 | 主頁右上角開關（跨局記住）：所有等待歸零（登場 67s 與四階全變 0，開局即 stage 4），四種預警時長不歸零；讀取一律走 `SpikeConfig.eff_*()` |
| 攀爬手套啟用 | 無此概念 | 買了之後主頁右上角多一顆開關可隨時停用（`SpikeSave.ledge_enabled`），沒買不顯示；`has_ledge_grab()` = 已買 AND 已啟用 |
| 成就系統 | 無此概念 | 9 個版位（`ACHIEVEMENT_SLOTS`）、17 個判定 leaf id（`ACHIEVEMENT_TABLE`，SECTION 8c），三態：未解鎖／已解鎖未領獎／已領獎。解鎖放橫幅（3s），入帳需玩家至成就頁點卡片，唯一入帳出口 `claim_achievement()`。披薩／義大利麵／Chattini／遊玩次數四項各拆 I/II/III 三階，共用同一張卡片版位（`SpikeSave.current_tier_id()` 動態決定） |
| 墓碑 | 無此概念 | 歷史最高高度 y 軸最相近的平台上立墓碑，碰到得 10 金幣，一局最多一個（無紀錄不放）；壓過同板金幣／燃料，讓位給蟲洞 |
| Pameloe（第二種敵人） | 無此概念 | 500m 以上出現的懸浮定點射手：不巡邏不跟隨平台，每 2s 朝 Kaela 當下位置射一發直線子彈（穿透平台、碰井壁消失、命中即死）；本體同既有怪物判定（踩頭／鞭子／無敵撞飛皆可殺）。只在畫面內開火（`hold_fire()`），`PAMELOE_MIN_DIST_X` 保證與母平台水平隔離 |
| Pameloe 出現率 | 無此概念 | 500m 起 8%，線性升到 1000m 的 24%（插值 t 從登場高度 500m 起算，非全井 0m） |
| Pameloe 雷射變體 | 無此概念 | 稀有立繪（`art_variant==1`，抽取 20%）不發子彈改發持續 1s 雷射，開火瞬間鎖方向（同子彈規則），從本體打到井壁；狀態掛在 `WellMonster` 本體上，殺掉本體立刻掐斷雷射；判定用點到線段距離 |
| Pameloe 開火鏡像 | 無此概念 | 開火瞬間依鎖定方向翻轉本體貼圖（`face_toward`），子彈與雷射兩分支皆觸發 |
| 死亡表現 | 未規定 | 不切獨立結算頁：死亡處放小型爆炸（0.55s，世界凍結）演完才結算；摔落死爆炸畫在畫面底緣往上一點；結算卡佔畫面 3/4 由下往上推入，背景維持最後一幀（壓暗） |
| 存檔備份 | 無此概念 | 設定頁匯出／匯入碼：JSON→Base64＋12 碼校驗，前綴 `RAORA1-`。⚠ 校驗非防作弊，文案不得稱「安全」 |
| 字型 | 未規定 | `assets/fonts/NotoSansCJKtc.otf` |
| 貼圖底部錨點 | 未規定 | 站在平台上的東西一律 alpha bbox 底邊貼齊平台上緣（怪物 `MONSTER_ART_FEET_FRAC`、蟲洞 `WORMHOLE_ART_FEET_FRAC`），懸浮物（Pameloe）維持中心對齊；稽核直接掃 PNG alpha 比對 |
| 開發者傳送 | 無此概念 | 畫面右緣中間 `▲ +300 m` 按鈕：按一次瞬間 +`DEV_TELEPORT_M`(300m)，相機同步＋一次無敵窗。只在 `SpikeConfig.dev_mode()` 為真才建得出來（debug build／桌面 `--dev`／Web `?dev=1`）。按過成績／成就／解關一律正常回報 |
| solo 區間的怪物 | 未規定 | `BAND_SOLO_HEIGHT_M`(690m) 以上：怪物巡邏範圍縮到 ±18（`MONSTER_PATROL_RANGE_SOLO`）、主鏈平台寬 ×1.3（`PLATFORM_WIDTH_MULT_SOLO`）、會動的平台不掛怪；`MONSTER_PATROL_SPEED` 70→52 |
| 特殊區段 | 無此概念 | 隨機某 40m 高度區間變主題區：整段只出某一種平台、怪物率 ×2、金幣率 ×2（首種＝移動平台區，`SEGMENT_TABLE` SECTION 4e）。區段內強制帶備援跳板（`band_extra_min`，確定性掃描擺放）；歸屬存 `WellPlatform.segment_id` 旗標，不用高度反推 |
| 爆炸平台 | 無此概念 | 第六種平台（`Kind.EXPLOSIVE`）：踩上去點燃 2s 引信（逐漸變亮仍踩得住），燒完消失並炸出半徑 80 圓形爆炸區（存在 0.35s，碰到即死）。關卡二起才出現（`LEVEL_GATED`）。引信只點一次；無敵免疫但爆炸不會被消掉；爆炸是獨立實體 `WellBlast` 不掛平台 |
| 物資漂浮 | 無此概念 | 金幣／燃料／Pameloe 皆做微幅緩慢上下晃動。金幣／燃料只晃視覺、判定不動（`_pickup_float_offset`）；Pameloe 判定跟著晃（`step()`）。金幣／燃料位移範圍 [-2×AMP, 0]（只往上）；相位由 seeded rng 生成當下定死 |
| 物資（金幣／燃料）尺寸 | 無此概念 | 判定（`PICKUP_SIZE`／`FUEL_PICKUP_SIZE`）與畫面尺寸（`COIN_ART_SIZE`／`FUEL_ART_SIZE`）、`PICKUP_HOVER` 皆等比減半；來源 PNG 不換檔，改用 `PICKUP_ART_SCALE`(0.5) 縮小繪製 |
| 怪物判定框位置 | 未規定 | 判定框大小不變（`MONSTER_SIZE`），位置改對齊 art 視覺中心（`MONSTER_HITBOX_CENTER_OFFSET_Y`），不再貼平台上緣 |

## 美術素材匯入 SOP（2026-08-09 起，Kaela 玩家貼圖為首例；08-10 怪物/蟲洞/投擲物第二次
## 套用、Pameloe 第三次，流程沒改，證明可重複用不用每次重寫一次）

給下一次「把 AI 畫的圖換成遊戲貼圖」照著做，不用重新想一次：

1. **量測目標尺寸**：目標＝角色在 `spike_config.gd` 的碰撞尺寸（如 `PLAYER_SIZE`）× 2（已拍板
   慣例，來源見 `../HANDOFF.md` 美術素材規範）。
2. **等比縮放，不要雙軸硬拉**：量實際來源檔尺寸算縮放比，若跟目標有落差（AI 畫圖常見）就
   **鎖長或寬其中一軸**等比縮小，兩軸各自分別拉到目標值＝變形不是縮放。
3. **判斷是不是硬邊像素風**再選縮圖演算法：抽樣幾列像素跑 run-length，長度若卡在固定倍數
   （真正的像素網格）才用整數倍＋nearest；平滑抗鋸齒插畫（多數 AI 產圖屬此類）用
   Lanczos/bicubic 不會有破網格風險。
4. **多姿勢貼圖共用同一個錨點**：同角色的每張畫布尺寸必須完全一致；只用其中「最需要精準
   貼合」的那張（例如踩到平台的姿勢）量出「腳底 alpha bbox 底邊 ÷ 畫布高度」當唯一錨點
   比例寫進 `spike_config.gd`（如 `KAELA_FEET_ANCHOR_FRAC`），其他姿勢沿用同一比例，不要
   各自重新量——每張各量各的，切換姿勢時角色會跳動。⚠ 量測基準用縮圖「之後」的檔案，
   縮放取整會有 1~2px 誤差，拿原始檔量測、貼縮圖後的比例會對不齊。
   ⚠⚠ **08-10 補，這條不只適用多姿勢角色**：凡是「站在平台上」的東西（玩家、怪物、
   蟲洞）**一律要量腳底錨點，不准用中心對齊**。art 尺寸是碰撞尺寸的 2 倍，中心對齊
   會讓貼圖底邊沉到平台上緣下方 21px、而平台只有 18px 厚 ⇒ 整塊平台被蓋掉。
   08-10 第一次接怪物與蟲洞就是這樣接錯的，使用者看畫面才發現。懸浮的東西
   （Pameloe）才用中心對齊——它沒有「腳底」這條基準線。
5. **檔案落地** `spike_well/assets/sprites/`。路徑常數住在實際 `load()` 它的那個檔案（同
   `SpikeUI.FONT_PATH` 慣例），不進 `spike_config.gd`——規則 1 管可調數值，不是資源路徑。
6. **匯入設定不用逐檔調**：`project.godot` 的 `[importer_defaults] texture` 已統一開
   `mipmaps/generate=true`，`[rendering]` 已設 `textures/canvas_textures/default_texture_filter=2`
   （Linear Mipmap），新圖直接吃這組預設。存檔後記得跑一次
   `Godot..._console.exe --headless --path <spike> --import`——跟換中文字型同一個坑：
   不重新 import，`ResourceLoader.exists()` 會是 false。
7. **程式接線延用既有 `_draw()`**：`draw_texture_rect()` 接進去，不新增 Sprite2D 節點、
   不手刻 .tscn（規則 3）。載入用 `ResourceLoader.exists()` 判斷，缺檔要退回色塊 fallback，
   不能讓玩家整個消失看不見。
8. **驗證兩層都要做**：① headless 回歸（`smoke.tscn`）確認 0 import error、無邏輯回歸；
   ② 肉眼看貼圖位置、姿勢切換有沒有跳動、有沒有穿模——這層數字測不出來，省不掉。
   **用 `res://visual_check.tscn`**（08-09 為 Kaela 三態寫的一次性小工具，留著沿用）：
   直接把 `WellWorld` 建出來、手動撥 `player` 狀態、`queue_redraw()` 後用
   `get_viewport().get_texture().get_image().save_png()` 把畫面存成 PNG，不用截圖工具、
   不用滑鼠去戳遊戲視窗。⚠⚠ **這條路一定不能加 `--headless`**：headless 底下
   `RenderingServer` 是 dummy driver，貼圖會是空白（這正是 08-08 那次「截圖抓到空白幀」
   的根因，見 `../HANDOFF.md` 執行方式那段的更新說明）。指令：
   `Godot..._console.exe --path <spike> res://visual_check.tscn`（會真的開一下 Vulkan
   視窗，正常，腳本跑完會自己 `quit()`）。輸出在 `tools/out/`。

切回規格數值：`spike_config.gd` 的 `ACTIVE_PRESET` 改成 `Preset.SPEC`。
