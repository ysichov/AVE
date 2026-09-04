*&---------------------------------------------------------------------*
*& Report Z_AVE_GOLDEN
*&---------------------------------------------------------------------*
*& Golden-master dump of one saved AVE code review.
*&
*& NOT a unit test. It asserts nothing about what is correct — it records
*& what the compute layer produces TODAY, so that after a refactoring the
*& same run can be compared byte for byte. An empty diff between the two
*& dumps is the whole assertion.
*&
*& Reads ZAVE_REVIEW through ZCL_AVE_ACR_REPOSITORY (the only class that
*& knows the table), drops everything that legitimately differs between
*& two runs of the same Prepare, and writes what is left as one canonical
*& line per record, sorted.
*&
*& Dropped as volatile: LAST_SAVED_AT, LAST_SAVED_BY, TIMINGS (measured
*& durations), HISTORY (save log). Their presence would make every diff
*& red and the net useless.
*&
*& Deliberately NOT covered: the rendered HTML. BUILD_SAVE_PAYLOAD clears
*& <saved_hunk>-HTML, so this dump protects the compute layer
*& (ZCL_AVE_ACR_PRECOMPUTE, ZCL_AVE_VERSION_LIST) and not the renderers.
*&
*& READ-ONLY. This report writes nothing but the frontend file.
*&
*& Usage:
*&   1. Prepare a pinned request in AVE with fixed settings.
*&   2. Run this with P_TAG = 'before'.
*&   3. Refactor.
*&   4. "Delete and recalc" in AVE, same settings.
*&   5. Run this with P_TAG = 'after'.
*&   6. Diff the two files.
*&---------------------------------------------------------------------*
REPORT z_ave_golden.

PARAMETERS p_trkorr TYPE trkorr OBLIGATORY.
PARAMETERS p_remote TYPE verssysnam.
PARAMETERS p_tag    TYPE c LENGTH 20 DEFAULT 'before'.
PARAMETERS p_dir    TYPE text255 DEFAULT 'C:\temp'.
PARAMETERS p_full   TYPE abap_bool AS CHECKBOX DEFAULT abap_false.

CLASS lcl_golden DEFINITION CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS run
      IMPORTING
        iv_trkorr TYPE trkorr
        iv_remote TYPE verssysnam
        iv_tag    TYPE clike
        iv_dir    TYPE clike
        iv_full   TYPE abap_bool.

  PRIVATE SECTION.
    "! One line per record; CR/LF folded away so a multi-line string can
    "! never split a record in two and shift every following diff line.
    CLASS-METHODS flat
      IMPORTING
        iv_text       TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! MD5 of a canonical rendering. Counts alone would not notice a pure
    "! reordering, which is exactly what a botched extraction produces.
    "! Fails loudly: no hash, no dump — a silently weakened net is worse
    "! than no net.
    CLASS-METHODS hash
      IMPORTING
        iv_text       TYPE string
      RETURNING
        VALUE(result) TYPE string
      RAISING
        cx_root.

    CLASS-METHODS obj_lines
      IMPORTING
        is_payload TYPE zif_ave_acr_types=>ty_saved_payload
      CHANGING
        ct_out     TYPE string_table.

    CLASS-METHODS hunk_lines
      IMPORTING
        is_payload TYPE zif_ave_acr_types=>ty_saved_payload
      CHANGING
        ct_out     TYPE string_table.

    CLASS-METHODS diff_lines
      IMPORTING
        is_payload TYPE zif_ave_acr_types=>ty_saved_payload
        iv_full    TYPE abap_bool
      CHANGING
        ct_out     TYPE string_table
      RAISING
        cx_root.

    CLASS-METHODS write_file
      IMPORTING
        iv_path TYPE string
      CHANGING
        ct_out  TYPE string_table.
ENDCLASS.


CLASS lcl_golden IMPLEMENTATION.

  METHOD flat.
    result = iv_text.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf
      IN result WITH `<br>`.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline
      IN result WITH `<br>`.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab
      IN result WITH `<tab>`.
  ENDMETHOD.


  METHOD hash.
    cl_abap_message_digest=>calculate_hash_for_char(
      EXPORTING
        if_algorithm  = 'MD5'
        if_data       = iv_text
      IMPORTING
        ef_hashstring = result ).
  ENDMETHOD.


  METHOD obj_lines.
    DATA lt_obj TYPE zif_ave_acr_types=>ty_t_obj_stats.
    DATA lt_auth TYPE zif_ave_acr_types=>ty_t_author_stats.

    lt_obj = is_payload-obj_stats.
    SORT lt_obj BY objtype class_name obj_name.

    LOOP AT lt_obj INTO DATA(ls_obj).
      APPEND |OBJ type={ ls_obj-objtype } name={ ls_obj-obj_name }| &&
             | class={ ls_obj-class_name }| &&
             | vnew={ ls_obj-versno_new } vold={ ls_obj-versno_old }| &&
             | author={ ls_obj-author } datum={ ls_obj-datum } zeit={ ls_obj-zeit }| &&
             | ins={ ls_obj-ins_count } del={ ls_obj-del_count } mod={ ls_obj-mod_count }| &&
             | hunks={ ls_obj-hunk_count } hi={ ls_obj-hunk_ins }| &&
             | hm={ ls_obj-hunk_mod } hd={ ls_obj-hunk_del }| &&
             | created={ ls_obj-is_created } disp={ flat( ls_obj-display_name ) }|
        TO ct_out.

      lt_auth = ls_obj-bt_authors.
      SORT lt_auth BY author.
      LOOP AT lt_auth INTO DATA(ls_auth).
        APPEND |AUT type={ ls_obj-objtype } name={ ls_obj-obj_name }| &&
               | author={ ls_auth-author }| &&
               | ins={ ls_auth-ins_count } del={ ls_auth-del_count }| &&
               | mod={ ls_auth-mod_count } hunks={ ls_auth-hunk_count }| &&
               | hi={ ls_auth-hunk_ins } hm={ ls_auth-hunk_mod } hd={ ls_auth-hunk_del }|
          TO ct_out.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD hunk_lines.
    " Sorted by object and block number, not by HUNK_KEY: the key sorts
    " ~10 before ~2, and a renumbering would then be unreadable in the diff.
    DATA lt_hunk TYPE STANDARD TABLE OF zif_ave_acr_types=>ty_hunk_info
                 WITH DEFAULT KEY.

    LOOP AT is_payload-hunks INTO DATA(ls_src).
      APPEND ls_src TO lt_hunk.
    ENDLOOP.
    SORT lt_hunk BY objtype obj_name hunk_no.

    LOOP AT lt_hunk INTO DATA(ls_hunk).
      APPEND |HNK key={ ls_hunk-hunk_key }| &&
             | type={ ls_hunk-objtype } name={ ls_hunk-obj_name }| &&
             | class={ ls_hunk-class_name }| &&
             | no={ ls_hunk-hunk_no } line={ ls_hunk-start_line }| &&
             | cnt={ ls_hunk-change_count } kind={ ls_hunk-change_kind }| &&
             | author={ ls_hunk-author }| &&
             | vnew={ ls_hunk-versno_new } vold={ ls_hunk-versno_old }| &&
             | req={ ls_hunk-req_ref } descr={ ls_hunk-obj_descr }| &&
             | retro={ flat( ls_hunk-retrofit ) }| &&
             | disp={ flat( ls_hunk-display_name ) }|
        TO ct_out.
    ENDLOOP.
  ENDMETHOD.


  METHOD diff_lines.
    DATA lt_diff TYPE STANDARD TABLE OF zif_ave_acr_types=>ty_diff_data
                 WITH DEFAULT KEY.
    DATA lv_id     TYPE i.
    DATA lv_seq    TYPE i.
    DATA lv_canon  TYPE string.
    DATA lv_ins    TYPE i.
    DATA lv_del    TYPE i.
    DATA lv_eq     TYPE i.
    DATA lv_bl     TYPE string.
    DATA lv_bd     TYPE string.
    DATA lv_exp_x  TYPE i.

    LOOP AT is_payload-diff_data INTO DATA(ls_src).
      APPEND ls_src TO lt_diff.
    ENDLOOP.
    SORT lt_diff BY key-objtype key-objname key-versno_n key-versno_o
                    key-blame key-ignore_case retrofit.

    LOOP AT lt_diff INTO DATA(ls_diff).
      lv_id = lv_id + 1.
      DATA(lv_id_txt) = |D{ lv_id WIDTH = 4 ALIGN = RIGHT PAD = '0' }|.

      " Canonical rendering of the change script — what the hash is taken
      " over, and what P_FULL writes out line by line.
      CLEAR: lv_canon, lv_ins, lv_del, lv_eq, lv_seq.
      LOOP AT ls_diff-diff INTO DATA(ls_op).
        lv_seq = lv_seq + 1.
        DATA(lv_op_line) = |{ ls_op-op }\|{ flat( ls_op-text ) }|.
        lv_canon = lv_canon && lv_op_line && cl_abap_char_utilities=>newline.
        CASE ls_op-op.
          WHEN '+'.
            lv_ins = lv_ins + 1.
          WHEN '-'.
            lv_del = lv_del + 1.
          WHEN OTHERS.
            lv_eq = lv_eq + 1.
        ENDCASE.
        IF iv_full = abap_true.
          APPEND |DOP { lv_id_txt } { lv_seq WIDTH = 6 ALIGN = RIGHT PAD = '0' } { lv_op_line }|
            TO ct_out.
        ENDIF.
      ENDLOOP.

      CLEAR lv_bl.
      LOOP AT ls_diff-blame_map INTO DATA(ls_blame).
        lv_bl = lv_bl
             && |{ ls_blame-author }\|{ ls_blame-versno_text }\|{ ls_blame-korrnum }|
             && |\|{ ls_blame-task }\|{ flat( ls_blame-text ) }|
             && cl_abap_char_utilities=>newline.
      ENDLOOP.

      CLEAR lv_bd.
      LOOP AT ls_diff-blame_deleted INTO DATA(ls_bldel).
        lv_bd = lv_bd
             && |{ ls_bldel-author }\|{ ls_bldel-versno_text }\|{ ls_bldel-korrnum }|
             && |\|{ ls_bldel-task }\|{ flat( ls_bldel-text ) }|
             && cl_abap_char_utilities=>newline.
      ENDLOOP.

      CLEAR lv_exp_x.
      LOOP AT ls_diff-expected INTO DATA(lv_flag).
        IF lv_flag = abap_true.
          lv_exp_x = lv_exp_x + 1.
        ENDIF.
      ENDLOOP.

      APPEND |DIF id={ lv_id_txt }| &&
             | type={ ls_diff-key-objtype } name={ ls_diff-key-objname }| &&
             | vnew={ ls_diff-key-versno_n } vold={ ls_diff-key-versno_o }| &&
             | blame={ ls_diff-key-blame } icase={ ls_diff-key-ignore_case }| &&
             | retrofit={ ls_diff-retrofit } created={ ls_diff-is_created }| &&
             | huge={ ls_diff-huge_source }| &&
             | ops={ lines( ls_diff-diff ) } ins={ lv_ins } del={ lv_del } eq={ lv_eq }| &&
             | md5={ hash( lv_canon ) }| &&
             | blame_n={ lines( ls_diff-blame_map ) } blame_md5={ hash( lv_bl ) }| &&
             | bldel_n={ lines( ls_diff-blame_deleted ) } bldel_md5={ hash( lv_bd ) }| &&
             | exp_n={ lines( ls_diff-expected ) } exp_x={ lv_exp_x }| &&
             | revlines={ lines( ls_diff-review_lines ) }| &&
             | htmllen={ strlen( ls_diff-html ) }| &&
             | title={ flat( ls_diff-title ) } meta={ flat( ls_diff-meta ) }|
        TO ct_out.
    ENDLOOP.
  ENDMETHOD.


  METHOD write_file.
    " UTF-8 with BOM, as everywhere else in AVE: the dumped source lines
    " carry comments in the developers' own language.
    cl_gui_frontend_services=>gui_download(
      EXPORTING
        filename              = iv_path
        filetype              = 'ASC'
        codepage              = '4110'
        write_bom             = abap_true
        write_field_separator = space
      CHANGING
        data_tab              = ct_out
      EXCEPTIONS
        OTHERS                = 24 ).
    IF sy-subrc <> 0.
      MESSAGE |Could not write { iv_path }| TYPE 'E'.
    ENDIF.
  ENDMETHOD.


  METHOD run.
    DATA ls_payload TYPE zif_ave_acr_types=>ty_saved_payload.
    DATA lt_out     TYPE string_table.
    DATA lv_dir     TYPE string.
    DATA lv_last    TYPE string.

    IF zcl_ave_acr_repository=>has_review_table( ) = abap_false.
      MESSAGE 'ZAVE_REVIEW does not exist in this system' TYPE 'E'.
    ENDIF.
    IF zcl_ave_acr_repository=>has_remote_field( ) = abap_false.
      MESSAGE 'ZAVE_REVIEW has no REMOTE key field' TYPE 'E'.
    ENDIF.

    DATA(lv_ok) = zcl_ave_acr_repository=>load_review_payload(
      EXPORTING
        iv_trkorr  = iv_trkorr
        iv_remote  = iv_remote
      CHANGING
        cs_payload = ls_payload ).
    IF lv_ok = abap_false.
      MESSAGE |No saved review for { iv_trkorr } / remote '{ iv_remote }'| TYPE 'E'.
    ENDIF.

    APPEND |# AVE golden dump v1| TO lt_out.
    APPEND |# trkorr={ iv_trkorr } remote={ iv_remote } tag={ iv_tag } full={ iv_full }|
      TO lt_out.
    APPEND |# schema={ ls_payload-schema_version }| &&
           | objects={ lines( ls_payload-obj_stats ) }| &&
           | hunks={ lines( ls_payload-hunks ) }| &&
           | diffs={ lines( ls_payload-diff_data ) }| TO lt_out.
    APPEND |# dropped as volatile: last_saved_at, last_saved_by, timings, history|
      TO lt_out.
    APPEND |# review state present: actions={ lines( ls_payload-hunk_actions ) }| &&
           | userstates={ lines( ls_payload-user_states ) }| &&
           | threads={ lines( ls_payload-threads ) }| TO lt_out.

    obj_lines(  EXPORTING is_payload = ls_payload CHANGING ct_out = lt_out ).
    hunk_lines( EXPORTING is_payload = ls_payload CHANGING ct_out = lt_out ).
    TRY.
        diff_lines( EXPORTING is_payload = ls_payload
                              iv_full    = iv_full
                    CHANGING  ct_out     = lt_out ).
      CATCH cx_root INTO DATA(lx_dump).
        MESSAGE |Dump failed: { lx_dump->get_text( ) }| TYPE 'E'.
    ENDTRY.

    lv_dir = iv_dir.
    WHILE strlen( lv_dir ) > 0.
      lv_last = substring( val = lv_dir off = strlen( lv_dir ) - 1 len = 1 ).
      IF lv_last <> '\' AND lv_last <> '/'.
        EXIT.
      ENDIF.
      lv_dir = substring( val = lv_dir off = 0 len = strlen( lv_dir ) - 1 ).
    ENDWHILE.

    DATA(lv_rem) = COND string( WHEN iv_remote IS INITIAL THEN ``
                                ELSE |_{ iv_remote }| ).
    DATA(lv_path) = |{ lv_dir }\\ave_golden_{ iv_trkorr }{ lv_rem }_{ iv_tag }.txt|.

    write_file( EXPORTING iv_path = lv_path CHANGING ct_out = lt_out ).

    WRITE: / 'Written:', lv_path.
    WRITE: / 'Lines:  ', lines( lt_out ).
    WRITE: / 'Objects:', lines( ls_payload-obj_stats ),
             'Hunks:',   lines( ls_payload-hunks ),
             'Diffs:',   lines( ls_payload-diff_data ).

    IF lines( ls_payload-hunk_actions ) > 0
      OR lines( ls_payload-user_states ) > 0
      OR lines( ls_payload-threads ) > 0.
      WRITE: / 'WARNING: this request already carries a real review'.
      WRITE: / '         (approvals / notes / comment threads).'.
      WRITE: / '         Do not use it as a harness request - a "Delete and'.
      WRITE: / '         recalc" on it destroys that review.'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  lcl_golden=>run(
    iv_trkorr = p_trkorr
    iv_remote = p_remote
    iv_tag    = p_tag
    iv_dir    = p_dir
    iv_full   = p_full ).
