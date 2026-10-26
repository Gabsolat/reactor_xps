# Knowledge-Base Specification (Appendix E / C / H material)

Reactor: **jacketed CSTR**, liquid-phase first-order exothermic reaction A → products, steady-state operation, three load cases (low 0.7 / nominal 1.0 / high 1.3 kg/s feed). Temperature held near 350 K by jacket flow under normal operation.

## 1. Fault taxonomy (refined from the F set in the brief)

`F = {F_K, F_T, F_H, F_C, F_M, F_Q, F_P, F_J, F_S, F_I, F_R, F_N}`  (12 classes)

**F_U (utility-supply abnormality) was merged into F_C and F_J.** With the selected sensor set, a utility fault appears as a warm jacket supply (F_C) or reduced jacket pressure/flow (F_J) and has no independent signature. The General Framework forbids padding the taxonomy, so a separate class is not justified. Reinstate it if an electrical-supply variable (voltage) is added.

| Id | Physical meaning | Typical causes | Observable symptoms (model) | Consequences |
|---|---|---|---|---|
| F_K | Catalyst/kinetic degradation: rate constant falls | poisoning, fouling, sintering | conversion low, T low, stream heat duty low | off-spec product, later re-activation excursion |
| F_T | Feed temperature excursion → excessive reaction temperature | pre-heater/controller failure | T_in high, T high, conversion high, selectivity low, jacket outlet warm | thermal excursion, runaway risk |
| F_H | Heat-transfer degradation: UA falls | fouling, scaling | T high, conversion high, duty high; jacket supply, feed and flow normal | thermal excursion, selectivity loss |
| F_C | Cooling-system fault: jacket supply too warm | chiller/utility fault | T_j,in high, T_j high, T high | thermal excursion |
| F_M | Mixing/agitation fault | drive/belt/impeller damage | N_a low, I_m low, vibration high | dead zones, poor heat/mass transfer |
| F_Q | Feed composition/quality fault | upstream blending error, contamination | C_A,in low, pH low, conversion low, T low | off-spec product, catalyst damage |
| F_P | Abnormal reactor pressure | blocked vent, inert accumulation | pressure above vapour-pressure estimate at measured T | overpressure, relief lift |
| F_J | Jacket leak/circulation fault | pump failure, leak, blockage | P_j low, jacket flow low, jacket outlet warm | loss of cooling, contamination |
| F_S | Seal/containment fault | seal wear, flush failure | level low, pressure residual low, vibration high | loss of containment |
| F_I | Temperature-sensor fault | drift, bias, wiring | T_r and T_out disagree; physical evidence otherwise unaffected | wrong control action |
| F_R | Reaction-control fault (feed-flow loop) | valve stuck, transmitter error | feed flow differs from load reference; conversion/duty shift | off-spec, thermal disturbance |
| F_N | Normal operation | – | all variables in band | – |

## 2. Variable dictionary

**Measured (dataset columns, 19).** `tr` reactor temperature (K, probe); `tin` feed temperature (K); `tout` outlet stream temperature (K, independent probe); `tjin` jacket supply temperature (K); `tj` jacket outlet temperature (K); `pr` reactor pressure (kPa abs); `mf` feed mass flow (kg/s); `cain` feed concentration of A (mol/m³, analyser); `ca`, `cb`, `cp` outlet concentrations of A, by-product B and product P (mol/m³); `qr` stream heat duty ṁc_p(T_out−T_in) (kW); `vr` liquid volume (m³); `na` agitator speed (rpm); `pj` jacket pressure (kPa); `mj` jacket coolant flow (kg/s); `ph` feed pH; `vrms` vibration RMS (mm/s); `im` motor current (A).
*Brief's vector vs this reactor:* `m_j`, `T_j`, `P_j` retained; `V_r` measured as level; `C_A,in` and `T_j,in` **added** (needed for X and Q_j); `e_T, e_P, X, S` are **derived** by the evidence layer (not measured); `Q_r` is the stream duty (Eq. 9). The brief's symbol clash (`C_p` vs `c_p` vs `C_P`) is resolved by: `c_p` = specific heat, `C_P` = product concentration (`cp` in code), no symbol named `C_p`.

**Derived (state variables of the evidence layer).** `th` best reactor-temperature estimate (T_out, else T_r); `tmis` |T_r − T_out| (K); `x` conversion (Eq. 6); `s` selectivity (Eq. 8); `pres` pressure residual P_r − P_exp(T) (kPa); `ebal` energy-balance residual (Eq. 23). Each takes states `low | normal | high`.

## 3. Rule inventory with provenance (Appendix E)

Tolerance bands (`src/params.pl`) are **engineering assumptions** sized from the synthetic sensor-noise model; they were calibrated using the *dev* split only (30%), then frozen. Rules R-xx encode the signatures derived from the energy/material balances (report Eqs. 6–25); the *basis* column names the textbook relationship that justifies each.

| Id | Rule (Horn clause, NAF in exceptions) | Engineering basis | Status |
|---|---|---|---|
| rk01 | activity_loss_pattern ∧ (cain or ph observed) ∧ ¬low feed conc ∧ ¬low pH → F_K | Rate ↓ ⇒ less heat generated ⇒ T↓, X↓ (Arrhenius, Eq. 5–7; Fogler/Levenspiel) | implemented |
| rq01/02 | activity_loss_pattern ∧ low feed concentration / low pH → F_Q | Same pattern; feed analysis separates it from F_K | implemented |
| rh01 | heat_removal_deficit ∧ tin, tjin, mj observed ∧ ¬high T_in ∧ ¬high T_j,in ∧ ¬low jacket flow → F_H | Q_gen > Q_removal with UA↓ (Eq. 12–16; Incropera) | implemented |
| rc01/02 | deficit ∧ high T_j,in; or high T_j,in ∧ high T_j → F_C | Warm supply lowers LMTD/ε·ṁc_p(T−T_j,in) (Eq. 15) | implemented |
| rt01 | high T ∧ high T_in → F_T | Feed sensible heat adds to the balance (Eq. 11) | implemented |
| rj01/02 | low P_j ∧ low ṁ_j; or low ṁ_j ∧ high T_j → F_J | ε falls with ṁ_j (Eq. 16); leak lowers P_j (Eq. 34) | implemented |
| rm01–03 | low N_a ∧ low I_m; vibration ∧ low N_a; vibration ∧ low I_m → F_M | I_m ∝ torque·ω (Eq. 26–29) | implemented |
| rs01/02 | low level ∧ high vibration; low level ∧ low pressure residual → F_S | Leak mass balance (Eq. 33), seal rub | implemented |
| rp01 | pressure above P_exp(T) → F_P | Vapour-pressure + ideal-gas inerts (Eq. 30–32) | implemented |
| rr01/02 | feed flow high/low vs load reference → F_R | τ = V/V̇ (Eq. 1–2) | implemented |
| ri01 | |T_r − T_out| above band → F_I | Sensor redundancy; CSTR is well mixed so T_r ≈ T_out (Eq. 35) | implemented |

**Knowledge-acquisition status (honest):** the *physics* basis is textbook (Fogler 2016; Levenspiel 1999; Seborg et al. 2011; Incropera et al. 2011; Stoessel 2008). The *thresholds* are assumptions, **not** taken from a plant or standard. Vibration level is only qualitatively motivated by ISO 20816-1. The 70–90-source literature review required by the brief is **not done** in this package — it must be completed in EndNote and the table above extended with the specific papers each rule relies on.

## 4. Causal model, necessary effects, constraints

`explains/3` (≈45 facts) is the abductive causal model; `must_any/2` (11 facts) gives each fault's necessary effects for consistency checking; `exclusive(fp, fs)` is the one fault-set constraint. Sources: same balances as above; effects were checked against the generator's perturbation table (see limitation L1).

## 5. Maintenance rationale (`src/planner.pl`)

Each record has fault, supporting evidence, action, urgency, safety constraint, verification step. Urgency: critical (F_P, F_S: containment/overpressure), high (F_T, F_H, F_C, F_J, F_R: thermal-excursion risk), medium (F_K, F_M, F_Q, F_I). Actions follow standard practice (inspect/clean/pressure-test/recalibrate). The expert system issues these as its maintenance directives. They follow standard practice but **have not been validated against any plant SOP/HAZOP**; that validation is a prerequisite for deployment on a real plant.

## 6. Traceability matrix (Appendix H)

| Requirement | Predicates | Rules/KB | Test |
|---|---|---|---|
| Observation → symbolic evidence | `meas/3 dev/3 state/3 observed/2` | tol/3 | tests.pl normal, fp |
| Deductive diagnosis | `fired/3 deductive/2 solve/2` | r/3 (18 rules) | tests fp, fh, fk; Exp. 1 |
| Abductive diagnosis | `min_covers/2 hyp_score/3` | explains/3 | tests multi_fp_fj; Exp. 1 |
| Consistency-based diagnosis | `inconsistent/3 consistent_cover/2` | must_any/2, exclusive/2 | test fh (rejects fc, ft, fj, fr) |
| Defaults & exceptions | `feed_conc/2 th_value/2`, NAF in rules | rk01, rh01 | test incomplete_fp |
| Uncertainty / borderline | `borderline/2 tol_scale/1 fault_confidence/3` | Eq. 25–26 | Exp. 4 |
| Sensor-vs-equipment | `dev(tmis)` | ri01, must_any(fi) | tests fi, fi_plus_fk |
| Multiple faults | `hypothesis/3` (≤3 faults) | – | test multi_fp_fj, fi_plus_fk; cat. C |
| Explanation | `explain/1 explain_data/3 sld_trace/2` | rule_text/2 | demos (Test H) |
| Maintenance plan | `plan/3 maint/5` | maint/5 | PlanValidity metric |
| Evaluation / ablation | `evaluate/3 report/2 exp_*` | – | `run_all` |

## 6b. Consultation facility
`src/consult.pl` implements the classic expert-system behaviour of asking for evidence: when competing hypotheses remain, `next_questions/3` returns unobserved variables that are a necessary effect of some but not all hypotheses (from `must_any/2`).

## 7. Limitations (state these in the report)

- **L1 Circularity.** The dataset generator and the KB share the same physics and the same fault-effect table, so high single-fault accuracy is *expected* and does not demonstrate performance on a real plant. The generator also uses a vapour-pressure surrogate identical to the KB's `p_expected/2`.
- **L2** All data are synthetic steady-state values (no dynamics, no start-up/shutdown, no controller interaction beyond the stated manual-hold assumption).
- **L3 Parsimony masking.** A minimal-cover diagnosis can hide a weaker fault whose symptoms a stronger fault also explains (e.g. F_H hidden by F_J).
- **L4** Sensor-fault detection is limited to the T_r/T_out pair; a faulty pressure or flow transmitter is not distinguishable from the physical fault with this sensor set.
- **L5** Hypotheses are limited to 3 simultaneous faults (tractability bound).
