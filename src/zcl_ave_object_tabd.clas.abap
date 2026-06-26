"! Object handler for a Dictionary Table (TABD).
"! Returns one part of type TABD; source is loaded via SVRS_GET_VERSION_LOCAL.
CLASS zcl_ave_object_tabd DEFINITION
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


CLASS zcl_ave_object_tabd IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    DATA lv_tabname TYPE dd02l-tabname.
    lv_tabname = name.
    SELECT SINGLE tabname FROM dd02l
      WHERE tabname  = @lv_tabname
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
      type        = 'TABD' ) ).
  ENDMETHOD.

ENDCLASS.
