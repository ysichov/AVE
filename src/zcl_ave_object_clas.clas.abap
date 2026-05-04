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

protected section.
  PRIVATE SECTION.
    DATA name TYPE seoclsname.

ENDCLASS.



CLASS ZCL_AVE_OBJECT_CLAS IMPLEMENTATION.


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
      ( class = name unit = 'Class pool'                 object_name = CONV #( name )                                  type = 'CLSD' )
      ( class = name unit = 'Public section'             object_name = CONV #( name )                                  type = 'CPUB' )
      ( class = name unit = 'Protected section'          object_name = CONV #( name )                                  type = 'CPRO' )
      ( class = name unit = 'Private section'            object_name = CONV #( name )                                  type = 'CPRI' )
      ( class = name unit = 'Local class definition'     object_name = CONV #( cl_oo_classname_service=>get_ccdef_name( name ) ) type = 'CDEF' )
      ( class = name unit = 'Local class implementation' object_name = CONV #( cl_oo_classname_service=>get_ccimp_name( name ) ) type = 'CINC' )
      ( class = name unit = 'Local macros'               object_name = CONV #( cl_oo_classname_service=>get_ccmac_name( name ) ) type = 'CINC' )
      ( class = name unit = 'Local types'                object_name = CONV #( cl_oo_classname_service=>get_cl_name( name ) )    type = 'REPS' )
      ( class = name unit = 'Test classes'               object_name = CONV #( cl_oo_classname_service=>get_ccau_name( name ) )  type = 'CINC' ) ).

    " One entry per method
    " object_name для METH в VRSD = класс (30 символов, с пробелами) + имя метода.
    " Строковый шаблон |{ char30_var }| обрезает trailing spaces у CHAR-типов,
    " поэтому собираем через прямое присваивание к versobjnam (CHAR110).
    CALL METHOD cl_oo_classname_service=>get_all_method_includes
      EXPORTING
        clsname            = name
      RECEIVING
        result             = DATA(lt_meth)
      EXCEPTIONS
        class_not_existing = 1.

    IF sy-subrc = 0.
      LOOP AT lt_meth INTO DATA(method_include).
        DATA lv_objname TYPE versobjnam.
        lv_objname = name.              " CHAR30: автоматический паддинг пробелами до 30
        lv_objname+30 = method_include-cpdkey-cpdname.
        APPEND VALUE #(
          class       = name
          unit        = |{ method_include-cpdkey-cpdname }|
          object_name = lv_objname
          type        = 'METH'
        ) TO result.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
