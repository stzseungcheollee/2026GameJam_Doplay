extends Node2D

## 압정(pin) 렌더 시각 확인용 (개발 전용).
## 조각을 rot 0~3 으로 나란히 두고, 그 위에 '안 돌아가는' 별도 핀 스프라이트를 얹어
## 조각이 어떤 각도든 핀은 늘 화면 기준 똑바로 서고 뾰족한 끝이 압정칸 중앙에 꽂히는지 확인한다.
## (실제 게임과 동일한 구조: 핀은 조각의 자식이 아니라 별도 레이어의 정적 스프라이트다.)
## 실행: godot --path . res://tools/pin_preview.tscn

const PIN_PATH := "res://assets/sprites/pin.png"
const PIN_H_FRAC := 1.15
const PIN_TIP := Vector2(0.42, 0.90)
const PIN_NUDGE := Vector2(5, 5)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("e7d6ab"))
	var tex: Texture2D = load("res://assets/puzzles/1.png")
	var pin_tex: Texture2D = load(PIN_PATH)
	var cpx := 90.0
	# L자 3칸 조각 — 압정은 가운데 칸(1,0)에 박는다.
	var shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]
	var tack := Vector2i(1, 0)
	var origins := [Vector2(120, 150), Vector2(400, 150), Vector2(120, 470), Vector2(400, 470)]
	for rr in 4:
		var origin: Vector2 = origins[rr]
		var g := PuzzleGroup.new()
		g.init(shape, Vector2i.ZERO, cpx, Vector2(cpx, cpx), tex)
		g.tacked = true
		g.tack_cell = tack
		g.set_rotation_index(rr)
		g.apply_pose(false)
		g.position = origin
		add_child(g)
		# 압정칸(tack)의 화면 위치 = 조각 노드 변환으로 tack 칸 중앙을 매핑. 회전해도 이 지점은 화면상 그대로.
		var tack_center: Vector2 = g.to_global((Vector2(g.rel_cell(tack, rr)) + Vector2(0.5, 0.5)) * cpx)
		var pin := Sprite2D.new()
		pin.texture = pin_tex
		pin.centered = false
		pin.offset = -PIN_TIP * pin_tex.get_size()
		var s := cpx * PIN_H_FRAC / pin_tex.get_height()
		pin.scale = Vector2(s, s)
		pin.position = tack_center + PIN_NUDGE   # 핀은 회전하지 않음(rotation=0), 우하단 5px 보정
		pin.z_index = 10
		add_child(pin)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/pin_preview.png")
	print("[preview] saved res://tools/pin_preview.png")
	get_tree().quit()
