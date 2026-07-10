extends Node

## 진행 상황(완성한 스테이지) 저장/불러오기 전역 싱글톤.
## 스테이지 인덱스는 퍼즐 번호 - 1 (1.png → 0). 웹(itch.io)에서는 user:// 가 IndexedDB에 저장된다.

const SAVE_PATH := "user://progress.save"
const PUZZLE_DIR := "res://assets/puzzles"
const PUZZLE_EXTS := ["png", "jpg", "jpeg", "webp", "svg"]

var _completed: Dictionary = {}          # level_idx(int) -> true (집합처럼 사용)

## 메뉴에서 고른 "시작할 레벨" — 씬 전환 시 main 에 넘기는 임시값(저장하지 않는다).
var pending_level := 0

## 방금 완성한 레벨 — 로비에서 완성 연출(반짝+짠)을 재생하려고 넘기는 임시값. -1 이면 없음(저장 안 함).
var just_completed := -1


func _ready() -> void:
	_load()


## idx 스테이지를 완성으로 표시하고 저장한다.
func mark_completed(idx: int) -> void:
	if _completed.has(idx):
		return
	_completed[idx] = true
	_save()


func is_completed(idx: int) -> bool:
	return _completed.has(idx)


## 완성한 스테이지 인덱스 목록(오름차순).
func completed_indices() -> Array[int]:
	var out: Array[int] = []
	for k in _completed.keys():
		out.append(int(k))
	out.sort()
	return out


## 모든 진행 상황 삭제.
func reset() -> void:
	_completed.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)   # user:// 경로 그대로 넘긴다(웹 IndexedDB에서도 동작)


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(completed_indices()))
	f.close()


func _load() -> void:
	_completed.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if data is Array:
		for v in data:
			_completed[int(v)] = true


## assets/puzzles 의 1.png, 2.png ... 를 순서대로 찾아 Texture2D 배열로 돌려준다.
## main(게임)과 menu(로비)가 같은 레벨 목록을 보도록 스캔을 여기 한 곳에 둔다.
func scan_puzzle_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var i := 1
	while i <= 99:
		var found: Texture2D = null
		for e in PUZZLE_EXTS:
			var p := "%s/%d.%s" % [PUZZLE_DIR, i, e]
			if ResourceLoader.exists(p):
				found = load(p)
				break
		if found == null:
			break
		out.append(found)
		i += 1
	return out
