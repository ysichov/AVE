# zcl_ave_popup_diff - Diff Engine

## Business Description

**Серце** порівняння версій — обчислює розходження між двома текстами:
- Line-level diff (які рядки додані/видалені/змінені)
- Character-level diff (які символи змінилися у рядку)
- Blame mapping (хто написав кожен рядок)

Алгоритм використовує **LCS (Longest Common Subsequence)** з оптимізацією для великих файлів.

## Technical Description

### Класифікація
- **Type**: Algorithm Engine
- **Scope**: Computational (no SAP GUI dependency)
- **Dependencies**: None (pure ABAP logic)

### Основні публічні методи

| Метод | Вхід | Вихід | Опис |
|-------|------|--------|------|
| `compute_diff` | old_lines, new_lines | ty_t_diff | LCS diff (line level) |
| `char_diff_html` | old_line, new_line | HTML string | Inline character diff |
| `build_blame_map` | versions, diffs | ty_blame_map | Author attribution |

### compute_diff() — Line-Level Diff

**Алгоритм**: LCS (Longest Common Subsequence) з look-ahead оптимізацією

**Приклад**:

```
Old (A):                 New (B):
1. DATA var1.            1. DATA var1.
2. var1 = 10.            2. var1 = 20.         ← REPLACE
3. WRITE var1.           3. WRITE: "V:".       ← REPLACE
4. WRITE var2.           4. WRITE var2.
5. (end)                 5. WRITE var1.        ← INSERT
                         6. WRITE var2.        ← INSERT

diff OUTPUT:
[
  { op: KEEP,    old_line: 1, new_line: 1 },
  { op: REPLACE, old_line: 2, new_line: 2 },
  { op: REPLACE, old_line: 3, new_line: 3 },
  { op: KEEP,    old_line: 4, new_line: 4 },
  { op: INSERT,  old_line: -, new_line: 5 },
  { op: INSERT,  old_line: -, new_line: 6 },
]
```

**Оптимізація для великих файлів**:
- Якщо файл > 50000 рядків → abort LCS, use fallback heuristic
- Look-ahead: Не заповнюй весь M×N matrix
- Streaming: Обробляй рядки у chunks

### char_diff_html() — Character-Level Diff

Для кожної REPLACE операції, обчисліть character-level diff:

```
Old: "DATA: var1 TYPE string."
New: "DATA: var2 TYPE string VALUE 'test'."

HTML output:
"DATA: var<span class='delete'>1</span><span class='insert'>2</span> 
TYPE string<span class='insert'> VALUE 'test'</span>."
```

**Логіка**:
1. Розбий обидва рядки на tokens (words)
2. Обчисли LCS tokens
3. Генеруй HTML span'и для різних операцій

### build_blame_map() — Author Attribution

**Завдання**: Для кожного рядка у найновішій версії, визначи його автора через весь ланцюг версій.

**Алгоритм** (recursive replay):

```
blame_map = {}

PROCEDURE replay_versions(versions: LIST, diffs: MAP):
  current_lines = versions[0].source_lines
  
  FOR each version i FROM 1 TO len(versions):
    COMPUTE diff_i = diffs[i]  " versions[i-1] vs versions[i]
    
    FOR each line L in versions[i].source:
      FIND L in diff_i:
        IF L is KEEP:
          ? blame_map[L] = blame_map[L from i-1]  (inherited)
        ELSE IF L is INSERT:
          ? blame_map[L] = versions[i].author
        ELSE IF L is REPLACE:
          ? blame_map[L] = versions[i].author
        ELSE IF L is DELETE:
          ? (removed, not in current lines)
      ENDFOR
  ENDFOR
```

**Приклад**:

```
Version 1 (USER1, 2026-05-01):
  [line1, line2, line3]

Version 2 (USER2, 2026-05-05):
  [line1, line2_modified, line3, line4_new]
  Diff: KEEP, REPLACE, KEEP, INSERT

Version 3 (USER3, 2026-05-10):
  [line1, line2_modified, line3, line4_modified]
  Diff: KEEP, KEEP, KEEP, REPLACE

Blame for Version 3:
  line1 ← USER1 (from v1)
  line2_modified ← USER2 (from v2)
  line3 ← USER1 (from v1)
  line4_modified ← USER3 (modified in v3, was inserted by USER2 in v2)
```

## Типи даних

```abap
TYPES BEGIN OF ty_diff_op.
  operation TYPE string.      " KEEP, INSERT, DELETE, REPLACE
  old_line_no TYPE int4.      " Line # in old version (0 if INSERT)
  new_line_no TYPE int4.      " Line # in new version (0 if DELETE)
  old_line TYPE string.       " Old line content
  new_line TYPE string.       " New line content
TYPES END OF ty_diff_op.

TYPES ty_t_diff TYPE TABLE OF ty_diff_op.

TYPES BEGIN OF ty_blame_entry.
  line_no TYPE int4.
  author TYPE string.
  version_number TYPE int4.
  operation TYPE string.      " INSERT, REPLACE, KEEP
TYPES END OF ty_blame_entry.

TYPES ty_blame_map TYPE TABLE OF ty_blame_entry.
```

## Performance Characteristics

| Сценарій | Складність | Час |
|----------|-----------|-----|
| Small files (< 1K lines) | O(M × N) | < 100ms |
| Medium files (1K-10K lines) | O(M × N) with look-ahead | < 1s |
| Large files (10K-50K lines) | Fallback heuristic | < 2s |
| Huge files (> 50K lines) | Abort, show warning | N/A |

## Synchronization with JavaScript

**ВАЖЛИВО**: Diff алгоритм портирований у JavaScript для HTML simulator!

- **File**: `html_simulator/diff.js`
- **Methods**: `compute_diff()`, `char_diff_html()` (1:1 mapping)
- **Sync Rule**: При зміні ABAP → ОБОВ'ЯЗКОВО оновлення JavaScript!

## Посилання

- [[architecture|Architecture]]
- [[layers/diff-render-layer|Diff/Render Layer]]
- [[zcl_ave_popup_html]]
- [[zcl_ave_popup_data]]
- [[zcl_ave_popup]]

---

**Last Updated**: 2026-05-17