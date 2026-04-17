"! Object handler for a Development Package (DEVCLASS).
"! Reads all objects from TADIR and delegates to specific object handlers.
CLASS zcl_ave_object_pack DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_ave_object.

    METHODS constructor
      IMPORTING
        !id TYPE devclass.

  PRIVATE SECTION.

    DATA id TYPE devclass.

    TYPES ty_t_object TYPE TABLE OF REF TO zif_ave_object WITH KEY table_line.

    METHODS get_object_keys
      RETURNING
        VALUE(result) TYPE trwbo_t_e071
      RAISING
        zcx_ave.

    METHODS get_object
      IMPORTING
        object_key    TYPE trwbo_s_e071
      RETURNING
        VALUE(result) TYPE REF TO zif_ave_object.

ENDCLASS.


CLASS zcl_ave_object_pack IMPLEMENTATION.

  METHOD constructor.
    me->id = id.
  ENDMETHOD.

  METHOD get_object.
    TRY.
        result = COND #(
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'CLAS'
            THEN NEW zcl_ave_object_clas( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'INTF'
            THEN NEW zcl_ave_object_intf( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'PROG'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'R3TR' AND object_key-object = 'FUGR'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'LIMU' AND object_key-object = 'FUNC'
            THEN NEW zcl_ave_object_func( CONV #( object_key-obj_name ) )
          WHEN object_key-pgmid = 'LIMU' AND object_key-object = 'REPS'
            THEN NEW zcl_ave_object_prog( CONV #( object_key-obj_name ) ) ).
      CATCH zcx_ave.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.

  METHOD get_object_keys.
    DATA lt_tadir TYPE STANDARD TABLE OF tadir.
    SELECT pgmid, object, obj_name FROM tadir
      WHERE devclass = @me->id
      INTO CORRESPONDING FIELDS OF TABLE @lt_tadir.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.
    LOOP AT lt_tadir INTO DATA(ls_tadir).
      APPEND VALUE trwbo_s_e071(
        pgmid    = ls_tadir-pgmid
        object   = ls_tadir-object
        obj_name = ls_tadir-obj_name ) TO result.
    ENDLOOP.
    SORT result BY pgmid ASCENDING object ASCENDING obj_name ASCENDING.
    DELETE ADJACENT DUPLICATES FROM result COMPARING pgmid object obj_name.
  ENDMETHOD.

  METHOD zif_ave_object~check_exists.
    SELECT SINGLE devclass FROM tdevc WHERE devclass = @me->id INTO @DATA(lv_d).
    result = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
  ENDMETHOD.

  METHOD zif_ave_object~get_name.
    result = id.
  ENDMETHOD.

  METHOD zif_ave_object~get_parts.
    LOOP AT get_object_keys( ) INTO DATA(key).
      IF key-pgmid = 'R3TR' AND ( key-object = 'CLAS' OR key-object = 'INTF' ).
        APPEND VALUE #(
          unit        = CONV string( key-obj_name )
          object_name = CONV versobjnam( key-obj_name )
          type        = CONV versobjtyp( key-object ) ) TO result.
      ELSE.
        DATA(obj) = get_object( key ).
        IF obj IS BOUND.
          APPEND LINES OF obj->get_parts( ) TO result.
        ELSE.
          APPEND VALUE #(
            unit        = CONV string( key-obj_name )
            object_name = CONV versobjnam( key-obj_name )
            type        = CONV versobjtyp( key-object ) ) TO result.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
