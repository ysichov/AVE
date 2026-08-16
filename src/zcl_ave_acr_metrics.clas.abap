"! Cost metrics for a Code Review scope: how many versions and lines every
"! changed part carries, and how long precomputing it is expected to take.
"!
"! The point is to know BEFORE pressing Prepare which objects are cheap (they
"! can be computed in the dialog right away) and which are heavy (they belong
"! in a background run), instead of discovering it after three hours.
"!
"! Everything here is read-only and cheap: one grouped SELECT on VRSD for the
"! version counts plus the line counts the parts list already carries.
CLASS zcl_ave_acr_metrics DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES ty_part_row TYPE zif_ave_popup_types=>ty_part_row.
    TYPES ty_t_part_row TYPE zif_ave_popup_types=>ty_t_part_row.

    "! Weight band of one part: L(ight) / M(edium) / H(eavy)
    TYPES ty_band TYPE c LENGTH 1.

    TYPES:
      BEGIN OF ty_metric,
        part_key     TYPE string,
        type         TYPE versobjtyp,
        object_name  TYPE versobjnam,
        class        TYPE string,
        display_name TYPE string,
        "! Versions in VRSD for this part — for CLAS/FUGR the sum over all
        "! technical parts of the object. Drives the version-metadata load, which
        "! runs over the whole history regardless of the reviewed range.
        versions     TYPE i,
        "! Versions belonging to the reviewed request(s). Blame replays only the
        "! range from the baseline to the new version, so this is what drives it.
        vers_scope   TYPE i,
        "! All those versions carry the same author. The replay could then only
        "! ever name that one author, so PRECOMPUTE_PART skips it and attributes
        "! the primary diff directly — blame costs nothing for such an object.
        solo_author  TYPE abap_bool,
        "! Technical parts the object expands into (1 for a plain part).
        sub_parts    TYPE i,
        "! Active source lines; 0 when unknown (CLAS/FUGR aggregates).
        lines        TYPE i,
        "! Lines actually used for the estimate (assumed value when unknown).
        lines_est    TYPE i,
        cached       TYPE abap_bool,
        "! What the model predicted before the run that produced the measurement,
        "! for the active blame setting. 0 when there is no measurement yet.
        est_before_ms   TYPE i,
        "! Estimate for the currently active blame setting — drives the band.
        est_ms     TYPE i,
        "! Both modes, so the cost of blame is visible before switching it on.
        est_nb_ms       TYPE i,
        est_bl_ms       TYPE i,
        "! True when the respective estimate is a measurement of an earlier
        "! Prepare run of this very part, not a model value.
        measured     TYPE abap_bool,
        measured_nb  TYPE abap_bool,
        measured_bl  TYPE abap_bool,
        band         TYPE ty_band,
      END OF ty_metric.
    TYPES ty_t_metric TYPE STANDARD TABLE OF ty_metric WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_summary,
        trkorr         TYPE trkorr,
        parts_total    TYPE i,
        parts_light    TYPE i,
        parts_medium   TYPE i,
        parts_heavy    TYPE i,
        parts_cached   TYPE i,
        versions_total TYPE i,
        "! Source lines actually counted, and the lines assumed for aggregates
        "! (CLAS/FUGR) that have no single source — kept apart so the number is
        "! not mistaken for a measurement.
        lines_total    TYPE i,
        lines_assumed  TYPE i,
        "! Totals for the active blame setting (EST_SECS) and for both modes,
        "! so the price of blame is visible without switching it on first.
        est_ms       TYPE i,
        est_ms_nb    TYPE i,
        est_ms_bl    TYPE i,
        est_ms_light TYPE i,
        est_ms_heavy TYPE i,
        "! The active-setting total split into the part that is measured and the
        "! part that is still modelled — the two are otherwise indistinguishable
        "! in the total, which is what makes it disagree with the stopwatch.
        est_ms_meas  TYPE i,
        est_ms_model TYPE i,
        blame          TYPE abap_bool,
        remote         TYPE verssysnam,
        "! True when the selected request is an S/R task: version filtering is
        "! skipped in that case, so blame replays the object's FULL history.
        full_history   TYPE abap_bool,
        "! Parts whose estimate is a real measurement.
        parts_measured TYPE i,
        "! Calibration factor applied to the model, in percent: measured total
        "! vs. what the model predicted for the same parts. 100 = uncalibrated.
        calib_pct      TYPE i,
      END OF ty_summary.

    TYPES:
      BEGIN OF ty_result,
        metrics TYPE ty_t_metric,
        summary TYPE ty_summary,
      END OF ty_result.

    CONSTANTS:
      BEGIN OF gc_band,
        light  TYPE ty_band VALUE 'L',
        medium TYPE ty_band VALUE 'M',
        heavy  TYPE ty_band VALUE 'H',
      END OF gc_band.

    "! Estimate model. CLASS-DATA, not CONSTANTS: measurements recalibrate it, and
    "! the starting values matter only until the first Prepare has run.
    "! Anchored on measured runs after the request-header cache landed. The base
    "! cost is per OBJECT, not per part: measurements show no correlation with
    "! the part count (a 5-part function group finished in 1.7 s, faster than a
    "! single-part table), while a 40-part class was over-estimated twofold when
    "! the base was multiplied by its parts.
    CLASS-DATA gv_obj_ms TYPE i VALUE 100 ##NO_TEXT.           " version directory + overhead
    CLASS-DATA gv_part_ms TYPE i VALUE 50 ##NO_TEXT.           " per technical part
    CLASS-DATA gv_ver_ms TYPE i VALUE 6 ##NO_TEXT.             " metadata of one version
    CLASS-DATA gv_line_ms TYPE i VALUE 1 ##NO_TEXT.            " diff + both html renders
    "! One blame step reads the source of that version (SVRS round trip) and runs
    "! a full diff against the previous one. Measured on parts where the replay
    "! really ran: 91 steps in 38.0 s, 77 in 32.7 s, 147 in 62.2 s — ~420 ms per
    "! step, independent of how small the source is.
    CLASS-DATA gv_blame_step_ms TYPE i VALUE 420 ##NO_TEXT.    " fixed cost per blame step
    CLASS-DATA gv_blame_lin_um TYPE i VALUE 500 ##NO_TEXT.     " µs per line per blame step
    CLASS-DATA gv_blame_sq_um TYPE i VALUE 100 ##NO_TEXT.      " µs per 1000 lines² per step
    CLASS-DATA gv_remote_pct TYPE i VALUE 180 ##NO_TEXT.       " remote retrofit multiplier
    CLASS-DATA gv_assumed_lines TYPE i VALUE 120 ##NO_TEXT.    " lines assumed per unknown part
    CLASS-DATA gv_heavy_secs TYPE i VALUE 90 ##NO_TEXT.        " band threshold H
    CLASS-DATA gv_medium_secs TYPE i VALUE 20 ##NO_TEXT.       " band threshold M

    "! Collects one metric row per reviewable part of the scope.
    CLASS-METHODS collect
      IMPORTING
        iv_trkorr          TYPE trkorr OPTIONAL
        it_parts           TYPE ty_t_part_row
        iv_blame           TYPE abap_bool DEFAULT abap_false
        iv_system          TYPE verssysnam OPTIONAL
        it_obj_stats       TYPE zif_ave_acr_types=>ty_t_obj_stats OPTIONAL
        it_filter_korrnums TYPE zif_ave_object=>ty_t_korr_range OPTIONAL
        iv_filter_korrnum  TYPE trkorr OPTIONAL
        "! Durations measured by earlier Prepare runs. A part that was measured
        "! reports its measurement; the rest of the model is rescaled to match.
        it_timings         TYPE zif_ave_acr_types=>ty_t_part_timings OPTIONAL
      RETURNING
        VALUE(result)      TYPE ty_result.

    "! Part keys (`;`-joined, same format as ZCL_AVE_ACR_PREPARE=>PART_KEY) of
    "! every part in the given bands — feeds PREPARE_CODE_REVIEW directly.
    CLASS-METHODS band_keys
      IMPORTING
        it_metrics    TYPE ty_t_metric
        iv_bands      TYPE string DEFAULT 'LM'
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS count_band
      IMPORTING
        it_metrics    TYPE ty_t_metric
        iv_bands      TYPE string DEFAULT 'LM'
      RETURNING
        VALUE(result) TYPE i.

    "! Human-readable duration from milliseconds: seconds with one decimal up to
    "! ten minutes (`12.4s`, `126.7s`), `m`/`h` above that for scope totals.
    "! Single parts finish in seconds, where whole seconds hide the differences.
    CLASS-METHODS format_ms
      IMPORTING
        iv_ms         TYPE i
      RETURNING
        VALUE(result) TYPE string.

    "! Same for a value already in whole seconds.
    CLASS-METHODS format_secs
      IMPORTING
        iv_secs       TYPE i
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS to_html
      IMPORTING
        iv_object_name TYPE string
        is_result      TYPE ty_result
      RETURNING
        VALUE(result)  TYPE string.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_vrsd_cnt,
        objtype TYPE versobjtyp,
        objname TYPE versobjnam,
        cnt     TYPE i,
      END OF ty_vrsd_cnt.
    TYPES ty_t_vrsd_cnt TYPE STANDARD TABLE OF ty_vrsd_cnt WITH DEFAULT KEY.
    TYPES ty_r_objtype TYPE RANGE OF versobjtyp.
    TYPES ty_r_objname TYPE RANGE OF versobjnam.
    TYPES ty_r_korrnum TYPE RANGE OF trkorr.

    TYPES ty_t_korrnum TYPE SORTED TABLE OF trkorr WITH UNIQUE KEY table_line.

    "! Which of the korrnums actually present in VRSD belong to the reviewed
    "! request. A VRSD korrnum is not necessarily the request itself: it is
    "! usually the S/R task that was released, and it can just as well be a
    "! transport of copies. Both are resolved to their parent K and compared
    "! there — comparing korrnums directly finds nothing in either case.
    CLASS-METHODS scope_korrnums
      IMPORTING
        it_filter_korrnums TYPE zif_ave_object=>ty_t_korr_range
        iv_filter_korrnum  TYPE trkorr
        it_candidates      TYPE ty_t_korrnum
      RETURNING
        VALUE(result)      TYPE ty_r_korrnum.

    "! VRSD object types a class expands into.
    CLASS-METHODS class_part_types
      RETURNING
        VALUE(result) TYPE ty_r_objtype.

    "! True when a VRSD entry belongs to the given class: the class name is
    "! padded with `=` (section includes) or blanks (METH) up to 30 characters.
    CLASS-METHODS is_class_part
      IMPORTING
        iv_objname    TYPE versobjnam
        iv_class      TYPE versobjnam
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS estimate_ms
      IMPORTING
        is_metric     TYPE ty_metric
        iv_blame      TYPE abap_bool
        iv_remote     TYPE abap_bool
      RETURNING
        VALUE(result) TYPE i.

    CLASS-METHODS band_of
      IMPORTING
        iv_ms         TYPE i
      RETURNING
        VALUE(result) TYPE ty_band.

    "! Measured duration in milliseconds. Payloads written before MSECS existed
    "! only carry whole seconds, so those are scaled up.
    CLASS-METHODS timing_ms
      IMPORTING
        is_timing     TYPE zif_ave_acr_types=>ty_part_timing
      RETURNING
        VALUE(result) TYPE i.

    "! Measured vs. predicted, in percent, clamped so one outlier cannot drag
    "! every other estimate along. 100 = nothing to calibrate from.
    CLASS-METHODS calib_factor
      IMPORTING
        iv_measured   TYPE p
        iv_modelled   TYPE p
      RETURNING
        VALUE(result) TYPE i.

    "! True when the selected request is an S or R task — in that case
    "! ZCL_AVE_VERSION_LIST=>LOAD keeps the full history (see its
    "! `lv_is_s_selection` branch), which makes blame replay every version.
    CLASS-METHODS is_task_scope
      IMPORTING
        it_filter_korrnums TYPE zif_ave_object=>ty_t_korr_range
        iv_filter_korrnum  TYPE trkorr
      RETURNING
        VALUE(result)      TYPE abap_bool.

    CLASS-METHODS esc
      IMPORTING
        iv_text       TYPE clike
      RETURNING
        VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_ave_acr_metrics IMPLEMENTATION.

  METHOD class_part_types.
    result = VALUE #(
      sign = 'I' option = 'EQ'
      ( low = 'CPUB' ) ( low = 'CPRO' ) ( low = 'CPRI' )
      ( low = 'CINC' ) ( low = 'CDEF' ) ( low = 'CLSD' )
      ( low = 'METH' ) ).
  ENDMETHOD.


  METHOD esc.
    result = escape( val = CONV string( iv_text ) format = cl_abap_format=>e_html_text ).
  ENDMETHOD.


  METHOD is_class_part.
    DATA(lv_class) = condense( CONV string( iv_class ) ).
    DATA(lv_name)  = CONV string( iv_objname ).
    DATA(lv_len)   = strlen( lv_class ).
    CHECK lv_len > 0.
    CHECK strlen( lv_name ) >= lv_len.
    CHECK lv_name(lv_len) = lv_class.

    " Exactly the class itself (CLSD), or a 30-character class name where no
    " padding character separates the suffix.
    IF strlen( lv_name ) = lv_len OR lv_len >= 30.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA(lv_sep) = lv_name+lv_len(1).
    result = xsdbool( lv_sep = '=' OR lv_sep = ` ` ).
  ENDMETHOD.


  METHOD scope_korrnums.
    DATA lt_selected TYPE ty_t_korrnum.
    DATA lt_target_k TYPE ty_t_korrnum.

    IF iv_filter_korrnum IS NOT INITIAL.
      INSERT iv_filter_korrnum INTO TABLE lt_selected.
    ENDIF.
    LOOP AT it_filter_korrnums INTO DATA(ls_korr)
      WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
      INSERT CONV trkorr( ls_korr-low ) INTO TABLE lt_selected.
    ENDLOOP.
    CHECK lt_selected IS NOT INITIAL.

    " The requests the user selected, reduced to their parent K. A selected S/R
    " task resolves to its K, a K to itself.
    LOOP AT lt_selected INTO DATA(lv_selected).
      INSERT lv_selected INTO TABLE lt_target_k.
      LOOP AT zcl_ave_request=>resolve_parent_k( lv_selected ) INTO DATA(ls_sel_parent)
        WHERE low IS NOT INITIAL.
        INSERT CONV trkorr( ls_sel_parent-low ) INTO TABLE lt_target_k.
      ENDLOOP.
    ENDLOOP.

    " Every korrnum that actually appears in VRSD for these objects, resolved the
    " same way: a released S/R task, the K itself, or a transport of copies whose
    " CORR/MERG entries name the K.
    LOOP AT it_candidates INTO DATA(lv_candidate).
      DATA(lv_in_scope) = xsdbool( line_exists( lt_target_k[ table_line = lv_candidate ] ) ).
      IF lv_in_scope = abap_false.
        LOOP AT zcl_ave_request=>resolve_parent_k( lv_candidate ) INTO DATA(ls_parent)
          WHERE low IS NOT INITIAL.
          IF line_exists( lt_target_k[ table_line = CONV trkorr( ls_parent-low ) ] ).
            lv_in_scope = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.
      CHECK lv_in_scope = abap_true.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_candidate ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_task_scope.
    DATA lr_scope TYPE RANGE OF trkorr.
    DATA lt_trf TYPE STANDARD TABLE OF e070-trfunction WITH DEFAULT KEY.

    IF iv_filter_korrnum IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = iv_filter_korrnum ) TO lr_scope.
    ENDIF.
    LOOP AT it_filter_korrnums INTO DATA(ls_korr)
      WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_korr-low ) TO lr_scope.
    ENDLOOP.
    CHECK lr_scope IS NOT INITIAL.

    SELECT trfunction FROM e070
      WHERE trkorr IN @lr_scope
      INTO TABLE @lt_trf.
    LOOP AT lt_trf TRANSPORTING NO FIELDS WHERE table_line = 'S' OR table_line = 'R'.
      result = abap_true.
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD collect.
    DATA lr_types TYPE RANGE OF versobjtyp.
    DATA lr_names TYPE RANGE OF versobjnam.
    DATA lt_cnt TYPE ty_t_vrsd_cnt.

    result-summary-trkorr = iv_trkorr.
    result-summary-blame  = iv_blame.
    result-summary-remote = iv_system.
    result-summary-full_history = is_task_scope(
      it_filter_korrnums = it_filter_korrnums
      iv_filter_korrnum  = iv_filter_korrnum ).

    " ── 1. One metric row per reviewable part, plus the VRSD lookup ranges ──
    LOOP AT it_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_part-type ) = abap_false.
        CONTINUE.
      ENDIF.
      " Never prepared, so never estimated either.
      IF zcl_ave_acr_prepare=>is_generated_class( ls_part-object_name ) = abap_true
         OR ( ls_part-class IS NOT INITIAL
          AND zcl_ave_acr_prepare=>is_generated_class( ls_part-class ) = abap_true ).
        CONTINUE.
      ENDIF.

      APPEND VALUE ty_metric(
        part_key     = |{ ls_part-type }~{ ls_part-object_name }|
        type         = ls_part-type
        object_name  = ls_part-object_name
        class        = ls_part-class
        display_name = COND #( WHEN ls_part-name IS NOT INITIAL
                               THEN ls_part-name
                               ELSE CONV string( ls_part-object_name ) )
        lines        = ls_part-rows ) TO result-metrics.

      CASE ls_part-type.
        WHEN 'CLAS'.
          " Class parts are stored under the class name plus a suffix
          " (`=`-padded section includes, blank-padded METH names).
          APPEND LINES OF class_part_types( ) TO lr_types.
          APPEND VALUE #( sign = 'I' option = 'CP' low = |{ ls_part-object_name }*| ) TO lr_names.
        WHEN 'FUGR'.
          " Function group includes: SAPL<area> and L<area>*.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = 'REPS' ) TO lr_types.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = |SAPL{ ls_part-object_name }| ) TO lr_names.
          APPEND VALUE #( sign = 'I' option = 'CP' low = |L{ ls_part-object_name }*| ) TO lr_names.
        WHEN OTHERS.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_part-type ) TO lr_types.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_part-object_name ) TO lr_names.
      ENDCASE.
    ENDLOOP.

    IF result-metrics IS INITIAL.
      RETURN.
    ENDIF.

    SORT lr_types BY low.
    DELETE ADJACENT DUPLICATES FROM lr_types COMPARING low.
    SORT lr_names BY option low.
    DELETE ADJACENT DUPLICATES FROM lr_names COMPARING option low.

    " ── 2. Version counts: one grouped read, both keys on the VRSD index ──
    DATA lt_scope_cnt TYPE ty_t_vrsd_cnt.

    IF lr_types IS NOT INITIAL AND lr_names IS NOT INITIAL.
      SELECT objtype, objname, COUNT(*) AS cnt
        FROM vrsd
        WHERE objtype IN @lr_types
          AND objname IN @lr_names
        GROUP BY objtype, objname
        INTO CORRESPONDING FIELDS OF TABLE @lt_cnt.

      " Same read restricted to the versions of the reviewed request: those are
      " the steps blame actually replays (baseline → new version), while the full
      " count above only drives the metadata load. Which korrnums qualify cannot
      " be derived from the request number alone — see SCOPE_KORRNUMS — so the
      " korrnums present for these objects are collected first.
      DATA lt_candidates TYPE ty_t_korrnum.
      SELECT DISTINCT korrnum
        FROM vrsd
        WHERE objtype IN @lr_types
          AND objname IN @lr_names
          AND korrnum <> @space
        INTO TABLE @DATA(lt_korr_rows).
      LOOP AT lt_korr_rows INTO DATA(ls_korr_row).
        INSERT CONV trkorr( ls_korr_row-korrnum ) INTO TABLE lt_candidates.
      ENDLOOP.

      DATA(lr_scope_korr) = scope_korrnums(
        it_filter_korrnums = it_filter_korrnums
        iv_filter_korrnum  = iv_filter_korrnum
        it_candidates      = lt_candidates ).
      IF lr_scope_korr IS NOT INITIAL.
        SELECT objtype, objname, COUNT(*) AS cnt
          FROM vrsd
          WHERE objtype IN @lr_types
            AND objname IN @lr_names
            AND korrnum IN @lr_scope_korr
          GROUP BY objtype, objname
          INTO CORRESPONDING FIELDS OF TABLE @lt_scope_cnt.

        " Which requests the in-scope versions sit under. Authorship in AVE is
        " not VRSD-AUTHOR: the replay attributes lines to OBJ_OWNER, the owner of
        " the task the version belongs to. For a version recorded under its
        " released S/R task — the usual case — that owner is exactly the AS4USER
        " of this korrnum, which the cached header already carries.
        SELECT objtype, objname, korrnum
          FROM vrsd
          WHERE objtype IN @lr_types
            AND objname IN @lr_names
            AND korrnum IN @lr_scope_korr
          GROUP BY objtype, objname, korrnum
          INTO TABLE @DATA(lt_scope_owners).
      ENDIF.
    ENDIF.

    " ── 3. Attribute the counts, fill missing line counts, model the cost ──
    DATA(lv_remote) = xsdbool( iv_system IS NOT INITIAL ).
    TYPES: BEGIN OF ty_model,
             nb TYPE i,
             bl TYPE i,
           END OF ty_model.
    DATA lt_model TYPE STANDARD TABLE OF ty_model WITH DEFAULT KEY.
    " Calibrated per mode: the model can be wrong by a different factor with and
    " without blame, and one shared factor would then fix neither.
    DATA lv_measured_nb TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_modelled_nb TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_measured_bl TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_modelled_bl TYPE p LENGTH 16 DECIMALS 2.

    LOOP AT result-metrics ASSIGNING FIELD-SYMBOL(<ls_metric>).
      CASE <ls_metric>-type.
        WHEN 'CLAS'.
          LOOP AT lt_cnt INTO DATA(ls_cnt_cls).
            CHECK ls_cnt_cls-objtype = 'CPUB' OR ls_cnt_cls-objtype = 'CPRO'
               OR ls_cnt_cls-objtype = 'CPRI' OR ls_cnt_cls-objtype = 'CINC'
               OR ls_cnt_cls-objtype = 'CDEF' OR ls_cnt_cls-objtype = 'CLSD'
               OR ls_cnt_cls-objtype = 'METH'.
            CHECK is_class_part(
              iv_objname = ls_cnt_cls-objname
              iv_class   = <ls_metric>-object_name ) = abap_true.
            <ls_metric>-versions  = <ls_metric>-versions + ls_cnt_cls-cnt.
            <ls_metric>-sub_parts = <ls_metric>-sub_parts + 1.
            READ TABLE lt_scope_cnt INTO DATA(ls_scope_cls)
              WITH KEY objtype = ls_cnt_cls-objtype objname = ls_cnt_cls-objname.
            IF sy-subrc = 0.
              <ls_metric>-vers_scope = <ls_metric>-vers_scope + ls_scope_cls-cnt.
            ENDIF.
          ENDLOOP.
        WHEN 'FUGR'.
          DATA(lv_fugr_incl) = |L{ <ls_metric>-object_name }|.
          DATA(lv_fugr_main) = |SAPL{ <ls_metric>-object_name }|.
          LOOP AT lt_cnt INTO DATA(ls_cnt_fugr) WHERE objtype = 'REPS'.
            CHECK ls_cnt_fugr-objname CP |{ lv_fugr_incl }*|
               OR ls_cnt_fugr-objname = lv_fugr_main.
            <ls_metric>-versions  = <ls_metric>-versions + ls_cnt_fugr-cnt.
            <ls_metric>-sub_parts = <ls_metric>-sub_parts + 1.
            READ TABLE lt_scope_cnt INTO DATA(ls_scope_fugr)
              WITH KEY objtype = ls_cnt_fugr-objtype objname = ls_cnt_fugr-objname.
            IF sy-subrc = 0.
              <ls_metric>-vers_scope = <ls_metric>-vers_scope + ls_scope_fugr-cnt.
            ENDIF.
          ENDLOOP.
        WHEN OTHERS.
          READ TABLE lt_cnt INTO DATA(ls_cnt)
            WITH KEY objtype = <ls_metric>-type objname = <ls_metric>-object_name.
          IF sy-subrc = 0.
            <ls_metric>-versions = ls_cnt-cnt.
          ENDIF.
          READ TABLE lt_scope_cnt INTO DATA(ls_scope_cnt)
            WITH KEY objtype = <ls_metric>-type objname = <ls_metric>-object_name.
          IF sy-subrc = 0.
            <ls_metric>-vers_scope = ls_scope_cnt-cnt.
          ENDIF.
          <ls_metric>-sub_parts = 1.
      ENDCASE.

      IF <ls_metric>-sub_parts = 0.
        <ls_metric>-sub_parts = 1.
      ENDIF.

      " At most one version attributes lines in the reviewed range, so there is
      " nothing to tell apart and PRECOMPUTE_PART takes the single-author path.
      " Only this case is claimed here.
      "
      " One version at most attributes lines — a single author by definition.
      IF <ls_metric>-vers_scope <= 1.
        <ls_metric>-solo_author = abap_true.
      ELSE.
        " Otherwise compare the task owners the replay would use.
        "
        " Keep-note (do not go back to VRSD-AUTHOR): counting DISTINCT AUTHOR of
        " the in-scope versions answers a different question and declared a
        " single author where the replay saw several — ZCL_HR_PIF_UIVIS_HELPER
        " was predicted at 1.2 s and took 38.0 s because of it. The owner of the
        " version's request is the value that matches.
        DATA(lv_owner_cnt) = 0.
        DATA(lv_seen_owner) = VALUE e070-as4user( ).
        LOOP AT lt_scope_owners INTO DATA(ls_scope_owner).
          CASE <ls_metric>-type.
            WHEN 'CLAS'.
              CHECK is_class_part( iv_objname = ls_scope_owner-objname
                                   iv_class   = <ls_metric>-object_name ) = abap_true.
            WHEN 'FUGR'.
              CHECK ls_scope_owner-objname CP |L{ <ls_metric>-object_name }*|
                 OR ls_scope_owner-objname = |SAPL{ <ls_metric>-object_name }|.
            WHEN OTHERS.
              CHECK ls_scope_owner-objtype = <ls_metric>-type
                AND ls_scope_owner-objname = <ls_metric>-object_name.
          ENDCASE.
          DATA(lv_owner) = zcl_ave_request=>get_header(
            CONV #( ls_scope_owner-korrnum ) )-as4user.
          CHECK lv_owner IS NOT INITIAL.
          IF lv_seen_owner IS INITIAL.
            lv_seen_owner = lv_owner.
            lv_owner_cnt  = 1.
          ELSEIF lv_seen_owner <> lv_owner.
            lv_owner_cnt = 2.
            EXIT.
          ENDIF.
        ENDLOOP.
        <ls_metric>-solo_author = xsdbool( lv_owner_cnt = 1 ).
      ENDIF.

      IF <ls_metric>-lines = 0.
        <ls_metric>-lines = zcl_ave_popup_data=>get_active_line_count(
          i_type = <ls_metric>-type
          i_name = <ls_metric>-object_name ).
      ENDIF.

      " Aggregates (CLAS/FUGR) have no single source: assume an average part size
      " so the estimate still scales with the number of technical parts.
      <ls_metric>-lines_est = COND i(
        WHEN <ls_metric>-lines > 0 THEN <ls_metric>-lines
        ELSE <ls_metric>-sub_parts * gv_assumed_lines ).

      IF it_obj_stats IS NOT INITIAL.
        IF <ls_metric>-type = 'CLAS'.
          READ TABLE it_obj_stats TRANSPORTING NO FIELDS
            WITH KEY class_name = <ls_metric>-object_name.
        ELSE.
          READ TABLE it_obj_stats TRANSPORTING NO FIELDS
            WITH KEY objtype = <ls_metric>-type obj_name = <ls_metric>-object_name.
        ENDIF.
        <ls_metric>-cached = xsdbool( sy-subrc = 0 ).
      ENDIF.

      " Both modes are modelled: the cost of blame is the whole reason to look
      " at this page before deciding how to run Prepare.
      DATA(ls_model) = VALUE ty_model(
        nb = estimate_ms( is_metric = <ls_metric>
                            iv_blame  = abap_false
                            iv_remote = lv_remote )
        bl = estimate_ms( is_metric = <ls_metric>
                            iv_blame  = abap_true
                            iv_remote = lv_remote ) ).
      APPEND ls_model TO lt_model.
      <ls_metric>-est_nb_ms = ls_model-nb.
      <ls_metric>-est_bl_ms = ls_model-bl.

      " A measurement of this part under the same blame setting beats any model
      " value — and tells the model how far off it is for this system.
      READ TABLE it_timings INTO DATA(ls_timing_nb)
        WITH KEY part_key = <ls_metric>-part_key blame = abap_false.
      IF sy-subrc = 0.
        <ls_metric>-measured_nb = abap_true.
        <ls_metric>-est_nb_ms      = timing_ms( ls_timing_nb ).
        lv_measured_nb = lv_measured_nb + timing_ms( ls_timing_nb ).
        " Prefer the prediction stored with the measurement: it was made on the
        " same input. Fall back to the model just computed for older payloads.
        lv_modelled_nb = lv_modelled_nb + COND i(
          WHEN ls_timing_nb-est_nb_ms > 0 THEN ls_timing_nb-est_nb_ms ELSE ls_model-nb ).
      ENDIF.

      READ TABLE it_timings INTO DATA(ls_timing_bl)
        WITH KEY part_key = <ls_metric>-part_key blame = abap_true.
      IF sy-subrc = 0.
        <ls_metric>-measured_bl = abap_true.
        <ls_metric>-est_bl_ms      = timing_ms( ls_timing_bl ).
        lv_measured_bl = lv_measured_bl + timing_ms( ls_timing_bl ).
        lv_modelled_bl = lv_modelled_bl + COND i(
          WHEN ls_timing_bl-est_bl_ms > 0 THEN ls_timing_bl-est_bl_ms ELSE ls_model-bl ).
      ENDIF.
    ENDLOOP.

    " ── 4. Calibrate the unmeasured parts against the measured ones ──
    DATA(lv_calib_nb) = calib_factor( iv_measured = lv_measured_nb
                                      iv_modelled = lv_modelled_nb ).
    DATA(lv_calib_bl) = calib_factor( iv_measured = lv_measured_bl
                                      iv_modelled = lv_modelled_bl ).
    " A mode without measurements of its own borrows the other one's factor:
    " both share the version-metadata part of the model.
    IF lv_calib_nb = 100 AND lv_calib_bl <> 100.
      lv_calib_nb = lv_calib_bl.
    ELSEIF lv_calib_bl = 100 AND lv_calib_nb <> 100.
      lv_calib_bl = lv_calib_nb.
    ENDIF.
    result-summary-calib_pct = COND i(
      WHEN iv_blame = abap_true THEN lv_calib_bl ELSE lv_calib_nb ).

    LOOP AT result-metrics ASSIGNING <ls_metric>.
      DATA(lv_idx) = sy-tabix.
      READ TABLE lt_model INTO DATA(ls_raw_model) INDEX lv_idx.
      IF sy-subrc = 0.
        " Packed again: a modelled value in milliseconds times the factor in
        " percent overflows an integer for anything above a few minutes.
        DATA lv_scaled TYPE p LENGTH 16 DECIMALS 2.
        IF <ls_metric>-measured_nb = abap_false AND lv_calib_nb <> 100.
          lv_scaled = CONV decfloat34( ls_raw_model-nb ) * lv_calib_nb / 100.
          <ls_metric>-est_nb_ms = CONV i( lv_scaled ).
        ENDIF.
        IF <ls_metric>-measured_bl = abap_false AND lv_calib_bl <> 100.
          lv_scaled = CONV decfloat34( ls_raw_model-bl ) * lv_calib_bl / 100.
          <ls_metric>-est_bl_ms = CONV i( lv_scaled ).
        ENDIF.

        " One mode measured, the other not: carry the measurement over and add
        " only the modelled difference between the modes. Scaling the two model
        " values independently lets the calibration push the blame estimate below
        " the measured no-blame time, which cannot happen — blame is extra work
        " on top of the same run, never a shortcut.
        IF <ls_metric>-measured_nb = abap_true AND <ls_metric>-measured_bl = abap_false.
          lv_scaled = CONV decfloat34( ls_raw_model-bl - ls_raw_model-nb ) * lv_calib_bl / 100.
          <ls_metric>-est_bl_ms = <ls_metric>-est_nb_ms + CONV i( lv_scaled ).
        ELSEIF <ls_metric>-measured_bl = abap_true AND <ls_metric>-measured_nb = abap_false.
          lv_scaled = CONV decfloat34( ls_raw_model-bl - ls_raw_model-nb ) * lv_calib_nb / 100.
          <ls_metric>-est_nb_ms = nmax( val1 = <ls_metric>-est_bl_ms - CONV i( lv_scaled )
                                        val2 = 0 ).
        ENDIF.

        " Whatever happens above, blame can never come out cheaper.
        IF <ls_metric>-est_bl_ms < <ls_metric>-est_nb_ms.
          <ls_metric>-est_bl_ms = <ls_metric>-est_nb_ms.
        ENDIF.
      ENDIF.

      " The active blame setting decides which of the two drives the band and
      " the Prepare-by-band buttons.
      IF iv_blame = abap_true.
        <ls_metric>-est_ms = <ls_metric>-est_bl_ms.
        <ls_metric>-measured = <ls_metric>-measured_bl.
        READ TABLE it_timings INTO DATA(ls_prev_bl)
          WITH KEY part_key = <ls_metric>-part_key blame = abap_true.
        IF sy-subrc = 0.
          <ls_metric>-est_before_ms = ls_prev_bl-est_bl_ms.
        ENDIF.
      ELSE.
        <ls_metric>-est_ms = <ls_metric>-est_nb_ms.
        <ls_metric>-measured = <ls_metric>-measured_nb.
        READ TABLE it_timings INTO DATA(ls_prev_nb)
          WITH KEY part_key = <ls_metric>-part_key blame = abap_false.
        IF sy-subrc = 0.
          <ls_metric>-est_before_ms = ls_prev_nb-est_nb_ms.
        ENDIF.
      ENDIF.
      IF <ls_metric>-measured = abap_true.
        result-summary-parts_measured = result-summary-parts_measured + 1.
        result-summary-est_ms_meas = result-summary-est_ms_meas + <ls_metric>-est_ms.
      ELSE.
        result-summary-est_ms_model = result-summary-est_ms_model + <ls_metric>-est_ms.
      ENDIF.
      <ls_metric>-band = band_of( <ls_metric>-est_ms ).

      result-summary-parts_total    = result-summary-parts_total + 1.
      result-summary-versions_total = result-summary-versions_total + <ls_metric>-versions.
      result-summary-lines_total    = result-summary-lines_total + <ls_metric>-lines.
      IF <ls_metric>-lines = 0.
        result-summary-lines_assumed = result-summary-lines_assumed + <ls_metric>-lines_est.
      ENDIF.
      result-summary-est_ms       = result-summary-est_ms + <ls_metric>-est_ms.
      result-summary-est_ms_nb    = result-summary-est_ms_nb + <ls_metric>-est_nb_ms.
      result-summary-est_ms_bl    = result-summary-est_ms_bl + <ls_metric>-est_bl_ms.
      IF <ls_metric>-cached = abap_true.
        result-summary-parts_cached = result-summary-parts_cached + 1.
      ENDIF.
      CASE <ls_metric>-band.
        WHEN gc_band-heavy.
          result-summary-parts_heavy    = result-summary-parts_heavy + 1.
          result-summary-est_ms_heavy = result-summary-est_ms_heavy + <ls_metric>-est_ms.
        WHEN gc_band-medium.
          result-summary-parts_medium   = result-summary-parts_medium + 1.
          result-summary-est_ms_light = result-summary-est_ms_light + <ls_metric>-est_ms.
        WHEN OTHERS.
          result-summary-parts_light    = result-summary-parts_light + 1.
          result-summary-est_ms_light = result-summary-est_ms_light + <ls_metric>-est_ms.
      ENDCASE.
    ENDLOOP.

    SORT result-metrics BY est_ms DESCENDING versions DESCENDING.
  ENDMETHOD.


  METHOD estimate_ms.
    " Per technical part, then scaled by their number. Intermediate values can
    " exceed the integer range (lines² for a 30k-line include), so the whole
    " calculation runs in packed arithmetic.
    DATA lv_ms TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_vpp TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_lpp TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_steps TYPE p LENGTH 16 DECIMALS 2.

    DATA(lv_parts) = COND i( WHEN is_metric-sub_parts > 0 THEN is_metric-sub_parts ELSE 1 ).
    lv_vpp = is_metric-versions / lv_parts.
    lv_lpp = is_metric-lines_est / lv_parts.

    " Base per object, then the totals that really scale: version metadata is
    " loaded for the COMPLETE history (ZCL_AVE_VERSION_LIST=>LOAD builds a
    " ZCL_AVE_VERSION per VRSD row before any scope filtering), and the diff plus
    " both HTML renders scale with the source size.
    lv_ms = gv_obj_ms
          + lv_parts * gv_part_ms
          + is_metric-versions * gv_ver_ms
          + is_metric-lines_est * gv_line_ms.

    " Blame replays the reviewed range only: BUILD_BLAME_MAP filters the versions
    " to [baseline .. new]. That is every version of the request, plus the one
    " step leading from the baseline into it — a request whose object carries
    " many versions (transports of copies, several released tasks) therefore
    " replays that many steps, not one.
    lv_steps = is_metric-vers_scope / lv_parts + 1.
    IF lv_steps > lv_vpp AND lv_vpp >= 1.
      lv_steps = lv_vpp.
    ENDIF.

    " Aggregates are measured far below what the per-part step count suggests
    " (a 26-part class with 3643 versions took 14.6 s, not the 19 min the step
    " model predicted): their parts either have no baseline or share one author,
    " so the replay is skipped. Charge one step per part, no more.
    IF is_metric-type = 'CLAS' OR is_metric-type = 'FUGR'.
      lv_steps = 1.
    ENDIF.

    " Cases where PRECOMPUTE_PART never reaches the replay at all:
    "  - dictionary objects leave through their structured-comparison branch;
    "  - every version belongs to the request, so no baseline exists and the
    "    object is treated as newly created;
    "  - at most one version attributes lines (single author by definition).
    DATA(lv_no_replay) = xsdbool(
         is_metric-type = 'TABD' OR is_metric-type = 'DOMD' OR is_metric-type = 'DTED'
      OR ( is_metric-versions > 0 AND is_metric-vers_scope >= is_metric-versions )
      OR is_metric-solo_author = abap_true ).

    IF iv_blame = abap_true AND lv_vpp > 1 AND lv_no_replay = abap_false.
      " Per part and step: read that version's source, diff it against the
      " previous one, and update the blame map. The map is deleted from with a
      " linear scan, which is what makes the last term grow with lines².
      lv_ms = lv_ms + lv_parts * lv_steps
                    * ( gv_blame_step_ms
                      + lv_lpp * gv_blame_lin_um / 1000
                      + lv_lpp * lv_lpp * gv_blame_sq_um / 1000000 ).
    ENDIF.

    IF iv_remote = abap_true.
      lv_ms = lv_ms * gv_remote_pct / 100.
    ENDIF.

    result = CONV i( lv_ms ).
  ENDMETHOD.


  METHOD timing_ms.
    result = COND i(
      WHEN is_timing-msecs > 0 THEN is_timing-msecs
      ELSE is_timing-secs * 1000 ).
  ENDMETHOD.


  METHOD calib_factor.
    result = 100.
    CHECK iv_measured > 0 AND iv_modelled > 0.

    result = CONV i( iv_measured * 100 / iv_modelled ).
    " The model can be off by a large factor in either direction (it was ~4x too
    " pessimistic before the request-header cache landed), so the clamp only has
    " to stop absurd values, not keep the factor near 100.
    IF result < 5.
      result = 5.
    ELSEIF result > 2000.
      result = 2000.
    ENDIF.
  ENDMETHOD.


  METHOD band_of.
    result = COND ty_band(
      WHEN iv_ms >= gv_heavy_secs * 1000  THEN gc_band-heavy
      WHEN iv_ms >= gv_medium_secs * 1000 THEN gc_band-medium
      ELSE                                     gc_band-light ).
  ENDMETHOD.


  METHOD band_keys.
    LOOP AT it_metrics INTO DATA(ls_metric).
      CHECK iv_bands CS ls_metric-band.
      result = COND string(
        WHEN result IS INITIAL THEN ls_metric-part_key
        ELSE |{ result };{ ls_metric-part_key }| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD count_band.
    LOOP AT it_metrics INTO DATA(ls_metric).
      CHECK iv_bands CS ls_metric-band.
      result = result + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD format_ms.
    " Seconds with one decimal up to ten minutes — that covers every single
    " object, including the heavy ones, and keeps small differences visible.
    " Only the totals, which run into hours, switch to m/h.
    IF iv_ms < 600000.
      DATA lv_tenths TYPE p LENGTH 8 DECIMALS 1.
      lv_tenths = iv_ms / 1000.
      result = |{ lv_tenths }s|.
      RETURN.
    ENDIF.
    result = format_secs( iv_ms / 1000 ).
  ENDMETHOD.


  METHOD format_secs.
    DATA(lv_secs) = iv_secs.
    IF lv_secs < 60.
      result = |{ lv_secs }s|.
      RETURN.
    ENDIF.
    DATA(lv_min) = lv_secs DIV 60.
    DATA(lv_rest) = lv_secs MOD 60.
    IF lv_min < 60.
      result = |{ lv_min }m { lv_rest }s|.
      RETURN.
    ENDIF.
    DATA(lv_hrs) = lv_min DIV 60.
    DATA(lv_min_rest) = lv_min MOD 60.
    result = |{ lv_hrs }h { lv_min_rest }m|.
  ENDMETHOD.


  METHOD to_html.
    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:10px}` &&
      `table{border-collapse:collapse;width:100%;margin-bottom:16px;font-size:12px}` &&
      `th{background:#3498db;color:#fff;padding:5px 10px;text-align:left;white-space:nowrap}` &&
      `td{padding:4px 10px;border-bottom:1px solid #eee;white-space:nowrap}` &&
      `td.nr,th.nr{text-align:right}` &&
      `.sum{background:#f7f9fa;border:1px solid #dfe6e9;border-radius:4px;padding:10px 14px;margin-bottom:14px}` &&
      `.sum b{color:#2c3e50}` &&
      `.go{display:inline-block;background:#27ae60;color:#fff;text-decoration:none;` &&
      `font:bold 13px Consolas,monospace;border-radius:4px;padding:7px 18px;margin-right:8px}` &&
      `.go2{background:#7f8c8d}.go3{background:#e67e22}` &&
      `.back{position:fixed;top:8px;left:8px;z-index:999;background:#3498db;color:#fff;` &&
      `text-decoration:none;font:bold 12px Consolas,monospace;border-radius:4px;padding:6px 14px}` &&
      `.H{color:#c0392b;font-weight:bold}.M{color:#e67e22}.L{color:#27ae60}` &&
      `tr.h td{background:#fdf1f0}` &&
      `tr.tot td{background:#eef3f7;border-top:2px solid #3498db;border-bottom:none}` &&
      `th.act{background:#2c3e50}td.meas{font-weight:bold;color:#2c3e50}` &&
      `.cached{color:#777}.warn{background:#fef5e7;border-left:4px solid #e67e22;padding:8px 12px;margin-bottom:14px}`.

    DATA(ls_sum) = is_result-summary.
    DATA(lv_light_cnt) = count_band( it_metrics = is_result-metrics iv_bands = 'LM' ).
    DATA(lv_heavy_cnt) = count_band( it_metrics = is_result-metrics iv_bands = 'H' ).

    DATA(lv_warn) = ``.
    IF ls_sum-full_history = abap_true.
      lv_warn =
        `<div class="warn">An S/R task is selected, so the version list is not trimmed to the ` &&
        `request: metadata for the <b>complete history</b> of every object is loaded (a request ` &&
        `lookup per version), which dominates the numbers below. Blame itself is not affected — ` &&
        `it replays only the range from the baseline to the new version. Reviewing the parent K ` &&
        `request, or setting a "date from", shortens the version load.</div>`.
    ENDIF.

    DATA(lv_cached_txt) = COND string(
      WHEN ls_sum-parts_cached > 0 THEN |, { ls_sum-parts_cached } already computed|
      ELSE `` ).
    " Aggregates carry no single source, so their size is assumed, not counted.
    DATA(lv_assumed_txt) = COND string(
      WHEN ls_sum-lines_assumed > 0
      THEN | counted (+~{ ls_sum-lines_assumed } assumed for class/group rows)|
      ELSE `` ).
    DATA(lv_calib_txt) = COND string(
      WHEN ls_sum-parts_measured > 0
      THEN |<br>{ ls_sum-parts_measured } object(s) timed in an earlier run| &&
           |{ COND string( WHEN ls_sum-calib_pct <> 100
                           THEN |; the model for the rest is scaled to { ls_sum-calib_pct }%|
                           ELSE `` ) }|
      ELSE `<br>No measurements yet — estimates are pure model values` ).
    DATA(lv_blame_txt) = COND string(
      WHEN ls_sum-blame = abap_true THEN `on` ELSE `off` ).
    " Totals mix measured and modelled parts; the tilde says so as long as at
    " least one object has never been prepared.
    DATA(lv_tilde) = COND string(
      WHEN ls_sum-parts_measured < ls_sum-parts_total THEN `~` ELSE `` ).

    " Spelling the split out: a total that disagrees with the stopwatch of the
    " last run does so because of the objects that were never measured.
    DATA(lv_unmeasured) = ls_sum-parts_total - ls_sum-parts_measured.
    DATA(lv_split_txt) = COND string(
      WHEN ls_sum-parts_measured > 0 AND lv_unmeasured > 0
      THEN |<br>Of that, <b>{ format_ms( ls_sum-est_ms_meas ) }</b> measured on | &&
           |{ ls_sum-parts_measured } object(s), | &&
           |<b>~{ format_ms( ls_sum-est_ms_model ) }</b> still modelled on { lv_unmeasured }|
      WHEN ls_sum-parts_measured > 0
      THEN |<br>All { ls_sum-parts_measured } object(s) measured — no model value left|
      ELSE `` ).

    " The column matching the active blame setting is highlighted.
    DATA(lv_th_nb) = COND string(
      WHEN ls_sum-blame = abap_false THEN ` class="nr act"` ELSE ` class="nr"` ).
    DATA(lv_th_bl) = COND string(
      WHEN ls_sum-blame = abap_true THEN ` class="nr act"` ELSE ` class="nr"` ).

    " What blame actually costs on this scope — the toolbar toggle switches it.
    DATA(lv_blame_cost_txt) = COND string(
      WHEN ls_sum-est_ms_bl > ls_sum-est_ms_nb
      THEN | &rarr; blame adds <b>{ format_ms( ls_sum-est_ms_bl - ls_sum-est_ms_nb ) }</b>|
      ELSE `` ).
    DATA(lv_remote_txt) = COND string(
      WHEN ls_sum-remote IS NOT INITIAL THEN |, retrofit against <b>{ esc( ls_sum-remote ) }</b>|
      ELSE `` ).

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ lv_css }</style></head><body>| &&
      |<h2>Code Review metrics - { esc( iv_object_name ) }</h2>| &&
      `<a class="back" href="sapevent:back~0">Back</a>` &&
      lv_warn &&
      `<div class="sum">` &&
      |<b>{ ls_sum-parts_total }</b> reviewable object(s), | &&
      |<b>{ ls_sum-versions_total }</b> version(s), | &&
      |<b>{ ls_sum-lines_total }</b> source line(s){ lv_assumed_txt }{ lv_cached_txt }<br>| &&
      |Blame is <b>{ lv_blame_txt }</b>{ lv_remote_txt }<br>| &&
      |Total <b>without blame { lv_tilde }{ format_ms( ls_sum-est_ms_nb ) }</b>, | &&
      |<b>with blame { lv_tilde }{ format_ms( ls_sum-est_ms_bl ) }</b>{ lv_blame_cost_txt }<br>| &&
      |At the current setting: <b>{ lv_tilde }{ format_ms( ls_sum-est_ms ) }</b> | &&
      |(light+medium { lv_tilde }{ format_ms( ls_sum-est_ms_light ) }, | &&
      |heavy { lv_tilde }{ format_ms( ls_sum-est_ms_heavy ) })| &&
      lv_split_txt &&
      lv_calib_txt &&
      `</div>` &&
      |<p><a class="go" href="sapevent:prepare_band~LM">Prepare light + medium ({ lv_light_cnt })</a>| &&
      |<a class="go go3" href="sapevent:prepare_band~H">Prepare heavy only ({ lv_heavy_cnt })</a>| &&
      |<a class="go go2" href="sapevent:prepare_selected~0">Prepare all ({ ls_sum-parts_total })</a>| &&
      `<a class="go go2" href="sapevent:recalcpick~0">Pick manually</a></p>` &&
      `<table><tr><th>Band</th><th>Type</th><th>Object</th><th>Class</th>` &&
      `<th class="nr" title="Versions in VRSD — drives the metadata load">Versions</th>` &&
      `<th class="nr" title="Versions of the reviewed request — drives the blame replay">In scope</th>` &&
      `<th class="nr">Parts</th><th class="nr">Lines</th>` &&
      |<th{ lv_th_nb }>Time no blame</th>| &&
      |<th{ lv_th_bl }>Time blame</th>| &&
      `<th class="nr" title="What the model predicted before the measured run">Predicted</th>` &&
      `<th class="nr" title="Measured vs. predicted">Err</th>` &&
      `<th>Source</th><th>Status</th></tr>`.

    LOOP AT is_result-metrics INTO DATA(ls_metric).
      DATA(lv_rowcls) = COND string( WHEN ls_metric-band = gc_band-heavy THEN ` class="h"` ELSE `` ).
      DATA(lv_lines_txt) = COND string(
        WHEN ls_metric-lines > 0 THEN |{ ls_metric-lines }|
        ELSE |~{ ls_metric-lines_est }| ).
      DATA(lv_status) = COND string(
        WHEN ls_metric-cached = abap_true THEN `<span class="cached">cached</span>`
        ELSE `new` ).
      " Prediction and its error get their own narrow columns — folded into the
      " Source text they pushed the table past the edge of the screen.
      DATA(lv_pred_cell) = `<td class="nr"></td>`.
      DATA(lv_err_cell)  = `<td class="nr"></td>`.
      IF ls_metric-measured = abap_true AND ls_metric-est_before_ms > 0.
        " Packed: milliseconds times 100 leaves the integer range for a part
        " that took more than a few minutes.
        DATA lv_err_calc TYPE p LENGTH 16 DECIMALS 2.
        lv_err_calc = CONV decfloat34( ls_metric-est_ms - ls_metric-est_before_ms ) * 100
                    / ls_metric-est_before_ms.
        DATA(lv_err_pct) = CONV i( lv_err_calc ).
        DATA(lv_err_cls) = COND string(
          WHEN abs( lv_err_pct ) >= 50 THEN ` class="nr M"` ELSE ` class="nr"` ).
        lv_pred_cell = |<td class="nr">{ format_ms( ls_metric-est_before_ms ) }</td>|.
        lv_err_cell  = |<td{ lv_err_cls }>{ COND string( WHEN lv_err_pct > 0 THEN `+` ELSE `` ) }| &&
                       |{ lv_err_pct }%</td>|.
      ENDIF.
      DATA(lv_solo_txt) = COND string(
        WHEN ls_metric-solo_author = abap_true
        THEN ` <span class="cached">· one author, no replay</span>`
        ELSE `` ).
      DATA(lv_source) = COND string(
        WHEN ls_metric-measured_nb = abap_true AND ls_metric-measured_bl = abap_true
        THEN |measured{ lv_solo_txt }|
        WHEN ls_metric-measured_nb = abap_true THEN |measured (no blame){ lv_solo_txt }|
        WHEN ls_metric-measured_bl = abap_true THEN |measured (blame){ lv_solo_txt }|
        ELSE |<span class="cached">model</span>{ lv_solo_txt }| ).
      DATA(lv_td_nb) = COND string(
        WHEN ls_metric-measured_nb = abap_true THEN ` class="nr meas"` ELSE ` class="nr"` ).
      DATA(lv_td_bl) = COND string(
        WHEN ls_metric-measured_bl = abap_true THEN ` class="nr meas"` ELSE ` class="nr"` ).

      result = result &&
        |<tr{ lv_rowcls }>| &&
        |<td class="{ ls_metric-band }">{ ls_metric-band }</td>| &&
        |<td>{ esc( ls_metric-type ) }</td>| &&
        |<td><b>{ esc( ls_metric-display_name ) }</b></td>| &&
        |<td>{ esc( ls_metric-class ) }</td>| &&
        |<td class="nr">{ ls_metric-versions }</td>| &&
        |<td class="nr">{ ls_metric-vers_scope }</td>| &&
        |<td class="nr">{ ls_metric-sub_parts }</td>| &&
        |<td class="nr">{ lv_lines_txt }</td>| &&
        |<td{ lv_td_nb }>{ COND string( WHEN ls_metric-measured_nb = abap_false THEN `~` ELSE `` ) }| &&
        |{ format_ms( ls_metric-est_nb_ms ) }</td>| &&
        |<td{ lv_td_bl }>{ COND string( WHEN ls_metric-measured_bl = abap_false THEN `~` ELSE `` ) }| &&
        |{ format_ms( ls_metric-est_bl_ms ) }</td>| &&
        lv_pred_cell &&
        lv_err_cell &&
        |<td>{ lv_source }</td>| &&
        |<td>{ lv_status }</td>| &&
        `</tr>`.
    ENDLOOP.

    IF is_result-metrics IS INITIAL.
      result = result && `<tr><td colspan="14">No reviewable objects in this scope</td></tr>`.
    ELSE.
      " Totals row: the same numbers as the summary box, at the end of the list
      " where the decision "can this run in the dialog" is actually made.
      DATA lv_sum_scope TYPE i.
      DATA lv_sum_parts TYPE i.
      LOOP AT is_result-metrics INTO DATA(ls_total).
        lv_sum_scope = lv_sum_scope + ls_total-vers_scope.
        lv_sum_parts = lv_sum_parts + ls_total-sub_parts.
      ENDLOOP.

      result = result &&
        `<tr class="tot">` &&
        |<td colspan="4"><b>Total &mdash; { ls_sum-parts_total } object(s)</b>| &&
        |{ COND string( WHEN ls_sum-parts_heavy > 0
                        THEN |, { ls_sum-parts_heavy } heavy ({ format_ms( ls_sum-est_ms_heavy ) })|
                        ELSE `` ) }</td>| &&
        |<td class="nr"><b>{ ls_sum-versions_total }</b></td>| &&
        |<td class="nr"><b>{ lv_sum_scope }</b></td>| &&
        |<td class="nr"><b>{ lv_sum_parts }</b></td>| &&
        |<td class="nr"><b>{ ls_sum-lines_total }</b></td>| &&
        |<td class="nr"><b>{ lv_tilde }{ format_ms( ls_sum-est_ms_nb ) }</b></td>| &&
        |<td class="nr"><b>{ lv_tilde }{ format_ms( ls_sum-est_ms_bl ) }</b></td>| &&
        `<td colspan="4"></td>` &&
        `</tr>`.
    ENDIF.

    result = result &&
      `</table>` &&
      `<p style="color:#777;font-size:11px">A bold time without <b>~</b> is measured: it is how ` &&
      `long the last Prepare of that object actually took, and <i>Source</i> shows what had been ` &&
      `predicted for it and by how much the prediction was off. A time with <b>~</b> is still a ` &&
      `model value — derived from version count, source size and blame replay depth, rescaled by ` &&
      `the factor observed on the measured objects.</p>` &&
      `</body></html>`.
  ENDMETHOD.

ENDCLASS.
