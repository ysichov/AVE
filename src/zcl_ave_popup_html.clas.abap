CLASS zcl_ave_popup_html DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Type aliases from ZIF_AVE_POPUP_TYPES (defined there for standalone compatibility)
    TYPES ty_blame_entry TYPE zif_ave_popup_types=>ty_blame_entry.
    TYPES ty_blame_map   TYPE zif_ave_popup_types=>ty_blame_map.

    "! Format a source table as a stand-alone HTML page with line numbers.
    CLASS-METHODS source_to_html
      IMPORTING it_source     TYPE abaptxt255_tab
                i_title       TYPE string
                i_meta        TYPE string OPTIONAL
      RETURNING VALUE(rv_html) TYPE string.

    "! Render a diff (from ZCL_AVE_POPUP_DIFF) as an HTML page.
    CLASS-METHODS diff_to_html
      IMPORTING it_diff           TYPE zif_ave_popup_types=>ty_t_diff
                i_title           TYPE string
                i_meta            TYPE string OPTIONAL
                i_two_pane        TYPE abap_bool OPTIONAL
                i_compact         TYPE abap_bool OPTIONAL
                it_blame          TYPE ty_blame_map OPTIONAL
                it_blame_deleted  TYPE ty_blame_map OPTIONAL
      RETURNING VALUE(result)     TYPE string.

    "! Debug rendering of diff ops and pairing decisions.
    CLASS-METHODS debug_diff_html
      IMPORTING it_diff       TYPE zif_ave_popup_types=>ty_t_diff
                i_title       TYPE string
                i_meta        TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_ave_popup_html IMPLEMENTATION.

  METHOD source_to_html.
    DATA lv_rows TYPE string.
    DATA lv_lno  TYPE i.

    LOOP AT it_source INTO DATA(ls_src).
      lv_lno += 1.
      DATA(lv_line) = CONV string( ls_src ).
      REPLACE ALL OCCURRENCES OF `&` IN lv_line WITH `&amp;`.
      REPLACE ALL OCCURRENCES OF `<` IN lv_line WITH `&lt;`.
      REPLACE ALL OCCURRENCES OF `>` IN lv_line WITH `&gt;`.
      lv_rows = lv_rows &&
        |<tr><td class="ln">{ lv_lno }</td>| &&
        |<td class="cd">{ lv_line }</td></tr>|.
    ENDLOOP.

    rv_html =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#ffffff;color:#1e1e1e;font:12px/1.5 Consolas,monospace\}| &&
      |.hdr\{background:#f3f3f3;padding:5px 12px;border-bottom:1px solid #ddd;| &&
             |color:#444;font-size:11px;display:flex;gap:16px;flex-wrap:wrap\}| &&
      |.ttl\{color:#0066aa;font-weight:bold\}| &&
      |.meta\{color:#888\}| &&
      |table\{border-collapse:collapse;width:100%\}| &&
      |tr:hover td\{background:#f0f4fa\}| &&
      |.ln\{color:#aaa;text-align:right;padding:1px 10px 1px 5px;| &&
           |user-select:none;min-width:42px;border-right:1px solid #e0e0e0;| &&
           |white-space:nowrap;background:#fafafa\}| &&
      |.cd\{padding:1px 8px;white-space:pre\}| &&
      |</style></head><body>| &&
      |<div class="hdr">| &&
      |<span class="ttl">| && i_title && |</span>| &&
      |<span class="meta">| && i_meta  && |</span>| &&
      |</div>| &&
      |<table><tbody>| && lv_rows &&
      |</tbody></table></body></html>|.
  ENDMETHOD.


  METHOD diff_to_html.
    DATA lv_rows  TYPE string.
    DATA lv_lno   TYPE i.

    " Pre-compute which '=' lines to show in compact mode (within 3 of any change)
    CONSTANTS lc_ctx TYPE i VALUE 3.
    DATA lt_show TYPE TABLE OF abap_bool WITH DEFAULT KEY.
    DATA(lv_ntot) = lines( it_diff ).
    DO lv_ntot TIMES. APPEND abap_false TO lt_show. ENDDO.
    IF i_compact = abap_true.
      DATA lv_ci TYPE i.
      lv_ci = 1.
      LOOP AT it_diff INTO DATA(ls_cm).
        IF ls_cm-op = '-' OR ls_cm-op = '+'.
          DATA lv_from TYPE i.
          DATA lv_to   TYPE i.
          lv_from = lv_ci - lc_ctx.
          lv_to   = lv_ci + lc_ctx.
          IF lv_from < 1. lv_from = 1. ENDIF.
          IF lv_to > lv_ntot. lv_to = lv_ntot. ENDIF.
          DATA lv_fi TYPE i.
          lv_fi = lv_from.
          WHILE lv_fi <= lv_to.
            lt_show[ lv_fi ] = abap_true.
            lv_fi += 1.
          ENDWHILE.
        ENDIF.
        lv_ci += 1.
      ENDLOOP.
    ENDIF.

    IF i_two_pane = abap_true.
      " ── Two-pane rendering ──────────────────────────────────────
      DATA lv_lno_l TYPE i.
      DATA lv_lno_r TYPE i.
      DATA lv_max_w TYPE i.
      DATA lv_pos2  TYPE i VALUE 1.
      DATA lv_tot2  TYPE i.
      lv_tot2 = lines( it_diff ).

      " Calculate max line length of left (base/new) content for column width
      LOOP AT it_diff INTO DATA(ls_w) WHERE op = '=' OR op = '+'.
        DATA(lv_wl) = strlen( condense( val = CONV string( ls_w-text ) ) ).
        IF lv_wl > lv_max_w. lv_max_w = lv_wl. ENDIF.
      ENDLOOP.
      lv_max_w = lv_max_w + 4.   " small padding

      DATA lv_gap2 TYPE abap_bool.
      WHILE lv_pos2 <= lv_tot2.
        READ TABLE it_diff INTO DATA(ls_c2) INDEX lv_pos2.

        IF ls_c2-op = '='.
          lv_lno_l += 1. lv_lno_r += 1.
          IF i_compact = abap_true AND lt_show[ lv_pos2 ] = abap_false.
            IF lv_gap2 = abap_false.
              lv_rows = lv_rows &&
                |<tr style="background:#f0f0f0;color:#888">| &&
                |<td class="ln">...</td><td class="cd">...</td>| &&
                |<td class="sep"></td>| &&
                |<td class="ln">...</td><td class="cd">...</td></tr>|.
              lv_gap2 = abap_true.
            ENDIF.
            lv_pos2 += 1.
            CONTINUE.
          ENDIF.
          CLEAR lv_gap2.
          DATA(lv_eq2) = ls_c2-text.
          REPLACE ALL OCCURRENCES OF `&` IN lv_eq2 WITH `&amp;`.
          REPLACE ALL OCCURRENCES OF `<` IN lv_eq2 WITH `&lt;`.
          REPLACE ALL OCCURRENCES OF `>` IN lv_eq2 WITH `&gt;`.
          lv_rows = lv_rows &&
            |<tr><td class="ln">{ lv_lno_l }</td>| &&
            |<td class="cd">{ lv_eq2 }</td>| &&
            |<td class="sep"></td>| &&
            |<td class="ln">{ lv_lno_r }</td>| &&
            |<td class="cd">{ lv_eq2 }</td></tr>|.
          lv_pos2 += 1.

        ELSEIF ls_c2-op = '-' OR ls_c2-op = '+'.
          DATA lt_d2 TYPE string_table.
          DATA lt_i2 TYPE string_table.
          DATA lv_sc TYPE i.
          lv_sc = lv_pos2.
          " Extended block: collect '-'/'+' AND short bridging empty '=' lines
          " (max 1 in a row) when more changes follow. Bridged '=' lines are
          " not added to lt_d2/lt_i2 (they're equal on both sides) but still
          " advance lv_sc so pairing across the gap works.
          WHILE lv_sc <= lv_tot2.
            READ TABLE it_diff INTO DATA(ls_s2) INDEX lv_sc.
            IF ls_s2-op = '-'. APPEND ls_s2-text TO lt_d2. lv_sc += 1.
            ELSEIF ls_s2-op = '+'. APPEND ls_s2-text TO lt_i2. lv_sc += 1.
            ELSEIF ls_s2-op = '=' AND condense( val = ls_s2-text ) = ``.
              DATA lv_peek2  TYPE i.
              DATA lv_extra2 TYPE i.
              DATA lv_more2  TYPE abap_bool.
              lv_peek2 = lv_sc + 1.
              lv_extra2 = 0.
              lv_more2 = abap_false.
              WHILE lv_peek2 <= lv_tot2.
                READ TABLE it_diff INTO DATA(ls_p2) INDEX lv_peek2.
                IF ls_p2-op = '-' OR ls_p2-op = '+'.
                  lv_more2 = abap_true.
                  EXIT.
                ELSEIF ls_p2-op = '=' AND condense( val = ls_p2-text ) = `` AND lv_extra2 < 1.
                  lv_extra2 += 1.
                  lv_peek2 += 1.
                  CONTINUE.
                ELSE.
                  EXIT.
                ENDIF.
              ENDWHILE.
              IF lv_more2 = abap_true.
                lv_sc += 1.
              ELSE.
                EXIT.
              ENDIF.
            ELSE. EXIT.
            ENDIF.
          ENDWHILE.
          DATA(lv_nd) = lines( lt_d2 ).
          DATA(lv_ni) = lines( lt_i2 ).

          " Blame separator for two-pane (added lines)
          IF it_blame IS NOT INITIAL AND lt_i2 IS NOT INITIAL.
            READ TABLE it_blame INTO DATA(ls_bl2) WITH KEY text = lt_i2[ 1 ].
            IF sy-subrc = 0.
              DATA(lv_bdate2) = |{ ls_bl2-datum+6(2) }.{ ls_bl2-datum+4(2) }.{ ls_bl2-datum(4) }|.
              DATA(lv_btime2) = |{ ls_bl2-zeit(2) }:{ ls_bl2-zeit+2(2) }|.
              DATA(lv_btask2) = COND string(
                WHEN ls_bl2-korrnum IS NOT INITIAL AND ls_bl2-task IS NOT INITIAL THEN | { ls_bl2-korrnum }/{ ls_bl2-task }|
                WHEN ls_bl2-korrnum IS NOT INITIAL THEN | { ls_bl2-korrnum }|
                WHEN ls_bl2-task IS NOT INITIAL THEN | { ls_bl2-task }|
                ELSE `` ).
              DATA(lv_btasktxt2) = COND string( WHEN ls_bl2-task_text IS NOT INITIAL THEN | { ls_bl2-task_text }| ELSE `` ).
              lv_rows = lv_rows &&
                |<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">| &&
                |<td class="ln">▶</td><td class="cd" colspan="3">── { ls_bl2-author }| &&
                COND string( WHEN ls_bl2-author_name IS NOT INITIAL THEN | ({ ls_bl2-author_name })| ELSE `` ) &&
                | added/changed  { lv_bdate2 } { lv_btime2 }  v{ ls_bl2-versno_text }{ lv_btask2 }{ lv_btasktxt2 } ──</td>| &&
                |<td class="ln"></td><td class="cd"></td></tr>|.
            ENDIF.
          ENDIF.
          " Blame separator for two-pane (deleted lines)
          IF it_blame_deleted IS NOT INITIAL AND lt_d2 IS NOT INITIAL AND lt_i2 IS INITIAL.
            READ TABLE it_blame_deleted INTO DATA(ls_bld2) WITH KEY text = lt_d2[ 1 ].
            IF sy-subrc = 0.
              DATA(lv_bddate2) = |{ ls_bld2-datum+6(2) }.{ ls_bld2-datum+4(2) }.{ ls_bld2-datum(4) }|.
              DATA(lv_bdtime2) = |{ ls_bld2-zeit(2) }:{ ls_bld2-zeit+2(2) }|.
              DATA(lv_bdtask2) = COND string(
                WHEN ls_bld2-korrnum IS NOT INITIAL AND ls_bld2-task IS NOT INITIAL THEN | { ls_bld2-korrnum }/{ ls_bld2-task }|
                WHEN ls_bld2-korrnum IS NOT INITIAL THEN | { ls_bld2-korrnum }|
                WHEN ls_bld2-task IS NOT INITIAL THEN | { ls_bld2-task }|
                ELSE `` ).
              DATA(lv_bdtasktxt2) = COND string( WHEN ls_bld2-task_text IS NOT INITIAL THEN | { ls_bld2-task_text }| ELSE `` ).
              lv_rows = lv_rows &&
                |<tr style="background:#fdf0f0;color:#888;font-size:10px;font-style:italic">| &&
                |<td class="ln">◀</td><td class="cd" colspan="3">── { ls_bld2-author }| &&
                COND string( WHEN ls_bld2-author_name IS NOT INITIAL THEN | ({ ls_bld2-author_name })| ELSE `` ) &&
                | deleted  { lv_bddate2 } { lv_bdtime2 }  v{ ls_bld2-versno_text }{ lv_bdtask2 }{ lv_bdtasktxt2 } ──</td>| &&
                |<td class="ln"></td><td class="cd"></td></tr>|.
            ENDIF.
          ENDIF.

          " Split whitespace-only lines out — they should not pair against real content
          DATA lt_i2_p  TYPE string_table.
          DATA lt_d2_p  TYPE string_table.
          DATA lt_i2_ws TYPE string_table.
          DATA lt_d2_ws TYPE string_table.
          DATA lv_cond_tmp TYPE string.
          CLEAR: lt_i2_p, lt_d2_p, lt_i2_ws, lt_d2_ws.
          LOOP AT lt_i2 INTO DATA(ls_itmp).
            lv_cond_tmp = ls_itmp.
            CONDENSE lv_cond_tmp.
            IF lv_cond_tmp IS INITIAL.
              APPEND ls_itmp TO lt_i2_ws.
            ELSE.
              APPEND ls_itmp TO lt_i2_p.
            ENDIF.
          ENDLOOP.
          LOOP AT lt_d2 INTO DATA(ls_dtmp).
            lv_cond_tmp = ls_dtmp.
            CONDENSE lv_cond_tmp.
            IF lv_cond_tmp IS INITIAL.
              APPEND ls_dtmp TO lt_d2_ws.
            ELSE.
              APPEND ls_dtmp TO lt_d2_p.
            ENDIF.
          ENDLOOP.
          " From content-pairable positions, keep only pairs that share characters.
          " Non-sharing pairs are moved to unpaired (own rows).
          DATA lt_i2_pair TYPE string_table.
          DATA lt_d2_pair TYPE string_table.
          DATA lt_i2_solo TYPE string_table.
          DATA lt_d2_solo TYPE string_table.
          CLEAR: lt_i2_pair, lt_d2_pair, lt_i2_solo, lt_d2_solo.
          DATA(lv_np_min) = COND i( WHEN lines( lt_i2_p ) < lines( lt_d2_p )
                                    THEN lines( lt_i2_p ) ELSE lines( lt_d2_p ) ).
          DATA lv_kk TYPE i.
          lv_kk = 1.
          WHILE lv_kk <= lv_np_min.
            IF zcl_ave_popup_diff=>has_common_chars( iv_a = lt_i2_p[ lv_kk ] iv_b = lt_d2_p[ lv_kk ] ) = abap_true.
              APPEND lt_i2_p[ lv_kk ] TO lt_i2_pair.
              APPEND lt_d2_p[ lv_kk ] TO lt_d2_pair.
            ELSE.
              APPEND lt_i2_p[ lv_kk ] TO lt_i2_solo.
              APPEND lt_d2_p[ lv_kk ] TO lt_d2_solo.
            ENDIF.
            lv_kk += 1.
          ENDWHILE.
          " Leftover content beyond min(|lt_i2_p|,|lt_d2_p|)
          lv_kk = lv_np_min + 1.
          WHILE lv_kk <= lines( lt_i2_p ).
            APPEND lt_i2_p[ lv_kk ] TO lt_i2_solo.
            lv_kk += 1.
          ENDWHILE.
          lv_kk = lv_np_min + 1.
          WHILE lv_kk <= lines( lt_d2_p ).
            APPEND lt_d2_p[ lv_kk ] TO lt_d2_solo.
            lv_kk += 1.
          ENDWHILE.

          " Rebuild: paired content first, then solo content, then whitespace-only (all unpaired after lv_np)
          CLEAR lt_i2.
          APPEND LINES OF lt_i2_pair TO lt_i2.
          APPEND LINES OF lt_i2_solo TO lt_i2.
          APPEND LINES OF lt_i2_ws   TO lt_i2.
          CLEAR lt_d2.
          APPEND LINES OF lt_d2_pair TO lt_d2.
          APPEND LINES OF lt_d2_solo TO lt_d2.
          APPEND LINES OF lt_d2_ws   TO lt_d2.
          DATA(lv_np) = lines( lt_i2_pair ).   " both _pair lists have same length
          lv_ni = lines( lt_i2 ).
          lv_nd = lines( lt_d2 ).

          DATA lv_pr TYPE i.
          DATA lv_dl2 TYPE string.
          DATA lv_il2 TYPE string.
          DATA lv_ln_l TYPE string.
          DATA lv_ln_r TYPE string.
          DATA lv_bg_l TYPE string.
          DATA lv_bg_r TYPE string.

          " 1) Paired content rows — char-level diff both sides
          lv_pr = 1.
          WHILE lv_pr <= lv_np.
            lv_lno_l += 1. lv_lno_r += 1.
            lv_dl2 = zcl_ave_popup_diff=>char_diff_html( iv_old = lt_d2[ lv_pr ] iv_new = lt_i2[ lv_pr ] iv_side = 'N' ).
            lv_il2 = zcl_ave_popup_diff=>char_diff_html( iv_old = lt_d2[ lv_pr ] iv_new = lt_i2[ lv_pr ] iv_side = 'O' ).
            lv_rows = lv_rows &&
              |<tr>| &&
              |<td class="ln" style="background:#eaffea">{ lv_lno_l }</td>| &&
              |<td class="cd" style="background:#eaffea">{ lv_dl2 }</td>| &&
              |<td class="sep"></td>| &&
              |<td class="ln" style="background:#ffecec">{ lv_lno_r }</td>| &&
              |<td class="cd" style="background:#ffecec">{ lv_il2 }</td></tr>|.
            CLEAR: lv_dl2, lv_il2.
            lv_pr += 1.
          ENDWHILE.

          " 2) Remaining inserts — left filled, right empty (own rows)
          lv_pr = lv_np + 1.
          WHILE lv_pr <= lv_ni.
            lv_lno_l += 1.
            lv_dl2 = lt_i2[ lv_pr ].
            REPLACE ALL OCCURRENCES OF `&` IN lv_dl2 WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<` IN lv_dl2 WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>` IN lv_dl2 WITH `&gt;`.
            lv_rows = lv_rows &&
              |<tr>| &&
              |<td class="ln" style="background:#eaffea">{ lv_lno_l }</td>| &&
              |<td class="cd" style="background:#eaffea">{ lv_dl2 }</td>| &&
              |<td class="sep"></td>| &&
              |<td class="ln"></td><td class="cd"></td></tr>|.
            CLEAR lv_dl2.
            lv_pr += 1.
          ENDWHILE.

          " 3) Remaining deletes — right filled, left empty (own rows)
          lv_pr = lv_np + 1.
          WHILE lv_pr <= lv_nd.
            lv_lno_r += 1.
            lv_il2 = lt_d2[ lv_pr ].
            REPLACE ALL OCCURRENCES OF `&` IN lv_il2 WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<` IN lv_il2 WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>` IN lv_il2 WITH `&gt;`.
            lv_rows = lv_rows &&
              |<tr>| &&
              |<td class="ln"></td><td class="cd"></td>| &&
              |<td class="sep"></td>| &&
              |<td class="ln" style="background:#ffecec">{ lv_lno_r }</td>| &&
              |<td class="cd" style="background:#ffecec">{ lv_il2 }</td></tr>|.
            CLEAR lv_il2.
            lv_pr += 1.
          ENDWHILE.
          CLEAR: lt_d2, lt_i2, lv_gap2.
          lv_pos2 = lv_sc.
        ELSE.
          lv_pos2 += 1.
        ENDIF.
      ENDWHILE.

      result =
        |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
        |*\{margin:0;padding:0;box-sizing:border-box\}| &&
        |body\{background:#fff;color:#1e1e1e;font:12px/1.5 Consolas,monospace\}| &&
        |.hdr\{background:#f3f3f3;padding:5px 12px;border-bottom:1px solid #ddd;| &&
               |color:#444;font-size:11px;display:flex;gap:16px;flex-wrap:wrap\}| &&
        |.ttl\{color:#0066aa;font-weight:bold\}.meta\{color:#888\}| &&
        |table\{border-collapse:collapse;width:100%\}| &&
        |.ln\{color:#aaa;text-align:right;padding:1px 8px 1px 4px;| &&
             |user-select:none;min-width:36px;border-right:1px solid #e0e0e0;| &&
             |white-space:nowrap;background:#fafafa\}| &&
        |.cd\{padding:1px 8px;white-space:pre;width:{ lv_max_w }ch\}| &&
        |.sep\{border-left:2px solid #ccc;padding:0\}| &&
        |</style></head><body>| &&
        |<div class="hdr">| &&
        |<span class="ttl">| && i_title && |</span>| &&
        |<span class="meta">| && i_meta  && |</span>| &&
        |</div>| &&
        |<table><tbody>| && lv_rows &&
        |</tbody></table></body></html>|.
      RETURN.
    ENDIF.

    " ── Inline rendering (default) ───────────────────────────────

    " Scan diff ops, grouping consecutive '-' and '+' blocks
    DATA lv_pos   TYPE i VALUE 1.
    DATA lv_total TYPE i.
    lv_total = lines( it_diff ).

    DATA lv_gap_shown TYPE abap_bool.   " tracks if '...' separator was already output
    WHILE lv_pos <= lv_total.
      READ TABLE it_diff INTO DATA(ls_cur) INDEX lv_pos.

      IF ls_cur-op = '='.
        lv_lno += 1.
        IF i_compact = abap_true AND lt_show[ lv_pos ] = abap_false.
          " Skip this line — show separator if not shown yet for this gap
          IF lv_gap_shown = abap_false.
            lv_rows = lv_rows &&
              |<tr style="background:#f0f0f0;color:#888">| &&
              |<td class="ln">...</td><td class="cd">...</td></tr>|.
            lv_gap_shown = abap_true.
          ENDIF.
          lv_pos += 1.
          CONTINUE.
        ENDIF.
        CLEAR lv_gap_shown.
        DATA(lv_line_eq) = ls_cur-text.
        REPLACE ALL OCCURRENCES OF `&` IN lv_line_eq WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_line_eq WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_line_eq WITH `&gt;`.
        lv_rows = lv_rows &&
          |<tr style="background:#ffffff">| &&
          |<td class="ln">{ lv_lno }</td>| &&
          |<td class="cd">{ lv_line_eq }</td></tr>|.
        lv_pos += 1.

      ELSEIF ls_cur-op = '-' OR ls_cur-op = '+'.
        " Collect EXTENDED block: consecutive '-'/'+' AND short bridging
        " empty '=' lines (max 1 in a row) when more changes follow.
        " This lets us pair changes across blank-line gaps that LCS inserted.
        DATA lt_block   TYPE zif_ave_popup_types=>ty_t_diff.
        DATA lt_dels    TYPE string_table.
        DATA lt_ins     TYPE string_table.
        DATA lt_del_idx TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
        DATA lt_ins_idx TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
        DATA lv_scan    TYPE i.
        CLEAR: lt_block, lt_dels, lt_ins, lt_del_idx, lt_ins_idx.
        lv_scan = lv_pos.

        WHILE lv_scan <= lv_total.
          READ TABLE it_diff INTO DATA(ls_s) INDEX lv_scan.
          IF ls_s-op = '-' OR ls_s-op = '+'.
            APPEND ls_s TO lt_block.
            lv_scan += 1.
          ELSEIF ls_s-op = '=' AND condense( val = ls_s-text ) = ``.
            " tentative bridge — peek ahead through up to 1 more empty '='
            DATA lv_peek         TYPE i.
            DATA lv_extra        TYPE i.
            DATA lv_more_changes TYPE abap_bool.
            lv_peek = lv_scan + 1.
            lv_extra = 0.
            lv_more_changes = abap_false.
            WHILE lv_peek <= lv_total.
              READ TABLE it_diff INTO DATA(ls_p) INDEX lv_peek.
              IF ls_p-op = '-' OR ls_p-op = '+'.
                lv_more_changes = abap_true.
                EXIT.
              ELSEIF ls_p-op = '=' AND condense( val = ls_p-text ) = `` AND lv_extra < 1.
                lv_extra += 1.
                lv_peek += 1.
                CONTINUE.
              ELSE.
                EXIT.
              ENDIF.
            ENDWHILE.
            IF lv_more_changes = abap_true.
              APPEND ls_s TO lt_block.
              lv_scan += 1.
            ELSE.
              EXIT.
            ENDIF.
          ELSE.
            EXIT.
          ENDIF.
        ENDWHILE.

        " Build dels/ins texts plus their positions inside lt_block.
        " Skip whitespace-only lines from pairing — they have no chars to
        " match and would otherwise eat an index slot, breaking alignment
        " between real changes. They still render as solo via the block walk.
        DATA lv_bi TYPE i.
        lv_bi = 1.
        WHILE lv_bi <= lines( lt_block ).
          DATA(ls_b) = lt_block[ lv_bi ].
          IF ls_b-op = '-' AND condense( val = ls_b-text ) <> ``.
            APPEND ls_b-text TO lt_dels.
            APPEND lv_bi     TO lt_del_idx.
          ELSEIF ls_b-op = '+' AND condense( val = ls_b-text ) <> ``.
            APPEND ls_b-text TO lt_ins.
            APPEND lv_bi     TO lt_ins_idx.
          ENDIF.
          lv_bi += 1.
        ENDWHILE.

        " Blame separator for added lines
        IF it_blame IS NOT INITIAL AND lt_ins IS NOT INITIAL.
          READ TABLE it_blame INTO DATA(ls_bl) WITH KEY text = lt_ins[ 1 ].
          IF sy-subrc = 0.
            DATA(lv_bdate) = |{ ls_bl-datum+6(2) }.{ ls_bl-datum+4(2) }.{ ls_bl-datum(4) }|.
            DATA(lv_btime) = |{ ls_bl-zeit(2) }:{ ls_bl-zeit+2(2) }|.
            DATA(lv_btask) = COND string(
              WHEN ls_bl-korrnum IS NOT INITIAL AND ls_bl-task IS NOT INITIAL THEN | { ls_bl-korrnum }/{ ls_bl-task }|
              WHEN ls_bl-korrnum IS NOT INITIAL THEN | { ls_bl-korrnum }|
              WHEN ls_bl-task IS NOT INITIAL THEN | { ls_bl-task }|
              ELSE `` ).
            DATA(lv_btasktxt) = COND string( WHEN ls_bl-task_text IS NOT INITIAL THEN | { ls_bl-task_text }| ELSE `` ).
            lv_rows = lv_rows &&
              |<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">| &&
              |<td class="ln">▶</td>| &&
              |<td class="cd">── { ls_bl-author }| &&
              COND string( WHEN ls_bl-author_name IS NOT INITIAL THEN | ({ ls_bl-author_name })| ELSE `` ) &&
              | added/changed  { lv_bdate } { lv_btime }  v{ ls_bl-versno_text }{ lv_btask }{ lv_btasktxt } ──</td></tr>|.
          ENDIF.
        ENDIF.
        " Blame separator for deleted lines
        IF it_blame_deleted IS NOT INITIAL AND lt_dels IS NOT INITIAL AND lt_ins IS INITIAL.
          READ TABLE it_blame_deleted INTO DATA(ls_bld) WITH KEY text = lt_dels[ 1 ].
          IF sy-subrc = 0.
            DATA(lv_bddate) = |{ ls_bld-datum+6(2) }.{ ls_bld-datum+4(2) }.{ ls_bld-datum(4) }|.
            DATA(lv_bdtime) = |{ ls_bld-zeit(2) }:{ ls_bld-zeit+2(2) }|.
            DATA(lv_bdtask) = COND string(
              WHEN ls_bld-korrnum IS NOT INITIAL AND ls_bld-task IS NOT INITIAL THEN | { ls_bld-korrnum }/{ ls_bld-task }|
              WHEN ls_bld-korrnum IS NOT INITIAL THEN | { ls_bld-korrnum }|
              WHEN ls_bld-task IS NOT INITIAL THEN | { ls_bld-task }|
              ELSE `` ).
            DATA(lv_bdtasktxt) = COND string( WHEN ls_bld-task_text IS NOT INITIAL THEN | { ls_bld-task_text }| ELSE `` ).
            lv_rows = lv_rows &&
              |<tr style="background:#fdf0f0;color:#888;font-size:10px;font-style:italic">| &&
              |<td class="ln">◀</td>| &&
              |<td class="cd">── { ls_bld-author }| &&
              COND string( WHEN ls_bld-author_name IS NOT INITIAL THEN | ({ ls_bld-author_name })| ELSE `` ) &&
              | deleted  { lv_bddate } { lv_bdtime }  v{ ls_bld-versno_text }{ lv_bdtask }{ lv_bdtasktxt } ──</td></tr>|.
          ENDIF.
        ENDIF.

        DATA(lv_ndels) = lines( lt_dels ).
        DATA(lv_nins)  = lines( lt_ins ).
        DATA(lv_min_di) = COND i( WHEN lv_ndels < lv_nins THEN lv_ndels ELSE lv_nins ).

        " status[i] for each block position: 'P' = render paired here,
        "                                    'C' = consumed (skip), ' ' = solo/equal
        DATA lt_status     TYPE STANDARD TABLE OF c WITH DEFAULT KEY.
        DATA lt_inline_html TYPE string_table.
        CLEAR: lt_status, lt_inline_html.
        DATA lv_init TYPE i.
        lv_init = 1.
        WHILE lv_init <= lines( lt_block ).
          APPEND ` ` TO lt_status.
          APPEND `` TO lt_inline_html.
          lv_init += 1.
        ENDWHILE.

        DATA lv_pk TYPE i.
        lv_pk = 1.
        WHILE lv_pk <= lv_min_di.
          IF zcl_ave_popup_diff=>has_common_chars( iv_a = lt_dels[ lv_pk ] iv_b = lt_ins[ lv_pk ] ) = abap_true.
            DATA(lv_di)    = lt_del_idx[ lv_pk ].
            DATA(lv_ii)    = lt_ins_idx[ lv_pk ].
            DATA(lv_first) = COND i( WHEN lv_di < lv_ii THEN lv_di ELSE lv_ii ).
            DATA(lv_other) = COND i( WHEN lv_di > lv_ii THEN lv_di ELSE lv_ii ).
            lt_status[ lv_first ] = 'P'.
            lt_status[ lv_other ] = 'C'.
            lt_inline_html[ lv_first ] = zcl_ave_popup_diff=>char_diff_html(
              iv_old  = lt_dels[ lv_pk ]
              iv_new  = lt_ins[ lv_pk ]
              iv_side = 'B' ).
          ENDIF.
          lv_pk += 1.
        ENDWHILE.

        " Render block ops in original order
        DATA lv_rb TYPE i.
        lv_rb = 1.
        WHILE lv_rb <= lines( lt_block ).
          DATA(ls_bo) = lt_block[ lv_rb ].
          DATA(lv_st) = lt_status[ lv_rb ].
          IF ls_bo-op = '='.
            lv_lno += 1.
            DATA(lv_eq) = ls_bo-text.
            REPLACE ALL OCCURRENCES OF `&` IN lv_eq WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<` IN lv_eq WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>` IN lv_eq WITH `&gt;`.
            lv_rows = lv_rows &&
              |<tr style="background:#ffffff">| &&
              |<td class="ln">{ lv_lno }</td>| &&
              |<td class="cd">{ lv_eq }</td></tr>|.
          ELSEIF ls_bo-op = '-'.
            IF lv_st = 'P'.
              lv_lno += 1.
              lv_rows = lv_rows &&
                |<tr style="background:#ffffff">| &&
                |<td class="ln">{ lv_lno }</td>| &&
                |<td class="cd">{ lt_inline_html[ lv_rb ] }</td></tr>|.
            ELSEIF lv_st = 'C'.
              " skip — already rendered as part of paired row
            ELSE.
              DATA(lv_dl) = ls_bo-text.
              REPLACE ALL OCCURRENCES OF `&` IN lv_dl WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_dl WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_dl WITH `&gt;`.
              lv_rows = lv_rows &&
                |<tr style="background:#ffecec">| &&
                |<td class="ln" style="color:#cc0000">-</td>| &&
                |<td class="cd" style="color:#cc0000">{ lv_dl }</td></tr>|.
            ENDIF.
          ELSE.  " '+'
            IF lv_st = 'P'.
              lv_lno += 1.
              lv_rows = lv_rows &&
                |<tr style="background:#ffffff">| &&
                |<td class="ln">{ lv_lno }</td>| &&
                |<td class="cd">{ lt_inline_html[ lv_rb ] }</td></tr>|.
            ELSEIF lv_st = 'C'.
              " skip
            ELSE.
              lv_lno += 1.
              DATA(lv_il) = ls_bo-text.
              REPLACE ALL OCCURRENCES OF `&` IN lv_il WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_il WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_il WITH `&gt;`.
              lv_rows = lv_rows &&
                |<tr style="background:#eaffea">| &&
                |<td class="ln" style="color:#006600">{ lv_lno }</td>| &&
                |<td class="cd" style="color:#006600">{ lv_il }</td></tr>|.
            ENDIF.
          ENDIF.
          lv_rb += 1.
        ENDWHILE.

        CLEAR lt_dels.
        CLEAR lt_ins.
        lv_pos = lv_scan.
      ELSE.
        lv_pos += 1.
      ENDIF.
    ENDWHILE.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#ffffff;color:#1e1e1e;font:12px/1.5 Consolas,monospace\}| &&
      |.hdr\{background:#f3f3f3;padding:5px 12px;border-bottom:1px solid #ddd;| &&
             |color:#444;font-size:11px;display:flex;gap:16px;flex-wrap:wrap\}| &&
      |.ttl\{color:#0066aa;font-weight:bold\}| &&
      |.meta\{color:#888\}| &&
      |table\{border-collapse:collapse;width:100%\}| &&
      |.ln\{color:#aaa;text-align:right;padding:1px 10px 1px 5px;| &&
           |user-select:none;min-width:42px;border-right:1px solid #e0e0e0;| &&
           |white-space:nowrap;background:#fafafa\}| &&
      |.cd\{padding:1px 8px;white-space:pre\}| &&
      |</style></head><body>| &&
      |<div class="hdr">| &&
      |<span class="ttl">| && i_title && |</span>| &&
      |<span class="meta">| && i_meta  && |</span>| &&
      |</div>| &&
      |<table><tbody>| && lv_rows &&
      |</tbody></table></body></html>|.
  ENDMETHOD.


  METHOD debug_diff_html.
    " Debug rendering: dump diff ops + change blocks + pairing decisions.
    " Mirrors AVEDiff.debugToHtml() in html_simulator/diff.js — same input
    " through both should produce structurally identical output.
    DATA lv_ops_rows TYPE string.
    DATA lv_blocks   TYPE string.
    DATA lv_idx      TYPE i.

    " ── Section 1: raw ops list ──
    lv_idx = 0.
    LOOP AT it_diff INTO DATA(ls_op).
      lv_idx += 1.
      DATA(lv_op_cls) = COND string(
        WHEN ls_op-op = '=' THEN `eq`
        WHEN ls_op-op = '-' THEN `del`
        ELSE `ins` ).
      DATA(lv_text_e) = ls_op-text.
      REPLACE ALL OCCURRENCES OF `&` IN lv_text_e WITH `&amp;`.
      REPLACE ALL OCCURRENCES OF `<` IN lv_text_e WITH `&lt;`.
      REPLACE ALL OCCURRENCES OF `>` IN lv_text_e WITH `&gt;`.
      DATA(lv_show)   = COND string(
        WHEN lv_text_e IS INITIAL THEN `<em>&lt;empty&gt;</em>`
        ELSE lv_text_e ).
      lv_ops_rows = lv_ops_rows &&
        |<tr class="{ lv_op_cls }"><td class="ln">{ lv_idx }</td>| &&
        |<td class="op">{ ls_op-op }</td><td class="cd">{ lv_show }</td></tr>|.
    ENDLOOP.

    " ── Section 2: walk change blocks, record pairing decisions ──
    DATA lv_pos      TYPE i VALUE 1.
    DATA lv_total    TYPE i.
    DATA lv_block_no TYPE i VALUE 0.
    lv_total = lines( it_diff ).

    WHILE lv_pos <= lv_total.
      READ TABLE it_diff INTO DATA(ls_cur) INDEX lv_pos.
      IF ls_cur-op = '='.
        lv_pos += 1.
        CONTINUE.
      ENDIF.

      DATA lt_dels    TYPE string_table.
      DATA lt_ins     TYPE string_table.
      DATA lv_bridged TYPE i.
      CLEAR: lt_dels, lt_ins, lv_bridged.
      DATA lv_scan TYPE i.
      lv_scan = lv_pos.
      WHILE lv_scan <= lv_total.
        READ TABLE it_diff INTO DATA(ls_s) INDEX lv_scan.
        IF ls_s-op = '-'.
          IF condense( val = ls_s-text ) <> ``.
            APPEND ls_s-text TO lt_dels.
          ENDIF.
          lv_scan += 1.
        ELSEIF ls_s-op = '+'.
          IF condense( val = ls_s-text ) <> ``.
            APPEND ls_s-text TO lt_ins.
          ENDIF.
          lv_scan += 1.
        ELSEIF ls_s-op = '=' AND condense( val = ls_s-text ) = ``.
          " Bridge short empty '=' if more changes follow (max 1 in a row)
          DATA lv_peek         TYPE i.
          DATA lv_extra        TYPE i.
          DATA lv_more_changes TYPE abap_bool.
          lv_peek = lv_scan + 1.
          lv_extra = 0.
          lv_more_changes = abap_false.
          WHILE lv_peek <= lv_total.
            READ TABLE it_diff INTO DATA(ls_p) INDEX lv_peek.
            IF ls_p-op = '-' OR ls_p-op = '+'.
              lv_more_changes = abap_true.
              EXIT.
            ELSEIF ls_p-op = '=' AND condense( val = ls_p-text ) = `` AND lv_extra < 1.
              lv_extra += 1.
              lv_peek += 1.
              CONTINUE.
            ELSE.
              EXIT.
            ENDIF.
          ENDWHILE.
          IF lv_more_changes = abap_true.
            lv_bridged += 1.
            lv_scan += 1.
          ELSE.
            EXIT.
          ENDIF.
        ELSE.
          EXIT.
        ENDIF.
      ENDWHILE.

      lv_block_no += 1.
      DATA(lv_nd) = lines( lt_dels ).
      DATA(lv_ni) = lines( lt_ins ).
      DATA(lv_min_di) = COND i( WHEN lv_nd < lv_ni THEN lv_nd ELSE lv_ni ).
      DATA(lv_block_end) = lv_scan - 1.

      DATA lv_pair_rows TYPE string.
      CLEAR lv_pair_rows.
      DATA lv_k TYPE i.
      lv_k = 1.
      WHILE lv_k <= lv_min_di.
        DATA(lv_a) = lt_dels[ lv_k ].
        DATA(lv_b) = lt_ins[ lv_k ].
        " Replicate has_common_chars: trim, common prefix length
        DATA lv_ta TYPE string.
        DATA lv_tb TYPE string.
        lv_ta = lv_a.
        lv_tb = lv_b.
        WHILE strlen( lv_ta ) > 0 AND substring( val = lv_ta off = 0 len = 1 ) = ` `.
          lv_ta = substring( val = lv_ta off = 1 len = strlen( lv_ta ) - 1 ).
        ENDWHILE.
        WHILE strlen( lv_tb ) > 0 AND substring( val = lv_tb off = 0 len = 1 ) = ` `.
          lv_tb = substring( val = lv_tb off = 1 len = strlen( lv_tb ) - 1 ).
        ENDWHILE.
        WHILE strlen( lv_ta ) > 0 AND substring( val = lv_ta off = strlen( lv_ta ) - 1 len = 1 ) = ` `.
          lv_ta = substring( val = lv_ta off = 0 len = strlen( lv_ta ) - 1 ).
        ENDWHILE.
        WHILE strlen( lv_tb ) > 0 AND substring( val = lv_tb off = strlen( lv_tb ) - 1 len = 1 ) = ` `.
          lv_tb = substring( val = lv_tb off = 0 len = strlen( lv_tb ) - 1 ).
        ENDWHILE.
        DATA(lv_la) = strlen( lv_ta ).
        DATA(lv_lb) = strlen( lv_tb ).
        DATA lv_cp TYPE i VALUE 0.
        lv_cp = 0.
        WHILE lv_cp < lv_la AND lv_cp < lv_lb.
          IF lv_ta+lv_cp(1) = lv_tb+lv_cp(1).
            lv_cp += 1.
          ELSE.
            EXIT.
          ENDIF.
        ENDWHILE.
        DATA(lv_paired) = COND abap_bool(
          WHEN lv_la = 0 OR lv_lb = 0 THEN abap_false
          WHEN lv_cp >= 3              THEN abap_true
          ELSE abap_false ).

        DATA(lv_a_e) = lv_a.
        REPLACE ALL OCCURRENCES OF `&` IN lv_a_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_a_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_a_e WITH `&gt;`.
        DATA(lv_b_e) = lv_b.
        REPLACE ALL OCCURRENCES OF `&` IN lv_b_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_b_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_b_e WITH `&gt;`.
        DATA(lv_a_show) = COND string(
          WHEN lv_a_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_a_e ).
        DATA(lv_b_show) = COND string(
          WHEN lv_b_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_b_e ).
        DATA(lv_verdict) = COND string(
          WHEN lv_paired = abap_true
            THEN |<span class="ok">PAIR (cp={ lv_cp })</span>|
            ELSE |<span class="bad">SOLO (cp={ lv_cp } &lt; 3)</span>| ).
        DATA(lv_inline) = COND string(
          WHEN lv_paired = abap_true THEN zcl_ave_popup_diff=>char_diff_html( iv_old = lv_a iv_new = lv_b iv_side = 'B' )
          ELSE `<em>—</em>` ).
        lv_pair_rows = lv_pair_rows &&
          |<tr><td class="ln">{ lv_k }</td>| &&
          |<td class="cd"><span class="del-tag">−</span> <code>{ lv_a_show }</code></td>| &&
          |<td class="cd"><span class="ins-tag">+</span> <code>{ lv_b_show }</code></td>| &&
          |<td>{ lv_verdict }</td>| &&
          |<td class="cd">{ lv_inline }</td></tr>|.
        lv_k += 1.
      ENDWHILE.

      DATA lv_leftover TYPE string.
      CLEAR lv_leftover.
      lv_k = lv_min_di + 1.
      WHILE lv_k <= lv_nd.
        DATA(lv_d_e) = lt_dels[ lv_k ].
        REPLACE ALL OCCURRENCES OF `&` IN lv_d_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_d_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_d_e WITH `&gt;`.
        DATA(lv_d_show) = COND string( WHEN lv_d_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_d_e ).
        lv_leftover = lv_leftover && |<div class="solo del">SOLO − <code>{ lv_d_show }</code></div>|.
        lv_k += 1.
      ENDWHILE.
      lv_k = lv_min_di + 1.
      WHILE lv_k <= lv_ni.
        DATA(lv_i_e) = lt_ins[ lv_k ].
        REPLACE ALL OCCURRENCES OF `&` IN lv_i_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_i_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_i_e WITH `&gt;`.
        DATA(lv_i_show) = COND string( WHEN lv_i_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_i_e ).
        lv_leftover = lv_leftover && |<div class="solo ins">SOLO + <code>{ lv_i_show }</code></div>|.
        lv_k += 1.
      ENDWHILE.

      DATA(lv_pair_section) = COND string(
        WHEN lv_pair_rows IS NOT INITIAL THEN
          |<table class="pair"><thead><tr><th>k</th><th>del</th><th>ins</th>| &&
          |<th>verdict</th><th>char-diff (if paired)</th></tr></thead>| &&
          |<tbody>| && lv_pair_rows && |</tbody></table>|
        ELSE `<div class="meta">(no del/ins pairs to test)</div>` ).
      DATA(lv_leftover_section) = COND string(
        WHEN lv_leftover IS NOT INITIAL THEN |<div class="leftover">{ lv_leftover }</div>|
        ELSE `` ).

      DATA(lv_bridge_note) = COND string(
        WHEN lv_bridged > 0 THEN | <span class="meta">— bridged { lv_bridged } empty '=' line(s)</span>|
        ELSE `` ).
      lv_blocks = lv_blocks &&
        |<div class="block"><h3>Block #{ lv_block_no } | &&
        |<span class="meta">({ lv_nd } dels, { lv_ni } ins, ops [{ lv_pos }..{ lv_block_end }])</span>| &&
        lv_bridge_note && |</h3>| &&
        lv_pair_section && lv_leftover_section && |</div>|.

      lv_pos = lv_scan.
    ENDWHILE.

    IF lv_blocks IS INITIAL.
      lv_blocks = `<div class="meta">(no change blocks)</div>`.
    ENDIF.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#fff;color:#222;font:12px/1.5 Segoe UI,sans-serif;padding:10px\}| &&
      |h2\{font-size:13px;margin:14px 0 6px;color:#0066aa;border-bottom:1px solid #ddd;padding-bottom:3px\}| &&
      |h3\{font-size:12px;margin:8px 0 4px;color:#444\}| &&
      |.hdr\{background:#f3f3f3;padding:6px 10px;border:1px solid #ddd;color:#444;| &&
            |display:flex;gap:14px;flex-wrap:wrap;margin-bottom:8px\}| &&
      |.ttl\{color:#0066aa;font-weight:bold\}.meta\{color:#888;font-weight:normal;font-size:11px\}| &&
      |table\{border-collapse:collapse;width:100%;font:11px/1.4 Consolas,monospace;margin-bottom:6px\}| &&
      |th,td\{padding:2px 6px;border:1px solid #e0e0e0;text-align:left;vertical-align:top\}| &&
      |th\{background:#fafafa;font-weight:600\}| &&
      |.ln\{color:#aaa;text-align:right;width:40px;background:#fafafa\}| &&
      |.op\{width:24px;text-align:center;font-weight:bold\}| &&
      |tr.eq td\{color:#888\}| &&
      |tr.del\{background:#ffecec\}tr.del td.op\{color:#cc0000\}| &&
      |tr.ins\{background:#eaffea\}tr.ins td.op\{color:#006600\}| &&
      |.cd\{white-space:pre;font:11px/1.4 Consolas,monospace\}| &&
      |code\{font:11px/1.4 Consolas,monospace;background:#f7f7f7;padding:1px 4px;border-radius:2px\}| &&
      |.block\{border:1px solid #ddd;padding:6px;margin-bottom:8px;border-radius:3px;background:#fcfcfc\}| &&
      |.pair th\{background:#eef\}| &&
      |.ok\{color:#006600;font-weight:bold\}.bad\{color:#cc0000;font-weight:bold\}| &&
      |.del-tag\{color:#cc0000;font-weight:bold\}.ins-tag\{color:#006600;font-weight:bold\}| &&
      |.solo\{margin:2px 0;padding:2px 6px;border-radius:2px;font:11px/1.4 Consolas,monospace\}| &&
      |.solo.del\{background:#ffecec;color:#cc0000\}| &&
      |.solo.ins\{background:#eaffea;color:#006600\}| &&
      |.leftover\{margin-top:4px\}| &&
      |em\{color:#aaa;font-style:italic\}| &&
      |</style></head><body>| &&
      |<div class="hdr"><span class="ttl">DEBUG: | && i_title && |</span>| &&
      |<span class="meta">| && i_meta && |</span></div>| &&
      |<h2>1. Diff ops ({ lv_total } total)</h2>| &&
      |<table><thead><tr><th>#</th><th>op</th><th>text</th></tr></thead>| &&
      |<tbody>| && lv_ops_rows && |</tbody></table>| &&
      |<h2>2. Change blocks &amp; pairing decisions</h2>| && lv_blocks &&
      |</body></html>|.
  ENDMETHOD.

ENDCLASS.
