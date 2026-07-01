clear
version 14.2

set more off

global data2018 "E:\HSES_result_2018\HSES_2018"
global workdata "E:\HSES_result_2018\HSES_2018\workdata"
global worklog "E:\HSES_result_2018\HSES_2018\worklog"

cd $workdata

cap log close 
log using "$worklog/setup_food.log", replace

***********************************************************
***                                                     ***
***    TO CLEAN AND CREATE A WORKING FOOD DATA SET      ***
***                                                     ***
***********************************************************

******************************************************************
* I. From HSES urban  
******************************************************************
use "$data2018/16_urb_diary", clear
rename hses_id identif
keep identif item q120* 
renpfix q120 q

* dropping records with no info
egen x = rmiss(q1_1 - q4)
tab x, m
drop if x==13
drop x

rename item itemcode
* transposing the data
rename q1_1 qtot1
rename q2_1 qtot2
rename q3_1 qtot3

rename q1_2 qpur1
rename q2_2 qpur2
rename q3_2 qpur3

rename q1_3 qfree1
rename q2_3 qfree2
rename q3_3 qfree3

rename q1_4 qown1
rename q2_4 qown2
rename q3_4 qown3

rename q4 aprice

* confirming there are no duplicated records at the -identif itemcode- level
duplicates tag identif itemcode, gen(flag)
tab flag
*drop if flag==1
l if flag==1
drop flag

reshape long qtot qpur qfree qown, i(identif itemcode) j(tenth)

******************************************************************
* dropping those without any data or with only the average price 
* -imputations are not possible in either case-
******************************************************************
summ qtot qpur qfree qown aprice
foreach v of varlist qtot qpur qfree qown aprice {
	recode `v' 0=.
	}
egen out = rmiss(qtot qpur qfree qown aprice)
tab out, m
drop if out==5 | (out==4 & aprice!=.)
drop out

keep identif tenth itemcode qtot qpur aprice qfree qown
gen survey = "hsesu"
summ
compress
sort identif itemcode
save tempfood1, replace

******************************************************************
* II. From HSES rural
******************************************************************
use "$data2018/17_rur_food_7d", clear

rename hses_id identif
keep identif item q130*
renpfix q130 q
rename item itemcode

summ q?
drop q1

rename q2 qtot
rename q3 qpur
rename q4 aprice
rename q5 qfree
rename q6 qown

******************************************************************
* dropping those without any data or with only the average price 
* -imputations are not possible in either case-
******************************************************************
summ qtot qpur qfree qown aprice
foreach v of varlist qtot qpur qfree qown aprice {
	recode `v' 0=.
	}
egen out = rmiss(qtot qpur qfree qown aprice)
tab out, m
drop if out==5 | (out==4 & aprice!=.)
drop out

keep identif itemcode qtot qpur aprice qfree qown
gen survey = "hsesr"
summ
compress
sort identif itemcode
save tempfood2, replace

******************************************************************
* III. putting together the 2 food files plus basicvars
******************************************************************
use tempfood1, clear
summ
append using tempfood2
summ

sort identif
merge identif using "$data2018/basicvars"
tab _

count if _merge==2
dis "there are " r(N) " households with no food data"
tab quarter if _==2, m
sort newaimag month identif
l newaimag month identif cluster location urban if _==2, nolabel sep(0)
drop if _m==2
drop _
sort identif itemcode tenth

* making both hies & hses homogeneous in terms of ==>
* (0) making back-up of original variables
* (1) change quantities and expenditure to a daily basis. average price is not a problem
* (2) dropping food items with incorrect codes

* (0) back-up variables
foreach v of varlist qtot qpur aprice qfree qown {
	clonevar `v'0 = `v'
	}
summ qtot* qpur* aprice* qfree* qown*, sep(2)
order identif itemcode tenth qtot0 qpur0 aprice0 qfree0 qown0 ///
	      cluster hhsize qtot qpur aprice qfree qown survey

* (1) quantities and expenditure to a daily basis
* from tenth (hsesu) or weekly (hsesr) to daily
gen perday = .
replace perday = 10 if inlist(tenth,1,2) | (tenth==3 & inlist(month,4,6,9,11))
replace perday = 11 if tenth==3 & inlist(month,1,3,5,7,8,10,12)
replace perday = 8  if tenth==3 & month==2
replace perday = 7  if tenth==.

tab perday, m
tab perday survey, m

	
foreach v of varlist qtot qpur qfree qown {
	replace `v' = `v'/perday 
	}
	
summ qtot* qpur* aprice* qfree* qown*, sep(2)


* (2) dropping food items with incorrect codes
gen outfi = itemcode - 10000
recode outfi 101/115 201/217 301/304 401/415 501/508 601/609 701/714 801/806 901/913 ///
	1001/1008 1101/1106 1201/1204 1301/1306 1401/1405 = 0 *=1
tab outfi, m
tab itemcode if outfi==1, m
l identif itemcode tenth qtot0 qpur0 aprice0 qfree0 qown0 survey if outfi==1
drop if outfi==1
drop outfi
* all observations are within the expected ranges for food codes

label var qtot0 "Quantity total, original"
label var qpur0 "Quantity purchased, original"
label var aprice0 "Average price, original"
label var qfree0 "Quantity free, original"
label var qown0 "Quantity own, original"

label var qtot "Quantity total, original daily"
label var qpur "Quantity purchased, original daily"
label var aprice "Average price, original"
label var qfree "Quantity free, original daily"
label var qown "Quantity own, original daily"
label var survey Survey
label var itemcode "Food item"
label var tenth "Tenth of the month"

d
summ
compress
sort identif itemcode tenth
save tempfood0, replace

erase tempfood1.dta
erase tempfood2.dta

*******************************
* Check 1: total vs subtotals *
*******************************
use tempfood0, clear
summ qtot qpur qfree qown

inspect qtot
count if qtot==.
dis "NOTE: There are " r(N) " cases with no total quantity"
summ qtot qpur qfree qown if qtot==.
* impute qtot=qpur+qfree+qown
egen tot = rsum(qpur qfree qown)
recode tot 0=.
replace qtot = tot if qtot==.
inspect qtot

summ tot qtot
compare tot qtot

gen dif = tot - qtot
summ dif, det
tab dif

recode dif -0.05/0.05 = 0
tab dif

count if dif==0
count if dif!=0

gen byte flag1=0
label var flag1 "Total vs subtotals"
replace flag1=1 if dif!=0
* if there is a total but there are not subtotals, two cases
count if qtot!=. & tot==.
* if both total reported and total estimated are zero or missing, only no cases
count if (qtot==0 & tot==0) | (qtot==. & tot==.)

tab flag1, m
tab itemcode if flag1==1, m
sort newaimag month identif itemcode tenth
l newaimag month identif itemcode tenth qtot0 qpur0 aprice0 qfree0 qown0 survey if flag1==1, nolabel sep(0)
drop dif tot

save tempx, replace

**************************************
* Check 2: Entries per tenth         *
* If meat is consumed daily ==> 10   *
* the same good can be counted more  *
* than once                          *
**************************************
gen byte flag2 = 0
label var flag2 "Entries per tenth"

gen byte first = 0
bys identif : replace first=1 if _n==1
sort identif itemcode tenth

***********************************
* items reported by household
***********************************
* notice this is different from entries
* however, we do NOT have info on entries
* the enumerator aggregated the diary info into the food module

bys identif tenth itemcode : keep if _n==1
* items by tenth ==> only for urban areas
foreach n of numlist 1/3 {
	egen byte zz = count(itemcode) if tenth==`n', by(identif)
	egen byte items`n' = mean(zz), by(identif)
	recode items`n' (.=0)
	drop zz
	}
* items by month
bys identif itemcode : keep if _n==1
egen itemst = count(itemcode), by(identif)
bys identif : keep if _n==1

summ items? if urban==1
summ items? if urban==2
* the 1st tenth reports 21.6 different food items, almost 0.24 more than the second tenth
* which in turns report 0.36 more food items than the 3rd tenth
* overall, in urban areas households report 29 food items per month
* in rural areas is 17 food items per week

* to compare total number of items by survey
table month urban [aw=hhweight], c(mean itemst) row col f(%9.0f)

gen semester = 1 + irecode(month,6)
table semester urban [aw=hhweight], c(mean itemst) row col f(%9.0f)
* similar results by semester

* flagging few food items reported overall
count if (urban==1 & itemst<8) | (urban==2 & itemst<5)
replace flag2 = (urban==1 & itemst<8) | (urban==2 & itemst<5)

* flagging when the # of food items changes drastically from one tenth to another
gen dif2 = items2-items1
gen dif3 = items3-items2
tab1 dif2 dif3
count if inrange(dif2,-15,15)==0 & dif2!=.
count if inrange(dif3,-15,15)==0 & dif3!=.
* listing households where the number of transactions between one tenth and the other is more than 15
replace flag2=1 if inrange(dif2,-15,15)==0 & dif2!=. 
replace flag2=1 if inrange(dif3,-15,15)==0 & dif3!=. 

* flagging households where there are no transactions at all in 1 or 2 tenths of the month
count if (urban==1 & (items1==0 | items2==0 | items3==0)) | (urban==2 & itemst==0)
replace flag2=1 if (urban==1 & (items1==0 | items2==0 | items3==0)) | (urban==2 & itemst==0)
tab flag2, m
sort newaimag month identif

list newaimag month identif items? survey if flag2==1, nolabel sep(0)
tab newaimag if flag2==1
drop items? dif2 dif3

use tempx, clear

****************************************
* Check 3: average and implicit prices *
****************************************
gen qt = qtot
gen q  = qpur
gen ap = aprice
gen qf = qfree
gen qs = qown

label var qt "Quantity total"
label var q  "Quantity purchased"
label var ap "Average price"
label var qf "Quantity free of charge"
label var qs "Quantity self-consumed"

gen byte flagx = 0
label var flagx "value outliers"

* Program to identify outliers
cap program drop xoutlier
program define xoutlier
	version 14.2
	summ uprice if itemcode==`1', det
	tab uprice if itemcode==`1'
	*cap kdensity uprice if itemcode==`1'
end 

gen uprice = ap


xoutlier 10101
replace flagx=1 if uprice!=. & inrange(uprice,400,3000)==0 & itemcode==10101

** rice
xoutlier 10102
replace flagx=1 if uprice!=. & inrange(uprice,1000,6000)==0 & itemcode==10102

** flour highest grade
xoutlier 10103
replace flagx=1 if uprice!=. & inrange(uprice,600,2600)==0 & itemcode==10103

** flour, grade 1
xoutlier 10104
replace flagx=1 if uprice!=. & inrange(uprice,400,1800)==0 & itemcode==10104

** flour, grade 2
xoutlier 10105
replace flagx=1 if uprice!=. & inrange(uprice,400,1500)==0 & itemcode==10105

** other flour
xoutlier 10106
replace flagx=1 if uprice!=. & inrange(uprice,500,6500)==0 & itemcode==10106

** noodle, domestic
xoutlier 10107
replace flagx=1 if uprice!=. & inrange(uprice,500,7000)==0 & itemcode==10107

** noodle, import
xoutlier 10108
replace flagx=1 if uprice!=. & inrange(uprice,900,20000)==0 & itemcode==10108

** bakery
xoutlier 10109
replace flagx=1 if uprice!=. & inrange(uprice,800,7000)==0 & itemcode==10109

** biscuit
xoutlier 10110
replace flagx=1 if uprice!=. & inrange(uprice,950,10000)==0 & itemcode==10110

** cake
xoutlier 10111
replace flagx=1 if uprice!=. & inrange(uprice,2000,5e5)==0 & itemcode==10111

** millet
xoutlier 10112
replace flagx=1 if uprice!=. & inrange(uprice,800,5000)==0 & itemcode==10112

** other rice
xoutlier 10113
replace flagx=1 if uprice!=. & inrange(uprice,800,10000)==0 & itemcode==10113

** pizza: we don't include this because there is no
xoutlier 10114
*replace flagx=1 if uprice!=. & inrange(uprice,5000,300000)==0 & itemcode==10114
* replace flagx=1 if uprice!=. & inrange(uprice,0,100)==0 & itemcode==

** other: we don't include this
xoutlier 10115 
*replace flagx=1 if uprice!=. & inrange(uprice 300,10000)==0 & itemcode==10115
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** mutton
xoutlier 10201
replace flagx=1 if uprice!=. & inrange(uprice,2000,10500)==0 & itemcode==10201

** beef
xoutlier 10202
replace flagx=1 if uprice!=. & inrange(uprice,2000,12500)==0 & itemcode==10202

** goat meat
xoutlier 10203
replace flagx=1 if uprice!=. & inrange(uprice,1500,9000)==0 & itemcode==10203

** horse meat
xoutlier 10204
replace flagx=1 if uprice!=. & inrange(uprice,2000,1e4)==0 & itemcode==10204

** camel meat
xoutlier 10205
replace flagx=1 if uprice!=. & inrange(uprice,1600,9000)==0 & itemcode==10205

** dried meat
xoutlier 10206
replace flagx=1 if uprice!=. & inrange(uprice,4000,5e5)==0 & itemcode==10206

** chicken
xoutlier 10207
replace flagx=1 if uprice!=. & inrange(uprice,1400,18e3)==0 & itemcode==10207

** pork
xoutlier 10208
replace flagx=1 if uprice!=. & inrange(uprice,3000,1e6)==0 & itemcode==10208

** bacon
xoutlier 10209
replace flagx=1 if uprice!=. & inrange(uprice,3000,1e6)==0 & itemcode==10209

** game
xoutlier 10210
replace flagx=1 if uprice!=. & inrange(uprice,1000,1e6)==0 & itemcode==10210

** other poultry
xoutlier 10211
replace flagx=1 if uprice!=. & inrange(uprice,0,1e6)==0 & itemcode==10211

** animal interior
xoutlier 10212
replace flagx=1 if uprice!=. & inrange(uprice,300,6500)==0 & itemcode==10212

** sausage, salami (big)
xoutlier 10213
replace flagx=1 if uprice!=. & inrange(uprice,2000,20000)==0 & itemcode==10213

** sausage (small)
xoutlier 10214
replace flagx=1 if uprice!=. & inrange(uprice,2000,18e3)==0 & itemcode==10214

** canned meat
xoutlier 10215
replace flagx=1 if uprice!=. & inrange(uprice,1500,20e3)==0 & itemcode==10215

** other: do not include this
xoutlier 10216
replace flagx=1 if uprice!=. & inrange(uprice,1200,12000)==0 & itemcode==10216

xoutlier 10217
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==


** fish
xoutlier 10301
replace flagx=1 if uprice!=. & inrange(uprice,1000,15e3)==0 & itemcode==10301

** dried, smoked, salted fish
xoutlier 10302
replace flagx=1 if uprice!=. & inrange(uprice,0,1e6)==0 & itemcode==10302

** canned fish
xoutlier 10303
replace flagx=1 if uprice!=. & inrange(uprice,1500,2e4)==0 & itemcode==10303

** other seafood: do not include this
xoutlier 10304
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** milk
xoutlier 10401
replace flagx=1 if uprice!=. & inrange(uprice,300,4500)==0 & itemcode==10401

** yougurt
xoutlier 10402
replace flagx=1 if uprice!=. & inrange(uprice,300,5000)==0 & itemcode==10402

** eggs
xoutlier 10403
replace flagx=1 if uprice!=. & inrange(uprice,130,800)==0 & itemcode==10403

** dried curds
xoutlier 10404
replace flagx=1 if uprice!=. & inrange(uprice,1000,25e3)==0 & itemcode==10404

** horse milk
xoutlier 10405
replace flagx=1 if uprice!=. & inrange(uprice,500,7000)==0 & itemcode==10405

** curds
xoutlier 10406
replace flagx=1 if uprice!=. & inrange(uprice,500,12000)==0 & itemcode==10406

** cheese, national
xoutlier 10407
replace flagx=1 if uprice!=. & inrange(uprice,1500,2e4)==0 & itemcode==10407

** cheese
xoutlier 10408
replace flagx=1 if uprice!=. & inrange(uprice,1000,42000)==0 & itemcode==10408

** curds
xoutlier 10409
replace flagx=1 if uprice!=. & inrange(uprice,1000,15e3)==0 & itemcode==10409

** other milk products: do not include this
xoutlier 10410
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** dried and coffee milk
xoutlier 10411
replace flagx=1 if uprice!=. & inrange(uprice,1500,12000)==0 & itemcode==10411

** condensed milk
xoutlier 10412
replace flagx=1 if uprice!=. & inrange(uprice,1000,16e3)==0 & itemcode==10412

** sour cream
xoutlier 10413
replace flagx=1 if uprice!=. & inrange(uprice,1500,18e3)==0 & itemcode==10413

** dried eggs
xoutlier 10414
replace flagx=1 if uprice!=. & inrange(uprice,1000,10000)==0 & itemcode==10414

** other dairy products: it will not be included
xoutlier 10415
* some transactions show really low prices (<10 Tugrug), I guess it could be possible
*replace flagx=1 if uprice!=. & inrange(uprice,)==0 & itemcode==

** butter
xoutlier 10501
replace flagx=1 if uprice!=. & inrange(uprice,1000,23e3)==0 & itemcode==10501

** margarine
xoutlier 10502
replace flagx=1 if uprice!=. & inrange(uprice,2000,12e3)==0 & itemcode==10502

** vegetable oil
xoutlier 10503
replace flagx=1 if uprice!=. & inrange(uprice,2000,8e3)==0 & itemcode==10503

** edible animal fats
xoutlier 10504
replace flagx=1 if uprice!=. & inrange(uprice,800,6000)==0 & itemcode==10504

** cream
xoutlier 10505
replace flagx=1 if uprice!=. & inrange(uprice,800,18e3)==0 & itemcode==10505

** melted butter
xoutlier 10506
replace flagx=1 if uprice!=. & inrange(uprice,2000,20e3)==0 & itemcode==10506

** olive oil
xoutlier 10507
replace flagx=1 if uprice!=. & inrange(uprice,3000,38e3)==0 & itemcode==10507

** other: do not include this
xoutlier 10508
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** apple
xoutlier 10601
replace flagx=1 if uprice!=. & inrange(uprice,1000,15e3)==0 & itemcode==10601

** mandarin
xoutlier 10602
replace flagx=1 if uprice!=. & inrange(uprice,1000,15e3)==0 & itemcode==10602

** raisin
xoutlier 10603
replace flagx=1 if uprice!=. & inrange(uprice,1000,20e3)==0 & itemcode==10603

** other fresh fruit: do not include this
xoutlier 10604
replace flagx=1 if uprice!=. & inrange(uprice,400,8000)==0 & itemcode==10604

* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** wild fruit
xoutlier 10605
replace flagx=1 if uprice!=. & inrange(uprice,500,2e5)==0 & itemcode==10605

** dried fruit
xoutlier 10606
replace flagx=1 if uprice!=. & inrange(uprice,1000,15e3)==0 & itemcode==10606

** wild nuts
xoutlier 10607
replace flagx=1 if uprice!=. & inrange(uprice,1000,15000)==0 & itemcode==10607

** other nuts: do not incldue this
xoutlier 10608
* one obvious outlier, will be fixed later
replace flagx=1 if uprice!=. & inrange(uprice,1000,42e3)==0 & itemcode==10608

** other: do not include this
xoutlier 10609
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** potato
xoutlier 10701
replace flagx=1 if uprice!=. & inrange(uprice,200,3000)==0 & itemcode==10701

** cabbage
xoutlier 10702
replace flagx=1 if uprice!=. & inrange(uprice,250,3500)==0 & itemcode==10702

** carrot
xoutlier 10703
replace flagx=1 if uprice!=. & inrange(uprice,300,4000)==0 & itemcode==10703

** turnip
xoutlier 10704
replace flagx=1 if uprice!=. & inrange(uprice,300,6000)==0 & itemcode==10704

** onion
xoutlier 10705
replace flagx=1 if uprice!=. & inrange(uprice,300,7000)==0 & itemcode==10705

** garlic
xoutlier 10706
replace flagx=1 if uprice!=. & inrange(uprice,0,50)==0 & itemcode==10706

** tomato
xoutlier 10707
replace flagx=1 if uprice!=. & inrange(uprice,800,10e3)==0 & itemcode==10707

** cucumber
xoutlier 10708
replace flagx=1 if uprice!=. & inrange(uprice,500,10e3)==0 & itemcode==10708

** jelly sticks
xoutlier 10709
replace flagx=1 if uprice!=. & inrange(uprice,600,9e3)==0 & itemcode==10709

** canned cucumber
xoutlier 10710
replace flagx=1 if uprice!=. & inrange(uprice,1000,15e3)==0 & itemcode==10710

** canned vegetable salad
xoutlier 10711
replace flagx=1 if uprice!=. & inrange(uprice,1000,16e3)==0 & itemcode==10711

** pepper
xoutlier 10712
replace flagx=1 if uprice!=. & inrange(uprice,800,6500)==0 & itemcode==10712

** mushrooms & "sea cabbage": excluded
xoutlier 10713
* sea cabbage appears to be a very expensive food item
replace flagx=1 if uprice!=. & inrange(uprice,1,200)==0 & itemcode==10713

** other: do not include this
xoutlier 10714
replace flagx=1 if uprice!=. & inrange(uprice,300,20000)==0 & itemcode==10714

** 
xoutlier 10801
replace flagx=1 if uprice!=. & inrange(uprice,1,80)==0 & itemcode==10801

xoutlier 10802
replace flagx=1 if uprice!=. & inrange(uprice,1,80)==0 & itemcode==10802

xoutlier 10803
replace flagx=1 if uprice!=. & inrange(uprice,1,100)==0 & itemcode==10803

xoutlier 10804
replace flagx=1 if uprice!=. & inrange(uprice,1,100)==0 & itemcode==10804

xoutlier 10805
replace flagx=1 if uprice!=. & inrange(uprice,1,80)==0 & itemcode==10805

xoutlier 10806

** sugar
xoutlier 10901
replace flagx=1 if uprice!=. & inrange(uprice,1000,5500)==0 & itemcode==10901

** lump sugar
xoutlier 10902
replace flagx=1 if uprice!=. & inrange(uprice,1000,10000)==0 & itemcode==10902

** sugar substitution
xoutlier 10903
replace flagx=1 if uprice!=. & inrange(uprice,4,100)==0 & itemcode==10903

** candy
xoutlier 10904
replace flagx=1 if uprice!=. & inrange(uprice,1500,25e3)==0 & itemcode==10904

** sweet
xoutlier 10905
replace flagx=1 if uprice!=. & inrange(uprice,2000,35e3)==0 & itemcode==10905

** chocolate
xoutlier 10906
replace flagx=1 if uprice!=. & inrange(uprice,1,60)==0 & itemcode==10906

** honey
xoutlier 10907
replace flagx=1 if uprice!=. & inrange(uprice,4,62)==0 & itemcode==10907

** compotes
xoutlier 10908
replace flagx=1 if uprice!=. & inrange(uprice,2,20)==0 & itemcode==10908

** jam
xoutlier 10909
replace flagx=1 if uprice!=. & inrange(uprice,1,50)==0 & itemcode==10909

** ice cream
xoutlier 10910
replace flagx=1 if uprice!=. & inrange(uprice,1,28)==0 & itemcode==10910

** chewing gum
xoutlier 10911
replace flagx=1 if uprice!=. & inrange(uprice,30,500)==0 & itemcode==10911

** syrup
xoutlier 10912
replace flagx=1 if uprice!=. & inrange(uprice,2.5,100)==0 & itemcode==10912

** other: do not include this
xoutlier 10913
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==



** salt
xoutlier 11001
replace flagx=1 if uprice!=. & inrange(uprice,0.1,15)==0 & itemcode==11001

** vinegar
xoutlier 11002
replace flagx=1 if uprice!=. & inrange(uprice,1,40)==0 & itemcode==11002

** ketchup
xoutlier 11003
replace flagx=1 if uprice!=. & inrange(uprice,1,25)==0 & itemcode==11003

** mayonnaise
xoutlier 11004
replace flagx=1 if uprice!=. & inrange(uprice,1000,20e3)==0 & itemcode==11004

** yeast
xoutlier 11005
replace flagx=1 if uprice!=. & inrange(uprice,1,30)==0 & itemcode==11005

** spices
xoutlier 11006
replace flagx=1 if uprice!=. & inrange(uprice,2,80)==0 & itemcode==11006

** babyfood
xoutlier 11007
replace flagx=1 if uprice!=. & inrange(uprice,1000,6e4)==0 & itemcode==11007

** other: do not include this
xoutlier 11008
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** green tea
xoutlier 11101
replace flagx=1 if uprice!=. & inrange(uprice,1,500)==0 & itemcode==11101

** tea
xoutlier 11102
replace flagx=1 if uprice!=. & inrange(uprice,1,130)==0 & itemcode==11102

** coffee
xoutlier 11103
replace flagx=1 if uprice!=. & inrange(uprice,3,150)==0 & itemcode==11103

** cocoa
xoutlier 11104
replace flagx=1 if uprice!=. & inrange(uprice,5,100)==0 & itemcode==11104

xoutlier 11105
replace flagx=1 if uprice!=. & inrange(uprice,2,300)==0 & itemcode==11105

** other: do not include this
xoutlier 11106
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** beverage
xoutlier 11201
replace flagx=1 if uprice!=. & inrange(uprice,500,6e3)==0 & itemcode==11201

** juice
xoutlier 11202
replace flagx=1 if uprice!=. & inrange(uprice,600,10e3)==0 & itemcode==11202

** pure water, bottled
xoutlier 11203
replace flagx=1 if uprice!=. & inrange(uprice,100,3500)==0 & itemcode==11203

** other: do not include this
xoutlier 11204
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** vodka domestic
xoutlier 11301
replace flagx=1 if uprice!=. & inrange(uprice,1000,1e6)==0 & itemcode==11301

** beer domestic
xoutlier 11302
replace flagx=1 if uprice!=. & inrange(uprice,900,5500)==0 & itemcode==11302

** vodka imported
xoutlier 11303
replace flagx=1 if uprice!=. & inrange(uprice,2500,1e6)==0 & itemcode==11303

** beer imported
xoutlier 11304
replace flagx=1 if uprice!=. & inrange(uprice,1000,1e5)==0 & itemcode==11304

** wine
xoutlier 11305
replace flagx=1 if uprice!=. & inrange(uprice,2600,1e5)==0 & itemcode==11305

** other: do not include this
xoutlier 11306
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==

** cigarette imported
xoutlier 11401
replace flagx=1 if uprice!=. & inrange(uprice,1000,7500)==0 & itemcode==11401

** cigarette domestic
xoutlier 11402
replace flagx=1 if uprice!=. & inrange(uprice,800,6500)==0 & itemcode==11402

** tobacco
xoutlier 11403
replace flagx=1 if uprice!=. & inrange(uprice,3,50)==0 & itemcode==11403

** snuff
xoutlier 11404
replace flagx=1 if uprice!=. & inrange(uprice,8,150)==0 & itemcode==11404

** other: do not include this
xoutlier 11405
* replace flagx=1 if uprice!=. & inrange(uprice,,)==0 & itemcode==


rename flagx flagP
tab flagP, m
tab itemcode if flagP==1, m
* ****** *
sort newaimag month identif itemcode tenth
list newaimag month identif itemcode tenth qtot0 qpur0 aprice0 qfree0 qown0 if flagP==1, sep(0) nolabel


****************************
* Check 4: food quantities *
****************************
foreach v of varlist q qf qs qt {
	* daily per capita quantities
	gen pc`v' = `v'/hhsize if flag1==0
	recode pc`v' .=0 if flag1==0
	}
summ q* pcq*, sep(4)

* Program to identify outliers of per capita quantities
cap program drop xquantity
program define xquantity
	version 14.2
	summ pcq pcqt q qt if itemcode==`1', det
	tab pcqt if itemcode==`1'
end

* Program to flag outliers of per capita quantities
cap program drop xflagq
program define xflagq
	version 14.2
	* there are no missing per capita quantities, all missings were recorded to zero
	replace flagq=1 if itemcode==`1' & (inrange(pcq,0,`2')==0 | inrange(pcqt,0,`2')==0) & flag1==0
end

gen byte flagq = 0
label var flagq "Quantity outliers"


** bread
xquantity 10101
xflagq 10101 2.5

** rice
xquantity 10102
xflagq 10102 0.9

** flour highest grade
xquantity 10103
xflagq 10103 1

** flour, grade 1
xquantity 10104
xflagq 10104 1.9

** flour, grade 2
xquantity 10105
xflagq 10105 1.2

** other flour
xquantity 10106
xflagq 10106 0.43

** noodle, domestic
xquantity 10107
xflagq 10107 0.6

** noodle, import
xquantity 10108
xflagq 10108 0.4

** bakery
xquantity 10109
xflagq 10109 1.25

** biscuit
xquantity 10110
xflagq 10110 0.4

** cake
xquantity 10111
xflagq 10111 0.273

** millet
xquantity 10112
xflagq 10112 0.3

** other rice
xquantity 10113
xflagq 10113 1e6

** pizza
xquantity 10114
xflagq 10114 1e6

** other: we don't include this
xquantity 10115 
* xflagq 

** mutton
xquantity 10201
xflagq 10201 1.8

** beef
xquantity 10202
xflagq 10202 1.5

** goat meat
xquantity 10203
xflagq 10203 1.2

** horse meat
xquantity 10204
xflagq 10204 1

** camel meat
xquantity 10205
xflagq 10205 0.7

** dried meat
xquantity 10206
xflagq 10206 0.5

** chicken
xquantity 10207
xflagq 10207 1e6

** pork
xquantity 10208
xflagq 10208 0.25

** bacon
xquantity 10209
xflagq 10209 0.2

** game
xquantity 10210
xflagq 10210 1e6

** other poultry
xquantity 10211
xflagq 10211 0.3

** animal interior
xquantity 10212
xflagq 10212 1.2

** sausage, salami (big)
xquantity 10213
xflagq 10213 0.9

** sausage (small)
xquantity 10214
xflagq 10214 0.25

** canned meat
xquantity 10215
xflagq 10215 0.3

xquantity 10216
xflagq 10216 1.2

** other: do not include this
xquantity 10217
xflagq 10217 1.0

** fish
xquantity 10301
xflagq 10301 0.3

** dried, smoked, salted fish
xquantity 10302
xflagq 10302 1e6

** canned fish
xquantity 10303
xflagq 10303 1e6

** other seafood: do not include this
xquantity 10304
* xflagq 

** milk
xquantity 10401
xflagq 10401 3

** yougurt
xquantity 10402
xflagq 10402 2

** eggs
xquantity 10403
xflagq 10403 5

** dried curds
xquantity 10404
xflagq 10404 .5

** horse milk
xquantity 10405
xflagq 10405 2

** curds
xquantity 10406
xflagq 10406 0.5

** cheese, national
xquantity 10407
xflagq 10407 0.29

** cheese
xquantity 10408
xflagq 10408 1e6

** curds
xquantity 10409
xflagq 10409 1e6

** other milk products: do not include this
xquantity 10410
* xflagq 

** dried and coffee milk
xquantity 10411
xflagq 10411 0.25

** condensed milk
xquantity 10412
xflagq 10412 0.4

** sour cream
xquantity 10413
xflagq 10413 0.3

** dried eggs
xquantity 10414
xflagq 10414 1e6
** other
*xquantity 10415

** butter
xquantity 10501
xflagq 10501 .33

** margarine
xquantity 10502
xflagq 10502 0.08

** vegetable oil
xquantity 10503
xflagq 10503 .261

** edible animal fats
xquantity 10504
xflagq 10504 .3

** cream
xquantity 10505
xflagq 10505 0.35

** melted butter
xquantity 10506
xflagq 10506 0.15

** olive oil
xquantity 10507
xflagq 10507 0.15

** other: do not include this
xquantity 10508
* xflagq 

** apple
xquantity 10601
xflagq 10601 0.51

** mandarin
xquantity 10602
xflagq 10602 0.3

** raisins
xquantity 10603
xflagq 10603 0.3

** other fresh fruit: do not include this
xquantity 10604
xflagq 10604 1.1
* xflagq 

** wild fruit
xquantity 10605
xflagq 10605 0.8

** dried fruit
xquantity 10606
xflagq 10606 1e6

** wild nuts
xquantity 10607
xflagq 10607 0.3

** other nuts: do not include this
xquantity 10608
* xflagq 

** other: do not include this
xquantity 10609
* xflagq 

** potato
xquantity 10701
xflagq 10701 1.1

** cabbage
xquantity 10702
xflagq 10702 0.9

** carrot
xquantity 10703
xflagq 10703 0.4

** turnip
xquantity 10704
xflagq 10704 0.3

** onion
xquantity 10705
xflagq 10705 0.4

** garlic
xquantity 10706
xflagq 10706 50

** tomato
xquantity 10707
xflagq 10707 0.3

** cucumber
xquantity 10708
xflagq 10708 0.54

** jelly sticks
xquantity 10709
xflagq 10709 1e6

** canned cucumber
xquantity 10710
xflagq 10710 0.25

** canned vegetable salad
xquantity 10711
xflagq 10711 0.33

** pepper
xquantity 10712
xflagq 10712 0.2

** mushrooms & sea-cabbage
xquantity 10713
xflagq 10713 85

** other: do not include this
xquantity 10714
xflagq 10714 1.6

xquantity 10801
xflagq 10801 50

xquantity 10802
xflagq 10802 25

xquantity 10803
xflagq 10803 45

xquantity 10804
xflagq 10804 10

xquantity 10805
xflagq 10805 31.3

xquantity 10806

** sugar
xquantity 10901
xflagq 10901 .33

** lump sugar
xquantity 10902
xflagq 10902 .235

** sugar substitution
xquantity 10903
xflagq 10903 1.4

** candy
xquantity 10904
xflagq 10904 .36

** sweet
xquantity 10905
xflagq 10905 .3

** chocolate
xquantity 10906
xflagq 10906 75

** honey
xquantity 10907
xflagq 10907 120

** compotes
xquantity 10908
xflagq 10908 350

** jam
xquantity 10909
xflagq 10909 230

** ice cream
xquantity 10910
xflagq 10910 151

** chewing gum
xquantity 10911
xflagq 10911 3

** syrup
xquantity 10912
xflagq 10912 10

** other: do not include this
xquantity 10913
* xflagq 

** salt
xquantity 11001
xflagq 11001 75

** vinegar
xquantity 11002
xflagq 11002 25

** ketchup
xquantity 11003
xflagq 11003 90

** mayonnaise
xquantity 11004
xflagq 11004 0.19

** yeast
xquantity 11005
xflagq 11005 12.5

** spice
xquantity 11006
xflagq 11006 56

** babyfood
xquantity 11007
xflagq 11007 .3

** other: do not include this
xquantity 11008
* xflagq 

** green tea
xquantity 11101
xflagq 11101 100

** tea
xquantity 11102
xflagq 11102 30

** coffee
xquantity 11103
xflagq 11103 70

** cocoa
xquantity 11104
xflagq 11104 30


xquantity 11105
xflagq 11105 100

** other: do not include this
xquantity 11106
* xflagq 

** beverage
xquantity 11201
xflagq 11201 1.6

** juice
xquantity 11202
xflagq 11202 0.85

** pure water, bottled
xquantity 11203
xflagq 11203 3.5

** other: do not include this
xquantity 11204
* xflagq 

** vodka domestic
xquantity 11301
xflagq 11301 .36

** beer domestic
xquantity 11302
xflagq 11302 1.43

** vodka imported
xquantity 11303
xflagq 11303 .35

** beer imported
xquantity 11304
xflagq 11304 .8

** wine
xquantity 11305
xflagq 11305 0.3

** other: do not include this
xquantity 11306
* xflagq 

** cigarette imported
xquantity 11401
xflagq 11401 2.3

** cigarette domestic
xquantity 11402
xflagq 11402 2

** tobacco
xquantity 11403
xflagq 11403 50

** snuff
xquantity 11404
xflagq 11404 10

** other: do not include this
xquantity 11405
* xflagq  

rename flagq flagQ
tab flagQ, m
tab itemcode if flagQ==1, m
* flour accounts for 15% of the cases
sort newaimag month identif itemcode tenth
list newaimag month identif itemcode tenth qtot0 qpur0 aprice0 qfree0 qown0 if flagQ==1, sep(0) nolabel

****************************
*** Summarizing outliers ***
****************************

d flag*
tab1 flag*, m

* there are 4 variables flagging outliers, 1 will be excluded:
* (1) flag2 because deals with transactions per tenth, those can only be checked against the questionnaire

* so the 3 relevant flags are:
* (1) flag1: total quantity consumed vs subtotals
* (2) flagp: values
* (3) flagq: quantity outliers

******************************************************
* excluding categories where unit values do not apply
******************************************************
gen out=0
foreach n of numlist 10114 10115 10216 10217 10304 10410 10415 10508 10604 10608 10609 10713 10714 10806 10913 ///
	11008 11106 11204 11306 11405 {
	replace out=1 if itemcode==`n'
	}

* for these residual "other" categories, the only valid flags are total vs subtotals
* neither unit values nor quantities should be considered
foreach v of varlist flagP flagQ {
	replace `v'=0 if out==1
	}

gen flag = real("1" + string(flag1) + string(flagP) + string(flagQ))
label var flag "Flagged transactions"
label val flag flag
label define flag 1000 "No problem" 1001 Q 1010 P 1011 "P, Q" 1100 TvsS
* Q means problem with quantities, P problems with the unit value
* and TvsS problems with the total quantity vs the sum of the subtotals
tab flag
tab flag if flag>1e3, m
 
* two main findings:
* (1) 99.96% of the reported transactions seem fine, only 0.04% have been flagged for one reason or another
* (2) out of those flagged, 61.62% are unit values, 38.38% quantities

tab flag out, m

* so what to do?
* (1) if prices and quantities have been flagged ==> delete (no imputation can be made unless the questionnaire is checked out)
* (2) if quantities alone have been flagged ==> delete (harder to impute unless the questionnaire is checked out)
* (3) if only prices have been flagged ==> impute median prices
* (4) if total vs sub-totals have been flagged ==> check them out (visual inspection)

compress
drop pcq pcqf pcqs pcqt
sort identif itemcode tenth
save tempfood.dta, replace


*************************************************
* implementing corrections
*************************************************
count if flagP==1 & flagQ==1
drop if flagP==1 & flagQ==1
*drop if flagQ==1



**************************************************
* fixing some quantities for Totals vs Sub-totals
**************************************************

tab flag1, m
l qtot qpur qfree qown if flag1==1

egen x = rsum(q qf qs)
replace x = . if q==. & qf==. & qs==.

gen qtx = qt

l itemcode qt q qf qs x if flag1==1
* difficult to decide
* keep the original total because is generally lower than the sum of the parts
* overall this is a conservative approach
drop x



***************************
* fixing unit values
***************************

gen upricex = uprice
replace upricex = . if flagP==1


* household level: it does not matter to hhweight because all have the same hhweight within each household 
egen hhprice      = median(upricex), by(identif itemcode)

compress
save, replace


* cluster level
* now some clusters have more than 1 hhweight (due to the attempt of capturing informality)
use tempfood, clear
collapse (median) clusterprice=upricex [aw=hhweight], by(cluster itemcode)
save temp1, replace

* aimag level
use tempfood, clear
collapse (median) aimagprice=upricex [aw=hhweight], by(newaimag strata month itemcode)
save temp2, replace

* strata level
use tempfood, clear
collapse (median) strataprice=upricex [aw=hhweight], by(strata month itemcode)
save temp3, replace

* month level
use tempfood, clear
collapse (median) monthprice=upricex [aw=hhweight], by(month itemcode)
save temp4, replace

* national level
use tempfood, clear
collapse (median) itemprice=upricex [aw=hhweight], by(itemcode)
save temp5, replace

use tempfood, clear
sort cluster itemcode
merge cluster itemcode using temp1
tab _
drop _
sort newaimag strata month itemcode
merge newaimag strata month itemcode using temp2
tab _
drop _
sort strata month itemcode
merge strata month itemcode using temp3
tab _
drop _
sort month itemcode
merge month itemcode using temp4
tab _
drop _
sort itemcode
merge itemcode using temp5
tab _
drop _
sort identif itemcode tenth

foreach n of numlist 1/5 {
	erase temp`n'.dta
	}


foreach v of varlist hhprice clusterprice aimagprice strataprice monthprice itemprice {
	replace `v'=. if out==1
	}

count if upricex==.
count if upricex==. & hhprice!=.
replace upricex=hhprice if upricex==. & hhprice!=.

count if upricex==.
count if upricex==. & clusterprice!=.
replace upricex=clusterprice if upricex==. & clusterprice!=.

count if upricex==.
count if upricex==. & aimagprice!=.
replace upricex=aimagprice if upricex==. & aimagprice!=.

count if upricex==.
count if upricex==. & strataprice!=.
replace upricex=strataprice if upricex==. & strataprice!=.

count if upricex==.
count if upricex==. & monthprice!=.
replace upricex=monthprice if upricex==. & monthprice!=.

count if upricex==.
count if upricex==. & itemprice!=.
replace upricex=itemprice if upricex==. & itemprice!=.

count if upricex==.
count if upricex==. & out==1

* excluding transactions flagged with -out-, the imputed prices come from ==>
* 0% household, 52.8% cluster, 24.2,% aimag, 18,1% stratum, 0.097% month, 0.002% national

summ uprice upricex
summ uprice upricex if uprice!=.
summ uprice upricex if uprice==.

* the average price of the imputed cases pulls upward the total average price by around 3%. is this average issue ok?
* this could happen if most of the imputed cases are food items that are more expensive than the average food item
tab itemcode if uprice==. & upricex!=., m
* 30.76% of these cases are mutton, beef, goat meat, horse meat, camel meat and dried meat
* another 28.86% is milk, yougurt, eggs, dried curds, horse milk and curds
* and another 14.27% is edible animal fats, cream and melted butter
summ uprice
summ uprice if inrange(itemcode,10201,10206)
summ uprice if inrange(itemcode,10401,10406)
summ uprice if inrange(itemcode,10504,10506)
* with the exception of the dairy products, the other groups are more expensive


******************************
* Checking implicit spending *
******************************

gen vx = qtx*upricex
summ vx, det

scalar usd = 2472.67

* daily amount of reference in US$
count if vx!=. & vx>(5*scalar(usd))
tab itemcode if vx!=. & vx>(5*scalar(usd)), m
count if vx!=. & vx>(10*scalar(usd))
tab itemcode if vx!=. & vx>(10*scalar(usd)), m
sort newaimag month identif itemcode tenth
local xlinesize = c(linesize)
set linesize 155


list newaimag month identif itemcode tenth qtot0 qpur0 aprice0 qfree0 qown0 qtx upricex vx ///
	if vx!=. & vx>(5*scalar(usd)), sep(0) nolabel
set linesize `xlinesize'
* mostly meat & diary
* not many high values, a few very small expenses
* the tricky bit with values is that a small value is sensible, say bread, perhaps the household
* bought only 2 pieces of bread in the last ten days, that would give very low amounts
* high values are possible too, the family could be stocking or hoarding

tab itemcode if vx!=. & vx>(5*scalar(usd)), m
list itemcode tenth hhsize qtot0 qpur0 aprice0 qown0 qtx upricex vx if vx!=. & vx>(5*scalar(usd)), sep(0) 
* daily quantities are reasonable with the exception of other marmalades, sugar, jam
list itemcode tenth hhsize qtot0 qpur0 aprice0 qown0 qtx upricex vx if vx!=. & vx>(5*scalar(usd)), sep(0) nolabel
* these cases will be fixed based on visual inspection
l identif itemcode tenth upricex qtx vx if vx!=. & vx>(5*scalar(usd)) & inlist(itemcode,10913)
* making corrections ==>
gen high = vx!=. & vx>(5*scalar(usd))
tab high, m
drop high


*****************************
* summary
*****************************

* the 3 relevant variables will be qtx, upricex & vx, all in daily terms
summ itemcode qtx upricex vx
* if price (or expenditure) is missing, it means the food item was a residual category reporting only quantities
tab out if upricex==., m
tab out, m

compress
d
summ
save tempfood, replace

erase tempx.dta

clear
log close


