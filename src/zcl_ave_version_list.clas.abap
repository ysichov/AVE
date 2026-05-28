CLASS zcl_ave_version_list DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES ty_version_row TYPE zif_ave_popup_types=>ty_version_row.
    TYPES ty_t_version_row TYPE zif_ave_popup_types=>ty_t_version_row.

    TYPES:
      BEGIN OF ty_result,
        versions TYPE ty_t_version_row,
        creator  TYPE versuser,
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

    LOOP AT result-versions INTO DATA(ls_k_ver)
      WHERE ( trfunction = 'K' OR trfunction = 'T' )
        AND korrnum IS NOT INITIAL.
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

      LOOP AT lt_all_tasks INTO DATA(ls_cand).
        CHECK ls_cand-as4date < <ver>-datum
           OR ( ls_cand-as4date = <ver>-datum AND ls_cand-as4time <= <ver>-zeit ).
        IF ( <ver>-trfunction = 'K' OR <ver>-trfunction = 'T' )
           AND ls_cand-strkorr <> <ver>-korrnum.
          CONTINUE.
        ENDIF.
        <ver>-task           = ls_cand-trkorr.
        <ver>-obj_owner      = ls_cand-as4user.
        <ver>-obj_owner_name = zcl_ave_popup_data=>get_user_name( ls_cand-as4user ).
        EXIT.
      ENDLOOP.
      IF ( <ver>-trfunction = 'K' OR <ver>-trfunction = 'T' )
         AND <ver>-task IS INITIAL.
        LOOP AT lt_request_tasks INTO ls_cand WHERE strkorr = <ver>-korrnum.
          CHECK ls_cand-as4date < <ver>-datum
             OR ( ls_cand-as4date = <ver>-datum AND ls_cand-as4time <= <ver>-zeit ).
          <ver>-task           = ls_cand-trkorr.
          <ver>-obj_owner      = ls_cand-as4user.
          <ver>-obj_owner_name = zcl_ave_popup_data=>get_user_name( ls_cand-as4user ).
          EXIT.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    IF it_filter_parent_korrnums IS NOT INITIAL OR it_filter_korrnums IS NOT INITIAL.
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

      LOOP AT it_filter_korrnums INTO DATA(ls_filter_korrnum)
        WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
        SELECT SINGLE trfunction, strkorr FROM e070
          WHERE trkorr = @ls_filter_korrnum-low
          INTO (@DATA(lv_filter_trf), @DATA(lv_filter_parent)).
        CHECK sy-subrc = 0.
        IF lv_filter_trf = lv_trf_s.
          INSERT VALUE #( korrnum = ls_filter_korrnum-low ) INTO TABLE lt_selected_keys.
          IF lv_filter_parent IS NOT INITIAL.
            INSERT VALUE #( korrnum = lv_filter_parent ) INTO TABLE lt_parent_keys.
          ENDIF.
        ELSEIF lv_filter_trf = 'K' OR lv_filter_trf = 'T'.
          INSERT VALUE #( korrnum = ls_filter_korrnum-low ) INTO TABLE lt_parent_keys.
        ENDIF.
      ENDLOOP.

      LOOP AT it_filter_parent_korrnums INTO DATA(ls_parent_filter)
        WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
        INSERT VALUE #( korrnum = ls_parent_filter-low ) INTO TABLE lt_parent_keys.
      ENDLOOP.

      IF lt_parent_keys IS NOT INITIAL.
        SELECT trkorr, as4date, as4time
          FROM e070
          FOR ALL ENTRIES IN @lt_parent_keys
          WHERE strkorr = @lt_parent_keys-korrnum
            AND trfunction = @lv_trf_s
          INTO TABLE @lt_parent_tasks.
        SORT lt_parent_tasks BY as4date ASCENDING as4time ASCENDING.
        READ TABLE lt_parent_tasks INTO DATA(ls_low_task) INDEX 1.
        IF sy-subrc = 0.
          lv_low_date = ls_low_task-as4date.
          lv_low_time = ls_low_task-as4time.
        ENDIF.
      ENDIF.

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
            AND trfunction = @lv_trf_s
          INTO TABLE @lt_selected_tasks.
        SORT lt_selected_tasks BY as4date ASCENDING as4time ASCENDING.
        READ TABLE lt_selected_tasks INTO DATA(ls_high_task) INDEX lines( lt_selected_tasks ).
        IF sy-subrc = 0.
          lv_high_date = ls_high_task-as4date.
          lv_high_time = ls_high_task-as4time.
        ENDIF.
      ENDIF.

      IF lv_low_date IS NOT INITIAL AND lv_high_date IS NOT INITIAL.
        LOOP AT result-versions INTO DATA(ls_ver).
          DATA(lv_req) = COND trkorr(
            WHEN ls_ver-korrnum IS NOT INITIAL
             AND line_exists( lt_selected_keys[ korrnum = CONV trkorr( ls_ver-korrnum ) ] )
            THEN CONV trkorr( ls_ver-korrnum )
            WHEN ls_ver-task IS NOT INITIAL THEN CONV trkorr( ls_ver-task )
            ELSE CONV trkorr( ls_ver-korrnum ) ).
          SELECT SINGLE as4date, as4time FROM e070
            WHERE trkorr = @lv_req
            INTO (@DATA(lv_req_date), @DATA(lv_req_time)).
          IF sy-subrc <> 0.
            lv_req_date = ls_ver-datum.
            lv_req_time = ls_ver-zeit.
          ENDIF.
          APPEND VALUE #(
            row      = ls_ver
            req      = lv_req
            as4date  = lv_req_date
            as4time  = lv_req_time
            selected = xsdbool( line_exists( lt_selected_keys[ korrnum = lv_req ] )
                             OR ( ls_ver-korrnum IS NOT INITIAL
                              AND line_exists( lt_selected_keys[ korrnum = CONV trkorr( ls_ver-korrnum ) ] ) ) ) )
            TO lt_work.
        ENDLOOP.
        SORT lt_work BY row-versno DESCENDING as4date DESCENDING as4time DESCENDING.

        LOOP AT lt_work INTO DATA(ls_work).
          IF ls_work-selected = abap_true.
            APPEND ls_work-row TO lt_filtered_versions.
            lv_selected_kept = abap_true.
            CONTINUE.
          ENDIF.
          IF ls_work-as4date > lv_high_date
            OR ( ls_work-as4date = lv_high_date AND ls_work-as4time > lv_high_time ).
            CONTINUE.
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

    IF iv_filter_korrnum IS NOT INITIAL AND iv_system IS NOT INITIAL.
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
        READ TABLE lt_remote_dir WITH KEY korrnum = iv_filter_korrnum INTO ls_remote_scan.
        IF sy-subrc = 0.
          READ TABLE lt_remote_dir INDEX sy-tabix + 1 INTO ls_remote_scan.
        ENDIF.
      ENDIF.
      IF ls_remote_scan IS NOT INITIAL.
        DATA(lv_remote_versno_text) = COND string(
          WHEN ls_remote_scan-versno = '00000'
            OR ls_remote_scan-versno = zcl_ave_version=>c_version-active
          THEN |Active ({ iv_system })|
          ELSE |{ CONV string( ls_remote_scan-versno + 0 ) } ({ iv_system })| ).
        INSERT VALUE ty_version_row(
          system      = iv_system
          versno      = ls_remote_scan-versno
          versno_text = lv_remote_versno_text
          datum       = ls_remote_scan-datum
          zeit        = ls_remote_scan-zeit
          author      = ls_remote_scan-author
          author_name = zcl_ave_popup_data=>get_user_name( ls_remote_scan-author )
          korrnum     = ls_remote_scan-korrnum
          objtype     = iv_objtype
          objname     = iv_objname ) INTO result-versions INDEX 2.

        INSERT VALUE ty_version_row(
          system      = iv_system
          versno      = zcl_ave_version=>c_version-active
          versno_text = |Active ({ iv_system })|
          objtype     = iv_objtype
          objname     = iv_objname ) INTO result-versions INDEX 1.
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
