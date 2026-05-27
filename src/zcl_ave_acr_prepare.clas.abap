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

    DATA(lv_versions_count) = lines( it_versions ).
    IF lv_versions_count >= 2.
      READ TABLE it_versions INTO result-old_version INDEX lv_versions_count.
    ENDIF.

    IF result-old_version IS INITIAL.
      APPEND |NEW OBJECT { is_part-type } { is_part-object_name }: no retained baseline version found, treating as new object| TO result-diag_lines.
    ELSEIF result-old_version-versno = '00001' AND result-old_version-korrnum = result-new_version-korrnum.
      APPEND |NEW OBJECT { is_part-type } { is_part-object_name }: old candidate is v1 of same request { result-old_version-korrnum }, treating as new object| TO result-diag_lines.
      CLEAR result-old_version.
    ELSEIF result-old_version-versno = '00001'
       AND result-old_version-trfunction = 'K'
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
