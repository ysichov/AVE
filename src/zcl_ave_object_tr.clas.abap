"! Object handler for a Transport Request or Task.
"! Reads all objects from the TR and delegates to specific object handlers.
CLASS zcl_ave_object_tr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !id TYPE trkorr.

  PRIVATE SECTION.

    DATA id TYPE trkorr.

    TYPES ty_t_object TYPE TABLE OF REF TO zif_ave_object WITH KEY table_line.

    METHODS get_object_keys
      RETURNING
        VALUE(result) TYPE trwbo_t_e071
      RAISING
        zcx_ave.

    METHODS get_objects_for_keys
      IMPORTING
        object_keys   TYPE trwbo_t_e071
      RETURNING
        VALUE(result) TYPE ty_t_object.

    METHODS get_object
      IMPORTING
        object_key    TYPE trwbo_s_e071
      RETURNING
        VALUE(result) TYPE REF TO zif_ave_object.

ENDCLASS.


CLASS zcl_ave_object_tr IMPLEMENTATION.

  METHOD constructor.
    me->id = id.
  ENDMETHOD.

  METHOD get_object.
    TRY.
        result = COND #(
          " R3TR CLAS → single row (drill-in via double-click)
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'CLAS'
            THEN NEW zcl_ave_object_clas( CONV #( object_key-obj_name ) )
          " R3TR PROG → program
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'PROG'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) )
          " R3TR FUGR → function group main include
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'FUGR'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) )
          " LIMU FUNC → single function module
          WHEN object_key-pgmid = 'LIMU' AND object_key-object = 'FUNC'
            THEN NEW zcl_ave_object_func( CONV #( object_key-obj_name ) )
          " LIMU REPS → single program/include
          WHEN object_key-pgmid = 'LIMU' AND object_key-object = 'REPS'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) ) ).
      CATCH zcx_ave.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.

  METHOD get_object_keys.
    DATA request_data TYPE trwbo_request.
    request_data-h-trkorr = id.

    CALL FUNCTION 'TRINT_READ_REQUEST'
      EXPORTING
        iv_read_objs  = abap_true
      CHANGING
        cs_request    = request_data
      EXCEPTIONS
        error_occured = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.

    result = request_data-objects.
    SORT result BY pgmid ASCENDING object ASCENDING obj_name ASCENDING.
    DELETE ADJACENT DUPLICATES FROM result COMPARING pgmid object obj_name.
  ENDMETHOD.

  METHOD get_objects_for_keys.
    result = VALUE #(
      FOR key IN object_keys
      LET obj = get_object( key )
      IN ( obj ) ).
    DELETE result WHERE table_line IS NOT BOUND.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    TRY.
        NEW zcl_ave_request( me->id ).
        result = abap_true.
      CATCH zcx_ave.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = id.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    LOOP AT get_object_keys( ) INTO DATA(key).
      IF key-pgmid = 'R3TR' AND key-object = 'CLAS'.
        " CLAS is shown as a single row; double-click opens the class-level popup
        APPEND VALUE #(
          unit        = CONV string( key-obj_name )
          object_name = CONV versobjnam( key-obj_name )
          type        = 'CLAS' ) TO result.
      ELSEIF key-pgmid = 'R3TR' AND key-object = 'METH'.
        " METH: obj_name may be CLASSNAME\METHODNAME or just METHODNAME
        DATA lv_meth_cls  TYPE seoclsname.
        DATA lv_meth_name TYPE seocmpname.
        DATA lv_meth_raw  TYPE string.
        lv_meth_raw = key-obj_name.
        CONDENSE lv_meth_raw.
        SPLIT lv_meth_raw AT ` ` INTO DATA(lv_cls_part) DATA(lv_meth_part).
        lv_meth_cls  = lv_cls_part.
        lv_meth_name = lv_meth_part.
        APPEND VALUE #(
          class       = CONV string( lv_meth_cls )
          unit        = CONV string( lv_meth_name )
          object_name = CONV versobjnam( lv_meth_name )
          type        = 'METH' ) TO result.
        CLEAR: lv_meth_cls, lv_meth_name, lv_meth_raw.
      ELSE.
        DATA(obj) = get_object( key ).
        IF obj IS BOUND.
          APPEND LINES OF obj->get_parts( ) TO result.
        ELSE.
          " Unknown/unsupported type — show as-is so it's not silently dropped
          APPEND VALUE #(
            unit        = CONV string( key-obj_name )
            object_name = CONV versobjnam( key-obj_name )
            type        = CONV versobjtyp( key-object ) ) TO result.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
