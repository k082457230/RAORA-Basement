class_name WellBuffOrb
extends RefCounted
## 開局三選一的增益球（08-12 使用者拍板，SpikeConfig SECTION 8e）。
## 純資料 + 純邏輯，不繪製、不接輸入。
##
## 一局最多存在三顆，全部長在開局那一排固定平台上（關卡二以上）。玩家碰到其中一顆
## ＝選它，另外兩顆進入 exploding 狀態、演完就消失。
##
## ⚠⚠ 爆炸**完全沒有判定**——它跟 WellBlast（爆炸平台）是兩件不同的事，刻意不共用。
##   玩家剛做完一個正向選擇，下一刻被自己沒選的獎勵炸死是最糟的體驗。
##   所以這個 class 沒有 `hits()`，也不要幫它加一個。
##
## ⚠ 綁在母平台上（host + offset）跟物資同一套。開局那排是 STATIC 不會動，所以現在
##   看不出差別——留著是因為「哪天想把三選一擺到會動的板上」時不必再改一次資料結構，
##   而 host 為 null 時的退化行為（留在原地）跟 WellPickup 完全一致。
##
## ⚠ exploding 期間 alive 仍是 true：alive 管的是「還在不在世界上」，判定端要另外看
##   `selectable()`。兩者合一的話爆炸演出會在第一幀就被回收掉，等於沒有演出
##   （同 WellMonster 的 dying／alive 那條教訓）。

var key: String = ""
## 這顆屬於哪一組三選一（0＝開局那組、1＝第三關 1000m 那組，08-13 新增）。
## ⚠ 選中時只爆**同組**的三顆——沒有這個欄位的話，在開局選完會把 1000m 那組一起清掉，
##   而且是無聲的（球直接不見，玩家只會覺得「那一層怎麼沒東西」）。
var group: int = 0
var pos := Vector2.ZERO
var alive: bool = true
var host: WellPlatform = null
var offset := Vector2.ZERO

## 沒被選到的那兩顆：進入爆炸演出，時間到才真的消失。
var exploding: bool = false
var explode_timer: float = 0.0


func rect() -> Rect2:
	return Rect2(pos - SpikeConfig.BUFF_ORB_SIZE * 0.5, SpikeConfig.BUFF_ORB_SIZE)


## 還能不能被選。⚠ 判定端一律問這個，不要直接問 alive——見檔頭的 ⚠。
func selectable() -> bool:
	return alive and not exploding


## 沒選到的那兩顆走這裡。⚠ 不是直接 alive = false：那樣三顆會在同一幀一起消失，
## 玩家看不到「另外兩個爆掉了」這件事，也就無從理解「一局只能選一個」這條規則。
func explode() -> void:
	if exploding:
		return
	exploding = true
	explode_timer = SpikeConfig.BUFF_ORB_EXPLODE_TIME


func step(delta: float) -> void:
	if not alive:
		return
	if host != null and host.alive:
		pos = host.pos + offset
	else:
		host = null
	if exploding:
		explode_timer -= delta
		if explode_timer <= 0.0:
			alive = false


## 爆炸演出進度 0 → 1，給繪製決定半徑與淡出。
func explode_progress() -> float:
	var t: float = SpikeConfig.BUFF_ORB_EXPLODE_TIME
	if t <= 0.0:
		return 1.0
	return clampf(1.0 - explode_timer / t, 0.0, 1.0)
