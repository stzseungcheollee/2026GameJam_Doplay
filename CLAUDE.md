# 2026 게임잼 프로젝트 (Godot 4.7 웹 게임)

## 핵심 제약
- **웹(HTML5) 타겟** — 렌더러는 반드시 `gl_compatibility` 유지. Forward+/Mobile로 바꾸면 웹 내보내기가 깨짐.
- 내보내기 프리셋 "Web"은 **스레드 미사용**(`variant/thread_support=false`). COOP/COEP 헤더 없는 호스팅(itch.io 기본)에서도 동작하기 위함. 바꾸지 말 것.
- 웹에서 오디오는 첫 유저 입력 이후에만 재생됨. 저장 데이터는 `user://` 경로만 사용.

## 도구 경로
- Godot 에디터: `D:\Program Files\Godot\Godot_v4.7-stable_win64.exe`
- CLI(콘솔 출력용): `D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe` — PATH에 `godot`으로 등록됨
- 내보내기 템플릿: `%APPDATA%\Godot\export_templates\4.7.stable\` 설치 완료

## 명령
```powershell
godot --headless --path . --import                                      # 리소스 임포트 (CI/검증용)
godot --headless --path . --export-release "Web" builds/web/index.html  # 웹 내보내기
godot --headless --path . --export-debug "Web" builds/web/index.html    # 디버그 내보내기
node tools/serve.mjs                                                    # 로컬 테스트 (http://localhost:8060)
```

## 구조
- `scenes/menu.tscn` — 타이틀/메인 화면 (project.godot의 run/main_scene). "게임하기" → `scenes/main.tscn`
- `scenes/main.tscn` — 퍼즐 게임 씬
- `scripts/` GDScript, `assets/` 리소스, `autoload/` 전역 싱글톤, `builds/` 산출물(gitignore)
- GDScript 스타일: 탭 들여쓰기, 타입 힌트 사용 (`func _ready() -> void:`)
