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
      !I_PROVIDER type STRING default 'ANTHROPIC'
      "! System prompt from the selected review profile (<profile>.md)
      !I_SYSTEM type STRING optional
      "! Raw JSON schema from the selected review profile (<profile>.json).
      "! Spliced into the payload as a sub-document, never as an escaped string.
      !I_SCHEMA type STRING optional
      !I_MAX_TOKENS type I default 20000
    returning
      value(RV_ANSWER) type STRING .
protected section.
private section.
  class-methods BUILD_PAYLOAD
    importing
      !I_PROMPT type STRING
      !I_MODEL type TEXT255
      !I_PROVIDER type STRING
      !I_SYSTEM type STRING
      !I_SCHEMA type STRING
      !I_MAX_TOKENS type I
    returning
      value(RV_JSON) type STRING .
  class-methods ESCAPE_JSON
    importing
      !I_TEXT type STRING
    returning
      value(RV_TEXT) type STRING .
  class-methods PARSE_RESPONSE
    importing
      !I_JSON type STRING
      !I_PROVIDER type STRING
    returning
      value(RV_ANSWER) type STRING .
ENDCLASS.



CLASS ZCL_AVE_AI_API IMPLEMENTATION.


  METHOD ask.
    DATA payload TYPE string.
    DATA o_client TYPE REF TO if_http_client.
    DATA lv_provider TYPE string.
    DATA lv_auth TYPE string.

    lv_provider = i_provider.
    TRANSLATE lv_provider TO UPPER CASE.
    IF lv_provider IS INITIAL.
      lv_provider = 'ANTHROPIC'.
    ENDIF.

    payload = build_payload(
      i_prompt   = i_prompt
      i_model    = i_model
      i_provider   = lv_provider
      i_system     = i_system
      i_schema     = i_schema
      i_max_tokens = COND i( WHEN i_max_tokens > 0 THEN i_max_tokens ELSE 20000 ) ).

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
    IF lv_provider = 'OPENAI'.
      lv_auth = i_apikey.
      IF lv_auth CP 'Bearer *' OR lv_auth CP 'bearer *'.
        o_client->request->set_header_field( name = 'Authorization' value = lv_auth ).
      ELSE.
        o_client->request->set_header_field( name = 'Authorization' value = |Bearer { lv_auth }| ).
      ENDIF.
    ELSE.
      o_client->request->set_header_field( name = 'anthropic-version' value = '2023-06-01' ).
      o_client->request->set_header_field( name = 'x-api-key' value = i_apikey ).
    ENDIF.
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
    rv_answer = parse_response( i_json = lv_response i_provider = lv_provider ).
  ENDMETHOD.


  METHOD escape_json.
    rv_text = i_text.
    REPLACE ALL OCCURRENCES OF '\' IN rv_text WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_text WITH '\"'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN rv_text WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_text WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>form_feed IN rv_text WITH '\f'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN rv_text WITH '\t'.
  ENDMETHOD.


  METHOD build_payload.
    DATA(lv_prompt) = escape_json( i_prompt ).

    " System prompt.
    " Anthropic: top-level "system". Sent as a content-block array with a
    "   cache_control marker — the profile prompt is large and identical across
    "   every hunk of a review, so it is billed once per cache window.
    " OpenAI: a leading message with role "system".
    DATA lv_system_field TYPE string.
    DATA lv_system_msg   TYPE string.
    IF i_system IS NOT INITIAL.
      DATA(lv_system) = escape_json( i_system ).
      IF i_provider = 'OPENAI'.
        lv_system_msg = |{ '{' }"role": "system", "content": "{ lv_system }"{ '}' }, |.
      ELSE.
        lv_system_field = |, "system": [{ '{' }"type": "text", "text": "{ lv_system }"| &&
                          |, "cache_control": { '{' }"type": "ephemeral"{ '}' }{ '}' }]|.
      ENDIF.
    ENDIF.

    " Structured output. The schema arrives as raw JSON text from the profile
    " file, so it is spliced in verbatim — escaping it would send a string
    " literal where the API expects an object.
    DATA lv_format_field TYPE string.
    IF i_schema IS NOT INITIAL.
      IF i_provider = 'OPENAI'.
        lv_format_field = |, "response_format": { '{' }"type": "json_schema", "json_schema": { '{' }| &&
                          |"name": "schema", "strict": true, "schema": { i_schema }{ '}' }{ '}' }|.
      ELSE.
        lv_format_field = |, "output_config": { '{' }"format": { '{' }| &&
                          |"type": "json_schema", "schema": { i_schema }{ '}' }{ '}' }|.
      ENDIF.
    ENDIF.

    rv_json = |{ '{' }"model": "{ i_model }"{ lv_system_field }| &&
              |, "messages": [{ lv_system_msg }{ '{' }"role": "user", "content": "{ lv_prompt }"{ '}' }]| &&
              |, "max_tokens": { i_max_tokens }{ lv_format_field }{ '}' }|.
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

    TYPES:
      BEGIN OF t_openai_message,
        role              TYPE string,
        content           TYPE string,
        reasoning_content TYPE string,
      END OF t_openai_message,
      BEGIN OF t_openai_choice,
        index         TYPE string,
        message       TYPE t_openai_message,
        finish_reason TYPE string,
      END OF t_openai_choice,
      t_openai_choices TYPE STANDARD TABLE OF t_openai_choice WITH NON-UNIQUE DEFAULT KEY,
      BEGIN OF t_openai_res,
        id      TYPE string,
        object  TYPE string,
        created TYPE string,
        model   TYPE string,
        choices TYPE t_openai_choices,
      END OF t_openai_res.

    DATA lv_provider TYPE string.
    DATA ls_openai_response TYPE t_openai_res.
    DATA response TYPE t_anthropic_res.

    lv_provider = i_provider.
    TRANSLATE lv_provider TO UPPER CASE.

    IF lv_provider = 'OPENAI'.
      /ui2/cl_json=>deserialize( EXPORTING json = i_json CHANGING data = ls_openai_response ).
      IF ls_openai_response-choices IS NOT INITIAL.
        rv_answer = ls_openai_response-choices[ 1 ]-message-content.
      ELSE.
        rv_answer = i_json.
      ENDIF.
      RETURN.
    ENDIF.

    /ui2/cl_json=>deserialize( EXPORTING json = i_json CHANGING data = response ).

    IF response-content IS NOT INITIAL.
      rv_answer = response-content[ 1 ]-text.
    ELSE.
      rv_answer = i_json.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
