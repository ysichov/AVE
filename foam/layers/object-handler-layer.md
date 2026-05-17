# Object Handler Layer 📦

## Призначення

Трансформація логічного вхідного об'єкта (задано користувачем за типом та назвою) в **список versionable parts** — окремих компонентів, які версіюються незалежно.

## Архітектура

```
Input: Object Type (PROG, CLAS, FUNC, etc.) + Name
         ↓
Object Factory (zcl_ave_object_factory)
         ↓
Handler Instance (zcl_ave_object_*)
         ↓
Output: List of Parts
  ├─ REPS (program/include source)
  ├─ METH (class method)
  ├─ FUNC (function module)
  └─ DDLS (CDS DDL source)
```

## Інтерфейс (Contract)

Всі обробники реалізують [[zif_ave_object]]:

```abap
INTERFACE zif_ave_object.
  
  " Check if object exists in the system
  METHODS check_exists
    RETURNING VALUE(exists) TYPE abap_bool.
  
  " Get the logical name (object name)
  METHODS get_name
    RETURNING VALUE(name) TYPE string.
  
  " Get list of versionable parts
  METHODS get_parts
    RETURNING VALUE(parts) TYPE zif_ave_popup_types=>ty_t_part_row.

ENDINTERFACE.
```

## Обробники за типами об'єктів

### 1. Program/Include Handler [[zcl_ave_object_prog]]

| Аспект | Опис |
|--------|------|
| **Вхід** | Program/Include name (e.g., `ZREPORT`, `ZXX_TOP`) |
| **Частини** | 1 part: `REPS` (тип: Repository Source) |
| **Проверка** | `TRDIR` таблиця |
| **Special** | Не розрізняє top-includes від programs |

**Приклад**:
```
Input: PROG, "ZTEST_REPORT"
Output: 
  [{ type: "REPS", name: "ZTEST_REPORT", ... }]
```

### 2. ABAP Class Handler [[zcl_ave_object_clas]]

| Аспект | Опис |
|--------|------|
| **Вхід** | Class name (e.g., `ZCL_MY_CLASS`) |
| **Частини** | Декілька: класс секції, includes, test include, методи |
| **Проверка** | `SEOCLASS` + `cl_abap_classdescr` |
| **Special** | Розрізняє публічні/приватні методи |

**Приклад**:
```
Input: CLAS, "ZCL_MANAGER"
Output:
  [
    { type: "REPS", name: "ZCL_MANAGER", part: "definitions", ... },
    { type: "REPS", name: "ZCL_MANAGER", part: "implementation", ... },
    { type: "METH", name: "ZCL_MANAGER", method: "GET_DATA", ... },
    { type: "METH", name: "ZCL_MANAGER", method: "PROCESS", ... },
    ...
  ]
```

### 3. Function Module Handler [[zcl_ave_object_func]]

| Аспект | Опис |
|--------|------|
| **Вхід** | Function module name (e.g., `Z_GET_ARTICLES`) |
| **Частини** | 1 part: `FUNC` |
| **Проверка** | `FUNCTION_EXISTS` RFC |
| **Special** | Включає IMPORT/EXPORT параметри у metadata |

**Приклад**:
```
Input: FUNC, "Z_GET_DATA"
Output:
  [{ type: "FUNC", name: "Z_GET_DATA", ... }]
```

### 4. Interface Handler [[zcl_ave_object_intf]]

| Аспект | Опис |
|--------|------|
| **Вхід** | Interface name (e.g., `ZIF_PROCESSOR`) |
| **Частини** | 1 part: `REPS` (generated interface include) |
| **Проверка** | `SEOCLASS` з type = "I" (interface) |
| **Special** | Резолвить гененовані include имена |

### 5. CDS DDL Source Handler [[zcl_ave_object_ddls]]

| Аспект | Опис |
|--------|------|
| **Вхід** | DDLS name (e.g., `ZC_ARTICLES`) |
| **Частини** | 1 part: `DDLS` |
| **Проверка** | `TADIR` + `R3TR/DDLS` |
| **Special** | Спеціальна загрузка源 через `cl_svrs_tlogo_controller` |

### 6. Transport Request Handler [[zcl_ave_object_tr]]

| Аспект | Опис |
|--------|------|
| **Вхід** | Transport ID (e.g., `NPLK900123`) |
| **Частини** | **N** об'єктів, розгорнуті з E071 |
| **Проверка** | Валідність TR у E070 |
| **Special** | **Drill-in**: для classes → розгорнути на методи |

**Приклад**:
```
Input: TR, "NPLK900123"
  (TR містить: Z_PROG, ZCL_MANAGER)
Output:
  [
    { type: "REPS", name: "Z_PROG", ... },
    { type: "REPS", name: "ZCL_MANAGER", part: "definitions", ... },
    { type: "METH", name: "ZCL_MANAGER", method: "PROCESS", ... },
    ...
  ]
```

### 7. Package Handler [[zcl_ave_object_pack]]

| Аспект | Опис |
|--------|------|
| **Вхід** | Package name (e.g., `Z_MYAPP`) |
| **Частини** | **N** об'єктів із `TADIR` package |
| **Проверка** | `TDEVC` таблиця |
| **Special** | Фільтр: тільки підтримувані типи |

## Factory Pattern

[[zcl_ave_object_factory]] централізує створення обробників:

```abap
DATA(handler) = zcl_ave_object_factory=>get_instance(
  object_type = 'CLAS'
  object_name = 'ZCL_MANAGER'
).

DATA(parts) = handler->get_parts().
```

**Factory логіка**:
1. Перевіри тип об'єкта
2. Вибери відповідний клас обробника
3. Перевір існування об'єкта
4. Raise `zcx_ave` якщо невідомий тип або об'єкт не існує

## Розширення: Додання новго типу

Щоб підтримати новий тип об'єкта (наприклад, `TABL` для таблиць):

1. **Створи обробник**:
```abap
CLASS zcl_ave_object_tabl DEFINITION.
  PUBLIC SECTION.
    INTERFACES zif_ave_object.
    
    METHODS constructor
      IMPORTING table_name TYPE tabl-tabname.
    
  PRIVATE SECTION.
    DATA mv_name TYPE tabl-tabname.
ENDCLASS.
```

2. **Реалізуй interface методи**:
```abap
METHODS zif_ave_object~get_parts ...
  "Return single TABL part or error if unsupported
ENDMETHOD.
```

3. **Додай у Factory**:
```abap
WHEN 'TABL'.
  ro_handler = NEW zcl_ave_object_tabl( table_name = object_name ).
```

4. **Тестуй** через z_ave.prog.abap selection screen.

## Поточні обмеження

- **Частини**: Закодовані типи (REPS, METH, FUNC, DDLS)
- **Вкладені об'єкти**: TR/Package розгортають лише на перший рівень
- **Фільтрація**: Деякі типи (наприклад, TEXT елементи) пропускаються
- **Класи**: Методи розгортаються, але вкладені классы (inner) не підтримуються

## Посилання

- [[architecture|Main Architecture]]
- [[zif_ave_object]]
- [[zcl_ave_object_factory]]

---

**Last Updated**: 2026-05-17