# MVP Firebase 데이터 구조 및 개발 규칙

이 문서는 Flutter와 Firebase를 이용한 지인 간 금전 거래 서비스의 데이터 구조, 계약 상태, 사용자 총액, 계약 목록, 삭제 및 가리기 규칙을 정의한다.

개발자와 AI 코딩 에이전트는 필드명, 자료형, 상태값, 변경 흐름을 임의로 변경하지 않고 이 문서를 기준으로 구현한다.

---

# 1. Firestore 전체 구조

Firestore에는 다음 두 개의 최상위 컬렉션을 사용한다.

```text
users
contracts
```

전체 구조:

```text
users
└── {uid}
    ├── name
    ├── email
    ├── borrowed_total
    ├── lent_total
    ├── active_contract_ids
    └── hidden_contract_ids

contracts
└── {contract_id}
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

# 2. User 데이터 구조

## 저장 경로

```text
users/{uid}
```

`uid`는 Firebase Authentication에서 자동 생성된 사용자의 UID를 사용한다.

UID를 별도로 직접 생성하지 않는다.

## 필드 구조

| 필드명 | 타입 | 필수 여부 | 설명 |
| --- | --- | ---: | --- |
| `name` | String | 필수 | 회원가입 시 입력한 사용자 이름 |
| `email` | String | 필수 | 로그인에 사용하는 이메일 |
| `borrowed_total` | int | 필수 | 현재 active 계약에서 사용자가 갚아야 하는 총금액 |
| `lent_total` | int | 필수 | 현재 active 계약에서 사용자가 돌려받아야 하는 총금액 |
| `active_contract_ids` | List<String> | 필수 | 사용자가 연결된 계약 문서 ID 목록 |
| `hidden_contract_ids` | List<String> | 필수 | 현재 사용자 화면에서 숨긴 계약 ID 목록 |

## 사용자 생성 초기값

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

회원가입 성공 후 Firebase Authentication UID를 문서 ID로 사용하여 생성한다.

```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(userUid)
    .set({
  'name': userName,
  'email': email,
  'borrowed_total': 0,
  'lent_total': 0,
  'active_contract_ids': <String>[],
  'hidden_contract_ids': <String>[],
});
```

비밀번호는 Firestore에 저장하지 않는다.

---

# 3. User 필드 의미

## name

화면에 표시하는 사용자 이름이다.

사용자 구분과 권한 확인에는 이름이 아니라 UID를 사용한다.

## email

로그인에 사용하는 이메일이다.

화면에 반드시 표시해야 하는 값은 아니며, 비밀번호와 인증 토큰은 함께 저장하지 않는다.

## borrowed_total

현재 `active` 상태 계약을 기준으로 사용자가 갚아야 하는 전체 금액이다.

```text
borrowed_total += total_repayment_amount
```

계약이 처음 `active`가 될 때 증가하고, 상환 완료 시 감소한다.

`editing`, `waiting_agreement` 계약은 포함하지 않는다.

## lent_total

현재 `active` 상태 계약을 기준으로 사용자가 돌려받아야 하는 전체 금액이다.

```text
lent_total += total_repayment_amount
```

계약이 처음 `active`가 될 때 증가하고, 상환 완료 시 감소한다.

## active_contract_ids

사용자가 연결된 계약의 Firestore 문서 ID 목록이다.

다음 상태의 계약을 포함할 수 있다.

```text
editing
waiting_agreement
active
```

이 필드명은 `active_contract_ids`이지만 MVP에서는 사용자의 계약 목록을 조회하기 위한 연결 ID 목록으로 사용한다.

계약 전체 데이터는 사용자 문서에 복사하지 않는다.

```text
users/{uid}.active_contract_ids
→ 계약 ID 목록

contracts/{contract_id}
→ 실제 계약 데이터
```

같은 계약 ID를 중복 추가하지 않는다.

```dart
FieldValue.arrayUnion([contract_id])
```

삭제 시 다음을 사용한다.

```dart
FieldValue.arrayRemove([contract_id])
```

## hidden_contract_ids

현재 사용자에게만 숨길 계약 ID 목록이다.

`active` 계약을 가리더라도 계약 문서 자체는 삭제하지 않는다.

가리기 처리:

```dart
FieldValue.arrayUnion([contract_id])
```

상환 완료 또는 계약 삭제 시 양쪽 사용자의 `hidden_contract_ids`에서도 계약 ID를 제거한다.

---

# 4. Contract 데이터 구조

## 저장 경로

```text
contracts/{contract_id}
```

`contract_id`는 Firestore 자동 문서 ID를 사용한다.

계약 문서 내부에 `contract_id`를 중복 저장하지 않는다.

## 필드 구조

| 필드명 | 타입 | 필수 여부 | 설명 |
| --- | --- | ---: | --- |
| `lender_uid` | String 또는 null | 필수 | 돈을 빌려주는 사용자의 UID |
| `lender_name` | String | 필수 | 돈을 빌려주는 사용자의 화면 표시 이름 |
| `borrower_uid` | String 또는 null | 필수 | 돈을 빌리는 사용자의 UID |
| `borrower_name` | String | 필수 | 돈을 빌리는 사용자의 화면 표시 이름 |
| `creator_uid` | String | 필수 | 계약서를 처음 작성한 사용자의 UID |
| `principal_amount` | int | 필수 | 빌린 원금 |
| `interest_rate` | double | 필수 | 퍼센트 단위 이자율 |
| `interest_amount` | int | 필수 | 계산된 이자 금액 |
| `total_repayment_amount` | int | 필수 | 원금과 이자를 합한 최종 상환 금액 |
| `due_date` | Timestamp | 필수 | 상환하기로 한 날짜 |
| `lender_agreed` | bool | 필수 | lender의 동의 여부 |
| `borrower_agreed` | bool | 필수 | borrower의 동의 여부 |
| `status` | String | 필수 | 계약 상태 |
| `memo` | String | 선택 | 추가 계약 내용, 없으면 빈 문자열 |

---

# 5. 계약 당사자와 역할

## lender

돈을 빌려주는 사람이다.

```text
lender_uid
lender_name
```

`waiting_agreement` 상태에서 현재 사용자가 lender인 경우 빌려주기 버튼을 사용할 수 있다.

계약이 활성화되면 lender의 `lent_total`에 최종 상환 금액을 반영한다.

## borrower

돈을 빌리는 사람이다.

```text
borrower_uid
borrower_name
```

`active` 상태에서 현재 사용자가 borrower인 경우 갚기 버튼을 사용할 수 있다.

계약이 활성화되면 borrower의 `borrowed_total`에 최종 상환 금액을 반영한다.

## creator

`creator_uid`는 계약서를 처음 작성한 사용자의 UID다.

작성자는 borrower일 수도 있고 lender일 수도 있다.

```text
creator_uid = 현재 로그인한 사용자의 UID
```

`editing`, `waiting_agreement` 계약의 삭제 권한은 작성자에게 있다.

---

# 6. 상대방 UID 연결 규칙

계약 작성 시 상대방이 아직 앱에 접속하지 않았다면 상대방 UID에 `null`을 저장할 수 있다.

예시: borrower가 계약을 작성한 경우

```json
{
  "borrower_uid": "현재 사용자 UID",
  "borrower_name": "권태준",
  "lender_uid": null,
  "lender_name": "김지수"
}
```

상대방이 공유 링크를 열면 다음 순서로 처리한다.

```text
현재 로그인 UID 확인
→ 계약 문서 조회
→ 비어 있는 상대방 UID 역할 확인
→ 현재 UID와 이름 등록
→ 현재 사용자의 active_contract_ids에 계약 ID 추가
→ 계약 상세 표시
```

이미 등록된 UID는 다른 사용자 UID로 변경하지 않는다.

현재 사용자가 이미 lender 또는 borrower로 등록되어 있지 않고, 비어 있는 역할에도 해당하지 않으면 계약 참여를 막는다.

---

# 7. 금액 및 이자 규칙

모든 금액은 대한민국 원 단위 정수 `int`로 저장한다.

```text
저장값: 1000000
화면 표시: 1,000,000원
```

## principal_amount

실제로 빌린 원금이다.

```text
principal_amount > 0
```

## interest_rate

이자율은 퍼센트 단위 `double`로 저장한다.

```text
5% → 5.0
```

이자 스위치가 꺼져 있으면 0을 저장한다.

## interest_amount

실제 이자 금액을 원 단위 정수로 저장한다.

```text
interest_amount >= 0
```

## total_repayment_amount

원금과 이자를 합한 최종 상환 금액이다.

```text
total_repayment_amount
= principal_amount + interest_amount
```

예시:

```json
{
  "principal_amount": 100000,
  "interest_rate": 5.0,
  "interest_amount": 5000,
  "total_repayment_amount": 105000
}
```

이자 off 예시:

```json
{
  "principal_amount": 100000,
  "interest_rate": 0,
  "interest_amount": 0,
  "total_repayment_amount": 100000
}
```

홈 합계와 송금 화면의 고정 금액에는 `total_repayment_amount`를 사용한다.

---

# 8. 계약 상태값

`status`는 다음 세 값만 사용한다.

```text
editing
waiting_agreement
active
```

`completed`, `waiting`, `achive`, `w_a` 등 다른 값은 사용하지 않는다.

## editing

계약을 작성하거나 임시 저장한 상태다.

```text
status = editing
```

규칙:

* 계약 작성 화면으로 이동
* 기존 내용 수정 가능
* 작성자만 삭제 가능
* 홈 합계와 최근 계약 목록에서 제외

## waiting_agreement

계약 작성이 끝나고 상대방의 동의 또는 송금 확인을 기다리는 상태다.

```text
status = waiting_agreement
```

규칙:

* 계약 상세보기 화면으로 이동
* 홈 합계와 최근 계약 목록에서 제외
* 현재 사용자가 lender인 경우에만 빌려주기 버튼 표시
* 계약 작성자만 삭제 가능

## active

양쪽 동의가 완료되어 돈을 빌리고 갚는 과정이 진행 중인 상태다.

```text
status = active
```

규칙:

* 홈 합계에 포함
* 홈 최근 계약 목록에 포함
* borrower에게만 갚기 버튼 표시
* 일반 삭제 불가
* 사용자별 가리기만 가능

상환 완료 상태는 별도로 저장하지 않는다.

상환 완료 시 사용자 합계와 계약 ID 목록을 정리한 뒤 계약 문서를 삭제한다.

---

# 9. 계약 작성 및 전송 흐름

## 새 계약 작성 시작

현재 사용자는 자신의 역할을 선택한다.

```text
나는 돈을 빌려요
→ 현재 사용자 = borrower

나는 돈을 빌려줘요
→ 현재 사용자 = lender
```

계약을 작성 중일 때:

```text
status = editing
```

계약 생성 시 작성자의 `active_contract_ids`에 계약 ID를 추가한다.

```text
contracts 문서 생성
+ creator 사용자의 active_contract_ids에 계약 ID 추가
```

가능하면 batch write를 사용한다.

## 계약 보내기

처리 순서:

```text
입력값 검증
→ 계약 데이터 저장 또는 수정
→ status = waiting_agreement
→ 공유 링크 생성
→ 시스템 공유창 실행
```

계약 보내기 단계에서 계약 총액을 사용자 합계에 반영하지 않는다.

사용자 합계는 계약이 처음 `active`가 될 때만 반영한다.

---

# 10. 계약 동의 규칙

동의 여부는 다음 두 boolean 필드로 관리한다.

```text
lender_agreed
borrower_agreed
```

```text
false = 아직 동의하지 않음
true = 동의 완료
```

계약 생성 초기값:

```json
{
  "lender_agreed": false,
  "borrower_agreed": false,
  "status": "editing"
}
```

각 사용자는 자신의 동의 값만 변경할 수 있다.

```text
lender_uid 사용자
→ lender_agreed 변경 가능

borrower_uid 사용자
→ borrower_agreed 변경 가능
```

한 사용자가 상대방 동의 값을 직접 변경하지 않는다.

양쪽 동의 값이 모두 true가 되면 상태를 `active`로 변경한다.

```dart
String calculateContractStatus({
  required bool lenderAgreed,
  required bool borrowerAgreed,
}) {
  if (lenderAgreed && borrowerAgreed) {
    return 'active';
  }

  return 'waiting_agreement';
}
```

`editing`은 작성 중 상태이므로 계약 보내기 전 별도로 관리한다.

---

# 11. 빌려주기 확인 처리

`detail_contract_screen.dart`에서 다음 조건일 때 빌려주기 버튼을 표시한다.

```text
status == waiting_agreement
현재 사용자 UID == lender_uid
```

버튼을 누르면 `mock_transfer_screen.dart`로 이동한다.

상세 화면에서는 상태나 총액을 직접 변경하지 않는다.

송금 화면에서 빌려주기 확인 버튼을 누르면 다음을 처리한다.

```text
1. lender_agreed = true
2. borrower_agreed 값 확인
3. 양쪽 agreed가 true이면 status = active
4. 양쪽 사용자의 active_contract_ids에 계약 ID 저장
5. borrower.borrowed_total 증가
6. lender.lent_total 증가
7. main_screen의 홈 탭으로 이동
```

총액 증가값:

```text
borrower.borrowed_total += total_repayment_amount
lender.lent_total += total_repayment_amount
```

총액은 계약이 처음 `active`가 되는 순간에만 한 번 증가한다.

이미 `active`였던 계약에 다시 증가시키면 안 된다.

계약 상태 변경과 두 사용자 총액 변경은 Firestore transaction으로 처리한다.

---

# 12. 홈 화면 조회 규칙

홈 화면에는 `active` 상태 계약만 표시한다.

다음 상태는 홈 합계와 최근 계약에서 제외한다.

```text
editing
waiting_agreement
```

합계 표시:

```text
빌린 돈 합계 → users/{uid}.borrowed_total
빌려준 돈 합계 → users/{uid}.lent_total
```

최근 계약 목록:

* `active` 상태만 표시
* 처음 3건 표시
* 더보기 시 전체 표시
* 더보기 버튼에 남은 건수 표시
* 접기 시 3건으로 복귀

계약 카드 표시 정보:

```text
상대방 이름
빌림 또는 빌려줌
계약 금액
갚을 날짜
```

현재 계약 ID가 `hidden_contract_ids`에 포함되어 있다면 홈과 계약 탭 모두에서 숨긴다.

---

# 13. 계약 목록 조회 규칙

조회 순서:

```text
1. users/{uid} 문서 조회
2. active_contract_ids 목록 확인
3. 각 ID에 해당하는 contracts 문서 조회
4. hidden_contract_ids에 포함된 계약 제외
5. editing, waiting_agreement, active 상태 표시
6. 존재하지 않는 계약 ID 정리
```

사용자 문서에는 계약 전체 내용을 중복 저장하지 않는다.

계약 카드에는 다음 정보를 표시한다.

* 상대방 이름
* 현재 사용자의 역할
* `total_repayment_amount`
* `due_date`
* 상태 표시 문구

상태 표시 문구:

```text
editing → 편집중
waiting_agreement → 동의 대기중
active → 진행중
```

---

# 14. 계약 수정 규칙

## editing

기존 계약 내용을 불러와 수정할 수 있다.

새 계약 문서를 생성하지 않고 기존 `contract_id` 문서를 갱신한다.

## waiting_agreement

MVP 화면 흐름에서는 상세보기 화면으로 이동하며 일반 수정 기능을 제공하지 않는다.

계약 내용을 다시 수정하는 기능을 추가하는 경우 기존 동의를 모두 무효화하고 상태를 `editing`으로 되돌려야 한다.

```json
{
  "lender_agreed": false,
  "borrower_agreed": false,
  "status": "editing"
}
```

## active

원금, 이자, 상환기한 등 핵심 계약 내용을 수정하지 않는다.

---

# 15. 계약 삭제 규칙

## editing 삭제

조건:

```text
현재 UID == creator_uid
```

처리:

```text
연결된 사용자 active_contract_ids에서 contract_id 제거
연결된 사용자 hidden_contract_ids에서 contract_id 제거
contracts/{contract_id} 삭제
```

## waiting_agreement 삭제

계약 작성자만 삭제할 수 있다.

상대방이 이미 참여한 경우 양쪽 사용자 문서에서 계약 ID를 제거한다.

```text
borrower.active_contract_ids에서 제거
lender.active_contract_ids에서 제거
borrower.hidden_contract_ids에서 제거
lender.hidden_contract_ids에서 제거
contracts 문서 삭제
```

아직 연결되지 않은 상대방 UID가 `null`이면 연결된 사용자만 정리한다.

## active 삭제

일반 삭제를 허용하지 않는다.

상환 완료 처리를 통해서만 계약 문서를 삭제한다.

---

# 16. 계약 가리기 규칙

`active` 계약은 사용자가 자신의 목록에서만 가릴 수 있다.

```dart
await user_reference.update({
  'hidden_contract_ids': FieldValue.arrayUnion([contract_id]),
});
```

가리기는 다음 데이터를 변경하지 않는다.

* 계약 문서
* 상대방의 `active_contract_ids`
* 상대방의 `hidden_contract_ids`
* 사용자 총액
* 계약 상태

상대방 화면에는 계속 표시된다.

---

# 17. 갚기 및 상환 완료 처리

`detail_contract_screen.dart`에서 다음 조건일 때 갚기 버튼을 표시한다.

```text
status == active
현재 사용자 UID == borrower_uid
```

버튼을 누르면 `mock_transfer_screen.dart`로 이동한다.

갚기 확인 시 다음을 하나의 transaction으로 처리한다.

```text
1. borrower.borrowed_total 감소
2. lender.lent_total 감소
3. borrower.active_contract_ids에서 계약 ID 제거
4. lender.active_contract_ids에서 계약 ID 제거
5. borrower.hidden_contract_ids에서 계약 ID 제거
6. lender.hidden_contract_ids에서 계약 ID 제거
7. contracts/{contract_id} 삭제
```

감소값:

```text
borrower.borrowed_total -= total_repayment_amount
lender.lent_total -= total_repayment_amount
```

감소 결과는 0보다 작아지지 않도록 처리한다.

```text
max(0, 기존 총액 - total_repayment_amount)
```

완료 후 `main_screen.dart`의 홈 탭으로 이동하고, 뒤로가기로 송금 화면에 다시 돌아오지 않도록 한다.

---

# 18. 날짜 저장 규칙

상환기한은 다음 필드를 사용한다.

```text
due_date
```

문자열이 아니라 Firestore `Timestamp`로 저장한다.

```text
잘못된 값: "2026-08-10"
올바른 값: Firestore Timestamp
```

화면에서만 다음처럼 변환한다.

```text
2026년 8월 10일까지
```

MVP에서는 별도 요청 없이 다음 시간 필드를 추가하지 않는다.

```text
created_at
updated_at
completed_at
lender_agreed_at
borrower_agreed_at
```

---

# 19. null 및 기본값 규칙

필수 숫자 필드는 `null`로 저장하지 않는다.

```text
principal_amount = 0
interest_rate = 0
interest_amount = 0
total_repayment_amount = 0
```

필수 boolean 필드는 `null`로 저장하지 않는다.

```text
lender_agreed = false
borrower_agreed = false
```

메모가 없으면 빈 문자열을 저장한다.

```text
memo = ""
```

상대방이 아직 참여하지 않은 경우에만 상대방 UID에 `null`을 허용한다.

---

# 20. 데이터 검증 규칙

계약 저장 전에 다음을 검사한다.

```text
principal_amount > 0
interest_rate >= 0
interest_amount >= 0
total_repayment_amount >= principal_amount
due_date가 선택되어 있음
lender_name이 비어 있지 않음
borrower_name이 비어 있지 않음
```

양쪽 UID가 모두 존재하면 서로 달라야 한다.

```text
lender_uid != borrower_uid
```

한 사용자가 자기 자신과 계약하지 못하도록 막는다.

사용자 이름과 이메일은 앞뒤 공백을 제거한다.

---

# 21. Transaction 및 Batch 규칙

다음 작업은 여러 문서가 함께 변경되므로 transaction 또는 batch write를 사용한다.

## 계약 생성

```text
contracts 문서 생성
+ creator.active_contract_ids에 계약 ID 추가
```

## 상대방 참여

```text
계약 문서에 상대방 UID와 이름 등록
+ 상대방.active_contract_ids에 계약 ID 추가
```

## 계약 활성화

```text
agreed 값과 status 변경
+ borrower.borrowed_total 증가
+ lender.lent_total 증가
+ 양쪽 active_contract_ids 확인 및 추가
```

## editing 또는 waiting 계약 삭제

```text
연결된 사용자들의 계약 ID 제거
+ hidden_contract_ids 정리
+ 계약 문서 삭제
```

## 상환 완료

```text
양쪽 총액 감소
+ 양쪽 active_contract_ids 제거
+ 양쪽 hidden_contract_ids 제거
+ 계약 문서 삭제
```

중간 작업만 성공해 데이터가 어긋나는 상황을 방지한다.

---

# 22. 권한 규칙

## 사용자 문서

```text
users/{uid}
→ 현재 로그인 UID == 문서 UID일 때만 본인 데이터 수정 가능
```

단, 계약 transaction에서 상대방 총액을 직접 수정해야 하는 구조는 클라이언트 Security Rules와 충돌할 수 있다.

이 경우 Cloud Functions 또는 검증 가능한 별도 서버 처리 도입을 검토한다. MVP에서 클라이언트 transaction을 사용하는 경우에도 아무 사용자가 임의의 다른 사용자 총액을 변경하지 못하도록 계약 참여자와 변경값을 엄격히 검증해야 한다.

## 계약 문서

기본 조회 및 수정 권한은 계약 당사자로 제한한다.

```text
현재 UID == lender_uid
또는
현재 UID == borrower_uid
```

공유 링크로 처음 참여하는 사용자는 비어 있는 상대방 UID 자리에 자신의 UID를 등록하는 제한된 작업만 수행할 수 있어야 한다.

## 삭제 권한

```text
editing, waiting_agreement
→ creator_uid만 삭제 가능

active
→ 일반 삭제 불가
→ borrower의 상환 완료 흐름에서만 삭제
```

클라이언트에서 버튼을 숨기는 것만으로 권한 처리를 끝내지 않는다.

---

# 23. 계약 데이터 예시

```json
{
  "lender_uid": "lender_uid_001",
  "lender_name": "김지수",
  "borrower_uid": "borrower_uid_002",
  "borrower_name": "권태준",
  "creator_uid": "borrower_uid_002",
  "principal_amount": 1000000,
  "interest_rate": 0,
  "interest_amount": 0,
  "total_repayment_amount": 1000000,
  "due_date": "Firestore Timestamp",
  "lender_agreed": true,
  "borrower_agreed": true,
  "status": "active",
  "memo": ""
}
```

---

# 24. 전체 상태 및 데이터 흐름

```text
회원가입
↓
users/{uid} 생성
borrowed_total = 0
lent_total = 0
active_contract_ids = []
hidden_contract_ids = []

계약 작성
↓
status = editing
작성자 active_contract_ids에 계약 ID 추가

계약 보내기
↓
status = waiting_agreement
공유 링크 생성

상대방 참여
↓
비어 있는 상대방 UID 등록
상대방 active_contract_ids에 계약 ID 추가

빌려주기 확인
↓
lender_agreed = true
양쪽 agreed가 true이면 status = active
borrower.borrowed_total 증가
lender.lent_total 증가

진행 중
↓
active 계약만 홈 합계와 최근 계약에 표시
active 계약은 삭제 불가
사용자별 가리기 가능

갚기 확인
↓
양쪽 총액 감소
양쪽 active_contract_ids 제거
양쪽 hidden_contract_ids 제거
contracts 문서 삭제
홈 탭으로 이동
```

---

# 25. AI 코딩 에이전트 필수 준수사항

1. 이 문서에 없는 필드를 임의로 추가하지 않는다.
2. User 필드는 `borrowed_total`, `lent_total`, `active_contract_ids`, `hidden_contract_ids`를 사용한다.
3. 모든 금액은 원 단위 정수로 처리한다.
4. 사용자 구분과 권한 검사는 UID로 처리한다.
5. 화면에는 UID 대신 사용자 이름을 표시한다.
6. 홈 합계와 최근 계약에는 `active` 계약만 반영한다.
7. 계약 총액은 `total_repayment_amount`를 사용한다.
8. 계약 활성화 시 총액을 정확히 한 번만 증가시킨다.
9. 상환 완료 시 총액 감소, ID 제거, 계약 삭제를 함께 수행한다.
10. `active` 계약은 일반 삭제하지 않는다.
11. 가리기는 현재 사용자의 `hidden_contract_ids`만 변경한다.
12. 동일한 계약 ID를 배열에 중복 추가하지 않는다.
13. 계약 전체 데이터를 User 문서에 중복 저장하지 않는다.
14. 여러 문서 변경은 transaction 또는 batch write로 처리한다.
15. Firestore 필드명에는 문서에 정의된 `snake_case`를 사용하고, Dart 함수명·변수명·매개변수명에는 `lowerCamelCase`를 사용한다.
16. 날짜는 Firestore `Timestamp`로 저장한다.
17. UI 표시 문자열과 Firestore 저장값을 구분한다.
18. 새로운 데이터가 필요하면 영향도를 설명한 뒤 추가한다.
