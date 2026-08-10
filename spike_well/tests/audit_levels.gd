extends Node
## 關卡制／無盡模式／第三批貼圖的稽核（08-10）。對外入口 _audit_levels()。
##
## 為什麼這組要獨立存在：bot 跑局爬不到 100m，**登頂那條路徑 bot 永遠驗不到**
## （見 smoke 輸出的「最高高度」）。沒有這組稽核的話，「抵達目標會不會結算」這件事
## 完全沒有任何自動檢查——而 08-09 就已經有過一次 cleared 訊號整條死掉、全綠燈的紀錄。
##
## ⚠ 每一條都自己定死依賴的狀態並在結束時還原（常青認知第 4 條：稽核之間會互相污染）。
##   特別是 SpikeSave.selected_level／unlocked_level／endless_mode 三顆——它們會改
##   SpikeConfig.goal_meters，漏還原會讓後面的 bot 跑局在錯誤的終點上跑。

const FPS := 60.0
const DT := 1.0 / FPS

## alpha bbox 量測的容差（畫布像素）。縮圖取整本來就有 1px 誤差，抓太緊會變成
## 「每次換圖都紅一次」的假陰性製造機。
const ANCHOR_TOLERANCE_PX := 1.5


func _audit_levels() -> bool:
	print("--- 關卡／無盡／貼圖錨點稽核 ---")
	var ok := true
	var lines := PackedStringArray()

	# 進來之前先把狀態定死，離開前還原（見檔頭 ⚠）
	var saved_sel: int = SpikeSave.selected_level
	var saved_unlocked: int = SpikeSave.unlocked_level
	var saved_endless: bool = SpikeSave.endless_mode
	var saved_extreme: bool = SpikeSave.extreme_mode

	if not _audit_level_table(lines):
		ok = false
	if not _audit_unlock_chain(lines):
		ok = false
	if not _audit_goal_sync(lines):
		ok = false
	if not _audit_difficulty_invariance(lines):
		ok = false
	if not _audit_clear_signal(lines):
		ok = false
	if not _audit_save_migration(lines):
		ok = false
	if not _audit_pameloe_variant(lines):
		ok = false
	if not _audit_art_anchors(lines):
		ok = false
	if not _audit_solo_foothold(lines):
		ok = false
	if not _audit_pickup_art(lines):
		ok = false
	if not _audit_explosive(lines):
		ok = false
	if not _audit_segments(lines):
		ok = false

	SpikeSave.unlocked_level = saved_unlocked
	SpikeSave.selected_level = saved_sel
	SpikeSave.endless_mode = saved_endless
	SpikeSave.extreme_mode = saved_extreme
	SpikeConfig.apply_level(SpikeSave.selected_level)

	for l in lines:
		print(l)
	if ok:
		print("  關卡表、解鎖鏈、終點同步、難度不變性（含白名單正向驗證）、登頂訊號、存檔遷移、"
			+ "Pameloe 立繪分佈、貼圖錨點、solo 落腳窗、物資貼圖尺寸、爆炸平台、特殊區段 — 十二項全通過")
	return ok


## ① 關卡表本身的常數關係。⚠ 這是「保命條款」型斷言（常青認知第 6 條）：三條陣列
##    長度不一致時，UI 讀名字、結算讀劇情、生成讀高度會各自在不同的 index 越界，
##    而行為稽核只會忠實地照著壞掉的表跑然後全綠。
func _audit_level_table(lines: PackedStringArray) -> bool:
	var ok := true
	if SpikeConfig.LEVEL_GOALS.size() != SpikeConfig.LEVEL_COUNT \
			or SpikeConfig.LEVEL_NAMES.size() != SpikeConfig.LEVEL_COUNT \
			or SpikeConfig.LEVEL_STORY_PLACEHOLDER.size() != SpikeConfig.LEVEL_COUNT:
		lines.append("  !! 關卡三張表長度對不上 LEVEL_COUNT（%d / 目標 %d、名稱 %d、劇情 %d）" % [
			SpikeConfig.LEVEL_COUNT, SpikeConfig.LEVEL_GOALS.size(),
			SpikeConfig.LEVEL_NAMES.size(), SpikeConfig.LEVEL_STORY_PLACEHOLDER.size()
		])
		ok = false
	for i in range(1, SpikeConfig.LEVEL_GOALS.size()):
		if SpikeConfig.LEVEL_GOALS[i] <= SpikeConfig.LEVEL_GOALS[i - 1]:
			lines.append("  !! 關卡目標高度不是遞增的（第 %d 關 %.0fm <= 第 %d 關 %.0fm）" % [
				i + 1, SpikeConfig.LEVEL_GOALS[i], i, SpikeConfig.LEVEL_GOALS[i - 1]
			])
			ok = false
	return ok


## ② 解鎖鏈：一開始只有關卡一、通關才往後開、已開過的不重複回報、最後一關到頂。
##    同時驗「沒解鎖的關選不動」——那是 UI 鎖頭以外的第二道門，UI 壞了它還要擋得住。
func _audit_unlock_chain(lines: PackedStringArray) -> bool:
	var ok := true
	SpikeSave.unlocked_level = 0
	SpikeSave.selected_level = 0

	if SpikeSave.is_level_unlocked(1) or SpikeSave.is_level_unlocked(2):
		lines.append("  !! 全新存檔就已經解鎖了關卡二／三")
		ok = false
	if SpikeSave.select_level(1):
		lines.append("  !! 沒解鎖的關卡竟然選得動（select_level(1) 回 true）")
		ok = false
	if SpikeSave.selected_level != 0:
		lines.append("  !! 被拒絕的 select_level 還是改動了 selected_level（=%d）" % SpikeSave.selected_level)
		ok = false

	if not SpikeSave.report_level_cleared(0) or SpikeSave.unlocked_level != 1:
		lines.append("  !! 通關關卡一之後沒有解鎖關卡二（unlocked=%d）" % SpikeSave.unlocked_level)
		ok = false
	# 再通關一次同一關：不該回報「有新解鎖」，也不該把進度往回推
	if SpikeSave.report_level_cleared(0) or SpikeSave.unlocked_level != 1:
		lines.append("  !! 重複通關關卡一被當成新解鎖（unlocked=%d）" % SpikeSave.unlocked_level)
		ok = false
	SpikeSave.report_level_cleared(1)
	if SpikeSave.report_level_cleared(2) or SpikeSave.unlocked_level != SpikeConfig.LEVEL_COUNT - 1:
		lines.append("  !! 通關最後一關之後 unlocked 越界或又往上加（=%d）" % SpikeSave.unlocked_level)
		ok = false
	return ok


## ③ 終點同步：selected_level 與 SpikeConfig.goal_meters 必須一起動。
##    ⚠ 這條抓的是「UI 說關卡三、井卻在 1000m 結束」那種不會報錯的錯——兩個狀態
##    分屬兩個 autoload，只要有人繞過 select_level 直接指派就會靜默分岔。
func _audit_goal_sync(lines: PackedStringArray) -> bool:
	var ok := true
	SpikeSave.unlocked_level = SpikeConfig.LEVEL_COUNT - 1
	for i in range(SpikeConfig.LEVEL_COUNT):
		if not SpikeSave.select_level(i):
			lines.append("  !! 已解鎖的關卡 %d 選不動" % (i + 1))
			ok = false
			continue
		if absf(SpikeConfig.goal_meters - SpikeConfig.LEVEL_GOALS[i]) > 0.01:
			lines.append("  !! 選了關卡 %d，goal_meters 卻是 %.0fm（應為 %.0fm）" % [
				i + 1, SpikeConfig.goal_meters, SpikeConfig.LEVEL_GOALS[i]
			])
			ok = false
	# 讀檔路徑也要同步（存檔裡的 selected_level 是另一條進入點）
	SpikeSave.select_level(2)
	SpikeSave.save()
	SpikeSave.load_save()
	if SpikeSave.selected_level != 2 or absf(SpikeConfig.goal_meters - SpikeConfig.LEVEL_GOALS[2]) > 0.01:
		lines.append("  !! 讀檔後關卡／終點沒同步（selected=%d、goal=%.0fm）" % [
			SpikeSave.selected_level, SpikeConfig.goal_meters
		])
		ok = false
	return ok


## ④ 難度不變性。08-10 二訂為**白名單制**（使用者推翻原本的全面禁止，理由是「不同關卡
##    之間應該還是要有些差距，不然會感覺是重複挑戰完全相同的東西」）：
##      • 登記在 `SpikeConfig.LEVEL_GATED` 的東西**允許**隨關卡變，而且下面會**正向驗**
##        它真的有差（門檻以下為 0、以上 > 0）——白名單不是免驗，是換一種驗法。
##      • 其餘所有軸仍然必須逐一相等。
##    ⚠ 這條會抓到「某人為了方便把某個分母換成 goal_meters」——那種改動在單一關卡下
##    測起來完全正常，只有跨關比較才看得出來。
##    ⚠⚠ 新增關卡差異時**這裡也要動**：登記進 LEVEL_GATED 之外，如果它會影響下面的取樣
##      值，還得把那一項從取樣陣列裡拿掉，否則這條會紅。刻意做成「要動兩個地方」——
##      白名單的價值就在於「加關卡差異」必須是一個顯式動作，不能順手做掉。
## ⚠⚠ spacing_at() **吃 rng**，所以每次取樣前都要重新 setup 同一顆 seed 把 rng 狀態
##    歸位；沒 setup 過的 WellGenerator 的 _rng 是 null，呼叫會噴 SCRIPT ERROR 然後
##    回傳 null ⇒ float(null) == 0.0 ⇒ 三關全都是 0.0 ⇒ **這條稽核會全綠**。
##    第一版就是這樣寫的，錯誤訊息印了 12 次照樣 PASS。下面的 `sane` 檢查就是為此存在。
func _audit_difficulty_invariance(lines: PackedStringArray) -> bool:
	const PROBE_SEED := 20260810
	var ok := true
	SpikeSave.unlocked_level = SpikeConfig.LEVEL_COUNT - 1
	var probe_heights := [200.0, 500.0, 800.0, 999.0]
	var baseline := {}
	for i in range(SpikeConfig.LEVEL_COUNT):
		SpikeSave.select_level(i)
		for h in probe_heights:
			var key := "%.0f" % h
			var gen := WellGenerator.new()
			gen.setup(0.0, PROBE_SEED)
			var sample := [
				gen.pameloe_chance_at(h),
				gen.monster_chance_at(h),
				gen.spacing_at(h),
				SpikeConfig.eff_projectile_interval_min(h),
				SpikeConfig.eff_steal_interval_min(h),
				SpikeConfig.eff_doom_interval_min(h),
				SpikeConfig.eff_shockwave_response(h),
			]
			# 保命條款：取樣值必須是正數。任何一項變成 0／null 都代表這條稽核本身
			# 失效了（見上方 ⚠⚠），而不是「三關剛好都一樣」。
			# ⚠ 唯一的合法例外：pameloe 機率在 PAMELOE_START_HEIGHT_M 以下**本來就是 0**
			#   （牠 500m 才登場）。這個例外要寫死條件，不能放寬成「允許 0」——
			#   放寬等於把這條保命條款關掉。
			for k in range(sample.size()):
				var may_be_zero: bool = k == 0 and h < SpikeConfig.PAMELOE_START_HEIGHT_M
				if sample[k] == null or (float(sample[k]) <= 0.0 and not may_be_zero):
					lines.append("  !! 難度取樣第 %d 項在 %sm 拿到 %s（稽核本身失效，不是通過）" % [
						k + 1, key, sample[k]
					])
					ok = false
			if i == 0:
				baseline[key] = sample
				continue
			for k in range(sample.size()):
				if absf(float(sample[k]) - float(baseline[key][k])) > 0.0001:
					lines.append(
						"  !! %sm 的難度數值隨關卡改變了（第 %d 項：關卡一 %.4f、關卡 %d %.4f）" % [
							key, k + 1, float(baseline[key][k]), i + 1, float(sample[k])
						]
					)
					ok = false

	# --- 白名單的**正向**驗證：登記在案的東西必須真的隨關卡有差 ---
	# ⚠ 沒有這一段的話，白名單就只是「不驗」的同義詞：把爆炸平台的機率手滑設成 0，
	#   上面那圈全等比較照樣全綠，而「關卡二跟關卡一長得一模一樣」正是使用者要避免的事。
	for feature in SpikeConfig.LEVEL_GATED:
		var entry: Dictionary = SpikeConfig.LEVEL_GATED[feature]
		var min_lv: int = int(entry["min_level"])
		var disp: String = String(entry["name"])
		if min_lv <= 0:
			lines.append("  !! 白名單項目「%s」的 min_level 是 %d，等於每一關都有，登記它沒有意義"
				% [disp, min_lv])
			ok = false
			continue
		if SpikeConfig.level_gate_ok(feature, min_lv - 1):
			lines.append("  !! 白名單項目「%s」在門檻以下的關卡就開了（min_level=%d）" % [disp, min_lv])
			ok = false
		if not SpikeConfig.level_gate_ok(feature, min_lv):
			lines.append("  !! 白名單項目「%s」在門檻關卡沒開（min_level=%d）" % [disp, min_lv])
			ok = false
	# 未登記的 key 必須一律回 false（拼錯字要壞在「東西沒出現」那一邊，見 level_gate_ok 的 ⚠）
	if SpikeConfig.level_gate_ok("no_such_feature_", SpikeConfig.LEVEL_COUNT):
		lines.append("  !! level_gate_ok 對沒登記的 key 回了 true（拼錯字會靜默開啟全部關卡）")
		ok = false
	return ok


## ⑤ 登頂訊號：有終點的模式抵達 goal 要 emit cleared 並停局；無盡模式在同樣的高度
##    **不能** emit、也不能停局。
##    ⚠ bot 爬不到 1000m，這條是唯一驗得到登頂路徑的地方（見檔頭）。
func _audit_clear_signal(lines: PackedStringArray) -> bool:
	var ok := true
	SpikeSave.unlocked_level = SpikeConfig.LEVEL_COUNT - 1
	SpikeSave.select_level(0)

	for endless in [false, true]:
		SpikeSave.endless_mode = endless
		var world := WellWorld.new()
		add_child(world)
		world.set_process(false)
		world.reset()
		world.running = true
		var got := {"v": false}
		world.cleared.connect(func() -> void: got["v"] = true)
		# 直接把玩家搬到目標高度之上（bot 跑不到，只能用這條路）
		world.player.pos.y = world.start_y \
			- (SpikeConfig.goal_meters + 5.0) * SpikeConfig.PIXELS_PER_METER
		world._check_end()
		if endless:
			if got["v"] or not world.running:
				lines.append("  !! 無盡模式抵達 %.0fm 卻結算了（cleared=%s、running=%s）" % [
					SpikeConfig.goal_meters, got["v"], world.running
				])
				ok = false
		else:
			if not got["v"] or world.running:
				lines.append("  !! 抵達 %.0fm 沒有登頂結算（cleared=%s、running=%s）" % [
					SpikeConfig.goal_meters, got["v"], world.running
				])
				ok = false
		world.queue_free()
		remove_child(world)
	SpikeSave.endless_mode = false

	# 目標「之下」不能誤觸發：差 1m 就結算的話等於整個終點往下挪了。
	var w2 := WellWorld.new()
	add_child(w2)
	w2.set_process(false)
	w2.reset()
	w2.running = true
	var early := {"v": false}
	w2.cleared.connect(func() -> void: early["v"] = true)
	w2.player.pos.y = w2.start_y \
		- (SpikeConfig.goal_meters - 1.0) * SpikeConfig.PIXELS_PER_METER
	w2._check_end()
	if early["v"]:
		lines.append("  !! 還差 1m 就提前登頂結算了")
		ok = false
	w2.queue_free()
	remove_child(w2)
	return ok


## ⑥ 存檔 v2 → v3 遷移：舊格式的單一 best_time_normal_s 要落進**關卡一**那一格，
##    而且不能把其他兩格弄髒。⚠ 走 _apply_save_dict（白名單回填的唯一入口），
##    不是自己塞欄位——測到的必須是玩家真的讀舊檔時會走的那條路。
func _audit_save_migration(lines: PackedStringArray) -> bool:
	var ok := true
	SpikeSave.clear_runtime()
	SpikeSave._apply_save_dict({
		"schema_version": 2,
		"coins": 123,
		"best_height_normal_m": 640.0,
		"best_time_normal_s": 271.5,
		"best_time_extreme_s": 355.0,
	})
	var n0 := SpikeSave.best_time_of_level(0, false)
	var e0 := SpikeSave.best_time_of_level(0, true)
	var n1 := SpikeSave.best_time_of_level(1, false)
	if absf(n0 - 271.5) > 0.01 or absf(e0 - 355.0) > 0.01:
		lines.append("  !! v2 存檔的登頂用時沒有遷進關卡一（一般 %.1f、極限 %.1f）" % [n0, e0])
		ok = false
	if n1 != SpikeSave.NO_TIME_RECORD:
		lines.append("  !! v2 遷移把關卡二那格也填上了（%.1f）" % n1)
		ok = false
	if SpikeSave.schema_version != SpikeSave.CURRENT_SCHEMA_VERSION:
		lines.append("  !! 遷移後 schema_version 沒有升到目前版本")
		ok = false

	# v3 往返：三格各存不同值，寫出去再讀回來要一格不差
	SpikeSave.clear_runtime()
	SpikeSave.unlocked_level = SpikeConfig.LEVEL_COUNT - 1
	for i in range(SpikeConfig.LEVEL_COUNT):
		SpikeSave.select_level(i)
		SpikeSave.record_clear_time(100.0 + float(i))
	SpikeSave.save()
	SpikeSave.load_save()
	for i in range(SpikeConfig.LEVEL_COUNT):
		if absf(SpikeSave.best_time_of_level(i, false) - (100.0 + float(i))) > 0.01:
			lines.append("  !! 每關時間存檔往返後對不上（關卡 %d = %.1f）" % [
				i + 1, SpikeSave.best_time_of_level(i, false)
			])
			ok = false
	return ok


## ⑦ Pameloe 兩張立繪的抽取：只能是 0/1，且稀有那張的比例要落在 PAMELOE_RARE_ART_CHANCE
##    附近。⚠ 範圍刻意放寬（±6 個百分點）：這是隨機抽樣，抓太緊會變成偶發假陰性，
##    而偶發假陰性比沒測還糟（常青認知第 4 條）。這條要抓的是「常數沒接上」「骰在繪製
##    時而不是生成時」這類整條壞掉的情況，不是統計精度。
func _audit_pameloe_variant(lines: PackedStringArray) -> bool:
	var ok := true
	var gen := WellGenerator.new()
	gen.setup(0.0, 20260810)
	var plat := WellPlatform.new()
	plat.pos = Vector2(
		(SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5, 0.0
	)
	plat.size = SpikeConfig.PLATFORM_SIZE

	var total := 0
	var rare := 0
	for _i in range(4000):
		var m = gen._make_pameloe(plat)
		if m == null:
			continue
		total += 1
		if m.art_variant != 0 and m.art_variant != 1:
			lines.append("  !! Pameloe 抽到不存在的立繪 index（%d）" % m.art_variant)
			ok = false
			break
		if m.art_variant == 1:
			rare += 1
	if total < 100:
		lines.append("  !! Pameloe 抽樣數太少（%d），這條稽核等於沒測" % total)
		ok = false
		return ok
	var ratio := float(rare) / float(total)
	var expect: float = SpikeConfig.PAMELOE_RARE_ART_CHANCE
	if absf(ratio - expect) > 0.06:
		lines.append("  !! Pameloe 稀有立繪比例 %.1f%%，離設定的 %.1f%% 太遠（抽樣 %d）" % [
			ratio * 100.0, expect * 100.0, total
		])
		ok = false
	else:
		lines.append("  Pameloe 立繪 : 稀有 %.1f%%（設定 %.1f%%，抽樣 %d）" % [
			ratio * 100.0, expect * 100.0, total
		])
	return ok


## ⑧ 貼圖錨點常數 vs 貼圖檔實際內容。**直接掃 PNG 的 alpha 算出腳底在哪**，不是
##    拿常數跟常數比——後者驗不出任何東西（常青認知第 6 條）。
##    ⚠ 這條抓的是「換了一張圖但忘了重量 FEET_FRAC」：那種錯在遊戲裡看起來只是
##    「腳陷進平台一點點」，沒有人會覺得那是 bug，但它會一路留到正式版。
func _audit_art_anchors(lines: PackedStringArray) -> bool:
	var ok := true
	var checks := [
		{
			"path": WellWorld.MONSTER_PATROL_TEX_PATH,
			"frac": SpikeConfig.MONSTER_ART_FEET_FRAC,
			"name": "怪物 chattini",
		},
		{
			"path": WellWorld.WORMHOLE_TEX_PATH,
			"frac": SpikeConfig.WORMHOLE_ART_FEET_FRAC,
			"name": "蟲洞 the_sheep",
		},
	]
	for c in checks:
		var measured := _measure_alpha_bottom_frac(String(c["path"]))
		if measured < 0.0:
			lines.append("  !! %s 的貼圖讀不到，無法驗錨點（%s）" % [c["name"], c["path"]])
			ok = false
			continue
		var canvas_h := _texture_height(String(c["path"]))
		var diff_px: float = absf(measured - float(c["frac"])) * canvas_h
		if diff_px > ANCHOR_TOLERANCE_PX:
			lines.append("  !! %s 的 FEET_FRAC 對不上貼圖實際內容（常數 %.4f、實測 %.4f，差 %.1f px）" % [
				c["name"], float(c["frac"]), measured, diff_px
			])
			ok = false

	# Pameloe 兩張立繪：必須都在、且畫布尺寸一致（不一致＝切換立繪時位置會跳）
	var sizes := []
	for path in WellWorld.PAMELOE_TEX_PATHS:
		if not ResourceLoader.exists(path):
			lines.append("  !! Pameloe 立繪缺檔：%s" % path)
			ok = false
			continue
		var tex: Texture2D = load(path)
		sizes.append(tex.get_size())
	if sizes.size() == 2 and sizes[0] != sizes[1]:
		lines.append("  !! Pameloe 兩張立繪畫布尺寸不一致（%s vs %s）" % [sizes[0], sizes[1]])
		ok = false
	if sizes.size() == 2 and sizes[0] != SpikeConfig.PAMELOE_ART_SIZE:
		lines.append("  !! Pameloe 立繪尺寸 %s 對不上 PAMELOE_ART_SIZE %s" % [
			sizes[0], SpikeConfig.PAMELOE_ART_SIZE
		])
		ok = false
	return ok


## 掃出「最下面一列還有不透明像素」的位置 ÷ 畫布高。讀不到回 -1。
## ⚠ 從底往上掃、第一列有 alpha 就停：整張掃是 88×115 = 一萬次取樣，沒必要。
func _measure_alpha_bottom_frac(path: String) -> float:
	if not ResourceLoader.exists(path):
		return -1.0
	var tex: Texture2D = load(path)
	if tex == null:
		return -1.0
	var img: Image = tex.get_image()
	if img == null:
		return -1.0
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h - 1, -1, -1):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.01:
				return float(y + 1) / float(h)
	return -1.0


func _texture_height(path: String) -> float:
	if not ResourceLoader.exists(path):
		return 1.0
	var tex: Texture2D = load(path)
	return maxf(1.0, tex.get_size().y)


## ⑫ 特殊區段（08-10 新增，SECTION 4e）。
##    ⓐ **表本身的合法性**：force_kind 翻得出來、不是「踩了就沒」的板、band_extra_min > 0。
##      ⚠ 拼錯 force_kind 的失效方式是「主題區看起來跟一般路段一模一樣」——沒有人會注意到，
##        所以這條非驗不可（同常青認知第 6 條：保命條款要驗常數關係）。
##    ⓑ **生成規則**：真的會出現、長度對得上、彼此間隔夠、不早於 START_HEIGHT_M。
##    ⓒ **豁免的對價**：區段內每個高度區間都要有備援跳板。`_pick_kind` 在區段內直接
##      跳過所有死局防護，前提就是這顆備援板；它擺不下（`_pick_x_apart` 放棄）的話，
##      690m 以上的主題區就是一連串「唯一的板還在跑」的運氣牆。
func _audit_segments(lines: PackedStringArray) -> bool:
	var ok := true

	# ⓐ 表的合法性
	var probe := WellGenerator.new()
	probe.setup(0.0, 1)
	for row in SpikeConfig.SEGMENT_TABLE:
		var sid: String = String(row.get("id", ""))
		var fk: String = String(row.get("force_kind", ""))
		if fk != "":
			var k: int = probe._kind_from_name(fk)
			if k < 0:
				lines.append("  !! 區段「%s」的 force_kind「%s」翻不出平台種類（拼錯字？）" % [sid, fk])
				ok = false
			elif k == WellPlatform.Kind.FRAGILE or k == WellPlatform.Kind.EXPLOSIVE:
				lines.append("  !! 區段「%s」整段只出「%s」——那是踩了就沒的板，整段沒有落點" % [sid, fk])
				ok = false
			elif float(row.get("band_extra_min", 0.0)) <= 0.0:
				lines.append(
					"  !! 區段「%s」覆寫了平台種類卻沒有 band_extra_min" % sid
					+ "（_pick_kind 在區段內跳過死局防護，備援跳板是它的對價）"
				)
				ok = false

	# ⓑⓒ 實際生成。⚠ 用多顆 seed：單顆 seed 抽不抽得到主題區是運氣，抽不到就等於沒測。
	var total := 0
	var bad_len := 0
	var bad_gap := 0
	var bad_early := 0
	var lonely_bands := 0
	var checked_bands := 0
	var wrong_kind := 0
	for seed_val in [20260810, 777, 13579]:
		var gen := WellGenerator.new()
		gen.setup(0.0, seed_val)
		gen.ensure_generated_to(-1000.0 * SpikeConfig.PIXELS_PER_METER)
		var prev_end := -INF
		for seg in gen.segments:
			total += 1
			var s: float = float(seg["start_h"])
			var e: float = float(seg["end_h"])
			if absf((e - s) - SpikeConfig.SEGMENT_LENGTH_M) > 0.01:
				bad_len += 1
			if s < SpikeConfig.SEGMENT_START_HEIGHT_M - 0.01:
				bad_early += 1
			if prev_end > -INF and s - prev_end < SpikeConfig.SEGMENT_MIN_GAP_M - 0.01:
				bad_gap += 1
			prev_end = e

			# 這一段裡每個「高度區間」有哪些板。
			# ⚠⚠ 用平台自己的 `segment_id` 挑，**不是拿高度去反推區段範圍**：生成鏈用
			#   上一塊的高度決定這一塊的性質，兩者差一個高度區間，靠高度反推會在每一段的
			#   頭尾各誤判一次（見 WellPlatform.segment_id 的 ⚠⚠）。第一版就是這樣假紅的。
			var mine: Array = []
			for p in gen.platforms:
				if p.is_goal or p.segment_id != String(seg["id"]):
					continue
				var ph: float = SpikeConfig.meters_from_y(0.0, p.center().y)
				if ph < s - SpikeConfig.SEGMENT_LENGTH_M or ph > e + SpikeConfig.SEGMENT_LENGTH_M:
					continue   # 同 id 的別段（一座井可能抽到同一種主題兩次）
				mine.append(p)
			# ⚠ 分群用「y 排序 ＋ 相鄰差 <= BAND_EXTRA_Y_DROP」，不要用固定格線切
			#   （`int(y / 100)` 那種）：band 間距是 138~188px 的變動值，固定格線會把相鄰
			#   兩個 band 併成一群、或把同一群切開，兩個檢查都會跟著錯。第一版踩過。
			mine.sort_custom(func(a, b): return a.center().y < b.center().y)
			var want_name: String = ""
			for row in SpikeConfig.SEGMENT_TABLE:
				if String(row["id"]) == String(seg["id"]):
					want_name = String(row.get("force_kind", ""))
			var want_kind: int = probe._kind_from_name(want_name) if want_name != "" else -1

			var i := 0
			while i < mine.size():
				var j := i + 1
				while j < mine.size() and absf(mine[j].center().y - mine[i].center().y) \
						<= SpikeConfig.BAND_EXTRA_Y_DROP + 1.0:
					j += 1
				checked_bands += 1
				if j - i < 2:
					lonely_bands += 1
				# force_kind 真的有被套用嗎。⚠ 這條不可省：「主題區存在」跟「主題區真的
				#   換了地形」是兩件事，只驗前者的話 force_kind 整條沒接上也會全綠——而
				#   失效的表現是「主題區看起來跟一般路段一樣」，沒有人會發現。
				# ⚠ 每群最高的那塊才是主鏈（備援跳板只往下偏移，恆為 STATIC），所以是 mine[i]。
				if want_kind >= 0 and mine[i].kind != want_kind:
					wrong_kind += 1
				i = j

	if total == 0:
		lines.append("  !! 三顆 seed 一段主題區都沒生出來，這條稽核等於沒測")
		ok = false
	if bad_len > 0:
		lines.append("  !! %d 段主題區的長度不是 %.0fm" % [bad_len, SpikeConfig.SEGMENT_LENGTH_M])
		ok = false
	if bad_early > 0:
		lines.append("  !! %d 段主題區出現在 %.0fm 以下" % [bad_early, SpikeConfig.SEGMENT_START_HEIGHT_M])
		ok = false
	if bad_gap > 0:
		lines.append("  !! %d 段主題區彼此間隔不足 %.0fm" % [bad_gap, SpikeConfig.SEGMENT_MIN_GAP_M])
		ok = false
	if lonely_bands > 0:
		lines.append(
			"  !! 主題區內有 %d/%d 個高度區間只有一塊板" % [lonely_bands, checked_bands]
			+ "（區段跳過了死局防護，備援跳板是它的對價 — 沒備援＝運氣牆）"
		)
		ok = false
	if wrong_kind > 0:
		lines.append("  !! 主題區內有 %d 塊主鏈平台不是 force_kind 指定的種類（覆寫沒生效？）"
			% wrong_kind)
		ok = false
	if ok:
		lines.append(
			"  特殊區段 : 3 顆 seed 共 %d 段，長度／間隔／起始高度都對，" % total
			+ "%d 個區間全有備援板，主鏈種類全被覆寫" % checked_bands
		)
	return ok


## ⑪ 爆炸平台（08-10 新增）。三組互相獨立的檢查：
##    ⓐ **保命條款（常數關係）**：爆炸半徑必須小於「玩家正常跳到上一塊板之後離爆炸中心
##      的距離」。不成立的話按規矩跳走的玩家照樣被炸 ⇒ 它就退化成更兇的碎裂平台，而且
##      是行為稽核驗不出來的那種退化（bot 爬不到那個高度，見常青認知第 6 條）。
##    ⓑ **關卡門檻**：關卡一整座井一塊都不能有；門檻關卡必須真的生得出來。
##      ⚠ 後者跟前者一樣重要——「一塊都沒生出來」跟「規則正確」在只驗前者時長得一模一樣。
##    ⓒ **死局防護**：不得與另一塊「踩了就會沒」的板相鄰（連兩次賭時機，solo 區間沒有備援）。
func _audit_explosive(lines: PackedStringArray) -> bool:
	var ok := true

	# ⓐ 常數關係。玩家跳到上一塊板之後，離爆炸中心至少有「最小中心距 − 玩家半高」那麼遠。
	# ⚠ 用 SPACING_MIN_AT_TOP 當最小中心距：爆炸板從關卡二才有，而關卡二的地形軸在
	#   DIFFICULTY_RAMP_HEIGHT_M 之後已經封頂，spacing 恆在 MIN_AT_TOP~MAX_AT_TOP 之間。
	var safe_dist: float = SpikeConfig.SPACING_MIN_AT_TOP - SpikeConfig.PLAYER_SIZE.y * 0.5
	if SpikeConfig.EXPLOSIVE_RADIUS >= safe_dist:
		lines.append(
			"  !! 爆炸半徑 %.1f >= 安全距離 %.1f" % [SpikeConfig.EXPLOSIVE_RADIUS, safe_dist]
			+ "（最小間距 %.0f − 玩家半高 %.0f）— 正常跳走也會被炸到" % [
				SpikeConfig.SPACING_MIN_AT_TOP, SpikeConfig.PLAYER_SIZE.y * 0.5
			]
		)
		ok = false
	# 引信必須明顯長於爆炸窗，否則「點燃 → 炸開」讀起來像同一件事、沒有反應時間
	if SpikeConfig.EXPLOSIVE_FUSE_TIME <= SpikeConfig.EXPLOSIVE_BLAST_TIME:
		lines.append("  !! 引信 %.2fs 不長於爆炸窗 %.2fs，等於沒有預告" % [
			SpikeConfig.EXPLOSIVE_FUSE_TIME, SpikeConfig.EXPLOSIVE_BLAST_TIME
		])
		ok = false

	# ⓑⓒ 生成規則：關卡一 vs 門檻關卡各生一座井來比。
	# ⚠ 關卡編號走 setup() 的參數，不碰 SpikeSave——稽核之間會互相污染（常青認知第 4 條）。
	var gate_lv: int = int(SpikeConfig.LEVEL_GATED["explosive_platform"]["min_level"])
	var counts := {}
	var adjacent_bad := 0
	for lv in [0, gate_lv]:
		var gen := WellGenerator.new()
		gen.setup(0.0, 20260810, 0.0, lv)
		gen.ensure_generated_to(-1000.0 * SpikeConfig.PIXELS_PER_METER)
		var n := 0
		var prev_kind := -1
		for p in gen.platforms:
			if p.is_goal:
				continue
			if p.kind == WellPlatform.Kind.EXPLOSIVE:
				n += 1
			# 相鄰檢查只看主鏈：platforms 的順序就是生成順序，額外跳板恆為 STATIC
			var perishable: bool = p.kind == WellPlatform.Kind.EXPLOSIVE \
				or p.kind == WellPlatform.Kind.FRAGILE
			var prev_perishable: bool = prev_kind == WellPlatform.Kind.EXPLOSIVE \
				or prev_kind == WellPlatform.Kind.FRAGILE
			if perishable and prev_perishable:
				adjacent_bad += 1
			prev_kind = p.kind
		counts[lv] = n

	if int(counts[0]) != 0:
		lines.append("  !! 關卡一生出了 %d 塊爆炸平台（門檻是關卡 %d）" % [int(counts[0]), gate_lv + 1])
		ok = false
	if int(counts[gate_lv]) <= 0:
		lines.append("  !! 關卡 %d 一塊爆炸平台都沒生出來 — 機率或門檻沒接上" % (gate_lv + 1))
		ok = false
	if adjacent_bad > 0:
		lines.append("  !! 有 %d 處「踩了就會沒」的板連續相鄰（碎裂／爆炸）" % adjacent_bad)
		ok = false
	if ok:
		lines.append("  爆炸平台 : 關卡一 0 塊 / 關卡 %d %d 塊，半徑 %.0f（安全距 %.0f），無連續易失板" % [
			gate_lv + 1, int(counts[gate_lv]), SpikeConfig.EXPLOSIVE_RADIUS, safe_dist
		])
	return ok


## ⑩ 物資貼圖的「看得見的大小」對不對（08-10 接 coin／fuel 後補）。
##    ⚠⚠ 這條驗的**不是畫布尺寸**而是 alpha 內容尺寸——coin/fuel 的來源圖四周有大片
##      透明留白，畫布 60 裡只有 52 有東西。拿畫布去比對判定框會全綠，但玩家實際看到的
##      東西整整小一圈，而且是「看起來對不上判定」這種沒人會歸類成 bug 的錯。
##    ⚠ coin 兩軸都驗（來源比例剛好對得上）；fuel 只驗**寬**——它的來源比例跟判定框
##      比例天生對不上，鎖寬是刻意的取捨（見 SpikeConfig.FUEL_ART_SIZE 的 ⚠）。高度改驗
##      「不得超過判定 ×2」：超過就代表視覺比判定寬，誤差方向會倒向「看起來碰到卻沒撿到」。
func _audit_pickup_art(lines: PackedStringArray) -> bool:
	var ok := true
	var checks := [
		{
			"path": WellWorld.COIN_TEX_PATH, "name": "金幣 coin",
			"art": SpikeConfig.COIN_ART_SIZE, "hit": SpikeConfig.PICKUP_SIZE,
			"check_h": true,
		},
		{
			"path": WellWorld.FUEL_TEX_PATH, "name": "燃料 fuel",
			"art": SpikeConfig.FUEL_ART_SIZE, "hit": SpikeConfig.FUEL_PICKUP_SIZE,
			"check_h": false,
		},
	]
	for c in checks:
		var path := String(c["path"])
		var content := _measure_alpha_content_size(path)
		if content.x < 0.0:
			lines.append("  !! %s 的貼圖讀不到，無法驗尺寸（%s）" % [c["name"], path])
			ok = false
			continue
		var canvas: Vector2 = _texture_size(path)
		var art: Vector2 = c["art"]
		# 08-10 三訂：art 不再等於原始畫布——PICKUP_ART_SCALE 把畫面尺寸整體縮小
		# （使用者拍板「COIN／FUEL 大小 -50%」），所以比對的是「畫布 × 縮放」不是「畫布」。
		var expect_art: Vector2 = canvas * SpikeConfig.PICKUP_ART_SCALE
		if absf(art.x - expect_art.x) > ANCHOR_TOLERANCE_PX \
				or absf(art.y - expect_art.y) > ANCHOR_TOLERANCE_PX:
			lines.append(
				"  !! %s 的畫布 %s ×PICKUP_ART_SCALE(%.2f) = %s 對不上 ART_SIZE %s（換圖或改縮放忘了同步？）"
				% [c["name"], canvas, SpikeConfig.PICKUP_ART_SCALE, expect_art, art]
			)
			ok = false
			continue
		# 畫布縮放到 art 尺寸後，alpha 內容實際會佔多少 px
		var shown := Vector2(
			content.x / canvas.x * art.x, content.y / canvas.y * art.y
		)
		var want: Vector2 = Vector2(c["hit"]) * 2.0
		if absf(shown.x - want.x) > ANCHOR_TOLERANCE_PX:
			lines.append("  !! %s 的視覺寬 %.1f 對不上判定 ×2 = %.1f" % [
				c["name"], shown.x, want.x
			])
			ok = false
		if bool(c["check_h"]) and absf(shown.y - want.y) > ANCHOR_TOLERANCE_PX:
			lines.append("  !! %s 的視覺高 %.1f 對不上判定 ×2 = %.1f" % [
				c["name"], shown.y, want.y
			])
			ok = false
		elif not bool(c["check_h"]) and shown.y > want.y + ANCHOR_TOLERANCE_PX:
			lines.append(
				"  !! %s 的視覺高 %.1f 超過判定 ×2 = %.1f" % [c["name"], shown.y, want.y]
				+ "（誤差倒向「看起來碰到了卻沒撿到」，撿取物不該往這邊倒）"
			)
			ok = false
		lines.append("  %s 視覺 : %.0f×%.0f px（判定 ×2 = %.0f×%.0f）" % [
			c["name"], shown.x, shown.y, want.x, want.y
		])
	return ok


## 貼圖裡「真的有東西」的區域尺寸（畫布像素）。讀不到回 (-1,-1)。
## ⚠ 整張掃：這兩張只有 60~78 見方，一次稽核幾千次取樣，不值得為此寫四向早停。
func _measure_alpha_content_size(path: String) -> Vector2:
	if not ResourceLoader.exists(path):
		return Vector2(-1.0, -1.0)
	var tex: Texture2D = load(path)
	if tex == null:
		return Vector2(-1.0, -1.0)
	var img: Image = tex.get_image()
	if img == null:
		return Vector2(-1.0, -1.0)
	if img.is_compressed():
		img.decompress()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a <= 0.04:
				continue
			lo.x = minf(lo.x, float(x))
			lo.y = minf(lo.y, float(y))
			hi.x = maxf(hi.x, float(x))
			hi.y = maxf(hi.y, float(y))
	if hi.x < lo.x:
		return Vector2(-1.0, -1.0)
	return hi - lo + Vector2.ONE


func _texture_size(path: String) -> Vector2:
	if not ResourceLoader.exists(path):
		return Vector2.ZERO
	var tex: Texture2D = load(path)
	return tex.get_size()


## ⑨ solo 區間的落腳窗（保命條款型，08-10 真人試玩回報後補）。
##    BAND_SOLO_HEIGHT_M 以上每個高度區間只剩主鏈一塊板，所以那塊板上掛了怪物時，
##    平台上**必須仍存在「玩家站得住、又碰不到怪物」的位置**——否則唯一的路被即死物
##    封死，只能靠 jetpack／鞭子繞過去（08-10 回報的原始症狀）。
##
##    ⚠⚠ 這條驗的是**幾何關係**不是行為，而且是唯一驗得到這件事的地方：bot 跑局爬不到
##      690m，行為稽核在那個高度以上一律測不到。三顆常數（PLATFORM_WIDTH_MULT_SOLO、
##      MONSTER_PATROL_RANGE_SOLO、MONSTER_SIZE.x）任何一顆被調動都會直接反映在窗寬上。
##    ⚠ 「站得住」的定義取自真實落地判定（well_world._check_landing:647）：玩家與平台
##      AABB 有水平重疊即可落地，所以中心最遠可以到 平台半寬 + PLAYER_SIZE.x/2。這裡
##      刻意只採一半（PLAYER_SIZE.x * 0.25，＝腳有一半踩在板上），把「邊緣接觸」那種
##      0 重疊的極限值排除在外——那不是玩家真的站得穩的位置。
##    ⚠ 同時反向驗低處**沒有**被加寬：solo 加寬是局部處方，套到全域等於整條難度曲線下修。
##    ⚠ 也驗「solo 的會動平台不掛怪物」——那一條走的是生成路徑，只有真的生一段井才驗得到。
func _audit_solo_foothold(lines: PackedStringArray) -> bool:
	var ok := true
	var gen := WellGenerator.new()
	gen.setup(0.0, 20260810)

	var solo_h: float = SpikeConfig.BAND_SOLO_HEIGHT_M + 100.0
	var low_h := 100.0

	# --- 低處不得被加寬 ---
	var low_size: Vector2 = gen._size_for_kind(WellPlatform.Kind.STATIC, low_h)
	if not is_equal_approx(low_size.x, SpikeConfig.PLATFORM_SIZE.x):
		lines.append("  !! solo 加寬外洩到低處（%.0fm 的平台寬 %.1f，應為 %.1f）" % [
			low_h, low_size.x, SpikeConfig.PLATFORM_SIZE.x
		])
		ok = false

	# --- solo 區間的實際幾何 ---
	var solo_size: Vector2 = gen._size_for_kind(WellPlatform.Kind.STATIC, solo_h)
	var plat := WellPlatform.new()
	plat.size = solo_size
	plat.pos = Vector2((SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5, 0.0)
	var m := gen._make_monster(plat, solo_h)

	# 玩家中心最遠（腳仍有一半踩在板上）／最近（AABB 剛好不碰到怪物）
	var reach: float = solo_size.x * 0.5 + SpikeConfig.PLAYER_SIZE.x * 0.25
	var clear: float = m.local_max \
		+ (SpikeConfig.MONSTER_SIZE.x + SpikeConfig.PLAYER_SIZE.x) * 0.5
	var window := reach - clear
	if window < SpikeConfig.SOLO_FOOTHOLD_MIN:
		lines.append(
			"  !! solo 區間沒有安全落腳點：窗寬 %.1fpx < 下限 %.1f"
			% [window, SpikeConfig.SOLO_FOOTHOLD_MIN]
			+ "（板寬 %.1f、巡邏 ±%.1f、怪物寬 %.1f）— 唯一的路被即死物封死"
			% [solo_size.x, m.local_max, SpikeConfig.MONSTER_SIZE.x]
		)
		ok = false
	else:
		lines.append("  solo 落腳窗 : 單側 %.1fpx（下限 %.1f，板寬 %.1f、巡邏 ±%.1f）" % [
			window, SpikeConfig.SOLO_FOOTHOLD_MIN, solo_size.x, m.local_max
		])

	# --- solo 的會動平台不得掛怪物（走真實生成路徑）---
	# ⚠ 跑多顆 seed 累加：單一 seed 在 solo 區間只生得出個位數怪物（那裡本來就密度低），
	#   樣本一薄，這條就從「驗規則」退化成「碰運氣」——沒抓到不代表規則成立。
	var solo_mobile_hosts := 0
	var solo_monsters := 0
	for seed_val in [98765, 20260810, 424242]:
		var gen2 := WellGenerator.new()
		gen2.setup(0.0, seed_val)
		gen2.ensure_generated_to(-(solo_h + 200.0) * SpikeConfig.PIXELS_PER_METER)
		for mon in gen2.monsters:
			if mon.kind != WellMonster.Kind.PATROL or mon.host == null:
				continue
			var host_h: float = SpikeConfig.meters_from_y(0.0, mon.host.center().y)
			if host_h < SpikeConfig.BAND_SOLO_HEIGHT_M:
				continue
			solo_monsters += 1
			if gen2._is_mobile(mon.host.kind):
				solo_mobile_hosts += 1
	if solo_mobile_hosts > 0:
		lines.append("  !! solo 區間有 %d 隻怪物長在會動的平台上（應為 0，取樣 %d 隻）" % [
			solo_mobile_hosts, solo_monsters
		])
		ok = false
	elif solo_monsters < 8:
		lines.append("  !! solo 區間只取樣到 %d 隻怪物，樣本太薄，這條等於沒測" % solo_monsters)
		ok = false
	else:
		lines.append("  solo 怪物宿主 : %d 隻全在不會動的平台上（3 顆 seed）" % solo_monsters)

	return ok
