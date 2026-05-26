# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AVE (ABAP Versions Explorer) is an SAP GUI ABAP program for browsing, comparing, and reviewing object versions in a SAP system. It supports Programs/Includes, Classes, Function Modules, Interfaces, CDS DDL Sources, Transport Requests/Tasks, and Packages.

Do not analyze or edit `src/z_ave_standalone.prog.abap` directly. It is a generated build artifact.

Agent rule: DON'T analyse and change standalone (`src/z_ave_standalone.prog.abap`).

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
- `populate_details`: reads request text/status from `E070` and `E07T`.
- `get_task_for_object`: normalizes object type/name and delegates to task lookup.
- `get_latest_task_for_object`: finds the latest matching task in `E071`/`E070`, constrained by version timestamp when supplied.

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

- `compute_diff`: computes line-level LCS diff; uses a low-memory look-ahead algorithm for huge files.
- `char_diff_html`: renders inline character-level differences for one old/new line pair.
- `has_common_chars`: decides whether two changed lines are similar enough to pair.
- `count_edit_runs`: estimates how many edit runs exist between two line middles.
- `build_blame_map`: replays diffs across versions and attributes added/deleted lines to authors.
- `collapse_token_ops`: private helper that collapses noisy character ops into whole-token replacements.

Keep `html_simulator/diff.js` in sync with the pairing/diff behavior here.

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
- `check_part_exists`: checks whether a part exists via `TADIR`, `SEOCOMPO`, or built-in pseudo-part rules.
- `get_type_text`: returns cached SAP object-type text.
- `load_type_cache`: fills the object-type cache from `TRINT_OBJECT_TABLE`.
- `check_class_has_author`: checks whether any class part has substantive changes.
- `build_versions_for_check`: builds a newest-first version list with transport function metadata.
- `is_substantive_user_change`: compares a target version with the nearest prior K-type version.
- `remove_duplicate_versions`: removes consecutive versions with identical source, preserving required baselines/current transport rows.
- `get_active_line_count`: reads the active include/source and returns its line count.
- `get_ver_source`: reads a version source, creating a synthetic VRSD row when needed.

### Code Review Helpers

#### `zcl_ave_acr_stats`

Computes code-review statistics from diff operations.

- `from_diff`: counts insertions, deletions, modifications, hunk counts, and optional per-author blame stats.
- `is_blank_hunk`: returns true when a hunk contains only whitespace.
- `add_blame`: private helper that increments per-author insertion/modification/hunk counters.

#### `zcl_ave_acr_report`

Builds the Code Review Report HTML page.

- `to_html`: renders developer totals, reviewer totals, object/class groups, approval/decline status, and report navigation links.
- `esc`: private HTML-escaping helper.

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

#### `zcl_ave_acr_ai`

AI helper methods for code-review prompts, comments, anchors, and persisted summaries.

- `build_hunk_prompt`: builds the LLM prompt for one changed hunk.
- `build_prompt_page_html`: renders the full/compact AI prompt page for a set of visible hunks.
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

- `has_review_table`: checks whether `ZAVE_REVIEW` exists.
- `load_review_payload`: reads a saved review payload for a transport.
- `load_review_from_db`: restores saved review state from the DB table.
- `save_review_to_db`: serializes and saves review state.
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
