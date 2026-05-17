# zcl_ave_vrsd - Version Directory Manager

## Business Description

Завантажує та управляє **версіями об'єкта** з SAP таблиці VRSD (Version Directory):
- Читає historical versions
- Синтезує "Active" та "Modified" versions
- Сортує by date (newest first)
- Опційно фільтрує по даті (дата cutoff)

По суті, це **версійна історія** об'єкта у зручному форматі для AVE.

## Technical Description

### Класифікація
- **Type**: Data Access / Aggregation
- **Scope**: Part-specific (per object type + name)
- **Dependencies**: SAP APIs (SVRS_GET_VERSION_DIRECTORY_46, etc.)

### Основні публічні методи

| Метод | Опис |
|-------|------|
| `constructor` | Load VRSD, apply cutoff, sort |
| `get_versions` | Return list of version rows (ty_version_row) |
| `get_request_active_modif` | Find TR for active/modified version |

### constructor() — Ініціалізація та завантаження

**Вхід**:
```abap
io_vrsd = zcl_ave_vrsd(
  object_type = 'REPS'         " REPS, METH, FUNC, DDLS
  object_name = 'ZTEST'
  version_cutoff_date = '20260501'  " Optional: filter to <=date
).
```

**Процес**:
1. Зберегти object type + name
2. `load_from_table()` — Читати VRSD
3. `load_active_or_modified()` — Синтезувати pseudo-versions
4. Sort by date (newest first)
5. Apply date cutoff (якщо задано)

### load_from_table() — VRSD Reading

Читає таблицю VRSD та SVRS API:

```sql
SELECT FROM VRSD WHERE
  pgmid = 'R3TR'      " Standard object type
  AND object = <type> " PROG, CLAS, FUNC, etc.
  AND obj_name = <name>
```

**VRSD Поля**:
- `versno`: Version number (1, 2, 3, ...)
- `author`: User who released
- `created`: Дата створення
- `trkorr`: Transport ID
- `as4date`: Дата останнього update
- `as4user`: User who updated

**SVRS API** (додаткова інформація):
- `SVRS_GET_VERSION_DIRECTORY_46`: Extended версійна інформація
- Provides: Release status, comments, etc.

### load_active_or_modified() — Синтез версій

Додає pseudo-versions для поточного стану:

**Active Version (99998)**:
```abap
APPEND INITIAL LINE TO mt_versions ASSIGNING <v>.
<v>-versno = 99998.                    " Special number
<v>-author = sy-uname.                 " Current user
<v>-created = sy-datum && sy-timlo.
<v>-trkorr = 'ACTIVE'.                 " Marker
<v>-status = 'A'.                       " Active
```

**Modified Version (99997)**:
```abap
APPEND INITIAL LINE TO mt_versions ASSIGNING <v>.
<v>-versno = 99997.
<v>-author = sy-uname.
<v>-created = sy-datum && sy-timlo.
<v>-trkorr = 'MODIFIED'.
<v>-status = 'M'.                       " Modified
```

**Логіка**:
- Якщо об'єкт редагується (lock exists) → додай Modified
- Завжди додавай Active (для порівняння з поточним станом)

### apply_date_from_cutoff() — Фільтрація по даті

Якщо задана дата cutoff:

```abap
" Keep версії до дати, плюс найновіша версія перед cutoff

" Example:
  V1: 2026-04-01 ✓ keep (перед cutoff)
  V2: 2026-04-20 ✓ keep
  V3: 2026-05-10 ✗ remove (після cutoff)
  V4: 2026-05-15 ✗ remove
```

### get_request_active_modif() — Find TR for Active/Modified

Для Active/Modified версій, знайди TR/task:

```abap
METHODS get_request_active_modif
  IMPORTING
    iv_object_type TYPE string
    iv_object_name TYPE string
  RETURNING
    VALUE(rv_trkorr) TYPE trkorr.
```

**Процес**:
1. Перевір SAP lock tables (E071 is locked?)
2. Знайди TR у E070/E071
3. Return TR ID або SPACE

## Типи даних

```abap
TYPES BEGIN OF ty_version_row.
  versno TYPE int4.           " Version number (1, 2, ..., 99998, 99997)
  author TYPE string.         " User display name
  created TYPE string.        " Timestamp
  trkorr TYPE trkorr.         " Transport ID
  status TYPE char1.          " A=Active, M=Modified, space=Released
  line_count TYPE int4.       " Optional: # of lines
  object_type TYPE string.    " REPS, METH, FUNC, DDLS
  object_name TYPE string.    " Object name
TYPES END OF ty_version_row.
```

## Workflow: Version Loading

```
1. User обирає Part у ALV
   ↓
2. zcl_ave_popup loads_versions()
   ↓
3. NEW zcl_ave_vrsd(
     object_type = "REPS",
     object_name = "ZTEST"
   )
   ├─ Reads VRSD table
   ├─ Calls SVRS APIs
   ├─ Synthesizes Active + Modified
   └─ Sorts by date
   ↓
4. Versions ALV grid shows:
   [99998] Active (2026-05-17)
   [99997] Modified (2026-05-17 14:30:00)
   [10] Released (2026-05-10)
   [9] Released (2026-05-05)
   [8] Released (2026-04-30)
   ...
```

## Performance & Caching

- **VRSD Cache**: Class-level cache per part (avoid re-reading)
- **SVRS Call**: Only on demand (lazy loading)
- **Date Cutoff**: Applied at load time (efficient filtering)

## Обмеження

- **Unreleased objects**: Версії не записуються у VRSD поки не released
- **Historical versions**: Только released (не draft/modify-in-place)
- **DDLS**: Special handling (читаються через TLOGO controller)
- **Modified**: Детектується через lock tables (може не завжди бути точна)

## Посилання

- [[architecture|Architecture]]
- [[layers/version-layer|Version Layer]]
- [[zcl_ave_version]]
- [[zcl_ave_request]]
- [[zcl_ave_popup]]

---

**Last Updated**: 2026-05-17