/* app.js -- user interface for the Prolog reactor expert system */
const $ = (s, r = document) => r.querySelector(s);
function el(t, a, ...k) {
  const e = document.createElement(t);
  if (a) for (const x in a) { if (x === 'class') e.className = a[x]; else if (x === 'text') e.textContent = a[x]; else if (x === 'html') e.innerHTML = a[x]; else e.setAttribute(x, a[x]); }
  k.flat().forEach(c => { if (c != null && c !== false) e.append(c.nodeType ? c : document.createTextNode(c)); });
  return e;
}
const api = (u, o) => fetch(u, o).then(r => r.json().then(j => { if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status)); return j; }));
const fmt = (x, d = 3) => x == null ? 'n/a' : (typeof x === 'number' ? (Math.abs(x) >= 1000 ? x.toFixed(0) : (+x.toFixed(d)).toString()) : x);
const pct = x => x == null ? 'n/a' : (100 * x).toFixed(1) + ' %';
function typeset(node) { try { if (window.MathJax && MathJax.typesetPromise) MathJax.typesetPromise([node || document.body]); } catch (e) { /* math rendering is optional */ } }
function clear(n) { n.replaceChildren(); return n; }
const M = t => '\\(' + t + '\\)';
const fsym = id => M('F_{' + ({ fk: 'K', ft: 'T', fh: 'H', fc: 'C', fm: 'M', fq: 'Q', fp: 'P', fj: 'J', fs: 'S', fi: 'I', fr: 'R', fn: 'N' }[id] || id) + '}');
const VTEX = { th: 'T_r', tmis: 'r_T', x: 'X', s: 'S', qr: '\\dot Q_r', tin: 'T_{in}', tjin: 'T_{j,in}', tj: 'T_j', pres: 'r_P', mf: '\\dot m_f', cain: 'C_{A,in}',
  ph: '\\mathrm{pH}', vr: 'V_r', na: 'N_a', pj: 'P_j', mj: '\\dot m_j', vrms: 'V_{RMS}', im: 'I_m', ebal: '\\rho_E',
  tr: 'T_r', tout: 'T_{out}', ca: 'C_A', cb: 'C_B', cp: 'C_P' };
const vsym = v => M(VTEX[v] || v);
const STATUS = { normal: 'Normal operation', fault: 'Fault diagnosed', ambiguous: 'Ambiguous diagnosis: further evidence required', unknown: 'No consistent explanation', insufficient: 'Insufficient observations' };
const SHORT = { ded: 'Deduction', ded_abd: 'Deduction + abduction', ded_cons: 'Deduction + consistency', full: 'Full system' };
const MODES = { full: 'Deduction, abduction and consistency checking', ded_abd: 'Deduction and abduction', ded_cons: 'Deduction and consistency checking', ded: 'Deduction only' };
const INFO = { unique_best: 'a unique best-ranked hypothesis', ambiguous: 'near-tied competing hypotheses', normal_by_default: 'normal operation by default (no primary variable abnormal)',
  few_observations: 'too few observations', fallback_to_deductive: 'fallback to deductive rules (no consistent covering explanation)', deductive: 'deductive rules only', consistency: 'consistency filter applied' };
const infoText = s => String(s).replace(/[\[\]]/g, '').split(',').map(x => INFO[x.trim()] || x.trim().replace(/_/g, ' ')).join('; ');
const MODEL = {};   // knowledge base snapshot from /api/kb

/* ------------------------------------------------------------------ input definitions */
const SENS = [
  ['Temperatures', [['tr', 'Reactor temperature, probe', 'K', 273, 600], ['tout', 'Outlet stream temperature', 'K', 273, 600], ['tin', 'Feed temperature', 'K', 250, 450],
    ['tjin', 'Jacket supply temperature', 'K', 250, 400], ['tj', 'Jacket outlet temperature', 'K', 250, 450]]],
  ['Pressure, flow and level', [['pr', 'Reactor pressure', 'kPa abs', 50, 1500], ['mf', 'Feed mass flow', 'kg/s', 0, 10], ['mj', 'Jacket coolant flow', 'kg/s', 0, 20],
    ['pj', 'Jacket pressure', 'kPa', 0, 1500], ['vr', 'Liquid volume', 'm³', 0, 10], ['qr', 'Stream heat duty', 'kW', -500, 3000]]],
  ['Composition', [['cain', 'Feed concentration of A', 'mol/m³', 0, 10000], ['ca', 'Outlet concentration of A', 'mol/m³', 0, 10000], ['cb', 'Outlet concentration of B', 'mol/m³', 0, 10000],
    ['cp', 'Outlet concentration of P', 'mol/m³', 0, 10000], ['ph', 'Feed pH', '', 0, 14]]],
  ['Mechanical', [['na', 'Agitator speed', 'rpm', 0, 500], ['im', 'Motor current', 'A', 0, 300], ['vrms', 'Vibration RMS', 'mm/s', 0, 100]]]];
let last = null, resTab = 'summary';

function buildForm() {
  const f = clear($('#form'));
  SENS.forEach(([g, vs], gi) => {
    const d = el('details', { class: 'group' }); if (gi < 2) d.open = true;
    d.append(el('summary', { text: g }));
    const b = el('div', { class: 'body' }), row = el('div', { class: 'row g-2' });
    vs.forEach(([k, l, u, lo, hi]) => row.append(el('div', { class: 'col-6' },
      el('label', { class: 'form-label small mb-0', for: 'i_' + k }, vsym(k) + ' ', el('span', { class: 'text-body-secondary', text: l })),
      el('div', { class: 'input-group input-group-sm' }, el('input', { id: 'i_' + k, class: 'form-control', type: 'number', step: 'any', inputmode: 'decimal', min: lo, max: hi }), el('span', { class: 'input-group-text', text: u || '–' })))));
    b.append(row); d.append(b); f.append(d);
  });
  typeset(f);
}
function setObs(o) { SENS.forEach(([g, vs]) => vs.forEach(([k]) => { $('#i_' + k).value = (o && o[k] != null) ? +(+o[k]).toFixed(4) : ''; $('#i_' + k).classList.remove('is-invalid'); })); }
function getObs() {
  const o = {}; let bad = 0;
  SENS.forEach(([g, vs]) => vs.forEach(([k, l, u, lo, hi]) => { const inp = $('#i_' + k), v = inp.value;
    inp.classList.remove('is-invalid'); if (v === '') return; const x = parseFloat(v);
    if (!isFinite(x) || x < lo || x > hi) { inp.classList.add('is-invalid'); bad++; } else o[k] = x; }));
  return { o, bad };
}

/* ------------------------------------------------------------------ consultation */
async function consult() {
  const { o, bad } = getObs(), msg = $('#formmsg'); clear(msg);
  if (bad) { msg.append(el('div', { class: 'alert alert-danger py-2 small', text: bad + ' value(s) outside the physically plausible range are highlighted.' })); return; }
  if (Object.keys(o).length === 0) { msg.append(el('div', { class: 'alert alert-warning py-2 small', text: 'Enter at least one observation or load a scenario.' })); return; }
  const out = clear($('#results')); out.append(el('div', { class: 'card card-body text-body-secondary', text: 'The Prolog inference engine is running.' }));
  try {
    last = await api('/api/diagnose', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ load: $('#load').value, mode: $('#mode').value, obs: o }) });
    resTab = 'summary'; renderResults(); if (window.innerWidth < 992) out.scrollIntoView({ behavior: 'smooth' });
  } catch (e) { clear(out).append(el('div', { class: 'alert alert-danger', text: 'Error: ' + e.message })); }
}
function fig(n, title, node, caption) {
  return el('figure', { class: 'fig' }, el('div', { class: 'figbox' }, node), el('figcaption', null, el('strong', { text: `Figure ${n}. ${title}. ` }), caption || ''));
}
function badge(u) { return el('span', { class: 'badge me-1 urg-' + u, text: u }); }
function table(head, rows, cls = 'table table-sm align-middle') {
  return el('div', { class: 'table-responsive' }, el('table', { class: cls }, el('thead', null, el('tr', null, head.map(h => el('th', { text: h })))),
    el('tbody', null, rows.map(r => el('tr', null, r.map(c => el('td', null, c)))))));
}
function sub(text) { return el('h6', { class: 'serif mt-4 mb-2 text-body-secondary text-uppercase', style: 'font-size:.78rem;letter-spacing:.06em', text }); }

function renderResults() {
  const j = last, out = clear($('#results'));
  const names = j.best.names.join(' together with ');
  const b = el('div', { class: 'card banner mb-3 ' + j.status });
  b.append(el('div', { class: 'kicker', text: STATUS[j.status] }), el('div', { class: 'headline', text: names }));
  const line = el('div', { class: 'mt-2' });
  j.diagnosis.forEach(d => { if (d.id !== 'fn' && d.id !== 'unknown' && d.id !== 'insufficient') line.append(el('span', { class: 'me-3' }, fsym(d.id), ' ', badge(d.urgency), d.confidence != null ? el('span', { class: 'small text-body-secondary', text: `evidence match ${pct(d.confidence)}` }) : null)); });
  b.append(line);
  b.append(el('div', { class: 'small text-body-secondary mt-2', text: `${j.observations} observations at ${j.load} load. Inference: ${MODES[j.mode]}; outcome: ${infoText(j.inference_info)}. Evidence match is the weighted share of the fault's expected symptoms that are present; it is not a probability.` }));
  if (j.alternatives.length) b.append(el('div', { class: 'mt-2 small' }, el('strong', { text: 'Competing hypotheses: ' }), j.alternatives.map(a => el('span', { class: 'badge text-bg-warning me-1', text: a.names.join(' + ') }))));
  out.append(b);
  const tabs = el('ul', { class: 'nav nav-tabs mb-3 no-print' });
  [['summary', 'Summary'], ['explain', 'Expert explanation'], ['reason', 'Reasoning'], ['maint', 'Maintenance'], ['evid', 'Further evidence'], ['data', 'Data and export']].forEach(([k, l]) => {
    const a = el('a', { class: 'nav-link' + (resTab === k ? ' active' : ''), href: '#', text: l }); a.onclick = e => { e.preventDefault(); resTab = k; renderResults(); }; tabs.append(el('li', { class: 'nav-item' }, a)); });
  out.append(tabs);
  const pane = el('div'); out.append(pane);
  ({ summary: tabSummary, explain: tabExplain, reason: tabReason, maint: tabMaint, evid: tabEvid, data: tabData })[resTab](pane, j);
  typeset(out);
}
const activeFaults = j => j.diagnosis.map(d => d.id).filter(x => !['fn', 'unknown', 'insufficient'].includes(x));

function tabSummary(p, j) {
  const c = j.counts, row = el('div', { class: 'row g-2 mb-3' });
  [['Observations', j.observations], ['Abnormal variables', c.abnormal], ['Rules fired', c.rules], ['Minimal explanations', c.covers], ['Eliminated by consistency', c.rejected]]
    .forEach(([k, v]) => row.append(el('div', { class: 'col-6 col-md' }, el('div', { class: 'metric' }, el('div', { class: 'k', text: k }), el('div', { class: 'v', text: v })))));
  p.append(row);
  p.append(fig(1, 'Process schematic with instrument values', schematic(j.raw, j.evidence, activeFaults(j)),
    'Jacketed continuous stirred-tank reactor. Instrument bubbles follow ISA tag letters; frame colour shows the state of the associated variable (green normal, amber low, red high, dashed grey not measured). Red dashed outlines mark subsystems implicated by the diagnosis.'));
  p.append(fig(2, 'Tolerance-normalised deviation of the diagnostic variables', devChart(j.evidence),
    'Each bar is the deviation from the load reference divided by the tolerance bound for that variable. Bars outside the shaded band lie outside the normal operating tolerance.'));
}

function tabExplain(p, j) {
  p.append(el('div', { class: 'card mb-3' }, el('div', { class: 'card-header', text: 'Expert explanation generated by the knowledge base' }),
    el('div', { class: 'card-body' }, j.narrative.map(n => el('div', { class: 'mb-3' }, el('div', { class: 'fw-semibold', text: n.title }), el('div', { text: n.text }))))));
  const ab = j.evidence.filter(e => e.state !== 'normal');
  p.append(sub('Observed evidence outside tolerance'));
  p.append(ab.length ? table(['Variable', 'Description', 'State', 'Deviation', 'Tolerance band'],
    ab.map(e => [vsym(e.var), `${e.label} [${e.unit}]`, el('span', { class: 'st-' + e.state, text: (e.state === 'high' ? 'High' : 'Low') + (e.borderline ? ' (borderline)' : '') }), fmt(e.deviation), `${e.low == null ? '-' : fmt(e.low)} to ${fmt(e.high)}`]))
    : el('p', { class: 'text-body-secondary', text: 'All available observations are inside their tolerance bands.' }));
  p.append(sub('Derived engineering conditions'));
  p.append(j.conditions.length ? el('ul', null, j.conditions.map(c => el('li', { text: c.text.charAt(0).toUpperCase() + c.text.slice(1) }))) : el('p', { class: 'text-body-secondary', text: 'None.' }));
  p.append(sub('Rules fired (deduction)'));
  p.append(j.rules_fired.length ? table(['Rule', 'Concludes', 'Engineering meaning'], j.rules_fired.map(r => [r.id, fsym(r.fault), r.text])) : el('p', { class: 'text-body-secondary', text: 'No rule fired; the conclusion rests on abductive covering or the normal-operation default.' }));
  p.append(sub('Hypotheses eliminated by consistency checking'));
  p.append(j.rejected.length ? table(['Hypothesis', 'Reason for elimination'], j.rejected.map(r => [r.faults.map(f => fsym(f)).join(' '), r.reason])) : el('p', { class: 'text-body-secondary', text: 'None eliminated.' }));
  if (j.proofs.length) { p.append(sub('SLD derivation of the fired rules (Prolog proof tree)')); j.proofs.forEach(s => p.append(el('pre', { class: 'proof', text: s }))); }
}

function reasoningFlow(j) {
  const c = j.counts, on = j.status !== 'normal' && j.status !== 'insufficient';
  return flow({ cols: 4, rows: 3, nodes: [
    { id: 'o', col: 0, row: 0, label: ['Plant observations', 'and load context'], count: j.observations },
    { id: 'e', col: 1, row: 0, label: ['Evidence layer', 'numeric to symbolic states'], count: c.abnormal, on: c.abnormal > 0 },
    { id: 'c', col: 2, row: 0, label: ['Derived engineering', 'conditions'], count: c.conditions, on: c.conditions > 0 },
    { id: 'r', col: 3, row: 0, label: ['Deductive reasoning', 'Horn rules, SLD'], count: c.rules, on: c.rules > 0 },
    { id: 'a', col: 1, row: 1, label: ['Abductive covering', 'minimal fault sets'], count: c.covers, on },
    { id: 'k', col: 2, row: 1, label: ['Consistency checking', 'necessary effects'], count: c.rejected, on: c.rejected > 0 },
    { id: 'n', col: 3, row: 1, label: ['Ranking and selection', 'weights rank only'], on },
    { id: 'x', col: 3, row: 2, label: ['Explanation facility', 'trace and narrative'], on },
    { id: 'm', col: 2, row: 2, label: ['Maintenance planner', 'directives'], on },
    { id: 'z', col: 1, row: 2, label: ['Expert report', 'and visualisations'], on }],
    edges: [['o', 'e'], ['e', 'c'], ['c', 'r'], ['e', 'a'], ['a', 'k'], ['k', 'n'], ['r', 'n'], ['n', 'x'], ['x', 'm'], ['m', 'z']] });
}
function tabReason(p, j) {
  p.append(fig(3, 'Diagnostic reasoning workflow for this consultation', reasoningFlow(j), 'Badges give the number of items produced at each stage for the present case. Highlighted stages contributed to the conclusion.'));
  if (j.ranked.length) p.append(fig(4, 'Ranked hypotheses', barChart(j.ranked.map((r, i) => ({ label: r.names.join(' + '), value: Math.max(0, r.score), cls: i === 0 ? 's1f' : 's2f' })), { dec: 2, xlabel: 'Score: weighted explained evidence + rule support − size penalty' }),
    'Weights only rank candidate explanations; membership of a hypothesis is decided symbolically. Near-tied entries are reported as competing hypotheses.'));
  const conf = j.diagnosis.filter(d => d.confidence != null);
  if (conf.length) p.append(fig(5, 'Evidence match per diagnosed fault', barChart(conf.map(d => ({ label: d.name, value: d.confidence, cls: 's3f' })), { max: 1, dec: 2, xlabel: 'Weighted fraction of observed expected symptoms present' }), 'Computed as the normalised weighted evidence aggregation of the fault, using only the symptoms for which an observation exists.'));
  if (MODEL.causal) {
    const sy = j.evidence.filter(e => e.state !== 'normal').map(e => e.var + ':' + e.state);
    p.append(fig(6, 'Fault propagation and causal structure', causalGraph(MODEL.causal, { faults: activeFaults(j), symptoms: sy }),
      'Edges link each fault hypothesis to the symptoms it explains. Highlighted nodes and edges are the diagnosed faults and the symptoms observed in this consultation.'));
  }
}

function maintFlow(j) {
  const n = j.maintenance.length;
  return flow({ cols: 5, rows: 1, bw: 150, nodes: [
    { id: 'd', col: 0, row: 0, label: ['Diagnosed faults'], count: n, on: true }, { id: 'ev', col: 1, row: 0, label: ['Evidence linkage', 'symptoms supporting'], on: true },
    { id: 'u', col: 2, row: 0, label: ['Directive and urgency', 'ordering'], on: true }, { id: 's', col: 3, row: 0, label: ['Safety constraint', 'attached'], on: true }, { id: 'v', col: 4, row: 0, label: ['Verification step', 'closes the loop'], on: true }],
    edges: [['d', 'ev'], ['ev', 'u'], ['u', 's'], ['s', 'v']] });
}
function tabMaint(p, j) {
  if (!j.maintenance.length) { p.append(el('p', { class: 'text-body-secondary', text: 'No maintenance directive was issued.' })); return; }
  j.maintenance.forEach(m => {
    const d = el('div', { class: 'directive ' + m.urgency });
    d.append(el('div', { class: 'd-flex justify-content-between flex-wrap' }, el('h5', { class: 'mb-1' }, fsym(m.fault), ' ', m.name), el('div', null, badge(m.urgency), el('span', { class: 'small text-body-secondary', text: 'urgency' }))));
    if (m.math) d.append(el('div', { class: 'eq' }, '\\[' + m.math + '\\]'));
    const dl = el('dl', { class: 'mb-0' });
    const add = (k, v) => { if (v) { dl.append(el('dt', { text: k }), el('dd', null, v)); } };
    add('Diagnostic basis', m.evidence.length ? el('span', null, m.evidence.map(t => { const [v, s] = t.split(': '); return el('span', { class: 'me-3' }, vsym(v), ' ', el('span', { class: 'st-' + s, text: s })); })) : 'Established by rule or default; no explained symptom was recorded.');
    add('Failure mechanism', m.mechanism); add('Consequence if uncorrected', m.consequence); add('Maintenance directive', m.action);
    add('Engineering rationale', m.rationale); add('Safety constraint', m.safety); add('Verification', m.verification);
    d.append(dl); p.append(d);
  });
  p.append(fig(7, 'Maintenance-planning workflow', maintFlow(j), 'Each diagnosed fault is mapped to a directive carrying its supporting evidence, urgency, safety constraint and verification step; directives are ordered by urgency.'));
}

function tabEvid(p, j) {
  p.append(el('p', { class: 'text-body-secondary', text: j.next_evidence.length ? 'The expert system requests the following additional evidence to resolve the diagnosis.' : 'The expert system needs no further evidence for this conclusion.' }));
  if (j.next_evidence.length) p.append(table(['Quantity', 'Sensor(s)', 'Reason'], j.next_evidence.map(q => [el('span', null, vsym(q.variable), ` ${q.label} [${q.unit}]`), q.sensors.map(s => vsym(s)).join(' or '),
    q.reason + (q.expected_abnormal_under ? ` (a necessary effect under hypothesis ${q.expected_abnormal_under.join(', ')} of the ranked list)` : '')])));
}

function tabData(p, j) {
  const d = j.derived;
  p.append(sub('Derived quantities'));
  p.append(table(['Quantity', 'Symbol', 'Value'], [['Conversion of A', vsym('x'), fmt(d.conversion)], ['Selectivity to product P', vsym('s'), fmt(d.selectivity)],
    ['Pressure residual [kPa]', vsym('pres'), fmt(d.pressure_residual_kpa)], ['Temperature sensor disagreement [K]', vsym('tmis'), fmt(d.sensor_disagreement_k)], ['Energy-balance residual', vsym('ebal'), fmt(d.energy_residual)]]));
  p.append(sub('All variable states'));
  p.append(table(['Symbol', 'Description', 'State', 'Deviation'], j.evidence.map(e => [vsym(e.var), `${e.label} [${e.unit}]`, el('span', { class: 'st-' + e.state, text: e.state }), fmt(e.deviation)])));
  const row = el('div', { class: 'd-flex gap-2 mt-3 no-print' });
  const bj = el('button', { class: 'btn btn-outline-primary btn-sm', text: 'Download result (JSON)' }); bj.onclick = () => download('consultation.json', JSON.stringify(j, null, 2), 'application/json');
  const bp = el('button', { class: 'btn btn-outline-secondary btn-sm', text: 'Print report' }); bp.onclick = () => window.print();
  row.append(bj, bp); p.append(row);
}
function download(name, text, type) { const a = el('a', { href: URL.createObjectURL(new Blob([text], { type })), download: name }); document.body.append(a); a.click(); a.remove(); }

/* ------------------------------------------------------------------ batch analysis */
const CSVCOLS = ['id', 'load', 'tr', 'tout', 'tin', 'tjin', 'tj', 'pr', 'mf', 'mj', 'pj', 'vr', 'qr', 'cain', 'ca', 'cb', 'cp', 'ph', 'na', 'im', 'vrms'];
async function batchExample() {
  const r = await api('/api/reference?load=nominal'), base = r.obs, rows = [CSVCOLS.join(',')];
  const mk = (id, mod) => { const o = Object.assign({}, base, mod); return [id, 'nominal'].concat(CSVCOLS.slice(2).map(k => o[k] == null ? '' : +(+o[k]).toFixed(3))).join(','); };
  rows.push(mk('normal_run', {}), mk('vent_blockage', { pr: base.pr + 100 }), mk('sensor_drift', { tr: base.tr + 12 }), mk('catalyst_loss', { tr: 340, tout: 340, ca: 1000, cp: 950, cb: 50, pr: 149.7, qr: 125.4 }));
  $('#csv').value = rows.join('\n');
}
function parseCsv(t) {
  const lines = t.trim().split(/\r?\n/).filter(l => l.trim()); if (lines.length < 2) throw new Error('Provide a header row and at least one data row.');
  const h = lines[0].split(',').map(s => s.trim());
  return lines.slice(1).map((l, i) => { const c = l.split(','), o = {}, obj = { obs: o, load: 'nominal', id: 'row' + (i + 1) };
    h.forEach((k, j) => { const v = (c[j] || '').trim(); if (k === 'id' && v) obj.id = v; else if (k === 'load' && v) obj.load = v; else if (v !== '' && k !== 'id' && k !== 'load' && !isNaN(+v)) o[k] = +v; }); return obj; });
}
async function runBatch() {
  const out = clear($('#batchout'));
  try {
    const cases = parseCsv($('#csv').value);
    const j = await api('/api/batch', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ cases }) });
    const counts = {}; j.results.forEach(r => counts[r.diagnosis] = (counts[r.diagnosis] || 0) + 1);
    out.append(table(['Case', 'Status', 'Diagnosis', 'Competing', 'Urgency', 'Observations'], j.results.map(r => [r.id, r.status, r.diagnosis, r.alternatives.join('; ') || '-', badge(r.urgency), r.observations])));
    out.append(fig(8, 'Distribution of batch diagnoses', barChart(Object.entries(counts).map(([k, v]) => ({ label: k, value: v })), { dec: 0, xlabel: 'Number of cases' }), 'Counts of the top-ranked diagnosis for each submitted case.'));
    const b = el('button', { class: 'btn btn-outline-primary btn-sm no-print', text: 'Download results (CSV)' });
    b.onclick = () => download('batch_results.csv', 'id,status,diagnosis,competing,urgency,observations\n' + j.results.map(r => [r.id, r.status, '"' + r.diagnosis + '"', '"' + r.alternatives.join('; ') + '"', r.urgency, r.observations].join(',')).join('\n'), 'text/csv');
    out.append(b);
  } catch (e) { out.append(el('div', { class: 'alert alert-danger', text: e.message })); }
}

/* ------------------------------------------------------------------ evaluation */
const MET = [{ key: 'exact', cls: 's1f' }, { key: 'hit', cls: 's2f' }, { key: 'coverage', cls: 's3f' }, { key: 'f1', cls: 's4f' }];
const legend = () => el('div', { class: 'legend mb-2' }, [['s1f', 'Exact-set accuracy'], ['s2f', 'Hit rate'], ['s3f', 'Coverage'], ['s4f', 'Label-wise F1']].map(([c, t]) => el('span', null, el('i', { style: `background:var(--c${c[1]})` }), t)));
async function runEval(which) {
  const st = $('#evst'), out = clear($('#evout')); const run = [];
  const all = which === 'all', want = k => all || which === k;
  try {
    if (want('modes') || want('full') || want('groups') || want('classes')) {
      st.textContent = 'Running reasoning-mode comparison...'; const m = await api('/api/experiment?name=modes'); const rows = m.rows;
      if (want('modes')) {
        out.append(el('h5', { class: 'serif mt-3', text: 'Reasoning-mode comparison (held-out test split)' }), legend());
        out.append(fig(9, 'Diagnostic performance by reasoning mode', groupedBars(rows.map(r => ({ label: SHORT[r.label] || r.label, vals: r })), MET), 'Exact-set accuracy requires the predicted fault set to equal the true set; hit rate also credits a flagged near-tied alternative.'));
        out.append(table(['Mode', 'N', 'Exact', 'Hit', 'Coverage', 'Precision', 'Recall', 'F1', 'False alarm', 'Mean ms', 'Max ms', 'Explained', 'Plan valid'], rows.map(r => [MODES[r.label] || r.label, r.n, fmt(r.exact), fmt(r.hit), fmt(r.coverage), fmt(r.precision), fmt(r.recall), fmt(r.f1), fmt(r.false_alarm), fmt(r.mean_ms, 2), fmt(r.max_ms, 2), fmt(r.explainability), fmt(r.plan_validity)])));
      }
      if (want('full')) {
        st.textContent = 'Running full-mode evaluation...'; const f = await api('/api/evaluate?split=test&mode=full');
        const names = { a: 'A normal', b: 'B single', c: 'C multiple', d: 'D ambiguous', e: 'E incomplete', f: 'F noisy', g: 'G sensor and physical' };
        out.append(el('h5', { class: 'serif mt-4', text: 'Full system by test category' }), legend());
        out.append(fig(10, 'Performance by test category', groupedBars(f.categories.map(c => ({ label: c.label.toUpperCase(), vals: c })), MET), 'Categories follow the test suite: A normal, B single fault, C multiple faults, D ambiguous symptoms, E incomplete observations, F noisy or borderline measurements, G sensor and physical faults together.'));
        out.append(table(['Category', 'N', 'Exact', 'Hit', 'Coverage', 'F1'], f.categories.map(c => [names[c.label] || c.label, c.n, fmt(c.exact), fmt(c.hit), fmt(c.coverage), fmt(c.f1)])));
        const cols = ['fn', 'fk', 'ft', 'fh', 'fc', 'fm', 'fq', 'fp', 'fj', 'fs', 'fi', 'fr', 'multi', 'unknown', 'insufficient'], lab = c => ({ multi: 'multi', unknown: 'unk', insufficient: 'insuf' }[c] || c.replace('f', 'F').toUpperCase().replace('F', 'F'));
        const rowsL = f.confusion.map(r => r.truth), get = (r, c) => (f.confusion.find(x => x.truth === r).counts[c] || 0);
        const hm = heatmap(rowsL, cols, get); out.append(fig(11, 'Confusion matrix, single-fault test cases', hm, 'Rows are true labels and columns the predicted top diagnosis; "multi" denotes a multi-fault prediction. Diagonal cells are correct diagnoses.'));
        out.append(table(['Class', 'TP', 'FP', 'FN', 'Precision', 'Recall', 'F1'], f.classes.map(c => [fsym(c.class), c.tp, c.fp, c.fn, fmt(c.precision), fmt(c.recall), fmt(c.f1)])));
      }
      if (want('groups')) {
        st.textContent = 'Running rule-group ablation...'; const g = await api('/api/experiment?name=groups'); const base = {}; rows.forEach(r => base[r.mode] = r);
        out.append(el('h5', { class: 'serif mt-4', text: 'Rule-group ablation' }));
        out.append(fig(12, 'Change in exact-set accuracy when a rule group is removed', groupedBars(g.rows.filter(r => r.mode === 'full').map((r, i) => ({ label: r.variant, vals: { full: r.exact, ded: (g.rows.find(x => x.variant === r.variant && x.mode === 'ded') || {}).exact } })), [{ key: 'full', cls: 's1f' }, { key: 'ded', cls: 's2f' }]),
          'Blue: full system; amber: deductive rules only. Abductive covering is unaffected by removing rules, so the full system is less sensitive to rule loss than deduction alone.'));
        out.append(table(['Removed group', 'Mode', 'Exact', 'Change vs baseline', 'Hit', 'Coverage'], g.rows.map(r => [r.variant, MODES[r.mode], fmt(r.exact), fmt(r.exact - base[r.mode].exact), fmt(r.hit), fmt(r.coverage)])));
      }
      if (want('classes')) {
        st.textContent = 'Running evidence-class ablation...'; const c = await api('/api/experiment?name=classes'); const b = rows.find(r => r.mode === 'full');
        out.append(el('h5', { class: 'serif mt-4', text: 'Evidence-class ablation (full system)' }));
        out.append(fig(13, 'Exact-set accuracy when an evidence class is withheld', barChart([{ label: 'Baseline (all evidence)', value: b.exact, cls: 's3f' }].concat(c.rows.map(r => ({ label: 'Without ' + r.variant, value: r.exact, cls: 's2f' }))), { max: 1, xlabel: 'Exact-set accuracy' }), 'Each bar removes one class of sensors from the evidence layer.'));
      }
    }
    if (want('tolerance')) {
      st.textContent = 'Running tolerance sensitivity...'; const t = await api('/api/experiment?name=tolerance'), ser = (mode, key, cls, name) => ({ name, cls, pts: t.rows.filter(r => r.mode === mode).map(r => [r.variant, r[key]]) });
      out.append(el('h5', { class: 'serif mt-4', text: 'Tolerance sensitivity' }));
      out.append(fig(14, 'Sensitivity to the tolerance scale', lineChart([ser('full', 'exact', 's1', 'Full, exact'), ser('full', 'hit', 's3', 'Full, hit'), ser('ded', 'exact', 's2', 'Deduction, exact')], { ymax: 1, xlabel: 'Tolerance scale factor (1.0 = calibrated)', ylabel: 'Accuracy' }),
        'Blue: full system exact; green: full system hit; amber: deduction only. Tolerance bands were calibrated on the development split only.'));
      out.append(el('div', { class: 'legend' }, [['1', 'Full, exact'], ['3', 'Full, hit'], ['2', 'Deduction, exact']].map(([c, tx]) => el('span', null, el('i', { style: `background:var(--c${c})` }), tx))));
    }
    if (want('growth')) {
      st.textContent = 'Running knowledge-base growth study...'; const g = await api('/api/experiment?name=growth');
      out.append(el('h5', { class: 'serif mt-4', text: 'Tractability: reasoning time against hypothesis-space growth' }));
      out.append(fig(15, 'Mean reasoning time against number of inert faults added', lineChart([{ name: 'mean', cls: 's1', pts: g.rows.map(r => [r.variant, r.mean_ms]) }, { name: 'max', cls: 's2', pts: g.rows.map(r => [r.variant, r.max_ms]) }], { xlabel: 'Inert fault hypotheses added to the knowledge base', ylabel: 'Time per case [ms]' }),
        'Inert faults and rules never explain an observed symptom, so completeness is unchanged (see table) while the enumeration of fault sets grows combinatorially. Blue: mean; amber: maximum.'));
      out.append(table(['Inert faults', 'Exact', 'Hit', 'Mean ms', 'Max ms'], g.rows.map(r => [r.variant, fmt(r.exact), fmt(r.hit), fmt(r.mean_ms, 2), fmt(r.max_ms, 2)])));
    }
    st.textContent = 'Complete.';
  } catch (e) { st.textContent = 'Error: ' + e.message; }
  typeset(out);
}

/* ------------------------------------------------------------------ knowledge base and methodology */
async function loadKb() {
  if (MODEL.faults) return;
  const k = await api('/api/kb'); MODEL.faults = k.faults; MODEL.causal = k.causal_model; MODEL.rules = k.rules; MODEL.tol = k.tolerances; MODEL.vars = k.variables;
  const v = clear($('#kbout'));
  v.append(el('div', { class: 'card mb-3' }, el('div', { class: 'card-header', text: `Fault classes and maintenance knowledge (${k.faults.length})` }), el('div', { class: 'card-body' },
    table(['Symbol', 'Fault', 'Failure mechanism', 'Governing relation', 'Urgency'], k.faults.map(f => [fsym(f.id), f.name, f.mechanism, f.math ? M(f.math) : '', badge(f.urgency)])))));
  v.append(el('div', { class: 'card mb-3' }, el('div', { class: 'card-header', text: `Diagnostic rules (${k.rules.length}): Horn clauses with negation as failure for exceptions` }), el('div', { class: 'card-body' },
    table(['Rule', 'Concludes', 'Group', 'Engineering meaning'], k.rules.map(r => [r.id, fsym(r.fault), r.group, r.text])))));
  v.append(el('div', { class: 'card mb-3' }, el('div', { class: 'card-header', text: 'Tolerance bands (engineering assumptions)' }), el('div', { class: 'card-body' },
    table(['Symbol', 'Lower bound', 'Upper bound'], k.tolerances.map(t => [vsym(t.var), t.low == null ? 'none' : fmt(t.low), fmt(t.high)])))));
  v.append(el('div', { class: 'card' }, el('div', { class: 'card-body' }, fig(16, 'Fault propagation and causal structure', causalGraph(k.causal_model), 'Abductive causal model: each edge states that the fault can explain the symptom.'))));
  typeset(v);
}
const EQ = [['Material balance and conversion', String.raw`\tau=\dfrac{V_r}{\dot V_f},\qquad X=\dfrac{C_{A,in}-C_A}{C_{A,in}}=\dfrac{k\tau}{1+k\tau}`],
  ['Arrhenius rate constant', String.raw`k=a\,k_0\exp\!\left(-\dfrac{E_a}{R\,T_r}\right)`],
  ['Reactor energy balance', String.raw`\rho V_r c_p\dfrac{dT_r}{dt}=\dot m_f c_p\,(T_{in}-T_r)+(-\Delta H_r)\,r_A V_r-\dot Q_j`],
  ['Jacket duty (effectiveness-NTU)', String.raw`\dot Q_j=\varepsilon\,\dot m_j c_{pj}\,(T_r-T_{j,in}),\qquad \varepsilon=1-\exp\!\left(-\dfrac{UA}{\dot m_j c_{pj}}\right)`],
  ['Pressure residual and sensor redundancy', String.raw`r_P=P_r-\left[P_{atm}+P_v(T)\right],\qquad r_T=\left|T_r-T_{out}\right|`],
  ['Relative deviation and symbolic state', String.raw`d_x=\dfrac{x-x_{ref}}{x_{ref}},\qquad \mathrm{state}(x)=\begin{cases}\text{low}&d_x<\ell_x\\\text{high}&d_x>u_x\\\text{normal}&\text{otherwise}\end{cases}`],
  ['Deduction, abduction and consistency', String.raw`KB\cup E\models F,\qquad D\cup KB\models Obs,\qquad KB\cup Obs\cup D\not\models\bot`],
  ['Evidence aggregation (ranking only)', String.raw`C(F_k)=\dfrac{\sum_i w_i\,e_i(F_k)}{\sum_i w_i}`]];
function buildMethod() {
  const v = clear($('#methodout'));
  v.append(el('p', { class: 'text-body-secondary', text: 'The figures below are the system views required for the project: process schematic, architecture, knowledge-acquisition workflow, fault propagation, diagnostic reasoning, explanation generation, maintenance planning and evaluation.' }));
  v.append(fig(17, 'Industrial system schematic (jacketed CSTR)', schematic(null, null, []), 'Instrument tags follow ISA letters: TT temperature, PT pressure, FT flow, LT level, AT analyser, QT heat duty, ST speed, JT motor current, VT vibration.'));
  v.append(fig(18, 'Expert-system architecture', flow({ cols: 4, rows: 2, nodes: [
    { id: 'o', col: 0, row: 0, label: ['Observations', 'and test cases'] }, { id: 'e', col: 1, row: 0, label: ['Evidence and', 'feature layer'] }, { id: 'k', col: 2, row: 0, label: ['Prolog', 'knowledge base'] }, { id: 'i', col: 3, row: 0, label: ['Inference engine', 'ded, abd, cons'] },
    { id: 'x', col: 3, row: 1, label: ['Explanation', 'facility'] }, { id: 'm', col: 2, row: 1, label: ['Maintenance', 'planner'] }, { id: 'r', col: 1, row: 1, label: ['Evaluation', 'and reporting'] }, { id: 'u', col: 0, row: 1, label: ['Web interface', 'and JSON API'] }],
    edges: [['o', 'e'], ['e', 'k'], ['k', 'i'], ['i', 'x'], ['x', 'm'], ['m', 'r'], ['r', 'u']] }), 'Layered architecture implemented in SWI-Prolog; the browser only renders results returned by the Prolog server.'));
  v.append(fig(19, 'Knowledge-acquisition workflow', flow({ cols: 4, rows: 2, nodes: [
    { id: 'a', col: 0, row: 0, label: ['Textbook and', 'literature sources'] }, { id: 'b', col: 1, row: 0, label: ['Engineering relation', 'balances, kinetics'] }, { id: 'c', col: 2, row: 0, label: ['First-order', 'formalisation'] }, { id: 'd', col: 3, row: 0, label: ['Horn-clause', 'transformation'] },
    { id: 'e', col: 3, row: 1, label: ['Prolog predicate', 'and rule'] }, { id: 'f', col: 2, row: 1, label: ['Provenance record', 'source, meaning'] }, { id: 'g', col: 1, row: 1, label: ['Unit test case', 'hand derived'] }, { id: 'h', col: 0, row: 1, label: ['Rule inventory', 'and traceability'] }],
    edges: [['a', 'b'], ['b', 'c'], ['c', 'd'], ['d', 'e'], ['e', 'f'], ['f', 'g'], ['g', 'h']] }), 'Every rule is traced from its source to a formal clause, a provenance record and a test case.'));
  const caus = MODEL.causal ? fig(20, 'Fault propagation and causal structure', causalGraph(MODEL.causal), 'Abductive causal model linking fault hypotheses to symptoms.') : null; if (caus) v.append(caus);
  v.append(fig(21, 'Diagnostic reasoning workflow', reasoningFlow({ counts: { conditions: null, abnormal: null, rules: null, covers: null, rejected: null }, observations: null, status: 'fault' }), 'Evidence is derived once and consumed by deduction and abduction; consistency checking removes hypotheses contradicting necessary effects.'));
  v.append(fig(22, 'Explanation-generation workflow', flow({ cols: 3, rows: 2, nodes: [
    { id: 'a', col: 0, row: 0, label: ['Diagnosis goal'] }, { id: 'b', col: 1, row: 0, label: ['Proof tree from', 'meta-interpreter'] }, { id: 'c', col: 2, row: 0, label: ['Observed evidence', 'and conditions'] },
    { id: 'd', col: 2, row: 1, label: ['Competing and', 'eliminated hypotheses'] }, { id: 'e', col: 1, row: 1, label: ['Narrative assembly', 'from rule texts'] }, { id: 'f', col: 0, row: 1, label: ['Readable expert', 'explanation'] }],
    edges: [['a', 'b'], ['b', 'c'], ['c', 'd'], ['d', 'e'], ['e', 'f']] }), 'The explanation answers why a diagnosis was reached and why alternatives were rejected.'));
  v.append(fig(23, 'Maintenance-planning workflow', flow({ cols: 5, rows: 1, bw: 150, nodes: [
    { id: 'a', col: 0, row: 0, label: ['Diagnosed faults'] }, { id: 'b', col: 1, row: 0, label: ['Directive lookup'] }, { id: 'c', col: 2, row: 0, label: ['Urgency ordering'] }, { id: 'd', col: 3, row: 0, label: ['Safety constraint'] }, { id: 'e', col: 4, row: 0, label: ['Verification step'] }],
    edges: [['a', 'b'], ['b', 'c'], ['c', 'd'], ['d', 'e']] }), 'Fault, evidence, directive, urgency, safety constraint and verification form each maintenance record.'));
  v.append(fig(24, 'Experimental and evaluation workflow', flow({ cols: 4, rows: 2, nodes: [
    { id: 'a', col: 0, row: 0, label: ['Synthetic dataset', 'generator, fixed seed'] }, { id: 'b', col: 1, row: 0, label: ['Development and', 'test split'] }, { id: 'c', col: 2, row: 0, label: ['Tolerance calibration', 'development only'] }, { id: 'd', col: 3, row: 0, label: ['Four reasoning modes', 'on test split'] },
    { id: 'e', col: 3, row: 1, label: ['Metrics and', 'confusion matrix'] }, { id: 'f', col: 2, row: 1, label: ['Rule and evidence', 'ablation'] }, { id: 'g', col: 1, row: 1, label: ['Tolerance and', 'size sensitivity'] }, { id: 'h', col: 0, row: 1, label: ['Report tables', 'and figures'] }],
    edges: [['a', 'b'], ['b', 'c'], ['c', 'd'], ['d', 'e'], ['e', 'f'], ['f', 'g'], ['g', 'h']] }), 'Tolerances are fixed on the development split and every reported score uses the held-out test split.'));
  v.append(el('h5', { class: 'serif mt-4', text: 'Governing relations encoded in the knowledge base' }));
  const row = el('div', { class: 'row g-3' }); EQ.forEach(([t, tex]) => row.append(el('div', { class: 'col-md-6' }, el('div', { class: 'card h-100' }, el('div', { class: 'card-body' }, el('div', { class: 'small text-body-secondary', text: t }), el('div', { class: 'eq' }, '\\[' + tex + '\\]'))))));
  v.append(row); typeset(v);
}

/* ------------------------------------------------------------------ navigation and start-up */
function show(view) {
  document.querySelectorAll('.topbar .nav-link').forEach(a => a.classList.toggle('active', a.dataset.v === view));
  document.querySelectorAll('.pane').forEach(p => p.classList.toggle('on', p.id === 'v-' + view));
  if (view === 'kb') loadKb().then(() => { }).catch(e => clear($('#kbout')).append(el('div', { class: 'alert alert-danger', text: e.message })));
  if (view === 'method') loadKb().then(buildMethod).catch(buildMethod);
}
function init() {
  const dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches; document.documentElement.setAttribute('data-bs-theme', dark ? 'dark' : 'light');
  buildForm();
  document.querySelectorAll('.topbar .nav-link').forEach(a => a.onclick = e => { e.preventDefault(); show(a.dataset.v); });
  $('#go').onclick = consult; $('#bclr').onclick = () => setObs(null);
  $('#bref').onclick = () => api('/api/reference?load=' + $('#load').value).then(j => setObs(j.obs));
  $('#scen').onchange = e => { if (e.target.value) api('/api/case?id=' + e.target.value).then(j => { $('#load').value = j.load; setObs(j.obs); }); };
  $('#bex').onclick = batchExample; $('#bgo').onclick = runBatch;
  document.querySelectorAll('[data-eval]').forEach(b => b.onclick = () => runEval(b.dataset.eval));
  api('/api/cases').then(j => { const S = $('#scen'), nm = { a: 'A  Normal operation', b: 'B  Single fault', c: 'C  Multiple faults', d: 'D  Ambiguous symptoms', e: 'E  Incomplete observations', f: 'F  Noisy or borderline', g: 'G  Sensor and physical faults' };
    const by = {}; j.cases.forEach(c => (by[c.category] = by[c.category] || []).push(c));
    Object.keys(by).sort().forEach(k => { const og = el('optgroup', { label: nm[k] || k }); by[k].slice(0, 60).forEach(c => og.append(el('option', { value: c.id, text: `${c.id}, ${c.load} load, recorded label: ${c.truth.join(' + ')}` }))); S.append(og); }); }).catch(() => { });
  api('/api/reference?load=nominal').then(j => setObs(j.obs)).catch(() => { });
  api('/api/kb').then(k => { MODEL.faults = null; MODEL.causal = k.causal_model; }).catch(() => { });
}
document.addEventListener('DOMContentLoaded', init);
