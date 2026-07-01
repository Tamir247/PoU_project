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

use "$data_out/food_2024_Noout",clear 

	collapse (sum) daily_qty_gr daily_qpur_gr daily_qfree_gr daily_qown_gr daily_exp daily_rexp, by(identif item)
	tab item
	*check
		egen a=rsum( daily_qpur_gr daily_qfree_gr daily_qown_gr )
		compare a daily_qty_gr // looks good
		drop a
		
	merge m:1 identif using "$data_temp/HH_size_food", nogen
			merge m:1 identif using "$data_raw24/basicvars", keepus(hhweight) nogen

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
	
joinby item using "$data_out/Country_nct_2024_with_Foodout", unm(b)
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

saveold "$data_out/DEC_2024", version(12) replace