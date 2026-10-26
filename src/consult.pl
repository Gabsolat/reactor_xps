%% consult.pl -- consultation facility (classic expert-system behaviour):
%% when the inference engine cannot decide, it names the evidence it still needs.

% derived state variable -> raw sensors that would supply it
var_raw(th,   [tout, tr]).
var_raw(tmis, [tr, tout]).
var_raw(x,    [ca, cain]).
var_raw(pres, [pr]).
var_raw(V,    [V]) :- \+ member(V, [th, tmis, x, pres]).

% discriminating_var(+Case, +Hypotheses, ?Var, -ExpectingIdx)
% Var is unobserved, and a necessary effect of SOME but not ALL competing hypotheses.
discriminating_var(C, Hyps, V, Idxs) :-
    Hyps = [_, _|_],
    primary_var(V), \+ observed(C, V),
    findall(I, ( nth1(I, Hyps, H), member(F, H), must_any(F, Alts), memberchk(V-_, Alts) ), L0),
    sort(L0, Idxs), Idxs \== [],
    length(Hyps, N), length(Idxs, M), M < N.

next_questions(C, Hyps, Qs) :-
    findall(q(V, Idxs), discriminating_var(C, Hyps, V, Idxs), Qs).
