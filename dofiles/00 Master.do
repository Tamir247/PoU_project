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
	** "11_Calc_DietaryEnergyConsumption.do"). Must be a variable that exists
	** on basicvars.dta. For now a single household-level var (region) is
	** used; this can be changed later (e.g. to newaimag, or a combined
	** region x urban x income quintile group built upstream) without
	** editing "11_Calc_DietaryEnergyConsumption.do" itself.
	global indirect_grp_var "region"


* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
*	2. Run do-files  (2024 analysis – dependency order)
*
* PIPELINE REORG (2026-07-05): renamed/reorganized into two stages so raw
* "input/" access stays confined to a clearly-named "Import" stage (01-04)
* and everything computed from survey rosters lives in "Build" (05-09,
* still pre-calculation) and "Calc" (10-11, MDER/ADER/XDER + DEC -- the
* only files consuming Build/Import outputs, never raw input directly).
* Old do-files (0 Import Unit.do, 00A-00D, 01, 02, 04, 05, 06) were moved
* via "git mv" to their new names below -- full history is preserved in git,
* nothing was deleted. See CLAUDE.md for the full file-by-file mapping.
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	** -------------------- Import stage --------------------
	** Step 1: basicvars passthrough (every other file merges from this
	** instead of reading "$data_raw/basicvars" directly)
	** Output: temp/analysis/basicvars_2024.dta
	di as text ">>> [1/7] Import: basicvars"
	do "$dofile/01_Import_BasicVars.do"

	** Step 2: Reference lookup tables (no data dependencies)
	** Outputs: input/unit_scale.dta, output/process/index.dta
	di as text ">>> [2/7] Import: unit scale, price deflators"
	quietly do "$dofile/02_Import_UnitScale.do"        // import unit-scale Excel  → input/unit_scale.dta
	do "$dofile/03_Import_PriceDeflators.do"           // monthly CPI & food-CPI   → output/process/index.dta

	** Step 3: age_class + height + BMI/PAL/weight-gain + WHO SD-for-height,
	** all keyed off age_class (or gender+height) -- see that file's header
	** comment for why these are now combined here instead of split between
	** here and the old "05 MDER_ADER_XDER.do"
	** Output: output/process/AgeClassReference_2024.dta
	di as text ">>> [3/7] Import: age-class reference (height, BMI/PAL, SD)"
	do "$dofile/04_Import_AgeClassReference.do"

	** -------------------- Build stage --------------------
	** Step 4: Household composition (depends on 01_hhold + 02_indiv)
	** Outputs: temp/analysis/equivalence_scales2024.dta, temp/analysis/HH_size_food.dta
	di as text ">>> [4/7] Build: household composition"
	do "$dofile/05_Build_EquivalenceScales.do"  // FAO & OECD-1 adult-equivalent sizes
	do "$dofile/06_Build_HHFoodPartakers.do"    // effective food partaker count per HH

	** Step 5: Food consumption dataset
	** Outputs: output/process/food_2024.dta + food_2024_Noout.dta
	di as text ">>> [5/7] Build: food consumption"
	do "$dofile/07_Build_FoodConsumption.do"    // harmonised intake, price imputation, outlier treatment

	** Step 6: Individual, household, and nutrient conversion table files
	** Outputs: indivdual_2024.dta, Country_nct_2024_with_Foodout.dta
	di as text ">>> [6/7] Build: individual roster, NCT"
	do "$dofile/08_Build_IndividualRoster.do"       // demographics, labour market, household-head vars
	do "$dofile/09_Build_NutrientConversionTable.do" // national nutrient conversion table

	* SPREAD-DATA ADAPTATION (2026-07-03): "03 Household.do" (expenditure,
	* income, poverty status) cannot run against the de-identified "spread"
	* 2024 release -- its three required inputs (input/2024/consumption.dta,
	* all_inc_exp.dta, deflators.dta) don't exist in that folder at all, and
	* "cluster"/"household_id" are also stripped from basicvars.dta, which
	* this file needs. This is the poverty-analysis file, out of scope
	* regardless (see CLAUDE.md) and its output (household_2024.dta) isn't
	* consumed by the Calc stage, so disabling it has no effect on the
	* DEC/MDER/PoU calculation. Left un-renamed (out of scope, not part of
	* this reorg). Re-enable if ever run against the full (non-spread) data:
	*   do "$dofile/03 Household.do"           // expenditure, income, poverty status

	** -------------------- Calc stage --------------------
	** Step 7: Dietary energy requirements and consumption (core PoU inputs)
	** Outputs: Requirement_HHLevel.dta, Requirement_admin.dta, DEC_2024.dta
	di as text ">>> [7/7] Calc: DER and DEC"
	do "$dofile/10_Calc_DietaryEnergyRequirement.do"  // MDER / ADER / XDER + within-CV component
	do "$dofile/11_Calc_DietaryEnergyConsumption.do"  // DEC: calorie intake per capita per day

log close _all
exit




