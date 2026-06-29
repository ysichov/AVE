"! Object handler for a Dictionary Data Element (DTEL).
"! Returns one part of type DTEL; source is loaded via SVRS_GET_VERSION_LOCAL.
CLASS zcl_ave_object_dtel DEFINITION
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


CLASS zcl_ave_object_dtel IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    DATA lv_rollname TYPE dd04l-rollname.
    lv_rollname = name.
    SELECT SINGLE rollname FROM dd04l
      WHERE rollname = @lv_rollname
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
      type        = 'DTED' ) ).
  ENDMETHOD.

ENDCLASS.
