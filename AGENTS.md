# Flutter 프로젝트 AI 개발 지침

이 프로젝트는 지인 간 금전 거래의 합의 내용을 명확하게 기록하고, 돈을 빌려주고 갚는 과정에서 발생할 수 있는 오해와 관계 훼손을 줄이기 위한 Flutter + Firebase MVP 서비스이다.

AI 코딩 에이전트는 기능 구현뿐 아니라 기존 구조 보존, 화면 흐름, UI 통일성, Firebase 데이터 일관성을 중요하게 고려해야 한다.

Firebase 필드명, 자료형, 상태값, 데이터 변경 규칙은 반드시 `DATA_STRUCTURE.md`를 기준으로 한다.

---

# 1. 기본 작업 원칙

* 코드를 수정하기 전에 관련 파일과 현재 프로젝트 구조를 먼저 확인한다.
* 기존 기능과 파일 구조를 최대한 유지한다.
* 요청받지 않은 파일, 화면, 함수, Firebase 설정을 임의로 삭제하지 않는다.
* 요청받지 않은 대규모 리팩터링을 수행하지 않는다.
* 수정 범위는 요청한 기능과 직접 관련된 부분으로 제한한다.
* 이미 존재하는 함수, 위젯, 모델, 상수를 중복 생성하지 않는다.
* `pubspec.yaml`과 현재 설치된 패키지를 확인한 뒤 코드를 작성한다.
* 새로운 데이터 필드나 상태값을 임의로 추가하지 않는다.
* 화면 구현과 데이터 구현이 충돌하면 `DATA_STRUCTURE.md`의 데이터 규칙을 우선한다.

작업 우선순위는 다음과 같다.

```text
기능 정상 동작
→ 기존 코드 보존
→ Firebase 데이터 일관성
→ 사용자 데이터 보호
→ 오류 및 로딩 처리
→ 화면 이동 흐름
→ 반응형 UI
→ UI 통일성
→ 코드 길이와 파일 분리
```

---

# 2. 파일 및 코드 구조

하나의 화면은 하나의 `.dart` 파일로 분리한다.

화면 파일은 가능하면 300~500줄 이내로 유지한다. 500줄을 크게 초과하면 다음 요소를 별도 파일로 분리한다.

* 반복해서 사용하는 위젯
* 데이터 모델
* Firebase 및 Firestore 처리 함수
* 공통 디자인 요소
* 공통 상수
* 복잡한 입력 폼
* 화면과 분리 가능한 비즈니스 로직

권장 구조는 다음과 같다.

```text
lib/
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── sign_up_screen.dart
│   ├── main/
│   │   └── main_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   └── contract/
│       ├── contract_list_screen.dart
│       ├── create_contract_screen.dart
│       ├── detail_contract_screen.dart
│       └── mock_transfer_screen.dart
├── widgets/
│   ├── common_button.dart
│   ├── common_text_field.dart
│   ├── contract_card.dart
│   └── contract_status_badge.dart
├── models/
│   ├── user_model.dart
│   └── contract_model.dart
├── services/
│   ├── auth_service.dart
│   └── contract_service.dart
├── constants/
│   ├── app_colors.dart
│   ├── app_dimensions.dart
│   └── app_text_styles.dart
└── main.dart
```

한 번만 사용하는 매우 짧은 위젯은 불필요하게 별도 파일로 분리하지 않는다.

---

# 3. 이름 작성 규칙

Dart 함수명, 변수명, 매개변수명, 상수명에는 `lowerCamelCase`를 사용한다.

```dart
final principalAmount = 100000;
final borrowerUid = currentUser.uid;
final userName = userData['name'];

void saveContractData() {
  // 계약 데이터를 저장한다.
}
```

클래스명과 enum 이름은 Dart 언어 규칙에 따라 `PascalCase`를 사용한다.

```dart
class ContractListScreen extends StatefulWidget {
  const ContractListScreen({super.key});
}
```

파일명과 Firestore 필드명에는 `snake_case`를 사용한다.

```text
create_contract_screen.dart
principal_amount
borrower_uid
```

Firestore 필드명은 `DATA_STRUCTURE.md`에 정의된 이름을 그대로 사용하며, Dart 변수명으로 가져올 때에는 `lowerCamelCase`로 작성한다.

---

# 4. 함수 및 주석 규칙

모든 주요 함수 바로 위에는 해당 함수의 목적과 동작을 한 줄 또는 두 줄로 요약한 주석을 작성한다.

```dart
// 현재 로그인한 사용자의 계약 목록을 불러온다.
Future<List<ContractModel>> get_user_contracts() async {
  // ...
}
```

```dart
// 계약을 활성화하고 양쪽 사용자의 총액을 transaction으로 갱신한다.
Future<void> activate_contract() async {
  // ...
}
```

코드 문법을 그대로 설명하는 불필요한 줄 단위 주석은 남발하지 않는다.

---

# 5. 데이터 구조 기준

Firebase 및 Firestore 데이터 구조는 `DATA_STRUCTURE.md`를 최우선 기준으로 사용한다.

최상위 컬렉션은 다음 두 개를 사용한다.

```text
users
contracts
```

기본 사용자 문서 구조는 다음과 같다.

```text
users/{uid}
├── name
├── email
├── borrowed_total
├── lent_total
├── active_contract_ids
└── hidden_contract_ids
```

기본 계약 문서 구조는 다음과 같다.

```text
contracts/{contract_id}
├── lender_uid
├── lender_name
├── borrower_uid
├── borrower_name
├── creator_uid
├── principal_amount
├── interest_rate
├── interest_amount
├── total_repayment_amount
├── due_date
├── lender_agreed
├── borrower_agreed
├── status
└── memo
```

다음 이전 필드명은 사용하지 않는다.

```text
total_borrowed_amount
total_lent_amount
contract_ids
userName
lenderUid
borrowerUid
```

---

# 6. 사용자 계정 및 이름 규칙

Firebase Authentication의 UID는 사용자를 내부적으로 구분하기 위한 고유 식별자로만 사용한다.

화면에는 UID를 직접 표시하지 않고 사용자 이름을 표시한다.

UID는 다음 용도로만 사용한다.

* Firestore 문서 연결
* 계약 참여자 확인
* 로그인한 사용자 권한 확인
* Security Rules 검증
* 사용자 문서 조회
* 동일한 이름의 사용자 구분

사용자 이름만으로 권한을 판단하지 않는다.

회원가입 성공 후 Firebase Authentication에서 자동 생성된 UID를 `users/{uid}` 문서 ID로 사용한다.

비밀번호는 Firestore에 저장하지 않는다.

---

# 7. 전체 화면 구조

## 1. 로그인 화면

파일:

```text
login_screen.dart
```

기능:

* 이메일 입력
* 비밀번호 입력
* 로그인 버튼
* 회원가입 화면으로 이동
* 입력값이 비어 있으면 안내 메시지 표시
* 로그인 중에는 버튼 중복 터치 방지
* 로그인 성공 시 `main_screen.dart`로 이동
* 로그인 실패 시 오류 메시지 표시
* 로그인 성공 후 뒤로가기로 로그인 화면에 돌아오지 않도록 처리

로그인 성공 시 `Navigator.pushReplacement`, `pushAndRemoveUntil` 또는 기존 라우팅 방식과 동등한 처리를 사용한다.

---

## 2. 회원가입 화면

파일:

```text
sign_up_screen.dart
```

입력값:

* 사용자 이름
* 이메일
* 비밀번호
* 비밀번호 확인

기능:

* 이메일 형식 확인
* 비밀번호와 비밀번호 확인 값 일치 확인
* Firebase Authentication을 통한 회원가입
* 회원가입 성공 시 UID 자동 생성
* 생성된 UID를 Firestore `users` 문서 ID로 사용
* Firestore에 사용자 정보 저장
* 회원가입 성공 시 `main_screen.dart`로 이동
* 회원가입 실패 시 오류 메시지 표시
* 처리 중 버튼 중복 터치 방지

Firestore 초기값:

```json
{
  "name": "권태준",
  "email": "user@example.com",
  "borrowed_total": 0,
  "lent_total": 0,
  "active_contract_ids": [],
  "hidden_contract_ids": []
}
```

---

## 3. 메인 화면

파일:

```text
main_screen.dart
```

기능:

* 로그인 이후 진입하는 메인 화면
* 하단 네비게이션 바 관리
* 홈 탭과 계약 탭 전환
* 송금 완료 후 돌아왔을 때 홈 탭이 선택되도록 처리

하단 탭:

* 홈
* 계약

홈 탭 선택 상태를 생성자 매개변수나 명확한 라우팅 결과로 전달할 수 있다.

---

## 4. 홈 탭

파일:

```text
home_screen.dart
```

피그마 구성:

* 빌린 돈 합계
* 빌려준 돈 합계
* 최근 계약 목록
* 몇 건 더보기
* 접기

기능:

* 현재 로그인한 사용자의 계약 조회
* `active` 상태의 계약만 조회
* `editing`, `waiting_agreement` 상태는 합계에서 제외
* 사용자가 빌린 계약 금액 총합 표시
* 사용자가 빌려준 계약 금액 총합 표시
* 최근 계약 목록에 `active` 계약만 표시
* 처음에는 최근 계약 3건만 표시
* 더보기 버튼을 누르면 전체 표시
* 더보기 버튼에 남은 계약 수 표시
* 접기 버튼을 누르면 다시 3건만 표시
* 계약 클릭 시 `detail_contract_screen.dart`로 이동

합계는 `users/{uid}`의 `borrowed_total`, `lent_total`을 기준으로 표시한다.

최근 계약 카드 표시 정보:

* 상대방 사용자 이름
* 빌림 또는 빌려줌
* 계약 금액
* 갚을 날짜

예시:

```text
김지수
빌림 · 1,000,000원
2026년 8월 10일까지
```

계약 정렬 기준이 기존 코드에 없다면 `due_date` 또는 명확히 정의된 현재 프로젝트 기준을 사용한다. 임의의 생성일 필드는 추가하지 않는다.

---

## 5. 계약 탭

파일:

```text
contract_list_screen.dart
```

표시 상태:

* `editing`
* `waiting_agreement`
* `active`

기능:

* 현재 사용자가 연결된 계약 표시
* `hidden_contract_ids`에 포함된 계약은 표시하지 않음
* 계약 카드에 상대방 이름, 역할, 금액, 갚을 날짜, 상태 표시
* 일반 터치 시 상태에 따라 다른 화면으로 이동
* 길게 누르면 삭제 또는 가리기 메뉴 표시
* 우측 하단 `+` 버튼 터치 시 `create_contract_screen.dart`로 이동

상태 표시 문구:

```text
editing → 편집중
waiting_agreement → 동의 대기중
active → 진행중
```

계약 카드 예시:

```text
김지수
빌림 · 1,000,000원
2026년 8월 10일까지
동의 대기중
```

일반 터치 동작:

### editing

* `create_contract_screen.dart`로 이동
* 기존 계약 데이터를 불러옴
* 새 문서를 만들지 않고 기존 계약을 수정

### waiting_agreement

* `detail_contract_screen.dart`로 이동

### active

* `detail_contract_screen.dart`로 이동

길게 누르기 동작:

### editing

* 작성자만 삭제 가능
* Firestore 계약 문서 삭제
* 연결된 사용자의 `active_contract_ids`에서 계약 ID 제거
* `hidden_contract_ids`에서도 계약 ID 정리

### waiting_agreement

* 계약 작성자만 삭제 가능
* 상대방이 참여한 계약은 일반 참여자가 삭제하지 못하도록 처리
* 작성자가 삭제하면 계약 문서와 연결된 양쪽 사용자의 계약 ID 목록에서 제거

### active

* 계약 삭제 불가
* 현재 사용자에게만 가리기 가능
* 가리기 시 현재 사용자의 `hidden_contract_ids`에 계약 ID 추가
* 계약 문서는 삭제하지 않음
* 상대방 화면에는 계속 표시

---

## 6. 계약 작성 화면

파일:

```text
create_contract_screen.dart
```

입력값:

* 현재 사용자의 역할
* 빌려주는 사람
* 빌리는 사람
* 빌릴 금액
* 갚을 날짜
* 이자 여부
* 이자율
* 메모가 UI에 존재하면 메모

역할 선택:

* 나는 돈을 빌려요
* 나는 돈을 빌려줘요

기능:

* 현재 로그인한 사용자의 역할 선택
* 빌려요 선택 시 현재 사용자를 borrower로 설정
* 빌려줘요 선택 시 현재 사용자를 lender로 설정
* 상대방 UID는 공유 링크로 접속한 뒤 등록 가능
* 빌릴 금액 입력
* 갚을 날짜 선택
* 이자 스위치 제공
* 이자 off 시 `interest_rate`, `interest_amount`를 0으로 저장
* 이자 on 시 이자율 직접 입력
* 필수 입력값 검증
* 작성 중에는 `status = editing`
* 기존 편집중 계약을 열면 기존 데이터 불러오기
* 계약 보내기 시 기존 문서를 저장 또는 갱신
* 계약 보내기 후 `status = waiting_agreement`
* 공유용 딥링크 또는 앱링크 생성
* 시스템 공유창 실행

계약 보내기 처리 순서:

```text
입력값 검증
→ Firestore 계약 데이터 저장
→ status를 waiting_agreement로 변경
→ 공유용 계약 링크 생성
→ 시스템 공유창 실행
```

공유 링크 생성에 필요한 패키지가 현재 프로젝트에 없다면 임의로 추가하지 말고 필요한 패키지와 플랫폼 설정을 먼저 설명한다.

---

## 7. 계약 상세보기 화면

파일:

```text
detail_contract_screen.dart
```

기능:

* 계약 작성 화면과 비슷한 형식으로 계약 내용 표시
* 모든 입력값 수정 불가
* 빌려주는 사람 표시
* 빌리는 사람 표시
* 계약 금액 표시
* 갚을 날짜 표시
* 이자율 표시
* 계약 상태 표시
* 현재 로그인 UID와 상태에 따라 하단 버튼 표시

버튼 표시 조건:

```text
status == waiting_agreement
그리고 현재 사용자 UID == lender_uid
→ 빌려주기 또는 송금하기 버튼 표시

status == active
그리고 현재 사용자 UID == borrower_uid
→ 갚기 또는 송금하기 버튼 표시

그 외
→ 추가 버튼 표시하지 않음
```

빌려주기 버튼은 `mock_transfer_screen.dart`로 이동하며, 상세 화면에서는 계약 상태를 직접 변경하지 않는다.

갚기 버튼도 `mock_transfer_screen.dart`로 이동하며, 상세 화면에서는 계약 삭제나 총액 변경을 직접 수행하지 않는다.

---

## 8. 송금 화면

파일:

```text
mock_transfer_screen.dart
```

기능:

* 실제 금융 송금이 발생하지 않는 MVP용 가상 송금 화면
* 이전 화면에서 전달받은 계약 데이터 표시
* 접속 경로에 따라 문구와 송금 대상 변경
* 송금 금액은 계약의 `total_repayment_amount`로 고정
* 확인 버튼 제공
* 확인 시 Firestore 데이터 변경
* 완료 후 `main_screen.dart`의 홈 탭으로 이동
* 뒤로가기로 송금 화면에 다시 돌아오지 않도록 처리

### 빌려주기 경로

표시 예시:

```text
김지수 님에게
1,000,000원을 빌려주시겠습니까?
```

확인 버튼:

```text
빌려주기 확인
```

확인 처리:

* `lender_agreed = true`
* `borrower_agreed`가 이미 true이면 `status = active`
* 양쪽 사용자의 `active_contract_ids`에 계약 ID 추가
* borrower의 `borrowed_total` 증가
* lender의 `lent_total` 증가
* `main_screen.dart`의 홈 탭으로 이동

총액 증가는 계약이 처음 `active`가 되는 순간에만 한 번 수행한다.

### 갚기 경로

표시 예시:

```text
권태준 님에게
1,000,000원을 갚으시겠습니까?
```

확인 버튼:

```text
갚기 확인
```

확인 처리:

* 양쪽 사용자의 `active_contract_ids`에서 계약 ID 제거
* 양쪽 사용자의 `hidden_contract_ids`에서 계약 ID 제거
* borrower의 `borrowed_total` 감소
* lender의 `lent_total` 감소
* Firestore 계약 문서 삭제
* `main_screen.dart`의 홈 탭으로 이동

여러 문서 변경은 transaction 또는 batch write로 묶는다.

---

# 8. 전체 화면 이동 구조

```text
login_screen.dart
├── sign_up_screen.dart
└── main_screen.dart
    ├── home_screen.dart
    │   └── detail_contract_screen.dart
    │       └── mock_transfer_screen.dart
    └── contract_list_screen.dart
        ├── create_contract_screen.dart
        └── detail_contract_screen.dart
            └── mock_transfer_screen.dart
```

로그인, 회원가입, 송금 완료처럼 이전 화면으로 돌아가면 안 되는 이동은 기존 네비게이션 스택을 제거하거나 교체한다.

---

# 9. 계약 상태 처리 규칙

상태 저장값은 다음 세 가지만 사용한다.

```text
editing
waiting_agreement
active
```

## editing

* 계약 작성 또는 임시 저장 상태
* 계약 작성 화면으로 이동
* 작성자만 삭제 가능

## waiting_agreement

* 계약 작성이 끝나고 상대방 동의를 기다리는 상태
* 계약 상세보기 화면으로 이동
* 현재 사용자가 lender일 때만 빌려주기 버튼 표시

## active

* 양쪽 동의가 완료된 진행 중 계약
* borrower에게만 갚기 버튼 표시
* 일반 삭제 불가
* 사용자별 가리기만 가능

`completed` 상태는 사용하지 않는다. 상환 완료 시 총액과 계약 ID 목록을 정리하고 계약 문서를 삭제한다.

---

# 10. 계약 역할 처리 규칙

## borrower

* 돈을 빌리는 사람
* `active` 계약에서 갚기 버튼 사용 가능
* 계약 활성화 시 `borrowed_total`에 `total_repayment_amount` 반영

## lender

* 돈을 빌려주는 사람
* `waiting_agreement` 계약에서 빌려주기 버튼 사용 가능
* 계약 활성화 시 `lent_total`에 `total_repayment_amount` 반영

화면에는 UID를 직접 표시하지 않고 사용자 이름을 표시한다.

---

# 11. 로딩, 오류 및 빈 상태 처리

Firebase를 사용하는 모든 화면은 다음 상태를 처리한다.

* 로딩 중
* 데이터 없음
* 로그인되지 않은 상태
* 사용자 문서 없음
* 권한 오류
* 네트워크 오류
* Firebase 오류
* 잘못된 문서 데이터
* 삭제되었거나 존재하지 않는 계약

오류 메시지에 UID, Firestore 경로, 스택 트레이스 등을 그대로 노출하지 않는다.

예시:

```text
계약 정보를 불러오지 못했습니다.
잠시 후 다시 시도해 주세요.
```

빈 상태에는 다음 행동을 안내한다.

```text
아직 등록된 계약이 없습니다.
새 계약을 작성해 보세요.
```

---

# 12. 비동기 처리 규칙

비동기 작업 중에는 버튼 중복 터치를 막는다.

```dart
bool isSubmitting = false;
```

비동기 작업 이후 `BuildContext`를 사용할 때에는 `mounted`를 확인한다.

```dart
if (!mounted) {
  return;
}
```

`TextEditingController`, `FocusNode`, `AnimationController`는 `dispose()`에서 정리한다.

계약 활성화, 상환 완료, 계약 삭제처럼 여러 문서를 함께 변경하는 작업은 transaction 또는 batch write를 사용한다.

---

# 13. UI 규칙

전체 화면의 기본 배경색은 흰색으로 통일한다.

```dart
const Color appBackgroundColor = Color(0xFFFFFFFF);
```

밝은 구분 색상:

```dart
const Color sectionBackgroundColor = Color(0x80A0EAF7);
```

회색 구분 색상:

```dart
const Color neutralSectionColor = Color(0x33787878);
```

강조 색상:

```dart
const Color highlightColor = Color(0xFF48E5FD);
```

주요 카드와 큰 버튼의 기본 모서리 반경:

```dart
const double defaultBorderRadius = 34;
```

오브젝트의 위치와 크기를 사용자가 직접 조정하기 쉽도록 주요 값을 상수로 분리한다.

```dart
const double contractCardTop = 120;
const double contractCardLeft = 24;
const double contractCardRight = 24;
```

정확한 배치가 필요한 요소에는 `Stack`과 `Positioned`를 사용할 수 있지만, 목록과 입력 폼은 반응형 레이아웃과 스크롤을 우선한다.

---

# 14. 상태 관리 및 패키지 규칙

MVP에서는 기본적으로 다음 방식을 사용한다.

* `StatefulWidget`
* `setState`
* `StreamBuilder`
* `FutureBuilder`
* Firebase 실시간 스트림

Provider, Riverpod, Bloc 등 새로운 상태 관리 패키지는 명시적인 요청 없이 추가하지 않는다.

새 Flutter 패키지를 임의로 추가하지 않는다. 딥링크, 앱링크, 시스템 공유 기능에 패키지가 필요하다면 다음 내용을 먼저 설명한다.

* 필요한 이유
* 사용할 패키지
* `pubspec.yaml` 변경 내용
* Android 및 iOS 설정
* 대체 구현 가능 여부

---

# 15. 보안 및 권한 규칙

* 사용자 이름이 아니라 UID로 권한을 확인한다.
* 사용자 문서는 본인만 수정할 수 있어야 한다.
* 계약은 계약 당사자와 공유 링크 참여 흐름에 필요한 사용자만 접근할 수 있어야 한다.
* `editing`, `waiting_agreement` 계약 삭제는 작성자만 가능하다.
* `active` 계약은 일반 삭제할 수 없다.
* 한 사용자가 상대방의 동의 값을 임의로 변경하지 못하게 한다.
* 클라이언트에서 버튼을 숨기는 것만으로 권한 처리를 끝내지 않고 Security Rules도 적용한다.
* 비밀번호, 인증 토큰, API 비밀키를 Firestore나 코드에 직접 저장하지 않는다.

---

# 16. 코드 수정 후 검증

코드 작성 또는 수정 후 다음 내용을 확인한다.

* import 오류가 없는가
* 사용되지 않는 변수와 함수가 없는가
* null safety 오류가 없는가
* Dart 함수명과 변수명이 `lowerCamelCase`인가
* 파일명과 Firestore 필드명이 `snake_case`인가
* 클래스명이 `PascalCase`인가
* 주요 함수 위에 행동 요약 주석이 있는가
* 최신 Firestore 필드명을 사용하는가
* UID가 화면에 노출되지 않는가
* `hidden_contract_ids` 필터가 적용되는가
* `active` 계약만 홈 합계와 최근 목록에 반영되는가
* 총액이 중복 증가하지 않는가
* 상환 완료 시 양쪽 총액과 계약 ID 목록이 함께 정리되는가
* `active` 계약이 일반 삭제되지 않는가
* 로그인 및 송금 완료 후 뒤로가기 흐름이 올바른가
* 로딩, 오류, 빈 상태가 처리되는가
* 화면 overflow가 없는가
* 비동기 작업 후 `mounted`를 확인했는가
* Firestore 숫자와 Timestamp 타입이 올바른가
* 새 패키지를 불필요하게 추가하지 않았는가

가능하면 다음 명령으로 확인한다.

```bash
flutter analyze
dart format .
```

---

# 17. 작업 결과 보고 규칙

작업 완료 후 다음 내용을 간단히 정리한다.

1. 수정한 파일
2. 새로 만든 파일
3. 주요 변경 내용
4. Firestore 구조 변경 여부
5. 실행 전에 필요한 명령어
6. 사용자가 직접 수정하기 쉬운 위치 및 크기 상수
7. 확인이 필요한 오류 또는 제한사항

실제로 실행하거나 검증하지 않은 코드를 정상 작동한다고 단정하지 않는다.
