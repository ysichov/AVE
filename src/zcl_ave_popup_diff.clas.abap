CLASS zcl_ave_popup_diff DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Type aliases from ZIF_AVE_POPUP_TYPES (defined there for standalone compatibility)
    TYPES ty_diff_op TYPE zif_ave_popup_types=>ty_diff_op.
    TYPES ty_t_diff  TYPE zif_ave_popup_types=>ty_t_diff.

    "! Line-level LCS diff between two source tables.
    CLASS-METHODS compute_diff
      IMPORTING it_old        TYPE abaptxt255_tab
                it_new        TYPE abaptxt255_tab
                i_title       TYPE csequence DEFAULT 'Computing diff'
      RETURNING VALUE(result) TYPE ty_t_diff.

    "! Inline char-level diff for a single line pair.
    "!   iv_side = 'B' → both sides inline (default)
    "!   iv_side = 'N' → only insertion highlighted (new side)
    "!   iv_side = 'O' → only deletion highlighted (old side)
    CLASS-METHODS char_diff_html
      IMPORTING iv_old        TYPE string
                iv_new        TYPE string
                iv_side       TYPE c DEFAULT 'B'
      RETURNING VALUE(result) TYPE string.

    "! True if iv_a and iv_b are similar enough for pairing in change blocks.
    "! Used by diff_to_html to decide whether two changed lines are similar enough to pair.
    CLASS-METHODS has_common_chars
      IMPORTING iv_a          TYPE string
                iv_b          TYPE string
      RETURNING VALUE(result) TYPE abap_bool.

    "! Build a blame map by replaying diffs between consecutive versions in
    "! [i_from, i_to] for (i_objtype, i_objname). For every '+' line the current
    "! version's author is recorded; '-' lines go to et_blame_deleted.
    CLASS-METHODS build_blame_map
      IMPORTING it_versions      TYPE zif_ave_popup_types=>ty_t_version_row
                i_objtype        TYPE versobjtyp
                i_objname        TYPE versobjnam
                i_from           TYPE versno
                i_to             TYPE versno
      EXPORTING et_blame_deleted TYPE zif_ave_popup_types=>ty_blame_map
      RETURNING VALUE(result)    TYPE zif_ave_popup_types=>ty_blame_map.

  PRIVATE SECTION.
    CLASS-METHODS collapse_token_ops
      CHANGING ct_ops TYPE ty_t_diff.
ENDCLASS.


CLASS zcl_ave_popup_diff IMPLEMENTATION.

  METHOD compute_diff.
    DATA(lv_nold) = lines( it_old ).
    DATA(lv_nnew) = lines( it_new ).

    " Simplest possible diff for large files: two-pointer walk with a
    " short look-ahead window for resync. No hash maps, no DP matrix —
    " just the result table in memory. Handles "one line deleted, rest
    " identical" correctly (resync at k=1). Degrades to 1:1 substitution
    " if no match within lc_window steps.
    IF lv_nold > 10000 OR lv_nnew > 10000.
      CONSTANTS lc_window TYPE i VALUE 50.
      DATA(lo_p) = NEW zcl_ave_progress( i_title = i_title i_threshold_secs = 30 ).
      DATA lv_i1  TYPE i VALUE 1.
      DATA lv_j1  TYPE i VALUE 1.
      DATA lv_tot TYPE i.
      lv_tot = lv_nold + lv_nnew.

      WHILE lv_i1 <= lv_nold OR lv_j1 <= lv_nnew.
        IF lo_p->check( i_remaining = lv_tot - lv_i1 - lv_j1 + 2
                        i_total     = lv_tot ) = abap_true.
          RETURN.
        ENDIF.
        IF lv_i1 > lv_nold.
          APPEND VALUE ty_diff_op( op = '+' text = CONV string( it_new[ lv_j1 ] ) ) TO result.
          lv_j1 += 1.
          CONTINUE.
        ENDIF.
        IF lv_j1 > lv_nnew.
          APPEND VALUE ty_diff_op( op = '-' text = CONV string( it_old[ lv_i1 ] ) ) TO result.
          lv_i1 += 1.
          CONTINUE.
        ENDIF.
        IF it_old[ lv_i1 ] = it_new[ lv_j1 ].
          APPEND VALUE ty_diff_op( op = '=' text = CONV string( it_old[ lv_i1 ] ) ) TO result.
          lv_i1 += 1.
          lv_j1 += 1.
          CONTINUE.
        ENDIF.

        " Mismatch — probe forward up to lc_window steps to find resync.
        DATA lv_k    TYPE i.
        DATA lv_mode TYPE c.
        CLEAR lv_mode.
        lv_k = 1.
        WHILE lv_k <= lc_window.
          " old[i] appears at new[j+k]? → k inserts
          IF lv_j1 + lv_k <= lv_nnew AND it_new[ lv_j1 + lv_k ] = it_old[ lv_i1 ].
            lv_mode = '+'.
            EXIT.
          ENDIF.
          " new[j] appears at old[i+k]? → k deletes
          IF lv_i1 + lv_k <= lv_nold AND it_old[ lv_i1 + lv_k ] = it_new[ lv_j1 ].
            lv_mode = '-'.
            EXIT.
          ENDIF.
          lv_k += 1.
        ENDWHILE.

        IF lv_mode = '+'.
          DO lv_k TIMES.
            APPEND VALUE ty_diff_op( op = '+' text = CONV string( it_new[ lv_j1 ] ) ) TO result.
            lv_j1 += 1.
          ENDDO.
        ELSEIF lv_mode = '-'.
          DO lv_k TIMES.
            APPEND VALUE ty_diff_op( op = '-' text = CONV string( it_old[ lv_i1 ] ) ) TO result.
            lv_i1 += 1.
          ENDDO.
        ELSE.
          " No match within window — substitute 1:1 and advance both sides.
          APPEND VALUE ty_diff_op( op = '-' text = CONV string( it_old[ lv_i1 ] ) ) TO result.
          APPEND VALUE ty_diff_op( op = '+' text = CONV string( it_new[ lv_j1 ] ) ) TO result.
          lv_i1 += 1.
          lv_j1 += 1.
        ENDIF.
      ENDWHILE.
      RETURN.
    ENDIF.

    " Build flat 2D DP table: (lv_nold+1) x (lv_nnew+1)
    DATA(lv_cols) = lv_nnew + 1.
    DATA(lv_rows) = lv_nold + 1.
    DATA lt_dp TYPE TABLE OF i.
    DATA(lv_size) = lv_rows * lv_cols.
    DO lv_size TIMES.
      APPEND 0 TO lt_dp.
    ENDDO.

    " Fill DP
    DATA(lo_progress) = NEW zcl_ave_progress( i_title = i_title i_threshold_secs = 30 ).
    DATA lv_i TYPE i.
    DATA lv_j TYPE i.
    lv_i = 1.
    LOOP AT it_old INTO DATA(ls_old).
      IF lo_progress->check(
           i_remaining = lv_nold - lv_i + 1
           i_total     = lv_nold ) = abap_true.
        RETURN.
      ENDIF.
      lv_j = 1.
      LOOP AT it_new INTO DATA(ls_new).
        DATA(lv_cell) = lv_i * lv_cols + lv_j + 1.
        IF ls_old = ls_new.
          DATA(lv_prev) = ( lv_i - 1 ) * lv_cols + ( lv_j - 1 ) + 1.
          lt_dp[ lv_cell ] = lt_dp[ lv_prev ] + 1.
        ELSE.
          DATA(lv_up)   = ( lv_i - 1 ) * lv_cols + lv_j + 1.
          DATA(lv_left) = lv_i * lv_cols + ( lv_j - 1 ) + 1.
          DATA(lv_vup)   = lt_dp[ lv_up ].
          DATA(lv_vleft) = lt_dp[ lv_left ].
          lt_dp[ lv_cell ] = COND i( WHEN lv_vup >= lv_vleft THEN lv_vup ELSE lv_vleft ).
        ENDIF.
        lv_j += 1.
      ENDLOOP.
      lv_i += 1.
    ENDLOOP.

    " Backtrack to build diff ops (prepend into result).
    " Prefer deletion over insertion (cup > cleft) so '-' precedes '+'
    " in the same change block – keeps related pairs together.
    lv_i = lv_nold.
    lv_j = lv_nnew.
    WHILE lv_i > 0 OR lv_j > 0.
      IF lv_i > 0 AND lv_j > 0.
        READ TABLE it_old INTO DATA(ls_bo) INDEX lv_i.
        READ TABLE it_new INTO DATA(ls_bn) INDEX lv_j.
        IF ls_bo = ls_bn.
          INSERT VALUE ty_diff_op( op = '=' text = CONV string( ls_bn ) ) INTO result INDEX 1.
          lv_i -= 1.
          lv_j -= 1.
        ELSE.
          DATA(lv_cup)   = ( lv_i - 1 ) * lv_cols + lv_j + 1.
          DATA(lv_cleft) = lv_i * lv_cols + ( lv_j - 1 ) + 1.
          IF lt_dp[ lv_cup ] >= lt_dp[ lv_cleft ].
            INSERT VALUE ty_diff_op( op = '-' text = CONV string( ls_bo ) ) INTO result INDEX 1.
            lv_i -= 1.
          ELSE.
            INSERT VALUE ty_diff_op( op = '+' text = CONV string( ls_bn ) ) INTO result INDEX 1.
            lv_j -= 1.
          ENDIF.
        ENDIF.
      ELSEIF lv_i > 0.
        READ TABLE it_old INTO DATA(ls_bo2) INDEX lv_i.
        INSERT VALUE ty_diff_op( op = '-' text = CONV string( ls_bo2 ) ) INTO result INDEX 1.
        lv_i -= 1.
      ELSE.
        READ TABLE it_new INTO DATA(ls_bn2) INDEX lv_j.
        INSERT VALUE ty_diff_op( op = '+' text = CONV string( ls_bn2 ) ) INTO result INDEX 1.
        lv_j -= 1.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.


  METHOD char_diff_html.
    " Build char-level LCS ops and render grouped spans.
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
    DATA(lv_rows) = lv_lo + 1.

    DATA lt_dp TYPE TABLE OF i.
    DATA(lv_size) = lv_rows * lv_cols.
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

    DATA lt_ops TYPE ty_t_diff.
    lv_i = lv_lo.
    lv_j = lv_ln.
    WHILE lv_i > 0 OR lv_j > 0.
      DATA(lv_off_bo) = lv_i - 1.
      DATA(lv_off_bn) = lv_j - 1.
      IF lv_i > 0 AND lv_j > 0 AND lv_old_t+lv_off_bo(1) = lv_new_t+lv_off_bn(1).
        INSERT VALUE ty_diff_op( op = '=' text = lv_old_t+lv_off_bo(1) ) INTO lt_ops INDEX 1.
        lv_i -= 1.
        lv_j -= 1.
      ELSEIF lv_j > 0.
        IF lv_i = 0.
          INSERT VALUE ty_diff_op( op = '+' text = lv_new_t+lv_off_bn(1) ) INTO lt_ops INDEX 1.
          lv_j -= 1.
        ELSEIF lt_dp[ lv_i * lv_cols + ( lv_j - 1 ) + 1 ] > lt_dp[ ( lv_i - 1 ) * lv_cols + lv_j + 1 ].
          INSERT VALUE ty_diff_op( op = '+' text = lv_new_t+lv_off_bn(1) ) INTO lt_ops INDEX 1.
          lv_j -= 1.
        ELSEIF lv_i > 0.
          INSERT VALUE ty_diff_op( op = '-' text = lv_old_t+lv_off_bo(1) ) INTO lt_ops INDEX 1.
          lv_i -= 1.
        ENDIF.
      ELSEIF lv_i > 0.
        INSERT VALUE ty_diff_op( op = '-' text = lv_old_t+lv_off_bo(1) ) INTO lt_ops INDEX 1.
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
            REPLACE ALL OCCURRENCES OF ` ` IN lv_emit WITH `&nbsp;`.
            result = result && |<span style="{ lv_del_style }">{ lv_emit }</span>|.
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
            REPLACE ALL OCCURRENCES OF ` ` IN lv_emit_last WITH `&nbsp;`.
            result = result && |<span style="{ lv_del_style }">{ lv_emit_last }</span>|.
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
    " Mirrors hasCommonChars() in html_simulator/diff.js.
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

    DATA(lv_shifted) = COND string(
      WHEN strlen( lv_longer ) > 1 THEN substring( val = lv_longer off = 1 )
      ELSE `` ).
    IF lv_shifted = lv_shorter.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA(lv_tail) = lv_shifted.
    WHILE strlen( lv_tail ) > 0 AND lv_tail(1) = ` `.
      lv_tail = substring( val = lv_tail off = 1 len = strlen( lv_tail ) - 1 ).
    ENDWHILE.
    IF lv_tail = lv_shorter.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA lv_cp TYPE i VALUE 0.
    WHILE lv_cp < lv_la AND lv_cp < lv_lb.
      IF lv_a+lv_cp(1) = lv_b+lv_cp(1).
        lv_cp += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.
    result = boolc( ( lv_la <= 8 AND lv_lb <= 8 AND lv_cp >= 1 )
                 OR ( lv_cp >= 3 AND lv_cp * 2 >= lv_la AND lv_cp * 2 >= lv_lb ) ).
  ENDMETHOD.


  METHOD build_blame_map.
    " Filter versions for this object within [i_from, i_to] and order ascending
    DATA lt_vers TYPE zif_ave_popup_types=>ty_t_version_row.
    LOOP AT it_versions INTO DATA(ls_v)
      WHERE versno  >= i_from
        AND versno  <= i_to
        AND objtype  = i_objtype
        AND objname  = i_objname.
      APPEND ls_v TO lt_vers.
    ENDLOOP.
    SORT lt_vers BY versno ASCENDING datum ASCENDING zeit ASCENDING.
    IF lines( lt_vers ) < 2. RETURN. ENDIF.

    DATA lt_prev_src TYPE abaptxt255_tab.
    DATA(ls_first) = lt_vers[ 1 ].
    lt_prev_src = zcl_ave_popup_data=>get_ver_source(
      i_objtype = ls_first-objtype i_objname = ls_first-objname i_versno = ls_first-versno
      i_korrnum = ls_first-korrnum i_author  = ls_first-author
      i_datum   = ls_first-datum   i_zeit    = ls_first-zeit ).

    DATA(lv_total) = lines( lt_vers ) - 1.
    DATA lv_idx TYPE i VALUE 2.
    WHILE lv_idx <= lines( lt_vers ).
      DATA(lv_step) = lv_idx - 1.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = CONV i( lv_step * 100 / lv_total )
                  text       = CONV char70( |Computing blame ({ lv_step }/{ lv_total })| ).
      DATA(ls_ver) = lt_vers[ lv_idx ].
      DATA(lt_cur_src) = zcl_ave_popup_data=>get_ver_source(
        i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno
        i_korrnum = ls_ver-korrnum i_author  = ls_ver-author
        i_datum   = ls_ver-datum   i_zeit    = ls_ver-zeit ).
      DATA(lt_diff) = compute_diff(
        it_old  = lt_prev_src
        it_new  = lt_cur_src
        i_title = |Computing blame ({ lv_step }/{ lv_total })| ).

      LOOP AT lt_diff INTO DATA(ls_d).
        IF ls_d-op = '+'.
          DATA(lv_text) = ls_d-text.
          DELETE result WHERE text = lv_text.
          APPEND VALUE zif_ave_popup_types=>ty_blame_entry(
            text        = lv_text
            author      = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner ELSE ls_ver-author )
            author_name = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner_name ELSE ls_ver-author_name )
            datum       = ls_ver-datum
            zeit        = ls_ver-zeit
            versno_text = ls_ver-versno_text
            korrnum     = ls_ver-korrnum
            task        = ls_ver-task
            task_text   = ls_ver-korr_text
          ) TO result.
        ELSEIF ls_d-op = '-'.
          DELETE et_blame_deleted WHERE text = ls_d-text.
          APPEND VALUE zif_ave_popup_types=>ty_blame_entry(
            text        = ls_d-text
            author      = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner ELSE ls_ver-author )
            author_name = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner_name ELSE ls_ver-author_name )
            datum       = ls_ver-datum
            zeit        = ls_ver-zeit
            versno_text = ls_ver-versno_text
            korrnum     = ls_ver-korrnum
            task        = ls_ver-task
            task_text   = ls_ver-korr_text
          ) TO et_blame_deleted.
          DELETE result WHERE text = ls_d-text.
        ENDIF.
      ENDLOOP.

      lt_prev_src = lt_cur_src.
      lv_idx += 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD collapse_token_ops.
    " Collapse word tokens where both deletions AND insertions exist (>2 total)
    " into whole-token replace, rather than showing partial char-level matches.
    DATA lt_result TYPE ty_t_diff.
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
          APPEND VALUE ty_diff_op( op = '-' text = lv_ot ) TO lt_result.
        ENDIF.
        IF lv_nt IS NOT INITIAL.
          APPEND VALUE ty_diff_op( op = '+' text = lv_nt ) TO lt_result.
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
