extends Node

## 절차적 효과음(SFX) — 외부 음원 파일 없이 코드로 파형을 합성해 AudioStreamWAV 로 굽는다.
##  - 그림맞추기 퍼즐의 포근한 톤에 맞춘 따뜻한 음색(마림바 / 우드블록 / 부드러운 벨).
##  - 웹(HTML5) 대상: 모든 재생은 유저 입력(탭·드래그)에서 비롯되므로 브라우저 오토플레이 제한에 안전하다.
##  - 동시 재생을 위해 AudioStreamPlayer 풀을 라운드로빈으로 돌린다(합체 연쇄음 등이 겹쳐 울리도록).
##
## 사용:  Sfx.play("snap")  /  Sfx.play_pitched("snap", 1.1)   (어디서든 전역 접근)

const MIX_RATE := 32000        # SFX 엔 충분한 샘플레이트(생성 비용 절감)
const VOICES := 10             # 동시 재생 플레이어 수

var _streams: Dictionary = {}                  # name -> AudioStreamWAV
var _cfg: Dictionary = {}                       # name -> {"vol": float, "pv": float}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_all()


# ---------- 재생 ----------

func play(name: String) -> void:
	play_pitched(name, 1.0)


## base_pitch 로 음정을 옮겨 재생(합체 연쇄 시 음을 조금씩 올리는 "콤보" 연출용). 미세 랜덤을 더해 반복이 기계적이지 않게.
func play_pitched(name: String, base_pitch: float) -> void:
	var s: AudioStreamWAV = _streams.get(name)
	if s == null:
		return
	var cfg: Dictionary = _cfg.get(name, {})
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = cfg.get("vol", 0.0)
	var pv: float = cfg.get("pv", 0.0)
	p.pitch_scale = maxf(0.05, base_pitch + randf_range(-pv, pv))
	p.play()


# ---------- 합성 빌딩 블록 ----------

## dur(초) 길이의 0으로 채운 모노 버퍼.
func _blank(dur: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(dur * MIX_RATE))
	return a


## 감쇠하는 사인 부분음을 버퍼에 더한다. f1>0 이면 f0→f1 로 glide(초) 동안 미끄러진다.
func _add_partial(buf: PackedFloat32Array, f0: float, amp: float, decay: float,
		start: float = 0.0, f1: float = -1.0, glide: float = 0.03, attack: float = 0.004) -> void:
	var n := buf.size()
	var s0 := maxi(int(start * MIX_RATE), 0)
	var phase := 0.0
	for i in range(s0, n):
		var t := float(i - s0) / float(MIX_RATE)
		var f := f0
		if f1 > 0.0:
			f = lerpf(f0, f1, clampf(t / maxf(glide, 0.0001), 0.0, 1.0))
		phase += TAU * f / float(MIX_RATE)
		var e := exp(-t / maxf(decay, 0.0001))
		var atk := clampf(t / maxf(attack, 0.0001), 0.0, 1.0)
		buf[i] += sin(phase) * amp * e * atk


## 감쇠하는 화이트노이즈를 더한다(타격 트랜지언트/바람소리용).
func _add_noise(buf: PackedFloat32Array, amp: float, decay: float, start: float = 0.0) -> void:
	var n := buf.size()
	var s0 := maxi(int(start * MIX_RATE), 0)
	for i in range(s0, n):
		var t := float(i - s0) / float(MIX_RATE)
		buf[i] += randf_range(-1.0, 1.0) * amp * exp(-t / maxf(decay, 0.0001))


## 끝부분을 짧게 페이드아웃해 잘림 클릭음을 없앤다.
func _finish(buf: PackedFloat32Array, fade: float = 0.005) -> void:
	var n := buf.size()
	var f := int(fade * MIX_RATE)
	for i in range(f):
		if i < n:
			buf[n - 1 - i] *= float(i) / float(f)


## 버퍼를 peak 로 정규화해 16비트 PCM AudioStreamWAV 로 만든다.
func _make(buf: PackedFloat32Array, peak: float = 0.9) -> AudioStreamWAV:
	_finish(buf)
	var mx := 0.0001
	for v in buf:
		mx = maxf(mx, absf(v))
	var g := peak / mx
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var s := clampf(buf[i] * g, -1.0, 1.0)
		data.encode_s16(i * 2, int(round(s * 32767.0)))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX_RATE
	st.stereo = false
	st.data = data
	return st


func _register(name: String, stream: AudioStreamWAV, vol: float, pv: float) -> void:
	_streams[name] = stream
	_cfg[name] = {"vol": vol, "pv": pv}


# ---------- 사운드 정의 ----------

func _build_all() -> void:
	_register("pick", _snd_pick(), -7.0, 0.06)
	_register("rotate", _snd_rotate(), -9.0, 0.05)
	_register("place", _snd_place(), -5.0, 0.05)
	_register("snap", _snd_snap(), -2.0, 0.05)
	_register("box_hit", _snd_box_hit(), -3.0, 0.08)
	_register("box_open", _snd_box_open(), -1.0, 0.03)
	_register("win", _snd_win(), -1.0, 0.0)
	_register("ui", _snd_ui(), -7.0, 0.03)
	_register("tick", _snd_tick(), -13.0, 0.08)


## 조각 집기 — 부드러운 나무 "톡".
func _snd_pick() -> AudioStreamWAV:
	var b := _blank(0.09)
	_add_partial(b, 430.0, 0.5, 0.03, 0.0, -1.0, 0.03, 0.002)
	_add_partial(b, 640.0, 0.22, 0.02)
	_add_noise(b, 0.12, 0.010)
	return _make(b)


## 조각 회전 — 짧게 위로 훑는 가벼운 스위시.
func _snd_rotate() -> AudioStreamWAV:
	var b := _blank(0.12)
	_add_partial(b, 300.0, 0.4, 0.06, 0.0, 560.0, 0.09, 0.003)
	_add_noise(b, 0.10, 0.05)
	return _make(b)


## 스냅 없이 그냥 내려놓기 — 낮고 포근한 "툭".
func _snd_place() -> AudioStreamWAV:
	var b := _blank(0.15)
	_add_partial(b, 180.0, 0.7, 0.06, 0.0, -1.0, 0.03, 0.002)
	_add_partial(b, 262.0, 0.25, 0.04)
	_add_noise(b, 0.10, 0.018)
	return _make(b)


## 조각 합체 — 만족스러운 마림바 "뽕"(살짝 음 떨어지는 말렛 타).
func _snd_snap() -> AudioStreamWAV:
	var b := _blank(0.24)
	_add_partial(b, 784.0, 0.70, 0.13, 0.0, 744.0, 0.05, 0.002)   # G5, 살짝 하강하는 몸통
	_add_partial(b, 1568.0, 0.22, 0.07)                            # 옥타브
	_add_partial(b, 2352.0, 0.10, 0.05)                            # 밝은 배음
	_add_partial(b, 392.0, 0.18, 0.16)                             # 따뜻한 저역
	_add_noise(b, 0.05, 0.006)                                     # 말렛 클릭
	return _make(b)


## 상자 타격 — 짧고 단단한 나무 노크.
func _snd_box_hit() -> AudioStreamWAV:
	var b := _blank(0.13)
	_add_partial(b, 150.0, 0.7, 0.05, 0.0, -1.0, 0.03, 0.001)
	_add_partial(b, 244.0, 0.3, 0.03)
	_add_noise(b, 0.40, 0.020)
	return _make(b)


## 상자 개봉 — 쪼개지는 소리 + 위로 번지는 반짝 차임.
func _snd_box_open() -> AudioStreamWAV:
	var b := _blank(0.55)
	_add_noise(b, 0.45, 0.045)
	_add_partial(b, 200.0, 0.5, 0.08, 0.0, -1.0, 0.03, 0.001)
	_add_partial(b, 880.0, 0.30, 0.28, 0.02)     # A5
	_add_partial(b, 1174.0, 0.28, 0.30, 0.08)    # D6
	_add_partial(b, 1568.0, 0.26, 0.32, 0.15)    # G6
	_add_partial(b, 2093.0, 0.20, 0.32, 0.22)    # C7
	return _make(b)


## 레벨 완성 — 상승 아르페지오 팡파레(C-E-G-C + 마지막 반짝).
func _snd_win() -> AudioStreamWAV:
	var b := _blank(0.95)
	var notes := [523.25, 659.25, 783.99, 1046.5]   # C5 E5 G5 C6
	for i in notes.size():
		var st := i * 0.11
		_add_partial(b, notes[i], 0.6, 0.5, st)
		_add_partial(b, notes[i] * 2.0, 0.16, 0.3, st)
	_add_partial(b, 1318.5, 0.28, 0.6, 0.44)        # E6 마지막 샤이머
	return _make(b)


## 버튼 / 스테이지 시작 — 부드러운 UI 블립.
func _snd_ui() -> AudioStreamWAV:
	var b := _blank(0.09)
	_add_partial(b, 660.0, 0.5, 0.03, 0.0, -1.0, 0.03, 0.002)
	_add_partial(b, 990.0, 0.2, 0.02)
	return _make(b)


## 스테이지 캐러셀 넘김 — 아주 작은 틱.
func _snd_tick() -> AudioStreamWAV:
	var b := _blank(0.06)
	_add_partial(b, 520.0, 0.35, 0.02, 0.0, -1.0, 0.03, 0.002)
	_add_noise(b, 0.08, 0.008)
	return _make(b)
