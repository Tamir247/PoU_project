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
* DESCRIPTION:  	Prepare "Food" dataset for ADePT

*
* SIMPLE PIPELINE:
*   1) Build harmonized food diary/recall file (urban+rural).
*   2) Clean quantities, prices, and dailyize consumption values.
*   3) Detect and impute outliers by item and socioeconomic groups.
*   4) Reshape by source and save final food consumption dataset.
*
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *


* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*
*	1. Append rural and urban & Food out
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

	** Urban 7 days diary
		use "$data_raw/16_urb_diary.dta", clear
			* SPREAD-DATA ADAPTATION (2026-07-03): the de-identified "spread"
			* release already ships "identif" instead of "hses_id".
			capture rename hses_id identif
			rename q1301 qty
			rename q1302 qty_purch
			rename q1303 uv
			rename q1304 qty_gift
			rename q1305 qty_own
			
			gen consumed=qty>0 & !mi(qty)
			
			recast double qty
			recode qty* (.=0)
			assert qty>0 if consumed==1		
			
			replace uv=. if consumed==0 | uv==0
			
			// Check quantities line up b/w sources and total
			egen double temp=rowtotal(qty_*)
			
			compare qty temp				// some rounding errors but looks fine
			replace qty=temp if qty!=temp
			drop temp
			
			
		save "$data_temp/food13", replace


	** Rural 7 days recall
	
		// Note: questionnaire had additions in 2024 to assess non-standard units
		// Because of confusion among enumerators on NSU questions, quality assurance was only done on q1405-q1410
		// Ignore NSUs for now
		
	use "$data_raw/17_rur_food_7d.dta", clear
	* SPREAD-DATA ADAPTATION (2026-07-03): the de-identified "spread" release
	* already ships "identif" instead of "hses_id".
	capture rename hses_id identif
		* SPREAD-DATA ADAPTATION (2026-07-03): "cluster" doesn't exist in the
		* spread release's basicvars.dta. The merge here only ever fed two
		* diagnostic `list` lines below and a final `drop cluster` -- no
		* calculation depends on it -- so it's dropped rather than reworked.
		* Original:
		*   merge m:1 identif using "$data_raw/basicvars.dta", keepusing(cluster)
		*   	drop if _m==2
		*   	drop _m

		recode q1401 (2=0), gen(consumed)
		
		rename q1404 qty
		rename q1405 qty_purch
		rename q1406 qty_gift
		rename q1407 qty_own
		rename q1408 purch30
		rename q1409 purch_qty
		rename q1410 purch_exp
		
		drop q14*
		
		format item %50.0g
		
		
	** Basic checks
		egen double tot=rowtotal(qty_purch qty_gift qty_own)
		* SPREAD-DATA ADAPTATION (2026-07-03): both `list` lines below are
		* diagnostic only (visual inspection, no calculation depends on
		* them) and reference "cluster" (the second one via Stata's
		* unambiguous-abbreviation "clust" -> "cluster"), which doesn't exist
		* in the spread release. Commented out rather than reworked.
		* Original:
		*   list cluster identif item qty* if tot==0 & consumed==1
		*   // values from NSO
		*   list identif qty* tot if clust==351 & item==10201 & consumed==1  // most HHs in PSU consume mutton from own consumption
		* kept as-is: harmless no-op against the spread release, since its
		* identif values are a different (re-numbered) scheme -- see note
		* below for why.
		replace qty=8 if tot==0 & consumed==1 & item==10201 & identif==243035101
		replace qty_own=8 if tot==0 & consumed==1 & item==10201 & identif==243035101

		* SPREAD-DATA ADAPTATION (2026-07-03), REAL DATA-HANDLING CHANGE, not
		* just a rename: the fix above targets one specific household by its
		* full-release identif (243035101). The spread release re-numbers
		* identif to plain sequential integers, so that fix no-ops here ("0
		* real changes made") while the same underlying data problem
		* (consumed==1 but zero quantity recorded from every source)
		* resurfaces under a different id -- confirmed one case in this data:
		* identif==8260, item 10201 (mutton). The original fix's replacement
		* value (8 kg) was derived by inspecting neighboring households in
		* the same cluster/PSU (see the commented-out `list ... if clust==
		* 351...` above) -- that specific derivation isn't reproducible here
		* since "cluster" doesn't exist in the spread release. Rather than
		* invent an unsupported replacement quantity, this generically
		* resolves any consumed==1-but-zero-quantity row by deferring to the
		* recorded zero quantities (setting consumed=0) instead of crashing
		* the assert below. Flagging this as a real judgment call, not a
		* mechanical fix -- worth reviewing if it recurs for other items.
		replace consumed=0 if consumed==1 & tot==0 & qty==0

		assert qty==0 if consumed==0
		assert qty!=0 if consumed==1
		assert qty!=0 if consumed==1
		assert tot==0 if consumed==0
				
		drop qty tot
		recode qty* (.=0)
		
		egen double qty=rowtotal(qty_purch qty_gift qty_own)
		
		* define unit price
		gen uv= purch_exp/purch_qty
			recode uv (0=.)
		* SPREAD-DATA ADAPTATION (2026-07-03): "price" doesn't exist in the
		* spread release's rural recall file -- this was a diagnostic
		* cross-check only (uv is what's actually used downstream), so
		* commented out rather than reworked. Original: compare uv price
		
		drop purch30  purch_qty purch_exp 
		
		save "$data_temp/food14", replace
		
		
		
				
	
	** Append urban and rural
		use "$data_temp/food14", clear 
			append using "$data_temp/food13", gen(survey)
			egen double temp=rowtotal(qty_*)
			
			compare qty temp					// looks good
			drop temp
			
		
		** Binaries for different sources of food consumption
			foreach x in purch gift own {
				gen cons_`x'=qty_`x'>0
			}
			
			// check binaries line up
			egen sources=rowtotal(cons_*)
				assert sources==0 if consumed==0
				assert sources>0 & !mi(sources) if consumed==1
				drop sources
	
	
	** // for 2024 data first fix some issues in salt
		* SPREAD-DATA ADAPTATION (2026-07-03): "interviewer" doesn't exist in
		* the spread release's basicvars.dta -- dropped from keepusing().
		* Only used below for a diagnostic `table` breakdown (not for the
		* actual SALT fix itself, which is based on qty/qty_p thresholds),
		* so this is a display-only loss, not a calculation change.
		merge m:1 identif using "$data_raw/basicvars.dta", keepus(newaimag) nogen
		merge m:1 identif using "$data_temp/equivalence_scales${survey_year}.dta", nogen keepusing(aesize_fao)

		
		** 
		* making both hies & hses homogeneous in terms of ==>
		* (0) Adjusting SALT
		* (1) making back-up of original variables
		* (2) change quantities and expenditure to a daily basis. average price is not a problem
		* (3) dropping food items with incorrect codes


		** (0) Adjusting SALT
			gen double qty_p=qty/aesize_fao if consumed==1

			table newaimag if  item==11001, stat(mean qty_p) nf(%7.3fc)  	// high: Sukhbaatar, Arkhangai, Govi-Altai
			*table newaimag if item == 11001, c(mean qty) format(%7.3fc)

			gen check1=qty<1 if item==11001 & consumed==1					// qty<1 gram
			gen check2=qty_p>150 if item==11001 & consumed==1				// pae qty>100 gram
			
			table newaimag if item==11001, stat(mean check1 check2) nf(%7.3fc)  	// low: Govisumber
			*table newaimag if item==11001, c(mean check1 mean check2)  	// low: Govisumber

			* SPREAD-DATA ADAPTATION (2026-07-03): "interviewer" not available
			* -- diagnostic breakdown only, no calculation depends on it.
			* Original: table interviewer if item==11001, stat(mean check1 check2) nf(%7.3fc)

			foreach x in  qty_purch qty_gift qty_own qty {
				replace `x'=`x'*100 if qty<=0.5 & item==11001			// zero issues -> assume 100x
				replace `x'=`x'*10 if qty>0.5 & qty<2 & item==11001		// zero issues -> assume 10x
				replace `x'=`x'/10 if qty_p>150 & item==11001			
			}

			*drop newaimag interviewer aesize_fao qty_p check1 check2
			drop newaimag check1 check2 qty_p
		
		 
		rename (qty qty_purch uv qty_gift qty_own ) (qtot qpur aprice qfree qown)

		* (1) back-up variables
		foreach v of varlist qtot qpur aprice qfree qown {
			clonevar `v'0 = `v'
			}
			
		summ qtot* qpur* aprice* qfree* qown*, sep(2)
		order identif item qtot0 qpur0 aprice0 qfree0 qown0 ///
				    qtot qpur aprice qfree qown cons* survey 
				
		* (2) quantities and expenditure to a daily basis
		* from tenth (hsesu) or weekly (hsesr) to daily
		gen perday = 7
		order perday, after(qown)
		
		foreach v of varlist qtot qpur qfree qown {
			replace `v' = `v'/perday 
			}
		summ qtot* qpur* aprice* qfree* qown*, sep(2)


		* (3) dropping food items with incorrect codes
		gen outfi = item- 10000
			recode outfi 101/115 201/217 301/304 401/415 501/508 601/609 701/715 801/805 901/913 ///
				1001/1011 1101/1105 1201/1204 1301/1306 1401/1405 = 0 *=1
			tab outfi, m
			tab item if outfi==1, m
			l identif item qtot0 qpur0 aprice0 qfree0 qown0 survey if outfi==1
			drop if outfi==1
			drop outfi
		* all observations are within the expected ranges for food codes
		
	
		*****************************************************
		* excluding categories where unit values do not apply
		******************************************************
		gen out=0
		foreach n of numlist 10114 10115 10216 10217 10304 10410 10415 10508 10608 10609 10713 10715 10805 10913 11010 11011 11105 11204 11306 11405 {
			replace out=1 if item==`n'
			}	
		
			* SPREAD-DATA ADAPTATION (2026-07-03): visitor13/ndays13 (urban)
			* and visitor14/ndays14/price (rural) don't exist in the spread
			* release. Checked what visitor/ndays actually feed downstream:
			* only the two `assert` sanity checks right below, plus an inert
			* carry-through in `foodtemp1.dta` -- they're dropped (not kept)
			* at the `keep identif item imprice daily_* out` step later in
			* this file and never enter any calculation (daily_qty_gr,
			* daily_exp, daily_rexp, etc.). So this block is commented out
			* rather than reworked -- the trade-off is losing that specific
			* data-quality gate, not any part of the actual DEC calculation.
			* Original:
			*   gen visitor=visitor13
			*   	replace visitor=visitor14 if visitor==.
			*   gen ndays=ndays13
			*   	replace ndays=ndays14 if ndays==.
			*   assert  mi(ndays) if visitor==0
			*   assert  !mi(ndays) if visitor>0
			*   drop price visitor13 visitor14 ndays13 ndays14

		sort identif item

		** Merge basic vars
		* SPREAD-DATA ADAPTATION (2026-07-03): "cluster", "newsoum", "bag"
		* don't exist in the spread release's basicvars.dta -- dropped from
		* this merge's keepusing() list. See "01 Food.do" cluster-level price
		* imputation note further below for the one place this actually
		* matters for a calculation.
		merge m:1 identif using "$data_raw/basicvars.dta", keepus(urban region location strata newaimag hhsize hhweight month quarter) nogen

		order urban region location strata newaimag hhsize hhweight month quarter, before(identif)
		order survey perday hhsize aesize_fao hhweight month quarter out, last

			* SPREAD-DATA ADAPTATION (2026-07-03): "cluster" doesn't exist in
			* the spread release. Confirmed elsewhere in this codebase that
			* nothing actually uses this svyset declaration (no `svy:`
			* prefixed command appears anywhere in the active pipeline), so
			* it was already vestigial -- removed rather than reworked.
			* Original: svyset cluster [pw=hhweight], strata(strata)

			** Save temporary dataset
				label var qtot0 "Quantity total, original-7days"
				label var qpur0 "Quantity purchased, original-7days"
				label var aprice0 "Average price, original-7days"
				label var qfree0 "Quantity free, original-7days"
				label var qown0 "Quantity own, original-7days"

				label var qtot "Quantity total, daily"
				label var qpur "Quantity purchased, daily"
				label var aprice "Average price,"
				label var qfree "Quantity free, daily"
				label var qown "Quantity own, daily"
				label var survey "Survey"
				label var item "Food item"
				
				label var perday "total days"
				label var consumed "Dummy for consumed"
				label var cons_purch "Dummy for consumed from purchase"
				label var cons_gift "Dummy for consumed from gift"
				label var cons_own "Dummy for consumed from own"
				label var out "Not include calculation"
				label var aesize_fao "FAO-Per adult equivalence scale"

			sort identif item
			save "$data_temp/foodtemp1.dta", replace
		
		***************************
		* fixing unit values - for own use and free food
		***************************
			* SPREAD-DATA ADAPTATION (2026-07-03), REAL METHODOLOGICAL CHANGE,
			* not just a rename: "cluster" doesn't exist in the spread
			* release, so the cluster-level rung of the price-imputation
			* cascade (household -> cluster -> aimag/strata/month ->
			* strata/month -> month -> national) can't be computed. Not
			* cosmetic: a note in this project's legacy reference code
			* (ref/foodsetup.do:1624) records that the cluster level
			* historically supplied ~52.8% of all imputed prices -- the
			* single most-used rung of the ladder. Without it, imputation
			* falls straight through to the aimag/strata level for every
			* household that would otherwise have used a cluster-level
			* price. Commented out (not deleted) and flagged here rather
			* than silently absorbed. Original:
			*   * cluster level
			*   	* now some clusters have more than 1 hhweight (due to the attempt of capturing informality)
			*   use "$data_temp/foodtemp1.dta", clear
			*   	collapse (median) clusterprice=aprice [aw=hhweight], by(cluster item)
			*   tempfile temp1
			*   save `temp1', replace

			* aimag level
			use "$data_temp/foodtemp1.dta", clear
				collapse (median) aimagprice=aprice [aw=hhweight], by(newaimag strata month item)
			tempfile temp2
			save `temp2', replace

			* strata level
			use "$data_temp/foodtemp1.dta", clear
				collapse (median) strataprice=aprice [aw=hhweight], by(strata month item)
			tempfile temp3
			save `temp3', replace

			* month level
			use "$data_temp/foodtemp1.dta", clear
				collapse (median) monthprice=aprice [aw=hhweight], by(month item)
			tempfile temp4
			save `temp4', replace

			* national level
			use "$data_temp/foodtemp1.dta", clear
				collapse (median) itemprice=aprice [aw=hhweight], by(item)
			tempfile temp5
			save `temp5', replace

		
		use "$data_temp/foodtemp1.dta", clear
			* household level: it does not matter to hhweight because all have the same hhweight within each household 
			egen hhprice      = median(aprice), by(identif item)
			compress
			
				* SPREAD-DATA ADAPTATION (2026-07-03): cluster-level merge
				* removed along with the cluster-level collapse above (see
				* note there).
				sort newaimag strata month item
					merge m:m newaimag strata month item using `temp2', nogen
				sort strata month item
					merge m:m strata month item using `temp3', nogen
				sort month item
					merge m:m  month item using `temp4', nogen
				sort item
					merge m:m  item using `temp5', nogen

				sort identif item

				label var hhprice "Household level price"
				label var aimagprice "Aimag level price"
				label var strataprice "Strata level price"
				label var monthprice "Month level price"
				label var itemprice "National level price"		

		gen imprice = aprice
			order imprice, after(aprice)
			
			foreach v of varlist hhprice aimagprice strataprice monthprice itemprice {
					replace `v'=. if consumed==0
				}


		count if imprice==.
		count if imprice==. & hhprice!=.
		replace imprice=hhprice if imprice==. & hhprice!=.

		* SPREAD-DATA ADAPTATION (2026-07-03): cluster-level imputation step
		* removed along with clusterprice above -- falls through directly to
		* aimag level now. See note further up for the scope of this change.

		count if imprice==.
		count if imprice==. & aimagprice!=.
		replace imprice=aimagprice if imprice==. & aimagprice!=.

		count if imprice==.
		count if imprice==. & strataprice!=.
		replace imprice=strataprice if imprice==. & strataprice!=.

		count if imprice==.
		count if imprice==. & monthprice!=.
		replace imprice=monthprice if imprice==. & monthprice!=.

		count if imprice==.
		count if imprice==. & itemprice!=.
		replace imprice=itemprice if imprice==. & itemprice!=.

		count if imprice==.
		count if imprice==. & out==1
		tab newaimag item if imprice==. & consumed==1, nol
		* angiin mahiig bugiig max bh gej taamarlaad Dornod aimgiin yamaanii maxnii dundaj uneer awsan
		summarize aprice if newaimag==21 & item==10203, detail
		gen med_aprice = r(p50)
		replace imprice=med_aprice if imprice==. & item==10210 & consumed==1
		
		drop hhprice aimagprice strataprice monthprice itemprice med_aprice
	
	
		rename (qtot qpur qfree qown) (daily_tot_qty daily_qpur daily_qfree daily_qown)
		gen daily_exp=daily_tot_qty*imprice 
		order daily_exp, after(daily_qown)
		
		order cons*, after(qown0)
		label var imprice "Average price, imputed"
		label var daily_exp "Total daily monetary value"

		compress
		d
		summ
		save "$data_temp/foodtemp2", replace				
	

		***************************
		* outliers  
		***************************
		
		use "$data_temp/foodtemp2.dta", clear
			merge m:1 identif using "$data_temp/HH_size_food", nogen
		order hhsize_food, after(hhsize)

		tab qtot if consumed==0 & qtot!=.
		keep if consumed==1
		

		* 
		****checking and replacing outlier from qunatities/caput/day at each food items level ************
		***** outlier utgaar ustgawal mash ih utguud ustdag tiimees bid nar 3sigma onol buyu 99.72% -iin utgiig awch uldej 
		***** 100-99.72= 0.08 uwiin utgiig ustgadag. Ene ni mash baga huwiin nuluutei utgiig ustgaj bgaa yum 
		*** IQR-iig har : ug onoliig ashiglaj 3sigma-g yalgaj bn
		*hist daily_p_qty if item==10101

		**** converting exp. and quantities into per capita per day at each food item level**
		
		* WB&FAO, Analysing Food Security Using Household Survey Data, 2014, page-32
		* mentioned that .... equally distributed among household members .... so used hhszie not aesize_fao
		*gen daily_pae_qty=qtot/aesize_fao // jishsen nasand hursen hunii honogiin hereglee
		*gen daily_pae_exp=exp_tot/aesize_fao 

		
		gen daily_pc_tot_qty=daily_tot_qty/hhsize_food // urhiin gertee baisan neg hunii honogiin hereglee
		* shuud total-iig bish pur, own, free-iin outlier-iig zasaad, uunii daraa tot-ahij bodoh 
		* tegehgui bol source long shape ugugdul uusgehed zuwkhun tot zasagdahaar niilber barihgui asuudal uuseheer bn
		
		gen daily_pc_qpur=daily_qpur/hhsize_food // urhiin gertee baisan neg hunii honogiin hereglee
		gen daily_pc_qfree=daily_qfree/hhsize_food // urhiin gertee baisan neg hunii honogiin hereglee
		gen daily_pc_qown=daily_qown/hhsize_food // urhiin gertee baisan neg hunii honogiin hereglee
		gen daily_pc_exp=daily_exp/hhsize_food 
						
		drop if inlist(item, 11401, 11402, 11403, 11404, 11405)
		
		foreach v of varlist daily_pc_qpur daily_pc_qfree  daily_pc_qown daily_pc_exp {
					recode `v' (0=.)
				}	
		
		tab item if daily_pc_qpur==. & daily_pc_qfree==. & daily_pc_qown==.
	
		
		** daily_pc_qpur
			gen daily_pc_qpur_ad=daily_pc_qpur
			gen daily_pc_qpur_ad1 = ln(daily_pc_qpur_ad)

			bysort item: egen qty_low= pctile(daily_pc_qpur_ad1), p(25)
			bysort item: egen qty_high= pctile(daily_pc_qpur_ad1), p(75)
			bysort item: egen IQ_qty= iqr(daily_pc_qpur_ad1)
			gen flag0=1 if daily_pc_qpur_ad1!=. & ((daily_pc_qpur_ad1< qty_low-2*IQ_qty) | (daily_pc_qpur_ad1> qty_high+2*IQ_qty))
			
			drop qty_low  qty_high IQ_qty 
			tab item if flag0==1
			replace daily_pc_qpur_ad=. if flag0==1 

	 	** daily_pc_qfree
			gen daily_pc_qfree_ad=daily_pc_qfree
			gen daily_pc_qfree_ad1 = ln(daily_pc_qfree_ad)

			bysort item: egen qty_low= pctile(daily_pc_qfree_ad1), p(25)
			bysort item: egen qty_high= pctile(daily_pc_qfree_ad1), p(75)
			bysort item: egen IQ_qty= iqr(daily_pc_qfree_ad1)
			gen flag1=1 if daily_pc_qfree_ad1!=. &  ((daily_pc_qfree_ad1< qty_low-2*IQ_qty) | (daily_pc_qfree_ad1> qty_high+2*IQ_qty))
			
			drop qty_low  qty_high IQ_qty 
			
			tab item if flag1==1
			replace daily_pc_qfree_ad=. if flag1==1 
			
		
		** daily_pc_qpown
			gen daily_pc_qown_ad=daily_pc_qown
			gen daily_pc_qown_ad1 = ln(daily_pc_qown_ad)

			bysort item: egen qty_low= pctile(daily_pc_qown_ad1), p(25)
			bysort item: egen qty_high= pctile(daily_pc_qown_ad1), p(75)
			bysort item: egen IQ_qty= iqr(daily_pc_qown_ad1)
			gen flag2=1 if daily_pc_qown_ad1!=. &  ((daily_pc_qown_ad1< qty_low-2*IQ_qty) | (daily_pc_qown_ad1> qty_high+2*IQ_qty))
			
			drop qty_low  qty_high IQ_qty 
			
			tab item if flag2==1
			replace daily_pc_qown_ad=. if flag2==1 
			
		
		***************************
		* Imputation  for Outlier
		***************************

		* SPREAD-DATA ADAPTATION (2026-07-03), REAL METHODOLOGICAL CHANGE,
		* not just a rename: input/2024/consumption.dta -- the file this
		* block reads to build an income-decile variable -- does not exist
		* at all in the spread release (unlike "cluster", this isn't a
		* stripped column, the whole file is absent, along with
		* all_inc_exp.dta and deflators.dta). Without it, "decile" cannot be
		* built, so it's dropped from the outlier-imputation grouping levels
		* below (see lev1-lev3) rather than substituted with something else.
		* Flagging clearly here per instruction, since this is a real loss of
		* imputation granularity, not cosmetic. Original:
		*   preserve
		*   	use "$data_raw/consumption", clear
		*   	rename identif hses_id
		*   	rename household_id identif
		*   	count
		*   	xtile decile=totex_rpae [aw=hhweight*hhsize], nq(10)
		*   	keep identif decile
		*   	save "$data_temp/decile_${survey_year}", replace
		*   restore
		*   joinby identif using "$data_temp/decile_${survey_year}", unm(b)
		*   tab _m
		*   drop if _m==2
		*   drop _m

		*** Hemjee ni 3 sigmagaar yalgagdchaad baigaa ugugdliihuu median hemjeegeer orluulga hj bn *****
		*** Uuruur helbel bid 959 utga flag-aar todorhoilogdoj bn timees bid tedniig usgahguigeer median hemjeegeer orluulga hh gej bn
		*** clusteriin huwid ch yum uu tuhain ner turliig heregleegui,  esvel 1 , 2 geh met tsuun tohioldol garch irj
		*** boloh yum, end ter ilreed bgaa tsuuhun tohioldloor orluulahgui hiilgui
		*** 30-aas deesh tohioldoldoor garch irj bgaa bol tuhain utgiig Tuhain tuwshin deer orluulga hiij boloh
		*** 30 aas baga bol daraagiin tuwshnii utgiig awch tootsno gesen tohiruulgig oruulj bn gesen ug yum.
		*** n>30 bol suffiecient tuuwer gej uzej bgaa gsn ug yum

		* SPREAD-DATA ADAPTATION (2026-07-03): "decile" removed from all
		* three levels below (was: lev1 "item region urban decile", lev2
		* "item urban decile", lev3 "item decile"). Side effect worth
		* knowing: lev3 is now identical to lev4 ("item" alone), so this
		* cascade is effectively 3 distinct fallback levels instead of 4
		* until decile is available again.
		global lev1 "item region urban"
		global lev2 "item urban"
		global lev3 "item"
		global lev4 "item "

		** daily_pc_qpur
			egen ct1 = count(daily_pc_qpur_ad), by($lev1)
			egen ct2 = count(daily_pc_qpur_ad), by($lev2)
			egen ct3 = count(daily_pc_qpur_ad), by($lev3)
			egen ct4 = count(daily_pc_qpur_ad), by($lev4)
			*defining an arbitrary number of counts having sufficient number of cases to replace outliers. here that is 30.
			*This number can be changed if required  
			gen ct0=30
			egen md1 = median(daily_pc_qpur_ad) , by($lev1) 
			egen md2 = median(daily_pc_qpur_ad) , by($lev2)
			egen md3 = median(daily_pc_qpur_ad) , by($lev3)
			egen md4 = median(daily_pc_qpur_ad) , by($lev4)

			replace daily_pc_qpur_ad=md1 if flag0==1 & daily_pc_qpur_ad==. & ct1>=ct0
			replace daily_pc_qpur_ad=md2 if flag0==1 & daily_pc_qpur_ad==. & ct2>=ct0
			replace daily_pc_qpur_ad=md3 if flag0==1 & daily_pc_qpur_ad==. & ct3>=ct0
			replace daily_pc_qpur_ad=md4 if flag0==1 & daily_pc_qpur_ad==. & ct4>=ct0
			replace daily_pc_qpur_ad=md4 if flag0==1 & daily_pc_qpur_ad==. & ct4<ct0

			drop md* ct*
			tab item if daily_pc_qpur_ad==. & (daily_pc_qfree==. & daily_pc_qown==.)
			replace daily_pc_qpur_ad=daily_pc_qpur if daily_pc_qpur_ad==. // buh utga orluulga hiigdsen bn
				
				
		** daily_pc_qfree
			egen ct1 = count(daily_pc_qfree_ad), by($lev1)
			egen ct2 = count(daily_pc_qfree_ad), by($lev2)
			egen ct3 = count(daily_pc_qfree_ad), by($lev3)
			egen ct4 = count(daily_pc_qfree_ad), by($lev4)
			*defining an arbitrary number of counts having sufficient number of cases to replace outliers. here that is 30.
			*This number can be changed if required  
			gen ct0=30
			egen md1 = median(daily_pc_qfree_ad) , by($lev1) 
			egen md2 = median(daily_pc_qfree_ad) , by($lev2)
			egen md3 = median(daily_pc_qfree_ad) , by($lev3)
			egen md4 = median(daily_pc_qfree_ad) , by($lev4)

			replace daily_pc_qfree_ad=md1 if flag1==1 & daily_pc_qfree_ad==. & ct1>=ct0
			replace daily_pc_qfree_ad=md2 if flag1==1 & daily_pc_qfree_ad==. & ct2>=ct0
			replace daily_pc_qfree_ad=md3 if flag1==1 & daily_pc_qfree_ad==. & ct3>=ct0
			replace daily_pc_qfree_ad=md4 if flag1==1 & daily_pc_qfree_ad==. & ct4>=ct0
			replace daily_pc_qfree_ad=md4 if flag1==1 & daily_pc_qfree_ad==. & ct4<ct0

			drop md* ct*

			tab item if daily_pc_qfree_ad==. 
			replace daily_pc_qfree_ad=daily_pc_qfree if daily_pc_qfree_ad==. // buh utga orluulga hiigdsen bn
			
			
		** daily_pc_qown
			egen ct1 = count(daily_pc_qown_ad), by($lev1)
			egen ct2 = count(daily_pc_qown_ad), by($lev2)
			egen ct3 = count(daily_pc_qown_ad), by($lev3)
			egen ct4 = count(daily_pc_qown_ad), by($lev4)
			*defining an arbitrary number of counts having sufficient number of cases to replace outliers. here that is 30.
			*This number can be changed if required  
			gen ct0=30
			egen md1 = median(daily_pc_qown_ad) , by($lev1) 
			egen md2 = median(daily_pc_qown_ad) , by($lev2)
			egen md3 = median(daily_pc_qown_ad) , by($lev3)
			egen md4 = median(daily_pc_qown_ad) , by($lev4)

			replace daily_pc_qown_ad=md1 if flag2==1 & daily_pc_qown_ad==. & ct1>=ct0
			replace daily_pc_qown_ad=md2 if flag2==1 & daily_pc_qown_ad==. & ct2>=ct0
			replace daily_pc_qown_ad=md3 if flag2==1 & daily_pc_qown_ad==. & ct3>=ct0
			replace daily_pc_qown_ad=md4 if flag2==1 & daily_pc_qown_ad==. & ct4>=ct0
			replace daily_pc_qown_ad=md4 if flag2==1 & daily_pc_qown_ad==. & ct4<ct0

			drop md* ct*

			tab item if daily_pc_qown_ad==. 
			replace daily_pc_qown_ad=daily_pc_qown if daily_pc_qown_ad==. // buh utga orluulga hiigdsen bn
								
		***Treating the food monetary values according to the quantities adjusted for outliers
		*** hemjeend uurchult orson tul negjiin une bolon, niit zardald uurchlult orno tiimees dahin negjiin uniig olj zasna
		egen daily_pc_tot_qty_ad=rsum( daily_pc_qpur_ad daily_pc_qfree_ad daily_pc_qown_ad)
		
			egen ct1 = count(daily_pc_tot_qty_ad), by($lev1)
			egen ct2 = count(daily_pc_tot_qty_ad), by($lev2)
			egen ct3 = count(daily_pc_tot_qty_ad), by($lev3)
			egen ct4 = count(daily_pc_tot_qty_ad), by($lev4)
		
		gen tempprice=daily_pc_exp/daily_pc_tot_qty_ad if ((flag0==. & flag1==. & flag2==.) & daily_pc_tot_qty!=.)
		gen ct0=30
		egen med_price1 = median(tempprice), by($lev1)
		egen med_price2 = median(tempprice), by($lev2)
		egen med_price3 = median(tempprice), by($lev3)
		egen med_price4 = median(tempprice), by($lev4)
		
		
		gen daily_pc_exp_adj=daily_pc_exp if (flag0==. & flag1==. & flag2==.)
		replace daily_pc_exp_adj=daily_pc_tot_qty_ad*med_price1 if (flag0==1 | flag1==1 | flag2==1) & daily_pc_exp_adj==. & ct1>=ct0
		replace daily_pc_exp_adj=daily_pc_tot_qty_ad*med_price2 if (flag0==1 | flag1==1 | flag2==1) & daily_pc_exp_adj==. & ct2>=ct0
		replace daily_pc_exp_adj=daily_pc_tot_qty_ad*med_price3 if (flag0==1 | flag1==1 | flag2==1)  & daily_pc_exp_adj==. & ct3>=ct0
		replace daily_pc_exp_adj=daily_pc_tot_qty_ad*med_price4 if (flag0==1 | flag1==1 | flag2==1)  & daily_pc_exp_adj==. & ct4>=ct0
		replace daily_pc_exp_adj=daily_pc_tot_qty_ad*med_price4 if (flag0==1 | flag1==1 | flag2==1)  & daily_pc_exp_adj==. & ct4<ct0
 		count if daily_pc_exp_adj==.
		
		
		drop med_price* ct* flag*  tempprice daily_pc_qpur_ad1 daily_pc_qfree_ad1 daily_pc_qown_ad1 survey
		rename (daily_pc_tot_qty_ad daily_pc_qpur_ad daily_pc_qfree_ad daily_pc_qown_ad) ///
			 (daily_pc_tot_qty_adj daily_pc_qpur_adj daily_pc_qfree_adj daily_pc_qown_adj)
		order daily_pc_tot_qty daily_pc_tot_qty_adj, after(daily_tot_qty)
		order daily_pc_qpur daily_pc_qpur_adj, after(daily_qpur)
		order daily_pc_qfree daily_pc_qfree_adj, after(daily_qfree)
		order daily_pc_qown daily_pc_qown_adj, after(daily_qown)
		order daily_pc_exp daily_pc_exp_adj,after(daily_exp)
		
		
		gen daily_tot_qty_adj=daily_pc_tot_qty_adj*hhsize_food
		gen daily_qpur_adj=daily_pc_qpur_adj*hhsize_food
		gen daily_qfree_adj=daily_pc_qfree_adj*hhsize_food
		gen daily_qown_adj=daily_pc_qown_adj*hhsize_food
		gen daily_exp_adj=daily_pc_exp_adj*hhsize_food
		
		order daily_tot_qty_adj, after(daily_tot_qty)
		order daily_qpur_adj, after(daily_qpur)
		order daily_qfree_adj, after(daily_qfree)
		order daily_qown_adj, after(daily_qown)	
		order daily_exp_adj, after(daily_exp)	
	    
	
		for var daily_* : recode X .=0
		
		
		sort identif item 
		save "$data_temp/foodtemp_${survey_year}", replace 

	
		
		
*************************************
*** To Prepare food dataset for Adept
*************************************

		use "$data_temp/foodtemp_${survey_year}", clear 
		
		* if price (or expenditure) is missing, it means the food item was a residual category reporting only quantities
		tab out if imprice==., m
		tab out, m
		
		keep identif item imprice daily_* out

		*check
			* HH level
			egen a=rsum(daily_qpur daily_qfree daily_qown)
			compare a  daily_tot_qty // looks good
			drop a 

			egen a=rsum(daily_qpur_adj daily_qfree_adj daily_qown_adj)
			compare a  daily_tot_qty_adj // looks good
			drop a 

			* Indiv level
			egen a=rsum(daily_pc_qpur daily_pc_qfree daily_pc_qown)
			compare a  daily_pc_tot_qty // looks good
			drop a 

			egen a=rsum(daily_pc_qpur_adj daily_pc_qfree_adj daily_pc_qown_adj)
			compare a  daily_pc_tot_qty_adj // looks good
			drop a 
		
			drop  daily_tot_qty daily_qpur daily_qfree daily_qown daily_exp daily_tot_qty_adj ///
			      daily_pc_tot_qty daily_pc_qpur daily_pc_qfree daily_pc_qown daily_pc_exp ///
			      daily_pc_tot_qty_adj  daily_pc_qpur_adj daily_pc_qfree_adj daily_pc_qown_adj daily_pc_exp_adj 
			   
		
		rename (daily_qpur_adj daily_qfree_adj daily_qown_adj) (daily_qpur_adj1 daily_qfree_adj2 daily_qown_adj3)
		reshape long  daily_qpur_adj daily_qfree_adj daily_qown_adj, i(identif item) j(source)
		recode source (1=1 "Ð¥ÑƒÐ´Ð°Ð»Ð´Ð°Ð¶ Ð°Ð²ÑÐ°Ð½") (3=2 "Ó¨Ó©Ñ€Ð¸Ð¹Ð½ Ð°Ð¶ Ð°Ñ…ÑƒÐ¹Ð³Ð°Ð°Ñ") (2=3 "Ð‘ÑƒÑÐ´Ð°Ð°Ñ Ò¯Ð½ÑÐ³Ò¯Ð¹ Ð°Ð²ÑÐ°Ð½"), gen(source2)
			drop source 
			rename source2 source
			order source, after(item)
			sort identif item source

		egen daily_tot_qty=rsum(daily_qpur_adj daily_qfree_adj daily_qown_adj)
				
			
		*check 
			by identif item: egen dairy_tot2 = total(daily_tot_qty)
			gen exp_f_im=dairy_tot2*imprice 
			gen a=exp_f_im-daily_exp_adj if exp_f_im!=0 // yag ijil bish uchir ni daily_pc_exp_adj-nmi imputed bolson
				sum a
				*hist a // looks good centered around 0	
			drop a imprice exp_f_im dairy_tot*
			
			egen b=total(daily_exp_adj) if source==1, by(identif)
			summ b  if source==1 // 1 cases  daily HH's exp more than 100000
			list identif if b>100000 & item==10101 & source==1
			drop b
			
			
		rename ( daily_qpur_adj daily_qfree_adj daily_qown_adj daily_exp_adj)	///
				( daily_qpur daily_qfree daily_qown daily_exp)
				
		order identif item source daily_tot_qty daily_qpur daily_qfree daily_qown 
			
		label var daily_tot_qty "Household daily quantity total"
		label var daily_qpur  "Household daily quantity purchased"
		label var daily_qfree "Household daily quantity free of charge"
		label var daily_qown "Household daily quantity self-consumed"
		label var daily_exp "Household food daily monetary value"

		sort identif item source 

preserve		
		*** Food consumed outside ******
		use "$data_raw/19_foodout", clear
			* Hunsnii medeelel bhgui urhiig ustgaw
			* SPREAD-DATA ADAPTATION (2026-07-03): spread release already
			* ships "identif" instead of "hses_id".
			capture rename hses_id identif
			rename q1307 qtot
			rename q1308 exp_own
			rename q1309 exp_gift
			rename q1310 exp_tot
					
			** Check totals
			egen double tot=rowtotal(exp_own exp_gift)
			compare exp_tot tot			// looks good
			count if (exp_tot==. | exp_tot==0) & q1306==1		// 5 obs in Bayankhongor
			drop if exp_tot==. | exp_tot==0
			drop tot 
					
			keep if q1306==1
			drop q1306

			gen daily_exp=0								
			replace daily_exp=exp_tot/7 
			keep identif item exp_tot daily_exp 
			gen itemcode=21801 
			gen source=4
					
			collapse (sum) daily_exp (mean) itemcode source,  by(identif)
			count
			rename (itemcode) (item )
			order identif item
			sort identif item daily_exp
		save "$data_temp/foodout_${survey_year}", replace 	

restore		
		
		append using "$data_temp/foodout_${survey_year}"

			label val source source
			label define source 1 "Ð¥ÑƒÐ´Ð°Ð»Ð´Ð°Ð¶ Ð°Ð²ÑÐ°Ð½" 2 "Ó¨Ó©Ñ€Ð¸Ð¹Ð½ Ð°Ð¶ Ð°Ñ…ÑƒÐ¹Ð³Ð°Ð°Ñ" 3 "Ð‘ÑƒÑÐ´Ð°Ð°Ñ Ò¯Ð½ÑÐ³Ò¯Ð¹ Ð°Ð²ÑÐ°Ð½" 4 "Ð“Ð°Ð´ÑƒÑƒÑ€ Ñ…Ð¾Ð¾Ð»Ð»Ð¾Ð»Ñ‚", modify
			sort identif item source 
	
			label val item item
			label define item 21801 "Ð“Ð°Ð´ÑƒÑƒÑ€ Ñ…Ð¾Ð¾Ð»Ð»Ð¾Ð»Ñ‚", modify
			sort identif item source 
			tab item 
			
			
		**** Merge UNIT SCALE
		
		**** medeellee grams-aar ilerhiilne uchir ni ilchleg ni 100g-d nognod colories-iin hemjee bgaa 
		*** uunii tuld 130 neg turul buriin huwid hemjih negjiig ni todorhoiloh heregtei Undug 65 gr gdg shig
		***converting quantities into gram per unit
		* grams ni neg ijil hemjeetei bolgohod ashiglasan huwisagch uuruur helbel talh 670 geh met 

			sort identif item source
			merge m:1 item using "$dbase/unit_scale"
			tab item if _m==1
			tab item if _m==2
			drop if _m==2
			drop _m 
			rename unit unit_gr
			sort identif item source 
			
			gen daily_qty_gr=daily_tot_qty*unit_gr
			gen daily_qpur_gr=daily_qpur*unit_gr
			gen daily_qfree_gr=daily_qfree*unit_gr
			gen daily_qown_gr=daily_qown*unit_gr
			
			sort identif item source
			count  if daily_qty_gr==0
			* daily_qty_gr==. baih utga zaawal orluulagdsan bh yostoi tiimees umnuh coduudig shalga
			count if daily_qty_gr!=. & daily_qty_gr!=0
			keep if daily_qty_gr!=0 
					duplicates tag identif item, gen(dup1)
					tab dup1 
					drop dup1
			count if daily_exp==0 | daily_exp==.  
			drop if daily_exp==0 | daily_exp==. 
		
		
		order identif item itemname* unit_gr source identif item itemname_mn itemname_en unit_gr source daily_tot_qty daily_qpur daily_qfree daily_qown daily_qty_gr daily_qpur_gr daily_qfree_gr daily_qown_gr daily_exp

		sort identif
		merge m:1 identif using "$data_raw/basicvars", keepus(month) nogen
		
		keep identif item itemname* unit_gr source daily_qty_gr daily_qpur_gr daily_qfree_gr daily_qown_gr daily_exp month out

		label var daily_qty_gr "Household daily total qty by gr"
		label var daily_qpur_gr  "Household daily purchased qty by gr "
		label var daily_qfree_gr "Household daily free of charge qty by gr"
		label var daily_qown_gr "Household daily self-consumed qty by gr "
		label var daily_exp "Household food daily monetary value"
		label var source "Purchased/Self/Free/FATH"
		
		
		sort identif item source
	
		merge m:1 month using "$data_out/index", keepus(def_fcpi) nogen	  

		gen daily_rexp = daily_exp/def_fcpi  //hhexpday-consumption tul ali hezeenii zasagdsan medeelel yum tiimees zuwhun inc-iig zassan
		drop month 
		
		label var daily_rexp "Household real food cons per day"
		
		
		gen itemAT=item // labelgui bolgoj bn 
		order itemAT, after(item)		
	
		saveold "$data_out/food_${survey_year}", version(12) replace

		drop if out==1
		
		saveold "$data_out/food_${survey_year}_Noout", version(12) replace
		
erase "$data_temp/food13.dta"
erase "$data_temp/food14.dta"
erase "$data_temp/foodtemp1.dta"
erase "$data_temp/foodtemp2.dta"	
	
	

	
	