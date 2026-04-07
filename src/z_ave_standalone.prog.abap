*&---------------------------------------------------------------------*
*& Report Z_AVE  -  Abap Versions Explorer
*&---------------------------------------------------------------------*
REPORT z_ave.

INTERFACE zif_ave_object DEFERRED.
CLASS zcl_ave_vrsd DEFINITION DEFERRED.
CLASS zcl_ave_versno DEFINITION DEFERRED.
CLASS zcl_ave_version DEFINITION DEFERRED.
CLASS zcl_ave_request DEFINITION DEFERRED.
CLASS zcl_ave_popup DEFINITION DEFERRED.
CLASS zcl_ave_object_tr DEFINITION DEFERRED.
CLASS zcl_ave_object_prog DEFINITION DEFERRED.
CLASS zcl_ave_object_func DEFINITION DEFERRED.
CLASS zcl_ave_object_factory DEFINITION DEFERRED.
CLASS zcl_ave_object_clas DEFINITION DEFERRED.
CLASS zcl_ave_author DEFINITION DEFERRED.
"! Exception class for AVE (Abap Versions Explorer)
CLASS zcx_ave DEFINITION
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        !textid   LIKE if_t100_message=>t100key OPTIONAL
        !previous LIKE previous OPTIONAL.

    CLASS-METHODS raise_from_syst
      RAISING
        zcx_ave.

ENDCLASS.
CLASS zcx_ave IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        previous = previous.
  ENDMETHOD.

  METHOD raise_from_syst.
    TRY.
        cx_proxy_t100=>raise_from_sy_msg( ).
      CATCH cx_proxy_t100 INTO DATA(exc_t100).
        RAISE EXCEPTION TYPE zcx_ave
          EXPORTING
            previous = exc_t100.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

INTERFACE zif_ave_object.

  "! A single versionable part of an object (e.g. one method, one include)
  TYPES:
    BEGIN OF ty_part,
      name        TYPE string,       " human-readable label
      object_name TYPE versobjnam,   " VRSD object name
      type        TYPE versobjtyp,   " VRSD object type (REPS, METH, CLSD, …)
    END OF ty_part,
    ty_t_part TYPE STANDARD TABLE OF ty_part WITH DEFAULT KEY.

  "! Returns the list of versionable parts for this object
  METHODS get_parts
    RETURNING
      VALUE(result) TYPE ty_t_part
    RAISING
      zcx_ave.

  "! Returns the logical object name
  METHODS get_name
    RETURNING
      VALUE(result) TYPE string.

  "! Returns TRUE if the object exists in the current system
  METHODS check_exists
    RETURNING
      VALUE(result) TYPE abap_bool.

ENDINTERFACE.

"! Resolves SAP username to display name, with caching
CLASS zcl_ave_author DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Returns the user's full name, or the username if the user no longer exists
    METHODS get_name
      IMPORTING
        !uname        TYPE syuname
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_author,
        uname TYPE syuname,
        name  TYPE string,
      END OF ty_s_author,
      ty_t_author TYPE SORTED TABLE OF ty_s_author WITH UNIQUE KEY uname.

    CLASS-DATA authors TYPE ty_t_author.

ENDCLASS.
"! Object handler for an ABAP class.
"! Returns class sections (pool, pub/pro/pri, local types/impl) plus all methods.
CLASS zcl_ave_object_clas DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE seoclsname
      RAISING
        zcx_ave.

  PRIVATE SECTION.
    DATA name TYPE seoclsname.

ENDCLASS.
"! Factory for AVE object handlers. Creates the right handler by object type string.
CLASS zcl_ave_object_factory DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF gc_type,
        program  TYPE string VALUE 'PROG',
        class    TYPE string VALUE 'CLAS',
        function TYPE string VALUE 'FUNC',
        tr       TYPE string VALUE 'TR',
      END OF gc_type.

    "! Returns an object handler for the given type+name.
    "! Raises ZCX_AVE if the object does not exist.
    METHODS get_instance
      IMPORTING
        object_type   TYPE string
        object_name   TYPE sobj_name
      RETURNING
        VALUE(result) TYPE REF TO zif_ave_object
      RAISING
        zcx_ave.

ENDCLASS.
"! Object handler for a function module (single FUNC part)
CLASS zcl_ave_object_func DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE rs38l_fnam.

  PRIVATE SECTION.
    DATA name TYPE rs38l_fnam.

ENDCLASS.
"! Object handler for a single program or include (one REPS part)
CLASS zcl_ave_object_prog DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE sobj_name.

  PRIVATE SECTION.
    DATA name TYPE sobj_name.

ENDCLASS.
"! Object handler for a Transport Request or Task.
"! Reads all objects from the TR and delegates to specific object handlers.
CLASS zcl_ave_object_tr DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !id TYPE trkorr.

  PRIVATE SECTION.

    DATA id TYPE trkorr.

    TYPES ty_t_object TYPE TABLE OF REF TO zif_ave_object WITH KEY table_line.

    METHODS get_object_keys
      RETURNING
        VALUE(result) TYPE trwbo_t_e071
      RAISING
        zcx_ave.

    METHODS get_objects_for_keys
      IMPORTING
        object_keys   TYPE trwbo_t_e071
      RETURNING
        VALUE(result) TYPE ty_t_object.

    METHODS get_object
      IMPORTING
        object_key    TYPE trwbo_s_e071
      RETURNING
        VALUE(result) TYPE REF TO zif_ave_object.

ENDCLASS.
CLASS zcl_ave_popup DEFINITION
  create public .

public section.

METHODS constructor
      IMPORTING
        i_object_type TYPE string   " PROG | CLAS | FUNC | TR
        i_object_name TYPE string.

    METHODS show.
protected section.
private section.

TYPES:
      BEGIN OF ty_version_row,
        versno      TYPE versno,
        datum       TYPE versdate,
        zeit        TYPE verstime,
        author      TYPE versuser,
        author_name TYPE ad_namtext,
        korrnum     TYPE verskorrno,
        objtype     TYPE versobjtyp,
        objname     TYPE versobjnam,
      END OF ty_version_row,
      ty_t_version_row TYPE STANDARD TABLE OF ty_version_row WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_node_info,
        node_key TYPE lvc_nkey,
        objtype  TYPE versobjtyp,
        objname  TYPE versobjnam,
      END OF ty_node_info,
      ty_t_node_info TYPE HASHED TABLE OF ty_node_info WITH UNIQUE KEY node_key.

    TYPES:
      BEGIN OF ty_tree_row,
        dummy TYPE c LENGTH 1,
      END OF ty_tree_row.

    "──────────── containers / controls ───────────────────────────
    CLASS-DATA mv_counter    TYPE i.

    DATA mv_object_type  TYPE string.
    DATA mv_object_name  TYPE string.

    DATA mo_box          TYPE REF TO cl_gui_dialogbox_container.
    DATA mo_split_main   TYPE REF TO cl_gui_splitter_container.
    DATA mo_split_top    TYPE REF TO cl_gui_splitter_container.
    DATA mo_cont_tree    TYPE REF TO cl_gui_container.
    DATA mo_cont_html    TYPE REF TO cl_gui_container.
    DATA mo_cont_vers    TYPE REF TO cl_gui_container.
    DATA mo_tree         TYPE REF TO cl_gui_alv_tree.
    DATA mo_html         TYPE REF TO cl_gui_html_viewer.
    DATA mo_grid_vers    TYPE REF TO cl_gui_alv_grid.

    "──────────── data ─────────────────────────────────────────────
    DATA mt_node_info    TYPE ty_t_node_info.
    DATA mt_versions     TYPE ty_t_version_row.
    DATA mv_cur_objtype  TYPE versobjtyp.
    DATA mv_cur_objname  TYPE versobjnam.

    "──────────── build methods ────────────────────────────────────
    METHODS build_layout.
    METHODS build_tree.
    METHODS build_html_viewer.
    METHODS build_versions_grid.

    "──────────── tree helpers ─────────────────────────────────────
    METHODS add_node
      IMPORTING
        i_parent_key TYPE lvc_nkey
        i_text       TYPE string
        i_objtype    TYPE versobjtyp
        i_objname    TYPE versobjnam
        i_icon       TYPE icon_d OPTIONAL
      RETURNING
        VALUE(r_key) TYPE lvc_nkey.

    METHODS populate_tree_prog.
    METHODS populate_tree_clas
      IMPORTING i_classname TYPE seoclsname
                i_parent    TYPE lvc_nkey OPTIONAL.
    METHODS populate_tree_func.
    METHODS populate_tree_tr.

    "──────────── event handlers ───────────────────────────────────
    METHODS on_node_double_click
      FOR EVENT node_double_click OF cl_gui_alv_tree
      IMPORTING node_key.

    METHODS on_ver_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row.

    METHODS on_box_close
      FOR EVENT close OF cl_gui_dialogbox_container
      IMPORTING sender.

    "──────────── logic ────────────────────────────────────────────
    METHODS load_versions
      IMPORTING
        i_objtype TYPE versobjtyp
        i_objname TYPE versobjnam.

    METHODS show_source
      IMPORTING
        i_objtype TYPE versobjtyp
        i_objname TYPE versobjnam
        i_versno  TYPE versno.

    METHODS set_html
      IMPORTING iv_html TYPE string.

    METHODS source_to_html
      IMPORTING
        it_source   TYPE abaptxt255_tab
        i_title     TYPE string
        i_meta      TYPE string OPTIONAL
      RETURNING
        VALUE(rv_html) TYPE string.
ENDCLASS.
"! Represents an SAP transport request — reads E070/E071 data
CLASS zcl_ave_request DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA id          TYPE trkorr    READ-ONLY.
    DATA description TYPE as4text   READ-ONLY.
    DATA status      TYPE trstatus  READ-ONLY.

    METHODS constructor
      IMPORTING
        !id TYPE trkorr
      RAISING
        zcx_ave.

    "! Returns the task (E070) most likely responsible for the given object.
    "! Prefers single-task requests; falls back to E071 lookup.
    METHODS get_task_for_object
      IMPORTING
                object_type   TYPE versobjtyp
                object_name   TYPE versobjnam
      RETURNING VALUE(result) TYPE e070.

protected section.
  PRIVATE SECTION.

    METHODS populate_details
      IMPORTING
        !id TYPE trkorr
      RAISING
        zcx_ave.

    METHODS get_task_if_only_one
      RETURNING VALUE(result) TYPE e070.

    METHODS get_latest_task_for_object
      IMPORTING
                object_type   TYPE versobjtyp
                object_name   TYPE versobjnam
      RETURNING VALUE(result) TYPE e070.

ENDCLASS.
"! Represents one version of a versionable object part.
"! Loads metadata from VRSD and source code via SVRS_GET_REPS_FROM_OBJECT.
CLASS zcl_ave_version DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF c_version,
        latest_db TYPE versno VALUE 0,
        latest    TYPE versno VALUE 99998,
        active    TYPE versno VALUE 99998,
        modified  TYPE versno VALUE 99999,
      END OF c_version.

    DATA version_number TYPE versno      READ-ONLY.
    DATA request        TYPE verskorrno  READ-ONLY.
    DATA task           TYPE verskorrno  READ-ONLY.
    DATA author         TYPE versuser    READ-ONLY.
    DATA author_name    TYPE ad_namtext  READ-ONLY.
    DATA date           TYPE versdate    READ-ONLY.
    DATA time           TYPE verstime    READ-ONLY.
    DATA objtype        TYPE versobjtyp  READ-ONLY.
    DATA objname        TYPE versobjnam  READ-ONLY.

    METHODS constructor
      IMPORTING
        !vrsd TYPE vrsd
      RAISING
        zcx_ave.

    "! Loads and returns the raw source code for this version
    METHODS get_source
      RETURNING
        VALUE(result) TYPE abaptxt255_tab
      RAISING
        zcx_ave.

  PRIVATE SECTION.

    DATA vrsd TYPE vrsd.

    METHODS load_attributes.

    "! Overwrite author/date/time from the task if possible
    "! (task owner better reflects who actually changed the code)
    METHODS load_latest_task
      RAISING zcx_ave.

    METHODS load_author_name
      RAISING zcx_ave.

ENDCLASS.
"! Converts between internal (DB) and external version numbers.
"! In the DB the latest version is stored as 0, but externally we use 99998
"! so that versions sort correctly (latest = highest).
CLASS zcl_ave_versno DEFINITION
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS to_internal
      IMPORTING
                versno        TYPE versno
      RETURNING VALUE(result) TYPE versno.

    CLASS-METHODS to_external
      IMPORTING
                versno        TYPE versno
      RETURNING VALUE(result) TYPE versno.

ENDCLASS.
"! Loads all VRSD records for a given object type/name.
"! Also appends artificial entries for the active (unreleased) and
"! modified (in-memory) versions, mirroring abapTimeMachine logic.
CLASS zcl_ave_vrsd DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA vrsd_list TYPE vrsd_tab READ-ONLY.

    METHODS constructor
      IMPORTING
        !type             TYPE versobjtyp
        !name             TYPE versobjnam
        ignore_unreleased TYPE abap_bool DEFAULT abap_false
      RAISING
        zcx_ave.

  PRIVATE SECTION.

    DATA type TYPE versobjtyp.
    DATA name TYPE versobjnam.
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
CLASS zcl_ave_vrsd IMPLEMENTATION.

  METHOD constructor.
    me->type = type.
    me->name = name.
    load_from_table( ignore_unreleased ).
    IF ignore_unreleased = abap_false.
      IF get_request_active_modif( ) IS NOT INITIAL.
        load_active_or_modified( zcl_ave_version=>c_version-active ).
      ENDIF.
      load_active_or_modified( zcl_ave_version=>c_version-modified ).
    ENDIF.
    SORT me->vrsd_list BY versno ASCENDING.
  ENDMETHOD.

  METHOD load_from_table.
    DATA versno_range TYPE RANGE OF versno.

    IF ignore_unreleased = abap_true.
      versno_range = VALUE #( sign = 'I' option = 'NE' ( low = '00000' ) ).
    ENDIF.

    SELECT * INTO TABLE me->vrsd_list
      FROM vrsd
      WHERE objtype = me->type
        AND objname = me->name
        AND versno IN versno_range
      ORDER BY PRIMARY KEY.

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

CLASS zcl_ave_versno IMPLEMENTATION.

  METHOD to_internal.
    " 99998 = active/latest externally → 0 in DB
    result = COND #(
      WHEN versno = 99998 THEN 0
      ELSE versno ).
  ENDMETHOD.

  METHOD to_external.
    " 0 in DB → 99998 externally (sorts after real versions)
    result = COND #(
      WHEN versno = 0 THEN 99998
      ELSE versno ).
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_version IMPLEMENTATION.

  METHOD constructor.
    me->vrsd = vrsd.
    load_attributes( ).
    load_latest_task( ).
    load_author_name( ).
  ENDMETHOD.

  METHOD get_source.
    DATA lt_trdir TYPE trdir_it.

    CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
      EXPORTING
        object_name = vrsd-objname
        object_type = vrsd-objtype
        versno      = zcl_ave_versno=>to_internal( me->version_number )
      TABLES
        repos_tab   = result
        trdir_tab   = lt_trdir
      EXCEPTIONS
        no_version  = 1
        OTHERS      = 2.
    " subrc <> 0 → empty source, not treated as error
  ENDMETHOD.

  METHOD load_attributes.
    me->version_number = vrsd-versno.
    me->author         = vrsd-author.
    me->date           = vrsd-datum.
    me->time           = vrsd-zeit.
    me->request        = vrsd-korrnum.
    me->objtype        = vrsd-objtype.
    me->objname        = vrsd-objname.
  ENDMETHOD.

  METHOD load_latest_task.
    IF me->request IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_request) = NEW zcl_ave_request( me->request ).
    DATA(ls_e070) = lo_request->get_task_for_object(
      object_type = vrsd-objtype
      object_name = vrsd-objname ).
    IF ls_e070-trkorr IS NOT INITIAL.
      me->task   = ls_e070-trkorr.
      me->author = ls_e070-as4user.
      me->date   = ls_e070-as4date.
      me->time   = ls_e070-as4time.
    ENDIF.
  ENDMETHOD.

  METHOD load_author_name.
    me->author_name = NEW zcl_ave_author( )->get_name( me->author ).
  ENDMETHOD.

ENDCLASS.

CLASS ZCL_AVE_REQUEST IMPLEMENTATION.
  METHOD constructor.
    me->id = id.
    populate_details( id ).
  ENDMETHOD.
  METHOD populate_details.
    SELECT as4text, trstatus INTO (@description, @status)
      UP TO 1 ROWS
      FROM e070
      LEFT JOIN e07t ON e07t~trkorr = e070~trkorr
      WHERE e070~trkorr = @id
      ORDER BY as4text, trstatus.
      EXIT.
    ENDSELECT.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.
  ENDMETHOD.
  METHOD get_task_for_object.
    " First try: if there is exactly one task, use it (avoids E071 lookup issues)
    result = get_task_if_only_one( ).

    IF result IS INITIAL.
      result = get_latest_task_for_object(
        object_type = object_type
        object_name = object_name ).
    ENDIF.

    " Workaround: VRSD stores REPS but E071 may store PROG
    IF result IS INITIAL AND object_type = 'REPS'.
      result = get_task_for_object(
        object_type = 'PROG'
        object_name = object_name ).
    ENDIF.
  ENDMETHOD.
  METHOD get_task_if_only_one.
    DATA e070_list TYPE STANDARD TABLE OF e070.
    SELECT trkorr, as4user, as4date, as4time
      INTO CORRESPONDING FIELDS OF TABLE @e070_list
      FROM e070
      WHERE strkorr = @me->id
      ORDER BY PRIMARY KEY.
    IF lines( e070_list ) = 1.
      result = e070_list[ 1 ].
    ENDIF.
  ENDMETHOD.
  METHOD get_latest_task_for_object.
    SELECT e070~trkorr, as4user, as4date, as4time
      INTO (@result-trkorr, @result-as4user, @result-as4date, @result-as4time)
      FROM e070
      INNER JOIN e071 ON e071~trkorr = e070~trkorr
      UP TO 1 ROWS
      WHERE strkorr  = @me->id
        AND object   = @object_type
        AND obj_name = @object_name
      ORDER BY as4date DESCENDING, as4time DESCENDING.
      EXIT.
    ENDSELECT.
  ENDMETHOD.
ENDCLASS.

CLASS ZCL_AVE_POPUP IMPLEMENTATION.
METHOD constructor.
    mv_object_type = i_object_type.
    mv_object_name = i_object_name.
  ENDMETHOD.
  METHOD show.
 "════════════════════════════════════════════════════════════════
    build_layout( ).
    build_tree( ).
    build_html_viewer( ).
    build_versions_grid( ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.
METHOD add_node.
    DATA ls_row TYPE ty_tree_row.

    mo_tree->add_node(
      EXPORTING
        i_relat_node_key = i_parent_key
        i_relationship   = cl_gui_column_tree=>relat_last_child
        i_node_text      = conv #( i_text )
        is_outtab_line    = ls_row
      IMPORTING
        e_new_node_key   = r_key ).

    INSERT VALUE #(
      node_key = r_key
      objtype  = i_objtype
      objname  = i_objname ) INTO TABLE mt_node_info.
  ENDMETHOD.
METHOD build_html_viewer.
    CREATE OBJECT mo_html
      EXPORTING
        parent = mo_cont_html.

    set_html(
      |<!DOCTYPE html><html><head><style>| &&
      `body{margin:0;background:#1e1e1e;color:#858585;` &&
      `font:13px/1.6 Consolas,monospace;display:flex;` &&
      `align-items:center;justify-content:center;height:100vh}` &&
      `</style></head><body>` &&
      `<div>Select an object in the tree → double-click a version below</div>` &&
      `</body></html>` ).
  ENDMETHOD.
METHOD build_layout.
    DATA: lv_pos TYPE i,
          lv_top TYPE i.

    ADD 1 TO mv_counter.
    lv_top = lv_pos = 50 - 5 * ( mv_counter DIV 5 ) - ( mv_counter MOD 5 ) * 5.

    CREATE OBJECT mo_box
      EXPORTING
        width                       = 1300
        height                      = 850
        top                         = lv_top
        left                        = lv_pos
        caption                     = |AVE – { mv_object_type }: { mv_object_name }|
        lifetime                    = cl_gui_control=>lifetime_dynpro
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0. RETURN. ENDIF.

    SET HANDLER me->on_box_close FOR mo_box.

    " Outer splitter: top band (tree + html) | bottom band (versions)
    CREATE OBJECT mo_split_main
      EXPORTING
        parent  = mo_box
        rows    = 2
        columns = 1.
    mo_split_main->set_row_height( id = 1 height = 70 ).
    mo_split_main->set_row_height( id = 2 height = 30 ).

    DATA(lo_top) = mo_split_main->get_container( row = 1 column = 1 ).
    mo_cont_vers = mo_split_main->get_container( row = 2 column = 1 ).

    " Inner splitter: left (tree) | right (html viewer)
    CREATE OBJECT mo_split_top
      EXPORTING
        parent  = lo_top
        rows    = 1
        columns = 2.
    mo_split_top->set_column_width( id = 1 width = 30 ).
    mo_split_top->set_column_width( id = 2 width = 70 ).

    mo_cont_tree = mo_split_top->get_container( row = 1 column = 1 ).
    mo_cont_html = mo_split_top->get_container( row = 1 column = 2 ).
  ENDMETHOD.
METHOD build_tree.
    DATA: lt_fcat   TYPE lvc_t_fcat,
          lt_outtab TYPE STANDARD TABLE OF ty_tree_row.

    APPEND VALUE lvc_s_fcat(
      fieldname = 'DUMMY'
      no_out    = abap_true ) TO lt_fcat.

    CREATE OBJECT mo_tree
      EXPORTING
        parent              = mo_cont_tree
        node_selection_mode = cl_gui_column_tree=>node_sel_mode_single
        item_selection      = abap_false
        no_html_header      = abap_true
        no_toolbar          = abap_false.

    SET HANDLER me->on_node_double_click FOR mo_tree.
    DATA: lt_events TYPE cntl_simple_events,
      ls_event  TYPE cntl_simple_event.

" 1. Обязательно сначала считываем текущие системные события
mo_tree->get_registered_events( IMPORTING events = lt_events ).

" 2. Добавляем ID двойного клика в список регистрации
ls_event-eventid = cl_gui_column_tree=>eventid_node_double_click.
ls_event-appl_event = 'X'. " Чтобы событие долетело до вашего HANDLER
APPEND ls_event TO lt_events.

" 3. Отправляем обновленный список обратно в дерево
mo_tree->set_registered_events( EXPORTING events = lt_events ).

    mo_tree->set_table_for_first_display(
      EXPORTING
        is_hierarchy_header = VALUE treev_hhdr(
                                heading = mv_object_name
                                width   = 40 )
      CHANGING
        it_fieldcatalog     = lt_fcat
        it_outtab           = lt_outtab ).

    " Populate nodes according to object type
    CASE mv_object_type.
      WHEN 'PROG'.
        populate_tree_prog( ).
      WHEN 'CLAS'.
        populate_tree_clas( CONV #( mv_object_name ) ).
      WHEN 'FUNC'.
        populate_tree_func( ).
      WHEN 'TR'.
        populate_tree_tr( ).
    ENDCASE.

    mo_tree->frontend_update( ).
  ENDMETHOD.
METHOD build_versions_grid.
    DATA lt_fcat TYPE lvc_t_fcat.

    DEFINE _fc.
      APPEND VALUE lvc_s_fcat(
        fieldname = &1
        coltext   = &2
        outputlen = &3 ) TO lt_fcat.
    END-OF-DEFINITION.

    _fc: 'VERSNO'      'Version'  6,
         'DATUM'       'Date'    10,
         'ZEIT'        'Time'     8,
         'AUTHOR'      'Author'  12,
         'AUTHOR_NAME' 'Name'    25,
         'KORRNUM'     'Request' 20,
         'OBJTYPE'     'Type'     6,
         'OBJNAME'     'Object'  40.

    CREATE OBJECT mo_grid_vers
      EXPORTING
        i_parent = mo_cont_vers.

    SET HANDLER me->on_ver_double_click FOR mo_grid_vers.

*    " double_click of cl_gui_alv_grid must be registered explicitly,
*    " same as node_double_click of cl_gui_alv_tree.
*    DATA: lt_events TYPE cntl_simple_events,
*          ls_event  TYPE cntl_simple_event.
*    mo_grid_vers->get_registered_events( IMPORTING events = lt_events ).
*    ls_event-eventid    = cl_gui_alv_grid=>mc_evt_double_click.
*    ls_event-appl_event = abap_true.
*    APPEND ls_event TO lt_events.
*    mo_grid_vers->set_registered_events( EXPORTING events = lt_events ).

    mo_grid_vers->set_table_for_first_display(
      EXPORTING
        is_layout       = VALUE lvc_s_layo(
                            zebra      = abap_true
                            sel_mode   = 'D'
                            cwidth_opt = 'X'
                            info_fname = ''
                            no_toolbar = ' ' )
        i_save          = 'X'
      CHANGING
        it_fieldcatalog = lt_fcat
        it_outtab       = mt_versions ).
  ENDMETHOD.
METHOD load_versions.
    CLEAR mt_versions.

    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd(
          type = i_objtype
          name = i_objname ).
      CATCH zcx_ave.
        RETURN.  " object not found / not versionable
    ENDTRY.

    " Load each version independently - a bad request on one version
    " should not stop the rest from loading
    LOOP AT lo_vrsd->vrsd_list INTO DATA(ls_vrsd).
      TRY.
          DATA(lo_ver) = NEW zcl_ave_version( ls_vrsd ).
          APPEND VALUE ty_version_row(
            versno      = lo_ver->version_number
            datum       = lo_ver->date
            zeit        = lo_ver->time
            author      = lo_ver->author
            author_name = lo_ver->author_name
            korrnum     = lo_ver->request
            objtype     = lo_ver->objtype
            objname     = lo_ver->objname ) TO mt_versions.
        CATCH zcx_ave.
          " Skip this version if metadata can't be loaded
      ENDTRY.
    ENDLOOP.

    " Show newest first
    SORT mt_versions BY versno DESCENDING.
  ENDMETHOD.
METHOD on_box_close.
    sender->free( ).
    CLEAR mo_box.
  ENDMETHOD.
METHOD on_node_double_click.
    " Use a local copy to avoid ambiguity between the event parameter
    " "node_key" and the table key field of the same name
    DATA(lv_nkey) = node_key.
    READ TABLE mt_node_info INTO DATA(ls_node)
      WITH TABLE KEY node_key = lv_nkey.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mv_cur_objtype = ls_node-objtype.
    mv_cur_objname = ls_node-objname.

    load_versions(
      i_objtype = ls_node-objtype
      i_objname = ls_node-objname ).

    mo_grid_vers->refresh_table_display( ).
  ENDMETHOD.
METHOD on_ver_double_click.
    READ TABLE mt_versions INTO DATA(ls_ver) INDEX e_row-index.
    IF sy-subrc <> 0. RETURN. ENDIF.

    show_source(
      i_objtype = ls_ver-objtype
      i_objname = ls_ver-objname
      i_versno  = ls_ver-versno ).
  ENDMETHOD.
METHOD populate_tree_clas.
    DATA(lv_cname) = CONV seoclsname( i_classname ).

    DATA(lv_root) = add_node(
      i_parent_key = i_parent
      i_text       = conv #( lv_cname )
      i_objtype    = 'CLSD'
      i_objname    = CONV #( lv_cname ) ).

    " Sections
    add_node( i_parent_key = lv_root i_text = 'Public'    i_objtype = 'CPUB' i_objname = CONV #( lv_cname ) ).
    add_node( i_parent_key = lv_root i_text = 'Protected' i_objtype = 'CPRO' i_objname = CONV #( lv_cname ) ).
    add_node( i_parent_key = lv_root i_text = 'Private'   i_objtype = 'CPRI' i_objname = CONV #( lv_cname ) ).
    add_node( i_parent_key = lv_root i_text = 'Local types'
              i_objtype = 'REPS'
              i_objname = CONV #( cl_oo_classname_service=>get_cl_name( lv_cname ) ) ).
    add_node( i_parent_key = lv_root i_text = 'Local impl'
              i_objtype = 'CINC'
              i_objname = CONV #( cl_oo_classname_service=>get_ccimp_name( lv_cname ) ) ).
    add_node( i_parent_key = lv_root i_text = 'Test classes'
              i_objtype = 'CINC'
              i_objname = CONV #( cl_oo_classname_service=>get_ccau_name( lv_cname ) ) ).

    " Methods
    LOOP AT cl_oo_classname_service=>get_all_method_includes( lv_cname )
         INTO DATA(ls_mi).
      DATA(lv_mname) = cl_oo_classname_service=>get_method_by_include(
                         ls_mi-incname )-cpdname.
      DATA(lv_obj)   = CONV versobjnam( |{ lv_cname WIDTH = 30 }{ lv_mname }| ).
      add_node(
        i_parent_key = lv_root
        i_text       = |{ to_lower( lv_mname ) }()|
        i_objtype    = 'METH'
        i_objname    = lv_obj ).
    ENDLOOP.
  ENDMETHOD.
METHOD populate_tree_func.
    SELECT SINGLE pname, include INTO ( @DATA(lv_pname), @DATA(lv_incl) )
      FROM tfdir WHERE funcname = @mv_object_name.
    IF sy-subrc = 0.
      SHIFT lv_pname LEFT BY 3 PLACES.
      DATA(lv_incl_name) = lv_pname && 'U' && lv_incl.
      add_node(
        i_parent_key = ''
        i_text       = |{ mv_object_name } ({ lv_incl_name })|
        i_objtype    = 'FUNC'
        i_objname    = CONV #( mv_object_name ) ).
    ENDIF.
  ENDMETHOD.
METHOD populate_tree_prog.
    add_node(
      i_parent_key = ''
      i_text       = mv_object_name
      i_objtype    = 'REPS'
      i_objname    = CONV #( mv_object_name ) ).
  ENDMETHOD.
METHOD populate_tree_tr.
    DATA request_data TYPE trwbo_request.
    request_data-h-trkorr = CONV #( mv_object_name ).

    CALL FUNCTION 'TRINT_READ_REQUEST'
      EXPORTING
        iv_read_objs  = abap_true
      CHANGING
        cs_request    = request_data
      EXCEPTIONS
        error_occured = 1
        OTHERS        = 2.
    IF sy-subrc <> 0. RETURN. ENDIF.

    SORT request_data-objects BY pgmid object obj_name.
    DELETE ADJACENT DUPLICATES FROM request_data-objects
      COMPARING pgmid object obj_name.

    LOOP AT request_data-objects INTO DATA(ls_obj).
      CASE ls_obj-pgmid.
        WHEN 'LIMU'.
          CASE ls_obj-object.
            WHEN 'REPS'.
              add_node( i_parent_key = '' i_text = |{ ls_obj-obj_name }|
                        i_objtype = 'REPS' i_objname = CONV #( ls_obj-obj_name ) ).
            WHEN 'METH'.
              add_node( i_parent_key = '' i_text = |METH: { ls_obj-obj_name }|
                        i_objtype = 'METH' i_objname = CONV #( ls_obj-obj_name ) ).
            WHEN 'CINC'.
              add_node( i_parent_key = '' i_text = |CINC: { ls_obj-obj_name }|
                        i_objtype = 'CINC' i_objname = CONV #( ls_obj-obj_name ) ).
          ENDCASE.
        WHEN 'R3TR'.
          CASE ls_obj-object.
            WHEN 'CLAS'.
              populate_tree_clas( CONV #( ls_obj-obj_name ) ).
            WHEN 'PROG'.
              add_node( i_parent_key = '' i_text = |PROG: { ls_obj-obj_name }|
                        i_objtype = 'REPS' i_objname = CONV #( ls_obj-obj_name ) ).
          ENDCASE.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.
METHOD set_html.
    " Build w3htmltab – APPEND short chunks (255 chars) to stay compatible
    " with both old (C255) and new (STRING) line types.
    DATA: lt_html   TYPE w3htmltab,
          lv_url    TYPE w3url,
          lv_offset TYPE i,
          lv_len    TYPE i,
          lv_chunk  TYPE i.

    lv_len = strlen( iv_html ).
    WHILE lv_offset < lv_len.
      lv_chunk = COND #(
        WHEN lv_len - lv_offset > 255 THEN 255
        ELSE lv_len - lv_offset ).
      APPEND VALUE #( line = iv_html+lv_offset(lv_chunk) ) TO lt_html.
      lv_offset += lv_chunk.
    ENDWHILE.

    " load_data registers the content and returns an internal URL;
    " show_url actually renders it in the browser control.
    mo_html->load_data(
      IMPORTING
        assigned_url = lv_url
      CHANGING
        data_table   = lt_html
      EXCEPTIONS
        OTHERS       = 1 ).

    mo_html->show_url( url = lv_url ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.
METHOD show_source.
    TRY.
        " Re-create the VRSD entry to get a version object
        DATA lt_vrsd TYPE vrsd_tab.
        SELECT *
          FROM vrsd
          WHERE objtype = @i_objtype
            AND objname = @i_objname
            AND versno  = @( zcl_ave_versno=>to_internal( i_versno ) )

          INTO TABLE @lt_vrsd
            UP TO 1 ROWS.

        DATA ls_vrsd TYPE vrsd.
        IF lt_vrsd IS NOT INITIAL.
          ls_vrsd = lt_vrsd[ 1 ].
        ELSE.
          " Active / Modified version: build synthetic VRSD
          ls_vrsd-objtype = i_objtype.
          ls_vrsd-objname = i_objname.
          ls_vrsd-versno  = zcl_ave_versno=>to_internal( i_versno ).
          ls_vrsd-author  = sy-uname.
          ls_vrsd-datum   = sy-datum.
          ls_vrsd-zeit    = sy-uzeit.
        ENDIF.

        DATA(lo_ver)    = NEW zcl_ave_version( ls_vrsd ).
        DATA(lt_source) = lo_ver->get_source( ).

        DATA(lv_meta) = |Ver: { i_versno } | &&
                        |{ lo_ver->date } { lo_ver->time } | &&
                        |{ lo_ver->author } ({ lo_ver->author_name })| &&
                        COND string( WHEN lo_ver->request IS NOT INITIAL
                                     THEN | - { lo_ver->request }|
                                     ELSE `` ).

        set_html( source_to_html(
          it_source = lt_source
          i_title   = |{ i_objtype }: { i_objname }|
          i_meta    = lv_meta ) ).

      CATCH zcx_ave.
        set_html( `<html><body style="background:#1e1e1e;color:#f44;` &&
                  `font-family:Consolas;padding:20px">` &&
                  `Error loading source.</body></html>` ).
    ENDTRY.
  ENDMETHOD.
METHOD source_to_html.
    DATA lv_rows TYPE string.
    DATA lv_lno  TYPE i.

    LOOP AT it_source INTO DATA(ls_src).
      lv_lno += 1.
      DATA(lv_line) = CONV string( ls_src ).
      REPLACE ALL OCCURRENCES OF `&` IN lv_line WITH `&amp;`.
      REPLACE ALL OCCURRENCES OF `<` IN lv_line WITH `&lt;`.
      REPLACE ALL OCCURRENCES OF `>` IN lv_line WITH `&gt;`.
      lv_rows = lv_rows &&
        |<tr><td class="ln">{ lv_lno }</td>| &&
        |<td class="cd">{ lv_line }</td></tr>|.
    ENDLOOP.

    rv_html =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      `*{margin:0;padding:0;box-sizing:border-box}` &&
      `body{background:#1e1e1e;color:#d4d4d4;font:12px/1.5 Consolas,monospace}` &&
      `.hdr{background:#252526;padding:5px 12px;border-bottom:1px solid #3c3c3c;` &&
            `color:#9cdcfe;font-size:11px;display:flex;gap:16px;flex-wrap:wrap}` &&
      `.ttl{color:#4ec9b0;font-weight:bold}` &&
      `.meta{color:#858585}` &&
      `table{border-collapse:collapse;width:100%}` &&
      `tr:hover td{background:#2a2d2e}` &&
      `.ln{color:#858585;text-align:right;padding:1px 10px 1px 5px;` &&
           `user-select:none;min-width:42px;border-right:1px solid #3c3c3c;` &&
           `white-space:nowrap}` &&
      `.cd{padding:1px 8px;white-space:pre}` &&
      `</style></head><body>` &&
      `<div class="hdr">` &&
      `<span class="ttl">` && i_title && `</span>` &&
      `<span class="meta">` && i_meta && `</span>` &&
      `</div>` &&
      `<table><tbody>` && lv_rows &&
      `</tbody></table></body></html>`.
  ENDMETHOD.
ENDCLASS.

CLASS zcl_ave_object_tr IMPLEMENTATION.

  METHOD constructor.
    me->id = id.
  ENDMETHOD.

  METHOD get_object.
    TRY.
        result = COND #(
          " R3TR CLAS → expand class with all sections + methods
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'CLAS'
            THEN NEW zcl_ave_object_clas( CONV #( object_key-obj_name ) )
          " R3TR FUGR → treated as program (main include)
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'FUGR'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) )
          " LIMU FUNC → single function module
          WHEN object_key-pgmid = 'LIMU' AND object_key-object = 'FUNC'
            THEN NEW zcl_ave_object_func( CONV #( object_key-obj_name ) )
          " LIMU REPS → single program/include
          WHEN object_key-pgmid = 'LIMU' AND object_key-object = 'REPS'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) ) ).
      CATCH zcx_ave.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.

  METHOD get_object_keys.
    DATA request_data TYPE trwbo_request.
    request_data-h-trkorr = id.

    CALL FUNCTION 'TRINT_READ_REQUEST'
      EXPORTING
        iv_read_objs  = abap_true
      CHANGING
        cs_request    = request_data
      EXCEPTIONS
        error_occured = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.

    result = request_data-objects.
    SORT result BY pgmid ASCENDING object ASCENDING obj_name ASCENDING.
    DELETE ADJACENT DUPLICATES FROM result COMPARING pgmid object obj_name.
  ENDMETHOD.

  METHOD get_objects_for_keys.
    result = VALUE #(
      FOR key IN object_keys
      LET obj = get_object( key )
      IN ( obj ) ).
    DELETE result WHERE table_line IS NOT BOUND.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    TRY.
        NEW zcl_ave_request( me->id ).
        result = abap_true.
      CATCH zcx_ave.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = id.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    DATA(object_keys) = get_object_keys( ).
    DATA(objects)     = get_objects_for_keys( object_keys ).

    result = REDUCE #(
      INIT t = VALUE zif_ave_object=>ty_t_part( )
      FOR obj IN objects
      FOR part IN obj->get_parts( )
      NEXT t = VALUE #( BASE t ( part ) ) ).
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_object_prog IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    SELECT SINGLE @abap_true INTO @result
      FROM trdir
      WHERE name = @name.
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    result = VALUE #( (
      name        = CONV #( name )
      object_name = CONV #( name )
      type        = 'REPS' ) ).
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_object_func IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    CALL FUNCTION 'FUNCTION_EXISTS'
      EXPORTING
        funcname           = name
      EXCEPTIONS
        function_not_exist = 1
        OTHERS             = 2.
    result = boolc( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    result = VALUE #( (
      name        = CONV #( name )
      object_name = CONV #( name )
      type        = 'FUNC' ) ).
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_object_factory IMPLEMENTATION.

  METHOD get_instance.
    result = SWITCH #(
      object_type
      WHEN gc_type-program  THEN NEW zcl_ave_object_prog( object_name )
      WHEN gc_type-class    THEN NEW zcl_ave_object_clas( CONV #( object_name ) )
      WHEN gc_type-function THEN NEW zcl_ave_object_func( CONV #( object_name ) )
      WHEN gc_type-tr       THEN NEW zcl_ave_object_tr(   CONV #( object_name ) ) ).

    IF result IS NOT BOUND OR result->check_exists( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_object_clas IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    cl_abap_classdescr=>describe_by_name(
      EXPORTING
        p_name         = name
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    result = boolc( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    " Fixed sections of the class
    result = VALUE #(
      ( name = 'Class pool'                 object_name = CONV #( name )                                  type = 'CLSD' )
      ( name = 'Public section'             object_name = CONV #( name )                                  type = 'CPUB' )
      ( name = 'Protected section'          object_name = CONV #( name )                                  type = 'CPRO' )
      ( name = 'Private section'            object_name = CONV #( name )                                  type = 'CPRI' )
      ( name = 'Local class definition'     object_name = CONV #( cl_oo_classname_service=>get_ccdef_name( name ) ) type = 'CDEF' )
      ( name = 'Local class implementation' object_name = CONV #( cl_oo_classname_service=>get_ccimp_name( name ) ) type = 'CINC' )
      ( name = 'Local macros'               object_name = CONV #( cl_oo_classname_service=>get_ccmac_name( name ) ) type = 'CINC' )
      ( name = 'Local types'                object_name = CONV #( cl_oo_classname_service=>get_cl_name( name ) )    type = 'REPS' )
      ( name = 'Test classes'               object_name = CONV #( cl_oo_classname_service=>get_ccau_name( name ) )  type = 'CINC' ) ).

    " One entry per method
    result = VALUE #( BASE result
      FOR method_include IN cl_oo_classname_service=>get_all_method_includes( name )
      LET method_name = cl_oo_classname_service=>get_method_by_include(
                          method_include-incname )-cpdname
          obj_name    = CONV versobjnam( |{ name WIDTH = 30 }{ method_name }| )
      IN ( name        = |{ to_lower( method_name ) }()|
           object_name = obj_name
           type        = 'METH' ) ).
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_author IMPLEMENTATION.

  METHOD get_name.
    DATA author LIKE LINE OF authors.

    READ TABLE authors INTO author WITH KEY uname = uname.
    IF sy-subrc <> 0.
      author-uname = uname.
      SELECT name_textc INTO author-name
        UP TO 1 ROWS
        FROM user_addr
        WHERE bname = uname
        ORDER BY name_textc.
        EXIT.
      ENDSELECT.
      IF sy-subrc <> 0.
        author-name = uname.
      ENDIF.
      INSERT author INTO TABLE authors.
    ENDIF.
    result = author-name.
  ENDMETHOD.

ENDCLASS.

" Global reference keeps the popup object (and its event handlers) alive
" while the selection screen is active. Without this the object would be
" garbage-collected as soon as FORM run_ave returns.
DATA go_popup TYPE REF TO zcl_ave_popup.

"======================================================================
" Selection screen
"======================================================================
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

  " Object type radio buttons
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS rb_prog RADIOBUTTON GROUP typ DEFAULT 'X'
               USER-COMMAND utyp MODIF ID typ.
    "SELECTION-SCREEN COMMENT 3(17) TEXT-010 FOR FIELD rb_prog.
    PARAMETERS rb_clas RADIOBUTTON GROUP typ MODIF ID typ.
    "SELECTION-SCREEN COMMENT 3(7)  TEXT-011 FOR FIELD rb_clas.
    PARAMETERS rb_func RADIOBUTTON GROUP typ MODIF ID typ.
   " SELECTION-SCREEN COMMENT 3(17) TEXT-012 FOR FIELD rb_func.
    PARAMETERS rb_tr   RADIOBUTTON GROUP typ MODIF ID typ.
   " SELECTION-SCREEN COMMENT 3(16) TEXT-013 FOR FIELD rb_tr.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN SKIP 1.

  " Input fields - only the active one is shown (MODIF ID)
  PARAMETERS p_prog  TYPE progname   MATCHCODE OBJECT progname     MODIF ID prg.
  PARAMETERS p_clas  TYPE seoclsname MATCHCODE OBJECT sfbeclname   MODIF ID cls.
  PARAMETERS p_func  TYPE rs38l_fnam MATCHCODE OBJECT cacs_function MODIF ID fnc.
  PARAMETERS p_tr    TYPE trkorr                                    MODIF ID trq.

SELECTION-SCREEN END OF BLOCK b1.

"======================================================================
INITIALIZATION.
  PERFORM supress_button.

"======================================================================
AT SELECTION-SCREEN OUTPUT.
  " Show only the field that matches the selected radio button
  LOOP AT SCREEN.
    CASE screen-group1.
      WHEN 'PRG'. screen-active = boolc( rb_prog = 'X' ).
      WHEN 'CLS'. screen-active = boolc( rb_clas = 'X' ).
      WHEN 'FNC'. screen-active = boolc( rb_func = 'X' ).
      WHEN 'TRQ'. screen-active = boolc( rb_tr   = 'X' ).
    ENDCASE.
    MODIFY SCREEN.
  ENDLOOP.

"======================================================================
AT SELECTION-SCREEN.
  CHECK sy-ucomm <> 'DUMMY'.
  PERFORM run_ave.

"======================================================================
FORM supress_button.
  DATA itab TYPE TABLE OF sy-ucomm.
  APPEND 'ONLI' TO itab.
  CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
    EXPORTING
      p_status  = sy-pfkey
    TABLES
      p_exclude = itab.
ENDFORM.

"======================================================================
FORM run_ave.
  " Open popup only when the user pressed Enter (ucomm is initial)
  CHECK sy-ucomm IS INITIAL.

  TRY.
      IF rb_prog = 'X' AND p_prog IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-program
          i_object_name = conv #( p_prog ) ).

      ELSEIF rb_clas = 'X' AND p_clas IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-class
          i_object_name = conv #( p_clas ) ).

      ELSEIF rb_func = 'X' AND p_func IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-function
          i_object_name = conv #( p_func ) ).

      ELSEIF rb_tr = 'X' AND p_tr IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-tr
          i_object_name = conv #( p_tr ) ).

      ELSE.
        MESSAGE 'Please enter an object name.' TYPE 'W'.
        RETURN.
      ENDIF.

      go_popup->show( ).

    CATCH zcx_ave INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.

****************************************************
INTERFACE lif_abapmerge_marker.
* abapmerge 0.16.7 - 2026-04-07T22:50:15.797Z
  CONSTANTS c_merge_timestamp TYPE string VALUE `2026-04-07T22:50:15.797Z`.
  CONSTANTS c_abapmerge_version TYPE string VALUE `0.16.7`.
ENDINTERFACE.
****************************************************
