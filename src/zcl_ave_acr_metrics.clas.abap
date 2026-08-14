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
        "! technical parts of the object. Main driver of the runtime.
        versions     TYPE i,
        "! Technical parts the object expands into (1 for a plain part).
        sub_parts    TYPE i,
        "! Active source lines; 0 when unknown (CLAS/FUGR aggregates).
        lines        TYPE i,
        "! Lines actually used for the estimate (assumed value when unknown).
        lines_est    TYPE i,
        cached       TYPE abap_bool,
        est_secs     TYPE i,
        "! True when EST_SECS is a measurement of an earlier Prepare run of this
        "! very part, not a model value.
        measured     TYPE abap_bool,
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
        lines_total    TYPE i,
        est_secs       TYPE i,
        est_secs_light TYPE i,
        est_secs_heavy TYPE i,
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

    "! Estimate model. CLASS-DATA, not CONSTANTS: once background runs record
    "! real durations these become calibrated from measurements.
    CLASS-DATA gv_part_ms TYPE i VALUE 300 ##NO_TEXT.          " fixed cost per part
    CLASS-DATA gv_ver_ms TYPE i VALUE 150 ##NO_TEXT.           " metadata of one version
    CLASS-DATA gv_line_ms TYPE i VALUE 1 ##NO_TEXT.            " diff + both html renders
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

    "! Human-readable duration, e.g. `2h 05m`, `7m 30s`, `12s`.
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

    CLASS-METHODS estimate_secs
      IMPORTING
        is_metric     TYPE ty_metric
        iv_blame      TYPE abap_bool
        iv_remote     TYPE abap_bool
      RETURNING
        VALUE(result) TYPE i.

    CLASS-METHODS band_of
      IMPORTING
        iv_secs       TYPE i
      RETURNING
        VALUE(result) TYPE ty_band.

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
    IF lr_types IS NOT INITIAL AND lr_names IS NOT INITIAL.
      SELECT objtype, objname, COUNT(*) AS cnt
        FROM vrsd
        WHERE objtype IN @lr_types
          AND objname IN @lr_names
        GROUP BY objtype, objname
        INTO CORRESPONDING FIELDS OF TABLE @lt_cnt.
    ENDIF.

    " ── 3. Attribute the counts, fill missing line counts, model the cost ──
    DATA(lv_remote) = xsdbool( iv_system IS NOT INITIAL ).
    DATA lt_model TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
    DATA lv_sum_measured TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_sum_modelled TYPE p LENGTH 16 DECIMALS 2.

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
          ENDLOOP.
        WHEN 'FUGR'.
          DATA(lv_fugr_incl) = |L{ <ls_metric>-object_name }|.
          DATA(lv_fugr_main) = |SAPL{ <ls_metric>-object_name }|.
          LOOP AT lt_cnt INTO DATA(ls_cnt_fugr) WHERE objtype = 'REPS'.
            CHECK ls_cnt_fugr-objname CP |{ lv_fugr_incl }*|
               OR ls_cnt_fugr-objname = lv_fugr_main.
            <ls_metric>-versions  = <ls_metric>-versions + ls_cnt_fugr-cnt.
            <ls_metric>-sub_parts = <ls_metric>-sub_parts + 1.
          ENDLOOP.
        WHEN OTHERS.
          READ TABLE lt_cnt INTO DATA(ls_cnt)
            WITH KEY objtype = <ls_metric>-type objname = <ls_metric>-object_name.
          IF sy-subrc = 0.
            <ls_metric>-versions = ls_cnt-cnt.
          ENDIF.
          <ls_metric>-sub_parts = 1.
      ENDCASE.

      IF <ls_metric>-sub_parts = 0.
        <ls_metric>-sub_parts = 1.
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

      DATA(lv_model_secs) = estimate_secs(
        is_metric = <ls_metric>
        iv_blame  = iv_blame
        iv_remote = lv_remote ).
      APPEND lv_model_secs TO lt_model.

      " A measurement of the same part under the same blame setting beats any
      " model value — and tells the model how far off it is for this system.
      READ TABLE it_timings INTO DATA(ls_timing) WITH KEY part_key = <ls_metric>-part_key.
      IF sy-subrc = 0 AND ls_timing-blame = iv_blame.
        <ls_metric>-measured = abap_true.
        <ls_metric>-est_secs = ls_timing-secs.
        lv_sum_measured = lv_sum_measured + ls_timing-secs.
        lv_sum_modelled = lv_sum_modelled + lv_model_secs.
      ELSE.
        <ls_metric>-est_secs = lv_model_secs.
      ENDIF.
    ENDLOOP.

    " ── 4. Calibrate the unmeasured parts against the measured ones ──
    DATA(lv_calib_pct) = 100.
    IF lv_sum_measured > 0 AND lv_sum_modelled > 0.
      lv_calib_pct = CONV i( lv_sum_measured * 100 / lv_sum_modelled ).
      " Guard against a single outlier dragging every other estimate along.
      IF lv_calib_pct < 20.
        lv_calib_pct = 20.
      ELSEIF lv_calib_pct > 1000.
        lv_calib_pct = 1000.
      ENDIF.
    ENDIF.
    result-summary-calib_pct = lv_calib_pct.

    LOOP AT result-metrics ASSIGNING <ls_metric>.
      DATA(lv_idx) = sy-tabix.
      IF <ls_metric>-measured = abap_true.
        result-summary-parts_measured = result-summary-parts_measured + 1.
      ELSEIF lv_calib_pct <> 100.
        READ TABLE lt_model INTO DATA(lv_raw_model) INDEX lv_idx.
        IF sy-subrc = 0.
          <ls_metric>-est_secs = CONV i( lv_raw_model * lv_calib_pct / 100 ).
        ENDIF.
      ENDIF.
      <ls_metric>-band = band_of( <ls_metric>-est_secs ).

      result-summary-parts_total    = result-summary-parts_total + 1.
      result-summary-versions_total = result-summary-versions_total + <ls_metric>-versions.
      result-summary-lines_total    = result-summary-lines_total + <ls_metric>-lines.
      result-summary-est_secs       = result-summary-est_secs + <ls_metric>-est_secs.
      IF <ls_metric>-cached = abap_true.
        result-summary-parts_cached = result-summary-parts_cached + 1.
      ENDIF.
      CASE <ls_metric>-band.
        WHEN gc_band-heavy.
          result-summary-parts_heavy    = result-summary-parts_heavy + 1.
          result-summary-est_secs_heavy = result-summary-est_secs_heavy + <ls_metric>-est_secs.
        WHEN gc_band-medium.
          result-summary-parts_medium   = result-summary-parts_medium + 1.
          result-summary-est_secs_light = result-summary-est_secs_light + <ls_metric>-est_secs.
        WHEN OTHERS.
          result-summary-parts_light    = result-summary-parts_light + 1.
          result-summary-est_secs_light = result-summary-est_secs_light + <ls_metric>-est_secs.
      ENDCASE.
    ENDLOOP.

    SORT result-metrics BY est_secs DESCENDING versions DESCENDING.
  ENDMETHOD.


  METHOD estimate_secs.
    " Per technical part, then scaled by their number. Intermediate values can
    " exceed the integer range (lines² for a 30k-line include), so the whole
    " calculation runs in packed arithmetic.
    DATA lv_ms TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_vpp TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_lpp TYPE p LENGTH 16 DECIMALS 2.

    DATA(lv_parts) = COND i( WHEN is_metric-sub_parts > 0 THEN is_metric-sub_parts ELSE 1 ).
    lv_vpp = is_metric-versions / lv_parts.
    lv_lpp = is_metric-lines_est / lv_parts.

    lv_ms = gv_part_ms + lv_vpp * gv_ver_ms + lv_lpp * gv_line_ms.

    IF iv_blame = abap_true AND lv_vpp > 1.
      " One diff per version step. The replay deletes matching entries from the
      " blame map with a linear scan, which is what makes it grow with lines².
      lv_ms = lv_ms + ( lv_vpp - 1 )
                    * ( lv_lpp * gv_blame_lin_um / 1000
                      + lv_lpp * lv_lpp * gv_blame_sq_um / 1000000 ).
    ENDIF.

    lv_ms = lv_ms * lv_parts.

    IF iv_remote = abap_true.
      lv_ms = lv_ms * gv_remote_pct / 100.
    ENDIF.

    result = CONV i( lv_ms / 1000 ).
    IF result = 0 AND lv_ms > 0.
      result = 1.
    ENDIF.
  ENDMETHOD.


  METHOD band_of.
    result = COND ty_band(
      WHEN iv_secs >= gv_heavy_secs  THEN gc_band-heavy
      WHEN iv_secs >= gv_medium_secs THEN gc_band-medium
      ELSE                                gc_band-light ).
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
      `.cached{color:#777}.warn{background:#fef5e7;border-left:4px solid #e67e22;padding:8px 12px;margin-bottom:14px}`.

    DATA(ls_sum) = is_result-summary.
    DATA(lv_light_cnt) = count_band( it_metrics = is_result-metrics iv_bands = 'LM' ).
    DATA(lv_heavy_cnt) = count_band( it_metrics = is_result-metrics iv_bands = 'H' ).

    DATA(lv_warn) = ``.
    IF ls_sum-full_history = abap_true AND ls_sum-blame = abap_true.
      lv_warn =
        `<div class="warn">An S/R task is selected, so the version list is not trimmed to the ` &&
        `request — blame replays the <b>complete history</b> of every object. This is the single ` &&
        `biggest cost factor below. Reviewing the parent K request, or setting a "date from", ` &&
        `shortens the replay.</div>`.
    ENDIF.

    DATA(lv_cached_txt) = COND string(
      WHEN ls_sum-parts_cached > 0 THEN |, { ls_sum-parts_cached } already computed|
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
      |<b>{ ls_sum-lines_total }</b> source line(s){ lv_cached_txt }<br>| &&
      |Blame: <b>{ lv_blame_txt }</b>{ lv_remote_txt }<br>| &&
      |Estimated total: <b>{ format_secs( ls_sum-est_secs ) }</b> | &&
      |(light+medium { format_secs( ls_sum-est_secs_light ) }, heavy { format_secs( ls_sum-est_secs_heavy ) })| &&
      lv_calib_txt &&
      `</div>` &&
      |<p><a class="go" href="sapevent:prepare_band~LM">Prepare light + medium ({ lv_light_cnt })</a>| &&
      |<a class="go go3" href="sapevent:prepare_band~H">Prepare heavy only ({ lv_heavy_cnt })</a>| &&
      |<a class="go go2" href="sapevent:prepare_selected~0">Prepare all ({ ls_sum-parts_total })</a>| &&
      `<a class="go go2" href="sapevent:recalcpick~0">Pick manually</a></p>` &&
      `<table><tr><th>Band</th><th>Type</th><th>Object</th><th>Class</th>` &&
      `<th class="nr">Versions</th><th class="nr">Parts</th><th class="nr">Lines</th>` &&
      `<th class="nr">Est.</th><th>Source</th><th>Status</th></tr>`.

    LOOP AT is_result-metrics INTO DATA(ls_metric).
      DATA(lv_rowcls) = COND string( WHEN ls_metric-band = gc_band-heavy THEN ` class="h"` ELSE `` ).
      DATA(lv_lines_txt) = COND string(
        WHEN ls_metric-lines > 0 THEN |{ ls_metric-lines }|
        ELSE |~{ ls_metric-lines_est }| ).
      DATA(lv_status) = COND string(
        WHEN ls_metric-cached = abap_true THEN `<span class="cached">cached</span>`
        ELSE `new` ).
      DATA(lv_source) = COND string(
        WHEN ls_metric-measured = abap_true THEN `measured`
        ELSE `<span class="cached">model</span>` ).

      result = result &&
        |<tr{ lv_rowcls }>| &&
        |<td class="{ ls_metric-band }">{ ls_metric-band }</td>| &&
        |<td>{ esc( ls_metric-type ) }</td>| &&
        |<td><b>{ esc( ls_metric-display_name ) }</b></td>| &&
        |<td>{ esc( ls_metric-class ) }</td>| &&
        |<td class="nr">{ ls_metric-versions }</td>| &&
        |<td class="nr">{ ls_metric-sub_parts }</td>| &&
        |<td class="nr">{ lv_lines_txt }</td>| &&
        |<td class="nr">{ format_secs( ls_metric-est_secs ) }</td>| &&
        |<td>{ lv_source }</td>| &&
        |<td>{ lv_status }</td>| &&
        `</tr>`.
    ENDLOOP.

    IF is_result-metrics IS INITIAL.
      result = result && `<tr><td colspan="10">No reviewable objects in this scope</td></tr>`.
    ENDIF.

    result = result &&
      `</table>` &&
      `<p style="color:#777;font-size:11px">Rows marked <i>measured</i> show the duration of an ` &&
      `earlier Prepare of that object; the rest are model values derived from version count, ` &&
      `source size and blame replay depth, rescaled to the measurements. Use them to separate ` &&
      `cheap objects from expensive ones, not as a clock.</p>` &&
      `</body></html>`.
  ENDMETHOD.

ENDCLASS.
