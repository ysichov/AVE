CLASS zcl_ave_acr_renderer DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS render_decline_thread_html
      IMPORTING
        iv_hunk_key      TYPE string
        it_hunk_threads  TYPE zif_ave_acr_types=>ty_t_hunk_threads
        it_decline_notes TYPE zif_ave_acr_types=>ty_t_decline_notes
        it_declined      TYPE zif_ave_acr_types=>ty_approved
      RETURNING
        VALUE(result)    TYPE string.

    CLASS-METHODS render_hunk_actions_html
      IMPORTING
        iv_hunk_key      TYPE string
        it_approved      TYPE zif_ave_acr_types=>ty_approved
        it_declined      TYPE zif_ave_acr_types=>ty_approved
        it_hunk_actions  TYPE zif_ave_acr_types=>ty_t_hunk_actions
        it_hunk_info     TYPE zif_ave_acr_types=>ty_t_hunk_info
        it_hunk_threads  TYPE zif_ave_acr_types=>ty_t_hunk_threads
        iv_ai_enabled    TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result)    TYPE string.

    CLASS-METHODS render_comment_links
      IMPORTING
        iv_hunk_key      TYPE string
        it_hunk_threads  TYPE zif_ave_acr_types=>ty_t_hunk_threads
        iv_ai_enabled    TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result)    TYPE string.

    CLASS-METHODS render_hunk_action_meta
      IMPORTING
        iv_hunk_key      TYPE string
        iv_action        TYPE zif_ave_acr_types=>ty_action_code
        it_hunk_actions  TYPE zif_ave_acr_types=>ty_t_hunk_actions
      RETURNING
        VALUE(result)    TYPE string.

    CLASS-METHODS build_review_help_html
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS add_report_toolbar
      IMPORTING
        iv_html       TYPE string
        iv_enabled    TYPE abap_bool
      RETURNING
        VALUE(result) TYPE string.
protected section.
private section.
ENDCLASS.



CLASS ZCL_AVE_ACR_RENDERER IMPLEMENTATION.


  METHOD render_decline_thread_html.
    DATA(lv_comment_anchor) = |ai_comment_{ iv_hunk_key }|.
    REPLACE ALL OCCURRENCES OF '/' IN lv_comment_anchor WITH '_'.
    REPLACE ALL OCCURRENCES OF '~' IN lv_comment_anchor WITH '_'.
    REPLACE ALL OCCURRENCES OF ' ' IN lv_comment_anchor WITH '_'.

    READ TABLE it_hunk_threads INTO DATA(ls_thread)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    IF sy-subrc <> 0.
      READ TABLE it_decline_notes INTO DATA(ls_note)
        WITH TABLE KEY hunk_key = iv_hunk_key.
      IF sy-subrc = 0 AND ls_note-note IS NOT INITIAL.
        DATA(lv_note_esc) = ls_note-note.
        REPLACE ALL OCCURRENCES OF `&` IN lv_note_esc WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_note_esc WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_note_esc WITH `&gt;`.
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_note_esc WITH `<br>`.
        DATA(lv_note_bg) = COND string(
          WHEN line_exists( it_declined[ table_line = iv_hunk_key ] ) THEN `#fff1f4`
          ELSE `#f3f9ff` ).
        DATA(lv_note_border) = COND string(
          WHEN line_exists( it_declined[ table_line = iv_hunk_key ] ) THEN `#efb8c8`
          ELSE `#a8cde8` ).
        DATA(lv_note_text) = COND string(
          WHEN line_exists( it_declined[ table_line = iv_hunk_key ] ) THEN `#9f3b57`
          ELSE `#2874a6` ).
        result =
          |<tr id="{ lv_comment_anchor }"><td class="ln">&nbsp;</td><td class="cd" style="padding:6px 12px">| &&
          `<div style="display:inline-block;background:` && lv_note_bg &&
          `;border:1px solid ` && lv_note_border &&
          `;padding:5px 9px;color:` && lv_note_text &&
          `;font-size:11px;line-height:15px;font-style:italic;border-radius:6px">` &&
          lv_note_esc && `</div></td></tr>`.
      ENDIF.
      RETURN.
    ENDIF.

    DATA lv_msg_idx TYPE i.
    LOOP AT ls_thread-messages INTO DATA(ls_msg).
      lv_msg_idx += 1.
      DATA(lv_row_id) = COND string(
        WHEN lv_msg_idx = lines( ls_thread-messages ) AND lv_comment_anchor IS NOT INITIAL
        THEN | id="{ lv_comment_anchor }"|
        ELSE `` ).
      DATA(lv_author_esc) = escape( val = CONV string( ls_msg-author ) format = cl_abap_format=>e_html_text ).
      DATA(lv_author_name_esc) = escape( val = CONV string( ls_msg-author_name ) format = cl_abap_format=>e_html_text ).
      DATA(lv_created_at_txt) = zcl_ave_acr_state=>format_timestamp( ls_msg-created_at ).
      DATA(lv_text_esc) = escape( val = ls_msg-text format = cl_abap_format=>e_html_text ).
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_text_esc WITH `<br>`.
      DATA(lv_note_bg_msg) = COND string(
        WHEN ls_msg-is_decline = abap_true THEN `#fff1f4`
        ELSE `#f3f9ff` ).
      DATA(lv_note_border_msg) = COND string(
        WHEN ls_msg-is_decline = abap_true THEN `#efb8c8`
        ELSE `#a8cde8` ).
      DATA(lv_note_text_msg) = COND string(
        WHEN ls_msg-is_decline = abap_true THEN `#9f3b57`
        ELSE `#2874a6` ).
      result = result &&
        `<tr` && lv_row_id && `><td class="ln">&nbsp;</td><td class="cd" style="padding:6px 12px">` &&
        `<div style="display:inline-block;margin:0 0 6px 0;background:` && lv_note_bg_msg &&
        `;border:1px solid ` && lv_note_border_msg && `;padding:6px 9px;max-width:900px;border-radius:6px">` &&
        `<div style="font-size:10px;color:#6f7f8f;font-weight:bold;margin-bottom:3px">` &&
        lv_author_esc && ` / ` && lv_author_name_esc &&
        ` <span style="font-weight:normal;color:#8a96a3">/ ` &&
        escape( val = lv_created_at_txt format = cl_abap_format=>e_html_text ) &&
        `</span></div>` &&
        `<div style="font-size:11px;line-height:15px;color:` && lv_note_text_msg &&
        `;font-style:italic">` &&
        lv_text_esc && `</div></div></td></tr>`.
    ENDLOOP.
  ENDMETHOD.


  METHOD render_hunk_actions_html.
    DATA(lv_status_html) = ``.
    DATA(lv_actions_html) = ``.
    DATA(lv_own_hunk) = zcl_ave_acr_state=>is_own_hunk(
      iv_hunk_key  = iv_hunk_key
      it_hunk_info = it_hunk_info ).
    DATA(lv_global_action) = zcl_ave_acr_state=>get_hunk_global_action(
      iv_hunk_key     = iv_hunk_key
      it_hunk_actions = it_hunk_actions ).

    IF line_exists( it_approved[ table_line = iv_hunk_key ] ).
      lv_status_html =
        `<span style="color:#27ae60;font-weight:bold">&#10003; approved</span>` &&
        render_hunk_action_meta(
          iv_hunk_key     = iv_hunk_key
          iv_action       = 'A'
          it_hunk_actions = it_hunk_actions ).
      IF lv_own_hunk = abap_true.
        lv_actions_html = render_comment_links(
          iv_hunk_key     = iv_hunk_key
          it_hunk_threads = it_hunk_threads
          iv_ai_enabled   = iv_ai_enabled ).
      ELSE.
        lv_actions_html =
          |<a href="sapevent:undo~{ iv_hunk_key }"| &&
          ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
          `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Undo</a>` &&
          render_comment_links(
            iv_hunk_key     = iv_hunk_key
            it_hunk_threads = it_hunk_threads
            iv_ai_enabled   = iv_ai_enabled ).
      ENDIF.
    ELSEIF line_exists( it_declined[ table_line = iv_hunk_key ] ).
      lv_status_html =
        `<span style="color:#e74c3c;font-weight:bold">&#10007; declined</span>` &&
        render_hunk_action_meta(
          iv_hunk_key     = iv_hunk_key
          iv_action       = 'D'
          it_hunk_actions = it_hunk_actions ).
      IF lv_own_hunk = abap_true.
        lv_actions_html = render_comment_links(
          iv_hunk_key     = iv_hunk_key
          it_hunk_threads = it_hunk_threads
          iv_ai_enabled   = iv_ai_enabled ).
      ELSE.
        lv_actions_html =
          |<a href="sapevent:undo~{ iv_hunk_key }"| &&
          ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
          `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Undo</a>` &&
          |<a href="sapevent:approve~{ iv_hunk_key }"| &&
          ` style="margin-left:4px;background:#27ae60;color:#fff;font-weight:bold;` &&
          `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">&#10003; Approve</a>` &&
          render_comment_links(
            iv_hunk_key     = iv_hunk_key
            it_hunk_threads = it_hunk_threads
            iv_ai_enabled   = iv_ai_enabled ).
      ENDIF.
    ELSEIF lv_global_action = 'A' OR lv_global_action = 'D'.
      lv_status_html = COND string(
        WHEN lv_global_action = 'A'
        THEN `<span style="color:#27ae60;font-weight:bold">&#10003; approved</span>` &&
             render_hunk_action_meta(
               iv_hunk_key     = iv_hunk_key
               iv_action       = 'A'
               it_hunk_actions = it_hunk_actions )
        ELSE `<span style="color:#e74c3c;font-weight:bold">&#10007; declined</span>` &&
             render_hunk_action_meta(
               iv_hunk_key     = iv_hunk_key
               iv_action       = 'D'
               it_hunk_actions = it_hunk_actions ) ).
      IF lv_own_hunk = abap_true.
        lv_actions_html = render_comment_links(
          iv_hunk_key     = iv_hunk_key
          it_hunk_threads = it_hunk_threads
          iv_ai_enabled   = iv_ai_enabled ).
      ELSE.
        lv_actions_html =
          |<a href="sapevent:approve~{ iv_hunk_key }"| &&
          ` style="margin-left:8px;background:#27ae60;color:#fff;font-weight:bold;` &&
          `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">&#10003; Approve</a>` &&
          |<a href="sapevent:decline~{ iv_hunk_key }"| &&
          ` style="margin-left:4px;background:#922b21;color:#fff;font-weight:bold;` &&
          `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">&#10007; Decline</a>` &&
          render_comment_links(
            iv_hunk_key     = iv_hunk_key
            it_hunk_threads = it_hunk_threads
            iv_ai_enabled   = iv_ai_enabled ).
      ENDIF.
    ELSE.
      IF lv_own_hunk = abap_true.
        lv_status_html =
          `<span style="color:#7f8c8d;font-weight:bold">&#9675; own block</span>`.
        lv_actions_html = render_comment_links(
          iv_hunk_key     = iv_hunk_key
          it_hunk_threads = it_hunk_threads
          iv_ai_enabled   = iv_ai_enabled ).
      ELSE.
        lv_status_html =
          `<span style="color:#7f8c8d;font-weight:bold">&#9675; open</span>`.
        lv_actions_html =
          |<a href="sapevent:approve~{ iv_hunk_key }"| &&
          ` style="margin-left:8px;background:#27ae60;color:#fff;font-weight:bold;` &&
          `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">&#10003; Approve</a>` &&
          |<a href="sapevent:decline~{ iv_hunk_key }"| &&
          ` style="margin-left:4px;background:#922b21;color:#fff;font-weight:bold;` &&
          `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">&#10007; Decline</a>` &&
          render_comment_links(
            iv_hunk_key     = iv_hunk_key
            it_hunk_threads = it_hunk_threads
            iv_ai_enabled   = iv_ai_enabled ).
      ENDIF.
    ENDIF.

    result =
      `<div style="display:flex;align-items:center;gap:0;margin:2px 0 8px 0">` &&
      lv_status_html && lv_actions_html && `</div>`.
  ENDMETHOD.


  METHOD render_comment_links.
    DATA(lv_last_note) = zcl_ave_acr_state=>get_last_own_comment(
      iv_hunk_key     = iv_hunk_key
      it_hunk_threads = it_hunk_threads ).
    IF lv_last_note IS NOT INITIAL.
      result =
        |<a href="sapevent:editreview~{ iv_hunk_key }"| &&
        ` onclick="if(window._saveScroll)window._saveScroll()"` &&
        ` style="margin-left:4px;background:#7f8c8d;color:#fff;font-weight:bold;` &&
        `text-decoration:none;font-style:normal;font-size:11px;` &&
        `border-radius:3px;padding:2px 7px">Edit</a>`.
    ENDIF.

    result = result &&
      |<a href="sapevent:addcomment~{ iv_hunk_key }"| &&
      ` onclick="if(window._saveScroll)window._saveScroll()"` &&
      ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
      `text-decoration:none;font-style:normal;font-size:11px;` &&
      `border-radius:3px;padding:2px 7px">Add Comment</a>`.

    result = result &&
      |<a href="sapevent:askai~{ iv_hunk_key }"| &&
      ` onclick="if(window._saveScroll)window._saveScroll()"` &&
      ` style="margin-left:4px;background:#8e44ad;color:#fff;font-weight:bold;` &&
      `text-decoration:none;font-style:normal;font-size:11px;` &&
      `border-radius:3px;padding:2px 7px">ASK AI</a>`.
  ENDMETHOD.


  METHOD render_hunk_action_meta.
    DATA ls_action TYPE zif_ave_acr_types=>ty_hunk_action.
    LOOP AT it_hunk_actions INTO DATA(ls_action_cur)
      WHERE hunk_key = iv_hunk_key AND action = iv_action.
      IF ls_action IS INITIAL OR ls_action_cur-changed_at > ls_action-changed_at.
        ls_action = ls_action_cur.
      ENDIF.
    ENDLOOP.
    CHECK ls_action IS NOT INITIAL.
    DATA(lv_label) = COND string(
      WHEN iv_action = 'A' THEN ''
      WHEN iv_action = 'D' THEN ''
      ELSE ` reviewed` ).
    result =
      | <span style="font-weight:normal;color:#7f8c8d;font-size:10px">| &&
      |{ lv_label }/ by { escape( val = CONV string( ls_action-reviewer ) format = cl_abap_format=>e_html_text ) }| &&
      | / { escape( val = CONV string( ls_action-reviewer_name ) format = cl_abap_format=>e_html_text ) }| &&
      | / { escape( val = zcl_ave_acr_state=>format_timestamp( ls_action-changed_at ) format = cl_abap_format=>e_html_text ) }</span>|.
  ENDMETHOD.


  METHOD build_review_help_html.
    result =
      `<!DOCTYPE html><html><head><meta charset="utf-8"><style>` &&
      `body{font:13px/1.5 Segoe UI,Arial,sans-serif;background:#f7f7f9;color:#222;padding:18px;}` &&
      `h2{margin:0 0 10px;color:#0a6ed1;}p{margin:0 0 12px;}` &&
      `table{border-collapse:collapse;width:100%;background:#fff;margin:10px 0 14px;}` &&
      `th,td{border:1px solid #d9d9d9;padding:7px 9px;text-align:left;vertical-align:top;}` &&
      `th{background:#eef4fb;}code{background:#eef2f7;padding:1px 4px;border-radius:3px;}` &&
      `ol{margin:8px 0 0 22px;padding:0;}li{margin:0 0 6px;}` &&
      `</style></head><body>` &&
      `<h2>Save review requires table ZAVE_REVIEW</h2>` &&
      `<p>The button can save review data only after a transparent table <code>ZAVE_REVIEW</code> is created and activated.</p>` &&
      `<p>For now keep the design minimal: one row per transport request, and the full review with save history stored inside one JSON payload.</p>` &&
      `<table><tr><th>Field</th><th>Type</th><th>Purpose</th></tr>` &&
      `<tr><td>MANDT</td><td>MANDT</td><td>Client field</td></tr>` &&
      `<tr><td>TRKORR</td><td>TRKORR</td><td>Transport request key</td></tr>` &&
      `<tr><td>PAYLOAD</td><td>STRING</td><td>Stored review JSON including current state and save history</td></tr>` &&
      `</table>` &&
      `<ol>` &&
      `<li>Create transparent table <code>ZAVE_REVIEW</code>.</li>` &&
      `<li>Make <code>MANDT</code> and <code>TRKORR</code> key fields.</li>` &&
      `<li>Add field <code>PAYLOAD</code> as type <code>STRING</code>.</li>` &&
      `<li>Activate the table. No ZIP or compression is needed yet.</li>` &&
      `<li>Return to AVE and press <code>Save</code> again.</li>` &&
      `</ol>` &&
      `</body></html>`.
  ENDMETHOD.


  METHOD add_report_toolbar.
    result = iv_html.
    CHECK iv_enabled = abap_true.
    CHECK result CS `</body>`.

    DATA(lv_toolbar) =
      `<div style="position:fixed;top:8px;right:12px;z-index:1000">` &&
      `<a href="sapevent:recalcpick~0"` &&
      ` style="display:inline-block;background:#7f8c8d;color:#fff;` &&
      `padding:5px 14px;border-radius:4px;font:bold 12px Consolas,sans-serif;` &&
      `text-decoration:none;box-shadow:0 1px 4px rgba(0,0,0,.25)">Recalc Diff</a>` &&
      `</div>`.

    result = replace( val = result sub = `</body>` with = lv_toolbar && `</body>` ).
  ENDMETHOD.
ENDCLASS.
