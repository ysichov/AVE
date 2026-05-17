# zcl_ave_acr_state - Code Review State Manager

## Business Description

Управління **станом код-ревю**:
- Якої hunks затверджені (Approved)
- Які відхилені (Declined)
- Коментарі до відхилень
- Reviewer інформація

По суті, це **динамічний реєстр** всіх дій ревю.

## Technical Description

### Класифікація
- **Type**: State Container / Manager
- **Scope**: Per-Transport (TR-specific)
- **Dependencies**: [[zcl_ave_acr_repository]] (persistence)

### Основні публічні методи

| Метод | Опис |
|-------|------|
| `constructor` | Initialize with TR |
| `load_from_db` | Load persisted state |
| `set_hunk_action` | Approve/decline hunk |
| `get_hunk_action` | Get hunk status |
| `clear_hunk_action` | Reset hunk status |
| `add_decline_note` | Add reviewer comment |
| `get_all_hunks` | Get all hunk statuses |
| `get_approved_hunks` | Get approved list |
| `get_declined_hunks` | Get declined list |

### State Data Structure

```abap
TYPES BEGIN OF ty_hunk_key.
  part_name TYPE string.    " Object/part name
  part_type TYPE string.    " REPS, METH, FUNC
  hunk_id TYPE string.      " Unique hunk ID (e.g., "001", "002")
TYPES END OF ty_hunk_key.

TYPES BEGIN OF ty_hunk_state.
  hunk_key TYPE ty_hunk_key.
  status TYPE string.       " APPROVED, DECLINED, UNKNOWN
  reviewer TYPE string.     " User who approved/declined
  timestamp TYPE timestamp.
  notes TYPE string.        " Decline reason/comments
TYPES END OF ty_hunk_state.

PRIVATE DATA mt_hunk_states TYPE TABLE OF ty_hunk_state.
```

### constructor() — Initialization

```abap
DATA(acr_state) = NEW zcl_ave_acr_state( trkorr = 'NPLK900123' ).

" Опціонально:
TRY.
  acr_state->load_from_db().  " Load persisted state
CATCH zcx_ave.
  " New review, start fresh
ENDTRY.
```

### set_hunk_action() — Approve/Decline

```abap
METHODS set_hunk_action
  IMPORTING
    hunk_key TYPE ty_hunk_key
    action TYPE string        " 'APPROVE' or 'DECLINE'
    iv_notes TYPE string OPTIONAL.
```

**Приклад**:

```abap
acr_state->set_hunk_action(
  hunk_key = VALUE #(
    part_name = 'ZREPORT'
    part_type = 'REPS'
    hunk_id = '001'
  )
  action = 'APPROVE'
).

acr_state->set_hunk_action(
  hunk_key = VALUE #(
    part_name = 'ZCL_MANAGER'
    part_type = 'METH'
    hunk_id = '002'
  )
  action = 'DECLINE'
  iv_notes = 'Missing error handling'
).
```

**Процес**:
1. Знайди hunk у mt_hunk_states
2. Update status
3. Set reviewer = sy-uname
4. Set timestamp = current time
5. Store notes if provided

### get_hunk_action() — Query Status

```abap
METHODS get_hunk_action
  IMPORTING hunk_key TYPE ty_hunk_key
  RETURNING VALUE(action) TYPE ty_hunk_state.
```

**Приклад**:

```abap
DATA(hunk_state) = acr_state->get_hunk_action(
  hunk_key = VALUE #(
    part_name = 'ZREPORT'
    part_type = 'REPS'
    hunk_id = '001'
  )
).

IF hunk_state-status = 'APPROVED'.
  WRITE: / 'Approved by', hunk_state-reviewer.
ENDIF.
```

### clear_hunk_action() — Reset Status

```abap
acr_state->clear_hunk_action( hunk_key ).
" Reset to UNKNOWN, remove reviewer/notes
```

### add_decline_note() — Comments

```abap
METHODS add_decline_note
  IMPORTING
    hunk_key TYPE ty_hunk_key
    note TYPE string
    reviewer TYPE string OPTIONAL.
```

**Логіка**:
- Append note до hunk's notes field
- Include reviewer + timestamp
- Support thread of comments

## Integration with zcl_ave_popup

```
User нажимає "Approve" на hunk
       ↓
on_sapevent() receives "approve_hunk?hunk_id=..."
       ↓
acr_state->set_hunk_action(APPROVED)
       ↓
acr_repository->save_to_db()
       ↓
rerender_cr_current() (refresh HTML display)
```

## Persistence

**NOT Persisted Directly**: zcl_ave_acr_state केवल in-memory.

**Persistence via**: [[zcl_ave_acr_repository]] (saves to ZAVE_REVIEW table).

```abap
acr_state->set_hunk_action(...).
acr_repository->save_review( acr_state ).  " Persist to DB
```

## Role in Code Review Workflow

```
1. User вибирає TR
   ↓
2. Prepare Code Review
   ├─ Compute diffs for all parts
   ├─ Extract hunks
   ├─ Create acr_state
   ├─ Load from DB (if exists)
   ↓
3. Render HTML with approve/decline buttons
   ├─ ACR Renderer uses acr_state for status
   ├─ Show "✓ Approved" badges
   ├─ Show "✗ Declined" badges
   ↓
4. User interacts
   ├─ Click Approve → set_hunk_action(APPROVE)
   ├─ Click Decline → set_hunk_action(DECLINE) + dialog for notes
   ↓
5. Save & Persist
   ├─ acr_state->get_all_hunks()
   └─ acr_repository->save_review()
   ↓
6. Generate Report
   ├─ acr_stats from acr_state
   ├─ acr_report renders summary
```

## Посилання

- [[architecture|Architecture]]
- [[layers/code-review-layer|Code Review Layer]]
- [[zcl_ave_acr_repository]]
- [[zcl_ave_acr_renderer]]
- [[zcl_ave_acr_stats]]
- [[zcl_ave_popup]]

---

**Last Updated**: 2026-05-17