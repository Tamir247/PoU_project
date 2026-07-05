* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
*
* PROGRAM:			Import basic household/individual characteristics
*
* PROJECT:			Food Analysis
*
* DATE: 			Jul 2026
*
* DESCRIPTION:  	Single entry point for "basicvars" (household weights,
*					region/urban/strata, hhsize, month, etc.)
*
* SIMPLE PIPELINE:
*   1) Read raw basicvars.dta once.
*   2) Save it as the one shared copy every other do-file merges from.
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

* PIPELINE REORG (2026-07-05): "basicvars.dta" used to be read directly from
* raw input in six separate places across the pipeline (00A, 00D, three times
* in 01 Food.do, 02 Individual.do, 05, 06) with overlapping keepusing() lists.
* This file is now the ONLY place that touches "$data_raw/basicvars" -- every
* other do-file merges from this file's output instead. Pure passthrough (no
* keepusing/drop), so every existing keepusing() list downstream keeps working
* unchanged: this file carries every column the raw file has.
*
* "03 Household.do" (poverty/expenditure, out of scope, disabled in
* "00 Master.do") is intentionally NOT repointed here -- it still reads
* "$data_raw/basicvars" directly. Leave it that way; don't "clean it up" later
* without checking CLAUDE.md for why it's out of scope.

	use "$data_raw/basicvars", clear
	save "$data_temp/basicvars_${survey_year}", replace
