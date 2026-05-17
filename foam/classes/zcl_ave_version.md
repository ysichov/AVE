# zcl_ave_version - Single Version Loader

## Business Description

Представляє **одну версію** об'єкта:
- Метадані (дата, автор, TR)
- Сирцевий код (REPS, FUNC, DDLS, тощо)
- Display name автора
- Responsible TR/task information

По суті, це **snapshot** об'єкта у конкретний момент часу.

## Technical Description

### Класифікація
- **Type**: Domain Object / Data Container
- **Scope**: Single version instance
- **Dependencies**: [[zcl_ave_author]] (user name resolution), [[zcl_ave_request]] (TR lookup)

### Основні публічні методи

| Метод | Опис |
|-------|------|
| `constructor` | Store VRSD row |
| `get_source` | Load source code (lazy) |
| `load_attributes` | Copy metadata |
| `load_latest_task` | Find responsible TR |
| `load_author_name` | Resolve user display name |

### constructor() — Ініціалізація

```abap
DATA(version) = NEW zcl_ave_version( vrsd_row = <row> ).

" VRSD row містить:
"   versno = 5
"   author = 'USER1'
"   created = '20260510'
"   trkorr = 'NPLK900123'
```

**Процес**:
1. Зберегти VRSD row
2. `load_attributes()` → Copy metadata
3. `load_author_name()` → Resolve display name
4. `load_latest_task()` → Find TR
5. (Source code завантажується на demand via `get_source()`)

### get_source() — Load Source Code

```abap
DATA(source_lines) = version->get_source().
" Returns: abap_source_table
" [
"   "PROGRAM ztest_report.",
"   "DATA: var1 TYPE string.",
"   "..."
" ]
```

**Process**:
- For **REPS** (program/include): Use `SVRS_GET_REPS_FROM_OBJECT`
- For **FUNC** (function module): Use `SVRS_GET_FUNCTION_FROM_OBJECT`
- For **DDLS** (CDS): Use `cl_svrs_tlogo_controller` (special DDLS handling)
- Caching: Завантажується один раз, потім кешується

### load_attributes() — Metadata Copy

Копіює поля з VRSD row:

```abap
PRIVATE DATA mv_versno TYPE int4.
PRIVATE DATA mv_author TYPE string.
PRIVATE DATA mv_created TYPE timestamp.
PRIVATE DATA mv_trkorr TYPE trkorr.
PRIVATE DATA mv_status TYPE char1.

METHODS load_attributes.
  mv_versno = vrsd_row-versno.
  mv_author = vrsd_row-author.
  mv_created = CONCATENATE(vrsd_row-created, vrsd_row-time).
  mv_trkorr = vrsd_row-trkorr.
  mv_status = vrsd_row-status.
ENDMETHOD.
```

### load_author_name() — User Name Resolution

Резолвить user ID (e.g., "USER1") у display name (e.g., "John Doe"):

```abap
mv_author_name = zcl_ave_author=>get_name( user = mv_author ).
" Uses cached resolution from zcl_ave_author
```

**Fallback**:
- Check USER_ADDR → display name
- Check USR21/ADRP → last name + first name
- Fallback to username if not found

### load_latest_task() — Find Responsible TR

Знаходить TR/task, відповідальний за цю версію:

```abap
METHODS load_latest_task.
  DATA(request) = NEW zcl_ave_request( mv_trkorr ).
  
  mv_task_id = request->get_latest_task_for_object(
    object_type = object_type
    object_name = object_name
    version_date = mv_created
  ).
ENDMETHOD.
```

**Логіка**:
- TR має задачі (sub-requests)
- Знайди задачу для цього об'єкта в межах дати версії

## Public Read-Only Properties

```abap
PUBLIC SECTION READ-ONLY.
  DATA mv_versno TYPE int4.
  DATA mv_author TYPE string.
  DATA mv_author_name TYPE string.     " Display name
  DATA mv_created TYPE timestamp.
  DATA mv_trkorr TYPE trkorr.          " Transport ID
  DATA mv_task_id TYPE trkorr.         " Task ID (sub-request)
  DATA mv_status TYPE char1.           " A=Active, M=Modified
```

## Приклад Usage

```abap
DATA(vrsd_row) = ...  " Loaded from VRSD

DATA(version) = NEW zcl_ave_version( vrsd_row = vrsd_row ).

WRITE: / version->mv_versno.          " 5
WRITE: / version->mv_author_name.     " "John Doe"
WRITE: / version->mv_created.         " "2026-05-10 10:30:45"
WRITE: / version->mv_trkorr.          " "NPLK900123"

DATA(source) = version->get_source().
LOOP AT source INTO DATA(line).
  WRITE: / line.
ENDLOOP.
```

## Синтетичні версії (Special Cases)

### Active Version (versno=99998)

```abap
mv_versno = 99998
mv_status = 'A'        " Active marker
mv_author = sy-uname   " Current user
mv_created = sy-datum  " Current date
mv_trkorr = 'ACTIVE'   " Synthetic

" get_source() повертає поточний активний код з системи
```

### Modified Version (versno=99997)

```abap
mv_versno = 99997
mv_status = 'M'        " Modified marker
mv_author = sy-uname
mv_created = sy-datum
mv_trkorr = 'MODIFIED' " Synthetic

" get_source() повертає поточний модифікований код
```

## Performance Considerations

- **Lazy Loading**: Source code завантажується тільки при `get_source()`
- **Caching**: Source кешується після першого завантаження
- **SVRS APIs**: Можуть бути повільні для великих файлів
- **Author Resolution**: Кешується у [[zcl_ave_author]]

## Обмеження

- **VRSD metadata**: Тільки для released версій
- **Active/Modified**: Синтезуються, не у VRSD
- **DDLS**: Спеціальна загрузка (тільки лінії, не объект)
- **Task Lookup**: Залежить від E070/E071 доступності

## Посилання

- [[architecture|Architecture]]
- [[layers/version-layer|Version Layer]]
- [[zcl_ave_vrsd]]
- [[zcl_ave_request]]
- [[zcl_ave_author]]
- [[zcl_ave_popup]]

---

**Last Updated**: 2026-05-17