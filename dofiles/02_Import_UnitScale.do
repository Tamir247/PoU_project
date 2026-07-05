* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Import file do-file 
*
* PROJECT:			Food Analysis
*
* PROGRAMMER:		Undral Lkhagva (LK)
*
* DATE: 			16 November 2025
*
* DESCRIPTION:  	Import do-file

*
* SIMPLE PIPELINE:
*   1) Import external unit-scale reference workbook.
*   2) Validate item-level uniqueness and formatting.
*   3) Label and standardize conversion variables.
*   4) Save unit-scale dataset for food gram conversion.
*
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *


** 		** Import data
		import excel "$dbase\Unit_scale.xlsx", sheet("use2024") firstrow case(lower) clear
			duplicates repor item
			format %30s itemname_en itemname_mn		
			label var unit "Unit for Gr"
			sort item
			save "$dbase/unit_scale", replace
				
		
