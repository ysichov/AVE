CLASS zcl_ave_acr_note_dlg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Opens a non-blocking text-editor dialog for entering a Decline note.
    "! After Save the event SAVED is raised; caller must SET HANDLER before show().
    "! iv_title    : dialog caption, e.g. "METH~MY_METHOD - Block 3"
    "! iv_hunk_key : opaque key passed back unchanged in the SAVED event
    "! iv_note     : pre-filled text (for Edit Review)
    EVENTS saved
      EXPORTING
        VALUE(iv_hunk_key) TYPE string
        VALUE(iv_note)     TYPE string.

    METHODS constructor
      IMPORTING iv_title    TYPE string
                iv_hunk_key TYPE string
                iv_note     TYPE string OPTIONAL.

    METHODS show.

  PRIVATE SECTION.
    DATA mv_title    TYPE string.
    DATA mv_hunk_key TYPE string.
    DATA mv_note     TYPE string.

    DATA mo_box       TYPE REF TO cl_gui_dialogbox_container.
    DATA mo_split     TYPE REF TO cl_gui_splitter_container.
    DATA mo_cont_edit TYPE REF TO cl_gui_container.
    DATA mo_cont_bar  TYPE REF TO cl_gui_container.
    DATA mo_text      TYPE REF TO cl_gui_textedit.
    DATA mo_toolbar   TYPE REF TO cl_gui_toolbar.

    METHODS on_toolbar_click
      FOR EVENT function_selected OF cl_gui_toolbar
      IMPORTING fcode.
    METHODS on_box_close
      FOR EVENT close OF cl_gui_dialogbox_container
      IMPORTING sender.

    METHODS close_dialog.
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
        width                       = 600
        height                      = 300
        top                         = 100
        left                        = 200
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mo_box->set_caption( mv_title ).
    SET HANDLER on_box_close FOR mo_box.

    " ── Splitter: row 1 = text editor (tall), row 2 = toolbar (thin) ─
    CREATE OBJECT mo_split
      EXPORTING
        parent  = mo_box
        rows    = 2
        columns = 1
      EXCEPTIONS
        OTHERS  = 1.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mo_split->set_row_height( id = 1 height = 88 ).
    mo_split->set_row_height( id = 2 height = 12 ).

    mo_split->get_container(
      EXPORTING row = 1 column = 1
      RECEIVING container = mo_cont_edit ).
    mo_split->get_container(
      EXPORTING row = 2 column = 1
      RECEIVING container = mo_cont_bar ).

    " ── Text editor ─────────────────────────────────────────────────
    CREATE OBJECT mo_text
      EXPORTING
        parent                 = mo_cont_edit
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

    " ── Toolbar with Save / Cancel ───────────────────────────────────
    CREATE OBJECT mo_toolbar
      EXPORTING parent = mo_cont_bar
      EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0. RETURN. ENDIF.
    SET HANDLER on_toolbar_click FOR mo_toolbar.

    mo_toolbar->add_button(
      fcode     = 'SAVE'
      icon      = icon_okay
      butn_type = 0
      text      = 'Save'
      quickinfo = 'Save decline note' ).
    mo_toolbar->add_button(
      fcode     = 'CANCEL'
      icon      = icon_cancel
      butn_type = 0
      text      = 'Cancel'
      quickinfo = 'Cancel' ).

    cl_gui_cfw=>flush( ).
    " Control returns to SAP GUI event loop — no dispatch loop needed.
  ENDMETHOD.


  METHOD on_toolbar_click.
    IF fcode = 'SAVE'.
      " Read text from editor
      DATA lt_lines TYPE TABLE OF char255.
      mo_text->get_text_as_r3table(
        IMPORTING table = lt_lines ).
      DATA lv_note TYPE string.
      LOOP AT lt_lines INTO DATA(lv_line).
        DATA(lv_trimmed) = CONV string( lv_line ).
        IF lv_note IS INITIAL.
          lv_note = lv_trimmed.
        ELSE.
          lv_note = lv_note && cl_abap_char_utilities=>newline && lv_trimmed.
        ENDIF.
      ENDLOOP.
      close_dialog( ).
      RAISE EVENT saved
        EXPORTING iv_hunk_key = mv_hunk_key
                  iv_note     = lv_note.
    ELSEIF fcode = 'CANCEL'.
      close_dialog( ).
    ENDIF.
  ENDMETHOD.


  METHOD on_box_close.
    close_dialog( ).
  ENDMETHOD.


  METHOD close_dialog.
    IF mo_box IS BOUND.
      mo_box->free( ).
      CLEAR mo_box.
      cl_gui_cfw=>flush( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
