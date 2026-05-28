# Topic 06 — Data Visualization for EDA and Results

## 1. Topic Summary

This topic is a tour through *static and interactive* data-visualization
techniques used during exploratory data analysis (EDA) and during the
presentation of results. The original lecture (Prof. Jia-Ming Chang,
NCCU CS) is delivered in R via `ggplot2` and `ggvis`/`shiny`, but every
idea translates directly to Python (`matplotlib`, `seaborn`, `plotly`,
`altair`). The talk insists on two ideas at every step:

1. **A chart is a hypothesis-generation device**. Each plot answers
   "is there a relationship?" or "what is the shape of this
   distribution?" The visual decision (chart family + encoding) must
   match the question.
2. **Decorations are not data**. Pie charts with more than 5 slices,
   double horizontal rules in tables, dense vertical gridlines, and
   gradient backgrounds all *add ink without adding information*.

Specific lecture content covered: a chart-type cheatsheet, table
typography rules (no vertical rules, no double rules, label and align
everything, group with `\multicolumn`/`\cmidrule`), and recipes in
`ggplot2`/`ggvis`/`shiny` for boxplots (regular, variable-width,
notched), scatterplots (with alpha, hexbin, 2-D bin, jitter, lowess
fit), bar charts (stacked, dodged, fill, faceted), histograms/density
plots, and line plots. For our CPBL final project (Python), we will
reuse all of the *principles* but with the Python plotting stack.

## 2. Outline

The hierarchy used in the lecture and adapted here:

- **Tips & taste** (chart-junk, the chart-type guide, table layout).
- **Univariate** — histogram, KDE/density, ridge plot, box plot,
  violin plot, ECDF, rug strips.
- **Bivariate** —
  - numeric × numeric: scatter, line, hexbin, 2-D histogram,
    contour/density, regression-overlay scatter.
  - numeric × categorical: box, violin, strip/swarm, bar of means
    with CIs.
  - categorical × categorical: count grid (`geom_count`), heatmap of
    counts, stacked / dodged / filled bar chart, mosaic plot.
- **Multivariate** — scatter-matrix / pair plot, correlation heatmap,
  parallel coordinates, Andrews curves, radar/spider plot,
  small-multiples / faceting, bubble chart (encoding size & colour).
- **Time-series** — line + smoother, calendar heatmap, run chart,
  cumulative line, season-trend decomposition plot, control chart.
- **Geospatial** — choropleth (province / stadium dot map). For CPBL
  this is *low priority* because we only have ~5 home stadiums; a dot
  map is enough.
- **Dimensionality-reduction projections** — PCA 2-D scatter,
  PCA scree, t-SNE 2-D, UMAP 2-D, biplot of loadings, dendrogram /
  hierarchical-cluster heatmap, silhouette plot.
- **Interactive** — `plotly` hover-tooltips, `shiny`/`streamlit`
  sliders and dropdowns, brushing/linking.

## 3. Key Concepts

### 3.1 Chart selection

Pick a chart from the question, not from a gallery.

| Question                                  | Chart family                              |
|-------------------------------------------|-------------------------------------------|
| What does *one* number look like?         | histogram, KDE, box, violin, ECDF         |
| How do *two* numbers move together?       | scatter (+ smooth), hexbin, 2-D bin       |
| One number split by one category?         | box / violin / strip / swarm by category  |
| How do *two* categories co-occur?         | mosaic, count-grid, heatmap of counts     |
| How does a number evolve over time?       | line + smoother, calendar heat            |
| How do *many* numbers relate?             | scatter-matrix, correlation heatmap, PCP  |
| Structure in high-D feature space?        | PCA / t-SNE / UMAP scatter, dendrogram    |

### 3.2 Perception (rank of channels)

Position on a common scale > position on non-aligned scales > length
> angle/slope > area > colour intensity > colour hue > volume.
Translation: encode the *most important* variable on the x or y axis
and only reach for colour or size when the axes are spent.

### 3.3 Colour

- **Sequential** (one variable, ordered) — `viridis`, `cividis`,
  `magma`. Perceptually uniform and colour-blind safe.
- **Diverging** (around a meaningful midpoint, e.g. correlation 0 or
  z-score 0) — `coolwarm`, `RdBu`, `PRGn`. Always set
  `vmin=-vmax`.
- **Categorical** — `tab10`, `Set2`. Limit to <= 8 hues.
- Never use the rainbow / jet palette: it lies about ordering.

### 3.4 Scale

- Use **log scale** when the variable spans 2+ orders of magnitude
  (e.g. salary, runs per season for benched players).
- Use a **square-root scale** for counts when zeros matter.
- Always start bar-chart y-axes at zero; never lie with truncated bars.
- For line plots a non-zero baseline is *acceptable* if the change is
  what matters.

### 3.5 Faceting (small multiples)

A 4 × 3 panel of identical mini-charts is almost always more
informative than a single dense chart with 12 colours. The eye can
compare panels rapidly when axes are *fixed* across panels. Vary
axes only when distributions differ in scale (then state it in the
caption).

### 3.6 Annotations and chart-junk

Strip out: 3-D effects, drop shadows, heavy gridlines, frames around
legends, decorative images. Add: a one-sentence caption, axis units,
direct labels on the largest/smallest series, and a reference line
(e.g. league mean) so the eye has an anchor.

## 4. Methods — chart-by-chart reference

### 4.1 Histogram
- **When to use** — explore the *shape* of a single numeric variable
  (skewness, modality, outliers).
- **Call** — `ax.hist(x, bins=30)` / `sns.histplot(x, bins='auto')` /
  `plotly.express.histogram`.
- **Caveats** — bin-width choice changes the story. Show two
  bin-widths if you suspect bi-modality. Histograms hide ties and
  are not great for very small n.

### 4.2 KDE (density plot)
- **When to use** — same questions as a histogram, but smoother;
  good for overlaying multiple groups.
- **Call** — `sns.kdeplot(x, hue=g, common_norm=False)`.
- **Caveats** — bandwidth (`bw_adjust`) is a hyper-parameter; the
  default Silverman rule over-smooths bi-modal data. KDE can show
  density below zero for strictly positive variables (e.g. hits) —
  set `clip=(0, None)`.

### 4.3 Boxplot
- **When to use** — quick five-number summary; ideal for *many*
  groups side by side. The lecture covers regular, variable-width
  (width ∝ √n), and notched (≈ 95 % CI for the median).
- **Call** — `sns.boxplot(data=df, x='team', y='OBP', notch=True)`.
- **Caveats** — hides multi-modality; whisker definition varies
  (Tukey 1.5×IQR vs 5–95th percentile). Reorder by median for
  readability (`reorder(class, hwy, FUN=median)` in R; in seaborn
  pass `order=df.groupby('team')['OBP'].median().sort_values().index`).

### 4.4 Violin plot
- **When to use** — boxplot + KDE in one; shows shape and quantiles.
- **Call** — `sns.violinplot(data=df, x='team', y='OBP',
  inner='quartile')`.
- **Caveats** — needs > ~30 observations per group; over-smooths tiny
  groups. Split violins (`split=True`, `hue=...`) compare two
  conditions cleanly.

### 4.5 Strip / Swarm plot
- **When to use** — small n; show every observation.
- **Call** — `sns.stripplot(jitter=0.2)` or `sns.swarmplot`.
- **Caveats** — swarm fails (errors) when n is huge; jitter strips
  scale better.

### 4.6 Scatter plot
- **When to use** — two numeric variables, look for trend, clusters,
  outliers.
- **Call** — `plt.scatter(x, y, alpha=0.3)` /
  `sns.scatterplot(data=df, x='IP', y='WHIP', hue='team')` /
  `px.scatter(..., trendline='lowess')`.
- **Caveats** — overplotting is the #1 problem. Use `alpha`, jitter,
  hexbin, or 2-D bin (see below). Don't fit a line by eye — overlay
  `sns.regplot` or `lowess`.

### 4.7 Scatter-matrix / pair plot
- **When to use** — first look at a data frame with <= ~10 numeric
  columns.
- **Call** — `sns.pairplot(df, hue='season', diag_kind='kde',
  corner=True)` / `pd.plotting.scatter_matrix`.
- **Caveats** — quadratic in number of variables (a 12 × 12 grid is
  144 panels); cull columns first. Use `corner=True` to halve the
  ink.

### 4.8 Heatmap / Correlation matrix
- **When to use** — show pairwise associations among many numeric
  features; show counts of a category × category contingency.
- **Call** —
  ```python
  corr = df[features].corr()
  sns.heatmap(corr, vmin=-1, vmax=1, cmap='coolwarm', annot=True)
  ```
- **Caveats** — for correlation, *always* use a diverging palette
  symmetric around 0, otherwise the colour suggests asymmetric
  importance. Mask the upper triangle for compactness. Pearson
  assumes linear; consider Spearman or Kendall for skewed counts
  (hits, runs).

### 4.9 Parallel coordinates
- **When to use** — see how *clusters or seasons* differ across many
  scaled features at once.
- **Call** — `pd.plotting.parallel_coordinates(df_scaled, 'cluster')`
  / `plotly.express.parallel_coordinates(df, color='cluster')`.
- **Caveats** — useless without z-scoring (one axis dominates).
  Order axes by similarity (correlation) so adjacent lines stay
  smooth. Limit to 100–300 lines; use alpha.

### 4.10 Radar / spider plot
- **When to use** — compare a *small* number of profiles (≤ 6) across
  ~5–8 features. Iconic in scouting reports.
- **Call** — `plotly.express.line_polar(df_long, r='value',
  theta='feature', line_close=True, color='team')`.
- **Caveats** — area is misleading (it grows quadratically with the
  radius). Always show the underlying numbers. Order the axes
  deliberately because reordering changes the apparent area.

### 4.11 t-SNE / UMAP 2-D projection
- **When to use** — reveal clusters in a high-dimensional feature
  space when PCA loses too much variance.
- **Call** —
  ```python
  from sklearn.manifold import TSNE
  from umap import UMAP
  emb = UMAP(n_neighbors=15, min_dist=0.1).fit_transform(X_scaled)
  ax.scatter(emb[:,0], emb[:,1], c=labels, cmap='tab10')
  ```
- **Caveats** — distances *between* clusters are not meaningful; only
  local neighbourhoods are preserved. Re-run with several seeds and
  perplexity/n_neighbours values before claiming a structure exists.

### 4.12 Dendrogram
- **When to use** — visualise hierarchical clustering linkages.
- **Call** — `scipy.cluster.hierarchy.dendrogram(linkage(X, 'ward'))`.
- **Caveats** — cut height is a hyper-parameter; pair the dendrogram
  with a *cluster-mean heatmap* so the reader sees what each cluster
  is. `clustermap` from seaborn does both at once.

### 4.13 Hexbin / 2-D histogram
- **When to use** — when a scatter plot has >5000 points and turns
  into a black blob.
- **Call** — `plt.hexbin(x, y, gridsize=40, mincnt=1)` or
  `sns.jointplot(kind='hex')`.
- **Caveats** — the hex grid must be calibrated (gridsize ≈ √n / 5);
  too fine and you reproduce the scatter, too coarse and you hide
  structure.

### 4.14 Ridgeplot (joyplot)
- **When to use** — many distributions stacked vertically; "ridges"
  reveal shifts over time or across teams.
- **Call** — `joypy.joyplot(df, by='month', column='hits',
  colormap=plt.cm.viridis)` (also `sns.FacetGrid + sns.kdeplot`).
- **Caveats** — overlap obscures tails; pick a row-height so ridges
  graze each other without blocking.

### 4.15 Facet grid / small multiples
- **When to use** — same chart × every level of a category (team,
  month, inning bucket).
- **Call** — `g = sns.FacetGrid(df, col='team', col_wrap=5,
  sharey=True); g.map_dataframe(sns.scatterplot, 'IP', 'WHIP')`
  / `px.scatter(..., facet_col='team', facet_col_wrap=5)`.
- **Caveats** — keep axes shared (`sharey=True`) unless distributions
  differ wildly. Sort panels by a summary statistic, not
  alphabetically.

### 4.16 Calendar / time-series heatmap
- **When to use** — show seasonality across the regular season
  (March → October).
- **Call** — `calplot.calplot(series)` or pivot to (week, weekday)
  and `sns.heatmap`.
- **Caveats** — weeks with few games will look anomalously cold; show
  game-count overlay or normalise by games played.

### 4.17 Line plot
- **When to use** — clean ordered relationship, especially time.
- **Call** — `ax.plot(date, runs_pg)` / `sns.lineplot`.
- **Caveats** — the lecture warns: when data is *noisy and not
  cleanly related*, a line plot turns into spaghetti — switch to a
  scatter + smoother. Never draw a line between non-ordered
  categorical x-values.

### 4.18 Bar chart
- **When to use** — counts or means by category.
- **Call** — `sns.barplot(x='team', y='runs', data=df,
  errorbar='ci')` / `sns.countplot`.
- **Caveats** — limit categories to ~10 and sort by height (Pareto
  order) unless ordering carries meaning. *Stacked* compares totals;
  *dodged* compares groups; *filled* (proportional stacked)
  compares shares.

### 4.19 ECDF
- **When to use** — when comparing distributions and you don't want
  to argue about bin-widths.
- **Call** — `sns.ecdfplot(data=df, x='OBP', hue='team')`.
- **Caveats** — less intuitive for non-statisticians than a histogram;
  pair it with a small explanatory caption.

### 4.20 Mosaic plot
- **When to use** — two or three categorical variables, areas
  proportional to counts.
- **Call** — `statsmodels.graphics.mosaicplot.mosaic`.
- **Caveats** — colour by residual (positive = over-represented) to
  highlight chi-squared-style departures from independence.

## 5. Code Snippets (concise, attributed)

These are paraphrased Python translations of the R/`ggplot2` examples
in Prof. Chang's slides plus what we will use in the CPBL notebook.

```python
# 5.1  Histogram + KDE overlay
import seaborn as sns
sns.histplot(df, x='innings_pitched', stat='density', bins=30,
             color='steelblue')
sns.kdeplot(df, x='innings_pitched', color='black', lw=2)
plt.xlabel('Innings pitched (single game)')
```

```python
# 5.2  Reordered, flipped boxplot  (R original: reorder(class, hwy, FUN=median))
order = df.groupby('team')['whip_like'].median().sort_values().index
sns.boxplot(data=df, y='team', x='whip_like', order=order, notch=True)
plt.xlabel('WHIP-like (BB + H per IP)')
```

```python
# 5.3  High-volume scatter -> hexbin  (R original: geom_hex + geom_smooth)
fig, ax = plt.subplots(figsize=(6,5))
hb = ax.hexbin(df['AB'], df['H'], gridsize=40, cmap='viridis',
               mincnt=1)
plt.colorbar(hb, label='# games')
sns.regplot(data=df, x='AB', y='H', lowess=True,
            scatter=False, line_kws={'color':'white'})
```

```python
# 5.4  Faceted small-multiples by team
g = sns.FacetGrid(df, col='team', col_wrap=5, sharex=True, sharey=True,
                  height=2.4)
g.map_dataframe(sns.scatterplot, 'innings_pitched', 'whip_like',
                alpha=0.4)
g.set_titles('{col_name}')
```

```python
# 5.5  Correlation matrix on Wang's features
import numpy as np
wang = ['run_per_hit','innings_pitched','H','scored_first',
        'whip_like','hr_allowed','hits_allowed','AB',
        'middle_runs','late_runs']
corr = df[wang].corr(method='spearman')
mask = np.triu(np.ones_like(corr, dtype=bool), k=1)
sns.heatmap(corr, mask=mask, vmin=-1, vmax=1, cmap='coolwarm',
            annot=True, fmt='.2f', square=True)
```

```python
# 5.6  PCA 2-D projection (colour = season)
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
X = StandardScaler().fit_transform(df[wang])
pcs = PCA(n_components=2).fit_transform(X)
sns.scatterplot(x=pcs[:,0], y=pcs[:,1], hue=df['season'],
                palette='tab10', alpha=0.6)
```

```python
# 5.7  UMAP projection coloured by k-means cluster
import umap
from sklearn.cluster import KMeans
emb = umap.UMAP(n_neighbors=15, min_dist=0.1,
                random_state=0).fit_transform(X)
labels = KMeans(n_clusters=4, n_init=20, random_state=0).fit_predict(X)
sns.scatterplot(x=emb[:,0], y=emb[:,1], hue=labels,
                palette='tab10', alpha=0.7)
```

```python
# 5.8  Dendrogram + cluster heatmap  (Ward linkage)
from scipy.cluster.hierarchy import linkage
g = sns.clustermap(df.groupby('team')[wang].mean(),
                   method='ward', standard_scale=1,
                   cmap='coolwarm', figsize=(8,6))
```

```python
# 5.9  Parallel coordinates of cluster centroids
import plotly.express as px
centroids = (df.assign(cluster=labels)
               .groupby('cluster')[wang].mean()
               .reset_index())
fig = px.parallel_coordinates(centroids, color='cluster',
                              dimensions=wang,
                              color_continuous_scale=px.colors.diverging.Tealrose)
fig.show()
```

```python
# 5.10  Radar / spider chart of two teams over Wang's features
import plotly.graph_objects as go
def to_long(team):
    s = df[df['team']==team][wang].mean()
    return go.Scatterpolar(r=s.values, theta=wang, fill='toself',
                           name=team)
fig = go.Figure(data=[to_long('Rakuten'), to_long('Uni-Lions')])
fig.update_layout(polar=dict(radialaxis=dict(visible=True)))
```

```python
# 5.11  Ridge-plot: monthly distribution of hits_allowed
import joypy
joypy.joyplot(df, by='month', column='hits_allowed',
              colormap=plt.cm.viridis, overlap=1.2)
```

```python
# 5.12  Calendar heatmap of total runs per game-day
import calplot
series = df.groupby('date')['runs'].sum()
calplot.calplot(series, cmap='YlGnBu',
                suptitle='Daily runs, 2023–2024 CPBL')
```

```python
# 5.13  Scree + cumulative variance  (PCA diagnostic)
pca = PCA().fit(X)
var = pca.explained_variance_ratio_
fig, ax = plt.subplots(1, 2, figsize=(10,4))
ax[0].bar(range(1, len(var)+1), var); ax[0].set_title('Scree')
ax[1].plot(range(1, len(var)+1), var.cumsum(), '-o')
ax[1].axhline(0.8, ls='--', c='grey'); ax[1].set_title('Cumulative')
```

```python
# 5.14  Silhouette diagnostic for KMeans cluster count
from sklearn.metrics import silhouette_score
ks = range(2, 10)
scores = [silhouette_score(X, KMeans(n_clusters=k, n_init=20,
                                     random_state=0).fit_predict(X))
          for k in ks]
plt.plot(list(ks), scores, '-o'); plt.xlabel('k'); plt.ylabel('silhouette')
```

```python
# 5.15  Bar of means with error bars  (early vs middle vs late runs)
runs_long = df.melt(id_vars='team',
                    value_vars=['scored_first','middle_runs','late_runs'],
                    var_name='phase', value_name='runs')
sns.barplot(data=runs_long, x='team', y='runs', hue='phase',
            errorbar='ci')
plt.xticks(rotation=45, ha='right')
```

## 6. Examples shown in lecture

- **Pie chart of countries** (US, UK, Australia, Germany, France) —
  used as a *negative example*: never go above 5 slices.
- **Telephone bill vs years lived in Chicago** — illustrates a
  regular boxplot, a variable-width boxplot, and a notched
  variable-width boxplot.
- **`mpg` dataset (`class` vs `hwy`)** — three boxplots in
  succession showing the "messy → reordered → flipped" refinement
  cycle.
- **Volcano plot** — log2(fold-change) on x, −log10(q-value) on y;
  classical genomics chart but transferable any time you have an
  effect size and a significance.
- **`diamonds`: carat × price** — progressively fixed overplotting
  with alpha (1/100), then `geom_bin2d`, then box-by-`cut_width`.
- **`custdata`: age × income** — line plot fails (`geom_line` on
  unordered data), scatter + lowess works, hexbin works for the
  large-n case, jitter+smoother for boolean `health.ins`.
- **`custdata`: `marital.stat` × `health.ins`** — same data shown
  four ways: stacked, dodged, filled, filled+rug.
- **`custdata2`: `housing.type` × `marital.stat`** — bar chart
  without facets vs *with* `facet_wrap(~housing.type,
  scales="free_y")`.
- **`mtcars`** — histograms, scatter (with linear-model overlay),
  scatter coloured by `cyl`, line plots of group means; the
  `ggvis`/`shiny` examples plug sliders into bandwidth, kernel,
  point-size and opacity.
- **K & R "Hello, world!"** — used in the Shiny demo. Tangentially
  reminds us that *minimal* working examples teach better than
  elaborate ones.

## 7. Pitfalls

1. **Chart-junk** — 3-D bars, decorative shadows, gradient
   backgrounds. Inks the chart but encodes no data.
2. **Truncated y-axis on bar charts** — exaggerates differences.
   Always start at zero for bars; non-zero baselines are okay for
   line charts when the variation is what matters.
3. **Pie charts** — only acceptable for ≤ 5 slices; otherwise use a
   horizontal bar chart sorted by value.
4. **Overplotting** — a scatter with 50 k points is a black blob.
   Solutions: alpha, jitter, hexbin, 2-D histogram, density contour,
   sampling, facets.
5. **Rainbow / jet palettes** — they imply false ordering and confuse
   colour-blind readers. Always use `viridis` family for sequential,
   `coolwarm` family for diverging.
6. **Asymmetric diverging colour maps** — when the data is centred on
   zero (correlation, z-score) but `vmin`/`vmax` are not symmetric,
   the eye reads a false sign.
7. **Too many colours** — eight hues is the upper limit for
   simultaneous discrimination; beyond that, facet.
8. **Misleading aspect ratios** — line plots whose y-range is
   stretched/compressed to dramatise or hide trends.
9. **Double y-axes** — superficially clever, almost always
   misleading; prefer two stacked panels with a shared x-axis.
10. **t-SNE / UMAP cluster distances** — they are *not* metric. Don't
    say "team A is far from team B in UMAP space" as evidence.
11. **Dendrogram cut without a heatmap** — readers cannot tell what a
    cluster means without seeing feature means. Always pair them
    (e.g. `sns.clustermap`).
12. **Tables with vertical rules / double rules / misaligned numbers
    / no units** — explicit advice from the lecture's "How to make a
    good table" section.
13. **Plotting all points on top of all points** without sorting; use
    `zorder` or sort the most important group last so it stays
    visible.
14. **Legends positioned over data** — move outside or use direct
    line labels.
15. **Mixing two correlation methods (Pearson vs Spearman) without
    saying so** — be explicit in the caption.

## 8. Cross-references

- Topic 05-1 **PCA / SVD** — 2-D PCA scatter and biplots reuse the
  scree-plot and projection charts here.
- Topic 05-2 **Feature engineering / explanation** — Wang's ten
  features come from there; this topic shows how to *visualise* them.
- Topic 02 / 03 **Pre-processing & descriptive statistics** — every
  univariate plot here is the visual half of those numeric summaries.
- Topic 04 **Clustering** — the dendrogram, silhouette, parallel
  coordinates and UMAP projection here all visualise *cluster*
  output.
- External references from the lecture:
  - Hadley Wickham, *ggplot2: Elegant Graphics for Data Analysis (3e)*
    — https://ggplot2-book.org/
  - Winston Chang, *R Graphics Cookbook* —
    http://www.cookbook-r.com/Graphs/
  - Antony Unwin, *Graphical Data Analysis with R*.
  - Quick-R — http://www.statmethods.net/
  - Shiny gallery — http://shiny.rstudio.com/gallery
  - Jia-Bin Huang's table-typography thread (cited explicitly in the
    slide: https://twitter.com/jbhuang0604/status/1626372613441290240).

## 9. Relevance to CPBL — concrete chart-by-chart plan

The CPBL notebook (rebas.tw 2023 + 2024) will be organised as
**descriptive stats → EDA → unsupervised feature discovery**. Each
sub-section gets a small battery of charts. Wang's top features are
abbreviated as W = {`run_per_hit`, `innings_pitched`, `H`,
`scored_first`, `whip_like`, `hr_allowed`, `hits_allowed`, `AB`,
`middle_runs`, `late_runs`}.

1. **Distribution of each Wang feature** — a 2 × 5 small-multiples
   panel of histograms (one per feature), with a KDE overlay and a
   vertical line at the league median. Reveals skew (`hr_allowed` is
   heavily right-skewed; `innings_pitched` is multi-modal because of
   starters vs relievers).
2. **Boxplot of `whip_like` and `run_per_hit` by team, sorted by
   median** — applies the lecture's "reorder + flip" trick directly.
   Use notched boxes (sample sizes are around 120 games × 2
   seasons), with team colour palette.
3. **Violin split by season (2023 vs 2024) for `hits_allowed` and
   `hr_allowed`** — a single violin per team with a left half from
   2023 and a right half from 2024, making YoY change immediately
   readable.
4. **2-D hexbin of `AB` vs `H` with overlaid LOWESS** — direct
   port of the R `geom_hex + geom_smooth` example. Annotate the
   league-average batting average as a reference line `H = 0.265 ×
   AB`.
5. **Correlation heatmap (Spearman) of all ten Wang features** —
   mask the upper triangle, diverging palette, annotate cells.
   Expected take-away: `whip_like` correlates with `hits_allowed`
   and `hr_allowed`; `scored_first` correlates with `middle_runs` +
   `late_runs`.
6. **Pair plot of a *reduced* Wang subset** (`run_per_hit`,
   `whip_like`, `innings_pitched`, `H`) coloured by `won_game`
   (boolean) — small enough (4×4 = 16 panels) to be readable; one
   slide.
7. **Stacked / dodged / filled bar chart of `scored_first` × `won
   game` per team** — mirrors the lecture's three `marital.stat ×
   health.ins` charts. Filled (proportional) is the headline view:
   "what share of first-scoring games does each team win?".
8. **Calendar heatmap of total runs per game-day across both
   seasons** — exposes weekday patterns (weekend doubleheaders),
   blackout windows (typhoon / All-Star break), and the September
   playoff push.
9. **PCA scree + 2-D PCA scatter of game-level Wang vectors,
   coloured by team and season** — pair with a *biplot* arrow
   overlay so the reader sees which feature drives PC1 (likely
   `whip_like`/`hits_allowed`) and PC2 (likely `middle_runs` vs
   `late_runs`).
10. **UMAP 2-D projection of standardised Wang vectors with
    k-means clusters overlaid in colour** — the headline
    unsupervised plot. Add a small panel of *cluster-mean radar
    charts* on the side so each cluster is interpretable
    ("front-running offense", "late-rally bullpen", etc.).
11. **`sns.clustermap` (Ward linkage) of team-by-feature mean
    matrix** — collapses 12 teams × 10 features into a single
    glanceable chart with two dendrograms; the team dendrogram
    surfaces "playoff-tier" vs "rebuilding-tier" groupings.
12. **Parallel-coordinates plot of cluster centroids over Wang
    features, plus an animated season slider (`plotly`)** — fulfils
    the "heavy visualization" mandate and lets the reader see
    whether a cluster's profile shifted from 2023 to 2024.

For each of the twelve charts above we will (a) state the question
the chart answers, (b) state the encoding (axes / colour / facet),
(c) supply ≤ 30 lines of paraphrased code from §5, and (d) write a
one-paragraph caption interpreting the result. The notebook closes
with a "lessons in unsupervised CPBL exploration" recap that ties
back to Wang's feature list.
