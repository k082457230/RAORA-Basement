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
enum Kind { STATIC, MOVING, FRAGILE, LAUNCHER, VERTICAL, CIRCULAR, EXPLOSIVE }

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

## 這一幀剛被 Raora 削掉。單幀旗標：WellWorld 讀到就放火花並自己清掉
## （見 WellWorld._collect_steal_sparks）。平台本身不畫東西，所以不能自己放特效。
var just_stolen: bool = false


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


func on_stepped() -> void:
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


## 爆炸引信的剩餘比例（1 → 0）。還沒被踩回 1。
## ⚠ 這個值同時是「還有多久炸」與「亮到什麼程度」，兩者刻意同一個數字——看得見的亮度
##   就是剩餘時間，玩家不必另外背一個隱形的倒數（同 fade_alpha 的設計）。
func fuse_ratio() -> float:
	if fuse_timer < 0.0:
		return 1.0
	return clampf(fuse_timer / SpikeConfig.EXPLOSIVE_FUSE_TIME, 0.0, 1.0)


func color() -> Color:
	if steal_warn >= 0.0:
		var phase := int(steal_warn / SpikeConfig.STEAL_WARN_BLINK_PERIOD) % 2
		if phase == 0:
			return SpikeConfig.C_STEAL_WARN

	if is_goal:
		return SpikeConfig.C_GOAL

	# 踩碎中的板：同一個底色，只把 alpha 拉掉，讓「快沒了」是連續量而不是突然消失
	if kind == Kind.FRAGILE and breaking_timer >= 0.0:
		return Color(SpikeConfig.C_FRAGILE, fade_alpha())

	# 引信燒著的爆炸板：從底色往亮色內插。⚠ 用「越來越亮」而不是閃爍——閃爍讀不出
	#   還剩多久，而這塊板的威脅正是時間本身（同碎裂平台用 alpha 當剩餘壽命的理由）。
	if kind == Kind.EXPLOSIVE and fuse_timer >= 0.0:
		return SpikeConfig.C_EXPLOSIVE.lerp(
			SpikeConfig.C_EXPLOSIVE_HOT, 1.0 - fuse_ratio()
		)

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
		Kind.EXPLOSIVE:
			return SpikeConfig.C_EXPLOSIVE
		_:
			return SpikeConfig.C_PLATFORM
