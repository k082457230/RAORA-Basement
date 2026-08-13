class_name WellMonster
extends RefCounted
## 井裡的怪物。純資料 + 純邏輯，不繪製、不接輸入。兩種（見 Kind）：
##   PATROL   在母平台上左右巡邏，碰到即死、踩頭／鞭子可殺（v7）
##   PAMELOE  懸浮在半空定點不動，每隔一段時間朝 Kaela 射一發子彈（v16）
##
## ⚠⚠ 兩種共用同一個類別、同一個 gen.monsters 陣列，是刻意的：踩頭、鞭子、無敵撞飛、
##   死亡演出、prune 回收這五套判定完全相同，拆成兩個類別等於把每一套都抄第二遍，
##   而且每抄一遍就多一個「只修好其中一邊」的漏接點（v9 的蟲洞就是這樣死的）。
##   差異只有兩處：step() 的移動方式、pameloe 多一個射擊計時器——用 kind 分支即可。
##
## ⚠ 巡邏座標是「相對母平台」的，不是世界座標。平台會左右移動／上下移動／繞圈，
##   用世界座標巡邏的話怪物會被平台丟在後面，變成半空中踩不到的障礙物——
##   那正是 PILLARS「踩頭必須永遠可行」要防的運氣牆（見 MONSTER_PATROL_RANGE 註解）。
##   母平台消失後怪物就停在原地，不再跟隨。
##   ⚠ PAMELOE 沒有 host、本來就用世界座標，這條不管牠——牠是定點懸浮，
##     不會被平台丟下，玩家跳上鄰近平台就一定踩得到牠。

enum Kind { PATROL, PAMELOE }

var kind: int = Kind.PATROL
var pos: Vector2
var size: Vector2
var alive: bool = true
var host: WellPlatform = null
var local_x: float = 0.0          # 相對母平台中心的水平偏移
var local_min: float = 0.0
var local_max: float = 0.0
var _dir: float = 1.0

## --- 暈眩（08-13 使用者改規格：鞭子命中不再當場擊殺）---
## 鞭子纏中的怪物先進入這個狀態：**停止一切行動**（不巡邏、不漂浮、不開火、雷射立刻關掉）
## 而且**不再傷人**，要等玩家真的碰到牠才演死亡動畫（見 WellWorld._check_hazards）。
## ⚠⚠ 跟 dying 不同：暈眩期間 alive 仍是 true——牠還在世界上、還佔著位置、還畫得出來，
##   只是變成一個安全的、可以踩過去的東西。用 alive = false 表示暈眩會讓牠從所有迴圈裡
##   消失（包含玩家碰撞判定），那樣「碰到才死」這條規格根本觸發不了。
## ⚠ 沒有計時器：使用者規格是「暫停所有行動，等玩家碰到」，沒有自己醒過來這回事。
##   玩家不去碰就一直暈著（然後隨相機捲離被 prune 掉）。
var stunned: bool = false

## --- 死亡演出（v12）---
## ⚠ dying 期間 alive 已經是 false：不撞人、鞭子纏不到、踩不到。純粹是還在畫面上演完。
##   兩個旗標分開的理由——用 alive 兼任「還在演」會讓每一處判定都得多一個例外。
var dying: bool = false
var death_timer: float = 0.0
var death_vel := Vector2.ZERO
var spin: float = 0.0
var spin_speed: float = 0.0

## --- Pameloe 專用（v16）---
## 距離下一發還有多久。生成時灌 PAMELOE_FIRE_FIRST_DELAY 而不是 0，玩家才不會
## 在牠一進畫面的同一幀就吃到子彈。
var fire_timer: float = 0.0

## 用哪一張立繪：0＝pameloe1（80%，發子彈）、1＝pameloe2（20%，雷射變體，見下方）。
## ⚠⚠ 在生成當下由 WellGenerator 的 seeded rng 骰一次就定死，**不准在繪製時骰**——
##   _draw() 每幀都跑，在那裡骰等於兩張圖以 60fps 互閃。用 gen 的 rng 而不是
##   randf() 也是刻意的：同一顆 seed 要能重現同一座井的每一個細節（榜單審核的前置，
##   見 SpikeSave.last_run_seed）。
## ⚠ 08-10 三訂起這顆**不再只是表現**：art_variant == 1 的這隻開火時走雷射分支
##   （WellWorld._fire_pameloe_shots），不是發子彈——換圖時如果順序或索引搞錯，
##   兩張立繪的攻擊方式會直接對調。
var art_variant: int = 0

## --- Pameloe 雷射變體（08-10 三訂／四訂，使用者拍板）---
## art_variant == 1 開火時不生 PameloeShot，改點亮這道雷射：固定 PAMELOE_LASER_DURATION
## 秒，期間持續可以殺人。
## ⚠ 08-10 四訂：方向鎖定點從「開火瞬間」提前到「充能起點」（見 lock_laser_aim 的 ⚠⚠）——
##   真人回報充能整段看不到要往哪打，等於沒有預警，玩家只能憑直覺跑。
var laser_active: bool = false
var laser_timer: float = 0.0
var laser_dir := Vector2.RIGHT      # 充能起點鎖定，單位向量，見 lock_laser_aim
var laser_dir_locked: bool = false  # 這次充能週期方向鎖了沒，見 lock_laser_aim／hold_fire

## --- 漂浮（08-10，只有 PAMELOE 用）---
## ⚠⚠ 判定**跟著晃**：pos.y 每幀在 step() 裡重算，而 rect() 讀的就是 pos ⇒ 視覺與判定
##   天生同步。刻意不像金幣／燃料那樣做在繪製端——牠碰到即死，致命物的視覺與判定一旦
##   分離就是不可歸因的死法（常青認知第 8 條⑤才剛在怪物判定框上踩過）。
## ⚠ float_base_y 是「沒有晃動時的高度」，由 WellGenerator 灌入；pos.y 是它加上當下的
##   正弦位移。要問「牠原本掛在哪」一律讀 float_base_y，不要讀 pos.y。
var float_phase: float = 0.0
var float_base_y: float = 0.0
var _float_t: float = 0.0


func _init() -> void:
	# 在 _init() 指派，避免成員初始化式引用 autoload 的時序問題。
	size = SpikeConfig.MONSTER_SIZE


## 種類的唯一設定入口——尺寸與射擊計時器都綁在這裡。
## ⚠ 不要在外面直接寫 m.kind = ...，那樣 pameloe 會頂著怪物的尺寸、而且永遠不開火。
func set_kind(k: int) -> void:
	kind = k
	if k == Kind.PAMELOE:
		size = SpikeConfig.PAMELOE_SIZE
		fire_timer = SpikeConfig.PAMELOE_FIRE_FIRST_DELAY
	else:
		size = SpikeConfig.MONSTER_SIZE
		fire_timer = 0.0


## ⚠ PATROL 判定框不是 `pos` 置中——`pos` 是「碰撞框底邊貼平台上緣」的腳底錨點
##   （見 step()／WellGenerator._make_monster），畫貼圖時另外量出視覺（art）位置。
##   踩頭手感修正（08-10）：判定框改成對齊 art 的視覺中心而不是貼平台，見
##   SpikeConfig.MONSTER_HITBOX_CENTER_OFFSET_Y 註解的推導。PAMELOE 懸浮、沒有腳底
##   這條基準線，維持原本的 pos 置中。
func rect() -> Rect2:
	if kind == Kind.PATROL:
		var center_y := pos.y + size.y * 0.5 - SpikeConfig.MONSTER_HITBOX_CENTER_OFFSET_Y
		return Rect2(Vector2(pos.x - size.x * 0.5, center_y - size.y * 0.5), size)
	return Rect2(pos - size * 0.5, size)


## 面向，給 WellWorld 畫貼圖時鏡像用。1.0＝面右、-1.0＝面左。
## PATROL：巡邏方向。PAMELOE：上一次開火鎖定的方向（見 face_toward）。
func facing() -> float:
	return _dir


## 殺掉牠：立刻退出所有判定，改成往 dir_x 方向拋物線飛出去。
## dir_x 由呼叫端給（一律是「遠離玩家」的方向），0 視為往右。
## ⚠ 一律走這個函式，不要在外面直接寫 m.alive = false——那樣屍體會原地消失。
## ⚠ 順手關掉雷射（laser_active = false）：殺掉正在發雷射的 pameloe 就該立刻掐斷
##   威脅，跟子彈「發射出去就跟牠脫鉤，死了也照常飛完」是刻意不同的兩條規則，
##   理由見 laser_hits() 的 ⚠。
func kill(dir_x: float) -> void:
	if dying:
		return
	alive = false
	dying = true
	laser_active = false          # 見上方 ⚠：雷射跟本體一起關掉，不是脫鉤飛完
	host = null                   # 脫離母平台，否則 step() 會把牠拉回平台上方
	death_timer = SpikeConfig.MONSTER_DEATH_TIME
	var sx: float = 1.0 if dir_x >= 0.0 else -1.0
	death_vel = Vector2(sx * SpikeConfig.MONSTER_DEATH_VX, -SpikeConfig.MONSTER_DEATH_VY)
	spin_speed = sx * SpikeConfig.MONSTER_DEATH_SPIN


## 鞭子纏中：暈眩。⚠ 雷射跟 kill() 一樣立刻關掉——牠已經不動了，卻還有一道會殺人的
## 光在原地掃，那是玩家完全讀不懂的狀態。已射出的子彈仍照常飛完（跟 kill() 同一條規則）。
func stun() -> void:
	if dying or not alive:
		return
	stunned = true
	laser_active = false


## 演完了，可以從陣列裡拿掉（由 WellGenerator.prune_below 回收）
func expired() -> bool:
	return dying and death_timer <= 0.0


## 死亡演出的淡出比例（1 → 0）
func death_alpha() -> float:
	if not dying:
		return 1.0
	return clampf(death_timer / SpikeConfig.MONSTER_DEATH_TIME, 0.0, 1.0)


## 這一幀要不要開火。回 true 的同時就把計時器重置，所以呼叫端每幀只能問一次。
## ⚠ 做成「問一次就重置」而不是「查旗標＋另外呼叫 reset」，是因為兩段式一定會有某條
##   路徑忘記重置 —— 那會變成每幀一發的彈幕，而且不會有任何錯誤訊息。
## ⚠ dying 期間 alive 已經是 false，所以死掉的 pameloe 不會再開火；牠已射出的子彈
##   仍會照常飛完（子彈不掛在牠身上，見 WellWorld._shots）。
func take_shot() -> bool:
	if kind != Kind.PAMELOE or not alive or stunned:
		return false
	if fire_timer > 0.0:
		return false
	fire_timer = SpikeConfig.PAMELOE_FIRE_INTERVAL
	laser_dir_locked = false
	return true


## 在畫面外時把計時器頂到「初見寬限」。
## ⚠ 沒有這一條的話，畫面外的 pameloe 計時器會一路跑到負值，玩家一把牠捲進畫面
##   牠就在同一幀開火——連 PAMELOE_CHARGE_TIME 的充能閃爍都看不到，等於沒有預告。
##   呼叫端見 WellWorld._fire_pameloe_shots。
## ⚠ 08-12 使用者拍板：頂的值從 PAMELOE_CHARGE_TIME（0.45s）換成 PAMELOE_FIRE_SIGHT_DELAY
##   （3.0s）——原本「一進畫面 0.45s 就吃子彈」太急，玩家還沒看清楚牠在哪。之後的節奏
##   仍是 PAMELOE_FIRE_INTERVAL，這裡只寬容第一發。取捨見該常數的 ⚠。
## ⚠ 順手清掉 laser_dir_locked：畫面外可能停留很久，玩家位置早就變了，重新進畫面
##   要在下一次充能起點重鎖，不能沿用離場前鎖住的舊方向。
func hold_fire() -> void:
	if kind == Kind.PAMELOE:
		fire_timer = maxf(fire_timer, SpikeConfig.PAMELOE_FIRE_SIGHT_DELAY)
		laser_dir_locked = false


## 發射前的充能程度（0＝還早，1＝就要射了）。純表現，給繪製決定閃爍強度。
func charge_ratio() -> float:
	if kind != Kind.PAMELOE or not alive:
		return 0.0
	var t: float = SpikeConfig.PAMELOE_CHARGE_TIME
	if t <= 0.0 or fire_timer > t:
		return 0.0
	return clampf(1.0 - fire_timer / t, 0.0, 1.0)


## 開火瞬間依方向鏡像面向（08-10 二訂，使用者拍板：PEMALOE 發射子彈／雷射時依方向翻轉）。
## ⚠ 沿用巡邏怪共用的 `_dir`／`facing()`：PAMELOE 平常不巡邏，`_dir` 原本停在初始值
##   1.0 從沒被動過，畫貼圖那端（_draw_pameloe）本來就讀 facing() 決定要不要鏡像，
##   兩種怪物繼續共用同一套，不新開一個平行欄位。
func face_toward(dx: float) -> void:
	if dx != 0.0:
		_dir = 1.0 if dx >= 0.0 else -1.0


## 雷射瞄準方向在充能「起點」鎖定（08-10 四訂，使用者拍板）。跟舊版「開火瞬間鎖定」的
## 差別：舊版充能全程玩家看不到要往哪打，等於沒有預警；現在鎖點提前到 charge_ratio()
## 剛轉正的那一刻，充能閃爍的整段時間畫面上都能看到瞄準線（見 WellWorld._draw_pameloe_lasers
## 讀 charge_ratio() 畫預警線那段），才有得躲。之後跟子彈同一條「鎖方向、之後不追蹤」
## 原則——玩家怎麼移動都不會讓雷射轉向。
## ⚠ 順手翻鏡像：瞄準線跟本體朝向要同時翻，不能瞄準線畫一個方向、貼圖翻另一個方向。
func lock_laser_aim(dir: Vector2) -> void:
	laser_dir = dir
	laser_dir_locked = true
	face_toward(dir.x)


## 點亮雷射（art_variant == 1 專用）。方向已經在充能起點由 lock_laser_aim 鎖定，這裡只
## 負責啟動計時器，不重算/覆蓋方向。
func start_laser() -> void:
	laser_active = true
	laser_timer = SpikeConfig.PAMELOE_LASER_DURATION


## 雷射另一端：從 pos 沿 laser_dir 打到井壁（跟子彈碰壁消失同一片牆）。近乎垂直角度
## （水平分量趨近 0）打不到牆，用 PAMELOE_LASER_MAX_LEN 頂住，見該常數的 ⚠。
func laser_endpoint() -> Vector2:
	var dx: float = laser_dir.x
	if absf(dx) < 0.001:
		return pos + laser_dir * SpikeConfig.PAMELOE_LASER_MAX_LEN
	var wall: float = SpikeConfig.WELL_LEFT if dx < 0.0 else SpikeConfig.WELL_RIGHT
	var t: float = clampf((wall - pos.x) / dx, 0.0, SpikeConfig.PAMELOE_LASER_MAX_LEN)
	return pos + laser_dir * t


## 這一點在不在雷射的致命範圍內。用點到線段距離，粗細讀 PAMELOE_LASER_HIT_WIDTH
## （刻意小於視覺，同子彈的理由：判定寧可鬆給玩家）。
## ⚠ 呼叫端要自己先檢查 alive——本體被踩死之後雷射跟著關掉是刻意的（跟子彈「發射出去
##   就跟牠脫鉤」相反）：雷射狀態掛在牠身上，殺掉牠就是玩家主動掐斷威脅的手段。
func laser_hits(point: Vector2) -> bool:
	if not laser_active:
		return false
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, pos, laser_endpoint())
	return point.distance_to(closest) <= SpikeConfig.PAMELOE_LASER_HIT_WIDTH * 0.5


func step(delta: float) -> void:
	# 暈眩：停住一切（連 pameloe 的漂浮與射擊計時器都不推進）。⚠ 擋在 dying 之後——
	# 已經在演死亡動畫的屍體要繼續演完，那跟「行動」是兩回事。
	if stunned and not dying:
		return
	if dying:
		death_timer -= delta
		death_vel.y += SpikeConfig.MONSTER_DEATH_GRAVITY * delta
		pos += death_vel * delta
		spin = fmod(spin + spin_speed * delta, TAU)
		return

	# Pameloe：定點懸浮，不巡邏也不跟隨平台（牠根本沒有 host）。推進射擊計時器 ＋ 漂浮。
	# ⚠ 漂浮改的是 pos.y 本身而不是繪製偏移，rect() 因此自動跟著走（見 float_phase 的 ⚠⚠）。
	if kind == Kind.PAMELOE:
		fire_timer -= delta
		if laser_active:
			laser_timer -= delta
			if laser_timer <= 0.0:
				laser_active = false
		_float_t += delta
		pos.y = float_base_y + sin(
			_float_t * SpikeConfig.PAMELOE_FLOAT_SPEED + float_phase
		) * SpikeConfig.PAMELOE_FLOAT_AMP
		return

	local_x += SpikeConfig.MONSTER_PATROL_SPEED * _dir * delta
	if local_x >= local_max:
		local_x = local_max
		_dir = -1.0
	elif local_x <= local_min:
		local_x = local_min
		_dir = 1.0

	if host != null and host.alive:
		pos = Vector2(host.pos.x + local_x, host.top_y() - size.y * 0.5)
	else:
		host = null
