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

	world.player.land_flash_timer = 0.0
	world.player.jetpack_on = false
	await _capture("kaela_check_jump.png")

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
	pm2.start_laser(Vector2(-1.0, 0.3).normalized())
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
