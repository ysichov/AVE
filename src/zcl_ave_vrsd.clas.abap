"! Loads all VRSD records for a given object type/name.
"! Also appends artificial entries for the active (unreleased) and
"! modified (in-memory) versions, mirroring abapTimeMachine logic.
CLASS zcl_ave_vrsd DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA vrsd_list TYPE vrsd_tab READ-ONLY.

    METHODS constructor
      IMPORTING
        !type             TYPE versobjtyp
        !name             TYPE versobjnam
        ignore_unreleased TYPE abap_bool DEFAULT abap_false
        no_toc            TYPE abap_bool DEFAULT abap_false
        date_from         TYPE versdate  DEFAULT '00000000'.

protected section.
  PRIVATE SECTION.

    DATA type      TYPE versobjtyp.
    DATA name      TYPE versobjnam.
    DATA no_toc    TYPE abap_bool.
    DATA date_from TYPE versdate.
    DATA request_active_modif TYPE trkorr.

    METHODS load_from_table
      IMPORTING ignore_unreleased TYPE abap_bool.

    METHODS load_active_or_modified
      IMPORTING versno TYPE versno
      RAISING   zcx_ave.

    METHODS get_request_active_modif
      RETURNING VALUE(result) TYPE trkorr
      RAISING   zcx_ave.

    METHODS determine_request_active_modif
      RETURNING VALUE(result) TYPE trkorr
      RAISING   zcx_ave.

    METHODS get_versionable_object
      RETURNING VALUE(result) TYPE svrs2_versionable_object.

    METHODS get_versionable_object_mode
      IMPORTING versno        TYPE versno
      RETURNING VALUE(result) TYPE char1.

    METHODS read_vrsd
      IMPORTING versno        TYPE versno
      RETURNING VALUE(result) TYPE vrsd
      RAISING   zcx_ave.

ENDCLASS.



CLASS ZCL_AVE_VRSD IMPLEMENTATION.


  METHOD constructor.
    me->type      = type.
    me->name      = name.
    me->no_toc    = no_toc.
    me->date_from = date_from.
    load_from_table( ignore_unreleased ).
    IF ignore_unreleased = abap_false.
      TRY.
        load_active_or_modified( zcl_ave_version=>c_version-active ).
        load_active_or_modified( zcl_ave_version=>c_version-modified ).
      CATCH zcx_ave.
        " Object type not supported (e.g. CPUB, METH)
        " Released versions from DB are still available
      ENDTRY.
    ENDIF.
    SORT me->vrsd_list BY versno ASCENDING.
  ENDMETHOD.


  METHOD load_from_table.
    DATA versno_range TYPE RANGE OF versno.
    IF ignore_unreleased = abap_true.
      versno_range = VALUE #( sign = 'I' option = 'NE' ( low = '00000' ) ).
    ENDIF.

    DATA lt_trtype TYPE RANGE OF char1.
    IF me->no_toc = abap_true.
      APPEND VALUE #( sign = 'E' option = 'EQ' low = 'T' ) TO lt_trtype.
    ENDIF.

    SELECT v~* FROM vrsd AS v
      INNER JOIN e070 AS e ON e~trkorr = v~korrnum
      WHERE v~objtype = @me->type
        AND v~objname = @me->name
        AND v~versno IN @versno_range
        AND v~datum >= @me->date_from
        AND e~trfunction IN @lt_trtype
      ORDER BY v~versno
      INTO TABLE @me->vrsd_list.

    " Convert internal 0 → external 99998 for consistent sorting
    LOOP AT me->vrsd_list REFERENCE INTO DATA(vrsd).
      vrsd->versno = zcl_ave_versno=>to_external( vrsd->versno ).
    ENDLOOP.

    " Supplement from SVRS_GET_VERSION_DIRECTORY — it knows about versions
    " that SAP hasn't written to VRSD yet (e.g. activated into an unreleased
    " task, released request whose VRSD entry is missing, etc.)
    DATA lt_dir     TYPE TABLE OF vrsd_old.
    DATA lv_objtype LIKE vrsd_old-objtype.
    DATA lv_objname LIKE vrsd_old-objname.
    lv_objtype = me->type.
    lv_objname = me->name.
    CALL FUNCTION 'SVRS_GET_VERSION_DIRECTORY'
      EXPORTING
        objtype      = lv_objtype
        objname      = lv_objname
      TABLES
        version_list = lt_dir
      EXCEPTIONS
        no_entry     = 1
        OTHERS       = 2.
    IF sy-subrc = 0.
      LOOP AT lt_dir INTO DATA(ls_dir).
        " Skip active (00000→99998) and modified (99997) — handled by load_active_or_modified
        IF ls_dir-versno = '00000' OR ls_dir-versno = '99997'.
          CONTINUE.
        ENDIF.
        " Apply date_from filter
        IF me->date_from <> '00000000' AND ls_dir-datum < me->date_from.
          CONTINUE.
        ENDIF.
        " Apply no_toc filter (skip TOC entries)
        IF me->no_toc = abap_true.
          DATA ls_e070_dir TYPE e070.
          SELECT SINGLE * FROM e070 WHERE trkorr = @ls_dir-korrnum
            INTO @ls_e070_dir.
          IF ls_e070_dir-trfunction = 'T'.
            CONTINUE.
          ENDIF.
        ENDIF.
        " Skip if already loaded from VRSD
        DATA(lv_ext) = zcl_ave_versno=>to_external( CONV versno( ls_dir-versno ) ).
        READ TABLE me->vrsd_list WITH KEY versno = lv_ext TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          " Map VRSD_OLD → VRSD
          INSERT VALUE vrsd(
            versno  = lv_ext
            objtype = CONV #( ls_dir-objtype )
            objname = CONV #( ls_dir-objname )
            korrnum = ls_dir-korrnum
            author  = ls_dir-author
            datum   = ls_dir-datum
            zeit    = ls_dir-zeit
            rels    = ls_dir-rels
          ) INTO TABLE me->vrsd_list.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD load_active_or_modified.
    DATA(ls_vrsd) = read_vrsd( versno ).
    IF ls_vrsd IS INITIAL OR ls_vrsd-author IS INITIAL.
      RETURN.
    ENDIF.

    ls_vrsd-versno  = versno.
    ls_vrsd-objtype = me->type.
    ls_vrsd-objname = me->name.
    ls_vrsd-korrnum = get_request_active_modif( ).

    " If DB already has this versno — keep DB date but update author from FM
    " (FM returns task author which is more accurate than DB author)
    READ TABLE me->vrsd_list ASSIGNING FIELD-SYMBOL(<existing>)
      WITH KEY versno = versno.
    IF sy-subrc = 0.
      <existing>-author = ls_vrsd-author.
    ELSE.
      INSERT ls_vrsd INTO TABLE me->vrsd_list.
    ENDIF.
  ENDMETHOD.


  METHOD determine_request_active_modif.
    DATA s_ko100   TYPE ko100.
    DATA locked    TYPE trparflag.
    DATA s_tlock   TYPE tlock.
    DATA s_tlock_key TYPE tlock_int.

    CALL FUNCTION 'TR_GET_PGMID_FOR_OBJECT'
      EXPORTING
        iv_object      = me->type
      IMPORTING
        es_type        = s_ko100
      EXCEPTIONS
        illegal_object = 1
        OTHERS         = 2.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.

    DATA(s_e071) = VALUE e071(
      pgmid    = s_ko100-pgmid
      object   = me->type
      obj_name = me->name ).

    CALL FUNCTION 'TR_CHECK_TYPE'
      EXPORTING
        wi_e071     = s_e071
      IMPORTING
        pe_result   = locked
        we_lock_key = s_tlock_key.
    IF locked <> 'L'.
      RETURN.
    ENDIF.

    CALL FUNCTION 'TRINT_CHECK_LOCKS'
      EXPORTING
        wi_lock_key = s_tlock_key
      IMPORTING
        we_lockflag = locked
        we_tlock    = s_tlock
      EXCEPTIONS
        empty_key   = 1
        OTHERS      = 2.
    IF sy-subrc <> 0.
      zcx_ave=>raise_from_syst( ).
    ENDIF.

    IF locked IS INITIAL.
      RETURN.
    ENDIF.

    result = s_tlock-trkorr.
  ENDMETHOD.


  METHOD get_request_active_modif.
    IF me->request_active_modif IS INITIAL.
      me->request_active_modif = determine_request_active_modif( ).
    ENDIF.
    result = me->request_active_modif.
  ENDMETHOD.


  METHOD read_vrsd.
    CALL FUNCTION 'SVRS_INITIALIZE_DATAPOINTER'
      CHANGING
        objtype      = me->type
        data_pointer = me->type.

    DATA(obj) = get_versionable_object( ).
    CALL FUNCTION 'SVRS_GET_VERSION_REPOSITORY'
      EXPORTING
        mode      = get_versionable_object_mode( versno )
      CHANGING
        obj       = obj
      EXCEPTIONS
        not_found = 1
        OTHERS    = 2.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CALL FUNCTION 'SVRS_EXTRACT_INFO_FROM_OBJECT'
      EXPORTING
        object    = obj
      CHANGING
        vrsd_info = result.
  ENDMETHOD.


  METHOD get_versionable_object.
    result = VALUE #(
      objtype      = me->type
      data_pointer = me->type
      objname      = me->name
      header_only  = abap_true ).
  ENDMETHOD.


  METHOD get_versionable_object_mode.
    result = SWITCH #(
      versno
      WHEN zcl_ave_version=>c_version-active   THEN 'A'
      WHEN zcl_ave_version=>c_version-modified THEN 'M' ).
  ENDMETHOD.
ENDCLASS.
