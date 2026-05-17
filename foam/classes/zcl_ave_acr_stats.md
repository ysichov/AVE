# zcl_ave_acr_stats - Code Review Statistics Calculator

## Business Description

Computes **review statistics** from diff operations:
- Line insertion/deletion counts
- Modification counts
- Per-author breakdown
- Hunk statistics
- Blank line change detection

Used to generate summary metrics for code review reports.

## Technical Description

### Classification
- **Type**: Calculation / Analytics
- **Scope**: Diff analysis
- **Dependencies**: [[zcl_ave_popup_diff]]

### Main Public Methods

| Method | Purpose |
|--------|---------|
| `from_diff` | Calculate stats from diff operations |
| `is_blank_hunk` | Detect whitespace-only changes |
| `get_stats` | Return calculated statistics |

### from_diff() - Calculate Statistics

```abap
METHODS from_diff
  IMPORTING
    diffs TYPE TABLE OF zif_ave_popup_types=>ty_diff_op
    blame_map TYPE TABLE OF zif_ave_popup_types=>ty_blame_entry
  RETURNING VALUE(stats) TYPE ty_diff_stats.
```

**Output Structure**:

```abap
TYPES BEGIN OF ty_diff_stats.
  insertions TYPE int4.              " +N lines
  deletions TYPE int4.               " -N lines
  modifications TYPE int4.           " ~N lines changed
  hunk_count TYPE int4.              " Number of hunks
  blank_line_changes TYPE int4.      " Whitespace-only changes
  by_author TYPE TABLE OF ty_author_stats.  " Per-author breakdown
TYPES END OF ty_diff_stats.

TYPES BEGIN OF ty_author_stats.
  author TYPE string.
  insertions TYPE int4.
  deletions TYPE int4.
  modifications TYPE int4.
  hunk_count TYPE int4.
TYPES END OF ty_author_stats.
```

### Calculation Logic

**Insertions** (INSERT operations):
```
+1 for each INSERT operation
```

**Deletions** (DELETE operations):
```
+1 for each DELETE operation
```

**Modifications** (REPLACE operations):
```
+1 for each REPLACE operation
```

**Hunks** (groups of consecutive changes):
```
Count distinct hunk boundaries
(KEEP after changes = new hunk)
```

**Per-Author Breakdown**:
```
For each operation, lookup author in blame_map
Aggregate insertions/deletions/modifications per author
```

**Blank Line Changes**:
```
Count operations where line content is whitespace-only
(Detected by is_blank_hunk method)
```

### is_blank_hunk() - Whitespace Detection

```abap
METHODS is_blank_hunk
  IMPORTING
    line_content TYPE string
  RETURNING VALUE(is_blank) TYPE abap_bool.
```

**Logic**:
1. Check if line is empty or contains only spaces/tabs
2. Return TRUE if whitespace-only
3. Return FALSE if has meaningful content

**Purpose**: Distinguish whitespace formatting changes from code changes

### Example Usage

```abap
DATA(stats) = zcl_ave_acr_stats=>from_diff(
  diffs = mt_diff_ops
  blame_map = mt_blame_map
).

WRITE: / 'Insertions:', stats-insertions.
WRITE: / 'Deletions:', stats-deletions.
WRITE: / 'Modifications:', stats-modifications.
WRITE: / 'Hunks:', stats-hunk_count.
WRITE: / 'Blank changes:', stats-blank_line_changes.

LOOP AT stats-by_author INTO DATA(author_stats).
  WRITE: / author_stats-author,
           '+', author_stats-insertions,
           '-', author_stats-deletions.
ENDLOOP.
```

## Statistics Application

**Used for**:
1. **Review Report** — summary statistics
2. **Per-author attribution** — who made what changes
3. **Impact assessment** — how much code changed
4. **Quality metrics** — whitespace vs meaningful changes

## Example Output

```
Version A → Version B Statistics:

Total Changes:
  +15 insertions
  -8 deletions
  ~3 modifications
  5 hunks
  2 blank-line-only changes

By Author:
  USER1:
    +10 insertions
    -3 deletions
    ~1 modifications
  USER2:
    +5 insertions
    -5 deletions
    ~2 modifications
```

## Notes

- **No DB dependency**: Pure calculation
- **Blame-aware**: Uses blame map for author attribution
- **Flexible**: Can work with partial blame maps

## References

- [[architecture|Architecture]]
- [[layers/code-review-layer|Code Review Layer]]
- [[zcl_ave_popup_diff]]
- [[zcl_ave_acr_report]]

---

**Last Updated**: 2026-05-17