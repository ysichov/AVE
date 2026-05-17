class ZCL_AVE_AI_API definition
  public
  create private .

public section.
  class-methods ASK
    importing
      !I_PROMPT type STRING
      !I_DEST type TEXT255
      !I_MODEL type TEXT255
      !I_APIKEY type STRING
    returning
      value(RV_ANSWER) type STRING .
protected section.
private section.
  class-methods BUILD_PAYLOAD
    importing
      !I_PROMPT type STRING
      !I_MODEL type TEXT255
    returning
      value(RV_JSON) type STRING .
  class-methods PARSE_RESPONSE
    importing
      !I_JSON type STRING
    returning
      value(RV_ANSWER) type STRING .
ENDCLASS.



CLASS ZCL_AVE_AI_API IMPLEMENTATION.

  METHOD ask.
    DATA payload TYPE string.
    DATA o_client TYPE REF TO if_http_client.

    payload = build_payload( i_prompt = i_prompt i_model = i_model ).

    CALL METHOD cl_http_client=>create_by_destination
      EXPORTING
        destination           = i_dest
      IMPORTING
        client                = o_client
      EXCEPTIONS
        destination_not_found = 2
        OTHERS                = 5.

    IF sy-subrc = 2.
      rv_answer = 'Error: Destination not found (check SM59)'.
      RETURN.
    ELSEIF sy-subrc <> 0.
      rv_answer = |Error: cl_http_client rc={ sy-subrc }|.
      RETURN.
    ENDIF.

    o_client->request->set_header_field( name = 'Content-Type' value = 'application/json' ).
    o_client->request->set_header_field( name = 'anthropic-version' value = '2023-06-01' ).
    o_client->request->set_header_field( name = 'x-api-key' value = i_apikey ).
    o_client->request->set_method( 'POST' ).
    o_client->request->set_cdata( payload ).

    o_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        OTHERS                     = 5 ).
    IF sy-subrc <> 0.
      rv_answer = 'Error: HTTP send failed'.
      RETURN.
    ENDIF.

    o_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        OTHERS                     = 4 ).

    DATA(lv_response) = o_client->response->get_cdata( ).
    rv_answer = parse_response( lv_response ).
  ENDMETHOD.


  METHOD build_payload.
    DATA lv_prompt TYPE string.

    lv_prompt = i_prompt.
    REPLACE ALL OCCURRENCES OF '\' IN lv_prompt WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN lv_prompt WITH '\"'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_prompt WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_prompt WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>form_feed IN lv_prompt WITH '\f'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_prompt WITH '\t'.

    rv_json = |{ '{' }"model": "{ i_model }", "messages": [{ '{' }"role": "user", "content": "{ lv_prompt }"{ '}' }], "max_tokens": 2000{ '}' }|.
  ENDMETHOD.


  METHOD parse_response.
    TYPES:
      BEGIN OF t_content_block,
        type TYPE string,
        text TYPE string,
      END OF t_content_block,
      t_content_blocks TYPE STANDARD TABLE OF t_content_block WITH NON-UNIQUE DEFAULT KEY,
      BEGIN OF t_anthropic_res,
        id          TYPE string,
        type        TYPE string,
        role        TYPE string,
        model       TYPE string,
        stop_reason TYPE string,
        content     TYPE t_content_blocks,
      END OF t_anthropic_res.

    DATA response TYPE t_anthropic_res.
    /ui2/cl_json=>deserialize( EXPORTING json = i_json CHANGING data = response ).

    IF response-content IS NOT INITIAL.
      rv_answer = response-content[ 1 ]-text.
    ELSE.
      rv_answer = i_json.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
