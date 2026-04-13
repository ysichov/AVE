"! Interface for all AVE object handlers (program, class, function, TR)
INTERFACE zif_ave_object
  PUBLIC.

  "! Popup display settings (maps to selection screen checkboxes)
  TYPES:
    BEGIN OF ty_settings,
      show_diff TYPE abap_bool,
      two_pane  TYPE abap_bool,
      no_toc    TYPE abap_bool,
      compact   TYPE abap_bool,
    END OF ty_settings.

  "! A single versionable part of an object (e.g. one method, one include)
  TYPES:
    BEGIN OF ty_part,
      class        TYPE string,      "class
      unit         type string,      "method/include
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
