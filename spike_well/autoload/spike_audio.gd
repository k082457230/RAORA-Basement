extends Node
## 全域音訊（08-18 首次建立）：兩條匯流排（Music／SFX）＋ 主頁背景音樂播放器。
##
## 匯流排在啟動時純程式建立（同硬規則 3「不手刻 .tscn」的精神延伸到音訊匯流排——
## 不手刻 default_bus_layout.tres，每次啟動重建一次即可，成本可忽略）。SFX 匯流排本身
## 不播放任何東西，是掛鉤——實際音效節點是 well_world.gd 那些既有 AudioStreamPlayer，
## 建立時把 .bus 指到這裡的 BUS_SFX，全域滑桿就靠匯流排音量一次控制全部，不必逐一
## 改每個 _play_*_sfx() 的音量計算。
##
## 使用者「現在調到多少」住 SpikeSave（bgm_volume／sfx_volume／bgm_muted／sfx_muted，
## 同 ledge_enabled 那組「這是設定不是進度」的既有慣例）；這個 autoload 只負責把那個
## 數字轉成匯流排 dB 並套用，以及背景音樂本身「主頁循環、每次隨機挑一首」的播放邏輯。

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

## 主頁背景音樂來源（08-18，使用者提供 kaela1／kaela2）。全有或全無：任一首缺席整組
## 清空，ensure_menu_bgm() 遇到空陣列直接 no-op（同其他音效批次「缺檔靜音退回」的既有慣例，
## 音樂沒有視覺 placeholder 可退，缺就是沒有背景音樂，不試圖生一份假的墊檔）。
const BGM_PATHS := [
	"res://assets/audio/kaela1.ogg",
	"res://assets/audio/kaela2.ogg",
]

## 井裡（PLAYING）背景音樂（08-18 三訂，使用者提供 Cancan／DiesIrae）。跟上面 kaela 那組
## 主頁系統各自獨立：固定 Cancan → Raora 登場淡出切固定 DiesIrae，不是多選一隨機挑，
## 生命週期跟著「正在爬井」這個狀態走，不是主頁 UI 狀態。缺檔各自獨立退（不是全有或全無）：
## Cancan 缺就整段沒有井內 BGM；DiesIrae 缺就 Raora 登場後 Cancan 繼續循環，沒有觸發點可退。
const GAMEPLAY_BGM_PATH := "res://assets/audio/cancan.ogg"
const INTERFERENCE_BGM_PATH := "res://assets/audio/dies_irae.ogg"

## UI 與遊戲共用的一次性音效（08-18 二批）：按鈕點擊、商店購買完成／成就橫幅彈出、取得
## 金幣。放在這個 autoload 而不是 well_world.gd——spike_ui.gd（主頁／商店／成就頁）也要
## 能播，只有 WellWorld 看得到的話 UI 那一半用不到。各自獨立缺檔判斷（不是全有或全無），
## 同其他單一音效常數的既有慣例。
const SFX_BUTTON_PATH := "res://assets/audio/button.ogg"
const SFX_CHECK_PATH := "res://assets/audio/check.ogg"
const SFX_COIN_PATH := "res://assets/audio/coin.ogg"

var bgm_player: AudioStreamPlayer
var _bgm_streams: Array[AudioStream] = []
## 主頁背景音樂延遲起播計時器（08-18 三訂）：回到主頁面家族狀態後等
## SpikeConfig.MENU_BGM_START_DELAY_SEC 秒才真的開始播，不是立即撥放。
var _menu_bgm_start_timer: Timer

var gameplay_bgm_player: AudioStreamPlayer
var _gameplay_bgm_stream: AudioStream = null
var _interference_bgm_stream: AudioStream = null
## 這一局是不是已經切過 DiesIrae——擋重複觸發（呼叫端 well_world.gd 那邊已經有
## _raora_shake_done 擋一次，這裡多一層純防呆，不假設呼叫端只會呼叫一次）。
var _interference_triggered := false
var _bgm_fade_tween: Tween

var _sfx_button_player: AudioStreamPlayer
var _sfx_check_player: AudioStreamPlayer
var _sfx_coin_player: AudioStreamPlayer
var _sfx_button_stream: AudioStream = null
var _sfx_check_stream: AudioStream = null
var _sfx_coin_stream: AudioStream = null


func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = BUS_MUSIC
	add_child(bgm_player)
	bgm_player.finished.connect(_on_bgm_finished)
	_load_bgm_streams()

	_menu_bgm_start_timer = Timer.new()
	_menu_bgm_start_timer.one_shot = true
	add_child(_menu_bgm_start_timer)
	_menu_bgm_start_timer.timeout.connect(_play_random_bgm)

	gameplay_bgm_player = AudioStreamPlayer.new()
	gameplay_bgm_player.bus = BUS_MUSIC
	add_child(gameplay_bgm_player)
	gameplay_bgm_player.finished.connect(_on_gameplay_bgm_finished)
	_load_gameplay_bgm_streams()

	_sfx_button_player = AudioStreamPlayer.new()
	_sfx_button_player.bus = BUS_SFX
	add_child(_sfx_button_player)
	_sfx_check_player = AudioStreamPlayer.new()
	_sfx_check_player.bus = BUS_SFX
	add_child(_sfx_check_player)
	_sfx_coin_player = AudioStreamPlayer.new()
	_sfx_coin_player.bus = BUS_SFX
	add_child(_sfx_coin_player)
	_load_ui_sfx_streams()

	apply_from_save()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _load_bgm_streams() -> void:
	var streams: Array[AudioStream] = []
	for path in BGM_PATHS:
		if not ResourceLoader.exists(path):
			streams.clear()
			break
		streams.append(load(path))
	_bgm_streams = streams


func _load_gameplay_bgm_streams() -> void:
	_gameplay_bgm_stream = load(GAMEPLAY_BGM_PATH) if ResourceLoader.exists(GAMEPLAY_BGM_PATH) else null
	_interference_bgm_stream = \
		load(INTERFERENCE_BGM_PATH) if ResourceLoader.exists(INTERFERENCE_BGM_PATH) else null


func _load_ui_sfx_streams() -> void:
	_sfx_button_stream = load(SFX_BUTTON_PATH) if ResourceLoader.exists(SFX_BUTTON_PATH) else null
	_sfx_check_stream = load(SFX_CHECK_PATH) if ResourceLoader.exists(SFX_CHECK_PATH) else null
	_sfx_coin_stream = load(SFX_COIN_PATH) if ResourceLoader.exists(SFX_COIN_PATH) else null


## 按鈕點擊：spike_ui.gd 各按鈕工廠共用同一個掛點呼叫（_make_button／_make_toggle_icon／
## _make_pause_button／選關列／商店卡／成就卡），見各自呼叫端的註解。
func play_button_sfx() -> void:
	if _sfx_button_stream == null:
		return
	_sfx_button_player.stream = _sfx_button_stream
	_sfx_button_player.volume_db = SpikeConfig.SFX_BUTTON_VOLUME_DB
	_sfx_button_player.play()


## 商店購買完成、或成就橫幅每次彈出（spike_ui.gd _advance_banner）。
func play_check_sfx() -> void:
	if _sfx_check_stream == null:
		return
	_sfx_check_player.stream = _sfx_check_stream
	_sfx_check_player.volume_db = SpikeConfig.SFX_CHECK_VOLUME_DB
	_sfx_check_player.play()


## 取得金幣：井裡撿金幣／金幣雨（well_world.gd _check_pickups）、成就頁領獎
## （spike_ui.gd _on_claim）共用同一顆——兩處都是「拿到錢」的同一種回饋。
func play_coin_sfx() -> void:
	if _sfx_coin_stream == null:
		return
	_sfx_coin_player.stream = _sfx_coin_stream
	_sfx_coin_player.volume_db = SpikeConfig.SFX_COIN_VOLUME_DB
	_sfx_coin_player.play()


## 開機套一次存檔裡的音量／靜音；設定頁匯入存檔碼成功後也會再呼叫一次
## （見 SpikeUI 存檔匯入那段），確保匯入進來的音量立刻生效而不是要重開遊戲才套用。
func apply_from_save() -> void:
	_apply_bus(BUS_MUSIC, SpikeSave.bgm_volume, SpikeSave.bgm_muted)
	_apply_bus(BUS_SFX, SpikeSave.sfx_volume, SpikeSave.sfx_muted)


func _apply_bus(bus_name: String, linear: float, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, muted)


## 設定頁拖動滑桿時即時預覽用：只套匯流排音量、不落盤（落盤是放開滑桿時
## SpikeSave.set_bgm_volume／set_sfx_volume 才做的事，見 SpikeUI._build_audio_row 的
## drag_ended 接線——拖曳過程中每一格都寫一次帶讀回驗證的存檔沒有必要）。
func set_bgm_volume_live(v: float) -> void:
	_apply_bus(BUS_MUSIC, v, SpikeSave.bgm_muted)


func set_sfx_volume_live(v: float) -> void:
	_apply_bus(BUS_SFX, v, SpikeSave.sfx_muted)


## 主頁背景音樂：main.gd 在「標題頁家族」（開始／商店／成就／設定／名單）那幾個狀態
## 進場時呼叫。已經在播就不重觸發——否則每次切換分頁都會重新起播一次，聽起來像
## 斷點續播失敗，而使用者要的是「在主頁面時循環撥放」，不是「每進一次分頁重播一次」。
## 08-18 三訂：不是進場立刻撥放，改成排一顆 MENU_BGM_START_DELAY_SEC 秒的計時器
## （已經在等就不重排——切分頁不會把 3 秒重新算過）；stop_menu_bgm() 會連同這顆計時器
## 一起停掉，離開主頁面家族的那一刻等待中的起播就會被取消，不會憑空冒出來。
func ensure_menu_bgm() -> void:
	if _bgm_streams.is_empty():
		return
	if bgm_player.playing:
		return
	if not _menu_bgm_start_timer.is_stopped():
		return
	_menu_bgm_start_timer.start(SpikeConfig.MENU_BGM_START_DELAY_SEC)


func stop_menu_bgm() -> void:
	_menu_bgm_start_timer.stop()
	bgm_player.stop()


func _play_random_bgm() -> void:
	bgm_player.stream = _bgm_streams[randi() % _bgm_streams.size()]
	bgm_player.play()


## 一首播完就再隨機挑一首接著播——不是把單一首設 loop 讓同一首無限重播，使用者要的是
## 「每次隨機撥一首」，兩首都有機會連續被選到也符合「隨機」的定義，不需要排除上一首。
func _on_bgm_finished() -> void:
	_play_random_bgm()


## 井裡（PLAYING）背景音樂：main.gd 在真正開一局（_start_run，不是 _resume）時呼叫，
## 固定從 Cancan 起播，不是隨機挑——見上方 GAMEPLAY_BGM_PATH 的 ⚠。
func start_gameplay_bgm() -> void:
	if _gameplay_bgm_stream == null:
		return
	if _bgm_fade_tween != null and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_interference_triggered = false
	gameplay_bgm_player.volume_db = 0.0
	gameplay_bgm_player.stream = _gameplay_bgm_stream
	gameplay_bgm_player.play()


## main.gd 在離開 PLAYING（不含 PAUSED——暫停時音樂繼續播，同大多數遊戲的既有慣例）
## 那幾個狀態呼叫。連同淡出用的 tween 一起殺掉：否則死亡那一幀正好撞上 Raora 登場淡出，
## tween 排的 tween_callback 會在結算頁畫面上把音樂重新 play() 起來。
func stop_gameplay_bgm() -> void:
	if _bgm_fade_tween != null and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	gameplay_bgm_player.stop()


## Raora 登場那一幀呼叫（well_world.gd _tick_cam_shake，跟 _play_come_sfx 同一個
## 一局一次的觸發旗標）：淡出 Cancan、切到 DiesIrae 循環播放。
func trigger_interference_bgm() -> void:
	if _interference_triggered or _interference_bgm_stream == null:
		return
	_interference_triggered = true
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(
		gameplay_bgm_player, "volume_db", -80.0, SpikeConfig.GAMEPLAY_BGM_FADE_SEC
	)
	_bgm_fade_tween.tween_callback(func() -> void:
		gameplay_bgm_player.stream = _interference_bgm_stream
		gameplay_bgm_player.volume_db = 0.0
		gameplay_bgm_player.play()
	)


## 循環：跟主頁那組「播完隨機挑下一首」不同，這裡永遠接著播同一首（不管當下是 Cancan
## 還是已經切到 DiesIrae 都一樣）——單純重播 gameplay_bgm_player 目前的 stream，
## 不必分兩個 handler 各自判斷「現在是哪一首」。
func _on_gameplay_bgm_finished() -> void:
	gameplay_bgm_player.play()
