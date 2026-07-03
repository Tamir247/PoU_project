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
clear
input year month
	2024 1
	2024 2
	2024 3
	2024 4
	2024 5
	2024 6
	2024 7
	2024 8
	2024 9
	2024 10 
	2024 11
	2024 12
end

assert year == $survey_year

** Data source
** https://www.1212.mn/mn/statcate/table-view/Economy,%20environment/Consumer%20Price%20Index/DT_NSO_0600_001V3.px 
** 2023=100 index awch ashiglaw 


** Food price index by month
recode month 	(1 = 102.6)  ///
				(2 = 104.5)  ///
				(3 = 106.6)  ///
				(4 = 109.0)  ///
				(5 = 111.2)  ///
				(6 = 111.6)  ///
				(7 = 110.8)  ///
				(8 = 108.1)  ///
				(9 = 107.2)  ///
				(10 = 106.9) ///
				(11 = 107.2) ///
				(12 = 109.6), gen(fcpi)

** Consumer price index by month
recode month 	(1 = 102.8)  ///
				(2 = 103.5)  ///
				(3 = 104.3)  ///
				(4 = 105.0)  ///
				(5 = 105.6)  ///
				(6 = 105.9)  ///
				(7 = 106.0)  ///
				(8 = 107.0)  ///
				(9 = 107.0)  ///
				(10 = 107.5) ///
				(11 = 109.2) ///
				(12 = 110.5), gen(cpi)


				
summ cpi if year == $survey_year
	scalar base_cpi = r(mean)

summ fcpi if year == $survey_year
	scalar base_fcpi = r(mean)

gen def_cpi  = cpi /base_cpi
gen def_fcpi = fcpi/base_fcpi


keep year month cpi fcpi def_cpi def_fcpi
order year month cpi fcpi def_cpi def_fcpi

save "$data_out/index.dta", replace


