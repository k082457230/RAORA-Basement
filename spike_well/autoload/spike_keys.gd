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


## 綁定新鍵。同一個鍵被別的動作佔用時，把舊的那個動作**清成未綁定**而不是拒絕——
## 拒絕會讓玩家卡在「想交換兩個鍵卻換不了」的死結裡。
func set_key(action: String, keycode: int) -> void:
	if not SpikeConfig.DEFAULT_KEYS.has(action):
		return
	for other in SpikeConfig.KEY_ORDER:
		if other != action and int(binds.get(other, KEY_NONE)) == keycode:
			binds[other] = KEY_NONE
	binds[action] = keycode
	save()


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
