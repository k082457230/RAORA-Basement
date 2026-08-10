extends Node
## 爬井 spike 的唯一數值來源。
## 規則：任何可調數字都住在這裡，其他檔一律引用，不准出現字面值。
## 未來若只想「抄數字走」，抄這一個檔就夠。
##
## ── 索引：想改什麼，去哪段 ──
## 用 Grep 找段落標題定位，例如 Grep "SECTION 4 —"（含子編號的段用完整字串，
## 例如 Grep "SECTION 4b —"）。索引刻意不寫行號——行號一改就過期，過期的索引比沒有更糟。
##
##  1. 尺度與場地 — 想改「畫面大小、井有多寬、相機何時往上推」時來這段
##  2. 水平移動（滑鼠） — 想改「滑鼠拖曳黏不黏、會不會滑過頭」時來這段
##  2b. 水平移動（鍵盤） — 想改「鍵盤左右移動速度、切滑鼠/鍵盤模式、預設按鍵」時來這段
##  3. 跳躍 — 想改「跳得太低／太高、重力、下墜速度、落地容差」時來這段
##  3b. 攀爬 — 想改「差一點跳不上去要不要自動補跳、攀爬手套判定/特效」時來這段
##  4. 平台 — 想改「平台間距太密／太鬆、移動/圓形平台速度、左右分佈、彈射器」時來這段
##  4b. 物資 — 想改「東西太難撿到、金幣/燃料補給掉落率、怪物太多/太少、怪物死亡飛出去的
##      幅度、踩頭退鞭子的機率、pameloe 太多/射太快/子彈太快、墓碑大小/獎勵」時來這段
##  4c. 蟲洞 — 想改「蟲洞太稀有/太常見、一次送多遠、旋轉/過場速度」時來這段
##  4e. 特殊區段 — 想改「主題區多長/多常見、裡面只出哪種平台、怪物與金幣加倍多少」
##      時來這段（新增一種主題區＝在 SEGMENT_TABLE 加一列）
##  5. 鞭子 — 想改「鞭子次數、拉近速度、瞄準時間、射程」時來這段
##  6. Jetpack — 想改「燃料上限、燃料耗多快、噴射推力」時來這段
##  6b. 無敵窗 — 想改「鞭子/噴射時無敵多久」時來這段
##  6c. 死亡演出 — 想改「死掉時爆炸多大/多久、結算小卡多大/推進來多快/背景壓多暗」時來這段
##  7. Raora 干擾 — 想改「投擲物太密/太大、抽跳板太快、側風陣風太強/太頻繁、黑洞太大/
##      吸太兇/活太久、四種預警（紅三角／削板火花／右緣綠條／紫圈）的時長與強度」時來這段
##  8. 局長 preset — 想改「干擾太早／太晚來、一局多長」時來這段
##      ⚠ **終點多遠已經不歸這段管**，改 SECTION 8d 的 LEVEL_GOALS
##  8d. 關卡 — 想改「三關各爬多高、關卡名稱、通關劇情文字」時來這段
##  8b. 金幣與永久升級 — 想改「商店某項太貴、升級效果太強/太弱、升級級數上限」時來這段
##  8c. 成就 — 想改「成就名稱／解鎖條件的門檻數字／領獎金幣」時來這段
##  9. 顏色 — 想改「畫面顏色」時來這段（純表現，改了不影響任何行為）
##  9b. 玩家貼圖 — 想改「Kaela 貼圖尺寸、腳底錨點、落地閃現姿勢顯示多久」時來這段
##      （怪物／蟲洞／Pameloe 的貼圖尺寸與腳底錨點跟著各自的機制走，分別在 4b / 4c）
##  9c. 高度階級提示 — 想改「跨階提示在幾公尺變色、變成什麼顏色」時來這段
##  10. 導出值 — 不要手改，是上面數字算出來的。**極限模式與無盡模式的生效值（eff_*）
##      也在這段**
##  11. 開發者工具 — 想改「測試用傳送鈕跳多高、開發者模式怎麼開」時來這段
##      （正式版玩家碰不到，見該段開頭的 ⚠⚠）

# ===== SECTION 1 — 尺度與場地 =====
# 連動警告：PIXELS_PER_METER 是全檔所有 *_M 高度門檻（SECTION 4b 物資／4c 蟲洞／
# 8 preset 的 goal_meters）換算成像素的唯一依據——改了它，其他段寫的「幾公尺」
# 語意都會跟著位移，不是只有這段的視覺尺度。
#
## PIXELS_PER_METER：遊戲公尺 → 像素。這是計分尺度，不是物理尺度。
## 校準依據：PILLARS 的 2.39 m/s 錨點（採集流 2:00 → 287m）。
## 目前跳躍弧 ~0.68s、平均淨爬升 ~150px → 約 2.8~3.0 m/s，同一量級。
#
## 相機：觸發線制，不是黏著玩家。玩家越過畫面上方 CAMERA_SCROLL_TRIGGER 這個比例的
## 位置，相機才往上推；相機永不下降。這條線決定「漏接一塊板還救不救得回來」。
## ⚠ 別改回「把玩家固定在畫面 N% 處」的黏著式相機。實測過：黏著頂點時玩家下方
##   只剩 (1-N)*VIEW_H，而一次跳躍就吃掉 202px，等於漏接一塊即死，冒煙測試的
##   落地次數會直接掉到 0。觸發線制把可回收高度從約 148px 拉到約 380px。

const PIXELS_PER_METER := 50.0

const VIEW_W := 1280.0
const VIEW_H := 720.0

const WALL_THICKNESS := 90.0           # 井壁厚度（鞭子可纏的標的之一）
const WELL_LEFT := WALL_THICKNESS
const WELL_RIGHT := VIEW_W - WALL_THICKNESS

const PLAYER_SIZE := Vector2(38.0, 54.0)

const CAMERA_SCROLL_TRIGGER := 0.35    # 觸發線，見上方 ⚠
const CAMERA_START_RATIO := 0.70       # 開局時玩家在畫面上的位置（越大＝越靠下）

# ===== SECTION 2 — 水平移動（滑鼠拖曳感） =====
# 手感三件套：GAIN 決定「黏不黏滑鼠」，ACCEL 決定起步俐落度，
# DECEL 刻意 < ACCEL → 停不下來、會滑過頭 = 拖曳感的來源。
# 跟 SECTION 2b（鍵盤）刻意分開調參，兩套邏輯互不影響，見 2b 開頭說明。

const MOUSE_FOLLOW_GAIN := 10          # 滑鼠距離 → 目標速度的增益，1/s
const MOVE_MAX_SPEED := 1000.0
const MOVE_ACCEL := 1000.0
const MOVE_DECEL := 500.0              # 刻意 < ACCEL，見上方三件套說明
const MOUSE_DEADZONE := 4.0            # 靠到滑鼠這個像素距離內就視為到位，避免抖動

# ===== SECTION 2b — 水平移動（鍵盤 AD，跟滑鼠拖曳並存、獨立調參） =====
# 跟滑鼠那組（SECTION 2）刻意分開：滑鼠的 DECEL<ACCEL 是特意做出「停不住會滑過頭」的
# 拖曳感，鍵盤這組預設 ACCEL=DECEL，放開就乾脆停下，不繼承滑鼠的滑行手感。
#
## ACTIVE_INPUT_MODE：MOUSE_DRAG＝滑鼠拖曳跟隨（原版，驗證的是「滑鼠拖曳移動」這條
## 手感）；KEYBOARD＝A/D 左右移動、E 出鞭子（簡化版，上手快，但這次跑局就驗證不到
## 滑鼠拖曳手感）。兩套邏輯都在，只需要切這個常數，不用動 well_world.gd。
#
## 按鍵預設值。實際生效的綁定住 SpikeKeys（可在設定頁改、存 user://），但「預設是
## 什麼」仍屬可調數值，所以正本在這裡，SpikeKeys 只負責覆寫與存檔。
## ⚠ key 同時是存檔欄位名，改名會讓舊的按鍵存檔那一項退回預設（可接受）。

enum InputMode { MOUSE_DRAG, KEYBOARD }
const ACTIVE_INPUT_MODE := InputMode.KEYBOARD  # 切這個常數就換整套輸入模式

const KB_MOVE_MAX_SPEED := 1400.0
const KB_MOVE_ACCEL := 2400.0
const KB_MOVE_DECEL := 2400.0

const DEFAULT_KEYS := {
	"left": KEY_A,
	"right": KEY_D,
	"aim": KEY_E,
	"jet": KEY_SPACE,
	"pause": KEY_ESCAPE,
}
const KEY_ORDER := ["left", "right", "aim", "jet", "pause"]
const KEY_NAMES := {
	"left": "左移",
	"right": "右移",
	"aim": "鞭子瞄準",
	"jet": "噴射（長按）",
	"pause": "暫停",
}

# ===== SECTION 3 — 跳躍 =====
# 連動警告：GRAVITY／JUMP_VELOCITY 改了 → MAX_JUMP_HEIGHT 是導出值（公式見下方
# 常數旁註解），SECTION 4 的間距／振幅／半徑上限、SECTION 3b 攀爬、SECTION 4b/8b 的
# 「基礎跳躍高度」全部跟著變，等於連動整個生成器的可達性天花板。

const GRAVITY := 2000.0
const JUMP_VELOCITY := -900.0          # Godot 2D：-y 是上
const MAX_FALL_SPEED := 1500.0
const MAX_JUMP_HEIGHT := 202.5         # 由上兩者導出：900^2 / (2*2000)，生成器用它保證可達性
const LAND_TOLERANCE := 10.0           # 落地判定容差 px。太小高速下墜穿板，太大平台下緣被吸上來

# ===== SECTION 3b — 攀爬（特殊裝備，商店解鎖） =====
# 連動警告：REACH／VEL_WINDOW 只補「差一點」，跟 SECTION 4 的可達性上限無關——生成器
# 永遠用 SECTION 3 的 MAX_JUMP_HEIGHT（基礎值），不讀這裡（見下方 ⚠）。
#
# 落地判定是「跨越偵測」不是「底部 Y > 上緣 Y」：只有下墜中、且這一幀從平台上緣
# 之上跨到之下才算落地（見 well_world._check_landing）。所以「差一點跳不上去」的
# 物理事實是——**跳躍頂點時腳底仍在平台上緣之下**，於是整段下墜都不成立，直接摔下去。
#
# 攀爬就是補這一段：頂點附近若上緣就在腳底上方 REACH 之內，補一次剛好夠越過的小跳。
#
# ⚠ 這不會讓井變難：生成器的可達性單位永遠是 SpikeConfig.MAX_JUMP_HEIGHT（基礎值），
#   不讀升級／裝備（PILLARS_2.md:427）。最大間距 202.5*0.93 = 188px，離基礎跳躍高度
#   只差 14.5px，攀爬 REACH 設 30px 只能把「差一點」救回來，不足以讓玩家跳過兩格
#   （那要 376px）。
# ⚠ 每次離地限一次（player.ledge_used），否則連續小跳＝無限爬升。
#
## LEDGE_GRAB_VEL_WINDOW：只在「頂點附近」才算數，|vel_y| 超過這個值就不觸發。窗口窄
## 是刻意的——開太大會變成上升途中就被吸上去，玩家會覺得角色自己亂動。
#
## 攀爬成功特效：白色圓圈從觸發點往外擴、同步淡出，純視覺回饋（見
## well_world._try_ledge_grab／_draw_ledge_fx）。釘在觸發當下的世界座標，不跟著
## 平台走——效果只活 LEDGE_FX_DURATION 這麼短，沒必要為此多存一份平台參照。

const LEDGE_GRAB_REACH := 30.0         # 頂點附近，上緣在腳底上方這個範圍內才補跳
const LEDGE_GRAB_VEL_WINDOW := 130.0   # |vel_y| 超過就不觸發，見上方說明
const LEDGE_GRAB_CLEAR := 10.0         # 攀上去時多給的餘裕 px，確保落地判定接得住

const LEDGE_FX_DURATION := 0.4
const LEDGE_FX_RADIUS_START := 8.0
const LEDGE_FX_RADIUS_END := 46.0
const LEDGE_FX_LINE_WIDTH := 3.0

# ===== SECTION 4 — 平台 =====
# 連動警告：SPACING_HARD_CAP_RATIO、VERTICAL_AMP_*、CIRCULAR_RADIUS_* 這三組的安全
# 上限全部錨定 SECTION 3 的 MAX_JUMP_HEIGHT（基礎跳躍高度）——改了跳躍段的 GRAVITY／
# JUMP_VELOCITY，這裡的「安全上限」會跟著鬆動或收緊，細節見各自警語。
#
# 命名慣例：本段大量成對常數用 `_AT_0` / `_AT_TOP` 命名，語意都是「隨高度 h 線性內插」，
# 0m 用 AT_0、終點高度用 AT_TOP，中間值由生成器插值算出——下面不逐組重複這句。

## --- 起跳平台 ---
## START_PLATFORM_WIDTH_MULT：起跳平台寬度＝一般平台的這個倍數（玩家一開局不會掉下去）。
#
## --- solo 區間加寬（08-10 二訂，使用者拍板）---
## PLATFORM_WIDTH_MULT_SOLO：BAND_SOLO_HEIGHT_M 以上的主鏈平台寬度倍率。
## ⚠⚠ 這是**可歸因性的保命條款，不是美觀參數**。原因是一組可以算出來的幾何：
##   平台半寬 60、怪物判定半寬 23、巡邏範圍 ±45 ⇒ 怪物掃過的包絡線是 ±68，
##   **比平台本身還寬**——平台上不存在任何一個 x 是怪物永遠碰不到的。
##   solo 區間又沒有備援跳板，於是「唯一那塊板上有怪物」＝ 只能靠 jetpack／鞭子繞過去，
##   踩邊緣等牠走開在數值上**根本不成立**（真人試玩回報，08-10）。
##   要讓「站在邊緣」有解，需要：玩家中心離怪物 >= (PLAYER_SIZE.x + MONSTER_SIZE.x)/2 = 42，
##   同時仍與平台重疊（中心最遠 = 半寬 + PLAYER_SIZE.x/2）。加寬與縮巡邏兩手一起下之後，
##   兩側各留約 37px 的安全落腳窗。這條關係有稽核在守（`tests/audit_levels.gd`
##   `_audit_solo_foothold`），改任何一顆相關常數把窗口壓到 SOLO_FOOTHOLD_MIN 以下會紅。
## ⚠ 刻意**只加寬 solo 區間**而不是全域放大 PLATFORM_SIZE：全域加寬會把低處一起變簡單，
##   等於整條難度曲線下修，而低處本來就有額外跳板當備援、沒有這個問題。
## ⚠ 加寬吃到所有種類（含 MOVING／CIRCULAR），是為了同一高度的板看起來一致；終點平台
##   除外（`_make_goal` 自己覆寫成全寬）。
#
## --- 同高度區間的額外跳板（doodle jump 式並排，v9）---
## 主鏈那顆（保證可達、會延續生成鏈）之外，同一區間再加幾顆額外跳板，純選項、恆為
## STATIC、不掛怪物——不然「抽跳板後仍可解」的判定會多一倍複雜度（見 HANDOFF 未決清單 #5）。
##
## 數量是「期望值」而非固定範圍：0m 給 BAND_EXTRA_EXPECT_AT_0，線性遞減，到
## BAND_SOLO_HEIGHT_M 歸零。該高度以上每個區間永遠只剩主鏈那一顆，這就是「越往上
## 密度越低」的水平分量（垂直分量由 SPACING_* 負責）。
##
## ⚠ BAND_EXTRA_Y_DROP 只往下（+y）不往上：往上會讓玩家實際要跳的高度超過 spacing
##   的可達性上限，等於偷偷突破 SPACING_HARD_CAP_RATIO 這條防線。實際落差還會再被
##   「下方那塊平台的擺動包絡線」壓縮，見 well_generator。
##
## PLATFORM_MIN_GAP：任兩塊平台的「水平運動包絡線」之間至少要留的 px。包絡線＝含板寬
## ＋ 移動平台的整段巡邏／繞圈範圍，所以移動平台不會掃進鄰居身上。
## BAND_EXTRA_PLACEMENT_TRIES：額外跳板找不到不重疊的位置時最多重試幾次就放棄這一顆
## （寧可少一顆也不擠爆）。
#
## --- 左右分佈平衡（v9）---
## 病灶：下一塊的 x 是「以上一塊為中心 ±315px 均勻抽」＝典型的隨機遊走。井寬只有
## 1100px，隨機遊走天生會在局部盤旋，連續 8~10 塊全落同一側是機率上的正常結果，
## 不是 bug——但看起來就是「這一段平台全擠在左邊」。
## 解法：記一條近期落點的指數移動平均（EMA），偏離井心超過死區時，才在可達視窗內
## 多抽幾個候選、挑最靠近「鏡射點」的那個。用死區而不是每塊都糾正，是為了避免
## 生出「左右左右」的機械式鋸齒——那比原本的群聚更假。
## ⚠ X_BALANCE_CANDIDATES 實測（固定 seed，見 smoke 的生成器稽核）：關閉（=1）時最長
##   同側連續 34 塊、左半 56%；開到 3 之後降到 12 塊、左半 51%。代價是平均橫移需求
##   112 → 126 px（最大值不變，仍被可達視窗夾住）。要更平均就調大，但橫移需求會跟著漲。
#
## --- 間距 spacing ---
## ⚠ 語意是「最壞情況下玩家要跳的淨高度」——上一塊擺到最低、這一塊擺到最高時的距離。
##   中心點距離由生成器從這個值反推，不等於這個值。SPACING_HARD_CAP_RATIO 是硬上限：
##   永遠不得超過基礎跳躍高度的這個比例（P4 的可達性防線）。
#
## --- 移動平台（左右巡邏）---
## MOVING_PATROL_RANGE_SOLO 用在 BAND_SOLO_HEIGHT_M 以上：該高度起一個區間只有一塊板，
## 沒有備援，板子跑太遠等於逼玩家在單一水平可達視窗之外接板 = 運氣牆，所以巡邏半徑較小。
#
## --- 上下移動平台 vertical ---
## 振幅算進「垂直包絡線」，生成器據此決定中心距，不會夾到上下鄰居。
## ⚠ 振幅上限受 4*AMP + PLATFORM_VERTICAL_CLEARANCE <= MAX_JUMP_HEIGHT*CAP_RATIO 約束
##   （上下兩塊都是移動平台時的最壞情況）。目前 4*38+24 = 176 <= 188，還有餘裕。
#
## --- 圓形軌跡平台 circular ---
## 半徑同時吃掉水平與垂直兩個方向的包絡線，上限約束同 vertical。
#
## --- 易碎平台（踩一次即碎）---
## ⚠ 踩到後不是「延遲一下然後瞬間消失」，是**整段淡出**（使用者拍板）：FRAGILE_FADE_TIME
##   同時是「還踩得住多久」與「alpha 從 1 掉到 0 要多久」，兩者刻意同一個數字——
##   看得見的透明度就是剩餘可站時間，玩家不需要另外背一個隱形的寬限期。
##   所以這個值比舊的 0.12s 長：0.12s 淡出等於閃一下，看不出是淡出。
#
## --- 生成器可達性檢查 ---
## REACHABILITY_MARGIN：玩家不會瞬間全速，保守係數抓 7 成。
#
## --- 彈射器（v4 加速元件）---
## ⚠ 越高越少：高處要的是精準接板，被彈射器甩上去反而會衝過尚未生成的空域再摔回來，
##   跟「頂端密度低」相乘會變成純運氣，所以 LAUNCHER_RATIO 隨高度遞減。

const PLATFORM_SIZE := Vector2(120.0, 18.0)
const FRAGILE_SIZE := Vector2(120.0, 18.0)
const LAUNCHER_SIZE := Vector2(110.0, 22.0)
const VERTICAL_SIZE := Vector2(120.0, 18.0)
const CIRCULAR_SIZE := Vector2(110.0, 18.0)
const START_PLATFORM_WIDTH_MULT := 5
const PLATFORM_WIDTH_MULT_SOLO := 1.3   # 見上方 ⚠⚠，是保命條款不是美觀參數
## solo 區間「怪物永遠碰不到、又還踩得到平台」的落腳窗最小寬度（px，單側）。
## 稽核用的下限，不是給生成器讀的——它存在的意義是讓「有解」變成一條驗得到的斷言，
## 而不是註解裡的一段推導（見常青認知第 6 條：保命條款型常數要另寫驗常數關係的斷言）。
const SOLO_FOOTHOLD_MIN := 24.0

const BAND_EXTRA_EXPECT_AT_0 := 1.6
const BAND_SOLO_HEIGHT_M := 690.0
const BAND_EXTRA_Y_DROP := 20.0
const PLATFORM_MIN_GAP := 26.0
const PLATFORM_VERTICAL_CLEARANCE := 24.0
const BAND_EXTRA_PLACEMENT_TRIES := 8
## 隨機試完仍失敗時，確定性掃描的步進（px）。只有主題區會走到這條路徑
## （見 WellGenerator._pick_x_apart 的 ⚠⚠）。⚠ 步進要明顯小於平台寬，否則會跳過
##   兩塊板之間剛好夠用的縫隙，掃描等於白做。
const BAND_EXTRA_SCAN_STEP := 20.0

const X_BALANCE_EMA_ALPHA := 0.28
const X_BALANCE_DEADZONE := 90.0
const X_BALANCE_CANDIDATES := 3

const SPACING_MIN_AT_0 := 95.0
const SPACING_MAX_AT_0 := 140.0
const SPACING_MIN_AT_TOP := 138.0
const SPACING_MAX_AT_TOP := 188.0
const SPACING_HARD_CAP_RATIO := 0.93

const MOVING_RATIO_AT_0 := 0.05
const MOVING_RATIO_AT_TOP := 0.30
const MOVING_SPEED_MIN := 55.0
const MOVING_SPEED_MAX := 135.0
const MOVING_PATROL_RANGE := 120.0
const MOVING_PATROL_RANGE_SOLO := 70.0

const VERTICAL_RATIO_AT_0 := 0.03
const VERTICAL_RATIO_AT_TOP := 0.16
const VERTICAL_AMP_MIN := 24.0
const VERTICAL_AMP_MAX := 38.0
const VERTICAL_SPEED_MIN := 40.0
const VERTICAL_SPEED_MAX := 95.0

const CIRCULAR_RATIO_AT_0 := 0.0
const CIRCULAR_RATIO_AT_TOP := 0.14
const CIRCULAR_RADIUS_MIN := 26.0
const CIRCULAR_RADIUS_MAX := 38.0
const CIRCULAR_ANGULAR_SPEED_MIN := 0.7   # rad/s
const CIRCULAR_ANGULAR_SPEED_MAX := 1.6

const TRAP_RATIO_AT_0 := 0.0
const TRAP_RATIO_AT_TOP := 0.32
const FRAGILE_FADE_TIME := 0.45        # 踩到後淡出＋仍踩得住的時間，見上方 ⚠

## --- 爆炸平台（08-10 使用者拍板，關卡二起）---
## 踩上去之後 EXPLOSIVE_FUSE_TIME 秒內逐漸變亮，時間到炸出一個圓形爆炸區、平台消失。
## 爆炸碰到即死；無敵中免疫（同投擲物／黑洞那條規則）。
##
## ⚠⚠ EXPLOSIVE_RADIUS 是**保命條款不是美觀參數**：它必須明顯小於「玩家正常跳到上一塊
##   板之後離爆炸中心的距離」，否則按規矩跳走的玩家照樣被追著炸 ⇒ 踩到就是死，它就退化
##   成「更兇的碎裂平台」而不是新的東西。必須成立的關係：
##       EXPLOSIVE_RADIUS + PLAYER_SIZE.y * 0.5 < SPACING_MIN_AT_TOP
##   有稽核在守（`tests/audit_levels.gd` `_audit_explosive`）。
## ⚠ FUSE_TIME 2s 遠長於玩家在一塊板上的停留時間（正常 < 0.5s）。這是刻意的——它威脅的
##   不是「踩到」而是「久留」與「折返」，是節奏加壓器，不是第二種碎裂平台。
## ⚠ 引信期間平台仍踩得住、仍可再次起跳（同碎裂平台淡出期間的處理）：亮度就是剩餘時間，
##   玩家不需要另外背一個隱形的倒數。
## ⚠ 出現條件綁**關卡編號**而不是高度（08-10 二訂，使用者推翻原本「關卡不改變高度→難度
##   對應」那條）。門檻登記在 SECTION 8d 的 LEVEL_GATED，不要在生成器裡另外寫一次關卡判斷。
## ⚠ BLAST_TIME 是「爆炸區存在多久」＝致命窗長度，不只是特效時間。改它等於改難度。
const EXPLOSIVE_SIZE := Vector2(120.0, 18.0)
const EXPLOSIVE_RATIO_AT_0 := 0.04
const EXPLOSIVE_RATIO_AT_TOP := 0.16
const EXPLOSIVE_FUSE_TIME := 2.0
const EXPLOSIVE_RADIUS := 80.0
const EXPLOSIVE_BLAST_TIME := 0.35     # 爆炸區存在多久（＝致命窗），見上方 ⚠
const EXPLOSIVE_BLAST_RING_WIDTH := 4.0
const EXPLOSIVE_BLAST_CORE_RATIO := 0.45

const REACHABILITY_MARGIN := 0.7

const LAUNCHER_RATIO_AT_0 := 0.10
const LAUNCHER_RATIO_AT_TOP := 0.01
const LAUNCHER_VELOCITY := -1900.0     # 約 2.1x 基礎跳躍

# ===== SECTION 4b — 物資（長在平台上的收集品） =====
# 連動警告：金幣（PICKUP）與燃料補給（FUEL_PICKUP）互斥長在同一塊板上、機率各自獨立
# 計算，改其中一個不會偷走另一個的名額，但兩者總合仍受「有怪物的平台不長物資」這條
# 規則限制——MONSTER_CHANCE 提高，物資能長的平台數量會跟著變少。

## PICKUP_CHANCE：每塊平台長出金幣的機率。有怪物的平台不長——否則物資等於逼玩家去撞怪。
## ⚠ 這條線性內插就是「金幣掉落率隨高度提升」：越高越值得爬，是回訪動機的來源。
##   AT_TOP 從 0.26 拉到 0.40（使用者要求更明顯），等於頂端每 2.5 塊板就有一枚。
#
## --- 燃料補給（第二種資源）---
## 獨立於金幣的一條機率線，而且**只長在沒有金幣的平台上**：兩者都掛在平台正上方，
## 同一塊板放不下兩個；用獨立機率而不是「瓜分金幣的名額」，金幣掉落率才不會被稀釋。
## 高度門檻的理由：300m 以前燃料還很夠用，補給撿了也是浪費，等於白佔一個物資位——
## 這個理由跟下面的遞減方向不衝突，門檻仍在 300m。
## ⚠ 機率改成隨高度「略微遞減」（AT_START 0.20 → AT_TOP 0.13，約 -35%）：高處已經
##   夠難了，燃料補給不該越往上越大方——jetpack 不能變成後期的萬能解，稀釋掉干擾的壓力。
## FUEL_PICKUP_REFILL_METERS：撿到固定補這麼多公尺（使用者拍板改定值，不再吃上限比例）。
#
## --- 怪物（v7）：碰到即墜落；踩頭或鞭子擊退 ---
## ⚠ MONSTER_PATROL_RANGE 必須 <= 平台半寬（PLATFORM_SIZE.x / 2 = 60），怪物才會待在
##   自己的平台上方。設成 150 時怪物會飄到平台外變成半空中的障礙物，玩家踩不到只能
##   撞死——那正是 PILLARS「踩頭必須永遠可行」要防的運氣牆。冒煙測試的踩頭次數會歸零。
## ⚠⚠ MONSTER_PATROL_RANGE_SOLO（08-10 二訂）：BAND_SOLO_HEIGHT_M 以上用這個較小的值。
##   「待在自己的平台上方」不等於「玩家踩得到」——45 這個值讓怪物的掃過範圍（45+23=68）
##   比平台半寬（60）還大，平台上沒有任何一格是安全的。solo 區間又沒有備援板，
##   於是唯一的路被即死物封死。完整推導與稽核見 SECTION 4 的 PLATFORM_WIDTH_MULT_SOLO。
##   ⚠ 比照 MOVING_PATROL_RANGE_SOLO 的既有先例（solo 沒有備援 ⇒ 活動範圍要收），
##     不是新發明的機制。
## ⚠ MONSTER_PATROL_SPEED 08-10 從 70 降到 52（-25%，使用者拍板）。這是**調味不是解法**：
##   減速不改變上面那組幾何，怪物照樣走遍整塊板，只是走得慢。真正解封的是範圍與板寬。
##   刻意不照原提案砍到 -50%——那會讓怪物在 solo 區間近乎靜止靶，威脅感整個消失。
#
## --- 怪物死亡表現（v12，使用者拍板）---
## 死掉不是原地消失，是往遠離玩家的方向拋物線飛出去、邊轉邊淡出。
## ⚠ 死亡中的怪物 alive 已經是 false，**不參與任何判定**（不撞人、鞭子纏不到），
##   只是還留在畫面上演完。時間到由 WellGenerator.prune_below 一併回收。
## MONSTER_DEATH_GRAVITY 刻意小於玩家的 GRAVITY：屍體飛得比玩家「飄」，
## 才看得出那是特效不是另一個要閃的物件。
#
## MONSTER_KILL_WHIP_REFUND_CHANCE：踩頭／撞飛殺掉怪物時，這個機率讓鞭子次數 +1
## （回不到超過本局上限）。刻意**不含鞭中怪物**——鞭子殺怪再退鞭子會變成自我循環，
## 「鞭子是有限資源」這條前提會鬆掉。基礎次數與上限在 SECTION 5／8b。

const PICKUP_SIZE := Vector2(13.0, 13.0)
const PICKUP_CHANCE_AT_0 := 0.12
const PICKUP_CHANCE_AT_TOP := 0.40
## 物資中心離平台上緣多高，px。
## ⚠⚠ 08-10 四訂：使用者回報懸浮時仍卡進平台下方，改成「較大那顆視覺半高（fuel，
## FUEL_ART_SIZE.y/2 = 19.5）＋ 2px 安全距」而不是直接等於視覺半高——原本 13 剛好等於
## 金幣視覺半高（COIN_ART_SIZE.y/2 = 15，還差 2）沒算到 fuel 比金幣高（19.5），兩者共用
## 同一顆 PICKUP_HOVER，用金幣的數字去頂會讓 fuel 的畫面底邊沉進平台裡。金幣拿到這顆值後
## 反而多出 7px 餘裕（22-15），不是額外加寬——是修正共用常數時漏看兩種尺寸不同的舊錯。
const PICKUP_HOVER := 22.0
const PICKUP_GRAB_PAD := 4.0           # 收集判定額外容差 px

## --- 物資貼圖（08-10 使用者拍板匯入 coin.png／fuel.png，硬規則 4 例外五）---
## 慣例同 KAELA_ART_SIZE：art 只管畫面大小，判定仍讀 PICKUP_SIZE／FUEL_PICKUP_SIZE。
## ⚠⚠ 但這兩顆的**定義基準跟怪物那組不同**，抄過去會錯：怪物是「art 畫布 ＝ 判定 ×2」，
##   這裡是「art 的 **alpha 內容** ＝ 判定 ×2」。來源圖四周有大片透明留白（coin 原始畫布
##   60 裡只有 52 有東西），照畫布算會讓玩家實際看到的東西整整小一圈。
## ⚠⚠ 08-10 續（使用者拍板「COIN／FUEL 大小 -50%」）：`PICKUP_ART_SCALE` 把畫布縮小成
##   目前的畫面尺寸——來源 PNG 檔沒有變（還是 coin 60×60／fuel 原始畫布），縮放交給
##   `draw_texture_rect` 在畫的時候做（已開 Linear+Mipmaps，縮小不會有鋸齒）。判定
##   （PICKUP_SIZE／FUEL_PICKUP_SIZE）與 PICKUP_HOVER 都跟著等比減半，維持「內容 ＝
##   判定 ×2」與「懸停高度＝視覺半高」兩條既有關係，不是只縮視覺。
## ⚠ fuel 的來源比例（內容 37×39 ≈ 0.95）跟判定框比例（24×30 ＝ 0.8）對不上，兩軸不可能
##   同時對齊。依匯入 SOP 第 2 步鎖一軸——鎖**寬**不鎖高：鎖高會讓視覺比判定寬 9px
##   ⇒「看起來碰到了卻沒撿到」，鎖寬則是視覺比判定矮 ⇒「還沒碰到就撿到」。撿取物的
##   誤差要往對玩家有利的那一邊倒，這不是美觀取捨。
## ⚠ 這組有稽核在守（`tests/audit_levels.gd` `_audit_pickup_art`）：直接掃 PNG 的 alpha
##   算內容尺寸跟這兩顆比對，換圖或改 PICKUP_ART_SCALE 忘了同步會紅。
const PICKUP_ART_SCALE := 0.5          # 畫布 → 畫面尺寸的縮放，見上方 ⚠⚠
const COIN_ART_SIZE := Vector2(30.0, 30.0)
const FUEL_ART_SIZE := Vector2(39.0, 39.0)
## 沿貼圖 alpha 輪廓的白光描邊寬度（使用者指定 +2px）。共用 WellWorld._draw_sprite_outline，
## 跟 Kaela 無敵窗／蟲洞金光／Pameloe 充能圈是同一套畫法（⚠ 必須畫在本體之前）。
const PICKUP_OUTLINE_WIDTH := 2.0

const FUEL_PICKUP_START_HEIGHT_M := 300.0
const FUEL_PICKUP_CHANCE_AT_START := 0.20
const FUEL_PICKUP_CHANCE_AT_TOP := 0.13
const FUEL_PICKUP_REFILL_METERS := 7.0  # 定值：撿一次固定補這麼多公尺，不吃燃料上限
const FUEL_PICKUP_SIZE := Vector2(12.0, 15.0)

const MONSTER_START_HEIGHT_M := 110.0
const MONSTER_CHANCE_AT_START := 0.04
const MONSTER_CHANCE_AT_TOP := 0.14
const MONSTER_SIZE := Vector2(46.0, 42.0)
## 08-10 使用者拍板匯入 `chattini.png`（怪物美術，145×183）。同 KAELA_ART_SIZE 慣例：
## 目標＝ MONSTER_SIZE ×2＝(92,84)，鎖高 84 不動，寬依來源真實比例算 84×145/183≈66.6
## 取整 67，不雙軸硬拉。判定仍讀 MONSTER_SIZE，這顆只管畫面大小。
const MONSTER_ART_SIZE := Vector2(67.0, 84.0)
## 貼圖的「腳底」在畫布高度的哪個比例（＝ alpha bbox 底邊 ÷ 畫布高，量自縮圖後的檔案）。
## 08-10 續：原本畫成「art 中心對齊碰撞框中心」，因為 art 高(84) 是碰撞高(42) 的兩倍，
## 貼圖底邊會落在平台上緣**下方 21px**——平台才 18px 厚，整塊被怪物蓋住，看起來是浮在
## 平台裡而不是站在上面。改成同 KAELA_FEET_ANCHOR_FRAC 的錨點法：alpha 底邊貼齊碰撞框
## 底邊（＝平台上緣）。
## ⚠ 判定框大小（MONSTER_SIZE）刻意不動——這是視覺對位不是難度調整。副作用是「貼腳底
##   錨點」跟「判定框中心」不再是同一點，判定框會落在視覺下半部；08-10 真人試玩回報
##   踩頭像「踩進身體」，已用 MONSTER_HITBOX_CENTER_OFFSET_Y 把判定框的**位置**（不是
##   大小）拉回視覺中心，見該常數註解與 WellMonster.rect()。
const MONSTER_ART_FEET_FRAC := 83.0 / 84.0
## 踩頭手感修正（08-10 真人試玩回報）：判定框改成「中心對齊視覺（art）中心」，不再貼
## 平台上緣（＝視覺最下緣＝腳）。原本判定框底邊貼平台上緣，art 卻是判定的 2 倍高，
## 於是判定框整條落在視覺下半部——踩頭時腳會陷進牛背，看起來「踩進身體」而不是「踩在背上」。
## 這其實是回到 FEET_FRAC 上線**之前**的關係：那時 art 跟判定框同中心對齊，天生就是「判定框
## 在視覺正中」；FEET_FRAC 只移動了 art 的錨點去貼平台，沒有連帶移動判定框，這裡補上。
## 算式：判定框中心 y＝平台上緣－MONSTER_ART_SIZE.y×(MONSTER_ART_FEET_FRAC－0.5)，
## 直接從那兩顆常數推導（不是另存一個獨立數字），換 art size／feet frac 會自動跟著算，
## 不會有「改了一邊忘記改另一邊」的漂移風險（見常青認知第 6 條的教訓）。
const MONSTER_HITBOX_CENTER_OFFSET_Y := MONSTER_ART_SIZE.y * (MONSTER_ART_FEET_FRAC - 0.5)
const MONSTER_PATROL_SPEED := 52.0     # 08-10：70 → 52（-25%），見上方 ⚠
const MONSTER_PATROL_RANGE := 45.0     # 必須 <= 平台半寬（見上方 ⚠）
const MONSTER_PATROL_RANGE_SOLO := 18.0  # solo 區間專用，見上方 ⚠⚠
const STOMP_TOLERANCE := 18.0          # 踩頭判定：玩家下墜且底部在怪物上緣這範圍內
const STOMP_BOUNCE_VELOCITY := -780.0

## ⚠ MONSTER_DEATH_TIME 必須「短到讓淡出在畫面內演完」。1.1s 是錯的（v12 初版）：
##   拋物線 0.39s 到頂點、0.85s 就掉出畫面底，最後 40% 的淡出全在畫面外，
##   玩家看到的是「屍體半透明地掉出去」＝ 看起來根本沒淡出。
##   0.6s 剛好讓 alpha 歸零時屍體還在死亡點上方約 70px，整段淡出都看得見。
##   要改長就得同步調小 MONSTER_DEATH_VY／GRAVITY，否則同一個問題會回來。
const MONSTER_DEATH_TIME := 0.6        # 屍體演完飛出去要多久（秒），見上方 ⚠
const MONSTER_DEATH_VX := 260.0        # 水平初速（往遠離玩家的方向）
const MONSTER_DEATH_VY := 540.0        # 垂直初速（往上，拋物線的高度來源）
const MONSTER_DEATH_GRAVITY := 1400.0  # 見上方 ⚠：刻意小於玩家的 GRAVITY
const MONSTER_DEATH_SPIN := 7.0        # 自轉角速度 rad/s，正負隨飛出方向
const MONSTER_KILL_WHIP_REFUND_CHANCE := 0.20   # 踩頭／撞飛 → 鞭子 +1 的機率，見上方

## --- Pameloe（v16，使用者拍板）：懸浮射手 ---
## 第二種怪物。500m 以上開始出現，懸浮在半空定點（不巡邏、不跟隨平台），每
## PAMELOE_FIRE_INTERVAL 秒朝 Kaela 射一發子彈。子彈穿透平台、碰到井壁消失、碰到 Kaela 即死。
##
## ⚠ 牠是 WellMonster 的第二種 kind，不是獨立系統——踩頭／鞭子／無敵撞飛／死亡演出／
##   prune 回收全部沿用怪物那一整套判定，所以「踩頭永遠可行」這條保底條款自動成立。
##   ⚠ 這代表 MONSTER_DEATH_* 那組演出常數也管牠，改那邊會同時改到兩種怪物。
##
## ⚠⚠ PAMELOE_MIN_DIST_X 是可歸因性的保命條款，不是美觀參數。牠本體碰到即死，若能長在
##   母平台正上方，主鏈那條唯一的跳躍路線就會被一個「踩得到但很難踩」的即死物堵住——
##   那是運氣牆。拉開水平距離之後，牠是「玩家可以選擇繞開或主動去踩」的目標。
## ⚠ PAMELOE_HOVER_Y 要大於玩家高度，否則牠會貼在平台上緣，跳上去等於直接撞側面。
##
## ⚠ 充能閃爍（PAMELOE_CHARGE_TIME）不是裝飾：子彈在發射瞬間才鎖定 Kaela 當下位置、之後
##   直線飛不追蹤（跟投擲物預警同一條原則——會追蹤的預警等於假動作），玩家必須能預期
##   「哪一刻鎖定」，否則射擊時點不可讀，閃不閃得掉全看運氣。
## ⚠ 只有在畫面內的 pameloe 才開火（見 WellWorld._fire_pameloe_shots）：畫面外射進來的
##   子彈玩家看不到來源，是不可歸因的死法。
## ⚠ 這兩個機率的插值 t **從 PAMELOE_START_HEIGHT_M 起算、不是從 0m 起算**
##   （見 WellGenerator.pameloe_chance_at，那是它跟其他機率線唯一的差別）。理由：牠 500m
##   才登場，若照全井 0~1000m 算 t，登場那一刻的實際機率會是兩個常數的中點，`AT_START`
##   這個名字就是騙人的——調機率的人看著 0.08 卻拿到 0.16。
const PAMELOE_START_HEIGHT_M := 500.0
const PAMELOE_CHANCE_AT_START := 0.08   # 剛登場（500m）當下的機率。每塊主鏈平台骰一次，與怪物／物資名額互不相干
const PAMELOE_CHANCE_AT_TOP := 0.24     # 機率到頂的高度（1000m，見下方 PAMELOE_CHANCE_TOP_HEIGHT_M）
## 機率插值的分母基準。08-10（關卡制）前這條線讀的是 goal_meters，關卡二／三把目標
## 拉到 1500／2000m 之後會讓同一個高度算出不同機率——使用者明確要求「不同關卡不改變
## 基本高度對應的參數」，所以改綁固定的 DIFFICULTY_RAMP_HEIGHT_M（＝地形軸同一顆分母）。
## 值與舊的 SHORT preset 完全相同（1000m），所以關卡一的行為零變化。
const PAMELOE_CHANCE_TOP_HEIGHT_M := DIFFICULTY_RAMP_HEIGHT_M
const PAMELOE_SIZE := Vector2(44.0, 44.0)
## 08-10 使用者拍板匯入 `pemaloe1.png` / `pemaloe2.png`（來源檔名的拼法是 pemaloe，
## 程式這邊一律沿用既有的 PAMELOE 拼法，不為了對齊檔名去改一整套既有識別字）。
## 來源 200×200 正方形，目標＝ PAMELOE_SIZE ×2＝(88,88)，等比不變形。判定仍讀
## PAMELOE_SIZE，這顆只管畫面大小。
## ⚠ 牠是懸浮的，所以**用中心對齊、不用腳底錨點**（怪物／蟲洞那兩顆 FEET_FRAC 的前提是
##   「站在平台上」）。中心對齊也讓判定框留在視覺正中，維持原本「本體畫的就是 rect()」
##   那條可歸因性推理的精神。
const PAMELOE_ART_SIZE := Vector2(88.0, 88.0)
## 充能圈的描邊寬度。08-10 二訂：從「沿 art_rect 畫的長方形」改成**沿貼圖 alpha 輪廓**
## 描邊（同 Kaela 無敵狀態那套剪影偏移畫法，見 WellWorld._draw_sprite_outline）——
## 長方形會在牠周圍框出一個跟牠無關的方塊，輪廓描邊才讀得出「發光的是牠自己」。
## ⚠ 太細會被貼圖自身的抗鋸齒邊吃掉（同 KAELA_OUTLINE_WIDTH 的 ⚠）：這圈是「牠要開火了」
##   的唯一預告，看不見等於把 pameloe 變成不可歸因的死法，讀不到就往上加不要改回方框。
const PAMELOE_CHARGE_OUTLINE_WIDTH := 3.0
## 兩張立繪的抽取機率：pemaloe1 佔 80%、pemaloe2（雷射變體）佔 20%（08-10 二訂，使用者
## 從 10% 調到 20%——這顆現在**不只是表現**，它同時決定這隻要不要走雷射分支，見下方 ⚠⚠。
## ⚠ 只在生成當下骰一次並記在 WellMonster.art_variant，**不能每幀骰**——每幀骰等於
##   兩張圖以 60fps 互閃。
const PAMELOE_RARE_ART_CHANCE := 0.20
const PAMELOE_HOVER_Y := 86.0           # 懸浮高度：母平台上緣往上多少 px，見上方 ⚠
const PAMELOE_MIN_DIST_X := 190.0       # 與母平台中心的最小水平距離，見上方 ⚠⚠
const PAMELOE_FIRE_INTERVAL := 2.0      # 兩發之間隔多久（秒）
const PAMELOE_FIRE_FIRST_DELAY := 1.2   # 生成後第一發的延遲，避免玩家一進畫面就吃子彈
const PAMELOE_CHARGE_TIME := 0.45       # 發射前這段時間本體閃爍，見上方 ⚠
const PAMELOE_SHOT_SPEED := 470.0
const PAMELOE_SHOT_SIZE := Vector2(18.0, 18.0)      # 視覺
const PAMELOE_SHOT_HIT_SIZE := Vector2(14.0, 14.0)  # 判定，刻意小於視覺（同投擲物的理由）

## --- Pameloe 雷射變體（08-10 三訂，使用者拍板）---
## art_variant == 1（pemaloe2，見上方 PAMELOE_RARE_ART_CHANCE）不發子彈，改發一道持續
## PAMELOE_LASER_DURATION 秒的雷射。⚠ 沿用跟子彈同一條「發射瞬間鎖定方向、之後不追蹤」
##   的原則——鎖的是方向不是終點，雷射是從牠身上一路打到井壁那一整條線，不是打到玩家
##   當時的位置就停（見 WellMonster.laser_endpoint 的推導）。
## ⚠ 沿用同一顆 fire_timer／PAMELOE_FIRE_INTERVAL 計時器（子彈與雷射共用開火節奏），
##   PAMELOE_CHARGE_TIME 的充能閃爍對兩種分支都成立，不用另外寫一套預警。
## ⚠ PAMELOE_LASER_MAX_LEN 只在方向近乎垂直（水平分量趨近 0）時才會用到，正常情況雷射
##   會先打到井壁——這顆是防止極端角度下線段無限長的保險絲，不是常態射程。
const PAMELOE_LASER_DURATION := 1.0
const PAMELOE_LASER_WIDTH := 14.0           # 視覺粗細
const PAMELOE_LASER_HIT_WIDTH := 10.0       # 判定粗細，刻意小於視覺（同子彈的理由）
const PAMELOE_LASER_MAX_LEN := 2000.0       # 見上方 ⚠ 保險絲

## --- 漂浮（08-10，使用者要求「微幅緩慢的上下晃動，漂在半空中」）---
## ⚠⚠ 金幣／燃料與 Pameloe 的漂浮**實作在不同層**，這是刻意的不是不一致：
##   金幣／燃料是撿取物，只晃**視覺**、判定完全不動（做在 WellWorld 的繪製端）。最壞
##   情況是「看起來還沒碰到就撿到」，誤差往對玩家有利的方向倒，沒有人會抱怨。
##   Pameloe **碰到即死**，判定必須跟著晃，所以做在 `WellMonster.step()` 裡而不是繪製端——
##   致命物的視覺與判定分離就是不可歸因的死法，08-10 才剛在怪物判定框上踩過同一個坑
##   （常青認知第 8 條⑤：art 錨點與判定框錨點是兩件事，改一個不會自動連動另一個）。
##   ⚠ 所以 Pameloe 的振幅不能隨便調大：牠與母平台的垂直關係（PAMELOE_HOVER_Y）是
##     「跳上平台不會直接撞到牠側面」的來源，晃幅吃掉的正是那段餘裕。
## ⚠ 相位在生成當下用 seeded rng 骰一次就定死（同 PAMELOE_RARE_ART_CHANCE 的 ⚠⚠）：
##   不骰的話整排物資會同步上下擺、看起來像機械故障（同 _setup_vertical 隨機起始相位的
##   理由）；在繪製時骰則是每幀跳一次。
const PICKUP_FLOAT_AMP := 5.0          # 視覺上下晃幅（px，單邊）
const PICKUP_FLOAT_SPEED := 1.9        # rad/s
## 08-10 四訂：使用者回報「幅度不明顯」，×3（5→15）。consts_ok 仍守著
## `PAMELOE_HOVER_Y - PAMELOE_FLOAT_AMP > PLAYER_SIZE.y`（86-15=71 > 54），餘裕還在，
## 見 tests/audit_hazards.gd `_audit_pameloe` 的 ⚠。
const PAMELOE_FLOAT_AMP := 15.0        # ⚠ 判定跟著晃，見上方 ⚠⚠
const PAMELOE_FLOAT_SPEED := 1.4

## --- 墓碑（v12，使用者拍板）---
## 長在「歷史最高抵達高度」附近那塊平台上的紀念碑，碰到給 TOMB_COIN_REWARD 枚金幣。
## ⚠ 一局最多一個，位置由 SpikeSave.best_height_m 決定（見 WellGenerator._maybe_place_tomb）。
##   還沒有紀錄（第一次玩）或紀錄已經到終點附近就不放——放在終點線旁邊沒有意義。
## ⚠ 墓碑**壓過**同一塊板上原本的金幣／燃料（同一個掛點放不下兩個），不是共存也不是
##   換一塊板：換板會讓「墓碑就在你上次死的地方」這個唯一的意義失準。
const TOMB_SIZE := Vector2(34.0, 44.0)
const TOMB_COIN_REWARD := 10
const TOMB_END_MARGIN_M := 20.0        # 歷史紀錄離終點這麼近就不放

# ===== SECTION 4c — 蟲洞（PILLARS_2.md:399，前段通勤的加速手段之一） =====
# 規格：稀少、固定送 +40m（不是隨機高度，所以不是抽卡）、水平出口位置隨機。
#
# ⚠ 出口採「固定落在一塊既有平台上」（使用者拍板）。這比 PILLARS v4 提案的
#   「出口下方 2 秒內必有可救落點」更強也更省事：出口平台在生成時就綁定，
#   玩家出來就是站在板上，死因永遠不會是「我進了蟲洞，然後擲骰輸了」。
#   出口平台排除 FRAGILE 與終點板——出來就踩碎等於沒守住。
#
# ⚠ WORMHOLE_RESOLVE_MAX_STEPS 是出口綁定的補生上限（塊）。見
#   WellGenerator._force_resolve_pending_wormholes：出口在上方 40m（2000px），但串流
#   生成只領先相機 720px、prune 又會在相機爬過蟲洞約 754px 時把它回收——754 < 1280，
#   所以 v9 的蟲洞**一次都沒出現過**。修法是生出蟲洞後就地把生成鏈推到出口高度之上。
#   40m / 平均間距 ~120px ≈ 17 塊，加上保險絲掃描的半個畫面約 23 塊，設 60 是給極端
#   小間距留的餘裕，不是預期值。
#
# WORMHOLE_TRAVEL_TIME：碰到蟲洞後不是瞬間 teleport，改成鏡頭＋玩家一起緩動滑到出口
# （見 well_world._step_wormhole_travel）。太短像瞬移沒有意義，太長會變成「等它演完」。

const WORMHOLE_SIZE := Vector2(44.0, 44.0)
## 08-10 使用者拍板匯入 `the_sheep.png`（蟲洞美術，185×141）。同 KAELA_ART_SIZE 慣例：
## 目標＝ WORMHOLE_SIZE ×2＝(88,88)，鎖高 88 不動，寬依來源真實比例算 88×185/141≈115.5
## 取整 115。抓取判定仍讀 WORMHOLE_SIZE（wh.rect()），這顆只管畫面大小。
const WORMHOLE_ART_SIZE := Vector2(115.0, 88.0)
## 同 MONSTER_ART_FEET_FRAC 的理由與量法（the_sheep 縮圖後 alpha bbox 底邊 86 / 畫布 88）。
## ⚠ 蟲洞的基準線不是自己的判定框而是**母平台上緣**：判定框中心浮在平台上緣往上
##   WORMHOLE_HOVER(34px)，貼齊自己的框底仍會離平台 12px。基準線由 `pos.y + WORMHOLE_HOVER`
##   反推（offset 的定義保證這條關係恆成立，見 WellGenerator._maybe_spawn_wormhole）。
const WORMHOLE_ART_FEET_FRAC := 86.0 / 88.0
## 常駐外緣金光的兩層描邊。08-10 二訂：從「沿 art_rect 畫的長方形外框」改成**沿貼圖
## alpha 輪廓**描邊（同 Kaela 無敵狀態那套剪影偏移畫法，見 WellWorld._draw_sprite_outline）。
## 兩層的意思沿用原本「外暈 ＋ 亮心」：外層寬而淡、內層窄而亮，疊出柔光暈開的感覺。
## ⚠ OUTER 要明顯大於 INNER，兩顆設得太接近會退化成一條硬邊、失去「暈開」的意思。
## ⚠ 純視覺，不參與任何判定；缺貼圖的 fallback 沒有「貼圖外緣」可言，整段不畫。
const WORMHOLE_GLOW_OUTER_W := 5.0
const WORMHOLE_GLOW_OUTER_ALPHA := 0.30
const WORMHOLE_GLOW_INNER_W := 2.0
const WORMHOLE_GLOW_INNER_ALPHA := 0.80
const WORMHOLE_RISE_M := 40.0          # 固定送多少公尺（PILLARS 明文 +40m）
const WORMHOLE_MIN_HEIGHT_M := 80.0    # 稀少度三件套：起始高度
const WORMHOLE_MIN_SPACING_M := 120.0  # 彼此最小間隔
const WORMHOLE_CHANCE := 0.9           # 命中機率
const WORMHOLE_END_MARGIN_M := 60.0    # 終點下方這段不生蟲洞
const WORMHOLE_HOVER := 34.0           # 蟲洞中心離平台上緣多高，px
const WORMHOLE_GRAB_PAD := 2.0         # 收取判定額外容差 px
const WORMHOLE_SPIN_SPEED := 2.4       # 旋轉速度 rad/s，純表現
const WORMHOLE_RESOLVE_MAX_STEPS := 60 # 見上方 ⚠
const WORMHOLE_TRAVEL_TIME := 0.5      # 過場秒數，見上方說明

# ===== SECTION 4e — 特殊區段（主題區，08-10 使用者拍板） =====
# 隨機某一段 SEGMENT_LENGTH_M 的高度變成「主題區」：地形種類與掉落率被整段覆寫。
#
# ⚠⚠ 主題區是「換一種玩法」不是「單純變難」。移動平台區把怪物**與**金幣一起 ×2 是刻意的：
#   只加怪物是純粹的難度尖峰（玩家只會覺得倒楣），只加金幣是免費午餐，兩者一起才是
#   「要不要為了報酬進去冒險」的取捨——而玩家其實無法繞開，所以更該讓它同時給補償。
#
# ⚠⚠ 「整段只出移動平台」跟既有的死局防護**直接對打**：`_pick_kind` 有一條「solo 區間
#   不准連續兩塊會動的板」，在 BAND_SOLO_HEIGHT_M 以上會把區段內的移動平台全部改回
#   STATIC ⇒ 主題區在高處完全失效，而高處正是最需要變化的地方。
#   對策**不是把防護關掉**，而是讓區段強制帶備援跳板（`band_extra_min`）：有備援就不再是
#   「連兩次賭時機」，防護的前提消失，才可以合法豁免。⚠ 兩者是一組，拿掉 band_extra_min
#   而保留豁免＝直接把 690m 以上的主題區變成運氣牆。
#
# ⚠ 區段內的移動平台一律用 `MOVING_PATROL_RANGE_SOLO`（較小的巡邏半徑），不看高度：
#   整段都是會動的板時，可達性要可預測，備援跳板也才擺得下。
#
# ⚠ 區段之間至少隔 SEGMENT_MIN_GAP_M——連著兩個主題區就等於主題變成常態，也就不特別了。
# ⚠ 抽選走生成器的 seeded rng（同一顆 seed 要能重現同一座井，見 WellGenerator.active_seed）。
#
## SEGMENT_TABLE 的欄位：
##   id             — 識別字，出現在稽核輸出裡
##   force_kind     — 整段只生這種平台；空字串＝不覆寫種類。⚠ 用**字串**而不是
##                    WellPlatform.Kind 的值：SpikeConfig 是 autoload，反過來引用 class_name
##                    會做出雙向依賴。翻譯在 `WellGenerator._kind_from_name()`，
##                    翻不出來的名字有稽核會抓（拼錯字否則是靜默失效——整段變成沒有主題）
##   monster_mult   — 怪物機率倍率
##   pickup_mult    — 金幣機率倍率
##   band_extra_min — 這一段每個高度區間至少要有幾顆額外跳板（期望值下限），見上方 ⚠⚠
const SEGMENT_LENGTH_M := 40.0
const SEGMENT_START_HEIGHT_M := 150.0    # 這之前不出現：前段要先讓玩家建立「正常」的基準
const SEGMENT_CHANCE_PER_BAND := 0.02    # 每個高度區間骰一次「從這裡開一段主題區」
const SEGMENT_MIN_GAP_M := 120.0
const SEGMENT_TABLE := [
	{
		"id": "moving",
		"force_kind": "MOVING",
		"monster_mult": 2.0,
		"pickup_mult": 2.0,
		"band_extra_min": 1.0,
	},
]

# ===== SECTION 5 — 鞭子（P4：砍掉拋物線，改瞬間射線） =====
# 連動警告：鞭子命中拉扯中的無敵判定在 SECTION 6b（INVULN_GRACE）；鞭中怪物的合併
# 行為（擊退＋仍纏住拉過去）是使用者拍板的刻意偏離，見專案 CLAUDE.md 偏離表。
#
## WHIP_AIM_DURATION：瞄準窗長度，用「真實秒」計（不受慢動作影響）。
## WHIP_PULL_ACCEL：拉近是加速度，不是定速（使用者當面改的規格）。
## WHIP_EXIT_SPEED_KEEP：通過錨點還控制權時保留的速度比例。
## WHIP_PULL_TIMEOUT：保險絲，拉這麼久還沒過錨點就強制放手。
## WHIP_RAY_STEP：射線取樣步長，越小越準、越慢。

const WHIP_CHARGES := 5
const WHIP_AIM_DURATION := 3.0
const WHIP_AIM_TIME_SCALE := 0.25
const WHIP_RANGE := 900.0
const WHIP_PULL_ACCEL := 5600.0
const WHIP_PULL_MAX_SPEED := 1600.0
const WHIP_EXIT_SPEED_KEEP := 0.55
const WHIP_PULL_TIMEOUT := 1.4
const WHIP_RAY_STEP := 6.0
const WHIP_ROPE_FLASH := 0.25          # 射出後繩子殘影存留秒數，純表現

# ===== SECTION 6 — Jetpack =====
# ⚠ 刻意偏離 PILLARS_2.md:384（「燃料上限寫死為常數，不得進入任何升級表」）——使用者拍板。
#   偏離的補償手法（使用者指定）：初始上限砍半（110 → 55m），升滿才回到原本的 110m。
#   P4 真正在怕的是「後期可攜 300m 燃料」，這個做法沒有踩到那條線。
#
# JETPACK_FUEL_BURN_MULT：每上升 1px 實際扣掉這麼多 px 的燃料（見 well_world._step_jetpack）。
# ⚠ 「jetpack 太強勢」是用**消耗端**解的，不是砍初始上限（使用者拍板）。差別很實際：
#   砍初始量（55 → 38.5）會連帶把升滿上限拉低到 93.5m，等於天花板跟著降、升級表的
#   價值感被削掉一角；乘消耗倍率則是全程生效的效率削弱，55 → 110m 這條升級曲線
#   一個字都不用動，CLAUDE.md 那張刻意偏離表也維持成立。
#   1.5 的意思：標示 55m 的燃料實際只推得動約 37m。要再削就往上調，別回去動 BASE。

const JETPACK_FUEL_METERS_BASE := 55.0
const JETPACK_FUEL_BURN_MULT := 1.5
const JETPACK_SPOOL_TIME := 0.2              # 冷啟動：按住到真的噴出來要多久
## 08-10 使用者拍板：上一段噴射**結束後**，要間隔這麼久才能再噴。⚠ 跟 JETPACK_SPOOL_TIME
##   是兩件不同的事——冷啟動管「按下去到噴出來」的延遲，這顆管「噴完到能再按」的空窗，
##   兩者互不相干、可以同時存在（見 WellPlayer.jetpack_cooldown_timer／WellWorld._step_jetpack）。
const JETPACK_COOLDOWN := 0.6
const JETPACK_THRUST_SPEED_BASE := -1540.0   # 目標上升速度（升級會再乘倍率）
const JETPACK_ACCEL := 2600.0                # 趨近目標上升速度的加速度

# ===== SECTION 6b — 無敵窗（鞭子命中拉扯中 / jetpack 噴射中，＋結束後的餘韻） =====
# 連動警告：對應的是 SECTION 5（鞭子拉扯）與 SECTION 6（jetpack 噴射）兩段的接管動作。
#
# 理由：這兩個動作都會「把速度完全接管」，玩家在過程中失去閃避能力。
# 若還照常判傷害，死因會落在玩家控制不到的地方——那是系統在懲罰自己給的工具。
# 無敵不只是免傷：撞到怪物會直接把牠撞飛，撞到投擲物會把它打散。
# ⚠ 鞭子落空不給無敵（沒抓到目標 = 沒被接管速度），這是使用者明文的前提。

const INVULN_GRACE := 0.5              # 無敵窗長度，秒（鞭子拉扯／彈射板／蟲洞過場共用）
## 08-10 使用者拍板：jetpack 結束後的餘韻改窄成 0.2s，跟其他三個來源（鞭子／彈射板／
##   蟲洞過場，仍讀上面的 INVULN_GRACE）分開算——所以 WellPlayer 是兩顆獨立計時器，
##   不是共用一顆常數就能做完（見 WellPlayer.jetpack_invuln_timer／refresh_jetpack_invuln）。
const JETPACK_INVULN_GRACE := 0.2

# ===== SECTION 6c — 死亡演出（爆炸 ＋ 結算小卡推進，v17 使用者拍板） =====
# 死掉不再瞬間切到獨立的結算頁。流程是三段：
#   ① 死亡位置放一個小型爆炸（DEATH_FX_DURATION 秒），世界在這段期間**完全凍結**
#      ——不推進物理、不生成、不判定，只有爆炸自己在動
#   ② 爆炸演完才通知 main.gd 進結算，背景維持在最後那一幀的遊戲畫面（不再運算）
#   ③ 結算資訊裝進一張佔畫面 RESULT_CARD_RATIO 的小卡，由下往上推進來
#
# ⚠ 爆炸位置必須落在畫面內，否則等於沒演。摔落死（CAUSE_FALL）觸發的當下玩家已經在畫面
#   底緣之下了，所以那一種**改用畫面底緣往上 DEATH_FX_FALL_INSET 的位置**（見
#   WellWorld._die）。這不是美觀調整，是「玩家要看得到自己怎麼死的」。
# ⚠ DEATH_FX_DURATION 是玩家死後被迫等待的時間，寧短勿長。這段期間他已經知道自己死了，
#   多出來的每 0.1 秒都是純粹的焦躁。同理 RESULT_CARD_SLIDE_TIME。
# ⚠ 美術素材接進來時只換 WellWorld._draw_death_fx 的內容，這一段的時長常數維持不動——
#   時長是手感，換素材不該連帶改掉節奏。

const DEATH_FX_DURATION := 0.55        # 爆炸總時長（秒）＝世界凍結多久，見上方 ⚠
const DEATH_FX_FALL_INSET := 26.0      # 摔落死：爆炸畫在畫面底緣往上這麼多 px，見上方 ⚠
const DEATH_FX_RADIUS_START := 12.0    # 擴散環的起始半徑
const DEATH_FX_RADIUS_END := 104.0     # 擴散環的結束半徑
const DEATH_FX_RING_WIDTH := 7.0       # 擴散環線寬
const DEATH_FX_CORE_RATIO := 0.34      # 中心亮球相對於當下環半徑的比例
const DEATH_FX_SHARD_COUNT := 12       # 往外噴的碎片數
const DEATH_FX_SHARD_SIZE := 11.0      # 碎片邊長（正方形）
const DEATH_FX_SHARD_SPEED_MIN := 190.0
const DEATH_FX_SHARD_SPEED_MAX := 430.0
const DEATH_FX_SHARD_GRAVITY := 950.0

const RESULT_CARD_RATIO := 0.75        # 小卡佔畫面寬高的比例（使用者指定「約 3/4」）
const RESULT_CARD_SLIDE_TIME := 0.38   # 由下往上推進來的時間（秒），見上方 ⚠
const RESULT_CARD_DIM_ALPHA := 0.55    # 卡片後方遊戲畫面被壓暗的程度（0＝完全看得見）

# ===== SECTION 7 — Raora 干擾（v7 階梯式解鎖） =====
# 三個手段不齊發，隨登場後時間逐級解鎖。數值依 preset 切換，登場時間表在 SECTION 8。
# 連動警告：SECTION 8 的 interference_start／stage_*_offset 決定這裡「什麼時候開始
# 生效」；這裡的數值決定「生效之後多強」。兩段要一起看才知道某個時間點的實際壓力。

## --- 投擲物 ---
## 視覺是一支邊落邊轉的長方形，判定框卻是固定的小正方形（不隨旋轉變形）。
## ⚠ 兩者刻意不一致，而且判定**小於**視覺：旋轉矩形要精準判定得走 SAT，成本高；
##   更重要的是判定寧可鬆給玩家也不能緊——「看起來明明閃過了卻死」是不可歸因的死法，
##   正是 PILLARS 要防的東西。所以視覺 116x44 轉起來的包絡直徑約 124，判定只有 60。
## ⚠ v12 使用者拍板「投擲物大小 ×2」：**視覺與判定一起 ×2**（58x22→116x44、30→60）。
##   只放大視覺會讓那條「判定寬鬆」的承諾反過來變成欺騙（看起來砸中卻沒事，玩家會
##   以為判定是壞的）；只放大判定則是隱形的難度上調。兩者同乘，上面那條比例關係不變。
##   實際影響：判定寬 60 vs 玩家寬 38，閃避需求明顯變高——這是使用者要的加壓，不是 bug。
## PROJECTILE_AIM_SPREAD：落點在玩家 x 的 ±這個範圍內隨機。若整個井寬均勻亂灑，
## 1100px 的井裡幾乎打不到人，干擾會退化成純裝飾。
#
## --- 落點預警（使用者要求）---
## 丟出前先在畫面上方、預計落點的 x 位置閃一個紅色小三角形。
## ⚠ 落點在**預警產生的那一刻**就抽定了，之後不再追蹤玩家——不然預警變成假動作，
##   玩家躲了也沒用。PROJECTILE_WARN_TIME 這 2 秒就是玩家真正能用來反應的窗口。
## PROJECTILE_WARN_BLINK_PERIOD／URGENT_*：閃爍週期，快到剩 URGENT_AT 秒時改用
## URGENT_PERIOD 加倍閃，讓「快來了」有遞增感。
#
## --- 抽跳板 ---
## 只抽玩家上方第 STEAL_MIN_INDEX_ABOVE 塊起，抽前閃爍預告（三道緩衝之一）。
## ⚠ v12 補「削去的當下四散火花」（使用者拍板）。閃爍是**事前**預警（板還在），火花是
##   **事後**確認（板沒了）——兩者不重複：玩家在半空中時視線多半不在那塊板上，
##   沒有事後訊號的話下場就是「跳過去發現腳下是空的」，死因不可歸因。
#
## --- 衝擊波（v13 起改成間歇陣風）---
## ⚠⚠ v13 使用者拍板：**不再常駐**，改成「吹 SHOCKWAVE_BURST_TIME 秒 → 休息 → 再吹」。
##   這是設計性質的轉向，不是調參：常駐版的「力道終將超過玩家全速 ⇒ 必然墜落」這條線
##   **不再成立**，1000m 變回純技術挑戰（PILLARS 層級的差異，見 HANDOFF 未決清單）。
##   陣風之間玩家完全自由，所以壓力來源改成「陣風來的那 3 秒你在不在安全位置」。
##   力道仍隨時間遞增（SLOPE 不變），所以後期的每一陣都比前一陣狠。
## SHOCKWAVE_CYCLE：一輪的長度。前 BURST_TIME 秒吹風、其餘休息；預警佔休息段的最後
##   SHOCKWAVE_WARN_TIME 秒。⚠ CYCLE 必須 > BURST + WARN，否則預警會疊到上一陣風身上。
##
## 向左的力。它是獨立速度分量，玩家的操作抵銷不掉（well_world「衝擊波」那段）。
## 校準基準：力道等於玩家全速（鍵盤模式 KB_MOVE_MAX_SPEED=1400）時，全力往右也只能站在原地。
## ⚠ 壓力是漸進的，不是到臨界點才突然出現：117s 解鎖時力道 170 只有玩家全速的 12%
##   （輕微側風），一路漲到 100% 才是「推不動」。中間整段都是可玩的施壓期。
## ⚠ SHOCKWAVE_FORCE_SLOPE 斜率 10 → 7 的理由（使用者拍板）：干擾登場從 130s 拉回 67s
##   後，衝擊波在 67+50 = 117s 解鎖（見 SECTION 8 的 stage_shockwave_offset），若維持
##   斜率 10 則 (1400-170)/10 ≈ 123s → 約 240s 封頂，早於「1000m 局約 260~300s 完賽」的
##   推估，天花板會壓在終點**之前**、終點形同虛設。改 7 之後 (1400-170)/7 ≈ 176s →
##   約 293s 封頂，重新壓回終點前後：高手趕得到，一般玩家死在路上。
## ⚠ 未決（使用者註記，之後不排除做）：加一條 SHOCKWAVE_FORCE_MAX 上限，讓衝擊波退化成
##   「永遠推不倒、只是變慢」的側風。那會讓「必然墜落」不再成立、1000m 變成純技術挑戰，
##   是 PILLARS 層級的設計轉向，所以現在只先動斜率、不動性質。
## SHOCKWAVE_RESPONSE：玩家被衝擊波推到目標速度的趨近速率（px/s²）。決定「陣風感」
## 還是「牆感」。
#
## --- 側風預警（v12，使用者拍板：三種干擾都要有對應的預警）---
## 衝擊波解鎖**前** SHOCKWAVE_WARN_TIME 秒，畫面右緣出現綠色半透明長條並閃爍。
## ⚠ 這是三種干擾裡唯一的「一次性事前公告」：投擲物每一發都預警、抽跳板每一次都預警，
##   但衝擊波是解鎖後常駐、力道連續遞增，沒有「下一次」可以逐次預警。所以它只在
##   從無到有的那個時點警告一次，之後靠玩家自己感覺得到被往左推。
## ⚠ 畫在**右**緣：風從右邊來、把人往左推。畫錯邊等於指錯逃生方向。
## SHOCKWAVE_WARN_ALPHA 壓得低（半透明）是因為它貼在畫面邊緣、整整兩秒都在，
## 不透明的話會蓋掉右側那一整條的平台與投擲物。

## 長寬比對齊 cucumber.png（干擾物 1 素材，305×133＝2.2932）：鎖長軸 116（v12 ×2
## 定案值不動），短軸依來源圖真實比例重算 116×133/305≈50.6 取整 51（08-09 使用者拍板，
## 同 KAELA_ART_SIZE 的量測慣例——鎖一軸、另一軸按來源比例算，不要雙軸硬拉變形）。
const PROJECTILE_DRAW_SIZE := Vector2(116.0, 51.0)   # v12 ×2 →08-09 依 cucumber.png 比例修正 y
## 08-09 使用者拍板：判定框跟視覺形狀差太多（60×60 正方形 vs 116×51 細長矩形），改成
## 跟 PROJECTILE_DRAW_SIZE 同比例的矩形——面積鎖定跟舊判定一樣 3600（90×40），只改「形狀」
## 不改「寬鬆度」：面積不變＝沒有偷偷調難度，純粹讓判定形狀貼近旋轉包絡真正的樣子。
## ⚠ 判定本身依然不隨旋轉變形（見下方 interference.gd 的 Projectile.rect() 註解）。
const PROJECTILE_HIT_SIZE := Vector2(90.0, 40.0)     # 90×40=3600，同舊 60×60 面積，比例對齊視覺
const PROJECTILE_SPEED := 640.0
const PROJECTILE_SPIN_MIN := 3.0       # 自轉角速度範圍 rad/s，正負各半
const PROJECTILE_SPIN_MAX := 7.0
const PROJECTILE_INTERVAL_DECAY := 0.5 # 每個衰減週期減這麼多秒
const PROJECTILE_AIM_SPREAD := 220.0

const PROJECTILE_WARN_TIME := 1.0
const PROJECTILE_WARN_SIZE := Vector2(30.0, 24.0)     # 三角形寬高 px
const PROJECTILE_WARN_MARGIN := 18.0                  # 三角形離畫面上緣多遠 px
const PROJECTILE_WARN_BLINK_PERIOD := 0.22
const PROJECTILE_WARN_URGENT_AT := 0.7
const PROJECTILE_WARN_URGENT_PERIOD := 0.09

const STEAL_MIN_INDEX_ABOVE := 2
const STEAL_WARN_TIME := 1.0
const STEAL_WARN_BLINK_PERIOD := 0.1   # < 這個間隔切一次顏色

## 削去平台的火花（也給未來其他「東西沒了」的事件共用）
const SPARK_COUNT := 18                # 一次噴幾顆
const SPARK_LIFE := 0.45               # 每顆存活秒數（alpha 同步線性淡出）
const SPARK_SPEED_MIN := 140.0
const SPARK_SPEED_MAX := 420.0
const SPARK_GRAVITY := 1100.0
const SPARK_SIZE := Vector2(5.0, 5.0)

const SHOCKWAVE_FORCE_START := 170.0
const SHOCKWAVE_FORCE_SLOPE := 7.0     # 力道每秒增加多少，px/s per s
const SHOCKWAVE_RESPONSE := 400.0

const SHOCKWAVE_BURST_TIME := 1.0      # 一陣風吹多久，見上方 ⚠⚠
const SHOCKWAVE_CYCLE := 10.0          # 一輪多長（吹 1s ＋ 休 9s），見上方 ⚠

const SHOCKWAVE_WARN_TIME := 1.0       # 每一陣風的前這麼多秒開始警告
const SHOCKWAVE_WARN_WIDTH := 46.0     # 長條寬度 px（貼畫面右緣、佔滿整個畫面高度）
const SHOCKWAVE_WARN_ALPHA := 0.34     # 半透明，見上方 ⚠
const SHOCKWAVE_WARN_BLINK_PERIOD := 0.18
## 陣風進行中畫面右緣的常駐色帶（比預警更淡）：告訴玩家「現在正在吹」。
## 少了它，玩家分不出「被推」是陣風還是自己操作失誤——不可歸因的挫折。
const SHOCKWAVE_ACTIVE_ALPHA := 0.18

## --- 第四種干擾：黑洞（doom，v13 使用者拍板）---
## 在玩家上方隨機一塊平台上開一個黑洞：靠近有向心吸力、碰到直接死亡。
## ⚠ 吸力是**獨立速度分量**（跟衝擊波同一個設計），玩家的左右操作抵銷不掉，
##   但最大吸力 520 遠低於玩家全速 1400 ⇒ 逃得掉，只是要付出時間與高度。
##   若哪天調到 >= KB_MOVE_MAX_SPEED，它就變成「進了範圍必死」的運氣牆，不要那樣做。
## ⚠ 無敵狀態（鞭子拉扯／jetpack／彈射起飛）碰到＝**消掉黑洞**，跟怪物、投擲物同一條規則：
##   那三段速度被系統接管、玩家閃不掉，此時判死等於懲罰玩家用工具。
## DOOM_RADIUS：事件視界，玩家中心進到這個半徑內就死。判定用圓不用矩形——它畫成圓，
##   用矩形判定會出現「看起來在圓外卻死」的角落死法。
## DOOM_PULL_RADIUS：吸力範圍（畫成一圈暗環，讓危險區看得見）。吸力隨距離線性遞減。
## DOOM_LIFETIME：黑洞會自己塌縮。不設會讓上方累積一堆永久死區，愈爬愈不可能。
## DOOM_MIN_INDEX_ABOVE：只挑玩家上方第 N 塊起的平台（同抽跳板的緩衝 ②）——
##   開在腳下那塊等於無預警處決。
const DOOM_RADIUS := 51.0              # v15：事件視界 ×1.5（使用者拍板），原 34.0
const DOOM_PULL_RADIUS := 260.0
const DOOM_PULL_MAX_SPEED := 520.0     # 貼到事件視界時的吸力速度，見上方 ⚠
const DOOM_PULL_RESPONSE := 900.0      # 趨近吸力速度的加速度 px/s²（同 SHOCKWAVE_RESPONSE 的角色）
const DOOM_LIFETIME := 5.0
const DOOM_MIN_INDEX_ABOVE := 2
const DOOM_HOVER := 40.0               # 黑洞中心離平台上緣多高 px
const DOOM_SPIN_SPEED := 1.9           # 純表現

const DOOM_WARN_TIME := 1.0            # 出現前這麼多秒開始閃紫圈
const DOOM_WARN_BLINK_PERIOD := 0.2
const DOOM_WARN_URGENT_AT := 0.6       # 剩這麼少秒時改用下面的快閃週期
const DOOM_WARN_URGENT_PERIOD := 0.08
const DOOM_WARN_ALPHA := 0.42

# ===== SECTION 8 — 局長 preset =====
# 連動警告：stage_*_offset 決定各干擾手段「登場後 +N 秒」解鎖，跟 SECTION 7 的強度數值
# 要一起看才知道某個時間點實際多硬。
#
# ⚠⚠ v13 使用者拍板的解鎖時程：**67 / 87 / 107 / 127s，每階間隔 20 秒**
#     ＝ interference_start 67 ＋ offset 0 / 20 / 40 / 60。四種手段是**累加常駐**
#     （stage() 用 >=），127s 之後四種全部同時在跑各自的計時器。
#     改 interference_start 只平移整組；要改「間隔」就改這四個 offset。
#
# ⚠ 衝擊波在 v13 改成間歇陣風（SECTION 7），所以舊註解說的「約 240s 完全推不動 ⇒
#   終點形同虛設」已經不成立——陣風之間玩家是自由的，力道再大也只影響那 3 秒。
#
# SHORT：spike 迭代用（終點 1000m）
# SPEC ：對得上 PILLARS_2.md v8 的數字

enum Preset { SHORT, SPEC }
const ACTIVE_PRESET := Preset.SHORT

var goal_meters: float
var interference_start: float          # 干擾登場秒數
var stage_projectile_offset: float     # 登場後 +N 秒解鎖投擲物
var stage_steal_offset: float
var stage_shockwave_offset: float
var stage_doom_offset: float           # v13：第四階，黑洞
var projectile_interval_start: float
var projectile_interval_min: float
var projectile_decay_every: float      # 每 N 秒把間隔減一次
var steal_interval_start: float
var steal_interval_min: float
var steal_decay_every: float
var doom_interval_start: float
var doom_interval_min: float
var doom_decay_every: float

func _ready() -> void:
	match ACTIVE_PRESET:
		Preset.SHORT:
			goal_meters = 1000.0
			interference_start = 67.0
			stage_projectile_offset = 0.0      # 67s
			stage_steal_offset = 20.0          # 87s
			stage_shockwave_offset = 40.0      # 107s
			stage_doom_offset = 60.0           # 127s
			projectile_interval_start = 4.0
			projectile_interval_min = 1.5
			projectile_decay_every = 20.0
			steal_interval_start = 10.0
			steal_interval_min = 5.0
			steal_decay_every = 25.0
			doom_interval_start = 14.0
			doom_interval_min = 8.0
			doom_decay_every = 30.0
		Preset.SPEC:
			goal_meters = 600.0
			interference_start = 67.0
			stage_projectile_offset = 0.0
			stage_steal_offset = 20.0
			stage_shockwave_offset = 45.0
			stage_doom_offset = 70.0
			projectile_interval_start = 6.0
			projectile_interval_min = 2.0
			projectile_decay_every = 30.0
			steal_interval_start = 15.0
			steal_interval_min = 8.0
			steal_decay_every = 30.0
			doom_interval_start = 18.0
			doom_interval_min = 10.0
			doom_decay_every = 35.0
	# preset 給的 goal_meters 只是「還沒選關之前」的初值，開局前一定會被
	# apply_level() 覆蓋（見 SECTION 8d）。⚠ 想改終點高度請改 LEVEL_GOALS，改這裡沒用。
	apply_level(0)


# ===== SECTION 8d — 關卡（08-10 使用者拍板）=====
# 三個關卡＝**同一套機制，只是在不同高度結束**：目標 1000／1500／2000m，抵達即成功結算、
# 解鎖下一關、播該關的劇情。已解鎖的關可以自由回頭重玩。
#
# ⚠⚠ 「高度 → 難度」的對應**預設不隨關卡改變**，但這條 08-10 二訂為**白名單制**
#    （使用者推翻原本的全面禁止：「不同關卡之間應該還是要有些差距，不然會感覺是重複
#    挑戰完全相同的東西」）。現在的規則是：
#      • 預設仍然禁止——所有隨高度變化的軸一律綁 DIFFICULTY_RAMP_HEIGHT_M /
#        PRESSURE_STEP_HEIGHT_M 這兩顆固定分母，**不准綁 goal_meters**（綁了的話同一個
#        800m 在關卡一與關卡三會是兩種難度，那是靜默的漂移，不是設計）。
#      • 要讓某個東西「第 N 關才出現」，必須**登記進 LEVEL_GATED**。沒登記的一律視為違例。
#    ⚠ 白名單存在的意義是把「刻意的關卡差異」跟「某人為了方便把分母換成 goal_meters」
#      區分開來——後者在單一關卡下測起來完全正常，只有跨關比較才看得出來。稽核
#      （`tests/audit_levels.gd` 難度不變性）現在驗的是「白名單以外的軸不得隨關卡變」，
#      不是「全部都不得變」。⚠⚠ 加新的關卡差異時**兩邊都要動**：登記進 LEVEL_GATED，
#      而且如果它會影響難度取樣值，還要把對應那一項從不變性取樣裡排除，否則稽核會紅。
#    （08-10 修掉的唯一一條違例是 pameloe_chance_at，見 PAMELOE_CHANCE_TOP_HEIGHT_M；
#     goal_meters 現在只剩「哪裡結束」與兩個「終點附近不生成」的邊界 margin 在讀。）
#
# ⚠ 關卡 × 極限 × 無盡是**三個互相獨立的維度**（使用者拍板）：極限只動等待時間
#   （eff_* 那組），無盡只動「要不要在 goal_meters 停局」（eff_has_goal），關卡只動
#   goal_meters 本身。三者可任意組合，沒有任何互斥規則。
#
# ⚠ 各關的差異一律登記在下面的 LEVEL_GATED，**不要散到生成器裡各自判斷關卡編號**——
#   散出去之後「第幾關才有什麼」就沒有一個能一眼看完的地方，稽核也無從驗起。

const LEVEL_COUNT := 3

## 允許「隨關卡編號改變」的白名單（08-10 二訂，見上方 ⚠⚠）。
##   key       — 功能識別字，程式用 level_gate_ok(key, idx) 問
##   name      — 給稽核／錯誤訊息用的顯示名
##   min_level — 從第幾關開始有（0-based，跟 selected_level 同一套編號）
## ⚠ 這張表就是「關卡之間到底差在哪」的唯一答案。新增關卡差異＝在這裡加一列，
##   不是在生成器裡多寫一個 if。
const LEVEL_GATED := {
	"explosive_platform": {"name": "爆炸平台", "min_level": 1},
}
## 各關的目標高度（m）。idx 是 0-based，UI 顯示才 +1。
const LEVEL_GOALS: Array[float] = [1000.0, 1500.0, 2000.0]
const LEVEL_NAMES: Array[String] = ["關卡一", "關卡二", "關卡三"]
## 通關後的劇情佔位（使用者拍板：這一輪只放可辨識的佔位，素材到位再換）。
## ⚠ 整句模板，不要拼接組句（i18n 條款，見 ../HANDOFF.md「未動工但已有定論」第 5 條）。
const LEVEL_STORY_PLACEHOLDER: Array[String] = [
	"〈關卡一 過場動畫與劇情：待補〉",
	"〈關卡二 過場動畫與劇情：待補〉",
	"〈關卡三 過場動畫與劇情：待補〉",
]

func level_goal(idx: int) -> float:
	return LEVEL_GOALS[clampi(idx, 0, LEVEL_COUNT - 1)]

func level_name(idx: int) -> String:
	return LEVEL_NAMES[clampi(idx, 0, LEVEL_COUNT - 1)]

func level_story(idx: int) -> String:
	return LEVEL_STORY_PLACEHOLDER[clampi(idx, 0, LEVEL_COUNT - 1)]

## 這一關有沒有解鎖某個關卡限定的東西。**唯一的問法**，不要在別處自己比 min_level。
## ⚠ 沒登記在 LEVEL_GATED 的 key 一律回 false（而不是 true）：拼錯字時要壞在「東西沒出現」
##   這種一眼看得到的方向，不是「全部關卡都出現」那種要跨關比對才發現的方向。
## ⚠ 呼叫端傳的是**這一局的關卡 idx**，不是 SpikeSave.selected_level——生成器不讀存檔
##   （狀態一律從 setup() 灌進去），稽核才控制得住自己的前提。
func level_gate_ok(feature: String, level_idx: int) -> bool:
	if not LEVEL_GATED.has(feature):
		return false
	return level_idx >= int(LEVEL_GATED[feature]["min_level"])

## goal_meters 的**唯一寫入點**。呼叫端只有 SpikeSave（讀完檔／換關卡時）與上面 preset
## 的收尾。⚠ 不要在別的地方直接指派 goal_meters——那會讓「現在是第幾關」與「終點在哪」
## 對不上，而且不會有任何錯誤訊息。
func apply_level(idx: int) -> void:
	goal_meters = level_goal(idx)


# ===== SECTION 8b — 金幣與永久升級（跨局累計，存檔在 SpikeSave） =====
# 連動警告：UPGRADE_TABLE 是「升級效果」的家，但「基礎值」在別段——jump 對應
# SECTION 3 跳躍、fuel 對應 SECTION 6 的 JETPACK_FUEL_METERS_BASE、whip 對應
# SECTION 5 的 WHIP_CHARGES、launcher 對應 SECTION 4 的 LAUNCHER_VELOCITY、
# ledge 對應 SECTION 3b。改基礎值時記得檢查升級表的 effect 文案要不要同步改。
#
# PILLARS_2.md:413「永久升級 = 加速，不是必需」：零升級必須仍可通關，升級只把
# 「幾乎完美」降成「穩健」。所以每一項都是**有限清單**（固定級數上限），不是成長曲線。
#
# ⚠⚠ 生成器永遠用「基礎跳躍高度」當設計單位（PILLARS_2.md:427 明文驗算要求）。
#    也就是 MAX_JUMP_HEIGHT / hard_spacing_cap() 一律讀 SpikeConfig 的基礎值，
#    **絕對不要**改成讀升級後的值——否則玩家跳得越高、井的間距跟著拉越開，
#    升級效果被生成器自己吃光，升級表會變成純粹的裝飾。
#
## 升級表 key 同時是存檔欄位名，改名會讓舊存檔的該項歸零（可接受，spike 而已）。
##   max        — 級數上限（有限清單，非曲線）
##   step       — 每級的效果增量（語意見各項 effect 說明）
##   cost_base  — 第 1 級價格；第 n 級價格 = cost_base + cost_step * (n-1)

const COIN_PER_PICKUP := 1             # 一個物資 = 幾枚金幣

const UPGRADE_TABLE := {
	"jump": {
		"name": "跳躍高度",
		"effect": "跳躍高度 +5%／級（初速按 √ 換算，維持高度是線性成長）",
		"max": 6, "step": 0.05, "cost_base": 40, "cost_step": 30,
	},
	"fuel": {
		"name": "噴射燃料上限",
		"effect": "燃料上限 +11m／級（55m 起，升滿 110m）",
		"max": 5, "step": 11.0, "cost_base": 35, "cost_step": 25,
	},
	"whip": {
		"name": "鞭子次數",
		"effect": "鞭子 +1 次／級（5 起，升滿 8 次 — 使用者拍板新規格，非 PILLARS 硬上限）",
		"max": 3, "step": 1.0, "cost_base": 120, "cost_step": 120,
	},
	"launcher": {
		"name": "彈射板高度",
		"effect": "踩到彈射板的初速 +6%／級",
		"max": 5, "step": 0.06, "cost_base": 50, "cost_step": 30,
	},
	# 特殊裝備：有／無兩態（max = 1），不是成長曲線。價格刻意高——它改的是
	# 「差一點」的容錯率，買到之後每一局都在生效，比純數值升級更有感。
	"ledge": {
		"name": "攀爬手套",
		"effect": "跳躍頂點差一點時自動攀上平台（每次離地限一次）",
		"max": 1, "step": 1.0, "cost_base": 1, "cost_step": 0,
	},
}
const UPGRADE_ORDER := ["jump", "fuel", "whip", "launcher", "ledge"]
## 商店卡片的色塊在 SECTION 9（UPGRADE_ICON_COLOR）——const 之間不做前向引用，
## 顏色常數得先定義完才引用得到。

# ===== SECTION 8c — 成就（跨局累計，存檔在 SpikeSave） =====
# 連動警告：`stat` 欄位名同時是 SpikeSave.stats 的存檔 key，改名等於把該項進度歸零。
# `need` 是門檻數字（可調），判定式本身住 SpikeSave._is_unlocked()——那是邏輯不是數值。
#
# 三態，不是兩態：0 = 未解鎖、1 = 已解鎖**未領獎**、2 = 已領獎。
# ⚠ 「解鎖」與「拿到金幣」刻意分開（使用者拍板）：解鎖時只放橫幅，玩家要自己去成就頁
#   點卡片才入帳。所以入帳只能有 SpikeSave.claim_achievement() 這一個出口，
#   check_achievements() 一毛錢都不准給——兩處都能給錢就會有重複領獎的漏洞。
#
# ⚠ 條件文案照使用者的 TSV 原文，保留他的設計語彙（小黃瓜＝投擲物、Chattini＝怪物、
#   披薩＝彈射板、義大利麵＝碎裂平台）。這是風味不是筆誤，不要「順手」改成白話。
#
## kind — 判定的取值來源，決定 SpikeSave 怎麼比對：
##   "run"   本局結束時才成立的條件（登頂類），看 ctx 的當局數字
##   "live"  本局進行中就能成立（speed run），看 ctx 的當局數字
##   "stat"  跨局累計計數，看 stats[stat] >= need
## glyph — 卡片與橫幅上那個字（placeholder 美術：色塊 ＋ 一個字，不引入資源檔）
## reward — 這個 id 領獎給多少金幣。沒寫就吃 ACHIEVEMENT_COIN_REWARD 這個預設值
##   （SpikeSave.claim_achievement() 讀法：row.get("reward", ACHIEVEMENT_COIN_REWARD)）。
#
# ⚠⚠ v15（使用者拍板）：披薩／義大利麵／Chattini／遊玩次數 四個 stat 成就拆成 I/II/III
#   三階，門檻 I=原數字÷2、III=原數字×2（原數字當 II），獎勵 20/50/100。
#   三階**共用同一張卡片位置**——ACHIEVEMENT_TABLE 底下還是三個獨立 id（判定、存檔、
#   領獎互不相干），但成就頁 grid 版位数一律照 ACHIEVEMENT_SLOTS（9 個），不是這裡的
#   17 個 leaf id。哪個 slot 現在該顯示哪個 id 由 SpikeSave.current_tier_id() 決定：
#   依序找第一個還沒領過的，三個都領完就停在最高階。這樣卡片數量、grid 版面完全不變，
#   不會撞上「9 張已經逼近可用區上限」那個舊版面上限（見 spike_ui.gd ACH_CARD_SIZE 附近）。

const ACHIEVEMENT_COIN_REWARD := 50       # 沒寫 reward 的成就都吃這個預設值

const ACHIEVEMENT_TABLE := {
	"soul": {
		"name": "魂系玩家", "cond": "不使用鞭子、jetpack登頂",
		"kind": "run", "glyph": "魂",
	},
	"chattini_model": {
		"name": "Chattini的典範", "cond": "不使用jetpack登頂",
		"kind": "run", "glyph": "範",
	},
	"spider2": {
		"name": "蜘蛛人第二代", "cond": "不使用鞭子登頂",
		"kind": "run", "glyph": "蛛",
	},
	"big_cat": {
		"name": "BIG CAT", "cond": "被小黃瓜砸中10次而死",
		"kind": "stat", "stat": "proj_deaths", "need": 10, "glyph": "貓",
	},
	"non_approval_1": {
		"name": "non approval I", "cond": "踩碎義大利麵50次",
		"kind": "stat", "stat": "fragile_broken", "need": 50, "glyph": "麵", "reward": 20,
	},
	"non_approval_2": {
		"name": "non approval II", "cond": "踩碎義大利麵100次",
		"kind": "stat", "stat": "fragile_broken", "need": 100, "glyph": "麵", "reward": 50,
	},
	"non_approval_3": {
		"name": "non approval III", "cond": "踩碎義大利麵200次",
		"kind": "stat", "stat": "fragile_broken", "need": 200, "glyph": "麵", "reward": 100,
	},
	"speed_run": {
		"name": "speed run", "cond": "2分鐘內抵達500m",
		"kind": "live", "glyph": "速",
	},
	"kaela_1": {
		"name": "kaela I", "cond": "遊玩35次遊戲",
		"kind": "stat", "stat": "plays", "need": 35, "glyph": "玩", "reward": 20,
	},
	"kaela_2": {
		"name": "kaela II", "cond": "遊玩69次遊戲",
		"kind": "stat", "stat": "plays", "need": 69, "glyph": "玩", "reward": 50,
	},
	"kaela_3": {
		"name": "kaela III", "cond": "遊玩138次遊戲",
		"kind": "stat", "stat": "plays", "need": 138, "glyph": "玩", "reward": 100,
	},
	"bad_chattini_1": {
		"name": "BAD chattini I", "cond": "打倒50隻Chattini",
		"kind": "stat", "stat": "monsters_killed", "need": 50, "glyph": "獸", "reward": 20,
	},
	"bad_chattini_2": {
		"name": "BAD chattini II", "cond": "打倒100隻Chattini",
		"kind": "stat", "stat": "monsters_killed", "need": 100, "glyph": "獸", "reward": 50,
	},
	"bad_chattini_3": {
		"name": "BAD chattini III", "cond": "打倒200隻Chattini",
		"kind": "stat", "stat": "monsters_killed", "need": 200, "glyph": "獸", "reward": 100,
	},
	"noooo_1": {
		"name": "nooooooo I", "cond": "踩披薩50次",
		"kind": "stat", "stat": "launchers_used", "need": 50, "glyph": "餅", "reward": 20,
	},
	"noooo_2": {
		"name": "nooooooo II", "cond": "踩披薩100次",
		"kind": "stat", "stat": "launchers_used", "need": 100, "glyph": "餅", "reward": 50,
	},
	"noooo_3": {
		"name": "nooooooo III", "cond": "踩披薩200次",
		"kind": "stat", "stat": "launchers_used", "need": 200, "glyph": "餅", "reward": 100,
	},
}

## 判定／存檔／領獎用的完整清單——17 個 leaf id，三階分開算，check_achievements()
## 與 SpikeSave.has_claimable_achievement() 都走這份，不是下面給 UI 版位用的那份。
const ACHIEVEMENT_ORDER := [
	"soul", "chattini_model", "spider2", "big_cat",
	"non_approval_1", "non_approval_2", "non_approval_3",
	"speed_run",
	"kaela_1", "kaela_2", "kaela_3",
	"bad_chattini_1", "bad_chattini_2", "bad_chattini_3",
	"noooo_1", "noooo_2", "noooo_3",
]

## 成就頁 grid 的 9 個卡片版位（UI 專用）。階梯成就填 slot key（例如 "noooo"），
## 由 SpikeSave.current_tier_id() 換成該顯示的 leaf id；非階梯成就 slot key 就是自己的 id。
const ACHIEVEMENT_SLOTS := [
	"soul", "chattini_model", "spider2", "big_cat", "non_approval",
	"speed_run", "kaela", "bad_chattini", "noooo",
]

## slot key → 依序三個 leaf id（低到高）。ACHIEVEMENT_ICON_COLOR 沿用 slot key 當索引，
## 不必為三階分別加顏色。
const ACHIEVEMENT_TIERS := {
	"non_approval": ["non_approval_1", "non_approval_2", "non_approval_3"],
	"kaela": ["kaela_1", "kaela_2", "kaela_3"],
	"bad_chattini": ["bad_chattini_1", "bad_chattini_2", "bad_chattini_3"],
	"noooo": ["noooo_1", "noooo_2", "noooo_3"],
}

## speed run 的兩個門檻（「run」與「stat」類不需要，它們的門檻寫在表裡／看 cleared）
const SPEEDRUN_HEIGHT_M := 500.0
const SPEEDRUN_TIME := 120.0

## stats 的完整欄位清單。⚠ 這裡是唯一的家：SpikeSave 用它初始化與讀存檔，
## 漏一個欄位那項進度就永遠是 0（而且不會報錯，只是成就永遠解不開）。
const STAT_KEYS := [
	"plays",             # 開過幾局（reset() 時 +1）
	"proj_deaths",       # 被投擲物砸死幾次
	"fragile_broken",    # 踩碎幾塊碎裂平台（同一塊只算第一次踩）
	"launchers_used",    # 踩到幾次彈射板（同一塊可重複算）
	"monsters_killed",   # 打倒幾隻怪物（踩頭＋撞飛＋鞭中，三種都算）
]

# ===== SECTION 9 — 顏色（placeholder，不是美術定調） =====
# 純表現／零耦合：這裡沒有任何常數會被其他 SECTION 讀來做判斷邏輯——不影響碰撞、
# 不影響機率、不影響任何行為。改這裡永遠安全，不用擔心連動。
#
## C_COUNTDOWN_HOT：倒數計時歸零後（＝干擾登場）計時器改用這個顏色，讓「時間到了」
## 是視覺事件不是文字事件。
## C_LEDGE_FX：攀爬手套成功時往外擴散淡出的那圈圓（見 well_world._draw_ledge_fx）。
## C_PROJ_WARN：投擲物落點預警的三角形。刻意跟 C_PROJECTILE 同色系但更亮，讓「這個
## 標記」跟「等一下會掉下來的那個東西」在視覺上連得起來。
## UPGRADE_ICON_COLOR：商店卡片上那塊色塊。刻意重用遊戲裡的既有顏色（燃料補給是綠
## 的、投擲物是橘紅的…），讓卡片跟井裡看到的東西對得起來，不是另一套獨立配色。
## ACHIEVEMENT_ICON_COLOR：成就卡片與橫幅上那塊色塊。同上原則——條件講的是哪個機制，
## 就用那個機制在井裡的顏色（義大利麵＝碎裂平台的褐、披薩＝彈射板的綠…）。
## C_EXTREME：極限模式開啟時那顆 icon 的顏色。刻意用最刺眼的紅，跟「規則變了」的
## 綠（C_SHOCK_WARN）與「這裡會死」的紅（C_STEAL_WARN）都不同——它是玩家自己按下去的。
## C_SHOCK_WARN：側風（衝擊波）解鎖前的右緣長條。⚠ 使用者指定綠色，跟另外兩種預警
## （投擲物紅三角、抽跳板紅閃爍）刻意不同色系——紅＝「這個位置馬上會死」，綠＝
## 「規則要變了」，兩種訊息要求的反應不一樣，同色會讓玩家把它當成又一發投擲物。
## C_SPARK：平台被削去時四散的火花。
## C_DOOM / C_DOOM_RING / C_DOOM_WARN：黑洞本體、邊緣與吸力範圍環、出現前的預警圈。
## 紫色是這遊戲裡唯一沒被別的機制佔走的色相（蟲洞也是紫，但蟲洞是亮紫小圓盤、
## 黑洞是幾乎全黑的大圓＋紫邊，形狀與明度差很大，不會混淆）。
## C_TOMB / C_TOMB_CROSS：歷史最高高度處的墓碑本體與十字。

const C_BG := Color(0.07, 0.06, 0.10)
const C_WALL := Color(0.16, 0.14, 0.20)
const C_WALL_EDGE := Color(0.30, 0.26, 0.38)
const C_PLAYER := Color(0.98, 0.83, 0.35)
const C_PLATFORM := Color(0.55, 0.62, 0.72)
const C_MOVING := Color(0.42, 0.72, 0.85)
const C_VERTICAL := Color(0.58, 0.55, 0.92)
const C_CIRCULAR := Color(0.85, 0.62, 0.92)
const C_PICKUP := Color(0.99, 0.78, 0.30)
const C_PICKUP_CORE := Color(1.0, 0.97, 0.86)
const C_FUEL := Color(0.38, 0.84, 0.62)
const C_FUEL_CORE := Color(0.88, 1.0, 0.94)
## 金幣／燃料沿貼圖輪廓的白光（使用者指定「白光」，08-10）。
## ⚠ 刻意用純白而不是各自的主色（C_PICKUP／C_FUEL）：這圈光的作用是讓小物件在雜亂
##   背景上被看見，不是替它上色——染成主色的話，在同色系背景前等於沒有描邊。
const C_PICKUP_GLOW := Color(1.0, 1.0, 1.0, 0.92)

## 爆炸平台：底色（未踩）→ 引信燒到底時的亮色。引信期間在兩者之間內插，
## **亮度就是剩餘時間**（同碎裂平台用 alpha 當剩餘壽命的做法）。
## ⚠ 底色刻意跟 C_FRAGILE 拉開：兩者都是「踩了會沒」，形狀又一樣，只靠位置分不出來。
const C_EXPLOSIVE := Color(0.85, 0.42, 0.30)
const C_EXPLOSIVE_HOT := Color(1.0, 0.95, 0.72)
const C_BLAST := Color(1.0, 0.62, 0.26)
const C_WORMHOLE := Color(0.62, 0.42, 0.95)
const C_WORMHOLE_CORE := Color(0.86, 0.80, 1.0)
const C_WORMHOLE_GLOW := Color(1.0, 0.80, 0.34)    # 常駐外緣金光（逆光感），見 _draw_wormhole
const C_COUNTDOWN_HOT := Color(1.0, 0.42, 0.40)    # 干擾登場時計時器變色，見上
const C_OK := Color(0.55, 0.88, 0.52)
const C_INVULN := Color(0.72, 0.96, 1.0)
const C_LEDGE_FX := Color(1.0, 1.0, 1.0)           # 攀爬特效圓圈，見上
const C_FRAGILE := Color(0.78, 0.55, 0.42)
const C_LAUNCHER := Color(0.55, 0.88, 0.52)
const C_MONSTER := Color(0.88, 0.35, 0.48)
const C_PAMELOE := Color(0.96, 0.44, 0.78)         # 懸浮射手本體，見上
const C_PAMELOE_SHOT := Color(1.0, 0.66, 0.90)     # 牠的子彈，同色系但更亮
const C_PAMELOE_CHARGE := Color(1.0, 0.94, 0.98)   # 發射前的充能閃爍
const C_PAMELOE_LASER := Color(1.0, 0.30, 0.55)    # 雷射變體的光束，同色系但更飽和刺眼

## 死亡爆炸（SECTION 6c）。⚠ placeholder：使用者之後會補真的爆炸素材，
## 換素材時這兩個顏色會一起作廢，但 6c 那段的時長常數要留著。
const C_DEATH_FX := Color(1.0, 0.66, 0.22)         # 擴散環與碎片
const C_DEATH_FX_CORE := Color(1.0, 0.96, 0.84)    # 中心亮球
const C_PROJECTILE := Color(0.95, 0.42, 0.30)
const C_WHIP := Color(1.0, 0.92, 0.55)
const C_AIM := Color(1.0, 0.55, 0.60, 0.65)
const C_STEAL_WARN := Color(1.0, 0.30, 0.35)
const C_PROJ_WARN := Color(1.0, 0.28, 0.24)        # 投擲物落點預警三角形，見上
const C_SHOCK_WARN := Color(0.36, 0.95, 0.48)      # 側風預警長條，見上
const C_DOOM := Color(0.05, 0.02, 0.10)            # 黑洞本體（事件視界）
const C_DOOM_RING := Color(0.72, 0.36, 0.98)       # 黑洞邊緣與吸力範圍環
const C_DOOM_WARN := Color(0.66, 0.32, 0.96)       # 黑洞出現前的紫色閃爍圈
const C_SPARK := Color(1.0, 0.78, 0.36)            # 平台被削去的火花，見上
const C_TOMB := Color(0.62, 0.64, 0.70)            # 墓碑本體，見上
const C_TOMB_CROSS := Color(0.94, 0.95, 0.98)      # 墓碑十字，見上
const C_GOAL := Color(0.98, 0.92, 0.45)
const C_TEXT := Color(0.94, 0.93, 0.97)
const C_TEXT_DIM := Color(0.62, 0.60, 0.70)
const C_PANEL := Color(0.12, 0.11, 0.17)           # 面板／卡片用（主頁與商店的框線與底色）
const C_PANEL_EDGE := Color(0.34, 0.30, 0.44)
const C_ACCENT := Color(0.42, 0.72, 0.85)
const C_CARD_LOCKED := Color(0.20, 0.19, 0.25)
const C_EXTREME := Color(1.0, 0.24, 0.22)          # 極限模式 icon，見上

const UPGRADE_ICON_COLOR := {
	"jump": C_PLAYER,
	"fuel": C_FUEL,
	"whip": C_WHIP,
	"launcher": C_LAUNCHER,
	"ledge": C_ACCENT,
}

const ACHIEVEMENT_ICON_COLOR := {
	"soul": C_WHIP,                # 不用鞭子 → 鞭子色
	"chattini_model": C_LAUNCHER,  # 不用 jetpack → jetpack 燃料條的色
	"spider2": C_WHIP,
	"big_cat": C_PROJECTILE,       # 小黃瓜＝投擲物
	"non_approval": C_FRAGILE,     # 義大利麵＝碎裂平台
	"speed_run": C_GOAL,
	"kaela": C_WORMHOLE,
	"bad_chattini": C_MONSTER,     # Chattini＝怪物
	"noooo": C_LAUNCHER,           # 披薩＝彈射板
}

# ===== SECTION 9b — 玩家貼圖（Kaela，本輪美術試接） =====
# 三張各自獨立姿勢貼圖，畫布完全同尺寸（78×108，來源 155×215 等比縮小 0.5023，
# 鎖高 108px）。⚠ 三張共用同一個錨點，不要每張各自量各自的貼齊點——不然切換姿勢
# 時角色會跳動。錨點量法：steady 幀（唯一一定要精準貼合平台的姿勢）用 alpha bbox
# 量出腳底像素列相對畫布高度的比例，其他兩張姿勢沿用同一比例，姿勢差異（跳躍腳
# 微縮、jetpack 火焰更長）用「相對這個錨點多畫一點」表現，不是重新對齊。

const KAELA_ART_SIZE := Vector2(78.0, 108.0)
const KAELA_FEET_ANCHOR_FRAC := 99.0 / 108.0   # 量測自 kaela_steady.png 縮圖後的 alpha bbox 底邊

## 無敵窗描邊寬度（px，畫在角色輪廓外側）。做法是把同一張貼圖用純色 modulate 往八個
## 方向各偏移這個距離、畫在角色底下，露出來的那一圈就是輪廓線——所以它天生貼合
## alpha 形狀，不是外接矩形。
## ⚠ 貼圖是 1:1 畫的（來源檔就是 KAELA_ART_SIZE），這裡的 1.0 才等於畫面上的 1px；
##   哪天 KAELA_ART_SIZE 跟來源檔尺寸脫鉤，這個值就不再是「1 個像素」。
## ⚠ 太細會被貼圖自身的抗鋸齒邊吃掉看不出來——看不見的無敵提示等於沒做，
##   真人試玩若讀不到就往上加（1.0 → 2.0），不要改成畫方框。
const KAELA_OUTLINE_WIDTH := 2.0

## 落地閃現：碰到平台那一刻短暫顯示 steady 姿勢（使用者拍板：接觸瞬間，約 0.1s），
## 之後平台本來就會給一次跳躍力（見 well_world._check_landing），角色隨即回到 jump 姿勢——
## 這裡不是「站立閒置」動畫，是撞擊瞬間的視覺回饋。
const LAND_FLASH_TIME := 0.1

# ===== SECTION 9c — 高度階級提示 =====
## 左上高度數字的跨階視覺提示（08-09 使用者拍板，見 ../../HANDOFF.md 當前狀態）。
## PRESSURE_STEP_HEIGHT_M 是唯一的階級分母：`floor(height_m / STEP)` 就是第幾階。
## ⚠ 這顆常數未來也是「無盡加壓」難度階梯的分母（HANDOFF「未動工但已有定論」第 3
##   條），兩邊共用同一顆，不要各自定義一份——階梯定義只能有一個來源。
const PRESSURE_STEP_HEIGHT_M := 500.0

## 無盡加壓（08-09 使用者拍板，見 ../../HANDOFF.md「未動工但已有定論」第 3 條）。
## 地形軸（間距／振幅／怪物與物資比例，全走 _lerp_by_height 與 spacing_at）的分母，
## 跟 goal_meters 脫鉤——地形軸滿檔後就凍結在最難但仍過得去的組態，不再繼續疊：
## 間距一旦超過 MAX_JUMP_HEIGHT 就是物理上跳不過去，那是壞掉不是難。
const DIFFICULTY_RAMP_HEIGHT_M := 1000.0

## 每階一組（徽章底色, 文字色）。第 6 階（3000m）以後沒有對應顏色，沿用陣列最後
## 一組——側風在 3000m 就已經頂到玩家全速（見 HANDOFF），紫色天花板之後不再變色
## 是刻意的：顏色到頂本身就是一種「這是極限」的訊號。
## 徽章底色是飽和色，文字色是同色系深色求可讀（白框徽章上不能疊淺色字）；
## tier 0 用深灰代替純黑——純黑徽章會直接融入遊戲的深色場景背景（C_BG）。
const TIER_BADGE_COLORS: Array[Color] = [
	Color(0.23, 0.23, 0.26),   # 0：0~500m（深灰，代替字面「黑」避免融入深色背景）
	Color(0.38, 0.84, 0.62),   # 1：500~1000m（同 C_FUEL 綠）
	Color(0.98, 0.92, 0.45),   # 2：1000~1500m（同 C_GOAL 黃）
	Color(1.0, 0.66, 0.22),    # 3：1500~2000m（同 C_DEATH_FX 橘）
	Color(0.88, 0.35, 0.48),   # 4：2000~2500m（同 C_MONSTER 紅）
	Color(0.72, 0.36, 0.98),   # 5：2500m 以上（同 C_DOOM_RING 紫，3000m+ 沿用）
]
const TIER_TEXT_COLORS: Array[Color] = [
	Color(0.88, 0.88, 0.90),
	Color(0.04, 0.24, 0.14),
	Color(0.29, 0.25, 0.02),
	Color(0.29, 0.17, 0.01),
	Color(0.27, 0.06, 0.12),
	Color(0.18, 0.06, 0.29),
]

func tier_at(height_m: float) -> int:
	return int(floor(maxf(height_m, 0.0) / PRESSURE_STEP_HEIGHT_M))

func tier_badge_color_at(height_m: float) -> Color:
	return TIER_BADGE_COLORS[clampi(tier_at(height_m), 0, TIER_BADGE_COLORS.size() - 1)]

func tier_text_color_at(height_m: float) -> Color:
	return TIER_TEXT_COLORS[clampi(tier_at(height_m), 0, TIER_TEXT_COLORS.size() - 1)]


## 三條「封頂軸」（乘法遞減，永遠 > 0）：每跨一階 PRESSURE_STEP_HEIGHT_M 就把對應
## interval_min 乘一次階梯係數，乘到地板常數就不再降。地板本身就是遊戲節奏能撐的下限，
## 三條都在 n=4（2000m）觸底，觸底之後這條軸不再變難——後續加壓全靠側風那條不封頂軸。
const PRESSURE_PROJECTILE_STEP_MULT := 0.85
const PRESSURE_PROJECTILE_FLOOR := 0.9
const PRESSURE_STEAL_STEP_MULT := 0.85
const PRESSURE_STEAL_FLOOR := 3.0
const PRESSURE_DOOM_STEP_MULT := 0.88
const PRESSURE_DOOM_FLOOR := 5.0

func eff_projectile_interval_min(height_m: float) -> float:
	return maxf(
		PRESSURE_PROJECTILE_FLOOR,
		projectile_interval_min * pow(PRESSURE_PROJECTILE_STEP_MULT, tier_at(height_m))
	)

func eff_steal_interval_min(height_m: float) -> float:
	return maxf(
		PRESSURE_STEAL_FLOOR,
		steal_interval_min * pow(PRESSURE_STEAL_STEP_MULT, tier_at(height_m))
	)

func eff_doom_interval_min(height_m: float) -> float:
	return maxf(
		PRESSURE_DOOM_FLOOR,
		doom_interval_min * pow(PRESSURE_DOOM_STEP_MULT, tier_at(height_m))
	)


## 唯一「不封頂軸」：側風靠 SHOCKWAVE_RESPONSE 逐階疊乘率，人類天花板抓在 3000m
## （第 6 階）：400 × 1.23^6 ≈ 1387 px/s，逼近玩家全速 1400 px/s——3000m 後陣風峰值
## 追平/超過玩家最快移動速度，「必然墜落」在夠高的地方重新成立。
## ⚠⚠ 只動 RESPONSE：SHOCKWAVE_BURST_TIME／FORCE_START／FORCE_SLOPE 維持不動，
##   同時動 BURST 會連 0~1000m 現有手感一起改掉，兩個變數一起動事後分不出是哪個造成的。
const PRESSURE_SHOCKWAVE_STEP_MULT := 1.23

func eff_shockwave_response(height_m: float) -> float:
	return SHOCKWAVE_RESPONSE * pow(PRESSURE_SHOCKWAVE_STEP_MULT, tier_at(height_m))


# ===== SECTION 10 — 導出值（勿手改，由上面算出來） =====

func goal_y(start_y: float) -> float:
	return start_y - goal_meters * PIXELS_PER_METER

func meters_from_y(start_y: float, y: float) -> float:
	return maxf(0.0, (start_y - y) / PIXELS_PER_METER)

# ------------------------------------------------------------------
# 極限模式的生效值
# ------------------------------------------------------------------
# 極限模式（使用者拍板）：**所有等待歸零** —— 干擾登場的 67s 等待、四階解鎖的
# 0/20/40/60s 等待全部變 0，開局第一幀 stage() 就是 4，四種干擾同時各跑自己的計時器
# （三個 *_timer 的初值本來就是 0，所以「立刻施作」是免費送的，不必另外處理）。
#
# ⚠⚠ **預警時間不歸零**（紅三角 2s／紫圈 2s／紅閃 0.5s／綠條 2s）。「等待」指的是
#    「玩家還沒被干擾的那段空白」，預警不是空白——它是威脅唯一的可見形式。拿掉預警
#    等於把四種干擾全變成不可歸因的死法，那是 PILLARS 從頭到尾在防的東西，
#    極限模式要的是「更早更密」不是「更不公平」。
#
# ⚠ 開關狀態的家是 SpikeSave（它是存檔的家，要跨局記住）。這裡刻意反向引用 SpikeSave，
#   換來的是「模式規則只住這一處」——Interference 與 UI 一律讀 eff_*，不各自判斷模式。
#   （執行期才呼叫，兩個 autoload 都 ready 了；autoload 順序 Config → Save 見 project.godot）
#
# ⚠ 讀取端一律用 eff_*，**不要**直接讀 interference_start / stage_*_offset。
#   直接讀的地方在極限模式下會靜默失效（不報錯、只是那一項照舊等 67 秒）。
#   唯一的例外是 smoke.gd 的壓力局，它是「暫時改寫原始值再還原」，走的是另一條路。

func eff_interference_start() -> float:
	return 0.0 if SpikeSave.extreme_mode else interference_start

func eff_stage_projectile_offset() -> float:
	return 0.0 if SpikeSave.extreme_mode else stage_projectile_offset

func eff_stage_steal_offset() -> float:
	return 0.0 if SpikeSave.extreme_mode else stage_steal_offset

func eff_stage_shockwave_offset() -> float:
	return 0.0 if SpikeSave.extreme_mode else stage_shockwave_offset

func eff_stage_doom_offset() -> float:
	return 0.0 if SpikeSave.extreme_mode else stage_doom_offset


## 無盡模式的生效值（08-10 使用者拍板，與極限模式同一種「狀態住 SpikeSave、規則住這裡」
## 的分工）。false ＝ 這一局沒有終點，爬到死為止；true ＝ 抵達 goal_meters 就成功結算。
## ⚠ 判定端一律讀這個函式，不要直接讀 SpikeSave.endless_mode——理由同上面 eff_* 那組：
##   規則只能有一個家，散出去之後「無盡模式該不該解成就」這種問題會有兩個答案。
## ⚠ 無盡模式**不**解鎖下一關、也不算登頂成就：沒有終點就沒有「抵達終點」這件事。
func eff_has_goal() -> bool:
	return not SpikeSave.endless_mode


# ===== SECTION 11 — 開發者工具（正式版玩家碰不到） =====
#
# ⚠⚠ 這一段控制的東西**一般玩家不該看得到、也不該按得到**。開關只有一個家：
#    `dev_mode()`。任何新的開發者功能一律問它，不要自己再判斷一次 OS.is_debug_build()
#    ——散出去之後「正式版到底有沒有這顆按鈕」就會有兩個答案。
#
# 開啟條件（三選一成立即為 true）：
#   1. debug build（從編輯器跑、或 debug 匯出）——本機開發自動有，不必記得加旗標。
#   2. 桌面版啟動參數 `--dev`。
#   3. Web 版網址加 `?dev=1`（itch 頁面也吃，因為 iframe 的 URL 就是遊戲自己的 URL）。
# 2 與 3 的存在理由：**正式 release 版上線後我們自己還要測**。只吃 debug build 的話，
# 每次要測都得另外出一包 debug 版，而那包跟玩家實際在玩的不是同一份東西。
#
# ⚠ 這不是防作弊機制（同存檔匯出碼那條 ⚠⚠：client 端沒有真正的防線）。它防的是
#   「一般玩家不小心碰到」，不防「有人故意加旗標」。真要防得等伺服器端榜單。
const DEV_TELEPORT_M := 300.0           # 傳送鈕一次往上送多少公尺
const DEV_CMDLINE_FLAG := "--dev"       # 桌面版啟動參數
const DEV_WEB_QUERY_KEY := "dev"        # Web 版網址參數（?dev=1）

## -1 ＝ 還沒算過。算一次就快取：Web 版要問 JavaScriptBridge，每幀重問太貴，
## 而且這個答案在一次執行內不會變。
var _dev_mode_cache: int = -1


func dev_mode() -> bool:
	if _dev_mode_cache >= 0:
		return _dev_mode_cache == 1
	_dev_mode_cache = 1 if _detect_dev_mode() else 0
	return _dev_mode_cache == 1


## 測試／稽核用：直接指定開發者模式的答案，不要讓 headless 稽核依賴「跑在哪種 build」。
## ⚠ 正式遊戲流程沒有任何地方呼叫它——它只是讓 dev_mode() 的行為驗得到。
func set_dev_mode_override(on: bool) -> void:
	_dev_mode_cache = 1 if on else 0


func _detect_dev_mode() -> bool:
	if OS.is_debug_build():
		return true
	if OS.get_cmdline_args().has(DEV_CMDLINE_FLAG):
		return true
	return _web_dev_flag()


## Web 版的網址參數。⚠ 走 Engine.get_singleton() 而不是直接寫 JavaScriptBridge：
##   那個單例只有 Web 匯出才註冊，識別字直接寫在腳本裡會讓桌面版**解析期**就報錯
##   （不是執行到才錯，是整支腳本載不起來）。
func _web_dev_flag() -> bool:
	if not OS.has_feature("web"):
		return false
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var search = bridge.call("eval", "window.location.search", true)
	if typeof(search) != TYPE_STRING:
		return false
	return String(search).contains("%s=1" % DEV_WEB_QUERY_KEY)
