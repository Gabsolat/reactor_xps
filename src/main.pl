%% main.pl -- loader and entry points
%% Run:  swipl -q -s src/main.pl -g run_all -t halt        (from the project root)

:- dynamic case/5, obs/3, ref/3.
:- ensure_loaded(params).
:- ensure_loaded(evidence).
:- ensure_loaded(kb).
:- ensure_loaded(reasoning).
:- ensure_loaded(planner).
:- ensure_loaded(explain).
:- ensure_loaded(consult).
:- ensure_loaded(narrative).
:- ensure_loaded(eval).
:- ensure_loaded('../data/reference').
:- ensure_loaded('../data/cases').

% ---- interactive use:  new_case(my1, nominal, [tr=350, tout=350, pr=277, ...]), explain(my1).
new_case(Id, Load, Obs) :-
    retractall(obs(Id, _, _)), retractall(case(Id, _, _, _, _)),
    assertz(case(Id, user, Load, [], none)),
    forall(member(V = X, Obs), assertz(obs(Id, V, X))).

% ---- representative demonstrations (reasoning modes, SLD trace, explanation)
first_case(Cat, Split, Id) :- case(Id, Cat, _, _, Split), !.

demos :-
    format("~n##### DEMONSTRATIONS (Test H: explanation and maintenance) #####~n"),
    forall(member(Cat, [b, c, g]),
           ( first_case(Cat, test, Id) ->
               format("~n--- category ~w, case ~w ---~n", [Cat, Id]),
               demo_deduction(Id), demo_abduction(Id), demo_consistency(Id),
               explain(Id, full)
           ; true )),
    ( first_case(b, test, Id2), fired(Id2, RId, _) -> sld_trace(Id2, RId) ; true ).

run_all :-
    aggregate_all(count, case(_,_,_,_,_), NC),
    aggregate_all(count, case(_,_,_,_,test), NT),
    format("Reactor expert system | cases: ~w (test split: ~w)~n", [NC, NT]),
    report(full, test), report(ded, test),
    exp_modes, exp_groups, exp_classes, exp_tolerance, exp_kb_growth,
    demos.

run_dev :- report(full, dev).
