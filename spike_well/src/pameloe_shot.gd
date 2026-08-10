class_name PameloeShot
extends RefCounted
## Pameloe 射出的子彈（v16）。純資料 + 純邏輯，不繪製、不判傷害。
##
## ⚠ 方向在**發射的那一瞬間**就鎖定 Kaela 當下位置，之後直線飛、不追蹤。
##   這跟投擲物落點預警是同一條原則：會追蹤的威脅等於假動作，玩家閃了也沒用。
## ⚠ 穿透平台（使用者拍板）：不對 gen.platforms 做任何判定，所以躲在板子下面沒有用，
##   要靠水平移動閃。碰到井壁才消失。
## ⚠ 判定框刻意小於視覺（PAMELOE_SHOT_HIT_SIZE < PAMELOE_SHOT_SIZE），理由同投擲物：
##   「看起來閃過了卻死」是不可歸因的死法，寧可鬆給玩家。

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var alive := true


func rect() -> Rect2:
	return Rect2(
		pos - SpikeConfig.PAMELOE_SHOT_HIT_SIZE * 0.5, SpikeConfig.PAMELOE_SHOT_HIT_SIZE
	)


## 前進一幀。碰到井壁就死。
## ⚠ 用視覺半徑而不是判定半徑去測牆：判定框較小，用它測會讓子彈「一半埋進牆裡才消失」。
func step(delta: float) -> void:
	pos += vel * delta
	var half: float = SpikeConfig.PAMELOE_SHOT_SIZE.x * 0.5
	if pos.x - half <= SpikeConfig.WELL_LEFT or pos.x + half >= SpikeConfig.WELL_RIGHT:
		alive = false
