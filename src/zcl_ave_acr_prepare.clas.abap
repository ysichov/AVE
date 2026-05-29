CLASS zcl_ave_acr_prepare DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES ty_part_row TYPE zif_ave_popup_types=>ty_part_row.
    TYPES ty_t_part_row TYPE zif_ave_popup_types=>ty_t_part_row.
    TYPES ty_version_row TYPE zif_ave_popup_types=>ty_version_row.
    TYPES ty_t_version_row TYPE zif_ave_popup_types=>ty_t_version_row.
    TYPES ty_t_selected_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    TYPES:
      BEGIN OF ty_author_lookup,
        author     TYPE versuser,
        diag_lines TYPE string_table,
      END OF ty_author_lookup.
    TYPES:
      BEGIN OF ty_diff_pair,
        new_version TYPE ty_version_row,
        old_version TYPE ty_version_row,
        diag_lines  TYPE string_table,
      END OF ty_diff_pair.

    CLASS-METHODS is_selected_only
      IMPORTING
        iv_keys          TYPE string
      RETURNING
        VALUE(result)    TYPE abap_bool.

    CLASS-METHODS parse_selected_keys
      IMPORTING
        iv_keys          TYPE string
      RETURNING
        VALUE(result)    TYPE ty_t_selected_keys.

    CLASS-METHODS part_key
      IMPORTING
        is_part          TYPE ty_part_row
      RETURNING
        VALUE(result)    TYPE string.

    CLASS-METHODS count_supported_parts
      IMPORTING
        it_parts         TYPE ty_t_part_row
      RETURNING
        VALUE(result)    TYPE i.

    CLASS-METHODS count_preparable_parts
      IMPORTING
        it_parts         TYPE ty_t_part_row
        iv_selected_only TYPE abap_bool
        it_selected_keys TYPE ty_t_selected_keys
      RETURNING
        VALUE(result)    TYPE i.

    CLASS-METHODS has_part_key
      IMPORTING
        it_parts         TYPE ty_t_part_row
        iv_key           TYPE string
      RETURNING
        VALUE(result)    TYPE abap_bool.

    CLASS-METHODS get_created_object_author
      IMPORTING
        is_part          TYPE ty_part_row
      RETURNING
        VALUE(result)    TYPE ty_author_lookup.

    CLASS-METHODS select_diff_pair
      IMPORTING
        is_part          TYPE ty_part_row
        it_versions      TYPE ty_t_version_row
      RETURNING
        VALUE(result)    TYPE ty_diff_pair.

    CLASS-METHODS is_comments_only
      IMPORTING
        it_source        TYPE abaptxt255_tab
      RETURNING
        VALUE(result)    TYPE abap_bool.
ENDCLASS.


CLASS zcl_ave_acr_prepare IMPLEMENTATION.

  METHOD is_selected_only.
    result = xsdbool( iv_keys IS NOT INITIAL AND iv_keys <> `0` ).
  ENDMETHOD.


  METHOD parse_selected_keys.
    CHECK is_selected_only( iv_keys ) = abap_true.

    SPLIT iv_keys AT `;` INTO TABLE DATA(lt_selected_raw).
    LOOP AT lt_selected_raw INTO DATA(lv_selected_raw).
      CHECK lv_selected_raw IS NOT INITIAL.
      INSERT lv_selected_raw INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD part_key.
    result = |{ is_part-type }~{ is_part-object_name }|.
  ENDMETHOD.


  METHOD count_supported_parts.
    LOOP AT it_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_part-type ) = abap_true.
        result += 1.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD count_preparable_parts.
    LOOP AT it_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      IF zcl_ave_popup_data=>is_supported_object_type( ls_part-type ) = abap_false.
        CONTINUE.
      ENDIF.
      IF iv_selected_only = abap_true
         AND NOT line_exists( it_selected_keys[ table_line = part_key( ls_part ) ] ).
        CONTINUE.
      ENDIF.
      result += 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD has_part_key.
    LOOP AT it_parts INTO DATA(ls_part) WHERE type <> 'RPT'.
      IF iv_key = part_key( ls_part ).
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_created_object_author.
    DATA(lv_tadir_object) = CONV tadir-object( is_part-type ).
    DATA(lv_tadir_name) = CONV tadir-obj_name( is_part-object_name ).

    CASE is_part-type.
      WHEN 'REPS' OR 'REPT'.
        lv_tadir_object = 'PROG'.
      WHEN 'METH'.
        IF is_part-class IS NOT INITIAL.
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
            DATA lv_meth_include TYPE seop_method_w_include.
            LOOP AT lt_meth_includes INTO lv_meth_include.
              IF lv_meth_include-cpdkey-cpdname = is_part-name.
                EXIT.
              ENDIF.
              CLEAR lv_meth_include.
            ENDLOOP.
            IF lv_meth_include IS NOT INITIAL.
              DATA lv_reposrc_cnam TYPE reposrc-cnam.
              SELECT SINGLE cnam FROM reposrc
                WHERE progname = @lv_meth_include-incname
                INTO @lv_reposrc_cnam.
              IF sy-subrc = 0 AND lv_reposrc_cnam IS NOT INITIAL.
                result-author = lv_reposrc_cnam.
                APPEND |METH AUTHOR { is_part-object_name }: include { lv_meth_include-cpdkey-cpdname }, REPOSRC-CNAM={ lv_reposrc_cnam }| TO result-diag_lines.
              ELSE.
                APPEND |METH AUTHOR { is_part-object_name }: include { lv_meth_include-cpdkey-cpdname }, REPOSRC-CNAM not found, fallback to TADIR| TO result-diag_lines.
                lv_tadir_object = 'CLAS'.
                lv_tadir_name = CONV tadir-obj_name( is_part-class ).
              ENDIF.
            ELSE.
              APPEND |METH AUTHOR { is_part-object_name }: include not found in SEO_CLASS_GET_METHOD_INCLUDES, fallback to TADIR| TO result-diag_lines.
              lv_tadir_object = 'CLAS'.
              lv_tadir_name = CONV tadir-obj_name( is_part-class ).
            ENDIF.
          ELSE.
            APPEND |METH AUTHOR { is_part-object_name }: SEO_CLASS_GET_METHOD_INCLUDES failed (subrc={ sy-subrc }), fallback to TADIR| TO result-diag_lines.
            lv_tadir_object = 'CLAS'.
            lv_tadir_name = CONV tadir-obj_name( is_part-class ).
          ENDIF.
          IF result-author IS NOT INITIAL.
            CLEAR: lv_tadir_object, lv_tadir_name.
          ENDIF.
        ELSE.
          CLEAR: lv_tadir_object, lv_tadir_name.
          APPEND |NEW OBJECT { is_part-type } { is_part-object_name }: skip TADIR author lookup, parent class is unknown| TO result-diag_lines.
        ENDIF.
      WHEN 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'CINC' OR 'CDEF'.
        lv_tadir_object = 'CLAS'.
        IF is_part-class IS NOT INITIAL.
          lv_tadir_name = CONV tadir-obj_name( is_part-class ).
        ELSEIF lv_tadir_name CS '='.
          DATA(lv_tadir_eq_pos) = find( val = CONV string( lv_tadir_name ) sub = '=' ).
          IF lv_tadir_eq_pos > 0.
            lv_tadir_name = lv_tadir_name(lv_tadir_eq_pos).
          ENDIF.
        ENDIF.
    ENDCASE.

    IF lv_tadir_object IS NOT INITIAL AND lv_tadir_name IS NOT INITIAL.
      SELECT SINGLE author FROM tadir
        WHERE pgmid    = 'R3TR'
          AND object   = @lv_tadir_object
          AND obj_name = @lv_tadir_name
          AND delflag  = ' '
        INTO @result-author.
    ENDIF.
  ENDMETHOD.


  METHOD select_diff_pair.
    READ TABLE it_versions INTO result-new_version INDEX 1.
    CHECK result-new_version IS NOT INITIAL.

    " Build own-scope set: the selected K request + all its S-tasks from E070
    DATA lt_own_korrnums TYPE HASHED TABLE OF trkorr WITH UNIQUE KEY table_line.

    DATA(lv_scope_k) = CONV trkorr( result-new_version-korrnum ).
    IF lv_scope_k IS NOT INITIAL.
      INSERT lv_scope_k INTO TABLE lt_own_korrnums.
      SELECT trkorr, as4date, as4time FROM e070
        WHERE strkorr    = @lv_scope_k
          AND trfunction = 'S'
        INTO TABLE @DATA(lt_s_tasks).
      LOOP AT lt_s_tasks INTO DATA(ls_s_task).
        INSERT ls_s_task-trkorr INTO TABLE lt_own_korrnums.
      ENDLOOP.
    ENDIF.

    IF result-new_version-task IS NOT INITIAL.
      INSERT CONV trkorr( result-new_version-task ) INTO TABLE lt_own_korrnums.
    ENDIF.

    DATA lt_own_korrnums_diag TYPE STANDARD TABLE OF trkorr WITH DEFAULT KEY.
    LOOP AT lt_own_korrnums INTO DATA(lv_own_k).
      APPEND lv_own_k TO lt_own_korrnums_diag.
    ENDLOOP.
    APPEND |DBG { is_part-type } { is_part-object_name }: own_korrnums={ concat_lines_of( table = lt_own_korrnums_diag sep = `,` ) }| TO result-diag_lines.

    " Date of the earliest S-task in the own set
    DATA lv_first_s_date TYPE e070-as4date.
    DATA lv_first_s_time TYPE e070-as4time.
    LOOP AT lt_s_tasks INTO DATA(ls_s_task2).
      IF lv_first_s_date IS INITIAL
         OR ls_s_task2-as4date < lv_first_s_date
         OR ( ls_s_task2-as4date = lv_first_s_date AND ls_s_task2-as4time < lv_first_s_time ).
        lv_first_s_date = ls_s_task2-as4date.
        lv_first_s_time = ls_s_task2-as4time.
      ENDIF.
    ENDLOOP.

    APPEND |DBG { is_part-type } { is_part-object_name }: first_s_date={ lv_first_s_date } first_s_time={ lv_first_s_time }| TO result-diag_lines.

    " Walk versions newest-first; first one outside own scope is the baseline candidate
    LOOP AT it_versions INTO DATA(ls_ver) FROM 2.
      " For T-type versions, task is artificially assigned from a nearby S-task of a
      " different K-request by load_versions; using it would falsely mark the version
      " as belonging to our scope. T-versions are always identified by their korrnum.
      DATA(lv_ver_korr) = COND trkorr(
        WHEN ls_ver-trfunction = 'T'       THEN CONV trkorr( ls_ver-korrnum )
        WHEN ls_ver-task IS NOT INITIAL    THEN CONV trkorr( ls_ver-task )
        WHEN ls_ver-korrnum IS NOT INITIAL THEN CONV trkorr( ls_ver-korrnum )
        ELSE VALUE trkorr( ) ).

      APPEND |DBG { is_part-type } { is_part-object_name }: scan versno={ ls_ver-versno } korrnum={ ls_ver-korrnum } task={ ls_ver-task } trf={ ls_ver-trfunction } ver_korr={ lv_ver_korr } datum={ ls_ver-datum } zeit={ ls_ver-zeit }| TO result-diag_lines.

      " Older than the first S-task of our scope → definitive baseline
      IF lv_first_s_date IS NOT INITIAL
         AND ( ls_ver-datum < lv_first_s_date
            OR ( ls_ver-datum = lv_first_s_date AND ls_ver-zeit < lv_first_s_time ) ).
        result-old_version = ls_ver.
        APPEND |BASELINE { is_part-type } { is_part-object_name }: candidate { ls_ver-korrnum } is older than first S-task, using as baseline| TO result-diag_lines.
        EXIT.
      ENDIF.

      " Not in own scope → baseline
      IF lv_ver_korr IS NOT INITIAL
         AND NOT line_exists( lt_own_korrnums[ table_line = lv_ver_korr ] ).
        result-old_version = ls_ver.
        APPEND |BASELINE { is_part-type } { is_part-object_name }: candidate { ls_ver-korrnum } is outside selected scope, using as baseline| TO result-diag_lines.
        EXIT.
      ENDIF.
    ENDLOOP.

    DATA(lv_v1_before_first_s) = xsdbool(
      result-old_version-versno = '00001'
      AND lv_first_s_date IS NOT INITIAL
      AND ( result-old_version-datum < lv_first_s_date
         OR ( result-old_version-datum = lv_first_s_date
          AND result-old_version-zeit < lv_first_s_time ) ) ).

    IF result-old_version IS INITIAL.
      APPEND |NEW OBJECT { is_part-type } { is_part-object_name }: no retained baseline version found, treating as new object| TO result-diag_lines.
    ELSEIF lv_v1_before_first_s = abap_true.
      APPEND |BASELINE { is_part-type } { is_part-object_name }: old candidate is v1 before first S-request, using as baseline (not a new object)| TO result-diag_lines.
    ELSEIF result-old_version-versno = '00001' AND result-old_version-korrnum = result-new_version-korrnum.
      APPEND |NEW OBJECT { is_part-type } { is_part-object_name }: old candidate is v1 of same request { result-old_version-korrnum }, treating as new object| TO result-diag_lines.
      CLEAR result-old_version.
    ELSEIF result-old_version-versno = '00001'
       AND ( result-old_version-trfunction = 'K' OR result-old_version-trfunction = 'T' )
       AND result-old_version-korrnum <> result-new_version-korrnum.
      APPEND |BASELINE { is_part-type } { is_part-object_name }: old candidate is v1 from earlier request { result-old_version-korrnum }, using as baseline (not a new object)| TO result-diag_lines.
    ELSEIF result-old_version-versno = '00001'.
      APPEND |NEW OBJECT { is_part-type } { is_part-object_name }: old candidate is v1, treating as new object| TO result-diag_lines.
      CLEAR result-old_version.
    ENDIF.
  ENDMETHOD.


  METHOD is_comments_only.
    result = abap_true.
    LOOP AT it_source INTO DATA(ls_line).
      DATA(lv_trimmed) = condense( CONV string( ls_line ) ).
      CHECK lv_trimmed IS NOT INITIAL.
      IF lv_trimmed(1) <> '*'.
        result = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
