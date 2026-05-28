# Scripts/build/

如何從已執行的 `Scripts/converge_analysis.ipynb` 重建 `Results/notebook_executed.html`。

> 一般情境下不需要這一層；直接讀 `Results/notebook_executed.html`，或執行
> 專案根目錄的 `./master.sh` 重跑即可。本目錄保留下來作 build pipeline
> 的審計紀錄。

## 檔案

| 檔名 | 角色 |
|---|---|
| `build_converge_report.py` | 把已執行的 notebook 轉成 styled HTML report（**code-free**、sidebar TOC、三段式呈現） |
| `report_assets/report.css` | HTML 報告 CSS（與同學 `cde52470/data_science@data-analysis` 的 `Scripts/build/build_report_html.py` 同款） |
| `report_assets/sidebar.js` | sidebar 互動 / scroll-spy JS（同上來源） |

## Pipeline

```bash
# (一次性 / 改完 notebook 後) 重執行 notebook
jupyter nbconvert \
  --to notebook \
  --execute Scripts/converge_analysis.ipynb \
  --output converge_analysis.ipynb \
  --ExecutePreprocessor.timeout=1200

# 從已執行 notebook 產生 HTML 報告
python3 Scripts/build/build_converge_report.py
# → 輸出：Results/notebook_executed.html（~810 KB，含 9 張 PNG base64 內嵌）

# 兩步驟合一
./master.sh
```

## 設計：為什麼不需要 `inject_explanations.py`?

同學的非監督式專案（`cde52470/data_science@data-analysis`）採兩段式 build：
（1）執行 notebook，（2）跑 `inject_explanations.py` 在每 cell 後注入中文
「結果解讀」評註。

本 converge 專案的【目標】／【方法】／【解釋】從一開始就**作者寫進 notebook
的 markdown / `display(Markdown(f"..."))` 動態 cell**裡，所以 build 是
**單階段**：notebook → HTML。`build_converge_report.py` 內的 `SECTION_EXPL`
（每子節的「讀法指引」+「本次結果與意義」）直接以 HTML 字串嵌入，**不
需要回頭改 notebook**。

## 為什麼還留著這些腳本？

- 若想 reproduce 同方法到別的球季（例如加入 2025），改 `CONVERGE_SEASONS`
  env、重跑 `./master.sh` 就好。
- 若想換 HTML 樣式（CSS／sidebar），只改 `report_assets/` 兩個檔。
- 也作為「本份報告 HTML 不是手寫、而是 builder 從 notebook 蒸餾出來」的
  明證，便於審計。
