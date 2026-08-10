extends Node
## headless 冒煙測試：把真實遊戲迴圈跑起來，抓執行期崩潰與明顯的數值失控。
## 不驗手感（那要人玩），只驗「不會炸、會爬、干擾會來、鞭子打得出去」。
##
## 必須以「場景」方式跑，不能用 --script——後者不會載入 autoload，SpikeConfig 會找不到。
##   Godot_v4.6.1-stable_win64_console.exe --headless --path <spike_well> res://smoke.tscn
##
## ── 索引：想改哪一條稽核，去哪個檔 ──
## 流程：讀這段索引 → 開對應的 tests/*.gd → Grep 函式名定位（不寫行號，行號一改就過期）。
##
##  tests/audit_generator.gd — 生成器靜態稽核（一次生完整座井，不跑物理）：
##    平台密度／重疊／可跳性、左右分佈、橫移需求、蟲洞（含串流路徑）、Pameloe 生成規則。
##    入口 _audit_generator()。
##  tests/audit_mechanics.gd — 機制稽核（餵真實狀態進判定函式，不靠 bot 撞運氣）：
##    無敵窗、撞飛、金幣、燃料補給、彈射無敵、蟲洞傳送、攀爬手套、投擲物預警、
##    怪物死亡演出、主角死亡演出（爆炸 → 延遲 emit）、碎裂淡出、削板火花、側風陣風、
##    干擾階梯。入口 _audit_mechanics()。
##    ⚠ 黑洞／墓碑／Pameloe／極限模式四項也在這條稽核清單裡，但實作分別住
##    audit_hazards.gd／audit_ui.gd，這裡只是持有引用去呼叫（見下方「跨組依賴」）。
##  tests/audit_hazards.gd — 危害稽核：Pameloe（懸浮定點射手）、黑洞（doom）、墓碑。
##    入口 _audit_pameloe() / _audit_doom() / _audit_tomb()，被 audit_mechanics.gd 呼叫。
##  tests/audit_ui.gd — UI 稽核（走真實路徑：build → show_screen → _on_buy/_on_claim）：
##    商店按鈕鎖定、購買生效、存檔往返、HUD、視窗縮放、內嵌字型、卡片尺寸、按鍵重綁、
##    成就三態、解鎖橫幅、存檔匯出／匯入碼、結算小卡推進、極限模式、開發者傳送
##    （按鈕存在與否／位置在畫面內／作弊局不寫存檔）。
##    入口 _audit_ui()，_audit_extreme_mode() 另被
##    audit_mechanics.gd 呼叫。
##  tests/audit_levels.gd — 關卡制／無盡模式／第三批貼圖（08-10）：關卡表常數關係、
##    解鎖鏈、selected_level ⇄ goal_meters 同步、**跨關的難度不變性**、登頂訊號
##    （有終點會 emit／無盡不會）、存檔 v2→v3 遷移、Pameloe 立繪抽取比例、
##    貼圖腳底錨點 vs PNG 實際 alpha。入口 _audit_levels()。
##    ⚠ bot 爬不到 1000m，登頂路徑只有這條稽核驗得到。
##  tests/bot_run.gd — headless bot 跑局：一隻很笨的自動玩家把 WellWorld 迴圈跑起來，
##    抓執行期崩潰。入口 _run_once(run_idx)，本檔 _ready() 呼叫 RUNS 次。
##
## 跨組依賴（拆檔時的接線，不是稽核邏輯本身）：
##   _audit_mechanics() 呼叫 hazards._audit_doom() / hazards._audit_tomb() /
##   hazards._audit_pameloe() / ui_audit._audit_extreme_mode()——兩條引用由本檔
##   _ready() 在 add_child() 完所有稽核節點後手動賦值給 mechanics.hazards / mechanics.ui_audit。

## 5 個 tests/*.gd 都要用到 FPS/DT（部分還要 MAX_SECONDS/STRESS_RUN），但彼此互相
## preload 會撞上 GDScript 的循環引用編譯錯誤（本檔要 preload 它們來 new()，它們若
## 反過來 preload 本檔就成環）。這幾個是凍結不變的測試框架技術常數（60 fps 是物理
## 步長、不是玩法數值），不受「所有可調數值進 spike_config.gd」那條硬規則管轄，所以
## 選擇讓每個需要的檔各自宣告一份，不做成單一引用來源。
const FPS := 60.0
const DT := 1.0 / FPS
## ⚠ 終點 1000m 之後一局要 4~5 分，240s 會在半路被截斷、看起來像「爬不上去」
const MAX_SECONDS := 420.0
## run 0 = 純爬升（無鞭子）／run 1,2 = 含鞭子／run 3 = 干擾壓力測試（干擾提前到 4s）
const RUNS := 4
const STRESS_RUN := 3


func _ready() -> void:
	# 一律在零升級狀態下測（PILLARS_2.md:429 驗算要求①：零升級必須仍可通關），
	# 而且導去沙盒存檔——UI 稽核會真的走 buy() → save()，不隔開就會洗掉玩家的存檔。
	# 按鍵設定同理：重綁稽核會真的落盤。
	SpikeSave.use_sandbox()
	SpikeKeys.use_sandbox()

	# 拆檔後的稽核節點：全部 extends Node（大量用到 add_child 等 Node 方法），
	# 統一在這裡 add_child 進場景樹之後再呼叫。跨組依賴見檔頭索引。
	var generator := preload("res://tests/audit_generator.gd").new()
	var mechanics := preload("res://tests/audit_mechanics.gd").new()
	var hazards := preload("res://tests/audit_hazards.gd").new()
	var ui := preload("res://tests/audit_ui.gd").new()
	var levels := preload("res://tests/audit_levels.gd").new()
	var bot := preload("res://tests/bot_run.gd").new()
	add_child(generator)
	add_child(mechanics)
	add_child(hazards)
	add_child(ui)
	add_child(levels)
	add_child(bot)
	mechanics.hazards = hazards
	mechanics.ui_audit = ui

	var failures := 0
	if not generator._audit_generator():
		failures += 1
	if not mechanics._audit_mechanics():
		failures += 1
	if not ui._audit_ui():
		failures += 1
	# ⚠ 排在 bot 跑局**之前**：這條會切換關卡（連帶改 goal_meters），它自己負責還原，
	#   但萬一還原漏了，放在 bot 前面至少會讓 bot 的「終點」欄位當場印出異常值。
	if not levels._audit_levels():
		failures += 1
	for run_idx in range(RUNS):
		if not bot._run_once(run_idx):
			failures += 1
	print("")
	if failures == 0:
		print("[SMOKE] PASS — 生成器稽核 ＋ %d 局全部通過，無崩潰" % RUNS)
	else:
		print("[SMOKE] FAIL — %d 個檢查項目有問題" % failures)
	get_tree().quit(0 if failures == 0 else 1)
