# HANDOFF_ARCHIVE — RAORA

從 [HANDOFF.md](HANDOFF.md) 溢出的歷史 session 摘要。**只放「發生過什麼」**——
現況與下一步永遠在 HANDOFF，設計數值正本在 [PILLARS_2.md](PILLARS_2.md)，
spike 的刻意偏離表在 [spike_well/CLAUDE.md](spike_well/CLAUDE.md)。

---

## 08-20 離職交接＝雲端開發體系上線（Cloud ＋ Actions ＋ itch.io 自動部署）

**背景**：使用者當日交還工作電腦，後續約三週只有手機＋平板（三週後新公司有電腦）。
目標＝三週內補完素材、讓 itch.io 頁面能從 draft 轉 public。

**選型裁決**：五條路（Oracle VM＋Telegram／claude.ai/code Cloud／GitHub Actions／
Codespaces／不做）評估後定案＝**Cloud 為主力、Actions 為安全網、VM 降為備用**。關鍵論據＝
VM 上的常駐 process 半夜掛掉時使用者在手機上無法搶救，Actions 無狀態不會死。原本「今天
必須架 VM，因為 Remote Control 的互動式登入今天做最容易」的理由，在使用者說明三週後有
新電腦後失效 → VM 收在「裝好但未登入」的斷點。

**建立的東西（全部實測過）**：
- `.github/workflows/smoke.yml`：push 自動跑七組稽核＋headless bot，判定依據＝
  `smoke.gd` 的 `quit(0/1)`。首輪即綠。
- 同檔 `deploy-web` job：smoke 綠燈後匯出 Web 版、butler 推 itch.io（維持 draft），
  版本標記 `ci-<run>-<sha7>`。金鑰走 GitHub Secret `BUTLER_API_KEY`。實測 1m25s，
  itch.io 端確認收到 `ci-4-56e99c0`。
- `REMOTE_OPS.md`（新建）：**無電腦期遠端操作資訊的唯一的家**。

**三環境輸出逐行數一致**（本機 Windows／Actions x86_64／Oracle VM aarch64）：皆 101 行、
exit 0、`[SMOKE] PASS`。**這個比對法是日後懷疑 CI 假綠燈時的標準做法。**

**Oracle VM 斷點**（161.33.14.206、user=ubuntu、Ampere A1 aarch64、同機跑 n8n）：
Claude Code 2.1.237 ＋ Godot 4.6.1 arm64 已裝、repo 已 clone 到 `~/RAORA`（deploy key
read-write）、七組稽核實跑通過。只差 Remote Control 的互動式登入。計費確認：4 OCPU/24GB
在 Always Free 上限內，**按「配置」計費不按用量**，多跑 Godot 與 Claude Code 不會多收錢。

**新踩的雷（五條）**：
1. 推含 `.github/workflows/` 的 commit 需要 token 有 `workflow` scope，否則 GitHub 端
   remote rejected。修法：`gh auth refresh -h github.com -s workflow`。
2. **Remote Control 不接受 `setup-token` 產的長期 token**，必須 `/login` 完整登入；官方
   也沒有開機自動重啟方案，只建議 tmux/screen。使用者當天特地生的一年期 token 因此用不到
   那條路（仍可用於 VM 上的非互動任務）。
3. `subset_font.py` 的來源字型原本被 gitignore → 雲端改中文文案後無法重跑子集化，Web 版
   新字變豆腐且在雲端修不了。已改為進版控（15.7MB 公版字型）。
4. **SharedArrayBuffer 不要勾**：本作 `variant/thread_support=false`（單執行緒匯出），
   勾了只會要求 cross-origin isolation、徒增 Safari/Firefox 相容性問題。（此處 AI 原本
   建議勾，被使用者既有的正確設定糾正，查 `export_presets.cfg` 確認後更正。）
5. itch.io 一個頁面只能有一個「在瀏覽器執行」的檔案；旗標留在舊檔上就會一直玩到舊版。

## 08-19 五訂＝cancan/dies_irae 換源結案 ＋ 35 個音效授權結案 ＋ 頁面文案繁中主稿

**BGM 換源**：使用者在 `Downloads/sound/BG/` 提供兩首來源明確的替代錄音——
`Offenbach_-_Orpheus_in_the_Underworld_-_Overture,_Can_Can_section.ogg`（Wikimedia
Commons，Musopen 錄製，公有領域）取代 `cancan.ogg`；`MozartK626Requiem3.DiesIrae.mp3`
（archive.org，CC0）取代 `dies_irae.ogg`。走 skill `/import-sound-asset` SOP：ffmpeg
`-c:a libvorbis -q:a 5 -map_metadata -1` 轉檔（`-map_metadata -1` 是新學到的一步——來源
mp3 本身還帶著 `album`／`Full Name=03 Dies irae?` 這類舊唱片抓軌痕跡的 tag，不清掉的話
照抄會讓新檔案又像商業專輯抓軌）＋自訂乾淨 metadata（title/artist/comment 含授權來源
網址）。`headless --import` 重新匯入、`smoke.tscn` 全套 PASS，且啟動階段不再出現舊版
`cancan.ogg` CP1251 編碼導致的 72 行 `Unicode parsing error`，間接證實舊檔案問題根源
已隨換源解決。路徑常數／播放邏輯不變（`SpikeAudio.GAMEPLAY_BGM_PATH`／
`INTERFERENCE_BGM_PATH`），純換音檔本體。細節見
[spike_well/.claude/docs/audio-assets.md](spike_well/.claude/docs/audio-assets.md) 例外八。

**35 個音效授權結案**：使用者確認與 `CREDITS.md` 素材聲明一致——多數取自 pixabay.com
（CC0），部分截自 Kaela／Raora／Bijou 直播片段。比照 `kaela1/2.ogg` 已接受的解套標準
（一般性口頭確認、非逐檔對照表）辦理，同樣結案。**checklist.md §6.6 音樂／音效授權阻塞
項至此全部解除**——這是三訂盤點以來卡最久的一項。

**文件同步**：`THIRD_PARTY_LICENSES.md`（`cancan`／`dies_irae` 移入 A 段明確授權，C-2／
C-3 舊風險盤點保留作稽核軌跡並加註已結案）、`CREDITS.md`（補上兩首新 BGM 授權來源）、
checklist.md（§6.6／頂部摘要／§13 附錄 B 同步）。

**YouTube 帳號確認**（checklist §1.3）：使用者提供帳號連結，與 `CREDITS.md` 既有登記的
`@paperstormingowo` 一致，已確認存在；trailer 影片本身尚未拍攝。`store/metadata.md`
External links 補上這個連結。

**頁面文案繁中主稿**：新建 `spike_well/store/description_zh.md`（checklist §5 交付物，
唯一的家），依「目前程式碼已實作的功能」逐項核對寫成（`well_world.gd`／`spike_config.gd`／
`spike_ui.gd`，**不採 `PILLARS_2.md` 的地下室經營長期願景**——那套系統程式碼裡完全沒做出來，
寫進頁面會違反 itch.io 品質指南「不得描述不存在的功能」，這是探索 agent 主動抓到的風險，
值得記一筆）。§5.2 全部段落齊（免責聲明中英雙語、遊戲簡介、特色列表、操作說明、系統需求、
實況政策、Credits、已知問題、更新方式、聯絡方式、語言支援說明、排行榜告知）。使用者拍板：
主稿先出繁中（英/日/印尼待補）、短介紹走直球資訊型、已知問題段落誠實揭露「約 1/4 局生成
偶爾出現刁鑽跳台區間」等 in-development 限制。checklist §5／§13 附錄 B 同步指向此檔。

---

## 08-19 四訂＝checklist.md 再瘦身（盤點記錄搬遷）＋ kaela1/2 音樂授權解套

**checklist.md 開頭三段盤點記錄（08-16／08-19 三訂／08-19 追加共 16 行）搬進本檔**，
checklist.md 開頭改成一段當前狀態摘要指向這裡，不重複貼。原文：

> ⚠ 2026-08-16 盤點：本檔只留「尚未實作」或「待你決定」的項目，已完成項目與判定依據
> 搬到 HANDOFF_ARCHIVE.md，這裡不重複貼。本次盤點新增的文件：SAVE_FORMAT.md／
> COMPATIBILITY.md／COMPLIANCE.md／THIRD_PARTY_LICENSES.md／CHANGELOG.md／test-matrix.md／
> store/metadata.md。各節「✓」開頭的引言是本次盤點加的狀態摘要，不是清單本身的一部分。
>
> ⚠ 2026-08-19 三訂（第三次盤點）：§0 四題全部拍板；Web 版與 Windows 版首次真的 CLI
> 匯出成功並通過 §2.1 硬性規範自動檢查（新工具 tools/check_web_zip.py）；§3.1 的
> IndexedDB 疑點已查證有結論；§6.6 音樂授權發現紅線級問題並降級為未勾（見該節）。細節見
> ../HANDOFF.md。
>
> ⚠ 2026-08-19 追加：§0 D-3（語言範圍）拍板＝中/英/日/印尼；§12 免責聲明四語補齊；§1.1
> itch.io 帳號全項驗證完成並歸檔（API key 唯讀端點實測）；設定頁新增「語言/名稱」分頁
> （§7.2 部分項目更新狀態）。細節見 ../HANDOFF_ARCHIVE.md「itch.io 上架前檢查清單第二次
> 盤點」。

**checklist.md §2.3（下載版）大段完成內容搬遷**：Windows 下載版 08-19 首次真的匯出成功，
`export_presets.cfg` 新增 `Windows Desktop` preset（release／64 位元／`embed_pck=true`
單檔），CLI 匯出 exit 0，產出 `RAORASBasement.exe`（113 MiB）＋ `README.txt`，打包成
`RAORASBasement_v0.1.0_win64.zip`（49.7 MB）。輸出目錄 `../build_win/`（已加進
.gitignore，比照 `build_web/`）。README 範本留在 `store/README_win_template.txt`，
三處引用值（按鍵／免責聲明／存檔路徑）皆從專案實際讀出，不是憑印象寫。⚠ 這份 08-19
上半場匯出的舊 zip，聯絡方式欄仍是「（待補）」；下半場已建 `SpikeConfig.CONTACT_EMAIL`
等四常數為 SSOT，下次重新匯出／打包 README 時要套用，這顆舊 zip 不會自動更新。

**checklist.md §3.1 Web 版存檔 IndexedDB flush 疑點結案**：`user://` 在 web 下走
Emscripten IDBFS，`FileAccess.close()` 只寫進 MEMFS 記憶體鏡像，真正落地 IndexedDB 靠
非同步 `syncfs()`，理論上「存檔後立刻關分頁」有競態窗口（Godot 無 `beforeunload`
支援）。真人實測：同一瀏覽器關閉分頁、重開後存檔正確保留，未觀測到掉檔。拍板**不做**
「web 平台額外寫 localStorage」治本修法，維持現狀。

**checklist.md §6.6 音樂授權：kaela1／kaela2 解套，cancan／dies_irae 仍卡住**：使用者
確認 `kaela1.ogg`／`kaela2.ogg`（主頁 BGM）來源是**偶像直播上隨口哼歌所截取下來的片段，
版權上沒有問題**——這條回答了 THIRD_PARTY_LICENSES.md「要問使用者的問題」第 4 題（原本
「未答，仍待確認」）。`cancan.ogg`（奧芬巴哈康康舞曲，倫敦愛樂／Charles Gerhardt 商業
錄音）與 `dies_irae.ogg`（莫札特安魂曲 K.626 第 3 曲，商業專輯抓軌）證據不變，**仍是
上架阻塞項**，使用者正在找替代版。checklist.md §6.6、THIRD_PARTY_LICENSES.md（C-2／
C-2a／「要問使用者的問題」第 4 題）、../HANDOFF.md 三處已同步更新阻塞範圍（從「四首
全部替換」收窄成「cancan／dies_irae 兩首待替換」）。

---

## 08-19 素材補齊＝petrify buff icon（順便修正 stone 配錯）／確認劇情圖與死亡爆炸已上線／pebbles 手感過關

**petrify（石化藥水）buff icon**：使用者提供 `biboo_water.PNG`／`woohoo.PNG`（`Downloads/素材/`），
描述文字分別對上 `SpikeConfig.BUFF_TABLE` 的 `"stone"`（每次踩上踏板的聲音改變）與
`"petrify"`（Kaela 開始旋轉）。核對發現：現有 `buff_stone.png`（08-14 匯入）視覺其實是
`woohoo.PNG` 那張醒石圖樣，跟 `"stone"` 的描述對不上，反而更像 `"petrify"`——判斷當初批次
匯入時來源檔配錯，`"petrify"` 因此一直沒有圖、留純色 placeholder。使用者確認後拍板：
`biboo_water.PNG` 換上 `"stone"`（覆蓋 `buff_stone.png`），`woohoo.PNG` 新增為
`"petrify"`（`buff_petrify.png`）。兩張都是來源 128×128 縮到 112×112（Lanczos），補進
`well_world.gd BUFF_TEX_PATHS`／`spike_ui.gd BUFF_ICON_PATHS` 兩份 key-value（皆為
`for key in dict` 泛用迭代，不用改載入邏輯）。`--import` 重新匯入、smoke 全套 PASS（含
OOB 掃描）；`visual_check.tscn` 的 `buff_intro_check_layout.png`（世界 orb）與
`hud_check_bottom_left.png`（HUD 格，臨時把 `grant_buff("pizza")` 換成 `("petrify")` 截圖
驗完後改回原樣）都截圖肉眼確認兩張新圖無 OOB、無破圖。`art-assets.md` 例外八、
`THIRD_PARTY_LICENSES.md` B 段已同步更新。

**滿版劇情圖／死亡爆炸確認已上線**：使用者提到這兩項「已加入」，讀 code 核實屬實——
`story_intro_1~4.png`（例外十一）與 `death_explosion_sheet.png`（例外十二）皆已在 08-18
完成上線，並非本次新增。⚠ 但「等使用者補素材」清單裡的另外兩項（`_unlock_glyph` 解鎖卡
icon、`_draw_blasts` 爆炸平台）**未被這批素材涵蓋**，讀 code 確認仍是 Label／向量
placeholder——使用者原本以為整段能全清，實際只清了 petrify 一項＋確認了已完成的兩項，
這兩項仍待補。

**pebbles 追人手感**：使用者確認 ok（08-14 那批全新未驗項目之一，這次真人試玩過關）。
DAHLAH 偏移手感因 DAHLAH 已退出抽池，目前不適用，恢復抽池時再驗。

---

## 08-19 收尾＝真人實測（存檔／音量滑桿）＋兩項拍板（bot 鞭子週期／錄影 HUD）

**Web 存檔／音量滑桿 persist**（原 HANDOFF「待你實測」兩項）：使用者真人瀏覽器實測——同一
瀏覽器關閉分頁、重開後，Web 版存檔與音量滑桿設定都有正確保留，未觀測到掉檔。理論風險窗口
（IDBFS 非同步 `syncfs()`＋ Godot 無 `beforeunload`）仍存在但正常關分頁情境已驗證通過；
拍板**不做**「web 平台額外寫 localStorage」治本修法，維持現狀。`checklist.md` §2.2／§3.1
兩項改勾 ✓ 並補實測結論。

**bot 鞭子週期 6→1.5 秒**（原 HANDOFF「仍待拍板」第 1 件，三個 session 沒動）：使用者拍板
比照 `record.gd` 縮短。改 `tests/bot_run.gd` 起手瞄準週期常數（`FPS * 6.0` → `FPS * 1.5`）。
smoke 全套重跑 PASS；run 2 鞭子路徑實測命中（射出 2／命中 2、射出 31／命中 4），確認稽核
不再是「恆為 0／0」的假路徑。

**錄影要不要接 HUD／UI 層**（原 HANDOFF「仍待拍板」第 2 件）：使用者拍板**暫不接**，維持
`record.tscn` 只建 `WellWorld` 的現狀；HUD 版面驗證繼續走 `visual_check.tscn` ＋ `audit_ui.gd`。

---

## 08-19 下半場＝版本號／聯絡方式＋致敬名單上線／素材授權盤點更正

**版本號**：`SpikeConfig.GAME_VERSION` `0.1.0`→`0.4.0`（`CHANGELOG.md` 同步記錄）。

**設定頁「工作人員名單」分頁從純佔位換成真實內容**：使用者提供 Email／X／YouTube／itch.io
四項聯絡方式與對應三顆 QR code（`personal/qrcode/*.png`，148~164px，登記進
`.claude/docs/art-assets.md` 例外十三）；新增素材聲明（美術全數使用者手繪、AI 生成數量＝0；
音效多數取自 pixabay.com CC0；死亡爆炸特效來源 YouTube Shorts 連結）、致敬與參考（Kaela／
Raora／Bijou 三個官方頻道，附註「部分音效截自其直播片段」）、特別感謝（三個帳號）。內容量
超過原本 `SETTINGS_CONTENT_HEIGHT`（420px）固定高度，改用 `ScrollContainer` 包住內容區
（`horizontal_scroll_mode` 關閉即可讓寬度貼齊、高度內部捲動），外殼（標題／分頁鈕列／版本號／
底部按鈕）位置維持跟其餘三個分頁一致，不是把共用常數調大。同步新建 `CREDITS.md`（checklist
附錄 B 原本待建項）、`store/metadata.md` External links 欄位填入四個致敬頻道連結、
`store/README_win_template.txt` 的【聯絡方式】欄位改指到 `SpikeConfig.CONTACT_*` 常數（SSOT）。
`visual_check.tscn` 截圖確認版面（QR 清晰可掃、無溢出、殼位置固定）；`tools/subset_font.py`
＋ `--import` 重跑；smoke 全綠兩次。

🔴→**已更正的重大發現**：`THIRD_PARTY_LICENSES.md` B 段（39 張貼圖）先前依
`.claude/skills/import-art-asset/SKILL.md` 的定位敘述（「AI 產生的圖」）＋ `COMPLIANCE.md`
自評，把全部貼圖歸類「專案慣例＝AI 生成」——**這是錯誤推測，不是使用者確認過的事實**。
使用者本次明確澄清：**AI 生成素材數量＝0，全部貼圖為使用者本人手繪原創**。已同步更正
`THIRD_PARTY_LICENSES.md` B 段（含總覽表、逐列「生成方式」欄）、`COMPLIANCE.md`「AI 生成內容
揭露提醒」一節、`store/metadata.md` 的 AI Disclosure 欄位（是→否）、checklist.md §6.2 對應
描述。「神似度是否與官方立繪太像」是獨立於此的另一個問題，跟是否 AI 生成無關，仍待使用者
親自目視確認，未受這次更正影響。

**補了幾條線索，但明確不等於結案**（`THIRD_PARTY_LICENSES.md` 已用醒目更正框標註，避免
之後被誤讀成「已解決」）：
1. 死亡爆炸來源影片：使用者提供出處＝`youtube.com/shorts/uW3FEhNNH1g`。這只回答「放在哪」，
   沒回答「這支影片的授權允許重新散布切幀畫面嗎」——單純連結不等於公眾授權，C-1 仍標記
   ⚠ 待確認。
2. 音效來源：使用者說明多數取自 pixabay.com（篩選 CC0），另有部分截自 Kaela／Raora／Bijou
   官方頻道的直播片段。**這是一般性說明，不是逐檔對照表**——C-3 全部 35 個檔案哪些屬於
   哪一類仍不清楚；「截自官方直播片段」這類額外涉及 hololive 二創「音楽/音声利用ガイドライン」
   是否涵蓋「內嵌進遊戲散布」，跟一般 CC0 音效庫是不同的合規問題，THIRD_PARTY_LICENSES.md
   「要問使用者的問題」已依此更新，建議下次盤點逐檔對一次。
3. 🔴 **四首 BGM 阻塞項完全不受這次補充影響，維持未解**：metadata 實測證據（`cancan.ogg`＝
   倫敦愛樂／Charles Gerhardt 商業錄音、`dies_irae.ogg`＝莫札特安魂曲商業專輯抓軌）跟
   「pixabay CC0」或「截自直播片段」是三件不同的事，不能互相取代結案，🔒 08-19 上半場已拍板
   的「四首全部替換」SOP 不變，見 HANDOFF.md 🔴 阻塞項。

---

## checklist.md 已完成項目歸檔（2026-08-19 下半場，清理瘦身）

checklist.md 從 627 行清出已完成的逐項核對紀錄，只留未完成／仍待你決定的項目。以下是搬出的
內容摘要（按原章節分組），細節如需要可用 `git log -p -- spike_well/checklist.md` 挖回來。

**§2.1 HTML5 硬性限制（8 項全 PASS，已移除逐項清單，只留頂端摘要）**：ZIP 打包、`index.html`
在根目錄、檔案數／容量／檔名長度上限、UTF-8 檔名、相對路徑、檔名大小寫一致、零非 HTTPS 請求、
不存取資料夾路徑——08-19 用 `tools/check_web_zip.py` 對真實匯出的 zip 全條驗證通過。

**§1.3 周邊帳號**：對外聯絡 email、社群帳號（X）皆已決定。

**§2.2 HTML5 版 Godot 專屬設定**：Godot 版本與 export templates 版本一致（4.6.1.stable）；
renderer 加了 web-only 覆寫 `gl_compatibility`；確認全專案零 C#；本機 HTTP server 實測可載入；
itch.io CDN 自動 gzip 免自行預壓縮；首次載入傳輸量實測 49.69 MB → gzip 後 ≈22.1 MB。

**§6.6 素材與音樂**：語音合成／Content ID／自製素材侵權三條禁止事項，程式面確認皆不適用
（專案無語音系統、無自動辨識系統接入、素材已個別登記來源）——這三條跟同節的 🔴 BGM 授權
阻塞項是兩件事，阻塞項維持未勾，見 checklist.md §6.6。

**§7.2 多語系**：免責聲明四語（繁/英/日/印尼）已全部寫進 `DISCLAIMER_TEXT_BY_LANG`，隨設定頁
語言選項即時切換（英/日/印尼三版是翻譯草稿，上架前建議母語人士覆核，見 checklist.md §12）。

**§11.3 ID 穩定性**：存檔讀到不認識的 ID 不會 crash（08-19 補上 `SpikeSave._log_unknown_ids()`
留痕，掛在 `levels`／`achievements`／`stats` 三處白名單回填之前，只印 log 不改行為）；按鍵等
設定檔新增欄位有預設值、不會整份重置舊存檔（`spike_keys.gd load_binds()` 查證本來就滿足）；
同日順手把 `SpikeKeys.save()` 從直接覆寫改成原子寫入。

---

## 08-14 三塊 ／ 08-17 真人試玩十項 施工細節（2026-08-19 從 HANDOFF.md 搬下來）

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

**08-17 真人試玩回報＋當場拍板的十項**（細節見 HANDOFF_ARCHIVE.md）：騙人平台 **ok**（alpha／
拆半演出／金幣誘餌都過關，不用再驗）；卡包金幣雨**不用停下來撿也沒問題**（確認維持現狀）；
金幣雨數量 ×3；黑洞換 doom1~3.png 三張輪播（0.05s）＋紅色光暈（方案 A：柔和放射，範圍＝
DOOM_PULL_RADIUS）＋粒子吸入特效；tcg.png 重新匯入（卡包貼圖）；pebbles 改關卡二起、拿掉
690m 高度上限、新增「落到別的平台會存活、只有掉出畫面下緣才死」的落地邏輯（原本是直接
自由落體到底，跟使用者原始預期不符，已修正）；視野干擾 5s 暗/15s 亮→**7s 暗/20s 亮**；
屍體堆從「幾乎整個井寬」收攏成圍繞井中心的窄帶（集中感）。**以上全部只過機器稽核，
尚未真人試玩**——doom 光暈風格是 5 選 1 選出來的，粒子吸入手感、pebbles 落地存活的真實
節奏、屍體堆收攏後好不好看，都要下一輪真人玩過才知道。

---

## itch.io 上架前檢查清單第三次盤點（2026-08-19 下半）—— §0 四題拍板、兩版首次真匯出、音樂授權紅線

> 起點：使用者要求「先把沒 commit 的 commit，然後把 checklist 能處理的盡量處理掉，需要判斷的
> 先討論選項，需要親手做的給 SOP」。剩餘 176 項先分四桶（agent 可代做 45／要你拍板 12／
> 只有你能做 40／現在做白工 79），再依桶推進。

### 拍板的六件事（§0 四題 ＋ 兩個技術小決策）

| 決策 | 結果 | 連帶影響 |
|---|---|---|
| D-1 發佈形式 | **Web ＋ Windows 下載版** | 不做 mac／Linux（無實機可實測，itch.io 要求平台標記須實測） |
| D-2 售價 | **0 元、不接受贊助**（鎖死） | — |
| D-0 長期更新前提 | **成立** | §11.2／§11.3 的存檔設計就是為它做的 |
| D-4 排行榜 | **不進 v1.0**，留 v1.1 | §3.2（14 項）＋ §11.4（6 項）整兩節本版 N/A |
| §7.2 i18n 主體 | **本輪完全不動** | 玩法還在改，現在 key 化會反覆重工；規矩不變：整句模板＋`format()`，禁字串拼接 |
| §11.2 例行 `.bak` | **不加**（維持三個風險時刻才備份） | web 版 IndexedDB 用量不 ×4 |

### 程式改動（兩項，皆使用者勾選）

1. **`SpikeSave._log_unknown_ids()`**（新函式）：掛在 `levels`／`achievements`／`stats` 三處白名單
   回填**之前**，讀到目前資料表沒有的 id 就印一行留痕。只印、不改變行為——白名單回填仍然照
   丟，真正的正解是內容下架時把 id 留在表裡標 deprecated（政策見 COMPATIBILITY.md）。
   ⚠ `corpse_deaths`／`story_seen` 不比對白名單（key 是關卡×模式的組合），不在涵蓋範圍。
2. **`SpikeKeys.save()` 改原子寫入**：原本直接覆寫，現在比照 `SpikeSave.save()` 走
   「寫 `.tmp` → 讀回驗證 JSON → `rename_absolute`」。順帶查證了 §11.3 那條標「待查」的
   ——`load_binds()` 先 `_reset()` 鋪滿 `DEFAULT_KEYS` 再只覆寫存檔裡有的 key，**新增動作不會
   把玩家舊綁定整份重置，本來就滿足**，不需要改。

### Web 版：首次真的 CLI 匯出，並在瀏覽器跑起來

- ⚠⚠ **抓到一個一直沒人發現的錯誤前提**：`project.godot` 的 `[rendering]` **完全沒有**
  `renderer/rendering_method`，整個專案吃引擎預設 **Forward+（Vulkan）**。checklist §2.2 原本
  寫「08-07 Run in Browser 能跑 ⇒ 當時用的是相容設定」——**那個推定不成立**。
  修法：只加 web-only 覆寫 `renderer/rendering_method.web="gl_compatibility"`，桌面維持 Forward+。
- CLI `--export-release "Web"` 匯出 exit 0；templates 版本 `4.6.1.stable` 與編輯器一致，
  `web_nothreads_release.zip` 存在（對應 `variant/thread_support=false`）。
- **新工具 `tools/check_web_zip.py`**：吃一個 zip，逐條驗 §2.1 全部硬性限制（zip 格式／
  index.html 在根／檔案數／總容量／單檔容量／路徑長度／UTF-8 檔名／絕對路徑引用／檔名大小寫
  一致），任何 FAIL 就 exit 1。**每次重新匯出都要重跑**。
  實測：9 檔／49.7 MB／最大 `index.wasm` 35.9 MB／最長路徑 31 字元／絕對路徑 0 筆／12 處引用
  大小寫全一致 ⇒ **8 條全 PASS**。
- **本機 HTTP server ＋ 瀏覽器實跑**：`python -m http.server` 服務 `../build_web/`，遊戲確實載入
  並跑起來（分頁標題 `RAORA'S BASEMENT`、有 WebGL draw call、IndexedDB 建立了 `/userfs`
  資料庫與 `FILE_DATA` object store）。
- **載入體積**：`index.wasm` 35.94→gzip **8.96 MB**、`index.pck` 13.44→gzip **13.10 MB**（97.5%，
  幾乎壓不動，裡面已是壓縮過的貼圖／字型子集／ogg）、總計 49.69 MB → **≈22.1 MB**。
  ⇒ 要減體積只能砍內容，不是調壓縮設定。
- ⚠ **§2.2 音訊那條的「現況：專案零音效系統」註記已過期**，該項重新變成待驗：Godot 4.3+ web
  預設 Sample 模式不支援 AudioEffect，而專案 08-18 起有 `BUS_MUSIC`／`BUS_SFX` 兩條匯流排＋
  設定頁滑桿。匯流排音量理論上仍有效，但**沒在瀏覽器實測過滑桿會不會動**。

### Windows 下載版：首次匯出

`export_presets.cfg` 新增 `Windows Desktop` preset（release／64 位元／`embed_pck=true` 單檔）。
產出 `RAORASBasement.exe`（113 MiB）＋ `README.txt`，打包成 `RAORASBasement_v0.1.0_win64.zip`
（49.7 MB），輸出到 `../build_win/`（已加進 .gitignore，比照 `build_web/`）。
README 三處都是從專案**實際讀出來**的：按鍵取自 `DEFAULT_KEYS`＋`KEY_NAMES`；免責聲明逐字抄
`DISCLAIMER_TEXT_BY_LANG` 的 zh／en；存檔路徑
`%APPDATA%\Godot\app_userdata\RAORA'S BASEMENT\` 是**用匯出的 exe 實跑後確認資料夾裡真的有
`spike_save.json`／`spike_keys.json`**，不是純推導。範本留在 `store/README_win_template.txt`。

### 🔴 音樂授權：本次最大發現（上架阻塞項）

發現鏈路值得記下來，因為它示範了「雜訊裡藏著紅線」：

1. 瀏覽器實跑 Web 版時，Godot 開機固定印 **72 行 `Unicode parsing error`**。
   （⚠ 這 72 行在 headless smoke 的輸出裡**一直都在**，只是被 CLAUDE.md「只讀 `[SMOKE]` 與 `!!`
   行」的省 token 規則濾掉了——省 token 規則會濾掉真訊號，這是它的已知代價。）
2. 追根因 → `cancan.ogg` 的 Vorbis comment 是 **CP1251 俄文編碼**，Godot 用 UTF-8 解析失敗。
3. 順勢把 39 個 `.ogg` 的內嵌 metadata 全 dump 出來 → **拿到四首 BGM 的來源證據**：

| 檔案 | 用在哪 | metadata 原文（節錄） | 判定 |
|---|---|---|---|
| `cancan.ogg` | 井內 BGM | `artist=Ж.Оффенбах` `date=1858`／`DESCRIPTION=Лонд.филар.орк. п.у. Ч.Герхарда` | 曲子公版（奧芬巴哈康康舞曲），但演奏＝**倫敦愛樂／指揮 Charles Gerhardt**，商業錄音、鄰接權未到期 |
| `dies_irae.ogg` | 干擾期 BGM | `artist=Wolfgang Amadeus Mozart`／`album=Requiem K 626…`／`Full Name=03 Dies irae` | **莫札特安魂曲第 3 曲**（不是額我略聖歌），`03 …` 是典型 CD 抓軌命名 |
| `kaela1/2.ogg` | 主頁 BGM | `compatible_brands=isomiso2avc1mp41`（title／artist 被剝光） | `avc1`＝H.264 ⇒ 來源是**含視訊軌的 MP4** |
| 35 個音效 | 各處 | `DESCRIPTION=Create videos with https://cl…` | Clipchamp 匯出浮水印 ⇒ 從影片抽的音軌 |

**「曲子公版」≠「這個錄音公版」**——整組 BGM 都落在這裡。
🔒 拍板：**四首全部替換成來源明確可用的音樂**；替換完成前不得上傳任何 build 到 itch.io。

### 文件產出

- **`THIRD_PARTY_LICENSES.md` 完全改寫**：41 張貼圖＋39 個音檔全部登記，分 A（明確授權：Noto
  Sans CJK TC = OFL 1.1、Godot = MIT）／B（自製・AI 生成，39 張貼圖）／C（來源待確認：2 張貼圖
  ＋全部 39 個音檔）三段，另加 **C-2a「檔案內嵌 metadata 實測」** 小節放上面那張證據表。
  與 `.claude/docs/art-assets.md`／`audio-assets.md` **雙向對照無落差**——落差不在「登記與檔案
  不符」，而在「登記了但沒寫授權來源」。文件末列 7 題待使用者回答。
- **`COMPLIANCE.md` 補完 §6 逐條自評**：每條都有判定（✓／⚠／✗／N/A）＋**可回溯的查證依據**
  （`檔案:行`）。已符合 8 條，其中：標題畫面免責聲明確實接線（`spike_ui.gd:2239-2242` →
  `SpikeConfig.disclaimer_text()`）；**零變現程式碼**（grep `IAP|purchase|donat|advertis|admob|
  sponsor` 全 repo 零命中，商店 `buy()` 扣的是遊戲內 `coins`）；遊戲命名不誤導。
- **`checklist.md` 三訂**：未勾項 176 → 149，另有 20 項因 D-4 = 否整節標 N/A。

### 這次的方法論筆記

- 176 項先分四桶（agent 代做／你拍板／你親手做／現在做白工）再動手，比逐節推進省很多——
  D 桶（等匯出／等頁面／等 v1.0 發佈）就佔了 79 項，一開始就不該碰。
- 五支 sonnet 子 agent 平行跑（web 匯出、合規自評、IndexedDB 查證、授權登記、Windows 匯出），
  彼此檔案不重疊；`checklist.md` 一律由主線統一改，禁止 agent 碰，避免衝突。

---

## 08-17 二訂／08-18 二訂 施工細節（2026-08-19 從 HANDOFF.md 搬下來）

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

---

## itch.io 上架前檢查清單第二次盤點（2026-08-19）—— 語言/名稱設定頁 ＋ 免責聲明四語化 ＋ 帳號盤點歸檔

**這次做的三件事**（對應使用者當面交辦，非例行盤點）：

**1. itch.io API key 驗證**：使用者提供的 API key 打 `https://itch.io/api/1/<key>/me` 與
`/my-games` 兩個唯讀端點皆回 200——帳號存在（username `paperstormingowo`，顯示名稱
`owo9987`，`developer:true`），目前掛零已發佈的 game（`/my-games` 回傳空物件）。這把
checklist.md §1.1「itch.io 帳號」那組全部 6 項的完成狀態坐實，一併歸檔到本節（見下）。
⚠ 這支 key 只能讀帳號基本資訊與已發佈的 game 列表——itch.io 官方 API 本身沒有「推 build」
的端點，真的要推新版本一律得靠 `butler` CLI（checklist.md §11.5 已經記過這件事，這裡
沒有新結論，只是這次順手用同一把 key 實測確認讀取路徑通）。

**2. 免責聲明四語化（checklist.md §12 附錄 A）**：`SpikeConfig.DISCLAIMER_TEXT` 常數改成
`DISCLAIMER_TEXT_BY_LANG` 字典 ＋ `disclaimer_text(lang)` 查表函式，繁中/英/日三語直接照
checklist §12 範本抄，新增印尼文版本（checklist 原範本沒有這一語，是這次因為使用者要
四語系統而補譯的草稿，上架前建議找母語人士覆核，尤其日文——COVER 是日本公司）。
checklist.md §0 D-3（語言範圍）原本待拍板，這次借這個機會定案為「中/英/日/印尼」四語，
已在 checklist.md 打勾並記錄。

**3. 設定頁「名稱設定」分頁從佔位改成真內容**（08-18 三訂建立分頁按鈕時說好「先佔位」，
這次補上），改名「語言/名稱」：
- a. 語言切換：四顆按鈕（`SpikeConfig.LANGUAGE_ORDER`），選到的用 `C_ACCENT` 反白，寫入
  `SpikeSave.language` 並落盤。**目前只有一段文字真的跟著切**——工作人員名單分頁的免責
  聲明（`SpikeUI._apply_language()` 統一套用點）。這是刻意的最小驗證切片，不是完整
  i18n：其餘 UI 文案還沒 key 化，checklist.md §7.2 主體仍待做（`HANDOFF.md`「未動工但
  已有定論」第 4 條原本就寫死等手感定案後一次做完，這次沒有推翻那個決定，只是先把
  「語言旗標可以切、切了之後有東西真的變」這條路走通）。
- b. 玩家顯示名稱：`LineEdit` 輸入，失焦或按 Enter 時寫入 `SpikeSave.player_name` 並
  落盤（`SpikeSave.set_player_name()`）。做為未來排行榜暱稱先鋪的欄位（checklist.md
  §3.2）。**沒有做「資料庫查重複、顯示第幾位」**——排行榜後端本來就還沒有（HANDOFF
  「未動工但已有定論」第 3 條：等無盡難度曲線定案後再投），欄位下方目前顯示誠實的提示
  文字（`SpikeConfig.NAME_RANK_UNAVAILABLE_HINT`：「排行榜尚未開放，暫時無法比對重
  名」），不是假造一個「第 1 位」出來騙人。真的接上後端時只要換掉
  `SpikeUI._refresh_name_rank_label()` 裡那一行判斷，輸入框與存檔欄位都不用動。

**存檔格式**：`SpikeSave` 新增 `player_name`（String）／`language`（String，只認
`SpikeConfig.LANGUAGE_ORDER` 裡的旗標，認不得的退回 `LANGUAGE_DEFAULT`），比照
`bgm_volume` 那組「設定不是進度」的既有慣例，`wipe()`／`clear_runtime()` 不清這兩顆。
**改過中文文案後重跑了 `tools/subset_font.py`**（新增「語言/名稱」「系統語言」「玩家
名稱」等字，子集後 1668 字、417 KB）。

**驗證**：headless `--import` 0 error（重跑兩次，加新字型後再跑一次）；headless
`smoke.tscn` 全組 PASS；另外直接 headless 跑 `Main.tscn --quit-after 30` 確認
`SpikeUI.build()`（含新的語言/名稱分頁建構）本身不丟 script error。**沒有跑過的**：
`visual_check.tscn` 目視——四顆語言鈕的寬度（`LANG_BUTTON_SIZE`）是估算值，最長標籤
"Indonesia" 有沒有把按鈕撐爆版**沒有實機截圖驗證過**，下一輪建議先看一眼。

**itch.io checklist.md §1.1「itch.io 帳號」全項歸檔**（6 項全部完成，原文如下，歸檔
理由：本次盤點確認全部打勾，依 checklist.md 頁首慣例移出正文）：
- 註冊 itch.io 帳號（免費）。
- 慎選 username：它同時是網址 `username.itch.io` 也是頁面作者名，上架後再改會破壞
  所有外部連結。
- username 不使用「〇〇工作室 / Studio / Team / サークル名」（§6.3 二創遊戲指南對法人／
  社團名義有明確限制）。
- 開啟兩步驟驗證（2FA）。
- 填寫個人頁：頭像、簡介、對外聯絡方式。
- 確認帳號限制夠用：新帳號預設專案頁上限 20 個、單頁檔案建議 10 個以內。

## 偏離表沿革／理由存底（2026-08-10，spike_well/CLAUDE.md 瘦身搬遷）

原 `spike_well/CLAUDE.md`「已知的刻意偏離規格」表的沿革與理由全文搬到這裡（現行規則精簡版留在原表）。查特定項目直接 Grep 項目名稱即可定位。

### 終點

- PILLARS_2.md：無終點，干擾升壓到必然墜落
- spike（原表全文）：**08-10 二訂：關卡制 ＋ 無盡模式並存**。有終點時抵達 `goal_meters` 就成功結算（`cleared` 訊號重新接回 `_check_end`）；無盡模式（右上角開關）走「沒有終點、爬到死」那條。地形軸仍於 `DIFFICULTY_RAMP_HEIGHT_M`（1000m）封頂，側風 `SHOCKWAVE_RESPONSE` 不封頂、每 500m 一階 ×1.23
- 理由／沿革：使用者拍板。⚠ 08-09~08-10 之間 `cleared` 一度沒有任何 emit 端（那次把 1000m 強制結束整段拿掉了），連帶讓三個登頂成就打不到；本次接回後**任一關卡登頂都算 cleared**（使用者拍板），那三個成就的判定條件不必改

### 關卡

- PILLARS_2.md：無此概念
- spike（原表全文）：**三關：1000／1500／2000m**（`LEVEL_GOALS`）。抵達即成功結算＋解鎖下一關＋播該關劇情（本輪只有佔位文字）；已解鎖的關可自由回頭重玩。主頁選關列在「開始遊戲」上方，未解鎖顯示「？？？」
- 理由／沿革：使用者拍板（08-10）。⚠⚠ **08-10 二訂：「關卡只改哪裡結束」改成白名單制**——使用者推翻原本的全面禁止（原話：「不同關卡之間應該還是要有些差距，不然會感覺是重複挑戰完全相同的東西，肌肉記憶不至於到這麼弱」）。現行規則：① **預設仍然禁止**隨關卡改變高度→難度對應，所有隨高度變化的軸一律綁 `DIFFICULTY_RAMP_HEIGHT_M` / `PRESSURE_STEP_HEIGHT_M`，不准綁 `goal_meters`；② 要讓某個東西「第 N 關才出現」，**必須登記進 `SpikeConfig.LEVEL_GATED`**，沒登記一律視為違例。⚠ 白名單不是免驗而是換一種驗法：`tests/audit_levels.gd` 的難度不變性現在**正向驗**白名單項目真的隨關卡有差（門檻以下為 0、以上 > 0），沒有這一段的話「白名單」就只是「不驗」的同義詞，把機率手滑設成 0 照樣全綠。⚠ 加新的關卡差異要動兩個地方（登記 + 把受影響的取樣項排除），刻意做成顯式動作。08-10 前已修掉唯一一條違例 `pameloe_chance_at`

### 無盡模式

- PILLARS_2.md：無此概念
- spike（原表全文）：主頁右上角第三顆開關（跨局記住）：**這一局不在 `goal_meters` 停局**，爬到死為止。與關卡、極限兩個維度**完全獨立**，可任意組合
- 理由／沿革：使用者拍板（08-10）。⚠ 讀取端一律走 `SpikeConfig.eff_has_goal()`，不直接讀 `SpikeSave.endless_mode`（同 `eff_*` 那組的理由：模式規則只能有一個家）。⚠ 無盡局**不解鎖下一關、不算登頂成就、不記登頂用時**——沒有終點就沒有「抵達終點」這件事

### 局長

- PILLARS_2.md：無干擾期 120s
- spike（原表全文）：短局 **67s**，四階每隔 20s：**67／87／107／127s**
- 理由／沿革：使用者拍板（v13）。⚠ 四個 `stage_*_offset` 必須兩兩不等，設成一樣會讓中間那階永遠跳過（曾經真的發生過，冒煙測試現在有一條專驗這件事）

### 干擾種類

- PILLARS_2.md：三種
- spike（原表全文）：**四種**（＋黑洞 doom）
- 理由／沿革：使用者拍板，見下方「黑洞」列

### 鞭子次數

- PILLARS_2.md：初始 10、**硬上限 12**
- spike（原表全文）：初始 **5**、升級上限 **+3（＝8）**
- 理由／沿革：使用者拍板。PILLARS 那條 12 的硬上限已不適用

### 鞭子拉近

- PILLARS_2.md：「定速拉近」
- spike（原表全文）：給加速度，過錨點才還控制權
- 理由／沿革：使用者當面改的規格

### 鞭中怪物

- PILLARS_2.md：「擊退」
- spike（原表全文）：擊退 ＋ 仍纏住拉過去
- 理由／沿革：使用者要求怪物也是可纏標的，兩者合併

### jetpack 燃料

- PILLARS_2.md：上限寫死，**不得進升級表**（:384）
- spike（原表全文）：進升級表，但初始砍半（110→55m），升滿才回到 110m；另加**消耗倍率 ×1.5**
- 理由／沿革：使用者拍板。天花板沒被推高，只是把起點往下挪。強勢度用**消耗端**削（`JETPACK_FUEL_BURN_MULT`），不砍上限——砍上限會連帶削掉升級表的價值感

### jetpack 噴射的無敵窗與使用間隔

- PILLARS_2.md：無此概念
- spike（原表全文）：08-10：噴射結束後的無敵餘韻從共用的 0.5s（`INVULN_GRACE`，鞭子／彈射板／蟲洞過場仍用這顆）改窄成 jetpack 專屬的 **0.2s**（`JETPACK_INVULN_GRACE`）；另加一條「上一段噴射結束後要間隔 `JETPACK_COOLDOWN`(**0.6s**) 才能再噴」的冷卻
- 理由／沿革：使用者拍板。⚠ 冷卻跟 `JETPACK_SPOOL_TIME`(0.2s，冷啟動) 是兩件不同的事——一個管「按下去到噴出來」的延遲，一個管「噴完到能再按」的空窗，兩者互不相干、可以同時存在（見 `WellPlayer.jetpack_cooldown_timer` 與 `WellWorld._step_jetpack` 的判斷順序）。⚠⚠ 無敵窗拆成兩顆計時器（`invuln_timer`／`jetpack_invuln_timer`）是因為只有 jetpack 這一個來源要變短，鞭子／彈射板／蟲洞過場維持原本規則、不能被連坐改掉

### 蟲洞守門

- PILLARS_2.md：v4 提案：出口 2 秒下墜內必有可救落點（待確認）
- spike（原表全文）：**出口固定綁定一塊不會動的平台**
- 理由／沿革：使用者拍板。比 v4 提案更強也更好驗；生成器稽核直接量得到

### 蟲洞轉場

- PILLARS_2.md：未規定
- spike（原表全文）：**0.5s 順滑過場**（相機與玩家共用一條 `smoothstep`），過場中凍結物理＋全程無敵
- 理由／沿革：使用者拍板要「像彈跳版的畫面平移」。干擾計時**不停**（過場不是免費喘息），只 `suppress_spawn` 避免預警瞄準一個馬上就不在的位置

### 戰利品商店

- PILLARS_2.md：分數制 ＋ 單次／永久兩檔
- spike（原表全文）：金幣直接買永久升級，無單次檔
- 理由／沿革：spike 只驗「有沒有回訪動機」，分數換算留給正式版

### 資源種類

- PILLARS_2.md：只有物資一種
- spike（原表全文）：＋**燃料補給**（300m 以上、固定補 **7m**、滿載不消耗）
- 理由／沿革：使用者拍板。走獨立機率、只長在沒金幣的板上，金幣掉落率不被稀釋。08-09 改定值：原本補「上限的 10%」會隨升級放大，改成固定公尺數

### 攀爬

- PILLARS_2.md：無此概念
- spike（原表全文）：**攀爬手套**（商店第 6 項，有／無兩態）：頂點差一點時補一次小跳，成功時放白色同心圓擴散特效
- 理由／沿革：使用者拍板。改的是容錯率不是可達性——生成器仍用基礎 `MAX_JUMP_HEIGHT`，間距不會跟著放寬。特效是因為「買了 220 元卻看不出有沒有生效」

### 燃料補給機率

- PILLARS_2.md：無此概念
- spike（原表全文）：隨高度**遞減**（0.20 → 0.13）
- 理由／沿革：使用者拍板。跟金幣（遞增）刻意反向：高處已經夠難，jetpack 不能變成後期的萬能解

### 投擲物

- PILLARS_2.md：「從上方落下」
- spike（原表全文）：邊落邊轉的長方形 ＋ **落點提前 2s 預警**（畫面上方閃紅三角）
- 理由／沿革：使用者拍板。落點在預警當下就抽定、之後不追蹤玩家——會追蹤的預警等於假動作

### 投擲物判定

- PILLARS_2.md：未規定
- spike（原表全文）：視覺 **116×51** 旋轉（08-10 依 `cucumber.png` 305×133 比例修正，原 116×44，貼圖已正式接進 `_draw_projectile`），**判定固定 90×40 矩形**（08-10 改自 60×60 正方形，同比例對齊視覺、面積鎖 3600 不變）
- 理由／沿革：旋轉矩形要 SAT 太重；判定寧可鬆給玩家，「看起來閃過了卻死」是不可歸因的死法。v12 使用者要求「大小 ×2」，**視覺與判定同乘**——只放大視覺會讓「判定寬鬆」反過來變欺騙，只放大判定是隱形的難度上調。⚠ 08-10 判定框改形狀（正方形→跟視覺同比例的矩形）但面積刻意鎖死跟舊版一樣，是「形狀對齊真實感」不是「調難度」——如果要真的調寬鬆度得另外動面積，不要跟形狀改動混在一起

### 干擾預警

- PILLARS_2.md：只規定投擲物要看得到
- spike（原表全文）：**四種干擾各有對應預警**：投擲物＝紅三角（事前 2s）、抽跳板＝紅閃爍（事前 0.5s）＋**削掉當下四散火花**（事後）、側風＝**每陣風前 2s 畫面右緣綠條閃爍**＋吹的時候常駐淡綠、黑洞＝**事前 2s 紫色半透明圈閃爍**（綁在目標平台上，會跟著板子走）
- 理由／沿革：使用者拍板。抽跳板加「事後」訊號是因為玩家在半空中時視線多半不在那塊板上；側風「吹的時候也要有色帶」是因為少了它玩家分不出被推是陣風還是自己失誤

### 側風性質

- PILLARS_2.md：常駐向左的力、無上限遞增 ⇒ **必然墜落**
- spike（原表全文）：**間歇陣風**：吹 **1s**、休 9s（`BURST_TIME 1.0`／`CYCLE 10.0`；08-09 修正，本欄原寫 3s 是錯的），力道仍隨時間遞增
- 理由／沿革：使用者拍板（v13）。⚠⚠ 這是**設計性質的轉向**：陣風之間玩家完全自由，「力道終將超過玩家全速 ⇒ 必然墜落」不再成立，1000m 變回純技術挑戰。⚠⚠ 08-09 追查到真凶不是「改成陣風」而是**吹的時間太短**：`shock_vel_x` 每秒最多趨近 `SHOCKWAVE_RESPONSE`(400) px/s²、一陣風只吹 1s ⇒ 側向速度**恆定封頂在 400 px/s**＝玩家全速的 29%，`SHOCKWAVE_FORCE_*` 漲到多少都沒用。這是兩個不相干常數乘出來的**隱形天花板**，帳面上的「無上限」是假的

### 黑洞（doom）

- PILLARS_2.md：無此概念
- spike（原表全文）：第四種干擾。玩家上方隨機一塊平台上開洞（只挑第 2 塊起），半徑 34 的事件視界碰到即死、260px 內有向心吸力（上限 520，玩家全速 1400 ⇒ 逃得掉），壽命 5s 自己塌縮，**無敵狀態碰到＝消掉它**
- 理由／沿革：使用者拍板（v13）。⚠ 吸力上限若調到 >= `KB_MOVE_MAX_SPEED` 就變成「進範圍必死」的運氣牆；⚠ 吸力範圍一定要畫出來，看不見的力場＝不可歸因的死法；⚠ 判定用圓不用矩形（它畫成圓，矩形會有角落死法）

### 碎裂平台

- PILLARS_2.md：「踩一次即碎」
- spike（原表全文）：踩到後**整段淡出 0.45s**，淡出期間仍踩得住
- 理由／沿革：使用者拍板。透明度＝剩餘可站時間，玩家不必另外背一個隱形寬限期。舊值 0.12s 只夠閃一下，看不出是淡出

### 怪物死亡

- PILLARS_2.md：未規定表現
- spike（原表全文）：往遠離玩家的方向**拋物線飛出＋邊轉邊淡出**（**0.6s**），期間完全退出判定；踩頭／撞飛另有 **20% 機率鞭子次數 +1**
- 理由／沿革：使用者拍板。⚠ 退鞭子**不含鞭中怪物**——鞭子殺怪再退鞭子會變成自我循環。⚠ 演出時間必須短到「淡出在畫面內演完」：1.1s 是錯的，屍體 0.85s 就掉出畫面底，最後 40% 的淡出玩家根本看不到

### 高度 HUD

- PILLARS_2.md：未規定
- spike（原表全文）：左上只顯示「**本回合最高抵達高度**」，不寫分母、**也沒有進度條**
- 理由／沿革：使用者拍板。當下高度每次下墜都往回跳，讀起來像進度倒退；分母／進度條則讓「還差 800m」變成常駐挫折

### 極限模式

- PILLARS_2.md：無此概念
- spike（原表全文）：主頁右上角開關（跨局記住）：**所有等待歸零**——登場 67s 與四階 0/20/40/60s 全變 0，開局第一幀 stage 就是 4。**四種預警的時長不歸零**
- 理由／沿革：使用者拍板（v14）。⚠ 預警不是「等待」而是威脅唯一的可見形式，一起歸零就變成四種不可歸因死法。⚠ 讀取端一律走 `SpikeConfig.eff_*()`，直接讀 `interference_start`／`stage_*_offset` 在極限模式下會**靜默失效**（不報錯，只是那一項照舊等 67 秒）

### 攀爬手套啟用

- PILLARS_2.md：無此概念
- spike（原表全文）：買了之後主頁右上角多一顆開關，可隨時停用（`SpikeSave.ledge_enabled`）；沒買不顯示
- 理由／沿革：使用者拍板（v14）。「有沒有買」與「要不要用」是兩件事，兩者 AND 才是 `has_ledge_grab()`。⚠ 停用不會讓任何一塊板變不可達——生成器本來就不讀它

### 成就系統

- PILLARS_2.md：無此概念
- spike（原表全文）：9 個版位（`ACHIEVEMENT_SLOTS`）、17 個判定用 leaf id（`ACHIEVEMENT_TABLE`，表住 `spike_config.gd` SECTION 8c），**三態**：未解鎖／已解鎖未領獎／已領獎。解鎖時只放橫幅（3s，末段 0.6s 淡出），金幣要玩家自己去成就頁**點卡片**才入帳，金額看該 id 的 `reward`（沒寫吃預設 50）
- 理由／沿革：使用者拍板（v14）。⚠⚠ 入帳只能有 `claim_achievement()` 一個出口，`check_achievements()` 一毛錢都不給——兩處都能給就是重複領獎的漏洞。⚠ 條件文案照使用者 TSV 原文保留設計語彙（小黃瓜＝投擲物、Chattini＝怪物、披薩＝彈射板、義大利麵＝碎裂平台），不要改成白話。**v15 追加**：披薩／義大利麵／Chattini／遊玩次數 四個拆成 I/II/III 三階（門檻÷2／×2、獎勵 20/50/100），三階**共用同一張卡片版位**（`SpikeSave.current_tier_id()` 動態決定顯示哪階），版位數不變，不是新增卡片

### 墓碑

- PILLARS_2.md：無此概念
- spike（原表全文）：歷史最高高度 y 軸**最相近的那塊平台**上立一個墓碑，碰到得 **10 金幣**。一局最多一個，沒紀錄（第一次玩）不放
- 理由／沿革：使用者拍板。位置在「生成鏈剛跨過該高度」時掃全場決定——之後才生的板一定更高、也就一定更遠，所以那一刻掃到的就是全井最近的。墓碑壓過同板上的金幣／燃料（同一個掛點），但讓位給蟲洞

### Pameloe（第二種敵人）

- PILLARS_2.md：無此概念
- spike（原表全文）：**500m 以上出現的懸浮定點射手**：不巡邏、不跟隨平台，每 2s 朝 Kaela **當下位置**射一發直線子彈（**穿透平台**、碰到井壁消失、命中即死）；本體同既有怪物——碰到即死，踩頭／鞭子／無敵撞飛都殺得掉
- 理由／沿革：使用者拍板（v16）。⚠⚠ 牠是 `WellMonster` 的第二種 `kind`，**不是獨立系統**：踩頭／鞭子／無敵撞飛／死亡演出／prune 這五套判定完全共用，拆成兩個類別等於每套抄第二遍，每抄一遍就多一個「只修好其中一邊」的漏接點。⚠ `PAMELOE_MIN_DIST_X`（與母平台的水平隔離）是**可歸因性保命條款**不是美觀參數：長在平台正上方會把主鏈那條唯一的跳躍路線變成運氣牆。⚠ **只有畫面內的才開火**，畫面外的用 `hold_fire()` 把計時器頂在充能起點——否則被相機捲進畫面時會同幀開火，`PAMELOE_CHARGE_TIME` 的充能閃爍完全來不及演，射擊時點變成不可讀。⚠ 子彈畫得比判定框大、pameloe 本體畫的就是 `rect()` 本身（不畫成圓／菱形，那會讓 AABB 的四角落在視覺外）

### Pameloe 出現率

- PILLARS_2.md：無此概念
- spike（原表全文）：500m 起 **8%**，線性升到 1000m 的 **24%**（v17 使用者拍板，原本 16%→26%）
- 理由／沿革：使用者要「機率減半、隨高度提升到 1.5 倍」。⚠ 插值 t **從登場高度起算而不是從 0m**（`WellGenerator.pameloe_chance_at` 是唯一不走 `_lerp_by_height` 的機率線）：牠 500m 才登場，照全井算 t 的話「剛登場」拿到的是兩個常數的中點，`AT_START` 這個名字就對不上實際值

### Pameloe 雷射變體

- PILLARS_2.md：無此概念
- spike（原表全文）：08-10 三訂：`art_variant == 1`（稀有立繪 pemaloe2，抽取機率同時從 10% 調到 **20%**，`PAMELOE_RARE_ART_CHANCE`）不再發子彈，改發一道持續 `PAMELOE_LASER_DURATION`(1s) 的雷射——方向在開火瞬間鎖定（同子彈「鎖方向不追蹤」的原則），從牠身上一路打到井壁，不是打到玩家當時的位置就停（見 `WellMonster.laser_endpoint`）
- 理由／沿革：使用者拍板。⚠⚠ 雷射狀態掛在 `WellMonster` 本體上（`laser_active`／`laser_timer`／`laser_dir`），不是像子彈那樣獨立成一個脫鉤的實體——所以殺掉正在發雷射的本體會立刻掐斷雷射（`kill()` 裡順手清掉），這跟子彈「發射出去就跟牠脫鉤，死了也照常飛完」是刻意不同的兩條規則。⚠ 判定用點到線段距離（`WellMonster.laser_hits`），不是矩形——雷射是一條線，理由同黑洞／爆炸「判定用圓不用矩形」，只是這裡換成線。有稽核在守（`tests/audit_hazards.gd` `_audit_pameloe` 的雷射四項）

### Pameloe 開火鏡像

- PILLARS_2.md：無此概念
- spike（原表全文）：08-10 二訂：使用者要求「發射子彈時依發射方向鏡像翻轉」。開火瞬間依鎖定方向翻轉本體貼圖（`WellMonster.face_toward`，沿用巡邏怪共用的 `_dir`／`facing()`），子彈與雷射兩條分支都會觸發
- 理由／沿革：使用者拍板。⚠ 充能圈的描邊要在算完翻轉之後的 rect 上畫，不能先畫再翻——否則描邊會沿著沒翻的形狀走，跟翻過的本體對不齊（同 Kaela 無敵窗描邊的順序，見 `_draw_pameloe`）

### 死亡表現

- PILLARS_2.md：未規定
- spike（原表全文）：**不切獨立結算頁**。死亡位置放小型爆炸（0.55s，世界完全凍結），演完才進結算；摔落死改畫在**畫面底緣往上一點**；結算資訊裝進佔畫面 **3/4** 的小卡由下往上推進來，背景維持最後一幀的遊戲畫面（只壓暗）
- 理由／沿革：使用者拍板（v17）。⚠ 瞬間切頁會把「我怎麼死的」藏在切換那一幀裡，死因整個押在結算那一行文字上。⚠ 爆炸位置必須在畫面內——摔落死觸發當下玩家已在畫面外，照玩家位置畫等於沒演。⚠ 爆炸是 placeholder，美術素材接進來只換 `WellWorld._draw_death_fx`，SECTION 6c 的**時長常數要留著**（時長是手感，換素材不該連帶改節奏）

### 存檔備份

- PILLARS_2.md：無此概念
- spike（原表全文）：設定頁的**匯出／匯入碼**：JSON→Base64＋12 碼校驗，前綴 `RAORA1-`
- 理由／沿革：使用者要求順手補。itch 免費方案沒有雲端存檔，Web 版 `user://` 只落 IndexedDB。⚠⚠ 校驗**不是防作弊**：鹽值就在 client code 裡，且玩家本來就能直接改 IndexedDB。任何面向玩家的文案都不准說它「安全」

### 字型

- PILLARS_2.md：未規定
- spike（原表全文）：`assets/fonts/NotoSansCJKtc.otf`（原本 NotoSansTC.ttf）
- 理由／沿革：使用者拍板（v17）。TC 版不含平假名／片假名，日文版會整頁豆腐。⚠ 子集只收「`.gd` 裡真的出現過的字」，所以現在的 .otf **還沒有假名**——換的是「未來補得進去」不是「現在就有」

### 貼圖底部錨點

- PILLARS_2.md：未規定
- spike（原表全文）：**站在平台上的東西一律「alpha bbox 底邊貼齊平台上緣」**，不是中心對齊：怪物讀 `MONSTER_ART_FEET_FRAC`、蟲洞讀 `WORMHOLE_ART_FEET_FRAC`（基準線是母平台上緣，由 `pos.y + WORMHOLE_HOVER` 反推）。懸浮的東西（Pameloe）維持中心對齊
- 理由／沿革：08-10 使用者回報「圖片底部沒跟平台貼齊」。根因：art 尺寸是碰撞尺寸的 **2 倍**，中心對齊會讓貼圖底邊沉到平台上緣**下方 21px**，而平台才 18px 厚 ⇒ 整塊平台被蓋住。⚠ FEET_FRAC 有稽核在守：`tests/audit_levels.gd` 會**直接掃 PNG 的 alpha** 算腳底位置跟常數比對，換圖忘了重量會紅

### 開發者傳送

- PILLARS_2.md：無此概念
- spike（原表全文）：遊戲畫面右緣中間一顆 `▲ +300 m` 按鈕：按一次瞬間往上 `DEV_TELEPORT_M`(300m)，相機同步移動＋給一次無敵窗。**只在 `SpikeConfig.dev_mode()` 為真時才建得出來**（debug build ／桌面 `--dev` ／Web 網址 `?dev=1`，三選一成立）。08-10 五訂：按過**不再標記作弊局**，成績／成就／解關一律正常回報
- 理由／沿革：使用者拍板（08-10；五訂推翻原本的「作弊局不寫存檔」）。⚠⚠ dev_mode 為假時是**整顆不建**不是 hide()——隱藏的東西會被某個 visible 誤設救活。⚠ 五訂理由：這是純測試用的傳送鈕，一般玩家碰不到、不會被濫用，標記反而讓「快速跳到高處測」跟正常結算脫節——原本的 `SpikeSave.cheated_run` 機制與其六個寫入端守衛已整條移除，不留死代碼。⚠ 它防的是「一般玩家不小心碰到」，不是防作弊（同存檔匯出碼那條：client 端沒有真正的防線）。⚠ 稽核：`tests/audit_ui.gd` `_audit_dev_teleport`

### solo 區間的怪物

- PILLARS_2.md：未規定
- spike（原表全文）：`BAND_SOLO_HEIGHT_M`(690m) 以上：怪物巡邏範圍縮到 **±18**（`MONSTER_PATROL_RANGE_SOLO`）、主鏈平台寬 **×1.3**（`PLATFORM_WIDTH_MULT_SOLO`）、**會動的平台不掛怪**。另 `MONSTER_PATROL_SPEED` 70→**52**
- 理由／沿革：08-10 真人試玩回報「高處平台上有怪＝基本一定得靠 jetpack 或鞭子」。⚠⚠ 根因是可以算出來的幾何，不是手感：平台半寬 60、怪物判定半寬 23、巡邏 ±45 ⇒ 怪物掃過的包絡線 ±68 **比平台本身還寬**，平台上不存在任何一個 x 是怪物碰不到的 ⇒「站在邊緣等牠走開」在舊數值下**根本不成立**。要有解需要 玩家中心離怪物 ≥ (38+46)/2 = 42 且仍與平台重疊，兩手一起下之後兩側各留 **27.5px** 的安全落腳窗。⚠ 減速是**調味不是解法**：它不改變上面那組幾何，怪物照樣走遍整塊板，只是慢——所以砍 25% 不砍 50%（砍一半會讓牠變靜止靶）。⚠ 只加寬 solo 區間而不是全域放大 `PLATFORM_SIZE`：全域加寬會把低處一起變簡單，而低處本來就有備援跳板。⚠ 有稽核在守（`audit_levels._audit_solo_foothold`，含突變測試驗過抓得到）

### 特殊區段

- PILLARS_2.md：無此概念
- spike（原表全文）：隨機某 **40m** 高度區間變成「主題區」：整段只出某一種平台、怪物率 ×2、金幣率 ×2。首種是移動平台區。表住 `spike_config.gd` SECTION 4e 的 `SEGMENT_TABLE`（加一種＝加一列）
- 理由／沿革：使用者拍板（08-10）。⚠⚠ 怪物**與**金幣一起 ×2 是刻意的：只加怪物是純難度尖峰（玩家只覺得倒楣），只加金幣是免費午餐，兩者一起才是取捨——何況玩家繞不開，更該給補償。⚠⚠ 「整段只出移動平台」跟 `_pick_kind` 那條「solo 區間不准連續兩塊會動的板」**直接對打**，在 690m 以上會把主題全部改回 STATIC ⇒ 主題區在最需要變化的高度完全失效。對策不是關掉防護，而是**區段強制帶備援跳板**（`band_extra_min`）：有備援就不是「連兩次賭時機」，防護的前提消失才可以合法豁免。⚠ 兩者是一組——拿掉 band_extra_min 而保留豁免＝直接把高處主題區變成運氣牆，有稽核在守。⚠ 備援板在區段內用**確定性掃描**擺放（隨機試 8 次在主題區約 8% 擺不出來，而它是豁免的對價，不能是機率性的）。⚠ 區段歸屬存成 `WellPlatform.segment_id` 旗標，**不准用高度反推**：生成鏈是用上一塊的高度決定這一塊的性質，靠高度反推會在每段頭尾各誤判一次

### 爆炸平台

- PILLARS_2.md：無此概念
- spike（原表全文）：第六種平台（`WellPlatform.Kind.EXPLOSIVE`）：踩上去點燃 **2s** 引信、期間**逐漸變亮且仍踩得住**，燒完平台消失並炸出半徑 **80** 的圓形爆炸區（存在 0.35s，碰到即死）。**關卡二起才出現**（登記在 `SpikeConfig.LEVEL_GATED`）
- 理由／沿革：使用者拍板（08-10）。⚠⚠ 半徑是**保命條款**：必須 < 最小中心距 − 玩家半高（138−27=111），否則按規矩跳走的玩家照樣被炸 ⇒ 它就退化成「更兇的碎裂平台」。有稽核在守（`audit_levels._audit_explosive`）。⚠ 引信 2s 遠長於玩家在一塊板上的停留時間（正常 <0.5s）——它威脅的不是「踩到」而是**久留與折返**，是節奏加壓器不是第二種碎裂平台。⚠ 引信只點一次（`fuse_timer < 0.0` 那個條件）：拿掉的話在板上連跳＝無限拆彈，這塊板永遠不會炸。⚠⚠ **無敵中免疫但爆炸不會被消掉**，跟怪物／投擲物／黑洞那三條刻意不同——爆炸是範圍事件不是可以被打散的物件，「衝過去消掉它」會讓 jetpack 變成拆彈工具。⚠ 爆炸區是獨立實體（`WellBlast`）不掛在平台上：平台炸開那一刻就 `alive = false`，之後隨時被 prune 回收，狀態掛上去等於「爆炸演不演得完」看相機捲到哪裡。⚠ 判定用**圓**不用矩形（同黑洞）；外環一律畫在致命半徑上、不隨演出縮放，會長大的圈等於前幾幀「看起來沒碰到卻死了」

### 物資漂浮

- PILLARS_2.md：無此概念
- spike（原表全文）：金幣／燃料／Pameloe 都做**微幅緩慢的上下晃動**。但**判定的處理相反**：金幣／燃料只晃視覺、判定完全不動（做在 `WellWorld._pickup_float_offset`），Pameloe 判定跟著晃（做在 `WellMonster.step()`）
- 理由／沿革：使用者拍板（08-10）。⚠⚠ 差別不是不一致而是刻意：撿取物的誤差要倒向「還沒碰到就撿到」，對玩家有利；Pameloe **碰到即死**，視覺與判定一分離就是不可歸因的死法（常青認知第 8 條⑤才剛在怪物判定框上踩過）。⚠ 金幣／燃料的位移範圍是 **[-2×AMP, 0]（只往上）不是 ±AMP**：`PICKUP_HOVER` 剛好等於金幣視覺半高，不晃時本來就貼著平台上緣，對稱晃動的下半段會穿進平台（visual_check 拍出來才看到）。⚠ 相位一律走 seeded rng 在生成當下定死，不在繪製時骰（每幀骰＝每幀跳），也不能不骰（整排同步擺動像機械故障）

### 物資（金幣／燃料）尺寸

- PILLARS_2.md：無此概念
- spike（原表全文）：08-10 三訂：使用者要求「COIN、FUEL 的大小 -50%」。判定（`PICKUP_SIZE`／`FUEL_PICKUP_SIZE`）與畫面尺寸（`COIN_ART_SIZE`／`FUEL_ART_SIZE`）等比一起減半，`PICKUP_HOVER`（懸停高度＝視覺半高）同步減半，維持「內容 ＝ 判定 ×2」與「不晃時貼齊平台上緣」兩條既有關係
- 理由／沿革：使用者拍板。⚠⚠ 來源 PNG 沒有換檔，縮小是畫的時候做的（新常數 `PICKUP_ART_SCALE := 0.5`，`draw_texture_rect` 把畫布縮到目標尺寸，已開 Linear+Mipmaps 不會有鋸齒）——這打破了原本「畫布 ＝ 畫面尺寸、零縮放」的慣例，`tests/audit_levels.gd` `_audit_pickup_art` 的比對基準已同步改成「畫布 × PICKUP_ART_SCALE」，換圖或再調縮放記得同步看這條

### 怪物判定框位置

- PILLARS_2.md：未規定
- spike（原表全文）：判定框**大小**不變（`MONSTER_SIZE`），但**位置**改成對齊 art 視覺中心，不再貼平台上緣——見 `SpikeConfig.MONSTER_HITBOX_CENTER_OFFSET_Y` 與 `WellMonster.rect()`
- 理由／沿革：08-10 二訂：上面那條「貼圖底部錨點」修正後，art 錨點移到腳底，但判定框沒有跟著移，於是整條判定框落在視覺下半部（踩頭腳陷進牛背）。真人試玩回報後改成判定框中心對齊 art 中心——這其實是回到 FEET_FRAC 上線**之前**「art 與判定框同中心」的關係，只是 art 錨點現在多繞了腳底這一步

---

## 2026-08-14 下半場 —— 驗證體系改造（成本歸因修正 ＋ 突變測試批次化）

起因：08-13 三批改動燒掉 80 萬 token／360 次工具呼叫／80 分鐘。上一版檢討把主因歸給「每次
驗證都跑完整回歸（1.5~3 分鐘）」並建議做 `--only`。本輪**先實測再動手**：完整 smoke 其實只要
4.3s／8.1s（錯 20~35 倍），據此重排優先序——真正的成本是 ① 進 context 的字數（乘法）
② round-trip 次數，執行時間是三者裡最小的。歸納見 `spike_well/.claude/docs/evergreen.md` 第 20 條。

四項落地：

- `smoke.gd` 加 `-- --only=<組>,<組>` 與 `-- --list`。不給 `--only` 行為完全不變；組名打錯
  一律 exit 2、不靜默全跑（mutation_check 靠退出碼判紅綠，靜默全跑會把拼錯字讀成「稽核抓不到」）。
  實測單組 2.1~2.7s／3~10 行，全套 4.3~8.1s／97 行。⚠ 沒有 hazards 組——它的三條稽核由
  mechanics 持有引用呼叫，要驗黑洞／墓碑／Pameloe 就跑 `--only=mechanics`。
- **`tools/mutation_check.py` ＋ `tools/mutations.json`**：突變測試批次驅動。一張表一次呼叫跑完
  （自動套用 → 跑 → 判紅 → 還原 → 驗回綠），把「每條稽核 4 次 round-trip」壓成 1 次。初始 6 條
  全 RED-OK、39 秒。還原走「開跑前存整檔原文、finally 寫回」而非反向替換，Ctrl-C 也還原得回來。
- `src/well_world.gd`（3400 行）補檔頭索引，規格比照 `spike_config.gd`（Grep 段落標題定位、
  刻意不寫行號）。它是三個大檔裡唯一還沒防守的一個。
- 新增 `.claude/docs/verification-matrix.md`：改動類型 → 最小驗證集，**唯一的家**。含各手段實測
  成本（import 1.5s／單組 2.4s／全套 4~8s／突變全表 39s／visual_check 5.7s＋53 張 PNG／錄影約
  4 分鐘）與「輸出一律導檔、只讀 `[SMOKE]` 與 `!!` 行」的標準呼叫式。

過程中兩個發現，都是 mutation_check 自己抓到的：

- **稽核端也讀的常數突變不出東西**：`TUTORIAL_HAZARD_GAP_MIN_M` 改小 → 斷言跟著變鬆 → 永遠
  MISS。`BUFF_SECOND_HEIGHT_M` 則是根本沒有稽核覆蓋。有效的突變點是「只被實作端使用的常數」
  （`INVULN_GRACE`／`WORMHOLE_RISE_M`／`LEVEL_COUNT`）或「直接改壞遊戲資料」（抽掉 `TUTORIAL_PLATFORMS`
  一列 → 落差變兩倍 → 紅）。挑點前先 Grep 那組稽核讀了哪些常數，避開清單上的。
- **教學關可跳性稽核只驗垂直落差、不驗橫向出井**：`TUTORIAL_PLATFORMS` 某列 `x` 改成 2000
  （遠在井外）`--only=tutorial` 仍全綠。真實覆蓋缺口，未補（HANDOFF Deferred 9）。

同批把常青認知 20 條從 HANDOFF 搬進 `spike_well/.claude/docs/evergreen.md`（HANDOFF 撞 12KB
上限；常青知識本來就不該住進度檔，全域規則是「常青陷阱住專案地圖」，本專案無地圖故住 docs）。

驗證：完整 smoke PASS（exit 0）；`mutation_check.py` 全表 6 RED-OK ＋ restore=ok；六個突變點
事後逐一 Grep 確認回到原值。⚠ 全程不動任何玩法數值與邏輯，只動測試框架與文件。

---

## 2026-08-14（spike v22）—— 第三關三種新內容 ＋ 真人試玩六項修正 ＋ DAHLAH 偏移

使用者真人試玩後的十項，分三批由 sonnet subagent 施工、主線逐批實跑驗證。
⚠ **Grep 對照**：本輪的程式碼註解一律標成 **`08-13x`**（沿用前一輪的標記慣例，全專案 80 處），
不是 `08-14`——要從程式碼反查這一輪的改動，搜 `08-13x` 而不是搜本條目的日期。

**第三關三種新內容**（三者皆 `LEVEL_GATED` min_level=2）：
- **騙人平台 `Kind.DECOY`**：外觀同 STATIC 但 alpha 0.8，**完全不成立落地**（直接穿透），
  碰到即從中間裂兩半往左右飛出並淡出。**只在 <500m**。使用者拍板要這個狠度，
  alpha 就是給玩家的線索；金幣照樣長在上面當誘餌（也是拍板的）。
  可達性安全條款選「**不進 `_pick_kind()` 的骰池、只當 `_generate_band_extras` 的備援板**」——
  備援板本來就不是承重的。順手修掉一個既有 bug：`_scan_exit_candidates()`（蟲洞出口）與
  `_maybe_place_tomb()` 掃全平台陣列，會把出口／墓碑掛到 DECOY 上＝必死。
- **卡包 `Pickup.LOOT_BAG`**：撿到後 1~3s 金幣雨，金幣從**畫面上方**落下、碰到才入帳
  （拍板要「停下來採金 vs 繼續爬」的取捨，不是自動入帳）。
- **`Monster.PEBBLES`**：朝 Kaela 水平移動、不跳、走出平台邊緣就墜落死，
  自己走死**算玩家擊殺**（走踩頭同一條 `_kill_monster`）。碰撞規則同 chattini。
  額外限制在 **690m 以下**（不進 solo 區間）——solo 區間落腳窗只剩 0.5px 餘裕，
  再放一隻會追人的怪等於運氣牆。使用者確認保留這個比規格嚴的限制。

**干擾／buff 修正**：
- 視野縮小從「解鎖後永久壓暗」改成**間歇**：暗 5s（含淡入與新增的 0.8s 淡出）／亮 15s。
- **屍體堆二訂＋三訂**（見下方「坑」）。
- **DAHLAH 新增起跳隨機偏 0~15 度**，實作成**可抵銷的滑行分量**：只加水平分量、
  **垂直初速一行都不動**（旋轉整個跳躍向量會少 3.4% 垂直分量，而生成器間距是照
  1.0x 跳躍高度算的——這正是 `BUFF_DAHLAH_MIN` 不准低於 1.0 的同一條理由）。
  按方向鍵／落地／撞牆皆歸零。只掛在一般起跳點，彈射板／踩頭／懷錶二段跳都不吃。

**教學關 200m → 500m 四項**：終點拉長、蟲洞改成送 `WORMHOLE_RISE_M`（+40m）、
非教學點區段間距加密到正式低空水準（`SPACING_MIN_AT_0`~`MAX_AT_0`＝95~140px，
教學關原本 3.0~3.6m 比正式的還稀疏）、怪物與干擾各自分段、之間插純平台練習區。
干擾示範拆到 370.5／420.5／470.5m。教學關稽核 37 → 42 項。

### 坑

**① 干擾跨局殘留的根因不在玩家身上**（使用者回報「死掉重來還在吹側風、教學關特別明顯」）：
`WellPlayer.shock_vel_x` 早就被 `reset()` 清乾淨了。真兇是
`Interference._manual_shock_active` / `_manual_shock_timer` 這**兩顆只有教學關手動陣風 API
（`tutorial_trigger_shockwave()`）會碰**的欄位，`Interference.reset()` 從來沒清過；而
`WellWorld._process()` 在 `_dying`（死亡演出）與 `not running`（登頂）時整個 early-return，
陣風就凍在半途被帶進下一局。**通用教訓：只有一條特殊路徑會寫的欄位，是 reset 最容易漏掉的
——盤點 reset 要按「誰會寫它」而不是按「主流程用不用得到」。**

**② 屍體堆的三個數字是同一組推導，不能單獨改**：
二訂先把散佈帶從 150px 壓到 **14px**——推導本身是對的（實跑 400 顆種子量到起跳台到第一塊
平台的板底只有 77px，全尺寸貼圖躺平旋轉後垂直半徑就吃掉 61px），但結果 40 具擠成一整排、
堆不起來。三訂照使用者「把屍體畫小」的指示改成**縮小繪製**：`CORPSE_ART_SCALE=0.6` ⇒
最壞外框半徑降到 38.8px ⇒ 散佈帶拿回 34px、角度範圍同步從 60~120° 放寬到 50~130°。
⚠ SCALE／BAND_H／ANGLE_MIN|MAX 綁死，改一個要重算另外兩個；**繪製（`_draw_corpses`）與
稽核（`_corpse_top_reach`）共用同一組公式但各自要記得乘 SCALE**，漏一邊就一邊對一邊錯。
殘餘風險（已知取捨）：關卡一有 ~3% 機率第一塊是 VERTICAL、板底可低到約 50px，那種局仍可能
貼到板底；要完全擋掉等於放棄散佈帶。

**③ 教學關蟲洞「移動距離極短」的根因**：教學關自己在平台表寫死入口／出口，
入口 51m → 出口 57m＝**只送 6m**，而正式蟲洞固定送 `WORMHOLE_RISE_M`＝40m。
新版改成從入口 + `WORMHOLE_RISE_M` 推導，不再寫死第二個 40。

## 2026-08-13 四訂 —— 使用者五項：教學關上線 ＋ 死亡文字改版 ＋ 井底屍體堆 ＋ 石化改規格 ＋ 名單頁佔位

使用者一次給五項規格（含三張參考圖與 `Downloads/dead.txt`）。開工前用選擇題把八個歧義點問掉，
逐項施工、每項完成就跑一次全套回歸再進下一項。**現行規則全部登記進
[deviations.md](spike_well/.claude/docs/deviations.md)，這裡只留沿革與踩到的坑。**

**① 石化藥水 × jetpack（改規格）** — 二訂的「點火加一次 BOOST」作廢，改成噴射的每一幀持續加到上限
（`BUFF_PETRIFY_SPIN_JET_RATE`）。點火那一幀只保留「重骰方向」（它仍是一次離地起跳）。
噴射期間 `DECAY` 整段跳過，理由是不跳過的話 RATE 要先扣掉 DECAY 才是淨值，兩個常數互相綁死、
玩家看到的加速度跟任一個常數都對不上。既有稽核「持續噴射不逐幀累加」語意反轉成「逐幀累加 ＋ 封頂」。

**② 死亡文字與結算卡（改版）** — 結算卡砍到只剩大字＋高度（破紀錄掛 NEW）＋用時＋KRONII 幣。
死因→大字的映射放 `WellWorld.death_line()`（比對 `CAUSE_*` 常數），文字住 `SpikeConfig`。
⚠ 為了分辨「chattini 殺的」與「pameloe 殺的」新增 `CAUSE_PAMELOE_BODY`——原本撞 pameloe 本體
跟撞 chattini 共用同一條死因，判定沒動，只是結算讀得出是誰。摔死三段的門檻讀**本局最高高度**
不是死亡當下高度（掉下來的過程不該把成就感降級）。dead.txt 原表缺 1000~1500m 與爆炸平台兩格，
都由使用者當場補齊。

**③ 井底屍體堆（新）** — 關卡 × 模式各自一堆（極限與無盡是兩個獨立 toggle ⇒ 四種組合）。
位置由「第幾具」決定而非每局重骰：重骰的話玩家看到的是一堆陌生屍體，而不是「我上次死在那裡」。
用自己的 `RandomNumberGenerator`（seed 混進關卡與模式），稽核直接比對「有 40 具 vs 0 具時同一顆
seed 的井是否逐塊相同」——這是 v19「共用純函式偷骰 RNG」那條教訓的回歸測試。

**④ 工作人員名單（佔位）** — 設定頁 → 獨立子頁，返回與 ESC 都回設定頁。內容只有「準備中」。

**⑤ 教學關（新，派 sonnet subagent 實作）** — 規格與架構決策由主線先定死（config 表結構、
世界層不讀 SpikeSave、`setup(tutorial)` 一次鋪完、字卡走 `SpikeUI.shared_font()`、干擾另開強制觸發
API），agent 照著填 56 塊固定平台／10 張字卡／4 筆干擾事件並自建 `tests/audit_tutorial.gd`。
交回後**主線自己重跑全套驗證，不採信自述**，另外抓到並修掉兩件 agent 沒做到的事：

- **字卡把按鍵寫死成「按 A/D」「按 E」**：玩家一改鍵教學就教錯，而且完全不報錯。改成整句模板
  `{left}` `{aim}`＋`SpikeConfig.tutorial_cue_text()` 用 `SpikeKeys.label_of()` 展開（i18n 條款本來就
  要求整句模板）。順手拿掉文案裡「鞭子有 5 次」這種吃永久升級的快照數字。稽核補兩條鎖住它。
- **教學關右上角照跑「Raora 登場倒數」**：教學關的干擾改成高度觸發，時間倒數在這關沒有意義，
  而且 67 秒後會印「Raora 已登場」但什麼都不會發生——純誤導。`hud_data()` 加 `tutorial` 旗標、
  UI 整格隱藏，並把計時器那段拆成 `_update_timer()` 只在非教學關呼叫（`_timer_hot` 是「只在跨越 0
  那一幀切色」的節流旗標，教學關偷翻它會讓回到正式局的第一幀顏色對不上狀態）。

**本輪踩到的坑（工具面，非遊戲邏輯）**

- **Markdown 表格的儲存格裡出現字面 `|` 會把那一列切成多欄**，而且渲染前看不出來（本輪在
  deviations.md 寫 `關卡|模式` 當場踩到）。同 v20 那條「儲存格內容不能用 `
`」——
  組表格類文件時**任何**會被當成分隔符的字元都要先改寫掉，用反斜線逸出則會讓後續的自動檢查
  誤判，不如直接換句話寫。驗收要寫一支「逐列數欄數」的檢查，不要靠肉眼。
- 改過中文文案後 `tools/subset_font.py` 一定要重跑（本輪新增死亡文字／字卡／名單頁三批中文），
  跑完還要再 `--import` 一次，否則 Web 版新字是豆腐方塊。

**驗證** — headless import 0 error；`smoke.tscn` 全綠（機制 25／UI 22／關卡 12／增益 81／教學 37 項、
生成器稽核、bot 4 局）；`visual_check.tscn` 新增三張截圖（教學字卡 ×2、死亡結算卡）人眼複核過版面。

## 2026-08-13 三訂 —— 驗證體系擴充（決定性錄影／通用版面掃描／錨點量測腳本化）

起因：使用者評估 GitHub `htdt/godogen`（5.4k★「一鍵生成遊戲」）是否值得引入。結論是**整包不可引入**
（它是一次性腳手架，`publish.sh --force` 會 `rm -rf` 目標；且零治理層——無 hook、無 commit 閘門、無 CI，
比本專案弱得多）。**唯一值得擷取的是它的錄影驗證配方**，本輪落地。順帶把兩個既有缺口一起補掉。

1. **決定性錄影驗證上線**（`record.gd` ＋ `record.tscn`）
   動機：既有兩支各缺一半——`smoke.tscn` 的 bot 跑得完整但 `set_process(false)` ＋ for 迴圈一次跑完、
   **全程不渲染**；`visual_check.tscn` 會渲染但只擺**靜態**姿勢。兩者都驗不到「動起來對不對」。
   做法：重用 `tests/bot_run.gd` 的決策函式（`_bot_target_x`／`_send_key`／`_send_click`，借用不複製——
   bot 決策改了錄影要跟著改），驅動方式改成**引擎逐格**（才有畫面可錄），配 Movie Maker `--write-movie`
   輸出 PNG 序列。
   ⚠ **一律餵固定 DT，不吃引擎 delta**：錄影的全部價值在「同顆 seed 跑出一模一樣的結果」，吃真實
   frame time 兩次就對不起來。（godogen 靠 `--fixed-fps` 讓引擎給固定 delta，這裡直接繞過引擎 delta。）
   實測 6 秒版與 8 秒版 `height` 皆 13.4m，決定性成立。
   ⚠ **一定不能加 `--headless`**（同 visual_check 的 dummy driver 坑，會寫出一整批空白 PNG）。
   已知缺口：錄的是 `WellWorld` 本身、**不含 HUD／UI 層**（未接 main.gd 流程）。
   成本：編碼約 190ms/格，20 秒錄影要跑約 4 分鐘，不是即時工具。

2. **seed 可重現**（`src/well_world.gd` 加 `seed_override`）
   `reset()` 原本硬寫 `gen.setup(start_y, 0, ...)` ＝每局 randomize。新增 `seed_override`
   （**預設 0 ＝ 行為完全不變**），沿用既有 `kb_dir_override`／`mouse_override` 的注入慣例。
   ⚠ 必須在 `add_child()` **之前**設：`add_child` 觸發 `_ready()` → `reset()`，seed 那一刻就被讀走。
   `bot_run.gd` 改用 `SEED_BASE + run_idx` ＝ 四座**不同但固定**的井——隨機 seed 下「昨天過今天不過」
   分不出是 regression 還是剛好抽到難井。

3. **通用版面掃描**（`tests/audit_ui.gd`，UI 稽核 20→21 項）
   原本 OOB 是**逐條手寫**（傳送鈕一條、三顆 dev 鈕一條）⇒ 新增 UI 元素不會自動被驗到。
   改成遞迴全樹掃描，三類 OOB／TRUNC／OVERLAP，走 9 個畫面組合。CLIP 不做（本專案無 ScrollContainer）。
   借 grab2 `tools/ui_audit/` 的**判定邏輯**，但**刻意不帶它的 manifest／factory／calibration 三層**——
   那三層是為了解 grab2「UI 散在幾十個 .tscn、有些要 factory 才建得出來」的問題，本專案 UI 全程式建構
   （硬規則 3），那三層是純包袱。
   ⚠ 排除規則一律用**結構性判斷**（`get_parent() is HudCell`、物件參照 exempt），**不得用節點名稱字串**：
   `_make_label()` 建的節點大多沒設 `.name`，Godot 自動配的匿名編號不是穩定識別碼。
   ⚠⚠ **新掃描器第一次跑就回報「乾淨」時必須反向驗證**——光看程式碼無法排除「判準被放寬成永遠 PASS」。
   用臨時 selftest 餵已知違規（超框 Label／大面積相疊的兄弟／被容器壓小的 `clip_text` Label）確認三類都
   爆得出來才能信。已驗過三類全抓到（臨時檔跑完即刪）。**真實 TRUNC 只構造得出於「容器把 Label 壓小」，
   Label 的 minimum size 會把 `size` 撐回文字寬度，得靠 `clip_text = true` 讓它歸零容器才壓得下去。**

4. **錨點量測腳本化**（`tools/measure_anchor.py`）
   `/import-art-asset` 第 4 步原本**人工**量「腳底 alpha bbox 底邊 ÷ 畫布高度」，一失手貼圖就沉進平台
   （08-10 接怪物與蟲洞踩過）。腳本化後：自動算 alpha bbox、**強制檢查多檔畫布尺寸一致**（不一致
   `exit 1` 拒絕出常數，因為那代表縮放步驟做壞了）、印出可直接貼進 config 的常數行。
   正確性證據：把既有三個常數**精準重現**（`KAELA_FEET_ANCHOR_FRAC` 99/108、`MONSTER_ART_FEET_FRAC`
   83/84、`WORMHOLE_ART_FEET_FRAC` 86/88）。⚠ 輸出一律純 ASCII 英文（Windows console 是 cp950）。
   附帶：PIL `alpha.getbbox()` 的 `bottom` 是 exclusive，剛好等於現有常數的量法，不用另外 +1。

5. **發現：bot 的鞭子路徑從來沒被真的執行過**（既有盲區，非本輪造成）
   smoke 四局輸出全是「鞭子 射出 0／命中 0」——bot 鞭子起手週期 6 秒，但實測只活 3~4 秒
   （`bot_run.gd` 註解自己就寫「常在 2~3s 就摔死」）。固定 seed 讓它從「偶爾測到」變成「**穩定**測不到」。
   `record.gd` 已把週期縮到 1.5 秒（錄影要看得到鞭子，實測 `whip_fired=1`）；
   **`bot_run.gd` 刻意沒動**——改它會變動既有稽核的意義，留給使用者拍板。

6. **skill／文件同步**
   `/import-art-asset` 的 description 改成**觸發式**（「要把 AI 產生的圖接進遊戲時用……」）而非自我介紹式：
   Claude Code 的 skill 靠 description 讓模型自主觸發，寫「我是什麼」模型較難判斷何時該用，寫「何時用我」
   才會在對的時機自己跳出來——這比 hook 事後提醒更早一步。驗證章節由兩層改三層。

---

## 2026-08-13 二訂 —— 解鎖門檻位移、jetpack 也算石化加速、平台四態貼圖分組修正

使用者真人試玩後回報三件事，逐一修掉：

1. **破關解鎖門檻各提前一關**：原「通關二→手套＋極限、通關三→懷錶＋無盡」改成
   「通關一→手套＋極限、通關二→懷錶＋無盡」（`UNLOCK_TABLE` 的 `level` 全部 -1）。
   理由：對齊 `STORY_CLEAR_LEVELS`（破關卡一／二播劇情）——劇情與解鎖蒙版本該同一時機播出，
   原本錯開一關是疏漏不是設計。`tests/audit_ui.gd _audit_unlock_rules` 重寫對應門檻。
2. **jetpack 點火新增石化加速**：使用者拍板「用 JETPACK 也該算一次加速」，跟彈射板／蟲洞
   同一類（`_petrify_takeoff(true)`）。只在 `_step_jetpack` 的 `was_on` false→true 那一幀
   （冷啟動剛結束、真的噴出來）觸發一次，持續按住不逐幀累加。
   ⚠ 新踩的坑：headless 稽核要用真實輸入模擬這條路徑時，`Input.parse_input_event()`
   不會立刻反映在 `Input.is_key_pressed()`——必須再呼叫一次 `Input.flush_buffered_events()`
   才會同幀生效，否則模擬按鍵永遠讀不到（見 `audit_buffs.gd` `_audit_petrify_spin` ⑥）。
3. **平台四態貼圖分組原本就沒接對**：08-11 使用者說明「會動的上下／左右／圓形統一用
   move.png」「爆炸平台未觸發前應該跟 normal 平台完全同色」，對照程式碼發現 VERTICAL／
   CIRCULAR 當時誤留在 `platform_normal.png` 分組、EXPLOSIVE 誤帶專屬底色 `C_EXPLOSIVE`——
   兩條都不是刻意的，是 08-10 首次接線時的疏漏，這次一併修正並移除已無用的 `C_EXPLOSIVE`
   常數。`visual_check.tscn` 的 `explosive_check_idle/fuse.png`、`platform_check_kinds.png`
   截圖比對確認外觀符合預期。

驗證：smoke 全綠（增益稽核 77→80 項，新增 3 項 jetpack 相關）。**這三項尚未真人試玩。**

---

## 2026-08-13（spike v20）—— 使用者十三項施工（三選一二輪／第五種干擾／劇情與解鎖／HUD 重排）

使用者一次給了十三項規格（含四張手繪／截圖參考圖）。動工前先用選擇題收斂四個衝突點，
拍板結果：① 同時持有兩顆 buff 時「主動疊兩顆、被動也同時生效」 ② 通關二→手套＋極限、
通關三→懷錶＋無盡（手套從商店移除） ③ 快捷鍵維持現行（圖五的 E／F 只是示意）
④ 石化旋轉的「彈起」＝所有離地起跳。

十三項全部完成，逐項的**現行規則**唯一的家＝`spike_well/.claude/docs/deviations.md`
對應列（本檔不重複）。這一輪比較值得記的判斷：

- **`cleared_max` 這顆新存檔欄位**：`unlocked_level` 夾在 `LEVEL_COUNT-1`，通關最後一關時
  完全不會動 ⇒「通關關卡三才給」的懷錶與無盡模式若沿用它就永遠解不開，而且是靜默的。
  舊檔用 `unlocked_level - 1` 回推，代價是老玩家要再通一次關卡三（一次性，已知）。
- **手套從商店移除**：`UPGRADE_TABLE` 刪 key 是 HANDOFF「存檔相容性」列的已知雷，這次刻意
  接受——影響僅止於「以前買過的人改成通關才拿得到」，而那正是新規則要的行為。
- **視野縮小的畫法換過一次**：第一版用 26 層同心環近似漸層，`visual_check` 實拍看得到
  一圈一圈的接痕（環與環重疊處 alpha 疊兩次）⇒ 改成一張 radial `GradientTexture2D`。
- **稽核自己寫錯過一條**：第二組三選一「不污染主 RNG」原本比「兩座井跑到同一高度後的下一個
  亂數」——那本來就會不同（第二組把主鏈推高 3 道間距，關卡三少生幾塊就到得了同一高度）。
  改成直接比 `_rng.state` 前後不變。紅的是斷言不是實作，這種要先懷疑斷言。
- **`HudCell` 的快捷鍵位置**：`set_anchors_preset(BOTTOM_LEFT)` 之後 `position` 是相對
  「格子左下角」算的，同一組偏移把字推到格子外面下方，`visual_check` 才看得出來。

驗證：smoke 五組稽核全綠（增益 77 項、機制 24 項、UI 20 項），四組新稽核（鞭子暈眩／
鏡頭震動／視野縮小／通關獎勵＋劇情＋左下角格子）全部用突變測試確認抓得到。
`visual_check.tscn` 新增四張圖：`hud_check_bottom_left` / `story_check_placeholder` /
`unlock_check_mask` / `vision_check_shrink`。字型子集已重跑（1493 字／377KB）。
**尚未真人試玩。**

## 2026-08-12 四訂 —— buff 視覺回饋 ＋ 開局排版三度重做 ＋ 跳躍數值三項

使用者提供手繪排版圖＋真人試玩截圖，指出三選一開局排版即使升級全滿＋手套仍能一跳直達
中間選項。改用「間距本身擋死」取代三訂的「過渡板不置中」：起跳板→過渡列 A(2 塊)→過渡列
B(3 塊)→三選一排(3 塊)，三道間距一律 `BUFF_INTRO_GAP`(165px)，任兩道相鄰加總(330px)超過
全點滿+手套的最大單跳可達高度(293.25px)，數學推導與稽核見 deviations.md「開局三選一增益」
列與 `tests/audit_buffs.gd`「常數：開局中繼列單跳跨不過」（已用突變測試確認抓得到）。

同批：護盾持有中常駐同心圓、鳳梨披薩／時間藥水使用瞬間外擴同心圓、時間藥水凍結敵人套藍色
濾鏡（`_frozen_tint()`）——畫法沿用既有 `_draw_ledge_fx` 一次性圈圈模式。跳躍數值三項：
懷錶二段跳 `WATCH_JUMP_RATIO` 1.0→0.5、踩頭彈跳改綁當前跳躍力 ×`STOMP_BOUNCE_RATIO`(1.5，
取代原本寫死的 `-780`)、DAHLAH 上限 2.0→1.5。另外清掉一處文件債：`CLAUDE.md`「核心玩法」
描述改成鍵盤為主（`ACTIVE_INPUT_MODE` 其實已經是 KEYBOARD 一段時間，MOUSE_DRAG 分支保留
不動，只是文件沒跟上）。全部細節唯一的家＝deviations.md 對應列，這裡不重複。

驗證：smoke 五組稽核全綠（增益組 57 項），新稽核用突變測試（暫時改小 `BUFF_INTRO_GAP`）
確認會抓到違規。`visual_check.tscn` 截圖 `buff_intro_check_layout.png` 目視確認階梯感
符合手繪圖。**尚未真人試玩**（DAHLAH 方向偏移 15 度那項使用者自己標注「可能要討論」，
本輪先擱置未做）。

## 2026-08-12 一訂～三訂（spike v19）—— Pameloe 寬限 ＋ 懷錶二段跳 ＋ 開局三選一增益上線

一訂三項：Pameloe 初見寬限 1.5s（畫面外計時器頂在寬限值而非充能時間）；懷錶＝通關關卡二
解鎖的二段跳（`SpikeSave.owns_pocket_watch()`）；開局三選一增益上線——固定佈局三塊平台＋
八種 buff＋左下角 HUD，抽 buff 走獨立 RNG（`_buff_rng`，見 `_build_buff_intro` 的 ⚠⚠：
骰在主序列上會讓關卡二／三整座井偏移，既有固定 seed 稽核卻照樣全綠，是新寫的
`audit_buffs.gd`「抽 buff 不污染主 RNG」那條當場抓到的）。二訂／三訂：真人試玩回報「開局
一跳就被迫選中間」，過渡板改不置中＋三選一排收窄（後於四訂整個重做，見上）。
全部細節唯一的家＝deviations.md 對應列。

驗證：smoke 五組稽核全綠（增益組 45 項），三批突變測試確認新斷言抓得到。

## 2026-08-11 一訂＋二訂（spike v19）—— 子彈變速／solo 隔怪／平台鏡像／踩踏晃動／蟲洞背光／Kaela 姿勢 ＋ 兩條真人試玩 bug 修復

一訂六項（使用者要求）：Pameloe1 子彈 +50%；solo 區間怪物至少隔一塊乾淨板
（`MONSTER_SOLO_MIN_GAP`）；一般平台生成時隨機鏡像（只套 `platform_normal.png`）；踩踏晃動
（下沉 4px 阻尼震盪 0.28s，純視覺不動判定）；蟲洞逆光改方向性背光；Kaela 姿勢改看垂直
速度（不再只有落地瞬間 steady）。同批修掉一條假紅稽核：主題區 `force_kind` 檢查原本靠
「群裡最高那塊＝主鏈」認人，備援板同 y 時排序不穩定會誤判，改存 `WellPlatform.is_band_extra`
旗標。二訂：真人試玩回報蟲洞判定框跟畫面對不上（`WORMHOLE_SIZE` 沒跟著 08-10 匯入的視覺
一起放大，改成對齊 `WORMHOLE_ART_SIZE`）、Pameloe2 雷射碰到沒事（判定寬度 10→13.5）。
全部細節唯一的家＝deviations.md 對應列。

驗證：smoke 四組稽核全綠（含常數不變式），突變測試確認抓得到。

---

## 2026-08-10 六訂＋七訂（spike v19）

六訂（本輪之前已存在的未提交修改）：爆炸平台引信 2s→1s、半徑 80→108（使用者要求 ×1.5
到 120，但 120 撞破 `EXPLOSIVE_RADIUS + PLAYER_SIZE.y*0.5 < SPACING_MIN_AT_TOP` 這條保命
條款不變式，改採「放大到安全上限」108，留 3px 餘裕，`_audit_explosive` 過）。

七訂：平台換真實貼圖＋尺寸統一。四態貼圖（`platform_normal/break/jump/move.png`，
`.claude/docs/art-assets.md` 例外六）換掉純色矩形 placeholder，`well_world._draw_platform`；
EXPLOSIVE／VERTICAL／CIRCULAR 共用 normal 貼圖，靠既有 `WellPlatform.color()` 的 modulate
顏色分辨種類，不另外做專用圖。貼圖尺寸基準是 normal.png 的 alpha 內容佔畫布比例（寬
0.8283／高 0.6064，四張共用同一組比例換算，同角色多姿勢共用同一比例是既有慣例）；錨點是
頂部對齊碰撞箱頂緣，不是腳底錨點（平台是被站的東西，不是站在東西上的東西）。同批拿掉
`PLATFORM_WIDTH_MULT_SOLO`(×1.3)／`START_PLATFORM_WIDTH_MULT`(×5) 兩個寬度倍率——貼圖是
固定比例畫布，加寬會拉伸變形，平台尺寸全面統一；終點平台仍全寬但改 `_draw_platform_tiled`
手動迴圈貼磚，不整張拉伸——⚠⚠ 一開始用 Godot 內建 `draw_texture_rect(tile=true)`，實測發現
它貼磚是照貼圖原生像素尺寸鋪、不縮放配 rect，套視覺尺寸傳進去直接爆版（磚塊比預期大好幾倍、
往下溢出整個畫面，靠 `visual_check.tscn` 截圖抓到），改成手動迴圈逐塊畫才修正。

solo 區間安全性：拿掉加寬後改由巡邏範圍全扛，`MONSTER_PATROL_RANGE_SOLO` 18→10、
`SOLO_FOOTHOLD_MIN` 24→17（落腳窗理論值降到 17.5px，見 `spike_config.gd`「平台不再靠加寬」
段落推導，稽核 `_audit_solo_foothold`）。

排查發現：拿掉寬度倍率後，`_audit_segments` 用的固定 seed 13579 撞上「moving 主題區備援
跳板機率性擺不下」——`_pick_x_apart` 的 exhaustive 掃描仍有約 1% 殘留機率整個可達視窗擠不下
（`_pick_x_apart` 自己的註解早就承認過）。用 60 顆 seed 做過 A/B：拿掉寬度倍率前基準率
1.06%、拿掉後 0.98%，同一量級，證實不是這次改動造成的迴歸，只是 RNG 序列位移後剛好讓
13579 撞雷。換掉稽核固定 seed（13579→20260811）解決，殘留問題本身另開追蹤任務。

---

## 2026-08-10 尾段（金光／充能圈改沿貼圖輪廓 ＋ 開發者傳送鈕）

使用者看了後段的截圖，指出兩圈**都還是長方形**，要求比照 kaela 無敵狀態沿貼圖外緣走。
改法是把 `_draw_sprite_outline`（原本只服務 kaela 無敵窗）多收一個寬度參數、變成三處共用，
蟲洞與 Pameloe 各自載入剪影（`_wormhole_sil` / `_pameloe_sils`，`_make_silhouette` 在
`_load_hazard_textures` 一次算好）。⚠ 兩處都得把描邊移到 `draw_texture_rect` **之前**——
輪廓靠的是本體蓋住中間、只露外圈，畫在後面等於整隻被塗白。新常數：
`WORMHOLE_GLOW_{OUTER,INNER}_{W,ALPHA}`（4c）、`PAMELOE_CHARGE_OUTLINE_WIDTH`（4b）。
缺貼圖的 fallback 兩條路都維持原本畫方框（沒有 alpha 輪廓可描）。

**開發者傳送鈕**（使用者要求，用來跳過爬升直接測高處內容）：畫面右緣中間 `▲ +300 m`，
規則與 ⚠ 全部住 `spike_well/CLAUDE.md` 偏離表「開發者傳送」列與 `spike_config.gd` SECTION 11，
這裡不重抄。施工過程值得記的三件事：① 開關做成 debug build／`--dev`／`?dev=1` 三擇一，
是因為使用者明說「第一版上線後其他版測試還會用到」——只吃 debug build 的話每次要測都得
另外出一包跟玩家不同的東西。② `JavaScriptBridge` 用 `Engine.get_singleton()` 動態取，
直接寫識別字會讓桌面版**解析期**就整支腳本載不起來。③ 按鈕第一版用
`set_anchors_and_offsets_preset(CENTER_RIGHT, MINSIZE)` 排，Button 拿自己算的最小尺寸排版、
右半邊被切出畫面外——稽核當時是綠的，是 `visual_check` 截圖才看到，事後補了「整顆要在畫面內」
那條斷言。驗證：smoke 15 項 UI 稽核全綠（新增 `_audit_dev_teleport`，並用兩次突變測試
確認它抓得到「按鈕永遠建出來」與「作弊局仍寫金幣」）＋ `visual_check` 新截圖
`hud_check_dev_button.png`、蟲洞／Pameloe 兩張輪廓圖肉眼確認。

## 2026-08-10 後段（鏡像方向二次修正 ＋ 踩頭判定框置中 ＋ Pameloe 充能圈／蟲洞金光貼合外緣）

真人試玩回報 chattini 鏡像方向又反了（跟 kaela 08-09 同一種坑，方向相反）：
`_draw_patrol_monster` 原本猜「來源圖面向左」（往右走才鏡像），這次確認來源其實面向右，
改成 `m.facing() < 0.0` 才鏡像。**踩頭判定框置中**：前段「貼圖底部錨點」修正只挪了 art
的位置，判定框（`WellMonster.rect()`）沒有跟著移，於是判定框整條落在視覺下半部（踩頭
腳陷進牛背）。改法：PATROL 判定框改成對齊 art 視覺中心而不是貼平台上緣，偏移量
`SpikeConfig.MONSTER_HITBOX_CENTER_OFFSET_Y` 直接從
`MONSTER_ART_SIZE.y*(MONSTER_ART_FEET_FRAC-0.5)` 推導，不是另存一個數字，換 art 尺寸／
錨點會自動跟著算。⚠ 這個改動讓 `mr.end.y`（判定框底邊）不再等於平台上緣，
`_draw_patrol_monster` 的 art 錨點公式因此改用 `m.pos.y + m.size.y*0.5` 直接算（不依賴
`rect()`），避免判定框搬家連帶把貼圖也搬走、重新引入上一輪剛修好的「貼圖沒貼平台」問題。
**Pameloe 充能圈**改成貼 `art_rect`（88×88）外緣、固定 2px 描邊、不再隨充能放大（原本貼
判定框 44×44，看起來像立繪中間浮一個小方框）。**蟲洞常駐外緣金光**：貼圖版新增對外 3px
兩層描邊（`C_WORMHOLE_GLOW`，外層寬淡、內層窄亮）模擬逆光暖金色，純視覺、不參與判定，
缺檔 fallback 不受影響。四項回歸：headless smoke 19+14+8 全綠 ＋ 4 局 bot，
`visual_check.tscn` 另拍新截圖肉眼確認（鏡像方向、貼圖仍貼平台、充能圈貼合、蟲洞金光）。

## 2026-08-10 中段（Pameloe 貼圖上線 ＋ 關卡制上線 ＋ 新稽核組 audit_levels）

**Pameloe 貼圖上線＋錨點修正**。`pemaloe1/2.png` 縮成 88×88（`PAMELOE_SIZE`×2）落地
`assets/sprites/pameloe1.png`／`pameloe2.png`，90%／10% 抽取（`PAMELOE_RARE_ART_CHANCE`，
生成當下用 gen 的 seeded rng 骰一次記進 `WellMonster.art_variant`，不在繪製時骰）。怪物與
蟲洞改成「alpha bbox 底邊貼齊平台上緣」（`MONSTER_ART_FEET_FRAC`／`WORMHOLE_ART_FEET_FRAC`），
不再中心對齊——根因是 art 尺寸是碰撞尺寸的 2 倍，中心對齊會讓貼圖底邊沉到平台上緣下方
21px，18px 厚的平台整塊被蓋住。

**關卡制上線**。三關 1000／1500／2000m（`SpikeConfig.LEVEL_GOALS`，SECTION 8d），抵達即
成功結算＋解鎖下一關＋播劇情（佔位文字）；已解鎖的關可自由回頭重玩。`cleared` 訊號重新
接回 `_check_end`。無盡模式改成右上角第三顆開關，與關卡、極限三個維度完全獨立可任意組合。
存檔 schema v2→v3（登頂用時從單一純量拆成每關一格，舊值遷進關卡一）。三個登頂成就判定
條件不必改——任一關卡登頂都算 cleared（使用者拍板）。細節與公式唯一的家是
`spike_well/CLAUDE.md` 偏離表「終點」「關卡」「無盡模式」三列。

**新稽核組 `tests/audit_levels.gd`（8 條）**：關卡表常數關係、解鎖鏈、`selected_level` ⇄
`goal_meters` 同步、跨關難度不變性、登頂訊號（有終點會 emit／無盡不會／差 1m 不會提前）、
存檔 v2→v3 遷移、Pameloe 立繪分佈、貼圖錨點 vs PNG 實際 alpha。`audit_ui.gd` 加三條版面
斷言。⚠ 兩條突變測試都紅了才收（拿掉無盡守衛／把 pameloe 分母改回 `goal_meters`）。
回歸全綠：19（機制）＋14（UI）＋8（關卡）＋ bot 4 局，`visual_check.tscn` 另拍 5 張新截圖，
存在 `spike_well/tools/out/`。`coin.png`／`fuel.png` 使用者仍未表態，留在

---

## itch.io 上架前檢查清單首次盤點（2026-08-16）

`checklist.md`（14 節、200+ 項）首次逐項核對，區分「已完成」「刻意延後」「你要做的手動項」。
完整現況與待辦已收斂進 checklist.md 本身（本次盤點後大幅改寫，只留未完成項＋狀態註解）與
[HANDOFF.md](HANDOFF.md)「itch.io 試玩發佈」段落，這裡只記**這次做了什麼**。

**存檔系統（§11）比清單假設的成熟很多**：`autoload/spike_save.gd` 讀檔遷移、白名單回填、壞檔
備份、匯出/匯入碼原本就已存在。本次新增：`game_version` 除錯欄位、讀檔擋「存檔版本比程式新」
（比照壞檔備份模式）、`save()` 改原子寫入（`.tmp`→驗證→改名）。全套 smoke 跑過，全綠。
兩處刻意不改，已記錄取捨：①遷移邏輯維持版本門檻級聯，不拆鏈式函式（3 版內仍清楚）；
②白名單回填不改成「保留未知欄位」（防污染的刻意設計，代價與重新評估條件見 COMPATIBILITY.md）。
內容資料表外部化（清單建議 JSON/CSV）判定不適用本專案——與 CLAUDE.md 硬規則第 1 條衝突，
維持現行 `spike_config.gd` 集中制。

**新建 7 份文件**（皆在 `spike_well/`）：`SAVE_FORMAT.md`（存檔 schema 快照）、
`COMPATIBILITY.md`（SemVer 三層級承諾＋ID 穩定性政策＋版本歷史表）、`COMPLIANCE.md`（§6
逐項自評，首次檢視日 2026-08-16）、`THIRD_PARTY_LICENSES.md`（Noto Sans CJK TC／Godot
Engine 已登記）、`CHANGELOG.md`（Keep a Changelog 格式骨架）、`test-matrix.md`（§8 空表，
SSOT 搬出 checklist.md）、`store/metadata.md`（AI Disclosure／Adult content／Inputs 已填）。

**遊戲內新增**：`SpikeConfig.GAME_VERSION`（"0.1.0"，唯一版本號來源）＋`DISCLAIMER_TEXT`
（清單 §12 繁中範本原文）。設定頁顯示版本號、工作人員名單頁顯示免責聲明——兩處都選在版面
較寬鬆的頁面（`_build_settings_panel`／`_build_credits_panel`，band 0.03~0.97），刻意避開
主頁 `_build_start_panel` 的緊繃版面預算（該版面已有 audit 斷言守 10px 餘裕，見
`tests/audit_ui.gd`「主頁版面」）。

**盤點結論**：§1（帳號）／§4（商店美術）／§9（tags 等決定）／§10（發佈步驟）本質是手動
itch.io 操作，沒有可派工的程式任務。§3.2（排行榜）／§7（i18n 字串化）依 HANDOFF 既有決定
刻意延後，非本次遺漏。§0 四題決策（D-1～D-4）仍待使用者拍板，未強行代答。
`C:\Users\gnt0233\Downloads\kaela\` 沒動。

## 2026-08-10 前段（無盡加壓 ＋ 第二批貼圖匯入）

**無盡加壓上線**。新增 `DIFFICULTY_RAMP_HEIGHT_M`（1000.0，地形軸分母）；`well_generator` 的
`ensure_generated_to`／`_force_resolve_pending_wormholes` 拿掉 `goal_spawned` 永久停生的
守衛，`spacing_at` 與 `_lerp_by_height` 的 t 改讀 `DIFFICULTY_RAMP_HEIGHT_M`（地形軸在
1000m 凍結，不再繼續變難）；`well_world._check_end` 拿掉 1000m 強制停局那段；三條封頂軸
（投擲物／抽跳板／黑洞 `interval_min`）與側風 `SHOCKWAVE_RESPONSE` 改吃
`SpikeConfig.eff_*(height_m)` 階梯函式，住 `spike_config.gd` SECTION 9c。一次性驗證腳本
（生井到 2200m ＋數值抽查，跑完即刪未留檔）與 headless 回歸（19+14+bot 4 局）皆綠燈。
⚠ 這一版的副作用是 `cleared` 訊號沒有任何 emit 端、三個登頂成就打不到——同日稍晚由關卡制
接回（見 HANDOFF 當前狀態）。

**第二批貼圖正式匯入**（怪物 chattini／蟲洞 the_sheep／投擲物 cucumber，使用者拍板比照
Kaela SOP）。三張都用 Python PIL Lanczos 縮到「碰撞/顯示尺寸 ×2、鎖一軸依來源比例算另一軸」：
`MONSTER_ART_SIZE(67,84)`、`WORMHOLE_ART_SIZE(115,88)`、`PROJECTILE_DRAW_SIZE(116,51)`
（cucumber.png 真實比例 305:133，鎖長軸不動）。接線：`_draw_patrol_monster`（依
`WellMonster.facing()` 鏡像）、`_draw_wormhole` 改靜態貼圖（不轉——來源是站定的羊，硬套 spin
會變直升機羊）、`_draw_projectile` 沿用既有旋轉；三處都保留缺檔退回純色 `_draw()`。
**判定框形狀跟著調**：`PROJECTILE_HIT_SIZE` 60×60 正方形 → 同比例矩形 `(90,40)`，
面積鎖死跟舊版一樣是 3600，只調形狀不調寬鬆度／難度。
⚠ 這批第一版的**貼圖錨點接錯**（中心對齊，貼圖底邊沉進平台裡），同日稍晚修成腳底錨點。

## 2026-08-09 續四（無敵描邊 ＋ 鏡像翻轉 ＋ 跨階高度徽章）

**無敵框改成沿 alpha 輪廓的描邊**（2px，`KAELA_OUTLINE_WIDTH`；剪影 ×8 方向偏移，不用
shader——`draw_texture_rect` 吃整個 `CanvasItem` 的 material，掛上去會連平台怪物一起描邊）。
**左右移動貼圖鏡像翻轉**（`WellPlayer.facing`，滑鼠與鍵盤兩條路徑都接；記的是輸入意圖不是
`sign(速度)`，跟著速度走會在原地反覆翻面）。
**鏡像方向修正**：`_draw_player_sprite` 判斷式原本寫反（面向左才鏡像），真人試玩發現按 A/D
時朝向跟移動方向相反，改成面向右才鏡像。
**跨階高度提示**：左上高度數字改白框徽章，底色依 `SpikeConfig.tier_at()`（每 500m 一階）
變色，黑灰→綠→黃→橘→紅→紫、3000m 後維持紫；常數／函式住 `spike_config.gd` SECTION 9c。

## 2026-08-09 續三（Kaela 玩家貼圖試接，打破 placeholder 硬規則）

使用者提供 3 張 AI 產圖（steady/jump/jetpack，原始 155×215），確認要提早接進 spike（打破
`spike_well/CLAUDE.md` 規則 4「不引入美術資源檔」，已在該檔規則 4 補例外二＋新增「美術素材
匯入 SOP」一節，供之後其他角色/物件比照，不用重新想一次）。

**尺寸判斷**：目標＝`PLAYER_SIZE`(38×54) × 2 = 76×108；來源 155×215 幾乎精準是目標的 2 倍
（非隨機跑偏），等比縮小鎖高 108px（寬隨比例得 78px，Lanczos），縮完存
`spike_well/assets/sprites/kaela_*.png`。

**錨點**：量 steady 幀縮圖後的 alpha bbox 底邊 ÷ 畫布高＝99/108，訂為
`SpikeConfig.KAELA_FEET_ANCHOR_FRAC`，三態共用同一比例（不個別重量，避免切姿勢時角色跳動）。

**接線**：`well_world.gd` 新增 `_draw_player_sprite()`，依 `land_flash_timer>0`／`jetpack_on`
選材質，`draw_texture_rect()` 取代原本 `draw_rect(player.rect(), C_PLAYER)`；新增落地閃現
（`WellPlayer.land_flash_timer`／`trigger_land_flash()`／`tick_land_flash()`，接在
`_check_landing()` 與主迴圈的 `tick_invuln` 旁邊），碰到平台起算 0.1s（`LAND_FLASH_TIME`）內
顯示 steady 姿勢；移除原本 jetpack 的色塊火焰（貼圖本身已畫火焰，避免疊兩層）。缺材質會退回
原本色塊，不會讓玩家消失。

**匯入設定**：`project.godot` 新增 `[importer_defaults] texture { mipmaps/generate: true }`
＋ `[rendering] textures/canvas_textures/default_texture_filter=2`（Linear Mipmap），比照已拍
板的正式版美術規範，套用到之後所有貼圖，不用逐檔調。

**驗證**：headless 回歸（生成器＋19 機制＋14 UI＋bot 4 局）全綠。目視驗證另寫
`spike_well/visual_check.tscn`（非稽核，留著給下次沿用）——直接建 `WellWorld`、手動撥
`player` 狀態、`get_viewport().get_texture().get_image().save_png()` 存 PNG，不靠 OS 截圖；
⚠⚠ 過程中確認了「08-08 截圖抓到空白幀」的根因：**headless 底下 `RenderingServer` 是 dummy
driver，畫面本來就是空白**，這條路一定要不加 `--headless` 才能真的渲染。三態貼圖輸出比對：
頭頂位置三張完全一致、腳底位置 steady/jump 幾乎重合、jetpack 火焰粒子自然垂在腳下，無跳動
無穿模。

## 2026-08-09 續（spike v17 ＋ 暫停／燃料／推力三項小修）

**v17**：`smoke.gd` 拆檔（1937 行 → orchestrator 84 行 ＋ `tests/` 五個檔：generator／
mechanics／hazards／ui／bot_run，索引住檔頭）。Pameloe 出現率 500m 起 8%、1000m 24%
（原 16%→26%），插值 t 改從登場高度起算。死亡演出改版：爆炸 0.55s（世界完全凍結）→
演完才進結算 → 結算資訊裝進佔畫面 3/4 的小卡由下往上推入，背景保留最後一幀（只壓暗）。
存檔加 `schema_version`、壞檔改名保留、匯出／匯入碼、榜單三項準備（登頂時間落盤、
一般／極限拆欄位、開局記 RNG seed）。字型換 Noto Sans CJK TC（1299 字／325 KB）。
全綠：headless import 0 error、生成器＋機制 19 項＋UI 14 項＋bot 4 局。

**同日續（三項小修）**：
1. **暫停沒真的暫停**——`World` 節點沒設 `process_mode`，繼承 `Main` 的 `PROCESS_MODE_ALWAYS`，
   `get_tree().paused` 對它沒用。改成明確設 `PROCESS_MODE_PAUSABLE`（`main.gd`）。
2. **燃料補給改定值 +7m**（原「補上限 10%」，`FUEL_PICKUP_REFILL_RATIO` →
   `FUEL_PICKUP_REFILL_METERS`）。
3. **移除「噴射推力」商店升級**——確認過燃料消耗按「上升距離」扣
   （`well_world._step_jetpack`），跟上升速度無關，這顆升級不影響燃料效率，使用者拍板
   整項刪除。`UPGRADE_TABLE`/`UPGRADE_ORDER`/`UPGRADE_ICON_COLOR` 移除 `thrust` key，
   `jetpack_thrust_speed()` 回傳固定基礎值，商店卡片數 6→5。

三項皆已跑過 headless 回歸測試（19 項機制稽核＋14 項 UI 稽核＋4 局 bot）全綠。

## 2026-08-09（spike v16）—— 第二種敵人 Pameloe

新增 500m 以上的懸浮定點射手 Pameloe：不巡邏、不跟隨平台，每 2s 朝 Kaela 當下位置射一發
直線子彈（穿透平台、碰到井壁消失、命中即死）。實作為 `WellMonster` 的第二個 `kind` 而非
獨立系統——踩頭／鞭子／無敵撞飛／死亡演出／prune 五套判定完全共用，新檔只有
`src/pameloe_shot.gd`。全綠：生成器＋機制 18 項＋UI 12 項＋bot 4 局，字型子集 1241 字／357 KB。

同輪回答了 5 個規劃性問題（資源消耗率、itch.io 更新不覆蓋存檔、無盡模式可行性、全玩家榜單、
i18n 四語系），結論住 HANDOFF 的「未動工但已有定論」，不重複於此。

## 2026-08-08 四輪（spike v15）—— 干擾參數調整 ＋ 成就階梯化 ＋ 設定頁 UI

四種干擾預警時間統一改 1s（原投擲物/黑洞/側風 2.0s、抽跳板 0.5s）；側風改「10s 一輪、
吹 1s」（原吹 3s／12s 一輪）；黑洞事件視界半徑 ×1.5（34→51）。主頁「成就」按鈕加紅色
驚嘆號（有可領獎成就時顯示，`SpikeSave.has_claimable_achievement()`）。披薩／義大利麵／
Chattini／遊玩次數 四個成就拆 I/II/III 三階（門檻 ÷2／×2，原數字當 II，獎勵 20/50/100，
使用者拍板）。設定頁鍵位文字改置左、拿掉下方操作說明區塊（順手刪掉變死代碼的
`_control_instructions()`）。全綠：headless import 0 error、生成器＋機制 17 項＋UI 12 項
（含新增成就階梯 chain 稽核）＋bot 4 局；已重跑字型子集（1219 字／349 KB）。

**階梯成就的關鍵設計（下次動成就系統前必讀）**：三階**共用同一張卡片版位**，不是新增
8 張卡片——`ACHIEVEMENT_TABLE` 底下還是 17 個獨立 leaf id（各自判定/存檔/領獎互不相干），
但成就頁 grid 版位數固定讀 `ACHIEVEMENT_SLOTS`（9 個）。UI 每次 refresh 用
`SpikeSave.current_tier_id(slot)` 動態問「這個版位現在該顯示哪一階」——不能在卡片建構
時就把 id 綁死，領完低階後同一張卡片要能顯示、也能點到下一階。

**四種預警飽和／同時觸發的風險評估（v13 分析，v15 已確認沒問題，結案）**：舊版預警時間
2.0/0.5/2.0/2.0s、間隔隨時間遞減，曾算出投擲物預警在 147s 後會首尾重疊、四種預警
結構上有 31% 機率同時亮（相位平移後）。v15 把預警全部縮到 1.0s 後使用者確認現況可接受，
不再追蹤。

**v10-v15 累積的真人試玩觀察清單（使用者已確認現況沒問題，結案）**：67s 干擾＋鞭子砍半
＋燃料削弱容錯、蟲洞過場 0.5s 順不順、攀爬特效明顯度、690m 以上單塊區間難度、投擲物
判定 ×2 閃避、碎裂淡出 0.45s 誤判、側風綠條擋視線、20% 退鞭子頻率感、墓碑 10 金幣
值不值得、黑洞吸力/壽命、極限模式撐幾秒、成就橫幅擋視線。

**成就獎勵分級（部分結案）**：v15 已把披薩／義大利麵／Chattini／遊玩次數四個按難度分級
（20/50/100）。其餘 5 個（魂系玩家／Chattini的典範／蜘蛛人第二代／BIG CAT／speed run）
仍一律 +50，使用者確認現況可接受、非緊急待辦。

---

## 2026-08-08 三輪（spike v14）—— 極限模式 ＋ 手套開關 ＋ 成就系統

**極限模式**（主頁右上 `極` icon，跨局記住）：所有干擾等待歸零，`SpikeSave.extreme_mode`
＋`SpikeConfig.eff_*()` 五個函式。**攀爬手套啟用開關**（主頁右上 `爬` icon，買了才顯示）：
`SpikeSave.ledge_enabled`／`has_ledge_grab()`。**成就系統**：9 個、三態（未解鎖／已解鎖
未領獎／已領獎）、+50 金幣要點卡片才領，config SECTION 8c＋`SpikeSave` 成就區塊＋
`SpikeUI` 成就頁。成就解鎖橫幅（3s，末段 0.6s 淡出，多個排隊逐播）。主頁多一顆「成就」
按鈕（四顆，band 上緣 0.52→0.48）。

**這輪學到的四件事**：
1. **`eff_*()` 這種「生效值」函式最大的風險是靜默失效**。極限模式把等待歸零，但任何一處
   忘了改成 `eff_` 就照舊讀 67 秒——不報錯、不崩潰，只是那一項干擾不進極限模式。
   所以稽核不是驗「模式打開了嗎」，而是驗**四種干擾第一幀都真的開始施作**。
2. **`WellWorld.reset()` 有兩個呼叫端**（`_ready()` 建構世界時也跑一次）。「遊玩次數」原本
   算在那裡，於是開啟遊戲就先送一次，玩一局變兩次。真正的「開一局」入口是
   `main._start_run`。⚠ 冒煙測試現在直接驗「reset 不得動到 plays」。
3. **「解鎖」與「入帳」必須只有一個出口**。使用者要的是點卡片才拿錢，所以
   `check_achievements()` 一毛錢都不給；兩處都給就是一個成就領兩份。
4. **版面爆版只有截圖看得出來，但要改成量得到的**。成就卡片高 240 時把「返回」擠出圓角
   外框（數字上「9 張放得進去」是對的，錯的是按鈕）。改成 228 並把
   `ACH_BACK_BAND_BOTTOM` 提成常數，冒煙測試現在直接算按鈕下緣有沒有超出 `PAGE_MARGIN`。

---

## 2026-08-08 一、二輪（spike v12／v13）

**v13 做的五件事**：解鎖時程改 67／87／107／127s（每階 +20s，`SECTION 8` preset 的四個
`stage_*_offset`）；側風改**間歇陣風**（吹 3s 休 9s，力道仍隨時間遞增）；**第四種干擾黑洞**
（吸力＋碰到即死＋無敵可消＋5s 塌縮，`DOOM_*`／`Interference.Doom`／`WellPlayer.doom_vel`）；
怪物死亡演出 1.1s → 0.6s；移除左上高度進度條。

**v12 做的七件事**：側風預警、削板火花、投擲物 ×2、碎裂平台淡出、怪物死亡拋物線＋20%
退鞭子、HUD 改顯示本回合最高高度、墓碑（歷史最高高度處，10 金幣）。

**這兩輪仍然有效的四條認知**：

1. **「大小 ×2」要連判定一起乘**。只放大視覺會讓「判定寬鬆」的承諾反過來變欺騙，
   只放大判定是隱形的難度上調。⚠ 判定寬 60 vs 玩家寬 38，閃避需求明顯變高。
2. **淡出必須在畫面內演完**。怪物死亡演出設 1.1s 時屍體 0.85s 就掉出畫面底，
   最後 40% 的淡出玩家根本看不到 ⇒ 看起來就是「沒淡出」。冒煙測試有一條直接驗這個位移。
3. **墓碑的「最相近平台」不能只比相鄰兩塊**——同區間的額外跳板落在主鏈那顆稍下方，
   很可能才是最近的。改成「生成鏈剛跨過目標高度時掃全場」。
4. **兩個 `stage_*_offset` 設成同值會讓中間那階永遠跳過**。冒煙測試現在直接驗四個
   offset 兩兩不等。

---

## 2026-08-07 四輪（spike v11）

干擾登場 130s→67s、衝擊波斜率 10→7、鞭子初始 10→5（升級上限 +3、共 8）、
jetpack 燃料消耗 ×1.5、燃料補給機率改隨高度遞減（0.20→0.13）、蟲洞 0.5s 順滑過場、
攀爬成功放白色同心圓擴散特效、`spike_config.gd` 漸進式揭露重構（585→627 行、數值零漂移）。

**衝擊波的真實行為（曾誤解，記下來）**：三種干擾是**累加常駐**不是三選一——
`Interference.stage()` 用 `>=` 判斷，解鎖後永久生效。衝擊波是獨立速度分量、
玩家操作抵銷不掉、無上限線性遞增，「必然墜落」由這條線成立，不是由投擲物或抽跳板。
但壓力是漸進的：解鎖當下力道 170 只有玩家全速 1400 的 12%（只是側風），要很久才漲到
100%（全力往右＝原地不動）。

**jetpack 為什麼削消耗而不削上限**：砍初始量（55→38.5m）會連帶把升滿上限拉低到
93.5m，天花板跟著降、升級表的價值感被削一角；乘消耗倍率是全程生效的效率削弱，
55→110m 這條升級曲線一個字不用動。實際效果：標示 55m 的燃料只推得動約 37m。

## 2026-08-07 三輪（spike v10）

蟲洞修好——**根因是串流 prune 早於出口綁定，機率為零而不是太低**：出口在上方 40m
（2000px），但串流生成只領先相機 720px，prune 又在相機爬過蟲洞約 754px 時就把它回收。
修法是生出蟲洞後就地把生成鏈推到出口高度之上。
另有：投擲物旋轉＋2s 落點預警、主頁重排、商店 6 卡、金幣率拉到 0.40、燃料補給、
攀爬手套、設定頁可重綁鍵、內嵌中文字型（Web 匯出讀不到系統字型 ⇒ 整頁豆腐方塊）。

## 2026-08-07 二輪（spike v9）

左右分佈平衡（EMA 反偏壓）、彈射無敵、蟲洞、金幣與永久升級商店、倒數計時。

## 2026-08-07 一輪

井拉到 1000m、密度隨高度遞減、平台防重疊（運動包絡線）、VERTICAL／CIRCULAR 平台。

## 2026-08-06

duty cycle 收緊至 50%、徵收 30%→20%、引擎拍板 Godot 4.6.1。數值正本在 PILLARS_2.md v8。


---

## 08-20 晚間收工（本機 session）

- 五批 commit：88611ca 教學開關／f6407a9 解鎖 icon／6be6de5 金幣雨 flaky／6be9425 治理修訂／
  2824c04 pebbles 預警爆炸；b3ea8d9 合併主頁背景分支；c7c73a2 handoff。
- 教學開關：`TUTORIAL_ENABLED=false` 短路 `main._start_run`；audit_tutorial 補雙向斷言（43 項）。
  評估過不加突變列（旗標由稽核自己控制＝matrix「稽核端也讀」MISS 類）。
- 金幣雨 flaky：根因＝`_start_loot_rain` 全域 randf＋其他雨滴巧合落入撿取框污染「碰到才入帳」；
  修法＝`_loot_rain_rng` 獨立 RNG（正式局照樣 randomize）＋稽核固定 seed＋隔離單滴。
  修前 1/8 紅、修後全套 6 連綠。
- pebbles 預警爆炸（第三關）：`arm_explode` 距離觸發→倒數原地凍結→引爆；`PebbleBlast` 仿
  WellBlast 不共用；`_audit_pebbles_explode` 7 項；mutations 補 pickup-grab-pad＋
  pebble-explode-radius（全表 10 RED-OK）。暫定規格見 HANDOFF 待拍板清單。
- 主頁背景分支：worktree 驗證（import 0 error＋全套綠＋title 截圖）後合併；合併後主 tree
  再跑 import＋全套綠。
- 治理實驗（本日主題）：兩個 Sonnet 子 agent 實測小任務成本 151k／135k tokens、60／56 呼叫
  ——地圖沒失靈（20 呼叫內完成主修改），大戶＝49k 基載＋驗證尾巴＋flaky 稅＋大文件整讀。
  對策落地：專案 CLAUDE.md（Grep 帶 glob／art-assets 索引）、全域 CLAUDE.md 硬規則 7（讀檔
  粒度看大小）、verification-matrix「修改稽核也要突變列」、/handoff 檢查表第 9 項（清
  tools/out）、evergreen 第 23 條（working tree 並行 commit 競態——本日實踩：主線在 agent
  施工中 commit＋pathspec 寫錯致檢查假陰性，靠 soft reset 重建五批乾淨 commit）。

---

## 08-20 x（雲端 session）：觸控三項＋裝置閘門

使用者規格三項，全在這次雲端 session 做完（**這台雲端環境沒有 Godot binary，全程只能靠
`gdlint`（另外 `pip install gdtoolkit` 裝的）語法檢查＋人工複查，一行都沒實跑過**，含新增
的 `_audit_layout_scan` 斷言本身——下次有 Godot 的 session 第一件事先跑一次完整 smoke）。

1. **裝置閘門**（解掉 Deferred §7 那句「觸控層目前無裝置閘門」）：`SpikeConfig.
   touch_ui_enabled()` 判斷式，`SpikeSave.device_mode`（""/"pc"/"mobile"）優先，空字串
   才退回 `SpikeConfig.is_touch_device()`（`DisplayServer.is_touchscreen_available()`，
   同 dev_mode() 那組 -1 快取慣例）。`_touch_controls.visible` 現在多一個 and 條件。
   設定頁「控制」分頁頂端加電腦/手機覆寫鈕（`_build_device_mode_row`）。第一次進遊戲
   （`SpikeSave.device_mode == ""`）在 `_advance_to_title()` 插一頁 S_DEVICE_CHOICE
   （開幕漫畫→解鎖卡之後、S_START 之前），兩顆鈕，不接「點畫面任意處關閉」那套手勢
   （逼玩家真的點中一顆）。`clear_runtime()` 也清 device_mode，開發者洗檔能重新走一次。
2. **鞭子觸控 HUD**（修掉 08-20 平板實測「鞭子完全叫不出來」——**根因**：鞭子瞄準走
   `well_world.gd _unhandled_input` 比對 `InputEventKey`，觸控層 `SpikeKeys.
   set_touch_held()` 只覆寫 `is_action_pressed()` 輪詢路徑，產不出 InputEventKey，觸控層
   當時也還沒建第 6 顆鈕）：`_unhandled_input` 的 aim 分支抽成 `WellWorld._toggle_aim()`，
   新公開方法 `touch_toggle_aim()` 直接呼叫它；觸控層新增獨立一顆「鞭」鈕（疊在
   action_row 正上方，走 `offset_top/offset_bottom` 位移不是 `position`），按一下呼叫它，
   `update_hud()` 依 `whip.state==AIMING` 把鈕字改「取消」／透明度提高。發射不用新方法：
   `project.godot` 的 emulate_mouse_from_touch 早就把觸控點擊轉成滑鼠事件，`_unhandled_input`
   既有的開火分支直接吃得到，**這段理論上早該能動，純粹是進瞄準那一步從頭到尾沒有入口**。
3. **左右移動分置兩端**：`←` 留在左邊緣垂直置中不動；`→` 改走絕對座標
   （`SpikeConfig.TOUCH_RIGHT_BTN_TOP=160`）貼右邊緣，卡在右上角常駐 HUD（y≈24~91）與
   dev_mode 傳送/金錢/洗檔三顆鈕（y≈338~486）中間的安全區——**這個坑是這次才發現**：
   `tests/audit_ui.gd _audit_layout_scan` 會在 dev_mode／觸控層都開的情況下掃 OVERLAP，
   原本 `→` 打算跟 `←` 對稱貼右邊緣垂直置中會直接撞上 dev 那三顆鈕的 y 範圍。

`_audit_layout_scan` 補了兩處，讓上面三項不會靜默失去版面掃描覆蓋：①新增 "DEVICE_CHOICE"
進靜態畫面清單；②PLAYING/PAUSED 那輪原本觸控層必顯示、現在有閘門會 headless 環境下永遠
invisible 掃不到，改成暫時把 `SpikeSave.device_mode` 設 "mobile" 掃過一輪再還原。
`SETTINGS_CONTENT_HEIGHT` 420→500（「控制」分頁多一列裝置覆寫鈕）是估算值，沒有 xvfb 驗證
環境，收工前建議跑一次 `visual_check.tscn` 確認沒有溢出/裁切。

**後續（同一 session）：用 workflow_dispatch 手動驗過，CI 現在全綠。** 沒有本機 Godot，
改用 GitHub Actions 的 `workflow_dispatch` 在這個 feature 分支上手動跑 smoke（平常只有
push master／PR／tag 才會自動跑）：
- 第一輪真的抓到 bug：`tests/audit_tutorial.gd _audit_finish_isolated` 直接 preload
  main.gd 建節點、跳過開場劇情頁後斷言 `state == S_START`，但沒跳過新增的裝置二選一頁，
  state 停在 DEVICE_CHOICE，斷言誤判「不自動開局」規則壞了。比照既有的 story_seen 跳過
  寫法補上 `SpikeSave.device_mode = "pc"`（跑完照樣還原）即可。全專案只有這一處會撞到
  （`grep 'preload("res://src/main.gd")' tests/*.gd` 只有這一筆），headless bot 走的是
  `WellWorld.new()` 直接建世界，不經過 main.gd 狀態機，不受影響。
- 第一輪失敗時 log 只印得出「Process completed with exit code 1」，看不到任何 [SMOKE]/!!
  細節——查下去才發現 `.github/workflows/smoke.yml`「跑七組稽核」與「匯出 Web 版」兩步都是
  「指令 → 另起一行 `RC=$?`」，`run:` 預設 `bash -e` 一旦該指令非零結束就整步中止，
  `RC=$?`／後面的診斷 echo／grep／tail 全部印不出來——**這是既有 bug，不是這次改動造成，
  只是這次才第一次在失敗狀態下真的跑到**。改成 `RC=0` 起始 ＋ `... || RC=$?`，讓失敗吸收
  進同一顆複合指令不觸發 `-e`，`exit $RC` 照樣讓步驟正確標紅，只是現在看得到為什麼紅了。
- 修完兩個 bug 後第三輪：七組稽核＋headless bot 全線 `[SMOKE] PASS`。`_audit_layout_scan`
  的 OOB/TRUNC/OVERLAP 掃描也在這輪一起過了（含強制開手機模式那段新增的覆蓋）——但那組
  掃描本來就是幾何斷言，過了不代表 `SETTINGS_CONTENT_HEIGHT`／`TOUCH_RIGHT_BTN_TOP` 這類
  估算值目視起來好看，**視覺確認仍待 visual_check.tscn／真機**，見 HANDOFF 起點 1。
