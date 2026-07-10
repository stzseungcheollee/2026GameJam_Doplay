class_name PictureArt
extends Node2D

## 퍼즐용 그림을 코드로 그리는 페인터.
## SubViewport 안에 넣고 한 프레임 렌더링한 뒤 텍스처로 캡처해서 사용한다.
## 좌표는 0~100 퍼센트 단위로 지정하고 _p()/_u()로 픽셀로 변환.

var scene_id := 0
var px := 480.0


func _draw() -> void:
	match scene_id:
		0:
			_draw_sunset_whale()
		1:
			_draw_volcano_island()
		_:
			_draw_lighthouse()


# ---------- 좌표/도형 헬퍼 ----------

func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * px / 100.0


func _u(v: float) -> float:
	return v * px / 100.0


func _rect(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(_p(x, y), Vector2(_u(w), _u(h))), col)


func _circle(x: float, y: float, r: float, col: Color) -> void:
	draw_circle(_p(x, y), _u(r), col)


func _ellipse(x: float, y: float, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	var c := _p(x, y)
	for i in 40:
		var a := TAU * i / 40.0
		var v := Vector2(cos(a) * _u(rx), sin(a) * _u(ry)).rotated(rot)
		pts.append(c + v)
	draw_colored_polygon(pts, col)


func _poly(points: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(_p(p.x, p.y))
	draw_colored_polygon(pts, col)


func _cloud(x: float, y: float, s: float, col: Color) -> void:
	_ellipse(x, y, 7.0 * s, 3.1 * s, col)
	_circle(x - 3.6 * s, y - 1.0 * s, 2.7 * s, col)
	_circle(x + 0.4 * s, y - 2.3 * s, 3.3 * s, col)
	_circle(x + 4.0 * s, y - 0.9 * s, 2.4 * s, col)


func _bird(x: float, y: float, s: float, col: Color) -> void:
	draw_arc(_p(x - 1.2 * s, y), _u(1.3 * s), PI, TAU, 10, col, _u(0.55 * s))
	draw_arc(_p(x + 1.2 * s, y), _u(1.3 * s), PI, TAU, 10, col, _u(0.55 * s))


func _sky_bands(top: Color, bottom: Color, horizon: float) -> void:
	var steps := 6
	var h := horizon / steps
	for i in steps:
		var col := top.lerp(bottom, float(i) / float(steps - 1))
		_rect(0.0, i * h, 100.0, h + 0.5, col)


func _sea(y0: float, base: Color, light: Color) -> void:
	_rect(0.0, y0, 100.0, 100.0 - y0, base)
	_rect(0.0, y0, 100.0, 2.6, Color(light.r, light.g, light.b, 0.55))
	# 물결 라인
	var rows := [y0 + 9.0, y0 + 19.0, y0 + 30.0]
	for ri in rows.size():
		var wy: float = rows[ri]
		if wy > 96.0:
			continue
		var pts := PackedVector2Array()
		for xi in 26:
			var wx := xi * 4.0
			pts.append(_p(wx, wy + sin(wx * 0.45 + ri * 2.1) * 1.1))
		draw_polyline(pts, Color(light.r, light.g, light.b, 0.75), _u(0.9))
	# 수면 거품
	for k in 8:
		var fx := 4.0 + k * 12.0 + (k % 3) * 2.5
		_rect(fx, y0 + 3.5 + (k % 2) * 2.0, 4.5, 1.0, Color(1, 1, 1, 0.45))


func _sailboat(x: float, y: float, s: float) -> void:
	_poly([Vector2(x - 6 * s, y), Vector2(x + 6 * s, y), Vector2(x + 4 * s, y + 4 * s), Vector2(x - 4 * s, y + 4 * s)], Color("7a4a2e"))
	_rect(x - 0.4 * s, y - 12 * s, 0.8 * s, 12 * s, Color("5d3a24"))
	_poly([Vector2(x + 0.6 * s, y - 11 * s), Vector2(x + 0.6 * s, y - 1 * s), Vector2(x + 7 * s, y - 1 * s)], Color("fdf6ea"))
	_poly([Vector2(x - 0.8 * s, y - 10 * s), Vector2(x - 0.8 * s, y - 1 * s), Vector2(x - 6 * s, y - 1 * s)], Color("ffdf74"))


# ---------- 장면 1: 노을과 고래 ----------

func _draw_sunset_whale() -> void:
	_sky_bands(Color("ffe7b0"), Color("ffab60"), 55.0)
	# 해
	_circle(30, 31, 16, Color(1.0, 0.8, 0.42, 0.35))
	_circle(30, 31, 12, Color("ffc94a"))
	_circle(30, 31, 9.5, Color("ffdf74"))
	_circle(27, 28, 2.4, Color(1, 1, 1, 0.65))
	# 구름 / 새
	_cloud(68, 13, 1.3, Color("fff6e6"))
	_cloud(13, 21, 0.9, Color("fff6e6"))
	_cloud(86, 30, 0.75, Color(1, 1, 1, 0.9))
	_bird(55, 20, 1.0, Color("6b4f3f"))
	_bird(63, 15, 0.8, Color("6b4f3f"))
	# 바다
	_sea(55.0, Color("2f6fd1"), Color("6aa7ef"))
	# 고래
	_poly([Vector2(79, 76), Vector2(87, 63), Vector2(91, 69), Vector2(84, 78)], Color("24418f"))
	_circle(88, 66, 2.2, Color("24418f"))
	_ellipse(67, 76, 15, 8.5, Color("24418f"))
	_ellipse(64, 80, 10, 4.0, Color("3a5cb0"))
	_poly([Vector2(66, 70), Vector2(72, 66), Vector2(73, 72)], Color("1b3372"))
	_circle(58, 74, 1.7, Color(1, 1, 1, 0.95))
	_circle(58.4, 74.2, 0.85, Color("14224d"))
	_circle(55.5, 77.5, 1.3, Color(1.0, 0.55, 0.55, 0.55))
	draw_arc(_p(59.5, 77.5), _u(2.0), 0.3, 1.3, 10, Color(1, 1, 1, 0.8), _u(0.5))
	# 물줄기
	_circle(64.5, 62.0, 1.2, Color("bfe6ff"))
	_circle(66.5, 60.0, 1.8, Color("bfe6ff"))
	_circle(68.6, 62.4, 1.1, Color("bfe6ff"))
	_rect(65.9, 62.5, 1.1, 4.5, Color("bfe6ff"))


# ---------- 장면 2: 화산섬 ----------

func _draw_volcano_island() -> void:
	_sky_bands(Color("8edaf7"), Color("cdeffc"), 60.0)
	# 해
	_circle(84, 14, 10, Color(1.0, 0.95, 0.5, 0.3))
	_circle(84, 14, 7, Color("ffe066"))
	# 구름 / 새
	_cloud(22, 15, 1.1, Color("ffffff"))
	_cloud(58, 24, 0.8, Color(1, 1, 1, 0.95))
	_bird(42, 13, 0.9, Color("4a5568"))
	_bird(50, 18, 0.7, Color("4a5568"))
	# 바다
	_sea(60.0, Color("2f86d8"), Color("6fb3ec"))
	# 섬
	_ellipse(40, 67, 28, 8.5, Color("d8c07a"))
	_ellipse(40, 65, 26, 8.5, Color("55b169"))
	# 야자수
	_poly([Vector2(23.5, 65), Vector2(25.5, 65), Vector2(25.0, 52), Vector2(24.2, 52)], Color("7a5230"))
	for leaf in [[0.4, 5.5], [-0.4, 5.5], [1.2, 4.5], [-1.2, 4.5], [0.0, 6.0]]:
		_ellipse(24.6, 51.0, leaf[1], 1.5, Color("3f9e57"), leaf[0] + PI * float(leaf[0] < 0))
	_circle(24.6, 52.2, 1.1, Color("8a5a3e"))
	# 화산
	_poly([Vector2(29, 65), Vector2(37, 38), Vector2(45, 38), Vector2(53, 65)], Color("8a5a3e"))
	_poly([Vector2(45, 38), Vector2(53, 65), Vector2(44, 65)], Color("74492f"))
	_ellipse(41, 38.2, 4.6, 1.8, Color("57351f"))
	_poly([Vector2(37.2, 39), Vector2(41, 45), Vector2(44.8, 38.5)], Color("ff6a3c"))
	_circle(41, 39, 3.0, Color(1.0, 0.55, 0.2, 0.5))
	# 연기
	_circle(44, 31, 3.2, Color(0.93, 0.92, 0.9, 0.9))
	_circle(47, 25, 4.0, Color(0.95, 0.94, 0.92, 0.85))
	_circle(51.5, 18.5, 4.8, Color(0.97, 0.96, 0.95, 0.8))
	# 돛단배
	_sailboat(78, 76, 1.1)


# ---------- 장면 3: 등대 ----------

func _draw_lighthouse() -> void:
	_sky_bands(Color("9fdcf8"), Color("dcf3fd"), 58.0)
	_circle(14, 13, 9, Color(1.0, 0.95, 0.5, 0.3))
	_circle(14, 13, 6.5, Color("ffe066"))
	_cloud(38, 11, 1.0, Color("ffffff"))
	_cloud(76, 19, 1.2, Color("ffffff"))
	_cloud(9, 30, 0.7, Color(1, 1, 1, 0.9))
	_bird(58, 15, 0.9, Color("4a5568"))
	_bird(66, 11, 0.7, Color("4a5568"))
	_sea(58.0, Color("2e76cf"), Color("6aabe8"))
	_sailboat(17, 74, 0.9)
	# 불빛
	_poly([Vector2(45, 29), Vector2(4, 19), Vector2(4, 37)], Color(1.0, 0.95, 0.6, 0.32))
	_poly([Vector2(55, 29), Vector2(96, 19), Vector2(96, 37)], Color(1.0, 0.95, 0.6, 0.32))
	# 등대 본체 + 빨간 줄무늬
	_poly([Vector2(44, 36), Vector2(56, 36), Vector2(59, 80), Vector2(41, 80)], Color("f7f1e6"))
	for band in [[42.0, 49.0], [56.0, 63.0], [70.0, 77.0]]:
		var w1 : float = lerpf(12.0, 18.0, (band[0] - 36.0) / 44.0)
		var w2 : float = lerpf(12.0, 18.0, (band[1] - 36.0) / 44.0)
		_poly([
			Vector2(50 - w1 / 2, band[0]), Vector2(50 + w1 / 2, band[0]),
			Vector2(50 + w2 / 2, band[1]), Vector2(50 - w2 / 2, band[1]),
		], Color("e85449"))
	# 발코니 / 등탑 / 지붕
	_rect(42.5, 33.5, 15, 3.0, Color("4a3b57"))
	_rect(45.5, 27, 9, 6.5, Color("ffe38a"))
	_rect(49.4, 27, 1.2, 6.5, Color("4a3b57"))
	_poly([Vector2(43.5, 27), Vector2(56.5, 27), Vector2(50, 20.5)], Color("e85449"))
	_circle(50, 20.5, 1.3, Color("e85449"))
	# 문
	_rect(48.3, 73.5, 3.4, 6.5, Color("6b4a33"))
	_circle(50, 73.5, 1.7, Color("6b4a33"))
	# 바위
	_ellipse(50, 85, 21, 8, Color("7d8296"))
	_ellipse(43, 82.5, 10, 5.5, Color("949ab0"))
	_ellipse(58, 83, 9, 5, Color("8a90a5"))
	_circle(64, 81, 3.0, Color("7d8296"))
