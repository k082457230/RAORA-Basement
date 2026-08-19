class_name Interference
extends RefCounted
## Raora 的干擾（PILLARS v7 階梯式解鎖，v13 擴成四階，08-17 合併側風＋抽跳板後回落三階）。
## 三種手段不齊發，隨登場後時間逐級解鎖、間隔逐步收緊（時間表在 SpikeConfig SECTION 8）：
##   +0s  投擲物   從上方落下，碰到即墜落
##   +20s 甩尾     左／右井壁伸出尾巴水平橫掃＋同時消除附近平台，碰到不死但擊退撞牆＋反彈
##   +60s 黑洞     玩家上方隨機一塊平台上開洞，有向心吸力，碰到即死
##
## ⚠ 三種是**累加常駐**不是二選一（stage() 用 >=），解鎖後永久有效，各跑各的計時器。
## 這個類別只產生威脅，不判傷害（甩尾的擊退物理是唯一例外，見 tail_hit_check 的 ⚠）。
## 碰撞判定住在 WellWorld。


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
	## doom1~3.png 輪播用的累加計時器，見 SpikeConfig.DOOM_FRAME_INTERVAL。
	var anim_t := 0.0
	## 紅色光暈的「被吸入」粒子（08-17）：純表現，跟世界生成的 seeded rng 無關，
	## 用全域 randf() 是刻意的（同 _spawn_sparks／_petrify_takeoff 的理由）。
	## 陣列在 step() 第一次呼叫時惰性建立，不在 _init() 裡——SpikeConfig 常數在
	## RefCounted 建構當下未必已就緒，其他惰性初始化的欄位（如 float_phase）也是同樣考量。
	var particles: Array = []
	## 光暈「不穩定呼吸」的隨機目標遊走（08-17 二訂，見 SpikeConfig.DOOM_GLOW_BREATH_*）：
	## 不用固定週期的 sine，改成每隔隨機時間換一個隨機目標，緩緩靠過去——同樣是純表現，
	## 用全域 randf_range() 不影響 seeded 生成。
	var breath_val := 1.0
	var breath_target := 1.0
	var breath_timer := 0.0

	func step(delta: float) -> void:
		# 母平台被削掉／回收之後就脫離、停在原地——洞不會跟著板子一起消失
		if host != null and host.alive:
			pos = host.pos + offset
		else:
			host = null
		spin = fmod(spin + SpikeConfig.DOOM_SPIN_SPEED * delta, TAU)
		anim_t += delta
		breath_timer -= delta
		if breath_timer <= 0.0:
			breath_target = randf_range(
				1.0 - SpikeConfig.DOOM_GLOW_BREATH_AMOUNT, 1.0 + SpikeConfig.DOOM_GLOW_BREATH_AMOUNT
			)
			breath_timer = randf_range(
				SpikeConfig.DOOM_GLOW_BREATH_INTERVAL_MIN, SpikeConfig.DOOM_GLOW_BREATH_INTERVAL_MAX
			)
		breath_val = lerpf(breath_val, breath_target, clampf(SpikeConfig.DOOM_GLOW_BREATH_RESPONSE * delta, 0.0, 1.0))
		if particles.is_empty():
			for i in range(SpikeConfig.DOOM_GLOW_PARTICLE_COUNT):
				particles.append(_spawn_particle())
		for p in particles:
			p["r"] -= p["speed"] * delta
			if p["r"] <= SpikeConfig.DOOM_RADIUS * SpikeConfig.DOOM_GLOW_PARTICLE_SINK_AT_T:
				var fresh: Dictionary = _spawn_particle()
				p["angle"] = fresh["angle"]
				p["r"] = fresh["r"]
				p["speed"] = fresh["speed"]
		life -= delta
		if life <= 0.0:
			alive = false

	func _spawn_particle() -> Dictionary:
		return {
			"angle": randf() * TAU,
			"r": SpikeConfig.DOOM_PULL_RADIUS * randf_range(
				SpikeConfig.DOOM_GLOW_PARTICLE_SPAWN_MIN_T, SpikeConfig.DOOM_GLOW_PARTICLE_SPAWN_MAX_T
			),
			"speed": randf_range(
				SpikeConfig.DOOM_GLOW_PARTICLE_SPEED_MIN, SpikeConfig.DOOM_GLOW_PARTICLE_SPEED_MAX
			),
		}

	## 目前該畫第幾張（0/1/2）。
	func frame_index() -> int:
		return int(anim_t / SpikeConfig.DOOM_FRAME_INTERVAL) % 3

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


## 甩尾（08-17，合併原側風＋抽跳板，見檔頭 ⚠）。三段狀態機：
##   WARN    ：TAIL_WARN_TIME 秒倒數，side／art_variant 在**進入這個狀態的那一刻**鎖定，
##             之後全程不變。anchor_y 例外——見下方 ⚠⚠，它延到 WARN 結束才鎖。
##   EXTEND  ：尾尖從出手牆平移到對牆，可判定命中（見 hits()）。命中或伸到底＝triggered，
##             立刻停止判定並切到 RETRACT——碰到玩家或另一側牆壁後就不再產生碰撞。
##   RETRACT ：純表現快速收回，結束後 alive=false 由呼叫端回收。
## ⚠ 不像舊側風需要額外的 _manual_shock_active／_manual_shock_timer 兩顆旗標才能給教學關
##   用——這個狀態機本身就是一個完整物件，教學關 tutorial_trigger_tail 直接生一個丟進
##   tail_strikes 陣列即可，沒有「常駐相位時鐘」需要額外旗標去插隊，reset() 也因此少一組
##   要記得清的殘留旗標（08-13x 三訂踩過的那個坑，見 reset() 的舊註解）。
## ⚠⚠ 08-17 真人試玩回報「瞄準精度過低，幾乎碰不到」二訂：anchor_y 原本在 _spawn_tail
##   當下（WARN 剛開始）就鎖死，但 WARN(1.0s) + EXTEND(0.35s) 合計 1.35s 玩家早就爬離
##   那個高度，鎖點形同瞄準一個早就沒人的位置。改成 WARN 結束、切進 EXTEND 的那一瞬間才
##   取用當下玩家 y 座標（lock_anchor_to_player 為真時），把「鎖定」與「命中判定開始」之間
##   的空窗從 1.35s 收到只剩 0（EXTEND 一開始 anchor_y 才剛取樣完）。這仍然是**單次快照**
##   不是連續追蹤——跟 Warn／Pameloe 雷射「預警不追人」的既有原則沒有衝突，只是把快照的
##   時間點換成命中判定真正開始生效的那一刻，而不是玩家根本還不知道要來的那一刻。
##   教學關 tutorial_trigger_tail 固定瞄準教學表指定的平台高度，不吃玩家位置，
##   lock_anchor_to_player 設 false 全程鎖死，行為不變。
class TailStrike extends RefCounted:
	enum Phase { WARN, EXTEND, RETRACT }
	var phase: int = Phase.WARN
	var from_left: bool = true
	var anchor_y: float = 0.0
	var art_variant: int = 0
	var timer: float = 0.0
	var tip_x: float = 0.0
	var triggered: bool = false
	var alive: bool = true
	var lock_anchor_to_player: bool = true

	func origin_x() -> float:
		return SpikeConfig.WELL_LEFT if from_left else SpikeConfig.WELL_RIGHT

	func target_x() -> float:
		return SpikeConfig.WELL_RIGHT if from_left else SpikeConfig.WELL_LEFT

	func step(delta: float, player_pos: Vector2 = Vector2.ZERO) -> void:
		match phase:
			Phase.WARN:
				timer -= delta
				if timer <= 0.0:
					phase = Phase.EXTEND
					timer = 0.0
					if lock_anchor_to_player:
						anchor_y = player_pos.y
			Phase.EXTEND:
				timer += delta
				var t: float = clampf(timer / SpikeConfig.TAIL_EXTEND_DURATION, 0.0, 1.0)
				tip_x = lerpf(origin_x(), target_x(), t)
				# 伸到對牆還沒命中＝未觸發的那條收尾路徑，同樣停止判定、切收回。
				if t >= 1.0 and not triggered:
					triggered = true
					phase = Phase.RETRACT
					timer = 0.0
			Phase.RETRACT:
				timer += delta
				if timer >= SpikeConfig.TAIL_RETRACT_DURATION:
					alive = false

	## 目前伸長比例 0~1，繪製端拿去決定貼圖 reveal 範圍與（收回時）反向淡出。
	func extend_ratio() -> float:
		if phase == Phase.WARN:
			return 0.0
		if phase == Phase.RETRACT:
			return 1.0 - clampf(timer / SpikeConfig.TAIL_RETRACT_DURATION, 0.0, 1.0)
		return clampf(timer / SpikeConfig.TAIL_EXTEND_DURATION, 0.0, 1.0)

	## 出手預警的閃爍相位（同 Warn.blink_on() 的既有寫法）。
	func warn_blink_on() -> bool:
		if phase != Phase.WARN:
			return false
		return int(maxf(timer, 0.0) / SpikeConfig.TAIL_WARN_BLINK_PERIOD) % 2 == 0

	## 判定：點到線段（起點＝出手牆、終點＝目前尾尖）距離 ≤ 固定寬度，跟三張貼圖的
	## 視覺外形脫鉤（同 WellMonster.laser_hits() 的既有手法，見檔頭 ⚠）。只在 EXTEND
	## 且還沒觸發過時可能命中——RETRACT／已觸發的不會二次攻擊。
	func hits(point: Vector2) -> bool:
		if phase != Phase.EXTEND or triggered:
			return false
		var a := Vector2(origin_x(), anchor_y)
		var b := Vector2(tip_x, anchor_y)
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
		return point.distance_to(closest) <= SpikeConfig.TAIL_HIT_WIDTH * 0.5


var projectiles: Array = []
var warns: Array = []
var dooms: Array = []
var doom_warns: Array = []
var tail_strikes: Array = []

## 這一局的關卡編號（0-based）。⚠ 第四種干擾（視野縮小）是關卡限定的，門檻走
## SpikeConfig.level_gate_ok("vision_shrink", level_idx)——不要在這裡比數字，
## 「第幾關才有什麼」的答案只住 LEVEL_GATED 那張表。
var level_idx := 0

var _t := -1.0                 # 登場後經過秒數；< 0 表示還沒登場
var _proj_timer := 0.0
var _tail_timer := 0.0
var _doom_timer := 0.0
var _rng := RandomNumberGenerator.new()
## 無盡加壓：三條封頂軸的階梯分母，來自 WellWorld.best_m（見 update() 的 height_m 參數）
var _height_m := 0.0


func reset() -> void:
	projectiles.clear()
	warns.clear()
	dooms.clear()
	doom_warns.clear()
	tail_strikes.clear()
	_t = -1.0
	_proj_timer = 0.0
	_tail_timer = 0.0
	_doom_timer = 0.0
	_height_m = 0.0
	_rng.randomize()


func active() -> bool:
	return _t >= 0.0


## 0 = 未登場, 1 = 投擲物, 2 = ＋甩尾, 3 = ＋黑洞（08-17：合併側風＋抽跳板後回落三階，
## vision_unlocked() 額外疊加第四階，見下方）
##
## ⚠ 解鎖時點一律讀 SpikeConfig.eff_*() 而不是 stage_*_offset 本身：極限模式把三個
##   offset 全部歸零，這裡直接讀原始值的話極限模式會靜默失效（見 SpikeConfig SECTION 10）。
##   極限模式下三個 eff_ 都是 0，_t 一到 0 就整段落到 return 3，三種同時開跑。
## ⚠ 黑洞維持原本 stage_doom_offset 的絕對時間不變（08-17 合併甩尾時保守決定，不因為
##   少了一階就往前提，數值連動風險留到真人試玩再議，見 SpikeConfig SECTION 8 的說明）。
func stage() -> int:
	if _t < 0.0:
		return 0
	if vision_unlocked():
		return 4
	if _t >= SpikeConfig.eff_stage_doom_offset():
		return 3
	if _t >= SpikeConfig.eff_stage_tail_offset():
		return 2
	if _t >= SpikeConfig.eff_stage_projectile_offset():
		return 1
	return 0


## 第四種干擾（視野縮小，08-13）解鎖了沒。
## ⚠ 兩個條件都要：關卡門檻 ＋ 時間。少了關卡門檻的話關卡一／二爬久了畫面也會變暗，
##   而那是「什麼都沒說就突然看不見」——最不可歸因的一種懲罰。
func vision_unlocked() -> bool:
	if _t < 0.0:
		return false
	if not SpikeConfig.level_gate_ok("vision_shrink", level_idx):
		return false
	return _t >= SpikeConfig.eff_stage_vision_offset()


## 暗幕強度 0 → 1（含淡入淡出、間歇循環）。繪製端只讀這一個數字，不自己算時間。
## 08-13x 二訂（使用者拍板）：解鎖後不再永久壓暗，改成「壓暗 DARK_DURATION 秒 → 恢復
## 明亮 LIGHT_DURATION 秒」的循環，淡入淡出都算在 DARK_DURATION 之內。
## ⚠ 純無狀態實作（只讀 _t，不另外存「現在暗不暗」之類的旗標）：跟第三項側風殘留是
##   同一類坑——凡是需要額外一顆計時器/旗標的機制，reset() 就多一個漏清的風險。
##   這裡直接用 fmod 從 _t 反推相位，reset() 只要把 _t 歸零，這裡自動跟著歸零，不需要
##   額外維護任何新欄位。
func vision_ratio() -> float:
	if not vision_unlocked():
		return 0.0
	var since: float = _t - SpikeConfig.eff_stage_vision_offset()
	var cycle: float = SpikeConfig.VISION_DARK_DURATION + SpikeConfig.VISION_LIGHT_DURATION
	var phase: float = fmod(since, cycle) if cycle > 0.0 else since
	if phase < 0.0 or phase >= SpikeConfig.VISION_DARK_DURATION:
		return 0.0    # 休息段：完全明亮

	var fade_in: float = SpikeConfig.VISION_FADE_IN
	var fade_out: float = SpikeConfig.VISION_FADE_OUT
	var in_ratio: float = 1.0 if fade_in <= 0.0 else clampf(phase / fade_in, 0.0, 1.0)
	var remain: float = SpikeConfig.VISION_DARK_DURATION - phase
	var out_ratio: float = 1.0 if fade_out <= 0.0 else clampf(remain / fade_out, 0.0, 1.0)
	# 取兩者較小值：淡入還沒完就已經進入淡出窗（設定值沒抓好、兩段重疊）時，
	# 自然退化成一個尖峰而不是硬跳，不會產生負值或超過 1 的異常結果。
	return minf(in_ratio, out_ratio)


func stage_label() -> String:
	match stage():
		1:
			return "投擲物"
		2:
			return "投擲物＋甩尾"
		3:
			return "投擲物＋甩尾＋黑洞"
		4:
			return "投擲物＋甩尾＋黑洞＋視野縮小"
		_:
			return ""


## suppress_spawn：計時器照樣跑，只是不觸發新的預警／甩尾（見 well_world 的蟲洞
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
	_step_tail_strikes(delta, player_pos)

	if stage() >= 1:
		_proj_timer -= delta
		if _proj_timer <= 0.0 and not suppress_spawn:
			_spawn_warn(player_pos)
			# 間隔從「預警出現」起算，不是從「東西掉下來」起算：
			# 後者會讓實際的投擲節奏被預警時間整段拖慢，干擾密度悄悄變低。
			_proj_timer = _projectile_interval()

	if stage() >= 2:
		_tail_timer -= delta
		if _tail_timer <= 0.0 and not suppress_spawn:
			_spawn_tail(player_pos, platforms)
			_tail_timer = _tail_interval()

	if stage() >= 3:
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


func _tail_interval() -> float:
	var since: float = maxf(0.0, _t - SpikeConfig.eff_stage_tail_offset())
	var decays := floorf(since / SpikeConfig.tail_decay_every)
	return maxf(
		SpikeConfig.eff_tail_interval_min(_height_m),
		SpikeConfig.tail_interval_start - decays * SpikeConfig.PROJECTILE_INTERVAL_DECAY
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


## 生一次甩尾：骰 side／art_variant，鎖 anchor_y＝玩家當下 y（同 Pameloe 雷射「充能起點
## 鎖定」的既有原則，見 TailStrike 類別開頭 ⚠），同時消除 anchor_y 附近的平台。
func _spawn_tail(player_pos: Vector2, platforms: Array) -> void:
	var t := TailStrike.new()
	t.from_left = _rng.randf() < 0.5
	t.anchor_y = player_pos.y
	var roll: float = _rng.randf()
	if roll < SpikeConfig.TAIL_ART_VARIANT_3_CHANCE:
		t.art_variant = 2
	elif roll < SpikeConfig.TAIL_ART_VARIANT_3_CHANCE + SpikeConfig.TAIL_ART_VARIANT_2_CHANCE:
		t.art_variant = 1
	else:
		t.art_variant = 0
	t.timer = SpikeConfig.TAIL_WARN_TIME
	t.tip_x = t.origin_x()
	tail_strikes.append(t)
	_tail_steal_platforms(t.anchor_y, player_pos, platforms)


## 在 anchor_y 上下 TAIL_STEAL_BAND px 內找候選平台，隨機消除 1~2 塊（沿用
## WellPlatform.steal_warn 既有的「標記→倒數→消失」管線，倒數＝TAIL_WARN_TIME 跟尾巴
## 同一刻消失）。排除玩家當下腳下那塊——避免「落腳板被抽走＋同時被打飛」的複合懲罰
## （水平重疊、且在玩家下方一個身位內視為腳下）。
## ⚠ 用 _rng 逐一挑 index 而不是 Array.shuffle()：shuffle 吃全域 RNG，會讓同一顆 seed
##   在不同次執行生出不同的消除結果，跟這座井「同一顆 seed 要能重現每個細節」的既有
##   要求衝突（見 SpikeSave.last_run_seed 的既有慣例）。
func _tail_steal_platforms(anchor_y: float, player_pos: Vector2, platforms: Array) -> void:
	var candidates: Array = []
	for p in platforms:
		if not p.alive or p.is_goal or p.steal_warn >= 0.0:
			continue
		if absf(p.pos.y - anchor_y) > SpikeConfig.TAIL_STEAL_BAND:
			continue
		if absf(p.pos.x - player_pos.x) <= p.size.x * 0.5 + 40.0 \
				and p.pos.y > player_pos.y and p.pos.y - player_pos.y <= 120.0:
			continue
		candidates.append(p)
	if candidates.is_empty():
		return

	var count: int = mini(
		_rng.randi_range(SpikeConfig.TAIL_STEAL_COUNT_MIN, SpikeConfig.TAIL_STEAL_COUNT_MAX),
		candidates.size()
	)
	for i in range(count):
		var idx := _rng.randi_range(0, candidates.size() - 1)
		candidates[idx].steal_warn = SpikeConfig.TAIL_WARN_TIME
		candidates.remove_at(idx)


func _step_tail_strikes(delta: float, player_pos: Vector2 = Vector2.ZERO) -> void:
	for t in tail_strikes:
		t.step(delta, player_pos)
	tail_strikes = tail_strikes.filter(func(t): return t.alive)


## 命中判定＋觸發後續狀態轉換。呼叫端＝WellWorld._step_player，每幀對玩家目前位置問
## 一次；命中就把該尾巴標記 triggered（停止判定、切收回），並回傳擊退方向給呼叫端套用
## 物理（此類別本身不判傷害／不動玩家速度，同檔頭 ⚠——這是唯一的例外，因為甩尾的
## 「觸發後立刻停止判定」狀態轉換跟命中判定本身是同一個原子操作，拆開會有一幀空窗）。
## 回傳 {"hit": bool, "dir": float}：dir＝1.0 表示擊退方向朝右（甩尾從左井壁出手），
## -1.0＝朝左（從右井壁出手）——永遠是「遠離出手牆」的方向。
func tail_hit_check(player_pos: Vector2) -> Dictionary:
	for t in tail_strikes:
		if t.hits(player_pos):
			t.triggered = true
			t.phase = TailStrike.Phase.RETRACT
			t.timer = 0.0
			return {"hit": true, "dir": 1.0 if t.from_left else -1.0}
	return {"hit": false, "dir": 0.0}


# ------------------------------------------------------------------
# 教學關專用（08-13x，SECTION 8f）：固定高度真的觸發一次，不吃正常的時間驅動階梯
# ------------------------------------------------------------------

## 教學關的每幀推進：只推已經存在的投擲物／預警／黑洞／黑洞預警，跟正常玩法的
## update() 不同——**不**推進 _t、**不**跑 stage() 那套時間驅動的解鎖階梯（規格明講
## 「干擾的時間驅動階梯要關掉，改由高度事件表觸發」）。呼叫端：WellWorld._process
## 在 tutorial_mode 為真時改叫這個，不叫 update()。
func tutorial_step(delta: float, cam_top_y: float) -> void:
	_step_projectiles(delta, cam_top_y)
	_step_warns(delta, cam_top_y)
	_step_dooms(delta, cam_top_y)
	_step_doom_warns(delta)
	_step_tail_strikes(delta)


## 教學專用：在固定 x 掛一個投擲物預警（不骰玩家位置，x 由教學表直接指定）。
func tutorial_trigger_projectile(x: float) -> void:
	var w := Warn.new()
	w.x = x
	w.timer = SpikeConfig.PROJECTILE_WARN_TIME
	warns.append(w)


## 教學專用：在指定平台位置觸發一次完整甩尾（預警→伸長→收回），不吃隨機間隔計時器。
## 正式流程走 _spawn_tail 隨機骰 side／anchor_y，教學關固定從左井壁出手、鎖定在教學表
## 指定的那塊平台高度（WellGenerator.tutorial_tail_target），可重現、好講解。平台消除
## 直接標記這塊教學板本身——它擺在主鏈外側（見 SpikeConfig TUTORIAL_PLATFORMS 的 ⚠），
## 消除它不影響教學路徑的可爬性。
func tutorial_trigger_tail(plat: WellPlatform) -> void:
	if plat == null or not plat.alive:
		return
	var t := TailStrike.new()
	t.from_left = true
	t.anchor_y = plat.pos.y
	# 教學關固定瞄準指定平台高度，不吃玩家位置——見 TailStrike 類別開頭 ⚠⚠。
	t.lock_anchor_to_player = false
	t.art_variant = 0
	t.timer = SpikeConfig.TAIL_WARN_TIME
	t.tip_x = t.origin_x()
	tail_strikes.append(t)
	if plat.steal_warn < 0.0:
		plat.steal_warn = SpikeConfig.TAIL_WARN_TIME


## 教學專用：直接對指定平台掛黑洞預警——理由同 tutorial_trigger_tail。
func tutorial_trigger_doom(plat: WellPlatform) -> void:
	if plat == null or not plat.alive or _platform_busy(plat):
		return
	var w := DoomWarn.new()
	w.host = plat
	w.offset = Vector2(0.0, -(plat.size.y * 0.5 + SpikeConfig.DOOM_HOVER))
	w.pos = plat.pos + w.offset
	w.timer = SpikeConfig.DOOM_WARN_TIME
	doom_warns.append(w)
