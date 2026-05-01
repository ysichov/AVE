CLASS zcl_ave_acr_report DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Build the Code Review Report HTML page from pre-computed object stats.
    CLASS-METHODS to_html
      IMPORTING it_obj_stats  TYPE zif_ave_acr_types=>ty_t_obj_stats
                i_korrnum     TYPE trkorr
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
    " Sort: objects without class first (by type+name), then class blocks
    " (class header row + its parts grouped together)
    DATA lt_sorted TYPE zif_ave_acr_types=>ty_t_obj_stats.
    lt_sorted = it_obj_stats.
    SORT lt_sorted BY class_name objtype obj_name.

    result = result &&
      |<h3>Changed Objects</h3>| &&
      |<table><tr>| &&
      |<th>Type</th><th>Class</th><th>Object</th>| &&
      |<th>Author</th><th>Date</th><th>Time</th>| &&
      |<th class="nr gi">+</th>| &&
      |<th class="nr gm">&#126;</th>| &&
      |<th class="nr gd">&#8722;</th></tr>|.

    LOOP AT lt_sorted INTO ls_obj.
      DATA(lv_row_css) = COND string(
        WHEN ls_obj-objtype = 'CLAS'       THEN ` class="cr"`
        WHEN ls_obj-class_name IS NOT INITIAL THEN ` class="mr"`
        ELSE `` ).

      " Format date/time for display
      DATA(lv_date) = CONV string( ls_obj-datum ).
      IF lv_date IS NOT INITIAL.
        lv_date = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }|.
      ENDIF.
      DATA(lv_time) = CONV string( ls_obj-zeit ).
      IF lv_time IS NOT INITIAL.
        lv_time = |{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.
      ENDIF.

      result = result &&
        |<tr{ lv_row_css }>| &&
        |<td>{ esc( ls_obj-objtype ) }</td>| &&
        |<td>{ esc( ls_obj-class_name ) }</td>| &&
        |<td>{ esc( ls_obj-obj_name ) }</td>| &&
        |<td>{ esc( ls_obj-author ) }</td>| &&
        |<td>{ lv_date }</td>| &&
        |<td>{ lv_time }</td>| &&
        |<td class="nr gi">{ ls_obj-ins_count }</td>| &&
        |<td class="nr gm">{ ls_obj-mod_count }</td>| &&
        |<td class="nr gd">{ ls_obj-del_count }</td></tr>|.
    ENDLOOP.

    result = result && |</table></body></html>|.
  ENDMETHOD.


  METHOD esc.
    result = escape( val = CONV string( iv_val ) format = cl_abap_format=>e_html_text ).
  ENDMETHOD.

ENDCLASS.
