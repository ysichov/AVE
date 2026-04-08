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
        rowcolor    TYPE lvc_s_scol,
      END OF ty_part_row,
      ty_t_part_row TYPE STANDARD TABLE OF ty_part_row WITH DEFAULT KEY.

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

    " Bottom panel: ALV grid with version list
    DATA mo_grid_vers TYPE REF TO cl_gui_alv_grid.
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
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row.

    METHODS on_box_close
      FOR EVENT close OF cl_gui_dialogbox_container
      IMPORTING sender.

    "──────────── logic ─────────────────────────────────────────────
    METHODS check_part_exists
      IMPORTING
        i_type        TYPE versobjtyp
        i_name        TYPE versobjnam
      RETURNING
        VALUE(result) TYPE abap_bool.

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
        it_source TYPE abaptxt255_tab
        i_title   TYPE string
        i_meta    TYPE string OPTIONAL
      RETURNING
        VALUE(rv_html) TYPE string.
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
    cl_gui_cfw=>flush( ).
  ENDMETHOD.


  METHOD build_layout.
    DATA lv_pos TYPE i.

    ADD 1 TO mv_counter.
    lv_pos = 50 - 5 * ( mv_counter DIV 5 ) - ( mv_counter MOD 5 ) * 5.

    CREATE OBJECT mo_box
      EXPORTING
        width                       = 1300
        height                      = 850
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

    " Outer: top 70% (parts + html) | bottom 30% (versions)
    CREATE OBJECT mo_split_main
      EXPORTING parent = mo_box rows = 2 columns = 1.
    mo_split_main->set_row_height( id = 1 height = 70 ).
    mo_split_main->set_row_height( id = 2 height = 30 ).

    DATA(lo_top) = mo_split_main->get_container( row = 1 column = 1 ).
    mo_cont_vers = mo_split_main->get_container( row = 2 column = 1 ).

    " Inner: left 30% (parts list) | right 70% (html viewer)
    CREATE OBJECT mo_split_top
      EXPORTING parent = lo_top rows = 1 columns = 2.
    mo_split_top->set_column_width( id = 1 width = 30 ).
    mo_split_top->set_column_width( id = 2 width = 70 ).

    mo_cont_parts = mo_split_top->get_container( row = 1 column = 1 ).
    mo_cont_html  = mo_split_top->get_container( row = 1 column = 2 ).
  ENDMETHOD.


  METHOD build_parts_list.
    " Load raw parts via object handler factory, then check existence
    TRY.
        DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
          object_type = mv_object_type
          object_name = CONV #( mv_object_name ) ).

        DATA(lv_is_tr) = boolc( mv_object_type = zcl_ave_object_factory=>gc_type-tr ).
        LOOP AT lo_obj->get_parts( ) INTO DATA(ls_raw).
          DATA(lv_exists) = COND abap_bool(
            WHEN lv_is_tr = abap_true
            THEN check_part_exists( i_type = ls_raw-type i_name = ls_raw-object_name )
            ELSE abap_true ).
          APPEND VALUE ty_part_row(
            class       = ls_raw-class
            name        = ls_raw-unit
            type        = ls_raw-type
            object_name = ls_raw-object_name
            exists_flag = lv_exists
            rowcolor    = COND #(
              WHEN lv_exists = abap_false
              THEN VALUE lvc_s_scol( col = 6 int = 1 )
              ELSE VALUE lvc_s_scol( ) ) ) TO mt_parts.
        ENDLOOP.
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
      ( function  = 'BACK'
        icon      = CONV #( icon_previous_object )
        text      = 'Back'
        quickinfo = 'Back to previous list' ) ) ).

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
    DATA lt_fcat TYPE lvc_t_fcat.

    DEFINE _fc.
      APPEND VALUE lvc_s_fcat(
        fieldname = &1  coltext = &2  outputlen = &3 ) TO lt_fcat.
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
      EXPORTING i_parent = mo_cont_vers.

    SET HANDLER me->on_ver_double_click FOR mo_grid_vers.


    mo_grid_vers->set_table_for_first_display(
      EXPORTING
        is_layout       = VALUE lvc_s_layo(
                            zebra      = abap_true
                            sel_mode   = 'D'
                            cwidth_opt = 'X' )
      CHANGING
        it_fieldcatalog = lt_fcat
        it_outtab       = mt_versions ).
  ENDMETHOD.


  METHOD on_part_double_click.
    READ TABLE mt_parts INTO DATA(ls_part) INDEX row.
    IF sy-subrc <> 0. RETURN. ENDIF.

    " ── CLAS row (from TR) → drill into class parts ──
    IF ls_part-type = 'CLAS'.
      mt_parts_backup = mt_parts.
      CLEAR mt_parts.
      TRY.
          DATA(lo_cls) = NEW zcl_ave_object_factory( )->get_instance(
            object_type = 'CLAS'
            object_name = CONV #( ls_part-object_name ) ).
          LOOP AT lo_cls->get_parts( ) INTO DATA(ls_cls).
            CHECK check_part_exists( i_type = ls_cls-type i_name = ls_cls-object_name ) = abap_true.
            APPEND VALUE ty_part_row(
              class       = ls_cls-class
              name        = ls_cls-unit
              type        = ls_cls-type
              object_name = ls_cls-object_name
              exists_flag = abap_true
            ) TO mt_parts.
          ENDLOOP.
        CATCH zcx_ave.
      ENDTRY.
      mo_salv_parts->refresh( ).
      RETURN.
    ENDIF.

    mv_cur_objtype = ls_part-type.
    mv_cur_objname = ls_part-object_name.

    " ── Object doesn't exist in system ────────────────────────────
    IF ls_part-exists_flag = abap_false.
      " Still load versions so user can see history in grid below
      load_versions( i_objtype = ls_part-type i_objname = ls_part-object_name ).
      mo_grid_vers->refresh_table_display( ).

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
    mo_grid_vers->refresh_table_display( ).

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
  ENDMETHOD.


  METHOD on_ver_double_click.
    READ TABLE mt_versions INTO DATA(ls_ver) INDEX e_row-index.
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
    CASE i_type.
      WHEN 'REPS' OR 'CINC' OR 'CDEF'.
        " Program/include → check TRDIR
        SELECT SINGLE @abap_true FROM trdir
          WHERE name = @i_name
          INTO @result.

      WHEN 'METH'.
        " First 30 chars = class name, rest = method name
        DATA(lv_cls_meth) = CONV seoclsname( i_name(30) ).
        CONDENSE lv_cls_meth.
        SELECT SINGLE @abap_true FROM tadir
          WHERE pgmid    = 'R3TR'
            AND object   = 'CLAS'
            AND obj_name = @lv_cls_meth
            AND delflag  = ' '
          INTO @result.

      WHEN 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI'.
        " Class sections → check class in TADIR
        SELECT SINGLE @abap_true FROM tadir
          WHERE pgmid    = 'R3TR'
            AND object   = 'CLAS'
            AND obj_name = @i_name
            AND delflag  = ' '
          INTO @result.

      WHEN 'FUNC'.
        CALL FUNCTION 'FUNCTION_EXISTS'
          EXPORTING
            funcname           = CONV rs38l_fnam( i_name )
          EXCEPTIONS
            function_not_exist = 1
            OTHERS             = 2.
        result = boolc( sy-subrc = 0 ).

      WHEN OTHERS.
        " Generic: check TADIR by obj_name regardless of object type
        SELECT SINGLE @abap_true FROM tadir
          WHERE obj_name = @i_name
            AND delflag  = ' '
          INTO @result.
    ENDCASE.

    IF result IS INITIAL.
      result = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD on_toolbar_click.
    CHECK fcode = 'BACK' AND mt_parts_backup IS NOT INITIAL.
    mt_parts = mt_parts_backup.
    CLEAR mt_parts_backup.
    mo_salv_parts->refresh( ).
  ENDMETHOD.


  METHOD on_box_close.
    sender->free( ).
    CLEAR mo_box.
  ENDMETHOD.
ENDCLASS.
