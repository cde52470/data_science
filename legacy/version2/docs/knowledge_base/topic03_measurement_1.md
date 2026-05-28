# Topic 03 - Measurement (Part 1): How to Evaluate Output?

## 1. Topic Summary (one paragraph)

This lecture (Jia-Ming Chang, NCCU CS) introduces **model evaluation** as the central activity that links a chosen modeling technique back to the original business goal. It walks through evaluation strategies family by family: classification (confusion matrix, accuracy, precision, recall, F1, sensitivity/specificity, PPV/NPV, Type I/II error, multi-class micro/macro averaging), scoring/regression (residuals, MAE, MSE, RMSE, RSS, TSS, R^2, Pearson r), probability (double-density plots, ROC/AUC, log-likelihood, deviance, pseudo R^2, AIC), ranking (Spearman), and clustering (internal metrics like Silhouette and Calinski-Harabasz, plus external metrics like Normalized Mutual Information). Worked examples include a German Credit decision tree, a Spambase logistic regression, an HIV diagnostic test illustrating how prevalence skews PPV, and k-means on uniform random data. The key recurring message is: **accuracy alone is misleading for imbalanced classes; pick the metric that matches your business asymmetry (e.g., spam, COVID, fraud), and remember that clustering quality must be assessed differently from supervised tasks.**

## 2. Outline / Section Structure (hierarchical bullets)

- Recap from previous week (R language essentials)
- Today's reading sources
  - Practical Data Science with R, Ch. 5 - Choosing and evaluating models
  - An Introduction to Statistical Learning, Ch. 2 - Statistical Learning
- Schematic model construction and evaluation
  - Three task families: classification, probability, scoring
  - Model critique questions (accuracy, generalization, sanity in domain)
- Outline of evaluation by model type
  - Accuracy of the model
  - Inference vs. Prediction (e.g., advertising data: which media drives sales)
  - Regression vs. Classification (quantitative vs. qualitative)
- Evaluating classification models
  - Multicategory vs. two-category classification (one-vs-rest, mlogit)
  - Confusion matrix (decision tree on German Credit Data)
  - Definitions: TP, FP, TN, FN
  - Metrics: Accuracy, Precision, Recall, FPR
  - Spam case: logistic regression on Spambase
    - Building model with `glm` + binomial logit link
    - Threshold trade-offs (>0.5, >0.9, >0.1)
    - F1 score; Akismet filter comparison
  - Precision vs. Recall trade-off
  - Why accuracy is wrong for unbalanced classes (null model paradox)
  - Sensitivity / Specificity
  - Type I / Type II errors mapped to spam
  - COVID-19 screening case study
    - Prevalence, sensitivity, specificity (prevalence-independent)
    - PPV, NPV (prevalence-dependent)
    - HIV example at 50% vs 1% prevalence
  - Multi-class classification
    - sklearn.metrics.classification_report
    - Converting confusion matrix to per-class binary CMs
    - Specificity inflation issue with 10 classes
    - Micro vs. macro averaging
- Evaluating scoring models
  - Residuals (residual.R)
  - Absolute error, MAE, relative absolute error
  - MSE, RMSE
  - RSS, TSS, R^2 (coefficient of determination)
  - R^2 interpretation (0 to 1)
  - Pearson correlation r (shift- and scale-invariant)
  - R^2 = correlation^2 (only under squared-error loss, optimal linear models)
- Evaluating probability models
  - Double density plot of predicted probabilities by class
  - ROC curve and AUC (using ROCR)
  - Log-likelihood (connection to binary cross-entropy)
  - Null model log-likelihood
  - Deviance = -2 * (logLik - S)
  - Pseudo R^2 = 1 - deviance(model)/deviance(null)
  - AIC = deviance + 2 * #parameters
- Evaluating ranking models
  - Spearman's rank correlation
- Evaluating clustering models
  - k-means example on uniform random data (clusterModel.R)
  - "Hair" clusters (too small) vs. "waste" clusters (too large)
  - Internal vs. external validation
  - Internal: intra-cluster vs inter-cluster distance, Silhouette, Calinski-Harabasz
  - External: Normalized Mutual Information (NMI), label permutation invariance

## 3. Key Concepts (paraphrased)

- **Model evaluation defined**: quantifying performance in a way that fits both the original business objective and the model family chosen. Choosing the wrong metric defeats the modeling effort.
- **Inference vs. prediction**: inference asks which predictors matter and how (e.g., which advertising media drive sales); prediction focuses on accurate output for new inputs. The metric you should pick differs.
- **Regression vs. classification**: quantitative targets get scoring metrics; qualitative targets get classification metrics. Mixing them up (e.g., using accuracy on a continuous target) loses information.
- **Confusion matrix**: a square table cross-tabulating actual vs predicted class. Rows = actual, columns = predicted. Diagonal entries are correct predictions; all derived metrics ultimately come from this table.
- **Precision**: among items the classifier labels positive, the fraction that are truly positive. A measure of *confirmation* (when it says yes, is it right?).
- **Recall (sensitivity / true positive rate)**: among truly positive items, the fraction detected. A measure of *utility* (does it find what is out there?).
- **Specificity (true negative rate)**: among truly negative items, the fraction correctly labeled negative. Specificity = 1 - alpha; sensitivity = 1 - beta.
- **Accuracy is unsafe for imbalanced data**: when the positive event is rare, a model that always predicts "negative" looks highly accurate but is useless.
- **Type I vs Type II error**: false alarm (Type I, alpha) vs missed detection (Type II, beta). The business asymmetry dictates which to minimize.
- **Prevalence, PPV, NPV**: PPV and NPV depend on prevalence; sensitivity and specificity do not. Low prevalence makes PPV plunge even when sensitivity and specificity look excellent.
- **F1 score**: harmonic mean of precision and recall, used when you need a single number balancing both.
- **Micro vs macro averaging** (multi-class): micro pools all TP/FP/FN counts across classes (favors big classes); macro averages metrics by class (treats classes equally).
- **Residual**: y_actual - y_predicted. Foundation of all regression metrics.
- **MAE, MSE, RMSE**: mean absolute, mean squared, and root mean squared errors. RMSE is in the same units as y.
- **R^2 (coefficient of determination)**: 1 - RSS/TSS. Fraction of variance explained. 1 is perfect; 0 means no improvement over the mean.
- **Pearson correlation**: invariant to shift and scale, so a high correlation does not guarantee a good calibrated regression model.
- **Double density plot**: overlay predicted-score densities for positive and negative classes; visually inspect class separability.
- **ROC curve**: TPR vs FPR across thresholds. AUC = 1.0 perfect; 0.5 random.
- **Log-likelihood**: log of product of predicted probabilities for actual outcomes. Connected to binary cross-entropy. 0 is perfect, more negative is worse.
- **Deviance**: -2 * (logLik - S). Lower is better. Comparable only on the same dataset.
- **Pseudo R^2**: 1 - deviance(model)/deviance(null model). Comparable across datasets, normalized.
- **AIC**: deviance + 2 * (number of parameters). Penalizes complexity. Smaller is better, even across model structures.
- **Spearman's rank correlation**: correlation on ranks, used to evaluate ranking models.
- **Clustering internal metrics**: intra-cluster distance should be small; inter-cluster distance should be large. Silhouette in [-1, 1]; 1 = well clustered, 0 = overlap, -1 = misassigned.
- **Calinski-Harabasz index**: ratio of between-cluster to within-cluster dispersion; higher is better.
- **External clustering metrics**: compare cluster assignments to known labels. NMI is permutation-invariant on label values.
- **Hair clusters and waste clusters**: pathological clustering outputs - one with too few points, one absorbing too many - that signal the wrong number of clusters.

## 4. Methods & Algorithms

Per method: Name | When used | Math/formula | Python implementation | Caveats

- **Confusion Matrix** | Binary or multi-class classification | Rows = truth, columns = prediction; cells = TP/FP/FN/TN counts | `sklearn.metrics.confusion_matrix(y_true, y_pred)` | Always inspect before reading aggregate metrics; row/column ordering matters; for multi-class, derive per-class binary CMs.
- **Accuracy** | Balanced classes | `(TP + TN) / (TP + TN + FP + FN)` | `sklearn.metrics.accuracy_score` | Misleading under class imbalance; null model can have high accuracy.
- **Precision** | Cost of false alarms is high (e.g., spam, biopsy) | `TP / (TP + FP)` | `sklearn.metrics.precision_score` | Ignores misses (FN); pair with recall.
- **Recall / Sensitivity / TPR** | Cost of missing positives is high (e.g., cancer screen) | `TP / (TP + FN)` | `sklearn.metrics.recall_score` | Can be inflated by predicting positive often; pair with precision/specificity.
- **Specificity / TNR** | Need to confirm negatives are negative | `TN / (TN + FP)` | derive from CM or `1 - FPR` | Inflates in multi-class with many classes (most classes are "negative" for any given target).
- **False Positive Rate** | Used in ROC and Type I analysis | `FP / (FP + TN)` | derive from CM | Complement of specificity.
- **F1 Score** | Single number summary with imbalance | `2 * P * R / (P + R)` | `sklearn.metrics.f1_score` | Hides whether precision or recall is the weak side; consider F-beta.
- **PPV / NPV** | Diagnostic interpretation given a prevalence | PPV = TP/(TP+FP); NPV = TN/(TN+FN) | derive from CM | Vary strongly with prevalence (unlike sens/spec); always disclose prevalence.
- **Micro / Macro averaging** | Multi-class scoring | Micro pools TP/FP/FN globally; Macro averages metric across classes | `sklearn.metrics.classification_report` (gives both) | Macro can be dragged by tiny classes with noise; micro masks them.
- **MAE / Relative Absolute Error** | Regression with comparable units | `mean(|y - y_hat|)` ; rel = sum|y-yhat|/sum|y| | `sklearn.metrics.mean_absolute_error` | "Picking the middle" effect on heavy-tailed targets.
- **MSE / RMSE** | Regression with squared-error loss | `mean((y - y_hat)^2)`; RMSE = sqrt(MSE) | `sklearn.metrics.mean_squared_error(..., squared=False)` for RMSE | RMSE is heavily influenced by outliers due to squaring.
- **R^2 (coefficient of determination)** | Linear regression goodness-of-fit | `1 - RSS/TSS` where RSS = sum((y-yhat)^2), TSS = sum((y-mean(y))^2) | `sklearn.metrics.r2_score` | For linear models under squared loss, R^2 = corr(y, yhat)^2; not so for general models. Can be negative for terrible models.
- **Pearson r** | Linear association | `cov(x,y)/(sd(x)*sd(y))` | `numpy.corrcoef`, `scipy.stats.pearsonr` | Shift- and scale-invariant: high r does not mean small RMSE.
- **Double-density plot** | Probability model diagnostic | Kernel density estimate of predicted score, separately for each class | `seaborn.kdeplot(data=df, x='score', hue='label')` | Visual only; complements ROC.
- **ROC curve / AUC** | Probability/ranking classifier across all thresholds | Plot TPR vs FPR; AUC = area under the curve | `sklearn.metrics.roc_curve`, `roc_auc_score` | AUC = 0.5 random, 1.0 perfect; not directly tied to a specific operating threshold; Hand (2009) argues for alternatives.
- **Log-likelihood / Binary Cross-Entropy** | Probability calibration | `sum(y*log(p) + (1-y)*log(1-p))`; 0 = perfect | `sklearn.metrics.log_loss` | Penalizes confident wrong predictions extremely; can blow up if p in {0, 1}.
- **Deviance** | Compare nested models on same data | `-2 * (logLik(model) - S)` | derive from log_loss * 2 * n in most cases | Comparable only on identical datasets; not normalized.
- **Pseudo R^2** | Logistic regression fit quality | `1 - deviance(model) / deviance(null)` | derive manually | Comparable across datasets; "70% rule" can be borrowed from linear R^2.
- **AIC** | Model selection with different complexity | `deviance + 2 * k` where k = parameters | `statsmodels` results object `.aic` | Punishes complexity; smaller better; assumes large n.
- **Spearman rank correlation** | Ranking model evaluation | Pearson r computed on ranks | `scipy.stats.spearmanr` | Captures monotonic association; cannot tell calibration.
- **k-means clustering (for evaluation example)** | Unsupervised baseline | Minimizes within-cluster sum of squares | `sklearn.cluster.KMeans` | k must be chosen; sensitive to scale, initialization, and outliers.
- **Silhouette score** | Internal cluster validation | `s_i = (b_i - a_i) / max(a_i, b_i)`; mean over i; range [-1, 1] | `sklearn.metrics.silhouette_score` | Requires distance matrix; O(n^2) memory at large n.
- **Calinski-Harabasz index** | Internal cluster validation, fast | Ratio of between- to within-cluster dispersion | `sklearn.metrics.calinski_harabasz_score` | Tends to prefer larger k; convex-cluster bias.
- **Normalized Mutual Information (NMI)** | External cluster validation | `NMI = I(Y;C)/normalizer(H(Y), H(C))` | `sklearn.metrics.normalized_mutual_info_score` | Permutation invariant on labels; 1 = perfect, 0 = independent; compares across different cluster counts.

## 5. Code Snippets (short, attributed)

R, German Credit decision tree (Practical Data Science with R, Ch. 5):

```r
library('rpart')
load('GCDData.RData')
model <- rpart(Good.Loan ~ Duration.in.month + Installment.rate.in.percentage.of.disposable.income
               + Credit.amount + Other.installment.plans,
               data=d, control=rpart.control(maxdepth=4), method="class")
resultframe <- data.frame(Good.Loan=creditdata$Good.Loan,
                          pred=predict(model, type="class"))
rtab <- table(resultframe)
```

R, Spambase logistic regression (spamExam.R):

```r
spamD <- read.table('spamD.tsv', header=TRUE, sep='\t')
spamTrain <- subset(spamD, spamD$rgroup >= 10)
spamTest  <- subset(spamD, spamD$rgroup < 10)
spamVars  <- setdiff(colnames(spamD), list('rgroup','spam'))
spamFormula <- as.formula(paste('spam=="spam"',
                                 paste(spamVars, collapse=' + '),
                                 sep=' ~ '))
spamModel <- glm(spamFormula, family=binomial(link='logit'), data=spamTrain)
cM <- table(truth=spamTest$spam, prediction=spamTest$pred > 0.5)
```

R, threshold experiments (illustrates precision/recall trade-off):

```r
table(truth=spamTest$spam, prediction=spamTest$pred > 0.9)
table(truth=spamTest$spam, prediction=spamTest$pred > 0.5)
table(truth=spamTest$spam, prediction=spamTest$pred > 0.1)
```

R, regression residuals (residual.R):

```r
d <- data.frame(y=(1:10)^2, x=1:10)
model <- lm(y ~ x, data=d)
d$prediction <- predict(model, newdata=d)
sum(abs(d$prediction - d$y))                       # absolute error
sum(abs(d$prediction - d$y)) / length(d$y)         # MAE
sum(abs(d$prediction - d$y)) / sum(abs(d$y))       # relative AE
```

R, ROC and AUC with ROCR:

```r
library('ROCR')
eval <- prediction(spamTest$pred, spamTest$spam)
plot(performance(eval, "tpr", "fpr"))
print(attributes(performance(eval, 'auc'))$y.values[[1]])
```

R, log-likelihood (model vs null):

```r
sum(ifelse(spamTest$spam=='spam',
           log(spamTest$pred),
           log(1 - spamTest$pred)))

pNull <- sum(ifelse(spamTest$spam=='spam', 1, 0)) / nrow(spamTest)
sum(ifelse(spamTest$spam=='spam', 1, 0)) * log(pNull) +
sum(ifelse(spamTest$spam=='spam', 0, 1)) * log(1 - pNull)
```

R, k-means clustering and intra/inter distance:

```r
set.seed(32297)
d   <- data.frame(x=runif(100), y=runif(100))
clus <- kmeans(d, centers=5)
d$cluster <- clus$cluster
table(d$cluster)
```

R, NMI usage (aricode):

```r
library('aricode')
NMI(c(0,0,1,1), c(0,0,1,1))   # 1, identical
NMI(c(0,0,1,1), c(1,1,0,0))   # 1, permutation invariant
NMI(c(0,0,1,1), c(1,0,0,1))   # 0, no mutual information
```

Python equivalents the project may use:

```python
from sklearn.metrics import (confusion_matrix, classification_report,
                             roc_curve, roc_auc_score, log_loss,
                             mean_absolute_error, mean_squared_error, r2_score,
                             silhouette_score, calinski_harabasz_score,
                             normalized_mutual_info_score)
```

## 6. Notable Examples or Datasets

- **German Credit Data (GCDData)**: predicting good vs bad loans using a decision tree (`rpart`). Used to build the very first confusion matrix in the lecture.
- **Spambase (UCI / WinVector mirror)**: logistic regression spam classifier. Path `https://raw.githubusercontent.com/WinVector/zmPDSwR/master/Spambase/spamD.tsv`. Demonstrates threshold tuning, F1, ROC, log-likelihood, deviance, pseudo R^2.
- **Akismet-style spam filter (illustrative table)**: shows the contrast of a high-precision, high-recall industrial baseline against a textbook glm.
- **Advertising dataset (ISLR)**: used to motivate inference vs prediction questions (which media boost sales, by how much).
- **HIV diagnostic test thought experiment**: same sensitivity (90%) and specificity (95%) but PPV swings from 94.7% at 50% prevalence to 15.4% at 1% prevalence. Punchline: PPV/NPV depend on prevalence; sensitivity/specificity do not.
- **COVID-19 screening (April 2020 snapshot)**: prevalence-adjusted PPV interpretation; the 48.65% PPV example, where more than half of "antibody-positive" results may be false positives.
- **Synthetic 100-point uniform plane data**: k-means with k=5 to illustrate hair vs waste clusters and visualize intra/inter-cluster distance computations.
- **Toy R^2 example**: `(1:10)^2` regressed on `1:10` shows residuals when fit is imperfect.
- **NMI toy vectors**: `c(0,0,1,1)` vs permutations, illustrating NMI's label-permutation invariance.

## 7. Pitfalls / Common Mistakes

- Reporting accuracy on highly imbalanced data; null model trick can beat real models on accuracy alone.
- Choosing 0.5 as the classification threshold by default without business justification; sliding it changes the precision/recall trade-off entirely.
- Confusing precision and recall, or treating F1 as a universal "best" metric. F1 hides which side is weak.
- Computing PPV/NPV from a screening sample with a different prevalence than the production environment.
- For multi-class metrics, forgetting that specificity inflates with many classes; reporting unweighted macro averages on highly imbalanced multi-class problems.
- Treating R^2 as if it transfers across models with different loss functions; the identity R^2 = corr^2 holds only for the optimal linear-regression / squared-error case.
- Reporting Pearson correlation and inferring calibration - correlation is invariant to scale and shift.
- Comparing deviances computed on different datasets (deviance is unnormalized).
- Comparing AIC across models fit on different data or with different likelihoods.
- Treating clustering quality the same way as supervised quality; clustering requires either an internal metric (silhouette, Calinski-Harabasz) or external labels (NMI).
- Picking k for k-means by eye and getting "hair clusters" (tiny isolated clusters) or "waste clusters" (one cluster absorbing most points).
- Forgetting that sensitivity and specificity each individually collapse for the null model that always predicts one class.
- Confusing Type I (false alarm, alpha) and Type II (miss, beta) errors when discussing test design.

## 8. Cross-references

- Practical Data Science with R, Nina Zumel and John Mount, Manning 2019, Ch. 5 - Choosing and evaluating models.
- An Introduction to Statistical Learning (James, Witten, Hastie, Tibshirani), Springer 2013, Ch. 2 - Statistical Learning.
- R for Data Science (Creative Commons NC-ND 3.0) - cited for figures.
- Hand, D.J. (2009), Measuring classifier performance: a coherent alternative to the area under the ROC curve, Mach. Learn. 77, 103-123.
- `topic08_unsupervised.pptx` for detail on Silhouette and Calinski-Harabasz (internal clustering metrics).
- R packages mentioned: `rpart`, `glm`/`mlogit`, `ROCR`, `ggplot2`, `aricode`, `reshape2`, `grDevices`.
- Python equivalents the downstream notebook will likely use: `sklearn.metrics`, `sklearn.cluster.KMeans`, `scipy.stats`, `pandas.crosstab`, `seaborn.kdeplot`.
- Earlier "Recap" pointers: R primary data types, `<-` vs `=`, `&` vs `&&`, `read_table`, `summary`.

## 9. Relevance to CPBL Descriptive Statistics & EDA Stage (max 5 bullets)

- For the **EDA stage**, confusion-matrix-style cross-tabs translate naturally to CPBL: `pandas.crosstab(home_team_won, scored_first)` to inspect whether scoring first is correlated with winning. Treat scored_first as a binary "predictor" and win/loss as the target to do quick sanity checks before any model.
- **R^2, Pearson r, and Spearman r** are exactly the tools to rank top consensus features (run_per_hit, innings_pitched, H, whip_like, hr_allowed, hits_allowed, AB, middle_runs, late_runs) by how strongly they associate with run differential or win flag; report both because some baseball stats are monotonic but non-linear (e.g., WHIP-like ratios).
- The **prevalence / class-imbalance warning** matters: in 2023-2024 CPBL, the rate of "scored_first" or "won blowout" is not 50/50 over all team-games; treating accuracy as a quality measure in the supervised baseline that Wang built can mislead - check sensitivity, specificity, and PPV instead, and quote the base rate explicitly.
- For the unsupervised feature-discovery step (clustering / PCA), use **internal metrics (silhouette, Calinski-Harabasz)** to pick k for team-game clusters; if rule-based labels exist for "good pitching game" or "blowout win", use **NMI** as an external check. NMI is robust to label permutations, so it works even if your cluster IDs are arbitrary.
- The **scoring metric trio (MAE, RMSE, R^2)** is the right vocabulary for describing the predictability of run totals or run differentials in the descriptive statistics section: report all three, and remember RMSE is sensitive to blowouts (heavy-tailed CPBL game outcomes).
