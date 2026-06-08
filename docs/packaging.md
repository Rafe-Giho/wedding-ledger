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

현재 Swift 앱 번들 버전은 `1.2.0`이다.

## 코드 서명

릴리즈 앱 번들은 ad-hoc 코드 서명을 적용한다.

```bash
codesign --verify --deep --strict --verbose=2 "dist/축의대 장부.app"
```

Apple Developer ID 공증은 아직 적용하지 않았다. GitHub에서 내려받은 앱이 macOS에서 `손상되었기 때문에 열 수 없습니다` 또는 `Apple은 악성 코드가 없음을 확인할 수 없습니다`라고 표시되면 실제 파일 손상보다 Gatekeeper 격리 속성 때문일 가능성이 높다.

일반 macOS 앱처럼 DMG를 열고 Applications로 드래그하는 배포를 만들려면 [Apple Notarization](apple-notarization.md)을 완료한다.

권장 설치:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Rafe-Giho/wedding-ledger/main/scripts/install_macos.sh)"
```

이 명령은 릴리즈 zip을 터미널에서 내려받아 `~/Applications/축의대 장부.app`에 설치하고 quarantine 속성을 제거한 뒤 실행한다.

브라우저로 zip을 직접 받은 경우:

```bash
xattr -dr com.apple.quarantine "/Applications/축의대 장부.app"
```

또는 Finder에서 앱을 Control-클릭한 뒤 `열기`를 선택한다.

더블클릭만으로 완전히 경고 없는 배포를 하려면 Apple Developer ID 인증서로 서명하고 notarization을 완료해야 한다.

## 레거시

Python/Tkinter 버전은 레거시 브랜치 또는 기존 스크립트 참고용으로만 유지한다. 배포 기준은 Swift 앱이다.
