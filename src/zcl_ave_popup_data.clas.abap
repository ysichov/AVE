CLASS zcl_ave_popup_data DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Full name of a user (USR01/AD display name).
    CLASS-METHODS get_user_name
      IMPORTING iv_user       TYPE versuser
      RETURNING VALUE(result) TYPE ad_namtext.

    "! Author of the most recent version of an object (from VRSD).
    CLASS-METHODS get_latest_author
      IMPORTING i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
      RETURNING VALUE(result) TYPE versuser.

    "! True if the object exists in the system (TADIR / SEOCOMPO check).
    CLASS-METHODS check_part_exists
      IMPORTING i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
                i_class_name  TYPE seoclsname OPTIONAL
      RETURNING VALUE(result) TYPE abap_bool.

    "! Object-type description text (lazy-loaded from TRINT_OBJECT_TABLE, cached).
    CLASS-METHODS get_type_text
      IMPORTING i_type        TYPE versobjtyp
      RETURNING VALUE(result) TYPE as4text.

    "! True if any part of the class was last changed by i_user.
    CLASS-METHODS check_class_has_author
      IMPORTING i_class_name  TYPE string
                i_user        TYPE versuser
      RETURNING VALUE(result) TYPE abap_bool.

    "! Read source of a single version. Builds a synthetic VRSD row if none
    "! is stored yet (e.g. version pending in an unreleased task).
    CLASS-METHODS get_ver_source
      IMPORTING i_objtype     TYPE versobjtyp
                i_objname     TYPE versobjnam
                i_versno      TYPE versno
                i_korrnum     TYPE trkorr  OPTIONAL
                i_author      TYPE versuser OPTIONAL
                i_datum       TYPE versdate OPTIONAL
                i_zeit        TYPE verstime OPTIONAL
      RETURNING VALUE(result) TYPE abaptxt255_tab.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_type_text,
        type TYPE versobjtyp,
        text TYPE as4text,
      END OF ty_type_text.
    CLASS-DATA mt_type_cache TYPE HASHED TABLE OF ty_type_text WITH UNIQUE KEY type.
    CLASS-DATA mv_cache_loaded TYPE abap_bool VALUE abap_false.
    CLASS-METHODS load_type_cache.
ENDCLASS.


CLASS zcl_ave_popup_data IMPLEMENTATION.

  METHOD get_user_name.
    result = NEW zcl_ave_author( )->get_name( iv_user ).
  ENDMETHOD.


  METHOD get_latest_author.
    DATA(lo_vrsd) = NEW zcl_ave_vrsd( type = i_type name = i_name ).
    IF lo_vrsd->vrsd_list IS INITIAL. RETURN. ENDIF.
    DATA(lt_list) = lo_vrsd->vrsd_list.
    SORT lt_list BY versno DESCENDING.
    result = lt_list[ 1 ]-author.
  ENDMETHOD.


  METHOD check_part_exists.
    IF i_type = 'RELE'.
      result = abap_true.
      RETURN.
    ENDIF.

    " METH: check existence directly in SEOCOMPO (class/method component table)
    IF i_type = 'METH' AND i_class_name IS NOT INITIAL.
      DATA lv_meth_cmpname TYPE seocmpname.
      DATA lv_cmptype      TYPE seocmptype VALUE '1'.
      lv_meth_cmpname = i_name.
      SELECT SINGLE clsname FROM seocompo
        WHERE clsname = @i_class_name
          AND cmpname = @lv_meth_cmpname
          AND cmptype = @lv_cmptype
        INTO @DATA(lv_cls_found).
      result = boolc( sy-subrc = 0 ).
      RETURN.
    ENDIF.

    IF i_type = 'CPUB' OR i_type = 'CPRO' OR i_type = 'CPRI'.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA lv_tadir_type TYPE tadir-object.
    IF i_type = 'REPS'.
      lv_tadir_type = 'PROG'.
    ELSEIF i_type = 'CLSD'.
      lv_tadir_type = 'CLAS'.   " VRSD 'CLSD' = class header, exists as CLAS in TADIR/TR
    ELSE.
      lv_tadir_type = i_type.
    ENDIF.

    DATA lv_obj_name TYPE tadir-obj_name.
    lv_obj_name = i_name.
    DATA lv_pgmid TYPE tadir-pgmid.
    SELECT SINGLE pgmid FROM tadir
      WHERE pgmid    = 'R3TR'
        AND object   = @lv_tadir_type
        AND obj_name = @lv_obj_name
        AND delflag  = ' '
      INTO @lv_pgmid.
    result = boolc( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD get_type_text.
    IF mv_cache_loaded = abap_false.
      load_type_cache( ).
    ENDIF.
    READ TABLE mt_type_cache ASSIGNING FIELD-SYMBOL(<c>) WITH TABLE KEY type = i_type.
    IF sy-subrc = 0.
      result = <c>-text.
    ENDIF.
  ENDMETHOD.


  METHOD load_type_cache.
    mv_cache_loaded = abap_true.
    DATA lt_types_out TYPE STANDARD TABLE OF ko100.
    CALL FUNCTION 'TRINT_OBJECT_TABLE'
      EXPORTING iv_complete  = 'X'
      TABLES    tt_types_out = lt_types_out.
    LOOP AT lt_types_out INTO DATA(ls_ko100).
      INSERT VALUE #( type = ls_ko100-object text = ls_ko100-text )
        INTO TABLE mt_type_cache.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_ver_source.
    DATA lt_vrsd TYPE vrsd_tab.
    DATA(lv_vno) = zcl_ave_versno=>to_internal( i_versno ).
    SELECT * FROM vrsd
      WHERE objtype = @i_objtype
        AND objname = @i_objname
        AND versno  = @lv_vno
      INTO TABLE @lt_vrsd UP TO 1 ROWS.
    IF lt_vrsd IS INITIAL.
      " Synthetic VRSD row so SVRS_GET_REPS_FROM_OBJECT can still resolve the source.
      APPEND VALUE vrsd(
        objtype = i_objtype
        objname = i_objname
        versno  = lv_vno
        korrnum = i_korrnum
        author  = i_author
        datum   = i_datum
        zeit    = i_zeit
      ) TO lt_vrsd.
    ENDIF.
    result = NEW zcl_ave_version( lt_vrsd[ 1 ] )->get_source( ).
  ENDMETHOD.


  METHOD check_class_has_author.
    TRY.
        DATA(lo_obj) = NEW zcl_ave_object_factory( )->get_instance(
          object_type = zcl_ave_object_factory=>gc_type-class
          object_name = CONV #( i_class_name ) ).
        LOOP AT lo_obj->get_parts( ) INTO DATA(ls_part).
          CHECK ls_part-type <> 'RELE'.
          IF get_latest_author( i_type = ls_part-type i_name = ls_part-object_name ) = i_user.
            result = abap_true.
            RETURN.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
