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

  PRIVATE SECTION.
    "! Up to this many objects the growing report still fits a screen and is
    "! worth redrawing after every one of them. Above it the run switches to the
    "! one-line progress page, because rebuilding the report renders every object
    "! collected so far — the cost grows with the square of the object count.
    CONSTANTS c_full_report_max TYPE i VALUE 50 ##NO_TEXT.
    "! Distance between two screen updates, derived from how long the run is
    "! expected to take — not from how many objects it has. The throttle exists
    "! because a refresh costs real time, but what a person waiting wants is a
    "! sign of life often enough relative to the wait: a two-minute run needs one
    "! every few seconds, a ten-minute one does not. C_REFRESH_DIVISOR fixes both
    "! ends — 2 min of estimate gives the 3 s floor, 10 min the 15 s ceiling.
    CONSTANTS c_refresh_min     TYPE i VALUE 3 ##NO_TEXT.
    CONSTANTS c_refresh_max     TYPE i VALUE 15 ##NO_TEXT.
    CONSTANTS c_refresh_divisor TYPE i VALUE 40000 ##NO_TEXT.

    "! Seconds between screen updates for a run estimated at IV_EST_MS.
    CLASS-METHODS refresh_secs
      IMPORTING iv_est_ms     TYPE i
      RETURNING VALUE(result) TYPE i.

    "! Reads the measured durations out of the saved review into the popup
    "! before the review row is deleted. Timings are not review state — they
    "! describe how long this system takes — so a "delete and recalc" should not
    "! throw away what the estimates are calibrated from.
    CLASS-METHODS keep_timings
      IMPORTING
        !io_popup TYPE REF TO zcl_ave_popup.
ENDCLASS.

CLASS zcl_ave_acr_workflow IMPLEMENTATION.

  METHOD prepare_code_review.
    CHECK io_popup->mv_code_review = abap_true.

    " Transport headers and per-object task lists are cached for the whole run —
    " dropped first so a long session picks up requests released meanwhile.
    zcl_ave_request=>clear_cache( ).

    IF io_popup->mv_object_type = zcl_ave_object_factory=>gc_type-tr
       AND io_popup->mt_parts_backup IS NOT INITIAL.
      io_popup->mt_parts = io_popup->mt_parts_backup.
      CLEAR io_popup->mt_parts_backup.
      CLEAR io_popup->mv_drilled_class.
      CLEAR io_popup->mv_drilled_fugr.
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
      it_parts            = io_popup->mt_parts
      iv_selected_only    = lv_selected_only
      it_selected_keys    = lt_selected_keys
      iv_ignore_generated = io_popup->mv_ignore_generated ).

    DATA lv_done TYPE i.

    " The saved payload cannot change while this loop runs (it is written once,
    " after it), so it is read and deserialized here instead of twice per object.
    DATA(ls_loop_payload) = VALUE zif_ave_acr_types=>ty_saved_payload( ).
    DATA(lv_loop_payload_ok) = io_popup->load_review_payload(
      EXPORTING iv_trkorr  = CONV #( io_popup->mv_object_name )
      IMPORTING es_payload = ls_loop_payload ).
    CLEAR lv_loop_payload_ok.

    " Estimates as they stand right before the run: stored next to the measured
    " duration so the next estimate can be corrected by the factor between them,
    " and used to predict the remaining time while the run is going.
    DATA(lt_run_metrics) = io_popup->collect_metrics( )-metrics.

    " Has this blame setting ever been measured? If not, the pre-run estimates —
    " and with them the remaining time on the progress page — are model values
    " nobody has checked against a clock yet.
    DATA lv_eta_rough TYPE abap_bool VALUE abap_true.
    LOOP AT lt_run_metrics INTO DATA(ls_meas_check).
      IF ( io_popup->mv_blame = abap_true  AND ls_meas_check-measured_bl = abap_true )
      OR ( io_popup->mv_blame = abap_false AND ls_meas_check-measured_nb = abap_true ).
        lv_eta_rough = abap_false.
        EXIT.
      ENDIF.
    ENDLOOP.

    DATA lv_est_total_ms TYPE i.
    LOOP AT io_popup->mt_parts INTO DATA(ls_est_part) WHERE type <> 'RPT'.
      CHECK zcl_ave_popup_data=>is_supported_object_type( ls_est_part-type ) = abap_true.
      IF io_popup->mv_ignore_generated = abap_true
         AND ( zcl_ave_acr_prepare=>is_generated_class( ls_est_part-object_name ) = abap_true
            OR ( ls_est_part-class IS NOT INITIAL
             AND zcl_ave_acr_prepare=>is_generated_class( ls_est_part-class ) = abap_true ) ).
        CONTINUE.
      ENDIF.
      IF zcl_ave_acr_prepare=>is_deleted_object( ls_est_part ) = abap_true.
        CONTINUE.
      ENDIF.
      DATA(lv_est_key) = zcl_ave_acr_prepare=>part_key( ls_est_part ).
      IF lv_selected_only = abap_true
         AND NOT line_exists( lt_selected_keys[ table_line = lv_est_key ] ).
        CONTINUE.
      ENDIF.
      READ TABLE lt_run_metrics INTO DATA(ls_est_metric) WITH KEY part_key = lv_est_key.
      CHECK sy-subrc = 0.
      lv_est_total_ms = lv_est_total_ms + COND i(
        WHEN io_popup->mv_blame = abap_true THEN ls_est_metric-est_bl_ms
        ELSE ls_est_metric-est_nb_ms ).
    ENDLOOP.

    " Screen updates: full report only while it still fits a screen, otherwise a
    " one-line progress page — and in both cases no more often than the cadence
    " REFRESH_SECS derives from the estimated duration of the run. Their cost is
    " measured separately from the objects.
    DATA(lv_light_progress) = xsdbool( lv_total > c_full_report_max ).
    DATA(lv_refresh_secs) = refresh_secs( lv_est_total_ms ).
    DATA lv_ts_run_start TYPE timestampl.
    DATA lv_ts_last_render TYPE timestampl.
    DATA lv_ts_now TYPE timestampl.
    DATA lv_ts_render_start TYPE timestampl.
    DATA lv_secs_gap TYPE tzntstmpl.
    DATA lv_render_secs TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_render_count TYPE i.
    DATA lv_est_done_ms TYPE i.
    DATA lv_actual_done_ms TYPE i.
    GET TIME STAMP FIELD lv_ts_run_start.
    lv_ts_last_render = lv_ts_run_start.

    LOOP AT io_popup->mt_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_part-type ) = abap_false.
        io_popup->add_cr_diag(
          |SKIP { ls_part-type } { ls_part-object_name }: unsupported object type| ).
        CONTINUE.
      ENDIF.

      IF io_popup->mv_ignore_generated = abap_true
         AND ( zcl_ave_acr_prepare=>is_generated_class( ls_part-object_name ) = abap_true
            OR ( ls_part-class IS NOT INITIAL
             AND zcl_ave_acr_prepare=>is_generated_class( ls_part-class ) = abap_true ) ).
        io_popup->add_cr_diag(
          |SKIP { ls_part-type } { ls_part-object_name }: generated Gateway class (MPC / MPC_EXT / DPC)| ).
        CONTINUE.
      ENDIF.

      " The object is gone from this system, only its versions survived — nothing
      " here can be reviewed, and pairing the last version against nothing would
      " report the whole source as newly written code.
      IF zcl_ave_acr_prepare=>is_deleted_object( ls_part ) = abap_true.
        io_popup->add_cr_diag(
          |SKIP { ls_part-type } { ls_part-object_name }: object does not exist any more (deleted, versions kept)| ).
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

      " Wall clock around the precompute of this part — the measurement the
      " metric estimates are calibrated from.
      DATA lv_ts_part_start TYPE timestampl.
      DATA lv_ts_part_end TYPE timestampl.
      DATA lv_part_secs TYPE tzntstmpl.
      GET TIME STAMP FIELD lv_ts_part_start.

      IF ls_part-type = 'CLAS'.
        io_popup->add_cr_diag(
          |DISPATCH CLAS { ls_part-object_name }: expand class parts| ).
        DELETE io_popup->mt_acr_stats WHERE class_name = ls_part-object_name.
        DELETE io_popup->mt_hunk_info WHERE class_name = ls_part-object_name.
        DELETE io_popup->mt_diff_cache WHERE key-objname = ls_part-object_name.
        DELETE io_popup->mt_diff_data WHERE key-objname = ls_part-object_name.
        DELETE io_popup->mt_diff_render_cache WHERE key-objname = ls_part-object_name.
        io_popup->call_cr_precompute_class_parts( CONV #( ls_part-object_name ) ).
      ELSEIF ls_part-type = 'FUGR'.
        io_popup->add_cr_diag(
          |DISPATCH FUGR { ls_part-object_name }: expand function group parts| ).
        io_popup->call_cr_precompute_fugr_parts( CONV #( ls_part-object_name ) ).
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

      GET TIME STAMP FIELD lv_ts_part_end.
      cl_abap_tstmp=>subtract(
        EXPORTING tstmp1 = lv_ts_part_end
                  tstmp2 = lv_ts_part_start
        RECEIVING r_secs = lv_part_secs ).
      DATA(ls_run_metric) = VALUE zcl_ave_acr_metrics=>ty_metric( ).
      READ TABLE lt_run_metrics INTO ls_run_metric WITH KEY part_key = lv_part_key.
      IF sy-subrc <> 0.
        CLEAR ls_run_metric.
      ENDIF.

      DATA(lv_part_ms) = CONV i( lv_part_secs * 1000 ).
      io_popup->add_cr_timing(
        is_part   = ls_part
        iv_msecs  = lv_part_ms
        is_metric = ls_run_metric ).
      DATA(lv_est_part_ms) = COND i(
        WHEN io_popup->mv_blame = abap_true THEN ls_run_metric-est_bl_ms
        ELSE ls_run_metric-est_nb_ms ).
      io_popup->add_cr_diag(
        |TIMING { ls_part-type } { ls_part-object_name }: | &&
        |{ zcl_ave_acr_metrics=>format_ms( lv_part_ms ) } | &&
        |(estimated { zcl_ave_acr_metrics=>format_ms( lv_est_part_ms ) })| ).

      io_popup->sanitize_review_state( ).

      lv_actual_done_ms = lv_actual_done_ms + lv_part_ms.
      lv_est_done_ms = lv_est_done_ms + lv_est_part_ms.

      " ── Screen update, throttled ──────────────────────────────────────────
      GET TIME STAMP FIELD lv_ts_now.
      cl_abap_tstmp=>subtract(
        EXPORTING tstmp1 = lv_ts_now
                  tstmp2 = lv_ts_last_render
        RECEIVING r_secs = lv_secs_gap ).

      IF lv_secs_gap >= lv_refresh_secs OR lv_done = lv_total OR lv_done = 1.
        lv_ts_render_start = lv_ts_now.

        IF lv_light_progress = abap_true.
          " Remaining time from the estimates, scaled by how far off they were
          " on the objects already done — a plain done/total ratio would be
          " wrong whenever the heavy objects are not evenly spread.
          DATA lv_eta_secs TYPE i.
          CLEAR lv_eta_secs.
          cl_abap_tstmp=>subtract(
            EXPORTING tstmp1 = lv_ts_now
                      tstmp2 = lv_ts_run_start
            RECEIVING r_secs = lv_secs_gap ).
          DATA(lv_elapsed_secs) = CONV i( lv_secs_gap ).

          " Distributing the remaining time by the model is only worth doing when
          " the model has been measured for this blame setting. Otherwise it
          " claims the objects still to come are cheap purely because it has
          " never seen what they cost, and the estimate collapses — so fall back
          " to the observed pace, which cannot be that wrong.
          DATA lv_eta_calc TYPE p LENGTH 16 DECIMALS 2.
          IF lv_eta_rough = abap_false AND lv_est_done_ms > 0 AND lv_actual_done_ms > 0.
            " Packed: milliseconds multiplied by milliseconds leaves the
            " integer range long before a run of this size finishes.
            lv_eta_calc = CONV decfloat34( lv_est_total_ms - lv_est_done_ms )
                        * lv_actual_done_ms / lv_est_done_ms / 1000.
            lv_eta_secs = CONV i( lv_eta_calc ).
          ELSEIF lv_done > 0.
            lv_eta_calc = CONV decfloat34( lv_actual_done_ms ) * ( lv_total - lv_done )
                        / lv_done / 1000.
            lv_eta_secs = CONV i( lv_eta_calc ).
          ENDIF.
          IF lv_eta_secs < 0.
            CLEAR lv_eta_secs.
          ENDIF.

          io_popup->set_html( zcl_ave_acr_renderer=>build_progress_html(
            iv_object_name  = io_popup->mv_object_name
            iv_done         = lv_done
            iv_total        = lv_total
            iv_elapsed_secs = lv_elapsed_secs
            iv_eta_secs     = lv_eta_secs
            iv_current      = |{ ls_part-type } { ls_part-object_name }| ) ).
        ELSE.
          DATA lt_report_approved TYPE zif_ave_acr_types=>ty_approved.
          DATA lt_report_declined TYPE zif_ave_acr_types=>ty_approved.

          io_popup->collect_report_status(
            EXPORTING
              is_payload  = ls_loop_payload
            IMPORTING
              et_approved = lt_report_approved
              et_declined = lt_report_declined ).

          io_popup->mv_cr_report_html = zcl_ave_acr_report=>to_html(
            it_obj_stats = io_popup->mt_acr_stats
            it_approved  = lt_report_approved
            it_declined  = lt_report_declined
            it_reviewers = io_popup->get_reviewer_stats( is_payload = ls_loop_payload )
            i_korrnum    = CONV #( io_popup->mv_object_name ) ).

          io_popup->mv_cr_report_html = io_popup->add_cr_diagnostics( io_popup->mv_cr_report_html ).
          io_popup->mv_cr_report_html = io_popup->add_cr_report_toolbar( io_popup->mv_cr_report_html ).
          io_popup->set_html( io_popup->mv_cr_report_html ).
        ENDIF.

        cl_gui_cfw=>flush( EXCEPTIONS OTHERS = 1 ).

        GET TIME STAMP FIELD lv_ts_last_render.
        cl_abap_tstmp=>subtract(
          EXPORTING tstmp1 = lv_ts_last_render
                    tstmp2 = lv_ts_render_start
          RECEIVING r_secs = lv_secs_gap ).
        lv_render_secs  = lv_render_secs + lv_secs_gap.
        lv_render_count = lv_render_count + 1.
      ENDIF.
    ENDLOOP.

    " The price of keeping the screen up to date, kept out of the per-object
    " measurements so those stay comparable between runs.
    io_popup->add_cr_diag(
      |RENDER: { lv_render_count } screen update(s), { CONV i( lv_render_secs ) }s total| ).

    io_popup->load_review_from_db( ).
    io_popup->regen_acr_report( ).
    io_popup->refresh_rpt_row( ).
    io_popup->save_review_to_db( iv_silent = abap_true ).
    io_popup->set_html( io_popup->mv_cr_report_html ).
  ENDMETHOD.


  METHOD refresh_secs.
    result = iv_est_ms / c_refresh_divisor.
    IF result < c_refresh_min.
      result = c_refresh_min.
    ELSEIF result > c_refresh_max.
      result = c_refresh_max.
    ENDIF.
  ENDMETHOD.


  METHOD keep_timings.
    CHECK io_popup->mt_cr_timings IS INITIAL.

    DATA(ls_payload) = VALUE zif_ave_acr_types=>ty_saved_payload( ).
    DATA(lv_ok) = io_popup->load_review_payload(
      EXPORTING iv_trkorr  = CONV #( io_popup->mv_object_name )
      IMPORTING es_payload = ls_payload ).
    CLEAR lv_ok.

    CHECK ls_payload-timings IS NOT INITIAL.
    io_popup->mt_cr_timings = ls_payload-timings.
    io_popup->add_cr_diag(
      |TIMINGS: { lines( ls_payload-timings ) } measurement(s) carried over the delete| ).
  ENDMETHOD.


  METHOD delete_and_recalc_selected.
    CHECK io_popup->mv_code_review = abap_true.
    CHECK iv_keys IS NOT INITIAL.

    IF iv_keys = `0`.
      io_popup->add_cr_diag( |RECALC all selected: short all-marker received| ).
      keep_timings( io_popup ).
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
      keep_timings( io_popup ).
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

