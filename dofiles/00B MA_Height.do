* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			MDER & ADER
*
* PROJECT:			Food Analysis
*
* PROGRAMMER:		Undral Lkhagva (LK)
*
* DATE: 			Jan 2026
*
* DESCRIPTION:  	Prepare "HEIGHT" dataset for ADePT

*
* SIMPLE PIPELINE:
*   1) Prepare individual roster for members only.
*   2) Build age-sex classes used by FAO requirement formulas.
*   3) Attach/prepare height references by class.
*   4) Save height-ready individual file for DER estimation.
*


*** Myagmarkhandaas height awch ashiglah



   *********************** Satter-iin datanii height ashiglaw ********************
	use "$data_raw/02_indiv", clear
	* SPREAD-DATA ADAPTATION (2026-07-03): the de-identified "spread" release
	* already ships "identif" instead of "hses_id" -- guard so this runs
	* against either source. Renamed here (rather than at the original
	* location, the end of the file) so "identif" can be kept below instead
	* of "hses_id".
	capture rename hses_id identif
	keep if q0113==1
	rename (q0103 q0105y) (gender age)

	*keep identif ind_id urban region age gender q0102 q0106 hhweight
	keep identif ind_id age gender q0102 q0106

	gen age_class = 0

	* CODE CLEANUP (2026-07-05): the 62 "replace age_class=N if ..." lines and
	* 62 "label define age_class N ..., add" lines used to be two separate
	* ~60-line blocks (all values, then all labels). Consolidated to one row
	* per age class -- value assignment and its label together, separated by
	* ";" -- using "#delimit ;" so a row can hold two commands. Same cutoffs,
	* same numbering, same labels as before, just easier to scan/verify one
	* class at a time. "#delimit cr" below restores the normal one-line-per-
	* command mode so the rest of the do-file is unaffected.
	#delimit ;
	replace age_class = 1  if gender==1 & age <1                   ; label define age_class 1  "Male:<1", add ;
	replace age_class = 2  if gender==1 & age >=1 & age <2         ; label define age_class 2  "Male:1-2", add ;
	replace age_class = 3  if gender==1 & age >=2 & age <3         ; label define age_class 3  "Male:2-3", add ;
	replace age_class = 4  if gender==1 & age >=3 & age <4         ; label define age_class 4  "Male:3-4", add ;
	replace age_class = 5  if gender==1 & age >=4 & age <5         ; label define age_class 5  "Male:4-5", add ;
	replace age_class = 6  if gender==1 & age >=5 & age <6         ; label define age_class 6  "Male:5-6", add ;
	replace age_class = 7  if gender==1 & age >=6 & age <7         ; label define age_class 7  "Male:6-7", add ;
	replace age_class = 8  if gender==1 & age >=7 & age <8         ; label define age_class 8  "Male:7-8", add ;
	replace age_class = 9  if gender==1 & age >=8 & age <9         ; label define age_class 9  "Male:8-9", add ;
	replace age_class = 10 if gender==1 & age >=9 & age <10        ; label define age_class 10 "Male:9-10", add ;
	replace age_class = 11 if gender==1 & age >=10 & age <11       ; label define age_class 11 "Male:10-11", add ;
	replace age_class = 12 if gender==1 & age >=11 & age <12       ; label define age_class 12 "Male:11-12", add ;
	replace age_class = 13 if gender==1 & age >=12 & age <13       ; label define age_class 13 "Male:12-13", add ;
	replace age_class = 14 if gender==1 & age >=13 & age <14       ; label define age_class 14 "Male:13-14", add ;
	replace age_class = 15 if gender==1 & age >=14 & age <15       ; label define age_class 15 "Male:14-15", add ;
	replace age_class = 16 if gender==1 & age >=15 & age <16       ; label define age_class 16 "Male:15-16", add ;
	replace age_class = 17 if gender==1 & age >=16 & age <17       ; label define age_class 17 "Male:16-17", add ;
	replace age_class = 18 if gender==1 & age >=17 & age <18       ; label define age_class 18 "Male:17-18", add ;
	replace age_class = 19 if gender==1 & age >=18 & age <19       ; label define age_class 19 "Male:18-19", add ;
	replace age_class = 20 if gender==1 & age >=19 & age <20       ; label define age_class 20 "Male:19-20", add ;
	replace age_class = 21 if gender==1 & age >=20 & age <25       ; label define age_class 21 "Male:20-25", add ;
	replace age_class = 22 if gender==1 & age >=25 & age <30       ; label define age_class 22 "Male:25-30", add ;
	replace age_class = 23 if gender==1 & age >=30 & age <35       ; label define age_class 23 "Male:30-35", add ;
	replace age_class = 24 if gender==1 & age >=35 & age <40       ; label define age_class 24 "Male:35-40", add ;
	replace age_class = 25 if gender==1 & age >=40 & age <45       ; label define age_class 25 "Male:40-45", add ;
	replace age_class = 26 if gender==1 & age >=45 & age <50       ; label define age_class 26 "Male:45-50", add ;
	replace age_class = 27 if gender==1 & age >=50 & age <55       ; label define age_class 27 "Male:50-55", add ;
	replace age_class = 28 if gender==1 & age >=55 & age <60       ; label define age_class 28 "Male:55-60", add ;
	replace age_class = 29 if gender==1 & age >=60 & age <65       ; label define age_class 29 "Male:60-65", add ;
	replace age_class = 30 if gender==1 & age >=65 & age <70       ; label define age_class 30 "Male:65-70", add ;
	replace age_class = 31 if gender==1 & age >=70                 ; label define age_class 31 "Male:>70", add ;

	replace age_class = 32 if gender==2 & age <1                   ; label define age_class 32 "Female:<1", add ;
	replace age_class = 33 if gender==2 & age >=1 & age <2         ; label define age_class 33 "Female:1-2", add ;
	replace age_class = 34 if gender==2 & age >=2 & age <3         ; label define age_class 34 "Female:2-3", add ;
	replace age_class = 35 if gender==2 & age >=3 & age <4         ; label define age_class 35 "Female:3-4", add ;
	replace age_class = 36 if gender==2 & age >=4 & age <5         ; label define age_class 36 "Female:4-5", add ;
	replace age_class = 37 if gender==2 & age >=5 & age <6         ; label define age_class 37 "Female:5-6", add ;
	replace age_class = 38 if gender==2 & age >=6 & age <7         ; label define age_class 38 "Female:6-7", add ;
	replace age_class = 39 if gender==2 & age >=7 & age <8         ; label define age_class 39 "Female:7-8", add ;
	replace age_class = 40 if gender==2 & age >=8 & age <9         ; label define age_class 40 "Female:8-9", add ;
	replace age_class = 41 if gender==2 & age >=9 & age <10        ; label define age_class 41 "Female:9-10", add ;
	replace age_class = 42 if gender==2 & age >=10 & age <11       ; label define age_class 42 "Female:10-11", add ;
	replace age_class = 43 if gender==2 & age >=11 & age <12       ; label define age_class 43 "Female:11-12", add ;
	replace age_class = 44 if gender==2 & age >=12 & age <13       ; label define age_class 44 "Female:12-13", add ;
	replace age_class = 45 if gender==2 & age >=13 & age <14       ; label define age_class 45 "Female:13-14", add ;
	replace age_class = 46 if gender==2 & age >=14 & age <15       ; label define age_class 46 "Female:14-15", add ;
	replace age_class = 47 if gender==2 & age >=15 & age <16       ; label define age_class 47 "Female:15-16", add ;
	replace age_class = 48 if gender==2 & age >=16 & age <17       ; label define age_class 48 "Female:16-17", add ;
	replace age_class = 49 if gender==2 & age >=17 & age <18       ; label define age_class 49 "Female:17-18", add ;
	replace age_class = 50 if gender==2 & age >=18 & age <19       ; label define age_class 50 "Female:18-19", add ;
	replace age_class = 51 if gender==2 & age >=19 & age <20       ; label define age_class 51 "Female:19-20", add ;
	replace age_class = 52 if gender==2 & age >=20 & age <25       ; label define age_class 52 "Female:20-25", add ;
	replace age_class = 53 if gender==2 & age >=25 & age <30       ; label define age_class 53 "Female:25-30", add ;
	replace age_class = 54 if gender==2 & age >=30 & age <35       ; label define age_class 54 "Female:30-35", add ;
	replace age_class = 55 if gender==2 & age >=35 & age <40       ; label define age_class 55 "Female:35-40", add ;
	replace age_class = 56 if gender==2 & age >=40 & age <45       ; label define age_class 56 "Female:40-45", add ;
	replace age_class = 57 if gender==2 & age >=45 & age <50       ; label define age_class 57 "Female:45-50", add ;
	replace age_class = 58 if gender==2 & age >=50 & age <55       ; label define age_class 58 "Female:50-55", add ;
	replace age_class = 59 if gender==2 & age >=55 & age <60       ; label define age_class 59 "Female:55-60", add ;
	replace age_class = 60 if gender==2 & age >=60 & age <65       ; label define age_class 60 "Female:60-65", add ;
	replace age_class = 61 if gender==2 & age >=65 & age <70       ; label define age_class 61 "Female:65-70", add ;
	replace age_class = 62 if gender==2 & age >=70                 ; label define age_class 62 "Female:>70", add ;
	#delimit cr

	tab age_class, m

		label val age_class age_class

		***join height information by age_class 
	*** nasnii angilal tus bureer Height bgaa datatai holboh shaardlagatai 
	*** Hyatadiin hunii medeellig ashiglej Mongol hunii unduriig tootsoj data uuzgesen
	*** Niigmiin eruul mendiin hureelgees medeellig awch ashiglah mun SISS-iin datanaas 0-5 hurtel nasiig ni awch ashiglah

	sort age_class

// 	joinby age_class using "$dbase/height_Mongolia_2018", unmatched(both) // full join
	merge m:1 age_class using "$data_raw/height_Mongolia_2018"
		tab _m
		drop _merge
		
	sort identif ind_id
	save "$data_out/Height_Sattar", replace 
