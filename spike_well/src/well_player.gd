class_name WellPlayer
extends RefCounted
## 玩家的狀態容器。純資料 + 小工具，不做輸入、不做繪製。
## 速度刻意拆成三條：
##   control_vel_x — 滑鼠／鍵盤驅動，玩家能直接控制
##   shock_vel_x   — Raora 側風陣風累積，玩家控制「抵銷不掉」
##   doom_vel      — 黑洞吸力（2D，v13），同樣抵銷不掉
## 拆開的理由：若干擾直接加進同一條速度，下一幀控制器會把它洗掉，干擾就完全無感。
## 分開之後它們才真的能把玩家推走／吸走。
## ⚠ doom_vel 是**二維**的（黑洞會往上下左右吸），所以它同時進 total_vel_x() 與
##   垂直位移（見 WellWorld._step_player）——不要只接一半。

enum State { NORMAL, WHIP_PULL }

var pos := Vector2.ZERO
var size := Vector2.ZERO

var control_vel_x := 0.0
var shock_vel_x := 0.0
var doom_vel := Vector2.ZERO      # 黑洞吸力，見檔頭 ⚠
var vel_y := 0.0

var state: int = State.NORMAL

# --- jetpack ---
var jetpack_fuel_px := 0.0
var jetpack_hold := 0.0          # 按住多久（用來走 0.2s 冷啟動，SpikeConfig.JETPACK_SPOOL_TIME）
var jetpack_on := false
## 08-10 使用者拍板：上一段噴射結束後的強制間隔（SpikeConfig.JETPACK_COOLDOWN）。
## ⚠ 跟 jetpack_hold／JETPACK_SPOOL_TIME 是兩件事——那顆管「按下去到噴出來」，
##   這顆管「噴完到能再按」，見 WellWorld._step_jetpack 的判斷順序。
var jetpack_cooldown_timer := 0.0

# --- 無敵窗（鞭子命中拉扯中／彈射板起飛／蟲洞過場，以及結束後 INVULN_GRACE 秒的餘韻）---
## 兩個來源在「進行中」是每幀重置這個計時器，所以結束的那一刻它才開始真的倒數，
## 「過程 ~ 結束後 0.5s」這條規格自然成立，不用另外記狀態。
var invuln_timer := 0.0

## jetpack 專屬的無敵窗，08-10 使用者拍板改窄成 SpikeConfig.JETPACK_INVULN_GRACE（0.2s）。
## ⚠ 跟上面 invuln_timer 分開算，不是同一顆常數兩種用法——鞭子／彈射板／蟲洞過場的餘韻
##   仍是 0.5s，只有 jetpack 變短，所以拆成兩顆計時器（見 is_invulnerable() 的 or）。
var jetpack_invuln_timer := 0.0

## 落地閃現：碰到平台那一刻起倒數 SpikeConfig.LAND_FLASH_TIME，>0 期間畫面用 steady 姿勢，
## 歸零後回到一般 airborne 姿勢。純表現用，不影響任何判定。
var land_flash_timer := 0.0

## 貼圖朝向（1 = 右、-1 = 左）。純表現用，不影響任何判定。
## ⚠ 記的是「最後一次有輸入意圖的方向」而不是 sign(control_vel_x)：放開按鍵後速度會
##   衰減到 0、被側風／黑洞推著走時速度方向也不是玩家的意圖，跟著速度走會讓角色
##   在原地反覆翻面。
var facing := 1.0

## 彈射板無敵：踩到彈射板起飛的那一段（使用者要求：彈起來時同樣能撞飛怪物）。
## 理由跟鞭子／jetpack 同一條——初速 2.1 倍的上升弧完全不受操作影響，
## 此時判傷害等於懲罰玩家踩了系統自己放的加速元件。
## 解除時機：下一次踩到「非彈射板」的平台（連踩彈射板則持續），之後還有 INVULN_GRACE 餘韻。
var launch_invuln := false

## 攀爬（特殊裝備）這次離地用掉了沒。落地／傳送時重置。
## ⚠ 沒有這個旗標，攀爬會在頂點窗裡每幀重複觸發＝無限爬升。
var ledge_used := false

# --- 被鞭子拖曳中 ---
var pull_anchor := Vector2.ZERO
var pull_dir := Vector2.ZERO
var pull_speed := 0.0
var pull_timer := 0.0


func _init() -> void:
	size = SpikeConfig.PLAYER_SIZE
	reset(Vector2.ZERO)


func reset(spawn_pos: Vector2) -> void:
	pos = spawn_pos
	control_vel_x = 0.0
	shock_vel_x = 0.0
	doom_vel = Vector2.ZERO
	vel_y = 0.0
	state = State.NORMAL
	# 燃料上限吃永久升級（見 SpikeSave 的警語：只有玩家端的數值吃升級，生成器不吃）
	jetpack_fuel_px = SpikeSave.jetpack_fuel_px()
	jetpack_hold = 0.0
	jetpack_on = false
	jetpack_cooldown_timer = 0.0
	invuln_timer = 0.0
	jetpack_invuln_timer = 0.0
	land_flash_timer = 0.0
	facing = 1.0
	launch_invuln = false
	ledge_used = false
	pull_timer = 0.0
	pull_speed = 0.0


func rect() -> Rect2:
	return Rect2(pos - size * 0.5, size)


func total_vel_x() -> float:
	return control_vel_x + shock_vel_x + doom_vel.x


func bottom() -> float:
	return pos.y + size.y * 0.5


## 無敵中：免傷，而且撞到的怪物會被撞飛（判定在 WellWorld._check_hazards）
## ⚠ 兩顆計時器任一顆 > 0 都算無敵——jetpack 走自己的窄窗，其他三個來源走共用的寬窗。
func is_invulnerable() -> bool:
	return invuln_timer > 0.0 or jetpack_invuln_timer > 0.0


## 進行中的來源每幀呼叫這個把窗口頂滿；停下後才開始倒數。
func refresh_invuln() -> void:
	invuln_timer = SpikeConfig.INVULN_GRACE


## jetpack 專屬版本，見 jetpack_invuln_timer 的 ⚠。
func refresh_jetpack_invuln() -> void:
	jetpack_invuln_timer = SpikeConfig.JETPACK_INVULN_GRACE


func tick_invuln(delta: float) -> void:
	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)
	if jetpack_invuln_timer > 0.0:
		jetpack_invuln_timer = maxf(0.0, jetpack_invuln_timer - delta)


## 上一段噴射結束後的強制冷卻，見 jetpack_cooldown_timer 的 ⚠。
func tick_jetpack_cooldown(delta: float) -> void:
	if jetpack_cooldown_timer > 0.0:
		jetpack_cooldown_timer = maxf(0.0, jetpack_cooldown_timer - delta)


func trigger_land_flash() -> void:
	land_flash_timer = SpikeConfig.LAND_FLASH_TIME


func tick_land_flash(delta: float) -> void:
	if land_flash_timer > 0.0:
		land_flash_timer = maxf(0.0, land_flash_timer - delta)


func jetpack_ratio() -> float:
	var full := SpikeSave.jetpack_fuel_px()
	if full <= 0.0:
		return 0.0
	return clampf(jetpack_fuel_px / full, 0.0, 1.0)


## 燃料補給：固定補 SpikeConfig.FUEL_PICKUP_REFILL_METERS 公尺（使用者拍板定值，
## 不再跟著燃料上限的升級放大）。回傳 true 表示真的補到了
## （已經滿載時回 false，呼叫端就不要把補給消耗掉）。
func refill_fuel() -> bool:
	var full := SpikeSave.jetpack_fuel_px()
	if jetpack_fuel_px >= full:
		return false
	var refill_px := SpikeConfig.FUEL_PICKUP_REFILL_METERS * SpikeConfig.PIXELS_PER_METER
	jetpack_fuel_px = minf(full, jetpack_fuel_px + refill_px)
	return true


## 被鞭子拖曳時，滑鼠與重力全部讓位（使用者明確要求：兩股力不可互相打架）
func is_pulled() -> bool:
	return state == State.WHIP_PULL


func start_pull(anchor: Vector2) -> void:
	state = State.WHIP_PULL
	pull_anchor = anchor
	pull_dir = (anchor - pos).normalized()
	pull_timer = 0.0
	# 起始速度取「現有速度在拉扯方向上的分量」，避免瞬間急停造成頓挫
	var cur := Vector2(total_vel_x(), vel_y)
	pull_speed = maxf(cur.dot(pull_dir), 0.0)


## 通過錨點才還控制權。回傳 true 表示這一幀結束拖曳。
func step_pull(delta: float) -> bool:
	pull_timer += delta
	pull_speed = minf(
		pull_speed + SpikeConfig.WHIP_PULL_ACCEL * delta,
		SpikeConfig.WHIP_PULL_MAX_SPEED
	)
	pos += pull_dir * pull_speed * delta

	var passed_anchor := (pos - pull_anchor).dot(pull_dir) >= 0.0
	var timed_out := pull_timer >= SpikeConfig.WHIP_PULL_TIMEOUT
	if passed_anchor or timed_out:
		_release_pull()
		return true
	return false


## 中止拖曳並清掉出場慣性。⚠ 目前唯一的呼叫端是開發者傳送（WellWorld.dev_teleport_up）：
##   人被瞬間搬走之後，錨點與拉扯方向講的都是傳送前那個世界，留著會把人往回拽。
##   正常遊戲流程不會用到它——一般的拖曳結束一律走 step_pull ⇒ _release_pull 那條，
##   那條要保留慣性（使用者明確要求的手感），這個函式不保留，兩者不要互相取代。
func abort_pull() -> void:
	if not is_pulled():
		return
	state = State.NORMAL
	pull_speed = 0.0
	pull_timer = 0.0
	control_vel_x = 0.0
	vel_y = 0.0


func _release_pull() -> void:
	state = State.NORMAL
	var exit_vel := pull_dir * pull_speed * SpikeConfig.WHIP_EXIT_SPEED_KEEP
	# 交棒給一般移動：把慣性交回 control_vel_x，滑鼠得「把它拉回來」才停得住
	control_vel_x = exit_vel.x
	vel_y = exit_vel.y
	pull_speed = 0.0
