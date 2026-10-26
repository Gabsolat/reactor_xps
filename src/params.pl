%% params.pl -- engineering constants, tolerances, evidence weights
%% All numeric values are ENGINEERING ASSUMPTIONS for a synthetic reference CSTR
%% (see docs/assumptions). They are not plant measurements.

:- dynamic tol_scale/1.
tol_scale(1.0).                      % global tolerance multiplier (sensitivity analysis)

% ---- physical parameters (Eq. numbers refer to the report) ----
param(rho, 1000.0).                  % kg/m3  liquid density
param(cpj, 4180.0).                  % J/kg/K jacket fluid specific heat
param(dh,  -150000.0).               % J/mol  heat of reaction (exothermic)
param(vol, 2.0).                     % m3     working volume

% ---- tolerance bands: tol(StateVariable, LowBound, HighBound) ----
% Units of the deviation: relative (D=(x-xref)/xref) except
%   pres : absolute kPa residual   tmis : absolute K   ebal : relative balance residual
tol(th,    -0.012,  0.010).
tol(tmis,  -1000.0, 3.5).
tol(x,     -0.050,  0.040).
tol(s,     -0.030,  0.030).
tol(qr,    -0.100,  0.100).
tol(tin,   -0.012,  0.012).
tol(tjin,  -0.007,  0.007).
tol(tj,    -0.050,  0.008).
tol(pres,  -12.0,  12.0).
tol(mf,    -0.080,  0.080).
tol(cain,  -0.050,  0.050).
tol(ph,    -0.060,  0.060).
tol(vr,    -0.050,  0.050).
tol(na,    -0.060,  0.060).
tol(pj,    -0.080,  0.080).
tol(mj,    -0.120,  0.120).
tol(vrms,  -0.400,  0.350).
tol(im,    -0.100,  0.100).
tol(ebal,  -0.150,  0.150).

% ---- evidence weights (used ONLY for ranking hypotheses, never for membership) ----
wt(th, 2.0).  wt(tmis, 2.0). wt(x, 1.5).   wt(s, 0.5).   wt(qr, 0.5).
wt(tin, 1.5). wt(tjin, 1.5). wt(tj, 1.0).  wt(pres, 2.0). wt(mf, 2.0).
wt(cain, 1.5). wt(ph, 1.5).  wt(vr, 2.0).  wt(na, 1.5).  wt(pj, 1.5).
wt(mj, 1.5).  wt(vrms, 1.0). wt(im, 1.0).  wt(ebal, 0.3).

% diagnostic variables; primary ones must be explained by a diagnosis, secondary only add score
diag_var(V) :- primary_var(V).
diag_var(V) :- secondary_var(V).
primary_var(V) :- member(V, [th,tmis,x,qr,tin,tjin,tj,pres,mf,cain,ph,vr,na,pj,mj,vrms,im]).
secondary_var(V) :- member(V, [s,ebal]).

% raw sensor -> evidence class (for evidence-class ablation)
raw_class(tr, thermal).    raw_class(tin, thermal).    raw_class(tout, thermal).
raw_class(tjin, jacket).   raw_class(tj, jacket).      raw_class(pj, jacket).   raw_class(mj, jacket).
raw_class(cain, composition). raw_class(ca, composition). raw_class(cb, composition).
raw_class(cp, composition).   raw_class(ph, composition).
raw_class(pr, pressure).
raw_class(na, mechanical). raw_class(im, mechanical). raw_class(vrms, mechanical). raw_class(vr, mechanical).
raw_class(mf, flow).       raw_class(qr, flow).
