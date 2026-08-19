class_name WellPickup
extends RefCounted
## 長在平台上的物資。純資料 + 純邏輯，不繪製、不接輸入。
##
## 四種：COIN（金幣，跨局累計買升級）、FUEL（jetpack 燃料補給，只在 300m 以上出現）、
## TOMB（墓碑，長在歷史最高高度那塊板上，一局最多一個，碰到給一大筆金幣）、
## LOOT_BAG（卡包，08-13x 關卡三限定，碰到觸發金幣雨——見 WellWorld._start_loot_rain）。
## 同一塊平台只會有一個——四者都掛在平台正上方同一個位置，放兩個會疊在一起。
##
## 綁在母平台上（host + offset），母平台左右移動／上下移動／繞圈時物資跟著走，
## 不會浮在半空。母平台碎掉或被 Raora 抽走時，物資「脫離但留在原地」——
## 踩碎跳板已經是一次懲罰，連物資一起沒收是第二次，不划算。

enum Kind { COIN, FUEL, TOMB, LOOT_BAG }

var kind: int = Kind.COIN
var pos := Vector2.ZERO
var size := Vector2.ZERO
var alive: bool = true
var host: WellPlatform = null
var offset := Vector2.ZERO

## 漂浮的起始相位（rad，08-10）。
## ⚠⚠ 只影響**繪製**，`rect()` 完全不看它——金幣／燃料是撿取物，判定不跟著晃，
##   誤差方向刻意倒向「還沒碰到就撿到」。完整理由見 SpikeConfig 漂浮那組的 ⚠⚠。
## ⚠ 在生成當下由 WellGenerator 的 seeded rng 骰一次就定死：不骰的話整排物資會同步
##   上下擺、看起來像機械故障；在繪製時骰則是每幀跳一次。
## ⚠ 墓碑（TOMB）不吃這個——它是立在平台上的石碑，不是漂浮物（見 WellWorld._draw）。
var float_phase: float = 0.0


func _init() -> void:
	# 在 _init() 指派，避免成員初始化式引用 autoload 的時序問題。
	size = SpikeConfig.PICKUP_SIZE


## kind 決定尺寸，所以設 kind 一律走這個函式，不要直接指派欄位
func set_kind(k: int) -> void:
	kind = k
	match k:
		Kind.FUEL:
			size = SpikeConfig.FUEL_PICKUP_SIZE
		Kind.TOMB:
			size = SpikeConfig.TOMB_SIZE
		Kind.LOOT_BAG:
			size = SpikeConfig.LOOT_BAG_SIZE
		_:
			size = SpikeConfig.PICKUP_SIZE


func rect() -> Rect2:
	return Rect2(pos - size * 0.5, size)


func step(_delta: float) -> void:
	if host != null and host.alive:
		pos = host.pos + offset
	else:
		host = null
