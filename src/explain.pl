%% explain.pl -- explanation facility and SLD proof-tree meta-interpreter

% ---------- vanilla meta-interpreter with proof trees (SLD resolution made visible)
leaf(state(_, _, _)).
leaf(observed(_, _)).
solve(true, true) :- !.
solve((A, B), (PA, PB)) :- !, solve(A, PA), solve(B, PB).
solve(\+ G, naf(G)) :- !, \+ solve(G, _).
solve(G, leaf(G)) :- leaf(G), !, call(G).
solve(G, node(G, P)) :- clause(G, Body), solve(Body, P).

print_proof(true, _).
print_proof((A, B), I) :- print_proof(A, I), print_proof(B, I).
print_proof(naf(G), I) :- tab(I), format("NAF  \\+ ~w   (no proof exists, so the exception does not apply)~n", [G]).
print_proof(leaf(G), I) :- tab(I), format("~w   [evidence layer]~n", [G]).
print_proof(node(G, P), I) :- tab(I), format("~w~n", [G]), I2 is I + 3, print_proof(P, I2).

% sld_trace(+Case, +RuleId): prints the proof tree of a fired rule
sld_trace(C, Id) :-
    r(Id, F, C), !,
    format("SLD proof of r(~w, ~w, ~w):~n", [Id, F, C]),
    solve(r(Id, F, C), P), print_proof(P, 2).
sld_trace(_, Id) :- format("Rule ~w does not fire for this case.~n", [Id]).

% ---------- explanation data (also used by the evaluator to compute ExplainabilityRate)
explain_data(C, Mode, ex(Pred, Evidence, Conds, Rules, Alts, Rejected)) :-
    diagnose(C, Mode, diag(Pred, Alts, _, _)),
    findall(V-S-D, ( diag_var(V), state(C, V, S), S \== normal, dev(C, V, D) ), E0), sort(E0, Evidence),
    findall(N, ( cond_text(N, _), cond(C, N) ), Cs0), sort(Cs0, Conds),
    findall(Id-F, fired(C, Id, F), Rules),
    (   Mode == full
    ->  min_covers(C, Covers),
        findall(D-Why, ( member(D, Covers), inconsistent(C, D, Why) ), Rejected)
    ;   Rejected = [] ).

% ---------- human-readable explanation (readable by a process engineer without reading source)
explain(C) :- explain(C, full).
explain(C, Mode) :-
    case_load(C, L),
    ( case(C, _, _, Truth, _) -> true ; Truth = [] ),
    explain_data(C, Mode, ex(Pred, Evidence, Conds, Rules, Alts, Rejected)),
    format("============================================================~n"),
    format("CASE ~w | load: ~w | recorded label (synthetic): ~w | mode: ~w~n", [C, L, Truth, Mode]),
    format("============================================================~n"),
    format("1. OBSERVED EVIDENCE (variables outside their normal band)~n"),
    (   Evidence == [] -> format("   none: all available observations are inside their bands~n")
    ;   forall(member(V-S-D, Evidence),
               ( var_text(V, T, U), upcase_atom(S, SU),
                 ( borderline(C, V) -> Bd = ' (borderline)' ; Bd = '' ),
                 format("   ~w [~w]: deviation ~4f -> ~w~w~n", [T, U, D, SU, Bd]) )) ),
    format("2. DERIVED ENGINEERING CONDITIONS~n"),
    (   Conds == [] -> format("   none~n")
    ;   forall(member(N, Conds), ( cond_text(N, T) -> format("   ~w: ~w~n", [N, T]) ; true )) ),
    format("3. RULES FIRED~n"),
    (   Rules == [] -> format("   none (diagnosis, if any, comes from abductive covering)~n")
    ;   forall(member(Id-F, Rules), ( rule_text(Id, T) -> format("   ~w -> ~w : ~w~n", [Id, F, T]) ; true )) ),
    format("4. DIAGNOSIS~n"),
    forall(member(F, Pred),
           ( fault_name(F, N),
             ( fault_confidence(C, F, Cf) -> format("   ~w (~w), evidence confidence ~2f~n", [N, F, Cf])
             ; format("   ~w (~w)~n", [N, F]) ) )),
    format("5. COMPETING AND REJECTED HYPOTHESES~n"),
    (   Alts == [] -> format("   no competing hypothesis within the ranking margin~n")
    ;   forall(member(A, Alts), format("   competing (near-tied) hypothesis: ~w -> AMBIGUOUS, more data needed~n", [A])) ),
    forall(member(D-Why, Rejected), format("   rejected ~w : ~w~n", [D, Why])),
    format("6. RECOMMENDED MAINTENANCE~n"),
    plan(C, Pred, Plan), print_plan(Plan),
    format("~n").
