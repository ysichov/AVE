"! Interface for all AVE object handlers (program, class, function, TR)
INTERFACE zif_ave_object
  PUBLIC.

  TYPES ty_t_korr_range TYPE RANGE OF trkorr.

  "! Popup display settings (maps to selection screen checkboxes)
  TYPES:
    BEGIN OF ty_settings,
      show_diff       TYPE abap_bool,
      layout          TYPE abap_bool,
      two_pane        TYPE abap_bool,
      no_toc          TYPE abap_bool,
      ignore_case     TYPE abap_bool,
      ignore_indent   TYPE abap_bool,
      compact         TYPE abap_bool,
      remove_dup      TYPE abap_bool,
      blame           TYPE abap_bool,
      filter_user     TYPE versuser,
      date_from       TYPE versdate,
      code_review     TYPE abap_bool,
      system          TYPE verssysnam,
      filter_korrnum  TYPE trkorr,
      filter_korrnums TYPE ty_t_korr_range,
      "! Also read the objects of the S-tasks belonging to the entered requests
      include_tasks   TYPE abap_bool,
      destination     TYPE text255,
      model           TYPE text255,
      apikey          TYPE text255,
      provider        TYPE string,
      "! Frontend folder holding the review profiles (<profile>.md / .json)
      prompt_path     TYPE text255,
      "! Selected profile name — file name without extension
      prompt_profile  TYPE text255,
      "! Output token cap per AI request
      max_tokens      TYPE i,
    END OF ty_settings.

  "! A single versionable part of an object (e.g. one method, one include)
  TYPES:
    BEGIN OF ty_part,
      class       TYPE string,      "class
      unit        TYPE string,      "method/include
      object_name TYPE versobjnam,   " VRSD object name
      type        TYPE versobjtyp,   " VRSD object type (REPS, METH, CLSD, …)
    END OF ty_part,
    ty_t_part TYPE STANDARD TABLE OF ty_part WITH DEFAULT KEY.

  "! Returns the list of versionable parts for this object
  METHODS get_parts
    RETURNING
      VALUE(result) TYPE ty_t_part
    RAISING
      zcx_ave.

  "! Returns the logical object name
  METHODS get_name
    RETURNING
      VALUE(result) TYPE string.

  "! Returns TRUE if the object exists in the current system
  METHODS check_exists
    RETURNING
      VALUE(result) TYPE abap_bool.

ENDINTERFACE.
