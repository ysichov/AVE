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

    "! Load local source via SVRS2 and fall back to legacy VRSD/SVRS reader.
    CLASS-METHODS get_source_local_compat
      IMPORTING
        iv_objtype    TYPE versobjtyp
        iv_objname    TYPE versobjnam
        iv_versno     TYPE versno
        iv_korrnum    TYPE verskorrno OPTIONAL
        iv_author     TYPE versuser OPTIONAL
        iv_datum      TYPE versdate OPTIONAL
        iv_zeit       TYPE verstime OPTIONAL
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

    "! Load a dictionary table version as structured header + field list.
    "! Local read when iv_system is empty, remote TMS read otherwise.
    CLASS-METHODS get_tabd
      IMPORTING
        iv_objname    TYPE versobjnam
        iv_versno     TYPE versno
        iv_system     TYPE tmscsys-sysnam OPTIONAL
      RETURNING
        VALUE(result) TYPE zif_ave_popup_types=>ty_tabd
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

    "! Render TABD dictionary table definition as diff-friendly text lines.
    CLASS-METHODS extract_tabd_source
      IMPORTING
        is_object     TYPE svrs2_versionable_object
      RETURNING
        VALUE(result) TYPE abaptxt255_tab.

    "! Extract structured TABD header + field list from a filled versionable object.
    CLASS-METHODS extract_tabd_struct
      IMPORTING
        is_object     TYPE svrs2_versionable_object
      RETURNING
        VALUE(result) TYPE zif_ave_popup_types=>ty_tabd.

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


  METHOD get_source_local_compat.
    TRY.
        result = get_source_local(
          iv_objtype = iv_objtype
          iv_objname = iv_objname
          iv_versno  = iv_versno ).
        RETURN.
      CATCH zcx_ave.
    ENDTRY.

    DATA lt_vrsd TYPE vrsd_tab.
    DATA(lv_db_versno) = zcl_ave_versno=>to_internal( iv_versno ).
    SELECT * FROM vrsd
      WHERE objtype = @iv_objtype
        AND objname = @iv_objname
        AND versno  = @lv_db_versno
      INTO TABLE @lt_vrsd
      UP TO 1 ROWS.

    IF lt_vrsd IS INITIAL.
      APPEND VALUE vrsd(
        objtype = iv_objtype
        objname = iv_objname
        versno  = lv_db_versno
        korrnum = iv_korrnum
        author  = COND #( WHEN iv_author IS NOT INITIAL THEN iv_author ELSE sy-uname )
        datum   = iv_datum
        zeit    = iv_zeit ) TO lt_vrsd.
    ENDIF.

    result = NEW zcl_ave_version( lt_vrsd[ 1 ] )->get_source( ).
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

    " Dictionary table: render field list as text
    IF is_object-objtype = 'TABD'.
      result = extract_tabd_source( is_object ).
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


  METHOD get_tabd.
    DATA(lo_obj) = build_object( iv_objtype = 'TABD'
                                 iv_objname = iv_objname
                                 iv_versno  = iv_versno ).

    IF iv_system IS NOT INITIAL.
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
    ELSE.
      CALL FUNCTION 'SVRS_GET_VERSION_LOCAL'
        CHANGING
          object             = lo_obj
        EXCEPTIONS
          no_version         = 1
          version_unreadable = 2
          OTHERS             = 3.
    ENDIF.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.

    result = extract_tabd_struct( lo_obj ).
  ENDMETHOD.


  METHOD extract_tabd_struct.
    FIELD-SYMBOLS: <tabd>  TYPE any,
                   <dd02v> TYPE any,
                   <dd03v> TYPE ANY TABLE,
                   <row>   TYPE any,
                   <fld>   TYPE any.

    ASSIGN COMPONENT 'TABD' OF STRUCTURE is_object TO <tabd>.
    CHECK sy-subrc = 0.

    " Header attributes from DD02V
    ASSIGN COMPONENT 'DD02V' OF STRUCTURE <tabd> TO <dd02v>.
    IF sy-subrc = 0.
      ASSIGN COMPONENT 'TABNAME'  OF STRUCTURE <dd02v> TO <fld>. IF sy-subrc = 0. result-tabname  = <fld>. ENDIF.
      ASSIGN COMPONENT 'DDTEXT'   OF STRUCTURE <dd02v> TO <fld>. IF sy-subrc = 0. result-ddtext   = <fld>. ENDIF.
      ASSIGN COMPONENT 'TABCLASS' OF STRUCTURE <dd02v> TO <fld>. IF sy-subrc = 0. result-tabclass = <fld>. ENDIF.
      ASSIGN COMPONENT 'CONTFLAG' OF STRUCTURE <dd02v> TO <fld>. IF sy-subrc = 0. result-contflag = <fld>. ENDIF.
    ENDIF.

    " Field list from DD03V — keep one row per field in the logon language
    ASSIGN COMPONENT 'DD03V' OF STRUCTURE <tabd> TO <dd03v>.
    CHECK sy-subrc = 0.
    LOOP AT <dd03v> ASSIGNING <row>.
      " Skip non-logon-language duplicates (text rows repeat per DDLANGUAGE)
      ASSIGN COMPONENT 'DDLANGUAGE' OF STRUCTURE <row> TO <fld>.
      IF sy-subrc = 0 AND <fld> IS NOT INITIAL AND <fld> <> sy-langu.
        CONTINUE.
      ENDIF.

      DATA ls_field TYPE zif_ave_popup_types=>ty_tabd_field.
      CLEAR ls_field.
      ASSIGN COMPONENT 'FIELDNAME'  OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-fieldname  = <fld>. ENDIF.
      " A blank field name means a structural row (.INCLUDE etc.) — skip
      CHECK ls_field-fieldname IS NOT INITIAL.
      " Guard against duplicate field names already collected
      IF line_exists( result-fields[ fieldname = ls_field-fieldname ] ).
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT 'POSITION'   OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-position   = <fld>. ENDIF.
      ASSIGN COMPONENT 'KEYFLAG'    OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-keyflag    = <fld>. ENDIF.
      ASSIGN COMPONENT 'ROLLNAME'   OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-rollname   = <fld>. ENDIF.
      ASSIGN COMPONENT 'CHECKTABLE' OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-checktable = <fld>. ENDIF.
      ASSIGN COMPONENT 'DATATYPE'   OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-datatype   = <fld>. ENDIF.
      ASSIGN COMPONENT 'LENG'       OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-leng       = <fld>. ENDIF.
      ASSIGN COMPONENT 'DECIMALS'   OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-decimals   = <fld>. ENDIF.
      ASSIGN COMPONENT 'NOTNULL'    OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-notnull    = <fld>. ENDIF.
      ASSIGN COMPONENT 'DDTEXT'     OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. ls_field-ddtext     = <fld>. ENDIF.
      APPEND ls_field TO result-fields.
    ENDLOOP.

    SORT result-fields BY position.
  ENDMETHOD.


  METHOD extract_tabd_source.
    FIELD-SYMBOLS: <tabd>  TYPE any,
                   <dd02v> TYPE any,
                   <dd03v> TYPE ANY TABLE,
                   <dd08v> TYPE ANY TABLE,
                   <row>   TYPE any,
                   <fld>   TYPE any.

    ASSIGN COMPONENT 'TABD' OF STRUCTURE is_object TO <tabd>.
    CHECK sy-subrc = 0.

    " Header from DD02V
    ASSIGN COMPONENT 'DD02V' OF STRUCTURE <tabd> TO <dd02v>.
    IF sy-subrc = 0.
      DATA lv_tabname  TYPE string.
      DATA lv_tabclass TYPE string.
      DATA lv_contflag TYPE string.
      DATA lv_ddtext   TYPE string.
      ASSIGN COMPONENT 'TABNAME'  OF STRUCTURE <dd02v> TO <fld>. IF sy-subrc = 0. lv_tabname  = <fld>. ENDIF.
      ASSIGN COMPONENT 'TABCLASS' OF STRUCTURE <dd02v> TO <fld>. IF sy-subrc = 0. lv_tabclass = <fld>. ENDIF.
      ASSIGN COMPONENT 'CONTFLAG' OF STRUCTURE <dd02v> TO <fld>. IF sy-subrc = 0. lv_contflag = <fld>. ENDIF.
      ASSIGN COMPONENT 'DDTEXT'   OF STRUCTURE <dd02v> TO <fld>. IF sy-subrc = 0. lv_ddtext   = <fld>. ENDIF.
      APPEND CONV abaptxt255( |TABLE:        { lv_tabname }| )  TO result.
      APPEND CONV abaptxt255( |DESCRIPTION:  { lv_ddtext }| )   TO result.
      APPEND CONV abaptxt255( |TABLE CLASS:  { lv_tabclass }| ) TO result.
      APPEND CONV abaptxt255( |DELIVERY CL.: { lv_contflag }| ) TO result.
      APPEND CONV abaptxt255( '' )                               TO result.
    ENDIF.

    " Fields from DD03V
    ASSIGN COMPONENT 'DD03V' OF STRUCTURE <tabd> TO <dd03v>.
    IF sy-subrc = 0 AND lines( <dd03v> ) > 0.
      APPEND CONV abaptxt255(
        |{ 'FIELD'     WIDTH = 30 } { 'KEY' WIDTH = 3 } { 'ROLLNAME' WIDTH = 30 }| &&
        |{ 'TYPE' WIDTH = 8 } { 'LEN' WIDTH = 6 } { 'DEC' WIDTH = 4 } DESCRIPTION| )
        TO result.
      APPEND CONV abaptxt255( '----------------------------------------------------------------------------------------------' ) TO result.
      LOOP AT <dd03v> ASSIGNING <row>.
        DATA lv_field TYPE string.
        DATA lv_key   TYPE string.
        DATA lv_roll  TYPE string.
        DATA lv_dtype TYPE string.
        DATA lv_leng  TYPE string.
        DATA lv_dec   TYPE string.
        DATA lv_ftext TYPE string.
        ASSIGN COMPONENT 'FIELDNAME' OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. lv_field = <fld>. ENDIF.
        ASSIGN COMPONENT 'KEYFLAG'   OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. lv_key   = COND #( WHEN <fld> = 'X' THEN 'KEY' ELSE '' ). ENDIF.
        ASSIGN COMPONENT 'ROLLNAME'  OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. lv_roll  = <fld>. ENDIF.
        ASSIGN COMPONENT 'DATATYPE'  OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. lv_dtype = <fld>. ENDIF.
        ASSIGN COMPONENT 'LENG'      OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. lv_leng  = |{ <fld> }|. ENDIF.
        ASSIGN COMPONENT 'DECIMALS'  OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. lv_dec   = |{ <fld> }|. ENDIF.
        ASSIGN COMPONENT 'DDTEXT'    OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. lv_ftext = <fld>. ENDIF.
        APPEND CONV abaptxt255(
          |{ lv_field WIDTH = 30 } { lv_key WIDTH = 3 } { lv_roll WIDTH = 30 }| &&
          |{ lv_dtype WIDTH = 8 } { lv_leng WIDTH = 6 } { lv_dec WIDTH = 4 } { lv_ftext }| )
          TO result.
      ENDLOOP.
    ENDIF.

    " Foreign keys from DD08V
    ASSIGN COMPONENT 'DD08V' OF STRUCTURE <tabd> TO <dd08v>.
    IF sy-subrc = 0 AND lines( <dd08v> ) > 0.
      APPEND CONV abaptxt255( '' ) TO result.
      APPEND CONV abaptxt255( 'FOREIGN KEYS:' ) TO result.
      APPEND CONV abaptxt255( '--------------------------------------------------------------------------------' ) TO result.
      LOOP AT <dd08v> ASSIGNING <row>.
        DATA lv_checktab TYPE string.
        DATA lv_fktext   TYPE string.
        ASSIGN COMPONENT 'CHECKTABLE' OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. lv_checktab = <fld>. ENDIF.
        ASSIGN COMPONENT 'DDTEXT'     OF STRUCTURE <row> TO <fld>. IF sy-subrc = 0. lv_fktext   = <fld>. ENDIF.
        APPEND CONV abaptxt255( |CHECK TABLE: { lv_checktab WIDTH = 30 } { lv_fktext }| ) TO result.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
