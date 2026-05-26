CLASS zcl_ave_html_viewer DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS show_html
      IMPORTING
        io_viewer       TYPE REF TO cl_gui_html_viewer
        iv_html         TYPE string
        iv_set_focus    TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result)   TYPE abap_bool.
ENDCLASS.


CLASS zcl_ave_html_viewer IMPLEMENTATION.

  METHOD show_html.
    CHECK io_viewer IS BOUND.

    DATA lt_html TYPE w3htmltab.
    DATA lv_url TYPE w3url.
    DATA lv_offset TYPE i.
    DATA lv_len TYPE i.
    DATA lv_chunk TYPE i.

    lv_len = strlen( iv_html ).
    WHILE lv_offset < lv_len.
      lv_chunk = COND #(
        WHEN lv_len - lv_offset > 255 THEN 255
        ELSE lv_len - lv_offset ).
      APPEND VALUE #( line = iv_html+lv_offset(lv_chunk) ) TO lt_html.
      lv_offset += lv_chunk.
    ENDWHILE.

    io_viewer->load_data(
      IMPORTING
        assigned_url = lv_url
      CHANGING
        data_table   = lt_html
      EXCEPTIONS
        OTHERS       = 1 ).
    CHECK sy-subrc = 0.

    io_viewer->show_url( url = lv_url ).
    IF iv_set_focus = abap_true.
      cl_gui_control=>set_focus( control = io_viewer ).
    ENDIF.
    cl_gui_cfw=>flush( ).
    result = abap_true.
  ENDMETHOD.

ENDCLASS.
