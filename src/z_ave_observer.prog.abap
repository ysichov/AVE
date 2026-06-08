*&---------------------------------------------------------------------*
*& Report Z_AVE_OBSERVER
*&---------------------------------------------------------------------*
*& Observes transport requests/tasks (E070/E071) released or changed in a
*& given date range and lets the user browse the source and version diff
*& of every workbench object they touched (PROG/REPS/CLAS/METH/CPRI/CPRO/CPUB).
*&
*& Self-contained: the version-reading, diff and HTML-render logic is ported
*& from the global zcl_ave_* classes into local classes of this program.
*&---------------------------------------------------------------------*
REPORT z_ave_observer.

PARAMETERS: p_from TYPE begda DEFAULT sy-datum,
            p_to   TYPE endda DEFAULT sy-datum.

*&---------------------------------------------------------------------*
*& Shared types
*&---------------------------------------------------------------------*
TYPES: BEGIN OF gty_diff_op,
         op   TYPE c LENGTH 1,   " '=' equal, '-' deleted, '+' inserted
         text TYPE string,
       END OF gty_diff_op,
       gty_t_diff TYPE STANDARD TABLE OF gty_diff_op WITH DEFAULT KEY.

TYPES: BEGIN OF gty_obj,
         idx      TYPE i,
         trkorr   TYPE trkorr,
         as4date  TYPE as4date,
         as4time  TYPE as4time,
         as4text  TYPE as4text,
         object   TYPE trobjtype,
         obj_name TYPE trobj_name,
         vrs_type TYPE versobjtyp,   " mapped VRSD object type ('' = no source)
         vrs_name TYPE versobjnam,   " mapped VRSD object name
       END OF gty_obj,
       gty_t_obj TYPE STANDARD TABLE OF gty_obj WITH DEFAULT KEY.

*&---------------------------------------------------------------------*
*& lcl_diff - line/char diff engine (ported from zcl_ave_popup_diff)
*&---------------------------------------------------------------------*
CLASS lcl_diff DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    "! Line-level delta between two source tables via RS_CMP_COMPUTE_DELTA.
    CLASS-METHODS compute_diff
      IMPORTING it_old        TYPE abaptxt255_tab
                it_new        TYPE abaptxt255_tab
      RETURNING VALUE(result) TYPE gty_t_diff.

    "! Inline char-level diff for a single old/new line pair.
    "!   iv_side = 'B' both, 'N' only insertion, 'O' only deletion.
    CLASS-METHODS char_diff_html
      IMPORTING iv_old        TYPE string
                iv_new        TYPE string
                iv_side       TYPE c DEFAULT 'B'
      RETURNING VALUE(result) TYPE string.

    "! True when two changed lines are similar enough to pair for inline diff.
    CLASS-METHODS has_common_chars
      IMPORTING iv_a          TYPE string
                iv_b          TYPE string
      RETURNING VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    CLASS-METHODS count_edit_runs
      IMPORTING iv_a TYPE string iv_b TYPE string
      RETURNING VALUE(result) TYPE i.
    CLASS-METHODS count_char_edit_runs
      IMPORTING iv_a TYPE string iv_b TYPE string
      RETURNING VALUE(result) TYPE i.
    CLASS-METHODS collapse_token_ops
      CHANGING ct_ops TYPE gty_t_diff.
ENDCLASS.

CLASS lcl_diff IMPLEMENTATION.

  METHOD compute_diff.
    DATA lt_old TYPE rswsourcet.
    DATA lt_new TYPE rswsourcet.
    LOOP AT it_old INTO DATA(ls_oi).
      APPEND CONV string( ls_oi ) TO lt_old.
    ENDLOOP.
    LOOP AT it_new INTO DATA(ls_ni).
      APPEND CONV string( ls_ni ) TO lt_new.
    ENDLOOP.

    DATA lt_delta TYPE TABLE OF rsedcresul.
    DATA ls_delta TYPE rsedcresul.

    CALL FUNCTION 'RS_CMP_COMPUTE_DELTA'
      EXPORTING
        compare_mode      = '1'
      TABLES
        text_tab1         = lt_old
        text_tab2         = lt_new
        text_tab_res      = lt_delta
      EXCEPTIONS
        parameter_invalid = 1
        OTHERS            = 2.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT lt_delta INTO ls_delta.
      IF ls_delta-flag1 = space AND ls_delta-flag2 = space.
        APPEND VALUE gty_diff_op( op = '=' text = CONV string( ls_delta-text1 ) ) TO result.
      ELSEIF ls_delta-line1 = 0.
        APPEND VALUE gty_diff_op( op = '-' text = CONV string( ls_delta-text2 ) ) TO result.
      ELSEIF ls_delta-line2 = 0.
        APPEND VALUE gty_diff_op( op = '+' text = CONV string( ls_delta-text1 ) ) TO result.
      ELSEIF ls_delta-flag1 = 'M' AND ls_delta-flag2 = 'M'.
        APPEND VALUE gty_diff_op( op = '-' text = CONV string( ls_delta-text2 ) ) TO result.
        APPEND VALUE gty_diff_op( op = '+' text = CONV string( ls_delta-text1 ) ) TO result.
      ELSE.
        APPEND VALUE gty_diff_op( op = '=' text = CONV string( ls_delta-text1 ) ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD char_diff_html.
    DATA lv_old_t TYPE string.
    DATA lv_new_t TYPE string.
    lv_old_t = iv_old.
    lv_new_t = iv_new.
    WHILE strlen( lv_old_t ) > 0 AND substring( val = lv_old_t off = strlen( lv_old_t ) - 1 len = 1 ) = ` `.
      lv_old_t = substring( val = lv_old_t off = 0 len = strlen( lv_old_t ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_new_t ) > 0 AND substring( val = lv_new_t off = strlen( lv_new_t ) - 1 len = 1 ) = ` `.
      lv_new_t = substring( val = lv_new_t off = 0 len = strlen( lv_new_t ) - 1 ).
    ENDWHILE.

    DATA(lv_lo) = strlen( lv_old_t ).
    DATA(lv_ln) = strlen( lv_new_t ).
    DATA(lv_cols) = lv_ln + 1.

    DATA lt_dp TYPE TABLE OF i.
    DATA(lv_size) = ( lv_lo + 1 ) * lv_cols.
    DO lv_size TIMES.
      APPEND 0 TO lt_dp.
    ENDDO.

    DATA lv_i TYPE i.
    DATA lv_j TYPE i.
    lv_i = 1.
    WHILE lv_i <= lv_lo.
      lv_j = 1.
      WHILE lv_j <= lv_ln.
        DATA(lv_cell) = lv_i * lv_cols + lv_j + 1.
        DATA(lv_off_o) = lv_i - 1.
        DATA(lv_off_n) = lv_j - 1.
        IF lv_old_t+lv_off_o(1) = lv_new_t+lv_off_n(1).
          DATA(lv_prev) = ( lv_i - 1 ) * lv_cols + ( lv_j - 1 ) + 1.
          lt_dp[ lv_cell ] = lt_dp[ lv_prev ] + 1.
        ELSE.
          DATA(lv_up)   = ( lv_i - 1 ) * lv_cols + lv_j + 1.
          DATA(lv_left) = lv_i * lv_cols + ( lv_j - 1 ) + 1.
          lt_dp[ lv_cell ] = COND i(
            WHEN lt_dp[ lv_up ] >= lt_dp[ lv_left ] THEN lt_dp[ lv_up ]
            ELSE lt_dp[ lv_left ] ).
        ENDIF.
        lv_j += 1.
      ENDWHILE.
      lv_i += 1.
    ENDWHILE.

    DATA lt_ops TYPE gty_t_diff.
    lv_i = lv_lo.
    lv_j = lv_ln.
    WHILE lv_i > 0 OR lv_j > 0.
      DATA(lv_off_bo) = lv_i - 1.
      DATA(lv_off_bn) = lv_j - 1.
      IF lv_i > 0 AND lv_j > 0 AND lv_old_t+lv_off_bo(1) = lv_new_t+lv_off_bn(1).
        INSERT VALUE gty_diff_op( op = '=' text = lv_old_t+lv_off_bo(1) ) INTO lt_ops INDEX 1.
        lv_i -= 1.
        lv_j -= 1.
      ELSEIF lv_j > 0.
        IF lv_i = 0.
          INSERT VALUE gty_diff_op( op = '+' text = lv_new_t+lv_off_bn(1) ) INTO lt_ops INDEX 1.
          lv_j -= 1.
        ELSEIF lt_dp[ lv_i * lv_cols + ( lv_j - 1 ) + 1 ] > lt_dp[ ( lv_i - 1 ) * lv_cols + lv_j + 1 ].
          INSERT VALUE gty_diff_op( op = '+' text = lv_new_t+lv_off_bn(1) ) INTO lt_ops INDEX 1.
          lv_j -= 1.
        ELSEIF lv_i > 0.
          INSERT VALUE gty_diff_op( op = '-' text = lv_old_t+lv_off_bo(1) ) INTO lt_ops INDEX 1.
          lv_i -= 1.
        ENDIF.
      ELSEIF lv_i > 0.
        INSERT VALUE gty_diff_op( op = '-' text = lv_old_t+lv_off_bo(1) ) INTO lt_ops INDEX 1.
        lv_i -= 1.
      ENDIF.
    ENDWHILE.

    collapse_token_ops( CHANGING ct_ops = lt_ops ).

    DATA(lv_del_style) = `background:#ffb3b3;color:#cc0000;padding:0 2px;outline:1px solid #c66`.
    DATA(lv_ins_style) = `background:#afffaf;color:#006600;padding:0 2px;outline:1px solid #6c6`.
    DATA lv_buf    TYPE string.
    DATA lv_buf_op TYPE c LENGTH 1.

    LOOP AT lt_ops INTO DATA(ls_part).
      IF lv_buf_op IS INITIAL OR ls_part-op = lv_buf_op.
        lv_buf = lv_buf && ls_part-text.
        lv_buf_op = ls_part-op.
        CONTINUE.
      ENDIF.

      DATA(lv_emit) = lv_buf.
      REPLACE ALL OCCURRENCES OF `&` IN lv_emit WITH `&amp;`.
      REPLACE ALL OCCURRENCES OF `<` IN lv_emit WITH `&lt;`.
      REPLACE ALL OCCURRENCES OF `>` IN lv_emit WITH `&gt;`.
      CASE lv_buf_op.
        WHEN '='.
          result = result && lv_emit.
        WHEN '-'.
          IF iv_side <> 'N'.
            DATA(lv_emit_cnd) = lv_emit.
            CONDENSE lv_emit_cnd.
            IF lv_emit_cnd IS NOT INITIAL.
              REPLACE ALL OCCURRENCES OF ` ` IN lv_emit WITH `&nbsp;`.
              result = result && |<span style="{ lv_del_style }">{ lv_emit }</span>|.
            ENDIF.
          ENDIF.
        WHEN '+'.
          IF iv_side <> 'O'.
            REPLACE ALL OCCURRENCES OF ` ` IN lv_emit WITH `&nbsp;`.
            result = result && |<span style="{ lv_ins_style }">{ lv_emit }</span>|.
          ENDIF.
      ENDCASE.

      lv_buf = ls_part-text.
      lv_buf_op = ls_part-op.
    ENDLOOP.

    IF lv_buf IS NOT INITIAL.
      DATA(lv_emit_last) = lv_buf.
      REPLACE ALL OCCURRENCES OF `&` IN lv_emit_last WITH `&amp;`.
      REPLACE ALL OCCURRENCES OF `<` IN lv_emit_last WITH `&lt;`.
      REPLACE ALL OCCURRENCES OF `>` IN lv_emit_last WITH `&gt;`.
      CASE lv_buf_op.
        WHEN '='.
          result = result && lv_emit_last.
        WHEN '-'.
          IF iv_side <> 'N'.
            DATA(lv_emit_last_cnd) = lv_emit_last.
            CONDENSE lv_emit_last_cnd.
            IF lv_emit_last_cnd IS NOT INITIAL.
              REPLACE ALL OCCURRENCES OF ` ` IN lv_emit_last WITH `&nbsp;`.
              result = result && |<span style="{ lv_del_style }">{ lv_emit_last }</span>|.
            ENDIF.
          ENDIF.
        WHEN '+'.
          IF iv_side <> 'O'.
            REPLACE ALL OCCURRENCES OF ` ` IN lv_emit_last WITH `&nbsp;`.
            result = result && |<span style="{ lv_ins_style }">{ lv_emit_last }</span>|.
          ENDIF.
      ENDCASE.
    ENDIF.
  ENDMETHOD.

  METHOD has_common_chars.
    DATA lv_a TYPE string.
    DATA lv_b TYPE string.
    lv_a = iv_a.
    lv_b = iv_b.
    WHILE strlen( lv_a ) > 0 AND substring( val = lv_a off = 0 len = 1 ) = ` `.
      lv_a = substring( val = lv_a off = 1 len = strlen( lv_a ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_b ) > 0 AND substring( val = lv_b off = 0 len = 1 ) = ` `.
      lv_b = substring( val = lv_b off = 1 len = strlen( lv_b ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_a ) > 0 AND substring( val = lv_a off = strlen( lv_a ) - 1 len = 1 ) = ` `.
      lv_a = substring( val = lv_a off = 0 len = strlen( lv_a ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_b ) > 0 AND substring( val = lv_b off = strlen( lv_b ) - 1 len = 1 ) = ` `.
      lv_b = substring( val = lv_b off = 0 len = strlen( lv_b ) - 1 ).
    ENDWHILE.

    DATA(lv_la) = strlen( lv_a ).
    DATA(lv_lb) = strlen( lv_b ).
    IF lv_la = 0 OR lv_lb = 0.
      result = abap_true.
      RETURN.
    ENDIF.
    IF lv_a = lv_b.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA lv_shorter TYPE string.
    DATA lv_longer  TYPE string.
    IF lv_la < lv_lb.
      lv_shorter = lv_a.
      lv_longer  = lv_b.
    ELSE.
      lv_shorter = lv_b.
      lv_longer  = lv_a.
    ENDIF.

    IF strlen( lv_shorter ) >= 3 AND lv_longer CS lv_shorter.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA lv_cp TYPE i VALUE 0.
    WHILE lv_cp < lv_la AND lv_cp < lv_lb.
      IF substring( val = lv_a off = lv_cp len = 1 ) =
         substring( val = lv_b off = lv_cp len = 1 ).
        lv_cp += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.
    IF lv_cp < 3. result = abap_false. RETURN. ENDIF.

    DATA(lv_min_len) = nmin( val1 = lv_la val2 = lv_lb ).
    IF lv_cp * 4 < lv_min_len. result = abap_false. RETURN. ENDIF.

    DATA lv_cs      TYPE i VALUE 0.
    DATA lv_la_rest TYPE i.
    DATA lv_lb_rest TYPE i.
    lv_la_rest = lv_la - lv_cp.
    lv_lb_rest = lv_lb - lv_cp.
    WHILE lv_cs < lv_la_rest AND lv_cs < lv_lb_rest.
      IF substring( val = lv_a off = lv_la - 1 - lv_cs len = 1 ) =
         substring( val = lv_b off = lv_lb - 1 - lv_cs len = 1 ).
        lv_cs += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.
    DATA lv_mid_a  TYPE string.
    DATA lv_mid_b  TYPE string.
    DATA(lv_mid_la) = lv_la - lv_cp - lv_cs.
    DATA(lv_mid_lb) = lv_lb - lv_cp - lv_cs.
    IF lv_mid_la > 0.
      lv_mid_a = substring( val = lv_a off = lv_cp len = lv_mid_la ).
    ENDIF.
    IF lv_mid_lb > 0.
      lv_mid_b = substring( val = lv_b off = lv_cp len = lv_mid_lb ).
    ENDIF.
    IF count_edit_runs( iv_a = lv_mid_a iv_b = lv_mid_b ) > 2.
      result = abap_false. RETURN.
    ENDIF.
    IF count_char_edit_runs( iv_a = lv_mid_a iv_b = lv_mid_b ) > 2.
      result = abap_false. RETURN.
    ENDIF.
    result = abap_true.
  ENDMETHOD.

  METHOD count_edit_runs.
    DATA lt_a       TYPE TABLE OF string.
    DATA lt_b       TYPE TABLE OF string.
    DATA lt_tmp     TYPE TABLE OF string.
    DATA lt_pair_ia TYPE TABLE OF i.
    DATA lt_pair_ib TYPE TABLE OF i.
    DATA lv_jstart  TYPE i.
    DATA lv_jb      TYPE i.
    DATA lv_ia      TYPE i.
    DATA lv_np      TYPE i.
    DATA lv_k       TYPE i.
    DATA lv_pia     TYPE i.
    DATA lv_pib     TYPE i.
    DATA lv_pia2    TYPE i.
    DATA lv_pib2    TYPE i.

    SPLIT iv_a AT ` ` INTO TABLE lt_a.
    SPLIT iv_b AT ` ` INTO TABLE lt_b.
    LOOP AT lt_a INTO DATA(lv_t). IF lv_t IS NOT INITIAL. APPEND lv_t TO lt_tmp. ENDIF. ENDLOOP.
    lt_a = lt_tmp. CLEAR lt_tmp.
    LOOP AT lt_b INTO lv_t. IF lv_t IS NOT INITIAL. APPEND lv_t TO lt_tmp. ENDIF. ENDLOOP.
    lt_b = lt_tmp.

    DATA(lv_na) = lines( lt_a ).
    DATA(lv_nb) = lines( lt_b ).
    IF lv_na = 0 AND lv_nb = 0. RETURN. ENDIF.
    IF lv_na = 0 OR  lv_nb = 0. result = 1. RETURN. ENDIF.

    lv_jstart = 1.
    DO lv_na TIMES.
      lv_ia = sy-index.
      lv_jb = lv_jstart.
      WHILE lv_jb <= lv_nb.
        IF lt_a[ lv_ia ] = lt_b[ lv_jb ].
          APPEND lv_ia TO lt_pair_ia.
          APPEND lv_jb TO lt_pair_ib.
          lv_jstart = lv_jb + 1.
          EXIT.
        ENDIF.
        lv_jb += 1.
      ENDWHILE.
    ENDDO.

    lv_np = lines( lt_pair_ia ).
    IF lv_np = 0. result = 1. RETURN. ENDIF.

    lv_pia = lt_pair_ia[ 1 ].
    lv_pib = lt_pair_ib[ 1 ].
    IF lv_pia > 1 OR lv_pib > 1. result += 1. ENDIF.
    DO lv_np - 1 TIMES.
      lv_k    = sy-index.
      lv_pia  = lt_pair_ia[ lv_k ].
      lv_pib  = lt_pair_ib[ lv_k ].
      lv_pia2 = lt_pair_ia[ lv_k + 1 ].
      lv_pib2 = lt_pair_ib[ lv_k + 1 ].
      IF lv_pia2 > lv_pia + 1 OR lv_pib2 > lv_pib + 1.
        result += 1.
      ENDIF.
    ENDDO.
    lv_pia = lt_pair_ia[ lv_np ].
    lv_pib = lt_pair_ib[ lv_np ].
    IF lv_pia < lv_na OR lv_pib < lv_nb. result += 1. ENDIF.
  ENDMETHOD.

  METHOD count_char_edit_runs.
    DATA(lv_la) = strlen( iv_a ).
    DATA(lv_lb) = strlen( iv_b ).
    IF lv_la = 0 AND lv_lb = 0.
      RETURN.
    ENDIF.
    IF lv_la = 0 OR lv_lb = 0.
      result = 1.
      RETURN.
    ENDIF.

    DATA(lv_cols) = lv_lb + 1.
    DATA lt_dp TYPE TABLE OF i.
    DATA(lv_size) = ( lv_la + 1 ) * lv_cols.
    DO lv_size TIMES.
      APPEND 0 TO lt_dp.
    ENDDO.

    DATA lv_i TYPE i.
    DATA lv_j TYPE i.
    lv_i = 1.
    WHILE lv_i <= lv_la.
      lv_j = 1.
      WHILE lv_j <= lv_lb.
        DATA(lv_cell) = lv_i * lv_cols + lv_j + 1.
        DATA(lv_off_a) = lv_i - 1.
        DATA(lv_off_b) = lv_j - 1.
        IF iv_a+lv_off_a(1) = iv_b+lv_off_b(1).
          DATA(lv_prev) = ( lv_i - 1 ) * lv_cols + ( lv_j - 1 ) + 1.
          lt_dp[ lv_cell ] = lt_dp[ lv_prev ] + 1.
        ELSE.
          DATA(lv_up)   = ( lv_i - 1 ) * lv_cols + lv_j + 1.
          DATA(lv_left) = lv_i * lv_cols + ( lv_j - 1 ) + 1.
          lt_dp[ lv_cell ] = COND i(
            WHEN lt_dp[ lv_up ] >= lt_dp[ lv_left ] THEN lt_dp[ lv_up ]
            ELSE lt_dp[ lv_left ] ).
        ENDIF.
        lv_j += 1.
      ENDWHILE.
      lv_i += 1.
    ENDWHILE.

    DATA lt_ops TYPE gty_t_diff.
    lv_i = lv_la.
    lv_j = lv_lb.
    WHILE lv_i > 0 OR lv_j > 0.
      DATA(lv_back_a) = lv_i - 1.
      DATA(lv_back_b) = lv_j - 1.
      IF lv_i > 0 AND lv_j > 0 AND iv_a+lv_back_a(1) = iv_b+lv_back_b(1).
        INSERT VALUE gty_diff_op( op = '=' text = iv_a+lv_back_a(1) ) INTO lt_ops INDEX 1.
        lv_i -= 1.
        lv_j -= 1.
      ELSEIF lv_j > 0.
        IF lv_i = 0.
          INSERT VALUE gty_diff_op( op = '+' text = iv_b+lv_back_b(1) ) INTO lt_ops INDEX 1.
          lv_j -= 1.
        ELSEIF lt_dp[ lv_i * lv_cols + ( lv_j - 1 ) + 1 ] > lt_dp[ ( lv_i - 1 ) * lv_cols + lv_j + 1 ].
          INSERT VALUE gty_diff_op( op = '+' text = iv_b+lv_back_b(1) ) INTO lt_ops INDEX 1.
          lv_j -= 1.
        ELSE.
          INSERT VALUE gty_diff_op( op = '-' text = iv_a+lv_back_a(1) ) INTO lt_ops INDEX 1.
          lv_i -= 1.
        ENDIF.
      ELSE.
        INSERT VALUE gty_diff_op( op = '-' text = iv_a+lv_back_a(1) ) INTO lt_ops INDEX 1.
        lv_i -= 1.
      ENDIF.
    ENDWHILE.

    DATA lv_in_edit TYPE abap_bool.
    LOOP AT lt_ops INTO DATA(ls_op).
      IF ls_op-op = '='.
        lv_in_edit = abap_false.
      ELSEIF lv_in_edit = abap_false.
        result += 1.
        lv_in_edit = abap_true.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD collapse_token_ops.
    DATA lt_result TYPE gty_t_diff.
    DATA lv_ts     TYPE i VALUE 1.
    DATA lv_te     TYPE i.
    DATA lv_tk     TYPE i.
    DATA lv_c0     TYPE string.
    DATA lv_cn     TYPE string.
    DATA lv_iw     TYPE abap_bool.
    DATA lv_iwn    TYPE abap_bool.
    DATA lv_opn    TYPE c LENGTH 1.
    DATA lv_dc     TYPE i.
    DATA lv_ic     TYPE i.
    DATA lv_ot     TYPE string.
    DATA lv_nt     TYPE string.
    DATA lv_opk    TYPE c LENGTH 1.
    DATA lv_ec     TYPE string.
    DATA lv_wch    TYPE string VALUE
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.
    DATA(lv_no) = lines( ct_ops ).
    WHILE lv_ts <= lv_no.
      lv_c0 = ct_ops[ lv_ts ]-text.
      lv_iw = xsdbool( lv_c0 CO lv_wch ).
      IF lv_iw = abap_false AND ct_ops[ lv_ts ]-op = '='.
        APPEND ct_ops[ lv_ts ] TO lt_result.
        lv_ts += 1.
        CONTINUE.
      ENDIF.
      lv_te = lv_ts.
      WHILE lv_te < lv_no.
        lv_cn  = ct_ops[ lv_te + 1 ]-text.
        lv_iwn = xsdbool( lv_cn CO lv_wch ).
        lv_opn = ct_ops[ lv_te + 1 ]-op.
        IF lv_opn <> '=' OR lv_iwn = abap_true.
          lv_te += 1.
        ELSE.
          EXIT.
        ENDIF.
      ENDWHILE.
      CLEAR: lv_dc, lv_ic, lv_ot, lv_nt.
      lv_tk = lv_ts.
      WHILE lv_tk <= lv_te.
        lv_opk = ct_ops[ lv_tk ]-op.
        lv_ec  = ct_ops[ lv_tk ]-text.
        CASE lv_opk.
          WHEN '-'.
            lv_ot = lv_ot && lv_ec.
            lv_dc += 1.
          WHEN '+'.
            lv_nt = lv_nt && lv_ec.
            lv_ic += 1.
          WHEN '='.
            lv_ot = lv_ot && lv_ec.
            lv_nt = lv_nt && lv_ec.
        ENDCASE.
        lv_tk += 1.
      ENDWHILE.
      IF lv_dc > 0 AND lv_ic > 0 AND lv_dc + lv_ic > 2.
        IF lv_ot IS NOT INITIAL.
          APPEND VALUE gty_diff_op( op = '-' text = lv_ot ) TO lt_result.
        ENDIF.
        IF lv_nt IS NOT INITIAL.
          APPEND VALUE gty_diff_op( op = '+' text = lv_nt ) TO lt_result.
        ENDIF.
      ELSE.
        lv_tk = lv_ts.
        WHILE lv_tk <= lv_te.
          APPEND ct_ops[ lv_tk ] TO lt_result.
          lv_tk += 1.
        ENDWHILE.
      ENDIF.
      lv_ts = lv_te + 1.
    ENDWHILE.
    ct_ops = lt_result.
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& lcl_src - version source/VRSD reader (ported from zcl_ave_version/vrsd)
*&---------------------------------------------------------------------*
CLASS lcl_src DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    "! Reads the VRSD version directory for one object (sorted ascending).
    CLASS-METHODS read_vrsd_list
      IMPORTING iv_type       TYPE versobjtyp
                iv_name       TYPE versobjnam
      RETURNING VALUE(result) TYPE vrsd_tab.

    "! Reads source for a given (internal) version number.
    CLASS-METHODS get_source
      IMPORTING iv_type       TYPE versobjtyp
                iv_name       TYPE versobjnam
                iv_versno     TYPE versno
      RETURNING VALUE(result) TYPE abaptxt255_tab.

    "! Reads the active source of a program/include.
    CLASS-METHODS get_active_source
      IMPORTING iv_type       TYPE versobjtyp
                iv_name       TYPE versobjnam
      RETURNING VALUE(result) TYPE abaptxt255_tab.
ENDCLASS.

CLASS lcl_src IMPLEMENTATION.

  METHOD read_vrsd_list.
    " Released versions from VRSD (joined to E070 to ignore orphans)
    SELECT v~* FROM vrsd AS v
      INNER JOIN e070 AS e ON e~trkorr = v~korrnum
      WHERE v~objtype = @iv_type
        AND v~objname = @iv_name
      ORDER BY v~versno
      INTO TABLE @result.

    " Supplement with the version directory (covers not-yet-released versions)
    DATA lt_dir46   TYPE vrsd_tab.
    DATA lt_lversno TYPE TABLE OF vrsn.
    CALL FUNCTION 'SVRS_GET_VERSION_DIRECTORY_46'
      EXPORTING
        objtype      = iv_type
        objname      = iv_name
      TABLES
        lversno_list = lt_lversno
        version_list = lt_dir46
      EXCEPTIONS
        no_entry     = 1
        OTHERS       = 2.
    IF sy-subrc = 0.
      LOOP AT lt_dir46 INTO DATA(ls_dir46).
        READ TABLE result WITH KEY versno = ls_dir46-versno TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          INSERT ls_dir46 INTO TABLE result.
        ENDIF.
      ENDLOOP.
    ENDIF.

    SORT result BY versno ASCENDING.
  ENDMETHOD.

  METHOD get_source.
    DATA lt_trdir TYPE trdir_it.
    CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
      EXPORTING
        object_name = iv_name
        object_type = iv_type
        versno      = iv_versno
      TABLES
        repos_tab   = result
        trdir_tab   = lt_trdir
      EXCEPTIONS
        no_version  = 1
        OTHERS      = 2.
    " subrc <> 0 -> empty source, not treated as error
  ENDMETHOD.

  METHOD get_active_source.
    " Active version is stored under internal versno 0
    result = get_source( iv_type = iv_type iv_name = iv_name iv_versno = 0 ).
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& lcl_html - HTML rendering (ported from zcl_ave_popup_html)
*&---------------------------------------------------------------------*
CLASS lcl_html DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    "! Builds the left navigation page: TR headers + object links.
    CLASS-METHODS build_nav
      IMPORTING it_objs       TYPE gty_t_obj
      RETURNING VALUE(result) TYPE string.

    "! Renders a unified (single-pane) diff page.
    CLASS-METHODS diff_to_html
      IMPORTING it_diff       TYPE gty_t_diff
                iv_title      TYPE string
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS esc
      IMPORTING iv_in         TYPE string
      RETURNING VALUE(result) TYPE string.

    "! Renders a buffered change block (deletions then insertions) into rows.
    CLASS-METHODS render_block
      CHANGING ct_del  TYPE gty_t_diff
               ct_ins  TYPE gty_t_diff
               cv_lo   TYPE i
               cv_ln   TYPE i
               cv_rows TYPE string.

    "! Loads an HTML string into a viewer.
    CLASS-METHODS show_html
      IMPORTING io_viewer TYPE REF TO cl_gui_html_viewer
                iv_html   TYPE string.
ENDCLASS.

CLASS lcl_html IMPLEMENTATION.

  METHOD esc.
    result = iv_in.
    REPLACE ALL OCCURRENCES OF `&` IN result WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN result WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN result WITH `&gt;`.
  ENDMETHOD.

  METHOD build_nav.
    DATA lv_body    TYPE string.
    DATA lv_curr_tr TYPE trkorr.

    LOOP AT it_objs INTO DATA(ls_o).
      IF ls_o-trkorr <> lv_curr_tr.
        lv_curr_tr = ls_o-trkorr.
        DATA(lv_dt) = |{ ls_o-as4date+6(2) }.{ ls_o-as4date+4(2) }.{ ls_o-as4date(4) }| &&
                      | { ls_o-as4time(2) }:{ ls_o-as4time+2(2) }:{ ls_o-as4time+4(2) }|.
        lv_body = lv_body &&
          |<div class="tr"><span class="trk">{ esc( CONV string( ls_o-trkorr ) ) }</span>| &&
          |<span class="trd">{ lv_dt }</span>| &&
          |<div class="trt">{ esc( CONV string( ls_o-as4text ) ) }</div></div>|.
      ENDIF.

      DATA(lv_label) = |{ ls_o-object } { esc( CONV string( ls_o-obj_name ) ) }|.
      IF ls_o-vrs_type IS INITIAL.
        " Object type without versioned source - show as plain text
        lv_body = lv_body && |<div class="obj"><span class="dim">{ lv_label }</span></div>|.
      ELSE.
        lv_body = lv_body &&
          |<div class="obj">| &&
          |<a href="sapevent:src?idx={ ls_o-idx }">{ lv_label }</a>| &&
          | <a class="diff" href="sapevent:diff?idx={ ls_o-idx }">[diff]</a>| &&
          |</div>|.
      ENDIF.
    ENDLOOP.

    IF lv_body IS INITIAL.
      lv_body = |<div class="empty">No transports with matching objects in the selected period.</div>|.
    ENDIF.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#fff;color:#1e1e1e;font:12px/1.5 Consolas,monospace;padding:6px\}| &&
      |.tr\{margin:10px 0 2px;padding:4px 6px;background:#eef3fa;| &&
           |border-left:3px solid #0066aa\}| &&
      |.trk\{color:#0066aa;font-weight:bold;margin-right:10px\}| &&
      |.trd\{color:#888\}| &&
      |.trt\{color:#444;margin-top:2px\}| &&
      |.obj\{padding:1px 6px 1px 18px\}| &&
      |.obj a\{color:#1a5fb4;text-decoration:none\}| &&
      |.obj a:hover\{text-decoration:underline\}| &&
      |.diff\{color:#a33;margin-left:8px\}| &&
      |.dim\{color:#aaa\}| &&
      |.empty\{color:#888;padding:20px\}| &&
      |</style></head><body>| && lv_body && |</body></html>|.
  ENDMETHOD.

  METHOD render_block.
    DATA(lv_max) = COND i( WHEN lines( ct_del ) > lines( ct_ins ) THEN lines( ct_del ) ELSE lines( ct_ins ) ).
    DATA lv_bi TYPE i.
    lv_bi = 1.
    WHILE lv_bi <= lv_max.
      DATA lv_dtxt  TYPE string.
      DATA lv_itxt  TYPE string.
      DATA lv_has_d TYPE abap_bool.
      DATA lv_has_i TYPE abap_bool.
      CLEAR: lv_dtxt, lv_itxt, lv_has_d, lv_has_i.
      IF lv_bi <= lines( ct_del ).
        lv_dtxt = ct_del[ lv_bi ]-text. lv_has_d = abap_true.
      ENDIF.
      IF lv_bi <= lines( ct_ins ).
        lv_itxt = ct_ins[ lv_bi ]-text. lv_has_i = abap_true.
      ENDIF.

      DATA(lv_pair) = COND abap_bool(
        WHEN lv_has_d = abap_true AND lv_has_i = abap_true
          AND lcl_diff=>has_common_chars( iv_a = lv_dtxt iv_b = lv_itxt ) = abap_true
        THEN abap_true ELSE abap_false ).

      IF lv_has_d = abap_true.
        cv_lo += 1.
        DATA(lv_dcell) = COND string(
          WHEN lv_pair = abap_true
          THEN lcl_diff=>char_diff_html( iv_old = lv_dtxt iv_new = lv_itxt iv_side = 'O' )
          ELSE esc( lv_dtxt ) ).
        cv_rows = cv_rows &&
          |<tr class="d"><td class="ln">{ cv_lo }</td><td class="ln"></td>| &&
          |<td class="cd">{ lv_dcell }</td></tr>|.
      ENDIF.
      IF lv_has_i = abap_true.
        cv_ln += 1.
        DATA(lv_icell) = COND string(
          WHEN lv_pair = abap_true
          THEN lcl_diff=>char_diff_html( iv_old = lv_dtxt iv_new = lv_itxt iv_side = 'N' )
          ELSE esc( lv_itxt ) ).
        cv_rows = cv_rows &&
          |<tr class="i"><td class="ln"></td><td class="ln">{ cv_ln }</td>| &&
          |<td class="cd">{ lv_icell }</td></tr>|.
      ENDIF.
      lv_bi += 1.
    ENDWHILE.
    CLEAR: ct_del, ct_ins.
  ENDMETHOD.

  METHOD diff_to_html.
    DATA lv_rows TYPE string.
    DATA lv_lo   TYPE i.   " old line number
    DATA lv_ln   TYPE i.   " new line number

    " Buffered change block: deletions then insertions, paired for inline diff
    DATA lt_del TYPE gty_t_diff.
    DATA lt_ins TYPE gty_t_diff.

    LOOP AT it_diff INTO DATA(ls_d).
      CASE ls_d-op.
        WHEN '-'.
          APPEND ls_d TO lt_del.
        WHEN '+'.
          APPEND ls_d TO lt_ins.
        WHEN '='.
          render_block( CHANGING ct_del = lt_del ct_ins = lt_ins
                                 cv_lo = lv_lo cv_ln = lv_ln cv_rows = lv_rows ).
          lv_lo += 1.
          lv_ln += 1.
          lv_rows = lv_rows &&
            |<tr><td class="ln">{ lv_lo }</td><td class="ln">{ lv_ln }</td>| &&
            |<td class="cd">{ esc( ls_d-text ) }</td></tr>|.
      ENDCASE.
    ENDLOOP.
    render_block( CHANGING ct_del = lt_del ct_ins = lt_ins
                           cv_lo = lv_lo cv_ln = lv_ln cv_rows = lv_rows ).

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#fff;color:#1e1e1e;font:12px/1.5 Consolas,monospace\}| &&
      |.hdr\{background:#f3f3f3;padding:5px 12px;border-bottom:1px solid #ddd;color:#0066aa;font-weight:bold\}| &&
      |table\{border-collapse:collapse;width:100%\}| &&
      |td.ln\{color:#aaa;text-align:right;padding:1px 8px;user-select:none;min-width:42px;| &&
             |border-right:1px solid #e0e0e0;white-space:nowrap;background:#fafafa\}| &&
      |td.cd\{padding:1px 8px;white-space:pre\}| &&
      |tr.d td.cd\{background:#ffecec\}| &&
      |tr.i td.cd\{background:#eaffea\}| &&
      |tr.d td.ln\{background:#ffdede\}| &&
      |tr.i td.ln\{background:#deffde\}| &&
      |</style></head><body>| &&
      |<div class="hdr">{ esc( iv_title ) }</div>| &&
      |<table><tbody>{ lv_rows }</tbody></table></body></html>|.
  ENDMETHOD.

  METHOD show_html.
    CHECK io_viewer IS BOUND.
    DATA lt_html TYPE w3htmltab.
    DATA lv_url TYPE w3url.
    DATA lv_offset TYPE i.
    DATA(lv_len) = strlen( iv_html ).
    DATA lv_chunk TYPE i.
    WHILE lv_offset < lv_len.
      lv_chunk = COND #( WHEN lv_len - lv_offset > 255 THEN 255 ELSE lv_len - lv_offset ).
      APPEND VALUE #( line = iv_html+lv_offset(lv_chunk) ) TO lt_html.
      lv_offset += lv_chunk.
    ENDWHILE.
    io_viewer->load_data(
      IMPORTING assigned_url = lv_url
      CHANGING  data_table   = lt_html
      EXCEPTIONS OTHERS      = 1 ).
    CHECK sy-subrc = 0.
    io_viewer->show_url( url = lv_url ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& lcl_app - selection, layout, event handling
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS run
      IMPORTING iv_from TYPE begda
                iv_to   TYPE endda.

  PRIVATE SECTION.
    DATA mt_objs    TYPE gty_t_obj.
    DATA mo_box     TYPE REF TO cl_gui_dialogbox_container.
    DATA mo_split   TYPE REF TO cl_gui_splitter_container.
    DATA mo_rsplit  TYPE REF TO cl_gui_splitter_container.
    DATA mo_nav     TYPE REF TO cl_gui_html_viewer.
    DATA mo_editor  TYPE REF TO cl_gui_abapedit.
    DATA mo_diff    TYPE REF TO cl_gui_html_viewer.

    METHODS collect_objects
      IMPORTING iv_from TYPE begda
                iv_to   TYPE endda.

    METHODS map_to_vrsd
      IMPORTING iv_object   TYPE trobjtype
                iv_obj_name TYPE trobj_name
      EXPORTING ev_type     TYPE versobjtyp
                ev_name     TYPE versobjnam.

    METHODS build_layout.
    METHODS show_source IMPORTING is_obj TYPE gty_obj.
    METHODS show_diff   IMPORTING is_obj TYPE gty_obj.
    METHODS show_right_source.
    METHODS show_right_diff.

    METHODS on_sapevent
      FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING action getdata.

    METHODS on_box_close
      FOR EVENT close OF cl_gui_dialogbox_container.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.

  METHOD run.
    collect_objects( iv_from = iv_from iv_to = iv_to ).
    build_layout( ).
    lcl_html=>show_html( io_viewer = mo_nav iv_html = lcl_html=>build_nav( mt_objs ) ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  METHOD map_to_vrsd.
    CLEAR: ev_type, ev_name.
    CASE iv_object.
      WHEN 'PROG' OR 'REPS'.
        ev_type = 'REPS'.
        ev_name = iv_obj_name.
      WHEN 'METH' OR 'CPRI' OR 'CPRO' OR 'CPUB'.
        " E071 object name already matches the VRSD version object name
        ev_type = iv_object.
        ev_name = iv_obj_name.
      WHEN OTHERS.
        " CLAS (whole class) and anything else: no single versioned source
    ENDCASE.
  ENDMETHOD.

  METHOD collect_objects.
    " All E070 requests/tasks changed/released in the period (any TRFUNCTION)
    SELECT h~trkorr, h~as4date, h~as4time, t~as4text
      FROM e070 AS h
      LEFT JOIN e07t AS t
        ON t~trkorr = h~trkorr AND t~langu = @sy-langu
      WHERE h~as4date BETWEEN @iv_from AND @iv_to
        AND h~trfunction IN ( 'S', 'R' )
      ORDER BY h~as4date DESCENDING, h~as4time DESCENDING, h~trkorr DESCENDING
      INTO TABLE @DATA(lt_tr).

    IF lt_tr IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_idx TYPE i.
    LOOP AT lt_tr INTO DATA(ls_tr).
      SELECT pgmid, object, obj_name
        FROM e071
        WHERE trkorr = @ls_tr-trkorr
          AND object IN ( 'PROG', 'REPS', 'CLAS', 'METH', 'CPRI', 'CPRO', 'CPUB' )
        ORDER BY object, obj_name
        INTO TABLE @DATA(lt_e071).

      LOOP AT lt_e071 INTO DATA(ls_e071).
        lv_idx += 1.
        DATA ls_o TYPE gty_obj.
        CLEAR ls_o.
        ls_o-idx      = lv_idx.
        ls_o-trkorr   = ls_tr-trkorr.
        ls_o-as4date  = ls_tr-as4date.
        ls_o-as4time  = ls_tr-as4time.
        ls_o-as4text  = ls_tr-as4text.
        ls_o-object   = ls_e071-object.
        ls_o-obj_name = ls_e071-obj_name.
        map_to_vrsd(
          EXPORTING iv_object   = ls_e071-object
                    iv_obj_name = ls_e071-obj_name
          IMPORTING ev_type     = ls_o-vrs_type
                    ev_name     = ls_o-vrs_name ).
        APPEND ls_o TO mt_objs.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_layout.
    CREATE OBJECT mo_box
      EXPORTING
        width    = 1300
        height   = 600
        top      = 20
        left     = 30
        caption  = |Observer { p_from DATE = USER } - { p_to DATE = USER }|
        lifetime = cl_gui_control=>lifetime_dynpro
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    SET HANDLER me->on_box_close FOR mo_box.

    " Vertical splitter: left navigation | right viewer
    mo_split = NEW cl_gui_splitter_container(
      parent  = mo_box
      rows    = 1
      columns = 2 ).
    mo_split->set_column_width( id = 1 width = 40 ).
    mo_split->set_column_width( id = 2 width = 60 ).

    DATA(lo_left)  = mo_split->get_container( row = 1 column = 1 ).
    DATA(lo_right) = mo_split->get_container( row = 1 column = 2 ).

    " Left: navigation HTML
    mo_nav = NEW cl_gui_html_viewer( parent = lo_left ).
    DATA lt_ev TYPE cntl_simple_events.
    APPEND VALUE #( eventid = cl_gui_html_viewer=>m_id_sapevent appl_event = abap_true ) TO lt_ev.
    mo_nav->set_registered_events( lt_ev ).
    SET HANDLER me->on_sapevent FOR mo_nav.

    " Right: nested splitter - row1 source editor, row2 diff HTML (toggled)
    mo_rsplit = NEW cl_gui_splitter_container(
      parent  = lo_right
      rows    = 2
      columns = 1 ).
    mo_rsplit->set_row_height( id = 1 height = 100 ).
    mo_rsplit->set_row_height( id = 2 height = 0 ).

    mo_editor = NEW cl_gui_abapedit( parent = mo_rsplit->get_container( row = 1 column = 1 ) ).
    mo_editor->create_document( ).
    mo_editor->set_readonly_mode( 1 ).

    mo_diff = NEW cl_gui_html_viewer( parent = mo_rsplit->get_container( row = 2 column = 1 ) ).

    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  METHOD show_right_source.
    mo_rsplit->set_row_height( id = 1 height = 100 ).
    mo_rsplit->set_row_height( id = 2 height = 0 ).
  ENDMETHOD.

  METHOD show_right_diff.
    mo_rsplit->set_row_height( id = 1 height = 0 ).
    mo_rsplit->set_row_height( id = 2 height = 100 ).
  ENDMETHOD.

  METHOD show_source.
    DATA(lt_src) = lcl_src=>get_active_source(
      iv_type = is_obj-vrs_type
      iv_name = is_obj-vrs_name ).

    DATA lt_str TYPE STANDARD TABLE OF char255.
    LOOP AT lt_src INTO DATA(ls_l).
      APPEND CONV char255( ls_l ) TO lt_str.
    ENDLOOP.

    mo_editor->set_text( table = lt_str ).
    show_right_source( ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  METHOD show_diff.
    " Find the version that belongs to this transport, and its predecessor.
    DATA(lt_vrsd) = lcl_src=>read_vrsd_list(
      iv_type = is_obj-vrs_type
      iv_name = is_obj-vrs_name ).

    " Target version: korrnum = this TR; fallback to newest version not after the
    " TR change date/time.
    DATA lv_target TYPE versno.
    DATA lv_found  TYPE abap_bool.
    LOOP AT lt_vrsd INTO DATA(ls_v) WHERE korrnum = is_obj-trkorr.
      lv_target = ls_v-versno.
      lv_found  = abap_true.
    ENDLOOP.
    IF lv_found = abap_false.
      LOOP AT lt_vrsd INTO ls_v.
        IF ls_v-datum < is_obj-as4date
           OR ( ls_v-datum = is_obj-as4date AND ls_v-zeit <= is_obj-as4time ).
          lv_target = ls_v-versno.
          lv_found  = abap_true.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF lv_found = abap_false.
      " No matching version - fall back to active source
      show_source( is_obj ).
      RETURN.
    ENDIF.

    " Predecessor = highest versno strictly below target
    DATA lv_prev TYPE versno.
    DATA lv_has_prev TYPE abap_bool.
    LOOP AT lt_vrsd INTO ls_v WHERE versno < lv_target.
      lv_prev = ls_v-versno.
      lv_has_prev = abap_true.
    ENDLOOP.

    DATA(lt_new) = lcl_src=>get_source(
      iv_type = is_obj-vrs_type iv_name = is_obj-vrs_name iv_versno = lv_target ).
    DATA lt_old TYPE abaptxt255_tab.
    IF lv_has_prev = abap_true.
      lt_old = lcl_src=>get_source(
        iv_type = is_obj-vrs_type iv_name = is_obj-vrs_name iv_versno = lv_prev ).
    ENDIF.

    DATA(lt_diff) = lcl_diff=>compute_diff( it_old = lt_old it_new = lt_new ).
    DATA(lv_title) = |{ is_obj-object } { is_obj-obj_name } - { is_obj-trkorr }| &&
                     COND string( WHEN lv_has_prev = abap_true
                                  THEN | (v{ lv_prev } -> v{ lv_target }) |
                                  ELSE | (new object) | ).
    DATA(lv_html) = lcl_html=>diff_to_html( it_diff = lt_diff iv_title = lv_title ).
    lcl_html=>show_html( io_viewer = mo_diff iv_html = lv_html ).
    show_right_diff( ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  METHOD on_sapevent.
    " getdata looks like "idx=NN"
    DATA lv_idx TYPE i.
    DATA lv_val TYPE string.
    SPLIT getdata AT '=' INTO DATA(lv_key) lv_val.
    lv_idx = lv_val.
    READ TABLE mt_objs INTO DATA(ls_obj) WITH KEY idx = lv_idx.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE action.
      WHEN 'src'.
        show_source( ls_obj ).
      WHEN 'diff'.
        show_diff( ls_obj ).
    ENDCASE.
  ENDMETHOD.

  METHOD on_box_close.
    mo_box->free( EXCEPTIONS OTHERS = 1 ).
    CLEAR: mo_box, mo_split, mo_rsplit, mo_nav, mo_editor, mo_diff.
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Events
*&---------------------------------------------------------------------*
DATA go_app TYPE REF TO lcl_app.

AT SELECTION-SCREEN.
  " Open the observer popup only on plain Enter (no other command)
  CHECK sy-ucomm IS INITIAL.
  go_app = NEW lcl_app( ).
  go_app->run( iv_from = p_from iv_to = p_to ).
