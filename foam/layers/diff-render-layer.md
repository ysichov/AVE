# Diff/Render Layer 🎨

## Призначення

1. **Обчисліть розходження** між двома версіями (line-level і character-level)
2. **Рендеріть HTML** для інтерактивного перегляду
3. **Побудуйте карту blame** — атрибутуйте кожен рядок автору
4. **Підтримуйте різні режими** — один панель, два панелі, компактний режим

## Архітектура

```
Version A (old source)        Version B (new source)
       ↓                              ↓
       └──────────────┬───────────────┘
                      ↓
              Diff Engine (zcl_ave_popup_diff)
              ├─ compute_diff() → line-level diff
              ├─ char_diff_html() → character-level diff
              └─ build_blame_map() → author attribution
                      ↓
              List of Diff Operations:
              [
                { op: "KEEP",    old_line: 1,  new_line: 1 },
                { op: "DELETE",  old_line: 5,  new_line: - },
                { op: "INSERT",  old_line: -,  new_line: 5 },
                { op: "REPLACE", old_line: 10, new_line: 10 },
                ...
              ]
                      ↓
              HTML Renderer (zcl_ave_popup_html)
              ├─ diff_to_html() → diff view
              ├─ source_to_html() → plain source view
              └─ cds_source_to_html() → CDS syntax coloring
                      ↓
              HTML Output (rendered in SAP GUI viewer)
```

## Diff Engine [[zcl_ave_popup_diff]]

### Основні методи

| Метод | Опис | Особливості |
|-------|------|------------|
| `compute_diff` | Обчисліть line-level LCS diff | Low-memory look-ahead алгоритм |
| `char_diff_html` | Character-level diff для одної лінії | Inline HTML markup |
| `has_common_chars` | Рішення чи лінії достатньо подібні | Для розумного pairing |
| `build_blame_map` | Replay дифи, атрибутуйте авторам | Через версії V1→V2→V3... |

### LCS (Longest Common Subsequence) Алгоритм

**Проблема**: Знайти "найменші" розходження між двома текстами.

**Рішення**: LCS — найдовша послідовність ліній, що з'являються в обох файлах у тому ж порядку.

**Приклад**:
```
Version A:          Version B:
1. DATA var1.       1. DATA var1.
2. var1 = 10.       2. var1 = 20.         ← REPLACE
3. WRITE var1.      3. WRITE: 'Value:'.   ← REPLACE
4. WRITE var2.      4. WRITE var2.
5. (empty)          5. WRITE var1.        ← INSERT
                    6. WRITE var2.

Diff:
1. KEEP (both have "DATA var1.")
2. REPLACE
3. REPLACE
4. KEEP
5. INSERT
```

**Оптимізація**: Look-ahead для великих файлів:
- Не заповнюй весь matrix (M × N) у памяті
- Шукай LCS поступово, враховуючи наступний стан
- Прерви рано якщо файл > 50000 рядків

### Character-Level Diff

Після знаходження line-level diff, для REPLACE операцій обчисліть **character-level** розходження:

```
Old line:  "DATA: var1 TYPE string."
New line:  "DATA: var2 TYPE string VALUE 'test'."

Character diff:
"DATA: var[1|2] TYPE string[| VALUE 'test']."
         ^^                    ^^^^^^^^^^^^
      DELETE+INSERT        INSERT
```

### Blame Map

**Завдання**: Атрибутувати кожен рядок в Version Z його автору, навіть якщо він прошов кілька проміжних версій.

**Алгоритм**:
```
1. Почни з Version Z (newest)
2. Compute diff: Version Y vs Version Z
   ├─ DELETE рядки → видалені автором Z
   ├─ INSERT рядки → додані автором Z
   ├─ REPLACE рядки → змінені автором Z
   └─ KEEP рядки → перенесені із Y
3. For KEEP рядків: recursively процесуй Version Y
4. Результат: Кожен рядок → { author, version_number, operation }
```

**Приклад**:
```
Version 1 (USER1): [line1, line2, line3]
Version 2 (USER2): [line1, line2_modified, line3, line4_new]
Version 3 (USER3): [line1, line2_modified, line3, line4_modified]

Blame for Version 3:
├─ line1 ← USER1 (v1) - INSERT
├─ line2_modified ← USER2 (v2) - REPLACE
├─ line3 ← USER1 (v1) - INSERT
└─ line4_modified ← USER3 (v3) - REPLACE (was USER2 in v2)
```

## HTML Renderer [[zcl_ave_popup_html]]

### Основні методи

| Метод | Опис |
|-------|------|
| `diff_to_html` | Рендеринг повного diff представлення |
| `source_to_html` | Рендеринг простого код без дифу |
| `cds_source_to_html` | Синтаксис для CDS/DDLS |
| `debug_diff_html` | Діагностичний HTML для дифу |

### Режими рендеринга

#### Single Pane Mode (old vs new "вбік")
```html
<table>
  <tr>
    <td class="old">line1 (old)</td>
    <td class="new">line1 (new)</td>
  </tr>
  <tr class="delete">
    <td>line2_old</td>
    <td></td>
  </tr>
  <tr class="insert">
    <td></td>
    <td>line2_new</td>
  </tr>
</table>
```

#### Compact Mode (змін тільки)
```html
<table>
  <tr class="context">5 lines unchanged</tr>
  <tr class="delete">10 > line removed</tr>
  <tr class="insert">11 > line added</tr>
  <tr class="context">5 more lines unchanged</tr>
</table>
```

#### Inline Character Markup
```html
<td>
  DATA: var<span class="delete">1</span><span class="insert">2</span> TYPE string.
</td>
```

### Blame Visualization

Кожен рядок маркується автором:
```html
<tr class="blame-author-USER1">
  <td class="blame-left">... (original author)</td>
  <td class="line-content">...</td>
</tr>
```

## Helper Utilities [[zcl_ave_popup_data]]

Утиліти для версій, типів об'єктів, перевірки існування:

| Утиліта | Опис |
|---------|------|
| `get_user_name` | Резолвити display name користувача |
| `get_latest_author` | Автор найновішої версії |
| `check_part_exists` | Перевірити чи частина існує |
| `get_type_text` | Кешований текст типу об'єкта |
| `get_active_line_count` | Кількість ліній в активній версії |

## Performance Considerations

### Memory Optimization
- **Low-memory diff**: Look-ahead замість повного matrix
- **Streaming**: Не завантажуй весь файл одразу
- **Chunking**: Обробляй великі файли частинами

### Time Optimization
- **Character diff**: Тільки для REPLACE операцій (не для всіх рядків)
- **Caching**: Кешуй diff результати для одних пар версій
- **Abort early**: Прерви LCS якщо файл надто великий

### HTML Optimization
- **Компактний режим**: Не рендеріть 50000 KEEP рядків
- **Code folding**: Згорни незмінені блоки
- **Lazy loading**: Завантажуй додатковий код на запит

## Synchronization: ABAP ↔ JavaScript

[[html_simulator/diff.js]] містить **JavaScript port** diff алгоритму для:
- 🖥️ Швидкої розробки UI (без SAP)
- 🧪 Тестування алгоритму
- 🔄 Перевірки консистентності

**ОБОВ'ЯЗКОВО**: Синхронізуй ABAP та JavaScript версії при змінах!

## Посилання

- [[architecture|Main Architecture]]
- [[zcl_ave_popup_diff]]
- [[zcl_ave_popup_html]]
- [[zcl_ave_popup_data]]
- [[layers/version-layer|Version Layer]]
- [[layers/popup-ui-layer|Popup/UI Layer]]

---

**Last Updated**: 2026-05-17