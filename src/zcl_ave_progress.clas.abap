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
    "! i_remaining is used both for the SAPGUI progress bar percentage
    "! (together with i_total) and for the confirmation text.
    METHODS check
      IMPORTING i_remaining   TYPE i OPTIONAL
                i_total       TYPE i OPTIONAL
                i_text        TYPE csequence OPTIONAL
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS was_stopped
      RETURNING VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mv_title     TYPE string.
    DATA mv_threshold TYPE i.
    DATA mv_ts_start    TYPE timestampl.
    DATA mv_ts_last_bar TYPE timestampl.
    DATA mv_stopped     TYPE abap_bool.
ENDCLASS.


CLASS zcl_ave_progress IMPLEMENTATION.

  METHOD constructor.
    mv_title     = i_title.
    mv_threshold = i_threshold_secs.
    GET TIME STAMP FIELD mv_ts_start.
    mv_ts_last_bar = mv_ts_start.
  ENDMETHOD.

  METHOD check.
    IF mv_stopped = abap_true.
      result = abap_true.
      RETURN.
    ENDIF.

    " SAPGUI progress bar — updated every ~1s to avoid excess roundtrips
    DATA lv_now  TYPE timestampl.
    DATA lv_secs TYPE tzntstmpl.
    GET TIME STAMP FIELD lv_now.
    cl_abap_tstmp=>subtract(
      EXPORTING tstmp1 = lv_now tstmp2 = mv_ts_last_bar
      RECEIVING r_secs = lv_secs ).
    IF lv_secs >= 1 AND i_total > 0 AND i_remaining >= 0.
      DATA(lv_done) = i_total - i_remaining.
      DATA(lv_pct)  = CONV i( lv_done * 100 / i_total ).
      DATA(lv_msg)  = COND string(
        WHEN i_text IS NOT INITIAL THEN |{ i_text } ({ lv_done }/{ i_total })|
        ELSE                            |{ mv_title } ({ lv_done }/{ i_total })| ).
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING percentage = lv_pct text = CONV char70( lv_msg ).
      mv_ts_last_bar = lv_now.
    ENDIF.

    " Threshold check: ask the user whether to keep going
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
