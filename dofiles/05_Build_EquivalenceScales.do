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


	use "$data_raw/01_hhold.dta", clear
	* SPREAD-DATA ADAPTATION (2026-07-03): full HSES releases key on "hses_id";
	* the de-identified "spread" 2024 release already ships this column as
	* "identif" -- guard the rename so this file runs unmodified against
	* either source instead of erroring on a missing "hses_id".
	capture rename hses_id identif
		* PIPELINE REORG (2026-07-05): repointed from "$data_raw/basicvars.dta"
		* (raw input) to "01_Import_BasicVars.do"'s passthrough output -- see
		* that file's header comment. Same columns (keepusing list unchanged),
		* no logic change.
		merge 1:1 identif using "$data_temp/basicvars_${survey_year}.dta", keepusing(month hhsize) nogen
		sort identif
		
	** Clean interview dates

		// raw v#_yy fields are recorded as 2-digit years (e.g. 24), unlike the
		// 4-digit "survey_year" global -- derive the 2-digit form here so
		// nothing below hardcodes either "24" or "2024" directly. This makes
		// the file work unchanged for a future round (e.g. survey_year=2025).
		local yy2 = mod(${survey_year}, 100)

		// first visit. must be within possible date
		gen check1=1 if v1_yy != `yy2' | v1_mm>12 // өдөр байхгүй?

		// second visit. must be within possible date
		gen check2=1 if (v2_yy != `yy2') | (v2_mm>12) | (v2_dd>31)
			replace check2=. if (v2_dd==. & v2_mm==. & v2_yy==.) | v2_res==.

		// third visit
		gen check3=1 if v3_yy!=`yy2' | v3_mm>12 | v3_dd>31
			replace check3=. if (v3_dd==. & v3_mm==. & v3_yy==.) | v3_res==.

		* SPREAD-DATA ADAPTATION (2026-07-03): "cluster" (survey PSU) doesn't
		* exist in the de-identified "spread" release. While adapting this
		* file to run without it, found the code below was never actually
		* using it anyway: mcheck1/mcheck2/mcheck3 were computed grouped by
		* cluster, but the repair block a few lines down uses check1/2/3
		* directly (never mcheck1/2/3), and mcheck?/check? are dropped
		* together right after -- so this was dead code even before "cluster"
		* went away. Removed outright rather than reworked. Original, for
		* reference:
		*   bys cluster: egen mcheck1=max(check1)
		*   bys cluster: egen mcheck2=max(check2)
		*   bys cluster: egen mcheck3=max(check3)

**# Bookmark #1
		// looks like month entered in year and day entered in month --> replace
		forval x=1/3 {
			replace v`x'_dd=v`x'_mm if check`x'==1
			replace v`x'_mm=v`x'_yy if check`x'==1
			replace v`x'_yy=`yy2' if check`x'==1
		} // ??

		drop check?


		gen double surveydate=mdy(v1_mm,v1_dd,${survey_year}) if inlist(v1_res,1,2)
			replace surveydate=mdy(v2_mm,v2_dd,${survey_year}) if inlist(v2_res,1,2) & surveydate==.
			replace surveydate=mdy(v3_mm,v3_dd,${survey_year}) if surveydate==.
			replace surveydate=mdy(v2_mm,v2_dd,${survey_year}) if surveydate==.
			format surveydate %td

		keep identif surveydate hhsize

		// Судалгааны онд яг таарч буйг шалгаж байна.
		// Үгүй бол алдаа гарсан буюу судалгааны оноос гажсан өөр судалгаанууд байна гэсэн үг.
		assert inrange(surveydate, ///
				date("01jan" + string(${survey_year}), "DMY"), /// Оны эхэн
				date("31dec" + string(${survey_year}), "DMY")) /// Оны төгсгөл
			
		tempfile d 
		save `d', replace
		
		
	// age based on birthdate 
	
	use "$data_raw/02_indiv.dta", clear
	* SPREAD-DATA ADAPTATION (2026-07-03): see the matching note above for
	* "hses_id" -> "identif".
	capture rename hses_id identif
		merge m:1 identif using `d', nogen

		* SPREAD-DATA ADAPTATION (2026-07-03): q0104y/q0104m/q0104d (exact
		* birthdate) are stripped from the de-identified "spread" release, so
		* the block below can't run against it. That turns out not to cost
		* anything real: age_exact/age_int (computed from birthdate) were
		* only ever used for a diagnostic `compare` against q0105y, then
		* dropped -- every actual classification below (adult/child, agecat)
		* uses q0105y (self-reported whole-number age) via `rename q0105y
		* age`, never age_exact/age_int. Verified earlier by direct
		* comparison: the two age measures disagree for ~3.7% of
		* individuals, and ~0.53% (284 people) land in a different age
		* bracket depending on which is used -- worth knowing if DEC/MDER
		* numbers ever look slightly off, but not something this file's
		* output currently depends on. Commented out rather than reworked,
		* since it can't run without the birthdate fields regardless.
		* Original, for reference:
		*   gen double bday=mdy(q0104m, q0104d, q0104y)
		*   	format bday %td
		*   describe bday surveydate
		*   gen double age_exact = (surveydate - bday) / 365.25
		*   gen int age_int = floor((surveydate - bday) / 365.25)
		*   recode age_* (.=0)
		*   compare age_int q0105y
		*   drop age_int bday

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
		
		save "$data_temp/equivalence_scales${survey_year}.dta", replace

