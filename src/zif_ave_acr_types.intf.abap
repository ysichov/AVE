interface ZIF_AVE_ACR_TYPES
  public .

    "! Per-author change contribution inside one object diff
  TYPES:
    BEGIN OF ty_author_stats,
      author      TYPE versuser,
      author_name TYPE ad_namtext,
      ins_count   TYPE i,
      del_count   TYPE i,
      mod_count   TYPE i,
    END OF ty_author_stats.
  TYPES ty_t_author_stats TYPE STANDARD TABLE OF ty_author_stats WITH DEFAULT KEY.

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
      bt_authors  TYPE ty_t_author_stats,
    END OF ty_obj_stats.
  TYPES ty_t_obj_stats TYPE STANDARD TABLE OF ty_obj_stats WITH DEFAULT KEY.


endinterface.
