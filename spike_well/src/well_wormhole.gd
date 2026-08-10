class_name WellWormhole
extends RefCounted
## 蟲洞（PILLARS_2.md:399）。長在平台上，碰到即傳送，固定送 +40m。
##
## 出口是**一塊實際的平台**，不是一個座標——使用者拍板的守門方式。
## 生成當下上方 40m 的平台通常還沒生出來（世界是邊爬邊串流的），所以出口採
## 「延後綁定」：先記下 target_y，等生成鏈越過那個高度，WellGenerator 再回頭把
## 最接近的平台指派給它。exit_platform 仍是 null 的蟲洞不會被畫出來、也不能踩。

var host: WellPlatform            # 掛在哪塊平台上（跟著它移動）
var offset := Vector2.ZERO
var pos := Vector2.ZERO
var size := Vector2.ZERO
var alive := true

## 出口高度（世界座標 y）。生成時就算好，用來配對出口平台。
var target_y := 0.0
## 出口平台。null = 還沒綁定成功，這個蟲洞此刻不作用。
var exit_platform: WellPlatform = null

## 純表現：讓它看起來在轉
var spin := 0.0


func _init() -> void:
	size = SpikeConfig.WORMHOLE_SIZE


func ready_to_use() -> bool:
	return alive and exit_platform != null and exit_platform.alive


func rect() -> Rect2:
	return Rect2(pos - size * 0.5, size)


func step(delta: float) -> void:
	if host != null:
		pos = host.pos + offset
	spin = fmod(spin + SpikeConfig.WORMHOLE_SPIN_SPEED * delta, TAU)
