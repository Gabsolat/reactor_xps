%% eval.pl -- evaluation: metrics, per-category tables, confusion matrix, ablation, sensitivity, KB growth
%% Metric definitions (stated in the report):
%%   Exact accuracy : predicted fault set == true fault set (case level)
%%   Label-wise Acc/P/R/F1 : Eq. 31-34 computed micro-averaged over per-class binary decisions
%%   Hit            : truth equals the top hypothesis OR one of its near-tied alternatives
%%   Coverage       : cases for which a definite hypothesis was produced (not unknown/insufficient)
%%   FalseAlarm     : normal cases diagnosed with any fault
%%   ExplainabilityRate : produced diagnoses with a non-empty evidence/support explanation
%%   PlanValidity   : plan complete AND contains the actions of every true fault

:- use_module(library(lists)).
:- use_module(library(aggregate)).
:- use_module(library(apply)).

all_classes([fn,fk,ft,fh,fc,fm,fq,fp,fj,fs,fi,fr]).

split_case(Split, Id, Cat, Truth) :-
    case(Id, Cat, _, Truth, Sp), Cat \== user,
    ( Split == all -> true ; Sp == Split ).

same_set(A, B) :- sort(A, S), sort(B, S).
exact(res(_,_,T,P,_,_,_,_)) :- same_set(T, P).
hit(res(_,_,T,P,Al,_,_,_)) :- ( same_set(T, P) ; member(A, Al), same_set(T, A) ), !.
covered(res(_,_,_,P,_,_,_,_)) :- P \== [unknown], P \== [insufficient].
in_cat(Cat, res(_,Cat,_,_,_,_,_,_)).

plan_valid(C, Truth, Pred, Ok) :-
    plan(C, Pred, Plan), plan(C, Truth, TPlan),
    (   maplist(complete_rec, Plan),
        forall(member(rec(F,_,_,_,_,_), TPlan), memberchk(rec(F,_,_,_,_,_), Plan))
    ->  Ok = 1 ; Ok = 0 ).

explained(Pe, Ev) :- Pe \== [unknown], Pe \== [insufficient], ( Pe == [fn] ; Ev \== [] ), !.

run_one(Mode, Id, Cat, Truth, res(Id, Cat, Truth, Pred, Alts, Ms, Expl, PlanOk)) :-
    statistics(cputime, T0),
    once(diagnose(Id, Mode, diag(Pred, Alts, _, _))),
    statistics(cputime, T1),
    Ms is (T1 - T0) * 1000.0,
    (   once(explain_data(Id, Mode, ex(Pe, Ev, _, _, _, _))), explained(Pe, Ev) -> Expl = 1 ; Expl = 0 ),
    plan_valid(Id, Truth, Pred, PlanOk).

evaluate(Mode, Split, Results) :-
    findall(R, ( split_case(Split, Id, Cat, Truth), run_one(Mode, Id, Cat, Truth, R) ), Results).

% ---------- label-wise statistics
class_stats(Rs, Cl, TP, FP, FN, TN) :-
    aggregate_all(count, ( member(res(_,_,T,P,_,_,_,_), Rs), memberchk(Cl,T), memberchk(Cl,P) ), TP),
    aggregate_all(count, ( member(res(_,_,T,P,_,_,_,_), Rs), \+ memberchk(Cl,T), memberchk(Cl,P) ), FP),
    aggregate_all(count, ( member(res(_,_,T,P,_,_,_,_), Rs), memberchk(Cl,T), \+ memberchk(Cl,P) ), FN),
    aggregate_all(count, ( member(res(_,_,T,P,_,_,_,_), Rs), \+ memberchk(Cl,T), \+ memberchk(Cl,P) ), TN).

safe_div(_, B, 0.0) :- B =:= 0, !.
safe_div(A, B, R) :- R is float(A / B).
f1(P, R, F) :- S is P + R, ( S =:= 0 -> F = 0.0 ; F is 2 * P * R / S ).

micro(Rs, TP, FP, FN, TN) :- all_classes(Cls), micro_(Cls, Rs, 0, 0, 0, 0, TP, FP, FN, TN).
micro_([], _, A, B, C, D, A, B, C, D).
micro_([Cl|T], Rs, A0, B0, C0, D0, A, B, C, D) :-
    class_stats(Rs, Cl, TP, FP, FN, TN),
    A1 is A0 + TP, B1 is B0 + FP, C1 is C0 + FN, D1 is D0 + TN,
    micro_(T, Rs, A1, B1, C1, D1, A, B, C, D).

summary(Rs, row(N, Ex, Hit, Cov, Acc, P, R, F1, FA, Mean, Max, ExR, PV)) :-
    length(Rs, N), N > 0,
    aggregate_all(count, ( member(X, Rs), exact(X) ), NEx), safe_div(NEx, N, Ex),
    aggregate_all(count, ( member(X, Rs), hit(X) ), NHit), safe_div(NHit, N, Hit),
    aggregate_all(count, ( member(X, Rs), covered(X) ), NCov), safe_div(NCov, N, Cov),
    micro(Rs, TP, FP, FN, TN),
    safe_div(TP + TN, TP + TN + FP + FN, Acc),
    safe_div(TP, TP + FP, P), safe_div(TP, TP + FN, R), f1(P, R, F1),
    aggregate_all(count, member(res(_,_,[fn],_,_,_,_,_), Rs), NNorm),
    aggregate_all(count, ( member(res(_,_,[fn],Pd,_,_,_,_), Rs), Pd \== [fn] ), NFA), safe_div(NFA, NNorm, FA),
    findall(M, member(res(_,_,_,_,_,M,_,_), Rs), Ms), sum_list(Ms, SumM), Mean is SumM / N, max_list(Ms, Max),
    aggregate_all(sum(E), member(res(_,_,_,_,_,_,E,_), Rs), SumE), safe_div(SumE, NCov, ExR),
    aggregate_all(sum(V), member(res(_,_,_,_,_,_,_,V), Rs), SumV), safe_div(SumV, N, PV).

print_header :-
    format("~w~t~22|~t~w~5+~t~w~7+~t~w~7+~t~w~7+~t~w~7+~t~w~7+~t~w~7+~t~w~7+~t~w~8+~t~w~8+~t~w~7+~t~w~7+~n",
           [config,'N','Exact','Hit','Cov','Acc','Prec','Rec','F1','mean ms','max ms','ExpR','PlanV']).
print_row(Label, Rs) :-
    summary(Rs, row(N, Ex, Hit, Cov, Acc, P, R, F1, _FA, Mean, Max, ExR, PV)),
    format("~w~t~22|~t~d~5+~t~3f~7+~t~3f~7+~t~3f~7+~t~3f~7+~t~3f~7+~t~3f~7+~t~3f~7+~t~3f~8+~t~3f~8+~t~3f~7+~t~3f~7+~n",
           [Label, N, Ex, Hit, Cov, Acc, P, R, F1, Mean, Max, ExR, PV]).

% ---------- full report for one mode
report(Mode, Split) :-
    evaluate(Mode, Split, Rs),
    format("~n##### MODE ~w | split ~w #####~n", [Mode, Split]),
    print_header, print_row(overall, Rs),
    forall(member(Cat, [a,b,c,d,e,f,g]),
           ( include(in_cat(Cat), Rs, Sub), Sub \== [] -> atom_concat(cat_, Cat, L), print_row(L, Sub) ; true )),
    summary(Rs, row(_,_,_,_,_,_,_,_,FA,_,_,_,_)),
    format("false-alarm rate on normal cases: ~3f~n", [FA]),
    print_class_table(Rs), print_confusion(Rs).

print_class_table(Rs) :-
    format("~nper-class (label-wise):~n~w~t~8|~t~w~6+~t~w~6+~t~w~6+~t~w~8+~t~w~8+~t~w~8+~n", [class,'TP','FP','FN',prec,rec,f1]),
    all_classes(Cls),
    forall(member(Cl, Cls),
           ( class_stats(Rs, Cl, TP, FP, FN, _), Sup is TP + FN,
             ( Sup =:= 0, FP =:= 0 -> true
             ; safe_div(TP, TP+FP, P), safe_div(TP, TP+FN, R), f1(P, R, F),
               format("~w~t~8|~t~d~6+~t~d~6+~t~d~6+~t~3f~8+~t~3f~8+~t~3f~8+~n", [Cl, TP, FP, FN, P, R, F]) ) )).

pred_label([L], L) :- !.
pred_label(_, multi).

print_confusion(Rs) :-
    Cols = [fn,fk,ft,fh,fc,fm,fq,fp,fj,fs,fi,fr,multi,unknown,insufficient],
    findall(T-Pl, ( member(res(_,_,[T],P,_,_,_,_), Rs), pred_label(P, Pl) ), Pairs),
    format("~nconfusion matrix (single-fault truth rows; predicted columns):~n~w~t~6|", [true]),
    forall(member(Cn, Cols), format("~t~w~5+", [Cn])), nl,
    all_classes(Rows),
    forall(member(Row, Rows),
           ( aggregate_all(count, member(Row-_, Pairs), Tot),
             ( Tot =:= 0 -> true
             ; format("~w~t~6|", [Row]),
               forall(member(Cn, Cols),
                      ( aggregate_all(count, member(Row-Cn, Pairs), N), format("~t~d~5+", [N]) )),
               nl ) )).

% ---------- Stage 14 experiments
exp_modes :-
    format("~n##### EXPERIMENT 1: reasoning-mode comparison (test split) #####~n"), print_header,
    forall(member(M, [ded, ded_abd, ded_cons, full]), ( evaluate(M, test, Rs), print_row(M, Rs) )).

exp_groups :-
    format("~n##### EXPERIMENT 2: rule-group ablation (test split) #####~n"), print_header,
    forall(member(G, [kinetic, thermal, jacket, mechanical, pressure, flow, sensor]),
           ( assertz(disabled_group(G)),
             evaluate(ded, test, R1), evaluate(full, test, R2),
             atom_concat('ded -rules:', G, L1), atom_concat('full -rules:', G, L2),
             print_row(L1, R1), print_row(L2, R2),
             retractall(disabled_group(G)) )).

exp_classes :-
    format("~n##### EXPERIMENT 3: evidence-class ablation (full mode, test split) #####~n"), print_header,
    forall(member(Cl, [thermal, jacket, composition, pressure, mechanical, flow]),
           ( assertz(disabled_class(Cl)), evaluate(full, test, Rs),
             atom_concat('full -evidence:', Cl, L), print_row(L, Rs),
             retractall(disabled_class(Cl)) )).

exp_tolerance :-
    format("~n##### EXPERIMENT 4: tolerance sensitivity (test split) #####~n"), print_header,
    forall(member(K, [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]),
           ( retractall(tol_scale(_)), assertz(tol_scale(K)),
             evaluate(ded, test, R1), evaluate(full, test, R2),
             format(atom(L1), 'ded   tol x~w', [K]), format(atom(L2), 'full  tol x~w', [K]),
             print_row(L1, R1), print_row(L2, R2) )),
    retractall(tol_scale(_)), assertz(tol_scale(1.0)).

% hypothesis-space growth: N inert faults + N inert rules; completeness should stay constant, time grows
exp_kb_growth :-
    format("~n##### EXPERIMENT 5: knowledge-base growth vs reasoning time (full mode, test split) #####~n"), print_header,
    forall(member(N, [0, 5, 10, 20, 30]),
           ( add_padding(N), evaluate(full, test, Rs),
             format(atom(L), 'full  +~w inert faults', [N]), print_row(L, Rs),
             remove_padding )).
add_padding(N) :-
    forall(between(1, N, I),
           ( atom_concat(fx_, I, F), atom_concat(padrule_, I, Pid),
             assertz(extra_fault(F)), assertz(explains(F, dummy, high)),
             assertz(( r(Pid, none, C) :- cond(C, high_reactor_temperature), cond(C, never_true) )) )).
remove_padding :-
    retractall(extra_fault(_)), retractall(explains(_, dummy, _)), retractall(r(_, none, _)).

% per-case CSV export (full mode) for external inspection
export_results(File) :-
    evaluate(full, all, Rs),
    open(File, write, S),
    format(S, 'id,category,truth,predicted,alternatives,ms~n', []),
    forall(member(res(Id,Cat,T,P,Al,Ms,_,_), Rs),
           ( atomic_list_concat(T, '|', Ts), atomic_list_concat(P, '|', Ps),
             findall(A, ( member(X, Al), atomic_list_concat(X, '+', A) ), As), atomic_list_concat(As, ';', Als),
             format(S, '~w,~w,~w,~w,~w,~3f~n', [Id, Cat, Ts, Ps, Als, Ms]) )),
    close(S).
