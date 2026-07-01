*
* SIMPLE PIPELINE:
*   1) Assemble historical income/consumption components.
*   2) Merge quarters/years into a comparable structure.
*   3) Produce weighted summaries by area and period.
*   4) Export tables used for GDP-related diagnostics.
*


	clear all
	set more off
	cap log close
	mat drop _all
	scalar drop _all
	macro drop _all	
	
	
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*
*	0. Set paths
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
	
	** User paths
			
		// undral
		if "`c(username)'" == "undral" {
				global base14 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2014\HSES_2014"
				global base15 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2015\HSES_2015"
				global base16 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2016\HSES_2016"
				global base17 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2017\HSES_2017"
				global base18 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2018\HSES_2018"				
				global base19 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2019\HSES_2019"
				global base20 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2020\HSES_2020" 
				global base21 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2021" 
				global base22 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2022" 		
				global base23 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2023" 
				global base24 "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\1.HSES\HSES_result_2024"
				global base "D:\Onedrive\OneDrive - ÐœÐžÐÐ“ÐžÐ› Ð£Ð›Ð¡Ð«Ð Ò®ÐÐ”Ð­Ð¡ÐÐ˜Ð™ Ð¡Ð¢ÐÐ¢Ð˜Ð¡Ð¢Ð˜ÐšÐ˜Ð™Ð Ð¥ÐžÐ ÐžÐž\10.Personnal\6.Projects_with_others\FAO_Project\NDC" 
			}	
			
		global data_out		"$base/output/process"
		global data_temp    "$base/temp/analysis"
		global output		"$base/output/analysis"
		global checks	    "$base/temp/check"
		
		
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*	1. Set globals
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

	** General
	gl inc_vars total_inc money_inc inc_tot_wage inc_tot_pension inc_tot_agriculture inc_tot_business inc_tot_other
	gl exp_vars total_exp money_exp food_pur nfood  nfoodloan nfoodother nfoodgifts food_res  nfoodfree food_own
	

************************* FOOD **********************
	use "$data2018/16_urb_diary.dta", clear

		sort hses_id item
		egen q12_pur=rsum( q1201_2 q1202_2 q1203_2)
		egen q12_res=rsum( q1201_3 q1202_3 q1203_3)
		egen q12_own=rsum( q1201_4 q1202_4 q1203_4)

		rename q1204 uprice

		egen qcons=rsum(q12_pur q12_res q12_own)

		collapse (sum) qcons (median) uprice, by(hses_id item)
		sort hses_id item
	save food12, replace

************************************************
	use "$data2018/17_rur_food_7d.dta", clear
		sort hses_id item

		gen q13_pur=q1303 * 4.285714286
		gen q13_res=q1305 * 4.285714286
		gen q13_own=q1306 * 4.285714286

		rename q1304 uprice

		egen qcons=rsum(q13_pur q13_res q13_own)

		collapse (sum) qcons (median) uprice, by(hses_id item)
		sort hses_id item
	save food13, replace

******************hunsnii 2 bulgiig negtgeh********
	append using food12
	count
	rename hses_id identif

	sort identif item
	merge identif using "$data2018\basicvars"
	tab _m
	drop if _m~=3
	drop _m

	replace uprice=. if uprice==0
	egen meduprice     =median(uprice), by(identif item)
	egen clusterprice  =median(uprice), by(cluster item)
	egen aimagprice    =median(uprice), by(newaimag location item)
	* all_inc_exp- deer doorh hyazgaarlaltiig awsan
	*egen aimagprice    =median(uprice), by(newaimag item)
	egen locationprice =median(uprice), by(location item)
	* all_inc_exp- deer doorh hyazgaarlalt bhgui awsan
	egen monthprice    =median(uprice), by(month item)
	egen itemprice     =median(uprice), by(item)

	inspect qcons
	gen vcons=qcons*meduprice
	count if vcons==. 
	replace vcons=qcons*clusterprice if vcons==. 
	count if vcons==. 
	replace vcons=qcons*aimagprice if vcons==. 
	count if vcons==. 
	replace vcons=qcons*locationprice if vcons==. 
	count if vcons==.
	replace vcons=qcons*monthprice if vcons==. 
	count if vcons==.
	replace vcons=qcons*itemprice if vcons==. 
	count if vcons==. & qcons~=0

	collapse (sum) vcons, by(identif item)
	reshape wide vcons, i(identif) j(item)

	sort identif 
	merge identif using "$data2018\basicvars"
	tab _m
	drop if _m~=3
	drop _m

******************Output table**************************
for var v*: recode X .=0
cap log close
log using "$worklog_other/food_GDP_2018.log", replace
svyset cluster [pweight=hhweight], strata(location)
svy: mean v*  
svy: mean v* if urban==1 
svy: mean v* if urban==2 
svy: mean v* if quarter==1 
svy: mean v* if quarter==2 
svy: mean v* if quarter==3 
svy: mean v* if quarter==4 

qui tabstat v* [aw=hhweight], by(urban) save
	qui tabstatmat a
	mat b = a'
	mat list b
	mat drop a b
	
qui tabstat v* [aw=hhweight], by(quarter) save
	qui tabstatmat a
	mat b = a'
	mat list b
	mat drop a b

log close
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*
*	1. Merge datasets
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
foreach n of numlist 19 20 21 22 23 24 25 {
		***********
		display `n'
		***********
		use "${data`n'_q1}\all_inc_exp", clear
		gen period=20`n'01
		keep period hses_id inc_tot_wage inc_tot_pension inc_tot_agriculture inc_tot_business inc_tot_other aimag location urban strata hhweight nfood nfoodother nfoodgifts nfoodfree foodout nfoodloan food_pur money_inc total_inc money_exp total_exp food_res  nfoodfree food_own

		order period hses_id total_inc money_inc inc_tot_wage inc_tot_pension inc_tot_agriculture inc_tot_business inc_tot_other total_exp money_exp food_pur foodout nfood nfoodloan nfoodother nfoodgifts  food_res  nfoodfree food_own urban location strata aimag hhweight
		summ
		sort hses_id
		save "${data_temp}/temp`n'01", replace
}



foreach n of numlist 19 20 21 22 23 24 25 {
		***********
		display `n'
		***********
		use "${data`n'_q2}\all_inc_exp", clear
		gen period=20`n'02
		keep period hses_id inc_tot_wage inc_tot_pension   inc_tot_agriculture inc_tot_business inc_tot_other aimag location urban strata hhweight nfood nfoodother nfoodgifts nfoodfree foodout nfoodloan food_pur money_inc total_inc money_exp total_exp food_res  nfoodfree food_own

		order period hses_id total_inc money_inc inc_tot_wage inc_tot_pension inc_tot_agriculture   inc_tot_business inc_tot_other total_exp money_exp food_pur foodout nfood nfoodloan nfoodother nfoodgifts food_res  nfoodfree food_own urban location strata aimag hhweight
		summ
		sort hses_id
		save "${data_temp}/temp`n'02", replace
}



foreach n of numlist 19 20 21 22 23 24 25 {
		***********
		display `n'
		***********
		use "${data`n'_q3}\all_inc_exp", clear
		gen period=20`n'03
		keep period hses_id inc_tot_wage inc_tot_pension   inc_tot_agriculture inc_tot_business inc_tot_other aimag location urban strata hhweight nfood nfoodother nfoodgifts nfoodfree foodout nfoodloan food_pur money_inc total_inc money_exp total_exp food_res  nfoodfree food_own

		order period hses_id total_inc money_inc inc_tot_wage inc_tot_pension inc_tot_agriculture   inc_tot_business inc_tot_other total_exp money_exp food_pur foodout nfood nfoodloan nfoodother nfoodgifts food_res  nfoodfree food_own urban location strata aimag hhweight
		summ
		sort hses_id
		save "${data_temp}/temp`n'03", replace
}


foreach n of numlist 19 20 21 22 23 24 25 {
		***********
		display `n'
		***********
		use "${data`n'_q4}\all_inc_exp", clear
		gen period=20`n'04
		keep period hses_id inc_tot_wage inc_tot_pension   inc_tot_agriculture inc_tot_business inc_tot_other aimag location urban strata hhweight nfood nfoodother nfoodgifts nfoodfree foodout nfoodloan food_pur money_inc total_inc money_exp total_exp food_res  nfoodfree food_own

		order period hses_id total_inc money_inc inc_tot_wage inc_tot_pension inc_tot_agriculture   inc_tot_business inc_tot_other total_exp money_exp food_pur foodout nfood nfoodloan nfoodother nfoodgifts food_res  nfoodfree food_own urban location strata aimag hhweight
		summ
		sort hses_id
		save "${data_temp}/temp`n'04", replace
}


use "$data_temp\temp1901", clear 

summ total_inc money_inc total_exp money_exp [aw=hhweight]	

append using "$data_temp\temp1902"
append using "$data_temp\temp1903"	
append using "$data_temp\temp1904"
append using "$data_temp\temp2001"
append using "$data_temp\temp2002"
append using "$data_temp\temp2003"	
append using "$data_temp\temp2004"
append using "$data_temp\temp2101"
append using "$data_temp\temp2102"
append using "$data_temp\temp2103"	
append using "$data_temp\temp2104"	
append using "$data_temp\temp2201"	
append using "$data_temp\temp2202"	
append using "$data_temp\temp2203"	
append using "$data_temp\temp2204"	
append using "$data_temp\temp2301"
append using "$data_temp\temp2302"
append using "$data_temp\temp2303"	
append using "$data_temp\temp2304"	
append using "$data_temp\temp2401"
append using "$data_temp\temp2402"	
append using "$data_temp\temp2403"	
append using "$data_temp\temp2404"	
append using "$data_temp\temp2501"
append using "$data_temp\temp2502"	
append using "$data_temp\temp2503"
append using "$data_temp\temp2504"

tab period

summ				

foreach v of varlist $inc_vars $exp_vars {
	
	gen r_`v'=`v'/$cpi19q1_20 if period==201901
	replace r_`v'=`v'/$cpi19q2_20 if period==201902
	replace r_`v'=`v'/$cpi19q3_20 if period==201903
	replace r_`v'=`v'/$cpi19q4_20 if period==201904
	
	replace r_`v'=`v'/$cpi20q1_20 if period==202001
	replace r_`v'=`v'/$cpi20q2_20 if period==202002
	replace r_`v'=`v'/$cpi20q3_20 if period==202003
	replace r_`v'=`v'/$cpi20q4_20 if period==202004
	
	replace r_`v'=`v'/$cpi21q1_20 if period==202101
	replace r_`v'=`v'/$cpi21q2_20 if period==202102
	replace r_`v'=`v'/$cpi21q3_20 if period==202103
	replace r_`v'=`v'/$cpi21q4_20 if period==202104

	replace r_`v'=`v'/$cpi22q1_20 if period==202201
	replace r_`v'=`v'/$cpi22q2_20 if period==202202
	replace r_`v'=`v'/$cpi22q3_20 if period==202203
	replace r_`v'=`v'/$cpi22q4_20 if period==202204
	
	
	replace r_`v'=`v'/$cpi23q1_20 if period==202301
	replace r_`v'=`v'/$cpi23q2_20 if period==202302
	replace r_`v'=`v'/$cpi23q3_20 if period==202303
	replace r_`v'=`v'/$cpi23q4_20 if period==202304

	replace r_`v'=`v'/$cpi24q1_20 if period==202401
	replace r_`v'=`v'/$cpi24q2_20 if period==202402
	replace r_`v'=`v'/$cpi24q3_20 if period==202403
	replace r_`v'=`v'/$cpi24q4_20 if period==202404
	
	replace r_`v'=`v'/$cpi25q1_20 if period==202501
	replace r_`v'=`v'/$cpi25q2_20 if period==202502
	replace r_`v'=`v'/$cpi25q3_20 if period==202503
	replace r_`v'=`v'/$cpi25q4_20 if period==202504

}

gen decile5   = .
gen decile10  = .
gen decile100 = .


local periods 201901 201902 201903 201904 202001 202002 202003 202004 202101 202102 202103 202104 202201 202202 202203 202204 202301 202302 202303 202304 202401 202402 202403 202404 202501 202502 202503 202504

foreach n of local periods {

	xtile d5 = total_inc [aw=hhweight] if period==`n', nq(5)
	xtile d10 = total_inc [aw=hhweight] if period==`n', nq(10)
	xtile d100 = total_inc [aw=hhweight] if period==`n', nq(100)
	
	replace decile5   = d5   if period==`n'
    replace decile10  = d10  if period==`n'
    replace decile100 = d100 if period==`n'
	
	drop d5 d10 d100
}

save "$data_out\real_inc_exp", replace 



fff ggg


use "$data_out\real_inc_exp", clear 

*************************** p10 p25 p50 p75 p90
preserve 	
	collapse (p10) p10=r_total_inc (p25) p25=r_total_inc (median) p50=r_total_inc (p75) p75=r_total_inc (p90) p90=r_total_inc [iw=hhweight], by(period)
	*reshape wide p10 p25 p50 p75 p90, i(percentile) j(period)
	xpose, clear varname
	order _varname
	rename v* p_*
	export excel using "$data_out/Table.xlsx", firstrow(variables) sheet("total_inc") replace
restore



foreach var of varlist money_inc inc_tot_wage inc_tot_pension inc_tot_agriculture inc_tot_business inc_tot_other total_exp money_exp food_pur nfood  nfoodloan nfoodother nfoodgifts food_res  nfoodfree food_own {
	preserve 	
			collapse (p10) p10=r_`var' (p25) p25=r_`var' (median) p50=r_`var' (p75) p75=r_`var' (p90) p90=r_`var' [iw=hhweight], by(period)
			xpose, clear varname
			order _varname
			rename v* p_*
			export excel using "$data_out/Table.xlsx", firstrow(variables) sheet("`var'") 
	restore		
}


*************************** decile5 decile10 decile100

foreach var of varlist total_inc money_inc inc_tot_wage inc_tot_pension inc_tot_agriculture inc_tot_business inc_tot_other total_exp money_exp food_pur nfood  nfoodloan nfoodother nfoodgifts food_res  nfoodfree food_own {
	preserve 
		collapse (mean) r_`var' [aw=hhweight] , by(decile5 period)
		reshape wide r_`var', i(decile5) j(period)	
		order decile* r_`var'*
		export excel using "$data_out/Table.xlsx", cell(A10) firstrow(variables) sheet("`var'", modify)
	restore
}




foreach var of varlist total_inc money_inc inc_tot_wage inc_tot_pension inc_tot_agriculture inc_tot_business inc_tot_other total_exp money_exp food_pur nfood  nfoodloan nfoodother nfoodgifts food_res  nfoodfree food_own {
	preserve 
		collapse (mean) r_`var' [aw=hhweight] , by(decile10 period)
		reshape wide r_`var', i(decile10) j(period)	
		order decile* r_`var'*
		export excel using "$data_out/Table.xlsx", cell(A18) firstrow(variables) sheet("`var'", modify)
	restore
}


foreach var of varlist total_inc money_inc inc_tot_wage inc_tot_pension inc_tot_agriculture inc_tot_business inc_tot_other total_exp money_exp food_pur nfood  nfoodloan nfoodother nfoodgifts food_res  nfoodfree food_own {
	preserve 
		collapse (mean) r_`var' [aw=hhweight] , by(decile100 period)
		reshape wide r_`var', i(decile100) j(period)	
		order decile* r_`var'*
		export excel using "$data_out/Table.xlsx", cell(A30) firstrow(variables) sheet("`var'", modify)
	restore
}



stop stop stop 


/*
matrix M = J(5,15,.)
local rownames = "p10 p25 p50 p75 p90"
matrix rownames M = p10 p25 median p75 p90
matrix colnames M = 2022_q1 2022_q2 2022_q3 2022_q4 2023_q1 2023_q2 2023_q3 2023_q4  2024_q1 2024_q2 2024_q3 2024_q4 2025_q1 2025_q2 2025_q3

local periods 202201 202202 202203 202204 202301 202302 202303 202304 202401 202402 202403 202404 202501 202502 202503 
local j=1

foreach v of local periods {
			summarize r_total_inc [aw=hhweight] if period==`v', detail
			matrix M[1,`j'] = r(p10)
			matrix M[2,`j'] = r(p25)
			matrix M[3,`j'] = r(p50)
			matrix M[4,`j'] = r(p75)
			matrix M[5,`j'] = r(p90)
			local j=`j'+1
}

matrix list M
*/



/*

preserve 
	collapse (mean) r_total_inc  r_total_exp [aw=hhweight] , by(decile5 period)
	reshape wide r_total_inc  r_total_exp , i(decile5) j(period)	
	order decile* r_total_inc* r_total_exp*
	export excel using "$data_out/Table.xlsx", firstrow(variables) sheet("decile5") replace
restore


preserve 
	collapse (mean)r_total_inc r_total_exp [aw=hhweight] , by(decile10 period)
	reshape wide r_total_inc r_total_exp, i(decile10) j(period)
	order decile* r_total_inc* r_total_exp*

	export excel using "$data_out/Table.xlsx", firstrow(variables) sheet("decile10") 
restore


preserve 
	collapse (mean) r_total_inc r_total_exp [aw=hhweight] , by(decile100 period)
	reshape wide r_total_inc r_total_exp, i(decile100) j(period)	
	order decile* r_total_inc* r_total_exp*
	export excel using "$data_out/Table.xlsx", firstrow(variables) sheet("decile100") 
restore



fffffffffffff



table decile [aw=hhweight*hhsize], row c(mean rpcexpm) col

xtile decile10 = rpcexpm [aw=hhweight*hhsize] if year==2010, nq(100)


count





