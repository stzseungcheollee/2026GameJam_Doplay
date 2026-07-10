class_name PuzzleBox
extends Node2D

## 퍼즐 파츠를 숨긴 보물상자. 보드의 한 칸(1x1)을 차지한다.
##  - box_1 / box_2 / box_3 은 서로 다른 상자 그림이다(숨긴 조각 수에 맞춰 고른다).
##  - 어떤 상자든 3겹이라, 세 번 타격해야 부서진다.
##  - 3겹을 모두 부수면 안에 든 모든 조각이 한꺼번에 튀어나온다(released 연출은 main 이 담당).

signal opened(box: PuzzleBox)          # 3겹 다 부숨 → main 이 payload 전체를 방출

const SPRITE_PATH := "res://assets/sprites/box_%d.png"
const MAX_KIND := 4                    # box_1 ~ box_4 그림 지원
const BOX_SCALE := 1.16                # 칸 대비 상자 크기(살짝 크게 그려 존재감)

static var _tex_cache: Dictionary = {}
static var _debris_tex_cache: Texture2D

var cell_px := 64.0
var cell := Vector2i.ZERO              # 놓인 보드칸 (1x1)
var payload: Array[PuzzleGroup] = []   # 숨긴 조각들 (부서질 때 한꺼번에 방출)
var layers := 3                        # 남은 겹 (= 남은 타격 횟수)
var max_layers := 3

var _busy := false                     # 부서지는 중엔 타격 무시
var _base_pos := Vector2.ZERO


func setup(p_cell_px: float, p_layers: int = 3) -> void:
	cell_px = p_cell_px
	layers = p_layers
	max_layers = p_layers
	queue_redraw()


## 보드칸 c(1x1)에 배치.
func place_at(c: Vector2i) -> void:
	cell = c
	_base_pos = Vector2(c) * cell_px
	position = _base_pos


func add_payload(g: PuzzleGroup) -> void:
	payload.append(g)
	queue_redraw()                     # 개수에 맞는 상자 그림(box_N)으로 갱신


func count() -> int:
	return payload.size()


## 상자가 덮는 보드칸 (1칸).
func footprint_cells() -> Array[Vector2i]:
	return [cell]


## 전역 좌표가 상자 위인지 (터치 히트 테스트). 그려지는 상자 크기만큼 넉넉히 잡는다.
func contains_point(global_pt: Vector2) -> bool:
	var lp := to_local(global_pt)
	var side := cell_px * BOX_SCALE
	var r := Rect2(Vector2(cell_px, cell_px) * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side))
	return r.has_point(lp)


## 겹을 하나 타격한다. 마지막 겹까지 부수면 상자가 열린다(안의 조각 전부 방출).
func peel() -> void:
	if _busy or layers <= 0:
		return
	layers -= 1
	_nudge()
	_burst(false)
	if layers <= 0:
		_open()
	else:
		Sfx.play("box_hit")


# ---------- 연출 ----------

## 3겹 다 부숨 → 파편 터지며 사라진다. 방출은 opened 로 main 에 맡긴다.
func _open() -> void:
	_busy = true
	Sfx.play("box_open")
	opened.emit(self)
	_burst(true)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.30)
	t.tween_method(_apply_pop, 1.0, 1.35, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(queue_free)


## 타격할 때 짧게 흔들림.
func _nudge() -> void:
	var t := create_tween()
	t.tween_property(self, "position", _base_pos + Vector2(6, -5), 0.05)
	t.tween_property(self, "position", _base_pos, 0.16) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 제자리에서 작게(0) → 살짝 오버슈트하며 등장.
func pop_in(delay: float) -> void:
	_apply_pop(0.0)
	var t := create_tween()
	t.tween_method(_apply_pop, 0.0, 1.0, 0.45) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 스케일 s 에 맞춰 크기·위치 조정 (칸 중심 고정).
func _apply_pop(s: float) -> void:
	scale = Vector2(s, s)
	position = _base_pos + Vector2(cell_px, cell_px) * 0.5 * (1.0 - s)


## 나무/금박 파편 파티클.
func _burst(big: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(cell_px, cell_px) * 0.5
	p.z_index = 5
	p.one_shot = true
	p.texture = _debris_tex()
	p.explosiveness = 1.0
	p.amount = 20 if big else 8
	p.lifetime = 0.7 if big else 0.45
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = cell_px * 0.28
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 520)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 230.0 if big else 150.0
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4 if big else 1.7
	p.color = Color("d9a441")
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


func _debris_tex() -> Texture2D:
	if _debris_tex_cache != null:
		return _debris_tex_cache
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_debris_tex_cache = ImageTexture.create_from_image(img)
	return _debris_tex_cache


func _box_tex(n: int) -> Texture2D:
	var k := clampi(n, 1, MAX_KIND)
	if _tex_cache.has(k):
		return _tex_cache[k]
	var path := SPRITE_PATH % k
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[k] = t
	return t


# ---------- 그리기 ----------

func _draw() -> void:
	# 상자 그림은 "숨긴 조각 수"로 고른다(box_1/2/3). 타격해도 바뀌지 않는다.
	var tex := _box_tex(maxi(1, payload.size()))
	var center := Vector2(cell_px, cell_px) * 0.5
	if tex:
		var ts := tex.get_size()
		var sc := cell_px * BOX_SCALE / maxf(ts.x, ts.y)
		var dsize := ts * sc
		draw_texture_rect(tex, Rect2(center - dsize * 0.5, dsize), false)
		return
	# 폴백: 텍스처가 없을 때 간단한 상자 + 개수 점
	var side := cell_px * BOX_SCALE
	var rect := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("c98a4a")
	sb.border_color = Color("6f4a22")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(cell_px * 0.16))
	sb.draw(get_canvas_item(), rect)
	var n := clampi(payload.size(), 1, MAX_KIND)
	var pr := cell_px * 0.08
	var gap := pr * 2.6
	var total := float(n - 1) * gap
	for i in n:
		draw_circle(Vector2(center.x - total * 0.5 + i * gap, center.y), pr, Color("ffe89a"))
