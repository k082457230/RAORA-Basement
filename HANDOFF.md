# HANDOFF — RAORA

> 最後更新：2026-08-14
> 設計支柱唯一的家：[PILLARS_2.md](PILLARS_2.md)（現為 **v8**）
> 爬井 spike：[spike_well/](spike_well/)，專屬規則見 [spike_well/CLAUDE.md](spike_well/CLAUDE.md)，
> 偏離規格的現行規則見 [spike_well/.claude/docs/deviations.md](spike_well/.claude/docs/deviations.md)
> 歷史（發生過什麼）：[HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)

---

## 當前狀態

spike_well 08-10 起**定位轉正**（籌備 itch.io 首發）。Git 備份：
`https://github.com/k082457230/RAORA-Basement.git`（使用者私人帳號）。

spike **v22 全綠**（七組稽核 ＋ bot 4 局；**各組項數以實跑輸出為準，不抄在這裡**）。
08-07～08-14 施工細節全在 [HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)；偏離規格現行規則
唯一的家＝[deviations.md](spike_well/.claude/docs/deviations.md)。

**08-14（v22）＝真人試玩後的十項**（騙人平台／卡包／pebbles／視野間歇／屍體堆／干擾跨局殘留
修復／教學關 500m／DAHLAH 偏移——細節見 archive）：**全部只過機器稽核與截圖，尚未真人試玩**，
要驗什麼見下方「這次真人試玩重點」。

**08-14 下半場＝驗證體系改造**（不動玩法，全綠）：新增 `smoke -- --only=<組>`、突變測試批次
驅動 `tools/mutation_check.py`、`well_world.gd` 檔頭索引、驗證路由表
[verification-matrix.md](spike_well/.claude/docs/verification-matrix.md)。細節見 archive。

**08-14 收尾＝美術接線流程改造**（只動文件、零程式）：檢討「14 張那批為何超時」後，skill
`/import-art-asset` 補 **Step 0 自主分桶**（要新寫渲染能力的排最前面先打通；檔名↔識別字
**雙向**對照，缺素材走 placeholder 不停下來問）、步驟 7 拆**世界層／UI 層兩條接線路徑**
（`EXPAND_KEEP_SIZE` 坑）、步驟 8 改**素材類型→驗證子集**（UI-only 不跑 record，省 4 分鐘）；
[art-assets.md](spike_well/.claude/docs/art-assets.md) 加 14 列檔頭索引。

**08-19＝itch.io 帳號驗證 ＋ 免責聲明四語化 ＋ 設定頁「語言/名稱」分頁上線**（機制驗證，
非全面 i18n）：itch.io API key 打 `/me`／`/my-games` 驗證帳號存在（`developer:true`，
零已發佈 game）；`SpikeConfig.DISCLAIMER_TEXT` 拆成 `DISCLAIMER_TEXT_BY_LANG`（中/英/日/
印尼四語，checklist.md §0 D-3 借此拍板）；設定頁「名稱設定」分頁（08-18 三訂原本佔位）
補上語言切換四鈕＋玩家名稱輸入框，`SpikeSave` 新增 `player_name`／`language` 兩個持久
欄位。**目前只有工作人員名單頁的免責聲明真的隨語言切換**，其餘 UI 文案仍未 key 化
（§7.2 主體不變）；玩家名稱**沒有查重複排名**（排行榜後端還沒有，欄位下方顯示誠實提示，
不假造「第幾位」）。headless import／smoke 全綠，重跑 `subset_font.py`。**未驗證**：語言
按鈕列的實機版面（"Indonesia" 標籤會不會撐爆按鈕，沒截圖確認）。細節見
[HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)「itch.io 上架前檢查清單第二次盤點」。

## ▶ 下個 Session 起點

**⚠ 仍待你拍板的兩件**（三訂留下，兩個 session 都沒動）：

1. **bot 的鞭子週期**：`bot_run.gd` 起手週期 6 秒 > bot 實際存活 3~4 秒 ⇒ smoke 四局的鞭子
   路徑**從來沒被真的執行過**（輸出恆為「射出 0／命中 0」）。要不要比照 `record.gd` 縮到
   1.5 秒？改了會變動既有稽核的意義，所以一直刻意沒動。
2. **錄影要不要接 HUD／UI 層**：`record.tscn` 只建 `WellWorld`，左下角 HUD（動態由下往上疊、
   最容易出版面問題的地方）完全沒入鏡。要接得走 main.gd 流程，複雜度高一階。

**⚠ 等使用者補素材**（全部到位前相關畫面都是佔位）：

1. **`petrify`（石化藥水）一張 112×112** — 08-14 那批唯一缺的 buff，目前自動退回純色
   placeholder。（`dahlah` 已退出抽池，不必配圖。）
2. **滿版劇情圖**（`SpikeUI._story_art` 換 TextureRect）／**解鎖卡 icon**（`_unlock_glyph`
   換 TextureRect，版面不動）。
3. **死亡爆炸**：只換 `_draw_death_fx`；`_draw_blasts`（爆炸平台）不能共用同套畫法。

**已到位（08-14）**：六種 buff ／四顆道具 icon ／卡包 ／pebbles 三變體 — 見
[art-assets.md](spike_well/.claude/docs/art-assets.md) 例外八（含檔頭索引表）。
**08-17 追加**：黑洞 doom1~3.png（三張輪播）、卡包貼圖用新版 tcg.png 重新產生——
細節見 [art-assets.md](spike_well/.claude/docs/art-assets.md) 例外九。

**08-17 二訂＝音效首次接線＋甩尾三項調整**（全部只過機器稽核＋一次突變測試自我驗證，
尚未真人試玩）：
1. **音效系統首次建立**：使用者提供的 come/doom/pemaloe2/sheep/scream 七張來源檔
   （部分誤存 mp4）統一用 ffmpeg 轉 `.ogg` 匯入，接線三種——Raora 登場 stinger
   （come 三選一）、一般落地聲（jump）、石頭藥水落地聲替身（biboo_water 七選一，
   蓋掉 jump，視覺石屑效果不拿掉）。SOP 做成 skill `/import-sound-asset`，資產現況
   見 [audio-assets.md](spike_well/.claude/docs/audio-assets.md)（含 `jump.ogg` 來源
   對應是排除法猜的、猜錯怎麼改）。`doom.ogg`／`pemaloe2.ogg` 已轉檔匯入但這次沒接線，
   留給未來黑洞／Pameloe 音效用。
2. **甩尾推力調強**：`TAIL_KNOCKBACK_SPEED` 650→1600，根因是舊值低於玩家鍵盤全速
   1400、被自己的操作蓋過去感覺不到力道，新值明確超過兩種輸入模式的操控上限。
3. **甩尾瞄準延後鎖定**：`anchor_y` 從「WARN 剛開始」延到「WARN 結束、EXTEND 開始」
   那一刻才取樣玩家 y，收掉真人試玩回報「幾乎碰不到」的 1.35s 瞄準空窗；教學關固定
   瞄準指定平台，行為不變。`tests/audit_mechanics.gd` 新增一條回歸斷言，已用突變測試
   自我驗證（暫時還原舊行為 → 斷言真的紅 → 改回來確認綠）。
4. **甩尾改整根平移繪製**：`_draw_tail_bodies` 不再用伸長比例裁 UV（那樣尖端會被切成
   方頭），改成整張貼圖固定縮放、只做位移，裁切永遠切在固定的井壁線上，尖端一露出
   就是完整形狀。

**08-18 二訂＝主頁背景音樂系統首次建立 ＋ 死亡爆炸放大加速 ＋ 全域音量匯流排**（全部只過機器
稽核與截圖＋一次實跑聽感待驗，尚未真人試玩）：
1. **背景音樂**：使用者提供 kaela1/kaela2，新 autoload `SpikeAudio` 負責「主頁面家族狀態
   循環、每次隨機挑一首」（不是單首 loop，靠 `finished` 訊號重新隨機）。main.gd 在標題頁
   家族（開始／商店／成就／設定／名單）進場播、其餘狀態停。
2. **設定頁新增「音樂與音效」滑桿**（兩條滑桿 ＋ 兩顆靜音鈕）：控制的是新增的
   `BUS_MUSIC`／`BUS_SFX` 兩條音訊匯流排，不是逐一改音效音量；既有 SFX 節點的 `.bus` 這次
   一併指過去。設定頁原本七顆按鍵列就已經逼近可用高度上限，加這排一度把「返回」擠出圓角
   外框（smoke 通用版面掃描抓到，超出 110.6px）——改用單排橫向擠兩組滑桿 ＋ 內距 10→8
   才收乾淨，細節見 `.claude/docs/audio-assets.md` 例外四。
3. **死亡爆炸放大 1.5 倍 ＋ 加速 1.5 倍**：`DEATH_EXPLOSION_ART_SIZE` 240→360，
   `DEATH_FX_DURATION` 2.0s→2.0/1.5s（改一個常數，frame interval／碎片 life 自動連動）。
   音效來源 `explosion (1).mp4` 直接擷取音軌，沒有調速對齊——時間拉伸太多倍聲音會失真，
   保留素材原始節奏。
⚠ 音量／混音平衡（背景音樂會不會蓋過音效、爆炸聲夠不夠力）**没有真人試玩調過**，覺得吵/
小聲先改 `SpikeSave` 預設值或請使用者用新滑桿調。

**08-17 真人試玩回報＋當場拍板的十項**（細節見 HANDOFF_ARCHIVE.md）：騙人平台 **ok**（alpha／
拆半演出／金幣誘餌都過關，不用再驗）；卡包金幣雨**不用停下來撿也沒問題**（確認維持現狀）；
金幣雨數量 ×3；黑洞換 doom1~3.png 三張輪播（0.05s）＋紅色光暈（方案 A：柔和放射，範圍＝
DOOM_PULL_RADIUS）＋粒子吸入特效；tcg.png 重新匯入（卡包貼圖）；pebbles 改關卡二起、拿掉
690m 高度上限、新增「落到別的平台會存活、只有掉出畫面下緣才死」的落地邏輯（原本是直接
自由落體到底，跟使用者原始預期不符，已修正）；視野干擾 5s 暗/15s 亮→**7s 暗/20s 亮**；
屍體堆從「幾乎整個井寬」收攏成圍繞井中心的窄帶（集中感）。**以上全部只過機器稽核，
尚未真人試玩**——doom 光暈風格是 5 選 1 選出來的，粒子吸入手感、pebbles 落地存活的真實
節奏、屍體堆收攏後好不好看，都要下一輪真人玩過才知道。

**這次真人試玩重點（08-14 這批，全新未驗，仍待補）**：

1. **教學關整條**（改動最大）：500m 會不會太長、分段節奏讀不讀得懂、加密後夠不夠閃干擾、
   鞭子段與 jetpack 段是不是仍然「非用不可」而不是卡死。
2. pebbles 追人手感（速度／反應）／DAHLAH 偏移會不會煩。

**舊帳（仍未真人驗，細節見 archive）**：教學關十個教學點可讀性、死亡結算卡死因對應、
石化＋jetpack 轉速暈眩感、平台四態貼圖、1000m 斷層感、側風 3000m 轉折、關卡二／三爬完。
⚠ **solo 區間還卡不卡**最關鍵（落腳窗只剩 0.5px，常數已無調整空間；下一步是「solo band
有怪就保底多生一塊乾淨跳板」，會削壓迫感，留到真卡死再做）。高處可用右緣 `▲ +300 m` 直接
跳，會**正常記錄**（不算作弊局）。

> 🔎 使用者觀測（下個 session 開頭補上）：______

---

## 常青認知

**唯一的家＝[spike_well/.claude/docs/evergreen.md](spike_well/.claude/docs/evergreen.md)**
（20 條：稽核會騙人／貼圖繪製／生成鏈身分／UI 版面／成本估算五類）。**動對應系統前先讀**，
這裡不複製。2026-08-14 從本檔搬出（HANDOFF 撞 12KB 上限，且常青知識本來就不該住進度檔）。

---

## spike 執行方式

**唯一的家＝[spike_well/CLAUDE.md](spike_well/CLAUDE.md)「執行方式」**（跑法、回歸測試指令、
動態錄影、cp950／visual_check／Win32 點擊三個坑、三個大檔怎麼省 token 讀）。這裡不複製。
**這次改動該跑到哪一格**（改動類型 → 最小驗證集、各手段實測耗時、突變測試）＝
[verification-matrix.md](spike_well/.claude/docs/verification-matrix.md)。

---

## 🔜 itch.io 試玩發佈

**上架前檢查清單唯一的家＝[spike_well/checklist.md](spike_well/checklist.md)**（14 節逐項
核對；2026-08-16 首次盤點——存檔相容性／合規文件大部分已完成，細節見
[HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)「itch.io 上架前檢查清單首次盤點」；帳號／商店
美術／§0 四題決策仍待你執行，checklist.md 逐項列著）。這裡只留「跟這個 spike 本身怎麼跑」
有關的技術細節，不重複清單內容。

程式面已備妥（字型內嵌、標題、`stretch`），Export Templates 與 Web preset 到位、Run in
Browser 冒煙過關（08-07 驗證）。**只能在編輯器手動操作**。
**等修得差不多再做**（每改程式就作廢）：zip 打包／itch 頁面設定（Kind=HTML、
Viewport 1280×720、勾 Fullscreen）。

**改文案去哪改**：死因大字→`DEATH_LINE_*`（配對在 `WellWorld.death_line()`，`CAUSE_*` 只是
判定 id）；結算卡版面與按鈕／商店文案→`spike_ui.gd`；教學關字卡→`TUTORIAL_CUE_CARDS`
（按鍵一律寫 `{aim}` 模板）；版本號→`SpikeConfig.GAME_VERSION`；免責聲明→
`SpikeConfig.DISCLAIMER_TEXT`。⚠ 改過中文文案要重跑 `tools/subset_font.py`。

---

## 未動工但已有定論（**不要重新調查一次**）

1. **資源消耗**：健康，⚠ 不加物件池（零 `queue_free`，實體皆 `RefCounted` 純資料）。
2. **存檔相容性**：⚠ 仍未解的三個雷：改 key 名或刪 key、改欄位語意、**改 Godot 專案名稱**
   （＝全體玩家存檔消失，要列進發佈檢查清單）。08-13 已知情踩過第一個雷。
3. **榜單**：前置三項已做；後端與防作弊**等無盡難度曲線定案後再投**（現在做等於錨死一份要重寫
   的 schema，主欄位屆時從「最快登頂時間」換「最高高度」）。`levels` 永久升級已拍板**不分組**。
4. **i18n（中／英／日／印尼）**：字型已備；key 化／CSV **等手感定案後一次做完**。⚠ 現在就要守：
   文案一律整句模板 ＋ `format()`，禁止字串拼接（日／印尼文語序不同）。

---

## Deferred（未決清單）

完整清單見 [PILLARS_2.md](PILLARS_2.md)「未定案 → 仍未決」。摘要：

1. **待辦**：`PILLARS_2.md`「干擾升壓到必然墜落」那句要改寫成「高度足夠後必然墜落」（側風
   3000m 觸頂後才成立，1000m 關仍是純技術挑戰）。
2. ⚠ **主題區備援跳板會機率性擺不下**（正式待辦，**不准再靠換 seed 續命**，已換兩次）：25 顆
   seed 有 6 顆撞上（≈24% 局有純運氣牆）。根因＝備援板水平視窗被主鏈 MOVING 運動包絡線吃光
   （`_pick_x_apart` 的 ⚠⚠）。三個候選修法未拍板，列在該處註解。
3. 干擾期存活時長、探索死亡機率與產出規則、徵收比例是否綁梯度（舊基準過時，需按 20% 重算）。
4. 生成器自動可行性檢查——需把「抽跳板後仍可解」納入判定。
5. +75s buff 的生效綁定（建議自動綁下一次爬井）。
6. **金幣經濟未平衡** — 掉落率與 5 項升級價格都是初值；08-14 新增的卡包金幣雨會再推高收益，
   要一起重算。
7. **手機適配延後（統一電腦優先）**，守兩條可逆性條款：①不移除 `MOUSE_DRAG` 輸入模式
   ②新 UI 按鈕最小邊守 **44px**。⚠ 傾斜／陀螺儀控制已否決，別再提案。
8. **美術素材規範**（1280×720、2 倍碰撞尺寸、Linear＋Mipmaps）與已匯入清單，唯一的家＝
   [art-assets.md](spike_well/.claude/docs/art-assets.md)。
9. **（08-14）教學關可跳性稽核只驗垂直落差、不驗橫向出井** — `TUTORIAL_PLATFORMS` 某列 `x`
   改成 2000（遠在井外），`--only=tutorial` 仍然全綠。用 `mutation_check.py` 發現；補不補未拍板。

---

## 專案現況

- **階段**：pre-production。設計已收斂（v8）；爬井核心已有可玩原型；主專案仍無程式碼。
- **文件**：`PILLARS_2.md`（支柱）＋本檔＋`HANDOFF_ARCHIVE.md`＋`spike_well/CLAUDE.md`。
  **尚未建立** `PROJECT_MAP.md`。治理不搬 grab2 包，跨專案底線靠全域 `~/.claude/CLAUDE.md`。
