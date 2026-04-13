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
        object_name TYPE versobjnam,
        exists_flag TYPE abap_bool,
        rowcolor    TYPE lvc_t_scol,
      END OF ty_part_row .
  types:
    ty_t_part_row TYPE STANDARD TABLE OF ty_part_row WITH DEFAULT KEY .
  types:
    BEGIN OF ty_version_row,
        versno      TYPE versno,
        versno_text TYPE string,
        datum       TYPE versdate,
        zeit        TYPE verstime,
        author      TYPE versuser,
        author_name TYPE ad_namtext,
        korrnum     TYPE verskorrno,
        korr_text   TYPE string,
        objtype     TYPE versobjtyp,
        objname     TYPE versobjnam,
        rowcolor    TYPE lvc_t_scol,
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
    " Left panel: SALV table with the list of object parts
  data MO_SALV_PARTS type ref to CL_SALV_TABLE .
  data MT_PARTS type TY_T_PART_ROW .
    " Right panel: HTML code viewer
  data MO_HTML type ref to CL_GUI_HTML_VIEWER .
    " Bottom panel: SALV table with version list
  data MO_SALV_VERS type ref to CL_SALV_TABLE .
  data MT_VERSIONS type TY_T_VERSION_ROW .
  data MV_CUR_OBJTYPE type VERSOBJTYP .
  data MV_CUR_OBJNAME type VERSOBJNAM .
  data MS_BASE_VER type TY_VERSION_ROW .
  data MS_DIFF_OLD type TY_VERSION_ROW .
  data MS_DIFF_NEW type TY_VERSION_ROW .
  data MV_SHOW_DIFF type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_TWO_PANE type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_NO_TOC type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_COMPACT     type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_FILTER_USER type VERSUSER ##NO_TEXT.
  data MV_VIEWED_VERSNO type VERSNO .
    " Backup for Back navigation (one level)
  data MT_PARTS_BACKUP type TY_T_PART_ROW .
  data MO_TOOLBAR type ref to CL_GUI_TOOLBAR .

    "──────────── build ─────────────────────────────────────────────
  methods BUILD_LAYOUT .
  methods BUILD_PARTS_LIST .
  methods BUILD_HTML_VIEWER .
  methods BUILD_VERSIONS_GRID .
    "──────────── events ────────────────────────────────────────────
  methods ON_PART_DOUBLE_CLICK
    for event DOUBLE_CLICK of CL_SALV_EVENTS_TABLE
    importing
      !ROW
      !COLUMN .
  methods ON_TOOLBAR_CLICK
    for event FUNCTION_SELECTED of CL_GUI_TOOLBAR
    importing
      !FCODE .
  methods ON_VER_DOUBLE_CLICK
    for event DOUBLE_CLICK of CL_SALV_EVENTS_TABLE
    importing
      !ROW .
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
  methods DIFF_TO_HTML
    importing
      !IT_DIFF type TY_T_DIFF
      !I_TITLE type STRING
      !I_META type STRING optional
      !I_TWO_PANE type ABAP_BOOL optional
      !I_COMPACT  type ABAP_BOOL optional
    returning
      value(RESULT) type STRING .
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
      mv_filter_user = is_settings-filter_user.
    ENDIF.
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
      mo_salv_vers->refresh( ).
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

    CREATE OBJECT mo_split_main
      EXPORTING
        parent  = mo_box
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
    mo_cont_vers = mo_split_top->get_container( row = 2 column = 1 ).
    mo_cont_html  = mo_split_main->get_container( row = 1 column = 2 ).
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
            ls_row-object_name = ls_raw-object_name.
            ls_row-exists_flag = lv_exists.
            DATA ls_scol TYPE lvc_s_scol.
            ls_scol-fname = space.
            IF lv_exists = abap_false.
              ls_scol-color-col = 6.
              ls_scol-color-int = 1.
              APPEND ls_scol TO ls_row-rowcolor.
            ELSEIF mv_filter_user IS NOT INITIAL.
              IF get_latest_author( i_type = ls_raw-type i_name = ls_raw-object_name ) = mv_filter_user.
                ls_scol-color-col = 4.
                ls_scol-color-int = 0.
                APPEND ls_scol TO ls_row-rowcolor.
              ENDIF.
            ENDIF.
            APPEND ls_row TO mt_parts.
            CLEAR ls_row.
          ENDLOOP.
        ENDIF.
      CATCH zcx_ave.
        " leave mt_parts empty – no crash
    ENDTRY.

    " ── Split parts container: toolbar (top) + SALV (rest) ──
    DATA(lo_parts_split) = NEW cl_gui_splitter_container(
      parent  = mo_cont_parts
      rows    = 2
      columns = 1 ).
    lo_parts_split->set_row_height( id = 1 height = 7 ).
    lo_parts_split->set_row_height( id = 2 height = 93 ).
    DATA(lo_cont_tb)   = lo_parts_split->get_container( row = 1 column = 1 ).
    DATA(lo_cont_salv) = lo_parts_split->get_container( row = 2 column = 1 ).

    " ── Toolbar ──
    CREATE OBJECT mo_toolbar EXPORTING parent = lo_cont_tb.
    DATA lt_tb_events TYPE cntl_simple_events.
    APPEND VALUE #( eventid = cl_gui_toolbar=>m_id_function_selected ) TO lt_tb_events.
    mo_toolbar->set_registered_events( lt_tb_events ).
    SET HANDLER me->on_toolbar_click FOR mo_toolbar.
    mo_toolbar->add_button_group( VALUE ttb_button(
      ( function  = 'REFRESH'
        icon      = CONV #( icon_refresh )
        text      = 'Refresh'
        quickinfo = 'Refresh' )
      ( function  = 'BACK'
        icon      = CONV #( icon_previous_object )
        text      = 'Back'
        quickinfo = 'Back' )
      ( function  = 'SET_BASE'
        icon      = CONV #( icon_header )
        text      = 'Set Base'
        quickinfo = 'Choose Version and Set it Base' )
      ( function  = 'DIFF_TOGGLE'
        icon      = CONV #( icon_compare )
        text      = 'Show Diff'
        quickinfo = 'Show Diff' )
      ( function  = 'COMPACT_TOGGLE'
        icon      = CONV #( icon_collapse_all )
        text      = 'Compact'
        quickinfo = 'Compact' )
      ( function  = 'PANE_TOGGLE'
        icon      = CONV #( ICON_SPOOL_REQUEST )
        text      = 'Inline'
        quickinfo = 'Inline' ) ) ).

    " Sync button texts with initial flag values
    mo_toolbar->set_button_info( EXPORTING fcode = 'DIFF_TOGGLE'
      text = COND #( WHEN mv_show_diff = abap_true THEN 'Show Diff' ELSE 'Show Vers' ) ).
    mo_toolbar->set_button_info( EXPORTING fcode = 'COMPACT_TOGGLE'
      text = COND #( WHEN mv_compact   = abap_true THEN 'Compact'   ELSE 'Full'      ) ).
    mo_toolbar->set_button_info( EXPORTING fcode = 'PANE_TOGGLE'
      text = COND #( WHEN mv_two_pane  = abap_true THEN '2-Pane'    ELSE 'Inline'    ) ).

    " ── SALV ──
    cl_salv_table=>factory(
      EXPORTING
        r_container  = lo_cont_salv
      IMPORTING
        r_salv_table = mo_salv_parts
      CHANGING
        t_table      = mt_parts ).

    " ── columns ──
    DATA(lo_cols) = mo_salv_parts->get_columns( ).
    lo_cols->set_optimize( abap_true ).

    lo_cols->set_color_column( 'ROWCOLOR' ).
    TRY.
        lo_cols->get_column( 'CLASS' )->set_long_text( 'Class' ).
        lo_cols->get_column( 'CLASS' )->set_medium_text( 'Class' ).
        lo_cols->get_column( 'NAME' )->set_long_text( 'Part' ).
        lo_cols->get_column( 'NAME' )->set_medium_text( 'Part' ).
        lo_cols->get_column( 'OBJECT_NAME' )->set_visible( abap_false ).
        lo_cols->get_column( 'EXISTS_FLAG' )->set_visible( abap_false ).
        lo_cols->get_column( 'ROWCOLOR' )->set_visible( abap_false ).
        lo_cols->get_column( 'TYPE' )->set_long_text( 'Type' ).
        lo_cols->get_column( 'TYPE' )->set_output_length( 6 ).
      CATCH cx_salv_not_found. "#EC NO_HANDLER
    ENDTRY.

    " ── display settings ──
    DATA(lo_disp) = mo_salv_parts->get_display_settings( ).
    lo_disp->set_striped_pattern( cl_salv_display_settings=>true ).

    mo_salv_parts->get_functions( )->set_all( abap_false ).

    " ── double-click → load versions ──
    DATA(lo_events) = mo_salv_parts->get_event( ).
    SET HANDLER me->on_part_double_click FOR lo_events.

    mo_salv_parts->display( ).
  ENDMETHOD.


  METHOD build_html_viewer.
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
    cl_salv_table=>factory(
      EXPORTING r_container  = mo_cont_vers
      IMPORTING r_salv_table = mo_salv_vers
      CHANGING  t_table      = mt_versions ).

    " Columns
    DATA(lo_cols) = mo_salv_vers->get_columns( ).
    lo_cols->set_optimize( abap_true ).
    lo_cols->set_color_column( 'ROWCOLOR' ).
    TRY.
        lo_cols->get_column( 'VERSNO'      )->set_visible( abap_false ).
        lo_cols->get_column( 'VERSNO_TEXT' )->set_long_text( 'Version' ).
        lo_cols->get_column( 'VERSNO_TEXT' )->set_medium_text( 'Version' ).
        lo_cols->get_column( 'DATUM'       )->set_long_text( 'Date' ).
        lo_cols->get_column( 'ZEIT'        )->set_long_text( 'Time' ).
        lo_cols->get_column( 'AUTHOR'      )->set_long_text( 'Author' ).
        lo_cols->get_column( 'AUTHOR_NAME' )->set_long_text( 'Name' ).
        lo_cols->get_column( 'KORRNUM'     )->set_long_text( 'Request' ).
        lo_cols->get_column( 'KORR_TEXT'   )->set_long_text( 'Description' ).
        lo_cols->get_column( 'OBJTYPE'     )->set_visible( abap_false ).
        lo_cols->get_column( 'OBJNAME'     )->set_visible( abap_false ).
        lo_cols->get_column( 'ROWCOLOR'    )->set_visible( abap_false ).
      CATCH cx_salv_not_found. "#EC NO_HANDLER
    ENDTRY.

    " Display settings
    DATA(lo_disp) = mo_salv_vers->get_display_settings( ).
    lo_disp->set_striped_pattern( cl_salv_display_settings=>true ).

    mo_salv_vers->get_functions( )->set_all( abap_false ).

    " Multiple row selection for Compare
    mo_salv_vers->get_selections( )->set_selection_mode(
      cl_salv_selections=>row_column ).

    " Double-click event
    SET HANDLER me->on_ver_double_click FOR mo_salv_vers->get_event( ).

    mo_salv_vers->display( ).
  ENDMETHOD.


  METHOD on_part_double_click.
    READ TABLE mt_parts INTO DATA(ls_part) INDEX row.
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
        mo_salv_parts->refresh( ).
        " Auto-open first part
        READ TABLE mt_parts INTO DATA(ls_first_part) INDEX 1.
        IF sy-subrc = 0.
          mv_cur_objtype = ls_first_part-type.
          mv_cur_objname = ls_first_part-object_name.
          load_versions( i_objtype = ls_first_part-type i_objname = ls_first_part-object_name ).
          mo_salv_vers->refresh( ).
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
    mo_salv_vers->refresh( ).

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
    CLEAR mt_versions.

    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd(
          type        = i_objtype
          name        = i_objname
          no_toc      = mv_no_toc
          filter_user = mv_filter_user ).
      CATCH zcx_ave.
        RETURN.
    ENDTRY.

    LOOP AT lo_vrsd->vrsd_list INTO DATA(ls_vrsd).
      TRY.
          DATA(lo_ver) = NEW zcl_ave_version( ls_vrsd ).
          APPEND VALUE ty_version_row(
            versno      = lo_ver->version_number
            versno_text = COND #( WHEN lo_ver->version_number = '99998'
                                  THEN 'Active'
                                  ELSE CONV string( lo_ver->version_number + 0 ) )
            datum       = lo_ver->date
            zeit        = lo_ver->time
            author      = lo_ver->author
            author_name = lo_ver->author_name
            korrnum     = lo_ver->request
            objtype     = lo_ver->objtype
            objname     = lo_ver->objname ) TO mt_versions.
        CATCH zcx_ave.
          " Skip version if metadata fails
      ENDTRY.
    ENDLOOP.

    SORT mt_versions BY versno DESCENDING.
    remove_duplicate_versions( ).

    " Fill TR descriptions from E07T
    DATA lv_korr_text TYPE e07t-as4text.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver>).
      IF <ver>-korrnum IS NOT INITIAL.
        SELECT SINGLE as4text FROM e07t
          WHERE trkorr = @<ver>-korrnum
            AND langu  = @sy-langu
          INTO @lv_korr_text.
        <ver>-korr_text = lv_korr_text.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD update_ver_colors.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<v>).
      CLEAR <v>-rowcolor.
      DATA lv_scol TYPE lvc_s_scol.
      lv_scol-fname     = space.
      lv_scol-color-int = 0.
      lv_scol-color-inv = 0.
      IF <v>-versno = ms_base_ver-versno.
        lv_scol-color-col = 5.   " green = base
        APPEND lv_scol TO <v>-rowcolor.
      ELSEIF <v>-versno = iv_viewed_versno AND iv_viewed_versno <> ms_base_ver-versno.
        lv_scol-color-col = 7.   " light blue = currently viewed
        APPEND lv_scol TO <v>-rowcolor.
      ENDIF.
    ENDLOOP.
    mo_salv_vers->refresh( ).
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

      " Timeout check: if > 3 seconds elapsed, append remaining versions as-is
      GET TIME STAMP FIELD lv_ts_now.
      CALL METHOD cl_abap_tstmp=>subtract
        EXPORTING tstmp1 = lv_ts_now tstmp2 = lv_ts_start
        RECEIVING r_secs = lv_secs.
      IF lv_secs > 3.
        LOOP AT mt_versions INTO DATA(ls_rest) FROM lv_tabix.
          APPEND ls_rest TO lt_result.
        ENDLOOP.
        EXIT.
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


  METHOD on_ver_double_click.
    READ TABLE mt_versions INTO DATA(ls_ver) INDEX row.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mv_viewed_versno = ls_ver-versno.

    IF mv_show_diff = abap_true.
      IF ls_ver-versno = ms_base_ver-versno.
        " Clicked base itself — compare with previous
        READ TABLE mt_versions INTO DATA(ls_prev_base) INDEX row + 1.
        IF sy-subrc = 0.
          show_versions_diff( is_old = ls_prev_base is_new = ls_ver ).
        ELSE.
          show_source( i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno ).
        ENDIF.
      ELSE.
        " Base always on right (is_new)
        show_versions_diff( is_old = ls_ver is_new = ms_base_ver ).
      ENDIF.
    ELSE.
      show_source( i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno ).
    ENDIF.

    update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
  ENDMETHOD.


  METHOD show_source.
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
          " Active/Modified: synthetic VRSD
          ls_vrsd-objtype = i_objtype.
          ls_vrsd-objname = i_objname.
          ls_vrsd-versno  = lv_db_versno.
          ls_vrsd-author  = sy-uname.
          ls_vrsd-datum   = sy-datum.
          ls_vrsd-zeit    = sy-uzeit.
        ENDIF.

        DATA(lo_ver)    = NEW zcl_ave_version( ls_vrsd ).
        DATA(lt_source) = lo_ver->get_source( ).

        Select single as4text into @data(lv_req_text)
          from e07t
         where trkorr = @lo_ver->request
           and  langu = @sy-langu.

        DATA(lv_versno_str) = |{ CONV i( i_versno ) }|.
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
      CHECK ls_part-type <> 'CLSD'.
      IF ls_part-type <> 'METH'.
        CHECK check_part_exists(
                     i_type       = ls_part-type
                     i_name       = CONV #( ls_part-object_name ) ).

      ENDIF.
      DATA ls_part_row TYPE ty_part_row.
      ls_part_row-class       = ls_part-class.
      ls_part_row-name        = ls_part-unit.
      ls_part_row-type        = ls_part-type.
      ls_part_row-object_name = ls_part-object_name.
      ls_part_row-exists_flag = abap_true.
      IF mv_filter_user IS NOT INITIAL.
        IF get_latest_author( i_type = ls_part-type i_name = ls_part-object_name ) = mv_filter_user.
          DATA ls_part_scol TYPE lvc_s_scol.
          ls_part_scol-fname     = space.
          ls_part_scol-color-col = 4.
          ls_part_scol-color-int = 0.
          APPEND ls_part_scol TO ls_part_row-rowcolor.
        ENDIF.
      ENDIF.
      APPEND ls_part_row TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD on_toolbar_click.
    CASE fcode.
      WHEN 'BACK'.
        CHECK mt_parts_backup IS NOT INITIAL.
        mt_parts = mt_parts_backup.
        CLEAR mt_parts_backup.
        mo_salv_parts->refresh( ).

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
                ls_row-object_name = ls_raw-object_name.
                ls_row-exists_flag = lv_exists.
                DATA ls_scol TYPE lvc_s_scol.
                ls_scol-fname = space.
                IF lv_exists = abap_false.
                  ls_scol-color-col = 6.
                  ls_scol-color-int = 1.
                  APPEND ls_scol TO ls_row-rowcolor.
                ELSEIF mv_filter_user IS NOT INITIAL.
                  IF get_latest_author( i_type = ls_raw-type i_name = ls_raw-object_name ) = mv_filter_user.
                    ls_scol-color-col = 4.
                    ls_scol-color-int = 0.
                    APPEND ls_scol TO ls_row-rowcolor.
                  ENDIF.
                ENDIF.
                APPEND ls_row TO mt_parts.
                CLEAR ls_row.
              ENDLOOP.
            ENDIF.
          CATCH zcx_ave.
        ENDTRY.
        mo_salv_parts->refresh( ).
        " Reload versions for current part if one was selected
        IF mv_cur_objtype IS NOT INITIAL.
          load_versions( i_objtype = mv_cur_objtype i_objname = mv_cur_objname ).
          mo_salv_vers->refresh( ).
        ENDIF.

      WHEN 'SET_BASE'.
        DATA(lt_sel_base) = mo_salv_vers->get_selections( )->get_selected_rows( ).
        CHECK lines( lt_sel_base ) = 1.
        ms_base_ver = mt_versions[ lt_sel_base[ 1 ] ].
        " Re-render current viewed version against new base
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
              show_versions_diff( is_old = ls_vw is_new = ms_base_ver ).
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
                    icon = COND #( WHEN mv_two_pane = abap_true
                                    THEN icon_view_hier_list ELSE icon_spool_request )                 ).
        "THEN ICON_overview ELSE 'ICON_SPOOL_REQUEST' )                 ).
        IF mv_show_diff = abap_true AND ms_diff_old IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
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

    ENDCASE.
  ENDMETHOD.


  METHOD on_box_close.
    sender->free( ).
    CLEAR mo_box.
  ENDMETHOD.


  METHOD show_versions_diff.
    ms_diff_old = is_old.
    ms_diff_new = is_new.
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
        set_html( diff_to_html(
          it_diff    = lt_diff
          i_title    = |{ is_new-objtype }: { is_new-objname }|
          i_meta     = lv_meta
          i_two_pane = mv_two_pane
          i_compact  = mv_compact ) ).
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
          IF lt_dp[ lv_cup ] > lt_dp[ lv_cleft ].
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
    " Strip trailing spaces (source lines are padded to 255 chars)
    DATA(lv_old_t) = condense( val = iv_old del = ` ` from = `` ).
    DATA(lv_new_t) = condense( val = iv_new del = ` ` from = `` ).

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
          DATA(lv_max_pair) = COND i( WHEN lv_nd > lv_ni THEN lv_nd ELSE lv_ni ).
          DATA lv_pr TYPE i.
          lv_pr = 1.
          WHILE lv_pr <= lv_max_pair.
            DATA lv_dl2 TYPE string.
            DATA lv_il2 TYPE string.
            " Left = base (is_new = '+'), Right = selected (is_old = '-')
            IF lv_pr <= lv_ni.
              lv_lno_l += 1.
              lv_dl2 = lt_i2[ lv_pr ].
              REPLACE ALL OCCURRENCES OF `&` IN lv_dl2 WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_dl2 WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_dl2 WITH `&gt;`.
            ENDIF.
            IF lv_pr <= lv_nd.
              lv_lno_r += 1.
              lv_il2 = lt_d2[ lv_pr ].
              REPLACE ALL OCCURRENCES OF `&` IN lv_il2 WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_il2 WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_il2 WITH `&gt;`.
            ENDIF.
            DATA(lv_ln_l) = COND string( WHEN lv_pr <= lv_ni THEN |{ lv_lno_l }| ELSE `` ).
            DATA(lv_ln_r) = COND string( WHEN lv_pr <= lv_nd THEN |{ lv_lno_r }| ELSE `` ).
            DATA(lv_bg_l) = COND string( WHEN lv_pr <= lv_ni THEN `background:#eaffea` ELSE `` ).
            DATA(lv_bg_r) = COND string( WHEN lv_pr <= lv_nd THEN `background:#ffecec` ELSE `` ).
            lv_rows = lv_rows &&
              |<tr>| &&
              |<td class="ln" style="{ lv_bg_l }">{ lv_ln_l }</td>| &&
              |<td class="cd" style="{ lv_bg_l }">{ lv_dl2 }</td>| &&
              |<td class="sep"></td>| &&
              |<td class="ln" style="{ lv_bg_r }">{ lv_ln_r }</td>| &&
              |<td class="cd" style="{ lv_bg_r }">{ lv_il2 }</td></tr>|.
            CLEAR: lv_dl2, lv_il2.
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


  METHOD get_latest_author.
    " Active version (versno='00000') represents the most recent unreleased change
    SELECT SINGLE author FROM vrsd
      WHERE objtype = @i_type
        AND objname = @i_name
        AND versno  = '00000'
      INTO @result.
    IF sy-subrc = 0 AND result IS NOT INITIAL.
      RETURN.
    ENDIF.
    " Fall back to highest released versno
    SELECT author FROM vrsd
      WHERE objtype = @i_type
        AND objname = @i_name
        AND versno <> '00000'
      ORDER BY versno DESCENDING
      INTO @result
      UP TO 1 ROWS.
    ENDSELECT.
  ENDMETHOD.
ENDCLASS.
