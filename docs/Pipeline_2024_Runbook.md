# FAO PoU Pipeline — Do-File Inventory

Base folders used by scripts (all under `$base = C:\Users\Admin\Desktop\PoU`):
- `input/` — raw survey data (`input/${survey_year}/`) and reference tables (`input/` root)
- `temp/analysis/` — intermediate files
- `output/process/` — final processed outputs
- `dofiles/` — executable Stata scripts

Run everything via `dofiles/00 Master.do` (`StataMP-64.exe /e do "dofiles/00 Master.do"`).
Log written to `main.log`.

## Pipeline stages (reorganized 2026-07-05)

Files are named `NN_Stage_Purpose.do` so the stage is obvious from the name:
- **Import** (`01`–`04`) — the only files that read raw `input/` data (`$data_raw`/`$dbase`).
- **Build** (`05`–`09`) — derive variables from survey rosters; read only Import-stage / earlier Build outputs, never raw input directly.
- **Calc** (`10`–`11`) — the MDER/ADER/XDER + DEC math; read only Build/Import outputs.

See `CLAUDE.md` for the full old→new file mapping and per-file caveats.

## Do-files

| Do-file | Purpose | Main input | Main output |
|---|---|---|---|
| dofiles/00 Master.do | Orchestrates the pipeline in dependency order; defines globals (`survey_year`, `u5mr`, `cbr`, `indirect_grp_var`, folder paths). | — | main.log, all downstream outputs |
| **Import** | | | |
| dofiles/01_Import_BasicVars.do | Passthrough of `basicvars` so every other file merges from one shared copy instead of reading raw input six times. | input/${survey_year}/basicvars.dta | temp/analysis/basicvars_${survey_year}.dta |
| dofiles/02_Import_UnitScale.do | Imports unit→gram conversion table from Excel. | input/Unit_scale.xlsx | input/unit_scale.dta |
| dofiles/03_Import_PriceDeflators.do | Builds monthly CPI / food-CPI deflators. | input/${survey_year}/CPI, FCPI.xlsx | output/process/index.dta |
| dofiles/04_Import_AgeClassReference.do | Builds age-sex class; attaches height + BMI/PAL/weight-gain + WHO SD-for-height references (all age_class- or gender+height-keyed). | input/${survey_year}/02_indiv.dta, input/${survey_year}/height_Mongolia_2018.dta, input/reference_values.dta, input/sd_value_0to2.dta, input/sd_value_2to5.dta | output/process/AgeClassReference_${survey_year}.dta |
| **Build** | | | |
| dofiles/05_Build_EquivalenceScales.do | Household adult-equivalent sizes (FAO/OECD). | input/${survey_year}/01_hhold.dta, input/${survey_year}/02_indiv.dta, temp/analysis/basicvars_${survey_year}.dta | temp/analysis/equivalence_scales${survey_year}.dta |
| dofiles/06_Build_HHFoodPartakers.do | Food-partaker household size (`hhsize_food`, excludes members absent 30+ days). | input/${survey_year}/02_indiv.dta, temp/analysis/basicvars_${survey_year}.dta | temp/analysis/HH_size_food.dta |
| dofiles/07_Build_FoodConsumption.do | Harmonized food intake (urban diary + rural recall + food-out), gram conversion, price imputation, outlier treatment, real (deflated) expenditure. | input/${survey_year}/16_urb_diary.dta, 17_rur_food_7d.dta, 19_foodout.dta, input/unit_scale.dta, temp/analysis/basicvars_${survey_year}.dta, equivalence_scales${survey_year}.dta, HH_size_food.dta, output/process/index.dta | output/process/food_${survey_year}.dta, food_${survey_year}_Noout.dta, temp/analysis/foodout_${survey_year}.dta |
| dofiles/08_Build_IndividualRoster.do | Individual analytical dataset + household-head attributes (demographics, labor-force classification). | input/${survey_year}/02_indiv.dta, temp/analysis/basicvars_${survey_year}.dta, output/process/AgeClassReference_${survey_year}.dta | temp/analysis/temp_indiv_${survey_year}.dta, temp_hhead_${survey_year}.dta, output/process/indivdual_${survey_year}.dta |
| dofiles/09_Build_NutrientConversionTable.do | Imports/cleans national nutrient conversion table; appends food-out (item 21801) placeholder row. | input/Undral_COUNTRY_NCT20260206_FINAL.xlsx, temp/analysis/foodout_${survey_year}.dta | output/process/Country_nct_${survey_year}_with_Foodout.dta |
| **Calc** | | | |
| dofiles/10_Calc_DietaryEnergyRequirement.do | MDER/ADER/XDER per individual + admin aggregates + within-CV component. | output/process/indivdual_${survey_year}.dta, output/process/AgeClassReference_${survey_year}.dta, temp/analysis/basicvars_${survey_year}.dta | output/process/Requirement_HHLevel.dta, Requirement_admin.dta |
| dofiles/11_Calc_DietaryEnergyConsumption.do | Converts food quantities to calories via NCT; aggregates household / per-capita DEC (`PC_tot_cal`); includes the food-away-from-home indirect-method calorie imputation. | output/process/food_${survey_year}_Noout.dta, Country_nct_${survey_year}_with_Foodout.dta, temp/analysis/HH_size_food.dta, basicvars_${survey_year}.dta | output/process/DEC_${survey_year}.dta |
| **Disabled / out of scope** | | | |
| dofiles/03 Household.do | Expenditure/income/poverty (MPI is out of scope; also its 3 external inputs don't exist in spread data). Commented out in `00 Master.do`, not renamed. | — | (output/process/household_${survey_year}.dta, when enabled) |

## Execution order (as called by `00 Master.do`)
1. 01_Import_BasicVars.do
2. 02_Import_UnitScale.do
3. 03_Import_PriceDeflators.do
4. 04_Import_AgeClassReference.do
5. 05_Build_EquivalenceScales.do
6. 06_Build_HHFoodPartakers.do
7. 07_Build_FoodConsumption.do
8. 08_Build_IndividualRoster.do
9. 09_Build_NutrientConversionTable.do
   — *03 Household.do stays disabled here (out of scope)* —
10. 10_Calc_DietaryEnergyRequirement.do
11. 11_Calc_DietaryEnergyConsumption.do
