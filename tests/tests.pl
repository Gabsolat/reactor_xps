%% tests/tests.pl -- hand-constructed unit tests (expected outputs derived by hand, see docs)
%% Run (project root):  swipl -q -s tests/tests.pl -g run_tests -t halt
:- ensure_loaded('../src/main').

raw_vars([tr,tin,tout,tjin,tj,pr,mf,cain,ca,cb,cp,qr,vr,na,pj,mj,ph,vrms,im]).

% mk(+Id, +Overrides(V=X list), +DroppedVars): reference nominal observations with changes
mk(Id, Over, Drop) :-
    retractall(obs(Id, _, _)), retractall(case(Id, _, _, _, _)),
    assertz(case(Id, user, nominal, [], none)),
    raw_vars(Vs),
    forall(( member(V, Vs), \+ memberchk(V, Drop) ),
           (   memberchk(V = X, Over) -> assertz(obs(Id, V, X))
           ;   ref(nominal, V, X0), assertz(obs(Id, V, X0)) )).

% test(Name, Overrides, Dropped, Expected fault set)   [full mode]
test(normal,      [], [], [fn]).
test(fp,          [pr=277.2], [], [fp]).
test(fh,          [tr=361, tout=361, pr=225.8, qr=213.2, ca=200], [], [fh]).
test(fi,          [tr=362], [], [fi]).
test(fk,          [tr=340, tout=340, ca=1000, cp=950, cb=50, pr=149.7, qr=125.4], [], [fk]).
test(multi_fp_fj, [pr=277.2, pj=140, mj=1.0, tj=312], [], [fj, fp]).
test(fi_plus_fk,  [tr=355, tout=340, ca=1000, cp=950, cb=50, pr=149.7, qr=125.4], [], [fi, fk]).
test(incomplete_fp, [pr=277.2], [tr, tout, tin], [fp]).
test(few_obs,     [], [tr,tin,tout,tjin,tj,pr,mf,cain,ca,cb,cp,qr,vr,na,pj,mj], [insufficient]).

run_tests :-
    findall(N-Ok, ( test(N, Over, Drop, Exp),
                    atom_concat(t_, N, Id), mk(Id, Over, Drop),
                    once(diagnose(Id, full, diag(P, _, _, _))),
                    ( same_set(P, Exp) -> Ok = pass ; Ok = fail(P, Exp) ),
                    format("~w~t~20| ~w~n", [N, Ok]) ), Rs),
    % SLD proof exists for a fired rule
    mk(t_sld, [pr=277.2], []),
    (   solve(r(rp01, fp, t_sld), _) -> format("sld_proof_rp01~t~20| pass~n") ; format("sld_proof_rp01~t~20| fail~n") ),
    % consistency check rejects fc when jacket evidence is normal (case t_fh)
    (   inconsistent(t_fh, [fc], _) -> format("consistency_rejects_fc~t~20| pass~n") ; format("consistency_rejects_fc~t~20| fail~n") ),
    findall(x, member(_-fail(_,_), Rs), Fs), length(Fs, NF),
    format("~nfailures: ~w~n", [NF]),
    ( NF =:= 0 -> true ; halt(1) ).
