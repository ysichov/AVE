# zcl_ave_popup - Main Popup Controller

## Business Description

Основний контролер AVE — **чорний ящик**, що оркеструє весь user experience:
- Побудова SAP GUI layout (сплітери, контейнери, ALV, HTML viewer)
- Завантаження та перемикання версій
- Обчислення дифів та рендеринг HTML
- Управління код-ревю workflow та його персистентністю
- Обробка користувальницьких команд

Ця класс є **найбільшим ризиком для рефакторингу** у AVE через змішування занадто багатьох обов'язків.

## Technical Description

### Класифікація
- **Type**: Controller/Orchestrator
- **Scope**: Global (main UI orchestration)
- **Dependencies**: 
  - [[zcl_ave_object_factory]] (object resolution)
  - [[zcl_ave_popup_diff]] (diff computation)
  - [[zcl_ave_popup_html]] (HTML rendering)
  - [[zcl_ave_popup_data]] (helper utilities)
  - [[zcl_ave_acr_*]] (all code review classes)

### Основні даті члени (Attributes)

```abap
PRIVATE SECTION.
  DATA mv_object_type TYPE string.        " PROG, CLAS, FUNC, etc.
  DATA mv_object_name TYPE string.        " Object name
  
  " UI Components
  DATA mo_main_dialog TYPE REF TO cl_gui_dialogbox_container.
  DATA mo_html_viewer TYPE REF TO cl_gui_html_viewer.
  DATA mo_parts_alv TYPE REF TO cl_gui_alv_grid.
  DATA mo_versions_alv TYPE REF TO cl_gui_alv_grid.
  
  " Current state
  DATA mv_selected_part TYPE zif_ave_popup_types=>ty_part_row.
  DATA mt_versions TYPE zif_ave_popup_types=>ty_t_version_row.
  DATA mv_selected_version_old TYPE zif_ave_popup_types=>ty_version_row.
  DATA mv_selected_version_new TYPE zif_ave_popup_types=>ty_version_row.
  
  " Cached data
  DATA mt_parts TYPE zif_ave_popup_types=>ty_t_part_row.
  DATA mv_html_content TYPE string.
  
  " Code Review
  DATA mo_acr_state TYPE REF TO zcl_ave_acr_state.
  DATA mv_cr_report_html TYPE string.
  DATA mv_in_review_mode TYPE abap_bool.
```

### Основні публічні методи

| Метод | Опис |
|-------|------|
| `constructor` | Зберегти object type + name, apply settings |
| `show` | Main entry point — create UI, enter modal |

### Основні приватні методи

#### Layout Methods

| Метод | Опис |
|-------|------|
| `build_layout` | Створи dialog, containers, splitters |
| `build_parts_list` | Load parts, enrich з line counts |
| `create_parts_alv` | Налаштуй parts grid |
| `create_versions_alv` | Налаштуй versions grid |
| `create_html_viewer` | Створи HTML viewer container |
| `switch_pane_layout` | Toggle split ↔ focused modes |

#### Version Loading

| Метод | Опис |
|-------|------|
| `load_versions` | VRSD load для обраної part |
| `show_source` | Render one version as plain code |
| `show_code_source` | Dispatch to ABAP editor for large files |
| `show_versions_diff` | Load 2 sources, compute diff, render |
| `auto_show_diff_or_source` | Avoid auto-diff for huge new sources |

#### ALV Event Handlers

| Метод | Обробляє |
|-------|----------|
| `handle_parts_command` | Command у parts grid |
| `handle_parts_dblclick` | Double-click на part |
| `handle_vers_command` | Command у versions grid |
| `handle_vers_dblclick` | Double-click на version |
| `handle_parts_toolbar` | Custom toolbar buttons |
| `handle_vers_toolbar` | Custom toolbar buttons |
| `on_toolbar_click` | Global toolbar |

#### Review Methods

| Метод | Опис |
|-------|------|
| `prepare_code_review` | Precompute diffs for all parts |
| `load_review_from_db` | Load persisted state |
| `save_review_to_db` | Persist state |
| `set_hunk_action` | Approve/decline hunk |
| `render_hunk_actions_html` | UI for approve buttons |
| `show_review_help_popup` | Help dialog |

## Роль у архітектурі

```
User Input (Selection Screen)
         ↓
z_ave.prog.abap creates zcl_ave_popup
         ↓
zcl_ave_popup orchestrates:
├─ zcl_ave_object_factory (resolve object)
├─ zcl_ave_object_* (get parts)
├─ zcl_ave_vrsd (load versions)
├─ zcl_ave_version (load source)
├─ zcl_ave_popup_diff (compute diff)
├─ zcl_ave_popup_html (render HTML)
├─ zcl_ave_popup_data (utilities)
└─ zcl_ave_acr_* (review workflow)
         ↓
SAP GUI HTML Viewer displays result
```

## Поточні проблеми (Refactoring Candidates)

### 🔴 Розмір
- **2000+ рядків** у одному класі
- Змішування layout, ALV обробки, version logic, diff, review

### 🟡 Відповідальності
- **UI Layout**: Container/splitter управління
- **ALV Orchestration**: Grid events, selections
- **Version Loading**: VRSD, source code
- **Diff Orchestration**: Compute + render
- **Review State**: Approve/decline management
- **HTML Content**: Diff та review HTML generation

### 🟠 Тестування
- Складно unit-тестувати (SAP GUI залежність)
- Складно mock-ити окремі компоненти

## Рекомендації для розширення

### Додавання нової команди
1. Додай `handle_*_command()` в ALV event
2. Реалізуй логіку (e.g., call service class)
3. Оновлення ALV grid або HTML viewer

### Додавання нового review action
1. Додай метод у [[zcl_ave_acr_state]]
2. Додай рендеринг у [[zcl_ave_acr_renderer]]
3. Обробляй `sapevent:` у `on_sapevent()`
4. Оновлення DB у [[zcl_ave_acr_repository]]

### Оптимізація дифу
1. Модифікуй алгоритм у [[zcl_ave_popup_diff]]
2. **ОБОВ'ЯЗКОВО** синхронізуй з `html_simulator/diff.js`
3. Тестуй обидва варіанти

## Посилання

- [[architecture|Architecture]]
- [[layers/popup-ui-layer|Popup/UI Layer]]
- [[zcl_ave_object_factory]]
- [[zcl_ave_popup_diff]]
- [[zcl_ave_popup_html]]
- [[zcl_ave_acr_state]]

---

**Last Updated**: 2026-05-17