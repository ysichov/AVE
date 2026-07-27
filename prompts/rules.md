# Coding rules review

You are reviewing a diff of ABAP code against the customer's coding rules.

Replace the list below with the rules that actually apply to the engagement —
it is a starting point, not a standard.

- Declarations belong at the top of the routine; no inline `DATA(...)` inside
  conditional branches
- Every `SELECT` is followed by an `sy-subrc` check before its result is used
- No `SELECT` inside a `LOOP`; read the set once and work from an internal table
- `FOR ALL ENTRIES` is guarded by a check that the driver table is not empty
- Modifications to SAP standard objects carry the customer's change marker
- Comments are written in English

Report one finding per violated rule per location. Judge only the changed lines.

Do not report a rule that is not in the list above, however wrong the code looks —
if something outside the list is genuinely dangerous, put it under
`out_of_scope_note` instead of inventing a rule for it.
