extends Node
## 跨局存檔：金幣總數 ＋ 永久升級等級，以及「升級後的生效數值」。
##
## 分工：級數上限／每級增量／價格全部住 SpikeConfig.UPGRADE_TABLE（可調數值的唯一的家），
## 這個檔只負責「存了幾級」「還買不買得起」「算出來是多少」。
##
## ⚠ 例外，且是刻意的：下面那組**存檔格式常數**（SCHEMA_VERSION／NO_TIME_RECORD／
##   CODE_PREFIX／CODE_SALT／CODE_HASH_LEN）留在本檔，不搬進 SpikeConfig。硬規則管的是
##   「可調數值」，而這幾個一改就是破壞相容性（改 salt＝所有已發出的碼失效、改 schema＝
##   舊檔判讀方式變了），它們是格式定義不是調參旋鈕。放進調參檔會讓人以為可以隨手動。
##
## ⚠⚠ WellGenerator 不准讀這個檔。井的設計單位永遠是 SpikeConfig 的基礎值
##    （PILLARS_2.md:427 的驗算要求）。一旦生成器跟著升級後的跳躍力放大間距，
##    升級就從「容錯率」悄悄變成「可達性」，玩家花的金幣會被生成器原地吃掉。

const SAVE_PATH := "user://spike_save.json"
## 測試沙盒用的路徑。headless 冒煙測試會真的走 buy() → save() 這條路，
## 不隔開的話跑一次測試就把玩家的存檔洗掉了。
const SANDBOX_PATH := "user://spike_save_test.json"

## 存檔格式版本。v1＝拆分一般／極限模式欄位之前的舊格式（只有共用的 best_height_m）；
## v2＝本輪加入 schema_version 本身＋一般/極限分開的高度與時間欄位。
## v3（08-10 關卡制）＝最佳登頂用時從單一純量拆成「每關一格」的陣列。舊的純量值遷移進
##   **關卡一**那一格——v2 時代的終點就是 1000m＝現在的關卡一，遷過去語意完全對得上。
## 讀到缺這個欄位的舊檔一律視為 1（load_save 的 data.get 預設值）。
const CURRENT_SCHEMA_VERSION := 3
var schema_version: int = CURRENT_SCHEMA_VERSION

## 「無紀錄」的哨兵值：時間不可能是負的，用 -1.0 跟合法的 0 以上的秒數區分開，
## 避免跟「真的跑了 0 秒」搞混（雖然實務上不可能，但語意上比借用 0.0 乾淨）。
const NO_TIME_RECORD := -1.0

## 匯出碼格式：JSON → UTF-8 → Base64，前面掛版本前綴方便未來格式改了能一眼認出。
const CODE_PREFIX := "RAORA1-"
## ⚠⚠ 這個鹽值只是拿來擋「玩家手滑貼錯／少複製一段」與「隨手改幾個字」，
## **不是防作弊**：鹽值就寫死在這支 client code 裡，肯拆包的人一樣算得出合法碼，
## 而且玩家原本就能直接改瀏覽器 IndexedDB 裡的存檔本體。真正的防作弊只能在伺服器端做
## （見 ../HANDOFF.md 榜單那條 L1/L2 的規劃）。這裡不要、也不准在任何面向玩家的文案裡
## 說這串校驗碼「安全」。
const CODE_SALT := "raora-spike-well-export-v1"
## 校驗碼只取 sha256 前幾碼：短一點方便玩家肉眼比對「這串是不是貼完整了」，
## 不是為了省空間。
const CODE_HASH_LEN := 12

## 實際讀寫的路徑。正常執行永遠是 SAVE_PATH，只有測試會切到沙盒。
var save_path: String = SAVE_PATH

var coins: int = 0
var levels: Dictionary = {}
## 歷史最高抵達高度（m，跨局）。墓碑就長在這個高度附近那塊平台上，見
## WellGenerator._maybe_place_tomb（well_world.gd:174 是直接讀這個屬性，不是呼叫函式）。
## ⚠ 只增不減，由 record_height() 單一入口更新。
## v16→v17：一般／極限模式的紀錄已經拆成 best_height_normal_m／best_height_extreme_m
## 兩個欄位（見下方），這個舊欄位**繼續維持「兩模式取大值」**同步更新，不停用它——
## 理由是墓碃機制讀的就是這個屬性本身，拆欄位不該讓極限模式刷出來的高度對墓碃隱形。
var best_height_m: float = 0.0
## 一般模式的歷史最高高度／最佳登頂用時。時間只有登頂才算數（半路摔死沒有排行意義），
## NO_TIME_RECORD 代表這個模式還沒登頂過。
var best_height_normal_m: float = 0.0
## 每關各一格的最佳登頂用時（index 對齊 SpikeConfig.LEVEL_GOALS）。08-10 從單一純量
## 拆開：關卡一 1000m 與關卡三 2000m 的秒數放同一格比的是不同東西，混在一起的「紀錄」
## 沒有任何意義。NO_TIME_RECORD ＝這一關在這個模式下還沒登頂過。
## ⚠ 無盡模式不寫這裡（沒有終點就沒有登頂用時），它只更新 best_height_*。
var best_time_level_normal: Array[float] = []
## 極限模式版本，語意同上。
var best_height_extreme_m: float = 0.0
var best_time_level_extreme: Array[float] = []

## 最近一局用的 RNG seed（well_generator.gd 的 seed_val）。給未來榜單審核用——沒 seed
## 就沒辦法重現那一局的井長什麼樣子。0 代表「還沒有任何一局記錄過」，跟 well_generator
## 目前把 0 當「請自己 randomize」的慣例一致，不是合法的已記錄 seed 值。
var last_run_seed: int = 0

## 極限模式：所有干擾等待歸零。狀態的家在這裡（要跨局記住），但「歸零成什麼」的
## 規則住 SpikeConfig 的 eff_* 函式群 —— 遊戲層一律讀 eff_*，不讀這個旗標。
var extreme_mode: bool = false

## 無盡模式：這一局不在 goal_meters 停局，爬到死為止。狀態的家在這裡（跨局記住），
## 「規則」住 SpikeConfig.eff_has_goal() —— 判定端一律讀那個函式，不讀這個旗標，
## 理由同 extreme_mode（規則只能有一個家）。
## ⚠ 它跟極限模式、跟關卡選擇**互相獨立**，沒有任何互斥：可以「關卡三 ＋ 極限 ＋ 無盡」
##   一起開，那就是「用關卡三的環境、所有等待歸零、而且沒有終點」。
var endless_mode: bool = false

## 現在選的關卡（0-based，對齊 SpikeConfig.LEVEL_GOALS）。
## ⚠ 一律走 select_level() 改，不要直接指派——SpikeConfig.goal_meters 是跟著這顆同步的，
##   直接改這裡會讓「顯示第幾關」跟「終點在哪」對不上，而且完全不會報錯。
var selected_level: int = 0
## 已解鎖到第幾關（0-based，值＝可以選的最大 index）。0＝只有關卡一，2＝三關全開。
## ⚠ 只增不減，唯一入口是 report_level_cleared()。
var unlocked_level: int = 0
## 通關過的最高關卡 index（0-based）。-1 ＝ 一關都還沒通。
## ⚠⚠ 跟 unlocked_level 是**兩件事**：後者夾在 LEVEL_COUNT-1，通關最後一關時完全不會動，
##   所以「通關過關卡三」這件事在它身上看不出來——而 08-13 起懷錶與無盡模式都綁在那上面
##   （SpikeConfig.UNLOCK_TABLE）。⚠ 只增不減，唯一入口同樣是 report_level_cleared()。
var cleared_max: int = -1

## 攀爬手套的啟用開關（買了之後才有意義）。買到即預設啟用——花了錢卻要再找一個開關
## 才會生效，那是陷阱不是選項。
## ⚠ 「有沒有買」與「要不要用」是兩件事：前者是 levels["ledge"]，後者是這個旗標。
##   兩者的 AND 才是 has_ledge_grab()。
var ledge_enabled: bool = true

## 懷錶（二段跳）的啟用開關。語意完全比照 ledge_enabled。
## 08-13 起手套與懷錶都是通關獎勵（分別是通關關卡一／通關關卡二，SpikeConfig.UNLOCK_TABLE），
## 不再是商店商品。拿到即預設啟用，理由同上——拿到了卻要再找一個開關才會生效，那是陷阱不是選項。
## ⚠ 「有沒有拿到」與「要不要用」是兩件事，兩者的 AND 才是 has_pocket_watch()。
var watch_enabled: bool = true

## 全域音樂／音效音量與靜音（08-18 首次建立背景音樂系統，見 autoload/spike_audio.gd）。
## 這是「設定」不是「進度」，比照 ledge_enabled／watch_enabled 那組既有慣例：
## wipe()／clear_runtime() 不清這兩組（見該函式），開發者洗檔也不該連玩家調好的音量一起洗掉。
## 0.0~1.0 線性音量，實際套用時轉 dB 再寫進音訊匯流排（SpikeAudio._apply_bus）。
## ⚠ sfx_volume 預設 1.0（0dB，不額外衰減）：既有每種音效的 SFX_*_VOLUME_DB 已經個別
##   調過音量平衡，全域倍率再打折等於疊加兩層衰減。bgm_volume 預設偏低（0.6）——音樂
##   是全新加入、完全沒調過音量的素材，保守起見先小聲一點，不會一開場就太吵。
var bgm_volume: float = 0.6
var sfx_volume: float = 1.0
var bgm_muted: bool = false
var sfx_muted: bool = false

## 玩家顯示名稱與系統語言（08-19，設定頁「語言/名稱」分頁）。這是「設定」不是
## 「進度」，比照 bgm_volume 那組既有慣例：wipe()／clear_runtime() 不清這兩顆，
## 開發者洗檔不該連玩家選好的語言與打好的名字一起洗掉。
## ⚠ player_name 目前只在本機使用（做為未來排行榜的暱稱），沒有串接任何後端，
##   不做長度上限／字元白名單／髒話過濾——那些是 checklist.md §3.2 排行榜後端
##   上線時才要做的事，這裡只單純存字串。
var player_name: String = ""
## 值只認 SpikeConfig.LANGUAGE_ORDER 裡的旗標，認不得的一律退回 LANGUAGE_DEFAULT。
var language: String = "zh"

## 播過的劇情場景：id → true（08-13 項目 9）。⚠ 存的是「看過沒」不是「播到第幾段」——
## 每個場景只播一次，中途離開也算看過（不然玩家會被同一段卡住）。
var story_seen: Dictionary = {}

## 教學關通關旗標（08-13x，一次性）。true＝玩過教學關，開幕劇情播完後不再自動進入
## （見 src/main.gd._advance_to_title）。⚠ clear_runtime()／wipe() 也要清——開發者洗檔
## 或沙盒測試都要能重新走到「第一次玩」那條路，否則那條路就永遠測不到。
var tutorial_done: bool = false

## 成就狀態：id → 0 未解鎖 / 1 已解鎖未領獎 / 2 已領獎。三態的理由見 SpikeConfig SECTION 8c。
var achievements: Dictionary = {}
## 跨局累計計數。欄位清單的唯一的家是 SpikeConfig.STAT_KEYS。
var stats: Dictionary = {}

## 井底屍體堆的累計死亡次數（08-13 三訂，使用者拍板「每個關卡的每個模式各自獨立」）。
## key = death_key() 產生的 "<關卡>|<模式>"，value = 在那個組合底下死過幾次。
## ⚠ 跟 stats 的 deaths 類計數**不是同一件事**（如果日後加）：這個 dict 的唯一用途是
##   決定井底畫幾具屍體，所以它按關卡×模式切開；成就用的累計是全域的。
## ⚠ 存進來的值不設上限，畫幾具由 SpikeConfig.CORPSE_MAX 夾——上限是**表現參數**，
##   調小它不該把玩家已經死過的次數永久抹掉。
var corpse_deaths: Dictionary = {}

## 存檔讀寫失敗時的訊息（headless 測試會印出來；正常玩不會看到）
var last_error: String = ""


func _ready() -> void:
	load_save()


# ------------------------------------------------------------------
# 存檔 I/O
# ------------------------------------------------------------------

func load_save() -> void:
	_reset_levels()
	_reset_progress()
	coins = 0
	best_height_m = 0.0
	best_height_normal_m = 0.0
	best_height_extreme_m = 0.0
	# ⚠ 一定要在任何 return 之前建好陣列（沒有存檔／讀檔失敗／壞檔三條路都會提早 return），
	#   否則後面 best_time_level_normal[i] 會存取到空陣列。
	_reset_level_times()
	endless_mode = false
	selected_level = 0
	unlocked_level = 0
	cleared_max = -1
	story_seen = {}
	corpse_deaths = {}
	SpikeConfig.apply_level(selected_level)
	last_run_seed = 0
	last_error = ""

	if not FileAccess.file_exists(save_path):
		return

	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		last_error = "讀檔失敗（%d）" % FileAccess.get_open_error()
		return
	var raw := f.get_as_text()
	f.close()

	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		# 壞檔不能靜默蓋掉：先備份原始內容再套預設值，玩家或我們之後都還撿得回來。
		_write_backup_file("corrupt", raw)
		last_error = "存檔格式壞掉，原檔已備份，這次先當新檔跑"
		return

	# 上架前檢查清單 §11.2：存檔版本比這個版本的程式還新時，不讀也不覆寫——
	# 玩家可能玩過新版又退回舊版。同樣先備份原檔（跟壞檔同一招），這次先當新檔跑，
	# 而不是硬讀一份自己看不懂的格式。之後只要玩家換回新版，原檔還在。
	var incoming_version := int(data.get("schema_version", 1))
	if incoming_version > CURRENT_SCHEMA_VERSION:
		_write_backup_file("future-version", raw)
		last_error = "存檔來自較新版本的遊戲（格式 v%d，這個版本只讀得懂 v%d），原檔已備份，這次先當新檔跑" % [
			incoming_version, CURRENT_SCHEMA_VERSION
		]
		return

	_apply_save_dict(data)


## 白名單回填的唯一入口：讀檔（load_save）與匯入代碼（import_code）都走這裡，
## 外來 Dictionary 不管來源一律只認這裡列出的 key，多餘欄位直接忽略、缺的一律吃預設值。
## ⚠ 這是安全底線——不准為了省事把 data 整包塞進狀態，那樣外來資料多一個鍵就可能污染狀態。
func _apply_save_dict(data: Dictionary) -> void:
	# 缺這個欄位＝schema_version 加入之前的舊檔，一律視為 1（任務規格的預設值）。
	var version := int(data.get("schema_version", 1))

	coins = maxi(0, int(data.get("coins", 0)))
	extreme_mode = bool(data.get("extreme_mode", false))
	endless_mode = bool(data.get("endless_mode", false))
	ledge_enabled = bool(data.get("ledge_enabled", true))
	# 舊檔沒有這個 key ⇒ 拿 true。安全的方向：已經通關關卡二的老玩家讀完檔就直接有懷錶，
	# 而還沒通關的人 has_pocket_watch() 本來就會被 unlocked_level 擋下來。
	watch_enabled = bool(data.get("watch_enabled", true))
	last_run_seed = int(data.get("last_run_seed", 0))

	# 關卡進度。⚠ unlocked 先夾好再夾 selected，順序不能顛倒——選中的關卡不准超過
	#   已解鎖的最大值，否則手改存檔就能直接跳到關卡三。
	unlocked_level = clampi(int(data.get("unlocked_level", 0)), 0, SpikeConfig.LEVEL_COUNT - 1)
	selected_level = clampi(int(data.get("selected_level", 0)), 0, unlocked_level)
	# 08-13 新欄位。舊檔沒有 ⇒ 用 unlocked_level - 1 回推（unlocked_level 唯一的來源就是
	# 「通關第 N 關」），這樣老玩家不會因為多了一顆欄位就退回「一關都沒通」。
	# ⚠ 回推得不到「通關過最後一關」那一格（unlocked_level 頂在 LEVEL_COUNT-1 就不動了）
	#   ——那正是這顆欄位存在的原因。老玩家要再通一次關卡三才拿得到懷錶與無盡模式，
	#   這是換規則的一次性代價，不是 bug。
	cleared_max = clampi(
		int(data.get("cleared_max", unlocked_level - 1)), -1, SpikeConfig.LEVEL_COUNT - 1
	)
	# 兩個模式 08-13 起有解鎖門檻：舊檔可能存著 true，沒解鎖就強制關掉。
	# ⚠ 不能只在 UI 隱藏開關：eff_* 那組讀的是這兩顆旗標本身，留著 true 等於偷偷開著。
	if not extreme_unlocked():
		extreme_mode = false
	if not endless_unlocked():
		endless_mode = false

	var legacy_height := maxf(0.0, float(data.get("best_height_m", 0.0)))
	_reset_level_times()
	if version < 2:
		# v1 存檔只有共用的 best_height_m，一律遷移進「一般模式」那一欄——
		# 不能讓老玩家的紀錄因為拆欄位就歸零。這正是 schema_version 存在的第一個用途。
		best_height_normal_m = legacy_height
		best_height_extreme_m = 0.0
	else:
		best_height_normal_m = maxf(0.0, float(data.get("best_height_normal_m", 0.0)))
		best_height_extreme_m = maxf(0.0, float(data.get("best_height_extreme_m", 0.0)))
	if version < 3:
		# v2 的登頂用時是單一純量，而 v2 時代的終點就是 1000m＝關卡一，直接遷進第 0 格。
		best_time_level_normal[0] = _sanitize_time(data.get("best_time_normal_s", NO_TIME_RECORD))
		best_time_level_extreme[0] = _sanitize_time(data.get("best_time_extreme_s", NO_TIME_RECORD))
	else:
		_read_level_times(data.get("best_time_level_normal", []), best_time_level_normal)
		_read_level_times(data.get("best_time_level_extreme", []), best_time_level_extreme)
	# 舊欄位＝兩模式取大值，維持 WellGenerator 直接讀這個屬性時的行為不變（見上方宣告處註解）。
	best_height_m = maxf(best_height_normal_m, best_height_extreme_m)
	# 套用完畢，記憶體狀態一律視為目前版本；下次 save() 就會用新格式落盤。
	schema_version = CURRENT_SCHEMA_VERSION
	# 讀完檔才知道玩家上次選到哪一關，這裡把終點同步給 SpikeConfig（唯一寫入點是
	# apply_level）。⚠ 不能放在 SpikeConfig._ready()：autoload 順序是 Config → Save，
	# 那時候這邊的 selected_level 還沒讀進來。
	SpikeConfig.apply_level(selected_level)

	var saved = data.get("levels", {})
	if typeof(saved) == TYPE_DICTIONARY:
		# 只認目前表裡有的 key：改過表之後舊存檔仍讀得進來，多出來的欄位直接忽略
		for key in SpikeConfig.UPGRADE_TABLE.keys():
			levels[key] = clampi(int(saved.get(key, 0)), 0, max_level(key))

	# 成就與計數同上原則（只認目前表裡的 key）。⚠ 狀態夾在 0~2：存檔被手改成 3
	# 會讓卡片落到「既不能點也不顯示已領」的第四態。
	var saved_ach = data.get("achievements", {})
	if typeof(saved_ach) == TYPE_DICTIONARY:
		for id in SpikeConfig.ACHIEVEMENT_TABLE.keys():
			achievements[id] = clampi(int(saved_ach.get(id, 0)), 0, ST_CLAIMED)
	var saved_stats = data.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for key in SpikeConfig.STAT_KEYS:
			stats[key] = maxi(0, int(saved_stats.get(key, 0)))

	# 井底屍體堆（08-13 三訂）。⚠ 只認非負整數；key 不比對白名單（關卡×模式的組合會隨
	#   關卡數變動，寫死清單等於加關卡就要記得改這裡），認不得的 key 留著也只是不會被讀到。
	var saved_corpse = data.get("corpse_deaths", {})
	corpse_deaths = {}
	if typeof(saved_corpse) == TYPE_DICTIONARY:
		for key in saved_corpse.keys():
			corpse_deaths[String(key)] = maxi(0, int(saved_corpse[key]))

	# 播過的劇情（08-13）。⚠ 只認 bool、而且只認「有播過」這一種值：外來資料塞什麼進來
	#   都只會變成 true／不存在兩態，不可能污染出第三種狀態。
	var saved_story = data.get("story_seen", {})
	story_seen = {}
	if typeof(saved_story) == TYPE_DICTIONARY:
		for id in saved_story.keys():
			if bool(saved_story[id]):
				story_seen[String(id)] = true

	tutorial_done = bool(data.get("tutorial_done", false))

	bgm_volume = clampf(float(data.get("bgm_volume", 0.6)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 1.0)), 0.0, 1.0)
	bgm_muted = bool(data.get("bgm_muted", false))
	sfx_muted = bool(data.get("sfx_muted", false))

	player_name = String(data.get("player_name", "")).strip_edges()
	language = String(data.get("language", SpikeConfig.LANGUAGE_DEFAULT))
	if not SpikeConfig.LANGUAGE_ORDER.has(language):
		language = SpikeConfig.LANGUAGE_DEFAULT


## 時間欄位的防呆：任何負值（NO_TIME_RECORD 本身，或外來資料塞進來的亂數）一律
## 收斂成 NO_TIME_RECORD。匯入代碼也走這條，擋掉「校驗碼算過但塞了荒謬時間」的髒資料。
func _sanitize_time(raw) -> float:
	var t := float(raw)
	return t if t >= 0.0 else NO_TIME_RECORD


## 兩條每關時間陣列一律重建成「LEVEL_COUNT 格、全部無紀錄」。
## ⚠ 長度只認 SpikeConfig.LEVEL_COUNT，不認存檔裡的長度——關卡數以後增減時，
##   舊檔的短陣列／長陣列都不該讓後面的 index 存取直接爆掉。
func _reset_level_times() -> void:
	best_time_level_normal = []
	best_time_level_extreme = []
	for _i in range(SpikeConfig.LEVEL_COUNT):
		best_time_level_normal.append(NO_TIME_RECORD)
		best_time_level_extreme.append(NO_TIME_RECORD)


## 把外來陣列逐格搬進目標陣列（目標長度已由 _reset_level_times 定死）。
## 多的格子忽略、少的維持無紀錄，同「只認目前表裡的 key」那條白名單原則。
func _read_level_times(raw, into: Array[float]) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var src: Array = raw
	for i in range(mini(src.size(), into.size())):
		into[i] = _sanitize_time(src[i])


## 原子寫入（上架前檢查清單 §11.2）：先寫到 .tmp、讀回來驗證是合法 JSON，
## 才改名蓋掉正式檔。存檔當下斷電/關頁籤時，正式檔要嘛是完整舊檔、要嘛是完整新檔，
## 不會停在「寫一半」的半殘狀態。
func save() -> void:
	var tmp_path := save_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		last_error = "寫檔失敗（%d）" % FileAccess.get_open_error()
		return
	f.store_string(JSON.stringify(_to_save_dict(), "\t"))
	f.close()

	var check := FileAccess.open(tmp_path, FileAccess.READ)
	if check == null or typeof(JSON.parse_string(check.get_as_text())) != TYPE_DICTIONARY:
		if check != null:
			check.close()
		last_error = "寫檔驗證失敗，已保留原本的存檔"
		return
	check.close()

	var err := DirAccess.rename_absolute(tmp_path, save_path)
	if err != OK:
		last_error = "存檔改名失敗（%d）" % err
		return
	last_error = ""


## 存檔內容的單一組裝點：save()、匯出碼（export_code）、匯入前備份都用它，
## 避免同一份欄位清單抄兩三份、改一個欄位卻只改到其中一處。
func _to_save_dict() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		# 除錯用：這份檔是哪個遊戲版本寫的，跟 schema_version（存檔格式版本）分開記——
		# 玩家回報問題時兩者都要看得到。永遠寫「現在」的版本，不讀舊值回填。
		"game_version": SpikeConfig.GAME_VERSION,
		"coins": coins,
		"levels": levels,
		"best_height_m": best_height_m,
		"best_height_normal_m": best_height_normal_m,
		"best_height_extreme_m": best_height_extreme_m,
		"best_time_level_normal": best_time_level_normal,
		"best_time_level_extreme": best_time_level_extreme,
		"last_run_seed": last_run_seed,
		"extreme_mode": extreme_mode,
		"endless_mode": endless_mode,
		"selected_level": selected_level,
		"unlocked_level": unlocked_level,
		"cleared_max": cleared_max,
		"ledge_enabled": ledge_enabled,
		"watch_enabled": watch_enabled,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"bgm_muted": bgm_muted,
		"sfx_muted": sfx_muted,
		"player_name": player_name,
		"language": language,
		"story_seen": story_seen,
		"tutorial_done": tutorial_done,
		"achievements": achievements,
		"stats": stats,
		"corpse_deaths": corpse_deaths,
	}


## 備份檔的單一寫檔點：壞檔保留（_apply_save_dict 呼叫端）與匯入前備份都走這裡，
## 只有 tag 不同，方便玩家自己從檔名分辨這是哪一種備份。同一秒內重複觸發會覆蓋
## 同名備份（時間戳精度只到秒）——這是規格明講可以接受的取捨。
func _write_backup_file(tag: String, content: String) -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var backup_path := "%s.%s-%s" % [save_path, tag, stamp]
	var f := FileAccess.open(backup_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(content)
	f.close()


## debug／測試用：把存檔清成全新狀態並落盤
func wipe() -> void:
	clear_runtime()
	save()


## 只清記憶體、**不落盤**。headless 冒煙測試專用：測試必須在零升級狀態下跑
## （PILLARS_2.md:429 驗算要求①），但不能因此洗掉玩家的真實存檔。
func clear_runtime() -> void:
	coins = 0
	best_height_m = 0.0
	best_height_normal_m = 0.0
	best_height_extreme_m = 0.0
	_reset_level_times()
	last_run_seed = 0
	extreme_mode = false
	endless_mode = false
	selected_level = 0
	unlocked_level = 0
	cleared_max = -1
	story_seen = {}
	tutorial_done = false
	corpse_deaths = {}
	SpikeConfig.apply_level(selected_level)
	ledge_enabled = true
	watch_enabled = true
	_reset_levels()
	_reset_progress()


## 測試沙盒：把讀寫導向另一個檔案，之後就算真的走 buy() → save() 也碰不到玩家存檔。
## 冒煙測試在 _ready 第一件事就呼叫這個。
func use_sandbox() -> void:
	save_path = SANDBOX_PATH
	clear_runtime()


func _reset_levels() -> void:
	levels = {}
	for key in SpikeConfig.UPGRADE_TABLE.keys():
		levels[key] = 0


func _reset_progress() -> void:
	achievements = {}
	for id in SpikeConfig.ACHIEVEMENT_TABLE.keys():
		achievements[id] = ST_LOCKED
	stats = {}
	for key in SpikeConfig.STAT_KEYS:
		stats[key] = 0


# ------------------------------------------------------------------
# 模式開關（極限模式 / 攀爬手套啟用）
# ------------------------------------------------------------------

## 回傳切換後的狀態。落盤是因為兩個開關都要跨局記住——玩家不會想每次開遊戲都重按一次。
func toggle_extreme_mode() -> bool:
	# 08-13：加了解鎖門檻（通關關卡一）。理由同 toggle_ledge_enabled——規則收在同一處，
	# 免得未來多一個呼叫端就繞過「解鎖了才有開關」這件事。
	if not extreme_unlocked():
		return extreme_mode
	extreme_mode = not extreme_mode
	save()
	return extreme_mode


## 無盡模式開關。語意與落盤理由同 toggle_extreme_mode——兩個模式互相獨立，
## 這裡刻意不做任何互斥檢查（使用者拍板：三個維度可任意組合）。
func toggle_endless_mode() -> bool:
	if not endless_unlocked():
		return endless_mode
	endless_mode = not endless_mode
	save()
	return endless_mode


## ⚠ 沒買手套時不准切換：那顆 icon 在主頁根本不會顯示，這裡只是把規則收在同一處，
##   免得未來多一個呼叫端就繞過了「買了才有開關」這件事。
func toggle_ledge_enabled() -> bool:
	if not owns_ledge_grab():
		return ledge_enabled
	ledge_enabled = not ledge_enabled
	save()
	return ledge_enabled


## 懷錶開關。理由同 toggle_ledge_enabled：還沒拿到就不准切換，把「拿到才有開關」
## 這條規則收在同一處，免得未來多一個呼叫端就繞過去了。
func toggle_watch_enabled() -> bool:
	if not owns_pocket_watch():
		return watch_enabled
	watch_enabled = not watch_enabled
	save()
	return watch_enabled


# ------------------------------------------------------------------
# 音樂／音效音量（08-18）
# ------------------------------------------------------------------

func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	save()


func toggle_bgm_muted() -> bool:
	bgm_muted = not bgm_muted
	save()
	return bgm_muted


func toggle_sfx_muted() -> bool:
	sfx_muted = not sfx_muted
	save()
	return sfx_muted


# ------------------------------------------------------------------
# 語言／玩家名稱（08-19）
# ------------------------------------------------------------------

func set_language(lang: String) -> void:
	if not SpikeConfig.LANGUAGE_ORDER.has(lang) or lang == language:
		return
	language = lang
	save()


## ⚠ 目前沒有排行榜後端，這裡只存字串本身，不做重名比對／髒話過濾／長度限制
##   （那些留給 checklist.md §3.2 後端上線時一起做，見 player_name 宣告處的 ⚠）。
func set_player_name(new_name: String) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed == player_name:
		return
	player_name = trimmed
	save()


# ------------------------------------------------------------------
# 金幣與購買
# ------------------------------------------------------------------

func add_coins(n: int) -> void:
	if n <= 0:
		return
	coins += n
	save()


## 一局結束時記錄這局的最高高度。不論這局有沒有登頂都要呼叫——摔死那局爬到的高度
## 對墓碑一樣有意義（既有行為，呼叫端 main.gd._finish 不看 is_clear）。
## 依呼叫當下的 extreme_mode 分流進一般／極限各自的欄位；只增不減，沒破紀錄就完全
## 不落盤（省一次寫檔）。回傳「這個模式」是否破了紀錄。
func record_height(m: float) -> bool:
	var current := best_height_extreme_m if extreme_mode else best_height_normal_m
	if m <= current:
		return false
	if extreme_mode:
		best_height_extreme_m = m
	else:
		best_height_normal_m = m
	best_height_m = maxf(best_height_normal_m, best_height_extreme_m)
	save()
	return true


## 只有登頂才記錄用時（半路摔死的時間沒有排行意義，呼叫端要自己看 is_clear 再呼叫這個）。
## 越小越好；依呼叫當下的 extreme_mode ＋ selected_level 分流到對應那一格。
## 回傳是否刷新了「這個模式的這一關」的紀錄。
## ⚠ 用 selected_level 而不是另外傳參數：一局的關卡不會中途改變，多一個參數只會多一個
##   「呼叫端傳錯關卡」的漏接點。
func record_clear_time(seconds: float) -> bool:
	var s := maxf(0.0, seconds)
	var arr := _level_time_array()
	var idx := clampi(selected_level, 0, arr.size() - 1)
	var current: float = arr[idx]
	if current != NO_TIME_RECORD and s >= current:
		return false
	arr[idx] = s
	save()
	return true


## 目前模式對應的那條每關時間陣列。⚠ 回傳的是**同一個 Array 物件的參照**（GDScript 的
## Array 是參照型別），所以改回傳值就等於改狀態——record_clear_time 靠的就是這件事。
func _level_time_array() -> Array[float]:
	return best_time_level_extreme if extreme_mode else best_time_level_normal


## 查某一關在某個模式下的最佳登頂用時，給 UI 顯示用。NO_TIME_RECORD ＝還沒登頂過。
func best_time_of_level(idx: int, extreme: bool) -> float:
	var arr := best_time_level_extreme if extreme else best_time_level_normal
	if arr.is_empty():
		return NO_TIME_RECORD
	return arr[clampi(idx, 0, arr.size() - 1)]


# ------------------------------------------------------------------
# 關卡（08-10）
# ------------------------------------------------------------------

## 這一關能不能選。⚠ 這是唯一的判定入口，UI 的鎖頭與 select_level 的擋門都讀它，
##   不要在 UI 那邊自己寫一次 idx <= unlocked_level。
func is_level_unlocked(idx: int) -> bool:
	return idx >= 0 and idx <= unlocked_level and idx < SpikeConfig.LEVEL_COUNT


## 換關卡。⚠ 這是 selected_level 的唯一寫入點，而且**同時**把終點同步給 SpikeConfig
##   （goal_meters 的唯一寫入點是 SpikeConfig.apply_level）。兩者必須綁在一起改，
##   分開改就會出現「UI 說關卡三、井卻在 1000m 結束」這種不會報錯的錯。
## 沒解鎖／越界一律拒絕並回傳 false，不做任何變更。
func select_level(idx: int) -> bool:
	if not is_level_unlocked(idx):
		return false
	selected_level = idx
	SpikeConfig.apply_level(idx)
	save()
	return true


## 通關第 idx 關 ⇒ 解鎖第 idx+1 關。回傳「這次有沒有真的解鎖到新的一關」，
## 給 UI 決定要不要在結算頁多印一行「已解鎖 XXX」。
## ⚠ 只增不減；已經是最後一關就只回 false，不當成錯誤。
## ⚠ 呼叫端（main.gd._finish）必須先確認這一局真的是「有終點的模式」——無盡模式沒有
##   終點，永遠不會走到這裡（見 SpikeConfig.eff_has_goal）。
func report_level_cleared(idx: int) -> bool:
	if idx < 0 or idx >= SpikeConfig.LEVEL_COUNT:
		return false
	# ⚠ cleared_max 要先記：解鎖獎勵（手套／懷錶／兩個模式）看的是它，而通關最後一關時
	#   下面那段會 return false，寫在後面就永遠記不到最後一關。
	var was := cleared_max
	cleared_max = maxi(cleared_max, idx)
	var next := idx + 1
	if next >= SpikeConfig.LEVEL_COUNT or next <= unlocked_level:
		if cleared_max != was:
			save()
		return false
	unlocked_level = next
	save()
	return true


## 這段劇情播過了沒（08-13 項目 9）。
## 井底屍體堆的 key（08-13 三訂）：關卡 × 模式各自一堆。
## ⚠ 模式讀的是**當下**的 extreme_mode／endless_mode，所以一定要在玩家還沒回主畫面
##   改模式之前呼叫（結算當下就記，見 main.gd _finish）。
## ⚠ 兩個 toggle 是獨立的 ⇒ 四種組合，字串把兩個都寫進去而不是排成三選一：
##   「極限＋無盡」是玩得到的組合，硬塞進三選一會讓它跟別的模式共用同一堆屍體。
func corpse_key(level: int, extreme: bool, endless: bool) -> String:
	return "%d|%s%s" % [
		level, "x" if extreme else "-", "e" if endless else "-"
	]


## 這一局死了，記進當下關卡×模式那一堆。回傳記完之後的次數。
func record_corpse_death() -> int:
	var key := corpse_key(selected_level, extreme_mode, endless_mode)
	var n: int = int(corpse_deaths.get(key, 0)) + 1
	corpse_deaths[key] = n
	save()
	return n


## 這一關這個模式底下該畫幾具屍體（已夾在 CORPSE_MAX 之內）。
func corpse_count(level: int, extreme: bool, endless: bool) -> int:
	var n: int = int(corpse_deaths.get(corpse_key(level, extreme, endless), 0))
	return clampi(n, 0, SpikeConfig.CORPSE_MAX)


func story_seen_of(id: String) -> bool:
	return bool(story_seen.get(id, false))


## 記下「播過了」。⚠ 立刻落盤：玩家看完劇情下一步多半是關掉遊戲，沒存的話下次開起來
##   又要再看一次同一段。
func mark_story_seen(id: String) -> void:
	if id == "" or story_seen_of(id):
		return
	story_seen[id] = true
	save()


## 記下「教學關玩過了」。立刻落盤：理由同 mark_story_seen——玩家看完教學關下一步
## 很可能直接關掉遊戲。
func mark_tutorial_done() -> void:
	if tutorial_done:
		return
	tutorial_done = true
	save()


## 一局開始時記錄這局用的 RNG seed（well_generator.gd 的 seed_val），供未來榜單審核用——
## 呼叫端：main.gd._start_run，在決定好本局要用的 seed 之後、傳給 WellGenerator.setup 之前。
func record_run_seed(seed: int) -> void:
	last_run_seed = seed
	save()


func level_of(key: String) -> int:
	return int(levels.get(key, 0))


func max_level(key: String) -> int:
	var row: Dictionary = SpikeConfig.UPGRADE_TABLE.get(key, {})
	return int(row.get("max", 0))


func is_maxed(key: String) -> bool:
	return level_of(key) >= max_level(key)


## 下一級的價格；已滿級回 -1
func cost_of(key: String) -> int:
	if is_maxed(key):
		return -1
	var row: Dictionary = SpikeConfig.UPGRADE_TABLE.get(key, {})
	return int(row.get("cost_base", 0)) + int(row.get("cost_step", 0)) * level_of(key)


func can_afford(key: String) -> bool:
	var c := cost_of(key)
	return c >= 0 and coins >= c


## 回傳是否真的買到（買不起／已滿級回 false，不會扣錢）
func buy(key: String) -> bool:
	if not can_afford(key):
		return false
	coins -= cost_of(key)
	levels[key] = level_of(key) + 1
	save()
	return true


# ------------------------------------------------------------------
# 生效數值（遊戲層只讀這些函式，不要自己乘倍率）
# ------------------------------------------------------------------

func _step(key: String) -> float:
	var row: Dictionary = SpikeConfig.UPGRADE_TABLE.get(key, {})
	return float(row.get("step", 0.0))


## 跳躍：表裡的 step 是「跳躍**高度**」的增量比例（PILLARS 說的 +5%／級是高度）。
## 高度 h = v² / 2g，所以初速要乘 √(1+r)，直接乘 (1+r) 會變成高度 +69%。
func jump_velocity() -> float:
	var ratio := 1.0 + _step("jump") * float(level_of("jump"))
	return SpikeConfig.JUMP_VELOCITY * sqrt(ratio)


## 玩家實際跳得到的高度（HUD／商店顯示用；生成器一律用 SpikeConfig.MAX_JUMP_HEIGHT）
func jump_height() -> float:
	var v := jump_velocity()
	return v * v / (2.0 * SpikeConfig.GRAVITY)


func jetpack_fuel_meters() -> float:
	return SpikeConfig.JETPACK_FUEL_METERS_BASE + _step("fuel") * float(level_of("fuel"))


func jetpack_fuel_px() -> float:
	return jetpack_fuel_meters() * SpikeConfig.PIXELS_PER_METER


func jetpack_thrust_speed() -> float:
	return SpikeConfig.JETPACK_THRUST_SPEED_BASE


func whip_charges() -> int:
	return SpikeConfig.WHIP_CHARGES + int(_step("whip")) * level_of("whip")


func launcher_velocity() -> float:
	var ratio := 1.0 + _step("launcher") * float(level_of("launcher"))
	return SpikeConfig.LAUNCHER_VELOCITY * ratio


## 攀爬手套：有／無兩態，**且要開著**（主頁右上角那顆 icon，見 ledge_enabled）。
## ⚠ 生成器仍然不讀它（同本檔開頭的警語）——攀爬改的是容錯率，不是可達性，
##   井的間距一步都不會跟著放寬。停用它只是把容錯還回去，不會讓某塊板變成不可達。
func has_ledge_grab() -> bool:
	return owns_ledge_grab() and ledge_enabled


## 08-13 起手套是**通關關卡一的獎勵**，不再是商店商品（見 SpikeConfig.UNLOCK_TABLE 的 ⚠⚠）。
func owns_ledge_grab() -> bool:
	return unlock_owned("ledge")


## 這一項通關獎勵拿到了沒。**唯一的問法**（手套／懷錶／極限／無盡四項共用）。
## ⚠ 比的是 cleared_max 不是 unlocked_level：後者夾在 LEVEL_COUNT-1，通關最後一關時
##   完全不會動，用它當門檻的話「通關最後一關才給」的東西永遠拿不到。
func unlock_owned(id: String) -> bool:
	if not SpikeConfig.UNLOCK_TABLE.has(id):
		return false
	return cleared_max >= int(SpikeConfig.UNLOCK_TABLE[id]["level"])


## 懷錶「拿到了沒」。08-13 起門檻搬到 SpikeConfig.UNLOCK_TABLE（通關關卡二），
## 跟手套／極限／無盡共用同一張表與同一個問法。
func owns_pocket_watch() -> bool:
	return unlock_owned("watch")


## 極限／無盡模式解鎖了沒（08-13 新增門檻：以前是無條件可切）。
func extreme_unlocked() -> bool:
	return unlock_owned("extreme")


func endless_unlocked() -> bool:
	return unlock_owned("endless")


## 懷錶：拿到了、**而且**開著（主頁右上角那顆 icon，見 watch_enabled）。
## ⚠⚠ 生成器不准讀這個函式，理由見 SpikeConfig SECTION 3c 的 ⚠⚠——懷錶抬高的是
##   玩家的可達高度，井的間距一步都不會跟著放寬。
func has_pocket_watch() -> bool:
	return owns_pocket_watch() and watch_enabled


## 商店那一列右側顯示的「現在是多少」
func current_value_label(key: String) -> String:
	match key:
		"jump":
			return "跳躍高度 %.0f px" % jump_height()
		"fuel":
			return "燃料 %.0f m" % jetpack_fuel_meters()
		"whip":
			return "鞭子 %d 次" % whip_charges()
		"launcher":
			return "彈射初速 %.0f" % absf(launcher_velocity())
		"ledge":
			if level_of("ledge") <= 0:
				return "未裝備"
			# 買了但關掉時要說得出來，不然玩家會以為手套壞了
			return "已裝備（啟用中）" if ledge_enabled else "已裝備（已停用）"
		_:
			return ""


# ------------------------------------------------------------------
# 成就
# ------------------------------------------------------------------
# 三態：未解鎖 → 已解鎖未領獎 → 已領獎。定義表與門檻數字住 SpikeConfig SECTION 8c，
# 這個區塊只有「怎麼比對」與「狀態怎麼轉移」。
#
# ⚠⚠ 金幣只從 claim_achievement() 出去。check_achievements() 負責解鎖、一毛錢都不給——
#    兩處都能給錢就是重複領獎的漏洞，而且「解鎖時自動入帳」跟使用者要的
#    「點卡片才拿獎勵」直接衝突。

const ST_LOCKED := 0
const ST_UNLOCKED := 1
const ST_CLAIMED := 2


func ach_state(id: String) -> int:
	return int(achievements.get(id, ST_LOCKED))


func is_unlocked(id: String) -> bool:
	return ach_state(id) >= ST_UNLOCKED


## 階梯成就（v15）的卡片版位共用同一個位置，這個 slot 現在該顯示哪個 leaf id：
## 依序找第一個還沒領過的；三階都領完了就停在最高階，卡片繼續顯示「已領取」而不是消失。
## 非階梯成就的 slot key 本身就是它的 id，原樣回傳。
func current_tier_id(slot_key: String) -> String:
	if not SpikeConfig.ACHIEVEMENT_TIERS.has(slot_key):
		return slot_key
	var ids: Array = SpikeConfig.ACHIEVEMENT_TIERS[slot_key]
	for id in ids:
		if ach_state(id) != ST_CLAIMED:
			return id
	return ids[-1]


## 主頁「成就」按鈕的紅色驚嘆號用這個判斷：有任何一個已解鎖但還沒領獎的就要提醒。
func has_claimable_achievement() -> bool:
	for id in SpikeConfig.ACHIEVEMENT_ORDER:
		if ach_state(id) == ST_UNLOCKED:
			return true
	return false


## 跨局計數 +n。**不落盤**——踩碎平台這種事一局會發生幾十次，每次寫檔太貴。
## 落盤時機統一在一局結束（report_run_end）與領獎時。
func bump_stat(key: String, n: int = 1) -> void:
	if n <= 0 or not stats.has(key):
		return
	stats[key] = int(stats[key]) + n


## 拿當下的局內狀況比對所有成就，回傳「這一次新解鎖的 id 陣列」（沒有就是空陣列）。
##
## ctx 欄位（缺的一律當「還沒達成」，所以局中呼叫不必湊齊全部）：
##   cleared        本局是否登頂
##   whip_used      本局用掉幾次鞭子
##   jetpack_used   本局是否用過 jetpack
##   best_m         本局最高高度
##   elapsed        本局用時
##
## ⚠ 不落盤：呼叫端可能在一局之中每隔幾秒就呼叫一次。落盤由 report_run_end() 收尾。
## ⚠ 已解鎖的不重複回報（只看 ST_LOCKED），否則橫幅每一幀都會再跳一次。
func check_achievements(ctx: Dictionary) -> Array:
	var fresh: Array = []
	for id in SpikeConfig.ACHIEVEMENT_ORDER:
		if ach_state(id) != ST_LOCKED:
			continue
		if not _is_unlocked(id, ctx):
			continue
		achievements[id] = ST_UNLOCKED
		fresh.append(id)
	return fresh


## 單一成就的判定式。⚠ 這裡是邏輯不是數值——門檻數字一律讀 SpikeConfig，
##   要調「100 次」改那邊的 need，不要改這個函式。
func _is_unlocked(id: String, ctx: Dictionary) -> bool:
	var row: Dictionary = SpikeConfig.ACHIEVEMENT_TABLE.get(id, {})
	match String(row.get("kind", "")):
		"stat":
			return int(stats.get(String(row.get("stat", "")), 0)) >= int(row.get("need", 0))
		"live":
			# 目前只有 speed run 屬於這類：2 分鐘內抵達 500m，局中就能成立
			return float(ctx.get("best_m", 0.0)) >= SpikeConfig.SPEEDRUN_HEIGHT_M \
				and float(ctx.get("elapsed", INF)) <= SpikeConfig.SPEEDRUN_TIME
		"run":
			# 三個登頂類。⚠ 一律要求 cleared——「不用鞭子」本身不是成就，
			#   摔死的那局也完全符合「沒用鞭子」。
			if not bool(ctx.get("cleared", false)):
				return false
			var no_whip: bool = int(ctx.get("whip_used", 1)) <= 0
			var no_jet: bool = not bool(ctx.get("jetpack_used", true))
			match id:
				"soul":
					return no_whip and no_jet
				"chattini_model":
					return no_jet
				"spider2":
					return no_whip
	return false


## 一局開始的統一入口：算一次遊玩次數並立刻比對成就（kaela 就在按下「開始遊戲」的
## 那一刻解鎖，不必等這局打完）。回傳新解鎖的 id 陣列。
##
## ⚠ 呼叫端只能是 main.gd 的 _start_run，**不是** WellWorld.reset()：reset 也被 _ready()
##   呼叫，算在那裡等於開啟遊戲就先送一次遊玩次數。
## ⚠ 這裡落盤，不等結算——玩到一半離開標題的那局，玩家的認知也是「我玩過了」。
func report_run_start() -> Array:
	bump_stat("plays")
	var fresh := check_achievements({})
	save()
	return fresh


## 一局結束的統一入口：先把只有結算才知道的計數補上（被投擲物砸死；遊玩次數在
## report_run_start 算過了），再比對一次成就，最後**落盤**（整局的 stats 累積在這裡一次寫檔）。
## 回傳這一局結束時才新解鎖的 id 陣列，交給 UI 放橫幅。
##
## ⚠ 死因走 `death_by_projectile` 這個布林值，**不比對死因文字**。死因文字的家是
##   well_world.gd（HANDOFF「改文案去哪改」那段），改文案不該讓 BIG CAT 靜默失效。
func report_run_end(ctx: Dictionary) -> Array:
	if bool(ctx.get("death_by_projectile", false)):
		bump_stat("proj_deaths")
	var fresh := check_achievements(ctx)
	save()
	return fresh


## 領獎。回傳是否真的領到（未解鎖／已領過都回 false，不會給錢）。
## 金幣數看該 id 自己的 reward 欄位，沒寫就吃 ACHIEVEMENT_COIN_REWARD 預設值
## （v15 階梯成就 I/II/III 各自 20/50/100，見 spike_config.gd SECTION 8c）。
func claim_achievement(id: String) -> bool:
	if ach_state(id) != ST_UNLOCKED:
		return false
	achievements[id] = ST_CLAIMED
	var row: Dictionary = SpikeConfig.ACHIEVEMENT_TABLE.get(id, {})
	coins += int(row.get("reward", SpikeConfig.ACHIEVEMENT_COIN_REWARD))
	save()
	return true


# ------------------------------------------------------------------
# 存檔匯出／匯入碼（itch.io 免費方案沒有雲端存檔，這是玩家自救的備份／換裝置手段）
# ------------------------------------------------------------------
#
# 格式：JSON（跟落盤同一份，見 _to_save_dict） → UTF-8 bytes → Base64，
# 前面掛 CODE_PREFIX，尾巴用 "." 接一段完整性校驗碼。
#
# ⚠⚠ 校驗碼防的是「玩家手滑貼錯／少複製一段」與「隨手改幾個字」——不是防作弊。
#    鹽值（CODE_SALT）就寫死在這支 client code 裡，會拆包的人一樣算得出合法碼，
#    而且玩家原本就能直接改瀏覽器 IndexedDB 裡的存檔本體。真正的防作弊只能在
#    伺服器端做（見 ../HANDOFF.md 榜單那條）。UI 文案不要把這個校驗碼講成「安全」。


## 把目前存檔序列化成一串可以整段複製貼上的純文字。
func export_code() -> String:
	var payload := JSON.stringify(_to_save_dict())
	var b64 := Marshalls.utf8_to_base64(payload)
	var checksum := (payload + CODE_SALT).sha256_text().substr(0, CODE_HASH_LEN)
	return "%s%s.%s" % [CODE_PREFIX, b64, checksum]


## 嘗試匯入一串匯出碼。回傳 {"ok": bool, "reason": String}，reason 是給玩家看的
## 繁體中文訊息（成功也有，UI 可以直接顯示）。
##
## ⚠ 這是破壞性動作：成功會整包覆蓋目前存檔。覆蓋**之前**會先把匯入前的狀態另存一份
## user:// 備份（_write_backup_file "before-import"），貼錯代碼還有得救。
## ⚠ 匯入成功走的是跟 load_save() 同一條 _apply_save_dict() 白名單回填路徑，
## 不會把外來 Dictionary 整包塞進狀態。
func import_code(code: String) -> Dictionary:
	var trimmed := code.strip_edges()
	if not trimmed.begins_with(CODE_PREFIX):
		return {"ok": false, "reason": "代碼格式不對（開頭應該是 %s，可能貼錯或漏貼了）" % CODE_PREFIX}

	var body := trimmed.substr(CODE_PREFIX.length())
	var parts := body.split(".")
	if parts.size() != 2 or parts[0].is_empty() or parts[1].is_empty():
		return {"ok": false, "reason": "代碼格式不對（少了一段，可能沒複製完整）"}

	var b64 := parts[0]
	var checksum := parts[1]

	var payload := Marshalls.base64_to_utf8(b64)
	if payload.is_empty():
		return {"ok": false, "reason": "代碼解不開（內容不是有效的 Base64，貼的時候可能漏字或多字）"}

	var expect_checksum := (payload + CODE_SALT).sha256_text().substr(0, CODE_HASH_LEN)
	if checksum != expect_checksum:
		return {"ok": false, "reason": "校驗碼不符，代碼可能被改動過或貼錯了"}

	var data = JSON.parse_string(payload)
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "代碼內容不是有效的存檔格式"}

	var version := int(data.get("schema_version", 1))
	if version > CURRENT_SCHEMA_VERSION:
		return {"ok": false, "reason": "這串代碼是比較新版本的遊戲存的，目前這個版本讀不懂"}

	# 校驗都過關才動手覆蓋；覆蓋前先備份匯入前的狀態，萬一匯入的不是玩家想要的
	# （例如貼錯朋友的代碼），還能從 user:// 手動撿回來。
	_write_backup_file("before-import", JSON.stringify(_to_save_dict(), "\t"))

	_apply_save_dict(data)
	save()
	return {"ok": true, "reason": "匯入成功"}
