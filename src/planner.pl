%% planner.pl -- corrective-maintenance planner
%% maint(Fault, Action, Urgency, SafetyConstraint, VerificationStep)
%% The planner issues the maintenance directive for each diagnosed fault (see docs/KB_SPECIFICATION.md).
%% Directives are derived from engineering practice, NOT validated against any specific plant's SOPs/HAZOP.

:- use_module(library(pairs)).

maint(fn, 'Continue routine monitoring; no corrective action.', low,
      'None beyond normal operating procedures.', 'Re-run diagnosis at next scan interval.').
maint(fk, 'Take catalyst/activity sample; check for poisoning, fouling or deactivation; plan regeneration or replacement.', medium,
      'Do not raise temperature setpoint to compensate (runaway risk on re-activation).', 'Conversion returns to reference band at nominal load.').
maint(ft, 'Inspect feed pre-heater and its temperature controller; restore feed temperature to setpoint.', high,
      'Increase jacket cooling before correcting; watch for thermal excursion.', 'Feed temperature and reactor temperature inside bands for 30 min.').
maint(fh, 'Inspect jacket/coil for fouling; plan chemical cleaning or descaling; verify UA from heat-duty data.', high,
      'Reduce feed rate while temperature is above band; isolate and depressurise jacket before opening.', 'Estimated UA restored and reactor temperature inside band.').
maint(fc, 'Inspect chiller/utility cooling supply; check supply temperature controller and valves.', high,
      'Reduce feed rate until jacket supply temperature is restored.', 'Jacket supply temperature inside band and heat balance closes.').
maint(fm, 'Inspect agitator drive, coupling/belt, impeller and bearings.', medium,
      'Lock out and tag out the agitator before inspection; do not restart a stopped agitator in a hot exothermic charge without procedure.', 'Agitator speed, motor current and vibration inside bands.').
maint(fq, 'Quarantine feed batch; analyse feed concentration, pH and impurities; correct upstream blending.', medium,
      'Do not charge off-spec feed; review compatibility of contaminants with catalyst.', 'Feed concentration and pH inside bands.').
maint(fp, 'Inspect vent/relief path and inert purge for blockage or accumulation; verify relief device status.', critical,
      'Never isolate the vent; follow depressurisation SOP; confirm relief set point before any intervention.', 'Pressure residual inside band for 30 min.').
maint(fj, 'Pressure-test jacket/coil for leakage; inspect circulation pump, strainers and valves.', high,
      'Isolate jacket only with alternative cooling available; consider feed reduction; check for process-side contamination.', 'Jacket pressure and flow inside bands; leak test passed.').
maint(fs, 'Inspect mechanical seal, flush system and shaft alignment; plan seal replacement.', critical,
      'Treat as loss of containment: assess toxic/flammable release; restrict access; follow emergency procedure.', 'Level stable, no leak at seal, vibration inside band.').
maint(fi, 'Verify and recalibrate or replace the disagreeing temperature sensor against the redundant sensor.', medium,
      'Operate on the redundant sensor/outlet reading until verified; do not trust control action on the suspect sensor.', 'Tr and Tout agree within tolerance.').
maint(fr, 'Inspect feed control valve, positioner and flow transmitter; return loop to cascade/auto after verification.', high,
      'Place feed loop in manual at load-reference flow; watch reactor temperature during change.', 'Feed flow matches load reference.').
maint(unknown, 'Escalate to process engineer: observations not consistent with the fault model; verify sensors.', medium,
      'Treat as unverified abnormal condition.', 'Manual inspection of flagged variables.').
maint(insufficient, 'Restore instrumentation or collect more observations before diagnosing.', medium,
      'Operate conservatively.', 'At least 5 observations available.').

urgency_rank(critical, 4). urgency_rank(high, 3). urgency_rank(medium, 2). urgency_rank(low, 1).

supporting_evidence(C, F, Ev) :-
    findall(V-S, ( explains(F, V, S), state(C, V, S) ), L), sort(L, Ev).

% plan(Case, PredictedFaults, PlanRecords) -- ordered by urgency (most urgent first)
plan(C, Pred, Plan) :-
    findall(R-rec(F, Ev, A, U, Sf, Vf),
            ( member(F, Pred), maint(F, A, U, Sf, Vf), urgency_rank(U, R), supporting_evidence(C, F, Ev) ), L0),
    keysort(L0, L1), reverse(L1, L2), pairs_values(L2, Plan).

complete_rec(rec(F, _, A, U, S, V)) :- atom(F), atom(A), atom(U), atom(S), atom(V), A \== '', S \== '', V \== ''.

print_plan(Plan) :-
    forall(nth1(I, Plan, rec(F, Ev, A, U, S, V)),
           ( fault_name(F, N),
             format("  ~w. [~w] ~w (~w)~n", [I, U, N, F]),
             format("     Evidence    : ~w~n", [Ev]),
             format("     Action      : ~w~n", [A]),
             format("     Safety      : ~w~n", [S]),
             format("     Verification: ~w~n", [V]) )).
