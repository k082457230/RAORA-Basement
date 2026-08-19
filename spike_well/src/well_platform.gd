class_name WellPlatform
extends RefCounted
## 井裡的單一平台。純資料 + 純邏輯，不繪製、不接輸入。
##
## 四種運動型態共存（STATIC 不動、MOVING 左右、VERTICAL 上下、CIRCULAR 繞圈），
## 因此「這塊板到底佔了多少空間」不能只看 pos：一律走 span_x() / up_extent() /
## down_extent() 這組「運動包絡線」API。生成器的防重疊與可達性計算全靠它們，
## 新增運動型態時只要補這三個函式，生成器一行都不用動。

## ⚠ enum 的既有順序不要動：`kind` 的整數值會出現在冒煙測試輸出（`k0`/`k4`…）與存檔
##   無關的除錯訊息裡，插隊會讓舊紀錄對不上。新種類一律往後加。
## DECOY（08-13x，關卡三限定）：外觀跟 STATIC 一模一樣、alpha 降到 DECOY_ALPHA，但完全
## 不成立落地——見 decoy_break_t 與 trigger_decoy_break() 的 ⚠⚠。
enum Kind { STATIC, MOVING, FRAGILE, LAUNCHER, VERTICAL, CIRCULAR, EXPLOSIVE, DECOY }

var kind: int = Kind.STATIC
var pos: Vector2                  # 中心點，世界座標
var size: Vector2
var alive: bool = true

# --- MOVING（左右） ---
var move_speed: float = 0.0       # 帶正負號代表方向
var move_min_x: float = 0.0
var move_max_x: float = 0.0

# --- VERTICAL（上下） ---
var vert_speed: float = 0.0       # 帶正負號代表方向
var vert_center_y: float = 0.0
var vert_amp: float = 0.0

# --- CIRCULAR（圓形軌跡） ---
var orbit_center := Vector2.ZERO
var orbit_radius: float = 0.0
var orbit_speed: float = 0.0      # rad/s
var orbit_phase: float = 0.0

var breaking_timer: float = -1.0  # FRAGILE 被踩後倒數；<0 = 未被踩
var steal_warn: float = -1.0      # 被 Raora 標記中的閃爍倒數；<0 = 未被標記
var is_goal: bool = false         # 終點平台

## --- EXPLOSIVE（08-10）---
## 踩過之後的引信倒數；<0 = 還沒被踩。歸零時平台 alive = false 並豎起 just_exploded，
## 由 WellWorld 接手生成爆炸區（同 just_stolen 的分工：平台是純資料，自己不放特效）。
## ⚠ 引信期間 alive 仍是 true——踩得住、跳得掉。亮度就是剩餘時間，不另設隱形寬限期。
## ⚠ 引信只點一次：重複踩不會重置倒數，否則在板上連跳等於無限拆彈。
var fuse_timer: float = -1.0
## 這一幀剛炸開。單幀旗標，WellWorld 讀到就生爆炸區並自己清掉（同 just_stolen）。
var just_exploded: bool = false

## 這塊板屬於哪一段主題區（SECTION 4e）；空字串＝一般路段。
## ⚠⚠ 存旗標而不是「用高度去反推區段範圍」：生成鏈是用**上一塊**的高度決定**這一塊**的
##   性質（要先知道種類與擺幅才算得出這一塊的 y，是個先有雞還先有蛋的順序），所以
##   「平台的高度落在區段範圍內」跟「它生成時真的套用了區段規則」會差一個高度區間。
##   稽核靠高度反推就會在每段的頭尾各誤判一次，紅得毫無道理。
var segment_id: String = ""

## 這塊是同一個高度區間的「備援跳板」（`_generate_band_extras` 灑的），不是主鏈那一顆。
## ⚠⚠ 存旗標而不是讓稽核用 y 去猜（同 segment_id 的 ⚠⚠，但這次是真的踩到）：備援板
##   往下偏移的距離是 `randf_range(0, max_drop)`，**骰到 0 就跟主鏈同一個 y**。稽核原本
##   靠「群裡最高的那顆＝主鏈」認人，同 y 時 sort_custom 不保證順序（Godot 的排序不穩定），
##   於是備援板（恆為 STATIC）會排到前面，被誤判成「主題區的 force_kind 沒生效」。
##   08-11 真的中過一次（seed 777 的 940.2m）。
var is_band_extra: bool = false

## --- 純視覺欄位（08-11）---
## ⚠⚠ 以下三顆**只有繪製讀得到**：`rect()`／`top_y()`／`span_x()`／落地判定一律不看它們。
##   判定被視覺牽著走＝偷偷改了平台的物理形狀（同 v12「大小 ×2 要連判定一起乘」那條的
##   反向：這裡是刻意讓視覺單飛，所以更要明講）。
##
## 踩踏晃動的剩餘時間；<0 = 沒在晃。見 stomp_offset_y()。
var stomp_t: float = -1.0
## 貼圖鏡像（生成時骰一次就定死，見 WellGenerator._generate_next）。
var flip_h: bool = false
var flip_v: bool = false

## 這一幀剛被 Raora 削掉。單幀旗標：WellWorld 讀到就放火花並自己清掉
## （見 WellWorld._collect_steal_sparks）。平台本身不畫東西，所以不能自己放特效。
var just_stolen: bool = false

## --- DECOY（騙人平台，08-13x）---
## 拆開演出的剩餘時間；<0 = 還沒被碰過。歸零時 alive = false（同 fuse_timer／
## breaking_timer 的收尾方式）。⚠⚠ **落地判定完全不看這顆**——WellWorld._check_landing
## 一律把 kind == DECOY 整塊跳過，不管 decoy_break_t 是多少：判定不成立這件事從生成的
## 那一刻就成立，不是「拆開之後才不成立」。這是「演出期間必須保證不可能再被判定到」
## 這條規格最簡單也最徹底的做法——判定原本就沒把它算進去，不需要額外的「演出中」旗標。
var decoy_break_t: float = -1.0


func rect() -> Rect2:
	return Rect2(pos - size * 0.5, size)


func top_y() -> float:
	return pos.y - size.y * 0.5


## 這塊板在整個運動週期裡會掃過的 x 範圍（已含板寬）。
## 防重疊只認這個，不認 pos.x——不然左右移動的板會直接掃進鄰居身上。
func span_x() -> Vector2:
	var half := size.x * 0.5
	match kind:
		Kind.MOVING:
			return Vector2(move_min_x - half, move_max_x + half)
		Kind.CIRCULAR:
			return Vector2(
				orbit_center.x - orbit_radius - half,
				orbit_center.x + orbit_radius + half
			)
		_:
			return Vector2(pos.x - half, pos.x + half)


## 中心點相對「靜止中心」最多能往上／往下擺多遠（px）。
## 生成器用它決定相鄰高度區間的中心距：往上擺會拉高玩家要跳的高度，
## 往下擺會壓縮跟下一塊的淨空。
func up_extent() -> float:
	match kind:
		Kind.VERTICAL:
			return vert_amp
		Kind.CIRCULAR:
			return orbit_radius
		_:
			return 0.0


func down_extent() -> float:
	return up_extent()


## 靜止中心，不隨運動漂移。⚠ 生成鏈一律引用這個而不是 pos：世界是邊玩邊串流生成的，
## 輪到接下一塊時上一塊的 pos 早就跑掉了，用 pos 當基準會讓整條鏈跟著歪。
func center() -> Vector2:
	match kind:
		Kind.VERTICAL:
			return Vector2(pos.x, vert_center_y)
		Kind.CIRCULAR:
			return orbit_center
		Kind.MOVING:
			return Vector2((move_min_x + move_max_x) * 0.5, pos.y)
		_:
			return pos


func step(delta: float) -> void:
	match kind:
		Kind.MOVING:
			pos.x += move_speed * delta
			if pos.x >= move_max_x:
				pos.x = move_max_x
				move_speed = -absf(move_speed)
			elif pos.x <= move_min_x:
				pos.x = move_min_x
				move_speed = absf(move_speed)
		Kind.VERTICAL:
			pos.y += vert_speed * delta
			if pos.y >= vert_center_y + vert_amp:
				pos.y = vert_center_y + vert_amp
				vert_speed = -absf(vert_speed)
			elif pos.y <= vert_center_y - vert_amp:
				pos.y = vert_center_y - vert_amp
				vert_speed = absf(vert_speed)
		Kind.CIRCULAR:
			orbit_phase = fmod(orbit_phase + orbit_speed * delta, TAU)
			pos = orbit_center + Vector2(cos(orbit_phase), sin(orbit_phase)) * orbit_radius

	if breaking_timer >= 0.0:
		breaking_timer -= delta
		if breaking_timer <= 0.0:
			alive = false

	if steal_warn >= 0.0:
		steal_warn -= delta
		if steal_warn <= 0.0:
			alive = false
			just_stolen = true

	if fuse_timer >= 0.0:
		fuse_timer -= delta
		if fuse_timer <= 0.0:
			alive = false
			just_exploded = true

	if decoy_break_t >= 0.0:
		decoy_break_t -= delta
		if decoy_break_t <= 0.0:
			alive = false

	if stomp_t >= 0.0:
		stomp_t -= delta


## 只有 STATIC 與 EXPLOSIVE 會晃（使用者拍板，理由見 SpikeConfig 的 PLATFORM_STOMP_TIME）。
func _stomps() -> bool:
	return kind == Kind.STATIC or kind == Kind.EXPLOSIVE


func on_stepped() -> void:
	# ⚠ 沒有 `< 0.0` 的守衛是刻意的（跟下面的引信相反）：重複踩要**重新起震**，
	#   晃動是即時觸覺回饋、不是倒數計時器。
	if _stomps():
		stomp_t = SpikeConfig.PLATFORM_STOMP_TIME

	if kind == Kind.FRAGILE and breaking_timer < 0.0:
		breaking_timer = SpikeConfig.FRAGILE_FADE_TIME
	# ⚠ `< 0.0` 這個條件就是「引信只點一次」：拿掉的話在板上連跳會一直把倒數推回滿格，
	#   等於玩家可以無限拆彈，這塊板就永遠不會炸。
	if kind == Kind.EXPLOSIVE and fuse_timer < 0.0:
		fuse_timer = SpikeConfig.EXPLOSIVE_FUSE_TIME


## 被踩過的 FRAGILE 在剩餘時間內線性淡出（1 → 0）。其他狀況一律 1。
## ⚠ 這個值同時就是「還踩得住多久」的比例——透明度即剩餘壽命，不另設隱形寬限期。
func fade_alpha() -> float:
	if breaking_timer < 0.0:
		return 1.0
	return clampf(breaking_timer / SpikeConfig.FRAGILE_FADE_TIME, 0.0, 1.0)


## 騙人平台碰到當幀觸發拆開演出。⚠ `< 0.0` 守衛＝只點一次（同爆炸引信的理由）：重複
## 碰撞不會重新起算，反正判定本來就不看這塊板，重觸發只會讓飛出去的兩半瞬間跳回原位。
func trigger_decoy_break() -> void:
	if kind == Kind.DECOY and decoy_break_t < 0.0:
		decoy_break_t = SpikeConfig.DECOY_BREAK_TIME


## 拆開演出的淡出比例（1 → 0）。還沒觸發回 1（＝完整不透明的那 DECOY_ALPHA）。
func decoy_break_alpha() -> float:
	if decoy_break_t < 0.0:
		return 1.0
	return clampf(decoy_break_t / SpikeConfig.DECOY_BREAK_TIME, 0.0, 1.0)


## 爆炸引信的剩餘比例（1 → 0）。還沒被踩回 1。
## ⚠ 這個值同時是「還有多久炸」與「亮到什麼程度」，兩者刻意同一個數字——看得見的亮度
##   就是剩餘時間，玩家不必另外背一個隱形的倒數（同 fade_alpha 的設計）。
func fuse_ratio() -> float:
	if fuse_timer < 0.0:
		return 1.0
	return clampf(fuse_timer / SpikeConfig.EXPLOSIVE_FUSE_TIME, 0.0, 1.0)


## 踩踏晃動的**視覺** y 偏移（px，正值＝往下沉）。阻尼震盪：一開始被踩下去 AMP，
## 之後上下來回、振幅指數衰減，時間到歸零。
## ⚠⚠ 只准繪製呼叫。任何判定（落地、重疊、可達性）讀到它就是 bug——平台的物理位置
##   一秒都沒有動過，動的只有那張貼圖。
func stomp_offset_y() -> float:
	if stomp_t < 0.0:
		return 0.0
	# u：已經過的比例 0→1。用「已過」而不是「剩餘」，衰減才是隨時間變小。
	var u: float = clampf(1.0 - stomp_t / SpikeConfig.PLATFORM_STOMP_TIME, 0.0, 1.0)
	var decay: float = exp(-SpikeConfig.PLATFORM_STOMP_DAMP * u)
	return SpikeConfig.PLATFORM_STOMP_AMP * decay \
		* cos(u * TAU * SpikeConfig.PLATFORM_STOMP_CYCLES)


func color() -> Color:
	if steal_warn >= 0.0:
		var phase := int(steal_warn / SpikeConfig.TAIL_PLATFORM_WARN_BLINK_PERIOD) % 2
		if phase == 0:
			return SpikeConfig.C_DANGER_RED

	if is_goal:
		return SpikeConfig.C_GOAL

	# 踩碎中的板：同一個底色，只把 alpha 拉掉，讓「快沒了」是連續量而不是突然消失
	if kind == Kind.FRAGILE and breaking_timer >= 0.0:
		return Color(SpikeConfig.C_FRAGILE, fade_alpha())

	# 引信燒著的爆炸板：從底色（跟 STATIC 同一個 C_PLATFORM，見下方 ⚠）往亮色內插。
	# ⚠ 用「越來越亮」而不是閃爍——閃爍讀不出還剩多久，而這塊板的威脅正是時間本身
	#   （同碎裂平台用 alpha 當剩餘壽命的理由）。
	if kind == Kind.EXPLOSIVE and fuse_timer >= 0.0:
		return SpikeConfig.C_PLATFORM.lerp(
			SpikeConfig.C_EXPLOSIVE_HOT, 1.0 - fuse_ratio()
		)

	# 騙人平台：外觀跟 STATIC 同一個底色，唯一差異是 alpha（使用者拍板的線索）。
	# 拆開演出期間額外乘上淡出比例，讓兩半飛出去的同時逐漸消失。
	if kind == Kind.DECOY:
		return Color(SpikeConfig.C_PLATFORM, SpikeConfig.DECOY_ALPHA * decoy_break_alpha())

	# ⚠ 08-11 使用者拍板：EXPLOSIVE 未觸發前**外觀跟 STATIC 完全一致**（不特別給底色），
	#   唯一的視覺差異是踩下去引信燒起來那段「越來越亮」——不在這裡列 Kind.EXPLOSIVE 的
	#   分支，讓它落到下面 `_` 預設分支自然拿到跟 STATIC 一樣的 C_PLATFORM。
	match kind:
		Kind.MOVING:
			return SpikeConfig.C_MOVING
		Kind.FRAGILE:
			return SpikeConfig.C_FRAGILE
		Kind.LAUNCHER:
			return SpikeConfig.C_LAUNCHER
		Kind.VERTICAL:
			return SpikeConfig.C_VERTICAL
		Kind.CIRCULAR:
			return SpikeConfig.C_CIRCULAR
		_:
			return SpikeConfig.C_PLATFORM
