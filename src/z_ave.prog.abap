*&---------------------------------------------------------------------*
*& Report Z_AVE  –  Abap Versions Explorer
*&---------------------------------------------------------------------*
REPORT z_ave.

"══════════════════════════════════════════════════════════════════════
" Selection screen
"══════════════════════════════════════════════════════════════════════
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

  " ── Object type radio buttons ──────────────────────────────────────
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS rb_prog RADIOBUTTON GROUP typ DEFAULT 'X'
               USER-COMMAND utyp MODIF ID typ.
    SELECTION-SCREEN COMMENT 3(20) TEXT-010 FOR FIELD rb_prog.
    PARAMETERS rb_clas RADIOBUTTON GROUP typ MODIF ID typ.
    SELECTION-SCREEN COMMENT 3(10) TEXT-011 FOR FIELD rb_clas.
    PARAMETERS rb_func RADIOBUTTON GROUP typ MODIF ID typ.
    SELECTION-SCREEN COMMENT 3(20) TEXT-012 FOR FIELD rb_func.
    PARAMETERS rb_tr   RADIOBUTTON GROUP typ MODIF ID typ.
    SELECTION-SCREEN COMMENT 3(20) TEXT-013 FOR FIELD rb_tr.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN SKIP 1.

  " ── Input fields (shown/hidden by MODIF ID) ────────────────────────
  PARAMETERS p_prog  TYPE progname    MATCHCODE OBJECT progname    MODIF ID prg.
  PARAMETERS p_clas  TYPE seoclsname  MATCHCODE OBJECT sfbeclname  MODIF ID cls.
  PARAMETERS p_func  TYPE rs38l_fnam  MATCHCODE OBJECT cacs_function MODIF ID fnc.
  PARAMETERS p_tr    TYPE trkorr                                    MODIF ID trq.

SELECTION-SCREEN END OF BLOCK b1.

"══════════════════════════════════════════════════════════════════════
INITIALIZATION.
  PERFORM supress_button.

"══════════════════════════════════════════════════════════════════════
AT SELECTION-SCREEN OUTPUT.
  " Show only the field that belongs to the selected radio button
  LOOP AT SCREEN.
    CASE screen-group1.
      WHEN 'PRG'. screen-active = boolc( rb_prog = 'X' ).
      WHEN 'CLS'. screen-active = boolc( rb_clas = 'X' ).
      WHEN 'FNC'. screen-active = boolc( rb_func = 'X' ).
      WHEN 'TRQ'. screen-active = boolc( rb_tr   = 'X' ).
    ENDCASE.
    MODIFY SCREEN.
  ENDLOOP.

"══════════════════════════════════════════════════════════════════════
AT SELECTION-SCREEN.
  CHECK sy-ucomm <> 'DUMMY'.
  PERFORM run_ave.

"══════════════════════════════════════════════════════════════════════
FORM supress_button.
  DATA itab TYPE TABLE OF sy-ucomm.
  APPEND 'ONLI' TO itab.
  CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
    EXPORTING
      p_status  = sy-pfkey
    TABLES
      p_exclude = itab.
ENDFORM.

"══════════════════════════════════════════════════════════════════════
FORM run_ave.
  " Only open window when the user pressed Enter (ucomm is initial)
  CHECK sy-ucomm IS INITIAL.

  TRY.
      DATA lo_popup TYPE REF TO zcl_ave_popup.

      IF rb_prog = 'X' AND p_prog IS NOT INITIAL.
        CREATE OBJECT lo_popup
          EXPORTING
            i_object_type = zcl_ave_object_factory=>gc_type-program
            i_object_name = p_prog.

      ELSEIF rb_clas = 'X' AND p_clas IS NOT INITIAL.
        CREATE OBJECT lo_popup
          EXPORTING
            i_object_type = zcl_ave_object_factory=>gc_type-class
            i_object_name = p_clas.

      ELSEIF rb_func = 'X' AND p_func IS NOT INITIAL.
        CREATE OBJECT lo_popup
          EXPORTING
            i_object_type = zcl_ave_object_factory=>gc_type-function
            i_object_name = p_func.

      ELSEIF rb_tr = 'X' AND p_tr IS NOT INITIAL.
        CREATE OBJECT lo_popup
          EXPORTING
            i_object_type = zcl_ave_object_factory=>gc_type-tr
            i_object_name = p_tr.

      ELSE.
        MESSAGE 'Please enter an object name.' TYPE 'W'.
        RETURN.
      ENDIF.

      lo_popup->show( ).

    CATCH zcx_ave INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.
