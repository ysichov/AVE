
REPORT z_ave. " AVE - Abap Versions Explorer
INTERFACE zif_ave_popup_types DEFERRED.
INTERFACE zif_ave_object DEFERRED.
CLASS zcl_ave_vrsd DEFINITION DEFERRED.
CLASS zcl_ave_versno DEFINITION DEFERRED.
CLASS zcl_ave_version DEFINITION DEFERRED.
CLASS zcl_ave_request DEFINITION DEFERRED.
CLASS zcl_ave_progress DEFINITION DEFERRED.
CLASS zcl_ave_popup_html DEFINITION DEFERRED.
CLASS zcl_ave_popup_diff DEFINITION DEFERRED.
CLASS zcl_ave_popup_data DEFINITION DEFERRED.
CLASS zcl_ave_popup DEFINITION DEFERRED.
CLASS zcl_ave_object_tr DEFINITION DEFERRED.
CLASS zcl_ave_object_prog DEFINITION DEFERRED.
CLASS zcl_ave_object_pack DEFINITION DEFERRED.
CLASS zcl_ave_object_intf DEFINITION DEFERRED.
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

  "! Popup display settings (maps to selection screen checkboxes)
  TYPES:
    BEGIN OF ty_settings,
      show_diff   TYPE abap_bool,
      two_pane    TYPE abap_bool,
      no_toc      TYPE abap_bool,
      compact     TYPE abap_bool,
      remove_dup  TYPE abap_bool,
      blame       TYPE abap_bool,
      filter_user TYPE versuser,
      date_from   TYPE versdate,
    END OF ty_settings.

  "! A single versionable part of an object (e.g. one method, one include)
  TYPES:
    BEGIN OF ty_part,
      class        TYPE string,      "class
      unit         type string,      "method/include
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

INTERFACE zif_ave_popup_types.

  "! One diff operation: op = '=' (equal), '-' (deleted), '+' (inserted)
  TYPES:
    BEGIN OF ty_diff_op,
      op(1)   TYPE c,
      text    TYPE string,
    END OF ty_diff_op.
  TYPES ty_t_diff TYPE STANDARD TABLE OF ty_diff_op WITH DEFAULT KEY.

  "! Version row: one VRSD entry enriched with author/task/request display data.
  TYPES:
    BEGIN OF ty_version_row,
      objname        TYPE versobjnam,
      versno         TYPE versno,
      versno_text    TYPE string,
      datum          TYPE versdate,
      zeit           TYPE verstime,
      author         TYPE versuser,
      author_name    TYPE ad_namtext,
      obj_owner      TYPE versuser,
      obj_owner_name TYPE ad_namtext,
      korrnum        TYPE verskorrno,
      task           TYPE trkorr,
      korr_text      TYPE string,
      objtype        TYPE versobjtyp,
      rowcolor(4)    TYPE c,
    END OF ty_version_row.
  TYPES ty_t_version_row TYPE STANDARD TABLE OF ty_version_row WITH DEFAULT KEY.

  "! Blame entry: a source line annotated with author/version info
  TYPES:
    BEGIN OF ty_blame_entry,
      text        TYPE string,
      author      TYPE versuser,
      author_name TYPE ad_namtext,
      datum       TYPE versdate,
      zeit        TYPE verstime,
      versno_text TYPE string,
      korrnum     TYPE verskorrno,
      task        TYPE trkorr,
      task_text   TYPE string,
    END OF ty_blame_entry.
  TYPES ty_blame_map TYPE STANDARD TABLE OF ty_blame_entry WITH DEFAULT KEY.

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

protected section.
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
        intf     TYPE string VALUE 'INTF',
        function TYPE string VALUE 'FUNC',
        tr       TYPE string VALUE 'TR',
        package  TYPE string VALUE 'DEVC',
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
"! Object handler for an ABAP interface (one INTF part)
CLASS zcl_ave_object_intf DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE seoclsname.

  PRIVATE SECTION.
    DATA name TYPE seoclsname.

ENDCLASS.
"! Object handler for a Development Package (DEVCLASS).
"! Reads all objects from TADIR and delegates to specific object handlers.
CLASS zcl_ave_object_pack DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !id TYPE devclass.

  PRIVATE SECTION.

    DATA id TYPE devclass.

    TYPES ty_t_object TYPE TABLE OF REF TO zif_ave_object WITH KEY table_line.

    METHODS get_object_keys
      RETURNING
        VALUE(result) TYPE trwbo_t_e071
      RAISING
        zcx_ave.

    METHODS get_object
      IMPORTING
        object_key    TYPE trwbo_s_e071
      RETURNING
        VALUE(result) TYPE REF TO zif_ave_object.

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
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        i_object_type TYPE string
        i_object_name TYPE string
        is_settings   TYPE zif_ave_object=>ty_settings OPTIONAL.

    METHODS show.

protected section.
private section.

  types:
    "──────────── types ─────────────────────────────────────────────
    " Extended parts row: original fields + existence flag + row color
    BEGIN OF ty_part_row,
        class       type string,
        name        TYPE string,
        type        TYPE versobjtyp,
        type_text   TYPE as4text,
        object_name TYPE versobjnam,
        exists_flag TYPE abap_bool,
        rows        TYPE i,
        rowcolor(4) TYPE c,
      END OF ty_part_row .
  types:
    ty_t_part_row TYPE STANDARD TABLE OF ty_part_row WITH DEFAULT KEY .
  TYPES ty_version_row   TYPE zif_ave_popup_types=>ty_version_row.
  TYPES ty_t_version_row TYPE zif_ave_popup_types=>ty_t_version_row.
  types:
    "! Delegated to ZCL_AVE_POPUP_DIFF (extracted diff engine)
    ty_diff_op TYPE zif_ave_popup_types=>ty_diff_op .
  types:
    ty_t_diff  TYPE zif_ave_popup_types=>ty_t_diff .
  "! Delegated to ZCL_AVE_POPUP_HTML (extracted HTML renderer)
  TYPES ty_blame_entry TYPE zif_ave_popup_types=>ty_blame_entry.
  TYPES ty_blame_map   TYPE zif_ave_popup_types=>ty_blame_map.

    "──────────── controls ──────────────────────────────────────────
  class-data MV_COUNTER type I .
  data MV_OBJECT_TYPE type STRING .
  data MV_OBJECT_NAME type STRING .
  data MO_BOX type ref to CL_GUI_DIALOGBOX_CONTAINER .
  data MO_SPLIT_MAIN type ref to CL_GUI_SPLITTER_CONTAINER .
  data MO_SPLIT_TOP type ref to CL_GUI_SPLITTER_CONTAINER .
  data MO_CONT_PARTS type ref to CL_GUI_CONTAINER .
  data MO_CONT_HTML type ref to CL_GUI_CONTAINER .
  data MO_CONT_VERS type ref to CL_GUI_CONTAINER .
  " 2-pane layout containers
  data MO_SPLIT_WRAP   type ref to CL_GUI_SPLITTER_CONTAINER .
  data MO_SPLIT_2P_TOP  type ref to CL_GUI_SPLITTER_CONTAINER .
  data MO_SPLIT_2P_WRAP type ref to CL_GUI_SPLITTER_CONTAINER .
  data MV_FOCUS_HTML    type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MO_CONT_PARTS_2P type ref to CL_GUI_CONTAINER .
  data MO_CONT_VERS_2P  type ref to CL_GUI_CONTAINER .
  data MO_CONT_HTML_2P  type ref to CL_GUI_CONTAINER .
    " Left panel: ALV Grid with the list of object parts
  data MO_ALV_PARTS type ref to CL_GUI_ALV_GRID .
  data MT_PARTS type TY_T_PART_ROW .
    " Right panel: HTML code viewer + ABAP editor (used for single-version
    " source view; HTML is too slow for 100k+ lines)
  data MO_HTML type ref to CL_GUI_HTML_VIEWER .
  data MO_CODE_VIEWER type ref to CL_GUI_ABAPEDIT .
  " Splits mo_cont_html into two rows — HTML (diff) on top, ABAP editor
  " (single-version source) on bottom. We toggle row heights 0/100 to
  " switch views reliably (z-order tricks with set_visible are unreliable).
  data MO_SPLIT_HTML type ref to CL_GUI_SPLITTER_CONTAINER .
  data MO_CONT_HTML_DIFF type ref to CL_GUI_CONTAINER .
  data MO_CONT_HTML_CODE type ref to CL_GUI_CONTAINER .
    " Bottom panel: SALV table with version list
  data MO_ALV_VERS type ref to CL_GUI_ALV_GRID .
  data MT_VERSIONS type TY_T_VERSION_ROW .
  data MV_CUR_OBJTYPE type VERSOBJTYP .
  data MV_CUR_OBJNAME type VERSOBJNAM .
  data MS_BASE_VER type TY_VERSION_ROW .
  data MS_DIFF_OLD type TY_VERSION_ROW .
  data MS_DIFF_NEW type TY_VERSION_ROW .
  data MV_SHOW_DIFF type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_TWO_PANE type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_NO_TOC type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_COMPACT     type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_REMOVE_DUP  type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_BLAME       type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_TASK_VIEW   type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_DIFF_PREV   type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_REFRESHING  type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_DEBUG       type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_LAST_HTML   type STRING.
  "! When drilled into a class from a TR parts view, holds the class name so
  "! Refresh reloads only that class (not the outer TR).
  data MV_DRILLED_CLASS type SEOCLSNAME ##NO_TEXT.
  data MV_FILTER_USER type VERSUSER ##NO_TEXT.
  data MV_DATE_FROM   type VERSDATE ##NO_TEXT.
  data MV_VIEWED_VERSNO type VERSNO .
    " Backup for Back navigation (one level)
  data MT_PARTS_BACKUP type TY_T_PART_ROW .
  data MO_TOOLBAR type ref to CL_GUI_TOOLBAR .
  data MO_CONT_TOOLBAR type ref to CL_GUI_CONTAINER .

    "──────────── build ─────────────────────────────────────────────
  methods BUILD_LAYOUT .
  methods BUILD_PARTS_LIST .
  methods BUILD_HTML_VIEWER .
  methods REFRESH_VERS .
  methods REFRESH_PARTS .
  methods SWITCH_PANE_LAYOUT .
  methods CREATE_PARTS_ALV .
  methods CREATE_VERSIONS_ALV .
  methods CREATE_HTML_VIEWER .
  methods BUILD_VERSIONS_GRID .
    "──────────── events ────────────────────────────────────────────
  methods HANDLE_PARTS_TOOLBAR
    for event TOOLBAR of CL_GUI_ALV_GRID
    importing
      !E_OBJECT
      !E_INTERACTIVE .
  methods HANDLE_PARTS_COMMAND
    for event USER_COMMAND of CL_GUI_ALV_GRID
    importing
      !E_UCOMM .
  methods HANDLE_PARTS_DBLCLICK
    for event DOUBLE_CLICK of CL_GUI_ALV_GRID
    importing
      !ES_ROW_NO
      !E_COLUMN .
  methods ON_TOOLBAR_CLICK
    for event FUNCTION_SELECTED of CL_GUI_TOOLBAR
    importing
      !FCODE .
  methods HANDLE_VERS_TOOLBAR
    for event TOOLBAR of CL_GUI_ALV_GRID
    importing
      !E_OBJECT
      !E_INTERACTIVE .
  methods HANDLE_VERS_COMMAND
    for event USER_COMMAND of CL_GUI_ALV_GRID
    importing
      !E_UCOMM .
  methods HANDLE_VERS_DBLCLICK
    for event DOUBLE_CLICK of CL_GUI_ALV_GRID
    importing
      !ES_ROW_NO
      !E_COLUMN .
  methods ON_BOX_CLOSE
    for event CLOSE of CL_GUI_DIALOGBOX_CONTAINER
    importing
      !SENDER .
    "──────────── logic ─────────────────────────────────────────────
  methods GET_CLASS_PARTS
    importing
      !I_NAME type VERSOBJNAM
    returning
      value(RESULT) type TY_T_PART_ROW
    raising
      ZCX_AVE .
  methods LOAD_VERSIONS
    importing
      !I_OBJTYPE type VERSOBJTYP
      !I_OBJNAME type VERSOBJNAM .
  methods LOAD_VERSIONS_TASK_VIEW
    importing
      !I_OBJTYPE type VERSOBJTYP
      !I_OBJNAME type VERSOBJNAM .
  methods UPDATE_VER_COLORS
    importing
      !IV_VIEWED_VERSNO type VERSNO optional .
  methods SHOW_SOURCE
    importing
      !I_OBJTYPE type VERSOBJTYP
      !I_OBJNAME type VERSOBJNAM
      !I_VERSNO type VERSNO .
  methods SHOW_VERSIONS_DIFF
    importing
      !IS_OLD type TY_VERSION_ROW
      !IS_NEW type TY_VERSION_ROW .
  "! Auto-open guard: if is_new source exceeds 1000 lines, show source only;
  "! user can manually trigger a diff from the version list.
  methods AUTO_SHOW_DIFF_OR_SOURCE
    importing
      !IS_OLD type TY_VERSION_ROW
      !IS_NEW type TY_VERSION_ROW .
  methods SET_HTML
    importing
      !IV_HTML type STRING .
  "! Upload source to the ABAP editor and toggle visibility so it takes the
  "! place of the HTML viewer. Used for single-version (Show Vers) view.
  methods SHOW_CODE_SOURCE
    importing
      !IT_SOURCE type ABAPTXT255_TAB .
ENDCLASS.
CLASS zcl_ave_popup_data DEFINITION
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Full name of a user (USR01/AD display name).
    CLASS-METHODS get_user_name
      IMPORTING iv_user       TYPE versuser
      RETURNING VALUE(result) TYPE ad_namtext.

    "! Author of the most recent version of an object (from VRSD).
    CLASS-METHODS get_latest_author
      IMPORTING i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
      RETURNING VALUE(result) TYPE versuser.

    "! True if the object exists in the system (TADIR / SEOCOMPO check).
    CLASS-METHODS check_part_exists
      IMPORTING i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
                i_class_name  TYPE seoclsname OPTIONAL
      RETURNING VALUE(result) TYPE abap_bool.

    "! Object-type description text (lazy-loaded from TRINT_OBJECT_TABLE, cached).
    CLASS-METHODS get_type_text
      IMPORTING i_type        TYPE versobjtyp
      RETURNING VALUE(result) TYPE as4text.

    "! True if any part of the class was last changed by i_user.
    CLASS-METHODS check_class_has_author
      IMPORTING i_class_name  TYPE string
                i_user        TYPE versuser
      RETURNING VALUE(result) TYPE abap_bool.

    "! True if the latest version of the object was authored by i_user AND
    "! its source differs from the nearest prior version whose transport
    "! request has TRFUNCTION='K' (Workbench request). Raw VRSD history is
    "! used (no deduplication). If no prior K-TR version exists the change
    "! is treated as substantive (first author case).
    CLASS-METHODS is_substantive_user_change
      IMPORTING i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
                i_user        TYPE versuser
      RETURNING VALUE(result) TYPE abap_bool.

    "! Drop consecutive versions whose source is identical (ignoring leading
    "! whitespace). Input must be sorted newest-first.
    CLASS-METHODS remove_duplicate_versions
      CHANGING ct_versions TYPE zif_ave_popup_types=>ty_t_version_row.

    "! Line count of the currently active source for a part (0 when unavailable,
    "! e.g. for CLSD/RELE which have no source).
    CLASS-METHODS get_active_line_count
      IMPORTING i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
      RETURNING VALUE(result) TYPE i.

    "! Read source of a single version. Builds a synthetic VRSD row if none
    "! is stored yet (e.g. version pending in an unreleased task).
    CLASS-METHODS get_ver_source
      IMPORTING i_objtype     TYPE versobjtyp
                i_objname     TYPE versobjnam
                i_versno      TYPE versno
                i_korrnum     TYPE trkorr  OPTIONAL
                i_author      TYPE versuser OPTIONAL
                i_datum       TYPE versdate OPTIONAL
                i_zeit        TYPE verstime OPTIONAL
      RETURNING VALUE(result) TYPE abaptxt255_tab.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_type_text,
        type TYPE versobjtyp,
        text TYPE as4text,
      END OF ty_type_text.
    CLASS-DATA mt_type_cache TYPE HASHED TABLE OF ty_type_text WITH UNIQUE KEY type.
    CLASS-DATA mv_cache_loaded TYPE abap_bool VALUE abap_false.
    CLASS-METHODS load_type_cache.
ENDCLASS.
CLASS zcl_ave_popup_diff DEFINITION
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Type aliases from ZIF_AVE_POPUP_TYPES (defined there for standalone compatibility)
    TYPES ty_diff_op TYPE zif_ave_popup_types=>ty_diff_op.
    TYPES ty_t_diff  TYPE zif_ave_popup_types=>ty_t_diff.

    "! Line-level LCS diff between two source tables.
    CLASS-METHODS compute_diff
      IMPORTING it_old        TYPE abaptxt255_tab
                it_new        TYPE abaptxt255_tab
                i_title       TYPE csequence DEFAULT 'Computing diff'
      RETURNING VALUE(result) TYPE ty_t_diff.

    "! Inline char-level diff for a single line pair.
    "!   iv_side = 'B' → both sides inline (default)
    "!   iv_side = 'N' → only insertion highlighted (new side)
    "!   iv_side = 'O' → only deletion highlighted (old side)
    CLASS-METHODS char_diff_html
      IMPORTING iv_old        TYPE string
                iv_new        TYPE string
                iv_side       TYPE c DEFAULT 'N'
      RETURNING VALUE(result) TYPE string.

    "! True if iv_a and iv_b share a common non-whitespace prefix of >= 3 chars.
    "! Used by diff_to_html to decide whether two changed lines are similar enough to pair.
    CLASS-METHODS has_common_chars
      IMPORTING iv_a          TYPE string
                iv_b          TYPE string
      RETURNING VALUE(result) TYPE abap_bool.

    "! Build a blame map by replaying diffs between consecutive versions in
    "! [i_from, i_to] for (i_objtype, i_objname). For every '+' line the current
    "! version's author is recorded; '-' lines go to et_blame_deleted.
    CLASS-METHODS build_blame_map
      IMPORTING it_versions      TYPE zif_ave_popup_types=>ty_t_version_row
                i_objtype        TYPE versobjtyp
                i_objname        TYPE versobjnam
                i_from           TYPE versno
                i_to             TYPE versno
      EXPORTING et_blame_deleted TYPE zif_ave_popup_types=>ty_blame_map
      RETURNING VALUE(result)    TYPE zif_ave_popup_types=>ty_blame_map.
ENDCLASS.
CLASS zcl_ave_popup_html DEFINITION
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Type aliases from ZIF_AVE_POPUP_TYPES (defined there for standalone compatibility)
    TYPES ty_blame_entry TYPE zif_ave_popup_types=>ty_blame_entry.
    TYPES ty_blame_map   TYPE zif_ave_popup_types=>ty_blame_map.

    "! Format a source table as a stand-alone HTML page with line numbers.
    CLASS-METHODS source_to_html
      IMPORTING it_source     TYPE abaptxt255_tab
                i_title       TYPE string
                i_meta        TYPE string OPTIONAL
      RETURNING VALUE(rv_html) TYPE string.

    "! Render a diff (from ZCL_AVE_POPUP_DIFF) as an HTML page.
    CLASS-METHODS diff_to_html
      IMPORTING it_diff           TYPE zif_ave_popup_types=>ty_t_diff
                i_title           TYPE string
                i_meta            TYPE string OPTIONAL
                i_two_pane        TYPE abap_bool OPTIONAL
                i_compact         TYPE abap_bool OPTIONAL
                "! Skip char-level inline highlighting (huge-file mode).
                i_plain           TYPE abap_bool OPTIONAL
                it_blame          TYPE ty_blame_map OPTIONAL
                it_blame_deleted  TYPE ty_blame_map OPTIONAL
      RETURNING VALUE(result)     TYPE string.

    "! Debug rendering of diff ops and pairing decisions.
    CLASS-METHODS debug_diff_html
      IMPORTING it_diff       TYPE zif_ave_popup_types=>ty_t_diff
                i_title       TYPE string
                i_meta        TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE string.
ENDCLASS.
"! Cooperative long-running loop interrupter.
"! After `threshold_secs` of continuous work, asks the user whether to
"! continue or stop. Caller decides how to react to a Stop (e.g. break
"! out of the loop with `was_stopped( )`).
CLASS zcl_ave_progress DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING i_title          TYPE csequence DEFAULT 'Long-running operation'
                i_threshold_secs TYPE i         DEFAULT 10.

    "! Call once per iteration. Returns abap_true → caller should stop.
    "! i_remaining is used both for the SAPGUI progress bar percentage
    "! (together with i_total) and for the confirmation text.
    METHODS check
      IMPORTING i_remaining   TYPE i OPTIONAL
                i_total       TYPE i OPTIONAL
                i_text        TYPE csequence OPTIONAL
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS was_stopped
      RETURNING VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mv_title     TYPE string.
    DATA mv_threshold TYPE i.
    DATA mv_ts_start    TYPE timestampl.
    DATA mv_ts_last_bar TYPE timestampl.
    DATA mv_stopped     TYPE abap_bool.
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
        " Modified (not-yet-activated workbench state) is intentionally skipped
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

    " Supplement from SVRS_GET_VERSION_DIRECTORY_46 — accepts full OBJNAME (LIKE VRSD-OBJNAME)
    " and returns VERSION_LIST LIKE VRSD. Covers versions not yet written to VRSD
    " (e.g. activated into an unreleased task). Works for long names (METH ≤110 chars).
    DATA lt_dir46    TYPE vrsd_tab.
    DATA lt_lversno TYPE TABLE OF vrsn.
    CALL FUNCTION 'SVRS_GET_VERSION_DIRECTORY_46'
      EXPORTING
        objtype         = me->type
        objname         = me->name
      TABLES
        lversno_list    = lt_lversno
        version_list    = lt_dir46
      EXCEPTIONS
        no_entry        = 1
        OTHERS          = 2.
    IF sy-subrc = 0.
      LOOP AT lt_dir46 REFERENCE INTO DATA(ls_dir46).
        " Skip active (00000) and modified (99997) — handled by load_active_or_modified
        IF ls_dir46->versno = '00000' OR ls_dir46->versno = '99997'.
          CONTINUE.
        ENDIF.
        " Apply date_from filter
        IF me->date_from <> '00000000' AND ls_dir46->datum < me->date_from.
          CONTINUE.
        ENDIF.
        " Apply no_toc filter (skip TOC entries)
        IF me->no_toc = abap_true.
          DATA ls_e070_dir TYPE e070.
          SELECT SINGLE * FROM e070 WHERE trkorr = @ls_dir46->korrnum
            INTO @ls_e070_dir.
          IF ls_e070_dir-trfunction = 'T'.
            CONTINUE.
          ENDIF.
        ENDIF.
        " Skip if already loaded from VRSD
        DATA(lv_ext) = zcl_ave_versno=>to_external( ls_dir46->versno ).
        READ TABLE me->vrsd_list WITH KEY versno = lv_ext TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          ls_dir46->versno = lv_ext.
          INSERT ls_dir46->* INTO TABLE me->vrsd_list.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
  METHOD load_active_or_modified.
    DATA ls_vrsd TYPE vrsd.

    IF versno = zcl_ave_version=>c_version-active.
      " Use SVRS_GET_VERSION_DIRECTORY_46 — accepts full OBJNAME (LIKE VRSD-OBJNAME),
      " works for both short (PROG/REPS) and long (METH ≤110 chars) names.
      " versno='00000' in the result = active version with exact korrnum/datum/zeit/author.
      " Do NOT use read_vrsd/SVRS_GET_VERSION_REPOSITORY mode='A' — it may return
      " metadata of the last activated virtual version (e.g. version 19 data).
      DATA lt_dir_a  TYPE vrsd_tab.
      DATA lt_lv_a   TYPE TABLE OF vrsn.
      CALL FUNCTION 'SVRS_GET_VERSION_DIRECTORY_46'
        EXPORTING  objtype      = me->type
                   objname      = me->name
        TABLES     lversno_list = lt_lv_a
                   version_list = lt_dir_a
        EXCEPTIONS no_entry     = 1  OTHERS = 2.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      " Active version stored internally as versno='00000'
      READ TABLE lt_dir_a INTO DATA(ls_a0)
        WITH KEY versno = '00000'.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      ls_vrsd-versno  = versno.   " our external key: 99998
      ls_vrsd-objtype = me->type.
      ls_vrsd-objname = me->name.
      ls_vrsd-korrnum = ls_a0-korrnum.
      ls_vrsd-datum   = ls_a0-datum.
      ls_vrsd-zeit    = ls_a0-zeit.
      ls_vrsd-author  = ls_a0-author.
    ELSE.
      " Modified or other special version — use repository + lock detection
      ls_vrsd = read_vrsd( versno ).
      IF ls_vrsd IS INITIAL OR ls_vrsd-author IS INITIAL.
        RETURN.
      ENDIF.
      ls_vrsd-versno  = versno.
      ls_vrsd-objtype = me->type.
      ls_vrsd-objname = me->name.
      ls_vrsd-korrnum = get_request_active_modif( ).
    ENDIF.

    READ TABLE me->vrsd_list ASSIGNING FIELD-SYMBOL(<existing>)
      WITH KEY versno = versno.
    IF sy-subrc = 0.
      <existing>-korrnum = ls_vrsd-korrnum.
      <existing>-datum   = ls_vrsd-datum.
      <existing>-zeit    = ls_vrsd-zeit.
      <existing>-author  = ls_vrsd-author.
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

    " Active version (99998): date/time/author already set correctly from
    " SVRS_GET_VERSION_DIRECTORY in zcl_ave_vrsd — don't overwrite with task data.
    IF me->version_number = c_version-active.
      RETURN.
    ENDIF.

    " korrnum is a request — find the responsible task within it
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

CLASS zcl_ave_progress IMPLEMENTATION.

  METHOD constructor.
    mv_title     = i_title.
    mv_threshold = i_threshold_secs.
    GET TIME STAMP FIELD mv_ts_start.
    mv_ts_last_bar = mv_ts_start.
  ENDMETHOD.

  METHOD check.
    IF mv_stopped = abap_true.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA lv_now  TYPE timestampl.
    DATA lv_secs TYPE tzntstmpl.
    GET TIME STAMP FIELD lv_now.

    " SAPGUI progress bar — throttle to once per second so cheap iterations
    " don't flood the GUI with roundtrips.
    cl_abap_tstmp=>subtract(
      EXPORTING tstmp1 = lv_now tstmp2 = mv_ts_last_bar
      RECEIVING r_secs = lv_secs ).
    IF lv_secs >= 1 AND i_total > 0 AND i_remaining >= 0.
      DATA(lv_done) = i_total - i_remaining.
      DATA(lv_pct)  = CONV i( lv_done * 100 / i_total ).

      " ETA: elapsed * remaining / done
      DATA lv_elapsed TYPE tzntstmpl.
      cl_abap_tstmp=>subtract(
        EXPORTING tstmp1 = lv_now tstmp2 = mv_ts_start
        RECEIVING r_secs = lv_elapsed ).
      DATA(lv_eta) = ``.
      IF lv_done > 0 AND lv_elapsed > 0.
        DATA(lv_eta_secs) = CONV i( lv_elapsed * i_remaining / lv_done ).
        DATA(lv_min) = lv_eta_secs DIV 60.
        DATA(lv_sec) = lv_eta_secs MOD 60.
        lv_eta = COND string(
          WHEN lv_min > 0 THEN | – est. { lv_min }m { lv_sec }s left|
          ELSE                 | – est. { lv_sec }s left| ).
      ENDIF.

      DATA(lv_msg)  = COND string(
        WHEN i_text IS NOT INITIAL THEN |{ i_text } ({ lv_done }/{ i_total }){ lv_eta }|
        ELSE                            |{ mv_title } ({ lv_done }/{ i_total }){ lv_eta }| ).
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = lv_pct text = CONV char70( lv_msg ).
      mv_ts_last_bar = lv_now.
    ENDIF.

    " Threshold check: ask the user whether to keep going
    cl_abap_tstmp=>subtract(
      EXPORTING tstmp1 = lv_now tstmp2 = mv_ts_start
      RECEIVING r_secs = lv_secs ).
    IF lv_secs <= mv_threshold.
      RETURN.
    ENDIF.

    DATA(lv_text) = COND string(
      WHEN i_remaining > 0 THEN |{ i_remaining } items remaining. Continue?|
      ELSE                      |Operation is taking a while. Continue?| ).
    DATA lv_answer TYPE c LENGTH 1.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar       = CONV char70( mv_title )
        text_question  = lv_text
        text_button_1  = 'Continue'
        text_button_2  = 'Stop'
        default_button = '2'
        start_column   = 60
        start_row      = 3
      IMPORTING
        answer         = lv_answer.
    IF lv_answer <> '1'.
      mv_stopped = abap_true.
      result     = abap_true.
      RETURN.
    ENDIF.
    GET TIME STAMP FIELD mv_ts_start.
  ENDMETHOD.

  METHOD was_stopped.
    result = mv_stopped.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_popup_html IMPLEMENTATION.

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
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#ffffff;color:#1e1e1e;font:12px/1.5 Consolas,monospace\}| &&
      |.hdr\{background:#f3f3f3;padding:5px 12px;border-bottom:1px solid #ddd;| &&
             |color:#444;font-size:11px;display:flex;gap:16px;flex-wrap:wrap\}| &&
      |.ttl\{color:#0066aa;font-weight:bold\}| &&
      |.meta\{color:#888\}| &&
      |table\{border-collapse:collapse;width:100%\}| &&
      |tr:hover td\{background:#f0f4fa\}| &&
      |.ln\{color:#aaa;text-align:right;padding:1px 10px 1px 5px;| &&
           |user-select:none;min-width:42px;border-right:1px solid #e0e0e0;| &&
           |white-space:nowrap;background:#fafafa\}| &&
      |.cd\{padding:1px 8px;white-space:pre\}| &&
      |</style></head><body>| &&
      |<div class="hdr">| &&
      |<span class="ttl">| && i_title && |</span>| &&
      |<span class="meta">| && i_meta  && |</span>| &&
      |</div>| &&
      |<table><tbody>| && lv_rows &&
      |</tbody></table></body></html>|.
  ENDMETHOD.
  METHOD diff_to_html.
    DATA lv_rows  TYPE string.
    DATA lv_lno   TYPE i.

    " Pre-compute which '=' lines to show in compact mode (within 3 of any change)
    CONSTANTS lc_ctx TYPE i VALUE 3.
    DATA lt_show TYPE TABLE OF abap_bool WITH DEFAULT KEY.
    DATA(lv_ntot) = lines( it_diff ).
    DO lv_ntot TIMES. APPEND abap_false TO lt_show. ENDDO.
    IF i_compact = abap_true.
      DATA lv_ci TYPE i.
      lv_ci = 1.
      LOOP AT it_diff INTO DATA(ls_cm).
        IF ls_cm-op = '-' OR ls_cm-op = '+'.
          DATA lv_from TYPE i.
          DATA lv_to   TYPE i.
          lv_from = lv_ci - lc_ctx.
          lv_to   = lv_ci + lc_ctx.
          IF lv_from < 1. lv_from = 1. ENDIF.
          IF lv_to > lv_ntot. lv_to = lv_ntot. ENDIF.
          DATA lv_fi TYPE i.
          lv_fi = lv_from.
          WHILE lv_fi <= lv_to.
            lt_show[ lv_fi ] = abap_true.
            lv_fi += 1.
          ENDWHILE.
        ENDIF.
        lv_ci += 1.
      ENDLOOP.
    ENDIF.

    DATA(lo_progress) = NEW zcl_ave_progress(
      i_title = 'Rendering diff' i_threshold_secs = 30 ).

    IF i_two_pane = abap_true.
      " ── Two-pane rendering ──────────────────────────────────────
      DATA lv_lno_l TYPE i.
      DATA lv_lno_r TYPE i.
      DATA lv_max_w TYPE i.
      DATA lv_pos2  TYPE i VALUE 1.
      DATA lv_tot2  TYPE i.
      lv_tot2 = lines( it_diff ).

      " Calculate max line length of left (base/new) content for column width
      LOOP AT it_diff INTO DATA(ls_w) WHERE op = '=' OR op = '+'.
        DATA(lv_wl) = strlen( condense( val = CONV string( ls_w-text ) ) ).
        IF lv_wl > lv_max_w. lv_max_w = lv_wl. ENDIF.
      ENDLOOP.
      lv_max_w = lv_max_w + 4.   " small padding

      DATA lv_gap2 TYPE abap_bool.
      WHILE lv_pos2 <= lv_tot2.
        IF lo_progress->check(
             i_remaining = lv_tot2 - lv_pos2 + 1
             i_total     = lv_tot2 ) = abap_true.
          EXIT.
        ENDIF.
        READ TABLE it_diff INTO DATA(ls_c2) INDEX lv_pos2.

        IF ls_c2-op = '='.
          lv_lno_l += 1. lv_lno_r += 1.
          IF i_compact = abap_true AND lt_show[ lv_pos2 ] = abap_false.
            IF lv_gap2 = abap_false.
              lv_rows = lv_rows &&
                |<tr style="background:#f0f0f0;color:#888">| &&
                |<td class="ln">...</td><td class="cd">...</td>| &&
                |<td class="sep"></td>| &&
                |<td class="ln">...</td><td class="cd">...</td></tr>|.
              lv_gap2 = abap_true.
            ENDIF.
            lv_pos2 += 1.
            CONTINUE.
          ENDIF.
          CLEAR lv_gap2.
          DATA(lv_eq2) = ls_c2-text.
          REPLACE ALL OCCURRENCES OF `&` IN lv_eq2 WITH `&amp;`.
          REPLACE ALL OCCURRENCES OF `<` IN lv_eq2 WITH `&lt;`.
          REPLACE ALL OCCURRENCES OF `>` IN lv_eq2 WITH `&gt;`.
          lv_rows = lv_rows &&
            |<tr><td class="ln">{ lv_lno_l }</td>| &&
            |<td class="cd">{ lv_eq2 }</td>| &&
            |<td class="sep"></td>| &&
            |<td class="ln">{ lv_lno_r }</td>| &&
            |<td class="cd">{ lv_eq2 }</td></tr>|.
          lv_pos2 += 1.

        ELSEIF ls_c2-op = '-' OR ls_c2-op = '+'.
          DATA lt_d2 TYPE string_table.
          DATA lt_i2 TYPE string_table.
          DATA lv_sc TYPE i.
          lv_sc = lv_pos2.
          " Extended block: collect '-'/'+' AND short bridging empty '=' lines
          " (max 1 in a row) when more changes follow. Bridged '=' lines are
          " not added to lt_d2/lt_i2 (they're equal on both sides) but still
          " advance lv_sc so pairing across the gap works.
          WHILE lv_sc <= lv_tot2.
            READ TABLE it_diff INTO DATA(ls_s2) INDEX lv_sc.
            IF ls_s2-op = '-'. APPEND ls_s2-text TO lt_d2. lv_sc += 1.
            ELSEIF ls_s2-op = '+'. APPEND ls_s2-text TO lt_i2. lv_sc += 1.
            ELSEIF ls_s2-op = '=' AND condense( val = ls_s2-text ) = ``.
              DATA lv_peek2  TYPE i.
              DATA lv_extra2 TYPE i.
              DATA lv_more2  TYPE abap_bool.
              lv_peek2 = lv_sc + 1.
              lv_extra2 = 0.
              lv_more2 = abap_false.
              WHILE lv_peek2 <= lv_tot2.
                READ TABLE it_diff INTO DATA(ls_p2) INDEX lv_peek2.
                IF ls_p2-op = '-' OR ls_p2-op = '+'.
                  lv_more2 = abap_true.
                  EXIT.
                ELSEIF ls_p2-op = '=' AND condense( val = ls_p2-text ) = `` AND lv_extra2 < 1.
                  lv_extra2 += 1.
                  lv_peek2 += 1.
                  CONTINUE.
                ELSE.
                  EXIT.
                ENDIF.
              ENDWHILE.
              IF lv_more2 = abap_true.
                lv_sc += 1.
              ELSE.
                EXIT.
              ENDIF.
            ELSE. EXIT.
            ENDIF.
          ENDWHILE.
          DATA(lv_nd) = lines( lt_d2 ).
          DATA(lv_ni) = lines( lt_i2 ).

          " Blame separator for two-pane (added lines)
          IF it_blame IS NOT INITIAL AND lt_i2 IS NOT INITIAL.
            READ TABLE it_blame INTO DATA(ls_bl2) WITH KEY text = lt_i2[ 1 ].
            IF sy-subrc = 0.
              DATA(lv_bdate2) = |{ ls_bl2-datum+6(2) }.{ ls_bl2-datum+4(2) }.{ ls_bl2-datum(4) }|.
              DATA(lv_btime2) = |{ ls_bl2-zeit(2) }:{ ls_bl2-zeit+2(2) }|.
              DATA(lv_btask2) = COND string(
                WHEN ls_bl2-korrnum IS NOT INITIAL AND ls_bl2-task IS NOT INITIAL THEN | { ls_bl2-korrnum }/{ ls_bl2-task }|
                WHEN ls_bl2-korrnum IS NOT INITIAL THEN | { ls_bl2-korrnum }|
                WHEN ls_bl2-task IS NOT INITIAL THEN | { ls_bl2-task }|
                ELSE `` ).
              DATA(lv_btasktxt2) = COND string( WHEN ls_bl2-task_text IS NOT INITIAL THEN | { ls_bl2-task_text }| ELSE `` ).
              DATA(lv_bauth2) = ls_bl2-author &&
                COND string( WHEN ls_bl2-author_name IS NOT INITIAL THEN | ({ ls_bl2-author_name })| ELSE `` ).
              DATA(lv_bline2) = |── { lv_bauth2 } changed  { lv_bdate2 } { lv_btime2 }  v.{ ls_bl2-versno_text }{ lv_btask2 }{ lv_btasktxt2 } ──|.
              IF strlen( ls_bl2-task_text ) > 10.
                " Split: first row without TR info, second row with TR info only
                lv_rows = lv_rows &&
                  |<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">| &&
                  |<td class="ln">▶</td><td class="cd" colspan="3">── { lv_bauth2 } changed  { lv_bdate2 } { lv_btime2 }  v.{ ls_bl2-versno_text } ──</td>| &&
                  |<td class="ln"></td><td class="cd"></td></tr>| &&
                  |<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">| &&
                  |<td class="ln"></td><td class="cd" colspan="3">──{ lv_btask2 }{ lv_btasktxt2 } ──</td>| &&
                  |<td class="ln"></td><td class="cd"></td></tr>|.
              ELSE.
                lv_rows = lv_rows &&
                  |<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">| &&
                  |<td class="ln">▶</td><td class="cd" colspan="3">{ lv_bline2 }</td>| &&
                  |<td class="ln"></td><td class="cd"></td></tr>|.
              ENDIF.
            ENDIF.
          ENDIF.
          " Blame separator for two-pane (deleted lines)
          IF it_blame_deleted IS NOT INITIAL AND lt_d2 IS NOT INITIAL AND lt_i2 IS INITIAL.
            READ TABLE it_blame_deleted INTO DATA(ls_bld2) WITH KEY text = lt_d2[ 1 ].
            IF sy-subrc = 0.
              DATA(lv_bddate2) = |{ ls_bld2-datum+6(2) }.{ ls_bld2-datum+4(2) }.{ ls_bld2-datum(4) }|.
              DATA(lv_bdtime2) = |{ ls_bld2-zeit(2) }:{ ls_bld2-zeit+2(2) }|.
              DATA(lv_bdtask2) = COND string(
                WHEN ls_bld2-korrnum IS NOT INITIAL AND ls_bld2-task IS NOT INITIAL THEN | { ls_bld2-korrnum }/{ ls_bld2-task }|
                WHEN ls_bld2-korrnum IS NOT INITIAL THEN | { ls_bld2-korrnum }|
                WHEN ls_bld2-task IS NOT INITIAL THEN | { ls_bld2-task }|
                ELSE `` ).
              DATA(lv_bdtasktxt2) = COND string( WHEN ls_bld2-task_text IS NOT INITIAL THEN | { ls_bld2-task_text }| ELSE `` ).
              DATA(lv_bdauth2) = ls_bld2-author &&
                COND string( WHEN ls_bld2-author_name IS NOT INITIAL THEN | ({ ls_bld2-author_name })| ELSE `` ).
              DATA(lv_bdline2) = |── { lv_bdauth2 } deleted  { lv_bddate2 } { lv_bdtime2 }  v.{ ls_bld2-versno_text }{ lv_bdtask2 }{ lv_bdtasktxt2 } ──|.
              IF strlen( lv_bdline2 ) > lv_max_w AND ( lv_bdtask2 IS NOT INITIAL OR lv_bdtasktxt2 IS NOT INITIAL ).
                lv_rows = lv_rows &&
                  |<tr style="background:#fdf0f0;color:#888;font-size:10px;font-style:italic">| &&
                  |<td class="ln">◀</td><td class="cd" colspan="3">── { lv_bdauth2 } deleted  { lv_bddate2 } { lv_bdtime2 }  v.{ ls_bld2-versno_text } ──</td>| &&
                  |<td class="ln"></td><td class="cd"></td></tr>| &&
                  |<tr style="background:#fdf0f0;color:#888;font-size:10px;font-style:italic">| &&
                  |<td class="ln"></td><td class="cd" colspan="3">──{ lv_bdtask2 }{ lv_bdtasktxt2 } ──</td>| &&
                  |<td class="ln"></td><td class="cd"></td></tr>|.
              ELSE.
                lv_rows = lv_rows &&
                  |<tr style="background:#fdf0f0;color:#888;font-size:10px;font-style:italic">| &&
                  |<td class="ln">◀</td><td class="cd" colspan="3">{ lv_bdline2 }</td>| &&
                  |<td class="ln"></td><td class="cd"></td></tr>|.
              ENDIF.
            ENDIF.
          ENDIF.

          " Split whitespace-only lines out — they should not pair against real content
          DATA lt_i2_p  TYPE string_table.
          DATA lt_d2_p  TYPE string_table.
          DATA lt_i2_ws TYPE string_table.
          DATA lt_d2_ws TYPE string_table.
          DATA lv_cond_tmp TYPE string.
          CLEAR: lt_i2_p, lt_d2_p, lt_i2_ws, lt_d2_ws.
          LOOP AT lt_i2 INTO DATA(ls_itmp).
            lv_cond_tmp = ls_itmp.
            CONDENSE lv_cond_tmp.
            IF lv_cond_tmp IS INITIAL.
              APPEND ls_itmp TO lt_i2_ws.
            ELSE.
              APPEND ls_itmp TO lt_i2_p.
            ENDIF.
          ENDLOOP.
          LOOP AT lt_d2 INTO DATA(ls_dtmp).
            lv_cond_tmp = ls_dtmp.
            CONDENSE lv_cond_tmp.
            IF lv_cond_tmp IS INITIAL.
              APPEND ls_dtmp TO lt_d2_ws.
            ELSE.
              APPEND ls_dtmp TO lt_d2_p.
            ENDIF.
          ENDLOOP.
          " From content-pairable positions, keep only pairs that share characters.
          " Non-sharing pairs are moved to unpaired (own rows).
          DATA lt_i2_pair TYPE string_table.
          DATA lt_d2_pair TYPE string_table.
          DATA lt_i2_solo TYPE string_table.
          DATA lt_d2_solo TYPE string_table.
          CLEAR: lt_i2_pair, lt_d2_pair, lt_i2_solo, lt_d2_solo.
          DATA(lv_np_min) = COND i( WHEN lines( lt_i2_p ) < lines( lt_d2_p )
                                    THEN lines( lt_i2_p ) ELSE lines( lt_d2_p ) ).
          DATA lv_kk TYPE i.
          lv_kk = 1.
          WHILE lv_kk <= lv_np_min.
            IF zcl_ave_popup_diff=>has_common_chars( iv_a = lt_i2_p[ lv_kk ] iv_b = lt_d2_p[ lv_kk ] ) = abap_true.
              APPEND lt_i2_p[ lv_kk ] TO lt_i2_pair.
              APPEND lt_d2_p[ lv_kk ] TO lt_d2_pair.
            ELSE.
              APPEND lt_i2_p[ lv_kk ] TO lt_i2_solo.
              APPEND lt_d2_p[ lv_kk ] TO lt_d2_solo.
            ENDIF.
            lv_kk += 1.
          ENDWHILE.
          " Leftover content beyond min(|lt_i2_p|,|lt_d2_p|)
          lv_kk = lv_np_min + 1.
          WHILE lv_kk <= lines( lt_i2_p ).
            APPEND lt_i2_p[ lv_kk ] TO lt_i2_solo.
            lv_kk += 1.
          ENDWHILE.
          lv_kk = lv_np_min + 1.
          WHILE lv_kk <= lines( lt_d2_p ).
            APPEND lt_d2_p[ lv_kk ] TO lt_d2_solo.
            lv_kk += 1.
          ENDWHILE.

          " Rebuild: paired content first, then solo content, then whitespace-only (all unpaired after lv_np)
          CLEAR lt_i2.
          APPEND LINES OF lt_i2_pair TO lt_i2.
          APPEND LINES OF lt_i2_solo TO lt_i2.
          APPEND LINES OF lt_i2_ws   TO lt_i2.
          CLEAR lt_d2.
          APPEND LINES OF lt_d2_pair TO lt_d2.
          APPEND LINES OF lt_d2_solo TO lt_d2.
          APPEND LINES OF lt_d2_ws   TO lt_d2.
          DATA(lv_np) = lines( lt_i2_pair ).   " both _pair lists have same length
          lv_ni = lines( lt_i2 ).
          lv_nd = lines( lt_d2 ).

          DATA lv_pr TYPE i.
          DATA lv_dl2 TYPE string.
          DATA lv_il2 TYPE string.
          DATA lv_ln_l TYPE string.
          DATA lv_ln_r TYPE string.
          DATA lv_bg_l TYPE string.
          DATA lv_bg_r TYPE string.

          " 1) Paired content rows — char-level diff both sides
          lv_pr = 1.
          WHILE lv_pr <= lv_np.
            lv_lno_l += 1. lv_lno_r += 1.
            IF i_plain = abap_true.
              lv_dl2 = escape( val = lt_i2[ lv_pr ] format = cl_abap_format=>e_html_text ).
              lv_il2 = escape( val = lt_d2[ lv_pr ] format = cl_abap_format=>e_html_text ).
            ELSE.
              lv_dl2 = zcl_ave_popup_diff=>char_diff_html( iv_old = lt_d2[ lv_pr ] iv_new = lt_i2[ lv_pr ] iv_side = 'N' ).
              lv_il2 = zcl_ave_popup_diff=>char_diff_html( iv_old = lt_d2[ lv_pr ] iv_new = lt_i2[ lv_pr ] iv_side = 'O' ).
            ENDIF.
            lv_rows = lv_rows &&
              |<tr>| &&
              |<td class="ln" style="background:#eaffea">{ lv_lno_l }</td>| &&
              |<td class="cd" style="background:#eaffea">{ lv_dl2 }</td>| &&
              |<td class="sep"></td>| &&
              |<td class="ln" style="background:#ffecec">{ lv_lno_r }</td>| &&
              |<td class="cd" style="background:#ffecec">{ lv_il2 }</td></tr>|.
            CLEAR: lv_dl2, lv_il2.
            lv_pr += 1.
          ENDWHILE.

          " 2) Remaining inserts — left filled, right empty (own rows)
          lv_pr = lv_np + 1.
          WHILE lv_pr <= lv_ni.
            lv_lno_l += 1.
            lv_dl2 = lt_i2[ lv_pr ].
            REPLACE ALL OCCURRENCES OF `&` IN lv_dl2 WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<` IN lv_dl2 WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>` IN lv_dl2 WITH `&gt;`.
            lv_rows = lv_rows &&
              |<tr>| &&
              |<td class="ln" style="background:#eaffea">{ lv_lno_l }</td>| &&
              |<td class="cd" style="background:#eaffea">{ lv_dl2 }</td>| &&
              |<td class="sep"></td>| &&
              |<td class="ln"></td><td class="cd"></td></tr>|.
            CLEAR lv_dl2.
            lv_pr += 1.
          ENDWHILE.

          " 3) Remaining deletes — right filled, left empty (own rows)
          lv_pr = lv_np + 1.
          WHILE lv_pr <= lv_nd.
            lv_lno_r += 1.
            lv_il2 = lt_d2[ lv_pr ].
            REPLACE ALL OCCURRENCES OF `&` IN lv_il2 WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<` IN lv_il2 WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>` IN lv_il2 WITH `&gt;`.
            lv_rows = lv_rows &&
              |<tr>| &&
              |<td class="ln"></td><td class="cd"></td>| &&
              |<td class="sep"></td>| &&
              |<td class="ln" style="background:#ffecec">{ lv_lno_r }</td>| &&
              |<td class="cd" style="background:#ffecec">{ lv_il2 }</td></tr>|.
            CLEAR lv_il2.
            lv_pr += 1.
          ENDWHILE.
          CLEAR: lt_d2, lt_i2, lv_gap2.
          lv_pos2 = lv_sc.
        ELSE.
          lv_pos2 += 1.
        ENDIF.
      ENDWHILE.

      result =
        |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
        |*\{margin:0;padding:0;box-sizing:border-box\}| &&
        |body\{background:#fff;color:#1e1e1e;font:12px/1.5 Consolas,monospace\}| &&
        |.hdr\{background:#f3f3f3;padding:5px 12px;border-bottom:1px solid #ddd;| &&
               |color:#444;font-size:11px;display:flex;gap:16px;flex-wrap:wrap\}| &&
        |.ttl\{color:#0066aa;font-weight:bold\}.meta\{color:#888\}| &&
        |table\{border-collapse:collapse;width:100%\}| &&
        |.ln\{color:#aaa;text-align:right;padding:1px 8px 1px 4px;| &&
             |user-select:none;min-width:36px;border-right:1px solid #e0e0e0;| &&
             |white-space:nowrap;background:#fafafa\}| &&
        |.cd\{padding:1px 8px;white-space:pre;width:{ lv_max_w }ch\}| &&
        |.sep\{border-left:2px solid #ccc;padding:0\}| &&
        |</style></head><body>| &&
        |<div class="hdr">| &&
        |<span class="ttl">| && i_title && |</span>| &&
        |<span class="meta">| && i_meta  && |</span>| &&
        |</div>| &&
        |<table><tbody>| && lv_rows &&
        |</tbody></table></body></html>|.
      RETURN.
    ENDIF.

    " ── Inline rendering (default) ───────────────────────────────

    " Scan diff ops, grouping consecutive '-' and '+' blocks
    DATA lv_pos   TYPE i VALUE 1.
    DATA lv_total TYPE i.
    lv_total = lines( it_diff ).

    DATA lv_gap_shown TYPE abap_bool.   " tracks if '...' separator was already output
    WHILE lv_pos <= lv_total.
      IF lo_progress->check(
           i_remaining = lv_total - lv_pos + 1
           i_total     = lv_total ) = abap_true.
        EXIT.
      ENDIF.
      READ TABLE it_diff INTO DATA(ls_cur) INDEX lv_pos.

      IF ls_cur-op = '='.
        lv_lno += 1.
        IF i_compact = abap_true AND lt_show[ lv_pos ] = abap_false.
          " Skip this line — show separator if not shown yet for this gap
          IF lv_gap_shown = abap_false.
            lv_rows = lv_rows &&
              |<tr style="background:#f0f0f0;color:#888">| &&
              |<td class="ln">...</td><td class="cd">...</td></tr>|.
            lv_gap_shown = abap_true.
          ENDIF.
          lv_pos += 1.
          CONTINUE.
        ENDIF.
        CLEAR lv_gap_shown.
        DATA(lv_line_eq) = ls_cur-text.
        REPLACE ALL OCCURRENCES OF `&` IN lv_line_eq WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_line_eq WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_line_eq WITH `&gt;`.
        lv_rows = lv_rows &&
          |<tr style="background:#ffffff">| &&
          |<td class="ln">{ lv_lno }</td>| &&
          |<td class="cd">{ lv_line_eq }</td></tr>|.
        lv_pos += 1.

      ELSEIF ls_cur-op = '-' OR ls_cur-op = '+'.
        " Collect EXTENDED block: consecutive '-'/'+' AND short bridging
        " empty '=' lines (max 1 in a row) when more changes follow.
        " This lets us pair changes across blank-line gaps that LCS inserted.
        DATA lt_block   TYPE zif_ave_popup_types=>ty_t_diff.
        DATA lt_dels    TYPE string_table.
        DATA lt_ins     TYPE string_table.
        DATA lt_del_idx TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
        DATA lt_ins_idx TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
        DATA lv_scan    TYPE i.
        CLEAR: lt_block, lt_dels, lt_ins, lt_del_idx, lt_ins_idx.
        lv_scan = lv_pos.

        WHILE lv_scan <= lv_total.
          READ TABLE it_diff INTO DATA(ls_s) INDEX lv_scan.
          IF ls_s-op = '-' OR ls_s-op = '+'.
            APPEND ls_s TO lt_block.
            lv_scan += 1.
          ELSEIF ls_s-op = '=' AND condense( val = ls_s-text ) = ``.
            " tentative bridge — peek ahead through up to 1 more empty '='
            DATA lv_peek         TYPE i.
            DATA lv_extra        TYPE i.
            DATA lv_more_changes TYPE abap_bool.
            lv_peek = lv_scan + 1.
            lv_extra = 0.
            lv_more_changes = abap_false.
            WHILE lv_peek <= lv_total.
              READ TABLE it_diff INTO DATA(ls_p) INDEX lv_peek.
              IF ls_p-op = '-' OR ls_p-op = '+'.
                lv_more_changes = abap_true.
                EXIT.
              ELSEIF ls_p-op = '=' AND condense( val = ls_p-text ) = `` AND lv_extra < 1.
                lv_extra += 1.
                lv_peek += 1.
                CONTINUE.
              ELSE.
                EXIT.
              ENDIF.
            ENDWHILE.
            IF lv_more_changes = abap_true.
              APPEND ls_s TO lt_block.
              lv_scan += 1.
            ELSE.
              EXIT.
            ENDIF.
          ELSE.
            EXIT.
          ENDIF.
        ENDWHILE.

        " Build dels/ins texts plus their positions inside lt_block.
        " Skip whitespace-only lines from pairing — they have no chars to
        " match and would otherwise eat an index slot, breaking alignment
        " between real changes. They still render as solo via the block walk.
        DATA lv_bi TYPE i.
        lv_bi = 1.
        WHILE lv_bi <= lines( lt_block ).
          DATA(ls_b) = lt_block[ lv_bi ].
          IF ls_b-op = '-' AND condense( val = ls_b-text ) <> ``.
            APPEND ls_b-text TO lt_dels.
            APPEND lv_bi     TO lt_del_idx.
          ELSEIF ls_b-op = '+' AND condense( val = ls_b-text ) <> ``.
            APPEND ls_b-text TO lt_ins.
            APPEND lv_bi     TO lt_ins_idx.
          ENDIF.
          lv_bi += 1.
        ENDWHILE.

        " Blame separator for added lines
        IF it_blame IS NOT INITIAL AND lt_ins IS NOT INITIAL.
          READ TABLE it_blame INTO DATA(ls_bl) WITH KEY text = lt_ins[ 1 ].
          IF sy-subrc = 0.
            DATA(lv_bdate) = |{ ls_bl-datum+6(2) }.{ ls_bl-datum+4(2) }.{ ls_bl-datum(4) }|.
            DATA(lv_btime) = |{ ls_bl-zeit(2) }:{ ls_bl-zeit+2(2) }|.
            DATA(lv_btask) = COND string(
              WHEN ls_bl-korrnum IS NOT INITIAL AND ls_bl-task IS NOT INITIAL THEN | { ls_bl-korrnum }/{ ls_bl-task }|
              WHEN ls_bl-korrnum IS NOT INITIAL THEN | { ls_bl-korrnum }|
              WHEN ls_bl-task IS NOT INITIAL THEN | { ls_bl-task }|
              ELSE `` ).
            DATA(lv_btasktxt) = COND string( WHEN ls_bl-task_text IS NOT INITIAL THEN | { ls_bl-task_text }| ELSE `` ).
            lv_rows = lv_rows &&
              |<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">| &&
              |<td class="ln">▶</td>| &&
              |<td class="cd">── { ls_bl-author }| &&
              COND string( WHEN ls_bl-author_name IS NOT INITIAL THEN | ({ ls_bl-author_name })| ELSE `` ) &&
              | changed  { lv_bdate } { lv_btime }  v.{ ls_bl-versno_text }{ lv_btask }{ lv_btasktxt } ──</td></tr>|.
          ENDIF.
        ENDIF.
        " Blame separator for deleted lines
        IF it_blame_deleted IS NOT INITIAL AND lt_dels IS NOT INITIAL AND lt_ins IS INITIAL.
          READ TABLE it_blame_deleted INTO DATA(ls_bld) WITH KEY text = lt_dels[ 1 ].
          IF sy-subrc = 0.
            DATA(lv_bddate) = |{ ls_bld-datum+6(2) }.{ ls_bld-datum+4(2) }.{ ls_bld-datum(4) }|.
            DATA(lv_bdtime) = |{ ls_bld-zeit(2) }:{ ls_bld-zeit+2(2) }|.
            DATA(lv_bdtask) = COND string(
              WHEN ls_bld-korrnum IS NOT INITIAL AND ls_bld-task IS NOT INITIAL THEN | { ls_bld-korrnum }/{ ls_bld-task }|
              WHEN ls_bld-korrnum IS NOT INITIAL THEN | { ls_bld-korrnum }|
              WHEN ls_bld-task IS NOT INITIAL THEN | { ls_bld-task }|
              ELSE `` ).
            DATA(lv_bdtasktxt) = COND string( WHEN ls_bld-task_text IS NOT INITIAL THEN | { ls_bld-task_text }| ELSE `` ).
            lv_rows = lv_rows &&
              |<tr style="background:#fdf0f0;color:#888;font-size:10px;font-style:italic">| &&
              |<td class="ln">◀</td>| &&
              |<td class="cd">── { ls_bld-author }| &&
              COND string( WHEN ls_bld-author_name IS NOT INITIAL THEN | ({ ls_bld-author_name })| ELSE `` ) &&
              | deleted  { lv_bddate } { lv_bdtime }  v.{ ls_bld-versno_text }{ lv_bdtask }{ lv_bdtasktxt } ──</td></tr>|.
          ENDIF.
        ENDIF.

        DATA(lv_ndels) = lines( lt_dels ).
        DATA(lv_nins)  = lines( lt_ins ).
        DATA(lv_min_di) = COND i( WHEN lv_ndels < lv_nins THEN lv_ndels ELSE lv_nins ).

        " status[i] for each block position: 'P' = render paired here,
        "                                    'C' = consumed (skip), ' ' = solo/equal
        DATA lt_status     TYPE STANDARD TABLE OF c WITH DEFAULT KEY.
        DATA lt_inline_html TYPE string_table.
        CLEAR: lt_status, lt_inline_html.
        DATA lv_init TYPE i.
        lv_init = 1.
        WHILE lv_init <= lines( lt_block ).
          APPEND ` ` TO lt_status.
          APPEND `` TO lt_inline_html.
          lv_init += 1.
        ENDWHILE.

        DATA lv_pk TYPE i.
        lv_pk = 1.
        WHILE lv_pk <= lv_min_di.
          IF i_plain = abap_false AND zcl_ave_popup_diff=>has_common_chars( iv_a = lt_dels[ lv_pk ] iv_b = lt_ins[ lv_pk ] ) = abap_true.
            DATA(lv_di)    = lt_del_idx[ lv_pk ].
            DATA(lv_ii)    = lt_ins_idx[ lv_pk ].
            DATA(lv_first) = COND i( WHEN lv_di < lv_ii THEN lv_di ELSE lv_ii ).
            DATA(lv_other) = COND i( WHEN lv_di > lv_ii THEN lv_di ELSE lv_ii ).
            lt_status[ lv_first ] = 'P'.
            lt_status[ lv_other ] = 'C'.
            lt_inline_html[ lv_first ] = zcl_ave_popup_diff=>char_diff_html(
              iv_old  = lt_dels[ lv_pk ]
              iv_new  = lt_ins[ lv_pk ]
              iv_side = 'B' ).
          ENDIF.
          lv_pk += 1.
        ENDWHILE.

        " Render block ops in original order
        DATA lv_rb TYPE i.
        lv_rb = 1.
        WHILE lv_rb <= lines( lt_block ).
          DATA(ls_bo) = lt_block[ lv_rb ].
          DATA(lv_st) = lt_status[ lv_rb ].
          IF ls_bo-op = '='.
            lv_lno += 1.
            DATA(lv_eq) = ls_bo-text.
            REPLACE ALL OCCURRENCES OF `&` IN lv_eq WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<` IN lv_eq WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>` IN lv_eq WITH `&gt;`.
            lv_rows = lv_rows &&
              |<tr style="background:#ffffff">| &&
              |<td class="ln">{ lv_lno }</td>| &&
              |<td class="cd">{ lv_eq }</td></tr>|.
          ELSEIF ls_bo-op = '-'.
            IF lv_st = 'P'.
              lv_lno += 1.
              lv_rows = lv_rows &&
                |<tr style="background:#ffffff">| &&
                |<td class="ln">{ lv_lno }</td>| &&
                |<td class="cd">{ lt_inline_html[ lv_rb ] }</td></tr>|.
            ELSEIF lv_st = 'C'.
              " skip — already rendered as part of paired row
            ELSE.
              DATA(lv_dl) = ls_bo-text.
              REPLACE ALL OCCURRENCES OF `&` IN lv_dl WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_dl WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_dl WITH `&gt;`.
              lv_rows = lv_rows &&
                |<tr style="background:#ffecec">| &&
                |<td class="ln" style="color:#cc0000">-</td>| &&
                |<td class="cd" style="color:#cc0000">{ lv_dl }</td></tr>|.
            ENDIF.
          ELSE.  " '+'
            IF lv_st = 'P'.
              lv_lno += 1.
              lv_rows = lv_rows &&
                |<tr style="background:#ffffff">| &&
                |<td class="ln">{ lv_lno }</td>| &&
                |<td class="cd">{ lt_inline_html[ lv_rb ] }</td></tr>|.
            ELSEIF lv_st = 'C'.
              " skip
            ELSE.
              lv_lno += 1.
              DATA(lv_il) = ls_bo-text.
              REPLACE ALL OCCURRENCES OF `&` IN lv_il WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_il WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_il WITH `&gt;`.
              lv_rows = lv_rows &&
                |<tr style="background:#eaffea">| &&
                |<td class="ln" style="color:#006600">{ lv_lno }</td>| &&
                |<td class="cd" style="color:#006600">{ lv_il }</td></tr>|.
            ENDIF.
          ENDIF.
          lv_rb += 1.
        ENDWHILE.

        CLEAR lt_dels.
        CLEAR lt_ins.
        lv_pos = lv_scan.
      ELSE.
        lv_pos += 1.
      ENDIF.
    ENDWHILE.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#ffffff;color:#1e1e1e;font:12px/1.5 Consolas,monospace\}| &&
      |.hdr\{background:#f3f3f3;padding:5px 12px;border-bottom:1px solid #ddd;| &&
             |color:#444;font-size:11px;display:flex;gap:16px;flex-wrap:wrap\}| &&
      |.ttl\{color:#0066aa;font-weight:bold\}| &&
      |.meta\{color:#888\}| &&
      |table\{border-collapse:collapse;width:100%\}| &&
      |.ln\{color:#aaa;text-align:right;padding:1px 10px 1px 5px;| &&
           |user-select:none;min-width:42px;border-right:1px solid #e0e0e0;| &&
           |white-space:nowrap;background:#fafafa\}| &&
      |.cd\{padding:1px 8px;white-space:pre\}| &&
      |</style></head><body>| &&
      |<div class="hdr">| &&
      |<span class="ttl">| && i_title && |</span>| &&
      |<span class="meta">| && i_meta  && |</span>| &&
      |</div>| &&
      |<table><tbody>| && lv_rows &&
      |</tbody></table></body></html>|.
  ENDMETHOD.
  METHOD debug_diff_html.
    " Debug rendering: dump diff ops + change blocks + pairing decisions.
    " Mirrors AVEDiff.debugToHtml() in html_simulator/diff.js — same input
    " through both should produce structurally identical output.
    DATA lv_ops_rows TYPE string.
    DATA lv_blocks   TYPE string.
    DATA lv_idx      TYPE i.

    " ── Section 1: raw ops list ──
    lv_idx = 0.
    LOOP AT it_diff INTO DATA(ls_op).
      lv_idx += 1.
      DATA(lv_op_cls) = COND string(
        WHEN ls_op-op = '=' THEN `eq`
        WHEN ls_op-op = '-' THEN `del`
        ELSE `ins` ).
      DATA(lv_text_e) = ls_op-text.
      REPLACE ALL OCCURRENCES OF `&` IN lv_text_e WITH `&amp;`.
      REPLACE ALL OCCURRENCES OF `<` IN lv_text_e WITH `&lt;`.
      REPLACE ALL OCCURRENCES OF `>` IN lv_text_e WITH `&gt;`.
      DATA(lv_show)   = COND string(
        WHEN lv_text_e IS INITIAL THEN `<em>&lt;empty&gt;</em>`
        ELSE lv_text_e ).
      lv_ops_rows = lv_ops_rows &&
        |<tr class="{ lv_op_cls }"><td class="ln">{ lv_idx }</td>| &&
        |<td class="op">{ ls_op-op }</td><td class="cd">{ lv_show }</td></tr>|.
    ENDLOOP.

    " ── Section 2: walk change blocks, record pairing decisions ──
    DATA lv_pos      TYPE i VALUE 1.
    DATA lv_total    TYPE i.
    DATA lv_block_no TYPE i VALUE 0.
    lv_total = lines( it_diff ).

    WHILE lv_pos <= lv_total.
      READ TABLE it_diff INTO DATA(ls_cur) INDEX lv_pos.
      IF ls_cur-op = '='.
        lv_pos += 1.
        CONTINUE.
      ENDIF.

      DATA lt_dels    TYPE string_table.
      DATA lt_ins     TYPE string_table.
      DATA lv_bridged TYPE i.
      CLEAR: lt_dels, lt_ins, lv_bridged.
      DATA lv_scan TYPE i.
      lv_scan = lv_pos.
      WHILE lv_scan <= lv_total.
        READ TABLE it_diff INTO DATA(ls_s) INDEX lv_scan.
        IF ls_s-op = '-'.
          IF condense( val = ls_s-text ) <> ``.
            APPEND ls_s-text TO lt_dels.
          ENDIF.
          lv_scan += 1.
        ELSEIF ls_s-op = '+'.
          IF condense( val = ls_s-text ) <> ``.
            APPEND ls_s-text TO lt_ins.
          ENDIF.
          lv_scan += 1.
        ELSEIF ls_s-op = '=' AND condense( val = ls_s-text ) = ``.
          " Bridge short empty '=' if more changes follow (max 1 in a row)
          DATA lv_peek         TYPE i.
          DATA lv_extra        TYPE i.
          DATA lv_more_changes TYPE abap_bool.
          lv_peek = lv_scan + 1.
          lv_extra = 0.
          lv_more_changes = abap_false.
          WHILE lv_peek <= lv_total.
            READ TABLE it_diff INTO DATA(ls_p) INDEX lv_peek.
            IF ls_p-op = '-' OR ls_p-op = '+'.
              lv_more_changes = abap_true.
              EXIT.
            ELSEIF ls_p-op = '=' AND condense( val = ls_p-text ) = `` AND lv_extra < 1.
              lv_extra += 1.
              lv_peek += 1.
              CONTINUE.
            ELSE.
              EXIT.
            ENDIF.
          ENDWHILE.
          IF lv_more_changes = abap_true.
            lv_bridged += 1.
            lv_scan += 1.
          ELSE.
            EXIT.
          ENDIF.
        ELSE.
          EXIT.
        ENDIF.
      ENDWHILE.

      lv_block_no += 1.
      DATA(lv_nd) = lines( lt_dels ).
      DATA(lv_ni) = lines( lt_ins ).
      DATA(lv_min_di) = COND i( WHEN lv_nd < lv_ni THEN lv_nd ELSE lv_ni ).
      DATA(lv_block_end) = lv_scan - 1.

      DATA lv_pair_rows TYPE string.
      CLEAR lv_pair_rows.
      DATA lv_k TYPE i.
      lv_k = 1.
      WHILE lv_k <= lv_min_di.
        DATA(lv_a) = lt_dels[ lv_k ].
        DATA(lv_b) = lt_ins[ lv_k ].
        " Replicate has_common_chars: trim, common prefix length
        DATA lv_ta TYPE string.
        DATA lv_tb TYPE string.
        lv_ta = lv_a.
        lv_tb = lv_b.
        WHILE strlen( lv_ta ) > 0 AND substring( val = lv_ta off = 0 len = 1 ) = ` `.
          lv_ta = substring( val = lv_ta off = 1 len = strlen( lv_ta ) - 1 ).
        ENDWHILE.
        WHILE strlen( lv_tb ) > 0 AND substring( val = lv_tb off = 0 len = 1 ) = ` `.
          lv_tb = substring( val = lv_tb off = 1 len = strlen( lv_tb ) - 1 ).
        ENDWHILE.
        WHILE strlen( lv_ta ) > 0 AND substring( val = lv_ta off = strlen( lv_ta ) - 1 len = 1 ) = ` `.
          lv_ta = substring( val = lv_ta off = 0 len = strlen( lv_ta ) - 1 ).
        ENDWHILE.
        WHILE strlen( lv_tb ) > 0 AND substring( val = lv_tb off = strlen( lv_tb ) - 1 len = 1 ) = ` `.
          lv_tb = substring( val = lv_tb off = 0 len = strlen( lv_tb ) - 1 ).
        ENDWHILE.
        DATA(lv_la) = strlen( lv_ta ).
        DATA(lv_lb) = strlen( lv_tb ).
        DATA lv_cp TYPE i VALUE 0.
        lv_cp = 0.
        WHILE lv_cp < lv_la AND lv_cp < lv_lb.
          IF lv_ta+lv_cp(1) = lv_tb+lv_cp(1).
            lv_cp += 1.
          ELSE.
            EXIT.
          ENDIF.
        ENDWHILE.
        DATA(lv_paired) = COND abap_bool(
          WHEN lv_la = 0 OR lv_lb = 0 THEN abap_false
          WHEN lv_cp >= 3              THEN abap_true
          ELSE abap_false ).

        DATA(lv_a_e) = lv_a.
        REPLACE ALL OCCURRENCES OF `&` IN lv_a_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_a_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_a_e WITH `&gt;`.
        DATA(lv_b_e) = lv_b.
        REPLACE ALL OCCURRENCES OF `&` IN lv_b_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_b_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_b_e WITH `&gt;`.
        DATA(lv_a_show) = COND string(
          WHEN lv_a_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_a_e ).
        DATA(lv_b_show) = COND string(
          WHEN lv_b_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_b_e ).
        DATA(lv_verdict) = COND string(
          WHEN lv_paired = abap_true
            THEN |<span class="ok">PAIR (cp={ lv_cp })</span>|
            ELSE |<span class="bad">SOLO (cp={ lv_cp } &lt; 3)</span>| ).
        DATA(lv_inline) = COND string(
          WHEN lv_paired = abap_true THEN zcl_ave_popup_diff=>char_diff_html( iv_old = lv_a iv_new = lv_b iv_side = 'B' )
          ELSE `<em>—</em>` ).
        lv_pair_rows = lv_pair_rows &&
          |<tr><td class="ln">{ lv_k }</td>| &&
          |<td class="cd"><span class="del-tag">−</span> <code>{ lv_a_show }</code></td>| &&
          |<td class="cd"><span class="ins-tag">+</span> <code>{ lv_b_show }</code></td>| &&
          |<td>{ lv_verdict }</td>| &&
          |<td class="cd">{ lv_inline }</td></tr>|.
        lv_k += 1.
      ENDWHILE.

      DATA lv_leftover TYPE string.
      CLEAR lv_leftover.
      lv_k = lv_min_di + 1.
      WHILE lv_k <= lv_nd.
        DATA(lv_d_e) = lt_dels[ lv_k ].
        REPLACE ALL OCCURRENCES OF `&` IN lv_d_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_d_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_d_e WITH `&gt;`.
        DATA(lv_d_show) = COND string( WHEN lv_d_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_d_e ).
        lv_leftover = lv_leftover && |<div class="solo del">SOLO − <code>{ lv_d_show }</code></div>|.
        lv_k += 1.
      ENDWHILE.
      lv_k = lv_min_di + 1.
      WHILE lv_k <= lv_ni.
        DATA(lv_i_e) = lt_ins[ lv_k ].
        REPLACE ALL OCCURRENCES OF `&` IN lv_i_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_i_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_i_e WITH `&gt;`.
        DATA(lv_i_show) = COND string( WHEN lv_i_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_i_e ).
        lv_leftover = lv_leftover && |<div class="solo ins">SOLO + <code>{ lv_i_show }</code></div>|.
        lv_k += 1.
      ENDWHILE.

      DATA(lv_pair_section) = COND string(
        WHEN lv_pair_rows IS NOT INITIAL THEN
          |<table class="pair"><thead><tr><th>k</th><th>del</th><th>ins</th>| &&
          |<th>verdict</th><th>char-diff (if paired)</th></tr></thead>| &&
          |<tbody>| && lv_pair_rows && |</tbody></table>|
        ELSE `<div class="meta">(no del/ins pairs to test)</div>` ).
      DATA(lv_leftover_section) = COND string(
        WHEN lv_leftover IS NOT INITIAL THEN |<div class="leftover">{ lv_leftover }</div>|
        ELSE `` ).

      DATA(lv_bridge_note) = COND string(
        WHEN lv_bridged > 0 THEN | <span class="meta">— bridged { lv_bridged } empty '=' line(s)</span>|
        ELSE `` ).
      lv_blocks = lv_blocks &&
        |<div class="block"><h3>Block #{ lv_block_no } | &&
        |<span class="meta">({ lv_nd } dels, { lv_ni } ins, ops [{ lv_pos }..{ lv_block_end }])</span>| &&
        lv_bridge_note && |</h3>| &&
        lv_pair_section && lv_leftover_section && |</div>|.

      lv_pos = lv_scan.
    ENDWHILE.

    IF lv_blocks IS INITIAL.
      lv_blocks = `<div class="meta">(no change blocks)</div>`.
    ENDIF.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#fff;color:#222;font:12px/1.5 Segoe UI,sans-serif;padding:10px\}| &&
      |h2\{font-size:13px;margin:14px 0 6px;color:#0066aa;border-bottom:1px solid #ddd;padding-bottom:3px\}| &&
      |h3\{font-size:12px;margin:8px 0 4px;color:#444\}| &&
      |.hdr\{background:#f3f3f3;padding:6px 10px;border:1px solid #ddd;color:#444;| &&
            |display:flex;gap:14px;flex-wrap:wrap;margin-bottom:8px\}| &&
      |.ttl\{color:#0066aa;font-weight:bold\}.meta\{color:#888;font-weight:normal;font-size:11px\}| &&
      |table\{border-collapse:collapse;width:100%;font:11px/1.4 Consolas,monospace;margin-bottom:6px\}| &&
      |th,td\{padding:2px 6px;border:1px solid #e0e0e0;text-align:left;vertical-align:top\}| &&
      |th\{background:#fafafa;font-weight:600\}| &&
      |.ln\{color:#aaa;text-align:right;width:40px;background:#fafafa\}| &&
      |.op\{width:24px;text-align:center;font-weight:bold\}| &&
      |tr.eq td\{color:#888\}| &&
      |tr.del\{background:#ffecec\}tr.del td.op\{color:#cc0000\}| &&
      |tr.ins\{background:#eaffea\}tr.ins td.op\{color:#006600\}| &&
      |.cd\{white-space:pre;font:11px/1.4 Consolas,monospace\}| &&
      |code\{font:11px/1.4 Consolas,monospace;background:#f7f7f7;padding:1px 4px;border-radius:2px\}| &&
      |.block\{border:1px solid #ddd;padding:6px;margin-bottom:8px;border-radius:3px;background:#fcfcfc\}| &&
      |.pair th\{background:#eef\}| &&
      |.ok\{color:#006600;font-weight:bold\}.bad\{color:#cc0000;font-weight:bold\}| &&
      |.del-tag\{color:#cc0000;font-weight:bold\}.ins-tag\{color:#006600;font-weight:bold\}| &&
      |.solo\{margin:2px 0;padding:2px 6px;border-radius:2px;font:11px/1.4 Consolas,monospace\}| &&
      |.solo.del\{background:#ffecec;color:#cc0000\}| &&
      |.solo.ins\{background:#eaffea;color:#006600\}| &&
      |.leftover\{margin-top:4px\}| &&
      |em\{color:#aaa;font-style:italic\}| &&
      |</style></head><body>| &&
      |<div class="hdr"><span class="ttl">DEBUG: | && i_title && |</span>| &&
      |<span class="meta">| && i_meta && |</span></div>| &&
      |<h2>1. Diff ops ({ lv_total } total)</h2>| &&
      |<table><thead><tr><th>#</th><th>op</th><th>text</th></tr></thead>| &&
      |<tbody>| && lv_ops_rows && |</tbody></table>| &&
      |<h2>2. Change blocks &amp; pairing decisions</h2>| && lv_blocks &&
      |</body></html>|.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_popup_diff IMPLEMENTATION.

  METHOD compute_diff.
    DATA(lv_nold) = lines( it_old ).
    DATA(lv_nnew) = lines( it_new ).

    " Simplest possible diff for large files: two-pointer walk with a
    " short look-ahead window for resync. No hash maps, no DP matrix —
    " just the result table in memory. Handles "one line deleted, rest
    " identical" correctly (resync at k=1). Degrades to 1:1 substitution
    " if no match within lc_window steps.
    IF lv_nold > 10000 OR lv_nnew > 10000.
      CONSTANTS lc_window TYPE i VALUE 50.
      DATA(lo_p) = NEW zcl_ave_progress( i_title = i_title i_threshold_secs = 30 ).
      DATA lv_i1  TYPE i VALUE 1.
      DATA lv_j1  TYPE i VALUE 1.
      DATA lv_tot TYPE i.
      lv_tot = lv_nold + lv_nnew.

      WHILE lv_i1 <= lv_nold OR lv_j1 <= lv_nnew.
        IF lo_p->check( i_remaining = lv_tot - lv_i1 - lv_j1 + 2
                        i_total     = lv_tot ) = abap_true.
          RETURN.
        ENDIF.
        IF lv_i1 > lv_nold.
          APPEND VALUE ty_diff_op( op = '+' text = CONV string( it_new[ lv_j1 ] ) ) TO result.
          lv_j1 += 1.
          CONTINUE.
        ENDIF.
        IF lv_j1 > lv_nnew.
          APPEND VALUE ty_diff_op( op = '-' text = CONV string( it_old[ lv_i1 ] ) ) TO result.
          lv_i1 += 1.
          CONTINUE.
        ENDIF.
        IF it_old[ lv_i1 ] = it_new[ lv_j1 ].
          APPEND VALUE ty_diff_op( op = '=' text = CONV string( it_old[ lv_i1 ] ) ) TO result.
          lv_i1 += 1.
          lv_j1 += 1.
          CONTINUE.
        ENDIF.

        " Mismatch — probe forward up to lc_window steps to find resync.
        DATA lv_k    TYPE i.
        DATA lv_mode TYPE c.
        CLEAR lv_mode.
        lv_k = 1.
        WHILE lv_k <= lc_window.
          " old[i] appears at new[j+k]? → k inserts
          IF lv_j1 + lv_k <= lv_nnew AND it_new[ lv_j1 + lv_k ] = it_old[ lv_i1 ].
            lv_mode = '+'.
            EXIT.
          ENDIF.
          " new[j] appears at old[i+k]? → k deletes
          IF lv_i1 + lv_k <= lv_nold AND it_old[ lv_i1 + lv_k ] = it_new[ lv_j1 ].
            lv_mode = '-'.
            EXIT.
          ENDIF.
          lv_k += 1.
        ENDWHILE.

        IF lv_mode = '+'.
          DO lv_k TIMES.
            APPEND VALUE ty_diff_op( op = '+' text = CONV string( it_new[ lv_j1 ] ) ) TO result.
            lv_j1 += 1.
          ENDDO.
        ELSEIF lv_mode = '-'.
          DO lv_k TIMES.
            APPEND VALUE ty_diff_op( op = '-' text = CONV string( it_old[ lv_i1 ] ) ) TO result.
            lv_i1 += 1.
          ENDDO.
        ELSE.
          " No match within window — substitute 1:1 and advance both sides.
          APPEND VALUE ty_diff_op( op = '-' text = CONV string( it_old[ lv_i1 ] ) ) TO result.
          APPEND VALUE ty_diff_op( op = '+' text = CONV string( it_new[ lv_j1 ] ) ) TO result.
          lv_i1 += 1.
          lv_j1 += 1.
        ENDIF.
      ENDWHILE.
      RETURN.
    ENDIF.

    " Build flat 2D DP table: (lv_nold+1) x (lv_nnew+1)
    DATA(lv_cols) = lv_nnew + 1.
    DATA(lv_rows) = lv_nold + 1.
    DATA lt_dp TYPE TABLE OF i.
    DATA(lv_size) = lv_rows * lv_cols.
    DO lv_size TIMES.
      APPEND 0 TO lt_dp.
    ENDDO.

    " Fill DP
    DATA(lo_progress) = NEW zcl_ave_progress( i_title = i_title i_threshold_secs = 30 ).
    DATA lv_i TYPE i.
    DATA lv_j TYPE i.
    lv_i = 1.
    LOOP AT it_old INTO DATA(ls_old).
      IF lo_progress->check(
           i_remaining = lv_nold - lv_i + 1
           i_total     = lv_nold ) = abap_true.
        RETURN.
      ENDIF.
      lv_j = 1.
      LOOP AT it_new INTO DATA(ls_new).
        DATA(lv_cell) = lv_i * lv_cols + lv_j + 1.
        IF ls_old = ls_new.
          DATA(lv_prev) = ( lv_i - 1 ) * lv_cols + ( lv_j - 1 ) + 1.
          lt_dp[ lv_cell ] = lt_dp[ lv_prev ] + 1.
        ELSE.
          DATA(lv_up)   = ( lv_i - 1 ) * lv_cols + lv_j + 1.
          DATA(lv_left) = lv_i * lv_cols + ( lv_j - 1 ) + 1.
          DATA(lv_vup)   = lt_dp[ lv_up ].
          DATA(lv_vleft) = lt_dp[ lv_left ].
          lt_dp[ lv_cell ] = COND i( WHEN lv_vup >= lv_vleft THEN lv_vup ELSE lv_vleft ).
        ENDIF.
        lv_j += 1.
      ENDLOOP.
      lv_i += 1.
    ENDLOOP.

    " Backtrack to build diff ops (prepend into result).
    " Prefer deletion over insertion (cup > cleft) so '-' precedes '+'
    " in the same change block – keeps related pairs together.
    lv_i = lv_nold.
    lv_j = lv_nnew.
    WHILE lv_i > 0 OR lv_j > 0.
      IF lv_i > 0 AND lv_j > 0.
        READ TABLE it_old INTO DATA(ls_bo) INDEX lv_i.
        READ TABLE it_new INTO DATA(ls_bn) INDEX lv_j.
        IF ls_bo = ls_bn.
          INSERT VALUE ty_diff_op( op = '=' text = CONV string( ls_bn ) ) INTO result INDEX 1.
          lv_i -= 1.
          lv_j -= 1.
        ELSE.
          DATA(lv_cup)   = ( lv_i - 1 ) * lv_cols + lv_j + 1.
          DATA(lv_cleft) = lv_i * lv_cols + ( lv_j - 1 ) + 1.
          IF lt_dp[ lv_cup ] >= lt_dp[ lv_cleft ].
            INSERT VALUE ty_diff_op( op = '-' text = CONV string( ls_bo ) ) INTO result INDEX 1.
            lv_i -= 1.
          ELSE.
            INSERT VALUE ty_diff_op( op = '+' text = CONV string( ls_bn ) ) INTO result INDEX 1.
            lv_j -= 1.
          ENDIF.
        ENDIF.
      ELSEIF lv_i > 0.
        READ TABLE it_old INTO DATA(ls_bo2) INDEX lv_i.
        INSERT VALUE ty_diff_op( op = '-' text = CONV string( ls_bo2 ) ) INTO result INDEX 1.
        lv_i -= 1.
      ELSE.
        READ TABLE it_new INTO DATA(ls_bn2) INDEX lv_j.
        INSERT VALUE ty_diff_op( op = '+' text = CONV string( ls_bn2 ) ) INTO result INDEX 1.
        lv_j -= 1.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.
  METHOD char_diff_html.
    " Prefix/suffix approach: find common prefix, common suffix,
    " highlight only the changed middle fragment.
    " Strip trailing spaces only (source lines are padded to 255 chars);
    " internal/leading spaces must be preserved so whitespace-only changes are diffed.
    DATA lv_old_t TYPE string.
    DATA lv_new_t TYPE string.
    lv_old_t = iv_old.
    lv_new_t = iv_new.
    WHILE strlen( lv_old_t ) > 0 AND substring( val = lv_old_t off = strlen( lv_old_t ) - 1 len = 1 ) = ` `.
      lv_old_t = substring( val = lv_old_t off = 0 len = strlen( lv_old_t ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_new_t ) > 0 AND substring( val = lv_new_t off = strlen( lv_new_t ) - 1 len = 1 ) = ` `.
      lv_new_t = substring( val = lv_new_t off = 0 len = strlen( lv_new_t ) - 1 ).
    ENDWHILE.

    DATA(lv_lo) = strlen( lv_old_t ).
    DATA(lv_ln) = strlen( lv_new_t ).

    " Common prefix
    DATA(lv_pre) = 0.
    WHILE lv_pre < lv_lo AND lv_pre < lv_ln.
      IF lv_old_t+lv_pre(1) = lv_new_t+lv_pre(1).
        lv_pre += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.

    " Common suffix (not overlapping prefix)
    DATA(lv_suf) = 0.
    WHILE lv_suf < lv_lo - lv_pre AND lv_suf < lv_ln - lv_pre.
      DATA(lv_po) = lv_lo - 1 - lv_suf.
      DATA(lv_pn) = lv_ln - 1 - lv_suf.
      IF lv_old_t+lv_po(1) = lv_new_t+lv_pn(1).
        lv_suf += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.

    " Extract parts
    DATA(lv_prefix)    = COND string( WHEN lv_pre > 0       THEN lv_old_t+0(lv_pre)          ELSE `` ).
    DATA(lv_mid_o_len) = lv_lo - lv_pre - lv_suf.
    DATA(lv_mid_n_len) = lv_ln - lv_pre - lv_suf.
    DATA(lv_mid_o)     = COND string( WHEN lv_mid_o_len > 0 THEN lv_old_t+lv_pre(lv_mid_o_len) ELSE `` ).
    DATA(lv_mid_n)     = COND string( WHEN lv_mid_n_len > 0 THEN lv_new_t+lv_pre(lv_mid_n_len) ELSE `` ).
    DATA(lv_suf_pos)   = lv_pre + lv_mid_o_len.
    DATA(lv_suffix)    = COND string( WHEN lv_suf > 0       THEN lv_old_t+lv_suf_pos(lv_suf)   ELSE `` ).

    " HTML-escape all parts
    REPLACE ALL OCCURRENCES OF `&` IN lv_prefix WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_prefix WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_prefix WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF `&` IN lv_mid_o  WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_mid_o  WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_mid_o  WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF ` ` IN lv_mid_o  WITH `&nbsp;`.
    REPLACE ALL OCCURRENCES OF `&` IN lv_mid_n  WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_mid_n  WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_mid_n  WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF ` ` IN lv_mid_n  WITH `&nbsp;`.
    REPLACE ALL OCCURRENCES OF `&` IN lv_suffix WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_suffix WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_suffix WITH `&gt;`.

    " Styles with horizontal padding so even a single-space highlight is visible.
    " outline gives a clear edge for whitespace-only fragments.
    DATA(lv_del_style) = `background:#ffb3b3;color:#cc0000;` &&
                        `padding:0 2px;outline:1px solid #c66`.
    DATA(lv_ins_style) = `background:#afffaf;color:#006600;` &&
                        `padding:0 2px;outline:1px solid #6c6`.

    " Comment-out detection: if new line starts with * or " but old doesn't,
    " the code was commented out — show old fragment with strikethrough.
    IF lv_pre = 0
      AND strlen( lv_new_t ) > 0 AND strlen( lv_old_t ) > 0
      AND ( lv_new_t(1) = `*` OR lv_new_t(1) = `"` )
      AND lv_old_t(1) <> `*` AND lv_old_t(1) <> `"`.
      lv_del_style = lv_del_style && `;text-decoration:line-through`.
    ENDIF.

    result = lv_prefix.
    CASE iv_side.
      WHEN 'O'.
        IF lv_mid_o IS NOT INITIAL.
          result = result && |<span style="{ lv_del_style }">{ lv_mid_o }</span>|.
        ENDIF.
      WHEN 'N'.
        IF lv_mid_n IS NOT INITIAL.
          result = result && |<span style="{ lv_ins_style }">{ lv_mid_n }</span>|.
        ENDIF.
      WHEN OTHERS. " 'B': show deleted then inserted inline
        IF lv_mid_o IS NOT INITIAL.
          result = result && |<span style="{ lv_del_style }">{ lv_mid_o }</span>|.
        ENDIF.
        IF lv_mid_n IS NOT INITIAL.
          result = result && |<span style="{ lv_ins_style }">{ lv_mid_n }</span>|.
        ENDIF.
    ENDCASE.
    result = result && lv_suffix.
  ENDMETHOD.
  METHOD has_common_chars.
    " Returns true if iv_a and iv_b share a non-trivial common prefix or suffix.
    " Used to decide whether two changed lines are similar enough to pair.
    DATA lv_a TYPE string.
    DATA lv_b TYPE string.
    lv_a = iv_a.
    lv_b = iv_b.
    " Strip leading whitespace — common indentation must not count as "common prefix"
    WHILE strlen( lv_a ) > 0 AND substring( val = lv_a off = 0 len = 1 ) = ` `.
      lv_a = substring( val = lv_a off = 1 len = strlen( lv_a ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_b ) > 0 AND substring( val = lv_b off = 0 len = 1 ) = ` `.
      lv_b = substring( val = lv_b off = 1 len = strlen( lv_b ) - 1 ).
    ENDWHILE.
    " Strip trailing whitespace
    WHILE strlen( lv_a ) > 0 AND substring( val = lv_a off = strlen( lv_a ) - 1 len = 1 ) = ` `.
      lv_a = substring( val = lv_a off = 0 len = strlen( lv_a ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_b ) > 0 AND substring( val = lv_b off = strlen( lv_b ) - 1 len = 1 ) = ` `.
      lv_b = substring( val = lv_b off = 0 len = strlen( lv_b ) - 1 ).
    ENDWHILE.
    DATA(lv_la) = strlen( lv_a ).
    DATA(lv_lb) = strlen( lv_b ).
    IF lv_la = 0 OR lv_lb = 0.
      result = abap_false.
      RETURN.
    ENDIF.

    " Comment-out special case: one line starts with * or " and the other doesn't.
    " Strip the comment char (+ leading spaces) and check for >=3 common chars with the other line.
    DATA(lv_a_is_cmt) = boolc( lv_a(1) = `*` OR lv_a(1) = `"` ).
    DATA(lv_b_is_cmt) = boolc( lv_b(1) = `*` OR lv_b(1) = `"` ).
    IF lv_a_is_cmt <> lv_b_is_cmt.
      DATA lv_uncommented TYPE string.
      DATA lv_other TYPE string.
      IF lv_a_is_cmt = abap_true.
        lv_uncommented = lv_a+1.
        lv_other       = lv_b.
      ELSE.
        lv_uncommented = lv_b+1.
        lv_other       = lv_a.
      ENDIF.
      " Strip leading spaces from the de-commented side
      WHILE strlen( lv_uncommented ) > 0 AND lv_uncommented(1) = ` `.
        lv_uncommented = lv_uncommented+1.
      ENDWHILE.
      DATA lv_ccp TYPE i VALUE 0.
      WHILE lv_ccp < strlen( lv_uncommented ) AND lv_ccp < strlen( lv_other ).
        IF lv_uncommented+lv_ccp(1) = lv_other+lv_ccp(1).
          lv_ccp += 1.
        ELSE.
          EXIT.
        ENDIF.
      ENDWHILE.
      result = boolc( lv_ccp >= 3 ).
      RETURN.
    ENDIF.

    DATA lv_cp TYPE i VALUE 0.
    WHILE lv_cp < lv_la AND lv_cp < lv_lb.
      IF lv_a+lv_cp(1) = lv_b+lv_cp(1).
        lv_cp += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.
    " Require a real common prefix (>=3 chars). Suffix only reinforces but isn't enough alone.
    result = boolc( lv_cp >= 3 ).
  ENDMETHOD.
  METHOD build_blame_map.
    " Filter versions for this object within [i_from, i_to] and order ascending
    DATA lt_vers TYPE zif_ave_popup_types=>ty_t_version_row.
    LOOP AT it_versions INTO DATA(ls_v)
      WHERE versno  >= i_from
        AND versno  <= i_to
        AND objtype  = i_objtype
        AND objname  = i_objname.
      APPEND ls_v TO lt_vers.
    ENDLOOP.
    SORT lt_vers BY versno ASCENDING datum ASCENDING zeit ASCENDING.
    IF lines( lt_vers ) < 2. RETURN. ENDIF.

    DATA lt_prev_src TYPE abaptxt255_tab.
    DATA(ls_first) = lt_vers[ 1 ].
    lt_prev_src = zcl_ave_popup_data=>get_ver_source(
      i_objtype = ls_first-objtype i_objname = ls_first-objname i_versno = ls_first-versno
      i_korrnum = ls_first-korrnum i_author  = ls_first-author
      i_datum   = ls_first-datum   i_zeit    = ls_first-zeit ).

    DATA lv_idx TYPE i VALUE 2.
    WHILE lv_idx <= lines( lt_vers ).
      DATA(ls_ver) = lt_vers[ lv_idx ].
      DATA(lt_cur_src) = zcl_ave_popup_data=>get_ver_source(
        i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno
        i_korrnum = ls_ver-korrnum i_author  = ls_ver-author
        i_datum   = ls_ver-datum   i_zeit    = ls_ver-zeit ).
      DATA(lt_diff) = compute_diff(
        it_old  = lt_prev_src
        it_new  = lt_cur_src
        i_title = 'Computing blame' ).

      LOOP AT lt_diff INTO DATA(ls_d).
        IF ls_d-op = '+'.
          DATA(lv_text) = ls_d-text.
          DELETE result WHERE text = lv_text.
          APPEND VALUE zif_ave_popup_types=>ty_blame_entry(
            text        = lv_text
            author      = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner ELSE ls_ver-author )
            author_name = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner_name ELSE ls_ver-author_name )
            datum       = ls_ver-datum
            zeit        = ls_ver-zeit
            versno_text = ls_ver-versno_text
            korrnum     = ls_ver-korrnum
            task        = ls_ver-task
            task_text   = ls_ver-korr_text
          ) TO result.
        ELSEIF ls_d-op = '-'.
          DELETE et_blame_deleted WHERE text = ls_d-text.
          APPEND VALUE zif_ave_popup_types=>ty_blame_entry(
            text        = ls_d-text
            author      = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner ELSE ls_ver-author )
            author_name = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner_name ELSE ls_ver-author_name )
            datum       = ls_ver-datum
            zeit        = ls_ver-zeit
            versno_text = ls_ver-versno_text
            korrnum     = ls_ver-korrnum
            task        = ls_ver-task
            task_text   = ls_ver-korr_text
          ) TO et_blame_deleted.
          DELETE result WHERE text = ls_d-text.
        ENDIF.
      ENDLOOP.

      lt_prev_src = lt_cur_src.
      lv_idx += 1.
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_popup_data IMPLEMENTATION.

  METHOD get_user_name.
    result = NEW zcl_ave_author( )->get_name( iv_user ).
  ENDMETHOD.
  METHOD get_latest_author.
    DATA(lo_vrsd) = NEW zcl_ave_vrsd( type = i_type name = i_name ).
    IF lo_vrsd->vrsd_list IS INITIAL. RETURN. ENDIF.
    DATA(lt_list) = lo_vrsd->vrsd_list.
    SORT lt_list BY versno DESCENDING.
    result = lt_list[ 1 ]-author.
  ENDMETHOD.
  METHOD check_part_exists.
    IF i_type = 'RELE'.
      result = abap_true.
      RETURN.
    ENDIF.

    " METH: check existence directly in SEOCOMPO (class/method component table)
    IF i_type = 'METH' AND i_class_name IS NOT INITIAL.
      DATA lv_meth_cmpname TYPE seocmpname.
      DATA lv_cmptype      TYPE seocmptype VALUE '1'.
      lv_meth_cmpname = i_name.
      SELECT SINGLE clsname FROM seocompo
        WHERE clsname = @i_class_name
          AND cmpname = @lv_meth_cmpname
          AND cmptype = @lv_cmptype
        INTO @DATA(lv_cls_found).
      result = boolc( sy-subrc = 0 ).
      RETURN.
    ENDIF.

    IF i_type = 'CPUB' OR i_type = 'CPRO' OR i_type = 'CPRI'.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA lv_tadir_type TYPE tadir-object.
    IF i_type = 'REPS'.
      lv_tadir_type = 'PROG'.
    ELSEIF i_type = 'CLSD'.
      lv_tadir_type = 'CLAS'.   " VRSD 'CLSD' = class header, exists as CLAS in TADIR/TR
    ELSE.
      lv_tadir_type = i_type.
    ENDIF.

    DATA lv_obj_name TYPE tadir-obj_name.
    lv_obj_name = i_name.
    DATA lv_pgmid TYPE tadir-pgmid.
    SELECT SINGLE pgmid FROM tadir
      WHERE pgmid    = 'R3TR'
        AND object   = @lv_tadir_type
        AND obj_name = @lv_obj_name
        AND delflag  = ' '
      INTO @lv_pgmid.
    result = boolc( sy-subrc = 0 ).
  ENDMETHOD.
  METHOD get_type_text.
    IF mv_cache_loaded = abap_false.
      load_type_cache( ).
    ENDIF.
    READ TABLE mt_type_cache ASSIGNING FIELD-SYMBOL(<c>) WITH TABLE KEY type = i_type.
    IF sy-subrc = 0.
      result = <c>-text.
    ENDIF.
  ENDMETHOD.
  METHOD load_type_cache.
    mv_cache_loaded = abap_true.
    DATA lt_types_out TYPE STANDARD TABLE OF ko100.
    CALL FUNCTION 'TRINT_OBJECT_TABLE'
      EXPORTING iv_complete  = 'X'
      TABLES    tt_types_out = lt_types_out.
    LOOP AT lt_types_out INTO DATA(ls_ko100).
      INSERT VALUE #( type = ls_ko100-object text = ls_ko100-text )
        INTO TABLE mt_type_cache.
    ENDLOOP.
  ENDMETHOD.
  METHOD remove_duplicate_versions.
    TYPES: BEGIN OF ty_prev,
             objtype TYPE versobjtyp,
             objname TYPE versobjnam,
             src     TYPE abaptxt255_tab,
             has_src TYPE abap_bool,
           END OF ty_prev.
    DATA lt_prev_map TYPE HASHED TABLE OF ty_prev WITH UNIQUE KEY objtype objname.
    DATA lt_result   TYPE zif_ave_popup_types=>ty_t_version_row.

    " ct_versions can contain rows for multiple (objtype,objname) pairs mixed
    " together (e.g. all methods of a class sorted globally by versno). We must
    " compare each row only against the previous row of the SAME object.
    LOOP AT ct_versions INTO DATA(ls_ver).

      " Read source directly from SVRS — bypass zcl_ave_version constructor,
      " whose load_latest_task can raise zcx_ave and leave lt_cur_src empty
      " for some versions while others succeed, producing spurious diffs.
      DATA lt_cur_src TYPE abaptxt255_tab.
      DATA lt_trdir   TYPE trdir_it.
      CLEAR lt_cur_src.
      DATA(lv_db_no) = zcl_ave_versno=>to_internal( ls_ver-versno ).
      CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
        EXPORTING object_name = ls_ver-objname
                  object_type = ls_ver-objtype
                  versno      = lv_db_no
        TABLES    repos_tab   = lt_cur_src
                  trdir_tab   = lt_trdir
        EXCEPTIONS no_version = 1 OTHERS = 2.
      IF sy-subrc <> 0. CLEAR lt_cur_src. ENDIF.

      " Compare ignoring leading whitespace (pretty-printer reindent is not a real change)
      DATA lt_cur_norm  TYPE string_table.
      DATA lt_prev_norm TYPE string_table.
      CLEAR lt_cur_norm. CLEAR lt_prev_norm.
      LOOP AT lt_cur_src INTO DATA(ls_cn).
        DATA(lv_cn) = CONV string( ls_cn ).
        SHIFT lv_cn LEFT DELETING LEADING ` `.
        APPEND lv_cn TO lt_cur_norm.
      ENDLOOP.

      DATA lv_has_prev TYPE abap_bool.
      lv_has_prev = abap_false.
      READ TABLE lt_prev_map ASSIGNING FIELD-SYMBOL(<p>)
        WITH TABLE KEY objtype = ls_ver-objtype objname = ls_ver-objname.
      IF sy-subrc = 0 AND <p>-has_src = abap_true.
        lv_has_prev = abap_true.
        LOOP AT <p>-src INTO DATA(ls_pn).
          DATA(lv_pn) = CONV string( ls_pn ).
          SHIFT lv_pn LEFT DELETING LEADING ` `.
          APPEND lv_pn TO lt_prev_norm.
        ENDLOOP.
      ENDIF.

      IF lv_has_prev = abap_false OR lt_cur_norm <> lt_prev_norm.
        APPEND ls_ver TO lt_result.
        IF <p> IS ASSIGNED.
          <p>-src     = lt_cur_src.
          <p>-has_src = abap_true.
        ELSE.
          INSERT VALUE #( objtype = ls_ver-objtype objname = ls_ver-objname
                          src = lt_cur_src has_src = abap_true )
            INTO TABLE lt_prev_map.
        ENDIF.
      ENDIF.
      UNASSIGN <p>.
    ENDLOOP.

    ct_versions = lt_result.
  ENDMETHOD.
  METHOD get_active_line_count.
    DATA lv_incname TYPE progname.
    DATA lt_src TYPE TABLE OF string.
    TRY.
        CASE i_type.
          WHEN 'CLSD' OR 'RELE' OR 'DEVC' OR 'FUGR' OR 'CLAS'.
            " Aggregate / header types — no single source.
            RETURN.
          WHEN 'INTF'.
            lv_incname = cl_oo_classname_service=>get_interfacepool_name( CONV #( i_name ) ).
          WHEN 'CPUB'.
            lv_incname = cl_oo_classname_service=>get_pubsec_name( CONV #( i_name ) ).
          WHEN 'CPRO'.
            lv_incname = cl_oo_classname_service=>get_prosec_name( CONV #( i_name ) ).
          WHEN 'CPRI'.
            lv_incname = cl_oo_classname_service=>get_prisec_name( CONV #( i_name ) ).
          WHEN 'METH'.
            " i_name layout (VRSD convention): class (30-char, blank-padded) + method
            DATA(lv_cls) = CONV seoclsname( i_name(30) ).
            DATA lv_mtd TYPE seocpdname.
            lv_mtd = i_name+30.
            lv_incname = cl_oo_classname_service=>get_method_include(
              mtdkey = VALUE #( clsname = lv_cls cpdname = lv_mtd ) ).
          WHEN OTHERS.
            lv_incname = i_name.
        ENDCASE.
        IF lv_incname IS INITIAL. RETURN. ENDIF.
        READ REPORT lv_incname INTO lt_src.
        IF sy-subrc = 0.
          result = lines( lt_src ).
        ENDIF.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.
  METHOD get_ver_source.
    DATA lt_vrsd TYPE vrsd_tab.
    DATA(lv_vno) = zcl_ave_versno=>to_internal( i_versno ).
    SELECT * FROM vrsd
      WHERE objtype = @i_objtype
        AND objname = @i_objname
        AND versno  = @lv_vno
      INTO TABLE @lt_vrsd UP TO 1 ROWS.
    IF lt_vrsd IS INITIAL.
      " Synthetic VRSD row so SVRS_GET_REPS_FROM_OBJECT can still resolve the source.
      APPEND VALUE vrsd(
        objtype = i_objtype
        objname = i_objname
        versno  = lv_vno
        korrnum = i_korrnum
        author  = i_author
        datum   = i_datum
        zeit    = i_zeit
      ) TO lt_vrsd.
    ENDIF.
    result = NEW zcl_ave_version( lt_vrsd[ 1 ] )->get_source( ).
  ENDMETHOD.
  METHOD check_class_has_author.
    TRY.
        DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
          object_type = zcl_ave_object_factory=>gc_type-class
          object_name = CONV #( i_class_name ) ).
        LOOP AT lo_obj->get_parts( ) INTO DATA(ls_part).
          CHECK ls_part-type <> 'CLSD' AND ls_part-type <> 'RELE'.
          IF is_substantive_user_change( i_type = ls_part-type i_name = ls_part-object_name i_user = i_user ) = abap_true.
            result = abap_true.
            RETURN.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.
  METHOD is_substantive_user_change.
    " Condition 1: latest version authored by i_user.
    DATA(lo_vrsd) = NEW zcl_ave_vrsd( type = i_type name = i_name ).
    DATA(lt_list) = lo_vrsd->vrsd_list.
    IF lt_list IS INITIAL. RETURN. ENDIF.
    SORT lt_list BY versno DESCENDING.
    DATA(ls_latest) = lt_list[ 1 ].
    IF ls_latest-author <> i_user. RETURN. ENDIF.

    " Condition 2: nearest prior K-TR version by date/time (single targeted query).
    DATA ls_prior TYPE vrsd.
    SELECT v~versno v~datum v~zeit v~korrnum
      FROM vrsd AS v
      INNER JOIN e070 AS e ON e~trkorr = v~korrnum
      WHERE v~objtype = @i_type
        AND v~objname = @i_name
        AND e~trfunction = 'K'
        AND ( v~datum < @ls_latest-datum
           OR ( v~datum = @ls_latest-datum AND v~zeit < @ls_latest-zeit ) )
      ORDER BY v~datum DESCENDING, v~zeit DESCENDING
      INTO CORRESPONDING FIELDS OF @ls_prior
      UP TO 1 ROWS.
    ENDSELECT.

    " No prior K-TR version — user is first author, treat as substantive.
    IF ls_prior-korrnum IS INITIAL.
      result = abap_true.
      RETURN.
    ENDIF.

    " Condition 3: full source equality (direct internal-table compare).
    DATA lt_new   TYPE abaptxt255_tab.
    DATA lt_old   TYPE abaptxt255_tab.
    DATA lt_trdir TYPE trdir_it.
    CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
      EXPORTING object_name = i_name object_type = i_type
                versno      = zcl_ave_versno=>to_internal( ls_latest-versno )
      TABLES    repos_tab   = lt_new trdir_tab = lt_trdir
      EXCEPTIONS no_version = 1 OTHERS = 2.
    IF sy-subrc <> 0. CLEAR lt_new. ENDIF.
    CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
      EXPORTING object_name = i_name object_type = i_type
                versno      = zcl_ave_versno=>to_internal( ls_prior-versno )
      TABLES    repos_tab   = lt_old trdir_tab = lt_trdir
      EXCEPTIONS no_version = 1 OTHERS = 2.
    IF sy-subrc <> 0. CLEAR lt_old. ENDIF.

    result = boolc( lt_new <> lt_old ).
  ENDMETHOD.

ENDCLASS.

CLASS ZCL_AVE_POPUP IMPLEMENTATION.
  METHOD constructor.
    mv_object_type = i_object_type.
    mv_object_name = i_object_name.
    " Member vars already have correct defaults (show_diff/no_toc/compact = X, two_pane = ' ')
    " Override only when settings explicitly provided
    IF is_settings IS SUPPLIED.
      mv_show_diff   = is_settings-show_diff.
      mv_two_pane    = is_settings-two_pane.
      mv_no_toc      = is_settings-no_toc.
      mv_compact     = is_settings-compact.
      mv_remove_dup  = is_settings-remove_dup.
      mv_blame       = is_settings-blame.
      mv_filter_user = is_settings-filter_user.
      mv_date_from   = is_settings-date_from.
    ENDIF.

  ENDMETHOD.
  METHOD show.
    build_layout( ).
    build_parts_list( ).
    build_html_viewer( ).
    build_versions_grid( ).

    " Auto-open the first part only for single-object views (class/program/intf/func).
    " For TR / package the user picks a row manually — auto-loading versions for
    " an arbitrary "first" object is slow and usually not what they want.
    IF mv_object_type <> zcl_ave_object_factory=>gc_type-tr
       AND mv_object_type <> zcl_ave_object_factory=>gc_type-package.
      DATA(lt_supported) = VALUE string_table(
        ( |REPS| ) ( |METH| ) ( |CLSD| ) ( |CPUB| ) ( |CPRO| )
        ( |CPRI| ) ( |CINC| ) ( |CDEF| ) ( |FUNC| ) ).
      LOOP AT mt_parts INTO DATA(ls_first)
        WHERE exists_flag = abap_true.
        CHECK line_exists( lt_supported[ table_line = ls_first-type ] ).
        mv_cur_objtype = ls_first-type.
        mv_cur_objname = ls_first-object_name.
        load_versions( i_objtype = ls_first-type i_objname = ls_first-object_name ).
        refresh_vers( ).
        IF mt_versions IS NOT INITIAL.
          ms_base_ver = mt_versions[ 1 ].
          mv_viewed_versno = ms_base_ver-versno.
          IF mv_show_diff = abap_true.
            READ TABLE mt_versions INTO DATA(ls_prev_auto) INDEX 2.
            IF sy-subrc = 0.
              auto_show_diff_or_source( is_old = ls_prev_auto is_new = ms_base_ver ).
            ELSE.
              show_source( i_objtype = ms_base_ver-objtype
                           i_objname = ms_base_ver-objname
                           i_versno  = ms_base_ver-versno ).
            ENDIF.
          ELSE.
            show_source( i_objtype = ms_base_ver-objtype
                         i_objname = ms_base_ver-objname
                         i_versno  = ms_base_ver-versno ).
          ENDIF.
          update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
        ENDIF.
        EXIT.
      ENDLOOP.
    ENDIF.

    cl_gui_cfw=>flush( ).
  ENDMETHOD.
  METHOD build_layout.

    ADD 1 TO mv_counter.

    CREATE OBJECT mo_box
      EXPORTING
        width                       = 1300
        height                      = 400
        top                         = 25
        left                        = 50
        caption                     = |{ mv_object_type }: { mv_object_name }|
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

    " Outer splitter: row 1 = toolbar, row 2 = content
    DATA(lo_split_outer) = NEW cl_gui_splitter_container(
      parent  = mo_box
      rows    = 2
      columns = 1 ).
    lo_split_outer->set_row_height( id = 1 height = 4 ).
    lo_split_outer->set_row_sash( id = 1 type = 0 value = 0 ).
    mo_cont_toolbar = lo_split_outer->get_container( row = 1 column = 1 ).
    DATA(lo_cont_main) = lo_split_outer->get_container( row = 2 column = 1 ).

    " Wrapper: row 1 = normal layout, row 2 = 2-pane layout (hidden initially)
    mo_split_wrap = NEW cl_gui_splitter_container(
      parent  = lo_cont_main
      rows    = 2
      columns = 1 ).
    mo_split_wrap->set_row_height( id = 1 height = 100 ).
    mo_split_wrap->set_row_height( id = 2 height = 0 ).
    mo_split_wrap->set_row_sash( id = 1 type = 0 value = 0 ).
    mo_split_wrap->set_row_sash( id = 2 type = 0 value = 0 ).
    DATA(lo_normal) = mo_split_wrap->get_container( row = 1 column = 1 ).
    DATA(lo_2pane)  = mo_split_wrap->get_container( row = 2 column = 1 ).

    " ── Normal layout: [parts+vers | html] ──────────────────────────
    CREATE OBJECT mo_split_main
      EXPORTING
        parent  = lo_normal
        rows    = 1
        columns = 2.
    mo_split_main->set_column_width( id = 1 width = 40 ).
    mo_split_main->set_column_width( id = 2 width = 60 ).
    DATA(lo_top) = mo_split_main->get_container( row = 1 column = 1 ).
    CREATE OBJECT mo_split_top
      EXPORTING
        parent  = lo_top
        rows    = 2
        columns = 1.
    mo_split_top->set_row_height( id = 1 height = 60 ).
    mo_cont_parts = mo_split_top->get_container( row = 1 column = 1 ).
    mo_cont_vers  = mo_split_top->get_container( row = 2 column = 1 ).
    mo_cont_html  = mo_split_main->get_container( row = 1 column = 2 ).

    " ── 2-pane layout: [parts | vers] top + [html] bottom ───────────
    mo_split_2p_wrap = NEW cl_gui_splitter_container(
      parent  = lo_2pane
      rows    = 2
      columns = 1 ).
    DATA(lo_2p_wrap) = mo_split_2p_wrap.
    lo_2p_wrap->set_row_height( id = 1 height = 35 ).
    mo_split_2p_top = NEW cl_gui_splitter_container(
      parent  = lo_2p_wrap->get_container( row = 1 column = 1 )
      rows    = 1
      columns = 2 ).
    mo_split_2p_top->set_column_width( id = 1 width = 25 ).
    mo_split_2p_top->set_column_width( id = 2 width = 75 ).
    mo_cont_parts_2p = mo_split_2p_top->get_container( row = 1 column = 1 ).
    mo_cont_vers_2p  = mo_split_2p_top->get_container( row = 1 column = 2 ).
    mo_cont_html_2p  = lo_2p_wrap->get_container( row = 2 column = 1 ).

    " If starting in 2-pane mode — flip wrapper and point containers
    IF mv_two_pane = abap_true.
      mo_split_wrap->set_row_height( id = 1 height = 0 ).
      mo_split_wrap->set_row_height( id = 2 height = 100 ).
      mo_cont_parts = mo_cont_parts_2p.
      mo_cont_vers  = mo_cont_vers_2p.
      mo_cont_html  = mo_cont_html_2p.
    ENDIF.

    " For single-object types (program / function) — hide parts, give versions 100%
    IF mv_object_type = zcl_ave_object_factory=>gc_type-program OR
       mv_object_type = zcl_ave_object_factory=>gc_type-function.
      mo_split_top->set_row_height(    id = 1 height = 0   ).
      mo_split_top->set_row_height(    id = 2 height = 100 ).
      mo_split_2p_top->set_column_width( id = 1 width  = 0   ).
      mo_split_2p_top->set_column_width( id = 2 width  = 100 ).
    ENDIF.
  ENDMETHOD.
  METHOD build_parts_list.
    " Load parts via object handler factory
    TRY.
        IF mv_object_type = zcl_ave_object_factory=>gc_type-class.
          " CLASS: filter empty includes, no existence check needed
          mt_parts = get_class_parts( CONV #( mv_object_name ) ).
        ELSE.
          DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
            object_type = mv_object_type
            object_name = CONV #( mv_object_name ) ).
          DATA(lv_is_tr) = boolc( mv_object_type = zcl_ave_object_factory=>gc_type-tr ).
          LOOP AT lo_obj->get_parts( ) INTO DATA(ls_raw).
            CHECK ls_raw-type <> 'RELE'.
            DATA(lv_exists) = COND abap_bool(
              WHEN lv_is_tr = abap_true
              THEN zcl_ave_popup_data=>check_part_exists(
                     i_type       = ls_raw-type
                     i_name       = CONV #( ls_raw-unit )
                     i_class_name = CONV #( ls_raw-class ) )
              ELSE abap_true ).
            DATA ls_row TYPE ty_part_row.
            ls_row-class       = ls_raw-class.
            ls_row-name        = ls_raw-unit.
            ls_row-type        = ls_raw-type.
            ls_row-type_text   = zcl_ave_popup_data=>get_type_text( ls_raw-type ).
            ls_row-object_name = ls_raw-object_name.
            ls_row-exists_flag = lv_exists.
            ls_row-rows        = COND i( WHEN lv_exists = abap_true
              THEN zcl_ave_popup_data=>get_active_line_count( i_type = ls_raw-type i_name = ls_raw-object_name )
              ELSE 0 ).
            IF lv_exists = abap_false.
              ls_row-rowcolor = 'C610'.   " red
            ELSEIF mv_filter_user IS NOT INITIAL.
              DATA(lv_user_match) = COND abap_bool(
                WHEN ls_raw-type = 'CLAS'
                THEN zcl_ave_popup_data=>check_class_has_author( i_class_name = CONV #( ls_raw-object_name ) i_user = mv_filter_user )
                ELSE zcl_ave_popup_data=>is_substantive_user_change(
                       i_type = ls_raw-type i_name = ls_raw-object_name i_user = mv_filter_user ) ).
              IF lv_user_match = abap_true.
                ls_row-rowcolor = 'C510'. " green
              ENDIF.
            ENDIF.
            APPEND ls_row TO mt_parts.
            CLEAR ls_row.
          ENDLOOP.
        ENDIF.
      CATCH zcx_ave.
        " leave mt_parts empty – no crash
    ENDTRY.

    " ── Toolbar (full-width top row, container from build_layout) ──
    CREATE OBJECT mo_toolbar EXPORTING parent = mo_cont_toolbar.
    DATA lt_tb_events TYPE cntl_simple_events.
    APPEND VALUE #( eventid = cl_gui_toolbar=>m_id_function_selected ) TO lt_tb_events.
    mo_toolbar->set_registered_events( lt_tb_events ).
    SET HANDLER me->on_toolbar_click FOR mo_toolbar.
    mo_toolbar->add_button_group( VALUE ttb_button(
      ( function  = 'REFRESH'
        icon      = CONV #( icon_refresh )
        text      = 'Refresh'
        quickinfo = 'Refresh' )
      ( function  = 'PANE_TOGGLE'
        icon      = CONV #( ICON_SPOOL_REQUEST )
        text      = 'Inline'
        quickinfo = 'Inline' )
      ( function  = 'DIFF_TOGGLE'
        icon      = CONV #( icon_compare )
        text      = 'Show Diff'
        quickinfo = 'Show Diff' )
      ( function  = 'COMPACT_TOGGLE'
        icon      = CONV #( icon_collapse_all )
        text      = 'Compact'
        quickinfo = 'Compact' )
      ( function  = 'BLAME_TOGGLE'
        icon      = CONV #( icon_history )
        text      = 'Blame'
        quickinfo = 'Toggle Blame' )
      ( function  = 'FOCUS_TOGGLE'
        icon      = CONV #( icon_view_maximize )
        text      = 'Maximize View'
        quickinfo = 'Hide parts/versions, expand HTML' )
      ( function  = 'DEBUG'
        icon      = CONV #( icon_bw_dm_aa )
        text      = 'Debug'
        quickinfo = 'Show diff ops + pairing decisions' )
      ( function  = 'INFO'
        icon      = CONV #( icon_bw_gis )
        text      = ''
        quickinfo = 'Documentation' ) ) ).

    " Sync button texts with initial flag values
    mo_toolbar->set_button_info( EXPORTING fcode = 'DIFF_TOGGLE'
      text = COND #( WHEN mv_show_diff = abap_true THEN 'Show Diff' ELSE 'Show Vers' ) ).
    mo_toolbar->set_button_info( EXPORTING fcode = 'COMPACT_TOGGLE'
      text = COND #( WHEN mv_compact   = abap_true THEN 'Compact'   ELSE 'Full'      ) ).
    mo_toolbar->set_button_info( EXPORTING fcode = 'PANE_TOGGLE'
      text = COND #( WHEN mv_two_pane  = abap_true THEN '2-Pane'    ELSE 'Inline'    ) ).
    mo_toolbar->set_button_info( EXPORTING fcode = 'BLAME_TOGGLE'
      text = COND #( WHEN mv_blame     = abap_true THEN 'Blame ON'  ELSE 'Blame'     ) ).

    create_parts_alv( ).
  ENDMETHOD.
  METHOD create_parts_alv.
    " ── Field catalog ──
    DATA lt_fcat TYPE lvc_t_fcat.
    DATA ls_fc   TYPE lvc_s_fcat.

    CLEAR ls_fc. ls_fc-fieldname = 'TYPE'.        ls_fc-coltext = 'Type'.
    ls_fc-outputlen = 6.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'NAME'.        ls_fc-coltext = 'Object'.
    ls_fc-outputlen = 30. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'CLASS'.       ls_fc-coltext = 'Class'.
    ls_fc-outputlen = 20. ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'TYPE_TEXT'.   ls_fc-coltext = 'Type Description'.
    ls_fc-outputlen = 30. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'ROWS'.        ls_fc-coltext = 'Rows'.
    ls_fc-outputlen = 6. ls_fc-just = 'R'. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJECT_NAME'. ls_fc-coltext = 'Object'.
    ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'EXISTS_FLAG'. ls_fc-coltext = 'Exists'.
    ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'ROWCOLOR'.    ls_fc-coltext = 'Color'.
    ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.

    " ── Layout ──
    DATA ls_layo TYPE lvc_s_layo.
    ls_layo-zebra      = abap_true.
    ls_layo-info_fname = 'ROWCOLOR'.
    ls_layo-cwidth_opt = abap_true.
    ls_layo-no_toolbar = abap_false.
    ls_layo-sel_mode   = 'A'.

    " ── Create ALV Grid ──
    mo_alv_parts = NEW cl_gui_alv_grid( i_parent = mo_cont_parts ).

    SET HANDLER me->handle_parts_toolbar  FOR mo_alv_parts.
    SET HANDLER me->handle_parts_command  FOR mo_alv_parts.
    SET HANDLER me->handle_parts_dblclick FOR mo_alv_parts.

    mo_alv_parts->set_table_for_first_display(
      EXPORTING
        is_layout       = ls_layo
        i_save          = 'A'
        i_default       = 'X'
      CHANGING
        it_fieldcatalog = lt_fcat
        it_outtab       = mt_parts ).

    mo_alv_parts->set_toolbar_interactive( ).
  ENDMETHOD.
  METHOD build_html_viewer.
    create_html_viewer( ).
  ENDMETHOD.
  METHOD create_html_viewer.
    " Split mo_cont_html into two rows: HTML on top (diff), ABAP editor
    " on bottom (single-version source). Only one has non-zero height.
    CREATE OBJECT mo_split_html
      EXPORTING parent = mo_cont_html rows = 2 columns = 1.
    mo_cont_html_diff = mo_split_html->get_container( row = 1 column = 1 ).
    mo_cont_html_code = mo_split_html->get_container( row = 2 column = 1 ).
    mo_split_html->set_row_height( id = 1 height = 100 ).
    mo_split_html->set_row_height( id = 2 height = 0 ).

    CREATE OBJECT mo_html
      EXPORTING
        parent             = mo_cont_html_diff
      EXCEPTIONS
        cntl_error         = 1
        cntl_install_error = 2
        dp_install_error   = 3
        dp_error           = 4
        OTHERS             = 5.

    CREATE OBJECT mo_code_viewer
      EXPORTING parent = mo_cont_html_code max_number_chars = 255.
    mo_code_viewer->upload_properties( EXCEPTIONS OTHERS = 1 ).
    mo_code_viewer->set_statusbar_mode( statusbar_mode = cl_gui_abapedit=>true ).
    mo_code_viewer->create_document( ).
    mo_code_viewer->set_readonly_mode( 1 ).

    set_html(
      |<!DOCTYPE html><html><head><style>| &&
      |body\{margin:0;background:#f8f8f8;color:#999;| &&
      |font:13px/1.6 Consolas,monospace;| &&
      |display:flex;align-items:center;justify-content:center;height:100vh\}| &&
      |</style></head><body>| &&
      |<div>Double-click a part on the left to open its latest version.</div>| &&
      |</body></html>| ).
  ENDMETHOD.
  METHOD build_versions_grid.
    create_versions_alv( ).
  ENDMETHOD.
  METHOD create_versions_alv.
    " ── Field catalog ──
    DATA lt_fcat TYPE lvc_t_fcat.
    DATA ls_fc   TYPE lvc_s_fcat.

    CLEAR ls_fc. ls_fc-fieldname = 'VERSNO'.      ls_fc-no_out = abap_true.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'VERSNO_TEXT'. ls_fc-coltext = 'Version'.
    ls_fc-outputlen = 8.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'DATUM'.       ls_fc-coltext = 'Date'.
    ls_fc-outputlen = 10. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'ZEIT'.        ls_fc-coltext = 'Time'.
    ls_fc-outputlen = 8.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'AUTHOR'.      ls_fc-coltext = 'Author'.
    ls_fc-outputlen = 12. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'AUTHOR_NAME'.    ls_fc-coltext = 'Name'.
    ls_fc-outputlen = 20. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJ_OWNER'.      ls_fc-coltext = 'Obj Owner'.
    ls_fc-outputlen = 12. ls_fc-emphasize = 'C411'. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJ_OWNER_NAME'. ls_fc-coltext = 'Owner Name'.
    ls_fc-outputlen = 20. ls_fc-emphasize = 'C411'. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'KORRNUM'.     ls_fc-coltext = 'Request'.
    ls_fc-outputlen = 12. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'TASK'.        ls_fc-coltext = 'Task'.
    ls_fc-outputlen = 12. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'KORR_TEXT'.   ls_fc-coltext = 'Description'.
    ls_fc-outputlen = 40. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJNAME'.     ls_fc-coltext = 'Object'.
    ls_fc-outputlen = 30. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJTYPE'.     ls_fc-coltext = 'Type'.
    ls_fc-outputlen = 6.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'ROWCOLOR'.    ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.

    " ── Layout ──
    DATA ls_layo TYPE lvc_s_layo.
    ls_layo-zebra      = abap_true.
    ls_layo-info_fname = 'ROWCOLOR'.
    ls_layo-cwidth_opt = abap_true.
    ls_layo-sel_mode   = 'A'.

    " ── Create ALV Grid ──
    mo_alv_vers = NEW cl_gui_alv_grid( i_parent = mo_cont_vers ).

    SET HANDLER me->handle_vers_toolbar  FOR mo_alv_vers.
    SET HANDLER me->handle_vers_command  FOR mo_alv_vers.
    SET HANDLER me->handle_vers_dblclick FOR mo_alv_vers.

    mo_alv_vers->set_table_for_first_display(
      EXPORTING
        is_layout       = ls_layo
        i_save          = 'A'
        i_default       = 'X'
      CHANGING
        it_fieldcatalog = lt_fcat
        it_outtab       = mt_versions ).

    mo_alv_vers->set_toolbar_interactive( ).
  ENDMETHOD.
  METHOD handle_parts_toolbar.
    CLEAR e_object->mt_toolbar.
    CHECK mt_parts_backup IS NOT INITIAL.
    APPEND VALUE stb_button(
      function  = 'BACK'
      icon      = CONV #( icon_previous_object )
      text      = 'Back'
      quickinfo = 'Back'
      butn_type = 0 ) TO e_object->mt_toolbar.
  ENDMETHOD.
  METHOD handle_parts_command.
    CASE e_ucomm.
      WHEN 'BACK'.
        CHECK mt_parts_backup IS NOT INITIAL.
        mt_parts = mt_parts_backup.
        CLEAR: mt_parts_backup, mv_drilled_class.
        refresh_parts( ).
      WHEN OTHERS.
        " pass other commands to toolbar handler (REFRESH etc.)
        on_toolbar_click( fcode = e_ucomm ).
    ENDCASE.
  ENDMETHOD.
  METHOD handle_parts_dblclick.
    DATA(lv_row) = es_row_no-row_id.
    READ TABLE mt_parts INTO DATA(ls_part) INDEX lv_row.
    IF sy-subrc <> 0. RETURN. ENDIF.

    " ── CLAS row (from TR) ──────────────────────────────────────────
    IF ls_part-type = 'CLAS'.
      IF ls_part-exists_flag = abap_false.
        set_html(
          |<!DOCTYPE html><html><head><style>| &&
          |body\{font:13px/1.8 Consolas,sans-serif;background:#fff8f8;| &&
          |padding:24px;color:#333\}| &&
          |h3\{color:#c0392b;margin-bottom:8px\}| &&
          |.lbl\{color:#888;font-size:11px\}.val\{font-weight:bold\}| &&
          |</style></head><body>| &&
          |<h3>&#9888; Object not found in system</h3>| &&
          |<p><span class="lbl">Type:</span> <span class="val">CLAS</span></p>| &&
          |<p><span class="lbl">Name:</span> | &&
          |<span class="val">{ ls_part-object_name }</span></p>| &&
          |</body></html>| ).
      ELSE.
        mt_parts_backup = mt_parts.
        mv_drilled_class = ls_part-object_name.
        CLEAR mt_parts.
        TRY.
            mt_parts = get_class_parts( i_name = ls_part-object_name ).
          CATCH zcx_ave.
        ENDTRY.
        refresh_parts( ).
        " Auto-open first part
        READ TABLE mt_parts INTO DATA(ls_first_part) INDEX 1.
        IF sy-subrc = 0.
          mv_cur_objtype = ls_first_part-type.
          mv_cur_objname = ls_first_part-object_name.
          load_versions( i_objtype = ls_first_part-type i_objname = ls_first_part-object_name ).
          refresh_vers( ).
          IF mt_versions IS NOT INITIAL.
            ms_base_ver = mt_versions[ 1 ].
            mv_viewed_versno = ms_base_ver-versno.
            IF mv_show_diff = abap_true.
              READ TABLE mt_versions INTO DATA(ls_prev_cls) INDEX 2.
              IF sy-subrc = 0.
                auto_show_diff_or_source( is_old = ls_prev_cls is_new = ms_base_ver ).
              ELSE.
                show_source( i_objtype = ms_base_ver-objtype
                             i_objname = ms_base_ver-objname
                             i_versno  = ms_base_ver-versno ).
              ENDIF.
            ELSE.
              show_source( i_objtype = ms_base_ver-objtype
                           i_objname = ms_base_ver-objname
                           i_versno  = ms_base_ver-versno ).
            ENDIF.
            update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
          ENDIF.
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    " ── Unsupported object type ───────────────────────────────────
    DATA(lt_supported) = VALUE string_table(
      ( |REPS| ) ( |METH| ) ( |CLSD| ) ( |CPUB| ) ( |CPRO| )
      ( |CPRI| ) ( |CINC| ) ( |CDEF| ) ( |FUNC| ) ).
    IF NOT line_exists( lt_supported[ table_line = ls_part-type ] ).
      set_html(
        |<html><body style="font:13px Consolas,sans-serif;| &&
        |padding:24px;color:#666">| &&
        |<h3 style="color:#888">&#128683; Not supported</h3>| &&
        |<p>This object type is not supported at the moment.</p>| &&
        |<p style="color:#aaa">Type: { ls_part-type }</p>| &&
        |</body></html>| ).
      RETURN.
    ENDIF.

    mv_cur_objtype = ls_part-type.
    mv_cur_objname = ls_part-object_name.

    " ── Object doesn't exist in system ────────────────────────────
    IF ls_part-exists_flag = abap_false.

      " Find last known version date from VRSD
      DATA lv_last_date TYPE versdate.
      DATA lv_last_time TYPE verstime.
      DATA lv_last_auth TYPE versuser.

      SELECT SINGLE datum, zeit, author
        FROM vrsd
        WHERE objtype = @ls_part-type
          AND objname = @ls_part-object_name
"ORDER BY datum DESCENDING, zeit DESCENDING

        INTO (@lv_last_date, @lv_last_time, @lv_last_auth)
        .

      DATA(lv_last_info) = COND string(
        WHEN sy-subrc = 0
        THEN |Last version: { lv_last_date } { lv_last_time } by { lv_last_auth }|
        ELSE |No version history found| ).

      set_html(
        |<!DOCTYPE html><html><head><style>| &&
        |body\{font:13px/1.8 Consolas,sans-serif;background:#fff8f8;| &&
        |padding:24px;color:#333\}| &&
        |h3\{color:#c0392b;margin-bottom:8px\}| &&
        |.lbl\{color:#888;font-size:11px\}| &&
        |.val\{font-weight:bold\}| &&
        |</style></head><body>| &&
        |<h3>&#9888; Object not found in system</h3>| &&
        |<p><span class="lbl">Type:</span> | &&
        |<span class="val">{ ls_part-type }</span></p>| &&
        |<p><span class="lbl">Name:</span> | &&
        |<span class="val">{ ls_part-object_name }</span></p>| &&
        |<p><span class="lbl">{ lv_last_info }</span></p>| &&
        |<p style="margin-top:12px;color:#888;font-size:11px">| &&
        |Previous versions are listed below — | &&
        |double-click to view historical source.</p>| &&
        |</body></html>| ).
      RETURN.
    ENDIF.

    " ── Object exists: normal flow ─────────────────────────────────
    load_versions( i_objtype = ls_part-type i_objname = ls_part-object_name ).

    " Newest version becomes base automatically
    CLEAR ms_base_ver.
    CLEAR mv_viewed_versno.
    IF mt_versions IS NOT INITIAL.
      ms_base_ver      = mt_versions[ 1 ].
      mv_viewed_versno = ms_base_ver-versno.
    ENDIF.

    update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
    refresh_vers( ).

    " Automatically open the latest version
    IF mt_versions IS NOT INITIAL.
      IF mv_show_diff = abap_true.
        READ TABLE mt_versions INTO DATA(ls_prev_part) INDEX 2.
        IF sy-subrc = 0.
          auto_show_diff_or_source( is_old = ls_prev_part is_new = ms_base_ver ).
        ELSE.
          show_source( i_objtype = ms_base_ver-objtype
                       i_objname = ms_base_ver-objname
                       i_versno  = ms_base_ver-versno ).
        ENDIF.
      ELSE.
        show_source( i_objtype = ms_base_ver-objtype
                     i_objname = ms_base_ver-objname
                     i_versno  = ms_base_ver-versno ).
      ENDIF.
    ENDIF.
  ENDMETHOD.
  METHOD load_versions.
    IF mv_task_view = abap_true.
      load_versions_task_view( i_objtype = i_objtype i_objname = i_objname ).
      RETURN.
    ENDIF.
    CLEAR mt_versions.

    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd(
          type      = i_objtype
          name      = i_objname
          no_toc    = mv_no_toc
          date_from = mv_date_from ).
      CATCH zcx_ave.
        RETURN.
    ENDTRY.

    LOOP AT lo_vrsd->vrsd_list INTO DATA(ls_vrsd).
      TRY.
          DATA(lo_ver) = NEW zcl_ave_version( ls_vrsd ).
          APPEND VALUE ty_version_row(
            versno         = lo_ver->version_number
            versno_text    = COND #( WHEN lo_ver->version_number = '99998'
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
            objname        = lo_ver->objname ) TO mt_versions.
        CATCH zcx_ave.
          " Skip version if metadata fails
      ENDTRY.
    ENDLOOP.

    SORT mt_versions BY versno DESCENDING datum DESCENDING zeit DESCENDING.

    " Rename versno_text for duplicate special versions (keep newest as-is)
    DATA lv_seen_active   TYPE abap_bool.
    DATA lv_seen_modified TYPE abap_bool.
    DATA lv_active_idx    TYPE i VALUE 1.
    DATA lv_modified_idx  TYPE i VALUE 1.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<vr>).
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

    IF mv_remove_dup = abap_true.
      zcl_ave_popup_data=>remove_duplicate_versions( CHANGING ct_versions = mt_versions ).
    ENDIF.

    " Strategy:
    "   1. Collect all unique (E071 type, E071 name) pairs from the versions.
    "   2. Fetch ALL type-S tasks that touch any of those objects in one SELECT.
    "   3. For each version: nearest task by date+time from the pre-fetched list
    "      (filtered to the version's object).
    " VRSD type (REPS/METH/CLSD/CPUB…) differs from E071 type (PROG/CLAS…),
    " so we map first.
    TYPES: BEGIN OF ty_task_candidate,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
             trkorr   TYPE trkorr,
             as4user  TYPE as4user,
             as4date  TYPE as4date,
             as4time  TYPE as4time,
           END OF ty_task_candidate.
    DATA lt_all_tasks TYPE STANDARD TABLE OF ty_task_candidate.

    TYPES: BEGIN OF ty_obj_key,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
           END OF ty_obj_key.
    DATA lt_keys TYPE SORTED TABLE OF ty_obj_key WITH UNIQUE KEY object obj_name.
    " Also: remember the mapped (type, name) per version to avoid recomputing
    TYPES: BEGIN OF ty_ver_key,
             idx      TYPE i,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
           END OF ty_ver_key.
    DATA lt_ver_keys TYPE TABLE OF ty_ver_key.

    DATA lv_trf_s TYPE e070-trfunction VALUE 'S'.

    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver>).
      " Map VRSD objtype → E071 transport object type
      DATA(lv_e071_type) = SWITCH e071-object( <ver>-objtype
        WHEN 'REPS' OR 'REPT' THEN 'PROG'
        WHEN 'CINC' OR 'CLSD' OR
             'CPUB' OR 'CPRO' OR 'CPRI' THEN 'CLAS'
        ELSE <ver>-objtype ).
      " Derive E071 obj_name. METH: as-is (class-pad-method). Others: strip '=' suffix.
      DATA(lv_e071_name) = CONV versobjnam( <ver>-objname ).
      CASE <ver>-objtype.
        WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'REPT'.
          DATA(lv_eq) = find( val = lv_e071_name sub = '=' ).
          IF lv_eq > 0.
            lv_e071_name = lv_e071_name(lv_eq).
          ENDIF.
      ENDCASE.

      INSERT VALUE #( object = lv_e071_type obj_name = lv_e071_name ) INTO TABLE lt_keys.
      APPEND VALUE #( idx      = sy-tabix
                      object   = lv_e071_type
                      obj_name = lv_e071_name ) TO lt_ver_keys.
    ENDLOOP.

    " One SELECT across all object keys for all type-S tasks
    IF lt_keys IS NOT INITIAL.
      SELECT e071~object, e071~obj_name,
             e070~trkorr, e070~as4user, e070~as4date, e070~as4time
        FROM e071
        INNER JOIN e070 ON e070~trkorr = e071~trkorr
        FOR ALL ENTRIES IN @lt_keys
        WHERE e071~object     = @lt_keys-object
          AND e071~obj_name   = @lt_keys-obj_name
          AND e070~trfunction = @lv_trf_s
        INTO TABLE @lt_all_tasks.
    ENDIF.

    " For each version: nearest task by date+time from the pre-fetched list
    LOOP AT mt_versions ASSIGNING <ver>.
      READ TABLE lt_ver_keys ASSIGNING FIELD-SYMBOL(<vk>) INDEX sy-tabix.
      CHECK sy-subrc = 0.

      DATA lv_task_tr  TYPE trkorr.
      DATA lv_owner    TYPE versuser.
      DATA lv_min_diff TYPE i.
      CLEAR: lv_task_tr, lv_owner.
      lv_min_diff = 9999999.

      LOOP AT lt_all_tasks INTO DATA(ls_cand)
           WHERE object   = <vk>-object
             AND obj_name = <vk>-obj_name.
        DATA(lv_diff) = abs( ( <ver>-datum - ls_cand-as4date ) * 86400
                           + ( <ver>-zeit  - ls_cand-as4time ) ).
        IF lv_diff < lv_min_diff.
          lv_min_diff = lv_diff.
          lv_task_tr  = ls_cand-trkorr.
          lv_owner    = ls_cand-as4user.
        ENDIF.
      ENDLOOP.

      IF lv_task_tr IS NOT INITIAL.
        <ver>-task           = lv_task_tr.
        <ver>-obj_owner      = lv_owner.
        <ver>-obj_owner_name = zcl_ave_popup_data=>get_user_name( lv_owner ).
      ENDIF.
    ENDLOOP.

    " Fill request description from E07T
    DATA lv_korr_text TYPE e07t-as4text.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver2>).
      CHECK <ver2>-korrnum IS NOT INITIAL.
      SELECT SINGLE as4text FROM e07t
        WHERE trkorr = @<ver2>-korrnum
          AND langu  = @sy-langu
        INTO @lv_korr_text.
      <ver2>-korr_text = lv_korr_text.
    ENDLOOP.
  ENDMETHOD.
  METHOD switch_pane_layout.
    IF mv_two_pane = abap_true.
      mo_split_wrap->set_row_height( id = 1 height = 0 ).
      mo_split_wrap->set_row_height( id = 2 height = 100 ).
      mo_cont_parts = mo_cont_parts_2p.
      mo_cont_vers  = mo_cont_vers_2p.
      mo_cont_html  = mo_cont_html_2p.
    ELSE.
      mo_split_wrap->set_row_height( id = 1 height = 100 ).
      mo_split_wrap->set_row_height( id = 2 height = 0 ).
      mo_cont_parts = mo_split_top->get_container( row = 1 column = 1 ).
      mo_cont_vers  = mo_split_top->get_container( row = 2 column = 1 ).
      mo_cont_html  = mo_split_main->get_container( row = 1 column = 2 ).
    ENDIF.
    FREE mo_alv_parts.
    FREE mo_alv_vers.
    FREE mo_code_viewer.
    FREE mo_html.
    FREE mo_split_html.
    create_parts_alv( ).
    create_versions_alv( ).
    create_html_viewer( ).
    IF mt_versions IS NOT INITIAL.
      update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
      IF mv_viewed_versno IS NOT INITIAL.
        READ TABLE mt_versions INTO DATA(ls_v) WITH KEY versno = mv_viewed_versno.
        IF sy-subrc = 0.
          IF mv_show_diff = abap_true.
            show_versions_diff( is_old = ls_v is_new = ms_base_ver ).
          ELSE.
            show_source( i_objtype = ls_v-objtype i_objname = ls_v-objname i_versno = ls_v-versno ).
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.
  METHOD refresh_parts.
    CHECK mv_refreshing = abap_false.
    mv_refreshing = abap_true.
    DATA ls_layo_p TYPE lvc_s_layo.
    mo_alv_parts->get_frontend_layout( IMPORTING es_layout = ls_layo_p ).
    ls_layo_p-cwidth_opt = abap_true.
    mo_alv_parts->set_frontend_layout( is_layout = ls_layo_p ).
    DATA ls_stbl_p TYPE lvc_s_stbl.
    ls_stbl_p-row = abap_true.
    ls_stbl_p-col = abap_true.
    mo_alv_parts->refresh_table_display( is_stable = ls_stbl_p ).
    mo_alv_parts->set_toolbar_interactive( ).
    mv_refreshing = abap_false.
  ENDMETHOD.
  METHOD refresh_vers.
    CHECK mv_refreshing = abap_false.
    mv_refreshing = abap_true.
    DATA ls_layo_v TYPE lvc_s_layo.
    mo_alv_vers->get_frontend_layout( IMPORTING es_layout = ls_layo_v ).
    ls_layo_v-cwidth_opt = abap_true.
    mo_alv_vers->set_frontend_layout( is_layout = ls_layo_v ).
    DATA ls_stbl TYPE lvc_s_stbl.
    ls_stbl-row = abap_true.
    ls_stbl-col = abap_true.
    mo_alv_vers->refresh_table_display( is_stable = ls_stbl ).
    mv_refreshing = abap_false.
  ENDMETHOD.
  METHOD update_ver_colors.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<v>).
      IF <v>-versno = ms_base_ver-versno.
        <v>-rowcolor = 'C510'.  " green = base
      ELSEIF <v>-versno = iv_viewed_versno AND iv_viewed_versno <> ms_base_ver-versno.
        <v>-rowcolor = 'C710'.  " blue = currently viewed
      ELSE.
        CLEAR <v>-rowcolor.
      ENDIF.
    ENDLOOP.
    refresh_vers( ).
  ENDMETHOD.
  METHOD load_versions_task_view.
    CLEAR mt_versions.

    " Use zcl_ave_vrsd — same source as TR view, includes Active/Modified
    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd(
          type              = i_objtype
          name              = i_objname
          ignore_unreleased = abap_false
          no_toc            = mv_no_toc ).
      CATCH zcx_ave.
        RETURN.
    ENDTRY.

    LOOP AT lo_vrsd->vrsd_list INTO DATA(ls_v).
      DATA ls_row TYPE ty_version_row.
      ls_row-versno  = zcl_ave_versno=>to_external( ls_v-versno ).
      ls_row-versno_text = COND string(
        WHEN ls_row-versno = zcl_ave_version=>c_version-active   THEN 'Active'
        WHEN ls_row-versno = zcl_ave_version=>c_version-modified THEN 'Modified'
        ELSE CONV string( ls_row-versno + 0 ) ).
      ls_row-datum   = ls_v-datum.
      ls_row-zeit    = ls_v-zeit.
      ls_row-author  = ls_v-author.
      ls_row-objtype = i_objtype.
      ls_row-objname = i_objname.

      " Find task and request — always fallback to VRSD data if lookup fails
      ls_row-korrnum = ls_v-korrnum.
      IF ls_v-korrnum IS NOT INITIAL.
        TRY.
            DATA ls_e070 TYPE e070.
            DATA lv_trf  TYPE e070-trfunction VALUE 'S'.
            SELECT SINGLE * FROM e070
              WHERE trkorr = @ls_v-korrnum
              INTO @ls_e070.
            IF ls_e070-trfunction = lv_trf.
              " korrnum IS the task
              ls_row-task    = ls_v-korrnum.
              ls_row-korrnum = ls_e070-strkorr.
              ls_row-author  = ls_e070-as4user.
            ELSE.
              " korrnum is the request — find task via E071 → E070
              SELECT SINGLE e070~trkorr, e070~as4user
                FROM e071
                INNER JOIN e070 ON e070~trkorr    = e071~trkorr
                WHERE e071~object    = @i_objtype
                  AND e071~obj_name  = @i_objname
                  AND e070~trfunction = @lv_trf
                  AND e070~strkorr   = @ls_v-korrnum
                INTO ( @ls_row-task, @ls_row-author ).
              IF sy-subrc <> 0.
                ls_row-author = ls_v-author.
              ENDIF.
            ENDIF.

            SELECT SINGLE as4text FROM e07t
              WHERE trkorr = @ls_row-korrnum AND langu = @sy-langu
              INTO @ls_row-korr_text.
          CATCH cx_root. " fallback: keep VRSD author, no task
            ls_row-author = ls_v-author.
        ENDTRY.
      ENDIF.

      ls_row-author_name = zcl_ave_popup_data=>get_user_name( ls_row-author ).

      APPEND ls_row TO mt_versions.
      CLEAR: ls_row, ls_e070.
    ENDLOOP.

    SORT mt_versions BY versno DESCENDING datum DESCENDING zeit DESCENDING.

    IF mv_remove_dup = abap_true.
      zcl_ave_popup_data=>remove_duplicate_versions( CHANGING ct_versions = mt_versions ).
    ENDIF.
  ENDMETHOD.
  METHOD handle_vers_toolbar.
    CLEAR e_object->mt_toolbar.
    APPEND VALUE stb_button(
      function  = 'DIFF_MODE_TOGGLE'
      icon      = CONV #( icon_compare )
      text      = COND #( WHEN mv_diff_prev = abap_true THEN 'Diff prev' ELSE 'Diff any' )
      quickinfo = 'Switch diff mode: compare with previous or any base'
      butn_type = 0 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar. " separator
    IF mv_diff_prev = abap_false.
      APPEND VALUE stb_button(
        function  = 'SET_BASE'
        icon      = CONV #( icon_header )
        text      = 'Set Base'
        quickinfo = 'Set selected version as base'
        butn_type = 0 ) TO e_object->mt_toolbar.
    ENDIF.
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar. " separator
    APPEND VALUE stb_button(
      function  = 'TOC_TOGGLE'
      icon      = CONV #( icon_list )
      text      = COND #( WHEN mv_no_toc = abap_true THEN 'TOCs off' ELSE 'TOCs on' )
      quickinfo = 'Toggle TOC versions'
      butn_type = 0 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button(
      function  = 'DUP_TOGGLE'
      icon      = CONV #( icon_overview )
      text      = COND #( WHEN mv_remove_dup = abap_true THEN 'Dups off' ELSE 'Dups on' )
      quickinfo = 'Toggle duplicate versions'
      butn_type = 0 ) TO e_object->mt_toolbar.
  ENDMETHOD.
  METHOD handle_vers_command.
    CASE e_ucomm.
      WHEN 'DIFF_MODE_TOGGLE'.
        mv_diff_prev = COND #( WHEN mv_diff_prev = abap_true THEN abap_false ELSE abap_true ).
        refresh_vers( ).

      WHEN 'TOC_TOGGLE'.
        mv_no_toc = COND #( WHEN mv_no_toc = abap_true THEN abap_false ELSE abap_true ).
        load_versions( i_objtype = mv_cur_objtype i_objname = mv_cur_objname ).
        refresh_vers( ).

      WHEN 'DUP_TOGGLE'.
        mv_remove_dup = COND #( WHEN mv_remove_dup = abap_true THEN abap_false ELSE abap_true ).
        load_versions( i_objtype = mv_cur_objtype i_objname = mv_cur_objname ).
        refresh_vers( ).

      WHEN 'SET_BASE'.
        DATA lt_rows TYPE lvc_t_row.
        mo_alv_vers->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
        CHECK lines( lt_rows ) = 1.
        ms_base_ver = mt_versions[ lt_rows[ 1 ]-index ].
        IF mv_viewed_versno IS NOT INITIAL AND mv_show_diff = abap_true.
          READ TABLE mt_versions INTO DATA(ls_viewed) WITH KEY versno = mv_viewed_versno.
          IF sy-subrc = 0.
            show_versions_diff( is_old = ls_viewed is_new = ms_base_ver ).
          ENDIF.
        ENDIF.
        update_ver_colors( iv_viewed_versno = mv_viewed_versno ).

      WHEN OTHERS.
        on_toolbar_click( fcode = e_ucomm ).
    ENDCASE.
  ENDMETHOD.
  METHOD handle_vers_dblclick.
    DATA(lv_row) = es_row_no-row_id.
    READ TABLE mt_versions INTO DATA(ls_ver) INDEX lv_row.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mv_viewed_versno = ls_ver-versno.

    IF mv_show_diff = abap_true.
      IF mv_diff_prev = abap_true.
        " Diff prev mode: clicked = new, next in list = old (previous chronologically)
        READ TABLE mt_versions INTO DATA(ls_prev) INDEX lv_row + 1.
        IF sy-subrc = 0.
          ms_base_ver = ls_ver.
          show_versions_diff( is_old = ls_prev is_new = ls_ver ).
        ELSE.
          show_source( i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno ).
        ENDIF.
      ELSE.
        " Diff any mode: compare with manually chosen base
        IF ls_ver-versno = ms_base_ver-versno.
          READ TABLE mt_versions INTO DATA(ls_prev_base) INDEX lv_row + 1.
          IF sy-subrc = 0.
            show_versions_diff( is_old = ls_prev_base is_new = ls_ver ).
          ELSE.
            show_source( i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno ).
          ENDIF.
        ELSE.
          show_versions_diff( is_old = ls_ver is_new = ms_base_ver ).
        ENDIF.
      ENDIF.
    ELSE.
      show_source( i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno ).
    ENDIF.

    update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
  ENDMETHOD.
  METHOD show_source.
    IF mo_box IS BOUND.
      DATA lv_vtxt TYPE string.
      READ TABLE mt_versions INTO DATA(ls_vcap) WITH KEY versno = i_versno.
      lv_vtxt = COND #( WHEN sy-subrc = 0 THEN ls_vcap-versno_text ELSE CONV string( i_versno ) ).
      DATA(lv_vlbl) = COND string( WHEN lv_vtxt CA '0123456789' AND lv_vtxt NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                                   THEN |v{ lv_vtxt }| ELSE lv_vtxt ).
      DATA(lv_extra) = COND string(
        WHEN i_objname IS NOT INITIAL AND ( i_objname <> mv_object_name )
        THEN | – { i_objtype }: { i_objname }| ELSE `` ).
      mo_box->set_caption( |{ mv_object_type }: { mv_object_name }{ lv_extra }  [{ lv_vlbl }]| ).
    ENDIF.
    TRY.
        " Find VRSD row for this version
        DATA lt_vrsd TYPE vrsd_tab.
        DATA(lv_db_versno) = zcl_ave_versno=>to_internal( i_versno ).
        SELECT * FROM vrsd
          WHERE objtype = @i_objtype
            AND objname = @i_objname
            AND versno  = @lv_db_versno
            INTO TABLE @lt_vrsd
          UP TO 1 ROWS.

        DATA ls_vrsd TYPE vrsd.
        IF lt_vrsd IS NOT INITIAL.
          ls_vrsd = lt_vrsd[ 1 ].
        ELSE.
          " Active/Modified: get timestamp from already-loaded version data
          ls_vrsd-objtype = i_objtype.
          ls_vrsd-objname = i_objname.
          ls_vrsd-versno  = lv_db_versno.
          READ TABLE mt_versions INTO DATA(ls_ver_row)
            WITH KEY versno = i_versno objtype = i_objtype objname = i_objname.
          IF sy-subrc = 0.
            ls_vrsd-author = ls_ver_row-author.
            ls_vrsd-datum  = ls_ver_row-datum.
            ls_vrsd-zeit   = ls_ver_row-zeit.
          ELSE.
            ls_vrsd-author = sy-uname.
          ENDIF.
        ENDIF.

        DATA(lo_ver)    = NEW zcl_ave_version( ls_vrsd ).
        DATA(lt_source) = lo_ver->get_source( ).

        " ABAP editor handles 100k+ line sources much faster than HTML.
        " Version metadata stays visible in the dialog caption + version list.
        show_code_source( it_source = lt_source ).

      CATCH zcx_ave.
        set_html(
          |<html><body style="background:#1e1e1e;color:#f55;| &&
          |font-family:Consolas;padding:20px">| &&
          |Error loading source.</body></html>| ).
    ENDTRY.
  ENDMETHOD.
  METHOD show_code_source.
    IF mo_code_viewer IS BOUND.
      DATA lt_src TYPE STANDARD TABLE OF char255.
      LOOP AT it_source INTO DATA(ls_line).
        APPEND CONV char255( ls_line ) TO lt_src.
      ENDLOOP.
      mo_code_viewer->set_text( table = lt_src ).
      mo_code_viewer->set_readonly_mode( 1 ).
      IF mo_split_html IS BOUND.
        mo_split_html->set_row_height( id = 1 height = 0 ).
        mo_split_html->set_row_height( id = 2 height = 100 ).
      ENDIF.
      cl_gui_cfw=>flush( ).
    ENDIF.
  ENDMETHOD.
  METHOD set_html.
    mv_last_html = iv_html.
    " Previous call may have swapped to the ABAP editor — bring HTML back.
    IF mo_split_html IS BOUND.
      mo_split_html->set_row_height( id = 1 height = 100 ).
      mo_split_html->set_row_height( id = 2 height = 0 ).
    ENDIF.
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

    mo_html->load_data(
      IMPORTING assigned_url = lv_url
      CHANGING  data_table   = lt_html
      EXCEPTIONS OTHERS      = 1 ).

    mo_html->show_url( url = lv_url ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.
  METHOD get_class_parts.
    DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
      object_type = zcl_ave_object_factory=>gc_type-class
      object_name = CONV #( i_name ) ).
    LOOP AT lo_obj->get_parts( ) INTO DATA(ls_part).
      CHECK ls_part-type <> 'CLSD' AND ls_part-type <> 'RELE'.
      IF ls_part-type <> 'METH'.
        CHECK zcl_ave_popup_data=>check_part_exists(
                     i_type       = ls_part-type
                     i_name       = CONV #( ls_part-object_name ) ).

      ENDIF.
      DATA ls_part_row TYPE ty_part_row.
      CLEAR ls_part_row.
      ls_part_row-class       = ls_part-class.
      ls_part_row-name        = ls_part-unit.
      ls_part_row-type        = ls_part-type.
      ls_part_row-type_text   = zcl_ave_popup_data=>get_type_text( ls_part-type ).
      ls_part_row-object_name = ls_part-object_name.
      ls_part_row-exists_flag = abap_true.
      ls_part_row-rows        = zcl_ave_popup_data=>get_active_line_count(
                                  i_type = ls_part-type i_name = ls_part-object_name ).
      IF mv_filter_user IS NOT INITIAL.
        IF zcl_ave_popup_data=>is_substantive_user_change(
             i_type = ls_part-type i_name = ls_part-object_name i_user = mv_filter_user ) = abap_true.
          ls_part_row-rowcolor = 'C510'. " green
        ENDIF.
      ENDIF.
      APPEND ls_part_row TO result.
    ENDLOOP.
  ENDMETHOD.
  METHOD on_toolbar_click.
    CASE fcode.
      WHEN 'INFO'.
        DATA(l_url) = 'https://github.com/ysichov/AVE'.
        CALL FUNCTION 'CALL_BROWSER' EXPORTING url = l_url.

      WHEN 'BACK'.
        CHECK mt_parts_backup IS NOT INITIAL.
        mt_parts = mt_parts_backup.
        CLEAR: mt_parts_backup, mv_drilled_class.
        refresh_parts( ).

      WHEN 'REFRESH'.
        " Reload parts
        CLEAR mt_parts.
        TRY.
            IF mv_drilled_class IS NOT INITIAL.
              " Drilled into a class from a TR parts view — refresh only this class.
              mt_parts = get_class_parts( mv_drilled_class ).
            ELSEIF mv_object_type = zcl_ave_object_factory=>gc_type-class.
              mt_parts = get_class_parts( CONV #( mv_object_name ) ).
            ELSE.
              DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
                object_type = mv_object_type
                object_name = CONV #( mv_object_name ) ).
              DATA(lv_is_tr) = boolc( mv_object_type = zcl_ave_object_factory=>gc_type-tr ).
              LOOP AT lo_obj->get_parts( ) INTO DATA(ls_raw).
                DATA(lv_exists) = COND abap_bool(
                  WHEN lv_is_tr = abap_true
                  THEN zcl_ave_popup_data=>check_part_exists(
                         i_type       = ls_raw-type
                         i_name       = ls_raw-object_name
                         i_class_name = CONV #( ls_raw-class ) )
                  ELSE abap_true ).
                DATA ls_row TYPE ty_part_row.
                ls_row-class       = ls_raw-class.
                ls_row-name        = ls_raw-unit.
                ls_row-type        = ls_raw-type.
                ls_row-type_text   = zcl_ave_popup_data=>get_type_text( ls_raw-type ).
                ls_row-object_name = ls_raw-object_name.
                ls_row-exists_flag = lv_exists.
                ls_row-rows        = COND i( WHEN lv_exists = abap_true
                  THEN zcl_ave_popup_data=>get_active_line_count( i_type = ls_raw-type i_name = ls_raw-object_name )
                  ELSE 0 ).
                IF lv_exists = abap_false.
                  ls_row-rowcolor = 'C610'.   " red
                ELSEIF mv_filter_user IS NOT INITIAL.
                  DATA(lv_umatch) = COND abap_bool(
                    WHEN ls_raw-type = 'CLAS'
                    THEN zcl_ave_popup_data=>check_class_has_author( i_class_name = CONV #( ls_raw-object_name ) i_user = mv_filter_user )
                    ELSE zcl_ave_popup_data=>is_substantive_user_change(
                           i_type = ls_raw-type i_name = ls_raw-object_name i_user = mv_filter_user ) ).
                  IF lv_umatch = abap_true.
                    ls_row-rowcolor = 'C510'. " green
                  ENDIF.
                ENDIF.
                APPEND ls_row TO mt_parts.
                CLEAR ls_row.
              ENDLOOP.
            ENDIF.
          CATCH zcx_ave.
        ENDTRY.
        refresh_parts( ).
        " Reload versions for current part if one was selected
        IF mv_cur_objtype IS NOT INITIAL.
          load_versions( i_objtype = mv_cur_objtype i_objname = mv_cur_objname ).
          update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
        ENDIF.

      WHEN 'SET_BASE'.
        DATA lt_sel_base TYPE lvc_t_row.
        mo_alv_vers->get_selected_rows( IMPORTING et_index_rows = lt_sel_base ).
        CHECK lines( lt_sel_base ) = 1.
        ms_base_ver = mt_versions[ lt_sel_base[ 1 ]-index ].
        IF mv_viewed_versno IS NOT INITIAL AND mv_show_diff = abap_true.
          READ TABLE mt_versions INTO DATA(ls_viewed) WITH KEY versno = mv_viewed_versno.
          IF sy-subrc = 0.
            show_versions_diff( is_old = ls_viewed is_new = ms_base_ver ).
          ENDIF.
        ENDIF.
        update_ver_colors( iv_viewed_versno = mv_viewed_versno ).

      WHEN 'DIFF_TOGGLE'.
        mv_show_diff = COND #( WHEN mv_show_diff = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'DIFF_TOGGLE'
                    text  = COND #( WHEN mv_show_diff = abap_true
                                    THEN 'Show Diff' ELSE 'Show Vers' )
                    icon  = COND #( WHEN mv_show_diff = abap_true
                                    THEN icon_compare ELSE icon_history ) ).
        IF mv_viewed_versno IS NOT INITIAL.
          READ TABLE mt_versions INTO DATA(ls_vw) WITH KEY versno = mv_viewed_versno.
          IF sy-subrc = 0.
            IF mv_show_diff = abap_true.
              " Restore last diff pair (ms_diff_old/new set by show_versions_diff)
              IF ms_diff_old IS NOT INITIAL OR ms_diff_new IS NOT INITIAL.
                show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
              ELSE.
                show_versions_diff( is_old = ls_vw is_new = ms_base_ver ).
              ENDIF.
            ELSE.
              show_source( i_objtype = ls_vw-objtype i_objname = ls_vw-objname i_versno = ls_vw-versno ).
            ENDIF.
          ENDIF.
        ENDIF.

      WHEN 'PANE_TOGGLE'.
        mv_two_pane = COND #( WHEN mv_two_pane = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'PANE_TOGGLE'
                    text  = COND #( WHEN mv_two_pane = abap_true
                                    THEN '2-Pane' ELSE 'Inline' )
                    icon  = COND #( WHEN mv_two_pane = abap_true
                                    THEN icon_view_hier_list ELSE icon_spool_request ) ).
        IF mv_viewed_versno IS NOT INITIAL AND mt_versions IS NOT INITIAL.
          READ TABLE mt_versions INTO DATA(ls_pv) WITH KEY versno = mv_viewed_versno.
          IF sy-subrc = 0.
            IF mv_show_diff = abap_true.
              IF ms_diff_old IS NOT INITIAL OR ms_diff_new IS NOT INITIAL.
                show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
              ELSE.
                show_versions_diff( is_old = ls_pv is_new = ms_base_ver ).
              ENDIF.
            ELSE.
              show_source( i_objtype = ls_pv-objtype i_objname = ls_pv-objname i_versno = ls_pv-versno ).
            ENDIF.
          ENDIF.
        ENDIF.

      WHEN 'COMPACT_TOGGLE'.
        mv_compact = COND #( WHEN mv_compact = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'COMPACT_TOGGLE'
                    text  = COND #( WHEN mv_compact = abap_true THEN 'Compact' ELSE 'Full' )
                    icon  = COND #( WHEN mv_compact = abap_true
                                    THEN icon_collapse_all ELSE icon_expand_all ) ).
        IF mv_show_diff = abap_true AND ms_diff_old IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ENDIF.

      WHEN 'BLAME_TOGGLE'.
        mv_blame = COND #( WHEN mv_blame = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'BLAME_TOGGLE'
                    text  = COND #( WHEN mv_blame = abap_true THEN 'Blame ON' ELSE 'Blame' )
                    icon  = CONV #( icon_history ) ).
        IF mv_show_diff = abap_true AND ms_diff_old IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ENDIF.

      WHEN 'DEBUG'.
        mv_debug = COND #( WHEN mv_debug = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'DEBUG'
                    text  = COND #( WHEN mv_debug = abap_true THEN 'Debug ON' ELSE 'Debug' )
                    icon  = CONV #( icon_bw_dm_aa ) ).
        " Re-render the current diff (if any) using the new mode
        IF mv_show_diff = abap_true AND ms_diff_old IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ENDIF.

      WHEN 'FOCUS_TOGGLE'.
        mv_focus_html = COND #( WHEN mv_focus_html = abap_true THEN abap_false ELSE abap_true ).
        mo_toolbar->set_button_info(
          EXPORTING fcode = 'FOCUS_TOGGLE'
                    text  = COND #( WHEN mv_focus_html = abap_true THEN 'Standard View' ELSE 'Maximize View' )
                    icon  = CONV #( icon_view_maximize ) ).
        IF mv_focus_html = abap_true.
          mo_split_2p_wrap->set_row_height( id = 1 height = 0 ).
          mo_split_2p_wrap->set_row_height( id = 2 height = 100 ).
          mo_split_2p_wrap->set_row_sash( id = 1 type = 0 value = 0 ).
        ELSE.
          mo_split_2p_wrap->set_row_height( id = 1 height = 35 ).
          mo_split_2p_wrap->set_row_height( id = 2 height = 65 ).
          mo_split_2p_wrap->set_row_sash( id = 1 type = 1 value = 0 ).
        ENDIF.

    ENDCASE.
  ENDMETHOD.
  METHOD on_box_close.
    sender->free( ).
    CLEAR mo_box.
  ENDMETHOD.
  METHOD auto_show_diff_or_source.
    DATA(lt_src) = zcl_ave_popup_data=>get_ver_source(
      i_objtype = is_new-objtype
      i_objname = is_new-objname
      i_versno  = is_new-versno
      i_korrnum = is_new-korrnum
      i_author  = is_new-author
      i_datum   = is_new-datum
      i_zeit    = is_new-zeit ).
    IF lines( lt_src ) > 1000.
      show_source( i_objtype = is_new-objtype
                   i_objname = is_new-objname
                   i_versno  = is_new-versno ).
    ELSE.
      show_versions_diff( is_old = is_old is_new = is_new ).
    ENDIF.
  ENDMETHOD.
  METHOD show_versions_diff.
    ms_diff_old = is_old.
    ms_diff_new = is_new.
    IF mo_box IS BOUND.
      DATA(lv_new_lbl) = COND string( WHEN is_new-versno_text CA '0123456789' AND is_new-versno_text NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                                      THEN |v{ is_new-versno_text }| ELSE is_new-versno_text ).
      DATA(lv_old_lbl) = COND string( WHEN is_old-versno_text CA '0123456789' AND is_old-versno_text NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                                      THEN |v{ is_old-versno_text }| ELSE is_old-versno_text ).
      DATA(lv_extra2) = COND string(
        WHEN is_new-objname IS NOT INITIAL AND is_new-objname <> mv_object_name
        THEN | – { is_new-objtype }: { is_new-objname }| ELSE `` ).
      mo_box->set_caption( |{ mv_object_type }: { mv_object_name }{ lv_extra2 }  [{ lv_new_lbl } -- { lv_old_lbl }]| ).
    ENDIF.
    TRY.
        DATA lt_vrsd_o TYPE vrsd_tab.
        DATA lt_vrsd_n TYPE vrsd_tab.
        DATA(lv_vno_o) = zcl_ave_versno=>to_internal( is_old-versno ).
        DATA(lv_vno_n) = zcl_ave_versno=>to_internal( is_new-versno ).
        SELECT * FROM vrsd WHERE objtype = @is_old-objtype AND objname = @is_old-objname
          AND versno = @lv_vno_o INTO TABLE @lt_vrsd_o UP TO 1 ROWS.
        SELECT * FROM vrsd WHERE objtype = @is_new-objtype AND objname = @is_new-objname
          AND versno = @lv_vno_n INTO TABLE @lt_vrsd_n UP TO 1 ROWS.
        IF lt_vrsd_o IS INITIAL.
          APPEND VALUE vrsd( objtype = is_old-objtype objname = is_old-objname
                             versno  = lv_vno_o       korrnum = is_old-korrnum
                             author  = is_old-author   datum   = is_old-datum
                             zeit    = is_old-zeit ) TO lt_vrsd_o.
        ENDIF.
        IF lt_vrsd_n IS INITIAL.
          APPEND VALUE vrsd( objtype = is_new-objtype objname = is_new-objname
                             versno  = lv_vno_n       korrnum = is_new-korrnum
                             author  = is_new-author   datum   = is_new-datum
                             zeit    = is_new-zeit ) TO lt_vrsd_n.
        ENDIF.
        DATA(lt_src_o) = NEW zcl_ave_version( lt_vrsd_o[ 1 ] )->get_source( ).
        DATA(lt_src_n) = NEW zcl_ave_version( lt_vrsd_n[ 1 ] )->get_source( ).
        DATA(lt_diff)  = zcl_ave_popup_diff=>compute_diff( it_old = lt_src_o it_new = lt_src_n ).
        DATA(lv_meta)  = |{ is_new-versno_text } → { is_old-versno_text }|.
        DATA lt_blame         TYPE ty_blame_map.
        DATA lt_blame_deleted TYPE ty_blame_map.
        IF mv_blame = abap_true.
          lt_blame = zcl_ave_popup_diff=>build_blame_map(
            EXPORTING it_versions      = mt_versions
                      i_objtype        = is_new-objtype
                      i_objname        = is_new-objname
                      i_from           = is_old-versno
                      i_to             = is_new-versno
            IMPORTING et_blame_deleted = lt_blame_deleted ).
        ENDIF.
        IF mv_debug = abap_true.
          set_html( zcl_ave_popup_html=>debug_diff_html(
            it_diff = lt_diff
            i_title = |{ is_new-objtype }: { is_new-objname }|
            i_meta  = lv_meta ) ).
        ELSE.
          set_html( zcl_ave_popup_html=>diff_to_html(
            it_diff          = lt_diff
            i_title          = |{ is_new-objtype }: { is_new-objname }|
            i_meta           = lv_meta
            i_two_pane       = mv_two_pane
            " Force compact for huge files — full view would render millions of rows.
            i_compact        = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                       THEN abap_true ELSE mv_compact )
            i_plain          = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                       THEN abap_true ELSE abap_false )
            it_blame         = lt_blame
            it_blame_deleted = lt_blame_deleted ) ).
        ENDIF.
      CATCH cx_root.
        set_html( |<html><body style="padding:24px;font:13px Consolas;color:#c00">| &&
          |Error loading versions for comparison.</body></html>| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

CLASS zcl_ave_object_tr IMPLEMENTATION.

  METHOD constructor.
    me->id = id.
  ENDMETHOD.

  METHOD get_object.
    TRY.
        result = COND #(
          " R3TR CLAS → single row (drill-in via double-click)
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'CLAS'
            THEN NEW zcl_ave_object_clas( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'INTF'
            THEN NEW zcl_ave_object_intf( CONV #( object_key-obj_name ) )
          " R3TR PROG → program
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'PROG'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) )
          " R3TR FUGR → function group main include
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
    LOOP AT get_object_keys( ) INTO DATA(key).
      IF key-pgmid = 'R3TR' AND ( key-object = 'CLAS' OR key-object = 'INTF' ).
        " CLAS/INTF is shown as a single row; double-click opens the object-level popup
        APPEND VALUE #(
          unit        = CONV string( key-obj_name )
          object_name = CONV versobjnam( key-obj_name )
          type        = CONV versobjtyp( key-object ) ) TO result.
      ELSEIF key-pgmid = 'LIMU' AND key-object = 'METH'.
        " METH: obj_name may be CLASSNAME\METHODNAME or just METHODNAME
        DATA lv_meth_cls  TYPE seoclsname.
        DATA lv_meth_name TYPE seocmpname.
        DATA lv_meth_raw  TYPE string.
        lv_meth_raw = key-obj_name.
        CONDENSE lv_meth_raw.
        SPLIT lv_meth_raw AT ` ` INTO DATA(lv_cls_part) DATA(lv_meth_part).
        lv_meth_cls  = lv_cls_part.
        lv_meth_name = lv_meth_part.
        APPEND VALUE #(
          class       = CONV string( lv_meth_cls )
          unit        = CONV string( lv_meth_name )
          object_name = CONV versobjnam( |{ lv_meth_cls WIDTH = 30 }{ lv_meth_name }| )
          type        = 'METH' ) TO result.
        CLEAR: lv_meth_cls, lv_meth_name, lv_meth_raw.
      ELSE.
        DATA(obj) = get_object( key ).
        IF obj IS BOUND.
          APPEND LINES OF obj->get_parts( ) TO result.
        ELSE.
          " Unknown/unsupported type — show as-is so it's not silently dropped
          APPEND VALUE #(
            unit        = CONV string( key-obj_name )
            object_name = CONV versobjnam( key-obj_name )
            type        = CONV versobjtyp( key-object ) ) TO result.
        ENDIF.
      ENDIF.
    ENDLOOP.
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
      unit        = CONV #( name )
      object_name = CONV #( name )
      type        = 'REPS' ) ).
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_object_pack IMPLEMENTATION.

  METHOD constructor.
    me->id = id.
  ENDMETHOD.

  METHOD get_object.
    TRY.
        result = COND #(
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'CLAS'
            THEN NEW zcl_ave_object_clas( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'INTF'
            THEN NEW zcl_ave_object_intf( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'PROG'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'FUGR'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'LIMU' AND object_key-object = 'FUNC'
            THEN NEW zcl_ave_object_func( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'LIMU' AND object_key-object = 'REPS'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) ) ).
      CATCH zcx_ave.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.

  METHOD get_object_keys.
    DATA lt_tadir TYPE STANDARD TABLE OF tadir.
    SELECT pgmid, object, obj_name FROM tadir
      WHERE devclass = @me->id
      INTO CORRESPONDING FIELDS OF TABLE @lt_tadir.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.
    LOOP AT lt_tadir INTO DATA(ls_tadir).
      APPEND VALUE trwbo_s_e071(
        pgmid    = ls_tadir-pgmid
        object   = ls_tadir-object
        obj_name = ls_tadir-obj_name ) TO result.
    ENDLOOP.
    SORT result BY pgmid ASCENDING object ASCENDING obj_name ASCENDING.
    DELETE ADJACENT DUPLICATES FROM result COMPARING pgmid object obj_name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    SELECT SINGLE devclass FROM tdevc WHERE devclass = @me->id INTO @DATA(lv_d).
    result = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = id.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    LOOP AT get_object_keys( ) INTO DATA(key).
      IF key-pgmid = 'R3TR' AND ( key-object = 'CLAS' OR key-object = 'INTF' ).
        APPEND VALUE #(
          unit        = CONV string( key-obj_name )
          object_name = CONV versobjnam( key-obj_name )
          type        = CONV versobjtyp( key-object ) ) TO result.
      ELSE.
        DATA(obj) = get_object( key ).
        IF obj IS BOUND.
          APPEND LINES OF obj->get_parts( ) TO result.
        ELSE.
          APPEND VALUE #(
            unit        = CONV string( key-obj_name )
            object_name = CONV versobjnam( key-obj_name )
            type        = CONV versobjtyp( key-object ) ) TO result.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_object_intf IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    SELECT SINGLE @abap_true INTO @result
      FROM seoclass
      WHERE clsname = @name
        AND clstype = '1'.
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    " Interface source is stored in a generated include; versions are
    " accessible via SVRS with objtype = 'REPS'.
    DATA lv_incname TYPE program.
    TRY.
        lv_incname = cl_oo_classname_service=>get_intfsec_name( name ).
      CATCH cx_root.
        lv_incname = name.
    ENDTRY.

    result = VALUE #( (
      unit        = CONV #( name )
      object_name = CONV #( lv_incname )
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
      unit        = CONV #( name )
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
      WHEN gc_type-intf     THEN NEW zcl_ave_object_intf( CONV #( object_name ) )
      WHEN gc_type-function THEN NEW zcl_ave_object_func( CONV #( object_name ) )
      WHEN gc_type-tr       THEN NEW zcl_ave_object_tr(   CONV #( object_name ) )
      WHEN gc_type-package  THEN NEW zcl_ave_object_pack( CONV #( object_name ) ) ).

    IF result IS NOT BOUND OR result->check_exists( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS ZCL_AVE_OBJECT_CLAS IMPLEMENTATION.
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
      ( class = name unit = 'Class pool'                 object_name = CONV #( name )                                  type = 'CLSD' )
      ( class = name unit = 'Public section'             object_name = CONV #( name )                                  type = 'CPUB' )
      ( class = name unit = 'Protected section'          object_name = CONV #( name )                                  type = 'CPRO' )
      ( class = name unit = 'Private section'            object_name = CONV #( name )                                  type = 'CPRI' )
      ( class = name unit = 'Local class definition'     object_name = CONV #( cl_oo_classname_service=>get_ccdef_name( name ) ) type = 'CDEF' )
      ( class = name unit = 'Local class implementation' object_name = CONV #( cl_oo_classname_service=>get_ccimp_name( name ) ) type = 'CINC' )
      ( class = name unit = 'Local macros'               object_name = CONV #( cl_oo_classname_service=>get_ccmac_name( name ) ) type = 'CINC' )
      ( class = name unit = 'Local types'                object_name = CONV #( cl_oo_classname_service=>get_cl_name( name ) )    type = 'REPS' )
      ( class = name unit = 'Test classes'               object_name = CONV #( cl_oo_classname_service=>get_ccau_name( name ) )  type = 'CINC' ) ).

    " One entry per method

CALL METHOD cl_oo_classname_service=>get_all_method_includes
  EXPORTING
    clsname            = name " Имя вашего класса
  RECEIVING
    result             = data(lt_meth)
  EXCEPTIONS
    class_not_existing = 1.

IF sy-subrc = 0.

    LOOP AT cl_oo_classname_service=>get_all_method_includes( name ) INTO DATA(method_include).
*      TRY.
*          "DATA(method_name) = cl_oo_classname_service=>get_method_by_include( method_include-incname  )-cpdname.
*          "data: method_name TYPE SEOP_METHODS_W_INCLUDE.
**          CALL METHOD cl_oo_classname_service=>get_all_method_includes
**  EXPORTING
**    clsname             = name
**  RECEIVING
**    result              = data(method_name)
**  EXCEPTIONS
**    class_not_existing  = 1.
*
*        CATCH cx_root.
*          CONTINUE.
*      ENDTRY.
      APPEND VALUE #( class = name
                      unit        = |{ method_include-cpdkey-cpdname }|
                      object_name = CONV versobjnam( |{ name WIDTH = 30 }{ method_include-cpdkey-cpdname }| )
                      type        = 'METH' ) TO result.
    ENDLOOP.
    ENDIF.
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

" & Multi-windows program for ABAP object version comparison
" &----------------------------------------------------------------------
" & version: beta 0.99
" & Git https://github.com/ysichov/AVE

" & Written by Yurii Sychov
" & e-mail:   ysichov@gmail.com
" & blog:     https://ysychov.wordpress.com/blog/
" & LinkedIn: https://www.linkedin.com/in/ysychov/

" &Inspired by https://github.com/abapinho/abapTimeMachine , Eclipse Adt, GitHub and all others similar tools
" &----------------------------------------------------------------------

" Global reference keeps the popup object (and its event handlers) alive
" while the selection screen is active. Without this the object would be
" garbage-collected as soon as FORM run_ave returns.
DATA go_popup TYPE REF TO zcl_ave_popup.

"======================================================================
" Selection screen
"======================================================================
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS rb_prog RADIOBUTTON GROUP typ DEFAULT 'X' USER-COMMAND utyp.
    SELECTION-SCREEN COMMENT 3(20) TEXT-010 FOR FIELD rb_prog.
    PARAMETERS p_prog  TYPE progname   MATCHCODE OBJECT progname      MODIF ID prg.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS rb_clas RADIOBUTTON GROUP typ.
    SELECTION-SCREEN COMMENT 3(20) TEXT-011 FOR FIELD rb_clas.
    PARAMETERS p_clas  TYPE seoclsname MATCHCODE OBJECT sfbeclname    MODIF ID cls.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS rb_func RADIOBUTTON GROUP typ.
    SELECTION-SCREEN COMMENT 3(20) TEXT-012 FOR FIELD rb_func.
    PARAMETERS p_func  TYPE rs38l_fnam MATCHCODE OBJECT cacs_function MODIF ID fnc.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS rb_tr   RADIOBUTTON GROUP typ.
    SELECTION-SCREEN COMMENT 3(20) TEXT-013 FOR FIELD rb_tr.
    PARAMETERS p_task  TYPE trkorr                                     MODIF ID trq.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS rb_pack RADIOBUTTON GROUP typ.
    SELECTION-SCREEN COMMENT 3(20) TEXT-014 FOR FIELD rb_pack.
    PARAMETERS p_pack  TYPE devclass   MATCHCODE OBJECT devclass       MODIF ID pck.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME.

    PARAMETERS p_diff AS CHECKBOX DEFAULT 'X'.
    PARAMETERS p_pane AS CHECKBOX DEFAULT 'X'.
    PARAMETERS p_ntoc AS CHECKBOX DEFAULT 'X'.
    PARAMETERS p_cmpct AS CHECKBOX DEFAULT 'X'.
    PARAMETERS p_rmdp  AS CHECKBOX DEFAULT 'X'.
    PARAMETERS p_blame AS CHECKBOX DEFAULT 'X'.
    PARAMETERS p_user TYPE versuser.
    PARAMETERS p_datefr TYPE versdate.

SELECTION-SCREEN END OF BLOCK b2.

"======================================================================

INITIALIZATION.
  p_user = sy-uname.
  PERFORM supress_button.

  "======================================================================

AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    CASE screen-group1.
      WHEN 'PRG'.
        screen-input = COND #( WHEN rb_prog = 'X' THEN 1 ELSE 0 ).
      WHEN 'CLS'.
        screen-input = COND #( WHEN rb_clas = 'X' THEN 1 ELSE 0 ).
      WHEN 'FNC'.
        screen-input = COND #( WHEN rb_func = 'X' THEN 1 ELSE 0 ).
      WHEN 'TRQ'.
        screen-input = COND #( WHEN rb_tr   = 'X' THEN 1 ELSE 0 ).
      WHEN 'PCK'.
        screen-input = COND #( WHEN rb_pack = 'X' THEN 1 ELSE 0 ).
    ENDCASE.
    IF screen-name = 'P_PANE' OR screen-name = 'P_CMPCT'.
      screen-input = COND #( WHEN p_diff = 'X' THEN 1 ELSE 0 ).
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.

  "======================================================================

AT SELECTION-SCREEN ON p_diff.
  " Trigger OUTPUT to re-evaluate enabled state of dependent checkboxes

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
      DATA(ls_settings) = VALUE zif_ave_object=>ty_settings(
        show_diff   = CONV #( p_diff )
        two_pane    = CONV #( p_pane )
        no_toc      = CONV #( p_ntoc )
        compact     = CONV #( p_cmpct )
        remove_dup  = CONV #( p_rmdp )
        blame       = CONV #( p_blame )
        filter_user = p_user
        date_from   = p_datefr ).

      IF rb_prog = 'X' AND p_prog IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-program
          i_object_name = CONV #( p_prog )
          is_settings   = ls_settings ).

      ELSEIF rb_clas = 'X' AND p_clas IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-class
          i_object_name = CONV #( p_clas )
          is_settings   = ls_settings ).

      ELSEIF rb_func = 'X' AND p_func IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-function
          i_object_name = CONV #( p_func )
          is_settings   = ls_settings ).

      ELSEIF rb_tr = 'X' AND p_task IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-tr
          i_object_name = CONV #( p_task )
          is_settings   = ls_settings ).

      ELSEIF rb_pack = 'X' AND p_pack IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-package
          i_object_name = CONV #( p_pack )
          is_settings   = ls_settings ).

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
* abapmerge 0.16.7 - 2026-04-20T03:02:13.902Z
  CONSTANTS c_merge_timestamp TYPE string VALUE `2026-04-20T03:02:13.902Z`.
  CONSTANTS c_abapmerge_version TYPE string VALUE `0.16.7`.
ENDINTERFACE.
****************************************************
