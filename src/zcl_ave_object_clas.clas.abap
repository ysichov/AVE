"! Object handler for an ABAP class.
"! Returns class sections (pool, pub/pro/pri, local types/impl) plus all methods.
CLASS zcl_ave_object_clas DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !name TYPE seoclsname
      RAISING
        zcx_ave.

  PRIVATE SECTION.
    DATA name TYPE seoclsname.

ENDCLASS.


CLASS zcl_ave_object_clas IMPLEMENTATION.

  METHOD constructor.
    me->name = name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    cl_abap_classdescr=>describe_by_name(
      EXPORTING
        p_name         = name
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    result = boolc( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = name.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    " Fixed sections of the class
    result = VALUE #(
      ( name = 'Class pool'                 object_name = CONV #( name )                                  type = 'CLSD' )
      ( name = 'Public section'             object_name = CONV #( name )                                  type = 'CPUB' )
      ( name = 'Protected section'          object_name = CONV #( name )                                  type = 'CPRO' )
      ( name = 'Private section'            object_name = CONV #( name )                                  type = 'CPRI' )
      ( name = 'Local class definition'     object_name = CONV #( cl_oo_classname_service=>get_ccdef_name( name ) ) type = 'CDEF' )
      ( name = 'Local class implementation' object_name = CONV #( cl_oo_classname_service=>get_ccimp_name( name ) ) type = 'CINC' )
      ( name = 'Local macros'               object_name = CONV #( cl_oo_classname_service=>get_ccmac_name( name ) ) type = 'CINC' )
      ( name = 'Local types'                object_name = CONV #( cl_oo_classname_service=>get_cl_name( name ) )    type = 'REPS' )
      ( name = 'Test classes'               object_name = CONV #( cl_oo_classname_service=>get_ccau_name( name ) )  type = 'CINC' ) ).

    " One entry per method
    LOOP AT cl_oo_classname_service=>get_all_method_includes( name ) INTO DATA(method_include).
      TRY.
          DATA(method_name) = cl_oo_classname_service=>get_method_by_include( method_include-incname )-cpdname.
        CATCH cx_root.
          CONTINUE.
      ENDTRY.
      CHECK method_name IS NOT INITIAL.
      APPEND VALUE #( name        = |{ to_lower( method_name ) }()|
                      object_name = CONV versobjnam( |{ name WIDTH = 30 }{ method_name }| )
                      type        = 'METH' ) TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
