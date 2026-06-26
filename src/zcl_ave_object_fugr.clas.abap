"! Object handler for a function group.
"! Returns the main SAPL include plus all L-prefixed sub-includes from TRDIR.
CLASS zcl_ave_object_fugr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE rs38l_area
      RAISING
        zcx_ave.

  PRIVATE SECTION.
    DATA name TYPE rs38l_area.

ENDCLASS.


CLASS zcl_ave_object_fugr IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    SELECT SINGLE @abap_true INTO @result
      FROM trdir
      WHERE name = @( |SAPL{ name }| ).
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    " Main top include: SAPL<FUGR>
    DATA(lv_main) = |SAPL{ name }|.
    APPEND VALUE #(
      unit        = lv_main
      object_name = CONV #( lv_main )
      type        = 'REPS'
    ) TO result.

    " Sub-includes: L<FUGR>* with SQLX = 'X'
    DATA lv_mask TYPE trdir-name.
    lv_mask = |L{ name }%|.

    DATA lt_incl TYPE STANDARD TABLE OF trdir WITH EMPTY KEY.
    SELECT name FROM trdir
      WHERE name LIKE @lv_mask
        AND sqlx = 'X'
      ORDER BY name
      INTO TABLE @lt_incl.

    LOOP AT lt_incl INTO DATA(ls).
      APPEND VALUE #(
        unit        = CONV #( ls-name )
        object_name = CONV #( ls-name )
        type        = 'REPS'
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
