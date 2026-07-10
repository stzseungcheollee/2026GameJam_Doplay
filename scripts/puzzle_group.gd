class_name PuzzleGroup
extends Node2D

## 하나 이상의 조각이 뭉쳐진 묶음.
## cells 는 "정답(그림) 격자 좌표" 목록이며, 묶음 안에서는 항상 정답과 같은 상대 배치를 유지한다.
## rot(0~3, 90° 단위 시계방향)로 회전할 수 있고, 서로 같은 rot·같은 anchor(정답 기준점)일 때 이웃과 합쳐진다.
## 회전한 상태로도 두 묶음이 같은 각도로 정확히 맞으면 합체된다.
## boardCell(그리드 점유칸) = off + rel_cell(solutionCell, rot) = solution_anchor + _rot_lin(solutionCell, rot).

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var cells: Array[Vector2i] = []
var cell_set: Dictionary = {}
var off := Vector2i.ZERO
var rot := 0                       # 0~3, 90° 시계방향 회전 수
var boxed := false                 # 상자 안에 숨겨진 상태 (입력/스냅/합체/떠오름에서 제외)
var cell_px := 75.0
var src_cell := Vector2.ZERO
var tex: Texture2D
var cmin := Vector2i.ZERO
var cmax := Vector2i.ZERO

var completed := false:
	set(v):
		completed = v
		queue_redraw()

var _outline := PackedVector2Array()       # 날카로운 외곽선(셀 격자)
var _round := PackedVector2Array()         # 둥근 외곽선(미완성 조각용)
var _outline_ring := PackedVector2Array()  # 테두리/두께용으로 바깥으로 확장한 날카로운 외곽선
var _round_ring := PackedVector2Array()    # 위와 동일(둥근 버전)
var _outline_w := 3.0                       # 실제 테두리 두께(px) = cell_px * OUTLINE_FRAC
var _depth := 5.0                           # 실제 두께(px) = cell_px * DEPTH_FRAC
var _tween: Tween
var _vis_angle := 0.0                       # 회전 트윈용 연속 각도(라디안)

var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()

# 떠오름(공중에 뜬 상태) 표현 — 0=바닥, 1=떠있음. 그림자로 높이를 나타낸다.
const LIFT_MOVE := Vector2(-3.0, -13.0)    # 뜰 때 조각이 화면에서 이동하는 방향(위-왼쪽)
const SHADOW_MOVE := Vector2(7.0, 15.0)    # 그림자가 바닥에서 벌어지는 방향(아래-오른쪽)
const SHADOW_ALPHA := 0.30

# 외곽선 + 두께(입체감). 값은 cell_px 비율로 스케일해 레벨별 칸 크기와 무관하게 일정하게 보인다.
const OUTLINE_FRAC := 0.05      # 밝은 테두리 두께 = cell_px * 이 값
const DEPTH_FRAC := 0.085       # 조각 두께(아래로 보이는 옆면 높이) = cell_px * 이 값
const RIM_COL := Color("fdf6e6")    # 밝은 크림 테두리
const SIDE_COL := Color("b58f5d")   # 두께(옆면) — 따뜻한 갈색 그림자

var lift := 0.0:
	set(v):
		lift = v
		queue_redraw()
var _lift_up := false
var _lift_tween: Tween


func init(p_cells: Array[Vector2i], p_off: Vector2i, p_cell_px: float, p_src_cell: Vector2, p_tex: Texture2D) -> void:
	cells = p_cells.duplicate()
	off = p_off
	cell_px = p_cell_px
	src_cell = p_src_cell
	tex = p_tex
	_recompute()
	rotation = _vis_angle
	position = _pose_position(rot)


func _recompute() -> void:
	cell_set.clear()
	var mn := Vector2i(9999, 9999)
	var mx := Vector2i(-9999, -9999)
	for c in cells:
		cell_set[c] = true
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	cmin = mn
	cmax = mx
	_outline = _trace_outline()
	_round = _round_corners(_outline)
	_outline_w = cell_px * OUTLINE_FRAC
	_depth = cell_px * DEPTH_FRAC
	_outline_ring = _expand_ring(_outline)
	_round_ring = _expand_ring(_round)


func absorb(other_cells: Array[Vector2i]) -> void:
	var anchor := solution_anchor()      # 흡수 전 기준점 — 회전 상태에서도 배치가 어긋나지 않게 보존
	for c in other_cells:
		if not cell_set.has(c):
			cells.append(c)
	_recompute()                          # cmin/cmax 가 바뀌므로 off 를 재조정해 anchor 를 유지한다
	off = off_for_anchor(anchor)
	apply_pose(false)
	queue_redraw()


func _active_poly() -> PackedVector2Array:
	return _round if (not completed and _round.size() >= 3) else _outline


func _active_ring() -> PackedVector2Array:
	return _round_ring if (not completed and _round.size() >= 3) else _outline_ring


## 조각을 아래로 두께만큼 파묻지 않고 칸 중앙에 오도록, 본체 전체를 화면 기준 위로 올린 양(두께의 절반).
func _center_up() -> Vector2:
	return Vector2(0.0, -_depth * 0.5)


func _draw() -> void:
	var poly := _active_poly()
	# 폴리곤/텍스처가 준비되지 않은 예외 경로 — 칸 단위로 단순 렌더(테두리·두께 없음).
	if poly.size() < 3 or tex == null:
		for c in cells:
			if tex:
				draw_texture_rect_region(tex,
					Rect2(Vector2(c) * cell_px, Vector2(cell_px, cell_px)),
					Rect2(Vector2(c) * src_cell, src_cell))
		return

	var ring := _active_ring()
	var body_up := (LIFT_MOVE * lift) + _center_up()   # 떠오름 + 두께 보정(위로)

	# 1) 그림자 (떠 있을 때만) — 바닥에 깔린다. 화면 기준 오프셋이 되도록 회전을 상쇄한다.
	if lift > 0.001:
		var shadow_poly := ring if ring.size() >= 3 else poly
		draw_set_transform((SHADOW_MOVE * lift).rotated(-rotation))
		draw_colored_polygon(shadow_poly, Color(0, 0, 0, SHADOW_ALPHA * lift))

	# 2) 두께(옆면) — 본체보다 화면 기준으로 _depth 만큼 아래에 그린 링. 테두리에 가려 아래쪽만 남는다.
	if ring.size() >= 3:
		draw_set_transform((body_up + Vector2(0.0, _depth)).rotated(-rotation))
		draw_colored_polygon(ring, SIDE_COL)

	# 3~5) 본체 프레임 (두께 보정만큼 위로 올린 위치)
	draw_set_transform(body_up.rotated(-rotation))
	# 3) 밝은 테두리(rim) — 확장한 링을 밝은색으로 채운 뒤 본체를 그 위에 얹어 바깥 테두리만 남긴다.
	if ring.size() >= 3:
		draw_colored_polygon(ring, RIM_COL)
	# 4) 본체(텍스처)
	var ts := Vector2(tex.get_width(), tex.get_height())
	var uvs := PackedVector2Array()
	for p in poly:
		uvs.append(p / cell_px * src_cell / ts)
	var cols := PackedColorArray()
	cols.resize(poly.size())
	cols.fill(Color.WHITE)
	draw_polygon(poly, cols, uvs, tex)
	# 5) 뭉침/스냅 플래시
	if flash > 0.0:
		draw_colored_polygon(poly, Color(1, 1, 1, flash * 0.6))

	draw_set_transform(Vector2.ZERO)


## 외곽선(src)을 바깥으로 _outline_w 만큼 확장한 링 폴리곤. 두께/테두리 밑판으로 쓴다.
## 확장 결과가 여러 폴리곤이면 면적이 가장 큰(=바깥) 것을 고른다.
func _expand_ring(src: PackedVector2Array) -> PackedVector2Array:
	if src.size() < 3 or _outline_w <= 0.0:
		return PackedVector2Array()
	var res := Geometry2D.offset_polygon(src, _outline_w, Geometry2D.JOIN_ROUND)
	var best := PackedVector2Array()
	var best_area := 0.0
	for p in res:
		var a := absf(_poly_area(p))
		if a > best_area:
			best_area = a
			best = p
	return best


func _poly_area(p: PackedVector2Array) -> float:
	var s := 0.0
	var n := p.size()
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


# ---------- 회전 지원 격자 좌표 ----------

## 정답 셀 c 가 회전 r 에서 차지하는 (off 기준) 상대 보드칸.
## r=0 이면 c 그대로 → boardCell = off + c (합체 로직이 쓰는 정답좌표계와 일치).
func rel_cell(c: Vector2i, r: int) -> Vector2i:
	var w := cmax.x - cmin.x + 1
	var h := cmax.y - cmin.y + 1
	var n := c - cmin
	var rn: Vector2i
	match posmod(r, 4):
		0:
			rn = n
		1:
			rn = Vector2i(h - 1 - n.y, n.x)
		2:
			rn = Vector2i(w - 1 - n.x, h - 1 - n.y)
		_:
			rn = Vector2i(n.y, w - 1 - n.x)
	return cmin + rn


## rel_cell 의 순수 선형(회전) 성분. bounding box 와 무관하게 격자 벡터를 r*90° 회전한다.
func _rot_lin(v: Vector2i, r: int) -> Vector2i:
	match posmod(r, 4):
		0:
			return v
		1:
			return Vector2i(-v.y, v.x)
		2:
			return Vector2i(-v.x, -v.y)
		_:
			return Vector2i(v.y, -v.x)


## 이 묶음의 회전 불변 "정답 기준점" G. 모든 셀에 대해 boardCell(c) = G + _rot_lin(c, rot) 이 성립.
## (rel_cell 은 자기 bounding box 안에서 도는 affine 이라 박스에 의존하지만, G 는 박스 무관한 값이다.)
## 두 묶음이 같은 rot 이고 anchor 가 같으면 서로 정답 상대 위치에 놓여 있다(합체 조건).
## G = off + rel_cell(c0, rot) - _rot_lin(c0, rot) — 어떤 셀 c0 로 계산해도 같다(rel_cell 과 항상 일치).
func solution_anchor() -> Vector2i:
	var c0 := cells[0]
	return off + rel_cell(c0, rot) - _rot_lin(c0, rot)


## 주어진 anchor 를 만드는 off (현재 rot / bounding box 기준). solution_anchor 의 역.
func off_for_anchor(anchor: Vector2i) -> Vector2i:
	var c0 := cells[0]
	return anchor - rel_cell(c0, rot) + _rot_lin(c0, rot)


func board_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(off + rel_cell(c, rot))
	return out


func board_cells_at(o: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(o + rel_cell(c, rot))
	return out


# ---------- 자세(위치+회전) ----------

func _center_local() -> Vector2:
	return (Vector2(cmin) + Vector2(cmax) + Vector2.ONE) * 0.5 * cell_px


## 주어진 off / rot 에 대한 Node2D position. 회전은 조각 중심을 유지하며 그리드에 정렬된다.
func pose_position_for(o: Vector2i, r: int) -> Vector2:
	var a := r * (PI / 2.0)
	var c0 := cells[0]
	var target := (Vector2(o) + Vector2(rel_cell(c0, r)) + Vector2(0.5, 0.5)) * cell_px
	var localc := (Vector2(c0) + Vector2(0.5, 0.5)) * cell_px
	return target - localc.rotated(a)


func _pose_position(r: int) -> Vector2:
	return pose_position_for(off, r)


## 정답 격자 좌표계의 점 p(격자 단위) → board_origin 기준 픽셀 위치(현재 off/rot 의 이상적 자세 기준).
## 회전을 반영하므로 파티클/완성 연출을 실제 화면 위치에 맞출 때 쓴다.
func solution_to_board_px(p: Vector2) -> Vector2:
	var a := rot * (PI / 2.0)
	return pose_position_for(off, rot) + (p * cell_px).rotated(a)


func set_rotation_index(r: int) -> void:
	rot = posmod(r, 4)
	_vis_angle = rot * (PI / 2.0)


func bump_rotation() -> void:
	rot = posmod(rot + 1, 4)
	_vis_angle += PI / 2.0


func apply_pose(animate: bool) -> void:
	var pos := _pose_position(rot)
	_kill_tween()
	if animate:
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(self, "position", pos, 0.16) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "rotation", _vis_angle, 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		position = pos
		rotation = _vis_angle


func set_off(new_off: Vector2i, animate: bool) -> void:
	off = new_off
	apply_pose(animate)


## 축칸(pivot, 정답 셀) 중앙을 부모 좌표계 pivot_center 에 고정한 채 새 off 자세로 90° 부드럽게 회전한다.
## rot·_vis_angle 은 호출 전에 bump_rotation() 으로 이미 갱신되어 있어야 한다(직전보다 한 스텝 앞선 상태).
## position·rotation 을 따로 트윈하지 않고, 각도를 보간하며 매 프레임 축을 고정해 튐 없이 제자리에서 돈다.
func rotate_around(pivot: Vector2i, pivot_center: Vector2, new_off: Vector2i) -> void:
	off = new_off
	var local_pivot := (Vector2(pivot) + Vector2(0.5, 0.5)) * cell_px
	var end_pos := _pose_position(rot)
	# 축을 고정한 순수 회전의 종료 위치. 클램프가 없으면 end_pos 와 같고, 밀렸으면 그 차이만큼 함께 슬라이드한다.
	var rot_end_pos := pivot_center - local_pivot.rotated(_vis_angle)
	var delta := end_pos - rot_end_pos
	var start_angle := _vis_angle - PI / 2.0
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_apply_rot_step.bind(start_angle, pivot_center, local_pivot, delta),
		0.0, 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_rot_step(t: float, start_angle: float, pivot_center: Vector2, local_pivot: Vector2, delta: Vector2) -> void:
	var a: float = lerp(start_angle, _vis_angle, t)
	rotation = a
	position = pivot_center - local_pivot.rotated(a) + delta * t


func snap_and_flash(new_off: Vector2i) -> void:
	set_off(new_off, true)
	var t := create_tween()
	t.tween_property(self, "flash", 0.0, 0.4).from(0.9)


## 제자리에서 작게(0) 시작해 텐션있게(살짝 오버슈트) 커지며 등장한다.
func pop_in(delay: float) -> void:
	var base := _pose_position(rot)
	rotation = _vis_angle
	_apply_pop(0.0, base)          # 시작 프레임: 크기 0 (중심 고정)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_apply_pop.bind(base), 0.0, 1.0, 0.45) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 스케일 s(0→1, 살짝 오버슈트)에 맞춰 크기와 위치를 함께 조정.
## 조각의 시각적 중심이 제자리에 고정된 채 커지도록 position 을 보정한다.
func _apply_pop(s: float, base_pos: Vector2) -> void:
	scale = Vector2(s, s)
	position = base_pos + (_center_local() * (1.0 - s)).rotated(rotation)


## 상자에서 튀어나오는 연출: center_from(부모 좌표, 조각 중심 기준)에서 시작해
## 아치를 그리며 현재 off/rot 의 제자리로 날아가 안착한다. 커지는 팝 효과를 곁들인다.
func fly_from(center_from: Vector2, delay: float = 0.0) -> void:
	var target := _pose_position(rot)
	rotation = _vis_angle
	var start := center_from - _center_local().rotated(_vis_angle)
	position = start
	scale = Vector2(0.55, 0.55)
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_fly_step.bind(start, target), 0.0, 1.0, 0.5) \
		.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.42) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fly_step(t: float, start: Vector2, target: Vector2) -> void:
	var p := start.lerp(target, t)
	p.y -= sin(t * PI) * 80.0          # 위로 솟았다 내려오는 아치
	position = p


## 현재 Node2D position(드래그로 임의 이동된) → 가장 가까운 정수 off.
func off_from_position() -> Vector2i:
	var a := rot * (PI / 2.0)
	var c0 := cells[0]
	var localc := (Vector2(c0) + Vector2(0.5, 0.5)) * cell_px
	var v := (position + localc.rotated(a)) / cell_px - Vector2(rel_cell(c0, rot)) - Vector2(0.5, 0.5)
	return Vector2i(roundi(v.x), roundi(v.y))


func contains_point(global_pt: Vector2) -> bool:
	return cell_set.has(cell_at_point(global_pt))


## 전역 좌표가 가리키는 정답 셀(회전 반영). 회전 축으로 쓴다.
func cell_at_point(global_pt: Vector2) -> Vector2i:
	var lp := to_local(global_pt)
	return Vector2i(floori(lp.x / cell_px), floori(lp.y / cell_px))


## 부드럽게 떠오르거나 내려앉는다.
func set_lifted(v: bool) -> void:
	if _lift_up == v:
		return
	_lift_up = v
	z_index = 4 if v else 0
	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.tween_property(self, "lift", 1.0 if v else 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func is_adjacent_to(other: PuzzleGroup) -> bool:
	for c in cells:
		for d in DIRS:
			if other.cell_set.has(c + d):
				return true
	return false


func allowed_off_range(board_w: int, board_h: int) -> Rect2i:
	# 회전된 점유칸(rel_cell)이 모두 보드 안에 들어오도록 off 범위 계산
	var mn := Vector2i(9999, 9999)
	var mx := Vector2i(-9999, -9999)
	for c in cells:
		var rc := rel_cell(c, rot)
		mn = Vector2i(mini(mn.x, rc.x), mini(mn.y, rc.y))
		mx = Vector2i(maxi(mx.x, rc.x), maxi(mx.y, rc.y))
	var lo := Vector2i(-mn.x, -mn.y)
	var hi := Vector2i(board_w - 1 - mx.x, board_h - 1 - mx.y)
	return Rect2i(lo, hi - lo)


func clamp_off(raw: Vector2i, board_w: int, board_h: int) -> Vector2i:
	var r := allowed_off_range(board_w, board_h)
	return Vector2i(
		clampi(raw.x, r.position.x, r.position.x + r.size.x),
		clampi(raw.y, r.position.y, r.position.y + r.size.y))


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


# ---------- 외곽선 추적 (구멍 없는 단순 다각형 가정, 외곽 경로만) ----------

func _trace_outline() -> PackedVector2Array:
	var edges := {}
	for c in cells:
		if not cell_set.has(c + Vector2i.UP):
			_add_edge(edges, Vector2i(c.x, c.y), Vector2i(c.x + 1, c.y))
		if not cell_set.has(c + Vector2i.RIGHT):
			_add_edge(edges, Vector2i(c.x + 1, c.y), Vector2i(c.x + 1, c.y + 1))
		if not cell_set.has(c + Vector2i.DOWN):
			_add_edge(edges, Vector2i(c.x + 1, c.y + 1), Vector2i(c.x, c.y + 1))
		if not cell_set.has(c + Vector2i.LEFT):
			_add_edge(edges, Vector2i(c.x, c.y + 1), Vector2i(c.x, c.y))
	if edges.is_empty():
		return PackedVector2Array()
	var start := Vector2i(9999, 9999)
	for k in edges.keys():
		if k.y < start.y or (k.y == start.y and k.x < start.x):
			start = k
	var pts: Array[Vector2i] = [start]
	var cur: Vector2i = start
	var dir := Vector2i(1, 0)
	var guard := cells.size() * 4 + 16
	while guard > 0:
		guard -= 1
		if not edges.has(cur) or (edges[cur] as Array).is_empty():
			break
		var outs: Array = edges[cur]
		var best := -1
		var best_cross := -9
		for i in outs.size():
			var d: Vector2i = outs[i] - cur
			var cr := dir.x * d.y - dir.y * d.x
			if cr > best_cross:
				best_cross = cr
				best = i
		var nxt: Vector2i = outs[best]
		outs.remove_at(best)
		dir = nxt - cur
		cur = nxt
		if cur == start:
			break
		pts.append(cur)
	# 일직선 위 중간점 제거 후 픽셀 좌표로 변환
	var merged := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var prev := pts[(i - 1 + n) % n]
		var next := pts[(i + 1) % n]
		var d1 := pts[i] - prev
		var d2 := next - pts[i]
		if d1.x * d2.y - d1.y * d2.x != 0:
			merged.append(Vector2(pts[i]) * cell_px)
	return merged


func _add_edge(edges: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if not edges.has(a):
		edges[a] = []
	edges[a].append(b)


## 날카로운 외곽선의 각 꼭짓점을 2차 베지어로 둥글린다(미완성 조각용).
func _round_corners(src: PackedVector2Array) -> PackedVector2Array:
	var n := src.size()
	if n < 3:
		return src
	var radius := cell_px * 0.28
	var out := PackedVector2Array()
	for i in n:
		var prev := src[(i - 1 + n) % n]
		var cur := src[i]
		var nxt := src[(i + 1) % n]
		var v_in := cur - prev
		var v_out := nxt - cur
		var len_in := v_in.length()
		var len_out := v_out.length()
		var r: float = min(radius, len_in * 0.5, len_out * 0.5)
		var din := v_in / maxf(len_in, 0.001)
		var dout := v_out / maxf(len_out, 0.001)
		var p_start := cur - din * r
		var p_end := cur + dout * r
		var steps := 8
		for s in steps + 1:
			var t := float(s) / float(steps)
			var a := p_start.lerp(cur, t)
			var b := cur.lerp(p_end, t)
			out.append(a.lerp(b, t))
	return out
