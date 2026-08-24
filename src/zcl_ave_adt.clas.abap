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

    "! "Open in SAP GUI, not in Eclipse" — the P_GUINAV setting, applied to every
    "! jump. The SAP GUI workbench opens in this window and returns control when
    "! it is left, which is what makes an automatic recompute afterwards possible.
    CLASS-DATA gv_gui_nav TYPE abap_bool.

    "! True when this object type has an ADT editor. Deliberately answered from
    "! the type alone: the link is rendered per row of a report that can hold
    "! hundreds of objects, and the URL itself (which reads TRDIR/TFDIR) is
    "! built only when the link is actually followed.
    CLASS-METHODS is_openable
      IMPORTING iv_objtype    TYPE versobjtyp
      RETURNING VALUE(result) TYPE abap_bool.

    "! The adt:// URL of one part; empty when the part has no ADT editor.
    "! IV_LINE positions the editor: it is the line as AVE counts it, i.e. inside
    "! the part — line 1 of a method is its `METHOD …` statement. Where ADT opens
    "! a larger source than the part (a method or a section is part of the class
    "! source) it is translated into the line of that source; where it cannot be
    "! translated the jump falls back to the object.
    CLASS-METHODS build_url
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_class      TYPE string OPTIONAL
                iv_line       TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE string.

    "! Opens the object: the adt:// URL through the frontend, or — with
    "! GV_GUI_NAV — the SAP GUI workbench in this window.
    "! RESULT = "the caller should re-read this object", and it is true after
    "! every workbench jump that came back. RS_TOOL_ACCESS is a drill-in: the
    "! statement after it runs when the editor is left, and that is the whole
    "! trigger. The Eclipse jump is always false — the adt:// URL goes to the OS
    "! and control comes back before anything has been edited.
    CLASS-METHODS open
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_class      TYPE string OPTIONAL
                iv_line       TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE abap_bool.

    "! "TYPE~NAME" as it arrives from a `sapevent:adt~` link.
    CLASS-METHODS open_by_key
      IMPORTING iv_key        TYPE string
                iv_line       TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE abap_bool.

    "! Small "ADT" badge for a list row; empty for a type without ADT editor.
    "! IV_LINE makes it the jump to one line — that is what the badge of a
    "! changed block uses, so a hunk opens where the change is and not at the
    "! top of a 900-line method.
    "! IV_ONCLICK is for a badge sitting inside a clickable header — pass
    "! `event.stopPropagation()` there so the jump does not also collapse it.
    CLASS-METHODS link_html
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_text       TYPE string OPTIONAL
                iv_line       TYPE i DEFAULT 0
                iv_onclick    TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE string.

    "! CSS of that badge — add it to the style block of every page using LINK_HTML.
    CLASS-METHODS css
      RETURNING VALUE(result) TYPE string.

    "! What the jump is called right now: every label follows GV_GUI_NAV, so a
    "! button never promises Eclipse while the setting sends it to the workbench.
    "! BADGE_TEXT is the short form for a list row, BUTTON_TEXT the long one for
    "! a button row, JUMP_TITLE the tooltip of both.
    CLASS-METHODS badge_text
      RETURNING VALUE(result) TYPE string.
    CLASS-METHODS button_text
      RETURNING VALUE(result) TYPE string.
    CLASS-METHODS jump_title
      IMPORTING iv_line       TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE string.

    "! Fixed top-right bar with the Eclipse jump and, when IV_REFRESH_EV is
    "! given, a reload next to it — inserted before </body> of a rendered page.
    "! Top-right on purpose: the review pages already own the top-left corner
    "! with their Back button.
    CLASS-METHODS add_bar
      IMPORTING iv_objtype      TYPE versobjtyp
                iv_objname      TYPE versobjnam
                iv_refresh_ev   TYPE string OPTIONAL
                iv_refresh_text TYPE string DEFAULT `Refresh`
      CHANGING  cv_html         TYPE string.

    "! The same two buttons as inline links, for pages that build their own
    "! button row (object view, class view). The review calls the reload
    "! "Recalc" — there it recomputes the diff, it does not redraw a page.
    CLASS-METHODS buttons_html
      IMPORTING iv_objtype      TYPE versobjtyp
                iv_objname      TYPE versobjnam
                iv_refresh_ev   TYPE string OPTIONAL
                iv_refresh_text TYPE string DEFAULT `Refresh`
                iv_css_class    TYPE string DEFAULT `filter-btn`
      RETURNING VALUE(result)   TYPE string.

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

    "! Line of a method / class section inside the one class source ADT opens.
    "! IV_ANCHOR is the statement the part starts with (`METHOD GET_FILES`,
    "! `PUBLIC SECTION`); the line is shifted by the distance between that
    "! statement in the class source and in the part's own source. For a method
    "! the two are the same, because a method include holds nothing but the
    "! method — a section include is prefixed with a generated `*"*` header, so
    "! its own source is read (IV_PART_INCLUDE) instead of assuming line 1.
    "! 0 when the class source cannot be read or the anchor is not in it; the
    "! caller then jumps to the object, which beats jumping to a wrong line.
    CLASS-METHODS class_source_line
      IMPORTING iv_class        TYPE string
                iv_anchor       TYPE string
                iv_line         TYPE i
                iv_part_include TYPE progname OPTIONAL
      RETURNING VALUE(result)   TYPE i.

    "! The statement a class part starts with, for CLASS_SOURCE_LINE.
    CLASS-METHODS anchor_of
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
      RETURNING VALUE(result) TYPE string.

    "! Generated include of a class section, whose own line numbering AVE shows.
    CLASS-METHODS section_include_of
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_class      TYPE string
      RETURNING VALUE(result) TYPE progname.

    "! Generated include behind any class part — the section, the method, or the
    "! local include the part is already named after. Empty for the class itself.
    CLASS-METHODS class_part_include
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_class      TYPE string
      RETURNING VALUE(result) TYPE progname.

    "! 1-based line of the first statement matching IV_ANCHOR; 0 when absent.
    CLASS-METHODS anchor_line_in
      IMPORTING it_source     TYPE string_table
                iv_anchor     TYPE string
      RETURNING VALUE(result) TYPE i.

    "! The single class source ADT opens, empty when it cannot be read.
    CLASS-METHODS read_clif_source
      IMPORTING iv_class      TYPE string
      RETURNING VALUE(result) TYPE string_table.

    "! `/sap/bc/adt/…` of a DDIC object, asked from the system's own ADT URI
    "! mapper. Empty for a non-DDIC type or when the mapper is not available.
    CLASS-METHODS ddic_uri
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
      RETURNING VALUE(result) TYPE string.

    "! SAP GUI workbench navigation, in this window, so control comes back.
    CLASS-METHODS open_in_gui
      IMPORTING iv_objtype    TYPE versobjtyp
                iv_objname    TYPE versobjnam
                iv_class      TYPE string OPTIONAL
                iv_line       TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE abap_bool.

    "! Workbench object type and the include the editor should land in. The
    "! include is the one AVE numbered its lines from, so IV_LINE needs no
    "! translation here — unlike the ADT jump, which opens the class source.
    CLASS-METHODS wb_target_of
      IMPORTING iv_objtype  TYPE versobjtyp
                iv_objname  TYPE versobjnam
                iv_class    TYPE string OPTIONAL
      EXPORTING ev_type     TYPE trobjtype
                ev_name     TYPE trobj_name
                ev_include  TYPE progname
                "! Sub-object under EV_NAME, when the type has one (a method).
                ev_sub_type TYPE trobjtype
                ev_sub_name TYPE trobj_name.

    "! One RS_TOOL_ACCESS attempt. False when the workbench refused the type or
    "! could not execute it, which is what the cascade in OPEN_IN_GUI walks on.
    CLASS-METHODS call_workbench
      IMPORTING iv_type       TYPE trobjtype
                iv_name       TYPE trobj_name
                iv_include    TYPE progname OPTIONAL
                iv_line       TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE abap_bool.

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

    " DDIC objects do not go through the path table below — ADT does not name
    " their resources alike and the system knows the URI, see DDIC_URI. Kept
    " ahead of everything else so a table or a domain never falls back to a
    " guessed path while the mapper is available.
    DATA(lv_ddic_uri) = ddic_uri( iv_objtype = iv_objtype iv_objname = iv_objname ).
    IF lv_ddic_uri IS NOT INITIAL.
      " Not lowercased: this URI is what ADT itself produced.
      result = |adt://{ sy-sysid }{ lv_ddic_uri }|.
      RETURN.
    ENDIF.

    path_of(
      EXPORTING
        iv_objtype  = iv_objtype
        iv_objname  = iv_objname
        iv_class    = iv_class
      IMPORTING
        ev_path     = lv_path
        ev_fragment = lv_fragment ).

    CHECK lv_path IS NOT INITIAL.

    IF iv_line > 0.
      DATA(lv_line) = iv_line.
      " A method or a class section is not a source of its own in ADT — it is
      " part of the class source, so the line has to be translated into that one.
      DATA(lv_anchor) = anchor_of( iv_objtype = iv_objtype iv_objname = iv_objname ).
      IF lv_anchor IS NOT INITIAL.
        DATA(lv_anchor_class) = class_of( iv_objtype = iv_objtype
                                          iv_objname = iv_objname
                                          iv_class   = iv_class ).
        lv_line = class_source_line(
          iv_class        = lv_anchor_class
          iv_anchor       = lv_anchor
          iv_line         = iv_line
          iv_part_include = section_include_of( iv_objtype = iv_objtype
                                                iv_class   = lv_anchor_class ) ).
      ENDIF.
      IF lv_line > 0.
        " Wins over the sub-object fragment: a line is the more precise of the two.
        lv_fragment = |#start={ lv_line },1|.
      ENDIF.
    ENDIF.

    " The fragment keeps its case: it carries an ADT type key (CLAS/OM) that is
    " matched case-sensitively, while the path itself is not.
    result = to_lower( |adt://{ sy-sysid }/sap/bc/adt/{ lv_path }| ) && lv_fragment.
  ENDMETHOD.


  METHOD anchor_of.
    " Only the parts ADT shows inside the class source need a translation. The
    " local includes (CCDEF/CCIMP/CCMAC/CCAU) are sources of their own there, so
    " their line numbers already match.
    CASE iv_objtype.
      WHEN 'METH'.
        DATA(lv_method) = method_of( iv_objname ).
        CHECK lv_method IS NOT INITIAL.
        result = |METHOD { lv_method }|.
      WHEN 'CPUB'.
        result = `PUBLIC SECTION`.
      WHEN 'CPRO'.
        result = `PROTECTED SECTION`.
      WHEN 'CPRI'.
        result = `PRIVATE SECTION`.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
  ENDMETHOD.


  METHOD class_source_line.
    CHECK iv_class IS NOT INITIAL.
    CHECK iv_line > 0.

    DATA(lt_source) = read_clif_source( iv_class ).

    DATA(lv_class_anchor) = anchor_line_in( it_source = lt_source iv_anchor = iv_anchor ).
    CHECK lv_class_anchor > 0.

    " Where the same statement sits in the source AVE numbered its lines from.
    DATA(lv_part_anchor) = 1.
    IF iv_part_include IS NOT INITIAL.
      TRY.
          DATA lt_part TYPE string_table.
          READ REPORT iv_part_include INTO lt_part.
          IF sy-subrc = 0.
            DATA(lv_found) = anchor_line_in( it_source = lt_part iv_anchor = iv_anchor ).
            IF lv_found > 0.
              lv_part_anchor = lv_found.
            ENDIF.
          ENDIF.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    result = lv_class_anchor + iv_line - lv_part_anchor.
    IF result < 1.
      CLEAR result.
    ENDIF.
  ENDMETHOD.


  METHOD ddic_uri.
    " ADT does not name its DDIC resources alike — `/ddic/dataelements/X` opens
    " a data element while `/ddic/domains/X` is answered with "could not be
    " found" — and the naming differs per release, so guessing it is what broke
    " the domain and table jumps. The system's own ADT URI mapper answers for
    " the release it runs on; abapGit builds its ADT links the same way.
    "
    " Called dynamically: on a release without CL_ADT_TOOLS_CORE_FACTORY the
    " failure is a CX_ROOT, and BUILD_URL falls back to the built-in path.
    DATA lv_object   TYPE trobjtype.
    DATA lv_obj_name TYPE trobj_name.

    CASE iv_objtype.
      WHEN 'TABD' OR 'TABL' OR 'STRU'. lv_object = 'TABL'.
      WHEN 'DOMD' OR 'DOMA'.           lv_object = 'DOMA'.
      WHEN 'DTED' OR 'DTEL'.           lv_object = 'DTEL'.
      WHEN 'VIED' OR 'VIEW'.           lv_object = 'VIEW'.
      WHEN 'TTYD' OR 'TTYP'.           lv_object = 'TTYP'.
      WHEN 'DEVC'.                     lv_object = 'DEVC'.
      WHEN OTHERS.                     RETURN.
    ENDCASE.

    lv_obj_name = to_upper( condense( CONV string( iv_objname ) ) ).
    CHECK lv_obj_name IS NOT INITIAL.

    DATA lo_wb_object  TYPE REF TO cl_wb_object.
    DATA lo_adt        TYPE REF TO object.
    DATA lo_mapper     TYPE REF TO object.
    DATA lo_adt_objref TYPE REF TO object.
    FIELD-SYMBOLS <lv_uri> TYPE string.

    TRY.
        cl_wb_object=>create_from_transport_key(
          EXPORTING
            p_object    = lv_object
            p_obj_name  = lv_obj_name
          RECEIVING
            p_wb_object = lo_wb_object
          EXCEPTIONS
            OTHERS      = 1 ).
        IF sy-subrc <> 0 OR lo_wb_object IS NOT BOUND.
          RETURN.
        ENDIF.

        CALL METHOD ('CL_ADT_TOOLS_CORE_FACTORY')=>('GET_INSTANCE')
          RECEIVING
            result = lo_adt.
        CALL METHOD lo_adt->('IF_ADT_TOOLS_CORE_FACTORY~GET_URI_MAPPER')
          RECEIVING
            result = lo_mapper.
        CALL METHOD lo_mapper->('IF_ADT_URI_MAPPER~MAP_WB_OBJECT_TO_OBJREF')
          EXPORTING
            wb_object = lo_wb_object
          RECEIVING
            result    = lo_adt_objref.

        " The attribute is reached by name because the reference is untyped.
        ASSIGN ('LO_ADT_OBJREF->REF_DATA-URI') TO <lv_uri>.
        IF sy-subrc = 0.
          result = <lv_uri>.
        ENDIF.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.


  METHOD read_clif_source.
    " The one source ADT shows for a class, read through CL_OO_FACTORY.
    "
    " KEEP (replaced): this used to be CL_OO_SOURCE —
    "   CREATE OBJECT lo_source EXPORTING clskey = ls_clskey.
    "   lo_source->read( 'A' ). lt_source = lo_source->get_old_source( ).
    " That class is deprecated and its constructor now opens with ASSERT 1 = 0
    " ("use cl_oo_factory=>create_instance( )->create_clif_source( )"). An
    " assertion is a short dump, not an exception, so the TRY around it caught
    " nothing — clicking the ADT badge of a method dumped.
    "
    " Called dynamically on purpose: a release without CL_OO_FACTORY, or a
    " renamed parameter, then costs the line jump and nothing else — every
    " dynamic-call failure is a CX_ROOT and the caller simply gets no line.
    DATA lo_factory TYPE REF TO object.
    DATA lo_clif    TYPE REF TO object.
    DATA lv_clif    TYPE seoclsname.
    lv_clif = iv_class.
    TRY.
        CALL METHOD ('CL_OO_FACTORY')=>('CREATE_INSTANCE')
          RECEIVING
            result = lo_factory.
        CALL METHOD lo_factory->('CREATE_CLIF_SOURCE')
          EXPORTING
            clif_name = lv_clif
          RECEIVING
            result    = lo_clif.
        CALL METHOD lo_clif->('GET_SOURCE')
          IMPORTING
            source = result.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.


  METHOD anchor_line_in.
    " `METHOD get_files.` and `METHOD get_files .` both start the method; the
    " trailing `*` covers a comment written behind the statement.
    DATA(lv_pat1) = |{ iv_anchor }.*|.
    DATA(lv_pat2) = |{ iv_anchor } .*|.
    LOOP AT it_source INTO DATA(lv_src_line).
      DATA(lv_norm) = to_upper( condense( lv_src_line ) ).
      IF lv_norm CP lv_pat1 OR lv_norm CP lv_pat2.
        result = sy-tabix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD section_include_of.
    CHECK iv_class IS NOT INITIAL.
    DATA lv_class TYPE seoclsname.
    lv_class = iv_class.
    TRY.
        CASE iv_objtype.
          WHEN 'CPUB'.
            result = cl_oo_classname_service=>get_pubsec_name( lv_class ).
          WHEN 'CPRO'.
            result = cl_oo_classname_service=>get_prosec_name( lv_class ).
          WHEN 'CPRI'.
            result = cl_oo_classname_service=>get_prisec_name( lv_class ).
          WHEN OTHERS.
            " A method include holds nothing but the method, so its own line 1
            " is the METHOD statement — nothing to read.
            RETURN.
        ENDCASE.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.


  METHOD open.
    IF gv_gui_nav = abap_true.
      result = open_in_gui(
        iv_objtype = iv_objtype
        iv_objname = iv_objname
        iv_class   = iv_class
        iv_line    = iv_line ).
      RETURN.
    ENDIF.

    DATA(lv_url) = build_url(
      iv_objtype = iv_objtype
      iv_objname = iv_objname
      iv_class   = iv_class
      iv_line    = iv_line ).

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


  METHOD open_in_gui.
    DATA lv_type     TYPE trobjtype.
    DATA lv_name     TYPE trobj_name.
    DATA lv_include  TYPE progname.
    DATA lv_sub_type TYPE trobjtype.
    DATA lv_sub_name TYPE trobj_name.

    wb_target_of(
      EXPORTING
        iv_objtype  = iv_objtype
        iv_objname  = iv_objname
        iv_class    = iv_class
      IMPORTING
        ev_type     = lv_type
        ev_name     = lv_name
        ev_include  = lv_include
        ev_sub_type = lv_sub_type
        ev_sub_name = lv_sub_name ).
    IF lv_type IS INITIAL OR lv_name IS INITIAL.
      MESSAGE |Cannot open { iv_objtype } { iv_objname } in the workbench| TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " Navigating with the R3TR type alone lands on the object, not on the line —
    " a method then opens the method LIST of its class. The sub-object type is
    " tried first for that reason, the include as a program second (the plain
    " "jump to a line" every syntax-error navigation uses), and the object
    " itself only as the last resort. Each step is skipped when the workbench
    " answers INVALID_OBJECT_TYPE / NOT_EXECUTED, so an unsupported type on this
    " release simply falls through instead of dumping.
    DATA(lv_done) = abap_false.
    IF lv_sub_type IS NOT INITIAL AND lv_sub_name IS NOT INITIAL.
      lv_done = call_workbench( iv_type    = lv_sub_type
                                iv_name    = lv_sub_name
                                iv_include = lv_include
                                iv_line    = iv_line ).
    ENDIF.
    IF lv_done = abap_false AND lv_include IS NOT INITIAL AND iv_line > 0.
      lv_done = call_workbench( iv_type    = 'PROG'
                                iv_name    = CONV #( lv_include )
                                iv_include = lv_include
                                iv_line    = iv_line ).
    ENDIF.
    IF lv_done = abap_false.
      lv_done = call_workbench( iv_type    = lv_type
                                iv_name    = lv_name
                                iv_include = lv_include
                                iv_line    = iv_line ).
    ENDIF.
    IF lv_done = abap_false.
      MESSAGE |Workbench cannot open { lv_type } { lv_name }| TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " Back from the editor: RS_TOOL_ACCESS is a drill-in, so this line runs the
    " moment the workbench is left. That alone is the trigger — the object is
    " re-read, full stop.
    "
    " KEEP (replaced): the part's source used to be read before and after the
    " jump and re-read only on a difference. It saved a recompute after a
    " look-and-leave and cost far more than it saved: it only worked where an
    " include could be read (never for a DDIC object or a whole-class row), and
    " its "nothing to do" branch was silent — a MESSAGE cannot report it,
    " because these handlers are system events, so a jump that did nothing
    " looked exactly like a jump that never returned.
    result = abap_true.
  ENDMETHOD.


  METHOD call_workbench.
    " IN_NEW_WINDOW is deliberately not set: a new session would return control
    " immediately and there would be no "back from the editor" moment to react to.
    CALL FUNCTION 'RS_TOOL_ACCESS'
      EXPORTING
        operation           = 'SHOW'
        object_name         = iv_name
        object_type         = iv_type
        include             = iv_include
        position            = iv_line
      EXCEPTIONS
        not_executed        = 1
        invalid_object_type = 2
        OTHERS              = 3.
    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD wb_target_of.
    CLEAR: ev_type, ev_name, ev_include, ev_sub_type, ev_sub_name.

    DATA(lv_name) = to_upper( condense( CONV string( iv_objname ) ) ).
    CHECK lv_name IS NOT INITIAL.

    CASE iv_objtype.
      WHEN 'METH' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'CLSD' OR 'CLAS'
        OR 'CINC' OR 'CDEF' OR 'CMAC'.
        DATA(lv_class) = class_of( iv_objtype = iv_objtype
                                   iv_objname = iv_objname
                                   iv_class   = iv_class ).
        CHECK lv_class IS NOT INITIAL.
        ev_type = 'CLAS'.
        ev_name = lv_class.
        ev_include = class_part_include(
          iv_objtype = iv_objtype
          iv_objname = iv_objname
          iv_class   = lv_class ).
        IF iv_objtype = 'METH'.
          " LIMU METH is a workbench type of its own, and its key is the one
          " VRSD already uses: the class padded to 30 characters in front of the
          " method. Passed unchanged for that reason — not as a bare method name.
          ev_sub_type = 'METH'.
          ev_sub_name = iv_objname.
        ENDIF.

      WHEN 'INTF'.
        ev_type = 'INTF'.
        ev_name = lv_name.

      WHEN 'REPS' OR 'REPT' OR 'PROG'.
        " A class-pool include is reached through its class, not as a program.
        IF lv_name CS '='.
          ev_type = 'CLAS'.
          ev_name = class_of( iv_objtype = 'CINC' iv_objname = CONV #( lv_name ) ).
          ev_include = lv_name.
          RETURN.
        ENDIF.
        ev_type = 'PROG'.
        ev_name = lv_name.
        ev_include = lv_name.

      WHEN 'FUNC'.
        ev_type = 'FUNC'.
        ev_name = lv_name.
        " The include the module lives in, so the before/after comparison has
        " something to read — TFDIR names the group program and the suffix.
        SELECT SINGLE pname, include FROM tfdir
          WHERE funcname = @lv_name
          INTO @DATA(ls_tfdir).
        IF sy-subrc = 0 AND ls_tfdir-pname IS NOT INITIAL.
          ev_include = replace( val  = to_upper( condense( CONV string( ls_tfdir-pname ) ) )
                                sub  = 'SAPL'
                                with = 'L' ) && |U{ ls_tfdir-include }|.
        ENDIF.

      WHEN 'FUGR'.
        ev_type = 'FUGR'.
        ev_name = lv_name.

      WHEN 'DDLS'.
        ev_type = 'DDLS'.
        ev_name = lv_name.

      WHEN 'TABD' OR 'TABL' OR 'STRU'. ev_type = 'TABL'. ev_name = lv_name.
      WHEN 'DOMD' OR 'DOMA'.           ev_type = 'DOMA'. ev_name = lv_name.
      WHEN 'DTED' OR 'DTEL'.           ev_type = 'DTEL'. ev_name = lv_name.
      WHEN 'VIED' OR 'VIEW'.           ev_type = 'VIEW'. ev_name = lv_name.
      WHEN 'TTYD' OR 'TTYP'.           ev_type = 'TTYP'. ev_name = lv_name.
      WHEN 'DEVC'.                     ev_type = 'DEVC'. ev_name = lv_name.

      WHEN OTHERS.
        RETURN.
    ENDCASE.
  ENDMETHOD.


  METHOD class_part_include.
    CASE iv_objtype.
      WHEN 'CPUB' OR 'CPRO' OR 'CPRI'.
        result = section_include_of( iv_objtype = iv_objtype iv_class = iv_class ).

      WHEN 'CINC' OR 'CDEF' OR 'CMAC'.
        " Those parts are already named after their generated include.
        result = to_upper( condense( CONV string( iv_objname ) ) ).

      WHEN 'METH'.
        DATA(lv_method) = method_of( iv_objname ).
        CHECK lv_method IS NOT INITIAL.
        DATA ls_mtdkey TYPE seocpdkey.
        ls_mtdkey-clsname = iv_class.
        ls_mtdkey-cpdname = lv_method.
        cl_oo_classname_service=>get_method_include(
          EXPORTING
            mtdkey              = ls_mtdkey
          RECEIVING
            result              = result
          EXCEPTIONS
            method_not_existing = 1
            OTHERS              = 2 ).
        IF sy-subrc <> 0.
          CLEAR result.
        ENDIF.

      WHEN OTHERS.
        RETURN.
    ENDCASE.
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
    " The answer of OPEN is the whole point of this method - discarding it left
    " every sapevent jump reporting "nothing to re-read", so the recompute after
    " a workbench drill-in never ran.
    result = open( iv_objtype = lv_type iv_objname = lv_name iv_line = iv_line ).
  ENDMETHOD.


  METHOD link_html.
    CHECK is_openable( iv_objtype ) = abap_true.
    DATA(lv_onclick) = COND string(
      WHEN iv_onclick IS NOT INITIAL THEN | onclick="{ iv_onclick }"|
      ELSE `` ).
    " The line goes in front of the object key, so the key keeps the one shape
    " every other action parses: everything behind the first '~' is the name.
    DATA(lv_href) = COND string(
      WHEN iv_line > 0 THEN |sapevent:adtl~{ iv_line }~{ iv_objtype }~{ iv_objname }|
      ELSE                  |sapevent:adt~{ iv_objtype }~{ iv_objname }| ).
    DATA(lv_text) = COND string(
      WHEN iv_text IS NOT INITIAL THEN iv_text
      ELSE badge_text( ) ).
    result =
      |<a class="adt" href="{ lv_href }"{ lv_onclick }| &&
      | title="{ jump_title( iv_line ) }">{ lv_text }</a>|.
  ENDMETHOD.


  METHOD badge_text.
    result = COND string( WHEN gv_gui_nav = abap_true THEN `WB` ELSE `ADT` ).
  ENDMETHOD.


  METHOD button_text.
    result = COND string( WHEN gv_gui_nav = abap_true THEN `Workbench` ELSE `Eclipse` ).
  ENDMETHOD.


  METHOD jump_title.
    DATA(lv_where) = COND string(
      WHEN gv_gui_nav = abap_true THEN `the SAP GUI workbench`
      ELSE                             `Eclipse (ADT)` ).
    result = COND string(
      WHEN iv_line > 0 THEN |Open line { iv_line } in { lv_where }|
      ELSE                  |Open in { lv_where }| ).
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
        | title="{ jump_title( ) }">&#9998; { button_text( ) }</a>|.
    ENDIF.
    CHECK iv_refresh_ev IS NOT INITIAL.
    result = result &&
      |<a class="{ iv_css_class }" href="sapevent:{ iv_refresh_ev }"| &&
      | title="Re-read the object and recompute its diff">&#8635; { iv_refresh_text }</a>|.
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
        | style="background:#8e44ad;{ lv_btn }" title="{ jump_title( ) }">&#9998; { button_text( ) }</a>|.
    ENDIF.
    IF iv_refresh_ev IS NOT INITIAL.
      lv_bar = lv_bar &&
        |<a href="sapevent:{ iv_refresh_ev }"| &&
        | style="background:#16a085;{ lv_btn }" title="Re-read the object">&#8635; { iv_refresh_text }</a>|.
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
