# HANDOFF — RAORA

> 最後更新：2026-08-20
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

**08-19 三訂／五訂／六訂**：兩版出口規範過、§0 四題拍板、音樂＋35 音效授權全結案、
itch Draft 頁建立、素材盤點＝全手繪。細節全在 [HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)。

**08-20 離職交接**：雲端開發體系（Cloud→Actions→itch.io）已上線並實測全通，**遠端操作唯一
的家＝[REMOTE_OPS.md](REMOTE_OPS.md)**；Oracle VM 停在「未登入 Remote Control」斷點。細節見
archive「08-20 離職交接」。

**08-20 本機收工**：教學關發佈開關／解鎖卡 icon／金幣雨 flaky 根治／pebbles 預警爆炸／主頁
背景圖五項（本機補驗全綠），細節見 archive「08-20 晚間收工」。**待拍板四件**：
①`description_zh.md`「專屬教學關」文案與隱藏矛盾（改要重跑 subset_font）②pebbles 規格：
130px 觸發→紅閃 1s→90px 即死、倒數不可取消、殺掉解除 ③主頁「目標 1000m」灰字對比偏低
④`bg_title.png` 是否 AI 生成未核對。

**08-20 CI 改標籤制＋平板觸控自測層**：CI 拆 test（push master 丟 draft）／prod（push `v*`
tag 才丟正式），見 [REMOTE_OPS.md](REMOTE_OPS.md) §3.5。觸控層範圍限「使用者自測」，
**不等於解除 Deferred §7**（坑見 evergreen 24/25/26）。

**08-20 平板實測（使用者，itch test 頁）**：✅ 版面／五顆觸控鈕／基本操作都可行；
❌ **鞭子完全叫不出來**（長按畫面中央無反應）——已修，見下方起點 1。

**08-20 x（雲端 session）**：使用者規格三項全做完（裝置閘門＋二選一頁／鞭子獨立觸控鈕／
`←``→` 分置兩端），細節見 archive 同名條目。**沒有 Godot、一行沒實跑過**，起點 1 是驗證清單。

---

## ▶ 下個 Session 起點

### 🔴 1. 先跑 smoke，再上平板實測「觸控三項」

**一行沒實跑過**（雲端 session 沒 Godot binary，只靠 `gdlint`＋人工複查），細節見 archive
「08-20 x（雲端 session）：觸控三項＋裝置閘門」。驗證順序：
1. `Godot --headless --path spike_well --import` 再 `res://smoke.tscn` 全套（`gdlint` 只
   查語法，查不出邏輯）；`res://visual_check.tscn` 順便看一眼設定頁「控制」分頁有沒有溢出
   （`SETTINGS_CONTENT_HEIGHT` 420→500 是估算值）。
2. 平板/手機實測：二選一頁會不會出現／選了存不存得住、鞭子鈕按下去是不是真的進瞄準
   （慢動作）、再點畫面射不射得出去、`→` 鈕（貼右邊緣 y≈160~244）手指按不按得到、
   dev_mode 開著時會不會跟右上角 HUD／dev 三顆鈕意外疊到。

### 🔴 2. 驗完整雲端迴路（拿上面那件當實驗品）

claude.ai/code 是三週唯一入口，但**從未真的跑完一次改動**（08-20 收工時卡在 clone）。
要注意／要檢查的點全部在 [REMOTE_OPS.md](REMOTE_OPS.md) §6「迴路成熟度」＋§7
「雲端 session 檢查點」，**這裡不複製**。

### 🔴 3. 08-20 收工待辦（未過期部分）

1. **輪換 itch.io API key**（舊的曾出現在對話中）→ 更新 GitHub Secret `BUTLER_API_KEY`。
2. Oracle Console 設 $1 Budget Alert（任何非零費用即 email 通知）。

### 🎯 真正卡住上架的三件事（音樂授權已於 08-19 五訂解除，見上）

1. **商店美術**：`store/cover_630x500.png`、`screenshot_01~05.png`、`banner.png`（選用）、
   `embed_bg.png` 全部待建，見 checklist §13 附錄 B。這是唯一還沒有任何草稿的項目，也是轉
   Public 前「被索引四條件」卡住的那一條（見 checklist §10.1）。
2. **itch.io 後台手動操作**：頁面建立／zip 上傳／嵌入設定／Payout mode 已完成（見 checklist
   §10.1）。**還沒做**：①文案貼進頁面說明欄 ②theme editor 把 Screenshots 改 Sidebar（陷阱
   見 §13 附錄）③其餘帳號層級設定（§1／§6.1／§6.2）。
3. **EN/JA/ID 三語頁面文案**：繁中主稿已完成（`spike_well/store/description_zh.md`），
   正式上架前至少應補英文版，見該檔檔尾清單。

**⚠ 等使用者補素材**：08-19 那批已補齊（細節見 archive「08-19 素材補齊」），**只剩一項**：
`_draw_blasts`（爆炸平台）仍是純向量 placeholder——它跟死亡演出 `_draw_death_fx` 是兩套獨立
畫法，換了死亡演出不代表這個也換了。

**已到位的美術／音效批次**（buff／道具 icon／卡包／pebbles／黑洞輪播／甩尾／聯絡方式 QR 等）
與音效系統、主頁 BGM、全域音量匯流排——索引見
[art-assets.md](spike_well/.claude/docs/art-assets.md)（含檔頭索引表），施工細節都在
[HANDOFF_ARCHIVE.md](HANDOFF_ARCHIVE.md)，這裡不重複。

**真人試玩待驗（08-14 起未清，細節見 archive）**：教學關整條（500m 會不會太長、分段節奏、
鞭子段與 jetpack 段是否仍「非用不可」而不是卡死）、教學關十個教學點可讀性、死亡結算卡死因對應、
石化＋jetpack 轉速暈眩感、平台四態貼圖、1000m 斷層感、側風 3000m 轉折、關卡二／三爬完。
⚠ **solo 區間還卡不卡**最關鍵（落腳窗只剩 0.5px，常數已無調整空間；下一步是「solo band
有怪就保底多生一塊乾淨跳板」，會削壓迫感，留到真卡死再做）。高處可用右緣 `▲ +300 m` 直接
跳，會**正常記錄**（不算作弊局）。

> 🔎 使用者觀測（下個 session 開頭補上）：______

---

## 常青認知

**唯一的家＝[spike_well/.claude/docs/evergreen.md](spike_well/.claude/docs/evergreen.md)**
（26 條：稽核會騙人／貼圖繪製／生成鏈身分／UI 版面／成本估算／流程競態／觸控輸入）。
**動對應系統前先讀**，這裡不複製。

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
三訂後未勾 149 項，多數屬「現在做等於做白工」（等頁面／等 v1.0）。真正卡住的剩上面
「▶ 下個 Session 起點」那三件（商店美術／itch.io 後台操作／EN-JA-ID 三語）。

**Web 版匯出＋上傳已全自動**（08-20 起）：push 到 master → Actions 驗證 → 匯出 → butler 推
itch.io（維持 draft）。⚠ **Windows 版仍是手動**：

```
Godot --headless --path <spike_well> --export-release "Windows Desktop" ../build_win/RAORASBasement.exe
```

⚠ CI 的已知驗證缺口（`check_web_zip.py`／`subset_font.py` 都不在 CI 裡等四項）唯一的家＝
[REMOTE_OPS.md](REMOTE_OPS.md) §6。產物目錄都在 .gitignore，可重生。

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
7. **手機適配延後（統一電腦優先）**，守兩條可逆性條款：①不移除 `MOUSE_DRAG` ②新 UI 按鈕
   最小邊守 **44px**。⚠ 傾斜／陀螺儀控制已否決。**08-20 narrow exception**：加了自測用觸控層
   （見「當前狀態」），兩條可逆性條款未違反，**不等於本條拍板解除**——全面手機化仍未排程。
   **08-20 x**：裝置閘門已補上（`SpikeConfig.touch_ui_enabled()`，見起點 1），但未實機驗證。
8. **美術素材規範**（1280×720、2 倍碰撞尺寸、Linear＋Mipmaps）與已匯入清單，唯一的家＝
   [art-assets.md](spike_well/.claude/docs/art-assets.md)。
9. **（08-14）教學關可跳性稽核只驗垂直落差、不驗橫向出井** — `TUTORIAL_PLATFORMS` 某列 `x`
   改成 2000（遠在井外），`--only=tutorial` 仍然全綠。用 `mutation_check.py` 發現；補不補未拍板。

---

## 專案現況

- **階段**：pre-production。設計已收斂（v8）；爬井核心已有可玩原型；主專案仍無程式碼。
- **文件**：`PILLARS_2.md`（支柱）＋本檔＋`HANDOFF_ARCHIVE.md`＋`spike_well/CLAUDE.md`。
  **尚未建立** `PROJECT_MAP.md`。治理不搬 grab2 包，跨專案底線靠全域 `~/.claude/CLAUDE.md`。
