# AVE — ABAP Versions Explorer & Code Reviewer

SAP ABAP version explorer and code review tool for SAP GUI.

<img width="1082" height="614" alt="AVE main window" src="https://github.com/user-attachments/assets/cd13979f-c14c-4fd9-b2d4-87c057561ce5" />

## What AVE gives you

- **A whole transport at once** — open a request, task, package, class or function group and review everything in it in one screen, instead of opening object after object in SE80 or Eclipse.
- **Objects that do not exist are red** — a request listing something nobody can find shows it before it is released.
- **Any two versions compared** — side by side or inline, the full source or only the changed blocks.
- **No noise** — reformatting and case, generator timestamps, generated `*_MPC` / `*_DPC` classes, SAP framework includes, empty class sections, blank blocks, repeated and Transport-of-Copies versions, and lines that merely moved are all left out. What remains is what a person wrote.
- **Class sections read as they were written** — declarations are paired by signature, so a method that only moved is not shown as deleted here and added there.
- **The real author** — resolved through Transports of Copies, together with the request and task that actually carry the change.
- **Blame** — who wrote each line, and when.
- **Code review with a memory** — approve or decline each block (never your own), leave comments and decline notes, see totals per developer and per reviewer, close the session and reopen the review later.
- **Moving Violations** — what your request will overwrite, or bring back, in another development system once it is moved there.
- **AI, if you want it** — send a block or a whole object to an LLM from inside SAP GUI, or copy out a ready-made prompt.
- **Fast navigation** — every method of a class, every object of a package or request, one click away.

---

## Table of Contents

1. [Why AVE](#1-why-ave)
   - [1.1 A change is a transport, not an object](#11-a-change-is-a-transport-not-an-object)
   - [1.2 The noise problem](#12-the-noise-problem)
   - [1.3 Class sections come back in random order](#13-class-sections-come-back-in-random-order)
   - [1.4 Who really made the change](#14-who-really-made-the-change)
   - [1.5 The other development system](#15-the-other-development-system)
   - [1.6 A review, not just a view](#16-a-review-not-just-a-view)
2. [Installation](#2-installation)
3. [Selection screen](#3-selection-screen)
   - [3.1 Main features](#31-main-features)
   - [3.2 Object types](#32-object-types)
   - [3.3 Layout / UI preferences](#33-layout--ui-preferences)
   - [3.4 Data filter options](#34-data-filter-options)
   - [3.5 AI API config](#35-ai-api-config)
   - [3.6 Diagnostic/Debug](#36-diagnosticdebug)
4. [Versions Explorer](#4-versions-explorer)
   - [4.1 The three panes](#41-the-three-panes)
   - [4.2 Toolbar buttons](#42-toolbar-buttons)
   - [4.3 Program / Include / Function Module](#43-program--include--function-module)
   - [4.4 Class](#44-class)
   - [4.5 Transport Request / Task](#45-transport-request--task)
   - [4.6 Package](#46-package)
   - [4.7 Function Group, CDS View, DDIC objects](#47-function-group-cds-view-ddic-objects)
   - [4.8 Comparing arbitrary versions](#48-comparing-arbitrary-versions)
   - [4.9 Blame](#49-blame)
   - [4.10 Remote system version check](#410-remote-system-version-check)
   - [4.11 Long-running operations](#411-long-running-operations)
5. [Code Reviewer](#5-code-reviewer)
   - [5.1 Object overview](#51-object-overview)
   - [5.2 Metrics — what a Prepare will cost](#52-metrics--what-a-prepare-will-cost)
   - [5.3 Preparing a review](#53-preparing-a-review)
   - [5.4 The report](#54-the-report)
   - [5.5 Reviewing a hunk](#55-reviewing-a-hunk)
   - [5.6 Developer and reviewer views](#56-developer-and-reviewer-views)
   - [5.7 Moving Violations](#57-moving-violations)
   - [5.8 Saving and reopening a review](#58-saving-and-reopening-a-review)
   - [5.9 What is excluded from a review](#59-what-is-excluded-from-a-review)
6. [AI-assisted review](#6-ai-assisted-review)
7. [ZAVE_REVIEW table setup](#7-zave_review-table-setup)
8. [Also in this repository](#8-also-in-this-repository)
9. [Author & links](#9-author--links)

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

And the longer answer to the list above: what the standard tools make you do by hand, and what AVE does instead.

### 1.1 A change is a transport, not an object

SE80 version management and Eclipse compare **one object with one of its versions**. A transport request is not one object — it is dozens of programs, classes, methods, function modules, CDS views and table definitions. Reviewing it in the standard tools means opening every object by hand, remembering which ones are already done, and starting over tomorrow.

AVE takes the whole scope as the unit of work: enter a request (or a task, a package, a class, a function group) and you get one list of everything in it, the versions of each part, and the diffs — with the objects that do not exist in the system marked red, so a request listing something nobody can find shows it before the request is released.

### 1.2 The noise problem

A raw line comparison shows everything that differs, and most of it is not a change anybody made. Reviewers learn to scroll past it, and that is exactly how a real change slips through. AVE removes the noise before it reaches the screen:

| Ignored | Why it is not a change |
|---|---|
| Indentation and case | The pretty-printer reformats a whole block nobody touched. One switch, because the comparison folds whitespace and case together. |
| Generator timestamps | The SEGW header (`has been generated on … in client …`) and the table maintenance generator header (`generation date:`, `view maintenance generator version:`) are rewritten by every regeneration — in every system independently. |
| Generated Gateway/SEGW classes | `*_MPC`, `*_MPC_EXT`, `*_DPC` are generated from the model. `*_DPC_EXT` holds hand-written code and stays in the review. |
| SAP-authored includes | Function group framework includes (version author `SAP*`) are written by the system, not by a developer. |
| Empty class sections | A new class always gets all three section includes; the unused ones contain nothing but their own `protected section.` header. |
| New objects that are only comments | A generated stub of comment lines is not something to review. |
| Blank-only blocks | A block whose changed lines are all empty is nothing to look at. |
| Repeated versions | Versions whose source is identical to the previous one, and the Transport-of-Copies versions that create them. |
| Lines that only moved | A block moved elsewhere in the file is not two changes (a deletion and an insertion). |

What is left is what a person wrote.

### 1.3 Class sections come back in random order

The public, protected and private part of a class is stored as a generated include, and SAP regenerates it with the declarations in an arbitrary order. Compare two versions line by line and you get a method that merely moved reported as deleted in one place and added in another — and, worse, the `importing` and parameter lines of one method matched against another method's, which reads as if signatures had changed.

AVE pairs declarations by their signature and aligns the parameters inside a matched declaration by name. Moved declarations disappear from the diff; a changed one shows exactly the parameter that changed.

### 1.4 Who really made the change

With a Transport of Copies in the landscape, the version list names the copy, not the author. AVE resolves a T-copy back to its parent request and looks up the responsible task, so every version shows the developer and the request that actually carries the change.

### 1.5 The other development system

If your landscape has more than one development system — a main one and a project one, say — the retrofit between them is never quite up to date. A request released from one of them can silently overwrite work done in the other, or bring back lines somebody had already deleted, and nobody sees it because everyone is looking at the changed lines, not at the code around them.

Point AVE at the other system and it compares the reviewed source against what is active there, listing everything that will be overwritten or re-inserted when the request is moved. See [Moving Violations](#57-moving-violations).

### 1.6 A review, not just a view

AVE is also a code review workflow: approve or decline every block (never your own), leave comments and decline notes, see totals per developer and per reviewer, and reopen the review later — it lives in one Z table, saved automatically after each action. An LLM can be plugged in, or the prompt copied out to any chat.

---

## 2. Installation

**a) abapGit** — clone `https://github.com/ysichov/AVE` into a package. You get the report `Z_AVE`, the observer report `Z_AVE_OBSERVER` and all `ZCL_AVE_*` classes.

**b) Standalone report** — copy `src/z_ave_standalone.prog.abap` into one new report; it is a generated single-file merge of the whole tool, nothing else is needed. The observer has its own standalone file, `src/z_ave_observer_sa.prog.abap`.

Only the Code Reviewer needs one extra object — the table `ZAVE_REVIEW`, see [section 7](#7-zave_review-table-setup). Everything else runs as is.

---

## 3. Selection screen

The whole selection screen of Z_AVE with contains six blocks: Main features, object type block, Layout/UI preferences, Data filter options, AI API config, Diagnostic/Debug.

### 3.1 Main features

The first block chooses the mode and the review scope.

<img width="1200" height="299" alt="image" src="https://github.com/user-attachments/assets/d6d33946-31f5-483d-8d56-fa9df9720c7d" />


| Field | Parameter | Meaning |
|---|---|---|
| **Code Reviewer** | `P_CR` | Review mode: AVE prepares the diffs of a transport scope and opens the review report. |
| **Versions Explorer** | `P_VE` | Classic mode: browse and compare versions of one object. |
| **TRs for Re-View** | `S_TASK` | One or more requests / tasks — the review scope, and also the object when *TR/Task* is chosen below. |
| **Include Tasks** | `P_ITASK` | Read the objects of the S-tasks belonging to the entered requests too. A request header only carries what was recorded directly on it, so an unreleased K is usually empty while its tasks hold everything. |
| **Remote system Id version check** | `P_SYS` | TMS system id — adds a remote baseline version and switches on the Moving Violations check ([5.7](#57-moving-violations)). |
| **Who is Blame :)** | `P_BLAME` | Compute blame — who wrote each line. Costly on long histories, see [4.9](#49-blame). |

### 3.2 Object types

Choose one object type, enter its name and press **Enter**.

<img width="1208" height="324" alt="image" src="https://github.com/user-attachments/assets/070e12c5-033b-418d-a9f6-a9db3ffd5b5d" />


| Radio button | Parameter | Object |
|---|---|---|
| TR/Task | `S_TASK` | Transport request or task |
| Program/Include | `P_PROG` | Report, include |
| Class | `P_CLAS` | Class |
| FM | `P_FUNC` | Single function module |
| Package | `P_PACK` | Development package |
| CDS View | `P_DDLS` | DDL source |
| Function Group | `P_FUGR` | Whole function group |
| Table | `P_TABD` | DDIC table |
| Domain | `P_DOMA` | DDIC domain |
| Data Element | `P_DTEL` | DDIC data element |

Interfaces have their own handler too — they are opened from a transport request or a package, not from the Class field.

### 3.3 Layout / UI preferences

<img width="1204" height="138" alt="image" src="https://github.com/user-attachments/assets/441077ea-f67e-4fe3-920f-bd517a91fbfe" />


| Field | Parameter | Meaning |
|---|---|---|
| **Compact/Full Text** | `P_CMPCT` | Only the changed fragments, or the full source with the changes highlighted. |
| **2-Pane/Single Pane** | `P_PANE` | Old and new side by side, or one inline pane. |
| **Side-bar/Top-down layout** | `P_LAYOUT` | Where the parts and versions tables sit relative to the viewer. |

### 3.4 Data filter options

<img width="1200" height="222" alt="image" src="https://github.com/user-attachments/assets/0b7f3e44-a608-4db0-b076-c34c5c60f089" />

| Field | Parameter | Meaning |
|---|---|---|
| **From Date** | `P_DATEFR` | Show versions from this date on; the newest predecessor before the date is kept as a baseline. |
| **For user** | `P_USER` | This user's last changed objects are marked green. |
| **Remove the same versions** | `P_RMDP` | Drop consecutive versions with identical source. |
| **Don't show TOCs** | `P_NTOC` | Hide transport-of-copies versions. |
| **Ignore SAP generated** | `P_IGNGEN` | Keeps generated code out of the review: framework includes whose version author is `SAP*` and the SEGW model classes `*_MPC`, `*_MPC_EXT`, `*_DPC`. Uncheck it to review them as well. `*_DPC_EXT` holds hand-written code and is always reviewable. See [5.9](#59-what-is-excluded-from-a-review). |
| **Ignore Case/Indent** | `P_ICASE` | Case- and indentation-insensitive comparison. One checkbox for both: the diff folds by removing all whitespace and upper-casing, so the two cannot be separated. |

### 3.5 AI API config

<img width="1204" height="300" alt="image" src="https://github.com/user-attachments/assets/2cfbe4e8-2cac-4008-bb76-f7db5278e094" />


| Field | Parameter | Meaning |
|---|---|---|
| **LLM Provider** | `P_PROV` | Dropdown: Anthropic, OpenAI, Gemini, Mistral, Groq, Cerebras, OpenRouter, NVIDIA. The list is hard-coded — there is no customizing table to fill. |
| **API URL** | `P_URL` | Leave empty to use the provider's own endpoint. Fill it for a company gateway, a proxy, or an Azure/Bedrock-style host. |
| **SSL Id (STRUST)** | `P_SSLID` | SSL identity used for the call, `ANONYM` by default. The provider's certificate must be in STRUST under it. |
| **LLM Model** | `P_MODEL` | Model id. **F4 lists the models the provider itself reports**, so a new model is offered the day it is released. |
| **API Key** | `P_APIKEY` | API key. |
| **Max output tokens** | `P_MAXTOK` | Output cap per request (default 20000). With a profile that has a schema, too low a cap truncates the answer mid-JSON and nothing parses. |
| **System prompt file (*.md)** | `P_SYSMD` | One `.md` file used as the system prompt, picked with F4. Leave empty to use a profile below. |
| **Review profiles folder** | `P_PPATH` | Frontend folder holding the review profiles. |
| **Review profile** | `P_PROF` | Profile name — see [section 6](#6-ai-assisted-review). |

Both profile fields have F4: folder browse, and a list of the `*.md` files found in the folder. URL, model, key, folder and profile are stored in SAP memory ids, so they survive between runs.

**No SM59 destination is needed.** The call goes out through `CL_HTTP_CLIENT=>CREATE_BY_URL` with the SSL id above, so the only prerequisite is the provider's certificate in STRUST.

Leaving this block empty is fine — the AI links then produce a ready-made prompt page you can copy manually.

### 3.6 Diagnostic/Debug

<img width="1202" height="109" alt="image" src="https://github.com/user-attachments/assets/18928de9-4b98-4ebb-a146-3e65a96d9d10" />

Both off by default — everything here is for whoever works on AVE itself or has to explain why a Prepare took as long as it did.

| Field | Parameter | Meaning |
|---|---|---|
| **Metrics (cost estimate)** | `P_METRIC` | Adds the [Metrics page](#52-metrics--what-a-prepare-will-cost) and the estimate columns and band selection of the Prepare picker. Without it the metrics are never collected, so the picker opens straight away. |
| **Debug info** | `P_DEBUG` | Adds the Debug button of the version view (diff operations and pairing decisions) and the diagnostics log under the review report. |

---

## 4. Versions Explorer

### 4.1 The three panes

- **Parts list** — the versionable parts of the object: one row for a program, all sections and methods of a class, all objects of a transport or a package.
- **Versions list** — the versions of the selected part: version, date, time, author and author name, **real object owner**, request, request type, task, request description, and the remote system row when one is configured.
- **HTML viewer** — the rendered source or diff.

By default AVE opens the difference between the latest version (base) and the previous one.
The list does not include versions without changes — that is a very comfortable thing.

> 📸 **SCREENSHOT PLACEHOLDER — THREE PANES**
> The main window with the three panes annotated: parts, versions, viewer.

### 4.2 Toolbar buttons

**Main toolbar**

| Button | Effect |
|---|---|
| Refresh | Reloads parts and versions (in review mode: reloads the saved review from the database). |
| Show Diff / Show Vers | Diff of two versions, or the plain source of one version. |
| 2-Pane / Inline | Side-by-side or inline rendering. |
| Compact / Full | Only changes, or the full source with changes highlighted. |
| Blame / Blame ON | Who wrote each line. |
| Maximize View | Hides both tables and expands the HTML viewer. |
| Debug ON | Diagnostic page: the raw diff operations and the pairing decisions behind them. Only with **Debug info** ticked on the selection screen. |
| 📖 | Opens this instruction in the browser. |

There is no Save button in review mode — everything is written to the database on its own, see [5.8](#58-saving-and-reopening-a-review).

**Versions grid toolbar**

| Button | Effect |
|---|---|
| Diff prev / Diff any | Compare with the previous version, or with a chosen base version. |
| Set Base | Marks the selected version as the base for *Diff any*. |
| TOCs on / TOCs off | Show or hide transport-of-copies versions. |
| Dups on / Dups off | Show or hide versions whose source is identical. |
| Case/ind on / off | Case- and indentation-insensitive comparison. |

The parts grid gets one extra button, **Back**, as soon as you drill into a class or a function group from a transport/package list — it returns to the outer object list.

> 📸 **SCREENSHOT PLACEHOLDER — TOOLBARS**
> Close-up of the main toolbar and of the version grid toolbar.

### 4.3 Program / Include / Function Module

Only one part exists, so no object list is needed — AVE goes straight to the version list and opens the latest diff.

> 📸 **SCREENSHOT PLACEHOLDER — PROGRAM 2-PANE**
> Program diff in 2-pane mode.

Pressing the **2-Pane** toggle switches to inline mode.

> 📸 **SCREENSHOT PLACEHOLDER — PROGRAM INLINE**
> The same diff in inline mode.

Double-click on any version shows the difference between it and the previous one.

With **Show Vers** a single version is loaded into the SAP ABAP editor instead of the HTML viewer, so you get real syntax highlighting and the editor's own search. If the newer source is longer than 1000 lines, AVE opens the source instead of diffing automatically — the diff is one double-click away.

### 4.4 Class

The parts list shows all class includes: the sections (Public, Protected, Private), the local and test includes and **one row per method**. So you can navigate fast to any part of the class.

Section includes are compared declaration by declaration rather than line by line: SAP regenerates them in an arbitrary order, and a plain line diff would report every moved declaration as a delete plus an insert far away from each other, and match the parameters of one method against another method's. Parameters inside a matched declaration are aligned by name as well.

> 📸 **SCREENSHOT PLACEHOLDER — CLASS PARTS**
> A class opened in AVE: sections and method list on the left, a method diff on the right.

### 4.5 Transport Request / Task

Shows all TR/Task objects, marking **non-existing objects in red**.

- Double-click on a supported object shows its code and version list.
- Double-click on a class switches to the class objects view (see [4.4](#44-class)); a function group expands into its includes.
- The **Back** button returns from the class object list to the TR/Task object list.

The real object owner is resolved even when the version was recorded under a transport of copies: a T-copy request number is resolved back to its parent K request, and the responsible task is looked up for each version.

> 📸 **SCREENSHOT PLACEHOLDER — TR OBJECT LIST**
> A transport request opened: object list with red rows for missing objects.

### 4.6 Package

Shows all package objects, marking non-existing objects in red; unsupported entries stay visible as rows. Navigation works exactly as for a transport request.

> 📸 **SCREENSHOT PLACEHOLDER — PACKAGE**
> A package opened: the object list of the package.

### 4.7 Function Group, CDS View, DDIC objects

- **Function Group** — expands into the main `SAPL*` include and all `L*` sub-includes.
- **CDS View (DDLS)** — the DDL source is read through the SVRS TLOGO controller and rendered with lightweight syntax highlighting.
- **Table / Domain / Data Element** — the version history of the DDIC definition, rendered from its version records.

> 📸 **SCREENSHOT PLACEHOLDER — CDS DIFF**
> A CDS view diff with syntax highlighting.

### 4.8 Comparing arbitrary versions

To compare any two versions press the toggle button **Diff prev** — it switches to **Diff any**.
Then select a version and press **Set Base**; the base row is coloured green.

> 📸 **SCREENSHOT PLACEHOLDER — SET BASE**
> The version grid with "Diff any" active and a base version marked.

After that, double-clicking any other version compares it with the base version.

Pressing **Maximize View** hides the tables so only the version sources remain.

> 📸 **SCREENSHOT PLACEHOLDER — MAXIMIZED VIEW**
> A diff filling the whole window after Maximize View.

### 4.9 Blame

With blame on, AVE replays the diffs across the version range and attributes every added or changed line to the author who last touched it, drawing separators between blame blocks.

Blame is not free: it replays the diffs of the whole reviewed range, so its cost grows with the number of versions. In review mode the cost is estimated **twice**, with and without blame, so the price is visible before the toggle is touched — see [5.2](#52-metrics--what-a-prepare-will-cost).

> 📸 **SCREENSHOT PLACEHOLDER — BLAME**
> A diff with blame authors and separators visible.

### 4.10 Remote system version check

Fill **Remote system Id version check** with a TMS system name and AVE adds a remote baseline row to the version list, so a local version can be diffed directly against what is active in the other system. In review mode the same setting drives the [Moving Violations](#57-moving-violations) page.

### 4.11 Long-running operations

Reading versions of a big transport can take a while. AVE shows a throttled progress indicator with an ETA and, once the operation runs past a threshold, asks whether to continue — so a mistyped package does not lock the session.

---

## 5. Code Reviewer

Choose **Code Reviewer**, enter one or more requests / tasks in **TRs for Re-View** and press Enter.

### 5.1 Object overview

AVE first shows the object overview of the scope: every object of the request with its tasks, authors, dates, request(s) and row status, plus a link to open a per-object TR/task drilldown. Nothing is computed yet — this page is cheap.

> 📸 **SCREENSHOT PLACEHOLDER — CR OVERVIEW**
> The code review object overview page for a transport request.

From here:

| Action | Meaning |
|---|---|
| **Prepare** | Opens the picker: choose which objects to compute. |
| **Metrics** | The cost estimate, before anything is computed. Only with **Metrics** ticked on the selection screen. |
| **Prepare band L / LM** | Computes only the light (L), or light plus medium (LM) objects — needs **Metrics** as well. |
| **Prepare selected** | Computes exactly the objects ticked in the picker. |
| **Recalc** | Drops the cached data of the selected objects and computes them again. |
| **Open saved review** | Restores the last saved review without recomputing. |

### 5.2 Metrics — what a Prepare will cost

Tick **Metrics** on the selection screen to get this page; it answers one question: *can this request be prepared in the dialog, or does it need to be cut into pieces?*

For every reviewable part it shows the number of versions, the versions in scope, the active line count, whether the part is already cached, the estimated duration and a weight band:

| Band | Estimate |
|---|---|
| **L** light | under 20 s |
| **M** medium | 20 – 90 s |
| **H** heavy | 90 s and more |

Every part is estimated **twice**, with and without blame, so the price of blame is visible before the toggle is touched. Two columns are deliberately kept apart:

- **Versions** — the object's complete version history; this drives the metadata load.
- **In scope** — only the versions of the reviewed request; this drives the blame replay.

A time shown with a leading `~` is still a model estimate. Without it, it is what the last Prepare actually took, and the *Source* column then names the prediction and how far off it was — measured durations are stored with the review and calibrate the next estimate.

> ⚠️ The page warns when an S/R **task** is the selected scope: version trimming is skipped there, so the metadata load covers the full history.

> 📸 **SCREENSHOT PLACEHOLDER — METRICS**
> The Metrics page: per-part table, weight bands, and the Prepare band buttons.

### 5.3 Preparing a review

Prepare loads the versions of every object in scope, picks the diff pair, computes the diff, the hunks, the statistics and — if enabled — the blame, and caches all of it.

During a long run the screen is refreshed at most every 10 seconds. Up to 50 objects the full report is redrawn each time; above that a one-line progress page takes its place, because rebuilding the report renders every object collected so far and its cost grows with the square of the object count. The remaining time comes from the pre-run estimates rescaled by the factor observed on the objects already done, not from a done/total ratio.

> 📸 **SCREENSHOT PLACEHOLDER — PREPARE PROGRESS**
> The progress page during a long Prepare run with the remaining-time estimate.

### 5.4 The report

The report aggregates the whole review:

- totals per **developer** — insertions, deletions, modifications, hunks,
- totals per **reviewer** — approved and declined,
- one group per object, and one group per class holding its parts,
- the approve/decline status of every object,
- links into an object, a class, one developer's or one reviewer's blocks, and the Moving Violations page.

Scroll position is remembered, so returning from an object lands where you left the report.

> 📸 **SCREENSHOT PLACEHOLDER — CR REPORT**
> The Code Review Report page with developer and reviewer totals and the object list.

### 5.5 Reviewing a hunk

Open an object and every changed hunk carries its own action row:

| Link | Effect |
|---|---|
| ✔ approve | Approves the hunk, stamped with your user and the time. |
| ✘ decline | Opens a note dialog; the note is stored with the decline and shown under the hunk. |
| undo | Removes the approval or decline. |
| comment | Adds a message to the hunk's comment thread. |
| edit | Edits your own last comment. |
| Ask AI | Sends this hunk to the configured LLM — see [section 6](#6-ai-assisted-review). |

**Approve all** approves every hunk of the object at once.

One rule is enforced everywhere: **you cannot approve, decline or undo your own block** — AVE knows the author of every hunk from the version data, and Approve all skips your own hunks.

Every action is saved to the database immediately, so a session that ends unexpectedly loses nothing, and **Refresh** picks up what other reviewers saved meanwhile.

Lines that only moved inside a file are filtered out of the review diff, so a re-indented or relocated block does not show up as a change to approve.

> 📸 **SCREENSHOT PLACEHOLDER — HUNK ACTIONS**
> A diff hunk with the approve/decline/undo/comment/AI links and a comment thread below it.

### 5.6 Developer and reviewer views

Clicking a developer in the report opens all their blocks; clicking a reviewer opens everything that reviewer acted on. Both pages have their own filter bar:

- **Declined only** / **Comments only** — narrow the page to what still needs attention,
- **Expand all** / **Collapse all** — fold the object groups,
- the AI link — run or show the AI summary of the visible blocks.

> 📸 **SCREENSHOT PLACEHOLDER — USER VIEW**
> A developer view with the filter bar and collapsed object groups.

### 5.7 Moving Violations

This page matters as soon as there is **more than one development system** — a main development system plus a separate project one, for example. Both change the same objects, and the retrofit between them, manual or automatic, rarely keeps up. So a request released from the project system can silently carry an old state of an object into the main system and overwrite work that was done there in the meantime, or bring back lines somebody else had already deleted. The changed lines of the request are reviewed carefully; the damage comes from everything *around* them, which nobody looks at.

That is exactly what this page shows. With a system id in **Remote system Id version check**, AVE additionally diffs the reviewed source against the source active in that other system and lists only the differences that are **not** part of the reviewed request:

| Warning | What it means |
|---|---|
| *will be overwritten (deleted)* | The other system has lines your source does not — moving the request deletes them there. |
| *deleted will be inserted* | Your source has lines the other system does not — moving the request brings them back there. |
| *diverges* | Both, in one block: the code differs and will be overwritten and re-inserted. |

Each entry names the object, shows the block with a few lines of context, and states the target system. The page is read-only and carries no approve/decline — these are not somebody's changes to judge, they are a warning that a retrofit is needed **before** the request is moved.

You meet them in three places: the red banner on the report, which says how many there are and links here; this page, which lists them across the whole request; and the object itself, where they follow the reviewable blocks in red, marked *Violated — will be deleted after TR move!*, so a diverging object cannot be reviewed without noticing it.

If the object shares no line at all with the remote one, the comparison is skipped: the object simply does not exist there (or is a different object under the same name), and reporting the whole file as a violation would only add noise.

> 📸 **SCREENSHOT PLACEHOLDER — MOVING VIOLATIONS**
> The Moving Violations page with warnings per object.

### 5.8 Saving and reopening a review

The review is written as one JSON payload into `ZAVE_REVIEW`, one row per transport request. Approvals, declines, notes, comment threads, AI summaries, hunk statistics and the measured Prepare durations are all inside it.

Saving happens **automatically** and there is nothing to press: after every approve, decline, undo and comment, after a Prepare or a Recalc, and after an AI answer, the payload goes to the database. A session that ends unexpectedly loses nothing.

Two things make sure the automatic save is not silent about failure:

- if the table `ZAVE_REVIEW` does not exist, the setup instruction ([section 7](#7-zave_review-table-setup)) opens right when the review is opened — before any work is done,
- if a save fails for another reason, you get a warning once per session instead of a lost review.

Reopening the same request offers **Open saved review**, which restores everything without recomputing. Obsolete state — approvals of hunks that no longer exist after a recalculation — is dropped on load.

> 📸 **SCREENSHOT PLACEHOLDER — SAVED REVIEW**
> Reopening a saved review.

### 5.9 What is excluded from a review

With **Ignore SAP generated** on (the default):

- versions whose author matches `SAP*` — function group framework includes and similar,
- generated Gateway/SEGW classes `*_MPC`, `*_MPC_EXT` and `*_DPC`.

`*_DPC_EXT` holds hand-written code and **stays reviewable**. Unchecking the flag brings everything back into the review; objects excluded by a previous version of this rule are dropped from old saved reviews as well.

Independently of that flag, generator boilerplate is neutralized line by line — the SEGW header (`This class has been generated on … in client …`) and the table maintenance generator header (`generation date: …`, `view maintenance generator version: …`). These are rewritten by every regeneration in every system, so left alone they turn a re-generated maintenance view into a change to approve, or into a [moving violation](#57-moving-violations) whose whole content is the date it was generated on. The rule applies to the review diff and the retrofit diff alike.

---

## 6. AI-assisted review

**Ask AI** on a single hunk sends that block alone. Above the block list there are two prompt buttons that cover everything visible in the current view:

| Button | What lands in the prompt |
|---|---|
| **AI prompt diff** | The changed blocks only — short and cheap, enough for "what changed here". |
| **AI prompt full** | The whole source of every touched object with the changes marked (`+` added, `-` deleted, the rest is context) — costs tokens, but the model judges a change in its surroundings instead of in isolation. |

Both are pages you can read, with **Save to file** and **Copy to clipboard** on top; which one you get no longer depends on the Compact toggle, the button decides. Each prompt states what the model is looking at — the changed blocks only, or the full source — and what the markers mean: `+` is a line of the new version, `-` a line of the previous one, and a block holding both is a modification. When the AI API block is filled in, the first button turns into **AI Summary** and AVE calls the provider itself, storing the answer as a comment in the hunk thread or as a persisted AI summary of the object — **AI prompt full** stays a copyable page in that case too.

A **review profile** is a pair of files in one frontend folder, matched by name:

```
<profile>.md     the system prompt — persona, what to look for, what to ignore  (required)
<profile>.json   the JSON schema the answer must conform to                     (optional)
```

The profile owns the instructions; AVE owns the material — object name and changed lines — and passes it as the user turn. A profile without a schema simply asks for free-form text.

The system prompt is resolved in three steps, first hit wins:

1. **System prompt file** — the `.md` file named on the selection screen,
2. **Review profile** — `<profile>.md` in the profiles folder,
3. the instruction text built into the report, kept as [`prompts/ave_system.md`](prompts/ave_system.md) so it can be read, edited or used as the start of your own profile.

The folder is read from the **frontend**, so it lives on the machine running SAP GUI. Files are read once per run and cached — leave and re-enter the report to pick up an edit.

Two ready-made profiles ship in [`prompts/`](prompts/): `rules` and `security`.

> 📸 **SCREENSHOT PLACEHOLDER — AI COMMENT**
> A hunk with an AI-generated review comment in its thread.

---

## 7. ZAVE_REVIEW table setup

The Code Reviewer can store its data only after a transparent table `ZAVE_REVIEW` exists and is active. The design is deliberately minimal: one row per transport request, the full review with its save history in one JSON payload.

| Field | Type | Purpose |
|---|---|---|
| `MANDT` | MANDT | Client field (key) |
| `TRKORR` | TRKORR | Transport request (key) |
| `PAYLOAD` | STRING | Review JSON including the current state and the save history |

1. Create transparent table `ZAVE_REVIEW`.
2. Make `MANDT` and `TRKORR` key fields.
3. Add field `PAYLOAD` of type `STRING`.
4. Activate the table. No ZIP or compression is needed.
5. Return to AVE and open the review again.

Opening a review without the table shows this same help page inside AVE.

---

## 8. Also in this repository

Two side tools, neither of them needed to run AVE:

- **`Z_AVE_OBSERVER`** — alpha 0.5. A companion report that observes workbench (K) requests changed or released in a date range, filtered by package and user, and lets you browse their objects with a quick diff indicator; clicking an object opens the real diff, rendered by AVE's own engine. Standalone version: `src/z_ave_observer_sa.prog.abap`.
- **`html_simulator/`** — a browser-side port of the diff algorithm, for trying the diff behaviour out without a SAP system. Open `html_simulator/index.html` directly in a browser, no build step.

And as a bonus, a standalone HTML/JS local comparer: https://github.com/ysichov/Diff

---

## 9. Author & links

Written by **Yurii Sychov**

- e-mail: ysichov@gmail.com
- blog: https://ysychov.wordpress.com/blog/
- LinkedIn: https://www.linkedin.com/in/ysychov/
- GitHub: https://github.com/ysichov/AVE

Inspired by [abapTimeMachine](https://github.com/abapinho/abapTimeMachine), Eclipse ADT, GitHub and all other similar tools.
