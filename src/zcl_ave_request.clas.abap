"! Represents an SAP transport request — reads E070/E071 data
CLASS zcl_ave_request DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA id          TYPE trkorr    READ-ONLY.
    DATA description TYPE as4text   READ-ONLY.
    DATA status      TYPE trstatus  READ-ONLY.

    METHODS constructor
      IMPORTING
        !id TYPE trkorr
      RAISING
        zcx_ave.

    "! Resolve the K-request(s) associated with iv_trkorr:
    "! K → itself, S/R → parent strkorr, T → CORR/MERG entries.
    CLASS-METHODS resolve_parent_k
      IMPORTING
        iv_trkorr     TYPE trkorr
      RETURNING
        VALUE(result) TYPE zif_ave_object=>ty_t_korr_range.

    "! Returns the task (E070) most likely responsible for the given object.
    "! Prefers single-task requests; falls back to E071 lookup.
    METHODS get_task_for_object
      IMPORTING
                object_type   TYPE versobjtyp
                object_name   TYPE versobjnam
                version_date  TYPE as4date OPTIONAL
                version_time  TYPE as4time OPTIONAL
      RETURNING VALUE(result) TYPE e070.

protected section.
  PRIVATE SECTION.

    METHODS populate_details
      IMPORTING
        !id TYPE trkorr
      RAISING
        zcx_ave.

    METHODS get_latest_task_for_object
      IMPORTING
                object_type   TYPE versobjtyp
                object_name   TYPE versobjnam
                version_date  TYPE as4date OPTIONAL
                version_time  TYPE as4time OPTIONAL
      RETURNING VALUE(result) TYPE e070.

ENDCLASS.



CLASS ZCL_AVE_REQUEST IMPLEMENTATION.


  METHOD constructor.
    me->id = id.
    populate_details( id ).
  ENDMETHOD.


  METHOD populate_details.
    SELECT as4text, trstatus INTO (@description, @status)
      UP TO 1 ROWS
      FROM e070
      LEFT JOIN e07t ON e07t~trkorr = e070~trkorr
      WHERE e070~trkorr = @id
      ORDER BY as4text, trstatus.
      EXIT.
    ENDSELECT.
    " E070 may be empty in sandbox/copy systems — silently ignore.
  ENDMETHOD.


  METHOD resolve_parent_k.
    SELECT SINGLE trfunction, strkorr FROM e070
      WHERE trkorr = @iv_trkorr
      INTO (@DATA(lv_trfunction), @DATA(lv_strkorr)).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE lv_trfunction.
      WHEN 'K'.
        APPEND iv_trkorr TO result.
      WHEN 'S' OR 'R'.
        IF lv_strkorr IS NOT INITIAL.
          APPEND lv_strkorr TO result.
        ENDIF.
      WHEN 'T'.
        " The T's CORR/MERG entries name the K request(s) it was merged from.
        SELECT obj_name FROM e071
          WHERE trkorr = @iv_trkorr
            AND pgmid  = 'CORR'
            AND object = 'MERG'
          INTO TABLE @DATA(lt_merg_obj).
        LOOP AT lt_merg_obj INTO DATA(lv_merg_obj).
          APPEND CONV trkorr( lv_merg_obj(10) ) TO result.
        ENDLOOP.
        SORT result.
        DELETE ADJACENT DUPLICATES FROM result.
    ENDCASE.
  ENDMETHOD.


  METHOD get_task_for_object.
    DATA(lv_object_type) = SWITCH versobjtyp( object_type
      WHEN 'REPS' OR 'REPT' THEN 'PROG'
      WHEN 'CINC' OR 'CLSD' OR
           'CPUB' OR 'CPRO' OR 'CPRI' THEN 'CLAS'
      ELSE object_type ).
    DATA(lv_object_name) = object_name.
    CASE object_type.
      WHEN 'CINC' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'REPT'.
        DATA(lv_eq) = find( val = lv_object_name sub = '=' ).
        IF lv_eq > 0.
          lv_object_name = lv_object_name(lv_eq).
        ENDIF.
    ENDCASE.

    result = get_latest_task_for_object(
      object_type  = lv_object_type
      object_name  = lv_object_name
      version_date = version_date
      version_time = version_time ).
  ENDMETHOD.


  METHOD get_latest_task_for_object.
    " Authoring tasks are the S (development) and R (repair) children of a K —
    " the same pair zcl_ave_version_list matches against.
    DATA lt_trf_task_types TYPE RANGE OF e070-trfunction.
    lt_trf_task_types = VALUE #(
      ( sign = 'I' option = 'EQ' low = 'S' )
      ( sign = 'I' option = 'EQ' low = 'R' ) ).
    DATA lv_request_trfunction TYPE e070-trfunction.
    DATA lt_tasks TYPE STANDARD TABLE OF e070.
    TYPES: BEGIN OF ty_obj_key,
             object   TYPE e071-object,
             obj_name TYPE e071-obj_name,
           END OF ty_obj_key.
    DATA lt_keys TYPE SORTED TABLE OF ty_obj_key WITH UNIQUE KEY object obj_name.

    INSERT VALUE #( object = object_type obj_name = object_name ) INTO TABLE lt_keys.
    IF object_type = 'PROG'.
      INSERT VALUE #( object = 'REPS' obj_name = object_name ) INTO TABLE lt_keys.
    ELSEIF object_type = 'REPS'.
      INSERT VALUE #( object = 'PROG' obj_name = object_name ) INTO TABLE lt_keys.
    ENDIF.

    SELECT SINGLE trfunction FROM e070
      WHERE trkorr = @me->id
      INTO @lv_request_trfunction.

    IF lv_request_trfunction IN lt_trf_task_types.
      SELECT SINGLE trkorr, strkorr, as4user, as4date, as4time
        FROM e070
        WHERE trkorr = @me->id
        INTO CORRESPONDING FIELDS OF @result.
      RETURN.
    ENDIF.

    SELECT e070~trkorr, e070~strkorr, e070~as4user, e070~as4date, e070~as4time
      FROM e071
      INNER JOIN e070 ON e070~trkorr = e071~trkorr
      FOR ALL ENTRIES IN @lt_keys
      WHERE e071~object     = @lt_keys-object
        AND e071~obj_name   = @lt_keys-obj_name
        AND e070~trfunction IN @lt_trf_task_types
      INTO CORRESPONDING FIELDS OF TABLE @lt_tasks.

    SORT lt_tasks BY as4date DESCENDING as4time DESCENDING.
    LOOP AT lt_tasks INTO DATA(ls_task).
      CHECK version_date IS INITIAL
         OR ls_task-as4date < version_date
         OR ( ls_task-as4date = version_date AND ls_task-as4time <= version_time ).
      CHECK ( lv_request_trfunction <> 'K' AND lv_request_trfunction <> 'T' )
         OR ls_task-strkorr = me->id.
      result = ls_task.
      EXIT.
    ENDLOOP.

    " Nothing precedes the version by date. E070-AS4DATE is the header's last-changed
    " stamp, not the moment the object entered the task, so a long-lived task (typically
    " an R) can carry a date past its own versions and never win the comparison above.
    " Fall back to the newest candidate — the set already only holds tasks that contain
    " this object and, for a K/T, belong to this request.
    IF result IS INITIAL.
      LOOP AT lt_tasks INTO DATA(ls_fallback_task).
        CHECK ( lv_request_trfunction <> 'K' AND lv_request_trfunction <> 'T' )
           OR ls_fallback_task-strkorr = me->id.
        result = ls_fallback_task.
        EXIT.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
