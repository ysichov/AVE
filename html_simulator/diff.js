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
    if (!lA.length || !lB.length) return true;

    if (lA === lB) return true;

    const shorter = lA.length < lB.length ? lA : lB;
    const longer = lA.length < lB.length ? lB : lA;
    if (longer.slice(1) === shorter) return true;
    if (longer.slice(1).replace(/^\s+/, '') === shorter) return true;

    let cp = 0;
    while (cp < lA.length && cp < lB.length && lA[cp] === lB[cp]) cp++;
    // Default rule: >=3 chars common prefix.
    return cp >= 3;
  }

  function computeLinePairs(oldLines, newLines) {
    const nOld = oldLines.length;
    const nNew = newLines.length;
    const cols = nNew + 1;
    const rows = nOld + 1;
    const dp = new Int32Array(rows * cols);

    for (let i = 1; i <= nOld; i++) {
      for (let j = 1; j <= nNew; j++) {
        if (hasCommonChars(oldLines[i - 1], newLines[j - 1])) {
          dp[i * cols + j] = dp[(i - 1) * cols + (j - 1)] + 1;
        } else {
          const vUp = dp[(i - 1) * cols + j];
          const vLeft = dp[i * cols + (j - 1)];
          dp[i * cols + j] = vUp >= vLeft ? vUp : vLeft;
        }
      }
    }

    const pairs = [];
    let i = nOld, j = nNew;
    while (i > 0 && j > 0) {
      if (hasCommonChars(oldLines[i - 1], newLines[j - 1])) {
        pairs.push([i - 1, j - 1]);
        i--;
        j--;
      } else {
        const vUp = dp[(i - 1) * cols + j];
        const vLeft = dp[i * cols + (j - 1)];
        if (vUp >= vLeft) i--;
        else j--;
      }
    }

    return pairs.reverse();
  }

  // ─── 3. Character-level diff highlight (matches METHOD char_diff_html) ───
  function escHtml(s) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
  function escCell(s) {
    // Make space-only lines visible even outside highlighted spans.
    return escHtml(s).replace(/ /g, '&nbsp;');
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

  const CMT_BG = '#fafae8';
  function isComment(s) { return /^\s*["*]/.test(s); }
  // Append comment bg to an existing style string (for cells that already have style=)
  function cmt(s) { return isComment(s) ? ';background:' + CMT_BG : ''; }
  // Standalone style attribute for cells with no existing style
  function cmtAttr(s) { return isComment(s) ? ' style="background:' + CMT_BG + '"' : ''; }

  function buildCharDiffOps(oldT, newT) {
    const lo = oldT.length;
    const ln = newT.length;
    const cols = ln + 1;
    const rows = lo + 1;
    const dp = new Int32Array(rows * cols);

    for (let i = 1; i <= lo; i++) {
      for (let j = 1; j <= ln; j++) {
        if (oldT[i - 1] === newT[j - 1]) {
          dp[i * cols + j] = dp[(i - 1) * cols + (j - 1)] + 1;
        } else {
          const vUp = dp[(i - 1) * cols + j];
          const vLeft = dp[i * cols + (j - 1)];
          dp[i * cols + j] = vUp >= vLeft ? vUp : vLeft;
        }
      }
    }

    const result = [];
    let i = lo, j = ln;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && oldT[i - 1] === newT[j - 1]) {
        result.push({ op: '=', text: oldT[i - 1] });
        i--;
        j--;
      } else if (j > 0 && (i === 0 || dp[i * cols + (j - 1)] > dp[(i - 1) * cols + j])) {
        result.push({ op: '+', text: newT[j - 1] });
        j--;
      } else if (i > 0) {
        result.push({ op: '-', text: oldT[i - 1] });
        i--;
      }
    }

    return result.reverse();
  }

  function renderCharDiffOps(ops, side) {
    let out = '';
    let buf = '';
    let bufOp = '';

    function flush() {
      if (!buf) return;
      if (bufOp === '=') out += escHtml(buf);
      else if (bufOp === '-' && side !== 'N') out += `<span style="${DEL_STYLE}">${escMid(buf)}</span>`;
      else if (bufOp === '+' && side !== 'O') out += `<span style="${INS_STYLE}">${escMid(buf)}</span>`;
      buf = '';
      bufOp = '';
    }

    for (const part of ops) {
      if (part.op !== bufOp) flush();
      bufOp = part.op;
      buf += part.text;
    }
    flush();
    return out;
  }

  function charDiffHtml(ivOld, ivNew, ivSide) {
    ivSide = ivSide || 'B';
    const oldT = rstrip(ivOld);
    const newT = rstrip(ivNew);
    return renderCharDiffOps(buildCharDiffOps(oldT, newT), ivSide);
  }

  // ─── 4. Render diff → HTML (mirrors METHOD diff_to_html, inline branch) ──
  function diffToHtml(ops, opts) {
    opts = opts || {};
    const title = opts.title || '';
    const meta = opts.meta || '';
    const twoPane = !!opts.twoPane;
    const compact = !!opts.compact;

    if (twoPane) {
      return renderTwoPaneAligned(ops, title, meta, compact);
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
        rows += `<tr style="background:#ffffff"><td class="ln">${lno}</td><td class="cd"${cmtAttr(cur.text)}>${escCell(cur.text)}</td></tr>`;
        pos++;
        continue;
      }

      // Collect EXTENDED block: consecutive '-'/'+' AND short bridging
      // empty '=' lines (max 1 in a row) when more changes follow.
      // This lets us pair changes across blank-line gaps that LCS inserted.
      const block = [];   // array of {op, text} in original order
      let scan = pos;
      while (scan < ops.length) {
        const o = ops[scan];
        if (o.op === '-' || o.op === '+') {
          block.push(o);
          scan++;
        } else if (o.op === '=' && /^\s*$/.test(o.text)) {
          // tentative bridge — peek ahead through up to 1 more empty '='
          let peek = scan + 1;
          let extra = 0;
          let moreChanges = false;
          while (peek < ops.length) {
            const p = ops[peek];
            if (p.op === '-' || p.op === '+') { moreChanges = true; break; }
            if (p.op === '=' && /^\s*$/.test(p.text) && extra < 1) { extra++; peek++; continue; }
            break;
          }
          if (moreChanges) { block.push(o); scan++; }
          else break;
        } else {
          break;
        }
      }

      // Within the extended block: pair '-' with '+' by index.
      // Skip whitespace-only lines from pairing — they have no chars to
      // match and would otherwise eat an index slot, breaking alignment
      // between real changes. They still render as solo via the block walk.
      const dels = [], ins = [];          // texts
      const delIdx = [], insIdx = [];     // positions in block[]
      block.forEach((o, idx) => {
        if (o.op === '-' && !/^\s*$/.test(o.text)) { dels.push(o.text); delIdx.push(idx); }
        else if (o.op === '+' && !/^\s*$/.test(o.text)) { ins.push(o.text); insIdx.push(idx); }
      });

      // status[i] for each block position: 'P' = render paired here,
      //                                    'C' = consumed (skip), '' = solo/equal
      const status = new Array(block.length).fill('');
      const inlineHtml = new Array(block.length).fill('');
      const pairs = computeLinePairs(dels, ins);
      for (const [dk, ik] of pairs) {
        const di = delIdx[dk], ii = insIdx[ik];
        const first = Math.min(di, ii);
        const other = Math.max(di, ii);
        status[first] = 'P';
        status[other] = 'C';
        inlineHtml[first] = charDiffHtml(dels[dk], ins[ik], 'B');
      }

      // Render block ops in original order
      for (let bi = 0; bi < block.length; bi++) {
        const o = block[bi];
        const st = status[bi];
        if (o.op === '=') {
          lno++;
          rows += `<tr style="background:#ffffff"><td class="ln">${lno}</td><td class="cd"${cmtAttr(o.text)}>${escCell(o.text)}</td></tr>`;
        } else if (o.op === '-') {
          if (st === 'P') {
            lno++;
            rows += `<tr style="background:#ffffff"><td class="ln">${lno}</td><td class="cd"${cmtAttr(o.text)}>${inlineHtml[bi]}</td></tr>`;
          } else if (st === 'C') {
            // skip — already rendered as part of paired row
          } else {
            rows += `<tr style="background:#ffecec"><td class="ln" style="color:#cc0000">-</td><td class="cd" style="color:#cc0000${cmt(o.text)}">${escCell(o.text)}</td></tr>`;
          }
        } else { // '+'
          if (st === 'P') {
            lno++;
            rows += `<tr style="background:#ffffff"><td class="ln">${lno}</td><td class="cd"${cmtAttr(o.text)}>${inlineHtml[bi]}</td></tr>`;
          } else if (st === 'C') {
            // skip
          } else {
            lno++;
            rows += `<tr style="background:#eaffea"><td class="ln" style="color:#006600">${lno}</td><td class="cd" style="color:#006600${cmt(o.text)}">${escCell(o.text)}</td></tr>`;
          }
        }
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
    // 2-pane: new on LEFT, old on RIGHT
    const ctx = 3;
    const show = compact ? buildShowMask(ops, ctx) : null;
    let rows = '';
    let lnoNew = 0, lnoOld = 0;  // lnoNew = left, lnoOld = right
    let pos = 0;
    let gapShown = false;

    while (pos < ops.length) {
      const cur = ops[pos];

      if (cur.op === '=') {
        lnoNew++; lnoOld++;
        if (compact && !show[pos]) {
          if (!gapShown) {
            rows += `<tr style="background:#f0f0f0;color:#888"><td class="ln">...</td><td class="cd">...</td><td class="sep"></td><td class="ln">...</td><td class="cd">...</td></tr>`;
            gapShown = true;
          }
          pos++;
          continue;
        }
        gapShown = false;
        const t = escCell(cur.text);
        rows += `<tr><td class="ln">${lnoNew}</td><td class="cd">${t}</td><td class="sep"></td><td class="ln">${lnoOld}</td><td class="cd">${t}</td></tr>`;
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

      const delsPair = [], insPair = [];
      const delsSolo = [], insSolo = [];
      const pairedDel = new Array(dels.length).fill(false);
      const pairedIns = new Array(ins.length).fill(false);
      const pairs = computeLinePairs(dels, ins);
      for (const [dk, ik] of pairs) {
        pairedDel[dk] = true;
        pairedIns[ik] = true;
        delsPair.push(dels[dk]);
        insPair.push(ins[ik]);
      }
      for (let k = 0; k < ins.length; k++) {
        if (!pairedIns[k]) insSolo.push(ins[k]);
      }
      for (let k = 0; k < dels.length; k++) {
        if (!pairedDel[k]) delsSolo.push(dels[k]);
      }

      // 1) Paired — char-diff both sides; new on LEFT, old on RIGHT
      for (let p = 0; p < delsPair.length; p++) {
        lnoNew++; lnoOld++;
        const newSide = charDiffHtml(delsPair[p], insPair[p], 'N'); // new highlighted (green)
        const oldSide = charDiffHtml(delsPair[p], insPair[p], 'O'); // old highlighted (red)
        rows += `<tr>
          <td class="ln" style="background:#eaffea">${lnoNew}</td>
          <td class="cd" style="background:#eaffea">${newSide}</td>
          <td class="sep"></td>
          <td class="ln" style="background:#ffecec">${lnoOld}</td>
          <td class="cd" style="background:#ffecec">${oldSide}</td></tr>`;
      }
      // 2) Solo ins (new lines) — left filled, right empty
      for (const i of insSolo) {
        lnoNew++;
        rows += `<tr><td class="ln" style="background:#eaffea">${lnoNew}</td><td class="cd" style="background:#eaffea">${escCell(i)}</td><td class="sep"></td><td class="ln"></td><td class="cd"></td></tr>`;
      }
      // 3) Solo dels (old lines) — right filled, left empty
      for (const d of delsSolo) {
        lnoOld++;
        rows += `<tr><td class="ln"></td><td class="cd"></td><td class="sep"></td><td class="ln" style="background:#ffecec">${lnoOld}</td><td class="cd" style="background:#ffecec">${escCell(d)}</td></tr>`;
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
  function renderTwoPaneAligned(ops, title, meta, compact) {
    const ctx = 3;
    const show = compact ? buildShowMask(ops, ctx) : null;
    let rows = '';
    let lnoNew = 0, lnoOld = 0;
    let pos = 0;
    let gapShown = false;

    while (pos < ops.length) {
      const cur = ops[pos];

      if (cur.op === '=') {
        lnoNew++;
        lnoOld++;
        if (compact && !show[pos]) {
          if (!gapShown) {
            rows += `<tr style="background:#f0f0f0;color:#888"><td class="ln">...</td><td class="cd">...</td><td class="sep"></td><td class="ln">...</td><td class="cd">...</td></tr>`;
            gapShown = true;
          }
          pos++;
          continue;
        }
        gapShown = false;
        const t = escCell(cur.text);
        rows += `<tr><td class="ln">${lnoNew}</td><td class="cd"${cmtAttr(cur.text)}>${t}</td><td class="sep"></td><td class="ln">${lnoOld}</td><td class="cd"${cmtAttr(cur.text)}>${t}</td></tr>`;
        pos++;
        continue;
      }

      const dels = [];
      const ins = [];
      const delIdx = [];
      const insIdx = [];
      let scan = pos;
      while (scan < ops.length) {
        const op = ops[scan];
        if (op.op === '-') {
          dels.push(op.text);
          delIdx.push(scan - pos);
          scan++;
        } else if (op.op === '+') {
          ins.push(op.text);
          insIdx.push(scan - pos);
          scan++;
        } else {
          break;
        }
      }

      const status = new Array(scan - pos).fill('');
      const pairData = new Array(scan - pos).fill(null);
      const pairs = computeLinePairs(dels, ins);
      for (const [dk, ik] of pairs) {
        const di = delIdx[dk];
        const ii = insIdx[ik];
        const first = Math.min(di, ii);
        const other = Math.max(di, ii);
        status[first] = 'P';
        status[other] = 'C';
        pairData[first] = { oldText: dels[dk], newText: ins[ik] };
      }

      for (let bi = pos; bi < scan; bi++) {
        const rel = bi - pos;
        const st = status[rel];
        const op = ops[bi];

        if (st === 'P') {
          lnoNew++;
          lnoOld++;
          const newSide = charDiffHtml(pairData[rel].oldText, pairData[rel].newText, 'N');
          const oldSide = charDiffHtml(pairData[rel].oldText, pairData[rel].newText, 'O');
          rows += `<tr>
            <td class="ln">${lnoNew}</td>
            <td class="cd"${cmtAttr(pairData[rel].newText)}>${newSide}</td>
            <td class="sep"></td>
            <td class="ln">${lnoOld}</td>
            <td class="cd"${cmtAttr(pairData[rel].oldText)}>${oldSide}</td></tr>`;
        } else if (st === 'C') {
          // already rendered as part of its pair
        } else if (op.op === '+') {
          lnoNew++;
          rows += `<tr><td class="ln" style="background:#eaffea">${lnoNew}</td><td class="cd" style="background:#eaffea${cmt(op.text)}">${escCell(op.text)}</td><td class="sep"></td><td class="ln"></td><td class="cd"></td></tr>`;
        } else {
          lnoOld++;
          rows += `<tr><td class="ln"></td><td class="cd"></td><td class="sep"></td><td class="ln" style="background:#ffecec">${lnoOld}</td><td class="cd" style="background:#ffecec${cmt(op.text)}">${escCell(op.text)}</td></tr>`;
        }
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

    // Section B: walk EXTENDED blocks like the renderer does (bridges short empty '=' gaps)
    let blocksHtml = '';
    let pos = 0;
    let blockNo = 0;
    while (pos < ops.length) {
      if (ops[pos].op === '=') { pos++; continue; }
      const block = [];
      let scan = pos;
      while (scan < ops.length) {
        const o = ops[scan];
        if (o.op === '-' || o.op === '+') { block.push(o); scan++; }
        else if (o.op === '=' && /^\s*$/.test(o.text)) {
          let peek = scan + 1, extra = 0, more = false;
          while (peek < ops.length) {
            const p = ops[peek];
            if (p.op === '-' || p.op === '+') { more = true; break; }
            if (p.op === '=' && /^\s*$/.test(p.text) && extra < 1) { extra++; peek++; continue; }
            break;
          }
          if (more) { block.push(o); scan++; } else break;
        } else break;
      }
      // Skip whitespace-only lines from pairing (mirror renderInline)
      const dels = block.filter(o => o.op === '-' && !/^\s*$/.test(o.text)).map(o => o.text);
      const ins  = block.filter(o => o.op === '+' && !/^\s*$/.test(o.text)).map(o => o.text);
      const pairs = computeLinePairs(dels, ins);
      const pairedDel = new Array(dels.length).fill(false);
      const pairedIns = new Array(ins.length).fill(false);
      pairs.forEach(([dk, ik]) => {
        pairedDel[dk] = true;
        pairedIns[ik] = true;
      });
      blockNo++;
      let pairTbl = '';
      for (const [dk, ik] of pairs) {
        const a = dels[dk], b = ins[ik];
        const trimA = a.replace(/^\s+|\s+$/g, '');
        const trimB = b.replace(/^\s+|\s+$/g, '');
        let cp = 0;
        while (cp < trimA.length && cp < trimB.length && trimA[cp] === trimB[cp]) cp++;
        const sameAfterTrim = trimA === trimB;
        const shorter = trimA.length < trimB.length ? trimA : trimB;
        const longer = trimA.length < trimB.length ? trimB : trimA;
        const leadingShift = longer.slice(1) === shorter;
        const leadingShiftWithSpaces = longer.slice(1).replace(/^\s+/, '') === shorter;
        const paired = sameAfterTrim || leadingShift || leadingShiftWithSpaces || cp >= 3;
        const verdict = paired
          ? `<span class="ok">PAIR (${sameAfterTrim ? 'same after trim' : (leadingShift ? 'leading +/-1 char' : (leadingShiftWithSpaces ? 'leading char + spaces' : `cp=${cp}`))})</span>`
          : `<span class="bad">SOLO (cp=${cp} &lt; 3)</span>`;
        const inline = paired ? charDiffHtml(a, b, 'B') : '<em>—</em>';
        pairTbl += `<tr>
          <td class="ln">${dk + 1}/${ik + 1}</td>
          <td class="cd"><span class="del-tag">−</span> <code>${escHtml(a) || '<em>&lt;empty&gt;</em>'}</code></td>
          <td class="cd"><span class="ins-tag">+</span> <code>${escHtml(b) || '<em>&lt;empty&gt;</em>'}</code></td>
          <td>${verdict}</td>
          <td class="cd">${inline}</td>
        </tr>`;
      }
      let leftover = '';
      for (let k = 0; k < dels.length; k++) {
        leftover += `<div class="solo del">SOLO − <code>${escHtml(dels[k]) || '<em>&lt;empty&gt;</em>'}</code></div>`;
      }
      for (let k = 0; k < ins.length; k++) {
        leftover += `<div class="solo ins">SOLO + <code>${escHtml(ins[k]) || '<em>&lt;empty&gt;</em>'}</code></div>`;
      }
      const bridged = block.filter(o => o.op === '=').length;
      const bridgeNote = bridged ? ` <span class="meta">— bridged ${bridged} empty '=' line(s)</span>` : '';
      blocksHtml += `
        <div class="block">
          <h3>Block #${blockNo} <span class="meta">(${dels.length} dels, ${ins.length} ins, ops [${pos + 1}..${scan}])</span>${bridgeNote}</h3>
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
