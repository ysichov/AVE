# zcl_ave_object_func - Function Module Handler

## Business Description

Handles **Function Modules** (FUNC objects).

Function modules are individual versionable units in SAP. This handler extracts a single FUNC part for versioning.

## Technical Description

### Classification
- **Type**: Object Handler
- **Implements**: [[zif_ave_object]]
- **Scope**: Single function module
- **Dependencies**: FUNCTION_EXISTS RFC, TFDIR table

### Main Methods

```abap
METHODS constructor
  IMPORTING function_name TYPE string.

METHODS zif_ave_object~check_exists
  RETURNING VALUE(exists) TYPE abap_bool.

METHODS zif_ave_object~get_name
  RETURNING VALUE(name) TYPE string.

METHODS zif_ave_object~get_parts
  RETURNING VALUE(parts) TYPE zif_ave_popup_types=>ty_t_part_row.
```

### check_exists() - Validation

Uses FUNCTION_EXISTS RFC call:

```abap
CALL FUNCTION 'FUNCTION_EXISTS'
  EXPORTING funcname = function_name
  IMPORTING rc = result.
```

### get_parts() - Parts Extraction

Returns a single FUNC part:

```abap
APPEND INITIAL LINE TO parts ASSIGNING <p>.
<p>-part_type = 'FUNC'.
<p>-part_name = function_name.
<p>-object_type = 'FUNC'.
<p>-object_name = function_name.
```

## Usage

```abap
DATA(handler) = zcl_ave_object_factory=>get_instance(
  object_type = 'FUNC'
  object_name = 'Z_GET_ARTICLES'
).

DATA(parts) = handler->get_parts().
" Returns: [{ type: FUNC, name: Z_GET_ARTICLES }]
```

## Notes

- Single versionable unit (no sub-parts)
- IMPORT/EXPORT parameters are metadata only
- Exceptions and tables are included in the source

## References

- [[architecture|Architecture]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[zif_ave_object]]
- [[zcl_ave_object_factory]]

---

**Last Updated**: 2026-05-17