# FAO 2024 Do-File Inventory (Simplified)

Base folders used by scripts:
- input: raw and reference data
- temp/analysis: intermediate files
- output/process: final processed outputs
- dofiles: executable Stata scripts

## Do-files

| Do-file | Purpose | Main input | Main output | File system management |
|---|---|---|---|---|
| dofiles/00 Master.do | Orchestrates full pipeline in dependency order and defines globals. | All downstream script inputs via global paths. | main.log, all downstream outputs. | Sets global folders (`$base`, `$dbase`, `$data_raw24`, `$data_temp`, `$data_out`), calls each do-file, opens/closes log. |
| dofiles/99 Import.do | Imports unit conversion table from Excel. | input/Unit_scale.xlsx | input/unit_scale.dta | Reads Excel from input and writes Stata table back to input. |
| dofiles/00C Price deflation.do | Creates monthly CPI and food-CPI deflators. | Internal CPI values coded in script. | output/process/index.dta | Writes deflator index to output/process. |
| dofiles/00A Equivalence scales.do | Computes household adult-equivalent sizes (FAO/OECD style). | input/2024/01_hhold.dta, input/2024/02_indiv.dta, input/2024/basicvars.dta | temp/analysis/equivalence_scales24.dta | Merges household/individual files and saves intermediate to temp/analysis. |
| dofiles/00D HHsize_Food.do | Builds food-partaker household size (effective HH size for food analysis). | input/2024/01_hhold.dta, input/2024/02_indiv.dta | temp/analysis/HH_size_food.dta | Saves household-size intermediate to temp/analysis. |
| dofiles/00B MA_Height.do | Builds age-sex classes and attaches reference height. | input/2024/02_indiv.dta, input/height_Mongolia_2018.dta | output/process/Height_Sattar.dta | Produces height reference file directly in output/process. |
| dofiles/01 Food.do | Builds harmonized food intake data (urban+rural+food out), converts quantities, imputes prices/outliers. | input/2024/16_urb_diary.dta, input/2024/17_rur_food_7d.dta, input/2024/19_foodout.dta, input/2024/basicvars.dta, input/unit_scale.dta, temp/analysis/equivalence_scales24.dta, temp/analysis/HH_size_food.dta, output/process/index.dta | output/process/food_2024.dta, output/process/food_2024_Noout.dta, temp/analysis/foodout_24.dta | Heavy temp usage; writes one temp food-out file and two final food outputs. |
| dofiles/02 Individual.do | Builds individual analytical dataset and household-head attributes. | input/2024/02_indiv.dta, input/2024/basicvars.dta, output/process/Height_Sattar.dta | temp/analysis/temp_indiv_24.dta, temp/analysis/temp_hhead_24.dta, output/process/indivdual_2024.dta | Writes both temp intermediates and final individual output. |
| dofiles/04 Country_NCT.do | Imports/cleans national nutrient conversion table and appends food-out item row. | input/Undral_COUNTRY_NCT20260206_FINAL.xlsx, temp/analysis/foodout_24.dta | output/process/Country_nct_2024_with_Foodout.dta | Reads Excel + temp file, writes processed NCT to output/process. |
| dofiles/03 Household.do | Builds household analytical file (expenditure, income, poverty, head characteristics). | input/2024/basicvars.dta, input/2024/01_hhold.dta, input/2024/consumption.dta, input/2024/all_inc_exp.dta, temp/analysis/equivalence_scales24.dta, temp/analysis/temp_hhead_24.dta, temp/analysis/HH_size_food.dta, output/process/index.dta | output/process/household_2024.dta | Merges multiple sources and writes final household dataset. |
| dofiles/05 MDER_ADER_XDER.do | Computes dietary energy requirements (MDER/ADER/XDER) and admin aggregates. | output/process/indivdual_2024.dta, input/reference_values.dta, input/sd_value_0to2.dta, input/sd_value_2to5.dta, input/2024/basicvars.dta | output/process/Requirement_HHLevel.dta, output/process/Requirement_admin.dta | Produces requirement outputs in output/process for PoU estimation. |
| dofiles/06 DEC.do | Converts food quantities to calories and aggregates household dietary energy consumption. | output/process/food_2024.dta, output/process/Country_nct_2024_with_Foodout.dta, temp/analysis/HH_size_food.dta | output/process/DEC_2024.dta | Merges food+NCT and writes final DEC file in output/process. |

## Quick execution order
1. 99 Import.do
2. 00C Price deflation.do
3. 00A Equivalence scales.do
4. 00D HHsize_Food.do
5. 00B MA_Height.do
6. 01 Food.do
7. 02 Individual.do
8. 04 Country_NCT.do
9. 03 Household.do
10. 05 MDER_ADER_XDER.do
11. 06 DEC.do
