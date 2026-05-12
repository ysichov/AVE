CLASS zcl_ave_acr_state DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS format_timestamp
      IMPORTING
        !iv_timestamp   TYPE timestampl
      RETURNING
        VALUE(result)   TYPE string.

    CLASS-METHODS set_hunk_action
      IMPORTING
        !iv_hunk_key     TYPE string
        !iv_action       TYPE zif_ave_acr_types=>ty_action_code
      CHANGING
        !ct_hunk_actions TYPE zif_ave_acr_types=>ty_t_hunk_actions.

    CLASS-METHODS clear_hunk_action
      IMPORTING
        !iv_hunk_key     TYPE string
      CHANGING
        !ct_hunk_actions TYPE zif_ave_acr_types=>ty_t_hunk_actions.

    CLASS-METHODS get_hunk_global_action
      IMPORTING
        !iv_hunk_key     TYPE string
        !it_hunk_actions TYPE zif_ave_acr_types=>ty_t_hunk_actions
      RETURNING
        VALUE(result)    TYPE zif_ave_acr_types=>ty_action_code.

    CLASS-METHODS sanitize_review_state
      IMPORTING
        !it_hunk_info    TYPE zif_ave_acr_types=>ty_t_hunk_info
      CHANGING
        !ct_approved     TYPE zif_ave_acr_types=>ty_approved
        !ct_declined     TYPE zif_ave_acr_types=>ty_approved
        !ct_hunk_actions TYPE zif_ave_acr_types=>ty_t_hunk_actions.

    CLASS-METHODS is_own_hunk
      IMPORTING
        !iv_hunk_key   TYPE string
        !it_hunk_info  TYPE zif_ave_acr_types=>ty_t_hunk_info
      RETURNING
        VALUE(result)  TYPE abap_bool.

    CLASS-METHODS get_last_own_comment
      IMPORTING
        !iv_hunk_key      TYPE string
        !it_hunk_threads  TYPE zif_ave_acr_types=>ty_t_hunk_threads
      RETURNING
        VALUE(result)     TYPE string.

    CLASS-METHODS get_reviewer_stats
      IMPORTING
        is_payload      TYPE zif_ave_acr_types=>ty_saved_payload
        it_hunk_info    TYPE zif_ave_acr_types=>ty_t_hunk_info
        it_approved     TYPE zif_ave_acr_types=>ty_approved
        it_declined     TYPE zif_ave_acr_types=>ty_approved
        it_hunk_threads TYPE zif_ave_acr_types=>ty_t_hunk_threads
      RETURNING
        VALUE(result)   TYPE zif_ave_acr_types=>ty_t_reviewer_stats.
ENDCLASS.


CLASS zcl_ave_acr_state IMPLEMENTATION.

  METHOD format_timestamp.
    CHECK iv_timestamp IS NOT INITIAL.
    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    CONVERT TIME STAMP iv_timestamp TIME ZONE sy-zonlo
      INTO DATE lv_date TIME lv_time.
    result = |{ lv_date+6(2) }.{ lv_date+4(2) }.{ lv_date+2(2) } { lv_time(5) }|.
  ENDMETHOD.


  METHOD set_hunk_action.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.
    DELETE ct_hunk_actions WHERE hunk_key = iv_hunk_key AND reviewer = sy-uname.
    APPEND VALUE zif_ave_acr_types=>ty_hunk_action(
      hunk_key      = iv_hunk_key
      reviewer      = sy-uname
      reviewer_name = zcl_ave_popup_data=>get_user_name( sy-uname )
      action        = iv_action
      changed_at    = lv_ts ) TO ct_hunk_actions.
  ENDMETHOD.


  METHOD clear_hunk_action.
    DELETE ct_hunk_actions WHERE hunk_key = iv_hunk_key AND reviewer = sy-uname.
  ENDMETHOD.


  METHOD get_hunk_global_action.
    DATA ls_action TYPE zif_ave_acr_types=>ty_hunk_action.
    LOOP AT it_hunk_actions INTO DATA(ls_action_cur)
      WHERE hunk_key = iv_hunk_key.
      IF ls_action IS INITIAL OR ls_action_cur-changed_at > ls_action-changed_at.
        ls_action = ls_action_cur.
      ENDIF.
    ENDLOOP.
    result = ls_action-action.
  ENDMETHOD.


  METHOD sanitize_review_state.
    CHECK it_hunk_info IS NOT INITIAL.

    LOOP AT ct_approved INTO DATA(lv_approved_key).
      IF NOT line_exists( it_hunk_info[ hunk_key = lv_approved_key ] ).
        DELETE TABLE ct_approved FROM lv_approved_key.
      ENDIF.
    ENDLOOP.

    LOOP AT ct_declined INTO DATA(lv_declined_key).
      IF NOT line_exists( it_hunk_info[ hunk_key = lv_declined_key ] ).
        DELETE TABLE ct_declined FROM lv_declined_key.
      ELSEIF line_exists( ct_approved[ table_line = lv_declined_key ] ).
        DELETE TABLE ct_declined FROM lv_declined_key.
      ENDIF.
    ENDLOOP.

    LOOP AT ct_hunk_actions INTO DATA(ls_action_key).
      IF NOT line_exists( it_hunk_info[ hunk_key = ls_action_key-hunk_key ] ).
        DELETE ct_hunk_actions WHERE hunk_key = ls_action_key-hunk_key.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_own_hunk.
    result = abap_false.
    READ TABLE it_hunk_info INTO DATA(ls_hunk)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    IF sy-subrc = 0 AND ls_hunk-author = sy-uname.
      result = abap_true.
    ELSEIF sy-subrc = 0 AND ls_hunk-author IS INITIAL AND ls_hunk-html CS sy-uname.
      result = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD get_last_own_comment.
    READ TABLE it_hunk_threads INTO DATA(ls_thread)
      WITH TABLE KEY hunk_key = iv_hunk_key.
    CHECK sy-subrc = 0.

    DATA(lv_idx) = lines( ls_thread-messages ).
    WHILE lv_idx > 0.
      READ TABLE ls_thread-messages INTO DATA(ls_msg) INDEX lv_idx.
      IF sy-subrc = 0
         AND ls_msg-author = sy-uname
         AND ls_msg-text IS NOT INITIAL.
        result = ls_msg-text.
        RETURN.
      ENDIF.
      lv_idx -= 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD get_reviewer_stats.
    LOOP AT is_payload-user_states INTO DATA(ls_user_state).
      DATA lv_appr_saved TYPE i.
      DATA lv_decl_saved TYPE i.
      CLEAR: lv_appr_saved, lv_decl_saved.
      LOOP AT ls_user_state-approved INTO DATA(ls_saved_appr_key).
        IF it_hunk_info IS INITIAL
           OR line_exists( it_hunk_info[ hunk_key = ls_saved_appr_key-hunk_key ] ).
          lv_appr_saved += 1.
        ENDIF.
      ENDLOOP.
      LOOP AT ls_user_state-declined INTO DATA(ls_saved_decl_key).
        IF it_hunk_info IS INITIAL
           OR line_exists( it_hunk_info[ hunk_key = ls_saved_decl_key-hunk_key ] ).
          lv_decl_saved += 1.
        ENDIF.
      ENDLOOP.
      CHECK lv_appr_saved > 0 OR lv_decl_saved > 0.
      APPEND VALUE zif_ave_acr_types=>ty_reviewer_stats(
        reviewer      = ls_user_state-reviewer
        reviewer_name = ls_user_state-reviewer_name
        appr_count    = lv_appr_saved
        decl_count    = lv_decl_saved
        total_count   = lv_appr_saved + lv_decl_saved
        saved_at      = ls_user_state-saved_at ) TO result.
    ENDLOOP.

    DATA(lv_appr_cur) = lines( it_approved ).
    DATA(lv_decl_cur) = lines( it_declined ).
    IF lv_appr_cur > 0 OR lv_decl_cur > 0.
      READ TABLE result ASSIGNING FIELD-SYMBOL(<rev>)
        WITH KEY reviewer = sy-uname.
      IF sy-subrc <> 0.
        APPEND VALUE zif_ave_acr_types=>ty_reviewer_stats(
          reviewer      = sy-uname
          reviewer_name = zcl_ave_popup_data=>get_user_name( sy-uname ) ) TO result.
        READ TABLE result ASSIGNING <rev> WITH KEY reviewer = sy-uname.
      ENDIF.
      <rev>-appr_count = lv_appr_cur.
      <rev>-decl_count = lv_decl_cur.
      <rev>-total_count = lv_appr_cur + lv_decl_cur.
    ENDIF.

    LOOP AT it_hunk_threads INTO DATA(ls_thread_cur).
      READ TABLE it_hunk_info INTO DATA(ls_hunk_cur)
        WITH TABLE KEY hunk_key = ls_thread_cur-hunk_key.
      LOOP AT ls_thread_cur-messages INTO DATA(ls_msg_cur).
        CHECK ls_msg_cur-author IS NOT INITIAL.
        IF sy-subrc = 0 AND ls_hunk_cur-author = ls_msg_cur-author.
          CONTINUE.
        ENDIF.
        READ TABLE result ASSIGNING <rev>
          WITH KEY reviewer = ls_msg_cur-author.
        IF sy-subrc <> 0.
          APPEND VALUE zif_ave_acr_types=>ty_reviewer_stats(
            reviewer      = ls_msg_cur-author
            reviewer_name = ls_msg_cur-author_name ) TO result.
          READ TABLE result ASSIGNING <rev> WITH KEY reviewer = ls_msg_cur-author.
        ENDIF.
        IF <rev>-total_count = 0.
          <rev>-total_count = 1.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
