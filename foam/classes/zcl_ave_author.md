# zcl_ave_author - User Name Resolver

## Business Description

Утиліта для резолвірання **SAP user ID** у **display name**.

Резолвить: `USER1` → `John Doe` (or full name from ADDRESS data)

Це потрібно для красивого показу авторів версій у UI.

## Technical Description

### Класифікація
- **Type**: Utility / Service
- **Scope**: Global (used everywhere)
- **Dependencies**: SAP tables (USER_ADDR, USR21, ADRP)
- **Caching**: Class-level cache (avoid re-querying)

### Основна публічна метод

```abap
CLASS zcl_ave_author DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS get_name
      IMPORTING user TYPE string
      RETURNING VALUE(display_name) TYPE string.
ENDCLASS.
```

### get_name() — User Name Resolution

**Логіка**:
1. Перевір class-level cache
2. If not cached:
   - Query USER_ADDR (user address record)
   - Fallback to USR21 (login name record)
   - Fallback to ADRP (general address)
3. Return display name or username

**Приклад**:

```abap
DATA(name1) = zcl_ave_author=>get_name( user = 'USER1' ).
" ↓
" "John Doe"

DATA(name2) = zcl_ave_author=>get_name( user = 'UNKNOWN_USER' ).
" ↓
" "UNKNOWN_USER"  (fallback to username)
```

### Priority Order

1. **USER_ADDR** (перевага):
   - Field: `NAME1` + `NAME2`
   - Best choice: Full address data

2. **USR21** (fallback):
   - Field: `GNAME` (last name)
   - Field: `FNAME` (first name)

3. **Username** (last resort):
   - Just return the user ID as-is

### Caching

**Зберіг кешу**:
```abap
PRIVATE CLASS DATA mt_author_cache TYPE TABLE OF ty_author_cache.

TYPES BEGIN OF ty_author_cache.
  user TYPE string.
  display_name TYPE string.
TYPES END OF ty_author_cache.
```

**Логіка**:
- При першому запиту → завантажити з DB, cache
- При другому запиту → return from cache
- Уникаємо дублювання DB запитів

### Performance

- **First call**: ~50ms (DB query)
- **Cached calls**: ~1ms (table lookup)
- **Impact**: Мало помітно для типового UI

## Usage in AVE

```abap
DATA(version) = NEW zcl_ave_version( vrsd_row = row ).
version->load_author_name().  " Uses zcl_ave_author internally

" Later:
WRITE: / version->mv_author_name.  " "John Doe" (cached)
```

## Обмеження

- **Missing users**: Return username as fallback (не error)
- **Performance**: DB queries можуть бути повільні для 1000+ users
- **Cache lifetime**: Class-level cache (очищена при new session)

## Посилання

- [[architecture|Architecture]]
- [[zcl_ave_version]]
- [[zcl_ave_popup_data]]

---

**Last Updated**: 2026-05-17