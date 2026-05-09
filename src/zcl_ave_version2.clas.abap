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
    "! For TLOGO objects (DDLS etc.): deserializes TLOG-CONTENT via cl_svrs_tlogo_db_view.
    "! For ABAP objects: tries ABAPTEXT -> REPS -> XSSRC in the type-named component.
    CLASS-METHODS extract_source
      IMPORTING
        is_object     TYPE svrs2_versionable_object
      RETURNING
        VALUE(result) TYPE abaptxt255_tab.

    "! Deserialize TLOG-CONTENT from a filled versionable object and extract source.
    "! Works for both local and remote — caller just passes the filled object.
    CLASS-METHODS extract_tlog_source
      IMPORTING
        is_object     TYPE svrs2_versionable_object
      RETURNING
        VALUE(result) TYPE abaptxt255_tab.

ENDCLASS.


CLASS zcl_ave_version2 IMPLEMENTATION.

  METHOD get_source_local.
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


  METHOD extract_source.
    " TLOGO-based objects: TLOG-CONTENT is filled by LOCAL/REMOTE — deserialize it
    IF lines( is_object-tlog-content ) > 0.
      result = extract_tlog_source( is_object ).
      RETURN.
    ENDIF.

    " Standard ABAP objects: component name = objtype (REPS, FUNC, METH, CLSD ...)
    FIELD-SYMBOLS: <typed>  TYPE any,
                   <source> TYPE abaptxt255_tab.

    ASSIGN COMPONENT is_object-objtype OF STRUCTURE is_object TO <typed>.
    CHECK sy-subrc = 0.

    " Field name for source varies: ABAPTEXT / REPS / XSSRC
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


  METHOD extract_tlog_source.
    FIELD-SYMBOLS: <content> TYPE any,
                   <ddlsrc>  TYPE ANY TABLE,
                   <row>     TYPE any,
                   <field>   TYPE any.
    TRY.
        " Reconstruct db_view from the TLOG already filled by LOCAL/REMOTE
        DATA(lo_db_view) = cl_svrs_tlogo_db_view=>create_from_container(
          it_header  = is_object-tlog-header
          it_content = is_object-tlog-content
          iv_versno  = is_object-versno
          it_mdlog   = is_object-tlog-mdlog
          it_mdsrc   = is_object-smodisrc ).

        " Deserialize RAW -> logical view
        DATA(lo_controller) = cl_svrs_tlogo_controller=>get_instance( ).
        DATA(lo_config)     = lo_controller->get_config_class( is_object-objtype ).
        DATA(lo_log_view)   = lo_config->unpack_object( lo_db_view ).

        CHECK lo_log_view IS BOUND AND lo_log_view->ar_content IS BOUND.
        ASSIGN lo_log_view->ar_content->* TO <content>.
        CHECK sy-subrc = 0.

        " Component in the logical view named after object type (e.g. DDLSOURCE for DDLS)
        DATA(lv_component) = SWITCH #( is_object-objtype
          WHEN 'DDLS' THEN 'DDLSOURCE'
          ELSE              is_object-objtype ).
        ASSIGN COMPONENT lv_component OF STRUCTURE <content> TO <ddlsrc>.
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

ENDCLASS.
