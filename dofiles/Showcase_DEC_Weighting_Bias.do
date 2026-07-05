* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Showcase: household- vs. population-weighted national DEC
*
* PROJECT:			Food Analysis
*
* DATE: 			Jul 2026
*
* DESCRIPTION:  	Standalone demonstration file -- NOT part of the pipeline
*					(not called from 00 Master.do). Run this manually, after
*					00 Master.do has produced output/process/DEC_2024.dta, to
*					show the difference between the pipeline's long-standing
*					"national mean DEC" diagnostic (household-weighted) and
*					the population-weighted figure the handbook's own CV
*					formula requires (Ch.2, "pop = sum(hh_size*hh_wgt)").
*
* NOT A FIX: this file only demonstrates the discrepancy for discussion --
* it does not change any pipeline output. See CLAUDE.md for the full writeup.
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

clear all
set more off
global base "C:\Users\Admin\Desktop\PoU"

use "$base/output/process/DEC_2024", clear
di "N households = " _N

di as result "===================================================================="
di as result "1) THE TWO WEIGHTINGS, SIDE BY SIDE"
di as result "===================================================================="
di ""
di as text "(a) Household-weighted -- every household counts once, regardless of"
di as text "    size. This is the pipeline's existing diagnostic"
di as text "    (12_Calc_DietaryEnergyConsumption.do, the [iw=hhweight] summ):"
summ PC_tot_cal [aw=hhweight]
scalar mean_hh = r(mean)

di ""
di as text "(b) Population-weighted -- weighted by how many people actually"
di as text "    experience each household's per-capita DEC (hhweight*hhsize_food)."
di as text "    This is what the FAO/WB handbook (Ch.2) requires for a national"
di as text "    per-person average, and what its CV-of-DEC-by-income-decile"
di as text "    formula is explicitly built on (pop_j = hh_size*hh_wgt)."
gen pop_hh = hhweight*hhsize_food
summ PC_tot_cal [aw=pop_hh]
scalar mean_pop = r(mean)

di ""
di as result "Household-weighted mean:   " %6.1f mean_hh " kcal/person/day"
di as result "Population-weighted mean:  " %6.1f mean_pop " kcal/person/day"
di as result "Difference: " %4.1f (mean_hh-mean_pop) " kcal/person/day (" %4.1f 100*(mean_hh-mean_pop)/mean_hh "% lower once correctly weighted)"

di as result "===================================================================="
di as result "2) WHY THEY DIFFER: household size is strongly, negatively"
di as result "   correlated with per-capita DEC"
di as result "===================================================================="
corr PC_tot_cal hhsize_food [aw=hhweight]

di ""
di as text "Mean per-capita DEC by household (food-partaker) size:"
gen hhsize_bucket = hhsize_food
recode hhsize_bucket (6/max=6)
label define hhsize_bucket_lbl 1 "1 person" 2 "2 people" 3 "3 people" 4 "4 people" 5 "5 people" 6 "6+ people"
label values hhsize_bucket hhsize_bucket_lbl
tabstat PC_tot_cal [aw=hhweight], by(hhsize_bucket) stat(mean n) format(%6.0f)

di as text "Interpretation: a 1-person household still cooks a whole pot of rice"
di as text "or bakes a whole loaf -- fixed-cost effects inflate its per-person"
di as text "figure. Household-weighting (each household = 1 vote) therefore"
di as text "over-represents small households relative to their true population"
di as text "share, pulling the 'national average' up."

di as result "===================================================================="
di as result "3) WHY IT MATTERS FOR THE PoU READ"
di as result "===================================================================="
preserve
	use "$base/output/process/Requirement_admin", clear
	summ MDER if urban==0 & region==0
	scalar mder_nat = r(mean)
restore

di as text "National MDER (minimum requirement): " %6.1f mder_nat " kcal/person/day"
di ""
di as text "Margin above MDER, household-weighted DEC:  " %5.1f (mean_hh-mder_nat) " kcal (" %4.1f 100*mean_hh/mder_nat "% of MDER)"
di as text "Margin above MDER, population-weighted DEC: " %5.1f (mean_pop-mder_nat) " kcal (" %4.1f 100*mean_pop/mder_nat "% of MDER)"
di ""
di as text "The population-weighted margin is much thinner -- this is the"
di as text "number that should drive any PoU discussion, since PoU is a"
di as text "population-level (not household-level) prevalence statistic."
