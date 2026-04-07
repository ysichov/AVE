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
      RETURNING VALUE(result) TYPE e070.

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
      RETURNING VALUE(result) TYPE e070.

ENDCLASS.


CLASS zcl_ave_request IMPLEMENTATION.

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
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ave.
    ENDIF.
  ENDMETHOD.

  METHOD get_task_for_object.
    " First try: if there is exactly one task, use it (avoids E071 lookup issues)
    result = get_task_if_only_one( ).

    IF result IS INITIAL.
      result = get_latest_task_for_object(
        object_type = object_type
        object_name = object_name ).
    ENDIF.

    " Workaround: VRSD stores REPS but E071 may store PROG
    IF result IS INITIAL AND object_type = 'REPS'.
      result = get_task_for_object(
        object_type = 'PROG'
        object_name = object_name ).
    ENDIF.
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
    SELECT e070~trkorr, as4user, as4date, as4time
      INTO (result-trkorr, result-as4user, result-as4date, result-as4time)
      FROM e070
      INNER JOIN e071 ON e071~trkorr = e070~trkorr
      UP TO 1 ROWS
      WHERE strkorr  = @me->id
        AND object   = @object_type
        AND obj_name = @object_name
      ORDER BY as4date DESCENDING, as4time DESCENDING.
      EXIT.
    ENDSELECT.
  ENDMETHOD.

ENDCLASS.
