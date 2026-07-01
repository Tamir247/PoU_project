*
* SIMPLE PIPELINE:
*   1) Convert cleaned food quantities to calorie intake.
*   2) Estimate calorie-from-food-away-from-home adjustment.
*   3) Aggregate calories at household/per-adult-equivalent levels.
*   4) Prepare calorie indicators for poverty/PoU analysis.
*




** Calculate calories  
		
		// food consumed at home
		gen double cal_7day=(qty_clean*cal_unit)
		gen double cal_day=(qty_clean*cal_unit)/7
		
	
		// FAFH - for each HH, use weighted avg calorie per MNT where weights are food item shares
		bys identif (item): egen double fdex_tot=total(fdex) if !inlist(foodcat,13,99)

		gen double wt=fdex/fdex_tot if !inlist(foodcat,13,99)
		
		by identif (item): egen double cal_mnt=sum(wt*(cal_day/(fdex/365))) 

		egen tag=tag(identif)
		
		preserve
			keep if tag==1
		
			outdetect cal_mnt if tag==1, bestnorm zscore(median, q) alpha(5) out(both) nozero replace
			
			keep identif _out
			
			tempfile d
			save `d', replace
		restore
		
		merge m:1 identif using `d', nogen
	
		// outliers imputation = Winsorization
		qui sum cal_mnt if _out==0 [aw=hhw],d
			replace cal_mnt=r(min) if _out==1
			replace cal_mnt=r(max) if _out==2
			replace cal_mnt=r(p50) if cal_mnt==0
			
		drop _out wt fdex_tot
		
		// 6 HHs have missing cal_mnt due to no food consumed at home -- use median of cluster
		levelsof cluster if cal_mnt==.
		foreach x in `r(levels)' {
			qui sum cal_mnt if cluster==`x' & tag==1 [aw=hhw],d
			replace cal_mnt=r(p50) if cluster==`x' & cal_mnt==.
		}		
		
		drop tag
		
		
		// Use average calories consumed by HH to determine calories per MNT for FAFH
		// Assume profit margin on FAFH compared to food consumed at home
		replace cal_7day=(fdex/(365/7))*cal_mnt*0.7 if inrange(item,11501,11507) & foodcat!=99
		replace cal_day=(fdex/365)*cal_mnt*0.7 if inrange(item,11501,11507) & foodcat!=99
		
		recode cal_*day (.=0) if foodcat!=99		

		// total calories per day
		bys identif (item): egen double cal_day_hh=sum(cal_day)		// per HH
		gen double cal_day_pae=cal_day_hh/aesize_fao				// per AE
		
		distinct identif if cal_day_hh==0				// 1 HH with zero food consumption
		
	** Share of calories by category
		
		bys identif foodcat: egen double temp=sum(cal_day)
		
		gen double cal_share=temp/cal_day_hh 
		
		drop temp
