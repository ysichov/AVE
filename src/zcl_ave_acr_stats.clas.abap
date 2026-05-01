CLASS zcl_ave_acr_stats DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Compute ins/del/mod counts from a diff, mirroring the pairing logic of diff_to_html.
    "! When it_blame is supplied, also builds per-author contribution in et_authors.
    CLASS-METHODS from_diff
      IMPORTING it_diff    TYPE zif_ave_popup_types=>ty_t_diff
                it_blame   TYPE zif_ave_popup_types=>ty_blame_map OPTIONAL
      EXPORTING ev_ins     TYPE i
                ev_del     TYPE i
                ev_mod     TYPE i
                et_authors TYPE zif_ave_acr_types=>ty_t_author_stats.

  PRIVATE SECTION.
    CLASS-METHODS add_blame
      IMPORTING iv_text    TYPE string
                iv_op      TYPE c   " '+' = ins, '~' = mod
                it_blame   TYPE zif_ave_popup_types=>ty_blame_map
      CHANGING  ct_authors TYPE zif_ave_acr_types=>ty_t_author_stats.

ENDCLASS.


CLASS zcl_ave_acr_stats IMPLEMENTATION.

  METHOD from_diff.
    CLEAR ev_ins. CLEAR ev_del. CLEAR ev_mod. CLEAR et_authors.

    DATA lt_dels TYPE string_table.
    DATA lt_ins  TYPE string_table.

    " Append sentinel '=' to flush the last change block
    DATA lt_ops TYPE zif_ave_popup_types=>ty_t_diff.
    lt_ops = it_diff.
    APPEND VALUE #( op = '=' ) TO lt_ops.

    LOOP AT lt_ops INTO DATA(ls).
      CASE ls-op.
        WHEN '-'.
          APPEND CONV string( ls-text ) TO lt_dels.
        WHEN '+'.
          APPEND CONV string( ls-text ) TO lt_ins.
        WHEN '='.
          CHECK lt_dels IS NOT INITIAL OR lt_ins IS NOT INITIAL.

          " Parallel flag table: which ins lines have been matched already
          DATA lt_ins_matched TYPE STANDARD TABLE OF abap_bool WITH DEFAULT KEY.
          CLEAR lt_ins_matched.
          DO lines( lt_ins ) TIMES.
            APPEND abap_false TO lt_ins_matched.
          ENDDO.

          " Greedy pairing: for each del, find first unmatched ins with has_common_chars
          LOOP AT lt_dels INTO DATA(lv_d).
            DATA lv_paired TYPE abap_bool.
            lv_paired = abap_false.
            LOOP AT lt_ins INTO DATA(lv_i).
              DATA(lv_ii) = sy-tabix.
              ASSIGN lt_ins_matched[ lv_ii ] TO FIELD-SYMBOL(<m>).
              CHECK <m> = abap_false.
              IF zcl_ave_popup_diff=>has_common_chars( iv_a = lv_d iv_b = lv_i ) = abap_true.
                ev_mod += 1.
                <m> = abap_true.
                lv_paired = abap_true.
                IF it_blame IS SUPPLIED.
                  add_blame( iv_text = lv_i iv_op = '~' it_blame = it_blame CHANGING ct_authors = et_authors ).
                ENDIF.
                EXIT.
              ENDIF.
            ENDLOOP.
            IF lv_paired = abap_false.
              ev_del += 1.
            ENDIF.
          ENDLOOP.

          " Unmatched ins lines
          LOOP AT lt_ins INTO lv_i.
            lv_ii = sy-tabix.
            ASSIGN lt_ins_matched[ lv_ii ] TO <m>.
            CHECK <m> = abap_false.
            ev_ins += 1.
            IF it_blame IS SUPPLIED.
              add_blame( iv_text = lv_i iv_op = '+' it_blame = it_blame CHANGING ct_authors = et_authors ).
            ENDIF.
          ENDLOOP.

          CLEAR lt_dels. CLEAR lt_ins. CLEAR lt_ins_matched.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_blame.
    READ TABLE it_blame INTO DATA(ls_b) WITH KEY text = iv_text.
    CHECK sy-subrc = 0.
    READ TABLE ct_authors ASSIGNING FIELD-SYMBOL(<a>) WITH KEY author = ls_b-author.
    IF sy-subrc <> 0.
      INSERT VALUE #( author = ls_b-author author_name = ls_b-author_name )
        INTO TABLE ct_authors.
      READ TABLE ct_authors ASSIGNING <a> WITH KEY author = ls_b-author.
    ENDIF.
    CASE iv_op.
      WHEN '+'. <a>-ins_count += 1.
      WHEN '~'. <a>-mod_count += 1.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
