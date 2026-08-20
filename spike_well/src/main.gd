extends Node2D
## 四個頁面的狀態機 ＋ 世界與 UI 的接線。這裡不碰遊戲邏輯。
##
## 頁面：START ⇄ SHOP，START → PLAYING ⇄ PAUSED → GAMEOVER / CLEAR → (重來 / 回標題)

const S_START := "START"
const S_SHOP := "SHOP"
const S_ACHIEVEMENTS := "ACHIEVEMENTS"
const S_SETTINGS := "SETTINGS"
const S_PLAYING := "PLAYING"
const S_PAUSED := "PAUSED"
const S_GAMEOVER := "GAMEOVER"
const S_CLEAR := "CLEAR"
## 教學關專用的簡化結算卡（08-13x）：只有「教學完成」＋金幣，一顆按鈕回主畫面——
## 跟正式的 S_CLEAR 分開一個狀態，不在共用的結算卡裡加一堆 if tutorial 判斷
## （最保守、最不侵入既有系統的做法，回報時列為偏離項）。
const S_TUTORIAL_CLEAR := "TUTORIAL_CLEAR"
## 08-13：滿版劇情（項目 9）與破關解鎖蒙版（項目 10）。兩者都是「蓋在流程中間、
## 看完才放行」的頁面，所以是狀態不是彈窗。
const S_STORY := "STORY"
const S_UNLOCK := "UNLOCK"
## 第一次進遊戲的裝置二選一頁（08-20 x）：跟 S_STORY／S_UNLOCK 同一組「蓋在流程
## 中間、選完才放行」頁面，見 _advance_to_title 的插入點。
const S_DEVICE_CHOICE := "DEVICE_CHOICE"

var world: WellWorld
var ui: SpikeUI
var state := S_START

## 還沒播的劇情 id（空字串＝沒有）與還沒播的解鎖卡（先進先出）。
## ⚠ 兩者刻意**留到玩家真的回主畫面**才播，不在結算頁上插隊：結算頁是「這一局怎麼樣」，
##   劇情與解鎖是「接下來有什麼」，混在同一頁玩家兩邊都讀不完。
## ⚠ 按「再玩一次」不會把它們清掉——欠玩家的東西不會因為他又跳進井裡就消失。
var _pending_story := ""
var _pending_unlocks: Array = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(SpikeConfig.C_BG)
	# 暫停時 UI 仍要能按，所以 Main 與 UI 都設 ALWAYS；World 維持 PAUSABLE
	process_mode = Node.PROCESS_MODE_ALWAYS

	world = WellWorld.new()
	world.name = "World"
	# 明確設 PAUSABLE：不設的話會繼承 Main 的 ALWAYS，get_tree().paused 對它就沒用，
	# 暫停時整個世界照跑（曾經真的是這樣）。
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.died.connect(_on_died)
	world.cleared.connect(_on_cleared)
	# 局中解鎖的成就：世界只負責通知，橫幅怎麼排隊怎麼淡出是 UI 的事
	world.achievement_unlocked.connect(_on_achievements_unlocked)

	ui = SpikeUI.new()
	ui.name = "UI"
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	ui.build()
	ui.start_pressed.connect(_start_run)
	ui.restart_pressed.connect(_start_run)
	ui.resume_pressed.connect(_resume)
	ui.quit_pressed.connect(_on_quit_pressed)
	ui.pause_pressed.connect(_on_pause_button_pressed)
	ui.shop_pressed.connect(_to_shop)
	ui.shop_back_pressed.connect(_to_title)
	ui.achievements_pressed.connect(_to_achievements)
	ui.achievements_back_pressed.connect(_to_title)
	ui.settings_pressed.connect(_to_settings)
	ui.settings_back_pressed.connect(_to_title)
	# 開發者傳送鈕。⚠ 訊號永遠接，按鈕本身在 dev_mode() 為假時根本不存在（見 SpikeUI._build_hud）
	# ——「有沒有這顆鈕」只由那一個地方決定，這裡不再判斷第二次。
	ui.dev_teleport_pressed.connect(_on_dev_teleport)
	ui.dev_coins_pressed.connect(_on_dev_coins)
	ui.dev_wipe_pressed.connect(_on_dev_wipe)
	# 觸控按鈕（08-20）：懷錶／道具是「點一下觸發一次」，UI 沒有 world 參照，
	# 訊號轉過來這裡才呼叫得到（同 dev_teleport_pressed 那套接法）。
	ui.touch_watch_pressed.connect(_on_touch_watch_pressed)
	ui.touch_item_pressed.connect(_on_touch_item_pressed)
	ui.touch_whip_pressed.connect(_on_touch_whip_pressed)
	ui.story_advanced.connect(_on_story_advanced)
	ui.unlock_dismissed.connect(_on_unlock_dismissed)
	# 第一次進遊戲的裝置二選一頁（08-20 x）：見 _advance_to_title 的插入點。
	ui.device_mode_chosen.connect(_on_device_mode_chosen)
	# 教學關簡化結算卡的唯一按鈕：回主畫面，走跟其他「回標題」入口同一條路
	# （劇情／解鎖蒙版仍照 _advance_to_title 的順序播，理論上教學關不會產生那些，
	# 但共用同一個入口比另開一條「這裡一定沒有待播內容」的捷徑更不容易出錯）。
	ui.tutorial_clear_pressed.connect(_to_title)
	# 教學關死亡卡的「跳過教學關」（08-14 使用者規格）：直接視同教學關已完成，
	# 走跟通關同一個 mark_tutorial_done()，否則 _advance_to_title 會在 tutorial_done
	# 還是 false 時把玩家重新送回教學關開頭（見 _advance_to_title 的判斷）。
	ui.tutorial_skip_pressed.connect(_on_tutorial_skip_pressed)

	# 第一次進入遊戲的劇情（08-13 項目 9）。⚠ 進標題頁**之前**播：它是開場，
	# 玩家不該先看到主選單再被拉回去看開場。
	_pending_story = SpikeConfig.STORY_INTRO_ID \
		if not SpikeSave.story_seen_of(SpikeConfig.STORY_INTRO_ID) else ""
	_advance_to_title()


func _process(_delta: float) -> void:
	if state == S_PLAYING or state == S_PAUSED:
		ui.update_hud(world.hud_data())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# 設定頁正在等玩家按新鍵時，這裡不能搶——否則玩家想把暫停綁到別的鍵永遠綁不成
	if ui.is_capturing_key():
		return
	# 子頁面的返回一律吃 ESC（不跟著暫停鍵走）：暫停鍵可以被玩家改掉，
	# 但「按 ESC 退出這一頁」是作業系統層級的肌肉記憶，不該被設定弄丟。
	# ⚠ 工作人員名單 08-18 四訂併進設定頁變成分頁（不再是獨立頁面），這裡不用再為它
	#   多寫一條「回設定頁」的特例——它現在跟按鍵設定／音量分頁一樣，ESC 直接回標題。
	if event.keycode == KEY_ESCAPE \
			and (state == S_SHOP or state == S_SETTINGS or state == S_ACHIEVEMENTS):
		_set_state(S_START)
		get_viewport().set_input_as_handled()
		return
	if event.keycode != SpikeKeys.key_of("pause"):
		return
	# 死亡演出那 0.55 秒不給暫停：暫停會把爆炸凍在半途，回來還得再看一次結局。
	if world.is_dying():
		get_viewport().set_input_as_handled()
		return
	if state == S_PLAYING:
		_set_state(S_PAUSED)
	elif state == S_PAUSED:
		_set_state(S_PLAYING)
	else:
		return
	get_viewport().set_input_as_handled()


func _set_state(next: String) -> void:
	state = next
	match next:
		S_PLAYING:
			get_tree().paused = false
			world.visible = true
			world.running = true
			SpikeAudio.stop_menu_bgm()
		S_PAUSED:
			# 暫停時強制收掉瞄準：否則 time_scale 會被凍在慢動作，回來後全域變慢
			world.force_cancel_aim()
			get_tree().paused = true
		S_START, S_SHOP, S_ACHIEVEMENTS, S_SETTINGS:
			get_tree().paused = false
			Engine.time_scale = 1.0
			world.running = false
			world.visible = false
			# 「主頁面」家族狀態：背景音樂唯一該播的地方。已經在播就不重觸發
			# （見 SpikeAudio.ensure_menu_bgm 的 ⚠），切換分頁不會聽起來像重新起播。
			SpikeAudio.ensure_menu_bgm()
			# 井裡的背景音樂（Cancan／DiesIrae）只在爬井時該響，離開 PLAYING 就要停
			# （不含 S_PAUSED——那條分支刻意不呼叫這個，暫停時音樂繼續播）。
			SpikeAudio.stop_gameplay_bgm()
		_:
			get_tree().paused = false
			Engine.time_scale = 1.0
			world.running = false
			world.visible = true
			# 涵蓋 GAMEOVER／CLEAR／STORY／UNLOCK／TUTORIAL_CLEAR／DEVICE_CHOICE：多數
			# 情況下音樂本來就沒在播（PLAYING 已經停過），但開發者洗檔會從 S_START 直接
			# 跳 S_STORY 重播開場劇情（見 _on_dev_wipe），那條路徑音樂確實還在播，
			# 這裡補一次停止。
			SpikeAudio.stop_menu_bgm()
			SpikeAudio.stop_gameplay_bgm()
	ui.show_screen(next)


func _start_run() -> void:
	get_tree().paused = false
	# 教學關（08-13x）：還沒通過教學關就一律進教學關，不管是第一次進遊戲、死掉重來、
	# 還是中途離開後回主畫面又按了「開始」——理由同 _advance_to_title 的判斷：教學關
	# 沒過完，正式局的入口都不該打開。world.tutorial_mode 是世界層唯一要知道的旗標，
	# 世界層本身不讀 SpikeSave（見 WellWorld.reset() 的 ⚠⚠）。
	# ⚠ 08-20 發佈開關（SpikeConfig.TUTORIAL_ENABLED）：關掉時前面那個 and 短路，
	# 不管存檔 tutorial_done 是不是 false 都直接進正式局，教學關程式碼與資料原封不動。
	world.tutorial_mode = SpikeConfig.TUTORIAL_ENABLED and not SpikeSave.tutorial_done
	world.reset()
	_set_state(S_PLAYING)
	# 井裡背景音樂固定從 Cancan 起播（不是隨機挑）：只掛在「真的開一局」這個入口，
	# 不是放進 _set_state(S_PLAYING) 分支——後者 _resume() 也會呼叫，暫停恢復不該
	# 把已經切到 DiesIrae 的音樂重置回 Cancan。
	SpikeAudio.start_gameplay_bgm()
	if world.tutorial_mode:
		# 教學關不算「開一局」：不記遊玩次數、不記種子（規格第 8 條，教學關只有
		# 金幣入帳）。
		return
	# 遊玩次數（kaela）：真正的「開一局」只有這一個入口。⚠ 不能放在 world.reset() 裡——
	# reset 也被 WellWorld._ready() 呼叫一次，放那裡光是開啟遊戲就先送一次。
	# 排在 _set_state 之後：橫幅要蓋在 PLAYING 的 HUD 上，不是蓋在標題頁上。
	var fresh := SpikeSave.report_run_start()
	if not fresh.is_empty():
		ui.queue_achievement_banners(fresh)
	# 這一局的井長什麼樣，全由這個 seed 決定。⚠ 要在 world.reset() 之後才問得到——
	# 生成器是在 reset() 裡新建並 randomize 的（見 WellGenerator.active_seed）。
	SpikeSave.record_run_seed(world.gen.active_seed())


func _resume() -> void:
	_set_state(S_PLAYING)


func _to_title() -> void:
	_advance_to_title()


## 右上角常駐暫停鈕（08-14）：跟暫停鍵同一條路，只在 PLAYING 生效——死亡演出那
## 0.55 秒不給暫停的規則（見 _unhandled_input 那條 ⚠）在這裡也要守一次，不然滑鼠
## 點按鈕能繞過鍵盤那邊擋的門檻。
func _on_pause_button_pressed() -> void:
	if state != S_PLAYING or world.is_dying():
		return
	_set_state(S_PAUSED)


## 暫停面板「離開」的統一入口（08-14 改）。教學關中途離開＝跳過教學關：不先標記
## 完成的話，回標題後再按「開始遊戲」仍會因為 tutorial_done 還是 false 被 _start_run
## 送回教學關開頭（見該函式的判斷），玩家永遠逃不出教學關。正式局離開不受影響，仍是回標題。
func _on_quit_pressed() -> void:
	if world.tutorial_mode:
		SpikeSave.mark_tutorial_done()
	_to_title()


## 教學關死亡卡「跳過教學關」鈕（08-14）：跟通關走同一個 mark_tutorial_done()，
## 理由同 _on_quit_pressed 那條 ⚠——教學關只有金幣入帳（規格第 8 條），跳過不該
## 額外補發任何東西，所以這裡不呼叫 _finish_tutorial 那一套。
func _on_tutorial_skip_pressed() -> void:
	SpikeSave.mark_tutorial_done()
	_to_title()


## 回主畫面的**唯一入口**（08-13）：先把欠玩家的劇情與解鎖卡播完，都播完了才真的進標題。
## ⚠ 順序是「劇情 → 解鎖卡 → 裝置二選一 → 標題」：劇情講的是「發生了什麼」，解鎖卡講的是
##   「你拿到了什麼」，倒過來播會先劇透獎勵；裝置二選一（08-20 x）刻意排在兩者之後——
##   使用者規格明講「開幕漫畫之後、進主畫面之前」，不是「開幕漫畫之前」，且它跟劇情/解鎖
##   無關，晚一點問不影響任何劇透疑慮。
## ⚠ 每一段播完都會再呼叫一次這裡（見 _on_story_advanced／_on_unlock_dismissed／
##   _on_device_mode_chosen），所以「還有沒有下一段」只在這一個地方判斷，不要在各自的
##   回呼裡再抄一次條件。
func _advance_to_title() -> void:
	if _pending_story != "":
		# intro 走真人漫畫四格（show_story_intro，滿版無文字），clear_0／clear_1 仍是
		# 佔位圖＋文字（show_story）——兩條路徑分岔在這裡，_on_story_advanced 收尾不用管
		# 播的是哪一種，兩邊最後都發同一個 story_advanced。
		if _pending_story == SpikeConfig.STORY_INTRO_ID:
			ui.show_story_intro()
			_set_state(S_STORY)
			return
		var text: String = SpikeConfig.story_text(_pending_story)
		# 認不得的 id（例如表被改過）就當作沒有這一段，不要卡在空白頁上
		if text != "":
			ui.show_story(text)
			_set_state(S_STORY)
			return
		_pending_story = ""
	if not _pending_unlocks.is_empty():
		ui.show_unlock(String(_pending_unlocks[0]))
		_set_state(S_UNLOCK)
		return
	# 裝置二選一（08-20 x）：SpikeSave.device_mode 還沒選過（""）才會走到這裡——玩家選過
	# 一次就永久記住，不會每次開遊戲都再問。舊版存檔（沒有這顆欄位）跟第一次進遊戲的新玩家
	# 共用同一個判斷式：兩者的 device_mode 讀出來都是空字串（見 SpikeSave._apply_save_dict）。
	if SpikeSave.device_mode == "":
		_set_state(S_DEVICE_CHOICE)
		return
	# 劇情／解鎖卡／裝置選擇都處理完了：一律先回標題，「開始遊戲」鈕本身會依
	# SpikeSave.tutorial_done 決定要不要走教學關（見 _start_run）。這裡不再自動跳過標題
	# 直接開局——玩家看完開場漫畫應該先看到主畫面，自己按下「開始遊戲」才進教學關
	# （09-XX 使用者規格改）。
	_set_state(S_START)


func _on_story_advanced() -> void:
	if state != S_STORY:
		return
	# ⚠ 播完當下就記進存檔：玩家看完劇情下一步很可能直接關掉遊戲。
	SpikeSave.mark_story_seen(_pending_story)
	_pending_story = ""
	_advance_to_title()


func _on_unlock_dismissed() -> void:
	if state != S_UNLOCK:
		return
	if not _pending_unlocks.is_empty():
		_pending_unlocks.remove_at(0)
	_advance_to_title()


## 裝置二選一頁的唯一按鈕出口（08-20 x）：寫進存檔（下次開遊戲不會再被問一次）之後
## 照 _advance_to_title 的既有慣例，交還給它判斷下一步（這裡一定是 S_START，但不在這裡
## 重複那個判斷——同 _on_story_advanced／_on_unlock_dismissed 那條 ⚠）。
func _on_device_mode_chosen(mode: String) -> void:
	if state != S_DEVICE_CHOICE:
		return
	SpikeSave.set_device_mode(mode)
	_advance_to_title()


func _to_shop() -> void:
	_set_state(S_SHOP)


func _to_achievements() -> void:
	_set_state(S_ACHIEVEMENTS)


func _on_achievements_unlocked(ids: Array) -> void:
	ui.queue_achievement_banners(ids)


func _to_settings() -> void:
	_set_state(S_SETTINGS)


## ⚠ 只在 PLAYING 生效：HUD 在 PAUSED 也看得見（按鈕跟著在），但暫停中搬玩家會讓
##   相機與物理在恢復那一幀對不上，而且「暫停時偷傳送」本來就不該是個功能。
func _on_dev_teleport() -> void:
	if state != S_PLAYING:
		return
	world.dev_teleport_up()


## 觸控懷錶二段跳鈕（08-20）。⚠ UI 的 _touch_controls 已經只在 S_PLAYING 才可見/可按
##   （見 SpikeUI.show_screen），這裡的 state 檢查是雙保險，同 _on_pause_button_pressed
##   那條 ⚠ 的理由——死亡演出那 0.55 秒也不該讓觸控鈕搶跳。
func _on_touch_watch_pressed() -> void:
	if state != S_PLAYING or world.is_dying():
		return
	world._try_watch_jump()


## 觸控道具鈕（08-20）。理由同 _on_touch_watch_pressed。
func _on_touch_item_pressed() -> void:
	if state != S_PLAYING or world.is_dying():
		return
	world.use_buff()


## 觸控鞭子鈕（08-20 x）。理由同 _on_touch_watch_pressed——world.touch_toggle_aim()
## 內部已經自己擋 running，這裡的 state／is_dying 檢查是同一套雙保險慣例。
func _on_touch_whip_pressed() -> void:
	if state != S_PLAYING or world.is_dying():
		return
	world.touch_toggle_aim()


## 開發者：直接加存檔金幣（08-13）。⚠ 加的是 SpikeSave.coins 不是 world.coin_count——
##   後者要等結算才入帳，而這顆鈕的用途是「馬上去商店買升級來測」。
func _on_dev_coins() -> void:
	SpikeSave.add_coins(SpikeConfig.DEV_COIN_GRANT)


## 開發者：洗掉所有紀錄，回到第一次進入遊戲的狀態（08-13）。
## ⚠ 洗完一定要回主頁：留在遊戲中的話，這一局仍掛著洗掉前的關卡與升級，之後的結算會
##   把「舊局的成績」寫回剛清空的存檔——那正是這顆鈕要避免的髒狀態。
## ⚠ 按鍵綁定**不洗**：那是設定不是進度，洗掉只會讓開發者每次重測都要重綁一次。
func _on_dev_wipe() -> void:
	SpikeSave.wipe()
	world.reset()
	# 洗掉存檔等於回到「第一次進入遊戲」，開場劇情要重新排進待播佇列——
	# _pending_story 只在 _ready() 判斷過一次，這裡不重設的話，wipe() 清掉的
	# story_seen 不會反映到這個變數，劇情就會被跳過（曾經真的是這樣）。
	_pending_story = SpikeConfig.STORY_INTRO_ID \
		if not SpikeSave.story_seen_of(SpikeConfig.STORY_INTRO_ID) else ""
	_pending_unlocks.clear()
	# 走 _advance_to_title 而不是直接 _set_state(S_START)：劇情／教學關的分流都在
	# 那個函式裡判斷，直接跳 S_START 會繞過它們（這正是這次修的 bug）。
	_advance_to_title()


func _on_died(cause: String) -> void:
	if state != S_PLAYING:
		return
	_finish(false, cause)


func _on_cleared() -> void:
	if state != S_PLAYING:
		return
	_finish(true, "")


func _finish(is_clear: bool, cause: String) -> void:
	if world.tutorial_mode:
		_finish_tutorial(is_clear, cause)
		return
	var d := world.result_data()
	# 先入帳再產結算文字：結算那行要印「累計 N」，順序顛倒會少算剛結束這一局。
	# 金幣摔死也保留（使用者指定），所以入帳不看 is_clear。
	SpikeSave.add_coins(int(d["coins"]))
	# 歷史最高高度：下一局的墓碑就立在這個高度（見 WellGenerator._maybe_place_tomb）。
	# ⚠ 必須在這裡記，不能在 reset() 記——reset 拿不到「上一局爬到哪」。
	# 回傳值＝這一局有沒有刷新該模式的最高高度，結算卡的「NEW」標記讀它（08-13 三訂）。
	# ⚠ 只能在這裡取：record_height 一寫進去，之後再問「有沒有破紀錄」永遠是 false。
	d["new_record"] = SpikeSave.record_height(float(d["best_m"]))
	# 最佳用時只有登頂才算數：半路摔死的秒數比的是「誰死得比較快」，不是成績。
	# 解鎖下一關也在這裡：is_clear 只有「有終點的模式抵達 goal_meters」才會是 true
	# （無盡模式的 cleared 永遠不 emit，見 WellWorld.cleared 的 ⚠），所以不必再判一次模式。
	# ⚠ d["unlocked"] 要在 set_result 之前算好——結算頁那行「已解鎖 XXX」讀的就是它。
	d["unlocked"] = false
	if is_clear:
		SpikeSave.record_clear_time(float(d["elapsed"]))
		# ⚠ 「這是不是第一次通這一關」要在 report_level_cleared **之前**問：那個函式會把
		#   cleared_max 推上去，問晚了永遠是 false，劇情與解鎖卡就一次都不會播。
		var level_idx := int(d["level"])
		var first_clear: bool = SpikeSave.cleared_max < level_idx
		d["unlocked"] = SpikeSave.report_level_cleared(level_idx)
		if first_clear:
			# 這一關該播的劇情（08-13 項目 9）。看過就不再播（存檔旗標）。
			var story_id: String = SpikeConfig.story_id_for_clear(level_idx)
			if story_id != "" and not SpikeSave.story_seen_of(story_id):
				_pending_story = story_id
			# 這一關送的東西（項目 10）。⚠ 清單的唯一的家是 SpikeConfig.UNLOCK_TABLE，
			#   不要在這裡另外寫「第二關給手套」這種條件。
			_pending_unlocks.append_array(SpikeConfig.unlocks_from_clearing(level_idx))
	d["cleared"] = is_clear
	d["cause"] = cause
	# 井底屍體堆（08-13 三訂）：死了才記，下一局開場就會多躺一具。
	# ⚠ 記在這裡而不是 WellWorld._die()：那裡是「爆炸開始」，玩家還可能在演出中關掉遊戲，
	#   而且世界層不讀 SpikeSave（狀態一律從外面灌進去，見 reset() 的 ⚠⚠）。
	if not is_clear:
		SpikeSave.record_corpse_death()

	# 成就的結算判定（登頂三連 ＋ 被投擲物砸死的累計）。⚠ 要在 add_coins 之後：
	# 領獎金幣走的是 claim_achievement 那條路，但這一局的金幣得先入帳，
	# 結算文字才印得出正確的「累計 N」。
	var fresh := SpikeSave.report_run_end(d)
	ui.set_result(d)
	_set_state(S_CLEAR if is_clear else S_GAMEOVER)
	# 橫幅排在切頁之後：結算頁蓋掉 HUD，但橫幅是獨立圖層，兩者不會互相遮
	if not fresh.is_empty():
		ui.queue_achievement_banners(fresh)


## 教學關的結算路徑（08-13x）：跟正式局的 _finish() 分開，理由是規格第 8 條
## 「只有金幣入帳」——不呼叫 record_height／record_clear_time／report_level_cleared／
## report_run_end／record_corpse_death，那幾個都會弄髒正式進度（最高高度、成就、
## 通關紀錄、關卡解鎖、井底屍體堆）。
func _finish_tutorial(is_clear: bool, cause: String) -> void:
	var d := world.result_data()
	SpikeSave.add_coins(int(d["coins"]))
	if is_clear:
		SpikeSave.mark_tutorial_done()
		ui.set_tutorial_clear_result(d)
		_set_state(S_TUTORIAL_CLEAR)
		return
	# 死亡立刻重來：結算卡只留「再試一次」（規格第 3 條，「回地下室」那顆藏起來，
	# 見 SpikeUI.set_result 的 tutorial 分支）。
	d["tutorial"] = true
	d["cleared"] = false
	d["cause"] = cause
	ui.set_result(d)
	_set_state(S_GAMEOVER)
