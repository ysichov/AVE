# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AVE (ABAP Versions Explorer) is an SAP GUI ABAP program for browsing, comparing, and reviewing object versions in a SAP system. It supports Programs/Includes, Classes, Function Modules, Interfaces, CDS DDL Sources, Function Groups, DDIC objects (tables, domains, data elements), Transport Requests/Tasks, and Packages.

### What it is for

The README carries the user-facing version of this; the short form, because it decides what "correct" means in this codebase:

- **The unit of work is a transport, not an object.** SE80 version management and Eclipse compare one object with one of its versions. AVE takes a request, task, package, class or function group and expands it into every reviewable part, with one version list and one diff engine behind all of them.
- **Noise is not a change.** Reformatting, case, generator timestamps, generated Gateway/SEGW classes, SAP-authored framework includes, empty class sections, comment-only new objects, identical repeated versions, TOC versions, lines that only moved, objects that no longer exist — all of it is filtered before the reviewer sees it. When in doubt about a diff feature, the question is "would a developer call this a change they made?".
- **Class sections come back in arbitrary order**, which is why the declaration-aware diff exists (`zcl_ave_diff_decl`) instead of a plain line diff.
- **Who changed it must survive a Transport of Copies** — hence the T-copy → parent K resolution in `zcl_ave_request`.
- **A second development system is a risk**, not a curiosity: the retrofit ("moving violation") comparison exists so a request cannot silently overwrite work in the other system.
- **It is a review tool**: approve/decline per hunk (never your own), comments, per-developer and per-reviewer totals, persisted in `ZAVE_REVIEW`, optional LLM assistance.

Diagnostics are opt-in: the selection screen carries `P_METRIC` ("Metrics (cost estimate)") and `P_DEBUG` ("Debug info"), carried in `zif_ave_object=>ty_settings-metrics` / `-debug` into `zcl_ave_popup=>mv_metrics` / `mv_debug`. Without `metrics` the Metrics button, the picker's estimate columns and band selection are gone and `collect_metrics` is never called; without `debug` there is no Debug button and no diagnostics log under the report. Anything added for developers of AVE itself belongs behind one of these two.

Do not analyze or edit `src/z_ave_standalone.prog.abap` directly. It is a generated build artifact.

Agent rule: DON'T analyse and change standalone (`src/z_ave_standalone.prog.abap`).

ABAP naming rule: method names must be 30 characters or shorter.

## Linting

Run ABAP lint from the repo root with the config file as a positional argument:

```bash
abaplint .abaplint.json
```

Do not use `abaplint --config .abaplint.json`; this CLI treats it incorrectly and falls back to the default config, producing thousands of irrelevant style findings including the generated standalone file.

## Generating the Standalone File

`src/z_ave_standalone.prog.abap` is auto-generated; never edit it directly.

To regenerate it after changing source files, run from the repo root:

```bash
bash generate_standalone.sh
# or on Windows: generate_standalone.bat
```

This uses [abapmerge](https://github.com/larshp/abapmerge) to merge all source files into a single deployable program. The tool must be installed and available on `PATH`.

## Architecture

The entry point is `src/z_ave.prog.abap` (selection screen + bootstrap). The reusable logic lives in `src/zcl_ave_*` classes, with shared contracts in `src/zif_ave_*` interfaces.

Main layers:

- Object handler layer: resolves a logical input object into versionable parts (`REPS`, `METH`, `FUNC`, `DDLS`, etc.).
- Version layer: reads VRSD/SVRS metadata and source for historical, active, and generated/synthetic versions.
- Diff/render layer: computes line and inline diffs, renders HTML, and builds blame metadata.
- Popup/UI layer: SAP GUI splitters, ALV grids, HTML viewer, commands, and code-review workflow.
- Code Review layer: hunk statistics, report HTML, approve/decline state, notes, and persistence in `ZAVE_REVIEW`.

## Class Inventory

Use this section as a refactoring map. It intentionally documents source classes only; `z_ave_standalone.prog.abap` is excluded because it is generated.

### Core Contracts

#### `zif_ave_object`

Interface implemented by every object handler.

- `get_parts`: returns the versionable parts of the object.
- `get_name`: returns the logical object name.
- `check_exists`: checks whether the object exists in the current system.

#### `zif_ave_popup_types`

Shared popup/diff types.

- Defines diff operations (`ty_diff_op`, `ty_t_diff`).
- Defines enriched version rows (`ty_version_row`, `ty_t_version_row`).
- Defines blame entries/maps (`ty_blame_entry`, `ty_blame_map`).

#### `zif_ave_acr_types`

Shared Auto Code Review report types.

- Defines approved/declined hunk-key sets.
- Defines per-author stats, per-reviewer stats, and per-object diff stats.

### Exceptions and Utilities

#### `zcx_ave`

Single checked exception class for AVE.

- `constructor`: delegates to `cx_static_check`.
- `raise_from_syst`: wraps the current `sy-msg*` message as `zcx_ave` via `cx_proxy_t100`.

#### `zcl_ave_author`

Resolves SAP users to display names with a class-level cache.

- `get_name`: reads `USER_ADDR`, falls back to `USR21`/`ADRP`, and returns the display name or the username.

#### `zcl_ave_versno`

Converts version numbers between DB/internal and AVE/external representation.

- `to_internal`: maps external active/latest `99998` to DB version `0`.
- `to_external`: maps DB version `0` to external `99998` so sorting works naturally.

#### `zcl_ave_progress`

Cooperative progress indicator and long-running-operation interrupter.

- `constructor`: stores title, threshold, confirmation key, and initial timestamps.
- `check`: throttles SAP GUI progress updates, estimates ETA, and asks whether to continue after the threshold.
- `was_stopped`: reports whether the user chose to stop.

#### `zcl_ave_html_viewer`

Small SAP GUI HTML viewer helper.

- `show_html`: converts an HTML string to `W3HTMLTAB`, loads it into `cl_gui_html_viewer`, optionally focuses the viewer, and flushes CFW.

#### `zcl_ave_version_list`

Version-list service for popup object/version navigation.

- `load`: reads VRSD metadata, enriches rows with request/task/owner text, applies popup filters, and adds remote baseline rows when configured.

### Object Handler Layer

#### `zcl_ave_object_factory`

Factory for object handlers.

- `get_instance`: creates the handler for `PROG`, `CLAS`, `INTF`, `FUNC`, `TR`, `DEVC`, or `DDLS`; raises `zcx_ave` if unsupported or missing.

#### `zcl_ave_object_prog`

Handler for a single program/include.

- `constructor`: stores the program/include name.
- `zif_ave_object~check_exists`: checks `TRDIR`.
- `zif_ave_object~get_name`: returns the stored name.
- `zif_ave_object~get_parts`: returns one `REPS` part.

#### `zcl_ave_object_clas`

Handler for ABAP classes.

- `constructor`: stores the class name.
- `zif_ave_object~check_exists`: uses `cl_abap_classdescr=>describe_by_name`.
- `zif_ave_object~get_name`: returns the class name.
- `zif_ave_object~get_parts`: returns class sections, local includes, test include, and one `METH` part per method.

#### `zcl_ave_object_intf`

Handler for ABAP interfaces.

- `constructor`: stores the interface name.
- `zif_ave_object~check_exists`: checks `SEOCLASS` for interface type.
- `zif_ave_object~get_name`: returns the interface name.
- `zif_ave_object~get_parts`: resolves the generated interface include and returns it as one `REPS` part.

#### `zcl_ave_object_func`

Handler for a single function module.

- `constructor`: stores the function module name.
- `zif_ave_object~check_exists`: calls `FUNCTION_EXISTS`.
- `zif_ave_object~get_name`: returns the function module name.
- `zif_ave_object~get_parts`: returns one `FUNC` part.

#### `zcl_ave_object_ddls`

Handler for a CDS DDL source.

- `constructor`: stores the DDLS name.
- `zif_ave_object~check_exists`: checks active `R3TR/DDLS` in `TADIR`.
- `zif_ave_object~get_name`: returns the DDLS name.
- `zif_ave_object~get_parts`: returns one `DDLS` part.

#### `zcl_ave_object_tr`

Handler for transport requests and tasks.

- `constructor`: stores the transport ID.
- `get_parts_expanded`: returns TR parts with CLAS/INTF rows expanded into reviewable technical parts (CLSD/RELE skipped).
- `get_object_keys`: reads and deduplicates E071 entries via `TRINT_READ_REQUEST`.
- `get_objects_for_keys`: maps E071 keys to object handlers and drops unsupported entries.
- `get_object`: creates a handler for supported transport object keys.
- `zif_ave_object~check_exists`: validates the transport via `zcl_ave_request`.
- `zif_ave_object~get_name`: returns the transport ID.
- `zif_ave_object~get_parts`: expands transport contents into versionable parts, with special handling for class/interface drill-in and `LIMU/METH`.

#### `zcl_ave_object_pack`

Handler for development packages.

- `constructor`: stores the package name.
- `get_object_keys`: reads package objects from `TADIR`.
- `get_object`: creates handlers for supported package object keys.
- `zif_ave_object~check_exists`: checks `TDEVC`.
- `zif_ave_object~get_name`: returns the package name.
- `zif_ave_object~get_parts`: expands package contents into versionable parts, preserving unsupported entries as visible rows.

### Version and Source Layer

#### `zcl_ave_request`

Represents a transport request and helps map object versions to tasks.

- `constructor`: stores the request ID and loads details.
- `get_filter_ranges` (static): builds the tasks/parents filter ranges for `zcl_ave_version_list=>load` for one request (S/R children, or the request itself).
- `resolve_parent_k` (static): resolves any VRSD korrnum to its parent K request(s) — S/R task via `strkorr`, K itself, T-copy via its CORR/MERG E071 entries.
- `get_header` (static): cached `E070`/`E07T` header of one request. Every other request lookup in AVE goes through it, because the version list builds one request object per VRSD row — uncached, the same header was read once per version and, for a class, once per version and technical part.
- `clear_cache` (static): drops the header and per-object task caches; called at the start of `prepare_code_review` so a long session still sees requests released meanwhile.
- `populate_details`: takes text/status from `get_header`.
- `get_task_for_object`: normalizes object type/name and delegates to task lookup.
- `get_latest_task_for_object`: finds the latest matching task in `E071`/`E070`, constrained by version timestamp when supplied. The candidate set depends on the object alone, never on the request, so it is read once per object (`get_object_tasks`) and reused for all its versions.

#### `zcl_ave_vrsd`

Loads version directory records for one object part.

- `constructor`: stores object identity, loads VRSD/directory records, optionally adds active version, sorts, and applies date cutoff.
- `load_from_table`: reads `VRSD` plus `SVRS_GET_VERSION_DIRECTORY_46`, handles unreleased/TOC filtering, and normalizes version numbers.
- `apply_date_from_cutoff`: keeps the newest predecessor before the cutoff and removes older regular versions.
- `load_active_or_modified`: appends or updates pseudo-version metadata for active/modified states.
- `determine_request_active_modif`: uses transport lock APIs to find the request for an active/modified object.
- `get_request_active_modif`: memoizes the active/modified request lookup.
- `read_vrsd`: reads repository metadata through `SVRS_GET_VERSION_REPOSITORY`.
- `get_versionable_object`: builds the SVRS versionable-object shell.
- `get_versionable_object_mode`: maps pseudo-version numbers to SVRS modes.

#### `zcl_ave_version`

Represents one version of a versionable object part.

- `constructor`: stores the VRSD row and loads attributes, task, and author display name.
- `get_source`: loads source with `SVRS_GET_REPS_FROM_OBJECT`, or DDLS-specific logic for `DDLS`.
- `load_ddls_source`: reads DDLS source through `cl_svrs_tlogo_controller`.
- `load_attributes`: copies VRSD metadata into public read-only fields.
- `load_latest_task`: finds the responsible task for the version and updates task/author.
- `load_author_name`: resolves the author display name.

#### `zcl_ave_version2`

Alternative source loader built around `SVRS_GET_VERSION_LOCAL` and `SVRS_GET_VERSION_REMOTE`.

- `get_source_local`: loads a local active, modified, or historical source version.
- `get_source_local_compat`: tries the SVRS2 local loader first, then falls back to legacy VRSD/SVRS source loading.
- `get_source_remote`: loads source from a remote TMS system.
- `build_object`: initializes an `svrs2_versionable_object`.
- `extract_source`: extracts source from TLOGO objects or standard ABAP object components.
- `extract_tlog_source`: deserializes TLOG content and extracts DDLS/TLOGO source lines.

### Diff, HTML, and Data Helpers

#### `zcl_ave_popup_diff`

Diff engine used by the popup, HTML renderer, blame calculation, and simulator.

- `compute_diff`: entry point; routes class section sources to the declaration-aware diff and everything else to the line diff.
- `diff_declarations`: private; diffs a class section declaration by declaration using `zcl_ave_diff_decl` pairs.
- `diff_lines`: private; the plain line-level diff (RS_CMP + ignore-case fold + semantic cleanup + commented-twin pairing).
- `char_diff_html`: renders inline character-level differences for one old/new line pair.
- `has_common_chars`: decides whether two changed lines are similar enough to pair.
- `count_edit_runs`: estimates how many edit runs exist between two line middles.
- `build_blame_map`: replays diffs across versions and attributes added/deleted lines to authors.
- `collapse_token_ops`: private helper that collapses noisy character ops into whole-token replacements.

Keep `html_simulator/diff.js` in sync with the pairing/diff behavior here.

#### `zcl_ave_diff_decl`

Declaration-aware pairing for class section sources (`CPUB`/`CPRO`/`CPRI` includes), used by `zcl_ave_popup_diff=>compute_diff`.

SAP regenerates section includes with an arbitrary declaration order, so a plain line diff reports moved declarations as delete+insert far apart and matches the `importing` / `!IV_X type Y` lines of one method against another method's. Pairing by signature removes both effects.

- `is_section_source`: true when the first statement of the source is `PUBLIC`/`PROTECTED`/`PRIVATE SECTION` (the only gate for the declaration-aware path).
- `pair_declarations`: splits both sides into declaration blocks and pairs them by signature key (kind + declared name); the result tiles both sources completely and is ordered by the new side.
- `align_params`: reorders the parameter lines of one old method declaration to the new parameter order (matched by group + parameter name); never moves the line carrying the closing `.`.
- `parse_blocks`, `split_code`, `decl_key`, `param_keys`: private parsing helpers.

#### `zcl_ave_popup_html`

HTML renderer for source and diff views.

- `source_to_html`: renders plain source with line numbers.
- `diff_to_html`: renders one-pane/two-pane diff HTML, compact mode, inline changes, blame separators, and code-review hunk markers.
- `cds_source_to_html`: renders CDS/DDLS source with lightweight syntax highlighting.
- `debug_diff_html`: renders diagnostic HTML for diff operations and pairing decisions.
- `is_comment`: private helper that detects ABAP comment lines.

#### `zcl_ave_popup_data`

Static data helpers for popup/version operations.

- `get_user_name`: resolves a user display name through `zcl_ave_author`.
- `get_latest_author`: returns the author of the newest VRSD entry.
- `check_part_exists`: does the object of this part still exist? Asks the table that owns the answer, not `TADIR`: `TRDIR` for programs and includes (what SE38 itself checks — an include of a function group or class has no `R3TR PROG` entry, and a deleted program can leave its `TADIR` row behind), `TFDIR` for function modules (`LIMU`, never in `TADIR`), `SEOCOMPO` for methods, `SEOCLASS` for the class pool and the class sections, `TADIR` for what really is an `R3TR` object of its own (CLAS, FUGR, DDLS, DDIC). Accepts a method name in either spelling — plain, or the VRSD one with the class padded to 30 chars in front of it.
- `get_type_text`: returns cached SAP object-type text.
- `load_type_cache`: fills the object-type cache from `TRINT_OBJECT_TABLE`.
- `check_class_has_author`: checks whether any class part has substantive changes.
- `build_versions_for_check`: builds a newest-first version list with transport function metadata.
- `is_substantive_user_change`: compares a target version with the nearest prior K-type version.
- `remove_duplicate_versions`: removes consecutive versions with identical source, preserving required baselines/current transport rows.
- `get_active_line_count`: reads the active include/source and returns its line count.
- `get_ver_source`: reads a version source, creating a synthetic VRSD row when needed.

### Code Review Helpers

#### `zcl_ave_acr_metrics`

Cost metrics of a review scope, collected before anything is computed: it answers "can this request be prepared in the dialog, or does it need a background run?".

- `collect`: one metric row per reviewable part — VRSD version count (one grouped SELECT), technical sub-parts, active line count, cached flag, time estimate and weight band (L/M/H). Uses measured durations from earlier Prepare runs where available and rescales the model for the rest.
- `band_keys` / `count_band`: part keys and counts of the given bands, feeding `prepare_code_review` directly (`sapevent:prepare_band~LM`).
- `format_secs`, `to_html`: duration formatting and the Metrics page.

Every part is estimated **twice**, with and without blame (`est_nb` / `est_bl`), so the price of blame is visible before the toolbar toggle is touched; the active setting decides which of the two fills `est_secs` and therefore the weight band. Measurements are likewise kept per blame setting — a run with blame never overwrites the measurement of a run without it.

Screen updates during a run are governed by `zcl_ave_acr_workflow`: up to `c_full_report_max` (50) objects the full report is redrawn as before, above it a one-line progress page (`zcl_ave_acr_renderer=>build_progress_html`) takes its place — rebuilding the report renders every object collected so far, so its cost grows with the square of the object count. Either way the screen is refreshed at most every `c_refresh_secs` (10 s), and the time spent on it is summed separately and reported as a `RENDER:` diagnostic line, so it never lands in the per-object measurements. Remaining time on the progress page comes from the pre-run estimates scaled by the factor observed on the objects already done, not from a done/total ratio.

Durations are handled in **milliseconds** end to end (`est_nb_ms` / `est_bl_ms` / `ty_part_timing-msecs`) and rendered by `format_ms` as seconds with one decimal up to ten minutes — most parts finish in a few seconds, where whole seconds hide every difference. A time shown with a leading `~` is still a model value; without it, it is what the last Prepare actually took, and the `Source` column then names the prediction and the percentage it was off by.

The feedback loop closes through `ty_part_timing`: `prepare_code_review` collects the metrics once before its loop and stores, next to each measured duration, the estimate that had been made for that part (`est_nb_ms` / `est_bl_ms`). The next `collect` calibrates measured-vs-predicted from those stored pairs — not from a model re-evaluated later on possibly changed version counts — and applies the resulting factor to every part it could not measure.

The estimate separates two costs that are often confused: the **version-metadata load** runs over the object's complete VRSD history (`zcl_ave_version_list=>load` builds a `zcl_ave_version` — and with it an `E070`/`E07T`/`E071` lookup — per row, before any scope filtering), while **blame** replays only the reviewed range, because `build_blame_map` filters versions to `[baseline .. new]`. Hence two columns: `Versions` (all, drives the load) and `In scope` (versions of the reviewed request, drives the replay). The page warns when an S/R task is the selected scope, since version trimming is skipped there and the metadata load covers the full history.

Measurements are written by `zcl_ave_acr_workflow=>prepare_code_review` (per part) into `zif_ave_acr_types=>ty_saved_payload-timings`.

#### `zcl_ave_acr_stats`

Computes code-review statistics from diff operations.

- `from_diff`: counts insertions, deletions, modifications, hunk counts, and optional per-author blame stats.
- `is_blank_hunk`: returns true when a hunk contains only whitespace.
- `add_blame`: private helper that increments per-author insertion/modification/hunk counters.

#### `zcl_ave_acr_report`

Builds the Code Review Report HTML page.

- `to_html`: renders developer totals, reviewer totals, object/class groups, approval/decline status, and report navigation links.
- `esc`: private HTML-escaping helper.

#### `zcl_ave_acr_precompute`

Precomputes Code Review data for one changed part (or expands class into parts).

- `precompute_part`: loads versions, selects diff pair, computes diff+HTML, optional blame, hunks/blame stats, and updates per-object caches (`mt_diff_cache`, `mt_hunk_info`, `mt_acr_stats`) plus diagnostics.
- `precompute_class_parts`: expands a class into reviewable technical parts and calls `precompute_part` for each part.

Generated code is excluded from review in two ways, both decided in `zcl_ave_acr_prepare`: `is_sap_generated_author` (version author `SAP*`, e.g. function-group framework includes) and `is_generated_class` (generated Gateway/SEGW classes `*_MPC`, `*_MPC_EXT` and `*_DPC`; `*_DPC_EXT` holds hand-written code and stays reviewable). The class check runs in `zcl_ave_acr_workflow=>prepare_code_review`, in `precompute_part`, in `zcl_ave_acr_metrics=>collect` and in the Prepare picker; `zcl_ave_acr_state=>apply_saved_payload` also drops such objects from reviews saved before the exclusion existed.

**A deleted object stays visible and is never reviewed.** **VRSD/VRSS survive a deletion by design** (that is how a deleted object can still be retrieved from version management), so a program that no longer exists still carries its full version history; without an existence check the newest of those versions was paired against nothing and the whole source shown as freshly written, approvable code — 136 green lines of a program SE38 reports as non-existent.

It remains transport content, so it keeps its row and its colour: `build_parts_list` runs the existence check in code review too (it used to assume `abap_true` there), so the part is red in the parts list like anywhere else, and the object report colours what it always coloured.

Nothing behind that row is computed. The rule is `zcl_ave_acr_prepare=>is_deleted_object` (which asks `zcl_ave_popup_data=>check_part_exists`), enforced in `prepare_code_review` and its estimate loop, in `count_preparable_parts`, in `zcl_ave_acr_metrics=>collect`, in the Prepare picker (not offered for selection, like a generated class) and in `precompute_part` — the last one matters most, because parts coming out of a class or function-group expansion (a deleted method, the sections of a deleted class) never passed through the parts list. Each skip is logged as `SKIP … (deleted, versions kept)`. Reviews saved while the object still existed are left alone: unlike a generated class, what was reviewed back then did happen.

A third, line-level rule works independently of the `ignore_generated` flag: `is_generated_ts_line` / `strip_generated_ts_diff` collapse a `-`/`+` pair of generator boilerplate into an unchanged line — the SEGW header (`has been generated on … in client …`) and the table maintenance generator header (`generation date:`, `view maintenance generator version:`). Both the review diff and the retrofit diff are stripped with it, so a re-generated maintenance view cannot be ignored in review and still surface as a moving violation.

#### `zcl_ave_acr_renderer`

Renders reusable Code Review HTML fragments.

- `render_hunk_actions_html`: renders approve/decline/undo/comment/AI links for a hunk.
- `render_hunk_comments_html`: renders persisted hunk comments and decline notes.
- `normalize_diff_html`: collapses two-pane diff rows for single-pane review screens.
- `build_review_help_html`: renders the ZAVE_REVIEW setup help page.

#### `zcl_ave_acr_note_dlg`

Non-blocking SAP GUI text dialog for decline notes.

- `constructor`: stores title, hunk key, and optional existing note.
- `show`: creates the dialog container and text editor, pre-fills existing note, and focuses the editor.
- `on_box_close`: reads the note, raises `saved` when non-empty or `cancelled` when empty, then closes the dialog.

#### `zcl_ave_acr_overview`

Builds code-review overview HTML fragments used by the popup.

- `build_object_report_html`: renders the transport object overview, saved-review state, task counts, authors, dates, and row status.
- `build_tr_task_popup_html`: renders the TR/task drilldown popup content for one object part.
- `build_recalc_picker_html`: renders the Prepare/Recalc object picker page.
- `has_saved_stat`: checks whether a saved review contains stats for a part or class aggregate.

#### `zcl_ave_ai_api`

The provider call itself, self-contained: no SM59 destination and no customizing table.

- `providers`: the hard-coded provider list (id, base URL including the version segment, wire format) — Anthropic plus the OpenAI-compatible hosts (OpenAI, Gemini, Mistral, Groq, Cerebras, OpenRouter, NVIDIA). Feeds the `P_PROV` listbox.
- `base_url` / `wire_of`: URL and wire format of one provider id; an unknown id is treated as OpenAI-compatible.
- `ask`: `CL_HTTP_CLIENT=>CREATE_BY_URL` with the STRUST SSL id (`P_SSLID`, default `ANONYM`), provider headers, payload and answer parsing per wire format. `P_URL` overrides the endpoint completely; empty means base URL + `/messages` or `/chat/completions`. The logon popup is disabled so a 401 returns the provider's JSON error instead of a password prompt.
- `list_models`: `GET <base>/models` → model ids, the F4 help of `P_MODEL`.

#### `zcl_ave_acr_ai`

AI helper methods for code-review prompts, comments, anchors, and persisted summaries.

Every prompt states its own scope and legend — whether the model sees only the changed blocks or the full source, and that `+` is a line of the new version, `-` one of the previous version, both together a modification. `gv_last_prompt_text` holds the plain text of the page built last, which is what `zcl_ave_popup=>save_ai_prompt` (frontend file) and `copy_ai_prompt` (clipboard) hand out; the page renders them as the Save/Copy buttons via `sapevent:promptsave~0` / `sapevent:promptcopy~0`.

- `build_hunk_prompt`: builds the LLM prompt for one changed hunk.
- `build_prompt_page_html`: renders the AI prompt page for a set of visible hunks, in two variants driven by `iv_compact` — the changed blocks alone ("AI prompt diff") or the whole source of every touched object with the changes marked ("AI prompt full"). The button decides, not the Compact toggle: `zcl_ave_popup=>show_ai_prompt( iv_full )` passes `xsdbool( iv_full = abap_false )`, and `sapevent:aipromptfull~0` always opens the page instead of calling the API.
- `get_hunk_comment`: finds the latest AI assistant comment for a hunk.
- `render_summary_html`: renders a saved AI object summary.
- `save_summary`: stores or replaces the AI summary thread for an object.

### Main Popup/UI Class

#### `zcl_ave_popup`

Main SAP GUI orchestrator. This class is large and currently mixes layout, ALV events, HTML rendering integration, version loading, diff display, review state, persistence, and code-review navigation. It is the primary refactoring candidate.

Public methods:

- `constructor`: stores object type/name and applies popup settings.
- `show`: creates and displays the main popup workflow.

Layout/build methods:

- `build_layout`: creates the main dialog, splitters, containers, and toolbar area.
- `build_parts_list`: loads object parts and enriches them with display/existence/line-count data.
- `build_html_viewer`: creates the HTML/source viewer area.
- `create_parts_alv`: configures the parts ALV grid and events.
- `create_versions_alv`: configures the versions ALV grid and events.
- `create_html_viewer`: creates the `cl_gui_html_viewer`.
- `build_versions_grid`: builds the version-list grid.
- `switch_pane_layout`: toggles between split and focused HTML layouts.
- `refresh_parts`: refreshes the parts ALV.
- `refresh_vers`: refreshes the version ALV.
- `update_ver_colors`: updates version row colors according to selected/viewed versions.

Parts/version event handlers:

- `handle_parts_toolbar`: adds custom buttons to the parts ALV toolbar.
- `handle_parts_command`: handles parts ALV user commands.
- `handle_parts_dblclick`: opens parts, class drill-in, or report rows on double-click.
- `handle_vers_toolbar`: adds version-grid toolbar actions.
- `handle_vers_command`: handles version-grid commands such as diff/source toggles.
- `handle_vers_dblclick`: opens source or diff for a selected version row.
- `on_toolbar_click`: handles global toolbar commands.
- `on_box_close`: closes the main popup.
- `on_help_box_close`: closes the review help popup.
- `on_sapevent`: handles HTML viewer `sapevent:` actions for review/navigation.

Version/diff logic:

- `get_class_parts`: returns class parts as popup part rows.
- `load_versions`: loads and enriches versions for the currently selected part.
- `show_source`: renders one source version.
- `show_code_source`: switches to the ABAP editor for large single-version source display.
- `show_versions_diff`: loads two sources, computes/caches diff HTML, and renders it.
- `auto_show_diff_or_source`: avoids auto-diff for very large new sources.
- `set_html`: loads HTML into the viewer and switches the display to diff/report mode.

Review persistence/state:

- `has_review_table`: checks whether `ZAVE_REVIEW` exists (now in `zcl_ave_acr_repository`); called by `show` when a review opens, which pops the setup help instead of the review failing to save later.
- `load_review_payload`: reads a saved review payload for a transport.
- `load_review_from_db`: restores saved review state from the DB table.
- `save_review_to_db`: serializes and saves review state. There is no Save button any more — every state change saves silently (approve/decline/undo/comment, Prepare, Recalc, AI), so a failed silent save reports itself once per session through `mv_save_failed_told`.
- `sanitize_review_state`: removes impossible/obsolete approve/decline/note state.
- `collect_report_status`: collects approved and declined hunk keys for report rendering.
- `get_reviewer_stats`: aggregates reviewer approve/decline totals.
- `format_timestamp`: formats saved/review timestamps.

Review rendering and actions:

- `render_decline_thread_html`: renders the discussion/decline-note thread for one hunk.
- `render_hunk_actions_html`: renders approve/decline/edit controls for one hunk.
- `render_comment_links`: renders comment/action links for a hunk.
- `render_hunk_action_meta`: renders metadata for the latest hunk action.
- `get_hunk_global_action`: determines the global approve/decline state for a hunk.
- `get_last_own_comment`: finds the current user's latest comment for a hunk.
- `set_hunk_action`: records approval/decline state for a hunk.
- `clear_hunk_action`: removes approval/decline state for a hunk.
- `is_own_hunk`: checks whether a hunk belongs to the current user.
- `build_review_help_html`: builds help content for the code-review UI.
- `show_review_help_popup`: opens the review help dialog.

Code-review report workflow:

- `prepare_code_review`: precomputes diffs/statistics for all or selected parts and persists the result.
- `cr_precompute_class_parts`: precomputes review data for all relevant class parts.
- `cr_precompute_part`: precomputes review data for one part.
- `inject_approve_btn`: injects approve/decline controls into rendered diff HTML.
- `acr_approve_cell`: renders inline approve/decline cell content.
- `acr_approve_fixed`: renders fixed-position approve controls.
- `build_approveall_btn`: renders an approve-all button for an object.
- `regen_acr_report`: rebuilds `mv_cr_report_html`.
- `build_cr_object_report_html`: builds the initial object list/report for a transport.
- `refresh_rpt_row`: updates the synthetic report row in the parts list.
- `delete_and_recalc_selected`: deletes cached review data for selected objects and recalculates.
- `show_recalc_picker`: renders the object picker for recalculation.
- `open_saved_code_review`: opens a persisted review without recomputing.

Code-review navigation:

- `maximize_html`: gives the HTML/report pane full focus.
- `back_to_report`: returns from an object/user view to the report.
- `show_class_objects`: opens all review objects for a class.
- `show_user_declines`: shows declined hunks for a developer or reviewer.
- `show_moving_violations`: the dedicated read-only page of retrofit hunks.

Retrofit (moving-violation) hunks are carried in `mt_hunk_info` with a non-initial `retrofit` field and appear in three places, never approvable: the dedicated page, the object view (`zcl_ave_acr_part_view=>build_violations_html`, after the reviewable blocks) and the class view (`show_class_objects`, where the red warning replaces the approve/decline row). The badge wording follows `change_kind`: `deleted` → will be deleted, `added` → will be re-inserted, otherwise overwritten. The developer/reviewer views keep filtering them out — a violation has no reviewer.
- `open_cr_part`: opens the review diff for one part.
- `rerender_cr_current`: refreshes the currently opened review hunk/object view.
- `rerender_cr_user_view`: refreshes the current user-decline/reviewer view.
- `on_note_dlg_saved`: receives note dialog save events and records decline notes.
- `on_note_dlg_cancelled`: receives note dialog cancel events and clears pending state.

## HTML Simulator

`html_simulator/` contains a browser-side port of the diff algorithm for fast iteration without a SAP system. Open `html_simulator/index.html` directly in a browser; no build step is needed.

`html_simulator/diff.js` mirrors `zcl_ave_popup_diff` method-by-method. Keep both in sync when changing the diff algorithm.

## Refactoring Notes

- `zcl_ave_popup` is the largest risk area: split candidates are layout/controller, version selection, diff rendering orchestration, review state/persistence, and review report/navigation.
- `zcl_ave_popup_diff`, `zcl_ave_popup_html`, `zcl_ave_popup_data`, `zcl_ave_acr_stats`, and `zcl_ave_acr_report` are already extraction points. Prefer extending these before adding more logic to `zcl_ave_popup`.
- Preserve generated/derived files. Do not edit `z_ave_standalone.prog.abap`; regenerate it after source changes.
