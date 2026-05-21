# Topic 07: Data Handling — Exploring and Managing Data

## 1. Topic Summary

This topic covers the **data-handling stage** of a data science project:
how to ingest raw files, examine their structure and quality, fix the
typical defects that real-world data carries, and shape the data so it
is suitable for downstream modeling — be that supervised learning,
clustering, dimensionality reduction, or descriptive statistics.

The lecture frames data work around two activities that consume the
bulk of any project's time:

- **Exploring data** — using *summary statistics* (means, medians,
  variances, counts) and *visualization* (histograms, density plots,
  bar charts, box plots) to characterize each variable and to surface
  problems before they pollute the model.
- **Managing data** — taking action on the problems found during
  exploration: handling missing values, dealing with invalid values
  and outliers, fixing unit issues, transforming variables that span
  many orders of magnitude, normalizing/rescaling so different features
  are comparable, and rebalancing classes in imbalanced data.

The recurring lesson is *"without good data you cannot build good
models"* — and that **time invested at this stage is not wasted later**.
Visualization is described as an iterative process whose purpose is to
*answer questions about the data*, not to produce pretty pictures.

For our CPBL final project — which builds an unsupervised pipeline on
two seasons of rebas.tw open-data JSON (2023 + 2024) — this is the
single most relevant lecture. Every step we take in the preprocessing
section of the notebook is grounded in concepts from here: tidy data
layout, missing-value strategy, type conversion, range checking,
normalization for distance-based clustering, and log transforms for
heavy-tailed batting/pitching aggregates such as `hits_allowed` and
`hr_allowed`.

A second key theme is **provenance**: when we treat data we never
overwrite the source. A fixed version is created as a *new* column or a
*new* DataFrame (Senior Wang's notebook follows this religiously) so
that we can roll back if our cleaning decisions turn out to be wrong.

## 2. Outline

1. Data import with the tidyverse / pandas ecosystem.
2. Exploring data
   - Summary statistics to spot problems.
   - Visualization (single variable and pair-wise).
   - Levels of measurement (nominal / ordinal / interval / ratio).
3. Typical problems revealed by data summaries
   - Missing values (random vs systematic).
   - Invalid values and outliers.
   - Units.
   - Data range and skew.
4. Managing data
   - Fixing data-quality problems.
   - Organizing data for modeling.
   - Data transformations: discretization, normalization, log.
5. Handling imbalanced datasets
   - Random over-sampling, **SMOTE**, ADASYN.
   - Undersampling: random, Tomek Links, ENN, CNN, NCR, OSS.
   - Combinations (SMOTE + Tomek, SMOTE + ENN).
6. The `vtreat` philosophy: a *repeatable* treatment plan.
7. Supervised vs unsupervised learning — choosing tasks.

## 3. Key Concepts

- **Tidy data** — each row is one observation, each column is one
  variable, each cell is one value. Many problems are simply
  tidy-violations in disguise (e.g. nested JSON where one game record
  contains multiple plate appearances buried in an array).
- **Schema** — the contract describing column names, dtypes, allowed
  ranges, and whether nulls are allowed. Validating the schema after
  ingestion catches most upstream surprises.
- **ETL** — Extract, Transform, Load. The pipeline that moves raw data
  through a series of deterministic steps into a clean, queryable form.
- **Data provenance** — the record of *which* operation changed *which*
  value at *what* time. The lecture explicitly recommends keeping the
  original column and creating a `_fix` version side-by-side (e.g.
  `is_employed.fix`).
- **Data quality** — completeness (no unintended missing), validity
  (values inside the legal range), consistency (units agree across
  rows), accuracy (matches reality), uniqueness (no duplicates).
- **Levels of measurement** — Nominal (labels, no order), Ordinal
  (ranked, intervals unknown), Interval (ranked, equal intervals, no
  true zero), Ratio (ranked, equal intervals, true zero). The level
  governs *which descriptive statistics are meaningful*: you can take
  the mean of a ratio variable like `H` but not of nominal `team_id`.
- **Encoding** — turning categorical labels into numeric form
  (one-hot, ordinal, target/mean, hashing). Required before any
  distance-based method (k-means, PCA, KNN imputation).
- **Scaling vs normalization** — Scaling changes the *range*
  (MinMax to [0,1]) without changing the distribution shape;
  z-score *standardization* removes mean and divides by SD;
  *normalization* in the tidyverse sense refers to making a value
  *relative* (e.g. age divided by mean age).
- **Missing at random (MAR) vs missing not at random (MNAR)** — the
  lecture's "randomly vs systematically missing" distinction. When
  in doubt, **assume systematic**: missingness is itself a signal.
- **Imbalanced data** — when the class distribution is heavily skewed,
  many learners optimize for the majority. Resampling rebalances
  the training set; **never resample the test set**.

## 4. Methods

The table below covers the methods we will actually need for the CPBL
notebook (plus a few extras commonly expected in a data-science final).

### 4.1 Ingestion

| Aspect | Detail |
|---|---|
| **Name** | JSON / CSV / Parquet ingestion |
| **When** | First step of every pipeline; choice driven by source format. |
| **Algorithm** | Streaming or in-memory parse; pandas uses C parsers under the hood. |
| **Python** | `pd.read_json`, `pd.read_csv`, `pd.read_parquet`, `json.load`, `pd.json_normalize` (for nested JSON). |
| **Caveats** | `read_csv` is ~10x faster than naive parsing. JSON with deeply nested arrays usually needs `json_normalize(record_path=..., meta=...)` to flatten. Watch out for inferred dtypes — long ID strings collapsing to floats lose precision. Always pass `dtype=` for known columns. Parquet preserves dtypes and is the recommended *intermediate* format between cleaning steps. |

### 4.2 Schema validation

| Aspect | Detail |
|---|---|
| **Name** | Schema check |
| **When** | Immediately after ingestion. |
| **Algorithm** | Assert presence, dtypes, value ranges; fail fast. |
| **Python** | `pandera`, `great_expectations`, or hand-rolled `assert df.dtypes.eq(expected).all()`. |
| **Caveats** | Lecture's recommendation: run `summary(df)` (`df.describe(include='all')`) and *look at every column*. Schema drift between 2023 and 2024 dumps is a realistic CPBL risk. |

### 4.3 Missing-data handling

| Aspect | Detail |
|---|---|
| **Name** | Listwise deletion (drop) |
| **When** | Few missing rows, missingness is random, plenty of data left. |
| **Algorithm** | Remove rows containing at least one NA in the relevant columns. |
| **Python** | `df.dropna(subset=[...])` |
| **Caveats** | Bias if missingness is *systematic*. Lecture: "when in doubt, assume that missing values are missing systematically." |

| Aspect | Detail |
|---|---|
| **Name** | Constant / sentinel fill |
| **When** | Categorical NA carries meaning (e.g. *no income*, *not in active workforce*). |
| **Algorithm** | Replace NA with a designated string/value AND keep an indicator column. |
| **Python** | `df['x_fix'] = df['x'].fillna('missing')`; `df['x_was_missing'] = df['x'].isna()` |
| **Caveats** | Make a new column, not an in-place edit. Never silently replace NA with 0 in a numeric variable — 0 is itself a legal value. |

| Aspect | Detail |
|---|---|
| **Name** | Mean / median imputation |
| **When** | Numeric column, missingness is roughly random, downstream model needs a complete matrix. |
| **Algorithm** | Replace NA with the column mean (sensitive to outliers) or median (robust). |
| **Python** | `df['x_fix'] = df['x'].fillna(df['x'].mean())`; `SimpleImputer(strategy='median')`. |
| **Caveats** | Shrinks variance; biases regression slopes toward zero. Always add an *indicator* column. *Fit the imputer on the training fold only*, never on full data — otherwise leakage. |

| Aspect | Detail |
|---|---|
| **Name** | KNN imputation |
| **When** | Multiple correlated numeric features; you want to borrow strength from similar rows. |
| **Algorithm** | For each NA, find the k nearest complete neighbors (Euclidean on observed features) and take their weighted mean. |
| **Python** | `from sklearn.impute import KNNImputer; KNNImputer(n_neighbors=5).fit_transform(X)` |
| **Caveats** | Requires *scaled* inputs first (distance metric); expensive on large data. |

| Aspect | Detail |
|---|---|
| **Name** | MICE / IterativeImputer |
| **When** | Several columns have missingness; relationships between columns are roughly linear. |
| **Algorithm** | Iteratively regress each missing column on the others; cycle until convergence. |
| **Python** | `from sklearn.experimental import enable_iterative_imputer; from sklearn.impute import IterativeImputer` |
| **Caveats** | Random init implies non-determinism; set `random_state`. Can fail on highly non-linear relationships; rule of thumb: avoid if missingness >40% in any column. |

### 4.4 Type conversion

| Aspect | Detail |
|---|---|
| **Name** | Cast to correct dtype |
| **When** | After parse; `read_csv` and `read_json` make wrong guesses (especially strings that look numeric, dates as objects, booleans as strings "T"/"F"). |
| **Algorithm** | Explicit cast with `astype`, `pd.to_numeric`, `pd.to_datetime`. |
| **Python** | `df['date'] = pd.to_datetime(df['date'])`; `df['count'] = pd.to_numeric(df['count'], errors='coerce')`; `df['flag'] = df['flag'].map({'T': True, 'F': False})`. |
| **Caveats** | `errors='coerce'` silently converts bad values to NA — afterwards inspect how many NAs appeared. Category dtype saves memory but breaks naive `.mean()`. |

### 4.5 Deduplication

| Aspect | Detail |
|---|---|
| **Name** | Drop duplicates |
| **When** | The same event was logged twice (very common when concatenating game JSONs across seasons). |
| **Algorithm** | Hash each row (or subset of columns) and keep only the first/last occurrence. |
| **Python** | `df.drop_duplicates(subset=['game_id','pa_id'], keep='first')` |
| **Caveats** | Choose the *key* carefully — two legitimate plate appearances may share player and inning. Use the most specific event key. |

### 4.6 Outlier detection

| Aspect | Detail |
|---|---|
| **Name** | IQR rule |
| **When** | Single numeric column, roughly symmetric. |
| **Algorithm** | Flag points below `Q1 - 1.5*IQR` or above `Q3 + 1.5*IQR`. |
| **Python** | `q1,q3 = df['x'].quantile([0.25,0.75]); iqr=q3-q1; mask=(df['x']<q1-1.5*iqr)|(df['x']>q3+1.5*iqr)` |
| **Caveats** | Box-plot conventions; 1.5 is arbitrary, use 3 for "extreme" outliers. |

| Aspect | Detail |
|---|---|
| **Name** | z-score |
| **When** | Roughly normal column. |
| **Algorithm** | Flag points where `|x - mean| / sd > k` (k≈3). |
| **Python** | `np.abs((df['x']-df['x'].mean())/df['x'].std()) > 3` |
| **Caveats** | Mean and SD are themselves shifted by the outliers — use median/MAD if heavy-tailed. |

| Aspect | Detail |
|---|---|
| **Name** | Isolation Forest |
| **When** | Multivariate outliers; arbitrary distributions; large data. |
| **Algorithm** | Random binary trees; outliers are isolated in fewer splits than inliers. Anomaly score = inverse of mean path length. |
| **Python** | `from sklearn.ensemble import IsolationForest; clf = IsolationForest(contamination=0.05); pred = clf.fit_predict(X)` |
| **Caveats** | `contamination` controls the cut-off — set from domain knowledge. Outputs +1 inlier / -1 outlier. |

| Aspect | Detail |
|---|---|
| **Name** | Local Outlier Factor (LOF) |
| **When** | Density-based; detects local outliers (a point that is normal globally but anomalous in its neighborhood). |
| **Algorithm** | Compare each point's local density to its k neighbors' densities; ratio > 1 ⇒ outlier. |
| **Python** | `from sklearn.neighbors import LocalOutlierFactor; LocalOutlierFactor(n_neighbors=20).fit_predict(X)` |
| **Caveats** | Expensive; needs scaled inputs. Cannot do `predict` on new data unless `novelty=True`. |

### 4.7 Categorical encoding

| Aspect | Detail |
|---|---|
| **Name** | One-hot encoding |
| **When** | Nominal categories, small cardinality, no order. |
| **Algorithm** | One indicator column per level. |
| **Python** | `pd.get_dummies(df, columns=['team'])` or `OneHotEncoder(handle_unknown='ignore', sparse_output=False)`. |
| **Caveats** | Curse of dimensionality if cardinality is high. *Drop first* level to avoid the dummy trap in linear models (`drop='first'`). Unseen categories at test time need `handle_unknown`. |

| Aspect | Detail |
|---|---|
| **Name** | Ordinal encoding |
| **When** | Ordered categories (e.g. minor / mid / major league level). |
| **Algorithm** | Assign integer rank consistent with order. |
| **Python** | `OrdinalEncoder(categories=[['low','mid','high']])` |
| **Caveats** | Implies *equal spacing* between ranks — false if the variable is genuinely ordinal but unevenly spaced. |

| Aspect | Detail |
|---|---|
| **Name** | Target / mean encoding |
| **When** | High-cardinality categorical for supervised learning. |
| **Algorithm** | Replace each category with the mean target value seen for that category. |
| **Python** | `category_encoders.TargetEncoder()`; in pandas `df['cat'].map(train.groupby('cat')['y'].mean())`. |
| **Caveats** | Massive leakage risk; must be fit *only on training fold* and applied to test. Use smoothing for rare categories. |

| Aspect | Detail |
|---|---|
| **Name** | Hashing trick |
| **When** | Streaming / very high cardinality / online learning. |
| **Algorithm** | Hash category to an integer in `[0, k)`; collisions accepted. |
| **Python** | `from sklearn.feature_extraction import FeatureHasher; FeatureHasher(n_features=2**12, input_type='string')`. |
| **Caveats** | Collisions destroy interpretability; not reversible. |

### 4.8 Scaling

| Aspect | Detail |
|---|---|
| **Name** | StandardScaler (z-score) |
| **When** | Distance-based or gradient-based learners; data approximately normal. |
| **Algorithm** | `(x - mean) / sd`, column-wise. |
| **Python** | `from sklearn.preprocessing import StandardScaler; StandardScaler().fit_transform(X)`. |
| **Caveats** | Sensitive to outliers (they inflate SD). Fit on training fold only. |

| Aspect | Detail |
|---|---|
| **Name** | MinMaxScaler |
| **When** | You want a bounded output (e.g. neural net inputs), and the column is roughly uniform. |
| **Algorithm** | `(x - min) / (max - min)` → `[0,1]`. |
| **Python** | `MinMaxScaler().fit_transform(X)`. |
| **Caveats** | One extreme value compresses the rest into a tiny interval. |

| Aspect | Detail |
|---|---|
| **Name** | RobustScaler |
| **When** | Heavy-tailed or outlier-laden data — exactly our CPBL hits/HR allowed case. |
| **Algorithm** | `(x - median) / IQR`. |
| **Python** | `RobustScaler().fit_transform(X)`. |
| **Caveats** | Output not bounded. Often the safest default for messy real-world data. |

### 4.9 Normalization vs Standardization

| Aspect | Detail |
|---|---|
| **Name** | Normalization (rescaling) |
| **When** | When *relative* size matters more than absolute (e.g. age / mean(age)). |
| **Algorithm** | Divide by some reference (mean, max, L2 norm). |
| **Python** | `df['age_norm'] = df['age'] / df['age'].mean()`; `Normalizer(norm='l2')` for row-wise. |
| **Caveats** | Lecture's *Code1* example. Distribution shape unchanged; only scale. |

| Aspect | Detail |
|---|---|
| **Name** | Standardization (z-score) |
| **When** | Center and equalize variance — required for PCA and clustering. |
| **Algorithm** | `(x - mean) / sd`. |
| **Python** | See StandardScaler above. |
| **Caveats** | Lecture's *Code2*. Output has mean 0, sd 1; distribution shape preserved. |

### 4.10 Log / Box-Cox / Yeo-Johnson transforms

| Aspect | Detail |
|---|---|
| **Name** | Log transform |
| **When** | Data spans many orders of magnitude; right-skewed; multiplicative process (lecture's "5% increase per night"). |
| **Algorithm** | `log(x)` (use `log1p(x)` if zero values exist). |
| **Python** | `np.log1p(df['x'])`; or the lecture's `signedlog10` for variables that can be negative. |
| **Caveats** | Undefined at 0/negative → use `log1p` or `signedlog`. Interpretation in log units; back-transform carefully. |

| Aspect | Detail |
|---|---|
| **Name** | Box-Cox |
| **When** | Strictly positive variable; want to choose the best power transform automatically. |
| **Algorithm** | `((x^λ - 1) / λ)` if λ≠0 else `log(x)`. λ chosen by max-likelihood. |
| **Python** | `from scipy.stats import boxcox; xt, lam = boxcox(x)`. |
| **Caveats** | Strictly positive; for data with zero/negatives use **Yeo-Johnson** (`PowerTransformer(method='yeo-johnson')`). |

### 4.11 Datetime feature engineering

| Aspect | Detail |
|---|---|
| **Name** | Extract calendar features |
| **When** | Date columns exist and seasonality matters. |
| **Algorithm** | Decompose into year / month / day / weekday / is_weekend / day-of-season. |
| **Python** | `df['month'] = df['date'].dt.month`; `df['dow'] = df['date'].dt.dayofweek`; cyclical encode with `sin(2π·month/12)`, `cos(...)`. |
| **Caveats** | Watch out for tz-naive vs tz-aware (mixing them throws). Game dates can land at midnight if only the date was logged. |

### 4.12 Joins / merges

| Aspect | Detail |
|---|---|
| **Name** | Inner / left / right / outer / cross join |
| **When** | Combining multiple sources (game-level + plate-appearance-level + roster). |
| **Algorithm** | Match on key(s); union or intersect rows depending on join type. |
| **Python** | `pd.merge(left, right, on='game_id', how='left')`; `df.join(other, on='player_id', how='left')`. |
| **Caveats** | Many-to-many joins can explode the row count; always check shape before/after. Watch for key-column dtype mismatches (`int` vs `str` silently fail to match). Use `validate='1:1'` etc. as a safety check. |

### 4.13 Long ↔ Wide reshape

| Aspect | Detail |
|---|---|
| **Name** | `pivot` / `melt` |
| **When** | Tidying nested or wide records into one-row-per-observation form. |
| **Algorithm** | Wide→long: stack columns into a `variable, value` pair; long→wide: unstack a key into columns. |
| **Python** | `df.melt(id_vars=['game_id'], value_vars=[...], var_name='inning', value_name='runs')`; `df.pivot(index='player', columns='season', values='H')`. |
| **Caveats** | Duplicate (index, columns) pairs cause `pivot` to fail — use `pivot_table` with an aggregator. |

### 4.14 Discretization (binning)

| Aspect | Detail |
|---|---|
| **Name** | `cut` (fixed breaks) / `qcut` (quantile) |
| **When** | Non-linear relationship; you want categorical buckets; the lecture's *converting continuous to discrete*. |
| **Algorithm** | Assign each value to an interval; output is an ordered categorical. |
| **Python** | `pd.cut(df['income'], bins=[0,10000,50000,100000,250000,1e6])`; `pd.qcut(df['x'], q=4)`. |
| **Caveats** | Cuts the dataset into possibly unbalanced bins. Quantile binning gives equal counts but breaks at varying values. |

### 4.15 Class imbalance — SMOTE family

| Aspect | Detail |
|---|---|
| **Name** | Random over-sampling |
| **When** | Quick fix; minority class very small. |
| **Algorithm** | Duplicate random minority rows until counts match. |
| **Python** | `from imblearn.over_sampling import RandomOverSampler` |
| **Caveats** | Doesn't add information; overfits the minority decision region (lecture: leads to many tight terminal nodes in a tree). |

| Aspect | Detail |
|---|---|
| **Name** | SMOTE (Chawla 2002) |
| **When** | Continuous numeric features; need *synthetic* minority examples, not duplicates. |
| **Algorithm** | For a minority point `x`, pick a k-NN minority neighbor `x'`; create a new point on the line segment between them at a random fraction. |
| **Python** | `from imblearn.over_sampling import SMOTE; SMOTE(k_neighbors=5, random_state=0).fit_resample(X, y)`. |
| **Caveats** | Apply *after* train/test split; only to the training fold. Needs numeric features (use SMOTENC for mixed types). Can synthesize points across class boundaries if classes overlap (use Borderline-SMOTE or ADASYN). |

| Aspect | Detail |
|---|---|
| **Name** | Borderline-SMOTE / ADASYN |
| **When** | Want focus on hard examples. |
| **Algorithm** | Borderline: only synthesize from misclassified minority points. ADASYN: density-weighted — more synthesis where minority is sparse. |
| **Python** | `imblearn.over_sampling.BorderlineSMOTE`, `imblearn.over_sampling.ADASYN`. |
| **Caveats** | Slightly slower; more sensitive to noise. |

### 4.16 Class imbalance — undersampling

| Aspect | Detail |
|---|---|
| **Name** | Random Undersampling |
| **When** | Majority class is enormous; speed matters. |
| **Algorithm** | Drop random majority rows. |
| **Python** | `imblearn.under_sampling.RandomUnderSampler`. |
| **Caveats** | Discards information. |

| Aspect | Detail |
|---|---|
| **Name** | Tomek Links |
| **When** | Cleaning the decision boundary. |
| **Algorithm** | A Tomek pair is two nearest-neighbor points from different classes — drop the majority-class member. |
| **Python** | `imblearn.under_sampling.TomekLinks`. |
| **Caveats** | Only removes a few points; usually combined with SMOTE. |

| Aspect | Detail |
|---|---|
| **Name** | Edited Nearest Neighbors (ENN) |
| **When** | Remove noisy majority points. |
| **Algorithm** | Drop any sample whose class disagrees with the majority of its k=3 nearest neighbors. |
| **Python** | `imblearn.under_sampling.EditedNearestNeighbours`. |
| **Caveats** | Aggressive; can shrink data significantly. |

| Aspect | Detail |
|---|---|
| **Name** | NearMiss / CNN / OSS / NCR |
| **When** | Specialized cleanups. NearMiss-1/2/3 use KNN distances to the minority; CNN keeps only the smallest condensed set that reproduces classification; OSS = Tomek + CNN; NCR = CNN + ENN. |
| **Python** | All in `imblearn.under_sampling`. |
| **Caveats** | More moving parts → more random seeds to control. |

### 4.17 Repeatable treatment plans (vtreat philosophy)

| Aspect | Detail |
|---|---|
| **Name** | Fitted preprocessor / Pipeline |
| **When** | You must apply the *same* cleaning to training data, validation data, and any future scoring data. |
| **Algorithm** | Record all parameters learned from training (means, encodings, scaler stats); apply via `transform`. |
| **Python** | `sklearn.pipeline.Pipeline`, `ColumnTransformer`, or R's `vtreat`. |
| **Caveats** | Pickle the fitted pipeline. Never refit on test or production data. |

## 5. Code Snippets

### 5.1 Read JSON, flatten nested arrays

```python
import json
import pandas as pd
from pathlib import Path

# Load one season at a time, concatenate later
def load_games(path):
    with open(path, 'r', encoding='utf-8') as f:
        raw = json.load(f)
    return pd.json_normalize(
        raw,
        record_path=['plateAppearances'],
        meta=['gameId', 'date', ['venue','name']],
        errors='ignore'
    )

pa_2023 = load_games('rebas_2023_games.json')
pa_2024 = load_games('rebas_2024_games.json')
pa = pd.concat([pa_2023, pa_2024], ignore_index=True)
```

### 5.2 First-look exploration

```python
print(pa.shape)
print(pa.dtypes)
print(pa.describe(include='all').T)         # summary() equivalent
print(pa.isna().mean().sort_values(ascending=False).head(20))
```

### 5.3 Treat missing categorical (per lecture)

```python
pa['is_pitcher_fix'] = pa['is_pitcher'].fillna('missing')
# Or with a more informative label:
pa['is_pitcher_fix'] = pa['is_pitcher'].fillna('unknown_role')
```

### 5.4 Treat missing numeric with indicator (per lecture)

```python
mean_inn = pa['innings_pitched'].mean()
pa['innings_pitched_missing'] = pa['innings_pitched'].isna()
pa['innings_pitched_fix']     = pa['innings_pitched'].fillna(mean_inn)
```

### 5.5 Outlier handling with mutate-to-NA (R-equivalent)

```python
# diamonds2 <- diamonds %>% mutate(y = ifelse(y < 3 | y > 20, NA, y))
mask_bad = (pa['hits_allowed'] < 0) | (pa['hits_allowed'] > 30)
pa.loc[mask_bad, 'hits_allowed'] = pd.NA
```

### 5.6 Discretize a continuous variable

```python
breaks  = [0, 1, 3, 6, 10, float('inf')]
labels  = ['none', 'low', 'mid', 'high', 'extreme']
pa['hits_allowed_band'] = pd.cut(pa['hits_allowed'],
                                 bins=breaks, labels=labels,
                                 include_lowest=True)
```

### 5.7 Normalize / standardize

```python
# Lecture Code1 — relative to mean
pa['ip_norm'] = pa['innings_pitched'] / pa['innings_pitched'].mean()

# Lecture Code2 — z-score
mu = pa['innings_pitched'].mean()
sd = pa['innings_pitched'].std()
pa['ip_z'] = (pa['innings_pitched'] - mu) / sd
```

### 5.8 Log-transform a heavy-tailed feature

```python
import numpy as np
pa['hr_allowed_log'] = np.log1p(pa['hr_allowed'])     # log(1+x), safe at 0

def signed_log10(x):
    return np.where(np.abs(x) <= 1, 0, np.sign(x) * np.log10(np.abs(x)))
```

### 5.9 ColumnTransformer pipeline

```python
from sklearn.compose      import ColumnTransformer
from sklearn.pipeline     import Pipeline
from sklearn.impute       import SimpleImputer, KNNImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder, RobustScaler

num_cols = ['innings_pitched','H','AB','hits_allowed','hr_allowed',
            'whip_like','middle_runs','late_runs','run_per_hit']
cat_cols = ['team','scored_first']

num_pipe = Pipeline([
    ('impute', SimpleImputer(strategy='median')),
    ('scale',  RobustScaler()),
])
cat_pipe = Pipeline([
    ('impute', SimpleImputer(strategy='most_frequent')),
    ('ohe',    OneHotEncoder(handle_unknown='ignore', sparse_output=False)),
])
pre = ColumnTransformer([
    ('num', num_pipe, num_cols),
    ('cat', cat_pipe, cat_cols),
])
X = pre.fit_transform(pa)            # fit on training data only
```

### 5.10 SMOTE on the *training* fold

```python
from sklearn.model_selection import train_test_split
from imblearn.over_sampling  import SMOTE

X_tr, X_te, y_tr, y_te = train_test_split(X, y, stratify=y,
                                          test_size=0.2, random_state=42)
X_tr, y_tr = SMOTE(random_state=42).fit_resample(X_tr, y_tr)
```

### 5.11 Isolation Forest for season outliers

```python
from sklearn.ensemble import IsolationForest
iso = IsolationForest(contamination=0.02, random_state=0)
pa['is_anomaly'] = iso.fit_predict(pa[num_cols].fillna(0))
```

### 5.12 Joins & shape checks

```python
games   = pd.read_parquet('games.parquet')
batters = pd.read_parquet('batterBox.parquet')

n_before = len(batters)
merged = batters.merge(games[['game_id','date','home_team']],
                       on='game_id', how='left', validate='m:1')
assert len(merged) == n_before, "join changed row count unexpectedly"
```

### 5.13 Long-form reshape for innings runs

```python
inn_long = (pa.melt(id_vars=['game_id','team'],
                    value_vars=[f'inn{i}_runs' for i in range(1,10)],
                    var_name='inning', value_name='runs')
              .assign(inning=lambda d: d['inning'].str.extract(r'(\d+)').astype(int)))
```

## 6. Examples / Datasets

- **custdata** (lecture) — customer-segmentation toy table illustrating
  missing values in `is_employed`, `housing_type`, `income`; the
  recommended fixes (`is.employed.fix`, indicator columns, income
  binning) carry across directly to pandas.
- **diamonds** (ggplot2 / seaborn) — used to illustrate visualization
  of continuous variables, unusual values in `y` (some diamonds with
  y=0 or y>30 mm — physically impossible).
- **mtcars** — interactive plotting examples; not used in CPBL.
- **CPBL rebas.tw 2023 + 2024** (our project) — nested JSON with games,
  plate appearances, batter boxes, pitcher boxes, events, runners.

## 7. Pitfalls

- **Data leakage** — fitting an imputer, scaler, encoder, or
  resampler on the full dataset (then splitting) bleeds test-set
  information into training. **Always split first**, fit transformers
  on the training partition only, then `transform` the held-out
  partition. For our unsupervised project leakage is less catastrophic,
  but if we later cross-validate cluster stability we must still
  refit each fold's preprocessor.
- **Train/test contamination via target encoding** — replace a category
  with its mean target using the *full* dataset → the test target leaks
  in. Mitigation: out-of-fold target encoding with smoothing.
- **Silent NaN propagation** — `np.nan` is contagious in arithmetic;
  one missing value can poison a column-sum. Check `df.isna().sum()`
  *after every transformation*, not just at ingestion.
- **dtype gotchas** — `bool` columns containing NA get up-cast to
  `object`; integer columns with NA become `float64` (NumPy has no
  integer NA). Use pandas nullable `Int64`, `boolean`, `string` dtypes
  for these. ID columns silently widening to `float` lose precision
  past 2^53.
- **Sample bias** — the lecture's "Sampling bias" example: only looking
  at `EarnedIncome + CapitalGains > 500000` and computing a
  correlation gives a wildly different answer than the full
  population. For CPBL: filtering to "only starting pitchers" or
  "only winning games" changes everything downstream.
- **Mean imputation under heavy skew** — the mean is pulled by
  outliers; median imputation is safer. Always look at the histogram
  before deciding.
- **Forgetting indicator columns** — once you impute, the model can
  no longer distinguish *imputed* from *observed*. Add a
  `*_was_missing` boolean.
- **One-hot dimension explosion** — encoding `player_id` (hundreds of
  unique values) with one-hot adds hundreds of nearly-empty columns
  and ruins distance metrics. Use hashing, embeddings, or simply drop.
- **Scaler refit at inference** — refitting StandardScaler on each
  scoring batch gives non-stationary outputs. Pickle the fitted
  transformer and reload.
- **Unit confusion** — the lecture's `Income = income/1000` warning:
  comparing dollars to thousands of dollars yields nonsensical
  results.
- **`merge` row-count blowup** — many-to-many joins multiply rows.
  Use `validate='1:1' | '1:m' | 'm:1'` to guard.
- **Imbalanced resampling applied to test set** — only resample
  training data; evaluating on a balanced fake test set gives
  optimistic and misleading metrics.

## 8. Cross-references

- **Topic 05-1 (PCA & SVD)** — PCA requires standardized inputs; the
  scaling decisions in this topic feed directly into PCA in Section 5.
- **Topic 05-2 (Feature explanation — LIME, SHAP)** — explanations
  read on standardized features can be misleading; SHAP values must
  be back-transformed for interpretability.
- **Clustering (k-means, DBSCAN, hierarchical)** — distance metrics
  amplify scaling issues. Robust scaling is recommended for our CPBL
  use case because counts like `hits_allowed` are right-skewed.
- **EDA topic** — descriptive statistics, box plots, and density
  plots described here are the visual layer on top of cleaned data.
- **Imbalanced learning** — even though our final project is
  unsupervised, the SMOTE / Tomek discussion is relevant if we later
  attach a supervised "predict winning team" head.
- **Tidy data (Wickham)** — the `melt`/`pivot` reshape patterns are
  the practical embodiment of tidy-data philosophy.

## 9. Relevance to CPBL — Concrete Preprocessing Plan for rebas.tw

The rebas.tw 2023+2024 dump arrives as deeply nested JSON. A single
**game** contains arrays of **batterBox** and **pitcherBox**
records, each containing **plate appearance (PA)** entries, each of
which contains **event** sub-records (including `runner` movements).
Senior Wang's target feature set — `run_per_hit`, `innings_pitched`,
`H`, `scored_first`, `whip_like`, `hr_allowed`, `hits_allowed`, `AB`,
`middle_runs`, `late_runs` — spans both batting and pitching aggregates
and lives at the per-team-per-game grain. The preprocessing pipeline
below maps every step to a concept from this topic.

### Step 1 — Ingest both seasons (Section 4.1)

- Read `rebas_2023.json` and `rebas_2024.json` separately.
- Use `pd.json_normalize` with explicit `record_path` and `meta`
  arguments to flatten the game → batterBox → PA → event → runner
  hierarchy into **four tidy tables**: `games_df`, `batter_box_df`,
  `pitcher_box_df`, `pa_df`. (One-row-per-observation per tidy-data
  rules.)
- Pass `dtype={'game_id': 'string', 'player_id': 'string'}` to keep
  IDs as strings — otherwise pandas may downcast them to `float64`
  and corrupt the matches in Step 6.
- Concatenate the two seasons with a `season` indicator column:
  `df['season'] = 2023` then `pd.concat([df23, df24], ignore_index=True)`.

### Step 2 — Schema validation (Section 4.2)

- Right after ingestion call `df.dtypes`, `df.describe(include='all')`,
  and `df.isna().mean()` for every flattened table.
- Compare 2023 vs 2024 column sets to catch schema drift (rebas may
  have added/renamed fields between seasons). Any column present in
  one season but not the other becomes a candidate for *systematic*
  missingness in the merged frame.
- Assert that every game has both a `homeTeam` and a `awayTeam`
  record (no orphan rows) before proceeding.

### Step 3 — Type conversion (Section 4.4)

- Parse `game.date` with `pd.to_datetime` (timezone Asia/Taipei).
- Cast counting columns (`H`, `AB`, `hits_allowed`, `hr_allowed`,
  `middle_runs`, `late_runs`) to nullable `Int64` so missing remains
  representable.
- Convert `scored_first` to `boolean` dtype, mapping the rebas
  representation (likely `0/1`, `T/F`, or `home/away`) to a clean
  `bool` series.
- Convert `innings_pitched` from the conventional `5.2` (= 5 + 2/3)
  to a true float by `whole + (frac*10)/3`. **This is a classic
  baseball-stat gotcha** — `5.2` is **not** the same as 5.20.

### Step 4 — Deduplication (Section 4.5)

- Each PA carries a (`game_id`, `inning`, `pa_seq`) natural key. Use
  `df.drop_duplicates(subset=['game_id','inning','pa_seq'])`.
- Verify that game-level keys are unique: `assert games_df['game_id'].is_unique`.

### Step 5 — Compute per-team-per-game aggregates

- Group `batter_box_df` by (`game_id`,`team_id`) and sum `H`, `AB`,
  `R`, `HR` etc., yielding our `H`, `AB` features.
- Group `pitcher_box_df` by (`game_id`,`team_id`) and aggregate
  `innings_pitched` (handling the 5.2-style values from Step 3),
  `hits_allowed`, `hr_allowed`, `BB`, plus the derived
  `whip_like = (BB + hits_allowed) / innings_pitched`.
- Compute `run_per_hit = R / H` with explicit zero-handling:
  use `np.where(H > 0, R/H, 0)` or `R / H.replace(0, np.nan)` then
  fill — choose explicitly and *document* the choice.
- Mark `scored_first` by ranking innings in the PA table and finding
  the team of the first run-scoring PA per game.
- Sum runs in innings 1-3, 4-6, 7+ to yield `early_runs`,
  `middle_runs`, `late_runs`.

### Step 6 — Joins (Section 4.12)

- Left-join the batting aggregate and pitching aggregate on
  (`game_id`,`team_id`) → one row per *team-game*.
- Left-join `games_df` to add date, venue, opponent.
- Use `validate='1:1'` on the team-game join; if it fails, return to
  Step 4 because there is duplicate keying upstream.

### Step 7 — Missing-data treatment (Section 4.3)

- For numeric features (`whip_like`, `run_per_hit`):
  - Build an indicator column `*_was_missing` first.
  - Impute with **median** (not mean): the columns are right-skewed
    so the lecture's caveat applies.
  - Use `SimpleImputer(strategy='median')` inside the pipeline so
    the same statistics are reused on any future season.
- For `scored_first`: missingness implies a tie/no-run game; encode
  as a new category `'no_first'` rather than dropping (lecture's
  "missing as a category" pattern).
- Decide *before any fitting* whether to drop or impute games with
  rain delays / suspended status — these are missing-systematically.

### Step 8 — Outlier scan (Section 4.6)

- Box-plot `hits_allowed`, `hr_allowed`, `innings_pitched`. Apply
  the IQR rule to flag (not drop) extreme values, e.g. a starter
  with `hr_allowed = 7` is rare but real. Use `RobustScaler` in
  step 10 rather than dropping.
- Run `IsolationForest(contamination=0.02)` on the full feature
  matrix to catch multivariate weird games (e.g. an 18-inning
  marathon) and tag them with `is_anomaly`. Keep them; they often
  drive interesting clusters.

### Step 9 — Transformations (Section 4.10)

- Apply `np.log1p` to right-skewed counts: `hits_allowed_log`,
  `hr_allowed_log`. The lecture explicitly justifies log transforms
  for "data over several orders of magnitude" — this is exactly
  what we get when a starter pitches 7 innings vs a position player
  who pitched 1 in a blowout.
- Keep both the raw and log-transformed columns; the unsupervised
  comparison in the EDA / PCA section can run with either.

### Step 10 — Encoding and scaling for clustering / PCA (Sections 4.7-4.8)

- One-hot encode `team_id` only if we expect to *retain* identity in
  the clustering (probably not — we want behavior-driven clusters).
  Otherwise drop or replace with team-aggregate stats.
- Use `RobustScaler` for all numeric features feeding into PCA /
  k-means. Justification: heavy tails and outliers (see Step 8) make
  StandardScaler unreliable, MinMax compresses the bulk of the data,
  Robust uses median/IQR which the topic recommends for skewed data.
- Wrap everything in a `ColumnTransformer` + `Pipeline` so the
  identical treatment can be replayed on 2025 data (vtreat principle).

### Step 11 — Provenance: never overwrite raw

- Always write `df['<col>_fix']` for treated versions; keep raw
  `df['<col>']` accessible. Mirrors the lecture's
  `is.employed.fix` discipline.
- Persist each intermediate stage as Parquet
  (`raw_2023_2024.parquet`, `clean_2023_2024.parquet`,
  `features_2023_2024.parquet`) so the notebook is reproducible
  even if the JSON disappears.

### Step 12 — Final tidy assertion

Before the EDA section runs, assert the tidy contract:

- One row per (`season`,`game_id`,`team_id`).
- Every column has the expected dtype.
- No NaNs remain in the columns Senior Wang named *unless* an
  explicit `*_was_missing` indicator co-exists.
- Counts of unique team-games match the schedule (≈120 reg-season
  games per team per season ⇒ ≈240 games per team across the two
  seasons, ≈1440 team-game rows for the six CPBL franchises).

If any assertion fails, fix the data — do not work around it in
modeling code. This is precisely the lecture's closing message:

> *Take the time to examine your data before diving into the modeling.*
> *Time spent here is time not wasted during the modeling process.*
