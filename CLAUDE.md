# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AVE (ABAP Versions Explorer) is an SAP GUI ABAP program for browsing and comparing object versions in a SAP system. It supports Programs/Includes, Classes, Function Modules, Interfaces, Transport Requests/Tasks, and Packages.

## Generating the Standalone File

`src/z_ave_standalone.prog.abap` is **auto-generated** — never edit it directly.

To regenerate it after changing source files, run from the repo root:

```bash
bash generate_standalone.sh
# or on Windows: generate_standalone.bat
```

This uses [abapmerge](https://github.com/larshp/abapmerge) to merge all source files into a single deployable program. The tool must be installed and available on `PATH`.

## Architecture

The entry point is `src/z_ave.prog.abap` (selection screen + bootstrap). All business logic lives in the `src/zcl_ave_*` classes.

**Object handler layer** — each ABAP object type has a dedicated handler class implementing `zif_ave_object`:
- `zcl_ave_object_prog` — Programs / Includes
- `zcl_ave_object_clas` — Classes
- `zcl_ave_object_intf` — Interfaces
- `zcl_ave_object_func` — Function Modules
- `zcl_ave_object_tr` — Transport Requests / Tasks
- `zcl_ave_object_pack` — Packages

`zcl_ave_object_factory` instantiates the correct handler by type string (`PROG`, `CLAS`, `INTF`, `FUNC`, `TR`, `DEVC`).

**Version / diff layer:**
- `zcl_ave_version` — wraps a single VRSD record; loads source via `SVRS_GET_REPS_FROM_OBJECT`
- `zcl_ave_versno` — version-number utilities
- `zcl_ave_vrsd` — VRSD table wrapper

**Display layer** (`zcl_ave_popup` orchestrates):
- `zcl_ave_popup_diff` — diff/pairing algorithm
- `zcl_ave_popup_html` — HTML renderer for the diff output
- `zcl_ave_popup_data` — data loading helpers

**Exception:** `zcx_ave` is the single exception class used throughout.

**Shared types:** `zif_ave_popup_types` holds types shared between popup sub-classes.

## HTML Simulator

`html_simulator/` contains a browser-side port of the diff algorithm for fast iteration without a SAP system. Open `html_simulator/index.html` directly in a browser (no build step needed).

`html_simulator/diff.js` mirrors `zcl_ave_popup_diff` method-by-method. **Keep both in sync** when changing the diff algorithm.
