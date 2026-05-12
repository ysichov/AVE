CLASS zcl_ave_acr_overview DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS has_saved_stat
      IMPORTING
        is_part       TYPE zif_ave_popup_types=>ty_part_row
        it_obj_stats  TYPE zif_ave_acr_types=>ty_t_obj_stats
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS build_tr_task_popup_html
      IMPORTING
        iv_objtype           TYPE versobjtyp
        iv_objname           TYPE versobjnam
        iv_outer_object_name TYPE string
        it_parts             TYPE zif_ave_popup_types=>ty_t_part_row
      RETURNING
        VALUE(result)        TYPE string.
ENDCLASS.


CLASS zcl_ave_acr_overview IMPLEMENTATION.

  METHOD has_saved_stat.
    result = xsdbool(
      line_exists( it_obj_stats[
        objtype = is_part-type obj_name = is_part-object_name ] ) ).

    IF result = abap_false AND is_part-type = 'CLAS'.
      DATA(lv_class_name) = CONV seoclsname( is_part-object_name ).
      LOOP AT it_obj_stats TRANSPORTING NO FIELDS
        WHERE class_name = lv_class_name.
        result = abap_true.
        EXIT.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD build_tr_task_popup_html.
    DATA ls_part TYPE zif_ave_popup_types=>ty_part_row.
    READ TABLE it_parts INTO ls_part
      WITH KEY type = iv_objtype object_name = iv_objname.

    DATA(lv_css) =
      `body{font:13px/1.5 Consolas,monospace;padding:14px 18px;background:#fff;color:#333}` &&
      `h3{margin:0 0 12px 0;color:#2c3e50}` &&
      `table{border-collapse:collapse;width:100%;font-size:12px}` &&
      `th{background:#3498db;color:#fff;padding:5px 8px;text-align:left}` &&
      `td{padding:4px 8px;border-bottom:1px solid #eee;white-space:nowrap}` &&
      `.muted{color:#777}`.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8">| &&
      |<style>{ lv_css }</style></head><body>| &&
      |<h3>TRs/Tasks - { escape( val = CONV string( iv_objtype ) format = cl_abap_format=>e_html_text ) } | &&
      |{ escape( val = CONV string( iv_objname ) format = cl_abap_format=>e_html_text ) }</h3>| &&
      |<table><tr><th>TR</th><th>Task</th><th>Author</th><th>Date</th><th>Time</th></tr>|.

    DATA lt_popup_tasks TYPE string_table.
    IF ls_part-requests IS NOT INITIAL.
      SPLIT ls_part-requests AT `,` INTO TABLE lt_popup_tasks.
    ELSEIF iv_outer_object_name IS NOT INITIAL.
      APPEND iv_outer_object_name TO lt_popup_tasks.
    ENDIF.

    DATA(lv_popup_rows) = 0.
    LOOP AT lt_popup_tasks INTO DATA(lv_popup_task).
      CONDENSE lv_popup_task.
      CHECK lv_popup_task IS NOT INITIAL.

      DATA(lv_popup_tr) = CONV trkorr( lv_popup_task ).
      DATA(lv_popup_author) = VALUE versuser( ).
      DATA(lv_popup_date) = VALUE as4date( ).
      DATA(lv_popup_time) = VALUE as4time( ).
      SELECT SINGLE strkorr, as4user, as4date, as4time FROM e070
        WHERE trkorr = @lv_popup_tr
        INTO (@DATA(lv_popup_parent), @lv_popup_author, @lv_popup_date, @lv_popup_time).
      IF sy-subrc = 0 AND lv_popup_parent IS NOT INITIAL.
        lv_popup_tr = lv_popup_parent.
      ENDIF.

      DATA(lv_popup_author_text) = CONV string( lv_popup_author ).
      DATA(lv_popup_author_name) = zcl_ave_popup_data=>get_user_name( lv_popup_author ).
      IF lv_popup_author_name IS NOT INITIAL.
        lv_popup_author_text = |{ lv_popup_author } { lv_popup_author_name }|.
      ENDIF.

      DATA(lv_popup_date_text) = CONV string( lv_popup_date ).
      IF lv_popup_date IS NOT INITIAL.
        lv_popup_date_text = |{ lv_popup_date_text+6(2) }.{ lv_popup_date_text+4(2) }.{ lv_popup_date_text+0(4) }|.
      ENDIF.
      DATA(lv_popup_time_text) = CONV string( lv_popup_time ).
      IF lv_popup_time IS NOT INITIAL.
        lv_popup_time_text = |{ lv_popup_time_text+0(2) }:{ lv_popup_time_text+2(2) }:{ lv_popup_time_text+4(2) }|.
      ENDIF.

      result = result &&
        |<tr><td>{ escape( val = CONV string( lv_popup_tr ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = lv_popup_task format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = lv_popup_author_text format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = lv_popup_date_text format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = lv_popup_time_text format = cl_abap_format=>e_html_text ) }</td></tr>|.
      lv_popup_rows += 1.
    ENDLOOP.

    IF lv_popup_rows = 0.
      result = result && `<tr><td colspan="5" class="muted">No task data</td></tr>`.
    ENDIF.

    result = result && `</table></body></html>`.
  ENDMETHOD.

ENDCLASS.
