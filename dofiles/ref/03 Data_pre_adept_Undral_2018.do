clear all
set more off



* Crude birth rate 24.5=0.0245

cd $workdata_other

**************************** Household *****************************************************************************
**************************** Household *****************************************************************************
**************************** Household *****************************************************************************
use "$data_raw22/basicvars.dta", clear

keep identif cluster region urban location hhweight hhsize month quarter
order identif cluster region urban hhsize location hhweight month quarter

gen year=2022

sort identif 

preserve 
		use "$data_raw22\workdata\profile\agg_indiv_2022.dta", clear
		keep if q0109==1
		drop hhsize
		egen hhsize = sum(q0109==1), by(identif)
        *compare hhsize hhsizes
		bysort identif: gen hhsize_group4=(hhsize<3)
		replace hhsize_group4=2 if hhsize==3 | hhsize==4
		replace hhsize_group4=3 if hhsize==5 | hhsize==6
		replace hhsize_group4=4 if hhsize>6
		tab hhsize_group4, m
		label val hhsize_group4 hhsize_group4
		label define hhsize_group4 1 " Less than 3" 2 " 3 or 4" 3 "5 or 6" 4 "More than 6" 
		label var hhsize_group4 "Grouping for household size"

		* occupation, 10-15 groups
		 ** use occupax
		
		*education 
		** use educa
		
		
		** age group
		gen age3 = 1 + irecode(age,29,39,49,59)
		label var age3 "Household head's age, 5 cohorts"
		label val age3 age3
		label define age3 1 "<30" 2 "30-39" 3 "40-49" 4 "50-59" 5 "60+"
		tab age3, m
		
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
		rename age3 hhead_age_gp
		rename industry3 hhead_eact
		
		label var hhead_gender "Household head's sex"
		label var hhead_edu   "Household head's education"
		label var hhead_occupa "Household head's occupation"
		label var hhead_age_gp   "Household head's age group"
		label var hhead_eact   "Household head's economic active"
		
		keep identif household_id head hhsize_group hhead_occupa hhead_edu hhead_age_gp hhead_gender hhead_eact 
		sort identif 
		tempfile hhead
		save `hhead', replace
restore 

rename identif household_id
merge 1:1 household_id using `hhead', nogen
rename household_id hses_id 
*rename identif hses_id
sort hses_id
merge hses_id using "$data_raw22/01_hhold", keep(visitor ndays)
tab _
drop _m
label var visitor "Number of food partakers"
label var ndays   "Number of day/food partakers"
*rename hses_id identif 

order identif hses_id


kkk 
sort identif
merge identif using "$data2018/workdata\poverty", keep(poorlNSO pcexpm pcfood pcfoodout pcfood1-pcfood12 )
tab _
drop _m

label val poorlNSO poorlNSO
label define poorlNSO 0 "Non-poor" 100 "Poor" 

sort identif
merge identif using "$data2018/workdata\all_inc_exp", keep(total_inc money_inc)
tab _
drop _m

sort identif
merge identif using "$data2018/workdata/foodpaasche", keep(paasche)
tab _
drop _m
rename paasche foodpaasche
label var foodpaasche "Normalized Paasche food index by cluster"

sort identif
merge identif using "$data2018/workdata\consumption", keep(paasche)
tab _
drop _m


preserve 
	collapse (mean) pcexpm, by(identif)
	xtile decile=pcexpm, nq(10)

	save decile, replace
restore 

replace pcexpm=pcexpm*paasche

gen hhexpday=(pcexpm*hhsize)/(365/12)
gen hhincday=total_inc/(365/12)
label var hhexpday "Household total consumption per day"
label var hhincday "Household total income per day"

tab foodpaasche

egen pcfood1_12=rsum(pcfood1-pcfood12)
egen pcfoodnew=rsum(pcfood1_12 pcfoodout)
compare pcfood pcfoodnew

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

tab urban if pcfood==0

keep identif cluster region urban hhsize location month quarter year hhsize_group hhsize_group hhead* visitor ///
	 pcfoodout pcfood pcexpm poorlNSO total_inc foodpaasche paasche hhweight_adj hhexpday hhincday

sort identif
	 
saveold household_2018, version(12) replace


stop stop stop

**************************** ********* *****************************************************************************
**************************** Indivdual *****************************************************************************
**************************** ********* *****************************************************************************
use "D:\HSES_result_2018\HSES_2018\workdata\Indivdual_demo_2018.dta", clear

keep if q0109==1

rename identif hses_id
* dropped no food cons hhs 
drop if hses_id==181050209 | hses_id==182040304	| hses_id==182050307 |hses_id==183047501 | hses_id==183047504 | hses_id==183047806	| hses_id==183047810 | 	hses_id==183047811 | hses_id==183048011 | ///
	hses_id==184047003 | hses_id==184047008	| hses_id==184047009 |	hses_id==184047106	| hses_id==184047107 |	hses_id==184047112 | hses_id==184048101 |	hses_id==184048102	| hses_id==184048103 |	///
	hses_id==184048104	| hses_id==184048105 |	hses_id==184048109

rename  hses_id identif

drop newaimag newsoum bag location urban region month hhweight q0101 q0103 q0104* q0105* q0107 q0108* q0109 q02* q03* q04*


tab sex, m
gen age3 = 1 + irecode(age,29,39,49,59)
label var age3 "Household head's age, 5 cohorts"
label val age3 age3
label define age3 1 "<30" 2 "30-39" 3 "40-49" 4 "50-59" 5 "60+"
tab age3, m

tab educa, nol
recode educa	(1=1 "None") (2=2 "Primary") (3=3 "Lower Secondary") (4=4 "Higher secondary") (5/6=5 "Vocational") (7/10=6 "University") , gen(hm_educa)

* occupation, 10-15 groups
gen occupax = floor(occupa/100)
tabstat occupa, by(occupax) s(min max)
replace occupax = . if inrange(occupa,100,999)!=1
recode occupax .=10 if eap==1
tab occupax
label var occupax "Occupation 9 groups"
label val occupax occupax
label define occupax 1 "Managers, senior officials and legislators" 2"Professionals" ///
	3 "Technicians and associate professionals" 4 "Clerks" 5 "Service workers, shop and market salespeople" ///
	6 "Skilled agricultural and fishery workers" 7 "Craft and related trader workers" ///
	8 "Plant and machine operators" 9 "Elementary occupations" 10 "Unspecified"
tab occupax if eap==1,  m

*bys identif: egen hm_n_u18=total(age<18)

egen hm_n_u18=total(age<18), by(identif)
tab hm_n_u18, m
gen hm_no_u18=(hm_n_u18==0)
tab hm_no_u18, m
gen hm_with_u18=(hm_n_u18>0)
tab hm_with_u18, m

bys identif: egen hm_n_u5=total(age<5)
gen hm_no_u5=(hm_n_u5==0)
gen hm_with_u5=(hm_n_u5>0)
tab hm_with_u5, m


rename q0102 hm_relation
rename q0106 hm_marital
rename age hm_age
rename sex hm_sex
rename eap hm_eact
rename occupax hm_occupa

label var hm_relation "Relation"
label var hm_marital "Marital_status"

keep identif ind_id hm_relation hm_sex  hm_age hm_marital hm_eact hm_occupa hm_educa hm_no_u18 hm_with_u18 hm_no_u5 hm_with_u5 
order identif ind_id hm_relation hm_sex  hm_age hm_marital hm_eact hm_occupa hm_educa hm_no_u18 hm_with_u18 hm_no_u5 hm_with_u5

count

preserve
   *********************** Satter-iin datanii height ashiglaw ********************
	use "$data2018/02_indiv", clear
	keep if q0109==1
	rename (q0103 q0105y) (gender age)
	
	*keep hses_id ind_id urban region age gender q0102 q0106 hhweight
	keep hses_id ind_id age gender q0102 q0106 

	gen age_class = 0
	replace age_class = 1 if gender==1 & age <1
	replace age_class = 2 if gender==1 & age >=1 & age <2
	replace age_class = 3 if gender==1 & age >=2 & age <3
	replace age_class = 4 if gender==1 & age >=3 & age <4
	replace age_class = 5 if gender==1 & age >=4 & age <5
	replace age_class = 6 if gender==1 & age >=5 & age <6
	replace age_class = 7 if gender==1 & age >=6 & age <7
	replace age_class = 8 if gender==1 & age >=7 & age <8
	replace age_class = 9 if gender==1 & age >=8 & age <9
	replace age_class = 10 if gender==1 & age >=9 & age <10
	replace age_class = 11 if gender==1 & age >=10 & age <11
	replace age_class = 12 if gender==1 & age >=11 & age <12
	replace age_class = 13 if gender==1 & age >=12 & age <13
	replace age_class = 14 if gender==1 & age >=13 & age <14
	replace age_class = 15 if gender==1 & age >=14 & age <15
	replace age_class = 16 if gender==1 & age >=15 & age <16
	replace age_class = 17 if gender==1 & age >=16 & age <17
	replace age_class = 18 if gender==1 & age >=17 & age <18
	replace age_class = 19 if gender==1 & age >=18 & age <19
	replace age_class = 20 if gender==1 & age >=19 & age <20
	replace age_class = 21 if gender==1 & age >=20 & age <25
	replace age_class = 22 if gender==1 & age >=25 & age <30
	replace age_class = 23 if gender==1 & age >=30 & age <35
	replace age_class = 24 if gender==1 & age >=35 & age <40
	replace age_class = 25 if gender==1 & age >=40 & age <45
	replace age_class = 26 if gender==1 & age >=45 & age <50
	replace age_class = 27 if gender==1 & age >=50 & age <55
	replace age_class = 28 if gender==1 & age >=55 & age <60
	replace age_class = 29 if gender==1 & age >=60 & age <65
	replace age_class = 30 if gender==1 & age >=65 & age <70
	replace age_class = 31 if gender==1 & age >=70
	replace age_class = 32 if gender==2 & age <1
	replace age_class = 33 if gender==2 & age >=1 & age <2
	replace age_class = 34 if gender==2 & age >=2 & age <3
	replace age_class = 35 if gender==2 & age >=3 & age <4
	replace age_class = 36 if gender==2 & age >=4 & age <5
	replace age_class = 37 if gender==2 & age >=5 & age <6
	replace age_class = 38 if gender==2 & age >=6 & age <7
	replace age_class = 39 if gender==2 & age >=7 & age <8
	replace age_class = 40 if gender==2 & age >=8 & age <9
	replace age_class = 41 if gender==2 & age >=9 & age <10
	replace age_class = 42 if gender==2 & age >=10 & age <11
	replace age_class = 43 if gender==2 & age >=11 & age <12
	replace age_class = 44 if gender==2 & age >=12 & age <13
	replace age_class = 45 if gender==2 & age >=13 & age <14
	replace age_class = 46 if gender==2 & age >=14 & age <15
	replace age_class = 47 if gender==2 & age >=15 & age <16
	replace age_class = 48 if gender==2 & age >=16 & age <17
	replace age_class = 49 if gender==2 & age >=17 & age <18
	replace age_class = 50 if gender==2 & age >=18 & age <19
	replace age_class = 51 if gender==2 & age >=19 & age <20
	replace age_class = 52 if gender==2 & age >=20 & age <25
	replace age_class = 53 if gender==2 & age >=25 & age <30
	replace age_class = 54 if gender==2 & age >=30 & age <35
	replace age_class = 55 if gender==2 & age >=35 & age <40
	replace age_class = 56 if gender==2 & age >=40 & age <45
	replace age_class = 57 if gender==2 & age >=45 & age <50
	replace age_class = 58 if gender==2 & age >=50 & age <55
	replace age_class = 59 if gender==2 & age >=55 & age <60
	replace age_class = 60 if gender==2 & age >=60 & age <65
	replace age_class = 61 if gender==2 & age >=65 & age <70
	replace age_class = 62 if gender==2 & age >=70
	tab age_class, m

	***join height information by age_class 
	*** nasnii angilal tus bureer Height bgaa datatai holboh shaardlagatai 
	*** Hyatadiin hunii medeellig ashiglej Mongol hunii unduriig tootsoj data uuzgesen
	*** Niigmiin eruul mendiin hureelgees medeellig awch ashiglah mun SISS-iin datanaas 0-5 hurtel nasiig ni awch ashiglah

	sort age_class

	joinby age_class using "D:\18.FAO\PoU_Training_4-8_NOV_2019\POU data/height_Mongolia_2018", unm(b)
	tab _m
	drop _merge
	rename hses_id identif 
	sort identif ind_id
	tempfile Height_Sattar
	save `Height_Sattar', replace 
restore

sort identif ind_id
merge 1:1 identif ind_id using `Height_Sattar', keepus(height)
tab _m
drop if _m!=3
drop _m

sort identif ind_id
saveold indivdual_2018, version(12) replace


***********************************************************
**********************  FOOD  *****************************
***********************************************************
*tempfood data bol udriin heregleeg oruulsan bgaa
use "$data2018/workdata\tempfood", clear
/*
gen out=0
foreach n of numlist 10114 10115 10216 10217 10304 10410 10415 10508 10604 10608 10609 10713 10714 10806 10913 ///
	11008 11106 11204 11306 11405 {
	replace out=1 if itemcode==`n'
	}
*/

* the 3 relevant variables will be qtx, upricex & vx, all in daily terms
summ itemcode qtx upricex vx
* if price (or expenditure) is missing, it means the food item was a residual category reporting only quantities
tab out if upricex==., m
tab out, m

for var qt q qf qs vx upricex: recode X .=0.
count

*qt-udriin niit hereglee
*q-udriin hudaldan awsan hereglee
*qf-udriin hudaldan busdaas awsan hereglee
*qs-udriin uuriin aj ahuin hereglee
*Udriin niit hereglee

collapse (mean) qt q qf qs vx upricex, by(identif itemcode)

rename q q1
rename qf qf2
rename qs qs3

reshape long q qf qs, i(identif itemcode) j(source)

gen source_ok=source
tab source_ok 
tab source


recode source_ok  2=3
recode source_ok  3=2 if source==3
tab source_ok 

drop source 
rename source_ok source
 
*ed if (identif==182178912 & itemcode==10414) |  (identif==183014709 & itemcode==10607) | (identif==184113508 & itemcode==10414)

*ed if (identif==181000601 & itemcode==11305) | (identif==181000602 & itemcode==10705) | (identif==181000602 & itemcode==10711)
egen qt_ok=rsum(q qf qs)
gen exp_f=qt_ok*upricex

*compare qt_ok qt if qt_ok!=0
*compare exp_f vx if exp_f!=0
*ed if qt_ok!=qt & qt_ok!=0

count
count if exp_f==0
replace upricex=. if upricex==0
egen md_p = median(upricex) , by(itemcode) 
replace exp_f=qt_ok*md_p if exp_f==0
count if exp_f==0
drop md_p

drop  qt vx upricex
rename qt_ok qt
rename exp_f vx

label var qt "Quantity total"
label var q  "Quantity purchased"
label var qf "Quantity free of charge"
label var qs "Quantity self-consumed"
label var vx "Food daily monetary value"

***** Dropping other nonfood items or having no calories reported in food item list like water, salt, Tobacco and cigrates 
*drop if inlist(itemcode, 11001, 11203, 11401, 11402, 11403, 11404, 11405)
drop if inlist(itemcode, 11401, 11402, 11403, 11404, 11405)

preserve 
		********************************** food consumed outside ******
		use "$data2018/19_foodout", clear
		* Hunsnii medeelel bhgui urhiig ustgaw
		drop if hses_id==181050209 | hses_id==182040304	| hses_id==182050307 |hses_id==183047501 | hses_id==183047504 | hses_id==183047806	| hses_id==183047810 | 	hses_id==183047811 | hses_id==183048011 | ///
			hses_id==184047003 | hses_id==184047008	| hses_id==184047009 |	hses_id==184047106	| hses_id==184047107 |	hses_id==184047112 | hses_id==184048101 |	hses_id==184048102	| hses_id==184048103 |	///
			hses_id==184048104	| hses_id==184048105 |	hses_id==184048109

		rename hses_id identif
		keep if q1307==1
		egen v = rsum(q1308 q1309)

		joinby identif using "$data2018/basicvars", unm(b)
		keep if _m==3
		drop _m

		gen daily_exp=0
		replace daily_exp=v/30 if location<3
		replace daily_exp=v/7 if location>=3
		rename item item_cod
		*rename identif hhcode
		keep identif item_cod daily_exp 
		gen itemcode=22501
		gen source=4
		collapse (sum) daily_exp (mean) itemcode source,  by(identif)
		count
		duplicates report identif
		rename daily_exp vx
		sort identif
		save foodout_ok, replace 	
restore

append using foodout_ok


***
label val source source
label define source 1 "Purchased" 2 "from own" 3 "Free" 4 "Food away from home", modify

sort identif
merge identif using household_2018, keep(region urban)
tab _m 
drop _m 

count

tab source

*ed if (identif==182178912 & itemcode==10414) |  (identif==183014709 & itemcode==10607) | (identif==184113508 & itemcode==10414)

keep if qt!=0
count if vx==0

****checking and replacing outlier from qunatities/caput/day at each food items level ************
***** outlier utgaar ustgawal mash ih utguud ustdag tiimees bid nar 3sigma onol buyu 99.72% -iin utgiig awch uldej 
***** 100-99.72= 0.08 uwiin utgiig ustgadag. Ene ni mash baga huwiin nuluutei utgiig ustgaj bgaa yum 
*** IQR-iig har : ug onoliig ashiglaj 3sigma-g yalgaj bn
*hist daily_p_qty if item==10101

tab itemcode if qt==.

gen qt_adj=qt

gen qt_adj1 = ln(qt)

bysort itemcode: egen qty_low= pctile(qt_adj1), p(25)
bysort itemcode: egen qty_high= pctile(qt_adj1), p(75)
bysort itemcode: egen IQ_qty= iqr(qt_adj1)

count

gen flag=1 if ((qt_adj1< qty_low-2*IQ_qty) | (qt_adj1> qty_high+2*IQ_qty))

count if flag==1
tab itemcode if flag==1
replace qt_adj=. if flag==1 

joinby identif using decile, unm(b)
tab _m

drop if _m==2
drop _m pcexpm


*** Hemjee ni 3 sigmagaar yalgagdchaad baigaa ugugdliihuu median hemjeegeer orluulga hj bn ***** 
*** Uuruur helbel bid 2243 utga flag-aar todorhoilogdoj bn timees bid tedniig usgahguigeer 
*** median hemjeegeer orluulga hh gej bn 
*** clusteriin huwid ch yum uu tuhain ner turliig heregleegui,  esvel 1 , 2 geh met tsuun tohioldol garch irj 
*** boloh yum, end ter ilreed bgaa tsuuhun tohioldloor orluulahgui hiilgui  
*** 30-aas deesh tohioldoldoor garch irj bgaa bol tuhain utgiig Tuhain tuwshin deer orluulga hiij boloh
*** 30 aas baga bol daraagiin tuwshnii utgiig awch tootsno gesen tohiruulgig oruulj bn gesen ug yum.  
*** n>30 bol suffiecient tuuwer gej uzej bgaa gsn ug yum

global lev1 "itemcode region urban decile"
global lev2 "itemcode urban decile"
global lev3 "itemcode decile"
global lev4 "itemcode decile"

egen ct1 = count(qt_adj), by($lev1)
egen ct2 = count(qt_adj), by($lev2)
egen ct3 = count(qt_adj), by($lev3)
egen ct4 = count(qt_adj), by($lev4)
*defining an arbitrary number of counts having sufficient number of cases to replace outliers. here that is 30.
*This number can be changed if required  
gen ct0=30
egen md1 = median(qt_adj) , by($lev1) 
egen md2 = median(qt_adj) , by($lev2)
egen md3 = median(qt_adj) , by($lev3)
egen md4 = median(qt_adj) , by($lev4)

replace qt_adj=md1 if flag==1 & qt_adj==. & ct1>=ct0
replace qt_adj=md2 if flag==1 & qt_adj==. & ct2>=ct0
replace qt_adj=md3 if flag==1 & qt_adj==. & ct3>=ct0
replace qt_adj=md4 if flag==1 & qt_adj==. & ct4>=ct0
replace qt_adj=md4 if flag==1 & qt_adj==. & ct4<ct0

********************************************* 
*hist  qt  if itemcode==10101 & flag==1
*hist qt_adj if itemcode==10101 & flag==1
*tab item_cod if flag==1

drop md*

tab itemcode if qt_adj==.
*ed if (identif==182178912 & itemcode==10414) |  (identif==183014709 & itemcode==10607) | (identif==184113508 & itemcode==10414)
replace qt_adj=qt if qt_adj==.

sort itemcode
merge itemcode using "D:\18.FAO\Adept\unit"
tab _m 
drop if _m==2
drop _m 

gen qt_gram=qt_adj*unit_scale
sort identif itemcode
count  if qt_gram==0
* qt_gram==. baih utga zaawal orluulagdsan bh yostoi tiimees umnuh coduudig shalga
count if qt_gram!=.

keep if qt_gram!=0 


count if vx==0 
count if vx==. 

order identif itemcode itemname unit_scale  source q qf qs qt qt_gram vx 
keep identif itemcode itemname unit_scale source qt_gram vx 

sort identif itemcode
 

saveold food_2018, version(12) replace


/*

**********************************************************
**********************  NCT  *****************************
**********************  ***  *****************************
clear
insheet using "D:\18.FAO\NCT_edit_last_02_10.txt"

duplicates report itemcode
drop v45 v46 v47 v48 v49 v50 v51 v52 v53
sort itemcode
count
tab itemcode
drop if inlist(itemcode, 11001, 11203, 11401, 11402, 11403, 11404, 11405)
count
*/

use "D:\18.FAO\NCT_Mongolia_final\country_nct_2020_0323_withfoodaway", clear 
count
drop if inlist(itemcode, 11401, 11402, 11403, 11404, 11405)
*drop if inlist(itemcode, 11001, 11203,11401, 11402, 11403, 11404, 11405)

saveold Country_nct_2020_2018_with_Foodout.dta, version(12) replace


********************************
