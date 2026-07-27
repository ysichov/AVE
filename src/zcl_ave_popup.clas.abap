CLASS zcl_ave_popup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  GLOBAL FRIENDS zcl_ave_acr_workflow
          zcl_ave_acr_command .

  PUBLIC SECTION.

    DATA mv_desination TYPE text255 .
    DATA mv_model TYPE text255 .
    DATA mv_apikey TYPE text255 .
    DATA mv_provider TYPE string VALUE 'ANTHROPIC' .

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
    TYPES ty_t_diff_cache TYPE zif_ave_acr_types=>ty_t_diff_cache .
    TYPES ty_t_diff_data TYPE zif_ave_acr_types=>ty_t_diff_data .
    TYPES:
      BEGIN OF ty_diff_render_key,
        objtype     TYPE versobjtyp,
        objname     TYPE versobjnam,
        system_o    TYPE verssysnam,
        system_n    TYPE verssysnam,
        versno_o    TYPE versno,
        versno_n    TYPE versno,
        blame         TYPE abap_bool,
        ignore_case   TYPE abap_bool,
        ignore_indent TYPE abap_bool,
      END OF ty_diff_render_key .
    TYPES:
      BEGIN OF ty_diff_render_cache,
        key           TYPE ty_diff_render_key,
        diff          TYPE ty_t_diff,
        blame         TYPE ty_blame_map,
        blame_deleted TYPE ty_blame_map,
        huge_source   TYPE abap_bool,
        title         TYPE string,
        meta          TYPE string,
        "! Prebuilt HTML for renderers that don't rebuild from DIFF (e.g. TABD).
        prebuilt_html TYPE string,
      END OF ty_diff_render_cache .
    TYPES ty_t_diff_render_cache TYPE HASHED TABLE OF ty_diff_render_cache WITH UNIQUE KEY key .
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
    DATA ms_load_new TYPE ty_version_row .   " pair endpoint from version_list=>load (scope-aware, ToC-excluded)
    DATA ms_load_old TYPE ty_version_row .   " baseline from version_list=>load
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
    "! Case- and indent-insensitivity are a single user option (one selection-screen
    "! checkbox, one toolbar toggle) — the ignore-indent post-pass in COMPUTE_DIFF
    "! folds case as well, so the two always move together. Kept as two fields
    "! because the diff caches and several helpers are keyed on them separately.
    DATA mv_ignore_case   TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_ignore_indent TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_task_view TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_diff_prev TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_refreshing TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_debug TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_last_html TYPE string .
  "! When drilled into a class from a TR parts view, holds the class name so
  "! Refresh reloads only that class (not the outer TR).
    DATA mv_drilled_class TYPE seoclsname .
  "! When drilled into a function group from a TR parts view, holds the group
  "! name so Refresh reloads only that group (not the outer TR).
    DATA mv_drilled_fugr TYPE rs38l_area .
    DATA mv_filter_user TYPE versuser .
    DATA mv_filter_korrnum TYPE trkorr .
    DATA mt_filter_korrnums TYPE zif_ave_object=>ty_t_korr_range .
    "! Requests exactly as entered on the selection screen (before any S-task
    "! expansion). Object reading for a TR must use these — asking for a K means
    "! only that K, not its S-tasks.
    DATA mt_entered_korrnums TYPE zif_ave_object=>ty_t_korr_range .
    "! "Include Tasks": read the objects of the S-tasks belonging to the entered
    "! requests as well. A request header only carries what was recorded directly
    "! on it, so an unreleased K is usually empty while its tasks hold everything.
    DATA mv_include_tasks TYPE abap_bool .
    DATA mt_filter_parent_korrnums TYPE zif_ave_object=>ty_t_korr_range .
    DATA mv_oldest_filter_korrnum TYPE trkorr .
    DATA mv_date_from TYPE versdate .
    DATA mv_viewed_versno TYPE versno .
    " Backup for Back navigation (one level)
    DATA mt_parts_backup TYPE ty_t_part_row .
    DATA mt_diff_cache TYPE ty_t_diff_cache .
    DATA mt_diff_data TYPE ty_t_diff_data .
    DATA mt_diff_render_cache TYPE ty_t_diff_render_cache .
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
    DATA mv_moving_view TYPE abap_bool .
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
    METHODS add_moving_violations_link
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
    METHODS show_moving_violations .
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
    METHODS do_askai
    IMPORTING
      !iv_hunk_key TYPE string .
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
    METHODS build_view_hunks
    IMPORTING
      !it_hunk_info TYPE ty_t_hunk_info
    RETURNING
      VALUE(result) TYPE ty_t_hunk_info .
    "──────────── logic ─────────────────────────────────────────────
    METHODS get_class_parts
    IMPORTING
      !i_name TYPE versobjnam
    RETURNING
      VALUE(result) TYPE ty_t_part_row
    RAISING
      zcx_ave .
    "! Expands a function group into its include part rows (SAPL* main +
    "! L* sub-includes). New, FUGR-only — mirrors get_class_parts loosely.
    METHODS get_fugr_parts
    IMPORTING
      !i_name TYPE rs38l_area
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
    METHODS render_cached_diff
    IMPORTING
      !is_cache TYPE ty_diff_render_cache
    RETURNING
      VALUE(result) TYPE string .
  "! Auto-open guard: if is_new source exceeds 1000 lines, show source only;
  "! user can manually trigger a diff from the version list.
    METHODS auto_show_diff_or_source
    IMPORTING
      !is_old TYPE ty_version_row
      !is_new TYPE ty_version_row .
    METHODS set_html
    IMPORTING
      !iv_html  TYPE string
      !iv_focus TYPE abap_bool DEFAULT abap_false .
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
    METHODS sanitize_review_state .
    METHODS collect_report_status
    EXPORTING
      !et_approved TYPE zif_ave_acr_types=>ty_approved
      !et_declined TYPE zif_ave_acr_types=>ty_approved .
    METHODS get_reviewer_stats
    RETURNING
      VALUE(result) TYPE zif_ave_acr_types=>ty_t_reviewer_stats .
    METHODS show_review_help_popup .
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
    METHODS is_ai_enabled
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS get_cr_precompute_options
    RETURNING
      VALUE(result) TYPE zcl_ave_acr_precompute=>ty_options .
    METHODS call_cr_precompute_part
    IMPORTING
      !is_part TYPE ty_part_row .
    METHODS call_cr_precompute_class_parts
    IMPORTING
      !iv_class_name TYPE seoclsname
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS call_cr_precompute_fugr_parts
    IMPORTING
      !iv_fugr_name TYPE rs38l_area
    RETURNING
      VALUE(result) TYPE abap_bool .
ENDCLASS.



CLASS ZCL_AVE_POPUP IMPLEMENTATION.


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


  METHOD is_ai_enabled.
    result = zcl_ave_acr_ai=>is_enabled(
      iv_destination = mv_desination
      iv_model       = mv_model
      iv_apikey      = mv_apikey ).
  ENDMETHOD.


  METHOD get_cr_precompute_options.
    result = VALUE zcl_ave_acr_precompute=>ty_options(
      date_from              = mv_date_from
      remove_dup             = mv_remove_dup
      no_toc                 = mv_no_toc
      ignore_case            = mv_ignore_case
      ignore_indent          = mv_ignore_indent
      filter_korrnum         = mv_filter_korrnum
      filter_korrnums        = mt_filter_korrnums
      filter_parent_korrnums = mt_filter_parent_korrnums
      system                 = mv_system
      filter_user            = mv_filter_user
      blame                  = mv_blame
      two_pane               = mv_two_pane
      compact                = mv_compact
      debug                  = mv_debug ).
  ENDMETHOD.


  METHOD call_cr_precompute_part.
    zcl_ave_acr_precompute=>precompute_part(
      EXPORTING
        is_part    = is_part
        is_options = get_cr_precompute_options( )
      CHANGING
        ct_versions   = mt_versions
        ct_acr_stats  = mt_acr_stats
        ct_hunk_info  = mt_hunk_info
        ct_diff_cache = mt_diff_cache
        ct_diff_data  = mt_diff_data
        ct_cr_diag    = mt_cr_diag ).
  ENDMETHOD.


  METHOD call_cr_precompute_class_parts.
    result = zcl_ave_acr_precompute=>precompute_class_parts(
      EXPORTING
        iv_class_name = iv_class_name
        is_options    = get_cr_precompute_options( )
      CHANGING
        ct_versions   = mt_versions
        ct_acr_stats  = mt_acr_stats
        ct_hunk_info  = mt_hunk_info
        ct_diff_cache = mt_diff_cache
        ct_diff_data  = mt_diff_data
        ct_cr_diag    = mt_cr_diag ).
  ENDMETHOD.


  METHOD call_cr_precompute_fugr_parts.
    result = zcl_ave_acr_precompute=>precompute_fugr_parts(
      EXPORTING
        iv_fugr_name = iv_fugr_name
        is_options   = get_cr_precompute_options( )
      CHANGING
        ct_versions   = mt_versions
        ct_acr_stats  = mt_acr_stats
        ct_hunk_info  = mt_hunk_info
        ct_diff_cache = mt_diff_cache
        ct_diff_data  = mt_diff_data
        ct_cr_diag    = mt_cr_diag ).
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
      mv_ignore_indent  = is_settings-ignore_indent.
      mv_filter_user    = is_settings-filter_user.
      mv_date_from      = is_settings-date_from.
      mv_code_review    = is_settings-code_review.
      mv_system         = is_settings-system.
      mv_filter_korrnum = is_settings-filter_korrnum.
      mt_filter_korrnums = is_settings-filter_korrnums.
      mv_include_tasks  = is_settings-include_tasks.
      mv_desination = is_settings-destination.
      mv_model = is_settings-model.
      mv_apikey = is_settings-apikey.
      mv_provider = COND #( WHEN is_settings-provider IS INITIAL THEN 'ANTHROPIC' ELSE is_settings-provider ).
      TRANSLATE mv_provider TO UPPER CASE.
    ENDIF.

    IF mt_filter_korrnums IS INITIAL AND mv_filter_korrnum IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = mv_filter_korrnum ) TO mt_filter_korrnums.
    ENDIF.

    " Remember the requests exactly as entered, before S-task expansion below
    " replaces mt_filter_korrnums. Object reading must use only what was asked.
    mt_entered_korrnums = mt_filter_korrnums.

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

        " A K carries both S (development) and R (repair) children — both are
        " authoring tasks and both must be in scope, otherwise versions recorded
        " under an R are invisible and no later task matching can recover them.
        IF lv_filter_trfunction = 'S' OR lv_filter_trfunction = 'R'.
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
              AND trfunction IN ( 'S', 'R' )
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
       AND mv_object_type <> zcl_ave_object_factory=>gc_type-package
       AND mv_object_type <> zcl_ave_object_factory=>gc_type-fugr.
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
        ELSEIF mv_object_type = zcl_ave_object_factory=>gc_type-fugr.
          " FUGR: show a single function-group row. Double-click expands it into
          " its includes via the same drill-in used when a FUGR comes from a TR.
          " Existence is validated against TADIR (R3TR FUGR).
          DATA(lv_fugr_exists) = zcl_ave_popup_data=>check_part_exists(
            i_type = 'FUGR'
            i_name = CONV #( mv_object_name ) ).
          mt_parts = VALUE #( (
            type         = 'FUGR'
            name         = CONV #( mv_object_name )
            display_name = CONV #( mv_object_name )
            type_text    = zcl_ave_popup_data=>get_type_text( 'FUGR' )
            object_name  = CONV #( mv_object_name )
            exists_flag  = lv_fugr_exists
            rowcolor     = COND #( WHEN lv_fugr_exists = abap_false THEN 'C601' ) ) ).
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
          " Read objects from the requests exactly as entered (mt_entered_korrnums),
          " NOT from the S-tasks that mt_filter_korrnums was expanded into: asking for
          " a K means only that K. Objects recorded directly on the K (not in any
          " S-task) would otherwise be lost. The expanded list stays untouched for
          " later version filtering.
          DATA lt_child_task_korrs TYPE STANDARD TABLE OF trkorr WITH DEFAULT KEY.
          IF lv_is_tr = abap_true AND mt_entered_korrnums IS NOT INITIAL.
            LOOP AT mt_entered_korrnums INTO DATA(ls_part_korrnum)
              WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
              APPEND ls_part_korrnum-low TO lt_korr_parts.
              " "Include Tasks": a request header only holds the objects recorded
              " directly on it — for an unreleased K that is usually nothing, while
              " the developers' objects sit on its S-tasks. Read those too.
              IF mv_include_tasks = abap_true.
                SELECT trkorr FROM e070
                  WHERE strkorr = @ls_part_korrnum-low
                    AND trfunction IN ( 'S', 'R' )
                  INTO TABLE @lt_child_task_korrs.
                APPEND LINES OF lt_child_task_korrs TO lt_korr_parts.
              ENDIF.
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
                    AND trfunction IN ( 'S', 'R' )
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
            DATA(lv_row_display_unit) = ls_raw-unit.
            IF ls_raw-type = 'METH' AND lv_row_display_unit IS INITIAL.
              lv_row_display_unit = CONV string( ls_raw-object_name+30 ).
              CONDENSE lv_row_display_unit.
            ENDIF.
            ls_row-display_name = COND string(
              WHEN ls_raw-type = 'METH'
               AND ls_raw-class IS NOT INITIAL
               AND lv_row_display_unit IS NOT INITIAL
              THEN |{ ls_raw-class }=>{ lv_row_display_unit }|
              WHEN lv_row_display_unit IS NOT INITIAL THEN lv_row_display_unit
              ELSE CONV string( ls_raw-object_name ) ).
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
                      AND trfunction IN ( 'S', 'R' )
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
                      AND trfunction IN ( 'S', 'R' )
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
                 ls_raw-type <> 'DDLS' AND ls_raw-type <> 'FUGR' AND ls_raw-type <> 'TABD' AND ls_raw-type <> 'DOMD' AND ls_raw-type <> 'DTED'.
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
    CLEAR ls_fc. ls_fc-fieldname = 'DISPLAY_NAME'. ls_fc-coltext = 'Object'.
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
        CLEAR: mt_parts_backup, mv_drilled_class, mv_drilled_fugr.
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
        DATA(ls_ck) = VALUE zif_ave_acr_types=>ty_diff_cache_key(
          objtype     = ls_stat-objtype
          objname     = ls_stat-obj_name
          versno_o    = ls_stat-versno_old
          versno_n    = ls_stat-versno_new
          blame         = mv_blame
          two_pane      = mv_two_pane
          compact       = mv_compact
          debug         = mv_debug
          ignore_case   = mv_ignore_case
          ignore_indent = mv_ignore_indent ).
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

    " ── FUGR row (from TR): drill into its includes ─────────────────
    IF ls_part-type = 'FUGR'.
      mt_parts_backup = mt_parts.
      mv_drilled_fugr = ls_part-object_name.
      CLEAR mt_parts.
      TRY.
          mt_parts = get_fugr_parts( CONV #( ls_part-object_name ) ).
        CATCH zcx_ave.
      ENDTRY.
      refresh_parts( ).
      " Auto-open first include
      READ TABLE mt_parts INTO DATA(ls_first_fugr) INDEX 1.
      IF sy-subrc = 0.
        mv_cur_objtype   = ls_first_fugr-type.
        mv_cur_objname   = ls_first_fugr-object_name.
        mv_cur_part_name = ls_first_fugr-name.
        load_versions( i_objtype = ls_first_fugr-type i_objname = ls_first_fugr-object_name ).
        refresh_vers( ).
        IF mt_versions IS NOT INITIAL.
          ms_base_ver = mt_versions[ 1 ].
          mv_viewed_versno = ms_base_ver-versno.
          IF mv_show_diff = abap_true.
            READ TABLE mt_versions INTO DATA(ls_prev_fugr) INDEX 2.
            auto_show_diff_or_source( is_old = ls_prev_fugr is_new = ms_base_ver ).
          ELSE.
            show_source( i_objtype = ms_base_ver-objtype
                         i_objname = ms_base_ver-objname
                         i_versno  = ms_base_ver-versno ).
          ENDIF.
          update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
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
      " Prefer the scope-aware NEW endpoint from version_list=>load: it excludes
      " ToC (T) copies and falls back to Active, matching the Code Review pairing.
      IF ms_load_new IS NOT INITIAL.
        ms_base_ver = ms_load_new.
      ELSEIF mv_object_type = zcl_ave_object_factory=>gc_type-tr.
        " In TR mode: base = version that belongs to the TR, not necessarily Active.
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
        " Scope-aware pair from load: use its baseline directly so a ToC sitting
        " between NEW and the real baseline is not picked as the compared version.
        IF ms_load_new IS NOT INITIAL AND ms_load_old IS NOT INITIAL.
          ls_prev_part = ms_load_old.
        ELSE.
          LOOP AT mt_versions INTO ls_prev_part WHERE versno < ms_base_ver-versno.
            EXIT.
          ENDLOOP.
        ENDIF.
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
    DATA(ls_result) = zcl_ave_version_list=>load(
      iv_objtype                = i_objtype
      iv_objname                = i_objname
      iv_date_from              = mv_date_from
      iv_remove_dup             = mv_remove_dup
      iv_no_toc                 = mv_no_toc
      iv_ignore_case            = mv_ignore_case
      iv_filter_korrnum         = mv_filter_korrnum
      it_filter_korrnums        = mt_filter_korrnums
      it_filter_parent_korrnums = mt_filter_parent_korrnums
      iv_system                 = mv_system ).

    mt_versions = ls_result-versions.
    mv_cur_creator = ls_result-creator.
    ms_load_new = ls_result-new_version.
    ms_load_old = ls_result-old_version.
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
      text      = COND #( WHEN mv_ignore_case = abap_true THEN 'Case/ind off' ELSE 'Case/ind on' )
      quickinfo = 'Toggle case/indent-insensitive diff'
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
        " One option, both flags — see the declaration of MV_IGNORE_CASE.
        mv_ignore_case   = COND #( WHEN mv_ignore_case = abap_true THEN abap_false ELSE abap_true ).
        mv_ignore_indent = mv_ignore_case.
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

        " Dictionary tables render as a structured field table (not raw text).
        IF i_objtype = 'TABD'.
          DATA(ls_tabd_one) = zcl_ave_version2=>get_tabd(
            iv_objname = i_objname
            iv_versno  = i_versno
            iv_system  = ls_ver_row-system ).
          set_html( zcl_ave_popup_html=>tabd_diff_to_html(
            is_old  = VALUE #( )
            is_new  = ls_tabd_one
            i_title = |{ i_objtype }: { i_objname }|
            i_meta  = ls_ver_row-versno_text ) ).
          RETURN.
        ENDIF.

        " Dictionary domains render as a structured fixed-value table (not raw text).
        IF i_objtype = 'DOMD'.
          DATA(ls_doma_one) = zcl_ave_version2=>get_doma(
            iv_objname = i_objname
            iv_versno  = i_versno
            iv_system  = ls_ver_row-system ).
          set_html( zcl_ave_popup_html=>doma_diff_to_html(
            is_old  = VALUE #( )
            is_new  = ls_doma_one
            i_title = |{ i_objtype }: { i_objname }|
            i_meta  = ls_ver_row-versno_text ) ).
          RETURN.
        ENDIF.

        " Data elements render as a structured attribute table (not raw text).
        IF i_objtype = 'DTED'.
          DATA(ls_dtel_one) = zcl_ave_version2=>get_dtel(
            iv_objname = i_objname
            iv_versno  = i_versno
            iv_system  = ls_ver_row-system ).
          set_html( zcl_ave_popup_html=>dtel_diff_to_html(
            is_old  = VALUE #( )
            is_new  = ls_dtel_one
            i_title = |{ i_objtype }: { i_objname }|
            i_meta  = ls_ver_row-versno_text ) ).
          RETURN.
        ENDIF.

        IF sy-subrc = 0 AND ls_ver_row-system IS NOT INITIAL.
          lt_source = zcl_ave_version2=>get_source_remote(
            iv_objtype = i_objtype
            iv_objname = i_objname
            iv_versno  = i_versno
            iv_system  = ls_ver_row-system ).
        ELSE.
          lt_source = zcl_ave_version2=>get_source_local_compat(
            iv_objtype = i_objtype
            iv_objname = i_objname
            iv_versno  = i_versno
            iv_korrnum = ls_ver_row-korrnum
            iv_author  = ls_ver_row-author
            iv_datum   = ls_ver_row-datum
            iv_zeit    = ls_ver_row-zeit ).
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
    zcl_ave_html_viewer=>show_html(
      io_viewer    = mo_html
      iv_html      = iv_html
      iv_set_focus = iv_focus ).
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
      DATA(lv_part_display_unit) = ls_part-unit.
      IF ls_part-type = 'METH' AND lv_part_display_unit IS INITIAL.
        lv_part_display_unit = CONV string( ls_part-object_name+30 ).
        CONDENSE lv_part_display_unit.
      ENDIF.
      ls_part_row-display_name = COND string(
        WHEN ls_part-type = 'METH'
         AND ls_part-class IS NOT INITIAL
         AND lv_part_display_unit IS NOT INITIAL
        THEN |{ ls_part-class }=>{ lv_part_display_unit }|
        WHEN lv_part_display_unit IS NOT INITIAL THEN lv_part_display_unit
        ELSE CONV string( ls_part-object_name ) ).
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


  METHOD get_fugr_parts.
    " New, FUGR-only expansion: ask the FUGR handler for its includes
    " (SAPL<group> main + L<group>* sub-includes) and build part rows.
    DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
      object_type = zcl_ave_object_factory=>gc_type-fugr
      object_name = CONV #( i_name ) ).

    " No check_part_exists here: FUGR includes (SAPL*/L*) live in TRDIR, not as
    " individual R3TR PROG entries in TADIR — the handler already returns only
    " includes that exist in TRDIR.
    LOOP AT lo_obj->get_parts( ) INTO DATA(ls_part).
      DATA ls_part_row TYPE ty_part_row.
      CLEAR ls_part_row.
      ls_part_row-name         = ls_part-unit.
      ls_part_row-display_name = CONV string( ls_part-object_name ).
      ls_part_row-type         = ls_part-type.
      ls_part_row-type_text    = zcl_ave_popup_data=>get_type_text( ls_part-type ).
      ls_part_row-object_name  = ls_part-object_name.
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
        IF zcl_ave_acr_repository=>has_review_table( ) = abap_false.
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
        CLEAR: mt_parts_backup, mv_drilled_class, mv_drilled_fugr.
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
            ELSEIF mv_drilled_fugr IS NOT INITIAL.
              " Drilled into a function group from a TR parts view — refresh only it.
              mt_parts = get_fugr_parts( mv_drilled_fugr ).
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
                DATA(lv_refresh_display_unit) = ls_raw-unit.
                IF ls_raw-type = 'METH' AND lv_refresh_display_unit IS INITIAL.
                  lv_refresh_display_unit = CONV string( ls_raw-object_name+30 ).
                  CONDENSE lv_refresh_display_unit.
                ENDIF.
                ls_row-display_name = COND string(
                  WHEN ls_raw-type = 'METH'
                   AND ls_raw-class IS NOT INITIAL
                   AND lv_refresh_display_unit IS NOT INITIAL
                  THEN |{ ls_raw-class }=>{ lv_refresh_display_unit }|
                  WHEN lv_refresh_display_unit IS NOT INITIAL THEN lv_refresh_display_unit
                  ELSE CONV string( ls_raw-object_name ) ).
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
        CLEAR: mt_diff_cache, mt_diff_data, mt_diff_render_cache.
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
        IF rerender_cr_current( ) = abap_true.
          RETURN.
        ENDIF.
        IF rerender_cr_user_view( ) = abap_true.
          RETURN.
        ENDIF.
        " Diff re-render must not depend on the viewed version still being in the
        " list: the base can be a synthetic Active endpoint (not in mt_versions).
        IF mv_show_diff = abap_true AND ( ms_diff_old IS NOT INITIAL OR ms_diff_new IS NOT INITIAL ).
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ELSEIF mv_viewed_versno IS NOT INITIAL AND mt_versions IS NOT INITIAL.
          READ TABLE mt_versions INTO DATA(ls_pv) WITH KEY versno = mv_viewed_versno.
          IF sy-subrc = 0.
            IF mv_show_diff = abap_true.
              show_versions_diff( is_old = ls_pv is_new = ms_base_ver ).
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
        IF rerender_cr_current( ) = abap_true.
          RETURN.
        ENDIF.
        IF rerender_cr_user_view( ) = abap_true.
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
        IF rerender_cr_current( ) = abap_true.
          RETURN.
        ENDIF.
        IF rerender_cr_user_view( ) = abap_true.
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
        IF rerender_cr_current( ) = abap_true.
          RETURN.
        ENDIF.
        IF rerender_cr_user_view( ) = abap_true.
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
    CHECK zcl_ave_acr_repository=>has_review_table( ) = abap_true.

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
        ct_diff_data     = mt_diff_data
        ct_approved      = mt_approved
        ct_declined      = mt_declined
        ct_decline_notes = mt_decline_notes
        ct_hunk_threads  = mt_hunk_threads
        ct_hunk_actions  = mt_hunk_actions ).
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
      it_diff_data        = mt_diff_data
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

    zcl_ave_html_viewer=>show_html(
      io_viewer    = mo_help_html
      iv_html      = zcl_ave_acr_renderer=>build_review_help_html( )
      iv_set_focus = abap_true ).
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

    zcl_ave_html_viewer=>show_html(
      io_viewer    = mo_help_html
      iv_html      = zcl_ave_acr_overview=>build_tr_task_popup_html(
        iv_objtype           = iv_objtype
        iv_objname           = iv_objname
        iv_outer_object_name = mv_object_name
        it_parts             = mt_parts )
      iv_set_focus = abap_true ).
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


  METHOD render_cached_diff.
    " Some object types (e.g. TABD) ship a prebuilt HTML that cannot be
    " reconstructed from the line DIFF — return it as-is.
    IF is_cache-prebuilt_html IS NOT INITIAL.
      result = is_cache-prebuilt_html.
      RETURN.
    ENDIF.
    IF mv_debug = abap_true.
      result = zcl_ave_popup_html=>debug_diff_html(
        it_diff = is_cache-diff
        i_title = is_cache-title
        i_meta  = is_cache-meta ).
    ELSE.
      result = zcl_ave_popup_html=>diff_to_html(
        it_diff          = is_cache-diff
        i_title          = is_cache-title
        i_meta           = is_cache-meta
        i_two_pane       = mv_two_pane
        i_compact        = COND #( WHEN is_cache-huge_source = abap_true THEN abap_true ELSE mv_compact )
        i_plain          = is_cache-huge_source
        i_ignore_case    = mv_ignore_case
        it_blame         = is_cache-blame
        it_blame_deleted = is_cache-blame_deleted ).
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
    DATA(ls_cache_key) = VALUE zif_ave_acr_types=>ty_diff_cache_key(
      objtype     = is_new-objtype
      objname     = is_new-objname
      system_o    = is_old-system
      system_n    = is_new-system
      versno_o    = is_old-versno
      versno_n    = is_new-versno
      blame         = mv_blame
      two_pane      = mv_two_pane
      compact       = mv_compact
      debug         = mv_debug
      ignore_case   = mv_ignore_case
      ignore_indent = mv_ignore_indent ).
    READ TABLE mt_diff_cache INTO DATA(ls_cached) WITH TABLE KEY key = ls_cache_key.
    IF sy-subrc = 0.
      set_html( ls_cached-html ).
      RETURN.
    ENDIF.

    DATA(ls_render_key) = VALUE ty_diff_render_key(
      objtype     = is_new-objtype
      objname     = is_new-objname
      system_o    = is_old-system
      system_n    = is_new-system
      versno_o    = is_old-versno
      versno_n    = is_new-versno
      blame         = mv_blame
      ignore_case   = mv_ignore_case
      ignore_indent = mv_ignore_indent ).
    READ TABLE mt_diff_render_cache INTO DATA(ls_render_cached) WITH TABLE KEY key = ls_render_key.
    IF sy-subrc = 0.
      DATA(lv_cached_html) = render_cached_diff( ls_render_cached ).
      INSERT VALUE zif_ave_acr_types=>ty_diff_cache( key = ls_cache_key html = lv_cached_html ) INTO TABLE mt_diff_cache.
      set_html( lv_cached_html ).
      RETURN.
    ENDIF.

    TRY.
        DATA(ls_diff_view) = zcl_ave_popup_diff_view=>render(
          is_old      = is_old
          is_new      = is_new
          it_versions = mt_versions
          is_options  = VALUE #(
            blame          = mv_blame
            two_pane       = mv_two_pane
            compact        = mv_compact
            debug          = mv_debug
            ignore_case    = mv_ignore_case
            ignore_indent  = mv_ignore_indent ) ).
        IF ls_diff_view-stopped = abap_true.
          RETURN.
        ENDIF.

        INSERT VALUE ty_diff_render_cache(
          key           = ls_render_key
          diff          = ls_diff_view-diff
          blame         = ls_diff_view-blame
          blame_deleted = ls_diff_view-blame_deleted
          huge_source   = ls_diff_view-huge_source
          title         = ls_diff_view-title
          meta          = ls_diff_view-meta
          prebuilt_html = COND #( WHEN is_new-objtype = 'TABD' OR is_new-objtype = 'DOMD' OR is_new-objtype = 'DTED' THEN ls_diff_view-html ELSE `` ) ) INTO TABLE mt_diff_render_cache.
        INSERT VALUE zif_ave_acr_types=>ty_diff_cache( key = ls_cache_key html = ls_diff_view-html ) INTO TABLE mt_diff_cache.
        set_html( ls_diff_view-html ).

      CATCH cx_root INTO DATA(lx_compare).
        DATA(lv_err_txt) = escape( val = lx_compare->get_text( ) format = cl_abap_format=>e_html_text ).
        DATA(lv_err_diffline) = zcl_ave_popup_html=>gv_render_line.
        set_html( |<html><body style="padding:24px;font:13px Consolas;color:#c00">| &&
          |Error loading versions for comparison.<br><br>{ lv_err_txt }| &&
          COND string( WHEN lv_err_diffline > 0
            THEN |<br><br><span style="color:#888;font-size:11px">diff source line { lv_err_diffline }</span>|
            ELSE `` ) &&
          |</body></html>| ).
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
        iv_ai_enabled    = is_ai_enabled( )
      CHANGING
        cv_html          = result
        ct_acr_stats     = mt_acr_stats ).
  ENDMETHOD.


  METHOD on_sapevent.
    zcl_ave_acr_command=>handle_sapevent(
      io_popup  = me
      iv_action = CONV #( action ) ).
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
    CLEAR mv_moving_view.
    maximize_html( ).
    DATA(lv_html) = mv_cr_report_html.
    " Restore the exact scroll offset the report was left at (saved to sessionStorage
    " by the report page before the drilldown link was followed). When nothing was
    " stored, fall back to the anchor of the last opened object/class row.
    DATA lv_anchor TYPE string.
    IF mv_cr_cur_key IS NOT INITIAL.
      " class drilldown sets mv_cr_cur_key = 'class_CLASSNAME' → anchor id is already 'class_CLASSNAME'
      " object drilldown sets mv_cr_cur_key = 'TYPE~OBJNAME'   → anchor id is 'obj_TYPE~OBJNAME'
      DATA(lv_is_class_anchor) = abap_false.
      IF strlen( mv_cr_cur_key ) >= 6.
        IF mv_cr_cur_key(6) = 'class_'.
          lv_is_class_anchor = abap_true.
        ENDIF.
      ENDIF.
      lv_anchor = COND string(
        WHEN lv_is_class_anchor = abap_true
        THEN mv_cr_cur_key
        ELSE |obj_{ escape( val = mv_cr_cur_key format = cl_abap_format=>e_html_attr ) }| ).
    ENDIF.
    " The retry via setTimeout re-applies the offset once the tables are laid out —
    " on load alone the document is often still shorter than the saved position.
    DATA(lv_script) =
      `<script>(function(){` &&
      `var pos=null;` &&
      `try{pos=sessionStorage.getItem('ave_scroll_crreport');` &&
      `sessionStorage.removeItem('ave_scroll_crreport');}catch(e){}` &&
      `var a='` && lv_anchor && `';` &&
      `function go(){` &&
      `if(pos){window.scrollTo(0,parseInt(pos,10));return;}` &&
      `if(!a)return;var el=document.getElementById(a);if(el)el.scrollIntoView(true);}` &&
      `window.addEventListener('load',function(){go();setTimeout(go,0);});` &&
      `})();</script></head>`.
    lv_html = replace( val = lv_html sub = `</head>` with = lv_script ).
    set_html( iv_html = lv_html iv_focus = abap_true ).
  ENDMETHOD.


  METHOD show_moving_violations.
    " Dedicated read-only view that lists only retrofit (moving-violation) hunks.
    " No blame, no approve/decline — these are informational warnings about code
    " that diverges from the remote system and will be overwritten/re-inserted there.
    CLEAR: mv_cr_base_html, mv_cr_cur_key, mv_cur_objtype, mv_cur_objname, mv_cur_part_name.
    CLEAR: mv_decline_view_user, mv_reviewer_view.
    mv_moving_view = abap_true.

    " Regenerate hunk html on the fly (respects current pane), then keep retrofit only
    DATA(lt_view) = build_view_hunks( mt_hunk_info ).
    DATA lt_mv TYPE STANDARD TABLE OF ty_hunk_info WITH DEFAULT KEY.
    LOOP AT lt_view INTO DATA(ls_mv) WHERE retrofit IS NOT INITIAL.
      APPEND ls_mv TO lt_mv.
    ENDLOOP.
    SORT lt_mv BY objtype obj_name hunk_no.

    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px;background:#fff;color:#333}` &&
      `h2{color:#c0392b;border-bottom:2px solid #e74c3c;padding-bottom:6px;margin-bottom:16px}` &&
      `.objhdr{margin:18px 0 8px 0;background:#ffe0e0;color:#c0392b;padding:5px 10px;` &&
      `font-weight:bold;white-space:nowrap}` &&
      `.warn{margin:4px 0 6px 0;padding:6px 10px;background:#ffe0e0;border:2px solid #e74c3c;` &&
      `border-radius:5px;color:#c0392b;font-weight:bold;white-space:normal}` &&
      `.blkinfo{margin:5px 0 2px 0;color:#2c3e50;font-weight:bold;white-space:nowrap}` &&
      `.muted{color:#777;font-weight:normal}` &&
      `table.diff{border-collapse:collapse;width:100%;font-size:12px;margin:0 0 10px 0}` &&
      `.diff .ln{color:#aaa;text-align:right;padding:1px 10px 1px 5px;min-width:42px;` &&
      `border-right:1px solid #e0e0e0;white-space:nowrap;background:#fafafa}` &&
      `.diff .cd{padding:1px 8px;white-space:pre}` &&
      `.back{position:fixed;top:8px;left:8px;z-index:999;background:#3498db;color:#fff;` &&
      `padding:4px 10px;border-radius:4px;text-decoration:none;font:bold 12px Consolas,monospace;` &&
      `white-space:nowrap;box-shadow:0 1px 4px rgba(0,0,0,.25)}`.

    DATA(lv_sys_txt) = COND string(
      WHEN mv_system IS NOT INITIAL
      THEN | &mdash; target system { escape( val = CONV string( mv_system ) format = cl_abap_format=>e_html_text ) }|
      ELSE `` ).
    DATA(lv_html) =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ lv_css }</style></head><body>| &&
      |<a class="back" href="sapevent:back~0">&#8592; Back</a>| &&
      |<h2>&#9888; Moving Violations ({ lines( lt_mv ) }){ lv_sys_txt }</h2>|.

    IF lt_mv IS INITIAL.
      lv_html = lv_html &&
        |<p style="color:#888">No moving violations found.</p></body></html>|.
      maximize_html( ).
      set_html( lv_html ).
      RETURN.
    ENDIF.

    DATA lv_cur_obj TYPE string.
    LOOP AT lt_mv INTO DATA(ls_hunk).
      DATA(lv_obj_key) = |{ ls_hunk-objtype }~{ ls_hunk-obj_name }|.
      IF lv_obj_key <> lv_cur_obj.
        lv_cur_obj = lv_obj_key.
        DATA(lv_obj_title) = COND string(
          WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
          ELSE CONV string( ls_hunk-obj_name ) ).
        lv_html = lv_html &&
          |<div class="objhdr">{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
          |{ escape( val = lv_obj_title format = cl_abap_format=>e_html_text ) }</div>|.
      ENDIF.

      " html already holds plain diff rows (no blame) rendered against the remote diff
      DATA(lv_code_html) = COND string(
        WHEN ls_hunk-html IS NOT INITIAL
        THEN |<table class="diff"><tbody>{ ls_hunk-html }</tbody></table>|
        ELSE `<div style="color:#888;margin:4px 0 10px">Diff not available.</div>` ).

      lv_html = lv_html &&
        |<div class="warn">&#9888; { escape( val = ls_hunk-retrofit format = cl_abap_format=>e_html_text ) }</div>| &&
        |<div class="blkinfo">Block #{ ls_hunk-hunk_no } | &&
        |<span class="muted">vs { escape( val = ls_hunk-versno_old_text format = cl_abap_format=>e_html_text ) } | &&
        |line</span> { ls_hunk-start_line } <span class="muted">changes</span> { ls_hunk-change_count }</div>| &&
        lv_code_html.
    ENDLOOP.

    lv_html = lv_html && |</body></html>|.
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD show_class_objects.
    " Track for back_to_report scroll
    CLEAR mv_cr_base_html.
    CLEAR: mv_cur_objtype, mv_cur_objname, mv_cur_part_name.
    mv_cr_cur_key = |class_{ iv_class_name }|.
    DATA(lt_view_hunk_info) = build_view_hunks( mt_hunk_info ).

    " Collect all hunks that belong to this class (any part: METH, CLSD, CPUB...)
    DATA lt_hunks TYPE STANDARD TABLE OF ty_hunk_info WITH DEFAULT KEY.
    LOOP AT lt_view_hunk_info INTO DATA(ls_hi).
      IF ls_hi-class_name <> iv_class_name.
        DATA(lv_hi_objname) = CONV string( ls_hi-obj_name ).
        FIND FIRST OCCURRENCE OF '=' IN lv_hi_objname MATCH OFFSET DATA(lv_hi_eq).
        IF sy-subrc = 0 AND lv_hi_eq > 0.
          lv_hi_objname = lv_hi_objname(lv_hi_eq).
        ENDIF.
        CHECK ls_hi-class_name IS INITIAL
          AND ( ls_hi-objtype = 'CPUB'
             OR ls_hi-objtype = 'CPRO'
             OR ls_hi-objtype = 'CPRI'
             OR ls_hi-objtype = 'CLSD'
             OR ls_hi-objtype = 'CINC'
             OR ls_hi-objtype = 'CDEF' )
          AND lv_hi_objname = iv_class_name.
      ENDIF.
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
          lv_html = lv_html && zcl_ave_acr_ai=>render_summary_html(
            iv_objtype      = CONV #( lv_cur_obj(4) )
            iv_objname      = CONV #( lv_cur_obj+5 )
            it_hunk_threads = mt_hunk_threads ) && `</div>`.
        ENDIF.
        lv_cur_obj = lv_obj_key.
        DATA lv_obj_blocks  TYPE i.
        DATA lv_obj_changes TYPE i.
        CLEAR: lv_obj_blocks, lv_obj_changes.
        LOOP AT lt_hunks INTO DATA(ls_s) WHERE objtype = ls_hunk-objtype AND obj_name = ls_hunk-obj_name.
          lv_obj_blocks = lv_obj_blocks + 1.
          lv_obj_changes = lv_obj_changes + ls_s-change_count.
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
      DATA(lv_clean_html) = zcl_ave_acr_renderer=>normalize_diff_html(
        iv_html     = ls_hunk-html
        iv_two_pane = mv_two_pane ).
      DATA(lv_blame_header_html) = zcl_ave_acr_renderer=>extract_blame_rows(
        CHANGING cv_html = lv_clean_html ).
      DATA(lv_code_html) = COND string(
        WHEN lv_clean_html IS NOT INITIAL
        THEN |<table class="diff"><tbody>{ lv_clean_html }</tbody></table>|
        ELSE `<div style="color:#888;margin:4px 0 10px">Diff not available.</div>` ).

      DATA(lv_actions_html) = zcl_ave_acr_renderer=>render_hunk_actions_html(
        iv_hunk_key     = ls_hunk-hunk_key
        it_approved     = mt_approved
        it_declined     = mt_declined
        it_hunk_actions = mt_hunk_actions
        it_hunk_info    = lt_view_hunk_info
        it_hunk_threads = mt_hunk_threads
        iv_ai_enabled   = is_ai_enabled( ) ).
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

      lv_html = lv_html && zcl_ave_acr_renderer=>render_hunk_comments_html(
        iv_hunk_key     = ls_hunk-hunk_key
        it_hunk_threads = mt_hunk_threads ).

      lv_html = lv_html &&
        COND string(
          WHEN lv_blame_header_html IS NOT INITIAL
          THEN |<table class="diff"><tbody>{ lv_blame_header_html }</tbody></table>|
          ELSE `` ) &&
        `<div class="codewrap">` &&
        lv_code_html &&
        `</div></div>`.
    ENDLOOP.

    IF lv_cur_obj <> `####`.
      lv_html = lv_html && zcl_ave_acr_ai=>render_summary_html(
        iv_objtype      = CONV #( lv_cur_obj(4) )
        iv_objname      = CONV #( lv_cur_obj+5 )
        it_hunk_threads = mt_hunk_threads ).
    ENDIF.

    lv_html = lv_html && `</div></body></html>`.
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD build_view_hunks.
    result = it_hunk_info.

    LOOP AT mt_diff_data INTO DATA(ls_view_diff_data).
      " Retrofit (moving-violation) diff: regenerate its hunk html on the fly,
      " respecting the current pane setting, then map to the retrofit hunks.
      IF ls_view_diff_data-retrofit = abap_true.
        DATA lt_rl TYPE zif_ave_acr_types=>ty_review_lines.
        CLEAR lt_rl.
        LOOP AT mt_diff_data INTO DATA(ls_prim_dd)
          WHERE key-objtype = ls_view_diff_data-key-objtype
            AND key-objname = ls_view_diff_data-key-objname
            AND retrofit    = abap_false.
          LOOP AT ls_prim_dd-diff INTO DATA(ls_pop) WHERE op = '+' OR op = '-'.
            INSERT |{ ls_pop-op }\|{ ls_pop-text }| INTO TABLE lt_rl.
          ENDLOOP.
        ENDLOOP.

        DATA ls_meta_hunk TYPE ty_hunk_info.
        CLEAR ls_meta_hunk.
        LOOP AT result INTO ls_meta_hunk
          WHERE objtype = ls_view_diff_data-key-objtype
            AND obj_name = ls_view_diff_data-key-objname
            AND retrofit IS NOT INITIAL.
          EXIT.
        ENDLOOP.

        DATA(lt_regen) = zcl_ave_acr_precompute=>collect_retrofit_hunks(
          is_part          = VALUE #( type        = ls_view_diff_data-key-objtype
                                      object_name = ls_view_diff_data-key-objname
                                      class       = ls_meta_hunk-class_name )
          it_diff          = ls_view_diff_data-diff
          it_review_lines  = lt_rl
          iv_versno_new    = ls_view_diff_data-key-versno_n
          iv_new_text      = ``
          iv_remote_versno = ls_view_diff_data-key-versno_o
          iv_old_text      = ``
          iv_system        = space
          iv_author        = ls_meta_hunk-author
          iv_display_name  = CONV #( ls_meta_hunk-display_name )
          iv_two_pane      = mv_two_pane
          iv_ignore_case   = mv_ignore_case ).

        LOOP AT result ASSIGNING FIELD-SYMBOL(<rh>)
          WHERE objtype = ls_view_diff_data-key-objtype
            AND obj_name = ls_view_diff_data-key-objname
            AND retrofit IS NOT INITIAL.
          READ TABLE lt_regen INTO DATA(ls_regen) WITH TABLE KEY hunk_key = <rh>-hunk_key.
          IF sy-subrc = 0.
            <rh>-html = ls_regen-html.
          ENDIF.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      DATA(lv_view_full_html) = zcl_ave_popup_html=>diff_to_html(
        it_diff          = ls_view_diff_data-diff
        i_title          = ls_view_diff_data-title
        i_meta           = ls_view_diff_data-meta
        i_two_pane       = mv_two_pane
        i_compact        = COND #( WHEN ls_view_diff_data-huge_source = abap_true THEN abap_true ELSE mv_compact )
        i_plain          = ls_view_diff_data-huge_source
        i_ignore_case    = mv_ignore_case
        i_code_review    = abap_true
        it_blame         = ls_view_diff_data-blame_map
        it_blame_deleted = ls_view_diff_data-blame_deleted ).
      DATA(lt_view_hunk_html) = zcl_ave_acr_hunk_html=>collect_rows(
        it_diff          = ls_view_diff_data-diff
        iv_full_html     = lv_view_full_html
        iv_title         = ls_view_diff_data-title
        iv_meta          = ls_view_diff_data-meta
        iv_two_pane      = mv_two_pane
        iv_plain         = ls_view_diff_data-huge_source
        iv_ignore_case   = mv_ignore_case
        iv_is_created    = ls_view_diff_data-is_created
        iv_context       = COND #( WHEN mv_compact = abap_true OR ls_view_diff_data-huge_source = abap_true THEN 3 ELSE 999999 )
        it_blame         = ls_view_diff_data-blame_map
        it_blame_deleted = ls_view_diff_data-blame_deleted ).

      LOOP AT result ASSIGNING FIELD-SYMBOL(<view_hunk>)
        WHERE objtype = ls_view_diff_data-key-objtype
          AND obj_name = ls_view_diff_data-key-objname.
        " Retrofit hunks keep their own precomputed html (built from the remote diff).
        CHECK <view_hunk>-retrofit IS INITIAL.
        READ TABLE lt_view_hunk_html INTO DATA(lv_view_hunk_html) INDEX <view_hunk>-hunk_no.
        IF sy-subrc = 0.
          <view_hunk>-html = lv_view_hunk_html.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
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
      scroll_last_html_to( zcl_ave_acr_ai=>get_summary_scroll_anchor(
        iv_objtype = iv_objtype
        iv_objname = iv_objname ) ).
    ELSE.
      scroll_last_html_to( zcl_ave_acr_ai=>get_hunk_scroll_anchor( iv_hunk_key ) ).
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
            i_apikey = CONV string( mv_apikey )
            i_provider = mv_provider ).
          IF lv_summary_answer IS NOT INITIAL AND lv_summary_answer NP 'Error:*'.
            DATA lv_sum_tld TYPE i.
            FIND FIRST OCCURRENCE OF '~' IN lv_cur_obj_key MATCH OFFSET lv_sum_tld.
            IF sy-subrc = 0.
              DATA(lv_sum_name_start) = lv_sum_tld + 1.
              zcl_ave_acr_ai=>save_summary(
                EXPORTING
                  iv_objtype      = CONV #( lv_cur_obj_key(lv_sum_tld) )
                  iv_objname      = CONV #( lv_cur_obj_key+lv_sum_name_start )
                  iv_text         = lv_summary_answer
                  it_hunk_info    = mt_hunk_info
                CHANGING
                  ct_hunk_threads = mt_hunk_threads ).
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

      DATA(lv_ai_comment) = zcl_ave_acr_ai=>get_hunk_comment(
        iv_hunk_key     = ls_hunk-hunk_key
        it_hunk_info    = mt_hunk_info
        it_hunk_threads = mt_hunk_threads ).
      IF lv_ai_comment IS INITIAL.
        DATA(lv_hunk_prompt) = zcl_ave_acr_ai=>build_hunk_prompt(
          iv_hunk_key    = ls_hunk-hunk_key
          it_hunk_info   = mt_hunk_info
          it_diff_data   = mt_diff_data
          iv_ignore_case = mv_ignore_case ).
        IF lv_hunk_prompt IS NOT INITIAL.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING
              percentage = 50
              text       = |Asking AI for block { ls_hunk-hunk_no }...|.

          lv_ai_comment = zcl_ave_ai_api=>ask(
            i_prompt = lv_hunk_prompt
            i_dest   = mv_desination
            i_model  = mv_model
            i_apikey = CONV string( mv_apikey )
            i_provider = mv_provider ).

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
        i_apikey = CONV string( mv_apikey )
        i_provider = mv_provider ).
      IF lv_summary_answer_last IS NOT INITIAL AND lv_summary_answer_last NP 'Error:*'.
        DATA lv_sum_tld_last TYPE i.
        FIND FIRST OCCURRENCE OF '~' IN lv_cur_obj_key MATCH OFFSET lv_sum_tld_last.
        IF sy-subrc = 0.
          DATA(lv_sum_name_start_last) = lv_sum_tld_last + 1.
          zcl_ave_acr_ai=>save_summary(
            EXPORTING
              iv_objtype      = CONV #( lv_cur_obj_key(lv_sum_tld_last) )
              iv_objname      = CONV #( lv_cur_obj_key+lv_sum_name_start_last )
              iv_text         = lv_summary_answer_last
              it_hunk_info    = mt_hunk_info
            CHANGING
              ct_hunk_threads = mt_hunk_threads ).
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
    DATA(lv_prompt) = zcl_ave_acr_ai=>build_hunk_prompt(
      iv_hunk_key    = iv_hunk_key
      it_hunk_info   = mt_hunk_info
      it_diff_data   = mt_diff_data
      iv_ignore_case = mv_ignore_case ).
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
      i_apikey = CONV string( mv_apikey )
      i_provider = mv_provider ).

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

    zcl_ave_html_viewer=>show_html(
      io_viewer    = mo_help_html
      iv_html      = lv_popup_html
      iv_set_focus = abap_true ).
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

    DATA(lv_html) = zcl_ave_acr_ai=>build_prompt_page_html(
      iv_object_name = mv_object_name
      iv_compact     = mv_compact
      iv_ignore_case = mv_ignore_case
      it_diff_data   = mt_diff_data
      it_hunks       = lt_hunks ).

    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD show_user_declines.
    CLEAR: mv_cr_base_html, mv_cr_cur_key, mv_cur_objtype, mv_cur_objname, mv_cur_part_name.
    mv_decline_view_user = iv_user.
    mv_reviewer_view = iv_reviewer.
    DATA(lv_user_name) = COND ad_namtext(
      WHEN iv_user IS INITIAL THEN 'All developers'
      ELSE zcl_ave_popup_data=>get_user_name( iv_user ) ).
    DATA(lt_view_hunk_info) = build_view_hunks( mt_hunk_info ).

    DATA lt_summary_objs TYPE zcl_ave_acr_user_view=>ty_t_summary_objs.
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
        READ TABLE lt_view_hunk_info INTO DATA(ls_review_hunk)
          WITH TABLE KEY hunk_key = lv_review_key.
        IF sy-subrc = 0.
          APPEND ls_review_hunk TO lt_hunks.
        ENDIF.
      ENDLOOP.
    ELSE.
      IF iv_user IS INITIAL.
        LOOP AT lt_view_hunk_info INTO DATA(ls_hi_all).
          CHECK ls_hi_all-retrofit IS INITIAL.
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
        LOOP AT lt_view_hunk_info INTO DATA(ls_hi) WHERE author = iv_user.
          CHECK ls_hi-retrofit IS INITIAL.
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

    DATA(lv_ai_enabled) = is_ai_enabled( ).
    DATA(lv_ai_prompt_label) = COND string(
      WHEN lv_ai_enabled = abap_true THEN `AI Summary`
      ELSE `AI prompt` ).

    DATA(lv_html) = zcl_ave_acr_user_view=>build_html(
      iv_user         = iv_user
      iv_user_name    = lv_user_name
      iv_reviewer     = iv_reviewer
      it_hunks        = lt_hunks
      it_summary_objs = lt_summary_objs
      it_hunk_info    = lt_view_hunk_info
      it_obj_stats    = mt_acr_stats
      it_approved     = mt_approved
      it_declined     = mt_declined
      it_hunk_actions = mt_hunk_actions
      it_hunk_threads = mt_hunk_threads
      iv_blame        = mv_blame
      iv_two_pane     = mv_two_pane
      iv_ai_enabled   = lv_ai_enabled
      iv_ai_label     = lv_ai_prompt_label ).
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD open_cr_part.
    " Clear cached ALV-based HTML so that ON_NOTE_DLG_SAVED re-renders via open_cr_part
    " instead of falling through to the inject_approve_btn branch (which has no comments).
    " Keep mv_cr_cur_key set to TYPE~OBJNAME so back_to_report can scroll to this row.
    CLEAR mv_cr_base_html.
    mv_cr_cur_key = |{ iv_objtype }~{ iv_objname }|.

    " Always track the current object from iv_ params so ON_NOTE_DLG_SAVED
    " re-renders the correct object even when mt_parts lookup finds nothing.
    mv_cur_objtype = iv_objtype.
    mv_cur_objname = iv_objname.

    " Dictionary tables always render as the full structured field table (one
    " approvable hunk) regardless of compact mode — the generic per-hunk renderer
    " cannot lay out its columns.
    IF iv_objtype = 'TABD' OR iv_objtype = 'DOMD' OR iv_objtype = 'DTED'.
      LOOP AT mt_diff_cache INTO DATA(ls_tabd_cache)
        WHERE key-objtype  = iv_objtype
          AND key-objname  = iv_objname
          AND key-two_pane = mv_two_pane.
        maximize_html( ).
        set_html( inject_approve_btn(
          iv_html = ls_tabd_cache-html
          iv_key  = |{ iv_objtype }~{ iv_objname }| ) ).
        RETURN.
      ENDLOOP.
    ENDIF.

    IF mv_compact = abap_false.
      LOOP AT mt_diff_cache INTO DATA(ls_full_diff)
        WHERE key-objtype     = iv_objtype
          AND key-objname     = iv_objname
          AND key-two_pane      = mv_two_pane
          AND key-compact       = mv_compact
          AND key-debug         = mv_debug
          AND key-ignore_case   = mv_ignore_case
          AND key-ignore_indent = mv_ignore_indent.
        DATA(lv_full_html) = inject_approve_btn(
          iv_html = ls_full_diff-html
          iv_key  = |{ iv_objtype }~{ iv_objname }| ).
        maximize_html( ).
        set_html( lv_full_html ).
        RETURN.
      ENDLOOP.
      READ TABLE mt_diff_data INTO DATA(ls_full_diff_data)
        WITH KEY key-objtype     = iv_objtype
                 key-objname     = iv_objname
                 key-ignore_case = mv_ignore_case
                 key-ignore_indent = mv_ignore_indent
                 retrofit        = abap_false.
      IF sy-subrc = 0.
        DATA lv_full_rendered TYPE string.
        IF mv_debug = abap_true.
          lv_full_rendered = zcl_ave_popup_html=>debug_diff_html(
            it_diff = ls_full_diff_data-diff
            i_title = ls_full_diff_data-title
            i_meta  = ls_full_diff_data-meta ).
        ELSE.
          lv_full_rendered = zcl_ave_popup_html=>diff_to_html(
            it_diff          = ls_full_diff_data-diff
            i_title          = ls_full_diff_data-title
            i_meta           = ls_full_diff_data-meta
            i_two_pane       = mv_two_pane
            i_compact        = COND #( WHEN ls_full_diff_data-huge_source = abap_true THEN abap_true ELSE mv_compact )
            i_plain          = ls_full_diff_data-huge_source
            i_ignore_case    = mv_ignore_case
            i_code_review    = abap_true
            it_blame         = ls_full_diff_data-blame_map
            it_blame_deleted = ls_full_diff_data-blame_deleted ).
        ENDIF.
        maximize_html( ).
        set_html( inject_approve_btn(
          iv_html = lv_full_rendered
          iv_key  = |{ iv_objtype }~{ iv_objname }| ) ).
        RETURN.
      ENDIF.
    ENDIF.
    " Refine part name from mt_parts (class => method display)
    LOOP AT mt_parts ASSIGNING FIELD-SYMBOL(<lp>)
      WHERE type = iv_objtype AND object_name = iv_objname.
      mv_cur_part_name = COND string(
        WHEN <lp>-class IS NOT INITIAL THEN |{ <lp>-class } => { <lp>-name }|
        ELSE <lp>-name ).
      EXIT.
    ENDLOOP.

    DATA(lv_ai_enabled) = is_ai_enabled( ).
    DATA(lv_ai_prompt_label) = COND string(
      WHEN lv_ai_enabled = abap_true THEN `AI Summary`
      ELSE `AI prompt` ).

    DATA(lv_html) = zcl_ave_acr_part_view=>build_html(
      iv_objtype      = iv_objtype
      iv_objname      = iv_objname
      it_parts        = mt_parts
      it_hunk_info    = build_view_hunks( mt_hunk_info )
      it_obj_stats    = mt_acr_stats
      it_approved     = mt_approved
      it_declined     = mt_declined
      it_hunk_actions = mt_hunk_actions
      it_hunk_threads = mt_hunk_threads
      iv_blame        = mv_blame
      iv_two_pane     = mv_two_pane
      iv_ai_enabled   = lv_ai_enabled
      iv_ai_label     = lv_ai_prompt_label ).
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD rerender_cr_current.
    result = abap_false.
    CHECK mv_code_review = abap_true.
    CHECK mv_decline_view_user IS INITIAL.
    CHECK mv_cr_cur_key IS NOT INITIAL.

    IF strlen( mv_cr_cur_key ) >= 6.
      IF mv_cr_cur_key(6) = 'class_'.
        DATA(lv_class_start) = 6.
        DATA(lv_class_name) = CONV seoclsname( mv_cr_cur_key+lv_class_start ).

        show_class_objects( iv_class_name = lv_class_name ).
        result = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    DATA lv_tld TYPE i.
    FIND FIRST OCCURRENCE OF '~' IN mv_cr_cur_key MATCH OFFSET lv_tld.
    CHECK sy-subrc = 0.

    DATA lv_objtype TYPE versobjtyp.
    DATA lv_objname TYPE versobjnam.
    lv_objtype = mv_cr_cur_key(lv_tld).
    DATA(lv_name_start) = lv_tld + 1.
    lv_objname = mv_cr_cur_key+lv_name_start.

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
      READ TABLE mt_parts TRANSPORTING NO FIELDS
        WITH KEY type = ls_key-objtype object_name = ls_key-obj_name.
      CHECK sy-subrc = 0.
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
      zcl_ave_acr_state=>set_hunk_action(
        EXPORTING
          iv_hunk_key     = iv_hunk_key
          iv_action       = 'D'
        CHANGING
          ct_hunk_actions = mt_hunk_actions ).
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
          lv_edit_idx = lv_edit_idx - 1.
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
      mv_cr_report_html = add_moving_violations_link( mv_cr_report_html ).
    ELSE.
      mv_cr_report_html = build_cr_object_report_html( ).
    ENDIF.
  ENDMETHOD.


  METHOD add_moving_violations_link.
    result = iv_html.
    DATA lv_cnt TYPE i.
    LOOP AT mt_hunk_info TRANSPORTING NO FIELDS WHERE retrofit IS NOT INITIAL.
      lv_cnt = lv_cnt + 1.
    ENDLOOP.
    CHECK lv_cnt > 0.

    DATA(lv_link) =
      |<div style="margin:8px 0;padding:8px 12px;background:#ffe0e0;| &&
      |border:2px solid #e74c3c;border-radius:5px">| &&
      |<a href="sapevent:movingviol~0" style="color:#c0392b;font-weight:bold;| &&
      |text-decoration:none;font-size:1.05em">&#9888; Moving Violations - { lv_cnt }</a></div>|.

    " Insert right after the opening <body> tag
    IF result CS `<body>`.
      result = replace( val = result sub = `<body>` with = |<body>{ lv_link }| ).
    ELSE.
      result = lv_link && result.
    ENDIF.
  ENDMETHOD.


  METHOD add_cr_report_toolbar.
    result = zcl_ave_acr_renderer=>add_report_toolbar(
      iv_html    = iv_html
      iv_enabled = mv_code_review ).
  ENDMETHOD.


  METHOD build_cr_object_report_html.
    result = zcl_ave_acr_overview=>build_object_report_html(
      iv_object_name = mv_object_name
      iv_object_type = mv_object_type
      iv_cr_prepared = mv_cr_prepared
      it_parts       = mt_parts ).
  ENDMETHOD.


  METHOD prepare_code_review.
    zcl_ave_acr_workflow=>prepare_code_review(
      io_popup = me
      iv_keys  = iv_keys ).
  ENDMETHOD.


  METHOD delete_and_recalc_selected.
    zcl_ave_acr_workflow=>delete_and_recalc_selected(
      io_popup = me
      iv_keys  = iv_keys ).
  ENDMETHOD.


  METHOD show_recalc_picker.
    IF mv_object_type = zcl_ave_object_factory=>gc_type-tr
       AND mt_parts_backup IS NOT INITIAL.
      mt_parts = mt_parts_backup.
      CLEAR mt_parts_backup.
      CLEAR mv_drilled_class.
      CLEAR mv_drilled_fugr.
      refresh_parts( ).
    ENDIF.

    DATA(ls_payload) = VALUE ty_saved_payload( ).
    DATA(lv_has_payload) = load_review_payload(
      EXPORTING iv_trkorr = CONV #( mv_object_name )
      IMPORTING es_payload = ls_payload ).

    DATA(lv_html) = zcl_ave_acr_overview=>build_recalc_picker_html(
      iv_object_name = mv_object_name
      iv_has_payload = lv_has_payload
      it_parts       = mt_parts
      it_obj_stats   = ls_payload-obj_stats ).
    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD open_saved_code_review.
    result = abap_false.
    CHECK mv_code_review = abap_true.
    CHECK mv_object_type = zcl_ave_object_factory=>gc_type-tr.
    CHECK zcl_ave_acr_repository=>has_review_table( ) = abap_true.

    DATA(ls_payload) = VALUE ty_saved_payload( ).
    CHECK load_review_payload(
      EXPORTING iv_trkorr = CONV #( mv_object_name )
      IMPORTING es_payload = ls_payload ) = abap_true.
    CHECK ls_payload-obj_stats IS NOT INITIAL.
    CHECK ls_payload-hunks IS NOT INITIAL.
    CHECK ls_payload-diff_data IS NOT INITIAL.

    CLEAR: mt_acr_stats, mt_hunk_info, mt_hunk_threads, mt_diff_cache, mt_diff_data, mt_diff_render_cache,
           mt_approved, mt_declined, mt_decline_notes,
           mv_cr_base_html, mv_cr_cur_key, mv_decline_view_user,
           mv_reviewer_view.

    mt_acr_stats = ls_payload-obj_stats.
    mt_hunk_info = ls_payload-hunks.
    mt_diff_data = ls_payload-diff_data.
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
ENDCLASS.
