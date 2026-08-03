# lOV

> 지인 간 금전 거래를 말로만 남기지 않고, 함께 확인할 수 있는 **돈 약속**으로 기록하는 Flutter + Firebase 앱입니다.

lOV는 빌리는 사람과 빌려주는 사람이 원금, 이자, 상환일과 메모를 명확히 확인하도록 돕습니다. 계약 링크 공유, 양측 동의, 진행 중 금액 집계, 상환 완료, AI 독촉 메시지와 알림까지 하나의 흐름으로 제공합니다.

## 주요 기능

- 이메일 회원가입 및 로그인
- Firebase 인증 세션을 이용한 자동 로그인
- 돈 약속 작성, 임시 저장, 수정, 공유 및 상대방 참여
- 카카오톡 카드 또는 시스템 공유를 통한 돈 약속 링크 전달
- 빌려주기·갚기 가상 송금 확인
- 빌린 돈과 빌려준 돈 합계 및 최근 돈 약속 표시
- 계약 상태별 목록, 삭제 및 사용자별 가리기
- Upstage Solar 기반 독촉 메시지 자동 작성
- 상대방 알림 전송과 미읽음 표시
- 이메일(ID) 변경 확인 메일 및 비밀번호 재설정 메일
- 라이트 모드와 다크 모드

## 프로그램 사용 흐름

```text
앱 실행
  ↓
Firebase 로그인 세션 확인
  ├─ 로그인 상태 → 메인 화면
  └─ 로그아웃 상태 → 로그인/회원가입
                         ↓
                    사용자 문서 생성
                         ↓
홈 ───────── 돈 약속 ───────── 설정
│              │                 ├─ 이메일 변경 확인
│              ├─ 새 돈 약속     ├─ 비밀번호 재설정
│              ├─ 계약 목록      ├─ 다크 모드
│              └─ 상세/송금       └─ 로그아웃
├─ 합계
├─ 최근 약속
└─ 알림
```

### 1. 회원가입과 로그인

1. 사용자 이름, 이메일, 비밀번호를 입력해 회원가입합니다.
2. Firebase Authentication 계정과 `users/{uid}` 문서가 생성됩니다.
3. 로그인 후에는 Firebase가 인증 세션을 복원하므로 로그아웃하기 전까지 자동 로그인됩니다.

### 2. 돈 약속 생성과 공유

1. **돈 약속** 탭의 추가 버튼을 누릅니다.
2. 작성자는 자동으로 돈을 빌리는 사람(`borrower`)이 됩니다.
3. 빌려주는 사람 이름, 원금, 상환일, 이자율과 메모를 입력합니다.
4. 임시 저장 시 상태는 `editing`입니다.
5. **돈 약속 보내기**를 누르면 작성자의 동의가 기록되고 상태가 `waiting_agreement`로 변경됩니다.
6. 카카오톡 카드, 다른 앱 공유 또는 링크 복사를 통해 상대방에게 전달합니다.

### 3. 상대방 참여와 계약 활성화

1. 상대방이 공유 링크를 열고 로그인합니다.
2. 비어 있던 `lender_uid`에 상대방 UID가 연결됩니다.
3. 상대방이 상세 화면에서 **빌려주기**를 확인합니다.
4. 양측 동의가 완료되면 상태가 `active`로 바뀌고 양쪽 사용자 합계에 최종 상환 금액이 한 번만 반영됩니다.

### 4. 독촉 메시지와 알림

1. 빌려준 사용자가 `active` 돈 약속 상세 화면에서 **독촉문자 보내기**를 누릅니다.
2. 직접 메시지를 입력하거나 AI 버튼으로 문구를 자동 생성합니다.
3. AI는 계약 당사자, 원금, 이자, 상환일, 총액과 메모를 바탕으로 한국어 문구를 만듭니다.
4. 전송된 메시지는 상대방의 Firestore 알림으로 저장됩니다.
5. 미읽음 알림이 있으면 홈 알림 버튼에 빨간 표시가 나타납니다.

### 5. 상환 완료

1. 빌린 사용자가 `active` 돈 약속에서 **갚기**를 선택합니다.
2. 가상 송금을 확인하면 양쪽 합계와 계약 ID 목록이 transaction으로 정리됩니다.
3. 계약 문서가 삭제되며 별도의 `completed` 상태는 저장하지 않습니다.

## 데이터 구조

Firebase 필드와 상태의 상세 규칙은 [`DATA_STRUCTURE.md`](DATA_STRUCTURE.md)를 기준으로 합니다.

### 사용자

```text
users/{uid}
├── name                  String
├── email                 String
├── borrowed_total        int
├── lent_total            int
├── active_contract_ids   List<String>
├── hidden_contract_ids   List<String>
└── notifications/{notification_id}
    ├── sender_uid        String
    ├── sender_name       String
    ├── contract_id       String
    ├── message           String
    ├── is_read           bool
    └── created_at        Timestamp
```

UID는 문서 연결과 권한 확인에만 사용하고 일반 화면에는 사용자 이름을 표시합니다.

### 돈 약속

```text
contracts/{contract_id}
├── lender_uid              String | null
├── lender_name             String
├── borrower_uid            String | null
├── borrower_name           String
├── creator_uid             String
├── principal_amount        int
├── interest_rate           double
├── interest_amount         int
├── total_repayment_amount  int
├── due_date                Timestamp
├── lender_agreed           bool
├── borrower_agreed         bool
├── status                  String
└── memo                    String
```

### 상태 흐름

| 저장값 | 의미 | 주요 동작 |
| --- | --- | --- |
| `editing` | 작성 중 | 작성자 수정 및 삭제 가능 |
| `waiting_agreement` | 상대방 동의 대기 | 링크 참여 및 빌려주기 확인 |
| `active` | 진행 중 | 합계 반영, 독촉 메시지, 상환 가능 |

```text
editing → waiting_agreement → active → 상환 transaction → 계약 문서 삭제
```

계약 생성·참여·활성화·삭제·상환처럼 여러 문서를 변경하는 작업은 Firestore batch 또는 transaction으로 처리합니다.

## 기술 스택

| 구분 | 사용 기술 |
| --- | --- |
| 앱 | Flutter 3.41.2, Dart 3.11.0 |
| 인증 | Firebase Authentication |
| 데이터 | Cloud Firestore |
| 링크/호스팅 | Firebase Hosting, Android/iOS URL Scheme |
| 공유 | Kakao Flutter SDK, `share_plus` |
| 생성형 AI | Upstage Solar Chat Completions API |
| 개발 보조 AI | OpenAI Codex, GPT-5 |

## Flutter로 프로젝트 열기

### 준비물

- Flutter SDK와 Dart SDK
- Android Studio 또는 VS Code + Flutter 확장
- Android 실행 시 Android SDK와 JDK 17
- iOS 실행 시 macOS, Xcode, CocoaPods
- 인터넷 연결
- AI 자동 작성을 시험하려면 Upstage API 키

현재 검증에 사용한 버전은 Flutter `3.41.2`, Dart `3.11.0`입니다. `pubspec.lock`이 반복해서 변경되지 않도록 팀과 같은 Flutter 버전을 사용하는 것을 권장합니다.

### 1. 저장소 받기

```bash
git clone https://github.com/tasong1122/AI-Builder-Sprint.git
cd AI-Builder-Sprint
```

### 2. 환경 확인과 패키지 설치

```bash
flutter doctor
flutter pub get
flutter devices
```

iOS에서 CocoaPods 설치가 필요하면 다음을 추가로 실행합니다.

```bash
cd ios
pod install
cd ..
```

### 3. 앱 실행

AI 자동 작성을 포함해 실행하려면 API 키를 저장소에 쓰지 않고 `dart-define`으로 전달합니다.

```bash
flutter run --dart-define=UPSTAGE_API_KEY=발급받은_API_KEY
```

특정 디바이스를 선택하려면:

```bash
flutter devices
flutter run -d 디바이스_ID --dart-define=UPSTAGE_API_KEY=발급받은_API_KEY
```

API 키 없이도 로그인, 돈 약속과 설정 기능은 실행할 수 있지만 **AI 자동 작성**은 사용할 수 없습니다.

필요한 경우 모델과 endpoint도 실행 시 덮어쓸 수 있습니다.

```bash
flutter run \
  --dart-define=UPSTAGE_API_KEY=발급받은_API_KEY \
  --dart-define=UPSTAGE_CHAT_MODEL=solar-pro2 \
  --dart-define=UPSTAGE_CHAT_ENDPOINT=https://api.upstage.ai/v1/solar/chat/completions
```

## 카카오톡 키 해시 안내

카카오톡 공유는 Android 앱의 서명 인증서에서 계산한 **키 해시**가 카카오 디벨로퍼스에 등록되어 있어야 합니다.

현재 Android `release` 설정도 개발 편의를 위해 각 컴퓨터의 `~/.android/debug.keystore`를 사용합니다. 따라서 심사위원이 소스코드를 받아 직접 빌드하면 팀원의 키 해시와 다른 값이 생성되며 카카오톡 공유 인증이 실패할 수 있습니다.

> 팀에서 빌드한 동일한 APK를 설치할 때는 심사위원 컴퓨터의 키 해시 등록이 필요하지 않습니다. 심사위원 컴퓨터에서 소스를 직접 빌드할 때만 해당 컴퓨터의 키 해시 등록이 필요합니다.

macOS/Linux에서는 다음 명령으로 Kakao용 Base64 키 해시를 확인할 수 있습니다.

```bash
keytool -exportcert \
  -alias AndroidDebugKey \
  -keystore ~/.android/debug.keystore \
  -storepass android \
  | openssl sha1 -binary \
  | openssl base64
```

키스토어가 없다면 Android 앱을 한 번 실행한 뒤 다시 확인합니다.

```bash
flutter run -d 안드로이드_디바이스_ID
```

심사 환경에서 카카오톡 공유를 직접 확인하려면 출력된 키 해시와 **“카카오 Android 키 해시 등록 요청”**이라는 내용을 아래 이메일로 보내 주세요. 확인 후 팀에서 카카오 디벨로퍼스 설정에 등록할 수 있습니다.

- 키 해시 등록 문의: **tasong1122@gmail.com**

키 해시 등록은 외부 카카오 설정 변경이므로 요청 즉시 반영되지 않을 수 있습니다. 가능한 경우 제출된 팀 빌드 APK를 이용해 확인해 주세요.

## AI 활용 증빙

### 1. 앱 기능에서의 AI API 사용

| 항목 | 설정 |
| --- | --- |
| 사용 위치 | 진행 중 돈 약속 상세 → 독촉문자 보내기 → AI 자동 작성 |
| 제공사 | Upstage |
| API | Solar Chat Completions, OpenAI 호환 응답 형식 |
| 모델 | `solar-pro2` |
| Endpoint | `https://api.upstage.ai/v1/solar/chat/completions` |
| Temperature | `0.6` |
| Max tokens | `500` |
| Timeout | `20초` |
| API 키 | `UPSTAGE_API_KEY` 환경값으로 주입, 저장소에 저장하지 않음 |

구현 파일: [`lib/services/upstage_ai_service.dart`](lib/services/upstage_ai_service.dart)

#### System prompt

```text
You write clear, polite Korean repayment reminder messages.
```

#### User prompt 템플릿

```text
다음 돈 약속 정보를 바탕으로 한국어 독촉 메세지를 작성해 줘.
친근하지만 예의 있는 톤으로 7~10줄 내외로 작성해 줘.
불필요한 설명 없이 바로 보낼 수 있는 메세지 본문만 출력해 줘.

[돈 약속 정보]
받는 사람: {recipientName}
보내는 사람: {senderName}
빌려주는 사람: {lenderName}
빌리는 사람: {borrowerName}
빌린 금액: {principalAmount}
갚을 날짜: {dueDate}
이자율: {interestRate 또는 없음}
이자 금액: {interestAmount 또는 없음}
총 갚을 금액: {totalRepaymentAmount}
메모: {memo 또는 없음}
```

AI에는 문구 생성에 필요한 표시 정보만 전달하며 Firebase UID, 비밀번호, 인증 토큰과 API 키는 prompt에 포함하지 않습니다. 생성 결과는 바로 전송하지 않고 입력창에 채워 사용자가 검토·수정한 뒤 직접 전송합니다.

### 2. 개발 과정에서의 코딩 에이전트 활용

개발 보조에는 **OpenAI Codex의 GPT-5 모델**을 사용했습니다. [`AGENTS.md`](AGENTS.md)에 파일 구조, 명명법, UI, Firebase 일관성, 권한과 검증 규칙을 제공하고 [`DATA_STRUCTURE.md`](DATA_STRUCTURE.md)를 데이터 스키마 기준으로 사용했습니다.

아래는 실제 개발 과정에서 사용한 대표 prompt입니다. 오탈자 수정이나 단순 확인 요청 등 작은 prompt는 제외했습니다.

<details>
<summary>설정 화면과 로그인 유지</summary>

```text
설정 화면 관련

이거 지금 설정 추가해서 id, 비밀번호 변경(이메일로 보내서 변경하도록),
다크모드 정도만 추가해줄 수 있어? 하단에 메뉴바도 좌측, 우측 상단만 둥글게 만들어주고.

다크모드에서 하늘색 버튼 색이 너무 쨍해서 눈이 아픈거같아. 색 좀 수정해줄수 있어?

로그인 상태 저장

지금 앱 껐다 키면 로그인 상태 저장이 안되는데 이거 저장되게 할 수 있어?
로그아웃 누르기 전까지는 자동으로 로그인 되게
```

결과: 설정 화면, 이메일 변경 확인 메일, 비밀번호 재설정 메일, 다크 모드, 둥근 상단 하단 바, Firebase 인증 세션 기반 자동 로그인이 구현되었습니다.

</details>

<details>
<summary>AI 독촉 메시지와 알림</summary>

```text
브랜치 feature/remainder 생성 > 요구사항 실행 > 원격으로 푸시

1. 내가 빌려준 돈 약속 상세 화면 아래에 독촉문자 보내기 버튼 생성
2. 버튼 클릭 시 다른 페이지로 가지 않고 메세지 화면 표시
3. 상대방 이름, 메세지 작성 칸, 보내기 버튼, AI 자동 작성 버튼 제공
4. AI는 돈 약속 상세 정보(당사자, 금액, 날짜, 이자, 총액, 메모)를 바탕으로 자동 작성
5. 상대방 알림으로 전송하고 미읽음이면 알림 버튼에 빨간 원 표시
```

결과: `feature/remainder` 브랜치와 관련 커밋, 독촉 메시지 bottom sheet, Upstage AI 자동 작성, Firestore 알림과 미읽음 표시가 구현되었습니다.

</details>

<details>
<summary>프로젝트 구조와 공통 코드</summary>

```text
AGENTS.md랑 DATA_STRUCTURE.md를 읽고 새로운 기준을 적용해.
권장 파일 구조에 따라 lib 아래 파일을 만들고,
screen을 제외한 공통 함수들을 작성해.
```

결과: 화면·위젯·모델·서비스·상수 분리, Firestore 모델 매핑, 인증/계약 서비스, 공통 버튼·입력창·계약 카드·상태 배지가 구성되었습니다.

</details>

<details>
<summary>UI 디버그와 실행 검증</summary>

```text
만든 위젯들의 디자인이랑 반응 확인을 위해 main.dart에 디버깅용으로 하나씩 만들어봐.
새로운 기준에 맞춰 main.dart에 시작하기 버튼을 만들고 flutter run을 한 번 실행해.
```

결과: 공통 위젯 상태와 반응을 확인하는 디버그 화면을 구성하고 시뮬레이터 실행, 정적 분석과 위젯 테스트를 수행했습니다.

</details>

### 3. AI 활용 추적 자료

- 프로젝트 개발 규칙: [`AGENTS.md`](AGENTS.md)
- Firebase 데이터 규칙: [`DATA_STRUCTURE.md`](DATA_STRUCTURE.md)
- 앱 내 AI 호출 구현: [`lib/services/upstage_ai_service.dart`](lib/services/upstage_ai_service.dart)
- AI 결과 검토 및 전송 UI: [`lib/screens/contract/detail_contract_screen.dart`](lib/screens/contract/detail_contract_screen.dart)
- 기능 단위 개발 이력: Git commit 및 `feature/remainder`, `feature/upstage-reminder-messages` 브랜치

## 테스트 및 검증 산출물

### 실행 명령

```bash
dart format .
flutter analyze
flutter test
```

### 2026-08-03 확인 결과

| 검증 | 결과 | 비고 |
| --- | --- | --- |
| `flutter analyze` | 통과 | `No issues found` |
| 로그인 화면 widget test | 통과 | 앱 이름과 로그인 UI 확인 |
| 메인 탭 widget test | 실패 | 테스트 환경에서 Firebase 기본 앱을 초기화하지 않아 `core/no-app` 발생 |
| 계약 작성 이동 widget test | 실패 | 위와 동일한 Firebase test setup 미구성 |

테스트 코드는 [`test/widget_test.dart`](test/widget_test.dart)에 있습니다. 현재 실패는 실제 앱의 Firebase 초기화 코드 문제가 아니라 `pumpWidget(MainScreen())` 단위 테스트에서 Firebase mock 또는 test initialization이 준비되지 않은 테스트 환경 문제입니다.

추가 검증 근거:

- 모델에서 Firestore 필드 타입과 필수값 검증
- 계약 생성·활성화·삭제·상환에 batch/transaction 사용
- 비동기 버튼 중복 입력 방지와 `mounted` 확인
- 사용자 화면에서 UID 대신 이름 표시
- API 키를 `dart-define`으로 분리

## 프로젝트 구조

```text
lib/
├── constants/   # 색상, 크기, 테마, Kakao 설정
├── models/      # 사용자, 계약, 알림 모델
├── screens/     # 인증, 홈, 계약, 설정 화면
├── services/    # 인증, 계약, 링크, 알림, Upstage AI
├── widgets/     # 공통 버튼, 입력창, 카드, 상태 배지
├── firebase_options.dart
└── main.dart
```

## 알려진 제한사항

- 실제 금융 이체가 아니라 MVP용 가상 송금 흐름입니다.
- Android release 빌드가 아직 정식 배포 keystore가 아닌 debug keystore를 사용합니다.
- 심사위원이 로컬 빌드한 Android 앱에서 카카오톡 공유를 시험하려면 해당 컴퓨터의 키 해시 등록이 필요합니다.
- Upstage API 키가 없으면 AI 자동 작성 기능을 사용할 수 없습니다.
- Firebase가 필요한 widget test에는 Firebase mock/test 초기화가 추가로 필요합니다.
