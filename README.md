# AVE — ABAP Versions Explorer & Code Reviewer

SAP ABAP version explorer and code review tool for SAP GUI.

<img width="1082" height="614" alt="AVE main window" src="https://github.com/user-attachments/assets/cd13979f-c14c-4fd9-b2d4-87c057561ce5" />

---

## Table of Contents

1. [Why AVE](#1-why-ave)
2. [Installation](#2-installation)
3. [Selection Screen](#3-selection-screen)
   - [3.1 Mode: Code Review vs Versions Explorer](#31-mode-code-review-vs-versions-explorer)
   - [3.2 Object types](#32-object-types)
   - [3.3 Layout / UI preferences](#33-layout--ui-preferences)
   - [3.4 Data filters](#34-data-filters)
   - [3.5 AI configuration](#35-ai-configuration)
4. [Versions Explorer](#4-versions-explorer)
   - [4.1 The three panes](#41-the-three-panes)
   - [4.2 Toolbar buttons](#42-toolbar-buttons)
   - [4.3 Program / Include / Function Module](#43-program--include--function-module)
   - [4.4 Class and Interface](#44-class-and-interface)
   - [4.5 Transport Request / Task](#45-transport-request--task)
   - [4.6 Package](#46-package)
   - [4.7 CDS View, Function Group, DDIC objects](#47-cds-view-function-group-ddic-objects)
   - [4.8 Comparing arbitrary versions](#48-comparing-arbitrary-versions)
   - [4.9 Blame](#49-blame)
   - [4.10 Remote system comparison](#410-remote-system-comparison)
5. [Code Review](#5-code-review)
   - [5.1 Preparing a review](#51-preparing-a-review)
   - [5.2 The Metrics page](#52-the-metrics-page)
   - [5.3 The report](#53-the-report)
   - [5.4 Reviewing a hunk](#54-reviewing-a-hunk)
   - [5.5 Saving and reopening a review](#55-saving-and-reopening-a-review)
   - [5.6 What is excluded from review](#56-what-is-excluded-from-review)
6. [AI-assisted review](#6-ai-assisted-review)
7. [Transport Observer (Z_AVE_OBSERVER)](#7-transport-observer-z_ave_observer)
8. [ZAVE_REVIEW table setup](#8-zave_review-table-setup)
9. [HTML diff simulator](#9-html-diff-simulator)
10. [Author & links](#10-author--links)

---

## 1. Why AVE

First of all — the Eclipse version is the best.

But I want a very fast interface for some cases:

- I don't want to see the list of all the same versions because of using TOC (Transport of Copies)
- I **do** want to see the real object owner, especially when a Transport of Copies is used
- fast navigation within Transport Requests / Tasks
- fast navigation within methods inside a class
- fast navigation within objects inside a package
- detecting non-existent objects in Transport Requests / Tasks

And on top of that, AVE grew a second mode: a **code review workflow** — approve/decline per hunk, comments, per-author and per-reviewer statistics, persistence in a Z table, and optional AI review of a hunk.

---

## 2. Installation

Two ways:

**a) abapGit** — clone `https://github.com/ysichov/AVE` into a package. This installs the report `Z_AVE`, the observer `Z_AVE_OBSERVER` and all `ZCL_AVE_*` classes.

**b) Standalone report** — copy `src/z_ave_standalone.prog.abap` into one new report. It is a generated single-file merge of the whole tool; nothing else is needed.

For the code review mode you additionally need the table `ZAVE_REVIEW` — see [section 8](#8-zave_review-table-setup). Everything else works without it.

---

## 3. Selection Screen

> 📸 **SCREENSHOT PLACEHOLDER — SELECTION SCREEN**
> The full selection screen of Z_AVE with all blocks: Main features, object types, Layout, Data filters, AI config.

### 3.1 Mode: Code Review vs Versions Explorer

| Parameter | Meaning |
|---|---|
| `P_CR` | **Code Review** mode — the tool prepares diffs of a transport scope and opens the review report. |
| `P_VE` | **Versions Explorer** mode — the classic version browsing/diff mode. |
| `S_TASK` | Transport request(s) / task(s) that define the review scope. |
| `P_ITASK` | Include the tasks of the selected request(s). |
| `P_SYS` | Remote system name — adds a remote baseline version for comparison (TMS). |
| `P_BLAME` | Compute blame (who wrote each line). Costly on long histories — see [4.9](#49-blame). |
| `P_IGNGEN` | Ignore generated code (see [5.6](#56-what-is-excluded-from-review)). |

### 3.2 Object types

Choose one object type, enter its name and press **Enter**.

| Radio button | Parameter | Object |
|---|---|---|
| TR/Task | `S_TASK` | Transport request or task |
| Program/Include | `P_PROG` | Report, include |
| Class | `P_CLAS` | Class (or interface) |
| Function Module | `P_FUNC` | Single function module |
| Package | `P_PACK` | Development package |
| CDS View | `P_DDLS` | DDL source |
| Function Group | `P_FUGR` | Whole function group |
| Table (TABD) | `P_TABD` | DDIC table |
| Domain | `P_DOMA` | DDIC domain |
| Data Element | `P_DTEL` | DDIC data element |

> 📸 **SCREENSHOT PLACEHOLDER — OBJECT TYPE BLOCK**
> Close-up of the object type radio-button block with a name filled in.

### 3.3 Layout / UI preferences

| Parameter | Meaning |
|---|---|
| `P_CMPCT` | **Compact** — show only changed fragments instead of the full source with changes. |
| `P_PANE` | **2-Pane** view (old/new side by side) instead of inline. |
| `P_LAYOUT` | Standard split layout (tables + viewer) vs maximized viewer. |

### 3.4 Data filters

| Parameter | Meaning |
|---|---|
| `P_DATEFR` | Date from which versions are shown. |
| `P_USER` | Highlight this user's last changed objects in green. |
| `P_RMDP` | Remove duplicate versions (versions with identical source). |
| `P_NTOC` | Hide TOC (transport of copies) versions. |
| `P_ICASE` | Case- and indentation-insensitive diff. |

### 3.5 AI configuration

| Parameter | Meaning |
|---|---|
| `P_ANTH` / `P_OAI` | Provider: Anthropic or OpenAI. |
| `P_DEST` | RFC destination (SM59, type G) pointing to the API host. |
| `P_MODEL` | Model id. |
| `P_APIKEY` | API key. |
| `P_MAXTOK` | Output cap per request. Too low a cap truncates a JSON answer mid-way and nothing parses. |
| `P_PPATH` | Frontend folder with review profiles. |
| `P_PROF` | Review profile name — `<profile>.md` (system prompt) plus optional `<profile>.json` (output schema). |

`P_PPATH` and `P_PROF` have F4 help: folder browse and a list of the `*.md` files found there.

---

## 4. Versions Explorer

### 4.1 The three panes

- **Parts list** (top left) — the versionable parts of the object: one row for a program, all sections + methods of a class, all objects of a transport or package.
- **Versions list** (bottom left) — the versions of the selected part, with date, time, author, real object owner, request, task and request description.
- **HTML viewer** (right) — the rendered source or diff.

By default AVE opens the difference between the latest version (base) and the previous one.
The list does not include versions without changes — that is a very comfortable thing.

> 📸 **SCREENSHOT PLACEHOLDER — THREE PANES**
> The main window with all three panes annotated: parts, versions, viewer.

### 4.2 Toolbar buttons

**Main toolbar**

| Button | Effect |
|---|---|
| Refresh | Reloads parts and versions. |
| Show Diff / Show Vers | Diff of two versions vs plain single-version source. |
| 2-Pane / Inline | Side-by-side vs inline rendering. |
| Compact / Full | Only changes vs full source with changes highlighted. |
| Blame / Blame ON | Who wrote each line. |
| Maximize View | Hides the two tables and expands the HTML viewer. |
| Debug | Diagnostic page: diff operations and pairing decisions. |
| 📖 | Opens this documentation in the browser. |

**Versions grid toolbar**

| Button | Effect |
|---|---|
| Diff prev / Diff any | Compare with the previous version, or with a chosen base version. |
| Set Base | Marks the selected version as the base for "Diff any". |
| TOCs on / TOCs off | Show or hide transport-of-copies versions. |
| Dups on / Dups off | Show or hide versions with identical source. |
| Case/ind on / off | Case- and indentation-insensitive comparison. |

> 📸 **SCREENSHOT PLACEHOLDER — TOOLBARS**
> Close-up of the main toolbar and of the version grid toolbar.

### 4.3 Program / Include / Function Module

Only one part exists, so the parts table is not needed — AVE goes straight to the version list and opens the latest diff in the configured mode.

> 📸 **SCREENSHOT PLACEHOLDER — PROGRAM 2-PANE**
> Program diff in 2-pane mode.

Pressing the **2-Pane** toggle switches to inline mode.

> 📸 **SCREENSHOT PLACEHOLDER — PROGRAM INLINE**
> The same diff in inline mode.

Double-click on any version shows the difference between it and the previous one.

### 4.4 Class and Interface

The parts list shows all class includes: the sections (Public, Protected, Private), the local/test includes and **one row per method**. So you can navigate fast to any part of the class.

Section includes are diffed declaration by declaration, not line by line: SAP regenerates them in an arbitrary order, and a plain line diff would report every moved declaration as a delete plus an insert far away from each other.

> 📸 **SCREENSHOT PLACEHOLDER — CLASS PARTS**
> Class opened in AVE: sections + method list on the left, method diff on the right.

### 4.5 Transport Request / Task

Shows all TR/Task objects, marking **non-existing objects in red**.

- Double-click on a supported object shows its code and version list.
- Double-click on a class switches to the class objects view (see [4.4](#44-class-and-interface)).
- The **Back** button returns from the class object list to the TR/Task object list.

The real object owner is resolved even when the version was recorded under a transport of copies — a T-copy `korrnum` is resolved back to its parent K request.

> 📸 **SCREENSHOT PLACEHOLDER — TR OBJECT LIST**
> Transport request opened: object list with red rows for missing objects.

### 4.6 Package

Shows all package objects, marking non-existing objects in red. Navigation works exactly as for a transport request.

> 📸 **SCREENSHOT PLACEHOLDER — PACKAGE**
> Package opened: object list of the package.

### 4.7 CDS View, Function Group, DDIC objects

- **CDS View (DDLS)** — the DDL source is read through the SVRS TLOGO controller and rendered with lightweight syntax highlighting.
- **Function Group** — expands to all its includes and function modules.
- **Table / Domain / Data Element** — version history of the DDIC definition.

> 📸 **SCREENSHOT PLACEHOLDER — CDS DIFF**
> A CDS view diff with syntax highlighting.

### 4.8 Comparing arbitrary versions

To compare any two versions, press the toggle button **Diff prev** — it switches to **Diff any**.
Then select a version and press **Set Base**.

> 📸 **SCREENSHOT PLACEHOLDER — SET BASE**
> Version grid with "Diff any" active and a base version marked.

After that, double-clicking any other version compares it with the base version.

Pressing **Maximize View** hides the tables so only the version sources remain.

> 📸 **SCREENSHOT PLACEHOLDER — MAXIMIZED VIEW**
> Diff filling the whole window after Maximize View.

### 4.9 Blame

With blame enabled, AVE replays the diffs across the version range and attributes every line to the author who last touched it, drawing separators between blame blocks.

Blame is not free: it replays all diffs of the reviewed range, so its cost grows with the number of versions. In code review mode the cost is estimated **twice**, with and without blame, so you can see the price before switching the toggle — see [5.2](#52-the-metrics-page).

> 📸 **SCREENSHOT PLACEHOLDER — BLAME**
> Diff view with blame authors and separators visible.

### 4.10 Remote system comparison

Fill `P_SYS` with a TMS system name and AVE adds a remote baseline row to the version list, so a local version can be diffed directly against what is active in the other system.

---

## 5. Code Review

Select **Code Review** on the selection screen, enter one or more transport requests / tasks in `S_TASK` and press Enter.

### 5.1 Preparing a review

AVE first shows the **object overview** of the scope: every object of the request, its tasks, authors, dates and row status. Nothing is computed yet.

> 📸 **SCREENSHOT PLACEHOLDER — CR OVERVIEW**
> Code review object overview page for a transport request.

From there:

| Action | Meaning |
|---|---|
| **Prepare** | Computes the diff, hunks and statistics for the whole scope. |
| **Prepare selected** | The same, for the objects picked in the picker page. |
| **Prepare band L / LM** | Prepares only the light (L) or light+medium (LM) objects — see the Metrics page. |
| **Metrics** | Opens the cost estimate before computing anything. |
| **Recalc** | Deletes cached data for the selected objects and recomputes them. |

During a long Prepare run, the screen refreshes at most every 10 seconds. Up to 50 objects the full report is redrawn; above that a one-line progress page is shown instead, because rebuilding the full report renders every object collected so far and its cost grows with the square of the object count.

> 📸 **SCREENSHOT PLACEHOLDER — PREPARE PROGRESS**
> Progress page during a long Prepare run with the remaining-time estimate.

### 5.2 The Metrics page

The Metrics page answers one question: *can this request be prepared in the dialog, or does it need a background run?*

For every reviewable part it shows the number of versions, the versions in scope, the active line count, whether the part is already cached, an estimated duration and a weight band (L / M / H). Every part is estimated twice — with and without blame — so the price of blame is visible before the toolbar toggle is touched.

Two columns are deliberately separate:

- **Versions** — the object's complete VRSD history; this drives the metadata load.
- **In scope** — only the versions of the reviewed request; this drives the blame replay.

A time shown with a leading `~` is still a model estimate. Without it, it is what the last Prepare actually took, and the *Source* column then names the prediction and how far off it was — the model calibrates itself from previous runs.

> ⚠️ The page warns when an S/R **task** is the selected scope: version trimming is skipped there, so the metadata load covers the full history.

> 📸 **SCREENSHOT PLACEHOLDER — METRICS**
> Metrics page with the per-part table, weight bands and the Prepare band buttons.

### 5.3 The report

The report page aggregates the whole review:

- totals per **developer** (insertions, deletions, modifications, hunks),
- totals per **reviewer** (approved / declined),
- one group per object, and one group per class with its parts,
- approval / decline status of each object,
- links to open an object, a class, or all declined hunks of one user.

> 📸 **SCREENSHOT PLACEHOLDER — CR REPORT**
> The Code Review Report page with developer and reviewer totals and the object list.

### 5.4 Reviewing a hunk

Open an object from the report and every changed hunk gets its own action row:

| Link | Effect |
|---|---|
| ✔ approve | Marks the hunk as approved, stamped with your user and time. |
| ✘ decline | Opens a note dialog; the note is stored with the decline. |
| undo | Removes your approval / decline. |
| comment | Adds a comment to the hunk thread. |
| AI | Sends the hunk to the configured LLM — see [section 6](#6-ai-assisted-review). |

There is also **Approve all** per object. Approvals and comments are shown inline in the diff, in a thread under the hunk.

> 📸 **SCREENSHOT PLACEHOLDER — HUNK ACTIONS**
> A diff hunk with the approve/decline/undo/comment/AI links and a comment thread below it.

### 5.5 Saving and reopening a review

**Save** writes the whole review — state plus save history — as one JSON payload into `ZAVE_REVIEW`, one row per transport request. Reopening the same request offers **Open saved review**, which restores everything without recomputing.

Measured durations of each Prepare run are stored with the payload; that is what calibrates the estimates on the Metrics page.

> 📸 **SCREENSHOT PLACEHOLDER — SAVED REVIEW**
> Reopening a saved review.

### 5.6 What is excluded from review

With `P_IGNGEN` set (default), generated code is dropped from the scope:

- versions whose author matches `SAP*` — function-group framework includes and similar,
- generated Gateway/SEGW classes `*_MPC`, `*_MPC_EXT` and `*_DPC`.

`*_DPC_EXT` holds hand-written code and **stays reviewable**. Unchecking the flag brings everything back into the review.

---

## 6. AI-assisted review

Every hunk has an **AI** link, and an object has an AI prompt page that collects all its visible hunks into one prompt.

Configuration lives in the *AI API config* block of the selection screen: provider, RFC destination, model, API key, output cap, and the review profile.

A **review profile** is a pair of files in one frontend folder, matched by name:

```
<profile>.md     system prompt (required)
<profile>.json   output JSON schema (optional)
```

A profile without a schema simply asks for free-form text. The answer is stored as an AI comment in the hunk thread, and object-level answers are persisted as an AI summary with the review.

> 📸 **SCREENSHOT PLACEHOLDER — AI COMMENT**
> A hunk with an AI-generated review comment in the thread.

---

## 7. Transport Observer (Z_AVE_OBSERVER)

`Z_AVE_OBSERVER` is a companion report: it observes workbench (K) transport requests changed or released in a given date range, with package and user filters, and lets you browse the objects of every K request with a quick diff indicator. Clicking an object opens the real diff, rendered by the same engine as AVE itself.

Parameters: date range (`P_FROM` / `P_TO`), package range (`S_PACK`), user range (`S_USER`).

> 📸 **SCREENSHOT PLACEHOLDER — OBSERVER**
> Z_AVE_OBSERVER: request list on the left, object list with change indicators, diff on the right.

---

## 8. ZAVE_REVIEW table setup

The **Save** button can store review data only after a transparent table `ZAVE_REVIEW` exists and is active. The design is deliberately minimal: one row per transport request, the full review with save history in one JSON payload.

| Field | Type | Purpose |
|---|---|---|
| `MANDT` | MANDT | Client field (key) |
| `TRKORR` | TRKORR | Transport request (key) |
| `PAYLOAD` | STRING | Review JSON including current state and save history |

Steps:

1. Create transparent table `ZAVE_REVIEW`.
2. Make `MANDT` and `TRKORR` key fields.
3. Add field `PAYLOAD` of type `STRING`.
4. Activate the table. No ZIP or compression is needed.
5. Return to AVE and press **Save** again.

AVE shows this same help page automatically if you press Save without the table.

---

## 9. HTML diff simulator

`html_simulator/` contains a browser-side port of the diff algorithm, for trying out the diff behaviour without a SAP system. Open `html_simulator/index.html` directly in a browser — no build step needed.

And as a bonus, a standalone HTML/JS local comparer: https://github.com/ysichov/Diff

> 📸 **SCREENSHOT PLACEHOLDER — SIMULATOR**
> html_simulator/index.html open in a browser with two sources compared.

---

## 10. Author & links

Written by **Yurii Sychov**

- e-mail: ysichov@gmail.com
- blog: https://ysychov.wordpress.com/blog/
- LinkedIn: https://www.linkedin.com/in/ysychov/
- GitHub: https://github.com/ysichov/AVE

Inspired by [abapTimeMachine](https://github.com/abapinho/abapTimeMachine), Eclipse ADT, GitHub and all other similar tools.
