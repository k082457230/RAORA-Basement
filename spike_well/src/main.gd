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

var world: WellWorld
var ui: SpikeUI
var state := S_START


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
	# 開發者傳送鈕。⚠ 訊號永遠接，按鈕本身在 dev_mode() 為假時根本不存在（見 SpikeUI._build_hud）
	# ——「有沒有這顆鈕」只由那一個地方決定，這裡不再判斷第二次。
	ui.dev_teleport_pressed.connect(_on_dev_teleport)

	_set_state(S_START)


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
		S_START, S_SHOP, S_ACHIEVEMENTS, S_SETTINGS:
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
	world.reset()
	_set_state(S_PLAYING)
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
	_set_state(S_START)


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


func _on_died(cause: String) -> void:
	if state != S_PLAYING:
		return
	_finish(false, cause)


func _on_cleared() -> void:
	if state != S_PLAYING:
		return
	_finish(true, "")


func _finish(is_clear: bool, cause: String) -> void:
	var d := world.result_data()
	# 先入帳再產結算文字：結算那行要印「累計 N」，順序顛倒會少算剛結束這一局。
	# 金幣摔死也保留（使用者指定），所以入帳不看 is_clear。
	SpikeSave.add_coins(int(d["coins"]))
	# 歷史最高高度：下一局的墓碑就立在這個高度（見 WellGenerator._maybe_place_tomb）。
	# ⚠ 必須在這裡記，不能在 reset() 記——reset 拿不到「上一局爬到哪」。
	SpikeSave.record_height(float(d["best_m"]))
	# 最佳用時只有登頂才算數：半路摔死的秒數比的是「誰死得比較快」，不是成績。
	# 解鎖下一關也在這裡：is_clear 只有「有終點的模式抵達 goal_meters」才會是 true
	# （無盡模式的 cleared 永遠不 emit，見 WellWorld.cleared 的 ⚠），所以不必再判一次模式。
	# ⚠ d["unlocked"] 要在 set_result 之前算好——結算頁那行「已解鎖 XXX」讀的就是它。
	d["unlocked"] = false
	if is_clear:
		SpikeSave.record_clear_time(float(d["elapsed"]))
		d["unlocked"] = SpikeSave.report_level_cleared(int(d["level"]))
	d["cleared"] = is_clear
	d["cause"] = cause

	# 成就的結算判定（登頂三連 ＋ 被投擲物砸死的累計）。⚠ 要在 add_coins 之後：
	# 領獎金幣走的是 claim_achievement 那條路，但這一局的金幣得先入帳，
	# 結算文字才印得出正確的「累計 N」。
	var fresh := SpikeSave.report_run_end(d)
	ui.set_result(d)
	_set_state(S_CLEAR if is_clear else S_GAMEOVER)
	# 橫幅排在切頁之後：結算頁蓋掉 HUD，但橫幅是獨立圖層，兩者不會互相遮
	if not fresh.is_empty():
		ui.queue_achievement_banners(fresh)
