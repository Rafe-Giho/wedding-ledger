# macOS Packaging

## 목표

최종 배포물은 맥에서 더블클릭으로 실행할 수 있는 `.app` 번들이다.

## 현재 방식

Swift Package를 release 모드로 빌드한 뒤 macOS 앱 번들 구조로 묶는다.

```bash
python3 scripts/build_swift_macos_app.py
```

생성 결과:

```txt
dist/축의대 장부.app
```

## 요구 사항

- macOS 14 이상
- Swift 빌드 환경은 개발/패키징 시에만 필요
- 생성된 앱 번들은 앱 실행 시 Python이 필요하지 않음

## 버전

현재 Swift 앱 번들 버전은 `1.1.1`이다.

## 레거시

Python/Tkinter 버전은 레거시 브랜치 또는 기존 스크립트 참고용으로만 유지한다. 배포 기준은 Swift 앱이다.
