class_name Interference
extends RefCounted
## Raora 的干擾（PILLARS v7 階梯式解鎖，v13 擴成四階）。
## 四種手段不齊發，隨登場後時間逐級解鎖、間隔逐步收緊（時間表在 SpikeConfig SECTION 8）：
##   +0s  投擲物   從上方落下，碰到即墜落
##   +20s 抽跳板   抽掉玩家上方的跳板（只抽第 2 塊起，抽前閃爍預告）
##   +40s 側風     向左的**間歇陣風**（吹 3s 休 9s），獨立速度分量、操作抵銷不掉
##   +60s 黑洞     玩家上方隨機一塊平台上開洞，有向心吸力，碰到即死
##
## ⚠ 四種是**累加常駐**不是三選一（stage() 用 >=），解鎖後永久有效，各跑各的計時器。
## 這個類別只產生威脅，不判傷害。碰撞判定住在 WellWorld。


class Projectile extends RefCounted:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var alive := true
	## 純表現：邊落邊轉。判定框不吃這個角度，見下方 rect() 的說明。
	var spin := 0.0
	var spin_speed := 0.0

	## ⚠ 判定用固定角度的小矩形（90×40，見 SpikeConfig.PROJECTILE_HIT_SIZE），
	##   **不隨旋轉變形**——精準的旋轉矩形判定要走 SAT，成本高；更重要的是「看起來閃過了
	##   卻死」是不可歸因的死法，寧可鬆給玩家。08-09 改成跟視覺 116×51 同比例的矩形
	##   （面積鎖定跟舊版 60×60 正方形一樣是 3600，只調形狀不調寬鬆度）。
	func rect() -> Rect2:
		return Rect2(pos - SpikeConfig.PROJECTILE_HIT_SIZE * 0.5, SpikeConfig.PROJECTILE_HIT_SIZE)

	func step(delta: float) -> void:
		pos += vel * delta
		spin = fmod(spin + spin_speed * delta, TAU)


## 落點預警。丟出前先在畫面上方閃一個三角形，玩家有 PROJECTILE_WARN_TIME 秒可以走開。
## ⚠ x 在**產生預警的那一刻**就抽定，之後不再追蹤玩家——會追蹤的預警等於假動作。
class Warn extends RefCounted:
	var x := 0.0
	var timer := 0.0
	var alive := true

	func step(delta: float) -> void:
		timer -= delta

	## 閃爍的亮暗相位。剩餘時間進入 URGENT 區間後週期減半，讓「快來了」有遞增感。
	func blink_on() -> bool:
		var period: float = SpikeConfig.PROJECTILE_WARN_BLINK_PERIOD
		if timer <= SpikeConfig.PROJECTILE_WARN_URGENT_AT:
			period = SpikeConfig.PROJECTILE_WARN_URGENT_PERIOD
		return int(maxf(timer, 0.0) / period) % 2 == 0


## 黑洞（v13）。掛在一塊平台上（跟著它移動），有壽命，時間到自己塌縮。
## ⚠ 判定用圓不用矩形：它畫成圓，用矩形會出現「看起來在圓外卻死」的角落死法。
class Doom extends RefCounted:
	var pos := Vector2.ZERO
	var host: WellPlatform = null
	var offset := Vector2.ZERO
	var life := 0.0
	var spin := 0.0
	var alive := true

	func step(delta: float) -> void:
		# 母平台被削掉／回收之後就脫離、停在原地——洞不會跟著板子一起消失
		if host != null and host.alive:
			pos = host.pos + offset
		else:
			host = null
		spin = fmod(spin + SpikeConfig.DOOM_SPIN_SPEED * delta, TAU)
		life -= delta
		if life <= 0.0:
			alive = false

	## 玩家中心到洞心的距離在事件視界內＝死
	func swallows(point: Vector2) -> bool:
		return point.distance_to(pos) <= SpikeConfig.DOOM_RADIUS


## 黑洞的出現預警。跟投擲物的 Warn 不同：它有位置、而且**跟著目標平台走**，
## 這樣「紫圈閃的地方」跟「洞真正開的地方」永遠是同一個點。
class DoomWarn extends RefCounted:
	var pos := Vector2.ZERO
	var host: WellPlatform = null
	var offset := Vector2.ZERO
	var timer := 0.0
	var alive := true

	func step(delta: float) -> void:
		if host != null and host.alive:
			pos = host.pos + offset
		else:
			host = null
		timer -= delta

	func blink_on() -> bool:
		var period: float = SpikeConfig.DOOM_WARN_BLINK_PERIOD
		if timer <= SpikeConfig.DOOM_WARN_URGENT_AT:
			period = SpikeConfig.DOOM_WARN_URGENT_PERIOD
		return int(maxf(timer, 0.0) / period) % 2 == 0


var projectiles: Array = []
var warns: Array = []
var dooms: Array = []
var doom_warns: Array = []

var _t := -1.0                 # 登場後經過秒數；< 0 表示還沒登場
var _proj_timer := 0.0
var _steal_timer := 0.0
var _doom_timer := 0.0
var _rng := RandomNumberGenerator.new()
## 無盡加壓：三條封頂軸的階梯分母，來自 WellWorld.best_m（見 update() 的 height_m 參數）
var _height_m := 0.0


func reset() -> void:
	projectiles.clear()
	warns.clear()
	dooms.clear()
	doom_warns.clear()
	_t = -1.0
	_proj_timer = 0.0
	_steal_timer = 0.0
	_doom_timer = 0.0
	_rng.randomize()


func active() -> bool:
	return _t >= 0.0


## 0 = 未登場, 1 = 投擲物, 2 = ＋抽跳板, 3 = ＋側風, 4 = ＋黑洞
##
## ⚠ 解鎖時點一律讀 SpikeConfig.eff_*() 而不是 stage_*_offset 本身：極限模式把四個
##   offset 全部歸零，這裡直接讀原始值的話極限模式會靜默失效（見 SpikeConfig SECTION 10）。
##   極限模式下四個 eff_ 都是 0，_t 一到 0 就整段落到 return 4，四種同時開跑。
func stage() -> int:
	if _t < 0.0:
		return 0
	if _t >= SpikeConfig.eff_stage_doom_offset():
		return 4
	if _t >= SpikeConfig.eff_stage_shockwave_offset():
		return 3
	if _t >= SpikeConfig.eff_stage_steal_offset():
		return 2
	if _t >= SpikeConfig.eff_stage_projectile_offset():
		return 1
	return 0


func stage_label() -> String:
	match stage():
		1:
			return "投擲物"
		2:
			return "投擲物＋抽跳板"
		3:
			return "全面施壓"
		4:
			return "全面施壓＋黑洞"
		_:
			return ""


## 側風在解鎖後的週期相位（0 ~ SHOCKWAVE_CYCLE）。未解鎖回 -1。
## 一輪＝前 SHOCKWAVE_BURST_TIME 秒吹風，其餘休息；預警佔休息段的最後 WARN_TIME 秒。
func _shock_phase() -> float:
	if stage() < 3:
		return -1.0
	return fmod(_t - SpikeConfig.eff_stage_shockwave_offset(), SpikeConfig.SHOCKWAVE_CYCLE)


## 現在正在吹嗎
func shockwave_active() -> bool:
	var ph := _shock_phase()
	return ph >= 0.0 and ph < SpikeConfig.SHOCKWAVE_BURST_TIME


## 距離「下一陣風開始」還有幾秒。正在吹或還沒登場回 -1。
## ⚠ 解鎖前也算：第一陣風就從解鎖那一刻開始吹，所以預警要跨過解鎖時點往前算。
func shockwave_next_gust_in() -> float:
	if _t < 0.0:
		return -1.0
	if stage() < 3:
		return SpikeConfig.eff_stage_shockwave_offset() - _t
	var ph := _shock_phase()
	if ph < SpikeConfig.SHOCKWAVE_BURST_TIME:
		return -1.0
	return SpikeConfig.SHOCKWAVE_CYCLE - ph


## 預警窗內回剩餘秒數，否則 -1。
## ⚠ v13 起側風是**間歇陣風**，所以每一陣風前都會警告一次，不再是「只警告一次」。
func shockwave_warn_left() -> float:
	var left := shockwave_next_gust_in()
	if left <= 0.0 or left > SpikeConfig.SHOCKWAVE_WARN_TIME:
		return -1.0
	return left


## 這一幀該不該畫那條長條（閃爍的亮相位）
func shockwave_warn_on() -> bool:
	var left := shockwave_warn_left()
	if left < 0.0:
		return false
	return int(left / SpikeConfig.SHOCKWAVE_WARN_BLINK_PERIOD) % 2 == 0


## 側風力道（px/s，向左為正值，由呼叫端加負號）。沒在吹就是 0。
## ⚠ 力道仍隨「解鎖後總時間」遞增（不是隨這一陣風的進度），所以後面的每一陣都更狠。
func shockwave_force() -> float:
	if not shockwave_active():
		return 0.0
	var since: float = _t - SpikeConfig.eff_stage_shockwave_offset()
	return SpikeConfig.SHOCKWAVE_FORCE_START + SpikeConfig.SHOCKWAVE_FORCE_SLOPE * since


## suppress_spawn：計時器照樣跑，只是不觸發新的預警／抽跳板（見 well_world 的蟲洞
## 過場——干擾不能被過場暫停，那是免費喘息，但過場中新開的預警會瞄準一個馬上就不在
## 的位置，所以只延後「真的生出來」這一下，過場結束後 timer 多半已經 <= 0，下一次
## update() 立刻用當下的真實 player_pos 補上，不會平白少一次）。
func update(
	delta: float, elapsed: float, player_pos: Vector2, cam_top_y: float, platforms: Array,
	height_m: float = 0.0, suppress_spawn: bool = false
) -> void:
	_height_m = height_m
	if elapsed >= SpikeConfig.eff_interference_start():
		if _t < 0.0:
			_t = 0.0
		else:
			_t += delta

	_step_projectiles(delta, cam_top_y)
	_step_warns(delta, cam_top_y)
	_step_dooms(delta, cam_top_y)
	_step_doom_warns(delta)

	if stage() >= 1:
		_proj_timer -= delta
		if _proj_timer <= 0.0 and not suppress_spawn:
			_spawn_warn(player_pos)
			# 間隔從「預警出現」起算，不是從「東西掉下來」起算：
			# 後者會讓實際的投擲節奏被預警時間整段拖慢，干擾密度悄悄變低。
			_proj_timer = _projectile_interval()

	if stage() >= 2:
		_steal_timer -= delta
		if _steal_timer <= 0.0 and not suppress_spawn:
			_steal_platform(player_pos, platforms)
			_steal_timer = _steal_interval()

	if stage() >= 4:
		_doom_timer -= delta
		if _doom_timer <= 0.0 and not suppress_spawn:
			# 找不到合格平台時不重設長間隔，隔 1 秒再試——不然玩家在稀疏段
			# 錯過一次就等於白送整個間隔
			if _spawn_doom_warn(player_pos, platforms):
				_doom_timer = _doom_interval()
			else:
				_doom_timer = 1.0


## ⚠ 無盡加壓：地板不再是 SpikeConfig.projectile_interval_min 本身，改吃
## eff_projectile_interval_min(_height_m)——高度每跨一階 PRESSURE_STEP_HEIGHT_M，
## 地板就往下降一階（見 SpikeConfig SECTION 9c），時間衰減與高度階梯疊在同一個 maxf。
func _projectile_interval() -> float:
	var since: float = maxf(0.0, _t - SpikeConfig.eff_stage_projectile_offset())
	var decays := floorf(since / SpikeConfig.projectile_decay_every)
	return maxf(
		SpikeConfig.eff_projectile_interval_min(_height_m),
		SpikeConfig.projectile_interval_start - decays * SpikeConfig.PROJECTILE_INTERVAL_DECAY
	)


func _doom_interval() -> float:
	var since: float = maxf(0.0, _t - SpikeConfig.eff_stage_doom_offset())
	var decays := floorf(since / SpikeConfig.doom_decay_every)
	return maxf(
		SpikeConfig.eff_doom_interval_min(_height_m),
		SpikeConfig.doom_interval_start - decays * SpikeConfig.PROJECTILE_INTERVAL_DECAY
	)


func _steal_interval() -> float:
	var since: float = maxf(0.0, _t - SpikeConfig.eff_stage_steal_offset())
	var decays := floorf(since / SpikeConfig.steal_decay_every)
	return maxf(
		SpikeConfig.eff_steal_interval_min(_height_m),
		SpikeConfig.steal_interval_start - decays * SpikeConfig.PROJECTILE_INTERVAL_DECAY
	)


## 「從上方隨機落下」——但完全均勻散佈在 1100px 寬的井裡幾乎打不到人，
## 干擾會變成純裝飾。所以在玩家 x 附近抽，仍是隨機、但真的有威脅。
##
## 抽完不是直接丟，而是先掛一個預警（見 Warn），倒數結束才真的生出投擲物。
func _spawn_warn(player_pos: Vector2) -> void:
	var half: float = maxf(
		SpikeConfig.PROJECTILE_DRAW_SIZE.x, SpikeConfig.PROJECTILE_DRAW_SIZE.y
	) * 0.5
	var x := player_pos.x + _rng.randf_range(
		-SpikeConfig.PROJECTILE_AIM_SPREAD, SpikeConfig.PROJECTILE_AIM_SPREAD
	)
	# 用旋轉包絡的半徑夾邊，長方形轉到直立時才不會插進井壁裡
	x = clampf(x, SpikeConfig.WELL_LEFT + half, SpikeConfig.WELL_RIGHT - half)

	var w := Warn.new()
	w.x = x
	w.timer = SpikeConfig.PROJECTILE_WARN_TIME
	warns.append(w)


func _spawn_projectile(x: float, cam_top_y: float) -> void:
	var p := Projectile.new()
	p.pos = Vector2(x, cam_top_y - SpikeConfig.PROJECTILE_DRAW_SIZE.x)
	p.vel = Vector2(0.0, SpikeConfig.PROJECTILE_SPEED)
	p.spin_speed = _rng.randf_range(
		SpikeConfig.PROJECTILE_SPIN_MIN, SpikeConfig.PROJECTILE_SPIN_MAX
	)
	if _rng.randf() < 0.5:
		p.spin_speed = -p.spin_speed
	p.spin = _rng.randf_range(0.0, TAU)
	projectiles.append(p)


## 預警倒數結束 → 從畫面上緣丟下投擲物。
## ⚠ 生成點用「當下的畫面上緣」而不是預警產生時的：玩家這 2 秒可能爬了一大段，
##   用舊的 y 會讓東西從畫面外老遠掉下來，玩家等半天才看到它進場。
func _step_warns(delta: float, cam_top_y: float) -> void:
	for w in warns:
		w.step(delta)
		if w.timer <= 0.0:
			w.alive = false
			_spawn_projectile(w.x, cam_top_y)
	warns = warns.filter(func(w): return w.alive)


func _step_projectiles(delta: float, cam_top_y: float) -> void:
	var kill_below: float = cam_top_y + SpikeConfig.VIEW_H * 2.0
	for p in projectiles:
		p.step(delta)
		if p.pos.y > kill_below:
			p.alive = false
	projectiles = projectiles.filter(func(p): return p.alive)


# ------------------------------------------------------------------
# 黑洞（v13）
# ------------------------------------------------------------------

## 挑一塊玩家上方的平台，掛一個 DOOM_WARN_TIME 秒的紫圈預警。回傳是否真的掛上。
##
## ⚠ 只挑上方第 DOOM_MIN_INDEX_ABOVE 塊起（同抽跳板的緩衝 ②）：開在腳下那塊等於
##   無預警處決——玩家連往哪跳都還沒決定，洞就在他要落腳的地方開了。
## ⚠ 預警綁在**平台**上而不是綁在一個世界座標：目標板若是移動板，紫圈要跟著它走，
##   否則「閃的地方」與「洞真正開的地方」會差一整個板寬，預警等於騙人。
## ⚠ 已經有洞或已經在預警中的板不重複挑，避免兩個洞疊在同一點。
func _spawn_doom_warn(player_pos: Vector2, platforms: Array) -> bool:
	var above: Array = []
	for p in platforms:
		if not p.alive or p.is_goal or p.steal_warn >= 0.0:
			continue
		if p.pos.y >= player_pos.y:
			continue
		if _platform_busy(p):
			continue
		above.append(p)
	if above.size() <= SpikeConfig.DOOM_MIN_INDEX_ABOVE:
		return false

	# 由近而遠（上方 = y 更小，所以離玩家最近的是 y 最大的那個）
	above.sort_custom(func(a, b): return a.pos.y > b.pos.y)
	var lo: int = SpikeConfig.DOOM_MIN_INDEX_ABOVE
	var hi: int = mini(above.size() - 1, lo + 4)
	var plat: WellPlatform = above[_rng.randi_range(lo, hi)]

	var w := DoomWarn.new()
	w.host = plat
	w.offset = Vector2(0.0, -(plat.size.y * 0.5 + SpikeConfig.DOOM_HOVER))
	w.pos = plat.pos + w.offset
	w.timer = SpikeConfig.DOOM_WARN_TIME
	doom_warns.append(w)
	return true


## 這塊板上已經有洞或已經在預警中嗎
func _platform_busy(plat: WellPlatform) -> bool:
	for d in dooms:
		if d.alive and d.host == plat:
			return true
	for w in doom_warns:
		if w.alive and w.host == plat:
			return true
	return false


## 預警倒數結束 → 就地開洞。位置沿用預警當下**那一幀**的位置（含平台的跟隨），
## 所以洞一定開在紫圈最後閃的地方。
func _step_doom_warns(delta: float) -> void:
	for w in doom_warns:
		w.step(delta)
		if w.timer > 0.0:
			continue
		w.alive = false
		var d := Doom.new()
		d.host = w.host
		d.offset = w.offset
		d.pos = w.pos
		d.life = SpikeConfig.DOOM_LIFETIME
		d.spin = _rng.randf_range(0.0, TAU)
		dooms.append(d)
	doom_warns = doom_warns.filter(func(w): return w.alive)


## 黑洞推進。除了自己的壽命之外，掉出視野下方一整個畫面就回收——
## 沒有這條的話，玩家往上爬之後下方會留一串永遠不會被清掉的物件。
func _step_dooms(delta: float, cam_top_y: float) -> void:
	var kill_below: float = cam_top_y + SpikeConfig.VIEW_H * 2.0
	for d in dooms:
		d.step(delta)
		if d.pos.y > kill_below:
			d.alive = false
	dooms = dooms.filter(func(d): return d.alive)


## 對 point 這個位置的吸力速度（世界座標向量）。不在任何洞的範圍內回零向量。
## 吸力隨距離線性遞減：貼到事件視界是 DOOM_PULL_MAX_SPEED，到 PULL_RADIUS 邊緣是 0。
## ⚠ 多個洞重疊時只取**最近**那個，不疊加——疊加會在兩洞之間生出一個誰也逃不掉的
##   合力區，而那個區域在畫面上看不出來。
func pull_velocity_at(point: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for d in dooms:
		if not d.alive:
			continue
		var v: Vector2 = d.pos - point
		var dist := v.length()
		if dist >= SpikeConfig.DOOM_PULL_RADIUS or dist <= 0.001:
			continue
		if dist >= best_d:
			continue
		best_d = dist
		var t: float = 1.0 - dist / SpikeConfig.DOOM_PULL_RADIUS
		best = (v / dist) * SpikeConfig.DOOM_PULL_MAX_SPEED * t
	return best


## 三道緩衝（PILLARS v7 明文，處理「抽跳板 × 高處密度低」這個最尖銳的相乘點）：
##   ① 延後解鎖  ② 只抽上方第 2 塊起  ③ 抽前閃爍預告
## 這裡負責 ②③；① 由 stage() 的解鎖時點負責。
func _steal_platform(player_pos: Vector2, platforms: Array) -> void:
	var above: Array = []
	for p in platforms:
		if not p.alive or p.is_goal or p.steal_warn >= 0.0:
			continue
		if p.pos.y < player_pos.y:
			above.append(p)
	if above.size() <= SpikeConfig.STEAL_MIN_INDEX_ABOVE:
		return

	# 由近而遠排序（上方 = y 更小，所以離玩家最近的是 y 最大的那個）
	above.sort_custom(func(a, b): return a.pos.y > b.pos.y)

	var lo: int = SpikeConfig.STEAL_MIN_INDEX_ABOVE
	var hi: int = mini(above.size() - 1, lo + 3)
	var idx := _rng.randi_range(lo, hi)
	above[idx].steal_warn = SpikeConfig.STEAL_WARN_TIME
