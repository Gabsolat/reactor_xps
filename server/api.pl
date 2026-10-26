%% api.pl -- JSON API over the Prolog expert system (SWI-Prolog HTTP libraries only)
:- encoding(utf8).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(uuid)).
:- use_module(library(lists)).
:- use_module(library(apply)).

:- dynamic eval_cache/3.

sensor_var(V) :- member(V, [tr,tin,tout,tjin,tj,pr,mf,cain,ca,cb,cp,qr,vr,na,pj,mj,ph,vrms,im]).

to_atom(X, A) :- ( atom(X) -> A = X ; string(X) -> atom_string(A, X) ).
to_num(V, V) :- number(V), !.
to_num(V, N) :- string(V), V \== "", catch(number_string(N, V), _, fail).

clean_obs(D, Pairs) :-
    dict_pairs(D, _, P0),
    findall(K-V, ( member(K-V0, P0), sensor_var(K), to_num(V0, V) ), Pairs).

assert_case(Id, Load, Pairs) :-
    assertz(case(Id, user, Load, [], none)),
    forall(member(K-V, Pairs), assertz(obs(Id, K, V))).
retract_case(Id) :- retractall(obs(Id, _, _)), retractall(case(Id, _, _, _, _)).

error_text(E, Msg) :- format(atom(Msg), "~w", [E]).

get_load(In, Load) :-
    (   get_dict(load, In, L0) -> to_atom(L0, Load) ; Load = nominal ),
    (   memberchk(Load, [low, nominal, high]) -> true ; throw(bad_request(load)) ).
get_obs(In, Pairs) :-
    (   get_dict(obs, In, ObsD), is_dict(ObsD) -> clean_obs(ObsD, Pairs) ; Pairs = [] ).

% ---------------------------------------------------------------- POST /api/diagnose
api_diagnose(Request) :-
    catch(api_diagnose_(Request), E,
          ( error_text(E, Msg), reply_json_dict(_{error: Msg}, [status(400)]) )).

api_diagnose_(Request) :-
    http_read_json_dict(Request, In),
    get_load(In, Load),
    (   get_dict(mode, In, M0) -> to_atom(M0, Mode) ; Mode = full ),
    (   memberchk(Mode, [ded, ded_abd, ded_cons, full]) -> true ; throw(bad_request(mode)) ),
    get_obs(In, Pairs),
    uuid(U), atom_concat(web_, U, Id),
    with_mutex(kb_lock,
        setup_call_cleanup(assert_case(Id, Load, Pairs),
                           once(build_response(Id, Load, Mode, Out)),
                           retract_case(Id))),
    reply_json_dict(Out).

opt(G, V, Out) :- ( once(G) -> Out = V ; Out = null ).

status_of([fn], _, normal) :- !.
status_of([unknown], _, unknown) :- !.
status_of([insufficient], _, insufficient) :- !.
status_of(_, Alts, ambiguous) :- Alts \== [], !.
status_of(_, _, fault).

hyp_json(H, _{faults: H, names: Ns}) :- findall(N, ( member(F, H), fault_name(F, N) ), Ns).

why_text(contradicted(F, Alts), T) :- !,
    fault_name(F, N),
    findall(S, ( member(V-St, Alts), var_text(V, VT, _), format(atom(S), "~w ~w", [VT, St]) ), Ss),
    atomic_list_concat(Ss, '; ', L),
    format(atom(T), "~w requires at least one of [~w], but the observed variables show none of them", [N, L]).
why_text(exclusive(A, B), T) :- !,
    format(atom(T), "~w and ~w cannot both hold (the net pressure residual has a single sign)", [A, B]).
why_text(X, T) :- format(atom(T), "~w", [X]).

state_json(Id, _{var: V, label: T, unit: Un, state: S, deviation: Dv, low: Lo, high: Hi, borderline: B}) :-
    diag_var(V), state(Id, V, S), dev(Id, V, Dv), var_text(V, T, Un),
    eff_tol(V, Lo0, Hi),
    ( Lo0 < -100 -> Lo = null ; Lo = Lo0 ),
    ( borderline(Id, V) -> B = true ; B = false ).

proof_strings(Id, Strs) :-
    findall(R, fired(Id, R, _), Rs0), sort(Rs0, Rs1),
    ( length(Rs1, L), L > 3 -> length(Rs, 3), append(Rs, _, Rs1) ; Rs = Rs1 ),
    findall(S, ( member(R, Rs), with_output_to(string(S), sld_trace(Id, R)) ), Strs).

build_response(Id, Load, Mode, Out) :-
    evidence_count(Id, NObs),
    once(diagnose(Id, Mode, diag(Pred, Alts, Ranked, Info))),
    status_of(Pred, Alts, Status),
    hyp_json(Pred, Best),
    findall(J, ( member(F, Pred), fault_name(F, N),
                 ( fault_confidence(Id, F, Cf) -> true ; Cf = null ),
                 ( maint(F, _, U, _, _) -> true ; U = none ),
                 J = _{id: F, name: N, confidence: Cf, urgency: U} ), Dx),
    maplist(hyp_json, Alts, AltsJ),
    ( length(Ranked, Len), Len > 6 -> length(Top, 6), append(Top, _, Ranked) ; Top = Ranked ),
    findall(_{score: Sc, faults: D, names: Ns},
            ( member(Sc-D, Top), findall(N2, ( member(F2, D), fault_name(F2, N2) ), Ns) ), RankedJ),
    findall(SJ, state_json(Id, SJ), States),
    findall(_{name: Nm, text: Tx}, ( cond_text(Nm, Tx), cond(Id, Nm) ), Conds),
    findall(_{id: RId, fault: RF, text: RT}, ( fired(Id, RId, RF), rule_text(RId, RT) ), Rules),
    (   Mode == full, \+ memberchk(Pred, [[insufficient]])
    ->  min_covers(Id, Covers),
        findall(_{faults: D3, reason: Why}, ( member(D3, Covers), inconsistent(Id, D3, W0), why_text(W0, Why) ), Rej),
        length(Covers, NCov)
    ;   Rej = [], NCov = 0 ),
    length(Rej, NRej),
    findall(V4, ( diag_var(V4), state(Id, V4, S4), S4 \== normal ), Abn), length(Abn, NAbn),
    length(Rules, NRules),
    findall(x, cond(Id, _), Cs0), length(Cs0, NCond),
    plan(Id, Pred, Plan), maplist(rec_json, Plan, PlanJ),
    questions_json(Id, Pred, Alts, QJ),
    narrative(Id, Pred, Alts, Narr),
    proof_strings(Id, Proofs),
    opt(conversion(Id, X0), X0, Xv), opt(selectivity(Id, S0), S0, Sv),
    opt(pressure_residual(Id, R0), R0, Rv), opt(dev(Id, tmis, T0), T0, Tv),
    opt(energy_residual(Id, E0), E0, Ev),
    findall(RS, ( sensor_var(K), obs(Id, K, X1), RS = K-X1 ), RawPairs), dict_pairs(Raw, _, RawPairs),
    format(atom(InfoS), "~w", [Info]),
    Out = _{status: Status, mode: Mode, load: Load, observations: NObs, best: Best, diagnosis: Dx,
            alternatives: AltsJ, ranked: RankedJ, evidence: States, conditions: Conds,
            rules_fired: Rules, rejected: Rej, maintenance: PlanJ, next_evidence: QJ,
            narrative: Narr, proofs: Proofs, raw: Raw,
            counts: _{abnormal: NAbn, conditions: NCond, rules: NRules, covers: NCov, rejected: NRej},
            derived: _{conversion: Xv, selectivity: Sv, pressure_residual_kpa: Rv,
                       sensor_disagreement_k: Tv, energy_residual: Ev},
            inference_info: InfoS}.

rec_json(rec(F, Ev, A, U, Sf, Vf),
         _{fault: F, name: N, urgency: U, evidence: EvS, action: A, safety: Sf, verification: Vf,
           mechanism: Mc, consequence: Cq, rationale: Ra, math: Mt}) :-
    fault_name(F, N),
    findall(T, ( member(V-S, Ev), format(atom(T), "~w: ~w", [V, S]) ), EvS),
    (   fault_knowledge(F, Mc, Cq, Ra) -> true ; Mc = "", Cq = "", Ra = "" ),
    (   fault_math(F, Mt) -> true ; Mt = "" ).

questions_json(Id, Pred, Alts, QJ) :-
    (   Pred == [insufficient]
    ->  findall(_{variable: V, label: T, unit: U, sensors: Rs, reason: "Too few observations to diagnose"},
                ( primary_var(V), \+ observed(Id, V), var_text(V, T, U), var_raw(V, Rs) ), QJ)
    ;   Alts \== []
    ->  next_questions(Id, [Pred|Alts], Qs),
        findall(_{variable: V, label: T, unit: U, sensors: Rs, expected_abnormal_under: Idxs,
                  reason: "Separates the competing hypotheses"},
                ( member(q(V, Idxs), Qs), var_text(V, T, U), var_raw(V, Rs) ), QJ)
    ;   QJ = [] ).

% ---------------------------------------------------------------- POST /api/batch
api_batch(Request) :-
    catch(api_batch_(Request), E,
          ( error_text(E, Msg), reply_json_dict(_{error: Msg}, [status(400)]) )).

api_batch_(Request) :-
    http_read_json_dict(Request, In),
    get_dict(cases, In, Cases), is_list(Cases),
    length(Cases, N), ( N =< 200 -> true ; throw(bad_request(too_many_cases)) ),
    with_mutex(kb_lock, maplist(batch_one, Cases, Results)),
    reply_json_dict(_{results: Results}).

batch_one(Case, _{id: IdOut, status: Status, diagnosis: Label, alternatives: AltLabels,
                  urgency: Urg, observations: NObs}) :-
    (   get_dict(id, Case, I0) -> format(atom(IdOut), "~w", [I0]) ; IdOut = unnamed ),
    get_load(Case, Load), get_obs(Case, Pairs),
    uuid(U), atom_concat(web_, U, Id),
    setup_call_cleanup(assert_case(Id, Load, Pairs),
                       once(batch_core(Id, Status, Label, AltLabels, Urg, NObs)),
                       retract_case(Id)).

batch_core(Id, Status, Label, AltLabels, Urg, NObs) :-
    evidence_count(Id, NObs),
    once(diagnose(Id, full, diag(Pred, Alts, _, _))),
    status_of(Pred, Alts, Status),
    hyp_label(Pred, Label),
    findall(L, ( member(A, Alts), hyp_label(A, L) ), AltLabels),
    findall(R-Ug, ( member(F, Pred), maint(F, _, Ug, _, _), urgency_rank(Ug, R) ), Ps),
    (   Ps == [] -> Urg = none ; keysort(Ps, Sorted), last(Sorted, _-Urg) ).

% ---------------------------------------------------------------- GET endpoints
api_health(_) :-
    aggregate_all(count, ( case(_, Cat, _, _, _), Cat \== user ), N),
    reply_json_dict(_{status: "ok", dataset_cases: N}).

api_cases(_) :-
    findall(_{id: Id, category: Cat, load: L, truth: T, split: S},
            ( case(Id, Cat, L, T, S), Cat \== user ), Cs),
    reply_json_dict(_{cases: Cs}).

api_case(Request) :-
    http_parameters(Request, [id(Id, [atom])]),
    (   case(Id, Cat, L, T, S), Cat \== user
    ->  findall(V-X, obs(Id, V, X), Ps), dict_pairs(Obs, _, Ps),
        reply_json_dict(_{id: Id, category: Cat, load: L, truth: T, split: S, obs: Obs})
    ;   reply_json_dict(_{error: "unknown case"}, [status(404)]) ).

api_reference(Request) :-
    http_parameters(Request, [load(Load, [oneof([low, nominal, high]), default(nominal)])]),
    findall(V-X, ( ref(Load, V, X), sensor_var(V) ), Ps), dict_pairs(Obs, _, Ps),
    reply_json_dict(_{load: Load, obs: Obs}).

api_kb(_) :-
    faults(Fs),
    findall(_{id: F, name: N, urgency: U, action: A, safety: Sf, verification: Vf, mechanism: Mc,
              consequence: Cq, rationale: Ra, math: Mt},
            ( member(F, [fn|Fs]), fault_name(F, N), maint(F, A, U, Sf, Vf),
              fault_knowledge(F, Mc, Cq, Ra), fault_math(F, Mt) ), FJ),
    findall(_{id: Id, fault: F, group: G, text: T},
            ( rule_group(Id, G), clause(r(Id, F, _), _), rule_text(Id, T) ), RJ),
    findall(_{var: V, low: Lo, high: Hi}, ( tol(V, Lo0, Hi), ( Lo0 < -100 -> Lo = null ; Lo = Lo0 ) ), TJ),
    findall(_{fault: F, var: V, state: S}, explains(F, V, S), EJ),
    findall(_{var: V, label: T, unit: U}, var_text(V, T, U), VJ),
    reply_json_dict(_{faults: FJ, rules: RJ, tolerances: TJ, causal_model: EJ, variables: VJ}).

% ---------------------------------------------------------------- evaluation and experiments
row_json(Label, row(N, Ex, Hit, Cov, Acc, P, R, F1, FA, Mean, Max, ExR, PV),
         _{label: Label, n: N, exact: Ex, hit: Hit, coverage: Cov, accuracy: Acc, precision: P,
           recall: R, f1: F1, false_alarm: FA, mean_ms: Mean, max_ms: Max,
           explainability: ExR, plan_validity: PV}).

api_evaluate(Request) :-
    http_parameters(Request, [split(Split, [oneof([test, dev, all]), default(test)]),
                              mode(Mode, [oneof([ded, ded_abd, ded_cons, full]), default(full)])]),
    cached(eval(Split, Mode), compute_eval(Split, Mode), Out),
    reply_json_dict(Out).

cached(Key, Goal, Out) :-
    (   eval_cache(Key, x, Out) -> true
    ;   with_mutex(kb_lock,
                   (   eval_cache(Key, x, Out) -> true
                   ;   call(Goal, Out), assertz(eval_cache(Key, x, Out)) )) ).

compute_eval(Split, Mode, _{split: Split, mode: Mode, overall: Overall, categories: Cats,
                            classes: Cls, confusion: Conf}) :-
    evaluate(Mode, Split, Rs),
    summary(Rs, Row), row_json(overall, Row, Overall),
    findall(J, ( member(Cat, [a,b,c,d,e,f,g]), include(in_cat(Cat), Rs, Sub), Sub \== [],
                 summary(Sub, R1), row_json(Cat, R1, J) ), Cats),
    all_classes(All),
    findall(_{class: Cl, tp: TP, fp: FP, fn: FN, precision: P, recall: R, f1: F},
            ( member(Cl, All), class_stats(Rs, Cl, TP, FP, FN, _), Sup is TP + FN, ( Sup > 0 ; FP > 0 ),
              safe_div(TP, TP + FP, P), safe_div(TP, TP + FN, R), f1(P, R, F) ), Cls),
    Cols = [fn,fk,ft,fh,fc,fm,fq,fp,fj,fs,fi,fr,multi,unknown,insufficient],
    findall(T-Pl, ( member(res(_,_,[T],Pd,_,_,_,_), Rs), pred_label(Pd, Pl) ), Pairs),
    findall(_{truth: Rw, counts: CD},
            ( member(Rw, All), aggregate_all(count, member(Rw-_, Pairs), Tot), Tot > 0,
              findall(Cn-Ct, ( member(Cn, Cols), aggregate_all(count, member(Rw-Cn, Pairs), Ct) ), CP),
              dict_pairs(CD, _, CP) ), Conf).

api_experiment(Request) :-
    http_parameters(Request, [name(Name, [oneof([modes, groups, classes, tolerance, growth])])]),
    cached(exp(Name), compute_experiment(Name), Out),
    reply_json_dict(Out).

exp_row(Label, Variant, Mode, Dict) :-
    evaluate(Mode, test, Rs), summary(Rs, Row), row_json(Label, Row, D0),
    put_dict(_{variant: Variant, mode: Mode}, D0, Dict).

compute_experiment(modes, _{name: modes, rows: Rows}) :-
    findall(D, ( member(M, [ded, ded_abd, ded_cons, full]), once(exp_row(M, none, M, D)) ), Rows).
compute_experiment(groups, _{name: groups, rows: Rows}) :-
    findall(D, ( member(G, [kinetic, thermal, jacket, mechanical, pressure, flow, sensor]),
                 member(M, [ded, full]),
                 setup_call_cleanup(assertz(disabled_group(G)), once(exp_row(G, G, M, D)),
                                    retractall(disabled_group(G))) ), Rows).
compute_experiment(classes, _{name: classes, rows: Rows}) :-
    findall(D, ( member(Cl, [thermal, jacket, composition, pressure, mechanical, flow]),
                 setup_call_cleanup(assertz(disabled_class(Cl)), once(exp_row(Cl, Cl, full, D)),
                                    retractall(disabled_class(Cl))) ), Rows).
compute_experiment(tolerance, _{name: tolerance, rows: Rows}) :-
    findall(D, ( member(K, [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]), member(M, [ded, full]),
                 setup_call_cleanup(( retractall(tol_scale(_)), assertz(tol_scale(K)) ),
                                    once(exp_row(K, K, M, D)),
                                    ( retractall(tol_scale(_)), assertz(tol_scale(1.0)) )) ), Rows).
compute_experiment(growth, _{name: growth, rows: Rows}) :-
    findall(D, ( member(N, [0, 5, 10, 20]),
                 setup_call_cleanup(add_padding(N), once(exp_row(N, N, full, D)), remove_padding) ), Rows).
