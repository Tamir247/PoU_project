* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Food consumption
*
* PROJECT:			Food Analysis
*
* PROGRAMMER:		Undral Lkhagva (LK)
*
* DATE: 			Jan 2026
*
* DESCRIPTION:  	Prepare "Indivdual" dataset for ADePT

*
* SIMPLE PIPELINE:
*   1) Build member-level roster with demographics and status.
*   2) Construct household-head and socioeconomic indicators.
*   3) Derive labor market variables and classifications.
*   4) Save individual analysis file for downstream merges.
*

clear all
set more off


************************************************************
***                                                      ***
***                  INDIVIDUAL level         		 	 ***
***                                                      ***
************************************************************

	use "$data_raw/02_indiv", clear
		* SPREAD-DATA ADAPTATION (2026-07-03): spread release already ships
		* "identif" instead of "hses_id", and doesn't have "q0101" at all
		* (not referenced again below, safe to skip).
		capture rename hses_id identif
		capture drop q0101

		keep identif ind_id q01* q02* q03* q04*
		keep if q0113==1
		* SPREAD-DATA ADAPTATION (2026-07-03): "cluster" and "household_id"
		* don't exist in the spread release's basicvars.dta -- dropped from
		* keepusing(). household_id only ever fed the household-head export
		* used by "03 Household.do" (poverty file, itself unable to run
		* against spread data -- see 00 Master.do), so this has no
		* consequence for the active pipeline here.
		merge m:1 identif using "$data_raw/basicvars", keepus(urban region newaimag location strata hhweight hhsize month) nogen
				
		*********************************
		* identifying the household head
		*********************************
		tab q0102, m
		tab q0105y if q0102==1, m
		
	*** to select a household head ==> reported head, next wife/husband, next older
		gen head = 0
		replace head = 1 if q0102==1 & q0105y>=15
		
		label var head "Head of household"
		label val head head
		tab head, m

		***************
		* identifying the demographics vars
		**************	
		clonevar relation=q0102
		
		recode q0103 	(1=1 "Male") (2=0 "Female"), gen(sex)
		tab q0103 sex, m
		
		gen age = q0105y
		inspect age
		recode age .=0
		duplicates report identif ind_id
			
		recode age 	(0/14=1 "0-14") (15/24=2 "15-24") (25/34=3 "25-34") (35/44=6 "35-44") (45/54=7 "45-54") (55/64=8 "55-64") (65/max=13 "65+"), gen(agegroup10)
		gen hoh_age = age if head==1									
		recode hoh_age (15/29=1 "15-29") (30/39=2 "30-39") (40/49=3 "40-49") (50/59=4 "50-59") (60/max=5 "60+"), gen(hoh_agegroup10)
					
									
		**** marital status
		clonevar mstatus=q0106
		gen dmarried = inrange(q0106,2,3)

		
		*** HHsize 
		tab hhsize, m
		recode hhsize (1=1 "1") (2=2 "2")  (3=3 "3")  (4=4 "4")  (5=5 "5")  (6=6 "6")  (7=7 "7")  (8/max=8 "8<") if hhsize!=. , gen(hhsize_group1)
		
		recode hhsize (1/2=1 "Less than 3") (3/4=2 "3 or 4") (5/6=3 "5 or 6") (7/max=4 "7<") if hhsize!=. , gen(hhsize_group2)
		tab1 hhsize_group1 hhsize_group2,m
		
		************************************
		* highest completed education level
		************************************
		tab q0210, m
		recode q0210	(1=1 "None") (2=2 "Primary") (3=3 "Lower Secondary") (4=4 "Higher secondary") (5/6=5 "Vocational") (7/10=6 "University") , gen(educa)
		
		tab educa if age<6, nol
		replace educa = 1 if age<6 & educa==.
		replace educa = 1 if (age>=6 & age<11) & educa==.
		replace age = 99 if (age>=99 & age<.) 
		tab educa, m
		label var educa "Education Level"


		************************************
		* Disability
		***********************************

		tab1 q0324_1-q0324_6, m
			for var q0324_1 q0324_2 q0324_3 q0324_4 q0324_5 q0324_6:  recode X 1/2=0 5/6=0 3/4=1

		tab1 q0326_1-q0326_8, m
			for var q0326_1 q0326_2 q0326_3 q0326_4 q0326_5 q0326_6 q0326_7 q0326_8:  recode X 1/2=0 5/6=0 3/4=1

		tab1 q0328_1-q0328_6, m
			for var q0328_1 q0328_2 q0328_3 q0328_4 q0328_5 q0328_6:  recode X 1/2=0 5/6=0 3/4=1

		foreach var of varlist q0324_1 q0324_2 q0324_3 q0324_4 q0324_5 q0324_6 q0326_1 q0326_2 q0326_3 q0326_4 q0326_5 q0326_6 q0326_7 q0326_8 q0328_1 q0328_2 q0328_3 q0328_4 q0328_5 q0328_6 {
			label values `var'
			label define `var' 1 "",modify
		}

		
		egen disability_n=rsum(q0324_1 q0324_2 q0324_3 q0324_4 q0324_5 q0324_6 ///
							q0326_1 q0326_2 q0326_3 q0326_4 q0326_5 q0326_6 q0326_7 q0326_8 ///
							q0328_1 q0328_2 q0328_3 q0328_4 q0328_5 q0328_6)
		tab disability_n,m					
		recode disability_n (1/8=100 "Disabled") (.=0 "Without Disabled"), gen(disability)
		drop disability_n
		tab disability, m
		tab disability if age>=18, m
			
			
		*******************************************************************
		** Labor variables
		*******************************************************************

		gen working_age=(q0105y>=15)
		tab working_age

		*Labor main indicators
		gen eap=1 if (q0404==1 ) |  (q0408==1 & inlist(q0409, 1,2,3,9)) | ///
					( q0408==1 & inlist(q0409, 4,5,6,7, 8, 10, 11) & q0410==1) | ///
					( q0408==1 & inlist(q0409, 4,5,6,7, 8, 10, 11) & q0410==2 & q0411==1) | ///
					(q0407==1 & q0412==5) | ((q0407==1 & q0412!=5 & q0413<=2)) | ///
					((q0407==1 & q0412!=5 & q0413>=3 & q0413!=. & q0414==1 ))
		tab eap, m			
		replace eap=2 if ((q0404==2 | q0407==2) & q0415==1 & (q0419==1 | q0420==1))  | ///
						((q0404==2 | q0407==2) & q0415==2 & (q0417==3 | q0417==4 ) & (q0419==1 | q0420==1)) 
		replace eap=3 if eap==. 
		label val eap eap
		label define eap 1 "Employed" 2 "Unemployed" 3 "OutLF"
		tab eap
										
		recode eap (1=1 "Employed") (2/3=0 "Not employed"), gen(emp)
		recode eap (2=1 "Unemployed") (1=0 "Not unemployed") (3=0 "Not unemployed"), gen(unemp)
		recode eap (3=1 "Out labor Force") (1/2=0 "Not OutLF"), gen(outlf)
		tab1 eap emp unemp outlf
		
	*** Outside the Labour force ***
		gen seekingnotavai=1 if q0415==1 & (q0419==2 & q0420==2)  // seeking and not available
		gen notseekingavai=1 if q0415==2 & (q0417!=3 & q0417!=4) & (q0419==1 | q0420==1) // not seeking but available
		gen notseekingnotavaiwant=1 if q0415==2 &  (q0419==2 & q0420==2) & q0418==1 // not seeking and not available 
		gen notwillingtowork=1 if q0415==2 & q0418==2    // not willing to work
		gen notelsewherecla=1 if q0415==2 & ((q0417==4 | q0417==5) & (q0419==2 & q0420==2))

	*** PotentialLF ** *
		gen potential_lf=(seekingnotavai==1 | notseekingavai==1)
		
	*** Discouraged jobseekers***
		gen discouraged_js=1 if q0418==1 & (q0419==1 | (q0419==2 & q0420==1)) & (q0417==1 | q0417==2 )
			
	*** Labor force
		gen lfp=1 if emp==100 | unemp==100 
		replace lfp=0 if lfp==.
		
	
	*** Extended labor force
		gen extended_lf=1 if lfp==1 | potential_lf==1
		replace extended_lf=0 if extended_lf==.
				
	*** Unemployed and Potential labor force
		gen unemp_potential_lf=1 if unemp==1 | potential_lf==1
		replace unemp_potential_lf=0 if unemp_potential_lf==.

		
	*** Complete the ISIC, ISCO
		l identif ind_id q0412 q0423* q0424* q0425 if eap==1 & (q0423==. | q0423==0   | q0424==. | q0424==0 )

		
	*** rename q0425 twork 
		gen twork=1  if q0425>=1 & q0425<=4
		*
		replace twork=2 if twork==. &  q0425==6 | q0425==9 
		replace twork=2 if twork==. & q0425==12 & q0412==2 & (q0423==61 | q0423==92 ) & (q0424==114)
		replace twork=2 if twork==. & q0425==13 & q0412==2 & (q0423==61 | q0423==92 ) & (q0424==114)
		replace twork=2 if twork==. & q0412==2 & (q0423==61 | q0423==92 ) & (q0424==114)
		replace twork=. if twork==2 & q0412!=2 & (q0423!=61 & q0423!=92 ) & (q0424!=114)
		replace twork=. if twork==2 & q0412==1 & (q0423!=61 | q0423!=92 ) & (q0424==111 | q0424==112  | q0424==113)

		*
		replace twork=3 if twork==. & q0425==10 
		replace twork=3 if twork==. & q0425==7 & q0412==1 & (q0423==61 | q0423==92 ) & (q0424==111 | q0424==112  | q0424==113 )
		replace twork=3 if twork==. & q0425==12 & q0412==1 & (q0423==61 | q0423==92 ) & (q0424==111 | q0424==112  | q0424==113 )
		replace twork=3 if twork==. & q0425==13 & q0412==1 & (q0423==61 | q0423==92 ) & (q0424==111 | q0424==112  | q0424==113  )
		replace twork=3 if twork==. & q0412==1 & (q0423==61 | q0423==92 ) & (q0424==111 | q0424==112  | q0424==113)
		replace twork=. if twork==3 & q0412!=1 & q0423!=61 & q0423!=92  & q0424!=111 & q0424!=112  & q0424!=113
		* SPREAD-DATA ADAPTATION (2026-07-03): q0423a (open-text occupation
		* field, checked here for the literal text "Малчин"/"малчин" =
		* "herder") doesn't exist in the spread release -- only q0423a and
		* its siblings (q0424a/q0431a/q0432a/q0442a/q0443a) were stripped,
		* the coded q0423/q0424/etc. fields these lines otherwise depend on
		* are still present. This is a narrow exception rule refining twork
		* for a specific text-match edge case; commented out rather than
		* reworked since the source field is gone. Original:
		*   replace twork=. if twork==3 & q0425==10 & (q0423a=="Малчин" & q0423==61  & q0424==114)
		*   replace twork=. if twork==3 & q0425==10 & (q0423a=="малчин" & q0423==61  & q0424==114)
		*
		replace twork=4 if twork==. & q0425==5 | q0425==8  
		replace twork=4 if twork==. & q0425==7 & q0412>=3 & q0412<=5
		replace twork=4 if twork==. & q0425==11 & q0412>=3 & q0412<=5
		replace twork=4 if twork==. & q0425==11 & q0423!=61 & q0423!=92 & (q0424!=111 & q0424!=112  & q0424!=113 & q0424!=114 )
		replace twork=4 if twork==. & q0425==12 & q0412>=3 & q0412<=5
		replace twork=4 if twork==. & q0425==13 & q0412>=3 & q0412<=5
		replace twork=. if twork==4 & q0412!=5 & q0412!=. & ( q0423==61 | q0423==92)  & ((q0424>=111 & q0424<=114)  )


		l identif ind_id q0404 q0407 q0412 q0423 q0424 q0425 twork if eap==1 & twork==4 & (q0424>=111 & q0424<=114), nol
		l identif ind_id q0412 q0423* q0424* q0425 twork if eap==1 & twork==4 & (q0424>=111 & q0424<=114)

		tab twork 
		tab eap
		dis 18554-18641

		l identif ind_id q0404 q0407 q0412 q0423 q0424 q0425 twork if eap==1 & twork==. & q0425!=. & q0412!=., nol
		l identif ind_id q0412 q0423* q0424* q0425 twork if eap==1 &  twork==. & q0425!=. & q0412!=. & (q0423==61 | q0423==92 ) & (q0424==114)
		
		replace twork=2 if eap==1 & twork==. & q0425!=. & q0412!=. & (q0423==61 | q0423==92 ) & (q0424==114)
		replace twork=2 if eap==1 & twork==. & q0425!=. & q0412==2 & (q0423==61 | q0423==92 ) & (q0424==115)
		replace twork=3 if eap==1 & twork==. & q0425!=. & q0412==1 & (q0423==61 | q0423==92 ) & (q0424==115)
		replace twork=4 if eap==1 & twork==. & q0425!=. & q0412>=3 & q0412<=5 & q0423!=61 & q0423!=92  & q0424!=111 & q0424!=112  & q0424!=113 & q0424!=114 
		
		l identif ind_id q0412 q0423* q0424* q0425 twork if eap==1 &  twork==. & q0425!=. & q0412!=. 
		
		replace twork=3 if identif==243094203  & ind_id==2 & twork==.
		tab twork

		l identif ind_id q0404 q0407 q0408 q0412 q0423 q0424 q0425  twork if eap==1 & twork==. , nol
		
		replace twork=2 if twork==. & (q0423==61 | q0423==92 ) & (q0424==114)
		replace twork=3 if twork==. & (q0423==61 | q0423==92 ) & (q0424==111 | q0424==112  | q0424==113  )
		replace twork=4 if twork==. & q0425==7 & q0423!=61 & q0423!=92  & q0424!=111 & q0424!=112  & q0424!=113 & q0424!=114 
		replace twork=4 if twork==. & q0425==11 & q0423!=61 & q0423!=92  & q0424!=111 & q0424!=112  & q0424!=113 & q0424!=114  
		replace twork=4 if twork==. & q0425==12 & q0423!=61 & q0423!=92  & q0424!=111 & q0424!=112  & q0424!=113 & q0424!=114  
		replace twork=4 if twork==. & q0425==13 & q0423!=61 & q0423!=92  & q0424!=111 & q0424!=112  & q0424!=113 & q0424!=114 

		tab twork
		dis 18635-18641
		tab q0425 if twork==., nol

		
	*** Must check!
		l identif ind_id q0423* q0424* q0425  if eap==1 & twork==. & q0425==6
			replace twork=2 if  twork==. & q0425==6 & q0423==63 & q0424==115  
			replace twork=4 if  twork==. & q0425==6 & q0423!=61 & q0423!=92  & q0424!=111 & q0424!=112  & q0424!=113 & q0424!=114  
		
		l identif ind_id q0423* q0424* q0425  if eap==1 & twork==. & q0425==9
			replace twork=4 if  twork==. & q0425==9 & q0423!=61 & q0423!=92  & q0424!=111 & q0424!=112  & q0424!=113 & q0424!=114 
		
		l identif ind_id q0423* q0424* q0425  if eap==1 & twork==. & q0425==10
			replace twork=3 if  twork==. & q0425==10 & q0423==83 & q0424==116
			replace twork=4 if  twork==. & q0425==10 & q0423==52 & q0424==47
			replace twork=4 if  twork==. & q0425==10 & q0423==71 & q0424==43
		
		l identif ind_id q0423* q0424* q0425  if eap==1 & twork==. & q0425==11
			replace twork=4 if  twork==. & q0425==11 & q0423==61 & q0424==10
			replace twork=4 if  twork==. & q0425==11 & q0423==61 & q0424==115
			replace twork=4 if  twork==. & q0425==11 & q0423==61 & q0424==46
			replace twork=4 if  twork==. & q0425==11 & q0423==22 & q0424==114
		
		l identif ind_id q0423* q0424* q0425  if eap==1 & twork==. & q0425==12
			replace twork=4 if  twork==. & q0425==12 & q0423==96 & q0424==114
			replace twork=4 if  twork==. & q0425==12 & q0423==92 & q0424==116
			replace twork=4 if  twork==. & q0425==12 & q0423==61 & q0424==2
		
		count if eap==1 & twork==.
		tab q0425 twork
		
		l identif ind_id q0404 q0407 q0412 q0423 q0424 q0425 twork if q0425==7 & twork==2  , nol
		l identif ind_id q0404 q0407 q0412 q0423 q0424 q0425 twork if q0425==10 & twork==2  , nol
		l identif ind_id q0404 q0407 q0412 q0423 q0424 q0425 twork if q0425==11 & (twork==2 )  , nol
		l identif ind_id q0404 q0407 q0412 q0423 q0424 q0425 twork if q0425==11 & (twork==3)  , nol

	
	*** Must check
		count if twork==2 & (q0423!=61 & q0423!=92)
		l identif ind_id q0412 q0423* q0424* twork if twork==2 & (q0423!=61 & q0423!=92), nol
				
		tab q0423 if twork==2
		l identif ind_id q0412 q0423* q0424* q0425 twork if twork==2 & q0423!=61 & q0423!=62 & q0423!=63 & q0423!=92 , nol
		
		tab q0424 if twork==2
		l identif ind_id q0412 q0423* q0424* q0425 twork if twork==2 & q0424!=114 & q0424!=115 & q0424!=116 , nol
		
		replace q0424 = 15 if twork==2 & q0423==75 &  q0424==114
		replace twork = 4 if twork==2 & q0423==75 &  q0424==15
				
		
		tab q0423 if twork==3
		l identif ind_id q0412 q0423* q0424* q0425 twork if twork==3 & q0423!=61 & q0423!=62 & q0423!=63 & q0423!=92, nol
		
		tab q0424 if twork==3
		l identif ind_id q0412 q0423* q0424* twork if twork==3 & q0424!=111 & q0424!=112  & q0424!=113 & q0424!=115 & q0424!=116 , nol
		
		tab q0423 if twork==4
		l identif ind_id q0412 q0423* q0424* twork if twork==4 & ((q0423==61 | q0423==92) & (q0424>=111 & q0424<=114) ), nol
		
		tab q0424 if twork==4
		l identif ind_id q0412 q0423* q0424* twork if twork==4 & (q0424>=111 & q0424<=114) , nol
		

		label var twork "Type of work"
		label val twork twork
		label define twork 1 Wage 2 Herder 3 Farmer 4 Selfemployed
		tab twork, m
		tab twork
		

		rename q0423 occupa
		tab occupa
	*** Occupation, 10-15 groups
		codebook occupa, tab(99)
		gen occupax = floor(occupa/10) 
		tabstat occupa, by(occupax) s(min max)
		recode occupax 0=10 if eap==1
		replace occupax = . if inrange(occupa,1,99)!=1
		recode occupax .=11 if eap==1
		tab occupax
		label var occupax "Occupation 10 groups"
		label val occupax occupax
		label define occupax 1 "Managers, senior officials and legislators" 2"Professionals" ///
			3 "Technicians and associate professionals" 4 "Clerks" 5 "Service workers, shop and market salespeople" ///
			6 "Skilled agricultural and fishery workers" 7 "Craft and related trader workers" ///
			8 "Plant and machine operators" 9 "Elementary occupations" 10  "Occupation in the Armed Forces" 11 "Unspecified"
		tab occupax if eap==1, m

		rename q0424 indwage
		rename q0426 twage

		
	*** For wage jobs
		inspect indwage if twork==1

	*** For self-employed (except herders and farmers)
	*** 4-digit industry code
	
		clonevar industry99 = indwage 
		tab industry99 if twork==2
		tab industry99 if twork==2
		tab industry99 if twork==3
		tab industry99 if twork==4

		tab industry99
		*ed if industry99==. & twork!=.
		recode industry99 0 =.
		label var industry99 "Industry 2-digit code"
		inspect industry99 if inrange(twork,1,4)

		tab industry99 if inrange(twork,1,4), m
		tab twork if industry99==., m

		
	*** 3 broad groups
	
		gen industry3=industry99
		recode industry3 (111/117=1) (2/3=1) (5/43=2)  (45/99=3)
		recode industry3 .=9 if twork~=. & industry3==.
		label var industry3 "Industry 3 groups"
		label val industry3 industry3
		label define industry3 1 Agriculture 2 Industry 3 Services 9 Unknown
		tab industry3, m
		tab twork if industry3==., m

		
		
	*** Industry, 10-15 groups
		tab industry99
		gen industry21 = industry99
		recode industry21 (111/117=1) (2/3=1) (5/9=2) (10/33=3) (35/39=4) (41/43=5) (45/47=6) ///
			(49/53=8) (55/56=7) (64/68 =9) (58/63 69/75 77/82=13) ///
			(84=10) (85=11) (86/88=12) (90/99=13) 
		tab industry21 if eap==1 
		recode industry21 (999/8324=15) (.=99)
		label var industry21 "Industry 10-15 groups"
		label val industry21 industry21
		label define industry21 1 "Agriculture" 2 "Mining" 3 "Manufacturing" 4 "Electricity/water" 5 "Construction" ///
			6 "Trade" 7 "Hotels, restaurants, tourism" 8 "Transportation"  9 "Financial, insurance, real estate" ///
			10 "Public administration" 11 "Education" 12 "Health" 13 "Other" 99 "Unspecified"
		tab industry21 if eap==1 , m

		
	*** Industry
		tab industry3 eap, m
		recode industry3 .=9 if twork==. & eap==1
		tab industry3 eap, m

		
	*** Sector 
		tab twage twork 

		gen sector = .
		replace sector = 1 if eap==1 & twork==2
		replace sector = 2 if eap==1 & inlist(twork,3,4)
		replace sector = 2 if eap==1 & twork==1 & inlist(twage,6, 7, 5, 4)
		replace sector = 3 if eap==1 & twork==1 & inlist(twage,3)
		replace sector = 4 if eap==1 & twork==1 & inlist(twage,1,2)
		*replace sector = 5 if eap==1 & twork==1 & inlist(twage,8,9)
		tab twork sector

		tab sector if eap==1, m
		tab industry99 if sector==.
		tab twage if sector==.

		replace sector = 1 if sector==. & eap==1 & twork==1 & (occupa==61 | occupa==92 ) & (indwage==114)
		replace sector = 2 if sector==. & eap==1 & twork==1 & (occupa==61 | occupa==92 ) & (indwage>=111 &indwage>=113)
		replace sector = 3 if sector==. & eap==1 & twork==1 & (indwage==84)
		replace sector = 2 if sector==. & eap==1 & twork==1 & inlist(twage,8,9)
		replace sector = 5 if sector==. & eap==1 
		replace sector = 6 if eap==2
		replace sector = 7 if eap==3 
		replace sector = 9 if eap==9

		label var sector "Sector of occupation"
		label val sector sector
		label define sector 1 Herders 2 Private 3 Public 4 State 5 EmpUnknown 6 Unemployed 7 OutLF 9 Unknown
		tab sector, m
		tab sector if head==1, m

		
	*** Sector2 
		recode sector (1/2=1 "Private") (3=2 "Public") (4=3 "State") (5=4 "Unspecified") (6/7=.), gen(sector22)
		label var sector22 "Private/public/state"   // variable is sector22, not sector2
		tab sector22, m
	
		
	*** Labour force participation and industry
	
		gen eap_ind = .
		replace eap_ind = industry3
		replace eap_ind = 22 if eap==2
		replace eap_ind = 33 if eap==3
		replace eap_ind = 99 if eap==9
		label var eap_ind "Labour force and industry"
		label val eap_ind eap_ind
		label define eap_ind 1 Agriculture 2 Industry 3 Services 9 EmpUnknown 22 Unemployed 33 OutLF 99 Unknown
		tab eap_ind, m
		count

	
		
	*** wage  ** ÑÐ°Ñ€Ñ‹Ð½ Ñ†Ð°Ð»Ð¸Ð½Ð³ Ð·Ó©Ð²Ñ…Ó©Ð½ Ò¯Ð½Ð´ÑÑÐ½ Ð°Ð¶Ð»Ñ‹Ð½ Ñ†Ð°Ð»Ð¸Ð½Ð³Ð°Ð°Ñ€ Ð°Ð²Ð°Ð²
		egen inc_tot_wage=rsum(q0436a )
		egen inc_tot_12=rsum(q0436b)
					replace inc_tot_wage=inc_tot_12/12 if (inc_tot_wage==0 & inc_tot_12~=0)
		egen inc_tot_12_bonus=rsum(q0436b q0436c)
			summ inc_tot_wage inc_tot_12 inc_tot_12_bonus

		drop seekingnotavai notseekingavai notseekingnotavaiwant notwillingtowork notelsewherecla discouraged_js indwage twage working_age inc_tot_12

		drop  q01*  q02* q03* q04* 
		
		* SPREAD-DATA ADAPTATION (2026-07-03): "cluster" and "household_id"
		* dropped from this order/keep list -- neither exists in the spread
		* release (see note at the top of this file).
		order identif ind_id newaimag urban region location strata relation head hoh_age hoh_agegroup10  sex age agegroup10 mstatus dmarried hhsize hhsize_group1 hhsize_group2 disability educa ///
				eap emp unemp outlf potential_lf lfp extended_lf unemp_potential_lf twork eap_ind industry3 industry21 industry99 sector sector22  occupax occupa inc_tot_wage inc_tot_12_bonus  month hhweight
			// note: inc_tot_12 (annual wage) was dropped earlier; inc_tot_12_bonus kept
		
		label var ind_id "Individual ID"
		label var newaimag "Aimag"
		label var relation "Relation with HH head"
		label var hoh_age "HH head age"
		label var hoh_agegroup10 "HH head: Age group 10"
		label var sex "Sex"
		label var age "Age"
		label var agegroup10 "Age group 10"
		label var mstatus "Marital_status"
		label var dmarried "Dummy for Married"
		label var hhsize_group1 "Household size 8 groups"
		label var hhsize_group2 "Household size 4 groups"
		label var disability "Dummy for disability"
		label var eap "Employment status" 
		label var emp  "Employed"
		label var unemp "Unemployed"
		label var outlf "Out of labor force"
		label var potential_lf "Potential labor force"
		label var lfp "Dummy for labor force participation"
		label var extended_lf "Dummy for  extended labor force participation"
		label var unemp_potential_lf "Dummy for unemp & potential labor force"
		label var inc_tot_wage  "Monthly salary"
		label var inc_tot_12_bonus  "Annual bonus"
	
		sum
		sort identif ind_id	
		
	 save "$data_temp/temp_indiv_${survey_year}.dta", replace

*************************
** Household Head data
**************************
		use "$data_temp/temp_indiv_${survey_year}.dta", clear

		tab head 
		tab sex
		tab age
		tab occupax 
		tab eap 
		tab educa
		
		keep if head==1	
		
		rename sex hhead_gender
		rename educa hhead_edu
		rename occupax hhead_occupa
		rename hoh_agegroup10 hhead_age_gp
		rename industry3 hhead_eact
		
		label var hhead_gender "Household head's sex"
		label var hhead_edu   "Household head's education"
		label var hhead_occupa "Household head's occupation"
		label var hhead_age_gp   "Household head's age group"
		label var hhead_eact   "Household head's economic active"
		
		* SPREAD-DATA ADAPTATION (2026-07-03): "household_id" dropped -- see
		* note near the top of this file. This file (temp_hhead) is only
		* consumed by "03 Household.do", which can't run against the spread
		* release regardless (see 00 Master.do), so this has no downstream
		* consequence here.
		keep identif head hhsize_group2 hhead_occupa hhead_edu hhead_age_gp hhead_gender hhead_eact
		sort identif
		save "$data_temp/temp_hhead_${survey_year}", replace


*************************************
*** To Prepare Individual dataset for Adept
*************************************
	use "$data_temp/temp_indiv_${survey_year}.dta", clear

		rename relation hm_relation
		rename dmarried hm_marital
		rename age hm_age
		rename sex hm_sex
		rename educa hm_educa
		rename eap hm_eact
		rename occupax hm_occupa

		bys identif: egen hm_nochild0_17=total(age<18)
		bys identif: egen hm_nochild0_5=total(age<6)

		label var hm_nochild0_17 "No. of children aged 0-17"
		label var hm_nochild0_5 "No. of children aged 0-5"
		
		keep identif ind_id hm_relation hm_sex  hm_age hm_marital hm_eact hm_occupa hm_educa hm_nochild0_17 hm_nochild0_5 
		order identif ind_id hm_relation hm_sex  hm_age hm_marital hm_eact hm_occupa hm_educa hm_nochild0_17 hm_nochild0_5  
		sort identif ind_id
		merge 1:1 identif ind_id using "$data_out/Height_Sattar", keepus(age_class height) nogen

		label var age_class "Age group by gender "
		label var height "Height for age group&gender"
		
sort identif ind_id
saveold "$data_out/indivdual_${survey_year}", version(12) replace

