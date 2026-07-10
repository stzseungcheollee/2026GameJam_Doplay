extends Control

## 메인(타이틀/로비) 화면 — 스테이지 캐러셀
##  - 완성한 스테이지는 그림 카드로, 아직 안 깬 "다음" 스테이지는 보물상자(box_4)로 표시한다.
##  - 그림은 완성 연출처럼 둥근 모서리 + 은은한 그림자로 둥둥 떠 있는 느낌을 준다(백판 없음).
##  - 좌우로 넘겨보며(peek: 양옆 카드가 반투명하게 살짝 보인다) 스테이지를 고른다.
##    드래그는 관성으로 흐르고, 멈추면 가장 가까운 카드가 중앙에 자석처럼 달라붙는다.
##  - 옆 카드를 탭 → 가운데로 이동 / 가운데 카드를 탭 → 그 스테이지 시작.
##    · 완성작을 탭하면 그 스테이지 다시 플레이, 박스를 탭하면 아직 안 깬 그 레벨을 시작.
##  - 시작 연출: 카드가 텐션있게 커졌다 작아지며 화면이 페이드아웃되고 게임 씬으로 컷 전환된다.

const VIEW_W := 720.0
const VIEW_H := 1280.0
const GAME_SCENE := "res://scenes/main.tscn"
const BOX_SPRITE := "res://assets/sprites/box_4.png"

# 카드/캐러셀 배치
const CARD_W := 460.0
const CARD_H := 748.0
const PAGE_W := 486.0           # 한 카드 중심 간격(< 화면폭 → 양옆 카드가 살짝 겹쳐 보인다)
const GALLERY_TOP := 236.0      # 카드 띠의 상단 Y (버튼이 사라져 화면 중앙에 크게 배치)
const OVERSCROLL := 120.0       # 끝에서 살짝 넘겨지는 여유

const PIC_MAX_W := 430.0        # 그림이 카드 안에서 차지하는 최대 크기(비율 유지로 맞춤)
const PIC_MAX_H := 650.0
const CORNER_RADIUS := 28.0     # 그림 둥근 모서리 반경
const BOX_MAX := 146.0          # 상자 표시 크기(이전의 약 절반)

# 옆(비중앙) 카드의 축소·반투명 정도
const SIDE_SCALE := 0.80
const SIDE_ALPHA := 0.42
const TAP_MOVE_THRESH := 12.0   # 이 이하로 움직였으면 드래그가 아닌 "탭"으로 본다
const FLING := 7.0              # 놓을 때 관성으로 더 흐르는 정도

# 둥둥 떠있는 연출
const BOB_AMP := 7.0
const BOB_SPEED := 1.6
const BOB_PHASE := 0.9

# 색상 (게임 톤과 동일)
const COL_BG := Color("e7d6ab")
const COL_INK := Color("46382b")
const FADE_COL := Color(0.10, 0.07, 0.04)    # 컷 전환용 어두운 따뜻한 톤

# 그림 둘레를 둥글게 깎는 셰이더 (완성 연출과 동일 방식: SDF 라운드 사각형으로 알파 클리핑)
const ROUNDED_SHADER := """shader_type canvas_item;
uniform vec2 size_px = vec2(430.0);
uniform float radius_px = 28.0;
void fragment() {
	vec2 h = size_px * 0.5;
	vec2 p = UV * size_px - h;
	vec2 q = abs(p) - h + radius_px;
	float d = min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius_px;
	float aa = max(fwidth(d), 0.0001);
	float a = 1.0 - smoothstep(-aa, aa, d);
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(t.rgb, t.a * a);
}
"""

var stages: Array[Dictionary] = []           # {idx:int, is_box:bool, tex:Texture2D}
var cards: Array[Control] = []               # 각 스테이지 카드(캐러셀 배치·스케일 대상)
var card_contents: Array[Control] = []       # 각 카드의 내용(그림/상자) — 둥둥 bob 대상
var content_base_y: Array[float] = []         # bob 기준 y

var gallery: Control
var strip: Control
var fade: ColorRect

var index := 0
var dragging := false
var moved_amt := 0.0
var _drag_vel := 0.0
var _launching := false
var _tween: Tween

var level_label: Label            # 가운데 상단 "LEVEL N" 표시
var _label_tween: Tween
var _level_hidden := false         # 이동 중 숨김 상태(중복 트윈 방지)

# 게임에서 완성하고 넘어왔을 때, 로비에서 재생하는 "짠~" 완성 연출 상태
var _celebrating := false
var _celeb_card := -1

# 데이터 없는 첫 진입 인트로(빈 화면 → 상자 뾱 → 글자) 재생 중 여부
var _intro_playing := false


func _ready() -> void:
	get_window().title = "스테이지 선택"
	RenderingServer.set_default_clear_color(COL_BG)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var theme := Theme.new()
	var f: Font = load("res://assets/fonts/BMJUA_ttf.ttf")
	if f:
		theme.default_font = f
	theme.default_font_size = 22
	self.theme = theme

	_build_stages()
	_build_ui()

	# 게임에서 완성하고 넘어왔으면 그 카드에서 시작해 완성 연출을 재생한다.
	var celeb := _stage_index_of_level(SaveData.just_completed)
	if celeb >= 0:
		index = celeb
	go(index, false)
	_update_appearance()
	if celeb >= 0:
		SaveData.just_completed = -1
		fade.color.a = 1.0                                   # 검은 화면에서 스무스하게 밝아오며
		create_tween().tween_property(fade, "color:a", 0.0, 0.30)
		_celebrate_then_advance(celeb)
	elif SaveData.completed_indices().is_empty():
		_play_intro()                                        # 데이터 없는 첫 진입: 빈 화면 → 상자 뾱 → 글자


## 저장 데이터 없는 첫 진입 인트로: 빈 화면에서 상자가 "뾱" 튀어나오고, 이어서 글자가 뜬다.
func _play_intro() -> void:
	if cards.is_empty():
		return
	_intro_playing = true
	for c in cards:                                          # 시작: 카드 전부 숨김(스케일 0)
		c.scale = Vector2.ZERO
	_kill_label_tween()                                     # 글자도 숨긴 채 대기
	level_label.modulate.a = 0.0
	level_label.scale = Vector2(0.4, 0.4)

	await get_tree().create_timer(0.35).timeout             # 잠깐 아무것도 없는 화면

	var card := cards[index]                                 # 상자 "뾱" — 0에서 오버슈트로 팝인
	var t := create_tween()
	t.tween_property(card, "scale", Vector2.ONE, 0.44) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("ui")
	await t.finished

	_intro_playing = false
	_reveal_level()                                         # 이어서 글자가 텐션있게 등장


# ---------- 스테이지 모델 구성 ----------

## 카드 목록을 만든다:
##  - 완성한 레벨 → 그림 카드
##  - 아직 안 깬 "가장 앞선" 레벨 하나 → 박스 카드(여기서부터가 다음 도전 스테이지)
##  - 그 뒤의 아직 안 깬(잠긴) 레벨들은 표시하지 않는다.
## 초기 포커스는 박스(다음 도전 스테이지)에 맞춘다. 전부 깼다면 마지막 완성작에 맞춘다.
func _build_stages() -> void:
	var level_texs := SaveData.scan_puzzle_textures()
	var box_tex: Texture2D = load(BOX_SPRITE) if ResourceLoader.exists(BOX_SPRITE) else null

	var first_uncleared := -1
	for i in level_texs.size():
		if not SaveData.is_completed(i):
			first_uncleared = i
			break

	stages.clear()
	var box_pos := -1
	for i in level_texs.size():
		if SaveData.is_completed(i):
			stages.append({"idx": i, "is_box": false, "tex": level_texs[i]})
		elif i == first_uncleared:
			box_pos = stages.size()
			stages.append({"idx": i, "is_box": true, "tex": box_tex})

	# 이미지가 하나도 없으면(개발 초기) 최소한 1스테이지 박스는 열 수 있게 둔다.
	if stages.is_empty():
		stages.append({"idx": 0, "is_box": true, "tex": box_tex})
		box_pos = 0

	index = box_pos if box_pos >= 0 else maxi(stages.size() - 1, 0)


# ---------- UI 구성 ----------

func _build_ui() -> void:
	# 카드 띠 — 화면 폭 전체를 덮고, 넘치는 부분(양옆 카드의 바깥)은 잘라낸다.
	gallery = Control.new()
	gallery.position = Vector2(0, GALLERY_TOP)
	gallery.size = Vector2(VIEW_W, CARD_H)
	gallery.clip_contents = true
	gallery.mouse_filter = Control.MOUSE_FILTER_STOP
	gallery.gui_input.connect(_on_gallery_input)
	add_child(gallery)

	strip = Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gallery.add_child(strip)

	for i in stages.size():
		var card := _make_card(stages[i])
		# 카드 중심이 strip 로컬 x = i*PAGE_W 에 오도록.
		card.position = Vector2(i * PAGE_W - CARD_W * 0.5, 0.0)
		strip.add_child(card)
		cards.append(card)

	# 가운데 상단 레벨 표시 — 이동 중엔 숨었다가 멈추면 텐션있게 등장한다.
	level_label = Label.new()
	level_label.size = Vector2(VIEW_W, 64)
	level_label.position = Vector2(0, 110)
	level_label.pivot_offset = Vector2(VIEW_W * 0.5, 32)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 44)
	level_label.add_theme_color_override("font_color", COL_INK)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.text = _level_text(index)
	add_child(level_label)

	# 컷 전환용 페이드 오버레이 — 항상 맨 위. 평소엔 완전 투명.
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(FADE_COL.r, FADE_COL.g, FADE_COL.b, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)


## 한 스테이지 카드를 만든다. 카드 자체는 투명한 컨테이너(크기·피벗만),
## 내용(그림 또는 상자)은 백판 없이 둥근 모서리 + 그림자로 떠 있는 느낌.
func _make_card(stage: Dictionary) -> Control:
	var card := Control.new()
	card.size = Vector2(CARD_W, CARD_H)
	card.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if stage["is_box"]:
		var bsize := _fit_size(stage["tex"], BOX_MAX, BOX_MAX)
		content.size = bsize
		var box := TextureRect.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.texture = stage["tex"]
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(box)
	else:
		var psize := _fit_size(stage["tex"], PIC_MAX_W, PIC_MAX_H)
		content.size = psize
		# 은은한 소프트 그림자 — 백판이 아니라 "떠 있는" 느낌만 준다.
		var shadow := Panel.new()
		shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(0, 0, 0, 0)
		ss.set_corner_radius_all(int(CORNER_RADIUS))
		ss.shadow_color = Color(0.20, 0.14, 0.08, 0.32)
		ss.shadow_size = 16
		ss.shadow_offset = Vector2(0, 12)
		shadow.add_theme_stylebox_override("panel", ss)
		content.add_child(shadow)
		# 그림 — 둥근 모서리로 클리핑(완성 연출과 동일).
		var pic := TextureRect.new()
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.texture = stage["tex"]
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.material = _rounded_material(psize, CORNER_RADIUS)
		content.add_child(pic)

	var base_y := (CARD_H - content.size.y) * 0.5
	content.position = Vector2((CARD_W - content.size.x) * 0.5, base_y)
	card.add_child(content)
	card_contents.append(content)
	content_base_y.append(base_y)
	return card


## 텍스처를 max_w×max_h 안에 비율 유지로 맞춘 표시 크기.
func _fit_size(tex: Texture2D, max_w: float, max_h: float) -> Vector2:
	if tex == null:
		return Vector2(max_w, max_h)
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return Vector2(max_w, max_h)
	var s := minf(max_w / ts.x, max_h / ts.y)
	return ts * s


## 둥근 모서리 셰이더 머티리얼(그림 크기·반경 지정).
func _rounded_material(size_px: Vector2, radius: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = ROUNDED_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("size_px", size_px)
	m.set_shader_parameter("radius_px", radius)
	return m


# ---------- 캐러셀 위치/외형 ----------

func _process(_delta: float) -> void:
	if cards.is_empty():
		return
	_update_appearance()
	if _intro_playing:
		return                                              # 인트로 중엔 bob 정지
	# 둥둥 떠있는 bob — 카드 내용만 위아래로(카드 스케일과 독립, 각 카드 위상 어긋나게).
	var t := Time.get_ticks_msec() / 1000.0
	for i in card_contents.size():
		if _celebrating and i == _celeb_card:
			continue                                        # 연출 중인 카드는 bob 을 멈춘다
		card_contents[i].position.y = content_base_y[i] + sin(t * BOB_SPEED + i * BOB_PHASE) * BOB_AMP


## strip.position.x 기준으로 각 카드의 화면상 중심을 계산해 스케일·투명도·앞뒤(z)를 갱신한다.
## 가운데(거리 0)일수록 크고 불투명하며 앞에 온다.
func _update_appearance() -> void:
	if _intro_playing:
		return                                              # 인트로 중엔 상자 스케일을 인트로 트윈이 제어
	var center_x := VIEW_W * 0.5
	for i in cards.size():
		if _celebrating and i == _celeb_card:
			continue                                        # 연출 중인 카드는 별도 트윈이 제어
		var cx := strip.position.x + i * PAGE_W        # 카드 중심의 화면 x
		var d := clampf(absf(cx - center_x) / PAGE_W, 0.0, 1.0)
		var s := lerpf(1.0, SIDE_SCALE, d)
		cards[i].scale = Vector2(s, s)
		cards[i].modulate.a = lerpf(1.0, SIDE_ALPHA, d)
		cards[i].z_index = int(round((1.0 - d) * 10.0))


func _target_x(i: int) -> float:
	return VIEW_W * 0.5 - i * PAGE_W


func _nearest_index_at(x: float) -> int:
	var raw := roundi((VIEW_W * 0.5 - x) / PAGE_W)
	return clampi(raw, 0, maxi(stages.size() - 1, 0))


func go(i: int, animate: bool = true) -> void:
	var prev := index
	index = clampi(i, 0, maxi(stages.size() - 1, 0))
	if animate and index != prev:
		Sfx.play("tick")
	_kill_tween()
	var target := _target_x(index)
	if animate:
		_conceal_level()
		_tween = create_tween()
		_tween.tween_property(strip, "position:x", target, 0.34) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_callback(_reveal_level)
	else:
		strip.position.x = target
		_reveal_level()


## 드래그를 놓으면 관성만큼 더 흐른 뒤, 가장 가까운 카드에 자석처럼 달라붙는다(살짝 오버슈트).
func _snap_after_drag() -> void:
	var prev := index
	var projected := strip.position.x + _drag_vel * FLING
	index = _nearest_index_at(projected)
	if index != prev:
		Sfx.play("tick")
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(strip, "position:x", _target_x(index), 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_reveal_level)


# ---------- 입력 (드래그로 넘김 / 탭으로 선택·시작) ----------

func _on_gallery_input(event: InputEvent) -> void:
	if _launching or _celebrating or _intro_playing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			moved_amt = 0.0
			_drag_vel = 0.0
			_kill_tween()
		else:
			dragging = false
			if moved_amt < TAP_MOVE_THRESH:
				_handle_tap(event.position.x)
			else:
				_snap_after_drag()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			go(index + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			go(index - 1)
	elif event is InputEventMouseMotion and dragging and stages.size() > 1:
		var lo := _target_x(stages.size() - 1) - OVERSCROLL
		var hi := _target_x(0) + OVERSCROLL
		strip.position.x = clampf(strip.position.x + event.relative.x, lo, hi)
		moved_amt += absf(event.relative.x)
		_drag_vel = _drag_vel * 0.55 + event.relative.x * 0.45   # 최근 이동 속도(관성용)
		if moved_amt >= TAP_MOVE_THRESH:
			_conceal_level()                                    # 실제 이동이 시작되면 레벨 숨김


## 갤러리 로컬 x 위치에서 어느 카드를 눌렀는지 판정.
##  - 가운데 카드를 눌렀으면 → 시작(완성작=다시 플레이 / 박스=그 레벨 시작)
##  - 옆 카드를 눌렀으면 → 그 카드를 가운데로.
func _handle_tap(local_x: float) -> void:
	# 카드 i 중심의 화면 x = strip.position.x + i*PAGE_W → i 를 역산.
	var tapped := clampi(roundi((local_x - strip.position.x) / PAGE_W), 0, maxi(stages.size() - 1, 0))
	if tapped == index:
		_activate(index)
	else:
		go(tapped)


func _input(event: InputEvent) -> void:
	if _launching or _celebrating or _intro_playing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			go(index + 1)
		elif event.keycode == KEY_LEFT:
			go(index - 1)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_activate(index)


# ---------- 스테이지 시작 (텐션 팝 + 페이드 컷 전환) ----------

func _activate(i: int) -> void:
	if _launching or stages.is_empty():
		return
	_launching = true
	dragging = false
	_kill_tween()
	Sfx.play("ui")
	var stage := stages[i]
	var is_box: bool = stage["is_box"]

	# 화면 중앙에 카드 내용 복제본(popper)을 띄워 텐션있게 키웠다 줄이며 페이드아웃.
	# (갤러리는 clip 되므로 확대 연출은 별도 오버레이에서 한다.)
	var psize := _fit_size(stage["tex"], BOX_MAX, BOX_MAX) if is_box \
		else _fit_size(stage["tex"], PIC_MAX_W, PIC_MAX_H)
	var pop := TextureRect.new()
	pop.texture = stage["tex"]
	pop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if is_box:
		pop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		pop.stretch_mode = TextureRect.STRETCH_SCALE
		pop.material = _rounded_material(psize, CORNER_RADIUS)
	pop.size = psize
	pop.pivot_offset = psize * 0.5
	pop.position = Vector2(VIEW_W * 0.5, GALLERY_TOP + CARD_H * 0.5) - psize * 0.5
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pop)
	cards[i].visible = false                 # 원본 카드는 숨기고 복제본만 연출
	move_child(fade, get_child_count() - 1)   # 페이드는 popper 위로

	var t := create_tween()
	# 1) 텐션있게 커진다(오버슈트)
	t.tween_property(pop, "scale", Vector2(1.32, 1.32), 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2) 작아지며 사라진다 + 동시에 화면 페이드아웃
	t.tween_property(pop, "scale", Vector2(0.28, 0.28), 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(fade, "color:a", 1.0, 0.26)
	t.chain().tween_callback(_go_game.bind(int(stage["idx"])))


func _go_game(level_idx: int) -> void:
	SaveData.pending_level = level_idx        # main 이 이 레벨부터 시작
	get_tree().change_scene_to_file(GAME_SCENE)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


# ---------- 가운데 상단 레벨 표시 ----------

func _level_text(i: int) -> String:
	if i < 0 or i >= stages.size():
		return ""
	return "LEVEL %d" % (int(stages[i]["idx"]) + 1)


## 이동 시작 → 잠깐 사라진다(빠르게 축소+페이드아웃).
func _conceal_level() -> void:
	if level_label == null or _level_hidden:
		return
	_level_hidden = true
	_kill_label_tween()
	_label_tween = create_tween().set_parallel(true)
	_label_tween.tween_property(level_label, "modulate:a", 0.0, 0.12)
	_label_tween.tween_property(level_label, "scale", Vector2(0.7, 0.7), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## 멈춤 → 현재 레벨을 텐션있게(오버슈트) 다시 노출.
func _reveal_level() -> void:
	if level_label == null:
		return
	_level_hidden = false
	level_label.text = _level_text(index)
	_kill_label_tween()
	level_label.scale = Vector2(0.4, 0.4)
	level_label.modulate.a = 0.0
	_label_tween = create_tween().set_parallel(true)
	_label_tween.tween_property(level_label, "modulate:a", 1.0, 0.26)
	_label_tween.tween_property(level_label, "scale", Vector2.ONE, 0.36) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kill_label_tween() -> void:
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()


# ---------- 완성 연출 (게임에서 넘어온 직후 로비에서 재생) ----------

## 레벨 인덱스에 해당하는 "그림 카드"의 캐러셀 위치. 없으면 -1(박스이거나 미완성).
func _stage_index_of_level(level_idx: int) -> int:
	if level_idx < 0:
		return -1
	for i in stages.size():
		if not bool(stages[i]["is_box"]) and int(stages[i]["idx"]) == level_idx:
			return i
	return -1


## 방금 깬 그림 카드에서 흰 반짝이 + 흔들림 + "짠~" 팝을 재생하고, 끝나면 다음 카드로 스무스 스크롤.
func _celebrate_then_advance(i: int) -> void:
	_celebrating = true
	_celeb_card = i
	gallery.clip_contents = false                # 팝이 갤러리 밖으로 커져도 잘리지 않게
	var card := cards[i]
	var content := card_contents[i]
	card.scale = Vector2(0.72, 0.72)
	card.rotation = 0.0
	card.modulate.a = 1.0
	card.z_index = 30

	# 그림 위 흰 플래시(둥근 모서리) + 반짝이 파티클을 그림에 부착
	var flash := _make_flash(content.size)
	content.add_child(flash)
	var spark := _make_sparkles()
	spark.position = content.size * 0.5
	content.add_child(spark)

	await get_tree().create_timer(0.30).timeout  # 페이드인이 걷힌 뒤 시작

	spark.emitting = true
	Sfx.play("win")                               # "짠~" 완성 팡파레
	# 짠~ 팝(오버슈트) + 흰 반짝 플래시
	var t := create_tween()
	t.tween_property(card, "scale", Vector2(1.1, 1.1), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(flash, "modulate:a", 0.0, 0.55).from(0.9)
	t.tween_property(card, "scale", Vector2(1.0, 1.0), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 흔들 흔들(팝과 겹쳐 시작, 점점 잦아든다)
	var sh := create_tween()
	sh.tween_interval(0.16)
	for amp in [0.07, -0.055, 0.038, -0.022, 0.0]:
		sh.tween_property(card, "rotation", amp, 0.07).set_trans(Tween.TRANS_SINE)

	await t.finished
	await get_tree().create_timer(0.4).timeout

	if is_instance_valid(flash):
		flash.queue_free()
	card.rotation = 0.0
	gallery.clip_contents = true
	_celebrating = false
	_celeb_card = -1
	go(mini(i + 1, maxi(stages.size() - 1, 0)), true)   # 다음 카드로 스무스 스크롤


## 그림 위에 잠깐 덮는 흰색 반짝 플래시(둥근 모서리, 처음엔 투명).
func _make_flash(size_px: Vector2) -> Panel:
	var f := Panel.new()
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 1)
	sb.set_corner_radius_all(int(CORNER_RADIUS))
	f.add_theme_stylebox_override("panel", sb)
	f.modulate.a = 0.0
	return f


## 흰색 반짝이 파티클 버스트(one-shot). emitting=true 로 터뜨린다.
func _make_sparkles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _spark_tex()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.amount = 22
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 240)
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 360.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.angular_velocity_min = -260.0
	p.angular_velocity_max = 260.0
	p.z_index = 5
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	p.finished.connect(p.queue_free)             # 다 터지면 스스로 정리
	return p


## 반짝이용 부드러운 흰 점 텍스처(가장자리로 갈수록 투명).
func _spark_tex() -> Texture2D:
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s, s) * 0.5
	for y in s:
		for x in s:
			var dd := Vector2(x + 0.5, y + 0.5).distance_to(c) / (s * 0.5)
			var a := clampf(1.0 - dd, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
