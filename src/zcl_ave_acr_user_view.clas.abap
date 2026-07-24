CLASS zcl_ave_acr_user_view DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_summary_obj,
        objtype  TYPE versobjtyp,
        obj_name TYPE versobjnam,
      END OF ty_summary_obj.
    TYPES ty_t_summary_objs TYPE SORTED TABLE OF ty_summary_obj WITH UNIQUE KEY objtype obj_name.
    TYPES ty_t_hunk_view TYPE STANDARD TABLE OF zif_ave_acr_types=>ty_hunk_info WITH DEFAULT KEY.

    CLASS-METHODS build_html
      IMPORTING
        iv_user         TYPE versuser
        iv_user_name    TYPE ad_namtext
        iv_reviewer     TYPE abap_bool
        it_hunks        TYPE ty_t_hunk_view
        it_summary_objs TYPE ty_t_summary_objs
        it_hunk_info    TYPE zif_ave_acr_types=>ty_t_hunk_info
        it_obj_stats    TYPE zif_ave_acr_types=>ty_t_obj_stats
        it_approved     TYPE zif_ave_acr_types=>ty_approved
        it_declined     TYPE zif_ave_acr_types=>ty_approved
        it_hunk_actions TYPE zif_ave_acr_types=>ty_t_hunk_actions
        it_hunk_threads TYPE zif_ave_acr_types=>ty_t_hunk_threads
        iv_blame        TYPE abap_bool
        iv_two_pane     TYPE abap_bool
        iv_ai_enabled   TYPE abap_bool
        iv_ai_label     TYPE string
      RETURNING
        VALUE(result)   TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS build_css
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS format_version_text
      IMPORTING
        iv_text       TYPE string
        iv_versno     TYPE versno
        iv_new_side   TYPE abap_bool
      RETURNING
        VALUE(result) TYPE string.

    "! Resolve the class name a hunk belongs to (from class_name, or derived
    "! from the CxxX/METH object name), empty for non-class objects.
    CLASS-METHODS class_of
      IMPORTING is_hunk       TYPE zif_ave_acr_types=>ty_hunk_info
      RETURNING VALUE(result) TYPE seoclsname.

    "! Category sort key: class objects after non-class category sections.
    CLASS-METHODS grp_ord_of
      IMPORTING is_hunk       TYPE zif_ave_acr_types=>ty_hunk_info
      RETURNING VALUE(result) TYPE i.

    "! Category group key: 'C:<class>' for class objects, 'G:<label>' otherwise.
    CLASS-METHODS grp_key_of
      IMPORTING is_hunk       TYPE zif_ave_acr_types=>ty_hunk_info
      RETURNING VALUE(result) TYPE string.

    "! Ordering of class sections within a class (def/pub/pro/pri/…/methods).
    CLASS-METHODS type_ord_of
      IMPORTING iv_objtype    TYPE versobjtyp
      RETURNING VALUE(result) TYPE i.
ENDCLASS.


CLASS zcl_ave_acr_user_view IMPLEMENTATION.

  METHOD build_html.
    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ build_css( ) }</style>| &&
      `<script>` &&
      `(function(){` &&
        `var k='ave_scroll_declines';` &&
        `var pos=sessionStorage.getItem(k);` &&
        `if(pos){window.addEventListener('load',function(){window.scrollTo(0,parseInt(pos,10));sessionStorage.removeItem(k);});}` &&
        `window._saveScroll=function(){sessionStorage.setItem(k,window.scrollY||document.documentElement.scrollTop||0);};` &&
      `})();` &&
      `function filterBlocks(mode){` &&
        `var btns=document.querySelectorAll('.filter-btn');btns.forEach(function(b){b.classList.remove('active');});` &&
        `var grps=document.querySelectorAll('.objgrp');` &&
        `grps.forEach(function(g){g.style.display='';g.querySelectorAll('.block').forEach(function(b){b.style.display='';});});` &&
        `if(!mode){return;}` &&
        `var btn=document.getElementById('btn_'+mode);if(btn){btn.classList.add('active');if(mode==='comments')btn.classList.add('comments');}` &&
        `grps.forEach(function(g){var anyVisible=false;g.querySelectorAll('.block').forEach(function(b){` &&
          `var show=false;if(mode==='declined'){var notes=b.querySelectorAll('.note');` &&
          `for(var i=0;i<notes.length;i++){if(notes[i].getAttribute('style')){show=true;break;}}` &&
          `}else if(mode==='comments'){show=b.querySelector('.comments')!==null;}` &&
          `b.style.display=show?'':'none';if(show)anyVisible=true;});g.style.display=anyVisible?'':'none';});` &&
      `}` &&
      `document.addEventListener('click',function(e){` &&
        `var a=e.target.closest('a[href^="sapevent:addcomment"],a[href^="sapevent:editreview"]');` &&
        `if(a&&window._saveScroll){window._saveScroll();}` &&
      `});` &&
      `function tgu(h){var g=h.parentNode;var col=g.getAttribute('data-c')=='1';` &&
        `var cs=g.children;for(var i=1;i<cs.length;i++){cs[i].style.display=col?'':'none';}` &&
        `g.setAttribute('data-c',col?'0':'1');` &&
        `var c=h.querySelector('.caret');if(c)c.innerHTML=col?'&#9662;':'&#9656;';}` &&
      `function tguA(s){var gs=document.querySelectorAll('.objgrp');gs.forEach(function(g){` &&
        `var cs=g.children;for(var i=1;i<cs.length;i++){cs[i].style.display=s?'':'none';}` &&
        `g.setAttribute('data-c',s?'0':'1');` &&
        `var c=g.querySelector('.objhdr .caret');if(c)c.innerHTML=s?'&#9662;':'&#9656;';});}` &&
      `function tgc(h){var b=h.nextElementSibling;if(!b)return;var c=h.querySelector('.caret');` &&
        `if(b.style.display=='none'){b.style.display='';if(c)c.innerHTML='&#9662;';}` &&
        `else{b.style.display='none';if(c)c.innerHTML='&#9656;';}}` &&
      `window.addEventListener('load',function(){tguA(0);});` &&
      `</script></head><body>` &&
      |<a class="back" href="sapevent:back~0">&#8592; Back</a>| &&
      `<p style="margin:0 0 14px 0">` &&
      `<a id="btn_declined" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'declined');return false">Declined only</a>` &&
      `<a id="btn_comments" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'comments');return false">Comments only</a>` &&
      |<a class="filter-btn" href="sapevent:aiprompt~0">{ iv_ai_label }</a>| &&
      `<a class="filter-btn" href="#" onclick="tguA(1);return false">Expand all</a>` &&
      `<a class="filter-btn" href="#" onclick="tguA(0);return false">Collapse all</a>` &&
      `</p>` &&
      COND string(
        WHEN iv_user IS INITIAL AND iv_reviewer = abap_false
        THEN |<h2>Review: { escape( val = CONV string( iv_user_name ) format = cl_abap_format=>e_html_text ) }</h2>|
        ELSE |<h2>Review: { escape( val = CONV string( iv_user ) format = cl_abap_format=>e_html_text ) }| &&
             | / { escape( val = CONV string( iv_user_name ) format = cl_abap_format=>e_html_text ) }</h2>| ).

    IF it_hunks IS INITIAL AND it_summary_objs IS INITIAL.
      result = result &&
        COND string(
          WHEN iv_reviewer = abap_true
          THEN |<p style="color:#888">No reviewed or commented blocks found for this reviewer.</p>|
          WHEN iv_user IS INITIAL
          THEN |<p style="color:#888">No changed blocks found.</p>|
          ELSE |<p style="color:#888">No changed blocks found for this developer.</p>| ) &&
        |</body></html>|.
      RETURN.
    ENDIF.

    " ── Order hunks + AI-summary-only objects into category groups ──────────
    " Category = class name (class objects) or cat_label(objtype) (Programs /
    " Tables / Domains / CDS), matching the main report grouping. Inside a
    " category the objects are listed and collapsed to their header by default.
    TYPES: BEGIN OF ty_ord,
             grp_ord  TYPE i,
             grp_key  TYPE string,
             type_ord TYPE i,
             obj_name TYPE versobjnam,
             hunk_no  TYPE i,
             is_sum   TYPE abap_bool,
             hunk     TYPE zif_ave_acr_types=>ty_hunk_info,
           END OF ty_ord.
    DATA lt_ord TYPE STANDARD TABLE OF ty_ord WITH DEFAULT KEY.

    LOOP AT it_hunks INTO DATA(ls_h0).
      APPEND VALUE #(
        grp_ord  = grp_ord_of( ls_h0 )
        grp_key  = grp_key_of( ls_h0 )
        type_ord = type_ord_of( ls_h0-objtype )
        obj_name = ls_h0-obj_name
        hunk_no  = ls_h0-hunk_no
        hunk     = ls_h0 ) TO lt_ord.
    ENDLOOP.

    LOOP AT it_summary_objs INTO DATA(ls_so).
      READ TABLE it_hunks TRANSPORTING NO FIELDS
        WITH KEY objtype = ls_so-objtype obj_name = ls_so-obj_name.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
      DATA(ls_hinfo) = VALUE zif_ave_acr_types=>ty_hunk_info(
        objtype = ls_so-objtype obj_name = ls_so-obj_name ).
      READ TABLE it_hunk_info INTO DATA(ls_si)
        WITH KEY objtype = ls_so-objtype obj_name = ls_so-obj_name.
      IF sy-subrc = 0.
        ls_hinfo-class_name   = ls_si-class_name.
        ls_hinfo-display_name = ls_si-display_name.
      ENDIF.
      APPEND VALUE #(
        grp_ord  = grp_ord_of( ls_hinfo )
        grp_key  = grp_key_of( ls_hinfo )
        type_ord = type_ord_of( ls_hinfo-objtype )
        obj_name = ls_hinfo-obj_name
        hunk_no  = 0
        is_sum   = abap_true
        hunk     = ls_hinfo ) TO lt_ord.
    ENDLOOP.

    SORT lt_ord BY grp_ord grp_key type_ord obj_name hunk_no.

    " Distinct object count per category (for the "(n)" badge).
    TYPES: BEGIN OF ty_gc,
             key TYPE string,
             cnt TYPE i,
           END OF ty_gc.
    DATA lt_gc   TYPE HASHED TABLE OF ty_gc WITH UNIQUE KEY key.
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT lt_ord INTO DATA(ls_gc).
      DATA(lv_seen) = |{ ls_gc-grp_key }~{ ls_gc-hunk-objtype }~{ ls_gc-hunk-obj_name }|.
      READ TABLE lt_seen TRANSPORTING NO FIELDS WITH TABLE KEY table_line = lv_seen.
      IF sy-subrc <> 0.
        INSERT lv_seen INTO TABLE lt_seen.
        READ TABLE lt_gc ASSIGNING FIELD-SYMBOL(<gc>) WITH TABLE KEY key = ls_gc-grp_key.
        IF sy-subrc <> 0.
          INSERT VALUE #( key = ls_gc-grp_key cnt = 0 ) INTO TABLE lt_gc ASSIGNING <gc>.
        ENDIF.
        <gc>-cnt = <gc>-cnt + 1.
      ENDIF.
    ENDLOOP.

    DATA lv_cur_grp TYPE string VALUE `####`.
    DATA lv_cur_obj TYPE string VALUE `####`.
    LOOP AT lt_ord INTO DATA(ls_ord).
      DATA(ls_hunk) = ls_ord-hunk.
      DATA(lv_obj_key) = |{ ls_hunk-objtype }~{ ls_hunk-obj_name }|.

      " ── Category boundary ────────────────────────────────────────────────
      IF ls_ord-grp_key <> lv_cur_grp.
        IF lv_cur_obj <> `####`.
          result = result && zcl_ave_acr_ai=>render_summary_html(
            iv_objtype      = CONV #( lv_cur_obj(4) )
            iv_objname      = CONV #( lv_cur_obj+5 )
            it_hunk_threads = it_hunk_threads ) && `</div>`.
          lv_cur_obj = `####`.
        ENDIF.
        IF lv_cur_grp <> `####`.
          result = result && `</div></div>`.
        ENDIF.
        lv_cur_grp = ls_ord-grp_key.
        DATA lv_cat_cnt TYPE i.
        lv_cat_cnt = 0.
        READ TABLE lt_gc ASSIGNING FIELD-SYMBOL(<gc2>) WITH TABLE KEY key = ls_ord-grp_key.
        IF sy-subrc = 0. lv_cat_cnt = <gc2>-cnt. ENDIF.
        DATA(lv_cat_label) = ls_ord-grp_key+2.
        DATA(lv_cat_inner) = COND string(
          WHEN ls_ord-grp_key(2) = `C:`
          THEN |Class: <a href="sapevent:openclass~{ escape( val = lv_cat_label format = cl_abap_format=>e_html_attr ) }"| &&
               | onclick="event.stopPropagation()" style="color:inherit">| &&
               |{ escape( val = lv_cat_label format = cl_abap_format=>e_html_text ) }</a>|
          ELSE escape( val = lv_cat_label format = cl_abap_format=>e_html_text ) ).
        result = result &&
          `<div class="catgrp">` &&
          |<div class="cathdr" onclick="tgc(this)"><span class="caret">&#9662;</span> | &&
          |{ lv_cat_inner } <span class="grpcnt">({ lv_cat_cnt })</span></div>| &&
          `<div class="catbody">`.
      ENDIF.

      " ── Object boundary ──────────────────────────────────────────────────
      IF lv_obj_key <> lv_cur_obj.
        IF lv_cur_obj <> `####`.
          result = result && zcl_ave_acr_ai=>render_summary_html(
            iv_objtype      = CONV #( lv_cur_obj(4) )
            iv_objname      = CONV #( lv_cur_obj+5 )
            it_hunk_threads = it_hunk_threads ) && `</div>`.
        ENDIF.
        lv_cur_obj = lv_obj_key.
        DATA(lv_title) = COND string(
          WHEN ls_hunk-class_name IS NOT INITIAL AND ls_hunk-display_name IS NOT INITIAL
          THEN |{ ls_hunk-class_name }=>{ ls_hunk-display_name }|
          WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
          ELSE CONV string( ls_hunk-obj_name ) ).
        DATA(lv_obj_suffix) = COND string( WHEN ls_ord-is_sum = abap_true
          THEN | <span class="muted">AI summary</span>|
          ELSE `` ).
        IF ls_ord-is_sum = abap_false.
          DATA lv_obj_blocks  TYPE i.
          DATA lv_obj_changes TYPE i.
          CLEAR: lv_obj_blocks, lv_obj_changes.
          LOOP AT it_hunks INTO DATA(ls_s) WHERE objtype = ls_hunk-objtype AND obj_name = ls_hunk-obj_name.
            lv_obj_blocks = lv_obj_blocks + 1.
            lv_obj_changes = lv_obj_changes + ls_s-change_count.
          ENDLOOP.
          lv_obj_suffix =
            | <span class="muted">blocks</span> { lv_obj_blocks }| &&
            | <span class="muted">changes</span> { lv_obj_changes } lines|.
        ENDIF.
        result = result &&
          `<div class="objgrp">` &&
          |<div class="objhdr" onclick="tgu(this)">| &&
          |<span class="caret">&#9662;</span>| &&
          |<a href="sapevent:openobj~{ lv_obj_key }" style="color:inherit;text-decoration:none" onclick="event.stopPropagation()">| &&
          |{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
          |{ escape( val = lv_title format = cl_abap_format=>e_html_text ) }</a>| &&
          |{ lv_obj_suffix }</div>|.
      ENDIF.

      " AI-summary-only objects have no diff blocks; their summary is emitted
      " on object close, same as for hunk objects.
      CHECK ls_ord-is_sum = abap_false.

      DATA(lv_clean_html) = zcl_ave_acr_renderer=>normalize_diff_html(
        iv_html     = ls_hunk-html
        iv_two_pane = iv_two_pane ).
      DATA(lv_blame_fallback_html) = zcl_ave_acr_renderer=>render_blame_fallback(
        is_hunk     = ls_hunk
        iv_html     = lv_clean_html
        iv_blame    = iv_blame
        iv_two_pane = iv_two_pane ).
      DATA(lv_blame_header_html) = zcl_ave_acr_renderer=>extract_blame_rows(
        CHANGING cv_html = lv_clean_html ).
      lv_blame_header_html = lv_blame_header_html && lv_blame_fallback_html.
      DATA(lv_code_html) = COND string(
        WHEN lv_clean_html IS NOT INITIAL
        THEN |<table class="diff"><tbody>{ lv_clean_html }</tbody></table>|
        ELSE `<div style="color:#888;margin:4px 0 10px">Diff not available.</div>` ).
      DATA(lv_actions_html) = zcl_ave_acr_renderer=>render_hunk_actions_html(
        iv_hunk_key     = ls_hunk-hunk_key
        it_approved     = it_approved
        it_declined     = it_declined
        it_hunk_actions = it_hunk_actions
        it_hunk_info    = it_hunk_info
        it_hunk_threads = it_hunk_threads
        iv_ai_enabled   = iv_ai_enabled ).
      DATA(lv_block_title) = COND string(
        WHEN ls_hunk-display_name IS NOT INITIAL THEN ls_hunk-display_name
        ELSE CONV string( ls_hunk-obj_name ) ).
      DATA(lv_change_kind_html) = COND string(
        WHEN ls_hunk-change_kind IS NOT INITIAL
        THEN | <span class="muted">{ escape( val = ls_hunk-change_kind format = cl_abap_format=>e_html_text ) }</span>|
        ELSE `` ).
      DATA(lv_hunk_new_text) = ls_hunk-versno_new_text.
      DATA(lv_hunk_old_text) = ls_hunk-versno_old_text.
      DATA(lv_hunk_new_versno) = ls_hunk-versno_new.
      DATA(lv_hunk_old_versno) = ls_hunk-versno_old.
      IF lv_hunk_new_versno IS INITIAL.
        READ TABLE it_obj_stats INTO DATA(ls_hunk_stat)
          WITH KEY objtype = ls_hunk-objtype obj_name = ls_hunk-obj_name.
        IF sy-subrc = 0.
          lv_hunk_new_versno = ls_hunk_stat-versno_new.
          lv_hunk_old_versno = ls_hunk_stat-versno_old.
        ENDIF.
      ENDIF.
      lv_hunk_new_text = format_version_text( iv_text = lv_hunk_new_text iv_versno = lv_hunk_new_versno iv_new_side = abap_true ).
      lv_hunk_old_text = format_version_text( iv_text = lv_hunk_old_text iv_versno = lv_hunk_old_versno iv_new_side = abap_false ).
      DATA(lv_versions_html) = COND string(
        WHEN lv_hunk_new_text IS NOT INITIAL
        THEN | <span class="muted">versions</span> { escape( val = lv_hunk_new_text format = cl_abap_format=>e_html_text ) } -&gt; { escape( val = lv_hunk_old_text format = cl_abap_format=>e_html_text ) }|
        ELSE `` ).

      result = result &&
        `<div class="block">` &&
        |<div class="blkinfo">{ escape( val = CONV string( ls_hunk-objtype ) format = cl_abap_format=>e_html_text ) }: | &&
        |{ escape( val = lv_block_title format = cl_abap_format=>e_html_text ) } | &&
        |Block #{ ls_hunk-hunk_no }| &&
        lv_change_kind_html &&
        lv_versions_html &&
        | <span class="muted">line</span> { ls_hunk-start_line }| &&
        | <span class="muted">changes</span> { ls_hunk-change_count }</div>| &&
        lv_actions_html &&
        zcl_ave_acr_renderer=>render_hunk_comments_html(
          iv_hunk_key     = ls_hunk-hunk_key
          it_hunk_threads = it_hunk_threads ) &&
        COND string(
          WHEN lv_blame_header_html IS NOT INITIAL
          THEN |<table class="diff"><tbody>{ lv_blame_header_html }</tbody></table>|
          ELSE `` ) &&
        `<div class="codewrap">` &&
        lv_code_html &&
        `</div></div>`.
    ENDLOOP.

    " Close the last open object and category.
    IF lv_cur_obj <> `####`.
      result = result && zcl_ave_acr_ai=>render_summary_html(
        iv_objtype      = CONV #( lv_cur_obj(4) )
        iv_objname      = CONV #( lv_cur_obj+5 )
        it_hunk_threads = it_hunk_threads ) && `</div>`.
    ENDIF.
    IF lv_cur_grp <> `####`.
      result = result && `</div></div>`.
    ENDIF.

    result = result && `</body></html>`.
  ENDMETHOD.


  METHOD build_css.
    result =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `.toolbar{display:block;white-space:nowrap;margin-bottom:14px}` &&
      `.objhdr{margin:8px 0 8px 0;background:#dbe9ff;color:#2c3e50;padding:5px 10px;` &&
      `font-weight:bold;white-space:nowrap;cursor:pointer}` &&
      `.caret{display:inline-block;width:1.1em;color:#3498db}` &&
      `.catgrp{margin:16px 0}` &&
      `.cathdr{cursor:pointer;user-select:none;font-weight:bold;color:#2c3e50;font-size:15px;` &&
      `border-bottom:2px solid #3498db;padding:4px 2px;margin:16px 0 6px 0;white-space:nowrap}` &&
      `.catbody{margin-left:6px}` &&
      `.grpcnt{color:#95a5a6;font-weight:normal;font-size:.82em}` &&
      `.block{margin:0 0 14px 0}` &&
      `.comments{display:block;width:100%;margin:0 0 8px 0}` &&
      `.codewrap{display:block;clear:both;width:100%;margin:0;padding:0}` &&
      `.blame{margin:0 0 6px 0;color:#5e6a75;font-style:italic;white-space:nowrap}` &&
      `.blkinfo{margin:5px 0 2px 0;color:#2c3e50;font-weight:bold;white-space:nowrap}` &&
      `.muted{color:#777;font-weight:normal}` &&
      `.meta{display:block;margin:0 0 4px 0;color:#7f8c99;font-size:10px;font-weight:normal}` &&
      `.note{display:table;margin:6px 0 6px 0;padding:5px 9px;background:#f3f9ff;` &&
      `border:1px solid #a8cde8;color:#155f8f;font-style:italic;font-weight:bold;border-radius:6px}` &&
      `table.diff{border-collapse:collapse;width:100%;font-size:12px;margin:0 0 4px 0}` &&
      `.diff .ln{color:#aaa;text-align:right;padding:1px 10px 1px 5px;` &&
      `min-width:42px;border-right:1px solid #e0e0e0;white-space:nowrap;background:#fafafa}` &&
      `.diff .cd{padding:1px 8px;white-space:pre}` &&
      `.back{position:fixed;top:8px;left:8px;z-index:999;` &&
      `background:#3498db;color:#fff;padding:4px 10px;border-radius:4px;` &&
      `text-decoration:none;font:bold 12px Consolas,monospace;white-space:nowrap;` &&
      `box-shadow:0 1px 4px rgba(0,0,0,.25)}` &&
      `.filter-btn{display:inline-block;background:#eee;color:#333;padding:4px 10px;border-radius:4px;cursor:pointer;` &&
      `font:bold 12px Consolas,monospace;border:1px solid #bbb;text-decoration:none;` &&
      `white-space:nowrap;margin-right:4px}` &&
      `.filter-btn.active{background:#e74c3c;color:#fff;border-color:#c0392b}` &&
      `.filter-btn.active.comments{background:#27ae60;border-color:#1e8449}`.
  ENDMETHOD.


  METHOD class_of.
    result = is_hunk-class_name.
    IF result IS NOT INITIAL.
      RETURN.
    ENDIF.
    CASE is_hunk-objtype.
      WHEN 'CLSD' OR 'CPUB' OR 'CPRO' OR 'CPRI' OR 'CINC' OR 'CDEF' OR 'METH'.
        DATA(lv_on) = CONV string( is_hunk-obj_name ).
        FIND FIRST OCCURRENCE OF '=' IN lv_on MATCH OFFSET DATA(lv_eq).
        IF sy-subrc = 0 AND lv_eq > 0.
          result = CONV #( lv_on(lv_eq) ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD grp_ord_of.
    result = COND i(
      WHEN class_of( is_hunk ) IS NOT INITIAL THEN 100
      ELSE zcl_ave_acr_report=>cat_order( is_hunk-objtype ) ).
  ENDMETHOD.


  METHOD grp_key_of.
    DATA(lv_class) = class_of( is_hunk ).
    result = COND string(
      WHEN lv_class IS NOT INITIAL THEN |C:{ lv_class }|
      ELSE |G:{ zcl_ave_acr_report=>cat_label( is_hunk-objtype ) }| ).
  ENDMETHOD.


  METHOD type_ord_of.
    result = SWITCH i( iv_objtype
      WHEN 'CLSD' THEN 1 WHEN 'CPUB' THEN 2 WHEN 'CPRO' THEN 3
      WHEN 'CPRI' THEN 4 WHEN 'CINC' THEN 5 WHEN 'CDEF' THEN 6
      WHEN 'METH' THEN 7 ELSE 0 ).
  ENDMETHOD.


  METHOD format_version_text.
    result = iv_text.
    IF result IS INITIAL.
      result = COND string(
        WHEN iv_new_side = abap_false AND iv_versno IS INITIAL THEN `(new object)`
        WHEN iv_versno = zcl_ave_version=>c_version-active THEN `Active`
        WHEN iv_versno = zcl_ave_version=>c_version-modified THEN `Modified`
        WHEN iv_versno IS NOT INITIAL THEN |v{ CONV string( iv_versno + 0 ) }|
        ELSE `` ).
    ELSEIF result CA '0123456789' AND result NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
      result = |v{ result }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
