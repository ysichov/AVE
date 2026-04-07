"! Represents one version of a versionable object part.
"! Loads metadata from VRSD and source code via SVRS_GET_REPS_FROM_OBJECT.
CLASS zcl_ave_version DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF c_version,
        latest_db TYPE versno VALUE 0,
        latest    TYPE versno VALUE 99998,
        active    TYPE versno VALUE 99998,
        modified  TYPE versno VALUE 99999,
      END OF c_version.

    DATA version_number TYPE versno      READ-ONLY.
    DATA request        TYPE verskorrno  READ-ONLY.
    DATA task           TYPE verskorrno  READ-ONLY.
    DATA author         TYPE versuser    READ-ONLY.
    DATA author_name    TYPE ad_namtext  READ-ONLY.
    DATA date           TYPE versdate    READ-ONLY.
    DATA time           TYPE verstime    READ-ONLY.
    DATA objtype        TYPE versobjtyp  READ-ONLY.
    DATA objname        TYPE versobjnam  READ-ONLY.

    METHODS constructor
      IMPORTING
        !vrsd TYPE vrsd
      RAISING
        zcx_ave.

    "! Loads and returns the raw source code for this version
    METHODS get_source
      RETURNING
        VALUE(result) TYPE abaptxt255_tab
      RAISING
        zcx_ave.

  PRIVATE SECTION.

    DATA vrsd TYPE vrsd.

    METHODS load_attributes.

    "! Overwrite author/date/time from the task if possible
    "! (task owner better reflects who actually changed the code)
    METHODS load_latest_task
      RAISING zcx_ave.

    METHODS load_author_name
      RAISING zcx_ave.

ENDCLASS.


CLASS zcl_ave_version IMPLEMENTATION.

  METHOD constructor.
    me->vrsd = vrsd.
    load_attributes( ).
    load_latest_task( ).
    load_author_name( ).
  ENDMETHOD.

  METHOD get_source.
    DATA lt_trdir TYPE trdir_it.

    CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
      EXPORTING
        object_name = vrsd-objname
        object_type = vrsd-objtype
        versno      = zcl_ave_versno=>to_internal( me->version_number )
      TABLES
        repos_tab   = result
        trdir_tab   = lt_trdir
      EXCEPTIONS
        no_version  = 1
        OTHERS      = 2.
    " subrc <> 0 → empty source, not treated as error
  ENDMETHOD.

  METHOD load_attributes.
    me->version_number = vrsd-versno.
    me->author         = vrsd-author.
    me->date           = vrsd-datum.
    me->time           = vrsd-zeit.
    me->request        = vrsd-korrnum.
    me->objtype        = vrsd-objtype.
    me->objname        = vrsd-objname.
  ENDMETHOD.

  METHOD load_latest_task.
    IF me->request IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_request) = NEW zcl_ave_request( me->request ).
    DATA(ls_e070) = lo_request->get_task_for_object(
      object_type = vrsd-objtype
      object_name = vrsd-objname ).
    IF ls_e070-trkorr IS NOT INITIAL.
      me->task   = ls_e070-trkorr.
      me->author = ls_e070-as4user.
      me->date   = ls_e070-as4date.
      me->time   = ls_e070-as4time.
    ENDIF.
  ENDMETHOD.

  METHOD load_author_name.
    me->author_name = NEW zcl_ave_author( )->get_name( me->author ).
  ENDMETHOD.

ENDCLASS.
