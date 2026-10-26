#!/usr/bin/env python3
"""Synthetic dataset generator for the Prolog reactor expert system.
NOT part of the diagnostic core. All values are SYNTHETIC (model-generated), never plant data.
Model: jacketed CSTR, first-order exothermic A->products, steady state, effectiveness-NTU jacket.
Usage (from project root): python3 tools/gen_dataset.py   (fixed seed => identical output)"""
import math, random, csv, os
SEED = 20260101
R = 8.314
BASE = dict(rho=1000., cp=4180., V=2.0, CAin=2000., dH=-1.5e5, Ea=60000., Tin=310.,
            Tjin=293., cpj=4180., UA=1400., a=1.0, k350=0.002, mj=2.0, mf=1.0,
            dP=0.0, Pj=250., Na=120., Vscale=1.0, pH=7.0, vib=1.5, Tbias=0.0)
LOAD_MF = {'low': 0.7, 'nominal': 1.0, 'high': 1.3}

def steady(p):
    tau = p['V'] * p['rho'] / p['mf']
    k0 = p['k350'] / math.exp(-p['Ea'] / (R * 350.))
    eps = 1 - math.exp(-p['UA'] / (p['mj'] * p['cpj']))
    def f(T):
        k = p['a'] * k0 * math.exp(-p['Ea'] / (R * T)); X = k * tau / (1 + k * tau)
        gen = -p['dH'] * (p['mf'] / p['rho']) * p['CAin'] * X
        rem = p['mf'] * p['cp'] * (T - p['Tin']) + eps * p['mj'] * p['cpj'] * (T - p['Tjin'])
        return gen - rem, X
    T = p['Tin']
    while T < 460 and f(T)[0] > 0: T += 0.05
    return T, f(T)[1], eps

def tune_mj(mf):
    lo, hi = 0.2, 8.0
    for _ in range(60):
        mid = (lo + hi) / 2; T, _, _ = steady(dict(BASE, mf=mf, mj=mid))
        if T > 350: lo = mid
        else: hi = mid
    return (lo + hi) / 2

REF = {}
for ld, mf in LOAD_MF.items():
    mj = tune_mj(mf); p = dict(BASE, mf=mf, mj=mj); T, X, eps = steady(p)
    REF[ld] = dict(T=T, X=X, p=p)

def lerp(a, b, s): return a + (b - a) * s
def apply_fault(p, f, s, rng):
    p = dict(p)
    if f == 'fk': p['a'] *= lerp(0.80, 0.55, s)
    elif f == 'ft': p['Tin'] += lerp(8, 22, s)
    elif f == 'fh': p['UA'] *= lerp(0.75, 0.40, s)
    elif f == 'fc': p['Tjin'] += lerp(6, 16, s)
    elif f == 'fm': p['a'] *= lerp(0.95, 0.85, s); p['UA'] *= lerp(0.92, 0.80, s); p['Na'] *= lerp(0.8, 0.5, s); p['vib'] *= lerp(1.6, 2.8, s)
    elif f == 'fq': p['CAin'] *= lerp(0.92, 0.78, s); p['pH'] = lerp(6.3, 5.0, s)
    elif f == 'fp': p['dP'] += lerp(40, 200, s)
    elif f == 'fj': p['mj'] *= lerp(0.8, 0.45, s); p['Pj'] *= lerp(0.85, 0.55, s)
    elif f == 'fs': p['Vscale'] *= lerp(0.92, 0.72, s); p['dP'] -= lerp(10, 30, s); p['vib'] *= lerp(1.6, 2.8, s)
    elif f == 'fr': p['mf'] *= (lerp(1.2, 1.6, s) if rng.random() < 0.5 else lerp(0.8, 0.55, s))
    elif f == 'fi': p['Tbias'] = rng.choice([-1, 1]) * lerp(5, 15, s)
    return p

VARS = ['tr','tin','tout','tjin','tj','pr','mf','cain','ca','cb','cp','qr','vr','na','pj','mj','ph','vrms','im']
SIG = dict(tr=.3, tin=.2, tout=.3, tjin=.2, tj=.3, pr=1.0, ph=.05,                 # absolute
           mf=.01, cain=.005, ca=.01, cb=.02, cp=.02, qr=.01, vr=.005, na=.01, pj=.01, mj=.01, vrms=.04, im=.02)  # relative
ABS = {'tr','tin','tout','tjin','tj','pr','ph'}

def observe(p, rng, nz=1.0):
    T, X, eps = steady(p)
    Qj = eps * p['mj'] * p['cpj'] * (T - p['Tjin']); Tj = p['Tjin'] + Qj / (p['mj'] * p['cpj'])
    S = max(0.5, min(0.99, 0.95 - 0.004 * (T - 350)))
    dC = p['CAin'] * X
    pr = 101.3 + 8 * math.exp(0.045 * (T - 300)) + p['dP']
    Im = 6 + 12 * (p['Na'] / 120.) ** 2
    tv = dict(tr=T + p['Tbias'], tin=p['Tin'], tout=T, tjin=p['Tjin'], tj=Tj, pr=pr, mf=p['mf'], cain=p['CAin'],
              ca=p['CAin'] - dC, cb=dC * (1 - S), cp=dC * S, vr=p['V'] * p['Vscale'], na=p['Na'], pj=p['Pj'],
              mj=p['mj'], ph=p['pH'], vrms=p['vib'], im=Im)
    o = {k: rng.gauss(v, (SIG[k] if k in ABS else abs(v) * SIG[k]) * nz) for k, v in tv.items()}
    o['qr'] = p['mf'] * p['cp'] * (o['tout'] - o['tin']) / 1000.0 * (1 + rng.gauss(0, SIG['qr'] * nz))
    return o

SINGLE = ['fk','ft','fh','fc','fm','fq','fp','fj','fs','fr','fi']
PAIRS = [('fk','fj'),('fh','fp'),('fq','fc'),('fm','fs'),('fk','fp'),('fh','fj'),('fq','fm'),('ft','fp'),('fr','fc'),('fk','fq')]
DROP = {'fh':['tj','tjin','qr'],'fc':['tjin','qr','tj'],'fk':['cain','ph','ca'],'fq':['ph','cain'],
        'fj':['pj','mj'],'fs':['vr','pr'],'fm':['na','im'],'fp':['tr','tout','tin']}

def build(rng):
    cases = []
    def add(cat, load, faults, obs, note=''):
        cases.append(dict(id='c%03d' % (len(cases) + 1), cat=cat, load=load, faults=faults, obs=obs, note=note))
    def make(load, faults, s_list, nz=1.0):
        p = dict(REF[load]['p'])
        for f, s in zip(faults, s_list): p = apply_fault(p, f, s, rng)
        return observe(p, rng, nz)
    for ld in LOAD_MF:
        for _ in range(8): add('A', ld, ['fn'], make(ld, [], []))
    for ld in LOAD_MF:
        for f in SINGLE:
            for _ in range(4): add('B', ld, [f], make(ld, [f], [rng.uniform(.45, 1)]))
    for a, b in PAIRS:
        for ld in LOAD_MF: add('C', ld, [a, b], make(ld, [a, b], [rng.uniform(.5, 1), rng.uniform(.5, 1)]))
    for f in DROP:
        for _ in range(3):
            ld = rng.choice(list(LOAD_MF)); o = make(ld, [f], [rng.uniform(.5, 1)])
            for d in DROP[f]: o.pop(d, None)
            add('D', ld, [f], o, 'discriminators removed: ' + ','.join(DROP[f]))
    for _ in range(30):
        ld = rng.choice(list(LOAD_MF)); f = rng.choice(SINGLE); o = make(ld, [f], [rng.uniform(.5, 1)])
        for d in rng.sample(VARS, rng.randint(4, 7)): o.pop(d, None)
        add('E', ld, [f], o, 'random drop')
    for _ in range(11):
        ld = rng.choice(list(LOAD_MF)); add('F', ld, ['fn'], make(ld, [], [], nz=3.0), 'noise x3')
    for f in [x for x in SINGLE if x != 'fi']:
        for _ in range(2):
            ld = rng.choice(list(LOAD_MF)); add('F', ld, [f], make(ld, [f], [rng.uniform(.25, .5)], nz=2.0), 'mild severity, noise x2')
    for f in ['fk','fh','fj','fq','fc']:
        for _ in range(3):
            ld = rng.choice(list(LOAD_MF)); add('G', ld, ['fi', f], make(ld, ['fi', f], [rng.uniform(.6, 1), rng.uniform(.6, 1)]), 'sensor + physical')
    for i, c in enumerate(cases): c['split'] = 'dev' if i % 10 < 3 else 'test'
    return cases

def pl(x): return ('%.4f' % x).rstrip('0').rstrip('.')

def main():
    rng = random.Random(SEED); cases = build(rng)
    os.makedirs('data', exist_ok=True)
    with open('data/cases.pl', 'w') as f:
        f.write('%% SYNTHETIC test cases (model-generated, seed %d). Not plant measurements.\n' % SEED)
        f.write(':- discontiguous case/5, obs/3.\n')
        for c in cases:
            f.write('case(%s, %s, %s, [%s], %s).\n' % (c['id'], c['cat'].lower(), c['load'], ','.join(c['faults']), c['split']))
            for k, v in c['obs'].items(): f.write('obs(%s, %s, %s).\n' % (c['id'], k, pl(v)))
    with open('data/cases.csv', 'w', newline='') as f:
        w = csv.writer(f); w.writerow(['id','category','load','labels','split','note'] + VARS)
        for c in cases: w.writerow([c['id'], c['cat'], c['load'], '|'.join(c['faults']), c['split'], c['note']] + [pl(c['obs'][v]) if v in c['obs'] else '' for v in VARS])
    with open('data/reference.pl', 'w') as f:
        f.write('%% Reference (normal, controlled) operating point per load: SYNTHETIC model output, noise-free\n')
        f.write(':- discontiguous ref/3.\n')
        for ld, r in REF.items():
            for k, v in observe(r['p'], random.Random(1), nz=0.0).items(): f.write('ref(%s, %s, %s).\n' % (ld, k, pl(v)))
    print('cases:', len(cases))
    for ld, r in REF.items(): print(ld, 'mj=%.3f T=%.2f X=%.3f' % (r['p']['mj'], r['T'], r['X']))
main()
