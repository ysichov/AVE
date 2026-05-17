# zcl_ave_acr_repository - Code Review Persistence

## Business Description

Manages **database persistence** of code review state.

Saves and loads review data from ZAVE_REVIEW table, serializing/deserializing the review state including approvals, declines, and notes.

## Technical Description

### Classification
- **Type**: Data Access / Repository
- **Scope**: Per-Transport review data
- **Dependencies**: ZAVE_REVIEW table, [[zcl_ave_acr_state]]

### Main Public Methods

| Method | Purpose |
|--------|---------|
| `load_review` | Load persisted review state from DB |
| `save_review` | Save review state to DB |
| `clear_review` | Delete review state from DB |
| `check_review_exists` | Verify review data exists |

### ZAVE_REVIEW Table Structure

**Purpose**: Store code review state persistence.

| Field | Type | Description |
|-------|------|-------------|
| `trkorr` | TRKORR (11) | Transport request ID (Primary Key) |
| `part_name` | STRING | Object/part name |
| `part_type` | CHAR(4) | REPS, METH, FUNC, DDLS |
| `hunk_id` | STRING | Unique hunk identifier |
| `status` | CHAR(10) | APPROVED, DECLINED, UNKNOWN |
| `reviewer` | CHAR(12) | User who approved/declined |
| `timestamp` | TIMESTAMP | Action timestamp |
| `notes` | STRING | Decline comments/thread |
| `payload` | STRING (JSON) | Full serialized review state |

### load_review() - Load from DB

```abap
METHODS load_review
  IMPORTING
    trkorr TYPE trkorr
  RETURNING VALUE(acr_state) TYPE REF TO zcl_ave_acr_state
  RAISING zcx_ave.
```

**Process**:
1. Query ZAVE_REVIEW for transport
2. Deserialize JSON payload
3. Reconstruct [[zcl_ave_acr_state]] from payload
4. Return state object

**Example**:
```abap
TRY.
  DATA(acr_state) = acr_repository->load_review(
    trkorr = 'NPLK900123'
  ).
  " acr_state now contains all approvals/declines
CATCH zcx_ave.
  " No review exists yet, start fresh
ENDTRY.
```

### save_review() - Save to DB

```abap
METHODS save_review
  IMPORTING
    trkorr TYPE trkorr
    acr_state TYPE REF TO zcl_ave_acr_state
  RAISING zcx_ave.
```

**Process**:
1. Serialize acr_state to JSON
2. Update/insert ZAVE_REVIEW rows
3. Commit transaction
4. Raise exception on error

**Example**:
```abap
acr_repository->save_review(
  trkorr = 'NPLK900123'
  acr_state = acr_state
).
```

### clear_review() - Delete Review Data

```abap
METHODS clear_review
  IMPORTING trkorr TYPE trkorr
  RAISING zcx_ave.
```

Deletes all review data for a transport:

```sql
DELETE FROM zave_review WHERE trkorr = transport_id.
```

### check_review_exists() - Existence Check

```abap
METHODS check_review_exists
  IMPORTING trkorr TYPE trkorr
  RETURNING VALUE(exists) TYPE abap_bool.
```

Checks if review data exists for transport:

```sql
SELECT SINGLE trkorr FROM zave_review
  WHERE trkorr = transport_id.
```

## Serialization Format

**Storage**:
- Individual hunk states in rows
- Full payload JSON in `payload` field

**JSON Structure**:
```json
{
  "transport_id": "NPLK900123",
  "reviewed_at": "2026-05-17 14:30:00",
  "hunks": [
    {
      "part_name": "ZREPORT",
      "part_type": "REPS",
      "hunk_id": "001",
      "status": "APPROVED",
      "reviewer": "USER2",
      "timestamp": "2026-05-17 10:30:00",
      "notes": ""
    },
    {
      "part_name": "ZCL_MANAGER",
      "part_type": "METH",
      "hunk_id": "002",
      "status": "DECLINED",
      "reviewer": "USER2",
      "timestamp": "2026-05-17 10:25:00",
      "notes": "Missing error handling"
    }
  ]
}
```

## Workflow

```
1. User performs code review
   ├─ set_hunk_action() in acr_state
   ├─ Add notes to hunks
   ↓
2. User clicks "Save Review"
   ├─ acr_repository->save_review()
   ├─ Serialize state to JSON
   └─ INSERT/UPDATE ZAVE_REVIEW
   ↓
3. Later: User reopens transport
   ├─ acr_repository->load_review()
   ├─ Deserialize from DB
   └─ Restore state
   ↓
4. User can continue reviewing from where they left
```

## Notes

- **Table creation**: ZAVE_REVIEW must exist (custom Z* table)
- **Transaction handling**: Commit/rollback managed by repository
- **Serialization**: Uses JSON for flexibility
- **Backward compatibility**: Payload format can evolve

## References

- [[architecture|Architecture]]
- [[layers/code-review-layer|Code Review Layer]]
- [[zcl_ave_acr_state]]
- [[zcl_ave_popup]]

---

**Last Updated**: 2026-05-17