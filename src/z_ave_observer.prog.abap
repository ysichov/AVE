*&---------------------------------------------------------------------*
*& Report Z_AVE_OBSERVER
*&---------------------------------------------------------------------*
*& Observes workbench (K) transport requests changed/released in a given
*& date range (with package and user filters) and lets the user browse
*& the objects of every K request with a quick diff indicator.
*&
*& Built on the global zcl_ave_* classes:
*&  - object list of a request:  zcl_ave_object_tr / zcl_ave_object_clas
*&  - version pair (new/old):    zcl_ave_version_list=>load
*&  - source loading:            zcl_ave_version2
*&  - quick diff:                plain comparison of the two source tables
*&  - real diff on click:        zcl_ave_popup_diff + zcl_ave_popup_html
*&---------------------------------------------------------------------*
REPORT z_ave_observer.


PARAMETERS: p_from TYPE begda DEFAULT sy-datum,
            p_to   TYPE endda DEFAULT sy-datum.

DATA gv_devclass TYPE tadir-devclass.
DATA gv_user     TYPE e070-as4user.

SELECT-OPTIONS s_pack FOR gv_devclass.
SELECT-OPTIONS s_user FOR gv_user.

TYPES gty_t_devclass_range TYPE RANGE OF devclass.
TYPES gty_t_user_range TYPE RANGE OF e070-as4user.

TYPES gty_t_trkorr TYPE STANDARD TABLE OF trkorr WITH DEFAULT KEY.

"! One K request header shown in the navigation, with the S/R child tasks
"! of the selected user(s) whose objects are virtually assembled under it.
TYPES: BEGIN OF gty_tr,
         trkorr  TYPE trkorr,
         as4text TYPE as4text,
         as4user TYPE e070-as4user,   " task owner (the selected user)
         as4date TYPE as4date,
         as4time TYPE as4time,
         tasks   TYPE gty_t_trkorr,   " user's S/R tasks in the period
       END OF gty_tr,
       gty_t_tr TYPE STANDARD TABLE OF gty_tr WITH DEFAULT KEY.

"! One object part row of a K request.
TYPES: BEGIN OF gty_obj,
         idx      TYPE i,
         trkorr   TYPE trkorr,                            " parent K request
         as4date  TYPE as4date,                           " K request date
         as4time  TYPE as4time,
         as4text  TYPE as4text,
         as4user  TYPE e070-as4user,
         tasks    TYPE gty_t_trkorr,                      " user's S/R tasks (scope for load)
         part     TYPE zif_ave_object=>ty_part,           " versionable part
         new_ver  TYPE zif_ave_popup_types=>ty_version_row,
         old_ver  TYPE zif_ave_popup_types=>ty_version_row,
         has_pair TYPE abap_bool,    " a target version was found
         has_diff TYPE abap_bool,    " quick diff: the two sources differ
         diff_loc TYPE i,            " line-count delta new - old
       END OF gty_obj,
       gty_t_obj TYPE STANDARD TABLE OF gty_obj WITH DEFAULT KEY.

*&---------------------------------------------------------------------*
*& lcl_html - navigation page rendering + viewer helper
*&---------------------------------------------------------------------*
CLASS lcl_html DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    "! Builds the left navigation page: K request headers + object links.
    CLASS-METHODS build_nav
      IMPORTING it_objs       TYPE gty_t_obj
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS esc
      IMPORTING iv_in         TYPE string
      RETURNING VALUE(result) TYPE string.

    "! Loads an HTML string into a viewer.
    CLASS-METHODS show_html
      IMPORTING io_viewer TYPE REF TO cl_gui_html_viewer
                iv_html   TYPE string.
ENDCLASS.

CLASS lcl_html IMPLEMENTATION.

  METHOD esc.
    result = iv_in.
    REPLACE ALL OCCURRENCES OF `&` IN result WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN result WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN result WITH `&gt;`.
  ENDMETHOD.

  METHOD build_nav.
    DATA lv_body      TYPE string.
    DATA lv_curr_date TYPE as4date.
    DATA lv_curr_tr   TYPE trkorr.

    LOOP AT it_objs INTO DATA(ls_o).
      IF ls_o-as4date <> lv_curr_date.
        lv_curr_date = ls_o-as4date.
        CLEAR lv_curr_tr.
        DATA(lv_day_loc) = 0.
        LOOP AT it_objs INTO DATA(ls_day_o) WHERE as4date = ls_o-as4date.
          lv_day_loc = lv_day_loc + ls_day_o-diff_loc.
        ENDLOOP.
        DATA(lv_day) = |{ ls_o-as4date+6(2) }.{ ls_o-as4date+4(2) }.{ ls_o-as4date(4) }|.
        lv_body = lv_body &&
          |<div class="day"><span>{ lv_day }</span><span class="loc">TOTAL { lv_day_loc } LOC</span></div>|.
      ENDIF.

      IF ls_o-trkorr <> lv_curr_tr.
        lv_curr_tr = ls_o-trkorr.
        DATA(lv_tr_loc) = 0.
        LOOP AT it_objs INTO DATA(ls_tr_o) WHERE trkorr = ls_o-trkorr.
          lv_tr_loc = lv_tr_loc + ls_tr_o-diff_loc.
        ENDLOOP.
        DATA(lv_dt) = |{ ls_o-as4date+6(2) }.{ ls_o-as4date+4(2) }.{ ls_o-as4date(4) }| &&
                      | { ls_o-as4time(2) }:{ ls_o-as4time+2(2) }:{ ls_o-as4time+4(2) }|.
        lv_body = lv_body &&
          |<div class="tr"><span class="trk">K { ls_o-trkorr }</span>| &&
          |<span class="loc">TOTAL { lv_tr_loc } LOC</span>| &&
          |<span class="tru">{ esc( CONV string( ls_o-as4user ) ) }</span>| &&
          |<span class="trd">{ lv_dt }</span>| &&
          |<div class="trt">{ esc( CONV string( ls_o-as4text ) ) }</div></div>|.
      ENDIF.

      DATA(lv_label) = COND string(
        WHEN ls_o-part-class IS NOT INITIAL AND ls_o-part-type = 'METH'
        THEN |{ ls_o-part-type } { esc( ls_o-part-class ) }->{ esc( ls_o-part-unit ) }|
        ELSE |{ ls_o-part-type } { esc( CONV string( ls_o-part-object_name ) ) }| ).

      " Only changed objects reach the navigation - always show the diff link.
      lv_body = lv_body &&
        |<div class="obj">| &&
        |<a href="sapevent:src?idx={ ls_o-idx }">{ lv_label }</a>| &&
        | <a class="diff" href="sapevent:diff?idx={ ls_o-idx }">[DIFF { ls_o-diff_loc } LOC]</a>| &&
        |</div>|.
    ENDLOOP.

    IF lv_body IS INITIAL.
      lv_body = |<div class="empty">No K requests with changed objects in the selected period.</div>|.
    ENDIF.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#fff;color:#1e1e1e;font:12px/1.5 Consolas,monospace;padding:6px\}| &&
      |.day\{margin:12px 0 4px;padding:3px 6px;background:#f7f7f7;| &&
           |border-bottom:1px solid #ddd;color:#333;font-weight:bold\}| &&
      |.tr\{margin:10px 0 2px;padding:4px 6px;background:#eef3fa;| &&
           |border-left:3px solid #0066aa\}| &&
      |.trk\{color:#0066aa;font-weight:bold;margin-right:10px\}| &&
      |.loc\{color:#a33;font-weight:bold;margin-right:10px\}| &&
      |.tru\{color:#0a7d28;font-weight:bold;margin-right:10px\}| &&
      |.trd\{color:#888\}| &&
      |.trt\{color:#444;margin-top:2px\}| &&
      |.obj\{padding:1px 6px 1px 18px\}| &&
      |.obj a\{color:#1a5fb4;text-decoration:none\}| &&
      |.obj a:hover\{text-decoration:underline\}| &&
      |.diff\{color:#a33;margin-left:8px\}| &&
      |.nodiff\{color:#aaa;margin-left:8px\}| &&
      |.dim\{color:#aaa\}| &&
      |.empty\{color:#888;padding:20px\}| &&
      |</style></head><body>| && lv_body && |</body></html>|.
  ENDMETHOD.

  METHOD show_html.
    CHECK io_viewer IS BOUND.
    DATA lt_html TYPE w3htmltab.
    DATA lv_url TYPE w3url.
    DATA lv_offset TYPE i.
    DATA(lv_len) = strlen( iv_html ).
    DATA lv_chunk TYPE i.
    WHILE lv_offset < lv_len.
      lv_chunk = COND #( WHEN lv_len - lv_offset > 255 THEN 255 ELSE lv_len - lv_offset ).
      APPEND VALUE #( line = iv_html+lv_offset(lv_chunk) ) TO lt_html.
      lv_offset = lv_offset + lv_chunk.
    ENDWHILE.
    io_viewer->load_data(
      IMPORTING assigned_url = lv_url
      CHANGING  data_table   = lt_html
      EXCEPTIONS OTHERS      = 1 ).
    CHECK sy-subrc = 0.
    io_viewer->show_url( url = lv_url ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& lcl_app - selection, layout, event handling
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS run
      IMPORTING iv_from TYPE begda
                iv_to   TYPE endda
                it_devclass TYPE gty_t_devclass_range
                it_user     TYPE gty_t_user_range.

  PRIVATE SECTION.
    DATA mt_objs    TYPE gty_t_obj.
    DATA mo_box     TYPE REF TO cl_gui_dialogbox_container.
    DATA mo_split   TYPE REF TO cl_gui_splitter_container.
    DATA mo_rsplit  TYPE REF TO cl_gui_splitter_container.
    DATA mo_nav     TYPE REF TO cl_gui_html_viewer.
    DATA mo_editor  TYPE REF TO cl_gui_abapedit.
    DATA mo_diff    TYPE REF TO cl_gui_html_viewer.

    "! Selects the user's S/R tasks of the period and groups them by parent K.
    "! The user filter applies to the task owner only - the K owner is often
    "! someone else (e.g. a transport coordinator).
    METHODS collect_k_requests
      IMPORTING iv_from       TYPE begda
                iv_to         TYPE endda
                it_user       TYPE gty_t_user_range
      RETURNING VALUE(result) TYPE gty_t_tr.

    "! Expands every K request into versionable parts via the AVE object
    "! handlers (classes are expanded into their technical parts).
    METHODS collect_objects
      IMPORTING iv_from TYPE begda
                iv_to   TYPE endda
                it_devclass TYPE gty_t_devclass_range
                it_user     TYPE gty_t_user_range.

    "! TADIR package check for one part (class parts map to CLAS, REPS to PROG).
    METHODS is_package_selected
      IMPORTING is_part            TYPE zif_ave_object=>ty_part
                it_devclass        TYPE gty_t_devclass_range
      RETURNING VALUE(rv_selected) TYPE abap_bool.

    "! Quick diff for the navigation: the version pair (new/old) comes from
    "! zcl_ave_version_list=>load - it trims the versions to the selected K
    "! and does the full S/T/K mapping. Quick = no compute_diff here, only
    "! a plain comparison of the two source tables.
    METHODS precompute_quick_diffs.

    "! Loads the source of one resolved version row (local or remote).
    METHODS load_version_source
      IMPORTING is_part       TYPE zif_ave_object=>ty_part
                is_ver        TYPE zif_ave_popup_types=>ty_version_row
      RETURNING VALUE(result) TYPE abaptxt255_tab.

    METHODS build_layout.
    METHODS show_source IMPORTING is_obj TYPE gty_obj.
    METHODS show_diff   IMPORTING is_obj TYPE gty_obj.
    METHODS show_right_source.
    METHODS show_right_diff.

    METHODS on_sapevent
      FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING action getdata.

    METHODS on_box_close
      FOR EVENT close OF cl_gui_dialogbox_container.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.

  METHOD run.
    collect_objects(
      iv_from     = iv_from
      iv_to       = iv_to
      it_devclass = it_devclass
      it_user     = it_user ).
    precompute_quick_diffs( ).
    build_layout( ).
    lcl_html=>show_html( io_viewer = mo_nav iv_html = lcl_html=>build_nav( mt_objs ) ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  METHOD collect_k_requests.
    " S/R tasks of the selected user(s) changed in the period, with the
    " parent K header. The user filter is applied to the TASK owner only.
    SELECT c~trkorr AS task, c~as4user AS task_user,
           h~trkorr, h~as4date, h~as4time, t~as4text
      FROM e070 AS c
      INNER JOIN e070 AS h
        ON h~trkorr = c~strkorr
      LEFT JOIN e07t AS t
        ON t~trkorr = h~trkorr AND t~langu = @sy-langu
      WHERE c~trfunction IN ( 'S', 'R' )
        AND c~as4date BETWEEN @iv_from AND @iv_to
        AND c~as4user IN @it_user
        AND h~trfunction = 'K'
      ORDER BY h~trkorr, c~trkorr
      INTO TABLE @DATA(lt_raw).

    " Group the tasks under their parent K (virtual object collection per K).
    DATA ls_tr TYPE gty_tr.
    LOOP AT lt_raw INTO DATA(ls_raw).
      IF ls_tr-trkorr <> ls_raw-trkorr.
        IF ls_tr IS NOT INITIAL.
          APPEND ls_tr TO result.
        ENDIF.
        CLEAR ls_tr.
        ls_tr-trkorr  = ls_raw-trkorr.
        ls_tr-as4date = ls_raw-as4date.
        ls_tr-as4time = ls_raw-as4time.
        ls_tr-as4text = ls_raw-as4text.
        ls_tr-as4user = ls_raw-task_user.
      ENDIF.
      APPEND ls_raw-task TO ls_tr-tasks.
    ENDLOOP.
    IF ls_tr IS NOT INITIAL.
      APPEND ls_tr TO result.
    ENDIF.

    SORT result BY as4date DESCENDING as4time DESCENDING trkorr DESCENDING.
  ENDMETHOD.

  METHOD is_package_selected.
    rv_selected = abap_true.
    IF it_devclass IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_object   TYPE tadir-object.
    DATA lv_obj_name TYPE tadir-obj_name.
    DATA lv_devclass TYPE tadir-devclass.

    CASE is_part-type.
      WHEN 'METH' OR 'CPRI' OR 'CPRO' OR 'CPUB' OR 'CDEF' OR 'CINC' OR 'CLSD'.
        lv_object   = 'CLAS'.
        lv_obj_name = COND #( WHEN is_part-class IS NOT INITIAL
                              THEN is_part-class
                              ELSE is_part-object_name(30) ).
      WHEN 'REPS' OR 'REPT'.
        lv_object   = 'PROG'.
        lv_obj_name = is_part-object_name.
      WHEN 'FUNC'.
        " Function modules live in their group's package - resolve via TFDIR.
        SELECT SINGLE pname FROM tfdir
          WHERE funcname = @is_part-object_name
          INTO @DATA(lv_pname).
        IF sy-subrc = 0 AND strlen( lv_pname ) > 4.
          lv_object   = 'FUGR'.
          lv_obj_name = lv_pname+4.
        ELSE.
          lv_object   = 'FUGR'.
          lv_obj_name = is_part-object_name.
        ENDIF.
      WHEN OTHERS.
        lv_object   = is_part-type.
        lv_obj_name = is_part-object_name.
    ENDCASE.

    SELECT SINGLE devclass
      FROM tadir
      WHERE pgmid    = 'R3TR'
        AND object   = @lv_object
        AND obj_name = @lv_obj_name
      INTO @lv_devclass.

    rv_selected = abap_false.
    IF sy-subrc = 0 AND lv_devclass IN it_devclass.
      rv_selected = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD collect_objects.
    DATA(lt_tr) = collect_k_requests(
      iv_from = iv_from
      iv_to   = iv_to
      it_user = it_user ).

    DATA lv_idx TYPE i.
    LOOP AT lt_tr INTO DATA(ls_tr).
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = CONV i( sy-tabix * 100 / lines( lt_tr ) )
                  text       = CONV char70( |Observer: reading objects of { ls_tr-trkorr } ({ sy-tabix }/{ lines( lt_tr ) })| ).

      " Virtual object list for the K: only the objects of the user's own
      " S/R tasks (the K itself may carry other users' objects too).
      DATA lt_parts TYPE zif_ave_object=>ty_t_part.
      CLEAR lt_parts.
      LOOP AT ls_tr-tasks INTO DATA(lv_task).
        TRY.
            APPEND LINES OF NEW zcl_ave_object_tr( lv_task )->get_parts_expanded( )
              TO lt_parts.
          CATCH zcx_ave.
        ENDTRY.
      ENDLOOP.
      SORT lt_parts BY type object_name.
      DELETE ADJACENT DUPLICATES FROM lt_parts COMPARING type object_name.

      LOOP AT lt_parts INTO DATA(ls_part).
        " For class objects keep only sections and methods — skip CINC (CCIMP/CCMAC/CCDEF/CCAU),
        " CLSD (class pool header) and REPS (local types include).
        IF ls_part-class IS NOT INITIAL.
          CASE ls_part-type.
            WHEN 'CPUB' OR 'CPRO' OR 'CPRI' OR 'METH'.
              " keep
            WHEN OTHERS.
              CONTINUE.
          ENDCASE.
        ENDIF.
        IF is_package_selected( is_part = ls_part it_devclass = it_devclass ) = abap_false.
          CONTINUE.
        ENDIF.
        lv_idx = lv_idx + 1.
        APPEND VALUE gty_obj(
          idx     = lv_idx
          trkorr  = ls_tr-trkorr
          as4date = ls_tr-as4date
          as4time = ls_tr-as4time
          as4text = ls_tr-as4text
          as4user = ls_tr-as4user
          tasks   = ls_tr-tasks
          part    = ls_part ) TO mt_objs.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD load_version_source.
    TRY.
        IF is_ver-system IS NOT INITIAL.
          result = zcl_ave_version2=>get_source_remote(
            iv_objtype = is_part-type
            iv_objname = is_part-object_name
            iv_versno  = is_ver-versno
            iv_system  = is_ver-system ).
        ELSE.
          result = zcl_ave_version2=>get_source_local_compat(
            iv_objtype = is_part-type
            iv_objname = is_part-object_name
            iv_versno  = is_ver-versno
            iv_korrnum = is_ver-korrnum
            iv_author  = is_ver-author
            iv_datum   = is_ver-datum
            iv_zeit    = is_ver-zeit ).
        ENDIF.
      CATCH zcx_ave.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.

  METHOD precompute_quick_diffs.
    DATA(lv_total) = lines( mt_objs ).

    LOOP AT mt_objs ASSIGNING FIELD-SYMBOL(<o>).
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = CONV i( sy-tabix * 100 / COND i( WHEN lv_total > 0 THEN lv_total ELSE 1 ) )
                  text       = CONV char70( |Observer: quick diff { sy-tabix }/{ lv_total } { <o>-part-object_name }| ).

      " Pass full K scope to load so it can resolve the S/T/K mapping correctly.
      DATA lt_tasks   TYPE zif_ave_object=>ty_t_korr_range.
      DATA lt_parents TYPE zif_ave_object=>ty_t_korr_range.
      CLEAR: lt_tasks, lt_parents.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <o>-trkorr ) TO lt_parents.
      LOOP AT <o>-tasks INTO DATA(lv_task).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_task ) TO lt_tasks.
      ENDLOOP.
      IF lt_tasks IS INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <o>-trkorr ) TO lt_tasks.
      ENDIF.

      " Pass only the K request as filter — exactly as ACR does.
      DATA(ls_list) = zcl_ave_version_list=>load(
        iv_objtype        = <o>-part-type
        iv_objname        = <o>-part-object_name
        iv_filter_korrnum = <o>-trkorr ).

      " Check that at least one version in scope belongs to the user's own tasks.
      " If none match — the object was not touched by this user in this K.
      DATA(lv_user_touched) = abap_false.
      LOOP AT ls_list-versions INTO DATA(ls_ver).
        IF ls_ver-task IS NOT INITIAL.
          READ TABLE <o>-tasks TRANSPORTING NO FIELDS
            WITH KEY table_line = CONV trkorr( ls_ver-task ).
          IF sy-subrc = 0.
            lv_user_touched = abap_true.
            EXIT.
          ENDIF.
        ENDIF.
      ENDLOOP.
      IF lv_user_touched = abap_false.
        CONTINUE.
      ENDIF.

      <o>-new_ver = ls_list-new_version.
      <o>-old_ver = ls_list-old_version.

      IF <o>-new_ver IS INITIAL OR ls_list-versions IS INITIAL.
        CONTINUE.   " no version found in K scope
      ENDIF.
      <o>-has_pair = abap_true.

      " Quick diff — the only reliable relevance filter.
      " If new source = old source the object was not actually changed in this K
      " (load may return a version pair even when the object was untouched,
      " because VRSD may have no entry for this task at all).
      DATA(lt_new) = load_version_source( is_part = <o>-part is_ver = <o>-new_ver ).
      DATA lt_old TYPE abaptxt255_tab.
      CLEAR lt_old.
      IF <o>-old_ver IS NOT INITIAL.
        lt_old = load_version_source( is_part = <o>-part is_ver = <o>-old_ver ).
      ENDIF.

      <o>-diff_loc = lines( lt_new ) - lines( lt_old ).
      <o>-has_diff = xsdbool( lt_old <> lt_new ).
    ENDLOOP.

    " Navigation shows only objects actually changed by their K request.
    DELETE mt_objs WHERE has_diff = abap_false.

    SORT mt_objs BY as4date DESCENDING as4time DESCENDING trkorr DESCENDING
                    part-type part-object_name.
  ENDMETHOD.

  METHOD build_layout.
    CREATE OBJECT mo_box
      EXPORTING
        width    = 1300
        height   = 600
        top      = 20
        left     = 30
        caption  = |Observer { p_from DATE = USER } - { p_to DATE = USER }|
        lifetime = cl_gui_control=>lifetime_dynpro
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    SET HANDLER me->on_box_close FOR mo_box.

    " Vertical splitter: left navigation | right viewer
    mo_split = NEW cl_gui_splitter_container(
      parent  = mo_box
      rows    = 1
      columns = 2 ).
    mo_split->set_column_width( id = 1 width = 40 ).
    mo_split->set_column_width( id = 2 width = 60 ).

    DATA(lo_left)  = mo_split->get_container( row = 1 column = 1 ).
    DATA(lo_right) = mo_split->get_container( row = 1 column = 2 ).

    " Left: navigation HTML
    mo_nav = NEW cl_gui_html_viewer( parent = lo_left ).
    DATA lt_ev TYPE cntl_simple_events.
    APPEND VALUE #( eventid = cl_gui_html_viewer=>m_id_sapevent appl_event = abap_true ) TO lt_ev.
    mo_nav->set_registered_events( lt_ev ).
    SET HANDLER me->on_sapevent FOR mo_nav.

    " Right: nested splitter - row1 source editor, row2 diff HTML (toggled)
    mo_rsplit = NEW cl_gui_splitter_container(
      parent  = lo_right
      rows    = 2
      columns = 1 ).
    mo_rsplit->set_row_height( id = 1 height = 100 ).
    mo_rsplit->set_row_height( id = 2 height = 0 ).

    mo_editor = NEW cl_gui_abapedit( parent = mo_rsplit->get_container( row = 1 column = 1 ) ).
    mo_editor->create_document( ).
    mo_editor->set_readonly_mode( 1 ).

    mo_diff = NEW cl_gui_html_viewer( parent = mo_rsplit->get_container( row = 2 column = 1 ) ).

    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  METHOD show_right_source.
    mo_rsplit->set_row_height( id = 1 height = 100 ).
    mo_rsplit->set_row_height( id = 2 height = 0 ).
  ENDMETHOD.

  METHOD show_right_diff.
    mo_rsplit->set_row_height( id = 1 height = 0 ).
    mo_rsplit->set_row_height( id = 2 height = 100 ).
  ENDMETHOD.

  METHOD show_source.
    " Show the version written by this K request (precomputed pair).
    DATA(lt_src) = load_version_source( is_part = is_obj-part is_ver = is_obj-new_ver ).

    DATA lt_str TYPE STANDARD TABLE OF char255.
    LOOP AT lt_src INTO DATA(ls_l).
      APPEND CONV char255( ls_l ) TO lt_str.
    ENDLOOP.

    mo_editor->set_text( table = lt_str ).
    show_right_source( ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  METHOD show_diff.
    " Real diff on click: the pair was already resolved by
    " zcl_ave_version_list=>load during the quick pass - only the
    " expensive compute_diff + HTML rendering happen here.
    DATA(ls_obj) = is_obj.
    DATA(lt_new) = load_version_source( is_part = ls_obj-part is_ver = ls_obj-new_ver ).
    DATA lt_old TYPE abaptxt255_tab.
    IF ls_obj-old_ver IS NOT INITIAL.
      lt_old = load_version_source( is_part = ls_obj-part is_ver = ls_obj-old_ver ).
    ENDIF.

    DATA lt_diff TYPE zif_ave_popup_types=>ty_t_diff.
    IF ls_obj-old_ver IS INITIAL.
      " New object in this K - the whole source is one insertion block.
      LOOP AT lt_new INTO DATA(ls_new_line).
        APPEND VALUE #( op = '+' text = CONV string( ls_new_line ) ) TO lt_diff.
      ENDLOOP.
    ELSE.
      zcl_ave_progress=>reset_stop( ).
      lt_diff = zcl_ave_popup_diff=>compute_diff(
        it_old        = lt_old
        it_new        = lt_new
        i_title       = CONV #( is_obj-part-object_name )
        i_confirm_key = |OBSV~{ is_obj-part-type }~{ is_obj-part-object_name }| ).
      IF zcl_ave_progress=>was_stop_requested( ) = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    DATA(lv_old_meta) = COND string(
      WHEN ls_obj-old_ver IS INITIAL THEN `(none - new object)`
      ELSE |{ ls_obj-old_ver-versno_text } req { ls_obj-old_ver-korrnum }| ).
    DATA(lv_meta) = |TR { is_obj-trkorr }  OLD: { lv_old_meta }  ->  | &&
                    |NEW: { ls_obj-new_ver-versno_text } req { ls_obj-new_ver-korrnum }|.

    DATA(lv_html) = zcl_ave_popup_html=>diff_to_html(
      it_diff = lt_diff
      i_title = |{ is_obj-part-type }: { is_obj-part-object_name }|
      i_meta  = lv_meta ).
    lcl_html=>show_html( io_viewer = mo_diff iv_html = lv_html ).
    show_right_diff( ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  METHOD on_sapevent.
    " getdata looks like "idx=NN"
    DATA lv_idx TYPE i.
    DATA lv_val TYPE string.
    SPLIT getdata AT '=' INTO DATA(lv_key) lv_val.
    lv_idx = lv_val.
    READ TABLE mt_objs INTO DATA(ls_obj) WITH KEY idx = lv_idx.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE action.
      WHEN 'src'.
        show_source( ls_obj ).
      WHEN 'diff'.
        show_diff( ls_obj ).
    ENDCASE.
  ENDMETHOD.

  METHOD on_box_close.
    mo_box->free( EXCEPTIONS OTHERS = 1 ).
    CLEAR: mo_box, mo_split, mo_rsplit, mo_nav, mo_editor, mo_diff.
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Events
*&---------------------------------------------------------------------*
DATA go_app TYPE REF TO lcl_app.

AT SELECTION-SCREEN.
  " Open the observer popup only on plain Enter (no other command)
  CHECK sy-ucomm IS INITIAL.
  go_app = NEW lcl_app( ).
  go_app->run(
    iv_from     = p_from
    iv_to       = p_to
    it_devclass = s_pack[]
    it_user     = s_user[] ).
