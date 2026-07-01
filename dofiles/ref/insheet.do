clear
insheet using "D:\18.FAO\NCT_edit_last_02_10.txt"


duplicates report itemcode
drop v45 v46 v47 v48 v49 v50 v51 v52 v53

sort itemcode
count

tab itemcode

drop if inlist(itemcode, 11001, 11203, 11401, 11402, 11403, 11404, 11405)

count

saveold "D:\18.FAO\Adept\country_nct_2020_0211.dta", version(12) replace

saveold country_nct_2018, version(12) replace
