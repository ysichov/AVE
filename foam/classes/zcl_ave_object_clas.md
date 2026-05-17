# zcl_ave_object_clas - ABAP Class Handler

## Business Description

Handles **ABAP Classes** (CLAS objects).

This handler breaks down a class into multiple versionable parts:
- Class definitions section
- Implementation section
- Individual methods (METH parts)
- Local includes
- Test include (if exists)

This allows comparing specific methods instead of the entire class.

## Technical Description

### Classification
- **Type**: Object Handler
- **Implements**: [[zif_ave_object]]
- **Scope**: Single ABAP class
- **Dependencies**: SEOCLASS, SEOCOMPO, cl_abap_classdescr

### Main Methods

```abap
METHODS constructor
  IMPORTING class_name TYPE string.

METHODS zif_ave_object~check_exists
  RETURNING VALUE(exists) TYPE abap_bool.

METHODS zif_ave_object~get_name
  RETURNING VALUE(name) TYPE string.

METHODS zif_ave_object~get_parts
  RETURNING VALUE(parts) TYPE zif_ave_popup_types=>ty_t_part_row.
```

### check_exists() - Validation

Uses ABAP API and SEOCLASS table:

```abap
TRY.
  DATA(descr) = cl_abap_classdescr=>describe_by_name( class_name ).
CATCH.
  RETURN abap_false.
ENDTRY.
```

### get_parts() - Parts Extraction

Returns multiple parts:

```
Class ZCL_MANAGER
├─ REPS (definitions section)
├─ REPS (implementation section)
├─ METH ZCL_MANAGER~GET_DATA
├─ METH ZCL_MANAGER~PROCESS
├─ METH ZCL_MANAGER~ON_INIT
├─ REPS (local includes)
└─ REPS (test include - if exists)
```

**Example**:

```abap
DATA(handler) = zcl_ave_object_factory=>get_instance(
  object_type = 'CLAS'
  object_name = 'ZCL_MANAGER'
).

DATA(parts) = handler->get_parts().
" Returns: [
"   { type: REPS, name: ZCL_MANAGER, part: DEFINITIONS },
"   { type: REPS, name: ZCL_MANAGER, part: IMPLEMENTATION },
"   { type: METH, name: ZCL_MANAGER~GET_DATA },
"   { type: METH, name: ZCL_MANAGER~PROCESS },
"   ...
" ]
```

## Features

- **Method-level versioning**: Compare individual methods
- **Section separation**: View definitions vs implementation
- **Test includes**: Separate versioning for unit tests
- **Local includes**: Tracking of class-local includes

## Notes

- Methods are extracted from SEOCOMPO (component table)
- Private methods are included in the parts list
- Static methods are supported
- Inner classes are NOT supported

## References

- [[architecture|Architecture]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[zif_ave_object]]
- [[zcl_ave_object_factory]]

---

**Last Updated**: 2026-05-17