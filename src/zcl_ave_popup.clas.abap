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

  PRIVATE SECTION.

    "──────────── types ─────────────────────────────────────────────
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
    DATA mt_parts      TYPE zif_ave_object=>ty_t_part.

    " Right panel: HTML code viewer
    DATA mo_html TYPE REF TO cl_gui_html_viewer.

    " Bottom panel: ALV grid with version list
    DATA mo_grid_vers TYPE REF TO cl_gui_alv_grid.
    DATA mt_versions  TYPE ty_t_version_row.

    DATA mv_cur_objtype TYPE versobjtyp.
    DATA mv_cur_objname TYPE versobjnam.

    "──────────── build ─────────────────────────────────────────────
    METHODS build_layout.
    METHODS build_parts_list.
    METHODS build_html_viewer.
    METHODS build_versions_grid.

    "──────────── events ────────────────────────────────────────────
    METHODS on_part_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.

    METHODS on_ver_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row.

    METHODS on_box_close
      FOR EVENT close OF cl_gui_dialogbox_container
      IMPORTING sender.

    "──────────── logic ─────────────────────────────────────────────
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


CLASS zcl_ave_popup IMPLEMENTATION.

  "════════════════════════════════════════════════════════════════
  METHOD constructor.
    mv_object_type = i_object_type.
    mv_object_name = i_object_name.
  ENDMETHOD.

  "════════════════════════════════════════════════════════════════
  METHOD show.
    build_layout( ).
    build_parts_list( ).
    build_html_viewer( ).
    build_versions_grid( ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  "════════════════════════════════════════════════════════════════
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

  "════════════════════════════════════════════════════════════════
  METHOD build_parts_list.
    " Load parts via object handler factory
    TRY.
        DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
          object_type = mv_object_type
          object_name = CONV #( mv_object_name ) ).
        mt_parts = lo_obj->get_parts( ).
      CATCH zcx_ave.
        " leave mt_parts empty – no crash
    ENDTRY.

    " Create SALV table embedded in the left container
    cl_salv_table=>factory(
      EXPORTING
        r_container  = mo_cont_parts
      IMPORTING
        r_salv_table = mo_salv_parts
      CHANGING
        t_table      = mt_parts ).

    " ── columns ──
    DATA(lo_cols) = mo_salv_parts->get_columns( ).
    lo_cols->set_optimize( abap_true ).
    TRY.
        lo_cols->get_column( 'NAME' )->set_long_text( 'Part' ).
        lo_cols->get_column( 'NAME' )->set_medium_text( 'Part' ).
        lo_cols->get_column( 'OBJECT_NAME' )->set_visible( abap_false ).
        lo_cols->get_column( 'TYPE' )->set_long_text( 'Type' ).
        lo_cols->get_column( 'TYPE' )->set_output_length( 6 ).
      CATCH cx_salv_not_found. "#EC NO_HANDLER
    ENDTRY.

    " ── display settings ──
    DATA(lo_disp) = mo_salv_parts->get_display_settings( ).
    lo_disp->set_striped_pattern( cl_salv_display_settings=>true ).

    " ── no toolbar needed ──
    DATA(lo_func) = mo_salv_parts->get_functions( ).
    lo_func->set_all( abap_false ).

    " ── double-click → load versions ──
    DATA(lo_events) = mo_salv_parts->get_event( ).
    SET HANDLER me->on_part_double_click FOR lo_events.

    mo_salv_parts->display( ).
  ENDMETHOD.

  "════════════════════════════════════════════════════════════════
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
      |body\{margin:0;background:#1e1e1e;color:#555;| &&
      |font:13px/1.6 Consolas,monospace;| &&
      |display:flex;align-items:center;justify-content:center;height:100vh\}| &&
      |</style></head><body>| &&
      |<div>Double-click a part (left) to see versions, | &&
      |then double-click a version (below) to see code.</div>| &&
      |</body></html>| ).
  ENDMETHOD.

  "════════════════════════════════════════════════════════════════
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

    " Register double_click explicitly (required for cl_gui_alv_grid)
    DATA lt_events TYPE cntl_simple_events.
    mo_grid_vers->get_registered_events( IMPORTING events = lt_events ).
    APPEND VALUE cntl_simple_event(
      eventid    = cl_gui_alv_grid=>mc_evt_double_click
      appl_event = abap_true ) TO lt_events.
    mo_grid_vers->set_registered_events( EXPORTING events = lt_events ).

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

  "════════════════════════════════════════════════════════════════
  METHOD on_part_double_click.
    READ TABLE mt_parts INTO DATA(ls_part) INDEX row.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mv_cur_objtype = ls_part-type.
    mv_cur_objname = ls_part-object_name.

    load_versions(
      i_objtype = ls_part-type
      i_objname = ls_part-object_name ).

    mo_grid_vers->refresh_table_display( ).
  ENDMETHOD.

  "════════════════════════════════════════════════════════════════
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

  "════════════════════════════════════════════════════════════════
  METHOD on_ver_double_click.
    READ TABLE mt_versions INTO DATA(ls_ver) INDEX e_row-index.
    IF sy-subrc <> 0. RETURN. ENDIF.

    show_source(
      i_objtype = ls_ver-objtype
      i_objname = ls_ver-objname
      i_versno  = ls_ver-versno ).
  ENDMETHOD.

  "════════════════════════════════════════════════════════════════
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

  "════════════════════════════════════════════════════════════════
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
      |body\{background:#1e1e1e;color:#d4d4d4;font:12px/1.5 Consolas,monospace\}| &&
      |.hdr\{background:#252526;padding:5px 12px;border-bottom:1px solid #3c3c3c;| &&
             |color:#9cdcfe;font-size:11px;display:flex;gap:16px;flex-wrap:wrap\}| &&
      |.ttl\{color:#4ec9b0;font-weight:bold\}| &&
      |.meta\{color:#858585\}| &&
      |table\{border-collapse:collapse;width:100%\}| &&
      |tr:hover td\{background:#2a2d2e\}| &&
      |.ln\{color:#858585;text-align:right;padding:1px 10px 1px 5px;| &&
           |user-select:none;min-width:42px;border-right:1px solid #3c3c3c;| &&
           |white-space:nowrap\}| &&
      |.cd\{padding:1px 8px;white-space:pre\}| &&
      |</style></head><body>| &&
      |<div class="hdr">| &&
      |<span class="ttl">| && i_title && |</span>| &&
      |<span class="meta">| && i_meta  && |</span>| &&
      |</div>| &&
      |<table><tbody>| && lv_rows &&
      |</tbody></table></body></html>|.
  ENDMETHOD.

  "════════════════════════════════════════════════════════════════
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

  "════════════════════════════════════════════════════════════════
  METHOD on_box_close.
    sender->free( ).
    CLEAR mo_box.
  ENDMETHOD.

ENDCLASS.
