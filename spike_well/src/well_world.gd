class_name WellWorld
extends Node2D
## 遊戲層：物理、碰撞、相機、繪製。狀態機與 UI 不在這裡（住 main.gd）。
##
## 物理刻意手寫 AABB 而不用 CharacterBody2D：
##   ① 鞭子射線本來就要對平台矩形做查詢，跟碰撞共用同一份資料最省事
##   ② 鞭子拖曳需要「完全接管速度」，跟引擎物理搶控制權是純粹的麻煩
##   ③ 單向平台（往上穿過、往下踩到）自己寫比設 one_way_collision 好調

signal died(cause: String)
## 登頂：抵達本關的 goal_meters。08-10 關卡制把這個訊號接回來了（08-09 的無盡加壓
## 曾一度讓它沒有任何 emit 端），現在由 _check_end 在「有終點的模式」下 emit。
## ⚠ 無盡模式（SpikeConfig.eff_has_goal() == false）永遠不會 emit 它：沒有終點就沒有
##   抵達終點這件事，連帶那一局也不解鎖下一關、不算登頂三連成就。
## ⚠ ACHIEVEMENT_TABLE 的 soul／chattini_model／spider2 條件仍是「cleared」，使用者
##   08-10 拍板**任一關卡登頂都算**——所以那三個判定不需要知道是第幾關，維持原樣即可。
signal cleared()
## 局中就成立的成就（見 _report_progress）。帶新解鎖的 id 陣列，main.gd 轉給 UI 放橫幅。
## ⚠ 只負責「通知」，不入帳——金幣要玩家自己去成就頁點卡片（見 SpikeSave.claim_achievement）。
signal achievement_unlocked(ids: Array)

## 死因文字。做成常數是因為它現在是**判定依據**（BIG CAT 成就數的是被投擲物砸死幾次）：
## 散在 died.emit() 裡的字面值一旦被改，成就會靜默失效而且不會有任何錯誤訊息。
## ⚠ 這裡仍是死因文案唯一的家（HANDOFF「改文案去哪改」指的就是這幾行），改字沒問題，
##   但改完不要順手把 result_data 的 death_by_projectile 換成字串比對。
const CAUSE_MONSTER := "撞到怪物"
const CAUSE_PROJECTILE := "被投擲物砸中"
const CAUSE_DOOM := "被黑洞吞噬"
const CAUSE_FALL := "掉出畫面"
## ⚠ 撞到 pameloe **本體**走 CAUSE_MONSTER（牠就是怪物，同一套判定）；這條專指被牠的子彈
##   打中。兩者分開是為了讓結算讀得出「我是被射死的還是撞死的」——同一隻敵人的兩種死法
##   要求玩家改的操作完全不同（一個是走位、一個是別亂踩）。
const CAUSE_PAMELOE_SHOT := "被 Pameloe 擊中"
## 雷射變體（08-10 三訂，art_variant == 1）專用死因，跟子彈分開的理由同上——結算要分得出
## 是被子彈打死還是站在雷射裡不動被燒死，兩者要求玩家改的行為不一樣（走位 vs 別久留）。
const CAUSE_PAMELOE_LASER := "被 Pameloe 的雷射擊中"
## ⚠ 爆炸平台（08-10）自己一條死因，不併進 CAUSE_FALL 或別的：它是唯一「玩家自己點燃、
##   2 秒後才發生」的死法，結算寫成別的東西會讓玩家對不上因果，而因果正是這塊板的全部設計。
const CAUSE_BLAST := "被爆炸平台炸中"

## Kaela 玩家貼圖（本輪美術試接，見 spike_well/CLAUDE.md 規則 4 例外）。
## 路徑常數住呼叫端而非 spike_config.gd——跟 SpikeUI.FONT_PATH 同一個理由：
## 這是資源位置不是可調數值，規則 1 管的是後者。
## ⚠ 用 ResourceLoader.exists() 才 load，缺檔就整組退回原本的色塊，不讓匯入漏掉的
##   資源變成靜默的空白玩家（同一個坑字型踩過一次，見 spike_ui.gd）。
const KAELA_STEADY_PATH := "res://assets/sprites/kaela_steady.png"
const KAELA_JUMP_PATH := "res://assets/sprites/kaela_jump.png"
const KAELA_JETPACK_PATH := "res://assets/sprites/kaela_jetpack.png"

var _kaela_steady_tex: Texture2D
var _kaela_jump_tex: Texture2D
var _kaela_jetpack_tex: Texture2D

## 剪影版（RGB 全白、保留原 alpha），無敵描邊用。載入時算一次。
## ⚠⚠ 描邊不能直接拿原圖 modulate 成青色：modulate 是**乘法**，貼圖自帶的黑色描邊
##   乘上任何顏色仍然是黑，畫出來會是一圈髒綠色的暗邊而不是白框（實測踩過）。
var _kaela_steady_sil: Texture2D
var _kaela_jump_sil: Texture2D
var _kaela_jetpack_sil: Texture2D

## 08-10 使用者拍板匯入的第二批貼圖（怪物／蟲洞／投擲物），流程與路徑慣例同上。
## 缺檔一律退回原本的純色 `_draw()`，見各自 draw 函式。
const MONSTER_PATROL_TEX_PATH := "res://assets/sprites/monster_chattini.png"
const WORMHOLE_TEX_PATH := "res://assets/sprites/wormhole_the_sheep.png"
const PROJECTILE_TEX_PATH := "res://assets/sprites/projectile_cucumber.png"
## Pameloe 的兩張立繪（08-10 補匯入）。index 對齊 WellMonster.art_variant：
## 0＝常見的那張、1＝10% 的那張。⚠ 兩張缺任何一張都整組退回純色 `_draw()`——
## 只載到一張會讓 10% 的那批變成看不見的即死物，那是最糟的失效方式。
const PAMELOE_TEX_PATHS := [
	"res://assets/sprites/pameloe1.png",
	"res://assets/sprites/pameloe2.png",
]

## 08-10 續：第四批（金幣／燃料補給，硬規則 4 例外五）。慣例同上，缺檔退回純色 `_draw()`。
## ⚠ 這兩張的 art 尺寸不是「畫布 ×2」而是「**alpha 內容** ＝ 判定 ×2」，理由見
##   SpikeConfig.COIN_ART_SIZE 的 ⚠⚠——來源圖四周有大片透明留白。
const COIN_TEX_PATH := "res://assets/sprites/pickup_coin.png"
const FUEL_TEX_PATH := "res://assets/sprites/pickup_fuel.png"

var _monster_tex: Texture2D
var _wormhole_tex: Texture2D
var _projectile_tex: Texture2D
var _pameloe_texs: Array[Texture2D] = []
var _coin_tex: Texture2D
var _fuel_tex: Texture2D

## 剪影版（同 _kaela_*_sil 的理由與做法）：蟲洞常駐金光與 Pameloe 充能圈都改成
## **沿貼圖 alpha 輪廓**描邊，不再畫外接長方形——長方形框住的是「畫布」不是「那隻東西」。
## ⚠ 跟本體貼圖同生同滅：本體是 null 就不會有剪影，繪製端統一用 `sil != null` 判斷。
var _wormhole_sil: Texture2D
var _pameloe_sils: Array[Texture2D] = []
## 金幣／燃料的白光輪廓（使用者指定沿輪廓 +2px）。同上：本體是 null 就沒有剪影。
var _coin_sil: Texture2D
var _fuel_sil: Texture2D

var gen: WellGenerator
var player: WellPlayer
var whip: Whip
var interference: Interference

var camera: Camera2D
var start_y := 0.0
var cam_y := 0.0
var elapsed := 0.0
var best_m := 0.0
var running := false
## 踩頭次數。「踩頭永遠可行」是 PILLARS 的保底條款，這個計數是它的回歸防線。
var stomp_count := 0
## 無敵狀態下撞飛怪物的次數（鞭子／jetpack 的附加價值，冒煙測試拿它當回歸指標）
var bump_count := 0
## 這局撿到的金幣數（前身是「物資」，v9 起直接就是商店貨幣）
var coin_count := 0
## 這局撿到的燃料補給數
var fuel_count := 0
## 這局用掉的蟲洞數
var wormhole_count := 0

# --- 成就用的本局計數（跨局累計住 SpikeSave.stats，這裡只記這一局） ---
## 這局有沒有真的噴過（`jetpack_on` 為真過一次就算）。⚠ 用「噴出來過」而不是「按過鍵」：
## 冷啟動 0.5s 沒到就放開，玩家的認知是「我沒用 jetpack」。
var jetpack_used := false
## 這局踩碎幾塊碎裂平台。同一塊只算第一次踩（第二次踩它還在淡出，不是新的一塊）。
var fragile_broken_count := 0
## 這局踩到幾次彈射板。同一塊可重複算——它不會消失，重複踩就是重複用。
var launcher_used_count := 0
## 這局打倒幾隻怪物（踩頭＋無敵撞飛＋鞭中，三種都算）。
## ⚠ 這不等於 stomp_count + bump_count：鞭中怪物也是擊殺，但它走 whip.fire() 那條路。
var monster_kill_count := 0
## 最後一次死亡的原因。result_data 拿它導出 death_by_projectile，見上方 CAUSE_* 的 ⚠。
var last_cause := ""
## speed run 的即時判定只跑一次。⚠ 沒有這個旗標的話「已經 500m 但超過 2 分鐘」會讓
## _check_end 每一幀都去比對一次成就表，白燒一整局的 CPU。
var _speedrun_checked := false

## 蟲洞過場：true 期間 _step_player／碰撞判定／_update_camera 整段不跑，
## 玩家與相機改由 _step_wormhole_travel 沿 smoothstep(t) 曲線各自推向終點。
## 見任務說明與 _begin_wormhole_travel 的設計選擇註解。
var _wh_travel_active := false
var _wh_travel_timer := 0.0
var _wh_travel_from_cam_y := 0.0
var _wh_travel_to_cam_y := 0.0
var _wh_travel_from_pos := Vector2.ZERO
var _wh_travel_to_pos := Vector2.ZERO

## 攀爬手套成功時的回饋圈：計時器歸零前每幀畫一個往外擴、往外淡的白色圓
## （見 _try_ledge_grab／_draw_ledge_fx）。
var _ledge_fx_active := false
var _ledge_fx_timer := 0.0
var _ledge_fx_pos := Vector2.ZERO

## 平台被 Raora 削掉時四散的火花。純表現、不參與任何判定。
## 這是「事後確認」訊號：閃爍預告是板還在時的事前警告，火花是板沒了的事後告知——
## 玩家在半空中時視線多半不在那塊板上，少了事後訊號就會變成「跳過去發現腳下是空的」。
var _sparks: Array = []

## Pameloe 射出的子彈（v16）。⚠ 存活期刻意跟發射者脫鉤：pameloe 被踩死之後，牠已經
## 射出去的子彈仍然會飛完，所以「殺掉牠」不是一個可以無視眼前彈道的解法。
var _shots: Array = []
## 這局 pameloe 一共射了幾發。冒煙測試拿它當回歸指標——歸零就代表生成／開火某一段
## 斷了，而斷掉的表現是「什麼都沒發生」，沒有任何錯誤訊息。
var pameloe_shot_count := 0
## 這局雷射變體一共點亮了幾次雷射（08-10 三訂）。同 pameloe_shot_count 的理由：
## art_variant == 1 抽不到、或分支寫錯全部落回發子彈，都是「什麼都沒發生」，需要數字盯著。
var pameloe_laser_count := 0

## 爆炸平台炸開後留下的爆炸區（08-10，WellBlast）。⚠ 存活期跟平台脫鉤是刻意的：平台在
## 炸開那一刻就 alive = false，之後隨時會被 prune 回收，狀態掛在它身上等於「爆炸演不演得完」
## 看相機捲到哪裡（見 WellBlast 檔頭的 ⚠⚠）。
var _blasts: Array = []
## 這局一共炸了幾次。同 pameloe_shot_count：斷掉的表現是「什麼都沒發生」，需要一個數字盯著。
var blast_count := 0

## 死亡演出（v17，使用者拍板）。死掉的當下**不切頁**：先在死亡位置放一個小型爆炸，
## 這段期間世界完全凍結（見 _process 開頭），演完才 emit died 讓 main.gd 進結算。
## ⚠ 這不是裝飾。瞬間切到結算頁會把「我怎麼死的」藏在切換的那一幀裡，玩家只看到
##   畫面一換就出現死因文字——那行字是唯一的線索，等於把可歸因性交給文案去補。
## ⚠ 常數住 SpikeConfig SECTION 6c；美術素材接進來時只換 _draw_death_fx 的內容。
var _dying := false
var _death_fx_t := 0.0
var _death_fx_pos := Vector2.ZERO
var _death_fx_shards: Array = []


## 一顆火花。位置／速度／剩餘壽命，吃自己的重力，alpha 隨壽命線性淡出。
class Spark extends RefCounted:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0

## 位移前的狀態快照。踩頭判定必須用這兩個值，不能用當幀最新值——
## 落地會把 vel_y 改成向上，若用最新值判定，「站在怪物所在平台上」會被
## 誤判成側面撞擊，踩頭這條保底條款會整條失效。
var _pre_vel_y := 0.0
var _pre_bottom := 0.0

## 非 null 時取代真實滑鼠座標。headless 沒有滑鼠，冒煙測試靠這個灌入合成輸入。
var mouse_override = null
## 非 null 時取代鍵盤 A/D 讀值（-1/0/1）。同上，headless 沒有真實按鍵狀態可讀。
var kb_dir_override = null


func mouse_world() -> Vector2:
	if mouse_override != null:
		return mouse_override
	return get_global_mouse_position()


## ⚠ 按鍵一律走 SpikeKeys.is_action_pressed()，不要出現 KEY_A/KEY_D 這種字面值——
##   設定頁改了綁定，遊戲裡才會跟著改。
func kb_dir() -> float:
	if kb_dir_override != null:
		return kb_dir_override
	var dir := 0.0
	if SpikeKeys.is_action_pressed("right"):
		dir += 1.0
	if SpikeKeys.is_action_pressed("left"):
		dir -= 1.0
	return dir


func _ready() -> void:
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	player = WellPlayer.new()
	whip = Whip.new()
	interference = Interference.new()
	gen = WellGenerator.new()
	_load_kaela_textures()
	_load_hazard_textures()
	reset()


func _load_kaela_textures() -> void:
	if ResourceLoader.exists(KAELA_STEADY_PATH):
		_kaela_steady_tex = load(KAELA_STEADY_PATH)
	if ResourceLoader.exists(KAELA_JUMP_PATH):
		_kaela_jump_tex = load(KAELA_JUMP_PATH)
	if ResourceLoader.exists(KAELA_JETPACK_PATH):
		_kaela_jetpack_tex = load(KAELA_JETPACK_PATH)
	_kaela_steady_sil = _make_silhouette(_kaela_steady_tex)
	_kaela_jump_sil = _make_silhouette(_kaela_jump_tex)
	_kaela_jetpack_sil = _make_silhouette(_kaela_jetpack_tex)


func _load_hazard_textures() -> void:
	if ResourceLoader.exists(MONSTER_PATROL_TEX_PATH):
		_monster_tex = load(MONSTER_PATROL_TEX_PATH)
	if ResourceLoader.exists(WORMHOLE_TEX_PATH):
		_wormhole_tex = load(WORMHOLE_TEX_PATH)
	if ResourceLoader.exists(PROJECTILE_TEX_PATH):
		_projectile_tex = load(PROJECTILE_TEX_PATH)
	# 全有或全無：任何一張缺席就把整組清掉，繪製端只要判斷陣列空不空（見上方 ⚠）。
	var pm: Array[Texture2D] = []
	for path in PAMELOE_TEX_PATHS:
		if not ResourceLoader.exists(path):
			pm.clear()
			break
		pm.append(load(path))
	_pameloe_texs = pm

	if ResourceLoader.exists(COIN_TEX_PATH):
		_coin_tex = load(COIN_TEX_PATH)
	if ResourceLoader.exists(FUEL_TEX_PATH):
		_fuel_tex = load(FUEL_TEX_PATH)

	_wormhole_sil = _make_silhouette(_wormhole_tex)
	_coin_sil = _make_silhouette(_coin_tex)
	_fuel_sil = _make_silhouette(_fuel_tex)
	var ps: Array[Texture2D] = []
	for tex in _pameloe_texs:
		ps.append(_make_silhouette(tex))
	_pameloe_sils = ps


## 把貼圖壓成純白剪影（RGB 全白、alpha 照抄），之後 modulate 成任何顏色都會是那個顏色。
## 目前六張（Kaela 三態 ＋ 蟲洞 ＋ Pameloe 兩張）≈ 5 萬像素，只在 _ready 跑一次，不進每幀。
func _make_silhouette(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image().duplicate()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, img.get_pixel(x, y).a))
	return ImageTexture.create_from_image(img)


func reset() -> void:
	start_y = 0.0
	elapsed = 0.0
	best_m = 0.0
	stomp_count = 0
	bump_count = 0
	coin_count = 0
	fuel_count = 0
	wormhole_count = 0
	jetpack_used = false
	fragile_broken_count = 0
	launcher_used_count = 0
	monster_kill_count = 0
	pameloe_shot_count = 0
	pameloe_laser_count = 0
	last_cause = ""
	_speedrun_checked = false
	# ⚠ 「遊玩次數」（kaela 成就）**不在這裡算**。reset() 有兩個呼叫端：_ready() 建構世界時
	#   也會呼叫一次，算在這裡的話光是開啟遊戲就先送一次遊玩次數，玩一局變成兩次。
	#   真正的「開一局」入口是 main.gd 的 _start_run，計數住那裡（SpikeSave.report_run_start）。
	_wh_travel_active = false
	_wh_travel_timer = 0.0
	_ledge_fx_active = false
	_ledge_fx_timer = 0.0
	_sparks.clear()
	_shots.clear()
	_blasts.clear()
	_dying = false
	_death_fx_t = 0.0
	_death_fx_shards.clear()
	Engine.time_scale = 1.0

	gen = WellGenerator.new()
	# 墓碑高度與關卡編號都由外面灌進生成器（生成器自己不讀 SpikeSave，見 setup() 的 ⚠⚠）。
	# ⚠ 關卡決定哪些「關卡限定」的地形生得出來（目前只有爆炸平台），門檻表住
	#   SpikeConfig.LEVEL_GATED——這裡只負責把「現在是第幾關」送過去。
	gen.setup(start_y, 0, SpikeSave.best_height_m, SpikeSave.selected_level)

	player.reset(Vector2(SpikeConfig.VIEW_W * 0.5, start_y - SpikeConfig.PLAYER_SIZE.y * 0.5))
	whip.reset()
	interference.reset()

	cam_y = player.pos.y - (SpikeConfig.CAMERA_START_RATIO - 0.5) * SpikeConfig.VIEW_H
	camera.position = Vector2(SpikeConfig.VIEW_W * 0.5, cam_y)
	gen.ensure_generated_to(cam_y - SpikeConfig.VIEW_H)
	queue_redraw()


# ============================================================
# 主迴圈
# ============================================================

func _process(delta: float) -> void:
	# 死亡演出：世界完全凍結，只有爆炸自己在動（不推進物理、不生成、不判定）。
	# ⚠ 這一段必須擋在 `not running` **之前**：_check_end 的摔落路徑會先把 running 關掉
	#   再呼叫 _die()，順序顛倒的話爆炸永遠不會被推進，看起來就像整個特效沒接上。
	if _dying:
		_tick_death_fx(delta)
		queue_redraw()
		return
	if not running:
		return

	# 瞄準窗走「真實秒」：慢動作不能連帶把 3 秒決策窗一起拉長。
	# 過場中不可能還在瞄準（進場那一刻已經強制收掉，見 _begin_wormhole_travel），
	# 這裡順手排除只是防呆。
	if not _wh_travel_active and whip.state == Whip.State.AIMING:
		var real_delta: float = delta / maxf(Engine.time_scale, 0.0001)
		if whip.tick_aim(real_delta, mouse_world() - player.pos):
			_end_slowmo()

	elapsed += delta
	# 蟲洞過場期間干擾計時照跑（加速手段不是免費喘息），但不生新的預警／抽跳板——
	# 那會瞄準一個過場中才有、下一刻就不在的位置。suppress_spawn 只讓計時器空轉，
	# 過場結束後下一次 update() 立刻用當下的真實位置補上，見 interference.gd 的註解。
	interference.update(
		delta, elapsed, player.pos, _view_top(), gen.platforms, best_m, _wh_travel_active
	)

	_step_platforms(delta)
	for m in gen.monsters:
		m.step(delta)
	# 開火在 _step_player 之前：鎖定的是上一幀的玩家位置。差一幀無所謂，重要的是
	# 「發射瞬間鎖定、之後不追蹤」這條性質（見 PameloeShot 的 ⚠）。
	_fire_pameloe_shots()
	_tick_shots(delta)
	for pk in gen.pickups:
		pk.step(delta)
	for wh in gen.wormholes:
		wh.step(delta)

	# 先倒數再讓來源重置：拉扯／噴射／蟲洞過場進行中每幀都會把窗口頂滿，
	# 所以它真正開始消耗的時點就是動作結束的那一刻。
	player.tick_invuln(delta)
	player.tick_land_flash(delta)
	player.tick_jetpack_cooldown(delta)

	if _wh_travel_active:
		_step_wormhole_travel(delta)
	else:
		if player.is_pulled():
			player.refresh_invuln()
			if player.step_pull(delta):
				whip.end_pull()
		else:
			_step_player(delta)

		_clamp_to_walls()
		# 彈射板起飛段跟鞭子／jetpack 同級：速度被完全接管，所以整段無敵。
		# 這裡每幀把窗口頂滿，落到非彈射板時 _check_landing 會關掉旗標，餘韻由計時器接手。
		if player.launch_invuln:
			player.refresh_invuln()
		_check_hazards()
		_check_pickups()
		_check_wormholes()
		# _check_wormholes 這一幀可能剛把 _wh_travel_active 打開——那就交給下一幀的
		# _step_wormhole_travel 去管相機，這裡不要再用觸發線邏輯去頂它。
		if not _wh_travel_active:
			_update_camera()

	_tick_ledge_fx(delta)
	_tick_sparks(delta)
	_stream_world()
	_check_end()

	whip.tick_visual(delta)
	queue_redraw()


## 推進所有平台，並把「這一幀剛被 Raora 削掉」的那些接成火花。
## 獨立成一個函式而不是寫在 _process 裡，是為了讓冒煙測試能走這條真實路徑
## （專案 CLAUDE.md 硬規則 7：稽核不准自己複製一份迴圈）。
func _step_platforms(delta: float) -> void:
	for p in gen.platforms:
		p.step(delta)
		# 旗標由平台設、由這裡清——平台是純資料，自己不畫東西
		if p.just_stolen:
			p.just_stolen = false
			_spawn_sparks(p.pos, p.size.x)
		# 爆炸板燒完引信（08-10）。⚠ 爆炸區生在**平台中心**而不是玩家位置：它是地形事件，
		#   跟觸發它的人早就沒有關係了（引信 2s，玩家通常已經在兩塊板以外）。
		if p.just_exploded:
			p.just_exploded = false
			_blasts.append(WellBlast.new(p.pos))
			blast_count += 1
			_spawn_sparks(p.pos, p.size.x)

	# ⚠ 爆炸區在平台之後推進、在判定之前——這樣「這一幀剛生出來的爆炸」立刻就有殺傷力，
	#   不會有一幀的空窗（那一幀畫得出來卻打不到人，是最難重現的那種 bug）。
	for b in _blasts:
		b.step(delta)
	_blasts = _blasts.filter(func(b): return b.alive)


func _step_player(delta: float) -> void:
	# --- 水平：滑鼠拖曳或鍵盤 AD，看 SpikeConfig.ACTIVE_INPUT_MODE ---
	if SpikeConfig.ACTIVE_INPUT_MODE == SpikeConfig.InputMode.KEYBOARD:
		_step_horizontal_keyboard(delta)
	else:
		_step_horizontal_mouse(delta)

	# --- 側風陣風：獨立速度分量，操作控制抵銷不掉。沒在吹時 force = 0，
	#     這條 move_toward 會自然把殘餘速度收回 0（陣風的「收尾」就是這樣來的）---
	var force := interference.shockwave_force()
	# 無盡加壓：唯一不封頂軸，逼近速度 RESPONSE 隨高度階梯疊乘（SpikeConfig SECTION 9c）
	player.shock_vel_x = move_toward(
		player.shock_vel_x, -force, SpikeConfig.eff_shockwave_response(best_m) * delta
	)

	# --- 黑洞吸力：同上，二維版。離開範圍後目標歸零，速度一樣靠 move_toward 收回 ---
	player.doom_vel = player.doom_vel.move_toward(
		interference.pull_velocity_at(player.pos), SpikeConfig.DOOM_PULL_RESPONSE * delta
	)

	_step_jetpack(delta)

	if not player.jetpack_on:
		player.vel_y = minf(
			player.vel_y + SpikeConfig.GRAVITY * delta, SpikeConfig.MAX_FALL_SPEED
		)

	# 攀爬要在位移前判：它改的是這一幀的 vel_y，晚一幀就錯過頂點窗了
	_try_ledge_grab()

	var prev_bottom := player.bottom()
	_pre_bottom = prev_bottom
	_pre_vel_y = player.vel_y

	player.pos.x += player.total_vel_x() * delta
	# ⚠ 垂直位移要把黑洞吸力加進來（total_vel_x 只涵蓋水平那一半）
	player.pos.y += (player.vel_y + player.doom_vel.y) * delta

	if player.vel_y > 0.0:
		_check_landing(prev_bottom)


## 目標速度正比於「滑鼠與角色的距離」，但趨近目標速度的速率分加速/減速兩檔。
## DECEL < ACCEL 是拖曳感的來源：起步俐落，但停不住、會滑過頭。
func _step_horizontal_mouse(delta: float) -> void:
	var dx: float = mouse_world().x - player.pos.x
	var desired := 0.0
	if absf(dx) > SpikeConfig.MOUSE_DEADZONE:
		desired = clampf(
			dx * SpikeConfig.MOUSE_FOLLOW_GAIN,
			-SpikeConfig.MOVE_MAX_SPEED,
			SpikeConfig.MOVE_MAX_SPEED
		)
	var speeding_up := absf(desired) > absf(player.control_vel_x) \
		and desired * player.control_vel_x >= 0.0
	var rate: float = SpikeConfig.MOVE_ACCEL if speeding_up else SpikeConfig.MOVE_DECEL
	player.control_vel_x = move_toward(player.control_vel_x, desired, rate * delta)
	_face_by_intent(desired)


## A/D 直接決定方向，全速為目標速度。KB_MOVE_ACCEL/DECEL 預設相等，放開就乾脆
## 停下，刻意不繼承滑鼠那組的滑行感。
func _step_horizontal_keyboard(delta: float) -> void:
	var desired := kb_dir() * SpikeConfig.KB_MOVE_MAX_SPEED
	var speeding_up := absf(desired) > absf(player.control_vel_x) \
		and desired * player.control_vel_x >= 0.0
	var rate: float = SpikeConfig.KB_MOVE_ACCEL if speeding_up else SpikeConfig.KB_MOVE_DECEL
	player.control_vel_x = move_toward(player.control_vel_x, desired, rate * delta)
	_face_by_intent(desired)


## 只有「玩家自己想往哪走」才翻面。desired == 0（放開按鍵／滑鼠在死區內）維持原朝向，
## 不歸零成預設方向——站著不動時角色不該自己轉回去。
func _face_by_intent(desired: float) -> void:
	if desired > 0.0:
		player.facing = 1.0
	elif desired < 0.0:
		player.facing = -1.0


func _step_jetpack(delta: float) -> void:
	var was_on := player.jetpack_on
	var held := SpikeKeys.is_action_pressed("jet")
	# 08-10 使用者拍板：冷卻中（jetpack_cooldown_timer > 0）一律不讓 hold 累積，
	# 跟「沒燃料」同一條路徑處理——冷卻跟冷啟動是兩件事，見 WellPlayer 的 ⚠。
	var can_engage := held and player.jetpack_fuel_px > 0.0 and player.jetpack_cooldown_timer <= 0.0
	if can_engage:
		player.jetpack_hold += delta
		player.jetpack_on = player.jetpack_hold >= SpikeConfig.JETPACK_SPOOL_TIME
	else:
		player.jetpack_hold = 0.0
		player.jetpack_on = false

	if not player.jetpack_on:
		if was_on:
			player.jetpack_cooldown_timer = SpikeConfig.JETPACK_COOLDOWN
		return

	# 「這局用過 jetpack」＝真的噴出來過（不是按過鍵）。魂系玩家／Chattini 的典範
	# 兩個成就靠它，見上方 jetpack_used 的說明。
	jetpack_used = true

	# 噴射中把無敵窗頂滿：這段期間玩家的垂直速度被 jetpack 完全接管，閃不掉任何東西。
	# ⚠ 走 jetpack 專屬的窄窗（refresh_jetpack_invuln），不是共用的 refresh_invuln——
	#   08-10 使用者拍板只把 jetpack 的餘韻改短，鞭子／彈射板／蟲洞過場維持原本 0.5s。
	player.refresh_jetpack_invuln()

	player.vel_y = move_toward(
		player.vel_y, SpikeSave.jetpack_thrust_speed(), SpikeConfig.JETPACK_ACCEL * delta
	)
	# 燃料按「上升距離」扣，再乘 BURN_MULT（削弱 jetpack 的效率，理由見 SpikeConfig SECTION 6）。
	# 只在上升時扣：下墜中按著噴射是在減速，那段不該收費。
	if player.vel_y < 0.0:
		player.jetpack_fuel_px -= -player.vel_y * delta * SpikeConfig.JETPACK_FUEL_BURN_MULT
		if player.jetpack_fuel_px <= 0.0:
			player.jetpack_fuel_px = 0.0
			player.jetpack_on = false
			# 燃料耗盡也是一種「結束」，同樣起算冷卻（見上方 was_on 那條路徑的對稱版本）。
			player.jetpack_cooldown_timer = SpikeConfig.JETPACK_COOLDOWN


## 攀爬（特殊裝備，商店的「攀爬手套」解鎖）。
##
## 落地判定是跨越偵測（見 _check_landing）：頂點時腳底若還在平台上緣**之下**，
## 整段下墜都不會成立，玩家就這樣擦邊摔下去。攀爬補的就是這一段——頂點附近若
## 上緣就在腳底上方 LEDGE_GRAB_REACH 之內，給一次剛好夠越過去的初速。
##
## 三道限制讓它不會變成「無限爬升」或「角色自己亂動」：
##   ① 只在頂點附近（|vel_y| <= LEDGE_GRAB_VEL_WINDOW）
##   ② 每次離地限一次（player.ledge_used，落地／傳送才重置）
##   ③ 鞭子拉扯中與 jetpack 噴射中不觸發——那兩段速度已被完全接管，再插手會打架
func _try_ledge_grab() -> void:
	if player.ledge_used or not SpikeSave.has_ledge_grab():
		return
	if player.is_pulled() or player.jetpack_on:
		return
	if absf(player.vel_y) > SpikeConfig.LEDGE_GRAB_VEL_WINDOW:
		return

	var bottom := player.bottom()
	var half_w := player.size.x * 0.5
	for p in gen.platforms:
		if not p.alive:
			continue
		var top: float = p.top_y()
		# 上緣必須在腳底之上（還沒跨過去）、且在觸及範圍內
		var reach := bottom - top
		if reach <= 0.0 or reach > SpikeConfig.LEDGE_GRAB_REACH:
			continue
		if absf(player.pos.x - p.pos.x) > half_w + p.size.x * 0.5:
			continue
		# v = √(2gh)：剛好夠把腳底送過上緣，外加 CLEAR 的餘裕讓落地判定接得住
		player.vel_y = -sqrt(
			2.0 * SpikeConfig.GRAVITY * (reach + SpikeConfig.LEDGE_GRAB_CLEAR)
		)
		player.ledge_used = true
		_trigger_ledge_fx(Vector2(player.pos.x, top))
		return


## 攀爬成功的視覺回饋：釘在觸發當下的世界座標（不是跟著平台走，見任務回報的設計選擇），
## 純粹是給玩家看「手套生效了」的一次性提示，跟 ledge_used 的一次性限制完全獨立——
## 這個函式只負責記時間與位置，不會、也不能反過來影響 ledge_used 的判定。
func _trigger_ledge_fx(pos: Vector2) -> void:
	_ledge_fx_active = true
	_ledge_fx_timer = 0.0
	_ledge_fx_pos = pos


func _tick_ledge_fx(delta: float) -> void:
	if not _ledge_fx_active:
		return
	_ledge_fx_timer += delta
	if _ledge_fx_timer >= SpikeConfig.LEDGE_FX_DURATION:
		_ledge_fx_active = false


## 在 at 這個位置沿板寬灑一排火花，往四面八方噴出去。
## 用全域 randf 而不是帶種子的 RNG：純表現，不需要重現性，也不該去污染生成器的亂數序列
## （生成器的 seed 是稽核要重現的東西）。
func _spawn_sparks(at: Vector2, spread_x: float) -> void:
	for _i in range(SpikeConfig.SPARK_COUNT):
		var s := Spark.new()
		s.pos = at + Vector2(randf_range(-spread_x * 0.5, spread_x * 0.5), 0.0)
		var ang := randf_range(0.0, TAU)
		var spd := randf_range(SpikeConfig.SPARK_SPEED_MIN, SpikeConfig.SPARK_SPEED_MAX)
		s.vel = Vector2(cos(ang), sin(ang)) * spd
		s.life = SpikeConfig.SPARK_LIFE
		_sparks.append(s)


## Pameloe 開火（v16）。
##
## ⚠ 只有在畫面內的才射。畫面外射進來的子彈玩家看不到來源，是不可歸因的死法。
##   但畫面外的計時器**不能就這樣一路跑到負值**，否則牠一被相機捲進畫面就在同一幀開火，
##   充能閃爍完全來不及演——所以那些改成 hold_fire() 頂在充能起點。
## ⚠ 蟲洞過場中不開火：那一刻玩家正沿 smoothstep 曲線位移，鎖定的是一個下一刻就不在的
##   位置。計時器照跑不停（過場不是免費喘息），過場結束後下一幀就補上——跟干擾在過場中
##   suppress_spawn 的處理同一套。
func _fire_pameloe_shots() -> void:
	if _wh_travel_active:
		return
	var top := _view_top()
	var bot := _view_bottom()
	for m in gen.monsters:
		if m.kind != WellMonster.Kind.PAMELOE:
			continue
		if m.pos.y < top or m.pos.y > bot:
			m.hold_fire()
			continue
		# 08-10 四訂：雷射變體在充能「起點」就鎖定方向並亮出預警線，不再等充能結束才
		# 決定要打哪——使用者回報充能全程沒有方向預告、雷射直接鎖玩家幾乎必死。鎖點
		# 提前到 charge_ratio() 剛轉正的那一刻，充能閃爍的整段時間都能看到打哪、來得及躲。
		if m.art_variant == 1 and not m.laser_dir_locked and m.charge_ratio() > 0.0:
			# ⚠ 型別要明寫：gen.monsters 是無型別 Array，m.pos 推不出型別，`:=` 會編譯失敗
			var aim: Vector2 = player.pos - m.pos
			if aim.length_squared() >= 1.0:
				m.lock_laser_aim(aim.normalized())
		if not m.take_shot():
			continue
		# 08-10 三訂：art_variant == 1（pemaloe2）走雷射分支，方向在充能起點已經鎖好
		# （見上方），這裡不再重算，直接用鎖定的 laser_dir 開火。
		if m.art_variant == 1:
			m.start_laser()
			pameloe_laser_count += 1
			continue
		var dir: Vector2 = player.pos - m.pos
		# 重合時方向是零向量，normalized() 會回 (0,0) 生出一顆不會動的子彈卡在原地
		if dir.length_squared() < 1.0:
			continue
		var dir_n: Vector2 = dir.normalized()
		# 08-10 二訂：開火瞬間依方向鏡像面向（子彈這條仍在發射瞬間鎖定，雷射已提前見上）。
		m.face_toward(dir_n.x)
		var sh := PameloeShot.new()
		sh.pos = m.pos
		sh.vel = dir_n * SpikeConfig.PAMELOE_SHOT_SPEED
		_shots.append(sh)
		pameloe_shot_count += 1


## 推進子彈並回收。三種消失方式：撞到井壁（PameloeShot.step 內部判定）、飛出串流視窗、
## 命中玩家或被無敵狀態打散（由 _check_hazards 設 alive=false）。
## ⚠ 回收邊界留一個 VIEW_H 的餘裕：子彈是斜著飛的，貼著畫面邊緣飛的那顆若用精確邊界
##   回收，會在玩家眼前憑空消失。
func _tick_shots(delta: float) -> void:
	var top := _view_top() - SpikeConfig.VIEW_H
	var bot := _view_bottom() + SpikeConfig.VIEW_H
	var kept: Array = []
	for sh in _shots:
		sh.step(delta)
		if sh.alive and sh.pos.y > top and sh.pos.y < bot:
			kept.append(sh)
	_shots = kept


func _tick_sparks(delta: float) -> void:
	if _sparks.is_empty():
		return
	for s in _sparks:
		s.life -= delta
		s.vel.y += SpikeConfig.SPARK_GRAVITY * delta
		s.pos += s.vel * delta
	_sparks = _sparks.filter(func(s): return s.life > 0.0)


## 單向平台：只有下墜中、且這一幀「從平台上緣之上跨到之下」才算落地
func _check_landing(prev_bottom: float) -> void:
	var new_bottom := player.bottom()
	var half_w := player.size.x * 0.5
	for p in gen.platforms:
		if not p.alive:
			continue
		var top: float = p.top_y()
		if prev_bottom > top + SpikeConfig.LAND_TOLERANCE:
			continue
		if new_bottom < top:
			continue
		if absf(player.pos.x - p.pos.x) > half_w + p.size.x * 0.5:
			continue
		player.pos.y = top - player.size.y * 0.5
		player.ledge_used = false
		player.trigger_land_flash()
		# 跳躍力與彈射初速吃永久升級；⚠ 生成器的間距仍以 SpikeConfig 的基礎值為設計單位
		if p.kind == WellPlatform.Kind.LAUNCHER:
			player.vel_y = SpikeSave.launcher_velocity()
			player.launch_invuln = true
			launcher_used_count += 1
			SpikeSave.bump_stat("launchers_used")
		else:
			player.vel_y = SpikeSave.jump_velocity()
			player.launch_invuln = false
		# ⚠ 碎裂平台要在 on_stepped() **之前**問 breaking_timer：on_stepped 會把它設成
		#   FRAGILE_FADE_TIME，之後就分不出「這是第一次踩」還是「淡出期間又踩一次」。
		#   淡出期間仍踩得住（v12 的設計），所以第二次踩不能再算一塊。
		var first_break: bool = p.kind == WellPlatform.Kind.FRAGILE and p.breaking_timer < 0.0
		p.on_stepped()
		if first_break:
			fragile_broken_count += 1
			SpikeSave.bump_stat("fragile_broken")
		# 落地是唯一會動到「披薩／義大利麵」兩個計數的地方，兩種各自 bump 完在這裡
		# 統一問一次成就（重複呼叫無害——已解鎖的不會再回報，見 check_achievements）
		_report_progress()
		return


func _clamp_to_walls() -> void:
	var half := player.size.x * 0.5
	var lo := SpikeConfig.WELL_LEFT + half
	var hi := SpikeConfig.WELL_RIGHT - half
	if player.pos.x < lo:
		player.pos.x = lo
		player.control_vel_x = maxf(player.control_vel_x, 0.0)
	elif player.pos.x > hi:
		player.pos.x = hi
		player.control_vel_x = minf(player.control_vel_x, 0.0)


func _check_hazards() -> void:
	# 無敵窗（鞭子命中拉扯中／jetpack 噴射中／兩者結束後 0.5s）：
	# 這兩個動作都把速度完全接管，玩家閃不掉任何東西，此時判傷害等於懲罰玩家用工具。
	# 而且不只是免傷——撞到的怪物直接被撞飛，投擲物被打散。
	var invuln := player.is_invulnerable()

	var pr := player.rect()
	for m in gen.monsters:
		if not m.alive:
			continue
		var mr: Rect2 = m.rect()
		if not pr.intersects(mr):
			continue
		if invuln:
			_kill_monster(m)
			bump_count += 1
			continue
		# 踩頭永遠可行（PILLARS 保底條款：鞭子用完後高處怪物不得退化成運氣牆）
		if _pre_vel_y > 0.0 and _pre_bottom <= mr.position.y + SpikeConfig.STOMP_TOLERANCE:
			_kill_monster(m)
			player.vel_y = SpikeConfig.STOMP_BOUNCE_VELOCITY
			stomp_count += 1
		else:
			_die(CAUSE_MONSTER)
			return

	for pj in interference.projectiles:
		if not (pj.alive and pr.intersects(pj.rect())):
			continue
		if invuln:
			pj.alive = false
			continue
		_die(CAUSE_PROJECTILE)
		return

	# Pameloe 的子彈：跟投擲物同一條規則（無敵中撞到＝打散它，否則即死）。
	# ⚠ 它穿透平台，所以躲在板子下面沒有用——這是使用者拍板的性質，不是漏判。
	for sh in _shots:
		if not (sh.alive and pr.intersects(sh.rect())):
			continue
		if invuln:
			sh.alive = false
			continue
		_die(CAUSE_PAMELOE_SHOT)
		return

	# Pameloe 雷射變體（08-10 三訂）：跟子彈同一條無敵規則（撞到＝打散，否則即死），
	# 但判定用點到線段距離（laser_hits），不是矩形——雷射是一條線不是一個框。
	# ⚠ 用玩家中心點而不是 pr（矩形）：跟黑洞／爆炸圈同一套風格，圓形／線形危害一律
	#   量中心距離，矩形危害才用 AABB 相交（見上面兩段跟下面黑洞段的分工）。
	for m in gen.monsters:
		if m.kind != WellMonster.Kind.PAMELOE or not m.alive:
			continue
		if not m.laser_hits(player.pos):
			continue
		if invuln:
			m.laser_active = false
			continue
		_die(CAUSE_PAMELOE_LASER)
		return

	# 黑洞：判定用圓心距離（它畫成圓，用矩形會出現「看起來在圓外卻死」的角落死法）。
	# 無敵中撞進去＝把洞消掉，跟怪物／投擲物同一條規則。
	for d in interference.dooms:
		if not (d.alive and d.swallows(player.pos)):
			continue
		if invuln:
			d.alive = false
			continue
		_die(CAUSE_DOOM)
		return

	# 爆炸平台的爆炸區（08-10）：判定用圓心距離，同黑洞的理由（它畫成圓）。
	# ⚠ 無敵中免疫，但**不把爆炸消掉**——跟怪物／投擲物／黑洞那三條不一樣。爆炸是範圍
	#   事件不是一個可以被打散的物件，「衝過去把它消掉」會讓 jetpack 變成拆彈工具，
	#   而這塊板整個設計就是要玩家用時間換位置。
	for b in _blasts:
		if not b.hits(player.pos):
			continue
		if invuln:
			continue
		_die(CAUSE_BLAST)
		return


## 死亡的單一出口：記下死因、起爆，**訊號延到爆炸演完才 emit**（見 _tick_death_fx）。
## 死因要留著是因為 result_data 得導出 death_by_projectile（BIG CAT 成就），
## 而 died 訊號的參數只有 main.gd 收得到。
## ⚠ 同一幀可能被呼叫兩次（_check_hazards 的 return 只跳出它自己，_process 之後照樣走到
##   _check_end），所以第一行就擋掉重入——否則爆炸會被第二次呼叫重置回 t=0。
func _die(cause: String) -> void:
	if _dying:
		return
	last_cause = cause
	_dying = true
	_death_fx_t = 0.0
	# ⚠ 摔落死觸發的當下玩家已經在畫面底緣**之下**，照玩家位置畫等於畫在畫面外＝沒演。
	#   那一種改畫在畫面底緣往上一點的位置（使用者指定），見 SpikeConfig SECTION 6c。
	if cause == CAUSE_FALL:
		_death_fx_pos = Vector2(
			player.pos.x, _view_bottom() - SpikeConfig.DEATH_FX_FALL_INSET
		)
	else:
		_death_fx_pos = player.pos
	# 碎片走全域 randf（同 _spawn_sparks 的理由：純表現，不該污染生成器的亂數序列）
	_death_fx_shards.clear()
	for _i in range(SpikeConfig.DEATH_FX_SHARD_COUNT):
		var s := Spark.new()
		s.pos = _death_fx_pos
		var ang := randf_range(0.0, TAU)
		var spd := randf_range(
			SpikeConfig.DEATH_FX_SHARD_SPEED_MIN, SpikeConfig.DEATH_FX_SHARD_SPEED_MAX
		)
		s.vel = Vector2(cos(ang), sin(ang)) * spd
		s.life = SpikeConfig.DEATH_FX_DURATION
		_death_fx_shards.append(s)
	queue_redraw()


## 推進爆炸；演完才把棒子交給 main.gd。
func _tick_death_fx(delta: float) -> void:
	_death_fx_t += delta
	for s in _death_fx_shards:
		s.vel.y += SpikeConfig.DEATH_FX_SHARD_GRAVITY * delta
		s.pos += s.vel * delta
	if _death_fx_t < SpikeConfig.DEATH_FX_DURATION:
		return
	# ⚠ running 在這裡才關（不是 _die() 當下）：提早關掉的話 _process 第一行就 return，
	#   爆炸一幀都推不動。
	_dying = false
	running = false
	died.emit(last_cause)


## main.gd 用它擋掉死亡演出期間的暫停鍵：那 0.55 秒按暫停會把爆炸凍在半途，
## 玩家回來還得再看一次結局，沒有任何好處。
func is_dying() -> bool:
	return _dying


## 踩頭／撞飛殺怪的共同出口：把牠往遠離玩家的方向拋出去，並擲一次鞭子回復。
##
## 方向取「怪物相對玩家」的水平符號——踩頭時兩者 x 幾乎重合，signf 會回 0，
## 這時改用玩家當下的水平速度符號（順著玩家的動勢掃開），再不行才預設往右。
##
## ⚠ 鞭子回復只掛在這條路徑上，不含「鞭中怪物」（見 SpikeConfig 的
##   MONSTER_KILL_WHIP_REFUND_CHANCE）：鞭子殺怪再退鞭子會變成自我循環。
func _kill_monster(m: WellMonster) -> void:
	var dx := m.pos.x - player.pos.x
	if absf(dx) < 1.0:
		dx = player.total_vel_x()
	m.kill(1.0 if dx >= 0.0 else -1.0)
	_count_monster_kill()
	if randf() < SpikeConfig.MONSTER_KILL_WHIP_REFUND_CHANCE:
		whip.refund()


## 擊殺計數的單一入口（BAD chattini 成就）。⚠ 有兩條擊殺路徑，兩條都得走這裡：
##   ① 踩頭／無敵撞飛 → _kill_monster（上面）
##   ② 鞭中怪物 → whip.fire() 內部直接 kill()，所以由 _unhandled_input 的命中分支補呼叫
## 少接一條就是「打倒 100 隻」永遠差一截，而且不會有任何錯誤訊息。
func _count_monster_kill() -> void:
	monster_kill_count += 1
	SpikeSave.bump_stat("monsters_killed")
	_report_progress()


## 物資：碰到即收。判定框往外擴一點，因為玩家多半是高速穿過而不是停在上面。
## 燃料補給滿載時不消耗（refill_fuel 回 false），留在原地等玩家用掉一些再回來——
## 「滿的時候撿到等於白撿」是玩家最容易記恨的一種浪費。
func _check_pickups() -> void:
	var pad := SpikeConfig.PICKUP_GRAB_PAD
	var pr := player.rect().grow(pad)
	for pk in gen.pickups:
		if not (pk.alive and pr.intersects(pk.rect())):
			continue
		if pk.kind == WellPickup.Kind.FUEL:
			if player.refill_fuel():
				pk.alive = false
				fuel_count += 1
		elif pk.kind == WellPickup.Kind.TOMB:
			# 墓碑一次給一大筆（TOMB_COIN_REWARD），直接併進這局金幣，不另立幣別
			pk.alive = false
			coin_count += SpikeConfig.TOMB_COIN_REWARD
		else:
			pk.alive = false
			coin_count += SpikeConfig.COIN_PER_PICKUP


## 蟲洞：碰到就進入過場（不是瞬間傳送），出口是生成時就綁好的一塊平台。
## 過場結束會把玩家放在出口平台正上方並直接給一次跳躍初速——等同「剛剛踩到那塊板」，
## 出來就有明確的下一步，不會出現「我在半空中，下面什麼都沒有」的不可歸因死法。
func _check_wormholes() -> void:
	var pr := player.rect().grow(SpikeConfig.WORMHOLE_GRAB_PAD)
	for wh in gen.wormholes:
		if not wh.ready_to_use():
			continue
		if not pr.intersects(wh.rect()):
			continue
		_begin_wormhole_travel(wh)
		return


## 蟲洞過場：凍結玩家＋讓相機／玩家各自沿同一條 smoothstep(t) 時間軸滑到出口，
## WORMHOLE_TRAVEL_TIME 秒後才真正落地（見 _step_wormhole_travel／_finish_wormhole_travel）。
##
## 設計選擇：相機與玩家各自用同一個 t 緩動到「自己的」終點，而不是把玩家焊死在相機的
## 固定螢幕偏移上。焊死的做法要嘛在終點強行 snap（畫面跳一下），要嘛出口的取景就不能沿用
## reset() 那套 CAMERA_START_RATIO 公式。兩條曲線共用同一個 t，讀起來仍是「一起被吸上去」，
## 但終點保證精確落在出口平台、相機也保證收斂到跟舊版瞬間傳送同一個公式算出來的位置。
##
## ⚠ 相機永不下降：_wh_travel_to_cam_y 用 minf 硬夾在 _wh_travel_from_cam_y 之下，
##   哪怕未來 WORMHOLE_RISE_M 被調到很小，也不會讓過場把相機往回拉。
func _begin_wormhole_travel(wh: WellWormhole) -> void:
	var exit_plat: WellPlatform = wh.exit_platform
	wh.alive = false
	wormhole_count += 1

	# 拉扯中／瞄準中進洞：先收掉，過場凍結期間不會有「一半在拉扯一半在飛」的怪狀態
	if player.is_pulled():
		whip.end_pull()
		player.state = WellPlayer.State.NORMAL
	if whip.state == Whip.State.AIMING:
		whip.cancel_aim()
		_end_slowmo()

	_wh_travel_timer = 0.0
	_wh_travel_from_cam_y = cam_y
	_wh_travel_from_pos = player.pos
	_wh_travel_to_pos = Vector2(exit_plat.pos.x, exit_plat.top_y() - player.size.y * 0.5)
	_wh_travel_to_cam_y = minf(
		_wh_travel_to_pos.y - (SpikeConfig.CAMERA_START_RATIO - 0.5) * SpikeConfig.VIEW_H,
		_wh_travel_from_cam_y
	)
	_wh_travel_active = true

	# 凍結物理：過場期間不吃重力、不會被投擲物的推力污染、鍵盤/滑鼠也改不動速度
	# （_step_player 這整段這幀開始就不會被呼叫了，見 _process 的分支）
	player.vel_y = 0.0
	player.control_vel_x = 0.0
	player.shock_vel_x = 0.0
	player.doom_vel = Vector2.ZERO
	player.jetpack_on = false
	player.jetpack_hold = 0.0
	# 過場期間玩家對自己的處境沒有任何發言權，比照鞭子／jetpack 給整段無敵
	player.refresh_invuln()


## 每幀把相機與玩家沿各自的 smoothstep(t) 曲線推向終點；t 到 1 就收尾。
func _step_wormhole_travel(delta: float) -> void:
	player.refresh_invuln()
	_wh_travel_timer += delta
	var t: float = clampf(_wh_travel_timer / SpikeConfig.WORMHOLE_TRAVEL_TIME, 0.0, 1.0)
	var eased: float = smoothstep(0.0, 1.0, t)

	cam_y = lerpf(_wh_travel_from_cam_y, _wh_travel_to_cam_y, eased)
	player.pos = _wh_travel_from_pos.lerp(_wh_travel_to_pos, eased)
	camera.position = Vector2(SpikeConfig.VIEW_W * 0.5, cam_y)

	if t >= 1.0:
		_finish_wormhole_travel()


## 過場結束：把玩家釘死在出口平台上緣（不是浮空、不是穿板），給一次跳躍初速讓玩家
## 出來就有明確下一步；相機收斂到的位置跟舊版瞬間傳送同一條公式，_update_camera 接手時
## 只會看到「玩家剛好在預期位置附近」——相機本身只有 _update_camera 一處會動它，且那裡
## 只會拉高（cam_y -= ...）不會拉低，所以過場結束不可能觸發「相機被玩家拖回去」。
func _finish_wormhole_travel() -> void:
	player.pos = _wh_travel_to_pos
	cam_y = _wh_travel_to_cam_y
	camera.position = Vector2(SpikeConfig.VIEW_W * 0.5, cam_y)

	player.vel_y = SpikeSave.jump_velocity()
	player.control_vel_x = 0.0
	player.ledge_used = false
	player.refresh_invuln()

	_wh_travel_active = false
	_stream_world()


func _update_camera() -> void:
	# 觸發線制：玩家越過畫面上方的觸發線，相機才被「頂」上去；相機永不下降。
	# 玩家因此會在畫面上上下浮動——這正是漏接一塊板還救得回來的原因。
	var trigger_y: float = cam_y \
		- SpikeConfig.VIEW_H * (0.5 - SpikeConfig.CAMERA_SCROLL_TRIGGER)
	if player.pos.y < trigger_y:
		cam_y -= trigger_y - player.pos.y
	camera.position = Vector2(SpikeConfig.VIEW_W * 0.5, cam_y)


func _stream_world() -> void:
	gen.ensure_generated_to(cam_y - SpikeConfig.VIEW_H)
	gen.prune_below(cam_y + SpikeConfig.VIEW_H)


func _check_end() -> void:
	best_m = maxf(best_m, SpikeConfig.meters_from_y(start_y, player.pos.y))

	# speed run：局中就成立的成就，所以在這裡即時問一次而不是等結算。
	# ⚠ 只問一次（_speedrun_checked）：跨過 500m 的那一刻要嘛已經在 2 分鐘內、要嘛
	#   已經超時，之後再問一萬次答案都一樣，每幀重問是純粹的浪費。
	if not _speedrun_checked and best_m >= SpikeConfig.SPEEDRUN_HEIGHT_M:
		_speedrun_checked = true
		_report_progress()

	# 登頂（08-10 關卡制重新接回）：抵達本關的 goal_meters 就成功結算。
	# ⚠ 走 eff_has_goal() 而不是直接讀 SpikeSave.endless_mode——模式規則的家在
	#   SpikeConfig（見那個函式的 ⚠）。無盡模式沒有終點，這一段整段不成立。
	# ⚠ 順序在墜落判定之前：同一幀既到達終點又掉出畫面時，應該算登頂而不是摔死
	#   （實務上碰不到，但兩個 running = false 的出口誰先誰後不該是碰運氣）。
	# ⚠ running = false 之後這個函式不會再被呼叫，所以 cleared 只會 emit 一次；
	#   若哪天 _check_end 改成不看 running 就要另外加旗標。
	if SpikeConfig.eff_has_goal() and best_m >= SpikeConfig.goal_meters:
		running = false
		cleared.emit()
		return

	if player.pos.y - player.size.y * 0.5 > _view_bottom():
		running = false
		_die(CAUSE_FALL)


## 把「當下的局內狀況」餵給成就判定，有新解鎖就 emit 讓 UI 放橫幅。
## ⚠ 這裡永遠帶 cleared = false：登頂類成就一律由 main.gd 的結算路徑
##   （SpikeSave.report_run_end）判定，局中不可能已經登頂。
## ⚠ 不落盤。stats 累積在記憶體裡，寫檔統一在 report_run_end 收尾一次。
func _report_progress() -> void:
	var fresh := SpikeSave.check_achievements({
		"cleared": false,
		"whip_used": whip.used(),
		"jetpack_used": jetpack_used,
		"best_m": best_m,
		"elapsed": elapsed,
	})
	if not fresh.is_empty():
		achievement_unlocked.emit(fresh)


# ============================================================
# 輸入
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == _aim_trigger_key():
			if whip.state == Whip.State.AIMING:
				whip.cancel_aim()
				_end_slowmo()
			elif whip.can_aim() and not player.is_pulled():
				whip.start_aim()
				_begin_slowmo()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if whip.state == Whip.State.AIMING:
			_end_slowmo()
			var res := whip.fire(player.pos, gen.platforms, gen.monsters)
			# 鞭中怪物＝擊殺（whip.fire 內部已經 kill 掉了），這裡只補計數——
			# 見 _count_monster_kill 的 ⚠：兩條擊殺路徑都得接上。
			# ⚠ 條件要跟 whip.fire 裡真正呼叫 kill() 的那一行完全一致（含 obj != null），
			#   不然條件放寬一點就變成「射到怪物但沒殺掉也算一隻」。
			if res["kind"] == "monster" and res["obj"] != null:
				_count_monster_kill()
			if res["hit"]:
				player.start_pull(res["point"])
			get_viewport().set_input_as_handled()


## 瞄準觸發鍵由設定頁決定（預設 E）。開火鍵不變，一律滑鼠左鍵。
func _aim_trigger_key() -> int:
	return SpikeKeys.key_of("aim")


func force_cancel_aim() -> void:
	if whip.state == Whip.State.AIMING:
		whip.cancel_aim()
	_end_slowmo()


# ============================================================
# 開發者傳送（只在 SpikeConfig.dev_mode() 為真時按得到，見 SECTION 11）
# ============================================================

## 一按往上送 DEV_TELEPORT_M 公尺，讓高處的內容不必真的爬上去才測得到。
##
## ⚠ 08-10 五訂（使用者拍板）：不再標記作弊局。這是測試用的傳送鈕，只在
##   `SpikeConfig.dev_mode()` 為真時才建得出來，一般玩家完全碰不到，標記不留痕反而
##   讓「快速跳到高處測試」跟正常結算脫節——現在成績、成就、解關一律正常回報。
## ⚠ 相機要跟著同步移動：只搬玩家的話這一幀相機還在原處，玩家會直接落在畫面外，
##   下一次 _check_end 就判定「掉出畫面」摔死。
## ⚠ 搬完要立刻串流：目的地上方的井還沒生成，不先 ensure_generated_to 就是站在虛空裡。
## ⚠ 給一次無敵窗：目的地可能正好疊到怪物或黑洞，傳送落地即死是不可歸因的。
func dev_teleport_up() -> void:
	if not running or _dying:
		return
	force_cancel_aim()
	player.abort_pull()

	var dy: float = SpikeConfig.DEV_TELEPORT_M * SpikeConfig.PIXELS_PER_METER
	player.pos.y -= dy
	player.vel_y = 0.0
	player.doom_vel = Vector2.ZERO
	player.refresh_invuln()
	cam_y -= dy
	camera.position = Vector2(SpikeConfig.VIEW_W * 0.5, cam_y)
	_stream_world()
	queue_redraw()


func _begin_slowmo() -> void:
	Engine.time_scale = SpikeConfig.WHIP_AIM_TIME_SCALE


func _end_slowmo() -> void:
	Engine.time_scale = 1.0


# ============================================================
# 對 UI 的輸出
# ============================================================

func hud_data() -> Dictionary:
	return {
		"height_m": SpikeConfig.meters_from_y(start_y, player.pos.y),
		"best_m": best_m,
		"goal_m": SpikeConfig.goal_meters,
		"elapsed": elapsed,
		# 倒數計時：歸零＝ Raora 登場。歸零後這個值一直是 0，UI 改顯示干擾已持續多久。
		# ⚠ 走 eff_：極限模式下登場等待是 0，倒數要從第一幀就是「已登場」。
		"countdown": maxf(0.0, SpikeConfig.eff_interference_start() - elapsed),
		"interference_active": interference.active(),
		"whip_charges": whip.charges,
		"whip_max": whip.max_charges,
		"jetpack_ratio": player.jetpack_ratio(),
		"interference": interference.stage_label(),
		"aiming": whip.state == Whip.State.AIMING,
		"aim_ratio": whip.aim_ratio(),
		"coins": coin_count,
		"invuln": player.is_invulnerable(),
	}


func result_data() -> Dictionary:
	return {
		"best_m": best_m,
		"goal_m": SpikeConfig.goal_meters,
		# 這一局的關卡與模式。⚠ 由結算頁與解鎖流程共用，讓 main.gd 不必自己再問一次
		# SpikeSave——「這一局是哪一關」要跟這局的其他數據一起走同一條路。
		"level": SpikeSave.selected_level,
		"endless": not SpikeConfig.eff_has_goal(),
		"elapsed": elapsed,
		"whip_used": whip.used(),
		"whip_max": whip.max_charges,
		"coins": coin_count,
		"fuels": fuel_count,
		"wormholes": wormhole_count,
		"stomps": stomp_count,
		"bumps": bump_count,
		# --- 以下是成就判定要的（SpikeSave.report_run_end 讀它們）---
		"jetpack_used": jetpack_used,
		"monster_kills": monster_kill_count,
		"fragile_broken": fragile_broken_count,
		"launchers_used": launcher_used_count,
		# ⚠ 布林值而不是死因字串：死因文案改了不該讓 BIG CAT 靜默失效
		"death_by_projectile": last_cause == CAUSE_PROJECTILE,
	}


# ============================================================
# 繪製（placeholder：純色矩形）
# ============================================================

func _view_top() -> float:
	return cam_y - SpikeConfig.VIEW_H * 0.5


func _view_bottom() -> float:
	return cam_y + SpikeConfig.VIEW_H * 0.5


func _draw() -> void:
	if gen == null:
		return
	var top := _view_top()
	var bot := _view_bottom()

	draw_rect(Rect2(0.0, top, SpikeConfig.WALL_THICKNESS, SpikeConfig.VIEW_H), SpikeConfig.C_WALL)
	draw_rect(
		Rect2(SpikeConfig.WELL_RIGHT, top, SpikeConfig.WALL_THICKNESS, SpikeConfig.VIEW_H),
		SpikeConfig.C_WALL
	)
	draw_line(
		Vector2(SpikeConfig.WELL_LEFT, top), Vector2(SpikeConfig.WELL_LEFT, bot),
		SpikeConfig.C_WALL_EDGE, 3.0
	)
	draw_line(
		Vector2(SpikeConfig.WELL_RIGHT, top), Vector2(SpikeConfig.WELL_RIGHT, bot),
		SpikeConfig.C_WALL_EDGE, 3.0
	)
	_draw_depth_ticks(top, bot)

	var gy := SpikeConfig.goal_y(start_y)
	if gy > top - SpikeConfig.VIEW_H and gy < bot + SpikeConfig.VIEW_H:
		draw_line(
			Vector2(SpikeConfig.WELL_LEFT, gy), Vector2(SpikeConfig.WELL_RIGHT, gy),
			SpikeConfig.C_GOAL, 5.0
		)

	for p in gen.platforms:
		if p.alive:
			draw_rect(p.rect(), p.color())

	# ⚠ 怪物畫在平台之後（上層）不只是層次好看：pameloe 懸在半空，垂直上可能跟後來才
	#   生成的平台重疊（見 WellGenerator._make_pameloe 的 ⚠），被平台蓋住的即死物
	#   跟看不見的黑洞是同一種不可歸因的死法。
	for m in gen.monsters:
		if m.dying:
			_draw_dying_monster(m)
			continue
		if not m.alive:
			continue
		if m.kind == WellMonster.Kind.PAMELOE:
			_draw_pameloe(m)
			continue
		_draw_patrol_monster(m)

	# 三種物資用形狀分辨，不是只靠顏色：金幣是圓的、燃料是圓角直立罐（帶一條亮口）、
	# 墓碑是圓頂石板。高速掠過時形狀比色相好認，何況色盲玩家分不出黃綠。
	for pk in gen.pickups:
		if not pk.alive:
			continue
		if pk.kind == WellPickup.Kind.FUEL:
			_draw_fuel(pk)
		elif pk.kind == WellPickup.Kind.TOMB:
			_draw_tomb(pk)
		else:
			_draw_coin(pk)

	for wh in gen.wormholes:
		if wh.ready_to_use():
			_draw_wormhole(wh)

	# 黑洞畫在平台與投擲物之後：它是致命區，被任何東西蓋住都可能變成不可歸因的死法
	_draw_doom_warns()
	for d in interference.dooms:
		if d.alive:
			_draw_doom(d)

	for pj in interference.projectiles:
		if pj.alive:
			_draw_projectile(pj)

	_draw_pameloe_shots()
	_draw_pameloe_lasers()
	# 爆炸區畫在投擲物與火花之間、玩家之前：它是致命區，被任何東西蓋住都可能變成
	# 不可歸因的死法（同黑洞那條）。
	_draw_blasts()
	_draw_proj_warns(top)
	_draw_sparks()

	_draw_whip()

	if _ledge_fx_active:
		_draw_ledge_fx()

	# 側風預警畫在最後（玩家之前）：它是 HUD 性質的滿版提示，被平台蓋住就失去意義
	_draw_shockwave_warn(top)

	if _dying:
		# 死掉的人不再畫出來——爆炸就是他現在的位置。留著矩形會讓畫面看起來像還活著，
		# 而且摔落死那一種矩形本來就在畫面外，畫了也看不到。
		_draw_death_fx()
	else:
		_draw_player_sprite()


## 描邊取樣方向（八方）。⚠ 斜角那四個要除以 √2，否則對角線的描邊會比上下左右厚
##   1.41 倍，輪廓看起來像被削成菱形。
const OUTLINE_DIRS: Array[Vector2] = [
	Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
	Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071),
]


## 三態選貼圖：落地閃現（steady）優先於 jetpack，jetpack 優先於一般 airborne（jump）。
## 三張畫布尺寸完全一致，用同一個 KAELA_FEET_ANCHOR_FRAC 錨點定位——只換材質、
## 不重算位置，切換姿勢時角色不會跳動（見 SECTION 9b 的錨點量法說明）。
## ⚠ 缺材質（匯入漏掉／路徑錯）就退回原本的色塊，不要讓玩家整個消失看不見。
func _draw_player_sprite() -> void:
	var tex: Texture2D = _kaela_jump_tex
	var sil: Texture2D = _kaela_jump_sil
	if player.land_flash_timer > 0.0:
		tex = _kaela_steady_tex
		sil = _kaela_steady_sil
	elif player.jetpack_on:
		tex = _kaela_jetpack_tex
		sil = _kaela_jetpack_sil

	# 無敵窗要看得見，否則玩家不會知道自己這 0.5 秒可以直接撞怪物。
	# 亮度隨剩餘時間衰減 ⇒ 讀得到的是「還剩多久」，不只是「現在無敵」。
	var invuln_col := Color(0.0, 0.0, 0.0, 0.0)
	if player.is_invulnerable():
		var a: float = clampf(player.invuln_timer / SpikeConfig.INVULN_GRACE, 0.0, 1.0)
		invuln_col = Color(SpikeConfig.C_INVULN, 0.35 + 0.5 * a)

	if tex == null:
		draw_rect(player.rect(), SpikeConfig.C_PLAYER)
		# 沒貼圖就沒有 alpha 輪廓可描，退回原本的外框。fallback 只求看得見。
		if invuln_col.a > 0.0:
			draw_rect(player.rect().grow(5.0), invuln_col, false, 3.0)
		return

	var art_size := SpikeConfig.KAELA_ART_SIZE
	var art_pos := Vector2(
		player.pos.x - art_size.x * 0.5,
		player.bottom() - art_size.y * SpikeConfig.KAELA_FEET_ANCHOR_FRAC
	)
	var rect := Rect2(art_pos, art_size)
	# kaela_*.png 原圖畫的是面向左，所以「面向右」才要鏡像（寬度取負），
	# 面向左直接照原圖畫。08-09 曾寫反（面向左才鏡像），導致按 A/D 時
	# 貼圖朝向跟移動方向相反，真人試玩抓到後在此修正。
	# ⚠ 負寬度是**原地**鏡像：position 仍是左緣、只把內容左右翻，不要再自己補
	#   `+ art_size.x` 去「翻到另一邊」——那會讓角色整個右移一個身寬（實測踩過）。
	if player.facing > 0.0:
		rect = Rect2(art_pos, Vector2(-art_size.x, art_size.y))

	if invuln_col.a > 0.0 and sil != null:
		_draw_sprite_outline(sil, rect, invuln_col, SpikeConfig.KAELA_OUTLINE_WIDTH)
	draw_texture_rect(tex, rect, false)


## 沿貼圖 alpha 輪廓的描邊：純白剪影往八方各偏 w、畫在本體底下，露出來的那一圈
## 就是輪廓線——貼合那張圖的形狀，不是外接矩形。
## 三個用途共用這一個函式（Kaela 無敵窗、蟲洞常駐金光、Pameloe 充能圈），各自帶自己的
## 寬度與顏色進來。⚠ 共用是刻意的：三處各抄一份的話，「輪廓描邊」這件事就有三種畫法，
##   改一處不會連動另外兩處。
## ⚠ 呼叫端要在畫本體**之前**呼叫——這條線靠的是被本體蓋掉中間、只露出外圈。
## ⚠ 傳進來的必須是剪影不是原圖（理由見 _kaela_*_sil 的 ⚠⚠）。
## ⚠ 不改用 shader：draw_texture_rect 吃的是整個 CanvasItem 的 material，掛上去會連
##   平台、怪物、特效全部一起描邊（本檔所有繪製都在同一個 _draw()）。
func _draw_sprite_outline(sil: Texture2D, rect: Rect2, col: Color, w: float) -> void:
	for d in OUTLINE_DIRS:
		draw_texture_rect(
			sil, Rect2(rect.position + d * w, rect.size), false, col
		)


## 死亡爆炸（placeholder：擴散環 ＋ 中心亮球 ＋ 四散碎片）。
## ⚠ 使用者之後會補真的爆炸素材——換的時候整個函式換掉即可，SECTION 6c 的時長／半徑
##   常數要留著：時長是手感，換素材不該連帶把節奏一起改掉。
func _draw_death_fx() -> void:
	var t: float = clampf(_death_fx_t / SpikeConfig.DEATH_FX_DURATION, 0.0, 1.0)
	var fade: float = 1.0 - t
	var r: float = lerpf(
		SpikeConfig.DEATH_FX_RADIUS_START, SpikeConfig.DEATH_FX_RADIUS_END, t
	)
	draw_arc(
		_death_fx_pos, r, 0.0, TAU, 48, Color(SpikeConfig.C_DEATH_FX, fade),
		SpikeConfig.DEATH_FX_RING_WIDTH
	)
	draw_circle(
		_death_fx_pos, r * SpikeConfig.DEATH_FX_CORE_RATIO,
		Color(SpikeConfig.C_DEATH_FX_CORE, fade)
	)
	var side: float = SpikeConfig.DEATH_FX_SHARD_SIZE
	for s in _death_fx_shards:
		draw_rect(
			Rect2(s.pos - Vector2(side, side) * 0.5, Vector2(side, side)),
			Color(SpikeConfig.C_DEATH_FX, fade)
		)


## 巡邏怪（chattini）：08-10 換成 monster_chattini.png，依 facing() 左右鏡像；缺檔退回
## 原本的純色矩形 ＋ 上緣可踩亮線。
## ⚠ 鏡像方向跟 kaela 貼圖同一個坑，08-10 真人試玩確認**來源圖面向右**（跟 kaela 相反）：
##   往左走（facing < 0）才要鏡像。原本猜「面向左」整段方向是反的，已修正——不需要再猜，
##   往後如果換圖，先用 visual_check.tscn 肉眼比對兩個巡邏方向再動這個條件。
func _draw_patrol_monster(m: WellMonster) -> void:
	var mr: Rect2 = m.rect()
	if _monster_tex == null:
		draw_rect(mr, SpikeConfig.C_MONSTER)
		draw_line(
			mr.position, mr.position + Vector2(mr.size.x, 0.0), SpikeConfig.C_TEXT, 3.0
		)
		return
	var art_size := SpikeConfig.MONSTER_ART_SIZE
	# 縱向錨點＝腳底貼齊平台上緣，不是中心對齊、也不是貼判定框底邊（判定框 08-10 踩頭
	# 手感修正後已經不貼平台了，見 WellMonster.rect()）。平台上緣＝ pos.y + size.y*0.5，
	# 這個關係由 step()／WellGenerator._make_monster 的擺放公式保證恆成立，跟判定框
	# 現在怎麼畫無關。見 SpikeConfig.MONSTER_ART_FEET_FRAC。
	var foot_y: float = m.pos.y + m.size.y * 0.5
	var art_pos := Vector2(
		m.pos.x - art_size.x * 0.5,
		foot_y - art_size.y * SpikeConfig.MONSTER_ART_FEET_FRAC
	)
	var rect := Rect2(art_pos, art_size)
	if m.facing() < 0.0:
		rect = Rect2(art_pos, Vector2(-art_size.x, art_size.y))
	draw_texture_rect(_monster_tex, rect, false)


## 死亡中的怪物：邊轉邊飛、邊淡出。不畫上緣那條「可踩」亮線——牠已經不能踩了，
## 留著會讓玩家去追一個踩不到的目標。
## ⚠ 死亡演出一律**中心對齊**，不套 MONSTER_ART_FEET_FRAC：屍體正在邊轉邊飛，
##   「腳底」不再是任何東西的基準線，用腳底錨點會讓牠繞著自己的腳旋轉。
func _draw_dying_monster(m: WellMonster) -> void:
	var a := m.death_alpha()
	var tex: Texture2D = _monster_tex
	var art_size := SpikeConfig.MONSTER_ART_SIZE
	if m.kind == WellMonster.Kind.PAMELOE:
		tex = null if _pameloe_texs.is_empty() \
			else _pameloe_texs[clampi(m.art_variant, 0, _pameloe_texs.size() - 1)]
		art_size = SpikeConfig.PAMELOE_ART_SIZE
	if tex != null:
		draw_set_transform(m.pos, m.spin, Vector2.ONE)
		# 白色 modulate 才是「原色 × alpha 淡出」——modulate 是乘法，見常青認知第 8 條①。
		draw_texture_rect(tex, Rect2(-art_size * 0.5, art_size), false, Color(1.0, 1.0, 1.0, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var col: Color = SpikeConfig.C_MONSTER
	if m.kind == WellMonster.Kind.PAMELOE:
		col = SpikeConfig.C_PAMELOE
	draw_set_transform(m.pos, m.spin, Vector2.ONE)
	draw_rect(Rect2(-m.size * 0.5, m.size), Color(col, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pameloe：本體矩形 ＋ 上緣可踩亮線 ＋ 左右兩片純視覺的翼 ＋ 充能時的外圈脈動。
##
## ⚠ 本體畫的就是 rect()，不多不少。畫成圓形或菱形會讓 AABB 判定框的四個角落在視覺
##   之外——對一個「碰到即死」的東西來說那就是不可歸因的死法（同 SpikeConfig 對黑洞
##   「判定用圓不用矩形」的推理，只是方向相反：黑洞畫成圓所以判定用圓，牠判定是
##   矩形所以就畫矩形）。
## ⚠ 翼刻意畫在本體**之外**且半透明：玩家一眼要分得出哪一塊會殺人。翼不參與任何判定。
## ⚠ 上緣亮線跟巡邏怪共用同一套語彙——那條線的意思一直都是「這裡可以踩」。
func _draw_pameloe(m: WellMonster) -> void:
	var r: Rect2 = m.rect()
	# 08-10：兩張立繪擇一（art_variant 在生成當下就骰好了，這裡不骰）。
	# ⚠ 中心對齊、不用腳底錨點——牠是懸浮的，判定框留在視覺正中才對得上原本
	#   「本體畫的就是 rect()」那條可歸因性推理（見 SpikeConfig.PAMELOE_ART_SIZE）。
	# ⚠ 充能閃爍照畫在貼圖之上：那圈是「牠要開火了」的唯一預告，換貼圖不能把它換掉。
	if not _pameloe_texs.is_empty():
		var art_size := SpikeConfig.PAMELOE_ART_SIZE
		var art_rect := Rect2(m.pos - art_size * 0.5, art_size)
		# 08-10 二訂：依上一次開火方向鏡像（同 _draw_player_sprite 的負寬度手法，常青認知
		# 第 8 條②）。要在算出充能圈的外框**之前**先決定翻不翻，否則充能圈會照著沒翻的
		# 形狀描邊，跟翻過的本體對不齊（同 _draw_player_sprite 的無敵窗描邊順序）。
		if m.facing() < 0.0:
			art_rect = Rect2(art_rect.position, Vector2(-art_size.x, art_size.y))
		var idx: int = clampi(m.art_variant, 0, _pameloe_texs.size() - 1)
		var tex: Texture2D = _pameloe_texs[idx]
		# 充能圈沿貼圖的 alpha 輪廓畫，而且要畫在本體**之前**（輪廓描邊靠本體蓋住中間）。
		# 08-10 二訂：原本沿 art_rect 畫長方形，那個框跟牠的形狀無關，看起來像牠被關在
		# 一個盒子裡；更早之前是沿判定框（44×44）畫，比貼圖小一半，真人試玩回報看不懂。
		var sil: Texture2D = null
		if idx < _pameloe_sils.size():
			sil = _pameloe_sils[idx]
		_draw_pameloe_charge(m, art_rect, sil)
		draw_texture_rect(tex, art_rect, false)
		return
	var wing := r.size.y * 0.30
	var wing_y := r.position.y + r.size.y * 0.32
	var wing_h := wing * 0.7
	var wing_col := Color(SpikeConfig.C_PAMELOE, 0.45)
	draw_rect(Rect2(r.position.x - wing, wing_y, wing, wing_h), wing_col)
	draw_rect(Rect2(r.end.x, wing_y, wing, wing_h), wing_col)

	draw_rect(r, SpikeConfig.C_PAMELOE)
	draw_line(r.position, r.position + Vector2(r.size.x, 0.0), SpikeConfig.C_TEXT, 3.0)

	_draw_pameloe_charge(m, r, null)


## 開火前的充能外圈。抽成獨立函式是因為貼圖版與純色 fallback 版都要畫它——
## ⚠ 兩條路各抄一份的話，改了其中一邊就會出現「某一種畫法沒有預告」的不可歸因死法。
## `sil` 有值＝沿貼圖 alpha 輪廓描邊（貼圖版走這條，`r` 傳 art_rect）；null＝沒有貼圖可
## 描輪廓的 fallback，退回沿判定框畫方框（fallback 的本體本來就是那個方框，框住的正是牠）。
## 08-10 二訂：固定寬度、不隨充能放大——放大會讓圈離開「貼圖外緣」這條線，
## 充能程度改用透明度表達（0.25 → 0.9）就夠。
func _draw_pameloe_charge(m: WellMonster, r: Rect2, sil: Texture2D) -> void:
	var c := m.charge_ratio()
	if c <= 0.0:
		return
	var col := Color(SpikeConfig.C_PAMELOE_CHARGE, 0.25 + 0.65 * c)
	if sil == null:
		draw_rect(r, col, false, 2.0)
		return
	_draw_sprite_outline(sil, r, col, SpikeConfig.PAMELOE_CHARGE_OUTLINE_WIDTH)


## Pameloe 的子彈：外暈 ＋ 亮心。外暈就是「看起來擦到了其實沒死」的那一圈——
## 視覺半徑大於判定半徑是刻意的（見 PameloeShot.rect 的 ⚠）。
func _draw_pameloe_shots() -> void:
	var rv: float = SpikeConfig.PAMELOE_SHOT_SIZE.x * 0.5
	for sh in _shots:
		if not sh.alive:
			continue
		draw_circle(sh.pos, rv, Color(SpikeConfig.C_PAMELOE_SHOT, 0.35))
		draw_circle(sh.pos, rv * 0.55, SpikeConfig.C_PAMELOE_SHOT)


## 雷射變體（08-10 三訂）的光束：外層寬而淡、內層窄而亮，跟子彈同一套「視覺比判定寬」
## 語彙，只是把圓換成線。⚠ 只畫還活著的 pameloe——本體被殺掉時 laser_active 已經在
## WellMonster.kill() 裡被關掉，這裡不用另外判斷 m.alive（讀 laser_active 就夠）。
##
## 08-10 四訂：實際光束之前先畫瞄準預警線——方向在充能起點就鎖定了（見
## WellMonster.lock_laser_aim），charge_ratio() 轉正代表正在充能，這裡直接讀已鎖定的
## laser_dir 畫一條細而閃的虛線，讓玩家在充能的整段時間都看得到牠要打哪。
## ⚠ 預警線不判定命中——`laser_hits()` 只吃 `laser_active`，充能期間站上去不會死，
##   跟其他三種干擾「預警期無傷、正式期才致命」同一條規則。
func _draw_pameloe_lasers() -> void:
	for m in gen.monsters:
		if m.kind != WellMonster.Kind.PAMELOE:
			continue
		if m.laser_active:
			var a: Vector2 = m.pos
			var b: Vector2 = m.laser_endpoint()
			draw_line(a, b, Color(SpikeConfig.C_PAMELOE_LASER, 0.35), SpikeConfig.PAMELOE_LASER_WIDTH)
			draw_line(a, b, SpikeConfig.C_PAMELOE_LASER, SpikeConfig.PAMELOE_LASER_WIDTH * 0.4)
		elif m.art_variant == 1 and m.charge_ratio() > 0.0:
			var aim_a: Vector2 = m.pos
			var aim_b: Vector2 = m.laser_endpoint()
			draw_dashed_line(
				aim_a, aim_b, Color(SpikeConfig.C_PAMELOE_LASER, 0.3 + 0.4 * m.charge_ratio()),
				2.0, 10.0
			)


## 墓碑：圓頂石板 ＋ 十字。立在平台上緣（不是浮著），跟金幣／燃料一眼分得開。
func _draw_tomb(pk: WellPickup) -> void:
	var r := Rect2(pk.pos - pk.size * 0.5, pk.size)
	var cap := r.size.x * 0.5                     # 圓頂半徑＝板寬的一半
	draw_rect(
		Rect2(r.position.x, r.position.y + cap, r.size.x, r.size.y - cap), SpikeConfig.C_TOMB
	)
	draw_circle(Vector2(pk.pos.x, r.position.y + cap), cap, SpikeConfig.C_TOMB)
	var cross_top := r.position.y + cap * 0.55
	draw_line(
		Vector2(pk.pos.x, cross_top), Vector2(pk.pos.x, r.position.y + r.size.y * 0.72),
		SpikeConfig.C_TOMB_CROSS, 3.0
	)
	var arm_y := cross_top + cap * 0.7
	draw_line(
		Vector2(pk.pos.x - cap * 0.55, arm_y), Vector2(pk.pos.x + cap * 0.55, arm_y),
		SpikeConfig.C_TOMB_CROSS, 3.0
	)


## 平台被削掉的火花。壽命同時是 alpha，燒完自然消失（回收在 _tick_sparks）。
func _draw_sparks() -> void:
	var s: Vector2 = SpikeConfig.SPARK_SIZE
	for sp in _sparks:
		var a: float = clampf(sp.life / SpikeConfig.SPARK_LIFE, 0.0, 1.0)
		draw_rect(Rect2(sp.pos - s * 0.5, s), Color(SpikeConfig.C_SPARK, a))


## 側風：畫面右緣的綠色長條。兩種狀態共用同一條——
##   ① 陣風前 2 秒：閃爍（預警）
##   ② 陣風進行中：常駐但更淡（告訴玩家「現在正在吹」）
## ⚠ 少了 ② 玩家會分不出「被推」是陣風還是自己操作失誤，那是不可歸因的挫折。
## ⚠ 畫在**右**緣，因為風從右邊來、把人往左推。畫錯邊等於指錯逃生方向。
## ⚠ 用當下的畫面上緣定位而不是世界座標——它是 HUD 性質的提示，跟著世界捲走就沒意義了。
func _draw_shockwave_warn(view_top: float) -> void:
	var alpha := 0.0
	if interference.shockwave_active():
		alpha = SpikeConfig.SHOCKWAVE_ACTIVE_ALPHA
	elif interference.shockwave_warn_on():
		alpha = SpikeConfig.SHOCKWAVE_WARN_ALPHA
	if alpha <= 0.0:
		return
	var w: float = SpikeConfig.SHOCKWAVE_WARN_WIDTH
	draw_rect(
		Rect2(SpikeConfig.VIEW_W - w, view_top, w, SpikeConfig.VIEW_H),
		Color(SpikeConfig.C_SHOCK_WARN, alpha)
	)


## 黑洞：全黑的事件視界 ＋ 兩道反向旋轉的紫弧 ＋ 一圈虛淡的吸力範圍環。
## ⚠ 吸力範圍一定要畫出來。看不見的力場＝玩家不知道自己為什麼被拉走，
##   那正是 PILLARS 要防的「不可歸因」。
func _draw_doom(d) -> void:
	var pr: float = SpikeConfig.DOOM_PULL_RADIUS
	draw_arc(d.pos, pr, 0.0, TAU, 48, Color(SpikeConfig.C_DOOM_RING, 0.14), 2.0)
	# 壽命快到時整個洞跟著淡出，玩家才知道「它要收了，可以過去了」
	var a: float = clampf(d.life / SpikeConfig.DOOM_LIFETIME, 0.0, 1.0)
	var fade: float = minf(1.0, a * 3.0)
	var r: float = SpikeConfig.DOOM_RADIUS
	draw_circle(d.pos, r * 1.35, Color(SpikeConfig.C_DOOM_RING, 0.12 * fade))
	draw_circle(d.pos, r, Color(SpikeConfig.C_DOOM, fade))
	draw_arc(d.pos, r, d.spin, d.spin + PI * 1.2, 24, Color(SpikeConfig.C_DOOM_RING, fade), 3.0)
	draw_arc(
		d.pos, r * 0.6, -d.spin * 1.6, -d.spin * 1.6 + PI * 0.9, 18,
		Color(SpikeConfig.C_DOOM_RING, 0.7 * fade), 2.0
	)


## 黑洞出現前的紫色半透明圈，閃爍 2 秒。畫在洞將要開的那個點上（跟著平台走）。
func _draw_doom_warns() -> void:
	for w in interference.doom_warns:
		if not w.blink_on():
			continue
		var col := Color(SpikeConfig.C_DOOM_WARN, SpikeConfig.DOOM_WARN_ALPHA)
		draw_circle(w.pos, SpikeConfig.DOOM_RADIUS, col)
		draw_arc(w.pos, SpikeConfig.DOOM_RADIUS, 0.0, TAU, 32, SpikeConfig.C_DOOM_WARN, 2.0)


## 爆炸平台的爆炸區（08-10）：擴散環 ＋ 中心亮球，整段淡出。
## ⚠⚠ **外環一律畫在 EXPLOSIVE_RADIUS 上、不隨演出進度縮放**：那圈就是致命範圍，畫成
##   會長大的圈等於前幾幀「看起來還沒碰到卻已經死了」。會動的是亮球與透明度，不是判定線。
##   （這跟死亡爆炸 _draw_death_fx 不一樣——那個是純特效，沒有判定要對齊。）
func _draw_blasts() -> void:
	var r: float = SpikeConfig.EXPLOSIVE_RADIUS
	for b in _blasts:
		var t: float = b.progress()
		var fade: float = 1.0 - t
		draw_circle(b.pos, r, Color(SpikeConfig.C_BLAST, fade * 0.35))
		draw_arc(
			b.pos, r, 0.0, TAU, 40, Color(SpikeConfig.C_BLAST, fade),
			SpikeConfig.EXPLOSIVE_BLAST_RING_WIDTH
		)
		draw_circle(
			b.pos, r * SpikeConfig.EXPLOSIVE_BLAST_CORE_RATIO * (1.0 - t * 0.5),
			Color(SpikeConfig.C_EXPLOSIVE_HOT, fade)
		)


## 撿取物的漂浮位移（08-10，使用者要求「微幅緩慢的上下晃動」）。
## ⚠⚠ **只給繪製用**——`WellPickup.rect()` 完全不看它，判定框一動也不動。金幣／燃料是
##   撿取物，這樣的誤差方向是「還沒碰到就撿到」，倒向對玩家有利的一邊。Pameloe 走的是
##   相反的路（判定跟著晃，做在 WellMonster.step()），理由見 SpikeConfig 漂浮那組的 ⚠⚠。
## ⚠ 用 `elapsed` 而不是另開一個累加器：它在死亡演出／未開局時本來就停著，漂浮跟著凍住，
##   自動符合「爆炸期間世界完全凍結」那條演出規則。多開一個計時器反而會在那時候繼續晃。
## ⚠⚠ 位移範圍是 **[-2×AMP, 0]（只往上）不是 ±AMP**：對稱晃動的下半段會讓金幣／燃料
##   底部插進平台裡（08-10 用 visual_check 拍出來才看到）。改成以「原位上方 AMP」為中心
##   之後，總晃幅一樣是 2×AMP，最低點回到原位（＝不晃時的靜止位置），不會晃得更低。
##   ⚠ 08-10 四訂：靜止位置本身也要離平台上緣留 2px（見 SpikeConfig.PICKUP_HOVER 的 ⚠⚠），
##   不再是「剛好貼齊」——貼齊在 fuel 的視覺尺寸下實測仍會卡進平台，見該常數推導。
##   ⚠ 這條只管金幣／燃料。Pameloe 懸在半空、腳下沒有東西可穿，維持對稱晃動。
func _pickup_float_offset(pk: WellPickup) -> Vector2:
	var s: float = sin(elapsed * SpikeConfig.PICKUP_FLOAT_SPEED + pk.float_phase)
	return Vector2(0.0, (s - 1.0) * SpikeConfig.PICKUP_FLOAT_AMP)


## 金幣：08-10 換成 coin.png ＋ 沿 alpha 輪廓的白光（缺檔退回原本的雙色圓）。
## ⚠ 白光必須畫在本體**之前**（見 _draw_sprite_outline 的 ⚠）。
## ⚠ art 矩形讀 COIN_ART_SIZE 不是 `pk.size`：後者是判定框，art 的 **alpha 內容**才是
##   對齊它 2 倍的那一個（來源圖有透明留白，見 SpikeConfig.COIN_ART_SIZE 的 ⚠⚠）。
func _draw_coin(pk: WellPickup) -> void:
	var c: Vector2 = pk.pos + _pickup_float_offset(pk)
	if _coin_tex == null:
		draw_circle(c, pk.size.x * 0.5, SpikeConfig.C_PICKUP)
		draw_circle(c, pk.size.x * 0.22, SpikeConfig.C_PICKUP_CORE)
		return
	var r := Rect2(c - SpikeConfig.COIN_ART_SIZE * 0.5, SpikeConfig.COIN_ART_SIZE)
	if _coin_sil != null:
		_draw_sprite_outline(
			_coin_sil, r, SpikeConfig.C_PICKUP_GLOW, SpikeConfig.PICKUP_OUTLINE_WIDTH
		)
	draw_texture_rect(_coin_tex, r, false)


## 燃料補給：08-10 換成 fuel.png ＋ 沿輪廓白光。缺檔退回原本的直立圓角罐 ＋ 上緣亮口
## （那個形狀是刻意不畫成圓形的，跟金幣一眼分得開——fallback 也要維持這條性質）。
func _draw_fuel(pk: WellPickup) -> void:
	var c: Vector2 = pk.pos + _pickup_float_offset(pk)
	if _fuel_tex == null:
		var r0 := Rect2(c - pk.size * 0.5, pk.size)
		draw_rect(r0, SpikeConfig.C_FUEL)
		draw_rect(
			Rect2(r0.position.x + 4.0, r0.position.y + 4.0, r0.size.x - 8.0, 5.0),
			SpikeConfig.C_FUEL_CORE
		)
		return
	var r := Rect2(c - SpikeConfig.FUEL_ART_SIZE * 0.5, SpikeConfig.FUEL_ART_SIZE)
	if _fuel_sil != null:
		_draw_sprite_outline(
			_fuel_sil, r, SpikeConfig.C_PICKUP_GLOW, SpikeConfig.PICKUP_OUTLINE_WIDTH
		)
	draw_texture_rect(_fuel_tex, r, false)


## 投擲物：邊落邊自轉，08-10 換成 cucumber.png 貼圖（缺檔退回純色長方形）。
## 判定框是另一回事（固定不轉的小矩形，見 Projectile.rect()）。
## draw_set_transform 把後續繪製整個旋轉，畫完務必還原，否則同一幀之後的東西全歪掉。
func _draw_projectile(pj) -> void:
	draw_set_transform(pj.pos, pj.spin, Vector2.ONE)
	var s: Vector2 = SpikeConfig.PROJECTILE_DRAW_SIZE
	if _projectile_tex != null:
		draw_texture_rect(_projectile_tex, Rect2(-s * 0.5, s), false)
	else:
		draw_rect(Rect2(-s * 0.5, s), SpikeConfig.C_PROJECTILE)
		draw_rect(Rect2(-s * 0.5, s), SpikeConfig.C_TEXT, false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 落點預警：畫面上緣、預計落點的 x 位置，一個朝下的閃爍三角形。
## ⚠ 畫在「當下的畫面上緣」而不是世界固定座標——它是 HUD 性質的提示，
##   必須永遠看得到，跟著世界捲走就失去意義了。
func _draw_proj_warns(view_top: float) -> void:
	var s: Vector2 = SpikeConfig.PROJECTILE_WARN_SIZE
	var y: float = view_top + SpikeConfig.PROJECTILE_WARN_MARGIN
	for w in interference.warns:
		if not w.blink_on():
			continue
		var pts := PackedVector2Array([
			Vector2(w.x - s.x * 0.5, y),
			Vector2(w.x + s.x * 0.5, y),
			Vector2(w.x, y + s.y),
		])
		draw_colored_polygon(pts, SpikeConfig.C_PROJ_WARN)


## 蟲洞：08-10 換成 the_sheep.png 貼圖，靜止不轉（來源就是一張站定的羊，硬套 wh.spin
## 轉起來會變成直升機羊，比原本的抽象漩渦還怪）。缺檔退回原本「暈開圓盤 ＋ 兩道反向
## 旋轉的弧 ＋ 亮核」的純色版本。
## ⚠ 常駐外緣金光（08-10 加，同日二訂）：**沿貼圖 alpha 輪廓**的暖金色描邊，模擬「背著
##   夕陽的逆光」——兩層疊畫（外層寬而淡、內層窄而亮）模擬柔光暈開的感覺，同 Pameloe 子彈
##   「外暈 ＋ 亮心」的畫法。初版畫的是外接長方形，框住的是畫布不是那隻羊，使用者回報後
##   改成跟 Kaela 無敵窗同一套剪影偏移描邊（_draw_sprite_outline）。**只在貼圖版畫**，
##   只是視覺點綴、不參與任何判定；缺檔 fallback 沒有輪廓可描，維持原本的純色版本不變。
func _draw_wormhole(wh: WellWormhole) -> void:
	if _wormhole_tex != null:
		var art_size := SpikeConfig.WORMHOLE_ART_SIZE
		# 基準線是**母平台上緣**而不是自己的判定框底邊：判定框浮在平台上緣往上
		# WORMHOLE_HOVER，貼齊框底仍會離平台 12px（見 SpikeConfig.WORMHOLE_ART_FEET_FRAC）。
		# `pos.y + WORMHOLE_HOVER` 由 offset 的定義反推得到，不依賴 host 還在不在。
		var base_y: float = wh.pos.y + SpikeConfig.WORMHOLE_HOVER
		var art_pos := Vector2(
			wh.pos.x - art_size.x * 0.5,
			base_y - art_size.y * SpikeConfig.WORMHOLE_ART_FEET_FRAC
		)
		var art_rect := Rect2(art_pos, art_size)
		# 金光要畫在本體**之前**：輪廓描邊靠的是被本體蓋掉中間、只露出外圈那一圈。
		# 外層先畫（寬而淡）、內層後畫（窄而亮），順序反過來會讓亮心被外暈蓋掉。
		if _wormhole_sil != null:
			_draw_sprite_outline(
				_wormhole_sil, art_rect,
				Color(SpikeConfig.C_WORMHOLE_GLOW, SpikeConfig.WORMHOLE_GLOW_OUTER_ALPHA),
				SpikeConfig.WORMHOLE_GLOW_OUTER_W
			)
			_draw_sprite_outline(
				_wormhole_sil, art_rect,
				Color(SpikeConfig.C_WORMHOLE_GLOW, SpikeConfig.WORMHOLE_GLOW_INNER_ALPHA),
				SpikeConfig.WORMHOLE_GLOW_INNER_W
			)
		draw_texture_rect(_wormhole_tex, art_rect, false)
		return
	var r: float = wh.size.x * 0.5
	draw_circle(wh.pos, r, Color(SpikeConfig.C_WORMHOLE, 0.28))
	draw_arc(wh.pos, r * 0.82, wh.spin, wh.spin + PI * 1.15, 22, SpikeConfig.C_WORMHOLE, 4.0)
	draw_arc(
		wh.pos, r * 0.52, -wh.spin * 1.7, -wh.spin * 1.7 + PI * 0.9, 18,
		SpikeConfig.C_WORMHOLE_CORE, 3.0
	)
	draw_circle(wh.pos, r * 0.2, SpikeConfig.C_WORMHOLE_CORE)


func _draw_whip() -> void:
	if player.is_pulled():
		draw_line(player.pos, player.pull_anchor, SpikeConfig.C_WHIP, 3.0)
		draw_circle(player.pull_anchor, 7.0, SpikeConfig.C_WHIP)
		return

	if whip.state == Whip.State.AIMING:
		# 只畫方向，不畫命中預覽——「3 秒內選錯方向」的失落感是 PILLARS 明文要的東西
		var d := (mouse_world() - player.pos).normalized()
		draw_line(
			player.pos, player.pos + d * SpikeConfig.WHIP_RANGE, SpikeConfig.C_AIM, 2.0
		)

	if whip.rope_flash > 0.0:
		var a: float = whip.rope_flash / SpikeConfig.WHIP_ROPE_FLASH
		var base: Color = SpikeConfig.C_WHIP if whip.rope_hit else SpikeConfig.C_TEXT_DIM
		draw_line(whip.rope_from, whip.rope_to, Color(base, a), 2.0)


## 攀爬手套成功的回饋：白色圓圈從觸發點往外擴同時淡出，半徑與 alpha 都是同一個
## [0,1] 進度算出來的，時間到（見 _tick_ledge_fx）就不再畫，純 _draw()，不吃資源檔。
func _draw_ledge_fx() -> void:
	var t: float = clampf(_ledge_fx_timer / SpikeConfig.LEDGE_FX_DURATION, 0.0, 1.0)
	var r: float = lerpf(SpikeConfig.LEDGE_FX_RADIUS_START, SpikeConfig.LEDGE_FX_RADIUS_END, t)
	var a: float = 1.0 - t
	draw_arc(
		_ledge_fx_pos, r, 0.0, TAU, 32,
		Color(SpikeConfig.C_LEDGE_FX, a), SpikeConfig.LEDGE_FX_LINE_WIDTH
	)


func _draw_depth_ticks(top: float, bot: float) -> void:
	var m_lo := int(floorf(SpikeConfig.meters_from_y(start_y, bot) * 0.1)) * 10
	var m_hi := int(ceilf(SpikeConfig.meters_from_y(start_y, top) * 0.1)) * 10
	if m_hi < m_lo:
		return
	for m in range(m_lo, m_hi + 10, 10):
		var y := start_y - float(m) * SpikeConfig.PIXELS_PER_METER
		var major := (m % 50) == 0
		var length: float = 26.0 if major else 12.0
		var col := Color(SpikeConfig.C_WALL_EDGE, 1.0 if major else 0.45)
		draw_line(
			Vector2(SpikeConfig.WELL_LEFT - length, y), Vector2(SpikeConfig.WELL_LEFT, y),
			col, 2.0
		)
		draw_line(
			Vector2(SpikeConfig.WELL_RIGHT, y), Vector2(SpikeConfig.WELL_RIGHT + length, y),
			col, 2.0
		)
