# Data Model

## entries

| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| id | TEXT | UUID |
| mode | TEXT | test 또는 live |
| envelope_no | INTEGER | 봉투번호 |
| name | TEXT | 이름 |
| group_name | TEXT | 모임, 기본값 미분류 |
| relationship | TEXT | 관계 |
| amount | INTEGER | 축의금 |
| meal_ticket_count | INTEGER | 식권 수 |
| payment_method | TEXT | cash, transfer, other |
| memo | TEXT | 메모 |
| status | TEXT | active 또는 void |
| created_at | TEXT | 생성 시간 |
| updated_at | TEXT | 수정 시간 |

제약:

- `(mode, envelope_no)`는 중복될 수 없다.
- `amount`는 0보다 커야 한다.
- `meal_ticket_count`는 0 이상이어야 한다.
- 삭제하지 않고 `status=void`로 취소 처리한다.

## audit_logs

수정, 취소, 복구 이력을 저장한다.

| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| id | TEXT | UUID |
| entry_id | TEXT | 대상 기록 |
| action | TEXT | create, update, void, restore |
| before_json | TEXT | 변경 전 값 |
| after_json | TEXT | 변경 후 값 |
| reason | TEXT | 사유 |
| created_at | TEXT | 이력 생성 시간 |

## settings

앱 설정, PIN 해시, 복구키 해시, 현재 모드를 저장한다.
