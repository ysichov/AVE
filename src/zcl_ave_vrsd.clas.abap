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
        filter_user       TYPE versuser  OPTIONAL.

protected section.
  PRIVATE SECTION.

    DATA type        TYPE versobjtyp.
    DATA name        TYPE versobjnam.
    DATA no_toc      TYPE abap_bool.
    DATA filter_user TYPE versuser.
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
    me->type        = type.
    me->name        = name.
    me->no_toc      = no_toc.
    me->filter_user = filter_user.
    load_from_table( ignore_unreleased ).
    IF ignore_unreleased = abap_false.
      TRY.
        IF get_request_active_modif( ) IS NOT INITIAL.
          load_active_or_modified( zcl_ave_version=>c_version-active ).
        ENDIF.
        load_active_or_modified( zcl_ave_version=>c_version-modified ).
      CATCH zcx_ave.
        " Object type not supported by TR_GET_PGMID_FOR_OBJECT (e.g. CPUB, METH)
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
    IF me->no_toc = abap_false.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = 'T' ) TO lt_trtype.
    ENDIF.

    DATA lt_user TYPE RANGE OF versuser.
    IF me->filter_user IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = me->filter_user ) TO lt_user.
    ENDIF.

    SELECT v~* FROM vrsd AS v
      INNER JOIN e070 AS e ON e~trkorr = v~korrnum
      WHERE v~objtype = @me->type
        AND v~objname = @me->name
        AND v~versno IN @versno_range
        AND e~trfunction IN @lt_trtype
        AND v~author IN @lt_user
      ORDER BY v~versno
      INTO TABLE @me->vrsd_list.

    " Convert internal 0 → external 99998 for consistent sorting
    LOOP AT me->vrsd_list REFERENCE INTO DATA(vrsd).
      vrsd->versno = zcl_ave_versno=>to_external( vrsd->versno ).
    ENDLOOP.
  ENDMETHOD.


  METHOD load_active_or_modified.
    DATA(ls_vrsd) = read_vrsd( versno ).
    IF ls_vrsd IS INITIAL OR ls_vrsd-author IS INITIAL.
      RETURN.
    ENDIF.

    " Unreleased versions get current timestamp so all parts appear as one moment
    ls_vrsd-datum  = sy-datum.
    ls_vrsd-zeit   = sy-uzeit.
    ls_vrsd-versno = versno.
    ls_vrsd-objtype = me->type.
    ls_vrsd-objname = me->name.
    ls_vrsd-korrnum = get_request_active_modif( ).

    INSERT ls_vrsd INTO TABLE me->vrsd_list.
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
