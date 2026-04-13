REPORT z_ave. " AVE - Abap Versions Explorer
" & Multi-windows program for ABAP object version comparison
" &----------------------------------------------------------------------
" & version: beta 0.1
" & Git https://github.com/ysichov/AVE

" & Written by Yurii Sychov
" & e-mail:   ysichov@gmail.com
" & blog:     https://ysychov.wordpress.com/blog/
" & LinkedIn: https://www.linkedin.com/in/ysychov/
" &----------------------------------------------------------------------

" Global reference keeps the popup object (and its event handlers) alive
" while the selection screen is active. Without this the object would be
" garbage-collected as soon as FORM run_ave returns.
DATA go_popup TYPE REF TO zcl_ave_popup.

"======================================================================
" Selection screen
"======================================================================
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS rb_prog RADIOBUTTON GROUP typ DEFAULT 'X' USER-COMMAND utyp.
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
    PARAMETERS rb_tr   RADIOBUTTON GROUP typ.
    SELECTION-SCREEN COMMENT 3(20) TEXT-013 FOR FIELD rb_tr.
    PARAMETERS p_task  TYPE trkorr                                     MODIF ID trq.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_diff AS CHECKBOX DEFAULT 'X'.
    SELECTION-SCREEN COMMENT 3(15) TEXT-020 FOR FIELD p_diff.
    PARAMETERS p_pane AS CHECKBOX DEFAULT ' '.
    SELECTION-SCREEN COMMENT 3(10) TEXT-021 FOR FIELD p_pane.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b2.

"======================================================================

INITIALIZATION.
  PERFORM supress_button.

  "======================================================================

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
    ENDCASE.
    MODIFY SCREEN.
  ENDLOOP.

  "======================================================================

AT SELECTION-SCREEN.
  CHECK sy-ucomm <> 'DUMMY'.
  PERFORM run_ave.

  "======================================================================
FORM supress_button.
  DATA itab TYPE TABLE OF sy-ucomm.
  APPEND 'ONLI' TO itab.
  CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
    EXPORTING
      p_status  = sy-pfkey
    TABLES
      p_exclude = itab.
ENDFORM.

"======================================================================
FORM run_ave.
  " Open popup only when the user pressed Enter (ucomm is initial)
  CHECK sy-ucomm IS INITIAL.

  TRY.
      DATA(lv_show_diff) = CONV abap_bool( p_diff ).
      DATA(lv_two_pane)  = CONV abap_bool( p_pane ).

      IF rb_prog = 'X' AND p_prog IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-program
          i_object_name = CONV #( p_prog )
          i_show_diff   = lv_show_diff
          i_two_pane    = lv_two_pane ).

      ELSEIF rb_clas = 'X' AND p_clas IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-class
          i_object_name = CONV #( p_clas )
          i_show_diff   = lv_show_diff
          i_two_pane    = lv_two_pane ).

      ELSEIF rb_func = 'X' AND p_func IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-function
          i_object_name = CONV #( p_func )
          i_show_diff   = lv_show_diff
          i_two_pane    = lv_two_pane ).

      ELSEIF rb_tr = 'X' AND p_task IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-tr
          i_object_name = CONV #( p_task )
          i_show_diff   = lv_show_diff
          i_two_pane    = lv_two_pane ).

      ELSE.
        MESSAGE 'Please enter an object name.' TYPE 'W'.
        RETURN.
      ENDIF.

      go_popup->show( ).

    CATCH zcx_ave INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.
