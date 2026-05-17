# zcl_ave_object_prog - Program/Include Handler

## Business Description

Handles **Programs and Includes** (PROG/REPS objects).

This handler extracts versionable parts from a program or include file. Programs are typically simple — they contain a single source code unit that can be versioned.

## Technical Description

### Classification
- **Type**: Object Handler
- **Implements**: [[zif_ave_object]]
- **Scope**: Single program/include
- **Dependencies**: TRDIR table (SAP program directory)

### Main Methods

```abap
METHODS constructor
  IMPORTING program_name TYPE string.

METHODS zif_ave_object~check_exists
  RETURNING VALUE(exists) TYPE abap_bool.

METHODS zif_ave_object~get_name
  RETURNING VALUE(name) TYPE string.

METHODS zif_ave_object~get_parts
  RETURNING VALUE(parts) TYPE zif_ave_popup_types=>ty_t_part_row.
```

### check_exists() - Validation

Checks TRDIR table to verify the program exists:

```sql
SELECT * FROM trdir WHERE name = program_name.
```

### get_parts() - Parts Extraction

Returns a single part of type REPS (Repository Source):

```abap
APPEND INITIAL LINE TO parts ASSIGNING <p>.
<p>-part_type = 'REPS'.
<p>-part_name = program_name.
<p>-object_type = 'PROG'.
<p>-object_name = program_name.
```

## Usage

```abap
DATA(handler) = zcl_ave_object_factory=>get_instance(
  object_type = 'PROG'
  object_name = 'ZTEST_REPORT'
).

DATA(parts) = handler->get_parts().
" Returns: [{ type: REPS, name: ZTEST_REPORT }]
```

## Notes

- Does not distinguish between main programs and includes
- Single versionable unit (no sub-parts)
- Works with both standard and custom programs (Z*, Y* prefix)

## References

- [[architecture|Architecture]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[zif_ave_object]]
- [[zcl_ave_object_factory]]

---

**Last Updated**: 2026-05-17