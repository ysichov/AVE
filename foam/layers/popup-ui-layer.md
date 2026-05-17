# Popup/UI Layer 🖥️

## Призначення

Керування **SAP GUI інтерфейсом** — побудова layout, ALV грид, HTML viewer, обробка користувальницьких команд та взаємодія з層 дифу.

## Архітектура

```
┌─────────────────────────────────────────────┐
│          Main Dialog (Container)            │
├─────────────────────────────────────────────┤
│ Toolbar (commands)                          │
├─────────────┬───────────────────────────────┤
│ Parts ALV   │  Splitter                     │
│             ├─────────────────────────────  │
│             │ Versions ALV / Source / Diff │
│             │ (HTML Viewer)                │
└─────────────┴───────────────────────────────┘
```

## Основна класс [[zcl_ave_popup]]

**Це велика класс** (~2000 строк), що мішає:
- Layout/контейнери
- ALV грид обробку
- HTML viewer керування
- Version завантаження
- Diff обчислення
- Код-ревю інтеграцію
- Усе разом 😅

### Основні методи

#### Побудова UI

| Метод | Опис |
|-------|------|
| `build_layout` | Створи main dialog, splitters, containers |
| `build_parts_list` | Завантажи parts і збагати data (line counts) |
| `create_parts_alv` | ALV grid для parts |
| `create_versions_alv` | ALV grid для versions |
| `create_html_viewer` | HTML viewer container |
| `switch_pane_layout` | Toggle split ↔ focused режими |

#### Версія обробка

| Метод | Опис |
|-------|------|
| `load_versions` | Завантажи versions для обраної part (з VRSD) |
| `show_source` | Рендерини одну version як plain код |
| `show_code_source` | Великі файли → переключи в ABAP editor |
| `show_versions_diff` | Дві версії → обчисли diff → рендеринг |

#### ALV Event Handlers

| Метод | Обробляє |
|-------|----------|
| `handle_parts_command` | Команди в parts грід (open, drill-in) |
| `handle_parts_dblclick` | Double-click на part |
| `handle_vers_command` | Команди в versions грід |
| `handle_vers_dblclick` | Double-click на version |
| `on_toolbar_click` | Global toolbar кнопки |

## Data Flow: User Interactions

### Сценарій 1: Відкриття програми

```
1. User запускає Z_AVE (selection screen)
2. Введе Object Type (PROG) + Name (ZREPORT)
3. Create zcl_ave_popup instance
4. popup->show()
   ├─ build_layout() → UI containers
   ├─ build_parts_list() → завантажи parts
   │  └─ zcl_ave_object_factory=>get_instance()
   │     └─ handler->get_parts()
   ├─ create_parts_alv()
   ├─ create_versions_alv()
   ├─ create_html_viewer()
   └─ User бачить Parts grid (ліва сторона)
```

### Сценарій 2: Вибір версій

```
1. User вибирає част 1 у Parts ALV
2. on_parts_selected() → load_versions()
3. load_versions() →
   ├─ zcl_ave_vrsd (для цієї part)
   └─ Versions ALV grid наповнюється
4. User вибирає version A і B
5. Нажимає "Diff" або двічі клікає версію
   ├─ show_versions_diff()
   ├─ load source для A
   ├─ load source для B
   ├─ compute_diff() (Diff Engine)
   ├─ diff_to_html() (HTML Renderer)
   └─ set_html() → HTML Viewer
6. User бачить інтерактивний diff
```

### Сценарій 3: Код-ревю

```
1. User вибирає TR в selection screen
2. Popup відкривається для TR
3. User нажимає "Prepare Code Review"
   ├─ acr_state->load()
   ├─ prepare_code_review()
   │  └─ For each part:
   │     ├─ load 2 versions
   │     ├─ compute_diff()
   │     ├─ build_blame_map()
   │     └─ extract hunks (continuous changes)
   ├─ acr_stats->from_diff() (count insertions/deletions)
   ├─ acr_renderer->to_html() (inject approve buttons)
   └─ HTML viewer shows interactive review
4. User затверджує/відхиляє hunks
   ├─ set_hunk_action() → update state
   └─ acr_repository->save_to_db()
5. HTML Viewer перезавантажується з оновленим станом
```

## ALV Grid Integration

### Parts ALV Grid

**Функціональність**:
- Список усіх versionable parts для об'єкта
- Колонки: Type, Name, Object, Line Count, Status
- Commands: Open, View Source, Drill-in (для class)
- Double-click: відкриває part

**Data**:
```abap
TYPES ty_part_row.
" Comes from zcl_ave_object*->get_parts()
```

### Versions ALV Grid

**Функціональність**:
- Список версій для обраної part
- Колонки: Version#, Date, Author, TR, Status, Line Count
- Commands: Diff, Source, Review
- Sorting: By date (newest first)
- Color: Selected rows are highlighted

**Data**:
```abap
TYPES ty_version_row.
" Comes from zcl_ave_vrsd->get_versions()
```

## HTML Viewer Integration

### Зберігання HTML Content

```abap
PRIVATE DATA mv_html_content TYPE string.

METHODS set_html
  IMPORTING html_content TYPE string.
  
METHODS show_diff_html.
METHODS show_source_html.
METHODS show_review_html.
```

### SAP Event Handling

HTML у SAP GUI HTML viewer може генерувати `sapevent:` URLs:

```html
<a href="sapevent:approve_hunk?hunk_id=123&action=APPROVE">
  ✓ Approve
</a>
```

Обробляється в `on_sapevent()`:
```abap
METHODS on_sapevent
  IMPORTING event_name TYPE string
            parameters TYPE string.
```

## Layout Modes

### Mode 1: Split View (Default)

```
┌──────────┬──────────┐
│ Parts    │ Versions │
│   ALV    ├──────────┤
│          │ HTML V.  │
│          │ (diff)   │
└──────────┴──────────┘
```

### Mode 2: Focused HTML

```
┌──────────────────────┐
│ HTML Viewer          │
│ (full screen diff)   │
│ [← Back button]      │
└──────────────────────┘
```

Переключення: `switch_pane_layout()` (via toolbar)

## Key Challenges

### Масивні файли
- LCS diff може бути повільним
- Рішення: Look-ahead в `zcl_ave_popup_diff`, abort if > 50K lines

### Комплексність коду
- 2000+ рядків у одному класі
- Рефакторинг кандидати:
  - Layout controller (окремий клас)
  - ALV event handler (делегат клас)
  - HTML content orchestrator

### SAP GUI обмеження
- HTML viewer не має на 100% контролю версіями CSS
- Деякі JavaScript обмежені
- Тестування вимагає SAP подій

## Посилання

- [[architecture|Main Architecture]]
- [[zcl_ave_popup]]
- [[zcl_ave_popup_diff]]
- [[zcl_ave_popup_html]]
- [[layers/diff-render-layer|Diff/Render Layer]]
- [[layers/code-review-layer|Code Review Layer]]

---

**Last Updated**: 2026-05-17