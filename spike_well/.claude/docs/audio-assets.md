# 音效資產現況（首批，08-17）

硬規則：素材本體放 `assets/audio/`；路徑常數住實際 `load()` 它的檔案
（`well_world.gd`，同貼圖 `TAIL_TEX_PATHS` 既有慣例——config 只管可調數值不管資源路徑）；
音量常數住 `autoload/spike_config.gd` SECTION 12。新增／替換音效照這裡的模式走，
SOP 見 skill `/import-sound-asset`。

## 索引

| 素材 | 掛點 | 觸發時機 | 詳情 |
|---|---|---|---|
| `come1/2/3.ogg` | `_play_come_sfx`（well_world.gd） | Raora 登場那一幀（同鏡頭震動觸發點），三選一 | 例外一／例外三（come3 08-18 更新） |
| `jump.ogg` | `_play_landing_sfx` | 一般落地（不是彈射板、沒有石頭藥水時） | 例外一／例外二／例外三（08-18 更新） |
| `biboo_water1~8.ogg` | `_play_stone_scream_sfx` | 落地時持有石頭藥水（不是彈射板），八選一蓋掉 jump，走專屬音效池不共用節點 | 例外一／例外三 |
| `bounce.ogg` | `_play_landing_sfx` | 踩到彈射板（LAUNCHER），蓋掉 jump／石頭尖叫聲 | 例外二 |
| `wormhole.ogg` | `_begin_wormhole_travel` | 碰到蟲洞那一刻，獨立節點 `_sfx_wormhole_player` | 例外二 |
| `doom.ogg` | `_play_doom_sfx` | 黑洞實際材化出現那一幀（不是預警圈亮起） | 例外一／例外三（08-18 接線） |
| `pemaloe2.ogg` | ⚠ 仍未接線 | 08-17 首批來源，一直沒有對應事件——08-18 二批的 Pameloe 音效改用**新提供**的 `laser.ogg`／`shoot.ogg`（見下方），這顆舊檔案繼續留著沒用 | 例外一 |
| `kaela1.ogg` / `kaela2.ogg` | `SpikeAudio._play_random_bgm` | 主頁面家族狀態（開始／商店／成就／設定／名單），延遲 `SpikeConfig.MENU_BGM_START_DELAY_SEC`（08-18 四訂：3 秒 → **1 秒**）才起播、循環、每次隨機挑一首 | 例外四／例外五／例外六 |
| `death_explosion.ogg` | `_play_death_explosion_sfx`（well_world.gd） | 死亡爆炸觸發那一刻（`_die()`），跟畫面爆炸同一個入口 | 例外四 |
| `cancan.ogg` | `SpikeAudio.start_gameplay_bgm` | 井裡（PLAYING）背景音樂，`_start_run()` 開一局時起播，固定同一首、`finished` 訊號驅動循環（不是隨機挑） | 例外五 |
| `dies_irae.ogg` | `SpikeAudio.trigger_interference_bgm` | Raora 登場那一幀（`well_world.gd _tick_cam_shake`，跟 `_play_come_sfx` 同一個一局一次的旗標），淡出 cancan 後接手循環播放到這局結束 | 例外五 |
| `button.ogg` | `SpikeAudio.play_button_sfx` | 幾乎所有按鈕按下那一刻（見例外六的按鈕清單） | 例外六 |
| `check.ogg` | `SpikeAudio.play_check_sfx` | 商店購買成功、成就橫幅每次彈出 | 例外六 |
| `coin.ogg` | `SpikeAudio.play_coin_sfx` | 井裡撿金幣／金幣雨、成就頁領獎 | 例外六 |
| `get.ogg` | `_play_get_sfx`（well_world.gd） | 撿到非金幣物資（燃料／墓碑／卡包）；08-18 七訂起也用於三選一增益球選取（`_select_buff_orb`），共用同一顆音效與播放函式，不是新開一顆 | 例外六／例外七 |
| `clock.ogg` | `_play_raora_warn_clock_sfx` | Raora 登場前剩 `SpikeConfig.RAORA_WARN_CLOCK_LEAD_SEC`（10 秒）那一刻，一局一次 | 例外六 |
| `fall.ogg` | `_play_fall_sfx` | 干擾一：投擲物預警倒數結束、真的從畫面上緣掉下來那一刻 | 例外六 |
| `jetpack.ogg` | `_play_jetpack_sfx` / `_stop_jetpack_sfx` | 點火開始播放（持續音），放開／沒油時淡出（`SFX_JETPACK_FADE_SEC` 0.25 秒）才停止，不是硬切 | 例外六 |
| `throw.ogg` | `_play_throw_sfx` | 鞭子左鍵確定射出方向那一刻（`whip.fire()` 呼叫後） | 例外六 |
| `laser.ogg` | `_play_pameloe_laser_sfx` | Pameloe 雷射變體（`art_variant == 1`，貼圖 pameloe2）開火 | 例外六 |
| `shoot.ogg` | `_play_pameloe_shoot_sfx` | Pameloe 一般子彈變體（`art_variant == 0`，貼圖 pameloe1）開火 | 例外六 |
| `no1~4.ogg` | `_play_break_sfx` | 碎裂平台第一次被踩碎（`FRAGILE`，貼圖 break.png），四選一 | 例外六 |
| `laugh1~4.ogg` | `_play_monster_laugh_sfx` | 玩家擊殺怪物（踩頭／無敵撞飛／鞭中後碰到／鳳梨披薩／金幣槍），四選一；**不含**怪物自己掉出畫面死亡 | 例外六 |

## 全域音量／匯流排（08-18 二訂，見例外四）

設定頁「音樂與音效」滑桿控制的不是個別音效，是兩條音訊匯流排（`SpikeAudio.BUS_MUSIC`／
`BUS_SFX`，程式在 `autoload/spike_audio.gd._ready()` 建立，不落在任何 `.tres` 資源檔）。
`assets/audio/` 底下所有既有 SFX 節點（come／jump／biboo_water／bounce／wormhole／doom／
死亡爆炸）建立時都指到 `BUS_SFX`；背景音樂播放器指到 `BUS_MUSIC`。使用者「現在調到多少」
住 `SpikeSave`（`bgm_volume`／`sfx_volume`／`bgm_muted`／`sfx_muted`，比照 `ledge_enabled`
那組「這是設定不是進度」的慣例，`wipe()` 不洗）。**新增音效節點時記得把 `.bus` 指到
`SpikeAudio.BUS_SFX`，否則那顆節點不會受設定頁滑桿控制**（預設值是 "Master"）。

## 例外一：首批音效（08-17）

來源：使用者提供 `Downloads/sound/`（`come1~3.m4a`／`doom.m4a`／`pemaloe2.flac`／
`sheep.wav`／`scream/1~7.mp4`）。`scream/` 底下原始檔部分誤存成 mp4（純音訊容器），
跟其他來源檔一律用 ffmpeg 轉成統一格式 `.ogg`（libvorbis, `-q:a 5`）再匯入，
指令與分桶判斷紀錄見 skill `/import-sound-asset`。

⚠ `jump.ogg` 來源是 `sheep.wav`——來源資料夾裡唯一沒被「come／scream」明確歸類走的
檔案，用「剩下那個就是它」的排除法對應。如果這個對應猜錯，音效檔本身沒問題，
只要在 `well_world.gd` 把 `SFX_JUMP_PATH` 指到別的來源即可，不必重新跑轉檔。

⚠ `doom.ogg`／`pemaloe2.ogg` 已轉檔匯入，但這次沒有對應的觸發點需求，先留著沒接線——
之後要接黑洞／Pameloe 音效時直接 `load()` 用，不必重新跑一次轉檔流程。

音量初值（`spike_config.gd` SECTION 12：`SFX_COME_VOLUME_DB` / `SFX_JUMP_VOLUME_DB` /
`SFX_STONE_SCREAM_VOLUME_DB`）沒有真人試玩調過，覺得吵／太小聲是第一件事去改那裡。

## 例外二：修正 jump／新增 bounce・wormhole（08-17 同日二訂）

使用者當面訂正例外一的猜測性對應：`jump.ogg`（落地聲）來源其實就是同名的
`Downloads/sound/jump.ogg`，不是 `sheep.wav`；`sheep.wav` 實際用途是**蟲洞**音效。
已重新轉檔覆蓋 `assets/audio/jump.ogg`（來源換成真正的 jump.ogg），`sheep.wav` 轉去
新檔 `assets/audio/wormhole.ogg`。另外新增 `bounce.wav`（使用者提供）轉出
`assets/audio/bounce.ogg`，接彈射板（LAUNCHER 平台）落地。

- `SFX_BOUNCE_PATH`／`SFX_WORMHOLE_PATH` 常數與 `_sfx_bounce_stream`／`_sfx_wormhole_stream`
  住 `well_world.gd`，同既有路徑常數慣例。
- bounce 共用 `_sfx_landing_player`（跟 jump／石頭尖叫聲同一個落地事件，互斥不疊播，
  優先權最高——`_play_landing_sfx(is_launcher)` 第一個分支）；wormhole 另開
  `_sfx_wormhole_player` 節點（碰蟲洞是獨立事件，不跟落地互斥）。
- 音量常數 `SFX_BOUNCE_VOLUME_DB` / `SFX_WORMHOLE_VOLUME_DB`（`spike_config.gd`
  SECTION 12）都是初值 -6.0dB，沒有真人試玩調過。

## 例外三：biboo_water 音效池、來源更新、doom 接線（08-18）

**biboo_water8.ogg 新增**：使用者提供 `Downloads/8.m4a`，ffmpeg 轉檔加入 `SFX_STONE_SCREAM_PATHS`
第 8 項，七選一變八選一。

**biboo_water 連續落地互相截斷的修正**：原本 biboo_water／jump／bounce 三種落地聲共用單一
`_sfx_landing_player`，重複 `play()` 會直接截斷上一次播放——對 jump／bounce 這種同一幀只會
觸發一次的短促踩踏聲沒問題，但持有石頭藥水時連續踩到兩個落地點（間距可能短於單顆尖叫聲的
播放長度），後一次會把前一次攔腰截斷。改法：biboo_water 獨立出 `_sfx_stone_players`
小池（`SpikeConfig.SFX_STONE_POOL_SIZE`＝3 顆 `AudioStreamPlayer`），`_play_stone_scream_sfx()`
round-robin 輪流挑池裡下一顆播放，兩次落地只要沒撞上同一顆節點就能重疊不截斷。**不**判斷
該顆節點是否正在播放中找空位——round-robin 已經把撞上同一顆的機率壓到池大小分之一，額外判斷
`playing` 狀態的複雜度沒有對應的效益，極端情況撞上同一顆也只是退化成舊行為（截斷），不會更糟。
bounce／jump 維持共用 `_sfx_landing_player` 不變（互斥本來就是刻意設計，彈射板／一般踩踏這兩種
不會連續密集觸發到需要疊播）。

**come3.ogg／jump.ogg 來源更新**：使用者提供新版 `Downloads/come3.m4a`／`Downloads/jump.m4a`，
ffmpeg 重新轉檔**覆蓋**同名 `.ogg`，觸發點與音量常數都不變，純換音效內容。

**doom.ogg 正式接線**：08-17 首批已轉檔匯入但沒接線（來源 `Downloads/sound/doom.m4a`，這次沒有
重新轉檔，同一份素材直接拿來用）。觸發點是黑洞**實際材化出現**那一幀，不是紫色預警圈亮起那一刻
——`well_world._process` 在呼叫 `interference.update()`／`tutorial_step()` 前後比對
`interference.dooms.size()` 有沒有變長（兩者的黑洞材化唯一出口都是 `interference.gd` 的
`_step_doom_warns`，一次比對同時覆蓋一般時間驅動與教學關強制觸發兩條路徑，不必分別接線）。
獨立節點 `_sfx_doom_player`，理由同 wormhole——一局可能觸發好幾次，不能被落地／come 攔腰截斷。
新常數 `SFX_DOOM_VOLUME_DB`＝-6.0dB，沒有真人試玩調過。

## 例外四：主頁背景音樂系統首次建立 ＋ 死亡爆炸放大加速 ＋ 全域音量匯流排（08-18 二訂）

**背景音樂（新系統）**：使用者提供 `Downloads/sound/kaela1.mp3`／`kaela2.MP3`，ffmpeg 轉
`.ogg`（`-q:a 6`，比 SFX 的 `-q:a 5` 高一點——音樂比短促 SFX 更聽得出壓縮痕跡）。播放邏輯
獨立成新 autoload `autoload/spike_audio.gd`（`SpikeAudio`），不是 well_world.gd 那套既有音效
系統的延伸——背景音樂的生命週期跟著「主頁面」這個 UI 狀態走，不是遊戲世界裡的事件，架構上
不該塞進 `WellWorld`。main.gd 的 `_set_state()` 在「標題頁家族」（S_START／S_SHOP／
S_ACHIEVEMENTS／S_SETTINGS／S_CREDITS）進場時呼叫 `SpikeAudio.ensure_menu_bgm()`，其餘
狀態（含 PLAYING／PAUSED／結算頁／劇情頁）呼叫 `stop_menu_bgm()`。**不是**同一首設
`loop=true`——`bgm_player.finished` 訊號接回 `_play_random_bgm()`，每首播完都重新隨機挑一首
（兩首都全有才播，任一首缺席整組清空、`ensure_menu_bgm()` 直接 no-op，同其他音效批次「全有
或全無」的既有慣例）。

**死亡爆炸放大 1.5 倍 ＋ 加速 1.5 倍**：`SpikeConfig.DEATH_EXPLOSION_ART_SIZE` 240×240 →
360×360；`DEATH_FX_DURATION` 2.0s → 2.0/1.5s（改這一個常數就夠，`DEATH_EXPLOSION_FRAME_
INTERVAL` 與碎片 `life` 都是從它算出來的，會自動跟著變快，不用另外改）。

**死亡爆炸音效**：來源 `Downloads/explosion (1).mp4`（跟上個 session 切幀去綠幕用的同一份
素材），這次用 ffmpeg `-vn` 直接擷取音軌，**沒有**額外調速去對齊畫面加速後的新時長——保留
素材原始的爆炸節奏（時間拉伸太多倍聲音會失真），跟畫面各自獨立處理。播放節點 `_sfx_death_
player`，觸發點 `_die()`（跟畫面爆炸同一個入口）。缺檔直接沒聲音，不影響畫面那邊獨立的
「缺檔退向量特效」判斷。

**全域音量匯流排**：新增 `SpikeAudio.BUS_MUSIC`／`BUS_SFX` 兩條匯流排，設定頁「音樂與音效」
滑桿（兩條 ＋ 兩顆靜音鈕）就是控制這兩條匯流排，不是逐一改各音效的 `volume_db`。**這次同時
把 well_world.gd 既有全部 SFX 節點（come／landing／wormhole／doom／death／stone pool）
的 `.bus` 指到 `BUS_SFX`**，否則舊音效不會受新滑桿影響。細節與「新增音效節點記得接 bus」
的提醒見上方「全域音量／匯流排」那節。

## 例外五：井內背景音樂（cancan/dies_irae）＋ 主頁 BGM 延遲起播 ＋ 設定頁分頁化（08-18 三訂）

**井裡背景音樂（新系統）**：使用者提供 `Downloads/sound/Cancan.mp3`／`DiesIrae.mp3`，ffmpeg
轉 `.ogg`（`-q:a 6`，同 kaela 那組音樂等級，不是 SFX 的 `-q:a 5`）。跟主頁 kaela 系統各自
獨立（各自的路徑常數／player／loop 邏輯都在 `autoload/spike_audio.gd`，互不共用節點）：
- 固定 Cancan 起播（不是多選一隨機挑）：`main.gd _start_run()` 呼叫 `SpikeAudio.
  start_gameplay_bgm()`——刻意不放在 `_set_state(S_PLAYING)` 分支，因為 `_resume()` 也會
  進那個分支，暫停恢復不該把已經切到 DiesIrae 的音樂重置回 Cancan。
- Raora 登場那一幀（`well_world.gd _tick_cam_shake`，跟 `_play_come_sfx` 同一個
  `_raora_shake_done` 一局一次旗標）呼叫 `SpikeAudio.trigger_interference_bgm()`：
  用 `Tween` 把 `volume_db` 淡到 -80dB（`SpikeConfig.GAMEPLAY_BGM_FADE_SEC`＝1 秒），
  完成後切 stream 到 DiesIrae 並重置音量，之後靠 `finished` 訊號重播同一首（循環）。
- 離開 PLAYING（不含 PAUSED——暫停時音樂繼續播）呼叫 `SpikeAudio.stop_gameplay_bgm()`，
  連同淡出用的 tween 一起 `kill()`，防止死亡瞬間撞上 Raora 登場淡出，tween 排的
  callback 在結算頁畫面上把音樂重新播起來。
- 缺檔各自獨立退（不是「全有或全無」）：Cancan 缺就整段沒有井內 BGM；DiesIrae 缺就
  Raora 登場後 Cancan 繼續循環，沒有觸發點可退——這跟 kaela 那組「兩首都全有才播」不同，
  因為 Cancan／DiesIrae 不是互相替代的多選一，是固定的「預設→干擾登場」兩階段。

**主頁 kaela BGM 延遲 3 秒起播**：回到主頁面家族狀態不再立即撥放，改成
`SpikeAudio.ensure_menu_bgm()` 排一顆 `SpikeConfig.MENU_BGM_START_DELAY_SEC`（3.0 秒）的
`Timer`，時間到才呼叫 `_play_random_bgm()`；`stop_menu_bgm()` 會連同這顆計時器一起停掉，
離開主頁面家族時等待中的起播就會被取消。已經在等（`is_stopped()` 為 false）就不重排，
切分頁不會把 3 秒重新算過。

**設定頁分頁化（08-18 三訂建立，08-18 四訂修正殼位置一致性）**：`spike_ui.gd
_build_settings_panel` 從單頁改成四個內容分頁（控制／音量／名稱設定／工作人員名單），
常駐掛著、切 `visible` 不重建節點。音量分頁兩組滑桿從同一橫排改直排，各自上方加一行
劃線小字（"kaela的可愛度"／"kaela的作業完成度"）。**名稱設定分頁使用者確認先佔位不放
內容**（`SpikeConfig.NAME_SETTINGS_PLACEHOLDER`），之後真的要做玩家改名功能再補。

⚠ **四訂修正**：三訂第一版「工作人員名單」還是導去獨立頁面（`S_CREDITS` 狀態＋
`_build_credits_panel`），使用者實測回報這樣切到名單頁時標題／分頁鈕列／底部按鈕整層殼
會消失，違反 CLAUDE.md 硬規則 8（同一頁面的殼不該因為內容或子分類而跳動／消失）。
四訂把工作人員名單也收進來變成第四個分頁（`_build_credits_tab`），`S_CREDITS`／
`_credits_panel`／`credits_pressed`／`credits_back_pressed`／`_to_credits()` 這條獨立頁面
的路徑整組退役刪除，不留死碼。同時四個分頁的 `custom_minimum_size.y` 都釘死在
`SETTINGS_CONTENT_HEIGHT`（420px，抓最高的控制分頁）：矮的分頁下面留白，不再讓外層
`VBoxContainer` 隨內容自適應高度——這正是「殼跳動」的根因，不是四個分頁各自的內容問題。
**存檔碼區塊使用者要求先隱藏**：`_build_control_tab()` 不再呼叫 `_build_save_code_block()`，
函式本體與 `_save_code_edit`／`_save_code_msg` 都還在（`_reset_save_code_ui()` 已有 null
檢查擋著），之後要恢復顯示只要把那行加回來。

⚠⚠ **劃線小字不是用 RichTextLabel 的 `[s]` BBCode**：那是 Godot 內建支援的標籤（
`get_parsed_text()` 也證實標籤有被吃掉），但實測掛自訂子集字型（`NotoSansCJKtc.otf`）
完全不畫線——子集流程沒保留 OS/2 `yStrikeoutPosition`/`Size` 這類 metrics，換回引擎預設
字型才畫得出來（截圖比對過）。改成 `SpikeUI._make_strike_label`：用 `_make_label` 畫文字，
`font.get_string_size()`／`get_height()` 量出字串寬高後疊一條 `ColorRect` 當刪除線，
不依賴任何字型的刪除線 metrics。⚠ 疊線用的外層 `Control` 一定要設
`size_flags_horizontal = SIZE_SHRINK_BEGIN`——它外面是 `VBoxContainer`，預設 `SIZE_FILL`
會被撐到跟同一欄下面那條滑桿列一樣寬，用絕對座標畫的線會卡在左邊、文字卻被置中對齊推到
撐開後的視覺中央，兩者對不上（踩過一次的坑，見 `STRIKE_LINE_Y_RATIO`/`_THICKNESS` 常數
旁的註解）。

## 例外六：第二批音效（button/check/coin/get/clock/fall/jetpack/throw/laser/shoot/no/laugh）
＋ 主頁 BGM 延遲改 1 秒 ＋ Raora 登場紅色邊框（08-18 五訂）

**來源與轉檔**：使用者提供 `Downloads/sound/`（單檔：button/check/clock/coin/fall/get/
jetpack/laser/shoot/throw；資料夾：`no/1~4.MP3`、`laugh/1~4.MP3`），ffmpeg 轉
`.ogg`（libvorbis `-q:a 5`，同既有 SFX 慣例）落地 `assets/audio/`。`no/`／`laugh/`
各自四選一，連號命名 `no1~4.ogg`／`laugh1~4.ogg`。

**架構決定：button/check/coin 三顆改住 `autoload/spike_audio.gd`，不是 well_world.gd**。
理由：`coin` 同時要被井裡撿金幣（well_world.gd）與成就頁領獎（spike_ui.gd）兩處觸發，
`button`／`check` 純粹是 UI 層事件（spike_ui.gd 的按鈕／商店／成就橫幅），only WellWorld
看得到的既有音效系統覆蓋不到 UI 層。三顆各自獨立缺檔判斷（不是全有或全無），播放函式
`SpikeAudio.play_button_sfx()` / `play_check_sfx()` / `play_coin_sfx()`。其餘 9 顆
（get/clock/fall/jetpack/throw/laser/shoot/no/laugh）是純遊戲世界事件，沿用既有慣例
住 well_world.gd（各自獨立 `AudioStreamPlayer` 節點、掛 `SpikeAudio.BUS_SFX`）。

**button 的接法**：不是逐一去每個按鈕的 `pressed.connect` 加一行，而是找到 spike_ui.gd
既有的按鈕工廠共用掛點：`_make_button()`（涵蓋絕大多數文字按鈕，且 `_make_dev_button()`
內部就是呼叫它，開發者鈕跟著免費覆蓋）、`_make_toggle_icon()`（極限／無盡／攀爬手套／
懷錶四顆開關 icon）、`_make_pause_button()`（右上角暫停鈕）、`_build_level_row()` 的選關
按鈕（唯一沒有共用工廠、直接 `Button.new()` 的一般按鈕）。商店卡片／成就卡片是唯二「點下去
會另外觸發 check／coin」的按鈕，額外接一條 `pressed.connect(SpikeAudio.play_button_sfx)`——
**按鈕點擊音跟購買完成／領獎音是疊加關係，不是互斥替換**：按下去先響 click，動作成功再響
check/coin，同大多數遊戲「操作回饋＋結果回饋」分層的慣例。

**check 的兩個掛點**：`_on_buy(key)` 在 `SpikeSave.buy(key)` 回 true 時播；成就橫幅
`_advance_banner()` 在每次真的把新橫幅設成 visible 時播（不是 `queue_achievement_banners`
入列那一刻）——多個成就同時解鎖、橫幅逐一排隊彈出時，每一次彈出都響一次，不是只響一次。

**coin 的兩個掛點**：井裡 `_check_pickups()` 的一般 COIN 分支與金幣雨（`_rain_coins`）分支
（well_world.gd 呼叫 `SpikeAudio.play_coin_sfx()`）；成就頁 `_on_claim(id)` 在
`SpikeSave.claim_achievement(id)` 回 true 時播（spike_ui.gd）。⚠ FUEL／TOMB／LOOT_BAG
三種非金幣物資走 `get` 不是 `coin`——即使 TOMB 撿到會併入 `coin_count`，判斷依據是**物資
種類**不是「有沒有進帳」。

**laser／shoot 對照表更新**：這批之前（例外一）轉檔匯入過 `pemaloe2.ogg` 但一直沒接線。
這次使用者明確指定「laser 對應 pemaloe2、shoot 對應 pemaloe1」，直接用**新提供**的
`laser.ogg`／`shoot.ogg` 接上 `_fire_pameloe_shots()` 的兩個分支（`art_variant == 1` 雷射／
`art_variant == 0` 子彈），舊的 `pemaloe2.ogg` 繼續閒置沒有動它。

**laugh 排除怪物自己死亡**：`_kill_monster(m, refund, laugh_sfx)` 新增第三個參數，預設
`true`；唯一傳 `false` 的呼叫端是 `_check_pebbles_falls()`（Pebbles 自己掉出畫面下緣死亡，
規格明講「死亡算玩家擊殺」只是為了共用擊殺計數／死亡演出，不是玩家真的動手）——這是目前
唯一找到的「非玩家造成」死亡路徑，其餘 5 個 `_kill_monster` 呼叫端（暈眩怪碰觸／無敵撞飛／
踩頭／鳳梨披薩／金幣槍）全部保留 laugh 音效。

**jetpack 是持續音**：點火（`_step_jetpack` 的 `not was_on` 分支）呼叫 `_play_jetpack_sfx()`
開始播放，放開或沒油時（`not player.jetpack_on` 且 `was_on` 為真）呼叫 `_stop_jetpack_sfx()`
用 `Tween` 淡到 -80dB（`SpikeConfig.SFX_JETPACK_FADE_SEC` 0.25 秒）才真的 `stop()`，不是
按放開鍵那一幀硬切——使用者規格明講「使用完則淡出」。

**clock 只在時間驅動的倒數有意義**：新增 `_raora_warn_clock_fired` 一局一次鎖，`_process()`
在 `elapsed += delta` 之後比對 `SpikeConfig.eff_interference_start() - elapsed` 是否落在
`(0, RAORA_WARN_CLOCK_LEAD_SEC]`（10 秒）區間觸發。教學關（干擾改高度事件表觸發，倒數
天生無意義）與極限模式（`eff_interference_start()` 從第一幀就是 0，沒有「登場前」這個
階段）都會自然跳過，不必額外分支判斷。

**fall 沿用黑洞音效的偵測手法**：`interference.projectiles.size()` 在呼叫
`interference.update()` / `tutorial_step()` 前後比對，變長就播——跟既有 `_play_doom_sfx()`
偵測 `dooms.size()` 同一招，一次覆蓋一般時間驅動與教學關強制觸發兩條路徑，不必分別接線。

**get.ogg 開頭有約 0.6 秒無聲區**：silencedetect 量測其餘 11 顆單檔／8 顆四選一素材開頭
都是即時發聲，唯獨 `get.ogg` 前面有一段明顯靜音（採到非金幣物資的音效延遲響）。**沒有
自行裁切**——照 SOP 留給使用者自行決定要不要修剪，若要縮短開頭靜音，改的是
`assets/audio/get.ogg` 這個檔案本體，程式端的路徑／播放邏輯不用動。

**主頁 BGM 延遲 3 秒 → 1 秒**：`SpikeConfig.MENU_BGM_START_DELAY_SEC` 改常數值，播放邏輯
（`SpikeAudio.ensure_menu_bgm()` 排 `_menu_bgm_start_timer`）完全沒動，純數值調整。

**Raora 登場紅色邊框（視覺效果，非音效，同一批一起做）**：`well_world.gd _draw_raora_border`
畫在 `_draw()` 最後（玩家之後，蓋在任何東西上面），觸發依據 `interference.active()`（整段
「已登場」時間持續顯示，不是只在登場那一幀閃一下）。做法：四邊各自一張 64×64 線性
`GradientTexture2D`（`SpikeConfig.C_DANGER_RED`，邊緣 alpha `RAORA_BORDER_MAX_ALPHA`
0.35 → 內緣全透明），寬度 `RAORA_BORDER_WIDTH` 160px，只建一次快取到
`_raora_border_top/bottom/left/right_tex`。⚠ 四邊各自建一張獨立貼圖，**沒有**共用一張再靠
`draw_texture_rect` 負尺寸翻轉——那個翻轉行為查不到明確保證，寧可多建三張小貼圖（成本可
忽略）。用 `record.tscn --stress` 錄影＋像素採樣驗證過四邊都正確漸層（見下方驗證段落），
headless 看不出畫面，這段是唯一動用到動態錄影驗證的部分。

**驗證**：`smoke.tscn` 全套跑過，`headless --import` 0 error。全套唯一的失敗項「卡包／
金幣雨：雨滴碰到才入帳」**是這次改動之前就存在的既有失敗**（比對 `tools/out/
smoke_final_full.txt` 這份更早的全套紀錄，同一項在那次也是失敗），跟這批音效／視覺改動
無關，沒有動手修——不在這次任務範圍內，需要的話另開任務處理。紅色邊框額外用
`record.tscn --stress --secs=12` 錄一段（Raora 提前到第 1 秒登場），採樣邊緣與內緣像素
RGB 確認四邊都有正確的「邊緣深、往內漸淡」效果。

## 例外七：get.ogg 換源、buff 三選一補音效、全域音量統一、jetpack 音效卡音三處修正（08-18 六訂）

**get.ogg 換源**：使用者提供新版 `Downloads/sound/get.m4a`，ffmpeg 重新轉檔覆蓋
`assets/audio/get.ogg`（同例外三 come3／jump 換源的既有模式，觸發點與掛點都不變，純換
內容）。順帶解掉例外六記錄的「get.ogg 開頭有約 0.6 秒無聲區」——新素材本身時長僅
0.92 秒且開頭即發聲（`silencedetect` 量測沒有前導靜音），不需要額外裁切。

**buff 三選一（開局／1000m）補音效**：`_select_buff_orb()`（well_world.gd）選中一顆後緊接
呼叫既有的 `_play_get_sfx()`——沒有另外開一顆音效或常數，直接沿用「取得非金幣物資」那顆，
理由：buff 也是一種「拿到東西」的回饋，跟燃料／墓碑／卡包同一類事件，沒有必要為了同一種
使用者感受另外做一套素材與播放邏輯。使用者原話只講「套用 get.m4a」，沒有要求獨立音效，
照字面對應。

**全域音量統一（回應使用者「音效間音量差距有些大，例如 clock」）**：用 ffmpeg
`volumedetect` 量測 `assets/audio/` 底下每顆 SFX（排除 BGM 四首：cancan／dies_irae／
kaela1／kaela2，那組走獨立的音樂匯流排音量，不在這次比較範圍）的 `mean_volume`，發現
沒有刻意分層設計意圖的那批（`spike_config.gd` SECTION 12 裡原本全部沿用同一個 -6.0dB
初值的常數）源檔本身響度差異極大——`mean_volume` 從 shoot.ogg 的 -9.8dB 到 clock.ogg 的
-43.2dB 都有，套上同一個 -6.0dB 增益之後聽感完全不統一：clock 幾乎聽不見、shoot 幾乎貼著
削波（`max_volume` 已經到 -0.0dB 邊緣）。

修法：反推讓「素材 `mean_volume` ＋ `volume_db`」都落在同一個目標有效音量（取這批素材
`mean_volume` 平均值 -22.57dB，加上原本平均增益 -6.0dB，目標抓 -28.5dB）附近，逐顆分別
調整常數，而不是繼續統一套同一個 dB 值：

| 常數 | 舊值 | 新值 | 素材 mean_volume | 備註 |
|---|---|---|---|---|
| `SFX_STONE_SCREAM_VOLUME_DB` | -6.0 | -7.0 | 池平均 -21.5 | 小幅調整 |
| `SFX_BOUNCE_VOLUME_DB` | -6.0 | -7.5 | -20.9 | 小幅調整 |
| `SFX_WORMHOLE_VOLUME_DB` | -6.0 | -12.5 | -15.9 | 原本偏大聲 |
| `SFX_DOOM_VOLUME_DB` | -6.0 | -13.0 | -15.7 | 原本偏大聲 |
| `SFX_CHECK_VOLUME_DB` | -6.0 | 0.0 | -28.8 | 原本偏小聲 |
| `SFX_COIN_VOLUME_DB` | -6.0 | -2.5 | -26.0 | 原本偏小聲 |
| `SFX_GET_VOLUME_DB` | -6.0 | -0.5 | -27.8（換源後重測） | 原本偏小聲 |
| `SFX_CLOCK_VOLUME_DB` | -6.0 | **+14.5** | -43.2 | 原本嚴重偏小聲，即使 +14.5dB 增益後 `max_volume` 仍在 -1.0dB 左右，沒有削波風險 |
| `SFX_FALL_VOLUME_DB` | -6.0 | -9.0 | -19.3 | 小幅調整 |
| `SFX_JETPACK_VOLUME_DB` | -6.0 | -9.5 | -19.1 | 小幅調整 |
| `SFX_THROW_VOLUME_DB` | -6.0 | -7.5 | -20.9 | 小幅調整 |
| `SFX_LASER_VOLUME_DB` | -6.0 | -9.5 | -18.9 | 小幅調整 |
| `SFX_SHOOT_VOLUME_DB` | -6.0 | **-18.5** | -9.8 | 原本嚴重偏大聲，`max_volume` 原本已貼近 0dB，調降沒有新的削波風險 |
| `SFX_BREAK_VOLUME_DB` | -6.0 | -3.0 | 四選一平均 -25.6 | 小幅調整 |
| `SFX_MONSTER_LAUGH_VOLUME_DB` | -6.0 | -5.5 | 四選一平均 -23.2 | 小幅調整 |

⚠ **刻意沒有動**：`SFX_COME_VOLUME_DB`（-3.0）／`SFX_JUMP_VOLUME_DB`（-9.0）／
`SFX_BUTTON_VOLUME_DB`（-12.0）／`SFX_DEATH_EXPLOSION_VOLUME_DB`（-3.0）這四顆——各自
原本就有明確的刻意分層理由（come／death 戲劇性給足、jump／button 頻繁觸發要壓低避免疲勞），
不是這次「沒有設計意圖、純粹統一」的目標對象。備註：`come1~3.ogg` 量測 `mean_volume` 平均
只有 -24.7dB（比多數素材都小聲），現有 -3.0dB 增益套上去換算有效音量約 -27.7dB，實際上
不會比一般音效顯著突出——如果真人試玩覺得「登場音沒有戲劇性」，這是第一件事去查的地方，
但這次沒有主動改，因為使用者沒有點名這顆，改變別人已經拍板的刻意設計需要更明確的訊號。

**jetpack 音效「有時候鬆手還繼續播」的根因與三處修正**：`jetpack.ogg` 本身長 9.56 秒（持續
音素材），正常路徑靠 `_stop_jetpack_sfx()` 淡出（0.25 秒）才 `stop()`；但只有 `_step_jetpack()`
裡「這一幀開始時 `jetpack_on` 就已經是 false」那個分支會呼叫它。找到三處會把
`player.jetpack_on` 直接改成 `false`、但不會經過那個分支的地方，音效就會播到素材自然結束
為止（最長 9.5 秒），不是鬆手就停：

1. **燃料耗盡**（`_step_jetpack()`，well_world.gd）：噴射到一半燃料歸零時，函式在「還在噴」
   的分支裡才把 `jetpack_on` 改成 `false`——那一刻已經過了本函式開頭那個「剛從噴變不噴」的
   判斷，下一幀 `was_on` 又已經是 `false`，兩幀都判斷不出「剛剛才停」。補上直接呼叫
   `_stop_jetpack_sfx()`。
2. **蟲洞過場開始**（`_begin_wormhole_travel()`，well_world.gd）：過場期間 `_step_jetpack()`
   完全不會被呼叫（`_process` 改走 `_step_wormhole_travel` 分支），噴射中撞上蟲洞會被這裡
   直接關掉 `jetpack_on`，同上補呼叫。
3. **新局開局**（`reset()`，well_world.gd）：上一局若死在噴射中，`_dying` 期間
   `_step_jetpack()` 同樣完全不會再跑（死亡演出提前 `return`），`jetpack_on` 停在 `true`
   直到這局結束，音效可能一路響到結算頁甚至下一局開始。`reset()` 裡 `player.reset()` 只會
   把資料歸零，不連帶停音效節點，補上呼叫一次保證新局一定乾淨（`_stop_jetpack_sfx()` 開頭
   已有 `not playing` 的 no-op 判斷，沒在響時呼叫零成本）。

**驗證**：`headless --import` 0 error；`smoke.tscn -- --only=mechanics,buffs` 跑過，增益
稽核（含選取／爆炸）88 項全過，機制稽核唯一失敗項是例外六已記錄過的既有卡包／金幣雨問題
（跟這次改動無關）。三處 jetpack 修正屬於「停止時機」的邏輯修正，headless 只能驗證程式
邏輯有跑到、不會崩潰，播放時機是否確實提早停止建議使用者實際噴射到燃料耗盡／噴射中碰
蟲洞這兩種情境親耳確認。
