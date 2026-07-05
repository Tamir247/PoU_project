//﻿ ===========================================================================//
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Master do-file 
*
* PROJECT:			Food Analysis
*
* PROGRAMMER:		Undral Lkhagva (LK)
*
* DATE: 			Jan 2026
*
* DESCRIPTION:  	Master do-file

*
* SIMPLE PIPELINE:
*   1) Define local user paths and global folders.
*   2) Initialize run environment (clear memory, close logs).
*   3) Execute each module in sequence for the 2024 workflow.
*   4) Save processed outputs for analysis and reporting.
*
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *


	clear all
	set more off
	cap log close
	mat drop _all
	scalar drop _all
	
	global base "C:\Users\Admin\Desktop\PoU"
	log using "$base\main.log", replace
	
	
	// ЧУХАЛ ТОГТМОЛУУД
	global survey_year 2024

	** Mongolia demographic constants used in dietary energy requirement
	** (MDER/ADER/XDER) formulas -- FAO handbook Ch.2, u5mr/cbr terms. These
	** are survey-year-specific empirical statistics (not derived from the
	** HSES data itself), so -- same reasoning as "survey_year" above --
	** they're globals here instead of literals buried in a calculation file.
	** Update both when survey_year changes to a year with different NSO figures.
	global u5mr 15.0    // Under-5 mortality rate, 2024, NSO: https://www.1212.mn/mn/statcate/table-view/Education,%20health/Births%2C%20deaths/DT_NSO_2100_041V3.px
	global cbr  0.0169  // Crude birth ratio, 2024, NSO: https://www.1212.mn/mn/statcate/table-view/Education,%20health/Births%2C%20deaths/DT_NSO_0300_029V1.px

	
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*
*	0. Set paths
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
	
			
		global dbase "$base/input"
		global data_out		"$base/output/process"
		global data_temp    "$base/temp/analysis"
		global output		"$base/output/analysis"
		global checks	    "$base/temp/check"
		global dofile		"$base/dofiles"  // folder that holds all do-files
		
		global data_raw	"$dbase/${survey_year}"
		
		
		

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
*	1. Set globals
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *


	** General

	** Indirect DEC / unit-value method (handbook Ch.2, 6-step method, step 5):
	** grouping variable used to compute median unit values for items that
	** lack a directly observed quantity (currently: Food-Away-From-Home in
	** "12_Calc_DietaryEnergyConsumption.do"). Must be a variable that exists
	** on basicvars.dta. For now a single household-level var (region) is
	** used; this can be changed later (e.g. to newaimag, or a combined
	** region x urban x income quintile group built upstream) without
	** editing "12_Calc_DietaryEnergyConsumption.do" itself.
	global indirect_grp_var "region"


* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
*	2. Run do-files  (2024 analysis – dependency order)
*
* PIPELINE REORG (2026-07-05, extended 2026-07-06): reorganized into three
* stages so raw "input/" access stays confined to a clearly-named "Import"
* stage (01-05) while everything computed from survey rosters lives in
* "Build" (06-10, still pre-calculation) and "Calc" (11-13, MDER/ADER/XDER +
* DEC + PoU -- the only files consuming Build/Import outputs, never raw
* input directly). Old do-files were moved via "git mv" to their new names --
* full history is preserved in git, nothing was deleted. See CLAUDE.md for
* the full file-by-file mapping.
*
* DATA SOURCE CHANGE (2026-07-06): "input/2024" now holds the FULL (non-
* de-identified) 2024 release; the de-identified "spread" release that the
* pipeline was adapted for on 2026-07-03 has moved to "input/2024 spread".
* Reason: the spread release's household IDs are a one-way anonymizing hash
* with no crosswalk back to the real IDs that consumption.dta (needed for
* income deciles, see step 5 below) is keyed on -- confirmed zero overlap.
* Folder swap, not a code change: "$data_raw" = "$dbase/${survey_year}" is
* unchanged, it just now resolves to the full data. See CLAUDE.md "Data
* variants" for the full explanation. All the "SPREAD-DATA ADAPTATION"
* guards throughout the pipeline are harmless no-ops against full data
* (they're "capture"-guarded or check column existence), EXCEPT the
* cluster-level price-imputation rung and income-decile outlier grouping in
* "08_Build_FoodConsumption.do", which are now explicitly RE-ENABLED (see
* that file's "REVERTED (2026-07-06)" comments) since their inputs exist
* again. "03 Household.do" stays disabled regardless -- poverty is out of
* scope independent of data availability.
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	** -------------------- Import stage --------------------
	** Step 1: basicvars passthrough (every other file merges from this
	** instead of reading "$data_raw/basicvars" directly)
	** Output: temp/analysis/basicvars_2024.dta
	di as text ">>> [1/8] Import: basicvars"
	do "$dofile/01_Import_BasicVars.do"

	** Step 2: Reference lookup tables (no data dependencies)
	** Outputs: input/unit_scale.dta, output/process/index.dta
	di as text ">>> [2/8] Import: unit scale, price deflators"
	quietly do "$dofile/02_Import_UnitScale.do"        // import unit-scale Excel  → input/unit_scale.dta
	do "$dofile/03_Import_PriceDeflators.do"           // monthly CPI & food-CPI   → output/process/index.dta

	** Step 3: age_class + height + BMI/PAL/weight-gain + WHO SD-for-height,
	** all keyed off age_class (or gender+height) -- see that file's header
	** comment for why these are now combined here instead of split between
	** here and the old "05 MDER_ADER_XDER.do"
	** Output: output/process/AgeClassReference_2024.dta
	di as text ">>> [3/8] Import: age-class reference (height, BMI/PAL, SD)"
	do "$dofile/04_Import_AgeClassReference.do"

	** Step 4: Income deciles (needs consumption.dta -- only available/
	** correctly identif-matched against the full data, see note above)
	** Output: temp/analysis/income_deciles_2024.dta
	di as text ">>> [4/8] Import: income deciles"
	do "$dofile/05_Import_IncomeDeciles.do"

	** -------------------- Build stage --------------------
	** Step 5: Household composition (depends on 01_hhold + 02_indiv)
	** Outputs: temp/analysis/equivalence_scales2024.dta, temp/analysis/HH_size_food.dta
	di as text ">>> [5/8] Build: household composition"
	do "$dofile/06_Build_EquivalenceScales.do"  // FAO & OECD-1 adult-equivalent sizes
	do "$dofile/07_Build_HHFoodPartakers.do"    // effective food partaker count per HH

	** Step 6: Food consumption dataset
	** Outputs: output/process/food_2024.dta + food_2024_Noout.dta
	di as text ">>> [6/8] Build: food consumption"
	do "$dofile/08_Build_FoodConsumption.do"    // harmonised intake, price imputation, outlier treatment

	** Step 7: Individual, household, and nutrient conversion table files
	** Outputs: indivdual_2024.dta, Country_nct_2024_with_Foodout.dta
	di as text ">>> [7/8] Build: individual roster, NCT"
	do "$dofile/09_Build_IndividualRoster.do"       // demographics, labour market, household-head vars
	do "$dofile/10_Build_NutrientConversionTable.do" // national nutrient conversion table

	* SPREAD-DATA ADAPTATION (2026-07-03): "03 Household.do" (expenditure,
	* income, poverty status) is disabled regardless of which data folder is
	* active -- poverty analysis is out of scope (see CLAUDE.md), independent
	* of whether its inputs happen to exist. Its output (household_2024.dta)
	* isn't consumed by the Calc stage, so disabling it has no effect on the
	* DEC/MDER/PoU calculation. Left un-renamed (out of scope, not part of
	* this reorg). Re-enable only if poverty work is ever explicitly in scope:
	*   do "$dofile/03 Household.do"           // expenditure, income, poverty status

	** -------------------- Calc stage --------------------
	** Step 8: Dietary energy requirements, consumption, and PoU estimate
	** Outputs: Requirement_HHLevel.dta, Requirement_admin.dta, DEC_2024.dta,
	** PoU_estimate_2024.dta
	di as text ">>> [8/8] Calc: DER, DEC, PoU"
	do "$dofile/11_Calc_DietaryEnergyRequirement.do"  // MDER / ADER / XDER + within-CV component
	do "$dofile/12_Calc_DietaryEnergyConsumption.do"  // DEC: calorie intake per capita per day
	do "$dofile/13_Calc_PoUEstimate.do"               // approximate PoU (see that file's caveats)

log close _all
exit




