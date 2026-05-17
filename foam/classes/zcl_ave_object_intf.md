# zcl_ave_object_intf - Interface Handler

## Business Description

Handles **ABAP Interfaces** (INTF objects).

Interfaces in ABAP are source-versionable units. This handler extracts the generated interface include as a REPS part.

## Technical Description

### Classification
- **Type**: Object Handler
- **Implements**: [[zif_ave_object]]
- **Scope**: Single interface
- **Dependencies**: SEOCLASS table, SEOCOMPO

### Main Methods

```abap
METHODS constructor
  IMPORTING interface_name TYPE string.

METHODS zif_ave_object~check_exists
  RETURNING VALUE(exists) TYPE abap_bool.

METHODS zif_ave_object~get_name
  RETURNING VALUE(name) TYPE string.

METHODS zif_ave_object~get_parts
  RETURNING VALUE(parts) TYPE zif_ave_popup_types=>ty_t_part_row.
```

### check_exists() - Validation

Checks SEOCLASS table with type = 'I' (interface):

```sql
SELECT * FROM seoclass 
  WHERE clsname = interface_name 
    AND type = 'I'.
```

### get_parts() - Parts Extraction

Returns the generated interface include as REPS:

```abap
APPEND INITIAL LINE TO parts ASSIGNING <p>.
<p>-part_type = 'REPS'.
<p>-part_name = interface_name.  " Generated include name
<p>-object_type = 'INTF'.
<p>-object_name = interface_name.
```

## Usage

```abap
DATA(handler) = zcl_ave_object_factory=>get_instance(
  object_type = 'INTF'
  object_name = 'ZIF_PROCESSOR'
).

DATA(parts) = handler->get_parts().
" Returns: [{ type: REPS, name: ZIF_PROCESSOR }]
```

## Notes

- Interfaces don't have methods as separate parts (unlike classes)
- Uses generated include naming
- Methods are part of the interface definition source

## References

- [[architecture|Architecture]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[zif_ave_object]]
- [[zcl_ave_object_factory]]

---

**Last Updated**: 2026-05-17