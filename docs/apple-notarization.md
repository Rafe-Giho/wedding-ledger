# Apple Notarization

## 목표

터미널 설치 명령 없이 일반 macOS 앱처럼 설치하려면 Apple Developer ID 서명과 notarization이 필요하다.

완료 후 설치 흐름:

1. GitHub Releases에서 `wedding-ledger-vX.Y.Z-macOS.dmg` 다운로드
2. DMG 열기
3. `축의대 장부.app`을 `Applications`로 드래그
4. 앱 실행

## 사용자가 준비해야 하는 것

- 유료 Apple Developer Program 계정
- Developer ID Application 인증서
- App Store Connect API Key

## GitHub Secrets

저장소의 `Settings > Secrets and variables > Actions`에 아래 값을 추가한다.

- `APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64`: Developer ID Application 인증서를 `.p12`로 내보낸 뒤 base64 인코딩한 값
- `APPLE_DEVELOPER_ID_APPLICATION_PASSWORD`: `.p12` 내보낼 때 설정한 비밀번호
- `APPLE_KEYCHAIN_PASSWORD`: GitHub Actions 임시 키체인에 사용할 임의의 긴 비밀번호
- `APP_STORE_CONNECT_KEY_ID`: App Store Connect API Key ID
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect Issuer ID
- `APP_STORE_CONNECT_PRIVATE_KEY`: `AuthKey_XXXXXXXXXX.p8` 파일 내용 전체

## p12 만들기

1. Xcode를 열고 `Settings > Accounts`에서 Apple ID로 로그인한다.
2. `Manage Certificates`에서 `Developer ID Application` 인증서를 만든다.
3. 키체인 접근 앱에서 해당 인증서와 개인키를 함께 선택한다.
4. `내보내기`로 `.p12` 파일을 만든다.
5. 아래 명령으로 base64 값을 복사한다.

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

## App Store Connect API Key 만들기

1. App Store Connect의 `Users and Access > Integrations`로 이동한다.
2. API Key를 생성하고 `.p8` 파일을 내려받는다.
3. Key ID, Issuer ID, `.p8` 파일 내용을 GitHub Secrets에 넣는다.

## 릴리즈 실행

GitHub 저장소의 `Actions > Release notarized macOS app`에서 `Run workflow`를 누르고 버전을 입력한다.

예:

```txt
v1.1.6
```

성공하면 GitHub Releases에 notarized DMG가 생성된다.

## 현재 한계

Apple Developer ID 인증서와 notarization 없이 브라우저 다운로드만으로 경고 없는 더블클릭 설치를 제공하는 방법은 없다. 현재 터미널 설치 스크립트는 이 제한을 우회하기 위한 임시 설치 경로다.
