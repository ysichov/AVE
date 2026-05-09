CLASS zcl_ave_version2 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Load source for a local version (active, modified, or historical)
    "! @parameter iv_objtype | Object type e.g. REPS, METH, FUNC, CLSD, INTF, DDLS
    "! @parameter iv_objname | Object name (long form, as in VRSD-OBJNAME)
    "! @parameter iv_versno  | Version number (external: 99998=active, 99999=modified, or real versno)
    CLASS-METHODS get_source_local
      IMPORTING
        iv_objtype    TYPE versobjtyp
        iv_objname    TYPE versobjnam
        iv_versno     TYPE versno
      RETURNING
        VALUE(result) TYPE abaptxt255_tab
      RAISING
        zcx_ave.

    "! Load source from a remote system via TMS
    "! @parameter iv_objtype | Object type
    "! @parameter iv_objname | Object name
    "! @parameter iv_versno  | Version number (99998 = active on remote system)
    "! @parameter iv_system  | TMS system name e.g. 'PRD'
    CLASS-METHODS get_source_remote
      IMPORTING
        iv_objtype    TYPE versobjtyp
        iv_objname    TYPE versobjnam
        iv_versno     TYPE versno
        iv_system     TYPE tmscsys-sysnam
      RETURNING
        VALUE(result) TYPE abaptxt255_tab
      RAISING
        zcx_ave.

  PRIVATE SECTION.

    "! Build a SVRS2_VERSIONABLE_OBJECT ready for LOCAL/REMOTE call
    CLASS-METHODS build_object
      IMPORTING
        iv_objtype    TYPE versobjtyp
        iv_objname    TYPE versobjnam
        iv_versno     TYPE versno
      RETURNING
        VALUE(result) TYPE svrs2_versionable_object.

    "! Extract source lines from the filled SVRS2_VERSIONABLE_OBJECT.
    "! Tries ABAPTEXT -> REPS -> XSSRC in the type-named component.
    CLASS-METHODS extract_source
      IMPORTING
        is_object     TYPE svrs2_versionable_object
      RETURNING
        VALUE(result) TYPE abaptxt255_tab.

    "! Read DDLS source via cl_svrs_tlogo_controller.
    "! iv_destination: empty = local, filled = RFC destination for remote system.
    CLASS-METHODS get_ddls_source
      IMPORTING
        iv_objname      TYPE versobjnam
        iv_versno       TYPE versno
        iv_destination  TYPE rfcdest DEFAULT space
      RETURNING
        VALUE(result)   TYPE abaptxt255_tab.

ENDCLASS.


CLASS zcl_ave_version2 IMPLEMENTATION.

  METHOD get_source_local.
    IF iv_objtype = 'DDLS'.
      result = get_ddls_source(
        iv_objname = iv_objname
        iv_versno  = iv_versno ).
      RETURN.
    ENDIF.

    DATA(lo_obj) = build_object( iv_objtype = iv_objtype
                                 iv_objname = iv_objname
                                 iv_versno  = iv_versno ).
    CALL FUNCTION 'SVRS_GET_VERSION_LOCAL'
      CHANGING
        object             = lo_obj
      EXCEPTIONS
        no_version         = 1
        version_unreadable = 2
        OTHERS             = 3.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.

    result = extract_source( lo_obj ).
  ENDMETHOD.


  METHOD get_source_remote.
    IF iv_objtype = 'DDLS'.
      " cl_svrs_tlogo_controller->get_object accepts iv_destination (RFC dest).
      " Need to resolve TMS system name -> RFC destination first.
      DATA lv_dest TYPE rfcdest.
      CALL FUNCTION 'TMS_CFG_GET_RFC_DESTINATION'
        EXPORTING
          iv_system      = iv_system
        IMPORTING
          ev_destination = lv_dest
        EXCEPTIONS
          OTHERS         = 1.
      IF sy-subrc <> 0.
        " Fallback: try system name directly as RFC destination
        lv_dest = iv_system.
      ENDIF.
      result = get_ddls_source(
        iv_objname     = iv_objname
        iv_versno      = iv_versno
        iv_destination = lv_dest ).
      RETURN.
    ENDIF.

    DATA(lo_obj) = build_object( iv_objtype = iv_objtype
                                 iv_objname = iv_objname
                                 iv_versno  = iv_versno ).
    CALL FUNCTION 'SVRS_GET_VERSION_REMOTE'
      EXPORTING
        p_tarsystem         = iv_system
      CHANGING
        object              = lo_obj
      EXCEPTIONS
        no_version          = 1
        system_error        = 2
        communication_error = 3
        OTHERS              = 4.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.

    result = extract_source( lo_obj ).
  ENDMETHOD.


  METHOD build_object.
    result-objtype     = iv_objtype.
    result-objname     = iv_objname.
    result-versno      = iv_versno.
    result-header_only = abap_false.

    CALL FUNCTION 'SVRS_INITIALIZE_DATAPOINTER'
      CHANGING
        objtype      = result-objtype
        data_pointer = result-data_pointer.
  ENDMETHOD.


  METHOD get_ddls_source.
    FIELD-SYMBOLS: <content> TYPE any,
                   <ddlsrc>  TYPE ANY TABLE,
                   <row>     TYPE any,
                   <field>   TYPE any.
    TRY.
        DATA(lo_controller) = NEW cl_svrs_tlogo_controller( ).
        DATA(lo_db_view) = lo_controller->get_object(
          iv_objtype     = 'DDLS'
          iv_objname     = iv_objname
          iv_versno      = iv_versno
          iv_destination = iv_destination ).
        CHECK lo_db_view IS BOUND.
        DATA(lo_log_view) = lo_db_view->convert_to_log_view( ).
        CHECK lo_log_view IS BOUND AND lo_log_view->ar_content IS BOUND.
        ASSIGN lo_log_view->ar_content->* TO <content>.
        CHECK sy-subrc = 0.
        ASSIGN COMPONENT 'DDLSOURCE' OF STRUCTURE <content> TO <ddlsrc>.
        CHECK sy-subrc = 0.
        LOOP AT <ddlsrc> ASSIGNING <row>.
          ASSIGN COMPONENT 1 OF STRUCTURE <row> TO <field>.
          IF sy-subrc = 0.
            APPEND CONV abaptxt255( CONV string( <field> ) ) TO result.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD extract_source.
    FIELD-SYMBOLS: <typed>  TYPE any,
                   <source> TYPE abaptxt255_tab.

    " Component name = objtype (e.g. obj-REPS, obj-FUNC, obj-METH, obj-CLSD ...)
    ASSIGN COMPONENT is_object-objtype OF STRUCTURE is_object TO <typed>.
    CHECK sy-subrc = 0.

    " Try the three known field names for source lines
    ASSIGN COMPONENT 'ABAPTEXT' OF STRUCTURE <typed> TO <source>.
    IF sy-subrc = 0.
      result = <source>.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT 'REPS' OF STRUCTURE <typed> TO <source>.
    IF sy-subrc = 0.
      result = <source>.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT 'XSSRC' OF STRUCTURE <typed> TO <source>.
    IF sy-subrc = 0.
      result = <source>.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
