# zcl_ave_version2 - Alternative Version Loader

## Business Description

Alternative **source code loader** for versions using SVRS_GET_VERSION_LOCAL/REMOTE APIs.

Provides flexibility for systems with different SVRS configurations or remote system access.

## Technical Description

### Classification
- **Type**: Data Access / Version Loader
- **Scope**: Single version source
- **Dependencies**: SVRS APIs

### Main Public Methods

| Method | Purpose |
|--------|---------|
| `constructor` | Initialize with version parameters |
| `get_source_local` | Load from local active/modified/historical version |
| `get_source_remote` | Load from remote TMS system |
| `build_object` | Create SVRS versionable object |

### constructor() - Initialization

```abap
METHODS constructor
  IMPORTING
    object_type TYPE string    " REPS, FUNC, DDLS
    object_name TYPE string
    version_number TYPE int4.  " 1, 2, 3, ..., 0=active
```

### get_source_local() - Local Source Loading

```abap
METHODS get_source_local
  RETURNING VALUE(source_lines) TYPE abap_source_table.
```

**Process**:
1. Build SVRS versionable object
2. Call SVRS_GET_VERSION_LOCAL
3. Extract source lines
4. Return table

**Modes**:
- `version_number = 0` → Active version
- `version_number = 99997` → Modified version
- `version_number > 0` → Historical version

**Example**:
```abap
DATA(loader) = NEW zcl_ave_version2(
  object_type = 'REPS'
  object_name = 'ZTEST'
  version_number = 5
).

DATA(source) = loader->get_source_local().
" Returns source lines for version 5
```

### get_source_remote() - Remote System Loading

```abap
METHODS get_source_remote
  IMPORTING remote_system TYPE string
  RETURNING VALUE(source_lines) TYPE abap_source_table.
```

**Process**:
1. Build SVRS object for remote system
2. Call SVRS_GET_VERSION_REMOTE
3. Extract source from remote
4. Return lines

**Purpose**: Compare with objects from other SAP systems (Sandbox, QA, Prod)

**Example**:
```abap
DATA(remote_source) = loader->get_source_remote(
  remote_system = 'PRD'
).
" Fetch version from production system
```

### build_object() - SVRS Object Construction

```abap
METHODS build_object
  RETURNING VALUE(object) TYPE svrs2_versionable_object.
```

Creates SVRS-compatible object structure for API calls.

## SVRS APIs

### SVRS_GET_VERSION_LOCAL

Retrieves source for local system version.

**Input**:
- `sv2_object` — Versionable object structure
- `sv2_version` — Version number

**Output**:
- `sv2_source` — Source table

### SVRS_GET_VERSION_REMOTE

Retrieves source from remote system via TMS.

**Input**:
- `sv2_object` — Versionable object structure
- `sv2_version` — Version number
- `remote_system` — Remote system ID

**Output**:
- `sv2_source` — Remote source lines

## Comparison: zcl_ave_version vs zcl_ave_version2

| Aspect | zcl_ave_version | zcl_ave_version2 |
|--------|-----------------|------------------|
| VRSD dependency | Yes | Minimal |
| Local only | Yes | No (supports remote) |
| Complexity | Medium | Higher |
| When to use | Standard case | Remote systems, special configs |

## Usage

```abap
" Preferred: zcl_ave_version (standard VRSD)
DATA(v1) = NEW zcl_ave_version( vrsd_row = row ).
DATA(src1) = v1->get_source().

" Alternative: zcl_ave_version2 (when v1 doesn't work)
DATA(v2) = NEW zcl_ave_version2(
  object_type = row-object
  object_name = row-obj_name
  version_number = row-versno
).
DATA(src2) = v2->get_source_local().

" Remote: zcl_ave_version2 with remote system
DATA(src3) = v2->get_source_remote( remote_system = 'QA' ).
```

## Notes

- **Fallback**: Use when zcl_ave_version fails
- **Remote access**: Requires TMS connection
- **Performance**: Remote calls can be slower
- **Error handling**: SVRS APIs may raise exceptions

## References

- [[architecture|Architecture]]
- [[layers/version-layer|Version Layer]]
- [[zcl_ave_version]]
- [[zcl_ave_vrsd]]

---

**Last Updated**: 2026-05-17