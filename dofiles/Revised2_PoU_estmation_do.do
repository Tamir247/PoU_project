*
* SIMPLE PIPELINE:
*   1) Apply second-round adjustments to PoU input construction.
*   2) Recompute requirement and DEC distribution parameters.
*   3) Validate revised values against prior runs.
*   4) Save finalized revision outputs.
*

*** umnuu neeltteei programiig ni haadag
clear 
*** tehnikiin command zugeer buhleer harah zorilgotoi
set more off


*** define the path of data folder**
** cd-current directly- ajillah zam aa zaaj ugdug

cd "E:\0.Personal\3.Undral\2.Surgalt\Domestic\PoU_Training_4-8_NOV_2019\POU data"
***** Adept porgram ashiglaj tootsoh bolomjtoi program bolowsuulsan bgaa ******************

*******************************************************************************************************
*******************************************************************************************************
****** Dietary Energy Requirement Calculation**********************************************************
*******************************************************************************************************
*******************************************************************************************************

/*
***** NOTETION FOR UNDRAL: from Mr. Satta Abdul lecture from 4 to 8, NOV, 2019  ***************

***** MDER-iig tootsoh arga zui- ***************
 MDER buyu Hool tejeelees awah shaardlagatai  ilchlegiin hamgiin baga utgiig tootsohiin 
       1. Hun amiin too, nas huiseer - HSES-02_indiv datanaas yalgana
	   2. Median height-iig nas huiseer - HSES-02_indiv datanaas yalgana
	   3. Bieiin jingiin indeks (BMI), olon ulsiin standartaar - BMI=w/(h*h)-iig ashiglan  weigth-iig tootsno 
	   4. Hun am,iin dundah idewhit hudulguunii tuvshin-PAL - end mortality rate bolon jiremsenii hunii nuhtsul bdliig awch uehees gadna
	                       nemelt energy-g tootsdog FAO-oos gargasan 1.55, 2.01, 1.85 coefficient-uudiig ashiglaw 

Bid zuwkhun MDER-minimum dietary energy reguirmentaas gadna, 
ADER-average dietary energy reguirment,
XDER-maximum dietary energy reguirmet-iig tootson

Requirements ni deer helsenchlen nasnii butets, huis, height pal-aas shaltgaalj todorhoilogddog bgaa. Uls ornii ontslog geh metiig PAL-d tusgaj 
boloh ch medeelel bdagguigeed nemelt enery boloh 1.55, 2.01, 1.85-iig ashiglaj bgaa / CHECK THIS UNDERSTANDING, UNDRAL! /

Requirements ni iluu hun amiin naznii butets boloh huisees iluu shaltgaalj ur dun uurchlugduhuur bgaa. Height, PAl-iin uzuuleltuud baigaa ch 
hun amiin butets, huis ni iluu nuluutei. 
					   
*/

*** From individual level file (Roster), calculate hh size and to prepare HM file for ADePT. 
***  Adept programaar PoU-iig tootsoh urhiin am buliin toog tootsoj bgaa 
*** Analyzing food security using hhs survey data wiith Adept- nomiig olj awaad tataj awch uzej bolno
*** Adept program ashiglaj herhen PoU tootsoniig harj bolno. 

use 02_indiv, clear 
**** "joinby"- command "merge" commandtai adilhan shine versionuud deer merge ashiglahaar zaawal 1:1 geh met tohirgoonuudig shaardaad bdag 
**** uuruur helbel, joinby, merge adilhan gsn ug yum
*** unm(b)- unmatching information-g haruul gesen ug

joinby identif using basicvars, unm(b)
*** underscore merge 
tab _m
drop _m

** Dropping non-household members 
** Urhud 6/11 saraas hugatsaagaar amidrahgui urhiin gishuuniig ustgaj bn
tab q0109
drop if q0109==2

*************calculating HH size and partaker******************
preserve
    *** bysort ni ijil nertei urhiin dugaariig ni toolj bgaa uuruur helbel uunii ur dung hhsize garch irj chadna gsn ug  
	bysort identif: generate hh_size=_N
*** 
***deducting household members who were not present at home during 7 and 30 days 
	gen p_days=q0108a
	replace p_days=30 if p_days==31
	replace p_days=30 if p_days==0 & location<3
	replace p_days=7 if p_days<=23 & location>=3
	replace p_days=6 if p_days==24 & location>=3
	replace p_days=5 if p_days==25 & location>=3
	replace p_days=4 if p_days==26 & location>=3
	replace p_days=3 if p_days==27 & location>=3
	replace p_days=2 if p_days==28 & location>=3
	replace p_days=1 if p_days==29 & location>=3
	replace p_days=0 if p_days==30 & location>=3
	gen h_mem=p_days/30 if location<3
	replace h_mem=p_days/7 if location>=3

	egen partaker = sum (h_mem), by(identif) 
** there is an error in q0108a in three cases, so repalcing zero with with 1 
	replace partaker=hh_size if partaker==0 & location>=3

	collapse (first) hh_size partaker location urban region month hhweight, by(identif)
    compare hh_size partaker 
	*** Adding visitors
	joinby identif using 01_hhold, unm(b)
	drop _m

	gen v_days=ndays 
	replace v_days=30 if ndays>=30 & ndays!=. & location<3 
	replace v_days=7 if ndays>=7 & ndays!=. & location>=3

	gen partak=0
	replace partak=(v_days*visitor)/30 if location<3 
	replace partak=(v_days*visitor)/7 if location>=3

	egen partaker_f=rsum (partaker partak)
	rename identif hhcode  
	keep hhcode hh_size partaker partak partaker_f location urban region month hhweight
	save HH_size, replace
		
restore
*****************************************************
**** daraah 3-n huwisagchiin neriig zereg solij bn
rename (identif q0103 q0105y) (hhcode gender age)


*****Dietary Energy Requirements (DERs) and Coefficient of Variation due to Body Weight and Life Style (CV|r)
***Rename age and gender variable to make them consistent with commands**

*** Within CV-iig Requirement talaas tootsno 
*** Between CV-iig bol consumption talaas tootsno  

keep hhcode ind_id urban region age gender q0102 q0106 hhweight

*** 18/21 hurtel nasnii huuhed bol usuh bgaa uzhcir nasiig buleglehdee 1 naasaar buleglesen 
*** harin 18 deeshih deer todorhoi hyazgaagaar buleglelt hiisen bgaa
*** Uuruur helbel 18 nasnaas deesh hunii height tudiilun usduggui gej uzej bgaa gsn ug yum 
*** yag 18 gej uzehgui zarim tohioldold 21 nas hurtlee usdug tohioldol bdag 
** medeej emnelgeiin talaas yamar neg nuluugui baialiin jamaarai usuh usultiig helj bgaa yum
*** age_class-31 turliin nasni buleglelt hiigeed huiseer todorhoilson bgaa
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

***join height information by age_class 
*** nasnii angilal tus bureer Height bgaa datatai holboh shaardlagatai 
*** Hyatadiin hunii medeellig shiglej Mongol hunii unduriig tootsoj data uuzgesen
*** Niigmiin eruul mendiin hureelgees medeellig awch ashiglah mun SISS-iin datanaas 0-5 hurtel nasiig ni awch ashiglah

joinby age_class using height_Mongolia_2018, unm(b)
drop _merge

**** Renaming the variables according to ADePT and save HM file******
preserve 
	rename (hhcode ind_id age q0102 q0106 ) (hh_no hm_no hm_age hm_rel hm_marital)
	keep hh_no hm_no hm_rel gender hm_age hm_marital height
	save HM, replace 
restore 


/*****************************
*** MDER-iig tootshoiin tuld 
***** age
**** sex
**** Height
**** Physical Activity - end bid 5 hurtel nasnii huuhdiin eruul mend bolon jiremsen hunii medeelliig nemelteer oruulj sudalj bgaa 
Bid hun buriin eruul mendiin nuhtsul bdliig ni sudalj oruulna. 
Mortality rate - Nas bariltiin shaltgaaniig oruulj bgaa gsn ug yum. 
5 hurtel nasnii huuhduudiin Mortality rate ni 10-aas doosh bol turulhiin uwchintei bj magadgui gej uzeed tootsoolold oruuldaggui bol 
M.rate>10 bol  bol oruulah heregtei- MDEr-t hamruulah heregtei oldmol uwchin bn gej uzej bn
/endegdeliin tuwshin 10-aas doosh bol MDER-d tootsoh shaardlagagui uchir ni turulhiin uwchin bsan gej uzej bgaa yum 
10-aas deesh bol MDEr-t hamruulah heregtei oldmol uwchin bn gej uzej bn/

Emegtei humuusiin huwid jiremsehiig ni awch harin sudalgaand medeelel sugluulssan bol turultiin tuwshing ni totsoj ashiglana 
Bid Proxy Ashiglana. Harin bhgui bol Busad eh uusverees garsan turultiin huwiig ni ashiglana. 

Emegtei hun 9 sar jiremsen bdag 3, 3, 3 saraar ni awch uzne. Ter 3 sard nogdoh kcal bdag

Crude Birth ratio (CBR) of survey year (2018) and country (Mongolia)  0.0245
Under 5 mortality rate 16.9 
Pregnancy allowance = 210 kcal

**********************/

//  Health indicatiors in 2018 (under 5 mortality rate)
gen u5mr=16.9  
// NSO source
gen cbr=0.0245 
/* 
*****************************
*********  BMI=w/(h*h)
********* w=/(h*h)
     ******  BMI:18.5-25-normal standart

******** Hun buriin BMI-iig tootsoh bolomjhgui gehdee hunii usushud shaardlagatai hamgiin baga tuwsghin 18.5 tuwshineer humuusiin weight-g olno 
********* MDER-hamgiin baga tuwshin-18.5
********* ADER- dundaj tuwshin- 23.1
********* Xder-maximum tuwshin - 25 
18.5, 23.1, 25-iid WHO tootsson bgaa

********* BMI_MDER:18.5=w/(h*h) >> w=18.5*(h*h)
********* BMI_ADER:23.1=w/(h*h) >> w=23.1*(h*h)
********* BMI_XDER:25=w/(h*h)  >> w=25*(h*h)

*******  Edgeer medeellig ahisglan Physical activity level-iig toosdog -PAL 
PAL-iin dung bol togtooson bgaa. 
hotod 1.55-iin PAL hureh hun am hotod tiim ch  ih bdaggui. uuruur helbel 55 huwiin nemelt energy oruulj bn gsn ug yum 
18-aas ih/baga nasnii huwid eruul idewhitei amidrahiin tuld todorhoi utgiig buyu nemelt energy -iig nemj oruulna. Uuniig FAO tooson bgaa  
18 nas hurtelh nasnii huuhed ni useh shaardlagtai uchir nemelt energy ni 2.1 bgaa, busad nasnii humuusiin huwid bol nemelt energy ni 1.55, 1.85 baina
MDEr-iin huwid 1.55 gdg ni 55% nemelt energy zartsuulna gesen utga
ADEr-iin huwid 1.85 gdg ni 85% nemelt energy zartsuulna gesen utga
XDEr-iin huwid 2.1 gdg ni 2 dahin nemelt energy zartsuulna gesen utga
*/

******************* 
 
****join reference values of BMI, PAL and SD values for children 

joinby age_class using reference_values, unm(b)
drop _merge 

replace height=int(round(height,1))

joinby gender height using sd_value_0to2, unm(b)
drop if _m==2
drop _merge

joinby gender height using sd_value_2to5, unm(b)
drop if _m==2
drop _merge


*** hieght data deer "cm" -eer bgaa uchir 100-d huwaaj ugsun bn
*** Calculate weight for height 
generate wh_mder=bmi_mder*(height/100)*(height/100)
generate wh_ader=bmi_ader*(height/100)*(height/100)
generate wh_xder=bmi_xder*(height/100)*(height/100)

*** replacing calculated weight-for-height (above) with the reference values for children age 0-5 
*** For MDER & ADER
replace wh_mder=bmi_mder if(inlist (age_class, 1,2,3,4,5,32,33,34,35,36))
replace wh_ader=bmi_ader if(inlist (age_class, 1,2,3,4,5,32,33,34,35,36))

**** for XDER 
replace wh_xder=sd_0to2 if(inlist (age_class, 1,2,32,33))
replace wh_xder=SD_2to5 if(inlist (age_class, 3,4,5,34,35,36))


 /*
Hichneen hun nuhun urjihuin nasnii emegtei bgaag tootsoh heregtei  
 
*/
**** Calculate the ratio of pregnant women in the population 
gen mem=1
*Total population - huwisagch buriin ard niit sudalgaand hamragdsan gishuudiin too garna 
egen t_mem=sum(mem) 
*female population of reproductive age (14 to 49.9)-nuhun urjihuin nasnii gishuudiin toogoot huwisagch uusne
egen f_mem=sum(mem) if(inlist(age_class,46,47,48,49,50,51,52,53,54,55,56,57)) 
*ratio of female population of reproductive to the total population - nuhun urjihuin nasnii humuusiin niit populationd ezleh huwiig tootsno 
gen fem_rat=f_mem/t_mem  
*Likelihood a woman is pregnant -  Crude Birth ratio (cbr)-iig ni nuhun urjihuin nasnii hun amiin huwid haritsuulj bn 
gen fem_p=cbr/fem_rat


******************* odoo MDER- iig tootsoh bolomjtoi hun medeelluud uusgesen, tiimees bid odoo MDER-iig tootsyo 

/*
Niigmiin eruul mendiin garzaas eruul tejeelleg amidrahad sharlagatai kcl-iig tootsdog tomyololiig daraahaas olj unsh
"Human enery requirements " -iin reportiig fao-iin site-aas olj unshaarai 
End shaardlagatai buyu requirement enery-iig herhen tootsdog euations-uudiig oruulsan bdag 

Parameters
RBM=Reference Body Mass (Weight for attened height (kg)
WG-Weight Gain
ERWG-Energy Requirement per weight gain
PAL-Physical Activity
MC1018-Multiplication coefficient for children between 10 and 18 


Deerh reportiig ashiglan doorh tomyoog oruulj irsen bgaa

! additional info: Basal Metabolic rate (BMR) - Erhten systemiin hewiin uil ajillagaag bailgah shaardlagatai ilchlegiig heldeg 

*/
******** Minimum Dietary Energy Requirement (MDER)
*** nas huis zergees shaltgaalan equition uurchlugduj bn
gen MDER=0
replace MDER = (-99.4 + 88.6*wh_mder) + (2*wg_mder*en_pwg) if (inlist (age_class, 1,32) & u5mr>10) 
replace MDER = (-99.4 + 88.6*wh_mder) + (wg_mder*en_pwg) if (inlist (age_class, 1,32) & u5mr<=10)
replace MDER= 0.93*(310.2 + 63.3*wh_mder-0.263*wh_mder^2) + (2*wg_mder*en_pwg) if age_class==2 & u5mr>10
replace MDER= 0.93*(310.2 + 63.3*wh_mder-0.263*wh_mder^2) + (wg_mder*en_pwg) if age_class==2 & u5mr<=10
replace MDER=0.93*(263.4 + 65.3*wh_mder-0.454*wh_mder^2) + (2*wg_mder*en_pwg) if age_class==33 & u5mr>10
replace MDER=0.93*(263.4 + 65.3*wh_mder-0.454*wh_mder^2) + (wg_mder*en_pwg)   if age_class==33 & u5mr<=10
replace MDER=(310.2 + 63.3*wh_mder-0.263*wh_mder^2) + (wg_mder*en_pwg) if(inlist(age_class,3,4,5,6,7,8,9,10))
replace MDER=(263.4 + 65.3*wh_mder-0.454*wh_mder^2) + (wg_mder*en_pwg) if(inlist(age_class,34,35,36,37,38,39,40,41))
replace MDER=0.85 * (310.2 + 63.3*wh_mder-0.263*wh_mder^2) + (wg_mder*en_pwg) if(inlist(age_class,11,12,13,14,15,16,17,18))     
replace MDER=0.85 * (263.4 + 65.3*wh_mder-0.454*wh_mder^2) + (wg_mder*en_pwg) if(inlist(age_class,42,43,44,45))
replace MDER=0.85 * (263.4 + 65.3*wh_mder-0.454*wh_mder^2) + (wg_mder*en_pwg)+fem_p*210 if(inlist(age_class,46,47,48,49))
replace MDER=pal_mder*(692.2 + 15.057*wh_mder) if(inlist(age_class,19,20,21,22))	
replace MDER=pal_mder*(486.6 + 14.818*wh_mder)+fem_p*210 if(inlist(age_class,50,51,52,53))
replace MDER=pal_mder*(873.1 + 11.472*wh_mder) if(inlist(age_class,23,24,25,26,27,28))
replace MDER=pal_mder*(845.6 + 8.126*wh_mder)+fem_p*210 if(inlist(age_class,54,55,56,57))
replace MDER=pal_mder*(845.6 + 8.126*wh_mder) if(inlist(age_class,58,59))
replace MDER=pal_mder*(587.7 + 11.711*wh_mder) if(inlist(age_class,29,30,31))
replace MDER=pal_mder*(658.5 + 9.082*wh_mder) if(age_class>59)

******** Average Dietary Energy Requirement (ADER)
gen ADER=0
replace ADER = (-99.4 + 88.6*wh_ader) + (2*wg_ader*en_pwg) if(inlist (age_class, 1,32) & u5mr>10)
replace ADER = (-99.4 + 88.6*wh_ader) + (wg_ader*en_pwg) if(inlist (age_class, 1,32) & u5mr<=10)
replace ADER= 0.93*(310.2 + 63.3*wh_ader-0.263*wh_ader^2) + (2*wg_ader*en_pwg) if age_class==2 & u5mr>10
replace ADER= 0.93*(310.2 + 63.3*wh_ader-0.263*wh_ader^2) + (wg_ader*en_pwg) if age_class==2 & u5mr<=10
replace ADER=0.93*(263.4 + 65.3*wh_ader-0.454*wh_ader^2) + (2*wg_ader*en_pwg) if age_class==33 & u5mr>10
replace ADER=0.93*(263.4 + 65.3*wh_ader-0.454*wh_ader^2) + (wg_ader*en_pwg)   if age_class==33 & u5mr<=10
replace ADER=(310.2 + 63.3*wh_ader-0.263*wh_ader^2) + (wg_ader*en_pwg) if(inlist(age_class,3,4,5,6,7,8,9,10))
replace ADER=(263.4 + 65.3*wh_ader-0.454*wh_ader^2) + (wg_ader*en_pwg) if(inlist(age_class,34,35,36,37,38,39,40,41))
replace ADER=(310.2 + 63.3*wh_ader-0.263*wh_ader^2) + (wg_ader*en_pwg) if(inlist(age_class,11,12,13,14,15,16,17,18))     
replace ADER=(263.4 + 65.3*wh_ader-0.454*wh_ader^2) + (wg_ader*en_pwg) if(inlist(age_class,42,43,44,45))
replace ADER=(263.4 + 65.3*wh_ader-0.454*wh_ader^2) + (wg_ader*en_pwg)+fem_p*210 if(inlist(age_class,46,47,48,49))
replace ADER=pal_ader*(692.2 + 15.057*wh_ader) if(inlist(age_class,19,20,21,22))	
replace ADER=pal_ader*(486.6 + 14.818*wh_ader)+fem_p*210 if(inlist(age_class,50,51,52,53))
replace ADER=pal_ader*(873.1 + 11.472*wh_ader) if(inlist(age_class,23,24,25,26,27,28))
replace ADER=pal_ader*(845.6 + 8.126*wh_ader)+fem_p*210 if(inlist(age_class,54,55,56,57))
replace ADER=pal_ader*(845.6 + 8.126*wh_ader) if(inlist(age_class,58,59))
replace ADER=pal_ader*(587.7 + 11.711*wh_ader) if(inlist(age_class,29,30,31))
replace ADER=pal_ader*(658.5 + 9.082*wh_ader) if(age_class>59)

******** Maximum Dietary Energy Requirement (XDER)
gen XDER=0
replace XDER = (-99.4 + 88.6*wh_xder) + (2*wg_xder*en_pwg) if(inlist (age_class, 1,32) & u5mr>10)
replace XDER = (-99.4 + 88.6*wh_xder) + (wg_xder*en_pwg) if(inlist (age_class, 1,32) & u5mr<=10)
replace XDER= 0.93*(310.2 + 63.3*wh_xder-0.263*wh_xder^2) + (2*wg_xder*en_pwg) if age_class==2 & u5mr>10
replace XDER= 0.93*(310.2 + 63.3*wh_xder-0.263*wh_xder^2) + (wg_xder*en_pwg) if age_class==2 & u5mr<=10
replace XDER=0.93*(263.4 + 65.3*wh_xder-0.454*wh_xder^2) + (2*wg_xder*en_pwg) if age_class==33 & u5mr>10
replace XDER=0.93*(263.4 + 65.3*wh_xder-0.454*wh_xder^2) + (wg_xder*en_pwg)   if age_class==33 & u5mr<=10
replace XDER=(310.2 + 63.3*wh_xder-0.263*wh_xder^2) + (wg_xder*en_pwg) if(inlist(age_class,3,4,5,6,7,8,9,10))
replace XDER=(263.4 + 65.3*wh_xder-0.454*wh_xder^2) + (wg_xder*en_pwg) if(inlist(age_class,34,35,36,37,38,39,40,41))
replace XDER=1.15*(310.2 + 63.3*wh_xder-0.263*wh_xder^2) + (wg_xder*en_pwg) if(inlist(age_class,11,12,13,14,15,16,17,18))     
replace XDER=1.15*(263.4 + 65.3*wh_xder-0.454*wh_xder^2) + (wg_xder*en_pwg) if(inlist(age_class,42,43,44,45))
replace XDER=1.15*(263.4 + 65.3*wh_xder-0.454*wh_xder^2) + (wg_xder*en_pwg)+fem_p*210 if(inlist(age_class,46,47,48,49))
replace XDER=pal_xder*(692.2 + 15.057*wh_xder) if(inlist(age_class,19,20,21,22))	
replace XDER=pal_xder*(486.6 + 14.818*wh_xder)+fem_p*210 if(inlist(age_class,50,51,52,53))
replace XDER=pal_xder*(873.1 + 11.472*wh_xder) if(inlist(age_class,23,24,25,26,27,28))
replace XDER=pal_xder*(845.6 + 8.126*wh_xder)+fem_p*210 if(inlist(age_class,54,55,56,57))
replace XDER=pal_xder*(845.6 + 8.126*wh_xder) if(inlist(age_class,58,59))
replace XDER=pal_xder*(587.7 + 11.711*wh_xder) if(inlist(age_class,29,30,31))
replace XDER=pal_xder*(658.5 + 9.082*wh_xder) if(age_class>59)

/*
Umnu huwi hunii tushind MDER ADER XDER yamar bgaag deer todorhoilj harsan harin odoo uls, bus nutgiin tuwshind yamar bhiig todorhoilii
 */

 
 
*** Aggregating the requirement at HH level. 
preserve 
	collapse (sum) MDER ADER XDER , by(hhcode)
	save req_hhLevel, replace 
restore 

*** Saving the MDER, ADER and XDER values of region, area and national level in different file
preserve 
	collapse (mean) MDER ADER XDER [fweight = round(hhweight)], by(urban)
	tempfile urban
	save `urban'
restore

preserve 
	collapse (mean) MDER ADER XDER [fweight = round(hhweight)], by(region)
	tempfile region
	save `region'
restore

collapse (mean) MDER ADER XDER [fweight = round(hhweight)]
append using `region'
append using `urban'

**** Within CV-g tootsno 
***** Calculate CV due to Body Weight and Life Style (CV|r)************
gen cv_r=(MDER-XDER)/(invnormal(0.01)-invnormal(0.99))/((MDER+XDER)/2)

replace region=0 if region==.
replace urban=0 if urban==.
label define region1 0 "National", modify
label define urban1 0 "National", modify

order urban region MDER ADER XDER cv_r
save household_requirment, replace

*** REMARK: **********************************************************************************************
***MDER iin huwisagchuud barag uurchlugduhgui - MDER-iin tootsoond hamgiin nuluu uzuulelt bol hun amiin butsetseer 
*** tootsoologdoj bgaa uchir barag l uurchlugduhgui yum **************************************************
********************************************************************************************************** 




******************************************************************************************************* 
***************************** PART- Conclusion ******************************************************** 
**** Bid PoU-iig bodohiin tuld MDER, DEC(Dietary enery intakes-consumption), Within CV, Between CV, Physical Activity- g tootsoh yostoi** 
****** Bid deerh code-oor MDER bolon within CV, Physical Activy-g tootsson ****************************
********************* HSES-iin consumption data ashiglaad DEC, Between CV-g tootsoh yostoi ************
******************************************************************************************************* 



*******************************************************************************************************
*******************************************************************************************************
****** Dietary Energy Consumption **********************
** using the data file having food quantities and prices ****
**urban data file 
*******************************************************************************************************
*******************************************************************************************************

****** Bid  MDER bolon within CV-g tootsson bol DEC-ees between CV tootsno. ***************************
********* MDEr-iin huwid mash olon medeellin eh uusveruud heretei bgaa bol DEC-iin huwid bol  *********
********* sudalgaanii data l ashigladag *************************************************************** 

	use 16_urb_diary, clear
** raname varaible item code
rename item item_cod
rename identif hhcode
*Adding quantities different for diffrent periods  - Niit heregleeg olj bn
*q-quintity
*v-value
egen q = rsum(q1201_1 q1202_1 q1203_1)
gen v   = q*q1204

*** er zardal garaagui item uudiig ustgana. 
drop if v==0 & q==0

** Imputing the price for missing values based on median price of each item.
** zaawal cluster, location geh metiin uniig orluulah shaardlagagui
** une bhgui item ni 3.8 huwi bgaa uchir tiim ch ach holbogdol uguh shaardlagui yum 
gen price=q1204
replace price=. if price==0
egen md_p = median(price) , by(item_cod) 
replace v=q*md_p if v==0

*** converting quantities and expenditure into per day
*** 31, 8-iin honogiin yalgaag tusgaj uguh 
gen daily_exp=v/30 
gen daily_qty=q/30
keep hhcode item_cod daily_exp daily_qty
save urban_food, replace 

****Rural data file**************************************************** 
use 17_rur_food_7d, clear
rename item item_cod
rename identif hhcode
keep if q1301==1

*Adding quantities different for diffrent periods  
gen q = q1302
gen v   = q*q1304
drop if v==0 & q==0

** Imputing the price for missing values based on median price of each item.
gen price=q1304
replace price=. if price==0
egen md_p = median(price) , by(item_cod) 
replace v=q*md_p if v==.

*** converting quantities and expenditure into per day
gen daily_exp=v/7 
gen daily_qty=q/7
keep hhcode item_cod daily_exp daily_qty

save rural_food, replace


********************************** food consumed outside ******
use 19_foodout, clear
keep if q1307==1
egen v = rsum(q1308 q1309)

joinby identif using basicvars, unm(b)
keep if _m==3
drop _m

gen daily_exp=0
replace daily_exp=v/30 if location<3
replace daily_exp=v/7 if location>=3
rename item item_cod
rename identif hhcode
keep hhcode item_cod daily_exp 

append using urban_food
append using rural_food
count
***Adding HH size 
joinby hhcode using HH_size, unm(b)
keep if _m==3
drop _m

**** converting exp. and quantities into per capita per day at each food item level**
gen daily_p_exp=daily_exp/hh_size
gen daily_p_qty=daily_qty/hh_size

****Adding total per capita HH expenditure. Expenditure are used as proxy for income. The data file shered by NSO colleagues 
rename  hhcode identif
joinby identif using cons_2018, unm(b)
keep if _m==3
drop _m
rename identif hhcode

rename pcexpm tth_inc 

** calculating expenditure deciles******
** bid nar decile-aar ur dun gargahgui bolohoor end zaawal hhweigh ashiglah tiim ch shuhal bish 
*** Harin poverty tootsoo ni descile-aar ur dun gargah uchir hhweight ashiglaj huwaadag  
preserve 
	collapse (mean) tth_inc, by(hhcode)
	xtile decile=tth_inc, nq(10)
	save decile, replace
restore 

joinby hhcode using decile, unm(b)
drop _m

***** Dropping other nonfood items or having no calories reported in food item list like water, salt, Tobacco and cigrates 
drop if inlist(item_cod, 11001, 11203, 11401, 11402, 11403, 11404, 11405)

****checking and replacing outlier from qunatities/caput/day at each food items level ************
***** outlier utgaar ustgawal mash ih utguud ustdag tiimees bid nar 3sigma onol buyu 99.72% -iin utgiig awch uldej 
***** 100-99.72= 0.08 uwiin utgiig ustgadag. Ene ni mash baga huwiin nuluutei utgiig ustgaj bgaa yum 
*** IQR-iig har : ug onoliig ashiglaj 3sigma-g yalgaj bn
*hist daily_p_qty if item==10101
gen qunatity_ad=daily_p_qty
gen qunatity_ad1 = ln(daily_p_qty)

bysort item_cod: egen qty_low= pctile(qunatity_ad1), p(25)
bysort item_cod: egen qty_high= pctile(qunatity_ad1), p(75)
bysort item_cod: egen IQ_qty= iqr(qunatity_ad1)

gen flag=1 if ((qunatity_ad1< qty_low-2*IQ_qty) | (qunatity_ad1> qty_high+2*IQ_qty))

replace qunatity_ad=. if flag==1 

*** Hemjee ni 3 sigmagaar yalgagdchaad baigaa ugugdliihuu median hemjeegeer orluulga hj bn ***** 
*** Uuruur helbel bid 2243 utga flag-aar todorhoilogdoj bn timees bid tedniig usgahguigeer 
*** median hemjeegeer orluulga hh gej bn 
*** clusteriin huwid ch yum uu tuhain ner turliig heregleegui,  esvel 1 , 2 geh met tsuun tohioldol garch irj 
*** boloh yum, end ter ilreed bgaa tsuuhun tohioldloor orluulahgui hiilgui  
*** 30-aas deesh tohioldoldoor garch irj bgaa bol tuhain utgiig Tuhain tuwshin deer orluulga hiij boloh
*** 30 aas baga bol daraagiin tuwshnii utgiig awch tootsno gesen tohiruulgig oruulj bn gesen ug yum.  
*** n>30 bol suffiecient tuuwer gej uzej bgaa gsn ug yum

global lev1 "item_cod region urban decile"
global lev2 "item_cod urban decile"
global lev3 "item_cod decile"
global lev4 "item_cod"

egen ct1 = count(qunatity_ad), by($lev1)
egen ct2 = count(qunatity_ad), by($lev2)
egen ct3 = count(qunatity_ad), by($lev3)
egen ct4 = count(qunatity_ad), by($lev4)
*defining an arbitrary number of counts having sufficient number of cases to replace outliers. here that is 30.
*This number can be changed if required  
gen ct0=30
egen md1 = median(qunatity_ad) , by($lev1) 
egen md2 = median(qunatity_ad) , by($lev2)
egen md3 = median(qunatity_ad) , by($lev3)
egen md4 = median(qunatity_ad) , by($lev4)

replace qunatity_ad=md1 if flag==1 & qunatity_ad==. & ct1>=ct0
replace qunatity_ad=md2 if flag==1 & qunatity_ad==. & ct2>=ct0
replace qunatity_ad=md3 if flag==1 & qunatity_ad==. & ct3>=ct0
replace qunatity_ad=md4 if flag==1 & qunatity_ad==. & ct4>=ct0
replace qunatity_ad=md4 if flag==1 & qunatity_ad==. & ct4<ct0


********************************************* 
*hist  daily_p_qty  if item_cod==10102
*hist qunatity_ad if item_cod==10102
*tab item_cod if flag==1

drop md*

***Treating the food monetary values according to the quantities adjusted for outliers
gen price=daily_p_exp/daily_p_qty if (flag==. & daily_p_qty!=.)
egen med_price1 = median(price), by($lev1)
egen med_price2 = median(price), by($lev2)
egen med_price3 = median(price), by($lev3)
egen med_price4 = median(price), by($lev4)

gen fd_mv=daily_p_exp
replace fd_mv=qunatity_ad*med_price1 if flag==1 & fd_mv==. & ct1>=ct0
replace fd_mv=qunatity_ad*med_price2 if flag==1 & fd_mv==. & ct2>=ct0
replace fd_mv=qunatity_ad*med_price3 if flag==1 & fd_mv==. & ct3>=ct0
replace fd_mv=qunatity_ad*med_price4 if flag==1 & fd_mv==. & ct4>=ct0
replace fd_mv=qunatity_ad*med_price4 if flag==1 & fd_mv==. & ct4<ct0

drop ct* med_price*


**** Bidend yagaad ilchleg heregtei we, ene hedii hemjeenii calore hereglej baigaag 
**** medeh heregtei, colariin hemjeeg tawih ni mash chuhal yum undug gehed l jijig undug bol tomoosso uur calorytoi
**** bdag tiinees nutriation tootsdog humuusin huwid bol tuhain ulsad niitleg yag yamar ner turliig ni 
**** heregleed bn gedgees ni tootsoj, todorhoildog
 
**** Joining nutrient conversion factors- 

*joinby item_cod using NCT_Mongolia, unm(b)
joinby item_cod using kcal_HSES, unm(b)

drop _m

**** medeellee grams-aar ilerhiilne uchir ni ulchleg ni 100g-d nognod colories-iin hemjee bgaa 
*** uunii tuld 130 neg turul buriin huwid hemjih negjiig ni todorhoiloh heregtei Undug 65 gr gdg shig
***converting quantities into gram per unit 
gen fd_qty=qunatity_ad*grams


**** Renaming the variables according to ADePT and save FOOD file******
preserve 
	rename hhcode hh_no
	drop unit
	gen unit=1 if fd_qty>0 & fd_qty!=.
	replace fd_qty=fd_qty*hh_size
	replace fd_mv=fd_mv*hh_size
	keep hh_no item_cod unit fd_qty fd_mv
			save FOOD, replace 
restore 

** Converting quantities into calories 
gen calories=fd_qty/100*(energy_kcal)


*** Urhiin gishuudiin gaduur hoolloltiin medeelel mash hangaltgui bgaa HSES datanaa
*** uuruur helbel zuwkhun heden tugrug l zartsuulsan gdg baigaagaas bish hen hedii hemjeenii 
*** yamar turliin hool idsen eseh ni bhgui bgaaa
*** tiimees bid zardliig ashiglan inputation hiih shaardlagatai bolson bid tuhain urhiin medeelellees 
*** hedii hemjeenii tugrugiig yu yund zartsuulj bgaag tootsoj uzej  bolno. 

*** Gaduur idsen humuusiin huwid gaduur idsen hool ni iluu ilchlegtei haragdaad bdag 
*** olon sudalgaanaas jisheelbel, iluu sharsan huursan hool idddeg, tiimees 

*** Gaduur yag yamar hool idseniig medehgui gaduur idsen zardal bgaa, tiimees taamaglal hj uzeh heregtei tiimees 
*** gertee 1000 tugrugud hedii hemjeenii caloriin huns hereglesen ter hemjeegeer gaduur hoolloltiin zardliin hemjeend
** hargalzah caloryiig onooj uguw. Gaduur hoolloltiin calory ni gert idsenees iluu bdag gsn sudalgaa bgaa ch bid tentsuu baihaar awch bn
** uchir bid zuruug ni batalj chadahgui yum 

*** imputing calories for food eaten outside

** tuhain urh ni 1 calori awahad dundjaar heden tugrug zartsuulj baigaag 
** olj bn. uuruur helbel, 16454 urh tus bureer 1 calory awahad zartsuulsan 
** dundaj zardliig olj bn. 
** Uuniig tootsohiin tuld neg urh buriin huwid ner turul bureer 1 calory awahad 
** zartsuulah zardliig olood, tuhain urhiin huwid buh ner turliin huwid ni 1 calory awahad zartsuulsan 
** zartsuulsan zardliin dundajiig ni tootsno
**  

**calories per unit value of money 
gen p_cal=fd_mv/calories
egen cal_all=mean(p_cal), by (hhcode)
replace calories=fd_mv/cal_all if calories==.


**** Herew gertee hool ideegui zuwkhun gaduur hoolloltiin zardal garsan urhiin huwid 
*** deerh argiig ni ashiglaj bolohgui bolchij bgaa, Tiimeed locationg ni ashiglaj 
*** busad todorhoilogdson medeelleeig ashiglan median ashiglan orluulga hiiw. 

*** Last imputation for those HH who only consumed outside or readymade food.. 

egen ct1 = count(cal_all), by($lev1)
egen ct2 = count(cal_all), by($lev2)
egen ct3 = count(cal_all), by($lev3)
egen ct4 = count(cal_all), by($lev4)
*defining an arbitrary number of counts having sufficient number of cases to replace outliers. here that is 30 
*This number can be changed if required
gen ct0=30

egen md1 = median(cal_all) , by($lev1) 
egen md2 = median(cal_all) , by($lev2)
egen md3 = median(cal_all) , by($lev3)
egen md4 = median(cal_all) , by($lev4)

replace calories=fd_mv/md1 if calories==. & ct1>=ct0
replace calories=fd_mv/md2 if calories==. & ct2>=ct0
replace calories=fd_mv/md3 if calories==. & ct3>=ct0
replace calories=fd_mv/md4 if calories==. & ct4>=ct0
replace calories=fd_mv/md4 if calories==. & ct4<ct0

**** Complete the calories comuptation for each food item**

**** Adding calories at hh level

egen tcal=sum (calories), by(hhcode)
egen f_exp=sum (fd_mv), by(hhcode)

*egen cal_item=sum(calories), by (item_cod)
*egen qty_item=sum(fd_qty), by (item_cod)
*collapse (mean) cal_item qty_item ,  by (item_cod)

collapse (mean) urban region decile hh_size tcal tth_inc f_exp hhweight month,  by (hhcode)

gen year=2018
*hist tcal
* hist-iin ur dund log normal distribution zuragdaj bgaa. 
* Ihenh urhiin neg hunii neg honogt awdag ilchlegiin hemjee 6000 kcal 
* -iin oiroltsoo idej bgaa ur dun haragdaj bn  
* 6000 kcal-aas ih idej bgaa urhiin too 182 bn 182/16454=1.1%
** uuruu helbel 1.1% huwiin outlier ni medeelliin huwid asuudal boloh toon hemjee bish ch 
** Bid BETWEEN CV -g tootsohod ene 182 urhiin utga iluu nuluu uzuulne. 
** Tiimees 1.1% geed orhih bish edgeer outlier-iig orluulga hh heregtei bolj bgaa yum. 


**** Renaming the variables according to ADePT and save HH file******
preserve 
	rename (hhcode urban hhweight) (hh_no urb_rur hh_wgt)
	recode hh_size (1=1 "One member") (2/4=2 "Two to four members") (5/100=3 "Five or more members"), gen (hhsizec)
	keep hh_no region urb_rur hh_size hhsizec month year hh_wgt tth_inc
			save HH, replace 
restore 

***** Generate one variable for month, in case if month and year are stored separately and possibility that same month is repeated in next year***

*** Deerh between CV-d nuluu uzuuleh ourlierigg zasahdaa uliriin nuluu, bolon suurishliin nuluug tootsno
*** edgeeriig tootsson regregtion ashiglaj tootsoj orluulga hj bn
*** gehdee ene regretionoor zuwkhun 182 urhuu l zasaad bgaa yum bish buh urhiin utga
*** predicted-eer zasahdaj bgaa, uunii ur dun bidnii ourlier ni zasagdaj bgaa gsn ug yum 
*** helbel reg-iin daraa buh too ni uurchlugduj bgaa ba hamgiin zahiin 2 ourlieruudad iluu nuluu uzuuleed
*** harin goliin hewiin calory-toi urhuuded  bol utga ni mash baga soligdoj bgaa gsn ug yum 
*** uuruur helbel inputation hj bui arga ni regretion bn


egen season=group(year month) 

**Remove seasonality and trend from per capita income and Kcal variables. 
**Hereby the variables are rescaled such that in each area/region the monthly average income and Kcal are stable over time. 
**The adjusted variable expresses the income and kcal of an 'average' month. 
**Note that due to this adjustment, the mean of fitted DEC will not exactly equal the mean of the empirical DEC.

*** Command to install wtmean
ssc inst _gwtmean, replace

*Calculate average income by Region and urban
bys urban region : egen year_inc=wtmean(tth_inc), weight(round(hhweight*hh_size))
*Calculate average income by Month, Region and urban
bys season urban region: egen month_inc=wtmean(tth_inc), weight(round(hhweight*hh_size))
*Calculate de-seasonalized income 
generate inc_season=tth_inc*year_inc/month_inc

*** Similarly (as income) remove seasonality from kcal
bys urban region: egen year_cal=wtmean(tcal), weight(round(hhweight*hh_size))
bys season urban region: egen month_cal=wtmean(tcal), weight(round(hhweight*hh_size))
generate cal_adjusted=tcal*year_cal/month_cal

**Calculate log income (avoiding 0s if any)-logrifchimlaad reg bodoj bgaa 
generate ln_inc=ln(inc_season+.05)
generate ln_inc2=ln(ln_inc)^2

** Estimate liner regression using adjusted kcal as dependent variables and as independent variables are: log of income, square log of income 
** dummies of region and area. Interactive terms are region with area, log of income with area and square log of income with area.
 
*reg  cal_adjusted ln_inc ln_inc2 i.urban i.region i.urban##i.region c.ln_inc##i.urban c.ln_inc2##i.urban 
reg  cal_adjusted ln_inc ln_inc2 i.urban c.ln_inc##i.urban c.ln_inc2##i.urban 

* regregtionii ur dungeer yag ene tohioldold R-square =0.2 buyu 20% garsan 
** gehdee cross section data eer R-square is 0.2 bol mash hangalttai yum time series data deer ashilljah 
** bol R-Square ni 0.9 ntr garah hgeregtei yum
** bid nar zuwkhun distributiong ni l harj bgaa, R square ni baga baigaad sanaa zowoh hereggui yum 

***generate fitted values of the regression 

*** CV-nii huwid erunhuuduu 35% hurtelhiig huleen zuwshuurdug bol 
*** food-iin huwid bol 30% bhad bolno gej uzdeg 

predict adj_energy
*hist tcal
*hist adj_energy
*sum adj_energy
*tabstat tcal adj_energy, statistics(cv)  
* cv-g harahad anhkhii utgaar bol CV ni 53.3%, inputationii argaar bol 25.9% 

*** Save required information in files by area and region  
preserve 
	bysort urban: egen sample_HH=count(hhcode)
	bysort urban: egen sample_pop=sum(hh_size)
	gen repsentative=hh_size*hhweight
	bysort urban: egen repsentative_pop=sum(repsentative)
	gen energyforSD=adj_energy
	collapse (sd) energyforSD (mean) tcal adj_energy (first) sample_HH sample_pop repsentative_pop [fweight = round(hhweight*hh_size)], by(urban)	
	tempfile urban
	save `urban', replace 
restore

preserve 
	bysort region: egen sample_HH=count(hhcode)
	bysort region: egen sample_pop=sum(hh_size)
	gen repsentative=hh_size*hhweight
	bysort region: egen repsentative_pop=sum(repsentative)
	gen energyforSD=adj_energy
	collapse (sd) energyforSD (mean) tcal adj_energy (first) sample_HH sample_pop repsentative_pop [fweight = round(hhweight*hh_size)], by(region)
	tempfile region
	save `region', replace 
restore

egen sample_HH=count(hhcode)
egen sample_pop=sum(hh_size)
gen repsentative=hh_size*hhweight
egen repsentative_pop=sum(repsentative)
gen energyforSD=adj_energy
collapse (sd) energyforSD (mean) tcal adj_energy (first) sample_HH sample_pop repsentative_pop [fweight = round(hhweight*hh_size)]

append using `region'
append using `urban'
replace region=0 if region==.
replace urban=0 if urban==.
*****************************************************************

joinby urban region using household_requirment, unm(b)	

rename tcal DEC
*Calculate CV due to income
gen CV_Income=energyforSD/adj_energy
*Calculate total CV 
generate final_cv=sqrt(cv_r^2 + CV_Income^2)

*** Calculate PoU
generate ln_var = ln(final_cv ^2 + 1)
generate ln_dec = ln(DEC) - ln_var/2
generate PoU = normal((ln(MDER)-ln_dec)/sqrt(ln_var))*100
generate NoU=round(PoU*repsentative_pop)/100
drop _m energyforSD adj_energy ln_var ln_dec

label define region1 0 "National", modify 
label values region region1 
label define urban1 0 "National", modify 
label values urban urban1 

order region urban sample_HH sample_pop repsentative_pop DEC MDER ADER XDER cv_r CV_Income final_cv PoU NoU

**** Rounding the variables**************
replace repsentative_pop=(round(repsentative_pop,1))
replace MDER=(round(MDER,1))
replace ADER=(round(ADER,1))
replace XDER=(round(XDER,1))
replace DEC=(round(DEC,1))
replace NoU=(round(NoU,1))

export excel using "Results_stata.csv", sheetreplace firstrow (variables)

save result_file, replace

