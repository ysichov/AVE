CLASS zcl_ave_acr_precompute DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES ty_part_row TYPE zif_ave_popup_types=>ty_part_row.
    TYPES ty_version_row TYPE zif_ave_popup_types=>ty_version_row.
    TYPES ty_t_version_row TYPE zif_ave_popup_types=>ty_t_version_row.
    TYPES ty_diff_op TYPE zif_ave_popup_types=>ty_diff_op.
    TYPES ty_t_diff TYPE zif_ave_popup_types=>ty_t_diff.
    TYPES ty_blame_map TYPE zif_ave_popup_types=>ty_blame_map.

    TYPES:
      BEGIN OF ty_options,
        date_from              TYPE versdate,
        remove_dup             TYPE abap_bool,
        no_toc                 TYPE abap_bool,
        ignore_case            TYPE abap_bool,
        ignore_indent          TYPE abap_bool,
        filter_korrnum         TYPE trkorr,
        filter_korrnums        TYPE zif_ave_object=>ty_t_korr_range,
        filter_parent_korrnums TYPE zif_ave_object=>ty_t_korr_range,
        system                 TYPE verssysnam,
        filter_user            TYPE versuser,
        blame                  TYPE abap_bool,
        two_pane               TYPE abap_bool,
        compact                TYPE abap_bool,
        debug                  TYPE abap_bool,
      END OF ty_options.

    CLASS-METHODS precompute_part
      IMPORTING
        is_part       TYPE ty_part_row
        is_options    TYPE ty_options
      CHANGING
        ct_versions   TYPE ty_t_version_row
        ct_acr_stats  TYPE zif_ave_acr_types=>ty_t_obj_stats
        ct_hunk_info  TYPE zif_ave_acr_types=>ty_t_hunk_info
        ct_diff_cache TYPE zif_ave_acr_types=>ty_t_diff_cache
        ct_diff_data  TYPE zif_ave_acr_types=>ty_t_diff_data
        ct_cr_diag    TYPE string_table.

    CLASS-METHODS precompute_class_parts
      IMPORTING
        iv_class_name TYPE seoclsname
        is_options    TYPE ty_options
      CHANGING
        ct_versions   TYPE ty_t_version_row
        ct_acr_stats  TYPE zif_ave_acr_types=>ty_t_obj_stats
        ct_hunk_info  TYPE zif_ave_acr_types=>ty_t_hunk_info
        ct_diff_cache TYPE zif_ave_acr_types=>ty_t_diff_cache
        ct_diff_data  TYPE zif_ave_acr_types=>ty_t_diff_data
        ct_cr_diag    TYPE string_table
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Builds retrofit (moving-violation) hunks from the remote->new diff.
    "! Self-contained: groups hunks, skips ones fully covered by the primary
    "! review, renders each hunk's html, and classifies the warning text.
    "! Public so the popup can regenerate hunk html on the fly at view time.
    CLASS-METHODS collect_retrofit_hunks
      IMPORTING
        is_part          TYPE ty_part_row
        it_diff          TYPE zif_ave_popup_types=>ty_t_diff
        it_review_lines  TYPE zif_ave_acr_types=>ty_review_lines
        iv_versno_new    TYPE versno
        iv_new_text      TYPE string
        iv_remote_versno TYPE versno
        iv_old_text      TYPE string
        iv_system        TYPE verssysnam
        iv_author        TYPE versuser
        iv_display_name  TYPE string
        iv_two_pane      TYPE abap_bool
        iv_ignore_case   TYPE abap_bool
      RETURNING
        VALUE(result)    TYPE zif_ave_acr_types=>ty_t_hunk_info.

  PRIVATE SECTION.
    CLASS-METHODS append_diag
      IMPORTING
        iv_text    TYPE string
      CHANGING
        ct_cr_diag TYPE string_table.

    "! Extracts the &lt;tr&gt; rows from a diff_to_html fragment.
    CLASS-METHODS extract_diff_rows
      IMPORTING
        iv_html       TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS load_versions
      IMPORTING
        iv_objtype        TYPE versobjtyp
        iv_objname        TYPE versobjnam
        is_options        TYPE ty_options
      EXPORTING
        ev_new_version    TYPE ty_version_row
        ev_old_version    TYPE ty_version_row
        ev_remote_version TYPE ty_version_row
      CHANGING
        ct_versions       TYPE ty_t_version_row.
ENDCLASS.


CLASS zcl_ave_acr_precompute IMPLEMENTATION.

  METHOD append_diag.
    CHECK iv_text IS NOT INITIAL.
    IF lines( ct_cr_diag ) < 300.
      APPEND iv_text TO ct_cr_diag.
    ENDIF.
  ENDMETHOD.


  METHOD load_versions.
    DATA(ls_result) = zcl_ave_version_list=>load(
      iv_objtype                = iv_objtype
      iv_objname                = iv_objname
      iv_date_from              = is_options-date_from
      iv_remove_dup             = is_options-remove_dup
      iv_no_toc                 = is_options-no_toc
      iv_ignore_case            = is_options-ignore_case
      iv_filter_korrnum         = is_options-filter_korrnum
      it_filter_korrnums        = is_options-filter_korrnums
      it_filter_parent_korrnums = is_options-filter_parent_korrnums
      iv_system                 = is_options-system ).

    ct_versions       = ls_result-versions.
    ev_new_version    = ls_result-new_version.
    ev_old_version    = ls_result-old_version.
    ev_remote_version = ls_result-remote_version.
  ENDMETHOD.


  METHOD precompute_class_parts.
    DATA(lv_before) = lines( ct_acr_stats ).
    append_diag(
      EXPORTING iv_text = |CLASS { iv_class_name }: expanding class parts|
      CHANGING  ct_cr_diag = ct_cr_diag ).
    TRY.
        DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
          object_type = zcl_ave_object_factory=>gc_type-class
          object_name = CONV #( iv_class_name ) ).
        DATA(lt_cr_parts) = lo_obj->get_parts( ).
        append_diag(
          EXPORTING iv_text = |CLASS { iv_class_name }: { lines( lt_cr_parts ) } part(s) found|
          CHANGING  ct_cr_diag = ct_cr_diag ).
        DATA(lv_cr_total) = lines( lt_cr_parts ).
        LOOP AT lt_cr_parts INTO DATA(ls_part).
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = CONV i( sy-tabix * 100 / COND i( WHEN lv_cr_total > 0 THEN lv_cr_total ELSE 1 ) )
                      text       = CONV char70( |Code Review: precomputing part { sy-tabix }/{ lv_cr_total }| ).
          IF ls_part-type = 'CLSD' OR ls_part-type = 'RELE'.
            append_diag(
              EXPORTING iv_text = |SKIP { ls_part-type } { ls_part-object_name }: class technical part is not reviewed directly|
              CHANGING  ct_cr_diag = ct_cr_diag ).
            CONTINUE.
          ENDIF.
          append_diag(
            EXPORTING iv_text = |CLASS PART { ls_part-type } { ls_part-object_name }: { ls_part-unit }|
            CHANGING  ct_cr_diag = ct_cr_diag ).
          precompute_part(
            EXPORTING
              is_part    = VALUE #(
                type        = ls_part-type
                name        = ls_part-unit
                class       = ls_part-class
                object_name = ls_part-object_name )
              is_options = is_options
            CHANGING
              ct_versions   = ct_versions
              ct_acr_stats  = ct_acr_stats
              ct_hunk_info  = ct_hunk_info
              ct_diff_cache = ct_diff_cache
              ct_diff_data  = ct_diff_data
              ct_cr_diag    = ct_cr_diag ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_class_parts).
        append_diag(
          EXPORTING iv_text = |SKIP CLAS { iv_class_name }: cannot expand class parts - { lx_class_parts->get_text( ) }|
          CHANGING  ct_cr_diag = ct_cr_diag ).
    ENDTRY.
    result = boolc( lines( ct_acr_stats ) > lv_before ).
  ENDMETHOD.


  METHOD precompute_part.
    IF is_part-type = 'CLAS'.
      append_diag(
        EXPORTING iv_text = |SKIP CLAS { is_part-object_name }: aggregate row has no direct diff source|
        CHANGING  ct_cr_diag = ct_cr_diag ).
      RETURN.
    ENDIF.

    DATA(ls_effective_part) = is_part.
    IF ls_effective_part-class IS INITIAL.
      CASE ls_effective_part-type.
        WHEN 'CPUB' OR 'CPRO' OR 'CPRI' OR 'CLSD' OR 'CINC' OR 'CDEF' OR 'METH'.
          DATA(lv_effective_objname) = CONV string( ls_effective_part-object_name ).
          FIND FIRST OCCURRENCE OF '=' IN lv_effective_objname MATCH OFFSET DATA(lv_effective_eq).
          IF sy-subrc = 0 AND lv_effective_eq > 0.
            ls_effective_part-class = CONV #( lv_effective_objname(lv_effective_eq) ).
          ELSEIF ls_effective_part-type <> 'METH'.
            ls_effective_part-class = CONV #( ls_effective_part-object_name ).
          ENDIF.
      ENDCASE.
    ENDIF.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING percentage = 0
                text       = CONV char70( |Code Review: loading versions for { is_part-object_name }| ).

    DATA ls_new    TYPE ty_version_row.
    DATA ls_old    TYPE ty_version_row.
    DATA ls_remote TYPE ty_version_row.
    load_versions(
      EXPORTING
        iv_objtype        = is_part-type
        iv_objname        = is_part-object_name
        is_options        = is_options
      IMPORTING
        ev_new_version    = ls_new
        ev_old_version    = ls_old
        ev_remote_version = ls_remote
      CHANGING
        ct_versions       = ct_versions ).
    append_diag(
      EXPORTING iv_text = |REMOTE { is_part-type } { is_part-object_name }: system={ ls_remote-system }, versno={ ls_remote-versno }, opt_sys={ is_options-system }|
      CHANGING  ct_cr_diag = ct_cr_diag ).
    IF ct_versions IS INITIAL
       AND ( is_options-filter_korrnum IS NOT INITIAL
          OR is_options-filter_korrnums IS NOT INITIAL
          OR is_options-filter_parent_korrnums IS NOT INITIAL ).
      append_diag(
        EXPORTING iv_text = |FALLBACK { is_part-type } { is_part-object_name }: no versions in selected request scope, probing active source|
        CHANGING  ct_cr_diag = ct_cr_diag ).
    ENDIF.
    DATA(lv_scope_korrnum) = is_options-filter_korrnum.
    IF lv_scope_korrnum IS INITIAL.
      READ TABLE is_options-filter_korrnums INTO DATA(ls_scope_korrnum) INDEX 1.
      IF sy-subrc = 0.
        lv_scope_korrnum = ls_scope_korrnum-low.
      ENDIF.
    ENDIF.
    IF lv_scope_korrnum IS INITIAL.
      READ TABLE is_options-filter_parent_korrnums INTO DATA(ls_scope_parent_korrnum) INDEX 1.
      IF sy-subrc = 0.
        lv_scope_korrnum = ls_scope_parent_korrnum-low.
      ENDIF.
    ENDIF.
    DATA lt_active_probe TYPE abaptxt255_tab.
    IF ct_versions IS INITIAL.
      lt_active_probe = zcl_ave_version2=>get_source_local_compat(
        iv_objtype = is_part-type
        iv_objname = is_part-object_name
        iv_versno  = zcl_ave_version=>c_version-active
        iv_korrnum = lv_scope_korrnum
        iv_author  = sy-uname
        iv_datum   = sy-datum
        iv_zeit    = sy-uzeit ).
      IF lt_active_probe IS INITIAL
         AND is_part-type = 'METH'
         AND is_part-class IS NOT INITIAL
         AND is_part-name IS NOT INITIAL.
        DATA lv_meth_cl_key TYPE seoclskey.
        DATA lt_meth_includes TYPE seop_methods_w_include.
        lv_meth_cl_key = is_part-class.
        CALL FUNCTION 'SEO_CLASS_GET_METHOD_INCLUDES'
          EXPORTING
            clskey   = lv_meth_cl_key
          IMPORTING
            includes = lt_meth_includes
          EXCEPTIONS
            _internal_class_not_existing = 1
            OTHERS                       = 2.
        IF sy-subrc = 0.
          LOOP AT lt_meth_includes INTO DATA(ls_meth_include).
            CHECK ls_meth_include-cpdkey-cpdname = is_part-name.
            READ REPORT ls_meth_include-incname INTO lt_active_probe.
            IF sy-subrc = 0 AND lt_active_probe IS NOT INITIAL.
              append_diag(
                EXPORTING iv_text = |NEW OBJECT { is_part-type } { is_part-object_name }: active method include { ls_meth_include-incname } read|
                CHANGING  ct_cr_diag = ct_cr_diag ).
            ENDIF.
            EXIT.
          ENDLOOP.
        ENDIF.
      ENDIF.
      IF lt_active_probe IS NOT INITIAL.
        DATA(lv_synth_trfunction) = VALUE e070-trfunction( ).
        IF lv_scope_korrnum IS NOT INITIAL.
          SELECT SINGLE trfunction
            FROM e070
            WHERE trkorr = @lv_scope_korrnum
            INTO @lv_synth_trfunction.
        ENDIF.
        APPEND VALUE ty_version_row(
          versno         = zcl_ave_version=>c_version-active
          versno_text    = `Active`
          datum          = sy-datum
          zeit           = sy-uzeit
          author         = sy-uname
          author_name    = zcl_ave_popup_data=>get_user_name( sy-uname )
          obj_owner      = sy-uname
          obj_owner_name = zcl_ave_popup_data=>get_user_name( sy-uname )
          korrnum        = lv_scope_korrnum
          task           = COND #( WHEN lv_synth_trfunction = 'S' THEN lv_scope_korrnum ELSE `` )
          objtype        = is_part-type
          objname        = is_part-object_name
          trfunction     = lv_synth_trfunction ) TO ct_versions.
        " load returned nothing so pair fields are empty; derive from synthetic row.
        IF ls_new IS INITIAL.
          READ TABLE ct_versions INTO ls_new INDEX 1.
        ENDIF.
        append_diag(
          EXPORTING iv_text = |NEW OBJECT { is_part-type } { is_part-object_name }: no versions, active source found|
          CHANGING  ct_cr_diag = ct_cr_diag ).
      ENDIF.
    ENDIF.
    IF ct_versions IS INITIAL.
      append_diag(
        EXPORTING iv_text = |SKIP { is_part-type } { is_part-object_name }: no versions after filters; filter TR={ is_options-filter_korrnum }, date_from={ is_options-date_from }|
        CHANGING  ct_cr_diag = ct_cr_diag ).
      RETURN.
    ENDIF.

    append_diag(
      EXPORTING iv_text = |VERS { is_part-type } { is_part-object_name }: { lines( ct_versions ) } version(s) after filters|
      CHANGING  ct_cr_diag = ct_cr_diag ).
    LOOP AT ct_versions INTO DATA(ls_vdiag).
      append_diag(
        EXPORTING iv_text = |  VER { ls_vdiag-versno_text }/{ ls_vdiag-versno } trf={ ls_vdiag-trfunction } korr={ ls_vdiag-korrnum } task={ ls_vdiag-task }|
        CHANGING  ct_cr_diag = ct_cr_diag ).
    ENDLOOP.
    append_diag(
      EXPORTING iv_text = |  >> PICKED new={ ls_new-versno_text }/{ ls_new-versno } trf={ ls_new-trfunction } korr={ ls_new-korrnum } | &&
                          |old={ ls_old-versno_text }/{ ls_old-versno } trf={ ls_old-trfunction } korr={ ls_old-korrnum }|
      CHANGING  ct_cr_diag = ct_cr_diag ).

    " Pair (ls_new / ls_old) comes from load_versions → zcl_ave_version_list=>load.
    " No separate select_diff_pair call; scope is derived once from user-selected K.
    CHECK ls_new IS NOT INITIAL.

    DATA(lv_is_created) = COND abap_bool( WHEN ls_old IS INITIAL THEN abap_true ELSE abap_false ).
    DATA(lv_versno_new) = ls_new-versno.
    DATA(lv_tadir_author) = VALUE versuser( ).

    DATA(lv_diag_old_pair) = COND string(
      WHEN ls_old IS INITIAL THEN `(empty/new object)`
      ELSE |{ ls_old-versno_text }/{ ls_old-versno }| ).
    append_diag(
      EXPORTING iv_text = |PAIR { is_part-type } { is_part-object_name }: new={ ls_new-versno_text }/{ lv_versno_new }, old={ lv_diag_old_pair }|
      CHANGING  ct_cr_diag = ct_cr_diag ).
    IF lv_is_created = abap_true.
      DATA(ls_author_lookup) = zcl_ave_acr_prepare=>get_created_object_author( is_part ).
      lv_tadir_author = ls_author_lookup-author.
      LOOP AT ls_author_lookup-diag_lines INTO DATA(lv_author_diag).
        append_diag(
          EXPORTING iv_text = lv_author_diag
          CHANGING  ct_cr_diag = ct_cr_diag ).
      ENDLOOP.
    ENDIF.

    DATA(lv_versno_old) = ls_old-versno.

    IF is_options-filter_user IS NOT INITIAL.
      DATA(lv_effective_author) = COND versuser(
        WHEN lv_is_created = abap_true AND lv_tadir_author IS NOT INITIAL THEN lv_tadir_author
        WHEN ls_new-obj_owner IS NOT INITIAL THEN ls_new-obj_owner
        ELSE ls_new-author ).
      IF lv_effective_author <> is_options-filter_user.
        append_diag(
          EXPORTING iv_text = |SKIP { is_part-type } { is_part-object_name }: author filter { is_options-filter_user }, effective author { lv_effective_author }|
          CHANGING  ct_cr_diag = ct_cr_diag ).
        RETURN.
      ENDIF.
    ENDIF.

    TRY.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 30
                    text       = CONV char70( |Code Review: loading new source for { is_part-object_name }| ).
        DATA(lt_src_n) = zcl_ave_version2=>get_source_local_compat(
          iv_objtype = is_part-type
          iv_objname = is_part-object_name
          iv_versno  = lv_versno_new
          iv_korrnum = ls_new-korrnum
          iv_author  = ls_new-author
          iv_datum   = ls_new-datum
          iv_zeit    = ls_new-zeit ).
        IF lt_src_n IS INITIAL
           AND lv_is_created = abap_true
           AND lt_active_probe IS NOT INITIAL.
          lt_src_n = lt_active_probe.
        ENDIF.
        DATA lt_src_o TYPE abaptxt255_tab.
        IF ls_old IS NOT INITIAL.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 40
                      text       = CONV char70( |Code Review: loading old source for { is_part-object_name }| ).
          IF ls_old-system IS NOT INITIAL.
            lt_src_o = zcl_ave_version2=>get_source_remote(
              iv_objtype = is_part-type
              iv_objname = is_part-object_name
              iv_versno  = lv_versno_old
              iv_system  = ls_old-system ).
          ELSE.
            lt_src_o = zcl_ave_version2=>get_source_local_compat(
              iv_objtype = is_part-type
              iv_objname = is_part-object_name
              iv_versno  = lv_versno_old
              iv_korrnum = ls_old-korrnum
              iv_author  = ls_old-author
              iv_datum   = ls_old-datum
              iv_zeit    = ls_old-zeit ).
          ENDIF.
        ENDIF.

        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 50
                    text       = CONV char70( |Code Review: computing diff for { is_part-object_name }| ).

        DATA lt_diff TYPE ty_t_diff.
        IF lv_is_created = abap_true.
          append_diag(
            EXPORTING iv_text = |NEW OBJECT { is_part-type } { is_part-object_name }: no K baseline, whole source is one review block|
            CHANGING  ct_cr_diag = ct_cr_diag ).
          LOOP AT lt_src_n INTO DATA(ls_new_object_line).
            APPEND VALUE ty_diff_op(
              op   = '+'
              text = CONV string( ls_new_object_line ) ) TO lt_diff.
          ENDLOOP.
        ELSE.
          zcl_ave_progress=>reset_stop( ).
          lt_diff = zcl_ave_popup_diff=>compute_diff(
            it_old        = lt_src_o
            it_new        = lt_src_n
            i_title       = CONV #( is_part-object_name )
            i_confirm_key = |DIFF~{ is_part-type }~{ is_part-object_name }|
            i_ignore_case = is_options-ignore_case ).
          IF zcl_ave_progress=>was_stop_requested( ) = abap_true.
            RETURN.
          ENDIF.
        ENDIF.

        IF lv_is_created = abap_true
           AND zcl_ave_acr_prepare=>is_comments_only( lt_src_n ) = abap_true.
          append_diag(
            EXPORTING iv_text = |SKIP { is_part-type } { is_part-object_name }: new object contains only comment lines|
            CHANGING  ct_cr_diag = ct_cr_diag ).
          RETURN.
        ENDIF.

        DATA lt_blame         TYPE ty_blame_map.
        DATA lt_blame_deleted TYPE ty_blame_map.
        IF is_options-blame = abap_true AND ls_old IS NOT INITIAL.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 65
                      text       = CONV char70( |Code Review: computing blame for { is_part-object_name }| ).
          zcl_ave_progress=>reset_stop( ).
          lt_blame = zcl_ave_popup_diff=>build_blame_map(
            EXPORTING it_versions      = ct_versions
                      i_objtype        = is_part-type
                      i_objname        = is_part-object_name
                      i_from           = lv_versno_old
                      i_to             = lv_versno_new
                      i_title          = |{ is_part-type }: { is_part-object_name }|
            IMPORTING et_blame_deleted = lt_blame_deleted ).
          IF zcl_ave_progress=>was_stop_requested( ) = abap_true.
            RETURN.
          ENDIF.
        ELSEIF is_options-blame = abap_true AND lv_is_created = abap_true.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING percentage = 65
                      text       = CONV char70( |Code Review: building blame for new object { is_part-object_name }| ).
          DATA(lv_new_obj_author) = COND versuser(
            WHEN lv_tadir_author IS NOT INITIAL THEN lv_tadir_author
            WHEN ls_new-obj_owner IS NOT INITIAL THEN ls_new-obj_owner
            ELSE ls_new-author ).
          DATA(lv_new_obj_author_name) = zcl_ave_popup_data=>get_user_name( lv_new_obj_author ).
          LOOP AT lt_src_n INTO DATA(ls_src_new_line).
            APPEND VALUE zif_ave_popup_types=>ty_blame_entry(
              text        = CONV string( ls_src_new_line )
              author      = lv_new_obj_author
              author_name = lv_new_obj_author_name
              datum       = ls_new-datum
              zeit        = ls_new-zeit
              versno_text = ls_new-versno_text
              korrnum     = ls_new-korrnum
              task        = ls_new-task
              task_text   = ls_new-korr_text ) TO lt_blame.
          ENDLOOP.
        ENDIF.

        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 75
                    text       = CONV char70( |Code Review: rendering diff for { is_part-object_name }| ).

        DATA(lv_meta_cr) = COND string(
          WHEN lv_is_created = abap_true
          THEN |{ ls_new-versno_text } → (new object)|
          ELSE |{ ls_new-versno_text } → { ls_old-versno_text }| ).
        " SINGLE DIFF SOURCE: code review now uses the SAME diff as the version
        " explorer (raw compute_diff output) instead of the CR-only moved-line
        " filter, so both stay byte-for-byte consistent.
        " DO NOT DELETE until tested — the move-detection step is kept here,
        " commented out, in case we want to restore it.
*        DATA(lt_review_diff) = zcl_ave_acr_hunk_html=>filter_moved_lines(
*          it_diff        = lt_diff
*          iv_ignore_case = is_options-ignore_case ).
        DATA(lt_review_diff) = lt_diff.
        DATA(lv_html) = zcl_ave_popup_html=>diff_to_html(
          it_diff          = lt_review_diff
          i_title          = |{ is_part-type }: { is_part-object_name }|
          i_meta           = lv_meta_cr
          i_two_pane       = is_options-two_pane
          i_compact        = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                     THEN abap_true ELSE is_options-compact )
          i_plain          = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                     THEN abap_true ELSE abap_false )
          i_ignore_case    = is_options-ignore_case
          i_code_review    = abap_true
          it_blame         = lt_blame
          it_blame_deleted = lt_blame_deleted ).
        DATA(lv_alt_two_pane) = xsdbool( is_options-two_pane = abap_false ).
        DATA(lv_alt_html) = zcl_ave_popup_html=>diff_to_html(
          it_diff          = lt_review_diff
          i_title          = |{ is_part-type }: { is_part-object_name }|
          i_meta           = lv_meta_cr
          i_two_pane       = lv_alt_two_pane
          i_compact        = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                     THEN abap_true ELSE is_options-compact )
          i_plain          = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                     THEN abap_true ELSE abap_false )
          i_ignore_case    = is_options-ignore_case
          i_code_review    = abap_true
          it_blame         = lt_blame
          it_blame_deleted = lt_blame_deleted ).

        DATA(lv_hunk_full_html) = COND string(
          WHEN is_options-two_pane = abap_true THEN lv_html
          ELSE lv_alt_html ).

        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING percentage = 85
                    text       = CONV char70( |Code Review: collecting hunks for { is_part-object_name }| ).

        DATA(lt_hunk_html) = zcl_ave_acr_hunk_html=>collect_rows(
          it_diff        = lt_review_diff
          iv_full_html   = lv_hunk_full_html
          iv_title       = |{ is_part-type }: { is_part-object_name }|
          iv_meta        = lv_meta_cr
          iv_two_pane    = abap_true
          iv_plain       = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                   THEN abap_true ELSE abap_false )
          iv_ignore_case = is_options-ignore_case
          iv_is_created  = lv_is_created
          it_blame         = lt_blame
          it_blame_deleted = lt_blame_deleted ).

        INSERT VALUE zif_ave_acr_types=>ty_diff_cache(
          key  = VALUE #(
            objtype     = is_part-type
            objname     = is_part-object_name
            versno_o    = lv_versno_old
            versno_n    = lv_versno_new
            blame         = is_options-blame
            two_pane      = is_options-two_pane
            compact       = is_options-compact
            debug         = is_options-debug
            ignore_case   = is_options-ignore_case
            ignore_indent = is_options-ignore_indent )
          html = lv_html )
          INTO TABLE ct_diff_cache.
        INSERT VALUE zif_ave_acr_types=>ty_diff_cache(
          key  = VALUE #(
            objtype       = is_part-type
            objname       = is_part-object_name
            versno_o      = lv_versno_old
            versno_n      = lv_versno_new
            blame         = is_options-blame
            two_pane      = lv_alt_two_pane
            compact       = is_options-compact
            debug         = is_options-debug
            ignore_case   = is_options-ignore_case
            ignore_indent = is_options-ignore_indent )
          html = lv_alt_html )
          INTO TABLE ct_diff_cache.
        INSERT VALUE zif_ave_acr_types=>ty_diff_data(
          key = VALUE #(
            objtype       = is_part-type
            objname       = is_part-object_name
            versno_o      = lv_versno_old
            versno_n      = lv_versno_new
            blame         = is_options-blame
            ignore_case   = is_options-ignore_case
            ignore_indent = is_options-ignore_indent )
          diff          = lt_review_diff
          blame_map     = lt_blame
          blame_deleted = lt_blame_deleted
          huge_source   = COND #( WHEN lines( lt_src_o ) > 10000 OR lines( lt_src_n ) > 10000
                                  THEN abap_true ELSE abap_false )
          title         = |{ is_part-type }: { is_part-object_name }|
          meta          = lv_meta_cr
          is_created    = lv_is_created )
          INTO TABLE ct_diff_data.

        DATA lv_ins TYPE i. DATA lv_del TYPE i. DATA lv_mod TYPE i.
        DATA lt_auth TYPE zif_ave_acr_types=>ty_t_author_stats.
        zcl_ave_acr_stats=>from_diff(
          EXPORTING it_diff    = lt_review_diff
                    it_blame   = lt_blame
          IMPORTING ev_ins     = lv_ins
                    ev_del     = lv_del
                    ev_mod     = lv_mod
                    et_authors = lt_auth ).

        DATA(lv_author) = COND versuser(
          WHEN lv_is_created = abap_true AND lv_tadir_author IS NOT INITIAL THEN lv_tadir_author
          WHEN ls_new-obj_owner IS NOT INITIAL THEN ls_new-obj_owner
          ELSE ls_new-author ).
        DATA(lv_datum)  = ls_new-datum.
        DATA(lv_zeit)   = ls_new-zeit.
        DATA(lv_disp_name) = CONV string( is_part-name ).

        DATA lv_hunk_cnt     TYPE i VALUE 0.
        DATA lv_stat_hunk_ins TYPE i VALUE 0.
        DATA lv_stat_hunk_mod TYPE i VALUE 0.
        DATA lv_stat_hunk_del TYPE i VALUE 0.
        DATA lt_part_hunk_info TYPE zif_ave_acr_types=>ty_t_hunk_info.

        DELETE ct_hunk_info WHERE objtype = is_part-type AND obj_name = is_part-object_name.
        zcl_ave_acr_hunk_info=>collect(
          EXPORTING
            is_part            = ls_effective_part
            it_diff            = lt_review_diff
            it_hunk_html       = lt_hunk_html
            it_blame           = lt_blame
            iv_author          = lv_author
            iv_display_name    = lv_disp_name
            iv_versno_new      = lv_versno_new
            iv_versno_old      = lv_versno_old
            iv_versno_new_text = ls_new-versno_text
            iv_versno_old_text = ls_old-versno_text
            iv_is_created      = lv_is_created
          IMPORTING
            et_hunk_info       = lt_part_hunk_info
            ev_hunk_count      = lv_hunk_cnt
            ev_hunk_ins        = lv_stat_hunk_ins
            ev_hunk_mod        = lv_stat_hunk_mod
            ev_hunk_del        = lv_stat_hunk_del ).
        INSERT LINES OF lt_part_hunk_info INTO TABLE ct_hunk_info.

        " Retrofit analysis: when a remote system is configured, compute a second
        " diff (remote -> new) and flag any hunk that is NOT part of the current
        " TR review. Such hunks signal code that will be overwritten or re-inserted
        " in the remote system after the transport is moved.
        " The remote row is a valid retrofit baseline whenever it points to any
        " readable remote version — either the version before our TR (if the TR was
        " already moved there) OR the remote ACTIVE state (99998), which is the
        " current production code our transport will overwrite once moved.
        " Keep-note: the previous logic excluded 00000/Active and treated it as "TR
        " not found -> object new -> skip retrofit". That was wrong: failing to match
        " our cross-system TR by korrnum does NOT mean the object is new in remote.
        " The genuinely-absent case is still caught downstream (empty remote source /
        " no common lines). Original guard kept below for reference:
        "DATA(lv_remote_has_ver) = xsdbool(
        "  ls_remote IS NOT INITIAL
        "  AND ls_remote-versno IS NOT INITIAL
        "  AND ls_remote-versno <> '00000'
        "  AND ls_remote-versno <> zcl_ave_version=>c_version-active ).
        DATA(lv_remote_has_ver) = xsdbool(
          ls_remote IS NOT INITIAL
          AND ls_remote-versno IS NOT INITIAL ).

        IF ls_remote IS NOT INITIAL AND lv_remote_has_ver = abap_false.
          " No readable remote version at all → nothing to compare against.
          append_diag(
            EXPORTING iv_text = |RFTR { is_part-type } { is_part-object_name }: no readable version in { ls_remote-system }, skipping retrofit|
            CHANGING  ct_cr_diag = ct_cr_diag ).
        ELSEIF ls_remote IS NOT INITIAL AND lv_is_created = abap_true.
          " A request is selected but there is no local baseline before it, so the
          " object is effectively new here → no retrofit comparison makes sense.
          append_diag(
            EXPORTING iv_text = |RFTR { is_part-type } { is_part-object_name }: no local baseline before the request (new object), skipping retrofit|
            CHANGING  ct_cr_diag = ct_cr_diag ).
        ELSEIF lv_remote_has_ver = abap_true AND lv_is_created = abap_false.
          TRY.
              CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
                EXPORTING percentage = 88
                          text       = CONV char70( |Code Review: retrofit analysis for { is_part-object_name }| ).

              DATA lt_src_rmt TYPE abaptxt255_tab.
              lt_src_rmt = zcl_ave_version2=>get_source_remote(
                iv_objtype = is_part-type
                iv_objname = is_part-object_name
                iv_versno  = ls_remote-versno
                iv_system  = ls_remote-system ).

              IF lt_src_rmt IS INITIAL.
                " Object does not exist in the remote system yet → no retrofit needed.
                " A diff against an empty remote would mark the whole object as added,
                " which is meaningless.
                append_diag(
                  EXPORTING iv_text = |RFTR { is_part-type } { is_part-object_name }: object not present in { ls_remote-system } yet, skipping retrofit analysis|
                  CHANGING  ct_cr_diag = ct_cr_diag ).
              ELSE.
                " Secondary diff: remote (old) -> new version
                zcl_ave_progress=>reset_stop( ).
                DATA(lt_diff_rmt) = zcl_ave_popup_diff=>compute_diff(
                  it_old        = lt_src_rmt
                  it_new        = lt_src_n
                  i_title       = CONV #( is_part-object_name )
                  i_confirm_key = |RFTR~{ is_part-type }~{ is_part-object_name }|
                  i_ignore_case = is_options-ignore_case ).
                DATA(lt_review_diff_rmt) = zcl_ave_acr_hunk_html=>filter_moved_lines(
                  it_diff        = lt_diff_rmt
                  iv_ignore_case = is_options-ignore_case ).

                " If the new source shares no common line with the remote one, the
                " object effectively does not exist in the remote system (the diff is
                " "everything added") → a retrofit comparison would be nonsense, skip.
                DATA(lv_rmt_common) = 0.
                LOOP AT lt_diff_rmt TRANSPORTING NO FIELDS WHERE op = '='.
                  lv_rmt_common = lv_rmt_common + 1.
                ENDLOOP.
                IF lv_rmt_common = 0.
                  append_diag(
                    EXPORTING iv_text = |RFTR { is_part-type } { is_part-object_name }: no common lines vs { ls_remote-system } (object absent/unrelated), skipping retrofit|
                    CHANGING  ct_cr_diag = ct_cr_diag ).
                ELSE.

                " Review-line set from the primary diff (|op|text|)
                DATA lt_review_lines TYPE zif_ave_acr_types=>ty_review_lines.
                LOOP AT lt_review_diff INTO DATA(ls_prim_op) WHERE op = '+' OR op = '-'.
                  INSERT |{ ls_prim_op-op }\|{ ls_prim_op-text }| INTO TABLE lt_review_lines.
                ENDLOOP.

                " Build retrofit hunks directly from the secondary diff (self-contained:
                " grouping + coverage + render), avoiding collect/collect_rows index drift.
                DATA(lt_rmt_hunks) = collect_retrofit_hunks(
                  is_part          = ls_effective_part
                  it_diff          = lt_review_diff_rmt
                  it_review_lines  = lt_review_lines
                  iv_versno_new    = lv_versno_new
                  iv_new_text      = ls_new-versno_text
                  iv_remote_versno = ls_remote-versno
                  iv_old_text      = ls_remote-versno_text
                  iv_system        = ls_remote-system
                  iv_author        = ls_new-author
                  iv_display_name  = lv_disp_name
                  iv_two_pane      = abap_false
                  iv_ignore_case   = is_options-ignore_case ).
                LOOP AT lt_rmt_hunks INTO DATA(ls_rmt_h).
                  INSERT ls_rmt_h INTO TABLE ct_hunk_info.
                ENDLOOP.

                " Persist the secondary (remote->new) diff so the hunk html can be
                " regenerated on the fly at view time, exactly like normal hunks.
                IF lt_rmt_hunks IS NOT INITIAL.
                  INSERT VALUE zif_ave_acr_types=>ty_diff_data(
                    key = VALUE #(
                      objtype     = is_part-type
                      objname     = is_part-object_name
                      versno_o    = ls_remote-versno
                      versno_n    = lv_versno_new
                      blame         = abap_false
                      ignore_case   = is_options-ignore_case
                      ignore_indent = is_options-ignore_indent )
                    diff       = lt_review_diff_rmt
                    title      = |{ is_part-type }: { is_part-object_name }|
                    is_created = abap_false
                    retrofit   = abap_true )
                    INTO TABLE ct_diff_data.
                ENDIF.

                append_diag(
                  EXPORTING iv_text = |RFTR { is_part-type } { is_part-object_name }: remote_src={ lines( lt_src_rmt ) }L, sec_diff={ lines( lt_review_diff_rmt ) }ops, retrofit_hunks={ lines( lt_rmt_hunks ) }|
                  CHANGING  ct_cr_diag = ct_cr_diag ).
                ENDIF.
              ENDIF.
            CATCH cx_root INTO DATA(lx_rftr).
              append_diag(
                EXPORTING iv_text = |RFTR ERROR { is_part-type } { is_part-object_name }: { lx_rftr->get_text( ) }|
                CHANGING  ct_cr_diag = ct_cr_diag ).
          ENDTRY.
        ENDIF.

        IF lv_is_created = abap_true.
          CLEAR lt_auth.
          APPEND VALUE zif_ave_acr_types=>ty_author_stats(
            author      = lv_author
            author_name = zcl_ave_popup_data=>get_user_name( lv_author )
            ins_count   = lv_ins
            del_count   = lv_del
            mod_count   = lv_mod
            hunk_count  = lv_hunk_cnt ) TO lt_auth.
        ENDIF.

        LOOP AT lt_auth ASSIGNING FIELD-SYMBOL(<auth_cnt>).
          CLEAR <auth_cnt>-hunk_count.
        ENDLOOP.
        LOOP AT ct_hunk_info INTO DATA(ls_auth_hi)
          WHERE objtype = is_part-type AND obj_name = is_part-object_name.
          " Retrofit (moving-violation) hunks are informational, not part of stats.
          CHECK ls_auth_hi-retrofit IS INITIAL.
          CHECK ls_auth_hi-author IS NOT INITIAL.
          READ TABLE lt_auth ASSIGNING <auth_cnt> WITH KEY author = ls_auth_hi-author.
          IF sy-subrc <> 0.
            APPEND VALUE zif_ave_acr_types=>ty_author_stats(
              author      = ls_auth_hi-author
              author_name = ls_auth_hi-author_name ) TO lt_auth.
            READ TABLE lt_auth ASSIGNING <auth_cnt> WITH KEY author = ls_auth_hi-author.
          ENDIF.
          <auth_cnt>-hunk_count = <auth_cnt>-hunk_count + 1.
        ENDLOOP.

        IF lt_blame IS INITIAL AND lt_auth IS NOT INITIAL.
          READ TABLE lt_auth ASSIGNING <auth_cnt> WITH KEY author = lv_author.
          IF sy-subrc = 0.
            <auth_cnt>-ins_count = lv_ins.
            <auth_cnt>-mod_count = lv_mod.
            <auth_cnt>-del_count = lv_del.
          ELSE.
            CLEAR lt_auth.
            APPEND VALUE zif_ave_acr_types=>ty_author_stats(
              author      = lv_author
              author_name = zcl_ave_popup_data=>get_user_name( lv_author )
              ins_count   = lv_ins
              mod_count   = lv_mod
              del_count   = lv_del
              hunk_count  = lv_hunk_cnt ) TO lt_auth.
          ENDIF.
        ENDIF.

        IF lv_ins = 0 AND lv_del = 0 AND lv_mod = 0 AND lv_hunk_cnt = 0.
          DELETE ct_diff_cache WHERE key-objtype = is_part-type
                                 AND key-objname = is_part-object_name.
          DELETE ct_diff_data WHERE key-objtype = is_part-type
                                AND key-objname = is_part-object_name.
          append_diag(
            EXPORTING iv_text = |SKIP { is_part-type } { is_part-object_name }: diff has no changed lines/hunks|
            CHANGING  ct_cr_diag = ct_cr_diag ).
          RETURN.
        ENDIF.

        APPEND VALUE zif_ave_acr_types=>ty_obj_stats(
          objtype      = is_part-type
          class_name   = CONV #( ls_effective_part-class )
          obj_name     = is_part-object_name
          display_name = lv_disp_name
          versno_new   = lv_versno_new
          versno_old   = lv_versno_old
          author       = lv_author
          author_name  = zcl_ave_popup_data=>get_user_name( lv_author )
          datum        = lv_datum
          zeit         = lv_zeit
          ins_count    = lv_ins
          del_count    = lv_del
          mod_count    = lv_mod
          hunk_count   = lv_hunk_cnt
          hunk_ins     = lv_stat_hunk_ins
          hunk_mod     = lv_stat_hunk_mod
          hunk_del     = lv_stat_hunk_del
          bt_authors   = lt_auth
          is_created   = lv_is_created )
          TO ct_acr_stats.

      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD extract_diff_rows.
    DATA lv_off TYPE i.
    DATA lv_len TYPE i.
    FIND FIRST OCCURRENCE OF `<table><tbody>` IN iv_html
      MATCH OFFSET lv_off MATCH LENGTH lv_len.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lv_start) = lv_off + lv_len.
    DATA(lv_tail) = iv_html+lv_start.
    DATA lv_end TYPE i.
    FIND FIRST OCCURRENCE OF `</tbody></table>` IN lv_tail MATCH OFFSET lv_end.
    IF sy-subrc = 0.
      result = lv_tail(lv_end).
    ENDIF.
  ENDMETHOD.


  METHOD collect_retrofit_hunks.
    DATA lv_pos TYPE i VALUE 1.
    DATA(lv_total) = lines( it_diff ).
    DATA lv_render_line TYPE i VALUE 0.
    DATA lv_seq TYPE i.

    WHILE lv_pos <= lv_total.
      READ TABLE it_diff INTO DATA(ls_start) INDEX lv_pos.
      IF ls_start-op <> '+' AND ls_start-op <> '-'.
        IF ls_start-op = '='.
          lv_render_line = lv_render_line + 1.
        ENDIF.
        lv_pos = lv_pos + 1.
        CONTINUE.
      ENDIF.

      " Gather a contiguous change block (bridge a single blank '=' line if
      " more changes follow), tracking change lines + signatures for coverage.
      DATA(lv_scan) = lv_pos.
      DATA lt_hunk_diff  TYPE zif_ave_popup_types=>ty_t_diff.
      DATA lt_hunk_lines TYPE string_table.
      DATA lt_sig        TYPE string_table.
      DATA lv_ins        TYPE i.
      DATA lv_del        TYPE i.
      CLEAR: lt_hunk_diff, lt_hunk_lines, lt_sig, lv_ins, lv_del.
      WHILE lv_scan <= lv_total.
        READ TABLE it_diff INTO DATA(ls_s) INDEX lv_scan.
        IF ls_s-op = '+' OR ls_s-op = '-'.
          APPEND ls_s TO lt_hunk_diff.
          APPEND CONV string( ls_s-text ) TO lt_hunk_lines.
          APPEND |{ ls_s-op }\|{ ls_s-text }| TO lt_sig.
          IF ls_s-op = '+'.
            lv_ins = lv_ins + 1.
          ELSE.
            lv_del = lv_del + 1.
          ENDIF.
          lv_scan = lv_scan + 1.
        ELSEIF ls_s-op = '=' AND condense( val = ls_s-text ) = ``.
          DATA(lv_peek) = lv_scan + 1.
          DATA(lv_more) = abap_false.
          WHILE lv_peek <= lv_total AND lv_peek <= lv_scan + 2.
            READ TABLE it_diff INTO DATA(ls_pk) INDEX lv_peek.
            IF ls_pk-op = '+' OR ls_pk-op = '-'.
              lv_more = abap_true.
              EXIT.
            ELSEIF ls_pk-op = '=' AND condense( val = ls_pk-text ) = ``.
              lv_peek = lv_peek + 1.
            ELSE.
              EXIT.
            ENDIF.
          ENDWHILE.
          IF lv_more = abap_true.
            APPEND ls_s TO lt_hunk_diff.
            lv_scan = lv_scan + 1.
          ELSE.
            EXIT.
          ENDIF.
        ELSE.
          EXIT.
        ENDIF.
      ENDWHILE.

      IF zcl_ave_acr_stats=>is_blank_hunk( lt_hunk_lines ) = abap_false.
        " Coverage: skip hunks whose every change line is part of the primary review.
        DATA(lv_covered) = abap_true.
        LOOP AT lt_sig INTO DATA(lv_s).
          IF NOT line_exists( it_review_lines[ table_line = lv_s ] ).
            lv_covered = abap_false.
            EXIT.
          ENDIF.
        ENDLOOP.

        IF lv_covered = abap_false.
          " Render the hunk with up to 3 context lines before/after.
          DATA lt_render TYPE zif_ave_popup_types=>ty_t_diff.
          CLEAR lt_render.
          DATA(lv_ctx_before) = 0.
          DATA(lv_cscan) = lv_pos - 1.
          WHILE lv_cscan >= 1 AND lv_ctx_before < 3.
            READ TABLE it_diff INTO DATA(ls_cb) INDEX lv_cscan.
            IF sy-subrc <> 0 OR ls_cb-op <> '='.
              EXIT.
            ENDIF.
            INSERT ls_cb INTO lt_render INDEX 1.
            lv_ctx_before = lv_ctx_before + 1.
            lv_cscan = lv_cscan - 1.
          ENDWHILE.
          INSERT LINES OF lt_hunk_diff INTO TABLE lt_render.
          DATA(lv_ctx_after) = 0.
          lv_cscan = lv_scan.
          WHILE lv_cscan <= lv_total AND lv_ctx_after < 3.
            READ TABLE it_diff INTO DATA(ls_ca) INDEX lv_cscan.
            IF sy-subrc <> 0 OR ls_ca-op <> '='.
              EXIT.
            ENDIF.
            APPEND ls_ca TO lt_render.
            lv_ctx_after = lv_ctx_after + 1.
            lv_cscan = lv_cscan + 1.
          ENDWHILE.

          DATA(lv_start_line) = lv_render_line - lv_ctx_before + 1.
          IF lv_start_line < 1.
            lv_start_line = 1.
          ENDIF.

          DATA(lv_full_html) = zcl_ave_popup_html=>diff_to_html(
            it_diff       = lt_render
            i_title       = |{ is_part-type }: { is_part-object_name }|
            i_meta        = ``
            i_two_pane    = iv_two_pane
            i_ignore_case = iv_ignore_case
            i_start_line  = lv_start_line
            i_code_review = abap_false ).
          DATA(lv_rows) = extract_diff_rows( lv_full_html ).

          DATA(lv_kind) = COND string(
            WHEN lv_ins > 0 AND lv_del > 0 THEN `changed`
            WHEN lv_ins > 0                THEN `added`
            ELSE                               `deleted` ).
          DATA(lv_msg) = COND string(
            WHEN lv_kind = `deleted`
              THEN |will be overwritten(deleted) in { iv_system } after moving - retrofit needed!!!|
            WHEN lv_kind = `added`
              THEN |deleted will be inserted in { iv_system } after moving - retrofit needed!!!|
            ELSE |diverges from { iv_system } - will be overwritten/re-inserted after moving - retrofit needed!!!| ).

          lv_seq = lv_seq + 1.
          INSERT VALUE zif_ave_acr_types=>ty_hunk_info(
            hunk_key        = |{ is_part-type }~{ is_part-object_name }~R{ lv_seq }|
            objtype         = is_part-type
            obj_name        = is_part-object_name
            class_name      = CONV #( is_part-class )
            display_name    = iv_display_name
            hunk_no         = lv_seq
            start_line      = lv_start_line
            change_count    = lv_ins + lv_del
            change_kind     = lv_kind
            author          = iv_author
            author_name     = zcl_ave_popup_data=>get_user_name( iv_author )
            versno_new      = iv_versno_new
            versno_old      = iv_remote_versno
            versno_new_text = iv_new_text
            versno_old_text = iv_old_text
            html            = lv_rows
            retrofit        = lv_msg )
            INTO TABLE result.
        ENDIF.
      ENDIF.

      " Advance the rendered-line counter past the consumed hunk ('=' and '+').
      LOOP AT lt_hunk_diff INTO DATA(ls_rc).
        IF ls_rc-op = '=' OR ls_rc-op = '+'.
          lv_render_line = lv_render_line + 1.
        ENDIF.
      ENDLOOP.
      lv_pos = lv_scan.
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.
