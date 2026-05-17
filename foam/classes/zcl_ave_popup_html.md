# zcl_ave_popup_html - HTML Renderer

## Business Description

Трансформує raw **diff операції** у красивий HTML для SAP GUI viewer. Підтримує різні режими:
- Two-pane mode (old vs new)
- Single-pane mode
- Compact mode (зі свортанням незмінених блоків)
- Blame visualization (кольором позначає авторів)

Також рендеріт CDS/DDLS з синтаксис-хайлайтингом.

## Technical Description

### Класифікація
- **Type**: Renderer/Formatter
- **Scope**: Computational (generates HTML strings)
- **Dependencies**: [[zcl_ave_popup_diff]] (diff operations), [[zcl_ave_popup_data]] (utilities)

### Основні публічні методи

| Метод | Вхід | Вихід | Опис |
|-------|------|--------|------|
| `diff_to_html` | diff_ops, versions, mode | HTML string | Full diff page |
| `source_to_html` | source_lines | HTML string | Plain code view |
| `cds_source_to_html` | ddls_source_lines | HTML string | CDS with syntax color |

### diff_to_html() — Diff Page Generation

**Вхід**:
```abap
it_diff_ops: ty_t_diff_op    " Diff операції
io_old_version: ty_version   " Metadata про версію A
io_new_version: ty_version   " Metadata про версію B
iv_mode: string              " "TWO_PANE", "COMPACT", "SINGLE"
```

**Вихід**: HTML сторінка для SAP GUI viewer

**Приклад HTML** (Two-Pane Mode):

```html
<html>
<head>
  <style>
    .old-pane { background: #ffe6e6; }
    .new-pane { background: #e6ffe6; }
    .delete { background: #ffcccc; text-decoration: line-through; }
    .insert { background: #ccffcc; font-weight: bold; }
    .blame { border-left: 3px solid #ccc; padding-left: 5px; }
  </style>
</head>
<body>
  <h2>Version Comparison</h2>
  <div class="header">
    <span class="version-old">
      Version 5 (2026-05-10) by USER1
    </span>
    <span class="version-new">
      Version 6 (2026-05-15) by USER2
    </span>
  </div>
  
  <table class="diff-table">
    <tr class="keep">
      <td class="old-pane">1</td>
      <td>DATA: var1.</td>
      <td class="new-pane">1</td>
      <td>DATA: var1.</td>
    </tr>
    
    <tr class="replace">
      <td class="old-pane">2</td>
      <td class="delete">var1 = <span class="highlight">10</span>.</td>
      <td class="new-pane">2</td>
      <td class="insert">var1 = <span class="highlight">20</span>.</td>
    </tr>
    
    <tr class="keep">
      <td class="old-pane">3</td>
      <td>WRITE var1.</td>
      <td class="new-pane">3</td>
      <td>WRITE var1.</td>
    </tr>
    
    <tr class="insert">
      <td class="old-pane">-</td>
      <td></td>
      <td class="new-pane">4</td>
      <td class="insert">WRITE 'New line'.</td>
    </tr>
  </table>
  
  <div class="footer">
    Statistics: +2 lines, -1 line, 5 hunks
  </div>
</body>
</html>
```

### source_to_html() — Plain Code View

Рендеріт просто вихідний код з номерами рядків:

```html
<table class="source-table">
  <tr>
    <td class="line-no">1</td>
    <td>DATA: var1.</td>
  </tr>
  <tr>
    <td class="line-no">2</td>
    <td>var1 = 10.</td>
  </tr>
  ...
</table>
```

### cds_source_to_html() — CDS Syntax Highlighting

Легкий syntax coloring для CDS/DDLS:

```html
<span class="keyword">DEFINE</span> <span class="entity-name">ZC_ARTICLES</span> {
  <span class="field">key</span> id : UUID;
  <span class="field">name</span> : String;
  ...
}
```

**Підтримувані keywords**: `DEFINE`, `EXTEND`, `VIEW`, `PROJECTION`, `ASSOCIATION`, тощо.

## Режими рендеринга

### Two-Pane Mode (Side-by-Side)

```
OLD CODE (Version A)  |  NEW CODE (Version B)
───────────────────────────────────────────────
1. DATA var1.        |  1. DATA var1.
2. var1 = 10.        |  2. var1 = 20.    ← REPLACE
3. WRITE var1.       |  3. WRITE var1.
                     |  4. NEW LINE      ← INSERT
```

**Переваги**: Легко порівнювати side-by-side
**Недоліки**: Потребує більше місця на екрані

### Single-Pane Mode

```
1. DATA var1.                (KEEP)
2. var1 = 10. → var1 = 20.   (REPLACE)
3. WRITE var1.               (KEEP)
4. + NEW LINE                (INSERT)
```

**Переваги**: Компактно, мобільно-friendly
**Недоліки**: Складніше порівнювати

### Compact Mode

```
1-5. [5 lines unchanged]
6.  - OLD LINE
7.  + NEW LINE
8-10. [3 more unchanged]
```

**Переваги**: Дуже компактно для великих файлів
**Недоліки**: Потрібна більше уважності

## Blame Visualization

Якщо є blame_map:

```html
<tr class="blame-author-USER1">
  <td class="blame-indicator" style="border-left: 3px solid #ff9900;">
    USER1 (v5)
  </td>
  <td>1</td>
  <td>DATA var1.</td>
</tr>

<tr class="blame-author-USER2">
  <td class="blame-indicator" style="border-left: 3px solid #00cc00;">
    USER2 (v6)
  </td>
  <td>2</td>
  <td>var1 = 20.</td>
</tr>
```

**Легенда**: Різні кольори для різних авторів

## Утиліти

### Helper Methods (Private)

| Метод | Опис |
|-------|------|
| `escape_html` | Escape `<`, `>`, `&`, тощо |
| `get_color_for_author` | Стабільний колір для user |
| `get_operation_css_class` | CSS класс для операції (delete, insert, replace) |
| `format_timestamp` | Форматуй дату/час |
| `is_blank_line` | Перевір чи рядок порожній |

## Performance Considerations

### HTML Size Optimization
- **Large diffs**: Компактний режим для файлів > 10K lines
- **Inline character diff**: Тільки для REPLACE (не для всіх)
- **Code folding**: Згорни 100+ незмінених рядків

### Rendering Speed
- String concatenation (ABAP): Може бути повільним для величезних HTML
- Рішення: Use `APPEND` до рядка таблиці, потім `CONCATENATE`

## Посилання

- [[architecture|Architecture]]
- [[layers/diff-render-layer|Diff/Render Layer]]
- [[zcl_ave_popup_diff]]
- [[zcl_ave_popup_data]]
- [[zcl_ave_popup]]

---

**Last Updated**: 2026-05-17