extends Node
## UI 稽核：商店、存檔往返、HUD、視窗縮放、內嵌字型、卡片尺寸、按鍵重綁、成就三態、
## 解鎖橫幅、極限模式——一律走真實路徑（build → show_screen → _on_buy/_on_claim），
## 不直接改 UI 的內部狀態。
## 對應稽核項：_audit_ui()（唯一對外入口，內部呼叫 _audit_banner / _audit_achievements /
##   _audit_keybinds）；_audit_extreme_mode() 另外被 audit_mechanics.gd 透過注入引用呼叫。

const FPS := 60.0
const DT := 1.0 / FPS


## UI 稽核：商店是這次最大的一塊新 UI，沒有任何測試碰它就是裸奔。
## 一律走真實路徑（build → show_screen → _on_buy），不直接改 UI 的內部狀態，
## 否則測到的是「我有沒有把欄位設對」而不是「玩家點下去會發生什麼」。
func _audit_ui() -> bool:
	var ui := SpikeUI.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	ui.build()

	var ok := true
	var lines := PackedStringArray()

	# ① 0 金幣：按鈕要一開始就 disabled，不是點下去才說你沒錢
	SpikeSave.clear_runtime()
	ui.show_screen("SHOP")
	var btn: Button = ui._shop_cards["jump"]["button"]
	if not btn.disabled:
		lines.append("!! 0 金幣時升級按鈕沒有鎖住")
		ok = false

	# ② 有錢：買下去，等級／金幣／生效高度三者都要跟著動
	SpikeSave.coins = 9999
	ui.show_screen("SHOP")
	var before_h := SpikeSave.jump_height()
	var before_coins := SpikeSave.coins
	ui._on_buy("jump")
	if SpikeSave.level_of("jump") != 1 or SpikeSave.coins >= before_coins \
			or SpikeSave.jump_height() <= before_h:
		lines.append("!! 買了跳躍升級，但等級/金幣/生效高度沒有正確變動")
		ok = false

	# ③ 滿級後鎖住（有限清單，不是無限成長曲線）
	while not SpikeSave.is_maxed("jump"):
		ui._on_buy("jump")
	ui.show_screen("SHOP")
	if not btn.disabled:
		lines.append("!! 滿級後按鈕沒鎖住")
		ok = false

	# ④ 存檔往返：寫出去再讀回來，等級與金幣都不能掉
	#    ⚠ v14 起也驗兩個模式開關（極限模式／手套啟用）。它們的預設值是相反的
	#    （extreme=false、ledge_enabled=true），所以刻意各存成**非預設值**再讀回來——
	#    若 load_save() 漏讀某一個，它會靜默退回預設值而不是報錯。
	SpikeSave.extreme_mode = true
	SpikeSave.ledge_enabled = false
	SpikeSave.save()
	var lv := SpikeSave.level_of("jump")
	var coins := SpikeSave.coins
	SpikeSave.load_save()
	if SpikeSave.level_of("jump") != lv or SpikeSave.coins != coins:
		lines.append("!! 存檔往返後資料掉了（等級 %d→%d，金幣 %d→%d）" % [
			lv, SpikeSave.level_of("jump"), coins, SpikeSave.coins
		])
		ok = false
	if not SpikeSave.extreme_mode or SpikeSave.ledge_enabled:
		lines.append("!! 存檔往返後模式開關退回預設值（極限 %s 應為 true，手套啟用 %s 應為 false）" % [
			SpikeSave.extreme_mode, SpikeSave.ledge_enabled
		])
		ok = false
	# ⚠ 後面的機制稽核與 bot 跑局都假設非極限模式，這裡務必還原
	SpikeSave.extreme_mode = false
	SpikeSave.ledge_enabled = true

	# ⑤ HUD：倒數歸零前後是兩條不同的顯示路徑，各餵一次真實 hud_data
	var world := WellWorld.new()
	add_child(world)
	world.set_process(false)
	ui.show_screen("PLAYING")
	ui.update_hud(world.hud_data())
	world.elapsed = SpikeConfig.interference_start + 10.0
	ui.update_hud(world.hud_data())
	remove_child(world)
	world.queue_free()

	# ⑥ 視窗縮放：整個遊戲照 1280x720 的世界座標手繪，靠 stretch 等比放大。
	#    這兩個設定被改掉（尤其 aspect 改成 expand）會直接露出井壁外沒畫的區域，
	#    而那種 bug 在編輯器裡看不出來——編輯器的嵌入遊戲視窗根本不會縮放。
	var stretch_mode: String = str(ProjectSettings.get_setting("display/window/stretch/mode", ""))
	var stretch_aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", ""))
	if stretch_mode != "canvas_items" or stretch_aspect != "keep":
		lines.append("!! 視窗縮放設定不對（mode=%s aspect=%s，應為 canvas_items / keep）" % [
			stretch_mode, stretch_aspect
		])
		ok = false

	# ⑦ 內嵌字型（v10）：Web 匯出讀不到系統字型，SystemFont 會 fallback 到不含 CJK 的
	#    內建字型 ⇒ 整頁豆腐方塊。桌面版看不出來，所以這條只能在這裡把關。
	var font := SpikeUI.shared_font()
	if font is SystemFont:
		lines.append("!! UI 用的是 SystemFont（%s 不存在）— Web 匯出會變豆腐方塊" % SpikeUI.FONT_PATH)
		ok = false

	# ⑧ 商店卡片放得進畫面（v10）：卡片是水平並排的，再加一項升級就會擠出井外。
	#    這條算的是最小寬度，實際排版只會更寬，所以它過不了就一定爆版。
	var n: int = SpikeConfig.UPGRADE_ORDER.size()
	var cards_w: float = float(n) * SpikeUI.CARD_SIZE.x + float(n - 1) * SpikeUI.CARD_GAP
	var avail: float = SpikeConfig.VIEW_W - SpikeUI.PAGE_MARGIN * 2.0
	if cards_w > avail:
		lines.append("!! 商店 %d 張卡片共 %.0f px，超過可用寬度 %.0f px（縮 CARD_SIZE 或改成兩排）" % [
			n, cards_w, avail
		])
		ok = false

	# ⑧b 主頁版面（08-10 加了選關列）：選關列 ＋ 說明字 ＋ 四顆按鈕塞不塞得進 band，
	#     以及 band 下緣有沒有壓到存檔說明那行。
	#     ⚠ 這種問題本來只有截圖看得出來（成就頁「返回」被切掉那次就是），量得到就寫成斷言。
	#     ⚠ 說明字用 font_size × 1.5 估行高：Label 的實際高度要等 layout 完才知道，
	#       而 1.5 對 Noto Sans CJK 是偏保守的估計（實測約 1.4），寧可估高不要估低。
	var start_rows_h: float = SpikeUI.LEVEL_BUTTON_SIZE.y \
		+ float(SpikeUI.FONT_SIZE_CARD_SMALL) * 1.5 \
		+ float(SpikeUI.START_MENU_BUTTONS) * SpikeUI.BUTTON_MIN_SIZE.y \
		+ float(SpikeUI.START_MENU_BUTTONS + 1) * float(SpikeUI.START_BOX_SEPARATION)
	var start_band_h: float = (SpikeUI.START_BUTTON_BAND_BOTTOM - SpikeUI.START_BUTTON_BAND_TOP) \
		* SpikeConfig.VIEW_H
	if start_rows_h > start_band_h:
		lines.append("!! 主頁按鈕組共 %.0f px，超過 band 的 %.0f px（band 往上挪或縮 separation）" % [
			start_rows_h, start_band_h
		])
		ok = false
	if SpikeUI.START_BUTTON_BAND_BOTTOM > SpikeUI.START_SAVE_NOTE_BAND_TOP:
		lines.append("!! 主頁按鈕 band 下緣 %.2f 壓到存檔說明那行 %.2f" % [
			SpikeUI.START_BUTTON_BAND_BOTTOM, SpikeUI.START_SAVE_NOTE_BAND_TOP
		])
		ok = false
	if SpikeUI.START_TITLE_BAND_BOTTOM > SpikeUI.START_BUTTON_BAND_TOP:
		lines.append("!! 主頁標題 band 下緣 %.2f 壓到按鈕組 %.2f" % [
			SpikeUI.START_TITLE_BAND_BOTTOM, SpikeUI.START_BUTTON_BAND_TOP
		])
		ok = false
	# 選關列本身的寬度（三顆按鈕橫排）
	var lv_row_w: float = float(SpikeConfig.LEVEL_COUNT) * SpikeUI.LEVEL_BUTTON_SIZE.x \
		+ float(SpikeConfig.LEVEL_COUNT - 1) * float(SpikeUI.LEVEL_ROW_GAP)
	if lv_row_w > avail:
		lines.append("!! 選關列 %d 顆共 %.0f px，超過可用寬度 %.0f px" % [
			SpikeConfig.LEVEL_COUNT, lv_row_w, avail
		])
		ok = false
	# 觸控最小邊（可逆性條款，見 ../HANDOFF.md Deferred 第 6 條②）
	if SpikeUI.LEVEL_BUTTON_SIZE.y < 44.0 or SpikeUI.TOGGLE_ICON_SIZE.y < 44.0:
		lines.append("!! 選關按鈕／開關 icon 的最小邊低於 44px（%.0f／%.0f）" % [
			SpikeUI.LEVEL_BUTTON_SIZE.y, SpikeUI.TOGGLE_ICON_SIZE.y
		])
		ok = false

	# ⑧c 結算卡片塞不塞得下（08-10：登頂頁多了劇情佔位與解鎖通知兩行）。
	#     ⚠ 用 get_combined_minimum_size() 而不是「行數 × 估計行高」：前者吃的是真實
	#       字型度量，加一行／換字級／改 separation 都會自動反映；後者要靠人記得同步
	#       改一份常數，忘了改就是靜默失效。
	#     ⚠ 這條抓過真的 bug：加了兩行之後「回標題」按鈕的下緣被圓角外框切掉 4px，
	#       只有截圖看得出來（跟成就頁「返回」那次同一個坑）。
	#     ⚠⚠ 門檻要留安全邊際：實測 minimum size 比實際 render 高度**低估約 20px**
	#       （Label 吃 SIZE_EXPAND_FILL），出事那一版量到 527 < 540 照樣通過，
	#       但畫面上按鈕確實被切掉了。沒有這個邊際這條斷言等於白寫。
	const CARD_SAFE_MARGIN := 24.0
	var card_h: float = SpikeConfig.RESULT_CARD_RATIO * SpikeConfig.VIEW_H - CARD_SAFE_MARGIN
	var probe := {
		"best_m": 1000.0, "goal_m": 1000.0, "elapsed": 321.0, "whip_used": 5, "whip_max": 5,
		"coins": 99, "fuels": 9, "wormholes": 9, "stomps": 99, "bumps": 99,
		"level": 0, "endless": false, "cleared": true, "cause": "", "unlocked": true,
	}
	ui.set_result(probe)
	var clear_h: float = ui._clear_box.get_combined_minimum_size().y
	if clear_h > card_h:
		lines.append("!! 登頂結算內容 %.0f px 超過卡片高 %.0f px（按鈕會被圓角外框切掉）" % [
			clear_h, card_h
		])
		ok = false
	probe["cleared"] = false
	probe["cause"] = "被投擲物砸中"
	ui.set_result(probe)
	var over_h: float = ui._gameover_box.get_combined_minimum_size().y
	if over_h > card_h:
		lines.append("!! 摔落結算內容 %.0f px 超過卡片高 %.0f px" % [over_h, card_h])
		ok = false

	# ⑨ 按鍵重綁（v10）
	if not _audit_keybinds():
		lines.append("!! 按鍵重綁不對（改不動／撞鍵沒讓位／存檔往返掉了／恢復預設回不去）")
		ok = false

	# ⑩ 成就卡片放得進畫面（v14）：5 列 × 2 行的 GridContainer，寬高都逼近可用區。
	#    ⚠ 高度也要算——商店那條只算寬度是因為它只有一排。再加一個成就就會多一行，
	#    9 → 10 張的那一刻高度會從 496 跳到 752，直接爆出畫面外。
	#    ⚠ v15：這裡量的是 grid 版位數 ACHIEVEMENT_SLOTS（固定 9），不是判定用的
	#    ACHIEVEMENT_ORDER（階梯拆開後有 17 個 leaf id）——階梯成就三階共用同一個版位，
	#    grid 實際畫出來的卡片數量沒變，量錯常數會造成假警報。
	var an: int = SpikeConfig.ACHIEVEMENT_SLOTS.size()
	var ach_rows: int = int(ceilf(float(an) / float(SpikeUI.ACH_COLS)))
	var ach_w: float = float(SpikeUI.ACH_COLS) * SpikeUI.ACH_CARD_SIZE.x \
		+ float(SpikeUI.ACH_COLS - 1) * SpikeUI.ACH_CARD_GAP
	var ach_h: float = float(ach_rows) * SpikeUI.ACH_CARD_SIZE.y \
		+ float(ach_rows - 1) * SpikeUI.ACH_CARD_GAP
	var ach_avail_h: float = (SpikeUI.ACH_BAND_BOTTOM - SpikeUI.ACH_BAND_TOP) * SpikeConfig.VIEW_H
	if ach_w > avail or ach_h > ach_avail_h:
		lines.append("!! 成就 %d 張（%d 列 × %d 行）共 %.0f×%.0f px，超過可用區 %.0f×%.0f px" % [
			an, SpikeUI.ACH_COLS, ach_rows, ach_w, ach_h, avail, ach_avail_h
		])
		ok = false
	# 「返回」按鈕不得撐出圓角外框。⚠ 這條抓過一次真的 bug：卡片高 240 時把按鈕擠下去，
	#    下緣被 PAGE_MARGIN 的外框切掉——只有截圖看得出來，所以改成量得到的。
	#    按鈕在 band 內置中，所以下緣 = band 中心 + 半個按鈕高。
	var back_center: float = (SpikeUI.ACH_BAND_BOTTOM + SpikeUI.ACH_BACK_BAND_BOTTOM) \
		* 0.5 * SpikeConfig.VIEW_H
	var back_bottom: float = back_center + SpikeUI.BUTTON_MIN_SIZE.y * 0.5
	var frame_bottom: float = SpikeConfig.VIEW_H - SpikeUI.PAGE_MARGIN
	if back_bottom > frame_bottom:
		lines.append("!! 成就頁「返回」下緣 %.0f px 撐出圓角外框 %.0f px（縮卡片高或把 band 往上挪）" % [
			back_bottom, frame_bottom
		])
		ok = false

	# ⑪ 成就三態流程（v14）＋階梯成就 I/II/III 進位（v15）：解鎖 → 領獎 → 不准重複領 →
	#    存檔往返狀態不掉 → 同一版位領完低階換顯示高階、reward 20/50/100 跟著對
	if not _audit_achievements(ui):
		lines.append("!! 成就不對（解不開／領不到錢／重複領到錢／未解鎖也能領／存檔往返掉了／遊玩次數重複計／階梯版位或獎勵不對）")
		ok = false

	# ⑫ 解鎖橫幅（v14）：3s 顯示、末段淡出、多個排隊逐一播、播完自己收掉
	if not _audit_banner(ui):
		lines.append("!! 成就橫幅不對（沒出現／不淡出／不排隊／播完沒收掉）")
		ok = false

	# ⑬ 存檔匯出／匯入碼（v17）：往返不掉資料、四種壞碼擋得下來、匯入走白名單
	if not _audit_save_code():
		lines.append("!! 存檔匯出／匯入碼不對（往返掉資料／壞碼沒擋下來／擋下來卻動到現況／外來多餘欄位污染狀態／新版本 schema 沒拒收）")
		ok = false

	# ⑭ 結算小卡（v17）：第一幀在畫面外、推完回到定位、尺寸是畫面的 3/4
	if not _audit_result_card(ui):
		lines.append("!! 結算小卡不對（第一幀沒在畫面外／推完沒回到定位／動畫沒收尾／尺寸不是畫面的 3/4）")
		ok = false

	# ⑮ 開發者傳送（08-10）：關掉時整顆按鈕不存在、打開時按得到；按下去要真的往上送、
	#    而且從此不寫任何存檔
	if not _audit_dev_teleport():
		lines.append("!! 開發者傳送不對（關掉卻建出按鈕／打開卻沒有／沒送到 300m／相機沒跟上／作弊局仍寫存檔／旗標沒在開新局時歸零）")
		ok = false

	print("--- UI 稽核（商店 / 存檔往返 / HUD / 視窗縮放 / 內嵌字型 / 卡片尺寸 / 按鍵重綁 / 成就 / 存檔碼 / 結算小卡 / 開發者傳送）---")
	if ok:
		print("  按鈕鎖定、購買生效、滿級鎖住、存檔往返、HUD 兩種時態、stretch、內嵌字型（%s）、商店卡片寬 %.0f/%.0f px、按鍵重綁、成就卡片 %.0f×%.0f/%.0f×%.0f px、成就三態、解鎖橫幅、存檔匯出／匯入碼、結算小卡推進、開發者傳送 — 十五項全通過" % [
			"內嵌" if not (SpikeUI.shared_font() is SystemFont) else "系統", cards_w, avail,
			ach_w, ach_h, avail, ach_avail_h
		])
		print("  成就橫幅 : 顯示 %.1fs（末段 %.1fs 淡出）、多個排隊逐一播、播完自己收掉" % [
			SpikeUI.BANNER_SHOW_TIME, SpikeUI.BANNER_FADE_TIME
		])
		# ⚠ 數值一定要印出來：get_combined_minimum_size() 若在某個環境回傳 0，
		#   上面那條「內容超過卡片高」的斷言會永遠是綠的（靜默假陰性）。印出來就看得到。
		print("  結算卡片 : 內容 登頂 %.0f / 摔落 %.0f px，卡片高 %.0f px（主頁按鈕組 %.0f / band %.0f px）" % [
			clear_h, over_h, card_h, start_rows_h, start_band_h
		])
	else:
		for l in lines:
			print("  %s" % l)

	remove_child(ui)
	ui.queue_free()
	# 後面的 bot 跑局必須是零升級狀態，這裡買出來的等級不能外溢
	SpikeSave.clear_runtime()
	return ok


## 成就解鎖橫幅（v14）。這條的存在理由很實際：橫幅是本輪唯一「只有真的解鎖成就才會跑到」
## 的程式路徑，沒有稽核的話第一次解鎖就是第一次執行它——那正是崩潰最容易藏的地方。
##
## 驗五件事：
##   ① 排進去就立刻可見
##   ② 淡出前 alpha 仍是滿的（別一出現就開始淡）
##   ③ 末段真的在淡（alpha 嚴格小於 1）
##   ④ 第一個播完會換第二個上台，而且**重設成不透明**（不是接著上一個的淡出繼續淡）
##   ⑤ 佇列空了自己收掉（visible = false），不會留一條橫幅擋著畫面
func _audit_banner(ui: SpikeUI) -> bool:
	ui.queue_achievement_banners(["soul", "kaela_2"])
	var shown: bool = ui._banner.visible and ui._banner_name.text == \
		String(SpikeConfig.ACHIEVEMENT_TABLE["soul"]["name"])

	# 推到「快要開始淡出」的前一刻
	var to_fade: float = SpikeUI.BANNER_SHOW_TIME - SpikeUI.BANNER_FADE_TIME
	var t := 0.0
	while t < to_fade - DT:
		ui._process(DT)
		t += DT
	var opaque: bool = is_equal_approx(ui._banner.modulate.a, 1.0)

	# 推進淡出段的一半
	for _i in range(int(FPS * SpikeUI.BANNER_FADE_TIME * 0.5)):
		ui._process(DT)
	var fading: bool = ui._banner.modulate.a < 0.99 and ui._banner.visible

	# 推到第一條播完 → 第二條該上台且重新變成不透明
	for _i in range(int(FPS * SpikeUI.BANNER_SHOW_TIME)):
		ui._process(DT)
	var advanced: bool = ui._banner.visible \
		and ui._banner_name.text == String(SpikeConfig.ACHIEVEMENT_TABLE["kaela_2"]["name"])

	# 第二條也播完 → 收掉
	for _i in range(int(FPS * (SpikeUI.BANNER_SHOW_TIME + 0.5))):
		ui._process(DT)
	var closed: bool = not ui._banner.visible

	return shown and opaque and fading and advanced and closed


## 成就三態（v14）：走真實路徑——用 check_achievements 解鎖、用 UI 的 _on_claim 領獎。
## 驗八件事：
##   ① 一開始全部未解鎖（新存檔不該送成就）
##   ② 條件成立 → 解鎖，而且 check_achievements **一毛錢都不給**
##      ⚠ 這是最重要的一條。使用者要的是「點卡片才拿獎勵」，解鎖時自動入帳＝規格反了，
##        而且加上領獎那次就變成一個成就領兩份錢。
##   ③ 同一個成就不會重複回報（否則橫幅會每幀跳一次）
##   ④ 點卡片 → 入帳 ACHIEVEMENT_COIN_REWARD，狀態轉 ST_CLAIMED
##   ⑤ 再點一次不給錢
##   ⑥ 未解鎖的點了也不給錢
##   ⑦ 存檔往返後三態不掉
##   ⑧b 階梯成就（v15）：I/II/III 共用同一張卡片版位，依序解鎖領獎、reward 20/50/100
##      跟著遞增，全部領完版位停在最高階——這是本輪新機制，不是只驗資料表數字，是走
##      SpikeSave.current_tier_id() ＋ ui._on_claim() 的真實路徑（同 CLAUDE.md 規則 ⑦）
func _audit_achievements(ui: SpikeUI) -> bool:
	SpikeSave.clear_runtime()
	ui.show_screen("ACHIEVEMENTS")

	var all_locked := true
	for id in SpikeConfig.ACHIEVEMENT_ORDER:
		if SpikeSave.ach_state(id) != SpikeSave.ST_LOCKED:
			all_locked = false

	# ⑥ 先驗未解鎖不能領（要在解鎖之前做，此時 speed_run 還是 locked）
	var coins_before := SpikeSave.coins
	ui._on_claim("speed_run")
	var locked_no_pay: bool = SpikeSave.coins == coins_before

	# ② speed run：2 分鐘內抵達 500m。走 live 那條判定路徑，不直接改 achievements 字典。
	var fresh := SpikeSave.check_achievements({
		"cleared": false, "whip_used": 0, "jetpack_used": false,
		"best_m": SpikeConfig.SPEEDRUN_HEIGHT_M, "elapsed": SpikeConfig.SPEEDRUN_TIME - 1.0,
	})
	var unlocked_ok: bool = fresh.has("speed_run") \
		and SpikeSave.ach_state("speed_run") == SpikeSave.ST_UNLOCKED \
		and SpikeSave.coins == coins_before

	# ③ 再問一次不該重複回報
	var again := SpikeSave.check_achievements({
		"best_m": SpikeConfig.SPEEDRUN_HEIGHT_M, "elapsed": 1.0,
	})
	var no_repeat: bool = not again.has("speed_run")

	# ④ 點卡片領獎
	ui.show_screen("ACHIEVEMENTS")
	ui._on_claim("speed_run")
	var claim_ok: bool = SpikeSave.coins == coins_before + SpikeConfig.ACHIEVEMENT_COIN_REWARD \
		and SpikeSave.ach_state("speed_run") == SpikeSave.ST_CLAIMED

	# ⑤ 重複領
	var after_claim := SpikeSave.coins
	ui._on_claim("speed_run")
	var no_double: bool = SpikeSave.coins == after_claim

	# 登頂三連：摔死的那局也「沒用鞭子」，所以 cleared = false 不該解鎖任何一個
	var not_cleared := SpikeSave.check_achievements({
		"cleared": false, "whip_used": 0, "jetpack_used": false, "best_m": 0.0, "elapsed": 999.0,
	})
	var needs_clear: bool = not (not_cleared.has("soul") or not_cleared.has("spider2") \
		or not_cleared.has("chattini_model"))
	# 登頂且兩者都沒用 → 三個一起解鎖
	var cleared_fresh := SpikeSave.check_achievements({
		"cleared": true, "whip_used": 0, "jetpack_used": false, "best_m": 0.0, "elapsed": 999.0,
	})
	var clear_ok: bool = cleared_fresh.has("soul") and cleared_fresh.has("spider2") \
		and cleared_fresh.has("chattini_model")

	# stat 類：跨局累計到門檻就解鎖（拿 big_cat 的「被小黃瓜砸死 10 次」當代表——特意不用
	# 披薩/義大利麵/Chattini/遊玩次數那四個，v15 拆完三階後同一個 stat 有三個門檻，
	# 用它們測「差一次不解鎖」會被較低那階提前解鎖污染，big_cat 是單一門檻，乾淨）
	var need: int = int(SpikeConfig.ACHIEVEMENT_TABLE["big_cat"]["need"])
	SpikeSave.bump_stat("proj_deaths", need - 1)
	var not_yet: bool = SpikeSave.check_achievements({}).is_empty()
	SpikeSave.bump_stat("proj_deaths", 1)
	var stat_ok: bool = SpikeSave.check_achievements({}).has("big_cat") and not_yet

	# ⑧b 階梯成就（v15）：I/II/III 共用同一張卡片版位，依序解鎖＋領獎，
	#    reward 20/50/100 遞增，全部領完後版位停在最高階（不會消失、不能再領）。
	#    拿「noooo」（披薩）當代表，走真實路徑：SpikeSave.current_tier_id() 決定版位該顯示
	#    誰、ui._on_claim() 領獎，兩者都要對得上，不是只驗資料表數字。
	var slot := "noooo"
	var tier_ids: Array = SpikeConfig.ACHIEVEMENT_TIERS[slot]
	var tier_sequence_ok := true
	var tier_reward_ok := true
	for i in range(tier_ids.size()):
		var expect_id: String = tier_ids[i]
		if SpikeSave.current_tier_id(slot) != expect_id:
			tier_sequence_ok = false
		SpikeSave.stats["launchers_used"] = int(SpikeConfig.ACHIEVEMENT_TABLE[expect_id]["need"])
		SpikeSave.check_achievements({})
		var reward_i: int = int(SpikeConfig.ACHIEVEMENT_TABLE[expect_id]["reward"])
		var coins_before_tier := SpikeSave.coins
		ui.show_screen("ACHIEVEMENTS")
		ui._on_claim(SpikeSave.current_tier_id(slot))
		if SpikeSave.coins != coins_before_tier + reward_i:
			tier_reward_ok = false
	var tier_ok: bool = tier_sequence_ok and tier_reward_ok \
		and SpikeSave.current_tier_id(slot) == tier_ids[-1] \
		and SpikeSave.ach_state(tier_ids[-1]) == SpikeSave.ST_CLAIMED

	# ⑧ 遊玩次數只在「開一局」時 +1（kaela）。
	#    ⚠ 這條抓的是一個真的發生過的 bug：計數本來寫在 WellWorld.reset()，而 reset 也被
	#    _ready() 呼叫，於是「建構世界 → 開一局」會算成兩次。所以這裡刻意各建一個世界、
	#    各呼叫一次 reset()，證明 reset 本身**不會**動到 plays，只有 report_run_start 會。
	var plays_before := int(SpikeSave.stats["plays"])
	var w2 := WellWorld.new()
	add_child(w2)
	w2.set_process(false)
	w2.reset()
	var reset_free: bool = int(SpikeSave.stats["plays"]) == plays_before
	SpikeSave.report_run_start()
	var start_counts: bool = int(SpikeSave.stats["plays"]) == plays_before + 1
	remove_child(w2)
	w2.queue_free()

	# ⑦ 存檔往返
	SpikeSave.save()
	var st_before := SpikeSave.ach_state("speed_run")
	var stat_before := int(SpikeSave.stats["fragile_broken"])
	SpikeSave.load_save()
	var roundtrip_ok: bool = SpikeSave.ach_state("speed_run") == st_before \
		and int(SpikeSave.stats["fragile_broken"]) == stat_before

	SpikeSave.clear_runtime()
	return all_locked and locked_no_pay and unlocked_ok and no_repeat and claim_ok \
		and no_double and needs_clear and clear_ok and stat_ok and tier_ok and roundtrip_ok \
		and reset_free and start_counts


## 結算小卡（v17）：進 GAMEOVER 的第一幀要在畫面外、推完之後回到定位、尺寸是畫面的 3/4。
## ⚠ 「推完會回到定位」是這一項真正的重點。滑入若沒收尾，卡片會停在畫面外，玩家只看到
##   一片壓暗的遊戲畫面、不知道自己已經死了——而且不會有任何錯誤訊息，只有玩才看得出來。
func _audit_result_card(ui: SpikeUI) -> bool:
	ui.show_screen("GAMEOVER")
	var card: Control = ui._result_cards[0]["card"]
	var started_offscreen: bool = card.offset_top > SpikeConfig.VIEW_H * 0.5
	var ratio_ok: bool = is_equal_approx(
			card.anchor_right - card.anchor_left, SpikeConfig.RESULT_CARD_RATIO
		) and is_equal_approx(
			card.anchor_bottom - card.anchor_top, SpikeConfig.RESULT_CARD_RATIO
		)

	var guard := int(SpikeConfig.RESULT_CARD_SLIDE_TIME / DT) + 8
	for _i in range(guard):
		ui._process(DT)
	var settled: bool = is_equal_approx(card.offset_top, 0.0) \
		and is_equal_approx(card.offset_bottom, 0.0) and not ui._slide_active

	ui.show_screen("START")
	return started_offscreen and ratio_ok and settled


## 開發者傳送（08-10）。驗五件事：
##   ① dev_mode() 為假時 HUD 裡**根本沒有**那顆按鈕（不是建了再隱藏——隱藏的東西
##      會被 visible 誤設救活，沒建出來的不會）
##   ② 為真時按得到，而且 focus_mode 是 NONE（不然按完之後鍵盤全被按鈕吃掉）
##   ③ 按下去真的往上送 DEV_TELEPORT_M，**相機一起走**、人沒有落在畫面外
##   ④ 從那一刻起存檔一個字都不寫（金幣／最高高度／登頂用時／解關／stats／成就）
##   ⑤ 下一局會恢復記錄（旗標在 report_run_start 歸零）
##
## ⚠ ④ 一定要逐條驗每個寫入函式，不能只驗「report_run_end 沒寫」——結算路徑有六個
##   寫入點，只擋住其中一個的話漏掉的那些會**沉默地**把玩家紀錄洗掉。
## ⚠ 這條稽核自己把 dev_mode 的覆寫值收乾淨（headless 是 debug build ⇒ 自然為真），
##   不還原的話後面的稽核會在「開發者模式關閉」的狀態下跑，那不是它們預期的環境。
func _audit_dev_teleport() -> bool:
	var ok := true
	var before_mode := SpikeConfig.dev_mode()

	SpikeConfig.set_dev_mode_override(false)
	var ui_off := SpikeUI.new()
	add_child(ui_off)
	ui_off.build()
	if _find_dev_button(ui_off) != null:
		ok = false
	remove_child(ui_off)
	ui_off.queue_free()

	SpikeConfig.set_dev_mode_override(true)
	var ui_on := SpikeUI.new()
	add_child(ui_on)
	ui_on.build()
	var btn := _find_dev_button(ui_on)
	if btn == null or btn.focus_mode != Control.FOCUS_NONE:
		ok = false
	else:
		# 走真實路徑：按鈕的 pressed 要真的把 UI 的訊號送出去
		var fired := [false]
		ui_on.dev_teleport_pressed.connect(func() -> void: fired[0] = true)
		btn.pressed.emit()
		if not fired[0]:
			ok = false
		# 整顆要在畫面內。⚠ 這條是實際踩到的坑：第一版用 set_anchors_and_offsets_preset
		#   排版，Button 用自己算出來的最小尺寸排，右半邊被切在畫面外（截圖才看得到）。
		if btn.position.x + btn.size.x > SpikeConfig.VIEW_W \
				or btn.position.y + btn.size.y > SpikeConfig.VIEW_H \
				or btn.position.x < 0.0 or btn.position.y < 0.0:
			ok = false
	remove_child(ui_on)
	ui_on.queue_free()

	# ③ 真的搬人：世界跑起來，按一次
	var world := WellWorld.new()
	add_child(world)
	world.set_process(false)
	world.reset()
	world.running = true
	var y0: float = world.player.pos.y
	var cam0: float = world.cam_y
	world.dev_teleport_up()
	var dy: float = SpikeConfig.DEV_TELEPORT_M * SpikeConfig.PIXELS_PER_METER
	if not is_equal_approx(y0 - world.player.pos.y, dy):
		ok = false
	if not is_equal_approx(cam0 - world.cam_y, dy):
		ok = false
	# 相機沒跟上的話人會在畫面下方外面，下一次 _check_end 直接判摔死
	if world.player.pos.y > world._view_bottom():
		ok = false
	remove_child(world)
	world.queue_free()

	# ④ 08-10 五訂：開發者傳送不再標記作弊局，按過之後成績照樣正常落盤——這是
	#   使用者要的行為（測試用傳送鈕，一般玩家碰不到，不必犧牲紀錄）。
	SpikeSave.clear_runtime()
	var height0: float = SpikeSave.best_height_m
	var recorded: bool = SpikeSave.record_height(height0 + 999.0) \
		and SpikeSave.record_clear_time(1.0) \
		and not SpikeSave.check_achievements({
			"cleared": true, "whip_used": 0, "jetpack_used": false, "best_m": 9999.0,
		}).is_empty()
	if not recorded:
		ok = false

	SpikeSave.clear_runtime()
	SpikeConfig.set_dev_mode_override(before_mode)
	return ok


## 從 HUD 樹裡找開發者傳送鈕。⚠ 遞迴掃 Button 而不是記節點名／索引：這條稽核要驗的是
##   「玩家的畫面上有沒有這顆按鈕」，綁死路徑的話 HUD 換個容器就會變成假綠燈。
##   HUD 目前除了它沒有任何 Button，找到任何一顆就是它。
func _find_dev_button(ui: SpikeUI) -> Button:
	return _find_button_in(ui._hud)


func _find_button_in(node: Node) -> Button:
	if node == null:
		return null
	for child in node.get_children():
		if child is Button:
			return child
		var found := _find_button_in(child)
		if found != null:
			return found
	return null


## 存檔匯出／匯入碼（v17）。驗六件事：往返之後資料一模一樣、四種壞碼各自被擋下、
## 壞碼被擋下時不動到現有存檔、匯入走白名單（外來的多餘欄位不會污染狀態）、
## schema_version 比程式新的碼要拒收。
##
## ⚠⚠ 這一項驗的是**完整性**，不是安全性——別把它的綠燈讀成「存檔改不了」。
##    下面「白名單」那段自己就是證據：稽核用寫死在 client 的鹽值**手工偽造了一張合法碼**
##    並且成功匯入。玩家做得到一模一樣的事，何況他本來就能直接改 IndexedDB。
##    真正的防作弊只能在伺服器端做（見 ../HANDOFF.md 榜單那條）。
func _audit_save_code() -> bool:
	SpikeSave.clear_runtime()
	SpikeSave.coins = 1234
	SpikeSave.levels["jump"] = 1
	SpikeSave.best_height_normal_m = 321.0
	SpikeSave.save()

	var code := SpikeSave.export_code()
	var prefix_ok: bool = code.begins_with(SpikeSave.CODE_PREFIX) and code.contains(".")

	# 往返：先把現況改掉，再匯入，資料要回到匯出當下的樣子
	SpikeSave.clear_runtime()
	SpikeSave.coins = 7
	SpikeSave.save()
	var res: Dictionary = SpikeSave.import_code(code)
	var roundtrip_ok: bool = res["ok"] and SpikeSave.coins == 1234 \
		and SpikeSave.level_of("jump") == 1 \
		and is_equal_approx(SpikeSave.best_height_normal_m, 321.0)

	# 四種壞碼都要擋下來，而且擋下來之後不能動到現有存檔
	var coins_now := SpikeSave.coins
	var parts := code.substr(SpikeSave.CODE_PREFIX.length()).split(".")
	var bad_prefix: bool = not SpikeSave.import_code("XXX-" + code)["ok"]
	var bad_shape: bool = not SpikeSave.import_code(SpikeSave.CODE_PREFIX + "abc")["ok"]
	var bad_sum: bool = not SpikeSave.import_code(
		"%s%s.%s" % [SpikeSave.CODE_PREFIX, parts[0], "000000000000"]
	)["ok"]
	# ⚠ 另外兩條擋下路徑（Base64 解不開、解開後不是 JSON）**刻意不測**：Godot 的 base64
	#   解碼器與 JSON parser 遇到爛輸入都會往 stderr 印一行引擎級 ERROR，而冒煙測試的驗收
	#   標準是「0 error」——為了兩條分支讓每次輸出都固定掛紅字，會把「有沒有真的出事」
	#   這個訊號洗掉。它們的外部行為與上面 bad_sum 一樣：擋下且不動現有存檔。
	var untouched: bool = SpikeSave.coins == coins_now

	# 白名單：一張**合法但夾帶多餘欄位**的碼，多的欄位不能變成 SpikeSave 的狀態
	var forged_payload := JSON.stringify({
		"coins": 55,
		"schema_version": SpikeSave.CURRENT_SCHEMA_VERSION,
		"evil_key": 999,
	})
	var forged := "%s%s.%s" % [
		SpikeSave.CODE_PREFIX,
		Marshalls.utf8_to_base64(forged_payload),
		(forged_payload + SpikeSave.CODE_SALT).sha256_text().substr(0, SpikeSave.CODE_HASH_LEN),
	]
	var forged_res: Dictionary = SpikeSave.import_code(forged)
	var whitelist_ok: bool = forged_res["ok"] and SpikeSave.coins == 55 \
		and SpikeSave.get("evil_key") == null

	# 比目前程式新的 schema 要拒收（讀不懂的欄位語意亂套比壞檔更糟）
	var future_payload := JSON.stringify({
		"coins": 1,
		"schema_version": SpikeSave.CURRENT_SCHEMA_VERSION + 1,
	})
	var future := "%s%s.%s" % [
		SpikeSave.CODE_PREFIX,
		Marshalls.utf8_to_base64(future_payload),
		(future_payload + SpikeSave.CODE_SALT).sha256_text().substr(0, SpikeSave.CODE_HASH_LEN),
	]
	var future_rejected: bool = not SpikeSave.import_code(future)["ok"]

	# ⚠ 後面還有成就與 bot 跑局，這裡務必把狀態清乾淨
	SpikeSave.clear_runtime()
	SpikeSave.save()

	return prefix_ok and roundtrip_ok and bad_prefix and bad_shape and bad_sum \
		and untouched and whitelist_ok and future_rejected


## 按鍵重綁：改得動、撞鍵時舊的那個要被清成未綁定（而不是拒絕，否則兩個鍵永遠交換不了）、
## 存檔往返不掉、恢復預設回得去。走沙盒路徑，不碰玩家真正的按鍵設定。
func _audit_keybinds() -> bool:
	SpikeKeys.reset_defaults()
	var default_left := SpikeKeys.key_of("left")

	SpikeKeys.set_key("left", KEY_J)
	var changed: bool = SpikeKeys.key_of("left") == KEY_J

	SpikeKeys.set_key("right", KEY_J)
	var stolen: bool = SpikeKeys.key_of("left") == KEY_NONE \
		and SpikeKeys.key_of("right") == KEY_J

	SpikeKeys.load_binds()
	var round_trip: bool = SpikeKeys.key_of("right") == KEY_J \
		and SpikeKeys.key_of("left") == KEY_NONE

	SpikeKeys.reset_defaults()
	var restored: bool = SpikeKeys.key_of("left") == default_left

	return changed and stolen and round_trip and restored


## 極限模式（v14 使用者拍板）：所有「等待」歸零。這條驗五件事——
##   ① 五個 eff_* 全部回 0（模式沒接上時它們照舊回 67／0／20／40／60）
##   ② 第一幀 stage() 就是 4（不是等 127 秒才累加到第四階）
##   ③ 四種干擾都真的**開始施作**：投擲物預警、抽跳板標記、側風在吹、黑洞預警
##   ④ **預警沒有被連帶歸零**——這是刻意的設計界線（見 SpikeConfig SECTION 10 的 ⚠⚠）：
##      投擲物第一幀只能有預警、不能已經有實體落下。歸零預警＝不可歸因的死法。
##   ⑤ 關掉模式之後 eff_* 要回到 preset 的原值（不是被永久改寫）
##
## ⚠ 這裡改的是 SpikeSave.extreme_mode 而不是 SpikeConfig 的欄位：模式狀態的家在存檔，
##   直接改 config 欄位等於繞過受測的那條路。跑完務必還原（後面還有 bot 跑局）。
func _audit_extreme_mode() -> bool:
	var saved := SpikeSave.extreme_mode

	SpikeSave.extreme_mode = true
	var zeroed: bool = is_zero_approx(SpikeConfig.eff_interference_start()) \
		and is_zero_approx(SpikeConfig.eff_stage_projectile_offset()) \
		and is_zero_approx(SpikeConfig.eff_stage_steal_offset()) \
		and is_zero_approx(SpikeConfig.eff_stage_shockwave_offset()) \
		and is_zero_approx(SpikeConfig.eff_stage_doom_offset())

	# 給一疊夠多的平台，抽跳板與黑洞才挑得到目標（兩者都只挑玩家上方第 N 塊起）
	var player_pos := Vector2(SpikeConfig.VIEW_W * 0.5, 0.0)
	var platforms: Array = []
	for i in range(12):
		var p := WellPlatform.new()
		p.kind = WellPlatform.Kind.STATIC
		p.size = SpikeConfig.PLATFORM_SIZE
		p.pos = Vector2(player_pos.x, player_pos.y - 160.0 * float(i + 1))
		platforms.append(p)

	var itf := Interference.new()
	itf.reset()
	itf.update(DT, DT, player_pos, -SpikeConfig.VIEW_H, platforms)

	var stage_ok: bool = itf.stage() == 4
	# 四種同時開跑的證據，各自取「第一幀就看得到」的那個訊號
	var proj_started: bool = itf.warns.size() > 0
	var steal_started := false
	for p in platforms:
		if p.steal_warn >= 0.0:
			steal_started = true
	var shock_started: bool = itf.shockwave_active() and itf.shockwave_force() > 0.0
	var doom_started: bool = itf.doom_warns.size() > 0
	# ④ 預警還在：投擲物這一幀只該有預警，不該已經有實體
	var warn_kept: bool = itf.projectiles.is_empty() \
		and itf.warns.size() > 0 and float(itf.warns[0].timer) > 0.0 \
		and itf.doom_warns.size() > 0 and float(itf.doom_warns[0].timer) > 0.0

	SpikeSave.extreme_mode = false
	var restored: bool = is_equal_approx(
		SpikeConfig.eff_interference_start(), SpikeConfig.interference_start
	) and is_equal_approx(
		SpikeConfig.eff_stage_doom_offset(), SpikeConfig.stage_doom_offset
	)

	SpikeSave.extreme_mode = saved
	return zeroed and stage_ok and proj_started and steal_started and shock_started \
		and doom_started and warn_kept and restored
