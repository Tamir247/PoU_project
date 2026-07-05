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
* DESCRIPTION:  	Prepare "NCT" dataset for ADePT

*
* SIMPLE PIPELINE:
*   1) Import national nutrient conversion table.
*   2) Harmonize item groups and diversity groups.
*   3) Append food-away-from-home nutrient record.
*   4) Save cleaned country nutrient table for joins.
*

clear all
set more off


	*import excel "$dbase\Undral_COUNTRY_NCT20200306 _FINAL.xlsx", sheet("stata") firstrow case(lower) clear
	import excel "$dbase\Undral_COUNTRY_NCT20260206_FINAL.xlsx", sheet("stata") firstrow case(lower) clear
	
	duplicates report item

	tab1 item_grp diversity_grp
	
	label val item_grp item_grp
			label define item_grp 1 "Ò®Ñ€ Ñ‚Ð°Ñ€Ð¸Ð°", add
			label define item_grp 2 "ÐœÐ°Ñ…, Ð¼Ð°Ñ…Ð°Ð½ Ð±Ò¯Ñ‚ÑÑÐ³Ð´ÑÑ…Ò¯Ò¯Ð½", add 
			label define item_grp 3 "Ð—Ð°Ð³Ð°Ñ, Ð´Ð°Ð»Ð°Ð¹Ð½ Ð±Ò¯Ñ‚ÑÑÐ³Ð´ÑÑ…Ò¯Ò¯Ð½", add 
			label define item_grp 4 "Ð¡Ò¯Ò¯, Ñ†Ð°Ð³Ð°Ð°Ð½ Ð¸Ð´ÑÑ", add 
			label define item_grp 5 "Ó¨Ó©Ñ… Ñ‚Ð¾Ñ", add 
			label define item_grp 6 "Ð–Ð¸Ð¼Ñ, Ð¶Ð¸Ð¼ÑÐ³ÑÐ½Ñ", add 
			label define item_grp 7 "Ð¥Ò¯Ð½ÑÐ½Ð¸Ð¹ Ð½Ð¾Ð³Ð¾Ð¾", add 
			label define item_grp 8 "Ð‘ÑƒÑƒÑ€Ñ†Ð°Ð³ ÑˆÐ¾Ñˆ", add 
			label define item_grp 9 "Ð§Ð¸Ñ…ÑÑ€, Ð°Ð¼Ñ‚Ñ‚Ð°Ð½", add 
			label define item_grp 10 "Ð¥Ð¾Ð¾Ð», Ð°Ð¼Ñ‚Ð»Ð°Ð³Ñ‡", add 
			label define item_grp 11 "Ð¦Ð°Ð¹, ÐºÐ¾Ñ„Ðµ", add 
			label define item_grp 12 "Ð¡Ð¾Ð³Ñ‚ÑƒÑƒÑ€ÑƒÑƒÐ»Ð°Ñ… Ð±ÑƒÑ  ÑƒÐ½Ð´Ð°Ð°", add 
			label define item_grp 13 "Ð¡Ð¾Ð³Ñ‚ÑƒÑƒÑ€ÑƒÑƒÐ»Ð°Ñ… ÑƒÐ½Ð´Ð°Ð°", add 
			label define item_grp 14 "Ó¨Ð½Ð´Ó©Ð³", add 
			label define item_grp 15 "Ð¢Ó©Ð¼Ñ", add 
			label define item_grp 16 "Ð¡Ð°Ð¼Ð°Ñ€", add
			label define item_grp 17 "Ð‘ÑƒÑÐ°Ð´", add
	label var item_grp "Food group-17"
	
	label val diversity_grp diversity_grp
			label define diversity_grp 1 "Ò®Ñ€ Ñ‚Ð°Ñ€Ð¸Ð°", add
			label define diversity_grp 2 "Ð‘ÑƒÐ»Ñ†ÑƒÑƒÑ‚ Ð½Ð¾Ð³Ð¾Ð¾, Ñ‚Ó©Ð¼Ñ", add 
			label define diversity_grp 3 "Ð Ð°Ð¼Ð¸Ð½Ð´ÑÐ¼ÑÑÑ€ Ð±Ð°ÑÐ»Ð°Ð³ Ñ…Ò¯Ð½ÑÐ½Ð¸Ð¹ Ð½Ð¾Ð³Ð¾Ð¾, Ð±ÑƒÐ»Ñ†ÑƒÑƒÑ‚ Ð½Ð¾Ð³Ð¾Ð¾", add 
			label define diversity_grp 4 "ÐÐ¾Ð³Ð¾Ð¾Ð½ Ð½Ð°Ð²Ñ‡Ð¸Ñ‚ Ð½Ð¾Ð³Ð¾Ð¾", add 
			label define diversity_grp 5 "Ð‘ÑƒÑÐ°Ð´ Ñ…Ò¯Ð½ÑÐ½Ð¸Ð¹ Ð½Ð¾Ð³Ð¾Ð¾", add 
			label define diversity_grp 6 "Ð Ð°Ð¼Ð¸Ð½Ð´ÑÐ¼ÑÑÑ€ Ð±Ð°ÑÐ»Ð°Ð³ Ð¶Ð¸Ð¼Ñ", add 
			label define diversity_grp 7 "Ð‘ÑƒÑÐ°Ð´ Ð¶Ð¸Ð¼Ñ", add 
			label define diversity_grp 8 "Ð”Ð¾Ñ‚Ð¾Ñ€ Ð¼Ð°Ñ…", add 
			label define diversity_grp 9 "ÐœÐ°Ñ…, Ð¼Ð°Ñ…Ð°Ð½ Ð±Ò¯Ñ‚ÑÑÐ³Ð´ÑÑ…Ò¯Ò¯Ð½", add 
			label define diversity_grp 10 "Ó¨Ð½Ð´Ó©Ð³", add 
			label define diversity_grp 11 "Ð—Ð°Ð³Ð°Ñ, Ð´Ð°Ð»Ð°Ð¹Ð½ Ð±Ò¯Ñ‚ÑÑÐ³Ð´ÑÑ…Ò¯Ò¯Ð½", add 
			label define diversity_grp 12 "Ð‘ÑƒÑƒÑ€Ñ†Ð°Ð³Ñ‚ ÑƒÑ€Ð³Ð°Ð¼Ð°Ð», ÑˆÐ¾Ñˆ Ð²Ð°Ð½Ð´ÑƒÐ¹, Ò¯Ñ€, ÑÐ°Ð¼Ð°Ñ€", add 
			label define diversity_grp 13 "Ð¡Ò¯Ò¯, ÑÒ¯Ò¯Ð½ Ð±Ò¯Ñ‚ÑÑÐ³Ð´ÑÑ…Ò¯Ò¯Ð½", add 
			label define diversity_grp 14 "Ó¨Ó©Ñ… Ñ‚Ð¾Ñ", add 
			label define diversity_grp 15 "ÐÐ¼Ñ‚Ñ‚Ð°Ð½", add 
			label define diversity_grp 16 "Ð¥Ð¾Ð¾Ð» Ð°Ð¼Ñ‚Ð»Ð°Ð³Ñ‡, ÑƒÐ½Ð´Ð°Ð°Ð½Ñ‹ Ð·Ò¯Ð¹Ð»Ñ", add
	label var diversity_grp "Dietary Diversity group-16"	
	
	
	preserve
		use "$data_temp/foodout_${survey_year}", clear
		collapse (mean) source, by(item) 
		gen desc_mon="Ð“Ð°Ð´ÑƒÑƒÑ€ Ñ…Ð¾Ð¾Ð»Ð»Ð¾Ð»Ñ‚"
		gen desc="Food away from home"
		gen fooditemindexmatching="C"
		gen refuse=0
		gen item_grp=17
		gen diversity_grp=17

		gen id=128
		tempfile fath
		save `fath'
	restore
	
		append using `fath'

		format %30s desc_mon desc 
		format %10.0g item_grp diversity_grp
		
		keep  id	item	desc_mon	desc	fooditemindexmatching	refuse	item_grp	diversity_grp	water	ash	fd_pro	fd_fat	fd_fib	fd_alc	carbohydratesincludingfiber	fd_car	calories	fd_kcal	calcium	iron	fe_anim	fe_nanim	zinc	folate	vit_c	vit_b1	vit_b2	retinol	betacar	vita	vit_b6	vit_b12	isoleuc	leucine	lysine	methion	phenyl	threon	trypto	valine	histid	cysteine	tyrosine

		sort item
		tab item
		drop if inlist(item, 11401, 11402, 11403, 11404, 11405)
		*drop if inlist(itemcode, 11001, 11203,11401, 11402, 11403, 11404, 11405)
		
		**check
		list item desc_mon if item_grp==0
		replace item_grp=17 if  item_grp==0
		
		list item desc_mon if diversity_grp==0
		
		gen item_grpAT=item_grp
		gen diversity_grpAT=diversity_grp
		
		summ 
		list item desc_mon if fd_car<0 
		replace fd_car=0 if fd_car<0 
		
		order item_grpAT, after(item_grp)
		order diversity_grpAT, after(diversity_grp)
		
		
saveold "$data_out/Country_nct_${survey_year}_with_Foodout.dta", version(12) replace

* stop removed – legacy recode notes below are kept as reference only

/*
codebook item, tab(99000)
			gen item_grp = 1 + irecode(item,10115,10217,10304,10415,10508,10609,10715,10805,10913,11011,11105, 11204,11306,11405)
tabstat item, by(item_grp) s(min max)
			
			 
			gen  diversity_grp=1 if item_grp==1 & (item!=10110 & item!=10111) 
				replace diversity_grp=1 if diversity_grp==. & item==10709 
				replace diversity_grp=9 if diversity_grp==. & item_grp==2 & (item!=10212 & item!=10217)
				replace diversity_grp=11 if diversity_grp==. & item_grp==3 
				replace diversity_grp=13 if diversity_grp==. & item_grp==4 & (item!=10403 & item!=10414 & item!=10411 & item!=10415)
				replace diversity_grp=14 if diversity_grp==. & item_grp==5
				replace diversity_grp=7 if diversity_grp==. & item_grp==6 & (item!=10607 & item!=10608)
				replace diversity_grp=5 if diversity_grp==. & item_grp==7 & (item!=10701 & item!=10703 & item!=10709 & item!=10710 & item!=10714 )
				replace diversity_grp=12 if diversity_grp==. & item_grp==8	
					replace diversity_grp=12 if diversity_grp==. & (item==10607 | item==10608)
					replace diversity_grp=12 if diversity_grp==. & (item==11007)
				replace diversity_grp=15 if diversity_grp==. & item_grp==9
					replace diversity_grp=15 if diversity_grp==. & (item==10110 | item==10111 | item==10415)
					replace diversity_grp=15 if diversity_grp==. & (item_grp==12 & item!=11203) 

				replace diversity_grp=16 if diversity_grp==. & (item_grp==10 & item!=11007) 
				replace diversity_grp=16 if diversity_grp==. & item_grp==11
					replace diversity_grp=16 if diversity_grp==. & (item==10411 | item==10710 )
					replace diversity_grp=16 if diversity_grp==. & (item==11203)
					replace diversity_grp=16 if diversity_grp==. & item_grp==13
			
				replace diversity_grp=8 if diversity_grp==. & (item==10212 | item==10217)
				replace diversity_grp=10 if diversity_grp==. & (item==10403 | item==10414)
				replace diversity_grp=2 if diversity_grp==. & (item==10701)
				replace diversity_grp=3 if diversity_grp==. & (item==10703)
				replace diversity_grp=4 if diversity_grp==. & (item==10714)			
			** diversity_grp does not classified for tobacco products
			
			tab item_grp diversity_grp,m
			tab diversity_grp, m

*/

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


/*

use "D:\18.FAO\NCT_Mongolia_final\country_nct_2020_0323_withfoodaway", clear 
count
drop if inlist(itemcode, 11401, 11402, 11403, 11404, 11405)
*drop if inlist(itemcode, 11001, 11203,11401, 11402, 11403, 11404, 11405)

saveold Country_nct_2020_2018_with_Foodout.dta, version(12) replace


********************************
