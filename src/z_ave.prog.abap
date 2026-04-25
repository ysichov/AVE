REPORT z_ave. " AVE - Abap Versions Explorer
" & Multi-windows program for ABAP object version comparison
" &----------------------------------------------------------------------
" & version: 1.00
" & Git https://github.com/ysichov/AVE

" & Written by Yurii Sychov
" & e-mail:   ysichov@gmail.com
" & blog:     https://ysychov.wordpress.com/blog/
" & LinkedIn: https://www.linkedin.com/in/ysychov/

" &Inspired by https://github.com/abapinho/abapTimeMachine , Eclipse Adt, GitHub and all others similar tools
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

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS rb_pack RADIOBUTTON GROUP typ.
SELECTION-SCREEN COMMENT 3(20) TEXT-014 FOR FIELD rb_pack.
PARAMETERS p_pack  TYPE devclass   MATCHCODE OBJECT devclass       MODIF ID pck.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-015.

PARAMETERS p_diff AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_pane AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_ntoc AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_cmpct AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_rmdp  AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_blame AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_user TYPE versuser.
PARAMETERS p_datefr TYPE versdate.

SELECTION-SCREEN END OF BLOCK b2.

"======================================================================

INITIALIZATION.
  p_user = sy-uname.
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
      WHEN 'PCK'.
        screen-input = COND #( WHEN rb_pack = 'X' THEN 1 ELSE 0 ).
    ENDCASE.
    IF screen-name = 'P_PANE' OR screen-name = 'P_CMPCT'.
      screen-input = COND #( WHEN p_diff = 'X' THEN 1 ELSE 0 ).
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.

  "======================================================================

AT SELECTION-SCREEN ON p_diff.
  " Trigger OUTPUT to re-evaluate enabled state of dependent checkboxes

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
      DATA(ls_settings) = VALUE zif_ave_object=>ty_settings(
        show_diff   = CONV #( p_diff )
        two_pane    = CONV #( p_pane )
        no_toc      = CONV #( p_ntoc )
        compact     = CONV #( p_cmpct )
        remove_dup  = CONV #( p_rmdp )
        blame       = CONV #( p_blame )
        filter_user = p_user
        date_from   = p_datefr ).

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

      ELSE.
        MESSAGE 'Please enter an object name.' TYPE 'W'.
        RETURN.
      ENDIF.

      go_popup->show( ).

    CATCH zcx_ave INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.
