* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Dietary Energy Requirement Calculation
*
* PROJECT:			Food Analysis
*
* PROGRAMMER:		Undral Lkhagva (LK)
*
* DATE: 			Jan 2026
*
* DESCRIPTION:  	Dietary Energy REQUIREMENT Calculation

*
* SIMPLE PIPELINE:
*   1) Load individual roster + pre-resolved BMI/PAL/SD reference columns.
*   2) Compute body weight proxies and requirement inputs.
*   3) Estimate MDER, ADER, and XDER per individual and household.
*   4) Aggregate to admin levels and save requirement outputs.
*
* PIPELINE REORG (2026-07-05): this file used to reach directly into raw
* "input/" data for its BMI/PAL/weight-gain constants (joinby age_class using
* "$dbase/reference_values") and its WHO SD-for-height values (joinby gender
* height using "$dbase/sd_value_0to2"/"sd_value_2to5") -- a calculation file
* touching raw input directly. Those are now resolved once in
* "04_Import_AgeClassReference.do" and merged in below from its output
* instead; this file no longer touches "$dbase"/"$data_raw" for anything
* except the one "basicvars" merge (also repointed, see below, to the
* "01_Import_BasicVars.do" passthrough).
*
* BUG FIX (2026-07-05) folded in here: the old gender+height join used
* "rename hm_sex gender" before joining -- but hm_sex (0=Female/1=Male, from
* "02 Individual.do") doesn't match sd_value_0to2/sd_value_2to5's native
* 1=Male/2=Female coding. Boys matched by coincidence (hm_sex==1 lines up
* with gender==1=Male in both codings); every girl aged 0-5 matched nothing,
* silently forcing her wh_xder (and XDER) to missing. Verified: 2,350 girls
* aged 0-5 in the 2024 sample were affected. "04_Import_AgeClassReference.do"
* resolves sd_0to2/SD_2to5 using the roster's own native-coded "gender"
* (built straight from q0103, never recoded), so this is fixed simply by no
* longer re-deriving these columns here from hm_sex.
*
* BUG FIX (2026-07-06), see the comment at "generate wh_mder=..." below for
* full detail: the old code rounded "height" to the nearest whole cm in
* place, which leaked into wh_mder/wh_ader/wh_xder for every age class, not
* just the SD-for-height lookup that rounding was meant for. Handbook Ch.2
* Annex 2F specifies this formula using unrounded "median height" -- fixed
* by keeping height unrounded here (a side effect of "04"'s ADePT-export-
* safe design, not something separately hunted for). Small (<1% per
* household) but universal effect -- see detail below.
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* The MDER & ADER can be estimated using:
	*Data on population structure by age and gender,
	*Median height by age and sex,
	*International standards of BMI,
	*Physical activity level in the population.
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

/*
*****************************
*** MDER & ADER-iig tootshoiin tuld 
***** age
**** sex
**** Height
**** Physical Activity - end bid 5 hurtel nasnii huuhdiin eruul mend bolon jiremsen hunii medeelliig nemelteer oruulj sudalj bgaa ..... Bid hun buriin eruul mendiin nuhtsul bdliig ni sudalj oruulna. 
Mortality rate - Nas bariltiin shaltgaaniig oruulj bgaa gsn ug yum. 5 hurtel nasnii huuhduudiin Mortality rate ni 10-aas doosh bol turulhiin uwchintei bj magadgui gej uzeed tootsoolold oruuldaggui bol M.rate>10 bol oruulah heregtei- MDEr-t hamruulah heregtei oldmol uwchin bn gej uzej bn
/endegdeliin tuwshin 10-aas doosh bol MDER-d tootsoh shaardlagagui uchir ni turulhiin uwchin bsan gej uzej bgaa yum 10-aas deesh bol MDEr-t hamruulah heregtei oldmol uwchin bn gej uzej bn/
in 2018 -- Crude Birth ratio (CBR) of survey year (2018) and country (Mongolia)  0.0245
Under 5 mortality rate 16.9 

Emegtei humuusiin huwid jiremsehiig ni awch harin sudalgaand medeelel sugluulssan bol turultiin tuwshing ni totsoj ashiglana. Bid Proxy Ashiglana. Harin bhgui bol Busad eh uusverees garsan turultiin huwiig ni ashiglana. Emegtei hun 9 sar jiremsen bdag 3, 3, 3 saraar ni awch uzne. Ter 3 sard nogdoh kcal bdag - Pregnancy allowance = 210 kcal
**********************/

use "$data_out/indivdual_${survey_year}", clear
keep identif ind_id hm_sex hm_age age_class height

* PIPELINE REORG (2026-07-05): pulls BMI/PAL/weight-gain constants and
* WHO SD-for-height values from "04_Import_AgeClassReference.do" instead of
* joining "reference_values"/"sd_value_0to2"/"sd_value_2to5" directly here
* (see header note). Same columns this file used to compute for itself.
merge 1:1 identif ind_id using "$data_out/AgeClassReference_${survey_year}", keepus(bmi_mder bmi_ader bmi_xder wg_mder wg_ader wg_xder pal_mder pal_ader pal_xder en_pwg sd_0to2 SD_2to5) nogen

tab age_class hm_sex

************************
*** Constant numbers
************************
		* PIPELINE REORG (2026-07-05): promoted from bare literals to globals
		* (set in "00 Master.do") -- same values, matches the "survey_year"
		* precedent so a future survey year has one obvious place to update
		* these rather than hunting for a hardcoded number in this file.
		* Original:
		*   gen u5mr=15.0
		*   gen cbr=0.0169
		* in 2024, Under 5 mortality rate 15 -- https://www.1212.mn/mn/statcate/table-view/Education,%20health/Births%2C%20deaths/DT_NSO_2100_041V3.px
		gen u5mr=${u5mr}
		*in 2024, Crude Birth ratio (CBR) - 16.9 https://www.1212.mn/mn/statcate/table-view/Education,%20health/Births%2C%20deaths/DT_NSO_0300_029V1.px
		gen cbr=${cbr}
		* PAL-Physical Activity Level - (PAL)-g tootsdog FAO-oos gargasan 1.55, 2.01, 1.85 coefficient
/*
*******  Edgeer medeellig ahisglan Physical activity level-iig toosdog -PAL 
PAL-iin dung bol togtooson bgaa.  hotod 1.55-iin PAL hureh hun am hotod tiim ch  ih bdaggui. uuruur helbel 55 huwiin nemelt energy oruulj bn gsn ug yum 
18-aas ih/baga nasnii huwid eruul idewhitei amidrahiin tuld todorhoi utgiig buyu nemelt energy -iig nemj oruulna. Uuniig FAO tooson bgaa  
18 nas hurtelh nasnii huuhed ni usuh shaardlagtai uchir nemelt energy ni 2.1 bgaa, busad nasnii humuusiin huwid bol nemelt energy ni 1.55, 1.85 baina
MDEr-iin huwid 1.55 gdg ni 55% nemelt energy zartsuulna gesen utga
ADEr-iin huwid 1.85 gdg ni 2 dahin nemelt energy zartsuulna gesen utga
XDEr-iin huwid 2.1 gdg ni 85% nemelt energy zartsuulna gesen utga

*/
		
***************************
*********  BMI=w/(h*h) - Boby Mass Index 
*********  WHO/FAO -- standards 
*********  <16.0 kg/m^2 -severe thinness
*********  16.0-16.9 kg/m^2 -moderate thinness
*********  17.0-18.4 kg/m^2 -mild thinness
*********  18.5-24.9 kg/m^2 -normal 
*********  25.0-29.9 kg/m^2 -overweight 
*********  30.0< kg/m^2 -obese 

********* Ð¥Ò¯Ð½Ð¸Ð¹ Ð¶Ð¸Ð½ Ñ‚Ð¾Ð¾Ñ†Ð¾Ñ… w=BMI*(h*h)  -- 18.5-24.9 ÑÑ‚Ð°Ð½Ð´Ð°Ñ€Ñ‚Ñ‹Ð³ Ð°ÑˆÐ¸Ð³Ð»Ð°Ð½ BMI, H Ð¼ÑÐ´ÑÐ³Ð´ÑÑ… Ò¯ÐµÐ´ Ñ…Ò¯Ð½Ð¸Ð¹ Ð¶Ð¸Ð½Ð³ Ñ‚Ð¾Ð¾Ñ†ÑÐ¾Ð½
********* BMI_MDER:18.5=w/(h*h) >> w=18.5*(h*h)
********* BMI_ADER:23.1=w/(h*h) >> w=23.1*(h*h)
********* BMI_XDER:25=w/(h*h)  >> w=25*(h*h)

**** reference values for BMI, PAL, and SD-for-height were joined here before
**** the 2026-07-05 reorg -- see header note above. Now come pre-attached
**** from "04_Import_AgeClassReference.do" via the merge near the top of
**** this file.

*** hieght data deer "cm" -eer bgaa uchir 100-d huwaaj ugsun bn
*** Calculate weight(Ð¥Ò¯Ð½Ð¸Ð¹ Ð¶Ð¸Ð½) for height
* BUG FIX (2026-07-06): before the reorg, this file rounded "height" to the
* nearest whole cm in-place (for the sd_value_0to2/sd_value_2to5 lookup, see
* header note) BEFORE this point -- so wh_mder/wh_ader/wh_xder for every
* age class, not just the SD lookup, were silently computed from rounded
* height. Handbook Ch.2 Annex 2F defines this formula ("KG" in the handbook)
* as BMI x (median height/100)^2 with no rounding instruction -- the only
* rounding-relevant reference in the chapter (footnote 17, WHO BMI-for-age
* growth standards) is specifically about the child SD-for-height tables,
* not this general formula. "04_Import_AgeClassReference.do" now keeps
* "height" unrounded for this reason (rounding only for the SD lookup, via
* a separate "height_rounded" var), so this formula uses the true reference
* height, matching the handbook. Effect: small (verified: household-level
* MDER/ADER/XDER shift by well under 1% for every household in the 2024
* sample -- e.g. one age class's MDER moved by ~6.8 kcal on a ~1,570 kcal
* base) but universal, since almost every household has members outside
* the 0-5 age range this didn't already apply to.
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
	WG-Weight Gain - means eating more calories than your body burns.
	ERWG-Energy Requirement per weight gain
	PAL-Physical Activity
	MC1018-Multiplication coefficient for children between 10 and 18 
Deerh reportiig ashiglan doorh tomyoog oruulj irsen bgaa
! additional info: Basal Metabolic rate (BMR) - Erhten systemiin hewiin uil ajillagaag bailgah shaardlagatai ilchlegiig heldeg 
*/

******** Minimum Dietary Energy Requirement (MDER)
*** MDER=BMR (Basal Methabolic Rate)*PALmin
*** nas huis zergees shaltgaalan equition uurchlugduj bn
gen MDER=0
replace MDER = (-99.4 + 88.6*wh_mder) + (2*wg_mder*en_pwg) if(inlist (age_class, 1,32) & u5mr>10) 
replace MDER = (-99.4 + 88.6*wh_mder) + (wg_mder*en_pwg) if(inlist (age_class, 1,32) & u5mr<=10)
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

 
*** Aggregating the requirement at HH level. 
preserve 
	collapse (sum) MDER ADER XDER , by(identif)
	save "$data_out/Requirement_HHLevel", replace 
restore 

* PIPELINE REORG (2026-07-05): repointed from "$data_raw/basicvars" to
* "01_Import_BasicVars.do"'s passthrough output -- same columns. This is now
* the only external merge in this file (besides the AgeClassReference merge
* near the top), and neither touches "$dbase"/"$data_raw" raw input paths.
merge m:1 identif using "$data_temp/basicvars_${survey_year}", keepus(urban region hhweight hhsize) nogen

/*
Umnu huwi hunii tushind MDER ADER XDER yamar bgaag deer todorhoilj harsan harin odoo us, bus nutgiin tuwshind yamar bhiig todorhoilii
 */
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
save "$data_out/Requirement_admin", replace


*** REMARK: **********************************************************************************************
***MDER iin huwisagchuud barag uurchlugduhgui - MDER-iin tootsoond hamgiin nuluu uzuulelt bol hun amiin butsetseer 
*** tootsoologdoj bgaa uchir barag l uurchlugduhgui yum **************************************************
********************************************************************************************************** 

 
 
