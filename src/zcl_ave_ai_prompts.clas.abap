"! Review profile loader.
"! A profile is a pair of files in one frontend folder, matched by name:
"!   <profile>.md   — the system prompt (required)
"!   <profile>.json — the output JSON schema (optional)
"! Mirrors ZCL_AI_AGENTS_PROMPTS in the ABAP-AI-Code repository so both tools
"! share one convention: same folder layout, same optional-schema rule.
CLASS zcl_ave_ai_prompts DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        !iv_path TYPE string.

    "! Profile names found in the folder — the *.md file names without extension.
    METHODS list_profiles
      RETURNING
        VALUE(result) TYPE string_table.

    "! Contents of <profile>.md. Empty when the file cannot be read.
    METHODS get_system
      IMPORTING
        !iv_profile   TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! Contents of <profile>.json, or empty when there is none — the schema is
    "! optional and a profile without one simply asks for free-form text.
    METHODS get_schema
      IMPORTING
        !iv_profile   TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! Drops the cache so edited files are picked up without leaving the report.
    METHODS reload.

    "! Contents of one file given by its full frontend path — the system prompt
    "! selected directly on the selection screen, without the folder/profile
    "! convention. Empty when the file cannot be read; cached per path, so the
    "! per-hunk AI loop does not hit the frontend once per block.
    CLASS-METHODS read_system_file
      IMPORTING
        !iv_path      TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! Drops the file cache of READ_SYSTEM_FILE.
    CLASS-METHODS clear_file_cache.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_profile,
        profile TYPE string,
        system  TYPE string,
        schema  TYPE string,
      END OF ty_profile.

    DATA mv_path  TYPE string.
    DATA mt_cache TYPE HASHED TABLE OF ty_profile WITH UNIQUE KEY profile.

    TYPES:
      BEGIN OF ty_file,
        path TYPE string,
        text TYPE string,
      END OF ty_file.
    CLASS-DATA gt_file_cache TYPE HASHED TABLE OF ty_file WITH UNIQUE KEY path.

    "! Reads both files of a profile once and caches them — the AI review loops
    "! over hunks, and a frontend round-trip per hunk would be painfully slow.
    METHODS load
      IMPORTING
        !iv_profile   TYPE string
      RETURNING
        VALUE(result) TYPE ty_profile.

    METHODS read_file
      IMPORTING
        !iv_filename  TYPE string
      RETURNING
        VALUE(result) TYPE string.

    METHODS build_file_path
      IMPORTING
        !iv_filename  TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS zcl_ave_ai_prompts IMPLEMENTATION.

  METHOD constructor.
    mv_path = iv_path.
  ENDMETHOD.

  METHOD reload.
    CLEAR mt_cache.
  ENDMETHOD.

  METHOD list_profiles.
    CHECK mv_path IS NOT INITIAL.

    DATA lt_files TYPE filetable.
    DATA lv_count TYPE i.
    DATA(lv_dir) = mv_path.
    REPLACE ALL OCCURRENCES OF '\' IN lv_dir WITH '/'.

    cl_gui_frontend_services=>directory_list_files(
      EXPORTING
        directory  = lv_dir
        filter     = '*.md'
        files_only = abap_true
      CHANGING
        file_table = lt_files
        count      = lv_count
      EXCEPTIONS
        OTHERS     = 1 ).
    CHECK sy-subrc = 0.

    LOOP AT lt_files INTO DATA(ls_file).
      DATA(lv_name) = CONV string( ls_file-filename ).
      " Strip the .md extension — the profile name is what the two files share.
      FIND REGEX `\.[mM][dD]$` IN lv_name MATCH OFFSET DATA(lv_ext_off).
      CHECK sy-subrc = 0.
      APPEND lv_name(lv_ext_off) TO result.
    ENDLOOP.

    SORT result.
  ENDMETHOD.

  METHOD get_system.
    result = load( iv_profile )-system.
  ENDMETHOD.

  METHOD get_schema.
    result = load( iv_profile )-schema.
  ENDMETHOD.

  METHOD load.
    CHECK iv_profile IS NOT INITIAL.

    READ TABLE mt_cache INTO result WITH TABLE KEY profile = iv_profile.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    result-profile = iv_profile.
    result-system  = read_file( |{ iv_profile }.md| ).
    result-schema  = read_file( |{ iv_profile }.json| ).

    " A schema file that is missing, unreadable, or not JSON means "no schema" —
    " same rule as ZCL_AI_AGENTS_PROMPTS: it must start with { or [.
    DATA(lv_probe) = result-schema.
    CONDENSE lv_probe.
    IF lv_probe IS INITIAL OR ( lv_probe(1) <> '{' AND lv_probe(1) <> '[' ).
      CLEAR result-schema.
    ENDIF.

    INSERT result INTO TABLE mt_cache.
  ENDMETHOD.

  METHOD clear_file_cache.
    CLEAR gt_file_cache.
  ENDMETHOD.

  METHOD read_system_file.
    CHECK iv_path IS NOT INITIAL.

    READ TABLE gt_file_cache INTO DATA(ls_file) WITH TABLE KEY path = iv_path.
    IF sy-subrc = 0.
      result = ls_file-text.
      RETURN.
    ENDIF.

    DATA lt_lines TYPE STANDARD TABLE OF string.
    DATA(lv_filename) = iv_path.
    REPLACE ALL OCCURRENCES OF '\' IN lv_filename WITH '/'.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename = lv_filename
        filetype = 'ASC'
      CHANGING
        data_tab = lt_lines
      EXCEPTIONS
        OTHERS   = 1 ).
    IF sy-subrc = 0.
      LOOP AT lt_lines INTO DATA(lv_line).
        IF result IS NOT INITIAL.
          result = result && cl_abap_char_utilities=>newline.
        ENDIF.
        result = result && lv_line.
      ENDLOOP.
    ENDIF.

    " Cached even when unreadable: a wrong path must not retry per hunk.
    INSERT VALUE #( path = iv_path text = result ) INTO TABLE gt_file_cache.
  ENDMETHOD.

  METHOD read_file.
    DATA lt_lines TYPE STANDARD TABLE OF string.
    DATA(lv_filename) = build_file_path( iv_filename ).

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename = lv_filename
        filetype = 'ASC'
      CHANGING
        data_tab = lt_lines
      EXCEPTIONS
        OTHERS   = 1 ).
    CHECK sy-subrc = 0.

    LOOP AT lt_lines INTO DATA(lv_line).
      IF result IS NOT INITIAL.
        result = result && cl_abap_char_utilities=>newline.
      ENDIF.
      result = result && lv_line.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_file_path.
    result = mv_path.
    REPLACE ALL OCCURRENCES OF '\' IN result WITH '/'.

    IF result IS INITIAL.
      result = iv_filename.
      RETURN.
    ENDIF.

    DATA(lv_last) = strlen( result ) - 1.
    IF result+lv_last(1) <> '/'.
      result = result && '/'.
    ENDIF.

    result = result && iv_filename.
  ENDMETHOD.

ENDCLASS.
