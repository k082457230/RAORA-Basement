extends Node
## 開局三選一增益的稽核（08-12，SpikeConfig SECTION 8e）。對外入口 _audit_buffs()。
##
## 分四組：
##   A 佈局與關卡門檻 — 生成器層面（不跑物理）
##   B 選取行為       — 碰到一顆會發生什麼
##   C 八種效果       — 逐條餵真實狀態進真實函式
##   D 常數不變式     — 常數彼此之間必須成立的關係（行為稽核驗不到的那個盲點，
##                      範本見 audit_hazards.gd _audit_pameloe 的 consts_ok）
##
## ⚠ 逐項印出來而不是回一個合成的 bool：二十幾條併成一句「其中一項有問題」時，
##   查是哪一條得回來讀整個檔，診斷成本比印幾行高太多（同 _audit_pameloe 的處理）。

const FPS := 60.0
const DT := 1.0 / FPS

## 稽核用的固定 seed。⚠ 不要為了讓某條過而換這顆——換 seed 續命是 HANDOFF Deferred
##   第 1b 條明文禁止的事。
const SEED := 20260812


func _audit_buffs() -> bool:
	var checks := {}
	_audit_layout(checks)
	_audit_selection(checks)
	_audit_effects(checks)
	_audit_second_row(checks)
	_audit_dual_hold(checks)
	_audit_petrify_spin(checks)
	_audit_consts(checks)

	var bad := PackedStringArray()
	for k in checks:
		if not checks[k]:
			bad.append(String(k))

	print("--- 增益稽核（開局三選一 / 八種效果）---")
	if bad.is_empty():
		print("  佈局、關卡門檻、RNG 隔離、選取與爆炸、隨機展開、護盾、鳳梨披薩、時間藥水、"
			+ "金錢彈、DAHLAH、HUD 變暗、1000m 第二組、雙 buff 並存、石化轉速、常數不變式"
			+ " — %d 項全通過" % checks.size())
	else:
		print("  !! 增益失敗細項：%s" % ", ".join(bad))
	return bad.is_empty()


# ------------------------------------------------------------------
# A. 佈局與關卡門檻
# ------------------------------------------------------------------

## ⚠ 直接用 WellGenerator 而不是 WellWorld：這一組驗的是「井長什麼樣」，不需要物理，
##   也不該去動 SpikeSave.selected_level（那會連帶改 goal_meters，還原漏一步就污染
##   後面所有稽核——常青認知第 4 條）。
func _audit_layout(checks: Dictionary) -> void:
	var g1 := WellGenerator.new()
	g1.setup(0.0, SEED, 0.0, 0)
	checks["關卡一沒有三選一"] = g1.buff_orbs.is_empty()

	var g2 := WellGenerator.new()
	g2.setup(0.0, SEED, 0.0, 1)
	var n: int = SpikeConfig.BUFF_ROW_X_FRACS.size()
	checks["關卡二有三顆"] = g2.buff_orbs.size() == n

	var g3 := WellGenerator.new()
	g3.setup(0.0, SEED, 0.0, 2)
	checks["關卡三有三顆"] = g3.buff_orbs.size() == n

	if g2.buff_orbs.size() != n:
		# 後面每一條都建立在「有三顆」之上，沒有就直接標紅、不要拿空陣列去算
		checks["三顆不重複"] = false
		checks["選擇層同高且全 STATIC"] = false
		checks["列 A 兩塊且同高全 STATIC"] = false
		checks["起跳板跳得到列 A"] = false
		checks["列 B 三塊且同高全 STATIC"] = false
		checks["列 A 跳得到列 B"] = false
		checks["列 B 跳得到三選一排"] = false
		checks["列 A／列 B 不穿井壁"] = false
		checks["縫寬過得去玩家"] = false
		checks["選擇層不穿井壁"] = false
		return

	# ① 三顆 key 不重複
	var seen := {}
	for orb in g2.buff_orbs:
		seen[orb.key] = true
	checks["三顆不重複"] = seen.size() == n

	# ② 選擇層：同一個 y、全部 STATIC
	# ⚠ 靠 orb.host 認人而不是「平台陣列的最後三塊」：後者是從幾何／順序反推身分，
	#   正是常青認知第 9／10 條那兩次教訓的來源。
	var row_y: float = g2.buff_orbs[0].host.pos.y
	var same_y := true
	var all_static := true
	var xs: Array[float] = []
	for orb in g2.buff_orbs:
		var host: WellPlatform = orb.host
		if host == null:
			same_y = false
			all_static = false
			break
		if not is_equal_approx(host.pos.y, row_y):
			same_y = false
		if host.kind != WellPlatform.Kind.STATIC:
			all_static = false
		xs.append(host.pos.x)
	checks["選擇層同高且全 STATIC"] = same_y and all_static
	xs.sort()

	# ③ 列 A（2 塊，08-12 四訂新增）：同高、全 STATIC、起跳板（置中不動）跳得到每一塊。
	var mid_x: float = (SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5
	var half_w: float = SpikeConfig.PLATFORM_SIZE.x * 0.5
	var row_a_shape_ok: bool = g2.buff_intro_row_a.size() \
		== SpikeConfig.BUFF_INTRO_ROW_A_X_OFFSETS.size()
	var row_a_xs: Array[float] = []
	if row_a_shape_ok:
		var row_a_y: float = g2.buff_intro_row_a[0].pos.y
		for p in g2.buff_intro_row_a:
			var plat_p: WellPlatform = p
			if plat_p.kind != WellPlatform.Kind.STATIC \
					or not is_equal_approx(plat_p.pos.y, row_a_y):
				row_a_shape_ok = false
			row_a_xs.append(plat_p.pos.x)
	checks["列 A 兩塊且同高全 STATIC"] = row_a_shape_ok

	var start_win: Vector2 = g2._reachable_window(mid_x, SpikeConfig.PLATFORM_SIZE, 0.0)
	var start_to_a_ok := row_a_shape_ok
	for x in row_a_xs:
		if x < start_win.x - 0.001 or x > start_win.y + 0.001:
			start_to_a_ok = false
	checks["起跳板跳得到列 A"] = start_to_a_ok

	# ④ 列 B（3 塊）：同高、全 STATIC、每一塊都有列 A 的某一塊跳得到（不要求全部都跳
	#    得到，只要求「存在一條路」——同三選一排本來就允許左右兩塊各走各的路徑）。
	var row_b_shape_ok: bool = g2.buff_intro_row_b.size() \
		== SpikeConfig.BUFF_INTRO_ROW_B_X_OFFSETS.size()
	var row_b_xs: Array[float] = []
	if row_b_shape_ok:
		var row_b_y: float = g2.buff_intro_row_b[0].pos.y
		for p in g2.buff_intro_row_b:
			var plat_p: WellPlatform = p
			if plat_p.kind != WellPlatform.Kind.STATIC \
					or not is_equal_approx(plat_p.pos.y, row_b_y):
				row_b_shape_ok = false
			row_b_xs.append(plat_p.pos.x)
	checks["列 B 三塊且同高全 STATIC"] = row_b_shape_ok

	var a_to_b_ok := row_a_shape_ok and row_b_shape_ok
	if a_to_b_ok:
		for x in row_b_xs:
			if not _reachable_from_any(g2, row_a_xs, x):
				a_to_b_ok = false
	checks["列 A 跳得到列 B"] = a_to_b_ok

	# ⑤ 三選一排：每一塊都有列 B 的某一塊跳得到（同上，容許不同側各走各的路）
	var b_to_c_ok := row_b_shape_ok
	if b_to_c_ok:
		for x in xs:
			if not _reachable_from_any(g2, row_b_xs, x):
				b_to_c_ok = false
	checks["列 B 跳得到三選一排"] = b_to_c_ok

	# ⑥ 列 A／列 B 也不得穿出井壁（同選擇層那條約束，見 BUFF_INTRO_ROW_A/B_X_OFFSETS 的 ⚠）
	var ab_walls_ok := row_a_shape_ok and row_b_shape_ok
	for x in row_a_xs + row_b_xs:
		if x - half_w < SpikeConfig.WELL_LEFT or x + half_w > SpikeConfig.WELL_RIGHT:
			ab_walls_ok = false
	checks["列 A／列 B 不穿井壁"] = ab_walls_ok

	# ⑦ 兩兩之間的縫要寬過玩家（約束②：使用者拍板「能跳過，不強制」，只約束三選一排）
	var gap_ok := true
	for i in range(xs.size() - 1):
		var gap: float = (xs[i + 1] - xs[i]) - SpikeConfig.PLATFORM_SIZE.x
		if gap <= SpikeConfig.PLAYER_SIZE.x:
			gap_ok = false
	checks["縫寬過得去玩家"] = gap_ok

	# ⑧ 三選一排最外側不得穿出井壁（約束③）
	checks["選擇層不穿井壁"] = xs[0] - half_w >= SpikeConfig.WELL_LEFT \
		and xs[xs.size() - 1] + half_w <= SpikeConfig.WELL_RIGHT

	# ⑨ 增益球要浮在板子上方，不能埋進板裡
	var hover_ok := true
	for orb in g2.buff_orbs:
		if orb.pos.y >= orb.host.top_y():
			hover_ok = false
	checks["球浮在板上方"] = hover_ok

	# ⑩ 同一顆 seed 兩次結果一致（決定性）。⚠ 沒有這條的話「_buff_rng 忘了設 seed、
	#    每次都 randomize」會完全靜默——玩起來也很正常，只是再也不能重現。
	var g2b := WellGenerator.new()
	g2b.setup(0.0, SEED, 0.0, 1)
	var same_picks := g2b.buff_orbs.size() == g2.buff_orbs.size()
	if same_picks:
		for i in range(g2.buff_orbs.size()):
			if g2.buff_orbs[i].key != g2b.buff_orbs[i].key:
				same_picks = false
	checks["同 seed 抽到同一組"] = same_picks

	# ⑪⚠⚠ **RNG 隔離**：抽 buff 不准動到主生成序列。
	#    做法＝同一顆 seed 分別跑關卡一（不建三選一）與關卡二（建），然後各問主 _rng
	#    要下一個亂數——setup() 之後主 _rng 還沒被用過，所以兩邊必須完全相同。
	#    ⚠ 這條是整組稽核裡最重要的一條：抽 buff 若骰在主序列上，關卡二／三的整座井會
	#      相對關卡一整體偏移，而所有以固定 seed 跑的既有稽核**照樣全綠**，只是驗的
	#      已經不是原本那件事了。
	var a := WellGenerator.new()
	a.setup(0.0, SEED, 0.0, 0)
	var b := WellGenerator.new()
	b.setup(0.0, SEED, 0.0, 1)
	checks["抽 buff 不污染主 RNG"] = is_equal_approx(a._rng.randf(), b._rng.randf())


## to_x 有沒有被 from_xs 裡至少一個 x 跳得到。用於驗證「這一列的每一塊，都有上一列
## 的某一塊跳得到」——不要求全部前一列的塊子都跳得到同一塊，只要求存在一條路徑
## （同三選一排本來就允許左右兩塊各走各的路，不強制每個起點都通往每個終點）。
func _reachable_from_any(g: WellGenerator, from_xs: Array, to_x: float) -> bool:
	for fx in from_xs:
		var win: Vector2 = g._reachable_window(fx, SpikeConfig.PLATFORM_SIZE, 0.0)
		if to_x >= win.x - 0.001 and to_x <= win.y + 0.001:
			return true
	return false


# ------------------------------------------------------------------
# B. 選取行為
# ------------------------------------------------------------------

## 碰到一顆＝選它，三顆全部爆掉（含被選中的那顆），爆完會消失。
func _audit_selection(checks: Dictionary) -> void:
	var world := WellWorld.new()
	add_child(world)
	world.set_process(false)
	world.gen.setup(0.0, SEED, 0.0, 1)

	var orbs: Array = world.gen.buff_orbs
	if orbs.size() < 2:
		checks["碰到就選中"] = false
		checks["其餘兩顆爆掉"] = false
		checks["爆完會消失"] = false
		checks["隨機展開成別的"] = false
		remove_child(world)
		world.queue_free()
		return

	var target: WellBuffOrb = orbs[0]
	world.player.pos = target.pos
	world._check_buff_orbs()

	checks["碰到就選中"] = world.buffs.size() == 1 \
		and not world.has_buff(SpikeConfig.BUFF_RANDOM_KEY)

	# ⚠ 連被選中的那顆也要爆：留在原地會讓玩家以為還能再選一次。
	var all_exploding := true
	for o in orbs:
		if not o.exploding:
			all_exploding = false
	checks["其餘兩顆爆掉"] = all_exploding

	# 選中之後再碰一次不得改變 buff（三選一是一次性的）
	var before: Array = world.buffs.duplicate(true)
	world._check_buff_orbs()
	checks["選過就不能再選"] = world.buffs.size() == before.size() \
		and (before.is_empty() or String(world.buffs[0]["key"]) == String(before[0]["key"]))

	# 爆炸演完會 alive = false
	for o in orbs:
		o.step(SpikeConfig.BUFF_ORB_EXPLODE_TIME + DT)
	var all_gone := true
	for o in orbs:
		if o.alive:
			all_gone = false
	checks["爆完會消失"] = all_gone

	# ⚠ 「隨機」必須在**選中的那一刻**展開，而且展開結果不得還是 random。
	#   直接餵一顆 random 球進去走真實路徑（_select_buff_orb），不呼叫內部展開函式。
	var w2 := WellWorld.new()
	add_child(w2)
	w2.set_process(false)
	w2.gen.setup(0.0, SEED, 0.0, 1)
	var rnd := WellBuffOrb.new()
	rnd.key = SpikeConfig.BUFF_RANDOM_KEY
	rnd.pos = w2.player.pos
	w2.gen.buff_orbs.append(rnd)
	w2._check_buff_orbs()
	checks["隨機展開成別的"] = w2.buffs.size() == 1 \
		and not w2.has_buff(SpikeConfig.BUFF_RANDOM_KEY) \
		and SpikeConfig.BUFF_TABLE.has(String(w2.buffs[0]["key"]))

	remove_child(w2)
	w2.queue_free()
	remove_child(world)
	world.queue_free()


# ------------------------------------------------------------------
# C. 八種效果
# ------------------------------------------------------------------

func _audit_effects(checks: Dictionary) -> void:
	_audit_shield(checks)
	_audit_pizza(checks)
	_audit_time_potion(checks)
	_audit_coin_bullet(checks)
	_audit_dahlah(checks)
	_audit_hud_dim(checks)


## 護盾：擋一次非掉落死亡、不擋掉落、擋完歸零、擋下時開無敵窗。
func _audit_shield(checks: Dictionary) -> void:
	var world := _fresh_world()
	world.grant_buff("shield", 1)

	# ① 擋得下怪物那種死法，而且**不寫 last_cause**（不能污染結算的死因）
	var absorbed: bool = world._buff_shield_absorb(WellWorld.CAUSE_MONSTER)
	checks["護盾擋得下"] = absorbed and not world.is_dying() \
		and world.last_cause == "" and world.buff_uses_left("shield") == 0

	# ②⚠⚠ 擋下的同時要開無敵窗：沒有它的話，玩家跟殺死他的東西還重疊著，
	#    下一幀會再判一次死——一次接觸就把盾吃光。這是保命條款不是裝飾。
	checks["護盾擋下給無敵"] = world.player.is_invulnerable() \
		and world.player.invuln_timer >= SpikeConfig.BUFF_SHIELD_INVULN - 0.001

	# ③ 用完了就擋不住
	checks["護盾用完失效"] = not world._buff_shield_absorb(WellWorld.CAUSE_MONSTER)

	# ④ 掉落（使用者規格「掉落除外」）一律擋不住，就算次數還在
	var w2 := _fresh_world()
	w2.grant_buff("shield", 1)
	var fall_absorbed: bool = w2._buff_shield_absorb(WellWorld.CAUSE_FALL)
	checks["護盾不擋掉落"] = not fall_absorbed and w2.buff_uses_left("shield") == 1

	_drop_world(world)
	_drop_world(w2)


## 鳳梨披薩：殺光**畫面上**的敵人。畫面外的不動（殺了玩家看不到＝白按一次）。
func _audit_pizza(checks: Dictionary) -> void:
	var world := _fresh_world()
	world.grant_buff("pizza")

	var inside := WellMonster.new()
	inside.pos = Vector2(world.player.pos.x + 40.0, world.player.pos.y)
	world.gen.monsters.append(inside)

	var outside := WellMonster.new()
	outside.pos = Vector2(world.player.pos.x, world._view_bottom() + 800.0)
	world.gen.monsters.append(outside)

	var used: bool = world.use_buff()
	checks["披薩殺畫面內"] = used and inside.dying and not inside.alive
	checks["披薩不殺畫面外"] = outside.alive and not outside.dying
	checks["披薩扣次數"] = world.buff_uses_left("pizza") \
		== SpikeConfig.buff_uses_of("pizza") - 1

	# 使用瞬間要留下一圈外擴特效（08-12 四訂，使用者規格「向外發出同心圓」）。
	# ⚠ 不直接呼叫 _draw_pizza_fx()：Godot 的 draw_* 只能在真正的 _draw() 回呼裡呼叫，
	#   這裡驗的是觸發特效的**狀態**（陣列有沒有進東西、時間到有沒有清掉），不是畫面本身
	#   ——同專案「畫面本身只能人眼看」的既有分工（visual_check.tscn 那條路）。
	checks["披薩觸發外擴特效"] = world._pizza_fx.size() == 1 \
		and world._pizza_fx[0]["pos"].distance_to(world.player.pos) < 0.001
	world._tick_pizza_fx(SpikeConfig.BUFF_PIZZA_FX_DURATION + DT)
	checks["披薩特效演完會清掉"] = world._pizza_fx.is_empty()

	_drop_world(world)


## 時間藥水：敵人與干擾凍結，**平台照常動**（凍平台等於抽走落點，見 SECTION 8e 的 ⚠⚠）。
## ⚠ 走 _process() 真實迴圈，不是直接讀計時器——「凍結」這件事的正確性完全在於
##   _process 有沒有真的跳過那幾行（專案 CLAUDE.md 硬規則 7）。
func _audit_time_potion(checks: Dictionary) -> void:
	var world := _fresh_world()
	world.running = true
	world.grant_buff("time")

	# 一隻會巡邏的怪 ＋ 一塊會左右移動的板，兩者在凍結期間的表現必須相反
	var host := WellPlatform.new()
	host.kind = WellPlatform.Kind.MOVING
	host.size = SpikeConfig.PLATFORM_SIZE
	host.pos = Vector2(world.player.pos.x, world.player.pos.y + 300.0)
	host.move_min_x = host.pos.x - 60.0
	host.move_max_x = host.pos.x + 60.0
	host.move_speed = SpikeConfig.MOVING_SPEED_MAX
	world.gen.platforms.append(host)

	var mon := WellMonster.new()
	mon.host = host
	mon.pos = Vector2(host.pos.x, host.top_y() - 20.0)
	world.gen.monsters.append(mon)

	world.use_buff()
	checks["時間藥水開凍結"] = world.buff_frozen()

	# 使用瞬間同披薩那條，留下一圈外擴特效（同樣只驗狀態，不呼叫 draw_*，理由見上方 ⚠）。
	checks["時間藥水觸發外擴特效"] = world._time_fx.size() == 1 \
		and world._time_fx[0]["pos"].distance_to(world.player.pos) < 0.001
	world._tick_time_fx(SpikeConfig.BUFF_TIME_FX_DURATION + DT)
	checks["時間藥水特效演完會清掉"] = world._time_fx.is_empty()

	# 凍結期間敵人要套藍色濾鏡（使用者規格）；沒凍結時濾鏡是純白（乘法不改變原色，
	# 見 _frozen_tint 的 ⚠）。這裡驗的是濾鏡色本身，不是貼圖畫出來的樣子。
	checks["凍結期間套藍色濾鏡"] = world._frozen_tint() == SpikeConfig.C_BUFF_FROZEN_TINT

	var mon_x0: float = mon.pos.x
	var plat_x0: float = host.pos.x
	for _i in range(10):
		world._process(DT)

	checks["凍結期間怪物不動"] = is_equal_approx(mon.pos.x, mon_x0)
	checks["凍結期間平台照動"] = not is_equal_approx(host.pos.x, plat_x0)

	# 時間到要自己解除。⚠ 沒有這條的話「減法寫成 >= 0」那種寫法會變成永久凍結，
	#   而永久凍結玩起來只是「這局特別簡單」，不會有人當成 bug 回報。
	# ⚠⚠ 這裡直接推進 _tick_buff_freeze，**不是**再跑 300 幀 _process：這個測試世界裡
	#   玩家腳下沒有板，跑滿 5 秒他會自由落體掉出畫面 ⇒ _dying ⇒ _process 第一行就
	#   return ⇒ 計時器反而永遠不動，這條會假紅（08-12 實錄，第一版就是這樣）。
	#   「時間到會解除」的邏輯整個住在 _tick_buff_freeze 裡，直接餵它就是走真實路徑。
	world._tick_buff_freeze(SpikeConfig.BUFF_TIME_FREEZE_DURATION)
	checks["凍結會結束"] = not world.buff_frozen()
	checks["解凍後濾鏡歸純白"] = world._frozen_tint() == Color(1.0, 1.0, 1.0)

	_drop_world(world)


## 金錢彈：錢不夠不能用、錢夠就扣錢射出、命中殺怪、沒目標不扣任何東西。
func _audit_coin_bullet(checks: Dictionary) -> void:
	var world := _fresh_world()
	world.grant_buff("coingun")

	var mon := WellMonster.new()
	mon.pos = Vector2(world.player.pos.x + 120.0, world.player.pos.y)
	world.gen.monsters.append(mon)

	# ① 錢不夠：不能用、不扣錢、不射出
	world.coin_count = SpikeConfig.BUFF_COIN_BULLET_COST - 1
	var poor_used: bool = world.use_buff()
	checks["金錢彈沒錢不能用"] = not poor_used and not world.buff_ready() \
		and world.coin_bullet_count == 0 \
		and world.coin_count == SpikeConfig.BUFF_COIN_BULLET_COST - 1

	# ② 錢夠：扣錢、射出一發
	world.coin_count = SpikeConfig.BUFF_COIN_BULLET_COST + 2
	var rich_used: bool = world.use_buff()
	checks["金錢彈射得出去"] = rich_used and world.coin_bullet_count == 1 \
		and world.coin_count == 2

	# ③ 飛過去要打死牠。⚠ 用 _tick_coin_bullets 真實路徑推進，不直接呼叫 _kill_monster。
	for _i in range(60):
		if not mon.alive:
			break
		world._tick_coin_bullets(DT)
	checks["金錢彈命中殺怪"] = mon.dying and not mon.alive

	# ④ 場上沒有目標時：不扣錢、不扣次數（見 _use_coin_bullet 的回傳值）
	var w2 := _fresh_world()
	w2.grant_buff("coingun")
	w2.coin_count = SpikeConfig.BUFF_COIN_BULLET_COST + 5
	var no_target_used: bool = w2.use_buff()
	checks["沒目標不扣錢"] = not no_target_used \
		and w2.coin_count == SpikeConfig.BUFF_COIN_BULLET_COST + 5 \
		and w2.coin_bullet_count == 0

	_drop_world(world)
	_drop_world(w2)


## DAHLAH：每次起跳的高度倍率在 [MIN, MAX] 之間隨機。
## ⚠⚠ 驗的是**高度**倍率不是初速倍率——實作把倍率開了根號（h = v²/2g）。少了這條，
##   「忘記開根號」會讓 2.0 倍變成 4 倍高，而那看起來只是「這顆 buff 很強」。
func _audit_dahlah(checks: Dictionary) -> void:
	var world := _fresh_world()
	var base: float = SpikeSave.jump_velocity()
	var base_h: float = base * base / (2.0 * SpikeConfig.GRAVITY)

	# 沒拿這顆 buff 時完全不變
	checks["沒 DAHLAH 就不變"] = is_equal_approx(world._jump_velocity_now(), base)

	world.grant_buff("dahlah")
	var in_range := true
	var saw_variation := false
	var first: float = world._jump_velocity_now()
	for _i in range(200):
		var v: float = world._jump_velocity_now()
		var h: float = v * v / (2.0 * SpikeConfig.GRAVITY)
		var mult: float = h / base_h
		if mult < SpikeConfig.BUFF_DAHLAH_MIN - 0.001 \
				or mult > SpikeConfig.BUFF_DAHLAH_MAX + 0.001:
			in_range = false
		if not is_equal_approx(v, first):
			saw_variation = true
	checks["DAHLAH 高度倍率在範圍內"] = in_range
	# ⚠ 「真的有在變」要單獨驗：實作若寫成永遠回 MIN，上面那條照樣全綠。
	checks["DAHLAH 每次都重骰"] = saw_variation

	_drop_world(world)


## HUD 變暗的三種理由（使用者規格）。
## ⚠ 這條在驗 buff_dimmed() 而不是 buff_ready()：後者對被動型一律回 false，拿來當
##   變暗依據會讓護盾／石化一拿到就是暗的。
func _audit_hud_dim(checks: Dictionary) -> void:
	var world := _fresh_world()

	# ⚠ 08-13 起 buff 是清單，buff_dimmed 吃格號。每一小段各自用一個乾淨的世界，
	#   免得前一段留下來的那格把格號推掉一位（同一個世界連續 grant 會累積成兩格）。
	# ① 被動型永遠不暗（沒有「用完」這回事）
	world.grant_buff("petrify")
	var passive_bright: bool = not world.buff_dimmed(0)

	# ② 有限次數的用完才暗
	var wp := _fresh_world()
	wp.grant_buff("pizza", 1)
	var has_use_bright: bool = not wp.buff_dimmed(0)
	wp.buffs[0]["uses"] = 0
	var used_up_dim: bool = wp.buff_dimmed(0)

	# ③ 金錢彈看錢夠不夠（次數是無限的 -1，所以只能靠這個條件）
	var wc := _fresh_world()
	wc.grant_buff("coingun")
	wc.coin_count = 0
	var broke_dim: bool = wc.buff_dimmed(0)
	wc.coin_count = SpikeConfig.BUFF_COIN_BULLET_COST
	var rich_bright: bool = not wc.buff_dimmed(0)
	_drop_world(wp)
	_drop_world(wc)

	checks["HUD 被動型不變暗"] = passive_bright
	checks["HUD 用完才變暗"] = has_use_bright and used_up_dim
	checks["HUD 錢不夠變暗"] = broke_dim and rich_bright

	_drop_world(world)


# ------------------------------------------------------------------
# E. 1000m 第二組三選一（08-13 項目 6）
# ------------------------------------------------------------------

## 五件事：只有關卡三有、擺在 1000m 之後、選項與第一組完全不重複、擺設跟開局那組一致、
## 而且**插進串流生成之後主 RNG 序列不變**（同 A 組那條 ⚠⚠ 的理由）。
## ⚠ 走 ensure_generated_to 真實串流路徑，不是直接呼叫 _build_buff_ladder——「爬到那個
##   高度時會不會長出來」正是這條要驗的東西（專案 CLAUDE.md 硬規則 7）。
func _audit_second_row(checks: Dictionary) -> void:
	var top_y: float = -(SpikeConfig.BUFF_SECOND_HEIGHT_M + 200.0) * SpikeConfig.PIXELS_PER_METER

	var g2 := WellGenerator.new()
	g2.setup(0.0, SEED, 0.0, 1)
	g2.ensure_generated_to(top_y)
	var n: int = SpikeConfig.BUFF_ROW_X_FRACS.size()
	# 關卡二爬到同一個高度也不該長出第二組（只有開局那三顆，而且早就被 prune 之外仍在陣列裡）
	var g2_second := 0
	for orb in g2.buff_orbs:
		if orb.group == 1:
			g2_second += 1
	checks["關卡二沒有第二組"] = g2_second == 0

	var g3 := WellGenerator.new()
	g3.setup(0.0, SEED, 0.0, 2)
	g3.ensure_generated_to(top_y)
	var first: Array = []
	var second: Array = []
	for orb in g3.buff_orbs:
		if orb.group == 0:
			first.append(orb.key)
		elif orb.group == 1:
			second.append(orb)
	checks["關卡三 1000m 有三顆"] = second.size() == n

	if second.size() != n:
		checks["第二組與第一組不重複"] = false
		checks["第二組在 1000m 之上"] = false
		checks["第二組擺設同開局"] = false
	else:
		var dup := false
		for orb in second:
			if first.has(orb.key):
				dup = true
		checks["第二組與第一組不重複"] = not dup

		# 高度：三顆都要在門檻高度之上（生成當下用的是「上一塊」的高度，所以實際會更高）
		var above := true
		for orb in second:
			if SpikeConfig.meters_from_y(0.0, orb.pos.y) < SpikeConfig.BUFF_SECOND_HEIGHT_M:
				above = false
		checks["第二組在 1000m 之上"] = above

		# 擺設一致：兩列中繼板的塊數與 x 偏移跟開局那組完全相同
		var same_layout: bool = g3.buff_second_row_a.size() \
				== SpikeConfig.BUFF_INTRO_ROW_A_X_OFFSETS.size() \
			and g3.buff_second_row_b.size() == SpikeConfig.BUFF_INTRO_ROW_B_X_OFFSETS.size()
		if same_layout:
			var mid_x: float = (SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5
			for i in range(g3.buff_second_row_a.size()):
				var want: float = mid_x + SpikeConfig.BUFF_INTRO_ROW_A_X_OFFSETS[i]
				if not is_equal_approx(g3.buff_second_row_a[i].pos.x, want):
					same_layout = false
			for i in range(g3.buff_second_row_b.size()):
				var want_b: float = mid_x + SpikeConfig.BUFF_INTRO_ROW_B_X_OFFSETS[i]
				if not is_equal_approx(g3.buff_second_row_b[i].pos.x, want_b):
					same_layout = false
		checks["第二組擺設同開局"] = same_layout

	# ⚠⚠ 插入第二組**一顆主亂數都不准用掉**（同 A 組「抽 buff 不污染主 RNG」的理由：
	#   固定佈局若吃了 _rng，同一顆 seed 的井會整段偏移，而既有稽核照樣全綠）。
	# ⚠ 這裡比的是 RNG 的 state 而不是「兩座井跑到同一高度後的下一個亂數」——後者本來就
	#   會不同：第二組把主鏈往上推了 3 道固定間距，關卡三要少生幾塊隨機平台才到得了同一
	#   高度，_generate_next 的呼叫次數不同，亂數當然也走到不同的位置。（第一版就是寫成
	#   那樣才紅的：紅的是斷言不是實作。）
	var probe := WellGenerator.new()
	probe.setup(0.0, SEED, 0.0, 2)
	var state_before: int = probe._rng.state
	probe._build_buff_ladder(1)
	checks["第二組不污染主 RNG"] = probe._rng.state == state_before


# ------------------------------------------------------------------
# F. 雙 buff 並存（08-13 項目 6，使用者拍板「主動疊兩顆、被動也同時生效」）
# ------------------------------------------------------------------

func _audit_dual_hold(checks: Dictionary) -> void:
	# ① 主動 ×2：先拿到的先用完
	var w := _fresh_world()
	w.grant_buff("pizza", 1)
	w.grant_buff("time", 2)
	checks["兩顆並存"] = w.buffs.size() == 2
	checks["優先用最舊的"] = w.active_buff_index() == 0
	w.use_buff()
	# 舊那顆歸零之後，同一顆鍵要自動接手新那顆——不是整顆鍵變成廢的
	checks["舊的用完換新的"] = w.buff_uses_left("pizza") == 0 \
		and w.active_buff_index() == 1 \
		and w.buff_ready()
	w.use_buff()
	checks["新的照樣扣次數"] = w.buff_uses_left("time") == 1

	# ② 被動 ×2：兩種效果同時成立（石化在轉、DAHLAH 在改跳躍高度）
	var w2 := _fresh_world()
	w2.grant_buff("petrify")
	w2.grant_buff("dahlah")
	var spins: bool = w2.has_buff("petrify") and not is_zero_approx(w2._petrify_spin_speed)
	var base: float = SpikeSave.jump_velocity()
	var varied := false
	for _i in range(50):
		if not is_equal_approx(w2._jump_velocity_now(), base):
			varied = true
	checks["兩種被動同時生效"] = spins and varied

	# ③ 同一個 key 給兩次只補次數，不會多長一格（HUD 會出現兩個一樣的圖示）
	var w3 := _fresh_world()
	w3.grant_buff("pizza", 1)
	w3.grant_buff("pizza", 3)
	checks["同 key 不重複佔格"] = w3.buffs.size() == 1 and w3.buff_uses_left("pizza") == 3

	# ④ HUD 資料：兩格都送得出去，而且「下一顆會用哪個」標在最舊那格
	var slots: Array = w.buff_hud_slots()
	checks["HUD 兩格資料"] = slots.size() == 2 \
		and String(slots[0]["key"]) == "pizza" and String(slots[1]["key"]) == "time"

	_drop_world(w)
	_drop_world(w2)
	_drop_world(w3)


# ------------------------------------------------------------------
# G. 石化藥水的動態轉速（08-13 項目 4）
# ------------------------------------------------------------------

## 四件事（使用者規格）：拿到就在轉、每次離地重骰方向、平時持續減速到地板值、
## 只有彈射板／蟲洞／jetpack 點火加速而且封頂在 5 圈／秒（jetpack 這條是 08-13 二訂新增）。
func _audit_petrify_spin(checks: Dictionary) -> void:
	var w := _fresh_world()
	w.grant_buff("petrify")
	checks["石化拿到就在轉"] = absf(w._petrify_spin_speed) \
		>= SpikeConfig.BUFF_PETRIFY_SPIN_MIN - 0.001

	# ① 減速：跑幾秒之後降到地板值，而且**不會低於**地板（規格是減速到底線不是停下來）
	for _i in range(int(FPS) * 5):
		w._tick_petrify(DT)
	checks["石化減速到地板"] = is_equal_approx(
		absf(w._petrify_spin_speed), SpikeConfig.BUFF_PETRIFY_SPIN_MIN
	)

	# ② 重骰方向：連骰很多次一定看得到兩個方向都出現過（機率 2^-40 才會假紅）
	var saw_cw := false
	var saw_ccw := false
	for _i in range(40):
		w._petrify_takeoff()
		if w._petrify_spin_speed > 0.0:
			saw_cw = true
		else:
			saw_ccw = true
	checks["石化每次起跳重骰方向"] = saw_cw and saw_ccw

	# ③ 一般起跳**不加速**（規格：只有彈射板／蟲洞才加速）
	var before: float = absf(w._petrify_spin_speed)
	w._petrify_takeoff()
	checks["一般起跳不加速"] = absf(w._petrify_spin_speed) <= before + 0.001

	# ④ 彈射／蟲洞加速，而且封頂
	w._petrify_takeoff(true)
	checks["彈射蟲洞會加速"] = absf(w._petrify_spin_speed) > before + 0.001
	for _i in range(20):
		w._petrify_takeoff(true)
	checks["轉速封頂 5 圈"] = absf(w._petrify_spin_speed) \
		<= SpikeConfig.BUFF_PETRIFY_SPIN_MAX + 0.001

	# ⑤ 沒拿這顆 buff 時整組是 no-op（不會偷偷把轉速灌起來）
	var w2 := _fresh_world()
	w2._petrify_takeoff(true)
	w2._tick_petrify(DT)
	checks["沒石化就不轉"] = is_zero_approx(w2._petrify_spin_speed) \
		and is_zero_approx(w2._petrify_spin)

	# ⑥ jetpack 噴射期間持續加速（08-13 三訂改規格：不再是點火加一次）。⚠ 走 _step_jetpack 的真實路徑
	#   （用 Input.parse_input_event 模擬真的按住鍵），不直接呼叫 _petrify_takeoff——
	#   這條規則的重點正是「有沒有接對地方」，繞過真實路徑等於沒驗到接線。
	var w4 := _fresh_world()
	w4.grant_buff("petrify")
	w4.player.jetpack_fuel_px = 999999.0
	w4.player.jetpack_cooldown_timer = 0.0
	var jet_key: int = SpikeKeys.key_of("jet")
	var press := InputEventKey.new()
	press.keycode = jet_key
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()

	var before4: float = absf(w4._petrify_spin_speed)
	# 冷啟動 JETPACK_SPOOL_TIME 之內（半程）還沒真的噴出來，不該加速
	for _i in range(6):
		w4._step_jetpack(DT)
	checks["jetpack 冷啟動中不加速"] = absf(w4._petrify_spin_speed) <= before4 + 0.001

	# 繼續按住跨過冷啟動門檻，開始噴之後才加速
	for _i in range(10):
		w4._step_jetpack(DT)
	checks["jetpack 噴射會加速"] = absf(w4._petrify_spin_speed) > before4 + 0.001
	var after_ignite: float = absf(w4._petrify_spin_speed)

	# 持續按住不放：每一幀都繼續往上加（08-13 三訂的規格重點就在這條）
	for _i in range(20):
		w4._step_jetpack(DT)
	checks["jetpack 持續噴射逐幀累加"] = absf(w4._petrify_spin_speed) > after_ignite + 0.001

	# 但加到上限就停：無限加速會讓判定與視覺完全脫節（判定不轉，見 SECTION 8e 的 ⚠）
	for _i in range(600):
		w4._step_jetpack(DT)
	checks["jetpack 加速封頂 5 圈"] = is_equal_approx(
		absf(w4._petrify_spin_speed), SpikeConfig.BUFF_PETRIFY_SPIN_MAX
	)

	var release := InputEventKey.new()
	release.keycode = jet_key
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	w4._step_jetpack(DT)

	_drop_world(w)
	_drop_world(w2)
	_drop_world(w4)


# ------------------------------------------------------------------
# D. 常數不變式
# ------------------------------------------------------------------

## ⚠ 這一組跟上面的行為稽核性質不同：上面每一條都是拿 SpikeConfig 的常數去驗 code，
##   所以**常數本身被改壞是驗不出來的**（把 BUFF_DAHLAH_MIN 設成 0.5，行為稽核只會
##   忠實地驗「倍率 >= 0.5」然後全綠）。這幾條驗的是常數彼此必須成立的關係。
func _audit_consts(checks: Dictionary) -> void:
	# ①⚠⚠ DAHLAH 的下限不准低於 1.0：生成器的平台間距是照 1.0x 跳躍高度算的
	#    （MAX_JUMP_HEIGHT），低於 1.0 會讓部分平台變成隨機的死局。使用者拍板的保命條款。
	var dahlah_ok: bool = SpikeConfig.BUFF_DAHLAH_MIN >= 1.0 \
		and SpikeConfig.BUFF_DAHLAH_MAX >= SpikeConfig.BUFF_DAHLAH_MIN

	# ②⚠ 金錢彈是**玩家方**的子彈，判定要比視覺**大**——跟 Pameloe 子彈那條「判定必須
	#    嚴格小於視覺」剛好相反。兩者的誤差都要倒向對玩家有利的方向。
	var bullet_ok: bool = SpikeConfig.BUFF_COIN_BULLET_HIT_SIZE.x \
			> SpikeConfig.BUFF_COIN_BULLET_SIZE.x \
		and SpikeConfig.BUFF_COIN_BULLET_HIT_SIZE.y > SpikeConfig.BUFF_COIN_BULLET_SIZE.y

	# ③ 球要浮得起來：懸浮高度必須大於「球半高 ＋ 平台半高」，否則球會埋進板子裡
	var hover_ok: bool = SpikeConfig.BUFF_ORB_HOVER \
		> SpikeConfig.BUFF_ORB_ART_SIZE.y * 0.5 + SpikeConfig.PLATFORM_SIZE.y * 0.5

	# ④ 判定小於視覺但不能小太多：這是一局一次的關鍵選擇，「明明碰到了卻沒選到」
	#    比「差一點就選到了」糟得多。
	var orb_hit_ok: bool = SpikeConfig.BUFF_ORB_SIZE.x < SpikeConfig.BUFF_ORB_ART_SIZE.x \
		and SpikeConfig.BUFF_ORB_SIZE.x > SpikeConfig.BUFF_ORB_ART_SIZE.x * 0.5

	# ⑤ 表要蓋滿：BUFF_KEYS 每一個都要在 BUFF_TABLE 裡有一列（含 desc／glyph）。
	#    ⚠ 少一列的話 buff_name_of 會回空字串，HUD 顯示一個沒有名字的框——不報錯。
	var table_ok := true
	for k in SpikeConfig.BUFF_KEYS:
		if not SpikeConfig.BUFF_TABLE.has(k):
			table_ok = false
			continue
		var row: Dictionary = SpikeConfig.BUFF_TABLE[k]
		if not (row.has("name") and row.has("glyph") and row.has("uses") and row.has("active")):
			table_ok = false

	# ⑥⚠ 隨機池＝全池扣掉 random 自己。少了這條，「random 展開後又是 random」這種
	#    無窮遞迴的雛形會靜默存在（現在只是機率性地讓玩家拿到一顆什麼都不做的 buff）。
	var pool: Array = SpikeConfig.buff_random_pool()
	var pool_ok: bool = pool.size() == SpikeConfig.BUFF_POOL.size() - 1 \
		and not pool.has(SpikeConfig.BUFF_RANDOM_KEY)

	# ⑦ 三選一要抽得出三顆不重複的：池子至少要跟位置一樣多
	var enough_ok: bool = SpikeConfig.BUFF_POOL.size() >= SpikeConfig.BUFF_ROW_X_FRACS.size()

	# ⑧⚠ 護盾的無敵窗要長過一般餘韻：那顆是「動作結束後的餘韻」，這顆要涵蓋
	#    「從危險物身上脫離」所需的時間，短了就會在同一次接觸裡被連續消耗。
	var shield_ok: bool = SpikeConfig.BUFF_SHIELD_INVULN > SpikeConfig.INVULN_GRACE

	# ⑨⚠⚠ 開局三選一的中繼列「單跳跨不過一整列」：使用者規格「跳躍高度升滿+手套也碰
	#    不到第二層平台」。現算 h_max 不抄 BUFF_INTRO_GAP 註解裡寫死的數字——upstream
	#    常數（UPGRADE_TABLE.jump／GRAVITY／LEDGE_GRAB_REACH）改了，這條要跟著動。
	#    兩個方向都要顧：單一間距仍在「沒升級沒手套」的基礎可達範圍內（① 一般玩家跳得
	#    過），但任兩道相鄰間距加總要超過「全點滿＋手套」的極限（② 跳不過一整列）。
	var jump_row: Dictionary = SpikeConfig.UPGRADE_TABLE.get("jump", {})
	var max_ratio: float = 1.0 + float(jump_row.get("step", 0.0)) * float(jump_row.get("max", 0))
	var v_max: float = SpikeConfig.JUMP_VELOCITY * sqrt(max_ratio)
	var h_max: float = v_max * v_max / (2.0 * SpikeConfig.GRAVITY)
	var reach_with_gear: float = h_max + SpikeConfig.LEDGE_GRAB_REACH
	var intro_gap_ok: bool = SpikeConfig.BUFF_INTRO_GAP <= SpikeConfig.MAX_JUMP_HEIGHT \
		and SpikeConfig.BUFF_INTRO_GAP * 2.0 > reach_with_gear

	checks["常數：DAHLAH 下限"] = dahlah_ok
	checks["常數：金錢彈判定大於視覺"] = bullet_ok
	checks["常數：球浮得起來"] = hover_ok
	checks["常數：球判定介於視覺與半視覺之間"] = orb_hit_ok
	checks["常數：BUFF_TABLE 蓋滿"] = table_ok
	checks["常數：隨機池扣掉自己"] = pool_ok
	checks["常數：池子夠抽三顆"] = enough_ok
	checks["常數：護盾無敵長過餘韻"] = shield_ok
	checks["常數：開局中繼列單跳跨不過"] = intro_gap_ok


# ------------------------------------------------------------------
# 共用
# ------------------------------------------------------------------

## 乾淨的世界：關卡二的生成，但清空所有實體——每條稽核自己擺自己要的東西。
## ⚠ 每條稽核各開一個新 world 而不是共用一個：稽核之間會互相污染狀態（常青認知第 4 條），
##   而 buff 這組的狀態（buff_key／uses／freeze）幾乎每一條都要改。
func _fresh_world() -> WellWorld:
	var world := WellWorld.new()
	add_child(world)
	world.set_process(false)
	world.gen.setup(0.0, SEED, 0.0, 1)
	world.gen.platforms.clear()
	world.gen.monsters.clear()
	world.gen.pickups.clear()
	world.gen.buff_orbs.clear()
	return world


func _drop_world(world: WellWorld) -> void:
	remove_child(world)
	world.queue_free()
