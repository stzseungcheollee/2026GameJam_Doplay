# 2026 게임잼 — Godot 웹 게임

Godot 4.7 기반 웹(HTML5) 게임 프로젝트. 주제 확정 전 기본 세팅 완료 상태.

## 환경

| 항목 | 값 |
|---|---|
| 엔진 | Godot 4.7 stable — `D:\Program Files\Godot\Godot_v4.7-stable_win64.exe` |
| 렌더러 | **GL Compatibility** (웹 내보내기 필수 — Forward+/Mobile은 웹 미지원) |
| 해상도 | 720×1280 (세로뷰), `canvas_items` 스트레치 + `expand` |
| 내보내기 | Web 프리셋 → `builds/web/index.html` (스레드 미사용 — itch.io 등에 헤더 설정 없이 업로드 가능) |

## 폴더 구조

```
scenes/    씬 파일 (.tscn) — 메인 씬: scenes/main.tscn
scripts/   GDScript
assets/    sprites / audio / fonts
autoload/  전역 싱글톤 (프로젝트 설정 > Autoload에 등록)
tools/     개발용 스크립트
builds/    내보내기 산출물 (git 제외)
```

## 자주 쓰는 명령

```powershell
# 에디터 열기
godot -e --path .

# 게임 실행 (에디터 없이)
godot --path .

# 웹 내보내기 (릴리즈)
godot --headless --path . --export-release "Web" builds/web/index.html

# 로컬에서 웹 빌드 테스트 → http://localhost:8060
node tools/serve.mjs
```

`godot` 명령은 `D:\Program Files\Godot`의 셔틀 스크립트로, 사용자 PATH에 등록되어 있음.
에디터에서는 우측 상단 **원격 디버그 > Run in Browser** 로도 바로 테스트 가능.

## 웹 빌드 주의사항 (게임잼 체크리스트)

- **오디오는 유저 입력 후 재생됨** — 브라우저 정책상 첫 클릭/키 입력 전엔 소리가 안 남. 시작 화면("클릭해서 시작")을 넣을 것.
- **용량 관리** — 웹은 로딩이 곧 이탈률. 이미지·오디오 압축(ogg 권장), 큰 폰트 임베드 주의.
- `OS.shell_open()` 외 파일시스템 접근 불가, 저장은 `user://` (IndexedDB로 저장됨).
- 종료 버튼(`get_tree().quit()`) 무의미 — 웹에선 UI에서 빼기.
- itch.io 업로드: `builds/web/` 내용물을 zip으로 묶어 업로드 → "This file will be played in the browser" 체크.
- 모바일 브라우저도 지원하려면 터치 입력(`InputEventScreenTouch`) 고려.
