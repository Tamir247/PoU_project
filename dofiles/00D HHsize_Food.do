* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Re Define  HHsize
*
* PROJECT:			Food Analysis
*
* PROGRAMMER:		Undral Lkhagva (LK)
*
* DATE: 			Jan 2026
*
* DESCRIPTION:  	Define no. of person who eat food

*
* SIMPLE PIPELINE:
*   1) Keep household members and merge basic household vars.
*   2) Identify members absent for the full food reference period.
*   3) Recompute household food partaker size.
*   4) Save HH size-for-food denominator file.
*
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* Partaker 

	use "$data_raw/02_indiv", clear

		*ed if hses_id== 241000312
		*ed if identif== 241000312
		
		* SPREAD-DATA ADAPTATION (2026-07-03): the de-identified "spread"
		* release already ships "identif" instead of "hses_id" -- guard so
		* this runs against either source.
		capture rename hses_id identif
		joinby identif using "$data_raw/basicvars", unm(b)
		tab _m
		drop _m
		keep if q0113==1
		
		bysort identif: generate hh_size=_N

		***deducting household members who were not present at home during 7 and 30 days 	
		gen abs_mem=(q0112a!=. &  (q0112a==30 | q0112a>30))
		tab1 abs_mem*
		recode abs_mem (0=1) (1=0), gen(abs_mem2)
		egen hhsize_food=sum(abs_mem2), by(identif) 
		compare hhsize hh_size
		compare hhsize hhsize_food
		drop hh_size abs_mem
		
		replace hhsize_food=hhsize if hhsize_food==0
		
		
	collapse (first) hhsize_food hhsize, by(identif)
	
	sort identif
	save "$data_temp/HH_size_food", replace
	* stop removed – visitor adjustment block below is kept as reference only
	
	
	
	/* 
	
	*** Adding visitors
	rename identif hses_id
	joinby hses_id using "$data_raw/01_hhold", unm(b)
	drop _m
	rename hses_id identif 
	
	gen v_days=ndays 
	replace v_days=7 if ndays>=7 & ndays!=. 

	
	gen partak=0
	replace partak=(v_days*visitor)/7 

	egen partaker_f=rsum (partaker partak)
	rename identif hhcode  
	keep hhcode hh_size partaker partak partaker_f location urban region month hhweight
	save HH_size, replace
	
	
	