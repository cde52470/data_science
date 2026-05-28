# Scripts/build/

如何從零（或從上游 base notebook）重建 `Scripts/cpbl_unsupervised_feature_discovery.ipynb`。

> 一般情境下不需要這一層；直接讀 `Scripts/cpbl_unsupervised_feature_discovery.ipynb`
> 或執行 `./master.sh` 重跑即可。本目錄保留下來做為 build pipeline 的審計紀錄。

## 檔案

| 檔名 | 角色 |
|---|---|
| `modify_notebook.py` | 從上游「optimized base notebook」（118 cells）注入三項改動：Wang merge 對照（2.7a）、pre-game lag features + gate（2.7b / 2.9）、六方法 K 共識取代單一 silhouette（5.7）、ANOVA F + MI（5.18a）、notched boxplot（5.17 patch）、cmean 涵蓋兩個 feature set（5.15 patch）、6.1 overlap 用 FEATURES_FOR_UNSUP |
| `inject_explanations.py` | 在已執行的 notebook 上逐 cell 注入「結果解讀」中文評註、加上每個 stage 的小結、最後附上 Workflow 總結與檔案樹 |

## 完整 build pipeline

```bash
# 1. 取得上游 base notebook（118 cells，本 repo 沒有 commit；參見下方說明）
BASE=/path/to/cpbl_unsupervised_feature_discovery_optimized.ipynb

# 2. 跑 modify_notebook.py 將三項改動 + 多項 patch 注入
#    輸入：BASE；輸出：/tmp/cpbl_unsupervised_feature_discovery.ipynb（126 cells）
python3 Scripts/build/modify_notebook.py

# 3. 用 nbconvert 執行
jupyter nbconvert --to notebook --execute \
  /tmp/cpbl_unsupervised_feature_discovery.ipynb \
  --output /tmp/cpbl_unsupervised_feature_discovery.executed.ipynb \
  --ExecutePreprocessor.timeout=1200

# 4. 跑 inject_explanations.py 加上每 cell 解讀 + 每 stage 小結 + 最終總結
#    輸入：/tmp/cpbl_unsupervised_feature_discovery.executed.ipynb
#    輸出：/tmp/cpbl_unsupervised_feature_discovery.annotated.ipynb（193 cells）
python3 Scripts/build/inject_explanations.py

# 5. 取代 Scripts/ 下的 notebook
cp /tmp/cpbl_unsupervised_feature_discovery.annotated.ipynb \
   Scripts/cpbl_unsupervised_feature_discovery.ipynb
```

> 上游 base notebook 的取得：第一版來自團隊成員上傳的「optimized」版本（含 rebas
> direct download + Chinese stage titles + Stage 7 CSV export 等已優化的結構）。
> 若沒有那份 base，最接近的替代是 `Scripts/cpbl_unsupervised_feature_discovery.ipynb`
> 本身——但這已是「modify + execute + inject 都做完」的最終版，不適合再餵給
> `modify_notebook.py`，所以這條 build pipeline 平常不會跑。

## 為什麼還留著這些腳本？

- 之後若想 reproduce 同一套方法到別的資料集（例如 2025 球季或不同聯盟），
  `modify_notebook.py` 與 `inject_explanations.py` 的結構可以直接套用——
  只需改 `RELEASE_SOURCES`、`PREGAME_LAG_BASE` 等少數變數。
- 也作為「這份 notebook 不是手 hand-coded、而是兩段自動化 pipeline 的產物」的明證，
  有利於審計與後續維護。
