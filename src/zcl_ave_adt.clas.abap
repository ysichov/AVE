"! Opens one object part in Eclipse (ADT).
"!
"! The jump is a plain `adt://` URL handed to the frontend, the same way
"! ZCL_ACE_WINDOW=>OPEN_IN_ADT does it in the ACE project: an installed ADT
"! registers the protocol with the OS and opens the object in the editor.
"! Nothing is called on the SAP side, so there is no destination, no RFC and
"! no ADT session — a system without Eclipse simply gets an OS error.
"!
"! The type mapping is the VRSD one AVE works with everywhere else (REPS,
"! METH, CPUB, TABD, …), not the TADIR one.
CLASS zcl_ave_adt DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! True when this object type has an ADT editor. Deliberately answered from
    "! the type alone: the link is rendered per row of a report that can hold
    "! hundreds of objects, and the URL itself (which reads TRDIR/TFDIR) is
    "! built only when the link is actually followed.
    CLASS-METHODS is_openable
      IMPORTING iv_objtype    TYPE versobjtyp
      RETURNING VALUE(result) TYPE abap_bool.

    "! The adt:// URL of one part; empty when the part has no ADT editor.
    CLASS-METHODS build_url
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_class      TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE string.

    "! Hands the URL to the frontend.
    CLASS-METHODS open
      IMPORTING iv_objtype TYPE versobjtyp
                iv_objname TYPE versobjnam
                iv_class   TYPE string OPTIONAL.

    "! "TYPE~NAME" as it arrives from a `sapevent:adt~` link.
    CLASS-METHODS open_by_key
      IMPORTING iv_key TYPE string.

    "! Small "ADT" badge for a list row; empty for a type without ADT editor.
    "! IV_ONCLICK is for a badge sitting inside a clickable header — pass
    "! `event.stopPropagation()` there so the jump does not also collapse it.
    CLASS-METHODS link_html
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_text       TYPE string DEFAULT `ADT`
                iv_onclick    TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE string.

    "! CSS of that badge — add it to the style block of every page using LINK_HTML.
    CLASS-METHODS css
      RETURNING VALUE(result) TYPE string.

    "! Fixed top-right bar with the Eclipse jump and, when IV_REFRESH_EV is
    "! given, a refresh next to it — inserted before </body> of a rendered page.
    "! Top-right on purpose: the review pages already own the top-left corner
    "! with their Back button.
    CLASS-METHODS add_bar
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_refresh_ev TYPE string OPTIONAL
      CHANGING  cv_html       TYPE string.

    "! The same two buttons as inline links, for pages that build their own
    "! button row (object view, class view).
    CLASS-METHODS buttons_html
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_refresh_ev TYPE string OPTIONAL
                iv_css_class  TYPE string DEFAULT `filter-btn`
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.

    "! Path behind /sap/bc/adt/ plus the optional URL fragment that selects a
    "! sub-object. Empty path = nothing to open.
    CLASS-METHODS path_of
      IMPORTING iv_objtype  TYPE versobjtyp
                iv_objname  TYPE versobjnam
                iv_class    TYPE string OPTIONAL
      EXPORTING ev_path     TYPE string
                ev_fragment TYPE string.

    CLASS-METHODS oo_path
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_class      TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS prog_path
      IMPORTING iv_name       TYPE string
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS class_of
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_class      TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS method_of
      IMPORTING iv_objname    TYPE versobjnam
      RETURNING VALUE(result) TYPE string.

    "! Function group owning an include, read from its master program.
    CLASS-METHODS group_of_include
      IMPORTING iv_include    TYPE progname
      RETURNING VALUE(result) TYPE string.

    "! Function group owning a function module.
    CLASS-METHODS group_of_function
      IMPORTING iv_funcname   TYPE string
      RETURNING VALUE(result) TYPE string.

    "! SAPL<group> / /NS/SAPL<group> -> <group> / /NS/<group>; empty otherwise.
    CLASS-METHODS group_of_main
      IMPORTING iv_program    TYPE string
      RETURNING VALUE(result) TYPE string.

    "! '/' is not a path separator inside an object name.
    CLASS-METHODS url_name
      IMPORTING iv_name       TYPE string
      RETURNING VALUE(result) TYPE string.

ENDCLASS.



CLASS zcl_ave_adt IMPLEMENTATION.


  METHOD is_openable.
    result = xsdbool(
         iv_objtype = 'CLAS' OR iv_objtype = 'CLSD' OR iv_objtype = 'CPUB'
      OR iv_objtype = 'CPRO' OR iv_objtype = 'CPRI' OR iv_objtype = 'CINC'
      OR iv_objtype = 'CDEF' OR iv_objtype = 'CMAC' OR iv_objtype = 'METH'
      OR iv_objtype = 'INTF'
      OR iv_objtype = 'REPS' OR iv_objtype = 'REPT' OR iv_objtype = 'PROG'
      OR iv_objtype = 'FUNC' OR iv_objtype = 'FUGR'
      OR iv_objtype = 'DDLS'
      OR iv_objtype = 'TABD' OR iv_objtype = 'TABL'
      OR iv_objtype = 'DOMD' OR iv_objtype = 'DOMA'
      OR iv_objtype = 'DTED' OR iv_objtype = 'DTEL'
      OR iv_objtype = 'VIED' OR iv_objtype = 'VIEW'
      OR iv_objtype = 'TTYD' OR iv_objtype = 'TTYP'
      OR iv_objtype = 'STRU'
      OR iv_objtype = 'DEVC' ).
  ENDMETHOD.


  METHOD build_url.
    DATA lv_path TYPE string.
    DATA lv_fragment TYPE string.

    path_of(
      EXPORTING
        iv_objtype  = iv_objtype
        iv_objname  = iv_objname
        iv_class    = iv_class
      IMPORTING
        ev_path     = lv_path
        ev_fragment = lv_fragment ).

    CHECK lv_path IS NOT INITIAL.

    " The fragment keeps its case: it carries an ADT type key (CLAS/OM) that is
    " matched case-sensitively, while the path itself is not.
    result = to_lower( |adt://{ sy-sysid }/sap/bc/adt/{ lv_path }| ) && lv_fragment.
  ENDMETHOD.


  METHOD open.
    DATA(lv_url) = build_url(
      iv_objtype = iv_objtype
      iv_objname = iv_objname
      iv_class   = iv_class ).

    IF lv_url IS INITIAL.
      MESSAGE |No ADT link for { iv_objtype } { iv_objname }| TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    cl_gui_frontend_services=>execute(
      EXPORTING  document = lv_url
      EXCEPTIONS OTHERS   = 1 ).
    IF sy-subrc <> 0.
      MESSAGE |Cannot open ADT link: { lv_url }| TYPE 'S' DISPLAY LIKE 'E'.
    ELSE.
      MESSAGE |ADT: { lv_url }| TYPE 'S'.
    ENDIF.
  ENDMETHOD.


  METHOD open_by_key.
    DATA lv_off TYPE i.
    FIND FIRST OCCURRENCE OF '~' IN iv_key MATCH OFFSET lv_off.
    IF sy-subrc <> 0 OR lv_off = 0.
      RETURN.
    ENDIF.
    DATA lv_start TYPE i.
    lv_start = lv_off + 1.
    DATA lv_type TYPE versobjtyp.
    DATA lv_name TYPE versobjnam.
    lv_type = substring( val = iv_key len = lv_off ).
    lv_name = substring( val = iv_key off = lv_start ).
    CHECK lv_name IS NOT INITIAL.
    open( iv_objtype = lv_type iv_objname = lv_name ).
  ENDMETHOD.


  METHOD link_html.
    CHECK is_openable( iv_objtype ) = abap_true.
    DATA(lv_onclick) = COND string(
      WHEN iv_onclick IS NOT INITIAL THEN | onclick="{ iv_onclick }"|
      ELSE `` ).
    result =
      |<a class="adt" href="sapevent:adt~{ iv_objtype }~{ iv_objname }"{ lv_onclick }| &&
      | title="Open in Eclipse (ADT)">{ iv_text }</a>|.
  ENDMETHOD.


  METHOD css.
    result =
      `.adt{display:inline-block;margin-left:6px;padding:0 5px;border:1px solid #c9b6e0;` &&
      `border-radius:3px;color:#8e44ad!important;background:#faf6ff;text-decoration:none;` &&
      `font:bold 10px Consolas,monospace;vertical-align:middle}` &&
      `.adt:hover{background:#8e44ad;color:#fff!important;border-color:#8e44ad}`.
  ENDMETHOD.


  METHOD buttons_html.
    IF is_openable( iv_objtype ) = abap_true.
      result =
        |<a class="{ iv_css_class }" href="sapevent:adt~{ iv_objtype }~{ iv_objname }"| &&
        | title="Open in Eclipse (ADT)">&#9998; Eclipse</a>|.
    ENDIF.
    CHECK iv_refresh_ev IS NOT INITIAL.
    result = result &&
      |<a class="{ iv_css_class }" href="sapevent:{ iv_refresh_ev }"| &&
      | title="Re-read the object and recompute its diff">&#8635; Refresh</a>|.
  ENDMETHOD.


  METHOD add_bar.
    DATA(lv_openable) = is_openable( iv_objtype ).
    CHECK lv_openable = abap_true OR iv_refresh_ev IS NOT INITIAL.
    CHECK cv_html CS `</body>`.
    " A page can pass through here twice - SCROLL_LAST_HTML_TO re-renders the
    " html it kept, which already carries the bar.
    CHECK NOT cv_html CS `id="ave_adt_bar"`.

    DATA(lv_btn) =
      `padding:5px 12px;border-radius:4px;color:#fff;text-decoration:none;` &&
      `font:bold 12px Consolas,sans-serif;margin-left:4px`.

    DATA(lv_bar) = `<div id="ave_adt_bar" style="position:fixed;top:8px;right:8px;z-index:999;white-space:nowrap">`.
    IF lv_openable = abap_true.
      lv_bar = lv_bar &&
        |<a href="sapevent:adt~{ iv_objtype }~{ iv_objname }"| &&
        | style="background:#8e44ad;{ lv_btn }" title="Open in Eclipse (ADT)">&#9998; Eclipse</a>|.
    ENDIF.
    IF iv_refresh_ev IS NOT INITIAL.
      lv_bar = lv_bar &&
        |<a href="sapevent:{ iv_refresh_ev }"| &&
        | style="background:#16a085;{ lv_btn }" title="Re-read the object">&#8635; Refresh</a>|.
    ENDIF.
    lv_bar = lv_bar && `</div>`.

    cv_html = replace( val = cv_html sub = `</body>` with = lv_bar && `</body>` ).
  ENDMETHOD.


  METHOD path_of.
    CLEAR: ev_path, ev_fragment.

    DATA(lv_name) = condense( CONV string( iv_objname ) ).
    CHECK lv_name IS NOT INITIAL.

    CASE iv_objtype.
      WHEN 'CLAS' OR 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI'
        OR 'CINC' OR 'CDEF' OR 'CMAC' OR 'METH'.
        ev_path = oo_path(
          iv_objtype = iv_objtype
          iv_objname = iv_objname
          iv_class   = iv_class ).
        IF iv_objtype = 'METH' AND ev_path IS NOT INITIAL.
          DATA(lv_method) = method_of( iv_objname ).
          IF lv_method IS NOT INITIAL.
            " ADT sub-object navigation. An ADT that cannot resolve the
            " fragment still opens the class source, so this only ever adds
            " precision — it never costs the jump.
            ev_fragment = |#type=CLAS%2FOM;name={ lv_method }|.
          ENDIF.
        ENDIF.

      WHEN 'INTF'.
        ev_path = |oo/interfaces/{ url_name( lv_name ) }/source/main|.

      WHEN 'FUGR'.
        ev_path = |functions/groups/{ url_name( lv_name ) }/source/main|.

      WHEN 'FUNC'.
        DATA(lv_group) = group_of_function( lv_name ).
        CHECK lv_group IS NOT INITIAL.
        ev_path = |functions/groups/{ url_name( lv_group ) }/fmodules/{ url_name( lv_name ) }/source/main|.

      WHEN 'DDLS'.
        ev_path = |ddic/ddl/sources/{ url_name( lv_name ) }/source/main|.

      " DDIC objects have no source URI — the ADT editor is the object itself.
      WHEN 'TABD' OR 'TABL'.
        ev_path = |ddic/tables/{ url_name( lv_name ) }|.
      WHEN 'DOMD' OR 'DOMA'.
        ev_path = |ddic/domains/{ url_name( lv_name ) }|.
      WHEN 'DTED' OR 'DTEL'.
        ev_path = |ddic/dataelements/{ url_name( lv_name ) }|.
      WHEN 'VIED' OR 'VIEW'.
        ev_path = |ddic/views/{ url_name( lv_name ) }|.
      WHEN 'TTYD' OR 'TTYP'.
        ev_path = |ddic/tabletypes/{ url_name( lv_name ) }|.
      WHEN 'STRU'.
        ev_path = |ddic/structures/{ url_name( lv_name ) }|.
      WHEN 'DEVC'.
        ev_path = |packages/{ url_name( lv_name ) }|.

      WHEN 'REPS' OR 'REPT' OR 'PROG'.
        ev_path = prog_path( lv_name ).

      WHEN OTHERS.
        RETURN.
    ENDCASE.
  ENDMETHOD.


  METHOD oo_path.
    DATA(lv_class) = class_of(
      iv_objtype = iv_objtype
      iv_objname = iv_objname
      iv_class   = iv_class ).
    CHECK lv_class IS NOT INITIAL.

    " Local definitions, implementations, macros and test classes are ADT
    " resources of their own under the class; everything else is the class
    " source. The include name carries which one it is behind the 30-character
    " class padding (ZCL_X=========CCIMP).
    DATA lv_suffix TYPE string.
    DATA(lv_raw) = CONV string( iv_objname ).
    IF iv_objtype <> 'METH' AND strlen( lv_raw ) > 30.
      lv_suffix = to_upper( condense( substring( val = lv_raw off = 30 ) ) ).
    ENDIF.

    DATA(lv_include) = SWITCH string( lv_suffix
      WHEN 'CCDEF' THEN `includes/definitions`
      WHEN 'CCIMP' THEN `includes/implementations`
      WHEN 'CCMAC' THEN `includes/macros`
      WHEN 'CCAU'  THEN `includes/testclasses`
      ELSE              `source/main` ).

    result = |oo/classes/{ url_name( lv_class ) }/{ lv_include }|.
  ENDMETHOD.


  METHOD prog_path.
    DATA(lv_name) = to_upper( condense( iv_name ) ).
    CHECK lv_name IS NOT INITIAL.

    " Class pool include (ZCL_X=========CP, =========CCIMP, …) — the class owns it.
    IF lv_name CS '='.
      result = oo_path( iv_objtype = 'CINC' iv_objname = CONV #( lv_name ) ).
      RETURN.
    ENDIF.

    " SAPL<group> is the main program of a function group, whatever TRDIR says
    " about its type.
    DATA(lv_main_group) = group_of_main( lv_name ).
    IF lv_main_group IS NOT INITIAL.
      result = |functions/groups/{ url_name( lv_main_group ) }/source/main|.
      RETURN.
    ENDIF.

    DATA lv_prog TYPE progname.
    lv_prog = lv_name.
    SELECT SINGLE subc FROM trdir
      WHERE name = @lv_prog
      INTO @DATA(lv_subc).

    CASE lv_subc.
      WHEN 'K'.
        " Class pool without the '=' padding.
        result = |oo/classes/{ url_name( lv_name ) }/source/main|.

      WHEN 'I'.
        DATA(lv_group) = group_of_include( lv_prog ).
        IF lv_group IS NOT INITIAL.
          result = |functions/groups/{ url_name( lv_group ) }/includes/{ url_name( lv_name ) }/source/main|.
        ELSE.
          result = |programs/includes/{ url_name( lv_name ) }/source/main|.
        ENDIF.

      WHEN OTHERS.
        result = |programs/programs/{ url_name( lv_name ) }/source/main|.
    ENDCASE.
  ENDMETHOD.


  METHOD class_of.
    IF iv_class IS NOT INITIAL.
      result = condense( iv_class ).
    ELSE.
      DATA(lv_raw) = CONV string( iv_objname ).
      IF iv_objtype = 'METH' AND strlen( lv_raw ) > 30.
        " VRSD spelling: the class padded to 30 characters in front of the method.
        result = condense( substring( val = lv_raw len = 30 ) ).
      ELSE.
        result = condense( lv_raw ).
      ENDIF.
    ENDIF.

    " Generated include names pad the class with '='.
    DATA(lv_eq) = find( val = result sub = '=' ).
    IF lv_eq > 0.
      result = substring( val = result len = lv_eq ).
    ENDIF.
    result = to_upper( result ).
  ENDMETHOD.


  METHOD method_of.
    DATA(lv_raw) = CONV string( iv_objname ).
    IF strlen( lv_raw ) > 30.
      result = condense( substring( val = lv_raw off = 30 ) ).
    ELSE.
      result = condense( lv_raw ).
    ENDIF.
    result = to_upper( result ).
  ENDMETHOD.


  METHOD group_of_include.
    " Guessing the group out of L<group><suffix> misreads every ordinary
    " include whose name happens to start with L; the master program of the
    " include names it without guessing.
    SELECT master FROM d010inc
      WHERE include = @iv_include
      INTO TABLE @DATA(lt_master).

    LOOP AT lt_master INTO DATA(ls_master).
      DATA(lv_group) = group_of_main( to_upper( condense( CONV string( ls_master-master ) ) ) ).
      IF lv_group IS NOT INITIAL.
        result = lv_group.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD group_of_function.
    DATA lv_funcname TYPE tfdir-funcname.
    lv_funcname = iv_funcname.
    SELECT SINGLE pname FROM tfdir
      WHERE funcname = @lv_funcname
      INTO @DATA(lv_pname).
    CHECK sy-subrc = 0.
    result = group_of_main( to_upper( condense( CONV string( lv_pname ) ) ) ).
  ENDMETHOD.


  METHOD group_of_main.
    IF iv_program CP 'SAPL*'.
      result = substring( val = iv_program off = 4 ).
    ELSEIF iv_program CP '/*/SAPL*'.
      " /NS/SAPLZFOO -> /NS/ZFOO
      result = replace( val = iv_program sub = '/SAPL' with = '/' ).
    ENDIF.
  ENDMETHOD.


  METHOD url_name.
    result = replace( val = iv_name sub = '/' with = '%2f' occ = 0 ).
  ENDMETHOD.

ENDCLASS.
