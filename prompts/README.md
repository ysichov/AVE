# Review profiles

Each profile is a pair of files in this folder, matched by name:

| File | Required | Role |
|---|---|---|
| `<profile>.md` | yes | The system prompt: persona, what to look for, what to ignore |
| `<profile>.json` | no | JSON schema the answer must conform to |

The profile name is what the two files share — `security.md` + `security.json`
give a profile called `security`. Only `.md` files are listed on the selection
screen, so a schema without a prompt is invisible.

Point **Review profiles folder** on the AVE selection screen at this folder and
pick a profile. Both fields sit in the AI API block, next to model and API key.

The folder is read from the **frontend** (`gui_upload`), so it lives on the
machine running SAP GUI — same mechanism as `AGENTS/` in ABAP-AI-Code. Files are
read once per run and cached; leave and re-enter the report to pick up an edit.

## Division of labour

The profile owns the **instructions**. AVE owns the **material** — object name
and the changed lines — and passes it as the user turn.

With no profile selected, AVE falls back to its own built-in instruction text,
so the tool behaves exactly as it did before profiles existed.

## Schema notes

- Every object needs `"additionalProperties": false`, otherwise the request is
  rejected.
- Not supported: recursive schemas, `minimum` / `maximum`, `minLength` /
  `maxLength`.
- A `.json` file that is missing, unreadable, or does not start with `{` or `[`
  counts as "no schema" — the profile then asks for free-form text.
- Leave **Max output tokens** generous. A truncated answer under a schema is
  invalid JSON, not a short answer.

## Shipped profiles

`security` and `rules` are starting points, not standards — in particular the
rule list in `rules.md` is a placeholder to be replaced per engagement.

## The built-in prompt

`ave_system.md` is the instruction text AVE falls back to when no profile and no
system-prompt file are selected — the same words, kept as a file so they can be
edited, translated or used as the starting point of a profile.

Point **System prompt file (*.md)** on the selection screen at one file to use it
as the system prompt directly, without the folder/profile pair. The order is:
that file, then `<profile>.md`, then the text built into the report.
