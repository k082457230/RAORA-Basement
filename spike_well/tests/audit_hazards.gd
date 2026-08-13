extends Node
## 危害稽核：Pameloe（懸浮定點射手）、黑洞（doom）、墓碑三種「踩到/碰到會死或給獎勵」的
## 危害物件，規格全在這裡驗。被 audit_mechanics.gd 透過 smoke.gd 注入的引用呼叫
## （_audit_mechanics 的第 ⑮⑭⑰ 項）。
## 對應稽核項：_audit_pameloe() / _audit_doom() / _audit_tomb()。

const FPS := 60.0
const DT := 1.0 / FPS


## 讓死亡演出跑完，直到 died 訊號真的 emit（或超時保護把控制權還回來）。
## ⚠ v17 起 `_die()` 只是**起爆**，`died` 要等爆炸演完才 emit（見 WellWorld._tick_death_fx）。
##   稽核若判定完就直接問「死了沒」，答案永遠是 false，而且是靜默的假陰性。
## ⚠ audit_mechanics.gd 有一份一模一樣的，理由見那邊的註解（兩個稽核節點之間只有
##   mechanics → hazards 單向引用，為 7 行的測試 helper 接第二條反向線不划算）。
func _settle_death(world: WellWorld) -> void:
	var guard := int(SpikeConfig.DEATH_FX_DURATION / DT) + 8
	for _i in range(guard):
		if not world.is_dying():
			return
		world._process(DT)


## Pameloe（v16，08-10 三訂加雷射變體）：懸浮定點射手與牠的子彈／雷射，十二條規格
## 全在這裡驗——畫面內才開火、發射瞬間鎖定玩家位置之後不追蹤、子彈穿透平台、碰到井壁
## 消失、命中玩家即死且死因是 CAUSE_PAMELOE_SHOT、無敵狀態下打散子彈、踩頭殺得掉本體、
## 畫面外用 hold_fire() 頂住計時器（不會一捲進畫面就同幀開火）、art_variant == 1 開火走
## 雷射分支、雷射命中死因是 CAUSE_PAMELOE_LASER、無敵狀態下打散雷射、殺掉本體立刻掐斷
## 雷射（跟子彈「脫鉤飛完」刻意不同）。
## ⚠ 全程呼叫 world._fire_pameloe_shots() / world._tick_shots() / world._check_hazards()
##   這幾個 WellWorld._process 實際在跑的函式，不自己複製一份判定邏輯（專案 CLAUDE.md 硬規則 7）。
func _audit_pameloe(world: WellWorld) -> bool:
	world.gen.monsters.clear()
	world.gen.platforms.clear()
	world._shots.clear()
	world._wh_travel_active = false
	world.interference = Interference.new()
	world.interference.reset()
	world.player.invuln_timer = 0.0
	# ⚠ 玩家的 x 要自己定死，不能沿用前面稽核留下的位置。黑洞那條會把玩家搬到**隨機**平台
	#   上，一旦落在井的右半邊，下面那隻擺在玩家 +300px 的 pameloe 就生在井壁外，子彈第一幀
	#   就判定碰壁消失 ⇒「穿透平台」與「命中死因」兩條偶發紅燈，而且紅的原因跟被測程式
	#   完全無關。偶發的假陰性比沒有測還糟：它會訓練人把紅燈當雜訊。
	world.player.pos.x = SpikeConfig.WELL_LEFT \
		+ (SpikeConfig.WELL_RIGHT - SpikeConfig.WELL_LEFT) * 0.25
	var orig_player_pos: Vector2 = world.player.pos
	world.cam_y = orig_player_pos.y      # 視窗邊界自己掌握，不依賴前面測試留下的相機位置

	# --- 畫面內開火 ＋ 發射瞬間鎖定玩家位置、之後不追蹤（規格 4）---
	var m1 := WellMonster.new()
	m1.set_kind(WellMonster.Kind.PAMELOE)
	m1.pos = orig_player_pos + Vector2(240.0, -120.0)
	m1.fire_timer = 0.0                  # 跳過生成延遲，逼近「就緒可射」
	world.gen.monsters.append(m1)

	var shots_before: int = world.pameloe_shot_count
	world._fire_pameloe_shots()
	var fired: bool = world.pameloe_shot_count == shots_before + 1 and world._shots.size() == 1

	var lock_ok := false
	if fired:
		var sh: PameloeShot = world._shots[0]
		var fire_pos: Vector2 = sh.pos
		var dir0: Vector2 = sh.vel.normalized()
		world.player.pos = Vector2(50.0, -900.0)   # 發射「之後」才把玩家挪走
		world._fire_pameloe_shots()                # m1 剛射完、計時器已重置，這幀不該再射
		var no_double_fire: bool = world._shots.size() == 1
		world._tick_shots(0.2)
		var moved: Vector2 = sh.pos - fire_pos
		lock_ok = no_double_fire and sh.alive and moved.length() > 1.0 \
			and moved.normalized().distance_to(dir0) < 0.01

	# --- 子彈穿透平台、命中玩家、死因是 CAUSE_PAMELOE_SHOT（規格 5）---
	world.gen.monsters.clear()
	world._shots.clear()
	world.player.pos = orig_player_pos
	var m2 := WellMonster.new()
	m2.set_kind(WellMonster.Kind.PAMELOE)
	m2.pos = orig_player_pos + Vector2(300.0, 0.0)
	m2.fire_timer = 0.0
	world.gen.monsters.append(m2)

	var blocker := WellPlatform.new()
	blocker.kind = WellPlatform.Kind.STATIC
	blocker.size = SpikeConfig.PLATFORM_SIZE
	blocker.pos = orig_player_pos + Vector2(150.0, 0.0)   # 卡在子彈與玩家的正中間
	world.gen.platforms.append(blocker)
	world._fire_pameloe_shots()

	var pierce_dead := {"v": false, "cause": ""}
	var pierce_cb := func(c: String):
		pierce_dead["v"] = true
		pierce_dead["cause"] = c
	world.died.connect(pierce_cb)

	var passed_through := false
	var frames := 0
	while not pierce_dead["v"] and frames < 240 and not world._shots.is_empty():
		world._tick_shots(DT)
		if not world._shots.is_empty() and world._shots[0].rect().intersects(blocker.rect()):
			passed_through = true
		world._check_hazards()
		frames += 1
	# 命中之後死亡演出還沒演完，died 要等它演完才來（見 _settle_death）
	_settle_death(world)
	world.died.disconnect(pierce_cb)
	var hit_ok: bool = pierce_dead["v"] and pierce_dead["cause"] == WellWorld.CAUSE_PAMELOE_SHOT

	# --- 碰到井壁消失（規格 5）---
	world._shots.clear()
	var sh_wall := PameloeShot.new()
	sh_wall.pos = Vector2(SpikeConfig.WELL_LEFT + 40.0, orig_player_pos.y)
	sh_wall.vel = Vector2(-SpikeConfig.PAMELOE_SHOT_SPEED, 0.0)
	world._shots.append(sh_wall)
	var wall_frames := 0
	while sh_wall.alive and wall_frames < 60:
		world._tick_shots(DT)
		wall_frames += 1
	var wall_ok: bool = not sh_wall.alive and world._shots.is_empty()

	# --- 無敵狀態下子彈被打散（規格 6，同投擲物規則）---
	world.gen.monsters.clear()
	world._shots.clear()
	world.player.pos = orig_player_pos
	world.player.invuln_timer = 0.0
	var sh_scatter := PameloeShot.new()
	sh_scatter.pos = orig_player_pos
	sh_scatter.vel = Vector2(300.0, 0.0)
	world._shots.append(sh_scatter)
	world.player.refresh_invuln()
	var scatter_dead := {"v": false}
	var scatter_cb := func(_c: String): scatter_dead["v"] = true
	world.died.connect(scatter_cb)
	world._check_hazards()
	world.died.disconnect(scatter_cb)
	# ⚠ 連 is_dying() 一起問：死亡訊號是延遲的，只看 scatter_dead 的話
	#   「無敵中竟然被子彈打死」會靜默通過
	var scattered: bool = (
		not scatter_dead["v"] and not world.is_dying() and not sh_scatter.alive
	)
	world.player.invuln_timer = 0.0

	# --- 踩頭殺得掉 pameloe（PILLARS 保底條款的回歸防線，規格 7）---
	world.gen.monsters.clear()
	var m3 := WellMonster.new()
	m3.set_kind(WellMonster.Kind.PAMELOE)
	m3.pos = orig_player_pos
	world.gen.monsters.append(m3)
	world._pre_vel_y = 400.0
	world._pre_bottom = m3.rect().position.y
	var stomps_before: int = world.stomp_count
	world._check_hazards()
	var stomped: bool = m3.dying and not m3.alive and world.stomp_count == stomps_before + 1

	# --- 畫面外不開火，hold_fire() 讓計時器不會跑到負值（規格 8）---
	world.gen.monsters.clear()
	world._shots.clear()
	world.player.pos = orig_player_pos
	world.cam_y = orig_player_pos.y
	var m4 := WellMonster.new()
	m4.set_kind(WellMonster.Kind.PAMELOE)
	m4.pos = Vector2(orig_player_pos.x, world._view_bottom() + 500.0)
	m4.fire_timer = -5.0    # 模擬在畫面外空轉很久，沒有 hold_fire 的話早該跑到很負
	world.gen.monsters.append(m4)

	var shots_before2: int = world.pameloe_shot_count
	world._fire_pameloe_shots()
	var offscreen_ok: bool = world.pameloe_shot_count == shots_before2 \
		and m4.fire_timer >= SpikeConfig.PAMELOE_FIRE_SIGHT_DELAY - 0.001 \
		and is_equal_approx(m4.charge_ratio(), 0.0)

	# 相機把牠捲進畫面的那一刻：計時器已經被頂住，不會同一幀就開火
	m4.pos.y = orig_player_pos.y
	world._fire_pameloe_shots()
	var no_instant_fire_on_enter: bool = world.pameloe_shot_count == shots_before2

	# --- 初見寬限（08-12 使用者拍板）：進畫面後要真的等滿 PAMELOE_FIRE_SIGHT_DELAY
	#     才開第一發，不是等 PAMELOE_CHARGE_TIME 就開 ---
	# ⚠ 這兩條是「畫面外充能」那條的補丁：那條驗的是 fire_timer 的**下限**，把
	#   SIGHT_DELAY 手滑改回 0.5 它照樣全綠（0.5 >= CHARGE_TIME 0.45）。要驗到
	#   「等滿」就得推進時間走真實路徑（專案 CLAUDE.md 硬規則 7）。
	# ⚠ float_base_y 要先對齊 pos.y：手動 new 的 m4 沒走過 _make_pameloe，這欄預設 0.0，
	#   第一次 step() 會把牠瞬移到井口高度、直接飛出畫面，後面兩條全部失真。
	m4.float_base_y = m4.pos.y
	m4.step((SpikeConfig.PAMELOE_CHARGE_TIME + SpikeConfig.PAMELOE_FIRE_SIGHT_DELAY) * 0.5)
	world._fire_pameloe_shots()
	var sight_delay_holds: bool = world.pameloe_shot_count == shots_before2
	m4.step(SpikeConfig.PAMELOE_FIRE_SIGHT_DELAY)   # 一定跨過剩下的
	world._fire_pameloe_shots()
	var sight_delay_fires: bool = world.pameloe_shot_count == shots_before2 + 1

	# --- 蟲洞過場中不開火，過場結束後補上（跟干擾的 suppress_spawn 同一套）---
	world.gen.monsters.clear()
	world._shots.clear()
	var m5 := WellMonster.new()
	m5.set_kind(WellMonster.Kind.PAMELOE)
	m5.pos = orig_player_pos + Vector2(0.0, -200.0)
	m5.fire_timer = 0.0
	world.gen.monsters.append(m5)
	var shots_before3: int = world.pameloe_shot_count
	world._wh_travel_active = true
	world._fire_pameloe_shots()
	var travel_silent: bool = world.pameloe_shot_count == shots_before3
	world._wh_travel_active = false
	# 計時器在過場中照跑（過場不是免費喘息），所以結束後下一次立刻補上那一發
	world._fire_pameloe_shots()
	var resumes_after_travel: bool = world.pameloe_shot_count == shots_before3 + 1

	# --- 雷射變體：開火走雷射分支、不生子彈（規格 9，08-10 三訂）---
	world.gen.monsters.clear()
	world._shots.clear()
	world.player.pos = orig_player_pos
	var m6 := WellMonster.new()
	m6.set_kind(WellMonster.Kind.PAMELOE)
	m6.art_variant = 1
	m6.pos = orig_player_pos + Vector2(240.0, -120.0)
	m6.fire_timer = 0.0
	world.gen.monsters.append(m6)
	var lasers_before: int = world.pameloe_laser_count
	world._fire_pameloe_shots()
	var laser_fired: bool = world.pameloe_laser_count == lasers_before + 1 \
		and world._shots.is_empty() and m6.laser_active

	# --- 雷射命中判定＋死因（規格 10）：站在光束中點，不是牠鎖定的原始位置——
	#     這樣才驗到「一路打到牆」而不是「打到玩家那一點就停」。
	var hit_point: Vector2 = m6.pos.lerp(m6.laser_endpoint(), 0.5)
	world.player.pos = hit_point
	var laser_dead := {"v": false, "cause": ""}
	var laser_cb := func(c: String):
		laser_dead["v"] = true
		laser_dead["cause"] = c
	world.died.connect(laser_cb)
	world._check_hazards()
	_settle_death(world)
	world.died.disconnect(laser_cb)
	var laser_hit_ok: bool = laser_dead["v"] and laser_dead["cause"] == WellWorld.CAUSE_PAMELOE_LASER

	# --- 無敵狀態下撞進雷射＝打散它、不死（規格 11，同子彈規則）---
	m6.laser_active = true
	m6.laser_timer = SpikeConfig.PAMELOE_LASER_DURATION
	world.player.pos = hit_point
	world.player.invuln_timer = 0.0
	world.player.refresh_invuln()
	var laser_scatter_dead := {"v": false}
	var laser_scatter_cb := func(_c: String): laser_scatter_dead["v"] = true
	world.died.connect(laser_scatter_cb)
	world._check_hazards()
	world.died.disconnect(laser_scatter_cb)
	var laser_scattered: bool = (
		not laser_scatter_dead["v"] and not world.is_dying() and not m6.laser_active
	)
	world.player.invuln_timer = 0.0

	# --- 殺掉本體＝立刻掐斷雷射（規格 12，跟子彈「脫鉤飛完」刻意不同，見 kill() 的 ⚠）---
	m6.laser_active = true
	m6.laser_timer = SpikeConfig.PAMELOE_LASER_DURATION
	m6.kill(1.0)
	var laser_cut_on_kill: bool = not m6.laser_active

	# --- 雷射瞄準在充能「起點」就鎖定、不是開火瞬間才鎖（規格 9b，08-10 四訂）---
	# ⚠ 這是本輪修正的核心：舊版直到充能結束才決定方向，玩家整段充能都看不到要打哪。
	#   驗三件事：① 剛跨進充能窗口那一幀就已經鎖了方向（不等 fire_timer 歸零）
	#   ② 鎖定之後玩家怎麼移動，方向都不會跟著重算 ③ 真正開火時用的還是同一個方向。
	world.gen.monsters.clear()
	world._shots.clear()
	world.player.pos = orig_player_pos + Vector2(240.0, -120.0)
	var m6b := WellMonster.new()
	m6b.set_kind(WellMonster.Kind.PAMELOE)
	m6b.art_variant = 1
	m6b.pos = orig_player_pos
	m6b.fire_timer = SpikeConfig.PAMELOE_CHARGE_TIME - 0.01   # 剛跨進充能窗口，還沒射
	world.gen.monsters.append(m6b)
	world._fire_pameloe_shots()
	var locked_dir: Vector2 = m6b.laser_dir
	var aim_locked_before_fire: bool = m6b.laser_dir_locked and not m6b.laser_active \
		and m6b.charge_ratio() > 0.0

	world.player.pos = Vector2(50.0, -900.0)   # 鎖定之後玩家亂跑，方向不該跟著變
	world._fire_pameloe_shots()
	var aim_holds_during_charge: bool = m6b.laser_dir.distance_to(locked_dir) < 0.001 \
		and not m6b.laser_active

	m6b.fire_timer = 0.0
	world._fire_pameloe_shots()   # 充能結束，真正開火
	var aim_lock_ok: bool = aim_locked_before_fire and aim_holds_during_charge \
		and m6b.laser_active and m6b.laser_dir.distance_to(locked_dir) < 0.001

	# --- 常數之間的合理性（⚠ 這一組跟上面那些行為稽核性質不同，見下）---
	# 上面每一條行為稽核都是拿 SpikeConfig 的常數去驗 code，所以**常數本身被改壞是驗不出來的**：
	# 把 PAMELOE_MIN_DIST_X 手滑設成 0，行為稽核只會忠實地驗「距離 >= 0」然後全綠。
	# 這幾條是那個盲點的補丁——驗的是常數彼此之間必須成立的關係，不吃任何 code 路徑。
	var consts_ok: bool = (
		# 隔開距離要大於「平台半寬 ＋ pameloe 半寬」，否則就算通過距離檢查仍會水平重疊到平台上
		SpikeConfig.PAMELOE_MIN_DIST_X
			>= SpikeConfig.PLATFORM_SIZE.x * 0.5 + SpikeConfig.PAMELOE_SIZE.x * 0.5
		# 懸浮高度要高過玩家身高，否則牠貼在平台上緣，跳上去等於直接撞側面（＝無法踩頭）。
		# ⚠ 08-10 漂浮上線後要扣掉振幅：吃掉這段餘裕的正是晃到最低點的那一刻，
		#   拿沒扣的 HOVER_Y 來驗等於驗一個玩家永遠碰不到的位置。
		and SpikeConfig.PAMELOE_HOVER_Y - SpikeConfig.PAMELOE_FLOAT_AMP
			> SpikeConfig.PLAYER_SIZE.y
		# 判定框必須小於視覺框（「看起來閃過了卻死」是不可歸因的死法）
		and SpikeConfig.PAMELOE_SHOT_HIT_SIZE.x < SpikeConfig.PAMELOE_SHOT_SIZE.x
		and SpikeConfig.PAMELOE_SHOT_HIT_SIZE.y < SpikeConfig.PAMELOE_SHOT_SIZE.y
		# 充能時間必須短於發射間隔，否則充能燈永遠亮著＝等於沒有預告
		and SpikeConfig.PAMELOE_CHARGE_TIME < SpikeConfig.PAMELOE_FIRE_INTERVAL
		# 初見寬限必須長於充能時間（08-12）：hold_fire 把計時器頂在 SIGHT_DELAY，
		# 若它小於 CHARGE_TIME，玩家一把牠捲進畫面充能燈就已經亮了一半＝預告被截掉。
		and SpikeConfig.PAMELOE_FIRE_SIGHT_DELAY > SpikeConfig.PAMELOE_CHARGE_TIME
		# 雷射判定必須小於視覺（同子彈的理由），持續時間必須是正數
		and SpikeConfig.PAMELOE_LASER_HIT_WIDTH < SpikeConfig.PAMELOE_LASER_WIDTH
		and SpikeConfig.PAMELOE_LASER_DURATION > 0.0
	)

	world.gen.monsters.clear()
	world.gen.platforms.clear()
	world._shots.clear()
	world.player.pos = orig_player_pos
	world.player.invuln_timer = 0.0

	# ⚠ 逐項印出來而不是回一個合成的 bool：12 條併成一句「其中一項有問題」時，
	#   查是哪一條得回來讀整個函式——診斷成本比印這幾行高太多。
	var checks := {
		"開火": fired,
		"方向鎖定": lock_ok,
		"命中死因": hit_ok,
		"穿透平台": passed_through,
		"碰壁消失": wall_ok,
		"無敵打散": scattered,
		"踩頭": stomped,
		"畫面外充能": offscreen_ok,
		"進畫面不同幀開火": no_instant_fire_on_enter,
		"初見寬限未滿不開火": sight_delay_holds,
		"初見寬限滿了才開火": sight_delay_fires,
		"過場靜默": travel_silent,
		"過場後補上": resumes_after_travel,
		"雷射開火": laser_fired,
		"雷射命中死因": laser_hit_ok,
		"雷射無敵打散": laser_scattered,
		"雷射隨本體關閉": laser_cut_on_kill,
		"雷射瞄準提前鎖定": aim_lock_ok,
		"常數合理性": consts_ok,
	}
	var bad := PackedStringArray()
	for k in checks:
		if not checks[k]:
			bad.append(String(k))
	if not bad.is_empty():
		print("  !! Pameloe 失敗細項：%s" % ", ".join(bad))
	return bad.is_empty()


## 黑洞（v13）。走真實路徑：讓 Interference 自己跑到第四階、自己挑平台、自己開洞。
## ⚠ 不直接 new 一個 Doom 塞進去——那樣測到的是「我有沒有把欄位設對」，
##   而不是「玩到那個時間點會發生什麼」（專案 CLAUDE.md 硬規則 7）。
## 爆炸平台（08-10）：踩上去點燃 → 引信期間仍踩得住 → 時間到炸開且平台消失 →
## 爆炸碰到即死（死因對得上）→ 無敵中免疫且**爆炸不會被消掉** → 重複踩不重置引信 →
## 爆炸區壽命到自己消失。
## ⚠ 全程走 world._step_platforms()／world._check_hazards() 這幾個 _process 真的在跑的
##   函式，不自己複製一份判定（硬規則 7）。
## ⚠⚠ 判定完必須 `_settle_death()` 把演出跑完才問「死了沒」——`_die()` 只是起爆，
##   `died` 要等爆炸演完才 emit（常青認知第 7 條）。直接問的答案永遠是 false，而且是
##   靜默的假陰性：致命判定整條壞掉也照樣全綠。
func _audit_explosive_platform(world: WellWorld) -> bool:
	world.gen.monsters.clear()
	world.gen.platforms.clear()
	world.gen.pickups.clear()
	world._shots.clear()
	world._blasts.clear()
	world._wh_travel_active = false
	world.interference = Interference.new()
	world.interference.reset()
	world.player.invuln_timer = 0.0
	world._dying = false

	var plat := WellPlatform.new()
	plat.kind = WellPlatform.Kind.EXPLOSIVE
	plat.size = SpikeConfig.EXPLOSIVE_SIZE
	plat.pos = Vector2(SpikeConfig.VIEW_W * 0.5, 0.0)
	world.gen.platforms.append(plat)

	# ① 沒踩之前不會自己燒
	world._step_platforms(DT)
	if plat.fuse_timer >= 0.0 or not plat.alive:
		return false

	# ② 踩下去點燃；引信期間平台仍活著（踩得住、跳得掉）
	plat.on_stepped()
	if plat.fuse_timer < 0.0:
		return false
	world._step_platforms(DT)
	if not plat.alive:
		return false
	var mid_ratio: float = plat.fuse_ratio()
	if mid_ratio >= 1.0 or mid_ratio <= 0.0:
		return false

	# ③ 重複踩不得把引信推回滿格（否則在板上連跳＝無限拆彈，這塊板永遠不會炸）
	var before: float = plat.fuse_timer
	plat.on_stepped()
	if plat.fuse_timer > before:
		return false

	# ④ 燒完 → 平台消失 ＋ 生出爆炸區。⚠ 玩家先擺遠一點，這一步驗的是「會不會炸」，
	#    不是「會不會炸死人」——兩件事混在一起的話，其中一條壞掉會被另一條掩蓋。
	world.player.pos = Vector2(SpikeConfig.VIEW_W * 0.5, -600.0)
	var blasts_before: int = world.blast_count
	var guard := int(SpikeConfig.EXPLOSIVE_FUSE_TIME / DT) + 8
	for _i in range(guard):
		if not plat.alive:
			break
		world._step_platforms(DT)
	if plat.alive or world.blast_count != blasts_before + 1 or world._blasts.is_empty():
		return false
	var blast = world._blasts[0]
	# 爆炸區生在平台中心（它是地形事件，跟觸發它的人已經沒有關係）
	if blast.pos.distance_to(plat.pos) > 0.5:
		return false
	# 半徑內外的判定：圓不是矩形——用對角線方向取樣，矩形判定會在這裡放行
	var diag: float = SpikeConfig.EXPLOSIVE_RADIUS * 0.75
	if not blast.hits(plat.pos):
		return false
	if blast.hits(plat.pos + Vector2(diag, diag)):   # 距離 = 半徑 × 1.06，圓外、矩形內
		return false

	# ⑤ 無敵中免疫，而且爆炸**不會**被消掉（跟怪物／投擲物／黑洞那三條刻意不同：
	#    爆炸是範圍事件，「衝過去消掉它」會讓 jetpack 變成拆彈工具）
	world.player.pos = blast.pos
	world.player.refresh_invuln()
	world._check_hazards()
	if world.is_dying() or not blast.alive:
		return false

	# ⑥ 無敵退場 → 同一個位置就要死，死因對得上
	world.player.invuln_timer = 0.0
	world._check_hazards()
	_settle_death(world)
	if world.last_cause != WellWorld.CAUSE_BLAST:
		return false

	# ⑦ 爆炸區壽命到自己消失（不靠任何人清）
	world._dying = false
	var guard2 := int(SpikeConfig.EXPLOSIVE_BLAST_TIME / DT) + 8
	for _i in range(guard2):
		blast.step(DT)
	if blast.alive:
		return false

	world.gen.platforms.clear()
	world._blasts.clear()
	world.player.invuln_timer = 0.0
	return true


func _audit_doom(world: WellWorld) -> bool:
	var itf := Interference.new()
	itf.reset()
	var player_pos := Vector2(SpikeConfig.VIEW_W * 0.5, 0.0)

	# 玩家上方擺一排候選平台。⚠ 要放得夠多：這條測試會一路跑到 127s，中間抽跳板
	#    已經把好幾塊標記走（被標記的板不給開洞），只放 6 塊會全被吃光、洞永遠開不出來。
	var plats: Array = []
	for i in range(24):
		var p := WellPlatform.new()
		p.kind = WellPlatform.Kind.STATIC
		p.size = SpikeConfig.PLATFORM_SIZE
		p.pos = Vector2(
			SpikeConfig.WELL_LEFT + 80.0 + fmod(90.0 * i, 800.0), -150.0 - 130.0 * i
		)
		plats.append(p)

	# ① 跑到第四階解鎖之後，預警要自己冒出來
	var t := 0.0
	var limit: float = SpikeConfig.interference_start + SpikeConfig.stage_doom_offset \
		+ SpikeConfig.doom_interval_start + 5.0
	while itf.doom_warns.is_empty() and t < limit:
		t += DT
		itf.update(DT, t, player_pos, -SpikeConfig.VIEW_H, plats)
	if itf.doom_warns.is_empty() or not itf.dooms.is_empty():
		return false

	var warn = itf.doom_warns[0]
	var warn_pos: Vector2 = warn.pos
	if warn.host == null:
		return false
	# 只挑上方第 DOOM_MIN_INDEX_ABOVE 塊起——開在腳下那塊等於無預警處決。
	# ⚠ 排名要對「當下真正的候選池」算（已被抽跳板標記的板不算），不能拿原始陣列比。
	var cands: Array = []
	for p in plats:
		if p.alive and p.steal_warn < 0.0 and p.pos.y < player_pos.y:
			cands.append(p)
	cands.sort_custom(func(a, b): return a.pos.y > b.pos.y)
	for i in range(mini(SpikeConfig.DOOM_MIN_INDEX_ABOVE, cands.size())):
		if cands[i] == warn.host:
			return false

	# ② 預警期間不得有洞，時間到才開，而且開在紫圈的位置
	var guard := 0
	var max_frames := int(FPS * (SpikeConfig.DOOM_WARN_TIME + 1.0))
	while itf.dooms.is_empty() and guard < max_frames:
		t += DT
		itf.update(DT, t, player_pos, -SpikeConfig.VIEW_H, plats)
		guard += 1
	if itf.dooms.is_empty():
		return false
	if guard < int(FPS * SpikeConfig.DOOM_WARN_TIME) - 2:
		return false
	var doom = itf.dooms[0]
	if doom.pos.distance_to(warn_pos) > 0.5:
		return false

	# ③ 吸力：範圍內指向洞心，範圍外歸零
	var near: Vector2 = doom.pos + Vector2(SpikeConfig.DOOM_PULL_RADIUS * 0.5, 0.0)
	var pull := itf.pull_velocity_at(near)
	var pulls_inward: bool = pull.x < 0.0 and pull.length() > 0.0 \
		and pull.length() <= SpikeConfig.DOOM_PULL_MAX_SPEED
	var far: Vector2 = doom.pos + Vector2(SpikeConfig.DOOM_PULL_RADIUS + 10.0, 0.0)
	var no_pull_outside: bool = itf.pull_velocity_at(far) == Vector2.ZERO
	# ⚠ 吸力不得超過玩家全速，否則進了範圍就是必死的運氣牆
	var escapable: bool = SpikeConfig.DOOM_PULL_MAX_SPEED < SpikeConfig.KB_MOVE_MAX_SPEED

	# ④ 碰到即死 / 無敵中碰到＝消掉洞。走真實的 _check_hazards
	# ⚠ 先清掉投擲物：_check_hazards 是「碰到第一個就 return」，剛好有一發疊在洞上
	#    的話會死在投擲物手上，黑洞這條就測不到（偶發紅燈比沒測還糟）
	itf.projectiles.clear()
	world.gen.monsters.clear()
	world.interference = itf
	world.player.pos = doom.pos
	world.player.invuln_timer = 0.0
	var dead := {"v": false}
	var cb := func(_c: String): dead["v"] = true
	world.died.connect(cb)
	world._check_hazards()
	_settle_death(world)
	var killed: bool = dead["v"] and doom.alive

	world.player.refresh_invuln()
	world._check_hazards()
	var erased: bool = not doom.alive
	world.died.disconnect(cb)
	world.player.invuln_timer = 0.0

	# ⑤ 壽命到會自己塌縮（不設會讓上方累積一堆永久死區）
	itf.dooms = [doom]
	doom.alive = true
	doom.life = SpikeConfig.DOOM_LIFETIME
	var f := 0
	var max_life_frames := int(FPS * (SpikeConfig.DOOM_LIFETIME + 1.0))
	while not itf.dooms.is_empty() and f < max_life_frames:
		t += DT
		itf.update(DT, t, player_pos, -SpikeConfig.VIEW_H, plats)
		f += 1
		# 這段可能又生出新的洞，只看原本那顆有沒有塌
		if not doom.alive:
			break
	var collapsed: bool = not doom.alive

	world.interference = Interference.new()
	world.interference.reset()
	return pulls_inward and no_pull_outside and escapable \
		and killed and erased and collapsed


## 墓碑（v12）：只在有歷史紀錄時生成，立在 y 軸最相近的平台上，碰到給 TOMB_COIN_REWARD。
## ⚠ 「最相近」要對整座井驗，不能只比相鄰兩塊——同區間的額外跳板落在主鏈那顆稍下方，
##   很可能才是真正最近的那個。
func _audit_tomb(world: WellWorld) -> bool:
	var best_h := 240.0
	var gen := WellGenerator.new()
	gen.setup(0.0, 20260808, best_h)
	gen.ensure_generated_to(SpikeConfig.goal_y(0.0) - 10.0)

	var tombs: Array = []
	for pk in gen.pickups:
		if pk.kind == WellPickup.Kind.TOMB:
			tombs.append(pk)
	if tombs.size() != 1:
		return false

	var host: WellPlatform = tombs[0].host
	if host == null:
		return false
	# 蟲洞跟墓碑搶同一個掛點，是唯一被允許的「讓位」對象，掃描時要一併排除
	var wh_hosts := {}
	for wh in gen.wormholes:
		wh_hosts[wh.host] = true

	var target_y: float = -best_h * SpikeConfig.PIXELS_PER_METER
	var host_d: float = absf(host.center().y - target_y)
	for p in gen.platforms:
		if p.is_goal or wh_hosts.has(p):
			continue
		if absf(p.center().y - target_y) < host_d - 0.5:
			return false

	# 沒有歷史紀錄（第一次玩）就不該有墓碑
	var gen0 := WellGenerator.new()
	gen0.setup(0.0, 20260808, 0.0)
	gen0.ensure_generated_to(SpikeConfig.goal_y(0.0) - 10.0)
	for pk in gen0.pickups:
		if pk.kind == WellPickup.Kind.TOMB:
			return false

	# 碰到給錢：走真實的 _check_pickups，不直接改計數
	world.gen.pickups.clear()
	var tomb := WellPickup.new()
	tomb.set_kind(WellPickup.Kind.TOMB)
	tomb.pos = world.player.pos
	world.gen.pickups.append(tomb)
	var before := world.coin_count
	world._check_pickups()
	var paid: bool = not tomb.alive \
		and world.coin_count == before + SpikeConfig.TOMB_COIN_REWARD
	world.gen.pickups.clear()
	return paid
