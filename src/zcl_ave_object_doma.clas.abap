"! Object handler for a Dictionary Domain (DOMA).
"! Returns one part of type DOMA; source is loaded via SVRS_GET_VERSION_LOCAL.
CLASS zcl_ave_object_doma DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE versobjnam.

  PRIVATE SECTION.
    DATA name TYPE versobjnam.

ENDCLASS.


CLASS zcl_ave_object_doma IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    DATA lv_domname TYPE dd01l-domname.
    lv_domname = name.
    SELECT SINGLE domname FROM dd01l
      WHERE domname  = @lv_domname
        AND as4local = 'A'
      INTO @DATA(lv_found).
    result = boolc( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    result = VALUE #( (
      unit        = CONV #( name )
      object_name = name
      type        = 'DOMD' ) ).
  ENDMETHOD.

ENDCLASS.
