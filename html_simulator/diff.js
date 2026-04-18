/* AVE diff algorithm — JS port of zcl_ave_popup.clas.abap.
 * Three core pieces:
 *   computeDiff(oldArr, newArr)            → [{op:'='|'-'|'+', text}]
 *   hasCommonChars(a, b)                   → bool   (>=3 char common prefix after trim)
 *   charDiffHtml(oldS, newS, side='B')     → string (prefix/suffix common, mid highlighted)
 *   diffToHtml(ops, opts)                  → full HTML doc (inline or 2-pane)
 *
 * Keep this file as faithful to the ABAP as possible — that's the whole point of the simulator.
 */
(function (global) {

  // ─── 1. Line-level LCS diff (matches METHOD compute_diff) ────────────────
  function computeDiff(itOld, itNew) {
    const nOld = itOld.length;
    const nNew = itNew.length;
    const cols = nNew + 1;
    const rows = nOld + 1;
    // flat DP table
    const dp = new Int32Array(rows * cols);

    for (let i = 1; i <= nOld; i++) {
      for (let j = 1; j <= nNew; j++) {
        if (itOld[i - 1] === itNew[j - 1]) {
          dp[i * cols + j] = dp[(i - 1) * cols + (j - 1)] + 1;
        } else {
          const vUp = dp[(i - 1) * cols + j];
          const vLeft = dp[i * cols + (j - 1)];
          dp[i * cols + j] = vUp >= vLeft ? vUp : vLeft;
        }
      }
    }

    // Backtrack — prefer '-' over '+' when equal so '-' precedes '+'
    const result = [];
    let i = nOld, j = nNew;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        if (itOld[i - 1] === itNew[j - 1]) {
          result.push({ op: '=', text: itNew[j - 1] });
          i--; j--;
        } else {
          const cup = dp[(i - 1) * cols + j];
          const cleft = dp[i * cols + (j - 1)];
          if (cup >= cleft) {
            result.push({ op: '-', text: itOld[i - 1] });
            i--;
          } else {
            result.push({ op: '+', text: itNew[j - 1] });
            j--;
          }
        }
      } else if (i > 0) {
        result.push({ op: '-', text: itOld[i - 1] });
        i--;
      } else {
        result.push({ op: '+', text: itNew[j - 1] });
        j--;
      }
    }
    return result.reverse();
  }

  // ─── 2. Pairing heuristic (matches METHOD has_common_chars) ──────────────
  function hasCommonChars(a, b) {
    const lA = a.replace(/^\s+|\s+$/g, '');
    const lB = b.replace(/^\s+|\s+$/g, '');
    if (!lA.length || !lB.length) return false;
    let cp = 0;
    while (cp < lA.length && cp < lB.length && lA[cp] === lB[cp]) cp++;
    // ABAP requires >=3 chars common prefix (suffix only reinforces).
    return cp >= 3;
  }

  // ─── 3. Character-level diff highlight (matches METHOD char_diff_html) ───
  function escHtml(s) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
  function escMid(s) {
    // After HTML-escape, replace spaces with &nbsp; so single-space diffs are visible
    return escHtml(s).replace(/ /g, '&nbsp;');
  }

  function rstrip(s) {
    let n = s.length;
    while (n > 0 && s.charCodeAt(n - 1) === 32) n--;
    return s.slice(0, n);
  }

  // Same padded styles as the latest ABAP (padding+outline so a 1-char highlight is visible).
  const DEL_STYLE = 'background:#ffb3b3;color:#cc0000;padding:0 2px;outline:1px solid #c66';
  const INS_STYLE = 'background:#afffaf;color:#006600;padding:0 2px;outline:1px solid #6c6';

  function charDiffHtml(ivOld, ivNew, ivSide) {
    ivSide = ivSide || 'B';
    const oldT = rstrip(ivOld);
    const newT = rstrip(ivNew);
    const lo = oldT.length, ln = newT.length;

    // Common prefix
    let pre = 0;
    while (pre < lo && pre < ln && oldT[pre] === newT[pre]) pre++;
    // Common suffix (not overlapping prefix)
    let suf = 0;
    while (suf < lo - pre && suf < ln - pre &&
           oldT[lo - 1 - suf] === newT[ln - 1 - suf]) suf++;

    const prefix = oldT.slice(0, pre);
    const midOLen = lo - pre - suf;
    const midNLen = ln - pre - suf;
    const midO = midOLen > 0 ? oldT.slice(pre, pre + midOLen) : '';
    const midN = midNLen > 0 ? newT.slice(pre, pre + midNLen) : '';
    const suffix = suf > 0 ? oldT.slice(pre + midOLen) : '';

    const ePrefix = escHtml(prefix);
    const eSuffix = escHtml(suffix);
    const eMidO = midO ? escMid(midO) : '';
    const eMidN = midN ? escMid(midN) : '';

    let out = ePrefix;
    if (ivSide === 'O') {
      if (eMidO) out += `<span style="${DEL_STYLE}">${eMidO}</span>`;
    } else if (ivSide === 'N') {
      if (eMidN) out += `<span style="${INS_STYLE}">${eMidN}</span>`;
    } else { // 'B'
      if (eMidO) out += `<span style="${DEL_STYLE}">${eMidO}</span>`;
      if (eMidN) out += `<span style="${INS_STYLE}">${eMidN}</span>`;
    }
    out += eSuffix;
    return out;
  }

  // ─── 4. Render diff → HTML (mirrors METHOD diff_to_html, inline branch) ──
  function diffToHtml(ops, opts) {
    opts = opts || {};
    const title = opts.title || '';
    const meta = opts.meta || '';
    const twoPane = !!opts.twoPane;
    const compact = !!opts.compact;

    if (twoPane) {
      return renderTwoPane(ops, title, meta, compact);
    }
    return renderInline(ops, title, meta, compact);
  }

  // Mark which '=' lines should be visible in compact mode (within 3 of any change)
  function buildShowMask(ops, ctx) {
    const n = ops.length;
    const show = new Array(n).fill(false);
    for (let i = 0; i < n; i++) {
      if (ops[i].op !== '=') {
        const lo = Math.max(0, i - ctx);
        const hi = Math.min(n - 1, i + ctx);
        for (let k = lo; k <= hi; k++) show[k] = true;
      }
    }
    return show;
  }

  function renderInline(ops, title, meta, compact) {
    const ctx = 3;
    const show = compact ? buildShowMask(ops, ctx) : null;
    let rows = '';
    let lno = 0;
    let pos = 0;
    let gapShown = false;

    while (pos < ops.length) {
      const cur = ops[pos];

      if (cur.op === '=') {
        lno++;
        if (compact && !show[pos]) {
          if (!gapShown) {
            rows += `<tr style="background:#f0f0f0;color:#888"><td class="ln">...</td><td class="cd">...</td></tr>`;
            gapShown = true;
          }
          pos++;
          continue;
        }
        gapShown = false;
        rows += `<tr style="background:#ffffff"><td class="ln">${lno}</td><td class="cd">${escHtml(cur.text)}</td></tr>`;
        pos++;
        continue;
      }

      // Collect consecutive '-' and '+' into one block
      const dels = [], ins = [];
      let scan = pos;
      while (scan < ops.length) {
        if (ops[scan].op === '-') { dels.push(ops[scan].text); scan++; }
        else if (ops[scan].op === '+') { ins.push(ops[scan].text); scan++; }
        else break;
      }

      // Pair dels with ins where they share enough chars (mirrors ABAP pairing pass)
      const minDI = Math.min(dels.length, ins.length);
      const delsPair = [], insPair = [];
      const delsSolo = [], insSolo = [];
      for (let k = 0; k < minDI; k++) {
        if (hasCommonChars(dels[k], ins[k])) {
          delsPair.push(dels[k]); insPair.push(ins[k]);
        } else {
          delsSolo.push(dels[k]); insSolo.push(ins[k]);
        }
      }
      for (let k = minDI; k < dels.length; k++) delsSolo.push(dels[k]);
      for (let k = minDI; k < ins.length; k++)  insSolo.push(ins[k]);

      // 1) Paired rows — inline char-diff
      for (let p = 0; p < delsPair.length; p++) {
        lno++;
        const inline = charDiffHtml(delsPair[p], insPair[p], 'B');
        rows += `<tr style="background:#ffffff"><td class="ln">${lno}</td><td class="cd">${inline}</td></tr>`;
      }
      // 2) Leftover dels (red, no line number)
      for (const d of delsSolo) {
        rows += `<tr style="background:#ffecec"><td class="ln" style="color:#cc0000">-</td><td class="cd" style="color:#cc0000">${escHtml(d)}</td></tr>`;
      }
      // 3) Leftover ins (green)
      for (const i of insSolo) {
        lno++;
        rows += `<tr style="background:#eaffea"><td class="ln" style="color:#006600">${lno}</td><td class="cd" style="color:#006600">${escHtml(i)}</td></tr>`;
      }
      pos = scan;
    }

    return `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#ffffff;color:#1e1e1e;font:12px/1.5 Consolas,monospace}
.hdr{background:#f3f3f3;padding:5px 12px;border-bottom:1px solid #ddd;color:#444;font-size:11px;display:flex;gap:16px;flex-wrap:wrap}
.ttl{color:#0066aa;font-weight:bold}
.meta{color:#888}
table{border-collapse:collapse;width:100%}
.ln{color:#aaa;text-align:right;padding:1px 10px 1px 5px;user-select:none;min-width:42px;border-right:1px solid #e0e0e0;white-space:nowrap;background:#fafafa}
.cd{padding:1px 8px;white-space:pre}
</style></head><body>
<div class="hdr"><span class="ttl">${escHtml(title)}</span><span class="meta">${escHtml(meta)}</span></div>
<table><tbody>${rows}</tbody></table></body></html>`;
  }

  function renderTwoPane(ops, title, meta, compact) {
    // Simplified 2-pane: side-by-side. Same pairing logic as inline.
    const ctx = 3;
    const show = compact ? buildShowMask(ops, ctx) : null;
    let rows = '';
    let lnoL = 0, lnoR = 0;
    let pos = 0;
    let gapShown = false;

    while (pos < ops.length) {
      const cur = ops[pos];

      if (cur.op === '=') {
        lnoL++; lnoR++;
        if (compact && !show[pos]) {
          if (!gapShown) {
            rows += `<tr style="background:#f0f0f0;color:#888"><td class="ln">...</td><td class="cd">...</td><td class="sep"></td><td class="ln">...</td><td class="cd">...</td></tr>`;
            gapShown = true;
          }
          pos++;
          continue;
        }
        gapShown = false;
        const t = escHtml(cur.text);
        rows += `<tr><td class="ln">${lnoL}</td><td class="cd">${t}</td><td class="sep"></td><td class="ln">${lnoR}</td><td class="cd">${t}</td></tr>`;
        pos++;
        continue;
      }

      const dels = [], ins = [];
      let scan = pos;
      while (scan < ops.length) {
        if (ops[scan].op === '-') { dels.push(ops[scan].text); scan++; }
        else if (ops[scan].op === '+') { ins.push(ops[scan].text); scan++; }
        else break;
      }

      const minDI = Math.min(dels.length, ins.length);
      const delsPair = [], insPair = [];
      const delsSolo = [], insSolo = [];
      for (let k = 0; k < minDI; k++) {
        if (hasCommonChars(dels[k], ins[k])) {
          delsPair.push(dels[k]); insPair.push(ins[k]);
        } else {
          delsSolo.push(dels[k]); insSolo.push(ins[k]);
        }
      }
      for (let k = minDI; k < dels.length; k++) delsSolo.push(dels[k]);
      for (let k = minDI; k < ins.length; k++)  insSolo.push(ins[k]);

      // 1) Paired — char-diff both sides
      for (let p = 0; p < delsPair.length; p++) {
        lnoL++; lnoR++;
        const left  = charDiffHtml(delsPair[p], insPair[p], 'O'); // old highlighted (red)
        const right = charDiffHtml(delsPair[p], insPair[p], 'N'); // new highlighted (green)
        rows += `<tr>
          <td class="ln" style="background:#ffecec">${lnoL}</td>
          <td class="cd" style="background:#ffecec">${left}</td>
          <td class="sep"></td>
          <td class="ln" style="background:#eaffea">${lnoR}</td>
          <td class="cd" style="background:#eaffea">${right}</td></tr>`;
      }
      // 2) Solo dels — left filled, right empty
      for (const d of delsSolo) {
        lnoL++;
        rows += `<tr><td class="ln" style="background:#ffecec">${lnoL}</td><td class="cd" style="background:#ffecec">${escHtml(d)}</td><td class="sep"></td><td class="ln"></td><td class="cd"></td></tr>`;
      }
      // 3) Solo ins — right filled, left empty
      for (const i of insSolo) {
        lnoR++;
        rows += `<tr><td class="ln"></td><td class="cd"></td><td class="sep"></td><td class="ln" style="background:#eaffea">${lnoR}</td><td class="cd" style="background:#eaffea">${escHtml(i)}</td></tr>`;
      }
      pos = scan;
    }

    return `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1e1e1e;font:12px/1.5 Consolas,monospace}
.hdr{background:#f3f3f3;padding:5px 12px;border-bottom:1px solid #ddd;color:#444;font-size:11px;display:flex;gap:16px;flex-wrap:wrap}
.ttl{color:#0066aa;font-weight:bold}.meta{color:#888}
table{border-collapse:collapse;width:100%;table-layout:fixed}
.ln{color:#aaa;text-align:right;padding:1px 8px 1px 4px;user-select:none;width:42px;border-right:1px solid #e0e0e0;white-space:nowrap;background:#fafafa}
.cd{padding:1px 8px;white-space:pre;overflow-x:auto}
.sep{border-left:2px solid #ccc;padding:0;width:2px}
</style></head><body>
<div class="hdr"><span class="ttl">${escHtml(title)}</span><span class="meta">${escHtml(meta)}</span></div>
<table><tbody>${rows}</tbody></table></body></html>`;
  }

  // ─── 5. Debug renderer — dumps ops, blocks, pairing, char-diff outputs ───
  function debugToHtml(ops, opts) {
    opts = opts || {};
    const title = opts.title || '';
    const meta = opts.meta || '';

    // Section A: raw ops list
    let opsRows = '';
    ops.forEach((o, i) => {
      const cls = o.op === '=' ? 'eq' : (o.op === '-' ? 'del' : 'ins');
      opsRows += `<tr class="${cls}"><td class="ln">${i + 1}</td><td class="op">${o.op}</td><td class="cd">${escHtml(o.text) || '<em>&lt;empty&gt;</em>'}</td></tr>`;
    });

    // Section B: walk blocks like the renderer does
    let blocksHtml = '';
    let pos = 0;
    let blockNo = 0;
    while (pos < ops.length) {
      if (ops[pos].op === '=') { pos++; continue; }
      const dels = [], ins = [];
      let scan = pos;
      while (scan < ops.length) {
        if (ops[scan].op === '-') { dels.push(ops[scan].text); scan++; }
        else if (ops[scan].op === '+') { ins.push(ops[scan].text); scan++; }
        else break;
      }
      blockNo++;
      const minDI = Math.min(dels.length, ins.length);
      let pairTbl = '';
      for (let k = 0; k < minDI; k++) {
        const a = dels[k], b = ins[k];
        const trimA = a.replace(/^\s+|\s+$/g, '');
        const trimB = b.replace(/^\s+|\s+$/g, '');
        let cp = 0;
        while (cp < trimA.length && cp < trimB.length && trimA[cp] === trimB[cp]) cp++;
        const paired = cp >= 3;
        const verdict = paired
          ? `<span class="ok">PAIR (cp=${cp})</span>`
          : `<span class="bad">SOLO (cp=${cp} &lt; 3)</span>`;
        const inline = paired ? charDiffHtml(a, b, 'B') : '<em>—</em>';
        pairTbl += `<tr>
          <td class="ln">${k + 1}</td>
          <td class="cd"><span class="del-tag">−</span> <code>${escHtml(a) || '<em>&lt;empty&gt;</em>'}</code></td>
          <td class="cd"><span class="ins-tag">+</span> <code>${escHtml(b) || '<em>&lt;empty&gt;</em>'}</code></td>
          <td>${verdict}</td>
          <td class="cd">${inline}</td>
        </tr>`;
      }
      let leftover = '';
      for (let k = minDI; k < dels.length; k++) {
        leftover += `<div class="solo del">SOLO − <code>${escHtml(dels[k]) || '<em>&lt;empty&gt;</em>'}</code></div>`;
      }
      for (let k = minDI; k < ins.length; k++) {
        leftover += `<div class="solo ins">SOLO + <code>${escHtml(ins[k]) || '<em>&lt;empty&gt;</em>'}</code></div>`;
      }
      blocksHtml += `
        <div class="block">
          <h3>Block #${blockNo} <span class="meta">(${dels.length} dels, ${ins.length} ins, ops [${pos + 1}..${scan}])</span></h3>
          ${pairTbl ? `<table class="pair">
            <thead><tr><th>k</th><th>del</th><th>ins</th><th>verdict</th><th>char-diff (if paired)</th></tr></thead>
            <tbody>${pairTbl}</tbody>
          </table>` : '<div class="meta">(no del/ins pairs to test)</div>'}
          ${leftover ? `<div class="leftover">${leftover}</div>` : ''}
        </div>`;
      pos = scan;
    }
    if (!blocksHtml) blocksHtml = '<div class="meta">(no change blocks)</div>';

    return `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#222;font:12px/1.5 Segoe UI,sans-serif;padding:10px}
h2{font-size:13px;margin:14px 0 6px;color:#0066aa;border-bottom:1px solid #ddd;padding-bottom:3px}
h3{font-size:12px;margin:8px 0 4px;color:#444}
.hdr{background:#f3f3f3;padding:6px 10px;border:1px solid #ddd;color:#444;display:flex;gap:14px;flex-wrap:wrap;margin-bottom:8px}
.ttl{color:#0066aa;font-weight:bold}.meta{color:#888;font-weight:normal;font-size:11px}
table{border-collapse:collapse;width:100%;font:11px/1.4 Consolas,monospace;margin-bottom:6px}
th,td{padding:2px 6px;border:1px solid #e0e0e0;text-align:left;vertical-align:top}
th{background:#fafafa;font-weight:600}
.ln{color:#aaa;text-align:right;width:40px;background:#fafafa}
.op{width:24px;text-align:center;font-weight:bold}
tr.eq td{color:#888}
tr.del{background:#ffecec}
tr.del td.op{color:#cc0000}
tr.ins{background:#eaffea}
tr.ins td.op{color:#006600}
.cd{white-space:pre;font:11px/1.4 Consolas,monospace}
code{font:11px/1.4 Consolas,monospace;background:#f7f7f7;padding:1px 4px;border-radius:2px}
.block{border:1px solid #ddd;padding:6px;margin-bottom:8px;border-radius:3px;background:#fcfcfc}
.pair th{background:#eef}
.ok{color:#006600;font-weight:bold}
.bad{color:#cc0000;font-weight:bold}
.del-tag{color:#cc0000;font-weight:bold}
.ins-tag{color:#006600;font-weight:bold}
.solo{margin:2px 0;padding:2px 6px;border-radius:2px;font:11px/1.4 Consolas,monospace}
.solo.del{background:#ffecec;color:#cc0000}
.solo.ins{background:#eaffea;color:#006600}
.leftover{margin-top:4px}
em{color:#aaa;font-style:italic}
</style></head><body>
<div class="hdr"><span class="ttl">DEBUG: ${escHtml(title)}</span><span class="meta">${escHtml(meta)}</span></div>

<h2>1. Diff ops (${ops.length} total)</h2>
<table><thead><tr><th>#</th><th>op</th><th>text</th></tr></thead><tbody>${opsRows}</tbody></table>

<h2>2. Change blocks &amp; pairing decisions</h2>
${blocksHtml}
</body></html>`;
  }

  global.AVEDiff = {
    computeDiff,
    hasCommonChars,
    charDiffHtml,
    diffToHtml,
    debugToHtml,
  };
})(window);
