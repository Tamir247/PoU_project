* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Master do-file -- 2018 DEC validation codebase
*
* PROJECT:			Food Analysis
*
* DATE: 			Jul 2026
*
* DESCRIPTION:  	Deliberately SEPARATE from the active 2024 pipeline
*					("00 Master.do" + the numbered 01-13 files). 2018's HSES
*					has a structurally different design (three 10-day "tenths"
*					per month instead of a single 7-day diary, no q0113
*					member-flag field, 4 household visit records instead of
*					3 -- see CLAUDE.md "Legacy 2018 pipeline") that the
*					numbered pipeline's do-files were never adapted for and
*					were deliberately NOT adapted for (a scoped decision made
*					earlier). This folder holds a small, narrow, SAVED
*					replacement for what used to be ad hoc scratchpad scripts
*					(dec_2018.do / dec_2018b.do, never committed to the repo)
*					-- just enough to validate DEC against ADePT-FSM's actual
*					2018 output and report it with the correct (population-)
*					weighting.
*
* NOT ATTEMPTED HERE (inputs don't exist for 2018, confirmed by checking
* input/2018/ directly):
*   - Income-decile CV / PoU estimate (no consumption.dta for 2018)
*   - Price deflation / FATH indirect-imputation calorie fix (no
*     "CPI, FCPI.xlsx" for 2018 -- food-away-from-home is NOT processed here,
*     same limitation as the original validation exercise)
*   - Food-partaker-adjusted household size, "hhsize_food" (no q0113/q0112a
*     in 2018's 02_indiv.dta) -- raw "hhsize" from basicvars.dta is used
*     instead throughout.
*   - MDER/ADER/XDER (out of scope for this validation exercise; only DEC
*     is being checked against the ADePT-FSM 2018 reference).
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	clear all
	set more off
	cap log close
	mat drop _all
	scalar drop _all

	global base "C:\Users\Admin\Desktop\PoU"
	log using "$base\2018_main.log", replace

	global survey_year_2018 2018
	global dbase "$base/input"
	global data_raw_2018 "$dbase/${survey_year_2018}"
	global data_temp_2018 "$base/temp/2018work"
	global data_out_2018 "$base/output/process/2018"
	global dofile "$base/dofiles"

	cap mkdir "$data_out_2018"

	di as text ">>> [1/2] Food diary cleaning (reused, unchanged, legacy script)"
	* ref/foodsetup.do is the already-adapted (2026-07) 2018 food-diary
	* cleaning script -- parsing, price/quantity outlier flagging, and a
	* price-imputation cascade structurally identical to the 2024 pipeline's
	* 08_Build_FoodConsumption.do. Its own 3 hardcoded path globals were
	* redirected earlier this project to input/2018, temp/2018work,
	* temp/2018log. Left as-is here (not duplicated into this folder) --
	* it's a big (1700+ line), already-verified file; only the DEC
	* calculation downstream of it is new/saved for this codebase.
	do "$dofile/ref/foodsetup.do"

	* NOTE: foodsetup.do manages its own log (cap log close + its own "log
	* using", ending at temp/2018log/setup_food.log) -- it closes the log
	* this master file opened above without reopening it. Re-open here so
	* step 2's results actually get captured somewhere durable, instead of
	* only existing in the "results" window of a batch run.
	cap log close
	log using "$base\2018_main.log", append

	di as text ">>> [2/2] DEC calculation + weighting report"
	do "$dofile/2018/01_Calc_DEC_2018.do"

log close _all
exit
