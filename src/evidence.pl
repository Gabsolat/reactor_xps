%% evidence.pl -- evidence & feature layer: numeric observations -> symbolic states
%% Implements Eq. (7) conversion, (8) selectivity, (24) relative deviation, vapour-pressure
%% residual, sensor-redundancy residual and energy-balance residual.

:- dynamic obs/3, ref/3, case/5, disabled_class/1.

case_load(C, L) :- case(C, _, L, _, _), !.

% measured value, honouring evidence-class ablation
meas(C, Var, V) :-
    obs(C, Var, V),
    \+ ( raw_class(Var, Cl), disabled_class(Cl) ).

% number of available raw observations
evidence_count(C, N) :- aggregate_all(count, meas(C, _, _), N).

% ---- thermal estimate: outlet temperature preferred; reactor temperature is the default substitute
th_value(C, V) :- ( meas(C, tout, V0) -> V = V0 ; meas(C, tr, V) ).

% ---- feed concentration: measured, else DEFAULT to the nominal feed (exception: any measurement overrides)
feed_conc(C, A) :- ( meas(C, cain, A0) -> A = A0 ; case_load(C, L), ref(L, cain, A) ).

% ---- Eq. (7) conversion and (8) selectivity
conversion(C, X) :- meas(C, ca, CA), feed_conc(C, A0), A0 > 0, X is (A0 - CA) / A0.
ref_conversion(L, X) :- ref(L, cain, A0), ref(L, ca, A), X is (A0 - A) / A0.
selectivity(C, S) :-
    meas(C, cp, CPv), meas(C, ca, CA), feed_conc(C, A0), Den is A0 - CA, Den > 1.0,
    S is CPv / Den.

% ---- vapour-pressure surrogate and pressure residual (kPa)
p_expected(Tk, Pe) :- Pe is 101.3 + 8.0 * exp(0.045 * (Tk - 300.0)).
pressure_residual(C, Res) :-
    meas(C, pr, P),
    (   th_value(C, Tk) -> p_expected(Tk, Pe) ; case_load(C, L), ref(L, pr, Pe) ),
    Res is P - Pe.

% ---- energy balance residual: (Q_gen - Q_r - Q_j)/Q_gen   (Eq. 9, 10, energy balance)
energy_residual(C, Rel) :-
    meas(C, qr, Qr), meas(C, mj, Mj), meas(C, tj, Tj), meas(C, tjin, Tji), meas(C, mf, Mf),
    conversion(C, X), feed_conc(C, A0),
    param(dh, DH), param(cpj, CPJ), param(rho, Rho),
    Qgen is (-DH) * (Mf / Rho) * A0 * X / 1000.0,
    Qj   is Mj * CPJ * (Tj - Tji) / 1000.0,
    Qgen > 1.0,
    Rel is (Qgen - Qr - Qj) / Qgen.

% ---- deviation per state variable
direct_var(V) :- member(V, [tin,tjin,tj,mf,cain,qr,vr,na,pj,mj,ph,vrms,im]).

dev(C, V, D) :- direct_var(V), meas(C, V, X), case_load(C, L), ref(L, V, R), R =\= 0, D is (X - R) / R.
dev(C, th, D) :- th_value(C, T), case_load(C, L), ref(L, tout, R), D is (T - R) / R.
dev(C, tmis, D) :- meas(C, tr, A), meas(C, tout, B), D is abs(A - B).
dev(C, x, D) :- conversion(C, X), case_load(C, L), ref_conversion(L, Xr), D is (X - Xr) / Xr.
dev(C, s, D) :-
    selectivity(C, S), case_load(C, L),
    ref(L, cp, P0), ref(L, ca, A), ref(L, cain, A0), Sr is P0 / (A0 - A), D is (S - Sr) / Sr.
dev(C, pres, D) :- pressure_residual(C, D).
dev(C, ebal, D) :- energy_residual(C, D).

eff_tol(V, Lo, Hi) :- tol(V, L0, H0), tol_scale(K), Lo is L0 * K, Hi is H0 * K.

% symbolic state: low / normal / high.  A state exists ONLY when evidence exists (open world for data).
state(C, V, S) :-
    dev(C, V, D), eff_tol(V, Lo, Hi),
    (   D < Lo -> S = low ; D > Hi -> S = high ; S = normal ).

% borderline: deviation within +-20% of a tolerance edge (uncertainty marker for explanations)
borderline(C, V) :-
    dev(C, V, D), eff_tol(V, Lo, Hi),
    (   Hi > 0, D >= 0.8 * Hi, D =< 1.2 * Hi
    ;   Lo < 0, Lo > -100, D =< 0.8 * Lo, D >= 1.2 * Lo ).

% a variable is 'observed' when a state can be derived for it (data exist)
observed(C, V) :- state(C, V, _), !.

any_primary_abnormal(C) :- primary_var(V), state(C, V, S), S \== normal, !.
