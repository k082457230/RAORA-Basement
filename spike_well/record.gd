extends Node
## 決定性錄影驗證：讓既有的 headless bot 在「會渲染」的模式下把遊戲真的跑起來，
## 逐格輸出 PNG，供事後回讀確認**動態**表現（姿勢切換、特效、干擾演出、死亡動畫）。
##
## 為什麼要有這支——既有兩支都驗不到「動起來對不對」：
##   smoke.tscn      bot 跑得完整但 set_process(false) ＋ for 迴圈一次跑完，全程不渲染。
##   visual_check.tscn 會渲染，但只擺靜態姿勢、拍單張。
##
## ⚠⚠ **一定不能加 --headless**：headless 底下 RenderingServer 是 dummy driver，
##    --write-movie 會寫出一整批空白 PNG（同 visual_check.gd 那個坑，08-08 踩過）。
## ⚠ 必須以「場景」方式跑（同 smoke.gd 的理由：--script 不會載入 autoload，
##   SpikeConfig／SpikeSave 會找不到）。
##
## 指令（Windows，PowerShell 用反引號續行；錄幾秒由本檔管，指令不帶 --quit-after）：
##   & "C:/Users/gnt0233/Downloads/Godot_v4.6.1-stable_win64_console.exe" `
##     --path <spike_well 絕對路徑> res://record.tscn `
##     --write-movie tools/out/rec/frame.png --fixed-fps 60
##
## 可選 user args（一律放在 `--` 之後）：
##   -- --seed=1234   指定井的 seed（預設 DEFAULT_SEED；固定＝同一座井才能逐格比對）
##   -- --secs=20     錄幾秒（預設 DEFAULT_SECONDS）
##   -- --stress      把干擾提前到第 1 秒。⚠ 正常節奏下干擾 67s 才登場，
##                    預設 20 秒的錄影**看不到任何干擾**，要驗干擾演出就得開這個。
##
## 輸出：tools/out/rec/frame*.png（不進版控，見根目錄 .gitignore）。
## 事後回讀建議挑頭／中／尾三張看，不用整批讀。

const FPS := 60.0
## ⚠ 刻意不吃引擎給的 delta（見 _process 的 ⚠⚠），這裡是唯一的時間真相。
const DT := 1.0 / FPS
## 固定 seed ＝ 同一座井。改這個值等於換一座井，之前錄的就不能拿來比對了。
const DEFAULT_SEED := 20260813
const DEFAULT_SECONDS := 20.0
const OUT_DIR := "res://tools/out/rec"
## 起手瞄準的週期。⚠ 刻意比 tests/bot_run.gd 的 6 秒短很多：實測 bot 只活 3~4 秒，
## 用 6 秒的話錄影全程一次鞭子都射不出來（smoke 的 bot 局同理，那邊「射出 0/命中 0」
## 就是這個原因）。錄影的用途是看演出，鞭子必須真的出現在畫面上。
const WHIP_PERIOD_SEC := 1.5
const WHIP_AIM_FRAMES := 12

var _world: WellWorld
## tests/bot_run.gd 的實例。只借它的決策函式（_bot_target_x／_send_key／_send_click），
## 不呼叫 _run_once——那支是「一次跑完不渲染」的，正好是本檔要避開的東西。
## ⚠ 借用而不是複製一份瞄準邏輯：bot 的決策改了，錄影要跟著改，否則錄的不是同一隻 bot。
var _bot: Node

var _frame := 0
var _total_frames := 0
var _aim_frames := 0
var _fired := 0
var _prev_vy := 0.0
var _stress := false
## 壓力模式改動的 SpikeConfig 欄位原值，跑完要還原（同 bot_run 的做法）。
var _saved: Array = []


func _ready() -> void:
	# ⚠ 同 visual_check.gd／smoke.gd：這支會走真實遊戲路徑（存檔、選關），
	#   不導沙盒就會洗掉玩家的真實存檔。
	SpikeSave.use_sandbox()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var seed_val := _arg_int("seed", DEFAULT_SEED)
	var secs := _arg_float("secs", DEFAULT_SECONDS)
	_stress = _has_flag("stress")
	_total_frames = int(FPS * secs)

	if _stress:
		_saved = [
			SpikeConfig.interference_start,
			SpikeConfig.stage_steal_offset,
			SpikeConfig.stage_shockwave_offset,
		]
		SpikeConfig.interference_start = 1.0
		SpikeConfig.stage_steal_offset = 0.25
		SpikeConfig.stage_shockwave_offset = 0.5

	_bot = preload("res://tests/bot_run.gd").new()

	_world = WellWorld.new()
	# ⚠⚠ seed 必須在 add_child() **之前**設：add_child 會觸發 _ready() → reset()，
	#    生成器的 seed 在那一刻就被讀走了，事後再設完全沒有作用。
	_world.seed_override = seed_val
	add_child(_world)
	# 由本檔逐格驅動，不讓引擎再自己呼叫一次（會變成一格跑兩次物理）。
	_world.set_process(false)
	_world.running = true

	print("[record] seed=%d secs=%.1f frames=%d stress=%s" % [
		seed_val, secs, _total_frames, str(_stress)
	])
	print("[record] out=%s" % ProjectSettings.globalize_path(OUT_DIR))


func _process(_engine_delta: float) -> void:
	# ⚠⚠ 刻意忽略引擎給的 delta，一律餵固定 DT。錄影的全部價值在「同一顆 seed 跑出
	#    一模一樣的結果」，吃真實 frame time 會讓兩次錄影對不起來，逐格比對就失去意義。
	#    （godogen 靠 --fixed-fps 讓引擎給固定 delta；這裡直接繞過引擎 delta，更硬。）
	if _frame >= _total_frames:
		_finish()
		return
	_drive_one_frame()
	_frame += 1


## 一格的 bot 決策 ＋ 推進世界。內容對齊 tests/bot_run.gd 的主迴圈，
## 差別只在「誰來驅動」——那邊是 for 迴圈，這邊是引擎逐格（才有畫面可錄）。
func _drive_one_frame() -> void:
	# 死亡演出期間不要再灌輸入：world 已經凍結物理，只有爆炸在動。
	# 這段照樣要推進（而且正是錄影想看的東西），所以不 return，只跳過決策。
	if not _world.running:
		_world._process(DT * Engine.time_scale)
		return

	var target_x: float = _bot._bot_target_x(_world)
	if SpikeConfig.ACTIVE_INPUT_MODE == SpikeConfig.InputMode.KEYBOARD:
		var dx := target_x - _world.player.pos.x
		_world.kb_dir_override = 0.0 if absf(dx) < 4.0 else signf(dx)
	else:
		_world.mouse_override = Vector2(target_x, _world.player.pos.y - 250.0)

	if _world.whip.state == Whip.State.AIMING:
		_aim_frames += 1
		if _aim_frames >= WHIP_AIM_FRAMES:
			_aim_frames = 0
			_bot._send_click(_world)
			_fired += 1
	elif _frame > int(FPS * WHIP_PERIOD_SEC) \
			and _frame % int(FPS * WHIP_PERIOD_SEC) == 0 \
			and _world.whip.can_aim():
		_bot._send_key(_world, _world._aim_trigger_key())

	_world._process(DT * Engine.time_scale)

	# 速度由正轉負 ＝ 剛彈起來（落地或踩頭）→ 讓 bot 重挑目標板。
	if _prev_vy > 0.0 and _world.player.vel_y < 0.0:
		_bot._bot_target = null
	_prev_vy = _world.player.vel_y


func _finish() -> void:
	set_process(false)
	print("[record] done frames=%d height=%.1fm whip_fired=%d ended=%s" % [
		_frame, _world.best_m, _fired,
		("死亡/結束" if not _world.running else "仍在進行")
	])
	if _stress and _saved.size() == 3:
		SpikeConfig.interference_start = _saved[0]
		SpikeConfig.stage_steal_offset = _saved[1]
		SpikeConfig.stage_shockwave_offset = _saved[2]
	# ⚠ _bot 是 new() 出來、刻意沒進場景樹的裸 Node（借函式用，不需要它被驅動）。
	#   沒 free 的話 quit 時會印 "ObjectDB instances leaked at exit"。
	if is_instance_valid(_bot):
		_bot.free()
	get_tree().quit()


# ============================================================
# user args（`--` 之後的參數，格式 --key=value 或 --flag）
# ============================================================

func _arg_raw(key: String) -> String:
	var want := "--%s=" % key
	for a in OS.get_cmdline_user_args():
		if a.begins_with(want):
			return a.substr(want.length())
	return ""


func _arg_int(key: String, fallback: int) -> int:
	var s := _arg_raw(key)
	return int(s) if s.is_valid_int() else fallback


func _arg_float(key: String, fallback: float) -> float:
	var s := _arg_raw(key)
	return float(s) if s.is_valid_float() else fallback


func _has_flag(key: String) -> bool:
	return OS.get_cmdline_user_args().has("--%s" % key)
