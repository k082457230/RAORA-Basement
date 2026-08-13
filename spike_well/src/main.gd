extends Node2D
## 四個頁面的狀態機 ＋ 世界與 UI 的接線。這裡不碰遊戲邏輯。
##
## 頁面：START ⇄ SHOP，START → PLAYING ⇄ PAUSED → GAMEOVER / CLEAR → (重來 / 回標題)

const S_START := "START"
const S_SHOP := "SHOP"
const S_ACHIEVEMENTS := "ACHIEVEMENTS"
const S_SETTINGS := "SETTINGS"
## 工作人員名單（08-13 三訂）。⚠ 它的「返回」回設定頁不是回標題，見 _on_credits_back。
const S_CREDITS := "CREDITS"
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
	ui.quit_pressed.connect(_to_title)
	ui.shop_pressed.connect(_to_shop)
	ui.shop_back_pressed.connect(_to_title)
	ui.achievements_pressed.connect(_to_achievements)
	ui.achievements_back_pressed.connect(_to_title)
	ui.settings_pressed.connect(_to_settings)
	ui.settings_back_pressed.connect(_to_title)
	ui.credits_pressed.connect(_to_credits)
	ui.credits_back_pressed.connect(_to_settings)
	# 開發者傳送鈕。⚠ 訊號永遠接，按鈕本身在 dev_mode() 為假時根本不存在（見 SpikeUI._build_hud）
	# ——「有沒有這顆鈕」只由那一個地方決定，這裡不再判斷第二次。
	ui.dev_teleport_pressed.connect(_on_dev_teleport)
	ui.dev_coins_pressed.connect(_on_dev_coins)
	ui.dev_wipe_pressed.connect(_on_dev_wipe)
	ui.story_advanced.connect(_on_story_advanced)
	ui.unlock_dismissed.connect(_on_unlock_dismissed)
	# 教學關簡化結算卡的唯一按鈕：回主畫面，走跟其他「回標題」入口同一條路
	# （劇情／解鎖蒙版仍照 _advance_to_title 的順序播，理論上教學關不會產生那些，
	# 但共用同一個入口比另開一條「這裡一定沒有待播內容」的捷徑更不容易出錯）。
	ui.tutorial_clear_pressed.connect(_to_title)

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
	# 名單頁的 ESC 退回設定頁（它的上一頁），不是退到標題——同 credits_back 的理由
	if event.keycode == KEY_ESCAPE and state == S_CREDITS:
		_set_state(S_SETTINGS)
		get_viewport().set_input_as_handled()
		return
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
		S_PAUSED:
			# 暫停時強制收掉瞄準：否則 time_scale 會被凍在慢動作，回來後全域變慢
			world.force_cancel_aim()
			get_tree().paused = true
		S_START, S_SHOP, S_ACHIEVEMENTS, S_SETTINGS, S_CREDITS:
			get_tree().paused = false
			Engine.time_scale = 1.0
			world.running = false
			world.visible = false
		_:
			get_tree().paused = false
			Engine.time_scale = 1.0
			world.running = false
			world.visible = true
	ui.show_screen(next)


func _start_run() -> void:
	get_tree().paused = false
	# 教學關（08-13x）：還沒通過教學關就一律進教學關，不管是第一次進遊戲、死掉重來、
	# 還是中途離開後回主畫面又按了「開始」——理由同 _advance_to_title 的判斷：教學關
	# 沒過完，正式局的入口都不該打開。world.tutorial_mode 是世界層唯一要知道的旗標，
	# 世界層本身不讀 SpikeSave（見 WellWorld.reset() 的 ⚠⚠）。
	world.tutorial_mode = not SpikeSave.tutorial_done
	world.reset()
	_set_state(S_PLAYING)
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


## 回主畫面的**唯一入口**（08-13）：先把欠玩家的劇情與解鎖卡播完，都播完了才真的進標題。
## ⚠ 順序是「劇情 → 解鎖卡 → 標題」：劇情講的是「發生了什麼」，解鎖卡講的是「你拿到了
##   什麼」，倒過來播會先劇透獎勵。
## ⚠ 每一段播完都會再呼叫一次這裡（見 _on_story_advanced／_on_unlock_dismissed），
##   所以「還有沒有下一段」只在這一個地方判斷，不要在各自的回呼裡再抄一次條件。
func _advance_to_title() -> void:
	if _pending_story != "":
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
	# 教學關（08-13x）：開幕劇情播完、也沒有排隊中的解鎖卡，第一次直接進教學關，
	# 不先進主畫面。_start_run() 本身就會依 SpikeSave.tutorial_done 決定要不要走
	# 教學關，這裡只要在「該進遊戲」的時候呼叫它，不必在這裡重複判斷一次。
	if not SpikeSave.tutorial_done:
		_start_run()
		return
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


func _to_shop() -> void:
	_set_state(S_SHOP)


func _to_achievements() -> void:
	_set_state(S_ACHIEVEMENTS)


func _on_achievements_unlocked(ids: Array) -> void:
	ui.queue_achievement_banners(ids)


func _to_settings() -> void:
	_set_state(S_SETTINGS)


## ⚠ 名單頁的返回接的是 _to_settings（見 _ready 的接線）：玩家是從設定頁進來的，
##   回標題會把他原本在調的按鍵設定一起關掉。
func _to_credits() -> void:
	_set_state(S_CREDITS)


## ⚠ 只在 PLAYING 生效：HUD 在 PAUSED 也看得見（按鈕跟著在），但暫停中搬玩家會讓
##   相機與物理在恢復那一幀對不上，而且「暫停時偷傳送」本來就不該是個功能。
func _on_dev_teleport() -> void:
	if state != S_PLAYING:
		return
	world.dev_teleport_up()


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
	# ⚠ 走 _set_state 而不是自己叫 ui.show_screen：show_screen("START") 本身就會重讀
	#   金幣／關卡／成就徽章（見 SpikeUI.show_screen 的分支），不必在這裡再刷一次。
	_set_state(S_START)


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
