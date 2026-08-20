extends Node
## 教學關稽核（08-13x，SpikeConfig SECTION 8f）。對外入口 _audit_tutorial()。
##
## 分五組：
##   A 表本身      — TUTORIAL_PLATFORMS／CUE_CARDS／INTERFERENCE_EVENTS 的形狀與單調性
##   B 生成器       — 固定佈局（不吃 seed）、不污染主 _rng、不生 buff／墓碑
##   C 可跳性       — 一般間距都在單跳範圍內，鞭子／jetpack 兩段刻意超過
##   D 干擾 API     — src/interference.gd 的「教學用強制觸發一次」四個 API 真的生效
##   E 結算路徑     — 真的呼叫 main.gd._finish()，驗證教學關只入帳金幣、其餘存檔不動
##
## ⚠ 逐項印出來而不是回一個合成的 bool，理由同 audit_buffs.gd 檔頭：查是哪一條
##   壞掉，要讀得到細項而不是只知道「有問題」。

const SEED_A := 20260813
const SEED_B := 776655


func _audit_tutorial() -> bool:
	var checks := {}
	_audit_tables(checks)
	_audit_generator(checks)
	_audit_reachability(checks)
	_audit_interference_api(checks)
	_audit_save_roundtrip(checks)
	_audit_finish_isolated(checks)

	var bad := PackedStringArray()
	for k in checks:
		if not checks[k]:
			bad.append(String(k))

	print("--- 教學關稽核（SECTION 8f）---")
	if bad.is_empty():
		print("  表單調性、固定佈局、RNG 隔離、無 buff／墓碑、可跳性、干擾 API、"
			+ "存檔往返、結算隔離 — %d 項全通過" % checks.size())
	else:
		print("  !! 教學關失敗細項：%s" % ", ".join(bad))
	return bad.is_empty()


# ------------------------------------------------------------------
# A. 表本身：單調性、範圍、與規格第 5 條教學點順序一致
# ------------------------------------------------------------------

func _audit_tables(checks: Dictionary) -> void:
	# 字卡：由下到上單調遞增，且都落在 [0, TUTORIAL_GOAL_M]
	var cue_ok := true
	var prev_h := -1.0
	for row: Dictionary in SpikeConfig.TUTORIAL_CUE_CARDS:
		var h: float = float(row["h_m"])
		if h <= prev_h or h < 0.0 or h > SpikeConfig.TUTORIAL_GOAL_M:
			cue_ok = false
		prev_h = h
	checks["字卡高度單調遞增且落在 0~TUTORIAL_GOAL_M"] = cue_ok
	checks["字卡至少涵蓋規格第 5 條的 10 個教學點"] = \
		SpikeConfig.TUTORIAL_CUE_CARDS.size() >= 10

	# 按鍵模板：文案裡的 {aim} 之類一定要被 tutorial_cue_text() 換掉。
	# ⚠ 這條要驗兩個方向：①換完不准還留大括號（漏接就是玩家臉上一排 `{jet}`）
	#   ②換完的字串要真的變了（若有模板卻原樣返回＝format 沒接上），而且換出來的
	#   就是 SpikeKeys 當下的綁定——寫死「A」的話玩家改鍵後教學會教錯，且不會報錯。
	var tpl_ok := true
	var saw_template := false
	for row: Dictionary in SpikeConfig.TUTORIAL_CUE_CARDS:
		var raw: String = String(row["text"])
		var shown: String = SpikeConfig.tutorial_cue_text(raw)
		if shown.contains("{") or shown.contains("}"):
			tpl_ok = false
		if raw.contains("{"):
			saw_template = true
			if shown == raw:
				tpl_ok = false
	checks["字卡按鍵走模板且已被實際綁定取代"] = tpl_ok and saw_template
	checks["移動字卡印的是當下綁定的鍵"] = \
		SpikeConfig.tutorial_cue_text("{left}") == SpikeKeys.label_of("left")

	# 干擾事件：由下到上單調遞增、都落在範圍內，且種類依序是規格第 5 條 ⑨ 那四種
	var events: Array = SpikeConfig.TUTORIAL_INTERFERENCE_EVENTS
	var event_ok := true
	prev_h = -1.0
	for row: Dictionary in events:
		var h: float = float(row["h_m"])
		if h <= prev_h or h < 0.0 or h > SpikeConfig.TUTORIAL_GOAL_M:
			event_ok = false
		prev_h = h
	checks["干擾事件高度單調遞增且落在 0~TUTORIAL_GOAL_M"] = event_ok

	var expect_order: Array[String] = ["projectile", "tail", "doom"]
	var order_ok := events.size() == expect_order.size()
	if order_ok:
		for i in range(events.size()):
			if String(events[i]["kind"]) != expect_order[i]:
				order_ok = false
	checks["干擾事件依規格順序：投擲物→甩尾→黑洞"] = order_ok

	# 平台表：id 不重複（重複會讓 by_id 覆寫掉前一塊，教學表的引用就會指錯地方）
	var seen_ids := {}
	var ids_unique := true
	for row: Dictionary in SpikeConfig.TUTORIAL_PLATFORMS:
		var pid: String = String(row.get("id", ""))
		if pid == "":
			continue
		if seen_ids.has(pid):
			ids_unique = false
		seen_ids[pid] = true
	checks["平台表 id 不重複"] = ids_unique

	# 五個關鍵 id 都真的存在（後面 B／C／D 組的稽核都靠它們定位）
	var required_ids := [
		"tutorial_whip_launch", "tutorial_whip_landing",
		"tutorial_jetpack_launch", "tutorial_jetpack_landing",
		"tutorial_wormhole_entry", "tutorial_wormhole_exit",
		"tutorial_tail_target", "tutorial_doom_target",
		"tutorial_chattini_host", "tutorial_pameloe_shot_host", "tutorial_pameloe_laser_host",
	]
	var ids_present := true
	for rid in required_ids:
		if not seen_ids.has(rid):
			ids_present = false
	checks["平台表包含所有教學點需要的 id"] = ids_present

	# 08-13④⑤⑥⑦ 三訂新增（200m→500m、蟲洞位移、密度、喘息間隔）——見下方各條註解。
	checks["TUTORIAL_GOAL_M 是 500"] = is_equal_approx(SpikeConfig.TUTORIAL_GOAL_M, 500.0)

	# 蟲洞位移＝WORMHOLE_RISE_M：教學關曾經自己寫死入口 51／出口 57，只送 6m
	# （規格明講要跟正式蟲洞的 +40m 一致），現在出口高度要用常數推導出來，這裡直接
	# 讀平台表反算兩塊的高度差，跟常數比對，不是驗「表看起來對不對」。
	var wh_entry_h := _platform_h("tutorial_wormhole_entry")
	var wh_exit_h := _platform_h("tutorial_wormhole_exit")
	checks["蟲洞位移等於 WORMHOLE_RISE_M"] = \
		not is_nan(wh_entry_h) and not is_nan(wh_exit_h) \
		and is_equal_approx(wh_exit_h - wh_entry_h, SpikeConfig.WORMHOLE_RISE_M)

	# 鞭子／jetpack 間距不變式的「常數關係」版本（同 audit_hazards.gd _audit_pameloe 的
	# consts_ok 模式）：只驗 SpikeConfig 常數彼此的大小關係，完全不碰 TUTORIAL_PLATFORMS
	# 的literal 數字——保護「MAX_JUMP_HEIGHT／WHIP_RANGE／JETPACK_FUEL_METERS_BASE 被
	# 改壞，但表沒動」這個盲點（下面 _audit_reachability 那條驗的是表的實際間距，
	# 兩條互補：一條驗常數本身留不留得出這個窗口，一條驗表有沒有真的落在窗口內）。
	checks["鞭子／jetpack 間距常數關係成立（保命條款）"] = \
		SpikeConfig.MAX_JUMP_HEIGHT < SpikeConfig.WHIP_RANGE \
		and SpikeConfig.WHIP_RANGE \
			< SpikeConfig.JETPACK_FUEL_METERS_BASE * SpikeConfig.PIXELS_PER_METER

	# 非教學點區段的間距要落在 SPACING_MIN_AT_0~SPACING_MAX_AT_0 帶內（對齊「正式關卡
	# 100m 附近」密度，使用者原話「平台太少、來不及閃干擾」）。排除三個刻意不受這條
	# 約束的區段：鞭子段、jetpack 段（間距刻意超過單跳範圍，見上面 ⚠⚠）、特殊平台
	# 示範段（MOVING／LAUNCHER／FRAGILE，維持看得清楚的節奏）。只看主鏈——
	# tail/doom 側邊裝飾板不算在內（它們本來就不在玩家非走不可的路徑上）。
	var density_ok := true
	var main_rows: Array[Dictionary] = []
	for row: Dictionary in SpikeConfig.TUTORIAL_PLATFORMS:
		var mpid: String = String(row.get("id", ""))
		if mpid == "tutorial_tail_target" or mpid == "tutorial_doom_target":
			continue
		main_rows.append(row)
	var exempt_kinds := ["MOVING", "LAUNCHER", "FRAGILE"]
	for i in range(main_rows.size() - 1):
		var r0: Dictionary = main_rows[i]
		var r1: Dictionary = main_rows[i + 1]
		var id0: String = String(r0.get("id", ""))
		var id1: String = String(r1.get("id", ""))
		if (id0 == "tutorial_whip_launch" and id1 == "tutorial_whip_landing") \
			or (id0 == "tutorial_jetpack_launch" and id1 == "tutorial_jetpack_landing"):
			continue
		if exempt_kinds.has(String(r0.get("kind", ""))) \
			or exempt_kinds.has(String(r1.get("kind", ""))):
			continue
		var dens_gap_px: float = (float(r1["h_m"]) - float(r0["h_m"])) * SpikeConfig.PIXELS_PER_METER
		if dens_gap_px < SpikeConfig.SPACING_MIN_AT_0 or dens_gap_px > SpikeConfig.SPACING_MAX_AT_0:
			density_ok = false
	checks["非教學點區段間距落在 SPACING_MIN_AT_0~SPACING_MAX_AT_0"] = density_ok

	# 3 隻怪物 host ＋ 3 種干擾事件＝6 個教學點（08-17 側風＋抽跳板合併後從 4 種回落
	# 成 3 種），兩兩之間的高度間隔都要 ≥ TUTORIAL_HAZARD_GAP_MIN_M
	# （使用者原話「各自分段出現、不要同時」）。
	var hazard_hs: Array[float] = [
		_platform_h("tutorial_chattini_host"),
		_platform_h("tutorial_pameloe_shot_host"),
		_platform_h("tutorial_pameloe_laser_host"),
	]
	for ev: Dictionary in SpikeConfig.TUTORIAL_INTERFERENCE_EVENTS:
		hazard_hs.append(float(ev["h_m"]))
	hazard_hs.sort()
	var hazard_gap_ok := true
	for i in range(hazard_hs.size() - 1):
		if hazard_hs[i + 1] - hazard_hs[i] < SpikeConfig.TUTORIAL_HAZARD_GAP_MIN_M:
			hazard_gap_ok = false
	checks["怪物與干擾事件兩兩間隔 >= TUTORIAL_HAZARD_GAP_MIN_M"] = hazard_gap_ok


## 從平台表按 id 找高度（m）。找不到回 NAN——呼叫端要自己判斷，不要讓稽核在這裡當掉。
func _platform_h(id: String) -> float:
	for row: Dictionary in SpikeConfig.TUTORIAL_PLATFORMS:
		if String(row.get("id", "")) == id:
			return float(row["h_m"])
	return NAN


# ------------------------------------------------------------------
# B. 生成器：固定佈局不吃 seed、不污染主 _rng、不生 buff／墓碑
# ------------------------------------------------------------------

func _audit_generator(checks: Dictionary) -> void:
	var ga := WellGenerator.new()
	ga.setup(0.0, SEED_A, 0.0, 0, true)
	var gb := WellGenerator.new()
	gb.setup(0.0, SEED_B, 0.0, 0, true)

	# ① 兩顆不同 seed 產出的平台座標序列完全相同（規格第 5 條驗收①）
	var same_layout := ga.platforms.size() == gb.platforms.size()
	if same_layout:
		for i in range(ga.platforms.size()):
			var pa: WellPlatform = ga.platforms[i]
			var pb: WellPlatform = gb.platforms[i]
			if not pa.pos.is_equal_approx(pb.pos) or pa.kind != pb.kind:
				same_layout = false
				break
	checks["不同 seed 產出完全相同的平台座標序列"] = same_layout

	# ② 教學關不污染主 _rng：同一顆 seed，一邊建教學關、一邊完全不建（level 0、非教學），
	#    setup() 之後兩邊都還沒真的骰過任何東西，各自問一次 randf() 必須相同——
	#    同 audit_buffs.gd「抽 buff 不污染主 RNG」那條的做法（見該檔 A 組 ⑪的註解）。
	var g_plain := WellGenerator.new()
	g_plain.setup(0.0, SEED_A, 0.0, 0)
	var g_tutorial := WellGenerator.new()
	g_tutorial.setup(0.0, SEED_A, 0.0, 0, true)
	checks["教學關不污染主 RNG"] = is_equal_approx(g_plain._rng.randf(), g_tutorial._rng.randf())

	# ③ 不生開局三選一 buff（就算故意灌關卡二的 level_idx，正常情況下會觸發 buff_choice）
	var g_gate := WellGenerator.new()
	g_gate.setup(0.0, SEED_A, 0.0, 1, true)
	checks["教學關不生開局三選一 buff"] = g_gate.buff_orbs.is_empty()

	# ④ 不生墓碑（就算故意灌一個會觸發墓碑的歷史最高高度）
	var g_tomb := WellGenerator.new()
	g_tomb.setup(0.0, SEED_A, 500.0, 0, true)
	var has_tomb := false
	for pk in g_tomb.pickups:
		var pickup: WellPickup = pk
		if pickup.kind == WellPickup.Kind.TOMB:
			has_tomb = true
	checks["教學關不生墓碑"] = not has_tomb

	# ⑤ 怪物表確實生出 1 隻 chattini（PATROL）＋ 2 隻 pameloe（art_variant 0／1 各一）
	var patrol_count := 0
	var pameloe_variants := {}
	for m in ga.monsters:
		var mon: WellMonster = m
		if mon.kind == WellMonster.Kind.PATROL:
			patrol_count += 1
		else:
			pameloe_variants[mon.art_variant] = true
	checks["教學關生出剛好 1 隻 chattini"] = patrol_count == 1
	checks["教學關兩種 pameloe 都各生一隻"] = pameloe_variants.has(0) and pameloe_variants.has(1)

	# ⑥ 蟲洞出口已經直接綁定好，不必等 _resolve_wormholes
	checks["教學關蟲洞出口已就緒"] = ga.wormholes.size() == 1 and ga.wormholes[0].ready_to_use()

	# ⑦ 出口在 TUTORIAL_GOAL_M
	var goal_plat: WellPlatform = ga.platforms[ga.platforms.size() - 1]
	var goal_h: float = SpikeConfig.meters_from_y(0.0, goal_plat.pos.y)
	checks["出口在 TUTORIAL_GOAL_M"] = goal_plat.is_goal \
		and is_equal_approx(goal_h, SpikeConfig.TUTORIAL_GOAL_M)

	# ⑧ ensure_generated_to() 對教學關是 no-op：呼叫後平台數不變
	var before := ga.platforms.size()
	ga.ensure_generated_to(-999999.0)
	checks["ensure_generated_to() 對教學關是 no-op"] = ga.platforms.size() == before


# ------------------------------------------------------------------
# C. 可跳性：一般間距都在單跳範圍內，鞭子／jetpack 兩段刻意超過
# ------------------------------------------------------------------

## 教學表 → 主鏈高度序列（含起跳點 0m 與出口 TUTORIAL_GOAL_M，排除干擾示範用的
## 兩塊側邊裝飾平台——它們不在玩家非走不可的路徑上，見 SpikeConfig SECTION 8f 的 ⚠）。
func _tutorial_chain() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"h_m": 0.0, "id": ""}]
	for row: Dictionary in SpikeConfig.TUTORIAL_PLATFORMS:
		var pid: String = String(row.get("id", ""))
		if pid == "tutorial_tail_target" or pid == "tutorial_doom_target":
			continue
		out.append({"h_m": float(row["h_m"]), "id": pid})
	out.append({"h_m": SpikeConfig.TUTORIAL_GOAL_M, "id": "tutorial_goal"})
	return out


func _audit_reachability(checks: Dictionary) -> void:
	var chain := _tutorial_chain()
	var normal_ok := true
	var whip_gap_ok := false
	var jetpack_gap_ok := false
	var whip_seen := false
	var jetpack_seen := false

	for i in range(chain.size() - 1):
		var h0: float = chain[i]["h_m"]
		var h1: float = chain[i + 1]["h_m"]
		var id0: String = chain[i]["id"]
		var id1: String = chain[i + 1]["id"]
		var gap_px: float = (h1 - h0) * SpikeConfig.PIXELS_PER_METER

		if id0 == "tutorial_whip_launch" and id1 == "tutorial_whip_landing":
			whip_seen = true
			whip_gap_ok = gap_px > SpikeConfig.MAX_JUMP_HEIGHT and gap_px <= SpikeConfig.WHIP_RANGE
			continue
		if id0 == "tutorial_jetpack_launch" and id1 == "tutorial_jetpack_landing":
			jetpack_seen = true
			var fuel_px: float = SpikeConfig.JETPACK_FUEL_METERS_BASE * SpikeConfig.PIXELS_PER_METER
			jetpack_gap_ok = gap_px > SpikeConfig.WHIP_RANGE and gap_px <= fuel_px
			continue

		if gap_px <= 0.0 or gap_px > SpikeConfig.MAX_JUMP_HEIGHT:
			normal_ok = false

	checks["一般段間距都在單跳可達範圍內"] = normal_ok
	checks["找得到鞭子段（launch→landing）"] = whip_seen
	checks["找得到 jetpack 段（launch→landing）"] = jetpack_seen
	checks["鞭子段間距超過單跳但在鞭子射程內"] = whip_gap_ok
	checks["jetpack 段間距超過鞭子射程（非用 jetpack 不可）"] = jetpack_gap_ok


# ------------------------------------------------------------------
# D. 干擾 API：src/interference.gd 的教學用強制觸發，真的生效
# ------------------------------------------------------------------

func _audit_interference_api(checks: Dictionary) -> void:
	var itf := Interference.new()
	itf.reset()

	itf.tutorial_trigger_projectile(640.0)
	checks["tutorial_trigger_projectile 真的掛出預警"] = itf.warns.size() == 1

	var tail_plat := WellPlatform.new()
	tail_plat.kind = WellPlatform.Kind.STATIC
	tail_plat.size = SpikeConfig.PLATFORM_SIZE
	tail_plat.pos = Vector2(340.0, -100.0)
	checks["甩尾觸發前 tail_strikes 是空的"] = itf.tail_strikes.is_empty()
	itf.tutorial_trigger_tail(tail_plat)
	checks["tutorial_trigger_tail 真的標記到平台且生出一條甩尾"] = \
		tail_plat.steal_warn >= 0.0 and itf.tail_strikes.size() == 1

	var doom_plat := WellPlatform.new()
	doom_plat.kind = WellPlatform.Kind.STATIC
	doom_plat.size = SpikeConfig.PLATFORM_SIZE
	doom_plat.pos = Vector2(940.0, -100.0)
	itf.tutorial_trigger_doom(doom_plat)
	checks["tutorial_trigger_doom 真的掛出黑洞預警"] = itf.doom_warns.size() == 1

	# tutorial_step 只推進既有物件、不跑時間驅動階梯：多跑幾幀之後 stage() 仍應是 0
	for _i in range(120):
		itf.tutorial_step(1.0 / 60.0, 0.0)
	checks["tutorial_step 不會偷偷解鎖正常的時間驅動階梯"] = itf.stage() == 0


# ------------------------------------------------------------------
# E. 存檔往返（tutorial_done）
# ------------------------------------------------------------------

func _audit_save_roundtrip(checks: Dictionary) -> void:
	var snap: bool = SpikeSave.tutorial_done
	SpikeSave.tutorial_done = true
	var dict := SpikeSave._to_save_dict()
	checks["_to_save_dict 含 tutorial_done=true"] = bool(dict.get("tutorial_done", false))

	SpikeSave.tutorial_done = false
	SpikeSave._apply_save_dict(dict)
	checks["_apply_save_dict 讀回 tutorial_done=true"] = SpikeSave.tutorial_done == true

	SpikeSave.tutorial_done = snap


# ------------------------------------------------------------------
# F. 結算路徑隔離：真的走 main.gd._finish()，驗證教學關只入帳金幣
# ------------------------------------------------------------------

## ⚠ 這條稽核會真的建一個 Main 節點（連帶建 WellWorld／SpikeUI）並呼叫真實的
## _finish()——「用假結算資料走一次真實路徑」是使用者規格明講的驗收條件，不能只
## 驗一份重寫過的邏輯（那樣驗到的是稽核自己的假設，不是 main.gd 實際的行為）。
## 開始與結束都存＋還原 SpikeSave 的相關欄位，不讓這條稽核的假資料污染後面別的稽核
## （同 audit_ui.gd／audit_levels.gd 既有的「跑完自己還原」慣例）。
func _audit_finish_isolated(checks: Dictionary) -> void:
	# 08-20 發佈開關：先驗「關掉時真的擋住教學關」（驗收條件本身），再驗「開回去
	# 教學關機制沒壞」——兩者都要真的走 main._start_run() 這條路徑，不能只驗
	# SpikeConfig.TUTORIAL_ENABLED and not tutorial_done 這個布林式本身有沒有寫對。
	var snap_tutorial_enabled: bool = SpikeConfig.TUTORIAL_ENABLED
	var snap_tutorial_done: bool = SpikeSave.tutorial_done
	var snap_story_intro: bool = SpikeSave.story_seen_of(SpikeConfig.STORY_INTRO_ID)
	var snap_best_normal: float = SpikeSave.best_height_normal_m
	var snap_best_extreme: float = SpikeSave.best_height_extreme_m
	var snap_cleared_max: int = SpikeSave.cleared_max
	var snap_unlocked: int = SpikeSave.unlocked_level
	var snap_ach: Dictionary = SpikeSave.achievements.duplicate(true)
	var snap_corpse: Dictionary = SpikeSave.corpse_deaths.duplicate(true)
	var snap_coins: int = SpikeSave.coins
	# 關掉開關那次會真的落進「非教學局」分支（main._start_run 的 report_run_start／
	# record_run_seed），教學局那次不會走到那裡（提早 return）——這兩個欄位只有前者
	# 會動到，原本這條稽核不需要存，08-20 補上避免留下未還原的側效應。
	var snap_stats: Dictionary = SpikeSave.stats.duplicate(true)
	var snap_last_seed: int = SpikeSave.last_run_seed

	SpikeSave.tutorial_done = false
	# 跳過開場劇情頁：這條稽核要驗的是「教學關結算」，不是劇情頁流程（那是 UI 稽核的事）。
	SpikeSave.story_seen[SpikeConfig.STORY_INTRO_ID] = true

	var main := preload("res://src/main.gd").new()
	add_child(main)

	checks["開幕劇情看過後先回標題、不自動開局"] = main.state == main.S_START

	# 發佈開關關掉：即使 tutorial_done 仍是 false，也不該進教學關（驗收條件①本身）。
	SpikeConfig.TUTORIAL_ENABLED = false
	main._start_run()
	checks["發佈開關關掉時，tutorial_done=false 也不會進教學關"] = not main.world.tutorial_mode

	# 開回去：接下來驗的是「教學關機制本身沒壞」，跟要不要在正式版露出是兩件事。
	SpikeConfig.TUTORIAL_ENABLED = true
	main._start_run()
	checks["發佈開關開回去、tutorial_done=false 時進教學關模式"] = main.world.tutorial_mode

	main.world.best_m = 500.0
	main.world.coin_count = 7
	main.world.running = true
	main._finish(true, "")

	checks["教學關結算：coins 有入帳"] = SpikeSave.coins == snap_coins + 7
	checks["教學關結算：不寫最高高度"] = \
		is_equal_approx(SpikeSave.best_height_normal_m, snap_best_normal) \
		and is_equal_approx(SpikeSave.best_height_extreme_m, snap_best_extreme)
	checks["教學關結算：不寫通關紀錄／解鎖"] = \
		SpikeSave.cleared_max == snap_cleared_max and SpikeSave.unlocked_level == snap_unlocked
	checks["教學關結算：成就字典不變"] = SpikeSave.achievements.hash() == snap_ach.hash()
	checks["教學關結算：井底屍體堆不變"] = SpikeSave.corpse_deaths.hash() == snap_corpse.hash()
	checks["教學關結算：mark_tutorial_done 生效"] = SpikeSave.tutorial_done == true

	remove_child(main)
	main.queue_free()

	SpikeSave.tutorial_done = snap_tutorial_done
	if not snap_story_intro:
		SpikeSave.story_seen.erase(SpikeConfig.STORY_INTRO_ID)
	SpikeSave.best_height_normal_m = snap_best_normal
	SpikeSave.best_height_extreme_m = snap_best_extreme
	SpikeSave.cleared_max = snap_cleared_max
	SpikeSave.unlocked_level = snap_unlocked
	SpikeSave.achievements = snap_ach
	SpikeSave.corpse_deaths = snap_corpse
	SpikeSave.coins = snap_coins
	SpikeSave.stats = snap_stats
	SpikeSave.last_run_seed = snap_last_seed
	SpikeConfig.TUTORIAL_ENABLED = snap_tutorial_enabled
