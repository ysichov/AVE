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
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS esc
      IMPORTING iv_val        TYPE clike
      RETURNING VALUE(result) TYPE string.

ENDCLASS.


CLASS zcl_ave_acr_report IMPLEMENTATION.

  METHOD to_html.
    " Transport description from E07T
    DATA lv_korr_text TYPE as4text.
    SELECT SINGLE as4text FROM e07t
      WHERE trkorr = @i_korrnum AND langu = @sy-langu
      INTO @lv_korr_text.

    " Aggregate grand totals per author across all objects
    DATA lt_totals TYPE zif_ave_acr_types=>ty_t_author_stats.
    LOOP AT it_obj_stats INTO DATA(ls_obj).
      IF ls_obj-bt_authors IS NOT INITIAL.
        " Blame data available: use per-line attribution
        LOOP AT ls_obj-bt_authors INTO DATA(ls_ba).
          READ TABLE lt_totals ASSIGNING FIELD-SYMBOL(<t>) WITH KEY author = ls_ba-author.
          IF sy-subrc <> 0.
            INSERT VALUE #( author = ls_ba-author author_name = ls_ba-author_name )
              INTO TABLE lt_totals.
            READ TABLE lt_totals ASSIGNING <t> WITH KEY author = ls_ba-author.
          ENDIF.
          <t>-ins_count += ls_ba-ins_count.
          <t>-del_count += ls_ba-del_count.
          <t>-mod_count += ls_ba-mod_count.
        ENDLOOP.
      ELSEIF ls_obj-author IS NOT INITIAL.
        " No blame: attribute all changes to the version author
        READ TABLE lt_totals ASSIGNING <t> WITH KEY author = ls_obj-author.
        IF sy-subrc <> 0.
          INSERT VALUE #( author = ls_obj-author author_name = ls_obj-author_name )
            INTO TABLE lt_totals.
          READ TABLE lt_totals ASSIGNING <t> WITH KEY author = ls_obj-author.
        ENDIF.
        <t>-ins_count += ls_obj-ins_count.
        <t>-del_count += ls_obj-del_count.
        <t>-mod_count += ls_obj-mod_count.
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
      `tr.obj-row{cursor:pointer}` &&
      `tr.obj-row:hover td{background:#e8f0fb}` &&
      `.cr td{background:#f0f4f8;font-weight:bold}` &&
      `.mr td:nth-child(3){padding-left:24px}` &&
      `.nr{text-align:right}` &&
      `.gi{color:#27ae60}.gd{color:#e74c3c}.gm{color:#e67e22}`.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8">| &&
      |<style>{ lv_css }</style></head><body>|.

    " ── Header ──────────────────────────────────────────────────────
    result = result &&
      |<h2>&#128196;&nbsp;Code Review Report</h2>| &&
      |<p><b>Transport:</b>&nbsp;{ esc( i_korrnum ) }|.
    IF lv_korr_text IS NOT INITIAL.
      result = result && |&nbsp;&mdash;&nbsp;{ esc( lv_korr_text ) }|.
    ENDIF.
    result = result && |</p>|.

    " ── Authors table ───────────────────────────────────────────────
    IF lt_totals IS NOT INITIAL.
      result = result &&
        |<h3>Authors</h3>| &&
        |<table><tr><th>Author</th><th>Name</th>| &&
        |<th class="nr gi">+&nbsp;Ins</th>| &&
        |<th class="nr gm">&#126;&nbsp;Mod</th>| &&
        |<th class="nr gd">&#8722;&nbsp;Del</th></tr>|.
      LOOP AT lt_totals INTO DATA(ls_tot).
        result = result &&
          |<tr><td>{ esc( ls_tot-author ) }</td>| &&
          |<td>{ esc( ls_tot-author_name ) }</td>| &&
          |<td class="nr gi">{ ls_tot-ins_count }</td>| &&
          |<td class="nr gm">{ ls_tot-mod_count }</td>| &&
          |<td class="nr gd">{ ls_tot-del_count }</td></tr>|.
      ENDLOOP.
      result = result && |</table>|.
    ENDIF.

    " ── Changed objects table ────────────────────────────────────────
    " Sort: objects without class first, then class blocks.
    " Within a class: sections (CPUB→CPRO→CPRI→CINC→CDEF) before methods (METH).
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
      APPEND VALUE #( class_name = ls_s2-class_name
                      type_order = lv_ord
                      obj_name   = ls_s2-obj_name
                      idx        = sy-tabix ) TO lt_sort.
    ENDLOOP.
    SORT lt_sort BY class_name type_order obj_name.

    DATA lt_sorted_final TYPE zif_ave_acr_types=>ty_t_obj_stats.
    LOOP AT lt_sort INTO DATA(ls_ord).
      READ TABLE lt_sorted INTO DATA(ls_tmp) INDEX ls_ord-idx.
      APPEND ls_tmp TO lt_sorted_final.
    ENDLOOP.

    " Remove entries with no actual changes
    DELETE lt_sorted_final WHERE ins_count = 0 AND del_count = 0 AND mod_count = 0.

    " Render one table per class (empty class_name = programs/other)
    DATA lv_cur_class TYPE seoclsname VALUE '####'.
    DATA(lv_tbl_hdr) =
      |<table><tr>| &&
      |<th>Type</th><th>Object</th>| &&
      |<th>Author</th><th>Date</th><th>Time</th>| &&
      |<th class="nr gi">+</th>| &&
      |<th class="nr gm">&#126;</th>| &&
      |<th class="nr gd">&#8722;</th>| &&
      |<th class="nr">Approve</th>| &&
      |<th class="nr">%</th></tr>|.

    LOOP AT lt_sorted_final INTO ls_obj.
      IF ls_obj-class_name <> lv_cur_class.
        IF lv_cur_class <> '####'.
          result = result && |</table>|.
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

      " Compute approve stats for this object
      DATA(lv_obj_prefix) = |{ ls_obj-objtype }~{ ls_obj-obj_name }~|.
      DATA(lv_cp_pat) = lv_obj_prefix && `*`.
      DATA lv_appr TYPE i.
      CLEAR lv_appr.
      LOOP AT it_approved INTO DATA(lv_ak).
        IF lv_ak CP lv_cp_pat.
          lv_appr += 1.
        ENDIF.
      ENDLOOP.
      DATA lv_total_h      TYPE i.
      DATA lv_approve_cell TYPE string.
      DATA lv_pct_cell     TYPE string.
      DATA lv_pct          TYPE i.
      CLEAR: lv_total_h, lv_approve_cell, lv_pct_cell, lv_pct.
      lv_total_h = ls_obj-hunk_count.
      IF lv_total_h = 0.
        lv_approve_cell = `<td class="nr">—</td>`.
        lv_pct_cell     = `<td class="nr">—</td>`.
      ELSE.
        lv_pct = lv_appr * 100 / lv_total_h.
        IF lv_appr >= lv_total_h.
          lv_approve_cell = |<td class="nr gi" style="font-weight:bold">&#10003; { lv_appr }/{ lv_total_h }</td>|.
          lv_pct_cell     = |<td class="nr gi" style="font-weight:bold">{ lv_pct }%</td>|.
        ELSE.
          lv_approve_cell = |<td class="nr">{ lv_appr }/{ lv_total_h }</td>|.
          lv_pct_cell     = |<td class="nr">{ lv_pct }%</td>|.
        ENDIF.
      ENDIF.

      DATA(lv_ev_key) = |{ ls_obj-objtype }~{ ls_obj-obj_name }|.
      DATA(lv_tr_attr) =
        `class="obj-row" ` &&
        `ondblclick="window.location.href='sapevent:openobj~` &&
        lv_ev_key && `'"` &&
        ` title="Double-click to open diff"`.
      result = result &&
        |<tr { lv_tr_attr }>| &&
        |<td>{ esc( ls_obj-objtype ) }</td>| &&
        |<td>{ esc( ls_obj-obj_name ) }</td>| &&
        |<td>{ esc( ls_obj-author ) }</td>| &&
        |<td>{ lv_date }</td>| &&
        |<td>{ lv_time }</td>| &&
        |<td class="nr gi">{ ls_obj-ins_count }</td>| &&
        |<td class="nr gm">{ ls_obj-mod_count }</td>| &&
        |<td class="nr gd">{ ls_obj-del_count }</td>| &&
        lv_approve_cell && lv_pct_cell && `</tr>`.
    ENDLOOP.

    IF lv_cur_class <> '####'.
      result = result && |</table>|.
    ENDIF.

    result = result && |</body></html>|.
  ENDMETHOD.


  METHOD esc.
    result = escape( val = CONV string( iv_val ) format = cl_abap_format=>e_html_text ).
  ENDMETHOD.

ENDCLASS.
