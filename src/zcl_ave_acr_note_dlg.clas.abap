CLASS zcl_ave_acr_note_dlg DEFINITION
  PUBLIC
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
    ENDIF.
  ENDMETHOD.

ENDCLASS.
