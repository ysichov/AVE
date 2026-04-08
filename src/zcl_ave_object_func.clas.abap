"! Object handler for a function module (single FUNC part)
CLASS zcl_ave_object_func DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE rs38l_fnam.

  PRIVATE SECTION.
    DATA name TYPE rs38l_fnam.

ENDCLASS.


CLASS zcl_ave_object_func IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    CALL FUNCTION 'FUNCTION_EXISTS'
      EXPORTING
        funcname           = name
      EXCEPTIONS
        function_not_exist = 1
        OTHERS             = 2.
    result = boolc( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    result = VALUE #( (
      unit        = CONV #( name )
      object_name = CONV #( name )
      type        = 'FUNC' ) ).
  ENDMETHOD.

ENDCLASS.
