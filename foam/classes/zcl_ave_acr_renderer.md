# zcl_ave_acr_renderer - Code Review HTML Renderer

## Business Description

Renders **interactive HTML for code review workflow**.

Takes diff operations, hunk information, and review state to generate HTML with:
- Approve/decline buttons
- Status badges (✓ Approved / ✗ Declined)
- Decline notes and discussion threads
- Comment links and actions

## Technical Description

### Classification
- **Type**: Renderer / HTML Generator
- **Scope**: Review UI rendering
- **Dependencies**: [[zcl_ave_acr_state]], [[zcl_ave_popup_html]]

### Main Public Methods

| Method | Purpose |
|--------|---------|
| `render_hunk_actions` | Generate HTML for approve/decline buttons |
| `render_decline_thread` | Render discussion thread for declined hunk |
| `render_status_badge` | Generate status indicator (✓/✗) |
| `render_comment_links` | Render action links (approve, decline, add note) |
| `render_hunk_action_meta` | Render metadata (reviewer, timestamp) |
| `inject_approve_buttons` | Inject approve UI into diff HTML |

### render_hunk_actions() - Action Buttons

```abap
METHODS render_hunk_actions
  IMPORTING
    hunk_key TYPE ty_hunk_key
    acr_state TYPE REF TO zcl_ave_acr_state
  RETURNING VALUE(html) TYPE string.
```

**Output**:
```html
<div class="hunk-actions">
  <a href="sapevent:approve_hunk?hunk_id=001">
    ✓ Approve
  </a>
  <a href="sapevent:decline_hunk?hunk_id=001">
    ✗ Decline
  </a>
  <a href="sapevent:add_note?hunk_id=001">
    💬 Add Note
  </a>
</div>
```

### render_decline_thread() - Discussion Thread

```abap
METHODS render_decline_thread
  IMPORTING
    hunk_key TYPE ty_hunk_key
    notes TYPE TABLE OF ty_decline_note
  RETURNING VALUE(html) TYPE string.
```

**Output**:
```html
<div class="decline-thread">
  <div class="note declined-by">
    <strong>USER2 (Reviewer)</strong>: "Need error handling"
    <time>2026-05-17 10:25</time>
  </div>
  <div class="note response-by">
    <strong>USER1 (Author)</strong>: "Fixed in v2"
    <time>2026-05-17 10:40</time>
  </div>
</div>
```

### render_status_badge() - Status Indicator

```abap
METHODS render_status_badge
  IMPORTING
    hunk_key TYPE ty_hunk_key
    acr_state TYPE REF TO zcl_ave_acr_state
  RETURNING VALUE(html) TYPE string.
```

**Output**:
```html
<span class="status APPROVED">
  ✓ Approved by REVIEWER1 on 2026-05-17 10:30
</span>

<!-- or -->

<span class="status DECLINED">
  ✗ Declined by REVIEWER1 on 2026-05-17 10:25
</span>

<!-- or -->

<span class="status UNKNOWN">
  ⏳ Pending review
</span>
```

### inject_approve_buttons() - HTML Integration

```abap
METHODS inject_approve_buttons
  IMPORTING
    html TYPE string
    diffs TYPE TABLE OF ty_diff_op
    acr_state TYPE REF TO zcl_ave_acr_state
  RETURNING VALUE(html_with_buttons) TYPE string.
```

**Process**:
1. Parse diff HTML
2. Identify hunk boundaries
3. Insert approve/decline buttons after each hunk
4. Add status badges
5. Return modified HTML

## HTML Structure

**Example Hunk with Review UI**:
```html
<div class="hunk" id="hunk_ZREPORT_REPS_001">
  <div class="hunk-header">
    <span class="hunk-id">Hunk #1</span>
    <span class="author">USER1</span>
    <span class="stats">+5 insertions, -2 deletions</span>
  </div>
  
  <div class="hunk-content">
    <table class="diff-table">
      <!-- Diff lines -->
    </table>
  </div>
  
  <div class="hunk-actions">
    <a href="sapevent:approve_hunk?hunk_id=...">✓ Approve</a>
    <a href="sapevent:decline_hunk?hunk_id=...">✗ Decline</a>
    <a href="sapevent:add_note?hunk_id=...">💬 Add Note</a>
  </div>
  
  <div class="hunk-status APPROVED">
    <span>✓ Approved by REVIEWER1 on 2026-05-17 10:30</span>
  </div>
  
  <div class="decline-thread">
    <!-- Discussion thread -->
  </div>
</div>
```

## SAP Events

Rendered links use `sapevent:` protocol for SAP GUI interaction:

```html
<a href="sapevent:approve_hunk?hunk_id=001&action=APPROVE">
```

Handled by [[zcl_ave_popup]] `on_sapevent()` method.

## Integration with Popup

```
zcl_ave_acr_renderer
     ↓
inject_approve_buttons(diff_html, acr_state)
     ↓
Enhanced HTML with review UI
     ↓
zcl_ave_popup->set_html()
     ↓
SAP GUI HTML Viewer displays with interactive buttons
```

## Notes

- All HTML is escaped for security
- CSS classes control styling (theme-independent)
- SAP GUI event handling is asynchronous
- Supports nested discussion threads

## References

- [[architecture|Architecture]]
- [[layers/code-review-layer|Code Review Layer]]
- [[zcl_ave_acr_state]]
- [[zcl_ave_popup_html]]
- [[zcl_ave_popup]]

---

**Last Updated**: 2026-05-17