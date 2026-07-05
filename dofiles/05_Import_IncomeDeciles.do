* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Import income deciles
*
* PROJECT:			Food Analysis
*
* DATE: 			Jul 2026
*
* DESCRIPTION:  	Build the population-weighted income-decile variable used
*					(a) as an outlier-imputation grouping level in
*					08_Build_FoodConsumption.do and (b) for the income-decile-
*					tabulated "Between-CV" component of the PoU distribution
*					fit in 13_Calc_PoUEstimate.do.
*
* SIMPLE PIPELINE:
*   1) Read consumption.dta (household real per-adult-equivalent expenditure).
*   2) Rank households into population-weighted deciles.
*   3) Save identif + decile (+ totex_rpae) for downstream merges.
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

* PIPELINE ADDITION (2026-07-06): this file only works because "input/2024"
* now points at the FULL (non-de-identified) 2024 release, not the "spread"
* release. The spread release's "identif" is a one-way anonymizing hash with
* no crosswalk back to the real household IDs "consumption.dta" is keyed on
* (confirmed: zero overlap when matching the two releases' basicvars.dta by
* identif) -- so this file cannot run, and this whole income-decile feature
* cannot exist, against the spread data. See CLAUDE.md "Data variants" for
* the full folder-swap explanation. "consumption.dta" is an official NSO
* welfare/consumption product (see 03 Household.do's caveats in CLAUDE.md for
* the evidence), not an ad hoc external file.
*
* NOTE: consumption.dta's OWN "identif" column is a different ID scheme that
* does NOT match this pipeline's "identif" (basicvars/02_indiv/etc). The
* actual shared household key is consumption.dta's "household_id" column
* (verified: matches basicvars' identif for all 15,513 households). This
* mirrors exactly what the original (pre-reorg) disabled code in
* "08_Build_FoodConsumption.do" already knew and handled the same way.

	use "$data_raw/consumption", clear
	rename identif hses_id_consumption_own_id
	rename household_id identif

	*** Population-weighted decile of real per-adult-equivalent total
	*** expenditure -- same formula as the original (pre-spread-adaptation)
	*** code: aw=hhweight*hhsize ranks households by population share, not
	*** household count (handbook Ch.2 "CV of DEC Tabulated by Income").
	xtile decile = totex_rpae [aw=hhweight*hhsize], nq(10)

	keep identif decile totex_rpae
	label var decile "Population-weighted income decile (1=poorest, 10=richest)"
	sort identif
	save "$data_temp/income_deciles_${survey_year}", replace
