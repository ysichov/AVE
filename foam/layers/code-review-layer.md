# Code Review Layer ✅

## Призначення

Система код-ревю — затвердження/відхилення zmін, збереження стану, статистика, звітування, і управління коментарями.

## Архітектура

```
TR Objects → Diff Pre-computation → Hunk Identification
       ↓
ACR State (zcl_ave_acr_state)
├─ Load saved review state
└─ Manage approve/decline actions per hunk
       ↓
ACR Renderer (zcl_ave_acr_renderer)
├─ Inject approve/decline buttons into HTML
├─ Render decline notes/threads
└─ Status indicators
       ↓
ACR Repository (zcl_ave_acr_repository)
├─ Save to ZAVE_REVIEW table
└─ Load persisted state
       ↓
ACR Report (zcl_ave_acr_report)
├─ Generate summary HTML
├─ Per-author stats
└─ Per-reviewer stats
```

## Компоненти

### 1. Review State [[zcl_ave_acr_state]]

**Завдання**: Керування динамічним станом ревю (які hunks затверджені/відхилені).

**Основні методи**:

| Метод | Опис |
|-------|------|
| `constructor` | Ініціалізація стану |
| `load_from_db` | Завантажи збережений стан із ZAVE_REVIEW |
| `set_hunk_action` | Затвердити або відхилити hunk |
| `get_hunk_action` | Отримай статус hunk'u |
| `clear_hunk_action` | Очисти статус (поверни в "unknown") |
| `add_decline_note` | Додай коментар до відхилення |

**Структури даних**:

```abap
TYPES BEGIN OF ty_hunk_key.
  part_name TYPE string.
  part_type TYPE string.
  hunk_id TYPE string.
TYPES END OF ty_hunk_key.

TYPES BEGIN OF ty_hunk_state.
  hunk_key TYPE ty_hunk_key.
  status TYPE string.    " APPROVED, DECLINED, UNKNOWN
  reviewer TYPE string.  " Who approved/declined
  timestamp TYPE timestamp.
  notes TYPE string.     " Decline notes/comments
TYPES END OF ty_hunk_state.
```

### 2. Review Renderer [[zcl_ave_acr_renderer]]

**Завдання**: Рендеринг інтерактивного HTML для ревю.

**Основні методи**:

| Метод | Опис |
|-------|------|
| `render_hunk_actions` | HTML для approve/decline buttons |
| `render_decline_thread` | Коментарі та thread of decline |
| `render_status_badge` | ✓ Approved / ✗ Declined badge |
| `render_comment_links` | Клікабельні посилання для дій |

**Приклад HTML**:

```html
<div class="hunk" id="hunk_ZREPORT_METHOD1_001">
  <div class="hunk-header">
    <span class="hunk-id">Hunk #1</span>
    <span class="author">USER1</span>
    <span class="stats">+5 insertions, -2 deletions</span>
  </div>
  
  <div class="hunk-content">
    <!-- diff lines -->
  </div>
  
  <div class="hunk-actions">
    <a href="sapevent:approve?hunk_id=...">✓ Approve</a>
    <a href="sapevent:decline?hunk_id=...">✗ Decline</a>
    <a href="sapevent:add_note?hunk_id=...">💬 Add Note</a>
  </div>
  
  <div class="hunk-status APPROVED">
    <span>✓ Approved by REVIEWER1 on 2026-05-17 10:30</span>
  </div>
  
  <!-- Decline thread (if declined) -->
  <div class="decline-thread">
    <div class="note">
      <strong>USER2 (Reviewer)</strong>: "Need to add error handling"
      <time>2026-05-17 10:25</time>
    </div>
    <div class="note">
      <strong>USER1 (Author)</strong>: "Fixed in version 2"
      <time>2026-05-17 10:40</time>
    </div>
  </div>
</div>
```

### 3. Review Stats [[zcl_ave_acr_stats]]

**Завдання**: Обчислення статистики змін (insertions, deletions, hunk counts).

**Основні методи**:

| Метод | Опис |
|-------|------|
| `from_diff` | Обчисли stats з diff операцій |
| `is_blank_hunk` | Чи hunk містить тільки whitespace |
| `count_*` | Лічильники для різних операцій |

**Структури даних**:

```abap
TYPES BEGIN OF ty_diff_stats.
  insertions TYPE int4.       " +N lines
  deletions TYPE int4.        " -N lines
  modifications TYPE int4.    " ~N lines changed
  hunk_count TYPE int4.       " Number of hunks
  blank_line_changes TYPE int4. " Whitespace only
  by_author TYPE TABLE OF ty_author_stats.
TYPES END OF ty_diff_stats.

TYPES BEGIN OF ty_author_stats.
  author TYPE string.
  insertions TYPE int4.
  deletions TYPE int4.
  modifications TYPE int4.
TYPES END OF ty_author_stats.
```

### 4. Review Repository [[zcl_ave_acr_repository]]

**Завдання**: Персистентність стану ревю у таблиці ZAVE_REVIEW.

**Таблиця структура** (ZAVE_REVIEW):

| Поле | Опис |
|------|------|
| `trkorr` | Transport request ID |
| `part_name` | Part name |
| `part_type` | Part type (REPS, METH, FUNC) |
| `hunk_id` | Unique hunk identifier |
| `status` | APPROVED, DECLINED, UNKNOWN |
| `reviewer` | User who acted |
| `timestamp` | Action timestamp |
| `notes` | Decline comments |
| `payload` | JSON payload з full review state |

**Методи**:

| Метод | Опис |
|-------|------|
| `load_review` | Завантажи стан з DB |
| `save_review` | Збережи стан у DB |
| `clear_review` | Видали стан ревю |

### 5. Review Report [[zcl_ave_acr_report]]

**Завдання**: Генерація сумарного HTML звіту ревю.

**Методи**:

| Метод | Опис |
|-------|------|
| `to_html` | Генеруй full report HTML |
| `build_summary` | Developer/reviewer totals |
| `build_object_groups` | Групування за об'єктами |

**Структура звіту**:

```html
<h1>Code Review Report</h1>
<h2>Summary</h2>
<table>
  <tr>
    <th>Author</th>
    <th>+Lines</th>
    <th>-Lines</th>
    <th>Hunks</th>
    <th>Status</th>
  </tr>
  <tr>
    <td>USER1</td>
    <td>+125</td>
    <td>-43</td>
    <td>8 hunks (5 approved, 3 declined)</td>
    <td>⚠️ Partial</td>
  </tr>
</table>

<h2>Reviewer Summary</h2>
<table>
  <tr>
    <th>Reviewer</th>
    <th>Approved</th>
    <th>Declined</th>
  </tr>
  <tr>
    <td>REVIEWER1</td>
    <td>12</td>
    <td>3</td>
  </tr>
</table>

<h2>Objects</h2>
<div class="object-group">
  <h3>ZREPORT</h3>
  <p>5 hunks, 2 approved, 2 declined, 1 unknown</p>
  <a href="#object_ZREPORT">View details</a>
</div>
```

### 6. Review Note Dialog [[zcl_ave_acr_note_dlg]]

**Завдання**: SAP GUI non-blocking діалог для редагування notes.

**Функціональність**:
- Text editor для коментарів
- Pre-fill існуючого note
- Focus при відкритті
- Raises events: `saved` або `cancelled`

## Hunks and Blame

### Що таке Hunk?

**Hunk** — це група послідовних diff операцій (INSERT, DELETE, REPLACE).

**Приклад**:

```
Version A:        Version B:           Hunks:
1. DATA var1.     1. DATA var1.
2. var1 = 10.     2. var1 = 20.        ← Hunk #1
3. WRITE var1.    3. WRITE: "Val:".    ← (continuous changes)
4. WRITE var2.    4. WRITE var2.
5. (empty)        5. WRITE var1.       ← Hunk #2
6. (empty)        6. WRITE var2.       ← (new section)
```

### Hunk Identification

```abap
PROCEDURE extract_hunks(diff_ops: TABLE OF ty_diff_op)
  DECLARE hunk_list TYPE TABLE OF ty_hunk.
  
  LOOP AT diff_ops INTO current_op.
    IF current_op IS CHANGED (INSERT/DELETE/REPLACE).
      Add to current hunk.
    ELSE IF current_op IS KEEP.
      IF current hunk has changes:
        Save hunk to hunk_list.
        Start new (empty) hunk.
      ENDIF.
    ENDIF.
  ENDLOOP.
  
  RETURN hunk_list.
```

## Код-ревю Workflow

### Крок 1: Підготовка

```
1. User вибирає TR
2. popup->prepare_code_review()
   ├─ Load last version per part
   ├─ Compute diff (old vs new)
   ├─ Extract hunks
   ├─ Calculate stats
   └─ Store in ACR State
```

### Крок 2: Перегляд

```
3. User бачить HTML звіт з hunks
4. User проглядає кожен hunk
5. User затверджує або відхиляє hunk
   └─ set_hunk_action()
```

### Крок 3: Коментарі

```
6. User нажимає "Decline" на hunk
7. Note dialog відкривається
8. User вводить причину відхилення
9. Note зберігається → save_to_db()
```

### Крок 4: Звіт

```
10. User повертається до звіту
11. ACR Report генерує summary
    ├─ Developer totals
    ├─ Reviewer totals
    ├─ Object breakdown
    └─ Overall status (Fully/Partially Approved/Declined)
```

## Особливості

- **Per-author attribution**: Blame map показує хто написав кожен рядок
- **Non-blocking dialogs**: Notes dialog не блокує UI
- **Persistence**: Стан ревю зберігається у DB
- **Partial approval**: Можна затвердити деякі hunks, відхилити інші
- **Decline threads**: Множені коментарі між автором та reviewer
- **Status tracking**: Затвердженість на рівні hunk, не на рівні версії

## Посилання

- [[architecture|Main Architecture]]
- [[zcl_ave_acr_state]]
- [[zcl_ave_acr_renderer]]
- [[zcl_ave_acr_stats]]
- [[zcl_ave_acr_repository]]
- [[zcl_ave_acr_report]]
- [[zcl_ave_acr_note_dlg]]
- [[layers/popup-ui-layer|Popup/UI Layer]]

---

**Last Updated**: 2026-05-17