---
name: import-sound-asset
description: 要把使用者提供的音效素材接進 spike_well 遊戲時用——新增或替換落地聲、事件 stinger（如 Raora 登場）、buff 專屬音效變體，或一次收到一批格式不一（m4a/flac/wav/mp4 誤存純音訊等）的來源檔要先統一轉檔再匯入。涵蓋開工前分桶（來源檔↔遊戲事件雙向對照）、ffmpeg 統一轉檔、Godot 匯入、路徑常數（掛 load() 端）與音量常數（掛 spike_config.gd）分離、AudioStreamPlayer 節點與觸發點接線、「全有或全無」多選一模式、驗證子集。08-17 首次建立，仿 /import-art-asset 的分桶與登記流程。
argument-hint: "[音效素材來源目錄或檔案路徑]"
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

給下一次「把使用者提供的音效接進遊戲」照著做。完成後把新素材登記進
`spike_well/.claude/docs/audio-assets.md`（唯一的音效資產現況清單）。

0. **開工前先分桶——目的是自己排出對應關係，不是把問題丟回去問使用者。**
   使用者要的是有效率的工作安排，**不是被確認打斷**：分桶結果一行帶過寫在開工那則訊息
   裡，然後直接往下做，不停等回覆（同 `/import-art-asset` 步驟 0 的既有原則）。

   **來源檔 ↔ 遊戲事件雙向對照**：使用者通常用白話描述每種音效「什麼時候要響」
   （例如「倒數結束、干擾登場」「一般踩到平台」），不一定給檔名 1:1 對應好的清單。
   對照時：
   - 先讀懂每個描述背後對應到程式裡的**哪一個既有觸發點**（不要自己發明新的判定
     時機）——先 Grep 相關關鍵字定位（例如「倒數」「登場」找 `_tick_cam_shake` 那類
     一局一次的旗標；「踩到平台」找 `_check_landing`），不要用猜的接錯地方。
   - 來源檔數量多於使用者明確描述的類別時，**剩下沒被歸類的檔案** 是最常見的缺口——
     排除法對應（「這幾類都指定了來源，剩下這個大概率是漏講的那一類」），並在完工
     報告與 `audio-assets.md` 都留一行「這個對應是猜的，猜錯的話怎麼改」，不要停下來問。
   - 明顯屬於「這次沒提到的其他系統」的來源檔（例如檔名對應到還沒做音效的怪物/機制）
     照樣轉檔＋匯入（使用者要求「各檔案」統一格式時是這個意思），但**不要**硬接一個
     不存在的觸發點——留著沒接線，登記進 `audio-assets.md` 註記「保留給未來」。

1. **統一轉檔（ffmpeg）**：來源常常混雜多種容器/編碼（m4a／flac／wav，甚至手滑存成
   mp4 的純音訊檔），使用者要求「先轉成統一格式再匯入」時，一律先轉再落地，不要讓
   `assets/audio/` 底下出現混雜格式。

   ```
   ffmpeg -y -i <來源檔> -c:a libvorbis -q:a 5 assets/audio/<目標檔名>.ogg -loglevel error
   ```

   - 選 `.ogg`（Vorbis）不是 `.wav`：這些都是短音效，壓縮後單檔幾十 KB，對 Web 匯出的
     總包大小友善；Godot 對 ogg 短音效的解碼成本可忽略，不必為了「零延遲」堅持 wav。
     如果之後有音樂／長音軌需求，那類再個案評估 wav/ogg 的取捨，不影響這裡的 SFX 選擇。
   - `-q:a 5` 落在 ~160kbps 上下，短 SFX 這個位元率聽不出壓縮痕跡，不必逐檔調。
   - 多選一的一組音效（例如「三選一」「七選一」）檔名用 `<用途>1.ogg`、`<用途>2.ogg`…
     連號，方便陣列化載入與之後補檔／抽換。
   - mp4 來源（純音訊、沒有視訊軌）ffmpeg 一樣吃得下，`-i` 指到 `.mp4` 正常轉出 `.ogg`，
     不需要額外參數。

2. **檔案落地** `spike_well/assets/audio/`（新目錄，跟 `assets/sprites/`／`assets/fonts/`
   平行）。

3. **Godot 匯入**：跟換字型／新貼圖同一個坑——不重新 import，`ResourceLoader.exists()`
   會是 false。轉完檔案後**一定要跑一次**：

   ```
   Godot..._console.exe --headless --path <spike_well 絕對路徑> --import
   ```

   `.ogg` 的匯入器是 `oggvorbisstr`（`AudioStreamOggVorbis`），預設 `loop=false`，
   短 SFX 不用逐檔調匯入設定。

4. **路徑常數 vs 音量常數——兩種各自的家不一樣**（跟 `/import-art-asset` 步驟 5
   同一條既有慣例，音效延續套用）：
   - **路徑常數**（`SFX_*_PATH(S)`）住**實際 `load()` 它們的那個檔案**（目前是
     `well_world.gd`，同 `TAIL_TEX_PATHS`／`DOOM_TEX_PATHS` 既有慣例）——不進
     `spike_config.gd`，config 只管可調數值，不是資源路徑。
   - **音量常數**（`SFX_*_VOLUME_DB`）才進 `spike_config.gd`（新開一個 SECTION，
     或併入既有音效 SECTION 12）——音量是使用者會想調的數字，走硬規則 1。
   - 多選一的一組音效用陣列常數（`const SFX_COME_PATHS := [...]`），單一音效用單一
     字串常數（`const SFX_JUMP_PATH := "..."`）。

5. **載入——「全有或全無」判斷**：一組多選一音效比照貼圖批次的既有做法（見
   `_load_hazard_textures` 的 `PAMELOE_TEX_PATHS`／`TAIL_TEX_PATHS` 迴圈）：任何一檔
   缺席就把整組陣列清空，播放端遇到空陣列直接 no-op（靜音跳過，音效沒有視覺
   placeholder 可以退——這跟貼圖的「缺檔退純色矩形」不同，缺音效就是沒有聲音，
   不要試圖生一個假音效墊檔）。單一音效用 `ResourceLoader.exists()` 判斷後
   `load()`，同上一樣缺檔就維持 `null`、播放端跳過。

6. **播放節點與觸發點接線**：
   - 每種「獨立、可能跟其他音效同時播放」的用途各開一顆 `AudioStreamPlayer`
     （**不是** `AudioStreamPlayer2D`——這些是遊戲事件回饋，不是世界座標定位音效），
     在 `_ready()` 用 `add_child()` 掛上去（同 `camera = Camera2D.new(); add_child(camera)`
     的既有寫法）。
   - 短促、同一時間只會觸發一次的音效（例如落地聲）可以共用同一顆
     `AudioStreamPlayer`，重複 `play()` 直接截斷上一次播放是可接受的行為；但如果
     兩種音效可能**重疊**（例如一局一次的長 stinger 撞上頻繁觸發的短音效），
     一定要分開節點，不然長音效會被短音效打斷。
   - 多選一：`streams[randi() % streams.size()]`，走**全域** `randi()` 不是生成器的
     seeded rng——這是純表現效果，不該污染「這座井長什麼樣」的亂數序列（同
     `_petrify_takeoff` 用全域 `randf()` 的既有理由）。
   - buff 專屬的音效覆蓋（例如某個 buff 拿到時同一個事件的音效要換掉）用
     `has_buff("<key>")` 判斷，覆蓋掉的原音效邏輯保留在 `else` 分支，不要整段刪掉。
   - 觸發點一律接在**既有的判定/事件函式裡**，不要另外起一顆計時器或旗標去猜
     「這件事發生了沒」——遊戲邏輯已經有明確的一次性觸發點（例如落地判定
     `_check_landing`、一局一次的登場旗標），音效只是在那個既有時機多做一件事。

7. **驗證——先按性質選子集，不是無腦全跑**：
   - **最低限度**：`smoke.tscn` 全套或相關組別（落地聲＝`mechanics`，buff 專屬音效＝
     連 `buffs` 一起跑），確認 headless import 0 error、`AudioStreamPlayer.play()`
     在 dummy audio driver 下不會拋錯導致崩潰。
   - **不需要** `visual_check.tscn` 或 `record.tscn`——這兩層驗的是「畫面長怎樣」，
     聽不出音效對不對；音效正確與否唯一能驗證的方式是使用者在編輯器裡實際玩過聽過，
     這裡先確保「不會崩潰、邏輯有跑到」就是 headless 能做到的全部。
   - 想在完工報告裡佐證「音效真的有被觸發」，可以讀 bot run 的落地/干擾階段輸出
     （`落地 / 踩頭` 次數、`干擾階段觸及` 有沒有到達對應階段）間接佐證觸發路徑有跑，
     不是聽感驗證的替代品。

完成後：把這次的素材對應、任何猜測性決策（檔名↔用途對照猜錯的話怎麼改）記錄進
`spike_well/.claude/docs/audio-assets.md`（音效資產現況唯一的家），不要另開文件。
