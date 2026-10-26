/* charts.js -- SVG figure library (no external chart dependency).  All figures are drawn from API data. */
const SVGNS = 'http://www.w3.org/2000/svg';
function S(tag, attrs, ...kids) {
  const e = document.createElementNS(SVGNS, tag);
  if (attrs) for (const k in attrs) { if (k === 'text') e.textContent = attrs[k]; else e.setAttribute(k, attrs[k]); }
  kids.flat().forEach(c => { if (c != null) e.append(c); });
  return e;
}
function svgRoot(w, h) { return S('svg', { viewBox: `0 0 ${w} ${h}`, class: 'viz', role: 'img', preserveAspectRatio: 'xMidYMid meet' }); }
// text with a subscript:  T_r  ->  sub('T','r')
function symText(x, y, base, sub, attrs = {}) {
  const t = S('text', Object.assign({ x, y }, attrs));
  t.append(S('tspan', { text: base }));
  if (sub) t.append(S('tspan', { text: sub, dy: 3, 'font-size': '70%' }));
  return t;
}
function arrowDefs() {
  return S('defs', null, S('marker', { id: 'ah', viewBox: '0 0 10 10', refX: 9, refY: 5, markerWidth: 7, markerHeight: 7, orient: 'auto-start-reverse' },
    S('path', { d: 'M0 0L10 5L0 10z', style: 'fill:var(--muted)' })));
}
const nice = (x, d = 2) => (x == null || !isFinite(x)) ? 'n/a' : (Math.abs(x) >= 1000 ? x.toFixed(0) : (+x.toFixed(d)).toString());

/* ---------- state-variable meta: symbol (base, subscript), used in SVG labels ---------- */
const VSYM = { th: ['T', 'r'], tmis: ['r', 'T'], x: ['X', ''], s: ['S', ''], qr: ['Q', 'r'], tin: ['T', 'in'], tjin: ['T', 'j,in'], tj: ['T', 'j'],
  pres: ['r', 'P'], mf: ['m', 'f'], cain: ['C', 'A,in'], ph: ['pH', ''], vr: ['V', 'r'], na: ['N', 'a'], pj: ['P', 'j'], mj: ['m', 'j'],
  vrms: ['V', 'RMS'], im: ['I', 'm'], ebal: ['ρ', 'E'] };
const FSYM = { fk: 'K', ft: 'T', fh: 'H', fc: 'C', fm: 'M', fq: 'Q', fp: 'P', fj: 'J', fs: 'S', fi: 'I', fr: 'R', fn: 'N' };

/* ---------- Figure: tolerance-normalised deviation chart ---------- */
function devChart(states) {
  const rows = states.slice().sort((a, b) => Math.abs(norm(b)) - Math.abs(norm(a)));
  function norm(e) { if (e.state === 'normal' && e.deviation === 0) return 0; const d = e.deviation; if (d >= 0) return e.high ? d / e.high : 0; return e.low ? d / Math.abs(e.low) : 0; }
  const W = 720, rh = 22, top = 34, left = 200, right = 30, H = top + rows.length * rh + 34, cx0 = left, cw = W - left - right, clamp = 4;
  const xo = v => cx0 + (Math.max(-clamp, Math.min(clamp, v)) + clamp) / (2 * clamp) * cw;
  const svg = svgRoot(W, H);
  svg.append(S('rect', { x: xo(-1), y: top - 6, width: xo(1) - xo(-1), height: rows.length * rh + 6, class: 'band' }));
  for (const t of [-4, -2, -1, 0, 1, 2, 4]) {
    svg.append(S('line', { x1: xo(t), x2: xo(t), y1: top - 6, y2: top + rows.length * rh, class: 'axis' }));
    svg.append(S('text', { x: xo(t), y: H - 12, 'text-anchor': 'middle', class: 'small muted', text: String(t) }));
  }
  svg.append(S('text', { x: cx0 + cw / 2, y: H - 0, 'text-anchor': 'middle', class: 'small muted', text: 'Deviation normalised by the tolerance bound (shaded band = within tolerance)' }));
  rows.forEach((e, i) => {
    const y = top + i * rh, n = norm(e), x0 = xo(0), x1 = xo(n);
    const lab = symText(left - 10, y + 13, VSYM[e.var] ? VSYM[e.var][0] : e.var, VSYM[e.var] ? VSYM[e.var][1] : '', { 'text-anchor': 'end', class: 'svg-md' });
    svg.append(lab);
    svg.append(S('rect', { x: Math.min(x0, x1), y: y + 3, width: Math.max(1.5, Math.abs(x1 - x0)), height: rh - 8, class: 'bar-' + e.state }));
    if (Math.abs(n) >= clamp) svg.append(S('text', { x: n > 0 ? W - right + 4 : 4, y: y + 14, class: 'small muted', text: n > 0 ? '>' : '<' }));
  });
  return svg;
}

/* ---------- Horizontal bar chart: items [{label, value, cls}] ---------- */
function barChart(items, opts = {}) {
  const W = 640, rh = 26, top = 8, left = opts.left || 230, right = 60, H = top + items.length * rh + 26;
  const max = opts.max || Math.max(...items.map(i => i.value), 1e-9);
  const svg = svgRoot(W, H);
  items.forEach((it, i) => {
    const y = top + i * rh, w = (it.value / max) * (W - left - right);
    svg.append(S('text', { x: left - 8, y: y + 15, 'text-anchor': 'end', class: 'svg-md', text: it.label.length > 38 ? it.label.slice(0, 36) + '...' : it.label }));
    svg.append(S('rect', { x: left, y: y + 3, width: Math.max(1, w), height: rh - 9, class: it.cls || 's1f' }));
    svg.append(S('text', { x: left + w + 6, y: y + 15, class: 'small muted', text: nice(it.value, opts.dec == null ? 2 : opts.dec) + (opts.unit || '') }));
  });
  svg.append(S('line', { x1: left, x2: left, y1: top, y2: top + items.length * rh, class: 'axis' }));
  if (opts.xlabel) svg.append(S('text', { x: left + (W - left - right) / 2, y: H - 6, 'text-anchor': 'middle', class: 'small muted', text: opts.xlabel }));
  return svg;
}

/* ---------- Grouped vertical bars: groups [{label, vals:{metric:value}}], metrics [{key,label,cls}] ---------- */
function groupedBars(groups, metrics, opts = {}) {
  const W = 720, H = 300, l = 46, r = 14, t = 16, b = 56, ymax = opts.ymax || 1;
  const gw = (W - l - r) / groups.length, bw = Math.min(26, (gw - 14) / metrics.length);
  const svg = svgRoot(W, H);
  for (let i = 0; i <= 5; i++) {
    const v = ymax * i / 5, y = t + (H - t - b) * (1 - i / 5);
    svg.append(S('line', { x1: l, x2: W - r, y1: y, y2: y, class: 'axis' }));
    svg.append(S('text', { x: l - 6, y: y + 3, 'text-anchor': 'end', class: 'small muted', text: v.toFixed(1) }));
  }
  groups.forEach((g, gi) => {
    const x0 = l + gi * gw + (gw - bw * metrics.length) / 2;
    metrics.forEach((m, mi) => {
      const v = g.vals[m.key] || 0, h = (H - t - b) * Math.min(v, ymax) / ymax;
      svg.append(S('rect', { x: x0 + mi * bw, y: H - b - h, width: bw - 2, height: Math.max(0.5, h), class: m.cls }));
    });
    svg.append(S('text', { x: l + gi * gw + gw / 2, y: H - b + 16, 'text-anchor': 'middle', class: 'svg-md', text: g.label }));
  });
  return svg;
}

/* ---------- Line chart: series [{name, cls, pts:[[x,y]]}] ---------- */
function lineChart(series, opts = {}) {
  const W = 640, H = 300, l = 54, r = 20, t = 16, b = 50;
  const xs = [...new Set(series.flatMap(s => s.pts.map(p => p[0])))].sort((a, c) => a - c);
  const ymax = opts.ymax || Math.max(...series.flatMap(s => s.pts.map(p => p[1])), 1e-9) * 1.1, ymin = opts.ymin || 0;
  const xo = v => l + (xs.length === 1 ? 0.5 : xs.indexOf(v) / (xs.length - 1)) * (W - l - r);
  const yo = v => t + (H - t - b) * (1 - (v - ymin) / (ymax - ymin));
  const svg = svgRoot(W, H);
  for (let i = 0; i <= 5; i++) {
    const v = ymin + (ymax - ymin) * i / 5;
    svg.append(S('line', { x1: l, x2: W - r, y1: yo(v), y2: yo(v), class: 'axis' }));
    svg.append(S('text', { x: l - 6, y: yo(v) + 3, 'text-anchor': 'end', class: 'small muted', text: nice(v, v < 10 ? 2 : 0) }));
  }
  xs.forEach(x => svg.append(S('text', { x: xo(x), y: H - b + 16, 'text-anchor': 'middle', class: 'small muted', text: String(x) })));
  series.forEach(s => {
    svg.append(S('path', { d: s.pts.map((p, i) => (i ? 'L' : 'M') + xo(p[0]) + ' ' + yo(p[1])).join(' '), class: s.cls }));
    s.pts.forEach(p => svg.append(S('circle', { cx: xo(p[0]), cy: yo(p[1]), r: 3.2, class: s.cls + 'f' })));
  });
  if (opts.xlabel) svg.append(S('text', { x: l + (W - l - r) / 2, y: H - 8, 'text-anchor': 'middle', class: 'small muted', text: opts.xlabel }));
  if (opts.ylabel) svg.append(S('text', { x: 14, y: t + (H - t - b) / 2, class: 'small muted', transform: `rotate(-90 14 ${t + (H - t - b) / 2})`, 'text-anchor': 'middle', text: opts.ylabel }));
  return svg;
}

/* ---------- Heatmap / confusion matrix ---------- */
function heatmap(rowLabels, colLabels, get, opts = {}) {
  const cw = 42, ch = 26, l = 70, t = 54, W = l + colLabels.length * cw + 10, H = t + rowLabels.length * ch + 30;
  const svg = svgRoot(W, H);
  const rowMax = r => Math.max(1, ...colLabels.map(c => get(r, c)));
  colLabels.forEach((c, j) => svg.append(S('text', { x: l + j * cw + cw / 2, y: t - 8, 'text-anchor': 'middle', class: 'small', text: c })));
  svg.append(S('text', { x: l + colLabels.length * cw / 2, y: 12, 'text-anchor': 'middle', class: 'small muted', text: 'Predicted' }));
  svg.append(S('text', { x: 4, y: t - 8, class: 'small muted', text: 'True' }));
  rowLabels.forEach((r, i) => {
    svg.append(S('text', { x: l - 8, y: t + i * ch + 17, 'text-anchor': 'end', class: 'small', text: r }));
    const mx = rowMax(r);
    colLabels.forEach((c, j) => {
      const v = get(r, c), diag = r === c;
      svg.append(S('rect', { x: l + j * cw, y: t + i * ch, width: cw - 1, height: ch - 1, style: `fill:${diag ? 'var(--ok)' : 'var(--bad)'};opacity:${v ? 0.15 + 0.75 * v / mx : 0.04}` }));
      if (v) svg.append(S('text', { x: l + j * cw + cw / 2, y: t + i * ch + 17, 'text-anchor': 'middle', class: 'small', text: String(v) }));
    });
  });
  return svg;
}

/* ---------- Generic workflow diagram ----------
   spec = { cols, rows, nodes:[{id,col,row,label:[line,...],count,on}], edges:[[from,to]] } */
function flow(spec) {
  const bw = spec.bw || 158, bh = spec.bh || 56, gx = spec.gx || 44, gy = spec.gy || 44, pad = 14;
  const W = pad * 2 + spec.cols * bw + (spec.cols - 1) * gx, H = pad * 2 + spec.rows * bh + (spec.rows - 1) * gy;
  const svg = svgRoot(W, H); svg.append(arrowDefs());
  const pos = {}; spec.nodes.forEach(n => { pos[n.id] = { x: pad + n.col * (bw + gx), y: pad + n.row * (bh + gy), n }; });
  spec.edges.forEach(([a, b]) => {
    const A = pos[a], B = pos[b]; let d;
    if (A.n.row === B.n.row) {
      if (B.x > A.x) d = `M${A.x + bw} ${A.y + bh / 2} L${B.x} ${B.y + bh / 2}`; else d = `M${A.x} ${A.y + bh / 2} L${B.x + bw} ${B.y + bh / 2}`;
    } else if (A.n.col === B.n.col) {
      d = A.y < B.y ? `M${A.x + bw / 2} ${A.y + bh} L${B.x + bw / 2} ${B.y}` : `M${A.x + bw / 2} ${A.y} L${B.x + bw / 2} ${B.y + bh}`;
    } else {
      const ym = A.y + bh + gy / 2; d = `M${A.x + bw / 2} ${A.y + bh} L${A.x + bw / 2} ${ym} L${B.x + bw / 2} ${ym} L${B.x + bw / 2} ${B.y}`;
    }
    svg.append(S('path', { d, class: 'arrow', 'marker-end': 'url(#ah)' }));
  });
  spec.nodes.forEach(n => {
    const p = pos[n.id], g = S('g');
    g.append(S('rect', { x: p.x, y: p.y, width: bw, height: bh, rx: 6, class: 'box' + (n.on ? ' active' : '') }));
    const lines = n.label, y0 = p.y + bh / 2 - (lines.length - 1) * 7 + 4;
    lines.forEach((ln, i) => g.append(S('text', { x: p.x + bw / 2, y: y0 + i * 14, 'text-anchor': 'middle', class: 'svg-md', text: ln })));
    if (n.count != null) { g.append(S('circle', { cx: p.x + bw - 4, cy: p.y + 4, r: 11, class: 'badge' })); g.append(S('text', { x: p.x + bw - 4, y: p.y + 8, 'text-anchor': 'middle', class: 'badget', text: String(n.count) })); }
    svg.append(g);
  });
  return svg;
}

/* ---------- Fault propagation / causal structure ---------- */
function causalGraph(causal, active = {}) {
  const faults = [...new Set(causal.map(c => c.fault))], syms = [];
  causal.forEach(c => { const k = c.var + ':' + c.state; if (!syms.includes(k)) syms.push(k); });
  syms.sort((a, b) => a.localeCompare(b));
  const W = 760, rf = 30, rs = 17, top = 34, H = Math.max(faults.length * rf, syms.length * rs) + top + 20, xf = 150, xs = 520;
  const svg = svgRoot(W, H);
  svg.append(S('text', { x: xf, y: 16, 'text-anchor': 'middle', class: 'svg-md muted', text: 'Fault hypotheses' }));
  svg.append(S('text', { x: xs + 60, y: 16, 'text-anchor': 'middle', class: 'svg-md muted', text: 'Observable symptoms (variable and state)' }));
  const fy = f => top + faults.indexOf(f) * rf + rf / 2 + ((H - top - 20) - faults.length * rf) / 2;
  const sy = k => top + syms.indexOf(k) * rs + rs / 2;
  const actF = f => (active.faults || []).includes(f), actS = k => (active.symptoms || []).includes(k);
  causal.forEach(c => { const k = c.var + ':' + c.state, on = actF(c.fault) && actS(k);
    svg.append(S('line', { x1: xf + 36, y1: fy(c.fault), x2: xs - 6, y2: sy(k), class: 'edge' + (on ? ' on' : '') })); });
  faults.forEach(f => {
    svg.append(S('rect', { x: xf - 36, y: fy(f) - 11, width: 72, height: 22, rx: 11, class: 'node' + (actF(f) ? ' on' : '') }));
    svg.append(symText(xf - 12, fy(f) + 4, 'F', FSYM[f] || f, { class: 'svg-md', 'font-weight': actF(f) ? 700 : 400 }));
  });
  syms.forEach(k => {
    const [v, st] = k.split(':');
    svg.append(S('rect', { x: xs, y: sy(k) - 8, width: 150, height: 15, rx: 3, class: 'node sym' + (actS(k) ? ' on' : '') }));
    const t = S('text', { x: xs + 6, y: sy(k) + 3, class: 'small' }); t.append(S('tspan', { text: VSYM[v] ? VSYM[v][0] : v }));
    if (VSYM[v] && VSYM[v][1]) t.append(S('tspan', { text: VSYM[v][1], dy: 2, 'font-size': '70%' }));
    t.append(S('tspan', { text: ' ' + (st === 'high' ? 'high' : 'low'), dy: -2 })); svg.append(t);
  });
  return svg;
}

/* ---------- Industrial schematic (jacketed CSTR) with instrument values ---------- */
const TAGS = [
  { k: 'tin', tag: 'TT', x: 150, y: 128, lx: 96, ly: 92, u: 'K', sv: 'tin' }, { k: 'mf', tag: 'FT', x: 190, y: 156, lx: 150, ly: 168, u: 'kg/s', sv: 'mf' },
  { k: 'cain', tag: 'AT', x: 118, y: 156, lx: 36, ly: 168, u: 'mol/m³', sv: 'cain' }, { k: 'ph', tag: 'AT', x: 68, y: 128, lx: 20, ly: 92, u: '', sv: 'ph' },
  { k: 'tr', tag: 'TT', x: 300, y: 215, lx: 270, ly: 238, u: 'K', sv: 'tmis' }, { k: 'vr', tag: 'LT', x: 232, y: 265, lx: 124, ly: 262, u: 'm³', sv: 'vr' },
  { k: 'pr', tag: 'PT', x: 470, y: 62, lx: 440, ly: 24, u: 'kPa', sv: 'pres' }, { k: 'na', tag: 'ST', x: 322, y: 62, lx: 244, ly: 14, u: 'rpm', sv: 'na' },
  { k: 'im', tag: 'JT', x: 380, y: 38, lx: 396, ly: 8, u: 'A', sv: 'im' }, { k: 'vrms', tag: 'VT', x: 400, y: 112, lx: 410, ly: 118, u: 'mm/s', sv: 'vrms' },
  { k: 'tjin', tag: 'TT', x: 150, y: 330, lx: 100, ly: 350, u: 'K', sv: 'tjin' }, { k: 'mj', tag: 'FT', x: 190, y: 330, lx: 160, ly: 370, u: 'kg/s', sv: 'mj' },
  { k: 'tj', tag: 'TT', x: 560, y: 190, lx: 530, ly: 208, u: 'K', sv: 'tj' }, { k: 'pj', tag: 'PT', x: 610, y: 190, lx: 600, ly: 146, u: 'kPa', sv: 'pj' },
  { k: 'tout', tag: 'TT', x: 540, y: 418, lx: 500, ly: 438, u: 'K', sv: 'th' }, { k: 'ca', tag: 'AT', x: 610, y: 418, lx: 580, ly: 438, u: 'mol/m³', sv: 'x' },
  { k: 'qr', tag: 'QT', x: 666, y: 418, lx: 660, ly: 396, u: 'kW', sv: 'qr' }];
const HL = { fk: [[262, 100, 176, 250]], ft: [[20, 110, 235, 40]], fh: [[238, 150, 224, 188]], fc: [[20, 300, 220, 60]], fm: [[302, 28, 100, 292]],
  fq: [[20, 110, 235, 40]], fp: [[400, 40, 330, 40]], fj: [[20, 300, 220, 60], [462, 160, 270, 50]], fs: [[330, 88, 40, 26]], fi: [[284, 198, 34, 34]], fr: [[88, 118, 46, 36]] };
function schematic(raw, states, activeFaults) {
  const W = 760, H = 470, svg = svgRoot(W, H), st = {}; (states || []).forEach(s => st[s.var] = s.state);
  svg.append(arrowDefs());
  // pipes
  svg.append(S('path', { d: 'M20 140 L262 140', class: 'pipe' })); svg.append(S('path', { d: 'M400 350 L400 400 L720 400', class: 'pipe' }));
  svg.append(S('path', { d: 'M20 330 L240 330', class: 'pipe cool' })); svg.append(S('path', { d: 'M462 175 L730 175', class: 'pipe cool' }));
  svg.append(S('path', { d: 'M420 100 L420 60 L730 60', class: 'pipe' }));
  // jacket and vessel
  svg.append(S('rect', { x: 238, y: 150, width: 224, height: 188, rx: 22, class: 'jacket' }));
  svg.append(S('rect', { x: 262, y: 100, width: 176, height: 250, rx: 26, class: 'vessel' }));
  svg.append(S('rect', { x: 264, y: 170, width: 172, height: 178, rx: 24, class: 'liquid' }));
  // agitator
  svg.append(S('rect', { x: 330, y: 28, width: 40, height: 28, rx: 3, class: 'box' })); svg.append(S('text', { x: 350, y: 46, 'text-anchor': 'middle', class: 'svg-md', text: 'M' }));
  svg.append(S('line', { x1: 350, y1: 56, x2: 350, y2: 300, class: 'pipe' })); svg.append(S('line', { x1: 318, y1: 300, x2: 382, y2: 300, class: 'pipe', 'stroke-width': 4 }));
  svg.append(S('circle', { cx: 350, cy: 100, r: 7, class: 'tagc' }));
  // control valve (feed) and relief valve (vent)
  svg.append(S('path', { d: 'M94 128 L124 152 L124 128 L94 152 Z', class: 'tagc' })); svg.append(S('path', { d: 'M668 50 L688 70 L688 50 L668 70 Z', class: 'tagc' }));
  // labels
  const lab = (x, y, t, a = 'start') => svg.append(S('text', { x, y, class: 'small muted', 'text-anchor': a, text: t }));
  lab(22, 134, 'Feed'); lab(722, 394, 'Product', 'end'); lab(22, 324, 'Coolant supply'); lab(728, 169, 'Coolant return', 'end'); lab(728, 54, 'Vent / relief', 'end');
  lab(350, 372, 'Jacketed CSTR', 'middle'); lab(357, 108, 'Seal');
  // fault highlights
  (activeFaults || []).forEach(f => (HL[f] || []).forEach(([x, y, w, h]) => svg.append(S('rect', { x, y, width: w, height: h, rx: 8, class: 'fault-hl' }))));
  // instruments
  TAGS.forEach(t => {
    const has = raw && raw[t.k] != null; const sv = !has ? 'na' : (st[t.sv] || (t.k === 'tr' && st.th) || 'normal');
    const stc = (t.k === 'tr' && has && st.tmis === 'high') ? 'high' : sv;
    svg.append(S('circle', { cx: t.x, cy: t.y, r: 13, class: 'tagc' })); svg.append(S('text', { x: t.x, y: t.y + 3.5, 'text-anchor': 'middle', class: 'small', text: t.tag, 'font-weight': 600 }));
    const txt = has ? `${nice(raw[t.k], Math.abs(raw[t.k]) < 20 ? 2 : 1)} ${t.u}`.trim() : 'not measured';
    const w = Math.max(60, txt.length * 6.2 + 10);
    svg.append(S('line', { x1: t.x, y1: t.y + (t.ly > t.y ? 13 : -13), x2: t.lx + w / 2, y2: t.ly > t.y ? t.ly : t.ly + 18, class: 'axis' }));
    svg.append(S('rect', { x: t.lx, y: t.ly, width: w, height: 18, rx: 3, class: 'vbox s-' + stc }));
    svg.append(S('text', { x: t.lx + w / 2, y: t.ly + 12.5, 'text-anchor': 'middle', class: 'small', text: txt }));
  });
  return svg;
}
