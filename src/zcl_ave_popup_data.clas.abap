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
    "! i_korrnum: when provided, only counts changes belonging to that specific TR.
    CLASS-METHODS check_class_has_author
      IMPORTING i_class_name  TYPE string
                i_user        TYPE versuser
                i_korrnum     TYPE trkorr OPTIONAL
      RETURNING VALUE(result) TYPE abap_bool.

    "! True if the latest version of the object was authored by i_user AND
    "! its source differs from the nearest prior version whose transport
    "! request has TRFUNCTION='K' (Workbench request). Raw VRSD history is
    "! used (no deduplication). If no prior K-TR version exists the change
    "! is treated as substantive (first author case).
    "! i_korrnum: when provided, only returns true if the latest version
    "! belongs to that specific TR (as a task or direct request entry).
    CLASS-METHODS is_substantive_user_change
      IMPORTING i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
                i_user        TYPE versuser
                i_korrnum     TYPE trkorr OPTIONAL
      RETURNING VALUE(result) TYPE abap_bool.

    "! Drop consecutive versions whose source is identical (ignoring leading
    "! whitespace). Input must be sorted newest-first.
    CLASS-METHODS remove_duplicate_versions
      CHANGING ct_versions TYPE zif_ave_popup_types=>ty_t_version_row.

    "! Line count of the currently active source for a part (0 when unavailable,
    "! e.g. for CLSD/RELE which have no source).
    CLASS-METHODS get_active_line_count
      IMPORTING i_type        TYPE versobjtyp
                i_name        TYPE versobjnam
      RETURNING VALUE(result) TYPE i.

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

protected section.
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



CLASS ZCL_AVE_POPUP_DATA IMPLEMENTATION.


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


  METHOD remove_duplicate_versions.
    TYPES: BEGIN OF ty_prev,
             objtype TYPE versobjtyp,
             objname TYPE versobjnam,
             src     TYPE abaptxt255_tab,
             has_src TYPE abap_bool,
           END OF ty_prev.
    DATA lt_prev_map TYPE HASHED TABLE OF ty_prev WITH UNIQUE KEY objtype objname.
    DATA lt_result   TYPE zif_ave_popup_types=>ty_t_version_row.

    " ct_versions can contain rows for multiple (objtype,objname) pairs mixed
    " together (e.g. all methods of a class sorted globally by versno). We must
    " compare each row only against the previous row of the SAME object.
    LOOP AT ct_versions INTO DATA(ls_ver).

      " Read source directly from SVRS — bypass zcl_ave_version constructor,
      " whose load_latest_task can raise zcx_ave and leave lt_cur_src empty
      " for some versions while others succeed, producing spurious diffs.
      DATA lt_cur_src TYPE abaptxt255_tab.
      DATA lt_trdir   TYPE trdir_it.
      CLEAR lt_cur_src.
      DATA(lv_db_no) = zcl_ave_versno=>to_internal( ls_ver-versno ).
      CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
        EXPORTING object_name = ls_ver-objname
                  object_type = ls_ver-objtype
                  versno      = lv_db_no
        TABLES    repos_tab   = lt_cur_src
                  trdir_tab   = lt_trdir
        EXCEPTIONS no_version = 1 OTHERS = 2.
      IF sy-subrc <> 0. CLEAR lt_cur_src. ENDIF.

      " Compare ignoring leading whitespace (pretty-printer reindent is not a real change)
      DATA lt_cur_norm  TYPE string_table.
      DATA lt_prev_norm TYPE string_table.
      CLEAR lt_cur_norm. CLEAR lt_prev_norm.
      LOOP AT lt_cur_src INTO DATA(ls_cn).
        DATA(lv_cn) = CONV string( ls_cn ).
        SHIFT lv_cn LEFT DELETING LEADING ` `.
        APPEND lv_cn TO lt_cur_norm.
      ENDLOOP.

      DATA lv_has_prev TYPE abap_bool.
      lv_has_prev = abap_false.
      READ TABLE lt_prev_map ASSIGNING FIELD-SYMBOL(<p>)
        WITH TABLE KEY objtype = ls_ver-objtype objname = ls_ver-objname.
      IF sy-subrc = 0 AND <p>-has_src = abap_true.
        lv_has_prev = abap_true.
        LOOP AT <p>-src INTO DATA(ls_pn).
          DATA(lv_pn) = CONV string( ls_pn ).
          SHIFT lv_pn LEFT DELETING LEADING ` `.
          APPEND lv_pn TO lt_prev_norm.
        ENDLOOP.
      ENDIF.

      IF lv_has_prev = abap_false OR lt_cur_norm <> lt_prev_norm.
        APPEND ls_ver TO lt_result.
        IF <p> IS ASSIGNED.
          <p>-src     = lt_cur_src.
          <p>-has_src = abap_true.
        ELSE.
          INSERT VALUE #( objtype = ls_ver-objtype objname = ls_ver-objname
                          src = lt_cur_src has_src = abap_true )
            INTO TABLE lt_prev_map.
        ENDIF.
      ENDIF.
      UNASSIGN <p>.
    ENDLOOP.

    ct_versions = lt_result.
  ENDMETHOD.


  METHOD get_active_line_count.
    DATA lv_incname TYPE progname.
    DATA lt_src TYPE TABLE OF string.
    TRY.
        CASE i_type.
          WHEN 'CLSD' OR 'RELE' OR 'DEVC' OR 'FUGR' OR 'CLAS'.
            " Aggregate / header types — no single source.
            RETURN.
          WHEN 'INTF'.
            lv_incname = cl_oo_classname_service=>get_interfacepool_name( CONV #( i_name ) ).
          WHEN 'CPUB'.
            lv_incname = cl_oo_classname_service=>get_pubsec_name( CONV #( i_name ) ).
          WHEN 'CPRO'.
            lv_incname = cl_oo_classname_service=>get_prosec_name( CONV #( i_name ) ).
          WHEN 'CPRI'.
            lv_incname = cl_oo_classname_service=>get_prisec_name( CONV #( i_name ) ).
          WHEN 'METH'.
            " i_name layout (VRSD convention): class (30-char, blank-padded) + method
            DATA(lv_cls) = CONV seoclsname( i_name(30) ).
            DATA lv_mtd TYPE seocpdname.
            lv_mtd = i_name+30.
            lv_incname = cl_oo_classname_service=>get_method_include(
              mtdkey = VALUE #( clsname = lv_cls cpdname = lv_mtd ) ).
          WHEN OTHERS.
            lv_incname = i_name.
        ENDCASE.
        IF lv_incname IS INITIAL. RETURN. ENDIF.
        READ REPORT lv_incname INTO lt_src.
        IF sy-subrc = 0.
          result = lines( lt_src ).
        ENDIF.
      CATCH cx_root.
    ENDTRY.
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
          CHECK ls_part-type <> 'CLSD' AND ls_part-type <> 'RELE'.
          IF is_substantive_user_change( i_type = ls_part-type i_name = ls_part-object_name i_user = i_user i_korrnum = i_korrnum ) = abap_true.
            result = abap_true.
            RETURN.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD is_substantive_user_change.
    DATA(lv_dbg) = boolc( i_user = 'DEVELOPER' ).

    " Condition 1: latest version authored by i_user.
    DATA(lo_vrsd) = NEW zcl_ave_vrsd( type = i_type name = i_name ).
    DATA(lt_list) = lo_vrsd->vrsd_list.
    IF lt_list IS INITIAL.
      IF lv_dbg = abap_true.
        MESSAGE |{ i_type } { i_name }: vrsd_list empty → skip| TYPE 'I'.
      ENDIF.
      RETURN.
    ENDIF.
    SORT lt_list BY versno DESCENDING.
    DATA(ls_latest) = lt_list[ 1 ].
    IF i_user IS NOT INITIAL AND ls_latest-author <> i_user.
      IF lv_dbg = abap_true.
        MESSAGE |{ i_type } { i_name }: author={ ls_latest-author } <> { i_user } → skip| TYPE 'I'.
      ENDIF.
      RETURN.
    ENDIF.

    " Condition 1b: when a specific TR is given, the latest version must belong to it.
    " This prevents false positives in K-TR3 when the latest user change was in K-TR2.
    "commented as not working properly
*    IF i_korrnum IS NOT INITIAL.
*      DATA lv_parent TYPE trkorr.
*      SELECT SINGLE strkorr FROM e070 WHERE trkorr = @ls_latest-korrnum
*        INTO @lv_parent.
*      " strkorr IS INITIAL → ls_latest-korrnum is the request itself;
*      " strkorr IS NOT INITIAL → ls_latest-korrnum is a task, parent = strkorr.
*      DATA(lv_owner_request) = COND trkorr(
*        WHEN lv_parent IS NOT INITIAL THEN lv_parent
*        ELSE ls_latest-korrnum ).
*      IF lv_owner_request <> i_korrnum.
*        RETURN.  " latest version not from this TR → no change in this TR
*      ENDIF.
*    ENDIF.

    " Condition 2: nearest prior K-TR version by date/time (single targeted query).
    DATA ls_prior TYPE vrsd.
    DATA(lv_zero_versno) = CONV versno( 0 ).
    SELECT v~versno, v~datum, v~zeit, v~korrnum
      FROM vrsd AS v
      INNER JOIN e070 AS e ON e~trkorr = v~korrnum
      WHERE v~objtype = @i_type
        AND v~objname = @i_name
        AND v~versno  <> @lv_zero_versno
        AND e~trfunction = 'K'
        AND ( v~datum < @ls_latest-datum
           OR ( v~datum = @ls_latest-datum AND v~zeit < @ls_latest-zeit ) )
      ORDER BY v~datum DESCENDING, v~zeit DESCENDING
      INTO CORRESPONDING FIELDS OF @ls_prior
      UP TO 1 ROWS.
    ENDSELECT.

    " No prior K-TR version — user is first author, treat as substantive.
    IF ls_prior-korrnum IS INITIAL.
      result = abap_true.
      RETURN.
    ENDIF.

    " Condition 3: full source equality (direct internal-table compare).
    DATA lt_new   TYPE abaptxt255_tab.
    DATA lt_old   TYPE abaptxt255_tab.
    DATA lt_trdir TYPE trdir_it.
    CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
      EXPORTING object_name = i_name object_type = i_type
                versno      = zcl_ave_versno=>to_internal( ls_latest-versno )
      TABLES    repos_tab   = lt_new trdir_tab = lt_trdir
      EXCEPTIONS no_version = 1 OTHERS = 2.
    IF sy-subrc <> 0. CLEAR lt_new. ENDIF.
    CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
      EXPORTING object_name = i_name object_type = i_type
                versno      = zcl_ave_versno=>to_internal( ls_prior-versno )
      TABLES    repos_tab   = lt_old trdir_tab = lt_trdir
      EXCEPTIONS no_version = 1 OTHERS = 2.
    IF sy-subrc <> 0. CLEAR lt_old. ENDIF.

    result = boolc( lt_new <> lt_old ).
    IF lv_dbg = abap_true AND result = abap_false.
      MESSAGE |{ i_type } { i_name }: latest v={ ls_latest-versno } { ls_latest-datum } { ls_latest-author } / prior K v={ ls_prior-versno } { ls_prior-datum } / new={ lines( lt_new ) } old={ lines( lt_old ) } → NOT colored| TYPE 'I'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
