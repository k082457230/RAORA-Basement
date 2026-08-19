# THIRD_PARTY_LICENSES — 第三方素材授權清單

> checklist.md §6.6 要求：每一項第三方素材（字型／圖片／插畫／BGM／音效／材質／原始碼／
> Godot 外掛）都要列出來源網址與授權條款。COVER 不會替你解釋第三方條款，缺一項就補一項，
> 不要等上架前才一次補。

**最後盤點日期：2026-08-19**
**盤點方式**：`ls assets/sprites/*.png`／`ls assets/audio/*.ogg`（`.import` 不算）取得實際
檔案清單，逐一比對 `.claude/docs/art-assets.md`（美術）／`.claude/docs/audio-assets.md`（音效）
兩份登記表的索引，雙向確認「文件有登記但檔案不存在」與「檔案存在但文件沒登記」兩種落差。

⛔ **本檔遵守的原則：查不到來源就標「⚠ 來源待確認」，不推測、不編造授權依據、不臆測平台名稱。**

## 雙向對照結果

**貼圖（`assets/sprites/*.png`，41 張）與 `.claude/docs/art-assets.md` 索引表：無落差。**
索引表（含各「例外」條目）逐一列出的檔名加總＝41，與實際檔案一一對應，沒有「文件登記但檔案
不存在」或「檔案存在但文件沒登記」的項目。

**音檔（`assets/audio/*.ogg`，39 個）與 `.claude/docs/audio-assets.md` 索引表：無落差。**
索引表加總＝39，與實際檔案一一對應，同上無落差。

（`.import` 檔為 Godot 匯入快取，非素材本體，不計入清點；`assets/fonts/NotoSansCJKtc.otf` 另列
於 A 段，不算在貼圖／音檔清點內。）

## 總覽

| 分類 | 項目數 |
|---|---|
| A. 明確授權的第三方素材 | 2（字型、引擎） |
| B. 專案自製／AI 生成素材 | 39 張貼圖 |
| C. ⚠ 來源待確認 | 2 張貼圖 ＋ 39 個音檔（全部音檔） |

---

## A. 明確授權的第三方素材

| 素材 | 用途 | 授權 | 來源 |
|---|---|---|---|
| Noto Sans CJK TC（`assets/fonts/NotoSansCJKtc.otf`，經 `tools/subset_font.py` 子集化） | 遊戲內繁中／英文字型 | SIL Open Font License 1.1（OFL） | Google Noto Fonts |
| Godot Engine | 遊戲引擎 | MIT License | godotengine.org |

---

## B. 專案自製／AI 生成素材（貼圖，39 張）

**生成方式的證據基礎**：`.claude/skills/import-art-asset/SKILL.md` 本身定位敘述即為「要把
**AI 產生的圖**接進 spike_well 遊戲時用」，`COMPLIANCE.md`（2026-08-19 自評）「AI 生成內容揭露
提醒」一節據此認定專案素材美術以 AI 生成為主。以下清單依此專案既定慣例歸類，但 **`.claude/docs/art-assets.md`
本身並未逐檔記錄使用的生成工具／服務名稱**——這是已知缺口，見下方「要問使用者的問題」。

**商用授權自評**：`COMPLIANCE.md` 已記錄「不使用官方 logo／商標字體／官方立繪／官方素材」一項
為 ⚠ **待使用者親自目視確認**（尤其 `kaela_*`／`pameloe*`／`monster_chattini` 等角色立繪是否與
hololive 官方立繪神似到有爭議，屬主觀判斷，程式面查不出來）。本檔不重複下結論，只如實引用該
自評狀態——**尚未完全結案**。

| 素材（檔名） | 用途／掛點 | 生成方式 | 備註 |
|---|---|---|---|
| `kaela_jetpack.png` / `kaela_jump.png` / `kaela_steady.png` | 玩家角色三姿勢立繪 | 專案慣例＝AI 生成 | 08-09 使用者拍板提早試接 |
| `monster_chattini.png` | 怪物立繪 | 專案慣例＝AI 生成 | 08-10 使用者拍板 |
| `wormhole_the_sheep.png` | 蟲洞立繪 | 專案慣例＝AI 生成 | 08-10 使用者拍板 |
| `projectile_cucumber.png` | 投擲物立繪 | 專案慣例＝AI 生成 | 08-10 使用者拍板 |
| `pameloe1.png` / `pameloe2.png` | 第二種敵人（Pameloe）兩變體立繪 | 專案慣例＝AI 生成 | 08-10 使用者拍板 |
| `pickup_coin.png` / `pickup_fuel.png` | 物資（金幣／燃料）立繪 | 專案慣例＝AI 生成 | 08-10 使用者拍板 |
| `platform_normal.png` / `platform_break.png` / `platform_jump.png` / `platform_move.png` | 平台四態貼圖 | 專案慣例＝AI 生成 | 08-10 使用者拍板 |
| `buff_random.png` / `buff_stone.png` / `buff_shield.png` / `buff_pizza.png` / `buff_time.png` / `buff_coingun.png` | 六種增益球（世界 orb ＋ HUD 格） | 專案慣例＝AI 生成 | 08-14 批次，來源 128×128 縮到 112×112 |
| `icon_glove.png` / `icon_jetpack.png` / `icon_pocketwatch.png` / `icon_whip.png` | HUD-only 道具 icon | 專案慣例＝AI 生成 | 08-14 批次 |
| `pickup_loot_bag.png` | 卡包（第三種物資） | 專案慣例＝AI 生成 | 來源 `tcg.png`，08-17 更新版 |
| `monster_pebbles1.png` / `monster_pebbles2.png` / `monster_pebbles3.png` | 第三種敵人（pebbles）三變體 | 專案慣例＝AI 生成 | 08-14 批次 |
| `doom1.png` / `doom2.png` / `doom3.png` | 黑洞輪播三張 | 專案慣例＝AI 生成 | 08-17 使用者拍板 |
| `tail1.png` / `tail2.png` / `tail3.png` | 甩尾（干擾）三變體 | 專案慣例＝AI 生成 | 08-17 使用者拍板，來源 `Downloads/素材/tail1~3.PNG` |
| `bg_vignette.png` | 背景暗角疊圖 | **自製**：512×512 徑向漸層，程式／工具生成（非取自外部圖檔） | 08-11 續，零外部內容，風險最低 |
| `story_intro_1.png` / `story_intro_2.png` / `story_intro_3.png` / `story_intro_4.png` | 開場四格漫畫（同畫布透明遮罩四張） | **使用者原創手繪**（`.claude/docs/art-assets.md` 例外十一明載「使用者手繪四格排版」），**非 AI 生成** | 08-18 使用者拍板，來源 `Downloads/manga/manga1.PNG` |

⚠ 上表「專案慣例＝AI 生成」的項目，**個別檔案沒有逐一記錄使用哪個生成工具／服務**（Midjourney／
NovelAI／Stable Diffusion／DALL-E 等），也就查不到對應服務的商用授權條款文字——這件事本身
不影響「是否為原創圖像」的認定，但影響「該素材的著作權歸屬與再散布權利依據哪份服務條款」，
見下方「要問使用者的問題」。

---

## C. ⚠ 來源待確認

### C-1．貼圖（2 張，風險原因與音樂不同——不是「AI 生成」也不是「使用者原創手繪」）

| 檔名 | 風險描述 |
|---|---|
| `assets/sprites/death_explosion_sheet.png` | 來源是**真人拍攝的爆炸影片**（`.claude/docs/art-assets.md` 例外十二：來源 `Downloads/explosion (1).mp4`，540×540、30fps、4.1s、**綠幕**），用 ffmpeg 去背切幀而成——**這不是 AI 生成也不是使用者手繪，是實際拍攝的影像素材**，來源影片本身是使用者自己拍的、還是從網路下載的 stock footage／素材網站取得，完全沒有記錄。若是後者，散布這款遊戲等於重新散布他人拍攝的素材，需要對應授權或該素材本身是免費商用授權（如 CC0／Pixabay 等）的證明。 |
| `assets/sprites/bg_backroom_tile.png` | 井背景磚紋（`.claude/docs/art-assets.md` 例外七）由參考素材 `12.webp`（720×960，橄欖色人字紋圖案，文件特別註記「不是隨手拍的照片」）裁切一個週期做無縫貼磚而成。`12.webp` 本身的來源（AI 生成的紋理圖／某個素材網站下載／使用者自己合成）沒有記錄——「不是隨手拍的照片」這句話恰好排除了「使用者自己拍照」的可能性，反而提高了它是外部素材（可能受版權保護的紋理／材質庫圖片）的機率。 |

同一份來源影片 `explosion (1).mp4` 也是下方 `death_explosion.ogg`（爆炸音效）的來源，兩個檔案
共用同一個「來源影片出處不明」的風險，只需向使用者確認一次。

### C-2．音樂（4 首，風險最高，獨立處理）

`.claude/docs/audio-assets.md` 四首背景音樂全部只記錄「使用者提供 `Downloads/sound/`
底下的來源檔」與轉檔過程（ffmpeg 轉 `.ogg`），**沒有任何一首記錄原始出處、演奏者、或授權依據**。

| 遊戲內檔名 | 來源檔（使用者提供） | 用途 | 風險描述 |
|---|---|---|---|
| `kaela1.ogg` | `Downloads/sound/kaela1.mp3` | 主頁面背景音樂（隨機二選一之一） | 完整長度的背景音樂，最容易被辨識出是既有錄音；來源檔案名沒有透露曲名或作者 |
| `kaela2.ogg` | `Downloads/sound/kaela2.MP3` | 主頁面背景音樂（隨機二選一之一） | 同上 |
| `cancan.ogg` | `Downloads/sound/Cancan.mp3` | 井內（PLAYING）背景音樂，固定曲目 | 檔名強烈暗示是奧芬巴哈《天堂與地獄》〈康康舞曲〉（Galop Infernal，1858 年作品）——**曲子本身雖已進入公版（作曲家 1880 年過世，早已超過任何國家的著作權保護期），但這不代表這個 `.mp3` 錄音檔案本身是公版**。任何一個樂團／音樂家的現代演奏、錄音、混音都各自獨立受著作權保護，除非明確是該樂團／發行方以公版／CC0／商用授權釋出的錄音，或是使用者自己演奏錄製。目前完全不知道這份 mp3 是哪個錄音版本 |
| `dies_irae.ogg` | `Downloads/sound/DiesIrae.mp3` | Raora 登場後井內背景音樂，取代 cancan | 檔名對應中世紀額我略聖歌《震怒之日》（Dies Irae）——**旋律本身是公版素材，歷史上被白遼士、威爾第等作曲家在各自的作品中引用改編，但那些「引用改編」的版本（如威爾第《安魂曲》）以及任何現代演奏／編曲／錄音仍可能各自受著作權保護**。同樣不知道這份 mp3 是純聖歌吟唱、是某個公版年代久遠的老錄音、還是某個現代作曲家／樂團的改編演奏或商業錄音 |

⚠ **這是最容易踩雷的地方，寫清楚給後續檢視的人看**：「公版旋律」與「公版錄音」是兩件不同的
事——`cancan.ogg`／`dies_irae.ogg` 就算曲子本身年代久遠、旋律進入公版，只要這份 `.mp3` 是
某個現代樂團／音樂家的演奏或商業發行的錄音檔，那個**特定錄音版本**依然受著作權保護，直接
內嵌散布在免費／付費遊戲裡一樣構成侵權，除非能證明這個版本本身是公版或已取得商用授權。

### C-2a．檔案內嵌 metadata 實測（2026-08-19 補，這段是**證據**不是推測）

發現經過：在瀏覽器實跑 Web 匯出版時，Godot 開機階段固定印出 **72 行 `Unicode parsing error`**。
追根因追到 `cancan.ogg` 的 Vorbis comment 是 **CP1251（俄文）編碼**，Godot 用 UTF-8 解析失敗。
順著把 39 個 `.ogg` 的 comment header 全部 dump 出來，得到以下**原始 metadata 原文**：

| 檔案 | 內嵌 metadata 原文（節錄） | 這代表什麼 |
|---|---|---|
| `cancan.ogg` | `title=Канкан из опер. Орфей в аду` ／ `artist=Ж.Оффенбах` ／ `album=Приглашение на танец` ／ `date=1858` ／ `DESCRIPTION=Лонд.филар.орк. п.у. Ч.Герхарда` ／ `genre=Classic` | 曲目＝奧芬巴哈《天堂與地獄》康康舞曲（作曲 1858，**曲子確實公版**）。但 DESCRIPTION 明寫演奏者＝**倫敦愛樂管弦樂團、指揮 Charles Gerhardt**——這是一份**商業錄音**，Gerhardt 卒於 1999 年，該錄音的鄰接權（錄音著作）**顯然尚未到期**。⇒ 這一首等同「確認是受保護的第三方錄音」，不再是「來源不明」 |
| `dies_irae.ogg` | `album=Requiem in re minore K 626 & Missa Brevis in do maggiore K 220 "Spatzenmesse"` ／ `Full Name=03 Dies irae` ／ `artist=Wolfgang Amadeus Mozart` | 是**莫札特《安魂曲》K.626 第 3 曲**，不是額我略聖歌原型。曲子公版，但這是某張商業專輯的第 3 軌（`03 Dies irae` 是典型的 CD 抓軌命名），錄音版權同樣未知且大機率有效 |
| `kaela1.ogg` / `kaela2.ogg` | `major_brand=isom` ／ `minor_version=512` ／ `compatible_brands=isomiso2avc1mp41`（無 title／artist） | `avc1` ＝ H.264 視訊編碼標記 ⇒ 來源是**含視訊軌的 MP4 檔案**（不是純音樂檔），且 metadata 被剝乾淨。典型特徵符合「從影片平台下載後抽音軌」 |
| `come*.ogg` / `doom.ogg` / `jump.ogg` 等音效 | `DESCRIPTION=Create videos with https://cl…` | Clipchamp（微軟影片編輯器）的匯出浮水印字串 ⇒ 這些音效是**從 Clipchamp 產出的影片抽音軌**得來，不是音效庫下載檔 |

⚠ metadata 是**強證據但不是鐵證**（可被竄改、也可能是轉檔時從別處帶過來的）。但在沒有相反
證據前，`cancan.ogg` 與 `dies_irae.ogg` 應**直接當成「有第三方錄音著作權」處理**，不要再當
成「待確認」拖到上架。

**要結案需要跟使用者確認（每首都要問）**：
1. 這份錄音是使用者自己演奏／錄製的嗎？
2. 如果不是自己錄的，是從哪個平台／來源取得的（購買授權曲庫、免費商用授權音樂網站如
   Incompetech／Pixabay/Freesound、YouTube Audio Library，還是其他）？
3. 如果是購買或訂閱授權取得，授權條款是否明確涵蓋「內嵌進遊戲散布」這個使用情境？授權憑證
   是否有留存（不需要放進版控，但需要留存備查，比照 CLAUDE.md「商用／非商用授權判斷提醒」
   一節的既有提醒）？
4. （僅 `cancan.ogg`／`dies_irae.ogg`）這是哪個特定錄音版本／演奏者／發行方？

### C-3．音效（35 個檔案，全部——非樂曲但同樣缺授權來源記錄）

`.claude/docs/audio-assets.md` 每一批音效都只記錄「使用者提供 `Downloads/sound/` 底下的
來源檔」與轉檔過程，**沒有任何一個記錄是使用者自行錄製、AI 生成、還是取自某個音效庫（免費或
付費）**。逐檔風險程度低於樂曲（多為 1 秒上下的短促音效，被辨識出「是哪份商業素材」的機率
較低），但仍是「查不到授權來源」，依驗收條件全數列出：

| 素材（檔名，可合併群組） | 用途 | 授權狀態 |
|---|---|---|
| `come1.ogg` / `come2.ogg` / `come3.ogg` | Raora 登場音效（三選一） | ⚠ 來源待確認 |
| `jump.ogg` | 一般落地音效 | ⚠ 來源待確認 |
| `biboo_water1.ogg` ~ `biboo_water8.ogg` | 持石頭藥水落地音效（八選一） | ⚠ 來源待確認 |
| `bounce.ogg` | 彈射板落地音效 | ⚠ 來源待確認 |
| `wormhole.ogg` | 碰到蟲洞音效 | ⚠ 來源待確認 |
| `doom.ogg` | 黑洞材化音效 | ⚠ 來源待確認 |
| `pemaloe2.ogg` | 08-17 首批來源，目前未接線閒置 | ⚠ 來源待確認（即使未使用，檔案仍在版控內，散布時一併存在） |
| `death_explosion.ogg` | 死亡爆炸音效 | ⚠ 來源待確認，**與 `death_explosion_sheet.png` 同一份來源影片**（見 C-1 說明） |
| `button.ogg` | 按鈕點擊音 | ⚠ 來源待確認 |
| `check.ogg` | 購買成功／成就橫幅音 | ⚠ 來源待確認 |
| `coin.ogg` | 撿金幣音效 | ⚠ 來源待確認 |
| `get.ogg` | 撿非金幣物資／三選一增益音效 | ⚠ 來源待確認 |
| `clock.ogg` | Raora 登場倒數提示音 | ⚠ 來源待確認 |
| `fall.ogg` | 投擲物落下音效 | ⚠ 來源待確認 |
| `jetpack.ogg` | 噴射持續音 | ⚠ 來源待確認 |
| `throw.ogg` | 鞭子射出音效 | ⚠ 來源待確認 |
| `laser.ogg` | Pameloe 雷射變體開火音效 | ⚠ 來源待確認 |
| `shoot.ogg` | Pameloe 一般子彈變體開火音效 | ⚠ 來源待確認 |
| `no1.ogg` ~ `no4.ogg` | 碎裂平台踩碎音效（四選一） | ⚠ 來源待確認 |
| `laugh1.ogg` ~ `laugh4.ogg` | 擊殺怪物音效（四選一） | ⚠ 來源待確認 |

---

## 要問使用者的問題（每題可一句話回答）

1. **貼圖（B 段列的「AI 生成」項目）**：這些貼圖具體是用哪個 AI 生成工具／服務畫的（Midjourney／
   NovelAI／Stable Diffusion／DALL-E／其他）？
2. **`death_explosion_sheet.png`／`death_explosion.ogg` 共用的來源影片 `explosion (1).mp4`**：
   是使用者自己拍的，還是從網路下載的素材（stock footage）？如果是下載的，從哪個平台、什麼
   授權？
3. **`bg_backroom_tile.png` 的參考圖 `12.webp`**：這張圖從哪裡來的（自己拍／AI 生成／某個素材
   網站下載）？
4. **`kaela1.ogg`／`kaela2.ogg`**：這兩首背景音樂是自己演奏錄製，還是從哪裡取得／購買的？
5. **`cancan.ogg`**：這是哪個特定的〈康康舞曲〉錄音版本／演奏者／發行方？（曲子公版不代表這個
   錄音檔是公版）
6. **`dies_irae.ogg`**：這是純額我略聖歌吟唱、某個古老公版錄音，還是某位作曲家的改編演奏／
   商業錄音？
7. **音效類（C-3 全部 35 個檔案）**：這批 `Downloads/sound/` 底下的短音效是使用者自行錄製、
   AI 生成，還是取自某個音效庫（免費／付費）？如果是音效庫，是哪一個？

---

## 商用／非商用授權判斷提醒

參考 HoloCure 的作法基準：視覺與音樂全為原創、音效全部購買含商用授權版本。本專案目前**已有**
完整音效系統（不再是「暫不適用」的狀態，這句提醒需更新）；一旦上述問題有了答案，購買／取得
授權的音效與音樂務必確認授權涵蓋「內嵌進遊戲散布」這個使用情境，憑證留存備查（不放進版控）。
