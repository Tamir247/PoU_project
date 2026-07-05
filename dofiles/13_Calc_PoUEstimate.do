* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Prevalence of Undernourishment (PoU) estimate
*
* PROJECT:			Food Analysis
*
* DATE: 			Jul 2026
*
* DESCRIPTION:  	Approximate PoU using this pipeline's own DEC/MDER outputs
*					and the handbook's CV/skewness derivation (Ch.2), so there
*					is a defensible, documented number available without
*					running ADePT-FSM itself.
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* IMPORTANT CAVEATS -- read before quoting this number to anyone:
*
* 1) This is NOT the official ADePT-FSM output. ADePT-FSM is the actual
*    software FAO uses to fit the final distribution and compute PoU; this
*    pipeline only prepares its inputs (see CLAUDE.md). This file is a
*    transparent, from-first-principles approximation using the exact
*    handbook formulas, so the methodology is fully inspectable -- it is not
*    a substitute for actually running ADePT.
*
* 2) ADePT-FSM's current default is the SKEW-NORMAL distribution (Azzalini
*    1980), which better captures asymmetry than the older log-normal model.
*    This file uses LOG-NORMAL -- the handbook's own documented "prior
*    methodology" (still a valid, explicitly-supported ADePT option, see
*    Ch.2 "the user has been left with the option of calculating the
*    distribution according to the old or improved methodology") -- because
*    it has a simple closed-form CDF (Stata's normal()) that can be verified
*    by hand, whereas skew-normal has no closed form and would require
*    machinery that can't be independently checked here. Expect the true
*    ADePT (skew-normal) PoU to differ from this number.
*
* 3) The CV derivation below only has 2 of ADePT's 3 CV inputs done properly:
*      - Between-decile CV (Step 1): now buildable, using
*        05_Import_IncomeDeciles.do's deciles -- this was NOT possible
*        against the de-identified spread data (no consumption.dta / income
*        ranking available there at all).
*      - Within-household CV (Step 2): already computed as "cv_r" in
*        Requirement_admin.dta (11_Calc_DietaryEnergyRequirement.do).
*    Both are combined per Step 3 below. Step 4 (compare vs. the empirical/
*    raw CV, take the lower) is also implemented.
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

clear all
set more off

********************************************************************
*** Step 1: CV of DEC tabulated by income decile (handbook Ch.2,
*** "Estimation of the CV of DEC Tabulated by Income")
***   sigma(x/v)^2 = sum_j [ (pop_j/pop) * (x_j - mu)^2 ]
***   where x_j = population-weighted mean DEC of decile j,
***   pop_j = population in decile j, pop = total population,
***   mu = overall population-weighted mean DEC.
********************************************************************

use "$data_out/DEC_${survey_year}", clear
merge 1:1 identif using "$data_temp/income_deciles_${survey_year}", keepusing(decile) nogen keep(match)
	* nogen keep(match): households with no decile (shouldn't happen -- both
	* files cover the same 15,513 households) are silently dropped rather
	* than crashing; check below confirms this doesn't actually lose anyone.
	count
	assert r(N)==15513 // guards against a silent household-loss regression here

gen pop_hh = hhweight*hhsize_food

* overall population-weighted mean DEC (mu)
summ PC_tot_cal [aw=pop_hh]
scalar mu_dec = r(mean)
scalar pop_total = r(sum_w)

* decile-level population-weighted means (x_j) and decile population (pop_j)
preserve
	collapse (mean) PC_tot_cal [aw=pop_hh], by(decile)
	rename PC_tot_cal decile_mean
	tempfile decile_means
	save `decile_means'
restore
preserve
	collapse (sum) pop_hh, by(decile)
	rename pop_hh pop_decile
	merge 1:1 decile using `decile_means', nogen
	gen sq_dev = (decile_mean - mu_dec)^2
	gen weight_share = pop_decile/pop_total
	gen contrib = weight_share*sq_dev
	summ contrib
	scalar sigma2_xv = r(sum)
	tempfile decile_summary
	save `decile_summary'
restore

scalar sigma_xv = sqrt(sigma2_xv)
scalar cv_xv = sigma_xv/mu_dec

di as result "=== Step 1: Between-decile CV of DEC ==="
di "mu (national mean DEC) = " mu_dec
di "sigma(x/v) = " sigma_xv
di "CV(x/v) = " cv_xv

********************************************************************
*** Step 2: CV of DEC due to physiological/requirement factors
*** (handbook Ch.2 "Estimation of CV of DEC Because of Other Factors").
*** Already computed as "cv_r" in 11_Calc_DietaryEnergyRequirement.do's
*** national output -- reuse it directly rather than recompute.
********************************************************************

preserve
	use "$data_out/Requirement_admin", clear
	summ cv_r if urban==0 & region==0
	scalar cv_xr = r(mean)
restore

di as result "=== Step 2: Within CV (body weight / PAL / measurement error) ==="
di "CV(x/r) = " cv_xr

********************************************************************
*** Step 3: Aggregation -- CV(x) = sqrt( CV(x/v)^2 + CV(x/r)^2 )
********************************************************************

scalar cv_combined = sqrt(cv_xv^2 + cv_xr^2)
di as result "=== Step 3: Combined CV ==="
di "CV(x) = " cv_combined

********************************************************************
*** Step 4: Selection -- ADePT-FSM uses whichever is LOWER: the combined
*** CV above, or the CV from the raw empirical distribution of DEC.
********************************************************************

summ PC_tot_cal [aw=pop_hh]
scalar cv_empirical = r(sd)/r(mean)

di as result "=== Step 4: CV selection ==="
di "CV empirical (raw household DEC distribution) = " cv_empirical
di "CV combined (Steps 1-3)                       = " cv_combined
if cv_combined < cv_empirical {
	scalar cv_final = cv_combined
	di "Selected: combined CV (lower)"
}
else {
	scalar cv_final = cv_empirical
	di "Selected: empirical CV (lower)"
}

********************************************************************
*** Skewness (handbook Ch.2, log-normal case): skewness = (CV^2+3)*CV
*** -- see caveat (2) at the top of this file re: skew-normal vs log-normal.
********************************************************************

scalar skewness_final = (cv_final^2 + 3)*cv_final
di as result "Implied skewness (log-normal): " skewness_final

********************************************************************
*** Final PoU: log-normal distribution with mean = mu_dec, CV = cv_final.
*** sigma2 = ln(1+CV^2); mu_ln = ln(mean) - sigma2/2 (so that the log-normal's
*** OWN mean equals mu_dec, not its median). PoU = P(DEC < MDER) = Phi(z).
********************************************************************

use "$data_out/Requirement_admin", clear
summ MDER if urban==0 & region==0
scalar mder_nat = r(mean)

scalar sigma2_ln = ln(1 + cv_final^2)
scalar mu_ln     = ln(mu_dec) - sigma2_ln/2
scalar sigma_ln  = sqrt(sigma2_ln)
scalar z_final   = (ln(mder_nat) - mu_ln)/sigma_ln
scalar PoU_final = normal(z_final)

di as result "===================================================="
di as result "FINAL (approximate, log-normal, see caveats above)"
di as result "===================================================="
di "National mean DEC : " mu_dec " kcal/person/day"
di "National MDER     : " mder_nat " kcal/person/day"
di "CV used           : " cv_final
di "Skewness (implied): " skewness_final
di "PoU = " PoU_final*100 "%"

* Save a tiny summary file for reference/reporting.
clear
set obs 1
gen mean_dec = mu_dec
gen mder = mder_nat
gen cv_between_decile = cv_xv
gen cv_within = cv_xr
gen cv_combined = cv_combined
gen cv_empirical = cv_empirical
gen cv_used = cv_final
gen skewness_lognormal = skewness_final
gen PoU_pct = PoU_final*100
save "$data_out/PoU_estimate_${survey_year}", replace
