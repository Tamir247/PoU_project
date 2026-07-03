* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Household dataset
*
* PROJECT:			Food Analysis
*
* PROGRAMMER:		Undral Lkhagva (LK)
*
* DATE: 			Jan 2026
*
* DESCRIPTION:  	Prepare "Household" dataset for ADePT

*
* SIMPLE PIPELINE:
*   1) Start from basic household file and merge core add-ons.
*   2) Add head characteristics, income, expenditure, and poverty.
*   3) Deflate nominal income where required.
*   4) Save household file for AdePT/PoU analysis.
*


clear all
set more off

**************************** Household *****************************************************************************
use "$data_raw/basicvars.dta", clear
		merge m:1 identif using "$data_temp/equivalence_scales${survey_year}.dta", nogen keepusing(aesize_fao aesize_oecd1)

	keep identif cluster newaimag region urban location hhweight hhsize aesize_fao aesize_oecd1 month quarter
	order identif cluster newaimag region urban hhsize location hhweight aesize_fao aesize_oecd1 month quarter

	gen year=$survey_year
	sort identif 

	merge 1:1 identif using "$data_temp/temp_hhead_${survey_year}", nogen
	rename identif hses_id
	merge 1:1 hses_id using "$data_raw/01_hhold", keepus(visitor ndays) nogen
	
	* quick checks 
		assert  mi(ndays) if visitor==0
		*assert  !mi(ndays) if visitor>0
		replace ndays=0 if visitor>0 & ndays==.

		label var visitor "Number of food partakers"
		label var ndays   "Number of day/food partakers"

	rename  household_id identif
	sort identif
	merge 1:1 identif using "$data_raw/consumption", keepus(totex_rpae fdex_rpae fdex13_rpae pi_v1) nogen
	rename identif household_id  
	rename hses_id identif
			gen pline_r_pae=16882.01434441
			replace pline_r_pae=pline_r_pae*365/12
			gen poor=(totex_rpae<pline_r_pae)
			tab poor [iw=hhweight*hhsize]
	
			label val poor poor
			label define poor 0 "Non-poor" 1 "Poor" 

	sort identif
	merge 1:1 identif using "$data_raw/all_inc_exp", keepus(total_inc money_inc) nogen
		
	replace totex_rpae=totex_rpae*pi_v1
	gen hhexpday=(totex_rpae*aesize_oecd1)/(365/12)
	gen hhincday=total_inc/(365/12)


label var hhexpday "Household total consumption per day"
label var hhincday "Household total income per day"

tab pi_v1

/*
	gen pop_orginal=hhweight*hhsize
	count if pcfood1_12==0
	gen pop_new=hhweight*hhsize if pcfood1_12!=0
	count

	total(pop_orginal)
	total(pop_new)

	gen hhweight_adj=hhweight*(3185676/3182073)
	drop if pcfood1_12==0

	count
	*gen a =hhweight_adj*hhsize
	*total(a)
	compare hhweight hhweight_adj
*/

tab urban if fdex_rpae==0
		label var year "Year"
		label var poor "Poverty Status"
		label var total_inc "Household monthly total income"
		label var pi_v1 "Paasche  index by aimag-quarter"
		label var aesize_oecd1 "OECD1-Equivalent hhsize"
		label var aesize_fao "FAO-Equivalent hhsize"
				
		order  identif cluster newaimag region urban hhsize location year month quarter hhsize hhsize aesize_fao aesize_oecd1 hhsize_group2 visitor ndays  hhead* ///
				  fdex_rpae fdex13_rpae  totex_rpae  poor total_inc hhexpday hhincday pi_v1 hhweight  household_id

		keep identif cluster newaimag region urban hhsize location year month quarter hhsize_group2 hhead* visitor ///
				  fdex_rpae fdex13_rpae  totex_rpae  poor total_inc pi_v1 hhweight hhexpday hhincday		  
		sort year month 

		merge m:1 year month using "$data_out/index", keepus(def_cpi) nogen	  	  

		gen r_hhincday = hhincday/def_cpi  //hhexpday-consumption tul ali hezeenii zasagdsan medeelel yum tiimees zuwhun inc-iig zassan
		order r_hhincday, after(hhincday)
		label var r_hhincday "Household total real income per day"
		
		merge 1:1 identif using "$data_temp/HH_size_food", keepus(hhsize_food) nogen	  
		order hhsize_food, after(hhsize)


sort identif
saveold "$data_out/household_${survey_year}", version(12) replace
