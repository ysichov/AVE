# zcl_ave_object_tr - Transport Request Handler

## Business Description

Handles **Transport Requests and Tasks** (TR objects).

Transport requests (e.g., "NPLK900123") contain multiple objects. This handler extracts all contained objects and expands them into versionable parts, with special handling for nested objects.

## Technical Description

### Classification
- **Type**: Object Handler / Aggregator
- **Implements**: [[zif_ave_object]]
- **Scope**: Single transport request
- **Dependencies**: E070, E071 tables (SAP transport tables), TRINT API

### Main Methods

```abap
METHODS constructor
  IMPORTING trkorr TYPE string.  " Transport ID

METHODS zif_ave_object~check_exists
  RETURNING VALUE(exists) TYPE abap_bool.

METHODS zif_ave_object~get_name
  RETURNING VALUE(name) TYPE string.

METHODS zif_ave_object~get_parts
  RETURNING VALUE(parts) TYPE zif_ave_popup_types=>ty_t_part_row.

METHODS get_object_keys
  RETURNING VALUE(keys) TYPE TABLE OF ty_object_key.

METHODS get_objects_for_keys
  IMPORTING keys TYPE TABLE OF ty_object_key
  RETURNING VALUE(handlers) TYPE TABLE OF REF TO zif_ave_object.
```

### check_exists() - Validation

Validates transport in E070:

```sql
SELECT * FROM e070 WHERE trkorr = transport_id.
```

### get_parts() - Parts Extraction

**Process**:
1. Read E071 (transport contents)
2. For each object, create appropriate handler
3. Extract parts from handler
4. **Special handling for classes**: Drill-in to individual methods
5. Return aggregated parts list

**Example**:

```
Transport NPLK900123 contains:
  ├─ PROG Z_REPORT
  ├─ CLAS ZCL_MANAGER
  └─ FUNC Z_PROCESS

get_parts() returns:
  ├─ REPS Z_REPORT
  ├─ REPS ZCL_MANAGER (definitions)
  ├─ REPS ZCL_MANAGER (implementation)
  ├─ METH ZCL_MANAGER~GET_DATA
  ├─ METH ZCL_MANAGER~PROCESS
  └─ FUNC Z_PROCESS
```

### get_object_keys() - Extract Object Keys

Reads E071 and deduplicates object keys:

```abap
SELECT DISTINCT pgmid, object, obj_name FROM e071
  WHERE trkorr = transport_id.
```

## Usage

```abap
DATA(handler) = zcl_ave_object_factory=>get_instance(
  object_type = 'TR'
  object_name = 'NPLK900123'
).

DATA(parts) = handler->get_parts().
" Returns expanded parts from all TR objects
```

## Features

- **Auto-drill**: Classes automatically expand to methods
- **Deduplication**: Same object appearing in multiple tasks
- **Object validation**: Skip unsupported object types
- **Transport metadata**: Includes task information

## Notes

- TR is a collection, not a single versionable object
- Nested parts inherit transport context
- Can handle both main requests and sub-tasks

## References

- [[architecture|Architecture]]
- [[layers/object-handler-layer|Object Handler Layer]]
- [[zif_ave_object]]
- [[zcl_ave_object_factory]]
- [[zcl_ave_request]]

---

**Last Updated**: 2026-05-17