CLASS zcl_ave_acr_repository DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS has_review_table
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Does ZAVE_REVIEW carry the REMOTE key field? A table created before it
    "! existed does not, and a dynamic WHERE on a column that is not there
    "! raises CX_SY_DYNAMIC_OSQL_SEMANTICS — which the caller would read as
    "! "no review saved" and every stored review would vanish from view. So the
    "! field is asked for once and the statement is built accordingly.
    CLASS-METHODS has_remote_field
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! One saved review per request AND per remote system. A review run with a
    "! remote system is a different review: its baseline is the state the other
    "! system already has, not the version before the request, so its diffs,
    "! its blocks and its approvals are not the ones of the plain review. They
    "! must not overwrite each other, hence REMOTE is part of the key.
    "! Empty REMOTE = the review without a remote comparison.
    CLASS-METHODS load_review_payload
      IMPORTING
        iv_trkorr     TYPE trkorr
        iv_remote     TYPE verssysnam OPTIONAL
      CHANGING
        cs_payload    TYPE any
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS save_review_payload
      IMPORTING
        iv_trkorr     TYPE trkorr
        iv_remote     TYPE verssysnam OPTIONAL
        is_payload    TYPE any
      RETURNING
        VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    CLASS-DATA gv_remote_field TYPE c LENGTH 1.
ENDCLASS.


CLASS zcl_ave_acr_repository IMPLEMENTATION.



  METHOD has_review_table.
    SELECT SINGLE tabname
      FROM dd02l
      WHERE tabname  = 'ZAVE_REVIEW'
        AND as4local = 'A'
        AND tabclass = 'TRANSP'
      INTO @DATA(lv_tabname).

    result = xsdbool( sy-subrc = 0 AND lv_tabname IS NOT INITIAL ).
  ENDMETHOD.


  METHOD has_remote_field.
    " ' ' not asked yet, 'X' present, '-' absent.
    IF gv_remote_field IS INITIAL.
      SELECT SINGLE fieldname
        FROM dd03l
        WHERE tabname   = 'ZAVE_REVIEW'
          AND fieldname = 'REMOTE'
          AND as4local  = 'A'
        INTO @DATA(lv_field).
      gv_remote_field = COND #( WHEN sy-subrc = 0 AND lv_field IS NOT INITIAL THEN 'X' ELSE '-' ).
    ENDIF.
    result = xsdbool( gv_remote_field = 'X' ).
  ENDMETHOD.


  METHOD load_review_payload.
    CLEAR cs_payload.
    DATA lv_payload_json TYPE string.
    DATA lv_tabname TYPE tabname VALUE 'ZAVE_REVIEW'.

    TRY.
        IF has_remote_field( ) = abap_true.
          SELECT SINGLE payload
            FROM (lv_tabname)
            WHERE trkorr = @iv_trkorr
              AND remote = @iv_remote
            INTO @lv_payload_json.
        ELSE.
          SELECT SINGLE payload
            FROM (lv_tabname)
            WHERE trkorr = @iv_trkorr
            INTO @lv_payload_json.
        ENDIF.
      CATCH cx_sy_dynamic_osql_semantics
            cx_sy_dynamic_osql_syntax
            cx_sy_open_sql_db.
        RETURN.
    ENDTRY.

    IF sy-subrc <> 0 OR lv_payload_json IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json = lv_payload_json
          CHANGING  data = cs_payload ).
        result = abap_true.
      CATCH cx_root.
        CLEAR cs_payload.
    ENDTRY.
  ENDMETHOD.


  METHOD save_review_payload.
    DATA lv_tabname TYPE tabname VALUE 'ZAVE_REVIEW'.
    DATA lr_review_db TYPE REF TO data.
    DATA(lv_payload_json) = /ui2/cl_json=>serialize( data = is_payload ).

    TRY.
        IF has_remote_field( ) = abap_true.
          UPDATE (lv_tabname)
            SET payload = @lv_payload_json
            WHERE trkorr = @iv_trkorr
              AND remote = @iv_remote.
        ELSE.
          UPDATE (lv_tabname)
            SET payload = @lv_payload_json
            WHERE trkorr = @iv_trkorr.
        ENDIF.
        IF sy-subrc <> 0.
          CREATE DATA lr_review_db TYPE (lv_tabname).
          ASSIGN lr_review_db->* TO FIELD-SYMBOL(<ls_review_db>).
          IF <ls_review_db> IS ASSIGNED.
            ASSIGN COMPONENT 'TRKORR' OF STRUCTURE <ls_review_db> TO FIELD-SYMBOL(<lv_trkorr>).
            ASSIGN COMPONENT 'PAYLOAD' OF STRUCTURE <ls_review_db> TO FIELD-SYMBOL(<lv_payload>).
            " REMOTE is part of the key, but a table created before it existed
            " does not have the field — the assign simply fails and the row is
            " written as it was, which is exactly the pre-remote behaviour.
            ASSIGN COMPONENT 'REMOTE' OF STRUCTURE <ls_review_db> TO FIELD-SYMBOL(<lv_remote>).
            IF <lv_remote> IS ASSIGNED.
              <lv_remote> = iv_remote.
            ENDIF.
            IF <lv_trkorr> IS ASSIGNED AND <lv_payload> IS ASSIGNED.
              <lv_trkorr> = iv_trkorr.
              <lv_payload> = lv_payload_json.
              INSERT (lv_tabname) FROM @<ls_review_db>.
            ELSE.
              sy-subrc = 4.
            ENDIF.
          ELSE.
            sy-subrc = 4.
          ENDIF.
        ENDIF.
      CATCH cx_sy_create_data_error
            cx_sy_dynamic_osql_semantics
            cx_sy_dynamic_osql_syntax
            cx_sy_open_sql_db.
        sy-subrc = 4.
    ENDTRY.

    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

ENDCLASS.
