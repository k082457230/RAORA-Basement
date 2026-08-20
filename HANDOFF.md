# HANDOFF — RAORA

> 最後更新：2026-08-19
> 設計支柱唯一的家：[PILLARS_2.md](PILLARS_2.md)（現為 **v8**）
> 爬井 spike：[spike_well/](spike_well/)，專屬規則見 [spike_well/CLAUDE.md](spike_well/CLAUDE.md)，
> 偏離規格的現行規則見 [spike_well/.claude/docs/deviations.md](spike_well/.claude/docs/deviations.md)
> 歷史（發生過什麼）：[HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)

---

## 當前狀態

spike_well 08-10 起**定位轉正**（籌備 itch.io 首發）。Git 備份：
`https://github.com/k082457230/RAORA-Basement.git`（使用者私人帳號）。版本號
`SpikeConfig.GAME_VERSION` = `0.4.0`。

spike **v23 全綠**（七組稽核 ＋ bot 4 局；**各組項數以實跑輸出為準，不抄在這裡**）。
08-07～08-19 施工細節全在 [HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)；偏離規格現行規則
唯一的家＝[deviations.md](spike_well/.claude/docs/deviations.md)。

**08-19 三訂盤點結論**：Web／Windows 兩版首次 CLI 匯出成功並通過 §2.1 硬性規範 8 條；§0
四題拍板＝**Web＋Windows 下載版**／**免費不收贊助**／**長期更新前提成立**／**排行榜不進
v1.0**；聯絡方式與致敬名單已上線（新建 `CREDITS.md`）；素材授權盤點更正為**AI 生成素材
數量＝0，全部手繪原創**。細節全在
[HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)「三訂盤點」與「08-19 下半場」兩則。

**08-19 五訂：✓ 音樂／音效授權全部結案，✓ 頁面文案繁中主稿完成**。`cancan.ogg`／
`dies_irae.ogg` 換成公版／CC0 錄音（Musopen／archive.org）；35 個音效經使用者確認一般
來源（pixabay CC0 ＋ 直播截取）結案；YouTube 帳號（trailer 用）已確認。新建
[spike_well/store/description_zh.md](spike_well/store/description_zh.md)（itch.io 頁面
文案繁中草稿，§5.2 全段落齊）。**checklist §6.6 音樂授權阻塞項解除**——剩下真正卡住上架的
只剩**商店美術（封面／截圖）**與**itch.io 後台手動操作**，還有 EN/JA/ID 三語頁面待補。
細節見下方「08-19 五訂」歸檔。

**08-19 六訂：itch.io Draft 頁面已建立並完成上傳／嵌入／Payout 設定**。頁面「Raora's
Basement」狀態 Draft；兩包 zip 已上傳，`build_win` README 的【聯絡方式】欄補齊重新打包；
Web 版嵌入設定（HTML、1280×720、SharedArrayBuffer 關）與 Payout mode（Collected by
itch.io, paid later）皆已在真實頁面套用。新建
[spike_well/game_content_strings.tsv](spike_well/game_content_strings.tsv)（成就／buff／
商店升級／解鎖物品統一文案表，給使用者在 Google Sheet 編輯用，來源仍是 `spike_config.gd`）。
細節見 [spike_well/checklist.md](spike_well/checklist.md) §10.1「08-19 六訂」。

**08-20：主頁背景圖上線**。`spike_well/assets/sprites/bg_title.png`（使用者提供，透過
Google Drive 連結取得，2560×1440），取代主頁原本的純色底＋圓角卡片框，改成滿版背景圖＋
半透明暗化層＋原有 UI 疊圖（版面座標不變）。細節見
[art-assets.md](spike_well/.claude/docs/art-assets.md) 例外十四。**這次施工環境沒有本機
Godot 執行檔，未跑過 `--headless --import`／`smoke.tscn`／`visual_check.tscn`**——下個
session 或使用者本機第一件事：跑一次 import 讓新圖真的被 Godot 讀到，再肉眼確認主頁版面
沒有被壓到、文字在圖片上仍可讀。素材來源是否為 AI 生成也還沒核對，會影響
`checklist.md`「AI 生成素材數量」盤點，需要回頭跟使用者確認。

---

## ▶ 下個 Session 起點

### 🎯 真正卡住上架的三件事（音樂授權已於 08-19 五訂解除，見上）

1. **商店美術**：`store/cover_630x500.png`、`screenshot_01~05.png`、`banner.png`（選用）、
   `embed_bg.png` 全部待建，見 checklist §13 附錄 B。這是唯一還沒有任何草稿的項目，也是轉
   Public 前「被索引四條件」卡住的那一條（見 checklist §10.1）。
2. **itch.io 後台手動操作**：✅ 08-19 六訂已完成頁面建立（Draft）＋兩包 zip 上傳＋嵌入設定
   ＋Payout mode，見 checklist §10.1「08-19 六訂」。**還沒做**：①`store/description_zh.md`
   文案貼進頁面說明欄 ②theme editor 把 Layout > Screenshots 改 Sidebar（§13 附錄陷阱——
   HTML5 頁面預設會把 screenshots 欄藏起來）③其餘帳號層級設定（§1／§6.1／§6.2 各項打勾）。
3. **EN/JA/ID 三語頁面文案**：繁中主稿已完成（`spike_well/store/description_zh.md`），
   正式上架前至少應補英文版，見該檔檔尾清單。

> ✅ 08-19 收尾：「待實測／待拍板」四項已清（Web 存檔／音量滑桿真人實測過關、bot 鞭子週期
> 縮到 1.5 秒、錄影暫不接 HUD 層）。細節見 [HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)「08-19
> 收尾」。

**⚠ 等使用者補素材**（全部到位前相關畫面都是佔位）。08-19：petrify buff icon 已補齊（順便
修正 stone 原本配錯來源檔），滿版劇情圖／死亡爆炸確認 08-18 已上線——**但不是全清**，讀 code
確認還剩兩項未涵蓋：

1. **解鎖卡 icon**（`_unlock_glyph` 換 TextureRect，版面不動）— 仍是 Label placeholder。
2. **`_draw_blasts`（爆炸平台）** — 跟死亡演出（`_draw_death_fx`）是兩套獨立畫法，換了
   死亡演出不代表這個也換了，仍是純向量 placeholder。

細節見 [HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)「08-19 素材補齊」。

**已到位的美術／音效批次**（buff／道具 icon／卡包／pebbles／黑洞輪播／甩尾／聯絡方式 QR 等）
與音效系統、主頁 BGM、全域音量匯流排——索引見
[art-assets.md](spike_well/.claude/docs/art-assets.md)（含檔頭索引表），施工細節都在
[HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)，這裡不重複。

**這次真人試玩重點（08-14 這批，全新未驗，仍待補）**：

1. **教學關整條**（改動最大）：500m 會不會太長、分段節奏讀不讀得懂、加密後夠不夠閃干擾、
   鞭子段與 jetpack 段是不是仍然「非用不可」而不是卡死。
2. ✅ pebbles 追人手感（速度／反應）08-19 使用者確認 ok。DAHLAH 已退出抽池，偏移項目前
   不適用。

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
20 項因 D-4=否整節 N/A。**五訂後音樂授權阻塞項已解除、頁面文案繁中主稿已完成**，真正卡住
的剩上面「▶ 下個 Session 起點」列的三件事（商店美術／itch.io 後台操作／EN-JA-ID 三語）。

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
