# zcl_ave_object_ddls - CDS DDL Source Handler

## Business Description

Handles **CDS DDL Sources** (DDLS objects).

CDS (Core Data Services) DDL sources are special ABAP objects used for data modeling. This handler extracts a single DDLS part for versioning.

## Technical Description

### Classification
- **Type**: Object Handler
- **Implements**: [[zif_ave_object]]
- **Scope**: Single CDS DDL source
- **Dependencies**: TADIR table, TLOGO tables (CDS metadata)

### Main Methods

```abap
METHODS constructor
  IMPORTING ddls_name TYPE string.

METHODS zif_ave_object~check_exists
  RETURNING VALUE(exists) TYPE abap_bool.

METHODS zif_ave_object~get_name
  RETURNING VALUE(name) TYPE string.

METHODS zif_ave_object~get_parts
  RETURNING VALUE(parts) TYPE zif_ave_popup_types=>ty_t_part_row.
```

### check_exists() - Validation

Checks TADIR for active DDLS entry:

```sql
SELECT * FROM tadir 
  WHERE pgmid = 'R3TR'
    AND object = 'DDLS'
    AND obj_name = ddls_name.
```

### get_parts() - Parts Extraction

Returns a single DDLS part:

```abap
APPEND INITIAL LINE TO parts ASSIGNING <p>.
<p>-part_type = 'DDLS'.
<p>-part_name = ddls_name.
<p>-object_type = 'DDLS'.
<p>-object_name = ddls_name.
```

## Usage

```abap
DATA(handler) = zcl_ave_object_factory=>get_instance(
  object_type = 'DDLS'
  object_name = 'ZC_ARTICLES'
).

DATA(parts) = handler->get_parts().
" Returns: [{ type: DDLS, name: ZC_ARTICLES }]
```

## Features

- Source loading uses specialized TLOGO controller
- Supports all CDS DDL syntax (DEFINE VIEW, PROJECTION, ASSOCIATION, etc.)
- Part of modern ABAP development (S/4HANA)

## Notes

- Requires TADIR access
- Source code is stored in TLOGO tables, not VRSD
- CDS objects support extended data model features

## References

- [[architecture|Architecture]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[zif_ave_object]]
- [[zcl_ave_object_factory]]

---

**Last Updated**: 2026-05-17