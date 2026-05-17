# zcl_ave_popup_data - Popup Helper Utilities

## Business Description

Collection of **static utility methods** used throughout AVE for:
- User name resolution (display names)
- Object type caching
- Part existence checking
- Line count calculation
- Version filtering and deduplication

This class reduces duplication in the main popup controller.

## Technical Description

### Classification
- **Type**: Utility / Helper
- **Scope**: Global (used in popup, diff, HTML rendering)
- **Dependencies**: [[zcl_ave_author]], [[zcl_ave_vrsd]], TADIR, SEOCOMPO

### Main Public Methods

| Method | Purpose |
|--------|---------|
| `get_user_name` | Resolve user ID to display name |
| `get_latest_author` | Get author of newest VRSD entry |
| `check_part_exists` | Verify part exists in system |
| `get_type_text` | Cached SAP object type text |
| `get_active_line_count` | Count lines in active source |
| `get_ver_source` | Load version source |
| `build_versions_for_check` | Build version list with TR metadata |
| `remove_duplicate_versions` | Deduplicate identical sources |
| `is_substantive_user_change` | Compare version against baseline |

### get_user_name() - User Resolution

```abap
CLASS-METHODS get_user_name
  IMPORTING user TYPE string
  RETURNING VALUE(display_name) TYPE string.
```

Delegates to [[zcl_ave_author]]:

```abap
display_name = zcl_ave_author=>get_name( user ).
```

### check_part_exists() - Part Validation

```abap
CLASS-METHODS check_part_exists
  IMPORTING
    part_type TYPE string    " REPS, METH, FUNC, DDLS
    part_name TYPE string
    object_type TYPE string
    object_name TYPE string
  RETURNING VALUE(exists) TYPE abap_bool.
```

**Logic**:
- For REPS: Check TRDIR (programs)
- For METH: Check SEOCOMPO (class methods)
- For FUNC: Check TFDIR
- For DDLS: Check TADIR

### get_type_text() - Object Type Caching

```abap
CLASS-METHODS get_type_text
  IMPORTING type TYPE string
  RETURNING VALUE(text) TYPE string.
```

**Caching**:
- Calls TRINT_OBJECT_TABLE once
- Caches results in class-level table
- Avoids repeated API calls

**Example**:
```
get_type_text( 'PROG' ) → "Program"
get_type_text( 'CLAS' ) → "Class"
get_type_text( 'FUNC' ) → "Function Module"
```

### get_active_line_count() - Line Counting

```abap
CLASS-METHODS get_active_line_count
  IMPORTING
    object_type TYPE string
    object_name TYPE string
  RETURNING VALUE(line_count) TYPE int4.
```

Loads active source and counts lines:

```abap
DATA(source) = ... " Load active source
line_count = LINES( source ).
```

### build_versions_for_check() - Version Building

```abap
CLASS-METHODS build_versions_for_check
  IMPORTING
    vrsd TYPE zif_ave_popup_types=>ty_t_version_row
    object_type TYPE string
    object_name TYPE string
  RETURNING VALUE(versions) TYPE zif_ave_popup_types=>ty_t_version_row.
```

**Processing**:
- Enrich versions with TR metadata
- Add transport function information
- Sort newest first
- Return enriched list

### remove_duplicate_versions() - Deduplication

```abap
CLASS-METHODS remove_duplicate_versions
  IMPORTING
    versions TYPE zif_ave_popup_types=>ty_t_version_row
  RETURNING VALUE(unique_versions) TYPE zif_ave_popup_types=>ty_t_version_row.
```

**Logic**:
- Compare consecutive versions' source code
- Remove versions with identical source
- Preserve important baselines (first, last, transport boundaries)

**Purpose**: Reduce clutter when multiple versions have same content

### is_substantive_user_change() - Change Detection

```abap
CLASS-METHODS is_substantive_user_change
  IMPORTING
    target_version TYPE zif_ave_popup_types=>ty_version_row
    baseline_version TYPE zif_ave_popup_types=>ty_version_row
  RETURNING VALUE(is_change) TYPE abap_bool.
```

Compares two versions for meaningful changes (not just whitespace).

## Usage in AVE

```abap
" In zcl_ave_popup:
DATA(author_name) = zcl_ave_popup_data=>get_user_name( 'USER1' ).

DATA(exists) = zcl_ave_popup_data=>check_part_exists(
  part_type = 'METH'
  part_name = 'ZCL_MANAGER~PROCESS'
  object_type = 'CLAS'
  object_name = 'ZCL_MANAGER'
).

DATA(type_text) = zcl_ave_popup_data=>get_type_text( 'PROG' ).

DATA(versions) = zcl_ave_popup_data=>build_versions_for_check(
  vrsd = mt_vrsd_versions
  object_type = 'REPS'
  object_name = 'ZTEST'
).
```

## Performance Considerations

- **Caching**: Type text is cached globally
- **Lazy loading**: Source code only loaded on demand
- **Deduplication**: Reduces memory for large version lists

## Notes

- All methods are CLASS-METHODS (static)
- No instance state
- Designed for utility/helper role
- Reduces coupling in main popup

## References

- [[architecture|Architecture]]
- [[zcl_ave_popup]]
- [[zcl_ave_author]]
- [[zcl_ave_popup_diff]]

---

**Last Updated**: 2026-05-17