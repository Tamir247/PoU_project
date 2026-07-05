* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Price deflation
*
* PROJECT:			Food Analysis 
*
* PROGRAMMER:		Undral Lkhagva (UK) 
*
* DATE: 			Jan 2026
*
* DESCRIPTION:  	Price deflation

*
* SIMPLE PIPELINE:
*   1) Create monthly year-month skeleton for 2024.
*   2) Enter CPI and food CPI series from official source.
*   3) Build deflator indices using annual mean base.
*   4) Save index file for real-value adjustments.
*
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 


** Data source
** https://www.1212.mn/mn/statcate/table-view/Economy,%20environment/Consumer%20Price%20Index/DT_NSO_0600_001V3.px 
** index awch ashiglaw 
import excel "$data_raw\CPI, FCPI.xlsx", firstrow clear
	assert year == $survey_year
	assert _n == month

summ cpi if year == $survey_year
	scalar base_cpi = r(mean)

summ fcpi if year == $survey_year
	scalar base_fcpi = r(mean)

gen def_cpi  = cpi /base_cpi
gen def_fcpi = fcpi/base_fcpi


keep year month cpi fcpi def_cpi def_fcpi
order year month cpi fcpi def_cpi def_fcpi

save "$data_out/index.dta", replace


