:- encoding(utf8).
%% kb.pl -- Prolog knowledge base: conditions, diagnostic rules, causal model, constraints
%% Layers:  state/3 (evidence)  ->  cond/2 (derived engineering conditions)  ->  r/3 (diagnostic rules)
%% Every rule has an id (r..), group (rule_group/2) and engineering basis (see docs/KB_SPECIFICATION.md).

:- dynamic r/3, cond/2, explains/3, extra_fault/1.
:- discontiguous r/3, cond/2, explains/3.

% ---------- fault universe (F_U merged into F_C / F_J: no independent signature with this sensor set)
base_fault(fk). base_fault(ft). base_fault(fh). base_fault(fc). base_fault(fm). base_fault(fq).
base_fault(fp). base_fault(fj). base_fault(fs). base_fault(fi). base_fault(fr).
faults(L) :- findall(F, base_fault(F), L0), findall(F, extra_fault(F), L1), append(L0, L1, L).

% ---------- level-1 conditions: symbolic states with engineering names
cond(C, low_reactor_temperature)        :- state(C, th, low).
cond(C, high_reactor_temperature)       :- state(C, th, high).
cond(C, low_conversion)                 :- state(C, x, low).
cond(C, high_conversion)                :- state(C, x, high).
cond(C, high_feed_temperature)          :- state(C, tin, high).
cond(C, high_jacket_supply_temperature) :- state(C, tjin, high).
cond(C, high_jacket_outlet_temperature) :- state(C, tj, high).
cond(C, low_jacket_pressure)            :- state(C, pj, low).
cond(C, low_jacket_flow)                :- state(C, mj, low).
cond(C, low_agitator_speed)             :- state(C, na, low).
cond(C, low_motor_current)              :- state(C, im, low).
cond(C, high_vibration)                 :- state(C, vrms, high).
cond(C, low_level)                      :- state(C, vr, low).
cond(C, high_pressure_residual)         :- state(C, pres, high).
cond(C, low_pressure_residual)          :- state(C, pres, low).
cond(C, high_feed_flow)                 :- state(C, mf, high).
cond(C, low_feed_flow)                  :- state(C, mf, low).
cond(C, low_feed_concentration)         :- state(C, cain, low).
cond(C, low_feed_ph)                    :- state(C, ph, low).
cond(C, sensor_disagreement)            :- state(C, tmis, high).
cond(C, energy_imbalance)               :- state(C, ebal, high).
cond(C, energy_imbalance)               :- state(C, ebal, low).

% ---------- level-2 (compound) conditions: engineering patterns from the energy balance
% Heat generation exceeds removal: temperature and conversion both rise (Arrhenius feedback, Eq. 6, 7)
cond(C, heat_removal_deficit) :- cond(C, high_reactor_temperature), cond(C, high_conversion).
% Rate suppression quenches the exotherm: conversion and temperature both fall
cond(C, activity_loss_pattern) :- cond(C, low_conversion), cond(C, low_reactor_temperature).

% ---------- diagnostic rules (Horn clauses with negation-as-failure for exceptions)
% kinetic / feed
r(rk01, fk, C) :- cond(C, activity_loss_pattern),
                  ( observed(C, cain) ; observed(C, ph) ),
                  \+ cond(C, low_feed_concentration), \+ cond(C, low_feed_ph).
r(rq01, fq, C) :- cond(C, activity_loss_pattern), cond(C, low_feed_concentration).
r(rq02, fq, C) :- cond(C, activity_loss_pattern), cond(C, low_feed_ph).
% thermal
r(rh01, fh, C) :- cond(C, heat_removal_deficit),
                  observed(C, tin), observed(C, tjin), observed(C, mj),
                  \+ cond(C, high_feed_temperature), \+ cond(C, high_jacket_supply_temperature),
                  \+ cond(C, low_jacket_flow).
r(rc01, fc, C) :- cond(C, heat_removal_deficit), cond(C, high_jacket_supply_temperature).
r(rc02, fc, C) :- cond(C, high_jacket_supply_temperature), cond(C, high_jacket_outlet_temperature).
r(rt01, ft, C) :- cond(C, high_reactor_temperature), cond(C, high_feed_temperature).
% jacket circulation
r(rj01, fj, C) :- cond(C, low_jacket_pressure), cond(C, low_jacket_flow).
r(rj02, fj, C) :- cond(C, low_jacket_flow), cond(C, high_jacket_outlet_temperature).
% mechanical
r(rm01, fm, C) :- cond(C, low_agitator_speed), cond(C, low_motor_current).
r(rm02, fm, C) :- cond(C, high_vibration), cond(C, low_agitator_speed).
r(rm03, fm, C) :- cond(C, high_vibration), cond(C, low_motor_current).
r(rs01, fs, C) :- cond(C, low_level), cond(C, high_vibration).
r(rs02, fs, C) :- cond(C, low_level), cond(C, low_pressure_residual).
% pressure
r(rp01, fp, C) :- cond(C, high_pressure_residual).
% control / flow
r(rr01, fr, C) :- cond(C, high_feed_flow).
r(rr02, fr, C) :- cond(C, low_feed_flow).
% instrumentation (redundant temperature sensors disagree)
r(ri01, fi, C) :- cond(C, sensor_disagreement).

rule_group(rk01, kinetic).    rule_group(rq01, kinetic).     rule_group(rq02, kinetic).
rule_group(rh01, thermal).    rule_group(rc01, thermal).     rule_group(rc02, thermal).
rule_group(rt01, thermal).    rule_group(rj01, jacket).      rule_group(rj02, jacket).
rule_group(rm01, mechanical). rule_group(rm02, mechanical).  rule_group(rm03, mechanical).
rule_group(rs01, mechanical). rule_group(rs02, mechanical).  rule_group(rp01, pressure).
rule_group(rr01, flow).       rule_group(rr02, flow).        rule_group(ri01, sensor).

% ---------- causal model: explains(Fault, Variable, State)  (abduction)
explains(fk, th, low).   explains(fk, x, low).    explains(fk, qr, low).  explains(fk, s, high).
explains(fq, th, low).   explains(fq, x, low).    explains(fq, qr, low).  explains(fq, s, high).
explains(fq, cain, low). explains(fq, ph, low).
explains(fh, th, high).  explains(fh, x, high).   explains(fh, qr, high). explains(fh, s, low).
explains(fc, th, high).  explains(fc, x, high).   explains(fc, qr, high). explains(fc, s, low).
explains(fc, tjin, high). explains(fc, tj, high).
explains(ft, th, high).  explains(ft, x, high).   explains(ft, s, low).   explains(ft, tin, high). explains(ft, tj, high). explains(ft, qr, high). explains(ft, qr, low).
explains(fj, pj, low).   explains(fj, mj, low).   explains(fj, tj, high).
explains(fj, th, high).  explains(fj, x, high).   explains(fj, s, low).  explains(fj, qr, high).
explains(fm, na, low).   explains(fm, im, low).   explains(fm, vrms, high).
explains(fs, vr, low).   explains(fs, pres, low). explains(fs, vrms, high).
explains(fp, pres, high).
explains(fr, mf, high).  explains(fr, mf, low).
explains(fr, th, high).  explains(fr, th, low).
explains(fr, x, low).    explains(fr, x, high).   explains(fr, qr, high). explains(fr, qr, low).
explains(fi, tmis, high).

% ---------- necessary effects (strong fault model) for consistency-based diagnosis
% must_any(Fault, [Var-State,...]): if any listed variable is observed, at least one observed
% variable must show its listed state, otherwise the fault is inconsistent with the observations.
must_any(fk, [x-low, th-low, qr-low]).
must_any(fq, [cain-low, ph-low]).
must_any(fh, [th-high, x-high]).
must_any(fc, [tjin-high, tj-high]).
must_any(ft, [tin-high]).
must_any(fj, [pj-low, mj-low]).
must_any(fm, [na-low, im-low, vrms-high]).
must_any(fs, [vr-low, pres-low, vrms-high]).
must_any(fp, [pres-high]).
must_any(fr, [mf-high, mf-low]).
must_any(fi, [tmis-high]).

% fault-set constraint: net pressure residual has one sign
exclusive(fp, fs).

% ---------- readable texts for explanation
fault_name(fn, 'Normal operation').
fault_name(fk, 'Catalyst / kinetic degradation').
fault_name(ft, 'Excessive reaction temperature (feed-temperature excursion)').
fault_name(fh, 'Heat-transfer degradation (jacket fouling)').
fault_name(fc, 'Cooling-system fault (jacket supply too warm)').
fault_name(fm, 'Mixing / agitation fault').
fault_name(fq, 'Feed composition / quality fault').
fault_name(fp, 'Abnormal reactor pressure (vent / inert accumulation)').
fault_name(fj, 'Jacket leakage or circulation fault').
fault_name(fs, 'Seal / containment fault').
fault_name(fi, 'Instrumentation (temperature sensor) fault').
fault_name(fr, 'Reaction-control fault (feed-flow loop)').
fault_name(unknown, 'No consistent explanation found').
fault_name(insufficient, 'Insufficient observations').

var_text(th, 'Reactor temperature (outlet/best estimate)', 'K').
var_text(tmis, 'Tr-Tout sensor disagreement', 'K').
var_text(x, 'Conversion of A', '-').
var_text(s, 'Selectivity to product P', '-').
var_text(qr, 'Stream heat duty', 'kW').
var_text(tin, 'Feed temperature', 'K').
var_text(tjin, 'Jacket supply temperature', 'K').
var_text(tj, 'Jacket outlet temperature', 'K').
var_text(pres, 'Pressure residual vs vapour-pressure estimate', 'kPa').
var_text(mf, 'Feed mass flow', 'kg/s').
var_text(cain, 'Feed concentration of A', 'mol/m³').
var_text(ph, 'Feed pH', '-').
var_text(vr, 'Liquid level (volume)', 'm³').
var_text(na, 'Agitator speed', 'rpm').
var_text(pj, 'Jacket pressure', 'kPa').
var_text(mj, 'Jacket coolant flow', 'kg/s').
var_text(vrms, 'Vibration RMS', 'mm/s').
var_text(im, 'Motor current', 'A').
var_text(ebal, 'Energy-balance residual', '-').

cond_text(heat_removal_deficit, 'heat generation exceeds heat removal (temperature and conversion both high)').
cond_text(activity_loss_pattern, 'reaction rate suppressed (conversion and temperature both low)').
cond_text(sensor_disagreement, 'redundant temperature sensors Tr and Tout disagree').
cond_text(high_feed_temperature, 'feed temperature above band').
cond_text(high_jacket_supply_temperature, 'jacket supply temperature above band').
cond_text(low_jacket_flow, 'jacket coolant flow below band').
cond_text(low_jacket_pressure, 'jacket pressure below band').
cond_text(high_jacket_outlet_temperature, 'jacket outlet temperature above band').
cond_text(low_feed_concentration, 'feed concentration below band').
cond_text(low_feed_ph, 'feed pH below band').
cond_text(low_agitator_speed, 'agitator speed below band').
cond_text(low_motor_current, 'motor current below band').
cond_text(high_vibration, 'vibration above band').
cond_text(low_level, 'liquid level below band').
cond_text(high_pressure_residual, 'pressure above what temperature explains').
cond_text(low_pressure_residual, 'pressure below what temperature explains').
cond_text(high_feed_flow, 'feed flow above load reference').
cond_text(low_feed_flow, 'feed flow below load reference').
cond_text(low_reactor_temperature, 'reactor temperature below band').
cond_text(high_reactor_temperature, 'reactor temperature above band').
cond_text(low_conversion, 'conversion below band').
cond_text(high_conversion, 'conversion above band').
cond_text(energy_imbalance, 'energy balance does not close (measurement inconsistency)').

rule_text(rk01, 'Quenched reaction with normal feed quality => catalyst/kinetic degradation').
rule_text(rq01, 'Quenched reaction with dilute feed => feed-quality fault').
rule_text(rq02, 'Quenched reaction with abnormal feed pH => feed-quality fault').
rule_text(rh01, 'Heat-removal deficit while feed and jacket supply are normal => jacket fouling').
rule_text(rc01, 'Heat-removal deficit with warm jacket supply => cooling-system fault').
rule_text(rc02, 'Warm jacket supply and warm jacket outlet => cooling-system fault').
rule_text(rt01, 'High reactor temperature with high feed temperature => feed-temperature excursion').
rule_text(rj01, 'Low jacket pressure and low coolant flow => jacket leak/circulation fault').
rule_text(rj02, 'Low coolant flow and warm jacket outlet => jacket circulation fault').
rule_text(rm01, 'Low agitator speed and low motor current => mixing fault').
rule_text(rm02, 'High vibration and low agitator speed => mixing fault').
rule_text(rm03, 'High vibration and low motor current => mixing fault').
rule_text(rs01, 'Low level with high vibration => seal/containment fault').
rule_text(rs02, 'Low level with low pressure residual => seal/containment fault').
rule_text(rp01, 'Pressure above what temperature explains => abnormal pressure (vent/inerts)').
rule_text(rr01, 'Feed flow above load reference => feed-flow control fault').
rule_text(rr02, 'Feed flow below load reference => feed-flow control fault').
rule_text(ri01, 'Tr and Tout disagree while physical evidence is unaffected => temperature sensor fault').
