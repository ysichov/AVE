CLASS zcl_ave_acr_part_view DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES ty_t_hunk_view TYPE STANDARD TABLE OF zif_ave_acr_types=>ty_hunk_info WITH DEFAULT KEY.

    CLASS-METHODS build_html
      IMPORTING
        iv_objtype      TYPE versobjtyp
        iv_objname      TYPE versobjnam
        it_parts        TYPE zif_ave_popup_types=>ty_t_part_row
        it_hunk_info    TYPE zif_ave_acr_types=>ty_t_hunk_info
        it_obj_stats    TYPE zif_ave_acr_types=>ty_t_obj_stats
        it_approved     TYPE zif_ave_acr_types=>ty_approved
        it_declined     TYPE zif_ave_acr_types=>ty_approved
        it_hunk_actions TYPE zif_ave_acr_types=>ty_t_hunk_actions
        it_hunk_threads TYPE zif_ave_acr_types=>ty_t_hunk_threads
        iv_two_pane     TYPE abap_bool
        iv_ai_enabled   TYPE abap_bool
        iv_ai_label     TYPE string
      RETURNING
        VALUE(result)   TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS build_css
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS get_page_title
      IMPORTING
        iv_objtype    TYPE versobjtyp
        iv_objname    TYPE versobjnam
        it_parts      TYPE zif_ave_popup_types=>ty_t_part_row
        it_hunks      TYPE ty_t_hunk_view
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS format_version_text
      IMPORTING
        iv_text       TYPE string
        iv_versno     TYPE versno
        iv_new_side   TYPE abap_bool
      RETURNING
        VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_ave_acr_part_view IMPLEMENTATION.

  METHOD build_html.
    DATA lt_hunks TYPE STANDARD TABLE OF zif_ave_acr_types=>ty_hunk_info WITH DEFAULT KEY.
    LOOP AT it_hunk_info INTO DATA(ls_hi)
      WHERE objtype = iv_objtype AND obj_name = iv_objname.
      APPEND ls_hi TO lt_hunks.
    ENDLOOP.
    SORT lt_hunks BY hunk_no.

    DATA(lv_page_title) = get_page_title(
      iv_objtype = iv_objtype
      iv_objname = iv_objname
      it_parts   = it_parts
      it_hunks   = lt_hunks ).

    result =
      |<!DOCTYPE html><html><head><meta charset="utf-8"><style>{ build_css( ) }</style>| &&
      `<script>` &&
      `(function(){` &&
        `var k='ave_scroll_crpart';` &&
        `var pos=sessionStorage.getItem(k);` &&
        `if(pos){` &&
          `window.addEventListener('load',function(){window.scrollTo(0,parseInt(pos,10));sessionStorage.removeItem(k);});` &&
        `}` &&
        `window._saveScroll=function(){sessionStorage.setItem(k,window.scrollY||document.documentElement.scrollTop||0);};` &&
      `})();` &&
      `function filterBlocks(mode){` &&
        `var btns=document.querySelectorAll('.filter-btn');` &&
        `btns.forEach(function(b){b.classList.remove('active');});` &&
        `var blocks=document.querySelectorAll('.block');` &&
        `blocks.forEach(function(b){b.style.display='';});` &&
        `if(!mode){return;}` &&
        `var btn=document.getElementById('btn_'+mode);` &&
        `if(btn){btn.classList.add('active');if(mode==='comments')btn.classList.add('comments');}` &&
        `blocks.forEach(function(b){` &&
          `var show=false;` &&
          `if(mode==='declined'){` &&
            `var notes=b.querySelectorAll('.note');` &&
            `for(var i=0;i<notes.length;i++){if(notes[i].getAttribute('style')){show=true;break;}}` &&
          `}else if(mode==='comments'){` &&
            `show=b.querySelector('.comments')!==null;` &&
          `}` &&
          `b.style.display=show?'':'none';` &&
        `});` &&
      `}` &&
      `document.addEventListener('click',function(e){` &&
        `var a=e.target.closest('a[href^="sapevent:addcomment"],a[href^="sapevent:editreview"]');` &&
        `if(a&&window._saveScroll){window._saveScroll();}` &&
      `});` &&
      `</script>` &&
      `</head><body>` &&
      |<a class="back" href="sapevent:back~0">&#8592; Back</a>| &&
      `<p style="margin:0 0 14px 0">` &&
      `<a id="btn_declined" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'declined');return false">Declined only</a>` &&
      `<a id="btn_comments" class="filter-btn" href="#" onclick="filterBlocks(this.classList.contains('active')?null:'comments');return false">Comments only</a>` &&
      |<a class="filter-btn" href="sapevent:aiprompt~0">{ iv_ai_label }</a>| &&
      `</p>` &&
      |<h2>{ escape( val = CONV string( iv_objtype ) format = cl_abap_format=>e_html_text ) }: | &&
      |{ escape( val = lv_page_title format = cl_abap_format=>e_html_text ) }</h2>|.

    IF lt_hunks IS INITIAL.
      result = result &&
        |<p style="color:#888">No changed blocks found for this object.</p>| &&
        |</body></html>|.
      RETURN.
    ENDIF.

    LOOP AT lt_hunks INTO DATA(ls_hunk).
      DATA(lv_clean_html) = zcl_ave_acr_renderer=>normalize_diff_html(
        iv_html     = ls_hunk-html
        iv_two_pane = iv_two_pane ).
      DATA(lv_code_html) = COND string(
        WHEN lv_clean_html IS NOT INITIAL
        THEN |<table class="diff"><tbody>{ lv_clean_html }</tbody></table>|
        ELSE `<div style="color:#888;margin:4px 0 10px">Diff not available.</div>` ).

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
      lv_hunk_new_text = format_version_text(
        iv_text     = lv_hunk_new_text
        iv_versno   = lv_hunk_new_versno
        iv_new_side = abap_true ).
      lv_hunk_old_text = format_version_text(
        iv_text     = lv_hunk_old_text
        iv_versno   = lv_hunk_old_versno
        iv_new_side = abap_false ).
      DATA(lv_versions_html) = COND string(
        WHEN lv_hunk_new_text IS NOT INITIAL
        THEN | <span class="muted">versions</span> { escape( val = lv_hunk_new_text format = cl_abap_format=>e_html_text ) } -&gt; { escape( val = lv_hunk_old_text format = cl_abap_format=>e_html_text ) }|
        ELSE `` ).

      DATA(lv_actions_html) = zcl_ave_acr_renderer=>render_hunk_actions_html(
        iv_hunk_key     = ls_hunk-hunk_key
        it_approved     = it_approved
        it_declined     = it_declined
        it_hunk_actions = it_hunk_actions
        it_hunk_info    = it_hunk_info
        it_hunk_threads = it_hunk_threads
        iv_ai_enabled   = iv_ai_enabled ).

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
        `<div class="codewrap">` &&
        lv_code_html &&
        `</div></div>`.
    ENDLOOP.

    result = result && zcl_ave_acr_ai=>render_summary_html(
      iv_objtype      = iv_objtype
      iv_objname      = iv_objname
      it_hunk_threads = it_hunk_threads ).

    result = result && zcl_ave_acr_hunk_renderer=>build_approveall_btn(
      iv_obj_key      = |{ iv_objtype }~{ iv_objname }|
      iv_total_hunks  = lines( lt_hunks )
      it_approved     = it_approved
      it_declined     = it_declined
      it_hunk_actions = it_hunk_actions ) &&
      `</body></html>`.
  ENDMETHOD.


  METHOD build_css.
    result =
      `body{font:13px/1.6 Consolas,monospace;padding:20px 28px 20px 28px;background:#fff;color:#333}` &&
      `h2{color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:6px;margin-bottom:16px}` &&
      `.toolbar{display:block;white-space:nowrap;margin-bottom:14px}` &&
      `.objhdr{margin:18px 0 8px 0;background:#dbe9ff;color:#2c3e50;padding:5px 10px;` &&
      `font-weight:bold;white-space:nowrap}` &&
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


  METHOD get_page_title.
    LOOP AT it_parts ASSIGNING FIELD-SYMBOL(<ls_part>)
      WHERE type = iv_objtype AND object_name = iv_objname.
      result = COND string(
        WHEN <ls_part>-class IS NOT INITIAL THEN |{ <ls_part>-class } => { <ls_part>-name }|
        ELSE <ls_part>-name ).
      RETURN.
    ENDLOOP.

    READ TABLE it_hunks INTO DATA(ls_title_hunk) INDEX 1.
    IF sy-subrc = 0.
      IF ls_title_hunk-class_name IS NOT INITIAL AND ls_title_hunk-display_name IS NOT INITIAL.
        result = |{ ls_title_hunk-class_name } => { ls_title_hunk-display_name }|.
      ELSEIF ls_title_hunk-display_name IS NOT INITIAL.
        result = ls_title_hunk-display_name.
      ELSE.
        result = CONV string( iv_objname ).
      ENDIF.
    ELSE.
      result = CONV string( iv_objname ).
    ENDIF.
  ENDMETHOD.


  METHOD format_version_text.
    result = iv_text.
    IF result IS INITIAL.
      result = COND string(
        WHEN iv_new_side = abap_false AND iv_versno IS INITIAL          THEN `(new object)`
        WHEN iv_versno = zcl_ave_version=>c_version-active             THEN `Active`
        WHEN iv_versno = zcl_ave_version=>c_version-modified           THEN `Modified`
        WHEN iv_versno IS NOT INITIAL                                  THEN |v{ CONV string( iv_versno + 0 ) }|
        ELSE `` ).
    ELSEIF result CA '0123456789'
       AND result NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
      result = |v{ result }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
