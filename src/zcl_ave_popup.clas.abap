CLASS zcl_ave_popup DEFINITION
  PUBLIC
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
        rowcolor(4) TYPE c,
      END OF ty_part_row .
  types:
    ty_t_part_row TYPE STANDARD TABLE OF ty_part_row WITH DEFAULT KEY .
  types:
    BEGIN OF ty_version_row,
        objname     TYPE versobjnam,
        versno      TYPE versno,
        versno_text TYPE string,
        datum       TYPE versdate,
        zeit        TYPE verstime,
        author      TYPE versuser,
        author_name TYPE ad_namtext,
        obj_owner      TYPE versuser,
        obj_owner_name TYPE ad_namtext,
        korrnum     TYPE verskorrno,
        task        TYPE trkorr,
        korr_text   TYPE string,
        objtype     TYPE versobjtyp,
        rowcolor(4) TYPE c,
      END OF ty_version_row .
  types:
    ty_t_version_row TYPE STANDARD TABLE OF ty_version_row WITH DEFAULT KEY .
  types:
    BEGIN OF ty_diff_op,
        op(255)   TYPE c,
        text TYPE string,
      END OF ty_diff_op .
  types:
    ty_t_diff TYPE STANDARD TABLE OF ty_diff_op WITH DEFAULT KEY .
  TYPES:
    BEGIN OF ty_blame_entry,
      text        TYPE string,
      author      TYPE versuser,
      author_name TYPE ad_namtext,
      datum       TYPE versdate,
      zeit        TYPE verstime,
      versno_text TYPE string,
      task        TYPE trkorr,
    END OF ty_blame_entry.
  TYPES ty_blame_map TYPE STANDARD TABLE OF ty_blame_entry WITH DEFAULT KEY.

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
    " Right panel: HTML code viewer
  data MO_HTML type ref to CL_GUI_HTML_VIEWER .
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
  data MV_LAST_HTML   type STRING.
  data MV_FILTER_USER type VERSUSER ##NO_TEXT.
  data MV_DATE_FROM   type VERSDATE ##NO_TEXT.
  data MV_VIEWED_VERSNO type VERSNO .
    " Backup for Back navigation (one level)
  data MT_PARTS_BACKUP type TY_T_PART_ROW .
  types:
    begin of TY_TYPE_TEXT,
      type type VERSOBJTYP,
      text type AS4TEXT,
    end of TY_TYPE_TEXT .
  data MT_TYPE_TEXT_CACHE type HASHED TABLE OF TY_TYPE_TEXT WITH UNIQUE KEY TYPE .
  data MO_TOOLBAR type ref to CL_GUI_TOOLBAR .
  data MO_CONT_TOOLBAR type ref to CL_GUI_CONTAINER .

    "──────────── build ─────────────────────────────────────────────
  methods BUILD_LAYOUT .
  methods BUILD_PARTS_LIST .
  methods BUILD_HTML_VIEWER .
  methods REFRESH_VERS .
  methods REFRESH_PARTS .
  methods SWITCH_PANE_LAYOUT .
  methods GET_USER_NAME
    importing !IV_USER       type versuser
    returning value(RESULT)  type ad_namtext .
  methods CREATE_PARTS_ALV .
  methods CREATE_VERSIONS_ALV .
  methods CREATE_HTML_VIEWER .
  methods BUILD_VERSIONS_GRID .
  methods HAS_COMMON_CHARS
    importing !IV_A          type STRING
              !IV_B          type STRING
    returning value(RESULT)  type ABAP_BOOL .
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
  methods CHECK_PART_EXISTS
    importing
      !I_TYPE type VERSOBJTYP
      !I_NAME type VERSOBJNAM
      !I_CLASS_NAME type SEOCLSNAME optional
    returning
      value(RESULT) type ABAP_BOOL .
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
  methods REMOVE_DUPLICATE_VERSIONS .
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
  methods SET_HTML
    importing
      !IV_HTML type STRING .
  methods SOURCE_TO_HTML
    importing
      !IT_SOURCE type ABAPTXT255_TAB
      !I_TITLE type STRING
      !I_META type STRING optional
    returning
      value(RV_HTML) type STRING .
  methods COMPUTE_DIFF
    importing
      !IT_OLD type ABAPTXT255_TAB
      !IT_NEW type ABAPTXT255_TAB
    returning
      value(RESULT) type TY_T_DIFF .
  methods CHAR_DIFF_HTML
    importing
      !IV_OLD type STRING
      !IV_NEW type STRING
      !IV_SIDE type C default 'N'
    returning
      value(RESULT) type STRING .
  methods GET_LATEST_AUTHOR
    importing
      !I_TYPE type VERSOBJTYP
      !I_NAME type VERSOBJNAM
    returning
      value(RESULT) type VERSUSER .
  methods GET_TYPE_TEXT
    importing
      !I_TYPE type VERSOBJTYP
    returning
      value(RESULT) type AS4TEXT .
  methods CHECK_CLASS_HAS_AUTHOR
    importing
      !I_CLASS_NAME type STRING
      !I_USER       type VERSUSER
    returning
      value(RESULT) type ABAP_BOOL .
  methods DIFF_TO_HTML
    importing
      !IT_DIFF    type TY_T_DIFF
      !I_TITLE    type STRING
      !I_META     type STRING optional
      !I_TWO_PANE type ABAP_BOOL optional
      !I_COMPACT  type ABAP_BOOL optional
      !IT_BLAME         type TY_BLAME_MAP optional
      !IT_BLAME_DELETED type TY_BLAME_MAP optional
    returning
      value(RESULT) type STRING .
  METHODS get_ver_source
    IMPORTING is_ver        TYPE ty_version_row
    RETURNING VALUE(result) TYPE abaptxt255_tab.
  METHODS build_blame_map
    IMPORTING i_objtype        TYPE versobjtyp
              i_objname        TYPE versobjnam
              i_from           TYPE versno
              i_to             TYPE versno
    EXPORTING et_blame_deleted TYPE ty_blame_map
    RETURNING VALUE(result)    TYPE ty_blame_map.
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

    " Load all object-type descriptions once
    DATA lt_types_out TYPE STANDARD TABLE OF ko100.
    CALL FUNCTION 'TRINT_OBJECT_TABLE'
      EXPORTING
        iv_complete  = 'X'
      TABLES
        tt_types_out = lt_types_out.
    LOOP AT lt_types_out INTO DATA(ls_ko100).
      INSERT VALUE #( type = ls_ko100-object text = ls_ko100-text )
        INTO TABLE mt_type_text_cache.
    ENDLOOP.
  ENDMETHOD.


  METHOD show.
    build_layout( ).
    build_parts_list( ).
    build_html_viewer( ).
    build_versions_grid( ).

    " Auto-load versions and source for the first existing part
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
            show_versions_diff( is_old = ls_prev_auto is_new = ms_base_ver ).
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

    cl_gui_cfw=>flush( ).
  ENDMETHOD.


  METHOD build_layout.
    DATA lv_pos TYPE i.

    ADD 1 TO mv_counter.
    lv_pos = 50 - 5 * ( mv_counter DIV 5 ) - ( mv_counter MOD 5 ) * 5.

    CREATE OBJECT mo_box
      EXPORTING
        width                       = 1300
        height                      = 400
        top                         = lv_pos
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
              THEN check_part_exists(
                     i_type       = ls_raw-type
                     i_name       = CONV #( ls_raw-unit )
                     i_class_name = CONV #( ls_raw-class ) )
              ELSE abap_true ).
            DATA ls_row TYPE ty_part_row.
            ls_row-class       = ls_raw-class.
            ls_row-name        = ls_raw-unit.
            ls_row-type        = ls_raw-type.
            ls_row-type_text   = get_type_text( ls_raw-type ).
            ls_row-object_name = ls_raw-object_name.
            ls_row-exists_flag = lv_exists.
            IF lv_exists = abap_false.
              ls_row-rowcolor = 'C610'.   " red
            ELSEIF mv_filter_user IS NOT INITIAL.
              DATA(lv_user_match) = COND abap_bool(
                WHEN ls_raw-type = 'CLAS'
                THEN check_class_has_author( i_class_name = CONV #( ls_raw-object_name ) i_user = mv_filter_user )
                ELSE boolc( get_latest_author( i_type = ls_raw-type i_name = ls_raw-object_name ) = mv_filter_user ) ).
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

    CLEAR ls_fc. ls_fc-fieldname = 'CLASS'.       ls_fc-coltext = 'Class'.
    ls_fc-outputlen = 20. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'NAME'.        ls_fc-coltext = 'Object'.
    ls_fc-outputlen = 30. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'TYPE'.        ls_fc-coltext = 'Type'.
    ls_fc-outputlen = 6.  APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'TYPE_TEXT'.   ls_fc-coltext = 'Type Description'.
    ls_fc-outputlen = 30. APPEND ls_fc TO lt_fcat.
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
    CREATE OBJECT mo_html
      EXPORTING
        parent             = mo_cont_html
      EXCEPTIONS
        cntl_error         = 1
        cntl_install_error = 2
        dp_install_error   = 3
        dp_error           = 4
        OTHERS             = 5.

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
    CLEAR ls_fc. ls_fc-fieldname = 'OBJTYPE'.     ls_fc-no_out = abap_true. APPEND ls_fc TO lt_fcat.
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
        CLEAR mt_parts_backup.
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
                show_versions_diff( is_old = ls_prev_cls is_new = ms_base_ver ).
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
          show_versions_diff( is_old = ls_prev_part is_new = ms_base_ver ).
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
            author_name    = get_user_name( ls_vrsd-author )
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
      remove_duplicate_versions( ).
    ENDIF.

    " For each version find the task and owner
    DATA lv_trf_s   TYPE e070-trfunction VALUE 'S'.
    DATA lv_trf_k   TYPE e070-trfunction VALUE 'K'.
    DATA lv_task_tr TYPE trkorr.
    DATA lv_owner   TYPE versuser.
    DATA ls_e070_lk TYPE e070.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver>).
      CLEAR: lv_task_tr, lv_owner, ls_e070_lk.
      IF <ver>-korrnum IS NOT INITIAL.
        SELECT SINGLE * FROM e070
          WHERE trkorr = @<ver>-korrnum
          INTO @ls_e070_lk.
        IF ls_e070_lk-trfunction = lv_trf_s.
          " korrnum itself is the task
          lv_task_tr = <ver>-korrnum.
          lv_owner   = ls_e070_lk-as4user.
        ELSEIF ls_e070_lk-trfunction = lv_trf_k.
          " korrnum is a request — find task within it for this object
          SELECT SINGLE e070~trkorr, e070~as4user
            FROM e071
            INNER JOIN e070 ON e070~trkorr   = e071~trkorr
            WHERE e071~object     = @<ver>-objtype
              AND e071~obj_name   = @<ver>-objname
              AND e070~trfunction = @lv_trf_s
              AND e070~strkorr    = @<ver>-korrnum
            INTO (@lv_task_tr, @lv_owner).
        ENDIF.
      ENDIF.
      " Fallback: nearest task by date across all transports
      IF lv_task_tr IS INITIAL.
        SELECT e070~trkorr, e070~as4user
          FROM e071
          INNER JOIN e070 ON e070~trkorr   = e071~trkorr
          WHERE e071~object     = @<ver>-objtype
            AND e071~obj_name   = @<ver>-objname
            AND e070~trfunction = @lv_trf_s
            AND e070~as4date   <= @<ver>-datum
          ORDER BY e070~as4date DESCENDING, e070~as4time DESCENDING
          INTO (@lv_task_tr, @lv_owner)
          UP TO 1 ROWS.
        ENDSELECT.
      ENDIF.
      IF lv_task_tr IS NOT INITIAL.
        <ver>-task           = lv_task_tr.
        <ver>-obj_owner      = lv_owner.
        <ver>-obj_owner_name = get_user_name( lv_owner ).
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
    FREE mo_html.
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


  METHOD get_user_name.
    result = NEW zcl_ave_author( )->get_name( iv_user ).
  ENDMETHOD.


  METHOD has_common_chars.
    " Returns true if iv_a and iv_b share a non-trivial common prefix or suffix.
    " Used to decide whether two changed lines are "similar enough" to pair.
    DATA lv_a TYPE string.
    DATA lv_b TYPE string.
    lv_a = iv_a.
    lv_b = iv_b.
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
    DATA lv_cp TYPE i VALUE 0.
    WHILE lv_cp < lv_la AND lv_cp < lv_lb.
      IF lv_a+lv_cp(1) = lv_b+lv_cp(1).
        lv_cp += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.
    DATA lv_cs TYPE i VALUE 0.
    WHILE lv_cs < lv_la - lv_cp AND lv_cs < lv_lb - lv_cp.
      DATA(lv_pa) = lv_la - 1 - lv_cs.
      DATA(lv_pb) = lv_lb - 1 - lv_cs.
      IF lv_a+lv_pa(1) = lv_b+lv_pb(1).
        lv_cs += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.
    " Require a real common prefix (>=3 chars). Suffix only reinforces but isn't enough alone.
    IF lv_cp >= 3.
      result = abap_true.
    ELSE.
      result = abap_false.
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

      ls_row-author_name = get_user_name( ls_row-author ).

      APPEND ls_row TO mt_versions.
      CLEAR: ls_row, ls_e070.
    ENDLOOP.

    SORT mt_versions BY versno DESCENDING datum DESCENDING zeit DESCENDING.

    IF mv_remove_dup = abap_true.
      remove_duplicate_versions( ).
    ENDIF.
  ENDMETHOD.


  METHOD remove_duplicate_versions.
    DATA lt_result   TYPE ty_t_version_row.
    DATA lt_prev_src TYPE abaptxt255_tab.
    DATA lt_vrsd     TYPE vrsd_tab.
    DATA lv_ts_start TYPE timestampl.
    DATA lv_ts_now   TYPE timestampl.
    DATA lv_secs     TYPE tzntstmpl.

    " mt_versions is already DESCENDING (newest first) — no sort needed
    GET TIME STAMP FIELD lv_ts_start.

    LOOP AT mt_versions INTO DATA(ls_ver).
      DATA(lv_tabix) = sy-tabix.

      " Timeout check: after 10 seconds ask user whether to continue or stop
      GET TIME STAMP FIELD lv_ts_now.
      CALL METHOD cl_abap_tstmp=>subtract
        EXPORTING tstmp1 = lv_ts_now tstmp2 = lv_ts_start
        RECEIVING r_secs = lv_secs.
      IF lv_secs > 10.
        DATA(lv_remaining) = lines( mt_versions ) - lv_tabix + 1.
        DATA lv_answer TYPE c LENGTH 1.
        CALL FUNCTION 'POPUP_TO_CONFIRM'
          EXPORTING
            titlebar      = 'Deduplication timeout'
            text_question = |{ lv_remaining } versions remaining. Continue?|
            text_button_1 = 'Continue'
            text_button_2 = 'Stop'
            default_button = '2'
          IMPORTING
            answer        = lv_answer.
        IF lv_answer <> '1'.
          LOOP AT mt_versions INTO DATA(ls_rest) FROM lv_tabix.
            APPEND ls_rest TO lt_result.
          ENDLOOP.
          EXIT.
        ENDIF.
        " Reset timer so next check is another 10 seconds later
        GET TIME STAMP FIELD lv_ts_start.
      ENDIF.

      TRY.
          DATA(lv_db_no) = zcl_ave_versno=>to_internal( ls_ver-versno ).
          SELECT * FROM vrsd
            WHERE objtype = @ls_ver-objtype
              AND objname = @ls_ver-objname
              AND versno  = @lv_db_no
                INTO TABLE @lt_vrsd
            UP TO 1 ROWS.
          DATA(lt_cur_src) = COND abaptxt255_tab(
            WHEN lt_vrsd IS NOT INITIAL
            THEN NEW zcl_ave_version( lt_vrsd[ 1 ] )->get_source( ) ).
        CATCH cx_root.
          CLEAR lt_cur_src.
      ENDTRY.

      IF lv_tabix = 1 OR lt_cur_src <> lt_prev_src.
        APPEND ls_ver TO lt_result.
        lt_prev_src = lt_cur_src.
      ENDIF.
    ENDLOOP.

    mt_versions = lt_result.
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
      mo_box->set_caption( |AVE – { mv_object_type }: { mv_object_name }  [{ lv_vtxt }]| ).
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

        Select single as4text into @data(lv_req_text)
          from e07t
         where trkorr = @lo_ver->request
           and  langu = @sy-langu.

        DATA(lv_versno_str) = COND string(
          WHEN i_versno = zcl_ave_version=>c_version-active   THEN 'Active'
          WHEN i_versno = zcl_ave_version=>c_version-modified THEN 'Modified'
          ELSE |{ CONV i( i_versno ) }| ).
        DATA(lv_date_str) = |{ lo_ver->date+6(2) }.{ lo_ver->date+4(2) }.{ lo_ver->date(4) }|.
        DATA(lv_time_str) = |{ lo_ver->time(2) }:{ lo_ver->time+2(2) }:{ lo_ver->time+4(2) }|.
        DATA(lv_meta) =
          |Ver: { lv_versno_str }  | &&
          |{ lv_date_str } { lv_time_str }  | &&
          |{ lo_ver->author }| &&
          COND string( WHEN lo_ver->author_name <> lo_ver->author
                       THEN | ({ lo_ver->author_name })| ELSE `` ) &&
          COND string( WHEN lo_ver->request IS NOT INITIAL
                       THEN |  { lo_ver->request }{ COND string( WHEN lv_req_text IS NOT INITIAL THEN | { lv_req_text }| ELSE `` ) }| ELSE `` ).

        set_html( source_to_html(
          it_source = lt_source
          i_title   = |{ i_objtype }: { i_objname }|
          i_meta    = lv_meta ) ).

      CATCH zcx_ave.
        set_html(
          |<html><body style="background:#1e1e1e;color:#f55;| &&
          |font-family:Consolas;padding:20px">| &&
          |Error loading source.</body></html>| ).
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


  METHOD set_html.
    mv_last_html = iv_html.
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

    IF i_type = 'CPUB' OR i_type = 'CPUB' OR i_type = 'CPUB'.
      result = abap_true.
      RETURN.
    ENDIF.


    DATA lv_tadir_type TYPE tadir-object.
    IF i_type = 'REPS'.
      lv_tadir_type = 'PROG'.
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


  METHOD get_class_parts.
    DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
      object_type = zcl_ave_object_factory=>gc_type-class
      object_name = CONV #( i_name ) ).
    LOOP AT lo_obj->get_parts( ) INTO DATA(ls_part).
      CHECK ls_part-type <> 'CLSD' AND ls_part-type <> 'RELE'.
      IF ls_part-type <> 'METH'.
        CHECK check_part_exists(
                     i_type       = ls_part-type
                     i_name       = CONV #( ls_part-object_name ) ).

      ENDIF.
      DATA ls_part_row TYPE ty_part_row.
      CLEAR ls_part_row.
      ls_part_row-class       = ls_part-class.
      ls_part_row-name        = ls_part-unit.
      ls_part_row-type        = ls_part-type.
      ls_part_row-type_text   = get_type_text( ls_part-type ).
      ls_part_row-object_name = ls_part-object_name.
      ls_part_row-exists_flag = abap_true.
      IF mv_filter_user IS NOT INITIAL.
        IF get_latest_author( i_type = ls_part-type i_name = ls_part-object_name ) = mv_filter_user.
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
        CLEAR mt_parts_backup.
        refresh_parts( ).

      WHEN 'REFRESH'.
        " Reload parts
        CLEAR mt_parts.
        TRY.
            IF mv_object_type = zcl_ave_object_factory=>gc_type-class.
              mt_parts = get_class_parts( CONV #( mv_object_name ) ).
            ELSE.
              DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
                object_type = mv_object_type
                object_name = CONV #( mv_object_name ) ).
              DATA(lv_is_tr) = boolc( mv_object_type = zcl_ave_object_factory=>gc_type-tr ).
              LOOP AT lo_obj->get_parts( ) INTO DATA(ls_raw).
                DATA(lv_exists) = COND abap_bool(
                  WHEN lv_is_tr = abap_true
                  THEN check_part_exists(
                         i_type       = ls_raw-type
                         i_name       = ls_raw-object_name
                         i_class_name = CONV #( ls_raw-class ) )
                  ELSE abap_true ).
                DATA ls_row TYPE ty_part_row.
                ls_row-class       = ls_raw-class.
                ls_row-name        = ls_raw-unit.
                ls_row-type        = ls_raw-type.
                ls_row-type_text   = get_type_text( ls_raw-type ).
                ls_row-object_name = ls_raw-object_name.
                ls_row-exists_flag = lv_exists.
                IF lv_exists = abap_false.
                  ls_row-rowcolor = 'C610'.   " red
                ELSEIF mv_filter_user IS NOT INITIAL.
                  DATA(lv_umatch) = COND abap_bool(
                    WHEN ls_raw-type = 'CLAS'
                    THEN check_class_has_author( i_class_name = CONV #( ls_raw-object_name ) i_user = mv_filter_user )
                    ELSE boolc( get_latest_author( i_type = ls_raw-type i_name = ls_raw-object_name ) = mv_filter_user ) ).
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


  METHOD show_versions_diff.
    ms_diff_old = is_old.
    ms_diff_new = is_new.
    IF mo_box IS BOUND.
      mo_box->set_caption( |AVE – { mv_object_type }: { mv_object_name }  [{ is_new-versno_text } → { is_old-versno_text }]| ).
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
        IF lt_vrsd_o IS INITIAL OR lt_vrsd_n IS INITIAL. RETURN. ENDIF.
        DATA(lt_src_o) = NEW zcl_ave_version( lt_vrsd_o[ 1 ] )->get_source( ).
        DATA(lt_src_n) = NEW zcl_ave_version( lt_vrsd_n[ 1 ] )->get_source( ).
        DATA(lt_diff)  = compute_diff( it_old = lt_src_o it_new = lt_src_n ).
        DATA(lv_meta)  = |{ is_new-versno_text } → { is_old-versno_text }|.
        DATA lt_blame         TYPE ty_blame_map.
        DATA lt_blame_deleted TYPE ty_blame_map.
        IF mv_blame = abap_true.
          lt_blame = build_blame_map(
            EXPORTING i_objtype        = is_new-objtype
                      i_objname        = is_new-objname
                      i_from           = is_old-versno
                      i_to             = is_new-versno
            IMPORTING et_blame_deleted = lt_blame_deleted ).
        ENDIF.
        set_html( diff_to_html(
          it_diff          = lt_diff
          i_title          = |{ is_new-objtype }: { is_new-objname }|
          i_meta           = lv_meta
          i_two_pane       = mv_two_pane
          i_compact        = mv_compact
          it_blame         = lt_blame
          it_blame_deleted = lt_blame_deleted ) ).
      CATCH cx_root.
        set_html( |<html><body style="padding:24px;font:13px Consolas;color:#c00">| &&
          |Error loading versions for comparison.</body></html>| ).
    ENDTRY.
  ENDMETHOD.


  METHOD compute_diff.
    " Line-level LCS diff. Falls back to all-delete/all-insert if > 500 lines.
    DATA(lv_nold) = lines( it_old ).
    DATA(lv_nnew) = lines( it_new ).

* My initiative Claude decided to show all Abap code objects with rows > 500 as totally different without trying to run diff )))
*    IF lv_nold > 500 OR lv_nnew > 500.
*      " Fallback: all old lines deleted, all new lines inserted
*      LOOP AT it_old INTO DATA(ls_old_fb).
*        APPEND VALUE ty_diff_op( op = '-' text = CONV string( ls_old_fb ) ) TO result.
*      ENDLOOP.
*      LOOP AT it_new INTO DATA(ls_new_fb).
*        APPEND VALUE ty_diff_op( op = '+' text = CONV string( ls_new_fb ) ) TO result.
*      ENDLOOP.
*      RETURN.
*    ENDIF.

    " Build flat 2D DP table: (lv_nold+1) x (lv_nnew+1)
    DATA(lv_cols) = lv_nnew + 1.
    DATA(lv_rows) = lv_nold + 1.
    DATA lt_dp TYPE TABLE OF i.
    DATA(lv_size) = lv_rows * lv_cols.
    DO lv_size TIMES.
      APPEND 0 TO lt_dp.
    ENDDO.

    " Fill DP
    DATA lv_i TYPE i.
    DATA lv_j TYPE i.
    lv_i = 1.
    LOOP AT it_old INTO DATA(ls_old).
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

    " Backtrack to build diff ops (prepend into result)
    " Prefer deletion over insertion (cup > cleft) so that '-' precedes '+'
    " in the same change block – this keeps related pairs together.
    lv_i = lv_nold.
    lv_j = lv_nnew.
    WHILE lv_i > 0 OR lv_j > 0.
      IF lv_i > 0 AND lv_j > 0.
        DATA(lv_oi) = lv_i - 1.
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
    " iv_side = 'B' (default) → inline both: deleted red+strike, inserted green
    " iv_side = 'N' → only insertion highlighted green (no deletion shown)
    " iv_side = 'O' → only deletion highlighted red+strike (no insertion shown)
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
    REPLACE ALL OCCURRENCES OF `&` IN lv_mid_n  WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_mid_n  WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_mid_n  WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF `&` IN lv_suffix WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN lv_suffix WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN lv_suffix WITH `&gt;`.

    result = lv_prefix.
    CASE iv_side.
      WHEN 'O'.
        IF lv_mid_o IS NOT INITIAL.
          result = result &&
            |<span style="background:#ffb3b3;color:#cc0000;text-decoration:line-through">{ lv_mid_o }</span>|.
        ENDIF.
      WHEN 'N'.
        IF lv_mid_n IS NOT INITIAL.
          result = result &&
            |<span style="background:#afffaf;color:#006600">{ lv_mid_n }</span>|.
        ENDIF.
      WHEN OTHERS. " 'B': show deleted then inserted inline
        IF lv_mid_o IS NOT INITIAL.
          result = result &&
            |<span style="background:#ffb3b3;color:#cc0000;text-decoration:line-through">{ lv_mid_o }</span>|.
        ENDIF.
        IF lv_mid_n IS NOT INITIAL.
          result = result &&
            |<span style="background:#afffaf;color:#006600">{ lv_mid_n }</span>|.
        ENDIF.
    ENDCASE.
    result = result && lv_suffix.
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
          WHILE lv_sc <= lv_tot2.
            READ TABLE it_diff INTO DATA(ls_s2) INDEX lv_sc.
            IF ls_s2-op = '-'. APPEND ls_s2-text TO lt_d2. lv_sc += 1.
            ELSEIF ls_s2-op = '+'. APPEND ls_s2-text TO lt_i2. lv_sc += 1.
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
              DATA(lv_btask2) = COND string( WHEN ls_bl2-task IS NOT INITIAL THEN | { ls_bl2-task }| ELSE `` ).
              lv_rows = lv_rows &&
                |<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">| &&
                |<td class="ln">▶</td><td class="cd" colspan="3">── { ls_bl2-author }| &&
                COND string( WHEN ls_bl2-author_name IS NOT INITIAL THEN | ({ ls_bl2-author_name })| ELSE `` ) &&
                | added/changed  { lv_bdate2 } { lv_btime2 }  { ls_bl2-versno_text }{ lv_btask2 } ──</td>| &&
                |<td class="ln"></td><td class="cd"></td></tr>|.
            ENDIF.
          ENDIF.
          " Blame separator for two-pane (deleted lines)
          IF it_blame_deleted IS NOT INITIAL AND lt_d2 IS NOT INITIAL AND lt_i2 IS INITIAL.
            READ TABLE it_blame_deleted INTO DATA(ls_bld2) WITH KEY text = lt_d2[ 1 ].
            IF sy-subrc = 0.
              DATA(lv_bddate2) = |{ ls_bld2-datum+6(2) }.{ ls_bld2-datum+4(2) }.{ ls_bld2-datum(4) }|.
              DATA(lv_bdtime2) = |{ ls_bld2-zeit(2) }:{ ls_bld2-zeit+2(2) }|.
              DATA(lv_bdtask2) = COND string( WHEN ls_bld2-task IS NOT INITIAL THEN | { ls_bld2-task }| ELSE `` ).
              lv_rows = lv_rows &&
                |<tr style="background:#fdf0f0;color:#888;font-size:10px;font-style:italic">| &&
                |<td class="ln">◀</td><td class="cd" colspan="3">── { ls_bld2-author }| &&
                COND string( WHEN ls_bld2-author_name IS NOT INITIAL THEN | ({ ls_bld2-author_name })| ELSE `` ) &&
                | deleted  { lv_bddate2 } { lv_bdtime2 }  { ls_bld2-versno_text }{ lv_bdtask2 } ──</td>| &&
                |<td class="ln"></td><td class="cd"></td></tr>|.
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
            IF has_common_chars( iv_a = lt_i2_p[ lv_kk ] iv_b = lt_d2_p[ lv_kk ] ) = abap_true.
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
            lv_dl2 = char_diff_html( iv_old = lt_d2[ lv_pr ] iv_new = lt_i2[ lv_pr ] iv_side = 'N' ).
            lv_il2 = char_diff_html( iv_old = lt_d2[ lv_pr ] iv_new = lt_i2[ lv_pr ] iv_side = 'O' ).
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
        " Collect consecutive '-' block
        DATA lt_dels TYPE string_table.
        DATA lt_ins  TYPE string_table.
        DATA lv_scan TYPE i.
        lv_scan = lv_pos.

        " Collect all consecutive '-' and '+' ops in any order
        WHILE lv_scan <= lv_total.
          READ TABLE it_diff INTO DATA(ls_s) INDEX lv_scan.
          IF ls_s-op = '-'.
            APPEND ls_s-text TO lt_dels.
            lv_scan += 1.
          ELSEIF ls_s-op = '+'.
            APPEND ls_s-text TO lt_ins.
            lv_scan += 1.
          ELSE.
            EXIT.
          ENDIF.
        ENDWHILE.

        " Blame separator for added lines
        IF it_blame IS NOT INITIAL AND lt_ins IS NOT INITIAL.
          READ TABLE it_blame INTO DATA(ls_bl) WITH KEY text = lt_ins[ 1 ].
          IF sy-subrc = 0.
            DATA(lv_bdate) = |{ ls_bl-datum+6(2) }.{ ls_bl-datum+4(2) }.{ ls_bl-datum(4) }|.
            DATA(lv_btime) = |{ ls_bl-zeit(2) }:{ ls_bl-zeit+2(2) }|.
            DATA(lv_btask) = COND string( WHEN ls_bl-task IS NOT INITIAL THEN | { ls_bl-task }| ELSE `` ).
            lv_rows = lv_rows &&
              |<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">| &&
              |<td class="ln">▶</td>| &&
              |<td class="cd">── { ls_bl-author }| &&
              COND string( WHEN ls_bl-author_name IS NOT INITIAL THEN | ({ ls_bl-author_name })| ELSE `` ) &&
              | added/changed  { lv_bdate } { lv_btime }  { ls_bl-versno_text }{ lv_btask } ──</td></tr>|.
          ENDIF.
        ENDIF.
        " Blame separator for deleted lines
        IF it_blame_deleted IS NOT INITIAL AND lt_dels IS NOT INITIAL AND lt_ins IS INITIAL.
          READ TABLE it_blame_deleted INTO DATA(ls_bld) WITH KEY text = lt_dels[ 1 ].
          IF sy-subrc = 0.
            DATA(lv_bddate) = |{ ls_bld-datum+6(2) }.{ ls_bld-datum+4(2) }.{ ls_bld-datum(4) }|.
            DATA(lv_bdtime) = |{ ls_bld-zeit(2) }:{ ls_bld-zeit+2(2) }|.
            DATA(lv_bdtask) = COND string( WHEN ls_bld-task IS NOT INITIAL THEN | { ls_bld-task }| ELSE `` ).
            lv_rows = lv_rows &&
              |<tr style="background:#fdf0f0;color:#888;font-size:10px;font-style:italic">| &&
              |<td class="ln">◀</td>| &&
              |<td class="cd">── { ls_bld-author }| &&
              COND string( WHEN ls_bld-author_name IS NOT INITIAL THEN | ({ ls_bld-author_name })| ELSE `` ) &&
              | deleted  { lv_bddate } { lv_bdtime }  { ls_bld-versno_text }{ lv_bdtask } ──</td></tr>|.
          ENDIF.
        ENDIF.

        DATA(lv_ndels) = lines( lt_dels ).
        DATA(lv_nins)  = lines( lt_ins ).

        IF lv_ndels = 1 AND lv_nins = 1.
          " Exactly one line replaced → single inline row with char-level diff
          lv_lno += 1.
          DATA(lv_inline) = char_diff_html(
            iv_old = lt_dels[ 1 ]
            iv_new = lt_ins[ 1 ]
            iv_side = 'B' ).
          lv_rows = lv_rows &&
            |<tr style="background:#ffffff">| &&
            |<td class="ln">{ lv_lno }</td>| &&
            |<td class="cd">{ lv_inline }</td></tr>|.
        ELSE.
          " Multiple lines changed: deletions (red) then insertions (green)
          DATA lv_de TYPE i.
          lv_de = 1.
          WHILE lv_de <= lv_ndels.
            DATA(lv_dl) = lt_dels[ lv_de ].
            REPLACE ALL OCCURRENCES OF `&` IN lv_dl WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<` IN lv_dl WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>` IN lv_dl WITH `&gt;`.
            lv_rows = lv_rows &&
              |<tr style="background:#ffecec">| &&
              |<td class="ln" style="color:#cc0000">-</td>| &&
              |<td class="cd" style="text-decoration:line-through;color:#cc0000">{ lv_dl }</td></tr>|.
            lv_de += 1.
          ENDWHILE.
          DATA lv_ie TYPE i.
          lv_ie = 1.
          WHILE lv_ie <= lv_nins.
            lv_lno += 1.
            DATA(lv_il) = lt_ins[ lv_ie ].
            REPLACE ALL OCCURRENCES OF `&` IN lv_il WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<` IN lv_il WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>` IN lv_il WITH `&gt;`.
            lv_rows = lv_rows &&
              |<tr style="background:#eaffea">| &&
              |<td class="ln" style="color:#006600">{ lv_lno }</td>| &&
              |<td class="cd" style="color:#006600">{ lv_il }</td></tr>|.
            lv_ie += 1.
          ENDWHILE.
        ENDIF.

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


  METHOD get_ver_source.
    DATA lt_vrsd TYPE vrsd_tab.
    DATA(lv_vno) = zcl_ave_versno=>to_internal( is_ver-versno ).
    SELECT * FROM vrsd
      WHERE objtype = @is_ver-objtype
        AND objname = @is_ver-objname
        AND versno  = @lv_vno
      INTO TABLE @lt_vrsd UP TO 1 ROWS.
    IF lt_vrsd IS INITIAL. RETURN. ENDIF.
    result = NEW zcl_ave_version( lt_vrsd[ 1 ] )->get_source( ).
  ENDMETHOD.


  METHOD build_blame_map.
    " Walk versions from i_from to i_to, diffing consecutive pairs.
    " For each '+' line: record/overwrite author in blame map.
    " For each '-' line: remove from blame map.
    DATA lt_vers TYPE ty_t_version_row.
    LOOP AT mt_versions INTO DATA(ls_v)
      WHERE versno  >= i_from
        AND versno  <= i_to
        AND objtype  = i_objtype
        AND objname  = i_objname.
      APPEND ls_v TO lt_vers.
    ENDLOOP.
    SORT lt_vers BY versno ASCENDING datum ASCENDING zeit ASCENDING.
    IF lines( lt_vers ) < 2. RETURN. ENDIF.

    DATA lt_prev_src TYPE abaptxt255_tab.
    lt_prev_src = get_ver_source( lt_vers[ 1 ] ).

    DATA lv_idx TYPE i VALUE 2.
    WHILE lv_idx <= lines( lt_vers ).
      DATA(ls_ver) = lt_vers[ lv_idx ].
      DATA(lt_cur_src) = get_ver_source( ls_ver ).
      DATA(lt_diff) = compute_diff( it_old = lt_prev_src it_new = lt_cur_src ).

      LOOP AT lt_diff INTO DATA(ls_d).
        IF ls_d-op = '+'.
          " Update or insert blame entry for this line
          DATA(lv_text) = ls_d-text.
          DELETE result WHERE text = lv_text.
          APPEND VALUE ty_blame_entry(
            text        = lv_text
            author      = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner ELSE ls_ver-author )
            author_name = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner_name ELSE ls_ver-author_name )
            datum       = ls_ver-datum
            zeit        = ls_ver-zeit
            versno_text = ls_ver-versno_text
            task        = ls_ver-korrnum
          ) TO result.
        ELSEIF ls_d-op = '-'.
          " Record who deleted this line, then remove from added-map
          DELETE et_blame_deleted WHERE text = ls_d-text.
          APPEND VALUE ty_blame_entry(
            text        = ls_d-text
            author      = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner ELSE ls_ver-author )
            author_name = COND #( WHEN ls_ver-obj_owner IS NOT INITIAL THEN ls_ver-obj_owner_name ELSE ls_ver-author_name )
            datum       = ls_ver-datum
            zeit        = ls_ver-zeit
            versno_text = ls_ver-versno_text
            task        = ls_ver-korrnum
          ) TO et_blame_deleted.
          DELETE result WHERE text = ls_d-text.
        ENDIF.
      ENDLOOP.

      lt_prev_src = lt_cur_src.
      lv_idx += 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD get_type_text.
    READ TABLE mt_type_text_cache ASSIGNING FIELD-SYMBOL(<c>) WITH TABLE KEY type = i_type.
    IF sy-subrc = 0.
      result = <c>-text.
    ENDIF.
  ENDMETHOD.


  METHOD get_latest_author.
    DATA(lo_vrsd) = NEW zcl_ave_vrsd( type = i_type name = i_name ).
    IF lo_vrsd->vrsd_list IS INITIAL. RETURN. ENDIF.
    DATA(lt_list) = lo_vrsd->vrsd_list.
    SORT lt_list BY versno DESCENDING.
    result = lt_list[ 1 ]-author.
  ENDMETHOD.


  METHOD check_class_has_author.
    TRY.
        DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
          object_type = zcl_ave_object_factory=>gc_type-class
          object_name = CONV #( i_class_name ) ).
        LOOP AT lo_obj->get_parts( ) INTO DATA(ls_part).
          CHECK ls_part-type <> 'CLSD' AND ls_part-type <> 'RELE'.
          IF get_latest_author( i_type = ls_part-type i_name = ls_part-object_name ) = i_user.
            result = abap_true.
            RETURN.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
