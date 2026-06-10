CLASS zcl_ave_version_list DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES ty_version_row TYPE zif_ave_popup_types=>ty_version_row.
    TYPES ty_t_version_row TYPE zif_ave_popup_types=>ty_t_version_row.

    TYPES:
      BEGIN OF ty_result,
        versions       TYPE ty_t_version_row,
        creator        TYPE versuser,
        new_version    TYPE ty_version_row,
        old_version    TYPE ty_version_row,
        remote_version TYPE ty_version_row,
      END OF ty_result.

    CLASS-METHODS load
      IMPORTING
        iv_objtype               TYPE versobjtyp
        iv_objname               TYPE versobjnam
        iv_date_from             TYPE versdate OPTIONAL
        iv_remove_dup            TYPE abap_bool DEFAULT abap_false
        iv_no_toc                TYPE abap_bool DEFAULT abap_true
        iv_ignore_case           TYPE abap_bool DEFAULT abap_true
        iv_filter_korrnum        TYPE trkorr OPTIONAL
        it_filter_korrnums       TYPE zif_ave_object=>ty_t_korr_range OPTIONAL
        it_filter_parent_korrnums TYPE zif_ave_object=>ty_t_korr_range OPTIONAL
        iv_system                TYPE verssysnam OPTIONAL
      RETURNING
        VALUE(result)            TYPE ty_result.

    "! Lightweight pair loader for batch scenarios (Observer quick diff).
    "! Reads VRSD directly — no zcl_ave_version construction, no metadata enrichment.
    "! Returns only new_version / old_version; versions list is left empty.
    CLASS-METHODS load_light
      IMPORTING
        iv_objtype        TYPE versobjtyp
        iv_objname        TYPE versobjnam
        iv_filter_korrnum TYPE trkorr
      RETURNING
        VALUE(result)     TYPE ty_result.

  PRIVATE SECTION.
    CLASS-METHODS map_to_e071_key
      IMPORTING
        iv_objtype     TYPE versobjtyp
        iv_objname     TYPE versobjnam
      EXPORTING
        ev_object      TYPE e071-object
        ev_obj_name    TYPE e071-obj_name.
ENDCLASS.


CLASS zcl_ave_version_list IMPLEMENTATION.

  METHOD load.
    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING
        percentage = 0
        text       = CONV char70( |Loading versions for { iv_objtype } { iv_objname }| ).

    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd(
          type      = iv_objtype
          name      = iv_objname
          no_toc    = abap_false
          date_from = iv_date_from ).
      CATCH zcx_ave.
        RETURN.
    ENDTRY.

    DATA(lv_vrsd_total) = lines( lo_vrsd->vrsd_list ).
    LOOP AT lo_vrsd->vrsd_list INTO DATA(ls_vrsd).
      IF sy-tabix = 1 OR sy-tabix = lv_vrsd_total OR sy-tabix MOD 10 = 0.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING
            percentage = CONV i( sy-tabix * 20 / COND i( WHEN lv_vrsd_total > 0 THEN lv_vrsd_total ELSE 1 ) )
            text       = CONV char70( |Reading version metadata ({ sy-tabix }/{ lv_vrsd_total })| ).
      ENDIF.

      TRY.
          DATA(lo_ver) = NEW zcl_ave_version( ls_vrsd ).
          APPEND VALUE ty_version_row(
            versno         = lo_ver->version_number
            versno_text    = COND #( WHEN lo_ver->version_number = zcl_ave_version=>c_version-active
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
            objname        = lo_ver->objname ) TO result-versions.
        CATCH zcx_ave.
      ENDTRY.
    ENDLOOP.

    SORT result-versions BY versno DESCENDING datum DESCENDING zeit DESCENDING.

    DATA lv_seen_active TYPE abap_bool.
    DATA lv_seen_modified TYPE abap_bool.
    DATA lv_active_idx TYPE i VALUE 1.
    DATA lv_modified_idx TYPE i VALUE 1.
    LOOP AT result-versions ASSIGNING FIELD-SYMBOL(<vr>).
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

    LOOP AT result-versions ASSIGNING FIELD-SYMBOL(<ver_trf>).
      CHECK <ver_trf>-korrnum IS NOT INITIAL AND <ver_trf>-trfunction IS INITIAL.
      SELECT SINGLE trfunction FROM e070
        WHERE trkorr = @<ver_trf>-korrnum
        INTO @<ver_trf>-trfunction.
      LOOP AT result-versions ASSIGNING FIELD-SYMBOL(<ver_trf2>)
        WHERE korrnum = <ver_trf>-korrnum AND trfunction IS INITIAL.
        <ver_trf2>-trfunction = <ver_trf>-trfunction.
      ENDLOOP.
    ENDLOOP.

    TYPES:
      BEGIN OF ty_obj_key,
        object   TYPE e071-object,
        obj_name TYPE e071-obj_name,
      END OF ty_obj_key.
    TYPES:
      BEGIN OF ty_task_cand,
        trkorr  TYPE trkorr,
        strkorr TYPE trkorr,
        as4user TYPE as4user,
        as4date TYPE as4date,
        as4time TYPE as4time,
      END OF ty_task_cand.
    TYPES:
      BEGIN OF ty_korr_key,
        korrnum TYPE trkorr,
      END OF ty_korr_key.
    TYPES:
      BEGIN OF ty_task_date,
        trkorr  TYPE trkorr,
        as4date TYPE e070-as4date,
        as4time TYPE e070-as4time,
      END OF ty_task_date.

    DATA lt_keys TYPE SORTED TABLE OF ty_obj_key WITH UNIQUE KEY object obj_name.
    DATA lt_all_tasks TYPE STANDARD TABLE OF ty_task_cand.
    DATA lt_request_tasks TYPE STANDARD TABLE OF ty_task_cand.
    DATA lt_korr_keys TYPE SORTED TABLE OF ty_korr_key WITH UNIQUE KEY korrnum.
    DATA lv_e071_type TYPE e071-object.
    DATA lv_e071_name TYPE e071-obj_name.

    map_to_e071_key(
      EXPORTING
        iv_objtype  = iv_objtype
        iv_objname  = iv_objname
      IMPORTING
        ev_object   = lv_e071_type
        ev_obj_name = lv_e071_name ).

    INSERT VALUE #( object = lv_e071_type obj_name = lv_e071_name ) INTO TABLE lt_keys.
    IF lv_e071_type = 'PROG'.
      INSERT VALUE #( object = 'REPS' obj_name = lv_e071_name ) INTO TABLE lt_keys.
    ELSEIF lv_e071_type = 'REPS'.
      INSERT VALUE #( object = 'PROG' obj_name = lv_e071_name ) INTO TABLE lt_keys.
    ENDIF.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING
        percentage = 35
        text       = CONV char70( |Reading S-requests for { iv_objtype } { iv_objname }| ).

    " A K can carry both S (task) and R (repair) child requests — match either.
    DATA lt_trf_task_types TYPE RANGE OF e070-trfunction.
    lt_trf_task_types = VALUE #(
      ( sign = 'I' option = 'EQ' low = 'S' )
      ( sign = 'I' option = 'EQ' low = 'R' ) ).
    " Build lt_korr_keys from the K/T requests selected on the selection screen.
    IF iv_filter_korrnum IS NOT INITIAL.
      DATA(lv_fkv_trf) = CONV e070-trfunction( '' ).
      SELECT SINGLE trfunction FROM e070 WHERE trkorr = @iv_filter_korrnum INTO @lv_fkv_trf.
      IF lv_fkv_trf = 'K' OR lv_fkv_trf = 'T'.
        INSERT VALUE #( korrnum = iv_filter_korrnum ) INTO TABLE lt_korr_keys.
      ENDIF.
    ENDIF.
    LOOP AT it_filter_korrnums INTO DATA(ls_fk) WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
      DATA(lv_fk_trf) = CONV e070-trfunction( '' ).
      SELECT SINGLE trfunction FROM e070 WHERE trkorr = @ls_fk-low INTO @lv_fk_trf.
      IF lv_fk_trf = 'K' OR lv_fk_trf = 'T'.
        INSERT VALUE #( korrnum = ls_fk-low ) INTO TABLE lt_korr_keys.
      ENDIF.
    ENDLOOP.
    LOOP AT it_filter_parent_korrnums INTO DATA(ls_pk) WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
      DATA(lv_pk_trf) = CONV e070-trfunction( '' ).
      SELECT SINGLE trfunction FROM e070 WHERE trkorr = @ls_pk-low INTO @lv_pk_trf.
      IF lv_pk_trf = 'K' OR lv_pk_trf = 'T'.
        INSERT VALUE #( korrnum = ls_pk-low ) INTO TABLE lt_korr_keys.
      ENDIF.
    ENDLOOP.

    " No selection-screen filter (plain Version Explorer): use every K-version in
    " the list as scope, so S/R-tasks can still be resolved for K- and T-versions.
    IF lt_korr_keys IS INITIAL.
      LOOP AT result-versions INTO DATA(ls_k_ver)
        WHERE trfunction = 'K' AND korrnum IS NOT INITIAL.
        INSERT VALUE #( korrnum = ls_k_ver-korrnum ) INTO TABLE lt_korr_keys.
      ENDLOOP.
    ENDIF.

    " All S/R-children of the selected K-request(s).
    IF lt_korr_keys IS NOT INITIAL.
      SELECT trkorr, strkorr, as4user, as4date, as4time
        FROM e070
        FOR ALL ENTRIES IN @lt_korr_keys
        WHERE strkorr    = @lt_korr_keys-korrnum
          AND trfunction IN @lt_trf_task_types
        INTO CORRESPONDING FIELDS OF TABLE @lt_request_tasks.
      SORT lt_request_tasks BY as4date DESCENDING as4time DESCENDING.
    ENDIF.

    " Candidate authoring tasks: ONLY the S/R-children of the selected K that
    " actually carry THIS object in E071 — either per-method (LIMU METH) or, when
    " the class was regenerated as a whole, at class level (R3TR CLAS). A task that
    " does not contain the object is never a candidate (spec: S/R must belong to the
    " selected K and contain the analysed object).
    DATA lt_obj_keys LIKE lt_keys.
    lt_obj_keys = lt_keys.
    IF lv_e071_type = 'METH'.
      INSERT VALUE #( object = 'CLAS' obj_name = CONV e071-obj_name( lv_e071_name(30) ) )
        INTO TABLE lt_obj_keys.
    ELSEIF lv_e071_type = 'CPUB' OR lv_e071_type = 'CPRO'
        OR lv_e071_type = 'CPRI' OR lv_e071_type = 'CDEF'.
      " Class section parts may be logged at class level (R3TR CLAS) on full
      " regeneration — same CLAS fallback as for methods. ev_obj_name is already
      " reduced to the class name by map_to_e071_key.
      INSERT VALUE #( object = 'CLAS' obj_name = lv_e071_name )
        INTO TABLE lt_obj_keys.
    ENDIF.
    DATA lr_scope_tasks TYPE RANGE OF trkorr.
    LOOP AT lt_request_tasks INTO DATA(ls_scope_task).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_scope_task-trkorr ) TO lr_scope_tasks.
    ENDLOOP.
    IF lr_scope_tasks IS NOT INITIAL.
      SELECT e070~trkorr, e070~strkorr, e070~as4user, e070~as4date, e070~as4time
        FROM e071
        INNER JOIN e070 ON e070~trkorr = e071~trkorr
        FOR ALL ENTRIES IN @lt_obj_keys
        WHERE e071~object   = @lt_obj_keys-object
          AND e071~obj_name = @lt_obj_keys-obj_name
          AND e070~trkorr  IN @lr_scope_tasks
        INTO TABLE @lt_all_tasks.
      SORT lt_all_tasks BY trkorr.
      DELETE ADJACENT DUPLICATES FROM lt_all_tasks COMPARING trkorr.
      SORT lt_all_tasks BY as4date DESCENDING as4time DESCENDING.
    ENDIF.

    DATA(lv_match_total) = lines( result-versions ).
    LOOP AT result-versions ASSIGNING FIELD-SYMBOL(<ver>).
      IF sy-tabix = 1 OR sy-tabix = lv_match_total OR sy-tabix MOD 10 = 0.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING
            percentage = 35 + CONV i( sy-tabix * 25 / COND i( WHEN lv_match_total > 0 THEN lv_match_total ELSE 1 ) )
            text       = CONV char70( |Matching S-request ({ sy-tabix }/{ lv_match_total })| ).
      ENDIF.

      IF <ver>-trfunction = 'S'.
        <ver>-task = <ver>-korrnum.
        CONTINUE.
      ENDIF.

      " For a T-copy: the T's E071 CORR/MERG entries name the MAIN request (a K) it was
      " merged from — the first 10 chars of obj_name are that K. Restrict the candidates
      " to all S/R-tasks subordinate to that K, prefer those that actually carry this
      " object, then pick the nearest preceding one by date/time. A single candidate is
      " taken as-is (R-tasks may carry an unusable date, so we do not drop the only one).
      IF <ver>-trfunction = 'T'.
        IF <ver>-korrnum IS NOT INITIAL.
          SELECT obj_name FROM e071
            WHERE trkorr = @<ver>-korrnum
              AND pgmid  = 'CORR'
              AND object = 'MERG'
            INTO TABLE @DATA(lt_merg_obj).

          " The K-request(s) named in CORR/MERG.
          DATA lr_merg_k TYPE RANGE OF trkorr.
          CLEAR lr_merg_k.
          LOOP AT lt_merg_obj INTO DATA(lv_merg_obj).
            APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_merg_obj+0(10) ) TO lr_merg_k.
          ENDLOOP.

          DATA lt_merg_cand TYPE STANDARD TABLE OF ty_task_cand.
          CLEAR lt_merg_cand.
          IF lr_merg_k IS NOT INITIAL.
            " Only S/R-tasks subordinate to the CORR/MERG K that carry THIS object
            " (per-method LIMU METH, or class-level R3TR CLAS on full regeneration).
            SELECT e070~trkorr, e070~strkorr, e070~as4user, e070~as4date, e070~as4time
              FROM e071
              INNER JOIN e070 ON e070~trkorr = e071~trkorr
              FOR ALL ENTRIES IN @lt_obj_keys
              WHERE e071~object   = @lt_obj_keys-object
                AND e071~obj_name = @lt_obj_keys-obj_name
                AND e070~strkorr IN @lr_merg_k
                AND e070~trfunction IN @lt_trf_task_types
              INTO TABLE @lt_merg_cand.
            SORT lt_merg_cand BY trkorr.
            DELETE ADJACENT DUPLICATES FROM lt_merg_cand COMPARING trkorr.
            SORT lt_merg_cand BY as4date DESCENDING as4time DESCENDING.
          ENDIF.

          " Pick the nearest preceding candidate by date/time. Date IS meaningful for
          " S-tasks (correct timestamps), so this selects the right S. R-tasks carry a
          " date/time in the FUTURE and will fail this check — when nothing precedes
          " (e.g. only an R remains), fall back to the newest candidate so the R is
          " still taken (the set is already constrained to the CORR/MERG K + object).
          DATA(ls_merg_pick) = VALUE ty_task_cand( ).
          LOOP AT lt_merg_cand INTO DATA(ls_merg_c).
            CHECK ls_merg_c-as4date < <ver>-datum
               OR ( ls_merg_c-as4date = <ver>-datum AND ls_merg_c-as4time <= <ver>-zeit ).
            ls_merg_pick = ls_merg_c.
            EXIT.
          ENDLOOP.
          IF ls_merg_pick IS INITIAL.
            READ TABLE lt_merg_cand INTO ls_merg_pick INDEX 1.
          ENDIF.

          IF ls_merg_pick IS NOT INITIAL.
            <ver>-task           = ls_merg_pick-trkorr.
            <ver>-obj_owner      = ls_merg_pick-as4user.
            <ver>-obj_owner_name = zcl_ave_popup_data=>get_user_name( ls_merg_pick-as4user ).
          ENDIF.
        ENDIF.
        " T is resolved only from S/R subordinate to its CORR/MERG K — never arbitrary tasks.
        CONTINUE.
      ENDIF.

      " For a K-version: prefer the candidate task that is a direct child of this K.
      IF <ver>-trfunction = 'K' AND <ver>-korrnum IS NOT INITIAL.
        LOOP AT lt_all_tasks INTO DATA(ls_k_task) WHERE strkorr = <ver>-korrnum.
          <ver>-task           = ls_k_task-trkorr.
          <ver>-obj_owner      = ls_k_task-as4user.
          <ver>-obj_owner_name = zcl_ave_popup_data=>get_user_name( ls_k_task-as4user ).
          EXIT.
        ENDLOOP.
        IF <ver>-task IS NOT INITIAL.
          CONTINUE.
        ENDIF.
      ENDIF.

      " Nearest preceding candidate by date/time (K-versions only — S and T already
      " handled above). lt_all_tasks holds only S/R-children of the selected K that
      " contain this object, so any match here is guaranteed relevant.
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
    ENDLOOP.

    IF iv_filter_korrnum IS NOT INITIAL
       OR it_filter_parent_korrnums IS NOT INITIAL
       OR it_filter_korrnums IS NOT INITIAL.
      TYPES:
        BEGIN OF ty_version_work,
          row      TYPE ty_version_row,
          req      TYPE trkorr,
          as4date  TYPE e070-as4date,
          as4time  TYPE e070-as4time,
          selected TYPE abap_bool,
        END OF ty_version_work.
      DATA lt_selected_keys TYPE SORTED TABLE OF ty_korr_key WITH UNIQUE KEY korrnum.
      DATA lt_parent_keys TYPE SORTED TABLE OF ty_korr_key WITH UNIQUE KEY korrnum.
      DATA lt_parent_tasks TYPE STANDARD TABLE OF ty_task_date.
      DATA lt_selected_tasks TYPE STANDARD TABLE OF ty_task_date WITH DEFAULT KEY.
      DATA lt_work TYPE STANDARD TABLE OF ty_version_work WITH DEFAULT KEY.
      DATA lt_filtered_versions TYPE ty_t_version_row.
      DATA lv_low_date TYPE e070-as4date.
      DATA lv_low_time TYPE e070-as4time.
      DATA lv_high_date TYPE e070-as4date.
      DATA lv_high_time TYPE e070-as4time.
      DATA lv_selected_kept TYPE abap_bool.
      DATA lv_previous_kept TYPE abap_bool.
      DATA lv_selected_top_versno TYPE versno.

      IF iv_filter_korrnum IS NOT INITIAL.
        SELECT SINGLE trfunction, strkorr FROM e070
          WHERE trkorr = @iv_filter_korrnum
          INTO (@DATA(lv_single_filter_trf), @DATA(lv_single_filter_parent)).
        IF sy-subrc = 0.
          IF lv_single_filter_trf = 'S' OR lv_single_filter_trf = 'R'.
            INSERT VALUE #( korrnum = iv_filter_korrnum ) INTO TABLE lt_selected_keys.
            IF lv_single_filter_parent IS NOT INITIAL.
              INSERT VALUE #( korrnum = lv_single_filter_parent ) INTO TABLE lt_parent_keys.
            ENDIF.
          ELSEIF lv_single_filter_trf = 'K'.
            INSERT VALUE #( korrnum = iv_filter_korrnum ) INTO TABLE lt_selected_keys.
            INSERT VALUE #( korrnum = iv_filter_korrnum ) INTO TABLE lt_parent_keys.
          ELSEIF lv_single_filter_trf = 'T'.
            INSERT VALUE #( korrnum = iv_filter_korrnum ) INTO TABLE lt_selected_keys.
          ENDIF.
        ENDIF.
      ENDIF.

      LOOP AT it_filter_korrnums INTO DATA(ls_filter_korrnum)
        WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
        SELECT SINGLE trfunction, strkorr FROM e070
          WHERE trkorr = @ls_filter_korrnum-low
          INTO (@DATA(lv_filter_trf), @DATA(lv_filter_parent)).
        CHECK sy-subrc = 0.
        IF lv_filter_trf = 'S' OR lv_filter_trf = 'R'.
          INSERT VALUE #( korrnum = ls_filter_korrnum-low ) INTO TABLE lt_selected_keys.
          IF lv_filter_parent IS NOT INITIAL.
            INSERT VALUE #( korrnum = lv_filter_parent ) INTO TABLE lt_parent_keys.
          ENDIF.
        ELSEIF lv_filter_trf = 'K'.
          INSERT VALUE #( korrnum = ls_filter_korrnum-low ) INTO TABLE lt_selected_keys.
          INSERT VALUE #( korrnum = ls_filter_korrnum-low ) INTO TABLE lt_parent_keys.
        ELSEIF lv_filter_trf = 'T'.
          INSERT VALUE #( korrnum = ls_filter_korrnum-low ) INTO TABLE lt_selected_keys.
        ENDIF.
      ENDLOOP.

      LOOP AT it_filter_parent_korrnums INTO DATA(ls_parent_filter)
        WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
        SELECT SINGLE trfunction FROM e070
          WHERE trkorr = @ls_parent_filter-low
          INTO @DATA(lv_parent_filter_trf).
        IF sy-subrc = 0 AND lv_parent_filter_trf = 'T'.
          INSERT VALUE #( korrnum = ls_parent_filter-low ) INTO TABLE lt_selected_keys.
        ELSE.
          INSERT VALUE #( korrnum = ls_parent_filter-low ) INTO TABLE lt_parent_keys.
        ENDIF.
      ENDLOOP.

      IF lt_parent_keys IS NOT INITIAL.
        SELECT trkorr, as4date, as4time
          FROM e070
          FOR ALL ENTRIES IN @lt_parent_keys
          WHERE strkorr = @lt_parent_keys-korrnum
            AND trfunction IN @lt_trf_task_types
          INTO TABLE @lt_parent_tasks.
        SORT lt_parent_tasks BY as4date ASCENDING as4time ASCENDING.
        READ TABLE lt_parent_tasks INTO DATA(ls_low_task) INDEX 1.
        IF sy-subrc = 0.
          lv_low_date = ls_low_task-as4date.
          lv_low_time = ls_low_task-as4time.
        ENDIF.
      ENDIF.

      " Set of S/R-child tasks of the selected K. A version whose -task is one of
      " these is part of our change (in scope) even if its own request (e.g. a T-copy)
      " is not directly selected — this matches the broader scope used by the code
      " reviewer, so the retained baseline is a truly older, out-of-scope version.
      DATA lt_scope_child_tasks TYPE SORTED TABLE OF trkorr WITH UNIQUE KEY table_line.
      LOOP AT lt_parent_tasks INTO DATA(ls_scope_child).
        INSERT ls_scope_child-trkorr INTO TABLE lt_scope_child_tasks.
      ENDLOOP.

      IF lt_selected_keys IS INITIAL.
        LOOP AT lt_parent_tasks INTO DATA(ls_parent_task).
          INSERT VALUE #( korrnum = ls_parent_task-trkorr ) INTO TABLE lt_selected_keys.
        ENDLOOP.
      ENDIF.

      IF lt_selected_keys IS NOT INITIAL.
        SELECT trkorr, as4date, as4time
          FROM e070
          FOR ALL ENTRIES IN @lt_selected_keys
          WHERE trkorr = @lt_selected_keys-korrnum
          INTO TABLE @lt_selected_tasks.
        SORT lt_selected_tasks BY as4date ASCENDING as4time ASCENDING.
        IF lv_low_date IS INITIAL.
          READ TABLE lt_selected_tasks INTO DATA(ls_low_selected) INDEX 1.
          IF sy-subrc = 0.
            lv_low_date = ls_low_selected-as4date.
            lv_low_time = ls_low_selected-as4time.
          ENDIF.
        ENDIF.
        READ TABLE lt_selected_tasks INTO DATA(ls_high_task) INDEX lines( lt_selected_tasks ).
        IF sy-subrc = 0.
          lv_high_date = ls_high_task-as4date.
          lv_high_time = ls_high_task-as4time.
        ENDIF.
      ENDIF.

      IF lv_low_date IS NOT INITIAL AND lv_high_date IS NOT INITIAL.
        LOOP AT result-versions INTO DATA(ls_ver).
          DATA(lv_req) = COND trkorr(
            WHEN ls_ver-trfunction = 'K' OR ls_ver-trfunction = 'T'
            THEN CONV trkorr( ls_ver-korrnum )
            WHEN ls_ver-korrnum IS NOT INITIAL
             AND line_exists( lt_selected_keys[ korrnum = CONV trkorr( ls_ver-korrnum ) ] )
            THEN CONV trkorr( ls_ver-korrnum )
            WHEN ls_ver-task IS NOT INITIAL THEN CONV trkorr( ls_ver-task )
            ELSE CONV trkorr( ls_ver-korrnum ) ).
          DATA(lv_req_date) = CONV e070-as4date( ls_ver-datum ).
          DATA(lv_req_time) = CONV e070-as4time( ls_ver-zeit ).
          DATA(lv_is_selected) = xsdbool(
            line_exists( lt_selected_keys[ korrnum = lv_req ] )
            OR ( ls_ver-korrnum IS NOT INITIAL
             AND line_exists( lt_selected_keys[ korrnum = CONV trkorr( ls_ver-korrnum ) ] ) )
            OR ( ls_ver-task IS NOT INITIAL
             AND line_exists( lt_scope_child_tasks[ table_line = CONV trkorr( ls_ver-task ) ] ) ) ).
          APPEND VALUE #(
            row      = ls_ver
            req      = lv_req
            as4date  = lv_req_date
            as4time  = lv_req_time
            selected = lv_is_selected )
            TO lt_work.
          IF lv_is_selected = abap_true
             AND ( lv_selected_top_versno IS INITIAL OR ls_ver-versno > lv_selected_top_versno ).
            lv_selected_top_versno = ls_ver-versno.
          ENDIF.
        ENDLOOP.
        SORT lt_work BY row-versno DESCENDING as4date DESCENDING as4time DESCENDING.

        LOOP AT lt_work INTO DATA(ls_work).
          " When a TR filter is active, always drop local Active/Modified pseudo-versions
          " from the display — the remote row already represents the current state.
          IF ls_work-row-versno = zcl_ave_version=>c_version-active
          OR ls_work-row-versno = zcl_ave_version=>c_version-modified.
            CONTINUE.
          ELSEIF lv_selected_top_versno IS NOT INITIAL
             AND ls_work-row-versno > lv_selected_top_versno.
            CONTINUE.
          ENDIF.
          IF ls_work-selected = abap_true.
            APPEND ls_work-row TO lt_filtered_versions.
            lv_selected_kept = abap_true.
            CONTINUE.
          ENDIF.
          IF ls_work-as4date > lv_high_date
            OR ( ls_work-as4date = lv_high_date AND ls_work-as4time > lv_high_time ).
            CONTINUE.
          ENDIF.
          IF lv_selected_kept = abap_true
             AND ( ls_work-row-trfunction = 'K' OR ls_work-row-trfunction = 'T' )
             AND NOT line_exists( lt_parent_keys[ korrnum = CONV trkorr( ls_work-row-korrnum ) ] )
             AND NOT line_exists( lt_selected_keys[ korrnum = CONV trkorr( ls_work-row-korrnum ) ] )
             AND ( ls_work-row-trfunction <> 'T'
                OR ls_work-row-task IS INITIAL
                OR NOT line_exists( lt_selected_keys[ korrnum = CONV trkorr( ls_work-row-task ) ] ) ).
            APPEND ls_work-row TO lt_filtered_versions.
            lv_previous_kept = abap_true.
            EXIT.
          ENDIF.
          IF ls_work-as4date > lv_low_date
            OR ( ls_work-as4date = lv_low_date AND ls_work-as4time >= lv_low_time ).
            APPEND ls_work-row TO lt_filtered_versions.
            lv_selected_kept = abap_true.
            CONTINUE.
          ENDIF.
          IF lv_selected_kept = abap_true
             AND lv_previous_kept = abap_false.
            APPEND ls_work-row TO lt_filtered_versions.
            lv_previous_kept = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        SORT lt_filtered_versions BY versno DESCENDING datum DESCENDING zeit DESCENDING.
        result-versions = lt_filtered_versions.
      ELSEIF lt_parent_keys IS NOT INITIAL OR lt_selected_keys IS NOT INITIAL.
        CLEAR result-versions.
      ENDIF.
    ENDIF.

    LOOP AT result-versions ASSIGNING FIELD-SYMBOL(<ver_owner_guard>)
      WHERE trfunction = 'K' AND task IS INITIAL.
      <ver_owner_guard>-obj_owner      = <ver_owner_guard>-author.
      <ver_owner_guard>-obj_owner_name = <ver_owner_guard>-author_name.
    ENDLOOP.

    DATA ls_creator_ver TYPE ty_version_row.
    LOOP AT result-versions INTO DATA(ls_creator_scan).
      IF ls_creator_ver IS INITIAL OR ls_creator_scan-versno < ls_creator_ver-versno.
        ls_creator_ver = ls_creator_scan.
      ENDIF.
    ENDLOOP.
    IF ls_creator_ver IS NOT INITIAL.
      result-creator = COND versuser(
        WHEN ls_creator_ver-obj_owner IS NOT INITIAL THEN ls_creator_ver-obj_owner
        ELSE ls_creator_ver-author ).
    ENDIF.

    DATA lv_korr_text TYPE e07t-as4text.
    LOOP AT result-versions ASSIGNING FIELD-SYMBOL(<ver2>).
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

    IF iv_remove_dup = abap_true.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING
          percentage = 70
          text       = CONV char70( |Checking duplicate versions for { iv_objtype } { iv_objname }| ).
      zcl_ave_popup_data=>remove_duplicate_versions(
        EXPORTING
          i_keep_korrnum = iv_filter_korrnum
          i_ignore_case  = iv_ignore_case
        CHANGING
          ct_versions    = result-versions ).
      LOOP AT result-versions ASSIGNING FIELD-SYMBOL(<ver_dup_owner_guard>)
        WHERE trfunction = 'K' AND task IS INITIAL.
        <ver_dup_owner_guard>-obj_owner      = <ver_dup_owner_guard>-author.
        <ver_dup_owner_guard>-obj_owner_name = <ver_dup_owner_guard>-author_name.
      ENDLOOP.
    ENDIF.

    IF iv_no_toc = abap_true.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING
          percentage = 95
          text       = CONV char70( |Filtering TOC versions for { iv_objtype } { iv_objname }| ).
      DELETE result-versions WHERE trfunction = 'T'.
    ENDIF.

    " Pair selection: only when a K/T/S filter is active (same condition as version
    " filtering above). Uses the scope structures already built by the filter block —
    " lt_selected_keys, lt_scope_child_tasks, lv_low_date/lv_low_time — so the scope
    " is derived exactly once from user-supplied parameters, never re-derived from
    " version data. When no filter is active there is no trimming and no pair.
    IF iv_filter_korrnum IS NOT INITIAL
       OR it_filter_korrnums IS NOT INITIAL
       OR it_filter_parent_korrnums IS NOT INITIAL.
      " Skip Active/Modified pseudo-versions — for diff purposes the newest
      " real (numbered) version of the selected request is what matters.
      LOOP AT result-versions INTO result-new_version.
        CHECK result-new_version-versno <> zcl_ave_version=>c_version-active
          AND result-new_version-versno <> zcl_ave_version=>c_version-modified.
        EXIT.
      ENDLOOP.
      IF result-new_version-versno = zcl_ave_version=>c_version-active
      OR result-new_version-versno = zcl_ave_version=>c_version-modified.
        CLEAR result-new_version.
      ENDIF.
      IF result-new_version IS NOT INITIAL.
        " Build own-scope set: all selected K/S/R/T plus all S/R children of parent K.
        DATA lt_pair_own TYPE HASHED TABLE OF trkorr WITH UNIQUE KEY table_line.
        LOOP AT lt_selected_keys INTO DATA(ls_pair_sel).
          INSERT ls_pair_sel-korrnum INTO TABLE lt_pair_own.
        ENDLOOP.
        LOOP AT lt_scope_child_tasks INTO DATA(lv_pair_ch).
          INSERT lv_pair_ch INTO TABLE lt_pair_own.
        ENDLOOP.
        IF result-new_version-task IS NOT INITIAL.
          INSERT CONV trkorr( result-new_version-task ) INTO TABLE lt_pair_own.
        ENDIF.

        " Walk versions from index 2; first one outside own scope is the baseline.
        LOOP AT result-versions INTO DATA(ls_bsl_ver) FROM 2.
          DATA(lv_bsl_korr) = COND trkorr(
            WHEN ls_bsl_ver-task    IS NOT INITIAL THEN CONV trkorr( ls_bsl_ver-task )
            WHEN ls_bsl_ver-korrnum IS NOT INITIAL THEN CONV trkorr( ls_bsl_ver-korrnum )
            ELSE VALUE trkorr( ) ).
          " Still in scope → skip
          IF lv_bsl_korr IS NOT INITIAL
             AND line_exists( lt_pair_own[ table_line = lv_bsl_korr ] ).
            CONTINUE.
          ENDIF.
          " Older than scope start → definitive baseline
          IF lv_low_date IS NOT INITIAL
             AND ( ls_bsl_ver-datum < lv_low_date
                OR ( ls_bsl_ver-datum = lv_low_date AND ls_bsl_ver-zeit < lv_low_time ) ).
            result-old_version = ls_bsl_ver.
            EXIT.
          ENDIF.
          " Not in scope → baseline
          IF lv_bsl_korr IS NOT INITIAL.
            result-old_version = ls_bsl_ver.
            EXIT.
          ENDIF.
        ENDLOOP.

        " New-object / v1 guards — mirror select_diff_pair logic.
        IF result-old_version IS INITIAL.
          IF result-new_version-versno <> '00001'.
            " Object existed before this request; oldest available is the baseline.
            READ TABLE result-versions INTO result-old_version
              INDEX lines( result-versions ).
            IF result-old_version-versno = result-new_version-versno.
              CLEAR result-old_version.  " only one version present
            ENDIF.
          ENDIF.
          " Else: versno=1 → new object, no baseline needed.
        ELSEIF result-old_version-versno = '00001'
           AND lv_low_date IS NOT INITIAL
           AND ( result-old_version-datum < lv_low_date
              OR ( result-old_version-datum = lv_low_date
               AND result-old_version-zeit < lv_low_time ) ).
          " v1 predates scope start → genuine baseline, keep it.
        ELSEIF result-old_version-versno = '00001'
           AND result-old_version-korrnum = result-new_version-korrnum.
          " v1 of the same request → object was created in this request → new object.
          CLEAR result-old_version.
        ELSEIF result-old_version-versno = '00001'
           AND ( result-old_version-trfunction = 'K'
              OR result-old_version-trfunction = 'T' )
           AND result-old_version-korrnum <> result-new_version-korrnum.
          " v1 from an earlier request → genuine baseline, keep it.
        ELSEIF result-old_version-versno = '00001'.
          " v1 otherwise → treat as new object.
          CLEAR result-old_version.
        ENDIF.
      ENDIF.
    ENDIF.

    IF iv_system IS NOT INITIAL.
      DATA lt_remote_dir TYPE vrsd_tab.
      DATA lt_remote_lversn TYPE TABLE OF vrsn.
      DATA lv_dest TYPE tmssysnam.
      lv_dest = iv_system.
      CALL FUNCTION 'SVRS_REMOTE_MANAGER'
        EXPORTING
          iv_command            = 'SVRS_GET_VERSION_DIRECTORY_40'
          iv_tarsystem          = lv_dest
          objname               = iv_objname
          objtype               = iv_objtype
        TABLES
          lversno_list          = lt_remote_lversn
          version_list          = lt_remote_dir
        EXCEPTIONS
          no_entry              = 1
          communication_failure = 2
          system_failure        = 3
          OTHERS                = 4.
      DATA ls_remote_scan TYPE vrsd.
      IF sy-subrc = 0.
        IF iv_filter_korrnum IS NOT INITIAL.
          " With TR filter: prefer the version just BEFORE the selected TR in remote
          " (production state before this change). If the TR has not yet been
          " released to the remote system, fall back to the current Active state.
          READ TABLE lt_remote_dir WITH KEY korrnum = iv_filter_korrnum INTO ls_remote_scan.
          IF sy-subrc = 0.
            READ TABLE lt_remote_dir INDEX sy-tabix + 1 INTO ls_remote_scan.
          ENDIF.
          IF ls_remote_scan IS INITIAL.
            " TR not yet in remote — show whatever is currently active there.
            READ TABLE lt_remote_dir INDEX 1 INTO ls_remote_scan.
          ENDIF.
        ELSE.
          " Without TR filter: show the current Active version of the remote system.
          READ TABLE lt_remote_dir INDEX 1 INTO ls_remote_scan.
        ENDIF.
      ENDIF.
      IF ls_remote_scan IS NOT INITIAL.
        DATA(lv_remote_versno_text) = COND string(
          WHEN ls_remote_scan-versno = '00000'
            OR ls_remote_scan-versno = zcl_ave_version=>c_version-active
          THEN |Active ({ iv_system })|
          ELSE |{ CONV string( ls_remote_scan-versno + 0 ) } ({ iv_system })| ).
        " One row from the remote system: either the baseline before the TR
        " (if the TR was found in remote) or the current Active state (fallback).
        DATA(ls_remote_row) = VALUE ty_version_row(
          system      = iv_system
          versno      = ls_remote_scan-versno
          versno_text = lv_remote_versno_text
          datum       = ls_remote_scan-datum
          zeit        = ls_remote_scan-zeit
          author      = ls_remote_scan-author
          author_name = zcl_ave_popup_data=>get_user_name( ls_remote_scan-author )
          korrnum     = ls_remote_scan-korrnum
          objtype     = iv_objtype
          objname     = iv_objname ).
        " Remote row at INDEX 2: newest local version stays at INDEX 1 (current),
        " remote becomes INDEX 2 (previous/baseline) — auto-diff picks it naturally.
        INSERT ls_remote_row INTO result-versions INDEX 2.

        " Store remote row separately so Code Review can compute retrofit diff
        " (new vs remote) in addition to the primary local diff (new vs old).
        " old_version stays as the local baseline — do NOT overwrite it here.
        result-remote_version = ls_remote_row.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD load_light.
    " Read all VRSD rows for this object, newest first. Active (versno=0) rows
    " are skipped — for diff purposes the newest numbered version is what matters.
    TYPES: BEGIN OF ty_vrow,
             versno  TYPE versno,
             korrnum TYPE trkorr,
             author  TYPE versuser,
             datum   TYPE versdate,
             zeit    TYPE verstime,
           END OF ty_vrow.
    DATA lt_vrows TYPE TABLE OF ty_vrow.
    SELECT versno, korrnum, author, datum, zeit
      FROM vrsd
      WHERE objtype = @iv_objtype
        AND objname = @iv_objname
        AND versno <> '00000'
      ORDER BY versno DESCENDING
      INTO TABLE @lt_vrows.

    " Scope check per distinct korrnum: a VRSD korrnum belongs to the K when it
    " IS the K, is an S/R child of the K, or is a T-copy merged from the K
    " (resolve_parent_k handles all three). Cache the decision per korrnum.
    TYPES: BEGIN OF ty_scope_cache,
             korrnum  TYPE trkorr,
             in_scope TYPE abap_bool,
           END OF ty_scope_cache.
    DATA lt_scope_cache TYPE HASHED TABLE OF ty_scope_cache WITH UNIQUE KEY korrnum.

    LOOP AT lt_vrows INTO DATA(ls_vr).
      DATA(lv_ext) = zcl_ave_versno=>to_external( ls_vr-versno ).
      DATA(lv_in_scope) = abap_false.
      READ TABLE lt_scope_cache INTO DATA(ls_cache) WITH KEY korrnum = ls_vr-korrnum.
      IF sy-subrc = 0.
        lv_in_scope = ls_cache-in_scope.
      ELSE.
        DATA(lt_parents) = zcl_ave_request=>resolve_parent_k( ls_vr-korrnum ).
        lv_in_scope = xsdbool( line_exists( lt_parents[ table_line = iv_filter_korrnum ] ) ).
        INSERT VALUE #( korrnum = ls_vr-korrnum in_scope = lv_in_scope ) INTO TABLE lt_scope_cache.
      ENDIF.

      APPEND VALUE ty_version_row(
        versno      = lv_ext
        versno_text = CONV string( lv_ext + 0 )
        korrnum     = ls_vr-korrnum
        author      = ls_vr-author
        datum       = ls_vr-datum
        zeit        = ls_vr-zeit
        " reuse trfunction field to carry the scope flag for the pair walk below
        trfunction  = COND #( WHEN lv_in_scope = abap_true THEN 'X' ELSE '' ) ) TO result-versions.
    ENDLOOP.

    " new_version: newest row in K scope (rows are sorted newest first).
    LOOP AT result-versions INTO DATA(ls_nv) WHERE trfunction = 'X'.
      result-new_version = ls_nv.
      EXIT.
    ENDLOOP.
    CHECK result-new_version IS NOT INITIAL.

    " old_version: first row AFTER new_version that is outside K scope.
    DATA lv_past_new TYPE abap_bool.
    LOOP AT result-versions INTO DATA(ls_ov).
      IF lv_past_new = abap_false.
        IF ls_ov-versno = result-new_version-versno
           AND ls_ov-korrnum = result-new_version-korrnum.
          lv_past_new = abap_true.
        ENDIF.
        CONTINUE.
      ENDIF.
      IF ls_ov-trfunction <> 'X'.
        result-old_version = ls_ov.
        EXIT.
      ENDIF.
    ENDLOOP.

    " Clear the borrowed trfunction flag so callers see clean rows.
    CLEAR: result-new_version-trfunction, result-old_version-trfunction.
    LOOP AT result-versions ASSIGNING FIELD-SYMBOL(<v_clr>).
      CLEAR <v_clr>-trfunction.
    ENDLOOP.

    " New-object guard: the K wrote v1 → object created in this K, no baseline.
    IF result-old_version IS INITIAL AND result-new_version-versno <> '00001'.
      " Object existed before; oldest available version is the baseline.
      DATA(lv_last) = lines( result-versions ).
      IF lv_last > 1.
        READ TABLE result-versions INTO result-old_version INDEX lv_last.
        IF result-old_version-versno = result-new_version-versno.
          CLEAR result-old_version.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD map_to_e071_key.
    ev_object = SWITCH e071-object( iv_objtype
      WHEN 'REPS' OR 'REPT' THEN 'PROG'
      WHEN 'CINC' OR 'CLSD' THEN 'CLAS'
      ELSE iv_objtype ).
    ev_obj_name = iv_objname.
    CASE iv_objtype.
      WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'REPT'.
        DATA(lv_eq) = find( val = ev_obj_name sub = '=' ).
        IF lv_eq > 0.
          ev_obj_name = ev_obj_name(lv_eq).
        ENDIF.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
