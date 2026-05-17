# zif_ave_object - Object Handler Interface

## Business Description

Контракт, який повинен реалізувати **кожний обробник об'єкта**.

Говорить: "Якщо ви хочете обробляти новий тип об'єкта, реалізуйте ці 3 методи, і все буде працювати".

## Technical Description

### Класифікація
- **Type**: Interface / Contract
- **Scope**: Global (all handlers implement)
- **Implementations**: [[zcl_ave_object_prog]], [[zcl_ave_object_clas]], [[zcl_ave_object_func]], [[zcl_ave_object_ddls]], [[zcl_ave_object_intf]], [[zcl_ave_object_tr]], [[zcl_ave_object_pack]]

### Методи

```abap
INTERFACE zif_ave_object.
  
  " Check if object exists in the system
  METHODS check_exists
    RETURNING VALUE(exists) TYPE abap_bool.
  
  " Get the logical object name
  METHODS get_name
    RETURNING VALUE(name) TYPE string.
  
  " Get list of versionable parts
  METHODS get_parts
    RETURNING VALUE(parts) TYPE zif_ave_popup_types=>ty_t_part_row.
  
ENDINTERFACE.
```

### check_exists() — Object Existence Check

**Мета**: Перевірити чи об'єкт існує у системі.

**Приклади реалізації**:

- **PROG**: Check TRDIR table
  ```sql
  SELECT * FROM trdir WHERE name = object_name.
  ```

- **CLAS**: Use ABAP API
  ```abap
  TRY.
    DATA(descr) = cl_abap_classdescr=>describe_by_name( object_name ).
  CATCH.
    RETURN abap_false.
  ENDTRY.
  ```

- **FUNC**: RFC call
  ```abap
  CALL FUNCTION 'FUNCTION_EXISTS'
    EXPORTING funcname = object_name
    IMPORTING rc = result.
  ```

- **TR**: Check E070 table
  ```sql
  SELECT * FROM e070 WHERE trkorr = object_name.
  ```

### get_name() — Object Name

**Мета**: Повернути логічну назву об'єкта (те ж що введено користувачем).

**Приклад**:
```abap
mv_object_name = 'ZCL_MANAGER'.
" Return value: 'ZCL_MANAGER'
```

**Практично**: Завжди повертає то ж, що задано у constructor.

### get_parts() — Versionable Parts

**Мета**: Повернути список **versionable parts** цього об'єкта.

**Part** — це одиниця, яка версіюється незалежно.

**Приклади**:

1. **Program** (PROG "ZTEST"):
   ```
   Parts: [REPS "ZTEST"]
   ```

2. **Class** (CLAS "ZCL_MANAGER"):
   ```
   Parts: [
     REPS "ZCL_MANAGER" (definitions),
     REPS "ZCL_MANAGER" (implementation),
     METH "ZCL_MANAGER~GET_DATA",
     METH "ZCL_MANAGER~PROCESS",
     REPS "ZCL_MANAGER" (test include)
   ]
   ```

3. **Function Module** (FUNC "Z_GET_DATA"):
   ```
   Parts: [FUNC "Z_GET_DATA"]
   ```

4. **Transport Request** (TR "NPLK900123"):
   ```
   Parts: [
     REPS "Z_REPORT",
     REPS "ZCL_MANAGER" (definitions),
     METH "ZCL_MANAGER~GET_DATA",
     FUNC "Z_PROCESS",
     ...
   ]
   ```

**Data Structure**:
```abap
TYPES BEGIN OF ty_part_row.
  part_type TYPE string.      " REPS, METH, FUNC, DDLS
  part_name TYPE string.      " Object name
  method_name TYPE string.    " For METH parts only
  object_type TYPE string.    " PROG, CLAS, FUNC, DDLS, etc.
  object_name TYPE string.
TYPES END OF ty_part_row.
```

## Implementation Pattern

Для додання нового типу об'єкта:

```abap
CLASS zcl_ave_object_xyz DEFINITION.
  PUBLIC SECTION.
    INTERFACES zif_ave_object.
    METHODS constructor IMPORTING xyz_name TYPE string.
  PRIVATE SECTION.
    DATA mv_xyz_name TYPE string.
ENDCLASS.

CLASS zcl_ave_object_xyz IMPLEMENTATION.
  
  METHOD constructor.
    mv_xyz_name = xyz_name.
  ENDMETHOD.
  
  METHOD zif_ave_object~check_exists.
    SELECT * FROM XYZ_TABLE WHERE name = mv_xyz_name.
    IF sy-subrc = 0.
      exists = abap_true.
    ELSE.
      exists = abap_false.
    ENDIF.
  ENDMETHOD.
  
  METHOD zif_ave_object~get_name.
    name = mv_xyz_name.
  ENDMETHOD.
  
  METHOD zif_ave_object~get_parts.
    " Розбей object на parts...
    APPEND INITIAL LINE TO parts ASSIGNING <p>.
    <p>-part_type = 'XYZ'.
    <p>-part_name = mv_xyz_name.
    <p>-object_type = 'XYZ'.
    <p>-object_name = mv_xyz_name.
  ENDMETHOD.
  
ENDCLASS.
```

## Role in AVE

```
User Input:
  Type = 'CLAS', Name = 'ZCL_MANAGER'
  
            ↓
            
zcl_ave_object_factory=>get_instance()
  ├─ Determine type → 'CLAS'
  └─ Create zcl_ave_object_clas instance
  
            ↓
            
handler->check_exists() ✓
  └─ Verify class exists
  
            ↓
            
popup->build_parts_list()
  ├─ handler->get_parts()
  └─ [REPS, REPS, METH, METH, METH, ...]
  
            ↓
            
Parts ALV grid populated
            ↓
User selects part → versions loaded → diff computed
```

## Посилання

- [[architecture|Architecture]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[zcl_ave_object_factory]]
- [[zcl_ave_object_prog]]
- [[zcl_ave_object_clas]]
- [[zcl_ave_object_func]]
- [[zcl_ave_object_ddls]]

---

**Last Updated**: 2026-05-17