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
## 撞到 pameloe **本體**（08-13 三訂新增）。判定完全同 CAUSE_MONSTER（就是撞到怪物那條），
## 拆出來只為了結算大字分得出「chattini 殺的」還是「pameloe 殺的」——使用者的死亡文字表
## 把兩者分成不同句子。⚠ 既有的 CAUSE_MONSTER 語意因此收窄成「撞到 chattini」。
const CAUSE_PAMELOE_BODY := "撞到 Pameloe"

## 護盾（SECTION 8e）擋**不住**的死因。使用者規格：「可以抵銷一次死亡（掉落除外）」。
## ⚠⚠ 這份清單的家在這裡而不是 SpikeConfig：它比對的是上面那組 CAUSE_* 常數，抄成字串
##   放進 config 就會出現「改死因文案 ⇒ 護盾靜默失效」——不報錯、不變紅、只有玩家會
##   發現盾突然不擋了。用常數參照就不可能對不上。
## ⚠ 列的是「擋不住的」而不是「擋得住的」：日後新增一種死法時，預設會被護盾擋下。
##   那個方向的錯（玩家多活一次）遠比反過來（盾莫名其妙沒作用）容易被發現。
const SHIELD_IGNORED_CAUSES: Array[String] = [CAUSE_FALL]

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

## 08-10 續：第六批（平台四態，硬規則 4 例外六）。四張彼此獨立，各自缺檔各自退回
## 純色 `_draw_rect()`（不是「全有全無」，跟 PAMELOE_TEX_PATHS 那組互相依賴的特例不同）。
## ⚠ 08-11 使用者拍板兩件事（見 deviations.md「平台貼圖與尺寸」列）：
##   ① normal.png 只給 STATIC／EXPLOSIVE 共用，EXPLOSIVE **未觸發前外觀跟 STATIC 完全
##     一致**（不靠顏色分辨——踩下去引信燒起來才會亮，那才是它唯一的視覺差異）
##   ② move.png 給三種「會動」的共用（MOVING／VERTICAL／CIRCULAR），這三種才靠
##     WellPlatform.color() 的 modulate 顏色分方向，見 _draw_platform()。
const PLATFORM_NORMAL_TEX_PATH := "res://assets/sprites/platform_normal.png"
const PLATFORM_BREAK_TEX_PATH := "res://assets/sprites/platform_break.png"
const PLATFORM_JUMP_TEX_PATH := "res://assets/sprites/platform_jump.png"
const PLATFORM_MOVE_TEX_PATH := "res://assets/sprites/platform_move.png"

## 08-11 背景試接（硬規則 4 例外七）：0~500m backroom 貼磚，使用者從參考素材
## （12.webp）指定座標裁出的無縫 tile，見 well_world._draw_background。
## 08-11 續（使用者從六種濾鏡方案挑 D）：tile 檔案本身已經烤入模糊＋螢光黃綠色偏
## （seamless_blur 1.8px → tint(214,206,150,22%) → 對比 ×0.85），不是原始裁圖。
## 模糊／色偏是「貼圖內容」，可以烤進會重複貼磚的 tile；暗角不行——暗角是螢幕空間效果，
## 烤進 tile 裡貼磚會變成每塊磚都暗一圈，看起來像格子紋而不是鏡頭暗角，所以暗角
## 另外用 BG_VIGNETTE_TEX_PATH 疊一張不貼磚、跟著目前可視範圍縮放的圖層（見下方）。
const BG_BACKROOM_TEX_PATH := "res://assets/sprites/bg_backroom_tile.png"
## 淡暗角疊圖（512×512 徑向漸層，中心透明→邊緣變暗，強度 0.35）。screen-space 效果，
## 每幀依目前可視範圍重新拉伸貼一次（tile=false），不能像背景本體那樣用固定世界座標
## 貼磚——暗角要跟著鏡頭走，不是釘在世界某個位置。
const BG_VIGNETTE_TEX_PATH := "res://assets/sprites/bg_vignette.png"

var _monster_tex: Texture2D
var _wormhole_tex: Texture2D
var _projectile_tex: Texture2D
var _pameloe_texs: Array[Texture2D] = []
var _coin_tex: Texture2D
var _fuel_tex: Texture2D
var _platform_normal_tex: Texture2D
var _platform_break_tex: Texture2D
var _platform_jump_tex: Texture2D
var _platform_move_tex: Texture2D
var _bg_backroom_tex: Texture2D
var _bg_vignette_tex: Texture2D

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
## 教學關（08-13x，SECTION 8f）。由 src/main.gd 在 reset() 之前灌入——世界層本身不讀
## SpikeSave（同 reset() 底下 gen.setup 那段的 ⚠⚠），這顆旗標也一樣，外面決定、
## 這裡只負責照著做（固定佈局、跳過時間驅動的干擾階梯、結算只入帳金幣）。
var tutorial_mode: bool = false
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

## 懷錶二段跳的回饋圈（SpikeConfig SECTION 3c）。畫法跟攀爬那組一樣，但**變數刻意
## 分開一組**而不是共用一組加旗標：兩者可以在同一次離地內接連觸發（先攀爬再按 W），
## 共用一組會讓後觸發的那個把前一個蓋掉，玩家只看得到一個圈。
var _watch_fx_active := false
var _watch_fx_timer := 0.0
var _watch_fx_pos := Vector2.ZERO

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
## --- 三選一增益（08-12 開局、08-13 加 1000m 第二組，SpikeConfig SECTION 8e）---
## 本局持有的 buff，依**取得順序**排列（index 0 ＝ 先拿到的那顆），每格是
## `{"key": String, "uses": int}`。uses 的語意同 SpikeConfig.buff_uses_of：
## 0＝被動無次數、N＝還能用幾次、-1＝無限次但有別的條件（金錢彈）。
##
## ⚠⚠ 08-13 起這是**陣列**不是單一 key（使用者拍板：第三關 1000m 有第二組三選一，
##   舊 buff 仍保留）。三條規則：
##   ① 主動型（披薩／時間／金錢彈）**排隊**，「使用道具」鍵一律先用完 index 較小的
##      那顆（＝先拿到的）——唯一的家是 active_buff_index()。
##   ② 被動型（石頭／石化／護盾／DAHLAH）**同時生效**，各自用 has_buff() 問。
##   ③ 同一個 key 不會出現兩次：第二組的候選池已經扣掉開局那三顆（見生成器的
##      exclude 參數），這裡不另外去重。
## ⚠ 永遠不會有 "random"：選到隨機的那一刻就已經展開成別的了（見 _select_buff_orb）。
var buffs: Array = []
## 本局用掉幾次（結算與稽核用，不影響玩法）
var buff_used_count := 0

## 時間藥水：還要凍結多久。> 0 期間敵人與干擾都不動。
## ⚠ 平台**不受影響**，見 SECTION 8e 的 ⚠。
var buff_freeze_timer := 0.0

## 石化藥水：Kaela 的旋轉角（純視覺，判定完全不轉，見 SECTION 8e 的 ⚠）
var _petrify_spin := 0.0
## 現在的轉速（**圈／秒**，帶正負號＝順／逆時針）。08-13 起不是常數：每次離地起跳
## 重骰方向、平時持續減速到地板值、踩到彈射板／穿蟲洞／jetpack 點火才加速（見 _petrify_takeoff）。
## ⚠ 單位是「圈／秒」不是弧度／秒，乘 TAU 只在 _tick_petrify 那一處做——兩種單位混用
##   會讓「最快 5 圈/秒」這條上限悄悄變成 5 弧度/秒（不到一圈）。
var _petrify_spin_speed := 0.0

## 井底屍體堆（08-13 三訂）：每具 {pos: Vector2, angle: float, flip: bool}。
## ⚠ 純表現：不進 gen.platforms／monsters，不參與任何 rect 判定，也不隨相機回收——
##   它只存在於井底那 CORPSE_BAND_H 一段，玩家爬上去就再也看不到。
var _corpses: Array[Dictionary] = []

## 石頭藥水的視覺替身（音效系統上線前的佔位）：踩板時在腳底灑一圈石屑。
## 每筆 {pos, timer}。⚠ 這是佔位不是最終效果——音效系統上線後這整組要換掉。
var _stone_fx: Array = []

## 鳳梨披薩／時間藥水使用瞬間的外擴同心圓。每筆 {pos, timer}，畫法同 _draw_ledge_fx，
## 用陣列存的理由同 _stone_fx（可能連續觸發，陣列讓多圈疊演不互相打斷）。
var _pizza_fx: Array = []
var _time_fx: Array = []

## 金錢彈射出的子彈。⚠ 跟 _shots（Pameloe 的敵方子彈）**分開兩個陣列**：兩者的判定
##   對象相反（一個打玩家、一個打怪物），混在一起遲早會有人拿錯迴圈。
var _coin_bullets: Array = []
var coin_bullet_count := 0

var _blasts: Array = []
## 這局一共炸了幾次。同 pameloe_shot_count：斷掉的表現是「什麼都沒發生」，需要一個數字盯著。
var blast_count := 0

## 死亡演出（v17，使用者拍板）。死掉的當下**不切頁**：先在死亡位置放一個小型爆炸，
## 這段期間世界完全凍結（見 _process 開頭），演完才 emit died 讓 main.gd 進結算。
## ⚠ 這不是裝飾。瞬間切到結算頁會把「我怎麼死的」藏在切換的那一幀裡，玩家只看到
##   畫面一換就出現死因文字——那行字是唯一的線索，等於把可歸因性交給文案去補。
## ⚠ 常數住 SpikeConfig SECTION 6c；美術素材接進來時只換 _draw_death_fx 的內容。
## Raora 登場的鏡頭震動（08-13，SpikeConfig SECTION 7）。
## ⚠ _raora_shake_done 是「一局只震一次」的鎖：干擾的 active() 在登場後**恆為真**，
##   沒有這把鎖的話每一幀都會把計時器頂滿＝從此永遠在震。
var _cam_shake_timer := 0.0
var _raora_shake_done := false

## 第五種干擾（視野縮小）的暗幕貼圖。第一次要畫時才建，之後每幀重用。
var _vision_tex: GradientTexture2D = null

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
## 非 0 時取代生成器的隨機 seed，讓整座井可重現。0 ＝ 照舊 randomize，正式遊戲行為不變。
## 錄影驗證（record.gd）與 bot 回歸（tests/bot_run.gd）靠這個做「同一座井」的逐格比對。
## ⚠ 要在 add_child() 之前設：add_child 觸發 _ready() → reset()，seed 那時就被讀走了。
var seed_override := 0

## 教學關干擾事件表（SpikeConfig.TUTORIAL_INTERFERENCE_EVENTS）觸發過的 index。
## ⚠ 存「觸發過沒」而不是拿 best_m 每幀重新判斷要不要觸發——不然玩家在同一段來回
## 走動，投擲物／抽跳板會被連續觸發好幾次（規格「固定高度真的觸發」是觸發一次，
## 不是每次經過都觸發）。reset() 清空。
var _tutorial_events_fired: Dictionary = {}
## 教學字卡的底板樣式，_draw_tutorial_cues() 第一次用到才建、之後重用——
## 不要在 _draw()（每幀都跑）裡 new 一份新的 StyleBoxFlat。
var _cue_card_style: StyleBoxFlat = null


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
	_load_platform_textures()
	_load_background_textures()
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


## 平台四態貼圖，四張彼此獨立判斷 ResourceLoader.exists()（見上方常數註解）。
func _load_platform_textures() -> void:
	if ResourceLoader.exists(PLATFORM_NORMAL_TEX_PATH):
		_platform_normal_tex = load(PLATFORM_NORMAL_TEX_PATH)
	if ResourceLoader.exists(PLATFORM_BREAK_TEX_PATH):
		_platform_break_tex = load(PLATFORM_BREAK_TEX_PATH)
	if ResourceLoader.exists(PLATFORM_JUMP_TEX_PATH):
		_platform_jump_tex = load(PLATFORM_JUMP_TEX_PATH)
	if ResourceLoader.exists(PLATFORM_MOVE_TEX_PATH):
		_platform_move_tex = load(PLATFORM_MOVE_TEX_PATH)


## 缺檔一律退回原本的純色 C_BG（見 _draw_background），跟其他批次一致。
func _load_background_textures() -> void:
	if ResourceLoader.exists(BG_BACKROOM_TEX_PATH):
		_bg_backroom_tex = load(BG_BACKROOM_TEX_PATH)
	if ResourceLoader.exists(BG_VIGNETTE_TEX_PATH):
		_bg_vignette_tex = load(BG_VIGNETTE_TEX_PATH)


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
	_tutorial_events_fired.clear()
	# ⚠ 「遊玩次數」（kaela 成就）**不在這裡算**。reset() 有兩個呼叫端：_ready() 建構世界時
	#   也會呼叫一次，算在這裡的話光是開啟遊戲就先送一次遊玩次數，玩一局變成兩次。
	#   真正的「開一局」入口是 main.gd 的 _start_run，計數住那裡（SpikeSave.report_run_start）。
	_wh_travel_active = false
	_wh_travel_timer = 0.0
	_ledge_fx_active = false
	_ledge_fx_timer = 0.0
	_watch_fx_active = false
	_watch_fx_timer = 0.0
	# 三選一增益（08-12）。⚠ 整組都要清：buffs 沒清的話「上一局選的 buff」會被帶到
	#   下一局，而且下一局的三顆球還在＝可以再選一個，變成無限疊 buff。
	buffs.clear()
	buff_used_count = 0
	buff_freeze_timer = 0.0
	_petrify_spin = 0.0
	_petrify_spin_speed = 0.0
	_cam_shake_timer = 0.0
	_raora_shake_done = false
	_stone_fx.clear()
	_coin_bullets.clear()
	coin_bullet_count = 0
	_sparks.clear()
	_shots.clear()
	_blasts.clear()
	_dying = false
	_death_fx_t = 0.0
	_death_fx_shards.clear()
	Engine.time_scale = 1.0
	# 井底屍體堆（08-13 三訂）：純表現，不進生成器也不參與任何判定
	_rebuild_corpses()

	gen = WellGenerator.new()
	# 墓碑高度與關卡編號都由外面灌進生成器（生成器自己不讀 SpikeSave，見 setup() 的 ⚠⚠）。
	# ⚠ 關卡決定哪些「關卡限定」的地形生得出來（目前只有爆炸平台），門檻表住
	#   SpikeConfig.LEVEL_GATED——這裡只負責把「現在是第幾關」送過去。
	gen.setup(
		start_y, seed_override, SpikeSave.best_height_m, SpikeSave.selected_level, tutorial_mode
	)

	player.reset(Vector2(SpikeConfig.VIEW_W * 0.5, start_y - SpikeConfig.PLAYER_SIZE.y * 0.5))
	whip.reset()
	interference.reset()
	# 第五種干擾（視野縮小）是關卡限定的，關卡編號要灌進去——同生成器那條「狀態一律從
	# 外面灌進去，元件自己不讀 SpikeSave」。
	interference.level_idx = SpikeSave.selected_level

	cam_y = player.pos.y - (SpikeConfig.CAMERA_START_RATIO - 0.5) * SpikeConfig.VIEW_H
	_apply_camera()
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
	# 時間藥水（08-12，SECTION 8e）：凍結期間敵人與干擾完全不動。
	# ⚠ elapsed 照跑：這顆 buff 買的是「敵人停下來」，不是「這 5 秒不算時間」。後者會
	#   讓它變成計時賽的作弊道具，而且連 Raora 登場倒數都會跟著延後。
	var frozen := _tick_buff_freeze(delta)

	# 蟲洞過場期間干擾計時照跑（加速手段不是免費喘息），但不生新的預警／抽跳板——
	# 那會瞄準一個過場中才有、下一刻就不在的位置。suppress_spawn 只讓計時器空轉，
	# 過場結束後下一次 update() 立刻用當下的真實位置補上，見 interference.gd 的註解。
	# ⚠ 時間藥水的凍結**整個跳過 update()**（連計時器都不跑），跟過場的 suppress_spawn
	#   不是同一件事：過場是「你在移動中，先別生新東西」，凍結是「時間停了」。
	if not frozen:
		# 教學關不跑正常的時間驅動干擾階梯（規格明講），改由高度事件表逐一強制觸發，
		# 見 _step_tutorial_events()。
		if tutorial_mode:
			interference.tutorial_step(delta, _view_top())
		else:
			interference.update(
				delta, elapsed, player.pos, _view_top(), gen.platforms, best_m, _wh_travel_active
			)

	# ⚠⚠ 平台**不吃凍結**（SECTION 8e）：凍住移動平台等於把玩家腳下的落點抽走，
	#   那不是增益是陷阱。凍結凍的是「會攻擊你的東西」，不是地形。
	_step_platforms(delta)
	if not frozen:
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
	# 增益球與金錢彈都不吃凍結：前者是靜物，後者是**玩家的**子彈——凍住自己的子彈
	# 等於這兩顆 buff 互相打架。
	for orb in gen.buff_orbs:
		orb.step(delta)
	_tick_coin_bullets(delta)
	_tick_stone_fx(delta)
	_tick_pizza_fx(delta)
	_tick_time_fx(delta)
	_tick_petrify(delta)

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
		# 增益球排在物資之後、蟲洞之前：它跟兩者都不會長在同一塊板上（開局那排是
		# 固定佈局，生成器根本沒在那裡放過物資或蟲洞），順序只影響同一幀的先後。
		_check_buff_orbs()
		_check_wormholes()
		# _check_wormholes 這一幀可能剛把 _wh_travel_active 打開——那就交給下一幀的
		# _step_wormhole_travel 去管相機，這裡不要再用觸發線邏輯去頂它。
		if not _wh_travel_active:
			_update_camera()

	# 排在相機更新之後：震動是疊在「這一幀算完的 cam_y」上的位移，順序顛倒會用到上一幀
	# 的 cam_y，快速爬升時看得出畫面慢一拍。
	_tick_cam_shake(delta)
	_tick_ledge_fx(delta)
	_tick_watch_fx(delta)
	_tick_sparks(delta)
	_stream_world()
	_check_end()
	_step_tutorial_events()

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

	if not was_on:
		# 石化：噴射點火（冷啟動剛結束、真的噴出來的第一幀）也算一次「起飛」＝重骰方向。
		# ⚠ 08-13 三訂使用者改規格後這裡**不再帶 boost**：jetpack 的加速改由下面
		#   _petrify_jet_thrust 在噴射期間逐幀累加，點火再加一次會變成雙重計費。
		_petrify_takeoff()

	# 石化：噴射期間持續加速到上限（08-13 三訂）
	_petrify_jet_thrust(delta)

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


## 懷錶二段跳（通關關卡二的獎勵，SpikeConfig SECTION 3c）。
##
## 跟攀爬（_try_ledge_grab）的分工：
##   攀爬 = 被動、每幀自動檢查、只在頂點附近、只補「差一點」的那 30px
##   懷錶 = 主動、按鍵觸發、任何高度與速度都算、給的是完整一次跳躍
## ⚠ 所以這裡**沒有** LEDGE_GRAB_VEL_WINDOW 那種頂點窗限制——下墜到一半按 W 救回來
##   正是這個道具存在的意義。
##
## 兩道限制（跟攀爬同源）：
##   ① 每次離地限一次（player.watch_used，落地／傳送才重置），否則連按＝無限爬升
##   ② 鞭子拉扯中與 jetpack 噴射中不觸發——那兩段速度已被完全接管，再插手會打架
##
## ⚠ 直接指派 vel_y 而不是相加：這是「重新起跳」不是「額外推力」。相加的話從高速下墜
##   按下去會幾乎沒效果，而在上升途中按下去會疊成超高跳——兩種都不是玩家預期的。
func _try_watch_jump() -> void:
	if player.watch_used or not SpikeSave.has_pocket_watch():
		return
	if player.is_pulled() or player.jetpack_on:
		return
	player.vel_y = SpikeSave.jump_velocity() * SpikeConfig.WATCH_JUMP_RATIO
	player.watch_used = true
	_petrify_takeoff()
	_trigger_watch_fx(Vector2(player.pos.x, player.bottom()))


func _trigger_watch_fx(pos: Vector2) -> void:
	_watch_fx_active = true
	_watch_fx_timer = 0.0
	_watch_fx_pos = pos


func _tick_watch_fx(delta: float) -> void:
	if not _watch_fx_active:
		return
	_watch_fx_timer += delta
	if _watch_fx_timer >= SpikeConfig.WATCH_FX_DURATION:
		_watch_fx_active = false


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
		player.watch_used = false
		player.trigger_land_flash()
		# 石頭藥水（08-12）的視覺替身：踩板時在腳底灑一圈石屑。沒拿這顆 buff 時是 no-op。
		# ⚠ 這是音效系統上線前的佔位，不是最終效果（SECTION 8e 的 ⚠）。
		_spawn_stone_fx(Vector2(player.pos.x, top))
		# 跳躍力與彈射初速吃永久升級；⚠ 生成器的間距仍以 SpikeConfig 的基礎值為設計單位
		if p.kind == WellPlatform.Kind.LAUNCHER:
			player.vel_y = SpikeSave.launcher_velocity()
			player.launch_invuln = true
			launcher_used_count += 1
			SpikeSave.bump_stat("launchers_used")
			# 石化：彈射板是三個「加速轉速」的來源之一（另外兩個是蟲洞與 jetpack 點火）
			_petrify_takeoff(true)
		else:
			_petrify_takeoff()
			# ⚠ 走 _jump_velocity_now() 而不是直接問 SpikeSave：DAHLAH 這顆 buff 要在
			#   **每一次起跳**重骰高度倍率，而這裡是唯一的一般起跳點。彈射板那條刻意
			#   不吃它——那塊板的初速是它自己的設計參數，不是「跳躍」。
			player.vel_y = _jump_velocity_now()
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
		# 暈眩怪（08-13，鞭子纏中的那隻）：碰到＝這一刻才演死亡動畫，玩家不受傷、
		# 也不彈起。⚠ 這條要排在無敵與踩頭**之前**：鞭子拉扯期間玩家本來就是無敵的，
		#   排在後面的話這一擊會被算成「無敵撞飛」（bump_count），使用者要的「鞭中→
		#   碰到才死」這條路徑會被靜默吃掉、還順便退鞭子次數。
		# ⚠ refund = false：這隻本來就是鞭子打的，殺了再退鞭子＝自我循環
		#   （見 SpikeConfig.MONSTER_KILL_WHIP_REFUND_CHANCE 的 ⚠）。
		if m.stunned:
			_kill_monster(m, false)
			continue
		if invuln:
			_kill_monster(m)
			bump_count += 1
			continue
		# 踩頭永遠可行（PILLARS 保底條款：鞭子用完後高處怪物不得退化成運氣牆）
		if _pre_vel_y > 0.0 and _pre_bottom <= mr.position.y + SpikeConfig.STOMP_TOLERANCE:
			_kill_monster(m)
			player.vel_y = SpikeSave.jump_velocity() * SpikeConfig.STOMP_BOUNCE_RATIO
			_petrify_takeoff()
			stomp_count += 1
		else:
			# 撞死：pameloe 本體另記一條死因（判定同一套，只差結算那句話）
			_die(
				CAUSE_PAMELOE_BODY if m.kind == WellMonster.Kind.PAMELOE else CAUSE_MONSTER
			)
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
	# 護盾（08-12，SECTION 8e）：吸收掉就直接返回，完全不進死亡流程。
	# ⚠ 擋在 _dying 之後、其他所有事之前：last_cause 都還沒寫，所以被擋下的那次不會
	#   污染結算的死因（否則「這局怎麼死的」會顯示一次根本沒發生的死亡）。
	# ⚠ 吸收的同時已經開了 BUFF_SHIELD_INVULN 的無敵窗（見該函式的 ⚠⚠），所以下一幀
	#   _check_hazards 會整個跳過——不會出現「同一次接觸把盾連續吃光」。
	if _buff_shield_absorb(cause):
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
## refund：這次擊殺要不要骰「鞭子 +1」。⚠ 鞭子自己造成的擊殺（暈眩怪被碰到）一律 false，
##   否則會變成「用鞭子殺怪 → 補回鞭子」的自我循環。
func _kill_monster(m: WellMonster, refund: bool = true) -> void:
	var dx := m.pos.x - player.pos.x
	if absf(dx) < 1.0:
		dx = player.total_vel_x()
	m.kill(1.0 if dx >= 0.0 else -1.0)
	_count_monster_kill()
	if refund and randf() < SpikeConfig.MONSTER_KILL_WHIP_REFUND_CHANCE:
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
# ============================================================
# 開局三選一增益（08-12，SpikeConfig SECTION 8e）
# ============================================================

## 時間藥水的凍結倒數。回傳「這一幀是不是凍結中」，呼叫端據此跳過敵人與干擾。
## ⚠ 回傳 bool 而不是讓呼叫端自己讀 buff_freeze_timer：那樣「> 0」這個判斷會散成好幾份，
##   而其中一份寫成 ">= 0" 就是永久凍結。
func _tick_buff_freeze(delta: float) -> bool:
	if buff_freeze_timer <= 0.0:
		return false
	buff_freeze_timer = maxf(0.0, buff_freeze_timer - delta)
	return true


func buff_frozen() -> bool:
	return buff_freeze_timer > 0.0


## 碰到增益球＝選它。⚠ 用 rect 相交而不是圓心距離：球是圓的，但這裡的誤差要倒向
##   「容易選到」（同金幣那條），矩形相交的四個角正好給出那個方向的寬容。
func _check_buff_orbs() -> void:
	if gen.buff_orbs.is_empty():
		return
	var pr := player.rect()
	for orb in gen.buff_orbs:
		if not orb.selectable():
			continue
		if not pr.intersects(orb.rect()):
			continue
		_select_buff_orb(orb)
		return


## 選中一顆：本局的 buff 定案，另外兩顆爆掉。
## ⚠ 「隨機」在**這一刻**才展開成別的（不是生成當下）——生成當下就展開的話，畫面上
##   會出現兩顆一樣的 buff（展開結果撞到另一個選項），而玩家看不出那是隨機造成的。
func _select_buff_orb(orb: WellBuffOrb) -> void:
	var key: String = orb.key
	if key == SpikeConfig.BUFF_RANDOM_KEY:
		key = gen.expand_random_buff(orb.group)
	grant_buff(key)
	# 選中的那顆也一起爆掉：它已經「被吃進去」了，留在原地會讓玩家以為還能再選一次。
	# ⚠ 只爆**同一組**的三顆：08-13 起一局可能有兩組（開局＋1000m），選了開局那組
	#   不能把 1000m 那組一起清掉。組別由生成器蓋在球上（WellBuffOrb.group）。
	# ⚠ 三顆都爆，但只有這一顆先把 buff 記進去——順序不能顛倒（explode 之後 orb.key
	#   還在，但迴圈裡分不出哪顆是被選的那顆）。
	for o in gen.buff_orbs:
		if o.group == orb.group:
			o.explode()
	queue_redraw()


## 記一顆 buff 進持有清單。**唯一的寫入點**（選球、稽核、未來的其他給予途徑都走這裡）。
## uses 留白＝用 BUFF_TABLE 的初始次數。
## ⚠ 同一個 key 重複給時只補次數不新增一格：兩格同 key 會讓 HUD 出現兩個一樣的圖示，
##   而被動效果又不會因此加倍，純粹是騙人的版面。
func grant_buff(key: String, uses: int = -999) -> void:
	if key == "" or not SpikeConfig.BUFF_TABLE.has(key):
		return
	var n: int = SpikeConfig.buff_uses_of(key) if uses == -999 else uses
	var i := buff_index_of(key)
	if i >= 0:
		buffs[i]["uses"] = n
		return
	buffs.append({"key": key, "uses": n})
	# 石化：拿到當下就要有轉速，不然要等到下一次起跳才看得出「我被石化了」。
	if key == "petrify":
		_petrify_spin_speed = SpikeConfig.BUFF_PETRIFY_SPIN_START
		_petrify_takeoff()


## 持有清單裡這個 key 在第幾格；沒有回 -1。
func buff_index_of(key: String) -> int:
	for i in range(buffs.size()):
		if String(buffs[i]["key"]) == key:
			return i
	return -1


## 有沒有持有這顆（**被動效果的唯一問法**）。
## ⚠ 被動型不看次數：它們的 uses 恆為 0，拿「uses > 0」問會讓每一種被動 buff 都失效。
func has_buff(key: String) -> bool:
	return buff_index_of(key) >= 0


## 這顆還剩幾次；沒持有回 0。
func buff_uses_left(key: String) -> int:
	var i := buff_index_of(key)
	return 0 if i < 0 else int(buffs[i]["uses"])


## 這一格能不能按下去用。三個條件：是主動型、次數還有、額外條件滿足。
func _slot_ready(i: int) -> bool:
	if i < 0 or i >= buffs.size():
		return false
	var key := String(buffs[i]["key"])
	if not SpikeConfig.buff_is_active(key):
		return false
	if int(buffs[i]["uses"]) == 0:
		return false
	if key == "coingun":
		return coin_count >= SpikeConfig.BUFF_COIN_BULLET_COST
	return true


## 「使用道具」鍵這一刻會用到哪一格。**唯一的家**——使用者拍板「優先用完舊的」，
## 所以是「index 最小的可用主動 buff」。沒有可用的回 -1。
## ⚠ 不能寫成「找第一個主動型再問 ready」：舊那顆金錢彈沒錢時應該讓新那顆披薩接手，
##   而不是整顆鍵變成廢的。
func active_buff_index() -> int:
	for i in range(buffs.size()):
		if _slot_ready(i):
			return i
	return -1


## 這一刻按「使用道具」鍵有沒有用。
## ⚠ HUD 的「icon 變不變暗」不讀這個函式，讀 buff_dimmed(i)：這裡對被動型一律回 false
##   （它問的是「主動鍵按下去有沒有用」），拿來當變暗依據會讓護盾／石化一拿到就是暗的。
func buff_ready() -> bool:
	return active_buff_index() >= 0


## 「使用道具」鍵（預設 F）。所有主動 buff 共用同一顆鍵，先用完先拿到的那顆。
func use_buff() -> bool:
	var i := active_buff_index()
	if i < 0:
		return false
	match String(buffs[i]["key"]):
		"pizza":
			_use_pizza()
		"time":
			_use_time_potion()
		"coingun":
			if not _use_coin_bullet():
				return false
		_:
			return false
	# ⚠ 次數在效果**成功之後**才扣：金錢彈可能因為場上沒有敵人而放棄發射，那種情況
	#   不該消耗次數也不該扣金幣（見 _use_coin_bullet 的回傳值）。
	if int(buffs[i]["uses"]) > 0:
		buffs[i]["uses"] = int(buffs[i]["uses"]) - 1
	buff_used_count += 1
	queue_redraw()
	return true


## 鳳梨披薩：畫面上的所有敵人死亡。
## ⚠ 走 _kill_monster() 這條真實路徑（不是直接 alive = false）：死亡演出、擊殺計數、
##   踩頭退鞭子那幾條都掛在它身上，繞過去就會少掉一半。
## ⚠ 只殺**畫面上的**（使用者規格）：畫面外的殺了玩家看不到，等於白按一次。
func _use_pizza() -> void:
	var top := _view_top()
	var bot := _view_bottom()
	for m in gen.monsters:
		if not m.alive or m.dying:
			continue
		if m.pos.y < top or m.pos.y > bot:
			continue
		_kill_monster(m)
		_count_monster_kill()
	_pizza_fx.append({"pos": player.pos, "timer": SpikeConfig.BUFF_PIZZA_FX_DURATION})


func _tick_pizza_fx(delta: float) -> void:
	if _pizza_fx.is_empty():
		return
	var kept: Array = []
	for fx in _pizza_fx:
		fx["timer"] -= delta
		if fx["timer"] > 0.0:
			kept.append(fx)
	_pizza_fx = kept


## 時間藥水：敵人行動與干擾暫停。
## ⚠ 用指派而不是累加：連按兩次不該疊成 10 秒（次數有限的道具疊加會讓「留到關鍵時刻」
##   的決策消失，全部一次倒出來永遠是最優解）。
func _use_time_potion() -> void:
	buff_freeze_timer = SpikeConfig.BUFF_TIME_FREEZE_DURATION
	_time_fx.append({"pos": player.pos, "timer": SpikeConfig.BUFF_TIME_FX_DURATION})


func _tick_time_fx(delta: float) -> void:
	if _time_fx.is_empty():
		return
	var kept: Array = []
	for fx in _time_fx:
		fx["timer"] -= delta
		if fx["timer"] > 0.0:
			kept.append(fx)
	_time_fx = kept


## 金錢彈：扣本局 5 金幣，朝最近的敵人射一發。
## 回傳 false ＝ 沒發射（場上沒有目標），呼叫端據此不扣次數也不扣錢。
## ⚠ 扣的是本局 coin_count 不是存檔金幣（使用者規格「本回合獲得的 5 金錢」）：扣存檔
##   金幣會讓它變成「花永久資源換一次擊殺」，那是完全不同的一顆 buff。
func _use_coin_bullet() -> bool:
	# ⚠ 用 `=` 不是 `:=`：_nearest_visible_monster() 回傳可能是 null，沒有靜態型別可推導
	#   （同 gen.monsters 那條「無型別 Array 的元素要明寫型別」的反面情形）。
	var target = _nearest_visible_monster()
	if target == null:
		return false
	coin_count -= SpikeConfig.BUFF_COIN_BULLET_COST
	var b := {
		"pos": player.pos,
		"vel": (target.pos - player.pos).normalized() * SpikeConfig.BUFF_COIN_BULLET_SPEED,
		"travelled": 0.0,
	}
	_coin_bullets.append(b)
	coin_bullet_count += 1
	return true


## 畫面內、還活著、離玩家最近的怪物。null ＝ 沒有目標。
func _nearest_visible_monster():
	var top := _view_top()
	var bot := _view_bottom()
	var best = null
	var best_d := INF
	for m in gen.monsters:
		if not m.alive or m.dying:
			continue
		if m.pos.y < top or m.pos.y > bot:
			continue
		var d: float = player.pos.distance_squared_to(m.pos)
		if d < best_d:
			best_d = d
			best = m
	return best


## 金錢彈的飛行與命中。
## ⚠ 判定框刻意**大於**視覺（BUFF_COIN_BULLET_HIT_SIZE > _SIZE），跟 Pameloe 子彈那條
##   「判定必須嚴格小於視覺」剛好相反——兩者的誤差都要倒向對玩家有利的方向。
func _tick_coin_bullets(delta: float) -> void:
	if _coin_bullets.is_empty():
		return
	var half: Vector2 = SpikeConfig.BUFF_COIN_BULLET_HIT_SIZE * 0.5
	var kept: Array = []
	for b in _coin_bullets:
		var step: Vector2 = b["vel"] * delta
		b["pos"] += step
		b["travelled"] += step.length()
		if b["travelled"] > SpikeConfig.BUFF_COIN_BULLET_MAX_RANGE:
			continue
		if b["pos"].x < SpikeConfig.WELL_LEFT or b["pos"].x > SpikeConfig.WELL_RIGHT:
			continue
		var hit := false
		var box := Rect2(b["pos"] - half, SpikeConfig.BUFF_COIN_BULLET_HIT_SIZE)
		for m in gen.monsters:
			if not m.alive or m.dying:
				continue
			if not box.intersects(m.rect()):
				continue
			_kill_monster(m)
			_count_monster_kill()
			hit = true
			break
		if not hit:
			kept.append(b)
	_coin_bullets = kept


## 石化藥水：純視覺的旋轉角。⚠ 判定完全不轉（SECTION 8e 的 ⚠）——轉起來的矩形碰撞箱
##   會忽寬忽窄，玩家會遇到「同一個縫有時過得去有時過不去」，那是最難歸因的死法。
## 08-13 改成動態轉速（使用者規格）：平時**持續減速**到地板值，只有「彈起」那一刻
## 才重骰方向、只有彈射板／蟲洞才加速。
## ⚠ 減速是每秒扣固定量（線性）不是乘衰減係數：指數衰減會讓「快到 5 圈」那段掉得又急
##   又不線性，玩家看不出「越彈越快、之後慢慢緩下來」這條因果。
func _tick_petrify(delta: float) -> void:
	if not has_buff("petrify"):
		return
	var mag := absf(_petrify_spin_speed)
	# ⚠ 噴射中完全跳過減速：加速那段由 _petrify_jet_thrust 全權負責，兩邊同時作用的話
	#   JET_RATE 就不再是玩家看到的加速度（得先扣掉 DECAY），兩個常數互相綁死。
	if mag > SpikeConfig.BUFF_PETRIFY_SPIN_MIN and not player.jetpack_on:
		mag = maxf(
			SpikeConfig.BUFF_PETRIFY_SPIN_MIN, mag - SpikeConfig.BUFF_PETRIFY_SPIN_DECAY * delta
		)
		_petrify_spin_speed = mag * signf(_petrify_spin_speed)
	_petrify_spin = fmod(_petrify_spin + _petrify_spin_speed * TAU * delta, TAU)


## 重建井底屍體堆（08-13 三訂）。每具的位置／角度由「第幾具」決定，同一具在每一局
## 都躺在同一個地方——玩家看到的是「我上一輪死在那裡」，不是每局重排的裝飾。
## ⚠ 自己開一個 RandomNumberGenerator 而不是用 randf()／生成器的 _rng：
##   ①全域 randf 會讓位置每局跳動 ②借生成器的 _rng 會污染「這座井長什麼樣」的序列
##   （同 _petrify_takeoff 與 _spawn_sparks 的理由，v19 那條「純函式偷骰 RNG」的教訓）。
## ⚠ seed 混進關卡與模式：不同關卡／模式的屍體堆要長得不一樣，否則三個關卡的井底
##   會是同一張圖。
func _rebuild_corpses() -> void:
	_corpses.clear()
	var n: int = SpikeSave.corpse_count(
		SpikeSave.selected_level, SpikeSave.extreme_mode, SpikeSave.endless_mode
	)
	if n <= 0:
		return
	var rng := RandomNumberGenerator.new()
	var left: float = SpikeConfig.WELL_LEFT + SpikeConfig.CORPSE_EDGE_MARGIN
	var right: float = SpikeConfig.WELL_RIGHT - SpikeConfig.CORPSE_EDGE_MARGIN
	for i in range(n):
		rng.seed = hash("%s#%d" % [
			SpikeSave.corpse_key(
				SpikeSave.selected_level, SpikeSave.extreme_mode, SpikeSave.endless_mode
			), i
		])
		_corpses.append({
			"pos": Vector2(
				rng.randf_range(left, right),
				start_y - rng.randf_range(0.0, SpikeConfig.CORPSE_BAND_H)
			),
			"angle": rng.randf_range(
				SpikeConfig.CORPSE_ANGLE_MIN, SpikeConfig.CORPSE_ANGLE_MAX
			),
			"flip": rng.randf() < 0.5,
		})


## 噴射期間的石化持續加速（08-13 三訂，使用者拍板「用 jetpack 的過程都一直加轉速」）。
## ⚠ 呼叫點在 _step_jetpack 的「確定噴出來了」之後，不是 _tick_petrify 裡——冷啟動
##   （按著鍵但還沒噴出來）那段不該加速，而那個判斷只有 _step_jetpack 知道。
## ⚠ 不用 signf()：轉速理論上不會是 0（拿到 buff 當下就有 START），但真的是 0 時
##   signf 會把整條速度歸零，石化就永遠停轉了。
func _petrify_jet_thrust(delta: float) -> void:
	if not has_buff("petrify"):
		return
	var mag := absf(_petrify_spin_speed)
	if mag >= SpikeConfig.BUFF_PETRIFY_SPIN_MAX:
		return
	mag = minf(
		SpikeConfig.BUFF_PETRIFY_SPIN_MAX,
		mag + SpikeConfig.BUFF_PETRIFY_SPIN_JET_RATE * delta
	)
	_petrify_spin_speed = mag if _petrify_spin_speed >= 0.0 else -mag


## 「彈起」一次：重骰旋轉方向，boost 為真時再加速。
## 呼叫點＝**所有離地起跳**（使用者拍板的定義）：一般跳、懷錶二段跳、踩頭彈跳、
## 彈射板、蟲洞出口、jetpack 點火。其中彈射板／蟲洞／jetpack 點火另外帶 boost。
## ⚠ 走全域 randf 而不是生成器的 seeded rng：這是玩家端的效果，不該污染「這座井長什麼樣」
##   的亂數序列（同 _jump_velocity_now 的理由）。
func _petrify_takeoff(boost: bool = false) -> void:
	if not has_buff("petrify"):
		return
	var mag := absf(_petrify_spin_speed)
	if boost:
		mag += SpikeConfig.BUFF_PETRIFY_SPIN_BOOST
	mag = clampf(
		mag, SpikeConfig.BUFF_PETRIFY_SPIN_MIN, SpikeConfig.BUFF_PETRIFY_SPIN_MAX
	)
	_petrify_spin_speed = mag if randf() < 0.5 else -mag


## 石頭藥水的視覺替身（音效系統上線前的佔位，見 SECTION 8e 的 ⚠）。
func _spawn_stone_fx(at: Vector2) -> void:
	if not has_buff("stone"):
		return
	_stone_fx.append({"pos": at, "timer": SpikeConfig.BUFF_STONE_FX_DURATION})


func _tick_stone_fx(delta: float) -> void:
	if _stone_fx.is_empty():
		return
	var kept: Array = []
	for fx in _stone_fx:
		fx["timer"] -= delta
		if fx["timer"] > 0.0:
			kept.append(fx)
	_stone_fx = kept


## 護盾：這次死亡擋不擋得下來。回傳 true ＝ 已吸收，呼叫端不得繼續走死亡流程。
## ⚠⚠ 吸收後給 BUFF_SHIELD_INVULN 的無敵**不是裝飾**：擋下的當幀玩家通常還跟殺死他的
##   東西重疊（怪物本體／爆炸範圍），沒有這段無敵的話下一幀會再判一次死，一次接觸就把
##   盾吃光。這是保命條款。
func _buff_shield_absorb(cause: String) -> bool:
	var i := buff_index_of("shield")
	if i < 0 or int(buffs[i]["uses"]) <= 0:
		return false
	if cause in SHIELD_IGNORED_CAUSES:
		return false
	buffs[i]["uses"] = int(buffs[i]["uses"]) - 1
	buff_used_count += 1
	player.invuln_timer = SpikeConfig.BUFF_SHIELD_INVULN
	queue_redraw()
	return true


## 這一次起跳的初速。DAHLAH 讓每次跳躍高度在 [MIN, MAX] 倍之間隨機。
## ⚠ 隨機的是**高度**倍率，換成初速要開根號（h = v²/2g）——直接乘倍率會讓 2.0 倍變成
##   4 倍高，同 SpikeSave.jump_velocity() 那條教訓。
## ⚠ 走全域 randf 而不是生成器的 seeded rng：這是玩家端的效果，不該污染「這座井長什麼樣」
##   的亂數序列（同 _spawn_sparks 的理由）。代價是 bot 跑局不可完全重現，可接受。
func _jump_velocity_now() -> float:
	var v: float = SpikeSave.jump_velocity()
	if not has_buff("dahlah"):
		return v
	var h_mult: float = randf_range(SpikeConfig.BUFF_DAHLAH_MIN, SpikeConfig.BUFF_DAHLAH_MAX)
	return v * sqrt(h_mult)


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
	_apply_camera()

	if t >= 1.0:
		_finish_wormhole_travel()


## 過場結束：把玩家釘死在出口平台上緣（不是浮空、不是穿板），給一次跳躍初速讓玩家
## 出來就有明確下一步；相機收斂到的位置跟舊版瞬間傳送同一條公式，_update_camera 接手時
## 只會看到「玩家剛好在預期位置附近」——相機本身只有 _update_camera 一處會動它，且那裡
## 只會拉高（cam_y -= ...）不會拉低，所以過場結束不可能觸發「相機被玩家拖回去」。
func _finish_wormhole_travel() -> void:
	player.pos = _wh_travel_to_pos
	cam_y = _wh_travel_to_cam_y
	_apply_camera()

	player.vel_y = SpikeSave.jump_velocity()
	player.control_vel_x = 0.0
	player.ledge_used = false
	player.watch_used = false
	player.refresh_invuln()
	# 石化：蟲洞是三個「加速轉速」的來源之一（另外兩個是彈射板與 jetpack 點火）
	_petrify_takeoff(true)

	_wh_travel_active = false
	_stream_world()


func _update_camera() -> void:
	# 觸發線制：玩家越過畫面上方的觸發線，相機才被「頂」上去；相機永不下降。
	# 玩家因此會在畫面上上下浮動——這正是漏接一塊板還救得回來的原因。
	var trigger_y: float = cam_y \
		- SpikeConfig.VIEW_H * (0.5 - SpikeConfig.CAMERA_SCROLL_TRIGGER)
	if player.pos.y < trigger_y:
		cam_y -= trigger_y - player.pos.y
	_apply_camera()


## 把 cam_y（＋震動位移）真正寫進相機節點。**相機節點的唯一寫入點**——散在五個地方
## 各寫一次的話，新加的震動只會在其中一條路徑上生效（例如蟲洞過場中就不震）。
func _apply_camera() -> void:
	camera.position = Vector2(SpikeConfig.VIEW_W * 0.5, cam_y) + cam_shake_offset()


## 這一幀的震動位移。⚠ 公開給稽核用：它是純函式（只吃 _cam_shake_timer），
## 稽核可以直接斷言「觸發後某一幀非零、2 秒後歸零」。
func cam_shake_offset() -> Vector2:
	if _cam_shake_timer <= 0.0:
		return Vector2.ZERO
	# 剩餘時間比例＝收斂係數：震幅隨時間線性縮到 0，不會突然停住
	var k: float = _cam_shake_timer / SpikeConfig.RAORA_SHAKE_DURATION
	var t: float = SpikeConfig.RAORA_SHAKE_DURATION - _cam_shake_timer
	var amp: float = SpikeConfig.RAORA_SHAKE_AMP * k
	var w: float = TAU * SpikeConfig.RAORA_SHAKE_FREQ * t
	# x／y 用不同頻率，否則兩軸同相＝只會沿 45° 對角線滑動，看起來像漂移不是震動
	return Vector2(sin(w), cos(w * 1.37)) * amp


func _tick_cam_shake(delta: float) -> void:
	# 干擾登場的那一幀觸發。⚠ 讀 interference.active() 而不是自己比 elapsed：
	#   登場時點走 eff_（極限模式是 0），比對條件散成兩份遲早會對不上。
	if not _raora_shake_done and interference.active():
		_raora_shake_done = true
		_cam_shake_timer = SpikeConfig.RAORA_SHAKE_DURATION
	if _cam_shake_timer <= 0.0:
		return
	_cam_shake_timer = maxf(0.0, _cam_shake_timer - delta)
	_apply_camera()


func _stream_world() -> void:
	gen.ensure_generated_to(cam_y - SpikeConfig.VIEW_H)
	gen.prune_below(cam_y + SpikeConfig.VIEW_H)


func _check_end() -> void:
	best_m = maxf(best_m, SpikeConfig.meters_from_y(start_y, player.pos.y))

	# speed run：局中就成立的成就，所以在這裡即時問一次而不是等結算。
	# ⚠ 只問一次（_speedrun_checked）：跨過 500m 的那一刻要嘛已經在 2 分鐘內、要嘛
	# 已經超時，之後再問一萬次答案都一樣，每幀重問是純粹的浪費。
	# ⚠ 教學關整段跳過：規格第 8 條「成就一律不記」，教學關的高度不該讓正式成就悄悄解鎖。
	if not tutorial_mode and not _speedrun_checked and best_m >= SpikeConfig.SPEEDRUN_HEIGHT_M:
		_speedrun_checked = true
		_report_progress()

	# 登頂：教學關比 TUTORIAL_GOAL_M（固定 200m，不受玩家選的正式關卡影響）；
	#   正式玩法（08-10 關卡制重新接回）比本關的 goal_meters。
	# ⚠ 走 eff_has_goal() 而不是直接讀 SpikeSave.endless_mode——模式規則的家在
	#   SpikeConfig（見那個函式的 ⚠）。無盡模式沒有終點，這一段整段不成立。
	# ⚠ 順序在墜落判定之前：同一幀既到達終點又掉出畫面時，應該算登頂而不是摔死
	#   （實務上碰不到，但兩個 running = false 的出口誰先誰後不該是碰運氣）。
	# ⚠ running = false 之後這個函式不會再被呼叫，所以 cleared 只會 emit 一次；
	#   若哪天 _check_end 改成不看 running 就要另外加旗標。
	var goal_reached: bool = best_m >= SpikeConfig.TUTORIAL_GOAL_M if tutorial_mode \
		else SpikeConfig.eff_has_goal() and best_m >= SpikeConfig.goal_meters
	if goal_reached:
		running = false
		cleared.emit()
		return

	if player.pos.y - player.size.y * 0.5 > _view_bottom():
		running = false
		_die(CAUSE_FALL)


## 教學關干擾事件表（SpikeConfig.TUTORIAL_INTERFERENCE_EVENTS）逐一比對觸發：
## best_m 跨過某一筆的 h_m 就觸發一次、標記已觸發，同一筆不會再觸發第二次
## （見 _tutorial_events_fired 宣告處的 ⚠）。實際觸發一律走 src/interference.gd 的
## 「教學用強制觸發一次」API，不直接戳 Interference 的私有狀態（使用者規格明講）。
func _step_tutorial_events() -> void:
	if not tutorial_mode:
		return
	for i in range(SpikeConfig.TUTORIAL_INTERFERENCE_EVENTS.size()):
		if _tutorial_events_fired.get(i, false):
			continue
		var row: Dictionary = SpikeConfig.TUTORIAL_INTERFERENCE_EVENTS[i]
		if best_m < float(row["h_m"]):
			continue
		_tutorial_events_fired[i] = true
		match String(row["kind"]):
			"projectile":
				var x: float = float(row.get(
					"x", (SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5
				))
				interference.tutorial_trigger_projectile(x)
			"steal":
				interference.tutorial_trigger_steal(gen.tutorial_steal_target)
			"shockwave":
				interference.tutorial_trigger_shockwave()
			"doom":
				interference.tutorial_trigger_doom(gen.tutorial_doom_target)


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
		# 懷錶二段跳（SpikeConfig SECTION 3c）。⚠ 走按鍵事件而不是 _step_player 裡的
		# is_action_pressed()：它是「按一下觸發一次」，長按不該連發——jetpack 才是長按型。
		# ⚠ not event.echo 已經在上面擋掉按住不放的重複事件了，但 watch_used 那條旗標
		#   仍然是必要的：玩家可以在同一次離地內快速連敲兩下 W。
		elif event.keycode == SpikeKeys.key_of("watch"):
			_try_watch_jump()
			get_viewport().set_input_as_handled()
		# 使用道具（08-12）：三種主動 buff 共用這一顆鍵，一局只會持有一顆。
		# ⚠ 不管 use_buff() 成不成功都算「這顆鍵被處理掉了」——不然沒 buff 的時候按 F
		#   會往下傳給別的處理器，行為隨手上有沒有東西而變。
		elif event.keycode == SpikeKeys.key_of("item"):
			use_buff()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if whip.state == Whip.State.AIMING:
			_end_slowmo()
			var res := whip.fire(player.pos, gen.platforms, gen.monsters)
			# ⚠ 08-13 起這裡**不再補擊殺計數**：鞭中只是暈眩，真正的擊殺發生在
			#   「玩家碰到暈眩怪」那一刻（_check_hazards 的 stunned 分支，走 _kill_monster
			#   ⇒ 計數在那裡）。在這裡補等於「纏到就算殺一隻」，而玩家可能根本沒碰到牠。
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
	_apply_camera()
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
		# 教學關（08-13x）：干擾改成固定高度觸發，時間驅動的登場倒數在這一關沒有意義。
		# ⚠ 不是「歸零就好」——倒數歸零 UI 會改印「Raora 已登場」，而教學關根本沒有
		#   持續的干擾，那行字是純誤導。UI 讀這個旗標把整格藏起來。
		"tutorial": tutorial_mode,
		"interference_active": interference.active(),
		"whip_charges": whip.charges,
		"whip_max": whip.max_charges,
		"jetpack_ratio": player.jetpack_ratio(),
		# 左下角格子要的四個狀態（08-13 項目 13）。⚠ 全部在這裡算好再送出去：
		#   「現在能不能用」的判斷只能有一個家，散到 UI 就會出現「格子是亮的但按下去
		#   沒反應」（同 buff_dimmed 那條）。
		# 噴射冷卻：1.0 ＝ 好了。⚠ 這是**唯一**真的有倒數的格子，黑幕會順時針轉白。
		"jetpack_cd_ratio": (
			1.0 if SpikeConfig.JETPACK_COOLDOWN <= 0.0
			else 1.0 - clampf(
				player.jetpack_cooldown_timer / SpikeConfig.JETPACK_COOLDOWN, 0.0, 1.0
			)
		),
		# 手套／懷錶：有沒有「這一局帶著而且開著」，以及這次離地用掉了沒
		"ledge_on": SpikeSave.has_ledge_grab(),
		"ledge_used": player.ledge_used,
		"watch_on": SpikeSave.has_pocket_watch(),
		"watch_used": player.watch_used,
		"interference": interference.stage_label(),
		"aiming": whip.state == Whip.State.AIMING,
		"aim_ratio": whip.aim_ratio(),
		"coins": coin_count,
		"invuln": player.is_invulnerable(),
		# --- 三選一增益（08-12，SECTION 8e）---
		# ⚠ 「亮還是暗」由 buff_dimmed() 這一個地方決定，不讓 UI 自己拼條件：三種 buff
		#   變暗的理由各不相同（次數用完／錢不夠／被動型永遠不暗），拼在 UI 那邊遲早
		#   會出現「圖示是亮的但按下去沒反應」。
		# 08-13 起是**清單**（最多兩顆，見 buffs 的 ⚠⚠）。UI 照順序由上往下畫，
		# index 0 ＝ 先拿到的＝「使用道具」鍵會先用完的那顆。
		"buffs": buff_hud_slots(),
		"buff_frozen": buff_frozen(),
	}


## 給 HUD 的每格資料。⚠ UI 不准自己去翻 buffs 或 BUFF_TABLE：三種 buff 變暗的理由各不
##   相同（次數用完／錢不夠／被動型永遠不暗），拼在 UI 那邊遲早會出現「圖示是亮的但按
##   下去沒反應」。
func buff_hud_slots() -> Array:
	var out: Array = []
	for i in range(buffs.size()):
		var key := String(buffs[i]["key"])
		out.append({
			"key": key,
			"name": SpikeConfig.buff_name_of(key),
			"glyph": SpikeConfig.buff_glyph_of(key),
			"uses": int(buffs[i]["uses"]),
			"show_uses": SpikeConfig.buff_uses_of(key) > 0,
			"dimmed": buff_dimmed(i),
			"active": SpikeConfig.buff_is_active(key),
			# 這一格是不是「下一次按使用道具鍵會用到的那顆」（優先用完舊的）
			"next": i == active_buff_index(),
		})
	return out


## HUD 的 icon 要不要變暗。三種理由（使用者規格）：
##   ① 有限次數的用完了（護盾、披薩、時間藥水）
##   ② 有使用限制的當下不滿足（金錢彈：本局金幣不足 5）
##   ③ 被動型永遠不暗（石頭、石化、DAHLAH）——它們沒有「用完」這回事
## ⚠ 不能直接用 _slot_ready()：那個函式對**被動型**一律回 false（它問的是「主動鍵按下去
##   有沒有用」），拿來當變暗依據會讓護盾／石化一拿到就是暗的。
func buff_dimmed(i: int) -> bool:
	if i < 0 or i >= buffs.size():
		return true
	var key := String(buffs[i]["key"])
	var init_uses: int = SpikeConfig.buff_uses_of(key)
	if init_uses == 0:
		return false
	if init_uses < 0:
		return not _slot_ready(i)
	return int(buffs[i]["uses"]) <= 0


## 死因 → 結算卡大字（08-13 三訂，使用者給表 dead.txt）。
## ⚠ 家在這裡而不是 SpikeConfig：它比對的是上面那組 CAUSE_* 常數，搬進 config 就得抄
##   字串，抄了會在「改死因文案」時靜默失效（同 SHIELD_IGNORED_CAUSES 的理由）。
##   文字本身仍住 SpikeConfig，這裡只做映射。
## ⚠ height_m 傳的是**這一局的最高高度**（best_m）不是死亡當下的高度，見 SpikeConfig
##   那組常數的 ⚠。
## ⚠ dead.txt 原表只有六句，爆炸平台那句是 08-13 三訂使用者另外補的（DEATH_LINE_BLAST）。
static func death_line(cause: String, height_m: float) -> String:
	match cause:
		CAUSE_MONSTER:
			return SpikeConfig.DEATH_LINE_MONSTER
		CAUSE_PAMELOE_BODY, CAUSE_PAMELOE_SHOT, CAUSE_PAMELOE_LASER:
			return SpikeConfig.DEATH_LINE_PAMELOE
		CAUSE_PROJECTILE, CAUSE_DOOM:
			return SpikeConfig.DEATH_LINE_INTERFERENCE
		CAUSE_BLAST:
			return SpikeConfig.DEATH_LINE_BLAST
	# 摔死（含被抽跳板／側風推下去的那些——它們不直接殺人，最後都走 CAUSE_FALL）
	# 與所有未列名的死因，一律按高度分段。
	if height_m >= SpikeConfig.DEATH_LINE_FALL_HIGH_M:
		return SpikeConfig.DEATH_LINE_FALL_HIGH
	if height_m >= SpikeConfig.DEATH_LINE_FALL_MID_M:
		return SpikeConfig.DEATH_LINE_FALL_MID
	return SpikeConfig.DEATH_LINE_FALL_LOW


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

	_draw_background(top, bot)
	_draw_tutorial_cues()

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

	# 屍體堆畫在平台之前（最底層）：它是背景裝飾，蓋住平台會讓玩家誤以為那裡踩得到東西。
	_draw_corpses(top, bot)

	for p in gen.platforms:
		if p.alive:
			_draw_platform(p)

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

	# 增益球畫在物資之後：它比金幣大得多，被蓋住的機會低，但萬一重疊時該讓「一局一次的
	# 選擇」壓在「隨處可見的金幣」上面。
	_draw_buff_orbs()

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
	if _watch_fx_active:
		_draw_watch_fx()
	_draw_coin_bullets()
	_draw_stone_fx()
	_draw_pizza_fx()
	_draw_time_fx()

	# 側風預警畫在最後（玩家之前）：它是 HUD 性質的滿版提示，被平台蓋住就失去意義
	_draw_shockwave_warn(top)

	# 視野縮小（08-13 第五種干擾）畫在**玩家之前**：暗幕的中心是玩家，蓋在他身上會讓
	# 「燈泡在我身上」這件事讀不出來。其餘一切（平台、怪物、投擲物）都在它底下變暗。
	# ⚠ HUD 不受影響——那是 SpikeUI 的獨立 CanvasLayer，不吃這一層。
	_draw_vision_shrink(top, bot)

	if _dying:
		# 死掉的人不再畫出來——爆炸就是他現在的位置。留著矩形會讓畫面看起來像還活著，
		# 而且摔落死那一種矩形本來就在畫面外，畫了也看不到。
		_draw_death_fx()
	else:
		_draw_player_sprite()
		# 護盾圈畫在主角之後（上層）：08-13 放大成 68 之後圈比角色大，但畫在之前仍會被
		# 貼圖蓋掉中間那段，玩家就看不出「我現在有盾」。
		_draw_shield_ring()


## 第五種干擾的暗幕（08-13，SpikeConfig SECTION 7 的 VISION_*）。
## 做法：一張**放射狀漸層貼圖**（中心透明、CLEAR_RADIUS 之外開始變黑、DARK_RADIUS 之後
## 維持最暗），每幀以玩家為中心畫一次，整體 alpha 乘上淡入係數。
## ⚠ 不是「畫一個大黑矩形再挖洞」：Godot 的 2D 繪製沒有現成的減法混色，挖洞要走 shader
##   或 light mask，那會把這個純表現的效果變成一整套渲染設定。
## ⚠⚠ 也**不要**改回「畫 N 層同心環近似漸層」（第一版的做法）：環與環的重疊處 alpha
##   會疊兩次，實拍看得到一圈一圈的接痕（vision_check_shrink.png 拍到過）。
## ⚠ 貼圖半徑要 >= 畫面對角線，否則玩家貼著角落時對面那個角會沒被壓暗。
func _draw_vision_shrink(_top: float, _bot: float) -> void:
	var k: float = interference.vision_ratio()
	if k <= 0.0:
		return
	if _vision_tex == null:
		_vision_tex = _make_vision_tex()
	var r: float = SpikeConfig.VISION_TEX_RADIUS
	draw_texture_rect(
		_vision_tex, Rect2(player.pos - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false,
		Color(1.0, 1.0, 1.0, k)
	)


## 暗幕貼圖。只建一次（第一次真的要畫的時候），之後每幀重用。
func _make_vision_tex() -> GradientTexture2D:
	var r: float = SpikeConfig.VISION_TEX_RADIUS
	var g := Gradient.new()
	# offsets 是「相對貼圖半徑」的比例。三個節點：亮圈邊緣（全透明）→ 全暗半徑 → 貼圖邊緣
	g.offsets = PackedFloat32Array([
		clampf(SpikeConfig.VISION_CLEAR_RADIUS / r, 0.0, 1.0),
		clampf(SpikeConfig.VISION_DARK_RADIUS / r, 0.0, 1.0),
		1.0,
	])
	var dark := Color(0.0, 0.0, 0.0, SpikeConfig.VISION_MAX_DARKNESS)
	g.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), dark, dark])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	# fill_to 落在右緣中點 ⇒ 漸層半徑＝貼圖寬的一半，跟上面的 offsets 比例對得起來
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = SpikeConfig.VISION_TEX_SIZE
	tex.height = SpikeConfig.VISION_TEX_SIZE
	return tex


## 0~500m backroom 背景（硬規則 4 例外七）。缺檔退回原本的純色 C_BG（main.gd 設的
## viewport clear color），不額外畫東西。
## ⚠⚠ 這裡用內建 draw_texture_rect(tile=true)，而不是仿平台那組手動雙迴圈：平台當年
##   改手動迴圈是因為要把貼圖「縮放」成特定視覺尺寸，tile=true 只認原生像素尺寸鋪，兩者
##   對不上（見 PLATFORM_TEX_CONTENT_FRAC_W 那組常數的 ⚠⚠）。背景不縮放，原生像素就是
##   目標視覺尺寸，這個情境反而是 tile=true 的正確用法。
## ⚠ rect 的 position／size 必須整段固定在世界座標（不能用每幀變動的 top/bot 當
##   rect.position）——tile 的貼磚起點鎖在傳入的 rect.position，如果 position 跟著相機
##   每幀重算，貼磚格線會跟著重新歸零，圖案在畫面上會變成貼在螢幕頂端不動，而不是跟著
##   世界捲動。整段 500m 高的 rect 只在世界座標裡定義一次，可視範圍外的部分由渲染器
##   自然裁掉，不必自己算可見窗口。
func _draw_background(top: float, bot: float) -> void:
	if _bg_backroom_tex == null:
		return
	var band_h := SpikeConfig.BG_TRANSITION_HEIGHT_M * SpikeConfig.PIXELS_PER_METER
	var band_top := start_y - band_h
	draw_texture_rect(
		_bg_backroom_tex,
		Rect2(SpikeConfig.WELL_LEFT, band_top, SpikeConfig.WELL_RIGHT - SpikeConfig.WELL_LEFT, band_h),
		true
	)
	# 暗角疊圖：跟背景本體相反，用「當前可視範圍」當 rect（screen-space），每幀重新
	# 拉伸貼一次、不貼磚——這樣暗角中心永遠落在鏡頭視窗中央，跟著相機捲動，不是釘死
	# 在世界某個座標（見 BG_VIGNETTE_TEX_PATH 的 ⚠）。
	if _bg_vignette_tex != null:
		var y0 := maxf(top, band_top)
		var y1 := minf(bot, start_y)
		if y1 > y0:
			draw_texture_rect(
				_bg_vignette_tex,
				Rect2(SpikeConfig.WELL_LEFT, y0, SpikeConfig.WELL_RIGHT - SpikeConfig.WELL_LEFT, y1 - y0),
				false
			)


## 描邊取樣方向（八方）。⚠ 斜角那四個要除以 √2，否則對角線的描邊會比上下左右厚
##   1.41 倍，輪廓看起來像被削成菱形。
const OUTLINE_DIRS: Array[Vector2] = [
	Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
	Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071),
]


## 三態選貼圖（08-11 使用者拍板改成看**垂直速度**）：
##   往上（vel_y < 0）＝ jump／往下或靜止＝ steady／噴射中＝ jetpack。
## 原本 steady 只在落地那 0.1 秒閃一下，於是整個下墜過程都維持起跳姿勢——爬井有一半
## 時間在往下掉，那半場等於完全沒有姿勢資訊。
## ⚠ 優先序：落地閃現 > jetpack > 速度。落地閃現留著是因為它蓋的正是「剛落地、下一幀就
##   被平台彈成往上」那一瞬——沒有它的話 steady 只會出現不到一幀，撞擊回饋讀不出來。
## 三張畫布尺寸完全一致，用同一個 KAELA_FEET_ANCHOR_FRAC 錨點定位——只換材質、
## 不重算位置，切換姿勢時角色不會跳動（見 SECTION 9b 的錨點量法說明）。
## ⚠ 缺材質（匯入漏掉／路徑錯）就退回原本的色塊，不要讓玩家整個消失看不見。
## 井底屍體堆（08-13 三訂）。用 steady 姿勢的貼圖轉躺平，比活人淡一點。
## ⚠ 每具都要自己 draw_set_transform ＋ 收尾重設回 identity：這個 transform 是整個
##   CanvasItem 層級的，漏收一次之後這一幀的所有繪製都會跟著轉（同 _draw_player_sprite 的 ⚠）。
## ⚠ 沒貼圖時**什麼都不畫**（不像玩家那樣退回色塊）：屍體是裝飾，退化成一排色塊會像
##   井底鋪了一排看不懂的方塊，比沒有更糟。
func _draw_corpses(top: float, bot: float) -> void:
	if _corpses.is_empty() or _kaela_steady_tex == null:
		return
	var art: Vector2 = SpikeConfig.KAELA_ART_SIZE
	var col := Color(1.0, 1.0, 1.0, SpikeConfig.CORPSE_ALPHA)
	for c in _corpses:
		var pos: Vector2 = c["pos"]
		# 井底以外的畫面完全不必處理：屍體只躺在起點上方那一小段
		if pos.y < top - art.y or pos.y > bot + art.y:
			continue
		var rect := Rect2(-art * 0.5, art)
		# 負寬度＝原地鏡像，不要再補 +art.x（同 _draw_player_sprite 的 ⚠）
		if bool(c["flip"]):
			rect = Rect2(Vector2(art.x * 0.5, -art.y * 0.5), Vector2(-art.x, art.y))
		draw_set_transform(pos, float(c["angle"]), Vector2.ONE)
		draw_texture_rect(_kaela_steady_tex, rect, false, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_player_sprite() -> void:
	var tex: Texture2D = _kaela_steady_tex
	var sil: Texture2D = _kaela_steady_sil
	if player.land_flash_timer > 0.0:
		pass   # 落地閃現：強制 steady，見上方 ⚠
	elif player.jetpack_on:
		tex = _kaela_jetpack_tex
		sil = _kaela_jetpack_sil
	elif player.vel_y < 0.0:
		tex = _kaela_jump_tex
		sil = _kaela_jump_sil

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

	# 石化藥水（08-12，SECTION 8e）：整張貼圖繞角色中心旋轉。
	# ⚠⚠ **只有繪製會轉，player.rect() 一動也不動**（SECTION 8e 的 ⚠）：轉起來的矩形
	#   碰撞箱會忽寬忽窄，玩家會遇到「同一個縫有時過得去有時過不去」，那是最難歸因的死法。
	# ⚠ draw_set_transform 之後座標系原點就是 pivot，所以 rect 要先扣掉 pivot；
	#   描邊也在同一個 transform 裡（它吃的是同一個 rect），所以會一起轉。
	# ⚠ 用完一定要重設回 identity——這個 transform 是整個 CanvasItem 層級的，忘了重設
	#   會讓這一幀之後所有的繪製（HUD 以外的一切）全部跟著轉。
	var spinning: bool = has_buff("petrify")
	if spinning:
		draw_set_transform(player.pos, _petrify_spin, Vector2.ONE)
		rect.position -= player.pos

	if invuln_col.a > 0.0 and sil != null:
		_draw_sprite_outline(sil, rect, invuln_col, SpikeConfig.KAELA_OUTLINE_WIDTH)
	draw_texture_rect(tex, rect, false)

	if spinning:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 沿貼圖 alpha 輪廓的描邊：純白剪影往八方各偏 w、畫在本體底下，露出來的那一圈
## 就是輪廓線——貼合那張圖的形狀，不是外接矩形。
## 三個用途共用這一個函式（Kaela 無敵窗、蟲洞常駐金光、Pameloe 充能圈），各自帶自己的
## 寬度與顏色進來。⚠ 共用是刻意的：三處各抄一份的話，「輪廓描邊」這件事就有三種畫法，
##   改一處不會連動另外兩處。
## ⚠ 呼叫端要在畫本體**之前**呼叫——這條線靠的是被本體蓋掉中間、只露出外圈。
## ⚠ 傳進來的必須是剪影不是原圖（理由見 _kaela_*_sil 的 ⚠⚠）。
## ⚠ 不改用 shader：draw_texture_rect 吃的是整個 CanvasItem 的 material，掛上去會連
##   平台、怪物、特效全部一起描邊（本檔所有繪製都在同一個 _draw()）。
## ⚠ dirs 預設是全八方（＝均勻一圈）。傳入子集就是**方向性**描邊：只有那幾個方向被推出去，
##   於是那一側的邊變寬變亮、對側幾乎沒有——蟲洞的逆光就是這樣做出來的（08-11）。
func _draw_sprite_outline(
	sil: Texture2D, rect: Rect2, col: Color, w: float, dirs: Array[Vector2] = OUTLINE_DIRS
) -> void:
	for d in dirs:
		draw_texture_rect(
			sil, Rect2(rect.position + d * w, rect.size), false, col
		)


## 平台四態貼圖尺寸基準：normal.png 的 alpha 內容佔畫布比例（寬 246/297≈0.8283、
## 高 57/94≈0.6064）。四張圖共用同一組比例（同角色多姿勢共用同一比例，是這個專案既有
## 的慣例，不逐張各量各的），只有寬的比例真的進公式——高由畫布原始長寬比反推，
## 不是另外拿高的比例去雙軸硬拉，見 _draw_platform()。
const PLATFORM_TEX_CONTENT_FRAC_W := 246.0 / 297.0
## 來源圖畫布比例（297:94）。縮放只認寬（由碰撞箱寬反推），高跟著比例算，不雙軸硬拉。
const PLATFORM_TEX_CANVAS_ASPECT := 94.0 / 297.0
## 08-11 使用者回報：怪物／蟲洞／Kaela 站上去跟木板之間有一段空隙。查證：三者的腳底
## 錨點（MONSTER_ART_FEET_FRAC／WORMHOLE_ART_FEET_FRAC／KAELA_FEET_ANCHOR_FRAC）跟
## 目前真實 PNG 的 alpha bbox 底邊量測值完全吻合，不是它們的問題。根因在平台這邊：
## normal.png 畫布最上緣到木板本體（alpha 內容頂邊）之間有 18/94≈19% 是留白，但
## draw_pos.y 原本直接拿「畫布頂邊」貼碰撞箱頂緣——木板本體因此比碰撞箱頂緣低了一截，
## 站在碰撞箱頂緣（腳底錨點正確）的東西自然跟低了一截的木板之間出現空隙。
## 四張圖共用這一顆比例（跟 CONTENT_FRAC_W／CANVAS_ASPECT 同一慣例，不逐張各量各的）；
## 木板內容幾乎垂直置中（頂 19.15% / 底留白 20.21%，差不到 1%），鏡像（flip_v）後這顆
## 偏移量仍然近似成立，不必為翻轉另外反推一組。
const PLATFORM_TEX_CONTENT_TOP_FRAC := 18.0 / 94.0


## 依 WellPlatform.kind 選對應貼圖，缺檔 fallback 回原本純色矩形（見 _platform_tex_for）。
## 錨點：貼圖矩形**頂部**貼齊碰撞箱頂部、水平置中——平台是被站的東西，「接觸面」＝
## 碰撞箱頂緣，不是腳底錨點（那是給角色用的）也不是置中疊加。
## 終點平台（is_goal）例外：寬度＝整個井寬，套一般公式會把整張圖橫向拉伸到誇張的比例，
## 改走 _draw_platform_tiled 手動貼磚，不整張拉伸；其餘所有種類單張縮放。
## 08-11 兩個**純視覺**疊加：踩踏晃動的 y 偏移、隨機鏡像。兩者都只活在這個函式裡，
## 判定端（rect()／top_y()／_check_landing）完全不知道它們存在。
## 教學關字卡（08-13x，SECTION 8f）：讀 SpikeConfig.TUTORIAL_CUE_CARDS，逐張畫在
## 對應高度、井心置中的黃底圓角矩形（使用者參考樣式：黃底＋深藍字）。純表現，
## 不參與任何判定，不吃 _rng。只有 10 張，每幀整批畫完全不是效能問題，不做視野裁切。
func _draw_tutorial_cues() -> void:
	if not tutorial_mode:
		return
	if _cue_card_style == null:
		_cue_card_style = StyleBoxFlat.new()
		_cue_card_style.bg_color = SpikeConfig.C_TUTORIAL_CARD_BG
		_cue_card_style.set_corner_radius_all(SpikeConfig.TUTORIAL_CUE_CARD_RADIUS)
	var font: Font = SpikeUI.shared_font()
	var mid_x: float = (SpikeConfig.WELL_LEFT + SpikeConfig.WELL_RIGHT) * 0.5
	var card_w: float = SpikeConfig.TUTORIAL_CUE_CARD_WIDTH
	var pad: float = SpikeConfig.TUTORIAL_CUE_CARD_PADDING
	var text_w: float = card_w - pad * 2.0
	var font_size: int = SpikeConfig.TUTORIAL_CUE_FONT_SIZE
	for row: Dictionary in SpikeConfig.TUTORIAL_CUE_CARDS:
		var h_m: float = float(row["h_m"])
		# ⚠ 一定要走 tutorial_cue_text()：文案裡的 {aim} 之類是按鍵模板，直接畫原字串
		#   玩家會看到大括號（而且改鍵後教學會教錯鍵）。見該函式的 ⚠⚠。
		var text: String = SpikeConfig.tutorial_cue_text(String(row["text"]))
		var y: float = start_y - h_m * SpikeConfig.PIXELS_PER_METER
		var text_size: Vector2 = font.get_multiline_string_size(
			text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_size
		)
		var card_h: float = text_size.y + pad * 2.0
		var rect := Rect2(mid_x - card_w * 0.5, y - card_h * 0.5, card_w, card_h)
		draw_style_box(_cue_card_style, rect)
		draw_multiline_string(
			font, Vector2(rect.position.x + pad, rect.position.y + pad + font_size * 0.85),
			text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_size,
			-1, SpikeConfig.C_TUTORIAL_CARD_TEXT
		)


func _draw_platform(p: WellPlatform) -> void:
	var tex: Texture2D = _platform_tex_for(p.kind)
	if tex == null:
		draw_rect(p.rect(), p.color())
		return

	if p.is_goal:
		_draw_platform_tiled(tex, p)
		return

	var canvas_draw_width: float = p.size.x / PLATFORM_TEX_CONTENT_FRAC_W
	var canvas_draw_height: float = canvas_draw_width * PLATFORM_TEX_CANVAS_ASPECT
	# 踩踏晃動：**只有這裡**加得上去，判定完全不知道有這回事（見 WellPlatform.stomp_offset_y）。
	# y 額外扣掉畫布頂邊留白（見 PLATFORM_TEX_CONTENT_TOP_FRAC 的 ⚠）：貼的是「木板本體
	# 頂邊」對齊碰撞箱頂緣，不是「整張畫布頂邊」對齊，兩者原本差了一截留白的高度。
	var draw_pos := Vector2(
		p.pos.x - canvas_draw_width * 0.5,
		p.top_y() - canvas_draw_height * PLATFORM_TEX_CONTENT_TOP_FRAC + p.stomp_offset_y()
	)
	var draw_size := Vector2(canvas_draw_width, canvas_draw_height)
	# 隨機鏡像：只有共用 normal.png 的那組翻（見 SpikeConfig.PLATFORM_FLIP_H_CHANCE 的 ⚠）。
	# 負寬／負高是**原地**鏡像，position 仍是左上角，不要自己補 `+size`（常青認知第 8 條）。
	if tex == _platform_normal_tex:
		if p.flip_h:
			draw_size.x = -draw_size.x
		if p.flip_v:
			draw_size.y = -draw_size.y
	draw_texture_rect(tex, Rect2(draw_pos, draw_size), false, p.color())


## ⚠⚠ Godot 的 draw_texture_rect(tile=true) 貼磚是照「貼圖原生像素尺寸」（297×94）鋪，
##   不會縮放去配傳入的 rect——套跟其他平台同一組公式算出的視覺尺寸傳進去＋tile=true，
##   Godot 只認原生像素當一塊磚，鋪出來的範圍跟目標視覺尺寸完全對不上（實測：磚塊比
##   預期大好幾倍，往下溢出整個畫面）。改成手動迴圈：每塊磚沿用一般平台同一組公式算出的
##   視覺尺寸（用 PLATFORM_SIZE.x 反推，不是終點平台自己的滿版寬），各自 tile=false 畫，
##   不依賴內建 tile 旗標。最後一塊允許超出右邊界（避免為了對齊邊界擠壓變形）。
func _draw_platform_tiled(tex: Texture2D, p: WellPlatform) -> void:
	var unit_w: float = SpikeConfig.PLATFORM_SIZE.x / PLATFORM_TEX_CONTENT_FRAC_W
	var unit_h: float = unit_w * PLATFORM_TEX_CANVAS_ASPECT
	var left: float = p.pos.x - p.size.x * 0.5
	var right: float = p.pos.x + p.size.x * 0.5
	# 同 _draw_platform() 的留白扣除（見 PLATFORM_TEX_CONTENT_TOP_FRAC 的 ⚠）。
	var top: float = p.top_y() - unit_h * PLATFORM_TEX_CONTENT_TOP_FRAC
	var x := left
	while x < right:
		draw_texture_rect(tex, Rect2(Vector2(x, top), Vector2(unit_w, unit_h)), false, p.color())
		x += unit_w


## move.png 給三種「會動」的平台共用（MOVING／VERTICAL／CIRCULAR），靠
## WellPlatform.color() 的 modulate 顏色分方向（各自底色不同）。其餘（STATIC／EXPLOSIVE）
## 落到預設分支共用 normal.png——EXPLOSIVE 未觸發前刻意跟 STATIC 同色同貼圖，
## 見上方 PLATFORM_NORMAL_TEX_PATH 的 ⚠（08-11 使用者拍板）。
func _platform_tex_for(kind: int) -> Texture2D:
	match kind:
		WellPlatform.Kind.MOVING, WellPlatform.Kind.VERTICAL, WellPlatform.Kind.CIRCULAR:
			return _platform_move_tex
		WellPlatform.Kind.LAUNCHER:
			return _platform_jump_tex
		WellPlatform.Kind.FRAGILE:
			return _platform_break_tex
		_:
			return _platform_normal_tex


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
	var tint := _monster_tint(m)
	if _monster_tex == null:
		draw_rect(mr, SpikeConfig.C_MONSTER * tint)
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
	draw_texture_rect(_monster_tex, rect, false, tint)


## 時間藥水凍結期間的濾鏡色：modulate 是乘法，未凍結時乘純白＝不變色
## （常青認知第 8 條①，同 _draw_dying_monster 的白色 modulate 用法）。
func _frozen_tint() -> Color:
	if buff_frozen():
		return SpikeConfig.C_BUFF_FROZEN_TINT
	return Color(1.0, 1.0, 1.0)


## 這一隻該套什麼濾鏡色：凍結（時間藥水）× 暈眩（鞭子纏中，08-13）。
## ⚠ 兩者相乘而不是二選一：同時成立時應該兩種訊息都看得出來。
## ⚠ 暈眩一定要有視覺差異——「這隻不會動也不會殺我」是玩家下一步的決策依據，
##   看起來跟活的一模一樣的話，玩家只會繞開它，鞭子的新規格等於白做。
func _monster_tint(m: WellMonster) -> Color:
	var c := _frozen_tint()
	if m.stunned:
		c *= SpikeConfig.C_MONSTER_STUN_TINT
	return c


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
	var tint := _monster_tint(m)
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
		draw_texture_rect(tex, art_rect, false, tint)
		return
	var wing := r.size.y * 0.30
	var wing_y := r.position.y + r.size.y * 0.32
	var wing_h := wing * 0.7
	var wing_col := Color(SpikeConfig.C_PAMELOE, 0.45) * tint
	draw_rect(Rect2(r.position.x - wing, wing_y, wing, wing_h), wing_col)
	draw_rect(Rect2(r.end.x, wing_y, wing, wing_h), wing_col)

	draw_rect(r, SpikeConfig.C_PAMELOE * tint)
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
		# 逆光三件套，全部畫在本體**之前**：描邊靠的是被本體蓋掉中間、只露出外圈那一圈；
		# 光暈更是「背後那片天空」，畫在後面才叫背光。
		if _wormhole_sil != null:
			# ① 背後暖光暈（光源偏左上）
			_draw_radial_bloom(
				art_rect.get_center()
					+ SpikeConfig.WORMHOLE_BLOOM_OFFSET_FRAC * art_size,
				SpikeConfig.WORMHOLE_BLOOM_RADIUS, SpikeConfig.WORMHOLE_BLOOM_PEAK,
				SpikeConfig.C_WORMHOLE_GLOW
			)
			# ② 全向淡底邊：背光側不至於整片糊進背景
			_draw_sprite_outline(
				_wormhole_sil, art_rect,
				Color(SpikeConfig.C_WORMHOLE_GLOW, SpikeConfig.WORMHOLE_GLOW_RIM_ALPHA),
				SpikeConfig.WORMHOLE_GLOW_RIM_W
			)
			# ③ 偏光側的漸層描邊，由寬而淡 → 窄而亮（順序不可反，見 WORMHOLE_GLOW_LAYERS）
			for layer in SpikeConfig.WORMHOLE_GLOW_LAYERS:
				_draw_sprite_outline(
					_wormhole_sil, art_rect,
					Color(SpikeConfig.C_WORMHOLE_GLOW, layer.y), layer.x,
					SpikeConfig.WORMHOLE_GLOW_BIAS_DIRS
				)
			# ④ 最內層白熱邊：金色到頂仍是「亮金」，要「燙」得再往白推一階
			_draw_sprite_outline(
				_wormhole_sil, art_rect,
				Color(SpikeConfig.C_WORMHOLE_HOT, SpikeConfig.WORMHOLE_GLOW_HOT_ALPHA),
				SpikeConfig.WORMHOLE_GLOW_HOT_W
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


## 柔和的徑向光暈：由外而內的同心橢圓。
## ⚠⚠ 每一圈的 alpha 是**反推**出來的、不是每圈給同一個值：目標是讓「疊完之後」的累積
##   alpha 落在 T(t) = peak × (1−t)^FALLOFF 這條曲線上（t＝半徑比例，1＝最外圈）。
##   由外往內畫、已疊到 prev 時，這一圈要補的量就是 (T−prev)/(1−prev)。
##   偷懶用固定 alpha 疊 N 圈的話，中心會直接飽和成一塊實心色塊（實測踩過）。
## ⚠ draw_circle 畫不出橢圓，靠 draw_set_transform 縮放；**畫完一定要還原**——本檔所有
##   繪製共用同一個 _draw()，忘記還原會把後面每一樣東西一起壓扁。
func _draw_radial_bloom(center: Vector2, radius: float, peak: float, col: Color) -> void:
	var steps: int = SpikeConfig.WORMHOLE_BLOOM_STEPS
	draw_set_transform(center, 0.0, Vector2(1.0, SpikeConfig.WORMHOLE_BLOOM_SQUASH))
	var prev := 0.0
	for i in range(steps, 0, -1):
		var t := float(i) / float(steps)
		var target: float = peak * pow(1.0 - t, SpikeConfig.WORMHOLE_BLOOM_FALLOFF)
		var a: float = (target - prev) / maxf(0.0001, 1.0 - prev)
		prev = target
		if a < 0.002:   # 換算成 8-bit alpha 不足 0.5，畫了也看不見
			continue
		draw_circle(Vector2.ZERO, radius * t, Color(col, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


## 懷錶二段跳的回饋：同 _draw_ledge_fx 的畫法，換一組常數與顏色（金黃）。
## 分開寫而不是抽共用函式：兩者只有「哪一組常數」不同，抽掉之後反而要多傳四個參數，
## 而且它們的視覺日後八成會各自長歪（見 SECTION 3c 的說明）。
func _draw_watch_fx() -> void:
	var t: float = clampf(_watch_fx_timer / SpikeConfig.WATCH_FX_DURATION, 0.0, 1.0)
	var r: float = lerpf(SpikeConfig.WATCH_FX_RADIUS_START, SpikeConfig.WATCH_FX_RADIUS_END, t)
	var a: float = 1.0 - t
	draw_arc(
		_watch_fx_pos, r, 0.0, TAU, 32,
		Color(SpikeConfig.C_WATCH_FX, a), SpikeConfig.WATCH_FX_LINE_WIDTH
	)


# ============================================================
# 增益（SECTION 8e）的繪製 — 目前全部是 placeholder 美術
# ============================================================
# ⚠ 這一整段是「純色 ＋ _draw()」的 placeholder（專案 CLAUDE.md 硬規則 4）。使用者會補
#   九張 112×112 的 PNG（八種 buff ＋ 懷錶），到位後走 skill `/import-art-asset` 換成
#   draw_texture_rect，目標視覺尺寸 BUFF_ORB_ART_SIZE（56×56，來源是它的 2 倍）。

func _draw_buff_orbs() -> void:
	for orb in gen.buff_orbs:
		if not orb.alive:
			continue
		if orb.exploding:
			_draw_buff_orb_explosion(orb)
			continue
		var r: float = SpikeConfig.BUFF_ORB_ART_SIZE.x * 0.5
		draw_circle(orb.pos, r, _buff_placeholder_color(orb.key))
		draw_arc(orb.pos, r, 0.0, TAU, 28, SpikeConfig.C_BUFF_ORB_RING, 2.5)
		_draw_buff_pips(orb.pos, orb.key, r)


## placeholder 的辨識方式：色相 ＋ 中央的小點數（＝這顆 buff 在 BUFF_KEYS 裡的序號）。
## ⚠ 用點數而不是文字：WellWorld 從來沒有載入過字型，為了一個暫時的 placeholder 引進
##   一份字型資源，等真實素材到位後多半會變成沒人記得刪的殘留。
func _draw_buff_pips(center: Vector2, key: String, r: float) -> void:
	var n: int = SpikeConfig.BUFF_KEYS.find(key) + 1
	if n <= 0:
		return
	var pip_r: float = r * 0.13
	var ring: float = r * 0.45
	for i in range(n):
		var ang: float = -PI * 0.5 + TAU * float(i) / float(n)
		draw_circle(
			center + Vector2(cos(ang), sin(ang)) * ring, pip_r, SpikeConfig.C_BUFF_ORB_RING
		)


func _buff_placeholder_color(key: String) -> Color:
	var idx: int = SpikeConfig.BUFF_KEYS.find(key)
	if idx < 0:
		return SpikeConfig.C_BUFF_ORB
	return Color.from_hsv(float(idx) / float(SpikeConfig.BUFF_KEYS.size()), 0.55, 1.0)


## 沒選到的那兩顆爆掉：圓圈往外擴同時淡出。
## ⚠⚠ 這個爆炸**沒有任何判定**（WellBuffOrb 檔頭的 ⚠⚠）——所以它刻意畫成細環而不是
##   實心火球，跟爆炸平台（_draw_blasts，會致死）在視覺上就分得開。
func _draw_buff_orb_explosion(orb: WellBuffOrb) -> void:
	var t: float = orb.explode_progress()
	var r: float = lerpf(
		SpikeConfig.BUFF_ORB_ART_SIZE.x * 0.5, SpikeConfig.BUFF_ORB_EXPLODE_RADIUS, t
	)
	draw_arc(
		orb.pos, r, 0.0, TAU, 28,
		Color(SpikeConfig.C_BUFF_EXPLODE, 1.0 - t), SpikeConfig.BUFF_ORB_EXPLODE_RING_WIDTH
	)


## 金錢彈。用金幣的顏色是刻意的：玩家要看得出「那是我剛花掉的錢飛出去了」。
func _draw_coin_bullets() -> void:
	for b in _coin_bullets:
		draw_circle(
			b["pos"], SpikeConfig.BUFF_COIN_BULLET_SIZE.x * 0.5, SpikeConfig.C_PICKUP
		)


## 石頭藥水的視覺替身：腳底往上噴一排石屑。
## ⚠ 這是音效系統上線前的佔位（SECTION 8e 的 ⚠），不是最終效果——規格是「聲音改變」。
func _draw_stone_fx() -> void:
	for fx in _stone_fx:
		var t: float = 1.0 - clampf(
			fx["timer"] / SpikeConfig.BUFF_STONE_FX_DURATION, 0.0, 1.0
		)
		var rr: float = SpikeConfig.BUFF_STONE_FX_RADIUS * t
		var col := Color(SpikeConfig.C_BUFF_STONE_FX, 1.0 - t)
		var n: int = SpikeConfig.BUFF_STONE_FX_COUNT
		for i in range(n):
			# PI ~ 2PI ＝ 上半圈（Godot 的 +y 朝下）
			var ang: float = PI + PI * (float(i) + 0.5) / float(n)
			draw_circle(fx["pos"] + Vector2(cos(ang), sin(ang)) * rr, 3.0, col)


## 護盾持有中：主角身上常駐一圈同心圓。⚠ 不吃計時器，每幀直接問持有狀態——用完
## （buff_uses 歸零）當幀這條件就不成立，圈子跟著同一幀消失，不需要另外觸發淡出。
func _draw_shield_ring() -> void:
	if buff_uses_left("shield") <= 0:
		return
	draw_arc(
		player.pos, SpikeConfig.BUFF_SHIELD_RING_RADIUS, 0.0, TAU, 32,
		SpikeConfig.C_BUFF_SHIELD_RING, SpikeConfig.BUFF_SHIELD_RING_LINE_WIDTH
	)


## 鳳梨披薩使用瞬間：外擴同心圓，畫法同 _draw_ledge_fx，陣列版（見 _pizza_fx 的 ⚠）。
func _draw_pizza_fx() -> void:
	for fx in _pizza_fx:
		var t: float = 1.0 - clampf(fx["timer"] / SpikeConfig.BUFF_PIZZA_FX_DURATION, 0.0, 1.0)
		var r: float = lerpf(
			SpikeConfig.BUFF_PIZZA_FX_RADIUS_START, SpikeConfig.BUFF_PIZZA_FX_RADIUS_END, t
		)
		draw_arc(
			fx["pos"], r, 0.0, TAU, 32,
			Color(SpikeConfig.C_BUFF_PIZZA_FX, 1.0 - t), SpikeConfig.BUFF_PIZZA_FX_LINE_WIDTH
		)


## 時間藥水使用瞬間：同上，換一組常數與顏色。
func _draw_time_fx() -> void:
	for fx in _time_fx:
		var t: float = 1.0 - clampf(fx["timer"] / SpikeConfig.BUFF_TIME_FX_DURATION, 0.0, 1.0)
		var r: float = lerpf(
			SpikeConfig.BUFF_TIME_FX_RADIUS_START, SpikeConfig.BUFF_TIME_FX_RADIUS_END, t
		)
		draw_arc(
			fx["pos"], r, 0.0, TAU, 32,
			Color(SpikeConfig.C_BUFF_TIME_FX, 1.0 - t), SpikeConfig.BUFF_TIME_FX_LINE_WIDTH
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
