class_name WellBlast
extends RefCounted
## 爆炸平台炸開後留下的圓形爆炸區（08-10）。純資料 + 純邏輯，不繪製、不接輸入。
##
## ⚠⚠ 為什麼要獨立成一個實體，而不是掛在平台身上：平台在爆炸的**同一刻** alive = false，
##   之後隨時可能被 `WellGenerator.prune_below` 回收掉。把爆炸狀態留在平台上等於
##   「爆炸會不會演完」取決於相機那一刻捲到哪裡——那是機率性的失效，而且不會有錯誤訊息
##   （v9 的蟲洞就是這樣整條死掉的，見 ../HANDOFF.md 常青認知第 4 條）。
##
## ⚠ 判定用**圓**不用矩形：它畫成圓，矩形會多出四個「看起來在圓外卻死」的角落
##   （同黑洞那條，見 SpikeConfig 的 DOOM 註解）。
##
## ⚠ 生命週期只有一個出口：`step()` 把 timer 減到 0 就 alive = false，由 WellWorld 統一
##   清掉。不要在判定端順手把它設成 false——那會讓「碰到一次就消失」，但爆炸是範圍事件，
##   同一次爆炸本來就該同時威脅到所有進到範圍裡的東西。

var pos := Vector2.ZERO
var timer: float = 0.0
var alive: bool = true


func _init(at: Vector2 = Vector2.ZERO) -> void:
	pos = at
	timer = SpikeConfig.EXPLOSIVE_BLAST_TIME


func step(delta: float) -> void:
	if not alive:
		return
	timer -= delta
	if timer <= 0.0:
		alive = false


## 這一點在不在致命範圍內。⚠ 用圓心距離，理由見檔頭。
func hits(p: Vector2) -> bool:
	return alive and pos.distance_to(p) <= SpikeConfig.EXPLOSIVE_RADIUS


## 演出進度 0 → 1。半徑與亮度都吃它，所以爆炸是「炸開」不是「一個圓憑空出現又消失」。
## ⚠ 致命半徑**不吃這個值**（`hits()` 一律用 EXPLOSIVE_RADIUS 全開）：視覺上還在擴張的
##   那幾幀如果判定比較小，玩家會看到「明明碰到火球卻沒事」，下一次就會賭同一件事然後死。
##   判定寧可從第一幀就全開——它有 2 秒的引信當預告，不需要再靠判定縮水來補償。
func progress() -> float:
	var t: float = SpikeConfig.EXPLOSIVE_BLAST_TIME
	if t <= 0.0:
		return 1.0
	return clampf(1.0 - timer / t, 0.0, 1.0)
