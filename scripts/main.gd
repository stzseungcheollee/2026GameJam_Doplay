extends Node2D

## 그림 맞추기 퍼즐 (직소 방식)
##  - 그림을 폴리오미노 조각으로 쪼갠 뒤, 완성 크기보다 큰 보드에 랜덤하게 흩뿌린다.
##  - 조각을 끌어 "서로 올바른 상대 위치"에 놓으면 뭉쳐진다(그룹).
##  - 위치와 상관없이 모든 조각이 하나로 뭉쳐 그림이 완성되면 클리어.
##  - 이미지는 res://assets/puzzles/ 에 1.png, 2.png ... 번호로 넣으면 자동으로 레벨이 된다.

const VIEW_W := 720.0
const VIEW_H := 1280.0
const BOARD_W_BUDGET := 576.0   # 보드가 가로로 채울 최대 크기(폭 720 중, 좌우 여백 넉넉히)
const BOARD_H_BUDGET := 900.0   # 보드가 세로로 채울 최대 크기
const MENU_SCENE := "res://scenes/menu.tscn"
const FADE_COL := Color(0.10, 0.07, 0.04)   # 메뉴에서 넘어올 때의 컷 전환(페이드인) 색
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const INTRO_STAGGER := 0.05     # 조각 팝업 등장 간격(초)

# 압정(누름핀) 이미지. 압정칸 보드 위치는 회전해도 고정이라, 조각과 무관한 별도 레이어에 '안 돌아가는' 스프라이트로 얹는다.
const PIN_PATH := "res://assets/sprites/pin.png"
const PIN_H_FRAC := 1.15                  # 핀 높이 = cell_px * 이 값
const PIN_TIP := Vector2(0.42, 0.90)      # 핀 이미지 안에서 '끝(팁)'의 UV — 이 점이 압정칸 중앙에 닿는다
const PIN_NUDGE := Vector2(5, 5)          # 핀 그림만 우하단으로 살짝 이동(순수 시각 보정, 로직 무관)

# ─────────────────────────────────────────────────────────────────────────────
# ★ 레벨 밸런스 표 — 레벨마다 한 줄. 뒤로 갈수록 어려워지게 짠다.
#   grid  : 완성 그림을 나누는 격자 (가로 x 세로). 총 칸 수 = 조각들이 덮는 넓이.
#   board : 조각을 흩뿌리는 보드 (가로 x 세로). 격자보다 클수록 넓게 흩어져 찾기 어렵다. (격자 이상이어야 함)
#   piece : 조각 한 개의 크기 범위 (최소칸, 최대칸). 최대칸이 작을수록 조각이 잘게 쪼개져 개수가 많아진다.
#   boxes : 이 레벨에 놓을 상자 목록. 항목 N = box_N 상자 하나가 "가장 작은 조각 N개"를 숨긴다.
#           예) [3, 1] = box_3(3조각 숨김) 1개 + box_1(1조각 숨김) 1개. [] = 상자 없음.
#   tacks : 이 레벨에 박을 압정 개수(옵션, 없으면 0). 압정 조각은 완성 위치에 고정돼 못 움직이고,
#           압정칸을 축으로만 회전한다. 완성 그림이 보드 안에 통째로 들어가는 곳에 두므로 클리어는 항상 가능.
#   ※ 규칙: (상자가 숨기는 총 조각 수 + 1) ≤ 최소 조각 수(= ceil(칸수 / piece 최대)). --balance 로 점검.
#   레벨이 그림 수보다 적으면 마지막(가장 어려운) 줄을 계속 쓴다.
# ─────────────────────────────────────────────────────────────────────────────
const LEVELS: Array[Dictionary] = [
	{"grid": Vector2i(2, 3), "board": Vector2i(4, 4),  "piece": Vector2i(2, 3), "boxes": []},          #  1  튜토리얼(상자 없음)
	{"grid": Vector2i(2, 3), "board": Vector2i(4, 5),  "piece": Vector2i(1, 3), "boxes": [1]},         #  2  상자 첫 등장
	{"grid": Vector2i(3, 3), "board": Vector2i(5, 5),  "piece": Vector2i(2, 4), "boxes": [1], "tacks": 1},   #  3  압정 첫 등장
	{"grid": Vector2i(3, 3), "board": Vector2i(5, 5),  "piece": Vector2i(1, 3), "boxes": [2]},         #  4
	{"grid": Vector2i(3, 4), "board": Vector2i(6, 6),  "piece": Vector2i(2, 4), "boxes": [2]},         #  5
	{"grid": Vector2i(3, 4), "board": Vector2i(6, 6),  "piece": Vector2i(1, 3), "boxes": [3]},         #  6
	{"grid": Vector2i(4, 4), "board": Vector2i(7, 7),  "piece": Vector2i(2, 4), "boxes": [1, 2]},      #  7  상자 2개
	{"grid": Vector2i(4, 4), "board": Vector2i(7, 7),  "piece": Vector2i(1, 3), "boxes": [3], "tacks": 1},   #  8  (압정+상자 → 조각 잘게: 최악 보장선 확보)
	{"grid": Vector2i(4, 5), "board": Vector2i(7, 8),  "piece": Vector2i(2, 4), "boxes": [2, 2]},      #  9
	{"grid": Vector2i(4, 5), "board": Vector2i(8, 8),  "piece": Vector2i(1, 4), "boxes": [1, 3]},      # 10
	{"grid": Vector2i(4, 5), "board": Vector2i(8, 8),  "piece": Vector2i(1, 3), "boxes": [2, 3]},      # 11
	{"grid": Vector2i(5, 5), "board": Vector2i(8, 8),  "piece": Vector2i(2, 4), "boxes": [3, 3]},      # 12
	{"grid": Vector2i(5, 5), "board": Vector2i(8, 9),  "piece": Vector2i(1, 3), "boxes": [2, 2, 2], "tacks": 1}, # 13  상자 3개
	{"grid": Vector2i(5, 6), "board": Vector2i(9, 9),  "piece": Vector2i(2, 4), "boxes": [3, 3]},      # 14
	{"grid": Vector2i(5, 6), "board": Vector2i(9, 9),  "piece": Vector2i(1, 4), "boxes": [1, 3, 3]},   # 15
	{"grid": Vector2i(5, 6), "board": Vector2i(9, 9),  "piece": Vector2i(1, 3), "boxes": [3, 3, 3]},   # 16
	{"grid": Vector2i(6, 6), "board": Vector2i(9, 10), "piece": Vector2i(2, 4), "boxes": [2, 3, 3]},   # 17
	{"grid": Vector2i(6, 6), "board": Vector2i(10, 10),"piece": Vector2i(1, 3), "boxes": [2, 3, 3], "tacks": 2}, # 18
	{"grid": Vector2i(6, 7), "board": Vector2i(10, 10),"piece": Vector2i(1, 4), "boxes": [3, 3, 3]},   # 19
	{"grid": Vector2i(6, 7), "board": Vector2i(10, 10),"piece": Vector2i(1, 3), "boxes": [1, 3, 3, 3]}, # 20  상자 4개
	{"grid": Vector2i(7, 7), "board": Vector2i(11, 11),"piece": Vector2i(1, 4), "boxes": [3, 3, 3, 3]}, # 21
	{"grid": Vector2i(7, 7), "board": Vector2i(11, 11),"piece": Vector2i(1, 3), "boxes": [2, 3, 3, 3]}, # 22
	{"grid": Vector2i(7, 8), "board": Vector2i(11, 11),"piece": Vector2i(1, 3), "boxes": [3, 3, 3, 3], "tacks": 2}, # 23
	{"grid": Vector2i(7, 9), "board": Vector2i(11, 11),"piece": Vector2i(1, 3), "boxes": [3, 3, 3, 3, 3]}, # 24  상자 5개
]

var cell_px := 75.0
var board_origin := Vector2.ZERO
var snap_dist := 45.0
var puzzle_w := 5              # 현재 레벨 그림 격자 가로 (LEVELS 에서 결정)
var puzzle_h := 5              # 현재 레벨 그림 격자 세로
var board_w := 8              # 현재 레벨 흩뿌림 보드 가로 (LEVELS 에서 결정)
var board_h := 8              # 현재 레벨 흩뿌림 보드 세로

var level_textures: Array[Texture2D] = []
var level_idx := 0
var cur_tex: Texture2D

var groups: Array[PuzzleGroup] = []
var cell_group: Dictionary = {}          # solutionCell -> PuzzleGroup
var groups_layer: Node2D
var boxes: Array[PuzzleBox] = []         # 조각을 숨긴 상자들
var boxes_layer: Node2D
var _box_plan: Array = []                # 이번 레벨 각 상자에 담을 조각 묶음 (Array of Array[PuzzleGroup])
var pins: Array[Node2D] = []             # 압정칸에 꽂은 핀 스프라이트들 (안 돌아감·고정)
var pins_layer: Node2D
var _pin_tex: Texture2D                  # 핀 텍스처 캐시
var board_view: BoardView

var drag_group: PuzzleGroup = null
var drag_offset := Vector2.ZERO
var busy := false

var _particle_tex: Texture2D          # 파티클용 둥근 흰색 텍스처 (캐시)

var hud_level: Label
var overlay: Control
var dim: ColorRect
var riser: Control
var riser_shadow: Panel
var riser_pic: TextureRect
var overlay_btn: Button
var _bob_tween: Tween
var _fade: ColorRect


func _ready() -> void:
	get_window().title = "그림 맞추기 퍼즐"
	RenderingServer.set_default_clear_color(Color("e7d6ab"))

	# 보드/조각 레이어만 만들고, 크기·위치는 레벨마다 _layout_board() 에서 정한다(격자가 레벨별로 다름).
	board_view = BoardView.new()
	board_view.z_index = 0
	add_child(board_view)

	groups_layer = Node2D.new()
	groups_layer.z_index = 10
	add_child(groups_layer)

	boxes_layer = Node2D.new()
	boxes_layer.z_index = 20        # 조각 위에 올라가 확실히 터치되고, 열릴 때 조각이 아래에서 튀어나온다
	add_child(boxes_layer)

	pins_layer = Node2D.new()
	pins_layer.z_index = 15         # 조각 위(핀은 늘 보이게). 조각처럼 회전하지 않는 별도 레이어라 핀이 안 돌아간다.
	add_child(pins_layer)

	_build_ui()
	level_textures = await _load_levels()
	# 메뉴(로비)에서 고른 스테이지부터 시작한다(없으면 0). 범위를 벗어나면 클램프.
	# 개발용: `-- --level=3` 처럼 시작 레벨을 강제로 지정할 수 있다(1부터). 압정/상자 레벨 점검에 쓴다.
	var start := clampi(SaveData.pending_level, 0, maxi(level_textures.size() - 1, 0))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			start = clampi(int(a.trim_prefix("--level=")) - 1, 0, maxi(level_textures.size() - 1, 0))
	start_level(start)
	_fade_in()

	if "--balance" in OS.get_cmdline_user_args():
		_report_balance()

	if "--test" in OS.get_cmdline_user_args():
		_run_self_test()


# ---------- 레벨 로딩 ----------

## assets/puzzles 에서 1.png, 2.png ... 를 순서대로 찾는다. 없으면 코드 그림으로 대체.
## 이미지 목록 스캔은 menu(로비)와 똑같이 SaveData 로 공유한다(원본 유지 — 레벨 시작 때 격자 비율로 중앙 크롭).
func _load_levels() -> Array[Texture2D]:
	var out := SaveData.scan_puzzle_textures()
	if out.is_empty():
		for sid in 3:
			out.append(await _paint_texture(sid))
	return out


## 이미지를 격자 비율(w:h)에 맞춰 중앙 크롭한다 → 각 칸이 정사각 텍셀이 되어 그림 왜곡이 없다.
## (예: 2x3 격자면 세로로 긴 2:3 사각형으로 원본 중앙을 잘라낸다.)
func _aspect_crop(tex: Texture2D, w: int, h: int) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	var tw := img.get_width()
	var th := img.get_height()
	var ar := float(w) / float(h)              # 목표 가로/세로 비
	var crop_w := tw
	var crop_h := int(roundf(float(tw) / ar))
	if crop_h > th:                            # 세로가 부족하면 세로에 맞춘다
		crop_h = th
		crop_w = int(roundf(float(th) * ar))
	var region := Rect2i((tw - crop_w) / 2, (th - crop_h) / 2, crop_w, crop_h)
	return ImageTexture.create_from_image(img.get_region(region))


func _paint_texture(sid: int) -> Texture2D:
	var px := 640      # 정사각 원본. 실제 격자 비율 크롭은 start_level 에서 한다
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art := PictureArt.new()
	art.scene_id = sid
	art.px = float(px)
	vp.add_child(art)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return ImageTexture.create_from_image(img)


# ---------- 레벨 시작 ----------

## 레벨 idx 의 설정(LEVELS)을 돌려준다. 정의된 레벨보다 뒤면 마지막(가장 어려운) 설정을 계속 쓴다.
func _level_cfg(idx: int) -> Dictionary:
	return LEVELS[mini(idx, LEVELS.size() - 1)]


func start_level(idx: int) -> void:
	busy = true
	drag_group = null
	level_idx = idx
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	groups_layer.visible = true
	pins_layer.visible = true
	board_view.clear_ghost()
	for g in groups:
		g.queue_free()
	groups.clear()
	cell_group.clear()
	for b in boxes:
		b.queue_free()
	boxes.clear()
	for p in pins:
		p.queue_free()
	pins.clear()

	# 이 레벨의 설정(격자·보드·조각크기·상자)을 LEVELS 에서 읽어 배치한다.
	var cfg := _level_cfg(idx)
	var grid: Vector2i = cfg["grid"]
	var board: Vector2i = cfg["board"]
	var psize: Vector2i = cfg["piece"]
	puzzle_w = grid.x
	puzzle_h = grid.y
	board_w = maxi(board.x, puzzle_w)      # 보드는 최소한 그림 격자만큼은 커야 한다
	board_h = maxi(board.y, puzzle_h)
	cur_tex = _aspect_crop(level_textures[idx], puzzle_w, puzzle_h)
	_layout_board()

	var src_cell := Vector2(cur_tex.get_width(), cur_tex.get_height()) / Vector2(puzzle_w, puzzle_h)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var regions := _partition(puzzle_w, puzzle_h, psize.x, psize.y, rng)

	for region in regions:
		var cells: Array[Vector2i] = []
		for c in region:
			cells.append(c)
		var g := PuzzleGroup.new()
		g.init(cells, Vector2i.ZERO, cell_px, src_cell, cur_tex)
		groups_layer.add_child(g)
		groups.append(g)
		for c in cells:
			cell_group[c] = g

	_choose_boxed()
	_choose_tacked()
	_scatter(rng)
	_update_hud()
	overlay.visible = false
	# 등장 팝업 애니메이션 동안 입력을 막았다가 끝나면 해제
	var intro_time := groups.size() * INTRO_STAGGER + 0.5
	get_tree().create_timer(intro_time).timeout.connect(func() -> void: busy = false)


## 현재 격자(board_w × board_h)에 맞춰 칸 크기·보드 위치를 계산하고 보드/조각 레이어를 배치한다.
## 가로·세로 예산 중 더 빡빡한 쪽에 맞춰 칸을 정사각으로 키운 뒤, 화면 정중앙에 정렬한다.
func _layout_board() -> void:
	cell_px = floorf(minf(BOARD_W_BUDGET / board_w, BOARD_H_BUDGET / board_h))
	snap_dist = cell_px * 0.6
	var bpx := cell_px * board_w
	var bpy := cell_px * board_h
	board_origin = Vector2(
		roundf((VIEW_W - bpx) / 2.0),
		roundf((VIEW_H - bpy) / 2.0))
	board_view.setup(board_w, board_h, cell_px)
	board_view.position = board_origin
	groups_layer.position = board_origin
	boxes_layer.position = board_origin
	pins_layer.position = board_origin


## 각 그룹을 랜덤 회전 + 서로 겹치지 않는 랜덤 위치에 배치. 상자(숨긴 조각)를 먼저 놓고 그 자리를 비켜간다.
func _scatter(rng: RandomNumberGenerator) -> void:
	var occ := {}
	# 압정: 완성 그림이 통째로 보드 안에 들어가는 위치(pic_origin)를 골라, 압정 조각들을 그 정답 자리에 rot=0 으로 고정한다.
	# 그림 전체가 보드 안이라 나머지 조각도 그 둘레 정답 자리에 모두 놓을 수 있어 → 클리어가 항상 가능하다.
	# 또한 압정 조각이 4방향 회전 내내 보드를 안 벗어나도록 여유까지 고려해 위치를 정한다.
	var pic_origin := _pick_pic_origin(rng)
	_place_tacks(pic_origin, occ)
	_place_boxes(rng, occ)
	var i := 0
	for g in groups:
		if g.boxed or g.tacked:
			continue
		g.set_rotation_index(rng.randi_range(0, 3))
		var r := g.allowed_off_range(board_w, board_h)
		var chosen := g.clamp_off(g.off, board_w, board_h)
		var ok := false
		for attempt in 60:
			var cand := Vector2i(
				rng.randi_range(r.position.x, r.position.x + r.size.x),
				rng.randi_range(r.position.y, r.position.y + r.size.y))
			if _cells_free(g, cand, occ):
				chosen = cand
				ok = true
				break
		if not ok:
			chosen = _free_off_in(g, chosen, occ)
		g.off = chosen
		for c in g.cells:
			occ[chosen + g.rel_cell(c, g.rot)] = true
		g.pop_in(i * INTRO_STAGGER)
		i += 1
	_reorder_by_depth()


# ---------- 상자 (조각을 숨겼다가 터치할 때마다 하나씩 날려 보낸다) ----------

## 레벨 설정의 boxes(예: [3,1])대로 상자별 "숨길 조각 묶음"을 짠다.
## 각 항목 N = box_N 상자 하나가 가장 작은 조각 N개를 숨긴다. 보드엔 최소 1개 조각을 남긴다.
## 조각이 모자라면 그 상자는 담을 수 있는 만큼만 담고(그림도 그 수로 바뀜), 더는 못 만들면 건너뛴다.
## 숨긴 조각은 안 보이게 하고 스냅 후보(cell_group)에서 뺀다. groups 에는 남겨 완성 판정을 막는다.
func _choose_boxed() -> void:
	_box_plan.clear()
	var specs: Array = _level_cfg(level_idx)["boxes"]
	if specs.is_empty():
		return
	# 크기 오름차순 정렬 → 가장 작은 조각들부터 숨긴다.
	var by_size := groups.duplicate()
	by_size.sort_custom(func(a: PuzzleGroup, b: PuzzleGroup) -> bool: return a.cells.size() < b.cells.size())
	var reserve := 1                       # 보드에 반드시 남길 최소 조각 수
	var taken := 0
	for want in specs:
		var take := mini(int(want), by_size.size() - reserve - taken)
		if take <= 0:
			break
		var bundle: Array[PuzzleGroup] = []
		for k in take:
			var g: PuzzleGroup = by_size[taken]
			taken += 1
			g.boxed = true
			g.visible = false
			for c in g.cells:
				cell_group.erase(c)
			bundle.append(g)
		_box_plan.append(bundle)


# ---------- 압정 (조각을 완성 위치에 고정 — 못 움직이고 압정칸을 축으로만 회전) ----------

## 레벨 설정의 tacks 수만큼, 상자에 안 든 조각 중에서 압정 조각을 고른다.
## 큰 조각부터(고정 앵커답게), 자유 조각은 최소 1개 남긴다(미리 풀린 판·손댈 조각 없음 방지).
## 여기선 대상 선택과 압정칸(tack_cell)만 정하고, 실제 고정 위치는 _place_tacks 에서 준다.
func _choose_tacked() -> void:
	var want := int(_level_cfg(level_idx).get("tacks", 0))
	if want <= 0:
		return
	var avail: Array[PuzzleGroup] = []
	for g in groups:
		if not g.boxed:
			avail.append(g)
	avail.sort_custom(func(a: PuzzleGroup, b: PuzzleGroup) -> bool: return a.cells.size() > b.cells.size())
	var take := mini(want, maxi(avail.size() - 1, 0))
	for k in take:
		var g: PuzzleGroup = avail[k]
		g.tacked = true
		g.tack_cell = _tack_pivot_cell(g)   # 회전 반경이 가장 작은 칸에 박아 4방향 회전에도 보드를 덜 벗어난다


## 압정 축으로 삼을 칸 = 회전 시 조각이 가장 적게 뻗치는 '체비쇼프 중심'(다른 모든 셀까지의 최대 체비쇼프 거리 R 최소).
## 이 R 이 곧 축을 기준으로 4방향 회전 시 조각이 사방으로 뻗는 최대 칸 수라, 배치 범위 계산(_pick_pic_origin)에 쓰인다.
## 동률이면 무게중심에 가까운 칸을 고른다.
func _tack_pivot_cell(g: PuzzleGroup) -> Vector2i:
	var ctr := Vector2.ZERO
	for c in g.cells:
		ctr += Vector2(c)
	ctr /= float(g.cells.size())
	var best := g.cells[0]
	var best_r := 1 << 30
	var best_d := INF
	for t in g.cells:
		var r := _tack_radius_for(g, t)
		var d := Vector2(t).distance_squared_to(ctr)
		if r < best_r or (r == best_r and d < best_d):
			best_r = r
			best_d = d
			best = t
	return best


## 조각 g 를 칸 t 를 축으로 회전할 때의 회전 반경 = 모든 셀까지의 최대 체비쇼프 거리.
func _tack_radius_for(g: PuzzleGroup, t: Vector2i) -> int:
	var r := 0
	for c in g.cells:
		r = maxi(r, maxi(absi(c.x - t.x), absi(c.y - t.y)))
	return r


## 완성 그림 좌상단(pic_origin) 위치를 정한다.
##  - 그림이 통째로 보드 안(클리어 가능) : pic_origin ∈ [0, board-puzzle].
##  - 모든 압정 조각이 4방향 회전 내내 보드 안 : 각 압정칸 보드위치 T=pic_origin+tack 가 [R, board-1-R] 안이도록 범위를 좁힌다.
## 두 조건을 함께 만족하는 범위가 있으면 그 안에서, 없으면(빡빡한 판) 그림-맞춤 범위로 폴백한다(그래도 rot=0 클리어는 가능).
func _pick_pic_origin(rng: RandomNumberGenerator) -> Vector2i:
	var lo := Vector2i.ZERO
	var hi := Vector2i(board_w - puzzle_w, board_h - puzzle_h)
	var clo := lo
	var chi := hi
	for g in groups:
		if not g.tacked:
			continue
		var t := g.tack_cell
		var r := _tack_radius_for(g, t)
		clo.x = maxi(clo.x, r - t.x)
		clo.y = maxi(clo.y, r - t.y)
		chi.x = mini(chi.x, board_w - 1 - r - t.x)
		chi.y = mini(chi.y, board_h - 1 - r - t.y)
	if clo.x <= chi.x and clo.y <= chi.y:
		lo = clo
		hi = chi
	return Vector2i(rng.randi_range(lo.x, hi.x), rng.randi_range(lo.y, hi.y))


## 압정 조각들을 pic_origin(완성 그림 좌상단)에 rot=0 으로 고정 배치한다.
## rot=0 이라 보드칸 = pic_origin + 정답셀 → 각 압정 조각은 서로 안 겹치는 정답 위치를 차지한다.
## 그림 전체가 보드 안(pic_origin 범위 보장)이라 이 배치는 항상 클리어 가능한 상태다.
func _place_tacks(pic_origin: Vector2i, occ: Dictionary) -> void:
	for g in groups:
		if not g.tacked:
			continue
		g.set_rotation_index(0)
		g.off = pic_origin
		for c in g.cells:
			occ[pic_origin + g.rel_cell(c, 0)] = true
		g.pop_in(0.0)
		# 압정칸의 보드 위치는 회전해도 고정(pivot 고정)이라, 여기에 안 돌아가는 핀을 한 번 꽂으면 끝.
		_spawn_pin(pic_origin + g.rel_cell(g.tack_cell, 0))


## 핀 텍스처(한 번 로드해 재사용). 없으면 null.
func _pin_texture() -> Texture2D:
	if _pin_tex == null and ResourceLoader.exists(PIN_PATH):
		_pin_tex = load(PIN_PATH)
	return _pin_tex


## 보드칸 bc 중앙에 핀 스프라이트를 세운다. pins_layer 소속이라 조각 회전과 무관하게 늘 똑바로 서 있다.
## 팁(뾰족한 끝, PIN_TIP)이 칸 중앙에 오도록 offset 을 잡는다. 톡 튀어나오는 팝 연출.
func _spawn_pin(bc: Vector2i) -> void:
	var tex := _pin_texture()
	if tex == null:
		return
	var pin := Sprite2D.new()
	pin.texture = tex
	pin.centered = false
	pin.offset = -PIN_TIP * tex.get_size()                  # 팁을 원점으로 (offset 은 스케일 전 텍셀 기준)
	var s := cell_px * PIN_H_FRAC / tex.get_height()
	pin.position = (Vector2(bc) + Vector2(0.5, 0.5)) * cell_px + PIN_NUDGE
	pins_layer.add_child(pin)
	pins.append(pin)
	# 조각 팝업에 맞춰 핀도 톡 꽂히듯 등장.
	pin.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_interval(0.12)
	t.tween_property(pin, "scale", Vector2(s, s), 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).from(Vector2.ZERO)


## _box_plan 의 각 묶음마다 상자 하나(1x1칸)를 빈 칸에 배치한다. 상자 그림(box_N)은 담은 조각 수로 정해진다.
func _place_boxes(rng: RandomNumberGenerator, occ: Dictionary) -> void:
	for bundle in _box_plan:
		if bundle.is_empty():
			continue
		var pos := _find_free_cell(occ, rng)
		var box := PuzzleBox.new()
		box.setup(cell_px)
		for g in bundle:
			box.add_payload(g)
		boxes_layer.add_child(box)
		box.place_at(pos)
		box.opened.connect(_on_box_opened)
		boxes.append(box)
		occ[pos] = true
		box.pop_in(0.0)


## occ 와 겹치지 않는 빈 보드칸(1x1)을 찾는다.
func _find_free_cell(occ: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	for attempt in 80:
		var o := Vector2i(rng.randi_range(0, board_w - 1), rng.randi_range(0, board_h - 1))
		if not occ.has(o):
			return o
	for y in board_h:
		for x in board_w:
			var o := Vector2i(x, y)
			if not occ.has(o):
				return o
	return Vector2i.ZERO


## 프레스 지점이 상자 위면 조각을 하나 꺼내고 true(입력 소비). 위에서부터(늦게 놓인 것부터) 검사.
func _try_peel_box(gp: Vector2) -> bool:
	for i in range(boxes.size() - 1, -1, -1):
		var b := boxes[i]
		if is_instance_valid(b) and b.contains_point(gp):
			b.peel()
			return true
	return false


## 상자가 3겹 다 부서지면 안의 모든 조각을 한꺼번에 방출한다.
## 각 조각은 상자 자리 근처 빈 칸으로 살짝 시차를 두고 날아가 안착한다(스냅/합체 복귀).
func _on_box_opened(box: PuzzleBox) -> void:
	boxes.erase(box)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var occ := _occupied_cells()
	var box_center := box.position + Vector2(box.cell_px, box.cell_px) * 0.5
	var k := 0
	for g in box.payload:
		g.boxed = false
		g.visible = true
		g.set_rotation_index(rng.randi_range(0, 3))
		for c in g.cells:
			cell_group[c] = g
		var chosen := _free_off_in(g, box.cell, occ)
		g.off = chosen
		for c in g.cells:
			occ[chosen + g.rel_cell(c, g.rot)] = true
		g.fly_from(box_center, k * 0.06)      # 한꺼번에 나오되 살짝 시차
		k += 1
	_reorder_by_depth()
	_update_float_states()


## 현재 보드에서 점유된 칸(보이는 조각 + 남은 상자 발자국).
func _occupied_cells() -> Dictionary:
	var occ := {}
	for g in groups:
		if g.boxed:
			continue
		for bc in g.board_cells():
			occ[bc] = true
	for b in boxes:
		if is_instance_valid(b):
			for bc in b.footprint_cells():
				occ[bc] = true
	return occ


## 상자를 즉시 열어 조각을 되돌린다(연출 없이). 테스트/즉시클리어에서 판을 정상화할 때.
func _force_open_boxes() -> void:
	for box in boxes:
		if not is_instance_valid(box):
			continue
		for g in box.payload:
			g.boxed = false
			g.visible = true
			for c in g.cells:
				cell_group[c] = g
		box.queue_free()
	boxes.clear()


# ---------- 입력 (드래그=이동 / 터치=회전) ----------

const TAP_MOVE_THRESH := 8.0

var _press_pos := Vector2.ZERO
var _dragging := false
var _pick_cell := Vector2i.ZERO       # 터치한 셀 (회전 축)


func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _try_peel_box(get_global_mouse_position()):
				return                          # 상자 터치는 조각 집기로 이어지지 않게 소비
			_press_pos = get_global_mouse_position()
			_dragging = false
			_pick(_press_pos)
		elif drag_group:
			var g := drag_group
			drag_group = null
			if _dragging:
				_drop(g)
			else:
				_tap_rotate(g)
	elif event is InputEventMouseMotion and drag_group:
		if drag_group.tacked:
			return                          # 압정 조각은 이동 불가 — 떼는 순간 탭(회전)으로만 처리된다
		if not _dragging and get_global_mouse_position().distance_to(_press_pos) > TAP_MOVE_THRESH:
			_dragging = true
			_update_float_states()          # 드래그 시작 → 뜬 상태
		if _dragging:
			drag_group.position = get_global_mouse_position() - board_origin + drag_offset
			_show_ghost()


func _pick(gp: Vector2) -> void:
	for i in range(groups_layer.get_child_count() - 1, -1, -1):
		var g := groups_layer.get_child(i) as PuzzleGroup
		if g and not g.boxed and g.contains_point(gp):
			drag_group = g
			_pick_cell = g.cell_at_point(gp)
			groups_layer.move_child(g, -1)
			drag_offset = g.position - (gp - board_origin)
			Sfx.play("pick")
			return


func _drop(g: PuzzleGroup) -> void:
	board_view.clear_ghost()
	var snap := _compute_snap(g)
	if snap.merge:
		g.snap_and_flash(snap.off)
		_resolve_merges(g)
	else:
		# 놓인 격자 위치에 그대로 둔다(겹침 허용). 겹치면 그 자리에 떠 있게 된다.
		g.set_off(snap.off, true)
		Sfx.play("place")
	_finish_move()


## 터치(제자리 클릭) → 터치한 칸을 축으로 90° 시계방향 회전.
## 겹침은 허용(떠오름으로 표현), 보드 밖으로만 안 나가게 클램프. 회전 후 같은 각도의 이웃과 맞으면 합체 시도.
func _tap_rotate(g: PuzzleGroup) -> void:
	board_view.clear_ghost()
	if g.tacked:
		_tap_rotate_tacked(g)
		return
	Sfx.play("rotate")
	var pivot := _pick_cell
	var pivot_bc := g.off + g.rel_cell(pivot, g.rot)    # 회전 전 축칸의 보드칸
	var pivot_center := (Vector2(pivot_bc) + Vector2(0.5, 0.5)) * g.cell_px  # 화면상 고정할 축 중앙
	g.bump_rotation()
	var new_off := pivot_bc - g.rel_cell(pivot, g.rot)  # 축칸을 제자리에 고정
	g.rotate_around(pivot, pivot_center, g.clamp_off(new_off, board_w, board_h))
	_resolve_merges(g)     # 회전한 상태로도 같은 각도의 이웃과 맞으면 합쳐진다
	_finish_move()


## 압정 조각 회전 — 압정칸을 축으로 돌되, 보드 밖으로 삐져나가는 자세는 건너뛰고 처음으로 완전히 보드 안에 드는
## 자세까지 90°씩 나아간다(합체로 커진 묶음이 가장자리에서 삐져나가는 걸 막는다). 어느 자세로도 못 들면 회전 무시.
## 압정칸 보드 위치는 어떤 경우에도 고정이라 압정은 절대 안 움직인다.
func _tap_rotate_tacked(g: PuzzleGroup) -> void:
	var pivot := g.tack_cell
	var pivot_bc := g.off + g.rel_cell(pivot, g.rot)
	var steps := 0
	for s in [1, 2, 3]:
		if _tacked_rot_in_board(g, s):
			steps = s
			break
	if steps == 0:
		return                                          # 유효한 자세 없음 → 그대로(현재 자세는 이미 보드 안)
	Sfx.play("rotate")
	var pivot_center := (Vector2(pivot_bc) + Vector2(0.5, 0.5)) * g.cell_px
	for _i in steps:
		g.bump_rotation()
	var new_off := pivot_bc - g.rel_cell(pivot, g.rot)  # 축칸을 제자리에 고정(클램프 안 함 → 압정 안 밀림)
	g.rotate_around(pivot, pivot_center, new_off, steps)
	_resolve_merges(g)
	_finish_move()


## 압정 조각 g 를 축(tack_cell)을 고정한 채 s 스텝(×90°) 돌렸을 때, 모든 칸이 보드 안이면 true.
func _tacked_rot_in_board(g: PuzzleGroup, s: int) -> bool:
	var pivot := g.tack_cell
	var pivot_bc := g.off + g.rel_cell(pivot, g.rot)
	var nr := posmod(g.rot + s, 4)
	var noff := pivot_bc - g.rel_cell(pivot, nr)
	for c in g.cells:
		var bc := noff + g.rel_cell(c, nr)
		if bc.x < 0 or bc.y < 0 or bc.x >= board_w or bc.y >= board_h:
			return false
	return true


func _finish_move() -> void:
	_reorder_by_depth()
	_update_float_states()
	_update_hud()
	if groups.size() == 1:
		groups[0].completed = true
		SaveData.mark_completed(level_idx)      # 완성한 스테이지 저장 → 타이틀 갤러리에 표시
		_win()


## 각 조각의 떠오름 상태 갱신.
## - 드래그 중인 조각: 항상 떠 있음.
## - 그 외: 스택에서 자기 아래(더 이전 자식)에 칸이 겹치는 조각이 있으면 떠 있음(위에 얹힘).
##   아래에 아무것도 없으면 부드럽게 내려앉는다.
func _update_float_states() -> void:
	var in_groups := {}
	for g in groups:
		in_groups[g] = true
	var order: Array[PuzzleGroup] = []
	for i in groups_layer.get_child_count():
		var g := groups_layer.get_child(i) as PuzzleGroup
		if g and in_groups.has(g) and not g.boxed:
			order.append(g)
	# 상자가 놓인 칸도 "다른 조각이 있는 칸"과 똑같이 취급한다.
	# 상자는 항상 조각보다 위 레이어라, 그 칸에 겹친 조각은 상자 위에 얹힌 것으로 보고 떠오른다.
	var box_cells := {}
	for b in boxes:
		if is_instance_valid(b):
			for bc in b.footprint_cells():
				box_cells[bc] = true
	for idx in order.size():
		var g := order[idx]
		if g == drag_group:
			g.set_lifted(true)
			continue
		var mine := {}
		for bc in g.board_cells():
			mine[bc] = true
		var on_top := false
		for bc in mine:
			if box_cells.has(bc):
				on_top = true
				break
		if not on_top:
			for lower in idx:
				var b := order[lower]
				if b == drag_group:
					continue
				for bc in b.board_cells():
					if mine.has(bc):
						on_top = true
						break
				if on_top:
					break
		g.set_lifted(on_top)


## 겹친 조각의 앞뒤(그리는 순서)를 보드 세로 위치로 정한다.
## 보드 아래쪽(= 화면에서 더 아래, y 가 큰) 조각일수록 자식 리스트의 뒤로 보내 위에(내 눈에 더 가깝게) 그린다.
## 자식 순서 = 그리는 순서라, 집기(_pick)·떠오름(_update_float_states)이 쓰는 순서와 항상 일치한다.
func _reorder_by_depth() -> void:
	var items: Array = []
	for i in groups_layer.get_child_count():
		var g := groups_layer.get_child(i) as PuzzleGroup
		if g != null and not g.boxed:      # 숨긴(상자 안) 조각은 깊이 정렬에서 제외 — 비가시라 뒤로 밀려나도 무방
			items.append({"g": g, "k": _depth_key(g), "i": i})
	# 깊이 키 오름차순, 동률이면 기존 순서 유지(안정 정렬)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["k"] == b["k"]:
			return a["i"] < b["i"]
		return a["k"] < b["k"])
	for i in items.size():
		groups_layer.move_child(items[i]["g"], i)


## 조각의 보드 세로 위치(점유칸 y 평균). 클수록 아래쪽 → 앞에 그린다.
func _depth_key(g: PuzzleGroup) -> float:
	var bcs := g.board_cells()
	if bcs.is_empty():
		return 0.0
	var s := 0.0
	for bc in bcs:
		s += bc.y
	return s / float(bcs.size())


## 드래그 중인 그룹이 놓일 위치를 계산. 같은 회전의 이웃과 정답 상대 위치로 맞으면 {off, merge=true}.
## 회전이 0이 아니어도 서로 같은 각도로 맞으면 합쳐진다.
func _compute_snap(g: PuzzleGroup) -> Dictionary:
	var cur := g.position
	var best_off: Variant = null
	var best_d := INF
	for s in g.cells:
		for d in DIRS:
			var nb: Vector2i = s + d
			if nb.x < 0 or nb.y < 0 or nb.x >= puzzle_w or nb.y >= puzzle_h:
				continue
			var h: PuzzleGroup = cell_group.get(nb)
			if h == null or h == g or h.boxed or h.rot != g.rot:
				continue
			# h 와 정답으로 맞물리려면 두 묶음의 anchor 가 같아야 한다 → 그 off 를 후보로.
			var cand := g.off_for_anchor(h.solution_anchor())
			var target := g.pose_position_for(cand, g.rot)
			var dd := cur.distance_to(target)
			if dd < best_d:
				best_d = dd
				best_off = cand
	if best_off != null and best_d <= snap_dist:
		return {"off": best_off, "merge": true}
	return {"off": g.clamp_off(g.off_from_position(), board_w, board_h), "merge": false}


func _show_ghost() -> void:
	var snap := _compute_snap(drag_group)
	var cells: Array[Vector2i] = drag_group.board_cells_at(snap.off)
	board_view.set_ghost(cells, snap.merge)


## g 와 같은 회전·기준점(anchor)을 가진 인접 그룹을 g 로 흡수(연쇄). 회전 상태에서도 동작. 흡수 지점에 파티클.
func _resolve_merges(g: PuzzleGroup) -> void:
	var changed := true
	var merged := 0
	while changed:
		changed = false
		for other in groups:
			if other == g or other.boxed or other.rot != g.rot or other.solution_anchor() != g.solution_anchor():
				continue
			if g.is_adjacent_to(other):
				var moved: Array[Vector2i] = other.cells.duplicate()
				_spawn_merge_particles(_seam_center_world(g, moved))
				# 합칠 때마다 음정을 반음씩 올려 연쇄가 상승하는 콤보로 들리게 한다.
				Sfx.play_pitched("snap", 1.0 + 0.06 * mini(merged, 6))
				merged += 1
				# 압정 조각을 흡수하면 합쳐진 묶음도 압정으로 고정된다(고정 위치·회전축 유지). anchor 가 같아 압정칸은 제자리.
				if other.tacked and not g.tacked:
					g.tacked = true
					g.tack_cell = other.tack_cell
				g.absorb(moved)
				for c in moved:
					cell_group[c] = g
				groups.erase(other)
				other.queue_free()
				changed = true
				break


# ---------- 초기 배치용 겹침 회피 (시작 시 조각이 서로 포개지지 않게) ----------

func _cells_free(g: PuzzleGroup, o: Vector2i, occ: Dictionary) -> bool:
	for c in g.cells:
		if occ.has(o + g.rel_cell(c, g.rot)):
			return false
	return true


## desired 에서 시작해 occ(이미 배치된 조각 점유칸)와 겹치지 않는 가장 가까운 off 를 찾는다.
func _free_off_in(g: PuzzleGroup, desired: Vector2i, occ: Dictionary) -> Vector2i:
	var d := g.clamp_off(desired, board_w, board_h)
	if _cells_free(g, d, occ):
		return d
	for radius in range(1, maxi(board_w, board_h) + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var o := Vector2i(d.x + dx, d.y + dy)
				if g.clamp_off(o, board_w, board_h) == o and _cells_free(g, o, occ):
					return o
	return d


# ---------- 파티클 (조각이 맞춰질 때) ----------

## 흡수되는 셀(moved)과 기존 그룹 g 가 맞닿는 경계(맞물리는 부분)의 중점(화면 좌표, 회전 반영).
## g 의 자세(off/rot)로 정답 좌표계 점을 실제 화면 위치에 매핑하므로 회전 상태에서도 정확하다.
func _seam_center_world(g: PuzzleGroup, moved: Array[Vector2i]) -> Vector2:
	var s := Vector2.ZERO
	var cnt := 0
	for c in moved:
		for d in DIRS:
			if g.cell_set.has(c + d):
				s += g.solution_to_board_px(Vector2(c) + Vector2(0.5, 0.5) + Vector2(d) * 0.5)
				cnt += 1
	if cnt == 0:
		var ctr := Vector2.ZERO
		for c in moved:
			ctr += Vector2(c) + Vector2(0.5, 0.5)
		return board_origin + g.solution_to_board_px(ctr / float(moved.size()))
	return board_origin + s / float(cnt)


## 둥근 흰색 파티클 텍스처 (중심 흰색 → 가장자리 투명). 한 번만 생성해 재사용.
func _get_particle_tex() -> Texture2D:
	if _particle_tex != null:
		return _particle_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_particle_tex = gt
	return gt


func _spawn_merge_particles(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 30
	p.one_shot = true
	p.texture = _get_particle_tex()
	p.explosiveness = 0.95
	p.amount = 18
	p.lifetime = 0.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = cell_px * 0.25
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 200.0
	# 텍스처(128px) 기준 스케일 — 훨씬 큰 둥근 파티클
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.85
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	p.color_ramp = ramp
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = sc
	add_child(p)
	p.emitting = true
	var t := get_tree().create_timer(p.lifetime + 0.4)
	t.timeout.connect(p.queue_free)


# ---------- 보드 분할 (레벨별 piece 크기 범위의 폴리오미노) ----------

func _partition(w: int, h: int, pmin: int, pmax: int, rng: RandomNumberGenerator) -> Array:
	var owner := {}
	var regions: Array = []
	var order: Array = []
	for y in h:
		for x in w:
			order.append(Vector2i(x, y))
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for cell0 in order:
		if owner.has(cell0):
			continue
		var idx := regions.size()
		var region: Array = [cell0]
		owner[cell0] = idx
		var target := rng.randi_range(pmin, pmax)
		while region.size() < target:
			var frontier: Array = []
			for c in region:
				for d in DIRS:
					var nb: Vector2i = c + d
					if nb.x >= 0 and nb.y >= 0 and nb.x < w and nb.y < h \
							and not owner.has(nb) and not frontier.has(nb):
						frontier.append(nb)
			if frontier.is_empty():
				break
			var pick: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
			owner[pick] = idx
			region.append(pick)
		regions.append(region)
	# 조각 크기는 pmin~pmax 목표. 자투리(작은 조각)는 그대로 둔다(상자가 숨길 후보).
	return regions


# ---------- 클리어 ----------

## 완성 → 팝업이 아니라 완성 그림이 보드에서 떠올라 중앙에서 커지며 보여준다.
## 회전한 상태로 완성했다면, 완성 그림이 그 각도에서 시작해 똑바로 회전하며 떠오른다.
func _win() -> void:
	busy = true
	Sfx.play("win")
	var g := groups[0]
	var last := level_idx == level_textures.size() - 1
	var rect := Vector2(puzzle_w, puzzle_h) * cell_px    # 완성 그림의 실제 크기(비정사각 가능)

	# 완성 시점의 회전각(짧은 쪽으로 정규화) — 0이면 회전 없이 기존과 동일.
	var start_angle := deg_to_rad(g.rot * 90.0)
	if start_angle > PI:
		start_angle -= TAU
	# 보드 위 완성 그림의 화면 중심 — 리저가 그 자리·그 각도에서 시작한다(회전 반영).
	var start_center := board_origin + g.solution_to_board_px(Vector2(puzzle_w, puzzle_h) * 0.5)

	# 리저를 이 레벨 격자 크기·비율에 맞춘다.
	riser.size = rect
	riser.pivot_offset = rect * 0.5
	riser_shadow.size = rect + Vector2(20, 20)
	riser_pic.texture = cur_tex
	# 이미지 라운드 반경을 이 레벨 크기에 맞추고, 뒤 그림자도 같은 라운드로.
	var img_radius := minf(rect.x, rect.y) * 0.08
	var pm := riser_pic.material as ShaderMaterial
	pm.set_shader_parameter("size_px", rect)
	pm.set_shader_parameter("radius_px", img_radius)
	var ssb := riser_shadow.get_theme_stylebox("panel") as StyleBoxFlat
	ssb.set_corner_radius_all(int(round(img_radius)))
	riser.scale = Vector2.ONE
	riser.rotation = start_angle
	riser.position = start_center - riser.pivot_offset
	dim.color.a = 0.0
	overlay_btn.text = "메뉴로" if last else "다음"
	overlay_btn.modulate.a = 0.0
	overlay.visible = true

	# 완성된 판을 잠깐 그대로 보여준 뒤, 실제 조각을 감추고 그림이 (회전하며) 떠오른다
	await get_tree().create_timer(0.35).timeout
	groups_layer.visible = false
	pins_layer.visible = false

	var target_center := Vector2(VIEW_W * 0.5, VIEW_H * 0.44)
	var final_size := 480.0
	var target_scale := final_size / maxf(rect.x, rect.y)   # 긴 변을 480에 맞춰 비율 유지
	var target_pos := target_center - rect * 0.5

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", 0.62, 0.45)
	tw.tween_property(riser, "position", target_pos, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(riser, "scale", Vector2(target_scale, target_scale), 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not is_equal_approx(start_angle, 0.0):
		tw.tween_property(riser, "rotation", 0.0, 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

	create_tween().tween_property(overlay_btn, "modulate:a", 1.0, 0.25)

	# 다 떠오른 뒤 살짝 둥실둥실
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(riser, "position:y", target_pos.y - 8.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(riser, "position:y", target_pos.y + 8.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 완성 후 "다음" — 로비로 나가서, 방금 깬 그림의 완성 연출을 보여준 뒤 다음으로 스크롤한다.
func _on_next() -> void:
	SaveData.just_completed = level_idx
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	overlay_btn.disabled = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))


func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


## 부드러운 크림색 버튼 — 둥근 모서리 + 은은한 드롭 섀도우, 진한 테두리 없음.
## radius: 모서리 반경(높이의 절반이면 완전한 원/알약). muted: 개발용 등 눈에 덜 띄는 반투명 버전.
func _style_soft_button(btn: Button, radius: int, muted: bool = false) -> void:
	var ink := Color("46382b")
	var base := Color("fbf4e4")                        # 따뜻한 오프화이트(크림)
	var sh_a := 0.10 if muted else 0.22
	var sh_sz := 3 if muted else 6
	var sh_off := 2 if muted else 4
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(base.r, base.g, base.b, 0.55) if muted else base
	bn.set_corner_radius_all(radius)
	bn.shadow_color = Color(0.27, 0.22, 0.16, sh_a)
	bn.shadow_size = sh_sz
	bn.shadow_offset = Vector2(0, sh_off)
	bn.content_margin_left = 12
	bn.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", bn)
	var bh: StyleBoxFlat = bn.duplicate()
	bh.bg_color = Color("fffdf5")                       # 호버: 더 밝게
	btn.add_theme_stylebox_override("hover", bh)
	var bp: StyleBoxFlat = bn.duplicate()
	bp.bg_color = Color("efe4c9")                       # 눌림: 살짝 어둡게 + 그림자 축소
	bp.shadow_size = maxi(sh_sz - 3, 0)
	bp.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("pressed", bp)
	btn.add_theme_color_override("font_color", Color(ink, 0.72) if muted else ink)
	btn.add_theme_color_override("font_hover_color", ink)
	btn.add_theme_color_override("font_pressed_color", ink)
	btn.focus_mode = Control.FOCUS_NONE


## 좌향(뒤로가기) 화살표 아이콘을 버튼 위에 벡터로 그린다.
## 폰트에 화살표 글리프가 없어 깨지는 걸 피하려고 Line2D 로 또렷하게 직접 그린다.
## 버튼 로컬 좌표(0..size)에 화살촉(<)과 샤프트(—)를 그려 좌우·상하 중앙에 맞춘다.
func _add_back_arrow_icon(btn: Button) -> void:
	var ink := Color("46382b")
	var w := btn.size.x
	var cx := w * 0.5
	var arm := w * 0.16          # 화살촉 팔 길이
	var half := w * 0.20         # 샤프트 절반 길이
	var tip := Vector2(cx - half, cx)
	var head := Line2D.new()     # 화살촉 "<"
	head.points = PackedVector2Array([
		Vector2(tip.x + arm, cx - arm), tip, Vector2(tip.x + arm, cx + arm)])
	var shaft := Line2D.new()    # 샤프트 "—"
	shaft.points = PackedVector2Array([tip, Vector2(cx + half, cx)])
	for ln in [head, shaft]:
		ln.width = maxf(w * 0.09, 4.0)
		ln.default_color = ink
		ln.antialiased = true
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.z_index = 1
		btn.add_child(ln)


# ---------- 밸런스 점검 (godot --headless --path . -- --balance) ----------

## 레벨 밸런스 표를 콘솔에 출력한다. 각 레벨의 격자/보드/조각크기와,
## 그에 따른 조각 수 범위·상자가 숨기는 수·경고(보드<격자, 상자>조각, 보드빽빽)를 보여준다.
func _report_balance() -> void:
	print("=== 레벨 밸런스 표 (LEVELS %d개) ===" % LEVELS.size())
	print(" lv | grid   칸 | board | piece | 조각수  | boxes        숨김 | 압정 | 경고")
	for i in LEVELS.size():
		var c := LEVELS[i]
		var g: Vector2i = c["grid"]
		var b: Vector2i = c["board"]
		var p: Vector2i = c["piece"]
		var bx: Array = c["boxes"]
		var tk := int(c.get("tacks", 0))
		var cells := g.x * g.y
		var min_pieces := int(ceili(float(cells) / float(p.y)))    # 조각이 가장 클 때 = 가장 적을 때
		var max_pieces := mini(cells, int(ceili(float(cells) / float(p.x))))
		var hide := 0
		for n in bx:
			hide += int(n)
		var warn := ""
		if b.x < g.x or b.y < g.y:
			warn += "보드<격자! "
		# 상자(hide) + 압정(자유 조각 1개 예약) + 보드에 남길 1개 ≤ 최소 조각 수 여야 정상 배치된다.
		if hide + tk + 1 > min_pieces:
			warn += "상자+압정>조각! "
		if float(cells + bx.size()) > float(b.x * b.y) * 0.7:
			warn += "보드빽빽 "
		# 압정은 완성 그림을 보드 안(pic_origin 범위)에 통째로 두므로 board≥grid 이면 항상 클리어 가능.
		if tk > 0 and (b.x < g.x or b.y < g.y):
			warn += "압정클리어불가! "
		print("%3d | %dx%d %4d | %2dx%-2d | %d~%d   | %2d~%-2d | %-12s → %d | %3d | %s" % [
			i + 1, g.x, g.y, cells, b.x, b.y, p.x, p.y,
			min_pieces, max_pieces, str(bx), hide, tk, warn])


# ---------- 자체 검증 (godot --path . -- --test) ----------

func _run_self_test() -> void:
	var ok := true
	var total_cells := puzzle_w * puzzle_h
	_force_open_boxes()          # 상자에 숨긴 조각을 되돌려 이하 검증을 상자와 무관하게 만든다
	# 1) 셀 총합 = 격자칸수, 그룹은 여러 개, 시작부터 완성 아님
	var sum := 0
	for g in groups:
		sum += g.cells.size()
	print("[test] groups=%d cells=%d (expect %d)" % [groups.size(), sum, total_cells])
	ok = ok and sum == total_cells and groups.size() > 1

	# 1.5) 압정 조각은 압정칸 축으로 4방향 회전해도 절대 보드를 벗어나지 않는다(이 레벨의 실제 배치·축 선택 검증).
	var n_tacked := 0
	var tack_in_board := true
	for g in groups:
		if not g.tacked:
			continue
		n_tacked += 1
		var base_off := g.off
		var base_rot := g.rot
		for _r in 4:
			var pbc := g.off + g.rel_cell(g.tack_cell, g.rot)      # _tap_rotate 와 동일: 축칸 보드위치 고정 회전
			g.set_rotation_index(g.rot + 1)
			g.off = pbc - g.rel_cell(g.tack_cell, g.rot)
			for bc in g.board_cells():
				if bc.x < 0 or bc.y < 0 or bc.x >= board_w or bc.y >= board_h:
					tack_in_board = false
		g.set_rotation_index(base_rot)
		g.off = base_off
	print("[test] tacked(%d) stay in board across rotations: %s" % [n_tacked, tack_in_board])
	ok = ok and tack_in_board

	# 2) 모든 조각 크기 1~4
	var size_ok := true
	for g in groups:
		if g.cells.size() < 1 or g.cells.size() > 4:
			size_ok = false
	print("[test] piece sizes 1..4: %s" % size_ok)
	ok = ok and size_ok

	# 3) 회전 4번 → 점유칸 원상복귀
	var g0 := groups[0]
	var base := _sorted_cells(g0.board_cells())
	for k in 4:
		g0.set_rotation_index(g0.rot + 1)
	var rt_ok := _sorted_cells(g0.board_cells()) == base
	print("[test] rotate x4 identity: %s" % rt_ok)
	ok = ok and rt_ok

	# 4) off_from_position 왕복 (각 회전에서 위치→off 복원)
	var fp_ok := true
	for rr in 4:
		g0.set_rotation_index(rr)
		g0.off = Vector2i(2, 1)
		g0.apply_pose(false)
		if g0.off_from_position() != Vector2i(2, 1):
			fp_ok = false
	print("[test] off_from_position round-trip: %s" % fp_ok)
	ok = ok and fp_ok

	# 4.5) 떠오름 스택: 두 조각을 강제로 겹치면 위(자식 뒤)만 뜨고 아래는 바닥
	if groups.size() >= 2:
		var a := groups[0]
		var b := groups[1]
		a.set_rotation_index(0)
		b.set_rotation_index(0)
		a.off = Vector2i(1000, 1000)                # 다른 조각(상자 되돌림 더미·압정 등)과 안 겹치는 외딴 곳으로 격리
		b.off = a.off + (a.cells[0] - b.cells[0])   # b 의 첫 셀이 a 의 첫 셀 보드칸에 겹침
		groups_layer.move_child(b, -1)              # b 를 스택 맨 위로
		_update_float_states()
		var stack_ok := b._lift_up and not a._lift_up
		print("[test] float stack (top lifted, bottom grounded): %s" % stack_ok)
		ok = ok and stack_ok
		# 겹침 해제하면 둘 다 내려감
		b.off = a.off + Vector2i(50, 50)
		_update_float_states()
		var settle_ok := not b._lift_up and not a._lift_up
		print("[test] float settle (no overlap → grounded): %s" % settle_ok)
		ok = ok and settle_ok

	# 4.7) 회전 병합: 같은 rot(1)·같은 anchor 인 두 조각이 맞물리고, 흡수 후 보드칸이 보존된다
	var ra: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var rb: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1)]
	var ga := PuzzleGroup.new()
	ga.init(ra, Vector2i(3, 3), cell_px, Vector2(cell_px, cell_px), cur_tex)
	ga.set_rotation_index(1)
	var gb := PuzzleGroup.new()
	gb.init(rb, Vector2i.ZERO, cell_px, Vector2(cell_px, cell_px), cur_tex)
	gb.set_rotation_index(1)
	gb.off = gb.off_for_anchor(ga.solution_anchor())     # ga 와 같은 anchor 로 맞춘다
	var rot_before := {}
	for bc in ga.board_cells():
		rot_before[bc] = true
	for bc in gb.board_cells():
		rot_before[bc] = true
	var rot_fit_ok := ga.solution_anchor() == gb.solution_anchor() and ga.is_adjacent_to(gb) \
			and rot_before.size() == ga.cells.size() + gb.cells.size()   # 겹침 없음
	ga.absorb(gb.cells)
	var rot_keep := ga.board_cells().size() == rot_before.size()
	for bc in ga.board_cells():
		if not rot_before.has(bc):
			rot_keep = false
	print("[test] rotated merge (anchor fit + absorb keeps cells): %s" % (rot_fit_ok and rot_keep))
	ok = ok and rot_fit_ok and rot_keep
	ga.free()
	gb.free()

	# 5) 모든 그룹 회전 0 + 같은 off 정렬 → resolve 하면 1묶음
	for g in groups:
		g.set_rotation_index(0)
	var target := groups[0].off
	for g in groups:
		g.off = target
	_resolve_merges(groups[0])
	print("[test] after solve groups=%d (expect 1)" % groups.size())
	ok = ok and groups.size() == 1

	# 6) 완성 묶음이 모든 셀을 정확히 보유
	if groups.size() == 1:
		var s2 := groups[0].cells.size()
		print("[test] final cells=%d (expect %d)" % [s2, total_cells])
		ok = ok and s2 == total_cells

	# 7) clamp_off 가 범위를 벗어나지 않는지
	var r := groups[0].allowed_off_range(board_w, board_h)
	var c := groups[0].clamp_off(Vector2i(999, -999), board_w, board_h)
	var in_range := c.x >= r.position.x and c.x <= r.position.x + r.size.x \
			and c.y >= r.position.y and c.y <= r.position.y + r.size.y
	print("[test] clamp %s in_range=%s" % [c, in_range])
	ok = ok and in_range

	# 8) 상자: 3겹 → 3번 타격해야 열리고, 열릴 때 안의 모든 조각(3개)이 그대로 payload 에 담겨 있다. 1x1 칸.
	var tb := PuzzleBox.new()
	tb.setup(cell_px)                          # 기본 3겹
	add_child(tb)
	tb.place_at(Vector2i.ZERO)
	var opened_n := [0]
	tb.opened.connect(func(_b: PuzzleBox) -> void: opened_n[0] += 1)
	for _i in 3:
		var pg := PuzzleGroup.new()
		var pcells: Array[Vector2i] = [Vector2i(0, 0)]
		pg.init(pcells, Vector2i.ZERO, cell_px, Vector2(cell_px, cell_px), cur_tex)
		tb.add_payload(pg)
	var full_ok := tb.count() == 3 and tb.layers == 3
	tb.peel()
	tb.peel()
	var mid_ok: bool = opened_n[0] == 0 and tb.layers == 1     # 2번 타격 — 아직 안 열림
	tb.peel()
	var open_ok: bool = opened_n[0] == 1 and tb.layers == 0 and tb.count() == 3   # 3번째에 열리고 payload 유지
	var foot_ok := tb.footprint_cells().size() == 1            # 1x1 칸 차지
	print("[test] box 3-hit opens & keeps payload: %s / 1x1: %s" % [full_ok and mid_ok and open_ok, foot_ok])
	ok = ok and full_ok and mid_ok and open_ok and foot_ok

	# 9) 압정 축 고정: 압정칸을 축으로 한 회전은 압정칸의 보드 위치를 4회전 내내 고정한다(_tap_rotate 축 계산 재현).
	var tg := groups[0]
	tg.set_rotation_index(0)
	tg.off = Vector2i(2, 2)
	tg.tacked = true
	tg.tack_cell = tg.cells[tg.cells.size() / 2]
	var tack_bc := tg.off + tg.rel_cell(tg.tack_cell, tg.rot)
	var tack_fixed := true
	for _k in 4:
		var pbc := tg.off + tg.rel_cell(tg.tack_cell, tg.rot)
		tg.bump_rotation()
		tg.off = pbc - tg.rel_cell(tg.tack_cell, tg.rot)
		if tg.off + tg.rel_cell(tg.tack_cell, tg.rot) != tack_bc:
			tack_fixed = false
	print("[test] tack pivot stays fixed under rotation: %s" % tack_fixed)
	ok = ok and tack_fixed
	tg.tacked = false
	tg.set_rotation_index(0)

	# 10) 압정 클리어 가능성: 완성 그림을 pic_origin(보드-격자 범위) 어디에 둬도 모든 칸이 보드 안에 들어온다.
	var solvable := true
	for oy in [0, board_h - puzzle_h]:
		for ox in [0, board_w - puzzle_w]:
			for gy in puzzle_h:
				for gx in puzzle_w:
					var bc := Vector2i(ox + gx, oy + gy)
					if bc.x < 0 or bc.y < 0 or bc.x >= board_w or bc.y >= board_h:
						solvable = false
	print("[test] tack picture fits in board (solvable): %s" % solvable)
	ok = ok and solvable

	# 11) 압정 병합 전파: 자유 조각이 압정 조각을 흡수하면 결과 묶음도 압정으로 남고 압정칸을 보존한다.
	var saved_groups := groups
	var saved_cg := cell_group
	groups = []
	cell_group = {}
	var free_g := PuzzleGroup.new()
	var fcells: Array[Vector2i] = [Vector2i(0, 0)]
	free_g.init(fcells, Vector2i(2, 2), cell_px, Vector2(cell_px, cell_px), cur_tex)
	groups_layer.add_child(free_g)
	groups.append(free_g)
	var tack_g := PuzzleGroup.new()
	var tcells: Array[Vector2i] = [Vector2i(1, 0)]
	tack_g.init(tcells, Vector2i(2, 2), cell_px, Vector2(cell_px, cell_px), cur_tex)
	tack_g.tacked = true
	tack_g.tack_cell = Vector2i(1, 0)
	groups_layer.add_child(tack_g)
	groups.append(tack_g)
	_resolve_merges(free_g)                        # 자유 조각 free_g 가 인접·동일 anchor 인 압정 조각을 흡수
	var prop_ok := groups.size() == 1 and groups[0].tacked \
			and groups[0].tack_cell == Vector2i(1, 0) and groups[0].cell_set.has(Vector2i(1, 0))
	print("[test] tack merge propagation: %s" % prop_ok)
	ok = ok and prop_ok
	for g in groups:
		g.queue_free()
	groups = saved_groups
	cell_group = saved_cg

	# 12) 압정 회전 스킵: 보드 밖으로 나가는 자세는 건너뛴다. 맨 윗줄의 가로줄은 90°(세로)면 y=-1 로 삐져 → 스킵, 180°는 OK.
	var line_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var lg := PuzzleGroup.new()
	lg.init(line_cells, Vector2i.ZERO, cell_px, Vector2(cell_px, cell_px), cur_tex)
	lg.tacked = true
	lg.tack_cell = Vector2i(1, 0)
	lg.set_rotation_index(0)
	lg.off = Vector2i(1, 0)                             # 축칸 보드위치 (2,0) — 맨 윗줄
	var skip_ok := (not _tacked_rot_in_board(lg, 1)) and _tacked_rot_in_board(lg, 2)
	print("[test] tacked rotation skips off-board pose: %s" % skip_ok)
	ok = ok and skip_ok
	lg.free()

	print("[test] RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _sorted_cells(cs: Array[Vector2i]) -> Array:
	var a: Array = []
	for c in cs:
		a.append([c.x, c.y])
	a.sort()
	return a


# ---------- UI ----------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)

	var theme := Theme.new()
	var f: Font = load("res://assets/fonts/BMJUA_ttf.ttf")
	if f:
		theme.default_font = f
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", Color("4a3a28"))

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	ui.add_child(root)

	# 맨 위: 레벨 표시 — 부드러운 크림색 알약(pill) 안에 (레퍼런스의 "LEVEL / 4:52" 느낌)
	var pill_w := 200.0
	var pill_h := 56.0
	var level_pill := Panel.new()
	level_pill.position = Vector2((VIEW_W - pill_w) * 0.5, 20)
	level_pill.size = Vector2(pill_w, pill_h)
	level_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lps := StyleBoxFlat.new()
	lps.bg_color = Color("fbf4e4")
	lps.set_corner_radius_all(int(pill_h * 0.5))
	lps.shadow_color = Color(0.27, 0.22, 0.16, 0.22)
	lps.shadow_size = 6
	lps.shadow_offset = Vector2(0, 4)
	level_pill.add_theme_stylebox_override("panel", lps)
	root.add_child(level_pill)

	hud_level = Label.new()
	hud_level.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_level.add_theme_font_size_override("font_size", 28)
	hud_level.add_theme_color_override("font_color", Color("46382b"))
	hud_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_pill.add_child(hud_level)

	# 왼쪽 상단: 뒤로가기(타이틀로) — 크림색 원형 + 벡터 화살표 아이콘
	var back_btn := Button.new()
	back_btn.position = Vector2(22, 18)
	back_btn.size = Vector2(56, 56)
	_style_soft_button(back_btn, 28)
	back_btn.pressed.connect(_on_back)
	root.add_child(back_btn)
	_add_back_arrow_icon(back_btn)

	# 완성 연출: 어둡게 깔고 → 완성 그림이 보드에서 떠올라 중앙에서 커진다
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root.add_child(overlay)

	dim = ColorRect.new()
	dim.color = Color(0.10, 0.07, 0.04, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	# 실제 크기·비율은 완성 시(_win)에 레벨 격자에 맞춰 정한다. 여기선 임시값.
	var rsize := 480.0
	riser = Control.new()
	riser.size = Vector2(rsize, rsize)
	riser.pivot_offset = Vector2(rsize, rsize) * 0.5
	riser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(riser)

	riser_shadow = Panel.new()
	riser_shadow.position = Vector2(-10, 22)
	riser_shadow.size = Vector2(rsize + 20, rsize + 20)
	riser_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.08, 0.05, 0.02, 0.35)
	ss.set_corner_radius_all(24)
	riser_shadow.add_theme_stylebox_override("panel", ss)
	riser.add_child(riser_shadow)

	# 완성 그림 — 테두리/빽판 없이 이미지 자체를 둥근 모서리로 클리핑한다.
	riser_pic = TextureRect.new()
	riser_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	riser_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	riser_pic.stretch_mode = TextureRect.STRETCH_SCALE
	riser_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic_shader := Shader.new()
	pic_shader.code = "shader_type canvas_item;\n" + \
		"uniform vec2 size_px = vec2(480.0);\n" + \
		"uniform float radius_px = 36.0;\n" + \
		"void fragment() {\n" + \
		"	vec2 h = size_px * 0.5;\n" + \
		"	vec2 p = UV * size_px - h;\n" + \
		"	vec2 q = abs(p) - h + radius_px;\n" + \
		"	float d = min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius_px;\n" + \
		"	float aa = max(fwidth(d), 0.0001);\n" + \
		"	float a = 1.0 - smoothstep(-aa, aa, d);\n" + \
		"	vec4 t = texture(TEXTURE, UV);\n" + \
		"	COLOR = vec4(t.rgb, t.a * a);\n" + \
		"}\n"
	var pic_mat := ShaderMaterial.new()
	pic_mat.shader = pic_shader
	riser_pic.material = pic_mat
	riser.add_child(riser_pic)

	# 완성 후 다음/재시작 버튼 — 부드러운 크림색 알약
	overlay_btn = Button.new()
	overlay_btn.size = Vector2(180, 56)
	overlay_btn.position = Vector2((VIEW_W - 180) * 0.5, VIEW_H * 0.82)
	_style_soft_button(overlay_btn, 28)
	overlay_btn.add_theme_font_size_override("font_size", 28)
	overlay_btn.pressed.connect(_on_next)
	overlay.add_child(overlay_btn)

	# 컷 전환용 페이드 — 씬 진입 시 어두운 색에서 서서히 걷힌다(메뉴의 페이드아웃과 이어짐).
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = FADE_COL
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)


## 씬이 시작될 때 페이드를 걷어낸다(페이드인).
func _fade_in() -> void:
	if _fade == null:
		return
	create_tween().tween_property(_fade, "color:a", 0.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_hud() -> void:
	hud_level.text = "레벨  %d" % (level_idx + 1)
