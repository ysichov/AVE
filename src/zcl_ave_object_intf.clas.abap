"! Object handler for an ABAP interface (one INTF part)
CLASS zcl_ave_object_intf DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE seoclsname.

  PRIVATE SECTION.
    DATA name TYPE seoclsname.

ENDCLASS.


CLASS zcl_ave_object_intf IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    SELECT SINGLE @abap_true INTO @result
      FROM seoclass
      WHERE clsname = @name
        AND clstype = '1'.
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    result = VALUE #( (
      unit        = CONV #( name )
      object_name = CONV #( name )
      type        = 'INTF' ) ).
  ENDMETHOD.

ENDCLASS.
