interface ZIF_AVE_ACR_TYPES
  public .

    TYPES ty_approved TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

  "! Per-author change contribution inside one object diff
  TYPES:
    BEGIN OF ty_author_stats,
      author      TYPE versuser,
      author_name TYPE ad_namtext,
      ins_count   TYPE i,
      del_count   TYPE i,
      mod_count   TYPE i,
      hunk_count  TYPE i,
    END OF ty_author_stats.
  TYPES ty_t_author_stats TYPE STANDARD TABLE OF ty_author_stats WITH DEFAULT KEY.

  "! Per-reviewer action totals for the report header
  TYPES:
    BEGIN OF ty_reviewer_stats,
      reviewer      TYPE syuname,
      reviewer_name TYPE ad_namtext,
      appr_count    TYPE i,
      decl_count    TYPE i,
      total_count   TYPE i,
      saved_at      TYPE timestampl,
    END OF ty_reviewer_stats.
  TYPES ty_t_reviewer_stats TYPE STANDARD TABLE OF ty_reviewer_stats WITH DEFAULT KEY.

  "! Statistics for one changed object: version pair, counts, blame breakdown
  TYPES:
    BEGIN OF ty_obj_stats,
      objtype     TYPE versobjtyp,
      class_name  TYPE seoclsname,   " parent class for METH / CPUB / CPRO / CPRI / CINC
      obj_name    TYPE versobjnam,
      versno_new  TYPE versno,
      versno_old  TYPE versno,
      author      TYPE versuser,
      author_name TYPE ad_namtext,
      datum       TYPE versdate,
      zeit        TYPE verstime,
      ins_count   TYPE i,
      del_count   TYPE i,
      mod_count   TYPE i,
      hunk_count    TYPE i,
      display_name  TYPE string,
      bt_authors    TYPE ty_t_author_stats,
      is_created    TYPE abap_bool,   " abap_true = object is brand-new (no prior version)
    END OF ty_obj_stats.
  TYPES ty_t_obj_stats TYPE STANDARD TABLE OF ty_obj_stats WITH DEFAULT KEY.


endinterface.
