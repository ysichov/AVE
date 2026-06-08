CLASS zcl_ave_acr_workflow DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS prepare_code_review
      IMPORTING
        !io_popup TYPE REF TO zcl_ave_popup
        !iv_keys  TYPE string OPTIONAL .

    CLASS-METHODS delete_and_recalc_selected
      IMPORTING
        !io_popup TYPE REF TO zcl_ave_popup
        !iv_keys  TYPE string .
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
             io_popup->mt_diff_data,
             io_popup->mt_diff_render_cache,
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
             io_popup->mt_diff_data,
             io_popup->mt_diff_render_cache,
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

      lv_done = lv_done + 1.
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
        DELETE io_popup->mt_diff_data WHERE key-objname = ls_part-object_name.
        DELETE io_popup->mt_diff_render_cache WHERE key-objname = ls_part-object_name.
        io_popup->call_cr_precompute_class_parts( CONV #( ls_part-object_name ) ).
      ELSE.
        io_popup->add_cr_diag(
          |DISPATCH { ls_part-type } { ls_part-object_name }: precompute direct part| ).
        DELETE io_popup->mt_acr_stats WHERE objtype = ls_part-type AND obj_name = ls_part-object_name.
        DELETE io_popup->mt_hunk_info WHERE objtype = ls_part-type AND obj_name = ls_part-object_name.
        DELETE io_popup->mt_diff_cache WHERE key-objtype = ls_part-type AND key-objname = ls_part-object_name.
        DELETE io_popup->mt_diff_data WHERE key-objtype = ls_part-type AND key-objname = ls_part-object_name.
        DELETE io_popup->mt_diff_render_cache WHERE key-objtype = ls_part-type AND key-objname = ls_part-object_name.
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


  METHOD delete_and_recalc_selected.
    CHECK io_popup->mv_code_review = abap_true.
    CHECK iv_keys IS NOT INITIAL.

    IF iv_keys = `0`.
      io_popup->add_cr_diag( |RECALC all selected: short all-marker received| ).
      IF zcl_ave_acr_repository=>has_review_table( ) = abap_true.
        DATA(lv_tabname_all_del) = CONV tabname( 'ZAVE_REVIEW' ).
        DATA(lv_trkorr_all_del) = CONV trkorr( io_popup->mv_object_name ).
        TRY.
            DELETE FROM (lv_tabname_all_del) WHERE trkorr = @lv_trkorr_all_del.
          CATCH cx_sy_dynamic_osql_semantics
                cx_sy_dynamic_osql_syntax
                cx_sy_open_sql_db.
        ENDTRY.
      ENDIF.
      CLEAR: io_popup->mt_acr_stats,
             io_popup->mt_hunk_info,
             io_popup->mt_hunk_threads,
             io_popup->mt_diff_cache,
             io_popup->mt_diff_data,
             io_popup->mt_diff_render_cache,
             io_popup->mt_approved,
             io_popup->mt_declined,
             io_popup->mt_decline_notes,
             io_popup->mt_hunk_actions.
      prepare_code_review( io_popup = io_popup ).
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
    LOOP AT io_popup->mt_parts INTO DATA(ls_part_all_check) WHERE type <> 'RPT'.
      lv_selectable_count = lv_selectable_count + 1.
      DATA(lv_part_all_key) = zcl_ave_acr_prepare=>part_key( ls_part_all_check ).
      IF NOT line_exists( lt_selected_keys[ table_line = lv_part_all_key ] ).
        lv_all_selected = abap_false.
      ENDIF.
    ENDLOOP.

    IF lv_selectable_count > 0
       AND lv_all_selected = abap_true
       AND lines( lt_selected_keys ) >= lv_selectable_count.
      io_popup->add_cr_diag(
        |RECALC all selected: deleting saved review, then preparing explicit selected keys={ lines( lt_selected_keys ) }| ).
      IF zcl_ave_acr_repository=>has_review_table( ) = abap_true.
        DATA(lv_tabname_del) = CONV tabname( 'ZAVE_REVIEW' ).
        DATA(lv_trkorr_del) = CONV trkorr( io_popup->mv_object_name ).
        TRY.
            DELETE FROM (lv_tabname_del) WHERE trkorr = @lv_trkorr_del.
          CATCH cx_sy_dynamic_osql_semantics
                cx_sy_dynamic_osql_syntax
                cx_sy_open_sql_db.
        ENDTRY.
      ENDIF.
      CLEAR: io_popup->mt_acr_stats,
             io_popup->mt_hunk_info,
             io_popup->mt_hunk_threads,
             io_popup->mt_diff_cache,
             io_popup->mt_diff_data,
             io_popup->mt_diff_render_cache,
             io_popup->mt_approved,
             io_popup->mt_declined,
             io_popup->mt_decline_notes,
             io_popup->mt_hunk_actions.
      prepare_code_review(
        io_popup = io_popup
        iv_keys  = iv_keys ).
      RETURN.
    ENDIF.

    io_popup->load_review_from_db( ).

    LOOP AT io_popup->mt_parts INTO DATA(ls_part_stat) WHERE type <> 'RPT'.
      DATA(lv_part_stat_key) = zcl_ave_acr_prepare=>part_key( ls_part_stat ).
      CHECK line_exists( lt_selected_keys[ table_line = lv_part_stat_key ] ).
      IF ls_part_stat-type = 'CLAS'.
        DELETE io_popup->mt_acr_stats WHERE class_name = ls_part_stat-object_name.
      ELSE.
        DELETE io_popup->mt_acr_stats WHERE objtype = ls_part_stat-type AND obj_name = ls_part_stat-object_name.
      ENDIF.
    ENDLOOP.

    DATA lt_hunk_keys_to_delete TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT io_popup->mt_hunk_info INTO DATA(ls_hunk_to_check).
      LOOP AT io_popup->mt_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
        DATA(lv_part_key) = zcl_ave_acr_prepare=>part_key( ls_part ).
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
      DELETE TABLE io_popup->mt_approved FROM lv_hunk_key.
      DELETE TABLE io_popup->mt_declined FROM lv_hunk_key.
      DELETE io_popup->mt_hunk_info WHERE hunk_key = lv_hunk_key.
      DELETE io_popup->mt_decline_notes WHERE hunk_key = lv_hunk_key.
      DELETE io_popup->mt_hunk_threads WHERE hunk_key = lv_hunk_key.
      DELETE io_popup->mt_hunk_actions WHERE hunk_key = lv_hunk_key.
    ENDLOOP.

    LOOP AT io_popup->mt_parts INTO DATA(ls_part_clean) WHERE type <> 'RPT'.
      DATA(lv_part_clean_key) = zcl_ave_acr_prepare=>part_key( ls_part_clean ).
      CHECK line_exists( lt_selected_keys[ table_line = lv_part_clean_key ] ).
      IF ls_part_clean-type = 'CLAS'.
        DELETE io_popup->mt_diff_cache WHERE key-objname = ls_part_clean-object_name.
        DELETE io_popup->mt_diff_data WHERE key-objname = ls_part_clean-object_name.
        DELETE io_popup->mt_diff_render_cache WHERE key-objname = ls_part_clean-object_name.
      ELSE.
        DELETE io_popup->mt_diff_cache WHERE key-objtype = ls_part_clean-type AND key-objname = ls_part_clean-object_name.
        DELETE io_popup->mt_diff_data WHERE key-objtype = ls_part_clean-type AND key-objname = ls_part_clean-object_name.
        DELETE io_popup->mt_diff_render_cache WHERE key-objtype = ls_part_clean-type AND key-objname = ls_part_clean-object_name.
      ENDIF.
    ENDLOOP.

    io_popup->sanitize_review_state( ).
    io_popup->save_review_to_db( iv_silent = abap_true ).
    prepare_code_review(
      io_popup = io_popup
      iv_keys  = iv_keys ).
  ENDMETHOD.

ENDCLASS.

