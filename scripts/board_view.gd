class_name BoardView
extends Node2D

## 보드 슬롯만 그린다. 백판 없음. 각 칸에 칸보다 20% 작은 라운드 사각형을 중앙 배치.

const SLOT_COL := Color("f1e6c4")

var w := 8
var h := 8
var cell := 75.0

var _ghost_cells: Array[Vector2i] = []
var _ghost_on := false
var _ghost_merge := false
var _sb := StyleBoxFlat.new()

var _slot := 0.0     # 칸 안 사각형 크기 (cell * 0.8)
var _pad := 0.0      # 중앙정렬 여백 (cell * 0.1)
var _radius := 0


func setup(p_w: int, p_h: int, p_cell: float) -> void:
	w = p_w
	h = p_h
	cell = p_cell
	_slot = cell * 0.8
	_pad = cell * 0.1
	_radius = int(_slot * 0.22)
	queue_redraw()


func set_ghost(board_cells: Array[Vector2i], will_merge: bool) -> void:
	_ghost_cells = board_cells.duplicate()
	_ghost_on = true
	_ghost_merge = will_merge
	queue_redraw()


func clear_ghost() -> void:
	if _ghost_on:
		_ghost_on = false
		queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	_sb.set_corner_radius_all(_radius)
	# 빈 슬롯 (칸보다 20% 작은 라운드 사각형, 중앙 정렬)
	_sb.bg_color = SLOT_COL
	for y in h:
		for x in w:
			_sb.draw(ci, Rect2(x * cell + _pad, y * cell + _pad, _slot, _slot))
	# 스냅 고스트
	if _ghost_on:
		_sb.bg_color = Color(0.30, 0.78, 0.42, 0.55) if _ghost_merge else Color(1, 1, 1, 0.35)
		for c in _ghost_cells:
			_sb.draw(ci, Rect2(c.x * cell + _pad, c.y * cell + _pad, _slot, _slot))
