class_name WellGenerator
extends RefCounted
## 爬井關卡生成器。純資料 + 純邏輯，不繪製、不接輸入。
## 逐塊往上生成平台／怪物／物資，保證垂直可達性與基本死局防護。
##
## 兩條貫穿全檔的原則：
##   ① 密度隨高度單調遞減 —— 垂直靠 spacing_at()，水平靠 band_extra_expect_at()，
##      到 BAND_SOLO_HEIGHT_M 之後每個高度區間只剩主鏈那一塊。
##   ② 任何兩塊平台的「運動包絡線」不得相交 —— 水平看 span_x()，垂直看 up/down_extent()。
##      判定只認包絡線不認當下位置，所以左右／上下／繞圈的板都不會掃進鄰居身上。

var platforms: Array = []   # WellPlatform
var monsters: Array = []    # WellMonster
var pickups: Array = []     # WellPickup
var wormholes: Array = []   # WellWormhole
## 這座井生過的主題區紀錄（SECTION 4e）：每筆 {id, start_h, end_h}，公尺。
## ⚠ 只增不刪，**不隨 prune 回收**：它是「這座井長什麼樣」的紀錄，不是場上實體。
##   稽核靠它驗區段規則（否則只能從平台種類反猜區段邊界，猜錯就是假紅燈）。
var segments: Array = []
var start_y: float = 0.0
var goal_y: float = 0.0
var goal_spawned: bool = false

var _rng: RandomNumberGenerator
var _last_platform: WellPlatform

## 還沒配到出口平台的蟲洞（出口在上方 40m，生成當下那一段通常還沒生出來）
var _pending_wormholes: Array = []
## 上一個蟲洞的高度（m），用來拉開彼此間隔。-INF = 這座井還沒有蟲洞
var _last_wormhole_h: float = -INF

## 近期落點的指數移動平均（x）。防止隨機遊走在井的某一側盤旋，見 SpikeConfig 的
## X_BALANCE_* 註解。這是「觀測值」不是「目標值」——偏離井心超過死區才反向施壓。
var _x_ema: float = 0.0

## 墓碑目標高度（世界 y）。NAN = 這一局不放墓碑（沒有歷史紀錄，或紀錄已經貼到終點）。
## ⚠ 由 setup() 從外面灌進來，生成器**不讀 SpikeSave**（見 setup() 的 ⚠⚠）。
var _tomb_y: float = NAN
var _tomb_placed: bool = false

## 這一局的關卡編號（0-based）。⚠ 同上：由 setup() 灌入，不去問 SpikeSave。
## 只拿來問 SpikeConfig.level_gate_ok()——「第幾關才有什麼」的答案住那張表，不住這裡。
var _level_idx: int = 0

## --- 特殊區段（08-10，SECTION 4e）---
## 目前這一段主題區在 SEGMENT_TABLE 的 index；-1 = 現在不在任何主題區裡。
## ⚠ 主題區是**覆寫層**：它不改寫 monster_chance_at()／pickup_chance_at() 這些純函式，
##   而是在呼叫端乘倍率。純函式保持純是刻意的——難度不變性稽核直接對那幾個函式取樣，
##   把區段狀態塞進去會讓那條稽核的結果取決於「這顆 seed 剛好有沒有抽到主題區」。
var _seg_index: int = -1
var _seg_end_h: float = -INF     # 目前這段主題區結束的高度（m）
var _last_seg_end_h: float = -INF  # 上一段結束的高度，用來拉開彼此間隔


## best_h_m：歷史最高抵達高度（m），墓碑就放在這個高度附近那塊平台上。
## level_idx：這一局的關卡編號（0-based）。決定哪些「關卡限定」的東西生得出來，
##            實際門檻表在 SpikeConfig.LEVEL_GATED，這裡只負責把當局狀態帶進來。
## 兩者都給預設值，是為了讓稽核／測試沿用舊的兩參數呼叫（0 = 不放墓碑、關卡一）。
## ⚠⚠ 這兩顆都是「外面灌進來」而不是生成器自己去問 SpikeSave——生成器**不讀存檔**。
##   理由是稽核：讀存檔的話每條稽核都得先把全域存檔擺成自己要的樣子，而稽核之間會互相
##   污染（常青認知第 4 條），偶發假陰性比沒測還糟。
func setup(
	start_y_: float, seed_val: int, best_h_m: float = 0.0, level_idx: int = 0
) -> void:
	_level_idx = level_idx
	start_y = start_y_
	goal_y = SpikeConfig.goal_y(start_y_)
	goal_spawned = false
	platforms.clear()
	monsters.clear()
	pickups.clear()
	wormholes.clear()
	_pending_wormholes.clear()
	_last_wormhole_h = -INF
	segments.clear()
	_seg_index = -1
	_seg_end_h = -INF
	_last_seg_end_h = -INF
	_x_ema = (SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5

	# 沒紀錄不放；紀錄已經貼到終點也不放——墓碑立在終點線旁邊沒有任何意義
	_tomb_placed = false
	var tomb_limit: float = SpikeConfig.goal_meters - SpikeConfig.TOMB_END_MARGIN_M
	if best_h_m > 0.0 and best_h_m < tomb_limit:
		_tomb_y = start_y_ - best_h_m * SpikeConfig.PIXELS_PER_METER
	else:
		_tomb_y = NAN

	_rng = RandomNumberGenerator.new()
	if seed_val == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_val

	# 起跳平台：STATIC，位於 start_y_ 正下方（上緣貼著 start_y_），x 置中，
	# 寬度是一般平台的數倍，確保玩家一開始不會掉下去。
	var first := WellPlatform.new()
	first.kind = WellPlatform.Kind.STATIC
	first.size = Vector2(
		SpikeConfig.PLATFORM_SIZE.x * SpikeConfig.START_PLATFORM_WIDTH_MULT,
		SpikeConfig.PLATFORM_SIZE.y
	)
	first.pos = Vector2(
		(SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5,
		start_y_ + first.size.y * 0.5
	)
	platforms.append(first)
	_last_platform = first


## ⚠ 無盡加壓：不能靠 goal_spawned 擋這個迴圈——放進去等於過了終點高度就永久停生，
##   井會憑空斷在半空。goal_spawned 只管「終點那塊全寬平台只擺一次」（見下面
##   _generate_next 的 goal_y 判斷本身自帶 and not goal_spawned），跟井要不要繼續往上
##   長是兩件事。
func ensure_generated_to(top_y: float) -> void:
	while _last_platform.center().y > top_y:
		_generate_next()
	_force_resolve_pending_wormholes()


## 蟲洞出口必須在生成當下就補到位，否則整個功能是死的。
##
## v9 的時序 bug（本次修）：出口在蟲洞上方 40m（2000px），但串流生成只領先相機
## VIEW_H（720px），而 prune_below(cam_y + VIEW_H) 會在相機爬過蟲洞約 754px 時就把
## 它回收掉。出口要等相機到「蟲洞上方 1280px」才綁得到——754 先到，所以蟲洞在綁定
## 成功之前就 alive = false 並被踢出佇列，`ready_to_use()` 永遠是 false，
## 從頭到尾沒被 _draw() 畫出來過，也踩不到。**不是機率太低，是機率為零。**
##
## （smoke.gd 的生成器稽核測不到這件事：它一口氣 ensure_generated_to(終點)，
##   既沒有 prune 也沒有串流上限，蟲洞當然全部綁得到出口。）
##
## 修法：只要還有待綁定的蟲洞，就地把生成鏈往上推到出口解析完成為止。
## 蟲洞彼此至少隔 WORMHOLE_MIN_SPACING_M（120m）> 補生的 40m，所以這段不會再冒出
## 新蟲洞、不會連鎖；WORMHOLE_RESOLVE_MAX_STEPS 是保險絲。
func _force_resolve_pending_wormholes() -> void:
	# ⚠ 無盡加壓：這裡本來也擋 goal_spawned，井變無限長之後終點高度以上的蟲洞會被這道
	# 守衛擋住，永遠補不到出口——重演 v9 那個「蟲洞是死的卻全綠燈」的舊坑（見
	# ../CLAUDE.md 常青認知第 4 條），拿掉。WORMHOLE_RESOLVE_MAX_STEPS 仍是保險絲。
	var steps := 0
	while not _pending_wormholes.is_empty():
		if steps >= SpikeConfig.WORMHOLE_RESOLVE_MAX_STEPS:
			break
		_generate_next()   # 尾端會呼叫 _resolve_wormholes()，佇列逐步清空
		steps += 1


func prune_below(y_limit: float) -> void:
	var kept_platforms: Array = []
	for p in platforms:
		if p.center().y <= y_limit:
			kept_platforms.append(p)
	platforms = kept_platforms

	# 演完的屍體（dying 且倒數歸零）一併回收，否則死亡演出結束後會留一堆看不見的殼
	var kept_monsters: Array = []
	for m in monsters:
		if m.pos.y <= y_limit and not m.expired():
			kept_monsters.append(m)
	monsters = kept_monsters

	var kept_pickups: Array = []
	for pk in pickups:
		if pk.alive and pk.pos.y <= y_limit:
			kept_pickups.append(pk)
	pickups = kept_pickups

	# 蟲洞被回收時也要退出待綁定佇列，否則 _pending 會一直長大、每次生成都白掃一輪
	var kept_wormholes: Array = []
	for wh in wormholes:
		if wh.alive and wh.pos.y <= y_limit:
			kept_wormholes.append(wh)
		else:
			wh.alive = false
	wormholes = kept_wormholes
	_pending_wormholes = _pending_wormholes.filter(func(wh): return wh.alive)


# ------------------------------------------------------------------
# 生成器契約（PILLARS_2.md 已定義的 API 邊界，高度用公尺）
# ------------------------------------------------------------------

## ⚠ 回傳的是「最壞情況下玩家要跳的淨高度」，不是中心點距離。
## 中心距由 _generate_next 從這個值扣掉兩塊板的擺動幅度反推。
func spacing_at(h_m: float) -> float:
	var t := clampf(h_m / SpikeConfig.DIFFICULTY_RAMP_HEIGHT_M, 0.0, 1.0)
	var lo := lerpf(SpikeConfig.SPACING_MIN_AT_0, SpikeConfig.SPACING_MIN_AT_TOP, t)
	var hi := lerpf(SpikeConfig.SPACING_MAX_AT_0, SpikeConfig.SPACING_MAX_AT_TOP, t)
	var s := _rng.randf_range(lo, hi)
	return minf(s, hard_spacing_cap())


func hard_spacing_cap() -> float:
	return SpikeConfig.MAX_JUMP_HEIGHT * SpikeConfig.SPACING_HARD_CAP_RATIO


## 同一高度區間除主鏈之外還會多幾塊（期望值）。到 BAND_SOLO_HEIGHT_M 歸零，
## 之後每個區間只有一塊——這是「越往上平台密度越低」的水平分量。
func band_extra_expect_at(h_m: float) -> float:
	if h_m >= SpikeConfig.BAND_SOLO_HEIGHT_M:
		return 0.0
	var t := clampf(h_m / SpikeConfig.BAND_SOLO_HEIGHT_M, 0.0, 1.0)
	return lerpf(SpikeConfig.BAND_EXTRA_EXPECT_AT_0, 0.0, t)


func is_solo_band(h_m: float) -> bool:
	return h_m >= SpikeConfig.BAND_SOLO_HEIGHT_M


## 這一局實際用的 RNG seed。setup() 收到 0 時 RNG 自己 randomize，真正的 seed 只有它知道，
## 所以要問回來而不是在外面另外產生一個——外面產生就得同時改 setup 的呼叫端與冒煙測試，
## 而那兩處現在都靠「傳 0 ＝ 每局不同」這條性質。
## ⚠ 榜單審核要靠 seed 重現整座井（見 HANDOFF「未動工但已有定論」第 4 條）：沒有 seed
##   就沒有審核能力，這不是統計用的紀錄。
func active_seed() -> int:
	return _rng.seed if _rng != null else 0


func moving_ratio_at(h_m: float) -> float:
	return _lerp_by_height(h_m, SpikeConfig.MOVING_RATIO_AT_0, SpikeConfig.MOVING_RATIO_AT_TOP)


func vertical_ratio_at(h_m: float) -> float:
	return _lerp_by_height(h_m, SpikeConfig.VERTICAL_RATIO_AT_0, SpikeConfig.VERTICAL_RATIO_AT_TOP)


func circular_ratio_at(h_m: float) -> float:
	return _lerp_by_height(h_m, SpikeConfig.CIRCULAR_RATIO_AT_0, SpikeConfig.CIRCULAR_RATIO_AT_TOP)


## 爆炸平台（08-10）。⚠ 這是目前唯一「**關卡**限定」的地形軸——關卡一整局為 0。
## 門檻不在這裡判斷，一律問 SpikeConfig.level_gate_ok()，那張表是「第幾關才有什麼」的
## 唯一答案（見 SECTION 8d 的 LEVEL_GATED）。
## ⚠ 高度插值的分母仍是 DIFFICULTY_RAMP_HEIGHT_M 而不是 goal_meters：「第幾關才有」跟
##   「同一個高度多常見」是兩件事，後者仍然不准隨關卡漂移（見 SECTION 8d 的 ⚠⚠）。
func explosive_ratio_at(h_m: float) -> float:
	if not SpikeConfig.level_gate_ok("explosive_platform", _level_idx):
		return 0.0
	return _lerp_by_height(
		h_m, SpikeConfig.EXPLOSIVE_RATIO_AT_0, SpikeConfig.EXPLOSIVE_RATIO_AT_TOP
	)


func trap_ratio_at(h_m: float) -> float:
	return _lerp_by_height(h_m, SpikeConfig.TRAP_RATIO_AT_0, SpikeConfig.TRAP_RATIO_AT_TOP)


## 彈射器是唯一「往上遞減」的種類，理由見 SpikeConfig 的常數註解。
func launcher_ratio_at(h_m: float) -> float:
	return _lerp_by_height(h_m, SpikeConfig.LAUNCHER_RATIO_AT_0, SpikeConfig.LAUNCHER_RATIO_AT_TOP)


func pickup_chance_at(h_m: float) -> float:
	return _lerp_by_height(h_m, SpikeConfig.PICKUP_CHANCE_AT_0, SpikeConfig.PICKUP_CHANCE_AT_TOP)


## 燃料補給：300m 以下不出現（那之前燃料還夠用，撿了等於白佔一個物資位）。
## 內插方式比照 monster_chance_at——t 仍以終點高度為分母，所以 300m 當下的實際值
## 會略高於 AT_START，這是既有寫法的既有語意，刻意不引入第二種。
func fuel_chance_at(h_m: float) -> float:
	if h_m < SpikeConfig.FUEL_PICKUP_START_HEIGHT_M:
		return 0.0
	return _lerp_by_height(
		h_m, SpikeConfig.FUEL_PICKUP_CHANCE_AT_START, SpikeConfig.FUEL_PICKUP_CHANCE_AT_TOP
	)


func monster_chance_at(h_m: float) -> float:
	if h_m < SpikeConfig.MONSTER_START_HEIGHT_M:
		return 0.0
	return _lerp_by_height(
		h_m, SpikeConfig.MONSTER_CHANCE_AT_START, SpikeConfig.MONSTER_CHANCE_AT_TOP
	)


## Pameloe 出現機率（v16）。PAMELOE_START_HEIGHT_M 以下恆為 0。
## ⚠ 跟 monster_chance_at 是**兩條獨立的機率線、不互斥**：同一塊板可能同時長出巡邏怪與
##   pameloe。兩者位置差很遠（一個站在板上、一個懸在 190px 外的半空），不會疊在一起，
##   而且 pameloe 不掛在平台上、不佔物資名額——所以它也不會偷走金幣的位置。
## ⚠ 這條**不走 `_lerp_by_height`**：t 從登場高度起算，不是從 0m 起算。牠 500m 才出現，
##   用全井的 t 會讓「剛登場」那一刻拿到兩個常數的中點，`AT_START` 這個名字就對不上實際值
##   （調機率的人看著 0.08 卻拿到 0.16）。monster／fuel 那兩條也有同樣的性質，但它們的
##   現行手感是照舊公式調出來的，不順手改。
func pameloe_chance_at(h_m: float) -> float:
	if h_m < SpikeConfig.PAMELOE_START_HEIGHT_M:
		return 0.0
	# ⚠ 分母綁固定的 PAMELOE_CHANCE_TOP_HEIGHT_M，**不是 goal_meters**（08-10 關卡制修正）：
	#   綁 goal_meters 的話同一個 800m 在關卡一與關卡三會抽到不同機率，違反「關卡不改變
	#   高度→難度對應」那條（見 SpikeConfig SECTION 8d ⚠⚠）。值與舊 SHORT preset 相同。
	var span: float = maxf(
		SpikeConfig.PAMELOE_CHANCE_TOP_HEIGHT_M - SpikeConfig.PAMELOE_START_HEIGHT_M, 1.0
	)
	var t := clampf((h_m - SpikeConfig.PAMELOE_START_HEIGHT_M) / span, 0.0, 1.0)
	return lerpf(SpikeConfig.PAMELOE_CHANCE_AT_START, SpikeConfig.PAMELOE_CHANCE_AT_TOP, t)


func _lerp_by_height(h_m: float, at_0: float, at_top: float) -> float:
	var t := clampf(h_m / SpikeConfig.DIFFICULTY_RAMP_HEIGHT_M, 0.0, 1.0)
	return lerpf(at_0, at_top, t)


# ------------------------------------------------------------------
# 內部
# ------------------------------------------------------------------

func _generate_next() -> void:
	var last := _last_platform
	var last_center := last.center()
	var h_m := SpikeConfig.meters_from_y(start_y, last_center.y)

	# 主題區的開始／結束都在這裡結算，之後這一塊的每個決定都吃同一個區段狀態
	_update_segment(h_m)

	# 先定種類與擺幅，才算得出中心距——擺幅會同時影響「最壞跳躍高度」與「最近淨空」。
	var kind := _pick_kind(h_m, last.kind)
	var size := _size_for_kind(kind, h_m)
	var extent := _pick_extent(kind)

	var next_y := last_center.y - _center_gap(spacing_at(h_m), last, extent)

	var x := _pick_x(last_center.x, size, extent)

	var plat := WellPlatform.new()
	plat.kind = kind
	plat.size = size
	plat.pos = Vector2(x, next_y)
	plat.segment_id = segment_id()   # 空字串＝一般路段，見 WellPlatform.segment_id 的 ⚠⚠

	match kind:
		WellPlatform.Kind.MOVING:
			_setup_moving(plat, h_m)
		WellPlatform.Kind.VERTICAL:
			_setup_vertical(plat, extent)
		WellPlatform.Kind.CIRCULAR:
			_setup_circular(plat, extent)

	if next_y <= goal_y and not goal_spawned:
		_make_goal(plat)
		platforms.append(plat)
		_last_platform = plat
		return

	platforms.append(plat)
	_last_platform = plat

	# 同區間已佔用的水平包絡線。主鏈這顆優先佔位，額外跳板只能閃它。
	var band_spans: Array = [plat.span_x()]

	var has_monster := false
	# solo 區間的「會動的平台」不掛怪物（08-10）：那裡沒有備援跳板，板子在跑 ＋ 板上有
	# 即死物＝兩層賭注疊在同一塊唯一的落點上。理由與 _pick_kind 擋掉「連兩塊會動的板」
	# 同一條；差別只在那條擋的是跨區間、這條擋的是同一塊板上的疊加。
	# ⚠ 爆炸板也不掛怪（08-10）：踩頭反彈會把玩家彈回半空，落點卻正好是一塊已經開始
	#   倒數的板，玩家沒有第二個選擇；而且怪物本身不會被爆炸清掉，等於板沒了怪還在。
	# ⚠ solo 判斷用**這一塊自己的**高度，不是 h_m（那是上一塊的）：兩者差一個高度區間，
	#   在 BAND_SOLO_HEIGHT_M 邊界上會讓剛好跨過去的那一塊漏掉防護。差一塊聽起來很小，
	#   但那一塊正好在「備援板剛消失」的交界處，是最不該漏的位置。
	var plat_h_m: float = SpikeConfig.meters_from_y(start_y, next_y)
	var monster_ok := kind != WellPlatform.Kind.LAUNCHER \
		and not _is_perishable(kind) \
		and not (is_solo_band(plat_h_m) and _is_mobile(kind))
	if monster_ok:
		# ⚠ 主題區的倍率在**呼叫端**乘，不進 monster_chance_at()——那個函式要維持純函式，
		#   難度不變性稽核直接對它取樣（見 _seg_index 的 ⚠）。
		var mchance: float = monster_chance_at(h_m) * float(_seg_field("monster_mult", 1.0))
		if _rng.randf() < mchance:
			monsters.append(_make_monster(plat, h_m))
			has_monster = true

	# Pameloe（v16）走自己的機率線，且**不看平台種類、不動 has_monster**：牠懸在半空、
	# 不掛在平台的物資掛點上，所以「有怪物的板不長物資」那條（物資等於逼玩家去撞怪）
	# 對牠不適用。彈射板／碎裂板上方一樣可能有牠。
	if _rng.randf() < pameloe_chance_at(h_m):
		var pm = _make_pameloe(plat)
		if pm != null:
			monsters.append(pm)

	# 蟲洞優先於物資：兩者都掛在平台正上方，同一塊板放不下兩個，而蟲洞稀少得多
	if not _maybe_spawn_wormhole(plat, h_m, has_monster):
		_maybe_spawn_pickup(plat, h_m, has_monster)
	_generate_band_extras(last, last_center, next_y, h_m, band_spans)
	# 墓碑放在物資與額外跳板之後：① 它要能把同一塊板上剛長出來的金幣擠掉
	# ② 額外跳板也是候選，得先存在才掃得到（見函式說明）
	_maybe_place_tomb(plat)
	_resolve_wormholes()


## 相鄰兩塊平台的中心距。兩條約束同時成立，取比較嚴的那個：
##   ① 可達性：上一塊擺到最低、這一塊擺到最高時，垂直距離不得超過 spacing
##   ② 不重疊：上一塊擺到最高、這一塊擺到最低時，仍要留 PLATFORM_VERTICAL_CLEARANCE
## 兩者都被 SPACING_HARD_CAP_RATIO 罩住（見 SpikeConfig 的擺幅上限約束推導）。
func _center_gap(spacing: float, last: WellPlatform, next_extent: float) -> float:
	var reach_gap := spacing - last.down_extent() - next_extent
	var clear_gap := last.up_extent() + next_extent + SpikeConfig.PLATFORM_VERTICAL_CLEARANCE
	return maxf(reach_gap, clear_gap)


## 同一高度區間的額外選擇：主鏈那顆之外再灑幾顆純 STATIC 跳板當額外選項。
## 取樣視窗跟主鏈那顆共用同一份「上一顆可達性」公式，只是彼此的水平包絡線要錯開，
## 所以每顆都真的落在玩家跳得到的範圍內，是真選擇而非裝飾。
func _generate_band_extras(
	prev: WellPlatform, prev_center: Vector2, band_y: float, h_m: float, band_spans: Array
) -> void:
	# ⚠⚠ 主題區把期望值頂到 band_extra_min（SECTION 4e）。這不是「順便多給一點」——
	#   它是 _pick_kind 裡那條「主題區跳過死局防護」的**對價**：BAND_SOLO_HEIGHT_M 以上
	#   一個區間本來只有主鏈那一塊，整段又都是會動的板，沒有備援就是連續賭時機。
	var expect: float = maxf(
		band_extra_expect_at(h_m), float(_seg_field("band_extra_min", 0.0))
	)
	var extra_count := _sample_count(expect)
	if extra_count <= 0:
		return

	# 額外跳板只能往下偏移，而且不得吃掉「下方那塊擺到最高時」的淨空。
	var room := (prev_center.y - band_y) - prev.up_extent() \
		- SpikeConfig.PLATFORM_VERTICAL_CLEARANCE
	var max_drop := clampf(SpikeConfig.BAND_EXTRA_Y_DROP, 0.0, maxf(room, 0.0))

	for _i in range(extra_count):
		var size := SpikeConfig.PLATFORM_SIZE
		# 主題區的備援板必須真的擺出來（見 _pick_x_apart 的 ⚠⚠），所以開確定性掃描
		var x = _pick_x_apart(prev_center.x, size, band_spans, in_segment())
		if x == null:
			continue

		var plat := WellPlatform.new()
		plat.kind = WellPlatform.Kind.STATIC
		plat.size = size
		plat.pos = Vector2(x, band_y + _rng.randf_range(0.0, max_drop))
		plat.segment_id = segment_id()   # 備援板跟主鏈同段，稽核靠這個配對
		platforms.append(plat)
		band_spans.append(plat.span_x())

		_maybe_spawn_pickup(plat, h_m, false)


## 把期望值變成整數個數：整數部分照給，小數部分當機率再擲一次。
func _sample_count(expect: float) -> int:
	var base := int(floorf(expect))
	if _rng.randf() < expect - float(base):
		base += 1
	return base


func _pick_kind(h_m: float, last_kind: int) -> int:
	# 主題區覆寫：整段只出這一種板（SECTION 4e）。
	# ⚠⚠ 直接 return，**跳過下面所有死局防護**——這是合法豁免不是漏寫：豁免的前提是
	#   區段強制帶備援跳板（band_extra_min，見 _generate_band_extras），有備援就不再是
	#   「連兩次賭時機」。⚠ 拿掉 band_extra_min 而保留這條 return，690m 以上的主題區
	#   會直接變成運氣牆。兩者是一組的。
	# ⚠ force_kind 只允許指定不會「踩了就沒」的板：整段都是碎裂／爆炸板等於沒有落點。
	#   這條有稽核在守（audit_levels._audit_segments）。
	var forced := _segment_forced_kind()
	if forced >= 0:
		return forced

	var kind := WellPlatform.Kind.STATIC
	if _rng.randf() < launcher_ratio_at(h_m):
		kind = WellPlatform.Kind.LAUNCHER
	elif _rng.randf() < trap_ratio_at(h_m):
		kind = WellPlatform.Kind.FRAGILE
	elif _rng.randf() < explosive_ratio_at(h_m):
		kind = WellPlatform.Kind.EXPLOSIVE
	elif _rng.randf() < moving_ratio_at(h_m):
		kind = WellPlatform.Kind.MOVING
	elif _rng.randf() < vertical_ratio_at(h_m):
		kind = WellPlatform.Kind.VERTICAL
	elif _rng.randf() < circular_ratio_at(h_m):
		kind = WellPlatform.Kind.CIRCULAR

	# 死局防護：連續兩塊 FRAGILE = 無解；LAUNCHER 後接 FRAGILE = 不公平。
	if kind == WellPlatform.Kind.FRAGILE and last_kind == WellPlatform.Kind.FRAGILE:
		kind = WellPlatform.Kind.STATIC
	if last_kind == WellPlatform.Kind.LAUNCHER and kind == WellPlatform.Kind.FRAGILE:
		kind = WellPlatform.Kind.STATIC
	# 爆炸板（08-10）：不得跟另一塊「踩了就會沒」的板相鄰。
	# ⚠ 這條防的不是「炸得到上一塊」（半徑遠小於間距，有稽核在守），而是**沒有安全落點**：
	#   兩塊都在倒數／淡出時，玩家被迫連續兩次賭時機，而 solo 區間根本沒有備援板。
	# ⚠ LAUNCHER 後接爆炸板同樣擋掉：被彈射器甩上去的那一刻玩家沒有控制權，落點是被動的，
	#   落在一塊會開始倒數的板上等於把「不能久留」變成「來不及反應」。
	if _is_perishable(kind) and _is_perishable(last_kind):
		kind = WellPlatform.Kind.STATIC
	if last_kind == WellPlatform.Kind.LAUNCHER and kind == WellPlatform.Kind.EXPLOSIVE:
		kind = WellPlatform.Kind.STATIC
	# solo 區間沒有備援跳板，連續兩塊會動的板等於要玩家連兩次賭時機。
	if is_solo_band(h_m) and _is_mobile(kind) and _is_mobile(last_kind):
		kind = WellPlatform.Kind.STATIC

	return kind


# ------------------------------------------------------------------
# 特殊區段（SECTION 4e）
# ------------------------------------------------------------------

## 每生一塊主鏈平台結算一次：該不該結束目前這段、該不該開一段新的。
## ⚠ 結束判斷放在開始判斷之前，否則同一塊板可能既結束又立刻開新的一段，
##   SEGMENT_MIN_GAP_M 就形同虛設。
func _update_segment(h_m: float) -> void:
	if _seg_index >= 0:
		if h_m >= _seg_end_h:
			_last_seg_end_h = _seg_end_h
			_seg_index = -1
		return
	if SpikeConfig.SEGMENT_TABLE.is_empty():
		return
	if h_m < SpikeConfig.SEGMENT_START_HEIGHT_M:
		return
	if h_m - _last_seg_end_h < SpikeConfig.SEGMENT_MIN_GAP_M:
		return
	if _rng.randf() >= SpikeConfig.SEGMENT_CHANCE_PER_BAND:
		return
	_seg_index = _rng.randi_range(0, SpikeConfig.SEGMENT_TABLE.size() - 1)
	_seg_end_h = h_m + SpikeConfig.SEGMENT_LENGTH_M
	segments.append({
		"id": segment_id(), "start_h": h_m, "end_h": _seg_end_h,
	})


## 目前主題區的某個欄位；不在主題區內就回 fallback。
## ⚠ 讀不到的欄位也回 fallback（不是報錯）：SEGMENT_TABLE 是給人手改的表，
##   少寫一個欄位應該退回「沒有效果」，不是讓整座井生不出來。
func _seg_field(key: String, fallback):
	if _seg_index < 0:
		return fallback
	var row: Dictionary = SpikeConfig.SEGMENT_TABLE[_seg_index]
	return row.get(key, fallback)


## 目前主題區強制的平台種類；-1 = 不覆寫。
## ⚠ 名字翻不出來時回 -1（＝整段沒有主題）而不是當掉，但**有稽核在守**
##   （`audit_levels._audit_segments` 會驗每一列的 force_kind 都翻得出來）：
##   拼錯字的失效方式是「主題區看起來跟一般路段一樣」，沒有人會注意到。
func _segment_forced_kind() -> int:
	var name: String = String(_seg_field("force_kind", ""))
	if name == "":
		return -1
	return _kind_from_name(name)


## SEGMENT_TABLE 用字串指定平台種類的翻譯表。⚠ 存在的理由是避免 SpikeConfig（autoload）
##   反過來引用 WellPlatform（class_name）而做出雙向依賴，見 SECTION 4e 的 ⚠。
func _kind_from_name(name: String) -> int:
	match name:
		"STATIC":
			return WellPlatform.Kind.STATIC
		"MOVING":
			return WellPlatform.Kind.MOVING
		"FRAGILE":
			return WellPlatform.Kind.FRAGILE
		"LAUNCHER":
			return WellPlatform.Kind.LAUNCHER
		"VERTICAL":
			return WellPlatform.Kind.VERTICAL
		"CIRCULAR":
			return WellPlatform.Kind.CIRCULAR
		"EXPLOSIVE":
			return WellPlatform.Kind.EXPLOSIVE
	return -1


## 現在在不在主題區裡（給稽核與繪製問）
func in_segment() -> bool:
	return _seg_index >= 0


## 目前主題區的 id（不在區段內回空字串）
func segment_id() -> String:
	return String(_seg_field("id", ""))


func _is_mobile(kind: int) -> bool:
	return kind == WellPlatform.Kind.MOVING \
		or kind == WellPlatform.Kind.VERTICAL \
		or kind == WellPlatform.Kind.CIRCULAR


## 「踩了就會消失」的板。⚠ 兩種消失方式差很多（碎裂只是沒了、爆炸還會殺人），但對
##   「下一塊落點安不安全」這個問題來說性質相同，所以放同一個判斷式，不各寫一條。
func _is_perishable(kind: int) -> bool:
	return kind == WellPlatform.Kind.FRAGILE or kind == WellPlatform.Kind.EXPLOSIVE


## 平台尺寸。solo 區間（BAND_SOLO_HEIGHT_M 以上）整體加寬 PLATFORM_WIDTH_MULT_SOLO，
## 讓「怪物走不到的邊緣」真的存在——完整幾何推導見 SpikeConfig 該常數的 ⚠⚠。
## ⚠ 只乘 x 不乘 y：厚度是落地判定（LAND_TOLERANCE）的基準，跟著乘等於偷偷改手感。
func _size_for_kind(kind: int, h_m: float) -> Vector2:
	var base: Vector2
	match kind:
		WellPlatform.Kind.FRAGILE:
			base = SpikeConfig.FRAGILE_SIZE
		WellPlatform.Kind.LAUNCHER:
			base = SpikeConfig.LAUNCHER_SIZE
		WellPlatform.Kind.VERTICAL:
			base = SpikeConfig.VERTICAL_SIZE
		WellPlatform.Kind.CIRCULAR:
			base = SpikeConfig.CIRCULAR_SIZE
		WellPlatform.Kind.EXPLOSIVE:
			base = SpikeConfig.EXPLOSIVE_SIZE
		_:
			base = SpikeConfig.PLATFORM_SIZE
	if is_solo_band(h_m):
		base.x *= SpikeConfig.PLATFORM_WIDTH_MULT_SOLO
	return base


## 這塊板的垂直擺幅（上下對稱）。先抽出來給 _center_gap 用，之後才真正裝進平台。
func _pick_extent(kind: int) -> float:
	match kind:
		WellPlatform.Kind.VERTICAL:
			return _rng.randf_range(SpikeConfig.VERTICAL_AMP_MIN, SpikeConfig.VERTICAL_AMP_MAX)
		WellPlatform.Kind.CIRCULAR:
			return _rng.randf_range(
				SpikeConfig.CIRCULAR_RADIUS_MIN, SpikeConfig.CIRCULAR_RADIUS_MAX
			)
		_:
			return 0.0


## 主鏈的水平落點。基礎是「可達視窗內均勻抽」＝隨機遊走，而隨機遊走天生會在井的
## 某一側盤旋好幾塊（井寬 1100px、單步只能位移 ±315px）。所以再疊一層弱反偏壓：
## 近期落點的 EMA 偏離井心超過死區時，多抽幾個候選、挑最靠近鏡射點的那個。
##
## ⚠ 只在超出死區時才施壓，而且是「挑候選」不是「直接指定座標」——若每塊都硬糾正，
##   會生出左右左右的鋸齒，那比原本的群聚更假、也更難跳。
func _pick_x(last_x: float, size: Vector2, extent: float) -> float:
	var window := _reachable_window(last_x, size, extent)
	var x := _rng.randf_range(window.x, window.y)

	var center := (SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5
	var bias := _x_ema - center
	if absf(bias) > SpikeConfig.X_BALANCE_DEADZONE:
		var mirror := clampf(center - bias, window.x, window.y)
		for _i in range(SpikeConfig.X_BALANCE_CANDIDATES - 1):
			var c := _rng.randf_range(window.x, window.y)
			if absf(c - mirror) < absf(x - mirror):
				x = c

	_note_x(x)
	return x


## 把一個實際落點餵進 EMA。額外跳板也要餵——它們同樣佔畫面，只算主鏈會低估群聚。
func _note_x(x: float) -> void:
	_x_ema = lerpf(_x_ema, x, SpikeConfig.X_BALANCE_EMA_ALPHA)


## 跟 _pick_x 同一份可達視窗，但額外排斥「水平包絡線會跟 taken_spans 相交」的位置
## （同區間額外跳板用）。試 BAND_EXTRA_PLACEMENT_TRIES 次找不到就放棄，回傳 null——
## 寧可這個區間少一顆，也不要生出互相重疊的板。
## exhaustive：隨機試完仍失敗時，改用**確定性掃描**把可達視窗走一遍。給主題區用
##   （SECTION 4e）——那裡的備援跳板不是「多給一顆」而是死局防護豁免的對價，
##   ⚠⚠ 它是機率性的就等於防護是機率性的。實測隨機 8 次在主題區有約 8% 的區間擺不出來
##   （整段都是會動的板，主鏈的水平包絡線寬得多，隨機抽很容易一直撞上）。
## ⚠ 一般路段刻意**不開**：那裡擺不下就少一顆額外選項而已，本來就有主鏈可走；
##   全面改成掃描會讓低處的平台密度整體上升，等於順手改掉既有的難度平衡。
func _pick_x_apart(last_x: float, size: Vector2, taken_spans: Array, exhaustive := false):
	var window := _reachable_window(last_x, size, 0.0)
	var half := size.x * 0.5
	for _try in range(SpikeConfig.BAND_EXTRA_PLACEMENT_TRIES):
		var x := _rng.randf_range(window.x, window.y)
		if _x_fits(x, half, taken_spans):
			_note_x(x)
			return x
	if not exhaustive:
		return null
	# 掃描：步進夠細才不會跳過兩塊板之間剛好夠用的縫隙
	var steps := int((window.y - window.x) / SpikeConfig.BAND_EXTRA_SCAN_STEP) + 1
	for i in range(steps):
		var x: float = minf(window.x + float(i) * SpikeConfig.BAND_EXTRA_SCAN_STEP, window.y)
		if _x_fits(x, half, taken_spans):
			_note_x(x)
			return x
	return null


func _x_fits(x: float, half: float, taken_spans: Array) -> bool:
	var span := Vector2(x - half, x + half)
	for t in taken_spans:
		if _spans_conflict(span, t):
			return false
	return true


## 兩段水平包絡線是否靠得太近（含 PLATFORM_MIN_GAP 的安全距）
func _spans_conflict(a: Vector2, b: Vector2) -> bool:
	return a.x < b.y + SpikeConfig.PLATFORM_MIN_GAP \
		and b.x < a.y + SpikeConfig.PLATFORM_MIN_GAP


## 水平可達視窗：從 last_x 起跳、一次跳躍弧線內全速能搆到的 x 範圍，clamp 在井內。
## extent > 0（會左右擺動的板）時要再往內縮，讓整段運動範圍都留在井內。
func _reachable_window(last_x: float, size: Vector2, extent: float) -> Vector2:
	var t_rise := absf(SpikeConfig.JUMP_VELOCITY) / SpikeConfig.GRAVITY
	var max_dx := SpikeConfig.MOVE_MAX_SPEED * t_rise * SpikeConfig.REACHABILITY_MARGIN

	var margin := size.x * 0.5 + extent
	var well_lo := SpikeConfig.WELL_LEFT + margin
	var well_hi := SpikeConfig.WELL_RIGHT - margin

	var lo := maxf(well_lo, last_x - max_dx)
	var hi := minf(well_hi, last_x + max_dx)
	if lo > hi:
		# 井太窄裝不下可達窗與尺寸的交集時，退回井內合法範圍（再不行就置中）。
		lo = well_lo
		hi = well_hi
		if lo > hi:
			var mid := (SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5
			return Vector2(mid, mid)

	return Vector2(lo, hi)


## ⚠ 主題區內一律用 SOLO 那個較小的巡邏半徑，**不看高度**（SECTION 4e）：整段都是會動的
##   板時，可達性要可預測，備援跳板也才擺得下（板子掃過的範圍越大，_pick_x_apart 越容易
##   找不到不重疊的位置而放棄——而那顆備援板正是主題區豁免死局防護的對價）。
func _setup_moving(plat: WellPlatform, h_m: float) -> void:
	var half: float = SpikeConfig.MOVING_PATROL_RANGE_SOLO \
		if (is_solo_band(h_m) or in_segment()) \
		else SpikeConfig.MOVING_PATROL_RANGE
	var well_lo := SpikeConfig.WELL_LEFT + plat.size.x * 0.5
	var well_hi := SpikeConfig.WELL_RIGHT - plat.size.x * 0.5

	plat.move_min_x = maxf(well_lo, plat.pos.x - half)
	plat.move_max_x = minf(well_hi, plat.pos.x + half)
	plat.pos.x = clampf(plat.pos.x, plat.move_min_x, plat.move_max_x)

	var speed := _rng.randf_range(SpikeConfig.MOVING_SPEED_MIN, SpikeConfig.MOVING_SPEED_MAX)
	if _rng.randf() < 0.5:
		speed = -speed
	plat.move_speed = speed


func _setup_vertical(plat: WellPlatform, amp: float) -> void:
	plat.vert_center_y = plat.pos.y
	plat.vert_amp = amp
	var speed := _rng.randf_range(SpikeConfig.VERTICAL_SPEED_MIN, SpikeConfig.VERTICAL_SPEED_MAX)
	if _rng.randf() < 0.5:
		speed = -speed
	plat.vert_speed = speed
	# 起始相位隨機：整條井的上下板同步擺動看起來像機械故障
	plat.pos.y = plat.vert_center_y + _rng.randf_range(-amp, amp)


func _setup_circular(plat: WellPlatform, radius: float) -> void:
	plat.orbit_center = plat.pos
	plat.orbit_radius = radius
	plat.orbit_speed = _rng.randf_range(
		SpikeConfig.CIRCULAR_ANGULAR_SPEED_MIN, SpikeConfig.CIRCULAR_ANGULAR_SPEED_MAX
	)
	if _rng.randf() < 0.5:
		plat.orbit_speed = -plat.orbit_speed
	plat.orbit_phase = _rng.randf_range(0.0, TAU)
	plat.pos = plat.orbit_center \
		+ Vector2(cos(plat.orbit_phase), sin(plat.orbit_phase)) * radius


func _make_goal(plat: WellPlatform) -> void:
	plat.is_goal = true
	plat.kind = WellPlatform.Kind.STATIC
	plat.size = Vector2(SpikeConfig.WELL_RIGHT - SpikeConfig.WELL_LEFT, SpikeConfig.PLATFORM_SIZE.y)
	plat.pos = Vector2((SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5, goal_y)
	plat.move_min_x = 0.0
	plat.move_max_x = 0.0
	plat.move_speed = 0.0
	plat.vert_amp = 0.0
	plat.vert_speed = 0.0
	plat.orbit_radius = 0.0
	plat.orbit_speed = 0.0
	goal_spawned = true


## ⚠ solo 區間用 MONSTER_PATROL_RANGE_SOLO（較小）：那裡沒有備援跳板，怪物的掃過範圍
##   若接近平台寬度，平台上就不存在安全落腳點，唯一的路等於被即死物封死
##   （完整推導見 SpikeConfig 的 PLATFORM_WIDTH_MULT_SOLO ⚠⚠）。
func _make_monster(plat: WellPlatform, h_m: float) -> WellMonster:
	var m := WellMonster.new()
	m.host = plat
	var base_range: float = SpikeConfig.MONSTER_PATROL_RANGE_SOLO if is_solo_band(h_m) \
		else SpikeConfig.MONSTER_PATROL_RANGE
	# 巡邏範圍相對母平台，且再夾一次「不得超過平台半寬」，怪物才會一直待在可踩的板上方
	var range_: float = minf(
		base_range, maxf(plat.size.x * 0.5 - m.size.x * 0.5, 0.0)
	)
	m.local_min = -range_
	m.local_max = range_
	m.local_x = 0.0
	m.pos = Vector2(plat.pos.x, plat.top_y() - m.size.y * 0.5)
	return m


## Pameloe（v16）：懸浮在母平台上方、水平至少隔開 PAMELOE_MIN_DIST_X 的定點。
##
## ⚠⚠ 水平隔開是可歸因性的保命條款（見 SpikeConfig 的 PAMELOE_MIN_DIST_X ⚠⚠）：牠碰到即死，
##   長在平台正上方就會把主鏈那條唯一的跳躍路線變成運氣牆。
## ⚠ 兩側都塞不下時回 null，這塊板就沒有——寧可少一隻，也不要生一個堵路的即死物。
## ⚠ 位置只在生成當下抽一次、之後完全不動（沒有 host，不跟隨任何平台）。這正是「玩家
##   一定踩得到」的來源：一個會飄的即死物才是踩不到的障礙。
## ⚠ 垂直上仍可能跟**下一塊還沒生成的**主鏈平台重疊（生成鏈是逐塊往上的，這一刻算不出來）。
##   對策不是挪位置而是**繪製順序**：pameloe 畫在平台之後（見 WellWorld._draw），被蓋住
##   就跟看不見的黑洞一樣是不可歸因的死法。
func _make_pameloe(plat: WellPlatform):
	var half: float = SpikeConfig.PAMELOE_SIZE.x * 0.5
	var lo: float = SpikeConfig.WELL_LEFT + half
	var hi: float = SpikeConfig.WELL_RIGHT - half
	var left_hi: float = plat.pos.x - SpikeConfig.PAMELOE_MIN_DIST_X
	var right_lo: float = plat.pos.x + SpikeConfig.PAMELOE_MIN_DIST_X

	var spans: Array = []
	if left_hi > lo:
		spans.append([lo, left_hi])
	if right_lo < hi:
		spans.append([right_lo, hi])
	if spans.is_empty():
		return null

	var span: Array = spans[_rng.randi_range(0, spans.size() - 1)]
	var m := WellMonster.new()
	m.set_kind(WellMonster.Kind.PAMELOE)
	# 漂浮（08-10）：base_y 是「不晃時的高度」，pos.y 立刻套用相位當下的位移——不先套的話
	# 第一次 step() 會把牠瞬間挪走，看起來像生成位置抽錯了。⚠ 判定跟著 pos 走，見
	# WellMonster.float_phase 的 ⚠⚠。
	m.float_phase = _rng.randf_range(0.0, TAU)
	m.float_base_y = plat.pos.y - plat.size.y * 0.5 - SpikeConfig.PAMELOE_HOVER_Y
	m.pos = Vector2(
		_rng.randf_range(span[0], span[1]),
		m.float_base_y + sin(m.float_phase) * SpikeConfig.PAMELOE_FLOAT_AMP
	)
	# 兩張立繪的抽取（08-10，三訂起同時決定開火方式）：生成當下骰一次就定死，走 seeded
	# rng 讓同一顆 seed 重現同一座井（見 WellMonster.art_variant 的 ⚠⚠）。
	m.art_variant = 1 if _rng.randf() < SpikeConfig.PAMELOE_RARE_ART_CHANCE else 0
	return m


## 物資掛在平台上（跟著它移動）。有怪物的平台不掛：物資的位置就在平台正上方，
## 跟怪物的巡邏帶完全重疊，等於用物資逼玩家去撞怪。
##
## 金幣優先、燃料補位：兩種都掛在平台正上方同一個座標，一塊板只放得下一個。
## 燃料走自己的機率線而不是「瓜分金幣的名額」，金幣掉落率才不會被稀釋。
func _maybe_spawn_pickup(plat: WellPlatform, h_m: float, has_monster: bool) -> void:
	if has_monster or plat.is_goal:
		return

	var kind := -1
	# ⚠ 主題區的金幣倍率同怪物那條，乘在呼叫端不進純函式。燃料補給刻意**不吃倍率**：
	#   它跟金幣是兩條獨立的線，而「這一段風險加倍所以報酬加倍」講的是報酬（金幣），
	#   燃料是續航資源，一起放大等於把主題區變成補給站。
	if _rng.randf() < pickup_chance_at(h_m) * float(_seg_field("pickup_mult", 1.0)):
		kind = WellPickup.Kind.COIN
	elif _rng.randf() < fuel_chance_at(h_m):
		kind = WellPickup.Kind.FUEL
	if kind < 0:
		return

	var pk := WellPickup.new()
	pk.set_kind(kind)
	pk.host = plat
	pk.offset = Vector2(0.0, -(plat.size.y * 0.5 + SpikeConfig.PICKUP_HOVER))
	pk.pos = plat.pos + pk.offset
	# 漂浮相位：走 seeded rng 在生成當下定死（見 WellPickup.float_phase 的 ⚠）
	pk.float_phase = _rng.randf_range(0.0, TAU)
	pickups.append(pk)


# ------------------------------------------------------------------
# 墓碑（v12）
# ------------------------------------------------------------------

## 墓碑：立在「歷史最高抵達高度」y 軸最相近的那塊平台上，一局最多一個。
##
## 時點選在「生成鏈剛跨過目標高度」的那一刻，然後掃一次全場挑最近的。
## ⚠ 為什麼這時候掃就等於掃全井：cur 是第一塊到達／越過目標高度的板，之後才會生的板
##   一定比 cur 更高、也就一定離目標更遠——所以「此刻存在的」就是全部候選，不會漏。
##   （不能只比 cur 與上一塊：同一區間的額外跳板落在 cur 稍下方，可能比兩者都更近。）
## ⚠ 也不受串流 prune 影響：生成鏈領先 prune 線約 2 個畫面高，目標高度附近那幾塊
##   在這一刻絕不可能已經被回收。
##
## ⚠ 墓碑壓過同一塊板上原本的金幣／燃料（同一個掛點放不下兩個）。刻意不「換一塊板」：
##   換板會讓「墓碑就在你上次爬到的地方」這個唯一的意義失準。蟲洞是唯一的例外——
##   它同樣佔那個掛點，但稀少得多，所以同距離競爭時讓墓碑退到次近的板。
func _maybe_place_tomb(cur: WellPlatform) -> void:
	if _tomb_placed or is_nan(_tomb_y):
		return
	if cur.center().y > _tomb_y:      # 生成鏈還沒爬到，等下一塊
		return
	_tomb_placed = true

	var pick: WellPlatform = null
	var fallback: WellPlatform = null
	var best_d := INF
	var best_any := INF
	for p in platforms:
		if p.is_goal:
			continue
		var d: float = absf(p.center().y - _tomb_y)
		if d < best_any:
			best_any = d
			fallback = p
		if d < best_d and not _has_wormhole(p):
			best_d = d
			pick = p
	if pick == null:
		pick = fallback
	if pick == null:
		return

	pickups = pickups.filter(func(pk): return pk.host != pick)

	var tomb := WellPickup.new()
	tomb.set_kind(WellPickup.Kind.TOMB)
	tomb.host = pick
	# 墓碑是「立在板上」不是「浮在板上」：底邊貼著平台上緣，不用 PICKUP_HOVER
	tomb.offset = Vector2(0.0, -(pick.size.y * 0.5 + tomb.size.y * 0.5))
	tomb.pos = pick.pos + tomb.offset
	pickups.append(tomb)


func _has_wormhole(plat: WellPlatform) -> bool:
	for wh in wormholes:
		if wh.host == plat:
			return true
	return false


# ------------------------------------------------------------------
# 蟲洞（PILLARS_2.md:399）
# ------------------------------------------------------------------

## 稀少、固定送 +40m、水平出口隨機但保證落在一塊實際平台上。
## 回傳 true 表示這塊板已被蟲洞佔用（呼叫端就不要再放物資）。
##
## 只長在 STATIC 板上：會動的板等於「進洞時機要賭板子晃到哪」，
## 而蟲洞的代價本來就設計成「一次高壓反應」，不該再疊一層運氣。
func _maybe_spawn_wormhole(plat: WellPlatform, h_m: float, has_monster: bool) -> bool:
	if has_monster or plat.is_goal or plat.kind != WellPlatform.Kind.STATIC:
		return false
	if h_m < SpikeConfig.WORMHOLE_MIN_HEIGHT_M:
		return false
	# 終點附近不生：出口會落到終點板之外，或根本來不及綁定
	if h_m > SpikeConfig.goal_meters - SpikeConfig.WORMHOLE_END_MARGIN_M:
		return false
	if h_m - _last_wormhole_h < SpikeConfig.WORMHOLE_MIN_SPACING_M:
		return false
	if _rng.randf() >= SpikeConfig.WORMHOLE_CHANCE:
		return false

	var wh := WellWormhole.new()
	wh.host = plat
	wh.offset = Vector2(0.0, -(plat.size.y * 0.5 + SpikeConfig.WORMHOLE_HOVER))
	wh.pos = plat.pos + wh.offset
	wh.target_y = plat.center().y \
		- SpikeConfig.WORMHOLE_RISE_M * SpikeConfig.PIXELS_PER_METER
	wormholes.append(wh)
	_pending_wormholes.append(wh)
	_last_wormhole_h = h_m
	return true


## 出口延後綁定：生成鏈爬過某個蟲洞的目標高度之後，才回頭把最接近的平台指派給它。
## 生成當下上方 40m 還不存在，硬要「生成時就決定出口」得先往上生 2000px，
## 那會讓串流生成失去意義。
func _resolve_wormholes() -> void:
	if _pending_wormholes.is_empty():
		return
	var still: Array = []
	for wh in _pending_wormholes:
		if not wh.alive:
			continue
		# 生成鏈還沒爬到出口高度 → 這一輪先擱著
		if _last_platform.center().y > wh.target_y:
			still.append(wh)
			continue

		# 只認不會動的出口。剛越過目標高度的那一刻，候選池只有 target_y 附近的兩三塊，
		# 剛好全是移動板是會發生的（實測 7 個蟲洞會中 1 個）。這時**再等幾塊**就好——
		# 等出來的出口只會比目標更高（送更多），絕不會更低，守門承諾不打折。
		var exit_plat := _scan_exit_candidates(wh.target_y, true)
		if exit_plat != null:
			wh.exit_platform = exit_plat
			continue

		# 保險絲：多生了半個畫面還是沒有靜止板，才退而求其次；連移動板都沒有就讓它失效
		# （不畫、不能踩），而不是永遠留在佇列裡每次生成都白掃一輪。
		if _last_platform.center().y < wh.target_y - SpikeConfig.VIEW_H * 0.5:
			wh.exit_platform = _scan_exit_candidates(wh.target_y, false)
			if wh.exit_platform == null:
				wh.alive = false
		else:
			still.append(wh)
	_pending_wormholes = still


## 出口平台候選掃描。「出口固定在平台上」是這次的守門承諾，所以預設只挑不會動的板——
## 出口若是移動板，玩家傳送出來的那 0.9 秒它已經滑走一整個板寬，承諾就打了折。
##
## 排除三種：FRAGILE（出來就踩碎＝等於沒守住）、終點板（會直接判通關）、
## 比目標低太多的（送不到 40m）。still_only = 只要不會動的板。
func _scan_exit_candidates(target_y: float, still_only: bool) -> WellPlatform:
	var best: WellPlatform = null
	var best_d := INF
	var floor_y: float = target_y + SpikeConfig.PLATFORM_VERTICAL_CLEARANCE * 8.0
	for p in platforms:
		if not p.alive or p.is_goal or p.kind == WellPlatform.Kind.FRAGILE:
			continue
		if still_only and _is_mobile(p.kind):
			continue
		var cy: float = p.center().y
		if cy > floor_y:
			continue
		var d: float = absf(cy - target_y)
		if d < best_d:
			best_d = d
			best = p
	return best
