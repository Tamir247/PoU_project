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
  FATH calorie imputation in `06 DEC.do` (handbook Ch.2 indirect-method step 5).
  Change here, not in `06 DEC.do`, to swap grouping granularity later.

Output/temp filenames that used to hardcode `24`/`2024` (e.g.
`equivalence_scales24.dta`, `food_2024.dta`) now build their year suffix from
`${survey_year}` — set once, applies everywhere.

## Execution order & per-file notes

### 1. `0 Import Unit.do` (renamed from `99 Import.do`)
Imports `Unit_scale.xlsx` → `unit_scale.dta`. The `unit` column is the
**gram-conversion factor** per food item (not a text label like "kg") — matches
handbook Ch.2 "Unit of Measurement" + Annex 2A's worked conversion example.
**Caveat:** conversion factors have never been spot-checked against real-world
values — still an open, unverified lead if calorie totals ever look off again.

### 2. `00C Price deflation.do`
Hardcodes 24 monthly CPI/FCPI values (from NSO) and builds `def_cpi`/`def_fcpi`
deflators (`month index / annual mean index`). Verified independently against
real data — formula and application both match the handbook exactly (Ch.2
"Adjustment to Account for Temporal Variability of Prices," p.31, Annex 2D).
**Caveat:** all 24 numbers are hand-typed; must be manually updated each survey
year, no automated source link (just a URL in a comment).

### 3. `00A Equivalence scales.do`
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
  follows this (see `01 Food.do` comment citing the handbook directly). It
  only shows up in one narrow outlier check in `01 Food.do`.
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

### 4. `00D HHsize_Food.do`
Builds `hhsize_food` (food-partaker count, excludes members absent 30+ days).
**This is what the real per-capita calorie calculation actually uses** — not
`aesize_fao`. Confirmed via log: `hhsize_food` is always ≤ `hhsize`, never
larger, so it can't be the cause of an underestimated per-capita calorie figure.

### 5. `00B MA_Height.do`
Builds age-sex height reference classes (from external `height_Mongolia_2018.dta`)
for the MDER calculation. Feeds `05 MDER_ADER_XDER.do`. Not yet deep-dived.

### 6. `01 Food.do`
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
  formula (in `06 DEC.do`). Not yet fixed — low priority, since omitting it
  would bias DEC *upward*, not downward, so it isn't the source of any
  underestimate, just a methodological gap versus the handbook's Procedure 1.

### 7. `02 Individual.do`
Builds individual demographics + a large labor-force/employment classification
block (occupation, industry, sector) + household-head attributes.
**Architecture note:** the labor-force classification is a big, self-contained
chunk of logic bolted onto what's nominally "build the roster" — good
candidate for separation later. Output filename keeps the pre-existing typo
"**indivdual**" (not "individual") for consistency — not something to
silently "fix," since it'd require renaming the actual saved file everywhere
it's referenced.

### 8. `04 Country_NCT.do`
Imports/cleans the national nutrient conversion table (NCT) and appends a
placeholder row for Food-Away-From-Home (item `21801`).
**This is the root cause of the confirmed DEC bug**: the FATH placeholder row
here (`~line 72-85`) sets `id/desc/refuse/item_grp/diversity_grp` but never
fills in `fd_pro/fd_fat/fd_car/fd_fib/fd_kcal` — leaving FATH with no calorie
value at all. (The fix lives downstream in `06 DEC.do`, not here — this file
itself wasn't changed, since the fix needed data only available later in the
pipeline.)

### 9. `03 Household.do` — **out of scope (poverty), do not extend**
Builds household expenditure/income/poverty file. Not consumed by `05` or `06`
— `household_2024.dta` is a terminal output, likely destined for ADePT-FSM
directly (not used further in this Stata pipeline).
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
- **Architecture note:** mixes expenditure, income, and poverty concerns in
  one file — candidate for separation, but out of scope to touch given the
  poverty restriction.

### 10. `05 MDER_ADER_XDER.do`
Computes Minimum/Average/Maximum Dietary Energy Requirements per individual
(FAO BMR-based formulas using age/sex/BMI/PAL) and the within-CV component.
Reads `indivdual_${survey_year}` (the roster from step 7). Not yet deep-dived
beyond the file-rename fixes.

### 11. `06 DEC.do`
Converts food quantities to calories via the NCT, aggregates to household/
per-capita DEC (`PC_tot_cal`).
**Confirmed, fixed bug:** Food-Away-From-Home (item `21801`, ~14.9% of
households) had no calorie data (root cause in `04 Country_NCT.do`), so
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

## Known architecture debt (not urgent, don't refactor mid-audit)

The do-files interleave four things that would ideally be separate steps:
**clean** (fix raw data-entry issues) → **classify** (add derived/categorical
columns, one concept per file, one level in/out) → **aggregate** (explicit
individual→household level transitions) → **combine** (merge everything,
no new logic) → **calculate** (MDER/DEC/PoU math on already-clean data).
Concretely: `00A` mixes date-cleaning + age classification + two unrelated
equivalence scales; `02 Individual.do` buries a large labor-classification
block inside roster-building; `03 Household.do` mixes expenditure/income/
poverty. This makes it hard to answer "where does this variable really come
from" without reading a whole file end-to-end. Worth using as a design target
for a future round (e.g. 2025), not a retroactive rewrite of this
now-verified-working 2024 pipeline.

## Legacy/reference files (not part of the active 2024 pipeline)

`dofiles/ref/`, `sattar_2018.do`, `Original_PoU_estmation_do.do`,
`Revised2_PoU_estmation_do.do`, `Revised_PoU_estmation_2018_Sattar.do`,
`10_GDP_Add.do`, `calori_povertyest.do`, `check_list.do`, `urban_food.dta` —
historical/reference material from prior survey rounds, not called by
`00 Master.do`.
