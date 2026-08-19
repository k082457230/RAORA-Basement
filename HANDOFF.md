# HANDOFF — RAORA

> 最後更新：2026-08-19
> 設計支柱唯一的家：[PILLARS_2.md](PILLARS_2.md)（現為 **v8**）
> 爬井 spike：[spike_well/](spike_well/)，專屬規則見 [spike_well/CLAUDE.md](spike_well/CLAUDE.md)，
> 偏離規格的現行規則見 [spike_well/.claude/docs/deviations.md](spike_well/.claude/docs/deviations.md)
> 歷史（發生過什麼）：[HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)

---

## 當前狀態

spike_well 08-10 起**定位轉正**（籌備 itch.io 首發）。Git 備份：
`https://github.com/k082457230/RAORA-Basement.git`（使用者私人帳號）。

spike **v23 全綠**（七組稽核 ＋ bot 4 局；**各組項數以實跑輸出為準，不抄在這裡**）。
08-07～08-14 施工細節全在 [HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)；偏離規格現行規則
唯一的家＝[deviations.md](spike_well/.claude/docs/deviations.md)。

**08-14 三塊施工細節**（v22 真人試玩後十項／驗證體系改造／美術接線流程改造）與
**08-17 真人試玩回報十項**：全部搬進 [HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)，這裡不重複。

**08-19 下半＝itch.io 三訂盤點（v23）：兩版首次真匯出 ＋ §0 四題拍板 ＋ 🔴 音樂授權紅線**
（不動玩法，smoke 全綠）。checklist 未勾項 176→149，另 20 項因 D-4=否整節 N/A。四題拍板＝
**Web＋Windows 下載版**／**免費不收贊助**／**長期更新前提成立**／**排行榜不進 v1.0**；另拍板
**本輪不動 i18n 主體**、**不加例行 `.bak`**。程式只改兩處：`SpikeSave._log_unknown_ids()`
（不認識的存檔 id 留一行 log）、`SpikeKeys.save()` 改原子寫入。
⚠⚠ **抓到一個一直沒人發現的錯誤前提**：`project.godot` 沒設 `rendering_method`，全專案吃
Forward+（Vulkan）——瀏覽器沒有 Vulkan。已加 **web-only** 覆寫
`renderer/rendering_method.web="gl_compatibility"`，桌面不動。
Web 版與 Windows 版**首次真的 CLI 匯出成功**，新工具 `tools/check_web_zip.py` 對真實 zip 驗
§2.1 **8 條全 PASS**，並在本機 HTTP server ＋ 瀏覽器實跑起來（gzip 後首次載入 ≈22 MB）。
🔴 **最大發現＝四首 BGM 的授權**：見下方阻塞項。細節全在
[HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)「第三次盤點」。

---

## ▶ 下個 Session 起點

### 🔴 阻塞項：四首 BGM 的授權（**沒解決前不得上傳任何 build**）

從 `.ogg` 內嵌 metadata 拿到的證據（原文見
[THIRD_PARTY_LICENSES.md](spike_well/THIRD_PARTY_LICENSES.md) C-2a）：`cancan.ogg` 是**倫敦
愛樂／指揮 Charles Gerhardt** 的商業錄音（曲子公版但錄音不是）、`dies_irae.ogg` 是**莫札特
安魂曲 K.626 第 3 曲**的某張商業專輯抓軌、`kaela1/2.ogg` 來源是**含 H.264 視訊軌的 MP4**。
🔒 已拍板：**四首全部替換**。接線點在 `autoload/spike_audio.gd`：`MAIN_BGM_PATHS`（kaela1/2）、
`GAMEPLAY_BGM_PATH`（cancan）、`INTERFERENCE_BGM_PATH`（dies_irae）。
替換 SOP ＝ 使用者挑檔 → 走 skill `/import-sound-asset` 轉檔匯入 → 只改上面三個常數。
⚠ 順帶：35 個音效帶 Clipchamp 浮水印 metadata（從影片抽的音軌），來源同樣待確認。

### ⚠ 待你實測（我做不了，需要真人瀏覽器）

1. **Web 存檔會不會掉檔**：已查證機制確有風險（IDBFS 非同步 sync＋Godot 無 `beforeunload`
   支援；`SpikeSave` 的原子寫入在 IDBFS 下**救不了**，因為 rename 也只發生在記憶體）。
   實測步驟寫在 [checklist.md](spike_well/checklist.md) §3.1。先量風險窗口有多寬，再決定要不要
   做「web 平台額外寫一份 localStorage」的治本修法。
2. **Web 版音量滑桿會不會動**：Godot 4.3+ web 預設 Sample 模式不支援 AudioEffect，而專案有
   `BUS_MUSIC`／`BUS_SFX` 兩條匯流排。匯流排音量理論上仍有效，但沒實測過（checklist §2.2）。
3. **README.txt 的【聯絡方式】欄**目前是「（待補：使用者的聯絡管道）」，上傳前必須填掉。

**⚠ 仍待你拍板的兩件**（三訂留下，三個 session 都沒動）：

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

**08-17 二訂（音效系統首次建立＋甩尾三項調整）** 與 **08-18 二訂（主頁背景音樂、全域音量匯流排、死亡爆炸放大加速）** 的施工細節已搬進 [HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)，這裡不重複。

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
核對；三次盤點的細節都在 [HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)，**這裡不重複清單內容**）。
2026-08-19 三訂後：未勾 149 項，其中 79 項屬「現在做等於做白工」（等頁面／等 v1.0 發佈），
20 項因 D-4=否整節 N/A，真正卡住的是**商店美術／頁面文案／itch.io 後台操作**與上面的音樂阻塞項。

**匯出已經不需要開編輯器了**（08-19 起，兩條都走 CLI）：

```
Godot --headless --path <spike_well> --export-release "Web" ../build_web/index.html
Godot --headless --path <spike_well> --export-release "Windows Desktop" ../build_win/RAORASBasement.exe
```

匯出後**一定要跑** `python tools/check_web_zip.py <zip>`（§2.1 硬性規範逐條驗，有 FAIL 就
exit 1）。產物目錄 `build_web/`／`build_win/` 都在 .gitignore，可重生。
⚠ **每改一次程式，上面兩個 zip 就作廢**——itch 頁面設定（Kind=HTML、Viewport 1280×720、
勾 Fullscreen、Layout>Screenshots 改 Sidebar）等修得差不多再做。

**改文案去哪改**：死因大字→`DEATH_LINE_*`（配對在 `WellWorld.death_line()`，`CAUSE_*` 只是
判定 id）；結算卡版面與按鈕／商店文案→`spike_ui.gd`；教學關字卡→`TUTORIAL_CUE_CARDS`
（按鍵一律寫 `{aim}` 模板）；版本號→`SpikeConfig.GAME_VERSION`；免責聲明→
`SpikeConfig.DISCLAIMER_TEXT`。⚠ 改過中文文案要重跑 `tools/subset_font.py`。

---

## 未動工但已有定論（**不要重新調查一次**）

1. **資源消耗**：健康，⚠ 不加物件池（零 `queue_free`，實體皆 `RefCounted` 純資料）。
2. **存檔相容性**：⚠ 仍未解的三個雷：改 key 名或刪 key、改欄位語意、**改 Godot 專案名稱**
   （＝全體玩家存檔消失，要列進發佈檢查清單）。08-13 已知情踩過第一個雷。
3. **榜單**：🔒 **08-19 拍板 D-4＝不進 v1.0**，v1 只做本機最高分，線上排行榜留 v1.1
   （checklist §3.2＋§11.4 共 20 項本版 N/A）。理由不變：無盡難度曲線沒定案，現在做等於錨死
   一份要重寫的 schema（主欄位屆時從「最快登頂時間」換「最高高度」）。`levels` 永久升級已拍板
   **不分組**。
4. **i18n（中／英／日／印尼）**：字型已備；🔒 **08-19 再次拍板本輪不動主體**——玩法還在改，
   現在把幾百條字串 key 化＋四語，之後每改一句要動四份。⚠ 現在就要守：文案一律整句模板 ＋
   `format()`，禁止字串拼接（日／印尼文語序不同）。目前只有免責聲明真的四語化
   （`DISCLAIMER_TEXT_BY_LANG`）。⚠ 語言鈕列實機版面（"Indonesia" 會不會撐爆）仍未驗。

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
