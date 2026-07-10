extends Node2D

## PuzzleBox 시각 확인용 (개발 전용). 숨긴 개수(1/2/3)에 따른 상자 그림을 렌더해 PNG 로 저장하고 종료한다.
## 실행: godot --path . res://tools/box_preview.tscn

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("e7d6ab"))
	var tex: Texture2D = load("res://assets/puzzles/1.png")
	var positions := [Vector2(140, 180), Vector2(360, 180), Vector2(580, 180)]
	for n in [1, 2, 3]:
		var box := PuzzleBox.new()
		box.setup(160.0)
		for _i in n:
			var g := PuzzleGroup.new()
			var cells: Array[Vector2i] = [Vector2i(0, 0)]
			g.init(cells, Vector2i.ZERO, 160.0, Vector2(160, 160), tex)
			box.add_payload(g)
		box.position = positions[n - 1] - Vector2(80, 80)
		add_child(box)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/box_preview.png")
	print("[preview] saved res://tools/box_preview.png")
	get_tree().quit()
