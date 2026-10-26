#!/usr/bin/env python3
"""DESIGN CHECK ONLY. A line-by-line Python mirror of the Prolog evidence layer + rules + abduction +
consistency logic, used because no Prolog interpreter was available when the system was authored.
It is NOT the expert system and its numbers are NOT the reported results; run the Prolog for those."""
import re, math, itertools, collections, sys
def load():
    ref=collections.defaultdict(dict); obs=collections.defaultdict(dict); cases={}
    for l in open('data/reference.pl'):
        m=re.match(r'ref\((\w+), (\w+), ([-\d.]+)\)',l)
        if m: ref[m[1]][m[2]]=float(m[3])
    for l in open('data/cases.pl'):
        m=re.match(r'case\((\w+), (\w+), (\w+), \[([\w,]*)\], (\w+)\)',l)
        if m: cases[m[1]]=dict(cat=m[2],load=m[3],truth=m[4].split(','),split=m[5])
        m=re.match(r'obs\((\w+), (\w+), ([-\d.]+)\)',l)
        if m: obs[m[1]][m[2]]=float(m[3])
    return ref,obs,cases
TOL=dict(th=(-.012,.010),tmis=(-1e3,3.5),x=(-.05,.04),s=(-.03,.03),qr=(-.1,.1),tin=(-.012,.012),tjin=(-.007,.007),
 tj=(-.05,.008),pres=(-12,12),mf=(-.08,.08),cain=(-.05,.05),ph=(-.06,.06),vr=(-.05,.05),na=(-.06,.06),pj=(-.08,.08),
 mj=(-.12,.12),vrms=(-.4,.35),im=(-.1,.1),ebal=(-.15,.15))
PRIM=['th','tmis','x','qr','tin','tjin','tj','pres','mf','cain','ph','vr','na','pj','mj','vrms','im']
DIAG=PRIM+['s','qr','ebal']
WT=dict(th=2,tmis=2,x=1.5,s=.5,qr=.5,tin=1.5,tjin=1.5,tj=1,pres=2,mf=2,cain=1.5,ph=1.5,vr=2,na=1.5,pj=1.5,mj=1.5,vrms=1,im=1,ebal=.3)
DIRECT=['tin','tjin','tj','mf','cain','qr','vr','na','pj','mj','ph','vrms','im']
def states(o,ref,load,scale=1.0,tol=TOL):
    R=ref[load]; st={}; dv={}
    def put(v,d):
        lo,hi=tol[v][0]*scale,tol[v][1]*scale; dv[v]=d; st[v]='low' if d<lo else 'high' if d>hi else 'normal'
    for v in DIRECT:
        if v in o: put(v,(o[v]-R[v])/R[v])
    th=o.get('tout',o.get('tr'))
    if th is not None: put('th',(th-R['tout'])/R['tout'])
    if 'tr' in o and 'tout' in o: put('tmis',abs(o['tr']-o['tout']))
    A0=o.get('cain',R['cain'])
    if 'ca' in o:
        X=(A0-o['ca'])/A0; Xr=(R['cain']-R['ca'])/R['cain']; put('x',(X-Xr)/Xr)
        if 'cp' in o and A0-o['ca']>1:
            S=o['cp']/(A0-o['ca']); Sr=R['cp']/(R['cain']-R['ca']); put('s',(S-Sr)/Sr)
    if 'pr' in o:
        Pe=101.3+8*math.exp(0.045*(th-300)) if th is not None else R['pr']; put('pres',o['pr']-Pe)
    if all(k in o for k in ('qr','mj','tj','tjin','mf','ca')):
        Qg=1.5e5*(o['mf']/1000)*A0*X/1000
        if Qg>1: put('ebal',(Qg-o['qr']-o['mj']*4180*(o['tj']-o['tjin'])/1000)/Qg)
    return st
C=lambda st,v,s: st.get(v)==s
def conds(st):
    c=set()
    m={('th','low'):'ltr',('th','high'):'htr',('x','low'):'lx',('x','high'):'hx',('tin','high'):'htin',('tjin','high'):'htjin',
       ('tj','high'):'htj',('pj','low'):'lpj',('mj','low'):'lmj',('na','low'):'lna',('im','low'):'lim',('vrms','high'):'hv',
       ('vr','low'):'llev',('pres','high'):'hp',('pres','low'):'lp',('mf','high'):'hmf',('mf','low'):'lmf',('cain','low'):'lca',
       ('ph','low'):'lph',('tmis','high'):'dis'}
    for (v,s),n in m.items():
        if C(st,v,s): c.add(n)
    for v in st: c.add('o_'+v)
    if 'htr' in c and 'hx' in c: c.add('hrd')
    if 'lx' in c and 'ltr' in c: c.add('alp')
    return c
RULES=[('rk01','fk',lambda c:'alp' in c and ('o_cain' in c or 'o_ph' in c) and 'lca' not in c and 'lph' not in c),('rq01','fq',lambda c:'alp' in c and 'lca' in c),
 ('rq02','fq',lambda c:'alp' in c and 'lph' in c),('rh01','fh',lambda c:'hrd' in c and 'o_tin' in c and 'o_tjin' in c and 'o_mj' in c and 'htin' not in c and 'htjin' not in c and 'lmj' not in c),
 ('rc01','fc',lambda c:'hrd' in c and 'htjin' in c),('rc02','fc',lambda c:'htjin' in c and 'htj' in c),('rt01','ft',lambda c:'htr' in c and 'htin' in c),
 ('rj01','fj',lambda c:'lpj' in c and 'lmj' in c),('rj02','fj',lambda c:'lmj' in c and 'htj' in c),('rm01','fm',lambda c:'lna' in c and 'lim' in c),
 ('rm02','fm',lambda c:'hv' in c and 'lna' in c),('rm03','fm',lambda c:'hv' in c and 'lim' in c),('rs01','fs',lambda c:'llev' in c and 'hv' in c),
 ('rs02','fs',lambda c:'llev' in c and 'lp' in c),('rp01','fp',lambda c:'hp' in c),('rr01','fr',lambda c:'hmf' in c),('rr02','fr',lambda c:'lmf' in c),
 ('ri01','fi',lambda c:'dis' in c)]
E={'fk':[('th','low'),('x','low'),('qr','low'),('s','high')],'fq':[('th','low'),('x','low'),('qr','low'),('s','high'),('cain','low'),('ph','low')],
 'fh':[('th','high'),('x','high'),('qr','high'),('s','low')],'fc':[('th','high'),('x','high'),('qr','high'),('s','low'),('tjin','high'),('tj','high')],
 'ft':[('th','high'),('x','high'),('s','low'),('tin','high'),('tj','high'),('qr','high'),('qr','low')],'fj':[('pj','low'),('mj','low'),('tj','high'),('th','high'),('x','high'),('s','low'),('qr','high')],
 'fm':[('na','low'),('im','low'),('vrms','high')],'fs':[('vr','low'),('pres','low'),('vrms','high')],'fp':[('pres','high')],
 'fr':[('mf','high'),('mf','low'),('th','high'),('th','low'),('x','low'),('x','high'),('qr','high'),('qr','low')],'fi':[('tmis','high')]}
MUST={'fk':[('x','low'),('th','low'),('qr','low')],'fq':[('cain','low'),('ph','low')],'fh':[('th','high'),('x','high')],'fc':[('tjin','high'),('tj','high')],
 'ft':[('tin','high'),('tj','high'),('qr','high'),('qr','low')],'fj':[('pj','low'),('mj','low')],'fm':[('na','low'),('im','low'),('vrms','high')],'fs':[('vr','low'),('pres','low'),('vrms','high')],
 'fp':[('pres','high')],'fr':[('mf','high'),('mf','low')],'fi':[('tmis','high')]}
FAULTS=list(E)
def fired(st,groups_off=()):
    c=conds(st); return {f for i,f,fn in RULES if fn(c)}
def inconsistent(st,D):
    for f in D:
        al=MUST[f]
        if any(v in st for v,_ in al) and not any(st.get(v)==s for v,s in al): return True
    return 'fp' in D and 'fs' in D
def covers_all(st,mode,fr):
    syms=[(v,st[v]) for v in PRIM if v in st and st[v]!='normal']
    syms=[x for x in syms if any(x in E[f] for f in FAULTS)]
    if not syms: return []
    allc=[D for n in (1,2,3) for D in itertools.combinations(FAULTS,n) if all(any(x in E[f] for f in D) for x in syms)]
    return [D for D in allc if not any(set(D2)<set(D) for D2 in allc)]
def score(st,D,fr):
    ex=[v for v in DIAG if v in st and st[v]!='normal' and any((v,st[v]) in E[f] for f in D)]
    return sum(WT[v] for v in ex)+2.0*len(set(D)&fr)-0.5*len(D)
def diagnose(st,mode,n):
    if n<5: return ['insufficient'],[]
    if not any(st.get(v,'normal')!='normal' for v in PRIM): return ['fn'],[]
    fr=fired(st)
    if mode=='ded': return (sorted(fr) or ['unknown']),[]
    if mode=='ded_cons':
        l=sorted(f for f in fr if not inconsistent(st,[f])); return (l or ['unknown']),[]
    cov=covers_all(st,mode,fr)
    if mode=='full': cov=[D for D in cov if not inconsistent(st,D)]
    if not cov: return (sorted(fr) or ['unknown']),[]
    rk=sorted(((score(st,D,fr),D) for D in cov),key=lambda t:-t[0])
    b=rk[0][0]; return sorted(rk[0][1]),[sorted(D) for s,D in rk[1:] if b-s<=0.75]
def run(split,mode,scale=1.0):
    ref,obs,cases=load(); res=[]
    for cid,c in cases.items():
        if c['split']!=split: continue
        st=states(obs[cid],ref,c['load'],scale); p,al=diagnose(st,mode,len(obs[cid])); res.append((cid,c,p,al))
    return res
def summ(res):
    n=len(res); ex=sum(sorted(c['truth'])==sorted(p) for _,c,p,_ in res)
    hit=sum(sorted(c['truth'])==sorted(p) or any(sorted(c['truth'])==a for a in al) for _,c,p,al in res)
    return n,ex/n,hit/n
if __name__=='__main__':
    split=sys.argv[1] if len(sys.argv)>1 else 'dev'
    for mode in ('ded','ded_cons','ded_abd','full'):
        r=run(split,mode); print(split,mode,'N=%d exact=%.3f hit=%.3f'%summ(r))
    r=run(split,'full'); bycat=collections.defaultdict(list)
    for x in r: bycat[x[1]['cat']].append(x)
    for k,v in sorted(bycat.items()): print(' cat',k,'N=%d exact=%.3f hit=%.3f'%summ(v))
    if len(sys.argv)>2:
        for cid,c,p,al in r:
            if sorted(c['truth'])!=sorted(p): print('  MISS',cid,c['cat'],c['truth'],'->',p,al)
