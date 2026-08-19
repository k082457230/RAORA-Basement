extends Node
## 生成器靜態稽核：一次生完整座井，量密度分布、平台重疊、可跳性、左右平衡、
## 橫移需求、蟲洞（含串流路徑）、Pameloe 生成規則。全部不跑物理、不靠 bot 撞運氣。
## 對應稽核項：_audit_generator()（唯一對外入口，其餘皆為它的資料工具函式）。


## 靜態稽核：把整座井一次生完（不跑物理、不回收），直接量三件事——
##   ① 密度是否隨高度遞減、BAND_SOLO_HEIGHT_M 以上是否真的每區間只有一塊
##   ② 任兩塊平台的「運動包絡線」是否相交（左右／上下／繞圈的板都算進去）
##   ③ 每一塊在最壞擺動相位下是否仍跳得到
## 這三題用實跑局是量不準的（bot 的路線只會經過一小部分平台）。
func _audit_generator() -> bool:
	var gen := WellGenerator.new()
	gen.setup(0.0, 20260807)
	gen.ensure_generated_to(SpikeConfig.goal_y(0.0) - 10.0)

	var body: Array = []
	for p in gen.platforms:
		if not p.is_goal:
			body.append(p)

	var slice_m := 100.0
	var slices := int(ceilf(SpikeConfig.goal_meters / slice_m))
	var counts := []
	var mobile := []
	var fragile := []
	var launcher := []
	for _i in range(slices):
		counts.append(0)
		mobile.append(0)
		fragile.append(0)
		launcher.append(0)

	for p in body:
		var h: float = SpikeConfig.meters_from_y(0.0, p.center().y)
		var si := clampi(int(h / slice_m), 0, slices - 1)
		counts[si] += 1
		match p.kind:
			WellPlatform.Kind.MOVING, WellPlatform.Kind.VERTICAL, WellPlatform.Kind.CIRCULAR:
				mobile[si] += 1
			WellPlatform.Kind.FRAGILE:
				fragile[si] += 1
			WellPlatform.Kind.LAUNCHER:
				launcher[si] += 1

	print("--- 生成器稽核（單一 seed 生完整座井）---")
	print("  平台總數 / 物資 : %d / %d" % [body.size(), gen.pickups.size()])
	print("  每 100m：塊數（移動 / 碎裂 / 彈射）")
	for i in range(slices):
		var lo := int(float(i) * slice_m)
		print("    %4d-%4dm : %3d（%d / %d / %d）" % [
			lo, lo + int(slice_m), counts[i], mobile[i], fragile[i], launcher[i]
		])

	var overlaps := _count_envelope_overlaps(body)
	# ⚠ 起跳候選要含終點平台（它踩得到），被檢查的目標才用排除終點的 body，見函式 ⚠⚠
	var worst_jump := _worst_required_jump(body, gen.platforms)
	var cap := gen.hard_spacing_cap()
	print("  包絡線重疊對數  : %d（左右/上下/繞圈的整段運動範圍都算）" % overlaps)
	print("  最壞跳躍需求    : %.1f px（上限 %.1f，基礎跳躍 %.1f）" % [
		worst_jump["worst"], cap, SpikeConfig.MAX_JUMP_HEIGHT
	])

	var balance := _audit_x_balance(body)
	var dx := _required_dx(body)
	var wh := _audit_wormholes(gen)
	print("  左右分佈        : 左 %d / 右 %d（左半 %.0f%%），最長同側連續 %d 塊" % [
		balance["left"], balance["right"], balance["left_ratio"] * 100.0, balance["worst_run"]
	])
	print("  橫移需求        : 平均 %.0f px / 最大 %.0f px（可達視窗 %.0f px）" % [
		dx["avg"], dx["max"], dx["limit"]
	])
	print("  蟲洞            : %d 個（已綁出口 %d），最小實際增益 %.1f m，壞出口 %d，會動的出口 %d" % [
		wh["total"], wh["bound"], wh["min_rise"], wh["bad_exit"], wh["moving_exit"]
	])

	var stream := _audit_streaming_wormholes()
	print("  蟲洞（串流路徑）: 進過畫面 %d 個，其中當下可用 %d 個" % [
		stream["in_view"], stream["usable"]
	])

	var pm := _audit_pameloe_spawns(gen)
	print("  Pameloe         : %d 隻（500m 以下 %d、與母平台距離不足 %d、出井 %d、配不到母平台 %d）" % [
		pm["total"], pm["below_start"], pm["too_close"], pm["out_of_well"], pm["unmatched_host"]
	])

	var ok := true
	if overlaps > 0:
		print("  !! 有平台互相重疊")
		ok = false
	if worst_jump["worst"] > cap + 0.5:
		print("  !! 有平台在最壞擺動相位下跳不到 — " + _describe_worst_pair(worst_jump, 0.0))
		ok = false
	if balance["left_ratio"] < 0.40 or balance["left_ratio"] > 0.60:
		print("  !! 左右分佈失衡（左半 %.0f%%）" % (balance["left_ratio"] * 100.0))
		ok = false
	if balance["worst_run"] > 14:
		print("  !! 有一段連續 %d 塊全落在同一側" % balance["worst_run"])
		ok = false
	if dx["max"] > dx["limit"] + 0.5:
		print("  !! 有平台的最省力接法要橫移 %.0f px，超過一次跳躍搆得到的範圍" % dx["max"])
		ok = false
	if wh["total"] < 3:
		print("  !! 整座井只有 %d 個蟲洞" % wh["total"])
		ok = false
	if wh["bound"] < wh["total"] - 1:
		print("  !! 有蟲洞沒配到出口平台")
		ok = false
	if wh["bad_exit"] > 0:
		print("  !! 有蟲洞的出口是碎裂板或終點板")
		ok = false
	if wh["moving_exit"] > 0:
		print("  !! 有 %d 個蟲洞的出口是會動的板（守門承諾應優先挑不會動的）" % wh["moving_exit"])
		ok = false
	if wh["bound"] > 0 and wh["min_rise"] < SpikeConfig.WORMHOLE_RISE_M * 0.8:
		print("  !! 有蟲洞實際只送 %.1f m（規格 %.0f m）" % [
			wh["min_rise"], SpikeConfig.WORMHOLE_RISE_M
		])
		ok = false
	# ⚠ 這一條是 v9「蟲洞從沒出現過」的回歸防線。上面那些指標全部走靜態路徑（一次生完、
	#    不 prune），所以 v9 是全綠的；真正的病灶只有串流路徑量得到。別把它拿掉。
	if stream["in_view"] <= 0:
		print("  !! 串流路徑下沒有任何蟲洞進過畫面")
		ok = false
	elif stream["usable"] < stream["in_view"]:
		print("  !! 有 %d 個蟲洞進到畫面時還沒綁到出口，玩家看不到也踩不到" % [
			stream["in_view"] - stream["usable"]
		])
		ok = false
	# 頂端密度：solo 高度以上的每一段都必須嚴格比 0-100m 那段稀疏
	var solo_slice := int(SpikeConfig.BAND_SOLO_HEIGHT_M / slice_m)
	for i in range(solo_slice + 1, slices):
		if counts[i] >= counts[0]:
			print("  !! %d-%dm 沒有比井底稀疏" % [i * int(slice_m), (i + 1) * int(slice_m)])
			ok = false

	if pm["below_start"] > 0:
		print("  !! 有 %d 隻 pameloe 生在 %.0fm 以下" % [
			pm["below_start"], SpikeConfig.PAMELOE_START_HEIGHT_M
		])
		ok = false
	if pm["too_close"] > 0:
		print("  !! 有 %d 隻 pameloe 與母平台水平距離小於 %.0f px（可歸因性保命條款破功）" % [
			pm["too_close"], SpikeConfig.PAMELOE_MIN_DIST_X
		])
		ok = false
	if pm["out_of_well"] > 0:
		print("  !! 有 %d 隻 pameloe 生在井外" % pm["out_of_well"])
		ok = false
	if pm["unmatched_host"] > 0:
		print("  !! 有 %d 隻 pameloe 配不到母平台（稽核端配對式子跟生成器對不上，先檢查兩邊有沒有改動）" % [
			pm["unmatched_host"]
		])
		ok = false
	if SpikeConfig.goal_meters >= SpikeConfig.PAMELOE_START_HEIGHT_M and pm["total"] <= 0:
		print("  !! 井生到 %.0fm 了，pameloe 總數卻是 0（生成邏輯可能靜默失效）" % SpikeConfig.goal_meters)
		ok = false

	# 騙人平台／卡包／pebbles（08-13x，關卡三限定）：生成器端的規則全在這裡驗，
	# 不吃 bot 撞運氣（bot 只跑關卡一）。
	var lv3 := _audit_level3_content()
	print("  騙人平台        : 關卡一/二 %d/%d 塊、關卡三 %d 塊（高度違規 %d、混進主鏈 %d）" % [
		lv3[0]["decoy_total"], lv3[1]["decoy_total"], lv3[2]["decoy_total"],
		lv3[2]["decoy_over_height"], lv3[2]["decoy_on_main_chain"]
	])
	print("  卡包            : 關卡一/二 %d/%d 個、關卡三 %d 個（最高 %.0fm）" % [
		lv3[0]["loot_total"], lv3[1]["loot_total"], lv3[2]["loot_total"], lv3[2]["loot_max_h"]
	])
	print("  pebbles         : 關卡一 %d 隻、關卡二/三 %d/%d 隻（solo 區間內 %d，08-17 起不再限制）" % [
		lv3[0]["pebbles_total"], lv3[1]["pebbles_total"], lv3[2]["pebbles_total"],
		lv3[2]["pebbles_in_solo"]
	])
	if lv3[0]["decoy_total"] > 0 or lv3[1]["decoy_total"] > 0:
		print("  !! 關卡一／二出現騙人平台（應為 0，LEVEL_GATED 門檻失效）")
		ok = false
	if lv3[2]["decoy_total"] <= 0:
		print("  !! 關卡三沒有生出任何騙人平台（生成邏輯可能靜默失效）")
		ok = false
	if lv3[2]["decoy_over_height"] > 0:
		print("  !! 有 %d 塊騙人平台生在 DECOY_MAX_HEIGHT_M（%.0fm）以上" % [
			lv3[2]["decoy_over_height"], SpikeConfig.DECOY_MAX_HEIGHT_M
		])
		ok = false
	if lv3[2]["decoy_on_main_chain"] > 0:
		print("  !! 有 %d 塊騙人平台混進主鏈（is_band_extra=false）——這是可達性安全條款" % [
			lv3[2]["decoy_on_main_chain"]
		] + "，見 SpikeConfig.DECOY_CHANCE 的 ⚠⚠")
		ok = false
	# 08-14 使用者拍板：卡包門檻從關卡三提早到關卡二（LEVEL_GATED["loot_bag"].min_level
	# 2→1），所以關卡一應為 0、關卡二／三都要 > 0——跟騙人平台／pebbles（仍是關卡三限定）
	# 不是同一條規則，不能共用同一個 if。
	if lv3[0]["loot_total"] > 0:
		print("  !! 關卡一出現卡包（應為 0，LEVEL_GATED 門檻失效）")
		ok = false
	if lv3[1]["loot_total"] <= 0:
		print("  !! 關卡二沒有生出任何卡包（規格是關卡二起就該出現，LEVEL_GATED 門檻可能沒生效）")
		ok = false
	if lv3[2]["loot_total"] <= 0:
		print("  !! 關卡三沒有生出任何卡包（生成邏輯可能靜默失效）")
		ok = false
	if lv3[2]["loot_max_h"] < SpikeConfig.DECOY_MAX_HEIGHT_M:
		print("  !! 關卡三的卡包全部擠在 %.0fm 以下——規格是「全段」都會出現" % SpikeConfig.DECOY_MAX_HEIGHT_M)
		ok = false
	# 08-17 使用者拍板：pebbles 門檻從關卡三提早到關卡二（同 loot_bag 的規則形狀），
	# 且拿掉 solo 區間限制——不再檢查 pebbles_in_solo（那是刻意接受的已知取捨，見
	# SpikeConfig.PEBBLES_CHANCE_GIVEN_MONSTER 的 ⚠⚠），改成純資訊性印出在上面的 print。
	if lv3[0]["pebbles_total"] > 0:
		print("  !! 關卡一出現 pebbles（應為 0，LEVEL_GATED 門檻失效）")
		ok = false
	if lv3[1]["pebbles_total"] <= 0:
		print("  !! 關卡二沒有生出任何 pebbles（規格是關卡二起就該出現，LEVEL_GATED 門檻可能沒生效）")
		ok = false
	if lv3[2]["pebbles_total"] <= 0:
		print("  !! 關卡三沒有生出任何 pebbles（生成邏輯可能靜默失效）")
		ok = false
	return ok


## 三顆 seed 各生一座完整的井（關卡一／二／三），統計騙人平台／卡包／pebbles 的分佈。
## ⚠ 每個關卡各自 setup 一次全新的生成器（level_idx 不同），不是同一顆 gen 切換關卡——
##   生成器本來就不支援「跑到一半換關卡」，這條稽核也不需要它支援。
func _audit_level3_content() -> Dictionary:
	const SEED := 20260813
	var out := {}
	for lv in range(SpikeConfig.LEVEL_COUNT):
		var gen := WellGenerator.new()
		gen.setup(0.0, SEED, 0.0, lv)
		gen.ensure_generated_to(SpikeConfig.goal_y(0.0) - 10.0)

		var decoy_total := 0
		var decoy_over_height := 0
		var decoy_on_main_chain := 0
		for p in gen.platforms:
			if p.kind != WellPlatform.Kind.DECOY:
				continue
			decoy_total += 1
			var h: float = SpikeConfig.meters_from_y(0.0, p.center().y)
			if h >= SpikeConfig.DECOY_MAX_HEIGHT_M:
				decoy_over_height += 1
			if not p.is_band_extra:
				decoy_on_main_chain += 1

		var loot_total := 0
		var loot_max_h := 0.0
		for pk in gen.pickups:
			if pk.kind != WellPickup.Kind.LOOT_BAG:
				continue
			loot_total += 1
			loot_max_h = maxf(loot_max_h, SpikeConfig.meters_from_y(0.0, pk.pos.y))

		var pebbles_total := 0
		var pebbles_in_solo := 0
		# 容差同 BAND_EXTRA_Y_DROP 量級（一個 spacing 步幅）：生成器內部拿的是
		# 「上一塊平台」的高度判斷 solo（見 WellGenerator._make_monster 的 h_m 參數），
		# 這一塊自己的高度可能比那個判斷值高一個 spacing——邊界附近的一兩隻不是 bug，
		# 全部飄到 690m 以上一路到頂才是。
		const SOLO_BOUNDARY_TOLERANCE_M := 10.0
		for m in gen.monsters:
			if m.kind != WellMonster.Kind.PEBBLES:
				continue
			pebbles_total += 1
			var hm: float = SpikeConfig.meters_from_y(0.0, m.pos.y)
			if hm >= SpikeConfig.BAND_SOLO_HEIGHT_M + SOLO_BOUNDARY_TOLERANCE_M:
				pebbles_in_solo += 1

		out[lv] = {
			"decoy_total": decoy_total, "decoy_over_height": decoy_over_height,
			"decoy_on_main_chain": decoy_on_main_chain,
			"loot_total": loot_total, "loot_max_h": loot_max_h,
			"pebbles_total": pebbles_total, "pebbles_in_solo": pebbles_in_solo,
		}
	return out


## 左右分佈：下一塊的 x 以上一塊為中心抽 ＝ 隨機遊走，天生會在井的一側盤旋好幾塊。
## 量兩個指標——整體偏側比例，以及「最長連續落在同一側」的塊數。後者才是玩家實際
## 感受到的「這一段全擠在左邊」；只看比例會被前後相消洗成漂亮的 50%。
func _audit_x_balance(body: Array) -> Dictionary:
	var center := (SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5
	var sorted := body.duplicate()
	sorted.sort_custom(func(a, b): return a.center().y > b.center().y)   # 由下往上

	var left := 0
	var run := 0
	var worst_run := 0
	var prev_side := 0
	for p in sorted:
		var side: int = -1 if p.center().x < center else 1
		if side < 0:
			left += 1
		if side == prev_side:
			run += 1
		else:
			run = 1
			prev_side = side
		worst_run = maxi(worst_run, run)

	var total := maxi(sorted.size(), 1)
	return {
		"left": left,
		"right": sorted.size() - left,
		"left_ratio": float(left) / float(total),
		"worst_run": worst_run,
	}


## 「最省力的接法要橫移多遠」：對每塊平台，在下方一次跳躍範圍內找水平最近的那塊，
## 記錄兩者的水平距離。這是左右平衡邏輯的**代價指標**——把落點往人少的一側拉，
## 必然拉長橫移距離。平均值上升代表玩家要更常全速橫移，最大值超過可達視窗就是生成 bug。
func _required_dx(body: Array) -> Dictionary:
	var t_rise: float = absf(SpikeConfig.JUMP_VELOCITY) / SpikeConfig.GRAVITY
	var limit: float = SpikeConfig.MOVE_MAX_SPEED * t_rise * SpikeConfig.REACHABILITY_MARGIN

	var total := 0.0
	var count := 0
	var worst := 0.0
	for i in range(body.size()):
		var p: WellPlatform = body[i]
		var pc: Vector2 = p.center()
		var best := INF
		for j in range(body.size()):
			if i == j:
				continue
			var q: WellPlatform = body[j]
			var qc: Vector2 = q.center()
			# 只看下方、且在一次跳躍垂直範圍內的候選
			if qc.y <= pc.y or qc.y - pc.y > SpikeConfig.MAX_JUMP_HEIGHT:
				continue
			best = minf(best, absf(qc.x - pc.x))
		if best < INF:
			total += best
			count += 1
			worst = maxf(worst, best)
	return {
		"avg": 0.0 if count == 0 else total / float(count),
		"max": worst,
		"limit": limit,
	}


## 蟲洞：數量、出口綁定率、實際送了幾公尺、有沒有綁到不該綁的出口。
## 「出口固定在平台上」是這次的守門承諾，沒綁到出口的蟲洞等於不存在。
## 蟲洞可用性——**走串流路徑**，這是上面那條靜態稽核測不到的東西。
##
## v9 的蟲洞在真實遊戲裡一次都沒出現過，但靜態稽核是綠的：它一口氣
## ensure_generated_to(終點)，既沒有串流上限也沒有 prune，出口當然全部綁得到。
## 這條改走 WellWorld._stream_world() 真正在跑的那條路——逐格把相機往上推，每格都做
## ensure_generated_to(cam - VIEW_H) + prune_below(cam + VIEW_H)——然後問一個問題：
## 「蟲洞進到畫面裡的當下，它是不是 ready_to_use()？」
## 修好之前這個比值是 0/N，修好之後必須是 N/N。
func _audit_streaming_wormholes() -> Dictionary:
	var gen := WellGenerator.new()
	gen.setup(0.0, 20260807)

	var seen_any := {}
	var seen_ready := {}
	var cam_y := 0.0
	var stop_y: float = SpikeConfig.goal_y(0.0)
	var step: float = SpikeConfig.VIEW_H * 0.25

	while cam_y > stop_y:
		gen.ensure_generated_to(cam_y - SpikeConfig.VIEW_H)
		var top: float = cam_y - SpikeConfig.VIEW_H * 0.5
		var bot: float = cam_y + SpikeConfig.VIEW_H * 0.5
		for wh in gen.wormholes:
			if wh.pos.y < top or wh.pos.y > bot:
				continue
			seen_any[wh] = true
			if wh.ready_to_use():
				seen_ready[wh] = true
		gen.prune_below(cam_y + SpikeConfig.VIEW_H)
		cam_y -= step

	return {"in_view": seen_any.size(), "usable": seen_ready.size()}


func _audit_wormholes(gen: WellGenerator) -> Dictionary:
	var bound := 0
	var bad_exit := 0
	var moving_exit := 0
	var min_rise := INF
	for wh in gen.wormholes:
		if wh.exit_platform == null:
			continue
		bound += 1
		var ex: WellPlatform = wh.exit_platform
		if ex.is_goal or ex.kind == WellPlatform.Kind.FRAGILE:
			bad_exit += 1
		match ex.kind:
			WellPlatform.Kind.MOVING, WellPlatform.Kind.VERTICAL, WellPlatform.Kind.CIRCULAR:
				moving_exit += 1
		min_rise = minf(
			min_rise, (wh.pos.y - ex.center().y) / SpikeConfig.PIXELS_PER_METER
		)
	return {
		"total": gen.wormholes.size(),
		"bound": bound,
		"bad_exit": bad_exit,
		"moving_exit": moving_exit,
		"min_rise": 0.0 if bound == 0 else min_rise,
	}


## Pameloe 生成統計（v16）：總數、500m 以下必為 0、與母平台水平距離必須 >= PAMELOE_MIN_DIST_X、
## 一律要落在井內。
##
## ⚠ 找母平台不能拿「全場離牠最近的平台」比——pameloe 只保證跟**生牠的那塊**水平隔開，跟其他
##   後來才長出來的主鏈平台是允許重疊的（見 WellGenerator._make_pameloe 的 ⚠：牠生成後完全不動，
##   垂直上仍可能跟下一塊還沒生成的主鏈板疊到，對策是繪製順序而不是位置保證）。拿「全場最近」
##   比對會把這種被明文允許的重疊誤判成違規，是會假紅的驗法。
## ⚠ 母平台的 y 可以精確反推：`float_base_y` 就是
##   `plat.pos.y - plat.size.y * 0.5 - PAMELOE_HOVER_Y`（見 WellGenerator._make_pameloe）。
##   拿這條式子去配對，比亂猜「最近」準，而且不用碰生成器內部的隨機邏輯。
## ⚠⚠ 反推一定要讀 `float_base_y` **不能讀 pos.y**（08-10 漂浮上線後）：pos.y 是掛點加上
##   當下的正弦位移，跟這條式子差一個振幅 ⇒ 整批 pameloe 全部配不到母平台，`too_close`
##   那條檢查就完全不會執行 —— 表面上是紅燈，實際上是**保命條款靜默失效**（水平隔離是
##   「主鏈那條唯一的路不會被即死物堵住」的唯一保證）。這一版就是這樣紅的。
func _audit_pameloe_spawns(gen: WellGenerator) -> Dictionary:
	var half: float = SpikeConfig.PAMELOE_SIZE.x * 0.5
	var lo: float = SpikeConfig.WELL_LEFT + half
	var hi: float = SpikeConfig.WELL_RIGHT - half

	var total := 0
	var below_start := 0
	var too_close := 0
	var out_of_well := 0
	var unmatched_host := 0

	for m in gen.monsters:
		if m.kind != WellMonster.Kind.PAMELOE:
			continue
		total += 1

		# ⚠ 高度也用掛點算：pos.y 帶著漂浮位移，問「牠生在多高」該問不晃的那個值
		var h_m: float = SpikeConfig.meters_from_y(0.0, m.float_base_y)
		if h_m < SpikeConfig.PAMELOE_START_HEIGHT_M - 0.5:
			below_start += 1

		if m.pos.x < lo - 0.5 or m.pos.x > hi + 0.5:
			out_of_well += 1

		# 反推母平台：找那塊「懸浮公式算出來的 y」跟牠的**掛點**最貼近的板
		var host: WellPlatform = null
		var best_err := INF
		for p in gen.platforms:
			var expect_y: float = p.pos.y - p.size.y * 0.5 - SpikeConfig.PAMELOE_HOVER_Y
			var err: float = absf(m.float_base_y - expect_y)   # ⚠ 不是 pos.y，見上方 ⚠⚠
			if err < best_err:
				best_err = err
				host = p
		if host == null or best_err > 0.5:
			unmatched_host += 1
			continue
		if absf(m.pos.x - host.pos.x) < SpikeConfig.PAMELOE_MIN_DIST_X - 0.5:
			too_close += 1

	return {
		"total": total,
		"below_start": below_start,
		"too_close": too_close,
		"out_of_well": out_of_well,
		"unmatched_host": unmatched_host,
	}


## 兩塊平台的「運動包絡線」（含板寬、含整段巡邏／繞圈範圍）是否在 x、y 都相交。
## 只比 pos 會漏掉「現在沒疊、等一下掃過去才疊」的情形，所以一律比包絡線。
func _count_envelope_overlaps(body: Array) -> int:
	var hits := 0
	for i in range(body.size()):
		var a: WellPlatform = body[i]
		var ac: Vector2 = a.center()
		var ax: Vector2 = a.span_x()
		var a_lo: float = ac.y - a.up_extent() - a.size.y * 0.5
		var a_hi: float = ac.y + a.down_extent() + a.size.y * 0.5
		for j in range(i + 1, body.size()):
			var b: WellPlatform = body[j]
			var bc: Vector2 = b.center()
			if absf(bc.y - ac.y) > 400.0:
				continue
			var b_lo: float = bc.y - b.up_extent() - b.size.y * 0.5
			var b_hi: float = bc.y + b.down_extent() + b.size.y * 0.5
			if a_hi <= b_lo or b_hi <= a_lo:
				continue
			var bx: Vector2 = b.span_x()
			if ax.y <= bx.x or bx.y <= ax.x:
				continue
			hits += 1
	return hits


## 每一塊平台「最容易的上來方式」在最壞擺動相位下要跳多高：
## 起跳板擺到最低（+down_extent）、目標板擺到最高（-up_extent）時的垂直距離，
## 取所有下方候選板裡最小的那個。整座井的最大值不得超過 spacing 的硬上限。
##
## ⚠ 回傳 Dictionary 而不是單一數字（08-10）：只印「有平台跳不到」定位不了任何東西——
##   跳不到的成因分歧很大（擺幅疊加／水平候選全被排除／額外跳板下移），沒有那一對板的
##   種類與座標，紅燈只能靠重跑猜。錯誤訊息要能直接指向現場。
##
## ⚠⚠ 被檢查的目標（body）與起跳候選（candidates）是**兩個不同的集合**，08-10 修正：
##   body 排除終點平台（它是全寬特例，可達性由前一塊保證、且會跟每個鄰居都「重疊」），
##   但終點平台**是真的踩得到的板**，所以它必須留在起跳候選裡。
##   兩者混用成同一個集合時，「終點正上方那一塊」會找不到它腳下真正的踏板，只能一路
##   算到終點**下方**那塊，量出來的是兩段距離相加 ⇒ 假紅燈。
##   ⚠ 這是靜默的假陰性／假陽性同源的坑：終點之後仍會繼續生成（`goal_spawned` 只管
##     「全寬那塊只擺一次」，不管井要不要繼續長），所以終點上方永遠有板，這條路徑一定會走到。
func _worst_required_jump(body: Array, candidates: Array) -> Dictionary:
	var t_rise: float = absf(SpikeConfig.JUMP_VELOCITY) / SpikeConfig.GRAVITY
	var max_dx: float = SpikeConfig.MOVE_MAX_SPEED * t_rise * SpikeConfig.REACHABILITY_MARGIN
	var worst := 0.0
	var worst_to: WellPlatform = null
	var worst_from: WellPlatform = null
	for i in range(body.size()):
		var p: WellPlatform = body[i]
		var pc: Vector2 = p.center()
		var target_top: float = pc.y - p.up_extent()
		var best := INF
		var best_q: WellPlatform = null
		for q in candidates:
			if q == p:
				continue
			var qc: Vector2 = q.center()
			if qc.y <= pc.y:
				continue
			if qc.y - pc.y > 400.0:
				continue
			# 水平也得搆得到，否則「正上方 400px 內」會把整排井寬的板都算成候選
			if absf(qc.x - pc.x) > max_dx + p.up_extent() + q.up_extent():
				continue
			var dist: float = (qc.y + q.down_extent()) - target_top
			if dist < best:
				best = dist
				best_q = q
		if best < INF and best > worst:
			worst = best
			worst_to = p
			worst_from = best_q
	return {"worst": worst, "to": worst_to, "from": worst_from}


## 把最壞那一對平台描述成一行人看得懂的字串（給紅燈訊息用）。
func _describe_worst_pair(info: Dictionary, start_y: float) -> String:
	var to_p = info.get("to")
	var from_p = info.get("from")
	if to_p == null or from_p == null:
		return "（找不到對應的平台，稽核本身可能有問題）"
	var to_c: Vector2 = to_p.center()
	var from_c: Vector2 = from_p.center()
	return "%.0fm 附近：從 kind%d(x%.0f, 擺幅±%.0f) 跳到 kind%d(x%.0f, 擺幅±%.0f)，中心距 %.0f" % [
		SpikeConfig.meters_from_y(start_y, to_c.y),
		from_p.kind, from_c.x, from_p.up_extent(),
		to_p.kind, to_c.x, to_p.up_extent(),
		from_c.y - to_c.y,
	]
