class ZCL_AVE_POPUP definition
  public
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

    " double_click of cl_gui_alv_grid must be registered explicitly,
    " same as node_double_click of cl_gui_alv_tree.
    DATA: lt_events TYPE cntl_simple_events,
          ls_event  TYPE cntl_simple_event.
    mo_grid_vers->get_registered_events( IMPORTING events = lt_events ).
    ls_event-eventid    = cl_gui_alv_grid=>mc_evt_double_click.
    ls_event-appl_event = abap_true.
    APPEND ls_event TO lt_events.
    mo_grid_vers->set_registered_events( EXPORTING events = lt_events ).

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
    " Load HTML string into the HTML viewer.
    " w3html-line is TYPE STRING in modern SAP, so one row is sufficient.
    DATA lt_html TYPE w3htmltab.
    APPEND VALUE #( line = iv_html ) TO lt_html.

    mo_html->load_data(
      EXPORTING
        type       = 'TEXT'
        subtype    = 'HTML'
      CHANGING
        data_table = lt_html ).

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
