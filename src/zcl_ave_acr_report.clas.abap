CLASS zcl_ave_acr_report DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Build the Code Review Report HTML page from pre-computed object stats.
    CLASS-METHODS to_html
      IMPORTING it_obj_stats  TYPE zif_ave_acr_types=>ty_t_obj_stats
                i_korrnum     TYPE trkorr
                it_approved   TYPE zif_ave_acr_types=>ty_approved OPTIONAL
                it_declined   TYPE zif_ave_acr_types=>ty_approved OPTIONAL
                it_reviewers  TYPE zif_ave_acr_types=>ty_t_reviewer_stats OPTIONAL
      RETURNING VALUE(result) TYPE string.

protected section.
  PRIVATE SECTION.
    CLASS-METHODS esc
      IMPORTING iv_val        TYPE clike
      RETURNING VALUE(result) TYPE string.

ENDCLASS.



CLASS ZCL_AVE_ACR_REPORT IMPLEMENTATION.


  METHOD to_html.
    " Transport description from E07T
    DATA lv_korr_text TYPE as4text.
    SELECT SINGLE as4text FROM e07t
      WHERE trkorr = @i_korrnum AND langu = @sy-langu
      INTO @lv_korr_text.

    " Aggregate grand totals per owner across all objects
    TYPES: BEGIN OF ty_owner_total,
             author      TYPE versuser,
             author_name TYPE ad_namtext,
             ins_count   TYPE i,
             mod_count   TYPE i,
             del_count   TYPE i,
             hunk_count  TYPE i,
             appr_count  TYPE i,
             decl_count  TYPE i,
           END OF ty_owner_total.
    DATA lt_totals TYPE STANDARD TABLE OF ty_owner_total WITH DEFAULT KEY.

    LOOP AT it_obj_stats INTO DATA(ls_obj).
      " Compute approved/declined for this object
      DATA(lv_obj_prefix) = |{ ls_obj-objtype }~{ ls_obj-obj_name }~|.
      DATA(lv_cp_pat2) = lv_obj_prefix && `*`.
      DATA lv_oa TYPE i. DATA lv_od TYPE i. CLEAR: lv_oa, lv_od.
      LOOP AT it_approved INTO DATA(lv_ak2). IF lv_ak2 CP lv_cp_pat2. lv_oa += 1. ENDIF. ENDLOOP.
      LOOP AT it_declined INTO DATA(lv_dk2). IF lv_dk2 CP lv_cp_pat2. lv_od += 1. ENDIF. ENDLOOP.
      IF lv_oa > ls_obj-hunk_count.
        lv_oa = ls_obj-hunk_count.
      ENDIF.
      IF lv_od > ls_obj-hunk_count.
        lv_od = ls_obj-hunk_count.
      ENDIF.

      IF ls_obj-bt_authors IS NOT INITIAL.

        LOOP AT ls_obj-bt_authors INTO DATA(ls_ba).
          READ TABLE lt_totals ASSIGNING FIELD-SYMBOL(<t>) WITH KEY author = ls_ba-author.
          IF sy-subrc <> 0.
            APPEND VALUE #( author = ls_ba-author author_name = ls_ba-author_name ) TO lt_totals.
            READ TABLE lt_totals ASSIGNING <t> WITH KEY author = ls_ba-author.
          ENDIF.
          <t>-ins_count  += ls_ba-ins_count.
          <t>-del_count  += ls_ba-del_count.
          <t>-mod_count  += ls_ba-mod_count.
          <t>-hunk_count += ls_ba-hunk_count.
        ENDLOOP.

        " approved/declined go to primary author (most ins, then mod lines)
        DATA lv_primary      TYPE versuser.
        DATA lv_primary_ins  TYPE i.
        DATA lv_primary_mod  TYPE i.
        CLEAR: lv_primary, lv_primary_ins, lv_primary_mod.
        LOOP AT ls_obj-bt_authors INTO ls_ba.
          IF ls_ba-ins_count > lv_primary_ins.
            lv_primary_ins = ls_ba-ins_count.
            lv_primary_mod = ls_ba-mod_count.
            lv_primary     = ls_ba-author.
          ELSEIF ls_ba-ins_count = lv_primary_ins AND ls_ba-mod_count > lv_primary_mod.
            lv_primary_mod = ls_ba-mod_count.
            lv_primary     = ls_ba-author.
          ENDIF.
        ENDLOOP.
        IF lv_primary IS INITIAL.
          DATA lv_primary_del TYPE i.
          CLEAR lv_primary_del.
          LOOP AT ls_obj-bt_authors INTO ls_ba.
            IF ls_ba-del_count > lv_primary_del.
              lv_primary_del = ls_ba-del_count.
              lv_primary     = ls_ba-author.
            ENDIF.
          ENDLOOP.
        ENDIF.
        IF lv_primary IS NOT INITIAL.
          READ TABLE lt_totals ASSIGNING <t> WITH KEY author = lv_primary.
          IF sy-subrc = 0.
            <t>-appr_count += lv_oa.
            <t>-decl_count += lv_od.
          ENDIF.
        ENDIF.
      ELSEIF ls_obj-author IS NOT INITIAL.
        READ TABLE lt_totals ASSIGNING <t> WITH KEY author = ls_obj-author.
        IF sy-subrc <> 0.
          APPEND VALUE #( author = ls_obj-author author_name = ls_obj-author_name ) TO lt_totals.
          READ TABLE lt_totals ASSIGNING <t> WITH KEY author = ls_obj-author.
        ENDIF.
        <t>-ins_count  += ls_obj-ins_count.
        <t>-del_count  += ls_obj-del_count.
        <t>-mod_count  += ls_obj-mod_count.
        <t>-hunk_count += ls_obj-hunk_count.
        <t>-appr_count += lv_oa.
        <t>-decl_count += lv_od.
      ENDIF.
    ENDLOOP.

    " Shared CSS (matches AVE's Consolas/monospace style)
    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `h3{color:#555;margin:20px 0 6px}` &&
      `table{border-collapse:collapse;width:100%;margin-bottom:16px;font-size:12px}` &&
      `th{background:#3498db;color:#fff;padding:5px 10px;text-align:left;white-space:nowrap}` &&
      `td{padding:4px 10px;border-bottom:1px solid #eee;white-space:nowrap}` &&
      `tr:hover td{background:#f5f9ff}` &&
      `td:nth-child(2){width:220px;min-width:220px;max-width:220px;overflow:hidden;text-overflow:ellipsis}` &&
      `tr.obj-row{cursor:pointer}` &&
      `tr.obj-row:hover td{background:#e8f0fb}` &&
      `tr.user-row{cursor:pointer}` &&
      `tr.user-row:hover td{background:#e8f0fb}` &&
      `.cr td{background:#f0f4f8;font-weight:bold}` &&
      `.mr td:nth-child(3){padding-left:24px}` &&
      `.nr{text-align:right}` &&
      `.gi{color:#27ae60}.gd{color:#e74c3c}.gm{color:#e67e22}`.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8">| &&
      |<style>{ lv_css }</style>| &&
      `<script>x=1;</script></head><body>`.

    " ── Header ──────────────────────────────────────────────────────
    result = result &&
      |<h2>&#128196;&nbsp;Code Review Report&nbsp;&mdash;&nbsp;| &&
      |<span style="color:#3498db">{ esc( i_korrnum ) }|.
    IF lv_korr_text IS NOT INITIAL.
      result = result && |&nbsp;&mdash;&nbsp;{ esc( lv_korr_text ) }|.
    ENDIF.
    result = result && |</span></h2>|.

    " ── Authors table ───────────────────────────────────────────────
    IF lt_totals IS NOT INITIAL.
      result = result &&
        |<h3>Developers</h3>| &&
        |<table><tr>| &&
        |<th>Developer</th><th>Name</th>| &&
        |<th class="nr">Ins/Mod/Del</th>| &&
        |<th class="nr">Blocks</th>| &&
        |<th class="nr">Approved</th>| &&
        |<th class="nr">Declined</th>| &&
        |<th class="nr">%</th></tr>|.
      LOOP AT lt_totals INTO DATA(ls_tot).
        CHECK ls_tot-ins_count > 0 OR ls_tot-mod_count > 0 OR ls_tot-del_count > 0
           OR ls_tot-hunk_count > 0.
        " Build approved/declined/% cells for owner row
        DATA lv_ow_appr_cell TYPE string.
        DATA lv_ow_decl_cell TYPE string.
        DATA lv_ow_pct_cell  TYPE string.
        DATA lv_ow_pct       TYPE i.
        IF ls_tot-hunk_count = 0.
          lv_ow_appr_cell = `<td class="nr">—</td>`.
          lv_ow_decl_cell = `<td class="nr">—</td>`.
          lv_ow_pct_cell  = `<td class="nr">—</td>`.
        ELSE.
          DATA(lv_ow_done) = ls_tot-appr_count + ls_tot-decl_count.
          IF lv_ow_done > ls_tot-hunk_count.
            lv_ow_done = ls_tot-hunk_count.
          ENDIF.
          lv_ow_pct = lv_ow_done * 100 / ls_tot-hunk_count.
          " Approved: green only at 100% approved
          IF ls_tot-appr_count = ls_tot-hunk_count.
            lv_ow_appr_cell = |<td class="nr gi" style="font-weight:bold">&#10003; { ls_tot-appr_count }/{ ls_tot-hunk_count }</td>|.
          ELSEIF ls_tot-appr_count > 0.
            lv_ow_appr_cell = |<td class="nr" style="font-weight:bold">&#10003; { ls_tot-appr_count }/{ ls_tot-hunk_count }</td>|.
          ELSE.
            lv_ow_appr_cell = |<td class="nr">{ ls_tot-appr_count }/{ ls_tot-hunk_count }</td>|.
          ENDIF.
          " Declined: red only at 100% declined
          IF ls_tot-decl_count = ls_tot-hunk_count.
            lv_ow_decl_cell = |<td class="nr gd" style="font-weight:bold">&#10007; { ls_tot-decl_count }/{ ls_tot-hunk_count }</td>|.
          ELSEIF ls_tot-decl_count > 0.
            lv_ow_decl_cell = |<td class="nr" style="font-weight:bold">&#10007; { ls_tot-decl_count }/{ ls_tot-hunk_count }</td>|.
          ELSE.
            lv_ow_decl_cell = |<td class="nr">{ ls_tot-decl_count }/{ ls_tot-hunk_count }</td>|.
          ENDIF.
          " %: green at 100% approved, red at 100% declined
          IF ls_tot-appr_count = ls_tot-hunk_count.
            lv_ow_pct_cell = |<td class="nr gi" style="font-weight:bold">{ lv_ow_pct }%</td>|.
          ELSEIF ls_tot-decl_count = ls_tot-hunk_count.
            lv_ow_pct_cell = |<td class="nr gd" style="font-weight:bold">{ lv_ow_pct }%</td>|.
          ELSE.
            lv_ow_pct_cell = |<td class="nr" style="font-weight:bold">{ lv_ow_pct }%</td>|.
          ENDIF.
        ENDIF.
        DATA(lv_user_tr_attr) = `class="user-row" title="Click to show declined notes"`.
        result = result &&
          |<tr { lv_user_tr_attr }>| &&
          |<td style="font-weight:bold"><a href="sapevent:openuserdeclined~{ esc( ls_tot-author ) }">{ esc( ls_tot-author ) }</a></td>| &&
          |<td style="font-weight:bold">{ esc( ls_tot-author_name ) }</td>| &&
          |<td class="nr" style="font-weight:bold">| &&
            |<span style="color:#27ae60">{ ls_tot-ins_count }</span>| &&
            |&nbsp;/&nbsp;<span style="color:#e67e22">{ ls_tot-mod_count }</span>| &&
            |&nbsp;/&nbsp;<span style="color:#e74c3c">{ ls_tot-del_count }</span>| &&
          |</td>| &&
          |<td class="nr" style="font-weight:bold">{ ls_tot-hunk_count }</td>| &&
          lv_ow_appr_cell && lv_ow_decl_cell && lv_ow_pct_cell &&
          |</tr>|.
      ENDLOOP.
      result = result && |</table>|.
    ENDIF.

    " ── Changed objects table ────────────────────────────────────────
    IF it_reviewers IS NOT INITIAL.
      result = result &&
        |<h3>Reviewers</h3>| &&
        |<table><tr>| &&
        |<th>Reviewer</th><th>Name</th>| &&
        |<th class="nr">Approved</th>| &&
        |<th class="nr">Declined</th>| &&
        |<th class="nr">Total</th></tr>|.
      LOOP AT it_reviewers INTO DATA(ls_rev).
        CHECK ls_rev-total_count > 0.
        result = result &&
          |<tr>| &&
          |<td style="font-weight:bold"><a href="sapevent:openreviewer~{ esc( ls_rev-reviewer ) }">{ esc( ls_rev-reviewer ) }</a></td>| &&
          |<td style="font-weight:bold">{ esc( ls_rev-reviewer_name ) }</td>| &&
          |<td class="nr gi" style="font-weight:bold">{ ls_rev-appr_count }</td>| &&
          |<td class="nr gd" style="font-weight:bold">{ ls_rev-decl_count }</td>| &&
          |<td class="nr" style="font-weight:bold">{ ls_rev-total_count }</td>| &&
          |</tr>|.
      ENDLOOP.
      result = result && |</table>|.
    ENDIF.

    TYPES: BEGIN OF ty_sort,
             class_name TYPE seoclsname,
             type_order TYPE i,
             obj_name   TYPE versobjnam,
             idx        TYPE i,
           END OF ty_sort.
    DATA lt_sort TYPE STANDARD TABLE OF ty_sort WITH DEFAULT KEY.
    DATA lt_sorted TYPE zif_ave_acr_types=>ty_t_obj_stats.
    lt_sorted = it_obj_stats.

    LOOP AT lt_sorted INTO DATA(ls_s2).
      DATA(lv_ord) = SWITCH i( ls_s2-objtype
        WHEN 'CLSD' THEN 1
        WHEN 'CPUB' THEN 2
        WHEN 'CPRO' THEN 3
        WHEN 'CPRI' THEN 4
        WHEN 'CINC' THEN 5
        WHEN 'CDEF' THEN 6
        WHEN 'METH' THEN 7
        ELSE             0 ).
      DATA(lv_class_name) = ls_s2-class_name.
      IF lv_class_name IS INITIAL.
        CASE ls_s2-objtype.
          WHEN 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'CINC' OR 'CDEF'.
            DATA(lv_obj_name) = CONV string( ls_s2-obj_name ).
            FIND FIRST OCCURRENCE OF '=' IN lv_obj_name MATCH OFFSET DATA(lv_eq_pos).
            IF sy-subrc = 0.
              lv_obj_name = lv_obj_name(lv_eq_pos).
            ENDIF.
            lv_class_name = CONV #( lv_obj_name ).
        ENDCASE.
      ENDIF.
      APPEND VALUE #( class_name = lv_class_name
                      type_order = lv_ord
                      obj_name   = ls_s2-obj_name
                      idx        = sy-tabix ) TO lt_sort.
    ENDLOOP.
    SORT lt_sort BY class_name type_order obj_name.

    DATA lt_sorted_final TYPE zif_ave_acr_types=>ty_t_obj_stats.
    LOOP AT lt_sort INTO DATA(ls_ord).
      READ TABLE lt_sorted INTO DATA(ls_tmp) INDEX ls_ord-idx.
      IF ls_tmp-class_name IS INITIAL.
        ls_tmp-class_name = ls_ord-class_name.
      ENDIF.
      APPEND ls_tmp TO lt_sorted_final.
    ENDLOOP.

    " Remove entries with no actual changes
    DELETE lt_sorted_final WHERE ins_count = 0 AND del_count = 0 AND mod_count = 0.

    " Render one table per class (empty class_name = programs/other)
    DATA lv_cur_class TYPE seoclsname VALUE '####'.
    DATA(lv_tbl_hdr) =
      |<table><tr>| &&
      |<th>Type</th><th>Object</th>| &&
      |<th>Owner</th><th>Date</th><th>Time</th>| &&
      |<th class="nr">Ins/Mod/Del</th>| &&
      |<th class="nr">Blocks</th>| &&
      |<th class="nr">Approved</th>| &&
      |<th class="nr">Declined</th>| &&
      |<th class="nr">%</th></tr>|.

    " Class-level totals accumulators
    DATA lv_tot_ins     TYPE i.
    DATA lv_tot_mod     TYPE i.
    DATA lv_tot_del     TYPE i.
    DATA lv_tot_hunks   TYPE i.
    DATA lv_tot_appr    TYPE i.
    DATA lv_tot_decl    TYPE i.

    DATA lv_tot_pct       TYPE i.
    DATA lv_tot_appr_cell TYPE string.
    DATA lv_tot_decl_cell TYPE string.
    DATA lv_tot_pct_cell  TYPE string.

    LOOP AT lt_sorted_final INTO ls_obj.
      IF ls_obj-class_name <> lv_cur_class.
        " ── close previous table with Total row ──
        IF lv_cur_class <> '####'.
          IF lv_tot_hunks = 0.
            lv_tot_appr_cell = `<td class="nr">—</td>`.
            lv_tot_decl_cell = `<td class="nr">—</td>`.
            lv_tot_pct_cell  = `<td class="nr">—</td>`.
          ELSE.
            DATA(lv_class_done) = lv_tot_appr + lv_tot_decl.
            IF lv_class_done > lv_tot_hunks.
              lv_class_done = lv_tot_hunks.
            ENDIF.
            lv_tot_pct = lv_class_done * 100 / lv_tot_hunks.
            IF lv_tot_appr > 0.
              lv_tot_appr_cell = |<td class="nr gi" style="font-weight:bold">&#10003; { lv_tot_appr }/{ lv_tot_hunks }</td>|.
            ELSE.
              lv_tot_appr_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_appr }/{ lv_tot_hunks }</td>|.
            ENDIF.
            IF lv_tot_decl > 0.
              lv_tot_decl_cell = |<td class="nr gd" style="font-weight:bold">&#10007; { lv_tot_decl }/{ lv_tot_hunks }</td>|.
            ELSE.
              lv_tot_decl_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_decl }/{ lv_tot_hunks }</td>|.
            ENDIF.
            lv_tot_pct_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_pct }%</td>|.
          ENDIF.
          result = result &&
            `<tr style="background:#e8f0fb;border-top:2px solid #3498db">` &&
            `<td style="font-weight:bold;color:#2c3e50" colspan="2">Total</td>` &&
            `<td colspan="3"></td>` &&
            |<td class="nr" style="font-weight:bold">| &&
              |<span style="color:#27ae60">{ lv_tot_ins }</span>| &&
              |&nbsp;/&nbsp;<span style="color:#e67e22">{ lv_tot_mod }</span>| &&
              |&nbsp;/&nbsp;<span style="color:#e74c3c">{ lv_tot_del }</span></td>| &&
            |<td class="nr" style="font-weight:bold">{ lv_tot_hunks }</td>| &&
            lv_tot_appr_cell && lv_tot_decl_cell && lv_tot_pct_cell &&
            `</tr></table>`.
          CLEAR: lv_tot_ins, lv_tot_mod, lv_tot_del, lv_tot_hunks, lv_tot_appr, lv_tot_decl.
        ENDIF.
        lv_cur_class = ls_obj-class_name.
        IF lv_cur_class IS INITIAL.
          result = result && |<h3>Programs / Other</h3>|.
        ELSE.
          result = result && |<h3>Class: { esc( lv_cur_class ) }</h3>|.
        ENDIF.
        result = result && lv_tbl_hdr.
      ENDIF.

      " Format date/time for display
      DATA(lv_date) = CONV string( ls_obj-datum ).
      IF lv_date IS NOT INITIAL.
        lv_date = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }|.
      ENDIF.
      DATA(lv_time) = CONV string( ls_obj-zeit ).
      IF lv_time IS NOT INITIAL.
        lv_time = |{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.
      ENDIF.

      " Compute approve/decline stats for this object
      lv_obj_prefix = |{ ls_obj-objtype }~{ ls_obj-obj_name }~|.
      DATA(lv_cp_pat) = lv_obj_prefix && `*`.
      DATA lv_appr TYPE i.
      DATA lv_decl TYPE i.
      CLEAR: lv_appr, lv_decl.
      LOOP AT it_approved INTO DATA(lv_ak).
        IF lv_ak CP lv_cp_pat. lv_appr += 1. ENDIF.
      ENDLOOP.
      LOOP AT it_declined INTO DATA(lv_dk).
        IF lv_dk CP lv_cp_pat. lv_decl += 1. ENDIF.
      ENDLOOP.
      DATA lv_total_h      TYPE i.
      DATA lv_approve_cell TYPE string.
      DATA lv_decline_cell TYPE string.
      DATA lv_pct_cell     TYPE string.
      DATA lv_pct          TYPE i.
      CLEAR: lv_total_h, lv_approve_cell, lv_decline_cell, lv_pct_cell, lv_pct.
      lv_total_h = ls_obj-hunk_count.
      IF lv_appr > lv_total_h.
        lv_appr = lv_total_h.
      ENDIF.
      IF lv_decl > lv_total_h.
        lv_decl = lv_total_h.
      ENDIF.
      IF lv_total_h = 0.
        lv_approve_cell = `<td class="nr">—</td>`.
        lv_decline_cell = `<td class="nr">—</td>`.
        lv_pct_cell     = `<td class="nr">—</td>`.
      ELSE.
        DATA(lv_obj_done) = lv_appr + lv_decl.
        IF lv_obj_done > lv_total_h.
          lv_obj_done = lv_total_h.
        ENDIF.
        lv_pct = lv_obj_done * 100 / lv_total_h.
        " Approved: green only at 100% approved
        IF lv_appr = lv_total_h.
          lv_approve_cell = |<td class="nr gi" style="font-weight:bold">&#10003; { lv_appr }/{ lv_total_h }</td>|.
        ELSEIF lv_appr > 0.
          lv_approve_cell = |<td class="nr" style="font-weight:bold">&#10003; { lv_appr }/{ lv_total_h }</td>|.
        ELSE.
          lv_approve_cell = |<td class="nr">{ lv_appr }/{ lv_total_h }</td>|.
        ENDIF.
        " Declined: red only at 100% declined
        IF lv_decl = lv_total_h.
          lv_decline_cell = |<td class="nr gd" style="font-weight:bold">&#10007; { lv_decl }/{ lv_total_h }</td>|.
        ELSEIF lv_decl > 0.
          lv_decline_cell = |<td class="nr" style="font-weight:bold">&#10007; { lv_decl }/{ lv_total_h }</td>|.
        ELSE.
          lv_decline_cell = |<td class="nr">{ lv_decl }/{ lv_total_h }</td>|.
        ENDIF.
        " %: green at 100% approved, red at 100% declined
        IF lv_appr = lv_total_h.
          lv_pct_cell = |<td class="nr gi" style="font-weight:bold">{ lv_pct }%</td>|.
        ELSEIF lv_decl = lv_total_h.
          lv_pct_cell = |<td class="nr gd" style="font-weight:bold">{ lv_pct }%</td>|.
        ELSE.
          lv_pct_cell = |<td class="nr" style="font-weight:bold">{ lv_pct }%</td>|.
        ENDIF.
      ENDIF.

      " Accumulate class totals
      lv_tot_ins     += ls_obj-ins_count.
      lv_tot_mod     += ls_obj-mod_count.
      lv_tot_del     += ls_obj-del_count.
      lv_tot_hunks   += ls_obj-hunk_count.
      lv_tot_appr    += lv_appr.
      lv_tot_decl    += lv_decl.

      DATA(lv_ev_key) = |{ ls_obj-objtype }~{ ls_obj-obj_name }|.
      DATA lv_disp_name TYPE string.
      lv_disp_name = COND #( WHEN ls_obj-display_name IS NOT INITIAL THEN ls_obj-display_name ELSE ls_obj-obj_name ).
      DATA(lv_row_id) = |obj_{ escape( val = lv_ev_key format = cl_abap_format=>e_html_attr ) }|.
      DATA lv_name_cell TYPE string.
      IF ls_obj-is_created = abap_true.
        lv_name_cell = |<td><a href="sapevent:openobj~{ lv_ev_key }" style="font-weight:bold;color:#27ae60">{ esc( lv_disp_name ) }</a></td>|.
      ELSE.
        lv_name_cell = |<td><a href="sapevent:openobj~{ lv_ev_key }" style="font-weight:bold">{ esc( lv_disp_name ) }</a></td>|.
      ENDIF.
      DATA lv_owner_display TYPE string.
      DATA lv_owner_count TYPE i.
      CLEAR: lv_owner_display, lv_owner_count.
      IF ls_obj-bt_authors IS NOT INITIAL.
        LOOP AT ls_obj-bt_authors INTO DATA(ls_owner_ba) WHERE hunk_count > 0.
          CHECK ls_owner_ba-author IS NOT INITIAL.
          lv_owner_count += 1.
          IF lv_owner_count <= 3.
            IF lv_owner_display IS INITIAL.
              lv_owner_display = ls_owner_ba-author.
            ELSE.
              lv_owner_display = lv_owner_display && `, ` && ls_owner_ba-author.
            ENDIF.
          ENDIF.
        ENDLOOP.
        IF lv_owner_count > 3.
          lv_owner_display = `Several`.
        ENDIF.
      ENDIF.
      IF lv_owner_display IS INITIAL.
        lv_owner_display = ls_obj-author.
      ENDIF.
      result = result &&
        |<tr id="{ lv_row_id }">| &&
        |<td>{ esc( ls_obj-objtype ) }</td>| &&
        lv_name_cell &&
        |<td>{ esc( lv_owner_display ) }</td>| &&
        |<td>{ lv_date }</td>| &&
        |<td>{ lv_time }</td>| &&
        |<td class="nr" style="font-weight:bold">| &&
          |<span style="color:#27ae60">{ ls_obj-ins_count }</span>| &&
          |&nbsp;/&nbsp;<span style="color:#e67e22">{ ls_obj-mod_count }</span>| &&
          |&nbsp;/&nbsp;<span style="color:#e74c3c">{ ls_obj-del_count }</span></td>| &&
        |<td class="nr" style="font-weight:bold">{ ls_obj-hunk_count }</td>| &&
        lv_approve_cell && lv_decline_cell && lv_pct_cell &&
        `</tr>`.
    ENDLOOP.

    " ── close last table with Total row ──
    IF lv_cur_class <> '####'.
      IF lv_tot_hunks = 0.
        lv_tot_appr_cell = `<td class="nr">—</td>`.
        lv_tot_decl_cell = `<td class="nr">—</td>`.
        lv_tot_pct_cell  = `<td class="nr">—</td>`.
      ELSE.
        DATA(lv_group_done) = lv_tot_appr + lv_tot_decl.
        IF lv_group_done > lv_tot_hunks.
          lv_group_done = lv_tot_hunks.
        ENDIF.
        lv_tot_pct = lv_group_done * 100 / lv_tot_hunks.
        IF lv_tot_appr > 0.
          lv_tot_appr_cell = |<td class="nr gi" style="font-weight:bold">&#10003; { lv_tot_appr }/{ lv_tot_hunks }</td>|.
        ELSE.
          lv_tot_appr_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_appr }/{ lv_tot_hunks }</td>|.
        ENDIF.
        IF lv_tot_decl > 0.
          lv_tot_decl_cell = |<td class="nr gd" style="font-weight:bold">&#10007; { lv_tot_decl }/{ lv_tot_hunks }</td>|.
        ELSE.
          lv_tot_decl_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_decl }/{ lv_tot_hunks }</td>|.
        ENDIF.
        lv_tot_pct_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_pct }%</td>|.
      ENDIF.
      result = result &&
        `<tr style="background:#e8f0fb;border-top:2px solid #3498db">` &&
        `<td style="font-weight:bold;color:#2c3e50" colspan="2">Total</td>` &&
        `<td colspan="3"></td>` &&
        |<td class="nr" style="font-weight:bold">| &&
          |<span style="color:#27ae60">{ lv_tot_ins }</span>| &&
          |&nbsp;/&nbsp;<span style="color:#e67e22">{ lv_tot_mod }</span>| &&
          |&nbsp;/&nbsp;<span style="color:#e74c3c">{ lv_tot_del }</span></td>| &&
        |<td class="nr" style="font-weight:bold">{ lv_tot_hunks }</td>| &&
        lv_tot_appr_cell && lv_tot_decl_cell && lv_tot_pct_cell &&
        `</tr></table>`.
    ENDIF.

    result = result && |</body></html>|.
  ENDMETHOD.


  METHOD esc.
result = escape( val = CONV string( iv_val ) format = cl_abap_format=>e_html_text ).
  ENDMETHOD.
ENDCLASS.
