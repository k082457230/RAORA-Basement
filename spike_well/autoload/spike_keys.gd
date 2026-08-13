extends Node
## 按鍵綁定：讀寫 user://，並提供「這個動作現在是哪個鍵」。
##
## 分工同 SpikeSave：預設值住 SpikeConfig.DEFAULT_KEYS（可調數值的唯一的家），
## 這個檔只負責「玩家改成了什麼」「存不存得起來」「顯示成什麼字」。
##
## ⚠ 遊戲層一律呼叫 key_of()，不准出現 KEY_A / KEY_SPACE 這種字面值——
##   不然設定頁改了鍵，遊戲裡還是照舊的按。

const SAVE_PATH := "user://spike_keys.json"
## 測試沙盒（同 SpikeSave 的理由）：冒煙測試會真的走 set_key() → save()，
## 不隔開的話跑一次測試就把玩家改好的按鍵洗掉了。
const SANDBOX_PATH := "user://spike_keys_test.json"

var save_path: String = SAVE_PATH
var binds: Dictionary = {}
var last_error: String = ""


func use_sandbox() -> void:
	save_path = SANDBOX_PATH
	_reset()


func _ready() -> void:
	load_binds()


func key_of(action: String) -> int:
	return int(binds.get(action, SpikeConfig.DEFAULT_KEYS.get(action, KEY_NONE)))


func is_action_pressed(action: String) -> bool:
	var k := key_of(action)
	return k != KEY_NONE and Input.is_key_pressed(k)


## 綁定新鍵。回傳 true ＝ 綁成功。
##
## ⚠⚠ 08-13 使用者拍板改規則：**兩個功能不准共用同一顆鍵，撞到就拒絕**。
##   舊行為是「把撞到的那個動作清成未綁定」，理由是「拒絕會讓玩家沒辦法交換兩個鍵」——
##   代價是玩家按一次就會有一個功能靜默變成沒有鍵可按，而他多半要到遊戲中按了沒反應
##   才發現。使用者選擇「寧可換不了也不要靜默失效」。
##   ⚠ 想交換 A、B 兩個鍵的玩家：先把其中一個改到第三顆閒置鍵，再交換。UI 會把
##     「這顆鍵已經是誰的」直接寫在畫面上（見 SpikeUI._input 的撞鍵訊息）。
func set_key(action: String, keycode: int) -> bool:
	if not SpikeConfig.DEFAULT_KEYS.has(action):
		return false
	if action_using(keycode, action) != "":
		return false
	binds[action] = keycode
	save()
	return true


## 這顆鍵現在綁在哪個動作上（排除 except_action）。沒有人用回空字串。
## ⚠ KEY_NONE 不算佔用：好幾個動作可能同時是未綁定狀態，那不是衝突。
func action_using(keycode: int, except_action: String = "") -> String:
	if keycode == KEY_NONE:
		return ""
	for other in SpikeConfig.KEY_ORDER:
		if other == except_action:
			continue
		if key_of(other) == keycode:
			return other
	return ""


func reset_defaults() -> void:
	_reset()
	save()


## 給 UI 顯示。未綁定顯示破折號，不要顯示空字串（按鈕會變成看不見的空框）。
func label_of(action: String) -> String:
	var k := key_of(action)
	if k == KEY_NONE:
		return "—"
	return OS.get_keycode_string(k)


func _reset() -> void:
	binds = {}
	for key in SpikeConfig.DEFAULT_KEYS.keys():
		binds[key] = SpikeConfig.DEFAULT_KEYS[key]


# ------------------------------------------------------------------
# 存檔 I/O（格式與失敗處理比照 SpikeSave）
# ------------------------------------------------------------------

func load_binds() -> void:
	_reset()
	last_error = ""

	if not FileAccess.file_exists(save_path):
		return

	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		last_error = "按鍵設定讀檔失敗（%d）" % FileAccess.get_open_error()
		return
	var raw := f.get_as_text()
	f.close()

	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		last_error = "按鍵設定格式壞掉，已退回預設"
		return

	# 只認目前表裡有的動作：加了新動作之後舊存檔仍讀得進來，多出來的欄位直接忽略
	for key in SpikeConfig.DEFAULT_KEYS.keys():
		if data.has(key):
			binds[key] = int(data[key])


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		last_error = "按鍵設定寫檔失敗（%d）" % FileAccess.get_open_error()
		return
	f.store_string(JSON.stringify(binds, "\t"))
	f.close()
	last_error = ""
