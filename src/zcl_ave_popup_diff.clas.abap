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
      RETURNING VALUE(result) TYPE ty_t_diff.

    "! Inline char-level diff for a single line pair.
    "!   iv_side = 'B' → both sides inline (default)
    "!   iv_side = 'N' → only insertion highlighted (new side)
    "!   iv_side = 'O' → only deletion highlighted (old side)
    CLASS-METHODS char_diff_html
      IMPORTING iv_old        TYPE string
                iv_new        TYPE string
                iv_side       TYPE c DEFAULT 'N'
      RETURNING VALUE(result) TYPE string.

    "! True if iv_a and iv_b share a common non-whitespace prefix of >= 3 chars.
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
ENDCLASS.


CLASS zcl_ave_popup_diff IMPLEMENTATION.

  METHOD compute_diff.
    DATA(lv_nold) = lines( it_old ).
    DATA(lv_nnew) = lines( it_new ).

    " Build flat 2D DP table: (lv_nold+1) x (lv_nnew+1)
    DATA(lv_cols) = lv_nnew + 1.
    DATA(lv_rows) = lv_nold + 1.
    DATA lt_dp TYPE TABLE OF i.
    DATA(lv_size) = lv_rows * lv_cols.
    DO lv_size TIMES.
      APPEND 0 TO lt_dp.
    ENDDO.

    " Fill DP
    DATA(lo_progress) = NEW zcl_ave_progress(
      i_title = 'Computing diff' i_threshold_secs = 15 ).
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
    " Prefix/suffix approach: find common prefix, common suffix,
    " highlight only the changed middle fragment.
    " Strip trailing spaces only (source lines are padded to 255 chars);
    " internal/leading spaces must be preserved so whitespace-only changes are diffed.
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

    " Common prefix
    DATA(lv_pre) = 0.
    WHILE lv_pre < lv_lo AND lv_pre < lv_ln.
      IF lv_old_t+lv_pre(1) = lv_new_t+lv_pre(1).
        lv_pre += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.

    " Common suffix (not overlapping prefix)
    DATA(lv_suf) = 0.
    WHILE lv_suf < lv_lo - lv_pre AND lv_suf < lv_ln - lv_pre.
      DATA(lv_po) = lv_lo - 1 - lv_suf.
      DATA(lv_pn) = lv_ln - 1 - lv_suf.
      IF lv_old_t+lv_po(1) = lv_new_t+lv_pn(1).
        lv_suf += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.

    " Extract parts
    DATA(lv_prefix)    = COND string( WHEN lv_pre > 0       THEN lv_old_t+0(lv_pre)          ELSE `` ).
    DATA(lv_mid_o_len) = lv_lo - lv_pre - lv_suf.
    DATA(lv_mid_n_len) = lv_ln - lv_pre - lv_suf.
    DATA(lv_mid_o)     = COND string( WHEN lv_mid_o_len > 0 THEN lv_old_t+lv_pre(lv_mid_o_len) ELSE `` ).
    DATA(lv_mid_n)     = COND string( WHEN lv_mid_n_len > 0 THEN lv_new_t+lv_pre(lv_mid_n_len) ELSE `` ).
    DATA(lv_suf_pos)   = lv_pre + lv_mid_o_len.
    DATA(lv_suffix)    = COND string( WHEN lv_suf > 0       THEN lv_old_t+lv_suf_pos(lv_suf)   ELSE `` ).

    " HTML-escape all parts
    REPLACE ALL OCCURRENCES OF `&` IN lv_prefix WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_prefix WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_prefix WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF `&` IN lv_mid_o  WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_mid_o  WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_mid_o  WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF ` ` IN lv_mid_o  WITH `&nbsp;`.
    REPLACE ALL OCCURRENCES OF `&` IN lv_mid_n  WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_mid_n  WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_mid_n  WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF ` ` IN lv_mid_n  WITH `&nbsp;`.
    REPLACE ALL OCCURRENCES OF `&` IN lv_suffix WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_suffix WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_suffix WITH `&gt;`.

    " Styles with horizontal padding so even a single-space highlight is visible.
    " outline gives a clear edge for whitespace-only fragments.
    DATA(lv_del_style) = `background:#ffb3b3;color:#cc0000;` &&
                        `padding:0 2px;outline:1px solid #c66`.
    DATA(lv_ins_style) = `background:#afffaf;color:#006600;` &&
                        `padding:0 2px;outline:1px solid #6c6`.

    " Comment-out detection: if new line starts with * or " but old doesn't,
    " the code was commented out — show old fragment with strikethrough.
    IF lv_pre = 0
      AND strlen( lv_new_t ) > 0 AND strlen( lv_old_t ) > 0
      AND ( lv_new_t(1) = `*` OR lv_new_t(1) = `"` )
      AND lv_old_t(1) <> `*` AND lv_old_t(1) <> `"`.
      lv_del_style = lv_del_style && `;text-decoration:line-through`.
    ENDIF.

    result = lv_prefix.
    CASE iv_side.
      WHEN 'O'.
        IF lv_mid_o IS NOT INITIAL.
          result = result && |<span style="{ lv_del_style }">{ lv_mid_o }</span>|.
        ENDIF.
      WHEN 'N'.
        IF lv_mid_n IS NOT INITIAL.
          result = result && |<span style="{ lv_ins_style }">{ lv_mid_n }</span>|.
        ENDIF.
      WHEN OTHERS. " 'B': show deleted then inserted inline
        IF lv_mid_o IS NOT INITIAL.
          result = result && |<span style="{ lv_del_style }">{ lv_mid_o }</span>|.
        ENDIF.
        IF lv_mid_n IS NOT INITIAL.
          result = result && |<span style="{ lv_ins_style }">{ lv_mid_n }</span>|.
        ENDIF.
    ENDCASE.
    result = result && lv_suffix.
  ENDMETHOD.


  METHOD has_common_chars.
    " Returns true if iv_a and iv_b share a non-trivial common prefix or suffix.
    " Used to decide whether two changed lines are similar enough to pair.
    DATA lv_a TYPE string.
    DATA lv_b TYPE string.
    lv_a = iv_a.
    lv_b = iv_b.
    " Strip leading whitespace — common indentation must not count as "common prefix"
    WHILE strlen( lv_a ) > 0 AND substring( val = lv_a off = 0 len = 1 ) = ` `.
      lv_a = substring( val = lv_a off = 1 len = strlen( lv_a ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_b ) > 0 AND substring( val = lv_b off = 0 len = 1 ) = ` `.
      lv_b = substring( val = lv_b off = 1 len = strlen( lv_b ) - 1 ).
    ENDWHILE.
    " Strip trailing whitespace
    WHILE strlen( lv_a ) > 0 AND substring( val = lv_a off = strlen( lv_a ) - 1 len = 1 ) = ` `.
      lv_a = substring( val = lv_a off = 0 len = strlen( lv_a ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_b ) > 0 AND substring( val = lv_b off = strlen( lv_b ) - 1 len = 1 ) = ` `.
      lv_b = substring( val = lv_b off = 0 len = strlen( lv_b ) - 1 ).
    ENDWHILE.
    DATA(lv_la) = strlen( lv_a ).
    DATA(lv_lb) = strlen( lv_b ).
    IF lv_la = 0 OR lv_lb = 0.
      result = abap_false.
      RETURN.
    ENDIF.

    " Comment-out special case: one line starts with * or " and the other doesn't.
    " Strip the comment char (+ leading spaces) and check for >=3 common chars with the other line.
    DATA(lv_a_is_cmt) = boolc( lv_a(1) = `*` OR lv_a(1) = `"` ).
    DATA(lv_b_is_cmt) = boolc( lv_b(1) = `*` OR lv_b(1) = `"` ).
    IF lv_a_is_cmt <> lv_b_is_cmt.
      DATA lv_uncommented TYPE string.
      DATA lv_other TYPE string.
      IF lv_a_is_cmt = abap_true.
        lv_uncommented = lv_a+1.
        lv_other       = lv_b.
      ELSE.
        lv_uncommented = lv_b+1.
        lv_other       = lv_a.
      ENDIF.
      " Strip leading spaces from the de-commented side
      WHILE strlen( lv_uncommented ) > 0 AND lv_uncommented(1) = ` `.
        lv_uncommented = lv_uncommented+1.
      ENDWHILE.
      DATA lv_ccp TYPE i VALUE 0.
      WHILE lv_ccp < strlen( lv_uncommented ) AND lv_ccp < strlen( lv_other ).
        IF lv_uncommented+lv_ccp(1) = lv_other+lv_ccp(1).
          lv_ccp += 1.
        ELSE.
          EXIT.
        ENDIF.
      ENDWHILE.
      result = boolc( lv_ccp >= 3 ).
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
    " Require a real common prefix (>=3 chars). Suffix only reinforces but isn't enough alone.
    result = boolc( lv_cp >= 3 ).
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

    DATA lv_idx TYPE i VALUE 2.
    WHILE lv_idx <= lines( lt_vers ).
      DATA(ls_ver) = lt_vers[ lv_idx ].
      DATA(lt_cur_src) = zcl_ave_popup_data=>get_ver_source(
        i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno
        i_korrnum = ls_ver-korrnum i_author  = ls_ver-author
        i_datum   = ls_ver-datum   i_zeit    = ls_ver-zeit ).
      DATA(lt_diff) = compute_diff( it_old = lt_prev_src it_new = lt_cur_src ).

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

ENDCLASS.
