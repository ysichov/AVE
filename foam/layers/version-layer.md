# Version Layer 📚

## Призначення

Управління **версіями** ABAP об'єктів:
1. Завантаження метаданих версій (VRSD)
2. Завантаження сирцевого коду для кожної версії
3. Синтез "активної" та "змінченої" версій
4. Пошук TR/task, відповідальних за версію

## Архітектура

```
Part (from Object Handler)
       ↓
VRSD Manager (zcl_ave_vrsd)
  └─→ Load metadata from VRSD + SVRS
  └─→ Add synthetic "Active" version
  └─→ Sort by date
       ↓
Version List (zcl_ave_version rows)
       ↓
User selects 2 versions to compare
       ↓
Version Loader (zcl_ave_version / zcl_ave_version2)
  └─→ Load source code (REPS, FUNC, DDLS, etc.)
  └─→ Find responsible TR/task
  └─→ Resolve author name
       ↓
Version Objects (with source + metadata)
       ↓
Diff Engine (next layer)
```

## Компоненти

### 1. VRSD Manager [[zcl_ave_vrsd]]

**Завдання**: Завантажити метадані **всіх версій** для однієї part.

**Основні методи**:

| Метод | Опис |
|-------|------|
| `constructor` | Ініціалізація, завантаження VRSD, сортування |
| `load_from_table` | Читання з VRSD + SVRS_GET_VERSION_DIRECTORY |
| `load_active_or_modified` | Додання pseudo-versions для активної/змінченої версії |
| `apply_date_from_cutoff` | Фільтр версій по даті |
| `get_request_active_modif` | Знаходження TR для активної версії |

**Приклад**:
```abap
DATA(vrsd) = NEW zcl_ave_vrsd(
  object_type = 'REPS'
  object_name = 'ZTEST_REPORT'
).

DATA(versions) = vrsd->get_versions(). " List of VRSD rows
" ↓
" [
"   { versno: 99998, object: "ZTEST_REPORT", author: "USER1", date: ... },
"   { versno: 5, object: "ZTEST_REPORT", author: "USER2", date: ... },
"   { versno: 4, object: "ZTEST_REPORT", author: "USER1", date: ... },
"   ...
" ]
```

**Версії**:
- `99998` = Active version (синтез)
- `99997` = Modified version (синтез)
- `1..99996` = Historical versions from VRSD

### 2. Version Loader [[zcl_ave_version]]

**Завдання**: Завантажити повне описання **однієї версії** (метадані + сирцевий код).

**Основні методи**:

| Метод | Опис |
|-------|------|
| `constructor` | Зберегти VRSD row |
| `load_attributes` | Скопіювати metadata (date, author, status) |
| `load_latest_task` | Знайти TR/task з E070/E071 |
| `load_author_name` | Резолвити display name користувача |
| `get_source` | Завантажити сирцевий код |

**Приклад**:
```abap
DATA(version) = NEW zcl_ave_version( vrsd_row = row ).

DATA(source_lines) = version->get_source(). " abap_source_table
" ↓
" [
"   "PROGRAM ztest_report.",
"   "DATA: var TYPE string.",
"   "..."
" ]

DATA(author_name) = version->mv_author_name. " "John Doe"
DATA(request_id) = version->mv_request_id.    " "NPLK900123"
```

### 3. Alternative Version Loader [[zcl_ave_version2]]

**Альтернатива** для систем з `SVRS_GET_VERSION_LOCAL/REMOTE`:

```abap
DATA(version2) = NEW zcl_ave_version2(
  object_type = 'REPS'
  object_name = 'ZTEST_REPORT'
  version_number = 5
).

DATA(source) = version2->get_source_local().
" або
DATA(source) = version2->get_source_remote( remote_system = 'P01' ).
```

### 4. Request Manager [[zcl_ave_request]]

**Завдання**: Управління TR/task інформацією (з таблиці E070).

**Методи**:

| Метод | Опис |
|-------|------|
| `constructor` | Завантажити деталі TR (текст, статус) |
| `get_task_for_object` | Знайти task для об'єкта |
| `get_latest_task_for_object` | Найновіший task для об'єкта (в межах дати) |

**Приклад**:
```abap
DATA(request) = NEW zcl_ave_request( trkorr = 'NPLK900123' ).

DATA(task_id) = request->get_latest_task_for_object(
  object_type = 'PROG'
  object_name = 'ZTEST_REPORT'
  version_date = sy-datum
).
" ↓ 'NPLK900124' (task у межах TR)
```

## Version Directory (VRSD) Table

SAP таблиця, що зберігає метадані **всіх версій** об'єкта:

| Поле | Опис |
|------|------|
| `pgmid` | Program ID (R3TR, LIMU, тощо) |
| `object` | Тип об'єкта (PROG, CLAS, FUNC) |
| `obj_name` | Назва об'єкта |
| `versno` | Версія (1, 2, 3, ..., або 0 для active) |
| `version` | Версія текст (長い числові) |
| `author` | SAP користувач |
| `created` | Дата створення |
| `trkorr` | Transport request ID |
| `as4user` | Користувач останнього редагування |
| `as4date` | Дата останнього редагування |

## Синтетичні версії

AVE синтезує додаткові "pseudo-versions" для зручності користувача:

### Active (99998)
- **Джерело**: Поточний активний код у системі
- **Метадані**: взяті з поточної VRSD версії (versno=0)
- **Доцільність**: Дозволяє порівняти історичну версію з поточним станом

### Modified (99997)
- **Джерело**: Поточний код, якщо об'єкт редагується
- **Метадані**: Дата модифікації (sy-datum)
- **Доцільність**: Показати локальні зміни перед commit

**Приклад**:
```
User бачить версії:
  [99998] Active (2026-05-17, USER_CURRENT)
  [99997] Modified (2026-05-17 13:45:00)
  [10] Released (2026-05-10, USER2)
  [9]  Released (2026-05-05, USER1)
  ...
```

## Потік версійних даних

```
1. User обирає Part з Parts ALV grid
   ↓
2. VRSD Manager завантажує всі версії цієї part:
   - VRSD таблиця (історичні версії)
   - SVRS API (доповнення)
   - Синтез Active + Modified
   ↓
3. Versions ALV grid відображає список
   ↓
4. User вибирає 2 версії для порівняння
   ↓
5. Для кожної версії:
   - Version Loader завантажує сирцевий код
   - Резолвить автора
   - Знаходить TR/task
   ↓
6. Обидві версії готові для Diff Engine
```

## Обмеження та особливості

- **VRSD**: Зберігає только "released" версії; активна версія синтезується
- **DDLS**: Спеціальна загрузка через TLOGO контролер
- **Кешування**: zcl_ave_vrsd та zcl_ave_author мають internal cache для оптимізації
- **Дата cutoff**: Опційно фільтрувати версії до дати
- **Modified версія**: Обчислюється лише якщо об'єкт редагується

## Посилання

- [[architecture|Main Architecture]]
- [[zcl_ave_vrsd]]
- [[zcl_ave_version]]
- [[zcl_ave_version2]]
- [[zcl_ave_request]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[layers/diff-render-layer|Diff/Render Layer]]

---

**Last Updated**: 2026-05-17