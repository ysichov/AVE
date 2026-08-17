class ZCL_AVE_AI_API definition
  public
  create private .

public section.
  types:
    " One LLM provider of the selection-screen dropdown.
    BEGIN OF ty_provider,
      " Key as it travels through the settings, e.g. 'ANTHROPIC'
      id   TYPE string,
      " Base URL including the version segment; the resource path is appended
      " by ASK from the wire format
      url  TYPE string,
      " Wire format spoken by the host: ANTHROPIC or OPENAI (everything else in
      " the list is OpenAI-compatible)
      wire TYPE string,
    END OF ty_provider .
  types:
    ty_t_provider TYPE STANDARD TABLE OF ty_provider WITH DEFAULT KEY .

  " The provider list, hard-coded on purpose: AVE stays a report plus classes,
  " with no customizing table to create before the first call.
  class-methods PROVIDERS
    returning
      value(RT_PROVIDERS) type TY_T_PROVIDER .
  " Base URL of one provider (empty when the id is unknown).
  class-methods BASE_URL
    importing
      !I_PROVIDER type STRING
    returning
      value(RV_URL) type STRING .
  " Wire format of one provider: 'ANTHROPIC' or 'OPENAI'.
  class-methods WIRE_OF
    importing
      !I_PROVIDER type STRING
    returning
      value(RV_WIRE) type STRING .
  " Model ids offered by the provider, read from its /models endpoint — the F4
  " help of the model field, so nobody has to type a model name from memory.
  class-methods LIST_MODELS
    importing
      !I_PROVIDER type STRING
      !I_APIKEY type STRING
      !I_URL type TEXT255 optional
      !I_SSL_ID type SSFAPPLSSL default 'ANONYM'
    exporting
      !ET_IDS type STRINGTAB
      !E_ERROR type STRING .
  class-methods ASK
    importing
      !I_PROMPT type STRING
      !I_URL type TEXT255 optional
      !I_SSL_ID type ssfapplssl default 'ANONYM'
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

    DATA lv_id TYPE string.
    lv_id = i_provider.
    TRANSLATE lv_id TO UPPER CASE.
    IF lv_id IS INITIAL.
      lv_id = 'ANTHROPIC'.
    ENDIF.
    " The provider id chooses the host; its wire format chooses payload,
    " headers and the shape of the answer.
    lv_provider = wire_of( lv_id ).

    payload = build_payload(
      i_prompt   = i_prompt
      i_model    = i_model
      i_provider   = lv_provider
      i_system     = i_system
      i_schema     = i_schema
      i_max_tokens = COND i( WHEN i_max_tokens > 0 THEN i_max_tokens ELSE 20000 ) ).

    " Base URL + the resource path of the wire format, unless the user typed a
    " complete endpoint into the URL field.
    DATA(lv_url) = COND string(
      WHEN i_url IS NOT INITIAL
      THEN CONV string( i_url )
      ELSE base_url( lv_id ) &&
           COND string( WHEN lv_provider = 'ANTHROPIC' THEN '/messages' ELSE '/chat/completions' ) ).

    cl_http_client=>create_by_url(
      EXPORTING  url    = lv_url
                 ssl_id = i_ssl_id
      IMPORTING  client = o_client
      EXCEPTIONS OTHERS = 5 ).
    IF sy-subrc <> 0.
      rv_answer = |Error: create_by_url failed rc={ sy-subrc } (check URL / SSL certificate in STRUST)|.
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

    " Without this a 401/403 pops the SAP logon dialog instead of returning the
    " provider's JSON error body — the user sees a password prompt for an API
    " they never logged on to.
    o_client->propertytype_logon_popup = if_http_client=>co_disabled.

    DATA lv_err_code TYPE i.
    DATA lv_err_msg  TYPE string.

    o_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        OTHERS                     = 5 ).
    IF sy-subrc <> 0.
      o_client->get_last_error( IMPORTING code = lv_err_code message = lv_err_msg ).
      rv_answer = |Error: HTTP send failed (code={ lv_err_code } msg={ lv_err_msg })|.
      RETURN.
    ENDIF.

    o_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        OTHERS                     = 4 ).
    IF sy-subrc <> 0.
      o_client->get_last_error( IMPORTING code = lv_err_code message = lv_err_msg ).
      rv_answer = |Error: HTTP receive failed (code={ lv_err_code } msg={ lv_err_msg })|.
      RETURN.
    ENDIF.

    DATA(lv_response) = o_client->response->get_cdata( ).
    rv_answer = parse_response( i_json = lv_response i_provider = lv_provider ).
  ENDMETHOD.


  METHOD providers.
    " Base URLs carry the version segment, exactly as in ABAP-AI-Code, so the
    " same list works for both wire formats. A host that is not here (a company
    " gateway, Azure/Bedrock, a local proxy) is reached by typing its full
    " endpoint into the URL field on the selection screen.
    rt_providers = VALUE #(
      ( id = 'ANTHROPIC'  wire = 'ANTHROPIC' url = 'https://api.anthropic.com/v1' )
      ( id = 'OPENAI'     wire = 'OPENAI'    url = 'https://api.openai.com/v1' )
      ( id = 'GEMINI'     wire = 'OPENAI'    url = 'https://generativelanguage.googleapis.com/v1beta/openai' )
      ( id = 'MISTRAL'    wire = 'OPENAI'    url = 'https://api.mistral.ai/v1' )
      ( id = 'GROQ'       wire = 'OPENAI'    url = 'https://api.groq.com/openai/v1' )
      ( id = 'CEREBRAS'   wire = 'OPENAI'    url = 'https://api.cerebras.ai/v1' )
      ( id = 'OPENROUTER' wire = 'OPENAI'    url = 'https://openrouter.ai/api/v1' )
      ( id = 'NVIDIA'     wire = 'OPENAI'    url = 'https://integrate.api.nvidia.com/v1' ) ).
  ENDMETHOD.


  METHOD base_url.
    DATA(lv_id) = to_upper( condense( i_provider ) ).
    READ TABLE providers( ) INTO DATA(ls_provider) WITH KEY id = lv_id.
    IF sy-subrc = 0.
      rv_url = ls_provider-url.
    ENDIF.
  ENDMETHOD.


  METHOD wire_of.
    DATA(lv_id) = to_upper( condense( i_provider ) ).
    READ TABLE providers( ) INTO DATA(ls_provider) WITH KEY id = lv_id.
    rv_wire = COND string(
      WHEN sy-subrc = 0 THEN ls_provider-wire
      " Unknown id (a hand-typed one): everything except Anthropic speaks the
      " OpenAI format, so that is the safer guess.
      WHEN lv_id = 'ANTHROPIC' THEN 'ANTHROPIC'
      ELSE 'OPENAI' ).
  ENDMETHOD.


  METHOD list_models.
    CLEAR: et_ids, e_error.

    DATA(lv_wire) = wire_of( i_provider ).
    DATA(lv_url) = COND string(
      WHEN i_url IS NOT INITIAL THEN CONV string( i_url )
      ELSE base_url( i_provider ) ) && '/models'.

    DATA lo_client TYPE REF TO if_http_client.
    cl_http_client=>create_by_url(
      EXPORTING  url    = lv_url
                 ssl_id = i_ssl_id
      IMPORTING  client = lo_client
      EXCEPTIONS OTHERS = 5 ).
    IF sy-subrc <> 0.
      e_error = |create_by_url failed rc={ sy-subrc } (check URL / SSL certificate in STRUST)|.
      RETURN.
    ENDIF.

    IF lv_wire = 'ANTHROPIC'.
      lo_client->request->set_header_field( name = 'anthropic-version' value = '2023-06-01' ).
      lo_client->request->set_header_field( name = 'x-api-key'         value = i_apikey ).
    ELSE.
      lo_client->request->set_header_field( name = 'Authorization' value = |Bearer { i_apikey }| ).
    ENDIF.
    lo_client->request->set_method( 'GET' ).
    lo_client->propertytype_logon_popup = if_http_client=>co_disabled.

    lo_client->send( EXCEPTIONS OTHERS = 5 ).
    IF sy-subrc <> 0.
      lo_client->get_last_error( IMPORTING message = DATA(lv_send_msg) ).
      e_error = |HTTP send failed: { lv_send_msg }|.
      RETURN.
    ENDIF.

    lo_client->receive( EXCEPTIONS OTHERS = 4 ).
    IF sy-subrc <> 0.
      lo_client->get_last_error( IMPORTING message = DATA(lv_recv_msg) ).
      e_error = |HTTP receive failed: { lv_recv_msg }|.
      RETURN.
    ENDIF.

    " Both formats answer with {"data":[{"id":"..."}, ...]}.
    TYPES: BEGIN OF ty_model,
             id TYPE string,
           END OF ty_model.
    TYPES: BEGIN OF ty_models,
             data TYPE STANDARD TABLE OF ty_model WITH DEFAULT KEY,
           END OF ty_models.
    DATA ls_models TYPE ty_models.
    /ui2/cl_json=>deserialize(
      EXPORTING json = lo_client->response->get_cdata( )
      CHANGING  data = ls_models ).

    LOOP AT ls_models-data INTO DATA(ls_model).
      CHECK ls_model-id IS NOT INITIAL.
      APPEND ls_model-id TO et_ids.
    ENDLOOP.

    IF et_ids IS INITIAL.
      e_error = |No models returned by { lv_url } (check the API key)|.
    ENDIF.
    SORT et_ids.
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
