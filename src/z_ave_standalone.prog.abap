REPORT z_ave. " AVE - Abap Versions Explorer/Code Reviewer
" & Multi-windows program for ABAP object version comparison
" &----------------------------------------------------------------------
" & version: 1.00, 0.5 for Code Reviewer
" & Git https://github.com/ysichov/AVE

" & Written by Yurii Sychov
" & e-mail:   ysichov@gmail.com
" & blog:     https://ysychov.wordpress.com/blog/
" & LinkedIn: https://www.linkedin.com/in/ysychov/

" &Inspired by https://github.com/abapinho/abapTimeMachine , Eclipse Adt, GitHub and all others similar tools
" &----------------------------------------------------------------------
INTERFACE zif_ave_popup_types DEFERRED.
INTERFACE zif_ave_object DEFERRED.
INTERFACE zif_ave_acr_types DEFERRED.
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
CLASS zcl_ave_object_ddls DEFINITION DEFERRED.
CLASS zcl_ave_object_clas DEFINITION DEFERRED.
CLASS zcl_ave_author DEFINITION DEFERRED.
CLASS zcl_ave_acr_stats DEFINITION DEFERRED.
CLASS zcl_ave_acr_report DEFINITION DEFERRED.
CLASS zcl_ave_acr_note_dlg DEFINITION DEFERRED.
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

interface ZIF_AVE_ACR_TYPES .

    TYPES ty_approved TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

  "! Per-author change contribution inside one object diff
  TYPES:
    BEGIN OF ty_author_stats,
      author      TYPE versuser,
      author_name TYPE ad_namtext,
      ins_count   TYPE i,
      del_count   TYPE i,
      mod_count   TYPE i,
      hunk_count  TYPE i,
    END OF ty_author_stats.
  TYPES ty_t_author_stats TYPE STANDARD TABLE OF ty_author_stats WITH DEFAULT KEY.

  "! Statistics for one changed object: version pair, counts, blame breakdown
  TYPES:
    BEGIN OF ty_obj_stats,
      objtype     TYPE versobjtyp,
      class_name  TYPE seoclsname,   " parent class for METH / CPUB / CPRO / CPRI / CINC
      obj_name    TYPE versobjnam,
      versno_new  TYPE versno,
      versno_old  TYPE versno,
      author      TYPE versuser,
      author_name TYPE ad_namtext,
      datum       TYPE versdate,
      zeit        TYPE verstime,
      ins_count   TYPE i,
      del_count   TYPE i,
      mod_count   TYPE i,
      hunk_count    TYPE i,
      display_name  TYPE string,
      bt_authors    TYPE ty_t_author_stats,
      is_created    TYPE abap_bool,   " abap_true = object is brand-new (no prior version)
    END OF ty_obj_stats.
  TYPES ty_t_obj_stats TYPE STANDARD TABLE OF ty_obj_stats WITH DEFAULT KEY.
endinterface.

INTERFACE zif_ave_object.

  "! Popup display settings (maps to selection screen checkboxes)
  TYPES:
    BEGIN OF ty_settings,
      show_diff     TYPE abap_bool,
      layout        TYPE abap_bool,
      two_pane      TYPE abap_bool,
      no_toc        TYPE abap_bool,
      ignore_case   TYPE abap_bool,
      compact       TYPE abap_bool,
      remove_dup    TYPE abap_bool,
      blame         TYPE abap_bool,
      filter_user   TYPE versuser,
      date_from     TYPE versdate,
      code_review   TYPE abap_bool,
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
      trfunction     TYPE e070-trfunction,
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

CLASS zcl_ave_acr_note_dlg DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Opens a non-blocking text-editor dialog for entering a Decline note.
    "! Logic: close with text → SAVED event raised (decline registered).
    "!        close with empty text → nothing happens (decline cancelled).
    "! iv_title    : dialog caption, e.g. "METH~MY_METHOD - Block 3"
    "! iv_hunk_key : opaque key passed back unchanged in the SAVED event
    "! iv_note     : pre-filled text (for Edit Review)
    EVENTS saved
      EXPORTING
        VALUE(iv_hunk_key) TYPE string
        VALUE(iv_note)     TYPE string.
    EVENTS cancelled
      EXPORTING
        VALUE(iv_hunk_key) TYPE string.

    METHODS constructor
      IMPORTING iv_title    TYPE string
                iv_hunk_key TYPE string
                iv_note     TYPE string OPTIONAL.

    METHODS show.

  PRIVATE SECTION.
    DATA mv_title    TYPE string.
    DATA mv_hunk_key TYPE string.
    DATA mv_note     TYPE string.

    DATA mo_box      TYPE REF TO cl_gui_dialogbox_container.
    DATA mo_text     TYPE REF TO cl_gui_textedit.

    METHODS on_box_close
      FOR EVENT close OF cl_gui_dialogbox_container
      IMPORTING sender.
ENDCLASS.
CLASS zcl_ave_acr_report DEFINITION
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Build the Code Review Report HTML page from pre-computed object stats.
    CLASS-METHODS to_html
      IMPORTING it_obj_stats  TYPE zif_ave_acr_types=>ty_t_obj_stats
                i_korrnum     TYPE trkorr
                it_approved   TYPE zif_ave_acr_types=>ty_approved OPTIONAL
                it_declined   TYPE zif_ave_acr_types=>ty_approved OPTIONAL
      RETURNING VALUE(result) TYPE string.

protected section.
  PRIVATE SECTION.
    CLASS-METHODS esc
      IMPORTING iv_val        TYPE clike
      RETURNING VALUE(result) TYPE string.

ENDCLASS.
CLASS zcl_ave_acr_stats DEFINITION
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Compute ins/del/mod counts from a diff, mirroring the pairing logic of diff_to_html.
    "! When it_blame is supplied, also builds per-author contribution in et_authors
    "! including per-author hunk_count (each change block attributed to the first blamed line).
    "! Hunks consisting entirely of blank/whitespace lines are excluded from hunk_count.
    CLASS-METHODS from_diff
      IMPORTING it_diff    TYPE zif_ave_popup_types=>ty_t_diff
                it_blame   TYPE zif_ave_popup_types=>ty_blame_map OPTIONAL
      EXPORTING ev_ins     TYPE i
                ev_del     TYPE i
                ev_mod     TYPE i
                et_authors TYPE zif_ave_acr_types=>ty_t_author_stats.

    "! Returns abap_true if every changed line in the hunk is blank/whitespace-only.
    CLASS-METHODS is_blank_hunk
      IMPORTING it_lines      TYPE string_table
      RETURNING VALUE(result) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS add_blame
      IMPORTING iv_text     TYPE string
                iv_op       TYPE c            " '+' = ins, '~' = mod
                iv_new_hunk TYPE abap_bool DEFAULT abap_false
                it_blame    TYPE zif_ave_popup_types=>ty_blame_map
      CHANGING  ct_authors  TYPE zif_ave_acr_types=>ty_t_author_stats.

ENDCLASS.
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
"! Object handler for a CDS View (DDLS).
"! Returns one part of type DDLS; source is loaded via cl_svrs_tlogo_controller.
CLASS zcl_ave_object_ddls DEFINITION
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE versobjnam.

  PRIVATE SECTION.
    DATA name TYPE versobjnam.

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
        ddls     TYPE string VALUE 'DDLS',
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

protected section.
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

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
    "──────────── types ─────────────────────────────────────────────
    " Extended parts row: original fields + existence flag + row color
    BEGIN OF ty_part_row,
        class       TYPE string,
        name        TYPE string,
        type        TYPE versobjtyp,
        type_text   TYPE as4text,
        object_name TYPE versobjnam,
        exists_flag TYPE abap_bool,
        rows        TYPE i,
        rowcolor(4) TYPE c,
      END OF ty_part_row .
    TYPES:
    ty_t_part_row TYPE STANDARD TABLE OF ty_part_row WITH DEFAULT KEY .
    TYPES ty_version_row TYPE zif_ave_popup_types=>ty_version_row .
    TYPES ty_t_version_row TYPE zif_ave_popup_types=>ty_t_version_row .
    "! Delegated to ZCL_AVE_POPUP_DIFF (extracted diff engine)
    TYPES ty_diff_op TYPE zif_ave_popup_types=>ty_diff_op .
    TYPES ty_t_diff TYPE zif_ave_popup_types=>ty_t_diff .
  "! Delegated to ZCL_AVE_POPUP_HTML (extracted HTML renderer)
    TYPES ty_blame_entry TYPE zif_ave_popup_types=>ty_blame_entry .
    TYPES ty_blame_map TYPE zif_ave_popup_types=>ty_blame_map .
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
    CLASS-DATA mv_counter TYPE i .
    DATA mv_object_type TYPE string .
    DATA mv_object_name TYPE string .
    DATA mo_box TYPE REF TO cl_gui_dialogbox_container .
    DATA mo_split_main TYPE REF TO cl_gui_splitter_container .
    DATA mo_split_top TYPE REF TO cl_gui_splitter_container .
    DATA mo_cont_parts TYPE REF TO cl_gui_container .
    DATA mo_cont_html TYPE REF TO cl_gui_container .
    DATA mo_cont_vers TYPE REF TO cl_gui_container .
  " 2-pane layout containers
    DATA mo_split_wrap TYPE REF TO cl_gui_splitter_container .
    DATA mo_split_2p_top TYPE REF TO cl_gui_splitter_container .
    DATA mo_split_2p_wrap TYPE REF TO cl_gui_splitter_container .
    DATA mv_focus_html TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mo_cont_parts_2p TYPE REF TO cl_gui_container .
    DATA mo_cont_vers_2p TYPE REF TO cl_gui_container .
    DATA mo_cont_html_2p TYPE REF TO cl_gui_container .
    " Left panel: ALV Grid with the list of object parts
    DATA mo_alv_parts TYPE REF TO cl_gui_alv_grid .
    DATA mt_parts TYPE ty_t_part_row .
    " Right panel: HTML code viewer + ABAP editor (used for single-version
    " source view; HTML is too slow for 100k+ lines)
    DATA mo_html TYPE REF TO cl_gui_html_viewer .
    DATA mo_code_viewer TYPE REF TO cl_gui_abapedit .
  " Splits mo_cont_html into two rows — HTML (diff) on top, ABAP editor
  " (single-version source) on bottom. We toggle row heights 0/100 to
  " switch views reliably (z-order tricks with set_visible are unreliable).
    DATA mo_split_html TYPE REF TO cl_gui_splitter_container .
    DATA mo_cont_html_diff TYPE REF TO cl_gui_container .
    DATA mo_cont_html_code TYPE REF TO cl_gui_container .
    " Bottom panel: SALV table with version list
    DATA mo_alv_vers TYPE REF TO cl_gui_alv_grid .
    DATA mt_versions TYPE ty_t_version_row .
    DATA mv_cur_objtype TYPE versobjtyp .
    DATA mv_cur_objname TYPE versobjnam .
    DATA mv_cur_part_name TYPE string .  " Human-readable display name for caption (e.g. method name, section name)
    DATA mv_cur_creator TYPE versuser .
    DATA ms_base_ver TYPE ty_version_row .
    DATA ms_diff_old TYPE ty_version_row .
    DATA ms_diff_new TYPE ty_version_row .
    DATA mv_show_diff TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_layout TYPE abap_bool .
    DATA mv_two_pane TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_no_toc TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_compact TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_remove_dup TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_blame TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_ignore_case TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_task_view TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_diff_prev TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA mv_refreshing TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_debug TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_last_html TYPE string .
  "! When drilled into a class from a TR parts view, holds the class name so
  "! Refresh reloads only that class (not the outer TR).
    DATA mv_drilled_class TYPE seoclsname .
    DATA mv_filter_user TYPE versuser .
    DATA mv_date_from TYPE versdate .
    DATA mv_viewed_versno TYPE versno .
    " Backup for Back navigation (one level)
    DATA mt_parts_backup TYPE ty_t_part_row .
    DATA mt_diff_cache TYPE ty_t_diff_cache .
    DATA mo_toolbar TYPE REF TO cl_gui_toolbar .
    DATA mo_cont_toolbar TYPE REF TO cl_gui_container .
  " ── Code Reviewer mode ──────────────────────────────────────────
    DATA mv_code_review      TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mv_cr_prepared      TYPE abap_bool VALUE abap_false ##NO_TEXT.
    DATA mt_acr_stats        TYPE zif_ave_acr_types=>ty_t_obj_stats.
    DATA mv_cr_report_html   TYPE string.
    DATA mt_approved         TYPE zif_ave_acr_types=>ty_approved.
    DATA mt_declined         TYPE zif_ave_acr_types=>ty_approved.
  " Decline notes: key = hunk key (OBJTYPE~OBJNAME~N), value = note text
    TYPES: BEGIN OF ty_decline_note,
           hunk_key TYPE string,
           note     TYPE string,
         END OF ty_decline_note.
    TYPES ty_t_decline_notes TYPE HASHED TABLE OF ty_decline_note WITH UNIQUE KEY hunk_key.
    TYPES: BEGIN OF ty_decline_msg,
           author      TYPE syuname,
           author_name TYPE ad_namtext,
           created_at  TYPE timestampl,
           is_decline  TYPE abap_bool,
           text        TYPE string,
         END OF ty_decline_msg.
    TYPES ty_t_decline_msgs TYPE STANDARD TABLE OF ty_decline_msg WITH DEFAULT KEY.
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
    TYPES: BEGIN OF ty_hunk_thread,
           hunk_key     TYPE string,
           objtype      TYPE versobjtyp,
           obj_name     TYPE versobjnam,
           class_name   TYPE seoclsname,
           display_name TYPE string,
           hunk_no      TYPE i,
           start_line   TYPE i,
           change_count TYPE i,
           html         TYPE string,
           messages     TYPE ty_t_decline_msgs,
         END OF ty_hunk_thread.
    TYPES ty_t_hunk_threads TYPE HASHED TABLE OF ty_hunk_thread WITH UNIQUE KEY hunk_key.
    TYPES: BEGIN OF ty_saved_thread,
           hunk_key     TYPE string,
           objtype      TYPE versobjtyp,
           obj_name     TYPE versobjnam,
           class_name   TYPE seoclsname,
           display_name TYPE string,
           hunk_no      TYPE i,
           start_line   TYPE i,
           change_count TYPE i,
           messages     TYPE ty_t_decline_msgs,
         END OF ty_saved_thread.
    TYPES ty_t_saved_threads TYPE STANDARD TABLE OF ty_saved_thread WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_saved_key,
           hunk_key TYPE string,
         END OF ty_saved_key.
    TYPES ty_t_saved_keys TYPE STANDARD TABLE OF ty_saved_key WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_saved_note,
           hunk_key TYPE string,
           note     TYPE string,
         END OF ty_saved_note.
    TYPES ty_t_saved_notes TYPE STANDARD TABLE OF ty_saved_note WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_saved_user_state,
           reviewer      TYPE syuname,
           reviewer_name TYPE ad_namtext,
           saved_at      TYPE timestampl,
           approved      TYPE ty_t_saved_keys,
           declined      TYPE ty_t_saved_keys,
           notes         TYPE ty_t_saved_notes,
         END OF ty_saved_user_state.
    TYPES ty_t_saved_user_state TYPE STANDARD TABLE OF ty_saved_user_state WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_saved_history,
           saved_at       TYPE timestampl,
           saved_by       TYPE syuname,
           saved_by_name  TYPE ad_namtext,
           approved_count TYPE i,
           declined_count TYPE i,
           note_count     TYPE i,
         END OF ty_saved_history.
    TYPES ty_t_saved_history TYPE STANDARD TABLE OF ty_saved_history WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_saved_payload,
           schema_version TYPE i,
           trkorr         TYPE trkorr,
           last_saved_at  TYPE timestampl,
           last_saved_by  TYPE syuname,
           user_states    TYPE ty_t_saved_user_state,
           threads        TYPE ty_t_saved_threads,
           history        TYPE ty_t_saved_history,
         END OF ty_saved_payload.
    DATA mt_decline_notes    TYPE ty_t_decline_notes.
    DATA mt_hunk_info        TYPE ty_t_hunk_info.
    DATA mt_hunk_threads     TYPE ty_t_hunk_threads.
    DATA mv_cr_base_html     TYPE string.
    DATA mv_cr_cur_key       TYPE string.
    DATA mv_cr_report_scroll TYPE i.
    DATA mv_decline_view_user TYPE versuser.
  " Pending decline key — set before opening note dialog, used in saved-event handler
    DATA mv_pending_decline  TYPE string.
    DATA mo_note_dlg         TYPE REF TO zcl_ave_acr_note_dlg.
    DATA mo_help_box         TYPE REF TO cl_gui_dialogbox_container.
    DATA mo_help_html        TYPE REF TO cl_gui_html_viewer.

    "──────────── build ─────────────────────────────────────────────
    METHODS build_layout .
    METHODS build_parts_list .
    METHODS build_html_viewer .
    METHODS refresh_vers .
    METHODS refresh_parts .
    METHODS switch_pane_layout .
    METHODS create_parts_alv .
    METHODS create_versions_alv .
    METHODS create_html_viewer .
    METHODS build_versions_grid .
    "──────────── events ────────────────────────────────────────────
    METHODS handle_parts_toolbar
    FOR EVENT toolbar OF cl_gui_alv_grid
    IMPORTING
      !e_object
      !e_interactive .
    METHODS handle_parts_command
    FOR EVENT user_command OF cl_gui_alv_grid
    IMPORTING
      !e_ucomm .
    METHODS handle_parts_dblclick
    FOR EVENT double_click OF cl_gui_alv_grid
    IMPORTING
      !es_row_no
      !e_column .
    METHODS on_toolbar_click
    FOR EVENT function_selected OF cl_gui_toolbar
    IMPORTING
      !fcode .
    METHODS handle_vers_toolbar
    FOR EVENT toolbar OF cl_gui_alv_grid
    IMPORTING
      !e_object
      !e_interactive .
    METHODS handle_vers_command
    FOR EVENT user_command OF cl_gui_alv_grid
    IMPORTING
      !e_ucomm .
    METHODS handle_vers_dblclick
    FOR EVENT double_click OF cl_gui_alv_grid
    IMPORTING
      !es_row_no
      !e_column .
    METHODS on_box_close
    FOR EVENT close OF cl_gui_dialogbox_container
    IMPORTING
      !sender .
    METHODS on_help_box_close
    FOR EVENT close OF cl_gui_dialogbox_container
    IMPORTING
      !sender .
    METHODS on_sapevent
    FOR EVENT sapevent OF cl_gui_html_viewer
    IMPORTING
      !action
      !getdata
      !postdata .
    METHODS inject_approve_btn
    IMPORTING
      !iv_html  TYPE string
      !iv_key   TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS acr_approve_cell
    IMPORTING
      !iv_key   TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS acr_approve_fixed
    IMPORTING
      !iv_key   TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS refresh_rpt_row .
    METHODS regen_acr_report .
    METHODS build_cr_object_report_html
    RETURNING
      VALUE(result) TYPE string .
    METHODS prepare_code_review .
    METHODS maximize_html .
    METHODS on_note_dlg_saved
    FOR EVENT saved OF zcl_ave_acr_note_dlg
    IMPORTING
      !iv_hunk_key
      !iv_note .
    METHODS on_note_dlg_cancelled
    FOR EVENT cancelled OF zcl_ave_acr_note_dlg
    IMPORTING
      !iv_hunk_key .
    METHODS back_to_report .
    METHODS show_user_declines
    IMPORTING
      !iv_user TYPE versuser .
    METHODS open_cr_part
    IMPORTING
      !iv_objtype TYPE versobjtyp
      !iv_objname TYPE versobjnam .
    "──────────── logic ─────────────────────────────────────────────
    METHODS get_class_parts
    IMPORTING
      !i_name TYPE versobjnam
    RETURNING
      VALUE(result) TYPE ty_t_part_row
    RAISING
      zcx_ave .
    METHODS load_versions
    IMPORTING
      !i_objtype TYPE versobjtyp
      !i_objname TYPE versobjnam .
    METHODS load_versions_task_view
    IMPORTING
      !i_objtype TYPE versobjtyp
      !i_objname TYPE versobjnam .
    METHODS update_ver_colors
    IMPORTING
      !iv_viewed_versno TYPE versno OPTIONAL .
    METHODS show_source
    IMPORTING
      !i_objtype TYPE versobjtyp
      !i_objname TYPE versobjnam
      !i_versno TYPE versno .
    METHODS show_versions_diff
    IMPORTING
      !is_old TYPE ty_version_row
      !is_new TYPE ty_version_row .
  "! Auto-open guard: if is_new source exceeds 1000 lines, show source only;
  "! user can manually trigger a diff from the version list.
    METHODS auto_show_diff_or_source
    IMPORTING
      !is_old TYPE ty_version_row
      !is_new TYPE ty_version_row .
    METHODS set_html
    IMPORTING
      !iv_html TYPE string .
    METHODS has_review_table
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS load_review_from_db .
    METHODS save_review_to_db .
    METHODS load_review_payload
    IMPORTING
      !iv_trkorr TYPE trkorr
    EXPORTING
      !es_payload TYPE ty_saved_payload
    RETURNING
      VALUE(result) TYPE abap_bool .
    METHODS render_decline_thread_html
    IMPORTING
      !iv_hunk_key TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS render_hunk_actions_html
    IMPORTING
      !iv_hunk_key TYPE string
    RETURNING
      VALUE(result) TYPE string .
    METHODS build_review_help_html
    RETURNING
      VALUE(result) TYPE string .
    METHODS show_review_help_popup .
  "! Upload source to the ABAP editor and toggle visibility so it takes the
  "! place of the HTML viewer. Used for single-version (Show Vers) view.
    METHODS show_code_source
    IMPORTING
      !it_source TYPE abaptxt255_tab .
  "! Code Reviewer: compute diff+HTML+stats for one changed part and cache them.
  "! Mirrors the core of show_versions_diff but without UI side effects.
    METHODS cr_precompute_part
    IMPORTING
      !is_part TYPE ty_part_row .
  "! Code Reviewer: iterate all parts of a class, call cr_precompute_part for each.
  "! Returns true if at least one part was added to mt_acr_stats.
    METHODS cr_precompute_class_parts
    IMPORTING
      !i_class_name TYPE seoclsname
    RETURNING
      VALUE(result) TYPE abap_bool .
ENDCLASS.
CLASS zcl_ave_popup_data DEFINITION
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-DATA mv_no_toc TYPE abap_bool.

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

    "! True if any part of the class has changed vs its prior K-type version.
    CLASS-METHODS check_class_has_author
      IMPORTING i_class_name  TYPE string
      RETURNING VALUE(result) TYPE abap_bool.

    "! True if the latest version of the object was authored by i_user AND
    "! its source differs from the nearest prior version whose transport
    "! Builds a version list (newest-first, trfunction filled) for a given object.
    "! Used to feed is_substantive_user_change without extra DB queries at check time.
    CLASS-METHODS build_versions_for_check
      IMPORTING i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
      RETURNING VALUE(result) TYPE zif_ave_popup_types=>ty_t_version_row.

    "! Returns true if the latest version in it_versions differs from the
    "! nearest prior K-type version (source comparison).
    CLASS-METHODS is_substantive_user_change
      IMPORTING it_versions   TYPE zif_ave_popup_types=>ty_t_version_row
                i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
      RETURNING VALUE(result) TYPE abap_bool.

    "! Drop consecutive versions whose source is identical (ignoring leading
    "! whitespace). Input must be sorted newest-first.
    "! i_keep_korrnum: version with this korrnum is never removed (e.g. current TR baseline).
    "! When filled, source comparison is limited to the relevant window around this TR.
    CLASS-METHODS remove_duplicate_versions
      IMPORTING i_keep_korrnum TYPE trkorr OPTIONAL
      CHANGING  ct_versions    TYPE zif_ave_popup_types=>ty_t_version_row.

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

protected section.
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
      IMPORTING it_old          TYPE abaptxt255_tab
                it_new          TYPE abaptxt255_tab
                i_title         TYPE csequence DEFAULT 'Computing diff'
                i_ignore_case   TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(result)   TYPE ty_t_diff.

    "! Inline char-level diff for a single line pair.
    "!   iv_side = 'B' → both sides inline (default)
    "!   iv_side = 'N' → only insertion highlighted (new side)
    "!   iv_side = 'O' → only deletion highlighted (old side)
    CLASS-METHODS char_diff_html
      IMPORTING iv_old          TYPE string
                iv_new          TYPE string
                iv_side         TYPE c DEFAULT 'B'
                iv_ignore_case  TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(result) TYPE string.

    "! True if iv_a and iv_b are similar enough for pairing in change blocks.
    "! Used by diff_to_html to decide whether two changed lines are similar enough to pair.
    CLASS-METHODS has_common_chars
      IMPORTING iv_a          TYPE string
                iv_b          TYPE string
      RETURNING VALUE(result) TYPE abap_bool.

    "! Count edit runs in the middle parts of two strings (after stripping common prefix/suffix).
    "! Tokenizes by spaces and does a greedy forward LCS on tokens.
    "! Public so debug_diff_html can display per-pair metrics.
    CLASS-METHODS count_edit_runs
      IMPORTING iv_a          TYPE string
                iv_b          TYPE string
      RETURNING VALUE(result) TYPE i.

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

protected section.
  PRIVATE SECTION.
    CLASS-METHODS collapse_token_ops
      CHANGING ct_ops TYPE ty_t_diff.
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
                i_ignore_case     TYPE abap_bool OPTIONAL
                it_blame          TYPE ty_blame_map OPTIONAL
                it_blame_deleted  TYPE ty_blame_map OPTIONAL
                i_code_review     TYPE abap_bool OPTIONAL
      RETURNING VALUE(result)     TYPE string.

    "! Format a CDS/DDL source as HTML with syntax highlighting.
    CLASS-METHODS cds_source_to_html
      IMPORTING it_source      TYPE abaptxt255_tab
                i_title        TYPE string
                i_meta         TYPE string OPTIONAL
      RETURNING VALUE(rv_html) TYPE string.

    "! Debug rendering of diff ops and pairing decisions.
    CLASS-METHODS debug_diff_html
      IMPORTING it_diff       TYPE zif_ave_popup_types=>ty_t_diff
                i_title       TYPE string
                i_meta        TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE string.

    "! Last source line number being rendered — updated during diff_to_html/debug_diff_html.
    "! Read this in a CATCH block to know which line caused a rendering error.
    CLASS-DATA gv_render_line TYPE i.

  PRIVATE SECTION.
    CLASS-METHODS is_comment
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_bool) TYPE abap_bool.
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
                version_date  TYPE as4date OPTIONAL
                version_time  TYPE as4time OPTIONAL
      RETURNING VALUE(result) TYPE e070.

protected section.
  PRIVATE SECTION.

    METHODS populate_details
      IMPORTING
        !id TYPE trkorr
      RAISING
        zcx_ave.

    METHODS get_latest_task_for_object
      IMPORTING
                object_type   TYPE versobjtyp
                object_name   TYPE versobjnam
                version_date  TYPE as4date OPTIONAL
                version_time  TYPE as4time OPTIONAL
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

    "! Loads DDLS source via cl_svrs_tlogo_controller for any caller.
    "! i_versno is the EXTERNAL version number (e.g. 99998 for active, 00001 etc.).
    CLASS-METHODS load_ddls_source
      IMPORTING i_objname     TYPE versobjnam
                i_versno      TYPE versno
      RETURNING VALUE(result) TYPE abaptxt255_tab.

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
    IF vrsd-objtype = 'DDLS'.
      result = load_ddls_source(
        i_objname = vrsd-objname
        i_versno  = me->version_number ).
      RETURN.
    ENDIF.

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
  METHOD load_ddls_source.
    DATA: lo_controller TYPE REF TO cl_svrs_tlogo_controller,
          lo_db_view    TYPE REF TO cl_svrs_tlogo_db_view,
          lo_log_view   TYPE REF TO cl_svrs_tlogo_log_view.
    FIELD-SYMBOLS: <content> TYPE any,
                   <ddlsrc>  TYPE ANY TABLE,
                   <row>     TYPE any,
                   <field>   TYPE any.
    TRY.
        CREATE OBJECT lo_controller.
        lo_db_view = lo_controller->get_object(
          iv_objtype     = 'DDLS'
          iv_objname     = i_objname
          iv_versno      = i_versno
          iv_destination = '' ).
        CHECK lo_db_view IS BOUND.
        lo_log_view = lo_db_view->convert_to_log_view( ).
        CHECK lo_log_view IS BOUND AND lo_log_view->ar_content IS BOUND.
        ASSIGN lo_log_view->ar_content->* TO <content>.
        CHECK sy-subrc = 0.
        ASSIGN COMPONENT 'DDLSOURCE' OF STRUCTURE <content> TO <ddlsrc>.
        CHECK sy-subrc = 0.
        LOOP AT <ddlsrc> ASSIGNING <row>.
          ASSIGN COMPONENT 1 OF STRUCTURE <row> TO <field>.
          IF sy-subrc = 0.
            DATA lv_line TYPE string.
            lv_line = <field>.
            APPEND CONV abaptxt255( lv_line ) TO result.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
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
      object_type  = vrsd-objtype
      object_name  = vrsd-objname
      version_date = me->date
      version_time = me->time ).
    IF ls_e070-trkorr IS NOT INITIAL.
      me->task   = ls_e070-trkorr.
      me->author = ls_e070-as4user.
*      me->date   = ls_e070-as4date.
*      me->time   = ls_e070-as4time.
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
    " E070 may be empty in sandbox/copy systems — silently ignore.
  ENDMETHOD.
  METHOD get_task_for_object.
    DATA(lv_object_type) = SWITCH versobjtyp( object_type
      WHEN 'REPS' OR 'REPT' THEN 'PROG'
      WHEN 'CINC' OR 'CLSD' OR
           'CPUB' OR 'CPRO' OR 'CPRI' THEN 'CLAS'
      ELSE object_type ).
    DATA(lv_object_name) = object_name.
    CASE object_type.
      WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'REPT'.
        DATA(lv_eq) = find( val = lv_object_name sub = '=' ).
        IF lv_eq > 0.
          lv_object_name = lv_object_name(lv_eq).
        ENDIF.
    ENDCASE.

    result = get_latest_task_for_object(
      object_type  = lv_object_type
      object_name  = lv_object_name
      version_date = version_date
      version_time = version_time ).
  ENDMETHOD.
  METHOD get_latest_task_for_object.
    DATA(lv_trf_s) = CONV e070-trfunction( 'S' ).
    DATA lt_tasks TYPE STANDARD TABLE OF e070.
    TYPES: BEGIN OF ty_obj_key,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
           END OF ty_obj_key.
    DATA lt_keys TYPE SORTED TABLE OF ty_obj_key WITH UNIQUE KEY object obj_name.

    INSERT VALUE #( object = object_type obj_name = object_name ) INTO TABLE lt_keys.
    IF object_type = 'PROG'.
      INSERT VALUE #( object = 'REPS' obj_name = object_name ) INTO TABLE lt_keys.
    ELSEIF object_type = 'REPS'.
      INSERT VALUE #( object = 'PROG' obj_name = object_name ) INTO TABLE lt_keys.
    ENDIF.

    SELECT e070~trkorr, e070~strkorr, e070~as4user, e070~as4date, e070~as4time
      FROM e071
      INNER JOIN e070 ON e070~trkorr = e071~trkorr
      FOR ALL ENTRIES IN @lt_keys
      WHERE e071~object     = @lt_keys-object
        AND e071~obj_name   = @lt_keys-obj_name
        AND e070~trfunction = @lv_trf_s
      INTO CORRESPONDING FIELDS OF TABLE @lt_tasks.

    SORT lt_tasks BY as4date DESCENDING as4time DESCENDING.
    LOOP AT lt_tasks INTO DATA(ls_task).
      CHECK version_date IS INITIAL
         OR ls_task-as4date < version_date
         OR ( ls_task-as4date = version_date AND ls_task-as4time <= version_time ).
      result = ls_task.
      EXIT.
    ENDLOOP.
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

  METHOD is_comment.
    DATA(lv_t) = condense( val = iv_text ).
    rv_bool = boolc( strlen( lv_t ) > 0 AND ( lv_t(1) = `"` OR lv_t(1) = `*` ) ).
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
      i_title = 'Rendering diff' i_threshold_secs = 15 ).

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
          DATA(lv_cmt_eq2) = COND string( WHEN is_comment( ls_c2-text ) = abap_true
            THEN ` style="background:#fafae8"` ELSE `` ).
          lv_rows = lv_rows &&
            |<tr><td class="ln">{ lv_lno_l }</td>| &&
            |<td class="cd"{ lv_cmt_eq2 }>{ lv_eq2 }</td>| &&
            |<td class="sep"></td>| &&
            |<td class="ln">{ lv_lno_r }</td>| &&
            |<td class="cd"{ lv_cmt_eq2 }>{ lv_eq2 }</td></tr>|.
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
              DATA(lv_bverb2) = COND string( WHEN lv_nd = 0 THEN 'inserted' ELSE 'changed' ).
              DATA(lv_bline2s) = |── { lv_bauth2 } { lv_bverb2 }  { lv_bdate2 }| &&
                | { lv_btime2 }  v.{ ls_bl2-versno_text } ──|.
              DATA(lv_bline2) = |── { lv_bauth2 } { lv_bverb2 }  { lv_bdate2 }| &&
                | { lv_btime2 }  v.{ ls_bl2-versno_text }{ lv_btask2 }{ lv_btasktxt2 } ──|.
              IF strlen( ls_bl2-task_text ) > 10.
                " Split: first row without TR info, second row with TR info only
                lv_rows = lv_rows &&
                  |<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">| &&
                  |<td class="ln">▶</td><td class="cd" colspan="3">{ lv_bline2s }</td>| &&
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
                  |<tr style="background:#fdf0f0;color:#555;font-size:10px;font-style:italic;font-weight:bold">| &&
                  |<td class="ln">◀</td><td class="cd" colspan="3">── { lv_bdauth2 } deleted  { lv_bddate2 } { lv_bdtime2 }  v.{ ls_bld2-versno_text } ──</td>| &&
                  |<td class="ln"></td><td class="cd"></td></tr>| &&
                  |<tr style="background:#fdf0f0;color:#555;font-size:10px;font-style:italic;font-weight:bold">| &&
                  |<td class="ln"></td><td class="cd" colspan="3">──{ lv_bdtask2 }{ lv_bdtasktxt2 } ──</td>| &&
                  |<td class="ln"></td><td class="cd"></td></tr>|.
              ELSE.
                lv_rows = lv_rows &&
                  |<tr style="background:#fdf0f0;color:#555;font-size:10px;font-style:italic;font-weight:bold">| &&
                  |<td class="ln">◀</td><td class="cd" colspan="3">{ lv_bdline2 }</td>| &&
                  |<td class="ln"></td><td class="cd"></td></tr>|.
              ENDIF.
            ENDIF.
          ENDIF.

          DATA(lv_nd2) = lines( lt_d2 ).
          DATA(lv_ni2) = lines( lt_i2 ).

          DATA lt_d2_pair_idx TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
          DATA lt_i2_pair_idx TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
          DATA lt_d2_paired   TYPE TABLE OF abap_bool WITH DEFAULT KEY.
          DATA lt_i2_paired   TYPE TABLE OF abap_bool WITH DEFAULT KEY.
          DO lv_nd2 TIMES. APPEND abap_false TO lt_d2_paired. ENDDO.
          DO lv_ni2 TIMES. APPEND abap_false TO lt_i2_paired. ENDDO.

          IF lv_nd2 > 0 AND lv_ni2 > 0.
            DATA(lv_cols_2p) = lv_ni2 + 1.
            DATA(lv_rows_2p) = lv_nd2 + 1.
            DATA lt_dp_2p TYPE TABLE OF i.
            DATA(lv_size_2p) = lv_rows_2p * lv_cols_2p.
            DO lv_size_2p TIMES.
              APPEND 0 TO lt_dp_2p.
            ENDDO.

            DATA lv_di2 TYPE i.
            DATA lv_ii2 TYPE i.
            lv_di2 = 1.
            WHILE lv_di2 <= lv_nd2.
              lv_ii2 = 1.
              WHILE lv_ii2 <= lv_ni2.
                DATA(lv_cell_2p) = lv_di2 * lv_cols_2p + lv_ii2 + 1.
                IF zcl_ave_popup_diff=>has_common_chars( iv_a = lt_d2[ lv_di2 ] iv_b = lt_i2[ lv_ii2 ] ) = abap_true.
                  DATA(lv_prev_2p) = ( lv_di2 - 1 ) * lv_cols_2p + ( lv_ii2 - 1 ) + 1.
                  lt_dp_2p[ lv_cell_2p ] = lt_dp_2p[ lv_prev_2p ] + 1.
                ELSE.
                  DATA(lv_up_2p)   = ( lv_di2 - 1 ) * lv_cols_2p + lv_ii2 + 1.
                  DATA(lv_left_2p) = lv_di2 * lv_cols_2p + ( lv_ii2 - 1 ) + 1.
                  lt_dp_2p[ lv_cell_2p ] = COND i(
                    WHEN lt_dp_2p[ lv_up_2p ] >= lt_dp_2p[ lv_left_2p ] THEN lt_dp_2p[ lv_up_2p ]
                    ELSE lt_dp_2p[ lv_left_2p ] ).
                ENDIF.
                lv_ii2 += 1.
              ENDWHILE.
              lv_di2 += 1.
            ENDWHILE.

            lv_di2 = lv_nd2.
            lv_ii2 = lv_ni2.
            WHILE lv_di2 > 0 AND lv_ii2 > 0.
              IF zcl_ave_popup_diff=>has_common_chars( iv_a = lt_d2[ lv_di2 ] iv_b = lt_i2[ lv_ii2 ] ) = abap_true.
                INSERT lv_di2 INTO lt_d2_pair_idx INDEX 1.
                INSERT lv_ii2 INTO lt_i2_pair_idx INDEX 1.
                lv_di2 -= 1.
                lv_ii2 -= 1.
              ELSE.
                DATA(lv_up_bt2)   = ( lv_di2 - 1 ) * lv_cols_2p + lv_ii2 + 1.
                DATA(lv_left_bt2) = lv_di2 * lv_cols_2p + ( lv_ii2 - 1 ) + 1.
                IF lt_dp_2p[ lv_up_bt2 ] >= lt_dp_2p[ lv_left_bt2 ].
                  lv_di2 -= 1.
                ELSE.
                  lv_ii2 -= 1.
                ENDIF.
              ENDIF.
            ENDWHILE.
          ENDIF.

          DATA lv_dl2 TYPE string.
          DATA lv_il2 TYPE string.

          " Walk lt_i2 (new/left) and lt_d2 (old/right) in document order.
          " Rendering paired first then solos breaks line-number ordering when a
          " solo insert precedes a paired row in the new file. Instead, advance
          " both pointers together, following pair anchors, and render solos as
          " they appear in each file's natural sequence.
          DATA lv_di TYPE i.
          DATA lv_ii TYPE i.
          DATA lv_pk TYPE i.
          lv_di = 1. lv_ii = 1. lv_pk = 1.
          DATA(lv_np) = lines( lt_d2_pair_idx ).
          WHILE lv_di <= lv_nd2 OR lv_ii <= lv_ni2.
            " Sentinel pair indices (beyond end when no more pairs)
            DATA(lv_npd) = COND i( WHEN lv_pk <= lv_np THEN lt_d2_pair_idx[ lv_pk ] ELSE lv_nd2 + 1 ).
            DATA(lv_npi) = COND i( WHEN lv_pk <= lv_np THEN lt_i2_pair_idx[ lv_pk ] ELSE lv_ni2 + 1 ).
            IF lv_di = lv_npd AND lv_ii = lv_npi.
              " Paired row: advance both counters
              lv_lno_l += 1. lv_lno_r += 1.
              IF i_plain = abap_true.
                lv_dl2 = escape( val = lt_i2[ lv_ii ] format = cl_abap_format=>e_html_text ).
                lv_il2 = escape( val = lt_d2[ lv_di ] format = cl_abap_format=>e_html_text ).
              ELSE.
                lv_dl2 = zcl_ave_popup_diff=>char_diff_html( iv_old = lt_d2[ lv_di ] iv_new = lt_i2[ lv_ii ] iv_side = 'N' iv_ignore_case = i_ignore_case ).
                lv_il2 = zcl_ave_popup_diff=>char_diff_html( iv_old = lt_d2[ lv_di ] iv_new = lt_i2[ lv_ii ] iv_side = 'O' iv_ignore_case = i_ignore_case ).
              ENDIF.
              DATA(lv_cmt_l2) = COND string( WHEN is_comment( lt_i2[ lv_ii ] ) = abap_true
                THEN `;background:#fafae8` ELSE `` ).
              DATA(lv_cmt_r2) = COND string( WHEN is_comment( lt_d2[ lv_di ] ) = abap_true
                THEN `;color:#cc0000` ELSE `` ).
              lv_rows = lv_rows &&
                |<tr>| &&
                |<td class="ln" style="background:#eaffea">{ lv_lno_l }</td>| &&
                |<td class="cd" style="background:#eaffea{ lv_cmt_l2 }">{ lv_dl2 }</td>| &&
                |<td class="sep"></td>| &&
                |<td class="ln" style="background:#ffecec">{ lv_lno_r }</td>| &&
                |<td class="cd" style="background:#ffecec{ lv_cmt_r2 }">{ lv_il2 }</td></tr>|.
              CLEAR: lv_dl2, lv_il2.
              lv_di += 1. lv_ii += 1. lv_pk += 1.
            ELSEIF lv_ii < lv_npi AND lv_di < lv_npd.
              " Positional pair: both sides available before next LCS anchor —
              " show side-by-side without char diff to keep document flow readable.
              lv_lno_l += 1. lv_lno_r += 1.
              lv_dl2 = lt_i2[ lv_ii ].
              lv_il2 = lt_d2[ lv_di ].
              REPLACE ALL OCCURRENCES OF `&` IN lv_dl2 WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_dl2 WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_dl2 WITH `&gt;`.
              REPLACE ALL OCCURRENCES OF `&` IN lv_il2 WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_il2 WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_il2 WITH `&gt;`.
              DATA(lv_cmt_ppl) = COND string( WHEN is_comment( lt_i2[ lv_ii ] ) = abap_true
                THEN `;background:#fafae8` ELSE `` ).
              DATA(lv_cmt_ppr) = COND string( WHEN is_comment( lt_d2[ lv_di ] ) = abap_true
                THEN `;color:#cc0000` ELSE `` ).
              lv_rows = lv_rows &&
                |<tr>| &&
                |<td class="ln" style="background:#eaffea">{ lv_lno_l }</td>| &&
                |<td class="cd" style="background:#eaffea{ lv_cmt_ppl }">{ lv_dl2 }</td>| &&
                |<td class="sep"></td>| &&
                |<td class="ln" style="background:#ffecec">{ lv_lno_r }</td>| &&
                |<td class="cd" style="background:#ffecec{ lv_cmt_ppr }">{ lv_il2 }</td></tr>|.
              CLEAR: lv_dl2, lv_il2.
              lv_ii += 1. lv_di += 1.
            ELSEIF lv_ii <= lv_ni2 AND lv_ii < lv_npi.
              " Solo insert (new line, left side only)
              lv_lno_l += 1.
              lv_dl2 = lt_i2[ lv_ii ].
              REPLACE ALL OCCURRENCES OF `&` IN lv_dl2 WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_dl2 WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_dl2 WITH `&gt;`.
              DATA(lv_cmt_si2) = COND string( WHEN is_comment( lt_i2[ lv_ii ] ) = abap_true
                THEN `;background:#fafae8` ELSE `` ).
              lv_rows = lv_rows &&
                |<tr>| &&
                |<td class="ln" style="background:#eaffea">{ lv_lno_l }</td>| &&
                |<td class="cd" style="background:#eaffea{ lv_cmt_si2 }">{ lv_dl2 }</td>| &&
                |<td class="sep"></td>| &&
                |<td class="ln"></td><td class="cd"></td></tr>|.
              CLEAR lv_dl2.
              lv_ii += 1.
            ELSEIF lv_di <= lv_nd2.
              " Solo delete (old line, right side only)
              lv_lno_r += 1.
              lv_il2 = lt_d2[ lv_di ].
              REPLACE ALL OCCURRENCES OF `&` IN lv_il2 WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_il2 WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_il2 WITH `&gt;`.
              DATA(lv_cmt_sd2) = COND string( WHEN is_comment( lt_d2[ lv_di ] ) = abap_true
                THEN `;color:#cc0000` ELSE `` ).
              lv_rows = lv_rows &&
                |<tr>| &&
                |<td class="ln"></td><td class="cd"></td>| &&
                |<td class="sep"></td>| &&
                |<td class="ln" style="background:#ffecec">{ lv_lno_r }</td>| &&
                |<td class="cd" style="background:#ffecec{ lv_cmt_sd2 }">{ lv_il2 }</td></tr>|.
              CLEAR lv_il2.
              lv_di += 1.
            ELSE.
              " Remaining solo inserts (all dels exhausted)
              lv_lno_l += 1.
              lv_dl2 = lt_i2[ lv_ii ].
              REPLACE ALL OCCURRENCES OF `&` IN lv_dl2 WITH `&amp;`.
              REPLACE ALL OCCURRENCES OF `<` IN lv_dl2 WITH `&lt;`.
              REPLACE ALL OCCURRENCES OF `>` IN lv_dl2 WITH `&gt;`.
              DATA(lv_cmt_rs2) = COND string( WHEN is_comment( lt_i2[ lv_ii ] ) = abap_true
                THEN `;background:#fafae8` ELSE `` ).
              lv_rows = lv_rows &&
                |<tr>| &&
                |<td class="ln" style="background:#eaffea">{ lv_lno_l }</td>| &&
                |<td class="cd" style="background:#eaffea{ lv_cmt_rs2 }">{ lv_dl2 }</td>| &&
                |<td class="sep"></td>| &&
                |<td class="ln"></td><td class="cd"></td></tr>|.
              CLEAR lv_dl2.
              lv_ii += 1.
            ENDIF.
          ENDWHILE.

          CLEAR: lt_d2, lt_i2, lv_gap2, lt_d2_pair_idx, lt_i2_pair_idx, lt_d2_paired, lt_i2_paired.
          lv_pos2 = lv_sc.
        ELSE.
          lv_pos2 += 1.
        ENDIF.
      ENDWHILE.

      result =
        |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
        |*\{margin:0;padding:0;box-sizing:border-box\}| &&
        |body\{background:#fff;color:#1e1e1e;font:12px/1.5 Consolas,monospace\}| &&
        |.hdr\{background:#f3f3f3;padding:5px 56px;border-bottom:1px solid #ddd;| &&
               |color:#444;font-size:11px;display:flex;gap:8px;| &&
               |justify-content:center;align-items:center;flex-wrap:wrap\}| &&
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
        gv_render_line = lv_lno.
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
        DATA(lv_cmt_eq) = COND string( WHEN is_comment( ls_cur-text ) = abap_true
          THEN ` style="background:#fafae8"` ELSE `` ).
        lv_rows = lv_rows &&
          |<tr style="background:#ffffff">| &&
          |<td class="ln">{ lv_lno }</td>| &&
          |<td class="cd"{ lv_cmt_eq }>{ lv_line_eq }</td></tr>|.
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
        ELSEIF i_code_review = abap_true AND lt_ins IS NOT INITIAL.
          lv_rows = lv_rows &&
            `<tr style="background:#e8f4e8;color:#555;font-size:10px;font-style:italic">` &&
            `<td class="ln">▶</td>` &&
            `<td class="cd">── changed ──</td></tr>`.
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
            DATA(lv_bdtasktxt) = COND string(
              WHEN ls_bld-task_text IS NOT INITIAL THEN | { ls_bld-task_text }|
              ELSE `` ).
            lv_rows = lv_rows &&
              |<tr style="background:#fdf0f0;color:#555;font-size:10px;font-style:italic;font-weight:bold">| &&
              |<td class="ln">◀</td>| &&
              |<td class="cd">── { ls_bld-author }| &&
              COND string( WHEN ls_bld-author_name IS NOT INITIAL THEN | ({ ls_bld-author_name })| ELSE `` ) &&
              | deleted  { lv_bddate } { lv_bdtime }  v.{ ls_bld-versno_text }| &&
              |{ lv_bdtask }{ lv_bdtasktxt } ──</td></tr>|.
          ENDIF.
        ELSEIF i_code_review = abap_true AND lt_dels IS NOT INITIAL AND lt_ins IS INITIAL.
          lv_rows = lv_rows &&
            `<tr style="background:#fdf0f0;color:#555;font-size:10px;font-style:italic;font-weight:bold">` &&
            `<td class="ln">◀</td>` &&
            `<td class="cd">── changed ──</td></tr>`.
        ENDIF.

        DATA(lv_ndels) = lines( lt_dels ).
        DATA(lv_nins)  = lines( lt_ins ).

        " status[i] for each block position: 'P' = render paired here,
        "                                    'C' = consumed (skip), ' ' = solo/equal
        DATA lt_status      TYPE STANDARD TABLE OF c WITH DEFAULT KEY.
        DATA lt_inline_html TYPE string_table.
        CLEAR: lt_status, lt_inline_html.
        DATA lv_init TYPE i.
        lv_init = 1.
        WHILE lv_init <= lines( lt_block ).
          APPEND ` ` TO lt_status.
          APPEND `` TO lt_inline_html.
          lv_init += 1.
        ENDWHILE.

        IF i_plain = abap_false AND lv_ndels > 0 AND lv_nins > 0.
          DATA(lv_cols_p) = lv_nins + 1.
          DATA(lv_rows_p) = lv_ndels + 1.
          DATA lt_dp_pair TYPE TABLE OF i.
          CLEAR lt_dp_pair.
          DATA(lv_size_p) = lv_rows_p * lv_cols_p.
          DO lv_size_p TIMES.
            APPEND 0 TO lt_dp_pair.
          ENDDO.

          DATA lv_di1 TYPE i.
          DATA lv_ii1 TYPE i.
          lv_di1 = 1.
          WHILE lv_di1 <= lv_ndels.
            lv_ii1 = 1.
            WHILE lv_ii1 <= lv_nins.
              DATA(lv_cell_p) = lv_di1 * lv_cols_p + lv_ii1 + 1.
              IF zcl_ave_popup_diff=>has_common_chars( iv_a = lt_dels[ lv_di1 ] iv_b = lt_ins[ lv_ii1 ] ) = abap_true.
                DATA(lv_prev_p) = ( lv_di1 - 1 ) * lv_cols_p + ( lv_ii1 - 1 ) + 1.
                lt_dp_pair[ lv_cell_p ] = lt_dp_pair[ lv_prev_p ] + 1.
              ELSE.
                DATA(lv_up_p)   = ( lv_di1 - 1 ) * lv_cols_p + lv_ii1 + 1.
                DATA(lv_left_p) = lv_di1 * lv_cols_p + ( lv_ii1 - 1 ) + 1.
                lt_dp_pair[ lv_cell_p ] = COND i(
                  WHEN lt_dp_pair[ lv_up_p ] >= lt_dp_pair[ lv_left_p ] THEN lt_dp_pair[ lv_up_p ]
                  ELSE lt_dp_pair[ lv_left_p ] ).
              ENDIF.
              lv_ii1 += 1.
            ENDWHILE.
            lv_di1 += 1.
          ENDWHILE.

          DATA lt_pair_dk TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
          DATA lt_pair_ik TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
          CLEAR: lt_pair_dk, lt_pair_ik.
          lv_di1 = lv_ndels.
          lv_ii1 = lv_nins.
          WHILE lv_di1 > 0 AND lv_ii1 > 0.
            IF zcl_ave_popup_diff=>has_common_chars( iv_a = lt_dels[ lv_di1 ] iv_b = lt_ins[ lv_ii1 ] ) = abap_true.
              " Before taking this pair, check if skipping this ins (going left)
              " gives the same DP score — if so, prefer the earlier insertion.
              " This prevents pairing del[i] with ins[j] when ins[j-1] matches
              " equally well (e.g. 1 del + 2 ins where both have common chars).
              IF lv_ii1 > 1 AND
                 lt_dp_pair[ lv_di1 * lv_cols_p + ( lv_ii1 - 1 ) + 1 ] =
                 lt_dp_pair[ lv_di1 * lv_cols_p + lv_ii1 + 1 ].
                lv_ii1 -= 1.  " skip to earlier ins — same score reachable without this ins
              ELSE.
                INSERT lv_di1 INTO lt_pair_dk INDEX 1.
                INSERT lv_ii1 INTO lt_pair_ik INDEX 1.
                lv_di1 -= 1.
                lv_ii1 -= 1.
              ENDIF.
            ELSE.
              DATA(lv_up_bt)   = ( lv_di1 - 1 ) * lv_cols_p + lv_ii1 + 1.
              DATA(lv_left_bt) = lv_di1 * lv_cols_p + ( lv_ii1 - 1 ) + 1.
              IF lt_dp_pair[ lv_up_bt ] >= lt_dp_pair[ lv_left_bt ].
                lv_di1 -= 1.
              ELSE.
                lv_ii1 -= 1.
              ENDIF.
            ENDIF.
          ENDWHILE.

          lv_pk = 1.
          WHILE lv_pk <= lines( lt_pair_dk ).
            DATA(lv_dk) = lt_pair_dk[ lv_pk ].
            DATA(lv_ik) = lt_pair_ik[ lv_pk ].
            lv_di    = lt_del_idx[ lv_dk ].
            lv_ii    = lt_ins_idx[ lv_ik ].
            DATA(lv_first) = COND i( WHEN lv_di < lv_ii THEN lv_di ELSE lv_ii ).
            DATA(lv_other) = COND i( WHEN lv_di > lv_ii THEN lv_di ELSE lv_ii ).
            lt_status[ lv_first ] = 'P'.
            lt_status[ lv_other ] = 'C'.
            lt_inline_html[ lv_first ] = zcl_ave_popup_diff=>char_diff_html(
              iv_old         = lt_dels[ lv_dk ]
              iv_new         = lt_ins[ lv_ik ]
              iv_side        = 'B'
              iv_ignore_case = i_ignore_case ).
            lv_pk += 1.
          ENDWHILE.
        ENDIF.
        " Render block ops in original order
        DATA lv_rb TYPE i.
        lv_rb = 1.
        WHILE lv_rb <= lines( lt_block ).
          DATA(ls_bo) = lt_block[ lv_rb ].
          DATA(lv_st) = lt_status[ lv_rb ].
          DATA(lv_cmt_b) = COND string( WHEN is_comment( ls_bo-text ) = abap_true
            THEN `;background:#fafae8` ELSE `` ).
          IF ls_bo-op = '='.
            lv_lno += 1.
            DATA(lv_eq) = ls_bo-text.
            REPLACE ALL OCCURRENCES OF `&` IN lv_eq WITH `&amp;`.
            REPLACE ALL OCCURRENCES OF `<` IN lv_eq WITH `&lt;`.
            REPLACE ALL OCCURRENCES OF `>` IN lv_eq WITH `&gt;`.
            lv_rows = lv_rows &&
              |<tr style="background:#ffffff">| &&
              |<td class="ln">{ lv_lno }</td>| &&
              |<td class="cd" style="background:#ffffff{ lv_cmt_b }">{ lv_eq }</td></tr>|.
          ELSEIF ls_bo-op = '-'.
            IF lv_st = 'P'.
              lv_lno += 1.
              lv_rows = lv_rows &&
                |<tr style="background:#ffffff">| &&
                |<td class="ln">{ lv_lno }</td>| &&
                |<td class="cd" style="background:#ffffff{ lv_cmt_b }">{ lt_inline_html[ lv_rb ] }</td></tr>|.
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
                |<td class="cd" style="color:#cc0000{ lv_cmt_b }">{ lv_dl }</td></tr>|.
            ENDIF.
          ELSE.  " '+'
            IF lv_st = 'P'.
              lv_lno += 1.
              lv_rows = lv_rows &&
                |<tr style="background:#ffffff">| &&
                |<td class="ln">{ lv_lno }</td>| &&
                |<td class="cd" style="background:#ffffff{ lv_cmt_b }">{ lt_inline_html[ lv_rb ] }</td></tr>|.
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
                |<td class="cd" style="color:#006600{ lv_cmt_b }">{ lv_il }</td></tr>|.
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
      |.hdr\{background:#f3f3f3;padding:5px 56px;border-bottom:1px solid #ddd;| &&
             |color:#444;font-size:11px;display:flex;gap:8px;| &&
             |justify-content:center;align-items:center;flex-wrap:wrap\}| &&
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
      DATA(lv_block_end) = lv_scan - 1.

      DATA lt_pair_dk TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
      DATA lt_pair_ik TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
      DATA lt_d_paired TYPE TABLE OF abap_bool WITH DEFAULT KEY.
      DATA lt_i_paired TYPE TABLE OF abap_bool WITH DEFAULT KEY.
      DATA lt_dp_dbg   TYPE TABLE OF i.
      " Must clear all block-local tables — DATA declarations are method-scoped
      " so they accumulate across iterations of this WHILE loop.
      CLEAR: lt_pair_dk, lt_pair_ik, lt_d_paired, lt_i_paired, lt_dp_dbg.
      DO lv_nd TIMES. APPEND abap_false TO lt_d_paired. ENDDO.
      DO lv_ni TIMES. APPEND abap_false TO lt_i_paired. ENDDO.

      IF lv_nd > 0 AND lv_ni > 0.
        DATA(lv_cols_dbg) = lv_ni + 1.
        DATA(lv_rows_dbg) = lv_nd + 1.
        DATA(lv_size_dbg) = lv_rows_dbg * lv_cols_dbg.
        DO lv_size_dbg TIMES.
          APPEND 0 TO lt_dp_dbg.
        ENDDO.

        DATA lv_di_dbg TYPE i.
        DATA lv_ii_dbg TYPE i.
        lv_di_dbg = 1.
        WHILE lv_di_dbg <= lv_nd.
          lv_ii_dbg = 1.
          WHILE lv_ii_dbg <= lv_ni.
            DATA(lv_cell_dbg) = lv_di_dbg * lv_cols_dbg + lv_ii_dbg + 1.
            DATA(lv_hcc_dbg) = zcl_ave_popup_diff=>has_common_chars(
              iv_a = lt_dels[ lv_di_dbg ]
              iv_b = lt_ins[ lv_ii_dbg ] ).
            IF lv_hcc_dbg = abap_true.
              DATA(lv_prev_dbg) = ( lv_di_dbg - 1 ) * lv_cols_dbg + ( lv_ii_dbg - 1 ) + 1.
              lt_dp_dbg[ lv_cell_dbg ] = lt_dp_dbg[ lv_prev_dbg ] + 1.
            ELSE.
              DATA(lv_up_dbg)   = ( lv_di_dbg - 1 ) * lv_cols_dbg + lv_ii_dbg + 1.
              DATA(lv_left_dbg) = lv_di_dbg * lv_cols_dbg + ( lv_ii_dbg - 1 ) + 1.
              lt_dp_dbg[ lv_cell_dbg ] = COND i(
                WHEN lt_dp_dbg[ lv_up_dbg ] >= lt_dp_dbg[ lv_left_dbg ] THEN lt_dp_dbg[ lv_up_dbg ]
                ELSE lt_dp_dbg[ lv_left_dbg ] ).
            ENDIF.
            lv_ii_dbg += 1.
          ENDWHILE.
          lv_di_dbg += 1.
        ENDWHILE.

        lv_di_dbg = lv_nd.
        lv_ii_dbg = lv_ni.
        WHILE lv_di_dbg > 0 AND lv_ii_dbg > 0.
          IF zcl_ave_popup_diff=>has_common_chars( iv_a = lt_dels[ lv_di_dbg ] iv_b = lt_ins[ lv_ii_dbg ] ) = abap_true.
            INSERT lv_di_dbg INTO lt_pair_dk INDEX 1.
            INSERT lv_ii_dbg INTO lt_pair_ik INDEX 1.
            lv_di_dbg -= 1.
            lv_ii_dbg -= 1.
          ELSE.
            DATA(lv_up_bt_dbg)   = ( lv_di_dbg - 1 ) * lv_cols_dbg + lv_ii_dbg + 1.
            DATA(lv_left_bt_dbg) = lv_di_dbg * lv_cols_dbg + ( lv_ii_dbg - 1 ) + 1.
            IF lt_dp_dbg[ lv_up_bt_dbg ] >= lt_dp_dbg[ lv_left_bt_dbg ].
              lv_di_dbg -= 1.
            ELSE.
              lv_ii_dbg -= 1.
            ENDIF.
          ENDIF.
        ENDWHILE.
      ENDIF.

      DATA lv_pair_rows TYPE string.
      CLEAR lv_pair_rows.
      DATA lv_k TYPE i.
      lv_k = 1.
      WHILE lv_k <= lines( lt_pair_dk ).
        DATA(lv_dk) = lt_pair_dk[ lv_k ].
        DATA(lv_ik) = lt_pair_ik[ lv_k ].
        lt_d_paired[ lv_dk ] = abap_true.
        lt_i_paired[ lv_ik ] = abap_true.

        DATA(lv_a) = lt_dels[ lv_dk ].
        DATA(lv_b) = lt_ins[ lv_ik ].

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
        DATA(lv_inline) = zcl_ave_popup_diff=>char_diff_html( iv_old = lv_a iv_new = lv_b iv_side = 'B' ).

        " ── pairing metrics ──────────────────────────────────────────────────
        DATA lv_ta_m TYPE string.
        DATA lv_tb_m TYPE string.
        lv_ta_m = lv_a. lv_tb_m = lv_b.
        WHILE strlen( lv_ta_m ) > 0 AND substring( val = lv_ta_m off = 0 len = 1 ) = ` `.
          lv_ta_m = substring( val = lv_ta_m off = 1 len = strlen( lv_ta_m ) - 1 ).
        ENDWHILE.
        WHILE strlen( lv_ta_m ) > 0 AND substring( val = lv_ta_m off = strlen( lv_ta_m ) - 1 len = 1 ) = ` `.
          lv_ta_m = substring( val = lv_ta_m off = 0 len = strlen( lv_ta_m ) - 1 ).
        ENDWHILE.
        WHILE strlen( lv_tb_m ) > 0 AND substring( val = lv_tb_m off = 0 len = 1 ) = ` `.
          lv_tb_m = substring( val = lv_tb_m off = 1 len = strlen( lv_tb_m ) - 1 ).
        ENDWHILE.
        WHILE strlen( lv_tb_m ) > 0 AND substring( val = lv_tb_m off = strlen( lv_tb_m ) - 1 len = 1 ) = ` `.
          lv_tb_m = substring( val = lv_tb_m off = 0 len = strlen( lv_tb_m ) - 1 ).
        ENDWHILE.
        DATA(lv_la_m) = strlen( lv_ta_m ).
        DATA(lv_lb_m) = strlen( lv_tb_m ).
        DATA lv_cp_m TYPE i VALUE 0.
        WHILE lv_cp_m < lv_la_m AND lv_cp_m < lv_lb_m.
          IF substring( val = lv_ta_m off = lv_cp_m len = 1 ) = substring( val = lv_tb_m off = lv_cp_m len = 1 ).
            lv_cp_m += 1.
          ELSE. EXIT.
          ENDIF.
        ENDWHILE.
        DATA lv_cs_m TYPE i VALUE 0.
        DATA(lv_la_rest_m) = lv_la_m - lv_cp_m.
        DATA(lv_lb_rest_m) = lv_lb_m - lv_cp_m.
        WHILE lv_cs_m < lv_la_rest_m AND lv_cs_m < lv_lb_rest_m.
          IF substring( val = lv_ta_m off = lv_la_m - 1 - lv_cs_m len = 1 ) =
             substring( val = lv_tb_m off = lv_lb_m - 1 - lv_cs_m len = 1 ).
            lv_cs_m += 1.
          ELSE. EXIT.
          ENDIF.
        ENDWHILE.
        DATA lv_mid_am TYPE string.
        DATA lv_mid_bm TYPE string.
        DATA(lv_mid_la_m) = lv_la_m - lv_cp_m - lv_cs_m.
        DATA(lv_mid_lb_m) = lv_lb_m - lv_cp_m - lv_cs_m.
        IF lv_mid_la_m > 0. lv_mid_am = substring( val = lv_ta_m off = lv_cp_m len = lv_mid_la_m ). ENDIF.
        IF lv_mid_lb_m > 0. lv_mid_bm = substring( val = lv_tb_m off = lv_cp_m len = lv_mid_lb_m ). ENDIF.
        DATA(lv_runs_m)  = zcl_ave_popup_diff=>count_edit_runs( iv_a = lv_mid_am iv_b = lv_mid_bm ).
        DATA(lv_min_m)   = nmin( val1 = lv_la_m val2 = lv_lb_m ).
        DATA(lv_ratio_m) = COND i( WHEN lv_min_m > 0 THEN lv_cp_m * 100 / lv_min_m ELSE 0 ).

        " Build annotated lines: prefix in blue, middle normal, suffix in green
        DATA lv_pfx_e TYPE string.
        DATA lv_sfx_e TYPE string.
        DATA lv_amid_e TYPE string.
        DATA lv_bmid_e TYPE string.
        IF lv_cp_m > 0. lv_pfx_e = substring( val = lv_ta_m off = 0 len = lv_cp_m ).
          REPLACE ALL OCCURRENCES OF `&` IN lv_pfx_e WITH `&amp;`.
          REPLACE ALL OCCURRENCES OF `<` IN lv_pfx_e WITH `&lt;`.
          REPLACE ALL OCCURRENCES OF `>` IN lv_pfx_e WITH `&gt;`.
        ENDIF.
        IF lv_cs_m > 0. lv_sfx_e = substring( val = lv_ta_m off = lv_la_m - lv_cs_m len = lv_cs_m ).
          REPLACE ALL OCCURRENCES OF `&` IN lv_sfx_e WITH `&amp;`.
          REPLACE ALL OCCURRENCES OF `<` IN lv_sfx_e WITH `&lt;`.
          REPLACE ALL OCCURRENCES OF `>` IN lv_sfx_e WITH `&gt;`.
        ENDIF.
        lv_amid_e = lv_mid_am. lv_bmid_e = lv_mid_bm.
        REPLACE ALL OCCURRENCES OF `&` IN lv_amid_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_amid_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_amid_e WITH `&gt;`.
        REPLACE ALL OCCURRENCES OF `&` IN lv_bmid_e WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_bmid_e WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_bmid_e WITH `&gt;`.
        DATA(lv_ann_a) = |<span style="color:#0055cc">{ lv_pfx_e }</span>{ lv_amid_e }<span style="color:#006600">{ lv_sfx_e }</span>|.
        DATA(lv_ann_b) = |<span style="color:#0055cc">{ lv_pfx_e }</span>{ lv_bmid_e }<span style="color:#006600">{ lv_sfx_e }</span>|.
        DATA(lv_metrics) = |cp={ lv_cp_m } cs={ lv_cs_m } ratio={ lv_ratio_m }% runs={ lv_runs_m }|.

        lv_pair_rows = lv_pair_rows &&
          |<tr><td class="ln">{ lv_dk }/{ lv_ik }</td>| &&
          |<td class="cd"><span class="del-tag">-</span> <code>{ lv_ann_a }</code></td>| &&
          |<td class="cd"><span class="ins-tag">+</span> <code>{ lv_ann_b }</code></td>| &&
          |<td><span class="ok">PAIR</span><br><small style="color:#888">{ lv_metrics }</small></td>| &&
          |<td class="cd">{ lv_inline }</td></tr>|.
        lv_k += 1.
      ENDWHILE.

      DATA lv_leftover TYPE string.
      CLEAR lv_leftover.
      lv_k = 1.
      WHILE lv_k <= lv_nd.
        IF lt_d_paired[ lv_k ] = abap_false.
          DATA(lv_d_e) = lt_dels[ lv_k ].
          REPLACE ALL OCCURRENCES OF `&` IN lv_d_e WITH `&amp;`.
          REPLACE ALL OCCURRENCES OF `<` IN lv_d_e WITH `&lt;`.
          REPLACE ALL OCCURRENCES OF `>` IN lv_d_e WITH `&gt;`.
          DATA(lv_d_show) = COND string( WHEN lv_d_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_d_e ).
          lv_leftover = lv_leftover && |<div class="solo del">SOLO - <code>{ lv_d_show }</code></div>|.
        ENDIF.
        lv_k += 1.
      ENDWHILE.
      lv_k = 1.
      WHILE lv_k <= lv_ni.
        IF lt_i_paired[ lv_k ] = abap_false.
          DATA(lv_i_e) = lt_ins[ lv_k ].
          REPLACE ALL OCCURRENCES OF `&` IN lv_i_e WITH `&amp;`.
          REPLACE ALL OCCURRENCES OF `<` IN lv_i_e WITH `&lt;`.
          REPLACE ALL OCCURRENCES OF `>` IN lv_i_e WITH `&gt;`.
          DATA(lv_i_show) = COND string( WHEN lv_i_e IS INITIAL THEN `<em>&lt;empty&gt;</em>` ELSE lv_i_e ).
          lv_leftover = lv_leftover && |<div class="solo ins">SOLO + <code>{ lv_i_show }</code></div>|.
        ENDIF.
        lv_k += 1.
      ENDWHILE.

      DATA(lv_pair_section) = COND string(
        WHEN lv_pair_rows IS NOT INITIAL THEN
          |<table class="pair"><thead><tr><th>-/+</th><th>del</th><th>ins</th>| &&
          |<th>verdict</th><th>char-diff (if paired)</th></tr></thead>| &&
          |<tbody>| && lv_pair_rows && |</tbody></table>|
        ELSE `<div class="meta">(no del/ins pairs to test)</div>` ).
      DATA(lv_leftover_section) = COND string(
        WHEN lv_leftover IS NOT INITIAL THEN |<div class="leftover">{ lv_leftover }</div>|
        ELSE `` ).

      " ── All-combinations matrix (≤8 dels AND ≤8 ins to keep output manageable)
      DATA lv_matrix_section TYPE string.
      CLEAR lv_matrix_section.
      IF lv_nd > 0 AND lv_ni > 0 AND lv_nd <= 8 AND lv_ni <= 8.
        DATA lv_mx_rows TYPE string.
        CLEAR lv_mx_rows.
        DATA lv_di_mx TYPE i.
        DATA lv_ii_mx TYPE i.
        lv_di_mx = 1.
        WHILE lv_di_mx <= lv_nd.
          lv_ii_mx = 1.
          WHILE lv_ii_mx <= lv_ni.
            DATA(lv_sa) = lt_dels[ lv_di_mx ].
            DATA(lv_sb) = lt_ins[ lv_ii_mx ].
            DATA(lv_hcc) = zcl_ave_popup_diff=>has_common_chars( iv_a = lv_sa iv_b = lv_sb ).
            " Trim for metrics
            DATA lv_ma TYPE string.
            DATA lv_mb TYPE string.
            lv_ma = lv_sa. lv_mb = lv_sb.
            WHILE strlen( lv_ma ) > 0 AND substring( val = lv_ma off = 0 len = 1 ) = ` `.
              lv_ma = substring( val = lv_ma off = 1 len = strlen( lv_ma ) - 1 ). ENDWHILE.
            WHILE strlen( lv_ma ) > 0 AND substring( val = lv_ma off = strlen( lv_ma ) - 1 len = 1 ) = ` `.
              lv_ma = substring( val = lv_ma off = 0 len = strlen( lv_ma ) - 1 ). ENDWHILE.
            WHILE strlen( lv_mb ) > 0 AND substring( val = lv_mb off = 0 len = 1 ) = ` `.
              lv_mb = substring( val = lv_mb off = 1 len = strlen( lv_mb ) - 1 ). ENDWHILE.
            WHILE strlen( lv_mb ) > 0 AND substring( val = lv_mb off = strlen( lv_mb ) - 1 len = 1 ) = ` `.
              lv_mb = substring( val = lv_mb off = 0 len = strlen( lv_mb ) - 1 ). ENDWHILE.
            DATA(lv_la_mx) = strlen( lv_ma ).
            DATA(lv_lb_mx) = strlen( lv_mb ).
            DATA lv_cp_mx TYPE i VALUE 0.
            WHILE lv_cp_mx < lv_la_mx AND lv_cp_mx < lv_lb_mx.
              IF substring( val = lv_ma off = lv_cp_mx len = 1 ) = substring( val = lv_mb off = lv_cp_mx len = 1 ).
                lv_cp_mx += 1.
              ELSE. EXIT.
              ENDIF.
            ENDWHILE.
            DATA lv_cs_mx TYPE i VALUE 0.
            DATA(lv_la_rx) = lv_la_mx - lv_cp_mx.
            DATA(lv_lb_rx) = lv_lb_mx - lv_cp_mx.
            WHILE lv_cs_mx < lv_la_rx AND lv_cs_mx < lv_lb_rx.
              IF substring( val = lv_ma off = lv_la_mx - 1 - lv_cs_mx len = 1 ) =
                 substring( val = lv_mb off = lv_lb_mx - 1 - lv_cs_mx len = 1 ).
                lv_cs_mx += 1.
              ELSE. EXIT.
              ENDIF.
            ENDWHILE.
            DATA lv_mid_amx TYPE string.
            DATA lv_mid_bmx TYPE string.
            DATA(lv_mla_mx) = lv_la_mx - lv_cp_mx - lv_cs_mx.
            DATA(lv_mlb_mx) = lv_lb_mx - lv_cp_mx - lv_cs_mx.
            IF lv_mla_mx > 0. lv_mid_amx = substring( val = lv_ma off = lv_cp_mx len = lv_mla_mx ). ENDIF.
            IF lv_mlb_mx > 0. lv_mid_bmx = substring( val = lv_mb off = lv_cp_mx len = lv_mlb_mx ). ENDIF.
            DATA(lv_runs_mx)  = zcl_ave_popup_diff=>count_edit_runs( iv_a = lv_mid_amx iv_b = lv_mid_bmx ).
            DATA(lv_min_mx)   = nmin( val1 = lv_la_mx val2 = lv_lb_mx ).
            DATA(lv_ratio_mx) = COND i( WHEN lv_min_mx > 0 THEN lv_cp_mx * 100 / lv_min_mx ELSE 0 ).
            DATA(lv_verdict)  = COND string( WHEN lv_hcc = abap_true
              THEN `<span style="color:#006600;font-weight:bold">PAIR</span>`
              ELSE `<span style="color:#cc0000">SKIP</span>` ).
            DATA(lv_row_bg) = COND string( WHEN lv_hcc = abap_true THEN `#eaffea` ELSE `#fff8f8` ).
            lv_mx_rows = lv_mx_rows &&
              |<tr style="background:{ lv_row_bg }">| &&
              |<td class="ln">{ lv_di_mx }/{ lv_ii_mx }</td>| &&
              |<td>{ lv_verdict }</td>| &&
              |<td>cp={ lv_cp_mx }&nbsp;cs={ lv_cs_mx }&nbsp;ratio={ lv_ratio_mx }%&nbsp;runs={ lv_runs_mx }</td>| &&
              |</tr>|.
            lv_ii_mx += 1.
          ENDWHILE.
          lv_di_mx += 1.
        ENDWHILE.
        lv_matrix_section =
          |<details style="margin-top:4px"><summary style="cursor:pointer;color:#555;font-size:11px">| &&
          |All { lv_nd }×{ lv_ni } combinations</summary>| &&
          |<table style="width:auto;margin-top:4px"><thead><tr>| &&
          |<th>d/i</th><th>verdict</th><th>metrics</th></tr></thead>| &&
          |<tbody>{ lv_mx_rows }</tbody></table></details>|.
      ENDIF.

      DATA(lv_bridge_note) = COND string(
        WHEN lv_bridged > 0 THEN | <span class="meta">— bridged { lv_bridged } empty '=' line(s)</span>|
        ELSE `` ).
      lv_blocks = lv_blocks &&
        |<div class="block"><h3>Block #{ lv_block_no } | &&
        |<span class="meta">({ lv_nd } dels, { lv_ni } ins, ops [{ lv_pos }..{ lv_block_end }])</span>| &&
        lv_bridge_note && |</h3>| &&
        lv_pair_section && lv_leftover_section && lv_matrix_section && |</div>|.

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
  METHOD cds_source_to_html.
    " Helper: apply span tags by match positions (avoids regex backreference issues).
    " Processes matches from left to right and wraps each with <span class=css_class>.
    DATA: lv_rows TYPE string,
          lv_lno  TYPE i.

    DATA(lv_kw_regex) =
      '\b(define|view|entity|root|as|select|from|key|association|' &&
      'to|one|many|redirected|composition|join|left|outer|inner|cross|on|' &&
      'where|group|by|having|union|all|intersect|except|distinct|order|' &&
      'asc|desc|case|when|then|else|end|and|or|not|null|is|with|' &&
      'parameters|cast|coalesce|concat|upper|lower|substring|length|trim|' &&
      'projection|extend|abstract|transactional|query|interface|' &&
      'draft|enabled|annotate|aspect|type|of|in|between|like|exists|' &&
      'count|sum|avg|min|max|currency|unit|localized|literal|parent|' &&
      'provider|contract|strict|authorization|check)\b'.

    LOOP AT it_source INTO DATA(ls_src).
      lv_lno += 1.
      DATA(lv_line) = CONV string( ls_src ).

      REPLACE ALL OCCURRENCES OF `&` IN lv_line WITH `&amp;`.
      REPLACE ALL OCCURRENCES OF `<` IN lv_line WITH `&lt;`.
      REPLACE ALL OCCURRENCES OF `>` IN lv_line WITH `&gt;`.

      DATA(lv_trimmed) = condense( val = lv_line ).
      DATA(lv_tlen)    = strlen( lv_trimmed ).

      DATA lv_cell TYPE string.

      IF lv_tlen >= 2 AND lv_trimmed(2) = '//'.
        lv_cell = |<span class="cmt">{ lv_line }</span>|.
      ELSEIF lv_tlen >= 2 AND lv_trimmed(2) = '/*'.
        lv_cell = |<span class="cmt">{ lv_line }</span>|.
      ELSE.
        lv_cell = lv_line.

        " Highlight @Annotation names using position-based approach.
        DATA lt_ann TYPE match_result_tab.
        FIND ALL OCCURRENCES OF REGEX '@[\w.]+'
          IN lv_cell RESULTS lt_ann IGNORING CASE.
        IF lt_ann IS NOT INITIAL.
          DATA: lv_ann_out TYPE string,
                lv_ann_pos TYPE i.
          DATA: lv_ann_before TYPE i,
                lv_ann_len    TYPE i,
                lv_ann_off    TYPE i.
          LOOP AT lt_ann INTO DATA(ls_ann).
            lv_ann_off    = ls_ann-offset.
            lv_ann_before = lv_ann_off - lv_ann_pos.
            lv_ann_len    = ls_ann-length.
            lv_ann_out = lv_ann_out &&
              lv_cell+lv_ann_pos(lv_ann_before) &&
              |<span class="ann">{ lv_cell+lv_ann_off(lv_ann_len) }</span>|.
            lv_ann_pos = lv_ann_off + lv_ann_len.
          ENDLOOP.
          lv_cell = lv_ann_out && lv_cell+lv_ann_pos.
        ENDIF.

        " Highlight CDS keywords using position-based approach.
        DATA lt_kw TYPE match_result_tab.
        FIND ALL OCCURRENCES OF REGEX lv_kw_regex
          IN lv_cell RESULTS lt_kw IGNORING CASE.
        IF lt_kw IS NOT INITIAL.
          DATA: lv_kw_out TYPE string,
                lv_kw_pos TYPE i.
          DATA: lv_kw_before TYPE i,
                lv_kw_len    TYPE i,
                lv_kw_off    TYPE i.
          LOOP AT lt_kw INTO DATA(ls_kw).
            lv_kw_off    = ls_kw-offset.
            lv_kw_before = lv_kw_off - lv_kw_pos.
            lv_kw_len    = ls_kw-length.
            lv_kw_out = lv_kw_out &&
              lv_cell+lv_kw_pos(lv_kw_before) &&
              |<span class="kw">{ lv_cell+lv_kw_off(lv_kw_len) }</span>|.
            lv_kw_pos = lv_kw_off + lv_kw_len.
          ENDLOOP.
          lv_cell = lv_kw_out && lv_cell+lv_kw_pos.
        ENDIF.
      ENDIF.

      lv_rows = lv_rows &&
        |<tr><td class="ln">{ lv_lno }</td>| &&
        |<td class="cd">{ lv_cell }</td></tr>|.
    ENDLOOP.

    rv_html =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>| &&
      |*\{margin:0;padding:0;box-sizing:border-box\}| &&
      |body\{background:#fff;color:#1e1e1e;font:12px/1.5 Consolas,monospace\}| &&
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
      |.kw\{color:#0070c1;font-weight:bold\}| &&
      |.ann\{color:#267f99\}| &&
      |.cmt\{color:#008000\}| &&
      |</style></head><body>| &&
      |<div class="hdr">| &&
      |<span class="ttl">| && i_title && |</span>| &&
      |<span class="meta">| && i_meta  && |</span>| &&
      |</div>| &&
      |<table><tbody>| && lv_rows &&
      |</tbody></table></body></html>|.
  ENDMETHOD.

ENDCLASS.

CLASS ZCL_AVE_POPUP_DIFF IMPLEMENTATION.
  METHOD compute_diff.
    DATA(lv_nold) = lines( it_old ).
    DATA(lv_nnew) = lines( it_new ).

    " Build comparison keys — uppercase when ignore_case, otherwise verbatim
    DATA lt_old_key TYPE string_table.
    DATA lt_new_key TYPE string_table.
    LOOP AT it_old INTO DATA(ls_oi).
      APPEND COND string( WHEN i_ignore_case = abap_true
        THEN to_upper( CONV string( ls_oi ) )
        ELSE CONV string( ls_oi ) ) TO lt_old_key.
    ENDLOOP.
    LOOP AT it_new INTO DATA(ls_ni).
      APPEND COND string( WHEN i_ignore_case = abap_true
        THEN to_upper( CONV string( ls_ni ) )
        ELSE CONV string( ls_ni ) ) TO lt_new_key.
    ENDLOOP.

    " Simplest possible diff for large files: two-pointer walk with a
    " short look-ahead window for resync. No hash maps, no DP matrix —
    " just the result table in memory. Handles "one line deleted, rest
    " identical" correctly (resync at k=1). Degrades to 1:1 substitution
    " if no match within lc_window steps.
    IF lv_nold > 10000 OR lv_nnew > 10000.
      CONSTANTS lc_window TYPE i VALUE 50.
      DATA(lo_p) = NEW zcl_ave_progress( i_title = i_title i_threshold_secs = 15 ).
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
        IF lt_old_key[ lv_i1 ] = lt_new_key[ lv_j1 ].
          APPEND VALUE ty_diff_op( op = '=' text = CONV string( it_new[ lv_j1 ] ) ) TO result.
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
          IF lv_j1 + lv_k <= lv_nnew AND lt_new_key[ lv_j1 + lv_k ] = lt_old_key[ lv_i1 ].
            lv_mode = '+'.
            EXIT.
          ENDIF.
          " new[j] appears at old[i+k]? → k deletes
          IF lv_i1 + lv_k <= lv_nold AND lt_old_key[ lv_i1 + lv_k ] = lt_new_key[ lv_j1 ].
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
    DATA(lo_progress) = NEW zcl_ave_progress( i_title = i_title i_threshold_secs = 15 ).
    DATA lv_i TYPE i.
    DATA lv_j TYPE i.
    lv_i = 1.
    LOOP AT lt_old_key INTO DATA(ls_old).
      IF lo_progress->check(
           i_remaining = lv_nold - lv_i + 1
           i_total     = lv_nold ) = abap_true.
        RETURN.
      ENDIF.
      lv_j = 1.
      LOOP AT lt_new_key INTO DATA(ls_new).
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
        IF lt_old_key[ lv_i ] = lt_new_key[ lv_j ].
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
    " Build char-level LCS ops and render grouped spans.
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
    DATA(lv_cols) = lv_ln + 1.
    DATA(lv_rows) = lv_lo + 1.

    " Build comparison strings: uppercase when ignore_case, verbatim otherwise.
    " Used for LCS matching only; lv_old_t / lv_new_t still hold original text for rendering.
    DATA lv_old_cmp TYPE string.
    DATA lv_new_cmp TYPE string.
    IF iv_ignore_case = abap_true.
      lv_old_cmp = to_upper( lv_old_t ).
      lv_new_cmp = to_upper( lv_new_t ).
    ELSE.
      lv_old_cmp = lv_old_t.
      lv_new_cmp = lv_new_t.
    ENDIF.

    DATA lt_dp TYPE TABLE OF i.
    DATA(lv_size) = lv_rows * lv_cols.
    DO lv_size TIMES.
      APPEND 0 TO lt_dp.
    ENDDO.

    DATA lv_i TYPE i.
    DATA lv_j TYPE i.
    lv_i = 1.
    WHILE lv_i <= lv_lo.
      lv_j = 1.
      WHILE lv_j <= lv_ln.
        DATA(lv_cell) = lv_i * lv_cols + lv_j + 1.
        DATA(lv_off_o) = lv_i - 1.
        DATA(lv_off_n) = lv_j - 1.
        IF lv_old_cmp+lv_off_o(1) = lv_new_cmp+lv_off_n(1).
          DATA(lv_prev) = ( lv_i - 1 ) * lv_cols + ( lv_j - 1 ) + 1.
          lt_dp[ lv_cell ] = lt_dp[ lv_prev ] + 1.
        ELSE.
          DATA(lv_up)   = ( lv_i - 1 ) * lv_cols + lv_j + 1.
          DATA(lv_left) = lv_i * lv_cols + ( lv_j - 1 ) + 1.
          lt_dp[ lv_cell ] = COND i(
            WHEN lt_dp[ lv_up ] >= lt_dp[ lv_left ] THEN lt_dp[ lv_up ]
            ELSE lt_dp[ lv_left ] ).
        ENDIF.
        lv_j += 1.
      ENDWHILE.
      lv_i += 1.
    ENDWHILE.

    DATA lt_ops TYPE ty_t_diff.
    lv_i = lv_lo.
    lv_j = lv_ln.
    WHILE lv_i > 0 OR lv_j > 0.
      DATA(lv_off_bo) = lv_i - 1.
      DATA(lv_off_bn) = lv_j - 1.
      IF lv_i > 0 AND lv_j > 0 AND lv_old_cmp+lv_off_bo(1) = lv_new_cmp+lv_off_bn(1).
        INSERT VALUE ty_diff_op( op = '=' text = lv_old_t+lv_off_bo(1) ) INTO lt_ops INDEX 1.
        lv_i -= 1.
        lv_j -= 1.
      ELSEIF lv_j > 0.
        IF lv_i = 0.
          INSERT VALUE ty_diff_op( op = '+' text = lv_new_t+lv_off_bn(1) ) INTO lt_ops INDEX 1.
          lv_j -= 1.
        ELSEIF lt_dp[ lv_i * lv_cols + ( lv_j - 1 ) + 1 ] > lt_dp[ ( lv_i - 1 ) * lv_cols + lv_j + 1 ].
          INSERT VALUE ty_diff_op( op = '+' text = lv_new_t+lv_off_bn(1) ) INTO lt_ops INDEX 1.
          lv_j -= 1.
        ELSEIF lv_i > 0.
          INSERT VALUE ty_diff_op( op = '-' text = lv_old_t+lv_off_bo(1) ) INTO lt_ops INDEX 1.
          lv_i -= 1.
        ENDIF.
      ELSEIF lv_i > 0.
        INSERT VALUE ty_diff_op( op = '-' text = lv_old_t+lv_off_bo(1) ) INTO lt_ops INDEX 1.
        lv_i -= 1.
      ENDIF.
    ENDWHILE.

    collapse_token_ops( CHANGING ct_ops = lt_ops ).

    DATA(lv_del_style) = `background:#ffb3b3;color:#cc0000;padding:0 2px;outline:1px solid #c66`.
    DATA(lv_ins_style) = `background:#afffaf;color:#006600;padding:0 2px;outline:1px solid #6c6`.
    DATA lv_buf    TYPE string.
    DATA lv_buf_op TYPE c LENGTH 1.

    LOOP AT lt_ops INTO DATA(ls_part).
      IF lv_buf_op IS INITIAL OR ls_part-op = lv_buf_op.
        lv_buf = lv_buf && ls_part-text.
        lv_buf_op = ls_part-op.
        CONTINUE.
      ENDIF.

      DATA(lv_emit) = lv_buf.
      REPLACE ALL OCCURRENCES OF `&` IN lv_emit WITH `&amp;`.
      REPLACE ALL OCCURRENCES OF `<` IN lv_emit WITH `&lt;`.
      REPLACE ALL OCCURRENCES OF `>` IN lv_emit WITH `&gt;`.
      CASE lv_buf_op.
        WHEN '='.
          result = result && lv_emit.
        WHEN '-'.
          IF iv_side <> 'N'.
            DATA(lv_emit_cnd) = lv_emit.
            CONDENSE lv_emit_cnd.
            IF lv_emit_cnd IS NOT INITIAL.   " skip pure-space deletions (alignment gaps)
              REPLACE ALL OCCURRENCES OF ` ` IN lv_emit WITH `&nbsp;`.
              result = result && |<span style="{ lv_del_style }">{ lv_emit }</span>|.
            ENDIF.
          ENDIF.
        WHEN '+'.
          IF iv_side <> 'O'.
            REPLACE ALL OCCURRENCES OF ` ` IN lv_emit WITH `&nbsp;`.
            result = result && |<span style="{ lv_ins_style }">{ lv_emit }</span>|.
          ENDIF.
      ENDCASE.

      lv_buf = ls_part-text.
      lv_buf_op = ls_part-op.
    ENDLOOP.

    IF lv_buf IS NOT INITIAL.
      DATA(lv_emit_last) = lv_buf.
      REPLACE ALL OCCURRENCES OF `&` IN lv_emit_last WITH `&amp;`.
      REPLACE ALL OCCURRENCES OF `<` IN lv_emit_last WITH `&lt;`.
      REPLACE ALL OCCURRENCES OF `>` IN lv_emit_last WITH `&gt;`.
      CASE lv_buf_op.
        WHEN '='.
          result = result && lv_emit_last.
        WHEN '-'.
          IF iv_side <> 'N'.
            DATA(lv_emit_last_cnd) = lv_emit_last.
            CONDENSE lv_emit_last_cnd.
            IF lv_emit_last_cnd IS NOT INITIAL.  " skip pure-space deletions
              REPLACE ALL OCCURRENCES OF ` ` IN lv_emit_last WITH `&nbsp;`.
              result = result && |<span style="{ lv_del_style }">{ lv_emit_last }</span>|.
            ENDIF.
          ENDIF.
        WHEN '+'.
          IF iv_side <> 'O'.
            REPLACE ALL OCCURRENCES OF ` ` IN lv_emit_last WITH `&nbsp;`.
            result = result && |<span style="{ lv_ins_style }">{ lv_emit_last }</span>|.
          ENDIF.
      ENDCASE.
    ENDIF.
  ENDMETHOD.
  METHOD has_common_chars.
    " Mirrors hasCommonChars() in html_simulator/diff.js.
    DATA lv_a TYPE string.
    DATA lv_b TYPE string.
    lv_a = iv_a.
    lv_b = iv_b.

    WHILE strlen( lv_a ) > 0 AND substring( val = lv_a off = 0 len = 1 ) = ` `.
      lv_a = substring( val = lv_a off = 1 len = strlen( lv_a ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_b ) > 0 AND substring( val = lv_b off = 0 len = 1 ) = ` `.
      lv_b = substring( val = lv_b off = 1 len = strlen( lv_b ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_a ) > 0 AND substring( val = lv_a off = strlen( lv_a ) - 1 len = 1 ) = ` `.
      lv_a = substring( val = lv_a off = 0 len = strlen( lv_a ) - 1 ).
    ENDWHILE.
    WHILE strlen( lv_b ) > 0 AND substring( val = lv_b off = strlen( lv_b ) - 1 len = 1 ) = ` `.
      lv_b = substring( val = lv_b off = 0 len = strlen( lv_b ) - 1 ).
    ENDWHILE.

    DATA(lv_la) = strlen( lv_a ).
    DATA(lv_lb) = strlen( lv_b ).
    IF lv_la = 0 OR lv_lb = 0.
      result = abap_true.
      RETURN.
    ENDIF.
    IF lv_a = lv_b.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA lv_shorter TYPE string.
    DATA lv_longer  TYPE string.
    IF lv_la < lv_lb.
      lv_shorter = lv_a.
      lv_longer  = lv_b.
    ELSE.
      lv_shorter = lv_b.
      lv_longer  = lv_a.
    ENDIF.

    DATA(lv_shifted) = COND string(
      WHEN strlen( lv_longer ) > 1 THEN substring( val = lv_longer off = 1 )
      ELSE `` ).
    IF lv_shifted = lv_shorter.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA(lv_tail) = lv_shifted.
    WHILE strlen( lv_tail ) > 0 AND lv_tail(1) = ` `.
      lv_tail = substring( val = lv_tail off = 1 len = strlen( lv_tail ) - 1 ).
    ENDWHILE.
    IF lv_tail = lv_shorter.
      result = abap_true.
      RETURN.
    ENDIF.

    " One line's content is contained in the other
    " (e.g. commented-out: old="  email TYPE x," new="  "email TYPE x, "comment")
    IF strlen( lv_shorter ) >= 3 AND lv_longer CS lv_shorter.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA lv_cp TYPE i VALUE 0.
    WHILE lv_cp < lv_la AND lv_cp < lv_lb.
      IF substring( val = lv_a off = lv_cp len = 1 ) =
         substring( val = lv_b off = lv_cp len = 1 ).
        lv_cp += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.
    IF lv_cp < 3. result = abap_false. RETURN. ENDIF.

    " Prefix must cover ≥25% of the shorter line — prevents pairing lines that
    " share only a leading keyword (OR, AND, IF, ...) but differ in substance.
    DATA(lv_min_len) = nmin( val1 = lv_la val2 = lv_lb ).
    IF lv_cp * 4 < lv_min_len. result = abap_false. RETURN. ENDIF.

    " Strip common suffix to isolate the changed middle
    DATA lv_cs      TYPE i VALUE 0.
    DATA lv_la_rest TYPE i.
    DATA lv_lb_rest TYPE i.
    lv_la_rest = lv_la - lv_cp.
    lv_lb_rest = lv_lb - lv_cp.
    WHILE lv_cs < lv_la_rest AND lv_cs < lv_lb_rest.
      IF substring( val = lv_a off = lv_la - 1 - lv_cs len = 1 ) =
         substring( val = lv_b off = lv_lb - 1 - lv_cs len = 1 ).
        lv_cs += 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.
    DATA lv_mid_a  TYPE string.
    DATA lv_mid_b  TYPE string.
    DATA lv_mid_la TYPE i.
    DATA lv_mid_lb TYPE i.
    lv_mid_la = lv_la - lv_cp - lv_cs.
    lv_mid_lb = lv_lb - lv_cp - lv_cs.
    IF lv_mid_la > 0.
      lv_mid_a = substring( val = lv_a off = lv_cp len = lv_mid_la ).
    ENDIF.
    IF lv_mid_lb > 0.
      lv_mid_b = substring( val = lv_b off = lv_cp len = lv_mid_lb ).
    ENDIF.
    " More than 2 edit runs in the middle → lines differ in too many places to pair
    IF count_edit_runs( iv_a = lv_mid_a iv_b = lv_mid_b ) > 2.
      result = abap_false. RETURN.
    ENDIF.
    result = abap_true.
  ENDMETHOD.
  METHOD build_blame_map.
    " Filter versions for this object within [i_from, i_to] and order ascending
    DATA lt_vers TYPE zif_ave_popup_types=>ty_t_version_row.
    IF i_from IS INITIAL.
      " New object — all lines credited to the object version author
      LOOP AT it_versions INTO DATA(ls_v)
        WHERE versno  <= i_to
          AND objtype  = i_objtype
          AND objname  = i_objname.
        APPEND ls_v TO lt_vers.
      ENDLOOP.
    ELSE.
      " Existing object — trace changes across versions
      LOOP AT it_versions INTO ls_v
        WHERE versno  >= i_from
          AND versno  <= i_to
          AND objtype  = i_objtype
          AND objname  = i_objname.
        APPEND ls_v TO lt_vers.
      ENDLOOP.
    ENDIF.
    SORT lt_vers BY versno ASCENDING datum ASCENDING zeit ASCENDING.

    IF lt_vers IS INITIAL. RETURN. ENDIF.

    DATA lt_prev_src TYPE abaptxt255_tab.
    DATA lt_cur_src TYPE abaptxt255_tab.
    DATA(ls_first) = lt_vers[ 1 ].
    lt_prev_src = zcl_ave_popup_data=>get_ver_source(
      i_objtype = ls_first-objtype i_objname = ls_first-objname i_versno = ls_first-versno
      i_korrnum = ls_first-korrnum i_author  = ls_first-author
      i_datum   = ls_first-datum   i_zeit    = ls_first-zeit ).

    IF i_from IS INITIAL.
      LOOP AT lt_prev_src INTO DATA(ls_line).
        APPEND VALUE zif_ave_popup_types=>ty_blame_entry(
          text        = CONV string( ls_line )
          author      = COND #( WHEN ls_first-obj_owner IS NOT INITIAL THEN ls_first-obj_owner ELSE ls_first-author )
          author_name = COND #( WHEN ls_first-obj_owner IS NOT INITIAL THEN ls_first-obj_owner_name ELSE ls_first-author_name )
          datum       = ls_first-datum
          zeit        = ls_first-zeit
          versno_text = ls_first-versno_text
          korrnum     = ls_first-korrnum
          task        = ls_first-task
          task_text   = ls_first-korr_text
        ) TO result.
      ENDLOOP.
    ELSEIF lines( lt_vers ) < 2.
      RETURN.
    ENDIF.

    IF lines( lt_vers ) < 2. RETURN. ENDIF.

    DATA(lv_total) = lines( lt_vers ) - 1.
    DATA lv_idx TYPE i VALUE 2.
    WHILE lv_idx <= lines( lt_vers ).
      DATA(lv_step) = lv_idx - 1.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = CONV i( lv_step * 100 / lv_total )
                  text       = CONV char70( |Computing blame ({ lv_step }/{ lv_total })| ).
      DATA(ls_ver) = lt_vers[ lv_idx ].
      lt_cur_src = zcl_ave_popup_data=>get_ver_source(
        i_objtype = ls_ver-objtype i_objname = ls_ver-objname i_versno = ls_ver-versno
        i_korrnum = ls_ver-korrnum i_author  = ls_ver-author
        i_datum   = ls_ver-datum   i_zeit    = ls_ver-zeit ).
      DATA(lt_diff) = compute_diff(
        it_old  = lt_prev_src
        it_new  = lt_cur_src
        i_title = |Computing blame ({ lv_step }/{ lv_total })| ).

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
  METHOD count_edit_runs.
    " Tokenize by spaces; keep non-empty tokens (single-char tokens like = ( ) are valid anchors)
    DATA lt_a       TYPE TABLE OF string.
    DATA lt_b       TYPE TABLE OF string.
    DATA lt_tmp     TYPE TABLE OF string.
    DATA lt_pair_ia TYPE TABLE OF i.   " greedy-matched indices in lt_a (1-based)
    DATA lt_pair_ib TYPE TABLE OF i.   " greedy-matched indices in lt_b (1-based)
    DATA lv_jstart  TYPE i.
    DATA lv_jb      TYPE i.
    DATA lv_ia      TYPE i.
    DATA lv_np      TYPE i.
    DATA lv_k       TYPE i.
    DATA lv_pia     TYPE i.
    DATA lv_pib     TYPE i.
    DATA lv_pia2    TYPE i.
    DATA lv_pib2    TYPE i.

    SPLIT iv_a AT ` ` INTO TABLE lt_a.
    SPLIT iv_b AT ` ` INTO TABLE lt_b.
    LOOP AT lt_a INTO DATA(lv_t). IF lv_t IS NOT INITIAL. APPEND lv_t TO lt_tmp. ENDIF. ENDLOOP.
    lt_a = lt_tmp. CLEAR lt_tmp.
    LOOP AT lt_b INTO lv_t. IF lv_t IS NOT INITIAL. APPEND lv_t TO lt_tmp. ENDIF. ENDLOOP.
    lt_b = lt_tmp.

    DATA(lv_na) = lines( lt_a ).
    DATA(lv_nb) = lines( lt_b ).
    IF lv_na = 0 AND lv_nb = 0. RETURN.         ENDIF.
    IF lv_na = 0 OR  lv_nb = 0. result = 1. RETURN. ENDIF.

    " Greedy forward scan: find matching token pairs (ia, ib) in ascending order
    lv_jstart = 1.
    DO lv_na TIMES.
      lv_ia = sy-index.
      lv_jb = lv_jstart.
      WHILE lv_jb <= lv_nb.
        IF lt_a[ lv_ia ] = lt_b[ lv_jb ].
          APPEND lv_ia TO lt_pair_ia.
          APPEND lv_jb TO lt_pair_ib.
          lv_jstart = lv_jb + 1.
          EXIT.
        ENDIF.
        lv_jb += 1.
      ENDWHILE.
    ENDDO.

    lv_np = lines( lt_pair_ia ).
    IF lv_np = 0. result = 1. RETURN. ENDIF.

    " Count edit runs: unmatched region before first island,
    " between consecutive islands, and after last island
    lv_pia = lt_pair_ia[ 1 ].
    lv_pib = lt_pair_ib[ 1 ].
    IF lv_pia > 1 OR lv_pib > 1. result += 1. ENDIF.
    DO lv_np - 1 TIMES.
      lv_k    = sy-index.
      lv_pia  = lt_pair_ia[ lv_k ].
      lv_pib  = lt_pair_ib[ lv_k ].
      lv_pia2 = lt_pair_ia[ lv_k + 1 ].
      lv_pib2 = lt_pair_ib[ lv_k + 1 ].
      IF lv_pia2 > lv_pia + 1 OR lv_pib2 > lv_pib + 1.
        result += 1.
      ENDIF.
    ENDDO.
    lv_pia = lt_pair_ia[ lv_np ].
    lv_pib = lt_pair_ib[ lv_np ].
    IF lv_pia < lv_na OR lv_pib < lv_nb. result += 1. ENDIF.
  ENDMETHOD.
  METHOD collapse_token_ops.
    " Collapse word tokens where both deletions AND insertions exist (>2 total)
    " into whole-token replace, rather than showing partial char-level matches.
    DATA lt_result TYPE ty_t_diff.
    DATA lv_ts     TYPE i VALUE 1.
    DATA lv_te     TYPE i.
    DATA lv_tk     TYPE i.
    DATA lv_c0     TYPE string.
    DATA lv_cn     TYPE string.
    DATA lv_iw     TYPE abap_bool.
    DATA lv_iwn    TYPE abap_bool.
    DATA lv_opn    TYPE c LENGTH 1.
    DATA lv_dc     TYPE i.
    DATA lv_ic     TYPE i.
    DATA lv_ot     TYPE string.
    DATA lv_nt     TYPE string.
    DATA lv_opk    TYPE c LENGTH 1.
    DATA lv_ec     TYPE string.
    DATA lv_wch    TYPE string VALUE
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.
    DATA(lv_no) = lines( ct_ops ).
    WHILE lv_ts <= lv_no.
      lv_c0 = ct_ops[ lv_ts ]-text.
      lv_iw = xsdbool( lv_c0 CO lv_wch ).
      IF lv_iw = abap_false AND ct_ops[ lv_ts ]-op = '='.
        APPEND ct_ops[ lv_ts ] TO lt_result.
        lv_ts += 1.
        CONTINUE.
      ENDIF.
      lv_te = lv_ts.
      WHILE lv_te < lv_no.
        lv_cn  = ct_ops[ lv_te + 1 ]-text.
        lv_iwn = xsdbool( lv_cn CO lv_wch ).
        lv_opn = ct_ops[ lv_te + 1 ]-op.
        IF lv_opn <> '=' OR lv_iwn = abap_true.
          lv_te += 1.
        ELSE.
          EXIT.
        ENDIF.
      ENDWHILE.
      CLEAR: lv_dc, lv_ic, lv_ot, lv_nt.
      lv_tk = lv_ts.
      WHILE lv_tk <= lv_te.
        lv_opk = ct_ops[ lv_tk ]-op.
        lv_ec  = ct_ops[ lv_tk ]-text.
        CASE lv_opk.
          WHEN '-'.
            lv_ot = lv_ot && lv_ec.
            lv_dc += 1.
          WHEN '+'.
            lv_nt = lv_nt && lv_ec.
            lv_ic += 1.
          WHEN '='.
            lv_ot = lv_ot && lv_ec.
            lv_nt = lv_nt && lv_ec.
        ENDCASE.
        lv_tk += 1.
      ENDWHILE.
      IF lv_dc > 0 AND lv_ic > 0 AND lv_dc + lv_ic > 2.
        IF lv_ot IS NOT INITIAL.
          APPEND VALUE ty_diff_op( op = '-' text = lv_ot ) TO lt_result.
        ENDIF.
        IF lv_nt IS NOT INITIAL.
          APPEND VALUE ty_diff_op( op = '+' text = lv_nt ) TO lt_result.
        ENDIF.
      ELSE.
        lv_tk = lv_ts.
        WHILE lv_tk <= lv_te.
          APPEND ct_ops[ lv_tk ] TO lt_result.
          lv_tk += 1.
        ENDWHILE.
      ENDIF.
      lv_ts = lv_te + 1.
    ENDWHILE.
    ct_ops = lt_result.
  ENDMETHOD.
ENDCLASS.

CLASS ZCL_AVE_POPUP_DATA IMPLEMENTATION.
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
             norm_src TYPE string_table,
             has_src TYPE abap_bool,
             owner   TYPE versuser,
             owner_name TYPE ad_namtext,
             datum   TYPE versdate,
             zeit    TYPE verstime,
             work_idx TYPE i,
           END OF ty_prev.
    TYPES: BEGIN OF ty_work,
             row      TYPE zif_ave_popup_types=>ty_version_row,
             norm_src TYPE string_table,
             orig_idx TYPE i,
             check    TYPE abap_bool,
             keep     TYPE abap_bool,
           END OF ty_work.
    DATA lt_prev_map TYPE HASHED TABLE OF ty_prev WITH UNIQUE KEY objtype objname.
    DATA lt_result   TYPE zif_ave_popup_types=>ty_t_version_row.
    DATA lt_work     TYPE STANDARD TABLE OF ty_work WITH DEFAULT KEY.
    FIELD-SYMBOLS <ver> TYPE ty_work.
    FIELD-SYMBOLS <p>   TYPE ty_prev.

    " ct_versions can contain rows for multiple (objtype,objname) pairs mixed
    " together (e.g. all methods of a class sorted globally by versno).
    " Analyze chronologically so duplicate runs keep the earliest version.
    LOOP AT ct_versions INTO DATA(ls_input_ver).
      DATA ls_work TYPE ty_work.
      ls_work-row = ls_input_ver.
      ls_work-orig_idx = sy-tabix.
      APPEND ls_work TO lt_work.
    ENDLOOP.
    SORT lt_work BY row-objtype row-objname row-versno ASCENDING row-datum ASCENDING row-zeit ASCENDING.

    IF i_keep_korrnum IS INITIAL.
      LOOP AT lt_work ASSIGNING <ver>.
        <ver>-check = abap_true.
      ENDLOOP.
    ELSE.
      DATA(lv_group_start) = 1.
      WHILE lv_group_start <= lines( lt_work ).
        READ TABLE lt_work INTO DATA(ls_group) INDEX lv_group_start.
        DATA(lv_group_end) = lv_group_start.
        DATA(lv_selected_idx) = 0.

        WHILE lv_group_end <= lines( lt_work ).
          READ TABLE lt_work ASSIGNING FIELD-SYMBOL(<group_ver>) INDEX lv_group_end.
          IF <group_ver>-row-objtype <> ls_group-row-objtype
          OR <group_ver>-row-objname <> ls_group-row-objname.
            EXIT.
          ENDIF.
          IF <group_ver>-row-korrnum = i_keep_korrnum.
            lv_selected_idx = lv_group_end.
          ENDIF.
          lv_group_end = lv_group_end + 1.
        ENDWHILE.

        IF lv_selected_idx > 0.
          DATA(lv_prev_k_idx) = 0.
          DATA(lv_scan_idx) = lv_selected_idx - 1.
          WHILE lv_scan_idx >= lv_group_start.
            READ TABLE lt_work ASSIGNING <group_ver> INDEX lv_scan_idx.
            IF <group_ver>-row-trfunction = 'K'.
              lv_prev_k_idx = lv_scan_idx.
              EXIT.
            ENDIF.
            lv_scan_idx = lv_scan_idx - 1.
          ENDWHILE.

          DATA(lv_check_from) = COND i(
            WHEN lv_prev_k_idx > lv_group_start THEN lv_prev_k_idx - 1
            ELSE lv_group_start ).
          DATA(lv_mark_idx) = lv_check_from.
          WHILE lv_mark_idx <= lv_selected_idx.
            READ TABLE lt_work ASSIGNING <group_ver> INDEX lv_mark_idx.
            <group_ver>-check = abap_true.
            lv_mark_idx = lv_mark_idx + 1.
          ENDWHILE.
        ENDIF.

        lv_group_start = lv_group_end.
      ENDWHILE.
    ENDIF.

    DATA(lv_total) = 0.
    LOOP AT lt_work TRANSPORTING NO FIELDS WHERE check = abap_true.
      lv_total = lv_total + 1.
    ENDLOOP.
    DATA(lv_check_idx) = 0.

    LOOP AT lt_work ASSIGNING <ver>.
      DATA(lv_work_idx) = sy-tabix.
      IF <ver>-check <> abap_true.
        <ver>-keep = abap_true.
        CONTINUE.
      ENDIF.

      lv_check_idx = lv_check_idx + 1.
      IF lv_check_idx = 1 OR lv_check_idx = lv_total OR lv_check_idx MOD 5 = 0.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = CONV i( lv_check_idx * 100 / COND i( WHEN lv_total > 0 THEN lv_total ELSE 1 ) )
                    text       = CONV char70( |Checking duplicates { <ver>-row-objtype } { <ver>-row-objname } ({ lv_check_idx }/{ lv_total })| ).
      ENDIF.

      " Read source directly from SVRS — bypass zcl_ave_version constructor,
      " whose load_latest_task can raise zcx_ave and leave lt_cur_src empty
      " for some versions while others succeed, producing spurious diffs.
      DATA lt_cur_src TYPE abaptxt255_tab.
      CLEAR lt_cur_src.
      IF <ver>-row-objtype = 'DDLS'.
        lt_cur_src = zcl_ave_version=>load_ddls_source(
          i_objname = <ver>-row-objname
          i_versno  = <ver>-row-versno ).
      ELSE.
        DATA lt_trdir TYPE trdir_it.
        DATA(lv_db_no) = zcl_ave_versno=>to_internal( <ver>-row-versno ).
        CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
          EXPORTING object_name = <ver>-row-objname
                    object_type = <ver>-row-objtype
                    versno      = lv_db_no
          TABLES    repos_tab   = lt_cur_src
                    trdir_tab   = lt_trdir
          EXCEPTIONS no_version = 1 OTHERS = 2.
        IF sy-subrc <> 0. CLEAR lt_cur_src. ENDIF.
      ENDIF.

      " Compare ignoring leading whitespace (pretty-printer reindent is not a real change)
      DATA lt_cur_norm  TYPE string_table.
      DATA lt_prev_norm TYPE string_table.
      CLEAR lt_cur_norm. CLEAR lt_prev_norm.
      LOOP AT lt_cur_src INTO DATA(ls_cn).
        DATA(lv_cn) = CONV string( ls_cn ).
        SHIFT lv_cn LEFT DELETING LEADING ` `.
        APPEND lv_cn TO lt_cur_norm.
      ENDLOOP.
      <ver>-norm_src = lt_cur_norm.

      DATA lv_has_prev TYPE abap_bool.
      lv_has_prev = abap_false.
      UNASSIGN <p>.
      READ TABLE lt_prev_map ASSIGNING <p>
        WITH TABLE KEY objtype = <ver>-row-objtype objname = <ver>-row-objname.
      IF sy-subrc = 0 AND <p>-has_src = abap_true.
        lv_has_prev = abap_true.
        lt_prev_norm = <p>-norm_src.
      ENDIF.

      DATA(lv_is_duplicate) = COND abap_bool(
        WHEN lv_has_prev = abap_true AND lt_cur_norm = lt_prev_norm THEN abap_true
        ELSE abap_false ).
      DATA(lv_keep_korrnum) = COND abap_bool(
        WHEN i_keep_korrnum IS NOT INITIAL AND <ver>-row-korrnum = i_keep_korrnum THEN abap_true
        ELSE abap_false ).
      DATA(lv_k_over_t) = COND abap_bool(
        WHEN lv_is_duplicate = abap_true
         AND <p> IS ASSIGNED
         AND <p>-work_idx IS NOT INITIAL
         AND <ver>-row-trfunction = 'K'
         AND lt_work[ <p>-work_idx ]-row-trfunction = 'T'
        THEN abap_true
        ELSE abap_false ).

      IF lv_is_duplicate = abap_true AND <p> IS ASSIGNED.
        <ver>-row-obj_owner      = <p>-owner.
        <ver>-row-obj_owner_name = <p>-owner_name.
*        <ver>-row-datum          = <p>-datum.
*        <ver>-row-zeit           = <p>-zeit.
      ENDIF.

      IF lv_has_prev = abap_false OR lv_is_duplicate = abap_false OR lv_keep_korrnum = abap_true OR lv_k_over_t = abap_true.
        <ver>-keep = abap_true.
        IF lv_k_over_t = abap_true.
          lt_work[ <p>-work_idx ]-keep = abap_false.
          <p>-norm_src   = lt_cur_norm.
          <p>-has_src    = abap_true.
          <p>-owner      = <ver>-row-obj_owner.
          <p>-owner_name = <ver>-row-obj_owner_name.
          <p>-datum      = <ver>-row-datum.
          <p>-zeit       = <ver>-row-zeit.
          <p>-work_idx   = lv_work_idx.
        ELSEIF lv_is_duplicate = abap_false.
          IF <p> IS ASSIGNED.
            <p>-norm_src   = lt_cur_norm.
            <p>-has_src    = abap_true.
            <p>-owner      = <ver>-row-obj_owner.
            <p>-owner_name = <ver>-row-obj_owner_name.
            <p>-datum      = <ver>-row-datum.
            <p>-zeit       = <ver>-row-zeit.
            <p>-work_idx   = lv_work_idx.
          ELSE.
            INSERT VALUE #( objtype    = <ver>-row-objtype
                            objname    = <ver>-row-objname
                            norm_src   = lt_cur_norm
                            has_src    = abap_true
                            owner      = <ver>-row-obj_owner
                            owner_name = <ver>-row-obj_owner_name
                            datum      = <ver>-row-datum
                            zeit       = <ver>-row-zeit
                            work_idx   = lv_work_idx )
              INTO TABLE lt_prev_map.
          ENDIF.
        ENDIF.
      ENDIF.
      UNASSIGN <p>.
    ENDLOOP.

    SORT lt_work BY orig_idx ASCENDING.
    LOOP AT lt_work ASSIGNING <ver> WHERE keep = abap_true.
      APPEND <ver>-row TO lt_result.
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
          WHEN 'DDLS'.
            result = lines( zcl_ave_version=>load_ddls_source(
              i_objname = i_name
              i_versno  = zcl_ave_version=>c_version-active ) ).
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
          IF is_substantive_user_change(
               it_versions = build_versions_for_check( i_type = ls_part-type i_name = ls_part-object_name )
               i_type      = ls_part-type
               i_name      = ls_part-object_name ) = abap_true.
            result = abap_true.
            RETURN.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.
  METHOD build_versions_for_check.
    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd( type = i_type name = i_name no_toc = mv_no_toc ignore_unreleased = abap_true ).
      CATCH zcx_ave.
        RETURN.
    ENDTRY.

    " vrsd_list already has versno (external), korrnum, objtype, objname — no zcl_ave_version needed.
    LOOP AT lo_vrsd->vrsd_list INTO DATA(ls_vrsd).
      APPEND VALUE zif_ave_popup_types=>ty_version_row(
        versno  = ls_vrsd-versno
        korrnum = ls_vrsd-korrnum
        objtype = ls_vrsd-objtype
        objname = ls_vrsd-objname ) TO result.
    ENDLOOP.

    SORT result BY versno DESCENDING.

    " Fill trfunction from E070 — one SELECT per unique korrnum
    LOOP AT result ASSIGNING FIELD-SYMBOL(<v>).
      CHECK <v>-korrnum IS NOT INITIAL AND <v>-trfunction IS INITIAL.
      SELECT SINGLE trfunction FROM e070
        WHERE trkorr = @<v>-korrnum
        INTO @<v>-trfunction.
      " Propagate trfunction to all versions with same korrnum
      LOOP AT result ASSIGNING FIELD-SYMBOL(<v2>) WHERE korrnum = <v>-korrnum AND trfunction IS INITIAL.
        <v2>-trfunction = <v>-trfunction.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
  METHOD is_substantive_user_change.
    " it_versions is already sorted newest-first with trfunction filled.
    " Find the latest version and the nearest prior K-type version, then compare sources.
    IF it_versions IS INITIAL. RETURN. ENDIF.

    DATA(ls_latest) = it_versions[ 1 ].

    DATA ls_prior LIKE ls_latest.
    DATA lv_k_count TYPE i.
    LOOP AT it_versions TRANSPORTING NO FIELDS WHERE trfunction = 'K'.
      lv_k_count += 1.
    ENDLOOP.
    IF lv_k_count = 1.
      result = abap_true.
      RETURN.
    ENDIF.

    LOOP AT it_versions INTO ls_prior
      WHERE versno < ls_latest-versno AND trfunction = 'K'.
      EXIT.
    ENDLOOP.
    IF ls_prior IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_new TYPE abaptxt255_tab.
    DATA lt_old TYPE abaptxt255_tab.
    IF i_type = 'DDLS'.
      lt_new = zcl_ave_version=>load_ddls_source( i_objname = i_name i_versno = ls_latest-versno ).
      lt_old = zcl_ave_version=>load_ddls_source( i_objname = i_name i_versno = ls_prior-versno ).
    ELSE.
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
    ENDIF.

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
        height                      = 345
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

    IF mv_code_review = abap_true.
      DELETE mt_parts WHERE rowcolor <> 'C510'.
      CLEAR: mt_acr_stats, mt_hunk_info, mt_hunk_threads,
             mt_approved, mt_declined, mt_decline_notes,
             mv_cr_base_html, mv_cr_cur_key, mv_decline_view_user.
      mv_cr_prepared = abap_false.
      mv_cr_report_html = build_cr_object_report_html( ).

      " Insert REPORT pseudo-part at the top of the list
      DATA(lv_total_acr) = lines( mt_parts ).
      DATA(ls_rpt) = VALUE ty_part_row(
        type      = 'RPT'
        name      = |[ Code Review Report - { lv_total_acr } object(s) ]|
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
        IF sy-subrc <> 0.
          LOOP AT mt_diff_cache INTO ls_ch
            WHERE key-objtype  = ls_stat-objtype
              AND key-objname  = ls_stat-obj_name
              AND key-versno_o = ls_stat-versno_old
              AND key-versno_n = ls_stat-versno_new.
            EXIT.
          ENDLOOP.
        ENDIF.
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
    CLEAR mv_cur_creator.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING percentage = 0
                text       = CONV char70( |Loading versions for { i_objtype } { i_objname }| ).

    TRY.
        DATA(lo_vrsd) = NEW zcl_ave_vrsd(
          type      = i_objtype
          name      = i_objname
          no_toc    = abap_false
          date_from = mv_date_from ).
      CATCH zcx_ave.
        RETURN.
    ENDTRY.

    DATA(lv_vrsd_total) = lines( lo_vrsd->vrsd_list ).
    LOOP AT lo_vrsd->vrsd_list INTO DATA(ls_vrsd).
      IF sy-tabix = 1 OR sy-tabix = lv_vrsd_total OR sy-tabix MOD 10 = 0.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = CONV i( sy-tabix * 20 / COND i( WHEN lv_vrsd_total > 0 THEN lv_vrsd_total ELSE 1 ) )
                    text       = CONV char70( |Reading version metadata ({ sy-tabix }/{ lv_vrsd_total })| ).
      ENDIF.
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

    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver_trf>).
      CHECK <ver_trf>-korrnum IS NOT INITIAL AND <ver_trf>-trfunction IS INITIAL.
      SELECT SINGLE trfunction FROM e070
        WHERE trkorr = @<ver_trf>-korrnum
        INTO @<ver_trf>-trfunction.
      LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver_trf2>)
        WHERE korrnum = <ver_trf>-korrnum AND trfunction IS INITIAL.
        <ver_trf2>-trfunction = <ver_trf>-trfunction.
      ENDLOOP.
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
             strkorr  TYPE trkorr,
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
    DATA lv_trf_s TYPE e070-trfunction VALUE 'S'.

    " Build E071 key set for this object (map VRSD type -> E071 transport type)
    TYPES: BEGIN OF ty_lv_obj_key,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
           END OF ty_lv_obj_key.
    TYPES: BEGIN OF ty_lv_task_cand,
             trkorr   TYPE trkorr,
             as4user  TYPE as4user,
             as4date  TYPE as4date,
             as4time  TYPE as4time,
           END OF ty_lv_task_cand.
    DATA lt_lv_keys      TYPE SORTED TABLE OF ty_lv_obj_key WITH UNIQUE KEY object obj_name.
    DATA lt_lv_all_tasks TYPE STANDARD TABLE OF ty_lv_task_cand.
    "data lv_trf_s        TYPE e070-trfunction VALUE 'S'.

    DATA lv_lv_e071_type TYPE e071-object.
    DATA lv_lv_e071_name TYPE versobjnam.
    lv_lv_e071_type = SWITCH e071-object( i_objtype
      WHEN 'REPS' OR 'REPT'                                THEN 'PROG'
      WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' THEN 'CLAS'
      ELSE i_objtype ).
    lv_lv_e071_name = i_objname.
    CASE i_objtype.
      WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'REPT'.
        DATA(lv_lv_eq) = find( val = lv_lv_e071_name sub = '=' ).
        IF lv_lv_eq > 0.
          lv_lv_e071_name = lv_lv_e071_name(lv_lv_eq).
        ENDIF.
    ENDCASE.

    INSERT VALUE #( object = lv_lv_e071_type obj_name = lv_lv_e071_name ) INTO TABLE lt_lv_keys.
    IF lv_lv_e071_type = 'PROG'.
      INSERT VALUE #( object = 'REPS' obj_name = lv_lv_e071_name ) INTO TABLE lt_lv_keys.
    ELSEIF lv_lv_e071_type = 'REPS'.
      INSERT VALUE #( object = 'PROG' obj_name = lv_lv_e071_name ) INTO TABLE lt_lv_keys.
    ENDIF.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING percentage = 35
                text       = CONV char70( |Reading S-requests for { i_objtype } { i_objname }| ).

    SELECT e070~trkorr, e070~as4user, e070~as4date, e070~as4time
      FROM e071
      INNER JOIN e070 ON e070~trkorr = e071~trkorr
      FOR ALL ENTRIES IN @lt_lv_keys
      WHERE e071~object     = @lt_lv_keys-object
        AND e071~obj_name   = @lt_lv_keys-obj_name
        AND e070~trfunction = @lv_trf_s
      INTO TABLE @lt_lv_all_tasks.
    SORT lt_lv_all_tasks BY as4date DESCENDING as4time DESCENDING.

    DATA(lv_match_total) = lines( mt_versions ).
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver>).
      IF sy-tabix = 1 OR sy-tabix = lv_match_total OR sy-tabix MOD 10 = 0.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 35 + CONV i( sy-tabix * 25 / COND i( WHEN lv_match_total > 0 THEN lv_match_total ELSE 1 ) )
                    text       = CONV char70( |Matching S-request ({ sy-tabix }/{ lv_match_total })| ).
      ENDIF.

      LOOP AT lt_lv_all_tasks INTO DATA(ls_cand).
        CHECK ls_cand-as4date < <ver>-datum
           OR ( ls_cand-as4date = <ver>-datum AND ls_cand-as4time <= <ver>-zeit ).
        <ver>-task           = ls_cand-trkorr.
        <ver>-obj_owner      = ls_cand-as4user.
        <ver>-obj_owner_name = zcl_ave_popup_data=>get_user_name( ls_cand-as4user ).
        EXIT.
      ENDLOOP.
    ENDLOOP.

    DATA ls_creator_ver TYPE ty_version_row.
    LOOP AT mt_versions INTO DATA(ls_creator_scan).
      IF ls_creator_ver IS INITIAL OR ls_creator_scan-versno < ls_creator_ver-versno.
        ls_creator_ver = ls_creator_scan.
      ENDIF.
    ENDLOOP.
    IF ls_creator_ver IS NOT INITIAL.
      mv_cur_creator = COND versuser(
        WHEN ls_creator_ver-obj_owner IS NOT INITIAL THEN ls_creator_ver-obj_owner
        ELSE ls_creator_ver-author ).
    ENDIF.

    " Fill request description and trfunction from E07T / E070
    DATA lv_korr_text TYPE e07t-as4text.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver2>).
      CHECK <ver2>-korrnum IS NOT INITIAL.
      SELECT SINGLE as4text FROM e07t
        WHERE trkorr = @<ver2>-korrnum
          AND langu  = @sy-langu
        INTO @lv_korr_text.
      <ver2>-korr_text = lv_korr_text.

      IF <ver2>-trfunction IS INITIAL.
        SELECT SINGLE trfunction FROM e070
          WHERE trkorr = @<ver2>-korrnum
          INTO @<ver2>-trfunction.
      ENDIF.
    ENDLOOP.

    IF mv_remove_dup = abap_true.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = 70
                  text       = CONV char70( |Checking duplicate versions for { i_objtype } { i_objname }| ).
      zcl_ave_popup_data=>remove_duplicate_versions(
        EXPORTING i_keep_korrnum = COND #( WHEN mv_object_type = zcl_ave_object_factory=>gc_type-tr
                                           THEN CONV trkorr( mv_object_name ) )
        CHANGING  ct_versions    = mt_versions ).
    ENDIF.

    IF mv_no_toc = abap_true.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = 95
                  text       = CONV char70( |Filtering TOC versions for { i_objtype } { i_objname }| ).
      DELETE mt_versions WHERE trfunction = 'T'.
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
          no_toc            = abap_false ).
      CATCH zcx_ave.
        RETURN.
    ENDTRY.

    DATA lv_tv_trf_s TYPE e070-trfunction VALUE 'S'.

    LOOP AT lo_vrsd->vrsd_list INTO DATA(ls_v).
      DATA ls_row TYPE ty_version_row.
      ls_row-versno  = zcl_ave_versno=>to_external( ls_v-versno ).
      ls_row-versno_text = COND string(
        WHEN ls_row-versno = zcl_ave_version=>c_version-active   THEN 'Active'
        WHEN ls_row-versno = zcl_ave_version=>c_version-modified THEN 'Modified'
        ELSE CONV string( ls_row-versno + 0 ) ).
      ls_row-datum      = ls_v-datum.
      ls_row-zeit       = ls_v-zeit.
      ls_row-author     = ls_v-author.
      ls_row-korrnum    = ls_v-korrnum.
      ls_row-objtype    = i_objtype.
      ls_row-objname    = i_objname.
      IF ls_v-korrnum IS NOT INITIAL.
        SELECT SINGLE trfunction FROM e070
          WHERE trkorr = @ls_v-korrnum INTO @ls_row-trfunction.
        SELECT SINGLE as4text FROM e07t
          WHERE trkorr = @ls_v-korrnum AND langu = @sy-langu INTO @ls_row-korr_text.
      ENDIF.
      ls_row-author_name = zcl_ave_popup_data=>get_user_name( ls_row-author ).
      APPEND ls_row TO mt_versions.
      CLEAR ls_row.
    ENDLOOP.

    SORT mt_versions BY versno DESCENDING datum DESCENDING zeit DESCENDING.

    TYPES: BEGIN OF ty_tv_obj_key,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
           END OF ty_tv_obj_key.
    TYPES: BEGIN OF ty_tv_task_cand,
             trkorr   TYPE trkorr,
             as4user  TYPE as4user,
             as4date  TYPE as4date,
             as4time  TYPE as4time,
           END OF ty_tv_task_cand.
    DATA lt_tv_keys      TYPE SORTED TABLE OF ty_tv_obj_key WITH UNIQUE KEY object obj_name.
    DATA lt_tv_all_tasks TYPE STANDARD TABLE OF ty_tv_task_cand.

    DATA lv_tv_e071_type TYPE e071-object.
    DATA lv_tv_e071_name TYPE versobjnam.
    lv_tv_e071_type = SWITCH e071-object( i_objtype
      WHEN 'REPS' OR 'REPT'                                THEN 'PROG'
      WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' THEN 'CLAS'
      ELSE i_objtype ).
    lv_tv_e071_name = i_objname.
    CASE i_objtype.
      WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'REPT'.
        DATA(lv_tv_eq) = find( val = lv_tv_e071_name sub = '=' ).
        IF lv_tv_eq > 0.
          lv_tv_e071_name = lv_tv_e071_name(lv_tv_eq).
        ENDIF.
    ENDCASE.

    INSERT VALUE #( object = lv_tv_e071_type obj_name = lv_tv_e071_name ) INTO TABLE lt_tv_keys.
    IF lv_tv_e071_type = 'PROG'.
      INSERT VALUE #( object = 'REPS' obj_name = lv_tv_e071_name ) INTO TABLE lt_tv_keys.
    ELSEIF lv_tv_e071_type = 'REPS'.
      INSERT VALUE #( object = 'PROG' obj_name = lv_tv_e071_name ) INTO TABLE lt_tv_keys.
    ENDIF.

    SELECT e070~trkorr, e070~as4user, e070~as4date, e070~as4time
      FROM e071
      INNER JOIN e070 ON e070~trkorr = e071~trkorr
      FOR ALL ENTRIES IN @lt_tv_keys
      WHERE e071~object     = @lt_tv_keys-object
        AND e071~obj_name   = @lt_tv_keys-obj_name
        AND e070~trfunction = @lv_tv_trf_s
      INTO TABLE @lt_tv_all_tasks.
    SORT lt_tv_all_tasks BY as4date DESCENDING as4time DESCENDING.

    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ver>).
      LOOP AT lt_tv_all_tasks INTO DATA(ls_cand).
        CHECK ls_cand-as4date < <ver>-datum
           OR ( ls_cand-as4date = <ver>-datum AND ls_cand-as4time <= <ver>-zeit ).
        <ver>-task        = ls_cand-trkorr.
        <ver>-author      = ls_cand-as4user.
        <ver>-author_name = zcl_ave_popup_data=>get_user_name( ls_cand-as4user ).
        EXIT.
      ENDLOOP.
    ENDLOOP.

    IF mv_remove_dup = abap_true.
      zcl_ave_popup_data=>remove_duplicate_versions(
        EXPORTING i_keep_korrnum = COND #( WHEN mv_object_type = zcl_ave_object_factory=>gc_type-tr
                                           THEN CONV trkorr( mv_object_name ) )
        CHANGING  ct_versions    = mt_versions ).
    ENDIF.

    IF mv_no_toc = abap_true.
      DELETE mt_versions WHERE trfunction = 'T'.
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
          save_review_to_db( ).
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
  METHOD load_review_payload.
    CLEAR es_payload.
    DATA lv_payload_json TYPE string.
    DATA lv_tabname TYPE tabname VALUE 'ZAVE_REVIEW'.

    TRY.
        SELECT SINGLE payload

          FROM (lv_tabname)
          WHERE trkorr = @iv_trkorr
          INTO @lv_payload_json.
      CATCH cx_sy_dynamic_osql_semantics
            cx_sy_dynamic_osql_syntax
            cx_sy_open_sql_db.
        RETURN.
    ENDTRY.

    IF sy-subrc <> 0 OR lv_payload_json IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json = lv_payload_json
          CHANGING  data = es_payload ).
        result = abap_true.
      CATCH cx_root.
        CLEAR es_payload.
    ENDTRY.
  ENDMETHOD.
  METHOD load_review_from_db.
    CHECK mv_code_review = abap_true.
    CHECK mv_object_type = zcl_ave_object_factory=>gc_type-tr.
    CHECK has_review_table( ) = abap_true.

    CLEAR: mt_approved, mt_declined, mt_decline_notes, mt_hunk_threads.

    DATA(ls_payload) = VALUE ty_saved_payload( ).
    CHECK load_review_payload(
      EXPORTING iv_trkorr = CONV #( mv_object_name )
      IMPORTING es_payload = ls_payload ) = abap_true.

    LOOP AT ls_payload-threads INTO DATA(ls_saved_thread).
      DATA(ls_thread) = VALUE ty_hunk_thread(
        hunk_key     = ls_saved_thread-hunk_key
        objtype      = ls_saved_thread-objtype
        obj_name     = ls_saved_thread-obj_name
        class_name   = ls_saved_thread-class_name
        display_name = ls_saved_thread-display_name
        hunk_no      = ls_saved_thread-hunk_no
        start_line   = ls_saved_thread-start_line
        change_count = ls_saved_thread-change_count
        messages     = ls_saved_thread-messages ).
      READ TABLE mt_hunk_info INTO DATA(ls_hunk_info_cur)
        WITH TABLE KEY hunk_key = ls_saved_thread-hunk_key.
      IF sy-subrc = 0.
        ls_thread-objtype      = ls_hunk_info_cur-objtype.
        ls_thread-obj_name     = ls_hunk_info_cur-obj_name.
        ls_thread-class_name   = ls_hunk_info_cur-class_name.
        ls_thread-display_name = ls_hunk_info_cur-display_name.
        ls_thread-hunk_no      = ls_hunk_info_cur-hunk_no.
        ls_thread-start_line   = ls_hunk_info_cur-start_line.
        ls_thread-change_count = ls_hunk_info_cur-change_count.
        ls_thread-html         = ls_hunk_info_cur-html.
      ENDIF.
      INSERT ls_thread INTO TABLE mt_hunk_threads.
    ENDLOOP.

    READ TABLE ls_payload-user_states INTO DATA(ls_user_state)
      WITH KEY reviewer = sy-uname.
    IF sy-subrc = 0.
      LOOP AT ls_user_state-approved INTO DATA(ls_approved_key).
        INSERT ls_approved_key-hunk_key INTO TABLE mt_approved.
      ENDLOOP.
      LOOP AT ls_user_state-declined INTO DATA(ls_declined_key).
        INSERT ls_declined_key-hunk_key INTO TABLE mt_declined.
      ENDLOOP.
      LOOP AT ls_user_state-notes INTO DATA(ls_saved_note).
        INSERT VALUE ty_decline_note(
          hunk_key = ls_saved_note-hunk_key
          note     = ls_saved_note-note ) INTO TABLE mt_decline_notes.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
  METHOD render_decline_thread_html.
    READ TABLE mt_hunk_threads INTO DATA(ls_thread)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    IF sy-subrc <> 0.
      READ TABLE mt_decline_notes INTO DATA(ls_note)
        WITH TABLE KEY hunk_key = iv_hunk_key.
      IF sy-subrc = 0 AND ls_note-note IS NOT INITIAL.
        DATA(lv_note_esc) = ls_note-note.
        REPLACE ALL OCCURRENCES OF `&` IN lv_note_esc WITH `&amp;`.
        REPLACE ALL OCCURRENCES OF `<` IN lv_note_esc WITH `&lt;`.
        REPLACE ALL OCCURRENCES OF `>` IN lv_note_esc WITH `&gt;`.
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_note_esc WITH `<br>`.
        DATA(lv_note_bg) = COND string(
          WHEN line_exists( mt_declined[ table_line = iv_hunk_key ] ) THEN `#fff1f4`
          ELSE `#f3f9ff` ).
        DATA(lv_note_border) = COND string(
          WHEN line_exists( mt_declined[ table_line = iv_hunk_key ] ) THEN `#efb8c8`
          ELSE `#a8cde8` ).
        DATA(lv_note_text) = COND string(
          WHEN line_exists( mt_declined[ table_line = iv_hunk_key ] ) THEN `#9f3b57`
          ELSE `#2874a6` ).
        result =
          `<tr><td class="ln">&nbsp;</td><td class="cd" style="padding:6px 12px">` &&
          `<div style="display:inline-block;background:` && lv_note_bg &&
          `;border:1px solid ` && lv_note_border &&
          `;padding:5px 9px;color:` && lv_note_text &&
          `;font-size:11px;line-height:15px;font-style:italic">` &&
          lv_note_esc && `</div></td></tr>`.
      ENDIF.
      RETURN.
    ENDIF.

    LOOP AT ls_thread-messages INTO DATA(ls_msg).
      DATA(lv_author_esc) = escape( val = CONV string( ls_msg-author ) format = cl_abap_format=>e_html_text ).
      DATA(lv_author_name_esc) = escape( val = CONV string( ls_msg-author_name ) format = cl_abap_format=>e_html_text ).
      DATA(lv_created_at_txt) = |{ ls_msg-created_at TIMESTAMP = USER }|.
      FIND FIRST OCCURRENCE OF `,` IN lv_created_at_txt MATCH OFFSET DATA(lv_ts_sep1).
      IF sy-subrc = 0.
        lv_created_at_txt = lv_created_at_txt(lv_ts_sep1).
      ENDIF.
      DATA(lv_text_esc) = escape( val = ls_msg-text format = cl_abap_format=>e_html_text ).
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_text_esc WITH `<br>`.
      DATA(lv_note_bg_msg) = COND string(
        WHEN ls_msg-is_decline = abap_true THEN `#fff1f4`
        ELSE `#f3f9ff` ).
      DATA(lv_note_border_msg) = COND string(
        WHEN ls_msg-is_decline = abap_true THEN `#efb8c8`
        ELSE `#a8cde8` ).
      DATA(lv_note_text_msg) = COND string(
        WHEN ls_msg-is_decline = abap_true THEN `#9f3b57`
        ELSE `#2874a6` ).
      result = result &&
        `<tr><td class="ln">&nbsp;</td><td class="cd" style="padding:6px 12px">` &&
        `<div style="display:inline-block;margin:0 0 6px 0;background:` && lv_note_bg_msg &&
        `;border:1px solid ` && lv_note_border_msg && `;padding:6px 9px;max-width:900px">` &&
        `<div style="font-size:10px;color:#6f7f8f;font-weight:bold;margin-bottom:3px">` &&
        lv_author_esc && ` / ` && lv_author_name_esc &&
        ` <span style="font-weight:normal;color:#8a96a3">/ ` &&
        escape( val = lv_created_at_txt format = cl_abap_format=>e_html_text ) &&
        `</span></div>` &&
        `<div style="font-size:11px;line-height:15px;color:` && lv_note_text_msg &&
        `;font-style:italic">` &&
        lv_text_esc && `</div></div></td></tr>`.
    ENDLOOP.
  ENDMETHOD.
  METHOD render_hunk_actions_html.
    DATA(lv_status_html) = ``.
    DATA(lv_actions_html) = ``.

    IF line_exists( mt_approved[ table_line = iv_hunk_key ] ).
      lv_status_html =
        `<span style="color:#27ae60;font-weight:bold">&#10003; approved</span>`.
      lv_actions_html =
        |<a href="sapevent:undo~{ iv_hunk_key }"| &&
        ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
        `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Undo</a>` &&
        |<a href="sapevent:addcomment~{ iv_hunk_key }"| &&
        ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
        `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Add Comment</a>`.
    ELSEIF line_exists( mt_declined[ table_line = iv_hunk_key ] ).
      lv_status_html =
        `<span style="color:#e74c3c;font-weight:bold">&#10007; declined</span>`.
      lv_actions_html =
        |<a href="sapevent:undo~{ iv_hunk_key }"| &&
        ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
        `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Undo</a>` &&
        |<a href="sapevent:approve~{ iv_hunk_key }"| &&
        ` style="margin-left:4px;background:#27ae60;color:#fff;font-weight:bold;` &&
        `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">&#10003; Approve</a>` &&
        |<a href="sapevent:addcomment~{ iv_hunk_key }"| &&
        ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
        `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Add Comment</a>`.
    ELSE.
      lv_status_html =
        `<span style="color:#7f8c8d;font-weight:bold">&#9675; open</span>`.
      lv_actions_html =
        |<a href="sapevent:approve~{ iv_hunk_key }"| &&
        ` style="margin-left:8px;background:#27ae60;color:#fff;font-weight:bold;` &&
        `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">&#10003; Approve</a>` &&
        |<a href="sapevent:decline~{ iv_hunk_key }"| &&
        ` style="margin-left:4px;background:#922b21;color:#fff;font-weight:bold;` &&
        `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">&#10007; Decline</a>` &&
        |<a href="sapevent:addcomment~{ iv_hunk_key }"| &&
        ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
        `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Add Comment</a>`.
    ENDIF.

    result =
      `<div style="display:flex;align-items:center;gap:0;margin:2px 0 8px 0">` &&
      lv_status_html && lv_actions_html && `</div>`.
  ENDMETHOD.
  METHOD save_review_to_db.
    DATA lv_saved_at TYPE timestampl.
    DATA lv_tabname TYPE tabname VALUE 'ZAVE_REVIEW'.
    DATA lr_review_db TYPE REF TO data.

    CHECK mv_code_review = abap_true.
    CHECK mv_object_type = zcl_ave_object_factory=>gc_type-tr.

    DATA(ls_payload) = VALUE ty_saved_payload( ).
    DATA(lv_has_existing) = load_review_payload(
      EXPORTING iv_trkorr = CONV #( mv_object_name )
      IMPORTING es_payload = ls_payload ).

    GET TIME STAMP FIELD lv_saved_at.
    DATA(lv_user_name) = zcl_ave_popup_data=>get_user_name( sy-uname ).

    DATA(ls_user_state_new) = VALUE ty_saved_user_state(
      reviewer      = sy-uname
      reviewer_name = lv_user_name
      saved_at      = lv_saved_at ).

    LOOP AT mt_approved INTO DATA(lv_approved_key).
      APPEND VALUE ty_saved_key( hunk_key = lv_approved_key ) TO ls_user_state_new-approved.
    ENDLOOP.
    LOOP AT mt_declined INTO DATA(lv_declined_key).
      APPEND VALUE ty_saved_key( hunk_key = lv_declined_key ) TO ls_user_state_new-declined.
    ENDLOOP.
    LOOP AT mt_decline_notes INTO DATA(ls_note_cur).
      APPEND VALUE ty_saved_note(
        hunk_key = ls_note_cur-hunk_key
        note     = ls_note_cur-note ) TO ls_user_state_new-notes.
    ENDLOOP.

    ls_payload-schema_version = 1.
    ls_payload-trkorr = CONV #( mv_object_name ).
    ls_payload-last_saved_at = lv_saved_at.
    ls_payload-last_saved_by = sy-uname.

    DELETE ls_payload-user_states WHERE reviewer = sy-uname.
    APPEND ls_user_state_new TO ls_payload-user_states.

    LOOP AT mt_hunk_threads INTO DATA(ls_thread_cur).
      DATA(ls_thread_to_save) = VALUE ty_saved_thread(
        hunk_key     = ls_thread_cur-hunk_key
        objtype      = ls_thread_cur-objtype
        obj_name     = ls_thread_cur-obj_name
        class_name   = ls_thread_cur-class_name
        display_name = ls_thread_cur-display_name
        hunk_no      = ls_thread_cur-hunk_no
        start_line   = ls_thread_cur-start_line
        change_count = ls_thread_cur-change_count
        messages     = ls_thread_cur-messages ).

      READ TABLE ls_payload-threads ASSIGNING FIELD-SYMBOL(<ls_thread_saved>)
        WITH KEY hunk_key = ls_thread_cur-hunk_key.
      IF sy-subrc <> 0.
        APPEND ls_thread_to_save TO ls_payload-threads.
        CONTINUE.
      ENDIF.

      <ls_thread_saved>-objtype      = ls_thread_to_save-objtype.
      <ls_thread_saved>-obj_name     = ls_thread_to_save-obj_name.
      <ls_thread_saved>-class_name   = ls_thread_to_save-class_name.
      <ls_thread_saved>-display_name = ls_thread_to_save-display_name.
      <ls_thread_saved>-hunk_no      = ls_thread_to_save-hunk_no.
      <ls_thread_saved>-start_line   = ls_thread_to_save-start_line.
      <ls_thread_saved>-change_count = ls_thread_to_save-change_count.

      LOOP AT ls_thread_cur-messages INTO DATA(ls_msg_cur).
        READ TABLE <ls_thread_saved>-messages TRANSPORTING NO FIELDS
          WITH KEY author = ls_msg_cur-author
                   created_at = ls_msg_cur-created_at
                   text = ls_msg_cur-text.
        IF sy-subrc <> 0.
          APPEND ls_msg_cur TO <ls_thread_saved>-messages.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    APPEND VALUE ty_saved_history(
      saved_at       = lv_saved_at
      saved_by       = sy-uname
      saved_by_name  = lv_user_name
      approved_count = lines( mt_approved )
      declined_count = lines( mt_declined )
      note_count     = lines( mt_decline_notes ) ) TO ls_payload-history.

    DATA(lv_payload_json) = /ui2/cl_json=>serialize( data = ls_payload ).
    TRY.
        CREATE DATA lr_review_db TYPE (lv_tabname).
        ASSIGN lr_review_db->* TO FIELD-SYMBOL(<ls_review_db>).
        IF <ls_review_db> IS ASSIGNED.
          ASSIGN COMPONENT 'TRKORR' OF STRUCTURE <ls_review_db> TO FIELD-SYMBOL(<lv_trkorr>).
          ASSIGN COMPONENT 'PAYLOAD' OF STRUCTURE <ls_review_db> TO FIELD-SYMBOL(<lv_payload>).
          IF <lv_trkorr> IS ASSIGNED AND <lv_payload> IS ASSIGNED.
            <lv_trkorr> = CONV trkorr( mv_object_name ).
            <lv_payload> = lv_payload_json.
            MODIFY (lv_tabname) FROM @<ls_review_db>.
          ELSE.
            sy-subrc = 4.
          ENDIF.
        ELSE.
          sy-subrc = 4.
        ENDIF.
      CATCH cx_sy_create_data_error
            cx_sy_dynamic_osql_semantics
            cx_sy_dynamic_osql_syntax
            cx_sy_open_sql_db.
        sy-subrc = 4.
    ENDTRY.

    IF sy-subrc = 0.
      MESSAGE |Review saved for { mv_object_name }| TYPE 'S'.
    ELSEIF lv_has_existing = abap_true.
      MESSAGE |Review for { mv_object_name } could not be updated| TYPE 'E'.
    ELSE.
      MESSAGE |Review for { mv_object_name } could not be created| TYPE 'E'.
    ENDIF.
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
        DATA(lt_cr_parts) = lo_obj->get_parts( ).
        DATA(lv_cr_total) = lines( lt_cr_parts ).
        LOOP AT lt_cr_parts INTO DATA(ls_part).
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = CONV i( sy-tabix * 100 / COND i( WHEN lv_cr_total > 0 THEN lv_cr_total ELSE 1 ) )
                      text       = CONV char70( |Code Review: precomputing part { sy-tabix }/{ lv_cr_total }| ).
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

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING percentage = 0
                text       = CONV char70( |Code Review: loading versions for { is_part-object_name }| ).

    " Use load_versions — same as Version Explorer — fills mt_versions with
    " correct obj_owner (nearest-task logic), trfunction, datum, zeit.
    load_versions( i_objtype = is_part-type i_objname = is_part-object_name ).
    CHECK mt_versions IS NOT INITIAL.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING percentage = 20
                text       = CONV char70( |Code Review: locating TR version for { is_part-object_name }| ).

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

    " Filter by user: check both the version author and the task owner (obj_owner).
    " obj_owner is the developer who locked the object in the task — the real "author"
    " from a code review perspective. author is who triggered the version save (often CI).
    IF mv_filter_user IS NOT INITIAL.
      DATA(lv_effective_author) = COND versuser(
        WHEN ls_new-obj_owner IS NOT INITIAL THEN ls_new-obj_owner
        ELSE ls_new-author ).
      IF lv_effective_author <> mv_filter_user.
        RETURN.
      ENDIF.
    ENDIF.

    CLEAR ls_old.
    LOOP AT mt_versions INTO ls_old FROM lv_idx + 1 WHERE trfunction = 'K'.
      EXIT.
    ENDLOOP.
    DATA(lv_is_created) = COND abap_bool( WHEN ls_old IS INITIAL THEN abap_true ELSE abap_false ).

    DATA(lv_versno_new) = ls_new-versno.
    DATA(lv_versno_old) = ls_old-versno.

    TRY.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 30
                    text       = CONV char70( |Code Review: loading new source for { is_part-object_name }| ).
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
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 40
                      text       = CONV char70( |Code Review: loading old source for { is_part-object_name }| ).

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

        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 50
                    text       = CONV char70( |Code Review: computing diff for { is_part-object_name }| ).

        DATA(lt_diff) = zcl_ave_popup_diff=>compute_diff(
          it_old        = lt_src_o
          it_new        = lt_src_n
          i_title       = CONV #( is_part-object_name )
          i_ignore_case = mv_ignore_case ).

        " Blame — pass mt_versions directly, same as show_versions_diff
        DATA lt_blame         TYPE ty_blame_map.
        DATA lt_blame_deleted TYPE ty_blame_map.
        IF mv_blame = abap_true AND lines( lt_src_o ) <= 1000 AND lines( lt_src_n ) <= 1000.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 65
                      text       = CONV char70( |Code Review: computing blame for { is_part-object_name }| ).

          lt_blame = zcl_ave_popup_diff=>build_blame_map(
            EXPORTING it_versions      = mt_versions
                      i_objtype        = is_part-type
                      i_objname        = is_part-object_name
                      i_from           = lv_versno_old
                      i_to             = lv_versno_new
            IMPORTING et_blame_deleted = lt_blame_deleted ).
        ELSEIF mv_blame = abap_true.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 65
                      text       = CONV char70( |Code Review: skipping blame for large source { is_part-object_name }| ).
        ENDIF.

        " Render HTML — same as show_versions_diff
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 75
                    text       = CONV char70( |Code Review: rendering diff for { is_part-object_name }| ).

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

        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 85
                    text       = CONV char70( |Code Review: collecting hunks for { is_part-object_name }| ).

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

        " Owner and date/time — taken from ls_new (already enriched by load_versions).
        " Brand-new objects belong to the creator: owner of the first version.
        DATA(lv_author) = COND versuser(
          WHEN lv_is_created = abap_true AND mv_cur_creator IS NOT INITIAL
          THEN mv_cur_creator
          WHEN lv_is_created = abap_true AND mt_versions IS NOT INITIAL AND mt_versions[ lines( mt_versions ) ]-obj_owner IS NOT INITIAL
          THEN mt_versions[ lines( mt_versions ) ]-obj_owner
          WHEN lv_is_created = abap_true AND mt_versions IS NOT INITIAL
          THEN mt_versions[ lines( mt_versions ) ]-author
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
                    WHEN lv_is_created = abap_true THEN lv_author
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
            WHEN lv_is_created = abap_true THEN lv_author
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

        IF lv_is_created = abap_true.
          CLEAR lt_auth.
          APPEND VALUE zif_ave_acr_types=>ty_author_stats(
            author      = lv_author
            author_name = zcl_ave_popup_data=>get_user_name( lv_author )
            ins_count   = lv_ins
            del_count   = lv_del
            mod_count   = lv_mod
            hunk_count  = lv_hunk_cnt ) TO lt_auth.
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
        DATA(lv_note_html) = render_decline_thread_html( lv_ck ).
        IF line_exists( mt_approved[ table_line = lv_ck ] ).
          lv_ins = |<a id="acr_c{ lv_n }"></a> ──| &&
                   `<span style="margin-left:10px;color:#27ae60;` &&
                   `font-style:normal;font-size:12px;font-weight:bold">&#10003; approved</span>` &&
                   |<a href="sapevent:undo~{ lv_ck }"| &&
                   ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;` &&
                   `border-radius:3px;padding:2px 7px">Undo</a>` &&
                   |<a href="sapevent:addcomment~{ lv_ck }"| &&
                   ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;` &&
                   `border-radius:3px;padding:2px 7px">Add Comment</a></td>` &&
                   lv_note_html.
        ELSEIF line_exists( mt_declined[ table_line = lv_ck ] ).
          lv_ins = |<a id="acr_c{ lv_n }"></a> ──| &&
                   `<span style="margin-left:10px;color:#e74c3c;` &&
                   `font-style:normal;font-size:12px;font-weight:bold">&#10007; declined</span>` &&
                   |<a href="sapevent:undo~{ lv_ck }"| &&
                   ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;` &&
                   `border-radius:3px;padding:2px 7px">Undo</a>` &&
                   |<a href="sapevent:addcomment~{ lv_ck }"| &&
                   ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;` &&
                   `border-radius:3px;padding:2px 7px">Add Comment</a></td>` &&
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
                   `border-radius:3px;padding:2px 7px">&#10007; decline</a>` &&
                   |<a href="sapevent:addcomment~{ lv_ck }"| &&
                   ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
                   `text-decoration:none;font-style:normal;font-size:11px;` &&
                   `border-radius:3px;padding:2px 7px">Add Comment</a></td>` &&
                   lv_note_html.
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
               `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Undo</a>` &&
               |<a href="sapevent:addcomment~{ iv_key }"| &&
               ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
               `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Add Comment</a></td>`.
    ELSEIF line_exists( mt_declined[ table_line = iv_key ] ).
      result = `<td class="cd" style="color:#e74c3c;font-weight:bold">` &&
               `&#10007;&nbsp;declined` &&
               |<a href="sapevent:undo~{ iv_key }"| &&
               ` style="margin-left:8px;background:#95a5a6;color:#fff;font-weight:bold;` &&
               `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Undo</a>` &&
               |<a href="sapevent:addcomment~{ iv_key }"| &&
               ` style="margin-left:4px;background:#3498db;color:#fff;font-weight:bold;` &&
               `text-decoration:none;font-size:11px;border-radius:3px;padding:2px 7px">Add Comment</a></td>`.
    ELSE.
      result = |<td class="cd">...| &&
               |<a href="sapevent:approve~{ iv_key }"| &&
               | style="margin-left:12px;background:#27ae60;color:#fff;| &&
               |font-size:11px;font-weight:bold;text-decoration:none;| &&
               |border-radius:3px;padding:2px 7px">&#10003;&nbsp;approve</a>| &&
               |<a href="sapevent:decline~{ iv_key }"| &&
               | style="margin-left:8px;background:#922b21;color:#fff;| &&
               |font-size:11px;font-weight:bold;text-decoration:none;| &&
               |border-radius:3px;padding:2px 7px">&#10007;&nbsp;decline</a>| &&
               |<a href="sapevent:addcomment~{ iv_key }"| &&
               | style="margin-left:4px;background:#3498db;color:#fff;| &&
               |font-size:11px;font-weight:bold;text-decoration:none;| &&
               |border-radius:3px;padding:2px 7px">Add Comment</a></td>|.
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
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">Undo</a>` &&
        |<a href="sapevent:addcomment~{ iv_key }"| &&
        ` style="background:#3498db;color:#fff;padding:4px 10px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">Add Comment</a></div>`.
    ELSEIF line_exists( mt_declined[ table_line = iv_key ] ).
      result =
        `<div style="position:fixed;top:8px;right:12px;z-index:999;display:flex;gap:6px;align-items:center">` &&
        `<span style="background:#e74c3c;color:#fff;padding:4px 14px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif">&#10007;&nbsp;Declined</span>` &&
        |<a href="sapevent:undo~{ iv_key }"| &&
        ` style="background:#95a5a6;color:#fff;padding:4px 10px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">Undo</a>` &&
        |<a href="sapevent:addcomment~{ iv_key }"| &&
        ` style="background:#3498db;color:#fff;padding:4px 10px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">Add Comment</a></div>`.
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
        `&#10007;&nbsp;Decline</a>` &&
        |<a href="sapevent:addcomment~{ iv_key }"| &&
        ` style="background:#3498db;color:#fff;padding:4px 10px;` &&
        `border-radius:4px;font:bold 12px Consolas,sans-serif;text-decoration:none">Add Comment</a></div>`.
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
    DATA lv_scroll_txt TYPE string.
    IF lv_cmd = 'openuserdeclined'.
      DATA lv_scroll_sep TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rest MATCH OFFSET lv_scroll_sep.
      IF sy-subrc = 0.
        DATA(lv_tail_start) = lv_scroll_sep + 1.
        DATA(lv_tail) = lv_rest+lv_tail_start.
        IF lv_tail CN '0123456789~'.
          " payload contains another component before the scroll value
        ELSEIF lv_tail CA '~'.
          " keep command-specific parsing below
        ELSEIF lv_tail IS NOT INITIAL.
          lv_scroll_txt = lv_tail.
          lv_rest = lv_rest(lv_scroll_sep).
        ENDIF.
      ENDIF.
    ENDIF.

    IF lv_cmd = 'back'.
      back_to_report( ).
      RETURN.

    ELSEIF lv_cmd = 'prepare'.
      prepare_code_review( ).
      RETURN.

    ELSEIF lv_cmd = 'openobj'.
      " lv_rest = TYPE~OBJNAME~SCROLLY  (TYPE always 4 chars, SCROLLY optional trailing digits)
      DATA lv_oo_rest TYPE string.
      lv_oo_rest = lv_rest.
      DATA(lv_rev2) = reverse( lv_oo_rest ).
      DATA lv_tilde2 TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rev2 MATCH OFFSET lv_tilde2.
      IF sy-subrc = 0.
        DATA(lv_scand_start) = strlen( lv_oo_rest ) - lv_tilde2.
        DATA(lv_scand) = lv_oo_rest+lv_scand_start.
        IF lv_scand IS NOT INITIAL AND lv_scand CO '0123456789'.
          mv_cr_report_scroll = CONV i( lv_scand ).
          DATA(lv_oo_rest_len) = lv_scand_start - 1.
          IF lv_oo_rest_len >= 0.
            lv_oo_rest = lv_oo_rest(lv_oo_rest_len).
          ENDIF.
        ENDIF.
      ENDIF.
      " TYPE is always 4 chars
      DATA lv_oo_type TYPE versobjtyp.
      DATA lv_oo_name TYPE versobjnam.
      IF strlen( lv_oo_rest ) > 5 AND lv_oo_rest+4(1) = '~'.
        lv_oo_type = lv_oo_rest(4).
        lv_oo_name = lv_oo_rest+5.
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

    ELSEIF lv_cmd = 'addcomment' OR lv_cmd = 'editreview'.
      " Open note dialog with empty text for adding a new comment
      DATA lv_er_key TYPE string.
      lv_er_key = lv_rest.
      CLEAR mv_pending_decline.
      mo_note_dlg = NEW zcl_ave_acr_note_dlg(
        iv_title    = lv_er_key
        iv_hunk_key = lv_er_key
        iv_note     = `` ).
      SET HANDLER on_note_dlg_saved FOR mo_note_dlg.
      SET HANDLER on_note_dlg_cancelled FOR mo_note_dlg.
      mo_note_dlg->show( ).
      RETURN.

    ELSEIF lv_cmd = 'undo'.
      DATA lv_undo_key TYPE string.
      lv_undo_key = lv_rest.
      DELETE TABLE mt_approved FROM lv_undo_key.
      DELETE TABLE mt_declined FROM lv_undo_key.
      DELETE TABLE mt_decline_notes WITH TABLE KEY hunk_key = lv_undo_key.
      IF mv_decline_view_user IS NOT INITIAL.
        show_user_declines( iv_user = mv_decline_view_user ).
      ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
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
        " Open note dialog — decline is registered only when user clicks Save with a comment
        READ TABLE mt_decline_notes INTO DATA(ls_dn_exist) WITH TABLE KEY hunk_key = lv_key.
        DATA lv_prev_note TYPE string.
        IF sy-subrc = 0. lv_prev_note = ls_dn_exist-note. ENDIF.
        mv_pending_decline = lv_key.
        mo_note_dlg = NEW zcl_ave_acr_note_dlg(
          iv_title    = lv_key
          iv_hunk_key = lv_key
          iv_note     = lv_prev_note ).
        SET HANDLER on_note_dlg_saved FOR mo_note_dlg.
        SET HANDLER on_note_dlg_cancelled FOR mo_note_dlg.
        mo_note_dlg->show( ).
        RETURN.  " Decline will be registered in on_note_dlg_saved event
      ENDIF.

      IF mv_decline_view_user IS NOT INITIAL.
        show_user_declines( iv_user = mv_decline_view_user ).
        regen_acr_report( ).
        refresh_rpt_row( ).
        RETURN.
      ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
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
    IF mv_decline_view_user IS NOT INITIAL.
      show_user_declines( iv_user = mv_decline_view_user ).
    ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
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
    CLEAR mv_decline_view_user.
    maximize_html( ).
    DATA(lv_html) = mv_cr_report_html.
    " Scroll to the last opened object row by anchor
    IF mv_cr_cur_key IS NOT INITIAL.
      DATA(lv_anchor) = |obj_{ escape( val = mv_cr_cur_key format = cl_abap_format=>e_html_attr ) }|.
      DATA(lv_script) =
        `<script>window.onload=function(){` &&
        `var e=document.getElementById('` && lv_anchor && `');` &&
        `if(e)e.scrollIntoView(true);}` &&
        `</script></head>`.
      lv_html = replace( val = lv_html sub = `</head>` with = lv_script ).
    ENDIF.
    set_html( lv_html ).
  ENDMETHOD.
  METHOD show_user_declines.
    mv_decline_view_user = iv_user.
    DATA(lv_user_name) = zcl_ave_popup_data=>get_user_name( iv_user ).

    " Collect all hunks authored by this user
    DATA lt_hunks TYPE STANDARD TABLE OF ty_hunk_info WITH DEFAULT KEY.
    LOOP AT mt_hunk_info INTO DATA(ls_hi) WHERE author = iv_user.
      APPEND ls_hi TO lt_hunks.
    ENDLOOP.
    SORT lt_hunks BY class_name objtype obj_name hunk_no.

    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:42px 28px 20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `.objhdr{margin:18px 0 8px 0;background:#dbe9ff;color:#2c3e50;padding:5px 10px;` &&
      `font-weight:bold;white-space:nowrap}` &&
      `.block{margin:0 0 14px 0}` &&
      `.comments{display:block;width:100%;margin:0 0 8px 0}` &&
      `.codewrap{display:block;clear:both;width:100%;margin:0;padding:0}` &&
      `.blame{margin:0 0 6px 0;color:#5e6a75;font-style:italic;white-space:nowrap}` &&
      `.blkinfo{margin:5px 0 2px 0;color:#2c3e50;font-weight:bold;white-space:nowrap}` &&
      `.muted{color:#777;font-weight:normal}` &&
      `.meta{display:block;margin:0 0 4px 0;color:#7f8c99;font-size:10px;font-weight:normal}` &&
      `.note{display:table;margin:6px 0 6px 0;padding:5px 9px;background:#f3f9ff;` &&
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
      |<h2>Review: { escape( val = CONV string( iv_user ) format = cl_abap_format=>e_html_text ) }| &&
      | / { escape( val = CONV string( lv_user_name ) format = cl_abap_format=>e_html_text ) }</h2>|.

    IF lt_hunks IS INITIAL.
      lv_html = lv_html &&
        |<p style="color:#888">No changed blocks found for this owner.</p>| &&
        |</body></html>|.
      maximize_html( ).
      set_html( lv_html ).
      RETURN.
    ENDIF.

    DATA lv_cur_obj TYPE string VALUE `####`.
    LOOP AT lt_hunks INTO DATA(ls_hunk).
      DATA(lv_obj_key) = |{ ls_hunk-objtype }~{ ls_hunk-obj_name }|.

      " Object header
      IF lv_obj_key <> lv_cur_obj.
        lv_cur_obj = lv_obj_key.
        DATA(lv_title) = COND string(
          WHEN ls_hunk-class_name IS NOT INITIAL AND ls_hunk-display_name IS NOT INITIAL
          THEN |{ ls_hunk-class_name }=>{ ls_hunk-display_name }|
          WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
          ELSE CONV string( ls_hunk-obj_name ) ).
        DATA lv_obj_blocks  TYPE i.
        DATA lv_obj_changes TYPE i.
        CLEAR: lv_obj_blocks, lv_obj_changes.
        LOOP AT lt_hunks INTO DATA(ls_s) WHERE objtype = ls_hunk-objtype AND obj_name = ls_hunk-obj_name.
          lv_obj_blocks  += 1.
          lv_obj_changes += ls_s-change_count.
        ENDLOOP.
        lv_html = lv_html &&
          |<div class="objhdr">| &&
          |<a href="sapevent:openobj~{ lv_obj_key }" style="color:inherit;text-decoration:none">| &&
          |{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
          |{ escape( val = lv_title format = cl_abap_format=>e_html_text ) }</a>| &&
          | <span class="muted">blocks</span> { lv_obj_blocks }| &&
          | <span class="muted">changes</span> { lv_obj_changes } lines</div>|.
      ENDIF.

      " Hunk diff HTML (same cleanup as before)
      DATA(lv_clean_html) = ls_hunk-html.
      DATA lv_mark_pos TYPE i.
      DATA lv_before_mark TYPE string.
      DATA lv_after_mark TYPE string.
      DATA lv_tr_start TYPE i.
      DATA lv_tr_end_rel TYPE i.
      DATA lv_tr_end TYPE i.
      DATA lv_rev_before TYPE string.
      DATA lv_rev_pos TYPE i.
      WHILE lv_clean_html CS `──</td>`.
        lv_mark_pos = sy-fdpos.
        lv_before_mark = lv_clean_html(lv_mark_pos).
        lv_after_mark = lv_clean_html+lv_mark_pos.
        lv_rev_before = reverse( lv_before_mark ).
        FIND FIRST OCCURRENCE OF `rt<` IN lv_rev_before MATCH OFFSET lv_rev_pos.
        IF sy-subrc <> 0. EXIT. ENDIF.
        lv_tr_start = strlen( lv_before_mark ) - lv_rev_pos - 3.
        FIND FIRST OCCURRENCE OF `</tr>` IN lv_after_mark MATCH OFFSET lv_tr_end_rel.
        IF sy-subrc <> 0. EXIT. ENDIF.
        lv_tr_end = lv_mark_pos + lv_tr_end_rel + 5.
        IF lv_tr_start < 0 OR lv_tr_end <= lv_tr_start. EXIT. ENDIF.
        lv_clean_html = lv_clean_html(lv_tr_start) && lv_clean_html+lv_tr_end.
      ENDWHILE.
      IF lv_clean_html CS `<td class="sep"></td>`.
        DATA(lv_rows_html) = lv_clean_html.
        DATA(lv_norm_html) = ``.
        DATA lv_row_start TYPE i.
        DATA lv_row_close_rel TYPE i.
        DATA lv_row_close TYPE i.
        DATA lv_row_len TYPE i.
        DATA lv_row_html TYPE string.
        DATA lv_gt_pos TYPE i.
        DATA lv_sep_pos TYPE i.
        DATA lv_body_left TYPE string.
        DATA lv_body_right TYPE string.
        DATA lv_plain_left TYPE string.
        DATA lv_plain_right TYPE string.
        WHILE lv_rows_html CS `<tr`.
          lv_row_start = sy-fdpos.
          IF lv_row_start > 0.
            lv_norm_html = lv_norm_html && lv_rows_html(lv_row_start).
            lv_rows_html = lv_rows_html+lv_row_start.
          ENDIF.
          FIND FIRST OCCURRENCE OF `</tr>` IN lv_rows_html MATCH OFFSET lv_row_close_rel.
          IF sy-subrc <> 0.
            lv_norm_html = lv_norm_html && lv_rows_html.
            CLEAR lv_rows_html.
            EXIT.
          ENDIF.
          lv_row_close = lv_row_close_rel + 5.
          lv_row_html = lv_rows_html(lv_row_close).
          lv_rows_html = lv_rows_html+lv_row_close.
          IF lv_row_html CS `<td class="sep"></td>`.
            FIND FIRST OCCURRENCE OF `>` IN lv_row_html MATCH OFFSET lv_gt_pos.
            FIND FIRST OCCURRENCE OF `<td class="sep"></td>` IN lv_row_html MATCH OFFSET lv_sep_pos.
            IF sy-subrc = 0 AND lv_gt_pos >= 0 AND lv_sep_pos > lv_gt_pos.
              DATA(lv_body_left_off)  = lv_gt_pos + 1.
              DATA(lv_body_left_len)  = lv_sep_pos - lv_gt_pos - 1.
              DATA(lv_body_right_off) = lv_sep_pos + 21.
              DATA(lv_row_prefix_len) = lv_gt_pos + 1.
              lv_body_left  = lv_row_html+lv_body_left_off(lv_body_left_len).
              lv_body_right = lv_row_html+lv_body_right_off.
              lv_row_len = strlen( lv_body_right ).
              IF lv_row_len >= 5.
                DATA(lv_body_right_len) = lv_row_len - 5.
                lv_body_right = lv_body_right(lv_body_right_len).
              ENDIF.
              lv_plain_left  = lv_body_left.
              lv_plain_right = lv_body_right.
              REPLACE ALL OCCURRENCES OF REGEX `<[^>]+>` IN lv_plain_left  WITH ``.
              REPLACE ALL OCCURRENCES OF REGEX `<[^>]+>` IN lv_plain_right WITH ``.
              CONDENSE lv_plain_left  NO-GAPS.
              CONDENSE lv_plain_right NO-GAPS.
              lv_norm_html = lv_norm_html &&
                lv_row_html(lv_row_prefix_len) &&
                COND string(
                  WHEN strlen( lv_plain_right ) >= strlen( lv_plain_left )
                  THEN lv_body_right ELSE lv_body_left ) &&
                `</tr>`.
            ELSE.
              lv_norm_html = lv_norm_html && lv_row_html.
            ENDIF.
          ELSE.
            lv_norm_html = lv_norm_html && lv_row_html.
          ENDIF.
        ENDWHILE.
        lv_clean_html = lv_norm_html && lv_rows_html.
      ENDIF.
      DATA(lv_code_html) = COND string(
        WHEN lv_clean_html IS NOT INITIAL
        THEN |<table class="diff"><tbody>{ lv_clean_html }</tbody></table>|
        ELSE `<div style="color:#888;margin:4px 0 10px">Diff not available.</div>` ).

      " Approved/declined status
      DATA(lv_status_html) = ``.
      IF line_exists( mt_approved[ table_line = ls_hunk-hunk_key ] ).
        lv_status_html = `<span style="color:#27ae60;font-weight:bold">&#10003; Approved</span> `.
      ELSEIF line_exists( mt_declined[ table_line = ls_hunk-hunk_key ] ).
        lv_status_html = `<span style="color:#e74c3c;font-weight:bold">&#10007; Declined</span> `.
      ENDIF.

      lv_html = lv_html &&
        `<div class="block">` &&
        |<div class="blkinfo">{ lv_status_html }Block #{ ls_hunk-hunk_no }| &&
        | <span class="muted">line</span> { ls_hunk-start_line }| &&
        | <span class="muted">changes</span> { ls_hunk-change_count }</div>|.

      " Comments for this hunk
      DATA(lv_comments_html) = ``.
      READ TABLE mt_hunk_threads INTO DATA(ls_thread) WITH KEY hunk_key = ls_hunk-hunk_key.
      IF sy-subrc = 0.
        LOOP AT ls_thread-messages INTO DATA(ls_msg).
          CHECK ls_msg-text IS NOT INITIAL.
          DATA(lv_note_esc) = escape( val = ls_msg-text format = cl_abap_format=>e_html_text ).
          REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_note_esc WITH `<br>`.
          DATA(lv_created_at_txt) = |{ ls_msg-created_at TIMESTAMP = USER }|.
          FIND FIRST OCCURRENCE OF `,` IN lv_created_at_txt MATCH OFFSET DATA(lv_ts_sep).
          IF sy-subrc = 0. lv_created_at_txt = lv_created_at_txt(lv_ts_sep). ENDIF.
          DATA(lv_note_style) = COND string(
            WHEN ls_msg-is_decline = abap_true
            THEN ` style="background:#fff1f4;border-color:#efb8c8;color:#9f3b57"`
            ELSE `` ).
          lv_comments_html = lv_comments_html &&
            |<span class="meta">{ escape( val = CONV string( ls_msg-author ) format = cl_abap_format=>e_html_text ) }| &&
            | / { escape( val = CONV string( ls_msg-author_name ) format = cl_abap_format=>e_html_text ) }| &&
            | / { escape( val = lv_created_at_txt format = cl_abap_format=>e_html_text ) }</span>| &&
            |<div class="note"{ lv_note_style }>{ lv_note_esc }</div>|.
        ENDLOOP.
      ENDIF.
      IF lv_comments_html IS NOT INITIAL.
        lv_html = lv_html && |<div class="comments">{ lv_comments_html }</div>|.
      ENDIF.

      lv_html = lv_html &&
        `<div class="codewrap">` &&
        lv_code_html &&
        `</div></div>`.
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
    IF sy-subrc <> 0.
      LOOP AT mt_diff_cache INTO ls_ch
        WHERE key-objtype  = ls_stat-objtype
          AND key-objname  = ls_stat-obj_name
          AND key-versno_o = ls_stat-versno_old
          AND key-versno_n = ls_stat-versno_new.
        EXIT.
      ENDLOOP.
    ENDIF.
    IF sy-subrc <> 0.
      READ TABLE mt_parts INTO DATA(ls_part)
        WITH KEY type = iv_objtype object_name = iv_objname.
      IF sy-subrc <> 0. RETURN. ENDIF.

      mv_cur_objtype   = ls_part-type.
      mv_cur_objname   = ls_part-object_name.
      mv_cur_part_name = COND string(
        WHEN ls_part-class IS NOT INITIAL THEN |{ ls_part-class } - { ls_part-name }|
        ELSE ls_part-name ).

      load_versions( i_objtype = ls_part-type i_objname = ls_part-object_name ).
      IF mt_versions IS INITIAL. RETURN. ENDIF.

      CLEAR ms_base_ver.
      IF mv_object_type = zcl_ave_object_factory=>gc_type-tr.
        LOOP AT mt_versions INTO ms_base_ver WHERE korrnum = mv_object_name.
          EXIT.
        ENDLOOP.
      ENDIF.
      IF ms_base_ver IS INITIAL.
        ms_base_ver = mt_versions[ 1 ].
      ENDIF.
      mv_viewed_versno = ms_base_ver-versno.

      DATA ls_prev_part TYPE ty_version_row.
      LOOP AT mt_versions INTO ls_prev_part WHERE versno < ms_base_ver-versno.
        EXIT.
      ENDLOOP.
      update_ver_colors( iv_viewed_versno = mv_viewed_versno ).
      refresh_vers( ).
      IF mv_show_diff = abap_true.
        auto_show_diff_or_source( is_old = ls_prev_part is_new = ms_base_ver ).
      ELSE.
        show_source( i_objtype = ms_base_ver-objtype
                     i_objname = ms_base_ver-objname
                     i_versno  = ms_base_ver-versno ).
      ENDIF.
      RETURN.
    ENDIF.

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
    " Called when user clicks Save in the note dialog.
    " For pending decline, register decline; otherwise just add/update comment.
    DATA lv_msg_ts TYPE timestampl.
    DATA(lv_is_decline_msg) = xsdbool( mv_pending_decline = iv_hunk_key ).

    DATA ls_dn TYPE ty_decline_note.
    ls_dn-hunk_key = iv_hunk_key.
    ls_dn-note     = iv_note.
    INSERT ls_dn INTO TABLE mt_decline_notes.
    IF sy-subrc <> 0. MODIFY TABLE mt_decline_notes FROM ls_dn. ENDIF.

    IF mv_pending_decline = iv_hunk_key.
      INSERT iv_hunk_key INTO TABLE mt_declined.
      DELETE TABLE mt_approved FROM iv_hunk_key.
    ENDIF.

    READ TABLE mt_hunk_threads ASSIGNING FIELD-SYMBOL(<ls_thread>)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    IF sy-subrc <> 0.
      READ TABLE mt_hunk_info INTO DATA(ls_hunk_info)
        WITH TABLE KEY hunk_key = iv_hunk_key.
      IF sy-subrc = 0.
        INSERT VALUE ty_hunk_thread(
          hunk_key     = ls_hunk_info-hunk_key
          objtype      = ls_hunk_info-objtype
          obj_name     = ls_hunk_info-obj_name
          class_name   = ls_hunk_info-class_name
          display_name = ls_hunk_info-display_name
          hunk_no      = ls_hunk_info-hunk_no
          start_line   = ls_hunk_info-start_line
          change_count = ls_hunk_info-change_count
          html         = ls_hunk_info-html ) INTO TABLE mt_hunk_threads.
        READ TABLE mt_hunk_threads ASSIGNING <ls_thread>
          WITH TABLE KEY hunk_key = iv_hunk_key.
      ENDIF.
    ENDIF.

    IF <ls_thread> IS ASSIGNED.
      GET TIME STAMP FIELD lv_msg_ts.
      READ TABLE <ls_thread>-messages INTO DATA(ls_last_msg)
        INDEX lines( <ls_thread>-messages ).
      IF sy-subrc <> 0
         OR ls_last_msg-author <> sy-uname
         OR ls_last_msg-is_decline <> lv_is_decline_msg
         OR ls_last_msg-text   <> iv_note.
        APPEND VALUE ty_decline_msg(
          author      = sy-uname
          author_name = zcl_ave_popup_data=>get_user_name( sy-uname )
          created_at  = lv_msg_ts
          is_decline  = lv_is_decline_msg
          text        = iv_note ) TO <ls_thread>-messages.
      ENDIF.
    ENDIF.
    CLEAR mv_pending_decline.

    " Refresh diff view and report
    IF mv_decline_view_user IS NOT INITIAL.
      show_user_declines( iv_user = mv_decline_view_user ).
    ELSEIF mv_cr_base_html IS NOT INITIAL AND mv_cr_cur_key IS NOT INITIAL.
      DATA(lv_html_after_note) = inject_approve_btn(
        iv_html = mv_cr_base_html iv_key = mv_cr_cur_key ).

      DATA(lv_rev_note) = reverse( iv_hunk_key ).
      DATA lv_tilde_pos_note TYPE i.
      FIND FIRST OCCURRENCE OF '~' IN lv_rev_note MATCH OFFSET lv_tilde_pos_note.
      IF sy-subrc = 0.
        DATA lv_chunk_start_note TYPE i.
        lv_chunk_start_note = strlen( iv_hunk_key ) - lv_tilde_pos_note.
        DATA(lv_chunk_note) = iv_hunk_key+lv_chunk_start_note.
        IF lv_chunk_note IS NOT INITIAL.
          DATA(lv_script_note) =
            `<script>window.onload=function(){` &&
            `var e=document.getElementById('acr_c` && lv_chunk_note && `');` &&
            `if(e)e.scrollIntoView({block:'center'});}` &&
            `</script></head>`.
          lv_html_after_note = replace(
            val  = lv_html_after_note
            sub  = `</head>`
            with = lv_script_note ).
        ENDIF.
      ENDIF.

      set_html( lv_html_after_note ).
    ENDIF.
    refresh_rpt_row( ).
    regen_acr_report( ).
  ENDMETHOD.
  METHOD on_note_dlg_cancelled.
    IF mv_pending_decline = iv_hunk_key.
      CLEAR mv_pending_decline.
    ENDIF.
  ENDMETHOD.
  METHOD regen_acr_report.
    IF mv_cr_prepared = abap_true.
      mv_cr_report_html = zcl_ave_acr_report=>to_html(
        it_obj_stats = mt_acr_stats
        it_approved  = mt_approved
        it_declined  = mt_declined
        i_korrnum    = CONV #( mv_object_name ) ).
    ELSE.
      mv_cr_report_html = build_cr_object_report_html( ).
    ENDIF.
  ENDMETHOD.
  METHOD build_cr_object_report_html.
    DATA lv_korr_text TYPE as4text.
    DATA(lv_korrnum) = CONV trkorr( mv_object_name ).
    SELECT SINGLE as4text FROM e07t
      WHERE trkorr = @lv_korrnum AND langu = @sy-langu
      INTO @lv_korr_text.

    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `.prepare{text-align:center;margin:8px 0 18px 0}` &&
      `.prepare a{display:inline-block;background:#27ae60;color:#fff;text-decoration:none;` &&
      `font:bold 13px Consolas,monospace;border-radius:4px;padding:7px 20px}` &&
      `table{border-collapse:collapse;width:100%;margin-bottom:16px;font-size:12px}` &&
      `th{background:#3498db;color:#fff;padding:5px 10px;text-align:left;white-space:nowrap}` &&
      `td{padding:4px 10px;border-bottom:1px solid #eee;white-space:nowrap}` &&
      `tr:hover td{background:#f5f9ff}` &&
      `.nr{text-align:right}.muted{color:#777}`.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8">| &&
      |<style>{ lv_css }</style></head><body>| &&
      |<h2>&#128196;&nbsp;Code Review Report&nbsp;-&nbsp;| &&
      |<span style="color:#3498db">{ escape( val = CONV string( mv_object_name ) format = cl_abap_format=>e_html_text ) }|.
    IF lv_korr_text IS NOT INITIAL.
      result = result && |&nbsp;-&nbsp;{ escape( val = CONV string( lv_korr_text ) format = cl_abap_format=>e_html_text ) }|.
    ENDIF.
    result = result && |</span></h2>|.

    result = result &&
      `<div class="prepare"><a href="sapevent:prepare~0">Prepare Code Review</a></div>` &&
      |<table><tr>| &&
      |<th>Type</th><th>Object</th><th>Class</th><th>Type Description</th>| &&
      |<th class="nr">Rows</th></tr>|.

    LOOP AT mt_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      DATA(lv_objname_str) = CONV string( ls_part-object_name ).
      " Key: fixed-width TYPE (4 chars) + OBJNAME — no ~ separator in name possible
      DATA(lv_part_key) = |{ ls_part-type }~{ lv_objname_str }|.
      result = result &&
        |<tr>| &&
        |<td>{ escape( val = CONV string( ls_part-type ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td><b>{ escape( val = condense( val = lv_objname_str ) format = cl_abap_format=>e_html_text ) }</b></td>| &&
        |<td>{ escape( val = CONV string( ls_part-class ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td>{ escape( val = CONV string( ls_part-type_text ) format = cl_abap_format=>e_html_text ) }</td>| &&
        |<td class="nr">{ ls_part-rows }</td>| &&
        |</tr>|.
    ENDLOOP.

    DATA(lv_obj_count) = lines( mt_parts ).
    IF line_exists( mt_parts[ type = 'RPT' ] ).
      lv_obj_count = lv_obj_count - 1.
    ENDIF.
    IF lv_obj_count = 0.
      result = result &&
        |<tr><td colspan="5" class="muted">No changed objects found.</td></tr>|.
    ENDIF.

    result = result && |</table></body></html>|.
  ENDMETHOD.
  METHOD prepare_code_review.
    CHECK mv_code_review = abap_true.

    CLEAR: mt_acr_stats, mt_hunk_info, mt_hunk_threads,
           mt_approved, mt_declined, mt_decline_notes,
           mv_cr_base_html, mv_cr_cur_key, mv_decline_view_user.

    mv_cr_prepared = abap_true.
    maximize_html( ).

    DATA(lv_total) = lines( mt_parts ).
    IF line_exists( mt_parts[ type = 'RPT' ] ).
      lv_total = lv_total - 1.
    ENDIF.
    DATA lv_done TYPE i.

    LOOP AT mt_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      lv_done += 1.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = CONV i( lv_done * 100 / COND i( WHEN lv_total > 0 THEN lv_total ELSE 1 ) )
                  text       = CONV char70( |Code Review: preparing { ls_part-object_name }| ).
      IF ls_part-type = 'CLAS'.
        cr_precompute_class_parts( CONV #( ls_part-object_name ) ).
      ELSE.
        cr_precompute_part( ls_part ).
      ENDIF.

      mv_cr_report_html = zcl_ave_acr_report=>to_html(
        it_obj_stats = mt_acr_stats
        it_approved  = mt_approved
        it_declined  = mt_declined
        i_korrnum    = CONV #( mv_object_name ) ).
      set_html( mv_cr_report_html ).
      cl_gui_cfw=>flush( EXCEPTIONS OTHERS = 1 ).
    ENDLOOP.

    load_review_from_db( ).
    regen_acr_report( ).
    refresh_rpt_row( ).
    set_html( mv_cr_report_html ).
  ENDMETHOD.
  METHOD refresh_rpt_row.
    DATA(lv_approved) = lines( mt_approved ).
    DATA(lv_obj_count) = lines( mt_parts ).
    IF line_exists( mt_parts[ type = 'RPT' ] ).
      lv_obj_count = lv_obj_count - 1.
    ENDIF.
    DATA(lv_name) = COND string(
      WHEN mv_cr_prepared = abap_true
      THEN |[ Code Review Report - { lv_approved } hunk(s) approved ]|
      ELSE |[ Code Review Report - { lv_obj_count } object(s) ]| ).
    LOOP AT mt_parts ASSIGNING FIELD-SYMBOL(<rpt>) WHERE type = 'RPT'.
      <rpt>-name = lv_name.
      EXIT.
    ENDLOOP.
    refresh_parts( ).
  ENDMETHOD.
ENDCLASS.

CLASS ZCL_AVE_OBJECT_TR IMPLEMENTATION.
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
*          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'FUGR'
*            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) )
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
      WHEN gc_type-package  THEN NEW zcl_ave_object_pack( CONV #( object_name ) )
      WHEN gc_type-ddls     THEN NEW zcl_ave_object_ddls( CONV #( object_name ) ) ).

    IF result IS NOT BOUND OR result->check_exists( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_ave_object_ddls IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    DATA lv_name TYPE tadir-obj_name.
    lv_name = name.
    SELECT SINGLE pgmid FROM tadir
      WHERE pgmid    = 'R3TR'
        AND object   = 'DDLS'
        AND obj_name = @lv_name
        AND delflag  = ' '
      INTO @DATA(lv_pgmid).
    result = boolc( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    result = VALUE #( (
      unit        = CONV #( name )
      object_name = name
      type        = 'DDLS' ) ).
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
        clsname            = name
      RECEIVING
        result             = DATA(lt_meth)
      EXCEPTIONS
        class_not_existing = 1.

    CHECK sy-subrc = 0.

    " Загружаем все VRSD-записи для методов этого класса одним запросом
    DATA lv_like TYPE versobjnam.
    lv_like = name.
    lv_like+30 = '%'.
    DATA lt_vrsd_meth TYPE STANDARD TABLE OF vrsd WITH EMPTY KEY.
    SELECT objname FROM vrsd
      WHERE objtype = 'METH'
        AND objname LIKE @lv_like
      INTO TABLE @lt_vrsd_meth.

    LOOP AT lt_meth INTO DATA(method_include).
      DATA lv_objname TYPE versobjnam.
      " Ищем точное имя из VRSD — SAP сам формирует ключ с правильным паддингом
      LOOP AT lt_vrsd_meth INTO DATA(ls_vrsd)
        WHERE objname+30 = method_include-cpdkey-cpdname.
        lv_objname = ls_vrsd-objname.
        EXIT.
      ENDLOOP.
      IF lv_objname IS INITIAL.
        " Fallback: паддинг вручную через CHAR-присваивание
        lv_objname = name.
        lv_objname+30 = method_include-cpdkey-cpdname.
      ENDIF.
      APPEND VALUE #(
        class       = name
        unit        = |{ method_include-cpdkey-cpdname }|
        object_name = lv_objname
        type        = 'METH'
      ) TO result.
      CLEAR lv_objname.
    ENDLOOP.
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

CLASS zcl_ave_acr_stats IMPLEMENTATION.

  METHOD is_blank_hunk.
    result = abap_true.
    LOOP AT it_lines INTO DATA(lv_line).
      DATA(lv_trimmed) = condense( lv_line ).
      IF lv_trimmed <> ''.
        result = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD from_diff.
    CLEAR ev_ins. CLEAR ev_del. CLEAR ev_mod. CLEAR et_authors.

    DATA lt_dels TYPE string_table.
    DATA lt_ins  TYPE string_table.

    " Append sentinel '=' to flush the last change block
    DATA lt_ops TYPE zif_ave_popup_types=>ty_t_diff.
    lt_ops = it_diff.
    APPEND VALUE #( op = '=' ) TO lt_ops.

    LOOP AT lt_ops INTO DATA(ls).
      CASE ls-op.
        WHEN '-'.
          APPEND CONV string( ls-text ) TO lt_dels.
        WHEN '+'.
          APPEND CONV string( ls-text ) TO lt_ins.
        WHEN '='.
          CHECK lt_dels IS NOT INITIAL OR lt_ins IS NOT INITIAL.

          " Skip hunks that contain only blank/whitespace lines — nothing to approve
          DATA lt_hunk_lines TYPE string_table.
          CLEAR lt_hunk_lines.
          LOOP AT lt_dels INTO DATA(lv_dl). APPEND lv_dl TO lt_hunk_lines. ENDLOOP.
          LOOP AT lt_ins  INTO DATA(lv_il). APPEND lv_il TO lt_hunk_lines. ENDLOOP.
          IF is_blank_hunk( lt_hunk_lines ) = abap_true.
            CLEAR lt_dels. CLEAR lt_ins.
            CONTINUE.
          ENDIF.

          " Parallel flag table: which ins lines have been matched already
          DATA lt_ins_matched TYPE STANDARD TABLE OF abap_bool WITH DEFAULT KEY.
          CLEAR lt_ins_matched.
          DO lines( lt_ins ) TIMES.
            APPEND abap_false TO lt_ins_matched.
          ENDDO.

          " First blamed line of the hunk claims the hunk_count for its author
          DATA lv_hunk_author TYPE versuser.
          CLEAR lv_hunk_author.

          " Greedy pairing: for each del, find first unmatched ins with has_common_chars
          LOOP AT lt_dels INTO DATA(lv_d).
            DATA lv_paired TYPE abap_bool.
            lv_paired = abap_false.
            LOOP AT lt_ins INTO DATA(lv_i).
              DATA(lv_ii) = sy-tabix.
              ASSIGN lt_ins_matched[ lv_ii ] TO FIELD-SYMBOL(<m>).
              CHECK <m> = abap_false.
              IF zcl_ave_popup_diff=>has_common_chars( iv_a = lv_d iv_b = lv_i ) = abap_true.
                ev_mod += 1.
                <m> = abap_true.
                lv_paired = abap_true.
                IF it_blame IS SUPPLIED.
                  DATA(lv_first_mod) = COND abap_bool(
                    WHEN lv_hunk_author IS INITIAL THEN abap_true ELSE abap_false ).
                  add_blame( EXPORTING iv_text     = lv_i
                                       iv_op       = '~'
                                       iv_new_hunk = lv_first_mod
                                       it_blame    = it_blame
                             CHANGING  ct_authors  = et_authors ).
                  IF lv_first_mod = abap_true.
                    READ TABLE it_blame INTO DATA(ls_bm) WITH KEY text = lv_i.
                    IF sy-subrc = 0. lv_hunk_author = ls_bm-author. ENDIF.
                  ENDIF.
                ENDIF.
                EXIT.
              ENDIF.
            ENDLOOP.
            IF lv_paired = abap_false.
              ev_del += 1.
            ENDIF.
          ENDLOOP.

          " Unmatched ins lines
          LOOP AT lt_ins INTO lv_i.
            lv_ii = sy-tabix.
            ASSIGN lt_ins_matched[ lv_ii ] TO <m>.
            CHECK <m> = abap_false.
            ev_ins += 1.
            IF it_blame IS SUPPLIED.
              DATA(lv_first_ins) = COND abap_bool(
                WHEN lv_hunk_author IS INITIAL THEN abap_true ELSE abap_false ).
              add_blame( EXPORTING iv_text     = lv_i
                                   iv_op       = '+'
                                   iv_new_hunk = lv_first_ins
                                   it_blame    = it_blame
                         CHANGING  ct_authors  = et_authors ).
              IF lv_first_ins = abap_true.
                READ TABLE it_blame INTO DATA(ls_bi) WITH KEY text = lv_i.
                IF sy-subrc = 0. lv_hunk_author = ls_bi-author. ENDIF.
              ENDIF.
            ENDIF.
          ENDLOOP.

          CLEAR lt_dels. CLEAR lt_ins. CLEAR lt_ins_matched. CLEAR lv_hunk_author.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_blame.
    READ TABLE it_blame INTO DATA(ls_b) WITH KEY text = iv_text.
    CHECK sy-subrc = 0.
    READ TABLE ct_authors ASSIGNING FIELD-SYMBOL(<a>) WITH KEY author = ls_b-author.
    IF sy-subrc <> 0.
      INSERT VALUE #( author = ls_b-author author_name = ls_b-author_name )
        INTO TABLE ct_authors.
      READ TABLE ct_authors ASSIGNING <a> WITH KEY author = ls_b-author.
    ENDIF.
    CASE iv_op.
      WHEN '+'. <a>-ins_count += 1.
      WHEN '~'. <a>-mod_count += 1.
    ENDCASE.
    IF iv_new_hunk = abap_true.
      <a>-hunk_count += 1.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS ZCL_AVE_ACR_REPORT IMPLEMENTATION.
  METHOD to_html.
    " Transport description from E07T
    DATA lv_korr_text TYPE as4text.
    SELECT SINGLE as4text FROM e07t
      WHERE trkorr = @i_korrnum AND langu = @sy-langu
      INTO @lv_korr_text.

    " Aggregate grand totals per owner across all objects
    TYPES: BEGIN OF ty_owner_total,
             author      TYPE versuser,
             author_name TYPE ad_namtext,
             ins_count   TYPE i,
             mod_count   TYPE i,
             del_count   TYPE i,
             hunk_count  TYPE i,
             appr_count  TYPE i,
             decl_count  TYPE i,
           END OF ty_owner_total.
    DATA lt_totals TYPE STANDARD TABLE OF ty_owner_total WITH DEFAULT KEY.

    LOOP AT it_obj_stats INTO DATA(ls_obj).
      " Compute approved/declined for this object
      DATA(lv_obj_prefix) = |{ ls_obj-objtype }~{ ls_obj-obj_name }~|.
      DATA(lv_cp_pat2) = lv_obj_prefix && `*`.
      DATA lv_oa TYPE i. DATA lv_od TYPE i. CLEAR: lv_oa, lv_od.
      LOOP AT it_approved INTO DATA(lv_ak2). IF lv_ak2 CP lv_cp_pat2. lv_oa += 1. ENDIF. ENDLOOP.
      LOOP AT it_declined INTO DATA(lv_dk2). IF lv_dk2 CP lv_cp_pat2. lv_od += 1. ENDIF. ENDLOOP.

      IF ls_obj-bt_authors IS NOT INITIAL.

        LOOP AT ls_obj-bt_authors INTO DATA(ls_ba).
          READ TABLE lt_totals ASSIGNING FIELD-SYMBOL(<t>) WITH KEY author = ls_ba-author.
          IF sy-subrc <> 0.
            APPEND VALUE #( author = ls_ba-author author_name = ls_ba-author_name ) TO lt_totals.
            READ TABLE lt_totals ASSIGNING <t> WITH KEY author = ls_ba-author.
          ENDIF.
          <t>-ins_count  += ls_ba-ins_count.
          <t>-del_count  += ls_ba-del_count.
          <t>-mod_count  += ls_ba-mod_count.
          <t>-hunk_count += ls_ba-hunk_count.
        ENDLOOP.

        " approved/declined go to primary author (most ins, then mod lines)
        DATA lv_primary      TYPE versuser.
        DATA lv_primary_ins  TYPE i.
        DATA lv_primary_mod  TYPE i.
        CLEAR: lv_primary, lv_primary_ins, lv_primary_mod.
        LOOP AT ls_obj-bt_authors INTO ls_ba.
          IF ls_ba-ins_count > lv_primary_ins.
            lv_primary_ins = ls_ba-ins_count.
            lv_primary_mod = ls_ba-mod_count.
            lv_primary     = ls_ba-author.
          ELSEIF ls_ba-ins_count = lv_primary_ins AND ls_ba-mod_count > lv_primary_mod.
            lv_primary_mod = ls_ba-mod_count.
            lv_primary     = ls_ba-author.
          ENDIF.
        ENDLOOP.
        IF lv_primary IS INITIAL.
          DATA lv_primary_del TYPE i.
          CLEAR lv_primary_del.
          LOOP AT ls_obj-bt_authors INTO ls_ba.
            IF ls_ba-del_count > lv_primary_del.
              lv_primary_del = ls_ba-del_count.
              lv_primary     = ls_ba-author.
            ENDIF.
          ENDLOOP.
        ENDIF.
        IF lv_primary IS NOT INITIAL.
          READ TABLE lt_totals ASSIGNING <t> WITH KEY author = lv_primary.
          IF sy-subrc = 0.
            <t>-appr_count += lv_oa.
            <t>-decl_count += lv_od.
          ENDIF.
        ENDIF.
      ELSEIF ls_obj-author IS NOT INITIAL.
        READ TABLE lt_totals ASSIGNING <t> WITH KEY author = ls_obj-author.
        IF sy-subrc <> 0.
          APPEND VALUE #( author = ls_obj-author author_name = ls_obj-author_name ) TO lt_totals.
          READ TABLE lt_totals ASSIGNING <t> WITH KEY author = ls_obj-author.
        ENDIF.
        <t>-ins_count  += ls_obj-ins_count.
        <t>-del_count  += ls_obj-del_count.
        <t>-mod_count  += ls_obj-mod_count.
        <t>-hunk_count += ls_obj-hunk_count.
        <t>-appr_count += lv_oa.
        <t>-decl_count += lv_od.
      ENDIF.
    ENDLOOP.

    " Shared CSS (matches AVE's Consolas/monospace style)
    DATA(lv_css) =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `h3{color:#555;margin:20px 0 6px}` &&
      `table{border-collapse:collapse;width:100%;margin-bottom:16px;font-size:12px}` &&
      `th{background:#3498db;color:#fff;padding:5px 10px;text-align:left;white-space:nowrap}` &&
      `td{padding:4px 10px;border-bottom:1px solid #eee;white-space:nowrap}` &&
      `tr:hover td{background:#f5f9ff}` &&
      `td:nth-child(2){width:220px;min-width:220px;max-width:220px;overflow:hidden;text-overflow:ellipsis}` &&
      `tr.obj-row{cursor:pointer}` &&
      `tr.obj-row:hover td{background:#e8f0fb}` &&
      `tr.user-row{cursor:pointer}` &&
      `tr.user-row:hover td{background:#e8f0fb}` &&
      `.cr td{background:#f0f4f8;font-weight:bold}` &&
      `.mr td:nth-child(3){padding-left:24px}` &&
      `.nr{text-align:right}` &&
      `.gi{color:#27ae60}.gd{color:#e74c3c}.gm{color:#e67e22}`.

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8">| &&
      |<style>{ lv_css }</style>| &&
      `<script>x=1;</script></head><body>`.

    " ── Header ──────────────────────────────────────────────────────
    result = result &&
      |<h2>&#128196;&nbsp;Code Review Report&nbsp;&mdash;&nbsp;| &&
      |<span style="color:#3498db">{ esc( i_korrnum ) }|.
    IF lv_korr_text IS NOT INITIAL.
      result = result && |&nbsp;&mdash;&nbsp;{ esc( lv_korr_text ) }|.
    ENDIF.
    result = result && |</span></h2>|.

    " ── Authors table ───────────────────────────────────────────────
    IF lt_totals IS NOT INITIAL.
      result = result &&
        |<h3>Owners</h3>| &&
        |<table><tr>| &&
        |<th>Owner</th><th>Name</th>| &&
        |<th class="nr">Ins/Mod/Del</th>| &&
        |<th class="nr">Blocks</th>| &&
        |<th class="nr">Approved</th>| &&
        |<th class="nr">Declined</th>| &&
        |<th class="nr">%</th></tr>|.
      LOOP AT lt_totals INTO DATA(ls_tot).
        CHECK ls_tot-ins_count > 0 OR ls_tot-mod_count > 0 OR ls_tot-del_count > 0.
        " Build approved/declined/% cells for owner row
        DATA lv_ow_appr_cell TYPE string.
        DATA lv_ow_decl_cell TYPE string.
        DATA lv_ow_pct_cell  TYPE string.
        DATA lv_ow_pct       TYPE i.
        IF ls_tot-hunk_count = 0.
          lv_ow_appr_cell = `<td class="nr">—</td>`.
          lv_ow_decl_cell = `<td class="nr">—</td>`.
          lv_ow_pct_cell  = `<td class="nr">—</td>`.
        ELSE.
          lv_ow_pct = ( ls_tot-appr_count + ls_tot-decl_count ) * 100 / ls_tot-hunk_count.
          " Approved: green only at 100% approved
          IF ls_tot-appr_count = ls_tot-hunk_count.
            lv_ow_appr_cell = |<td class="nr gi" style="font-weight:bold">&#10003; { ls_tot-appr_count }/{ ls_tot-hunk_count }</td>|.
          ELSEIF ls_tot-appr_count > 0.
            lv_ow_appr_cell = |<td class="nr" style="font-weight:bold">&#10003; { ls_tot-appr_count }/{ ls_tot-hunk_count }</td>|.
          ELSE.
            lv_ow_appr_cell = |<td class="nr">{ ls_tot-appr_count }/{ ls_tot-hunk_count }</td>|.
          ENDIF.
          " Declined: red only at 100% declined
          IF ls_tot-decl_count = ls_tot-hunk_count.
            lv_ow_decl_cell = |<td class="nr gd" style="font-weight:bold">&#10007; { ls_tot-decl_count }/{ ls_tot-hunk_count }</td>|.
          ELSEIF ls_tot-decl_count > 0.
            lv_ow_decl_cell = |<td class="nr" style="font-weight:bold">&#10007; { ls_tot-decl_count }/{ ls_tot-hunk_count }</td>|.
          ELSE.
            lv_ow_decl_cell = |<td class="nr">{ ls_tot-decl_count }/{ ls_tot-hunk_count }</td>|.
          ENDIF.
          " %: green at 100% approved, red at 100% declined
          IF ls_tot-appr_count = ls_tot-hunk_count.
            lv_ow_pct_cell = |<td class="nr gi" style="font-weight:bold">{ lv_ow_pct }%</td>|.
          ELSEIF ls_tot-decl_count = ls_tot-hunk_count.
            lv_ow_pct_cell = |<td class="nr gd" style="font-weight:bold">{ lv_ow_pct }%</td>|.
          ELSE.
            lv_ow_pct_cell = |<td class="nr" style="font-weight:bold">{ lv_ow_pct }%</td>|.
          ENDIF.
        ENDIF.
        DATA(lv_user_tr_attr) = `class="user-row" title="Click to show declined notes"`.
        result = result &&
          |<tr { lv_user_tr_attr }>| &&
          |<td style="font-weight:bold"><a href="sapevent:openuserdeclined~{ esc( ls_tot-author ) }">{ esc( ls_tot-author ) }</a></td>| &&
          |<td style="font-weight:bold">{ esc( ls_tot-author_name ) }</td>| &&
          |<td class="nr" style="font-weight:bold">| &&
            |<span style="color:#27ae60">{ ls_tot-ins_count }</span>| &&
            |&nbsp;/&nbsp;<span style="color:#e67e22">{ ls_tot-mod_count }</span>| &&
            |&nbsp;/&nbsp;<span style="color:#e74c3c">{ ls_tot-del_count }</span>| &&
          |</td>| &&
          |<td class="nr" style="font-weight:bold">{ ls_tot-hunk_count }</td>| &&
          lv_ow_appr_cell && lv_ow_decl_cell && lv_ow_pct_cell &&
          |</tr>|.
      ENDLOOP.
      result = result && |</table>|.
    ENDIF.

    " ── Changed objects table ────────────────────────────────────────
    TYPES: BEGIN OF ty_sort,
             class_name TYPE seoclsname,
             type_order TYPE i,
             obj_name   TYPE versobjnam,
             idx        TYPE i,
           END OF ty_sort.
    DATA lt_sort TYPE STANDARD TABLE OF ty_sort WITH DEFAULT KEY.
    DATA lt_sorted TYPE zif_ave_acr_types=>ty_t_obj_stats.
    lt_sorted = it_obj_stats.

    LOOP AT lt_sorted INTO DATA(ls_s2).
      DATA(lv_ord) = SWITCH i( ls_s2-objtype
        WHEN 'CLSD' THEN 1
        WHEN 'CPUB' THEN 2
        WHEN 'CPRO' THEN 3
        WHEN 'CPRI' THEN 4
        WHEN 'CINC' THEN 5
        WHEN 'CDEF' THEN 6
        WHEN 'METH' THEN 7
        ELSE             0 ).
      DATA(lv_class_name) = ls_s2-class_name.
      IF lv_class_name IS INITIAL.
        CASE ls_s2-objtype.
          WHEN 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'CINC' OR 'CDEF'.
            DATA(lv_obj_name) = CONV string( ls_s2-obj_name ).
            FIND FIRST OCCURRENCE OF '=' IN lv_obj_name MATCH OFFSET DATA(lv_eq_pos).
            IF sy-subrc = 0.
              lv_obj_name = lv_obj_name(lv_eq_pos).
            ENDIF.
            lv_class_name = CONV #( lv_obj_name ).
        ENDCASE.
      ENDIF.
      APPEND VALUE #( class_name = lv_class_name
                      type_order = lv_ord
                      obj_name   = ls_s2-obj_name
                      idx        = sy-tabix ) TO lt_sort.
    ENDLOOP.
    SORT lt_sort BY class_name type_order obj_name.

    DATA lt_sorted_final TYPE zif_ave_acr_types=>ty_t_obj_stats.
    LOOP AT lt_sort INTO DATA(ls_ord).
      READ TABLE lt_sorted INTO DATA(ls_tmp) INDEX ls_ord-idx.
      IF ls_tmp-class_name IS INITIAL.
        ls_tmp-class_name = ls_ord-class_name.
      ENDIF.
      APPEND ls_tmp TO lt_sorted_final.
    ENDLOOP.

    " Remove entries with no actual changes
    DELETE lt_sorted_final WHERE ins_count = 0 AND del_count = 0 AND mod_count = 0.

    " Render one table per class (empty class_name = programs/other)
    DATA lv_cur_class TYPE seoclsname VALUE '####'.
    DATA(lv_tbl_hdr) =
      |<table><tr>| &&
      |<th>Type</th><th>Object</th>| &&
      |<th>Owner</th><th>Date</th><th>Time</th>| &&
      |<th class="nr">Ins/Mod/Del</th>| &&
      |<th class="nr">Blocks</th>| &&
      |<th class="nr">Approved</th>| &&
      |<th class="nr">Declined</th>| &&
      |<th class="nr">%</th></tr>|.

    " Class-level totals accumulators
    DATA lv_tot_ins     TYPE i.
    DATA lv_tot_mod     TYPE i.
    DATA lv_tot_del     TYPE i.
    DATA lv_tot_hunks   TYPE i.
    DATA lv_tot_appr    TYPE i.
    DATA lv_tot_decl    TYPE i.

    DATA lv_tot_pct       TYPE i.
    DATA lv_tot_appr_cell TYPE string.
    DATA lv_tot_decl_cell TYPE string.
    DATA lv_tot_pct_cell  TYPE string.

    LOOP AT lt_sorted_final INTO ls_obj.
      IF ls_obj-class_name <> lv_cur_class.
        " ── close previous table with Total row ──
        IF lv_cur_class <> '####'.
          IF lv_tot_hunks = 0.
            lv_tot_appr_cell = `<td class="nr">—</td>`.
            lv_tot_decl_cell = `<td class="nr">—</td>`.
            lv_tot_pct_cell  = `<td class="nr">—</td>`.
          ELSE.
            lv_tot_pct = ( lv_tot_appr + lv_tot_decl ) * 100 / lv_tot_hunks.
            IF lv_tot_appr > 0.
              lv_tot_appr_cell = |<td class="nr gi" style="font-weight:bold">&#10003; { lv_tot_appr }/{ lv_tot_hunks }</td>|.
            ELSE.
              lv_tot_appr_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_appr }/{ lv_tot_hunks }</td>|.
            ENDIF.
            IF lv_tot_decl > 0.
              lv_tot_decl_cell = |<td class="nr gd" style="font-weight:bold">&#10007; { lv_tot_decl }/{ lv_tot_hunks }</td>|.
            ELSE.
              lv_tot_decl_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_decl }/{ lv_tot_hunks }</td>|.
            ENDIF.
            lv_tot_pct_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_pct }%</td>|.
          ENDIF.
          result = result &&
            `<tr style="background:#e8f0fb;border-top:2px solid #3498db">` &&
            `<td style="font-weight:bold;color:#2c3e50" colspan="2">Total</td>` &&
            `<td colspan="3"></td>` &&
            |<td class="nr" style="font-weight:bold">| &&
              |<span style="color:#27ae60">{ lv_tot_ins }</span>| &&
              |&nbsp;/&nbsp;<span style="color:#e67e22">{ lv_tot_mod }</span>| &&
              |&nbsp;/&nbsp;<span style="color:#e74c3c">{ lv_tot_del }</span></td>| &&
            |<td class="nr" style="font-weight:bold">{ lv_tot_hunks }</td>| &&
            lv_tot_appr_cell && lv_tot_decl_cell && lv_tot_pct_cell &&
            `</tr></table>`.
          CLEAR: lv_tot_ins, lv_tot_mod, lv_tot_del, lv_tot_hunks, lv_tot_appr, lv_tot_decl.
        ENDIF.
        lv_cur_class = ls_obj-class_name.
        IF lv_cur_class IS INITIAL.
          result = result && |<h3>Programs / Other</h3>|.
        ELSE.
          result = result && |<h3>Class: { esc( lv_cur_class ) }</h3>|.
        ENDIF.
        result = result && lv_tbl_hdr.
      ENDIF.

      " Format date/time for display
      DATA(lv_date) = CONV string( ls_obj-datum ).
      IF lv_date IS NOT INITIAL.
        lv_date = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }|.
      ENDIF.
      DATA(lv_time) = CONV string( ls_obj-zeit ).
      IF lv_time IS NOT INITIAL.
        lv_time = |{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.
      ENDIF.

      " Compute approve/decline stats for this object
      lv_obj_prefix = |{ ls_obj-objtype }~{ ls_obj-obj_name }~|.
      DATA(lv_cp_pat) = lv_obj_prefix && `*`.
      DATA lv_appr TYPE i.
      DATA lv_decl TYPE i.
      CLEAR: lv_appr, lv_decl.
      LOOP AT it_approved INTO DATA(lv_ak).
        IF lv_ak CP lv_cp_pat. lv_appr += 1. ENDIF.
      ENDLOOP.
      LOOP AT it_declined INTO DATA(lv_dk).
        IF lv_dk CP lv_cp_pat. lv_decl += 1. ENDIF.
      ENDLOOP.
      DATA lv_total_h      TYPE i.
      DATA lv_approve_cell TYPE string.
      DATA lv_decline_cell TYPE string.
      DATA lv_pct_cell     TYPE string.
      DATA lv_pct          TYPE i.
      CLEAR: lv_total_h, lv_approve_cell, lv_decline_cell, lv_pct_cell, lv_pct.
      lv_total_h = ls_obj-hunk_count.
      IF lv_total_h = 0.
        lv_approve_cell = `<td class="nr">—</td>`.
        lv_decline_cell = `<td class="nr">—</td>`.
        lv_pct_cell     = `<td class="nr">—</td>`.
      ELSE.
        lv_pct = ( lv_appr + lv_decl ) * 100 / lv_total_h.
        " Approved: green only at 100% approved
        IF lv_appr = lv_total_h.
          lv_approve_cell = |<td class="nr gi" style="font-weight:bold">&#10003; { lv_appr }/{ lv_total_h }</td>|.
        ELSEIF lv_appr > 0.
          lv_approve_cell = |<td class="nr" style="font-weight:bold">&#10003; { lv_appr }/{ lv_total_h }</td>|.
        ELSE.
          lv_approve_cell = |<td class="nr">{ lv_appr }/{ lv_total_h }</td>|.
        ENDIF.
        " Declined: red only at 100% declined
        IF lv_decl = lv_total_h.
          lv_decline_cell = |<td class="nr gd" style="font-weight:bold">&#10007; { lv_decl }/{ lv_total_h }</td>|.
        ELSEIF lv_decl > 0.
          lv_decline_cell = |<td class="nr" style="font-weight:bold">&#10007; { lv_decl }/{ lv_total_h }</td>|.
        ELSE.
          lv_decline_cell = |<td class="nr">{ lv_decl }/{ lv_total_h }</td>|.
        ENDIF.
        " %: green at 100% approved, red at 100% declined
        IF lv_appr = lv_total_h.
          lv_pct_cell = |<td class="nr gi" style="font-weight:bold">{ lv_pct }%</td>|.
        ELSEIF lv_decl = lv_total_h.
          lv_pct_cell = |<td class="nr gd" style="font-weight:bold">{ lv_pct }%</td>|.
        ELSE.
          lv_pct_cell = |<td class="nr" style="font-weight:bold">{ lv_pct }%</td>|.
        ENDIF.
      ENDIF.

      " Accumulate class totals
      lv_tot_ins     += ls_obj-ins_count.
      lv_tot_mod     += ls_obj-mod_count.
      lv_tot_del     += ls_obj-del_count.
      lv_tot_hunks   += ls_obj-hunk_count.
      lv_tot_appr    += lv_appr.
      lv_tot_decl    += lv_decl.

      DATA(lv_ev_key) = |{ ls_obj-objtype }~{ ls_obj-obj_name }|.
      DATA lv_disp_name TYPE string.
      lv_disp_name = COND #( WHEN ls_obj-display_name IS NOT INITIAL THEN ls_obj-display_name ELSE ls_obj-obj_name ).
      DATA(lv_row_id) = |obj_{ escape( val = lv_ev_key format = cl_abap_format=>e_html_attr ) }|.
      DATA lv_name_cell TYPE string.
      IF ls_obj-is_created = abap_true.
        lv_name_cell = |<td><a href="sapevent:openobj~{ lv_ev_key }" style="font-weight:bold;color:#27ae60">{ esc( lv_disp_name ) }</a></td>|.
      ELSE.
        lv_name_cell = |<td><a href="sapevent:openobj~{ lv_ev_key }" style="font-weight:bold">{ esc( lv_disp_name ) }</a></td>|.
      ENDIF.
      DATA lv_owner_display TYPE string.
      DATA lv_owner_count TYPE i.
      CLEAR: lv_owner_display, lv_owner_count.
      IF ls_obj-bt_authors IS NOT INITIAL.
        LOOP AT ls_obj-bt_authors INTO DATA(ls_owner_ba) WHERE hunk_count > 0.
          CHECK ls_owner_ba-author IS NOT INITIAL.
          lv_owner_count += 1.
          IF lv_owner_count <= 3.
            IF lv_owner_display IS INITIAL.
              lv_owner_display = ls_owner_ba-author.
            ELSE.
              lv_owner_display = lv_owner_display && `, ` && ls_owner_ba-author.
            ENDIF.
          ENDIF.
        ENDLOOP.
        IF lv_owner_count > 3.
          lv_owner_display = `Several`.
        ENDIF.
      ENDIF.
      IF lv_owner_display IS INITIAL.
        lv_owner_display = ls_obj-author.
      ENDIF.
      result = result &&
        |<tr id="{ lv_row_id }">| &&
        |<td>{ esc( ls_obj-objtype ) }</td>| &&
        lv_name_cell &&
        |<td>{ esc( lv_owner_display ) }</td>| &&
        |<td>{ lv_date }</td>| &&
        |<td>{ lv_time }</td>| &&
        |<td class="nr" style="font-weight:bold">| &&
          |<span style="color:#27ae60">{ ls_obj-ins_count }</span>| &&
          |&nbsp;/&nbsp;<span style="color:#e67e22">{ ls_obj-mod_count }</span>| &&
          |&nbsp;/&nbsp;<span style="color:#e74c3c">{ ls_obj-del_count }</span></td>| &&
        |<td class="nr" style="font-weight:bold">{ ls_obj-hunk_count }</td>| &&
        lv_approve_cell && lv_decline_cell && lv_pct_cell &&
        `</tr>`.
    ENDLOOP.

    " ── close last table with Total row ──
    IF lv_cur_class <> '####'.
      IF lv_tot_hunks = 0.
        lv_tot_appr_cell = `<td class="nr">—</td>`.
        lv_tot_decl_cell = `<td class="nr">—</td>`.
        lv_tot_pct_cell  = `<td class="nr">—</td>`.
      ELSE.
        lv_tot_pct = ( lv_tot_appr + lv_tot_decl ) * 100 / lv_tot_hunks.
        IF lv_tot_appr > 0.
          lv_tot_appr_cell = |<td class="nr gi" style="font-weight:bold">&#10003; { lv_tot_appr }/{ lv_tot_hunks }</td>|.
        ELSE.
          lv_tot_appr_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_appr }/{ lv_tot_hunks }</td>|.
        ENDIF.
        IF lv_tot_decl > 0.
          lv_tot_decl_cell = |<td class="nr gd" style="font-weight:bold">&#10007; { lv_tot_decl }/{ lv_tot_hunks }</td>|.
        ELSE.
          lv_tot_decl_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_decl }/{ lv_tot_hunks }</td>|.
        ENDIF.
        lv_tot_pct_cell = |<td class="nr" style="font-weight:bold">{ lv_tot_pct }%</td>|.
      ENDIF.
      result = result &&
        `<tr style="background:#e8f0fb;border-top:2px solid #3498db">` &&
        `<td style="font-weight:bold;color:#2c3e50" colspan="2">Total</td>` &&
        `<td colspan="3"></td>` &&
        |<td class="nr" style="font-weight:bold">| &&
          |<span style="color:#27ae60">{ lv_tot_ins }</span>| &&
          |&nbsp;/&nbsp;<span style="color:#e67e22">{ lv_tot_mod }</span>| &&
          |&nbsp;/&nbsp;<span style="color:#e74c3c">{ lv_tot_del }</span></td>| &&
        |<td class="nr" style="font-weight:bold">{ lv_tot_hunks }</td>| &&
        lv_tot_appr_cell && lv_tot_decl_cell && lv_tot_pct_cell &&
        `</tr></table>`.
    ENDIF.

    result = result && |</body></html>|.
  ENDMETHOD.
  METHOD esc.
result = escape( val = CONV string( iv_val ) format = cl_abap_format=>e_html_text ).
  ENDMETHOD.
ENDCLASS.

CLASS zcl_ave_acr_note_dlg IMPLEMENTATION.

  METHOD constructor.
    mv_title    = iv_title.
    mv_hunk_key = iv_hunk_key.
    mv_note     = iv_note.
  ENDMETHOD.
  METHOD show.
    " ── Dialog box ──────────────────────────────────────────────────
    CREATE OBJECT mo_box
      EXPORTING
        width                       = 560
        height                      = 160
        top                         = 120
        left                        = 200
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mo_box->set_caption( CONV text40( mv_title ) ).
    SET HANDLER on_box_close FOR mo_box.

    " ── Text editor fills the whole dialog ──────────────────────────
    CREATE OBJECT mo_text
      EXPORTING
        parent                 = mo_box
        wordwrap_mode          = cl_gui_textedit=>wordwrap_at_fixed_position
        wordwrap_position      = 255
      EXCEPTIONS
        error_cntl_create      = 1
        error_cntl_init        = 2
        error_cntl_link        = 3
        error_dp_create        = 4
        gui_type_not_supported = 5
        OTHERS                 = 6.
    IF sy-subrc <> 0. RETURN. ENDIF.

    " Pre-fill existing note if editing
    IF mv_note IS NOT INITIAL.
      DATA lt_lines TYPE TABLE OF char255.
      DATA lv_rest  TYPE string.
      lv_rest = mv_note.
      WHILE strlen( lv_rest ) > 255.
        APPEND CONV char255( lv_rest(255) ) TO lt_lines.
        lv_rest = lv_rest+255.
      ENDWHILE.
      APPEND CONV char255( lv_rest ) TO lt_lines.
      mo_text->set_text_as_r3table( lt_lines ).
    ENDIF.

    cl_gui_control=>set_focus( control = mo_text ).
    cl_gui_cfw=>flush( ).
  ENDMETHOD.
  METHOD on_box_close.
    " Read text — if not empty, register decline with note.
    " Do NOT call free() here — the framework closes the container automatically.
    DATA lt_lines TYPE TABLE OF char255.
    mo_text->get_text_as_r3table(
      IMPORTING table = lt_lines ).

    DATA lv_note TYPE string.
    LOOP AT lt_lines INTO DATA(lv_line).
      DATA(lv_str) = condense( CONV string( lv_line ) ).
      IF lv_str IS NOT INITIAL.
        IF lv_note IS INITIAL.
          lv_note = lv_str.
        ELSE.
          lv_note = lv_note && cl_abap_char_utilities=>newline && lv_str.
        ENDIF.
      ENDIF.
    ENDLOOP.

    sender->free( ).
    CLEAR mo_box.

    IF lv_note IS NOT INITIAL.
      RAISE EVENT saved
        EXPORTING iv_hunk_key = mv_hunk_key
                  iv_note     = lv_note.
    ELSE.
      RAISE EVENT cancelled
        EXPORTING iv_hunk_key = mv_hunk_key.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

" & Multi-windows program for ABAP object version comparison
" &----------------------------------------------------------------------
" & version: 1.00, 0.5 for Code Reviewer
" & Git https://github.com/ysichov/AVE

" & Written by Yurii Sychov
" & e-mail:   ysichov@gmail.com
" & blog:     https://ysychov.wordpress.com/blog/
" & LinkedIn: https://www.linkedin.com/in/ysychov/

" &Inspired by https://github.com/abapinho/abapTimeMachine , Eclipse Adt, GitHub and all others similar tools
" &----------------------------------------------------------------------
DATA go_popup TYPE REF TO zcl_ave_popup.

SELECTION-SCREEN BEGIN OF BLOCK b_mode WITH FRAME TITLE TEXT-020.
PARAMETERS: p_cr RADIOBUTTON GROUP mode  USER-COMMAND umod DEFAULT 'X'.
PARAMETERS: p_ve RADIOBUTTON GROUP mode .

SELECTION-SCREEN END OF BLOCK b_mode.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS rb_tr   RADIOBUTTON  GROUP typ USER-COMMAND utyp DEFAULT 'X'.
SELECTION-SCREEN COMMENT 3(20) TEXT-013 FOR FIELD rb_tr.
PARAMETERS p_task  TYPE trkorr                                     MODIF ID trq.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS rb_prog RADIOBUTTON GROUP typ .
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
PARAMETERS rb_pack RADIOBUTTON GROUP typ.
SELECTION-SCREEN COMMENT 3(20) TEXT-014 FOR FIELD rb_pack.
PARAMETERS p_pack  TYPE devclass   MATCHCODE OBJECT devclass       MODIF ID pck.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS rb_ddls RADIOBUTTON GROUP typ.
SELECTION-SCREEN COMMENT 3(20) TEXT-018 FOR FIELD rb_ddls.
PARAMETERS p_ddls  TYPE versobjnam                                  MODIF ID dls.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-015.
PARAMETERS p_layout AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_pane AS CHECKBOX.
PARAMETERS p_cmpct AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-016.
PARAMETERS p_diff NO-DISPLAY DEFAULT 'X'.
PARAMETERS p_datefr TYPE versdate.
PARAMETERS p_rmdp  AS CHECKBOX.
PARAMETERS p_ntoc AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_icase  AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-017.
PARAMETERS p_blame AS CHECKBOX.
PARAMETERS p_user TYPE versuser.
SELECTION-SCREEN END OF BLOCK b4.

"Events
INITIALIZATION.
  p_user = sy-uname.
  PERFORM supress_button.

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
      WHEN 'DLS'.
        screen-input = COND #( WHEN rb_ddls = 'X' THEN 1 ELSE 0 ).
    ENDCASE.
    IF screen-name = 'P_PANE' OR screen-name = 'P_CMPCT'.
      screen-input = COND #( WHEN p_diff = 'X' THEN 1 ELSE 0 ).
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.

AT SELECTION-SCREEN ON p_diff.
  " Trigger OUTPUT to re-evaluate enabled state of dependent checkboxes

AT SELECTION-SCREEN.
  CHECK sy-ucomm <> 'DUMMY'.
  PERFORM run_ave.

FORM supress_button.
  DATA itab TYPE TABLE OF sy-ucomm.
  APPEND 'ONLI' TO itab.
  CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
    EXPORTING
      p_status  = sy-pfkey
    TABLES
      p_exclude = itab.
ENDFORM.

FORM run_ave.
  " Open popup only when the user pressed Enter (ucomm is initial)
  CHECK sy-ucomm IS INITIAL.

  TRY.
      DATA(ls_settings) = VALUE zif_ave_object=>ty_settings(
        show_diff   = CONV #( p_diff )
        layout      = CONV #( p_layout )
        two_pane    = CONV #( p_pane )
        no_toc      = CONV #( p_ntoc )
        ignore_case = CONV #( p_icase )
        compact     = CONV #( p_cmpct )
        remove_dup  = CONV #( p_rmdp )
        blame       = CONV #( p_blame )
        filter_user = p_user
        date_from   = p_datefr
        code_review = CONV #( p_cr ) ).

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

      ELSEIF rb_ddls = 'X' AND p_ddls IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-ddls
          i_object_name = CONV #( p_ddls )
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
* abapmerge 0.16.7 - 2026-05-05T04:07:00.087Z
  CONSTANTS c_merge_timestamp TYPE string VALUE `2026-05-05T04:07:00.087Z`.
  CONSTANTS c_abapmerge_version TYPE string VALUE `0.16.7`.
ENDINTERFACE.
****************************************************
