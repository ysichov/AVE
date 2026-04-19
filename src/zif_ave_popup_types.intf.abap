"! Shared types for AVE popup diff engine and HTML renderer.
"! Defined here so standalone program and new extracted classes all reference one source.
INTERFACE zif_ave_popup_types
  PUBLIC.

  "! One diff operation: op = '=' (equal), '-' (deleted), '+' (inserted)
  TYPES:
    BEGIN OF ty_diff_op,
      op(255) TYPE c,
      text    TYPE string,
    END OF ty_diff_op.
  TYPES ty_t_diff TYPE STANDARD TABLE OF ty_diff_op WITH DEFAULT KEY.

  "! Version row: one VRSD entry enriched with author/task/request display data.
  TYPES:
    BEGIN OF ty_version_row,
      objname        TYPE versobjnam,
      versno         TYPE versno,
      versno_text    TYPE string,
      datum          TYPE versdate,
      zeit           TYPE verstime,
      author         TYPE versuser,
      author_name    TYPE ad_namtext,
      obj_owner      TYPE versuser,
      obj_owner_name TYPE ad_namtext,
      korrnum        TYPE verskorrno,
      task           TYPE trkorr,
      korr_text      TYPE string,
      objtype        TYPE versobjtyp,
      rowcolor(4)    TYPE c,
    END OF ty_version_row.
  TYPES ty_t_version_row TYPE STANDARD TABLE OF ty_version_row WITH DEFAULT KEY.

  "! Blame entry: a source line annotated with author/version info
  TYPES:
    BEGIN OF ty_blame_entry,
      text        TYPE string,
      author      TYPE versuser,
      author_name TYPE ad_namtext,
      datum       TYPE versdate,
      zeit        TYPE verstime,
      versno_text TYPE string,
      korrnum     TYPE verskorrno,
      task        TYPE trkorr,
      task_text   TYPE string,
    END OF ty_blame_entry.
  TYPES ty_blame_map TYPE STANDARD TABLE OF ty_blame_entry WITH DEFAULT KEY.

ENDINTERFACE.
