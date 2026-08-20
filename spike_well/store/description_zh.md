# store/description_zh.md — itch.io 頁面文案（繁中主稿）

> checklist.md §5 的交付物之一。**唯一的家＝本檔**，checklist §5 只指向這裡，不重複貼內容。
> 上架時把下面「itch.io 描述欄位內容」整段複製貼進 itch.io 頁面編輯器（Header 2 分段風格
> 已經對齊 itch.io 自動生成區塊的視覺）。
>
> **狀態**：2026-08-19 首版草稿，依「目前程式碼已實作的功能」寫（來源：`src/well_world.gd`／
> `autoload/spike_config.gd`／`src/spike_ui.gd` 逐項核對，**不是** `../PILLARS_2.md` 的長期
> 設計願景——那份文件描述的地下室經營系統目前完全沒做出來，寫進頁面會違反 itch.io 品質指南
> 「不得描述不存在的功能」）。玩法仍在改，**每次功能異動後回來對一次這份文案還準不準**，
> 不要放著不管。
>
> **語言範圍**：本檔是繁中主稿（2026-08-19 使用者拍板：先出中文版，英/日/印尼待補）。
> ⚠ itch.io 是國際平台，**單一中文頁面對英語讀者不友善，正式上架前至少應該補一份
> `store/description_en.md`**（比照 §13 附錄 B 既有的三語檔名規劃：`_en.md`／`_ja.md`／
> `_zh.md`），本檔下方免責聲明段落已經同時附了英文版，可以先當最小限度的英語讀者交代，
> 但不能取代整頁翻譯。
>
> **待補值**（不是本檔職責，去對應 SSOT 填，這裡只提醒別漏）：Tags／Genre／
> Accessibility／Average session length 填 `store/metadata.md`；截圖／封面圖等圖像素材見
> checklist §13 附錄 B。

---

## 5.1 基本欄位建議

| 欄位 | 建議值 |
|---|---|
| Title | `RAORA'S BASEMENT`（已拍板，見 checklist §6.2） |
| Short description | 見下方「一句話簡介」 |
| Project URL slug | `raoras-basement`（標題已經不長，不強制改短，上架時再依實際可用性確認） |
| Classification | Game |
| Kind of project | HTML（網頁版）＋ Downloadable（Windows 下載版） |

### 一句話簡介（Short description）

```
快拯救 Kaela 逃出 Raora 的地下室
免費、非官方的 hololive 粉絲向遊戲。doodle jump-like，受keenBiscuit與PainguinMan 企鵝人的作品啟發所創作
```

---

## itch.io 描述欄位內容（正式貼上區）

### 免責聲明

**繁體中文**

```
免責聲明
本作為免費的非官方粉絲遊戲，與 COVER 株式會社及 hololive production
無任何從屬或合作關係。
本作依循「二次創作指南」與「二次創作遊戲指南」製作：
https://hololivepro.com/terms/
本作完全免費，不進行販售、募款、廣告等任何形式的營利行為。
所有美術、音樂與音效素材皆為本作原創或已取得合法授權，詳見致謝名單。
```

**English**

```
DISCLAIMER
This is a free, unofficial fan game. We are not affiliated with hololive
production or COVER Corp. in any way.
This project follows the hololive production Derivative Works Guidelines
and the Guidelines for Derivative Work Games:
https://hololivepro.com/en/terms/
This game is completely free. There is no monetization of any kind
— no sales, no donations, no ads, no paid content.
All art, music, and sound assets are either original to this project or
licensed for such use. See CREDITS for details.
```

> 日文／印尼文版本已經寫好在 `SpikeConfig.DISCLAIMER_TEXT_BY_LANG`（遊戲內工作人員名單頁
> 隨語言選項即時切換），需要的話逐字抄，不要重寫。

### 遊戲簡介

```
《RAORA'S BASEMENT》是一款免費的 hololive 粉絲向 2D 爬井小品。

你要做的事很單純：一路往上爬，撐到終點。井裡有巡邏怪、定點射手、沿路追人的怪物，還有
一般／移動／易碎／彈射板等各種平台等你判斷。爬到一定高度後，Raora 會登場，並隨時間逐漸
解鎖更多干擾手段——從預警式投擲物，到會橫掃井壁的甩尾，再到會把你吸過去的黑洞。她不會
無限升級到不能玩，但你能撐多久、爬多高，完全看你自己。

途中撿到的三選一增益球會讓每一局的策略都不一樣：石化、護盾、鳳梨披薩清場、時間暫停、
金錢彈反擊……用得好可以續命，用不好可能反而害死自己。

沒有戰鬥系統、沒有經營玩法——這是一款純粹考驗反應與判斷的爬升挑戰。
```

> ⚠ 「鳳梨披薩」等增益名稱請上架前跟遊戲內實際文案（`spike_ui.gd`／`BUFF_TABLE`）逐字核對
> 一次，避免文案跟遊戲內顯示的名稱不一致。

### 特色列表

```
◆ 三個關卡（1000m／1500m／2000m）＋ 專屬教學關，通關解鎖下一關
◆ 通關後解鎖「極限模式」（Raora 開局即登場、四種干擾同時運作）與「無盡模式」（不設終點，
  一路爬到摔下去為止）
◆ 三種敵人：定點巡邏怪、會定時開火的定點射手（一般彈／雷射兩種變體）、沿平台追人的怪物
◆ 多種平台機制：一般、水平移動、垂直移動、繞圈、易碎、彈射板、爆炸平台、會騙人的偽裝平台
◆ 八種三選一增益球：隨機、石頭藥水、石化藥水、護盾、鳳梨披薩（清場）、時間藥水（暫停敵人／
  干擾）、金錢彈、隨機轉換——每局開局與半路各選一次，決定這局的打法
◆ Raora 登場後階梯式解鎖四階干擾：預警式投擲物 → 甩尾橫掃 → 黑洞吸引 → 視野縮小（僅最終關）
◆ 蟲洞瞬移，穿越時畫面與判定會整段暫停切換到新地點
◆ 商店永久升級（跳躍高度／燃料上限／鞭子彈藥／彈射板高度），17 項成就
◆ 按鍵可自由重新綁定；免責聲明已支援繁中／英文／日文／印尼文四語切換
```

### 操作說明 / 支援的輸入裝置

```
預設鍵盤操作（可在遊戲內「設定」頁面自由重新綁定）：
  左移 A ／ 右移 D ／ 鞭子瞄準 E ／ 噴射（長按）Space ／ 二段跳（懷錶解鎖後）W ／
  使用道具 F ／ 暫停 Esc

目前僅支援鍵盤操作，尚未支援手把（gamepad）。滑鼠拖曳為保留中的備用輸入模式，
預設關閉，可在設定頁開啟。
```

### 系統需求（下載版）／建議瀏覽器（網頁版）

```
【網頁版】
建議使用近期版本的 Chrome、Edge 或 Firefox（桌面版）以獲得最佳體驗。
首次載入約需下載 22 MB（伺服器端會自動壓縮，實際數字以上架時最新匯出為準）。
手機瀏覽器與觸控操作尚未支援。

【Windows 下載版】
作業系統：Windows 10 / 11（64 位元）
顯示卡：需支援 Vulkan 1.0（近十年內多數獨立顯卡與內顯皆支援）
硬碟空間：約 50 MB 可用空間（以上架時最新匯出的實際大小為準）
免安裝，解壓縮後直接執行；未購買代碼簽署憑證，Windows SmartScreen 跳出警告是正常現象，
非病毒警示。
僅提供 Windows 版本，暫不支援 macOS／Linux（未有對應機器可實測）。
```

### 實況與影片政策

```
歡迎自由實況、錄影、剪輯本作內容並公開發布，唯不得用於商業營利用途（例如置入付費廣告、
販售內容），並請遵守 hololive production 的「二次創作指南」與「二次創作遊戲指南」
（https://hololivepro.com/terms/）。
```

### Credits

```
製作：paperstorming
— 遊戲引擎：Godot
— 美術／遊戲設計／程式：paperstorming

音樂：
— 井內背景音樂：《天堂與地獄》序曲康康舞曲段落，Jacques Offenbach 作曲、Musopen 錄製
  （公有領域）
— 干擾期背景音樂：《安魂曲》K.626 第 3 曲 Dies Irae，Wolfgang Amadeus Mozart 作曲（CC0）
— 主頁面背景音樂：偶像直播片段截取

音效：主要取自 pixabay.com（CC0 授權），部分截自直播片段

字型：Noto Sans CJK TC（SIL Open Font License 1.1）
引擎：Godot Engine（MIT License）

完整第三方素材授權清單見專案內 THIRD_PARTY_LICENSES.md。

致敬：本作為非官方粉絲遊戲，向以下 hololive 官方頻道致敬——
Kaela：https://youtube.com/channel/UCfrWoRGlawPQDQxxeIDRP0Q
Raora：https://youtube.com/@holoen_raorapanthera
Bijou：https://youtube.com/@KosekiBijou

特別感謝（啟蒙、部分素材參考）：
https://youtube.com/@painguinman
https://youtube.com/@HandMrH
https://x.com/keenbiscuit
```

> 這段直接濃縮自 `CREDITS.md`（SSOT），上架前若 `CREDITS.md` 有更新記得回來同步這裡，
> 不要各自維護出兩份不一致的名單。

### 已知問題

> 2026-08-19 使用者拍板：誠實揭露還在調整中的內容，展現 in-development 透明度。

```
本作仍在開發中（release status: in development），以下是目前已知、還在處理的項目：

◆ 介面在地化尚未全面完成：目前僅「免責聲明」支援繁中／英文／日文／印尼文四語切換，
  其餘遊戲內文字（選單、商店、成就說明等）暫時只有繁體中文，其他語言版本規劃中。
◆ 少數情況下（機率抓約每四局一次），系統隨機生成的井可能出現特別刁鑽、要求精準操作的
  跳台區間，屬於已知的生成演算法邊界案例，持續調整規則中。
◆ 目前僅支援鍵盤操作，尚無手把支援。
◆ 教學關與部分關卡內容仍持續依玩家回饋微調，平衡數值可能隨版本更新調整。
◆ 僅提供 Windows 下載版與網頁版，暫無 macOS／Linux／手機版本。
```

### 更新方式

```
【網頁版】直接重新整理頁面即可玩到最新版本，itch.io 會自動提供最新上傳的版本。
存檔存在瀏覽器的 IndexedDB，清除瀏覽器資料或使用無痕模式會導致進度消失，長期遊玩
建議改用下載版。

【下載版】下載新版 zip、解壓縮到新資料夾覆蓋（或直接取代）舊版即可，新舊版本互不影響。
存檔獨立存放在 Windows 使用者資料夾（%APPDATA%\Godot\app_userdata\RAORA'S BASEMENT\），
與遊戲安裝位置無關，刪除或更新遊戲本體都不會動到進度；更新前仍建議先備份整個資料夾。
```

### 聯絡方式

```
Email：paperstormingowo@gmail.com
X (Twitter)：@paperstorming99 （https://x.com/paperstorming99）
YouTube：https://youtube.com/@paperstormingowo
itch.io：https://paperstormingowo.itch.io/
```

### 語言支援說明

```
目前介面語言：繁體中文（預設）。
免責聲明已支援繁中／英文／日文／印尼文四語即時切換（設定頁「語言」分頁）。
其餘介面文字全面在地化規劃中，尚未上線，見上方「已知問題」。
不會自動偵測系統語言，需自行在設定頁切換。
```

### 排行榜的資料告知

```
本版（v1.0）不提供線上排行榜，僅記錄本機最高紀錄。線上排行榜規劃在後續版本推出。
```

---

## 待你確認／填入的項目（本檔沒有替你決定的部分）

- [ ] Short description 最終文字（使用者預告會自己補調整，這版是起點不是定案）
- [ ] Project URL slug 是否要改（目前建議 `raoras-basement`，需上架時實測是否已被佔用）
- [ ] Genre／Tags／Accessibility／Average session length（`store/metadata.md` 待補，不是本檔職責）
- [ ] 「鳳梨披薩」等增益球名稱、成就名稱等細節文案，建議上架前跟 `spike_ui.gd` 實際顯示文字逐字核對一次，避免不一致
- [ ] 英／日／印尼文三語頁面（`description_en.md`／`_ja.md`／`_id.md`）——本次刻意只寫繁中主稿，正式上架前至少應補英文版
