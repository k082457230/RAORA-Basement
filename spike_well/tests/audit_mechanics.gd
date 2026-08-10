extends Node
## 機制稽核：無敵窗、彈射無敵、蟲洞傳送、燃料補給、攀爬手套、投擲物預警、怪物死亡演出、
## 碎裂平台淡出、削板火花、側風陣風、干擾階梯——全部餵真實狀態進判定函式，不靠 bot 撞運氣。
## 對應稽核項：_audit_mechanics()（唯一對外入口）。
## ⚠ 黑洞／墓碑／Pameloe 三項規格上屬於機制稽核的一部分，但實作住在 audit_hazards.gd
##   （拆檔分組），這裡透過 `hazards` 持有的實例呼叫；極限模式住 audit_ui.gd，透過 `ui_audit` 呼叫。
##   兩個引用由 smoke.gd 在 _ready() 建好所有稽核節點後手動接上。

## 由 smoke.gd 注入：hazards 稽核節點（提供 _audit_doom / _audit_tomb / _audit_pameloe）
var hazards: Node
## 由 smoke.gd 注入：UI 稽核節點（提供 _audit_extreme_mode）
var ui_audit: Node

const FPS := 60.0
const DT := 1.0 / FPS


## 讓死亡演出跑完，直到 died 訊號真的 emit（或超時保護把控制權還回來）。
##
## ⚠ v17 起 `_die()` 只是**起爆**，`died` 要等爆炸演完才 emit（見 WellWorld._tick_death_fx）。
##   稽核若呼叫完 `_check_hazards()` 就直接問「死了沒」，答案永遠是 false——而且是
##   **靜默的假陰性**：致命判定整條壞掉也照樣全綠。
## ⚠ 這個 helper 本身也是死亡演出的回歸防線：爆炸卡住不結束的話這裡會空轉到超時，
##   對應的稽核項就會紅。
## ⚠ audit_hazards.gd 有一份一模一樣的：它們是兩個獨立的稽核節點，互相沒有引用
##   （只有 mechanics → hazards 單向），為了一個 7 行的測試 helper 去接第二條反向線
##   不划算。這是測試框架的技術重複，同 FPS／DT 的處理。
func _settle_death(world: WellWorld) -> void:
	var guard := int(SpikeConfig.DEATH_FX_DURATION / DT) + 8
	for _i in range(guard):
		if not world.is_dying():
			return
		world._process(DT)


## 機制稽核：無敵窗與物資收集直接餵狀態進判定函式，不靠 bot 撞運氣。
## 理由：怪物 110m 以上才出現、物資是機率生成，靠 bot 跑局覆蓋不到，
##       綠燈會變成「這次剛好沒遇到」而不是「這個機制是對的」。
func _audit_mechanics() -> bool:
	var world := WellWorld.new()
	add_child(world)
	world.set_process(false)
	var dead := {"v": false}
	world.died.connect(func(_c: String): dead["v"] = true)

	var ok := true
	var lines := PackedStringArray()

	# ① 無敵中撞到怪物 = 撞飛，不死
	world.player.refresh_invuln()
	var m1 := WellMonster.new()
	m1.pos = world.player.pos
	world.gen.monsters.append(m1)
	world._pre_vel_y = -100.0        # 上升中，排除踩頭路徑
	world._pre_bottom = world.player.bottom()
	world._check_hazards()
	# ⚠ 要連 is_dying() 一起問：v17 起 died 訊號延到爆炸演完才 emit（見 _settle_death），
	#   只看 dead["v"] 的話「無敵中竟然被判死」這個 bug 會在這一格靜默通過。
	if m1.alive or dead["v"] or world.is_dying() or world.bump_count != 1:
		lines.append("!! 無敵撞怪物沒有把牠撞飛（alive=%s dead=%s dying=%s bump=%d）" % [
			m1.alive, dead["v"], world.is_dying(), world.bump_count
		])
		ok = false

	# ② 無敵窗長度：結束後 0.4s 還在，0.6s 就沒了
	world.player.refresh_invuln()
	world.player.tick_invuln(0.4)
	var still := world.player.is_invulnerable()
	world.player.tick_invuln(0.2)
	var gone := not world.player.is_invulnerable()
	if not (still and gone):
		lines.append("!! 無敵窗長度不對（0.4s 仍有=%s、0.6s 已無=%s）" % [still, gone])
		ok = false

	# ③ 無敵過期後，同樣的撞擊要照常致死
	world.gen.monsters.clear()
	var m2 := WellMonster.new()
	m2.pos = world.player.pos
	world.gen.monsters.append(m2)
	world._check_hazards()
	_settle_death(world)
	if not dead["v"]:
		lines.append("!! 無敵過期後撞怪物沒死")
		ok = false

	# ④ 金幣：碰到就收
	var pk := WellPickup.new()
	pk.pos = world.player.pos
	world.gen.pickups.append(pk)
	world._check_pickups()
	if pk.alive or world.coin_count != SpikeConfig.COIN_PER_PICKUP:
		lines.append("!! 金幣沒被收走（alive=%s count=%d）" % [pk.alive, world.coin_count])
		ok = false

	# ⑤ 彈射板起飛＝無敵（v9）。⚠ 這條要驗兩邊：踩彈射板要開旗標，
	#    踩一般板要關掉——只驗「會開」的話，旗標一旦沒人關就是永久無敵。
	if not _audit_launch_invuln(world):
		lines.append("!! 彈射板無敵旗標不對（起飛沒開，或落到一般板沒關）")
		ok = false

	# ⑥ 蟲洞：碰到即進入過場，過場結束落點必須正好在出口平台上方
	if not _audit_wormhole_teleport(world):
		lines.append("!! 蟲洞傳送落點不在出口平台上")
		ok = false

	# ⑦ 燃料補給（v10）：補上限的固定比例，滿載時不消耗
	if not _audit_fuel_pickup(world):
		lines.append("!! 燃料補給沒補到、或滿載時被白白吃掉")
		ok = false

	# ⑧ 攀爬手套（v10）：沒裝備不得有任何效果、裝備後每次離地限一次
	if not _audit_ledge_grab(world):
		lines.append("!! 攀爬手套行為不對（沒裝備卻生效／沒送上去／可以重複觸發）")
		ok = false

	# ⑨ 投擲物落點預警（v10）：先出三角形，2 秒後才在同一個 x 落下
	if not _audit_projectile_warn():
		lines.append("!! 投擲物預警不對（沒預警、提早落下、或落點跟預警的 x 對不上）")
		ok = false

	# ⑩ 怪物死亡演出（v12）：踩頭後要拋物線飛出去、期間完全退出判定、演完會被回收
	if not _audit_monster_death(world):
		lines.append("!! 怪物死亡演出不對（沒飛出去／沒淡出／淡出在畫面外才演完／演完沒被回收）")
		ok = false

	# ⑪ 碎裂平台淡出（v12）：踩到後不是瞬間消失，整段淡出期間都還踩得住
	if not _audit_fragile_fade():
		lines.append("!! 碎裂平台淡出不對（沒淡出／提早消失／時間到了還在）")
		ok = false

	# ⑫ 削去平台的火花（v12）：走 _step_platforms 這條真實路徑，不自己複製迴圈
	if not _audit_steal_sparks(world):
		lines.append("!! 削去平台沒有噴火花（或火花不會消失）")
		ok = false

	# ⑬ 側風陣風（v13）：吹 3s 休 9s，每一陣風前 2 秒都要預警，吹的時候不算預警
	if not _audit_shockwave_gust():
		lines.append("!! 側風陣風不對（沒間歇／預警沒在每陣風前出現／吹的時候還在預警）")
		ok = false

	# ⑮ 黑洞（v13）：預警 → 開洞 → 吸力 → 碰到即死 → 無敵可消 → 壽命到自己塌縮
	if not hazards._audit_doom(world):
		lines.append("!! 黑洞不對（沒開／位置對不上預警／沒吸力／碰到沒死／無敵消不掉／不會塌縮）")
		ok = false

	# ⑭ 墓碑（v12）：立在歷史最高高度 y 軸最相近的平台上，碰到給 TOMB_COIN_REWARD
	if not hazards._audit_tomb(world):
		lines.append("!! 墓碑不對（沒生出來／位置不是最相近的平台／獎勵金額不對）")
		ok = false

	# ⑯ 極限模式（v14）：所有等待歸零，第一幀就是第四階、四種同時開跑，但預警仍在
	if not ui_audit._audit_extreme_mode():
		lines.append("!! 極限模式不對（等待沒歸零／第一幀不是第四階／四種沒同時開跑／預警被連帶歸零）")
		ok = false

	# ⑰ Pameloe（v16，08-10 三訂加雷射變體）：畫面內開火、發射瞬間鎖定玩家之後不追蹤、
	#    子彈穿透平台、碰壁消失、命中致死且死因對得上、無敵狀態打散子彈、踩頭殺得掉本體、
	#    畫面外靠 hold_fire() 頂住計時器、雷射變體開火走雷射分支且命中/無敵/隨本體關閉都對
	if not hazards._audit_pameloe(world):
		lines.append("!! Pameloe 不對（開火／方向鎖定／穿透平台／碰壁消失／命中死因／無敵打散／踩頭／畫面外充能／過場靜默／雷射開火／雷射命中死因／雷射無敵打散／雷射隨本體關閉／常數合理性，其中一項有問題）")
		ok = false

	# ⑲ 爆炸平台（08-10）：踩了才點燃、引信期間仍踩得住、重複踩不重置、燒完平台消失並炸開、
	#    爆炸判定是圓、無敵免疫但消不掉它、死因對得上、爆炸區壽命到自己消失
	if not hazards._audit_explosive_platform(world):
		lines.append("!! 爆炸平台不對（自己燒／點不燃／重複踩可拆彈／不會炸／平台沒消失／判定是矩形／無敵沒免疫或把爆炸消掉／死因不對／爆炸不會自己消失，其中一項有問題）")
		ok = false

	# ⑱ 主角死亡演出（v17）：_die() 只起爆不 emit、爆炸期間世界完全凍結、演完才 emit 一次、
	#    重入不會把爆炸倒回去、摔落死的爆炸位置一定落在畫面內
	if not _audit_death_fx(world):
		lines.append("!! 主角死亡演出不對（訊號沒延遲／世界沒凍結／重入把爆炸倒回去／沒演完就 emit／emit 不只一次／時長對不上／摔落死的爆炸不在畫面內）")
		ok = false

	# ⑤ 干擾階梯：純時間驅動，跟玩家無關。⚠ 別再用「bot 有沒有活到第三階段」來驗它——
	#    那量到的是 bot 的運氣，不是階梯，bot 早死一秒整條檢查就假性紅燈。
	var ladder := _audit_interference_ladder()
	if not ladder["ok"]:
		lines.append("!! 干擾階梯沒走完（觸及 %s，四個 offset 互異=%s，側風峰值力道 %.0f）" % [
			ladder["stages"], ladder["distinct"], ladder["force"]
		])
		ok = false

	print("--- 機制稽核（無敵窗 / 撞飛 / 金幣 / 燃料 / 彈射無敵 / 蟲洞 / 攀爬 / 預警 / 干擾階梯 / 怪物死亡演出 / 碎裂淡出 / 火花 / 側風陣風 / 墓碑 / 黑洞 / 極限模式 / Pameloe / 主角死亡演出）---")
	if ok:
		print("  無敵撞飛、0.5s 餘韻、過期致死、金幣、燃料補給、彈射無敵、蟲洞、攀爬、投擲物預警、階梯 0→4、怪物死亡演出、碎裂淡出、削板火花、側風陣風、墓碑、黑洞、極限模式、Pameloe 開火與方向鎖定、主角死亡演出、爆炸平台 — 二十項全通過（攀爬含「停用後不生效」；Pameloe 含「畫面外不開火」；主角死亡演出含「摔落死畫在畫面內」；爆炸平台含「無敵免疫但消不掉它」）")
		print("  側風峰值力道 : %.0f px/s（玩家全速 %.0f）；黑洞吸力上限 %.0f" % [
			ladder["force"], SpikeConfig.KB_MOVE_MAX_SPEED, SpikeConfig.DOOM_PULL_MAX_SPEED
		])
	else:
		for l in lines:
			print("  %s" % l)

	remove_child(world)
	world.queue_free()
	return ok


## 彈射板無敵：走 _check_landing 這條真實路徑，不直接改旗標。
## 兩邊都要驗——只驗「會開」的話，旗標一旦沒人關就變成踩一次彈射板就永久無敵。
func _audit_launch_invuln(world: WellWorld) -> bool:
	world.gen.platforms.clear()
	world.player.launch_invuln = false
	world.player.vel_y = 400.0

	var launcher := _place_under_player(
		world, WellPlatform.Kind.LAUNCHER, SpikeConfig.LAUNCHER_SIZE
	)
	world._check_landing(launcher.top_y() - 5.0)
	var opened: bool = world.player.launch_invuln \
		and is_equal_approx(world.player.vel_y, SpikeSave.launcher_velocity())

	world.gen.platforms.clear()
	world.player.vel_y = 400.0
	var normal := _place_under_player(
		world, WellPlatform.Kind.STATIC, SpikeConfig.PLATFORM_SIZE
	)
	world._check_landing(normal.top_y() - 5.0)
	var closed: bool = not world.player.launch_invuln

	return opened and closed


## 在玩家腳下貼一塊板，上緣落在玩家底部略上方，讓單向落地判定這一幀會命中
func _place_under_player(world: WellWorld, kind: int, size: Vector2) -> WellPlatform:
	var p := WellPlatform.new()
	p.kind = kind
	p.size = size
	p.pos = Vector2(world.player.pos.x, world.player.bottom() - 2.0 + size.y * 0.5)
	world.gen.platforms.append(p)
	return p


## 蟲洞：碰到即進入過場（不再是瞬間傳送），過場跑完落點必須正好站在出口平台上緣。
## 這條在驗兩件事——① 出口固定在平台上這個守門承諾，出口飄在半空中就是不可歸因的死法；
## ② 過場狀態機真的會結束，不會卡在 _wh_travel_active 出不來。
## 直接用一個超過 WORMHOLE_TRAVEL_TIME 的單一 delta 把過場跑完，驗的是「跑完之後的
## 結果」，不是逐幀動畫本身——動畫要人眼看，headless 測不了。
func _audit_wormhole_teleport(world: WellWorld) -> bool:
	var exit_plat := WellPlatform.new()
	exit_plat.kind = WellPlatform.Kind.STATIC
	exit_plat.size = SpikeConfig.PLATFORM_SIZE
	exit_plat.pos = Vector2(
		420.0,
		world.player.pos.y - SpikeConfig.WORMHOLE_RISE_M * SpikeConfig.PIXELS_PER_METER
	)
	world.gen.platforms.append(exit_plat)

	var wh := WellWormhole.new()
	wh.pos = world.player.pos
	wh.exit_platform = exit_plat
	world.gen.wormholes.append(wh)

	var before := world.wormhole_count
	world._check_wormholes()
	var started: bool = world.wormhole_count == before + 1 and not wh.alive \
		and world._wh_travel_active

	world._step_wormhole_travel(SpikeConfig.WORMHOLE_TRAVEL_TIME + 0.1)
	var finished: bool = not world._wh_travel_active

	var on_exit: bool = absf(world.player.pos.x - exit_plat.pos.x) < 0.5 \
		and absf(world.player.bottom() - exit_plat.top_y()) < 0.5
	return started and finished and on_exit


## 燃料補給：固定補 FUEL_PICKUP_REFILL_METERS 公尺，而且滿載時**不消耗**——
## 「滿的時候撿到等於白撿」是玩家最容易記恨的一種浪費，所以它要留在原地。
func _audit_fuel_pickup(world: WellWorld) -> bool:
	var full := SpikeSave.jetpack_fuel_px()
	var refill_px := SpikeConfig.FUEL_PICKUP_REFILL_METERS * SpikeConfig.PIXELS_PER_METER

	world.gen.pickups.clear()
	world.player.jetpack_fuel_px = full * 0.3
	var pk := WellPickup.new()
	pk.set_kind(WellPickup.Kind.FUEL)
	pk.pos = world.player.pos
	world.gen.pickups.append(pk)
	var before := world.player.jetpack_fuel_px
	world._check_pickups()
	var refilled: bool = not pk.alive and is_equal_approx(
		world.player.jetpack_fuel_px, minf(full, before + refill_px)
	)

	world.gen.pickups.clear()
	world.player.jetpack_fuel_px = full
	var pk2 := WellPickup.new()
	pk2.set_kind(WellPickup.Kind.FUEL)
	pk2.pos = world.player.pos
	world.gen.pickups.append(pk2)
	world._check_pickups()
	var kept: bool = pk2.alive and is_equal_approx(world.player.jetpack_fuel_px, full)

	world.gen.pickups.clear()
	return refilled and kept


## 攀爬手套：造一個「頂點時腳底還在平台上緣下方 20px」的情境（reach 30 之內）。
## 三件事都要驗——沒裝備不得有任何效果、裝備後真的送得上去、而且每次離地只能一次
## （少了最後這條就是無限爬升）。
func _audit_ledge_grab(world: WellWorld) -> bool:
	var saved_level := SpikeSave.level_of("ledge")
	var saved_enabled := SpikeSave.ledge_enabled
	SpikeSave.ledge_enabled = true

	world.gen.platforms.clear()
	world.player.ledge_used = false
	world.player.vel_y = 0.0
	world.player.state = WellPlayer.State.NORMAL
	world.player.jetpack_on = false

	var gap := 20.0
	var p := WellPlatform.new()
	p.kind = WellPlatform.Kind.STATIC
	p.size = SpikeConfig.PLATFORM_SIZE
	p.pos = Vector2(world.player.pos.x, world.player.bottom() - gap + p.size.y * 0.5)
	world.gen.platforms.append(p)

	SpikeSave.levels["ledge"] = 0
	world._try_ledge_grab()
	var no_equip_ok: bool = is_equal_approx(world.player.vel_y, 0.0) and not world.player.ledge_used

	SpikeSave.levels["ledge"] = 1
	world._try_ledge_grab()
	var boosted: bool = world.player.vel_y < 0.0 and world.player.ledge_used
	# 初速要真的夠越過那道邊緣：h = v²/2g >= gap
	var enough: bool = (world.player.vel_y * world.player.vel_y) \
		/ (2.0 * SpikeConfig.GRAVITY) >= gap

	var v_before := world.player.vel_y
	world._try_ledge_grab()
	var once_only: bool = is_equal_approx(world.player.vel_y, v_before)

	# 買了但在主頁把手套關掉（ledge_enabled = false）＝ 完全不生效。
	# ⚠ 這條驗的是「開關真的接到 has_ledge_grab()」。少了它，開關會變成純裝飾——
	#   點下去 icon 變暗、遊戲裡照補跳，而且不會有任何錯誤訊息。
	SpikeSave.ledge_enabled = false
	world.player.ledge_used = false
	world.player.vel_y = 0.0
	world._try_ledge_grab()
	var disabled_ok: bool = is_equal_approx(world.player.vel_y, 0.0) and not world.player.ledge_used

	SpikeSave.levels["ledge"] = saved_level
	SpikeSave.ledge_enabled = saved_enabled
	world.gen.platforms.clear()
	world.player.ledge_used = false
	world.player.vel_y = 0.0
	return no_equip_ok and boosted and enough and once_only and disabled_ok


## 投擲物落點預警：預警先出現、PROJECTILE_WARN_TIME 秒之內不得有東西落下，
## 時間到才在**同一個 x** 落下。x 對不上就等於預警是假動作，玩家躲了也沒用。
func _audit_projectile_warn() -> bool:
	var itf := Interference.new()
	itf.reset()
	var player_pos := Vector2(SpikeConfig.VIEW_W * 0.5, 0.0)
	var cam_top := -SpikeConfig.VIEW_H
	var t := 0.0

	var limit: float = SpikeConfig.interference_start + 30.0
	while itf.warns.is_empty() and t < limit:
		t += DT
		itf.update(DT, t, player_pos, cam_top, [])
	if itf.warns.is_empty() or not itf.projectiles.is_empty():
		return false

	var warn_x: float = itf.warns[0].x
	var guard := 0
	var max_frames := int(FPS * (SpikeConfig.PROJECTILE_WARN_TIME + 1.0))
	while itf.projectiles.is_empty() and guard < max_frames:
		t += DT
		itf.update(DT, t, player_pos, cam_top, [])
		guard += 1

	if itf.projectiles.is_empty():
		return false
	# 早於預警時間就落下 = 預警沒有真的擋住 spawn
	if guard < int(FPS * SpikeConfig.PROJECTILE_WARN_TIME) - 2:
		return false
	return absf(itf.projectiles[0].pos.x - warn_x) < 0.5


## 怪物死亡演出（v12）：踩頭殺掉之後，怪物要往上飛出去、**完全退出判定**、演完被回收。
## 中間那條「退出判定」最重要——屍體若還撞得死人，玩家會死在一個看起來已經死掉的東西上。
## 主角死亡演出（v17）。驗六件事：died 訊號真的被延到爆炸演完、爆炸期間世界完全凍結、
## 重入不會把爆炸倒回去（死因也不被後來的蓋掉）、演完只 emit 一次、時長對得上常數、
## 摔落死的爆炸位置落在畫面內。
##
## ⚠ 這一項驗的是「延遲」本身。少了它，哪天有人把 died.emit 搬回 _die() 裡，其他致死
##   稽核仍然全綠——訊號提早來不會讓任何一條斷言失敗——但玩家再也看不到自己怎麼死的。
## ⚠ 摔落那條是可歸因性的保命條款：CAUSE_FALL 觸發的當下玩家已經在畫面底緣**之下**，
##   照玩家位置畫等於畫在畫面外＝整個特效等於沒做，而且不會有任何錯誤訊息。
func _audit_death_fx(world: WellWorld) -> bool:
	world.reset()
	world.gen.monsters.clear()
	world.player.invuln_timer = 0.0
	world.running = true

	var got := {"n": 0}
	var cb := func(_c: String): got["n"] += 1
	world.died.connect(cb)

	var m := WellMonster.new()
	m.pos = world.player.pos
	world.gen.monsters.append(m)
	world._pre_vel_y = -100.0        # 上升中，排除踩頭路徑
	world._pre_bottom = world.player.bottom()
	world._check_hazards()
	var deferred: bool = world.is_dying() and got["n"] == 0

	# 凍結：爆炸期間 elapsed 不前進、玩家不動（整個世界停止運算）
	var t0: float = world.elapsed
	var p0: Vector2 = world.player.pos
	world._process(DT)
	var frozen: bool = is_equal_approx(world.elapsed, t0) and world.player.pos == p0

	# 重入：爆炸中再死一次不能把計時器倒回 0，死因也不能被後來那次蓋掉
	var t_mid: float = world._death_fx_t
	world._die(WellWorld.CAUSE_DOOM)
	var no_restart: bool = is_equal_approx(world._death_fx_t, t_mid) \
		and world.last_cause == WellWorld.CAUSE_MONSTER

	# 演完才 emit，而且只有一次
	var guard := int(SpikeConfig.DEATH_FX_DURATION / DT) + 8
	var frames := 1                  # 上面的凍結測試已經推過一幀
	while world.is_dying() and frames < guard:
		world._process(DT)
		frames += 1
	var emitted: bool = got["n"] == 1 and not world.is_dying() and not world.running
	# 時長要對得上常數，不能只驗「總有一天會結束」
	var timing_ok: bool = absf(float(frames) * DT - SpikeConfig.DEATH_FX_DURATION) < DT * 3.0
	world.died.disconnect(cb)

	# 摔落死：爆炸要畫在畫面底緣附近，不是畫在已經掉出畫面的玩家身上
	world.reset()
	world.player.pos.y = world._view_bottom() + 200.0
	world._check_end()
	var fall_in_view: bool = world.is_dying() \
		and world._death_fx_pos.y <= world._view_bottom() \
		and world._death_fx_pos.y >= world._view_top()
	world.reset()

	return deferred and frozen and no_restart and emitted and timing_ok and fall_in_view


func _audit_monster_death(world: WellWorld) -> bool:
	world.gen.monsters.clear()
	world.player.invuln_timer = 0.0
	world.player.vel_y = 400.0

	var m := WellMonster.new()
	m.pos = world.player.pos
	world.gen.monsters.append(m)
	# 造出「下墜中、腳底剛好落在怪物頭上」的踩頭情境
	world._pre_vel_y = 400.0
	world._pre_bottom = m.rect().position.y
	var stomps_before := world.stomp_count
	world._check_hazards()

	var killed: bool = m.dying and not m.alive and world.stomp_count == stomps_before + 1
	var flying: bool = m.death_vel.y < 0.0 and absf(m.death_vel.x) > 0.0

	# 拋物線：飛出去之後 y 要先變小（往上）再被自己的重力拉回來
	var y0 := m.pos.y
	var a0 := m.death_alpha()
	m.step(0.1)
	var went_up: bool = m.pos.y < y0
	var fading: bool = m.death_alpha() < a0        # alpha 真的在掉
	m.step(SpikeConfig.MONSTER_DEATH_TIME)
	var fell_back: bool = m.death_vel.y > 0.0
	var done: bool = m.expired() and is_equal_approx(m.death_alpha(), 0.0)

	# ⚠ 淡出必須在畫面內演完。屍體在 alpha 歸零那一刻離死亡點的垂直位移若接近一個畫面，
	#    玩家看到的就是「半透明地掉出畫面」＝ 看起來根本沒淡出（v12 初版的 1.1s 就是這樣壞的）。
	var tt: float = SpikeConfig.MONSTER_DEATH_TIME
	var drop: float = -SpikeConfig.MONSTER_DEATH_VY * tt \
		+ 0.5 * SpikeConfig.MONSTER_DEATH_GRAVITY * tt * tt
	var on_screen: bool = drop < SpikeConfig.VIEW_H * 0.35

	# 演完要真的從陣列裡消失（否則死亡演出結束後會留一堆看不見的殼）
	world.gen.prune_below(m.pos.y + 10000.0)
	var reaped: bool = not world.gen.monsters.has(m)

	world.gen.monsters.clear()
	world.player.vel_y = 0.0
	return killed and flying and went_up and fading and fell_back and done \
		and on_screen and reaped


## 碎裂平台淡出（v12）：踩到之後不是瞬間消失。透明度就是剩餘可站時間，
## 所以要驗三件事——淡出中還踩得住、alpha 真的在掉、時間到才消失。
func _audit_fragile_fade() -> bool:
	var p := WellPlatform.new()
	p.kind = WellPlatform.Kind.FRAGILE
	p.size = SpikeConfig.FRAGILE_SIZE
	p.pos = Vector2.ZERO

	if not is_equal_approx(p.fade_alpha(), 1.0):
		return false
	p.on_stepped()

	p.step(SpikeConfig.FRAGILE_FADE_TIME * 0.5)
	var half := p.fade_alpha()
	# 淡出到一半：還在（踩得住）、alpha 掉到約 0.5、畫出來的顏色也跟著半透明
	var mid_ok: bool = p.alive and half < 0.9 and half > 0.1 \
		and is_equal_approx(p.color().a, half)

	p.step(SpikeConfig.FRAGILE_FADE_TIME * 0.5 + 0.02)
	var gone: bool = not p.alive
	return mid_ok and gone


## 削去平台的火花（v12）：走 WellWorld._step_platforms 這條真實路徑——
## 專案 CLAUDE.md 硬規則 7，稽核不准自己複製一份迴圈。
func _audit_steal_sparks(world: WellWorld) -> bool:
	world.gen.platforms.clear()
	world._sparks.clear()

	var p := WellPlatform.new()
	p.kind = WellPlatform.Kind.STATIC
	p.size = SpikeConfig.PLATFORM_SIZE
	p.pos = Vector2(SpikeConfig.VIEW_W * 0.5, -400.0)
	p.steal_warn = SpikeConfig.STEAL_WARN_TIME
	world.gen.platforms.append(p)

	# 預告期間還沒被削掉 → 不該有火花
	world._step_platforms(SpikeConfig.STEAL_WARN_TIME * 0.5)
	var quiet_before: bool = p.alive and world._sparks.is_empty()

	world._step_platforms(SpikeConfig.STEAL_WARN_TIME * 0.5 + 0.02)
	var sparked: bool = not p.alive and world._sparks.size() == SpikeConfig.SPARK_COUNT \
		and not p.just_stolen        # 單幀旗標，讀完就要被清掉

	# 再跑一幀不得補噴第二次（旗標沒清乾淨的話這裡會抓到）
	world._step_platforms(0.02)
	var no_double: bool = world._sparks.size() == SpikeConfig.SPARK_COUNT

	# 火花會自己燒完
	world._tick_sparks(SpikeConfig.SPARK_LIFE + 0.02)
	var faded: bool = world._sparks.is_empty()

	world.gen.platforms.clear()
	return quiet_before and sparked and no_double and faded


## 側風陣風（v13）：解鎖後每 SHOCKWAVE_CYCLE 秒吹 SHOCKWAVE_BURST_TIME 秒，
## 每一陣風前 SHOCKWAVE_WARN_TIME 秒預警。四件事都要驗——
##   ① 真的會停（不是常駐）② 至少吹到第二陣（週期真的在轉）
##   ③ 吹的時候不得同時算預警（那會讓玩家以為還沒開始）
##   ④ 每一陣風開始的前一刻，預警一定亮過
func _audit_shockwave_gust() -> bool:
	var itf := Interference.new()
	itf.reset()
	var pos := Vector2(SpikeConfig.VIEW_W * 0.5, 0.0)
	var t := 0.0
	var unlock: float = SpikeConfig.interference_start + SpikeConfig.stage_shockwave_offset
	# 跑到第三輪，確認週期是真的在轉而不是只有第一次
	var total: float = unlock + SpikeConfig.SHOCKWAVE_CYCLE * 2.5

	var gusts := 0
	var was_active := false
	var seen_rest := false
	var overlap := false          # 吹的時候還在算預警 = 壞
	var warned_before_gust := true
	var warn_seen_this_cycle := false

	while t < total:
		t += DT
		itf.update(DT, t, pos, -SpikeConfig.VIEW_H, [])
		var active := itf.shockwave_active()
		var warning: bool = itf.shockwave_warn_left() >= 0.0

		if active and warning:
			overlap = true
		if warning:
			warn_seen_this_cycle = true
		if active and not was_active:
			gusts += 1
			# 每一陣風開始前都該有預警（第一陣的預警跨在解鎖之前）
			if not warn_seen_this_cycle:
				warned_before_gust = false
			warn_seen_this_cycle = false
		if was_active and not active:
			seen_rest = true
		# 力道要跟著開關：沒在吹就必須是 0
		if not active and itf.shockwave_force() != 0.0:
			overlap = true
		was_active = active

	return gusts >= 2 and seen_rest and not overlap and warned_before_gust


## 空跑一整條干擾時間軸，確認 0→1→2→3→4 五個階段都真的到得了。
## ⚠ 這條曾經紅燈過，根因是兩個 stage_*_offset 被設成同一個值 ⇒ 中間那階永遠跳過。
##   所以除了「都到得了」，這裡也直接驗四個 offset 兩兩不相等。
## ⚠ 極限模式開著的話這條會整段失真（五個 eff_ 都是 0 ⇒ 只看得到 stage 0 與 4），
##   所以呼叫端必須在 extreme_mode = false 的狀態下跑它（_audit_extreme_mode 會還原）。
func _audit_interference_ladder() -> Dictionary:
	var itf := Interference.new()
	itf.reset()
	var seen := {}
	var t := 0.0
	var peak_force := 0.0
	var total: float = SpikeConfig.interference_start \
		+ SpikeConfig.stage_doom_offset + SpikeConfig.SHOCKWAVE_CYCLE + 5.0
	while t < total:
		t += DT
		itf.update(DT, t, Vector2(SpikeConfig.VIEW_W * 0.5, 0.0), -SpikeConfig.VIEW_H, [])
		seen[itf.stage()] = true
		peak_force = maxf(peak_force, itf.shockwave_force())
	var stages: Array = seen.keys()
	stages.sort()

	var offsets := [
		SpikeConfig.stage_projectile_offset, SpikeConfig.stage_steal_offset,
		SpikeConfig.stage_shockwave_offset, SpikeConfig.stage_doom_offset,
	]
	var distinct := true
	for i in range(offsets.size()):
		for j in range(i + 1, offsets.size()):
			if is_equal_approx(offsets[i], offsets[j]):
				distinct = false

	return {
		"ok": seen.has(0) and seen.has(1) and seen.has(2) and seen.has(3) and seen.has(4) \
			and distinct and peak_force > SpikeConfig.SHOCKWAVE_FORCE_START,
		"stages": stages,
		"distinct": distinct,
		"force": peak_force,
	}
