# data_science
114-2 Data Science

## Data Source

This project uses CPBL 2024 OpenData provided by the original dataset authors.

Source repository:
https://github.com/rebas-tw/rebas.tw-open-data

License:
Open Data Commons Attribution License (ODC-By) v1.0

http://opendatacommons.org/licenses/by/1.0/

## Data Cleaning Process

The preprocessing pipeline includes:

- Reading raw JSON game data
- Aggregating inning scores into total scores
- Extracting team batting statistics
- Generating derived features
- Removing duplicated games
- Converting data types
- Exporting cleaned CSV files

## Generated Features

The cleaned dataset includes:

| Column | Description |
|---|---|
| away_total_score | Total score of away team |
| home_total_score | Total score of home team |
| total_score | Combined score of both teams |
| high_score | Whether total score >= 10 |
| home_win | Whether home team won |
| H | Total hits |
| HR | Total home runs |
| 2B | Total doubles |
| 3B | Total triples |
| BB | Total walks |
| SO | Total strikeouts |