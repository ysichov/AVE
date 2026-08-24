# AVE — ABAP Versions Explorer & Code Reviewer

SAP ABAP version explorer and code review tool for SAP GUI.

Tested on dozens of transport requests and on real projects — the largest one so far: **4 developers, several months of work, ~25 000 lines of code**, reviewed with AVE from end to end.

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
- **Straight into Eclipse** — every object, and every changed block, opens in the ADT editor on its own line; one Recalc afterwards and the review is on the new code.
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
   - [4.12 Open in Eclipse (ADT)](#412-open-in-eclipse-adt)
5. [Code Reviewer](#5-code-reviewer)
   - [5.1 Object overview](#51-object-overview)
   - [5.2 Preparing a review](#52-preparing-a-review)
   - [5.3 The report](#53-the-report)
   - [5.4 Reviewing a hunk](#54-reviewing-a-hunk)
   - [5.5 Developer and reviewer views](#55-developer-and-reviewer-views)
   - [5.6 Moving Violations](#56-moving-violations)
   - [5.7 Saving and reopening a review](#57-saving-and-reopening-a-review)
   - [5.8 What is excluded from a review](#58-what-is-excluded-from-a-review)
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

Point AVE at the other system and it compares the reviewed source against what is active there, listing everything that will be overwritten or re-inserted when the request is moved. See [Moving Violations](#56-moving-violations).

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

<img width="1207" height="301" alt="image" src="https://github.com/user-attachments/assets/9f8517e6-03ba-4f18-a550-09cfdbaf0434" />



| Field | Parameter | Meaning |
|---|---|---|
| **Code Reviewer** | `P_CR` | Review mode: AVE prepares the diffs of a transport scope and opens the review report. |
| **Versions Explorer** | `P_VE` | Classic mode: browse and compare versions of one object. |
| **TRs for Re-View** | `S_TASK` | One or more requests / tasks — the review scope, and also the object when *TR/Task* is chosen below. |
| **Include Tasks** | `P_ITASK` | Read the objects of the S-tasks belonging to the entered requests too. A request header only carries what was recorded directly on it, so an unreleased K is usually empty while its tasks hold everything. |
| **Remote system Id version check** | `P_SYS` | TMS system id — adds a remote baseline version and switches on the Moving Violations check ([5.6](#56-moving-violations)). |
| **Who is Blame :)** | `P_BLAME` | Compute blame — who wrote each line. Costly on long histories, see [4.9](#49-blame). |

### 3.2 Object types

Choose one object type, enter its name and press **Enter**.

<img width="1208" height="324" alt="image" src="https://github.com/user-attachments/assets/070e12c5-033b-418d-a9f6-a9db3ffd5b5d" />


| Radio button | Parameter | Object |
|---|---|---|
| TR/Task | `S_TASK` | Transport request or task (entered in the block above) |
| Program/Include | `P_PROG` | Report, include |
| Class | `P_CLAS` | Class |
| Function Module | `P_FUNC` | Single function module |
| Package | `P_PACK` | Development package |
| CDS View | `P_DDLS` | DDL source |
| Function Group | `P_FUGR` | Whole function group |
| Table (TABD) | `P_TABD` | DDIC table |
| Domain (DOMA) | `P_DOMA` | DDIC domain |
| Data element (DTEL) | `P_DTEL` | DDIC data element |

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
| **Ignore SAP generated** | `P_IGNGEN` | Keeps generated code out of the review: framework includes whose version author is `SAP*` and the SEGW model classes `*_MPC`, `*_MPC_EXT`, `*_DPC`. Uncheck it to review them as well. `*_DPC_EXT` holds hand-written code and is always reviewable. See [5.8](#58-what-is-excluded-from-a-review). |
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

Four fields have F4: the model (asks the provider), the system prompt file, the profiles folder (folder browse) and the profile (the `*.md` files found there). URL, model, key, prompt file, folder and profile are stored in SAP memory ids, so they survive between runs.

**No SM59 destination is needed.** The call goes out through `CL_HTTP_CLIENT=>CREATE_BY_URL` with the SSL id above, so the only prerequisite is the provider's certificate in STRUST.

Leaving this block empty is fine — the AI links then produce a ready-made prompt page you can copy manually.

### 3.6 Diagnostic/Debug

<img width="1202" height="109" alt="image" src="https://github.com/user-attachments/assets/18928de9-4b98-4ebb-a146-3e65a96d9d10" />

Both off by default — everything here is for whoever works on AVE itself or has to explain why a Prepare took as long as it did.

| Field | Parameter | Meaning |
|---|---|---|
| **Metrics (cost estimate)** | `P_METRIC` | Adds a page estimating what a Prepare of this scope will cost, plus the estimate columns and the by-weight selection in the Prepare picker. Without it nothing is measured and the picker opens straight away. |
| **Debug info** | `P_DEBUG` | Adds the Debug button of the version view (diff operations and pairing decisions) and the diagnostics log under the review report. |

---

## 4. Versions Explorer

### 4.1 The three panes

- **Parts list** — the versionable parts of the object: one row for a program, all sections and methods of a class, all objects of a transport or a package.
- **Versions list** — the versions of the selected part: version, date, time, author and author name, **real object owner**, request, request type, task, request description, and the remote system row when one is configured.
- **HTML viewer** — the rendered source or diff. Its top-right corner carries **Eclipse** and **Refresh** for the part on display, so both stay reachable when the two grids are hidden by *Maximize View* ([4.12](#412-open-in-eclipse-adt)).

By default AVE opens the difference between the latest version (base) and the previous one.
The list does not include versions without changes — that is a very comfortable thing.


The main window with the three panes annotated: parts, versions, viewer.
<img width="1622" height="768" alt="image" src="https://github.com/user-attachments/assets/4649ce38-f05f-4f7e-97f9-d8dfcceb7d8d" />


### 4.2 Toolbar buttons

**Main toolbar**

| Button | Effect |
|---|---|
| Refresh | Reloads parts and versions. |
| Show Diff / Show Vers | Diff of two versions, or the plain source of one version. |
| 2-Pane / Inline | Side-by-side or inline rendering. |
| Compact / Full | Only changes, or the full source with changes highlighted. |
| Blame / Blame ON | Who wrote each line. |
| Maximize View | Hides both tables and expands the HTML viewer. |
| Eclipse | Opens the object in Eclipse (ADT), see [4.12](#412-open-in-eclipse-adt). |
| Debug ON | Diagnostic page: the raw diff operations and the pairing decisions behind them. Appears only with **Debug info** ticked on the selection screen. |
| 📖 | Opens this instruction in the browser. |

The Code Reviewer has a shorter toolbar of its own — **Inline**, **Compact**, **Maximize View**, **Eclipse**, **Reload** and 📖. There is no Save button: everything is written to the database on its own, see [5.7](#57-saving-and-reopening-a-review).

**Versions grid toolbar**

| Button | Effect |
|---|---|
| Diff prev / Diff any | Compare with the previous version, or with a chosen base version. |
| Set Base | Marks the selected version as the base. Appears only while *Diff any* is active. |
| TOCs on / TOCs off | Show or hide transport-of-copies versions. |
| Dups on / Dups off | Show or hide versions whose source is identical. |
| Case/ind on / off | Case- and indentation-insensitive comparison. |

The parts grid carries **Eclipse** and **Refresh** for the object marked in it, and gets one extra button, **Back**, as soon as you drill into a class or a function group from a transport/package list — it returns to the outer object list.

> 📸 **SCREENSHOT PLACEHOLDER — TOOLBARS**
> Close-up of the main toolbar and of the version grid toolbar.
<img width="657" height="35" alt="image" src="https://github.com/user-attachments/assets/b542c66d-32b8-49b2-9f1e-9a154cbd4249" />
<img width="450" height="34" alt="image" src="https://github.com/user-attachments/assets/d9c68272-ba01-4bf7-b94c-e8ac5af7466d" />


### 4.3 Program / Include / Function Module

Only one part exists, so no object list is needed — AVE goes straight to the version list and opens the latest diff.

> 📸 **SCREENSHOT PLACEHOLDER — PROGRAM 2-PANE**
<img width="1846" height="573" alt="image" src="https://github.com/user-attachments/assets/d487585f-09cc-4a1d-9198-e9574de24dd9" />

Pressing the **2-Pane** toggle switches to inline mode.

Double-click on any version shows the difference between it and the previous one.

With **Show Vers** a single version is loaded into the SAP ABAP editor instead of the HTML viewer, so you get real syntax highlighting and the editor's own search. If the newer source is longer than 1000 lines, AVE opens the source instead of diffing automatically — the diff is one double-click away. Programs and includes are exempt: they always open as a diff.

### 4.4 Class

The parts list shows all class includes: the sections (Public, Protected, Private), the local and test includes and **one row per method**. So you can navigate fast to any part of the class.

Section includes are compared declaration by declaration rather than line by line: SAP regenerates them in an arbitrary order, and a plain line diff would report every moved declaration as a delete plus an insert far away from each other, and match the parameters of one method against another method's. Parameters inside a matched declaration are aligned by name as well.

### 4.5 Transport Request / Task

Shows all TR/Task objects, marking **non-existing objects in red**.

- Double-click on a supported object shows its code and version list.
- Double-click on a class switches to the class objects view (see [4.4](#44-class)); a function group expands into its includes.
- The **Back** button returns from the class object list to the TR/Task object list.

The real object owner is resolved even when the version was recorded under a transport of copies: a T-copy request number is resolved back to its parent K request, and the responsible task is looked up for each version.

A transport request opened: object list with red rows for missing objects.

### 4.6 Package

Shows all package objects, marking non-existing objects in red; unsupported entries stay visible as rows. Navigation works exactly as for a transport request.


### 4.7 Function Group, CDS View, DDIC objects

- **Function Group** — expands into the main `SAPL*` include and all `L*` sub-includes.
- **CDS View (DDLS)** — the DDL source is read through the SVRS TLOGO controller and rendered with lightweight syntax highlighting.
- **Table / Domain / Data Element** — no line diff: two versions of the definition are compared as a table, one row per field, fixed value or attribute, each marked added, deleted or changed.

### 4.8 Comparing arbitrary versions

To compare any two versions press the toggle button **Diff prev** — it switches to **Diff any**.
Then select a version and press **Set Base**; the base row is coloured green.

After that, double-clicking any other version compares it with the base version.

Pressing **Maximize View** hides the tables so only the version sources remain.

### 4.9 Blame

With blame on, AVE replays the diffs across the version range and attributes every added or changed line to the author who last touched it, drawing separators between blame blocks.

Blame is not free: it replays the diffs of the whole reviewed range, so on an object with a long history it is the slowest part of a review.

A diff with blame authors and separators visible.

### 4.10 Remote system version check

Fill **Remote system Id version check** with a TMS system name and AVE adds a remote baseline row to the version list, so a local version can be diffed directly against what is active in the other system. In review mode the same setting drives the [Moving Violations](#56-moving-violations) page.

### 4.11 Long-running operations

Reading versions of a big transport can take a while. AVE shows a throttled progress indicator with an ETA and, once the operation runs past a threshold, asks whether to continue — so a mistyped package does not lock the session.

### 4.12 Open in Eclipse (ADT)

Reading a diff usually ends with wanting to change the code, and AVE is a viewer. Every object it shows therefore carries a jump into the Eclipse editor:

- the **Eclipse** button of the main toolbar and of the parts grid opens the object marked in the list, or — with nothing marked — the one on display;
- every page of the Version Explorer carries an **Eclipse** button in its top-right corner, next to a **Refresh**;
- in the Code Reviewer, the object list, the report, the metrics and picker pages, the developer/reviewer views and the Moving Violations page carry a small **ADT** badge next to each object name; the object and class views carry **Eclipse** and **Recalc** buttons of their own;
- **every changed block carries its own ADT badge**, and that one opens the editor on the first changed line of the block — not at the top of a 900-line method.

The jump is a plain `adt://<SID>/sap/bc/adt/…` URL handed to the frontend: Eclipse registers that protocol when ADT is installed and opens the object. Nothing is called on the SAP side, so no destination and no ADT session are needed — a workstation without Eclipse simply gets an OS error from the URL.

What each part opens:

| Part | Opens |
|---|---|
| Class, class pool, public / protected / private section | The class source. |
| Method | The class, positioned on that method. |
| Local definitions / implementations / macros / test classes | The matching tab of the class editor. |
| Interface | The interface source. |
| Program, include | The program or the include. |
| Function module | The module inside its function group; a group include, under its group. |
| Function group | The group's main program. |
| CDS DDL source | The DDL source. |
| Table, structure, view, domain, data element, table type, package | The DDIC / package editor of that object. AVE does not build these links itself — ADT names those resources differently per release, so the system's own ADT URI mapper is asked for the address. |

A block badge adds the line to that URL. AVE numbers lines inside the part, while ADT opens the whole class source, so for a method or a section the line is translated first — by locating the part's opening statement in the class source. If it cannot be located, the line is dropped and the jump lands on the object rather than on a wrong line.

Re-reading the object after the change is the other half of it, and the two modes name it differently because they do different things. In the Explorer **Refresh** reloads parts, versions and the open diff. In the Code Reviewer **Recalc** drops the cached diff of that one object, recomputes it and reopens the same view — so a review is never given on a stale diff; the toolbar's **Reload** next to it only re-reads the saved review state from `ZAVE_REVIEW` and recomputes nothing.

---

## 5. Code Reviewer

Choose **Code Reviewer**, enter one or more requests / tasks in **TRs for Re-View** and press Enter.

### 5.1 Object overview

AVE first shows the object overview of the scope: every object of the request with its tasks, authors, dates, request(s) and row status, plus a link to open a per-object TR/task drilldown. Nothing is computed yet — this page is cheap. Every row also carries an **ADT** badge that opens the object in Eclipse, see [4.12](#412-open-in-eclipse-adt).

TR not saved earlier
> <img width="1621" height="419" alt="image" src="https://github.com/user-attachments/assets/b7c7c193-05da-417b-b9d8-93748231c0da" />

TR Review from database

<img width="1588" height="407" alt="image" src="https://github.com/user-attachments/assets/29cf5ea5-f50a-4603-b354-4c3b927cc235" />


From here:

| Action | Meaning |
|---|---|
| **Prepare Code Review** | Opens the picker: tick the objects to compute, then **Prepare Selected**. |
| **Open Review** | Replaces the Prepare button once a saved review exists for this request: opens it as it was, without recomputing. A saved review also opens by itself when you enter the request. |
| **Recalc Diff** | Next to Open Review: the same picker, but for objects that already have data — **Recalc Selected** recomputes them, **Delete and recalc** drops the saved data of the ticked objects first. |

### 5.2 Preparing a review

Prepare loads the versions of every object in scope, picks the diff pair, computes the diff, the hunks, the statistics and — if enabled — the blame, and caches all of it.

During a long run the screen is refreshed at most every 10 seconds. Up to 50 objects the full report is redrawn each time; above that a one-line progress page takes its place, because rebuilding the report renders every object collected so far and its cost grows with the square of the object count.

### 5.3 The report

The report aggregates the whole review:

- totals per **developer** — insertions, deletions, modifications, hunks,
- totals per **reviewer** — approved and declined,
- one group per object, and one group per class holding its parts,
- the approve/decline status of every object,
- links into an object, a class, one developer's or one reviewer's blocks, and the Moving Violations page,
- an **ADT** badge next to every object and class name, opening it in Eclipse ([4.12](#412-open-in-eclipse-adt)).

Scroll position is remembered, so returning from an object lands where you left the report.


### 5.4 Reviewing a hunk

Open an object and every changed hunk carries its own action row:

| Link | Effect |
|---|---|
| ✓ Approve | Approves the hunk, stamped with your user and the time. |
| ✗ Decline | Opens a note dialog; the note is stored with the decline and shown under the hunk. |
| Undo | Removes the approval or decline. Shown once the hunk carries one. |
| Add Comment | Adds a message to the hunk's comment thread. |
| Edit | Edits your own last comment. Shown once you have written one. |
| ASK AI | Sends this hunk to the LLM — only when the AI block on the selection screen is filled in, see [section 6](#6-ai-assisted-review). |
| ADT | Opens the Eclipse editor **on the first changed line of this hunk**, see [4.12](#412-open-in-eclipse-adt). |

Every hunk carries its state next to those links: `○ open`, `○ own block`, `✓ approved` or `✗ declined`, the last two with the reviewer and the time. **✓ Approve All** at the end of the object approves the rest of it in one go.

Above the blocks the object has its own bar: **Declined only**, **Comments only** to narrow the page, the two AI buttons, and **Eclipse** / **Recalc** — the object in the editor, and the recompute that picks up what you changed there.

One rule is enforced everywhere: **you cannot approve, decline or undo your own block** — AVE knows the author of every hunk from the version data, and Approve all skips your own hunks.

Every action is saved to the database immediately, so a session that ends unexpectedly loses nothing. What another reviewer saved meanwhile is picked up when the review is opened again.

Lines that only moved inside a file are filtered out of the review diff, so a re-indented or relocated block does not show up as a change to approve.

<img width="1631" height="135" alt="image" src="https://github.com/user-attachments/assets/19846736-7a69-41e8-b440-317c29e5e81f" />

### 5.5 Developer and reviewer views

Clicking a developer in the report opens all their blocks; clicking a reviewer opens everything that reviewer acted on. Both pages have their own filter bar:

- **Declined only** / **Comments only** — narrow the page to what still needs attention,
- **Expand all** / **Collapse all** — fold the object groups (they start collapsed),
- **AI prompt diff** / **AI prompt full** — the prompt of everything visible; with the API configured the first one becomes **AI Summary** and calls the model.

Each object header carries an **ADT** badge and each block its own, so a block opens in Eclipse on its first changed line ([4.12](#412-open-in-eclipse-adt)). The scroll position is kept across a drilldown: going into an object and back lands where you left the list.



### 5.6 Moving Violations

This page matters as soon as there is **more than one development system** — a main development system plus a separate project one, for example. Both change the same objects, and the retrofit between them, manual or automatic, rarely keeps up. So a request released from the project system can silently carry an old state of an object into the main system and overwrite work that was done there in the meantime, or bring back lines somebody else had already deleted. The changed lines of the request are reviewed carefully; the damage comes from everything *around* them, which nobody looks at.

That is exactly what this page shows. With a system id in **Remote system Id version check**, AVE additionally diffs the reviewed source against the source active in that other system and lists only the differences that are **not** part of the reviewed request:

| Warning | What it means |
|---|---|
| *will be overwritten (deleted)* | The other system has lines your source does not — moving the request deletes them there. |
| *deleted will be inserted* | Your source has lines the other system does not — moving the request brings them back there. |
| *diverges* | Both, in one block: the code differs and will be overwritten and re-inserted. |

Each entry names the object, shows the block with a few lines of context, and states the target system. The page is read-only and carries no approve/decline — these are not somebody's changes to judge, they are a warning that a retrofit is needed **before** the request is moved. Object and block still carry their **ADT** badges, so the code that is about to be overwritten can be opened in Eclipse right away ([4.12](#412-open-in-eclipse-adt)).

You meet them in three places: the red banner on the report, which says how many there are and links here; this page, which lists them across the whole request; and the object itself, where they follow the reviewable blocks in red, tagged *Violated — will be deleted / re-inserted / overwritten after TR move!* depending on the case, so a diverging object cannot be reviewed without noticing it.

If the object shares no line at all with the remote one, the comparison is skipped: the object simply does not exist there (or is a different object under the same name), and reporting the whole file as a violation would only add noise.

> 📸 **SCREENSHOT PLACEHOLDER — MOVING VIOLATIONS**
<img width="1629" height="201" alt="image" src="https://github.com/user-attachments/assets/3edc759c-c421-482a-a7f0-2530243775f5" />


### 5.7 Saving and reopening a review

The review is written as one JSON payload into `ZAVE_REVIEW`, one row per transport request. Approvals, declines, notes, comment threads, AI summaries and hunk statistics are all inside it.

Saving happens **automatically** and there is nothing to press: after every approve, decline, undo and comment, after a Prepare or a Recalc, and after an AI answer, the payload goes to the database. A session that ends unexpectedly loses nothing.

Two things make sure the automatic save is not silent about failure:

- if the table `ZAVE_REVIEW` does not exist, the setup instruction ([section 7](#7-zave_review-table-setup)) opens right when the review is opened — before any work is done,
- if a save fails for another reason, you get a warning once per session instead of a lost review.

Entering the same request again opens the saved review straight away; from the object overview the **Open Review** button does the same. Obsolete state — approvals of hunks that no longer exist after a recalculation — is dropped on load.


### 5.8 What is excluded from a review

With **Ignore SAP generated** on (the default):

- versions whose author matches `SAP*` — function group framework includes and similar,
- generated Gateway/SEGW classes `*_MPC`, `*_MPC_EXT` and `*_DPC`.

`*_DPC_EXT` holds hand-written code and **stays reviewable**. Unchecking the flag brings everything back into the review; objects excluded by a previous version of this rule are dropped from old saved reviews as well.

Independently of that flag, generator boilerplate is neutralized line by line — the SEGW header (`This class has been generated on … in client …`) and the table maintenance generator header (`generation date: …`, `view maintenance generator version: …`). These are rewritten by every regeneration in every system, so left alone they turn a re-generated maintenance view into a change to approve, or into a [moving violation](#56-moving-violations) whose whole content is the date it was generated on. The rule applies to the review diff and the retrofit diff alike.

---

## 6. AI-assisted review

**ASK AI** on a single hunk sends that block alone; the link appears only when the AI block above is filled in. Above the block list there are two prompt buttons that cover everything visible in the current view:

| Button | What lands in the prompt |
|---|---|
| **AI prompt diff** | The changed blocks only — short and cheap, enough for "what changed here". |
| **AI prompt full** | The whole source of every touched object with the changes marked (`+` added, `-` deleted, the rest is context) — costs tokens, but the model judges a change in its surroundings instead of in isolation. |

Both are pages you can read, with **Save to file** and **Copy to clipboard** on top; the button decides what goes in, not the Compact toggle. Each prompt states what the model is looking at — the changed blocks only, or the full source — and what the markers mean: `+` is a line of the new version, `-` a line of the previous one, and a block holding both is a modification. When the AI API block is filled in, the first button turns into **AI Summary** and AVE calls the provider itself, storing the answer as a comment in the hunk thread or as a persisted AI summary of the object — **AI prompt full** stays a copyable page in that case too.

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
