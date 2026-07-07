* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Showcase: adult-equivalent scales vs. raw headcount (2018)
*
* PROJECT:			Food Analysis
*
* DATE: 			Jul 2026
*
* DESCRIPTION:  	Standalone diagnostic -- NOT part of the 2018 validation
*					pipeline (not called from dofiles/2018/00_Master_2018.do).
*					Follow-up to Showcase_DEC_Weighting_Bias.do's finding that
*					per-capita DEC falls sharply as household size rises.
*					Tests how much of that pattern survives once household
*					composition (adults vs. children) is accounted for, using
*					four candidate per-person denominators:
*					  - hhsize        raw headcount (the ADePT-consistent
*					                  denominator -- see note below)
*					  - ae_boss       Undral-suggested formula, 0.3+0.7*adult
*					                  +0.3*child
*					  - ae_existing   06_Build_EquivalenceScales.do's own
*					                  (already built, never wired anywhere)
*					                  aesize_oecd1 formula, 0.3+0.7*adult
*					                  +0.5*child -- algebraically the classic
*					                  "old OECD" scale (1 + 0.7 per additional
*					                  adult + 0.5 per child)
*					  - aesize_fao    same file's calorie-need age/sex scale,
*					                  built from actual MOH calorie
*					                  recommendations by age-sex bin, divided
*					                  by 2400 (a reference adult male need)
*					For each, reports THREE weighting conventions -- plain
*					unweighted mean, household-weighted mean ([aw=hhweight],
*					every household counts once), and population-weighted
*					mean ([aw=hhweight*hhsize], every PERSON counts once) --
*					then compares all twelve resulting figures against
*					ADePT-FSM's actual 2018 output (DEC = 2,461.0
*					kcal/person/day, from HH data.xlsx).
*
* IMPORTANT SCOPE NOTE: ADePT-FSM's own technical manual confirms it divides
* by raw household size/food-partakers, NOT an adult-equivalence scale, when
* computing DEC (see CLAUDE.md). Of the twelve figures below, only the
* "hhsize" row's population-weighted column is actually on an ADePT-
* comparable basis -- the ae_boss/ae_existing/aesize_fao rows are shown for
* DIAGNOSTIC purposes (how much of the household-size gradient is
* composition vs. genuine economies of scale), not as alternative candidates
* for "the" DEC figure.
*
* NOT A FIX: this file only demonstrates/compares -- it does not change
* dofiles/2018/01_Calc_DEC_2018.do's output.
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

clear all
set more off
global base "C:\Users\Admin\Desktop\PoU"

* ============================================================================
* 1) Build adult-equivalent scales from the 2018 individual roster
* ============================================================================
use "$base/input/2018/02_indiv.dta", clear
	gen age = q0105y
	gen female = q0103==2
	gen adult = age>=15
	gen child = age<15

	* FAO/MOH calorie-based age-sex bins -- copied verbatim from
	* 06_Build_EquivalenceScales.do (same age cuts, same 0-6mo carve-out,
	* same calorie coefficient matrix) so the 2018 and 2024 aesize_fao
	* scales are built identically and comparable to one another.
	egen agecat=cut(age), at(0 1 4 7 11 15 18 30 60 120) icode
		replace agecat=agecat+1
		replace agecat=0 if agecat==1 & q0105m<6

	gen agecat_m=agecat if female==0
	gen agecat_f=agecat if female==1

	tab agecat_m, gen(agecat_m)
	tab agecat_f, gen(agecat_f)

	collapse (sum) adult child agecat_m* agecat_f*, by(identif)

	mat define A=[720, 820, 1060, 1470, 1820, 2500, 2700, 2400, 2380, 1920 \ 660, 750, 980, 1330, 1650, 2170, 2280, 1990, 1850, 1680]
	gen double cal=0
	forval c=1/10 {
		replace cal=cal+A[1,`c']*agecat_m`c' + A[2,`c']*agecat_f`c'
	}
	gen aesize_fao=cal/2400

	gen ae_boss     = 0.3 + 0.7*adult + 0.3*child
	gen ae_existing = 0.3 + 0.7*adult + 0.5*child

	* NOTE: unlike 2024's 02_indiv.dta, 2018's has no q0113-style "is this a
	* current household member" flag (documented gap, see CLAUDE.md "Legacy
	* 2018 pipeline"). Roster headcount (adult+child) exceeds hhsize for
	* ~10% of households, usually by just 1 person -- plausibly a visiting
	* relative counted on the roster but not in the official household
	* size. Left as-is (not forced to reconcile) since this is a diagnostic,
	* not the official pipeline; the mismatch is too small and too rare to
	* matter for the comparison below.

	keep identif adult child ae_boss ae_existing aesize_fao
	tempfile aescales
	save `aescales'

* ============================================================================
* 2) Merge onto 2018 DEC and build the weight variables
* ============================================================================
use "$base/output/process/2018/DEC_2018", clear
	merge 1:1 identif using `aescales'
	tab _merge
	keep if _merge==3
	drop _merge

	di as text "N households in this comparison = " _N

	gen pop_w = hhweight*hhsize

* ============================================================================
* 3) For each denominator, report unweighted / hh-weighted / pop-weighted mean
* ============================================================================
local denomlist hhsize ae_boss ae_existing aesize_fao
local denomlabel1 "Raw headcount (hhsize)"
local denomlabel2 "Boss's formula (0.3+0.7A+0.3C)"
local denomlabel3 "Existing project formula (0.3+0.7A+0.5C)"
local denomlabel4 "FAO/MOH calorie-need scale"

mat results = J(4,3,.)
local r=1
foreach d of local denomlist {
	gen PC_`d' = HH_tot_cal/`d'

	quietly summ PC_`d'
	mat results[`r',1] = r(mean)

	quietly summ PC_`d' [aw=hhweight]
	mat results[`r',2] = r(mean)

	quietly summ PC_`d' [aw=pop_w]
	mat results[`r',3] = r(mean)

	local r = `r'+1
}

di as result "===================================================================="
di as result "2018 -- per-person DEC under each denominator x weighting scheme"
di as result "===================================================================="
di as text "                                            unweighted   hh-weighted   pop-weighted"
forval r=1/4 {
	di as text %-43s "`denomlabel`r''" %11.1f (results[`r',1]) %13.1f (results[`r',2]) %14.1f (results[`r',3])
}

di ""
di as result "===================================================================="
di as result "Comparison against ADePT-FSM's actual 2018 output"
di as result "===================================================================="
di as text "ADePT-FSM reference DEC (2018): 2,461.0 kcal/person/day"
di as text "MDER reference (2018):          1,848.0 kcal/person/day"
di as text "ADER reference (2018):          2,348.0 kcal/person/day"
di ""
di as text "ADePT's own technical manual confirms it uses population weights"
di as text "(hh_wgt*hh_size) and RAW household size/food-partakers -- not an"
di as text "adult-equivalence scale -- as the DEC denominator. So only the"
di as text "'Raw headcount' row's pop-weighted column is actually on an"
di as text "ADePT-comparable basis; the other three rows are diagnostic only."
di ""

forval r=1/4 {
	local gap_pw = results[`r',3]-2461
	local pct_pw = 100*results[`r',3]/2461
	di as text "`denomlabel`r''"
	di as text "   unweighted:   " %7.1f (results[`r',1]) " kcal  (diff vs ADePT: " %7.1f (results[`r',1]-2461) ")"
	di as text "   hh-weighted:  " %7.1f (results[`r',2]) " kcal  (diff vs ADePT: " %7.1f (results[`r',2]-2461) ")"
	di as text "   pop-weighted: " %7.1f (results[`r',3]) " kcal  (diff vs ADePT: " %7.1f `gap_pw' ", " %5.1f `pct_pw' "% of ADePT)"
	di ""
}

di as result "===================================================================="
di as result "Correlation check: does each denominator flatten the hhsize gradient?"
di as result "===================================================================="
foreach d of local denomlist {
	quietly corr hhsize PC_`d' [aw=pop_w]
	di as text %-30s "`d'" "  pop-weighted corr(hhsize, PC_`d') = " %7.4f r(rho)
}
