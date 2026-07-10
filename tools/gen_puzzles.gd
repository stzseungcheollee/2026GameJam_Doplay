extends Node

## 기본 퍼즐 이미지 생성기. PictureArt 로 그린 풍경 3장을
## res://assets/puzzles/1~3.png 로 저장한다. (에디터/디버그 실행에서만 res:// 쓰기 가능)
## 실행: godot --path . tools/gen_puzzles.tscn

func _ready() -> void:
	var px := 640
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/puzzles"))
	for i in 3:
		var vp := SubViewport.new()
		vp.size = Vector2i(px, px)
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var art := PictureArt.new()
		art.scene_id = i
		art.px = float(px)
		vp.add_child(art)
		add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		var err := img.save_png("res://assets/puzzles/%d.png" % (i + 1))
		print("saved %d.png  err=%d" % [i + 1, err])
		vp.queue_free()
	get_tree().quit()
