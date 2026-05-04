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

    METHODS get_task_if_only_one
      RETURNING VALUE(result) TYPE e070.

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


  METHOD get_task_if_only_one.
    DATA e070_list TYPE STANDARD TABLE OF e070.
    SELECT trkorr, as4user, as4date, as4time
      INTO CORRESPONDING FIELDS OF TABLE @e070_list
      FROM e070
      WHERE strkorr = @me->id
      ORDER BY PRIMARY KEY.
    IF lines( e070_list ) = 1.
      result = e070_list[ 1 ].
    ENDIF.
  ENDMETHOD.


  METHOD get_latest_task_for_object.
    DATA(lv_trf_s) = CONV e070-trfunction( 'S' ).
    DATA lt_tasks TYPE STANDARD TABLE OF e070.

    SELECT e070~trkorr, as4user, as4date, as4time
      FROM e070
      INNER JOIN e071 ON e071~trkorr = e070~trkorr
      WHERE e070~trfunction = @lv_trf_s
        AND e071~object     = @object_type
        AND e071~obj_name   = @object_name
      INTO CORRESPONDING FIELDS OF TABLE @lt_tasks.

    SORT lt_tasks BY as4date DESCENDING as4time DESCENDING.
    LOOP AT lt_tasks INTO result.
      CHECK version_date IS INITIAL
         OR result-as4date < version_date
         OR ( result-as4date = version_date AND result-as4time <= version_time ).
      EXIT.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
