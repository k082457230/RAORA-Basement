class_name SpikeUI
extends CanvasLayer
## 爬井 spike 的 UI 層：七個頁面 + PLAYING 時的 HUD + 跨頁面的成就橫幅。
## 只管畫面與訊號，不碰遊戲邏輯。所有節點程式建構，不讀 .tscn。

signal start_pressed
signal resume_pressed
signal restart_pressed
signal quit_pressed
signal shop_pressed
signal shop_back_pressed
signal achievements_pressed
signal achievements_back_pressed
signal settings_pressed
signal settings_back_pressed
## 開發者傳送鈕（只在 SpikeConfig.dev_mode() 為真時才建得出來，見 _build_hud）
signal dev_teleport_pressed

# ============================================================
# 字型
# ============================================================
# ⚠ Web 匯出必須用內嵌字型。SystemFont 在瀏覽器沙盒裡讀不到系統字型，會 fallback 到
#   Godot 內建字型，而內建字型不含 CJK ⇒ 整個 UI 變豆腐方塊。桌面版看不出問題，
#   所以這條只有真的匯出 web 才會爆——別因為本機正常就把它改回 SystemFont。
#   字型檔不存在時（例如有人清掉 assets/）才退回 SystemFont，至少桌面版還能看。
#
# v17 起換成 **Noto Sans CJK TC**（原本是 Noto Sans TC）：後者不含平假名／片假名，
# 未來出日文版會整頁豆腐。CJK 版一份字型就涵蓋繁中＋假名＋部分韓文，之後不必再換字型。
# ⚠ 子集腳本只收「.gd 裡真的出現過的字」，所以現在的 .otf 裡**還沒有假名**——
#   等日文文案進到 .gd（或之後 i18n 改成掃 CSV）再重跑 tools/subset_font.py 就會補進去。
#   換字型換的是「未來補得進去」，不是「現在就有」。

const FONT_PATH := "res://assets/fonts/NotoSansCJKtc.otf"

## PackedStringArray 不是編譯期常數，只能用 static var
static var FONT_NAMES := PackedStringArray([
	"Microsoft JhengHei UI", "Microsoft JhengHei", "Noto Sans CJK TC", "PMingLiU", "Segoe UI",
])
## 全 UI 共用同一個 Font 實例。原本每個 Label 都 new 一個 SystemFont，
## 光是商店頁就會生出數十份同樣的字型物件。
static var _font_cache: Font = null


static func shared_font() -> Font:
	if _font_cache != null:
		return _font_cache
	if ResourceLoader.exists(FONT_PATH):
		_font_cache = load(FONT_PATH)
	else:
		var sf := SystemFont.new()
		sf.font_names = FONT_NAMES
		_font_cache = sf
	return _font_cache

# ============================================================
# 字級 / 尺寸常數（集中管理；顏色一律引用 SpikeConfig.C_*）
# ============================================================

const FONT_SIZE_TITLE := 64
const FONT_SIZE_SECTION := 30
const FONT_SIZE_SUBTITLE := 22
const FONT_SIZE_BODY := 18
const FONT_SIZE_BUTTON := 24
const FONT_SIZE_HUD_BIG := 32
const FONT_SIZE_HUD_SMALL := 16
const FONT_SIZE_RESULT_TITLE := 40
const FONT_SIZE_RESULT_BODY := 20
const FONT_SIZE_AIM := 22
const FONT_SIZE_CARD_NAME := 17
const FONT_SIZE_CARD_SMALL := 14

const BUTTON_MIN_SIZE := Vector2(240.0, 58.0)
const HUD_MARGIN := 24
const PAGE_MARGIN := 28
const WHIP_BOX_SIZE := Vector2(20.0, 20.0)
const WHIP_BOX_GAP := 6
const JETPACK_BAR_SIZE := Vector2(200.0, 14.0)
const AIM_BAR_SIZE := Vector2(280.0, 16.0)
const AIM_BOX_TOP_OFFSET := 140.0
## 開發者傳送鈕（畫面右緣中間）。刻意比一般按鈕小：它不是遊戲的一部分，
## 只是測試用的梯子，不該跟 HUD 搶注意力。
const DEV_BTN_SIZE := Vector2(132.0, 44.0)

## 金幣徽章（左上角那個方框 + 數字）
const BADGE_BOX_SIZE := Vector2(58.0, 58.0)
const BADGE_GAP := 12

## 商店卡片：6 張水平並排。1280 - 2*28 邊距 = 1224，6*186 + 5*14 = 1186，塞得下。
const CARD_SIZE := Vector2(186.0, 268.0)
const CARD_GAP := 14
const CARD_ICON_SIZE := Vector2(84.0, 84.0)

## 成就卡片：9 張排成 5 列 × 2 行（GridContainer）。格式刻意貼近商店卡（icon 在上、
## 文字在下），只是為了塞進 9 張而縮小。⚠ 寬高都逼近可用區，再加成就就會爆版——
## smoke.gd 的 UI 稽核有一條直接算這件事（同商店卡片那條的用意）。
## 5*226 + 4*16 = 1194 ≤ 1224（可用寬）；2*228 + 16 = 472 ≤ 0.68*720 = 489（可用高）。
## ⚠ 高度是 240 → 228 調過一次：240 時卡片區壓到下面的「返回」，把按鈕推出圓角外框之外
##   （截圖看得出來按鈕下緣被框線切掉）。改卡片高度而不是把按鈕往下擠——外框是版面邊界。
const ACH_CARD_SIZE := Vector2(226.0, 228.0)
const ACH_CARD_GAP := 16
const ACH_COLS := 5
const ACH_ICON_SIZE := Vector2(72.0, 72.0)
const ACH_BAND_TOP := 0.17
const ACH_BAND_BOTTOM := 0.85
## 「返回」那條橫帶的下緣。做成常數是為了讓冒煙測試量得到「按鈕有沒有撐出圓角外框」——
## 那正是上面那條 ⚠ 講的 bug，只在截圖上看得出來，不該只靠肉眼守。
const ACH_BACK_BAND_BOTTOM := 0.97

## 主頁右上角的開關 icon（極限模式 / 攀爬手套）
const TOGGLE_ICON_SIZE := Vector2(56.0, 56.0)
const TOGGLE_GAP := 16

## 主頁選關列（08-10）。⚠ 高度 46 > 44：觸控最小邊的可逆性條款
## （見 ../HANDOFF.md Deferred 第 6 條②），改小之前先讀那條。
const LEVEL_BUTTON_SIZE := Vector2(158.0, 46.0)
const LEVEL_ROW_GAP := 12

## 主頁三條 band 的比例。⚠ 提成常數不是為了好看，是為了讓 tests/audit_ui.gd
## 量得到「選關列 ＋ 說明 ＋ 四顆按鈕」塞不塞得進 band、band 下緣有沒有壓到存檔說明
## 那行——這種版面問題本來只有截圖看得出來（成就頁「返回」被切掉那次就是這樣抓到的）。
const START_TITLE_BAND_TOP := 0.08
const START_TITLE_BAND_BOTTOM := 0.34
const START_BUTTON_BAND_TOP := 0.36
const START_BUTTON_BAND_BOTTOM := 0.90
const START_SAVE_NOTE_BAND_TOP := 0.91
const START_SAVE_NOTE_BAND_BOTTOM := 0.98
const START_BOX_SEPARATION := 16
## 主頁按鈕組裡「一般按鈕」的顆數（開始／商店／成就／設定）。稽核算高度用。
const START_MENU_BUTTONS := 4

## 「成就」按鈕上的紅色驚嘆號
const ACH_NOTIF_DOT_SIZE := Vector2(20.0, 20.0)

## 成就解鎖橫幅：畫面上緣置中，顯示 BANNER_SHOW_TIME 秒，最後 BANNER_FADE_TIME 秒淡出。
## ⚠ 淡出要「在顯示時間之內」演完（不是演完再加 0.6s）——使用者說的是「出現 3s 就淡出」。
const BANNER_SIZE := Vector2(540.0, 92.0)
const BANNER_TOP := 18.0
const BANNER_SHOW_TIME := 3.0
const BANNER_FADE_TIME := 0.6
const BANNER_ICON_SIZE := Vector2(56.0, 56.0)

const KEYROW_LABEL_WIDTH := 200.0
const KEYROW_BUTTON_SIZE := Vector2(180.0, 44.0)

## 存檔碼那一列（設定頁）。輸入框要夠寬才看得出「這是一整串要全選的東西」，
## 但不能寬到把設定頁的按鍵列擠爆版。
const SAVE_CODE_EDIT_WIDTH := 420.0
const SAVE_CODE_BUTTON_SIZE := Vector2(120.0, 44.0)

# ============================================================
# 節點參照
# ============================================================

var _start_panel: Control
var _paused_panel: Control
var _gameover_panel: Control
var _clear_panel: Control
var _shop_panel: Control
var _ach_panel: Control
var _settings_panel: Control
var _hud: Control

var _height_label: Label
var _height_badge_style: StyleBoxFlat
## 目前顯示中的高度階級（tier_at 的結果）。-1 是「還沒畫過」的哨兵值，
## 保證 update_hud 第一次呼叫一定會上色，不用另外寫一條初始化路徑。
var _height_tier := -1
var _timer_caption: Label
var _timer_label: Label
## 計時器目前是不是「已登場」配色。每幀呼叫 add_theme_color_override 太浪費，
## 用這個旗標讓顏色只在跨越 0 的那一幀切一次。
var _timer_hot := false
var _coin_label: Label
var _interference_label: Label
var _whip_boxes: Array[ColorRect] = []
var _jetpack_bar_bg: ColorRect
var _jetpack_bar_fill: ColorRect
var _aim_box: Control
var _aim_bar_bg: ColorRect
var _aim_bar_fill: ColorRect

var _gameover_result_label: Label
var _clear_result_label: Label
## 登頂頁的劇情佔位／解鎖通知（小字，見 _build_result_panel 的 ⚠）
var _clear_story_label: Label
## 兩張結算卡片的 VBox 與卡片本體，給 tests/audit_ui.gd 量「內容塞不塞得進卡片」
var _gameover_box: Control
var _clear_box: Control
var _result_card_ref: Control

## 結算小卡的推進動畫（v17）。兩張卡（GAMEOVER／CLEAR）共用同一個計時器——
## 同一時間只可能顯示其中一張，各留一份計時器只是多一個會不同步的狀態。
var _result_cards: Array = []
var _slide_t := 0.0
var _slide_active := false

var _start_coin_label: Label
var _shop_coin_label: Label
var _ach_coin_label: Label
## key → {"name", "value", "level", "cost", "button", "icon"}
var _shop_cards: Dictionary = {}
## 成就 slot key（見 ACHIEVEMENT_SLOTS，不是 leaf id）→ {"button", "icon", "glyph", "name", "cond", "status"}
var _ach_cards: Dictionary = {}
## 主頁右上角的兩顆開關 icon，格式見 _make_toggle_icon
var _extreme_icon: Dictionary = {}
var _endless_icon: Dictionary = {}
var _ledge_icon: Dictionary = {}

## 選關列的三顆按鈕（每格 {button, style}），index 對齊 SpikeConfig.LEVEL_GOALS。
var _level_buttons: Array = []
## 主頁「成就」按鈕右上角的紅色驚嘆號：有已解鎖未領獎的成就時顯示
var _ach_notif_dot: Control
## 選關列底下那行「目標 / 最佳 / 無盡」說明
var _level_hint: Label
## action → Button
var _key_buttons: Dictionary = {}

## 設定頁的存檔碼欄位與結果訊息（v17）
var _save_code_edit: LineEdit
var _save_code_msg: Label
## 非空字串 = 正在等玩家按下要綁定的鍵
var _capturing_action := ""

# --- 成就橫幅 ---
## 橫幅是**跨頁面**的獨立圖層：show_screen 不碰它的 visible。局末解鎖時結算頁已經蓋掉
## HUD，橫幅若隸屬 HUD 就會一起被藏起來。
var _banner: Control
var _banner_icon: ColorRect
var _banner_glyph: Label
var _banner_name: Label
var _banner_cond: Label
## 還沒播的成就 id。一次解鎖多個就一個接一個播，不疊在同一條橫幅上。
var _banner_queue: Array = []
var _banner_timer := 0.0

# ============================================================
# 公開 API
# ============================================================

func build() -> void:
	# 暫停時（get_tree().paused）Paused 面板的按鈕仍要能按，所以 UI 整層不跟著暫停。
	process_mode = Node.PROCESS_MODE_ALWAYS

	_hud = _build_hud()
	add_child(_hud)

	_start_panel = _build_start_panel()
	add_child(_start_panel)

	_paused_panel = _build_paused_panel()
	add_child(_paused_panel)

	var go := _build_result_panel("摔落", SpikeConfig.C_STEAL_WARN)
	_gameover_panel = go["panel"]
	_gameover_result_label = go["result_label"]
	# 摔落頁沒有劇情也沒有解鎖，那顆 label 永遠不用（建了才能共用同一個建構函式）
	_gameover_box = go["box"]
	add_child(_gameover_panel)

	var cl := _build_result_panel("爬出去了", SpikeConfig.C_GOAL)
	_clear_panel = cl["panel"]
	_clear_result_label = cl["result_label"]
	_clear_story_label = cl["story_label"]
	_clear_box = cl["box"]
	_result_card_ref = cl["card"]
	add_child(_clear_panel)

	_shop_panel = _build_shop_panel()
	add_child(_shop_panel)

	_ach_panel = _build_achievements_panel()
	add_child(_ach_panel)

	_settings_panel = _build_settings_panel()
	add_child(_settings_panel)

	# 橫幅最後加：同一個 CanvasLayer 裡後加的畫在上面，它必須蓋過所有頁面
	_banner = _build_banner()
	add_child(_banner)

	show_screen("START")


func show_screen(state: String) -> void:
	# 換頁一律取消「等待按鍵」，不然離開設定頁之後下一次按鍵會被莫名其妙綁走
	_cancel_capture()

	_start_panel.visible = state == "START"
	_hud.visible = state == "PLAYING" or state == "PAUSED"
	_paused_panel.visible = state == "PAUSED"
	_gameover_panel.visible = state == "GAMEOVER"
	_clear_panel.visible = state == "CLEAR"
	_shop_panel.visible = state == "SHOP"
	_ach_panel.visible = state == "ACHIEVEMENTS"
	_settings_panel.visible = state == "SETTINGS"
	# ⚠ 這裡刻意不動 _banner.visible：它跨頁面，由 _process 的計時器獨自決定生死。

	# 金幣是跨局累計的，任何回到標題／商店的路徑都要重讀，不能只在 build() 時填一次
	if state == "START":
		_start_coin_label.text = "%d" % SpikeSave.coins
		refresh_toggles()
		refresh_levels()
		refresh_ach_badge()
	elif state == "SHOP":
		refresh_shop()
	elif state == "ACHIEVEMENTS":
		refresh_achievements()
	elif state == "SETTINGS":
		# ⚠ 清空要放這裡不能放 refresh_settings()：後者在每次重綁按鍵時也會被呼叫，
		#   放進去的話玩家剛按「匯出」產生的碼會被下一次重綁清掉。
		_reset_save_code_ui()
		refresh_settings()
	elif state == "GAMEOVER" or state == "CLEAR":
		# 每次進結算都從畫面外重推一次。⚠ 不能只在 build() 時擺好位置：玩第二局再死時
		# 卡片會已經在定位上，動畫等於只演了第一次。
		_begin_result_slide()


## main.gd 靠這個判斷該不該吃 ESC——正在等綁定時它得讓路，
## 否則玩家永遠沒辦法把暫停鍵綁到別的鍵上。
func is_capturing_key() -> bool:
	return _capturing_action != ""


func update_hud(d: Dictionary) -> void:
	# ⚠ 顯示的是「本回合抵達過的最高高度」而不是當下高度（使用者拍板），而且**不寫出
	#   目標 1000m、也不畫進度條**：當下高度會在每一次下墜時往回跳，讀起來像進度倒退；
	#   分母／進度條則會讓「還差 800m」變成常駐的挫折來源。這一格只回答「我這局爬多高」。
	var best_m: float = float(d["best_m"])
	_height_label.text = "%d m" % int(round(best_m))

	# 跨階提示：徽章底色與文字色只在跨過 500m 級距的那一幀切一次（同 _timer_hot 的
	# 節流慣例），不必每幀都重寫 stylebox。
	var tier := SpikeConfig.tier_at(best_m)
	if tier != _height_tier:
		_height_tier = tier
		_height_badge_style.bg_color = SpikeConfig.tier_badge_color_at(best_m)
		_height_label.add_theme_color_override("font_color", SpikeConfig.tier_text_color_at(best_m))

	# 主計時器是「Raora 登場倒數」。歸零之後不清空，改成向上計干擾已經持續多久——
	# 玩家在干擾期最想知道的就是「我還撐了幾秒」，把它變成空白等於丟掉一個壓力來源。
	var countdown: float = d["countdown"]
	var hot := countdown <= 0.0
	if hot:
		# ⚠ 走 eff_：極限模式下登場等待是 0，「已登場幾秒」就等於 elapsed 本身。
		#   直接讀 interference_start 的話極限模式會印出 -67 開頭的負秒數。
		_timer_label.text = "+%s" % _format_time(
			float(d["elapsed"]) - SpikeConfig.eff_interference_start()
		)
		_timer_caption.text = "Raora 已登場"
	else:
		_timer_label.text = _format_time(countdown)
		_timer_caption.text = "Raora 登場倒數"
	if hot != _timer_hot:
		_timer_hot = hot
		var col: Color = SpikeConfig.C_COUNTDOWN_HOT if hot else SpikeConfig.C_TEXT
		_timer_label.add_theme_color_override("font_color", col)
		_timer_caption.add_theme_color_override("font_color", col)

	_coin_label.text = "金幣 %d" % int(d["coins"])

	var interference: String = d["interference"]
	_interference_label.text = interference
	_interference_label.visible = interference != ""

	# 鞭子格數吃永久升級，所以格子建到硬上限、依本局實際上限決定顯示幾格
	var charges: int = d["whip_charges"]
	var whip_max: int = int(d["whip_max"])
	for i in range(_whip_boxes.size()):
		_whip_boxes[i].visible = i < whip_max
		_whip_boxes[i].color = SpikeConfig.C_WHIP if i < charges else SpikeConfig.C_TEXT_DIM

	var jetpack_ratio: float = clampf(d["jetpack_ratio"], 0.0, 1.0)
	_jetpack_bar_fill.size = Vector2(_jetpack_bar_bg.size.x * jetpack_ratio, _jetpack_bar_bg.size.y)

	var aiming: bool = d["aiming"]
	_aim_box.visible = aiming
	if aiming:
		var aim_ratio: float = clampf(d["aim_ratio"], 0.0, 1.0)
		_aim_bar_fill.size = Vector2(_aim_bar_bg.size.x * aim_ratio, _aim_bar_bg.size.y)


## ⚠ 兩個結算頁（摔落／登頂）共用同一份主體，只有第一行的標頭與最後幾行不同：
##   摔落補死因，登頂補劇情佔位與解鎖通知。共用的部分不要為了排版各抄一份。
func set_result(d: Dictionary) -> void:
	var cleared: bool = d["cleared"]
	var level: int = int(d.get("level", 0))
	var endless: bool = bool(d.get("endless", false))
	var lines := PackedStringArray()
	# 標頭：無盡模式沒有終點，印「目標 X m」會是假資訊（那個數字這一局根本不會用到）。
	if endless:
		lines.append("%s　·　無盡模式" % SpikeConfig.level_name(level))
	else:
		lines.append("%s　·　目標 %d m" % [
			SpikeConfig.level_name(level), int(round(float(d["goal_m"])))
		])
	lines.append("最高高度：%d m" % int(round(float(d["best_m"]))))
	lines.append("用時：%s" % _format_time(d["elapsed"]))
	lines.append("鞭子用量：%d / %d" % [int(d["whip_used"]), int(d["whip_max"])])
	lines.append("這局金幣：+%d（累計 %d）" % [int(d["coins"]), SpikeSave.coins])
	lines.append("燃料補給 / 蟲洞：%d / %d" % [int(d.get("fuels", 0)), int(d["wormholes"])])
	lines.append("踩頭 / 撞飛：%d / %d" % [int(d["stomps"]), int(d["bumps"])])
	if not cleared:
		lines.append("死因：%s" % String(d["cause"]))
		_gameover_result_label.text = "\n".join(lines)
		return
	_clear_result_label.text = "\n".join(lines)
	# 登頂才有的劇情佔位（使用者拍板這一輪只放可辨識的佔位，素材到位再換
	# SpikeConfig.LEVEL_STORY_PLACEHOLDER）。⚠ 換的時候不要順手把播放器邏輯塞進 UI 這層。
	var story := PackedStringArray([SpikeConfig.level_story(level)])
	if bool(d.get("unlocked", false)):
		story.append("已解鎖：%s" % SpikeConfig.level_name(level + 1))
	_clear_story_label.text = "\n".join(story)
	_clear_story_label.visible = true


# ============================================================
# 輸入：按鍵重綁的擷取
# ============================================================
# _input 早於 _unhandled_input，所以這裡能搶在 main.gd 的暫停鍵之前吃掉事件——
# 玩家才有辦法把暫停綁到別的鍵上。

func _input(event: InputEvent) -> void:
	if _capturing_action == "":
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	SpikeKeys.set_key(_capturing_action, event.keycode)
	_capturing_action = ""
	refresh_settings()
	get_viewport().set_input_as_handled()


func _cancel_capture() -> void:
	if _capturing_action == "":
		return
	_capturing_action = ""
	if _settings_panel != null:
		refresh_settings()

# ============================================================
# 建構：HUD
# ============================================================

func _build_hud() -> Control:
	var hud := Control.new()
	hud.name = "Hud"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 左上：高度。白框徽章、底色隨跨階提示變化（SpikeConfig SECTION 9c）——
	# 常駐可見，不是跨階瞬間才閃一下，讓玩家隨時都讀得到「現在第幾階」。
	var top_left := VBoxContainer.new()
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_theme_constant_override("separation", 8)
	var height_badge := PanelContainer.new()
	height_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_height_badge_style = StyleBoxFlat.new()
	_height_badge_style.border_color = Color(1.0, 1.0, 1.0)
	_height_badge_style.set_border_width_all(2)
	_height_badge_style.set_corner_radius_all(8)
	_height_badge_style.content_margin_left = 14.0
	_height_badge_style.content_margin_right = 14.0
	_height_badge_style.content_margin_top = 4.0
	_height_badge_style.content_margin_bottom = 4.0
	height_badge.add_theme_stylebox_override("panel", _height_badge_style)
	_height_label = _make_label("0 m", FONT_SIZE_HUD_BIG, SpikeConfig.C_TEXT)
	height_badge.add_child(_height_label)
	top_left.add_child(height_badge)
	_coin_label = _make_label("金幣 0", FONT_SIZE_HUD_SMALL, SpikeConfig.C_PICKUP)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_left.add_child(_coin_label)
	hud.add_child(top_left)
	top_left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, HUD_MARGIN)

	# 右上：倒數計時 + 干擾狀態
	var top_right := VBoxContainer.new()
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.add_theme_constant_override("separation", 4)
	_timer_caption = _make_label("Raora 登場倒數", FONT_SIZE_HUD_SMALL, SpikeConfig.C_TEXT)
	_timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(_timer_caption)
	_timer_label = _make_label("0:00", FONT_SIZE_HUD_BIG, SpikeConfig.C_TEXT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(_timer_label)
	_interference_label = _make_label("", FONT_SIZE_BODY, SpikeConfig.C_STEAL_WARN)
	_interference_label.visible = false
	top_right.add_child(_interference_label)
	hud.add_child(top_right)
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, HUD_MARGIN)

	# 左下：jetpack 燃料 + 鞭子存量
	var bottom_left := VBoxContainer.new()
	bottom_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_left.add_theme_constant_override("separation", 8)

	bottom_left.add_child(_make_label(
		"噴射 (%s 長按)" % SpikeKeys.label_of("jet"), FONT_SIZE_HUD_SMALL, SpikeConfig.C_TEXT_DIM
	))
	var jbar := _make_bar(JETPACK_BAR_SIZE, SpikeConfig.C_WALL, SpikeConfig.C_LAUNCHER)
	_jetpack_bar_bg = jbar["bg"]
	_jetpack_bar_fill = jbar["fill"]
	bottom_left.add_child(jbar["wrap"])

	bottom_left.add_child(_make_label(
		"鞭子 (%s)" % SpikeKeys.label_of("aim"), FONT_SIZE_HUD_SMALL, SpikeConfig.C_TEXT_DIM
	))
	var whip_row := HBoxContainer.new()
	whip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	whip_row.add_theme_constant_override("separation", WHIP_BOX_GAP)
	# 建到「基礎 + 升級硬上限」那麼多格；每局實際顯示幾格由 update_hud 決定
	var whip_row_max: int = SpikeConfig.WHIP_CHARGES \
		+ int(SpikeConfig.UPGRADE_TABLE["whip"]["max"]) * int(SpikeConfig.UPGRADE_TABLE["whip"]["step"])
	for i in range(whip_row_max):
		var box := ColorRect.new()
		box.custom_minimum_size = WHIP_BOX_SIZE
		box.color = SpikeConfig.C_WHIP
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		whip_row.add_child(box)
		_whip_boxes.append(box)
	bottom_left.add_child(whip_row)

	hud.add_child(bottom_left)
	bottom_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, HUD_MARGIN)

	# 正中央偏上：瞄準指示
	_aim_box = VBoxContainer.new()
	_aim_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_box.add_theme_constant_override("separation", 8)
	_aim_box.add_child(_make_label("瞄準中 — 點左鍵射出", FONT_SIZE_AIM, SpikeConfig.C_AIM))
	var abar := _make_bar(AIM_BAR_SIZE, SpikeConfig.C_WALL, SpikeConfig.C_AIM)
	_aim_bar_bg = abar["bg"]
	_aim_bar_fill = abar["fill"]
	_aim_box.add_child(abar["wrap"])
	_aim_box.visible = false
	hud.add_child(_aim_box)
	_aim_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_aim_box.position.y = AIM_BOX_TOP_OFFSET

	# 右側中間：開發者傳送鈕（測試用梯子，一按往上 300m）。
	# ⚠⚠ dev_mode() 為假時**整顆不建出來**，不是建了再 hide()——一般玩家的畫面上
	#   根本沒有這個節點，點不到、也不會因為某個 visible 被誤設而冒出來。
	#   開關條件的唯一的家在 SpikeConfig SECTION 11。
	# ⚠ focus_mode = NONE：按過之後焦點會留在按鈕上，Button 會把空白鍵／方向鍵吃掉，
	#   人就跳不起來也走不動了（這種 bug 很容易被誤判成「傳送把玩家弄壞了」）。
	if SpikeConfig.dev_mode():
		var dev_btn := _make_button("▲ +%d m" % int(SpikeConfig.DEV_TELEPORT_M))
		dev_btn.custom_minimum_size = DEV_BTN_SIZE
		dev_btn.add_theme_font_size_override("font_size", FONT_SIZE_HUD_SMALL)
		dev_btn.focus_mode = Control.FOCUS_NONE
		dev_btn.tooltip_text = "開發者傳送：這一局的成績與成就將不會被記錄"
		dev_btn.pressed.connect(func() -> void: dev_teleport_pressed.emit())
		hud.add_child(dev_btn)
		# ⚠ 直接給座標，不用 set_anchors_and_offsets_preset：那條路會拿 Button 自己算出來的
		#   最小尺寸去排，結果比 DEV_BTN_SIZE 寬，右半邊被切在畫面外（第一版就是這樣）。
		#   整個遊戲都畫在 VIEW_W×VIEW_H 的設計解析度上（靠 stretch 等比放大），
		#   所以這裡算絕對座標是安全的。
		dev_btn.size = DEV_BTN_SIZE
		dev_btn.position = Vector2(
			SpikeConfig.VIEW_W - DEV_BTN_SIZE.x - HUD_MARGIN,
			(SpikeConfig.VIEW_H - DEV_BTN_SIZE.y) * 0.5
		)

	return hud


## 建一條「底色 + 填充」橫條，回傳 {wrap, bg, fill}。wrap 是純 Control（非 Container），
## 所以 bg/fill 的手動 size 不會被 Godot 的容器排版覆蓋。
func _make_bar(size: Vector2, bg_color: Color, fill_color: Color) -> Dictionary:
	var wrap := Control.new()
	wrap.custom_minimum_size = size
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.size = size
	bg.color = bg_color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(bg)

	var fill := ColorRect.new()
	fill.size = Vector2(0.0, size.y)
	fill.color = fill_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(fill)

	return {"wrap": wrap, "bg": bg, "fill": fill}

# ============================================================
# 建構：主頁
# ============================================================
# 版面（使用者指定）：左上角金幣徽章、上半置中大標題、下半三顆按鈕。
# 操作說明搬去設定頁——主頁只留這三個決策，一眼就看得完。

func _build_start_panel() -> Control:
	var panel := _make_page("StartPanel")

	var badge := _make_coin_badge()
	_start_coin_label = badge["label"]
	panel.add_child(badge["node"])

	# 右上角的三顆開關 icon（跟左上角的金幣徽章對稱）。
	# ⚠ 攀爬手套那顆「沒買就不顯示」——顯示一個按了沒反應的開關比不顯示更糟。
	# ⚠ 極限與無盡是**兩個獨立維度**（使用者拍板），刻意不做互斥：兩顆都開＝
	#   「所有等待歸零而且沒有終點」，那是合法的組合不是錯誤狀態。
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", TOGGLE_GAP)
	toggles.alignment = BoxContainer.ALIGNMENT_END
	_extreme_icon = _make_toggle_icon("極")
	_extreme_icon["button"].pressed.connect(func() -> void:
		SpikeSave.toggle_extreme_mode()
		refresh_toggles()
	)
	toggles.add_child(_extreme_icon["node"])
	_endless_icon = _make_toggle_icon("盡")
	_endless_icon["button"].pressed.connect(func() -> void:
		SpikeSave.toggle_endless_mode()
		refresh_toggles()
		# 無盡開關會改變選關列的說明文字（有終點 ⇄ 沒終點），一起刷新。
		refresh_levels()
	)
	toggles.add_child(_endless_icon["node"])
	_ledge_icon = _make_toggle_icon("爬")
	_ledge_icon["button"].pressed.connect(func() -> void:
		SpikeSave.toggle_ledge_enabled()
		refresh_toggles()
	)
	toggles.add_child(_ledge_icon["node"])
	panel.add_child(toggles)
	toggles.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, PAGE_MARGIN + 20
	)

	var title_band := _make_band(START_TITLE_BAND_TOP, START_TITLE_BAND_BOTTOM)
	title_band.add_child(_center_of(
		_make_label("RAORA'S BASEMENT", FONT_SIZE_TITLE, SpikeConfig.C_TEXT)
	))
	panel.add_child(title_band)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", START_BOX_SEPARATION)
	# 選關列排在「開始遊戲」正上方：玩家的動線是「先決定爬哪一關 → 再按開始」，
	# 擺到標題旁邊或頁尾都會讓這兩件事看起來無關。
	box.add_child(_build_level_row())
	box.add_child(_make_level_hint())
	var start_button := _make_button("開始遊戲")
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	box.add_child(start_button)
	var shop_button := _make_button("商店")
	shop_button.pressed.connect(func() -> void: shop_pressed.emit())
	box.add_child(shop_button)
	var ach_wrap := Control.new()
	ach_wrap.custom_minimum_size = BUTTON_MIN_SIZE
	ach_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ach_button := _make_button("成就")
	ach_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	ach_button.pressed.connect(func() -> void: achievements_pressed.emit())
	ach_wrap.add_child(ach_button)
	_ach_notif_dot = _make_notif_dot()
	ach_wrap.add_child(_ach_notif_dot)
	box.add_child(ach_wrap)
	var settings_button := _make_button("設定")
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	box.add_child(settings_button)

	# ⚠ 08-10 再往上挪一次（0.48 → 0.36）：多了選關列（46）＋說明字（約 21）＋兩道
	#   separation（32），總高從 280 變 378px。**再加任何一列之前一定要重算**——
	#   band 現在只剩 10px 餘裕，壓到下面那行存檔說明就會疊字。
	#   ⚠ 這件事現在 tests/audit_ui.gd 有一條斷言在守（搜「主頁版面」），不是靠記性。
	var button_band := _make_band(START_BUTTON_BAND_TOP, START_BUTTON_BAND_BOTTOM)
	button_band.add_child(_center_of(box))
	panel.add_child(button_band)

	# 存檔說明：user:// 在 Web 版落在瀏覽器 IndexedDB，關分頁/重開機仍在，
	# 但清瀏覽器資料或換瀏覽器/裝置會遺失（itch 免費方案無雲端存檔）。
	var save_note_band := _make_band(START_SAVE_NOTE_BAND_TOP, START_SAVE_NOTE_BAND_BOTTOM)
	save_note_band.add_child(_center_of(
		_make_label("進度存在此瀏覽器，關閉分頁仍會保留；清除瀏覽器資料或換裝置會遺失",
			FONT_SIZE_CARD_SMALL, SpikeConfig.C_TEXT_DIM)
	))
	panel.add_child(save_note_band)

	return panel

## 主頁選關列（08-10）。三顆按鈕橫排，index 對齊 SpikeConfig.LEVEL_GOALS。
## ⚠ 未解鎖的那幾關**不顯示名稱與目標高度**：「下一關要爬多高」本身就是誘因，
##   先劇透等於把它先花掉。
## ⚠ 四個狀態共用同一份 stylebox，理由同 _make_toggle_icon：「有沒有選中」必須是
##   唯一的視覺變數，留著預設的 hover 高亮會讓「滑過去」看起來像「已選中」。
func _build_level_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", LEVEL_ROW_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_level_buttons.clear()
	for i in range(SpikeConfig.LEVEL_COUNT):
		var idx := i
		var b := Button.new()
		b.add_theme_font_override("font", shared_font())
		b.add_theme_font_size_override("font_size", FONT_SIZE_CARD_NAME)
		b.custom_minimum_size = LEVEL_BUTTON_SIZE
		var sb := StyleBoxFlat.new()
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(10)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		# ⚠ 擋門在 SpikeSave.select_level（沒解鎖直接回 false），這裡不自己判一次——
		#   「哪幾關能選」只能有一個判定來源。
		b.pressed.connect(func() -> void:
			if SpikeSave.select_level(idx):
				refresh_levels()
		)
		row.add_child(b)
		_level_buttons.append({"button": b, "style": sb})
	return row


func _make_level_hint() -> Label:
	_level_hint = _make_label("", FONT_SIZE_CARD_SMALL, SpikeConfig.C_TEXT_DIM)
	return _level_hint


## 選關列底下那行說明。三種狀態各一句**完整模板** ＋ format，不用字串拼接組句
## （i18n 條款，見 ../HANDOFF.md「未動工但已有定論」第 5 條：日文／印尼文語序不同）。
func _level_hint_text() -> String:
	var idx: int = SpikeSave.selected_level
	if SpikeSave.endless_mode:
		return "無盡模式：用%s的環境一路往上，沒有終點" % SpikeConfig.level_name(idx)
	var best := SpikeSave.best_time_of_level(idx, SpikeSave.extreme_mode)
	if best == SpikeSave.NO_TIME_RECORD:
		return "目標 %d m　·　尚未通關" % int(SpikeConfig.level_goal(idx))
	return "目標 %d m　·　最佳 %s" % [int(SpikeConfig.level_goal(idx)), _format_time(best)]


## 選關列的狀態同步。呼叫時機同 refresh_toggles（進主頁、以及按下任何一顆之後），
## 另外無盡開關也會叫它——那行說明會跟著模式換句子。
func refresh_levels() -> void:
	for i in range(_level_buttons.size()):
		var b: Button = _level_buttons[i]["button"]
		var sb: StyleBoxFlat = _level_buttons[i]["style"]
		var unlocked: bool = SpikeSave.is_level_unlocked(i)
		var chosen: bool = unlocked and SpikeSave.selected_level == i
		b.disabled = not unlocked
		b.text = "%s　%d m" % [SpikeConfig.level_name(i), int(SpikeConfig.level_goal(i))] \
			if unlocked else "？？？"
		sb.bg_color = Color(SpikeConfig.C_GOAL, 0.30) if chosen else SpikeConfig.C_PANEL
		if not unlocked:
			sb.border_color = SpikeConfig.C_CARD_LOCKED
		else:
			sb.border_color = SpikeConfig.C_GOAL if chosen else SpikeConfig.C_PANEL_EDGE
		var fc: Color = SpikeConfig.C_TEXT if unlocked else SpikeConfig.C_TEXT_DIM
		# 四個字色都要 override：只設 font_color 的話 hover／disabled 會掉回主題預設，
		# 滑過去字就變色，那又變成第二個視覺變數。
		b.add_theme_color_override("font_color", fc)
		b.add_theme_color_override("font_hover_color", fc)
		b.add_theme_color_override("font_pressed_color", fc)
		b.add_theme_color_override("font_disabled_color", SpikeConfig.C_TEXT_DIM)
	_level_hint.text = _level_hint_text()


## 一顆方形開關 icon。回傳 {node, button, style, glyph, caption}——refresh_toggles 靠
## style（底色／邊框）與 glyph 的顏色表達開關，不靠另外一顆勾勾。
##
## ⚠ normal / hover / pressed 三個 stylebox 都指同一份：開關狀態必須是**唯一**的視覺變數。
##   留著預設的 hover 高亮會讓「滑過去」看起來像「已開啟」。
func _make_toggle_icon(glyph_text: String) -> Dictionary:
	var b := Button.new()
	b.custom_minimum_size = TOGGLE_ICON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)

	var g := _make_label(glyph_text, FONT_SIZE_SUBTITLE, SpikeConfig.C_TEXT)
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(g)

	var cap := _make_label("", FONT_SIZE_CARD_SMALL, SpikeConfig.C_TEXT_DIM)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(b)
	box.add_child(cap)
	return {"node": box, "button": b, "style": sb, "glyph": g, "caption": cap}


## 「成就」按鈕右上角的紅色驚嘆號，貼齊按鈕外角、預設隱藏。
func _make_notif_dot() -> Control:
	var dot := Control.new()
	dot.custom_minimum_size = ACH_NOTIF_DOT_SIZE
	# 錨點釘在按鈕右上角、offset 用像素位移讓它一半蓋在按鈕內一半探出去——
	# 用 offset 而不是 position，才不會被建構當下（父節點還沒排版完）的暫時尺寸誤導。
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	dot.anchor_top = 0.0
	dot.anchor_bottom = 0.0
	dot.offset_left = -ACH_NOTIF_DOT_SIZE.x * 0.5
	dot.offset_right = ACH_NOTIF_DOT_SIZE.x * 0.5
	dot.offset_top = -ACH_NOTIF_DOT_SIZE.y * 0.5
	dot.offset_bottom = ACH_NOTIF_DOT_SIZE.y * 0.5
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.visible = false

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = SpikeConfig.C_STEAL_WARN
	sb.set_corner_radius_all(int(ACH_NOTIF_DOT_SIZE.x * 0.5))
	bg.add_theme_stylebox_override("panel", sb)
	dot.add_child(bg)

	var mark := _make_label("!", FONT_SIZE_CARD_SMALL, Color(1.0, 1.0, 1.0))
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_child(mark)

	return dot


## 有沒有「已解鎖未領獎」的成就——跟 refresh_toggles 同一批呼叫時機（進主頁時）。
func refresh_ach_badge() -> void:
	_ach_notif_dot.visible = SpikeSave.has_claimable_achievement()


## 兩顆開關 icon 的狀態同步（進主頁時、以及每次點下去之後）。
## ⚠ 攀爬手套沒買就整顆隱藏，不是 disabled——買了才存在的東西不該先擺一顆灰的在那裡。
func refresh_toggles() -> void:
	_apply_toggle(
		_extreme_icon, SpikeSave.extreme_mode, SpikeConfig.C_EXTREME,
		"極限 ON" if SpikeSave.extreme_mode else "極限 OFF"
	)
	_apply_toggle(
		_endless_icon, SpikeSave.endless_mode, SpikeConfig.C_DOOM_RING,
		"無盡 ON" if SpikeSave.endless_mode else "無盡 OFF"
	)
	var owned := SpikeSave.level_of("ledge") > 0
	_ledge_icon["node"].visible = owned
	if owned:
		_apply_toggle(
			_ledge_icon, SpikeSave.ledge_enabled, SpikeConfig.C_ACCENT,
			"手套 ON" if SpikeSave.ledge_enabled else "手套 OFF"
		)


## 開＝彩色邊框＋亮字；關＝暗框暗字。兩顆 icon 共用這一段，配色只差 on_color。
func _apply_toggle(icon: Dictionary, on: bool, on_color: Color, caption: String) -> void:
	var sb: StyleBoxFlat = icon["style"]
	sb.bg_color = Color(on_color, 0.30) if on else SpikeConfig.C_PANEL
	sb.border_color = on_color if on else SpikeConfig.C_CARD_LOCKED
	var g: Label = icon["glyph"]
	g.add_theme_color_override("font_color", SpikeConfig.C_TEXT if on else SpikeConfig.C_TEXT_DIM)
	var cap: Label = icon["caption"]
	cap.text = caption
	cap.add_theme_color_override("font_color", on_color if on else SpikeConfig.C_TEXT_DIM)

# ============================================================
# 建構：商店
# ============================================================
# PILLARS_2.md:413「升級＝加速，不是必需」：所以這裡是一張有限清單（每項固定級數上限），
# 不是無限成長曲線。買不起／已滿級的卡片 disabled，不做「點下去才說你沒錢」。
#
# 版面（使用者指定）：卡片水平並排，**點卡片本身就是購買**，沒有獨立的購買按鈕。

func _build_shop_panel() -> Control:
	var panel := _make_page("ShopPanel")

	var badge := _make_coin_badge()
	_shop_coin_label = badge["label"]
	panel.add_child(badge["node"])

	var title_band := _make_band(0.04, 0.22)
	title_band.add_child(_center_of(
		_make_label("SHOP", FONT_SIZE_TITLE, SpikeConfig.C_TEXT)
	))
	panel.add_child(title_band)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	for key in SpikeConfig.UPGRADE_ORDER:
		row.add_child(_build_shop_card(key))

	var card_band := _make_band(0.24, 0.80)
	card_band.add_child(_center_of(row))
	panel.add_child(card_band)

	var back_button := _make_button("返回")
	back_button.pressed.connect(func() -> void: shop_back_pressed.emit())
	var back_band := _make_band(0.82, 0.98)
	back_band.add_child(_center_of(back_button))
	panel.add_child(back_band)

	return panel


## 一張卡 = 一顆 Button（整張可點）＋ 疊在上面的 VBox 內容。
## 內容全部 MOUSE_FILTER_IGNORE，點擊才會穿到底下的 Button。
func _build_shop_card(key: String) -> Control:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.pressed.connect(func() -> void: _on_buy(key))

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := ColorRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	icon.color = SpikeConfig.UPGRADE_ICON_COLOR.get(key, SpikeConfig.C_ACCENT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)

	var name_label := _make_label(
		String(SpikeConfig.UPGRADE_TABLE[key]["name"]), FONT_SIZE_CARD_NAME, SpikeConfig.C_TEXT
	)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name_label)

	var level_label := _make_label("", FONT_SIZE_CARD_SMALL, SpikeConfig.C_ACCENT)
	content.add_child(level_label)

	var value_label := _make_label("", FONT_SIZE_CARD_SMALL, SpikeConfig.C_TEXT_DIM)
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(value_label)

	# 價格推到卡片底部：中間塞一個會擴張的空 Control
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)

	var cost_label := _make_label("", FONT_SIZE_CARD_NAME, SpikeConfig.C_PICKUP)
	content.add_child(cost_label)

	card.add_child(content)

	_shop_cards[key] = {
		"button": card, "icon": icon, "level": level_label,
		"value": value_label, "cost": cost_label,
	}
	return card


func _on_buy(key: String) -> void:
	if SpikeSave.buy(key):
		refresh_shop()


func refresh_shop() -> void:
	_shop_coin_label.text = "%d" % SpikeSave.coins
	for key in SpikeConfig.UPGRADE_ORDER:
		var c: Dictionary = _shop_cards[key]
		var lv := SpikeSave.level_of(key)
		var mx := SpikeSave.max_level(key)

		var level_label: Label = c["level"]
		level_label.text = "%s  %d/%d" % [_level_pips(lv, mx), lv, mx]

		var value_label: Label = c["value"]
		value_label.text = SpikeSave.current_value_label(key)

		var cost_label: Label = c["cost"]
		var button: Button = c["button"]
		var icon: ColorRect = c["icon"]
		if SpikeSave.is_maxed(key):
			cost_label.text = "已滿級"
			button.disabled = true
			icon.color = SpikeConfig.UPGRADE_ICON_COLOR.get(key, SpikeConfig.C_ACCENT)
		else:
			cost_label.text = "$ %d" % SpikeSave.cost_of(key)
			var afford := SpikeSave.can_afford(key)
			button.disabled = not afford
			# 買不起時色塊轉暗：卡片自己就說得出「現在不能買」，不用等玩家點下去
			icon.color = SpikeConfig.UPGRADE_ICON_COLOR.get(key, SpikeConfig.C_ACCENT) \
				if afford else SpikeConfig.C_CARD_LOCKED


func _level_pips(level: int, max_level: int) -> String:
	var s := ""
	for i in range(max_level):
		s += "●" if i < level else "○"
	return s

# ============================================================
# 建構：成就
# ============================================================
# 版面照商店（卡片並排、**點卡片本身就是動作**、沒有獨立按鈕），只是 9 張放不成一排，
# 改成 5 列 × 2 行的 GridContainer。
#
# 三態的視覺（對應 SpikeSave 的 ST_*）：
#   未解鎖   整張半透明、色塊轉暗、按鈕 disabled ——「還沒拿到」一眼看得出來
#   已解鎖   全亮、可點，狀態行寫「點擊領取 +N」
#   已領獎   全亮、不可點，狀態行寫「已領取」
# ⚠ 未解鎖用半透明**而不是**把條件文字藏起來：條件本身就是玩家該看的目標。

func _build_achievements_panel() -> Control:
	var panel := _make_page("AchievementsPanel")

	var badge := _make_coin_badge()
	_ach_coin_label = badge["label"]
	panel.add_child(badge["node"])

	var title_band := _make_band(0.02, 0.16)
	title_band.add_child(_center_of(
		_make_label("ACHIEVEMENTS", FONT_SIZE_TITLE, SpikeConfig.C_TEXT)
	))
	panel.add_child(title_band)

	var grid := GridContainer.new()
	grid.columns = ACH_COLS
	grid.add_theme_constant_override("h_separation", ACH_CARD_GAP)
	grid.add_theme_constant_override("v_separation", ACH_CARD_GAP)
	for slot_key in SpikeConfig.ACHIEVEMENT_SLOTS:
		grid.add_child(_build_achievement_card(slot_key))

	var card_band := _make_band(ACH_BAND_TOP, ACH_BAND_BOTTOM)
	card_band.add_child(_center_of(grid))
	panel.add_child(card_band)

	var back_button := _make_button("返回")
	back_button.pressed.connect(func() -> void: achievements_back_pressed.emit())
	# ⚠ 下緣收在 0.97：0.99 會讓按鈕（58px 高）撐出 PAGE_MARGIN 的圓角外框之外。
	var back_band := _make_band(ACH_BAND_BOTTOM, ACH_BACK_BAND_BOTTOM)
	back_band.add_child(_center_of(back_button))
	panel.add_child(back_band)

	return panel


## 一張成就卡 = 一顆 Button（整張可點＝領獎）＋ 疊在上面的 VBox 內容，同商店卡的做法。
## slot_key 是版位（見 ACHIEVEMENT_SLOTS），不是 leaf id：階梯成就（v15）三階共用同一個
## slot，點下去當下才問 SpikeSave.current_tier_id() 該領哪一個 id，不能在建構時就寫死——
## 領完 I 之後同一張卡片要能點到 II，绑死的話卡片點了也只會一直領（或領不到）同一階。
func _build_achievement_card(slot_key: String) -> Control:
	var row: Dictionary = SpikeConfig.ACHIEVEMENT_TABLE[SpikeSave.current_tier_id(slot_key)]

	var card := Button.new()
	card.custom_minimum_size = ACH_CARD_SIZE
	card.pressed.connect(func() -> void: _on_claim(SpikeSave.current_tier_id(slot_key)))

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# icon：色塊 ＋ 中央一個字（placeholder 美術，不引入資源檔）
	var icon := ColorRect.new()
	icon.custom_minimum_size = ACH_ICON_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var glyph := _make_label(String(row["glyph"]), FONT_SIZE_SECTION, SpikeConfig.C_BG)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_child(glyph)
	content.add_child(icon)

	var name_label := _make_label(String(row["name"]), FONT_SIZE_CARD_NAME, SpikeConfig.C_TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name_label)

	var cond_label := _make_label(String(row["cond"]), FONT_SIZE_CARD_SMALL, SpikeConfig.C_TEXT_DIM)
	cond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(cond_label)

	# 狀態推到卡片底部（同商店卡的價格）
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)

	var status_label := _make_label("", FONT_SIZE_CARD_SMALL, SpikeConfig.C_PICKUP)
	content.add_child(status_label)

	card.add_child(content)

	_ach_cards[slot_key] = {
		"button": card, "icon": icon, "glyph": glyph,
		"name": name_label, "cond": cond_label, "status": status_label,
	}
	return card


## 點卡片＝領獎。⚠ 入帳與狀態轉移全在 SpikeSave.claim_achievement()，這裡只負責重畫：
##   未解鎖／已領過時它回 false，不會給錢也不會扣狀態，所以連判斷都不必寫在 UI。
func _on_claim(id: String) -> void:
	if SpikeSave.claim_achievement(id):
		refresh_achievements()


## slot_key 迴圈，不是 leaf id：階梯成就（v15）先問 current_tier_id() 該顯示哪一階，
## 再把那一階的 name／cond／reward 寫回卡片——同一張卡片，領完低階內容會換成高階。
func refresh_achievements() -> void:
	_ach_coin_label.text = "%d" % SpikeSave.coins
	for slot_key in SpikeConfig.ACHIEVEMENT_SLOTS:
		var id := SpikeSave.current_tier_id(slot_key)
		var row: Dictionary = SpikeConfig.ACHIEVEMENT_TABLE[id]
		var c: Dictionary = _ach_cards[slot_key]
		var st := SpikeSave.ach_state(id)
		var button: Button = c["button"]
		var icon: ColorRect = c["icon"]
		var status: Label = c["status"]
		var base: Color = SpikeConfig.ACHIEVEMENT_ICON_COLOR.get(slot_key, SpikeConfig.C_ACCENT)
		var reward := int(row.get("reward", SpikeConfig.ACHIEVEMENT_COIN_REWARD))

		var name_label: Label = c["name"]
		name_label.text = String(row["name"])
		var cond_label: Label = c["cond"]
		cond_label.text = String(row["cond"])

		match st:
			SpikeSave.ST_UNLOCKED:
				button.disabled = false
				button.modulate = Color(1.0, 1.0, 1.0, 1.0)
				icon.color = base
				status.text = "點擊領取 +%d" % reward
				status.add_theme_color_override("font_color", SpikeConfig.C_PICKUP)
			SpikeSave.ST_CLAIMED:
				button.disabled = true
				button.modulate = Color(1.0, 1.0, 1.0, 1.0)
				icon.color = base
				status.text = "已領取"
				status.add_theme_color_override("font_color", SpikeConfig.C_OK)
			_:
				# 未解鎖：整張半透明（modulate 一次搞定全部子節點，不必逐個染色）
				button.disabled = true
				button.modulate = Color(1.0, 1.0, 1.0, 0.45)
				icon.color = SpikeConfig.C_CARD_LOCKED
				status.text = "未解鎖"
				status.add_theme_color_override("font_color", SpikeConfig.C_TEXT_DIM)

# ============================================================
# 成就解鎖橫幅
# ============================================================
# 使用者規格：達成當下在上方橫幅顯示 icon、名稱、解鎖條件，出現 3s 後淡出。
#
# ⚠ 一次解鎖多個就排隊逐一播，**不疊在同一條橫幅上**：三個名稱塞進一條的話玩家只會
#   看到一團字，而且第三個成就是誰完全記不住。
# ⚠ 橫幅 MOUSE_FILTER_IGNORE 全開：它蓋在畫面上緣，會擋住底下頁面的按鈕。

func _build_banner() -> Control:
	var wrap := Control.new()
	wrap.name = "AchievementBanner"
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.visible = false

	var frame := Panel.new()
	frame.custom_minimum_size = BANNER_SIZE
	frame.size = BANNER_SIZE
	frame.position = Vector2((SpikeConfig.VIEW_W - BANNER_SIZE.x) * 0.5, BANNER_TOP)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = SpikeConfig.C_PANEL
	sb.border_color = SpikeConfig.C_GOAL
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", sb)
	wrap.add_child(frame)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_banner_icon = ColorRect.new()
	_banner_icon.custom_minimum_size = BANNER_ICON_SIZE
	_banner_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_banner_glyph = _make_label("", FONT_SIZE_SUBTITLE, SpikeConfig.C_BG)
	_banner_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_icon.add_child(_banner_glyph)
	row.add_child(_banner_icon)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_name = _make_label("", FONT_SIZE_SUBTITLE, SpikeConfig.C_GOAL)
	_banner_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(_banner_name)
	_banner_cond = _make_label("", FONT_SIZE_CARD_SMALL, SpikeConfig.C_TEXT_DIM)
	_banner_cond.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(_banner_cond)
	row.add_child(texts)

	frame.add_child(row)
	return wrap


## main.gd 的兩條解鎖路徑（局中的 world 訊號、結算的 report_run_end）都走這裡。
func queue_achievement_banners(ids: Array) -> void:
	for id in ids:
		if SpikeConfig.ACHIEVEMENT_TABLE.has(id):
			_banner_queue.append(id)
	if not _banner.visible:
		_advance_banner()


## 拉下一個成就上台；佇列空了就收工。
func _advance_banner() -> void:
	if _banner_queue.is_empty():
		_banner.visible = false
		return
	var id: String = _banner_queue.pop_front()
	var row: Dictionary = SpikeConfig.ACHIEVEMENT_TABLE[id]
	_banner_glyph.text = String(row["glyph"])
	_banner_name.text = String(row["name"])
	_banner_cond.text = String(row["cond"])
	_banner_icon.color = SpikeConfig.ACHIEVEMENT_ICON_COLOR.get(id, SpikeConfig.C_ACCENT)
	_banner_timer = 0.0
	_banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_banner.visible = true


## ⚠ 走 _process 而不是 Tween：本層 process_mode 是 ALWAYS，所以暫停中橫幅也演得完。
##   Tween 預設吃 tree paused，一按暫停就會卡在半透明。
## ⚠ delta 直接用引擎給的：瞄準慢動作會把 delta 縮小，橫幅因此在慢動作中演得比較久——
##   那是對的，玩家在慢動作裡看東西的時間感也一起被拉長了。
func _process(delta: float) -> void:
	_tick_result_slide(delta)
	if not _banner.visible:
		return
	_banner_timer += delta
	var fade_from := BANNER_SHOW_TIME - BANNER_FADE_TIME
	if _banner_timer >= BANNER_SHOW_TIME:
		_advance_banner()
	elif _banner_timer > fade_from:
		_banner.modulate = Color(
			1.0, 1.0, 1.0, 1.0 - (_banner_timer - fade_from) / BANNER_FADE_TIME
		)

# ============================================================
# 建構：設定
# ============================================================

func _build_settings_panel() -> Control:
	var panel := _make_page("SettingsPanel")

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_make_label("設定", FONT_SIZE_SECTION, SpikeConfig.C_TEXT))
	box.add_child(_make_label(
		"點右邊的按鈕，再按下想改成的鍵。射出鞭子固定是滑鼠左鍵。",
		FONT_SIZE_HUD_SMALL, SpikeConfig.C_TEXT_DIM
	))

	for action in SpikeConfig.KEY_ORDER:
		box.add_child(_build_key_row(action))

	box.add_child(_build_save_code_block())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var reset_button := _make_button("恢復預設")
	reset_button.custom_minimum_size = KEYROW_BUTTON_SIZE
	reset_button.pressed.connect(func() -> void:
		_cancel_capture()
		SpikeKeys.reset_defaults()
		refresh_settings()
	)
	buttons.add_child(reset_button)
	var back_button := _make_button("返回")
	back_button.custom_minimum_size = KEYROW_BUTTON_SIZE
	back_button.pressed.connect(func() -> void: settings_back_pressed.emit())
	buttons.add_child(back_button)
	box.add_child(buttons)

	var band := _make_band(0.03, 0.97)
	band.add_child(_center_of(box))
	panel.add_child(band)

	return panel


## 存檔匯出／匯入（v17，使用者要求「順手補」）。itch.io 免費方案沒有雲端存檔，
## Web 版的 user:// 只落在瀏覽器 IndexedDB——玩家清一次瀏覽器資料進度就沒了，
## 這串碼是他唯一的備份手段。
## ⚠ 這**不是防作弊機制**。碼裡的校驗只擋「貼錯／少複製一段／隨手改幾個字」，
##   鹽值就在 client code 裡，而且玩家本來就能直接改 IndexedDB。理由見
##   SpikeSave.export_code 的 ⚠⚠，別在文案裡宣稱它安全。
func _build_save_code_block() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(_make_label(
		"存檔備份：按「匯出」產生一串碼，整段複製保存；換裝置時貼回來按「匯入」。",
		FONT_SIZE_HUD_SMALL, SpikeConfig.C_TEXT_DIM
	))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	_save_code_edit = LineEdit.new()
	_save_code_edit.custom_minimum_size = Vector2(SAVE_CODE_EDIT_WIDTH, 0.0)
	_save_code_edit.placeholder_text = "在這裡貼上存檔碼"
	# ⚠ LineEdit 不吃 _make_label 那條路，字型要自己掛，否則 Web 版的中文提示是豆腐方塊
	_save_code_edit.add_theme_font_override("font", shared_font())
	_save_code_edit.add_theme_font_size_override("font_size", FONT_SIZE_CARD_SMALL)
	row.add_child(_save_code_edit)

	var export_button := _make_button("匯出")
	export_button.custom_minimum_size = SAVE_CODE_BUTTON_SIZE
	export_button.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	export_button.pressed.connect(func() -> void:
		_save_code_edit.text = SpikeSave.export_code()
		_save_code_edit.grab_focus()
		_save_code_edit.select_all()
		# 順手送一份到剪貼簿。Web 版寫剪貼簿要有使用者手勢，而「按下按鈕」本身就是手勢，
		# 所以這條在瀏覽器裡也成立；真的失敗也無所謂——碼已經在框裡選起來了。
		DisplayServer.clipboard_set(_save_code_edit.text)
		_set_save_msg("已產生存檔碼並複製，請整段貼到安全的地方。", SpikeConfig.C_TEXT_DIM)
	)
	row.add_child(export_button)

	var import_button := _make_button("匯入")
	import_button.custom_minimum_size = SAVE_CODE_BUTTON_SIZE
	import_button.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	import_button.pressed.connect(func() -> void:
		var res: Dictionary = SpikeSave.import_code(_save_code_edit.text)
		var ok: bool = res["ok"]
		_set_save_msg(
			String(res["reason"]),
			SpikeConfig.C_GOAL if ok else SpikeConfig.C_STEAL_WARN
		)
	)
	row.add_child(import_button)

	col.add_child(row)

	_save_code_msg = _make_label("", FONT_SIZE_HUD_SMALL, SpikeConfig.C_TEXT_DIM)
	col.add_child(_save_code_msg)
	return col


## 進設定頁時把上一次留下的碼與訊息清掉：那串碼等於一整份存檔，
## 沒有理由在玩家離開又回來之後還掛在畫面上。
func _reset_save_code_ui() -> void:
	if _save_code_edit == null:
		return
	_save_code_edit.text = ""
	_set_save_msg("", SpikeConfig.C_TEXT_DIM)


func _set_save_msg(text: String, color: Color) -> void:
	_save_code_msg.text = text
	_save_code_msg.add_theme_color_override("font_color", color)


func _build_key_row(action: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var name_label := _make_label(
		String(SpikeConfig.KEY_NAMES.get(action, action)), FONT_SIZE_BODY, SpikeConfig.C_TEXT
	)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.custom_minimum_size = Vector2(KEYROW_LABEL_WIDTH, 0.0)
	row.add_child(name_label)

	var b := _make_button("")
	b.custom_minimum_size = KEYROW_BUTTON_SIZE
	b.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	b.pressed.connect(func() -> void:
		_capturing_action = action
		refresh_settings()
	)
	row.add_child(b)

	_key_buttons[action] = b
	return row


func refresh_settings() -> void:
	for action in SpikeConfig.KEY_ORDER:
		var b: Button = _key_buttons[action]
		if action == _capturing_action:
			b.text = "按下新的鍵…"
		else:
			b.text = SpikeKeys.label_of(action)

# ============================================================
# 建構：暫停 / 結算
# ============================================================

func _build_paused_panel() -> Control:
	var panel := Control.new()
	panel.name = "PausedPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 半透明黑底：直接引用 C_BG，只改 alpha（不是新的顏色字面值），
	# 讓底下仍可見的 HUD 透出來。
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(SpikeConfig.C_BG, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(_make_label("暫停", FONT_SIZE_SECTION, SpikeConfig.C_TEXT))

	var resume_button := _make_button("繼續")
	resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(resume_button)

	var restart_button := _make_button("重新開始")
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(restart_button)

	var quit_button := _make_button("離開")
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())
	box.add_child(quit_button)

	center.add_child(box)

	return panel


## GAMEOVER 與 CLEAR 版面完全相同（標題 + 結算文字 + 兩顆按鈕），共用一份建構邏輯。
##
## v17 起**不再是一整頁**（使用者拍板）：背景保留死掉那一刻的遊戲畫面（只壓暗），
## 資訊裝進一張佔畫面 RESULT_CARD_RATIO 的小卡、由下往上推進來。
## ⚠ 底不能再用 _make_page 的不透明底色蓋掉——「我死在哪裡、旁邊有什麼」是玩家最後、
##   也是唯一的歸因線索，蓋掉等於把死因全部押在結算那一行文字上。
## ⚠ 滑入位移一律走 offset_top/offset_bottom，不要改 position：卡片是用 anchor 定位的，
##   position 會在下一次排版被 anchor 算出來的值蓋掉，看起來就像動畫沒生效。
func _build_result_panel(title_text: String, title_color: Color) -> Dictionary:
	var panel := Control.new()
	panel.name = "ResultPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 壓暗層要 MOUSE_FILTER_STOP：底下的世界雖然已經不運算了，但點擊不擋住會穿過去
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(SpikeConfig.C_BG, SpikeConfig.RESULT_CARD_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(dim)

	var inset: float = (1.0 - SpikeConfig.RESULT_CARD_RATIO) * 0.5
	var card := Control.new()
	card.name = "Card"
	card.anchor_left = inset
	card.anchor_right = 1.0 - inset
	card.anchor_top = inset
	card.anchor_bottom = 1.0 - inset
	card.offset_left = 0.0
	card.offset_right = 0.0
	card.offset_top = 0.0
	card.offset_bottom = 0.0
	panel.add_child(card)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = SpikeConfig.C_PANEL
	sb.border_color = SpikeConfig.C_PANEL_EDGE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	frame.add_theme_stylebox_override("panel", sb)
	card.add_child(frame)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(_make_label(title_text, FONT_SIZE_RESULT_TITLE, title_color))

	var result_label := _make_label("", FONT_SIZE_RESULT_BODY, SpikeConfig.C_TEXT)
	box.add_child(result_label)

	# 劇情佔位／解鎖通知（08-10，只有登頂頁用得到）。
	# ⚠ 刻意**另開一顆小字 Label** 而不是接在 result_label 後面：接上去的話這兩行會吃
	#   FONT_SIZE_RESULT_BODY 的行高，卡片一次多 84px，「回標題」按鈕的下緣就被圓角外框
	#   切掉（實測發生過，跟成就頁「返回」被切那次同一個坑）。
	# ⚠ 空字串時要 visible = false，不然 Label 仍佔一整行高度。
	var story_label := _make_label("", FONT_SIZE_CARD_SMALL, SpikeConfig.C_GOAL)
	story_label.visible = false
	box.add_child(story_label)

	var restart_button := _make_button("再爬一次")
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(restart_button)

	var quit_button := _make_button("回標題")
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())
	box.add_child(quit_button)

	center.add_child(box)

	_result_cards.append({"card": card, "dim": dim})
	# box 一併回傳給 tests/audit_ui.gd 量 get_combined_minimum_size()——
	# 「內容塞不塞得進卡片」用實際字型度量算，不靠一份會過期的行數常數。
	return {
		"panel": panel, "result_label": result_label,
		"story_label": story_label, "box": box, "card": card,
	}


## 每次進結算頁重新推一次。⚠ 一定要立刻把 t=0 的位置套上去：等下一幀的 _process 才套的話，
## 卡片會先在定位閃現一幀再跳到畫面外，看起來像畫面破圖。
func _begin_result_slide() -> void:
	_slide_t = 0.0
	_slide_active = true
	_apply_result_slide(0.0)


func _tick_result_slide(delta: float) -> void:
	if not _slide_active:
		return
	_slide_t += delta
	var t: float = clampf(_slide_t / SpikeConfig.RESULT_CARD_SLIDE_TIME, 0.0, 1.0)
	_apply_result_slide(t)
	if t >= 1.0:
		_slide_active = false


## t=0 在畫面外、t=1 就定位。ease-out（三次方）而不是等速：等速滑入看起來像被拖著走，
## 尾段慢下來才有「推上來停住」的重量感。壓暗層跟著同一條曲線淡入，兩者分開演會脫節。
func _apply_result_slide(t: float) -> void:
	var e: float = 1.0 - pow(1.0 - t, 3.0)
	var off: float = (1.0 - e) * SpikeConfig.VIEW_H
	for c in _result_cards:
		var card: Control = c["card"]
		card.offset_top = off
		card.offset_bottom = off
		var dim: ColorRect = c["dim"]
		dim.color = Color(SpikeConfig.C_BG, SpikeConfig.RESULT_CARD_DIM_ALPHA * e)

# ============================================================
# 共用工廠 / 小工具
# ============================================================

## 一頁的底：不透明底色 ＋ 一圈圓角外框（對應使用者給的版面草圖）。
## 底色必須 MOUSE_FILTER_STOP，不然點擊會穿到底下還在跑的世界。
func _make_page(node_name: String) -> Control:
	var panel := Control.new()
	panel.name = node_name
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = SpikeConfig.C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(bg)

	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PAGE_MARGIN
	)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = SpikeConfig.C_PANEL
	sb.border_color = SpikeConfig.C_PANEL_EDGE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	frame.add_theme_stylebox_override("panel", sb)
	panel.add_child(frame)

	return panel


## 一條佔滿寬度、上下用比例定位的橫帶。用比例而不是絕對 y：
## 視窗放大時（stretch=canvas_items/keep）版面才會跟著等比移動。
func _make_band(top_ratio: float, bottom_ratio: float) -> Control:
	var band := Control.new()
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = top_ratio
	band.anchor_bottom = bottom_ratio
	band.offset_left = 0.0
	band.offset_right = 0.0
	band.offset_top = 0.0
	band.offset_bottom = 0.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return band


## 把一個節點包進撐滿父層的 CenterContainer。
## ⚠ 用 CenterContainer 而不是手動 anchors_preset(CENTER)：後者在容器尚未跑完排版、
##   尺寸仍是 0 時就把置中錨點釘死在左上角，之後撐開會整塊往右下偏。
func _center_of(node: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(node)
	return center


## 左上角的金幣徽章：方框「錢」＋ 數字。回傳 {node, label}。
func _make_coin_badge() -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", BADGE_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := Panel.new()
	box.custom_minimum_size = BADGE_BOX_SIZE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = SpikeConfig.C_PANEL
	sb.border_color = SpikeConfig.C_ACCENT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	box.add_theme_stylebox_override("panel", sb)

	var glyph := _make_label("錢", FONT_SIZE_SUBTITLE, SpikeConfig.C_PICKUP)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(glyph)
	row.add_child(box)

	var amount := _make_label("0", FONT_SIZE_HUD_BIG, SpikeConfig.C_PICKUP)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.custom_minimum_size = Vector2(0.0, BADGE_BOX_SIZE.y)
	row.add_child(amount)

	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(row)
	row.position = Vector2(PAGE_MARGIN + 20, PAGE_MARGIN + 20)

	return {"node": wrap, "label": amount}


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", shared_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", shared_font())
	b.add_theme_font_size_override("font_size", FONT_SIZE_BUTTON)
	b.custom_minimum_size = BUTTON_MIN_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	var m := total / 60
	var s := total % 60
	return "%d:%02d" % [m, s]
