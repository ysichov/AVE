CLASS zcl_ave_popup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        i_object_type TYPE string
        i_object_name TYPE string.

    METHODS show.

protected section.
  PRIVATE SECTION.

    "──────────── types ─────────────────────────────────────────────
    " Extended parts row: original fields + existence flag + row color
    TYPES:
      BEGIN OF ty_part_row,
        class       type string,
        name        TYPE string,
        type        TYPE versobjtyp,
        object_name TYPE versobjnam,
        exists_flag TYPE abap_bool,
        rowcolor    TYPE lvc_t_scol,
      END OF ty_part_row,
      ty_t_part_row TYPE STANDARD TABLE OF ty_part_row WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_version_row,
        versno      TYPE versno,
        versno_text TYPE string,
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
      BEGIN OF ty_diff_op,
        op(255)   TYPE c,
        text TYPE string,
      END OF ty_diff_op,
      ty_t_diff TYPE STANDARD TABLE OF ty_diff_op WITH DEFAULT KEY.

    "──────────── controls ──────────────────────────────────────────
    CLASS-DATA mv_counter TYPE i.

    DATA mv_object_type TYPE string.
    DATA mv_object_name TYPE string.

    DATA mo_box        TYPE REF TO cl_gui_dialogbox_container.
    DATA mo_split_main TYPE REF TO cl_gui_splitter_container.
    DATA mo_split_top  TYPE REF TO cl_gui_splitter_container.
    DATA mo_cont_parts TYPE REF TO cl_gui_container.
    DATA mo_cont_html  TYPE REF TO cl_gui_container.
    DATA mo_cont_vers  TYPE REF TO cl_gui_container.

    " Left panel: SALV table with the list of object parts
    DATA mo_salv_parts TYPE REF TO cl_salv_table.
    DATA mt_parts      TYPE ty_t_part_row.

    " Right panel: HTML code viewer
    DATA mo_html TYPE REF TO cl_gui_html_viewer.

    " Bottom panel: SALV table with version list
    DATA mo_salv_vers TYPE REF TO cl_salv_table.
    DATA mt_versions  TYPE ty_t_version_row.

    DATA mv_cur_objtype TYPE versobjtyp.
    DATA mv_cur_objname TYPE versobjnam.

    " Backup for Back navigation (one level)
    DATA mt_parts_backup TYPE ty_t_part_row.
    DATA mo_toolbar       TYPE REF TO cl_gui_toolbar.

    "──────────── build ─────────────────────────────────────────────
    METHODS build_layout.
    METHODS build_parts_list.
    METHODS build_html_viewer.
    METHODS build_versions_grid.

    "──────────── events ────────────────────────────────────────────
    METHODS on_part_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.

    METHODS on_toolbar_click
      FOR EVENT function_selected OF cl_gui_toolbar
      IMPORTING fcode.

    METHODS on_ver_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row.

    METHODS on_box_close
      FOR EVENT close OF cl_gui_dialogbox_container
      IMPORTING sender.

    "──────────── logic ─────────────────────────────────────────────
    METHODS check_part_exists
      IMPORTING
        i_type        TYPE versobjtyp
        i_name        TYPE versobjnam
        i_class_name  TYPE seoclsname OPTIONAL
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS is_include_empty
      IMPORTING
        i_type        TYPE versobjtyp
        i_name        TYPE versobjnam
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS get_class_parts
      IMPORTING
        i_name        TYPE versobjnam
      RETURNING
        VALUE(result) TYPE ty_t_part_row
      RAISING
        zcx_ave.

    METHODS load_versions
      IMPORTING
        i_objtype TYPE versobjtyp
        i_objname TYPE versobjnam.

    METHODS remove_duplicate_versions.

    METHODS show_source
      IMPORTING
        i_objtype TYPE versobjtyp
        i_objname TYPE versobjnam
        i_versno  TYPE versno.

    METHODS show_versions_diff
      IMPORTING
        is_old TYPE ty_version_row
        is_new TYPE ty_version_row.

    METHODS set_html
      IMPORTING iv_html TYPE string.

    METHODS source_to_html
      IMPORTING
        it_source TYPE abaptxt255_tab
        i_title   TYPE string
        i_meta    TYPE string OPTIONAL
      RETURNING
        VALUE(rv_html) TYPE string.

    METHODS compute_diff
      IMPORTING
        it_old        TYPE abaptxt255_tab
        it_new        TYPE abaptxt255_tab
      RETURNING
        VALUE(result) TYPE ty_t_diff.

    METHODS char_diff_html
      IMPORTING
        iv_old        TYPE string
        iv_new        TYPE string
        iv_side       TYPE c DEFAULT 'N'
      RETURNING
        VALUE(result) TYPE string.

    METHODS diff_to_html
      IMPORTING
        it_diff       TYPE ty_t_diff
        i_title       TYPE string
        i_meta        TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE string.
ENDCLASS.



CLASS ZCL_AVE_POPUP IMPLEMENTATION.


  METHOD constructor.
    mv_object_type = i_object_type.
    mv_object_name = i_object_name.
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
        DATA(ls_ver) = mt_versions[ 1 ].
        show_source( i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno ).
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
            IF lv_exists = abap_false.
              DATA ls_scol TYPE lvc_s_scol.
              ls_scol-fname     = space.
              ls_scol-color-col = 6.
              ls_scol-color-int = 1.
              APPEND ls_scol TO ls_row-rowcolor.
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
        quickinfo = 'Reload parts and versions' )
      ( function  = 'BACK'
        icon      = CONV #( icon_previous_object )
        text      = 'Back'
        quickinfo = 'Back to previous list' )
      ( function  = 'COMPARE'
        icon      = CONV #( icon_compare )
        text      = 'Compare'
        quickinfo = 'Compare two selected versions' ) ) ).

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
    TRY.
        lo_cols->get_column( 'VERSNO'      )->set_visible( abap_false ).
        lo_cols->get_column( 'VERSNO_TEXT' )->set_long_text( 'Version' ).
        lo_cols->get_column( 'VERSNO_TEXT' )->set_medium_text( 'Version' ).
        lo_cols->get_column( 'DATUM'       )->set_long_text( 'Date' ).
        lo_cols->get_column( 'ZEIT'        )->set_long_text( 'Time' ).
        lo_cols->get_column( 'AUTHOR'      )->set_long_text( 'Author' ).
        lo_cols->get_column( 'AUTHOR_NAME' )->set_long_text( 'Name' ).
        lo_cols->get_column( 'KORRNUM'     )->set_long_text( 'Request' ).
        lo_cols->get_column( 'OBJTYPE'     )->set_visible( abap_false ).
        lo_cols->get_column( 'OBJNAME'     )->set_visible( abap_false ).
      CATCH cx_salv_not_found. "#EC NO_HANDLER
    ENDTRY.

    " Display settings
    DATA(lo_disp) = mo_salv_vers->get_display_settings( ).
    lo_disp->set_striped_pattern( cl_salv_display_settings=>true ).

    mo_salv_vers->get_functions( )->set_all( abap_false ).

    " Multiple row selection for Compare
    mo_salv_vers->get_selections( )->set_selection_mode(
      cl_salv_selections=>multiple ).

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
    mo_salv_vers->refresh( ).

    " Automatically open the latest version
    IF mt_versions IS NOT INITIAL.
      DATA(ls_latest) = mt_versions[ 1 ].
      show_source(
        i_objtype = ls_latest-objtype
        i_objname = ls_latest-objname
        i_versno  = ls_latest-versno ).
    ENDIF.
  ENDMETHOD.


  METHOD load_versions.
    CLEAR mt_versions.

    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd(
          type = i_objtype
          name = i_objname ).
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
  ENDMETHOD.


  METHOD remove_duplicate_versions.
    DATA lt_result   TYPE ty_t_version_row.
    DATA lt_prev_src TYPE abaptxt255_tab.
    DATA lt_vrsd     TYPE vrsd_tab.

    " Process from oldest (00001) to newest
    SORT mt_versions BY versno ASCENDING.

    LOOP AT mt_versions INTO DATA(ls_ver).
      DATA(lv_tabix) = sy-tabix.
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

    " Restore descending order for display
    SORT lt_result BY versno DESCENDING.
    mt_versions = lt_result.
  ENDMETHOD.


  METHOD on_ver_double_click.
    READ TABLE mt_versions INTO DATA(ls_ver) INDEX row.
    IF sy-subrc <> 0. RETURN. ENDIF.

    show_source(
      i_objtype = ls_ver-objtype
      i_objname = ls_ver-objname
      i_versno  = ls_ver-versno ).
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

        DATA(lv_meta) =
          |Ver: { i_versno }  | &&
          |{ lo_ver->date } { lo_ver->time }  | &&
          |{ lo_ver->author }| &&
          COND string( WHEN lo_ver->author_name <> lo_ver->author
                       THEN | ({ lo_ver->author_name })| ELSE `` ) &&
          COND string( WHEN lo_ver->request IS NOT INITIAL
                       THEN |  { lo_ver->request }| ELSE `` ).

        " ── Diff against previous (older) version ───────────────────
        DATA lv_idx TYPE i.
        LOOP AT mt_versions INTO DATA(ls_mv) WHERE versno = i_versno.
          lv_idx = sy-tabix.
          EXIT.
        ENDLOOP.
        IF lv_idx > 0 AND lv_idx < lines( mt_versions ).
          " Next index in DESC table = older version
          DATA(ls_cur_ver) = mt_versions[ lv_idx ].
          DATA(ls_prev_ver) = mt_versions[ lv_idx + 1 ].
          show_versions_diff( is_old = ls_prev_ver is_new = ls_cur_ver ).
          RETURN.
        ENDIF.

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
      " Class parts (METH, CLSD, CPUB etc.) are not standalone TADIR objects –
      " existence check is not applicable here.
      IF ls_part-type <> 'METH'.
        CHECK is_include_empty( i_type = ls_part-type i_name = ls_part-object_name ) = abap_false.
      ENDIF.
      APPEND VALUE ty_part_row(
        class       = ls_part-class
        name        = ls_part-unit
        type        = ls_part-type
        object_name = ls_part-object_name
        exists_flag = abap_true ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_include_empty.
    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd( type = i_type name = i_name ).
        IF lo_vrsd->vrsd_list IS INITIAL.
          result = abap_true.
          RETURN.
        ENDIF.
        DATA(lt_source) = NEW zcl_ave_version( lo_vrsd->vrsd_list[ 1 ] )->get_source( ).
      CATCH zcx_ave cx_root.
        result = abap_true.
        RETURN.
    ENDTRY.
    IF lines( lt_source ) <= 1.
      result = abap_true.
      RETURN.
    ENDIF.
    " Empty if every non-blank line starts with *
    LOOP AT lt_source INTO DATA(ls_line).
      DATA(lv_trimmed) = condense( val = CONV string( ls_line ) ).
      IF lv_trimmed IS NOT INITIAL AND lv_trimmed(1) <> '*'.
        RETURN.  " has real content
      ENDIF.
    ENDLOOP.
    result = abap_true.
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
                IF lv_exists = abap_false.
                  DATA ls_scol TYPE lvc_s_scol.
                  ls_scol-fname     = space.
                  ls_scol-color-col = 6.
                  ls_scol-color-int = 1.
                  APPEND ls_scol TO ls_row-rowcolor.
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

      WHEN 'COMPARE'.
        " Get selected rows – exactly 2 required
        DATA(lt_sel) = mo_salv_vers->get_selections( )->get_selected_rows( ).
        IF lines( lt_sel ) <> 2.
          set_html(
            |<html><body style="font:13px Consolas,sans-serif;padding:24px;color:#666">| &&
            |<h3 style="color:#888">Select exactly 2 versions to compare</h3>| &&
            |</body></html>| ).
          RETURN.
        ENDIF.
        " Load sources for both selected rows (order by versno: older first)
        DATA(lv_idx1) = lt_sel[ 1 ].
        DATA(lv_idx2) = lt_sel[ 2 ].
        DATA(ls_v1) = mt_versions[ lv_idx1 ].
        DATA(ls_v2) = mt_versions[ lv_idx2 ].
        " Ensure ls_v1 = older (smaller versno), ls_v2 = newer
        IF ls_v1-versno > ls_v2-versno.
          DATA(ls_tmp) = ls_v1. ls_v1 = ls_v2. ls_v2 = ls_tmp.
        ENDIF.
        show_versions_diff( is_old = ls_v1 is_new = ls_v2 ).
    ENDCASE.
  ENDMETHOD.


  METHOD on_box_close.
    sender->free( ).
    CLEAR mo_box.
  ENDMETHOD.


  METHOD show_versions_diff.
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
        DATA(lv_meta)  = |{ is_old-versno_text } → { is_new-versno_text }|.
        set_html( diff_to_html(
          it_diff = lt_diff
          i_title = |{ is_new-objtype }: { is_new-objname }|
          i_meta  = lv_meta ) ).
      CATCH cx_root.
        set_html( |<html><body style="padding:24px;font:13px Consolas;color:#c00">| &&
          |Error loading versions for comparison.</body></html>| ).
    ENDTRY.
  ENDMETHOD.


  METHOD compute_diff.
    " Line-level LCS diff. Falls back to all-delete/all-insert if > 500 lines.
    DATA(lv_nold) = lines( it_old ).
    DATA(lv_nnew) = lines( it_new ).

    IF lv_nold > 500 OR lv_nnew > 500.
      " Fallback: all old lines deleted, all new lines inserted
      LOOP AT it_old INTO DATA(ls_old_fb).
        APPEND VALUE ty_diff_op( op = '-' text = CONV string( ls_old_fb ) ) TO result.
      ENDLOOP.
      LOOP AT it_new INTO DATA(ls_new_fb).
        APPEND VALUE ty_diff_op( op = '+' text = CONV string( ls_new_fb ) ) TO result.
      ENDLOOP.
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

    " Scan diff ops, grouping consecutive '-' and '+' blocks
    DATA lv_pos   TYPE i VALUE 1.
    DATA lv_total TYPE i.
    lv_total = lines( it_diff ).

    WHILE lv_pos <= lv_total.
      READ TABLE it_diff INTO DATA(ls_cur) INDEX lv_pos.

      IF ls_cur-op = '='.
        lv_lno += 1.
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
ENDCLASS.
