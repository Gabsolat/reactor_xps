%% narrative.pl -- expert explanation text generated from the knowledge base
%% fault_knowledge(Fault, Mechanism, Consequence, Rationale)  and  fault_math(Fault, LaTeX)

fault_knowledge(fn,
 'All monitored variables are consistent with the load reference and with the energy and material balances.',
 'No degradation is indicated; continued operation within the current envelope is supported by the evidence.',
 'Routine monitoring is sufficient because no variable departs from its tolerance band and the energy balance closes.').
fault_knowledge(fk,
 'Loss of active catalytic sites lowers the rate constant. Because the reaction is exothermic, less heat is generated, so the reactor cools while conversion falls.',
 'Off-specification product and unreacted feed carried downstream; a thermal excursion is possible if activity returns abruptly or if the temperature set point is raised to compensate.',
 'A catalyst sample distinguishes poisoning, fouling and sintering, which need different remedies. Activity cannot be restored by operating adjustments alone, so regeneration or replacement is planned.').
fault_knowledge(ft,
 'An elevated feed temperature adds sensible heat to the energy balance, raising reactor temperature, which accelerates the reaction through the Arrhenius dependence.',
 'Thermal excursion, loss of selectivity and, if jacket capacity is exceeded, runaway.',
 'The feed pre-heater and its controller are the only element that changes the feed enthalpy, so they are inspected first. Cooling is increased before the correction to avoid a transient overshoot.').
fault_knowledge(fh,
 'Fouling or scaling raises the thermal resistance of the jacket wall, so the overall coefficient falls and the jacket removes less heat at the same flow and supply temperature.',
 'Sustained temperature rise, higher conversion, lower selectivity, and eventual runaway risk at high load.',
 'Jacket supply, feed temperature and jacket flow are normal, which isolates the wall resistance as the cause. Cleaning restores the coefficient; reducing the feed rate limits heat generation until then.').
fault_knowledge(fc,
 'The coolant arrives warmer than specified, reducing the temperature driving force across the jacket and therefore the heat removed.',
 'Temperature rise and thermal excursion; the problem originates upstream of the reactor in the utility system.',
 'The chiller or utility supply and its temperature controller are inspected because the reactor-side hardware is unaffected. Feed is reduced until the supply temperature is restored.').
fault_knowledge(fm,
 'Reduced agitator speed or impeller damage lowers power draw and mixing intensity, creating dead zones and degrading heat and mass transfer.',
 'Hot spots, poor conversion and selectivity, and possible local thermal excursion in an exothermic charge.',
 'Speed, motor current and vibration together separate drive failure from process effects. The agitator is locked out before inspection to protect personnel.').
fault_knowledge(fq,
 'The feed carries a lower reactant concentration or contaminants, so heat generation and conversion both fall; an abnormal pH points to contamination.',
 'Off-specification product, possible catalyst damage and unstable heat balance.',
 'Feed analysis confirms the concentration and pH deviation, which separates this fault from catalyst degradation. Off-specification feed must not be charged.').
fault_knowledge(fp,
 'Pressure exceeds what the measured temperature explains through vapour pressure, indicating accumulation of non-condensables or a restricted vent.',
 'Overpressure, relief-device lift and loss of containment if the vent remains restricted.',
 'The vent and relief path are inspected first because they are the only route for excess pressure. The vent must never be isolated, and relief set points are confirmed before any intervention.').
fault_knowledge(fj,
 'Reduced jacket flow or leakage lowers the heat-exchanger effectiveness and the jacket pressure, so the jacket outlet warms while less heat is removed.',
 'Loss of cooling capacity, thermal excursion and possible contamination of the process by coolant.',
 'A pressure test locates leakage; the circulation pump, strainers and valves are checked for flow restriction. Alternative cooling must be available before the jacket is isolated.').
fault_knowledge(fs,
 'The mechanical seal is leaking: liquid volume and pressure fall below what the balances predict while shaft vibration rises.',
 'Loss of containment with possible toxic or flammable release.',
 'Because the failure mode is a release, the plant is treated as having lost containment: access is restricted and the emergency procedure is followed before seal replacement.').
fault_knowledge(fi,
 'The reactor temperature probe and the independent outlet probe disagree, although the physical evidence (conversion, duty, jacket temperatures) is unaffected.',
 'Control action based on a wrong temperature, which can itself cause a thermal excursion.',
 'The redundant reading is trusted until the suspect probe is verified against it. This prevents the controller from acting on a false measurement.').
fault_knowledge(fr,
 'The feed flow differs from the load reference, so residence time and the heat balance shift.',
 'Off-specification conversion and a thermal disturbance proportional to the flow error.',
 'The control valve, positioner and transmitter are inspected; the loop is held in manual at the reference flow while the reactor temperature is watched.').

% key governing relation behind each diagnosis (rendered with LaTeX by the interface)
fault_math(fn, '\\rho_E=\\dfrac{\\dot Q_{gen}-\\dot Q_r-\\dot Q_j}{\\dot Q_{gen}}\\approx 0').
fault_math(fk, 'X=\\dfrac{k\\tau}{1+k\\tau},\\qquad k=a\\,k_0\\,e^{-E_a/(R\\,T_r)}').
fault_math(ft, '\\rho V_r c_p\\dfrac{dT_r}{dt}=\\dot m_f c_p\\,(T_{in}-T_r)+(-\\Delta H_r)\\,r_A V_r-\\dot Q_j').
fault_math(fh, '\\dot Q_j=\\varepsilon\\,\\dot m_j c_{pj}\\,(T_r-T_{j,in}),\\quad \\varepsilon=1-e^{-UA/(\\dot m_j c_{pj})}').
fault_math(fc, '\\dot Q_j=\\varepsilon\\,\\dot m_j c_{pj}\\,(T_r-T_{j,in})').
fault_math(fm, 'P_{agit}=N_p\\,\\rho\\,N^3 D^5').
fault_math(fq, '\\dot Q_{gen}=(-\\Delta H_r)\\,\\dfrac{\\dot m_f}{\\rho}\\,C_{A,in}\\,X').
fault_math(fp, 'r_P=P_r-P_{exp}(T),\\qquad P_{exp}=P_{atm}+P_v(T)').
fault_math(fj, '\\dot m_{j,out}=\\dot m_{j,in}-\\dot m_{leak}').
fault_math(fs, '\\dfrac{dV_r}{dt}=\\dot V_{in}-\\dot V_{out}-\\dot V_{leak}').
fault_math(fi, 'r_T=\\left|T_r-T_{out}\\right|').
fault_math(fr, '\\tau=\\dfrac{V_r}{\\dot V_f}').

state_word(low, 'below its band').
state_word(high, 'above its band').

abnormal_sentence(C, Sentence) :-
    diag_var(V), state(C, V, S), S \== normal, dev(C, V, D), var_text(V, T, U),
    state_word(S, W),
    (   memberchk(V, [pres, tmis])
    ->  format(atom(Sentence), "~w is ~w (~2f ~w from the expected value)", [T, W, D, U])
    ;   P is D * 100.0, format(atom(Sentence), "~w is ~w (~1f percent from the load reference)", [T, W, P]) ).

hyp_label(H, L) :- findall(N, ( member(F, H), fault_name(F, N) ), Ns), atomic_list_concat(Ns, ' together with ', L).

% narrative(+Case, +Pred, +Alts, -Paragraphs)
narrative(C, Pred, Alts, [_{title: 'Conclusion', text: T1}, _{title: 'Evidence', text: T2},
                          _{title: 'Reasoning chain', text: T3}, _{title: 'Alternatives considered', text: T4}]) :-
    evidence_count(C, N),
    hyp_label(Pred, PL),
    (   Pred == [fn]
    ->  format(atom(T1), "All ~w available observations lie inside their tolerance bands for the stated load, so the knowledge base concludes normal operation by default.", [N])
    ;   Pred == [insufficient]
    ->  format(atom(T1), "Only ~w observations were supplied. At least five are required before the knowledge base will diagnose.", [N])
    ;   Pred == [unknown]
    ->  T1 = 'The observations are abnormal but no fault hypothesis within the knowledge base is consistent with them.'
    ;   Alts == []
    ->  format(atom(T1), "The knowledge base concludes: ~w.", [PL])
    ;   format(atom(T1), "The best-supported conclusion is: ~w. Competing hypotheses remain, so the diagnosis is ambiguous until further evidence is supplied.", [PL]) ),
    findall(S, abnormal_sentence(C, S), Ss),
    (   Ss == [] -> T2 = 'No variable lies outside its tolerance band.'
    ;   atomic_list_concat(Ss, '; ', B), format(atom(T2), "Abnormal findings: ~w.", [B]) ),
    findall(Id-Tx, ( fired(C, Id, _), rule_text(Id, Tx) ), Rs),
    (   Rs == [] -> D1 = 'Deduction: no rule fired.'
    ;   findall(Q, ( member(Id-Tx, Rs), format(atom(Q), "rule ~w (~w)", [Id, Tx]) ), Qs),
        atomic_list_concat(Qs, '; ', QJ), format(atom(D1), "Deduction: ~w.", [QJ]) ),
    (   memberchk(Pred, [[fn], [insufficient], [unknown]]) -> T3 = D1
    ;   min_covers(C, Covers), length(Covers, NC),
        include(consistent_cover(C), Covers, Ok), length(Ok, NO), Elim is NC - NO,
        format(atom(T3), "~w Abduction: ~w minimal explanation(s) cover every primary symptom. Consistency checking eliminated ~w, leaving ~w. Ranking by weighted evidence selects: ~w.", [D1, NC, Elim, NO, PL]) ),
    (   memberchk(Pred, [[fn], [insufficient], [unknown]]) -> T4 = 'Not applicable.'
    ;   min_covers(C, Cv),
        findall(Q, ( member(D, Cv), inconsistent(C, D, _), hyp_label(D, Dl), format(atom(Q), "~w", [Dl]) ), Rj),
        (   Rj == [] -> R1 = 'No competing explanation was eliminated.'
        ;   atomic_list_concat(Rj, '; ', RjA), format(atom(R1), "Eliminated by consistency checking: ~w.", [RjA]) ),
        (   Alts == [] -> T4 = R1
        ;   findall(Q, ( member(A, Alts), hyp_label(A, Al), format(atom(Q), "~w", [Al]) ), As),
            atomic_list_concat(As, '; ', AsA),
            format(atom(T4), "~w Still competing within the ranking margin: ~w.", [R1, AsA]) ) ).
