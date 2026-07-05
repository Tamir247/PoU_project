* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			2018 DEC calculation (validation exercise)
*
* PROJECT:			Food Analysis
*
* DATE: 			Jul 2026
*
* DESCRIPTION:  	Computes Dietary Energy Consumption (DEC) for the 2018
*					HSES round, reusing this project's already-verified
*					2024 Atwater-formula/unit-conversion logic, and reports
*					it under BOTH household-weighting and (the handbook-
*					correct) population-weighting -- see CLAUDE.md for why
*					these differ. This is a proper, saved replacement for
*					what used to be a throwaway scratchpad script.
*
* Reused reference tables (confirmed cross-year-compatible earlier this
* project): input/unit_scale.dta (2018 and 2024 gram-conversion factors are
* near-identical, per input/Unit_scale.xlsx's "units" sheet -- only item
* 10114/Pizza differs, and it's excluded from calorie calc in both years
* anyway) and output/process/Country_nct_2024_with_Foodout.dta (same item-
* code scheme both years).
*
* NOT INCLUDED (see 00_Master_2018.do header for why): food-away-from-home,
* price deflation, MDER/ADER/XDER, income-decile CV / PoU estimate.
*
* Reference: ADePT-FSM's actual 2018 output (HH data.xlsx) --
*   DEC=2,461, MDER=1,848, ADER=2,348 kcal/person/day
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

use "$data_temp_2018/tempfood.dta", clear

di as result "=== Flag distribution before any exclusion ==="
tab1 flag1 flagP flagQ out

* Apply the exclusions foodsetup.do's own comments say SHOULD happen but whose
* code was left disabled (flagQ alone -- already fixed earlier this project,
* see CLAUDE.md), plus the residual "out" categories where unit values/
* quantities don't apply at all.
drop if flagQ==1
drop if out==1

* tempfood.dta is at identif/itemcode/TENTH level (three 10-day sub-periods
* per month, 2018's collection design) -- collapsing (mean) across tenths
* gives a single representative daily quantity per item per household,
* the 2018 equivalent of 2024's 7-day-diary daily average.
collapse (mean) qtx (first) hhsize hhweight, by(identif itemcode)

rename itemcode item
merge m:1 item using "$dbase/unit_scale.dta", keepusing(unit) nogen keep(match)
gen daily_qty_gr = qtx*unit

merge m:1 item using "$base/output/process/Country_nct_2024_with_Foodout.dta", keepusing(fd_pro fd_fat fd_car fd_fib) nogen keep(match)

* Same Atwater formula as the 2024 pipeline's 12_Calc_DietaryEnergyConsumption.do
gen kcal = 4*fd_pro + 4*fd_car + 9*fd_fat + 2*fd_fib
gen hh_cal = daily_qty_gr/100*kcal
* No "hhsize_food" equivalent exists for 2018 (no q0113/q0112a) -- raw
* "hhsize" is the per-capita denominator here, a known, documented
* simplification (see 00_Master_2018.do header).
gen pc_cal = hh_cal/hhsize

egen HH_tot_cal = total(hh_cal), by(identif)
egen PC_tot_cal = total(pc_cal), by(identif)

collapse (firstnm) HH_tot_cal PC_tot_cal hhsize hhweight, by(identif)

label var HH_tot_cal "HH total dietary energy consumption (kcal/day)"
label var PC_tot_cal "Per-capita dietary energy consumption (kcal/day)"

save "$data_out_2018/DEC_2018", replace

* ============================================================================
* Reporting: household-weighted (original validation figure) vs.
* population-weighted (the handbook-correct figure, added 2026-07-06 -- see
* CLAUDE.md "2026-07-06 additions" for the full household- vs. population-
* weighting explanation from the 2024 pipeline, same logic applies here).
* ============================================================================

di as result "===================================================================="
di as result "2018 DEC -- household-weighted (matches the original validation run)"
di as result "===================================================================="
summ HH_tot_cal PC_tot_cal [aw=hhweight]
scalar mean_hh_2018 = r(mean)

di as result "===================================================================="
di as result "2018 DEC -- population-weighted (hhweight*hhsize; the handbook-"
di as result "correct figure for a per-PERSON national average)"
di as result "===================================================================="
gen pop_hh = hhweight*hhsize
summ PC_tot_cal [aw=pop_hh]
scalar mean_pop_2018 = r(mean)

di as result "===================================================================="
di as result "SUMMARY"
di as result "===================================================================="
di as text "Household-weighted DEC:   " %6.1f mean_hh_2018 " kcal/person/day"
di as text "Population-weighted DEC:  " %6.1f mean_pop_2018 " kcal/person/day"
di as text "ADePT-FSM 2018 reference: 2,461.0 kcal/person/day (household-weighted"
di as text "  basis presumed, same as this pipeline's own long-standing 2024"
di as text "  diagnostic convention -- not independently confirmed for the 2018"
di as text "  ADePT run specifically)"
di ""
di as text "Same caveats as the original validation exercise apply to BOTH figures"
di as text "above: food-away-from-home not processed, no price-deflation/indirect-"
di as text "method calories for zero-quantity items, no partaker-adjusted size."
