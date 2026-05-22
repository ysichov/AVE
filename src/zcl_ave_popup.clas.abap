CLASS zcl_ave_popup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    DATA mv_desination TYPE text255 .
    DATA mv_model TYPE text255 .
    DATA mv_apikey TYPE text255 .

    METHODS constructor
    IMPORTING
      !i_object_type TYPE string
      !i_object_name TYPE string
      !is_settings TYPE zif_ave_object=>ty_settings OPTIONAL .
    METHODS show .
  PROTECTED SECTION.
  PRIVATE SECTION.

    "──────────── types ─────────────────────────────────────────────
    " Extended parts row: original fields + existence flag + row color
    TYPES ty_part_row TYPE zif_ave_popup_types=>ty_part_row .
    TYPES ty_t_part_row TYPE zif_ave_popup_types=>ty_t_part_row .
    TYPES ty_version_row TYPE zif_ave_popup_types=>ty_version_row .
    TYPES ty_t_version_row TYPE zif_ave_popup_types=>ty_t_version_row .
    "! Delegated to ZCL_AVE_POPUP_DIFF (extracted diff engine)
    TYPES ty_diff_op TYPE zif_ave_popup_types=>ty_diff_op .
    TYPES ty_t_diff TYPE zif_ave_popup_types=>ty_t_diff .
  "! Delegated to ZCL_AVE_POPUP_HTML (extracted HTML renderer)
    TYPES ty_blame_entry TYPE zif_ave_popup_types=>ty_blame_entry .
    TYPES ty_blame_map TYPE zif_ave_popup_types=>ty_blame_map .
    TYPES:
  "──────────── diff HTML cache ────────────────────────────────────
  "! Per-instance cache for rendered diff HTML.
  "! Key: object type/name + old/new versno + display flags (blame/two_pane/compact/debug).
  "! Hit: return stored HTML immediately, skipping source load, diff and blame computation.
  "! Miss: compute as usual, store result. Cache lives for the lifetime of the popup instance.
    BEGIN OF ty_diff_cache_key,
           objtype     TYPE versobjtyp,
           objname     TYPE versobjnam,
           system_o    TYPE verssysnam,
           system_n    TYPE verssysnam,
           versno_o    TYPE versno,
           versno_n    TYPE versno,
           blame       TYPE abap_bool,
           two_pane    TYPE abap_bool,
           compact     TYPE abap_bool,
           debug       TYPE abap_bool,
           ignore_case TYPE abap_bool,
         END OF ty_diff_cache_key .
    TYPES:
    BEGIN OF ty_diff_cache,
           key  TYPE ty_diff_cache_key,
           html TYPE string,
         END OF ty_diff_cache .
    TYPES:
    ty_t_diff_cache TYPE HASHED TABLE OF ty_diff_cache WITH UNIQUE KEY key .
    TYPES ty_action_code TYPE zif_ave_acr_types=>ty_action_code .
    TYPES ty_hunk_action TYPE zif_ave_acr_types=>ty_hunk_action .
    TYPES ty_t_hunk_actions TYPE zif_ave_acr_types=>ty_t_hunk_actions .
    TYPES ty_decline_note TYPE zif_ave_acr_types=>ty_decline_note .
    TYPES ty_t_decline_notes TYPE zif_ave_acr_types=>ty_t_decline_notes .
    TYPES ty_decline_msg TYPE zif_ave_acr_types=>ty_decline_msg .
    TYPES ty_t_decline_msgs TYPE zif_ave_acr_types=>ty_t_decline_msgs .
    TYPES ty_hunk_info TYPE zif_ave_acr_types=>ty_hunk_info .
    TYPES ty_t_hunk_info TYPE zif_ave_acr_types=>ty_t_hunk_info .
    TYPES ty_hunk_thread TYPE zif_ave_acr_types=>ty_hunk_thread .
    TYPES ty_t_hunk_threads TYPE zif_ave_acr_types=>ty_t_hunk_threads .
    TYPES ty_saved_thread TYPE zif_ave_acr_types=>ty_saved_thread .
    TYPES ty_t_saved_threads TYPE zif_ave_acr_types=>ty_t_saved_threads .
    TYPES ty_saved_key TYPE zif_ave_acr_types=>ty_saved_key .
    TYPES ty_t_saved_keys TYPE zif_ave_acr_types=>ty_t_saved_keys .
    TYPES ty_saved_note TYPE zif_ave_acr_types=>ty_saved_note .
    TYPES ty_t_saved_notes TYPE zif_ave_acr_types=>ty_t_saved_notes .
    TYPES ty_saved_user_state TYPE zif_ave_acr_types=>ty_saved_user_state .
    TYPES ty_t_saved_user_state TYPE zif_ave_acr_types=>ty_t_saved_user_state .
    TYPES ty_saved_history TYPE zif_ave_acr_types=>ty_saved_history .
    TYPES ty_t_saved_history TYPE zif_ave_acr_types=>ty_t_saved_history .
    TYPES ty_saved_payload TYPE zif_ave_acr_types=>ty_saved_payload .

    "──────────── controls ──────────────────────────────────────────
    CLASS-DATA mv_counter TYPE i .
    DATA mv_object_type TYPE string .
    DATA mv_object_name TYPE string .
    DATA mo_box TYPE REF TO cl_gui_dialogbox_container .
    DATA mo_split_main TYPE REF TO cl_gui_splitter_container .
    DATA mo_split_top TYPE REF TO cl_gui_splitter_container .
    DATA mo_cont_parts TYPE REF TO cl_gui_container .
    DATA mo_cont_html TYPE REF TO cl_gui_container .
    DATA mo_cont_vers TYPE REF TO cl_gui_container .
  " 2-pane layout containers
    DATA mo_split_wrap TYPE REF TO cl_gui_splitter_container .
    DATA mo_split_2p_top TYPE REF TO cl_gui_splitter_container .
    DATA mo_split_2p_wrap TYPE REF TO cl_gui_splitter_container .
    DATA mv_focus_html TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mo_cont_parts_2p TYPE REF TO cl_gui_container .
    DATA mo_cont_vers_2p TYPE REF TO cl_gui_container .
    DATA mo_cont_html_2p TYPE REF TO cl_gui_container .
    " Left panel: ALV Grid with the list of object parts
    DATA mo_alv_parts TYPE REF TO cl_gui_alv_grid .
    DATA mt_parts TYPE ty_t_part_row .
    " Right panel: HTML code viewer + ABAP editor (used for single-version
    " source view; HTML is too slow for 100k+ lines)
    DATA mo_html TYPE REF TO cl_gui_html_viewer .
    DATA mo_code_viewer TYPE REF TO cl_gui_abapedit .
  " Splits mo_cont_html into two rows — HTML (diff) on top, ABAP editor
  " (single-version source) on bottom. We toggle row heights 0/100 to
  " switch views reliably (z-order tricks with set_visible are unreliable).
    DATA mo_split_html TYPE REF TO cl_gui_splitter_container .
    DATA mo_cont_html_diff TYPE REF TO cl_gui_container .
    DATA mo_cont_html_code TYPE REF TO cl_gui_container .
    " Bottom panel: SALV table with version list
    DATA mo_alv_vers TYPE REF TO cl_gui_alv_grid .
    DATA mt_versions TYPE ty_t_version_row .
    DATA mv_cur_objtype TYPE versobjtyp .
    DATA mv_cur_objname TYPE versobjnam .
    DATA mv_cur_part_name TYPE string .      " Human-readable display name for caption (e.g. method name, section name)
    DATA mv_cur_creator TYPE versuser .
    DATA ms_base_ver TYPE ty_version_row .
    DATA ms_diff_old TYPE ty_version_row .
    DATA ms_diff_new TYPE ty_version_row .
    DATA mv_show_diff TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_layout TYPE abap_bool .
    DATA mv_two_pane TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_no_toc TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_compact TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_remove_dup TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_blame TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_ignore_case TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_task_view TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_diff_prev TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_refreshing TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_debug TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_last_html TYPE string .
  "! When drilled into a class from a TR parts view, holds the class name so
  "! Refresh reloads only that class (not the outer TR).
    DATA mv_drilled_class TYPE seoclsname .
    DATA mv_filter_user TYPE versuser .
    DATA mv_filter_korrnum TYPE trkorr .
    DATA mt_filter_korrnums TYPE zif_ave_object=>ty_t_korr_range .
    DATA mt_filter_parent_korrnums TYPE zif_ave_object=>ty_t_korr_range .
    DATA mv_oldest_filter_korrnum TYPE trkorr .
    DATA mv_date_from TYPE versdate .
    DATA mv_viewed_versno TYPE versno .
    " Backup for Back navigation (one level)
    DATA mt_parts_backup TYPE ty_t_part_row .
    DATA mt_diff_cache TYPE ty_t_diff_cache .
    DATA mo_toolbar TYPE REF TO cl_gui_toolbar .
    DATA mo_cont_toolbar TYPE REF TO cl_gui_container .
  " ── Code Reviewer mode ──────────────────────────────────────────
    DATA mv_code_review TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_cr_prepared TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mt_acr_stats TYPE zif_ave_acr_types=>ty_t_obj_stats .
    DATA mv_cr_report_html TYPE string .
    DATA mv_system TYPE verssysnam .
    DATA mt_approved TYPE zif_ave_acr_types=>ty_approved .
    DATA mt_declined TYPE zif_ave_acr_types=>ty_approved .
    DATA mt_decline_notes TYPE ty_t_decline_notes .
    DATA mt_hunk_actions TYPE ty_t_hunk_actions .
    DATA mt_hunk_info TYPE ty_t_hunk_info .
    DATA mt_hunk_threads TYPE ty_t_hunk_threads .
    DATA mt_cr_diag TYPE string_table .
    DATA mv_cr_base_html TYPE string .
    DATA mv_cr_cur_key TYPE string .
    DATA mv_cr_report_scroll TYPE i .
    DATA mv_decline_view_user TYPE versuser .
    DATA mv_reviewer_view TYPE abap_bool .
  " Pending decline key — set before opening note dialog, used in saved-event handler
    DATA mv_pending_decline TYPE string .
    DATA mv_pending_edit TYPE string .
    DATA mo_note_dlg TYPE REF TO zcl_ave_acr_note_dlg .
    DATA mo_help_box TYPE REF TO cl_gui_dialogbox_container .
    DATA mo_help_html TYPE REF TO cl_gui_html_viewer .

    "──────────── build ─────────────────────────────────────────────
    METHODS build_layout .
    METHODS build_parts_list .
    METHODS build_html_viewer .
    METHODS refresh_vers .
    METHODS refresh_parts .
    METHODS switch_pane_layout .
    METHODS create_parts_alv .
    METHODS create_versions_alv .
    METHODS create_html_viewer .
    METHODS build_versions_grid .
    "──────────── events ────────────────────────────────────────────
    METHODS handle_parts_toolbar
    FOR EVENT toolbar OF cl_gui_alv_grid
    IMPORTING
      !e_object
      !e_interactive .
    METHODS handle_parts_command
    FOR EVENT user_command OF cl_gui_alv_grid
    IMPORTING
      !e_ucomm .
    METHODS handle_parts_dblclick
    FOR EVENT double_click OF cl_gui_alv_grid
    IMPORTING
      !es_row_no
      !e_column .
    METHODS on_toolbar_click
    FOR EVENT function_selected OF cl_gui_toolbar
    IMPORTING
      !fcode .
    METHODS handle_vers_toolbar
    FOR EVENT toolbar OF cl_gui_alv_grid
    IMPORTING
      !e_object
      !e_interactive .
    METHODS handle_vers_command
    FOR EVENT user_command OF cl_gui_alv_grid
    IMPORTING
      !e_ucomm .
    METHODS handle_vers_dblclick
    FOR EVENT double_click OF cl_gui_alv_grid
    IMPORTING
      !es_row_no
      !e_column .
    METHODS on_box_close
    FOR EVENT close OF cl_gui_dialogbox_container
    IMPORTING
      !sender .
    METHODS on_help_box_close
    FOR EVENT close OF cl_gui_dialogbox_container
    IMPORTING
      !sender .
    METHODS on_sapevent
    FOR EVENT sapevent OF cl_gui_html_viewer
    IMPORTING
      !action
      !getdata
      !postdata .
    METHODS inject_approve_btn
    IMPORTING
      !iv_html TYPE string
      !iv_key TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS refresh_rpt_row .
    METHODS regen_acr_report .
    METHODS add_cr_report_toolbar
    IMPORTING
      !iv_html TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS build_cr_object_report_html
    RETURNING
      VALUE(result) TYPE string .
    METHODS prepare_code_review
    IMPORTING
      !iv_keys TYPE string OPTIONAL .
    METHODS delete_and_recalc_selected
    IMPORTING
      !iv_keys TYPE string .
    METHODS show_recalc_picker .
    METHODS open_saved_code_review
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS maximize_html .
    METHODS on_note_dlg_saved
    FOR EVENT saved OF zcl_ave_acr_note_dlg
    IMPORTING
      !iv_hunk_key
      !iv_note .
    METHODS on_note_dlg_cancelled
    FOR EVENT cancelled OF zcl_ave_acr_note_dlg
    IMPORTING
      !iv_hunk_key .
    METHODS back_to_report .
    METHODS show_class_objects
    IMPORTING
      !iv_class_name TYPE seoclsname .
    METHODS show_user_declines
    IMPORTING
      !iv_user TYPE versuser
      !iv_reviewer TYPE abap_bool OPTIONAL .
    METHODS show_ai_prompt .
    METHODS do_ai_summary .
    METHODS show_ai_hunk_prompt_popup
    IMPORTING
      !iv_prompt TYPE string
      !iv_hunk_key TYPE string .
    METHODS build_ai_hunk_prompt
    IMPORTING
      !iv_hunk_key TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS do_askai
    IMPORTING
      !iv_hunk_key TYPE string .
    METHODS is_ai_enabled
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS get_ai_hunk_comment
    IMPORTING
      !iv_hunk_key TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS get_hunk_thread
    IMPORTING
      !is_hunk TYPE ty_hunk_info
    RETURNING
      VALUE(result) TYPE ty_hunk_thread .
    METHODS get_ai_summary_key
    IMPORTING
      !iv_objtype TYPE versobjtyp
      !iv_objname TYPE versobjnam
    RETURNING
      VALUE(result) TYPE string .
    METHODS render_ai_summary_html
    IMPORTING
      !iv_objtype TYPE versobjtyp
      !iv_objname TYPE versobjnam
    RETURNING
      VALUE(result) TYPE string .
    METHODS save_ai_summary
    IMPORTING
      !iv_objtype TYPE versobjtyp
      !iv_objname TYPE versobjnam
      !iv_text TYPE string .
    METHODS get_hunk_scroll_anchor
    IMPORTING
      !iv_hunk_key TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS get_summary_scroll_anchor
    IMPORTING
      !iv_objtype TYPE versobjtyp
      !iv_objname TYPE versobjnam
    RETURNING
      VALUE(result) TYPE string .
    METHODS scroll_last_html_to
    IMPORTING
      !iv_anchor TYPE string .
    METHODS refresh_ai_html_progress
    IMPORTING
      !iv_hunk_key TYPE string OPTIONAL
      !iv_objtype TYPE versobjtyp OPTIONAL
      !iv_objname TYPE versobjnam OPTIONAL
      !iv_summary TYPE abap_bool OPTIONAL .
    METHODS open_cr_part
    IMPORTING
      !iv_objtype TYPE versobjtyp
      !iv_objname TYPE versobjnam .
    METHODS rerender_cr_current
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS rerender_cr_user_view
    RETURNING
      VALUE(result) TYPE abap_bool .
    "──────────── logic ─────────────────────────────────────────────
    METHODS get_class_parts
    IMPORTING
      !i_name TYPE versobjnam
    RETURNING
      VALUE(result) TYPE ty_t_part_row
    RAISING
      zcx_ave .
    METHODS load_versions
    IMPORTING
      !i_objtype TYPE versobjtyp
      !i_objname TYPE versobjnam .
    METHODS update_ver_colors
    IMPORTING
      !iv_viewed_versno TYPE versno OPTIONAL .
    METHODS show_source
    IMPORTING
      !i_objtype TYPE versobjtyp
      !i_objname TYPE versobjnam
      !i_versno TYPE versno .
    METHODS show_versions_diff
    IMPORTING
      !is_old TYPE ty_version_row
      !is_new TYPE ty_version_row .
  "! Auto-open guard: if is_new source exceeds 1000 lines, show source only;
  "! user can manually trigger a diff from the version list.
    METHODS auto_show_diff_or_source
    IMPORTING
      !is_old TYPE ty_version_row
      !is_new TYPE ty_version_row .
    METHODS set_html
    IMPORTING
      !iv_html TYPE string .
    METHODS has_review_table
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS load_review_from_db .
    METHODS load_review_payload
    IMPORTING
      !iv_trkorr TYPE trkorr
    EXPORTING
      !es_payload TYPE ty_saved_payload
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS save_review_to_db
    IMPORTING
      !iv_silent TYPE abap_bool OPTIONAL .
    METHODS get_last_own_comment
    IMPORTING
      !iv_hunk_key TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS format_timestamp
    IMPORTING
      !iv_timestamp TYPE timestampl
    RETURNING
      VALUE(result) TYPE string .
    METHODS set_hunk_action
    IMPORTING
      !iv_hunk_key TYPE string
      !iv_action TYPE ty_action_code .
    METHODS clear_hunk_action
    IMPORTING
      !iv_hunk_key TYPE string .
    METHODS sanitize_review_state .
    METHODS collect_report_status
    EXPORTING
      !et_approved TYPE zif_ave_acr_types=>ty_approved
      !et_declined TYPE zif_ave_acr_types=>ty_approved .
    METHODS get_reviewer_stats
    RETURNING
      VALUE(result) TYPE zif_ave_acr_types=>ty_t_reviewer_stats .
    METHODS build_review_help_html
    RETURNING
      VALUE(result) TYPE string .
    METHODS show_review_help_popup .
    METHODS build_tr_task_popup_html
    IMPORTING
      !iv_objtype TYPE versobjtyp
      !iv_objname TYPE versobjnam
    RETURNING
      VALUE(result) TYPE string .
    METHODS show_tr_task_popup
    IMPORTING
      !iv_objtype TYPE versobjtyp
      !iv_objname TYPE versobjnam .
  "! Upload source to the ABAP editor and toggle visibility so it takes the
  "! place of the HTML viewer. Used for single-version (Show Vers) view.
    METHODS show_code_source
    IMPORTING
      !it_source TYPE abaptxt255_tab .
    METHODS add_cr_diag
    IMPORTING
      !iv_text TYPE string .
    METHODS add_cr_diagnostics
    IMPORTING
      !iv_html TYPE string
    RETURNING
      VALUE(result) TYPE string .
  "! Code Reviewer: compute diff+HTML+stats for one changed part and cache them.
  "! Mirrors the core of show_versions_diff but without UI side effects.
    METHODS cr_precompute_part
    IMPORTING
      !is_part TYPE ty_part_row .
  "! Code Reviewer: iterate all parts of a class, call cr_precompute_part for each.
  "! Returns true if at least one part was added to mt_acr_stats.
    METHODS cr_precompute_class_parts
    IMPORTING
      !i_class_name TYPE seoclsname
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS is_comments_only
    IMPORTING
      !it_src TYPE abaptxt255_tab
    RETURNING
      VALUE(result) TYPE abap_bool .
ENDCLASS.



CLASS zcl_ave_popup IMPLEMENTATION.


  METHOD add_cr_diag.
    CHECK mv_code_review = abap_true.
    CHECK iv_text IS NOT INITIAL.
    IF lines( mt_cr_diag ) < 300.
      APPEND iv_text TO mt_cr_diag.
    ENDIF.
  ENDMETHOD.


  METHOD add_cr_diagnostics.
    result = iv_html.
    CHECK mt_cr_diag IS NOT INITIAL.

    DATA(lv_diag_html) =
      `<details style="margin:12px 0;padding:10px;border:1px solid #d8dee9;` &&
      `background:#fbfcfe;color:#4d5968;font:12px Consolas,monospace">` &&
      `<summary style="cursor:pointer;font-weight:bold;color:#2c3e50">` &&
      `Code Review diagnostics</summary><pre style="white-space:pre-wrap;margin:8px 0 0">`.
    LOOP AT mt_cr_diag INTO DATA(lv_diag_line).
      lv_diag_html = lv_diag_html &&
        escape( val = lv_diag_line format = cl_abap_format=>e_html_text ) &&
        cl_abap_char_utilities=>newline.
    ENDLOOP.
    lv_diag_html = lv_diag_html && `</pre></details>`.

    REPLACE FIRST OCCURRENCE OF `</body>` IN result WITH lv_diag_html && `</body>`.
  ENDMETHOD.


  METHOD constructor.
    mv_object_type = i_object_type.
    mv_object_name = i_object_name.
    " Member vars already have correct defaults (show_diff/no_toc/compact = X, two_pane = ' ')
    " Override only when settings explicitly provided
    IF is_settings IS SUPPLIED.
      mv_show_diff      = is_settings-show_diff.
      mv_layout         = is_settings-layout.
      mv_two_pane       = is_settings-two_pane.
      mv_no_toc                     = is_settings-no_toc.
      zcl_ave_popup_data=>mv_no_toc = is_settings-no_toc.
      mv_compact        = is_settings-compact.
      mv_remove_dup     = is_settings-remove_dup.
      mv_blame          = is_settings-blame.
      mv_ignore_case    = is_settings-ignore_case.
      mv_filter_user    = is_settings-filter_user.
      mv_date_from      = is_settings-date_from.
      mv_code_review    = is_settings-code_review.
      mv_system         = is_settings-system.
      mv_filter_korrnum = is_settings-filter_korrnum.
      mt_filter_korrnums = is_settings-filter_korrnums.
      mv_desination = is_settings-destination.
      mv_model = is_settings-model.
      mv_apikey = is_settings-apikey.
    ENDIF.

    IF mt_filter_korrnums IS INITIAL AND mv_filter_korrnum IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = mv_filter_korrnum ) TO mt_filter_korrnums.
    ENDIF.

    IF mt_filter_korrnums IS NOT INITIAL.
      DATA lt_filter_tasks TYPE zif_ave_object=>ty_t_korr_range.
      TYPES: BEGIN OF ty_filter_task_meta,
               task   TYPE trkorr,
               parent TYPE trkorr,
               datum  TYPE e070-as4date,
               zeit   TYPE e070-as4time,
             END OF ty_filter_task_meta.
      DATA lt_filter_task_meta TYPE STANDARD TABLE OF ty_filter_task_meta WITH DEFAULT KEY.
      DATA(lv_filter_total) = lines( mt_filter_korrnums ).
      LOOP AT mt_filter_korrnums INTO DATA(ls_filter_korrnum)
        WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING
            percentage = CONV i( sy-tabix * 10 / COND i( WHEN lv_filter_total > 0 THEN lv_filter_total ELSE 1 ) )
            text       = CONV char70( |Preparing selected tasks ({ sy-tabix }/{ lv_filter_total })| ).
        SELECT SINGLE trfunction, strkorr, as4date, as4time FROM e070
          WHERE trkorr = @ls_filter_korrnum-low
          INTO (@DATA(lv_filter_trfunction), @DATA(lv_filter_parent),
                @DATA(lv_filter_date), @DATA(lv_filter_time)).
        CHECK sy-subrc = 0.

        IF lv_filter_trfunction = 'S'.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_filter_korrnum-low ) TO lt_filter_tasks.
          APPEND VALUE #(
            task   = ls_filter_korrnum-low
            parent = COND #( WHEN lv_filter_parent IS NOT INITIAL THEN lv_filter_parent ELSE ls_filter_korrnum-low )
            datum  = lv_filter_date
            zeit   = lv_filter_time ) TO lt_filter_task_meta.
          APPEND VALUE #(
            sign   = 'I'
            option = 'EQ'
            low    = COND #( WHEN lv_filter_parent IS NOT INITIAL THEN lv_filter_parent ELSE ls_filter_korrnum-low ) )
            TO mt_filter_parent_korrnums.
        ELSE.
          SELECT trkorr, strkorr, as4date, as4time FROM e070
            WHERE strkorr = @ls_filter_korrnum-low
              AND trfunction = 'S'
            INTO TABLE @DATA(lt_child_tasks).
          LOOP AT lt_child_tasks INTO DATA(ls_child_task).
            APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_child_task-trkorr ) TO lt_filter_tasks.
            APPEND VALUE #(
              task   = ls_child_task-trkorr
              parent = ls_child_task-strkorr
              datum  = ls_child_task-as4date
              zeit   = ls_child_task-as4time ) TO lt_filter_task_meta.
            APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_child_task-strkorr )
              TO mt_filter_parent_korrnums.
          ENDLOOP.
          IF lt_child_tasks IS INITIAL.
            APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_filter_korrnum-low )
              TO mt_filter_parent_korrnums.
          ENDIF.
        ENDIF.
      ENDLOOP.

      IF lt_filter_tasks IS NOT INITIAL.
        SORT lt_filter_tasks BY low.
        DELETE ADJACENT DUPLICATES FROM lt_filter_tasks COMPARING low.
        mt_filter_korrnums = lt_filter_tasks.
      ENDIF.
      SORT mt_filter_parent_korrnums BY low.
      DELETE ADJACENT DUPLICATES FROM mt_filter_parent_korrnums COMPARING low.

      DATA lv_oldest_date TYPE e070-as4date.
      DATA lv_oldest_time TYPE e070-as4time.
      DATA lv_newest_date TYPE e070-as4date.
      DATA lv_newest_time TYPE e070-as4time.
      LOOP AT lt_filter_task_meta INTO DATA(ls_filter_task_meta).
        IF mv_oldest_filter_korrnum IS INITIAL
          OR ls_filter_task_meta-datum < lv_oldest_date
          OR ( ls_filter_task_meta-datum = lv_oldest_date AND ls_filter_task_meta-zeit < lv_oldest_time ).
          mv_oldest_filter_korrnum = ls_filter_task_meta-parent.
          lv_oldest_date = ls_filter_task_meta-datum.
          lv_oldest_time = ls_filter_task_meta-zeit.
        ENDIF.
        IF mv_filter_korrnum IS INITIAL
          OR ls_filter_task_meta-datum > lv_newest_date
          OR ( ls_filter_task_meta-datum = lv_newest_date AND ls_filter_task_meta-zeit > lv_newest_time ).
          mv_filter_korrnum = ls_filter_task_meta-parent.
          lv_newest_date = ls_filter_task_meta-datum.
          lv_newest_time = ls_filter_task_meta-zeit.
        ENDIF.
      ENDLOOP.

      IF mv_filter_korrnum IS INITIAL.
        mv_filter_korrnum = mt_filter_korrnums[ 1 ]-low.
      ENDIF.
    ENDIF.

    " In TR mode, if no explicit filter_korrnum supplied, use the TR name itself
    IF mv_filter_korrnum IS INITIAL
      AND mv_object_type = zcl_ave_object_factory=>gc_type-tr.
      mv_filter_korrnum = CONV trkorr( mv_object_name ).
      IF mt_filter_korrnums IS INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = mv_filter_korrnum ) TO mt_filter_korrnums.
      ENDIF.
      IF mt_filter_parent_korrnums IS INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = mv_filter_korrnum ) TO mt_filter_parent_korrnums.
      ENDIF.
      IF mv_oldest_filter_korrnum IS INITIAL.
        mv_oldest_filter_korrnum = mv_filter_korrnum.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD show.
    build_layout( ).
    build_parts_list( ).
    build_html_viewer( ).
    build_versions_grid( ).

    " Code Review: auto-open report immediately in maximized view
    IF mv_code_review = abap_true AND mv_cr_report_html IS NOT INITIAL.
      IF open_saved_code_review( ) = abap_false.
        maximize_html( ).
        set_html( mv_cr_report_html ).
      ENDIF.
      cl_gui_cfw=>flush( ).
      RETURN.
    ENDIF.

    " Auto-open the first part only for single-object views (class/program/intf/func).
    " For TR / package the user picks a row manually — auto-loading versions for
    " an arbitrary "first" object is slow and usually not what they want.
    IF mv_object_type <> zcl_ave_object_factory=>gc_type-tr
       AND mv_object_type <> zcl_ave_object_factory=>gc_type-package.
      LOOP AT mt_parts INTO DATA(ls_first)
        WHERE exists_flag = abap_true.
        CHECK zcl_ave_popup_data=>is_supported_object_type( ls_first-type ) = abap_true.
        mv_cur_objtype = ls_first-type.
        mv_cur_objname = ls_first-object_name.
        load_versions( i_objtype = ls_first-type i_objname = ls_first-object_name ).
        refresh_vers( ).
        IF mt_versions IS NOT INITIAL.
          ms_base_ver = mt_versions[ 1 ].
          mv_viewed_versno = ms_base_ver-versno.
          IF mv_show_diff = abap_true.
            READ TABLE mt_versions INTO DATA(ls_prev_auto) INDEX 2.
            " No previous version → show as new object (all-green diff vs empty source)
            auto_show_diff_or_source( is_old = ls_prev_auto is_new = ms_base_ver ).
          ELSE.
            show_source( i_objtype = ms_base_ver-objtype
                         i_objname = ms_base_ver-objname
                         i_versno  = ms_base_ver-versno ).
          ENDIF.
          update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
        ENDIF.
        EXIT.
      ENDLOOP.
    ENDIF.

    cl_gui_cfw=>flush( ).
  ENDMETHOD.


  METHOD build_layout.

    ADD 1 TO mv_counter.

    CREATE OBJECT mo_box
      EXPORTING
        width                       = 1300
        height                      = 345
        top                         = 25
        left                        = 50
        caption                     = |{ mv_object_type }: { mv_object_name }|
        lifetime                    = cl_gui_control=>lifetime_dynpro
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0. RETURN. ENDIF.

    SET HANDLER me->on_box_close FOR mo_box.

    " Outer splitter: row 1 = toolbar, row 2 = content
    DATA(lo_split_outer) = NEW cl_gui_splitter_container(
      parent  = mo_box
      rows    = 2
      columns = 1 ).
    lo_split_outer->set_row_height( id = 1 height = 4 ).
    lo_split_outer->set_row_sash( id = 1 type = 0 value = 0 ).
    mo_cont_toolbar = lo_split_outer->get_container( row = 1 column = 1 ).
    DATA(lo_cont_main) = lo_split_outer->get_container( row = 2 column = 1 ).

    " Wrapper: row 1 = normal layout, row 2 = 2-pane layout (hidden initially)
    mo_split_wrap = NEW cl_gui_splitter_container(
      parent  = lo_cont_main
      rows    = 2
      columns = 1 ).
    mo_split_wrap->set_row_height( id = 1 height = 100 ).
    mo_split_wrap->set_row_height( id = 2 height = 0 ).
    mo_split_wrap->set_row_sash( id = 1 type = 0 value = 0 ).
    mo_split_wrap->set_row_sash( id = 2 type = 0 value = 0 ).
    DATA(lo_normal) = mo_split_wrap->get_container( row = 1 column = 1 ).
    DATA(lo_2pane)  = mo_split_wrap->get_container( row = 2 column = 1 ).

    " ── Normal layout: [parts+vers | html] ──────────────────────────
    CREATE OBJECT mo_split_main
      EXPORTING
        parent  = lo_normal
        rows    = 1
        columns = 2.
    mo_split_main->set_column_width( id = 1 width = 40 ).
    mo_split_main->set_column_width( id = 2 width = 60 ).
    DATA(lo_top) = mo_split_main->get_container( row = 1 column = 1 ).
    CREATE OBJECT mo_split_top
      EXPORTING
        parent  = lo_top
        rows    = 2
        columns = 1.
    mo_split_top->set_row_height( id = 1 height = 60 ).
    mo_cont_parts = mo_split_top->get_container( row = 1 column = 1 ).
    mo_cont_vers  = mo_split_top->get_container( row = 2 column = 1 ).
    mo_cont_html  = mo_split_main->get_container( row = 1 column = 2 ).

    " ── 2-pane layout: [parts | vers] top + [html] bottom ───────────
    mo_split_2p_wrap = NEW cl_gui_splitter_container(
      parent  = lo_2pane
      rows    = 2
      columns = 1 ).
    DATA(lo_2p_wrap) = mo_split_2p_wrap.
    lo_2p_wrap->set_row_height( id = 1 height = 35 ).
    mo_split_2p_top = NEW cl_gui_splitter_container(
      parent  = lo_2p_wrap->get_container( row = 1 column = 1 )
      rows    = 1
      columns = 2 ).
    mo_split_2p_top->set_column_width( id = 1 width = 25 ).
    mo_split_2p_top->set_column_width( id = 2 width = 75 ).
    mo_cont_parts_2p = mo_split_2p_top->get_container( row = 1 column = 1 ).
    mo_cont_vers_2p  = mo_split_2p_top->get_container( row = 1 column = 2 ).
    mo_cont_html_2p  = lo_2p_wrap->get_container( row = 2 column = 1 ).

    " If starting in TOP-DOWN layout — flip wrapper and point containers
    IF mv_layout = abap_false.
      mo_split_wrap->set_row_height( id = 1 height = 0 ).
      mo_split_wrap->set_row_height( id = 2 height = 100 ).
      mo_cont_parts = mo_cont_parts_2p.
      mo_cont_vers  = mo_cont_vers_2p.
      mo_cont_html  = mo_cont_html_2p.
    ENDIF.

    " For single-object types (program / function) — hide parts, give versions 100%
    IF mv_object_type = zcl_ave_object_factory=>gc_type-program OR
       mv_object_type = zcl_ave_object_factory=>gc_type-function.
      mo_split_top->set_row_height(    id = 1 height = 0   ).
      mo_split_top->set_row_height(    id = 2 height = 100 ).
      mo_split_2p_top->set_column_width( id = 1 width  = 0   ).
      mo_split_2p_top->set_column_width( id = 2 width  = 100 ).
    ENDIF.
  ENDMETHOD.


  METHOD build_parts_list.
    " Load parts via object handler factory
    TRY.
        IF mv_object_type = zcl_ave_object_factory=>gc_type-class.
          " CLASS: filter empty includes, no existence check needed
          mt_parts = get_class_parts( CONV #( mv_object_name ) ).
        ELSE.
          DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
            object_type = mv_object_type
            object_name = CONV #( mv_object_name ) ).
          DATA(lv_is_tr) = boolc( mv_object_type = zcl_ave_object_factory=>gc_type-tr ).
          TYPES: BEGIN OF ty_part_request,
                   type        TYPE versobjtyp,
                   object_name TYPE versobjnam,
                   class       TYPE string,
                   unit        TYPE string,
                   requests    TYPE string,
                   parent_requests TYPE string,
                 END OF ty_part_request.
          TYPES: BEGIN OF ty_part_tr_key,
                   trkorr TYPE trkorr,
                 END OF ty_part_tr_key.
          DATA lt_raw_parts TYPE zif_ave_object=>ty_t_part.
          DATA lt_korr_parts TYPE STANDARD TABLE OF trkorr WITH DEFAULT KEY.
          DATA lt_part_requests TYPE HASHED TABLE OF ty_part_request
            WITH UNIQUE KEY type object_name class unit.
          IF lv_is_tr = abap_true AND mt_filter_korrnums IS NOT INITIAL.
            LOOP AT mt_filter_korrnums INTO DATA(ls_part_korrnum)
              WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
              APPEND ls_part_korrnum-low TO lt_korr_parts.
            ENDLOOP.
            SORT lt_korr_parts.
            DELETE ADJACENT DUPLICATES FROM lt_korr_parts.
          ENDIF.
          DATA(lv_korr_parts_total) = lines( lt_korr_parts ).
          LOOP AT lt_korr_parts INTO DATA(lv_korr_part).
            CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
              EXPORTING percentage = CONV i( 10 + sy-tabix * 25 / COND i( WHEN lv_korr_parts_total > 0 THEN lv_korr_parts_total ELSE 1 ) )
                        text       = CONV char70( |Reading task objects ({ sy-tabix }/{ lv_korr_parts_total }) { lv_korr_part }| ).
            TRY.
                DATA(lv_korr_part_text) = CONV string( lv_korr_part ).
                DATA(lv_parent_korr_part) = lv_korr_part.
                SELECT SINGLE strkorr FROM e070
                  WHERE trkorr = @lv_korr_part
                    AND trfunction = 'S'
                  INTO @DATA(lv_parent_korr_part_db).
                IF sy-subrc = 0 AND lv_parent_korr_part_db IS NOT INITIAL.
                  lv_parent_korr_part = lv_parent_korr_part_db.
                ENDIF.
                DATA(lv_parent_korr_part_text) = CONV string( lv_parent_korr_part ).
                DATA(lo_range_obj) = NEW zcl_ave_object_factory( )->get_instance(
                  object_type = mv_object_type
                  object_name = CONV #( lv_korr_part ) ).
                LOOP AT lo_range_obj->get_parts( ) INTO DATA(ls_range_part).
                  APPEND ls_range_part TO lt_raw_parts.
                  ASSIGN lt_part_requests[
                    type        = ls_range_part-type
                    object_name = ls_range_part-object_name
                    class       = ls_range_part-class
                    unit        = ls_range_part-unit ] TO FIELD-SYMBOL(<part_request>).
                  IF sy-subrc <> 0.
                    INSERT VALUE #(
                      type        = ls_range_part-type
                      object_name = ls_range_part-object_name
                      class       = ls_range_part-class
                      unit        = ls_range_part-unit
                      requests    = lv_korr_part_text
                      parent_requests = lv_parent_korr_part_text ) INTO TABLE lt_part_requests.
                  ELSE.
                    IF <part_request>-requests NS lv_korr_part_text.
                      <part_request>-requests = |{ <part_request>-requests }, { lv_korr_part }|.
                    ENDIF.
                    IF <part_request>-parent_requests NS lv_parent_korr_part_text.
                      <part_request>-parent_requests = |{ <part_request>-parent_requests }, { lv_parent_korr_part }|.
                    ENDIF.
                  ENDIF.
                ENDLOOP.
              CATCH zcx_ave.
            ENDTRY.
          ENDLOOP.
          IF lt_raw_parts IS INITIAL.
            lt_raw_parts = lo_obj->get_parts( ).
          ENDIF.
          SORT lt_raw_parts BY type object_name class unit.
          DELETE ADJACENT DUPLICATES FROM lt_raw_parts COMPARING type object_name class unit.
          DATA(lv_raw_parts_total) = lines( lt_raw_parts ).
          LOOP AT lt_raw_parts INTO DATA(ls_raw).
            IF mv_code_review = abap_false
               AND ( sy-tabix = 1 OR sy-tabix = lv_raw_parts_total OR sy-tabix MOD 5 = 0 ).
              CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
                EXPORTING percentage = CONV i( 35 + sy-tabix * 35 / COND i( WHEN lv_raw_parts_total > 0 THEN lv_raw_parts_total ELSE 1 ) )
                          text       = CONV char70( |Preparing parts ({ sy-tabix }/{ lv_raw_parts_total }) { ls_raw-object_name }| ).
            ENDIF.
            CHECK ls_raw-type <> 'RELE'.
            DATA(lv_exists) = COND abap_bool(
              WHEN mv_code_review = abap_true
              THEN abap_true
              WHEN lv_is_tr = abap_true
              THEN zcl_ave_popup_data=>check_part_exists(
                     i_type       = ls_raw-type
                     i_name       = CONV #( ls_raw-unit )
                     i_class_name = CONV #( ls_raw-class ) )
              ELSE abap_true ).
            DATA ls_row TYPE ty_part_row.
            ls_row-class       = ls_raw-class.
            ls_row-name        = ls_raw-unit.
            ls_row-type        = ls_raw-type.
            ls_row-type_text   = zcl_ave_popup_data=>get_type_text( ls_raw-type ).
            ls_row-object_name = ls_raw-object_name.
            IF lt_part_requests IS NOT INITIAL.
              READ TABLE lt_part_requests INTO DATA(ls_part_request)
                WITH TABLE KEY type        = ls_raw-type
                               object_name = ls_raw-object_name
                               class       = ls_raw-class
                               unit        = ls_raw-unit.
              IF sy-subrc = 0.
                ls_row-requests = ls_part_request-requests.
                DATA lt_part_tasks_for_trs TYPE string_table.
                DATA lt_part_trs TYPE SORTED TABLE OF ty_part_tr_key WITH UNIQUE KEY trkorr.
                SPLIT ls_row-requests AT `,` INTO TABLE lt_part_tasks_for_trs.
                LOOP AT lt_part_tasks_for_trs INTO DATA(lv_part_task_for_tr).
                  CONDENSE lv_part_task_for_tr.
                  CHECK lv_part_task_for_tr IS NOT INITIAL.
                  DATA(lv_part_parent_tr) = CONV trkorr( lv_part_task_for_tr ).
                  SELECT SINGLE strkorr FROM e070
                    WHERE trkorr = @lv_part_parent_tr
                      AND trfunction = 'S'
                    INTO @DATA(lv_part_parent_tr_db).
                  IF sy-subrc = 0 AND lv_part_parent_tr_db IS NOT INITIAL.
                    lv_part_parent_tr = lv_part_parent_tr_db.
                  ENDIF.
                  INSERT VALUE #( trkorr = lv_part_parent_tr ) INTO TABLE lt_part_trs.
                ENDLOOP.
                ls_row-trs = lines( lt_part_trs ).
              ENDIF.
            ELSEIF lv_is_tr = abap_true.
              ls_row-requests = mv_object_name.
              ls_row-trs = 1.
            ENDIF.
            ls_row-exists_flag = lv_exists.
            ls_row-rows        = COND i( WHEN lv_exists = abap_true
                                           AND mv_code_review = abap_false
              THEN zcl_ave_popup_data=>get_active_line_count( i_type = ls_raw-type i_name = ls_raw-object_name )
              ELSE 0 ).
            IF lv_exists = abap_false.
              ls_row-rowcolor = 'C601'.   " red
            ELSEIF mv_filter_user IS NOT INITIAL AND mv_code_review = abap_false.
              DATA lv_changed TYPE abap_bool.
              IF lv_is_tr = abap_true AND lt_korr_parts IS NOT INITIAL.
                LOOP AT lt_korr_parts INTO DATA(lv_check_korr).
                  DATA(lv_check_version_korr) = lv_check_korr.
                  SELECT SINGLE strkorr FROM e070
                    WHERE trkorr = @lv_check_korr
                      AND trfunction = 'S'
                    INTO @DATA(lv_check_parent_korr).
                  IF sy-subrc = 0 AND lv_check_parent_korr IS NOT INITIAL.
                    lv_check_version_korr = lv_check_parent_korr.
                  ENDIF.
                  lv_changed = COND abap_bool(
                    WHEN ls_raw-type = 'CLAS'
                    THEN zcl_ave_popup_data=>check_class_has_author(
                           i_class_name = CONV #( ls_raw-object_name )
                           i_korrnum    = CONV verskorrno( lv_check_version_korr )
                           i_ignore_case = mv_ignore_case )
                    ELSE zcl_ave_popup_data=>is_substantive_user_change(
                           it_versions = zcl_ave_popup_data=>build_versions_for_check( i_type = ls_raw-type i_name = ls_raw-object_name )
                           i_type      = ls_raw-type
                           i_name      = ls_raw-object_name
                           i_korrnum   = CONV verskorrno( lv_check_version_korr )
                           i_ignore_case = mv_ignore_case ) ).
                  IF lv_changed = abap_true.
                    EXIT.
                  ENDIF.
                ENDLOOP.
              ELSE.
                lv_changed = COND abap_bool(
                  WHEN ls_raw-type = 'CLAS'
                  THEN zcl_ave_popup_data=>check_class_has_author(
                         i_class_name = CONV #( ls_raw-object_name )
                         i_korrnum    = COND #( WHEN lv_is_tr = abap_true THEN CONV verskorrno( mv_object_name ) )
                         i_ignore_case = mv_ignore_case )
                  ELSE zcl_ave_popup_data=>is_substantive_user_change(
                         it_versions = zcl_ave_popup_data=>build_versions_for_check( i_type = ls_raw-type i_name = ls_raw-object_name )
                         i_type      = ls_raw-type
                         i_name      = ls_raw-object_name
                         i_korrnum   = COND #( WHEN lv_is_tr = abap_true THEN CONV verskorrno( mv_object_name ) )
                         i_ignore_case = mv_ignore_case ) ).
              ENDIF.
              IF lv_changed = abap_true.
                ls_row-rowcolor = 'C510'. " green
              ENDIF.
            ENDIF.
            IF ls_row-rowcolor IS INITIAL.
              IF ls_raw-type <> 'METH' AND ls_raw-type <> 'CPUB'  AND ls_raw-type <> 'CPRO' AND ls_raw-type <> 'CPRI' AND
                 ls_raw-type <> 'REPS' AND ls_raw-type <> 'PROG' AND ls_raw-type <> 'CLSD' AND ls_raw-type <> 'CLAS' AND
                 ls_raw-type <> 'DDLS'.
                ls_row-rowcolor = 'C201'. " not supported obj
              ENDIF.
            ENDIF.
            APPEND ls_row TO mt_parts.
            CLEAR ls_row.
          ENDLOOP.
        ENDIF.
      CATCH zcx_ave.
        " leave mt_parts empty – no crash
    ENDTRY.

    IF mv_code_review = abap_true.
      CLEAR: mt_acr_stats, mt_hunk_info, mt_hunk_threads,
             mt_approved, mt_declined, mt_decline_notes,
             mv_cr_base_html, mv_cr_cur_key, mv_decline_view_user.
      mv_cr_prepared = abap_false.
      mv_cr_report_html = build_cr_object_report_html( ).

      " Insert REPORT pseudo-part at the top of the list
      DATA(lv_total_acr) = lines( mt_parts ).
      DATA(ls_rpt) = VALUE ty_part_row(
        type      = 'RPT'
        name      = |[ Code Review Report - { lv_total_acr } object(s) ]|
        type_text = 'Report'
        rows      = lv_total_acr ).
      INSERT ls_rpt INTO mt_parts INDEX 1.
    ENDIF.

    " ── Toolbar (full-width top row, container from build_layout) ──
    CREATE OBJECT mo_toolbar EXPORTING parent = mo_cont_toolbar.
    DATA lt_tb_events TYPE cntl_simple_events.
    APPEND VALUE #( eventid = cl_gui_toolbar=>m_id_function_selected ) TO lt_tb_events.
    mo_toolbar->set_registered_events( lt_tb_events ).
    SET HANDLER me->on_toolbar_click FOR mo_toolbar.
    IF mv_code_review = abap_true.
      mo_toolbar->add_button_group( VALUE ttb_button(
        ( function  = 'PANE_TOGGLE'
          icon      = CONV #( icon_spool_request )
          text      = 'Inline'
          quickinfo = 'Inline' )
        ( function  = 'COMPACT_TOGGLE'
          icon      = CONV #( icon_collapse_all )
          text      = 'Compact'
          quickinfo = 'Compact' )
        ( function  = 'FOCUS_TOGGLE'
          icon      = CONV #( icon_view_maximize )
          text      = 'Maximize View'
          quickinfo = 'Hide parts/versions, expand HTML' )
        ( function  = 'INFO'
          icon      = CONV #( icon_bw_gis )
          text      = ''
          quickinfo = 'Documentation' ) ) ).
      mo_toolbar->add_button_group( VALUE ttb_button(
        ( function  = 'SAVE_REVIEW'
          icon      = CONV #( icon_system_save )
          text      = 'Save'
          quickinfo = 'Save review' ) ) ).
    ELSE.
      mo_toolbar->add_button_group( VALUE ttb_button(
        ( function  = 'REFRESH'
          icon      = CONV #( icon_refresh )
          text      = 'Refresh'
          quickinfo = 'Refresh' )
        ( function  = 'PANE_TOGGLE'
          icon      = CONV #( icon_spool_request )
          text      = 'Inline'
          quickinfo = 'Inline' )
        ( function  = 'DIFF_TOGGLE'
          icon      = CONV #( icon_compare )
          text      = 'Show Diff'
          quickinfo = 'Show Diff' )
        ( function  = 'COMPACT_TOGGLE'
          icon      = CONV #( icon_collapse_all )
          text      = 'Compact'
          quickinfo = 'Compact' )
        ( function  = 'BLAME_TOGGLE'
          icon      = CONV #( icon_history )
          text      = 'Blame'
          quickinfo = 'Toggle Blame' )
        ( function  = 'FOCUS_TOGGLE'
          icon      = CONV #( icon_view_maximize )
          text      = 'Maximize View'
          quickinfo = 'Hide parts/versions, expand HTML' )
        ( function  = 'DEBUG'
          icon      = CONV #( icon_bw_dm_aa )
          text      = 'Debug'
          quickinfo = 'Show diff ops + pairing decisions' )
        ( function  = 'INFO'
          icon      = CONV #( icon_bw_gis )
          text      = ''
          quickinfo = 'Documentation' ) ) ).
    ENDIF.

    " Sync button texts with initial flag values
    mo_toolbar->set_button_info( EXPORTING fcode = 'COMPACT_TOGGLE'
      text = COND #( WHEN mv_compact   = abap_true THEN 'Compact'   ELSE 'Full'      ) ).
    mo_toolbar->set_button_info( EXPORTING fcode = 'PANE_TOGGLE'
      text = COND #( WHEN mv_two_pane  = abap_true THEN '2-Pane'    ELSE 'Inline'    ) ).
    IF mv_code_review = abap_false.
      mo_toolbar->set_button_info( EXPORTING fcode = 'DIFF_TOGGLE'
        text = COND #( WHEN mv_show_diff = abap_true THEN 'Show Diff' ELSE 'Show Vers' ) ).
      mo_toolbar->set_button_info( EXPORTING fcode = 'BLAME_TOGGLE'
        text = COND #( WHEN mv_blame     = abap_true THEN 'Blame ON'  ELSE 'Blame'     ) ).
    ENDIF.

    create_parts_alv( ).
  ENDMETHOD.


  METHOD create_parts_alv.
    " ── Field catalog ──
    DATA lt_fcat TYPE lvc_t_fcat.
    DATA ls_fc   TYPE lvc_s_fcat.

    CLEAR ls_fc. ls_fc-fieldname = 'TYPE'.        ls_fc-coltext = 'Type'.
    ls_fc-outputlen = 6.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'NAME'.        ls_fc-coltext = 'Object'.
    ls_fc-outputlen = 30. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'CLASS'.       ls_fc-coltext = 'Class'.
    ls_fc-outputlen = 20. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'TYPE_TEXT'.   ls_fc-coltext = 'Type Description'.
    ls_fc-outputlen = 30. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'REQUESTS'.    ls_fc-coltext = 'Request'.
    ls_fc-outputlen = 24. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'ROWS'.        ls_fc-coltext = 'Rows'.
    ls_fc-outputlen = 6. ls_fc-just = 'R'. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJECT_NAME'. ls_fc-coltext = 'Object'.
    ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'EXISTS_FLAG'. ls_fc-coltext = 'Exists'.
    ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'ROWCOLOR'.    ls_fc-coltext = 'Color'.
    ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.

    " ── Layout ──
    DATA ls_layo TYPE lvc_s_layo.
    ls_layo-zebra      = abap_true.
    ls_layo-info_fname = 'ROWCOLOR'.
    ls_layo-cwidth_opt = abap_true.
    ls_layo-no_toolbar = abap_false.
    ls_layo-sel_mode   = 'A'.

    " ── Create ALV Grid ──
    mo_alv_parts = NEW cl_gui_alv_grid( i_parent = mo_cont_parts ).

    SET HANDLER me->handle_parts_toolbar  FOR mo_alv_parts.
    SET HANDLER me->handle_parts_command  FOR mo_alv_parts.
    SET HANDLER me->handle_parts_dblclick FOR mo_alv_parts.

    mo_alv_parts->set_table_for_first_display(
      EXPORTING
        is_layout       = ls_layo
        i_save          = 'A'
        i_default       = 'X'
      CHANGING
        it_fieldcatalog = lt_fcat
        it_outtab       = mt_parts ).

    mo_alv_parts->set_toolbar_interactive( ).
  ENDMETHOD.


  METHOD build_html_viewer.
    create_html_viewer( ).
  ENDMETHOD.


  METHOD create_html_viewer.
    " Split mo_cont_html into two rows: HTML on top (diff), ABAP editor
    " on bottom (single-version source). Only one has non-zero height.
    CREATE OBJECT mo_split_html
      EXPORTING parent = mo_cont_html rows = 2 columns = 1.
    mo_cont_html_diff = mo_split_html->get_container( row = 1 column = 1 ).
    mo_cont_html_code = mo_split_html->get_container( row = 2 column = 1 ).
    mo_split_html->set_row_height( id = 1 height = 100 ).
    mo_split_html->set_row_height( id = 2 height = 0 ).

    CREATE OBJECT mo_html
      EXPORTING
        parent             = mo_cont_html_diff
      EXCEPTIONS
        cntl_error         = 1
        cntl_install_error = 2
        dp_install_error   = 3
        dp_error           = 4
        OTHERS             = 5.
    DATA lt_html_ev TYPE cntl_simple_events.
    APPEND VALUE #( eventid = cl_gui_html_viewer=>m_id_sapevent ) TO lt_html_ev.
    mo_html->set_registered_events( lt_html_ev ).
    SET HANDLER me->on_sapevent FOR mo_html.

    CREATE OBJECT mo_code_viewer
      EXPORTING parent = mo_cont_html_code max_number_chars = 255.
    mo_code_viewer->upload_properties( EXCEPTIONS OTHERS = 1 ).
    mo_code_viewer->set_statusbar_mode( statusbar_mode = cl_gui_abapedit=>true ).
    mo_code_viewer->create_document( ).
    mo_code_viewer->set_readonly_mode( 1 ).

    set_html(
      |<!DOCTYPE html><html><head><style>| &&
      |body\{margin:0;background:#f8f8f8;color:#999;| &&
      |font:13px/1.6 Consolas,monospace;| &&
      |display:flex;align-items:center;justify-content:center;height:100vh\}| &&
      |</style></head><body>| &&
      |<div>Double-click a part on the left to open its latest version.</div>| &&
      |</body></html>| ).
  ENDMETHOD.


  METHOD build_versions_grid.
    create_versions_alv( ).
  ENDMETHOD.


  METHOD create_versions_alv.
    " ── Field catalog ──
    DATA lt_fcat TYPE lvc_t_fcat.
    DATA ls_fc   TYPE lvc_s_fcat.

    CLEAR ls_fc. ls_fc-fieldname = 'SYSTEM'.       ls_fc-coltext = 'System'.
    ls_fc-outputlen = 8.
    ls_fc-no_out = COND #( WHEN mv_system IS INITIAL THEN abap_true ELSE abap_false ).
    APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'VERSNO'.      ls_fc-no_out = abap_true.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'VERSNO_TEXT'. ls_fc-coltext = 'Version'.
    ls_fc-outputlen = 8.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'DATUM'.       ls_fc-coltext = 'Date'.
    ls_fc-outputlen = 10. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'ZEIT'.        ls_fc-coltext = 'Time'.
    ls_fc-outputlen = 8.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'AUTHOR'.      ls_fc-coltext = 'Author'.
    ls_fc-outputlen = 12. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'AUTHOR_NAME'.    ls_fc-coltext = 'Name'.
    ls_fc-outputlen = 20. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJ_OWNER'.      ls_fc-coltext = 'Obj Owner'.
    ls_fc-outputlen = 12. ls_fc-emphasize = 'C401'. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJ_OWNER_NAME'. ls_fc-coltext = 'Owner Name'.
    ls_fc-outputlen = 20. ls_fc-emphasize = 'C401'. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'KORRNUM'.     ls_fc-coltext = 'Request'.
    ls_fc-outputlen = 12. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'TRFUNCTION'.  ls_fc-coltext = 'Type'.
    ls_fc-outputlen = 4.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'TASK'.        ls_fc-coltext = 'Task'.
    ls_fc-outputlen = 12. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'KORR_TEXT'.   ls_fc-coltext = 'Description'.
    ls_fc-outputlen = 40. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJNAME'.     ls_fc-coltext = 'Object'.
    ls_fc-outputlen = 30. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJTYPE'.     ls_fc-coltext = 'Type'.
    ls_fc-outputlen = 6.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'ROWCOLOR'.    ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.

    " ── Layout ──
    DATA ls_layo TYPE lvc_s_layo.
    ls_layo-zebra      = abap_true.
    ls_layo-info_fname = 'ROWCOLOR'.
    ls_layo-cwidth_opt = abap_true.
    ls_layo-sel_mode   = 'A'.

    " ── Create ALV Grid ──
    mo_alv_vers = NEW cl_gui_alv_grid( i_parent = mo_cont_vers ).

    SET HANDLER me->handle_vers_toolbar  FOR mo_alv_vers.
    SET HANDLER me->handle_vers_command  FOR mo_alv_vers.
    SET HANDLER me->handle_vers_dblclick FOR mo_alv_vers.

    mo_alv_vers->set_table_for_first_display(
      EXPORTING
        is_layout       = ls_layo
        i_save          = 'A'
        i_default       = 'X'
      CHANGING
        it_fieldcatalog = lt_fcat
        it_outtab       = mt_versions ).

    mo_alv_vers->set_toolbar_interactive( ).
  ENDMETHOD.


  METHOD handle_parts_toolbar.
    CLEAR e_object->mt_toolbar.
    CHECK mt_parts_backup IS NOT INITIAL.
    APPEND VALUE stb_button(
      function  = 'BACK'
      icon      = CONV #( icon_previous_object )
      text      = 'Back'
      quickinfo = 'Back'
      butn_type = 0 ) TO e_object->mt_toolbar.
  ENDMETHOD.


  METHOD handle_parts_command.
    CASE e_ucomm.
      WHEN 'BACK'.
        CHECK mt_parts_backup IS NOT INITIAL.
        mt_parts = mt_parts_backup.
        CLEAR: mt_parts_backup, mv_drilled_class.
        refresh_parts( ).
      WHEN OTHERS.
        " pass other commands to toolbar handler (REFRESH etc.)
        on_toolbar_click( fcode = e_ucomm ).
    ENDCASE.
  ENDMETHOD.


  METHOD handle_parts_dblclick.
    DATA(lv_row) = es_row_no-row_id.
    READ TABLE mt_parts INTO DATA(ls_part) INDEX lv_row.
    IF sy-subrc <> 0. RETURN. ENDIF.

    " ── Code Reviewer: REPORT pseudo-part ───────────────────────────
    IF ls_part-type = 'RPT'.
      maximize_html( ).
      set_html( mv_cr_report_html ).
      RETURN.
    ENDIF.

    " ── Code Reviewer: show pre-cached diff if available ───────────
    IF mv_code_review = abap_true.
      READ TABLE mt_acr_stats INTO DATA(ls_stat)
        WITH KEY objtype = ls_part-type obj_name = ls_part-object_name.
      IF sy-subrc = 0.
        DATA(ls_ck) = VALUE ty_diff_cache_key(
          objtype     = ls_stat-objtype
          objname     = ls_stat-obj_name
          versno_o    = ls_stat-versno_old
          versno_n    = ls_stat-versno_new
          blame       = mv_blame
          two_pane    = mv_two_pane
          compact     = mv_compact
          debug       = mv_debug
          ignore_case = mv_ignore_case ).
        READ TABLE mt_diff_cache INTO DATA(ls_ch) WITH TABLE KEY key = ls_ck.
        IF sy-subrc = 0.
          mv_cur_objtype   = ls_part-type.
          mv_cur_objname   = ls_part-object_name.
          mv_cur_part_name = COND string(
            WHEN ls_part-class IS NOT INITIAL THEN |{ ls_part-class } – { ls_part-name }|
            ELSE ls_part-name ).
          mv_cr_cur_key   = |{ ls_stat-objtype }~{ ls_stat-obj_name }|.
          mv_cr_base_html = ls_ch-html.
          " Restore layout (un-maximize) so versions grid is visible
          mv_focus_html = abap_false.
          mo_split_main->set_column_width( id = 1 width = 20 ).
          mo_split_main->set_column_width( id = 2 width = 80 ).
          mo_split_main->set_column_sash( id = 1 type = 1 value = 0 ).
          mo_split_2p_wrap->set_row_height( id = 1 height = 35 ).
          mo_split_2p_wrap->set_row_height( id = 2 height = 65 ).
          mo_split_2p_wrap->set_row_sash( id = 1 type = 1 value = 0 ).
          " Load versions for this part so the grid is populated
          load_versions( i_objtype = ls_part-type i_objname = ls_part-object_name ).
          refresh_vers( ).
          set_html( inject_approve_btn( iv_html = ls_ch-html iv_key = mv_cr_cur_key ) ).
          RETURN.
        ENDIF.
      ENDIF.
      " No cache — fall through to standard Version Explorer diff mechanism
    ENDIF.

    " ── CLAS row (from TR) ──────────────────────────────────────────
    IF ls_part-type = 'CLAS'.
      IF ls_part-exists_flag = abap_false.
        set_html(
          |<!DOCTYPE html><html><head><style>| &&
          |body\{font:13px/1.8 Consolas,sans-serif;background:#fff8f8;| &&
          |padding:24px;color:#333\}| &&
          |h3\{color:#c0392b;margin-bottom:8px\}| &&
          |.lbl\{color:#888;font-size:11px\}.val\{font-weight:bold\}| &&
          |</style></head><body>| &&
          |<h3>&#9888; Object not found in system</h3>| &&
          |<p><span class="lbl">Type:</span> <span class="val">CLAS</span></p>| &&
          |<p><span class="lbl">Name:</span> | &&
          |<span class="val">{ ls_part-object_name }</span></p>| &&
          |</body></html>| ).
      ELSE.
        mt_parts_backup = mt_parts.
        mv_drilled_class = ls_part-object_name.
        CLEAR mt_parts.
        TRY.
            mt_parts = get_class_parts( i_name = ls_part-object_name ).
          CATCH zcx_ave.
        ENDTRY.
        refresh_parts( ).
        " Auto-open first part
        READ TABLE mt_parts INTO DATA(ls_first_part) INDEX 1.
        IF sy-subrc = 0.
          mv_cur_objtype   = ls_first_part-type.
          mv_cur_objname   = ls_first_part-object_name.
          mv_cur_part_name = ls_first_part-name.
          load_versions( i_objtype = ls_first_part-type i_objname = ls_first_part-object_name ).
          refresh_vers( ).
          IF mt_versions IS NOT INITIAL.
            ms_base_ver = mt_versions[ 1 ].
            mv_viewed_versno = ms_base_ver-versno.
            IF mv_show_diff = abap_true.
              READ TABLE mt_versions INTO DATA(ls_prev_cls) INDEX 2.
              " No previous version → show as new object (all-green diff vs empty source)
              auto_show_diff_or_source( is_old = ls_prev_cls is_new = ms_base_ver ).
            ELSE.
              show_source( i_objtype = ms_base_ver-objtype
                           i_objname = ms_base_ver-objname
                           i_versno  = ms_base_ver-versno ).
            ENDIF.
            update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
          ENDIF.
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    " ── Unsupported object type ───────────────────────────────────
    IF zcl_ave_popup_data=>is_supported_object_type( ls_part-type ) = abap_false.
      set_html(
        |<html><body style="font:13px Consolas,sans-serif;| &&
        |padding:24px;color:#666">| &&
        |<h3 style="color:#888">&#128683; Not supported</h3>| &&
        |<p>This object type is not supported at the moment.</p>| &&
        |<p style="color:#aaa">Type: { ls_part-type }</p>| &&
        |</body></html>| ).
      RETURN.
    ENDIF.

    mv_cur_objtype   = ls_part-type.
    mv_cur_objname   = ls_part-object_name.
    mv_cur_part_name = COND string(
      WHEN ls_part-class IS NOT INITIAL AND ls_part-class <> mv_object_name
      THEN |{ ls_part-class } – { ls_part-name }|
      ELSE ls_part-name ).

    " ── Object doesn't exist in system ────────────────────────────
    IF ls_part-exists_flag = abap_false.

      " Find last known version date from VRSD
      DATA lv_last_date TYPE versdate.
      DATA lv_last_time TYPE verstime.
      DATA lv_last_auth TYPE versuser.

      SELECT SINGLE datum, zeit, author
        FROM vrsd
        WHERE objtype = @ls_part-type
          AND objname = @ls_part-object_name
"ORDER BY datum DESCENDING, zeit DESCENDING

        INTO (@lv_last_date, @lv_last_time, @lv_last_auth)
        .

      DATA(lv_last_info) = COND string(
        WHEN sy-subrc = 0
        THEN |Last version: { lv_last_date } { lv_last_time } by { lv_last_auth }|
        ELSE |No version history found| ).

      set_html(
        |<!DOCTYPE html><html><head><style>| &&
        |body\{font:13px/1.8 Consolas,sans-serif;background:#fff8f8;| &&
        |padding:24px;color:#333\}| &&
        |h3\{color:#c0392b;margin-bottom:8px\}| &&
        |.lbl\{color:#888;font-size:11px\}| &&
        |.val\{font-weight:bold\}| &&
        |</style></head><body>| &&
        |<h3>&#9888; Object not found in system</h3>| &&
        |<p><span class="lbl">Type:</span> | &&
        |<span class="val">{ ls_part-type }</span></p>| &&
        |<p><span class="lbl">Name:</span> | &&
        |<span class="val">{ ls_part-object_name }</span></p>| &&
        |<p><span class="lbl">{ lv_last_info }</span></p>| &&
        |<p style="margin-top:12px;color:#888;font-size:11px">| &&
        |Previous versions are listed below — | &&
        |double-click to view historical source.</p>| &&
        |</body></html>| ).
      RETURN.
    ENDIF.

    " ── Object exists: normal flow ─────────────────────────────────
    load_versions( i_objtype = ls_part-type i_objname = ls_part-object_name ).

    CLEAR ms_base_ver.
    CLEAR mv_viewed_versno.
    IF mt_versions IS NOT INITIAL.
      " In TR mode: base = version that belongs to the TR, not necessarily Active.
      IF mv_object_type = zcl_ave_object_factory=>gc_type-tr.
        LOOP AT mt_versions INTO ms_base_ver WHERE korrnum = mv_object_name.
          EXIT.
        ENDLOOP.
      ENDIF.
      IF ms_base_ver IS INITIAL.
        ms_base_ver = mt_versions[ 1 ].
      ENDIF.
      mv_viewed_versno = ms_base_ver-versno.
    ENDIF.

    update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
    refresh_vers( ).

    IF mt_versions IS NOT INITIAL.
      IF mv_show_diff = abap_true.
        " Prior = first version before the base (VRSD korrnum is always K-type).
        DATA ls_prev_part TYPE ty_version_row.
        LOOP AT mt_versions INTO ls_prev_part WHERE versno < ms_base_ver-versno.
          EXIT.
        ENDLOOP.
        IF ls_prev_part IS INITIAL.
          LOOP AT mt_versions TRANSPORTING NO FIELDS
            WHERE versno = ms_base_ver-versno
              AND system = ms_base_ver-system.
            READ TABLE mt_versions INTO ls_prev_part INDEX sy-tabix + 1.
            EXIT.
          ENDLOOP.
        ENDIF.
        IF ls_prev_part IS NOT INITIAL.
          auto_show_diff_or_source( is_old = ls_prev_part is_new = ms_base_ver ).
        ELSE.
          show_source( i_objtype = ms_base_ver-objtype
                       i_objname = ms_base_ver-objname
                       i_versno  = ms_base_ver-versno ).
        ENDIF.
      ELSE.
        show_source( i_objtype = ms_base_ver-objtype
                     i_objname = ms_base_ver-objname
                     i_versno  = ms_base_ver-versno ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD load_versions.
    CLEAR mt_versions.
    CLEAR mv_cur_creator.

    DATA lv_date_from TYPE versdate.
    lv_date_from = mv_date_from.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING percentage = 0
                text       = CONV char70( |Loading versions for { i_objtype } { i_objname }| ).

    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd(
          type      = i_objtype
          name      = i_objname
          no_toc    = abap_false
          date_from = lv_date_from ).
      CATCH zcx_ave.
        RETURN.
    ENDTRY.

    DATA(lv_vrsd_total) = lines( lo_vrsd->vrsd_list ).
    LOOP AT lo_vrsd->vrsd_list INTO DATA(ls_vrsd).
      IF sy-tabix = 1 OR sy-tabix = lv_vrsd_total OR sy-tabix MOD 10 = 0.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = CONV i( sy-tabix * 20 / COND i( WHEN lv_vrsd_total > 0 THEN lv_vrsd_total ELSE 1 ) )
                    text       = CONV char70( |Reading version metadata ({ sy-tabix }/{ lv_vrsd_total })| ).
      ENDIF.
      TRY.
          DATA(lo_ver) = NEW zcl_ave_version( ls_vrsd ).
          APPEND VALUE ty_version_row(
            versno         = lo_ver->version_number
            versno_text    = COND #( WHEN lo_ver->version_number = '99998'
                                     THEN 'Active'
                                     ELSE CONV string( lo_ver->version_number + 0 ) )
            datum          = lo_ver->date
            zeit           = lo_ver->time
            author         = ls_vrsd-author
            author_name    = zcl_ave_popup_data=>get_user_name( ls_vrsd-author )
            obj_owner      = lo_ver->author
            obj_owner_name = lo_ver->author_name
            korrnum        = lo_ver->request
            task           = lo_ver->task
            objtype        = lo_ver->objtype
            objname        = lo_ver->objname ) TO mt_versions.
        CATCH zcx_ave.
          " Skip version if metadata fails
      ENDTRY.
    ENDLOOP.

    SORT mt_versions BY versno DESCENDING datum DESCENDING zeit DESCENDING.

    " Rename versno_text for duplicate special versions (keep newest as-is)
    DATA lv_seen_active   TYPE abap_bool.
    DATA lv_seen_modified TYPE abap_bool.
    DATA lv_active_idx    TYPE i VALUE 1.
    DATA lv_modified_idx  TYPE i VALUE 1.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<vr>).
      IF <vr>-versno = zcl_ave_version=>c_version-active.
        IF lv_seen_active = abap_true.
          <vr>-versno_text = |Active ({ lv_active_idx })|.
          lv_active_idx = lv_active_idx + 1.
        ELSE.
          lv_seen_active = abap_true.
        ENDIF.
      ELSEIF <vr>-versno = zcl_ave_version=>c_version-modified.
        IF lv_seen_modified = abap_true.
          <vr>-versno_text = |Modified ({ lv_modified_idx })|.
          lv_modified_idx = lv_modified_idx + 1.
        ELSE.
          lv_seen_modified = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " Fill trfunction / korr_text from E070 / E07T
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver_trf>).
      CHECK <ver_trf>-korrnum IS NOT INITIAL AND <ver_trf>-trfunction IS INITIAL.
      SELECT SINGLE trfunction FROM e070
        WHERE trkorr = @<ver_trf>-korrnum
        INTO @<ver_trf>-trfunction.
      LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver_trf2>)
        WHERE korrnum = <ver_trf>-korrnum AND trfunction IS INITIAL.
        <ver_trf2>-trfunction = <ver_trf>-trfunction.
      ENDLOOP.
    ENDLOOP.

    " Build E071 object key set (map VRSD type -> E071 transport type)
    TYPES: BEGIN OF ty_obj_key,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
           END OF ty_obj_key.
    TYPES: BEGIN OF ty_task_cand,
             trkorr  TYPE trkorr,
             strkorr TYPE trkorr,
             as4user TYPE as4user,
             as4date TYPE as4date,
             as4time TYPE as4time,
           END OF ty_task_cand.
    TYPES: BEGIN OF ty_korr_key,
             korrnum TYPE trkorr,
           END OF ty_korr_key.
    DATA lt_keys      TYPE SORTED TABLE OF ty_obj_key WITH UNIQUE KEY object obj_name.
    DATA lt_all_tasks TYPE STANDARD TABLE OF ty_task_cand.
    DATA lt_request_tasks TYPE STANDARD TABLE OF ty_task_cand.
    DATA lt_korr_keys TYPE SORTED TABLE OF ty_korr_key WITH UNIQUE KEY korrnum.

    DATA lv_e071_type TYPE e071-object.
    DATA lv_e071_name TYPE versobjnam.
    lv_e071_type = SWITCH e071-object( i_objtype
      WHEN 'REPS' OR 'REPT'                                THEN 'PROG'
      WHEN 'CINC' OR 'CLSD' THEN 'CLAS'
      ELSE i_objtype ).
    lv_e071_name = i_objname.
    CASE i_objtype.
      WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'REPT'.
        DATA(lv_eq) = find( val = lv_e071_name sub = '=' ).
        IF lv_eq > 0.
          lv_e071_name = lv_e071_name(lv_eq).
        ENDIF.
    ENDCASE.

    INSERT VALUE #( object = lv_e071_type obj_name = lv_e071_name ) INTO TABLE lt_keys.
    IF lv_e071_type = 'PROG'.
      INSERT VALUE #( object = 'REPS' obj_name = lv_e071_name ) INTO TABLE lt_keys.
    ELSEIF lv_e071_type = 'REPS'.
      INSERT VALUE #( object = 'PROG' obj_name = lv_e071_name ) INTO TABLE lt_keys.
    ENDIF.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING percentage = 35
                text       = CONV char70( |Reading S-requests for { i_objtype } { i_objname }| ).

    DATA lv_trf_s TYPE e070-trfunction VALUE 'S'.
    SELECT e070~trkorr, e070~strkorr, e070~as4user, e070~as4date, e070~as4time
      FROM e071
      INNER JOIN e070 ON e070~trkorr = e071~trkorr
      FOR ALL ENTRIES IN @lt_keys
      WHERE e071~object     = @lt_keys-object
        AND e071~obj_name   = @lt_keys-obj_name
        AND e070~trfunction = @lv_trf_s
      INTO TABLE @lt_all_tasks.
    SORT lt_all_tasks BY as4date DESCENDING as4time DESCENDING.

    LOOP AT mt_versions INTO DATA(ls_k_ver)
      WHERE trfunction = 'K' AND korrnum IS NOT INITIAL.
      INSERT VALUE #( korrnum = ls_k_ver-korrnum ) INTO TABLE lt_korr_keys.
    ENDLOOP.
    IF lt_korr_keys IS NOT INITIAL.
      SELECT trkorr, strkorr, as4user, as4date, as4time
        FROM e070
        FOR ALL ENTRIES IN @lt_korr_keys
        WHERE strkorr    = @lt_korr_keys-korrnum
          AND trfunction = @lv_trf_s
        INTO CORRESPONDING FIELDS OF TABLE @lt_request_tasks.
      SORT lt_request_tasks BY as4date DESCENDING as4time DESCENDING.
    ENDIF.

    DATA(lv_match_total) = lines( mt_versions ).
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver>).
      IF sy-tabix = 1 OR sy-tabix = lv_match_total OR sy-tabix MOD 10 = 0.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 35 + CONV i( sy-tabix * 25 / COND i( WHEN lv_match_total > 0 THEN lv_match_total ELSE 1 ) )
                    text       = CONV char70( |Matching S-request ({ sy-tabix }/{ lv_match_total })| ).
      ENDIF.

      LOOP AT lt_all_tasks INTO DATA(ls_cand).
        CHECK ls_cand-as4date < <ver>-datum
           OR ( ls_cand-as4date = <ver>-datum AND ls_cand-as4time <= <ver>-zeit ).
        IF <ver>-trfunction = 'K' AND ls_cand-strkorr <> <ver>-korrnum.
          CONTINUE.
        ENDIF.
        <ver>-task           = ls_cand-trkorr.
        <ver>-obj_owner      = ls_cand-as4user.
        <ver>-obj_owner_name = zcl_ave_popup_data=>get_user_name( ls_cand-as4user ).
        EXIT.
      ENDLOOP.
      IF <ver>-trfunction = 'K' AND <ver>-task IS INITIAL.
        LOOP AT lt_request_tasks INTO ls_cand WHERE strkorr = <ver>-korrnum.
          CHECK ls_cand-as4date < <ver>-datum
             OR ( ls_cand-as4date = <ver>-datum AND ls_cand-as4time <= <ver>-zeit ).
          <ver>-task           = ls_cand-trkorr.
          <ver>-obj_owner      = ls_cand-as4user.
          <ver>-obj_owner_name = zcl_ave_popup_data=>get_user_name( ls_cand-as4user ).
          EXIT.
        ENDLOOP.
      ENDIF.
      IF <ver>-trfunction = 'T' AND <ver>-task IS INITIAL.
        LOOP AT lt_request_tasks INTO ls_cand.
          CHECK ls_cand-as4date < <ver>-datum
             OR ( ls_cand-as4date = <ver>-datum AND ls_cand-as4time <= <ver>-zeit ).
          <ver>-task           = ls_cand-trkorr.
          <ver>-obj_owner      = ls_cand-as4user.
          <ver>-obj_owner_name = zcl_ave_popup_data=>get_user_name( ls_cand-as4user ).
          EXIT.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

" Trim early per object: selected parent TRs define this object's own
    " upper/lower bounds. Do not use one global marker for all objects.
    IF mt_filter_parent_korrnums IS NOT INITIAL.
      DATA lv_pre_upper_versno TYPE versno.
      DATA lv_pre_lower_versno TYPE versno.
      DATA lv_pre_lower_idx TYPE i.
      DATA lv_pre_lower_k_idx TYPE i.

      LOOP AT mt_versions INTO DATA(ls_pre_selected_scan).
        CHECK ls_pre_selected_scan-korrnum IN mt_filter_parent_korrnums OR
        ls_pre_selected_scan-korrnum IN mt_filter_korrnums.
        IF lv_pre_upper_versno IS INITIAL OR ls_pre_selected_scan-versno > lv_pre_upper_versno.
          lv_pre_upper_versno = ls_pre_selected_scan-versno.
        ENDIF.
        IF lv_pre_lower_versno IS INITIAL OR ls_pre_selected_scan-versno < lv_pre_lower_versno.
          lv_pre_lower_versno = ls_pre_selected_scan-versno.
          lv_pre_lower_idx = sy-tabix.
        ENDIF.
      ENDLOOP.

      IF lv_pre_upper_versno IS INITIAL.
        CLEAR mt_versions.
        RETURN.
      ENDIF.

      DELETE mt_versions WHERE versno > lv_pre_upper_versno.

      IF lv_pre_lower_idx > 0.
        DATA(lv_pre_after_lower_idx) = lv_pre_lower_idx + 1.
        LOOP AT mt_versions INTO DATA(ls_pre_lower_k_scan)
          FROM lv_pre_after_lower_idx WHERE trfunction = 'K'.
          lv_pre_lower_k_idx = sy-tabix.
          EXIT.
        ENDLOOP.
        IF lv_pre_lower_k_idx > 0.
          DATA(lv_pre_delete_from_idx) = lv_pre_lower_k_idx + 1.
          DATA(lv_pre_delete_to_idx) = lines( mt_versions ).
          IF lv_pre_delete_from_idx <= lv_pre_delete_to_idx.
            DELETE mt_versions FROM lv_pre_delete_from_idx TO lv_pre_delete_to_idx.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver_owner_guard>)
      WHERE trfunction = 'K' AND task IS INITIAL.
      <ver_owner_guard>-obj_owner      = <ver_owner_guard>-author.
      <ver_owner_guard>-obj_owner_name = <ver_owner_guard>-author_name.
    ENDLOOP.

    DATA ls_creator_ver TYPE ty_version_row.
    LOOP AT mt_versions INTO DATA(ls_creator_scan).
      IF ls_creator_ver IS INITIAL OR ls_creator_scan-versno < ls_creator_ver-versno.
        ls_creator_ver = ls_creator_scan.
      ENDIF.
    ENDLOOP.
    IF ls_creator_ver IS NOT INITIAL.
      mv_cur_creator = COND versuser(
        WHEN ls_creator_ver-obj_owner IS NOT INITIAL THEN ls_creator_ver-obj_owner
        ELSE ls_creator_ver-author ).
    ENDIF.

    " Fill request description from E07T
    DATA lv_korr_text TYPE e07t-as4text.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver2>).
      CHECK <ver2>-korrnum IS NOT INITIAL.
      SELECT SINGLE as4text FROM e07t
        WHERE trkorr = @<ver2>-korrnum
          AND langu  = @sy-langu
        INTO @lv_korr_text.
      <ver2>-korr_text = lv_korr_text.

      IF <ver2>-trfunction IS INITIAL.
        SELECT SINGLE trfunction FROM e070
          WHERE trkorr = @<ver2>-korrnum
          INTO @<ver2>-trfunction.
      ENDIF.
    ENDLOOP.

    IF mv_remove_dup = abap_true.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = 70
                  text       = CONV char70( |Checking duplicate versions for { i_objtype } { i_objname }| ).
      zcl_ave_popup_data=>remove_duplicate_versions(
        EXPORTING i_keep_korrnum = mv_filter_korrnum
                  i_ignore_case  = mv_ignore_case
        CHANGING  ct_versions    = mt_versions ).
      LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver_dup_owner_guard>)
        WHERE trfunction = 'K' AND task IS INITIAL.
        <ver_dup_owner_guard>-obj_owner      = <ver_dup_owner_guard>-author.
        <ver_dup_owner_guard>-obj_owner_name = <ver_dup_owner_guard>-author_name.
      ENDLOOP.
    ENDIF.

    IF mv_no_toc = abap_true.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = 95
                  text       = CONV char70( |Filtering TOC versions for { i_objtype } { i_objname }| ).
      DELETE mt_versions WHERE trfunction = 'T'.
    ENDIF.

    " The old tail has already been trimmed. Keep the upper-bound filter here,
    " after task/owner detection, duplicate handling and TOC filtering.
    " If a remote system is configured: first try to find the filtered TR in
    " that system's full version directory. If found, use the preceding
    " remote version as baseline when it exists; otherwise use the TR version.
    " Fallback remains remote active (99998).
    IF mv_filter_korrnum IS NOT INITIAL AND mv_system IS NOT INITIAL.
      DATA lt_remote_dir    TYPE vrsd_tab.
      DATA lt_remote_lversn TYPE TABLE OF vrsn.
      DATA lv_dest TYPE tmssysnam.
      lv_dest = mv_system.
      CALL FUNCTION 'SVRS_REMOTE_MANAGER'
         EXPORTING
              iv_command            = 'SVRS_GET_VERSION_DIRECTORY_40'
              iv_tarsystem          = lv_dest
              objname               = i_objname
              objtype               = i_objtype
         TABLES
              lversno_list          = lt_remote_lversn
              version_list          = lt_remote_dir
         EXCEPTIONS
              no_entry              = 1
              communication_failure = 2
              system_failure        = 3
              OTHERS                = 4.
      DATA ls_remote_found TYPE vrsd.
      IF sy-subrc = 0.
        READ TABLE lt_remote_dir WITH KEY korrnum = mv_filter_korrnum INTO DATA(ls_remote_scan).
        IF sy-subrc = 0.
          READ TABLE lt_remote_dir INDEX sy-tabix + 1  INTO ls_remote_scan.
        ENDIF.
      ENDIF.
      IF ls_remote_scan IS NOT INITIAL.
        DATA(lv_remote_versno_text) = COND string(
          WHEN ls_remote_scan-versno = '00000'
            OR ls_remote_scan-versno = zcl_ave_version=>c_version-active
          THEN |Active ({ mv_system })|
          ELSE |{ CONV string( ls_remote_scan-versno + 0 ) } ({ mv_system })| ).
        INSERT VALUE ty_version_row(
          system      = mv_system
          versno      = ls_remote_scan-versno
          versno_text = lv_remote_versno_text
          datum       = ls_remote_scan-datum
          zeit        = ls_remote_scan-zeit
          author      = ls_remote_scan-author
          author_name = zcl_ave_popup_data=>get_user_name( ls_remote_scan-author )
          korrnum     = ls_remote_scan-korrnum
          objtype     = i_objtype
          objname     = i_objname ) INTO mt_versions INDEX 2.

        INSERT VALUE ty_version_row(
          system      = mv_system
          versno      = zcl_ave_version=>c_version-active
          versno_text = |Active ({ mv_system })|
          objtype     = i_objtype
          objname     = i_objname ) INTO mt_versions INDEX 1.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD switch_pane_layout.
    IF mv_two_pane = abap_true.
      mo_split_wrap->set_row_height( id = 1 height = 0 ).
      mo_split_wrap->set_row_height( id = 2 height = 100 ).
      mo_cont_parts = mo_cont_parts_2p.
      mo_cont_vers  = mo_cont_vers_2p.
      mo_cont_html  = mo_cont_html_2p.
    ELSE.
      mo_split_wrap->set_row_height( id = 1 height = 100 ).
      mo_split_wrap->set_row_height( id = 2 height = 0 ).
      mo_cont_parts = mo_split_top->get_container( row = 1 column = 1 ).
      mo_cont_vers  = mo_split_top->get_container( row = 2 column = 1 ).
      mo_cont_html  = mo_split_main->get_container( row = 1 column = 2 ).
    ENDIF.
    FREE mo_alv_parts.
    FREE mo_alv_vers.
    FREE mo_code_viewer.
    FREE mo_html.
    FREE mo_split_html.
    create_parts_alv( ).
    create_versions_alv( ).
    create_html_viewer( ).
    IF mt_versions IS NOT INITIAL.
      update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
      IF mv_viewed_versno IS NOT INITIAL.
        READ TABLE mt_versions INTO DATA(ls_v) WITH KEY versno = mv_viewed_versno.
        IF sy-subrc = 0.
          IF mv_show_diff = abap_true.
            show_versions_diff( is_old = ls_v is_new = ms_base_ver ).
          ELSE.
            show_source( i_objtype = ls_v-objtype i_objname = ls_v-objname i_versno = ls_v-versno ).
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD refresh_parts.
    CHECK mv_refreshing = abap_false.
    mv_refreshing = abap_true.
    DATA ls_layo_p TYPE lvc_s_layo.
    mo_alv_parts->get_frontend_layout( IMPORTING es_layout = ls_layo_p ).
    ls_layo_p-cwidth_opt = abap_true.
    mo_alv_parts->set_frontend_layout( is_layout = ls_layo_p ).
    DATA ls_stbl_p TYPE lvc_s_stbl.
    ls_stbl_p-row = abap_true.
    ls_stbl_p-col = abap_true.
    mo_alv_parts->refresh_table_display( is_stable = ls_stbl_p ).
    mo_alv_parts->set_toolbar_interactive( ).
    mv_refreshing = abap_false.
  ENDMETHOD.


  METHOD refresh_vers.
    CHECK mv_refreshing = abap_false.
    mv_refreshing = abap_true.
    DATA ls_layo_v TYPE lvc_s_layo.
    mo_alv_vers->get_frontend_layout( IMPORTING es_layout = ls_layo_v ).
    ls_layo_v-cwidth_opt = abap_true.
    mo_alv_vers->set_frontend_layout( is_layout = ls_layo_v ).
    DATA ls_stbl TYPE lvc_s_stbl.
    ls_stbl-row = abap_true.
    ls_stbl-col = abap_true.
    mo_alv_vers->refresh_table_display( is_stable = ls_stbl ).
    mv_refreshing = abap_false.
  ENDMETHOD.


  METHOD update_ver_colors.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<v>).
      IF <v>-versno = ms_base_ver-versno.
        <v>-rowcolor = 'C510'.  " green background = base
      ELSEIF <v>-versno = iv_viewed_versno AND iv_viewed_versno <> ms_base_ver-versno.
        <v>-rowcolor = 'C710'.  " blue = currently viewed
      ELSEIF <v>-trfunction = 'K' AND <v>-task IS NOT INITIAL.
        <v>-rowcolor = 'C501'.  "  green = workbench request (type K)
      ELSE.
        CLEAR <v>-rowcolor.
      ENDIF.
    ENDLOOP.
    refresh_vers( ).
  ENDMETHOD.


  METHOD handle_vers_toolbar.
    CLEAR e_object->mt_toolbar.
    APPEND VALUE stb_button(
      function  = 'DIFF_MODE_TOGGLE'
      icon      = CONV #( icon_compare )
      text      = COND #( WHEN mv_diff_prev = abap_true THEN 'Diff prev' ELSE 'Diff any' )
      quickinfo = 'Switch diff mode: compare with previous or any base'
      butn_type = 0 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar. " separator
    IF mv_diff_prev = abap_false.
      APPEND VALUE stb_button(
        function  = 'SET_BASE'
        icon      = CONV #( icon_header )
        text      = 'Set Base'
        quickinfo = 'Set selected version as base'
        butn_type = 0 ) TO e_object->mt_toolbar.
    ENDIF.
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar. " separator
    APPEND VALUE stb_button(
      function  = 'TOC_TOGGLE'
      icon      = CONV #( icon_list )
      text      = COND #( WHEN mv_no_toc = abap_true THEN 'TOCs off' ELSE 'TOCs on' )
      quickinfo = 'Toggle TOC versions'
      butn_type = 0 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button(
      function  = 'DUP_TOGGLE'
      icon      = CONV #( icon_overview )
      text      = COND #( WHEN mv_remove_dup = abap_true THEN 'Dups off' ELSE 'Dups on' )
      quickinfo = 'Toggle duplicate versions'
      butn_type = 0 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar. " separator
    APPEND VALUE stb_button(
      function  = 'CASE_TOGGLE'
      icon      = CONV #( icon_abc )
      text      = COND #( WHEN mv_ignore_case = abap_true THEN 'Case off' ELSE 'Case on' )
      quickinfo = 'Toggle case-insensitive diff'
      butn_type = 0 ) TO e_object->mt_toolbar.
  ENDMETHOD.


  METHOD handle_vers_command.
    CASE e_ucomm.
      WHEN 'DIFF_MODE_TOGGLE'.
        mv_diff_prev = COND #( WHEN mv_diff_prev = abap_true THEN abap_false ELSE abap_true ).
        refresh_vers( ).

      WHEN 'TOC_TOGGLE'.
        mv_no_toc = COND #( WHEN mv_no_toc = abap_true THEN abap_false ELSE abap_true ).
        load_versions( i_objtype = mv_cur_objtype i_objname = mv_cur_objname ).
        refresh_vers( ).

      WHEN 'DUP_TOGGLE'.
        mv_remove_dup = COND #( WHEN mv_remove_dup = abap_true THEN abap_false ELSE abap_true ).
        load_versions( i_objtype = mv_cur_objtype i_objname = mv_cur_objname ).
        refresh_vers( ).

      WHEN 'CASE_TOGGLE'.
        mv_ignore_case = COND #( WHEN mv_ignore_case = abap_true THEN abap_false ELSE abap_true ).
        IF mv_remove_dup = abap_true.
          load_versions( i_objtype = mv_cur_objtype i_objname = mv_cur_objname ).
        ENDIF.
        refresh_vers( ).
        IF mv_show_diff = abap_true AND ms_diff_old IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ENDIF.

      WHEN 'SET_BASE'.
        DATA lt_rows TYPE lvc_t_row.
        mo_alv_vers->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
        CHECK lines( lt_rows ) = 1.
        ms_base_ver = mt_versions[ lt_rows[ 1 ]-index ].
        IF mv_viewed_versno IS NOT INITIAL AND mv_show_diff = abap_true.
          READ TABLE mt_versions INTO DATA(ls_viewed) WITH KEY versno = mv_viewed_versno.
          IF sy-subrc = 0.
            show_versions_diff( is_old = ls_viewed is_new = ms_base_ver ).
          ENDIF.
        ENDIF.
        update_ver_colors( iv_viewed_versno = mv_viewed_versno ).

      WHEN OTHERS.
        on_toolbar_click( fcode = e_ucomm ).
    ENDCASE.
  ENDMETHOD.


  METHOD handle_vers_dblclick.
    DATA(lv_row) = es_row_no-row_id.
    READ TABLE mt_versions INTO DATA(ls_ver) INDEX lv_row.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mv_viewed_versno = ls_ver-versno.

    IF mv_show_diff = abap_true.
      IF mv_diff_prev = abap_true.
        " Diff prev mode: clicked = new, next in list = old (previous chronologically)
        READ TABLE mt_versions INTO DATA(ls_prev) INDEX lv_row + 1.
        ms_base_ver = ls_ver.
        " No previous version → show as new object (all-green diff vs empty source)
        show_versions_diff( is_old = ls_prev is_new = ls_ver ).
      ELSE.
        " Diff any mode: compare with manually chosen base
        IF ls_ver-versno = ms_base_ver-versno.
          READ TABLE mt_versions INTO DATA(ls_prev_base) INDEX lv_row + 1.
          " No previous version → show as new object
          show_versions_diff( is_old = ls_prev_base is_new = ls_ver ).
        ELSE.
          show_versions_diff( is_old = ls_ver is_new = ms_base_ver ).
        ENDIF.
      ENDIF.
    ELSE.
      show_source( i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno ).
    ENDIF.

    update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
  ENDMETHOD.


  METHOD show_source.
    IF mo_box IS BOUND.
      DATA lv_vtxt TYPE string.
      READ TABLE mt_versions INTO DATA(ls_vcap) WITH KEY versno = i_versno.
      lv_vtxt = COND #( WHEN sy-subrc = 0 THEN ls_vcap-versno_text ELSE CONV string( i_versno ) ).
      DATA(lv_vlbl) = COND string( WHEN lv_vtxt CA '0123456789' AND lv_vtxt NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                                   THEN |v{ lv_vtxt }| ELSE lv_vtxt ).
      DATA(lv_extra) = COND string(
        WHEN mv_cur_part_name IS NOT INITIAL
        THEN | – { mv_cur_part_name }|
        WHEN i_objname IS NOT INITIAL AND i_objname <> mv_object_name
        THEN | – { i_objtype }: { i_objname }|
        ELSE `` ).
      mo_box->set_caption( |{ mv_object_type }: { mv_object_name }{ lv_extra }  [{ lv_vlbl }]| ).
    ENDIF.
    TRY.
        DATA lt_source TYPE abaptxt255_tab.

        " Check if this version row has a remote system — use ZCL_AVE_VERSION2 for remote read
        READ TABLE mt_versions INTO DATA(ls_ver_row)
          WITH KEY versno = i_versno objtype = i_objtype objname = i_objname.
        IF sy-subrc = 0 AND ls_ver_row-system IS NOT INITIAL.
          lt_source = zcl_ave_version2=>get_source_remote(
            iv_objtype = i_objtype
            iv_objname = i_objname
            iv_versno  = i_versno
            iv_system  = ls_ver_row-system ).
        ELSE.
          " Local version: find VRSD row and use old ZCL_AVE_VERSION
          DATA lt_vrsd TYPE vrsd_tab.
          DATA(lv_db_versno) = zcl_ave_versno=>to_internal( i_versno ).
          SELECT * FROM vrsd
            WHERE objtype = @i_objtype
              AND objname = @i_objname
              AND versno  = @lv_db_versno
              INTO TABLE @lt_vrsd
            UP TO 1 ROWS.

          DATA ls_vrsd TYPE vrsd.
          IF lt_vrsd IS NOT INITIAL.
            ls_vrsd = lt_vrsd[ 1 ].
          ELSE.
            " Active/Modified: get timestamp from already-loaded version data
            ls_vrsd-objtype = i_objtype.
            ls_vrsd-objname = i_objname.
            ls_vrsd-versno  = lv_db_versno.
            IF sy-subrc = 0.
              ls_vrsd-author = ls_ver_row-author.
              ls_vrsd-datum  = ls_ver_row-datum.
              ls_vrsd-zeit   = ls_ver_row-zeit.
            ELSE.
              ls_vrsd-author = sy-uname.
            ENDIF.
          ENDIF.

          lt_source = NEW zcl_ave_version( ls_vrsd )->get_source( ).
        ENDIF.

        show_code_source( it_source = lt_source ).

      CATCH zcx_ave.
        set_html(
          |<html><body style="background:#1e1e1e;color:#f55;| &&
          |font-family:Consolas;padding:20px">| &&
          |Error loading source.</body></html>| ).
    ENDTRY.
  ENDMETHOD.


  METHOD show_code_source.
    IF mo_code_viewer IS BOUND.
      DATA lt_src TYPE STANDARD TABLE OF char255.
      LOOP AT it_source INTO DATA(ls_line).
        APPEND CONV char255( ls_line ) TO lt_src.
      ENDLOOP.
      mo_code_viewer->set_text( table = lt_src ).
      mo_code_viewer->set_readonly_mode( 1 ).
      IF mo_split_html IS BOUND.
        mo_split_html->set_row_height( id = 1 height = 0 ).
        mo_split_html->set_row_height( id = 2 height = 100 ).
      ENDIF.
      cl_gui_cfw=>flush( ).
    ENDIF.
  ENDMETHOD.


  METHOD set_html.
    mv_last_html = iv_html.
    " Previous call may have swapped to the ABAP editor — bring HTML back.
    IF mo_split_html IS BOUND.
      mo_split_html->set_row_height( id = 1 height = 100 ).
      mo_split_html->set_row_height( id = 2 height = 0 ).
    ENDIF.
    DATA: lt_html   TYPE w3htmltab,
          lv_url    TYPE w3url,
          lv_offset TYPE i,
          lv_len    TYPE i,
          lv_chunk  TYPE i.

    lv_len = strlen( iv_html ).
    WHILE lv_offset < lv_len.
      lv_chunk = COND #(
        WHEN lv_len - lv_offset > 255 THEN 255
        ELSE lv_len - lv_offset ).
      APPEND VALUE #( line = iv_html+lv_offset(lv_chunk) ) TO lt_html.
      lv_offset += lv_chunk.
    ENDWHILE.

    mo_html->load_data(
      IMPORTING assigned_url = lv_url
      CHANGING  data_table   = lt_html
      EXCEPTIONS OTHERS      = 1 ).

    mo_html->show_url( url = lv_url ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.


  METHOD get_class_parts.
    DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
      object_type = zcl_ave_object_factory=>gc_type-class
      object_name = CONV #( i_name ) ).

    LOOP AT lo_obj->get_parts( ) INTO DATA(ls_part).
      CHECK ls_part-type <> 'CLSD' AND ls_part-type <> 'RELE'.
      IF ls_part-type <> 'METH'.
        CHECK zcl_ave_popup_data=>check_part_exists(
                     i_type       = ls_part-type
                     i_name       = CONV #( ls_part-object_name ) ).

      ENDIF.
      DATA ls_part_row TYPE ty_part_row.
      CLEAR ls_part_row.
      ls_part_row-class       = ls_part-class.
      ls_part_row-name        = ls_part-unit.
      ls_part_row-type        = ls_part-type.
      ls_part_row-type_text   = zcl_ave_popup_data=>get_type_text( ls_part-type ).
      ls_part_row-object_name = ls_part-object_name.
      IF mv_object_type = zcl_ave_object_factory=>gc_type-tr.
        ls_part_row-requests = mv_object_name.
        ls_part_row-trs = 1.
      ENDIF.
      ls_part_row-exists_flag = abap_true.
      ls_part_row-rows        = zcl_ave_popup_data=>get_active_line_count(
                                  i_type = ls_part-type i_name = ls_part-object_name ).
      " TR drill-down: color if changed vs prior K-TR (author irrelevant).
      IF mv_filter_user IS NOT INITIAL
         AND zcl_ave_popup_data=>is_substantive_user_change(
           it_versions = zcl_ave_popup_data=>build_versions_for_check( i_type = ls_part-type i_name = ls_part-object_name )
           i_type      = ls_part-type
           i_name      = ls_part-object_name
           i_korrnum   = COND #( WHEN mv_object_type = zcl_ave_object_factory=>gc_type-tr
                                  THEN CONV verskorrno( mv_object_name ) )
           i_ignore_case = mv_ignore_case ) = abap_true.
        ls_part_row-rowcolor = 'C510'. " green
      ENDIF.
      APPEND ls_part_row TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD on_toolbar_click.
    CASE fcode.
      WHEN 'SAVE_REVIEW'.
        IF has_review_table( ) = abap_false.
          show_review_help_popup( ).
        ELSE.
          save_review_to_db( ).
        ENDIF.

      WHEN 'INFO'.
        DATA(l_url) = 'https://github.com/ysichov/AVE'.
        CALL FUNCTION 'CALL_BROWSER' EXPORTING url = l_url.

      WHEN 'BACK'.
        CHECK mt_parts_backup IS NOT INITIAL.
        mt_parts = mt_parts_backup.
        CLEAR: mt_parts_backup, mv_drilled_class.
        refresh_parts( ).

      WHEN 'REFRESH'.
        IF mv_code_review = abap_true.
          load_review_from_db( ).
          regen_acr_report( ).
          refresh_rpt_row( ).

          IF mv_decline_view_user IS NOT INITIAL.
            show_user_declines( iv_user = mv_decline_view_user iv_reviewer = mv_reviewer_view ).
          ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
            set_html( inject_approve_btn( iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ) ).
          ELSE.
            set_html( mv_cr_report_html ).
          ENDIF.
          RETURN.
        ENDIF.

        " Reload parts
        CLEAR mt_parts.
        TRY.
            IF mv_drilled_class IS NOT INITIAL.
              " Drilled into a class from a TR parts view — refresh only this class.
              mt_parts = get_class_parts( CONV #( mv_drilled_class ) ).
            ELSEIF mv_object_type = zcl_ave_object_factory=>gc_type-class.
              mt_parts = get_class_parts( CONV #( mv_object_name ) ).
            ELSE.
              DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
                object_type = mv_object_type
                object_name = CONV #( mv_object_name ) ).
              DATA(lv_is_tr) = boolc( mv_object_type = zcl_ave_object_factory=>gc_type-tr ).
              LOOP AT lo_obj->get_parts( ) INTO DATA(ls_raw).
                DATA(lv_exists) = COND abap_bool(
                  WHEN lv_is_tr = abap_true
                  THEN zcl_ave_popup_data=>check_part_exists(
                         i_type       = ls_raw-type
                         i_name       = ls_raw-object_name
                         i_class_name = CONV #( ls_raw-class ) )
                  ELSE abap_true ).
                DATA ls_row TYPE ty_part_row.
                ls_row-class       = ls_raw-class.
                ls_row-name        = ls_raw-unit.
                ls_row-type        = ls_raw-type.
                ls_row-type_text   = zcl_ave_popup_data=>get_type_text( ls_raw-type ).
                ls_row-object_name = ls_raw-object_name.
                IF lv_is_tr = abap_true.
                  ls_row-requests = mv_object_name.
                  ls_row-trs = 1.
                ENDIF.
                ls_row-exists_flag = lv_exists.
                ls_row-rows        = COND i( WHEN lv_exists = abap_true
                  THEN zcl_ave_popup_data=>get_active_line_count( i_type = ls_raw-type i_name = ls_raw-object_name )
                  ELSE 0 ).
                IF lv_exists = abap_false.
                  ls_row-rowcolor = 'C601'.   " red
                ELSEIF mv_filter_user IS NOT INITIAL.
                  DATA(lv_changed2) = COND abap_bool(
                    WHEN ls_raw-type = 'CLAS'
                    THEN zcl_ave_popup_data=>check_class_has_author(
                           i_class_name = CONV #( ls_raw-object_name )
                           i_korrnum    = COND #( WHEN lv_is_tr = abap_true THEN CONV verskorrno( mv_object_name ) )
                           i_ignore_case = mv_ignore_case )
                    ELSE zcl_ave_popup_data=>is_substantive_user_change(
                           it_versions = zcl_ave_popup_data=>build_versions_for_check( i_type = ls_raw-type i_name = ls_raw-object_name )
                           i_type      = ls_raw-type
                           i_name      = ls_raw-object_name
                           i_korrnum   = COND #( WHEN lv_is_tr = abap_true THEN CONV verskorrno( mv_object_name ) )
                           i_ignore_case = mv_ignore_case ) ).
                  IF lv_changed2 = abap_true.
                    ls_row-rowcolor = 'C510'. " green
                  ENDIF.
                ENDIF.
                APPEND ls_row TO mt_parts.
                CLEAR ls_row.
              ENDLOOP.
            ENDIF.
          CATCH zcx_ave.
        ENDTRY.
        refresh_parts( ).
        CLEAR mt_diff_cache.
        " Reload versions for current part if one was selected
        IF mv_cur_objtype IS NOT INITIAL.
          load_versions( i_objtype = mv_cur_objtype i_objname = mv_cur_objname ).
          update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
        ENDIF.
        " Re-render diff if it was already open (cache cleared above forces fresh render)
        IF ms_diff_old IS NOT INITIAL AND ms_diff_new IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ENDIF.

      WHEN 'SET_BASE'.
        DATA lt_sel_base TYPE lvc_t_row.
        mo_alv_vers->get_selected_rows( IMPORTING et_index_rows = lt_sel_base ).
        CHECK lines( lt_sel_base ) = 1.
        ms_base_ver = mt_versions[ lt_sel_base[ 1 ]-index ].
        IF mv_viewed_versno IS NOT INITIAL AND mv_show_diff = abap_true.
          READ TABLE mt_versions INTO DATA(ls_viewed) WITH KEY versno = mv_viewed_versno.
          IF sy-subrc = 0.
            show_versions_diff( is_old = ls_viewed is_new = ms_base_ver ).
          ENDIF.
        ENDIF.
        update_ver_colors( iv_viewed_versno = mv_viewed_versno ).

      WHEN 'DIFF_TOGGLE'.
        mv_show_diff = COND #( WHEN mv_show_diff = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'DIFF_TOGGLE'
                    text  = COND #( WHEN mv_show_diff = abap_true
                                    THEN 'Show Diff' ELSE 'Show Vers' )
                    icon  = COND #( WHEN mv_show_diff = abap_true
                                    THEN icon_compare ELSE icon_history ) ).
        IF mv_viewed_versno IS NOT INITIAL.
          READ TABLE mt_versions INTO DATA(ls_vw) WITH KEY versno = mv_viewed_versno.
          IF sy-subrc = 0.
            IF mv_show_diff = abap_true.
              " Restore last diff pair (ms_diff_old/new set by show_versions_diff)
              IF ms_diff_old IS NOT INITIAL OR ms_diff_new IS NOT INITIAL.
                show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
              ELSE.
                show_versions_diff( is_old = ls_vw is_new = ms_base_ver ).
              ENDIF.
            ELSE.
              show_source( i_objtype = ls_vw-objtype i_objname = ls_vw-objname i_versno = ls_vw-versno ).
            ENDIF.
          ENDIF.
        ENDIF.

      WHEN 'PANE_TOGGLE'.
        mv_two_pane = COND #( WHEN mv_two_pane = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'PANE_TOGGLE'
                    text  = COND #( WHEN mv_two_pane = abap_true
                                    THEN '2-Pane' ELSE 'Inline' )
                    icon  = COND #( WHEN mv_two_pane = abap_true
                                    THEN icon_view_hier_list ELSE icon_spool_request ) ).
        IF rerender_cr_user_view( ) = abap_true.
          RETURN.
        ENDIF.
        IF rerender_cr_current( ) = abap_true.
          RETURN.
        ENDIF.
        IF mv_viewed_versno IS NOT INITIAL AND mt_versions IS NOT INITIAL.
          READ TABLE mt_versions INTO DATA(ls_pv) WITH KEY versno = mv_viewed_versno.
          IF sy-subrc = 0.
            IF mv_show_diff = abap_true.
              IF ms_diff_old IS NOT INITIAL OR ms_diff_new IS NOT INITIAL.
                show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
              ELSE.
                show_versions_diff( is_old = ls_pv is_new = ms_base_ver ).
              ENDIF.
            ELSE.
              show_source( i_objtype = ls_pv-objtype i_objname = ls_pv-objname i_versno = ls_pv-versno ).
            ENDIF.
          ENDIF.
        ENDIF.

      WHEN 'COMPACT_TOGGLE'.
        mv_compact = COND #( WHEN mv_compact = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'COMPACT_TOGGLE'
                    text  = COND #( WHEN mv_compact = abap_true THEN 'Compact' ELSE 'Full' )
                    icon  = COND #( WHEN mv_compact = abap_true
                                    THEN icon_collapse_all ELSE icon_expand_all ) ).
        IF rerender_cr_user_view( ) = abap_true.
          RETURN.
        ENDIF.
        IF rerender_cr_current( ) = abap_true.
          RETURN.
        ENDIF.
        IF mv_show_diff = abap_true AND ms_diff_old IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ENDIF.

      WHEN 'BLAME_TOGGLE'.
        mv_blame = COND #( WHEN mv_blame = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'BLAME_TOGGLE'
                    text  = COND #( WHEN mv_blame = abap_true THEN 'Blame ON' ELSE 'Blame' )
                    icon  = CONV #( icon_history ) ).
        IF rerender_cr_user_view( ) = abap_true.
          RETURN.
        ENDIF.
        IF rerender_cr_current( ) = abap_true.
          RETURN.
        ENDIF.
        IF mv_show_diff = abap_true AND ms_diff_old IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ENDIF.

      WHEN 'DEBUG'.
        mv_debug = COND #( WHEN mv_debug = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'DEBUG'
                    text  = COND #( WHEN mv_debug = abap_true THEN 'Debug ON' ELSE 'Debug' )
                    icon  = CONV #( icon_bw_dm_aa ) ).
        IF rerender_cr_user_view( ) = abap_true.
          RETURN.
        ENDIF.
        IF rerender_cr_current( ) = abap_true.
          RETURN.
        ENDIF.
        " Re-render the current diff (if any) using the new mode
        IF mv_show_diff = abap_true AND ms_diff_old IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ENDIF.

      WHEN 'FOCUS_TOGGLE'.
        IF mv_focus_html = abap_true.
          " currently maximized → restore
          mv_focus_html = abap_false.
          mo_toolbar->set_button_info(
            EXPORTING fcode = 'FOCUS_TOGGLE'
                      text  = 'Maximize View'
                      icon  = CONV #( icon_view_maximize ) ).
          mo_split_main->set_column_width( id = 1 width = 40 ).
          mo_split_main->set_column_width( id = 2 width = 60 ).
          mo_split_main->set_column_sash( id = 1 type = 1 value = 0 ).
          mo_split_2p_wrap->set_row_height( id = 1 height = 35 ).
          mo_split_2p_wrap->set_row_height( id = 2 height = 65 ).
          mo_split_2p_wrap->set_row_sash( id = 1 type = 1 value = 0 ).
        ELSE.
          maximize_html( ).
        ENDIF.

    ENDCASE.
  ENDMETHOD.


  METHOD on_box_close.
    sender->free( ).
    CLEAR mo_box.
  ENDMETHOD.


  METHOD on_help_box_close.
    sender->free( ).
    CLEAR: mo_help_box, mo_help_html.
  ENDMETHOD.


  METHOD has_review_table.
    result = zcl_ave_acr_repository=>has_review_table( ).
  ENDMETHOD.


  METHOD load_review_payload.
    result = zcl_ave_acr_repository=>load_review_payload(
      EXPORTING
        iv_trkorr  = iv_trkorr
      CHANGING
        cs_payload = es_payload ).
  ENDMETHOD.


  METHOD load_review_from_db.
    CHECK mv_code_review = abap_true.
    CHECK mv_object_type = zcl_ave_object_factory=>gc_type-tr.
    CHECK has_review_table( ) = abap_true.

    DATA(ls_payload) = VALUE ty_saved_payload( ).
    CHECK load_review_payload(
      EXPORTING iv_trkorr = CONV #( mv_object_name )
      IMPORTING es_payload = ls_payload ) = abap_true.

    zcl_ave_acr_state=>apply_saved_payload(
      EXPORTING
        is_payload       = ls_payload
      CHANGING
        ct_obj_stats     = mt_acr_stats
        ct_hunk_info     = mt_hunk_info
        ct_diff_cache    = mt_diff_cache
        ct_approved      = mt_approved
        ct_declined      = mt_declined
        ct_decline_notes = mt_decline_notes
        ct_hunk_threads  = mt_hunk_threads
        ct_hunk_actions  = mt_hunk_actions ).
  ENDMETHOD.


  METHOD get_last_own_comment.
    result = zcl_ave_acr_state=>get_last_own_comment(
      iv_hunk_key     = iv_hunk_key
      it_hunk_threads = mt_hunk_threads ).
  ENDMETHOD.


  METHOD format_timestamp.
    result = zcl_ave_acr_state=>format_timestamp( iv_timestamp ).
  ENDMETHOD.


  METHOD set_hunk_action.
    zcl_ave_acr_state=>set_hunk_action(
      EXPORTING
        iv_hunk_key     = iv_hunk_key
        iv_action       = iv_action
      CHANGING
        ct_hunk_actions = mt_hunk_actions ).
  ENDMETHOD.


  METHOD clear_hunk_action.
    zcl_ave_acr_state=>clear_hunk_action(
      EXPORTING
        iv_hunk_key     = iv_hunk_key
      CHANGING
        ct_hunk_actions = mt_hunk_actions ).
  ENDMETHOD.


  METHOD sanitize_review_state.
    zcl_ave_acr_state=>sanitize_review_state(
      EXPORTING
        it_hunk_info    = mt_hunk_info
      CHANGING
        ct_approved     = mt_approved
        ct_declined     = mt_declined
        ct_hunk_actions = mt_hunk_actions ).
  ENDMETHOD.


  METHOD collect_report_status.
    DATA(ls_payload) = VALUE ty_saved_payload( ).
    DATA(lv_has_payload) = load_review_payload(
      EXPORTING iv_trkorr = CONV #( mv_object_name )
      IMPORTING es_payload = ls_payload ).
    CLEAR lv_has_payload.

    zcl_ave_acr_state=>collect_report_status(
      EXPORTING
        is_payload   = ls_payload
        it_hunk_info = mt_hunk_info
        it_approved  = mt_approved
        it_declined  = mt_declined
      IMPORTING
        et_approved  = et_approved
        et_declined  = et_declined ).
  ENDMETHOD.


  METHOD get_reviewer_stats.
    DATA(ls_payload) = VALUE ty_saved_payload( ).
    DATA(lv_has_payload) = load_review_payload(
      EXPORTING iv_trkorr = CONV #( mv_object_name )
      IMPORTING es_payload = ls_payload ).
    CLEAR lv_has_payload.
    result = zcl_ave_acr_state=>get_reviewer_stats(
      is_payload      = ls_payload
      it_hunk_info    = mt_hunk_info
      it_approved     = mt_approved
      it_declined     = mt_declined
      it_hunk_threads = mt_hunk_threads ).
  ENDMETHOD.


  METHOD save_review_to_db.
    DATA lv_save_trkorr TYPE trkorr.

    CHECK mv_code_review = abap_true.
    CHECK mv_object_type = zcl_ave_object_factory=>gc_type-tr.
    lv_save_trkorr = CONV #( mv_object_name ).
    CHECK lv_save_trkorr IS NOT INITIAL.

    sanitize_review_state( ).

    DATA(ls_payload) = VALUE ty_saved_payload( ).
    DATA(lv_has_existing) = load_review_payload(
      EXPORTING iv_trkorr = lv_save_trkorr
      IMPORTING es_payload = ls_payload ).

    ls_payload = zcl_ave_acr_state=>build_save_payload(
      is_existing_payload = ls_payload
      iv_trkorr           = lv_save_trkorr
      it_obj_stats        = mt_acr_stats
      it_hunk_info        = mt_hunk_info
      it_diff_cache       = mt_diff_cache
      it_hunk_actions     = mt_hunk_actions
      it_approved         = mt_approved
      it_declined         = mt_declined
      it_decline_notes    = mt_decline_notes
      it_hunk_threads     = mt_hunk_threads ).

    DATA(lv_saved_ok) = zcl_ave_acr_repository=>save_review_payload(
      iv_trkorr  = lv_save_trkorr
      is_payload = ls_payload ).

    IF iv_silent = abap_true.
      RETURN.
    ENDIF.

    IF lv_saved_ok = abap_true.
      MESSAGE |Review saved for { mv_object_name }| TYPE 'S'.
    ELSEIF lv_has_existing = abap_true.
      MESSAGE |Review for { mv_object_name } could not be updated| TYPE 'E'.
    ELSE.
      MESSAGE |Review for { mv_object_name } could not be created| TYPE 'E'.
    ENDIF.
  ENDMETHOD.


  METHOD build_review_help_html.
    result = zcl_ave_acr_renderer=>build_review_help_html( ).
  ENDMETHOD.


  METHOD show_review_help_popup.
    IF mo_help_box IS BOUND.
      mo_help_box->free( ).
      CLEAR: mo_help_box, mo_help_html.
    ENDIF.

    CREATE OBJECT mo_help_box
      EXPORTING
        width                       = 760
        height                      = 360
        top                         = 90
        left                        = 120
        caption                     = 'ZAVE_REVIEW setup'
        lifetime                    = cl_gui_control=>lifetime_dynpro
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SET HANDLER me->on_help_box_close FOR mo_help_box.

    CREATE OBJECT mo_help_html
      EXPORTING
        parent = mo_help_box
      EXCEPTIONS
        cntl_error                = 1
        cntl_install_error        = 2
        dp_install_error          = 3
        dp_error                  = 4
        OTHERS                    = 5.
    IF sy-subrc <> 0.
      mo_help_box->free( ).
      CLEAR: mo_help_box, mo_help_html.
      RETURN.
    ENDIF.

    DATA(lv_help_html) = build_review_help_html( ).
    DATA: lt_html   TYPE w3htmltab,
          lv_url    TYPE w3url,
          lv_offset TYPE i,
          lv_len    TYPE i,
          lv_chunk  TYPE i.

    lv_len = strlen( lv_help_html ).
    WHILE lv_offset < lv_len.
      lv_chunk = COND #( WHEN lv_len - lv_offset > 255 THEN 255 ELSE lv_len - lv_offset ).
      APPEND VALUE #( line = lv_help_html+lv_offset(lv_chunk) ) TO lt_html.
      lv_offset += lv_chunk.
    ENDWHILE.

    mo_help_html->load_data(
      IMPORTING assigned_url = lv_url
      CHANGING  data_table   = lt_html
      EXCEPTIONS OTHERS      = 1 ).
    IF sy-subrc = 0.
      mo_help_html->show_url( url = lv_url ).
      cl_gui_control=>set_focus( control = mo_help_html ).
      cl_gui_cfw=>flush( ).
    ENDIF.
  ENDMETHOD.


  METHOD build_tr_task_popup_html.
    result = zcl_ave_acr_overview=>build_tr_task_popup_html(
      iv_objtype           = iv_objtype
      iv_objname           = iv_objname
      iv_outer_object_name = mv_object_name
      it_parts             = mt_parts ).
  ENDMETHOD.


  METHOD show_tr_task_popup.
    IF mo_help_box IS BOUND.
      mo_help_box->free( ).
      CLEAR: mo_help_box, mo_help_html.
    ENDIF.

    CREATE OBJECT mo_help_box
      EXPORTING
        width                       = 760
        height                      = 320
        top                         = 100
        left                        = 140
        caption                     = 'TRs/Tasks'
        lifetime                    = cl_gui_control=>lifetime_dynpro
      EXCEPTIONS
        OTHERS                      = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SET HANDLER me->on_help_box_close FOR mo_help_box.

    CREATE OBJECT mo_help_html
      EXPORTING
        parent = mo_help_box
      EXCEPTIONS
        OTHERS = 1.
    IF sy-subrc <> 0.
      mo_help_box->free( ).
      CLEAR: mo_help_box, mo_help_html.
      RETURN.
    ENDIF.

    DATA(lv_popup_html) = build_tr_task_popup_html(
      iv_objtype = iv_objtype
      iv_objname = iv_objname ).
    DATA: lt_html   TYPE w3htmltab,
          lv_url    TYPE w3url,
          lv_offset TYPE i,
          lv_len    TYPE i,
          lv_chunk  TYPE i.

    lv_len = strlen( lv_popup_html ).
    WHILE lv_offset < lv_len.
      lv_chunk = COND #( WHEN lv_len - lv_offset > 255 THEN 255 ELSE lv_len - lv_offset ).
      APPEND VALUE #( line = lv_popup_html+lv_offset(lv_chunk) ) TO lt_html.
      lv_offset += lv_chunk.
    ENDWHILE.

    mo_help_html->load_data(
      IMPORTING assigned_url = lv_url
      CHANGING  data_table   = lt_html
      EXCEPTIONS OTHERS      = 1 ).
    IF sy-subrc = 0.
      mo_help_html->show_url( url = lv_url ).
      cl_gui_control=>set_focus( control = mo_help_html ).
      cl_gui_cfw=>flush( ).
    ENDIF.
  ENDMETHOD.


  METHOD auto_show_diff_or_source.
    DATA(lt_src) = zcl_ave_popup_data=>get_ver_source(
      i_objtype = is_new-objtype
      i_objname = is_new-objname
      i_versno  = is_new-versno
      i_korrnum = is_new-korrnum
      i_author  = is_new-author
      i_datum   = is_new-datum
      i_zeit    = is_new-zeit ).
    IF lines( lt_src ) > 1000
       AND is_new-objtype <> 'PROG'
       AND is_new-objtype <> 'REPS'
       AND is_new-objtype <> 'REPT'.
      show_source( i_objtype = is_new-objtype
                   i_objname = is_new-objname
                   i_versno  = is_new-versno ).
    ELSE.
      show_versions_diff( is_old = is_old is_new = is_new ).
    ENDIF.
  ENDMETHOD.


  METHOD show_versions_diff.
    ms_diff_old = is_old.
    ms_diff_new = is_new.
    DATA(lv_has_old) = xsdbool( is_old IS NOT INITIAL ).
    IF mo_box IS BOUND.
      DATA(lv_new_lbl) = COND string( WHEN is_new-versno_text CA '0123456789' AND is_new-versno_text NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                                      THEN |v{ is_new-versno_text }| ELSE is_new-versno_text ).
      DATA(lv_old_lbl) = COND string(
        WHEN lv_has_old = abap_false THEN `(new object)`
        WHEN is_old-versno_text CA '0123456789' AND is_old-versno_text NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        THEN |v{ is_old-versno_text }| ELSE is_old-versno_text ).
      DATA(lv_extra2) = COND string(
        WHEN mv_cur_part_name IS NOT INITIAL
        THEN | – { mv_cur_part_name }|
        WHEN is_new-objname IS NOT INITIAL AND is_new-objname <> mv_object_name
        THEN | – { is_new-objtype }: { is_new-objname }|
        ELSE `` ).
      mo_box->set_caption( |{ mv_object_type }: { mv_object_name }{ lv_extra2 }  [{ lv_new_lbl } -- { lv_old_lbl }]| ).
    ENDIF.
    " Cache lookup
    DATA(ls_cache_key) = VALUE ty_diff_cache_key(
      objtype     = is_new-objtype
      objname     = is_new-objname
      system_o    = is_old-system
      system_n    = is_new-system
      versno_o    = is_old-versno
      versno_n    = is_new-versno
      blame       = mv_blame
      two_pane    = mv_two_pane
      compact     = mv_compact
      debug       = mv_debug
      ignore_case = mv_ignore_case ).
    READ TABLE mt_diff_cache INTO DATA(ls_cached) WITH TABLE KEY key = ls_cache_key.
    IF sy-subrc = 0.
      set_html( ls_cached-html ).
      RETURN.
    ENDIF.

    TRY.
        " ── Load OLD source ──
        DATA lt_src_o TYPE abaptxt255_tab.
        IF lv_has_old = abap_true.
          IF is_old-system IS NOT INITIAL.
            lt_src_o = zcl_ave_version2=>get_source_remote(
              iv_objtype = is_old-objtype
              iv_objname = is_old-objname
              iv_versno  = is_old-versno
              iv_system  = is_old-system ).
          ELSE.
            DATA lt_vrsd_o TYPE vrsd_tab.
            DATA(lv_vno_o) = zcl_ave_versno=>to_internal( is_old-versno ).
            SELECT * FROM vrsd WHERE objtype = @is_old-objtype AND objname = @is_old-objname
              AND versno = @lv_vno_o INTO TABLE @lt_vrsd_o UP TO 1 ROWS.
            IF lt_vrsd_o IS INITIAL.
              APPEND VALUE vrsd( objtype = is_old-objtype objname = is_old-objname
                                 versno  = lv_vno_o       korrnum = is_old-korrnum
                                 author  = is_old-author   datum   = is_old-datum
                                 zeit    = is_old-zeit ) TO lt_vrsd_o.
            ENDIF.
            lt_src_o = NEW zcl_ave_version( lt_vrsd_o[ 1 ] )->get_source( ).
          ENDIF.
        ENDIF.

        " ── Load NEW source ──
        DATA lt_src_n TYPE abaptxt255_tab.
        IF is_new-system IS NOT INITIAL.
          lt_src_n = zcl_ave_version2=>get_source_remote(
            iv_objtype = is_new-objtype
            iv_objname = is_new-objname
            iv_versno  = is_new-versno
            iv_system  = is_new-system ).
        ELSE.
          DATA lt_vrsd_n TYPE vrsd_tab.
          DATA(lv_vno_n) = zcl_ave_versno=>to_internal( is_new-versno ).
          SELECT * FROM vrsd WHERE objtype = @is_new-objtype AND objname = @is_new-objname
            AND versno = @lv_vno_n INTO TABLE @lt_vrsd_n UP TO 1 ROWS.
          IF lt_vrsd_n IS INITIAL.
            APPEND VALUE vrsd( objtype = is_new-objtype objname = is_new-objname
                               versno  = lv_vno_n       korrnum = is_new-korrnum
                               author  = is_new-author   datum   = is_new-datum
                               zeit    = is_new-zeit ) TO lt_vrsd_n.
          ENDIF.
          lt_src_n = NEW zcl_ave_version( lt_vrsd_n[ 1 ] )->get_source( ).
        ENDIF.

        zcl_ave_progress=>reset_stop( ).
        DATA(lt_diff)  = zcl_ave_popup_diff=>compute_diff(
          it_old        = lt_src_o
          it_new        = lt_src_n
          i_title       = |{ is_new-objtype }: { is_new-objname }|
          i_confirm_key = |DIFF~{ is_new-objtype }~{ is_new-objname }|
          i_ignore_case = mv_ignore_case ).
        IF zcl_ave_progress=>was_stop_requested( ) = abap_true.
          RETURN.
        ENDIF.
        DATA(lv_meta)  = COND string(
          WHEN lv_has_old = abap_false THEN |{ is_new-versno_text } → (new object)|
          ELSE |{ is_new-versno_text } → { is_old-versno_text }| ).
        DATA lt_blame         TYPE ty_blame_map.
        DATA lt_blame_deleted TYPE ty_blame_map.
        IF mv_blame = abap_true.
          zcl_ave_progress=>reset_stop( ).
          lt_blame = zcl_ave_popup_diff=>build_blame_map(
            EXPORTING it_versions      = mt_versions
                      i_objtype        = is_new-objtype
                      i_objname        = is_new-objname
                      i_from           = is_old-versno
                      i_to             = is_new-versno
                      i_title          = |{ is_new-objtype }: { is_new-objname }|
            IMPORTING et_blame_deleted = lt_blame_deleted ).
          IF zcl_ave_progress=>was_stop_requested( ) = abap_true.
            RETURN.
          ENDIF.
        ENDIF.
        DATA lv_html TYPE string.
        IF mv_debug = abap_true.
          lv_html = zcl_ave_popup_html=>debug_diff_html(
            it_diff = lt_diff
            i_title = |{ is_new-objtype }: { is_new-objname }|
            i_meta  = lv_meta ).
        ELSE.
          lv_html = zcl_ave_popup_html=>diff_to_html(
            it_diff          = lt_diff
            i_title          = |{ is_new-objtype }: { is_new-objname }|
            i_meta           = lv_meta
            i_two_pane       = mv_two_pane
            " Force compact for huge files — full view would render millions of rows.
            i_compact        = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                       THEN abap_true ELSE mv_compact )
            i_plain          = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                       THEN abap_true ELSE abap_false )
            i_ignore_case    = mv_ignore_case
            it_blame         = lt_blame
            it_blame_deleted = lt_blame_deleted ).
        ENDIF.
        INSERT VALUE ty_diff_cache( key = ls_cache_key html = lv_html ) INTO TABLE mt_diff_cache.
        set_html( lv_html ).
*      CATCH cx_root INTO DATA(lx_compare).
*        DATA(lv_err_txt) = escape( val = lx_compare->get_text( ) format = cl_abap_format=>e_html_text ).
*        DATA(lv_err_diffline) = zcl_ave_popup_html=>gv_render_line.
*        set_html( |<html><body style="padding:24px;font:13px Consolas;color:#c00">| &&
*          |Error loading versions for comparison.<br><br>{ lv_err_txt }| &&
*          COND string( WHEN lv_err_diffline > 0
*            THEN |<br><br><span style="color:#888;font-size:11px">diff source line { lv_err_diffline }</span>|
*            ELSE `` ) &&
*          |</body></html>| ).
    ENDTRY.
  ENDMETHOD.


  METHOD cr_precompute_class_parts.
    DATA(lv_before) = lines( mt_acr_stats ).
    add_cr_diag( |CLASS { i_class_name }: expanding class parts| ).
    TRY.
        DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
          object_type = zcl_ave_object_factory=>gc_type-class
          object_name = CONV #( i_class_name ) ).
        DATA(lt_cr_parts) = lo_obj->get_parts( ).
        add_cr_diag( |CLASS { i_class_name }: { lines( lt_cr_parts ) } part(s) found| ).
        DATA(lv_cr_total) = lines( lt_cr_parts ).
        LOOP AT lt_cr_parts INTO DATA(ls_part).
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = CONV i( sy-tabix * 100 / COND i( WHEN lv_cr_total > 0 THEN lv_cr_total ELSE 1 ) )
                      text       = CONV char70( |Code Review: precomputing part { sy-tabix }/{ lv_cr_total }| ).
          IF ls_part-type = 'CLSD' OR ls_part-type = 'RELE'.
            add_cr_diag( |SKIP { ls_part-type } { ls_part-object_name }: class technical part is not reviewed directly| ).
            CONTINUE.
          ENDIF.
          add_cr_diag( |CLASS PART { ls_part-type } { ls_part-object_name }: { ls_part-unit }| ).
          cr_precompute_part( VALUE #(
            type        = ls_part-type
            name        = ls_part-unit
            class       = ls_part-class
            object_name = ls_part-object_name ) ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_class_parts).
        add_cr_diag( |SKIP CLAS { i_class_name }: cannot expand class parts - { lx_class_parts->get_text( ) }| ).
    ENDTRY.
    result = boolc( lines( mt_acr_stats ) > lv_before ).
  ENDMETHOD.


  METHOD cr_precompute_part.
    " CLAS rows are aggregate markers — they have no direct diff source
    IF is_part-type = 'CLAS'.
      add_cr_diag( |SKIP CLAS { is_part-object_name }: aggregate row has no direct diff source| ).
      RETURN.
    ENDIF.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING percentage = 0
                text       = CONV char70( |Code Review: loading versions for { is_part-object_name }| ).

    load_versions( i_objtype = is_part-type i_objname = is_part-object_name ).
    IF mt_versions IS INITIAL.
      add_cr_diag( |SKIP { is_part-type } { is_part-object_name }: no versions after filters; filter TR={ mv_filter_korrnum }, date_from={ mv_date_from }| ).
      RETURN.
    ENDIF.

    add_cr_diag( |VERS { is_part-type } { is_part-object_name }: { lines( mt_versions ) } version(s) after filters| ).

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING percentage = 20
                text       = CONV char70( |Code Review: selecting diff pair for { is_part-object_name }| ).

    DATA ls_new TYPE ty_version_row.
    DATA ls_old TYPE ty_version_row.

    READ TABLE mt_versions INTO ls_new INDEX 1.
    CHECK ls_new IS NOT INITIAL.

    " Latest version is the new side. Choose an old side only if there is a
    " previous version with a selected task/selected request context.
    DATA(lv_versions_count) = lines( mt_versions ).
    IF lv_versions_count >= 2.
      DO lv_versions_count TIMES.
        DATA(lv_old_idx) = lv_versions_count - sy-index + 1.
        READ TABLE mt_versions INTO ls_old INDEX lv_old_idx.
        IF ls_old-task IS NOT INITIAL.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.

    IF ls_old IS INITIAL.
      add_cr_diag( |NEW OBJECT { is_part-type } { is_part-object_name }: no previous version with selected task found, treating as new object| ).
    ELSEIF ls_old-versno = '00001' AND ls_old-korrnum = ls_new-korrnum.
      " Version 1 belongs to the same request as the new side — the object was
      " truly created within this request, so there is no prior baseline.
      add_cr_diag( |NEW OBJECT { is_part-type } { is_part-object_name }: old candidate is v1 of same request { ls_old-korrnum }, treating as new object| ).
      CLEAR ls_old.
    ELSEIF ls_old-versno = '00001' AND ls_old-trfunction = 'K' AND ls_old-korrnum <> ls_new-korrnum.
      " Version 1 is a K-version from a different (older) request — the object
      " already existed before our request, so use it as the real baseline.
      add_cr_diag( |BASELINE { is_part-type } { is_part-object_name }: old candidate is v1 from earlier request { ls_old-korrnum }, using as baseline (not a new object)| ).
    ELSEIF ls_old-versno = '00001'.
      add_cr_diag( |NEW OBJECT { is_part-type } { is_part-object_name }: old candidate is v1, treating as new object| ).
      CLEAR ls_old.
    ENDIF.

    DATA(lv_is_created) = COND abap_bool( WHEN ls_old IS INITIAL THEN abap_true ELSE abap_false ).
    DATA(lv_versno_new) = ls_new-versno.
    DATA(lv_tadir_author) = VALUE versuser( ).

    DATA(lv_diag_old_pair) = COND string(
      WHEN ls_old IS INITIAL THEN `(empty/new object)`
      ELSE |{ ls_old-versno_text }/{ ls_old-versno }| ).
    add_cr_diag( |PAIR { is_part-type } { is_part-object_name }: new={ ls_new-versno_text }/{ lv_versno_new }, old={ lv_diag_old_pair }| ).
    IF lv_is_created = abap_true.
      DATA(lv_tadir_object) = CONV tadir-object( is_part-type ).
      DATA(lv_tadir_name) = CONV tadir-obj_name( is_part-object_name ).
      CASE is_part-type.
        WHEN 'REPS' OR 'REPT'.
          lv_tadir_object = 'PROG'.
        WHEN 'METH'.
          IF is_part-class IS NOT INITIAL.
            DATA lv_meth_cl_key TYPE seoclskey.
            DATA lt_meth_includes TYPE seop_methods_w_include.
            lv_meth_cl_key = is_part-class.
            CALL FUNCTION 'SEO_CLASS_GET_METHOD_INCLUDES'
              EXPORTING clskey   = lv_meth_cl_key
              IMPORTING includes = lt_meth_includes
              EXCEPTIONS
                _internal_class_not_existing = 1
                OTHERS                       = 2.
            IF sy-subrc = 0.
              DATA lv_meth_include TYPE seop_method_w_include.
              LOOP AT lt_meth_includes INTO lv_meth_include.
                IF lv_meth_include-cpdkey-cpdname = is_part-name. EXIT. ENDIF.
                CLEAR lv_meth_include.
              ENDLOOP.
              IF lv_meth_include IS NOT INITIAL.
                DATA lv_reposrc_cnam TYPE reposrc-cnam.
                SELECT SINGLE cnam FROM reposrc
                  WHERE progname = @lv_meth_include-incname
                  INTO @lv_reposrc_cnam.
                IF sy-subrc = 0 AND lv_reposrc_cnam IS NOT INITIAL.
                  lv_tadir_author = lv_reposrc_cnam.
                  add_cr_diag( |METH AUTHOR { is_part-object_name }: include { lv_meth_include-cpdkey-cpdname }, REPOSRC-CNAM={ lv_reposrc_cnam }| ).
                ELSE.
                  add_cr_diag( |METH AUTHOR { is_part-object_name }: include { lv_meth_include-cpdkey-cpdname }, REPOSRC-CNAM not found, fallback to TADIR| ).
                  lv_tadir_object = 'CLAS'.
                  lv_tadir_name   = CONV tadir-obj_name( is_part-class ).
                ENDIF.
              ELSE.
                add_cr_diag( |METH AUTHOR { is_part-object_name }: include not found in SEO_CLASS_GET_METHOD_INCLUDES, fallback to TADIR| ).
                lv_tadir_object = 'CLAS'.
                lv_tadir_name   = CONV tadir-obj_name( is_part-class ).
              ENDIF.
            ELSE.
              add_cr_diag( |METH AUTHOR { is_part-object_name }: SEO_CLASS_GET_METHOD_INCLUDES failed (subrc={ sy-subrc }), fallback to TADIR| ).
              lv_tadir_object = 'CLAS'.
              lv_tadir_name   = CONV tadir-obj_name( is_part-class ).
            ENDIF.
            IF lv_tadir_author IS NOT INITIAL.
              CLEAR: lv_tadir_object, lv_tadir_name.
            ENDIF.
          ELSE.
            CLEAR: lv_tadir_object, lv_tadir_name.
            add_cr_diag( |NEW OBJECT { is_part-type } { is_part-object_name }: skip TADIR author lookup, parent class is unknown| ).
          ENDIF.
        WHEN 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'CINC' OR 'CDEF'.
          lv_tadir_object = 'CLAS'.
          IF is_part-class IS NOT INITIAL.
            lv_tadir_name = CONV tadir-obj_name( is_part-class ).
          ELSEIF lv_tadir_name CS '='.
            DATA(lv_tadir_eq_pos) = find( val = CONV string( lv_tadir_name ) sub = '=' ).
            IF lv_tadir_eq_pos > 0.
              lv_tadir_name = lv_tadir_name(lv_tadir_eq_pos).
            ENDIF.
          ENDIF.
      ENDCASE.
      IF lv_tadir_object IS NOT INITIAL AND lv_tadir_name IS NOT INITIAL.
        SELECT SINGLE author FROM tadir
          WHERE pgmid    = 'R3TR'
            AND object   = @lv_tadir_object
            AND obj_name = @lv_tadir_name
            AND delflag  = ' '
          INTO @lv_tadir_author.
      ENDIF.
    ENDIF.

    DATA(lv_versno_old) = ls_old-versno.
    lv_diag_old_pair = COND string(
      WHEN ls_old IS INITIAL THEN `(empty/new object)`
      ELSE |{ ls_old-versno_text }/{ ls_old-versno }| ).
    add_cr_diag( |PAIR { is_part-type } { is_part-object_name }: new={ ls_new-versno_text }/{ lv_versno_new }, old={ lv_diag_old_pair }| ).

    IF mv_filter_user IS NOT INITIAL.
      DATA(lv_effective_author) = COND versuser(
        WHEN lv_is_created = abap_true AND lv_tadir_author IS NOT INITIAL THEN lv_tadir_author
        WHEN ls_new-obj_owner IS NOT INITIAL THEN ls_new-obj_owner
        ELSE ls_new-author ).
      IF lv_effective_author <> mv_filter_user.
        add_cr_diag( |SKIP { is_part-type } { is_part-object_name }: author filter { mv_filter_user }, effective author { lv_effective_author }| ).
        RETURN.
      ENDIF.
    ENDIF.

    TRY.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 30
                    text       = CONV char70( |Code Review: loading new source for { is_part-object_name }| ).
        DATA lt_vrsd_n TYPE vrsd_tab.
        DATA(lv_vno_n) = zcl_ave_versno=>to_internal( lv_versno_new ).
        SELECT * FROM vrsd WHERE objtype = @is_part-type AND objname = @is_part-object_name
          AND versno = @lv_vno_n INTO TABLE @lt_vrsd_n UP TO 1 ROWS.
        IF lt_vrsd_n IS INITIAL.
          APPEND VALUE vrsd( objtype = is_part-type objname = is_part-object_name
                             versno = lv_vno_n ) TO lt_vrsd_n.
        ENDIF.
        DATA(lt_src_n) = NEW zcl_ave_version( lt_vrsd_n[ 1 ] )->get_source( ).
        DATA lt_src_o TYPE abaptxt255_tab.
        IF ls_old IS NOT INITIAL.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 40
                      text       = CONV char70( |Code Review: loading old source for { is_part-object_name }| ).
          IF ls_old-system IS NOT INITIAL.
            lt_src_o = zcl_ave_version2=>get_source_remote(
              iv_objtype = is_part-type
              iv_objname = is_part-object_name
              iv_versno  = lv_versno_old
              iv_system  = ls_old-system ).
          ELSE.
            DATA lt_vrsd_o TYPE vrsd_tab.
            DATA(lv_vno_o) = zcl_ave_versno=>to_internal( lv_versno_old ).
            SELECT * FROM vrsd WHERE objtype = @is_part-type AND objname = @is_part-object_name
              AND versno = @lv_vno_o INTO TABLE @lt_vrsd_o UP TO 1 ROWS.
            IF lt_vrsd_o IS INITIAL.
              APPEND VALUE vrsd( objtype = is_part-type objname = is_part-object_name
                                 versno = lv_vno_o ) TO lt_vrsd_o.
            ENDIF.
            lt_src_o = NEW zcl_ave_version( lt_vrsd_o[ 1 ] )->get_source( ).
          ENDIF.
        ENDIF.

        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 50
                    text       = CONV char70( |Code Review: computing diff for { is_part-object_name }| ).

        DATA lt_diff TYPE ty_t_diff.
        IF lv_is_created = abap_true.
          add_cr_diag( |NEW OBJECT { is_part-type } { is_part-object_name }: no K baseline, whole source is one review block| ).
          LOOP AT lt_src_n INTO DATA(ls_new_object_line).
            APPEND VALUE ty_diff_op(
              op   = '+'
              text = CONV string( ls_new_object_line ) ) TO lt_diff.
          ENDLOOP.
        ELSE.
          zcl_ave_progress=>reset_stop( ).
          lt_diff = zcl_ave_popup_diff=>compute_diff(
            it_old        = lt_src_o
            it_new        = lt_src_n
            i_title       = CONV #( is_part-object_name )
            i_confirm_key = |DIFF~{ is_part-type }~{ is_part-object_name }|
            i_ignore_case = mv_ignore_case ).
          IF zcl_ave_progress=>was_stop_requested( ) = abap_true.
            RETURN.
          ENDIF.
        ENDIF.

        IF lv_is_created = abap_true
           AND is_comments_only( lt_src_n ) = abap_true.
          add_cr_diag( |SKIP { is_part-type } { is_part-object_name }: new object contains only comment lines| ).
          RETURN.
        ENDIF.

        DATA lt_blame         TYPE ty_blame_map.
        DATA lt_blame_deleted TYPE ty_blame_map.
        IF mv_blame = abap_true AND ls_old IS NOT INITIAL AND lines( lt_src_o ) <= 1000 AND lines( lt_src_n ) <= 1000.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 65
                      text       = CONV char70( |Code Review: computing blame for { is_part-object_name }| ).
          zcl_ave_progress=>reset_stop( ).
          lt_blame = zcl_ave_popup_diff=>build_blame_map(
            EXPORTING it_versions      = mt_versions
                      i_objtype        = is_part-type
                      i_objname        = is_part-object_name
                      i_from           = lv_versno_old
                      i_to             = lv_versno_new
                      i_title          = |{ is_part-type }: { is_part-object_name }|
            IMPORTING et_blame_deleted = lt_blame_deleted ).
          IF zcl_ave_progress=>was_stop_requested( ) = abap_true.
            RETURN.
          ENDIF.
        ELSEIF mv_blame = abap_true AND lv_is_created = abap_true.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 65
                      text       = CONV char70( |Code Review: building blame for new object { is_part-object_name }| ).
          DATA(lv_new_obj_author) = COND versuser(
            WHEN lv_tadir_author IS NOT INITIAL THEN lv_tadir_author
            WHEN ls_new-obj_owner IS NOT INITIAL THEN ls_new-obj_owner
            ELSE ls_new-author ).
          DATA(lv_new_obj_author_name) = zcl_ave_popup_data=>get_user_name( lv_new_obj_author ).
          LOOP AT lt_src_n INTO DATA(ls_src_new_line).
            APPEND VALUE zif_ave_popup_types=>ty_blame_entry(
              text        = CONV string( ls_src_new_line )
              author      = lv_new_obj_author
              author_name = lv_new_obj_author_name
              datum       = ls_new-datum
              zeit        = ls_new-zeit
              versno_text = ls_new-versno_text
              korrnum     = ls_new-korrnum
              task        = ls_new-task
              task_text   = ls_new-korr_text ) TO lt_blame.
          ENDLOOP.
        ELSEIF mv_blame = abap_true.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 65
                      text       = CONV char70( |Code Review: skipping blame for large source { is_part-object_name }| ).
        ENDIF.

        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 75
                    text       = CONV char70( |Code Review: rendering diff for { is_part-object_name }| ).

        DATA(lv_meta_cr) = COND string(
          WHEN lv_is_created = abap_true
          THEN |{ ls_new-versno_text } → (new object)|
          ELSE |{ ls_new-versno_text } → { ls_old-versno_text }| ).
        DATA(lv_html) = zcl_ave_popup_html=>diff_to_html(
          it_diff          = lt_diff
          i_title          = |{ is_part-type }: { is_part-object_name }|
          i_meta           = lv_meta_cr
          i_two_pane       = mv_two_pane
          i_compact        = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                     THEN abap_true ELSE mv_compact )
          i_plain          = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                     THEN abap_true ELSE abap_false )
          i_ignore_case    = mv_ignore_case
          i_code_review    = abap_true
          it_blame         = lt_blame
          it_blame_deleted = lt_blame_deleted ).

        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 85
                    text       = CONV char70( |Code Review: collecting hunks for { is_part-object_name }| ).

        DATA lt_hunk_html TYPE string_table.
        DATA lv_rows_html TYPE string.
        DATA lv_tb_off TYPE i.
        DATA lv_tb_len TYPE i.
        FIND FIRST OCCURRENCE OF `<table><tbody>` IN lv_html
          MATCH OFFSET lv_tb_off MATCH LENGTH lv_tb_len.
        IF sy-subrc = 0.
          DATA(lv_rows_start) = lv_tb_off + lv_tb_len.
          DATA(lv_rows_tail) = lv_html+lv_rows_start.
          DATA lv_rows_end TYPE i.
          FIND FIRST OCCURRENCE OF `</tbody></table>` IN lv_rows_tail MATCH OFFSET lv_rows_end.
          IF sy-subrc = 0.
            lv_rows_html = lv_rows_tail(lv_rows_end).
          ENDIF.
        ENDIF.
        IF lv_is_created = abap_true AND lv_rows_html IS NOT INITIAL.
          APPEND lv_rows_html TO lt_hunk_html.
        ELSE.
          DATA lv_diff_pos TYPE i VALUE 1.
          DATA(lv_diff_total) = lines( lt_diff ).
          WHILE lv_diff_pos <= lv_diff_total.
            READ TABLE lt_diff INTO DATA(ls_hscan_start) INDEX lv_diff_pos.
            IF ls_hscan_start-op <> '-' AND ls_hscan_start-op <> '+'.
              lv_diff_pos += 1.
              CONTINUE.
            ENDIF.

            DATA lt_hunk_diff TYPE ty_t_diff.
            DATA lt_hunk_lines TYPE string_table.
            CLEAR: lt_hunk_diff, lt_hunk_lines.
            DATA(lv_hscan) = lv_diff_pos.
            WHILE lv_hscan <= lv_diff_total.
              READ TABLE lt_diff INTO DATA(ls_hscan) INDEX lv_hscan.
              IF ls_hscan-op = '-' OR ls_hscan-op = '+'.
                APPEND ls_hscan TO lt_hunk_diff.
                APPEND CONV string( ls_hscan-text ) TO lt_hunk_lines.
                lv_hscan += 1.
              ELSEIF ls_hscan-op = '=' AND condense( val = ls_hscan-text ) = ``.
                DATA(lv_hpeek) = lv_hscan + 1.
                DATA(lv_hextra) = 0.
                DATA(lv_hmore_changes) = abap_false.
                WHILE lv_hpeek <= lv_diff_total.
                  READ TABLE lt_diff INTO DATA(ls_hpeek) INDEX lv_hpeek.
                  IF ls_hpeek-op = '-' OR ls_hpeek-op = '+'.
                    lv_hmore_changes = abap_true.
                    EXIT.
                  ELSEIF ls_hpeek-op = '=' AND condense( val = ls_hpeek-text ) = `` AND lv_hextra < 1.
                    lv_hextra += 1.
                    lv_hpeek += 1.
                    CONTINUE.
                  ELSE.
                    EXIT.
                  ENDIF.
                ENDWHILE.
                IF lv_hmore_changes = abap_true.
                  APPEND ls_hscan TO lt_hunk_diff.
                  lv_hscan += 1.
                ELSE.
                  EXIT.
                ENDIF.
              ELSE.
                EXIT.
              ENDIF.
            ENDWHILE.

            IF zcl_ave_acr_stats=>is_blank_hunk( lt_hunk_lines ) = abap_false.
              DATA(lv_hunk_full_html) = zcl_ave_popup_html=>diff_to_html(
                it_diff          = lt_hunk_diff
                i_title          = |{ is_part-type }: { is_part-object_name }|
                i_meta           = lv_meta_cr
                i_two_pane       = mv_two_pane
                i_compact        = abap_false
                i_plain          = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                           THEN abap_true ELSE abap_false )
                i_ignore_case    = mv_ignore_case
                i_code_review    = abap_false ).
              DATA lv_hunk_tb_off TYPE i.
              DATA lv_hunk_tb_len TYPE i.
              CLEAR: lv_hunk_tb_off, lv_hunk_tb_len.
              FIND FIRST OCCURRENCE OF `<table><tbody>` IN lv_hunk_full_html
                MATCH OFFSET lv_hunk_tb_off MATCH LENGTH lv_hunk_tb_len.
              IF sy-subrc = 0.
                DATA(lv_hunk_rows_start) = lv_hunk_tb_off + lv_hunk_tb_len.
                DATA(lv_hunk_rows_tail) = lv_hunk_full_html+lv_hunk_rows_start.
                DATA lv_hunk_rows_end TYPE i.
                FIND FIRST OCCURRENCE OF `</tbody></table>` IN lv_hunk_rows_tail MATCH OFFSET lv_hunk_rows_end.
                IF sy-subrc = 0.
                  APPEND lv_hunk_rows_tail(lv_hunk_rows_end) TO lt_hunk_html.
                ENDIF.
              ENDIF.
            ENDIF.

            lv_diff_pos = lv_hscan.
          ENDWHILE.
        ENDIF.

        INSERT VALUE ty_diff_cache(
          key  = VALUE #(
            objtype     = is_part-type
            objname     = is_part-object_name
            versno_o    = lv_versno_old
            versno_n    = lv_versno_new
            blame       = mv_blame
            two_pane    = mv_two_pane
            compact     = mv_compact
            debug       = mv_debug
            ignore_case = mv_ignore_case )
          html = lv_html )
          INTO TABLE mt_diff_cache.

        DATA lv_ins TYPE i. DATA lv_del TYPE i. DATA lv_mod TYPE i.
        DATA lt_auth TYPE zif_ave_acr_types=>ty_t_author_stats.
        zcl_ave_acr_stats=>from_diff(
          EXPORTING it_diff    = lt_diff
                    it_blame   = lt_blame
          IMPORTING ev_ins     = lv_ins
                    ev_del     = lv_del
                    ev_mod     = lv_mod
                    et_authors = lt_auth ).

        DATA(lv_author) = COND versuser(
          WHEN lv_is_created = abap_true AND lv_tadir_author IS NOT INITIAL THEN lv_tadir_author
          WHEN ls_new-obj_owner IS NOT INITIAL THEN ls_new-obj_owner
          ELSE ls_new-author ).
        DATA(lv_datum)  = ls_new-datum.
        DATA(lv_zeit)   = ls_new-zeit.
        DATA(lv_disp_name) = CONV string( is_part-name ).

        " Count hunks and classify directly in one pass — hunk_ins/mod/del counted here,
        " NOT from mt_hunk_info (avoids stale-data and double-count issues).
        DATA lv_hunk_cnt     TYPE i VALUE 0.
        DATA lv_hunk_html_idx TYPE i VALUE 0.
        DATA lv_stat_hunk_ins TYPE i VALUE 0.
        DATA lv_stat_hunk_mod TYPE i VALUE 0.
        DATA lv_stat_hunk_del TYPE i VALUE 0.
        DATA lv_in_hunk      TYPE abap_bool VALUE abap_false.
        DATA lt_cur_hunk     TYPE string_table.
        DATA lv_new_line     TYPE i VALUE 0.
        DATA lv_hunk_line    TYPE i.
        DATA lv_hunk_chg     TYPE i.
        DATA lv_hunk_ins     TYPE i.
        DATA lv_hunk_del     TYPE i.
        DATA lv_hunk_kind    TYPE string.
        DATA lv_hunk_auth    TYPE versuser.

        DELETE mt_hunk_info WHERE objtype = is_part-type AND obj_name = is_part-object_name.

        " Inner macro: flush current hunk into mt_hunk_info and update stat counters
        " (implemented inline below for each flush point)

        LOOP AT lt_diff INTO DATA(ls_dop).
          CASE ls_dop-op.
            WHEN '+' OR '-'.
              IF lv_in_hunk = abap_false.
                lv_in_hunk = abap_true.
                CLEAR: lt_cur_hunk, lv_hunk_chg, lv_hunk_ins, lv_hunk_del, lv_hunk_auth.
                lv_hunk_line = lv_new_line + 1.
              ENDIF.
              lv_hunk_chg += 1.
              IF ls_dop-op = '+'.
                lv_hunk_ins += 1.
                IF lv_hunk_auth IS INITIAL AND lt_blame IS NOT INITIAL.
                  READ TABLE lt_blame INTO DATA(ls_hb) WITH KEY text = ls_dop-text.
                  IF sy-subrc = 0. lv_hunk_auth = ls_hb-author. ENDIF.
                ENDIF.
                lv_new_line += 1.
              ELSE. " '-'
                lv_hunk_del += 1.
              ENDIF.
              APPEND CONV string( ls_dop-text ) TO lt_cur_hunk.
            WHEN OTHERS.
              IF lv_in_hunk = abap_true.
                IF ls_dop-op = '=' AND condense( val = ls_dop-text ) = ``.
                  DATA(lv_dpeek_idx) = sy-tabix + 1.
                  DATA(lv_dextra) = 0.
                  DATA(lv_dmore_changes) = abap_false.
                  WHILE lv_dpeek_idx <= lines( lt_diff ).
                    READ TABLE lt_diff INTO DATA(ls_dpeek) INDEX lv_dpeek_idx.
                    IF ls_dpeek-op = '-' OR ls_dpeek-op = '+'.
                      lv_dmore_changes = abap_true.
                      EXIT.
                    ELSEIF ls_dpeek-op = '=' AND condense( val = ls_dpeek-text ) = `` AND lv_dextra < 1.
                      lv_dextra += 1.
                      lv_dpeek_idx += 1.
                      CONTINUE.
                    ELSE.
                      EXIT.
                    ENDIF.
                  ENDWHILE.
                  IF lv_dmore_changes = abap_true.
                    APPEND CONV string( ls_dop-text ) TO lt_cur_hunk.
                    lv_new_line += 1.
                    CONTINUE.
                  ENDIF.
                ENDIF.
                IF zcl_ave_acr_stats=>is_blank_hunk( lt_cur_hunk ) = abap_false.
                  lv_hunk_html_idx += 1.
                  lv_hunk_kind = COND string(
                    WHEN lv_hunk_ins > 0 AND lv_hunk_del > 0 THEN `changed`
                    WHEN lv_hunk_ins > 0                      THEN `added`
                    WHEN lv_hunk_del > 0                      THEN `deleted`
                    ELSE                                           `changed` ).
                  DATA(lv_info_author) = COND versuser(
                    WHEN lv_is_created = abap_true THEN lv_author
                    WHEN lv_hunk_auth IS NOT INITIAL THEN lv_hunk_auth
                    ELSE lv_author ).
                  DATA lv_info_html TYPE string.
                  READ TABLE lt_hunk_html INTO lv_info_html INDEX lv_hunk_html_idx.
                  IF lv_info_html CS `#ffb3b3`
                     OR lv_info_html CS `#afffaf`
                     OR lv_info_html CS `background:#ffecec`
                     OR lv_info_html CS `background:#eaffea`.
                    lv_hunk_cnt += 1.
                    CASE lv_hunk_kind.
                      WHEN `added`.   lv_stat_hunk_ins += 1.
                      WHEN `changed`. lv_stat_hunk_mod += 1.
                      WHEN `deleted`. lv_stat_hunk_del += 1.
                    ENDCASE.
                    INSERT VALUE ty_hunk_info(
                      hunk_key        = |{ is_part-type }~{ is_part-object_name }~{ lv_hunk_cnt }|
                      objtype         = is_part-type
                      obj_name        = is_part-object_name
                      class_name      = CONV #( is_part-class )
                      display_name    = lv_disp_name
                      hunk_no         = lv_hunk_cnt
                      start_line      = lv_hunk_line
                      change_count    = lv_hunk_chg
                      change_kind     = lv_hunk_kind
                      author          = lv_info_author
                      author_name     = zcl_ave_popup_data=>get_user_name( lv_info_author )
                      versno_new      = lv_versno_new
                      versno_old      = lv_versno_old
                      versno_new_text = ls_new-versno_text
                      versno_old_text = ls_old-versno_text
                      html            = lv_info_html )
                      INTO TABLE mt_hunk_info.
                  ENDIF.
                ENDIF.
                lv_in_hunk = abap_false.
                CLEAR: lt_cur_hunk, lv_hunk_chg, lv_hunk_ins, lv_hunk_del, lv_hunk_auth.
              ENDIF.
              lv_new_line += 1.
          ENDCASE.
        ENDLOOP.

        " Flush last hunk if diff ends without trailing '='
        IF lv_in_hunk = abap_true AND zcl_ave_acr_stats=>is_blank_hunk( lt_cur_hunk ) = abap_false.
          lv_hunk_html_idx += 1.
          lv_hunk_kind = COND string(
            WHEN lv_hunk_ins > 0 AND lv_hunk_del > 0 THEN `changed`
            WHEN lv_hunk_ins > 0                      THEN `added`
            WHEN lv_hunk_del > 0                      THEN `deleted`
            ELSE                                           `changed` ).
          DATA(lv_last_info_author) = COND versuser(
            WHEN lv_is_created = abap_true THEN lv_author
            WHEN lv_hunk_auth IS NOT INITIAL THEN lv_hunk_auth
            ELSE lv_author ).
          DATA lv_last_info_html TYPE string.
          READ TABLE lt_hunk_html INTO lv_last_info_html INDEX lv_hunk_html_idx.
          IF lv_last_info_html CS `#ffb3b3`
             OR lv_last_info_html CS `#afffaf`
             OR lv_last_info_html CS `background:#ffecec`
             OR lv_last_info_html CS `background:#eaffea`.
            lv_hunk_cnt += 1.
            CASE lv_hunk_kind.
              WHEN `added`.   lv_stat_hunk_ins += 1.
              WHEN `changed`. lv_stat_hunk_mod += 1.
              WHEN `deleted`. lv_stat_hunk_del += 1.
            ENDCASE.
            INSERT VALUE ty_hunk_info(
              hunk_key        = |{ is_part-type }~{ is_part-object_name }~{ lv_hunk_cnt }|
              objtype         = is_part-type
              obj_name        = is_part-object_name
              class_name      = CONV #( is_part-class )
              display_name    = lv_disp_name
              hunk_no         = lv_hunk_cnt
              start_line      = lv_hunk_line
              change_count    = lv_hunk_chg
              change_kind     = lv_hunk_kind
              author          = lv_last_info_author
              author_name     = zcl_ave_popup_data=>get_user_name( lv_last_info_author )
              versno_new      = lv_versno_new
              versno_old      = lv_versno_old
              versno_new_text = ls_new-versno_text
              versno_old_text = ls_old-versno_text
              html            = lv_last_info_html )
              INTO TABLE mt_hunk_info.
          ENDIF.
        ENDIF.

        IF lv_is_created = abap_true.
          CLEAR lt_auth.
          APPEND VALUE zif_ave_acr_types=>ty_author_stats(
            author      = lv_author
            author_name = zcl_ave_popup_data=>get_user_name( lv_author )
            ins_count   = lv_ins
            del_count   = lv_del
            mod_count   = lv_mod
            hunk_count  = lv_hunk_cnt ) TO lt_auth.
        ENDIF.

        " Rebuild hunk_count per author from mt_hunk_info
        LOOP AT lt_auth ASSIGNING FIELD-SYMBOL(<auth_cnt>).
          CLEAR <auth_cnt>-hunk_count.
        ENDLOOP.
        LOOP AT mt_hunk_info INTO DATA(ls_auth_hi)
          WHERE objtype = is_part-type AND obj_name = is_part-object_name.
          CHECK ls_auth_hi-author IS NOT INITIAL.
          READ TABLE lt_auth ASSIGNING <auth_cnt> WITH KEY author = ls_auth_hi-author.
          IF sy-subrc <> 0.
            APPEND VALUE zif_ave_acr_types=>ty_author_stats(
              author      = ls_auth_hi-author
              author_name = ls_auth_hi-author_name ) TO lt_auth.
            READ TABLE lt_auth ASSIGNING <auth_cnt> WITH KEY author = ls_auth_hi-author.
          ENDIF.
          <auth_cnt>-hunk_count += 1.
        ENDLOOP.

        " If blame was not available, assign row totals to lv_author
        IF lt_blame IS INITIAL AND lt_auth IS NOT INITIAL.
          READ TABLE lt_auth ASSIGNING <auth_cnt> WITH KEY author = lv_author.
          IF sy-subrc = 0.
            <auth_cnt>-ins_count = lv_ins.
            <auth_cnt>-mod_count = lv_mod.
            <auth_cnt>-del_count = lv_del.
          ELSE.
            CLEAR lt_auth.
            APPEND VALUE zif_ave_acr_types=>ty_author_stats(
              author      = lv_author
              author_name = zcl_ave_popup_data=>get_user_name( lv_author )
              ins_count   = lv_ins
              mod_count   = lv_mod
              del_count   = lv_del
              hunk_count  = lv_hunk_cnt ) TO lt_auth.
          ENDIF.
        ENDIF.

        IF lv_ins = 0 AND lv_del = 0 AND lv_mod = 0 AND lv_hunk_cnt = 0.
          DELETE mt_diff_cache WHERE key-objtype = is_part-type
                                 AND key-objname = is_part-object_name.
          add_cr_diag( |SKIP { is_part-type } { is_part-object_name }: diff has no changed lines/hunks| ).
          RETURN.
        ENDIF.

        APPEND VALUE zif_ave_acr_types=>ty_obj_stats(
          objtype      = is_part-type
          class_name   = CONV #( is_part-class )
          obj_name     = is_part-object_name
          display_name = lv_disp_name
          versno_new   = lv_versno_new
          versno_old   = lv_versno_old
          author       = lv_author
          author_name  = zcl_ave_popup_data=>get_user_name( lv_author )
          datum        = lv_datum
          zeit         = lv_zeit
          ins_count    = lv_ins
          del_count    = lv_del
          mod_count    = lv_mod
          hunk_count   = lv_hunk_cnt
          hunk_ins     = lv_stat_hunk_ins
          hunk_mod     = lv_stat_hunk_mod
          hunk_del     = lv_stat_hunk_del
          bt_authors   = lt_auth
          is_created   = lv_is_created )
          TO mt_acr_stats.

      CATCH cx_root.
        " Skip this part on any error — report will simply omit it
    ENDTRY.
  ENDMETHOD.


  METHOD inject_approve_btn.
    result = iv_html.
    zcl_ave_acr_hunk_renderer=>inject_approve_btn(
      EXPORTING
        iv_key           = iv_key
        it_hunk_info     = mt_hunk_info
        it_approved      = mt_approved
        it_declined      = mt_declined
        it_decline_notes = mt_decline_notes
        it_hunk_actions  = mt_hunk_actions
        it_hunk_threads  = mt_hunk_threads
        iv_ai_enabled    = COND #( WHEN mv_desination IS NOT INITIAL
                                     AND mv_model IS NOT INITIAL
                                     AND mv_apikey IS NOT INITIAL
                                   THEN abap_true ELSE abap_false )
      CHANGING
        cv_html          = result
        ct_acr_stats     = mt_acr_stats ).
  ENDMETHOD.


  METHOD on_sapevent.
    CHECK mv_code_review = abap_true.
    DATA lv_cmd  TYPE string.
    DATA lv_rest TYPE string.
    DATA lv_sep_off TYPE i.
    FIND FIRST OCCURRENCE OF '~' IN action MATCH OFFSET lv_sep_off.
    IF sy-subrc <> 0. RETURN. ENDIF.
    lv_cmd = action(lv_sep_off).
    DATA lv_sep_start TYPE i.
    lv_sep_start = lv_sep_off + 1.
    lv_rest = action+lv_sep_start.
    DATA lv_scroll_txt TYPE string.
    IF lv_cmd = 'openuserdeclined'.
      DATA lv_scroll_sep TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rest MATCH OFFSET lv_scroll_sep.
      IF sy-subrc = 0.
        DATA(lv_tail_start) = lv_scroll_sep + 1.
        DATA(lv_tail) = lv_rest+lv_tail_start.
        IF lv_tail CN '0123456789~'.
          " payload contains another component before the scroll value
        ELSEIF lv_tail CA '~'.
          " keep command-specific parsing below
        ELSEIF lv_tail IS NOT INITIAL.
          lv_scroll_txt = lv_tail.
          lv_rest = lv_rest(lv_scroll_sep).
        ENDIF.
      ENDIF.
    ENDIF.

    IF lv_cmd = 'back'.
      back_to_report( ).
      RETURN.

    ELSEIF lv_cmd = 'prepare'.
      show_recalc_picker( ).
      RETURN.

    ELSEIF lv_cmd = 'recalcpick'.
      show_recalc_picker( ).
      RETURN.

    ELSEIF lv_cmd = 'prepare_selected'.
      delete_and_recalc_selected( iv_keys = lv_rest ).
      RETURN.

    ELSEIF lv_cmd = 'delete_recalc'.
      delete_and_recalc_selected( iv_keys = lv_rest ).
      RETURN.

    ELSEIF lv_cmd = 'openreview'.
      IF open_saved_code_review( ) = abap_false.
        MESSAGE 'Saved review diff is not available; use Prepare Code Review' TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
      RETURN.

    ELSEIF lv_cmd = 'aiprompt'.
      IF is_ai_enabled( ) = abap_true.
        do_ai_summary( ).
      ELSE.
        show_ai_prompt( ).
      ENDIF.
      RETURN.

    ELSEIF lv_cmd = 'askai'.
      do_askai( iv_hunk_key = lv_rest ).
      RETURN.

    ELSEIF lv_cmd = 'trtasks'.
      DATA lv_tt_type TYPE versobjtyp.
      DATA lv_tt_name TYPE versobjnam.
      IF strlen( lv_rest ) > 5 AND lv_rest+4(1) = '~'.
        lv_tt_type = lv_rest(4).
        lv_tt_name = lv_rest+5.
        show_tr_task_popup( iv_objtype = lv_tt_type iv_objname = lv_tt_name ).
      ENDIF.
      RETURN.

    ELSEIF lv_cmd = 'openobj'.
      " lv_rest = TYPE~OBJNAME~SCROLLY  (TYPE always 4 chars, SCROLLY optional trailing digits)
      DATA lv_oo_rest TYPE string.
      lv_oo_rest = lv_rest.
      DATA(lv_rev2) = reverse( lv_oo_rest ).
      DATA lv_tilde2 TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rev2 MATCH OFFSET lv_tilde2.
      IF sy-subrc = 0.
        DATA(lv_scand_start) = strlen( lv_oo_rest ) - lv_tilde2.
        DATA(lv_scand) = lv_oo_rest+lv_scand_start.
        IF lv_scand IS NOT INITIAL AND lv_scand CO '0123456789'.
          mv_cr_report_scroll = CONV i( lv_scand ).
          DATA(lv_oo_rest_len) = lv_scand_start - 1.
          IF lv_oo_rest_len >= 0.
            lv_oo_rest = lv_oo_rest(lv_oo_rest_len).
          ENDIF.
        ENDIF.
      ENDIF.
      " TYPE is always 4 chars
      DATA lv_oo_type TYPE versobjtyp.
      DATA lv_oo_name TYPE versobjnam.
      IF strlen( lv_oo_rest ) > 5 AND lv_oo_rest+4(1) = '~'.
        lv_oo_type = lv_oo_rest(4).
        lv_oo_name = lv_oo_rest+5.
        open_cr_part( iv_objtype = lv_oo_type iv_objname = lv_oo_name ).
      ENDIF.
      RETURN.

    ELSEIF lv_cmd = 'openuserdeclined'.
      show_user_declines( iv_user = CONV #( lv_rest ) ).
      RETURN.

    ELSEIF lv_cmd = 'openreviewer'.
      show_user_declines( iv_user = CONV #( lv_rest ) iv_reviewer = abap_true ).
      RETURN.

    ELSEIF lv_cmd = 'openclass'.
      show_class_objects( iv_class_name = CONV #( lv_rest ) ).
      RETURN.

    ELSEIF lv_cmd = 'approveall'.
      " lv_rest = TYPE~OBJNAME — approve all hunks for this object
      DATA lv_tld2 TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rest MATCH OFFSET lv_tld2.
      DATA lv_nst2 TYPE i.
      lv_nst2 = lv_tld2 + 1.
      DATA lv_type2  TYPE versobjtyp.
      DATA lv_onam2  TYPE versobjnam.
      lv_type2 = lv_rest(lv_tld2).
      lv_onam2 = lv_rest+lv_nst2.
      " Count hunks directly from mt_hunk_info (reliable even when mt_acr_stats is stale)
      DATA lv_hunk_cnt2 TYPE i.
      LOOP AT mt_hunk_info TRANSPORTING NO FIELDS
        WHERE objtype = lv_type2 AND obj_name = lv_onam2.
        lv_hunk_cnt2 += 1.
      ENDLOOP.
      " Fallback to mt_acr_stats if mt_hunk_info is empty
      IF lv_hunk_cnt2 = 0.
        READ TABLE mt_acr_stats INTO DATA(ls_st2)
          WITH KEY objtype = lv_type2 obj_name = lv_onam2.
        IF sy-subrc = 0. lv_hunk_cnt2 = ls_st2-hunk_count. ENDIF.
      ENDIF.
      IF lv_hunk_cnt2 > 0.
        DO lv_hunk_cnt2 TIMES.
          DATA(lv_hk) = |{ lv_rest }~{ sy-index }|.
          CHECK zcl_ave_acr_state=>is_own_hunk(
            iv_hunk_key  = lv_hk
            it_hunk_info = mt_hunk_info ) = abap_false.
          INSERT lv_hk INTO TABLE mt_approved.
          DELETE TABLE mt_declined FROM lv_hk.
          set_hunk_action( iv_hunk_key = lv_hk iv_action = 'A' ).
        ENDDO.
      ENDIF.

    ELSEIF lv_cmd = 'addcomment' OR lv_cmd = 'editreview'.
      DATA lv_er_key TYPE string.
      lv_er_key = lv_rest.
      CLEAR mv_pending_decline.
      CLEAR mv_pending_edit.
      DATA(lv_er_note) = ``.
      IF lv_cmd = 'editreview'.
        mv_pending_edit = lv_er_key.
        lv_er_note = get_last_own_comment( lv_er_key ).
      ENDIF.
      mo_note_dlg = NEW zcl_ave_acr_note_dlg(
        iv_title    = lv_er_key
        iv_hunk_key = lv_er_key
        iv_note     = lv_er_note ).
      SET HANDLER on_note_dlg_saved FOR mo_note_dlg.
      SET HANDLER on_note_dlg_cancelled FOR mo_note_dlg.
      mo_note_dlg->show( ).
      RETURN.

    ELSEIF lv_cmd = 'undo'.
      DATA lv_undo_key TYPE string.
      lv_undo_key = lv_rest.
      IF zcl_ave_acr_state=>is_own_hunk(
           iv_hunk_key  = lv_undo_key
           it_hunk_info = mt_hunk_info ) = abap_true.
        MESSAGE 'You cannot undo review status for your own block' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
      DELETE TABLE mt_approved FROM lv_undo_key.
      DELETE TABLE mt_declined FROM lv_undo_key.
      DELETE TABLE mt_decline_notes WITH TABLE KEY hunk_key = lv_undo_key.
      clear_hunk_action( lv_undo_key ).
      IF mv_decline_view_user IS NOT INITIAL.
        show_user_declines( iv_user = mv_decline_view_user iv_reviewer = mv_reviewer_view ).
      ELSEIF mv_cur_objtype IS NOT INITIAL AND mv_cr_base_html IS INITIAL.
        open_cr_part( iv_objtype = mv_cur_objtype iv_objname = mv_cur_objname ).
      ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
        set_html( inject_approve_btn( iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ) ).
      ENDIF.
      regen_acr_report( ).
      refresh_rpt_row( ).
      save_review_to_db( iv_silent = abap_true ).
      RETURN.

    ELSEIF lv_cmd = 'approve' OR lv_cmd = 'decline'.
      DATA lv_key TYPE string.
      lv_key = lv_rest.
      IF zcl_ave_acr_state=>is_own_hunk(
           iv_hunk_key  = lv_key
           it_hunk_info = mt_hunk_info ) = abap_true.
        MESSAGE 'You cannot approve or decline your own block' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
      IF lv_cmd = 'approve'.
        INSERT lv_key INTO TABLE mt_approved.
        DELETE TABLE mt_declined FROM lv_key.
        set_hunk_action( iv_hunk_key = lv_key iv_action = 'A' ).
      ELSE.
        " Open note dialog — decline is registered only when user clicks Save with a comment
        mv_pending_decline = lv_key.
        mo_note_dlg = NEW zcl_ave_acr_note_dlg(
          iv_title    = lv_key
          iv_hunk_key = lv_key
          iv_note     = `` ).
        SET HANDLER on_note_dlg_saved FOR mo_note_dlg.
        SET HANDLER on_note_dlg_cancelled FOR mo_note_dlg.
        mo_note_dlg->show( ).
        RETURN.  " Decline will be registered in on_note_dlg_saved event
      ENDIF.

      IF mv_decline_view_user IS NOT INITIAL.
        show_user_declines( iv_user = mv_decline_view_user iv_reviewer = mv_reviewer_view ).
        regen_acr_report( ).
        refresh_rpt_row( ).
        save_review_to_db( iv_silent = abap_true ).
        RETURN.
      ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
        DATA(lv_html) = inject_approve_btn(
          iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ).

        " Scroll to the acted chunk by its anchor id
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

        set_html( lv_html ).
        regen_acr_report( ).
        refresh_rpt_row( ).
        save_review_to_db( iv_silent = abap_true ).
        RETURN.
      ENDIF.
    ENDIF.

    " approveall path (or approve without cached html)
    IF mv_decline_view_user IS NOT INITIAL.
      show_user_declines( iv_user = mv_decline_view_user iv_reviewer = mv_reviewer_view ).
    ELSEIF mv_cur_objtype IS NOT INITIAL AND mv_cr_base_html IS INITIAL.
      open_cr_part( iv_objtype = mv_cur_objtype iv_objname = mv_cur_objname ).
    ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
      set_html( inject_approve_btn( iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ) ).
    ENDIF.
    regen_acr_report( ).
    refresh_rpt_row( ).
    save_review_to_db( iv_silent = abap_true ).
  ENDMETHOD.


  METHOD maximize_html.
    CHECK mv_focus_html = abap_false.
    mv_focus_html = abap_true.
    mo_toolbar->set_button_info(
      EXPORTING fcode = 'FOCUS_TOGGLE'
                text  = 'Standard View'
                icon  = CONV #( icon_view_maximize ) ).
    mo_split_main->set_column_width( id = 1 width = 0 ).
    mo_split_main->set_column_width( id = 2 width = 100 ).
    mo_split_main->set_column_sash( id = 1 type = 0 value = 0 ).
    mo_split_2p_wrap->set_row_height( id = 1 height = 0 ).
    mo_split_2p_wrap->set_row_height( id = 2 height = 100 ).
    mo_split_2p_wrap->set_row_sash( id = 1 type = 0 value = 0 ).
  ENDMETHOD.


  METHOD back_to_report.
    CLEAR mv_decline_view_user.
    CLEAR mv_reviewer_view.
    maximize_html( ).
    DATA(lv_html) = mv_cr_report_html.
    " Scroll to the last opened object/class row by anchor
    IF mv_cr_cur_key IS NOT INITIAL.
      " class drilldown sets mv_cr_cur_key = 'class_CLASSNAME' → anchor id is already 'class_CLASSNAME'
      " object drilldown sets mv_cr_cur_key = 'TYPE~OBJNAME'   → anchor id is 'obj_TYPE~OBJNAME'
      DATA(lv_is_class_anchor) = abap_false.
      IF strlen( mv_cr_cur_key ) >= 6.
        IF mv_cr_cur_key(6) = 'class_'.
          lv_is_class_anchor = abap_true.
        ENDIF.
      ENDIF.
      DATA(lv_anchor) = COND string(
        WHEN lv_is_class_anchor = abap_true
        THEN mv_cr_cur_key
        ELSE |obj_{ escape( val = mv_cr_cur_key format = cl_abap_format=>e_html_attr ) }| ).
      DATA(lv_script) =
        `<script>window.onload=function(){` &&
        `var e=document.getElementById('` && lv_anchor && `');` &&
        `if(e)e.scrollIntoView(true);}` &&
        `</script></head>`.
      lv_html = replace( val = lv_html sub = `</head>` with = lv_script ).
    ENDIF.
    set_html( lv_html ).
  ENDMETHOD.


  METHOD show_class_objects.
    " Track for back_to_report scroll
    CLEAR mv_cr_base_html.
    mv_cr_cur_key = |class_{ iv_class_name }|.

    " Collect all hunks that belong to this class (any part: METH, CLSD, CPUB...)
    DATA lt_hunks TYPE STANDARD TABLE OF ty_hunk_info WITH DEFAULT KEY.
    LOOP AT mt_hunk_info INTO DATA(ls_hi)
      WHERE class_name = iv_class_name.
      APPEND ls_hi TO lt_hunks.
    ENDLOOP.
    SORT lt_hunks BY objtype obj_name hunk_no.

    " Build HTML — same toolbar/CSS as SHOW_USER_DECLINES
    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:44px 28px 20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `.toolbar{margin-bottom:14px}` &&
      `.toolbar a{display:inline-block;margin-right:4px}` &&
      `.objhdr{margin:18px 0 8px 0;background:#dbe9ff;color:#2c3e50;padding:5px 10px;` &&
      `font-weight:bold;white-space:nowrap}` &&
      `.block{margin:0 0 14px 0}` &&
      `.comments{display:block;width:100%;margin:0 0 8px 0}` &&
      `.codewrap{display:block;clear:both;width:100%;margin:0;padding:0}` &&
      `.blame{margin:0 0 6px 0;color:#5e6a75;font-style:italic;white-space:nowrap}` &&
      `.blkinfo{margin:5px 0 2px 0;color:#2c3e50;font-weight:bold;white-space:nowrap}` &&
      `.muted{color:#777;font-weight:normal}` &&
      `.meta{display:block;margin:0 0 4px 0;color:#7f8c99;font-size:10px;font-weight:normal}` &&
      `.note{display:table;margin:6px 0 6px 0;padding:5px 9px;background:#f3f9ff;` &&
      `border:1px solid #a8cde8;color:#155f8f;font-style:italic;font-weight:bold;border-radius:6px}` &&
      `table.diff{border-collapse:collapse;width:100%;font-size:12px;margin:0 0 4px 0}` &&
      `.diff .ln{color:#aaa;text-align:right;padding:1px 10px 1px 5px;` &&
      `min-width:42px;border-right:1px solid #e0e0e0;white-space:nowrap;background:#fafafa}` &&
      `.diff .cd{padding:1px 8px;white-space:pre}` &&
      `.back{position:fixed;top:8px;left:8px;z-index:999;background:#3498db;color:#fff;padding:4px 10px;border-radius:4px;` &&
      `text-decoration:none;font-weight:bold;white-space:nowrap}` &&
      `.filter-btn{background:#eee;color:#333;padding:4px 10px;border-radius:4px;cursor:pointer;` &&
      `font:bold 12px Consolas,monospace;border:1px solid #bbb;text-decoration:none;white-space:nowrap}` &&
      `.filter-btn.active{background:#e74c3c;color:#fff;border-color:#c0392b}` &&
      `.filter-btn.active.comments{background:#27ae60;border-color:#1e8449}`.

    DATA(lv_ai_prompt_label) = COND string(
      WHEN is_ai_enabled( ) = abap_true THEN `AI Summary`
      ELSE `AI prompt` ).

    DATA(lv_html) =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ lv_css }</style>| &&
      `<script>` &&
      `function filterBlocks(mode){` &&
        `var btns=document.querySelectorAll('.filter-btn');` &&
        `btns.forEach(function(b){b.classList.remove('active');});` &&
        `var grps=document.querySelectorAll('.objgrp');` &&
        `grps.forEach(function(g){` &&
          `g.style.display='';` &&
          `g.querySelectorAll('.block').forEach(function(b){b.style.display='';});` &&
        `});` &&
        `if(!mode){return;}` &&
        `var btn=document.getElementById('btn_'+mode);` &&
        `if(btn){btn.classList.add('active');if(mode==='comments')btn.classList.add('comments');}` &&
        `grps.forEach(function(g){` &&
          `var anyVisible=false;` &&
          `g.querySelectorAll('.block').forEach(function(b){` &&
            `var show=false;` &&
            `if(mode==='declined'){` &&
              `var notes=b.querySelectorAll('.note');` &&
              `for(var i=0;i<notes.length;i++){if(notes[i].getAttribute('style')){show=true;break;}}` &&
            `}else if(mode==='comments'){` &&
              `show=b.querySelector('.comments')!==null;` &&
            `}` &&
            `b.style.display=show?'':'none';` &&
            `if(show)anyVisible=true;` &&
          `});` &&
          `g.style.display=anyVisible?'':'none';` &&
        `});` &&
      `}` &&
      `</script>` &&
      `</head><body>` &&
      |<a class="back" href="sapevent:back~0">Back</a>| &&
      `<p style="margin:0 0 14px 0">` &&
      `<a id="btn_declined" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'declined');return false">Declined only</a>` &&
      `&nbsp;` &&
      `<a id="btn_comments" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'comments');return false">Comments only</a>` &&
      `&nbsp;` &&
      |<a class="filter-btn" href="sapevent:aiprompt~0">{ lv_ai_prompt_label }</a>| &&
      `</p>` &&
      |<h2>Class: { escape( val = CONV string( iv_class_name ) format = cl_abap_format=>e_html_text ) }</h2>|.

    IF lt_hunks IS INITIAL.
      lv_html = lv_html &&
        |<p style="color:#888">No changed blocks found for this class.</p>| &&
        |</body></html>|.
      maximize_html( ).
      set_html( lv_html ).
      RETURN.
    ENDIF.

    DATA lv_cur_obj TYPE string VALUE `####`.
    LOOP AT lt_hunks INTO DATA(ls_hunk).
      DATA(lv_obj_key) = |{ ls_hunk-objtype }~{ ls_hunk-obj_name }|.

      " Object group header
      IF lv_obj_key <> lv_cur_obj.
        IF lv_cur_obj <> `####`.
          lv_html = lv_html && render_ai_summary_html(
            iv_objtype = CONV #( lv_cur_obj(4) )
            iv_objname = CONV #( lv_cur_obj+5 ) ) && `</div>`.
        ENDIF.
        lv_cur_obj = lv_obj_key.
        DATA lv_obj_blocks  TYPE i.
        DATA lv_obj_changes TYPE i.
        CLEAR: lv_obj_blocks, lv_obj_changes.
        LOOP AT lt_hunks INTO DATA(ls_s) WHERE objtype = ls_hunk-objtype AND obj_name = ls_hunk-obj_name.
          lv_obj_blocks  += 1.
          lv_obj_changes += ls_s-change_count.
        ENDLOOP.
        DATA(lv_hdr_title) = COND string(
          WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
          ELSE CONV string( ls_hunk-obj_name ) ).
        lv_html = lv_html &&
          `<div class="objgrp">` &&
          |<div class="objhdr">| &&
          |<a href="sapevent:openobj~{ lv_obj_key }" style="color:inherit;text-decoration:none">| &&
          |{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
          |{ escape( val = lv_hdr_title format = cl_abap_format=>e_html_text ) }</a>| &&
          | <span class="muted">blocks</span> { lv_obj_blocks }| &&
          | <span class="muted">changes</span> { lv_obj_changes } lines</div>|.
      ENDIF.

      " Actions + comments + diff — reuse same rendering as SHOW_USER_DECLINES
      DATA(lv_clean_html) = ls_hunk-html.
      IF mv_two_pane = abap_false AND lv_clean_html CS `<td class="sep"></td>`.
        DATA(lv_rows_html) = lv_clean_html.
        DATA(lv_norm_html) = ``.
        WHILE lv_rows_html CS `<tr`.
          DATA(lv_row_start) = sy-fdpos.
          IF lv_row_start > 0.
            lv_norm_html = lv_norm_html && lv_rows_html(lv_row_start).
            lv_rows_html = lv_rows_html+lv_row_start.
          ENDIF.
          DATA lv_row_close_rel TYPE i.
          FIND FIRST OCCURRENCE OF `</tr>` IN lv_rows_html MATCH OFFSET lv_row_close_rel.
          IF sy-subrc <> 0.
            lv_norm_html = lv_norm_html && lv_rows_html.
            CLEAR lv_rows_html.
            EXIT.
          ENDIF.
          DATA(lv_row_close) = lv_row_close_rel + 5.
          DATA(lv_row_html)  = lv_rows_html(lv_row_close).
          lv_rows_html = lv_rows_html+lv_row_close.
          IF lv_row_html CS `<td class="sep"></td>`.
            DATA lv_gt_pos   TYPE i.
            DATA lv_sep_pos  TYPE i.
            FIND FIRST OCCURRENCE OF `>` IN lv_row_html MATCH OFFSET lv_gt_pos.
            FIND FIRST OCCURRENCE OF `<td class="sep"></td>` IN lv_row_html MATCH OFFSET lv_sep_pos.
            IF sy-subrc = 0 AND lv_gt_pos >= 0 AND lv_sep_pos > lv_gt_pos.
              DATA(lv_body_left_off)  = lv_gt_pos + 1.
              DATA(lv_body_left_len)  = lv_sep_pos - lv_gt_pos - 1.
              DATA(lv_body_right_off) = lv_sep_pos + 21.
              DATA(lv_row_prefix_len) = lv_gt_pos + 1.
              DATA(lv_body_left)  = lv_row_html+lv_body_left_off(lv_body_left_len).
              DATA(lv_body_right) = lv_row_html+lv_body_right_off.
              DATA(lv_row_len)    = strlen( lv_body_right ).
              IF lv_row_len >= 5.
                DATA(lv_body_right_len) = lv_row_len - 5.
                lv_body_right = lv_body_right(lv_body_right_len).
              ENDIF.
              DATA(lv_plain_left)  = lv_body_left.
              DATA(lv_plain_right) = lv_body_right.
              REPLACE ALL OCCURRENCES OF REGEX `<[^>]+>` IN lv_plain_left  WITH ``.
              REPLACE ALL OCCURRENCES OF REGEX `<[^>]+>` IN lv_plain_right WITH ``.
              CONDENSE lv_plain_left  NO-GAPS.
              CONDENSE lv_plain_right NO-GAPS.
              lv_norm_html = lv_norm_html &&
                lv_row_html(lv_row_prefix_len) &&
                COND string(
                  WHEN strlen( lv_plain_right ) >= strlen( lv_plain_left )
                  THEN lv_body_right ELSE lv_body_left ) &&
                `</tr>`.
            ELSE.
              lv_norm_html = lv_norm_html && lv_row_html.
            ENDIF.
          ELSE.
            lv_norm_html = lv_norm_html && lv_row_html.
          ENDIF.
        ENDWHILE.
        lv_clean_html = lv_norm_html && lv_rows_html.
      ENDIF.
      DATA(lv_code_html) = COND string(
        WHEN lv_clean_html IS NOT INITIAL
        THEN |<table class="diff"><tbody>{ lv_clean_html }</tbody></table>|
        ELSE `<div style="color:#888;margin:4px 0 10px">Diff not available.</div>` ).

      DATA(lv_actions_html) = zcl_ave_acr_renderer=>render_hunk_actions_html(
        iv_hunk_key     = ls_hunk-hunk_key
        it_approved     = mt_approved
        it_declined     = mt_declined
        it_hunk_actions = mt_hunk_actions
        it_hunk_info    = mt_hunk_info
        it_hunk_threads = mt_hunk_threads
        iv_ai_enabled   = COND #( WHEN mv_desination IS NOT INITIAL
                                    AND mv_model IS NOT INITIAL
                                    AND mv_apikey IS NOT INITIAL
                                  THEN abap_true ELSE abap_false ) ).
      DATA(lv_block_title) = COND string(
        WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
        ELSE CONV string( ls_hunk-obj_name ) ).
      lv_html = lv_html &&
        `<div class="block">` &&
        |<div class="blkinfo">{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
        |{ escape( val = lv_block_title format = cl_abap_format=>e_html_text ) } | &&
        |Block #{ ls_hunk-hunk_no }| &&
        | <span class="muted">line</span> { ls_hunk-start_line }| &&
        | <span class="muted">changes</span> { ls_hunk-change_count }</div>| &&
        lv_actions_html.

      DATA(lv_comments_html) = ``.
      DATA(ls_thread) = get_hunk_thread( ls_hunk ).
      IF ls_thread-messages IS NOT INITIAL.
        LOOP AT ls_thread-messages INTO DATA(ls_msg).
          CHECK ls_msg-text IS NOT INITIAL.
          DATA(lv_note_esc) = escape( val = ls_msg-text format = cl_abap_format=>e_html_text ).
          REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_note_esc WITH `<br>`.
          DATA(lv_created_at_txt) = format_timestamp( ls_msg-created_at ).
          DATA(lv_note_style) = COND string(
            WHEN ls_msg-is_decline = abap_true
            THEN ` style="background:#fff1f4;border-color:#efb8c8;color:#9f3b57"`
            ELSE `` ).
          lv_comments_html = lv_comments_html &&
            |<span class="meta">{ escape( val = CONV string( ls_msg-author ) format = cl_abap_format=>e_html_text ) }| &&
            | / { escape( val = CONV string( ls_msg-author_name ) format = cl_abap_format=>e_html_text ) }| &&
            | / { escape( val = lv_created_at_txt format = cl_abap_format=>e_html_text ) }</span>| &&
            |<div class="note"{ lv_note_style }>{ lv_note_esc }</div>|.
        ENDLOOP.
      ENDIF.
      IF lv_comments_html IS NOT INITIAL.
        lv_html = lv_html &&
          |<div id="{ get_hunk_scroll_anchor( ls_hunk-hunk_key ) }" class="comments">{ lv_comments_html }</div>|.
      ENDIF.

      lv_html = lv_html &&
        `<div class="codewrap">` &&
        lv_code_html &&
        `</div></div>`.
    ENDLOOP.

    IF lv_cur_obj <> `####`.
      lv_html = lv_html && render_ai_summary_html(
        iv_objtype = CONV #( lv_cur_obj(4) )
        iv_objname = CONV #( lv_cur_obj+5 ) ).
    ENDIF.

    lv_html = lv_html && `</div></body></html>`.
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD build_ai_hunk_prompt.
    DATA(lv_nl) = cl_abap_char_utilities=>newline.

    READ TABLE mt_hunk_info INTO DATA(ls_hunk)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lt_src_old TYPE abaptxt255_tab.
    DATA lt_src_new TYPE abaptxt255_tab.
    DATA lt_obj_diff TYPE ty_t_diff.

    IF ls_hunk-versno_old IS NOT INITIAL.
      lt_src_old = zcl_ave_popup_data=>get_ver_source(
        i_objtype = ls_hunk-objtype
        i_objname = ls_hunk-obj_name
        i_versno  = ls_hunk-versno_old ).
    ENDIF.
    lt_src_new = zcl_ave_popup_data=>get_ver_source(
      i_objtype = ls_hunk-objtype
      i_objname = ls_hunk-obj_name
      i_versno  = ls_hunk-versno_new ).

    IF ls_hunk-versno_old IS INITIAL.
      LOOP AT lt_src_new INTO DATA(ls_new_line).
        APPEND VALUE ty_diff_op( op = '+' text = CONV string( ls_new_line ) ) TO lt_obj_diff.
      ENDLOOP.
    ELSE.
      lt_obj_diff = zcl_ave_popup_diff=>compute_diff(
        it_old        = lt_src_old
        it_new        = lt_src_new
        i_title       = CONV #( ls_hunk-obj_name )
        i_confirm_key = |ASKAI~{ ls_hunk-objtype }~{ ls_hunk-obj_name }|
        i_ignore_case = mv_ignore_case ).
    ENDIF.

    DATA lv_hunk_cnt TYPE i.
    DATA lv_in_block TYPE abap_bool.
    DATA lt_deleted TYPE string_table.
    DATA lt_inserted TYPE string_table.
    DATA lv_hunk_code TYPE string.

    LOOP AT lt_obj_diff INTO DATA(ls_op).
      CASE ls_op-op.
        WHEN '+' OR '-'.
          IF lv_in_block = abap_false.
            lv_in_block = abap_true.
            CLEAR: lt_deleted, lt_inserted.
          ENDIF.
          IF ls_op-op = '+'.
            APPEND ls_op-text TO lt_inserted.
          ELSE.
            APPEND ls_op-text TO lt_deleted.
          ENDIF.

        WHEN OTHERS.
          IF lv_in_block = abap_true.
            IF lt_deleted IS NOT INITIAL OR lt_inserted IS NOT INITIAL.
              lv_hunk_cnt += 1.
              IF lv_hunk_cnt = ls_hunk-hunk_no.
                EXIT.
              ENDIF.
            ENDIF.
            lv_in_block = abap_false.
            CLEAR: lt_deleted, lt_inserted.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    IF lv_hunk_cnt <> ls_hunk-hunk_no AND lv_in_block = abap_true
       AND ( lt_deleted IS NOT INITIAL OR lt_inserted IS NOT INITIAL ).
      lv_hunk_cnt += 1.
    ENDIF.

    IF lv_hunk_cnt <> ls_hunk-hunk_no.
      RETURN.
    ENDIF.

    DATA(lv_kind) = COND string(
      WHEN lt_deleted IS NOT INITIAL AND lt_inserted IS NOT INITIAL THEN `changed`
      WHEN lt_inserted IS NOT INITIAL                              THEN `added`
      ELSE                                                               `deleted` ).

    lv_hunk_code = |>>> start of { lv_kind } block for LLM| && lv_nl.
    LOOP AT lt_deleted INTO DATA(lv_deleted).
      lv_hunk_code = lv_hunk_code && `- ` && lv_deleted && lv_nl.
    ENDLOOP.
    LOOP AT lt_inserted INTO DATA(lv_inserted).
      lv_hunk_code = lv_hunk_code && `+ ` && lv_inserted && lv_nl.
    ENDLOOP.
    lv_hunk_code = lv_hunk_code && |<<< end of { lv_kind } block for LLM|.

    DATA(lv_disp) = COND string(
      WHEN ls_hunk-class_name IS NOT INITIAL AND ls_hunk-display_name IS NOT INITIAL
      THEN |{ ls_hunk-class_name }=>{ ls_hunk-display_name }|
      WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
      ELSE CONV string( ls_hunk-obj_name ) ).

    DATA: lv_obj_name TYPE string.

    IF ls_hunk-class_name IS NOT INITIAL.
      lv_obj_name = | Class { ls_hunk-class_name } method { ls_hunk-display_name }|.
    ELSE.
      lv_obj_name = |{ ls_hunk-objtype } { ls_hunk-obj_name }|.
    ENDIF.
    result =
      `You are ABAP code business reviewer. Very very Brifly describe meaning of the changes. - deleted, + inserted. Just describe what you see - no deep research. No suggests.` && lv_nl &&
      lv_nl &&
      `Output format - Object name` && lv_nl &&

      lv_nl &&
      `Below are code changes` && lv_nl &&
      'Object name: ' && lv_obj_name  && lv_nl &&
      lv_nl &&
      lv_hunk_code.
  ENDMETHOD.


  METHOD is_ai_enabled.
    result = COND #( WHEN mv_desination IS NOT INITIAL
                       AND mv_model IS NOT INITIAL
                       AND mv_apikey IS NOT INITIAL
                     THEN abap_true ELSE abap_false ).
  ENDMETHOD.


  METHOD get_ai_hunk_comment.
    DATA ls_thread TYPE ty_hunk_thread.
    READ TABLE mt_hunk_info INTO DATA(ls_hunk)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    IF sy-subrc = 0.
      ls_thread = get_hunk_thread( ls_hunk ).
    ELSE.
      READ TABLE mt_hunk_threads INTO ls_thread
        WITH TABLE KEY hunk_key = iv_hunk_key.
    ENDIF.
    CHECK ls_thread-messages IS NOT INITIAL.

    DATA(lv_idx) = lines( ls_thread-messages ).
    WHILE lv_idx > 0.
      READ TABLE ls_thread-messages INTO DATA(ls_msg) INDEX lv_idx.
      IF sy-subrc = 0
         AND ls_msg-author = 'AI_Assistant'
         AND ls_msg-text IS NOT INITIAL.
        result = ls_msg-text.
        RETURN.
      ENDIF.
      lv_idx -= 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD get_hunk_thread.
    READ TABLE mt_hunk_threads INTO result
      WITH TABLE KEY hunk_key = is_hunk-hunk_key.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    LOOP AT mt_hunk_threads INTO result
      WHERE objtype = is_hunk-objtype
        AND obj_name = is_hunk-obj_name
        AND hunk_no = is_hunk-hunk_no.
      RETURN.
    ENDLOOP.

    CLEAR result.
  ENDMETHOD.


  METHOD get_ai_summary_key.
    result = |AI_SUMMARY~{ iv_objtype }~{ iv_objname }|.
  ENDMETHOD.


  METHOD render_ai_summary_html.
    DATA(lv_key) = get_ai_summary_key(
      iv_objtype = iv_objtype
      iv_objname = iv_objname ).
    READ TABLE mt_hunk_threads INTO DATA(ls_thread)
      WITH TABLE KEY hunk_key = lv_key.
    IF sy-subrc <> 0.
      LOOP AT mt_hunk_threads INTO ls_thread
        WHERE objtype = iv_objtype
          AND obj_name = iv_objname.
        IF ls_thread-hunk_key CP 'AI_SUMMARY~*'
           OR ls_thread-change_kind = 'AI_SUMMARY'.
          EXIT.
        ENDIF.
        CLEAR ls_thread.
      ENDLOOP.
    ENDIF.
    CHECK ls_thread-messages IS NOT INITIAL.

    DATA(lv_idx) = lines( ls_thread-messages ).
    WHILE lv_idx > 0.
      READ TABLE ls_thread-messages INTO DATA(ls_msg) INDEX lv_idx.
      IF sy-subrc = 0
         AND ls_msg-author = 'AI_SUMMARY'
         AND ls_msg-text IS NOT INITIAL.
        DATA(lv_text) = escape( val = ls_msg-text format = cl_abap_format=>e_html_text ).
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_text WITH `<br>`.
        DATA(lv_created_at_txt) = format_timestamp( ls_msg-created_at ).
        result =
          |<div id="{ get_summary_scroll_anchor( iv_objtype = iv_objtype iv_objname = iv_objname ) }" class="comments" style="margin:12px 0 18px 0">| &&
          `<span class="meta">AI_SUMMARY / AI Summary / ` &&
          escape( val = lv_created_at_txt format = cl_abap_format=>e_html_text ) &&
          `</span>` &&
          `<div class="note" style="background:#f5f0ff;border-color:#c8b6e8;color:#5f3b8f">` &&
          lv_text &&
          `</div></div>`.
        RETURN.
      ENDIF.
      lv_idx -= 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD get_hunk_scroll_anchor.
    result = |ai_comment_{ iv_hunk_key }|.
    TRANSLATE result USING '/_ ~_ _ '.
  ENDMETHOD.


  METHOD get_summary_scroll_anchor.
    result = |ai_summary_{ iv_objtype }_{ iv_objname }|.
    TRANSLATE result USING '/_ ~_ _ '.
  ENDMETHOD.


  METHOD scroll_last_html_to.
    CHECK iv_anchor IS NOT INITIAL.
    CHECK mv_last_html IS NOT INITIAL.

    DATA(lv_anchor) = escape( val = iv_anchor format = cl_abap_format=>e_html_attr ).
    DATA(lv_fallback_anchor) = ``.
    FIND REGEX `_[0-9]+$` IN iv_anchor MATCH OFFSET DATA(lv_suffix_off).
    IF sy-subrc = 0.
      DATA(lv_suffix) = iv_anchor+lv_suffix_off.
      IF strlen( lv_suffix ) > 1.
        lv_suffix = lv_suffix+1.
        lv_fallback_anchor = |acr_c{ lv_suffix }|.
      ENDIF.
    ENDIF.
    DATA(lv_html) = mv_last_html.
    DATA(lv_script) =
      `<script>window.onload=function(){` &&
      `var e=document.getElementById('` && lv_anchor && `');` &&
      COND string(
        WHEN lv_fallback_anchor IS NOT INITIAL
        THEN `if(!e)e=document.getElementById('` &&
             escape( val = lv_fallback_anchor format = cl_abap_format=>e_html_attr ) && `');`
        ELSE `` ) &&
      `if(e)e.scrollIntoView({block:'center'});}` &&
      `</script></head>`.
    lv_html = replace(
      val  = lv_html
      sub  = `</head>`
      with = lv_script ).
    set_html( lv_html ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.


  METHOD refresh_ai_html_progress.
    IF mv_decline_view_user IS NOT INITIAL.
      show_user_declines( iv_user = mv_decline_view_user iv_reviewer = mv_reviewer_view ).
    ELSEIF iv_objtype IS NOT INITIAL AND iv_objname IS NOT INITIAL.
      open_cr_part( iv_objtype = iv_objtype iv_objname = iv_objname ).
    ELSEIF mv_cur_objtype IS NOT INITIAL AND mv_cur_objname IS NOT INITIAL.
      open_cr_part( iv_objtype = mv_cur_objtype iv_objname = mv_cur_objname ).
    ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
      set_html( inject_approve_btn( iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ) ).
    ENDIF.

    IF iv_summary = abap_true.
      scroll_last_html_to( get_summary_scroll_anchor(
        iv_objtype = iv_objtype
        iv_objname = iv_objname ) ).
    ELSE.
      scroll_last_html_to( get_hunk_scroll_anchor( iv_hunk_key ) ).
    ENDIF.
  ENDMETHOD.


  METHOD save_ai_summary.
    CHECK iv_text IS NOT INITIAL.

    DATA(lv_key) = get_ai_summary_key(
      iv_objtype = iv_objtype
      iv_objname = iv_objname ).
    DATA lv_msg_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_msg_ts.

    READ TABLE mt_hunk_threads ASSIGNING FIELD-SYMBOL(<ls_thread>)
      WITH TABLE KEY hunk_key = lv_key.
    IF sy-subrc <> 0.
      READ TABLE mt_hunk_info INTO DATA(ls_hunk_info)
        WITH KEY objtype = iv_objtype obj_name = iv_objname.
      INSERT VALUE ty_hunk_thread(
        hunk_key     = lv_key
        objtype      = iv_objtype
        obj_name     = iv_objname
        class_name   = ls_hunk_info-class_name
        display_name = ls_hunk_info-display_name
        hunk_no      = 0
        start_line   = 0
        change_count = 0
        change_kind  = 'AI_SUMMARY' ) INTO TABLE mt_hunk_threads.
      READ TABLE mt_hunk_threads ASSIGNING <ls_thread>
        WITH TABLE KEY hunk_key = lv_key.
    ENDIF.

    IF <ls_thread> IS ASSIGNED.
      DELETE <ls_thread>-messages WHERE author = 'AI_SUMMARY'.
      APPEND VALUE ty_decline_msg(
        author      = 'AI_SUMMARY'
        author_name = 'AI Summary'
        created_at  = lv_msg_ts
        is_decline  = abap_false
        text        = iv_text ) TO <ls_thread>-messages.
    ENDIF.
  ENDMETHOD.


  METHOD do_ai_summary.
    IF is_ai_enabled( ) = abap_false.
      show_ai_prompt( ).
      RETURN.
    ENDIF.

    DATA lt_hunks TYPE STANDARD TABLE OF ty_hunk_info WITH DEFAULT KEY.
    DATA(lv_is_class_key) = abap_false.
    IF strlen( mv_cr_cur_key ) >= 6.
      IF mv_cr_cur_key(6) = 'class_'.
        lv_is_class_key = abap_true.
      ENDIF.
    ENDIF.
    IF mv_cur_objtype IS NOT INITIAL AND mv_cur_objname IS NOT INITIAL.
      LOOP AT mt_hunk_info INTO DATA(ls_cur_hunk)
        WHERE objtype = mv_cur_objtype AND obj_name = mv_cur_objname.
        APPEND ls_cur_hunk TO lt_hunks.
      ENDLOOP.
    ELSEIF mv_cr_cur_key IS NOT INITIAL
       AND lv_is_class_key = abap_false.
      DATA lv_tld TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN mv_cr_cur_key MATCH OFFSET lv_tld.
      IF sy-subrc = 0.
        DATA(lv_name_start) = lv_tld + 1.
        DATA(lv_key_objtype) = CONV versobjtyp( mv_cr_cur_key(lv_tld) ).
        DATA(lv_key_objname) = CONV versobjnam( mv_cr_cur_key+lv_name_start ).
        LOOP AT mt_hunk_info INTO DATA(ls_key_hunk)
          WHERE objtype = lv_key_objtype
            AND obj_name = lv_key_objname.
          APPEND ls_key_hunk TO lt_hunks.
        ENDLOOP.
      ENDIF.
    ELSEIF mv_cr_cur_key IS NOT INITIAL
       AND lv_is_class_key = abap_true.
      DATA(lv_class_start) = 6.
      DATA(lv_class_name) = CONV seoclsname( mv_cr_cur_key+lv_class_start ).
      LOOP AT mt_hunk_info INTO DATA(ls_class_hunk) WHERE class_name = lv_class_name.
        APPEND ls_class_hunk TO lt_hunks.
      ENDLOOP.
    ELSE.
      lt_hunks = VALUE #( FOR ls_hunk_all IN mt_hunk_info ( ls_hunk_all ) ).
    ENDIF.

    SORT lt_hunks BY class_name objtype obj_name hunk_no.
    IF lt_hunks IS INITIAL.
      MESSAGE 'No changed blocks found for AI summary' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA(lv_nl) = cl_abap_char_utilities=>newline.
    DATA lv_cur_obj_key TYPE string.
    DATA lv_comments TYPE string.
    DATA lv_any_summary TYPE abap_bool.
    FIELD-SYMBOLS <ls_thread> TYPE ty_hunk_thread.

    LOOP AT lt_hunks INTO DATA(ls_hunk).
      DATA(lv_obj_key) = |{ ls_hunk-objtype }~{ ls_hunk-obj_name }|.
      IF lv_cur_obj_key IS NOT INITIAL AND lv_obj_key <> lv_cur_obj_key.
        IF lv_comments IS NOT INITIAL.
          DATA(lv_summary_prompt) = `Please make summary fo changes below:` && lv_nl && lv_comments.
          DATA(lv_summary_answer) = zcl_ave_ai_api=>ask(
            i_prompt = lv_summary_prompt
            i_dest   = mv_desination
            i_model  = mv_model
            i_apikey = CONV string( mv_apikey ) ).
          IF lv_summary_answer IS NOT INITIAL AND lv_summary_answer NP 'Error:*'.
            DATA lv_sum_tld TYPE i.
            FIND FIRST OCCURRENCE OF '~' IN lv_cur_obj_key MATCH OFFSET lv_sum_tld.
            IF sy-subrc = 0.
              DATA(lv_sum_name_start) = lv_sum_tld + 1.
              save_ai_summary(
                iv_objtype = CONV #( lv_cur_obj_key(lv_sum_tld) )
                iv_objname = CONV #( lv_cur_obj_key+lv_sum_name_start )
                iv_text    = lv_summary_answer ).
              save_review_to_db( iv_silent = abap_true ).
              refresh_ai_html_progress(
                iv_objtype = CONV #( lv_cur_obj_key(lv_sum_tld) )
                iv_objname = CONV #( lv_cur_obj_key+lv_sum_name_start )
                iv_summary = abap_true ).
              lv_any_summary = abap_true.
            ENDIF.
          ENDIF.
        ENDIF.
        CLEAR lv_comments.
      ENDIF.

      lv_cur_obj_key = lv_obj_key.

      DATA(lv_ai_comment) = get_ai_hunk_comment( iv_hunk_key = ls_hunk-hunk_key ).
      IF lv_ai_comment IS INITIAL.
        DATA(lv_hunk_prompt) = build_ai_hunk_prompt( iv_hunk_key = ls_hunk-hunk_key ).
        IF lv_hunk_prompt IS NOT INITIAL.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING
              percentage = 50
              text       = |Asking AI for block { ls_hunk-hunk_no }...|.

          lv_ai_comment = zcl_ave_ai_api=>ask(
            i_prompt = lv_hunk_prompt
            i_dest   = mv_desination
            i_model  = mv_model
            i_apikey = CONV string( mv_apikey ) ).

          IF lv_ai_comment IS NOT INITIAL AND lv_ai_comment NP 'Error:*'.
            UNASSIGN <ls_thread>.
            READ TABLE mt_hunk_threads ASSIGNING <ls_thread>
              WITH TABLE KEY hunk_key = ls_hunk-hunk_key.
            IF sy-subrc <> 0.
              INSERT VALUE ty_hunk_thread(
                hunk_key        = ls_hunk-hunk_key
                objtype         = ls_hunk-objtype
                obj_name        = ls_hunk-obj_name
                class_name      = ls_hunk-class_name
                display_name    = ls_hunk-display_name
                hunk_no         = ls_hunk-hunk_no
                start_line      = ls_hunk-start_line
                change_count    = ls_hunk-change_count
                change_kind     = ls_hunk-change_kind
                versno_new      = ls_hunk-versno_new
                versno_old      = ls_hunk-versno_old
                versno_new_text = ls_hunk-versno_new_text
                versno_old_text = ls_hunk-versno_old_text
                html            = ls_hunk-html ) INTO TABLE mt_hunk_threads.
              READ TABLE mt_hunk_threads ASSIGNING <ls_thread>
                WITH TABLE KEY hunk_key = ls_hunk-hunk_key.
            ENDIF.
            IF <ls_thread> IS ASSIGNED.
              DATA lv_msg_ts TYPE timestampl.
              GET TIME STAMP FIELD lv_msg_ts.
              APPEND VALUE ty_decline_msg(
                author      = 'AI_Assistant'
                author_name = 'AI_Assistant'
                created_at  = lv_msg_ts
                is_decline  = abap_false
                text        = lv_ai_comment ) TO <ls_thread>-messages.
              save_review_to_db( iv_silent = abap_true ).
              refresh_ai_html_progress(
                iv_hunk_key = ls_hunk-hunk_key
                iv_objtype  = ls_hunk-objtype
                iv_objname  = ls_hunk-obj_name ).
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      IF lv_ai_comment IS NOT INITIAL AND lv_ai_comment NP 'Error:*'.
        DATA(lv_disp) = COND string(
          WHEN ls_hunk-class_name IS NOT INITIAL AND ls_hunk-display_name IS NOT INITIAL
          THEN |{ ls_hunk-class_name }=>{ ls_hunk-display_name }|
          WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
          ELSE CONV string( ls_hunk-obj_name ) ).
        lv_comments = lv_comments &&
          |{ ls_hunk-objtype } { lv_disp } block { ls_hunk-hunk_no }:| && lv_nl &&
          lv_ai_comment && lv_nl && lv_nl.
      ENDIF.
    ENDLOOP.

    IF lv_cur_obj_key IS NOT INITIAL AND lv_comments IS NOT INITIAL.
      DATA(lv_summary_prompt_last) = `Please make summary fo changes below:` && lv_nl && lv_comments.
      DATA(lv_summary_answer_last) = zcl_ave_ai_api=>ask(
        i_prompt = lv_summary_prompt_last
        i_dest   = mv_desination
        i_model  = mv_model
        i_apikey = CONV string( mv_apikey ) ).
      IF lv_summary_answer_last IS NOT INITIAL AND lv_summary_answer_last NP 'Error:*'.
        DATA lv_sum_tld_last TYPE i.
        FIND FIRST OCCURRENCE OF '~' IN lv_cur_obj_key MATCH OFFSET lv_sum_tld_last.
        IF sy-subrc = 0.
          DATA(lv_sum_name_start_last) = lv_sum_tld_last + 1.
          save_ai_summary(
            iv_objtype = CONV #( lv_cur_obj_key(lv_sum_tld_last) )
            iv_objname = CONV #( lv_cur_obj_key+lv_sum_name_start_last )
            iv_text    = lv_summary_answer_last ).
          save_review_to_db( iv_silent = abap_true ).
          refresh_ai_html_progress(
            iv_objtype = CONV #( lv_cur_obj_key(lv_sum_tld_last) )
            iv_objname = CONV #( lv_cur_obj_key+lv_sum_name_start_last )
            iv_summary = abap_true ).
          lv_any_summary = abap_true.
        ENDIF.
      ELSEIF lv_summary_answer_last CP 'Error:*'.
        MESSAGE lv_summary_answer_last TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
    ENDIF.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING
        percentage = 0
        text       = ''.

    IF lv_any_summary = abap_false.
      MESSAGE 'AI summary was not created' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    save_review_to_db( iv_silent = abap_true ).

    IF mv_decline_view_user IS NOT INITIAL.
      show_user_declines( iv_user = mv_decline_view_user iv_reviewer = mv_reviewer_view ).
    ELSEIF mv_cur_objtype IS NOT INITIAL AND mv_cur_objname IS NOT INITIAL.
      open_cr_part( iv_objtype = mv_cur_objtype iv_objname = mv_cur_objname ).
    ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
      set_html( inject_approve_btn( iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ) ).
    ENDIF.

    refresh_rpt_row( ).
    regen_acr_report( ).
    MESSAGE 'AI summary created' TYPE 'S'.
  ENDMETHOD.


  METHOD do_askai.
    DATA(lv_prompt) = build_ai_hunk_prompt( iv_hunk_key = iv_hunk_key ).
    IF lv_prompt IS INITIAL.
      MESSAGE 'Cannot build AI prompt for this block' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF mv_desination IS INITIAL OR mv_model IS INITIAL OR mv_apikey IS INITIAL.
      show_ai_hunk_prompt_popup(
        iv_prompt   = lv_prompt
        iv_hunk_key = iv_hunk_key ).
      RETURN.
    ENDIF.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING
        percentage = 50
        text       = 'Asking AI...'.

    DATA(lv_answer) = zcl_ave_ai_api=>ask(
      i_prompt = lv_prompt
      i_dest   = mv_desination
      i_model  = mv_model
      i_apikey = CONV string( mv_apikey ) ).

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING
        percentage = 0
        text       = ''.

    IF lv_answer IS INITIAL.
      MESSAGE 'AI returned empty response' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ELSEIF lv_answer CP 'Error:*'.
      MESSAGE lv_answer TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    READ TABLE mt_hunk_threads ASSIGNING FIELD-SYMBOL(<ls_thread>)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    IF sy-subrc <> 0.
      READ TABLE mt_hunk_info INTO DATA(ls_hunk_info)
        WITH TABLE KEY hunk_key = iv_hunk_key.
      IF sy-subrc <> 0.
        MESSAGE 'Changed block was not found' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
      INSERT VALUE ty_hunk_thread(
        hunk_key        = ls_hunk_info-hunk_key
        objtype         = ls_hunk_info-objtype
        obj_name        = ls_hunk_info-obj_name
        class_name      = ls_hunk_info-class_name
        display_name    = ls_hunk_info-display_name
        hunk_no         = ls_hunk_info-hunk_no
        start_line      = ls_hunk_info-start_line
        change_count    = ls_hunk_info-change_count
        change_kind     = ls_hunk_info-change_kind
        versno_new      = ls_hunk_info-versno_new
        versno_old      = ls_hunk_info-versno_old
        versno_new_text = ls_hunk_info-versno_new_text
        versno_old_text = ls_hunk_info-versno_old_text
        html            = ls_hunk_info-html ) INTO TABLE mt_hunk_threads.
      READ TABLE mt_hunk_threads ASSIGNING <ls_thread>
        WITH TABLE KEY hunk_key = iv_hunk_key.
    ENDIF.

    IF <ls_thread> IS ASSIGNED.
      DATA lv_msg_ts TYPE timestampl.
      GET TIME STAMP FIELD lv_msg_ts.
      APPEND VALUE ty_decline_msg(
        author      = 'AI_Assistant'
        author_name = 'AI_Assistant'
        created_at  = lv_msg_ts
        is_decline  = abap_false
        text        = lv_answer ) TO <ls_thread>-messages.
    ENDIF.

    save_review_to_db( iv_silent = abap_true ).

    READ TABLE mt_hunk_info INTO DATA(ls_ai_hunk)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    IF sy-subrc = 0.
      refresh_ai_html_progress(
        iv_hunk_key = iv_hunk_key
        iv_objtype  = ls_ai_hunk-objtype
        iv_objname  = ls_ai_hunk-obj_name ).
    ENDIF.

    refresh_rpt_row( ).
    regen_acr_report( ).
  ENDMETHOD.


  METHOD show_ai_hunk_prompt_popup.
    IF mo_help_box IS BOUND.
      mo_help_box->free( ).
      CLEAR: mo_help_box, mo_help_html.
    ENDIF.

    CREATE OBJECT mo_help_box
      EXPORTING
        width                       = 820
        height                      = 560
        top                         = 70
        left                        = 120
        caption                     = 'ASK AI prompt'
        lifetime                    = cl_gui_control=>lifetime_dynpro
      EXCEPTIONS
        OTHERS                      = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SET HANDLER me->on_help_box_close FOR mo_help_box.

    CREATE OBJECT mo_help_html
      EXPORTING
        parent = mo_help_box
      EXCEPTIONS
        OTHERS = 1.
    IF sy-subrc <> 0.
      mo_help_box->free( ).
      CLEAR: mo_help_box, mo_help_html.
      RETURN.
    ENDIF.

    DATA(lv_prompt_html) = escape( val = iv_prompt format = cl_abap_format=>e_html_text ).
    DATA(lv_hunk_html) = escape( val = iv_hunk_key format = cl_abap_format=>e_html_text ).
    DATA(lv_popup_html) =
      `<!DOCTYPE html><html><head><meta charset="utf-8"><style>` &&
      `body{font:13px/1.45 Segoe UI,Arial,sans-serif;background:#f7f7f9;color:#222;margin:0;padding:16px}` &&
      `h2{font-size:16px;margin:0 0 6px;color:#2c3e50}` &&
      `.hint{margin:0 0 12px;color:#666}` &&
      `textarea{box-sizing:border-box;width:100%;height:420px;font:12px/1.35 Consolas,monospace;` &&
      `white-space:pre;resize:none;border:1px solid #bbb;background:#fff;color:#111;padding:10px}` &&
      `button{margin-top:10px;background:#8e44ad;color:#fff;border:0;border-radius:3px;` &&
      `font:bold 12px Segoe UI,Arial,sans-serif;padding:6px 14px;cursor:pointer}` &&
      `</style><script>` &&
      `function copyPrompt(){var t=document.getElementById('prompt');t.focus();t.select();` &&
      `if(window.clipboardData){window.clipboardData.setData('Text',t.value);}else{document.execCommand('copy');}}` &&
      `</script></head><body>` &&
      |<h2>ASK AI prompt</h2><p class="hint">AI settings are empty. Copy this prompt to an external chat and edit it as needed. Hunk: { lv_hunk_html }</p>| &&
      |<textarea id="prompt">{ lv_prompt_html }</textarea>| &&
      `<br><button onclick="copyPrompt()">Copy prompt</button>` &&
      `</body></html>`.

    DATA: lt_html   TYPE w3htmltab,
          lv_url    TYPE w3url,
          lv_offset TYPE i,
          lv_len    TYPE i,
          lv_chunk  TYPE i.

    lv_len = strlen( lv_popup_html ).
    WHILE lv_offset < lv_len.
      lv_chunk = COND #( WHEN lv_len - lv_offset > 255 THEN 255 ELSE lv_len - lv_offset ).
      APPEND VALUE #( line = lv_popup_html+lv_offset(lv_chunk) ) TO lt_html.
      lv_offset += lv_chunk.
    ENDWHILE.

    mo_help_html->load_data(
      IMPORTING assigned_url = lv_url
      CHANGING  data_table   = lt_html
      EXCEPTIONS OTHERS      = 1 ).
    IF sy-subrc = 0.
      mo_help_html->show_url( url = lv_url ).
      cl_gui_control=>set_focus( control = mo_help_html ).
      cl_gui_cfw=>flush( ).
    ENDIF.
  ENDMETHOD.


  METHOD show_ai_prompt.
    " Determine filter context — same logic as show_class_objects / show_user_declines
    DATA lv_ai_filter_class    TYPE seoclsname.
    DATA lv_ai_filter_obj_key  TYPE string.
    DATA lv_ai_filter_user     TYPE versuser.
    DATA lv_ai_filter_reviewer TYPE abap_bool.

    DATA(lv_is_class_key) = abap_false.
    IF strlen( mv_cr_cur_key ) >= 6.
      IF mv_cr_cur_key(6) = 'class_'.
        lv_is_class_key = abap_true.
      ENDIF.
    ENDIF.

    IF mv_cr_cur_key IS NOT INITIAL AND lv_is_class_key = abap_true.
      DATA(lv_class_start) = 6.
      lv_ai_filter_class = mv_cr_cur_key+lv_class_start.
    ELSEIF mv_cr_cur_key IS NOT INITIAL.
      " Single object view: mv_cr_cur_key = 'TYPE~OBJNAME'
      lv_ai_filter_obj_key = mv_cr_cur_key.
    ELSEIF mv_decline_view_user IS NOT INITIAL OR mv_reviewer_view = abap_true.
      lv_ai_filter_user     = mv_decline_view_user.
      lv_ai_filter_reviewer = mv_reviewer_view.
    ENDIF.

    " Collect hunks visible in the current view (sorted for stable output)
    DATA lt_hunks TYPE STANDARD TABLE OF ty_hunk_info WITH DEFAULT KEY.

    IF lv_ai_filter_class IS NOT INITIAL.
      LOOP AT mt_hunk_info INTO DATA(ls_h) WHERE class_name = lv_ai_filter_class.
        APPEND ls_h TO lt_hunks.
      ENDLOOP.

    ELSEIF lv_ai_filter_obj_key IS NOT INITIAL.
      " Filter to hunks of the single object currently open
      LOOP AT mt_hunk_info INTO DATA(ls_ho)
        WHERE objtype = mv_cur_objtype AND obj_name = mv_cur_objname.
        APPEND ls_ho TO lt_hunks.
      ENDLOOP.

    ELSEIF lv_ai_filter_reviewer = abap_true.
      DATA lt_rev_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
      DATA ls_rev_payload TYPE ty_saved_payload.
      IF load_review_payload(
           EXPORTING iv_trkorr = CONV #( mv_object_name )
           IMPORTING es_payload = ls_rev_payload ) = abap_true.
        READ TABLE ls_rev_payload-user_states INTO DATA(ls_rev_state)
          WITH KEY reviewer = lv_ai_filter_user.
        IF sy-subrc = 0.
          LOOP AT ls_rev_state-approved INTO DATA(ls_ra). INSERT ls_ra-hunk_key INTO TABLE lt_rev_keys. ENDLOOP.
          LOOP AT ls_rev_state-declined INTO DATA(ls_rd). INSERT ls_rd-hunk_key INTO TABLE lt_rev_keys. ENDLOOP.
        ENDIF.
      ENDIF.
      IF lv_ai_filter_user = sy-uname.
        LOOP AT mt_approved INTO DATA(lv_a). INSERT lv_a INTO TABLE lt_rev_keys. ENDLOOP.
        LOOP AT mt_declined INTO DATA(lv_d). INSERT lv_d INTO TABLE lt_rev_keys. ENDLOOP.
      ENDIF.
      LOOP AT mt_hunk_threads INTO DATA(ls_thr).
        LOOP AT ls_thr-messages TRANSPORTING NO FIELDS WHERE author = lv_ai_filter_user.
          INSERT ls_thr-hunk_key INTO TABLE lt_rev_keys. EXIT.
        ENDLOOP.
      ENDLOOP.
      LOOP AT lt_rev_keys INTO DATA(lv_rk).
        READ TABLE mt_hunk_info INTO DATA(ls_rh) WITH TABLE KEY hunk_key = lv_rk.
        IF sy-subrc = 0. APPEND ls_rh TO lt_hunks. ENDIF.
      ENDLOOP.

    ELSEIF lv_ai_filter_user IS NOT INITIAL.
      LOOP AT mt_hunk_info INTO DATA(ls_h2) WHERE author = lv_ai_filter_user.
        APPEND ls_h2 TO lt_hunks.
      ENDLOOP.

    ELSE.
      lt_hunks = VALUE #( FOR ls IN mt_hunk_info ( ls ) ).
    ENDIF.

    SORT lt_hunks BY class_name objtype obj_name hunk_no.

    " Build page
    DATA(lv_nl)  = cl_abap_char_utilities=>newline.
    DATA(lv_css) =
      `body{font:13px/1.45 Consolas,monospace;padding:20px 28px;background:#fff;color:#222}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin:0 0 16px}` &&
      `pre{margin:0 0 0 0;padding:10px 12px;background:#fafafa;border:1px solid #ddd;` &&
      `white-space:pre-wrap;border-top:none}` &&
      `.hdr{background:#dbe9ff;color:#2c3e50;font-weight:bold;padding:5px 12px;` &&
      `margin:20px 0 0 0;border:1px solid #b0c8f0}` &&
      `.back{position:fixed;top:8px;left:8px;z-index:999;background:#3498db;color:#fff;` &&
      `padding:4px 10px;border-radius:4px;text-decoration:none;` &&
      `font:bold 12px Consolas,monospace;box-shadow:0 1px 4px rgba(0,0,0,.25)}`.

    DATA(lv_mode) = COND string( WHEN mv_compact = abap_true THEN `Compact` ELSE `Full` ).
    DATA(lv_html) =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ lv_css }</style></head><body>| &&
      |<a class="back" href="sapevent:back~0">&#8592; Back</a>| &&
      |<h2>AI prompt &#8212; { escape( val = CONV string( mv_object_name ) format = cl_abap_format=>e_html_text ) }| &&
      | / { lv_mode }</h2>| &&
      |<pre>Check please all changes in the code and provide a brief change description</pre>|.

    IF lt_hunks IS INITIAL.
      lv_html = lv_html && `<p style="color:#888">No changed blocks found.</p></body></html>`.
      maximize_html( ). set_html( lv_html ). RETURN.
    ENDIF.

    " Process hunks grouped by object to avoid calling compute_diff multiple times
    DATA lv_cur_obj_key TYPE string.
    DATA lt_obj_diff    TYPE ty_t_diff.

    LOOP AT lt_hunks INTO DATA(ls_hunk).

      DATA(lv_obj_key) = |{ ls_hunk-objtype }~{ ls_hunk-obj_name }|.

      " Recompute diff only when object changes
      IF lv_obj_key <> lv_cur_obj_key.
        lv_cur_obj_key = lv_obj_key.
        CLEAR lt_obj_diff.

        DATA lt_src_old TYPE abaptxt255_tab.
        DATA lt_src_new TYPE abaptxt255_tab.
        CLEAR: lt_src_old, lt_src_new.

        IF ls_hunk-versno_old IS NOT INITIAL.
          lt_src_old = zcl_ave_popup_data=>get_ver_source(
            i_objtype = ls_hunk-objtype
            i_objname = ls_hunk-obj_name
            i_versno  = ls_hunk-versno_old ).
        ENDIF.
        lt_src_new = zcl_ave_popup_data=>get_ver_source(
          i_objtype = ls_hunk-objtype
          i_objname = ls_hunk-obj_name
          i_versno  = ls_hunk-versno_new ).

        " For new objects (no old version) reconstruct diff as pure '+' stream,
        " matching the same logic used in cr_precompute_part.
        IF ls_hunk-versno_old IS INITIAL.
          LOOP AT lt_src_new INTO DATA(ls_new_line).
            APPEND VALUE ty_diff_op( op = '+' text = CONV string( ls_new_line ) ) TO lt_obj_diff.
          ENDLOOP.
        ELSE.
          lt_obj_diff = zcl_ave_popup_diff=>compute_diff(
            it_old        = lt_src_old
            it_new        = lt_src_new
            i_title       = CONV #( ls_hunk-obj_name )
            i_confirm_key = |AIPROMPT~{ lv_obj_key }|
            i_ignore_case = mv_ignore_case ).
        ENDIF.
      ENDIF.

      " Walk diff stream and find hunk #ls_hunk-hunk_no
      " IMPORTANT: all accumulators must be cleared at the top of each hunk iteration
      DATA lv_hunk_cnt  TYPE i.
      DATA lv_in_block  TYPE abap_bool.
      DATA lt_del       TYPE string_table.
      DATA lt_ins       TYPE string_table.
      DATA lv_hunk_code TYPE string.
      CLEAR: lv_hunk_cnt, lv_in_block, lt_del, lt_ins, lv_hunk_code.

      LOOP AT lt_obj_diff INTO DATA(ls_op).
        CASE ls_op-op.
          WHEN '+' OR '-'.
            IF lv_in_block = abap_false.
              lv_in_block = abap_true.
              CLEAR: lt_del, lt_ins.
            ENDIF.
            IF ls_op-op = '+'.
              APPEND ls_op-text TO lt_ins.
            ELSE.
              APPEND ls_op-text TO lt_del.
            ENDIF.

          WHEN OTHERS.
            IF lv_in_block = abap_true.
              IF lt_del IS NOT INITIAL OR lt_ins IS NOT INITIAL.
                lv_hunk_cnt += 1.

                IF lv_hunk_cnt = ls_hunk-hunk_no.
                  " change_kind values from cr_precompute_part: 'changed', 'added', 'deleted'
                  DATA(lv_kind) = COND string(
                    WHEN lt_del IS NOT INITIAL AND lt_ins IS NOT INITIAL THEN `changed`
                    WHEN lt_ins IS NOT INITIAL                            THEN `added`
                    ELSE                                                       `deleted` ).
                  lv_hunk_code = |>>> start of { lv_kind } block for LLM| && lv_nl.
                  " op='+' in compute_diff = inserted line, op='-' = deleted line

                  LOOP AT lt_ins INTO DATA(lv_il).
                    lv_hunk_code = lv_hunk_code &&
                      `+ ` && |{ escape( val = lv_il format = cl_abap_format=>e_html_text ) }| && lv_nl.
                  ENDLOOP.
                  LOOP AT lt_del INTO DATA(lv_dl).
                    lv_hunk_code = lv_hunk_code &&
                      `- ` && |{ escape( val = lv_dl format = cl_abap_format=>e_html_text ) }| && lv_nl.
                  ENDLOOP.
                  lv_hunk_code = lv_hunk_code && |&lt;&lt;&lt; end of { lv_kind } block for LLM| && lv_nl.
                ENDIF.
              ENDIF.
              lv_in_block = abap_false.
              CLEAR: lt_del, lt_ins.

              IF lv_hunk_cnt >= ls_hunk-hunk_no.
                EXIT.
              ENDIF.
            ENDIF.
        ENDCASE.
      ENDLOOP.

      " Handle diff ending without trailing context line
      IF lv_in_block = abap_true AND lv_hunk_code IS INITIAL.
        IF lt_del IS NOT INITIAL OR lt_ins IS NOT INITIAL.
          lv_hunk_cnt += 1.
          IF lv_hunk_cnt = ls_hunk-hunk_no.
            DATA(lv_kind2) = COND string(
              WHEN lt_del IS NOT INITIAL AND lt_ins IS NOT INITIAL THEN `changed`
              WHEN lt_ins IS NOT INITIAL                            THEN `added`
              ELSE                                                       `deleted` ).
            lv_hunk_code = |>>> start of { lv_kind2 } block for LLM| && lv_nl.
            LOOP AT lt_ins INTO DATA(lv_il2).
              lv_hunk_code = lv_hunk_code &&
                `+ ` && |{ escape( val = lv_il2 format = cl_abap_format=>e_html_text ) }| && lv_nl.
            ENDLOOP.
            LOOP AT lt_del INTO DATA(lv_dl2).
              lv_hunk_code = lv_hunk_code &&
                `- ` && |{ escape( val = lv_dl2 format = cl_abap_format=>e_html_text ) }| && lv_nl.
            ENDLOOP.
            lv_hunk_code = lv_hunk_code && |&lt;&lt;&lt; end of { lv_kind2 } block for LLM| && lv_nl.
          ENDIF.
        ENDIF.
      ENDIF.

      " Build display name for header
      DATA(lv_disp) = COND string(
        WHEN ls_hunk-class_name IS NOT INITIAL AND ls_hunk-display_name IS NOT INITIAL
        THEN |{ ls_hunk-class_name }=>{ ls_hunk-display_name }|
        WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
        ELSE CONV string( ls_hunk-obj_name ) ).

      lv_html = lv_html &&
        |<div class="hdr">| &&
        |{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
        |{ escape( val = lv_disp format = cl_abap_format=>e_html_text ) }| &&
        | &nbsp;&#9656;&nbsp; Hunk #{ ls_hunk-hunk_no }| &&
        | &nbsp;<span style="color:#7f8c99;font-weight:normal">| &&
        |{ ls_hunk-change_kind } &bull; line { ls_hunk-start_line } &bull; { ls_hunk-change_count } change(s)| &&
        `</span></div>` &&
        |<pre>{ lv_hunk_code }</pre>|.
    ENDLOOP.

    lv_html = lv_html && `</body></html>`.
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD show_user_declines.
    mv_decline_view_user = iv_user.
    mv_reviewer_view = iv_reviewer.
    DATA(lv_user_name) = COND ad_namtext(
      WHEN iv_user IS INITIAL THEN 'All developers'
      ELSE zcl_ave_popup_data=>get_user_name( iv_user ) ).

    TYPES: BEGIN OF ty_summary_obj,
             objtype  TYPE versobjtyp,
             obj_name TYPE versobjnam,
           END OF ty_summary_obj.
    DATA lt_summary_objs TYPE SORTED TABLE OF ty_summary_obj WITH UNIQUE KEY objtype obj_name.
    DATA lt_hunks TYPE STANDARD TABLE OF ty_hunk_info WITH DEFAULT KEY.
    IF iv_reviewer = abap_true.
      DATA lt_review_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
      DATA ls_review_payload TYPE ty_saved_payload.
      IF load_review_payload(
           EXPORTING iv_trkorr = CONV #( mv_object_name )
           IMPORTING es_payload = ls_review_payload ) = abap_true.
        READ TABLE ls_review_payload-user_states INTO DATA(ls_review_state)
          WITH KEY reviewer = iv_user.
        IF sy-subrc = 0.
          LOOP AT ls_review_state-approved INTO DATA(ls_review_approved).
            INSERT ls_review_approved-hunk_key INTO TABLE lt_review_keys.
          ENDLOOP.
          LOOP AT ls_review_state-declined INTO DATA(ls_review_declined).
            INSERT ls_review_declined-hunk_key INTO TABLE lt_review_keys.
          ENDLOOP.
        ENDIF.
      ENDIF.

      IF iv_user = sy-uname.
        LOOP AT mt_approved INTO DATA(lv_cur_approved_key).
          INSERT lv_cur_approved_key INTO TABLE lt_review_keys.
        ENDLOOP.
        LOOP AT mt_declined INTO DATA(lv_cur_declined_key).
          INSERT lv_cur_declined_key INTO TABLE lt_review_keys.
        ENDLOOP.
      ENDIF.

      LOOP AT mt_hunk_threads INTO DATA(ls_review_thread).
        LOOP AT ls_review_thread-messages TRANSPORTING NO FIELDS WHERE author = iv_user.
          IF ls_review_thread-hunk_key CP 'AI_SUMMARY~*'
             OR ls_review_thread-change_kind = 'AI_SUMMARY'.
            INSERT VALUE #(
              objtype  = ls_review_thread-objtype
              obj_name = ls_review_thread-obj_name ) INTO TABLE lt_summary_objs.
          ELSE.
            INSERT ls_review_thread-hunk_key INTO TABLE lt_review_keys.
          ENDIF.
          EXIT.
        ENDLOOP.
      ENDLOOP.

      LOOP AT lt_review_keys INTO DATA(lv_review_key).
        READ TABLE mt_hunk_info INTO DATA(ls_review_hunk)
          WITH TABLE KEY hunk_key = lv_review_key.
        IF sy-subrc = 0.
          APPEND ls_review_hunk TO lt_hunks.
        ENDIF.
      ENDLOOP.
    ELSE.
      IF iv_user IS INITIAL.
        LOOP AT mt_hunk_info INTO DATA(ls_hi_all).
          APPEND ls_hi_all TO lt_hunks.
        ENDLOOP.
        LOOP AT mt_hunk_threads INTO DATA(ls_sum_all).
          CHECK ls_sum_all-hunk_key CP 'AI_SUMMARY~*'
             OR ls_sum_all-change_kind = 'AI_SUMMARY'.
          INSERT VALUE #(
            objtype  = ls_sum_all-objtype
            obj_name = ls_sum_all-obj_name ) INTO TABLE lt_summary_objs.
        ENDLOOP.
      ELSE.
        LOOP AT mt_hunk_info INTO DATA(ls_hi) WHERE author = iv_user.
          APPEND ls_hi TO lt_hunks.
        ENDLOOP.
        IF iv_user = 'AI_SUMMARY'.
          LOOP AT mt_hunk_threads INTO DATA(ls_sum_user).
            CHECK ls_sum_user-hunk_key CP 'AI_SUMMARY~*'
               OR ls_sum_user-change_kind = 'AI_SUMMARY'.
            INSERT VALUE #(
              objtype  = ls_sum_user-objtype
              obj_name = ls_sum_user-obj_name ) INTO TABLE lt_summary_objs.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDIF.
    SORT lt_hunks BY class_name objtype obj_name hunk_no.

    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `.toolbar{display:block;white-space:nowrap;margin-bottom:14px}` &&
      `.objhdr{margin:18px 0 8px 0;background:#dbe9ff;color:#2c3e50;padding:5px 10px;` &&
      `font-weight:bold;white-space:nowrap}` &&
      `.block{margin:0 0 14px 0}` &&
      `.comments{display:block;width:100%;margin:0 0 8px 0}` &&
      `.codewrap{display:block;clear:both;width:100%;margin:0;padding:0}` &&
      `.blame{margin:0 0 6px 0;color:#5e6a75;font-style:italic;white-space:nowrap}` &&
      `.blkinfo{margin:5px 0 2px 0;color:#2c3e50;font-weight:bold;white-space:nowrap}` &&
      `.muted{color:#777;font-weight:normal}` &&
      `.meta{display:block;margin:0 0 4px 0;color:#7f8c99;font-size:10px;font-weight:normal}` &&
      `.note{display:table;margin:6px 0 6px 0;padding:5px 9px;background:#f3f9ff;` &&
      `border:1px solid #a8cde8;color:#155f8f;font-style:italic;font-weight:bold;border-radius:6px}` &&
      `table.diff{border-collapse:collapse;width:100%;font-size:12px;margin:0 0 4px 0}` &&
      `.diff .ln{color:#aaa;text-align:right;padding:1px 10px 1px 5px;` &&
      `min-width:42px;border-right:1px solid #e0e0e0;white-space:nowrap;background:#fafafa}` &&
      `.diff .cd{padding:1px 8px;white-space:pre}` &&
      `.back{position:fixed;top:8px;left:8px;z-index:999;` &&
      `background:#3498db;color:#fff;padding:4px 10px;border-radius:4px;` &&
      `text-decoration:none;font:bold 12px Consolas,monospace;white-space:nowrap;` &&
      `box-shadow:0 1px 4px rgba(0,0,0,.25)}` &&
      `.filter-btn{display:inline-block;background:#eee;color:#333;padding:4px 10px;border-radius:4px;cursor:pointer;` &&
      `font:bold 12px Consolas,monospace;border:1px solid #bbb;text-decoration:none;` &&
      `white-space:nowrap;margin-right:4px}` &&
      `.filter-btn.active{background:#e74c3c;color:#fff;border-color:#c0392b}` &&
      `.filter-btn.active.comments{background:#27ae60;border-color:#1e8449}`.

    DATA(lv_ai_prompt_label) = COND string(
      WHEN is_ai_enabled( ) = abap_true THEN `AI Summary`
      ELSE `AI prompt` ).

    DATA(lv_html) =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ lv_css }</style>| &&
      `<script>` &&
      `(function(){` &&
        `var k='ave_scroll_declines';` &&
        `var pos=sessionStorage.getItem(k);` &&
        `if(pos){` &&
          `window.addEventListener('load',function(){window.scrollTo(0,parseInt(pos,10));sessionStorage.removeItem(k);});` &&
        `}` &&
        `window._saveScroll=function(){sessionStorage.setItem(k,window.scrollY||document.documentElement.scrollTop||0);};` &&
      `})();` &&
      `function filterBlocks(mode){` &&
        `var btns=document.querySelectorAll('.filter-btn');` &&
        `btns.forEach(function(b){b.classList.remove('active');});` &&
        `var grps=document.querySelectorAll('.objgrp');` &&
        `grps.forEach(function(g){` &&
          `g.style.display='';` &&
          `g.querySelectorAll('.block').forEach(function(b){b.style.display='';});` &&
        `});` &&
        `if(!mode){return;}` &&
        `var btn=document.getElementById('btn_'+mode);` &&
        `if(btn){btn.classList.add('active');if(mode==='comments')btn.classList.add('comments');}` &&
        `grps.forEach(function(g){` &&
          `var anyVisible=false;` &&
          `g.querySelectorAll('.block').forEach(function(b){` &&
            `var show=false;` &&
            `if(mode==='declined'){` &&
              `var notes=b.querySelectorAll('.note');` &&
              `for(var i=0;i<notes.length;i++){if(notes[i].getAttribute('style')){show=true;break;}}` &&
            `}else if(mode==='comments'){` &&
              `show=b.querySelector('.comments')!==null;` &&
            `}` &&
            `b.style.display=show?'':'none';` &&
            `if(show)anyVisible=true;` &&
          `});` &&
          `g.style.display=anyVisible?'':'none';` &&
        `});` &&
      `}` &&
      `document.addEventListener('click',function(e){` &&
        `var a=e.target.closest('a[href^="sapevent:addcomment"],a[href^="sapevent:editreview"]');` &&
        `if(a&&window._saveScroll){window._saveScroll();}` &&
      `});` &&
      `</script>` &&
      `</head><body>` &&
      |<a class="back" href="sapevent:back~0">&#8592; Back</a>| &&
      `<p style="margin:0 0 14px 0">` &&
      `<a id="btn_declined" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'declined');return false">Declined only</a>` &&
      `<a id="btn_comments" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'comments');return false">Comments only</a>` &&
      |<a class="filter-btn" href="sapevent:aiprompt~0">{ lv_ai_prompt_label }</a>| &&
      `</p>` &&
      COND string(
        WHEN iv_user IS INITIAL AND iv_reviewer = abap_false
        THEN |<h2>Review: { escape( val = CONV string( lv_user_name ) format = cl_abap_format=>e_html_text ) }</h2>|
        ELSE |<h2>Review: { escape( val = CONV string( iv_user ) format = cl_abap_format=>e_html_text ) }| &&
             | / { escape( val = CONV string( lv_user_name ) format = cl_abap_format=>e_html_text ) }</h2>| ).

    IF lt_hunks IS INITIAL AND lt_summary_objs IS INITIAL.
      lv_html = lv_html &&
        COND string(
          WHEN iv_reviewer = abap_true
          THEN |<p style="color:#888">No reviewed or commented blocks found for this reviewer.</p>|
          WHEN iv_user IS INITIAL
          THEN |<p style="color:#888">No changed blocks found.</p>|
          ELSE |<p style="color:#888">No changed blocks found for this developer.</p>| ) &&
        |</body></html>|.
      maximize_html( ).
      set_html( lv_html ).
      RETURN.
    ENDIF.

    DATA lv_cur_obj TYPE string VALUE `####`.
    LOOP AT lt_hunks INTO DATA(ls_hunk).
      DATA(lv_obj_key) = |{ ls_hunk-objtype }~{ ls_hunk-obj_name }|.

      " Object header
      IF lv_obj_key <> lv_cur_obj.
        " close previous group
        IF lv_cur_obj <> `####`.
          lv_html = lv_html && render_ai_summary_html(
            iv_objtype = CONV #( lv_cur_obj(4) )
            iv_objname = CONV #( lv_cur_obj+5 ) ) && `</div>`.
        ENDIF.
        lv_cur_obj = lv_obj_key.
        DATA(lv_title) = COND string(
          WHEN ls_hunk-class_name IS NOT INITIAL AND ls_hunk-display_name IS NOT INITIAL
          THEN |{ ls_hunk-class_name }=>{ ls_hunk-display_name }|
          WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
          ELSE CONV string( ls_hunk-obj_name ) ).
        DATA lv_obj_blocks  TYPE i.
        DATA lv_obj_changes TYPE i.
        CLEAR: lv_obj_blocks, lv_obj_changes.
        LOOP AT lt_hunks INTO DATA(ls_s) WHERE objtype = ls_hunk-objtype AND obj_name = ls_hunk-obj_name.
          lv_obj_blocks  += 1.
          lv_obj_changes += ls_s-change_count.
        ENDLOOP.
        lv_html = lv_html &&
          `<div class="objgrp">` &&
          |<div class="objhdr">| &&
          |<a href="sapevent:openobj~{ lv_obj_key }" style="color:inherit;text-decoration:none">| &&
          |{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
          |{ escape( val = lv_title format = cl_abap_format=>e_html_text ) }</a>| &&
          | <span class="muted">blocks</span> { lv_obj_blocks }| &&
          | <span class="muted">changes</span> { lv_obj_changes } lines</div>|.
      ENDIF.

      " Hunk diff HTML (same cleanup as before)
      DATA(lv_clean_html) = ls_hunk-html.
      "blame row should not be deleted CLAUDE
*      DATA lv_mark_pos TYPE i.
*      DATA lv_before_mark TYPE string.
*      DATA lv_after_mark TYPE string.
*      DATA lv_tr_start TYPE i.
*      DATA lv_tr_end_rel TYPE i.
*      DATA lv_tr_end TYPE i.
*      DATA lv_rev_before TYPE string.
*      DATA lv_rev_pos TYPE i.
*      WHILE lv_clean_html CS `──</td>`.
*        lv_mark_pos = sy-fdpos.
*        lv_before_mark = lv_clean_html(lv_mark_pos).
*        lv_after_mark = lv_clean_html+lv_mark_pos.
*        lv_rev_before = reverse( lv_before_mark ).
*        FIND FIRST OCCURRENCE OF `rt<` IN lv_rev_before MATCH OFFSET lv_rev_pos.
*        IF sy-subrc <> 0. EXIT. ENDIF.
*        lv_tr_start = strlen( lv_before_mark ) - lv_rev_pos - 3.
*        FIND FIRST OCCURRENCE OF `</tr>` IN lv_after_mark MATCH OFFSET lv_tr_end_rel.
*        IF sy-subrc <> 0. EXIT. ENDIF.
*        lv_tr_end = lv_mark_pos + lv_tr_end_rel + 5.
*        IF lv_tr_start < 0 OR lv_tr_end <= lv_tr_start. EXIT. ENDIF.
*        lv_clean_html = lv_clean_html(lv_tr_start) && lv_clean_html+lv_tr_end.
*      ENDWHILE.
      IF mv_two_pane = abap_false AND lv_clean_html CS `<td class="sep"></td>`.
        DATA(lv_rows_html) = lv_clean_html.
        DATA(lv_norm_html) = ``.
        DATA lv_row_start TYPE i.
        DATA lv_row_close_rel TYPE i.
        DATA lv_row_close TYPE i.
        DATA lv_row_len TYPE i.
        DATA lv_row_html TYPE string.
        DATA lv_gt_pos TYPE i.
        DATA lv_sep_pos TYPE i.
        DATA lv_body_left TYPE string.
        DATA lv_body_right TYPE string.
        DATA lv_plain_left TYPE string.
        DATA lv_plain_right TYPE string.
        WHILE lv_rows_html CS `<tr`.
          lv_row_start = sy-fdpos.
          IF lv_row_start > 0.
            lv_norm_html = lv_norm_html && lv_rows_html(lv_row_start).
            lv_rows_html = lv_rows_html+lv_row_start.
          ENDIF.
          FIND FIRST OCCURRENCE OF `</tr>` IN lv_rows_html MATCH OFFSET lv_row_close_rel.
          IF sy-subrc <> 0.
            lv_norm_html = lv_norm_html && lv_rows_html.
            CLEAR lv_rows_html.
            EXIT.
          ENDIF.
          lv_row_close = lv_row_close_rel + 5.
          lv_row_html = lv_rows_html(lv_row_close).
          lv_rows_html = lv_rows_html+lv_row_close.
          IF lv_row_html CS `<td class="sep"></td>`.
            FIND FIRST OCCURRENCE OF `>` IN lv_row_html MATCH OFFSET lv_gt_pos.
            FIND FIRST OCCURRENCE OF `<td class="sep"></td>` IN lv_row_html MATCH OFFSET lv_sep_pos.
            IF sy-subrc = 0 AND lv_gt_pos >= 0 AND lv_sep_pos > lv_gt_pos.
              DATA(lv_body_left_off)  = lv_gt_pos + 1.
              DATA(lv_body_left_len)  = lv_sep_pos - lv_gt_pos - 1.
              DATA(lv_body_right_off) = lv_sep_pos + 21.
              DATA(lv_row_prefix_len) = lv_gt_pos + 1.
              lv_body_left  = lv_row_html+lv_body_left_off(lv_body_left_len).
              lv_body_right = lv_row_html+lv_body_right_off.
              lv_row_len = strlen( lv_body_right ).
              IF lv_row_len >= 5.
                DATA(lv_body_right_len) = lv_row_len - 5.
                lv_body_right = lv_body_right(lv_body_right_len).
              ENDIF.
              lv_plain_left  = lv_body_left.
              lv_plain_right = lv_body_right.
              REPLACE ALL OCCURRENCES OF REGEX `<[^>]+>` IN lv_plain_left  WITH ``.
              REPLACE ALL OCCURRENCES OF REGEX `<[^>]+>` IN lv_plain_right WITH ``.
              CONDENSE lv_plain_left  NO-GAPS.
              CONDENSE lv_plain_right NO-GAPS.
              lv_norm_html = lv_norm_html &&
                lv_row_html(lv_row_prefix_len) &&
                COND string(
                  WHEN strlen( lv_plain_right ) >= strlen( lv_plain_left )
                  THEN lv_body_right ELSE lv_body_left ) &&
                `</tr>`.
            ELSE.
              lv_norm_html = lv_norm_html && lv_row_html.
            ENDIF.
          ELSE.
            lv_norm_html = lv_norm_html && lv_row_html.
          ENDIF.
        ENDWHILE.
        lv_clean_html = lv_norm_html && lv_rows_html.
      ENDIF.
      DATA(lv_code_html) = COND string(
        WHEN lv_clean_html IS NOT INITIAL
        THEN |<table class="diff"><tbody>{ lv_clean_html }</tbody></table>|
        ELSE `<div style="color:#888;margin:4px 0 10px">Diff not available.</div>` ).

      " Actions (approve / decline / undo / add comment) — same set as in object report
      DATA(lv_actions_html) = zcl_ave_acr_renderer=>render_hunk_actions_html(
        iv_hunk_key     = ls_hunk-hunk_key
        it_approved     = mt_approved
        it_declined     = mt_declined
        it_hunk_actions = mt_hunk_actions
        it_hunk_info    = mt_hunk_info
        it_hunk_threads = mt_hunk_threads
        iv_ai_enabled   = COND #( WHEN mv_desination IS NOT INITIAL
                                    AND mv_model IS NOT INITIAL
                                    AND mv_apikey IS NOT INITIAL
                                  THEN abap_true ELSE abap_false ) ).
      DATA(lv_block_title) = COND string(
        WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
        ELSE CONV string( ls_hunk-obj_name ) ).
      DATA(lv_change_kind_html) = COND string(
        WHEN ls_hunk-change_kind IS NOT INITIAL
        THEN | <span class="muted">{ escape( val = ls_hunk-change_kind format = cl_abap_format=>e_html_text ) }</span>|
        ELSE `` ).
      DATA(lv_hunk_new_text) = ls_hunk-versno_new_text.
      DATA(lv_hunk_old_text) = ls_hunk-versno_old_text.
      DATA(lv_hunk_new_versno) = ls_hunk-versno_new.
      DATA(lv_hunk_old_versno) = ls_hunk-versno_old.
      IF lv_hunk_new_versno IS INITIAL.
        READ TABLE mt_acr_stats INTO DATA(ls_hunk_stat)
          WITH KEY objtype = ls_hunk-objtype obj_name = ls_hunk-obj_name.
        IF sy-subrc = 0.
          lv_hunk_new_versno = ls_hunk_stat-versno_new.
          lv_hunk_old_versno = ls_hunk_stat-versno_old.
        ENDIF.
      ENDIF.
      IF lv_hunk_new_text IS INITIAL AND lv_hunk_new_versno IS NOT INITIAL.
        lv_hunk_new_text = COND string(
          WHEN lv_hunk_new_versno = zcl_ave_version=>c_version-active THEN `Active`
          WHEN lv_hunk_new_versno = zcl_ave_version=>c_version-modified THEN `Modified`
          ELSE |v{ CONV string( lv_hunk_new_versno + 0 ) }| ).
      ELSEIF lv_hunk_new_text IS NOT INITIAL AND lv_hunk_new_text CA '0123456789' AND lv_hunk_new_text NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
        lv_hunk_new_text = |v{ lv_hunk_new_text }|.
      ENDIF.
      IF lv_hunk_old_text IS INITIAL.
        lv_hunk_old_text = COND string(
          WHEN lv_hunk_old_versno IS INITIAL THEN `(new object)`
          WHEN lv_hunk_old_versno = zcl_ave_version=>c_version-active THEN `Active`
          WHEN lv_hunk_old_versno = zcl_ave_version=>c_version-modified THEN `Modified`
          ELSE |v{ CONV string( lv_hunk_old_versno + 0 ) }| ).
      ELSEIF lv_hunk_old_text CA '0123456789' AND lv_hunk_old_text NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
        lv_hunk_old_text = |v{ lv_hunk_old_text }|.
      ENDIF.
      DATA(lv_versions_html) = COND string(
        WHEN lv_hunk_new_text IS NOT INITIAL
        THEN | <span class="muted">versions</span> { escape( val = lv_hunk_new_text format = cl_abap_format=>e_html_text ) } -&gt; { escape( val = lv_hunk_old_text format = cl_abap_format=>e_html_text ) }|
        ELSE `` ).

      lv_html = lv_html &&
        `<div class="block">` &&
        |<div class="blkinfo">{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
        |{ escape( val = lv_block_title format = cl_abap_format=>e_html_text ) } | &&
        |Block #{ ls_hunk-hunk_no }| &&
        lv_change_kind_html &&
        lv_versions_html &&
        | <span class="muted">line</span> { ls_hunk-start_line }| &&
        | <span class="muted">changes</span> { ls_hunk-change_count }</div>| &&
        lv_actions_html.

      " Comments for this hunk
      DATA(lv_comments_html) = ``.
      DATA(ls_thread) = get_hunk_thread( ls_hunk ).
      IF ls_thread-messages IS NOT INITIAL.
        LOOP AT ls_thread-messages INTO DATA(ls_msg).
          CHECK ls_msg-text IS NOT INITIAL.
          DATA(lv_note_esc) = escape( val = ls_msg-text format = cl_abap_format=>e_html_text ).
          REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_note_esc WITH `<br>`.
          DATA(lv_created_at_txt) = format_timestamp( ls_msg-created_at ).
          DATA(lv_note_style) = COND string(
            WHEN ls_msg-is_decline = abap_true
            THEN ` style="background:#fff1f4;border-color:#efb8c8;color:#9f3b57"`
            ELSE `` ).
          lv_comments_html = lv_comments_html &&
            |<span class="meta">{ escape( val = CONV string( ls_msg-author ) format = cl_abap_format=>e_html_text ) }| &&
            | / { escape( val = CONV string( ls_msg-author_name ) format = cl_abap_format=>e_html_text ) }| &&
            | / { escape( val = lv_created_at_txt format = cl_abap_format=>e_html_text ) }</span>| &&
            |<div class="note"{ lv_note_style }>{ lv_note_esc }</div>|.
        ENDLOOP.
      ENDIF.
      IF lv_comments_html IS NOT INITIAL.
        lv_html = lv_html &&
          |<div id="{ get_hunk_scroll_anchor( ls_hunk-hunk_key ) }" class="comments">{ lv_comments_html }</div>|.
      ENDIF.

      lv_html = lv_html &&
        `<div class="codewrap">` &&
        lv_code_html &&
        `</div></div>`.
    ENDLOOP.

    IF lv_cur_obj <> `####`.
      lv_html = lv_html && render_ai_summary_html(
        iv_objtype = CONV #( lv_cur_obj(4) )
        iv_objname = CONV #( lv_cur_obj+5 ) ) && `</div>`.
    ENDIF.

    LOOP AT lt_summary_objs INTO DATA(ls_summary_obj).
      READ TABLE lt_hunks TRANSPORTING NO FIELDS
        WITH KEY objtype = ls_summary_obj-objtype obj_name = ls_summary_obj-obj_name.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      DATA(lv_summary_title) = CONV string( ls_summary_obj-obj_name ).
      READ TABLE mt_hunk_info INTO DATA(ls_summary_hunk)
        WITH KEY objtype = ls_summary_obj-objtype obj_name = ls_summary_obj-obj_name.
      IF sy-subrc = 0.
        lv_summary_title = COND string(
          WHEN ls_summary_hunk-class_name IS NOT INITIAL AND ls_summary_hunk-display_name IS NOT INITIAL
          THEN |{ ls_summary_hunk-class_name }=>{ ls_summary_hunk-display_name }|
          WHEN ls_summary_hunk-display_name IS NOT INITIAL THEN ls_summary_hunk-display_name
          ELSE CONV string( ls_summary_hunk-obj_name ) ).
      ENDIF.

      DATA(lv_summary_obj_key) = |{ ls_summary_obj-objtype }~{ ls_summary_obj-obj_name }|.
      lv_html = lv_html &&
        `<div class="objgrp">` &&
        |<div class="objhdr">| &&
        |<a href="sapevent:openobj~{ lv_summary_obj_key }" style="color:inherit;text-decoration:none">| &&
        |{ escape( val = CONV string( ls_summary_obj-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
        |{ escape( val = lv_summary_title format = cl_abap_format=>e_html_text ) }</a>| &&
        | <span class="muted">AI summary</span></div>| &&
        render_ai_summary_html(
          iv_objtype = ls_summary_obj-objtype
          iv_objname = ls_summary_obj-obj_name ) &&
        `</div>`.
    ENDLOOP.

    lv_html = lv_html && `</body></html>`.
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD open_cr_part.
    " Build a self-contained HTML page for the given object — same approach as SHOW_USER_DECLINES.
    " Collect all hunks that belong to iv_objtype / iv_objname (independent of author/user).
    DATA lt_hunks TYPE STANDARD TABLE OF ty_hunk_info WITH DEFAULT KEY.
    LOOP AT mt_hunk_info INTO DATA(ls_hi)
      WHERE objtype = iv_objtype AND obj_name = iv_objname.
      APPEND ls_hi TO lt_hunks.
    ENDLOOP.
    SORT lt_hunks BY hunk_no.

    " Clear cached ALV-based HTML so that ON_NOTE_DLG_SAVED re-renders via open_cr_part
    " instead of falling through to the inject_approve_btn branch (which has no comments).
    " Keep mv_cr_cur_key set to TYPE~OBJNAME so back_to_report can scroll to this row.
    CLEAR mv_cr_base_html.
    mv_cr_cur_key = |{ iv_objtype }~{ iv_objname }|.

    " Always track the current object from iv_ params so ON_NOTE_DLG_SAVED
    " re-renders the correct object even when mt_parts lookup finds nothing.
    mv_cur_objtype = iv_objtype.
    mv_cur_objname = iv_objname.

    " Refine part name from mt_parts (class => method display)
    DATA lv_page_title TYPE string.
    LOOP AT mt_parts ASSIGNING FIELD-SYMBOL(<lp>)
      WHERE type = iv_objtype AND object_name = iv_objname.
      mv_cur_part_name = COND string(
        WHEN <lp>-class IS NOT INITIAL THEN |{ <lp>-class } => { <lp>-name }|
        ELSE <lp>-name ).
      lv_page_title = mv_cur_part_name.
      EXIT.
    ENDLOOP.

    " Derive title from hunk_info as fallback (covers re-render after comment/decline
    " when mt_parts is not reliably indexed by object_name alone).
    IF lv_page_title IS INITIAL.
      READ TABLE lt_hunks INTO DATA(ls_title_hunk) INDEX 1.
      IF sy-subrc = 0.
        IF ls_title_hunk-class_name IS NOT INITIAL AND ls_title_hunk-display_name IS NOT INITIAL.
          lv_page_title = |{ ls_title_hunk-class_name } => { ls_title_hunk-display_name }|.
        ELSEIF ls_title_hunk-display_name IS NOT INITIAL.
          lv_page_title = ls_title_hunk-display_name.
        ELSE.
          lv_page_title = CONV string( iv_objname ).
        ENDIF.
      ELSE.
        lv_page_title = CONV string( iv_objname ).
      ENDIF.
    ENDIF.

    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px 20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `.toolbar{display:block;white-space:nowrap;margin-bottom:14px}` &&
      `.objhdr{margin:18px 0 8px 0;background:#dbe9ff;color:#2c3e50;padding:5px 10px;` &&
      `font-weight:bold;white-space:nowrap}` &&
      `.block{margin:0 0 14px 0}` &&
      `.comments{display:block;width:100%;margin:0 0 8px 0}` &&
      `.codewrap{display:block;clear:both;width:100%;margin:0;padding:0}` &&
      `.blame{margin:0 0 6px 0;color:#5e6a75;font-style:italic;white-space:nowrap}` &&
      `.blkinfo{margin:5px 0 2px 0;color:#2c3e50;font-weight:bold;white-space:nowrap}` &&
      `.muted{color:#777;font-weight:normal}` &&
      `.meta{display:block;margin:0 0 4px 0;color:#7f8c99;font-size:10px;font-weight:normal}` &&
      `.note{display:table;margin:6px 0 6px 0;padding:5px 9px;background:#f3f9ff;` &&
      `border:1px solid #a8cde8;color:#155f8f;font-style:italic;font-weight:bold;border-radius:6px}` &&
      `table.diff{border-collapse:collapse;width:100%;font-size:12px;margin:0 0 4px 0}` &&
      `.diff .ln{color:#aaa;text-align:right;padding:1px 10px 1px 5px;` &&
      `min-width:42px;border-right:1px solid #e0e0e0;white-space:nowrap;background:#fafafa}` &&
      `.diff .cd{padding:1px 8px;white-space:pre}` &&
      `.back{position:fixed;top:8px;left:8px;z-index:999;` &&
      `background:#3498db;color:#fff;padding:4px 10px;border-radius:4px;` &&
      `text-decoration:none;font:bold 12px Consolas,monospace;white-space:nowrap;` &&
      `box-shadow:0 1px 4px rgba(0,0,0,.25)}` &&
      `.filter-btn{display:inline-block;background:#eee;color:#333;padding:4px 10px;border-radius:4px;cursor:pointer;` &&
      `font:bold 12px Consolas,monospace;border:1px solid #bbb;text-decoration:none;` &&
      `white-space:nowrap;margin-right:4px}` &&
      `.filter-btn.active{background:#e74c3c;color:#fff;border-color:#c0392b}` &&
      `.filter-btn.active.comments{background:#27ae60;border-color:#1e8449}`.

    DATA(lv_ai_prompt_label) = COND string(
      WHEN is_ai_enabled( ) = abap_true THEN `AI Summary`
      ELSE `AI prompt` ).

    DATA(lv_html) =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ lv_css }</style>| &&
      `<script>` &&
      `(function(){` &&
        `var k='ave_scroll_crpart';` &&
        `var pos=sessionStorage.getItem(k);` &&
        `if(pos){` &&
          `window.addEventListener('load',function(){window.scrollTo(0,parseInt(pos,10));sessionStorage.removeItem(k);});` &&
        `}` &&
        `window._saveScroll=function(){sessionStorage.setItem(k,window.scrollY||document.documentElement.scrollTop||0);};` &&
      `})();` &&
      `function filterBlocks(mode){` &&
        `var btns=document.querySelectorAll('.filter-btn');` &&
        `btns.forEach(function(b){b.classList.remove('active');});` &&
        `var blocks=document.querySelectorAll('.block');` &&
        `blocks.forEach(function(b){b.style.display='';});` &&
        `if(!mode){return;}` &&
        `var btn=document.getElementById('btn_'+mode);` &&
        `if(btn){btn.classList.add('active');if(mode==='comments')btn.classList.add('comments');}` &&
        `blocks.forEach(function(b){` &&
          `var show=false;` &&
          `if(mode==='declined'){` &&
            `var notes=b.querySelectorAll('.note');` &&
            `for(var i=0;i<notes.length;i++){if(notes[i].getAttribute('style')){show=true;break;}}` &&
          `}else if(mode==='comments'){` &&
            `show=b.querySelector('.comments')!==null;` &&
          `}` &&
          `b.style.display=show?'':'none';` &&
        `});` &&
      `}` &&
      `document.addEventListener('click',function(e){` &&
        `var a=e.target.closest('a[href^="sapevent:addcomment"],a[href^="sapevent:editreview"]');` &&
        `if(a&&window._saveScroll){window._saveScroll();}` &&
      `});` &&
      `</script>` &&
      `</head><body>` &&
      |<a class="back" href="sapevent:back~0">&#8592; Back</a>| &&
      `<p style="margin:0 0 14px 0">` &&
      `<a id="btn_declined" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'declined');return false">Declined only</a>` &&
      `<a id="btn_comments" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'comments');return false">Comments only</a>` &&
      |<a class="filter-btn" href="sapevent:aiprompt~0">{ lv_ai_prompt_label }</a>| &&
      `</p>` &&
      |<h2>{ escape( val = CONV string( iv_objtype ) format = cl_abap_format=>e_html_text ) }: | &&
      |{ escape( val = lv_page_title format = cl_abap_format=>e_html_text ) }</h2>|.

    IF lt_hunks IS INITIAL.
      lv_html = lv_html &&
        |<p style="color:#888">No changed blocks found for this object.</p>| &&
        |</body></html>|.
      maximize_html( ).
      set_html( lv_html ).
      RETURN.
    ENDIF.

    LOOP AT lt_hunks INTO DATA(ls_hunk).
      " ── Diff HTML cleanup (identical to SHOW_USER_DECLINES) ──────────────────
      DATA(lv_clean_html) = ls_hunk-html.
      "blame row should not be deleted CLAUDE
*      DATA lv_mark_pos    TYPE i.
*      DATA lv_before_mark TYPE string.
*      DATA lv_after_mark  TYPE string.
*      DATA lv_tr_start    TYPE i.
*      DATA lv_tr_end_rel  TYPE i.
*      DATA lv_tr_end      TYPE i.
*      DATA lv_rev_before  TYPE string.
*      DATA lv_rev_pos     TYPE i.
*      WHILE lv_clean_html CS `──</td>`.
*        lv_mark_pos   = sy-fdpos.
*        lv_before_mark = lv_clean_html(lv_mark_pos).
*        lv_after_mark  = lv_clean_html+lv_mark_pos.
*        lv_rev_before  = reverse( lv_before_mark ).
*        FIND FIRST OCCURRENCE OF `rt<` IN lv_rev_before MATCH OFFSET lv_rev_pos.
*        IF sy-subrc <> 0. EXIT. ENDIF.
*        lv_tr_start = strlen( lv_before_mark ) - lv_rev_pos - 3.
*        FIND FIRST OCCURRENCE OF `</tr>` IN lv_after_mark MATCH OFFSET lv_tr_end_rel.
*        IF sy-subrc <> 0. EXIT. ENDIF.
*        lv_tr_end = lv_mark_pos + lv_tr_end_rel + 5.
*        IF lv_tr_start < 0 OR lv_tr_end <= lv_tr_start. EXIT. ENDIF.
*        lv_clean_html = lv_clean_html(lv_tr_start) && lv_clean_html+lv_tr_end.
*      ENDWHILE.
      IF mv_two_pane = abap_false AND lv_clean_html CS `<td class="sep"></td>`.
        DATA(lv_rows_html)       = lv_clean_html.
        DATA(lv_norm_html)       = ``.
        DATA lv_row_start        TYPE i.
        DATA lv_row_close_rel    TYPE i.
        DATA lv_row_close        TYPE i.
        DATA lv_row_len          TYPE i.
        DATA lv_row_html         TYPE string.
        DATA lv_gt_pos           TYPE i.
        DATA lv_sep_pos          TYPE i.
        DATA lv_body_left        TYPE string.
        DATA lv_body_right       TYPE string.
        DATA lv_plain_left       TYPE string.
        DATA lv_plain_right      TYPE string.
        WHILE lv_rows_html CS `<tr`.
          lv_row_start = sy-fdpos.
          IF lv_row_start > 0.
            lv_norm_html  = lv_norm_html && lv_rows_html(lv_row_start).
            lv_rows_html  = lv_rows_html+lv_row_start.
          ENDIF.
          FIND FIRST OCCURRENCE OF `</tr>` IN lv_rows_html MATCH OFFSET lv_row_close_rel.
          IF sy-subrc <> 0.
            lv_norm_html = lv_norm_html && lv_rows_html.
            CLEAR lv_rows_html.
            EXIT.
          ENDIF.
          lv_row_close = lv_row_close_rel + 5.
          lv_row_html  = lv_rows_html(lv_row_close).
          lv_rows_html = lv_rows_html+lv_row_close.
          IF lv_row_html CS `<td class="sep"></td>`.
            FIND FIRST OCCURRENCE OF `>` IN lv_row_html MATCH OFFSET lv_gt_pos.
            FIND FIRST OCCURRENCE OF `<td class="sep"></td>` IN lv_row_html MATCH OFFSET lv_sep_pos.
            IF sy-subrc = 0 AND lv_gt_pos >= 0 AND lv_sep_pos > lv_gt_pos.
              DATA(lv_body_left_off)  = lv_gt_pos + 1.
              DATA(lv_body_left_len)  = lv_sep_pos - lv_gt_pos - 1.
              DATA(lv_body_right_off) = lv_sep_pos + 21.
              DATA(lv_row_prefix_len) = lv_gt_pos + 1.
              lv_body_left  = lv_row_html+lv_body_left_off(lv_body_left_len).
              lv_body_right = lv_row_html+lv_body_right_off.
              lv_row_len = strlen( lv_body_right ).
              IF lv_row_len >= 5.
                DATA(lv_body_right_len) = lv_row_len - 5.
                lv_body_right = lv_body_right(lv_body_right_len).
              ENDIF.
              lv_plain_left  = lv_body_left.
              lv_plain_right = lv_body_right.
              REPLACE ALL OCCURRENCES OF REGEX `<[^>]+>` IN lv_plain_left  WITH ``.
              REPLACE ALL OCCURRENCES OF REGEX `<[^>]+>` IN lv_plain_right WITH ``.
              CONDENSE lv_plain_left  NO-GAPS.
              CONDENSE lv_plain_right NO-GAPS.
              lv_norm_html = lv_norm_html &&
                lv_row_html(lv_row_prefix_len) &&
                COND string(
                  WHEN strlen( lv_plain_right ) >= strlen( lv_plain_left )
                  THEN lv_body_right ELSE lv_body_left ) &&
                `</tr>`.
            ELSE.
              lv_norm_html = lv_norm_html && lv_row_html.
            ENDIF.
          ELSE.
            lv_norm_html = lv_norm_html && lv_row_html.
          ENDIF.
        ENDWHILE.
        lv_clean_html = lv_norm_html && lv_rows_html.
      ENDIF.
      DATA(lv_code_html) = COND string(
        WHEN lv_clean_html IS NOT INITIAL
        THEN |<table class="diff"><tbody>{ lv_clean_html }</tbody></table>|
        ELSE `<div style="color:#888;margin:4px 0 10px">Diff not available.</div>` ).

      " ── Block header ─────────────────────────────────────────────────────────
      DATA(lv_block_title) = COND string(
        WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
        ELSE CONV string( ls_hunk-obj_name ) ).
      DATA(lv_change_kind_html) = COND string(
        WHEN ls_hunk-change_kind IS NOT INITIAL
        THEN | <span class="muted">{ escape( val = ls_hunk-change_kind format = cl_abap_format=>e_html_text ) }</span>|
        ELSE `` ).
      DATA(lv_hunk_new_text) = ls_hunk-versno_new_text.
      DATA(lv_hunk_old_text) = ls_hunk-versno_old_text.
      DATA(lv_hunk_new_versno) = ls_hunk-versno_new.
      DATA(lv_hunk_old_versno) = ls_hunk-versno_old.
      IF lv_hunk_new_versno IS INITIAL.
        READ TABLE mt_acr_stats INTO DATA(ls_hunk_stat)
          WITH KEY objtype = ls_hunk-objtype obj_name = ls_hunk-obj_name.
        IF sy-subrc = 0.
          lv_hunk_new_versno = ls_hunk_stat-versno_new.
          lv_hunk_old_versno = ls_hunk_stat-versno_old.
        ENDIF.
      ENDIF.
      IF lv_hunk_new_text IS INITIAL AND lv_hunk_new_versno IS NOT INITIAL.
        lv_hunk_new_text = COND string(
          WHEN lv_hunk_new_versno = zcl_ave_version=>c_version-active   THEN `Active`
          WHEN lv_hunk_new_versno = zcl_ave_version=>c_version-modified THEN `Modified`
          ELSE |v{ CONV string( lv_hunk_new_versno + 0 ) }| ).
      ELSEIF lv_hunk_new_text IS NOT INITIAL
         AND lv_hunk_new_text CA '0123456789'
         AND lv_hunk_new_text NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
        lv_hunk_new_text = |v{ lv_hunk_new_text }|.
      ENDIF.
      IF lv_hunk_old_text IS INITIAL.
        lv_hunk_old_text = COND string(
          WHEN lv_hunk_old_versno IS INITIAL                             THEN `(new object)`
          WHEN lv_hunk_old_versno = zcl_ave_version=>c_version-active   THEN `Active`
          WHEN lv_hunk_old_versno = zcl_ave_version=>c_version-modified THEN `Modified`
          ELSE |v{ CONV string( lv_hunk_old_versno + 0 ) }| ).
      ELSEIF lv_hunk_old_text CA '0123456789'
         AND lv_hunk_old_text NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
        lv_hunk_old_text = |v{ lv_hunk_old_text }|.
      ENDIF.
      DATA(lv_versions_html) = COND string(
        WHEN lv_hunk_new_text IS NOT INITIAL
        THEN | <span class="muted">versions</span> { escape( val = lv_hunk_new_text format = cl_abap_format=>e_html_text ) } -&gt; { escape( val = lv_hunk_old_text format = cl_abap_format=>e_html_text ) }|
        ELSE `` ).

      " ── Actions (Approve / Decline / Undo / Comment) ─────────────────────────
      DATA(lv_actions_html) = zcl_ave_acr_renderer=>render_hunk_actions_html(
        iv_hunk_key     = ls_hunk-hunk_key
        it_approved     = mt_approved
        it_declined     = mt_declined
        it_hunk_actions = mt_hunk_actions
        it_hunk_info    = mt_hunk_info
        it_hunk_threads = mt_hunk_threads
        iv_ai_enabled   = COND #( WHEN mv_desination IS NOT INITIAL
                                    AND mv_model IS NOT INITIAL
                                    AND mv_apikey IS NOT INITIAL
                                  THEN abap_true ELSE abap_false ) ).

      lv_html = lv_html &&
        `<div class="block">` &&
        |<div class="blkinfo">{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
        |{ escape( val = lv_block_title format = cl_abap_format=>e_html_text ) } | &&
        |Block #{ ls_hunk-hunk_no }| &&
        lv_change_kind_html &&
        lv_versions_html &&
        | <span class="muted">line</span> { ls_hunk-start_line }| &&
        | <span class="muted">changes</span> { ls_hunk-change_count }</div>| &&
        lv_actions_html.

      " ── Comments for this hunk ────────────────────────────────────────────────
      DATA(lv_comments_html) = ``.
      DATA(ls_thread) = get_hunk_thread( ls_hunk ).
      IF ls_thread-messages IS NOT INITIAL.
        LOOP AT ls_thread-messages INTO DATA(ls_msg).
          CHECK ls_msg-text IS NOT INITIAL.
          DATA(lv_note_esc) = escape( val = ls_msg-text format = cl_abap_format=>e_html_text ).
          REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_note_esc WITH `<br>`.
          DATA(lv_created_at_txt) = format_timestamp( ls_msg-created_at ).
          DATA(lv_note_style) = COND string(
            WHEN ls_msg-is_decline = abap_true
            THEN ` style="background:#fff1f4;border-color:#efb8c8;color:#9f3b57"`
            ELSE `` ).
          lv_comments_html = lv_comments_html &&
            |<span class="meta">{ escape( val = CONV string( ls_msg-author ) format = cl_abap_format=>e_html_text ) }| &&
            | / { escape( val = CONV string( ls_msg-author_name ) format = cl_abap_format=>e_html_text ) }| &&
            | / { escape( val = lv_created_at_txt format = cl_abap_format=>e_html_text ) }</span>| &&
            |<div class="note"{ lv_note_style }>{ lv_note_esc }</div>|.
        ENDLOOP.
      ENDIF.
      IF lv_comments_html IS NOT INITIAL.
        lv_html = lv_html &&
          |<div id="{ get_hunk_scroll_anchor( ls_hunk-hunk_key ) }" class="comments">{ lv_comments_html }</div>|.
      ENDIF.

      lv_html = lv_html &&
        `<div class="codewrap">` &&
        lv_code_html &&
        `</div></div>`.
    ENDLOOP.

    lv_html = lv_html && render_ai_summary_html(
      iv_objtype = iv_objtype
      iv_objname = iv_objname ).

    lv_html = lv_html && zcl_ave_acr_hunk_renderer=>build_approveall_btn(
      iv_obj_key      = |{ iv_objtype }~{ iv_objname }|
      iv_total_hunks  = REDUCE i( INIT n = 0 FOR ls IN mt_hunk_info
                          WHERE ( objtype = iv_objtype AND obj_name = iv_objname )
                          NEXT n = n + 1 )
      it_approved     = mt_approved
      it_declined     = mt_declined
      it_hunk_actions = mt_hunk_actions ) &&
      `</body></html>`.
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD rerender_cr_current.
    result = abap_false.
    CHECK mv_code_review = abap_true.
    CHECK mv_decline_view_user IS INITIAL.
    CHECK mv_cr_cur_key IS NOT INITIAL.

    DATA lv_tld TYPE i.
    FIND FIRST OCCURRENCE OF '~' IN mv_cr_cur_key MATCH OFFSET lv_tld.
    CHECK sy-subrc = 0.

    DATA lv_objtype TYPE versobjtyp.
    DATA lv_objname TYPE versobjnam.
    lv_objtype = mv_cr_cur_key(lv_tld).
    DATA(lv_name_start) = lv_tld + 1.
    lv_objname = mv_cr_cur_key+lv_name_start.

    READ TABLE mt_parts INTO DATA(ls_part)
      WITH KEY type = lv_objtype object_name = lv_objname.
    CHECK sy-subrc = 0.

    DELETE mt_acr_stats WHERE objtype = lv_objtype AND obj_name = lv_objname.
    DELETE mt_diff_cache WHERE key-objtype = lv_objtype AND key-objname = lv_objname.

    cr_precompute_part( ls_part ).
    open_cr_part( iv_objtype = lv_objtype iv_objname = lv_objname ).
    result = abap_true.
  ENDMETHOD.


  METHOD rerender_cr_user_view.
    result = abap_false.
    CHECK mv_code_review = abap_true.
    IF mv_decline_view_user IS INITIAL AND mv_reviewer_view = abap_true.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_obj_key,
             objtype  TYPE versobjtyp,
             obj_name TYPE versobjnam,
           END OF ty_obj_key.
    DATA lt_keys TYPE SORTED TABLE OF ty_obj_key WITH UNIQUE KEY objtype obj_name.

    IF mv_reviewer_view = abap_true.
      DATA lt_review_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
      DATA ls_review_payload TYPE ty_saved_payload.
      IF load_review_payload(
           EXPORTING iv_trkorr = CONV #( mv_object_name )
           IMPORTING es_payload = ls_review_payload ) = abap_true.
        READ TABLE ls_review_payload-user_states INTO DATA(ls_review_state)
          WITH KEY reviewer = mv_decline_view_user.
        IF sy-subrc = 0.
          LOOP AT ls_review_state-approved INTO DATA(ls_review_approved).
            INSERT ls_review_approved-hunk_key INTO TABLE lt_review_keys.
          ENDLOOP.
          LOOP AT ls_review_state-declined INTO DATA(ls_review_declined).
            INSERT ls_review_declined-hunk_key INTO TABLE lt_review_keys.
          ENDLOOP.
        ENDIF.
      ENDIF.

      IF mv_decline_view_user = sy-uname.
        LOOP AT mt_approved INTO DATA(lv_cur_approved_key).
          INSERT lv_cur_approved_key INTO TABLE lt_review_keys.
        ENDLOOP.
        LOOP AT mt_declined INTO DATA(lv_cur_declined_key).
          INSERT lv_cur_declined_key INTO TABLE lt_review_keys.
        ENDLOOP.
      ENDIF.

      LOOP AT mt_hunk_threads INTO DATA(ls_review_thread).
        LOOP AT ls_review_thread-messages TRANSPORTING NO FIELDS WHERE author = mv_decline_view_user.
          INSERT ls_review_thread-hunk_key INTO TABLE lt_review_keys.
          EXIT.
        ENDLOOP.
      ENDLOOP.

      LOOP AT lt_review_keys INTO DATA(lv_review_key).
        READ TABLE mt_hunk_info INTO DATA(ls_review_hunk)
          WITH TABLE KEY hunk_key = lv_review_key.
        IF sy-subrc = 0.
          INSERT VALUE #( objtype = ls_review_hunk-objtype obj_name = ls_review_hunk-obj_name ) INTO TABLE lt_keys.
        ENDIF.
      ENDLOOP.
    ELSE.
      IF mv_decline_view_user IS INITIAL.
        LOOP AT mt_hunk_info INTO DATA(ls_hi_all).
          INSERT VALUE #( objtype = ls_hi_all-objtype obj_name = ls_hi_all-obj_name ) INTO TABLE lt_keys.
        ENDLOOP.
      ELSE.
        LOOP AT mt_hunk_info INTO DATA(ls_hi) WHERE author = mv_decline_view_user.
          INSERT VALUE #( objtype = ls_hi-objtype obj_name = ls_hi-obj_name ) INTO TABLE lt_keys.
        ENDLOOP.
      ENDIF.
    ENDIF.
    CHECK lt_keys IS NOT INITIAL.

    LOOP AT lt_keys INTO DATA(ls_key).
      READ TABLE mt_parts INTO DATA(ls_part)
        WITH KEY type = ls_key-objtype object_name = ls_key-obj_name.
      CHECK sy-subrc = 0.

      DELETE mt_acr_stats WHERE objtype = ls_key-objtype AND obj_name = ls_key-obj_name.
      DELETE mt_diff_cache WHERE key-objtype = ls_key-objtype AND key-objname = ls_key-obj_name.
      cr_precompute_part( ls_part ).
    ENDLOOP.

    show_user_declines( iv_user = mv_decline_view_user iv_reviewer = mv_reviewer_view ).
    result = abap_true.
  ENDMETHOD.


  METHOD on_note_dlg_saved.
    " Called when user clicks Save in the note dialog.
    " For pending decline, register decline; otherwise just add/update comment.
    DATA lv_msg_ts TYPE timestampl.
    DATA(lv_is_decline_msg) = xsdbool( mv_pending_decline = iv_hunk_key ).

    IF mv_pending_decline = iv_hunk_key
       AND zcl_ave_acr_state=>is_own_hunk(
             iv_hunk_key  = iv_hunk_key
             it_hunk_info = mt_hunk_info ) = abap_true.
      CLEAR mv_pending_decline.
      MESSAGE 'You cannot decline your own block' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA ls_dn TYPE ty_decline_note.
    ls_dn-hunk_key = iv_hunk_key.
    ls_dn-note     = iv_note.
    INSERT ls_dn INTO TABLE mt_decline_notes.
    IF sy-subrc <> 0. MODIFY TABLE mt_decline_notes FROM ls_dn. ENDIF.

    IF mv_pending_decline = iv_hunk_key.
      INSERT iv_hunk_key INTO TABLE mt_declined.
      DELETE TABLE mt_approved FROM iv_hunk_key.
      set_hunk_action( iv_hunk_key = iv_hunk_key iv_action = 'D' ).
    ENDIF.

    READ TABLE mt_hunk_threads ASSIGNING FIELD-SYMBOL(<ls_thread>)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    IF sy-subrc <> 0.
      READ TABLE mt_hunk_info INTO DATA(ls_hunk_info)
        WITH TABLE KEY hunk_key = iv_hunk_key.
      IF sy-subrc = 0.
        INSERT VALUE ty_hunk_thread(
          hunk_key     = ls_hunk_info-hunk_key
          objtype      = ls_hunk_info-objtype
          obj_name     = ls_hunk_info-obj_name
          class_name   = ls_hunk_info-class_name
          display_name = ls_hunk_info-display_name
          hunk_no      = ls_hunk_info-hunk_no
          start_line   = ls_hunk_info-start_line
          change_count = ls_hunk_info-change_count
          change_kind  = ls_hunk_info-change_kind
          versno_new   = ls_hunk_info-versno_new
          versno_old   = ls_hunk_info-versno_old
          versno_new_text = ls_hunk_info-versno_new_text
          versno_old_text = ls_hunk_info-versno_old_text
          html         = ls_hunk_info-html ) INTO TABLE mt_hunk_threads.
        READ TABLE mt_hunk_threads ASSIGNING <ls_thread>
          WITH TABLE KEY hunk_key = iv_hunk_key.
      ENDIF.
    ENDIF.

    IF <ls_thread> IS ASSIGNED.
      GET TIME STAMP FIELD lv_msg_ts.
      DATA(lv_message_handled) = abap_false.
      IF mv_pending_edit = iv_hunk_key.
        DATA(lv_edit_idx) = lines( <ls_thread>-messages ).
        WHILE lv_edit_idx > 0.
          READ TABLE <ls_thread>-messages ASSIGNING FIELD-SYMBOL(<ls_edit_msg>) INDEX lv_edit_idx.
          IF sy-subrc = 0 AND <ls_edit_msg>-author = sy-uname.
            <ls_edit_msg>-text = iv_note.
            <ls_edit_msg>-created_at = lv_msg_ts.
            lv_message_handled = abap_true.
            EXIT.
          ENDIF.
          lv_edit_idx -= 1.
        ENDWHILE.
      ENDIF.

      IF lv_message_handled = abap_false.
        READ TABLE <ls_thread>-messages INTO DATA(ls_last_msg)
          INDEX lines( <ls_thread>-messages ).
        IF sy-subrc <> 0
           OR ls_last_msg-author <> sy-uname
           OR ls_last_msg-is_decline <> lv_is_decline_msg
           OR ls_last_msg-text   <> iv_note.
          APPEND VALUE ty_decline_msg(
          author      = sy-uname
          author_name = zcl_ave_popup_data=>get_user_name( sy-uname )
          created_at  = lv_msg_ts
          is_decline  = lv_is_decline_msg
          text        = iv_note ) TO <ls_thread>-messages.
        ENDIF.
      ENDIF.
    ENDIF.
    CLEAR mv_pending_decline.
    CLEAR mv_pending_edit.

    save_review_to_db( iv_silent = abap_true ).

    " Refresh diff view and report.
    " Priority: 1) user/reviewer drill-down  2) object part view (openobj)  3) cached ALV diff
    IF mv_decline_view_user IS NOT INITIAL.
      show_user_declines( iv_user = mv_decline_view_user iv_reviewer = mv_reviewer_view ).
    ELSEIF mv_cur_objtype IS NOT INITIAL AND mv_cr_base_html IS INITIAL.
      " Object part view opened via sapevent:openobj — mv_cr_base_html was cleared by open_cr_part
      open_cr_part( iv_objtype = mv_cur_objtype iv_objname = mv_cur_objname ).
    ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
      DATA(lv_html_after_note) = inject_approve_btn(
        iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ).

      DATA(lv_rev_note) = reverse( iv_hunk_key ).
      DATA lv_tilde_pos_note TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rev_note MATCH OFFSET lv_tilde_pos_note.
      IF sy-subrc = 0.
        DATA lv_chunk_start_note TYPE i.
        lv_chunk_start_note = strlen( iv_hunk_key ) - lv_tilde_pos_note.
        DATA(lv_chunk_note) = iv_hunk_key+lv_chunk_start_note.
        IF lv_chunk_note IS NOT INITIAL.
          DATA(lv_script_note) =
            `<script>window.onload=function(){` &&
            `var e=document.getElementById('acr_c` && lv_chunk_note && `');` &&
            `if(e)e.scrollIntoView({block:'center'});}` &&
            `</script></head>`.
          lv_html_after_note = replace(
            val  = lv_html_after_note
            sub  = `</head>`
            with = lv_script_note ).
        ENDIF.
      ENDIF.

      set_html( lv_html_after_note ).
    ENDIF.
    refresh_rpt_row( ).
    regen_acr_report( ).
  ENDMETHOD.


  METHOD on_note_dlg_cancelled.
    IF mv_pending_decline = iv_hunk_key.
      CLEAR mv_pending_decline.
    ENDIF.
    IF mv_pending_edit = iv_hunk_key.
      CLEAR mv_pending_edit.
    ENDIF.
  ENDMETHOD.


  METHOD regen_acr_report.
    IF mv_cr_prepared = abap_true.
      sanitize_review_state( ).
      DATA lt_report_approved TYPE zif_ave_acr_types=>ty_approved.
      DATA lt_report_declined TYPE zif_ave_acr_types=>ty_approved.
      collect_report_status(
        IMPORTING
          et_approved = lt_report_approved
          et_declined = lt_report_declined ).
      mv_cr_report_html = zcl_ave_acr_report=>to_html(
        it_obj_stats = mt_acr_stats
        it_approved  = lt_report_approved
        it_declined  = lt_report_declined
        it_reviewers = get_reviewer_stats( )
        i_korrnum    = CONV #( mv_object_name ) ).
      mv_cr_report_html = add_cr_diagnostics( mv_cr_report_html ).
      mv_cr_report_html = add_cr_report_toolbar( mv_cr_report_html ).
    ELSE.
      mv_cr_report_html = build_cr_object_report_html( ).
    ENDIF.
  ENDMETHOD.


  METHOD add_cr_report_toolbar.
    result = zcl_ave_acr_renderer=>add_report_toolbar(
      iv_html    = iv_html
      iv_enabled = mv_code_review ).
  ENDMETHOD.


  METHOD build_cr_object_report_html.
    DATA lv_korr_text TYPE as4text.
    DATA(lv_korrnum) = CONV trkorr( mv_object_name ).
    SELECT SINGLE as4text FROM e07t
      WHERE trkorr = @lv_korrnum AND langu = @sy-langu
      INTO @lv_korr_text.

    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `.prepare{text-align:center;margin:8px 0 18px 0}` &&
      `.prepare a{display:inline-block;background:#27ae60;color:#fff;text-decoration:none;` &&
      `font:bold 13px Consolas,monospace;border-radius:4px;padding:7px 20px}` &&
      `table{border-collapse:collapse;width:100%;margin-bottom:16px;font-size:12px}` &&
      `th{background:#3498db;color:#fff;padding:5px 10px;text-align:left;white-space:nowrap}` &&
      `td{padding:4px 10px;border-bottom:1px solid #eee;white-space:nowrap}` &&
      `tr:hover td{background:#f5f9ff}` &&
      `tr.skip td{color:#999;background:#f3f3f3}` &&
      `tr.skip a{color:#777!important}` &&
      `tr.deleted td{color:#a94442;background:#fdf2f2}` &&
      `tr.deleted a{color:#a94442!important}` &&
      `.nr{text-align:right}.muted{color:#777}`.

    DATA(lv_has_saved_review) = abap_false.
    IF has_review_table( ) = abap_true.
      DATA(ls_saved_payload_check) = VALUE ty_saved_payload( ).
      IF load_review_payload(
           EXPORTING iv_trkorr = CONV #( mv_object_name )
           IMPORTING es_payload = ls_saved_payload_check ) = abap_true
         AND ls_saved_payload_check-obj_stats IS NOT INITIAL
         AND ls_saved_payload_check-hunks IS NOT INITIAL
         AND ls_saved_payload_check-diff_cache IS NOT INITIAL.
        lv_has_saved_review = abap_true.
      ENDIF.
    ENDIF.

    TYPES: BEGIN OF ty_cr_rele_task,
             trkorr TYPE trkorr,
             owner  TYPE versuser,
             datum  TYPE versdate,
             zeit   TYPE verstime,
           END OF ty_cr_rele_task.
    TYPES: BEGIN OF ty_cr_author_key,
             author TYPE versuser,
           END OF ty_cr_author_key.
    TYPES: BEGIN OF ty_cr_task_key,
             trkorr TYPE trkorr,
           END OF ty_cr_task_key.
    TYPES: BEGIN OF ty_cr_task_object,
             trkorr   TYPE trkorr,
             pgmid    TYPE e071-pgmid,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
             owner    TYPE versuser,
             datum    TYPE versdate,
             zeit     TYPE verstime,
           END OF ty_cr_task_object.
    " For TADIR deleted-flag lookup: pgmid+object+obj_name → delflag
    TYPES: BEGIN OF ty_tadir_key,
             pgmid    TYPE tadir-pgmid,
             object   TYPE tadir-object,
             obj_name TYPE tadir-obj_name,
           END OF ty_tadir_key.
    TYPES: BEGIN OF ty_tadir_delflag,
             pgmid    TYPE tadir-pgmid,
             object   TYPE tadir-object,
             obj_name TYPE tadir-obj_name,
             delflag  TYPE tadir-delflag,
           END OF ty_tadir_delflag.
    DATA lt_cr_rele_tasks   TYPE STANDARD TABLE OF ty_cr_rele_task   WITH DEFAULT KEY.
    DATA lt_cr_task_objects TYPE STANDARD TABLE OF ty_cr_task_object WITH DEFAULT KEY.
    DATA lt_tadir_keys      TYPE STANDARD TABLE OF ty_tadir_key      WITH DEFAULT KEY.
    DATA lt_tadir_delflags  TYPE STANDARD TABLE OF ty_tadir_delflag  WITH DEFAULT KEY.
    DATA lv_cr_corr_pgmid TYPE e071-pgmid VALUE 'CORR'.
    DATA lv_cr_corr_rele  TYPE e071-object VALUE 'RELE'.

    IF mv_cr_prepared = abap_true.
      SELECT obj_name FROM e071
        WHERE trkorr = @lv_korrnum
          AND pgmid  = @lv_cr_corr_pgmid
          AND object = @lv_cr_corr_rele
        INTO TABLE @DATA(lt_cr_rele_objects).

      LOOP AT lt_cr_rele_objects INTO DATA(lv_cr_rele_obj).
        DATA lv_cr_task_text  TYPE string.
        DATA lv_cr_date_text  TYPE string.
        DATA lv_cr_time_text  TYPE string.
        DATA lv_cr_owner_text TYPE string.
        CONDENSE lv_cr_rele_obj.
        SPLIT lv_cr_rele_obj AT space
          INTO lv_cr_task_text lv_cr_date_text lv_cr_time_text lv_cr_owner_text.
        CHECK lv_cr_task_text IS NOT INITIAL
          AND strlen( lv_cr_date_text ) = 8
          AND strlen( lv_cr_time_text ) = 6
          AND lv_cr_date_text CO '0123456789'
          AND lv_cr_time_text CO '0123456789'.
        APPEND VALUE #(
          trkorr = lv_cr_task_text
          owner  = lv_cr_owner_text
          datum  = lv_cr_date_text
          zeit   = lv_cr_time_text ) TO lt_cr_rele_tasks.
      ENDLOOP.

      IF lt_cr_rele_tasks IS NOT INITIAL.
        SELECT trkorr, pgmid, object, obj_name FROM e071
          FOR ALL ENTRIES IN @lt_cr_rele_tasks
          WHERE trkorr = @lt_cr_rele_tasks-trkorr
          INTO TABLE @DATA(lt_cr_e071_objects).
        LOOP AT lt_cr_e071_objects INTO DATA(ls_cr_e071_object).
          READ TABLE lt_cr_rele_tasks INTO DATA(ls_cr_rele_meta)
            WITH KEY trkorr = ls_cr_e071_object-trkorr.
          CHECK sy-subrc = 0.
          APPEND VALUE #(
            trkorr   = ls_cr_e071_object-trkorr
            pgmid    = ls_cr_e071_object-pgmid
            object   = ls_cr_e071_object-object
            obj_name = ls_cr_e071_object-obj_name
            owner    = ls_cr_rele_meta-owner
            datum    = ls_cr_rele_meta-datum
            zeit     = ls_cr_rele_meta-zeit ) TO lt_cr_task_objects.
        ENDLOOP.
      ENDIF.
    ENDIF.

    " Build TADIR lookup keys for all parts — one bulk SELECT before the render loop
    LOOP AT mt_parts INTO DATA(ls_part_key_scan) WHERE type <> 'RPT'.
      DATA lv_scan_tadir_pgmid  TYPE tadir-pgmid.
      DATA lv_scan_tadir_object TYPE tadir-object.
      DATA lv_scan_tadir_name   TYPE tadir-obj_name.
      " Resolve pgmid/object/obj_name the same way as lv_part_e071_type above,
      " but prefer what E071 says for this object (first matching entry).
      DATA(lv_scan_e071_object) = SWITCH e071-object( ls_part_key_scan-type
        WHEN 'REPS' OR 'REPT'                                THEN 'PROG'
        WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI'
          OR 'METH' OR 'CDEF'                                THEN 'CLAS'
        ELSE ls_part_key_scan-type ).
      DATA(lv_scan_e071_name) = CONV e071-obj_name( ls_part_key_scan-object_name ).
      IF lv_scan_e071_object = 'CLAS' AND ls_part_key_scan-class IS NOT INITIAL.
        lv_scan_e071_name = ls_part_key_scan-class.
      ELSEIF lv_scan_e071_object = 'CLAS' AND lv_scan_e071_name CS '='.
        DATA(lv_scan_eq) = find( val = CONV string( lv_scan_e071_name ) sub = '=' ).
        IF lv_scan_eq > 0.
          lv_scan_e071_name = lv_scan_e071_name(lv_scan_eq).
        ENDIF.
      ENDIF.
      " Look up pgmid from E071 for this object/name
      lv_scan_tadir_pgmid = 'R3TR'. " default
      READ TABLE lt_cr_task_objects INTO DATA(ls_scan_e071_row)
        WITH KEY object = lv_scan_e071_object obj_name = lv_scan_e071_name.
      IF sy-subrc = 0.
        lv_scan_tadir_pgmid = ls_scan_e071_row-pgmid.
      ENDIF.
      lv_scan_tadir_object = lv_scan_e071_object.
      lv_scan_tadir_name   = lv_scan_e071_name.
      " Collect unique keys
      READ TABLE lt_tadir_keys TRANSPORTING NO FIELDS
        WITH KEY pgmid = lv_scan_tadir_pgmid object = lv_scan_tadir_object obj_name = lv_scan_tadir_name.
      IF sy-subrc <> 0.
        APPEND VALUE #(
          pgmid    = lv_scan_tadir_pgmid
          object   = lv_scan_tadir_object
          obj_name = lv_scan_tadir_name ) TO lt_tadir_keys.
      ENDIF.
    ENDLOOP.

    " Bulk read TADIR delflag
    IF lt_tadir_keys IS NOT INITIAL.
      SELECT pgmid, object, obj_name, delflag FROM tadir
        FOR ALL ENTRIES IN @lt_tadir_keys
        WHERE pgmid    = @lt_tadir_keys-pgmid
          AND object   = @lt_tadir_keys-object
          AND obj_name = @lt_tadir_keys-obj_name
        INTO TABLE @lt_tadir_delflags.
    ENDIF.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8">| &&
      |<style>{ lv_css }</style></head><body>| &&
      |<h2>&#128196;&nbsp;Code Review Report&nbsp;-&nbsp;| &&
      |<span style="color:#3498db">{ escape( val = CONV string( mv_object_name ) format = cl_abap_format=>e_html_text ) }|.
    IF lv_korr_text IS NOT INITIAL.
      result = result && |&nbsp;-&nbsp;{ escape( val = CONV string( lv_korr_text ) format = cl_abap_format=>e_html_text ) }|.
    ENDIF.
    result = result && |</span></h2>|.

    result = result && `<div class="prepare">`.
    IF lv_has_saved_review = abap_true.
      result = result &&
        `<a href="sapevent:openreview~0">Open Review</a>` &&
        `&nbsp;&nbsp;` &&
        `<a href="sapevent:recalcpick~0" style="background:#7f8c8d">Recalc Diff</a>`.
    ELSE.
      result = result &&
        `<a href="sapevent:prepare~0">Prepare Code Review</a>`.
    ENDIF.
    result = result &&
      `</div>` &&
      |<table><tr>| &&
      |<th>Type</th><th>Object</th><th>Class</th><th>Type Description</th>| &&
      |<th>Author</th><th class="nr">TRs/Tasks</th><th>Start</th><th>Finish</th><th class="nr">Days</th>| &&
      |<th class="nr">Rows</th></tr>|.

    DATA lv_earliest_finish_minus1 TYPE versdate.
    DATA lv_report_part_idx TYPE i.
    DATA lv_report_part_total TYPE i.
    LOOP AT mt_parts TRANSPORTING NO FIELDS WHERE type <> 'RPT'.
      lv_report_part_total += 1.
    ENDLOOP.

    " Declare request tables outside loop to avoid ABAP DATA stale-value accumulation
    DATA lt_request_tokens TYPE string_table.
    DATA lt_request_tasks  TYPE RANGE OF trkorr.
    DATA lt_request_trs    TYPE RANGE OF trkorr.

    LOOP AT mt_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      lv_report_part_idx += 1.
      IF lv_report_part_idx = 1 OR lv_report_part_idx = lv_report_part_total OR lv_report_part_idx MOD 5 = 0.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = CONV i( lv_report_part_idx * 100 / COND i( WHEN lv_report_part_total > 0 THEN lv_report_part_total ELSE 1 ) )
                    text       = CONV char70( |Code Review: summarizing parts ({ lv_report_part_idx }/{ lv_report_part_total }) { ls_part-object_name }| ).
      ENDIF.
      DATA(lv_objname_str) = CONV string( ls_part-object_name ).
      DATA(lv_part_key) = |{ ls_part-type }~{ lv_objname_str }|.
      DATA lv_part_authors TYPE string.
      DATA lv_part_task_count TYPE i.
      DATA lv_part_tr_count TYPE i.
      DATA lv_part_first_date TYPE versdate.
      DATA lv_part_last_date TYPE versdate.
      CLEAR: lv_part_authors, lv_part_task_count, lv_part_tr_count, lv_part_first_date, lv_part_last_date.
      lv_part_tr_count = ls_part-trs.

      IF lt_cr_task_objects IS NOT INITIAL.
        DATA lv_part_e071_type TYPE e071-object.
        DATA lv_part_e071_name TYPE e071-obj_name.
        lv_part_e071_type = SWITCH e071-object( ls_part-type
          WHEN 'REPS' OR 'REPT'                                THEN 'PROG'
          WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' THEN 'CLAS'
          ELSE ls_part-type ).
        lv_part_e071_name = ls_part-object_name.
        IF lv_part_e071_type = 'CLAS' AND ls_part-class IS NOT INITIAL.
          lv_part_e071_name = ls_part-class.
        ELSEIF lv_part_e071_type = 'CLAS' AND lv_part_e071_name CS '='.
          DATA(lv_part_eq) = find( val = CONV string( lv_part_e071_name ) sub = '=' ).
          IF lv_part_eq > 0.
            lv_part_e071_name = lv_part_e071_name(lv_part_eq).
          ENDIF.
        ENDIF.

        DATA lt_part_authors TYPE SORTED TABLE OF ty_cr_author_key WITH UNIQUE KEY author.
        DATA lt_part_tasks TYPE SORTED TABLE OF ty_cr_task_key WITH UNIQUE KEY trkorr.
        CLEAR: lt_part_authors, lt_part_tasks.
        LOOP AT lt_cr_task_objects INTO DATA(ls_cr_task_object).
          DATA(lv_touched) = xsdbool(
            ls_cr_task_object-object = lv_part_e071_type
            AND ls_cr_task_object-obj_name = lv_part_e071_name ).
          IF lv_touched = abap_false
             AND lv_part_e071_type = 'PROG'
             AND ls_cr_task_object-object = 'REPS'
             AND ls_cr_task_object-obj_name = lv_part_e071_name.
            lv_touched = abap_true.
          ENDIF.
          CHECK lv_touched = abap_true.

          INSERT VALUE #( trkorr = ls_cr_task_object-trkorr ) INTO TABLE lt_part_tasks.
          IF ls_cr_task_object-owner IS NOT INITIAL.
            INSERT VALUE #( author = ls_cr_task_object-owner ) INTO TABLE lt_part_authors.
          ENDIF.
          IF lv_part_first_date IS INITIAL OR ls_cr_task_object-datum < lv_part_first_date.
            lv_part_first_date = ls_cr_task_object-datum.
          ENDIF.
          IF lv_part_last_date IS INITIAL OR ls_cr_task_object-datum > lv_part_last_date.
            lv_part_last_date = ls_cr_task_object-datum.
          ENDIF.
        ENDLOOP.

        " Fallback: if no authors/tasks found via prepared release tasks, try direct E071/E070 lookup
        IF lt_part_authors IS INITIAL.
          DATA lt_tmp_tasks TYPE STANDARD TABLE OF ty_cr_rele_task WITH DEFAULT KEY.
          SELECT e071~trkorr AS trkorr, e070~as4user AS owner, e070~as4date AS datum, e070~as4time AS zeit
            FROM e071
            INNER JOIN e070 ON e070~trkorr = e071~trkorr
            WHERE e071~object = @lv_part_e071_type
              AND e071~obj_name = @lv_part_e071_name
              AND e070~trfunction = 'S'
            INTO TABLE @lt_tmp_tasks.
          IF lt_tmp_tasks IS NOT INITIAL.
            SORT lt_tmp_tasks BY datum DESCENDING zeit DESCENDING.
            LOOP AT lt_tmp_tasks INTO DATA(ls_tmp_task).
              INSERT VALUE #( trkorr = ls_tmp_task-trkorr ) INTO TABLE lt_part_tasks.
              IF ls_tmp_task-owner IS NOT INITIAL.
                INSERT VALUE #( author = ls_tmp_task-owner ) INTO TABLE lt_part_authors.
              ENDIF.
              IF lv_part_first_date IS INITIAL OR ls_tmp_task-datum < lv_part_first_date.
                lv_part_first_date = ls_tmp_task-datum.
              ENDIF.
              IF lv_part_last_date IS INITIAL OR ls_tmp_task-datum > lv_part_last_date.
                lv_part_last_date = ls_tmp_task-datum.
              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDIF.

        lv_part_task_count = lines( lt_part_tasks ).
        IF mv_object_type = zcl_ave_object_factory=>gc_type-tr
           AND lv_part_task_count > 0.
          lv_part_tr_count = 1.
        ELSEIF lv_part_tr_count = 0 AND lt_part_tasks IS NOT INITIAL.
          lv_part_tr_count = lines( lt_part_tasks ).
        ENDIF.
        IF lv_part_tr_count = 0 AND lv_part_task_count > 0.
          lv_part_tr_count = 1.
        ENDIF.
      ENDIF.

      IF ls_part-requests IS NOT INITIAL.
        CLEAR: lv_part_authors, lv_part_task_count, lv_part_tr_count,
               lv_part_first_date, lv_part_last_date,
               lt_request_tokens, lt_request_tasks, lt_request_trs.
        SPLIT ls_part-requests AT `,` INTO TABLE lt_request_tokens.
        LOOP AT lt_request_tokens ASSIGNING FIELD-SYMBOL(<request_token>).
          CONDENSE <request_token>.
          IF <request_token> IS NOT INITIAL.
            DATA(lv_request_task) = CONV trkorr( <request_token> ).
            INSERT VALUE #( sign = 'I' option = 'EQ' low = lv_request_task ) INTO TABLE lt_request_tasks.
            DATA(lv_request_tr) = lv_request_task.
            SELECT SINGLE strkorr FROM e070
              WHERE trkorr = @lv_request_tr
                AND trfunction = 'S'
              INTO @DATA(lv_request_parent_tr).
            IF sy-subrc = 0 AND lv_request_parent_tr IS NOT INITIAL.
              lv_request_tr = lv_request_parent_tr.
            ENDIF.
            INSERT VALUE #( sign = 'I' option = 'EQ' low = lv_request_tr ) INTO TABLE lt_request_trs.
          ENDIF.
        ENDLOOP.
        IF lt_request_tasks IS NOT INITIAL.
          lv_part_task_count = lines( lt_request_tasks ).
        ENDIF.
        IF mv_object_type = zcl_ave_object_factory=>gc_type-tr.
          IF lv_part_task_count > 0.
            lv_part_tr_count = 1.
          ENDIF.
        ELSE.
          IF lt_request_trs IS NOT INITIAL.
            lv_part_tr_count = lines( lt_request_trs ).
          ENDIF.
        ENDIF.

        IF lt_request_tasks IS NOT INITIAL.
          SELECT trkorr, as4user AS owner, as4date AS datum, as4time AS zeit
            FROM e070
            WHERE trkorr IN @lt_request_tasks
              AND trfunction = 'S'
            INTO TABLE @DATA(lt_request_info).
          LOOP AT lt_request_info INTO DATA(ls_req_info).
            IF ls_req_info-owner IS NOT INITIAL.
              INSERT VALUE #( author = ls_req_info-owner ) INTO TABLE lt_part_authors.
            ENDIF.
            IF lv_part_first_date IS INITIAL OR ls_req_info-datum < lv_part_first_date.
              lv_part_first_date = ls_req_info-datum.
            ENDIF.
            IF lv_part_last_date IS INITIAL OR ls_req_info-datum > lv_part_last_date.
              lv_part_last_date = ls_req_info-datum.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDIF.
      IF lv_part_tr_count = 0 AND lv_part_task_count > 0.
        lv_part_tr_count = 1.
      ENDIF.

      " Render author names from lt_part_authors (collected by both lookup paths above)
      LOOP AT lt_part_authors INTO DATA(ls_render_author).
        DATA(lv_render_author_name) = zcl_ave_popup_data=>get_user_name( ls_render_author-author ).
        IF lv_render_author_name IS INITIAL.
          lv_render_author_name = ls_render_author-author.
        ENDIF.
        IF lv_part_authors IS INITIAL.
          lv_part_authors = lv_render_author_name.
        ELSE.
          lv_part_authors = lv_part_authors && `, ` && lv_render_author_name.
        ENDIF.
      ENDLOOP.

      DATA lv_start_date TYPE string.
      DATA lv_finish_date TYPE string.
      DATA lv_days TYPE i.
      CLEAR: lv_start_date, lv_finish_date, lv_days.
      IF lv_part_first_date IS NOT INITIAL.
        lv_start_date = CONV string( lv_part_first_date ).
        lv_start_date = |{ lv_start_date+6(2) }.{ lv_start_date+4(2) }.{ lv_start_date+2(2) }|.
      ENDIF.
      IF lv_part_last_date IS NOT INITIAL.
        lv_finish_date = CONV string( lv_part_last_date ).
        lv_finish_date = |{ lv_finish_date+6(2) }.{ lv_finish_date+4(2) }.{ lv_finish_date+2(2) }|.
      ENDIF.
      IF lv_part_first_date IS NOT INITIAL AND lv_part_last_date IS NOT INITIAL.
        lv_days = lv_part_last_date - lv_part_first_date + 1.
      ENDIF.

      DATA(lv_tr_task_text) = |{ lv_part_tr_count }/{ lv_part_task_count }|.
      DATA(lv_tr_task_objname) = condense( val = lv_objname_str ).
      DATA(lv_tr_task_link) =
        |<a href="sapevent:trtasks~{ ls_part-type }~{ lv_tr_task_objname }"| &&
        | style="color:#2980b9;text-decoration:none;font-weight:bold">{ lv_tr_task_text }</a>|.

      DATA(lv_part_supported) = zcl_ave_popup_data=>is_supported_object_type( ls_part-type ).

      " Resolve TADIR key for this part (same logic as pre-loop scan)
      DATA(lv_row_tadir_object) = SWITCH tadir-object( ls_part-type
        WHEN 'REPS' OR 'REPT'                                THEN 'PROG'
        WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI'
          OR 'METH' OR 'CDEF'                                THEN 'CLAS'
        ELSE ls_part-type ).
      DATA(lv_row_tadir_name) = CONV tadir-obj_name( ls_part-object_name ).
      IF lv_row_tadir_object = 'CLAS' AND ls_part-class IS NOT INITIAL.
        lv_row_tadir_name = ls_part-class.
      ELSEIF lv_row_tadir_object = 'CLAS' AND lv_row_tadir_name CS '='.
        DATA(lv_row_eq) = find( val = CONV string( lv_row_tadir_name ) sub = '=' ).
        IF lv_row_eq > 0.
          lv_row_tadir_name = lv_row_tadir_name(lv_row_eq).
        ENDIF.
      ENDIF.
      DATA(lv_row_tadir_pgmid) = CONV tadir-pgmid( 'R3TR' ).
      READ TABLE lt_cr_task_objects INTO DATA(ls_row_e071)
        WITH KEY object = lv_row_tadir_object obj_name = lv_row_tadir_name.
      IF sy-subrc = 0.
        lv_row_tadir_pgmid = ls_row_e071-pgmid.
      ENDIF.

      " Check delflag from pre-fetched TADIR data
      DATA(lv_part_deleted) = abap_false.
      READ TABLE lt_tadir_delflags INTO DATA(ls_tadir_row)
        WITH KEY pgmid = lv_row_tadir_pgmid object = lv_row_tadir_object obj_name = lv_row_tadir_name.
      IF sy-subrc = 0 AND ls_tadir_row-delflag = abap_true.
        lv_part_deleted = abap_true.
      ENDIF.

      DATA(lv_part_type_style) = COND string(
        WHEN lv_part_supported = abap_true THEN ``
        ELSE ` style="color:#8a8f98;font-weight:normal"` ).
      DATA(lv_part_object_cell) = COND string(
        WHEN lv_part_supported = abap_true
        THEN |<td><b>{ escape( val = condense( val = lv_objname_str ) format = cl_abap_format=>e_html_text ) }</b></td>|
        ELSE |<td style="color:#8a8f98;font-weight:normal">{ escape( val = condense( val = lv_objname_str ) format = cl_abap_format=>e_html_text ) }</td>| ).

      DATA(lv_has_saved_stat) = zcl_ave_acr_overview=>has_saved_stat(
        is_part      = ls_part
        it_obj_stats = ls_saved_payload_check-obj_stats ).

      " Row class priority: deleted > skip
      DATA(lv_row_class) = COND string(
        WHEN lv_part_deleted = abap_true
        THEN ` class="deleted"`
        WHEN lv_has_saved_review = abap_true AND lv_has_saved_stat = abap_false
        THEN ` class="skip"`
        ELSE `` ).

      result = result &&
        |<tr{ lv_row_class }>| &&
        |<td{ lv_part_type_style }>{ escape( val = CONV string( ls_part-type ) format = cl_abap_format=>e_html_text ) }</td>| &&
        lv_part_object_cell &&
        |<td>{ escape( val = CONV string( ls_part-class ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = CONV string( ls_part-type_text ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = lv_part_authors format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td class="nr">{ lv_tr_task_link }</td>| &&
        |<td>{ lv_start_date }</td>| &&
        |<td>{ lv_finish_date }</td>| &&
        |<td class="nr">{ lv_days }</td>| &&
        |<td class="nr">{ ls_part-rows }</td>| &&
        |</tr>|.
    ENDLOOP.

    DATA(lv_obj_count) = lines( mt_parts ).
    IF line_exists( mt_parts[ type = 'RPT' ] ).
      lv_obj_count = lv_obj_count - 1.
    ENDIF.
    IF lv_obj_count = 0.
      result = result &&
        |<tr><td colspan="9" class="muted">No changed objects found.</td></tr>|.
    ENDIF.

    result = result && |</table></body></html>|.
  ENDMETHOD.


  METHOD prepare_code_review.
    CHECK mv_code_review = abap_true.

    IF mv_object_type = zcl_ave_object_factory=>gc_type-tr
       AND mt_parts_backup IS NOT INITIAL.
      mt_parts = mt_parts_backup.
      CLEAR mt_parts_backup.
      CLEAR mv_drilled_class.
    ENDIF.

    DATA(lv_selected_only) = xsdbool( iv_keys IS NOT INITIAL AND iv_keys <> `0` ).
    DATA lt_selected_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    IF lv_selected_only = abap_true.
      SPLIT iv_keys AT `;` INTO TABLE DATA(lt_selected_raw).
      LOOP AT lt_selected_raw INTO DATA(lv_selected_raw).
        CHECK lv_selected_raw IS NOT INITIAL.
        INSERT lv_selected_raw INTO TABLE lt_selected_keys.
      ENDLOOP.
    ENDIF.

    CLEAR: mv_cr_base_html, mv_cr_cur_key, mv_decline_view_user.
    IF lv_selected_only = abap_true.
      CLEAR: mt_acr_stats, mt_hunk_info, mt_hunk_threads, mt_diff_cache, mt_cr_diag,
             mt_approved, mt_declined, mt_decline_notes.
      load_review_from_db( ).
    ELSE.
      CLEAR: mt_acr_stats, mt_hunk_info, mt_hunk_threads, mt_diff_cache, mt_cr_diag,
             mt_approved, mt_declined, mt_decline_notes.
    ENDIF.

    mv_cr_prepared = abap_true.
    maximize_html( ).

    DATA lv_total TYPE i.
    DATA lv_part_count TYPE i.
    LOOP AT mt_parts INTO DATA(ls_count_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_count_part-type ) = abap_false.
        CONTINUE.
      ENDIF.
      lv_part_count += 1.
    ENDLOOP.
    add_cr_diag( |PREPARE { mv_object_name }: parts={ lv_part_count }, selected_only={ lv_selected_only }, selected_keys={ lines( lt_selected_keys ) }| ).

    IF lv_selected_only = abap_true.
      LOOP AT lt_selected_keys INTO DATA(lv_diag_selected_key).
        DATA(lv_diag_key_found) = abap_false.
        LOOP AT mt_parts INTO DATA(ls_diag_part_check) WHERE type <> 'RPT'.
          IF lv_diag_selected_key = |{ ls_diag_part_check-type }~{ ls_diag_part_check-object_name }|.
            lv_diag_key_found = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_diag_key_found = abap_false.
          add_cr_diag( |SELECTED KEY { lv_diag_selected_key }: not found in current parts list| ).
        ENDIF.
      ENDLOOP.
    ENDIF.

    LOOP AT mt_parts INTO DATA(ls_total_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_total_part-type ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA(lv_total_key) = |{ ls_total_part-type }~{ ls_total_part-object_name }|.
      IF lv_selected_only = abap_true
         AND NOT line_exists( lt_selected_keys[ table_line = lv_total_key ] ).
        CONTINUE.
      ENDIF.
      lv_total += 1.
    ENDLOOP.
    DATA lv_done TYPE i.

    LOOP AT mt_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_part-type ) = abap_false.
        add_cr_diag( |SKIP { ls_part-type } { ls_part-object_name }: unsupported object type| ).
        CONTINUE.
      ENDIF.
      DATA(lv_part_key) = |{ ls_part-type }~{ ls_part-object_name }|.
      IF lv_selected_only = abap_true
         AND NOT line_exists( lt_selected_keys[ table_line = lv_part_key ] ).
        add_cr_diag( |SKIP { ls_part-type } { ls_part-object_name }: not selected| ).
        CONTINUE.
      ENDIF.
      lv_done += 1.
      add_cr_diag( |DISPATCH { ls_part-type } { ls_part-object_name }: class={ ls_part-class }, name={ ls_part-name }, rows={ ls_part-rows }| ).
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = CONV i( lv_done * 100 / COND i( WHEN lv_total > 0 THEN lv_total ELSE 1 ) )
                  text       = CONV char70( |Code Review: preparing { ls_part-object_name }| ).
      IF ls_part-type = 'CLAS'.
        add_cr_diag( |DISPATCH CLAS { ls_part-object_name }: expand class parts| ).
        DELETE mt_acr_stats WHERE class_name = ls_part-object_name.
        DELETE mt_hunk_info WHERE class_name = ls_part-object_name.
        DELETE mt_diff_cache WHERE key-objname = ls_part-object_name.
        cr_precompute_class_parts( CONV #( ls_part-object_name ) ).
      ELSE.
        add_cr_diag( |DISPATCH { ls_part-type } { ls_part-object_name }: precompute direct part| ).
        DELETE mt_acr_stats WHERE objtype = ls_part-type AND obj_name = ls_part-object_name.
        DELETE mt_hunk_info WHERE objtype = ls_part-type AND obj_name = ls_part-object_name.
        DELETE mt_diff_cache WHERE key-objtype = ls_part-type AND key-objname = ls_part-object_name.
        cr_precompute_part( ls_part ).
      ENDIF.

      sanitize_review_state( ).
      DATA lt_report_approved TYPE zif_ave_acr_types=>ty_approved.
      DATA lt_report_declined TYPE zif_ave_acr_types=>ty_approved.
      collect_report_status(
        IMPORTING
          et_approved = lt_report_approved
          et_declined = lt_report_declined ).
      mv_cr_report_html = zcl_ave_acr_report=>to_html(
        it_obj_stats = mt_acr_stats
        it_approved  = lt_report_approved
        it_declined  = lt_report_declined
        it_reviewers = get_reviewer_stats( )
        i_korrnum    = CONV #( mv_object_name ) ).
      mv_cr_report_html = add_cr_diagnostics( mv_cr_report_html ).
      mv_cr_report_html = add_cr_report_toolbar( mv_cr_report_html ).
      set_html( mv_cr_report_html ).
      cl_gui_cfw=>flush( EXCEPTIONS OTHERS = 1 ).
    ENDLOOP.

    load_review_from_db( ).
    regen_acr_report( ).
    refresh_rpt_row( ).
    save_review_to_db( iv_silent = abap_true ).
    set_html( mv_cr_report_html ).
  ENDMETHOD.


  METHOD delete_and_recalc_selected.
    CHECK mv_code_review = abap_true.
    CHECK iv_keys IS NOT INITIAL.

    IF iv_keys = `0`.
      add_cr_diag( |RECALC all selected: short all-marker received| ).
      IF has_review_table( ) = abap_true.
        DATA(lv_tabname_all_del) = CONV tabname( 'ZAVE_REVIEW' ).
        DATA(lv_trkorr_all_del) = CONV trkorr( mv_object_name ).
        TRY.
            DELETE FROM (lv_tabname_all_del) WHERE trkorr = @lv_trkorr_all_del.
          CATCH cx_sy_dynamic_osql_semantics
                cx_sy_dynamic_osql_syntax
                cx_sy_open_sql_db.
        ENDTRY.
      ENDIF.
      CLEAR: mt_acr_stats, mt_hunk_info, mt_hunk_threads, mt_diff_cache,
             mt_approved, mt_declined, mt_decline_notes, mt_hunk_actions.
      prepare_code_review( ).
      RETURN.
    ENDIF.

    DATA lt_selected_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    SPLIT iv_keys AT `;` INTO TABLE DATA(lt_selected_raw).
    LOOP AT lt_selected_raw INTO DATA(lv_selected_raw).
      CHECK lv_selected_raw IS NOT INITIAL.
      INSERT lv_selected_raw INTO TABLE lt_selected_keys.
    ENDLOOP.

    DATA(lv_selectable_count) = 0.
    DATA(lv_all_selected) = abap_true.
    LOOP AT mt_parts INTO DATA(ls_part_all_check) WHERE type <> 'RPT'.
      lv_selectable_count += 1.
      DATA(lv_part_all_key) = |{ ls_part_all_check-type }~{ ls_part_all_check-object_name }|.
      IF NOT line_exists( lt_selected_keys[ table_line = lv_part_all_key ] ).
        lv_all_selected = abap_false.
      ENDIF.
    ENDLOOP.

    IF lv_selectable_count > 0
       AND lv_all_selected = abap_true
       AND lines( lt_selected_keys ) >= lv_selectable_count.
      add_cr_diag( |RECALC all selected: deleting saved review, then preparing explicit selected keys={ lines( lt_selected_keys ) }| ).
      IF has_review_table( ) = abap_true.
        DATA(lv_tabname_del) = CONV tabname( 'ZAVE_REVIEW' ).
        DATA(lv_trkorr_del) = CONV trkorr( mv_object_name ).
        TRY.
            DELETE FROM (lv_tabname_del) WHERE trkorr = @lv_trkorr_del.
          CATCH cx_sy_dynamic_osql_semantics
                cx_sy_dynamic_osql_syntax
                cx_sy_open_sql_db.
        ENDTRY.
      ENDIF.
      CLEAR: mt_acr_stats, mt_hunk_info, mt_hunk_threads, mt_diff_cache,
             mt_approved, mt_declined, mt_decline_notes, mt_hunk_actions.
      prepare_code_review( iv_keys = iv_keys ).
      RETURN.
    ENDIF.

    load_review_from_db( ).

    LOOP AT mt_parts INTO DATA(ls_part_stat) WHERE type <> 'RPT'.
      DATA(lv_part_stat_key) = |{ ls_part_stat-type }~{ ls_part_stat-object_name }|.
      CHECK line_exists( lt_selected_keys[ table_line = lv_part_stat_key ] ).
      IF ls_part_stat-type = 'CLAS'.
        DELETE mt_acr_stats WHERE class_name = ls_part_stat-object_name.
      ELSE.
        DELETE mt_acr_stats WHERE objtype = ls_part_stat-type AND obj_name = ls_part_stat-object_name.
      ENDIF.
    ENDLOOP.

    DATA lt_hunk_keys_to_delete TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT mt_hunk_info INTO DATA(ls_hunk_to_check).
      LOOP AT mt_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
        DATA(lv_part_key) = |{ ls_part-type }~{ ls_part-object_name }|.
        IF NOT line_exists( lt_selected_keys[ table_line = lv_part_key ] ).
          CONTINUE.
        ENDIF.
        IF ls_part-type = 'CLAS'.
          IF ls_hunk_to_check-class_name = ls_part-object_name.
            INSERT ls_hunk_to_check-hunk_key INTO TABLE lt_hunk_keys_to_delete.
          ENDIF.
        ELSE.
          IF ls_hunk_to_check-objtype = ls_part-type AND ls_hunk_to_check-obj_name = ls_part-object_name.
            INSERT ls_hunk_to_check-hunk_key INTO TABLE lt_hunk_keys_to_delete.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    LOOP AT lt_hunk_keys_to_delete INTO DATA(lv_hunk_key).
      DELETE TABLE mt_approved FROM lv_hunk_key.
      DELETE TABLE mt_declined FROM lv_hunk_key.
      DELETE mt_hunk_info WHERE hunk_key = lv_hunk_key.
      DELETE mt_decline_notes WHERE hunk_key = lv_hunk_key.
      DELETE mt_hunk_threads WHERE hunk_key = lv_hunk_key.
      DELETE mt_hunk_actions WHERE hunk_key = lv_hunk_key.
    ENDLOOP.

    LOOP AT mt_parts INTO DATA(ls_part_clean) WHERE type <> 'RPT'.
      DATA(lv_part_clean_key) = |{ ls_part_clean-type }~{ ls_part_clean-object_name }|.
      CHECK line_exists( lt_selected_keys[ table_line = lv_part_clean_key ] ).
      IF ls_part_clean-type = 'CLAS'.
        DELETE mt_diff_cache WHERE key-objname = ls_part_clean-object_name.
      ELSE.
        DELETE mt_diff_cache WHERE key-objtype = ls_part_clean-type AND key-objname = ls_part_clean-object_name.
      ENDIF.
    ENDLOOP.

    sanitize_review_state( ).
    save_review_to_db( iv_silent = abap_true ).
    prepare_code_review( iv_keys = iv_keys ).
  ENDMETHOD.


  METHOD show_recalc_picker.
    IF mv_object_type = zcl_ave_object_factory=>gc_type-tr
       AND mt_parts_backup IS NOT INITIAL.
      mt_parts = mt_parts_backup.
      CLEAR mt_parts_backup.
      CLEAR mv_drilled_class.
      refresh_parts( ).
    ENDIF.

    DATA(ls_payload) = VALUE ty_saved_payload( ).
    DATA(lv_has_payload) = load_review_payload(
      EXPORTING iv_trkorr = CONV #( mv_object_name )
      IMPORTING es_payload = ls_payload ).
    DATA(lv_picker_title) = COND string(
      WHEN lv_has_payload = abap_true THEN `Recalc Diff`
      ELSE `Prepare Code Review` ).
    DATA(lv_primary_label) = COND string(
      WHEN lv_has_payload = abap_true THEN `Recalc Selected`
      ELSE `Prepare Selected` ).
    DATA(lv_delete_button) = COND string(
      WHEN lv_has_payload = abap_true
      THEN `&nbsp;<a class="go" style="background:#e74c3c" href="#" onclick="return del_recalc()">Delete and recalc</a>`
      ELSE `` ).

    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `table{border-collapse:collapse;width:100%;margin-bottom:16px;font-size:12px}` &&
      `th{background:#3498db;color:#fff;padding:5px 10px;text-align:left;white-space:nowrap}` &&
      `td{padding:4px 10px;border-bottom:1px solid #eee;white-space:nowrap}` &&
      `.go{display:inline-block;background:#7f8c8d;color:#fff;text-decoration:none;` &&
      `font:bold 13px Consolas,monospace;border-radius:4px;padding:7px 20px}` &&
      `.back{position:fixed;top:8px;left:8px;z-index:999;background:#3498db;color:#fff;text-decoration:none;` &&
      `font:bold 13px Consolas,monospace;border-radius:4px;padding:7px 14px}` &&
      `.clear{display:inline-block;background:#95a5a6;color:#fff;text-decoration:none;` &&
      `font:bold 13px Consolas,monospace;border-radius:4px;padding:7px 14px;margin-left:8px}` &&
      `.new{color:#27ae60;font-weight:bold}.cached{color:#777}`.

    DATA(lv_html) =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ lv_css }</style>| &&
      `<script>` &&
      `function go(){var xs=document.querySelectorAll('input[name=o]:checked');` &&
      `var all=document.querySelectorAll('input[name=o]');` &&
      `var a=[];for(var i=0;i<xs.length;i++){a.push(xs[i].value);}` &&
      `if(a.length==0){alert('Select at least one object');return false;}` &&
      `if(a.length==all.length){location.href='sapevent:prepare_selected~0';return false;}` &&
      `location.href='sapevent:prepare_selected~'+a.join(';');return false;}` &&
      `function del_recalc(){var xs=document.querySelectorAll('input[name=o]:checked');` &&
      `var all=document.querySelectorAll('input[name=o]');` &&
      `var a=[];for(var i=0;i<xs.length;i++){a.push(xs[i].value);}` &&
      `if(a.length==0){alert('Select at least one object');return false;}` &&
      `if(a.length==all.length){location.href='sapevent:delete_recalc~0';return false;}` &&
      `location.href='sapevent:delete_recalc~'+a.join(';');return false;}` &&
      `function allc(v){var xs=document.querySelectorAll('input[name=o]');` &&
      `for(var i=0;i<xs.length;i++){xs[i].checked=v;}}` &&
      `</script></head><body>` &&
      |<h2>{ lv_picker_title } - { escape( val = CONV string( mv_object_name ) format = cl_abap_format=>e_html_text ) }</h2>| &&
      |<p><a class="go" href="#" onclick="return go()">{ lv_primary_label }</a>| &&
      lv_delete_button &&
      `<a class="back" href="sapevent:back~0">Back</a>` &&
      `<a class="clear" href="#" onclick="allc(false);return false">Clear Selected</a>` &&
      `&nbsp;&nbsp;<a href="#" onclick="allc(true);return false">Select all</a>` &&
      `</p>` &&
      `<table><tr><th></th><th>Type</th><th>Object</th><th>Class</th><th>Status</th><th class="nr">Rows</th></tr>`.

    LOOP AT mt_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_part-type ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA(lv_key) = |{ ls_part-type }~{ ls_part-object_name }|.
      DATA(lv_cached) = abap_false.
      IF lv_has_payload = abap_true.
        READ TABLE ls_payload-obj_stats TRANSPORTING NO FIELDS
          WITH KEY objtype = ls_part-type obj_name = ls_part-object_name.
        lv_cached = xsdbool( sy-subrc = 0 ).
      ENDIF.
      DATA(lv_status) = COND string(
        WHEN lv_cached = abap_true THEN `<span class="cached">cached</span>`
        ELSE `<span class="new">new</span>` ).
      DATA(lv_part_rows) = ls_part-rows.
      IF lv_part_rows = 0.
        lv_part_rows = zcl_ave_popup_data=>get_active_line_count(
          i_type = ls_part-type
          i_name = ls_part-object_name ).
      ENDIF.
      lv_html = lv_html &&
        `<tr>` &&
        |<td><input type="checkbox" name="o" checked value="{ escape( val = lv_key format = cl_abap_format=>e_html_attr ) }"></td>| &&
        |<td>{ escape( val = CONV string( ls_part-type ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td><b>{ escape( val = CONV string( ls_part-object_name ) format = cl_abap_format=>e_html_text ) }</b></td>| &&
        |<td>{ escape( val = CONV string( ls_part-class ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ lv_status }</td>| &&
        |<td class="nr">{ lv_part_rows }</td>| &&
        `</tr>`.
    ENDLOOP.

    lv_html = lv_html && `</table></body></html>`.
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD open_saved_code_review.
    result = abap_false.
    CHECK mv_code_review = abap_true.
    CHECK mv_object_type = zcl_ave_object_factory=>gc_type-tr.
    CHECK has_review_table( ) = abap_true.

    DATA(ls_payload) = VALUE ty_saved_payload( ).
    CHECK load_review_payload(
      EXPORTING iv_trkorr = CONV #( mv_object_name )
      IMPORTING es_payload = ls_payload ) = abap_true.
    CHECK ls_payload-obj_stats IS NOT INITIAL.
    CHECK ls_payload-hunks IS NOT INITIAL.
    CHECK ls_payload-diff_cache IS NOT INITIAL.

    CLEAR: mt_acr_stats, mt_hunk_info, mt_hunk_threads, mt_diff_cache,
           mt_approved, mt_declined, mt_decline_notes,
           mv_cr_base_html, mv_cr_cur_key, mv_decline_view_user,
           mv_reviewer_view.

    mt_acr_stats = ls_payload-obj_stats.
    mt_hunk_info = ls_payload-hunks.
    mt_diff_cache = ls_payload-diff_cache.
    mv_cr_prepared = abap_true.

    load_review_from_db( ).
    regen_acr_report( ).
    refresh_rpt_row( ).
    maximize_html( ).
    set_html( mv_cr_report_html ).
    result = abap_true.
  ENDMETHOD.


  METHOD refresh_rpt_row.
    DATA(lv_approved) = lines( mt_approved ).
    DATA(lv_obj_count) = lines( mt_parts ).
    IF line_exists( mt_parts[ type = 'RPT' ] ).
      lv_obj_count = lv_obj_count - 1.
    ENDIF.
    DATA(lv_name) = COND string(
      WHEN mv_cr_prepared = abap_true
      THEN |[ Code Review Report - { lv_approved } hunk(s) approved ]|
      ELSE |[ Code Review Report - { lv_obj_count } object(s) ]| ).
    LOOP AT mt_parts ASSIGNING FIELD-SYMBOL(<rpt>) WHERE type = 'RPT'.
      <rpt>-name = lv_name.
      EXIT.
    ENDLOOP.
    refresh_parts( ).
  ENDMETHOD.


  METHOD is_comments_only.
    result = abap_true.
    LOOP AT it_src INTO DATA(ls_line).
      DATA(lv_trimmed) = condense( CONV string( ls_line ) ).
      CHECK lv_trimmed IS NOT INITIAL.
      IF lv_trimmed(1) <> '*'.
        result = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
