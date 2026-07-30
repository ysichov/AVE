CLASS zcl_ave_popup_diff_view DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES ty_version_row TYPE zif_ave_popup_types=>ty_version_row.
    TYPES ty_t_version_row TYPE zif_ave_popup_types=>ty_t_version_row.

    TYPES:
      BEGIN OF ty_options,
        blame          TYPE abap_bool,
        two_pane       TYPE abap_bool,
        compact        TYPE abap_bool,
        debug          TYPE abap_bool,
        ignore_case    TYPE abap_bool,
      END OF ty_options.

    TYPES:
      BEGIN OF ty_result,
        html          TYPE string,
        diff          TYPE zif_ave_popup_types=>ty_t_diff,
        blame         TYPE zif_ave_popup_types=>ty_blame_map,
        blame_deleted TYPE zif_ave_popup_types=>ty_blame_map,
        huge_source   TYPE abap_bool,
        title         TYPE string,
        meta          TYPE string,
        stopped       TYPE abap_bool,
      END OF ty_result.

    CLASS-METHODS render
      IMPORTING
        is_old            TYPE ty_version_row OPTIONAL
        is_new            TYPE ty_version_row
        it_versions       TYPE ty_t_version_row
        is_options        TYPE ty_options
      RETURNING
        VALUE(result)     TYPE ty_result.

  PRIVATE SECTION.
    CLASS-METHODS load_source
      IMPORTING
        is_version       TYPE ty_version_row
      RETURNING
        VALUE(result)    TYPE abaptxt255_tab.
ENDCLASS.


CLASS zcl_ave_popup_diff_view IMPLEMENTATION.

  METHOD render.
    DATA(lv_has_old) = xsdbool( is_old IS NOT INITIAL ).
    result-title = |{ is_new-objtype }: { is_new-objname }|.

    " Dictionary tables get a dedicated structured field-level comparison
    " instead of the line-based source diff.
    IF is_new-objtype = 'TABD'.
      result-meta = COND string(
        WHEN lv_has_old = abap_false THEN |{ is_new-versno_text } → (new object)|
        ELSE |{ is_new-versno_text } → { is_old-versno_text }| ).
      TRY.
          DATA ls_tabd_old TYPE zif_ave_popup_types=>ty_tabd.
          IF lv_has_old = abap_true.
            ls_tabd_old = zcl_ave_version2=>get_tabd(
              iv_objname = is_old-objname
              iv_versno  = is_old-versno
              iv_system  = is_old-system ).
          ENDIF.
          DATA(ls_tabd_new) = zcl_ave_version2=>get_tabd(
            iv_objname = is_new-objname
            iv_versno  = is_new-versno
            iv_system  = is_new-system ).
          result-html = zcl_ave_popup_html=>tabd_diff_to_html(
            is_old  = ls_tabd_old
            is_new  = ls_tabd_new
            i_title = result-title
            i_meta  = result-meta ).
        CATCH zcx_ave.
          result-html = |<html><body style="padding:24px;font:13px Consolas;color:#c00">| &&
            |Error loading table definition for comparison.</body></html>|.
      ENDTRY.
      RETURN.
    ENDIF.

    " Dictionary domains get a dedicated structured fixed-value comparison
    " instead of the line-based source diff.
    IF is_new-objtype = 'DOMD'.
      result-meta = COND string(
        WHEN lv_has_old = abap_false THEN |{ is_new-versno_text } → (new object)|
        ELSE |{ is_new-versno_text } → { is_old-versno_text }| ).
      TRY.
          DATA ls_doma_old TYPE zif_ave_popup_types=>ty_doma.
          IF lv_has_old = abap_true.
            ls_doma_old = zcl_ave_version2=>get_doma(
              iv_objname = is_old-objname
              iv_versno  = is_old-versno
              iv_system  = is_old-system ).
          ENDIF.
          DATA(ls_doma_new) = zcl_ave_version2=>get_doma(
            iv_objname = is_new-objname
            iv_versno  = is_new-versno
            iv_system  = is_new-system ).
          result-html = zcl_ave_popup_html=>doma_diff_to_html(
            is_old  = ls_doma_old
            is_new  = ls_doma_new
            i_title = result-title
            i_meta  = result-meta ).
        CATCH zcx_ave.
          result-html = |<html><body style="padding:24px;font:13px Consolas;color:#c00">| &&
            |Error loading domain definition for comparison.</body></html>|.
      ENDTRY.
      RETURN.
    ENDIF.

    " Data elements get a dedicated structured attribute comparison
    " instead of the line-based source diff.
    IF is_new-objtype = 'DTED'.
      result-meta = COND string(
        WHEN lv_has_old = abap_false THEN |{ is_new-versno_text } → (new object)|
        ELSE |{ is_new-versno_text } → { is_old-versno_text }| ).
      TRY.
          DATA ls_dtel_old TYPE zif_ave_popup_types=>ty_dtel.
          IF lv_has_old = abap_true.
            ls_dtel_old = zcl_ave_version2=>get_dtel(
              iv_objname = is_old-objname
              iv_versno  = is_old-versno
              iv_system  = is_old-system ).
          ENDIF.
          DATA(ls_dtel_new) = zcl_ave_version2=>get_dtel(
            iv_objname = is_new-objname
            iv_versno  = is_new-versno
            iv_system  = is_new-system ).
          result-html = zcl_ave_popup_html=>dtel_diff_to_html(
            is_old  = ls_dtel_old
            is_new  = ls_dtel_new
            i_title = result-title
            i_meta  = result-meta ).
        CATCH zcx_ave.
          result-html = |<html><body style="padding:24px;font:13px Consolas;color:#c00">| &&
            |Error loading data element definition for comparison.</body></html>|.
      ENDTRY.
      RETURN.
    ENDIF.

    DATA lt_src_o TYPE abaptxt255_tab.
    IF lv_has_old = abap_true.
      lt_src_o = load_source( is_old ).
    ENDIF.

    DATA(lt_src_n) = load_source( is_new ).

    zcl_ave_progress=>reset_stop( ).
    DATA(lt_diff) = zcl_ave_popup_diff=>compute_diff(
      it_old           = lt_src_o
      it_new           = lt_src_n
      i_title          = result-title
      i_confirm_key    = |DIFF~{ is_new-objtype }~{ is_new-objname }|
      i_ignore_case    = is_options-ignore_case ).
    IF zcl_ave_progress=>was_stop_requested( ) = abap_true.
      result-stopped = abap_true.
      RETURN.
    ENDIF.

    DATA(lv_meta) = COND string(
      WHEN lv_has_old = abap_false THEN |{ is_new-versno_text } → (new object)|
      ELSE |{ is_new-versno_text } → { is_old-versno_text }| ).

    result-meta = lv_meta.

    DATA lt_blame         TYPE zif_ave_popup_types=>ty_blame_map.
    DATA lt_blame_deleted TYPE zif_ave_popup_types=>ty_blame_map.
    IF is_options-blame = abap_true.
      zcl_ave_progress=>reset_stop( ).
      lt_blame = zcl_ave_popup_diff=>build_blame_map(
        EXPORTING
          it_versions      = it_versions
          i_objtype        = is_new-objtype
          i_objname        = is_new-objname
          i_from           = is_old-versno
          i_to             = is_new-versno
          i_title          = result-title
        IMPORTING
          et_blame_deleted = lt_blame_deleted ).
      IF zcl_ave_progress=>was_stop_requested( ) = abap_true.
        result-stopped = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    result-diff          = lt_diff.
    result-blame         = lt_blame.
    result-blame_deleted = lt_blame_deleted.
    DATA(lv_huge_source) = xsdbool( lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000 ).
    result-huge_source = lv_huge_source.

    IF is_options-debug = abap_true.
      result-html = zcl_ave_popup_html=>debug_diff_html(
        it_diff = lt_diff
        i_title = result-title
        i_meta  = lv_meta ).
    ELSE.
      result-html = zcl_ave_popup_html=>diff_to_html(
        it_diff          = lt_diff
        i_title          = result-title
        i_meta           = lv_meta
        i_two_pane       = is_options-two_pane
        i_compact        = COND #( WHEN lv_huge_source = abap_true THEN abap_true ELSE is_options-compact )
        i_plain          = lv_huge_source
        i_ignore_case    = is_options-ignore_case
        it_blame         = lt_blame
        it_blame_deleted = lt_blame_deleted ).
    ENDIF.
  ENDMETHOD.


  METHOD load_source.
    IF is_version-system IS NOT INITIAL.
      result = zcl_ave_version2=>get_source_remote(
        iv_objtype = is_version-objtype
        iv_objname = is_version-objname
        iv_versno  = is_version-versno
        iv_system  = is_version-system ).
    ELSE.
      result = zcl_ave_version2=>get_source_local_compat(
        iv_objtype = is_version-objtype
        iv_objname = is_version-objname
        iv_versno  = is_version-versno
        iv_korrnum = is_version-korrnum
        iv_author  = is_version-author
        iv_datum   = is_version-datum
        iv_zeit    = is_version-zeit ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
