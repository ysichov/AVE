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
        rows        TYPE i,
        rowcolor(4) TYPE c,
      END OF ty_part_row .
  types:
    ty_t_part_row TYPE STANDARD TABLE OF ty_part_row WITH DEFAULT KEY .
  types TY_VERSION_ROW type ZIF_AVE_POPUP_TYPES=>TY_VERSION_ROW .
  types TY_T_VERSION_ROW type ZIF_AVE_POPUP_TYPES=>TY_T_VERSION_ROW .
    "! Delegated to ZCL_AVE_POPUP_DIFF (extracted diff engine)
  types TY_DIFF_OP type ZIF_AVE_POPUP_TYPES=>TY_DIFF_OP .
  types TY_T_DIFF type ZIF_AVE_POPUP_TYPES=>TY_T_DIFF .
  "! Delegated to ZCL_AVE_POPUP_HTML (extracted HTML renderer)
  types TY_BLAME_ENTRY type ZIF_AVE_POPUP_TYPES=>TY_BLAME_ENTRY .
  types TY_BLAME_MAP type ZIF_AVE_POPUP_TYPES=>TY_BLAME_MAP .
  "──────────── diff HTML cache ────────────────────────────────────
  "! Per-instance cache for rendered diff HTML.
  "! Key: object type/name + old/new versno + display flags (blame/two_pane/compact/debug).
  "! Hit: return stored HTML immediately, skipping source load, diff and blame computation.
  "! Miss: compute as usual, store result. Cache lives for the lifetime of the popup instance.
  TYPES: BEGIN OF ty_diff_cache_key,
           objtype     TYPE versobjtyp,
           objname     TYPE versobjnam,
           versno_o    TYPE versno,
           versno_n    TYPE versno,
           blame       TYPE abap_bool,
           two_pane    TYPE abap_bool,
           compact     TYPE abap_bool,
           debug       TYPE abap_bool,
           ignore_case TYPE abap_bool,
         END OF ty_diff_cache_key.
  TYPES: BEGIN OF ty_diff_cache,
           key  TYPE ty_diff_cache_key,
           html TYPE string,
         END OF ty_diff_cache.
  TYPES ty_t_diff_cache TYPE HASHED TABLE OF ty_diff_cache WITH UNIQUE KEY key.

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
  data MO_SPLIT_WRAP type ref to CL_GUI_SPLITTER_CONTAINER .
  data MO_SPLIT_2P_TOP type ref to CL_GUI_SPLITTER_CONTAINER .
  data MO_SPLIT_2P_WRAP type ref to CL_GUI_SPLITTER_CONTAINER .
  data MV_FOCUS_HTML type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MO_CONT_PARTS_2P type ref to CL_GUI_CONTAINER .
  data MO_CONT_VERS_2P type ref to CL_GUI_CONTAINER .
  data MO_CONT_HTML_2P type ref to CL_GUI_CONTAINER .
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
  data MV_CUR_PART_NAME type STRING .  " Human-readable display name for caption (e.g. method name, section name)
  data MS_BASE_VER type TY_VERSION_ROW .
  data MS_DIFF_OLD type TY_VERSION_ROW .
  data MS_DIFF_NEW type TY_VERSION_ROW .
  data MV_SHOW_DIFF type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_LAYOUT type ABAP_BOOL .
  data MV_TWO_PANE type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_NO_TOC type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_COMPACT type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_REMOVE_DUP type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_BLAME type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_IGNORE_CASE type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_TASK_VIEW type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_DIFF_PREV type ABAP_BOOL value ABAP_TRUE ##NO_TEXT.
  data MV_REFRESHING type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_DEBUG type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MV_LAST_HTML type STRING .
  "! When drilled into a class from a TR parts view, holds the class name so
  "! Refresh reloads only that class (not the outer TR).
  data MV_DRILLED_CLASS type SEOCLSNAME .
  data MV_FILTER_USER type VERSUSER .
  data MV_DATE_FROM type VERSDATE .
  data MV_VIEWED_VERSNO type VERSNO .
    " Backup for Back navigation (one level)
  data MT_PARTS_BACKUP type TY_T_PART_ROW .
  data MT_DIFF_CACHE type TY_T_DIFF_CACHE .
  data MO_TOOLBAR type ref to CL_GUI_TOOLBAR .
  data MO_CONT_TOOLBAR type ref to CL_GUI_CONTAINER .
  " ── Code Reviewer mode ──────────────────────────────────────────
  data MV_CODE_REVIEW      type ABAP_BOOL value ABAP_FALSE ##NO_TEXT.
  data MT_ACR_STATS        type ZIF_AVE_ACR_TYPES=>TY_T_OBJ_STATS.
  data MV_CR_REPORT_HTML   type STRING.
  data MT_APPROVED         type ZIF_AVE_ACR_TYPES=>TY_APPROVED.
  data MT_DECLINED         type ZIF_AVE_ACR_TYPES=>TY_APPROVED.
  " Decline notes: key = hunk key (OBJTYPE~OBJNAME~N), value = note text
  TYPES: BEGIN OF ty_decline_note,
           hunk_key TYPE string,
           note     TYPE string,
         END OF ty_decline_note.
  TYPES ty_t_decline_notes TYPE HASHED TABLE OF ty_decline_note WITH UNIQUE KEY hunk_key.
  TYPES: BEGIN OF ty_hunk_info,
           hunk_key     TYPE string,
           objtype      TYPE versobjtyp,
           obj_name     TYPE versobjnam,
           class_name   TYPE seoclsname,
           display_name TYPE string,
           hunk_no      TYPE i,
           start_line   TYPE i,
           change_count TYPE i,
           author       TYPE versuser,
           author_name  TYPE ad_namtext,
           html         TYPE string,
         END OF ty_hunk_info.
  TYPES ty_t_hunk_info TYPE HASHED TABLE OF ty_hunk_info WITH UNIQUE KEY hunk_key.
  data MT_DECLINE_NOTES    type TY_T_DECLINE_NOTES.
  data MT_HUNK_INFO        type TY_T_HUNK_INFO.
  data MV_CR_BASE_HTML     type STRING.
  data MV_CR_CUR_KEY       type STRING.
  " Pending decline key — set before opening note dialog, used in saved-event handler
  data MV_PENDING_DECLINE  type STRING.
  data MO_NOTE_DLG         type ref to ZCL_AVE_ACR_NOTE_DLG.
  data MO_HELP_BOX         type ref to CL_GUI_DIALOGBOX_CONTAINER.
  data MO_HELP_HTML        type ref to CL_GUI_HTML_VIEWER.

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
  methods ON_HELP_BOX_CLOSE
    for event CLOSE of CL_GUI_DIALOGBOX_CONTAINER
    importing
      !SENDER .
  methods ON_SAPEVENT
    for event SAPEVENT of CL_GUI_HTML_VIEWER
    importing
      !ACTION
      !GETDATA
      !POSTDATA .
  methods INJECT_APPROVE_BTN
    importing
      !IV_HTML  type STRING
      !IV_KEY   type STRING
    returning
      value(RESULT) type STRING .
  methods ACR_APPROVE_CELL
    importing
      !IV_KEY   type STRING
    returning
      value(RESULT) type STRING .
  methods ACR_APPROVE_FIXED
    importing
      !IV_KEY   type STRING
    returning
      value(RESULT) type STRING .
  methods REFRESH_RPT_ROW .
  methods REGEN_ACR_REPORT .
  methods MAXIMIZE_HTML .
  methods ON_NOTE_DLG_SAVED
    for event SAVED of ZCL_AVE_ACR_NOTE_DLG
    importing
      !IV_HUNK_KEY
      !IV_NOTE .
  methods BACK_TO_REPORT .
  methods SHOW_USER_DECLINES
    importing
      !IV_USER type VERSUSER .
  methods OPEN_CR_PART
    importing
      !IV_OBJTYPE type VERSOBJTYP
      !IV_OBJNAME type VERSOBJNAM .
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
  methods HAS_REVIEW_TABLE
    returning
      value(RESULT) type ABAP_BOOL .
  methods BUILD_REVIEW_HELP_HTML
    returning
      value(RESULT) type STRING .
  methods SHOW_REVIEW_HELP_POPUP .
  "! Upload source to the ABAP editor and toggle visibility so it takes the
  "! place of the HTML viewer. Used for single-version (Show Vers) view.
  methods SHOW_CODE_SOURCE
    importing
      !IT_SOURCE type ABAPTXT255_TAB .
  "! Code Reviewer: compute diff+HTML+stats for one changed part and cache them.
  "! Mirrors the core of show_versions_diff but without UI side effects.
  methods CR_PRECOMPUTE_PART
    importing
      !IS_PART type TY_PART_ROW .
  "! Code Reviewer: iterate all parts of a class, call cr_precompute_part for each.
  "! Returns true if at least one part was added to mt_acr_stats.
  methods CR_PRECOMPUTE_CLASS_PARTS
    importing
      !I_CLASS_NAME type SEOCLSNAME
    returning
      value(RESULT) type ABAP_BOOL .
ENDCLASS.



CLASS ZCL_AVE_POPUP IMPLEMENTATION.


  METHOD constructor.
    mv_object_type = i_object_type.
    mv_object_name = i_object_name.
    " Member vars already have correct defaults (show_diff/no_toc/compact = X, two_pane = ' ')
    " Override only when settings explicitly provided
    IF is_settings IS SUPPLIED.
      mv_show_diff   = is_settings-show_diff.
      mv_layout      = is_settings-layout.
      mv_two_pane    = is_settings-two_pane.
      mv_no_toc                    = is_settings-no_toc.
      zcl_ave_popup_data=>mv_no_toc = is_settings-no_toc.
      mv_compact     = is_settings-compact.
      mv_remove_dup  = is_settings-remove_dup.
      mv_blame       = is_settings-blame.
      mv_ignore_case = is_settings-ignore_case.
      mv_filter_user = is_settings-filter_user.
      mv_date_from   = is_settings-date_from.
      mv_code_review = is_settings-code_review.
    ENDIF.

  ENDMETHOD.


  METHOD show.
    build_layout( ).
    build_parts_list( ).
    build_html_viewer( ).
    build_versions_grid( ).

    " Code Review: auto-open report immediately in maximized view
    IF mv_code_review = abap_true AND mv_cr_report_html IS NOT INITIAL.
      maximize_html( ).
      set_html( mv_cr_report_html ).
      cl_gui_cfw=>flush( ).
      RETURN.
    ENDIF.

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
            " No previous version → show as new object (all-green diff vs empty source)
            auto_show_diff_or_source( is_old = ls_prev_auto is_new = ms_base_ver ).
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

    " If starting in TOP-DOWN layout — flip wrapper and point containers
    IF mv_layout = abap_false.
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
              ls_row-rowcolor = 'C601'.   " red
            ELSE.
              DATA(lv_changed) = COND abap_bool(
                WHEN ls_raw-type = 'CLAS'
                THEN zcl_ave_popup_data=>check_class_has_author( i_class_name = CONV #( ls_raw-object_name ) )
                ELSE zcl_ave_popup_data=>is_substantive_user_change(
                       it_versions = zcl_ave_popup_data=>build_versions_for_check( i_type = ls_raw-type i_name = ls_raw-object_name )
                       i_type      = ls_raw-type
                       i_name      = ls_raw-object_name ) ).
              IF lv_changed = abap_true.
                ls_row-rowcolor = 'C510'. " green
              ENDIF.
            ENDIF.
            IF ls_raw-type <> 'METH' AND ls_raw-type <> 'CPUB'  AND ls_raw-type <> 'CPRO' AND ls_raw-type <> 'CPRI' AND
               ls_raw-type <> 'REPS' AND ls_raw-type <> 'PROG' AND ls_raw-type <> 'CLSD' AND ls_raw-type <> 'CLAS' AND
               ls_raw-type <> 'DDLS'.

               ls_row-rowcolor = 'C201'. " not supported obj
            ENDIF.
            APPEND ls_row TO mt_parts.
            CLEAR ls_row.
          ENDLOOP.
        ENDIF.
      CATCH zcx_ave.
        " leave mt_parts empty – no crash
    ENDTRY.

    " ── Code Reviewer post-processing ───────────────────────────────
    IF mv_code_review = abap_true.
      " Remove only unsupported / missing — changed check is done inside cr_precompute_part
      " (which compares active vs prior K, including unreleased transports)
      DELETE mt_parts WHERE rowcolor = 'C201' OR rowcolor = 'C601'.

      " Pre-compute diff + stats for each part; only objects with real diffs
      " land in mt_acr_stats. The USER filter is applied inside
      " cr_precompute_part after the transport version is known; filtering here
      " would drop CLAS aggregate rows before their child parts are inspected.
      LOOP AT mt_parts ASSIGNING FIELD-SYMBOL(<lp>).
        cr_precompute_part( <lp> ).
      ENDLOOP.

      " Color: green if there are real diff stats, otherwise leave as-is.
      " Parts list mirrors Version Explorer; report only includes changed parts.
      LOOP AT mt_parts ASSIGNING FIELD-SYMBOL(<p>).
        IF <p>-type = 'CLAS'.
          " For CLAS aggregate row (from TR): precompute child parts for the report
          IF cr_precompute_class_parts( CONV #( <p>-object_name ) ) = abap_true.
            <p>-rowcolor = 'C510'.
          ENDIF.
        ELSE.
          READ TABLE mt_acr_stats TRANSPORTING NO FIELDS
            WITH KEY objtype = <p>-type obj_name = <p>-object_name.
          IF sy-subrc = 0.
            <p>-rowcolor = 'C510'.
          ENDIF.
        ENDIF.
      ENDLOOP.

      " Build report HTML from collected stats
      mv_cr_report_html = zcl_ave_acr_report=>to_html(
        it_obj_stats = mt_acr_stats
        it_approved  = mt_approved
        it_declined  = mt_declined
        i_korrnum    = CONV #( mv_object_name ) ).

      " Insert REPORT pseudo-part at the top of the list
      DATA(lv_total_acr) = lines( mt_acr_stats ).
      DATA(ls_rpt) = VALUE ty_part_row(
        type      = 'RPT'
        name      = |[ Code Review Report — 0/{ lv_total_acr } approved (0%) ]|
        type_text = 'Report'
        rows      = lv_total_acr ).
      INSERT ls_rpt INTO mt_parts INDEX 1.
    ENDIF.

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
        icon      = CONV #( icon_spool_request )
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
    IF mv_code_review = abap_true.
      mo_toolbar->add_button_group( VALUE ttb_button(
        ( function  = 'SAVE_REVIEW'
          icon      = CONV #( icon_system_save )
          text      = 'Save'
          quickinfo = 'Save review' ) ) ).
    ENDIF.

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
    ls_fc-outputlen = 20. APPEND ls_fc TO lt_fcat.
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
    DATA lt_html_ev TYPE cntl_simple_events.
    APPEND VALUE #( eventid = cl_gui_html_viewer=>m_id_sapevent ) TO lt_html_ev.
    mo_html->set_registered_events( lt_html_ev ).
    SET HANDLER me->on_sapevent FOR mo_html.

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
    ls_fc-outputlen = 12. ls_fc-emphasize = 'C401'. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'OBJ_OWNER_NAME'. ls_fc-coltext = 'Owner Name'.
    ls_fc-outputlen = 20. ls_fc-emphasize = 'C401'. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'KORRNUM'.     ls_fc-coltext = 'Request'.
    ls_fc-outputlen = 12. APPEND ls_fc TO lt_fcat.
    CLEAR ls_fc. ls_fc-fieldname = 'TRFUNCTION'.  ls_fc-coltext = 'Type'.
    ls_fc-outputlen = 4.  APPEND ls_fc TO lt_fcat.
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

    " ── Code Reviewer: REPORT pseudo-part ───────────────────────────
    IF ls_part-type = 'RPT'.
      maximize_html( ).
      set_html( mv_cr_report_html ).
      RETURN.
    ENDIF.

    " ── Code Reviewer: show pre-cached diff if available ───────────
    IF mv_code_review = abap_true.
      READ TABLE mt_acr_stats INTO DATA(ls_stat)
        WITH KEY objtype = ls_part-type obj_name = ls_part-object_name.
      IF sy-subrc = 0.
        DATA(ls_ck) = VALUE ty_diff_cache_key(
          objtype     = ls_stat-objtype
          objname     = ls_stat-obj_name
          versno_o    = ls_stat-versno_old
          versno_n    = ls_stat-versno_new
          blame       = mv_blame
          two_pane    = mv_two_pane
          compact     = mv_compact
          debug       = mv_debug
          ignore_case = mv_ignore_case ).
        READ TABLE mt_diff_cache INTO DATA(ls_ch) WITH TABLE KEY key = ls_ck.
        IF sy-subrc = 0.
          mv_cur_objtype   = ls_part-type.
          mv_cur_objname   = ls_part-object_name.
          mv_cur_part_name = COND string(
            WHEN ls_part-class IS NOT INITIAL THEN |{ ls_part-class } – { ls_part-name }|
            ELSE ls_part-name ).
          mv_cr_cur_key   = |{ ls_stat-objtype }~{ ls_stat-obj_name }|.
          mv_cr_base_html = ls_ch-html.
          " Restore layout (un-maximize) so versions grid is visible
          mv_focus_html = abap_false.
          mo_split_main->set_column_width( id = 1 width = 20 ).
          " Load versions for this part so the grid is populated
          load_versions( i_objtype = ls_part-type i_objname = ls_part-object_name ).
          refresh_vers( ).
          set_html( inject_approve_btn( iv_html = ls_ch-html iv_key = mv_cr_cur_key ) ).
          RETURN.
        ENDIF.
      ENDIF.
      " No cache — fall through to standard Version Explorer diff mechanism
    ENDIF.

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
          mv_cur_objtype   = ls_first_part-type.
          mv_cur_objname   = ls_first_part-object_name.
          mv_cur_part_name = ls_first_part-name.
          load_versions( i_objtype = ls_first_part-type i_objname = ls_first_part-object_name ).
          refresh_vers( ).
          IF mt_versions IS NOT INITIAL.
            ms_base_ver = mt_versions[ 1 ].
            mv_viewed_versno = ms_base_ver-versno.
            IF mv_show_diff = abap_true.
              READ TABLE mt_versions INTO DATA(ls_prev_cls) INDEX 2.
              " No previous version → show as new object (all-green diff vs empty source)
              auto_show_diff_or_source( is_old = ls_prev_cls is_new = ms_base_ver ).
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
      ( |CPRI| ) ( |CINC| ) ( |CDEF| ) ( |FUNC| ) ( |DDLS| ) ).
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

    mv_cur_objtype   = ls_part-type.
    mv_cur_objname   = ls_part-object_name.
    mv_cur_part_name = COND string(
      WHEN ls_part-class IS NOT INITIAL AND ls_part-class <> mv_object_name
      THEN |{ ls_part-class } – { ls_part-name }|
      ELSE ls_part-name ).

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

    CLEAR ms_base_ver.
    CLEAR mv_viewed_versno.
    IF mt_versions IS NOT INITIAL.
      " In TR mode: base = version that belongs to the TR, not necessarily Active.
      IF mv_object_type = zcl_ave_object_factory=>gc_type-tr.
        LOOP AT mt_versions INTO ms_base_ver WHERE korrnum = mv_object_name.
          EXIT.
        ENDLOOP.
      ENDIF.
      IF ms_base_ver IS INITIAL.
        ms_base_ver = mt_versions[ 1 ].
      ENDIF.
      mv_viewed_versno = ms_base_ver-versno.
    ENDIF.

    update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
    refresh_vers( ).

    IF mt_versions IS NOT INITIAL.
      IF mv_show_diff = abap_true.
        " Prior = first version before the base (VRSD korrnum is always K-type).
        DATA ls_prev_part TYPE ty_version_row.
        LOOP AT mt_versions INTO ls_prev_part WHERE versno < ms_base_ver-versno.
          EXIT.
        ENDLOOP.
        IF ls_prev_part IS NOT INITIAL.
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

    " Fill request description and trfunction from E07T / E070
    DATA lv_korr_text TYPE e07t-as4text.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver2>).
      CHECK <ver2>-korrnum IS NOT INITIAL.
      SELECT SINGLE as4text FROM e07t
        WHERE trkorr = @<ver2>-korrnum
          AND langu  = @sy-langu
        INTO @lv_korr_text.
      <ver2>-korr_text = lv_korr_text.

      SELECT SINGLE trfunction FROM e070
        WHERE trkorr = @<ver2>-korrnum
        INTO @<ver2>-trfunction.
    ENDLOOP.

    IF mv_remove_dup = abap_true.
      zcl_ave_popup_data=>remove_duplicate_versions(
        EXPORTING i_keep_korrnum = COND #( WHEN mv_object_type = zcl_ave_object_factory=>gc_type-tr
                                           THEN CONV trkorr( mv_object_name ) )
        CHANGING  ct_versions    = mt_versions ).
    ENDIF.
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
        <v>-rowcolor = 'C510'.  " green background = base
      ELSEIF <v>-versno = iv_viewed_versno AND iv_viewed_versno <> ms_base_ver-versno.
        <v>-rowcolor = 'C710'.  " blue = currently viewed
      ELSEIF <v>-trfunction = 'K' AND <v>-task IS NOT INITIAL.
        <v>-rowcolor = 'C501'.  "  green = workbench request (type K)
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
      zcl_ave_popup_data=>remove_duplicate_versions(
        EXPORTING i_keep_korrnum = COND #( WHEN mv_object_type = zcl_ave_object_factory=>gc_type-tr
                                           THEN CONV trkorr( mv_object_name ) )
        CHANGING  ct_versions    = mt_versions ).
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
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar. " separator
    APPEND VALUE stb_button(
      function  = 'CASE_TOGGLE'
      icon      = CONV #( icon_abc )
      text      = COND #( WHEN mv_ignore_case = abap_true THEN 'Case off' ELSE 'Case on' )
      quickinfo = 'Toggle case-insensitive diff'
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

      WHEN 'CASE_TOGGLE'.
        mv_ignore_case = COND #( WHEN mv_ignore_case = abap_true THEN abap_false ELSE abap_true ).
        refresh_vers( ).
        IF mv_show_diff = abap_true AND ms_diff_old IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
        ENDIF.

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
        ms_base_ver = ls_ver.
        " No previous version → show as new object (all-green diff vs empty source)
        show_versions_diff( is_old = ls_prev is_new = ls_ver ).
      ELSE.
        " Diff any mode: compare with manually chosen base
        IF ls_ver-versno = ms_base_ver-versno.
          READ TABLE mt_versions INTO DATA(ls_prev_base) INDEX lv_row + 1.
          " No previous version → show as new object
          show_versions_diff( is_old = ls_prev_base is_new = ls_ver ).
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
        WHEN mv_cur_part_name IS NOT INITIAL
        THEN | – { mv_cur_part_name }|
        WHEN i_objname IS NOT INITIAL AND i_objname <> mv_object_name
        THEN | – { i_objtype }: { i_objname }|
        ELSE `` ).
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
*        IF i_objtype = 'DDLS'.
*          set_html( zcl_ave_popup_html=>cds_source_to_html(
*            it_source = lt_source
*            i_title   = |{ i_objtype }: { i_objname }|
*            i_meta    = lv_vlbl ) ).
*        ELSE.
*          show_code_source( it_source = lt_source ).
*        ENDIF.

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
      " TR drill-down: color if changed vs prior K-TR (author irrelevant).
      IF zcl_ave_popup_data=>is_substantive_user_change(
           it_versions = zcl_ave_popup_data=>build_versions_for_check( i_type = ls_part-type i_name = ls_part-object_name )
           i_type      = ls_part-type
           i_name      = ls_part-object_name ) = abap_true.
        ls_part_row-rowcolor = 'C510'. " green
      ENDIF.
      APPEND ls_part_row TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD on_toolbar_click.
    CASE fcode.
      WHEN 'SAVE_REVIEW'.
        IF has_review_table( ) = abap_false.
          show_review_help_popup( ).
        ELSE.
          MESSAGE 'ZAVE_REVIEW found. Save handler comes next.' TYPE 'S'.
        ENDIF.

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
              mt_parts = get_class_parts( CONV #( mv_drilled_class ) ).
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
                  ls_row-rowcolor = 'C601'.   " red
                ELSE.
                  DATA(lv_changed2) = COND abap_bool(
                    WHEN ls_raw-type = 'CLAS'
                    THEN zcl_ave_popup_data=>check_class_has_author( i_class_name = CONV #( ls_raw-object_name ) )
                    ELSE zcl_ave_popup_data=>is_substantive_user_change(
                           it_versions = zcl_ave_popup_data=>build_versions_for_check( i_type = ls_raw-type i_name = ls_raw-object_name )
                           i_type      = ls_raw-type
                           i_name      = ls_raw-object_name ) ).
                  IF lv_changed2 = abap_true.
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
        CLEAR mt_diff_cache.
        " Reload versions for current part if one was selected
        IF mv_cur_objtype IS NOT INITIAL.
          load_versions( i_objtype = mv_cur_objtype i_objname = mv_cur_objname ).
          update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
        ENDIF.
        " Re-render diff if it was already open (cache cleared above forces fresh render)
        IF ms_diff_old IS NOT INITIAL AND ms_diff_new IS NOT INITIAL.
          show_versions_diff( is_old = ms_diff_old is_new = ms_diff_new ).
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
        IF mv_focus_html = abap_true.
          " currently maximized → restore
          mv_focus_html = abap_false.
          mo_toolbar->set_button_info(
            EXPORTING fcode = 'FOCUS_TOGGLE'
                      text  = 'Maximize View'
                      icon  = CONV #( icon_view_maximize ) ).
          IF mv_two_pane = abap_true.
            mo_split_2p_wrap->set_row_height( id = 1 height = 35 ).
            mo_split_2p_wrap->set_row_height( id = 2 height = 65 ).
            mo_split_2p_wrap->set_row_sash( id = 1 type = 1 value = 0 ).
          ELSE.
            mo_split_main->set_column_width( id = 1 width = 40 ).
            mo_split_main->set_column_width( id = 2 width = 60 ).
            mo_split_main->set_column_sash( id = 1 type = 1 value = 0 ).
          ENDIF.
        ELSE.
          maximize_html( ).
        ENDIF.

    ENDCASE.
  ENDMETHOD.


  METHOD on_box_close.
    sender->free( ).
    CLEAR mo_box.
  ENDMETHOD.


  METHOD on_help_box_close.
    sender->free( ).
    CLEAR: mo_help_box, mo_help_html.
  ENDMETHOD.


  METHOD has_review_table.
    SELECT SINGLE tabname
      FROM dd02l
      WHERE tabname  = 'ZAVE_REVIEW'
        AND as4local = 'A'
        AND tabclass = 'TRANSP'
      INTO @DATA(lv_tabname).

    result = xsdbool( sy-subrc = 0 AND lv_tabname IS NOT INITIAL ).
  ENDMETHOD.


  METHOD build_review_help_html.
    result =
      `<!DOCTYPE html><html><head><meta charset="utf-8"><style>` &&
      `body{font:13px/1.5 Segoe UI,Arial,sans-serif;background:#f7f7f9;color:#222;padding:18px;}` &&
      `h2{margin:0 0 10px;color:#0a6ed1;}p{margin:0 0 12px;}` &&
      `table{border-collapse:collapse;width:100%;background:#fff;margin:10px 0 14px;}` &&
      `th,td{border:1px solid #d9d9d9;padding:7px 9px;text-align:left;vertical-align:top;}` &&
      `th{background:#eef4fb;}code{background:#eef2f7;padding:1px 4px;border-radius:3px;}` &&
      `ol{margin:8px 0 0 22px;padding:0;}li{margin:0 0 6px;}` &&
      `</style></head><body>` &&
      `<h2>Save review requires table ZAVE_REVIEW</h2>` &&
      `<p>The button can save review data only after a transparent table <code>ZAVE_REVIEW</code> is created and activated.</p>` &&
      `<p>For now keep the design minimal: one row per transport request, and the full review with save history stored inside one JSON payload.</p>` &&
      `<table><tr><th>Field</th><th>Type</th><th>Purpose</th></tr>` &&
      `<tr><td>MANDT</td><td>MANDT</td><td>Client field</td></tr>` &&
      `<tr><td>TRKORR</td><td>TRKORR</td><td>Transport request key</td></tr>` &&
      `<tr><td>PAYLOAD</td><td>STRING</td><td>Stored review JSON including current state and save history</td></tr>` &&
      `</table>` &&
      `<ol>` &&
      `<li>Create transparent table <code>ZAVE_REVIEW</code>.</li>` &&
      `<li>Make <code>MANDT</code> and <code>TRKORR</code> key fields.</li>` &&
      `<li>Add field <code>PAYLOAD</code> as type <code>STRING</code>.</li>` &&
      `<li>Activate the table. No ZIP or compression is needed yet.</li>` &&
      `<li>Return to AVE and press <code>Save</code> again.</li>` &&
      `</ol>` &&
      `</body></html>`.
  ENDMETHOD.


  METHOD show_review_help_popup.
    IF mo_help_box IS BOUND.
      mo_help_box->free( ).
      CLEAR: mo_help_box, mo_help_html.
    ENDIF.

    CREATE OBJECT mo_help_box
      EXPORTING
        width                       = 760
        height                      = 360
        top                         = 90
        left                        = 120
        caption                     = 'ZAVE_REVIEW setup'
        lifetime                    = cl_gui_control=>lifetime_dynpro
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SET HANDLER me->on_help_box_close FOR mo_help_box.

    CREATE OBJECT mo_help_html
      EXPORTING
        parent = mo_help_box
      EXCEPTIONS
        cntl_error                = 1
        cntl_install_error        = 2
        dp_install_error          = 3
        dp_error                  = 4
        OTHERS                    = 5.
    IF sy-subrc <> 0.
      mo_help_box->free( ).
      CLEAR: mo_help_box, mo_help_html.
      RETURN.
    ENDIF.

    DATA(lv_help_html) = build_review_help_html( ).
    DATA: lt_html   TYPE w3htmltab,
          lv_url    TYPE w3url,
          lv_offset TYPE i,
          lv_len    TYPE i,
          lv_chunk  TYPE i.

    lv_len = strlen( lv_help_html ).
    WHILE lv_offset < lv_len.
      lv_chunk = COND #( WHEN lv_len - lv_offset > 255 THEN 255 ELSE lv_len - lv_offset ).
      APPEND VALUE #( line = lv_help_html+lv_offset(lv_chunk) ) TO lt_html.
      lv_offset += lv_chunk.
    ENDWHILE.

    mo_help_html->load_data(
      IMPORTING assigned_url = lv_url
      CHANGING  data_table   = lt_html
      EXCEPTIONS OTHERS      = 1 ).
    IF sy-subrc = 0.
      mo_help_html->show_url( url = lv_url ).
      cl_gui_control=>set_focus( control = mo_help_html ).
      cl_gui_cfw=>flush( ).
    ENDIF.
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
      DATA(lv_old_lbl) = COND string(
        WHEN is_old-versno IS INITIAL THEN `(new object)`
        WHEN is_old-versno_text CA '0123456789' AND is_old-versno_text NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        THEN |v{ is_old-versno_text }| ELSE is_old-versno_text ).
      DATA(lv_extra2) = COND string(
        WHEN mv_cur_part_name IS NOT INITIAL
        THEN | – { mv_cur_part_name }|
        WHEN is_new-objname IS NOT INITIAL AND is_new-objname <> mv_object_name
        THEN | – { is_new-objtype }: { is_new-objname }|
        ELSE `` ).
      mo_box->set_caption( |{ mv_object_type }: { mv_object_name }{ lv_extra2 }  [{ lv_new_lbl } -- { lv_old_lbl }]| ).
    ENDIF.
    " Cache lookup
    DATA(ls_cache_key) = VALUE ty_diff_cache_key(
      objtype     = is_new-objtype
      objname     = is_new-objname
      versno_o    = is_old-versno
      versno_n    = is_new-versno
      blame       = mv_blame
      two_pane    = mv_two_pane
      compact     = mv_compact
      debug       = mv_debug
      ignore_case = mv_ignore_case ).
    READ TABLE mt_diff_cache INTO DATA(ls_cached) WITH TABLE KEY key = ls_cache_key.
    IF sy-subrc = 0.
      set_html( ls_cached-html ).
      RETURN.
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
        " Old source: empty for brand-new objects (no prior version → all-green diff)
        DATA lt_src_o TYPE abaptxt255_tab.
        IF is_old-versno IS NOT INITIAL.
          lt_src_o = NEW zcl_ave_version( lt_vrsd_o[ 1 ] )->get_source( ).
        ENDIF.
        DATA(lt_src_n) = NEW zcl_ave_version( lt_vrsd_n[ 1 ] )->get_source( ).
        DATA(lt_diff)  = zcl_ave_popup_diff=>compute_diff( it_old = lt_src_o it_new = lt_src_n i_ignore_case = mv_ignore_case ).
        DATA(lv_meta)  = COND string(
          WHEN is_old-versno IS INITIAL THEN |{ is_new-versno_text } → (new object)|
          ELSE |{ is_new-versno_text } → { is_old-versno_text }| ).
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
        DATA lv_html TYPE string.
        IF mv_debug = abap_true.
          lv_html = zcl_ave_popup_html=>debug_diff_html(
            it_diff = lt_diff
            i_title = |{ is_new-objtype }: { is_new-objname }|
            i_meta  = lv_meta ).
        ELSE.
          lv_html = zcl_ave_popup_html=>diff_to_html(
            it_diff          = lt_diff
            i_title          = |{ is_new-objtype }: { is_new-objname }|
            i_meta           = lv_meta
            i_two_pane       = mv_two_pane
            " Force compact for huge files — full view would render millions of rows.
            i_compact        = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                       THEN abap_true ELSE mv_compact )
            i_plain          = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                       THEN abap_true ELSE abap_false )
            i_ignore_case    = mv_ignore_case
            it_blame         = lt_blame
            it_blame_deleted = lt_blame_deleted ).
        ENDIF.
        INSERT VALUE ty_diff_cache( key = ls_cache_key html = lv_html ) INTO TABLE mt_diff_cache.
        set_html( lv_html ).
      CATCH cx_root INTO DATA(lx_compare).
        DATA(lv_err_txt) = escape( val = lx_compare->get_text( ) format = cl_abap_format=>e_html_text ).
        DATA(lv_err_diffline) = zcl_ave_popup_html=>gv_render_line.
        set_html( |<html><body style="padding:24px;font:13px Consolas;color:#c00">| &&
          |Error loading versions for comparison.<br><br>{ lv_err_txt }| &&
          COND string( WHEN lv_err_diffline > 0
            THEN |<br><br><span style="color:#888;font-size:11px">diff source line { lv_err_diffline }</span>|
            ELSE `` ) &&
          |</body></html>| ).
    ENDTRY.
  ENDMETHOD.


  METHOD cr_precompute_class_parts.
    DATA(lv_before) = lines( mt_acr_stats ).
    TRY.
        DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
          object_type = zcl_ave_object_factory=>gc_type-class
          object_name = CONV #( i_class_name ) ).
        LOOP AT lo_obj->get_parts( ) INTO DATA(ls_part).
          CHECK ls_part-type <> 'CLSD' AND ls_part-type <> 'RELE'.
          cr_precompute_part( VALUE #(
            type        = ls_part-type
            name        = ls_part-unit
            class       = ls_part-class
            object_name = ls_part-object_name ) ).
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
    result = boolc( lines( mt_acr_stats ) > lv_before ).
  ENDMETHOD.


  METHOD cr_precompute_part.
    " CLAS rows are aggregate markers — they have no direct diff source
    CHECK is_part-type <> 'CLAS'.

    " Use load_versions — same as Version Explorer — fills mt_versions with
    " correct obj_owner (nearest-task logic), trfunction, datum, zeit.
    load_versions( i_objtype = is_part-type i_objname = is_part-object_name ).
    CHECK mt_versions IS NOT INITIAL.

    " Build range: request + all its tasks
    DATA lt_korr_range TYPE RANGE OF verskorrno.
    DATA(lv_req) = CONV verskorrno( mv_object_name ).
    APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_req ) TO lt_korr_range.
    SELECT trkorr FROM e070 WHERE strkorr = @lv_req INTO TABLE @DATA(lt_tasks_cr).
    LOOP AT lt_tasks_cr INTO DATA(ls_task_cr).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = CONV verskorrno( ls_task_cr-trkorr ) )
        TO lt_korr_range.
    ENDLOOP.

    " Find new version (belongs to this transport) and prior version — same as user does in VE
    DATA ls_new TYPE ty_version_row.
    DATA ls_old TYPE ty_version_row.
    DATA lv_idx TYPE i.
    LOOP AT mt_versions INTO ls_new.
      IF ls_new-korrnum IN lt_korr_range.
        lv_idx = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.
    CHECK ls_new IS NOT INITIAL.
    IF mv_filter_user IS NOT INITIAL AND ls_new-author <> mv_filter_user.
      RETURN.
    ENDIF.
    READ TABLE mt_versions INTO ls_old INDEX lv_idx + 1.
    DATA(lv_is_created) = COND abap_bool( WHEN sy-subrc <> 0 THEN abap_true ELSE abap_false ).

    DATA(lv_versno_new) = ls_new-versno.
    DATA(lv_versno_old) = ls_old-versno.

    TRY.
        " Load sources — same as show_versions_diff
        DATA lt_vrsd_n TYPE vrsd_tab.
        DATA(lv_vno_n) = zcl_ave_versno=>to_internal( lv_versno_new ).
        SELECT * FROM vrsd WHERE objtype = @is_part-type AND objname = @is_part-object_name
          AND versno = @lv_vno_n INTO TABLE @lt_vrsd_n UP TO 1 ROWS.
        IF lt_vrsd_n IS INITIAL.
          APPEND VALUE vrsd( objtype = is_part-type objname = is_part-object_name
                             versno = lv_vno_n ) TO lt_vrsd_n.
        ENDIF.
        DATA(lt_src_n) = NEW zcl_ave_version( lt_vrsd_n[ 1 ] )->get_source( ).
        " Old source: empty for brand-new objects (no prior version → all-green diff)
        DATA lt_src_o TYPE abaptxt255_tab.
        IF lv_is_created = abap_false.
          DATA lt_vrsd_o TYPE vrsd_tab.
          DATA(lv_vno_o) = zcl_ave_versno=>to_internal( lv_versno_old ).
          SELECT * FROM vrsd WHERE objtype = @is_part-type AND objname = @is_part-object_name
            AND versno = @lv_vno_o INTO TABLE @lt_vrsd_o UP TO 1 ROWS.
          IF lt_vrsd_o IS INITIAL.
            APPEND VALUE vrsd( objtype = is_part-type objname = is_part-object_name
                               versno = lv_vno_o ) TO lt_vrsd_o.
          ENDIF.
          lt_src_o = NEW zcl_ave_version( lt_vrsd_o[ 1 ] )->get_source( ).
        ENDIF.

        DATA(lt_diff) = zcl_ave_popup_diff=>compute_diff(
          it_old        = lt_src_o
          it_new        = lt_src_n
          i_title       = CONV #( is_part-object_name )
          i_ignore_case = mv_ignore_case ).

        " Blame — pass mt_versions directly, same as show_versions_diff
        DATA lt_blame         TYPE ty_blame_map.
        DATA lt_blame_deleted TYPE ty_blame_map.
        IF mv_blame = abap_true.
          lt_blame = zcl_ave_popup_diff=>build_blame_map(
            EXPORTING it_versions      = mt_versions
                      i_objtype        = is_part-type
                      i_objname        = is_part-object_name
                      i_from           = lv_versno_old
                      i_to             = lv_versno_new
            IMPORTING et_blame_deleted = lt_blame_deleted ).
        ENDIF.

        " Render HTML — same as show_versions_diff
        DATA(lv_meta_cr) = COND string(
          WHEN lv_is_created = abap_true
          THEN |{ ls_new-versno_text } → (new object)|
          ELSE |{ ls_new-versno_text } → { ls_old-versno_text }| ).
        DATA(lv_html) = zcl_ave_popup_html=>diff_to_html(
          it_diff          = lt_diff
          i_title          = |{ is_part-type }: { is_part-object_name }|
          i_meta           = lv_meta_cr
          i_two_pane       = mv_two_pane
          i_compact        = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                     THEN abap_true ELSE mv_compact )
          i_plain          = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                     THEN abap_true ELSE abap_false )
          i_ignore_case    = mv_ignore_case
          i_code_review    = abap_true
          it_blame         = lt_blame
          it_blame_deleted = lt_blame_deleted ).

        DATA lt_hunk_html TYPE string_table.
        DATA lv_rows_html TYPE string.
        DATA lv_tb_off TYPE i.
        DATA lv_tb_len TYPE i.
        FIND FIRST OCCURRENCE OF `<table><tbody>` IN lv_html
          MATCH OFFSET lv_tb_off MATCH LENGTH lv_tb_len.
        IF sy-subrc = 0.
          DATA(lv_rows_start) = lv_tb_off + lv_tb_len.
          DATA(lv_rows_tail) = lv_html+lv_rows_start.
          DATA lv_rows_end TYPE i.
          FIND FIRST OCCURRENCE OF `</tbody></table>` IN lv_rows_tail MATCH OFFSET lv_rows_end.
          IF sy-subrc = 0.
            lv_rows_html = lv_rows_tail(lv_rows_end).
          ENDIF.
        ENDIF.
        IF lv_rows_html IS NOT INITIAL.
          DATA lv_scan_off TYPE i VALUE 0.
          DO.
            DATA(lv_scan_tail) = lv_rows_html+lv_scan_off.
            DATA lv_add_rel TYPE i.
            DATA lv_del_rel TYPE i.
            DATA lv_has_add TYPE abap_bool.
            DATA lv_has_del TYPE abap_bool.
            CLEAR: lv_add_rel, lv_del_rel, lv_has_add, lv_has_del.
            FIND FIRST OCCURRENCE OF `<tr style="background:#e8f4e8` IN lv_scan_tail MATCH OFFSET lv_add_rel.
            IF sy-subrc = 0. lv_has_add = abap_true. ENDIF.
            FIND FIRST OCCURRENCE OF `<tr style="background:#fdf0f0` IN lv_scan_tail MATCH OFFSET lv_del_rel.
            IF sy-subrc = 0. lv_has_del = abap_true. ENDIF.
            IF lv_has_add = abap_false AND lv_has_del = abap_false.
              EXIT.
            ENDIF.
            DATA(lv_hstart_rel) = COND i(
              WHEN lv_has_add = abap_true AND lv_has_del = abap_true AND lv_add_rel <= lv_del_rel THEN lv_add_rel
              WHEN lv_has_add = abap_true AND lv_has_del = abap_false THEN lv_add_rel
              ELSE lv_del_rel ).
            DATA(lv_hstart) = lv_scan_off + lv_hstart_rel.
            DATA(lv_next_start) = lv_hstart + 1.
            DATA(lv_next_tail) = lv_rows_html+lv_next_start.
            CLEAR: lv_add_rel, lv_del_rel, lv_has_add, lv_has_del.
            FIND FIRST OCCURRENCE OF `<tr style="background:#e8f4e8` IN lv_next_tail MATCH OFFSET lv_add_rel.
            IF sy-subrc = 0. lv_has_add = abap_true. ENDIF.
            FIND FIRST OCCURRENCE OF `<tr style="background:#fdf0f0` IN lv_next_tail MATCH OFFSET lv_del_rel.
            IF sy-subrc = 0. lv_has_del = abap_true. ENDIF.
            DATA(lv_hend) = strlen( lv_rows_html ).
            IF lv_has_add = abap_true OR lv_has_del = abap_true.
              DATA(lv_next_rel) = COND i(
                WHEN lv_has_add = abap_true AND lv_has_del = abap_true AND lv_add_rel <= lv_del_rel THEN lv_add_rel
                WHEN lv_has_add = abap_true AND lv_has_del = abap_false THEN lv_add_rel
                ELSE lv_del_rel ).
              lv_hend = lv_hstart + 1 + lv_next_rel.
            ENDIF.
            DATA(lv_hlen) = lv_hend - lv_hstart.
            APPEND lv_rows_html+lv_hstart(lv_hlen) TO lt_hunk_html.
            lv_scan_off = lv_hend.
          ENDDO.
        ENDIF.

        INSERT VALUE ty_diff_cache(
          key  = VALUE #(
            objtype     = is_part-type
            objname     = is_part-object_name
            versno_o    = lv_versno_old
            versno_n    = lv_versno_new
            blame       = mv_blame
            two_pane    = mv_two_pane
            compact     = mv_compact
            debug       = mv_debug
            ignore_case = mv_ignore_case )
          html = lv_html )
          INTO TABLE mt_diff_cache.

        " Compute ins/del/mod statistics
        DATA lv_ins TYPE i. DATA lv_del TYPE i. DATA lv_mod TYPE i.
        DATA lt_auth TYPE zif_ave_acr_types=>ty_t_author_stats.
        zcl_ave_acr_stats=>from_diff(
          EXPORTING it_diff    = lt_diff
                    it_blame   = lt_blame
          IMPORTING ev_ins     = lv_ins
                    ev_del     = lv_del
                    ev_mod     = lv_mod
                    et_authors = lt_auth ).

        " Owner and date/time — taken from ls_new (already enriched by load_versions)
        DATA(lv_author) = COND versuser(
          WHEN ls_new-obj_owner IS NOT INITIAL THEN ls_new-obj_owner
          ELSE ls_new-author ).
        DATA(lv_datum)  = ls_new-datum.
        DATA(lv_zeit)   = ls_new-zeit.

        " Display name: method name / section label for class parts
        DATA(lv_disp_name) = CONV string( is_part-name ).

        " Count change blocks (hunks) from diff, skipping whitespace-only hunks
        DATA lv_hunk_cnt  TYPE i VALUE 0.
        DATA lv_in_hunk   TYPE abap_bool VALUE abap_false.
        DATA lt_cur_hunk  TYPE string_table.
        DATA lv_new_line   TYPE i VALUE 0.
        DATA lv_hunk_line  TYPE i.
        DATA lv_hunk_chg   TYPE i.
        DATA lv_hunk_auth  TYPE versuser.
        DELETE mt_hunk_info WHERE objtype = is_part-type AND obj_name = is_part-object_name.
        LOOP AT lt_diff INTO DATA(ls_dop).
          CASE ls_dop-op.
            WHEN '+' OR '-'.
              IF lv_in_hunk = abap_false.
                lv_in_hunk = abap_true.
                CLEAR: lt_cur_hunk, lv_hunk_chg, lv_hunk_auth.
                lv_hunk_line = lv_new_line + 1.
              ENDIF.
              lv_hunk_chg += 1.
              APPEND CONV string( ls_dop-text ) TO lt_cur_hunk.
              IF ls_dop-op = '+'.
                IF lv_hunk_auth IS INITIAL AND lt_blame IS NOT INITIAL.
                  READ TABLE lt_blame INTO DATA(ls_hb) WITH KEY text = ls_dop-text.
                  IF sy-subrc = 0. lv_hunk_auth = ls_hb-author. ENDIF.
                ENDIF.
                lv_new_line += 1.
              ENDIF.
            WHEN OTHERS.
              IF lv_in_hunk = abap_true.
                IF zcl_ave_acr_stats=>is_blank_hunk( lt_cur_hunk ) = abap_false.
                  lv_hunk_cnt += 1.
                  DATA(lv_hunk_key) = |{ is_part-type }~{ is_part-object_name }~{ lv_hunk_cnt }|.
                  DATA(lv_info_author) = COND versuser(
                    WHEN lv_hunk_auth IS NOT INITIAL THEN lv_hunk_auth
                    ELSE lv_author ).
                  DATA lv_info_html TYPE string.
                  READ TABLE lt_hunk_html INTO lv_info_html INDEX lv_hunk_cnt.
                  INSERT VALUE ty_hunk_info(
                    hunk_key     = lv_hunk_key
                    objtype      = is_part-type
                    obj_name     = is_part-object_name
                    class_name   = CONV #( is_part-class )
                    display_name = lv_disp_name
                    hunk_no      = lv_hunk_cnt
                    start_line   = lv_hunk_line
                    change_count = lv_hunk_chg
                    author       = lv_info_author
                    author_name  = zcl_ave_popup_data=>get_user_name( lv_info_author )
                    html         = lv_info_html )
                    INTO TABLE mt_hunk_info.
                ENDIF.
                lv_in_hunk = abap_false.
                CLEAR: lt_cur_hunk, lv_hunk_chg, lv_hunk_auth.
              ENDIF.
              lv_new_line += 1.
          ENDCASE.
        ENDLOOP.
        " flush last hunk if diff ends without '='
        IF lv_in_hunk = abap_true AND zcl_ave_acr_stats=>is_blank_hunk( lt_cur_hunk ) = abap_false.
          lv_hunk_cnt += 1.
          DATA(lv_last_hunk_key) = |{ is_part-type }~{ is_part-object_name }~{ lv_hunk_cnt }|.
          DATA(lv_last_info_author) = COND versuser(
            WHEN lv_hunk_auth IS NOT INITIAL THEN lv_hunk_auth
            ELSE lv_author ).
          DATA lv_last_info_html TYPE string.
          READ TABLE lt_hunk_html INTO lv_last_info_html INDEX lv_hunk_cnt.
          INSERT VALUE ty_hunk_info(
            hunk_key     = lv_last_hunk_key
            objtype      = is_part-type
            obj_name     = is_part-object_name
            class_name   = CONV #( is_part-class )
            display_name = lv_disp_name
            hunk_no      = lv_hunk_cnt
            start_line   = lv_hunk_line
            change_count = lv_hunk_chg
            author       = lv_last_info_author
            author_name  = zcl_ave_popup_data=>get_user_name( lv_last_info_author )
            html         = lv_last_info_html )
            INTO TABLE mt_hunk_info.
        ENDIF.

        APPEND VALUE zif_ave_acr_types=>ty_obj_stats(
          objtype      = is_part-type
          class_name   = CONV #( is_part-class )
          obj_name     = is_part-object_name
          display_name = lv_disp_name
          versno_new   = lv_versno_new
          versno_old   = lv_versno_old
          author       = lv_author
          author_name  = zcl_ave_popup_data=>get_user_name( lv_author )
          datum        = lv_datum
          zeit         = lv_zeit
          ins_count    = lv_ins
          del_count    = lv_del
          mod_count    = lv_mod
          hunk_count   = lv_hunk_cnt
          bt_authors   = lt_auth
          is_created   = lv_is_created )
          TO mt_acr_stats.

      CATCH cx_root.
        " Skip this part on any error — report will simply omit it
    ENDTRY.
  ENDMETHOD.


  METHOD inject_approve_btn.
    result = iv_html.

    " ── Blame info rows end with ' ──</td>' (unique to blame separators) ──
    CONSTANTS lc_blame TYPE string VALUE ` ──</td>`.
    DATA lt_bm TYPE match_result_tab.
    FIND ALL OCCURRENCES OF lc_blame IN result RESULTS lt_bm.

    DATA lv_total_hunks TYPE i.

    IF lt_bm IS NOT INITIAL.
      " Replace from end → start so earlier offsets stay valid
      DATA(lv_total) = lines( lt_bm ).
      lv_total_hunks = lv_total.
      SORT lt_bm BY offset DESCENDING.
      LOOP AT lt_bm INTO DATA(ls_bm).
        DATA(lv_n) = lv_total - sy-tabix + 1.   " 1 = topmost blame row
        DATA(lv_ck) = |{ iv_key }~{ lv_n }|.
        DATA lv_ins TYPE string.
        IF line_exists( mt_approved[ table_line = lv_ck ] ).
          lv_ins = |<a id="acr_c{ lv_n }"></a> ──| &&
                   `<span style="margin-left:10px;color:#27ae60;` &&
                   `font-style:normal;font-size:12px;font-weight:bold">&#10003; approved</span>` &&
                   |<a href="sapevent:undo~{ lv_ck }"| &&
                   ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;` &&
                   `border-radius:3px;padding:2px 7px">Undo</a></td>`.
        ELSEIF line_exists( mt_declined[ table_line = lv_ck ] ).
          " Look up decline note for this hunk
          DATA(lv_note_html) = ``.
          READ TABLE mt_decline_notes INTO DATA(ls_dn) WITH TABLE KEY hunk_key = lv_ck.
          IF sy-subrc = 0 AND ls_dn-note IS NOT INITIAL.
            " Escape note text and replace newlines with <br>
            DATA(lv_note_esc) = ls_dn-note.
            REPLACE ALL OCCURRENCES OF `&`  IN lv_note_esc WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<`  IN lv_note_esc WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>`  IN lv_note_esc WITH `&gt;`.
            REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_note_esc WITH `<br>`.
            lv_note_html =
              `<tr><td class="ln">&nbsp;</td><td class="cd" style="padding:6px 12px">` &&
              `<table cellspacing="0" cellpadding="0" border="0" style="display:inline">` &&
              `<tr><td bgcolor="#d3e5f2" style="padding:0 2px 2px 0">` &&
              `<table cellspacing="0" cellpadding="0" border="0" bgcolor="#f3f9ff">` &&
              `<tr><td style="padding:5px 9px;border:1px solid #a8cde8;` &&
              `border-top-color:#ffffff;border-left-color:#ffffff;` &&
              `font-size:11px;line-height:15px;color:#2874a6;` &&
              `font-style:italic;font-weight:normal">` &&
              `<font size="2" color="#2874a6"><i>` &&
              lv_note_esc && `</i></font></td></tr></table></td></tr></table></td></tr>`.
          ENDIF.
          lv_ins = |<a id="acr_c{ lv_n }"></a> ──| &&
                   `<span style="margin-left:10px;color:#e74c3c;` &&
                   `font-style:normal;font-size:12px;font-weight:bold">&#10007; declined</span>` &&
                   |<a href="sapevent:undo~{ lv_ck }"| &&
                   ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;` &&
                   `border-radius:3px;padding:2px 7px">Undo</a>` &&
                   |<a href="sapevent:editreview~{ lv_ck }"| &&
                   ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;` &&
                   `border-radius:3px;padding:2px 7px">Edit review</a></td>` &&
                   lv_note_html.
        ELSE.
          lv_ins = |<a id="acr_c{ lv_n }"></a> ──| &&
                   |<a href="sapevent:approve~{ lv_ck }"| &&
                   ` style="margin-left:10px;background:#27ae60;color:#fff;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;font-weight:bold;` &&
                   `border-radius:3px;padding:2px 7px">&#10003; approve</a>` &&
                   |<a href="sapevent:decline~{ lv_ck }"| &&
                   ` style="margin-left:8px;background:#922b21;color:#fff;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;font-weight:bold;` &&
                   `border-radius:3px;padding:2px 7px">&#10007; decline</a></td>`.
        ENDIF.
        DATA lv_off   TYPE i.
        DATA lv_after TYPE i.
        lv_off   = ls_bm-offset.
        lv_after = ls_bm-offset + ls_bm-length.
        result = result(lv_off) && lv_ins && result+lv_after.
      ENDLOOP.

    ELSE.
      " ── Fallback: compact '...' separator rows ──
      CONSTANTS lc_sep1 TYPE string VALUE
        `<tr style="background:#f0f0f0;color:#888"><td class="ln">...</td><td class="cd">...</td></tr>`.
      CONSTANTS lc_sep2 TYPE string VALUE
        `<tr style="background:#f0f0f0;color:#888"><td class="ln">...</td><td class="cd">...</td><td class="sep"></td><td class="ln">...</td><td class="cd">...</td></tr>`.
      DATA lv_sn TYPE i VALUE 0.
      DATA lv_found TYPE abap_bool.
      DO.
        lv_found = abap_false.
        IF result CS lc_sep2.
          lv_found = abap_true.
          lv_sn += 1.
          DATA(lv_cell2) = me->acr_approve_cell( iv_key = |{ iv_key }~{ lv_sn }| ).
          REPLACE FIRST OCCURRENCE OF lc_sep2 IN result WITH
            `<tr style="background:#f0f0f0;color:#888"><td class="ln">...</td>` &&
            `<td class="cd">...</td><td class="sep"></td><td class="ln">...</td>` &&
            lv_cell2 && `</tr>`.
        ELSEIF result CS lc_sep1.
          lv_found = abap_true.
          lv_sn += 1.
          DATA(lv_cell1) = me->acr_approve_cell( iv_key = |{ iv_key }~{ lv_sn }| ).
          REPLACE FIRST OCCURRENCE OF lc_sep1 IN result WITH
            `<tr style="background:#f0f0f0;color:#888"><td class="ln">...</td>` &&
            lv_cell1 && `</tr>`.
        ENDIF.
        IF lv_found = abap_false. EXIT. ENDIF.
      ENDDO.
      lv_total_hunks = lv_sn.

      " Single hunk, no separator — fixed button
      IF lv_sn = 0.
        lv_total_hunks = 1.
        result = replace( val = result sub = `</body>`
          with = me->acr_approve_fixed( iv_key = |{ iv_key }~1| ) && `</body>` ).
      ENDIF.
    ENDIF.

    " ── Store hunk count in stats ────────────────────────────────────
    DATA lv_tld TYPE i.
    FIND FIRST OCCURRENCE OF '~' IN iv_key MATCH OFFSET lv_tld.
    IF sy-subrc = 0.
      DATA lv_type  TYPE versobjtyp.
      DATA lv_oname TYPE versobjnam.
      lv_type = iv_key(lv_tld).
      DATA lv_nstart TYPE i.
      lv_nstart = lv_tld + 1.
      lv_oname = iv_key+lv_nstart.
      READ TABLE mt_acr_stats ASSIGNING FIELD-SYMBOL(<acrs>)
        WITH KEY objtype = lv_type obj_name = lv_oname.
      IF sy-subrc = 0 AND lv_total_hunks > <acrs>-hunk_count.
        <acrs>-hunk_count = lv_total_hunks.
      ENDIF.
    ENDIF.

    " ── "Approve All changes" fixed button (top-right) ──────────────
    DATA lv_appr_cnt TYPE i VALUE 0.
    DATA lv_decl_cnt TYPE i VALUE 0.
    DO lv_total_hunks TIMES.
      IF line_exists( mt_approved[ table_line = |{ iv_key }~{ sy-index }| ] ).
        lv_appr_cnt += 1.
      ELSEIF line_exists( mt_declined[ table_line = |{ iv_key }~{ sy-index }| ] ).
        lv_decl_cnt += 1.
      ENDIF.
    ENDDO.

    " Badge: ✓N (green) / ✗M (red) / total — always visible
    DATA(lv_badge) =
      |<span style="color:#27ae60">&#10003;{ lv_appr_cnt }</span>| &&
      | <span style="color:#e74c3c">&#10007;{ lv_decl_cnt }</span>| &&
      | <span style="color:#ccc">/{ lv_total_hunks }</span>|.

    DATA lv_all_btn TYPE string.
    IF lv_appr_cnt >= lv_total_hunks AND lv_total_hunks > 0.
      " All approved — static green label
      lv_all_btn =
        `<div style="position:fixed;top:8px;right:12px;z-index:999;` &&
        `background:#27ae60;color:#fff;padding:5px 16px;border-radius:4px;` &&
        `font:bold 12px Consolas,sans-serif">` &&
        |&#10003; All Approved &nbsp;{ lv_badge }</div>|.
    ELSE.
      " Clickable blue button
      lv_all_btn =
        |<div style="position:fixed;top:8px;right:12px;z-index:999">| &&
        |<a href="sapevent:approveall~{ iv_key }"| &&
        ` style="background:#2F2F2F;color:#fff;padding:5px 16px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">` &&
        |&#10003; Approve All &nbsp;{ lv_badge }</a></div>|.
    ENDIF.
    result = replace( val = result sub = `</body>` with = lv_all_btn && `</body>` ).

    " ── Back button (top-left) ───────────────────────────────────────
    DATA(lv_back_btn) =
      `<div style="position:fixed;top:8px;left:8px;z-index:999">` &&
      `<a href="sapevent:back~0"` &&
      ` style="background:#3498db;color:#fff;padding:5px 14px;` &&
      `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">` &&
      `&#8592; Back</a></div>`.
    result = replace( val = result sub = `</body>` with = lv_back_btn && `</body>` ).

  ENDMETHOD.


  METHOD acr_approve_cell.
    " Returns <td class="cd"> content for a separator row (inline approve/decline links)
    IF line_exists( mt_approved[ table_line = iv_key ] ).
      result = `<td class="cd" style="color:#27ae60;font-weight:bold">` &&
               `&#10003;&nbsp;approved` &&
               |<a href="sapevent:undo~{ iv_key }"| &&
               ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
               `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Undo</a></td>`.
    ELSEIF line_exists( mt_declined[ table_line = iv_key ] ).
      result = `<td class="cd" style="color:#e74c3c;font-weight:bold">` &&
               `&#10007;&nbsp;declined` &&
               |<a href="sapevent:undo~{ iv_key }"| &&
               ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
               `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Undo</a>` &&
               |<a href="sapevent:editreview~{ iv_key }"| &&
               ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
               `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Edit review</a></td>`.
    ELSE.
      result = |<td class="cd">...| &&
               |<a href="sapevent:approve~{ iv_key }"| &&
               | style="margin-left:12px;background:#27ae60;color:#fff;| &&
               |font-size:11px;font-weight:bold;text-decoration:none;| &&
               |border-radius:3px;padding:2px 7px">&#10003;&nbsp;approve</a>| &&
               |<a href="sapevent:decline~{ iv_key }"| &&
               | style="margin-left:8px;background:#922b21;color:#fff;| &&
               |font-size:11px;font-weight:bold;text-decoration:none;| &&
               |border-radius:3px;padding:2px 7px">&#10007;&nbsp;decline</a></td>|.
    ENDIF.
  ENDMETHOD.


  METHOD acr_approve_fixed.
    " Returns fixed-position button for diffs without separators
    IF line_exists( mt_approved[ table_line = iv_key ] ).
      result =
        `<div style="position:fixed;top:8px;right:12px;z-index:999;display:flex;gap:6px;align-items:center">` &&
        `<span style="background:#27ae60;color:#fff;padding:4px 14px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif">&#10003;&nbsp;Approved</span>` &&
        |<a href="sapevent:undo~{ iv_key }"| &&
        ` style="background:#95a5a6;color:#fff;padding:4px 10px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">Undo</a></div>`.
    ELSEIF line_exists( mt_declined[ table_line = iv_key ] ).
      result =
        `<div style="position:fixed;top:8px;right:12px;z-index:999;display:flex;gap:6px;align-items:center">` &&
        `<span style="background:#e74c3c;color:#fff;padding:4px 14px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif">&#10007;&nbsp;Declined</span>` &&
        |<a href="sapevent:undo~{ iv_key }"| &&
        ` style="background:#95a5a6;color:#fff;padding:4px 10px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">Undo</a>` &&
        |<a href="sapevent:editreview~{ iv_key }"| &&
        ` style="background:#3498db;color:#fff;padding:4px 10px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">Edit review</a></div>`.
    ELSE.
      result =
        |<div style="position:fixed;top:8px;right:12px;z-index:999;display:flex;gap:6px">| &&
        |<a href="sapevent:approve~{ iv_key }"| &&
        ` style="background:#27ae60;color:#fff;padding:4px 14px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">` &&
        `&#10003;&nbsp;Approve</a>` &&
        |<a href="sapevent:decline~{ iv_key }"| &&
        ` style="background:#922b21;color:#fff;padding:4px 14px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">` &&
        `&#10007;&nbsp;Decline</a></div>`.
    ENDIF.
  ENDMETHOD.


  METHOD on_sapevent.
    CHECK mv_code_review = abap_true.
    DATA lv_cmd  TYPE string.
    DATA lv_rest TYPE string.
    DATA lv_sep_off TYPE i.
    FIND FIRST OCCURRENCE OF '~' IN action MATCH OFFSET lv_sep_off.
    IF sy-subrc <> 0. RETURN. ENDIF.
    lv_cmd = action(lv_sep_off).
    DATA lv_sep_start TYPE i.
    lv_sep_start = lv_sep_off + 1.
    lv_rest = action+lv_sep_start.

    IF lv_cmd = 'back'.
      back_to_report( ).
      RETURN.

    ELSEIF lv_cmd = 'openobj'.
      " lv_rest = TYPE~OBJNAME  — open diff from report row double-click
      DATA lv_oo_tld TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rest MATCH OFFSET lv_oo_tld.
      IF sy-subrc = 0.
        DATA lv_oo_start TYPE i.
        lv_oo_start = lv_oo_tld + 1.
        DATA lv_oo_type TYPE versobjtyp.
        DATA lv_oo_name TYPE versobjnam.
        lv_oo_type = lv_rest(lv_oo_tld).
        lv_oo_name = lv_rest+lv_oo_start.
        open_cr_part( iv_objtype = lv_oo_type iv_objname = lv_oo_name ).
      ENDIF.
      RETURN.

    ELSEIF lv_cmd = 'openuserdeclined'.
      show_user_declines( iv_user = CONV #( lv_rest ) ).
      RETURN.

    ELSEIF lv_cmd = 'approveall'.
      " lv_rest = TYPE~OBJNAME — approve all hunks for this object
      DATA lv_tld2 TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rest MATCH OFFSET lv_tld2.
      DATA lv_nst2 TYPE i.
      lv_nst2 = lv_tld2 + 1.
      DATA lv_type2  TYPE versobjtyp.
      DATA lv_onam2  TYPE versobjnam.
      lv_type2 = lv_rest(lv_tld2).
      lv_onam2 = lv_rest+lv_nst2.
      READ TABLE mt_acr_stats INTO DATA(ls_st2)
        WITH KEY objtype = lv_type2 obj_name = lv_onam2.
      IF sy-subrc = 0 AND ls_st2-hunk_count > 0.
        DO ls_st2-hunk_count TIMES.
          DATA(lv_hk) = |{ lv_rest }~{ sy-index }|.
          INSERT lv_hk INTO TABLE mt_approved.
          DELETE TABLE mt_declined FROM lv_hk.
        ENDDO.
      ENDIF.

    ELSEIF lv_cmd = 'editreview'.
      " Open note dialog pre-filled with existing note for editing
      DATA lv_er_key TYPE string.
      lv_er_key = lv_rest.
      DATA lv_er_note TYPE string.
      READ TABLE mt_decline_notes INTO DATA(ls_er_note) WITH TABLE KEY hunk_key = lv_er_key.
      IF sy-subrc = 0. lv_er_note = ls_er_note-note. ENDIF.
      mo_note_dlg = NEW zcl_ave_acr_note_dlg(
        iv_title    = lv_er_key
        iv_hunk_key = lv_er_key
        iv_note     = lv_er_note ).
      SET HANDLER on_note_dlg_saved FOR mo_note_dlg.
      mo_note_dlg->show( ).
      RETURN.

    ELSEIF lv_cmd = 'undo'.
      DATA lv_undo_key TYPE string.
      lv_undo_key = lv_rest.
      DELETE TABLE mt_approved FROM lv_undo_key.
      DELETE TABLE mt_declined FROM lv_undo_key.
      DELETE TABLE mt_decline_notes WITH TABLE KEY hunk_key = lv_undo_key.
      IF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
        set_html( inject_approve_btn( iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ) ).
      ENDIF.
      regen_acr_report( ).
      refresh_rpt_row( ).
      RETURN.

    ELSEIF lv_cmd = 'approve' OR lv_cmd = 'decline'.
      DATA lv_key TYPE string.
      lv_key = lv_rest.
      IF lv_cmd = 'approve'.
        INSERT lv_key INTO TABLE mt_approved.
        DELETE TABLE mt_declined FROM lv_key.
      ELSE.
        " Open note dialog — decline is registered only when user clicks Save
        READ TABLE mt_decline_notes INTO DATA(ls_dn_exist) WITH TABLE KEY hunk_key = lv_key.
        DATA lv_prev_note TYPE string.
        IF sy-subrc = 0. lv_prev_note = ls_dn_exist-note. ENDIF.
        mo_note_dlg = NEW zcl_ave_acr_note_dlg(
          iv_title    = lv_key
          iv_hunk_key = lv_key
          iv_note     = lv_prev_note ).
        SET HANDLER on_note_dlg_saved FOR mo_note_dlg.
        mo_note_dlg->show( ).
        RETURN.  " Decline will be registered in on_note_dlg_saved event
      ENDIF.

      IF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
        DATA(lv_html) = inject_approve_btn(
          iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ).

        " Scroll to the acted chunk by its anchor id
        DATA(lv_rev) = reverse( lv_key ).
        DATA lv_tilde_pos TYPE i.
        FIND FIRST OCCURRENCE OF '~' IN lv_rev MATCH OFFSET lv_tilde_pos.
        IF sy-subrc = 0.
          DATA lv_chunk_start TYPE i.
          lv_chunk_start = strlen( lv_key ) - lv_tilde_pos.
          DATA(lv_chunk) = lv_key+lv_chunk_start.
          IF lv_chunk IS NOT INITIAL.
            DATA(lv_script) =
              `<script>window.onload=function(){` &&
              `var e=document.getElementById('acr_c` && lv_chunk && `');` &&
              `if(e)e.scrollIntoView({block:'center'});}` &&
              `</script></head>`.
            lv_html = replace( val = lv_html sub = `</head>` with = lv_script ).
          ENDIF.
        ENDIF.

        set_html( lv_html ).
        regen_acr_report( ).
        refresh_rpt_row( ).
        RETURN.
      ENDIF.
    ENDIF.

    " approveall path (or approve without cached html)
    IF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
      set_html( inject_approve_btn( iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ) ).
    ENDIF.
    regen_acr_report( ).
    refresh_rpt_row( ).
  ENDMETHOD.


  METHOD maximize_html.
    CHECK mv_focus_html = abap_false.
    mv_focus_html = abap_true.
    mo_toolbar->set_button_info(
      EXPORTING fcode = 'FOCUS_TOGGLE'
                text  = 'Standard View'
                icon  = CONV #( icon_view_maximize ) ).
    IF mv_two_pane = abap_true.
      mo_split_2p_wrap->set_row_height( id = 1 height = 0 ).
      mo_split_2p_wrap->set_row_height( id = 2 height = 100 ).
      mo_split_2p_wrap->set_row_sash( id = 1 type = 0 value = 0 ).
    ELSE.
      mo_split_main->set_column_width( id = 1 width = 0 ).
      mo_split_main->set_column_width( id = 2 width = 100 ).
      mo_split_main->set_column_sash( id = 1 type = 0 value = 0 ).
    ENDIF.
  ENDMETHOD.


  METHOD back_to_report.
    maximize_html( ).
    set_html( mv_cr_report_html ).
  ENDMETHOD.

  METHOD show_user_declines.
    TYPES: BEGIN OF ty_decl_row,
             class_name   TYPE seoclsname,
             objtype      TYPE versobjtyp,
             obj_name     TYPE versobjnam,
             display_name TYPE string,
             hunk_no      TYPE i,
             start_line   TYPE i,
             change_count TYPE i,
             note         TYPE string,
             html         TYPE string,
           END OF ty_decl_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_decl_row WITH DEFAULT KEY.

    LOOP AT mt_decline_notes INTO DATA(ls_note).
      CHECK ls_note-note IS NOT INITIAL.
      READ TABLE mt_hunk_info INTO DATA(ls_hi) WITH TABLE KEY hunk_key = ls_note-hunk_key.
      CHECK sy-subrc = 0.
      CHECK ls_hi-author = iv_user.
      APPEND VALUE #(
        class_name   = ls_hi-class_name
        objtype      = ls_hi-objtype
        obj_name     = ls_hi-obj_name
        display_name = ls_hi-display_name
        hunk_no      = ls_hi-hunk_no
        start_line   = ls_hi-start_line
        change_count = ls_hi-change_count
        note         = ls_note-note
        html         = ls_hi-html ) TO lt_rows.
    ENDLOOP.

    SORT lt_rows BY class_name objtype obj_name hunk_no.

    DATA(lv_user_name) = zcl_ave_popup_data=>get_user_name( iv_user ).
    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:42px 28px 20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `.objhdr{margin:18px 0 8px 0;background:#dbe9ff;color:#2c3e50;padding:5px 10px;` &&
      `font-weight:bold;white-space:nowrap}` &&
      `.block{margin:0 0 14px 0;cursor:pointer}` &&
      `.block:hover .note{background:#e8f4ff}` &&
      `.blkinfo{margin:5px 0 2px 0;color:#2c3e50;font-weight:bold;white-space:nowrap}` &&
      `.muted{color:#777;font-weight:normal}` &&
      `.note{display:inline-block;margin:6px 0 6px 0;padding:5px 9px;background:#f3f9ff;` &&
      `border:1px solid #a8cde8;color:#155f8f;font-style:italic;font-weight:bold}` &&
      `table.diff{border-collapse:collapse;width:100%;font-size:12px;margin:0 0 4px 0}` &&
      `.diff .ln{color:#aaa;text-align:right;padding:1px 10px 1px 5px;` &&
      `min-width:42px;border-right:1px solid #e0e0e0;white-space:nowrap;background:#fafafa}` &&
      `.diff .cd{padding:1px 8px;white-space:pre}` &&
      `.back{position:fixed;top:8px;left:12px;z-index:999;background:#3498db;color:#fff;` &&
      `padding:4px 10px;border-radius:4px;text-decoration:none;font-weight:bold}`.

    DATA(lv_html) =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ lv_css }</style></head><body>| &&
      |<a class="back" href="sapevent:back~0">Back</a>| &&
      |<h2>Declined notes: { escape( val = CONV string( iv_user ) format = cl_abap_format=>e_html_text ) }| &&
      | / { escape( val = CONV string( lv_user_name ) format = cl_abap_format=>e_html_text ) }</h2>|.

    IF lt_rows IS INITIAL.
      lv_html = lv_html &&
        |<p style="color:#888">No declined notes for this owner.</p>| &&
        |</body></html>|.
      maximize_html( ).
      set_html( lv_html ).
      RETURN.
    ENDIF.

    DATA lv_cur_obj TYPE string VALUE `####`.
    LOOP AT lt_rows INTO DATA(ls_row).
      DATA(lv_obj_key) = |{ ls_row-objtype }~{ ls_row-obj_name }|.
      IF lv_obj_key <> lv_cur_obj.
        lv_cur_obj = lv_obj_key.
        DATA(lv_title) = COND string(
          WHEN ls_row-class_name IS NOT INITIAL AND ls_row-display_name IS NOT INITIAL
          THEN |{ ls_row-class_name }=>{ ls_row-display_name }|
          WHEN ls_row-display_name IS NOT INITIAL THEN ls_row-display_name
          ELSE CONV string( ls_row-obj_name ) ).
        DATA lv_obj_blocks TYPE i.
        DATA lv_obj_changes TYPE i.
        DATA lv_obj_start TYPE i.
        CLEAR: lv_obj_blocks, lv_obj_changes, lv_obj_start.
        LOOP AT lt_rows INTO DATA(ls_sum)
          WHERE objtype = ls_row-objtype AND obj_name = ls_row-obj_name.
          lv_obj_blocks += 1.
          lv_obj_changes += ls_sum-change_count.
          IF lv_obj_start = 0 OR ls_sum-start_line < lv_obj_start.
            lv_obj_start = ls_sum-start_line.
          ENDIF.
        ENDLOOP.
        lv_html = lv_html &&
          |<div class="objhdr">| &&
          |{ escape( val = CONV string( ls_row-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
          |{ escape( val = lv_title format = cl_abap_format=>e_html_text ) }| &&
          | <span class="muted">/ blocks</span> { lv_obj_blocks }| &&
          | <span class="muted">/ first line</span> { lv_obj_start }| &&
          | <span class="muted">/ changes</span> { lv_obj_changes } lines</div>|.
      ENDIF.

      DATA(lv_note_esc) = escape( val = ls_row-note format = cl_abap_format=>e_html_text ).
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_note_esc WITH `<br>`.
      DATA(lv_row_attr) =
        `ondblclick="window.location.href='sapevent:openobj~` &&
        lv_obj_key && `'" title="Double-click to open diff"`.
      DATA(lv_code_html) = COND string(
        WHEN ls_row-html IS NOT INITIAL
        THEN |<table class="diff"><tbody>{ ls_row-html }</tbody></table>|
        ELSE |<div style="color:#888;margin:4px 0 10px">Diff block is not available.</div>| ).
      lv_html = lv_html &&
        |<div class="block" { lv_row_attr }>| &&
        |<div class="blkinfo">Block #{ ls_row-hunk_no }| &&
        | <span class="muted">/ start line</span> { ls_row-start_line }| &&
        | <span class="muted">/ changes</span> { ls_row-change_count } lines</div>| &&
        |<div class="note">{ lv_note_esc }</div>| &&
        lv_code_html &&
        |</div>|.
    ENDLOOP.
    lv_html = lv_html && `</body></html>`.

    maximize_html( ).
    set_html( lv_html ).
  ENDMETHOD.


  METHOD open_cr_part.
    " Open the diff for a given type/name — called from report row double-click
    READ TABLE mt_acr_stats INTO DATA(ls_stat)
      WITH KEY objtype = iv_objtype obj_name = iv_objname.
    IF sy-subrc <> 0. RETURN. ENDIF.

    DATA(ls_ck) = VALUE ty_diff_cache_key(
      objtype     = ls_stat-objtype
      objname     = ls_stat-obj_name
      versno_o    = ls_stat-versno_old
      versno_n    = ls_stat-versno_new
      blame       = mv_blame
      two_pane    = mv_two_pane
      compact     = mv_compact
      debug       = mv_debug
      ignore_case = mv_ignore_case ).
    READ TABLE mt_diff_cache INTO DATA(ls_ch) WITH TABLE KEY key = ls_ck.
    IF sy-subrc <> 0. RETURN. ENDIF.

    " Highlight the matching part row in the ALV
    LOOP AT mt_parts ASSIGNING FIELD-SYMBOL(<lp>)
      WHERE type = iv_objtype AND object_name = iv_objname.
      mv_cur_objtype   = <lp>-type.
      mv_cur_objname   = <lp>-object_name.
      mv_cur_part_name = COND string(
        WHEN <lp>-class IS NOT INITIAL THEN |{ <lp>-class } – { <lp>-name }|
        ELSE <lp>-name ).
      EXIT.
    ENDLOOP.

    mv_cr_cur_key   = |{ ls_stat-objtype }~{ ls_stat-obj_name }|.
    mv_cr_base_html = ls_ch-html.
    set_html( inject_approve_btn( iv_html = ls_ch-html iv_key = mv_cr_cur_key ) ).
  ENDMETHOD.


  METHOD on_note_dlg_saved.
    " Called when user clicks Save in the decline note dialog.
    " Register decline and save note for this hunk key.
    DATA ls_dn TYPE ty_decline_note.
    ls_dn-hunk_key = iv_hunk_key.
    ls_dn-note     = iv_note.
    INSERT ls_dn INTO TABLE mt_decline_notes.
    IF sy-subrc <> 0. MODIFY TABLE mt_decline_notes FROM ls_dn. ENDIF.

    INSERT iv_hunk_key INTO TABLE mt_declined.
    DELETE TABLE mt_approved FROM iv_hunk_key.

    " Refresh diff view and report
    IF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
      set_html( inject_approve_btn( iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ) ).
    ENDIF.
    refresh_rpt_row( ).
    regen_acr_report( ).
  ENDMETHOD.


  METHOD regen_acr_report.
    mv_cr_report_html = zcl_ave_acr_report=>to_html(
      it_obj_stats = mt_acr_stats
      it_approved  = mt_approved
      it_declined  = mt_declined
      i_korrnum    = CONV #( mv_object_name ) ).
  ENDMETHOD.


  METHOD refresh_rpt_row.
    DATA(lv_approved) = lines( mt_approved ).
    DATA(lv_name)     = |[ Code Review Report — { lv_approved } hunk(s) approved ]|.
    LOOP AT mt_parts ASSIGNING FIELD-SYMBOL(<rpt>) WHERE type = 'RPT'.
      <rpt>-name = lv_name.
      EXIT.
    ENDLOOP.
    refresh_parts( ).
  ENDMETHOD.
ENDCLASS.
