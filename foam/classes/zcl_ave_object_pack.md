# zcl_ave_object_pack - Package Handler

## Business Description

Handles **Development Packages** (DEVC objects).

Development packages are containers for ABAP objects. This handler extracts all contained objects from TADIR and expands them into versionable parts.

## Technical Description

### Classification
- **Type**: Object Handler / Aggregator
- **Implements**: [[zif_ave_object]]
- **Scope**: Single package
- **Dependencies**: TDEVC table, TADIR table

### Main Methods

```abap
METHODS constructor
  IMPORTING package_name TYPE string.

METHODS zif_ave_object~check_exists
  RETURNING VALUE(exists) TYPE abap_bool.

METHODS zif_ave_object~get_name
  RETURNING VALUE(name) TYPE string.

METHODS zif_ave_object~get_parts
  RETURNING VALUE(parts) TYPE zif_ave_popup_types=>ty_t_part_row.

METHODS get_object_keys
  RETURNING VALUE(keys) TYPE TABLE OF ty_object_key.

METHODS get_object
  IMPORTING key TYPE ty_object_key
  RETURNING VALUE(handler) TYPE REF TO zif_ave_object.
```

### check_exists() - Validation

Checks TDEVC table:

```sql
SELECT * FROM tdevc WHERE devclass = package_name.
```

### get_parts() - Parts Extraction

**Process**:
1. Read TADIR for all objects in package
2. For each object type, create appropriate handler
3. Extract parts from handler
4. **Filter**: Skip unsupported types (keep as visible rows)
5. Return aggregated parts

**Example**:

```
Package Z_MYAPP contains:
  ├─ PROG Z_REPORT1
  ├─ CLAS ZCL_SERVICE
  ├─ FUNC Z_HELPER
  └─ TABLE ZTEST_DATA (unsupported)

get_parts() returns:
  ├─ REPS Z_REPORT1
  ├─ REPS ZCL_SERVICE (definitions)
  ├─ REPS ZCL_SERVICE (implementation)
  ├─ METH ZCL_SERVICE~PROCESS
  ├─ FUNC Z_HELPER
  └─ [UNSUPPORTED] TABLE ZTEST_DATA
```

## Usage

```abap
DATA(handler) = zcl_ave_object_factory=>get_instance(
  object_type = 'DEVC'
  object_name = 'Z_MYAPP'
).

DATA(parts) = handler->get_parts().
" Returns all versioned objects from package
```

## Features

- **TADIR-based**: Reads all objects assigned to package
- **Auto-expansion**: Classes automatically expand to methods
- **Unsupported visibility**: Shows unsupported types as informational rows
- **Package context**: Preserves package association

## Notes

- Package is a collection, not a single versionable object
- Only assigned objects (TADIR ownership) are included
- Sub-packages not automatically expanded

## References

- [[architecture|Architecture]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[zif_ave_object]]
- [[zcl_ave_object_factory]]

---

**Last Updated**: 2026-05-17