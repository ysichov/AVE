CLASS zcl_ave_acr_overview DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS has_saved_stat
      IMPORTING
        is_part       TYPE zif_ave_popup_types=>ty_part_row
        it_obj_stats  TYPE zif_ave_acr_types=>ty_t_obj_stats
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS build_object_report_html
      IMPORTING
        iv_object_name TYPE string
        iv_object_type TYPE string
        iv_cr_prepared TYPE abap_bool
        it_parts       TYPE zif_ave_popup_types=>ty_t_part_row
      RETURNING
        VALUE(result)  TYPE string.
    CLASS-METHODS build_tr_task_popup_html
      IMPORTING
        iv_objtype           TYPE versobjtyp
        iv_objname           TYPE versobjnam
        iv_outer_object_name TYPE string
        it_parts             TYPE zif_ave_popup_types=>ty_t_part_row
      RETURNING
        VALUE(result)        TYPE string.
    CLASS-METHODS build_recalc_picker_html
      IMPORTING
        iv_object_name TYPE string
        iv_has_payload TYPE abap_bool
        it_parts       TYPE zif_ave_popup_types=>ty_t_part_row
        it_obj_stats   TYPE zif_ave_acr_types=>ty_t_obj_stats
      RETURNING
        VALUE(result)  TYPE string.
ENDCLASS.


CLASS zcl_ave_acr_overview IMPLEMENTATION.

  METHOD has_saved_stat.
    result = xsdbool(
      line_exists( it_obj_stats[
        objtype = is_part-type obj_name = is_part-object_name ] ) ).

    IF result = abap_false AND is_part-type = 'CLAS'.
      DATA(lv_class_name) = CONV seoclsname( is_part-object_name ).
      LOOP AT it_obj_stats TRANSPORTING NO FIELDS
        WHERE class_name = lv_class_name.
        result = abap_true.
        EXIT.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD build_object_report_html.
    DATA lv_korr_text TYPE as4text.
    DATA(lv_korrnum) = CONV trkorr( iv_object_name ).
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
    IF zcl_ave_acr_repository=>has_review_table( ) = abap_true.
      DATA(ls_saved_payload_check) = VALUE zif_ave_acr_types=>ty_saved_payload( ).
      IF zcl_ave_acr_repository=>load_review_payload(
           EXPORTING iv_trkorr = CONV #( iv_object_name )
           CHANGING  cs_payload = ls_saved_payload_check ) = abap_true
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

    IF iv_cr_prepared = abap_true.
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
    LOOP AT it_parts INTO DATA(ls_part_key_scan) WHERE type <> 'RPT'.
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
      |<span style="color:#3498db">{ escape( val = CONV string( iv_object_name ) format = cl_abap_format=>e_html_text ) }|.
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
    LOOP AT it_parts TRANSPORTING NO FIELDS WHERE type <> 'RPT'.
      lv_report_part_total += 1.
    ENDLOOP.

    " Declare request tables outside loop to avoid ABAP DATA stale-value accumulation
    DATA lt_request_tokens TYPE string_table.
    DATA lt_request_tasks  TYPE RANGE OF trkorr.
    DATA lt_request_trs    TYPE RANGE OF trkorr.

    LOOP AT it_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
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
        IF iv_object_type = zcl_ave_object_factory=>gc_type-tr
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
        IF iv_object_type = zcl_ave_object_factory=>gc_type-tr.
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
      DATA(lv_part_display_name) = COND string(
        WHEN ls_part-class IS NOT INITIAL AND ls_part-name IS NOT INITIAL
        THEN ls_part-name
        ELSE lv_objname_str ).
      DATA(lv_part_object_cell) = COND string(
        WHEN lv_part_supported = abap_true
        THEN |<td><b>{ escape( val = condense( val = lv_part_display_name ) format = cl_abap_format=>e_html_text ) }</b></td>|
        ELSE |<td style="color:#8a8f98;font-weight:normal">{ escape( val = condense( val = lv_part_display_name ) format = cl_abap_format=>e_html_text ) }</td>| ).

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

    DATA(lv_obj_count) = lines( it_parts ).
    IF line_exists( it_parts[ type = 'RPT' ] ).
      lv_obj_count = lv_obj_count - 1.
    ENDIF.
    IF lv_obj_count = 0.
      result = result &&
        |<tr><td colspan="9" class="muted">No changed objects found.</td></tr>|.
    ENDIF.

    result = result && |</table></body></html>|.
  ENDMETHOD.


  METHOD build_tr_task_popup_html.
    DATA ls_part TYPE zif_ave_popup_types=>ty_part_row.
    READ TABLE it_parts INTO ls_part
      WITH KEY type = iv_objtype object_name = iv_objname.

    DATA(lv_css) =
      `body{font:13px/1.5 Consolas,monospace;padding:14px 18px;background:#fff;color:#333}` &&
      `h3{margin:0 0 12px 0;color:#2c3e50}` &&
      `table{border-collapse:collapse;width:100%;font-size:12px}` &&
      `th{background:#3498db;color:#fff;padding:5px 8px;text-align:left}` &&
      `td{padding:4px 8px;border-bottom:1px solid #eee;white-space:nowrap}` &&
      `.muted{color:#777}`.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8">| &&
      |<style>{ lv_css }</style></head><body>| &&
      |<h3>TRs/Tasks - { escape( val = CONV string( iv_objtype ) format = cl_abap_format=>e_html_text ) } | &&
      |{ escape( val = CONV string( iv_objname ) format = cl_abap_format=>e_html_text ) }</h3>| &&
      |<table><tr><th>TR</th><th>Task</th><th>Author</th><th>Date</th><th>Time</th></tr>|.

    DATA lt_popup_tasks TYPE string_table.
    IF ls_part-requests IS NOT INITIAL.
      SPLIT ls_part-requests AT `,` INTO TABLE lt_popup_tasks.
    ELSEIF iv_outer_object_name IS NOT INITIAL.
      APPEND iv_outer_object_name TO lt_popup_tasks.
    ENDIF.

    DATA(lv_popup_rows) = 0.
    LOOP AT lt_popup_tasks INTO DATA(lv_popup_task).
      CONDENSE lv_popup_task.
      CHECK lv_popup_task IS NOT INITIAL.

      DATA(lv_popup_tr) = CONV trkorr( lv_popup_task ).
      DATA(lv_popup_author) = VALUE versuser( ).
      DATA(lv_popup_date) = VALUE as4date( ).
      DATA(lv_popup_time) = VALUE as4time( ).
      SELECT SINGLE strkorr, as4user, as4date, as4time FROM e070
        WHERE trkorr = @lv_popup_tr
        INTO (@DATA(lv_popup_parent), @lv_popup_author, @lv_popup_date, @lv_popup_time).
      IF sy-subrc = 0 AND lv_popup_parent IS NOT INITIAL.
        lv_popup_tr = lv_popup_parent.
      ENDIF.

      DATA(lv_popup_author_text) = CONV string( lv_popup_author ).
      DATA(lv_popup_author_name) = zcl_ave_popup_data=>get_user_name( lv_popup_author ).
      IF lv_popup_author_name IS NOT INITIAL.
        lv_popup_author_text = |{ lv_popup_author } { lv_popup_author_name }|.
      ENDIF.

      DATA(lv_popup_date_text) = CONV string( lv_popup_date ).
      IF lv_popup_date IS NOT INITIAL.
        lv_popup_date_text = |{ lv_popup_date_text+6(2) }.{ lv_popup_date_text+4(2) }.{ lv_popup_date_text+0(4) }|.
      ENDIF.
      DATA(lv_popup_time_text) = CONV string( lv_popup_time ).
      IF lv_popup_time IS NOT INITIAL.
        lv_popup_time_text = |{ lv_popup_time_text+0(2) }:{ lv_popup_time_text+2(2) }:{ lv_popup_time_text+4(2) }|.
      ENDIF.

      result = result &&
        |<tr><td>{ escape( val = CONV string( lv_popup_tr ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = lv_popup_task format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = lv_popup_author_text format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = lv_popup_date_text format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = lv_popup_time_text format = cl_abap_format=>e_html_text ) }</td></tr>|.
      lv_popup_rows += 1.
    ENDLOOP.

    IF lv_popup_rows = 0.
      result = result && `<tr><td colspan="5" class="muted">No task data</td></tr>`.
    ENDIF.

    result = result && `</table></body></html>`.
  ENDMETHOD.


  METHOD build_recalc_picker_html.
    DATA(lv_picker_title) = COND string(
      WHEN iv_has_payload = abap_true THEN `Recalc Diff`
      ELSE `Prepare Code Review` ).
    DATA(lv_primary_label) = COND string(
      WHEN iv_has_payload = abap_true THEN `Recalc Selected`
      ELSE `Prepare Selected` ).
    DATA(lv_delete_button) = COND string(
      WHEN iv_has_payload = abap_true
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

    result =
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
      |<h2>{ lv_picker_title } - { escape( val = CONV string( iv_object_name ) format = cl_abap_format=>e_html_text ) }</h2>| &&
      |<p><a class="go" href="#" onclick="return go()">{ lv_primary_label }</a>| &&
      lv_delete_button &&
      `<a class="back" href="sapevent:back~0">Back</a>` &&
      `<a class="clear" href="#" onclick="allc(false);return false">Clear Selected</a>` &&
      `&nbsp;&nbsp;<a href="#" onclick="allc(true);return false">Select all</a>` &&
      `</p>` &&
      `<table><tr><th></th><th>Type</th><th>Object</th><th>Class</th><th>Status</th><th class="nr">Rows</th></tr>`.

    LOOP AT it_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_part-type ) = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_key) = |{ ls_part-type }~{ ls_part-object_name }|.
      DATA(lv_cached) = abap_false.
      IF iv_has_payload = abap_true.
        READ TABLE it_obj_stats TRANSPORTING NO FIELDS
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
      DATA(lv_object_text) = COND string(
        WHEN ls_part-type = 'METH' AND ls_part-unit IS NOT INITIAL
        THEN ls_part-unit
        ELSE CONV string( ls_part-object_name ) ).

      result = result &&
        `<tr>` &&
        |<td><input type="checkbox" name="o" checked value="{ escape( val = lv_key format = cl_abap_format=>e_html_attr ) }"></td>| &&
        |<td>{ escape( val = CONV string( ls_part-type ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td><b>{ escape( val = lv_object_text format = cl_abap_format=>e_html_text ) }</b></td>| &&
        |<td>{ escape( val = CONV string( ls_part-class ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ lv_status }</td>| &&
        |<td class="nr">{ lv_part_rows }</td>| &&
        `</tr>`.
    ENDLOOP.

    result = result && `</table></body></html>`.
  ENDMETHOD.

ENDCLASS.
