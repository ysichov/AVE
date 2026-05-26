CLASS zcl_ave_acr_prepare DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES ty_part_row TYPE zif_ave_popup_types=>ty_part_row.
    TYPES ty_t_part_row TYPE zif_ave_popup_types=>ty_t_part_row.
    TYPES ty_t_selected_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

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

ENDCLASS.
