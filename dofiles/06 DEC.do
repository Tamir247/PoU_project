* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Dietary Energy Consumption
*
* PROJECT:			Food Analysis
*
* PROGRAMMER:		Undral Lkhagva (LK)
*
* DATE: 			Jan 2026
*
* DESCRIPTION:  	Dietary Energy Consumption

*
* SIMPLE PIPELINE:
*   1) Aggregate adjusted food quantities and expenditures by item.
*   2) Convert quantities to calories using nutrient table.
*   3) Build household and per-capita dietary energy consumption.
*   4) Prepare DEC components for PoU parameter estimation.
*
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*The foundamental elements of the PoU
*The average Dietary Energy Consumption (DEC) â€“ kcal/cap/day
*The inequality in access to food, the Coefficient of Variation (CV)
*The Minimum Dietary Energy Requirement (MDER), the threshold â€“ kcal/cap/day
*The functional form of the distribution of the dietary energy intake, and the estimation of its asymmetry by the skewness (SK)
* indicators 
* Dietary Energy Intake (DEI)
* Dietary Energy Requirements (DER)
* Dietary Energy Consumption (DEC)
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

******************************************************************************************************* 
***************************** PART- Conclusion ******************************************************** 
**** PoU-iig bodohiin tuld MDER, DEC(Dietary enery intakes-consumption), Within CV, Between CV, Physical Activity- g tootsoh yostoi** 
**** HSES-iin consumption data ashiglaad DEC, Between CV-g tootsoh yostoi ************
**** MDER bolon within CV-g tootsson bol DEC-ees between CV tootsno. ***************************
******************************************************************************************************* 

use "$data_out/food_${survey_year}_Noout",clear

	* grouping var for the indirect/unit-value method below (step 5); set in
	* "00 Master.do" -- default here only guards standalone runs of this file
	if "$indirect_grp_var"=="" global indirect_grp_var "region"

	collapse (sum) daily_qty_gr daily_qpur_gr daily_qfree_gr daily_qown_gr daily_exp daily_rexp, by(identif item)
	tab item
	*check
		egen a=rsum( daily_qpur_gr daily_qfree_gr daily_qown_gr )
		compare a daily_qty_gr // looks good
		drop a
		
	merge m:1 identif using "$data_temp/HH_size_food", nogen
			merge m:1 identif using "$data_raw/basicvars", keepus(hhweight $indirect_grp_var) nogen

**** converting exp. and quantities into per capita per day at each food item level**
	gen daily_pc_qty_gr=daily_qty_gr/hhsize_food  // fix: after collapse the var is daily_qty_gr
	gen daily_pc_qpur_gr=daily_qpur_gr/hhsize_food
	gen daily_pc_qfree_gr=daily_qfree_gr/hhsize_food
	gen daily_pc_qown_gr=daily_qown_gr/hhsize_food
	gen daily_pc_exp=daily_exp/hhsize_food // gertee buten sar baigaagui huniig hasasj hhsize-iig dahin tootsson
	gen daily_pc_rexp=daily_rexp/hhsize_food 

		label var daily_qty_gr "HH daily total qty by gr"
		label var daily_qpur_gr  "HH daily purchased qty by gr "
		label var daily_qfree_gr "HH daily free of charge qty by gr"
		label var daily_qown_gr "HH daily self-consumed qty by gr "
		label var daily_exp "HH food daily monetary value"
		label var daily_rexp "HH real food cons per day"
	
		label var daily_pc_qty_gr "PC daily total qty by gr"
		label var daily_pc_qpur_gr "PC daily purchased qty by gr"
		label var daily_pc_qfree_gr "PC daily free of charge qty by gr"
		label var daily_pc_qown_gr "PC daily self-consumed  qty by gr"
		label var daily_pc_exp "PC food daily monetary value"
		label var daily_pc_rexp "PC real daily monetary value"
		
		order hhsize*, last
	
joinby item using "$data_out/Country_nct_${survey_year}_with_Foodout", unm(b)
tab _m
drop if _m==2
drop _m id

tab item

* Calories(Kcal)=Protein(g)+9*Fats(g)+Av.Carbohydrates(g)*4+Fiber(g)*2+Alcohol(g)*7
*Available Carbohydrates(g)=total carbohydrates-fibers 

gen kcal=4*fd_pro+4*fd_car+9*fd_fat+2*fd_fib
**** medeellee grams-aar ilerhiilne uchir ni ulchleg ni 100g-d nognod colories-iin hemjee bgaa 

gen a=kcal-calories
gen b=kcal-fd_kcal

summ a b
compare kcal calories
*ed if kcal!=calories   // interactive data browser - disabled in batch mode
compare kcal fd_kcal
*ed if kcal!=fd_kcal & b>1 & b!=.


** Converting quantities into calories
	*gen calories=fd_qty/100*(energy_kcal)
	*gen calories=fd_qty/100*(kcal)
	*gen calories=fd_qty/100*(calorieskcal)
	gen hh_cal=daily_qty_gr/100*(kcal)
	gen pc_cal=hh_cal/hhsize_food

* ============================================================================
* FIX (2026-07-01, Claude; rebuilt 2026-07-02 on the handbook's 6-step
* indirect/unit-value method, Ch.2): item 21801 (Гадуур хооллолт / Food-Away-
* From-Home) has NO nutrient data in Country_nct_2024_with_Foodout.dta -- the
* placeholder row appended for it in "04 Country_NCT.do" (~line 72-85) only
* sets id/desc/refuse/item_grp/diversity_grp and never fills fd_pro/fd_fat/
* fd_fib/fd_car/fd_kcal. That left `kcal` (and therefore hh_cal/pc_cal above)
* MISSING for every one of the 1,549 households (~14.9% of the sample) that
* report eating-out spending, and egen total() below silently treats missing
* as 0 -- i.e. eating-out calories were being dropped entirely from DEC, not
* just left uncertain. This was the confirmed root cause of PC_tot_cal
* averaging ~1,941 kcal/person/day instead of the ~2,000-2,500 kcal range
* this file expects (see diagnostic below).
*
* FATH is only ever recorded as money spent (daily_exp/daily_rexp, from
* 19_foodout.dta), never as a food quantity in grams, so it cannot use the
* grams x kcal/100g approach every other item uses. Instead this adapts the
* handbook's 6-step indirect method (used when quantity isn't observed and
* must be inferred from expenditure via a median unit value):
*   Steps 1-2 (deflate expenditure by the survey-period food-CPI index) are
*     already done upstream -- that IS daily_rexp (see "01 Food.do", merged
*     with output/process/index.dta).
*   Step 3 (convert to a standard unit) doesn't apply to FATH itself -- there
*     is no physical quantity for "eating out" -- so instead of a price per
*     gram we use an implied *calorie* value per unit of real food
*     expenditure (kcal per 1,000 real MNT), estimated from the rest of the
*     already-quantified food basket, as a stand-in unit value.
*   Step 4: for every non-FATH household-item row, compute that ratio.
*   Step 5: take the MEDIAN of the ratio, grouped by $indirect_grp_var (set
*     in "00 Master.do" -- currently household region; swap/extend it there,
*     e.g. to region x urban x income quintile, without touching this file).
*   Step 6: apply each household's own group median rate to FATH's real
*     expenditure (daily_rexp) to impute its calories.
*
* This is a METHODOLOGICAL ASSUMPTION (adapting the indirect method to a
* category with no physical unit), not a verified fact -- please review
* before treating results as final, and replace with an official FATH kcal
* benchmark (e.g. a standard restaurant-meal estimate) if one becomes
* available.
* ============================================================================

	* Step 4: household-item unit value in calorie terms, quantified basket only
	gen cal_per_1000rmnt = hh_cal/daily_rexp*1000 if item!=21801 & daily_rexp>0 & hh_cal!=. & hh_cal>0

	* Step 5: median unit value by group (region, for now -- see $indirect_grp_var)
	egen fath_kcal_rate     = median(cal_per_1000rmnt), by($indirect_grp_var)
	egen fath_kcal_rate_nat = median(cal_per_1000rmnt)
	replace fath_kcal_rate = fath_kcal_rate_nat if missing(fath_kcal_rate)  // fallback: group too small/missing
	label var fath_kcal_rate "Median kcal/1,000 real MNT by $indirect_grp_var (step 5, indirect method)"

	di as result "Median kcal per 1,000 real MNT of food value, by $indirect_grp_var (used to impute FATH calories):"
	tab $indirect_grp_var if item==21801, summarize(fath_kcal_rate)

	* [diagnostic] FATH rows before imputation -- hh_cal/pc_cal should be all missing here
	summ hh_cal pc_cal daily_rexp if item==21801

	* Step 6: apply the group's median rate to FATH's own real expenditure
	replace hh_cal = daily_rexp/1000*fath_kcal_rate if item==21801
	replace pc_cal = hh_cal/hhsize_food             if item==21801

	* [diagnostic] FATH rows after imputation -- hh_cal/pc_cal should now be populated
	summ hh_cal pc_cal daily_rexp if item==21801

	drop cal_per_1000rmnt fath_kcal_rate fath_kcal_rate_nat
* ============================================================================
* END FIX
* ============================================================================


* ---- Aggregate calorie intake to household level --------------------------------
*  hh_cal     = kcal consumed by the household today from this food item
*  pc_cal     = per-capita share (distributed evenly among food partakers)
*  HH_tot_cal / PC_tot_cal = total across ALL food items per household
egen HH_tot_cal = total(hh_cal), by(identif)
egen PC_tot_cal = total(pc_cal),  by(identif)

* [diagnostic] national weighted mean should be ~2000-2500 kcal/person/day
summ HH_tot_cal PC_tot_cal [iw=hhweight] if item==10101

label var HH_tot_cal "HH total dietary energy consumption (kcal/day)"
label var PC_tot_cal  "Per-capita dietary energy consumption (kcal/day)"

* Collapse to one row per household – HH_tot_cal/PC_tot_cal are identical
* across all item rows of the same HH after the by-group total above
collapse (firstnm) HH_tot_cal PC_tot_cal hhsize_food hhweight, by(identif)

saveold "$data_out/DEC_${survey_year}", version(12) replace