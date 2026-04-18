# AVE Diff Simulator

Browser-side port of the AVE diff algorithm (`zcl_ave_popup.clas.abap`).
Lets you iterate on the diff/pairing/char-highlight logic without round-tripping through SAP.

## Usage

Open `index.html` in any modern browser (no server / build needed).
- Paste OLD source into the top textarea, NEW into the bottom.
- Auto-compare runs on input (debounced 150 ms); toggle off and use **Compare** for manual.
- **2-pane mode** mirrors the side-by-side ABAP rendering.
- **Compact** hides unchanged lines outside a 3-line context window.
- **Load sample** prefills a small example, including the `WRITE 1.` ↔ `WRITE 1 .` case.

## Files

- `index.html` — UI shell (textareas + iframe for the rendered diff).
- `diff.js` — JS port of `compute_diff`, `has_common_chars`, `char_diff_html`,
  and the inline / 2-pane rendering with block-pairing pass.

## Keeping it in sync with ABAP

When you change the ABAP algorithm (`zcl_ave_popup.clas.abap`), update `diff.js`
to match. The file is intentionally structured as a 1-to-1 mirror of the ABAP
methods so diffs between the two are easy to spot.
