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
	
	
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*
*	0. Set paths
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
	
			
		global dbase "$base/input"
		
	** Paths
		*global data_in		"$base/data/data_in"
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
	** "06 DEC.do"). Must be a variable that exists on basicvars.dta.
	** For now a single household-level var (region) is used; this can be
	** changed later (e.g. to newaimag, or a combined region x urban x income
	** quintile group built upstream) without editing "06 DEC.do" itself.
	global indirect_grp_var "region"


* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
*	2. Run do-files  (2024 analysis – dependency order)
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

	** Step 1: Reference lookup tables (no data dependencies)
	** Outputs: input/unit_scale.dta, output/process/index.dta
	di as text ">>> [1/6] Reference tables"
	quietly do "$dofile/0 Import Unit.do"              // import unit-scale Excel  → input/unit_scale.dta
	do "$dofile/00C Price deflation.do"    // monthly CPI & food-CPI   → output/process/index.dta

	** Step 2: Household composition (depends on 01_hhold + 02_indiv)
	** Outputs: temp/analysis/equivalence_scales24.dta, temp/analysis/HH_size_food.dta
	di as text ">>> [2/6] Household composition"
	do "$dofile/00A Equivalence scales.do" // FAO & OECD-1 adult-equivalent sizes
	do "$dofile/00D HHsize_Food.do"        // effective food partaker count per HH

	** Step 3: Individual heights (depends on 02_indiv + height reference)
	** Outputs: output/process/Height_Sattar.dta
	di as text ">>> [3/6] Individual heights"
	do "$dofile/00B MA_Height.do"          // age-sex height classes for DER estimation

	** Step 4: Food consumption dataset
	** Depends on: 00A, 00D, 00C, 00B, unit_scale
	** Outputs: output/process/food_2024.dta + food_2024_Noout.dta
	di as text ">>> [4/6] Food consumption"
	do "$dofile/01 Food.do"                // harmonised intake, price imputation, outlier treatment

	** Step 5: Individual, household, and nutrient conversion table files
	** Outputs: indivdual_2024.dta, Country_nct_2024_with_Foodout.dta, household_2024.dta
	di as text ">>> [5/6] Individual / Household / NCT"
	do "$dofile/02 Individual.do"          // demographics, labour market, household-head vars
	do "$dofile/04 Country_NCT.do"         // national nutrient conversion table

	* SPREAD-DATA ADAPTATION (2026-07-03): "03 Household.do" (expenditure,
	* income, poverty status) cannot run against the de-identified "spread"
	* 2024 release -- its three required inputs (input/2024/consumption.dta,
	* all_inc_exp.dta, deflators.dta) don't exist in that folder at all, and
	* "cluster"/"household_id" are also stripped from basicvars.dta, which
	* this file needs. This is the poverty-analysis file, out of scope
	* regardless (see CLAUDE.md) and its output (household_2024.dta) isn't
	* consumed by 05 or 06, so disabling it has no effect on the DEC/MDER/PoU
	* calculation. Re-enable if ever run against the full (non-spread) data:
	*   do "$dofile/03 Household.do"           // expenditure, income, poverty status

	** Step 6: Dietary energy requirements and consumption (core PoU inputs)
	** Outputs: Requirement_HHLevel.dta, Requirement_admin.dta, DEC_2024.dta
	di as text ">>> [6/6] DER and DEC"
	do "$dofile/05 MDER_ADER_XDER.do"     // MDER / ADER / XDER + within-CV component
	do "$dofile/06 DEC.do"                 // DEC: calorie intake per capita per day

log close _all
exit




