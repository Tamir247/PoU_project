* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Equivalence scales
*
* PROJECT:			Food Analysis
*
* PROGRAMMER:		Undral Lkhagva (UL) 
*
* DATE: 			Jan 2026
*
* DESCRIPTION:  	Adjusting for HH composition/size

*
* SIMPLE PIPELINE:
*   1) Clean interview dates and build survey date.
*   2) Prepare individual age and sex structure by household.
*   3) Compute OECD1 and FAO adult-equivalent scales.
*   4) Save household equivalence-scale file for merges.
*
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *


* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*
*	1. Check ages
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 


	use "$data_raw24/01_hhold.dta", clear
	rename hses_id identif
		merge 1:1 identif using "$data_raw24/basicvars.dta", keepusing(month hhsize cluster) nogen
		order cluster
		sort cluster identif
		
	** Clean interview dates
	
		// first visit. must be within possible date
		gen check1=1 if v1_yy != survey_year | v1_mm>12 // өдөр байхгүй?
		bys cluster: egen mcheck1=max(check1)			

		// second visit. must be within possible date
		gen check2=1 if (v2_yy != survey_year) | (v2_mm>12) | (v2_dd>31)
			replace check2=. if (v2_dd==. & v2_mm==. & v2_yy==.) | v2_res==.
		bys cluster: egen mcheck2=max(check2)			 
		
		// third visit
		gen check3=1 if v3_yy!=24 | v3_mm>12 | v3_dd>31
			replace check3=. if (v3_dd==. & v3_mm==. & v3_yy==.) | v3_res==.
		bys cluster: egen mcheck3=max(check3)			 
		
**# Bookmark #1
		// looks like month entered in year and day entered in month --> replace
		forval x=1/3 {
			replace v`x'_dd=v`x'_mm if check`x'==1
			replace v`x'_mm=v`x'_yy if check`x'==1
			replace v`x'_yy=24 if check`x'==1
		} // ?? 
		
		drop mcheck? check?
			
		
		gen double surveydate=mdy(v1_mm,v1_dd,real("20"+string(survey_year))) if inlist(v1_res,1,2)
			replace surveydate=mdy(v2_mm,v2_dd,real("20"+string(survey_year))) if inlist(v2_res,1,2) & surveydate==.
			replace surveydate=mdy(v3_mm,v3_dd,real("20"+string(survey_year))) if surveydate==.
			replace surveydate=mdy(v2_mm,v2_dd,real("20"+string(survey_year))) if surveydate==.
			format surveydate %td
			
		keep identif surveydate hhsize
		
		// Судалгааны онд яг таарч буйг шалгаж байна. 
		// Үгүй бол алдаа гарсан буюу судалгааны оноос гажсан өөр судалгаанууд байна гэсэн үг. 
		assert inrange(surveydate, ///
				date("01jan20" + string(survey_year), "DMY"), /// Оны эхэн
				date("31dec20" + string(survey_year), "DMY")) /// Оны төгсгөл
			
		tempfile d 
		save `d', replace
		
		
	// age based on birthdate 
	
	use "$data_raw24/02_indiv.dta", clear
	rename hses_id identif
		merge m:1 identif using `d', nogen
		  
		gen double bday=mdy(q0104m, q0104d, q0104y)
			format bday %td
			
		describe bday surveydate
	

		*gen double age_exact=age_frac(bday,surveydate)
		*gen double age_int=age(bday,surveydate)
		gen double age_exact = (surveydate - bday) / 365.25
		gen int age_int = floor((surveydate - bday) / 365.25)

		recode age_* (.=0)			// 11 obs with survey dates before birth date
		
		compare age_int q0105y		// minimal differences between self-reported age and age calculated based on bday
		
		drop age_int bday
		
		rename q0105y age
		
		// drop non HH members
		drop if q0113==2
		
	
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*
*	2. Equivalence scales
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
	
		
	** Adult/Child definitions

		gen adult=age>=15
		gen child=age<15
			
		gen female=q0103==2
		
		egen agecat=cut(age), at(0 1 4 7 11 15 18 30 60 120) icode
			replace agecat=agecat+1
			replace agecat=0 if agecat==1 & q0105m<6		// split 0-6m and 7-12m
		
		gen agecat_m=agecat if female==0
		gen agecat_f=agecat if female==1
			
		tab agecat_m, gen(agecat_m)
		tab agecat_f, gen(agecat_f)
			
**# Bookmark #2. sum age_cat?
		collapse (firstnm) hhsize (sum) adult child agecat_m* agecat_f*, by(identif) 
			drop agecat_?
		
		assert adult+child==hhsize
	

	** OECD-I scale
	
		gen aesize_oecd1=0.3 + 0.7*adult + 0.5*child
		
		
	** FAO scale based on MOH calorie recommendations (by gender/age cat)
		
		mat define A=[720, 820, 1060, 1470, 1820, 2500, 2700, 2400, 2380, 1920 \ 660, 750, 980, 1330, 1650, 2170, 2280, 1990, 1850, 1680]
		
		gen double cal=0
		forval c=1/10 {
			replace cal=cal+A[1,`c']*agecat_m`c' + A[2,`c']*agecat_f`c'
		}

		gen aesize_fao=cal/2400


	** Save
	
		keep identif hhsize aesize_* adult child
		
		save "$data_temp/equivalence_scales24.dta", replace







scalar x = 3.14159

display "The value is " + string(x)



