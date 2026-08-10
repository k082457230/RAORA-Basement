class_name Whip
extends RefCounted
## 射線鞭子（PILLARS P4：砍掉拋物線，改瞬間射線）。
##
## 流程：Q → 瞄準（時間放慢，3 真實秒）→ 左鍵射出 → 射線取樣找到路徑上第一個標的
##      → 纏住並「加速」拉過去 → 玩家超過錨點才恢復操作。
##
## 次數規則：射出去就扣（命中或落空都扣，落空扣次數是 PILLARS 明文）。
##          瞄準逾時或主動取消「不扣」——按錯 Q 不該直接吃掉資源。

enum State { IDLE, AIMING, PULLING }

var state: int = State.IDLE
var charges: int = 0
## 本局的次數上限。吃永久升級，所以不是常數——結算的「用了幾次」要拿它當分母。
var max_charges: int = 0
var aim_time_left := 0.0          # 真實秒，不受慢動作影響
var aim_dir := Vector2.UP

var anchor := Vector2.ZERO
var anchor_kind := ""             # "platform" / "wall" / "monster"

## 落空／命中後的繩子殘影，純表現用
var rope_from := Vector2.ZERO
var rope_to := Vector2.ZERO
var rope_flash := 0.0
var rope_hit := false


func reset() -> void:
	state = State.IDLE
	max_charges = SpikeSave.whip_charges()
	charges = max_charges
	aim_time_left = 0.0
	rope_flash = 0.0


func used() -> int:
	return max_charges - charges


func can_aim() -> bool:
	return state == State.IDLE and charges > 0


func start_aim() -> void:
	state = State.AIMING
	aim_time_left = SpikeConfig.WHIP_AIM_DURATION


func cancel_aim() -> void:
	state = State.IDLE
	aim_time_left = 0.0


## real_delta 必須是「真實秒」（呼叫端要自己除掉 Engine.time_scale）
## 回傳 true 表示瞄準窗到期，呼叫端要收慢動作
func tick_aim(real_delta: float, dir: Vector2) -> bool:
	if dir.length_squared() > 0.0:
		aim_dir = dir.normalized()
	aim_time_left -= real_delta
	if aim_time_left <= 0.0:
		cancel_aim()
		return true
	return false


func aim_ratio() -> float:
	return clampf(aim_time_left / SpikeConfig.WHIP_AIM_DURATION, 0.0, 1.0)


## 射出。回傳結果字典：{"hit": bool, "point": Vector2, "kind": String, "obj": Object}
## 呼叫端負責：命中 → player.start_pull(point)；落空 → 什麼都不做（次數已扣）
func fire(origin: Vector2, platforms: Array, monsters: Array) -> Dictionary:
	charges -= 1
	state = State.IDLE
	var res := _raycast(origin, aim_dir, platforms, monsters)

	rope_from = origin
	rope_to = res["point"]
	rope_hit = res["hit"]
	rope_flash = 0.25

	if res["hit"]:
		anchor = res["point"]
		anchor_kind = res["kind"]
		state = State.PULLING
		# 鞭中怪物 = 擊退（怪物直接除去），但仍纏住該點把玩家拉過去。
		# 這是把 PILLARS 的「擊退」與使用者要求的「怪物也是可纏標的」兩者合併。
		# 飛出去的方向＝鞭子射出的方向（順著這一鞭把牠掃開）。
		# ⚠ 這條路徑**不退鞭子次數**（見 SpikeConfig 的 MONSTER_KILL_WHIP_REFUND_CHANCE）：
		#   鞭子殺怪再退鞭子會變成自我循環。
		if res["kind"] == "monster" and res["obj"] != null:
			res["obj"].kill(aim_dir.x)
	return res


## 踩頭／撞飛殺怪的機率回饋（見 SpikeConfig.MONSTER_KILL_WHIP_REFUND_CHANCE）。
## 回傳是否真的補到——已經滿了就不補，也不該讓 UI 跳出「+1」。
func refund() -> bool:
	if charges >= max_charges:
		return false
	charges += 1
	return true


func end_pull() -> void:
	if state == State.PULLING:
		state = State.IDLE


func tick_visual(delta: float) -> void:
	if rope_flash > 0.0:
		rope_flash = maxf(0.0, rope_flash - delta)


## 沿方向等距取樣，回報路徑上第一個碰到的東西。
## 用取樣而非解析求交：標的有三種形狀來源（矩形平台、矩形怪物、井壁半平面），
## 取樣的程式碼量與出錯面都遠小於三套解析式，而 6px 步長對這個尺度已足夠精準。
func _raycast(origin: Vector2, dir: Vector2, platforms: Array, monsters: Array) -> Dictionary:
	var miss := {
		"hit": false,
		"point": origin + dir * SpikeConfig.WHIP_RANGE,
		"kind": "",
		"obj": null,
	}
	if dir.length_squared() <= 0.0:
		return miss

	var steps := int(SpikeConfig.WHIP_RANGE / SpikeConfig.WHIP_RAY_STEP)
	for i in range(1, steps + 1):
		var p: Vector2 = origin + dir * (float(i) * SpikeConfig.WHIP_RAY_STEP)

		if p.x <= SpikeConfig.WELL_LEFT or p.x >= SpikeConfig.WELL_RIGHT:
			return {"hit": true, "point": p, "kind": "wall", "obj": null}

		for m in monsters:
			if m.alive and m.rect().has_point(p):
				return {"hit": true, "point": p, "kind": "monster", "obj": m}

		for pl in platforms:
			if pl.alive and pl.rect().has_point(p):
				return {"hit": true, "point": p, "kind": "platform", "obj": pl}

	return miss
