CLASS zcl_ave_acr_repository DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS has_review_table
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS load_review_payload
      IMPORTING
        iv_trkorr     TYPE trkorr
      CHANGING
        cs_payload    TYPE any
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS save_review_payload
      IMPORTING
        iv_trkorr     TYPE trkorr
        is_payload    TYPE any
      RETURNING
        VALUE(result) TYPE abap_bool.
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


  METHOD load_review_payload.
    CLEAR cs_payload.
    DATA lv_payload_json TYPE string.
    DATA lv_tabname TYPE tabname VALUE 'ZAVE_REVIEW'.

    TRY.
        SELECT SINGLE payload
          FROM (lv_tabname)
          WHERE trkorr = @iv_trkorr
          INTO @lv_payload_json.
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
        UPDATE (lv_tabname)
          SET payload = @lv_payload_json
          WHERE trkorr = @iv_trkorr.
        IF sy-subrc <> 0.
          CREATE DATA lr_review_db TYPE (lv_tabname).
          ASSIGN lr_review_db->* TO FIELD-SYMBOL(<ls_review_db>).
          IF <ls_review_db> IS ASSIGNED.
            ASSIGN COMPONENT 'TRKORR' OF STRUCTURE <ls_review_db> TO FIELD-SYMBOL(<lv_trkorr>).
            ASSIGN COMPONENT 'PAYLOAD' OF STRUCTURE <ls_review_db> TO FIELD-SYMBOL(<lv_payload>).
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
