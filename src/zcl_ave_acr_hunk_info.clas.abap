CLASS zcl_ave_acr_hunk_info DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS collect
      IMPORTING
        is_part            TYPE zif_ave_popup_types=>ty_part_row
        it_diff            TYPE zif_ave_popup_types=>ty_t_diff
        it_hunk_html       TYPE string_table
        it_blame           TYPE zif_ave_popup_types=>ty_blame_map
        iv_author          TYPE versuser
        iv_display_name    TYPE string
        iv_versno_new      TYPE versno
        iv_versno_old      TYPE versno
        iv_versno_new_text TYPE string
        iv_versno_old_text TYPE string
        iv_is_created      TYPE abap_bool
        "! Requests in this object's own version history — see
        "! ZCL_AVE_ACR_PREPARE=>BLOCK_REQUEST_VERDICT.
        it_obj_korrnums    TYPE zif_ave_acr_types=>ty_t_korr_found OPTIONAL
      EXPORTING
        et_hunk_info       TYPE zif_ave_acr_types=>ty_t_hunk_info
        ev_hunk_count      TYPE i
        ev_hunk_ins        TYPE i
        ev_hunk_mod        TYPE i
        ev_hunk_del        TYPE i.

  PRIVATE SECTION.
    CLASS-METHODS has_visible_change
      IMPORTING
        iv_html        TYPE string
      RETURNING
        VALUE(result)  TYPE abap_bool.
ENDCLASS.


CLASS zcl_ave_acr_hunk_info IMPLEMENTATION.

  METHOD collect.
    CLEAR: et_hunk_info, ev_hunk_count, ev_hunk_ins, ev_hunk_mod, ev_hunk_del.

    DATA lv_hunk_html_idx TYPE i VALUE 0.
    DATA lv_in_hunk TYPE abap_bool VALUE abap_false.
    DATA lt_cur_hunk TYPE string_table.
    DATA lv_new_line TYPE i VALUE 0.
    DATA lv_hunk_line TYPE i.
    DATA lv_hunk_chg TYPE i.
    DATA lv_hunk_ins TYPE i.
    DATA lv_hunk_del TYPE i.
    DATA lv_hunk_auth TYPE versuser.
    " Lines of the current block per author. A block whose lines come from two
    " people still has to name one, and whoever wrote most of it is the only
    " defensible answer — see the pick where the block is closed.
    TYPES: BEGIN OF ty_auth_cnt,
             author TYPE versuser,
             lines  TYPE i,
           END OF ty_auth_cnt.
    DATA lt_hunk_auth_cnt TYPE STANDARD TABLE OF ty_auth_cnt WITH DEFAULT KEY.
    DATA lt_hunk_ins_lines TYPE string_table.
    DATA lt_hunk_del_lines TYPE string_table.

    " Comment control of the object, decided once for the whole part: is there
    " a change description at the top of it? Every block of the part carries the
    " answer — the mark belongs to the object, not to the block it is read from.
    DATA lv_obj_descr TYPE c LENGTH 1.
    lv_obj_descr = COND #(
      WHEN zcl_ave_acr_prepare=>comment_check_applies( is_part-type ) = abap_false
      THEN space
      WHEN zcl_ave_acr_prepare=>diff_has_change_descr( it_diff ) = abap_true
      THEN 'X' ELSE '-' ).

    DATA lt_ops TYPE zif_ave_popup_types=>ty_t_diff.
    lt_ops = it_diff.
    APPEND VALUE #( op = '=' ) TO lt_ops.

    LOOP AT lt_ops INTO DATA(ls_dop).
      CASE ls_dop-op.
        WHEN '+' OR '-'.
          IF lv_in_hunk = abap_false.
            lv_in_hunk = abap_true.
            CLEAR: lt_cur_hunk, lv_hunk_chg, lv_hunk_ins, lv_hunk_del, lv_hunk_auth,
                   lt_hunk_ins_lines, lt_hunk_del_lines, lt_hunk_auth_cnt.
            lv_hunk_line = lv_new_line + 1.
          ENDIF.
          lv_hunk_chg = lv_hunk_chg + 1.
          IF ls_dop-op = '+'.
            lv_hunk_ins = lv_hunk_ins + 1.
            APPEND CONV string( ls_dop-text ) TO lt_hunk_ins_lines.
            " KEEP (replaced): the first attributable line decided the whole block —
            "   IF lv_hunk_auth IS INITIAL AND it_blame IS NOT INITIAL.
            "     READ TABLE it_blame ... lv_hunk_auth = ls_hb-author.
            " A block opening with one developer's line and continuing with a
            " hundred lines of another was credited entirely to the first, so the
            " per-line row counts and the per-block counts disagreed: a developer
            " could show 108 rows and 0 blocks, and their developer page — which
            " lists blocks — came up empty.
            IF it_blame IS NOT INITIAL.
              READ TABLE it_blame INTO DATA(ls_hb) WITH KEY text = ls_dop-text.
              IF sy-subrc = 0 AND ls_hb-author IS NOT INITIAL.
                READ TABLE lt_hunk_auth_cnt ASSIGNING FIELD-SYMBOL(<auth_cnt>)
                  WITH KEY author = ls_hb-author.
                IF sy-subrc <> 0.
                  APPEND VALUE #( author = ls_hb-author ) TO lt_hunk_auth_cnt.
                  READ TABLE lt_hunk_auth_cnt ASSIGNING <auth_cnt>
                    WITH KEY author = ls_hb-author.
                ENDIF.
                <auth_cnt>-lines = <auth_cnt>-lines + 1.
              ENDIF.
            ENDIF.
            lv_new_line = lv_new_line + 1.
          ELSE.
            lv_hunk_del = lv_hunk_del + 1.
            APPEND CONV string( ls_dop-text ) TO lt_hunk_del_lines.
          ENDIF.
          APPEND CONV string( ls_dop-text ) TO lt_cur_hunk.
        WHEN OTHERS.
          IF lv_in_hunk = abap_true.
            IF ls_dop-op = '=' AND condense( val = ls_dop-text ) = ``.
              DATA(lv_dpeek_idx) = sy-tabix + 1.
              DATA(lv_dextra) = 0.
              DATA(lv_dmore_changes) = abap_false.
              WHILE lv_dpeek_idx <= lines( lt_ops ).
                READ TABLE lt_ops INTO DATA(ls_dpeek) INDEX lv_dpeek_idx.
                IF ls_dpeek-op = '-' OR ls_dpeek-op = '+'.
                  lv_dmore_changes = abap_true.
                  EXIT.
                ELSEIF ls_dpeek-op = '=' AND condense( val = ls_dpeek-text ) = `` AND lv_dextra < 1.
                  lv_dextra = lv_dextra + 1.
                  lv_dpeek_idx = lv_dpeek_idx + 1.
                  CONTINUE.
                ELSE.
                  EXIT.
                ENDIF.
              ENDWHILE.
              IF lv_dmore_changes = abap_true.
                APPEND CONV string( ls_dop-text ) TO lt_cur_hunk.
                lv_new_line = lv_new_line + 1.
                CONTINUE.
              ENDIF.
            ENDIF.

            IF zcl_ave_acr_stats=>is_blank_hunk( lt_cur_hunk ) = abap_false.
              lv_hunk_html_idx = lv_hunk_html_idx + 1.
              " Keep-note: the kind used to be decided by mere presence of '+'
              " and '-' in the hunk, which reported unrelated delete+insert
              " pairs as modifications and let the "Blocks ~" column exceed the
              " "Rows ~" column next to it. CLASSIFY_HUNK applies the pairing
              " rule of ZCL_AVE_ACR_STATS=>FROM_DIFF instead.
              "DATA(lv_hunk_kind) = COND string(
              "  WHEN lv_hunk_ins > 0 AND lv_hunk_del > 0 THEN `changed` … ).
              DATA(lv_hunk_kind) = zcl_ave_acr_stats=>classify_hunk(
                it_dels = lt_hunk_del_lines
                it_ins  = lt_hunk_ins_lines ).
              " Whoever wrote most of the block owns it.
              CLEAR lv_hunk_auth.
              DATA lv_auth_top TYPE i.
              CLEAR lv_auth_top.
              LOOP AT lt_hunk_auth_cnt INTO DATA(ls_auth_cnt).
                IF ls_auth_cnt-lines > lv_auth_top.
                  lv_auth_top  = ls_auth_cnt-lines.
                  lv_hunk_auth = ls_auth_cnt-author.
                ENDIF.
              ENDLOOP.

              " Blame decides whenever it has an answer, and IV_AUTHOR is only
              " the fallback for a line it could not attribute.
              " KEEP (replaced): a created object took IV_AUTHOR for every block —
              "   WHEN iv_is_created = abap_true THEN iv_author
              " which is wrong as soon as a second developer touches the object
              " inside the same request: blame knows who added which line, and
              " this threw that away and credited the whole object to one person.
              DATA(lv_info_author) = COND versuser(
                WHEN lv_hunk_auth IS NOT INITIAL THEN lv_hunk_auth
                ELSE iv_author ).
              DATA lv_info_html TYPE string.
              READ TABLE it_hunk_html INTO lv_info_html INDEX lv_hunk_html_idx.
              IF has_visible_change( lv_info_html ) = abap_true.
                ev_hunk_count = ev_hunk_count + 1.
                CASE lv_hunk_kind.
                  WHEN `added`.   ev_hunk_ins = ev_hunk_ins + 1.
                  WHEN `changed`. ev_hunk_mod = ev_hunk_mod + 1.
                  WHEN `deleted`. ev_hunk_del = ev_hunk_del + 1.
                ENDCASE.
                INSERT VALUE zif_ave_acr_types=>ty_hunk_info(
                  hunk_key        = |{ is_part-type }~{ is_part-object_name }~{ ev_hunk_count }|
                  objtype         = is_part-type
                  obj_name        = is_part-object_name
                  class_name      = CONV #( is_part-class )
                  display_name    = iv_display_name
                  hunk_no         = ev_hunk_count
                  start_line      = lv_hunk_line
                  change_count    = lv_hunk_chg
                  change_kind     = lv_hunk_kind
                  author          = lv_info_author
                  author_name     = zcl_ave_popup_data=>get_user_name( lv_info_author )
                  versno_new      = iv_versno_new
                  versno_old      = iv_versno_old
                  versno_new_text = iv_versno_new_text
                  versno_old_text = iv_versno_old_text
                  " Comment control: the block is judged on the lines it adds,
                  " which are the lines the developer wrote. A block that only
                  " deletes has no such line and fails — commenting the removed
                  " code out with the request number is what the rule asks for.
                  " Decided on every run, not only when P_CMTCHK is on: the
                  " scan costs a walk over the comments of the block, while
                  " making it conditional would mean that ticking the checkbox
                  " over an already prepared review shows nothing until every
                  " object has been computed again.
                  req_ref         = COND #(
                    WHEN zcl_ave_acr_prepare=>comment_check_applies( is_part-type ) = abap_false
                    THEN space
                    ELSE zcl_ave_acr_prepare=>block_request_verdict(
                           it_lines        = lt_hunk_ins_lines
                           it_obj_korrnums = it_obj_korrnums ) )
                  obj_descr       = lv_obj_descr
                  html            = lv_info_html )
                  INTO TABLE et_hunk_info.
              ENDIF.
            ENDIF.
            lv_in_hunk = abap_false.
            CLEAR: lt_cur_hunk, lv_hunk_chg, lv_hunk_ins, lv_hunk_del, lv_hunk_auth,
                   lt_hunk_ins_lines, lt_hunk_del_lines, lt_hunk_auth_cnt.
          ENDIF.
          lv_new_line = lv_new_line + 1.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD has_visible_change.
    result = boolc( iv_html CS `#ffb3b3`
                 OR iv_html CS `#afffaf`
                 OR iv_html CS `background:#ffecec`
                 OR iv_html CS `background:#eaffea` ).
  ENDMETHOD.
ENDCLASS.
