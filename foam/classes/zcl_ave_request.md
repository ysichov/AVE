# zcl_ave_request - Transport Request Manager

## Business Description

Manages **Transport Request metadata** from SAP E070/E071 tables.

Reads TR information and locates the specific task (sub-request) responsible for a given object's version.

## Technical Description

### Classification
- **Type**: Data Access / Manager
- **Scope**: Single transport request
- **Dependencies**: E070, E071 tables

### Main Public Methods

| Method | Purpose |
|--------|---------|
| `constructor` | Load TR details |
| `populate_details` | Read TR text/status |
| `get_task_for_object` | Find task for object |
| `get_latest_task_for_object` | Find latest task with date filter |

### constructor() - Initialization

```abap
METHODS constructor
  IMPORTING trkorr TYPE trkorr.
```

**Process**:
1. Store TR ID
2. Call `populate_details()`
3. Load TR metadata from E070

### populate_details() - Load TR Metadata

Reads E070 and E07T:

```sql
SELECT * FROM e070 WHERE trkorr = transport_id.
SELECT * FROM e07t WHERE trkorr = transport_id AND langu = sy-langu.
```

**Fields**:
- `strkorr` — Main request
- `trstat` — Status (D=Draft, R=Released, C=Closed)
- `as4user` — Owner
- `as4date` — Date
- `as4time` — Time

### get_task_for_object() - Task Lookup

```abap
METHODS get_task_for_object
  IMPORTING
    object_type TYPE string
    object_name TYPE string
  RETURNING VALUE(task_id) TYPE trkorr.
```

**Logic**:
1. Normalize object type (e.g., PROG → R3TR/PROG)
2. Search E071 for matching object
3. Return task ID (main request or sub-task)

**Example**:
```abap
DATA(request) = NEW zcl_ave_request( trkorr = 'NPLK900123' ).

DATA(task) = request->get_task_for_object(
  object_type = 'PROG'
  object_name = 'ZTEST_REPORT'
).
" ↓ 'NPLK900124' (sub-task)
```

### get_latest_task_for_object() - Time-Constrained Lookup

```abap
METHODS get_latest_task_for_object
  IMPORTING
    object_type TYPE string
    object_name TYPE string
    version_date TYPE dats OPTIONAL
  RETURNING VALUE(task_id) TYPE trkorr.
```

**Logic**:
1. Find task for object
2. If `version_date` provided, verify task date <= version date
3. Return latest matching task

**Purpose**: When version is from specific date, find the TR/task responsible for that version

**Example**:
```abap
" Version 5 was created on 2026-05-10
DATA(task) = request->get_latest_task_for_object(
  object_type = 'PROG'
  object_name = 'ZTEST_REPORT'
  version_date = '20260510'
).
" Returns TR/task that modified object on or before 2026-05-10
```

## E070/E071 Tables

### E070 - Transport Request Header

| Field | Description |
|-------|-------------|
| `trkorr` | Transport request ID |
| `strkorr` | Main request (if sub-task) |
| `trstat` | Status (D, R, C, etc.) |
| `as4user` | User |
| `as4date` | Creation date |

### E071 - Transport Request Objects

| Field | Description |
|-------|-------------|
| `trkorr` | Transport request ID |
| `pgmid` | Program ID (R3TR, LIMU, etc.) |
| `object` | Object type (PROG, CLAS, FUNC) |
| `obj_name` | Object name |
| `as4date` | Release date |

## Usage in AVE

```abap
DATA(version) = NEW zcl_ave_version( vrsd_row = row ).

" Find responsible TR for this version
DATA(request) = NEW zcl_ave_request( trkorr = row-trkorr ).

DATA(task_id) = request->get_latest_task_for_object(
  object_type = row-object_type
  object_name = row-object_name
  version_date = row-created
).

" Load task information
version->mv_task_id = task_id.
```

## Notes

- **Sub-tasks**: TR can have main request + sub-tasks
- **Date filtering**: Optional version date for time-constrained lookup
- **Normalization**: Object types normalized to SAP format

## References

- [[architecture|Architecture]]
- [[layers/version-layer|Version Layer]]
- [[zcl_ave_version]]
- [[zcl_ave_popup]]

---

**Last Updated**: 2026-05-17