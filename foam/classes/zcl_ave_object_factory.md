# zcl_ave_object_factory - Object Handler Factory

## Business Description

**Factory pattern** для створення правильного обробника об'єкта на основі типу.

Замість великого switch/if statement у popup, користувач каже "мені потрібен обробник для PROG Z_REPORT", а factory повертає готовий handler який знає как витягувати parts для програм.

## Technical Description

### Класифікація
- **Type**: Factory / Service Locator
- **Scope**: Global
- **Dependencies**: All `zcl_ave_object_*` handlers

### Основна публічна метод

```abap
CLASS zcl_ave_object_factory DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS get_instance
      IMPORTING
        object_type TYPE string
        object_name TYPE string
      RETURNING
        VALUE(ro_handler) TYPE REF TO zif_ave_object
      RAISING
        zcx_ave.
ENDCLASS.

CLASS zcl_ave_object_factory IMPLEMENTATION.
  METHOD get_instance.
    " Лоґіка:
    CASE object_type.
      WHEN 'PROG'.
        ro_handler = NEW zcl_ave_object_prog( object_name ).
      WHEN 'CLAS'.
        ro_handler = NEW zcl_ave_object_clas( object_name ).
      WHEN 'FUNC'.
        ro_handler = NEW zcl_ave_object_func( object_name ).
      WHEN 'INTF'.
        ro_handler = NEW zcl_ave_object_intf( object_name ).
      WHEN 'DDLS'.
        ro_handler = NEW zcl_ave_object_ddls( object_name ).
      WHEN 'TR'.
        ro_handler = NEW zcl_ave_object_tr( object_name ).
      WHEN 'DEVC'.
        ro_handler = NEW zcl_ave_object_pack( object_name ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_ave
          EXPORTING message = 'Unsupported object type'.
    ENDCASE.
    
    " Перевір існування
    IF NOT ro_handler->check_exists( ).
      RAISE EXCEPTION TYPE zcx_ave
        EXPORTING message = 'Object does not exist'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```

## Usage

```abap
TRY.
  DATA(handler) = zcl_ave_object_factory=>get_instance(
    object_type = 'CLAS'
    object_name = 'ZCL_MANAGER'
  ).
  
  DATA(parts) = handler->get_parts().
  
CATCH zcx_ave INTO DATA(exc).
  " Handle error
ENDTRY.
```

## Підтримувані типи

| Type | Handler | Підтримано? |
|------|---------|-----------|
| PROG | [[zcl_ave_object_prog]] | ✅ |
| CLAS | [[zcl_ave_object_clas]] | ✅ |
| FUNC | [[zcl_ave_object_func]] | ✅ |
| INTF | [[zcl_ave_object_intf]] | ✅ |
| DDLS | [[zcl_ave_object_ddls]] | ✅ |
| TR | [[zcl_ave_object_tr]] | ✅ |
| DEVC | [[zcl_ave_object_pack]] | ✅ |
| TABL | - | ❌ |
| VIEW | - | ❌ |
| DTEL | - | ❌ |

## Розширення: Додання нового типу

1. **Створи обробник**:
```abap
CLASS zcl_ave_object_tabl DEFINITION.
  PUBLIC SECTION.
    INTERFACES zif_ave_object.
  PRIVATE SECTION.
    DATA mv_table_name TYPE tabl-tabname.
ENDCLASS.
```

2. **Додай у factory**:
```abap
WHEN 'TABL'.
  ro_handler = NEW zcl_ave_object_tabl( object_name ).
```

3. **Тестуй**:
```abap
DATA(handler) = zcl_ave_object_factory=>get_instance(
  object_type = 'TABL'
  object_name = 'ZTEST_TABLE'
).
```

## Посилання

- [[architecture|Architecture]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[zif_ave_object]]
- [[zcl_ave_object_prog]]
- [[zcl_ave_object_clas]]
- [[zcl_ave_object_func]]

---

**Last Updated**: 2026-05-17