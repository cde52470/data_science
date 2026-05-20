# data_science
114-2 Data Science

# CPBL 2024 PA-Level Baseball Analytics Project

This project focuses on CPBL (Chinese Professional Baseball League) 2024 game analytics using play-by-play and plate appearance (PA) level data.

The goal is to build a contextual baseball analytics pipeline for:
- player performance analysis
- situational baseball analysis
- plate appearance prediction
- game context modeling

---

## Data Source

This project uses CPBL 2024 OpenData provided by the original dataset authors.

Source repository:
https://github.com/rebas-tw/rebas.tw-open-data

License:
Open Data Commons Attribution License (ODC-By) v1.0

http://opendatacommons.org/licenses/by/1.0/

---

## Raw Data Structure

The original dataset contains:

- Game-level information
- Team batting statistics
- Team pitching statistics
- Plate appearance (PA) records
- Pitch-by-pitch events

Main nested fields:
- awayBatterBox
- homeBatterBox
- awayPitcherBox
- homePitcherBox
- awayPAList
- homePAList

---

## Data Cleaning Process

The preprocessing pipeline includes:

### Game-Level Cleaning
- Reading raw JSON game data
- Aggregating inning scores into total scores
- Extracting team batting statistics
- Generating derived features
- Removing duplicated games
- Converting data types

### PA-Level Cleaning
- Extracting awayPAList and homePAList
- Flattening nested PA structures
- Merging game context into each PA
- Converting numeric fields
- Creating binary labels
- Filtering invalid or non-play PA rows
- Handling missing values

---

## Generated Datasets

### 1. Team-Game Dataset

One row represents:
- one team
- in one game

Used for:
- game outcome analysis
- team-level modeling

---

### 2. PA-Level Dataset (`pa_features_2024.csv`)

One row represents:
- one plate appearance (PA)

Used for:
- situational prediction
- player matchup analysis
- contextual baseball analytics

---

## PA-Level Features

### Game Context Features

| Column | Description |
|---|---|
| inning | Current inning |
| outs | Number of outs |
| bases | Base occupancy state |
| awayScores | Away team score before PA |
| homeScores | Home team score before PA |
| score_diff_from_batting_team_view | Score difference from batting team's perspective |
| RE | Run expectancy |
| WPA | Win probability added |
| RE24 | Run expectancy change |

---

### Player Features

| Column | Description |
|---|---|
| batterName | Batter name |
| batterHand | Batter handedness |
| pitcherName | Pitcher name |
| pitcherHand | Pitcher handedness |

---

### PA Result Features

| Column | Description |
|---|---|
| result | Plate appearance result |
| RBI | Runs batted in |
| scored | Whether a run scored |
| endOuts | Outs after PA |
| endBases | Base state after PA |

---

## Generated Labels

| Label | Description |
|---|---|
| on_base | Whether batter reached base |
| is_hit | Whether PA resulted in a hit |
| is_extra_base_hit | Whether PA resulted in extra-base hit |
| is_strikeout | Whether PA resulted in strikeout |
| is_walk | Whether PA resulted in walk/HBP |
| rbi_positive | Whether PA produced RBI |

---

## Data Validation

Validation steps include:

- Checking legal ranges for:
  - balls
  - strikes
  - outs
  - bases
- Filtering invalid PA rows
- Investigating missing `result` values
- Identifying structurally missing fields
- Verifying score calculations

---

## Missing Value Handling

### `result` Missing Values

Approximately 0.64% of PA rows contained missing `result`.

Analysis showed these rows were mainly:
- extra-inning automatic runner initialization rows
- non-play events
- malformed or incomplete PA records

These rows were removed before modeling.

### `locationCode`, `trajectory`, `hardness`

Missing values are structurally normal because:
- walks
- strikeouts
- non-contact events