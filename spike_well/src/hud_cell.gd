class_name HudCell
extends Control
## 左下角 HUD 的一格「道具方格」（08-13 使用者規格，項目 13）。
##
## 一格長這樣：
##   ┌────────┐
##   │   盾   │ ← ICON（現在是 placeholder 文字，素材到位換成 TextureRect，版面不動）
##   │ E      │ ← 左下角的快捷鍵（沒有快捷鍵的東西留空，例如攀爬手套）
##   └────────┘
##
## 冷卻表現（使用者規格「該格子呈現黑色、並以順時針逐步變白」）：
##   ready_ratio 1.0 ＝ 完全可用（沒有黑幕）；0.0 ＝ 剛進冷卻（整格黑）。
##   黑幕是一塊**扇形**，從 12 點鐘方向開始順時針保留「還沒好的那一段」，
##   所以看起來就是白色的部分順時針長回來。
##
## ⚠⚠ 這一格**只負責畫**，不判斷任何遊戲狀態：ready_ratio 由 SpikeUI 從 hud_data 餵進來。
##   在這裡自己去問 SpikeSave／WellWorld 會讓「什麼時候算冷卻」多出第二個家。
## ⚠ 扇形沿**方形邊界**取樣，不是畫圓：畫圓的話四個角永遠是白的，看起來像黑幕破圖。
## ⚠ 沒有 CD 概念的格子（鞭子、被動 buff）就一直餵 1.0；用「不可用」表達的格子
##   （攀爬手套／懷錶這次離地已經用掉）餵 0.0 ＝ 整格黑，等落地才變回 1.0。

## 冷卻黑幕的濃度。刻意不到全黑：底下的 icon 要還看得出是哪一顆。
const CD_MASK_ALPHA := 0.72
## 扇形取樣角度（度）。12 是「看不出是折線」與「不要畫太多點」的折衷。
const CD_SAMPLE_DEG := 12.0
const BORDER_WIDTH := 2.0
const CORNER_PAD := 4.0

var accent: Color = Color(1.0, 1.0, 1.0)
var dimmed: bool = false
## 0 ＝ 整格黑（剛進冷卻／現在不能用）、1 ＝ 完全可用
var ready_ratio: float = 1.0

var _glyph: Label
var _key: Label


## font 由 SpikeUI 傳進來（內嵌字型的唯一來源是 SpikeUI.shared_font()，
## 這裡自己 load 一份會讓 Web 版的中文變豆腐方塊）。
func setup(cell_size: Vector2, font: Font, glyph_size: int, key_size: int) -> void:
	custom_minimum_size = cell_size
	size = cell_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_glyph = Label.new()
	_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.add_theme_font_override("font", font)
	_glyph.add_theme_font_size_override("font_size", glyph_size)
	add_child(_glyph)

	# 快捷鍵靠左下角（使用者規格「ICON 格左下角為快捷鍵」）。
	# ⚠ 直接給 position／size，**不要**用 set_anchors_preset(BOTTOM_LEFT)：那個 preset 之後
	#   position 是相對「格子的左下角」算的，同一組偏移會把字推到格子外面下方（第一版就是
	#   這樣，visual_check 的 hud_check_bottom_left.png 拍到快捷鍵掉在下一列的格子旁邊）。
	var key_h: float = float(key_size) + 4.0
	_key = Label.new()
	_key.position = Vector2(CORNER_PAD, cell_size.y - CORNER_PAD - key_h)
	_key.size = Vector2(cell_size.x - CORNER_PAD * 2.0, key_h)
	_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key.add_theme_font_override("font", font)
	_key.add_theme_font_size_override("font_size", key_size)
	add_child(_key)


func set_content(glyph: String, key_text: String) -> void:
	if _glyph != null:
		_glyph.text = glyph
	if _key != null:
		_key.text = key_text


func set_colors(text_color: Color, key_color: Color) -> void:
	if _glyph != null:
		_glyph.add_theme_color_override("font_color", text_color)
	if _key != null:
		_key.add_theme_color_override("font_color", key_color)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var a: float = 0.10 if dimmed else 0.28
	draw_rect(r, Color(accent, a), true)
	draw_rect(r, Color(accent, 0.32 if dimmed else 1.0), false, BORDER_WIDTH)
	if ready_ratio < 1.0:
		var pts := _cd_wedge(clampf(ready_ratio, 0.0, 1.0))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, CD_MASK_ALPHA))


## 「還沒好」的那塊扇形（從 12 點鐘 ＋ ratio 圈開始，順時針補到 12 點鐘）。
## ratio ＝ 0 時整格；ratio ＝ 1 時空的（呼叫端已經先擋掉）。
func _cd_wedge(ratio: float) -> PackedVector2Array:
	var c := size * 0.5
	var out := PackedVector2Array()
	out.append(c)
	var from: float = TAU * ratio
	var step: float = deg_to_rad(CD_SAMPLE_DEG)
	var ang: float = from
	while ang < TAU:
		out.append(c + _edge_dir(ang))
		ang += step
	out.append(c + _edge_dir(TAU))
	return out


## 角度 → 方格邊界上的點（0 ＝ 正上方，順時針為正）。
## ⚠ 用「射線打到哪一條邊」算，不是取固定半徑：固定半徑畫出來是圓，四個角會留白。
func _edge_dir(ang: float) -> Vector2:
	var d := Vector2(sin(ang), -cos(ang))
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	var tx: float = INF if absf(d.x) < 0.0001 else hw / absf(d.x)
	var ty: float = INF if absf(d.y) < 0.0001 else hh / absf(d.y)
	return d * minf(tx, ty)
