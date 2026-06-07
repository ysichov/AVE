CLASS zcl_ave_acr_command DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS handle_sapevent
      IMPORTING
        io_popup  TYPE REF TO zcl_ave_popup
        iv_action TYPE string.
ENDCLASS.

CLASS zcl_ave_acr_command IMPLEMENTATION.

  METHOD handle_sapevent.
    CHECK io_popup->mv_code_review = abap_true.
    DATA lv_cmd  TYPE string.
    DATA lv_rest TYPE string.
    DATA lv_sep_off TYPE i.
    FIND FIRST OCCURRENCE OF '~' IN iv_action MATCH OFFSET lv_sep_off.
    IF sy-subrc <> 0. RETURN. ENDIF.
    lv_cmd = iv_action(lv_sep_off).
    DATA lv_sep_start TYPE i.
    lv_sep_start = lv_sep_off + 1.
    lv_rest = iv_action+lv_sep_start.
    DATA lv_scroll_txt TYPE string.
    IF lv_cmd = 'openuserdeclined'.
      DATA lv_scroll_sep TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rest MATCH OFFSET lv_scroll_sep.
      IF sy-subrc = 0.
        DATA(lv_tail_start) = lv_scroll_sep + 1.
        DATA(lv_tail) = lv_rest+lv_tail_start.
        IF lv_tail CN '0123456789~'.
        ELSEIF lv_tail CA '~'.
        ELSEIF lv_tail IS NOT INITIAL.
          lv_scroll_txt = lv_tail.
          lv_rest = lv_rest(lv_scroll_sep).
        ENDIF.
      ENDIF.
    ENDIF.

    IF lv_cmd = 'back'.
      io_popup->back_to_report( ).
      RETURN.

    ELSEIF lv_cmd = 'prepare'.
      io_popup->show_recalc_picker( ).
      RETURN.

    ELSEIF lv_cmd = 'recalcpick'.
      io_popup->show_recalc_picker( ).
      RETURN.

    ELSEIF lv_cmd = 'prepare_selected'.
      io_popup->delete_and_recalc_selected( iv_keys = lv_rest ).
      RETURN.

    ELSEIF lv_cmd = 'delete_recalc'.
      io_popup->delete_and_recalc_selected( iv_keys = lv_rest ).
      RETURN.

    ELSEIF lv_cmd = 'openreview'.
      IF io_popup->open_saved_code_review( ) = abap_false.
        MESSAGE 'Saved review diff is not available; use Prepare Code Review' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
      RETURN.

    ELSEIF lv_cmd = 'aiprompt'.
      IF io_popup->is_ai_enabled( ) = abap_true.
        io_popup->do_ai_summary( ).
      ELSE.
        io_popup->show_ai_prompt( ).
      ENDIF.
      RETURN.

    ELSEIF lv_cmd = 'askai'.
      io_popup->do_askai( iv_hunk_key = lv_rest ).
      RETURN.

    ELSEIF lv_cmd = 'trtasks'.
      DATA lv_tt_type TYPE versobjtyp.
      DATA lv_tt_name TYPE versobjnam.
      IF strlen( lv_rest ) > 5 AND lv_rest+4(1) = '~'.
        lv_tt_type = lv_rest(4).
        lv_tt_name = lv_rest+5.
        io_popup->show_tr_task_popup( iv_objtype = lv_tt_type iv_objname = lv_tt_name ).
      ENDIF.
      RETURN.

    ELSEIF lv_cmd = 'openobj'.
      DATA lv_oo_rest TYPE string.
      lv_oo_rest = lv_rest.
      DATA(lv_rev2) = reverse( lv_oo_rest ).
      DATA lv_tilde2 TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rev2 MATCH OFFSET lv_tilde2.
      IF sy-subrc = 0.
        DATA(lv_scand_start) = strlen( lv_oo_rest ) - lv_tilde2.
        DATA(lv_scand) = lv_oo_rest+lv_scand_start.
        IF lv_scand IS NOT INITIAL AND lv_scand CO '0123456789'.
          io_popup->mv_cr_report_scroll = CONV i( lv_scand ).
          DATA(lv_oo_rest_len) = lv_scand_start - 1.
          IF lv_oo_rest_len >= 0.
            lv_oo_rest = lv_oo_rest(lv_oo_rest_len).
          ENDIF.
        ENDIF.
      ENDIF.
      DATA lv_oo_type TYPE versobjtyp.
      DATA lv_oo_name TYPE versobjnam.
      IF strlen( lv_oo_rest ) > 5 AND lv_oo_rest+4(1) = '~'.
        lv_oo_type = lv_oo_rest(4).
        lv_oo_name = lv_oo_rest+5.
        io_popup->open_cr_part( iv_objtype = lv_oo_type iv_objname = lv_oo_name ).
      ENDIF.
      RETURN.

    ELSEIF lv_cmd = 'openuserdeclined'.
      io_popup->show_user_declines( iv_user = CONV #( lv_rest ) ).
      RETURN.

    ELSEIF lv_cmd = 'openreviewer'.
      io_popup->show_user_declines( iv_user = CONV #( lv_rest ) iv_reviewer = abap_true ).
      RETURN.

    ELSEIF lv_cmd = 'openclass'.
      io_popup->show_class_objects( iv_class_name = CONV #( lv_rest ) ).
      RETURN.

    ELSEIF lv_cmd = 'movingviol'.
      io_popup->show_moving_violations( ).
      RETURN.

    ELSEIF lv_cmd = 'approveall'.
      DATA lv_tld2 TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rest MATCH OFFSET lv_tld2.
      DATA lv_nst2 TYPE i.
      lv_nst2 = lv_tld2 + 1.
      DATA lv_type2  TYPE versobjtyp.
      DATA lv_onam2  TYPE versobjnam.
      lv_type2 = lv_rest(lv_tld2).
      lv_onam2 = lv_rest+lv_nst2.
      DATA lv_hunk_cnt2 TYPE i.
      LOOP AT io_popup->mt_hunk_info INTO DATA(ls_aa_hi)
        WHERE objtype = lv_type2 AND obj_name = lv_onam2.
        CHECK ls_aa_hi-retrofit IS INITIAL.
        lv_hunk_cnt2 += 1.
      ENDLOOP.
      IF lv_hunk_cnt2 = 0.
        READ TABLE io_popup->mt_acr_stats INTO DATA(ls_st2)
          WITH KEY objtype = lv_type2 obj_name = lv_onam2.
        IF sy-subrc = 0. lv_hunk_cnt2 = ls_st2-hunk_count. ENDIF.
      ENDIF.
      IF lv_hunk_cnt2 > 0.
        DO lv_hunk_cnt2 TIMES.
          DATA(lv_hk) = |{ lv_rest }~{ sy-index }|.
          CHECK zcl_ave_acr_state=>is_own_hunk(
            iv_hunk_key  = lv_hk
            it_hunk_info = io_popup->mt_hunk_info ) = abap_false.
          INSERT lv_hk INTO TABLE io_popup->mt_approved.
          DELETE TABLE io_popup->mt_declined FROM lv_hk.
          zcl_ave_acr_state=>set_hunk_action(
            EXPORTING
              iv_hunk_key     = lv_hk
              iv_action       = 'A'
            CHANGING
              ct_hunk_actions = io_popup->mt_hunk_actions ).
        ENDDO.
      ENDIF.

    ELSEIF lv_cmd = 'addcomment' OR lv_cmd = 'editreview'.
      DATA lv_er_key TYPE string.
      lv_er_key = lv_rest.
      CLEAR io_popup->mv_pending_decline.
      CLEAR io_popup->mv_pending_edit.
      DATA(lv_er_note) = ``.
      IF lv_cmd = 'editreview'.
        io_popup->mv_pending_edit = lv_er_key.
        lv_er_note = zcl_ave_acr_state=>get_last_own_comment(
          iv_hunk_key     = lv_er_key
          it_hunk_threads = io_popup->mt_hunk_threads ).
      ENDIF.
      io_popup->mo_note_dlg = NEW zcl_ave_acr_note_dlg(
        iv_title    = lv_er_key
        iv_hunk_key = lv_er_key
        iv_note     = lv_er_note ).
      SET HANDLER io_popup->on_note_dlg_saved FOR io_popup->mo_note_dlg.
      SET HANDLER io_popup->on_note_dlg_cancelled FOR io_popup->mo_note_dlg.
      io_popup->mo_note_dlg->show( ).
      RETURN.

    ELSEIF lv_cmd = 'undo'.
      DATA lv_undo_key TYPE string.
      lv_undo_key = lv_rest.
      IF zcl_ave_acr_state=>is_own_hunk(
           iv_hunk_key  = lv_undo_key
           it_hunk_info = io_popup->mt_hunk_info ) = abap_true.
        MESSAGE 'You cannot undo review status for your own block' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
      DELETE TABLE io_popup->mt_approved FROM lv_undo_key.
      DELETE TABLE io_popup->mt_declined FROM lv_undo_key.
      DELETE TABLE io_popup->mt_decline_notes WITH TABLE KEY hunk_key = lv_undo_key.
      zcl_ave_acr_state=>clear_hunk_action(
        EXPORTING
          iv_hunk_key     = lv_undo_key
        CHANGING
          ct_hunk_actions = io_popup->mt_hunk_actions ).
      IF io_popup->mv_decline_view_user IS NOT INITIAL.
        io_popup->show_user_declines( iv_user = io_popup->mv_decline_view_user iv_reviewer = io_popup->mv_reviewer_view ).
      ELSEIF io_popup->mv_cur_objtype IS NOT INITIAL AND io_popup->mv_cr_base_html IS INITIAL.
        io_popup->open_cr_part( iv_objtype = io_popup->mv_cur_objtype iv_objname = io_popup->mv_cur_objname ).
      ELSEIF io_popup->mv_cr_base_html IS NOT INITIAL AND io_popup->mv_cr_cur_key IS NOT INITIAL.
        io_popup->set_html( io_popup->inject_approve_btn( iv_html = io_popup->mv_cr_base_html iv_key = io_popup->mv_cr_cur_key ) ).
      ENDIF.
      io_popup->regen_acr_report( ).
      io_popup->refresh_rpt_row( ).
      io_popup->save_review_to_db( iv_silent = abap_true ).
      RETURN.

    ELSEIF lv_cmd = 'approve' OR lv_cmd = 'decline'.
      DATA lv_key TYPE string.
      lv_key = lv_rest.
      IF zcl_ave_acr_state=>is_own_hunk(
           iv_hunk_key  = lv_key
           it_hunk_info = io_popup->mt_hunk_info ) = abap_true.
        MESSAGE 'You cannot approve or decline your own block' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
      IF lv_cmd = 'approve'.
        INSERT lv_key INTO TABLE io_popup->mt_approved.
        DELETE TABLE io_popup->mt_declined FROM lv_key.
        zcl_ave_acr_state=>set_hunk_action(
          EXPORTING
            iv_hunk_key     = lv_key
            iv_action       = 'A'
          CHANGING
            ct_hunk_actions = io_popup->mt_hunk_actions ).
      ELSE.
        io_popup->mv_pending_decline = lv_key.
        io_popup->mo_note_dlg = NEW zcl_ave_acr_note_dlg(
          iv_title    = lv_key
          iv_hunk_key = lv_key
          iv_note     = `` ).
        SET HANDLER io_popup->on_note_dlg_saved FOR io_popup->mo_note_dlg.
        SET HANDLER io_popup->on_note_dlg_cancelled FOR io_popup->mo_note_dlg.
        io_popup->mo_note_dlg->show( ).
        RETURN.
      ENDIF.

      IF io_popup->mv_decline_view_user IS NOT INITIAL.
        io_popup->show_user_declines( iv_user = io_popup->mv_decline_view_user iv_reviewer = io_popup->mv_reviewer_view ).
        io_popup->regen_acr_report( ).
        io_popup->refresh_rpt_row( ).
        io_popup->save_review_to_db( iv_silent = abap_true ).
        RETURN.
      ELSEIF io_popup->mv_cr_base_html IS NOT INITIAL AND io_popup->mv_cr_cur_key IS NOT INITIAL.
        DATA(lv_html) = io_popup->inject_approve_btn(
          iv_html = io_popup->mv_cr_base_html iv_key = io_popup->mv_cr_cur_key ).

        DATA(lv_rev) = reverse( lv_key ).
        DATA lv_tilde_pos TYPE i.
        FIND FIRST OCCURRENCE OF '~' IN lv_rev MATCH OFFSET lv_tilde_pos.
        IF sy-subrc = 0.
          DATA lv_chunk_start TYPE i.
          lv_chunk_start = strlen( lv_key ) - lv_tilde_pos.
          DATA(lv_chunk) = lv_key+lv_chunk_start.
          IF lv_chunk IS NOT INITIAL.
            DATA(lv_script) =
              `<script>window.onload=function(){` &&
              `var e=document.getElementById('acr_c` && lv_chunk && `');` &&
              `if(e)e.scrollIntoView({block:'center'});}` &&
              `</script></head>`.
            lv_html = replace( val = lv_html sub = `</head>` with = lv_script ).
          ENDIF.
        ENDIF.

        io_popup->set_html( lv_html ).
        io_popup->regen_acr_report( ).
        io_popup->refresh_rpt_row( ).
        io_popup->save_review_to_db( iv_silent = abap_true ).
        RETURN.
      ENDIF.
    ENDIF.

    IF io_popup->mv_decline_view_user IS NOT INITIAL.
      io_popup->show_user_declines( iv_user = io_popup->mv_decline_view_user iv_reviewer = io_popup->mv_reviewer_view ).
    ELSEIF io_popup->mv_cur_objtype IS NOT INITIAL AND io_popup->mv_cr_base_html IS INITIAL.
      io_popup->open_cr_part( iv_objtype = io_popup->mv_cur_objtype iv_objname = io_popup->mv_cur_objname ).
    ELSEIF io_popup->mv_cr_base_html IS NOT INITIAL AND io_popup->mv_cr_cur_key IS NOT INITIAL.
      io_popup->set_html( io_popup->inject_approve_btn( iv_html = io_popup->mv_cr_base_html iv_key = io_popup->mv_cr_cur_key ) ).
    ENDIF.
    io_popup->regen_acr_report( ).
    io_popup->refresh_rpt_row( ).
    io_popup->save_review_to_db( iv_silent = abap_true ).
  ENDMETHOD.

ENDCLASS.

