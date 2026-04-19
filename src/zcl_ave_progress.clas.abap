"! Cooperative long-running loop interrupter.
"! After `threshold_secs` of continuous work, asks the user whether to
"! continue or stop. Caller decides how to react to a Stop (e.g. break
"! out of the loop with `was_stopped( )`).
CLASS zcl_ave_progress DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING i_title          TYPE csequence DEFAULT 'Long-running operation'
                i_threshold_secs TYPE i         DEFAULT 10.

    "! Call once per iteration. Returns abap_true → caller should stop.
    "! i_remaining is only used for the confirmation text.
    METHODS check
      IMPORTING i_remaining   TYPE i OPTIONAL
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS was_stopped
      RETURNING VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mv_title     TYPE string.
    DATA mv_threshold TYPE i.
    DATA mv_ts_start  TYPE timestampl.
    DATA mv_stopped   TYPE abap_bool.
ENDCLASS.


CLASS zcl_ave_progress IMPLEMENTATION.

  METHOD constructor.
    mv_title     = i_title.
    mv_threshold = i_threshold_secs.
    GET TIME STAMP FIELD mv_ts_start.
  ENDMETHOD.

  METHOD check.
    IF mv_stopped = abap_true.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA lv_now  TYPE timestampl.
    DATA lv_secs TYPE tzntstmpl.
    GET TIME STAMP FIELD lv_now.
    cl_abap_tstmp=>subtract(
      EXPORTING tstmp1 = lv_now tstmp2 = mv_ts_start
      RECEIVING r_secs = lv_secs ).
    IF lv_secs <= mv_threshold.
      RETURN.
    ENDIF.

    DATA(lv_text) = COND string(
      WHEN i_remaining > 0 THEN |{ i_remaining } items remaining. Continue?|
      ELSE                      |Operation is taking a while. Continue?| ).
    DATA lv_answer TYPE c LENGTH 1.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar       = CONV char70( mv_title )
        text_question  = lv_text
        text_button_1  = 'Continue'
        text_button_2  = 'Stop'
        default_button = '2'
      IMPORTING
        answer         = lv_answer.
    IF lv_answer <> '1'.
      mv_stopped = abap_true.
      result     = abap_true.
      RETURN.
    ENDIF.
    GET TIME STAMP FIELD mv_ts_start.
  ENDMETHOD.

  METHOD was_stopped.
    result = mv_stopped.
  ENDMETHOD.

ENDCLASS.
