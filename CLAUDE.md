# PoU Pipeline — Codebase Guide

Mongolia HSES 2024 → Prevalence of Undernourishment (PoU) pipeline. Stata do-files
prepare data following the FAO/World Bank handbook (`docs/Analyzing Food Security
using HH survey data - Chapter 2.pdf` and `- Chapter 3.pdf`); the actual PoU
statistic is computed downstream in ADePT-FSM (not in this repo — see
`HH data.xlsx` for an example ADePT-FSM output/config from a prior 2018 round).

Run everything via `dofiles/00 Master.do` (`StataMP-64.exe /e do "dofiles/00 Master.do"`).
Log written to `main.log`. Full execution order also documented in
`docs/Pipeline_2024_Runbook.md`.

## Key globals (set in `00 Master.do`)

- `survey_year` — **must stay a `global`, not a `scalar`.** Several do-files call
  `clear all`, which wipes scalars but not globals. Always reference it as
  `${survey_year}` (braced), never bare `$survey_year` — Stata's macro-name
  parsing is greedy and will swallow trailing `_text` into the macro name (e.g.
  `$survey_year_with_Foodout` looks for a global literally named that).
- `data_raw` — `$dbase/${survey_year}`, e.g. `input/2024`. Was `data_raw24`
  (year baked into the name itself) until renamed for reusability.
- `indirect_grp_var` — grouping variable (default `"region"`) for the
  FATH calorie imputation in `12_Calc_DietaryEnergyConsumption.do` (handbook
  Ch.2 indirect-method step 5). Change here, not in the do-file, to swap
  grouping granularity later.
- `u5mr` / `cbr` — Mongolia under-5 mortality rate (15.0) and crude birth
  ratio (0.0169), 2024 NSO figures, used in the MDER/ADER/XDER formulas
  (`11_Calc_DietaryEnergyRequirement.do`). **Promoted from bare literals to
  globals (2026-07):** these are survey-year-specific empirical constants, so
  — same reasoning as `survey_year` — they live in one obvious place instead
  of buried in a calculation file. Update both when the survey year changes.

Output/temp filenames that used to hardcode `24`/`2024` (e.g.
`equivalence_scales24.dta`, `food_2024.dta`) now build their year suffix from
`${survey_year}` — set once, applies everywhere.

## Pipeline structure & the 2026-07 reorg

The do-files were reorganized (2026-07-05/06) so raw-input access is confined
to a clearly-named **Import** stage, with derived-variable **Build** and
**Calc** stages that only ever read earlier stages' outputs, never raw
`input/` directly. Files are renamed `NN_Stage_Purpose.do`. Renames were done
with `git mv` (history preserved); nothing was deleted.

**Old → new mapping:**

| Old | New | Stage |
|---|---|---|
| *(new file)* | `01_Import_BasicVars.do` | Import |
| `0 Import Unit.do` | `02_Import_UnitScale.do` | Import |
| `00C Price deflation.do` | `03_Import_PriceDeflators.do` | Import |
| `00B MA_Height.do` | `04_Import_AgeClassReference.do` | Import |
| *(new file, 2026-07-06)* | `05_Import_IncomeDeciles.do` | Import |
| `00A Equivalence scales.do` | `06_Build_EquivalenceScales.do` | Build |
| `00D HHsize_Food.do` | `07_Build_HHFoodPartakers.do` | Build |
| `01 Food.do` | `08_Build_FoodConsumption.do` | Build |
| `02 Individual.do` | `09_Build_IndividualRoster.do` | Build |
| `04 Country_NCT.do` | `10_Build_NutrientConversionTable.do` | Build |
| `05 MDER_ADER_XDER.do` | `11_Calc_DietaryEnergyRequirement.do` | Calc |
| `06 DEC.do` | `12_Calc_DietaryEnergyConsumption.do` | Calc |
| *(new file, 2026-07-06)* | `13_Calc_PoUEstimate.do` | Calc |
| `03 Household.do` | *(unchanged — disabled, out of scope)* | — |

**Note:** the table above already reflects the *current* (2026-07-06) file
names. The pipeline was renumbered a second time that day to make room for
`05_Import_IncomeDeciles.do` and `13_Calc_PoUEstimate.do` — see "2026-07-06
additions" below for what was added and why.

**Two structural moves (no numeric effect):**
- **`basicvars` consolidation** — `basicvars.dta` used to be read from raw
  input in six separate places. `01_Import_BasicVars.do` now makes one shared
  passthrough copy (`temp/analysis/basicvars_${survey_year}.dta`) and every
  other file merges from that. (`03 Household.do`, disabled/out of scope, still
  points at raw input on purpose — don't "clean it up".)
- **Reference-table joins moved upstream** — `reference_values`,
  `sd_value_0to2`, `sd_value_2to5` used to be joined *inside* the requirement
  calculation (old `05`). They're now attached in `04_Import_AgeClassReference.do`
  alongside the height/age_class they're keyed to, and `11_Calc_...` merges the
  resolved columns instead of touching raw input. Verified bit-identical for
  the reference columns themselves.

**Four deliberate fixes folded in (these DO change numbers, all documented in
the code with dated comments):**
1. **`hhsize_food` cumulative-sum bug** (`07_Build_HHFoodPartakers.do`) — old
   code used `gen ... = _N - sum(abs_mem)` (Stata's *running* `sum()`) then
   kept only the first row per household via `collapse (first)`, so households
   got an arbitrary partial-sum instead of the true absent-count. Fixed to
   `egen ... total()`. Affected 1,948/51,471 individual rows (3.8%) at the
   person level, but netted out to **zero** change in the final household-level
   `hhsize_food`/`PC_tot_cal` for the 2024 data (the partial sums happened to
   land on the right first-row value here) — kept anyway because it's a genuine
   correctness bug that could bite other years/orderings.
2. **Gender-coding bug** (surfaced in old `05`, fixed via
   `04_Import_AgeClassReference.do`) — the WHO SD-for-height join (children 0-5)
   was done on `gender` = a rename of `hm_sex` (coded 0=Female/1=Male), but the
   `sd_value_*` tables use the **HSES-native 1=Male/2=Female** coding. Boys
   matched by coincidence; **every girl aged 0-5 (2,350 in 2024) matched
   nothing and had her XDER silently forced to missing** (same "silent-zero"
   failure mode as the FATH bug). Fixed by resolving these from the roster's
   own native-coded `gender` (built from raw `q0103`, never recoded). The
   HSES-native 1=Male/2=Female is the project-wide convention — the 0/1
   `hm_sex` recode is a one-off local to `08`'s ADePT export column only.
3. **Height-rounding leak** (`11_Calc_DietaryEnergyRequirement.do`) — old code
   did `replace height=int(round(height,1))` in place (needed only for the
   integer-cm SD-for-height lookup), which leaked cm-rounding into the general
   weight-for-height formula `BMI × (height/100)²` for **every** age class.
   Handbook Ch.2 Annex 2F specifies this formula with unrounded median height
   (the only rounding-relevant reference, footnote 17, is specifically the
   child SD tables). Fixed: `04` keeps `height` unrounded and rounds only a
   separate `height_rounded` for the SD lookup. Effect: small (<1% per
   household) but universal.
4. **`u5mr`/`cbr` promoted to globals** — see Key globals above. Same values,
   zero numeric change; just no longer bare literals in a calc file.

**Net effect on headline numbers (2024 spread data), new vs. pre-reorg
baseline:**
- `PC_tot_cal` (consumption / DEC): **unchanged**, 2,068.3 kcal/person/day
  (diagnostic) — no fix touches the consumption side.
- National MDER 1,788.4 → 1,786.6 (−0.1%), ADER 2,300.2 → 2,297.6 (−0.1%) —
  height-rounding fix only (MDER/ADER never use the SD columns).
- National XDER 2,818.4 → 2,735.5 (−2.9%) — net of the height-rounding fix
  (small, ~95% of people) and the gender fix (larger, but only the ~4.6% of
  individuals who are girls 0-5); `cv_r` moves with it.
- All other shared outputs byte-identical except `def_fcpi`/`daily_rexp`, which
  differ only because of a *separate*, earlier-committed CPI-import change (not
  part of this reorg).

**Still bundled (a later phase):** this reorg only split *import* from the
rest. Indicator/classification building, the calculation math, and
table/output generation still live together within the Build and Calc stages —
see "Known architecture debt" below.

## 2026-07-06 additions: full data by default, income deciles, PoU estimate

**Data source swap.** `input/2024/` now holds the **full** (non-de-identified)
2024 release; the de-identified "spread" release the pipeline was adapted for
on 2026-07-03 moved to `input/2024 spread/`. Reason: `consumption.dta` (needed
for income deciles, below) only exists in the full release, and its household
IDs **cannot be matched to the spread release's IDs at all** — the spread
release's `identif` is a one-way anonymizing hash with no crosswalk back to
the real IDs (confirmed: merging both releases' `basicvars.dta` on `identif`
gives zero matches, despite both covering the same 15,513 households). This
is a pure folder-swap, not a code change — `$data_raw` (`$dbase/${survey_year}`)
resolves to whichever folder is named `input/2024`. Every "SPREAD-DATA
ADAPTATION" guard elsewhere in the pipeline is harmless against full data
(they're `capture`-guarded or check column existence) **except** the two
features below, which are explicitly re-enabled now that their inputs exist
again. `03 Household.do` stays disabled regardless — poverty is out of scope
independent of data availability.

**Re-enabled in `08_Build_FoodConsumption.do`** (both were disabled only
because the spread release lacked their inputs, not because they were wrong):
- **Cluster-level price-imputation rung** restored (household → cluster →
  aimag/strata/month → national) — per `ref/foodsetup.do`'s own historical
  note, this rung supplied ~52.8% of all imputed prices.
- **Income-decile outlier-imputation grouping** restored (`$lev1`="item region
  urban decile", `$lev2`="item urban decile", `$lev3`="item decile") — full
  4-level cascade again instead of the spread-data's collapsed 3-level one.

**New: `05_Import_IncomeDeciles.do`.** Reads `consumption.dta`, ranks
households into population-weighted deciles of real per-adult-equivalent
expenditure (`xtile decile=totex_rpae [aw=hhweight*hhsize], nq(10)` — same
formula the original, pre-spread-adaptation code used). Note:
`consumption.dta`'s own `identif` column is a *different* ID scheme that does
**not** match this pipeline's `identif` — the real shared key is
`consumption.dta`'s `household_id` column (verified: matches `basicvars`'
`identif` for all 15,513 households). Output feeds both the outlier grouping
above and the Between-CV calculation below.

**New: `13_Calc_PoUEstimate.do`.** An approximate PoU calculation using this
pipeline's own DEC/MDER outputs and the handbook's CV/skewness derivation
(Ch.2) — not ADePT-FSM itself, which is what actually produces the official
number (see file header for the full caveat list). Implements the handbook's
4-step CV derivation: Step 1 (between-decile CV of DEC, now buildable thanks
to the file above — **not possible at all against the spread data**, which
has no income ranking); Step 2 (within-household CV, already computed as
`cv_r` in `Requirement_admin.dta`); Step 3 (combine via
`sqrt(CV_between² + CV_within²)`); Step 4 (select the lower of the combined
CV vs. the raw empirical CV). Uses **log-normal**, not ADePT's default
skew-normal, because it has a closed-form CDF (Stata's `normal()`) that can
be verified by hand — expect the true ADePT PoU to differ from this
approximation. Saves `output/process/PoU_estimate_${survey_year}.dta`.

**Major discovery (not yet fixed — flagged for the user to raise with her
boss, standalone demo file provided): the pipeline's long-standing "national
mean DEC" diagnostic is household-weighted, not population-weighted.**
`12_Calc_DietaryEnergyConsumption.do`'s own diagnostic
(`summ PC_tot_cal [iw=hhweight] if item==10101`) gives every household equal
weight regardless of size. But household size correlates strongly and
negatively with per-capita DEC (`corr = -0.52`: 1-person households average
3,502 kcal/person/day; 6+-person households average only 1,425 — plausibly a
mix of fixed-cost effects in per-capita cooking/food-prep accounting and
genuine differences between household types). Household-weighting therefore
**overweights small households** relative to their true population share,
inflating the reported "average person's" DEC. Correctly population-weighting
(by `hhweight*hhsize_food`, matching the handbook's own CV-by-decile formula)
gives **~1,808 kcal/person/day, not ~2,068-2,120** — a ~14-15% difference,
and a margin over MDER (1,786.6) of only ~1.2%, versus the misleadingly
comfortable ~118% the household-weighted figure implies. This directly
explains why `13_Calc_PoUEstimate.do`'s PoU comes out much higher (~50%) than
naive expectations based on the old household-weighted headline number.
**Not fixed pipeline-wide per explicit user instruction** ("don't fix it
right now, but I think I will show this to my boss tomorrow") — a standalone,
non-pipeline demonstration file, `dofiles/Showcase_DEC_Weighting_Bias.do`, was
built instead (run manually after `00 Master.do`; not called from it).

## Execution order & per-file notes

*(Section headers below give the current name with the old name in parentheses.
Detailed caveats still apply under the new names.)*

### `02_Import_UnitScale.do` (was `0 Import Unit.do`, orig `99 Import.do`)
Imports `Unit_scale.xlsx` → `unit_scale.dta`. The `unit` column is the
**gram-conversion factor** per food item (not a text label like "kg") — matches
handbook Ch.2 "Unit of Measurement" + Annex 2A's worked conversion example.
**Caveat:** conversion factors have never been spot-checked against real-world
values — still an open, unverified lead if calorie totals ever look off again.

### `03_Import_PriceDeflators.do` (was `00C Price deflation.do`)
Builds `def_cpi`/`def_fcpi` deflators (`month index / annual mean index`).
Verified independently against real data — formula and application both match
the handbook exactly (Ch.2 "Adjustment to Account for Temporal Variability of
Prices," p.31, Annex 2D). **Updated 2026-07 (by the user, not Claude):** now
imports `$data_raw\CPI, FCPI.xlsx` (i.e. a per-survey-year file living in
`input/${survey_year}/`) instead of the original hardcoded 24 monthly values —
removes the old "hand-typed, no automated source" caveat, but means each new
survey year's input folder must include its own `CPI, FCPI.xlsx` (year, month,
cpi, fcpi columns) or this file will fail immediately. Source: NSO
(https://www.1212.mn, Consumer Price Index table).

### `06_Build_EquivalenceScales.do` (was `00A Equivalence scales.do`)
Builds survey date → individual age → adult/child + age-sex brackets → two
equivalence scales: `aesize_oecd1` (OECD scale, used later for expenditure
equivalization) and `aesize_fao` (calorie-weighted scale).
**Caveats:**
- `age_exact`/`age_int` (precise, birthdate-derived age) are computed then
  **discarded** — actual classification uses self-reported whole-number
  `q0105y` instead. Verified impact: 3.7% of individuals disagree between the
  two age measures; **0.53% (284 people) land in a different age bracket**,
  and 32 flip adult/child status, purely depending on which is used. Probably
  intentional (self-reported age often treated as canonical), not a bug, but
  worth knowing.
- `aesize_fao` is essentially unused for the real DEC calculation — the
  handbook explicitly says to use raw household/food-partaker size instead
  (Ch.2 "Conversion in per Person per Day," p.32), and the codebase correctly
  follows this (see `08_Build_FoodConsumption.do` comment citing the handbook
  directly). It only shows up in one narrow outlier check in that file.
- Had a stray, unrelated debug snippet (`scalar x=3.14159` + broken `display`)
  at the end of the file that crashed the entire pipeline — removed.
- Fixed a 2-digit vs. 4-digit year mismatch: raw `v1_yy`/`v2_yy`/`v3_yy` fields
  are 2-digit; `survey_year` is 4-digit. A local `yy2 = mod(${survey_year},100)`
  bridges this. Also fixed a pre-existing bug where `check3` hardcoded a
  literal `24` instead of using the year variable at all.
- **Architecture note:** this file mixes household date-cleaning, individual
  age/demographic classification, and two unrelated equivalence-scale
  calculations. Candidate for splitting into separate classify-only files if
  ever revisited (see "Known architecture debt" below).

### `07_Build_HHFoodPartakers.do` (was `00D HHsize_Food.do`)
Builds `hhsize_food` (food-partaker count, excludes members absent 30+ days).
**This is what the real per-capita calorie calculation actually uses** — not
`aesize_fao`. Confirmed via log: `hhsize_food` is always ≤ `hhsize`, never
larger, so it can't be the cause of an underestimated per-capita calorie figure.
**Bug fixed 2026-07** (cumulative `sum()` → `egen total()`) — see reorg fix #1
above. Also had a `cleara` typo (`use ..., cleara`) that would halt the
pipeline; fixed to `clear`.

### `04_Import_AgeClassReference.do` (was `00B MA_Height.do`)
Builds the 62-way age-sex `age_class` and attaches every age/gender-keyed
reference table: median height (from `height_Mongolia_2018.dta`), BMI/PAL/
weight-gain constants (`reference_values.dta`), and WHO SD-for-height for
children 0-5 (`sd_value_0to2.dta`/`sd_value_2to5.dta`). Output:
`AgeClassReference_${survey_year}.dta` (was `Height_Sattar.dta`). Feeds both
`09_Build_IndividualRoster.do` (height + age_class only) and
`11_Calc_DietaryEnergyRequirement.do` (the full reference set).
**Expanded in the 2026-07 reorg** — the last three tables used to be joined
inside old `05`; moved here (see reorg section). Keeps `height` **unrounded**
and rounds only a separate `height_rounded` for the integer-cm SD lookup (this
is what fixed the height-rounding leak, reorg fix #3). Uniqueness `assert`s
guard each join against future duplicate-key data refreshes.

### `08_Build_FoodConsumption.do` (was `01 Food.do`)
Harmonizes urban diary (7-day) + rural recall (7-day) + food-away-from-home
data, converts to grams via `unit_scale`, imputes missing unit prices via a
cascading median (household → cluster → aimag/strata/month → national),
detects/imputes outliers via IQR, computes `daily_rexp` (deflated real
expenditure via `def_fcpi`).
**Caveats:**
- Uses `hhsize`/`hhsize_food` for per-capita, not `aesize_fao` — deliberate,
  cites the handbook directly in a comment (page 32).
- Has a manual SALT-quantity fix (10x/100x rescaling for apparent data-entry
  errors) — a targeted patch, not general logic.
- Food-away-from-home (item `21801`) is captured **only as expenditure, never
  quantity** — this is the root design gap behind the big bug below.
- The `refuse` (waste %) field from the NCT is never applied in the calorie
  formula (in `12_Calc_DietaryEnergyConsumption.do`). Not yet fixed — low
  priority, since omitting it
  would bias DEC *upward*, not downward, so it isn't the source of any
  underestimate, just a methodological gap versus the handbook's Procedure 1.

### `09_Build_IndividualRoster.do` (was `02 Individual.do`)
Builds individual demographics + a large labor-force/employment classification
block (occupation, industry, sector) + household-head attributes.
**Architecture note:** the labor-force classification is a big, self-contained
chunk of logic bolted onto what's nominally "build the roster" — good
candidate for separation later. Output filename keeps the pre-existing typo
"**indivdual**" (not "individual") for consistency — not something to
silently "fix," since it'd require renaming the actual saved file everywhere
it's referenced.

### `10_Build_NutrientConversionTable.do` (was `04 Country_NCT.do`)
Imports/cleans the national nutrient conversion table (NCT) and appends a
placeholder row for Food-Away-From-Home (item `21801`).
**This is the root cause of the confirmed DEC bug**: the FATH placeholder row
here (`~line 72-85`) sets `id/desc/refuse/item_grp/diversity_grp` but never
fills in `fd_pro/fd_fat/fd_car/fd_fib/fd_kcal` — leaving FATH with no calorie
value at all. (The fix lives downstream in `12_Calc_DietaryEnergyConsumption.do`,
not here — this file itself wasn't changed, since the fix needed data only
available later in the pipeline.)

### `03 Household.do` — **out of scope (poverty), do not extend, NOT renamed**
Builds household expenditure/income/poverty file. Not consumed by the Calc
stage — `household_2024.dta` is a terminal output, likely destined for ADePT-FSM
directly (not used further in this Stata pipeline). Deliberately left with its
old name and **disabled** in `00 Master.do` (out of scope, and its 3 external
inputs don't exist in spread data). It also still reads `basicvars` from raw
input directly (not repointed to `01_Import_BasicVars.do`) — intentional, since
it's out of scope; don't "fix" that.
**Caveats:**
- `poor = (totex_rpae < pline_r_pae)` is an **old-style absolute monetary
  poverty line** (hardcoded ~16,882 MNT/day poverty line, `totex_rpae` sourced
  externally from `input/2024/consumption.dta`, not built in this repo). The
  org has since moved to Multidimensional Poverty Index (MPI) methodology,
  which is custom per country and likely not fully supportable from HSES data
  alone (HSES is consumption/expenditure-focused; MPI typically needs
  health/education/living-standards modules like child mortality, WASH,
  housing, assets — not confirmed present in this survey).
- **Ordering subtlety:** `poor` is computed from `totex_rpae` *before* the
  regional Paasche adjustment (`pi_v1`) is applied; `pi_v1` is only applied
  afterward, for `hhexpday`. Unclear if intentional (totex_rpae may already
  arrive pre-adjusted from its external source) — can't verify since
  `consumption.dta`'s construction is outside this repo.
- `aesize_oecd1` (not `aesize_fao`) is used here for `hhexpday` — expenditure
  equivalization is a different, legitimate use case from the calorie side,
  and correctly separated.
- The handbook itself never mentions "poor/non-poor" as a standard
  population group — it's achieved via ADePT-FSM's generic "Population group
  1-5" user-definable slots (confirmed via `HH data.xlsx`'s `ExtraInfo` sheet:
  `FSSM_VAR1 = poorlNSO`, `CHMLBL1 = "Poverty"`).
- **Origin of `consumption.dta`/`all_inc_exp.dta`** (external inputs, not
  built anywhere in this repo): their embedded Stata characteristics are
  strong evidence they're **official NSO poverty/welfare working files**, not
  a generic download — `consumption.dta` carries `_dta[_svy_*]` characteristics
  (only created by `svyset` with `pweight`/`cluster`/`strata`), weight-raking
  characteristics (`hhweight[objfcn]`, `[converged]`, etc.), and `reshape`
  bookkeeping (`_dta[ReS_i]`/`ReS_j`) showing it was built from raw item-level
  HSES data reshaped into COICOP-style categories; `all_inc_exp.dta`'s reshape
  metadata (`_dta[ReS_i]: hses_id day item`) ties directly to the raw
  questionnaire's own `q1307`/`q1308` fields. Same pattern (external,
  never-constructed `consumption`/`all_inc_exp` files) recurs in the 2018
  legacy scripts too — consistent with a recurring, per-round NSO product.
- **Architecture note:** mixes expenditure, income, and poverty concerns in
  one file — candidate for separation, but out of scope to touch given the
  poverty restriction.

### `11_Calc_DietaryEnergyRequirement.do` (was `05 MDER_ADER_XDER.do`)
Computes Minimum/Average/Maximum Dietary Energy Requirements per individual
(FAO BMR-based formulas using age/sex/BMI/PAL) and the within-CV component.
Reads `indivdual_${survey_year}` (the roster from `08`) + the reference columns
from `AgeClassReference_${survey_year}` (`04`). **Two bugs fixed here in the
2026-07 reorg** (both detailed in the reorg section above and in dated code
comments): the gender-coding bug (girls 0-5 getting missing XDER, fix #2) and
the height-rounding leak (fix #3). `u5mr`/`cbr` now read from globals (fix #4).
The three raw-reference joins it used to do are gone — moved to `04`.

### `12_Calc_DietaryEnergyConsumption.do` (was `06 DEC.do`)
Converts food quantities to calories via the NCT, aggregates to household/
per-capita DEC (`PC_tot_cal`).
**Confirmed, fixed bug:** Food-Away-From-Home (item `21801`, ~14.9% of
households) had no calorie data (root cause in
`10_Build_NutrientConversionTable.do`), so
`egen total()` silently zeroed its contribution — this was the actual reason
`PC_tot_cal` was implausibly low (~1,941 kcal/person/day vs. the handbook's
~2,000-2,500 expected range). **Fixed** by adapting the handbook's 6-step
indirect/unit-value method (Ch.2): derive an implied kcal-per-1,000-real-MNT
rate from the rest of the (quantified) food basket, take the **median**
grouped by `${indirect_grp_var}` (region), and apply each household's own
group rate to FATH's deflated expenditure. Result: `PC_tot_cal` → ~2,069
kcal/person/day, now plausible. Verified against real data (deflator formula
and application both independently recomputed and matched to the decimal; see
diagnostic blocks in the file for before/after FATH imputation).
**Still-open, unverified leads** (lower priority, pipeline is now plausible
but not exhaustively audited):
- `unit_scale.dta` conversion factors — never spot-checked.
- Large item-level divergences between Atwater-derived `kcal` and tabulated
  `fd_kcal`/`calories` (up to ±300 kcal/100g for some items) — worth checking
  the source NCT Excel for transcription errors if DEC ever looks off again.
- **The `[iw=hhweight]` diagnostic in this file is household-weighted, not
  population-weighted** — see "2026-07-06 additions" above for why that
  matters (~2,068-2,120 vs. the population-weighted ~1,808 kcal/person/day).
  Not fixed yet (explicit user instruction to hold off); see
  `dofiles/Showcase_DEC_Weighting_Bias.do`.

## Data variants in `input/`: full vs. spread vs. 2018

`input/` holds multiple data releases sharing the same do-files where
possible. **Check what `input/${survey_year}/` actually points at before
assuming the pipeline will "just work"** — as of 2026-07-06 the default is
the **full** 2024 release (see "2026-07-06 additions" above for why); running
against `2018` does not work at all (see below) without deep rework.

- **`input/2024/`** — the complete, detailed 2024 release (has `cluster`,
  `household_id`, `interviewer`, `consumption.dta`, `all_inc_exp.dta`,
  `deflators.dta`, `q0104y/m/d` birthdates, `q0423a`, diary `visitor13`/
  `ndays13` etc.). **This is the default data since 2026-07-06** (was
  `input/2024 full/` before the folder swap). This is what the pipeline was
  originally built and verified against (`PC_tot_cal` ≈ 2,068.8 kcal/person/day,
  household-weighted -- see the weighting caveat above).
- **`input/2024 spread/`** — the de-identified "**spread**" release (was
  `input/2024/` before the folder swap, 2026-07-03 through 2026-07-06): same
  survey, same question numbering, but several columns stripped for
  disclosure-avoidance, and `hses_id` already renamed to `identif` throughout.
  **No longer the default** — its `identif` is a one-way anonymizing hash
  with no crosswalk to the full release's real IDs, which blocks anything
  needing `consumption.dta` (income deciles, the Between-CV PoU component).
  The pipeline still runs correctly against this folder if ever needed again
  (rename it back to `input/2024/` and move the full release aside) — nothing
  about the do-files themselves depends on which folder is active, only the
  cluster-imputation and income-decile features would need re-disabling (see
  their own "SPREAD-DATA ADAPTATION" comments in `08_Build_FoodConsumption.do`).
  Missing vs. full: `cluster`, `household_id`, `newsoum`, `bag`,
  `interviewer`, `supervisor`, several `hhweight_*` variants (from
  `basicvars.dta`); `q0104y/q0104m/q0104d` (birthdate) and `q0423a` (open-text
  occupation) from `02_indiv.dta`; `visitor13`/`ndays13` (urban),
  `visitor14`/`ndays14`/`price` (rural) from the diary files; and **the entire
  `consumption.dta`/`all_inc_exp.dta`/`deflators.dta` files don't exist at
  all**. All active do-files were adapted to run against this (see per-file
  notes above, all marked "SPREAD-DATA ADAPTATION (2026-07-03)" in the code).
  Result after adaptation: `PC_tot_cal` ≈ 2,068.3 kcal/person/day — within
  0.02% of the full-data run, despite real methodology losses (below).
  **Real, non-cosmetic losses from adapting to spread data, all REVERTED
  2026-07-06 now that full data is the default** (kept here for history, and
  in case this folder is ever made the default again):
  - `08_Build_FoodConsumption.do`'s price-imputation cascade lost its
    **cluster-level rung** (household → ~~cluster~~ → aimag/strata/month →
    national). Per `ref/foodsetup.do`'s own historical note, cluster supplied
    ~52.8% of all imputed prices — the single most-used rung. Fell straight to
    aimag while spread data was active. **Restored** (see "2026-07-06
    additions").
  - The outlier-imputation grouping (`$lev1-3` in
    `08_Build_FoodConsumption.do`) lost the
    **income-decile** dimension entirely, since building it required
    `consumption.dta` (absent). Was effectively 3 levels instead of 4 while
    spread data was active. **Restored** (see "2026-07-06 additions").
  - `03 Household.do` (poverty) is **entirely disabled** in `00 Master.do`,
    independent of which data folder is active — out of scope regardless
    (see the poverty caveat above), not just a spread-data limitation. This
    one is NOT reverted and should stay disabled.
  - One genuine data anomaly surfaced (not a structural issue): a
    `consumed==1`-but-zero-quantity mutton record under a re-numbered
    household ID, resolved generically (deferring to the zero-quantity
    evidence) since the cluster-peer context the original hardcoded fix used
    isn't reconstructable without `cluster`. This fix is harmless against
    full data too (the `replace consumed=0 if ...` condition is data-driven,
    not ID-driven), so it was left as-is rather than reverted.
- **`input/2018/`** — real 2018 HSES raw data (renamed from downloaded
  filenames like `01_hhold (9).dta` → `01_hhold.dta`, etc.). **Structurally
  different from 2024, not just missing columns** — a different survey design
  entirely (see "Legacy 2018 pipeline" below). The active `00`-`06` files do
  **not** work against this and were deliberately **not** adapted for it (a
  scoped decision — see below). Do not point `$data_raw`/`survey_year` at
  `2018` and run `00 Master.do` expecting it to work.

## Legacy 2018 pipeline (validation exercise, not part of the active pipeline)

Used to sanity-check the current methodology against ADePT-FSM's actual 2018
output (`HH data.xlsx`: DEC=2,461, MDER=1,848, ADER=2,348 kcal/person/day).

**Why 2018 needs different code, not just different data:** 2018's food diary
used a fundamentally different collection design — **three 10-day "tenths"
per month** (`q1201_x`/`q1202_x`/`q1203_x` in `16_urb_diary.dta`), not 2024's
single 7-day diary. `02_indiv.dta` also has no `q0113` at all (the field every
active do-file uses via `keep if q0113==1`), and `01_hhold.dta` has 4 visit
records instead of 3. This is why the "spread-data" adaptation approach
(rename/guard missing columns) doesn't apply here — the shape of the data
itself differs, not just which columns are present.

**Files evaluated, not all used:** the repo has 5+ overlapping legacy 2018
MDER/DEC scripts by two different authors (`sattar_2018.do`,
`Original_PoU_estmation_do.do`, `Revised2_PoU_estmation_do.do`,
`Revised_PoU_estmation_2018_Sattar.do` in both `dofiles/` root and
`dofiles/ref/` — the two same-named files differ in content), all with
hardcoded paths to machines that no longer exist (`E:\HSES_result_2018\...`,
`D:\18.FAO\Adept\...`, `C:\Users\Sattar\OneDrive\...`). Unclear whether any of
them compute a final MDER/DEC/PoU number in Stata or just prepare files for
ADePT itself to finish. **Decision made: don't try to get these running** —
too fragile, uncertain payoff. `10_GDP_Add.do` is a separate income/GDP
diagnostic tool spanning 2018-2025, not part of the PoU pipeline at all.

**What was actually done:** only `dofiles/ref/foodsetup.do` was adapted (it's
the food-diary *cleaning* script — parsing, price/quantity outlier flagging,
and a price-imputation cascade structurally identical to
`08_Build_FoodConsumption.do`'s).
Two fixes: redirected its 3 hardcoded path globals (`data2018`/`workdata`/
`worklog`) to `input/2018`, `temp/2018work`, `temp/2018log`; guarded its
`rename hses_id identif` (2018 data already ships `identif`). Ran clean.
One data-quality catch: its own code left `*drop if flagQ==1` (quantity
outliers) commented out despite its own documentation saying it should be
dropped — enabling it fixed a wildly inflated mean (one household otherwise
hit 580,000+ kcal/person/day).

Its output (`temp/2018work/tempfood.dta`: cleaned daily quantities in
*original survey units*, not grams, keyed by `identif`/`itemcode`/`tenth`)
was then fed through **this project's own, already-verified DEC logic**
(ad hoc scratchpad scripts, not saved in `dofiles/` — reused
`input/unit_scale.dta` and `output/process/Country_nct_2024_with_Foodout.dta`
directly, after confirming 2018 and 2024 share the same item-code scheme and
near-identical gram-conversion factors via `input/Unit_scale.xlsx`'s "units"
sheet, which has both years' figures side by side — only one item, Pizza/
10114, differs, and it's excluded from calorie calc as an "out" category in
both years anyway).

**Result: our computed DEC ≈ 2,341-2,385 kcal/person/day vs. ADePT's 2,461**
(~3-5% gap). Expected direction and magnitude given what was deliberately
left out of this scoped exercise: food-away-from-home wasn't processed at
all (would add calories back, per the 2024 FATH fix precedent), no full
price-imputation cascade or Procedure-2 indirect-method calories for
zero-quantity items (both would add, not subtract), and raw `hhsize` instead
of a partaker-adjusted size. Landing within 5%, in the expected direction, is
a good independent sanity check that the core Atwater-formula/unit-conversion
methodology in this codebase is sound.

**Note:** `00 Master.do`'s `survey_year` is set to `2024`. Even if someone
sets it to `2018`, that does **not** mean `00 Master.do` works against 2018
data; none of the numbered pipeline files (`01`-`13`) were adapted for 2018's
different survey design. The 2018 result above came entirely from the
standalone `foodsetup.do` + scratchpad route, never through `00 Master.do`.

## Known architecture debt (not urgent, don't refactor mid-audit)

**Done (2026-07):** raw-*import* is now separated from everything downstream
(the Import/Build/Calc reorg above) — calculation files no longer reach into
raw `input/` data.

**Still bundled (a later phase, deliberately not attempted yet):** within the
Build and Calc stages, the do-files still interleave steps that would ideally
be separate: **clean** (fix raw data-entry issues) → **classify/indicator**
(add derived/categorical columns, one concept per file, one level in/out) →
**aggregate** (explicit individual→household level transitions) → **combine**
(merge everything, no new logic) → **calculate** (MDER/DEC math) →
**table/output** (final admin-level collapse + ADePT export). Concretely:
`06_Build_EquivalenceScales.do` mixes date-cleaning + age classification + two
unrelated equivalence scales; `09_Build_IndividualRoster.do` buries a large
labor-classification block inside roster-building; `03 Household.do` mixes
expenditure/income/poverty; `11_Calc_...` mixes the requirement math with its
admin-level table aggregation. The user has flagged indicator/calculation/
table-output separation as the next round's target — use the current Import/
Build/Calc structure as the starting point rather than redoing it. Not a
retroactive rewrite of this now-verified-working 2024 pipeline.

## Legacy/reference files (not part of the active 2024 pipeline)

`dofiles/ref/`, `sattar_2018.do`, `Original_PoU_estmation_do.do`,
`Revised2_PoU_estmation_do.do`, `Revised_PoU_estmation_2018_Sattar.do`,
`10_GDP_Add.do`, `calori_povertyest.do`, `check_list.do`, `urban_food.dta` —
historical/reference material from prior survey rounds, not called by
`00 Master.do`.
