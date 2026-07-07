* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Showcase: item-level DEC vs. ADePT-FSM's actual 2018 output
*
* PROJECT:			Food Analysis
*
* DATE: 			Jul 2026
*
* DESCRIPTION:  	Standalone diagnostic -- NOT part of the 2018 validation
*					pipeline (not called from dofiles/2018/00_Master_2018.do).
*					Builds OUR item-level, urban/rural-split per-capita DEC
*					(same Atwater/unit-conversion logic as
*					dofiles/2018/01_Calc_DEC_2018.do, but keeping item-level
*					detail instead of collapsing to household level), then
*					imports ADePT-FSM's ACTUAL 2018 item-level output
*					directly from "HH data.xlsx" (sheet "By items ") for a
*					side-by-side comparison, item by item.
*
* WHY THIS EXISTS: the headline ADePT DEC (2,461.0, from "HH data.xlsx"
* sheet ExtraInfo, row 74) doesn't reconcile with ADePT's OWN item-level
* "By items" sheet once you sum it up and population-weight by urban/rural
* (implies ~2,019, not 2,461) -- a ~440 kcal gap that lines up closely with
* our own reconstruction's ~412 kcal shortfall vs. the same headline. Since
* food-away-from-home has no food-item identity in the survey (confirmed
* from the actual 2024 HSES questionnaire form earlier this project), it
* structurally cannot appear as a line in "By items" -- so this gap is
* consistent with (though not direct proof of) FATH being the main unmet
* piece. This file lets you verify the "our item-level number" side of that
* claim yourself, in Stata, against the Excel file directly.
*
* NOT A FIX: this file only demonstrates/compares -- it does not change
* dofiles/2018/01_Calc_DEC_2018.do's output.
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

clear all
set more off
global base "C:\Users\Admin\Desktop\PoU"

* ============================================================================
* 1) Rebuild OUR item-level daily calories, keeping item x urban/rural detail
*    (same logic as dofiles/2018/01_Calc_DEC_2018.do, just not collapsed to
*    household level, and not collapsed across urban/rural)
* ============================================================================
use "$base/temp/2018work/tempfood.dta", clear
	drop if flagQ==1
	drop if out==1

	collapse (mean) qtx (first) hhsize hhweight urban, by(identif itemcode)

	rename itemcode item
	merge m:1 item using "$base/input/unit_scale.dta", keepusing(unit) nogen keep(match)
	gen daily_qty_gr = qtx*unit

	merge m:1 item using "$base/output/process/Country_nct_2024_with_Foodout.dta", keepusing(fd_pro fd_fat fd_car fd_fib) nogen keep(match)

	gen kcal = 4*fd_pro + 4*fd_car + 9*fd_fat + 2*fd_fib
	gen hh_cal = daily_qty_gr/100*kcal

	tempfile itemlevel
	save `itemlevel'

* ============================================================================
* 2) Total population by urban/rural (denominator for population-weighted
*    per-capita DEC -- households NOT reporting a given item still count in
*    the denominator, contributing an implicit zero for that item)
* ============================================================================
use `itemlevel', clear
	duplicates drop identif, force
	gen pop_w = hhweight*hhsize
	collapse (sum) pop_w, by(urban)
	tempfile totpop
	save `totpop'
	list

* ============================================================================
* 3) Our population-weighted per-item DEC, by urban/rural
* ============================================================================
use `itemlevel', clear
	gen pop_w = hhweight*hhsize
	gen w_cal = hh_cal*hhweight
	collapse (sum) w_cal, by(item urban)
	merge m:1 urban using `totpop', nogen
	gen our_dec = w_cal/pop_w
	keep item urban our_dec
	label var our_dec "Our population-weighted DEC (kcal/capita/day)"
	tempfile ours
	save `ours'

* ============================================================================
* 4) Import ADePT-FSM's ACTUAL 2018 item-level output directly from the
*    Excel file -- "HH data.xlsx", sheet "By items ". Row ranges below were
*    confirmed directly against the file: Urban section header at row 5,
*    123 items in rows 6-128. Rural section header at row 130, but only
*    ~117 items in rows 131-250 (rural has zero reported consumption --
*    and so no row at all -- for a handful of items that urban does
*    report; rows 251-253 are blank padding before the row-254 footer,
*    confirmed by direct inspection, not guessed) -- the missing-item drop
*    below is a defensive backstop, not a fix for a real problem.
* ============================================================================
import excel "$base/HH data.xlsx", sheet("By items ") cellrange(A6:E128) clear
	rename A item_str
	rename B adept_purchased
	rename C adept_edible
	rename D adept_value
	rename E adept_dec
	gen urban = 1
	destring item_str, gen(item) force
	drop if missing(item)
	drop item_str
	tempfile adept_urban
	save `adept_urban'

import excel "$base/HH data.xlsx", sheet("By items ") cellrange(A131:E250) clear
	rename A item_str
	rename B adept_purchased
	rename C adept_edible
	rename D adept_value
	rename E adept_dec
	gen urban = 2
	destring item_str, gen(item) force
	drop if missing(item)
	drop item_str
	tempfile adept_rural
	save `adept_rural'

use `adept_urban', clear
	append using `adept_rural'
	isid item urban
	tempfile adept_all
	save `adept_all'

* ============================================================================
* 5) Merge ours vs. ADePT's, item by item, side by side
* ============================================================================
use `ours', clear
	merge 1:1 item urban using `adept_all'
	di as result "===================================================================="
	di as result "Merge quality check"
	di as result "===================================================================="
	tab _merge
	* _merge==1 (ours only): items we compute but ADePT's sheet doesn't list
	*   (e.g., zero-consumption items ADePT may have dropped from output)
	* _merge==2 (ADePT only): items ADePT lists but we have zero rows for
	keep if _merge==3
	drop _merge

	gen refuse_implied_pct = 100*(1 - adept_edible/adept_purchased)
	gen our_vs_adept_diff = our_dec - adept_dec
	gen our_vs_adept_ratio = our_dec/adept_dec

	label define urban_lbl 1 "Urban" 2 "Rural"
	label values urban urban_lbl

	di ""
	di as result "===================================================================="
	di as result "Item 10201 (Mutton) -- refuse-factor check"
	di as result "===================================================================="
	list item urban our_dec adept_dec our_vs_adept_ratio refuse_implied_pct if item==10201, noobs clean

	di ""
	di as result "===================================================================="
	di as result "National totals: sum of item-level DEC, ours vs. ADePT's own sheet"
	di as result "(compare both to ExtraInfo's headline DEC=2461 -- see the gap)"
	di as result "===================================================================="
	collapse (sum) our_dec adept_dec, by(urban)
	list, noobs clean

	di ""
	di as text "Full item-by-item comparison saved to:"
	di as text "  output/process/2018/ItemLevel_vs_ADePT_2018.dta"
	di as text "Open it directly (or 'browse' it in Stata) to check every single"
	di as text "item yourself -- columns: item, urban, our_dec, adept_purchased,"
	di as text "adept_edible, adept_value, adept_dec, refuse_implied_pct,"
	di as text "our_vs_adept_diff, our_vs_adept_ratio."

use `ours', clear
merge 1:1 item urban using `adept_all', keep(match) nogen
gen refuse_implied_pct = 100*(1 - adept_edible/adept_purchased)
gen our_vs_adept_diff = our_dec - adept_dec
gen our_vs_adept_ratio = our_dec/adept_dec
label define urban_lbl2 1 "Urban" 2 "Rural"
label values urban urban_lbl2
save "$base/output/process/2018/ItemLevel_vs_ADePT_2018.dta", replace
