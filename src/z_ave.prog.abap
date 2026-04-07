*&---------------------------------------------------------------------*
*& Report Z_AVE
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT Z_AVE.

SELECTION-SCREEN BEGIN OF BLOCK s1 WITH FRAME TITLE TEXT-004.
    SELECTION-SCREEN BEGIN OF LINE.
      SELECTION-SCREEN COMMENT (29) TEXT-002 FOR FIELD p_prog.
      SELECTION-SCREEN POSITION 33.
      PARAMETERS: p_prog  TYPE progname MATCHCODE OBJECT progname MODIF ID prg.
      SELECTION-SCREEN COMMENT (70) TEXT-001 FOR FIELD p_prog.
    SELECTION-SCREEN END OF LINE.
    PARAMETERS: p_class  TYPE seoclsname MATCHCODE OBJECT sfbeclname.
    PARAMETERS: p_func  TYPE seoclsname MATCHCODE OBJECT cacs_function.
  SELECTION-SCREEN END OF BLOCK s1.

  PARAMETERS: n_parser NO-DISPLAY. "AS CHECKBOX DEFAULT ' '.
  PARAMETERS: n_time NO-DISPLAY . "AS CHECKBOX DEFAULT ' ' .

  SELECTION-SCREEN SKIP.

  INITIALIZATION.

    PERFORM supress_button. "supressing F8 button
    DATA itab TYPE TABLE OF sy-ucomm.

    APPEND: 'ONLI' TO itab.
    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        p_status  = sy-pfkey
      TABLES
        p_exclude = itab.


  " Resolve class name to generated class/interface program
  AT SELECTION-SCREEN ON p_class.

    IF p_class IS NOT INITIAL.
      SELECT SINGLE clstype INTO @DATA(clstype)
        FROM seoclass
       WHERE clsname = @p_class.
      IF sy-subrc = 0.

        p_prog = p_class && repeat( val = `=` occ = 30 - strlen( p_class ) ).
        IF clstype = '1'.
          p_prog = p_prog && 'IP'.
        ELSE.
          p_prog = p_prog && 'CP'.
        ENDIF.
      ENDIF.

    ENDIF.


  " Resolve function module to generated include program
  AT SELECTION-SCREEN ON p_func.

    IF p_func IS NOT INITIAL.
      SELECT SINGLE pname, include INTO ( @DATA(func_incl), @DATA(incl_num) )
        FROM tfdir
       WHERE funcname = @p_func.

      IF sy-subrc = 0.
        SHIFT func_incl LEFT BY 3 PLACES.
        p_prog = func_incl && 'U' && incl_num.
      ENDIF.

    ENDIF.

  " Trigger ACE execution after selection-screen validation
  AT SELECTION-SCREEN.

    CHECK sy-ucomm <> 'DUMMY'.
    PERFORM run_ave.


  FORM supress_button. "supressing F8 button

    DATA itab TYPE TABLE OF sy-ucomm.

    APPEND: 'ONLI' TO itab.
    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        p_status  = sy-pfkey
      TABLES
        p_exclude = itab.
  ENDFORM.

  " Run AVE only when target program exists in repository
  FORM run_ave.

    CHECK sy-ucomm IS INITIAL.

  ENDFORM.
