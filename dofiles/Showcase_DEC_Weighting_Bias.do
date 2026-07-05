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
merge 1:1 identif using "$base/output/process/Requirement_HHLevel", keepusing(MDER) nogen
gen mder_pc = MDER/hhsize_food
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

di as result "===================================================================="
di as result "4) DOES HOUSEHOLD SIZE ACTUALLY CROSS THE LINE? DEC vs. EACH"
di as result "   BUCKET'S OWN PER-CAPITA MDER (not just the national average)"
di as result "===================================================================="
di as text "Larger households often have a different age/sex mix (more children,"
di as text "for instance), so their MINIMUM requirement per person isn't the same"
di as text "flat 1,786.6 either -- this compares each bucket's DEC against ITS OWN"
di as text "average per-capita MDER, a fairer test than one flat threshold."
di ""

gen below_mder = PC_tot_cal < mder_pc
gen pop_hh2 = hhweight*hhsize_food
egen total_pop2 = total(pop_hh2)
gen pop_share = 100*pop_hh2/total_pop2

di as text "  Household   DEC    Per-capita   DEC minus   % of households   % of national"
di as text "  size        kcal   MDER kcal    MDER kcal   below OWN MDER    population"
di as text "  ----------  -----  ----------   ---------   ---------------   -------------"
forvalues b = 1/6 {
	local lbl : label hhsize_bucket_lbl `b'
	quietly summ PC_tot_cal [aw=hhweight] if hhsize_bucket==`b'
	local dec = r(mean)
	quietly summ mder_pc [aw=hhweight] if hhsize_bucket==`b'
	local mder = r(mean)
	quietly summ below_mder [aw=hhweight] if hhsize_bucket==`b'
	local pct_below = 100*r(mean)
	quietly summ pop_share if hhsize_bucket==`b', meanonly
	local pshare = r(sum)
	local gap = `dec'-`mder'
	local sign = cond(`gap'>=0, "+", "")
	di as text %-12s "`lbl'" %6.0f `dec' "  " %9.0f `mder' "  " "`sign'" %8.0f `gap' "        " %5.1f `pct_below' "%           " %5.1f `pshare' "%"
}

di ""
di as result "Takeaway: the DEC-minus-MDER gap flips from positive to negative"
di as result "between 3 and 4 household members, and keeps widening in the"
di as result "negative direction as size grows. Households of 4+ people are"
di as result "~67% of the national population, and their AVERAGE per-capita"
di as result "DEC sits below their own AVERAGE per-capita minimum requirement --"
di as result "this is not just a weighting artifact, it's a real, monotonic"
di as result "gradient by household size that a boss/reviewer can sanity-check"
di as result "at a glance."
