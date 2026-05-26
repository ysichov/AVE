CLASS zcl_ave_acr_workflow DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS prepare_code_review
      IMPORTING
        !io_popup TYPE REF TO zcl_ave_popup
        !iv_keys  TYPE string OPTIONAL .
ENDCLASS.

CLASS zcl_ave_acr_workflow IMPLEMENTATION.

  METHOD prepare_code_review.
    CHECK io_popup->mv_code_review = abap_true.

    IF io_popup->mv_object_type = zcl_ave_object_factory=>gc_type-tr
       AND io_popup->mt_parts_backup IS NOT INITIAL.
      io_popup->mt_parts = io_popup->mt_parts_backup.
      CLEAR io_popup->mt_parts_backup.
      CLEAR io_popup->mv_drilled_class.
    ENDIF.

    DATA(lv_selected_only) = zcl_ave_acr_prepare=>is_selected_only( iv_keys ).
    DATA(lt_selected_keys) = zcl_ave_acr_prepare=>parse_selected_keys( iv_keys ).

    CLEAR: io_popup->mv_cr_base_html,
           io_popup->mv_cr_cur_key,
           io_popup->mv_decline_view_user.

    IF lv_selected_only = abap_true.
      CLEAR: io_popup->mt_acr_stats,
             io_popup->mt_hunk_info,
             io_popup->mt_hunk_threads,
             io_popup->mt_diff_cache,
             io_popup->mt_cr_diag,
             io_popup->mt_approved,
             io_popup->mt_declined,
             io_popup->mt_decline_notes.
      io_popup->load_review_from_db( ).
    ELSE.
      CLEAR: io_popup->mt_acr_stats,
             io_popup->mt_hunk_info,
             io_popup->mt_hunk_threads,
             io_popup->mt_diff_cache,
             io_popup->mt_cr_diag,
             io_popup->mt_approved,
             io_popup->mt_declined,
             io_popup->mt_decline_notes.
    ENDIF.

    io_popup->mv_cr_prepared = abap_true.
    io_popup->maximize_html( ).

    DATA(lv_part_count) = zcl_ave_acr_prepare=>count_supported_parts( io_popup->mt_parts ).
    io_popup->add_cr_diag(
      |PREPARE { io_popup->mv_object_name }: parts={ lv_part_count }, selected_only={ lv_selected_only }, selected_keys={ lines( lt_selected_keys ) }| ).

    IF lv_selected_only = abap_true.
      LOOP AT lt_selected_keys INTO DATA(lv_diag_selected_key).
        IF zcl_ave_acr_prepare=>has_part_key(
             it_parts = io_popup->mt_parts
             iv_key   = lv_diag_selected_key ) = abap_false.
          io_popup->add_cr_diag(
            |SELECTED KEY { lv_diag_selected_key }: not found in current parts list| ).
        ENDIF.
      ENDLOOP.
    ENDIF.

    DATA(lv_total) = zcl_ave_acr_prepare=>count_preparable_parts(
      it_parts         = io_popup->mt_parts
      iv_selected_only = lv_selected_only
      it_selected_keys = lt_selected_keys ).

    DATA lv_done TYPE i.

    LOOP AT io_popup->mt_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_part-type ) = abap_false.
        io_popup->add_cr_diag(
          |SKIP { ls_part-type } { ls_part-object_name }: unsupported object type| ).
        CONTINUE.
      ENDIF.

      DATA(lv_part_key) = zcl_ave_acr_prepare=>part_key( ls_part ).
      IF lv_selected_only = abap_true
         AND NOT line_exists( lt_selected_keys[ table_line = lv_part_key ] ).
        io_popup->add_cr_diag(
          |SKIP { ls_part-type } { ls_part-object_name }: not selected| ).
        CONTINUE.
      ENDIF.

      lv_done += 1.
      io_popup->add_cr_diag(
        |DISPATCH { ls_part-type } { ls_part-object_name }: class={ ls_part-class }, name={ ls_part-name }, rows={ ls_part-rows }| ).

      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = CONV i( lv_done * 100 / COND i( WHEN lv_total > 0 THEN lv_total ELSE 1 ) )
                  text       = CONV char70( |Code Review: preparing { ls_part-object_name }| ).

      IF ls_part-type = 'CLAS'.
        io_popup->add_cr_diag(
          |DISPATCH CLAS { ls_part-object_name }: expand class parts| ).
        DELETE io_popup->mt_acr_stats WHERE class_name = ls_part-object_name.
        DELETE io_popup->mt_hunk_info WHERE class_name = ls_part-object_name.
        DELETE io_popup->mt_diff_cache WHERE key-objname = ls_part-object_name.
        io_popup->call_cr_precompute_class_parts( CONV #( ls_part-object_name ) ).
      ELSE.
        io_popup->add_cr_diag(
          |DISPATCH { ls_part-type } { ls_part-object_name }: precompute direct part| ).
        DELETE io_popup->mt_acr_stats WHERE objtype = ls_part-type AND obj_name = ls_part-object_name.
        DELETE io_popup->mt_hunk_info WHERE objtype = ls_part-type AND obj_name = ls_part-object_name.
        DELETE io_popup->mt_diff_cache WHERE key-objtype = ls_part-type AND key-objname = ls_part-object_name.
        io_popup->call_cr_precompute_part( ls_part ).
      ENDIF.

      io_popup->sanitize_review_state( ).

      DATA lt_report_approved TYPE zif_ave_acr_types=>ty_approved.
      DATA lt_report_declined TYPE zif_ave_acr_types=>ty_approved.

      io_popup->collect_report_status(
        IMPORTING
          et_approved = lt_report_approved
          et_declined = lt_report_declined ).

      io_popup->mv_cr_report_html = zcl_ave_acr_report=>to_html(
        it_obj_stats = io_popup->mt_acr_stats
        it_approved  = lt_report_approved
        it_declined  = lt_report_declined
        it_reviewers = io_popup->get_reviewer_stats( )
        i_korrnum    = CONV #( io_popup->mv_object_name ) ).

      io_popup->mv_cr_report_html = io_popup->add_cr_diagnostics( io_popup->mv_cr_report_html ).
      io_popup->mv_cr_report_html = io_popup->add_cr_report_toolbar( io_popup->mv_cr_report_html ).
      io_popup->set_html( io_popup->mv_cr_report_html ).
      cl_gui_cfw=>flush( EXCEPTIONS OTHERS = 1 ).
    ENDLOOP.

    io_popup->load_review_from_db( ).
    io_popup->regen_acr_report( ).
    io_popup->refresh_rpt_row( ).
    io_popup->save_review_to_db( iv_silent = abap_true ).
    io_popup->set_html( io_popup->mv_cr_report_html ).
  ENDMETHOD.

ENDCLASS.

