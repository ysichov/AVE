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

    DATA mo_box        TYPE REF TO cl_gui_dialogbox_container.
    DATA mo_split      TYPE REF TO cl_gui_splitter_container.
    DATA mo_split_btn  TYPE REF TO cl_gui_splitter_container.
    DATA mo_cont_edit  TYPE REF TO cl_gui_container.
    DATA mo_cont_bar   TYPE REF TO cl_gui_container.
    DATA mo_cont_save  TYPE REF TO cl_gui_container.
    DATA mo_cont_cncl  TYPE REF TO cl_gui_container.
    DATA mo_text       TYPE REF TO cl_gui_textedit.
    DATA mo_btn_save   TYPE REF TO cl_gui_button.
    DATA mo_btn_cancel TYPE REF TO cl_gui_button.

    METHODS on_save_click
      FOR EVENT select OF cl_gui_button
      IMPORTING sender.
    METHODS on_cancel_click
      FOR EVENT select OF cl_gui_button
      IMPORTING sender.
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
        width                       = 560
        height                      = 180
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

    mo_box->set_caption( CONV c200( mv_title ) ).
    SET HANDLER on_box_close FOR mo_box.

    " ── Main splitter: row 1 = text editor, row 2 = button bar ──────
    " no_autosize makes the sash non-draggable
    CREATE OBJECT mo_split
      EXPORTING
        parent      = mo_box
        rows        = 2
        columns     = 1
        no_autosize = abap_true
      EXCEPTIONS
        OTHERS      = 1.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mo_split->set_row_height( id = 1 height = 82 ).
    mo_split->set_row_height( id = 2 height = 18 ).

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

    " ── Button bar: 1 row × 2 columns splitter for Save | Cancel ────
    CREATE OBJECT mo_split_btn
      EXPORTING
        parent      = mo_cont_bar
        rows        = 1
        columns     = 2
        no_autosize = abap_true
      EXCEPTIONS
        OTHERS      = 1.
    IF sy-subrc <> 0. RETURN. ENDIF.

    mo_split_btn->set_column_width( id = 1 width = 50 ).
    mo_split_btn->set_column_width( id = 2 width = 50 ).

    mo_split_btn->get_container(
      EXPORTING row = 1 column = 1
      RECEIVING container = mo_cont_save ).
    mo_split_btn->get_container(
      EXPORTING row = 1 column = 2
      RECEIVING container = mo_cont_cncl ).

    " ── Save button ─────────────────────────────────────────────────
    CREATE OBJECT mo_btn_save
      EXPORTING
        text   = 'Save'
        parent = mo_cont_save
      EXCEPTIONS
        OTHERS = 1.
    IF sy-subrc <> 0. RETURN. ENDIF.
    SET HANDLER on_save_click FOR mo_btn_save.

    " ── Cancel button ───────────────────────────────────────────────
    CREATE OBJECT mo_btn_cancel
      EXPORTING
        text   = 'Cancel'
        parent = mo_cont_cncl
      EXCEPTIONS
        OTHERS = 1.
    IF sy-subrc <> 0. RETURN. ENDIF.
    SET HANDLER on_cancel_click FOR mo_btn_cancel.

    " ── Set focus to text editor so user can type immediately ────────
    cl_gui_control=>set_focus( control = mo_text ).

    cl_gui_cfw=>flush( ).
    " Returns immediately — SAP GUI event loop handles button clicks.
  ENDMETHOD.


  METHOD on_save_click.
    " Read text from editor
    DATA lt_lines TYPE TABLE OF char255.
    mo_text->get_text_as_r3table(
      IMPORTING table = lt_lines ).
    DATA lv_note TYPE string.
    LOOP AT lt_lines INTO DATA(lv_line).
      DATA(lv_str) = CONV string( lv_line ).
      IF lv_note IS INITIAL.
        lv_note = lv_str.
      ELSE.
        lv_note = lv_note && cl_abap_char_utilities=>newline && lv_str.
      ENDIF.
    ENDLOOP.
    close_dialog( ).
    RAISE EVENT saved
      EXPORTING iv_hunk_key = mv_hunk_key
                iv_note     = lv_note.
  ENDMETHOD.


  METHOD on_cancel_click.
    close_dialog( ).
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
