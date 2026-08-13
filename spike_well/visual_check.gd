extends Node
## 一次性視覺驗證工具（非稽核，不進 headless 回歸）：把三種 Kaela 貼圖狀態渲染成 PNG
## 存到 tools/out/，供人眼確認錨點位置／切換有沒有跳動／有沒有穿模。
## 完成任務後可刪，或留著給下次「置換圖片」SOP 第 8 步沿用。
##
## 必須以「場景」方式跑（同 smoke.gd 的理由：--script 不會載入 autoload）。
## ⚠ 不能加 --headless：headless 底下 RenderingServer 是 dummy driver，貼圖畫出來是空白。
##   Godot_v4.6.1-stable_win64_console.exe --path <spike_well> res://visual_check.tscn

const OUT_DIR := "res://tools/out"

var world: WellWorld


func _ready() -> void:
	# ⚠ 08-10 起這支會拍 UI 頁面，而選關／模式開關會真的走 save()——不導去沙盒就會
	#   洗掉玩家的真實存檔（同 smoke.gd 的理由）。
	SpikeSave.use_sandbox()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	world = preload("res://src/well_world.gd").new()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	world.camera.position = Vector2(640.0, 360.0)
	world.player.pos = Vector2(640.0, 360.0)

	world.player.land_flash_timer = 0.1
	world.player.jetpack_on = false
	await _capture("kaela_check_steady.png")

	# 08-11：姿勢改成看 vel_y（往上 jump／往下 steady），所以這兩張一定要自己給速度——
	# 不給就是 vel_y = 0 ⇒ 兩張都會拍到 steady，看起來像「jump 貼圖壞了」。
	world.player.land_flash_timer = 0.0
	world.player.jetpack_on = false
	world.player.vel_y = -400.0
	await _capture("kaela_check_jump.png")

	world.player.vel_y = 400.0
	await _capture("kaela_check_falling.png")

	world.player.vel_y = 0.0
	world.player.land_flash_timer = 0.0
	world.player.jetpack_on = true
	await _capture("kaela_check_jetpack.png")

	# 鏡像翻轉（面向左）
	world.player.jetpack_on = false
	world.player.facing = -1.0
	await _capture("kaela_check_flip_left.png")

	# 無敵描邊：貼合 alpha 輪廓、不是外接方框。左右各拍一張，順便驗描邊有沒有跟著翻。
	world.player.invuln_timer = SpikeConfig.INVULN_GRACE
	await _capture("kaela_check_invuln_left.png")
	world.player.facing = 1.0
	await _capture("kaela_check_invuln_right.png")
	world.player.invuln_timer = 0.0

	# 08-10：第二批貼圖（怪物／蟲洞／投擲物）人眼驗證，接線同上一樣走 world.gen / interference
	# 的真實陣列，不直接呼叫 _draw_*()——那些函式只能在 _draw() 回呼內執行。
	# ⚠ 玩家挪離畫面中央，否則跟怪物/蟲洞/投擲物疊在同一個點，誰蓋誰完全看不出來
	#   （第一次拍漏了這步，monster_check_facing_left.png 拍出來只看得到 Kaela）。
	world.player.pos = Vector2(100.0, 650.0)

	var m := WellMonster.new()
	m.pos = Vector2(640.0, 360.0)
	# 08-10 真人試玩確認來源圖面向右、往左走（_dir=-1）才鏡像，跟這裡原本寫的假設相反
	# （見 _draw_patrol_monster 的 ⚠）；兩張都拍是為了肉眼比對移動方向跟貼圖朝向一不一致。
	m._dir = -1.0
	world.gen.monsters.append(m)
	await _capture("monster_check_facing_left.png")
	m._dir = 1.0
	await _capture("monster_check_facing_right.png")
	world.gen.monsters.clear()

	var plat := WellPlatform.new()
	plat.pos = Vector2(640.0, 500.0)
	plat.size = SpikeConfig.PLATFORM_SIZE
	var wh := WellWormhole.new()
	wh.pos = Vector2(640.0, 360.0)
	wh.exit_platform = plat
	world.gen.wormholes.append(wh)
	await _capture("wormhole_check.png")
	world.gen.wormholes.clear()

	var pj := Interference.Projectile.new()
	pj.pos = Vector2(640.0, 360.0)
	pj.spin = 0.0
	world.interference.projectiles.append(pj)
	await _capture("projectile_check_spin0.png")
	pj.spin = PI * 0.5
	await _capture("projectile_check_spin90.png")
	world.interference.projectiles.clear()

	# 08-10 續：**底部錨點**驗證（使用者回報怪物／蟲洞沒跟平台貼齊）。
	# ⚠ 一定要真的放一塊平台進 gen.platforms 再把它們擺上去：上面那三張是懸空拍的，
	#   畫面裡沒有基準線，「貼不貼齊」這件事在那種圖上根本看不出來——這正是 08-10
	#   第一次接貼圖時漏掉的驗證。
	var ground := WellPlatform.new()
	ground.pos = Vector2(640.0, 470.0)
	ground.size = SpikeConfig.PLATFORM_SIZE
	world.gen.platforms.append(ground)

	var m2 := WellMonster.new()
	# 位置用生成器的真實公式（WellGenerator._make_monster），不要自己湊一個數字
	m2.pos = Vector2(ground.pos.x, ground.top_y() - m2.size.y * 0.5)
	m2._dir = -1.0
	world.gen.monsters.append(m2)
	await _capture("anchor_check_monster.png")
	world.gen.monsters.clear()

	var wh2 := WellWormhole.new()
	# offset 同 WellGenerator._maybe_spawn_wormhole
	wh2.host = ground
	wh2.offset = Vector2(0.0, -(ground.size.y * 0.5 + SpikeConfig.WORMHOLE_HOVER))
	wh2.pos = ground.pos + wh2.offset
	wh2.exit_platform = ground
	world.gen.wormholes.append(wh2)
	await _capture("anchor_check_wormhole.png")
	world.gen.wormholes.clear()

	# Pameloe 兩張立繪 ＋ 充能圈。⚠ 第三張是要確認「換成貼圖之後開火預告還在」——
	#   那圈是牠唯一的事前警告，被貼圖蓋掉就變成不可歸因的死法。
	var pm := WellMonster.new()
	pm.set_kind(WellMonster.Kind.PAMELOE)
	pm.pos = Vector2(640.0, 280.0)
	world.gen.monsters.append(pm)
	pm.art_variant = 0
	await _capture("pameloe_check_v0.png")
	pm.art_variant = 1
	await _capture("pameloe_check_v1.png")
	pm.art_variant = 0
	pm.fire_timer = SpikeConfig.PAMELOE_CHARGE_TIME * 0.4
	await _capture("pameloe_check_charge.png")
	world.gen.monsters.clear()

	# 08-10 三訂：開火鏡像（face_toward）＋ 雷射變體視覺。
	var pm2 := WellMonster.new()
	pm2.set_kind(WellMonster.Kind.PAMELOE)
	pm2.pos = Vector2(640.0, 280.0)
	pm2.art_variant = 0
	world.gen.monsters.append(pm2)
	pm2.face_toward(1.0)
	await _capture("pameloe_check_facing_right.png")
	pm2.face_toward(-1.0)
	await _capture("pameloe_check_facing_left.png")

	pm2.art_variant = 1
	pm2.lock_laser_aim(Vector2(-1.0, 0.3).normalized())
	pm2.start_laser()
	await _capture("pameloe_check_laser.png")
	world.gen.monsters.clear()

	# 08-10 續：金幣／燃料貼圖 ＋ 沿輪廓白光 ＋ 漂浮。
	# ⚠ 一定要跟平台一起拍：它們是「漂在平台上方」的東西，沒有那條基準線就看不出漂浮
	#   幅度對不對，也看不出白光會不會被平台邊緣吃掉（同上面錨點那組的教訓）。
	# ⚠ host 設 null、pos 直接給：這支不跑 step()，掛 host 只會讓「位置怎麼來的」多繞一層。
	var coin := WellPickup.new()
	coin.set_kind(WellPickup.Kind.COIN)
	coin.pos = Vector2(
		ground.pos.x - 45.0, ground.top_y() - SpikeConfig.PICKUP_HOVER
	)
	var fuel_pk := WellPickup.new()
	fuel_pk.set_kind(WellPickup.Kind.FUEL)
	fuel_pk.pos = Vector2(
		ground.pos.x + 45.0, ground.top_y() - SpikeConfig.PICKUP_HOVER
	)
	world.gen.pickups.append(coin)
	world.gen.pickups.append(fuel_pk)
	# 漂浮的兩個極端（相位 ±PI/2 ⇒ sin 為 ±1）：兩張疊起來看就是整段晃動範圍。
	# elapsed 歸零，讓相位完全由 float_phase 決定，拍出來才可重現。
	# ⚠ 位移只往上（見 _pickup_float_offset 的 ⚠⚠），所以 sin=+1 那張是**最低點**＝原位，
	#   要看的正是它有沒有插進平台——這組圖第一版就是這樣抓到穿模的。
	world.elapsed = 0.0
	coin.float_phase = PI * 0.5
	fuel_pk.float_phase = PI * 0.5
	await _capture("pickup_check_float_low.png")
	coin.float_phase = -PI * 0.5
	fuel_pk.float_phase = -PI * 0.5
	await _capture("pickup_check_float_high.png")
	world.gen.pickups.clear()

	# 08-10 續：爆炸平台的三個狀態。⚠ 三張要一起看才有意義——引信是「越來越亮」，
	#   單張圖看不出它在變化；而爆炸那張要確認**外環畫在致命半徑上**（不是隨演出縮放的圈），
	#   那圈就是判定線，畫錯等於玩家看到的範圍跟會死的範圍不同。
	world.gen.platforms.clear()
	var boom := WellPlatform.new()
	boom.kind = WellPlatform.Kind.EXPLOSIVE
	boom.size = SpikeConfig.EXPLOSIVE_SIZE
	boom.pos = Vector2(640.0, 470.0)
	world.gen.platforms.append(boom)
	await _capture("explosive_check_idle.png")
	boom.on_stepped()
	boom.fuse_timer = SpikeConfig.EXPLOSIVE_FUSE_TIME * 0.15   # 快燒完＝最亮
	await _capture("explosive_check_fuse.png")
	world.gen.platforms.clear()
	world._blasts.append(WellBlast.new(boom.pos))
	await _capture("explosive_check_blast.png")
	world._blasts.clear()

	# 08-10 續：平台四態貼圖（例外六）人眼驗證。臨時擺幾種 kind 在畫面裡，不改動
	# 原本場景的正式軌跡。⚠ 08-13 二訂分組：STATIC／EXPLOSIVE 共用 normal.png（未觸發的
	# EXPLOSIVE 應該跟 STATIC 同色看不出差異）；MOVING／VERTICAL／CIRCULAR 共用 move.png
	# 靠 modulate 顏色分方向。七種全拍是為了一次確認兩組貼圖＋換色都分得出種類。
	world.player.pos = Vector2(100.0, 900.0)
	var kinds := [
		WellPlatform.Kind.STATIC, WellPlatform.Kind.MOVING, WellPlatform.Kind.LAUNCHER,
		WellPlatform.Kind.FRAGILE, WellPlatform.Kind.VERTICAL, WellPlatform.Kind.CIRCULAR,
		WellPlatform.Kind.EXPLOSIVE,
	]
	for i in kinds.size():
		var pk_plat := WellPlatform.new()
		pk_plat.kind = kinds[i]
		pk_plat.size = SpikeConfig.PLATFORM_SIZE
		match pk_plat.kind:
			WellPlatform.Kind.FRAGILE:
				pk_plat.size = SpikeConfig.FRAGILE_SIZE
			WellPlatform.Kind.LAUNCHER:
				pk_plat.size = SpikeConfig.LAUNCHER_SIZE
			WellPlatform.Kind.VERTICAL:
				pk_plat.size = SpikeConfig.VERTICAL_SIZE
			WellPlatform.Kind.CIRCULAR:
				pk_plat.size = SpikeConfig.CIRCULAR_SIZE
		pk_plat.pos = Vector2(200.0 + i * 150.0, 300.0)
		world.gen.platforms.append(pk_plat)
	await _capture("platform_check_kinds.png")
	world.gen.platforms.clear()

	# 08-11：一般平台的隨機鏡像。四種組合並排——⚠ 要確認的是「上下翻之後木板還是貼在
	# 碰撞箱頂緣」，不是「有沒有翻」：normal.png 的 alpha 內容幾乎垂直置中，翻完位移只有
	# 0.5px，真的翻錯的話會整條掉到平台下面去，一眼看得出來。
	for i in 4:
		var fp := WellPlatform.new()
		fp.size = SpikeConfig.PLATFORM_SIZE
		fp.pos = Vector2(260.0 + i * 250.0, 300.0)
		fp.flip_h = i % 2 == 1
		fp.flip_v = i >= 2
		world.gen.platforms.append(fp)
	await _capture("platform_check_flip.png")
	world.gen.platforms.clear()

	# 08-11：踩踏晃動。三張＝震盪曲線的三個相位（第一下沉底／回彈到最高／幾乎靜止），
	# ⚠ 純視覺，所以要看的是「貼圖離開了原位」而不是判定有沒有跟著動——判定框本來就
	#   不會動（見 WellPlatform.stomp_offset_y 的 ⚠⚠）。基準用旁邊那塊沒被踩的板比對。
	var ref_plat := WellPlatform.new()
	ref_plat.size = SpikeConfig.PLATFORM_SIZE
	ref_plat.pos = Vector2(400.0, 300.0)
	var stomped := WellPlatform.new()
	stomped.size = SpikeConfig.PLATFORM_SIZE
	stomped.pos = Vector2(750.0, 300.0)
	world.gen.platforms.append(ref_plat)
	world.gen.platforms.append(stomped)
	var phases := {"down": 0.0, "up": 0.2, "settled": 0.8}
	for tag in phases:
		stomped.on_stepped()
		stomped.stomp_t = SpikeConfig.PLATFORM_STOMP_TIME * (1.0 - float(phases[tag]))
		await _capture("platform_check_stomp_%s.png" % tag)
	world.gen.platforms.clear()

	# 碎裂平台踩踏後淡出：踩下去（on_stepped）後倒數過一半，alpha 應該只剩約一半。
	var frag := WellPlatform.new()
	frag.kind = WellPlatform.Kind.FRAGILE
	frag.size = SpikeConfig.FRAGILE_SIZE
	frag.pos = Vector2(400.0, 300.0)
	frag.on_stepped()
	frag.breaking_timer = SpikeConfig.FRAGILE_FADE_TIME * 0.5
	world.gen.platforms.append(frag)
	await _capture("platform_check_fragile_fade.png")
	world.gen.platforms.clear()

	# 終點平台：寬度＝整個井寬，貼磚模式（tile=true）不整張拉伸。
	var goal_plat := WellPlatform.new()
	goal_plat.kind = WellPlatform.Kind.STATIC
	goal_plat.is_goal = true
	goal_plat.size = Vector2(SpikeConfig.WELL_RIGHT - SpikeConfig.WELL_LEFT, SpikeConfig.PLATFORM_SIZE.y)
	goal_plat.pos = Vector2((SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5, 300.0)
	world.gen.platforms.append(goal_plat)
	world.camera.position = Vector2((SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5, 300.0)
	await _capture("platform_check_goal_tile.png")
	world.gen.platforms.clear()
	world.camera.position = Vector2(640.0, 360.0)

	# 08-11：背景貼磚（硬規則 4 例外七）。三個高度各拍一張：井頂（貼磚起點對不對）、
	# 井中段（純檢查捲動中的貼磚有沒有斷線／錯位）、500m 以後（應該退回純色 C_BG，
	# 不能整段井都貼滿）。⚠ camera.position.y 用世界座標，start_y=0 時往上爬 y 變負值
	# （見 SpikeConfig.height_m 換算），跟高度公尺的直覺方向相反，這裡先注意。
	world.camera.position = Vector2(640.0, -20.0)
	await _capture("bg_check_top.png")
	world.camera.position = Vector2(640.0, -200.0 * SpikeConfig.PIXELS_PER_METER)
	await _capture("bg_check_mid.png")
	world.camera.position = Vector2(640.0, -550.0 * SpikeConfig.PIXELS_PER_METER)
	await _capture("bg_check_beyond_500m.png")
	world.camera.position = Vector2(640.0, 360.0)

	# 08-12 四訂：開局三選一改成起跳板→過渡列 A（2 塊）→過渡列 B（3 塊）→三選一排的
	# 三道階梯（見 SpikeConfig BUFF_INTRO_GAP 的說明）。稽核只驗得到座標數字對不對，
	# 「階梯感看起來對不對、沒有貼壁、沒有跟起跳平台疊在一起」還是要人眼看一次。
	# ⚠ 先把舊的 world 藏起來：這張圖是另開一個 WellWorld 拍的，兩個 world 疊在同一個
	#   viewport 裡不藏會拍到疊影（下面 08-10 那段本來就要把 world 藏起來，這裡只是提前）。
	world.visible = false
	# select_level() 靠 unlocked_level 擋門檻（level_unlocked()），沙盒存檔預設沒解鎖
	# 關卡二，不先解鎖的話 select_level(1) 會静默失敗、selected_level 還是停在 0，
	# 生成器就過不了 buff_choice 的 level_gate_ok，buff_orbs 會是空的。
	SpikeSave.unlocked_level = 1
	SpikeSave.select_level(1)
	var buff_world := preload("res://src/well_world.gd").new()
	add_child(buff_world)
	await get_tree().process_frame
	var start_plat: WellPlatform = buff_world.gen.platforms[0]
	var center_host: WellPlatform = buff_world.gen.buff_orbs[1].host
	buff_world.camera.position = Vector2(640.0, (start_plat.pos.y + center_host.pos.y) * 0.5)
	await _capture("buff_intro_check_layout.png")
	remove_child(buff_world)
	buff_world.queue_free()
	SpikeSave.select_level(0)

	# 08-10：主頁選關列與結算頁。版面稽核（audit_ui「主頁版面」那條）只算得到高度總和，
	# 「三種鎖定狀態看不看得出差別」「劇情佔位有沒有被卡片邊界切掉」還是只有人眼判得了。
	world.visible = false
	var ui := SpikeUI.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	ui.build()

	# 關卡二已解鎖、關卡三仍鎖著 ⇒ 選中／已解鎖未選中／鎖定三種狀態同一張圖看得完
	SpikeSave.unlocked_level = 1
	SpikeSave.select_level(0)
	SpikeSave.endless_mode = false
	ui.show_screen("START")
	await _capture("start_check_levels.png")

	SpikeSave.endless_mode = true
	ui.show_screen("START")
	await _capture("start_check_endless.png")
	SpikeSave.endless_mode = false

	# 08-10：開發者傳送鈕的位置（畫面右緣中間）。⚠ 從 console/編輯器跑一律是 debug build
	#   ⇒ SpikeConfig.dev_mode() 為真 ⇒ 這顆鈕一定拍得到。玩家的正式版沒有它（見 SECTION 11），
	#   所以這張圖驗的是「它在不在礙事的位置」，不是「它存不存在」（那條由稽核驗）。
	ui.show_screen("PLAYING")
	ui.update_hud(world.hud_data())
	await _capture("hud_check_dev_button.png")

	# 結算頁（登頂）：劇情佔位 ＋ 解鎖通知那兩行
	var d := world.result_data()
	d["cleared"] = true
	d["cause"] = ""
	d["level"] = 0
	d["endless"] = false
	d["unlocked"] = true
	d["best_m"] = SpikeConfig.LEVEL_GOALS[0]
	ui.set_result(d)
	ui.show_screen("CLEAR")
	# ⚠ show_screen 會把卡片重置到畫面外（推進動畫的第一幀），直接拍會拍到空畫面。
	#   要驗的是「文字排版對不對」不是動畫本身，所以先關掉 _slide_active 再推到 t=1——
	#   只設位置不關動畫的話，_capture 等的那一幀 _process 會用 _slide_t 把它覆寫回去。
	ui._slide_active = false
	ui._apply_result_slide(1.0)
	await _capture("clear_check_story.png")

	# 死亡結算頁（08-13 三訂改版）：大字＝死因文字、高度掛 NEW、用時、KRONII 幣。
	# ⚠ 拍**破紀錄**那一版：NEW 標記那一列是高度那行最寬的狀態，版面出事會先出在這裡。
	d["cleared"] = false
	d["cause"] = WellWorld.CAUSE_DOOM
	d["best_m"] = 540.0
	d["coins"] = 37
	d["new_record"] = true
	ui.set_result(d)
	ui.show_screen("GAMEOVER")
	ui._slide_active = false
	ui._apply_result_slide(1.0)
	await _capture("gameover_check_death_line.png")

	# 08-13 四張新圖（項目 13／9／10／7）。前三張是**佔位版**的版面確認：素材到位之後
	# 這幾張要重拍一次比對（版位不該變，變的只有「畫什麼」）。
	# ① 左下角四種格子（BUFF ×2 → 手套／懷錶 → 噴射 → 鞭子）＋冷卻黑幕。
	#    ⚠ 手套與懷錶要「拿得到」才畫得出來，所以先把通關紀錄推到全解鎖。
	SpikeSave.cleared_max = SpikeConfig.LEVEL_COUNT - 1
	SpikeSave.ledge_enabled = true
	SpikeSave.watch_enabled = true
	world.visible = true
	world.grant_buff("shield")
	world.grant_buff("pizza")
	world.player.jetpack_cooldown_timer = SpikeConfig.JETPACK_COOLDOWN * 0.6
	world.player.watch_used = true      # 懷錶那格演「這次離地已經用掉」的整格黑
	ui.show_screen("PLAYING")
	ui.update_hud(world.hud_data())
	await _capture("hud_check_bottom_left.png")
	world.player.jetpack_cooldown_timer = 0.0
	world.player.watch_used = false

	# ② 滿版劇情佔位（圖二那種排版：滿版圖 ＋ 底部文字區塊）
	ui.show_story(SpikeConfig.story_text(SpikeConfig.STORY_INTRO_ID))
	ui.show_screen("STORY")
	await _capture("story_check_placeholder.png")

	# ③ 破關解鎖蒙版（圖三那種排版：半透明蒙版 ＋ 中央 ICON ＋ 名稱 ＋ 說明）
	ui.show_unlock("ledge")
	ui.show_screen("UNLOCK")
	await _capture("unlock_check_mask.png")
	ui.show_screen("PLAYING")

	# ④ 第五種干擾：視野縮小（第三關限定）。⚠ 這張不是佔位——暗幕就是最終效果，
	#    要看的是「主角周遭那圈亮度夠不夠讀得到落點」。
	world.interference = Interference.new()
	world.interference.reset()
	world.interference.level_idx = SpikeConfig.LEVEL_COUNT - 1
	var t := 0.0
	var elapsed := SpikeConfig.eff_interference_start()
	while t < SpikeConfig.eff_stage_vision_offset() + SpikeConfig.VISION_FADE_IN + 0.5:
		world.interference.update(0.05, elapsed, world.player.pos, world._view_top(), [])
		t += 0.05
		elapsed += 0.05
	world.player.pos = Vector2(640.0, 360.0)
	world.camera.position = Vector2(640.0, 360.0)
	world.cam_y = 360.0
	await _capture("vision_check_shrink.png")

	# ⑤ 教學關字卡（08-13x）：黃底圓角卡在固定高度，headless 的版面掃描完全看不到它
	#    （它是世界層繪製不是 Control），只有這張截圖驗得出「字有沒有溢出卡片／卡片有沒有
	#    壓到平台」。⚠ 一定要走 tutorial_mode + reset() 的真實路徑，手動塞平台驗不到佈局。
	world.interference = Interference.new()
	world.interference.reset()
	world.tutorial_mode = true
	world.reset()
	for shot: Dictionary in [
		{"h_m": 1.5, "name": "tutorial_check_cue_intro.png"},
		{"h_m": 61.5, "name": "tutorial_check_cue_whip.png"},
	]:
		var cy: float = world.start_y - float(shot["h_m"]) * SpikeConfig.PIXELS_PER_METER
		world.cam_y = cy
		world.camera.position = Vector2(SpikeConfig.VIEW_W * 0.5, cy)
		world.player.pos = Vector2(SpikeConfig.VIEW_W * 0.5, cy + 120.0)
		await _capture(String(shot["name"]))

	print("[VISUAL_CHECK] done")
	get_tree().quit()


func _capture(filename: String) -> void:
	world.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join(filename)
	img.save_png(path)
	print("saved ", path)
