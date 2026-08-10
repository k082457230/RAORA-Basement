extends Node
## headless bot 跑局：一隻很笨的自動玩家（上升瞄上方最近板、下墜瞄腳下最近板），
## 實際把 WellWorld 迴圈跑起來，抓執行期崩潰與明顯的數值失控（不驗手感，那要人玩）。
## 對應稽核項：_run_once(run_idx)（唯一對外入口，由 smoke.gd 呼叫 RUNS 次）。

const FPS := 60.0
const DT := 1.0 / FPS
## ⚠ 終點 1000m 之後一局要 4~5 分，240s 會在半路被截斷、看起來像「爬不上去」
const MAX_SECONDS := 420.0
## run 0 = 純爬升（無鞭子）／run 1,2 = 含鞭子／run 3 = 干擾壓力測試（干擾提前到 4s）
const STRESS_RUN := 3

var _bot_target = null


func _run_once(run_idx: int) -> bool:
	Engine.time_scale = 1.0
	_bot_target = null

	var world := WellWorld.new()
	add_child(world)
	world.set_process(false)      # 由本測試手動驅動，不讓引擎重複呼叫
	world.running = true

	var ended := {"done": false, "how": ""}
	world.died.connect(func(cause: String): ended["done"] = true; ended["how"] = "摔落(%s)" % cause)
	world.cleared.connect(func(): ended["done"] = true; ended["how"] = "通關")

	# run 0 完全不用鞭子 —— 先確認純爬升迴圈本身站得住，
	# 否則「摔死」到底是關卡不可爬還是鞭子把人甩死，會分不出來
	var use_whip := run_idx > 0

	# 壓力局：把干擾提前，否則 bot 撐不到 60s，三種干擾一種都測不到
	var saved := [
		SpikeConfig.interference_start,
		SpikeConfig.stage_steal_offset,
		SpikeConfig.stage_shockwave_offset,
	]
	# ⚠ 解鎖時點要壓在「bot 活得到」的範圍內。bot 很笨，實測常在 2~3s 就摔死，
	#   原本的 2/2/4（＝第 6 秒才進衝擊波）根本量不到第三階段。
	if run_idx == STRESS_RUN:
		SpikeConfig.interference_start = 1.0
		SpikeConfig.stage_steal_offset = 0.25
		SpikeConfig.stage_shockwave_offset = 0.5

	var frames := int(FPS * MAX_SECONDS)
	var aim_frames := 0
	var fired := 0
	var hits := 0
	var landings := 0
	var max_platforms := 0
	var stages_seen := {}
	var prev_vy := 0.0

	for i in range(frames):
		if ended["done"]:
			break

		# 一隻很笨的自動玩家：上升時瞄上方最近的板，下墜時瞄腳下最近的板。
		# 亂擺的輸入測不出東西（一定摔死），會把「關卡不可爬」跟「輸入很爛」混在一起。
		# 兩種輸入模式都要灌合成輸入，不然預設模式一切換，bot 就完全不會動。
		var target_x := _bot_target_x(world)
		if SpikeConfig.ACTIVE_INPUT_MODE == SpikeConfig.InputMode.KEYBOARD:
			var dx := target_x - world.player.pos.x
			world.kb_dir_override = 0.0 if absf(dx) < 4.0 else signf(dx)
		else:
			world.mouse_override = Vector2(target_x, world.player.pos.y - 250.0)

		# 每 6 秒起手瞄準一次；瞄準 12 幀後射出（走真實輸入路徑）
		if use_whip:
			if world.whip.state == Whip.State.AIMING:
				aim_frames += 1
				if aim_frames >= 12:
					aim_frames = 0
					_send_click(world)
					fired += 1
					if world.player.is_pulled():
						hits += 1
			elif i > int(FPS * 6.0) and i % int(FPS * 6.0) == 0 and world.whip.can_aim():
				_send_key(world, world._aim_trigger_key())

		world._process(DT * Engine.time_scale)

		# 速度由正轉負 = 剛剛彈起來了（落地或踩頭）→ 重新挑目標板
		if prev_vy > 0.0 and world.player.vel_y < 0.0:
			landings += 1
			_bot_target = null
		prev_vy = world.player.vel_y

		max_platforms = maxi(max_platforms, world.gen.platforms.size())
		stages_seen[world.interference.stage()] = true

	var height: float = world.best_m
	var elapsed: float = world.elapsed
	var rate := height / maxf(elapsed, 0.001)
	var stages: Array = stages_seen.keys()
	stages.sort()

	var tag := "干擾壓力測試" if run_idx == STRESS_RUN else ("鞭子啟用" if use_whip else "鞭子停用")
	print("--- run %d（%s）---" % [run_idx, tag])
	print("  落地 / 踩頭     : %d / %d" % [landings, world.stomp_count])
	print("  金幣 / 蟲洞     : %d / %d" % [world.coin_count, world.wormhole_count])
	print("  無敵撞飛        : %d" % world.bump_count)
	print("  結束方式        : %s" % ("時間到仍未結束" if not ended["done"] else ended["how"]))
	print("  最高高度 / 終點 : %.1f m / %.0f m" % [height, SpikeConfig.goal_meters])
	print("  用時 / 爬升速率 : %.1f s / %.2f m/s（PILLARS 錨點 2.39）" % [elapsed, rate])
	print("  鞭子 射出/命中  : %d / %d，剩餘 %d" % [fired, hits, world.whip.charges])
	print("  干擾階段觸及    : %s（0未登場 1投擲物 2抽跳板 3衝擊波）" % [stages])
	print("  場上平台峰值    : %d（有回收就不該無限增長）" % max_platforms)

	if ended["done"]:
		_print_death_context(world)

	var ok := true
	if height <= 1.0:
		print("  !! 玩家完全沒爬升")
		ok = false
	if max_platforms > 400:
		print("  !! 平台沒有被回收")
		ok = false
	if fired >= 3 and hits == 0:
		print("  !! 鞭子射了 %d 次全部落空" % fired)
		ok = false
	# 壓力局只驗「干擾真的在實跑局裡開火」；完整階梯 0→3 由 _audit_interference_ladder
	# 空跑驗證，那條不該綁在 bot 的存活時間上。
	if run_idx == STRESS_RUN and not stages_seen.has(1):
		print("  !! 壓力局完全沒觸發干擾")
		ok = false

	SpikeConfig.interference_start = saved[0]
	SpikeConfig.stage_steal_offset = saved[1]
	SpikeConfig.stage_shockwave_offset = saved[2]
	remove_child(world)
	world.queue_free()
	return ok


## 死亡當下的現場：玩家在哪、附近還有哪些板。用來分辨「關卡生不出可踩的板」
## 跟「bot 自己接不到」——兩者的修法完全不同。
func _print_death_context(world: WellWorld) -> void:
	var py: float = world.player.pos.y
	var near: Array = []
	for p in world.gen.platforms:
		if p.alive and absf(p.center().y - py) < 320.0:
			near.append(p)
	near.sort_custom(func(a, b): return a.center().y < b.center().y)
	print("  死亡位置        : x=%.0f y=%.0f（畫面底 y=%.0f）" % [
		world.player.pos.x, py, world.cam_y + SpikeConfig.VIEW_H * 0.5
	])
	var parts := PackedStringArray()
	for p in near:
		parts.append("k%d(x%.0f,dy%+.0f)" % [p.kind, p.pos.x, p.center().y - py])
	print("  附近平台        : %s" % (", ".join(parts) if parts.size() > 0 else "無"))


## bot 必須「鎖定一塊目標板直到落地」。每幀重挑最近的板會讓它在原地來回擺盪、
## 永遠爬不上去——那樣量到的是 bot 的爛，不是關卡的難度。
func _bot_target_x(world: WellWorld) -> float:
	var pl := world.player
	var feet: float = pl.bottom()

	if _bot_target != null and not _bot_target.alive:
		_bot_target = null
	# 已經掉到目標下方 → 放棄它，改找腳下能接的
	if pl.vel_y > 0.0 and _bot_target != null and feet > _bot_target.top_y() + 40.0:
		_bot_target = null

	if _bot_target == null:
		if pl.vel_y > 0.0:
			_bot_target = _nearest_below(world, feet)
		else:
			_bot_target = _pick_climb_target(world, feet, pl.pos.x)

	if _bot_target == null:
		return (SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5
	return _bot_target.pos.x


## 跳得到、且水平距離划算的那一塊
func _pick_climb_target(world: WellWorld, feet: float, px: float):
	var reach := SpikeConfig.MAX_JUMP_HEIGHT * 0.95
	var best = null
	var best_cost := INF
	for p in world.gen.platforms:
		if not p.alive:
			continue
		var top: float = p.top_y()
		if top >= feet - 20.0 or top < feet - reach:
			continue
		var cost: float = absf(p.pos.x - px) - (feet - top) * 0.5
		if cost < best_cost:
			best_cost = cost
			best = p
	return best


func _nearest_below(world: WellWorld, feet: float):
	var best = null
	for p in world.gen.platforms:
		if not p.alive:
			continue
		var top: float = p.top_y()
		if top < feet:
			continue
		if best == null or top < best.top_y():
			best = p
	return best


func _send_key(world: WellWorld, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	world._unhandled_input(ev)


func _send_click(world: WellWorld) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	world._unhandled_input(ev)
