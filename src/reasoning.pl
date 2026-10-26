%% reasoning.pl -- deductive, abductive and consistency-based diagnosis
%% Modes: ded | ded_abd | ded_cons | full   (used for ablation, Stage 14)
%% Symbolic membership decisions never depend on weights; weights only rank candidates.

:- use_module(library(lists)).
:- use_module(library(aggregate)).
:- dynamic disabled_group/1.

% =============== 1. DEDUCTIVE REASONING:  KB u E |= F  (SLD resolution over r/3)
fired(C, Id, F) :- r(Id, F, C), rule_group(Id, G), \+ disabled_group(G).
deductive(C, Faults) :- findall(F, fired(C, _, F), L), sort(L, Faults).

% =============== 2. ABDUCTIVE REASONING:  D u KB |= Obs   (minimal covers of primary symptoms)
abnormal_primary(C, Syms) :-
    findall(V-S, (primary_var(V), state(C, V, S), S \== normal), L), sort(L, Syms).

coverable(V-S) :- explains(_, V, S), !.

covers(D, Syms) :- forall(member(V-S, Syms), ( member(F, D), explains(F, V, S) )).

subset_n(0, _, []) :- !.
subset_n(N, [F|Fs], [F|S]) :- N1 is N - 1, subset_n(N1, Fs, S).
subset_n(N, [_|Fs], S) :- N > 0, subset_n(N, Fs, S).

hypothesis(Max, Fs, D) :- between(1, Max, N), subset_n(N, Fs, D).

minimal_in(All, D) :- \+ ( member(D2, All), D2 \== D, subset(D2, D) ).

% minimal covers (subset-minimal, cardinality <= 3). [] if nothing coverable.
min_covers(C, Covers) :-
    abnormal_primary(C, Syms0),
    include(coverable, Syms0, Syms),
    Syms \== [],
    faults(Fs),
    findall(D, ( hypothesis(3, Fs, D), covers(D, Syms) ), All),
    include(minimal_in(All), All, Covers),
    !.
min_covers(_, []).

% =============== 3. CONSISTENCY-BASED DIAGNOSIS:  KB u Obs u D |/= false
inconsistent(C, D, contradicted(F, Alts)) :-
    member(F, D), must_any(F, Alts),
    findall(V, ( member(V-_, Alts), state(C, V, _) ), Observed), Observed \== [],
    \+ ( member(V-S, Alts), state(C, V, S) ).
inconsistent(_, D, exclusive(A, B)) :- exclusive(A, B), memberchk(A, D), memberchk(B, D).

consistent_cover(C, D) :- \+ inconsistent(C, D, _).

% =============== ranking (weights rank, never decide)
sum_weights([], 0.0).
sum_weights([V-_|T], Sum) :- wt(V, W), sum_weights(T, S0), Sum is S0 + W.

hyp_score(C, D, Score) :-
    findall(V-S, ( diag_var(V), state(C, V, S), S \== normal,
                   once(( member(F, D), explains(F, V, S) )) ), Ex),
    sum_weights(Ex, SumEx),
    findall(F, ( member(F, D), fired(C, _, F) ), Fr0), sort(Fr0, Fr), length(Fr, NF),
    length(D, ND),
    Score is SumEx + 2.0 * NF - 0.5 * ND.

rank_covers(C, Covers, Ranked) :-
    findall(Sc-D, ( member(D, Covers), hyp_score(C, D, Sc) ), Ps),
    keysort(Ps, Asc), reverse(Asc, Ranked).

% Eq. (25),(26): evidence aggregation E(F), C(F) over observed entries of the causal model
fault_confidence(C, F, Conf) :-
    findall(W-M, ( explains(F, V, S), state(C, V, S0), wt(V, W), ( S0 == S -> M = 1.0 ; M = 0.0 ) ), L),
    L \== [],
    foldl(wsum, L, 0.0-0.0, E-Wt), Wt > 0, Conf is E / Wt.
wsum(W-M, E0-W0, E-W1) :- E is E0 + W * M, W1 is W0 + W.

% =============== diagnosis driver
diagnose(C, _, diag([insufficient], [], [], [few_observations])) :-
    evidence_count(C, N), N < 5, !.
diagnose(C, _, diag([fn], [], [], [normal_by_default])) :-
    \+ any_primary_abnormal(C), !.
diagnose(C, ded, diag(P, [], [], [deductive])) :- !,
    deductive(C, Dd), ( Dd == [] -> P = [unknown] ; P = Dd ).
diagnose(C, ded_cons, diag(P, [], [], [deductive, consistency])) :- !,
    deductive(C, Dd),
    findall(F, ( member(F, Dd), \+ inconsistent(C, [F], _) ), L),
    ( L == [] -> P = [unknown] ; P = L ).
diagnose(C, ded_abd, Res) :- !, abductive_result(C, false, Res).
diagnose(C, full, Res)    :- abductive_result(C, true, Res).

abductive_result(C, UseCons, diag(P, Alts, Ranked, Info)) :-
    min_covers(C, Covers0),
    (   UseCons == true -> include(consistent_cover(C), Covers0, Covers) ; Covers = Covers0 ),
    (   Covers == []
    ->  deductive(C, Dd),
        ( Dd == [] -> P = [unknown] ; P = Dd ),
        Alts = [], Ranked = [], Info = [fallback_to_deductive]
    ;   rank_covers(C, Covers, Ranked),
        Ranked = [Best-P|Rest],
        findall(D, ( member(S-D, Rest), Best - S =< 0.75 ), Alts),
        ( Alts == [] -> Info = [unique_best] ; Info = [ambiguous] )
    ).

% explicit predicates for demonstrations in the report
demo_abduction(C) :-
    min_covers(C, Covers), format("Minimal covers (no consistency filter):~n"),
    forall(member(D, Covers), format("  ~w~n", [D])).
demo_consistency(C) :-
    min_covers(C, Covers), format("Consistency check of each minimal cover:~n"),
    forall(member(D, Covers),
           ( inconsistent(C, D, Why) -> format("  ~w REJECTED: ~w~n", [D, Why])
           ; format("  ~w CONSISTENT~n", [D]) )).
demo_deduction(C) :-
    format("Rules fired:~n"), forall(fired(C, Id, F), format("  ~w => ~w~n", [Id, F])).
