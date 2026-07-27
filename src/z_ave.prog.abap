REPORT z_ave. " AVE - Abap Versions Explorer/Code Reviewer
" & Multi-windows program for ABAP object version comparison
" &----------------------------------------------------------------------
" & version: 2.00 beta
" & Git https://github.com/ysichov/AVE

" & Written by Yurii Sychov
" & e-mail:   ysichov@gmail.com
" & blog:     https://ysychov.wordpress.com/blog/
" & LinkedIn: https://www.linkedin.com/in/ysychov/

" &Inspired by https://github.com/abapinho/abapTimeMachine , Eclipse Adt, GitHub and all others similar tools
" &----------------------------------------------------------------------

DATA: go_popup TYPE REF TO zcl_ave_popup,
      gv_task  TYPE trkorr.

SELECTION-SCREEN BEGIN OF BLOCK b_mode WITH FRAME TITLE TEXT-020.
PARAMETERS: p_cr RADIOBUTTON GROUP mode  USER-COMMAND umod DEFAULT 'X'.
PARAMETERS: p_ve RADIOBUTTON GROUP mode .
SELECT-OPTIONS: s_task FOR gv_task NO INTERVALS.
PARAMETERS p_itask AS CHECKBOX DEFAULT abap_true.
PARAMETERS p_sys TYPE verssysnam.
PARAMETERS p_blame AS CHECKBOX DEFAULT abap_true.
SELECTION-SCREEN END OF BLOCK b_mode.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS rb_tr   RADIOBUTTON  GROUP typ USER-COMMAND utyp DEFAULT 'X'.
SELECTION-SCREEN COMMENT 3(20) TEXT-013 FOR FIELD rb_tr.
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

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS rb_fugr RADIOBUTTON GROUP typ.
SELECTION-SCREEN COMMENT 3(20) TEXT-019 FOR FIELD rb_fugr.
PARAMETERS p_fugr  TYPE rs38l_area MATCHCODE OBJECT vrm_fugr        MODIF ID fgr.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS rb_tabd RADIOBUTTON GROUP typ.
SELECTION-SCREEN COMMENT 3(20) TEXT-024 FOR FIELD rb_tabd.
PARAMETERS p_tabd  TYPE tabname                                       MODIF ID tbd.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS rb_doma RADIOBUTTON GROUP typ.
SELECTION-SCREEN COMMENT 3(20) TEXT-025 FOR FIELD rb_doma.
PARAMETERS p_doma  TYPE domname                                       MODIF ID dom.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS rb_dtel RADIOBUTTON GROUP typ.
SELECTION-SCREEN COMMENT 3(20) TEXT-026 FOR FIELD rb_dtel.
PARAMETERS p_dtel  TYPE rollname                                      MODIF ID dte.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-015.
PARAMETERS p_cmpct AS CHECKBOX DEFAULT abap_true.
PARAMETERS p_pane AS CHECKBOX.
PARAMETERS p_layout AS CHECKBOX DEFAULT abap_true.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-016.
PARAMETERS p_datefr TYPE versdate.
PARAMETERS p_user TYPE versuser.
PARAMETERS p_diff NO-DISPLAY DEFAULT abap_true.
PARAMETERS p_rmdp  AS CHECKBOX.
PARAMETERS p_ntoc AS CHECKBOX.
PARAMETERS p_icase  AS CHECKBOX DEFAULT abap_true.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-022.
PARAMETERS: p_anth RADIOBUTTON GROUP api DEFAULT 'X',
            p_oai  RADIOBUTTON GROUP api.

PARAMETERS: p_dest   TYPE text255 MEMORY ID dest,
              p_model  TYPE text255 MEMORY ID model,
              p_apikey TYPE text255 MEMORY ID api.

" Output cap per request. Matters most with a review profile that has a schema:
" hitting the cap truncates the answer mid-JSON and nothing parses.
PARAMETERS p_maxtok TYPE i DEFAULT 20000.

" Review profiles: a frontend folder holding <profile>.md (system prompt) and
" optional <profile>.json (output schema) — see ZCL_AVE_AI_PROMPTS.
PARAMETERS: p_ppath TYPE text255 MEMORY ID ppt,
            p_prof  TYPE text255 MEMORY ID prf.

SELECTION-SCREEN END OF BLOCK b4.

*SELECTION-SCREEN BEGIN OF BLOCK b5 WITH FRAME TITLE TEXT-023.
*SELECTION-SCREEN END OF BLOCK b5.

"Events

INITIALIZATION.
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
      WHEN 'FGR'.
        screen-input = COND #( WHEN rb_fugr = 'X' THEN 1 ELSE 0 ).
      WHEN 'TBD'.
        screen-input = COND #( WHEN rb_tabd = 'X' THEN 1 ELSE 0 ).
      WHEN 'DOM'.
        screen-input = COND #( WHEN rb_doma = 'X' THEN 1 ELSE 0 ).
      WHEN 'DTE'.
        screen-input = COND #( WHEN rb_dtel = 'X' THEN 1 ELSE 0 ).
    ENDCASE.
    IF screen-name = 'P_PANE' OR screen-name = 'P_CMPCT'.
      screen-input = COND #( WHEN p_diff = 'X' THEN 1 ELSE 0 ).
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_ppath.
  PERFORM f4_prompt_folder.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_prof.
  PERFORM f4_prompt_profile.

AT SELECTION-SCREEN ON p_diff.
  " Trigger OUTPUT to re-evaluate enabled state of dependent checkboxes

AT SELECTION-SCREEN.
  CHECK sy-ucomm <> 'DUMMY'.
  PERFORM run_ave.

FORM f4_prompt_folder.
  DATA lv_folder TYPE string.
  cl_gui_frontend_services=>directory_browse(
    EXPORTING
      window_title    = 'Review profiles folder'
      initial_folder  = CONV string( p_ppath )
    CHANGING
      selected_folder = lv_folder
    EXCEPTIONS
      OTHERS          = 1 ).
  CHECK sy-subrc = 0 AND lv_folder IS NOT INITIAL.
  p_ppath = lv_folder.
ENDFORM.

FORM f4_prompt_profile.
  " The list is the *.md files in the folder — the profile name is what the
  " prompt file and its optional schema file share.
  DATA(lo_prompts) = NEW zcl_ave_ai_prompts( CONV string( p_ppath ) ).
  DATA(lt_profiles) = lo_prompts->list_profiles( ).
  IF lt_profiles IS INITIAL.
    MESSAGE 'No *.md profiles found in that folder' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  TYPES: BEGIN OF ty_f4,
           profile TYPE text255,
         END OF ty_f4.
  DATA lt_f4 TYPE STANDARD TABLE OF ty_f4 WITH DEFAULT KEY.
  LOOP AT lt_profiles INTO DATA(lv_profile).
    APPEND VALUE #( profile = lv_profile ) TO lt_f4.
  ENDLOOP.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield        = 'PROFILE'
      dynpprog        = sy-repid
      dynpnr          = sy-dynnr
      dynprofield     = 'P_PROF'
      value_org       = 'S'
    TABLES
      value_tab       = lt_f4
    EXCEPTIONS
      parameter_error = 1
      no_values_found = 2
      OTHERS          = 3.
ENDFORM.

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
        " One checkbox drives both: the ignore-indent post-pass in COMPUTE_DIFF
        " upper-cases as it compares, so "ignore case" alone had no effect on the
        " line diff. Splitting them only produced a combination that did nothing.
        ignore_case   = CONV #( p_icase )
        ignore_indent = CONV #( p_icase )
        compact     = CONV #( p_cmpct )
        remove_dup  = CONV #( p_rmdp )
        blame       = CONV #( p_blame )
        filter_user = p_user
        date_from   = p_datefr
        code_review = CONV #( p_cr )
        system      = p_sys
        destination = p_dest
        model = p_model
        apikey = p_apikey
        provider = COND string( WHEN p_oai = 'X' THEN 'OPENAI' ELSE 'ANTHROPIC' )
        prompt_path    = p_ppath
        prompt_profile = p_prof
        max_tokens     = p_maxtok
        filter_korrnum = COND #( WHEN s_task[] IS NOT INITIAL THEN s_task[ 1 ]-low )
        filter_korrnums = s_task[]
        include_tasks   = CONV #( p_itask ) ).

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

      ELSEIF rb_tr = 'X' AND s_task[] IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-tr
          i_object_name = CONV #( s_task[ 1 ]-low )
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

      ELSEIF rb_fugr = 'X' AND p_fugr IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-fugr
          i_object_name = CONV #( p_fugr )
          is_settings   = ls_settings ).

      ELSEIF rb_tabd = 'X' AND p_tabd IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-tabd
          i_object_name = CONV #( p_tabd )
          is_settings   = ls_settings ).

      ELSEIF rb_doma = 'X' AND p_doma IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-doma
          i_object_name = CONV #( p_doma )
          is_settings   = ls_settings ).

      ELSEIF rb_dtel = 'X' AND p_dtel IS NOT INITIAL.
        go_popup = NEW zcl_ave_popup(
          i_object_type = zcl_ave_object_factory=>gc_type-dtel
          i_object_name = CONV #( p_dtel )
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
