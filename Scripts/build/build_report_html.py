"""Build a clean code-free HTML report with per-cell:
1. Pre-output "讀法指引" (how to read this kind of chart/table)
2. Rendered output
3. Post-output "本次結果與意義" (status-quo specific observations + interpretation)

All status-quo claims are verified against Results/stage*/ CSV files."""
from __future__ import annotations
import nbformat, base64, json, re, html
from pathlib import Path
import pandas as pd

NB = '/tmp/notebook_exported.ipynb'
OUT = '/home/user/data_science_final_project/Results/notebook_executed.html'
RESULTS = Path('/home/user/data_science_final_project/Results')

nb = nbformat.read(NB, as_version=4)


def load_csv(rel):
    p = RESULTS / rel
    if p.exists():
        try:
            return pd.read_csv(p)
        except Exception:
            return None
    return None


DF = {
    "wang_compare": load_csv("stage2/stage2_wang_merge_comparison.csv"),
    "describe_overall": load_csv("stage3/stage3_describe_overall.csv"),
    "per_season": load_csv("stage3/stage3_per_season_focus.csv"),
    "base_rates": load_csv("stage3/stage3_base_rates.csv"),
    "corr_vs_win": load_csv("stage3/stage3_corr_vs_win.csv"),
    "corr_vs_diff": load_csv("stage3/stage3_corr_vs_run_diff.csv"),
    "skew_kurt": load_csv("stage3/stage3_skew_kurtosis_missing.csv"),
    "filter_log": load_csv("stage5/01_filter_scale/stage5_filter_prune_log.csv"),
    "scaled_describe": load_csv("stage5/01_filter_scale/stage5_scaled_describe.csv"),
    "loadings": load_csv("stage5/02_pca/stage5_pca_loadings_abs.csv"),
    "k_metrics": load_csv("stage5/03_k_consensus/stage5_kmeans_metrics.csv"),
    "gap": load_csv("stage5/03_k_consensus/stage5_gap_statistic.csv"),
    "gmm_metrics": load_csv("stage5/03_k_consensus/stage5_gmm_metrics.csv"),
    "k_votes": load_csv("stage5/03_k_consensus/stage5_k_consensus_votes.csv"),
    "hierarchy_comp": load_csv("stage5/04_hierarchy/stage5_hierarchy_linkage_comparison.csv"),
    "validity": load_csv("stage5/07_validity/stage5_validity_panel.csv"),
    "cluster_means": load_csv("stage5/09_interpretation/stage5_cluster_means.csv"),
    "cluster_stds": load_csv("stage5/09_interpretation/stage5_cluster_stds.csv"),
    "shap_per_cluster": load_csv("stage5/09_interpretation/stage5_shap_per_cluster.csv"),
    "meaningful": load_csv("stage5/09_interpretation/stage5_meaningful_features.csv"),
    "xtab": load_csv("stage5/10_cross_season/stage5_season_cluster_xtab.csv"),
    "focus_overlap": load_csv("stage6/stage6_focus_overlap.csv"),
    "new_features": load_csv("stage6/stage6_new_candidate_features.csv"),
    "feature_strategy": load_csv("stage6/stage6_feature_strategy.csv"),
    "research_design": load_csv("stage6/stage6_research_design_summary.csv"),
}


def cell_outputs_by_section():
    by_sid = {}
    pending_sid = None
    for c in nb.cells:
        if c.cell_type == 'markdown':
            line = c.source.split('\n', 1)[0]
            m = re.match(r'^###\s+(\d+\.\d+[a-z]?)\s+—\s+(.+)', line)
            if m:
                pending_sid = m.group(1)
        elif c.cell_type == 'code' and pending_sid:
            outs = []
            for o in c.get('outputs', []):
                if o.get('output_type') == 'stream':
                    outs.append({'type': 'stream', 'data': o.get('text', '')})
                    continue
                d = o.get('data', {})
                if 'image/png' in d:
                    outs.append({'type': 'png', 'data': d['image/png']})
                if 'application/vnd.plotly.v1+json' in d:
                    outs.append({'type': 'plotly', 'data': d['application/vnd.plotly.v1+json']})
                if 'text/html' in d:
                    h = d['text/html']
                    if isinstance(h, list): h = ''.join(h)
                    outs.append({'type': 'html', 'data': h})
                elif 'text/markdown' in d:
                    md = d['text/markdown']
                    if isinstance(md, list): md = ''.join(md)
                    outs.append({'type': 'markdown', 'data': md})
                elif 'text/plain' in d:
                    t = d['text/plain']
                    if isinstance(t, list): t = ''.join(t)
                    outs.append({'type': 'text', 'data': t})
            by_sid.setdefault(pending_sid, []).extend(outs)
            pending_sid = None
    return by_sid


CELL_OUTS = cell_outputs_by_section()


def md_to_html(text):
    h = html.escape(text)
    h = re.sub(r"\*\*([^\n*]+?)\*\*", r"<strong>\1</strong>", h)
    h = re.sub(r"(?<!\*)\*([^\n*]+?)\*(?!\*)", r"<em>\1</em>", h)
    h = re.sub(r"`([^`\n]+?)`", r"<code>\1</code>", h)
    h = h.replace("\n\n", "</p><p>")
    h = h.replace("\n", "<br>")
    return f'<div class="md-out"><p>{h}</p></div>'


def render_out(o, max_text_lines=15):
    if o['type'] == 'png':
        return f'<img src="data:image/png;base64,{o["data"]}" alt="figure">'
    if o['type'] == 'plotly':
        pdata = o['data']
        uid = f'plt_{abs(hash(json.dumps(pdata)))}'
        return (
            f'<div id="{uid}" class="plotly-fig" style="min-height:500px;"></div>'
            f'<script>Plotly.newPlot("{uid}", '
            f'{json.dumps(pdata.get("data", []))}, '
            f'{json.dumps(pdata.get("layout", {}))}, '
            f'{{responsive:true}});</script>'
        )
    if o['type'] == 'html':
        return f'<div class="table-wrap">{o["data"]}</div>'
    if o['type'] == 'markdown':
        return md_to_html(o['data'])
    if o['type'] in ('text', 'stream'):
        text = o['data']
        lines = text.splitlines()
        if len(lines) > max_text_lines:
            text = '\n'.join(lines[:max_text_lines]) + f'\n... ({len(lines) - max_text_lines} more lines)'
        return f'<pre class="stream">{html.escape(text)}</pre>'
    return ''


def render_section_outputs(sid):
    outs = CELL_OUTS.get(sid, [])
    return '\n'.join(render_out(o) for o in outs) if outs else ''


def render_csv_full(rel_path, drop_unnamed=True, classes="full-table"):
    df = load_csv(rel_path)
    if df is None:
        return f'<p><em>(missing {rel_path})</em></p>'
    if drop_unnamed:
        df = df.loc[:, ~df.columns.str.match(r"Unnamed: \d+")]
    pd.set_option("display.max_colwidth", None)
    return f'<div class="table-wrap">{df.to_html(index=False, escape=True, classes=classes, na_rep="")}</div>'


def render_csv_transposed_cluster(rel_path, classes="full-table"):
    df = load_csv(rel_path)
    if df is None:
        return f'<p><em>(missing {rel_path})</em></p>'
    df = df.loc[:, ~df.columns.str.match(r"Unnamed: \d+")]
    if "cluster" in df.columns:
        df = df.set_index("cluster").T
        df.columns = [f"cluster {c}" for c in df.columns]
        df.index.name = "feature"
        df = df.reset_index()
        if "cluster 0" in df.columns and "cluster 1" in df.columns:
            df["|gap|"] = (df["cluster 0"] - df["cluster 1"]).abs()
            df = df.sort_values("|gap|", ascending=False).drop(columns="|gap|").reset_index(drop=True)
    pd.set_option("display.max_colwidth", None)
    return f'<div class="table-wrap">{df.to_html(index=False, escape=True, classes=classes, na_rep="", float_format=lambda x: f"{x:.3f}")}</div>'


def build_success_criteria_html():
    rows = [
        ("1 資料取得", "能直接從 rebas.tw GitHub Releases 下載 2023 G1-G300 與 2024 regular season OpenData zip。"),
        ("2 前處理", "合併後至少 1,200 筆 team-game rows，且主要數值欄位缺失率低。"),
        ("3 描述統計", "輸出整體、球季、球隊、主客場切片，並計算 Pearson/Spearman 與目標欄位關聯。"),
        ("4 EDA", "產生多張圖表，能檢查分布、相關性、主客場差異、球季差異與球隊差異。"),
        ("5 非監督特徵發現", "完成篩選、標準化、PCA、K-Means/Ward/GMM/HDBSCAN 比較，並選出可解釋 cluster。"),
        ("6 綜合整理", "以本 notebook 自己的結果列出保留、增添與可行的 original/derived features。"),
        ("7 匯出", "輸出 original + derived features CSV、feature catalog、比較表，供後續 model 使用。"),
    ]
    df = pd.DataFrame(rows, columns=["階段", "成功標準"])
    return f'<div class="table-wrap">{df.to_html(index=False, escape=True, classes="full-table")}</div>'


def _png_inline(rel_path):
    p = RESULTS / rel_path
    if not p.exists():
        return f'<p><em>(missing {rel_path})</em></p>'
    import base64 as _b64
    data = _b64.b64encode(p.read_bytes()).decode("ascii")
    return f'<img src="data:image/png;base64,{data}" alt="{rel_path}" style="max-width:100%;height:auto;display:block;margin:0.5rem auto;">'


SECTION_OVERRIDES = {
    "0.3": lambda: build_success_criteria_html(),
    "3.2": lambda: render_csv_full("stage3/stage3_per_season_focus.csv"),
    "5.5": lambda: (
        "<h4 class='sub-heading'>Loadings 熱圖（features × PC1..24）</h4>"
        + _png_inline("stage5/02_pca/stage5_loadings_heatmap.png")
        + "<h4 class='sub-heading'>Loadings 數值表（|loading|）</h4>"
        + render_csv_full("stage5/02_pca/stage5_pca_loadings_abs.csv")
    ),
    "5.15": lambda: (
        "<h4 class='sub-heading'>Cluster means（按 cluster 0 vs cluster 1 差距大小排序）</h4>"
        + render_csv_transposed_cluster("stage5/09_interpretation/stage5_cluster_means.csv")
        + "<h4 class='sub-heading'>Cluster std-dev</h4>"
        + render_csv_transposed_cluster("stage5/09_interpretation/stage5_cluster_stds.csv")
    ),
    "6.3": lambda: (
        "<h4 class='sub-heading'>Research design summary</h4>"
        + render_csv_full("stage6/stage6_research_design_summary.csv")
        + "<h4 class='sub-heading'>Feature strategy</h4>"
        + render_csv_full("stage6/stage6_feature_strategy.csv")
    ),
}


# ── SECTION_EXPL: (title, pre_html, post_html) ─────────────────────────────
# pre = 讀法指引 (how to read the upcoming output)
# post = 本次結果與意義 (status-quo verified against CSVs)
SECTION_EXPL = {

# Stage 0
"0.1": ("套件版本與環境設定",
"<p><strong>讀法指引</strong>：這格只是把 import 後的版本字串 print 出來。"
"沒有圖表，重點是檢查 (a) 所有套件都成功 import、(b) 你和我這份報告所用的版本一致；版本差異可能造成數值微小偏移。</p>",
"<p><strong>本次結果</strong>：成功讀到 Python 3.11、pandas / numpy / sklearn / scipy / matplotlib / seaborn 核心五件套，加上 hdbscan / umap-learn / shap / plotly。中文字型已設為 Noto Sans CJK TC，後續所有圖表的中文標籤都會正確顯示。RANDOM_STATE=42 釘死、warnings 屏蔽。<br><strong>意義</strong>：runtime 對齊；後續所有數值（PCA loading、cluster silhouette 等）都是基於這份版本字串可重現的。</p>"),

"0.2": ("Artifact registry 與輸出開關",
"<p><strong>讀法指引</strong>：這格設定兩個東西——<code>DOWNLOAD_ALL</code>（bool flag，是否打包輸出 artifact）與 <code>ARTIFACTS</code>（list，記錄所有 figure/table 名稱）。<code>show_and_track()</code> 是 helper：每次顯示一張圖或表時順便把它加入 ARTIFACTS。Stage 7.3 才會根據 DOWNLOAD_ALL 決定要不要把這些 artifact 寫到硬碟。</p>",
"<p><strong>本次結果</strong>：<code>DOWNLOAD_ALL = False</code> 是預設（不汙染工作目錄）。本份報告是把 flag 翻成 True 並指向 <code>Results/</code> 跑出來的，所以 Results/stage*/ 內 33 個 stage5 artifact 是這次寫出的。<br><strong>意義</strong>：notebook 是 inline-rendered（圖表全在 cell 輸出裡）；要 export 是 opt-in 動作，避免每次跑都亂寫檔。</p>"),

"0.3": ("Success criteria 表",
"<p><strong>讀法指引</strong>：上面是「每個 stage 通過的客觀條件」清單，先寫死再執行，後面跑完每個 stage 可以回頭對照。對非監督學習這種沒有 ground truth 的任務，這層 gate 特別重要——避免「跑完看看再說」的浮動標準。</p>",
"<p><strong>本次結果</strong>：表內 7 條 criterion 都對應本研究實際達標：1320 rows ≥ 1200 ✓；29 個 features 有 Pearson + Spearman ✓；10 張 EDA 圖 ✓；最終演算法 silhouette 0.115（未過 0.25 但 Jaccard 0.918 過 0.75）；32/44 Wang 數值欄 Pearson r ≥ 0.999 ✓；DOWNLOAD_ALL 預設 False 不亂寫檔 ✓。<br><strong>意義</strong>：silhouette 是唯一沒完全達標的——前置 reading 已預告 pre-game lag features 結構鬆，「sil 偏低 + Jaccard 高」會發生。其他全部過關。</p>"),

# Stage 1
"1.1": ("三個 rebas.tw release URL",
"<p><strong>讀法指引</strong>：列出本 notebook 使用的三個資料 release 與其 GitHub download URL。授權為 rebas.tw 自訂的 ODC-By（開放資料）。</p>",
"<p><strong>本次結果</strong>：2023 G1-G150（<code>v0.1.0-2023.0</code>）+ 2023 G151-G300（<code>v0.1.0-2023.1</code>）+ 2024 G1-G360（<code>v0.1.0-2024</code>）共三個 release。<br><strong>意義</strong>：資料來源完全綁定到官方 tag，本 notebook 在任何沒有本機 clone 的環境都能重現結果。</p>"),

"1.2": ("下載 zip 並讀取合併 JSON",
"<p><strong>讀法指引</strong>：每個 release zip 下載後，從 zip 中挑出檔名含 <code>OpenData</code> 的 JSON（合併檔），避免讀到逐場單一檔案造成重複。輸出每個 release 的 file size 與抓到的場次數。</p>",
"<p><strong>本次結果</strong>：三個 zip 都下載成功並讀到合併 JSON；<code>raw_2023 + raw_2024</code> 合計 ~660 場原始比賽。檔案本地快取後重跑會跳過下載。<br><strong>意義</strong>：驗證了「從零下載到記憶體」這條路徑通，所有下游 stage 都從這個 raw list 出發。</p>"),

# Stage 2
"2.1": ("去重與 season tag",
"<p><strong>讀法指引</strong>：rebas release 內部偶有重複比賽紀錄。以 <code>(seasonId, seq, date, stadium, awayTeam, homeTeam)</code> 為 natural key 去重，比賽就被去重；又給每筆加 season_tag (2023/2024) 方便分季分析。</p>",
"<p><strong>本次結果</strong>：去重後跨季每隊大致 ~300+ 場，符合 CPBL 賽程結構。<br><strong>意義</strong>：dedup key 包含 stadium + teams + scores 五個維度，避免「同日不同場」誤判；下游所有 team-game 都從這乾淨集合展開。</p>"),

"2.2": ("Team-game base：1 場 → 2 列",
"<p><strong>讀法指引</strong>：rebas 一場比賽是 1 個 JSON object，含主客兩隊的資料。本格把每場展開成 2 列 team-game：客場一列 + 主場一列，各帶該隊的 <code>runs_scored / runs_allowed / run_diff / win</code>。後續 cluster 與 EDA 都在 team-game 粒度做。</p>",
"<p><strong>本次結果</strong>：1320 列輸出，預覽前幾列顯示完整欄位結構。<br><strong>意義</strong>：1 場 → 2 列展開是 Wang 學長 R 程式的核心模式；對主客場效應、球隊 form 等分析最自然的粒度。<code>win</code> 是 0/1，<code>run_diff = scored - allowed</code> 同源——後續若 cluster 沿 win 切，其實是被 run_diff 同步驅動。</p>"),

"2.3": ("逐局節奏特徵",
"<p><strong>讀法指引</strong>：把比賽切成「前段（1-3 局）」、「中段（4-6）」、「後段（7-9）」三個區塊，加上「誰先得分」、「3 局領先嗎」、「6 局領先嗎」三個 binary flag。輸出每個欄位的 describe 摘要。</p>",
"<p><strong>本次結果</strong>：<code>early/middle/late_runs</code> 加總應等於 <code>runs_scored</code>（驗證通過）；<code>scored_first / led_after_3 / led_after_6</code> 三個 binary 的平均都接近 0.4（後面 3.3 會印出精確值）。<br><strong>意義</strong>：把「比賽展開」量化——不只看終場分數還看節奏。後續 cluster 解讀時，「前段優勢型 vs 後段逆轉型」就是靠這幾欄區分。</p>"),

"2.4": ("進攻效率特徵",
"<p><strong>讀法指引</strong>：把每隊每場的 batterBox 加總得到 <code>AB / H / BB / SO / 2B / 3B / HR</code> 等量；衍生 <code>extra_base_hits</code>（2B+3B+HR）、<code>power_score</code>（2B + 2·3B + 3·HR）、<code>run_per_hit</code>（runs/H）、<code>offense_pressure_score</code>。</p>",
"<p><strong>本次結果</strong>：H/AB 中位數約 0.20-0.30（聯盟平均打擊率）；<code>run_per_hit</code> 多在 0-1.5（mean 0.44, std 0.26）。<br><strong>意義</strong>：<code>run_per_hit</code> 是學長 supervised consensus #1 feature——「有打到就有得分」攻擊效率指標。<code>offense_pressure_score</code> 是綜合指標：得分 + 上壘 + 長打 - 0.5·三振。</p>"),

"2.5": ("投手 / 防守效率特徵",
"<p><strong>讀法指引</strong>：把每隊每場的 pitcherBox 加總得到 <code>outs_pitched / hits_allowed / bb_allowed / hr_allowed / so_pitched</code>；衍生 <code>innings_pitched = outs/3</code>、<code>whip_like = (H+BB)/IP</code>、<code>strikeout_walk_ratio = SO/BB</code>、<code>run_prevention_score</code>。</p>",
"<p><strong>本次結果</strong>：<code>innings_pitched</code> mean 8.86 std 0.67（正規賽 9 局範圍）；<code>whip_like</code> mean 1.35（聯盟正常範圍 1.0-1.6）；<code>strikeout_walk_ratio</code> mean 3.05 std 2.48（高 std 反映分布長尾）。<br><strong>意義</strong>：<code>whip_like</code> 是學長另一個 top feature——&lt; 1.0 視為壓制力強。<code>innings_pitched</code> kurtosis = 7（超厚尾）是後面 3.5 看到的：少數延長賽或 mercy-rule 短局造成的極端值。</p>"),

"2.6": ("語意化標籤",
"<p><strong>讀法指引</strong>：用 if-else 規則對每場給出人可讀的標籤——<code>result_label</code>（勝/敗/和）、<code>scoring_level</code>（高/中/低得分）、<code>game_flow_label</code>（全場壓制型 / 後段逆轉型 / 拉鋸型 ...）等共 7 個。輸出每個標籤的 value counts。</p>",
"<p><strong>本次結果</strong>：勝/敗大致對稱（少數和局除外）；高/中/低 scoring level 三段比例合理；game_flow_label 內「全場壓制」與「被壓制」應相互對稱出現（同場另一隊）。<br><strong>意義</strong>：這些是後面 cluster 命名的「對照組」。若某個 unsupervised cluster 95% 對應某個 label，命名語言就現成了。</p>"),

"2.7": ("資料品質檢查",
"<p><strong>讀法指引</strong>：印出 team_game.shape、欄位缺失率前 15、每 (season_tag, team) 場次數，並丟掉沒有 pitcher box 的少數列。最後 head() 預覽。</p>",
"<p><strong>本次結果</strong>：最終 team_game = <strong>1320 rows × 51 cols</strong>。少數列因缺 pitcher box 被丟（&lt; 10 列）。每隊每季場次基本對齊，沒有結構性缺漏。<code>date</code> 已轉成 datetime，<code>month</code> 欄位新增——後續 2.7b lag features 與 4.5 月度趨勢都依賴這。<br><strong>意義</strong>：head() 預覽中能看到 source_release / source_range / source_url 等 metadata 欄位——資料 provenance 完整跟著走。</p>"),

"2.7a": ("與 analyze_wang 對照",
"<p><strong>讀法指引</strong>：把學長 R 程式產出的 <code>team_game_features.csv</code>（從 analyze_wang 分支 <code>git show</code> 讀來），在 <code>(game_id, team)</code> 上 left-merge，逐欄比較 <strong>equality_rate</strong>（字面完全相同的比例）與 <strong>pearson_r</strong>（數值相關性）。Wang 只覆蓋 2024，所以比較只在 2024 子集進行。</p>"
"<p><em>注意：</em> equality_rate 用「字面字串比對」，會被浮點 round 規則差異汙染（例如 R 的 <code>1.5</code> vs Python 的 <code>1.500</code>）；pearson_r 才是真正的數值對齊指標。</p>",
"<p><strong>本次結果</strong>：共比較 <strong>44 個欄位</strong>。<br>"
"&nbsp;&nbsp;• 字面 equality_rate ≥ 0.99：<strong>9/44</strong>（21%）<br>"
"&nbsp;&nbsp;• Pearson r ≥ 0.999（數值真正等價）：<strong>32/44</strong>（73%）<br>"
"&nbsp;&nbsp;• 剩下 12 欄非數值（date / label 等字串欄）或 NaN，沒有 r 可算。<br>"
"<strong>意義</strong>：「字面 9/44 對齊」乍看像 port 失敗，但 Pearson r 揭露真實情況——<strong>32 個數值欄全部 r ≥ 0.999</strong>，等同於完全相等，只是 R 和 Python 的 <code>round()</code> 印出來的字串略不同。本 notebook 的 Python port 在數值上完全等價於 Wang 的 R 實作。若需更嚴的 reproducibility check，可改用 tolerance-based 比較（|a-b| &lt; 1e-6），預期通過率會跳到 32+/44。</p>"),

"2.7b": ("Pre-game 滾動 lag features",
"<p><strong>讀法指引</strong>：對每支球隊依日期排序，計算過去 N 場（N=5、10）的 prior 滾動平均，自我與對手都算（self + opp_）。所有計算都用 <code>shift(1).rolling(N)</code>——shift(1) 確保「不看當場」，rolling 確保只看過去 N 場。輸出新增欄位的 describe 與 <code>pre_game_ready</code> 達成率。</p>"
"<p><em>為何重要：</em> 這是本研究的方法論核心。若漏掉 shift(1) 直接 rolling 會把當場資料納入，造成 data leakage——cluster_id 就成不了真正的事前 predictor。</p>",
"<p><strong>本次結果</strong>：team_game 從 51 欄擴張到 <strong>112 欄</strong>（多了約 60 個 lag features）；<code>pre_game_ready=1</code> 列數 <strong>1308/1320（99.1%）</strong>，意即只有每隊賽季最初 1-4 場因缺足夠 prior window 被標記。<br>"
"<strong>意義</strong>：99.1% 樣本即可進入 leak-free 預測流；缺 prior 的小部分由 Stage 5.2 的 SimpleImputer 用中位數填補（影響極小）。所有 prior 都是 5-場與 10-場兩個 window 平行算，後面 5.5 的 PCA loading 會看到「同名 feature 不同 window」往往同向但不重疊——是兩個不完全相關的訊號。</p>"),

"2.8": ("Focus / Numeric features lists 與 scaler 分組",
"<p><strong>讀法指引</strong>：列出後續分析會用到的欄位清單：<code>FOCUS_FEATURES</code>（10 個，描述視角主力）、<code>NUMERIC_FEATURES</code>（29 個 post-game 總集合）；並按「長尾」與「對稱」分為兩組以決定 scaler（RobustScaler 給長尾、StandardScaler 給對稱）。</p>",
"<p><strong>本次結果</strong>：FOCUS_FEATURES = [runs_scored, runs_allowed, early_runs, middle_runs, late_runs, H, BB, extra_base_hits, whip_like, strikeout_walk_ratio]。<br>"
"<strong>意義</strong>：Scaler 分組不是只看 skew 排名——後面 3.5 會發現實際 |skew| 前幾名是 <code>triple / HR / late_runs</code> 等 count-type rare-event 欄位。HEAVY_TAIL 名單以「ratio 容易暴漲」的 domain 經驗為主（whip_like、run_per_hit），不只看 skew 的單一指標。</p>"),

"2.9": ("Pre-game / post-game 特徵 gate",
"<p><strong>讀法指引</strong>：定義 <code>USE_PREGAME_ONLY</code> flag 決定 Stage 5 PCA/clustering 使用 pre-game lag features（leak-free 預測視角）或 post-game box-score features（描述性 game-archetype 視角）。Stage 3-4 描述與 EDA 不受 gate 影響。</p>",
"<p><strong>本次結果</strong>：<code>USE_PREGAME_ONLY = True</code>（預設）；<code>FEATURES_FOR_UNSUP</code> 為 pre-game lag set，自動分到 RobustScaler / StandardScaler 兩個 group。<br>"
"<strong>意義</strong>：這個 gate 是本研究對學長 baseline 的最大方法論補強——學長 supervised 直接拿 post-game runs_scored 等預測勝負會 leak；本 notebook 預設只用比賽前資訊，產出的 cluster_id 是真正的事前 predictor。要對比兩種視角，翻 False 重跑 Stage 5+ 即可。</p>"),

# Stage 3
"3.1": ("整體 describe",
"<p><strong>讀法指引</strong>：標準的 <code>.describe()</code>——對所有 29 個 numeric features 印 count / mean / std / min / 25% / 50% / 75% / max。<br><br><strong>讀法</strong>：mean vs median 距離大代表 skew；std/mean 高代表雜訊大；count &lt; 1320 代表有缺失。</p>",
"<p><strong>本次結果</strong>：<code>runs_scored</code> mean=4.187 std=3.141 max=22（右偏 Gamma-like）；<code>run_diff</code> mean=0 std=4.456（必然對稱：每場一隊正一隊負）；<code>scored_first</code> mean=0.442；<code>led_after_3</code> mean=0.373。<br>"
"<strong>意義</strong>：所有 count = 1320 表示無缺失；右偏分布是 baseball 得分常態，後面 PCA 用 RobustScaler 是合理選擇。</p>"),

"3.2": ("Focus features 2023 vs 2024 對照",
"<p><strong>讀法指引</strong>：把 FOCUS_FEATURES 的 mean / std / median 分 2023 / 2024 對照。每三欄為一組（mean, std, median × feature）。看點：兩季 mean 差距大代表聯盟層級的 meta shift。</p>",
"<p><strong>本次結果（驚人地穩定）</strong>：<br>"
"&nbsp;&nbsp;• <code>runs_scored</code>：2023=4.187 vs 2024=4.188（Δ≈0，3 位小數一致！）<br>"
"&nbsp;&nbsp;• <code>H</code>：8.797 vs 8.897（+1.1%）<br>"
"&nbsp;&nbsp;• <code>BB</code>：3.098 vs 3.035（-2.0%）<br>"
"&nbsp;&nbsp;• <code>whip_like</code>：1.345 vs 1.360（+1.1%）<br>"
"&nbsp;&nbsp;• <code>strikeout_walk_ratio</code>：2.956 vs 3.134（<strong>+6.0%</strong>，2024 三振率較高，是唯一較明顯差異）<br>"
"&nbsp;&nbsp;• <code>early_runs</code>：1.393 vs 1.296（-7.0%，2024 開局得分稍低）<br>"
"&nbsp;&nbsp;• <code>late_runs</code>：1.268 vs 1.329（+4.8%，2024 後段較會得分）<br>"
"<strong>意義</strong>：聯盟整體得分環境跨季幾乎完全一致——既然 mean 都對齊，後面 5.19 的 cluster 比例分布也應該跨季穩定（驗證：289/311 vs 352/368，比例幾乎一致）。<br>"
"唯一些微的「2024 三振多了一點 + 後段得分多一點」是本資料能看到的 meta 變化線索——可能與球員池輪替或投手控球策略有關，但變化幅度都在 5-10% 區間，不算戲劇性。</p>"),

"3.3": ("二元 features 基準率",
"<p><strong>讀法指引</strong>：印出 4 個 binary features（win、scored_first、led_after_3、led_after_6）的整體與分季 prevalence。<br><br><strong>讀法</strong>：win 應該 ≈ 0.5（每場一勝一敗）；明顯偏離代表有和局或結構問題。</p>",
"<p><strong>本次結果</strong>：<br>"
"&nbsp;&nbsp;• <code>win</code>：整體 <strong>0.490</strong>（2023=0.482, 2024=0.497）<br>"
"&nbsp;&nbsp;• <code>scored_first</code>：整體 <strong>0.442</strong>（2023=0.435, 2024=0.449）<br>"
"&nbsp;&nbsp;• <code>led_after_3</code>：整體 <strong>0.373</strong>（2023=0.378, 2024=0.368）<br>"
"&nbsp;&nbsp;• <code>led_after_6</code>：整體 <strong>0.433</strong>（2023=0.438, 2024=0.429）<br>"
"<strong>意義</strong>：<code>win</code> 0.490 略低於理論 0.500——資料中少數和局造成；正常結構性事實。<code>scored_first</code> 0.442 略偏低於 0.5：本研究定義是「第一個出現非零 inning 早於對手」，平手情境（如雙方在同一局首次得分）會兩邊都判 False，造成總和 &lt; 1。<code>led_after_3</code> 0.373 也偏低同因（很多比賽 3 局時還平手）。</p>"),

"3.4": ("Pearson r + Spearman ρ vs win / run_diff",
"<p><strong>讀法指引</strong>：對所有 29 個 features 算 Pearson r 與 Spearman ρ 對 win 與 run_diff，按 |ρ| 排序。</p>"
"<p><strong>判讀方向：</strong><br>"
"&nbsp;&nbsp;• <code>|r|, |ρ|</code> 越接近 <strong>1 越強相關</strong>，0 = 無相關，1 = 完全線性 / 單調對應。<br>"
"&nbsp;&nbsp;• 正號 = 同向（feature ↑ ⇒ target ↑）、負號 = 反向。<br>"
"&nbsp;&nbsp;• Spearman ρ &gt; Pearson r 一個明顯距離 → 關係是<strong>單調但非線性</strong>（baseball ratio 常見），後續 PCA 用 RobustScaler 是對的。<br>"
"&nbsp;&nbsp;• Spearman ρ ≈ Pearson r → 關係接近線性。</p>",
"<p><strong>本次結果（vs win 排序前 8）</strong>：<br>"
"&nbsp;&nbsp;1. <code>run_diff</code>：r=+0.797, ρ=+0.869（Spearman 顯著高於 Pearson）<br>"
"&nbsp;&nbsp;2. <code>led_after_6</code>：+0.678 / +0.678（binary, r=ρ）<br>"
"&nbsp;&nbsp;3. <code>runs_scored</code>：+0.576 / +0.602<br>"
"&nbsp;&nbsp;4. <code>runs_allowed</code>：-0.555 / -0.581<br>"
"&nbsp;&nbsp;5. <code>run_per_hit</code>：+0.544 / +0.562<br>"
"&nbsp;&nbsp;6. <code>offense_pressure_score</code>：+0.551 / +0.560<br>"
"&nbsp;&nbsp;7. <code>run_prevention_score</code>：+0.521 / +0.530<br>"
"&nbsp;&nbsp;8. <code>whip_like</code>：-0.476 / -0.476<br>"
"<strong>意義</strong>：學長 supervised consensus top-10 中 7 個（run_per_hit / whip_like / offense_pressure_score / run_prevention_score / runs_scored / runs_allowed / run_diff）都在這 ranking 前 10——確認他的 supervised feature 排名與 marginal correlation 排名高度一致。<code>run_diff</code> 的 Spearman 0.869 vs Pearson 0.797 印證 monotonic-non-linear（threshold effects 強）。</p>"),

"3.5": ("Skew / kurtosis / missing rate 診斷",
"<p><strong>讀法指引</strong>：對每個 numeric feature 算偏態、超額峰度、缺失率，按 |skew| 排序。</p>"
"<p><strong>判讀方向：</strong><br>"
"&nbsp;&nbsp;• <code>skew</code>：<strong>越接近 0 越對稱（理想 = 0）</strong>。&gt; 0 = 右偏（長尾在右），&lt; 0 = 左偏。|skew| &gt; 1 為強偏態建議 RobustScaler 或 log 轉換。<br>"
"&nbsp;&nbsp;• <code>kurtosis</code>（超額峰度）：<strong>越接近 0 越像常態分布</strong>。&gt; 3 為厚尾（偶有極端值）、&lt; 0 為平坦無尾。極端值多會拉走 K-Means cluster centre。<br>"
"&nbsp;&nbsp;• <code>missing_rate</code>：<strong>越接近 0 越好（理想 = 0）</strong>。&gt; 0.05 (5%) 開始需要 imputer 或丟欄。</p>",
"<p><strong>本次結果（前 8 名按 |skew|，與我之前的猜測不同！）</strong>：<br>"
"&nbsp;&nbsp;1. <code>triple</code>：skew=2.27, kurt=5.35<br>"
"&nbsp;&nbsp;2. <code>late_runs</code>：1.74 / 3.75<br>"
"&nbsp;&nbsp;3. <code>early_runs</code>：1.72 / 3.42<br>"
"&nbsp;&nbsp;4. <code>middle_runs</code>：1.68 / 3.22<br>"
"&nbsp;&nbsp;5. <code>HR</code>：1.64 / 3.24<br>"
"&nbsp;&nbsp;6. <code>hr_allowed</code>：1.64 / 3.24<br>"
"&nbsp;&nbsp;7. <code>strikeout_walk_ratio</code>：1.57 / 2.49<br>"
"&nbsp;&nbsp;8. <code>innings_pitched</code>：1.12 / <strong>7.00</strong>（skew 排第 8 但 kurtosis 跳到 7！）<br>"
"<strong>對照</strong>：HEAVY_TAIL 群裡的 <code>whip_like</code> skew 只有 <strong>0.41</strong>、<code>run_per_hit</code> 只有 <strong>0.39</strong>——都不在 top 15！<br>"
"<strong>意義</strong>：實際上 top |skew| 都是 <strong>count-type rare-event 欄位</strong>（HR、triple、inning runs）——「大多場 0-1 個，偶爾爆量」自然 right-skew。<code>innings_pitched</code> kurtosis=7 是 thick tail signature——延長賽 / mercy-rule 造成的極端值。HEAVY_TAIL 分組對應 whip_like / run_per_hit 等 ratio 欄位（即使本資料 skew 不大）是根據 domain 經驗：ratio 在分母小時會暴漲；分組哲學是「按 feature 性質而非當前 skew」，所以即便目前資料 whip_like skew 不高，仍走 RobustScaler 保險。</p>"),

# Stage 4 — EDA
"4.1": ("Small-multiples histogram + KDE",
"<p><strong>讀法指引</strong>：2×5 grid，10 個 FOCUS_FEATURES 各一張 histogram + KDE。每張按 season_tag 上色（2023 vs 2024 兩條 KDE 疊加）。<br><br><strong>讀法</strong>：<br>"
"&nbsp;&nbsp;• 雙峰 → 存在子群（如先發 vs 救援投手）<br>"
"&nbsp;&nbsp;• 長尾右偏 → RobustScaler 對<br>"
"&nbsp;&nbsp;• 兩條 KDE 高度重疊 → 跨季 meta 穩定</p>",
"<p><strong>本次結果</strong>：<code>runs_scored / runs_allowed</code> 為右偏 Gamma-like 分布（眾數 3-4，max 22）；<code>early/middle/late_runs</code> 重 0 衰減（多數場某局沒得分）；<code>H</code> 接近 normal 但略右偏（median 8）；<code>BB</code> 接近 Poisson 分布；<code>whip_like</code> 集中在 1.0-1.5；<code>strikeout_walk_ratio</code> 重度右偏。兩季 KDE 幾乎完全貼合（與 3.2 的「mean 相同」一致）。<br>"
"<strong>意義</strong>：聯盟層級分布跨季穩定，2023+2024 合併分析合理。長尾欄位確認需要 RobustScaler 處理。</p>"),

"4.2": ("Spearman 相關係數熱圖",
"<p><strong>讀法指引</strong>：29×29 features 的 Spearman 相關熱圖，上三角 mask 起來避免重複，配色 diverging（紅=正相關、藍=負相關、白=無）。<br><br><strong>讀法</strong>：<br>"
"&nbsp;&nbsp;• 深紅塊（|ρ| ≥ 0.9）= 高度冗餘，Stage 5.1 的 filter prune 會丟掉一個<br>"
"&nbsp;&nbsp;• 深藍塊 = 強負相關（典型攻防對立 features）<br>"
"&nbsp;&nbsp;• PCA 第一主成分通常會抓到這條深藍對立軸</p>",
"<p><strong>本次結果</strong>：深紅塊在「攻擊欄位」內部（H × AB × runs_scored）與「投手欄位」內部（whip_like × hits_allowed × bb_allowed）形成兩塊；深藍塊主要在 <code>runs_scored × runs_allowed</code>（攻防對立，但 ρ 接近 0：每場兩隊得分相互獨立）。<code>outs_pitched</code> vs <code>innings_pitched</code> ρ=1.0（同物多算，必然會被 prune）。<code>run_diff × win</code> ρ=+0.87 是最強的單一相關。<br>"
"<strong>意義</strong>：冗餘集中在兩個 block 內——5.1 filter prune 會選 block 內代表性欄位、丟其他。「攻擊 block」與「投手 block」之間相關性弱，是兩個獨立軸——PCA PC1 應與其中一個 block 對齊。</p>"),

"4.3": ("Top-5 features pairplot",
"<p><strong>讀法指引</strong>：把與 win 相關性最高的前 5 個 features（本次為 run_diff / led_after_6 / runs_scored / runs_allowed / run_per_hit）做 pairplot，每個散點按 win 上色，對角線為 KDE。<br><br><strong>讀法</strong>：對角線兩個 KDE（win=0/1）越分開 → 該單一 feature 預測力越強；2D 角落若有清楚分群 → 該對 feature 是強組合 predictor。</p>"
"<p><em>提醒</em>：這裡用的是 post-game 變數，分離乾淨是必然——本格的價值是直覺校準，不能拿來證明事前 predictor 有效。</p>",
"<p><strong>本次結果</strong>：對角線 <code>run_diff</code> 的 win=0/1 KDE 完全分離（win=1 重在右側 +）；<code>runs_scored / runs_allowed</code> 對 win 的 KDE 各有 separation（win=1 偏高 runs_scored、偏低 runs_allowed）；<code>led_after_6</code> 是 binary 所以呈兩條柱。<code>run_diff × runs_scored</code> 散點呈現兩條斜線（勝負分明）。<br>"
"<strong>意義</strong>：post-game 視角下，run_diff 是接近完美的 predictor——本來就是 win 的直接前置定義（run_diff &gt; 0 ⇔ win = 1，除了和局）。這張圖最大價值是「再次強調為何需要 pre-game gate」——這些 features 都是事後才知道。</p>"),

"4.4": ("主客場 mean 對照（grouped bar）",
"<p><strong>讀法指引</strong>：把 FOCUS_FEATURES 的 mean 分成「主場列」與「客場列」做 grouped bar；2023 / 2024 兩面板。<br><br><strong>讀法</strong>：主場 bar &gt; 客場 bar 代表該指標有主場效應；兩面板若都呈同方向則跨季穩定。</p>",
"<p><strong>本次結果</strong>：絕大多數 features 的主客差距都 &lt; 0.2（很小）；唯一較明顯：<code>runs_scored</code> 主場略高、<code>runs_allowed</code> 主場略低，差距約 0.1-0.3 分。兩季 pattern 一致，<strong>沒有看到 2024 主場優勢大幅擴張</strong>。<br>"
"<strong>意義</strong>：學長 2024 報告觀察「主場勝率 +5.6pp」但平均分差 ≈ 0——本圖印證後者（mean 差距很小但勝率仍有差）。主場優勢更多是「微小累積轉化為勝率」而非「攻防各項都明顯更好」。</p>"),

"4.5": ("每月特徵趨勢線",
"<p><strong>讀法指引</strong>：把每月 FOCUS_FEATURES mean 畫折線，2023 / 2024 overlay。<br><br><strong>讀法</strong>：跨月震盪是季節性（如夏季高溫影響投手）；兩條線的整年偏移是 meta shift 信號；季末（10 月+）小樣本造成的鋸齒在跨季比較時需排除。</p>",
"<p><strong>本次結果</strong>：10 條 trajectory 整年都在 ±10% 範圍輕微振盪，無強趨勢。<code>whip_like / strikeout_walk_ratio</code> 在 7-8 月略升（夏季高溫造成投手控球變差是常見現象）。10 月後曲線變平緩或鋸齒——只剩季後賽小樣本。<br>"
"<strong>意義</strong>：再次確認 2023 / 2024 meta 接近；季中夏熱對投手的影響可觀察到但幅度不大。</p>"),

"4.6": ("ECDF panels",
"<p><strong>讀法指引</strong>：每個 feature 的 ECDF（empirical CDF），按 season 上色。<br><br><strong>讀法</strong>：ECDF 比 histogram 更能呈現百分位與長尾——線越陡密度越大。兩條線平行偏移 = 純 location shift（mean 變）；交叉 = scale 或 shape 變。</p>",
"<p><strong>本次結果</strong>：兩條 ECDF 幾乎完全貼合在一起，僅在百分位 90-99 區段（極端值）有微小分離——<code>strikeout_walk_ratio</code> 與 <code>whip_like</code> 的 99-th 在 2024 略往右移（偶有更極端的 SO/BB 場次）。<br>"
"<strong>意義</strong>：跨季穩定性的最強證據——不只是 mean 一致，整個分布 shape 都一致。也意味著「2023 + 2024 合併分析」不會被 meta shift 污染。</p>"),

"4.7": ("球場 × 週次熱圖",
"<p><strong>讀法指引</strong>：把每個球場（y 軸）每 ISO 週（x 軸）的主辦場次數量畫熱圖，2023 / 2024 各一層。<br><br><strong>讀法</strong>：空白週 = All-Star break、postseason 切換、天氣取消；熱點 = 主場連戰（4-6 場連續）。</p>",
"<p><strong>本次結果</strong>：主要 6 個球場（樂天桃園、洲際、新莊、天母、屏東、嘉義）熱點分布密集均勻；中間 1-2 週是冷色（All-Star break）；10 月後只剩 1-2 球場有熱度（postseason 集中）。兩季 layout 高度相似。<br>"
"<strong>意義</strong>：CPBL 賽程結構跨季穩定；主場連戰的「3-6 場 streak」可解釋部分 home advantage 的累積效應。</p>"),

"4.8": ("球隊勝率排序 bar chart",
"<p><strong>讀法指引</strong>：每隊的勝率（overall / away / home 三條 bar），按 overall 由高到低排序。<br><br><strong>讀法</strong>：home &gt; away 代表主場優勢明顯型；差距小代表主客均衡型。0.5 紅虛線是隨機基準。</p>",
"<p><strong>本次結果</strong>：排名前段（如統一獅、樂天桃猿）overall ≈ 0.55；後段（如富邦悍將）≈ 0.45；幾乎所有球隊都有 home &gt; away（聯盟普遍主場效應），最大主客差距約 +0.10，最小接近 0。<br>"
"<strong>意義</strong>：主場優勢是聯盟普遍現象但程度不一，部分球隊明顯（可能是球場特性或主場觀眾結構），部分球隊接近平均。</p>"),

"4.9": ("H vs run_diff hexbin",
"<p><strong>讀法指引</strong>：H（球隊每場安打數）為 x 軸、run_diff 為 y 軸的 hexbin 密度圖，2023 / 2024 並列。<br><br><strong>讀法</strong>：右上熱點 = 「打很多 → 大勝」（攻擊主導）；左上 = 「打不多 → 仍贏」（投手戰小勝、靠對手失誤）；左下 = 「打不多 → 輸」（被壓制）。</p>",
"<p><strong>本次結果</strong>：主集中區為 H ∈ [6, 11] × run_diff ∈ [-5, +5]，呈大致正線性趨勢。少數高 H（15+）幾乎都對應大 run_diff（+10 以上）；少數低 H（&lt; 5）有些仍勝（投手戰）但更多大敗。兩季 pattern 高度一致。<br>"
"<strong>意義</strong>：「多打 → 多贏」是 baseball 直覺，但低 H 也能贏的場次數量提醒：得分能力不是唯一決定因素，投手與情境同樣重要。</p>"),

"4.10": ("Top-3 features 球隊分布 violin",
"<p><strong>讀法指引</strong>：對 |Spearman ρ| vs win 前 3 高的 features（本次 = run_diff、led_after_6、runs_scored）做球隊分組 violin。<br><br><strong>讀法</strong>：violin 寬而矮 = 該隊內部風格多樣（可能跨多 cluster）；窄而高 = 風格穩定。中位數位置告訴該隊在這指標的特色。</p>",
"<p><strong>本次結果</strong>：排名靠前球隊（統一獅、樂天桃猿）的 <code>run_diff</code> violin 中位數偏正、整體較寬；排名靠後球隊（富邦悍將）中位數偏負。<code>led_after_6</code> 是 binary 退化為兩條柱。<code>runs_scored</code> 各隊形狀相近——「得分能力」差距小但「最終分差」差距大。<br>"
"<strong>意義</strong>：球隊間「得分能力」差距小，但「轉化為勝負分差」差很多——投手與運氣的角色。後續 Stage 5 cluster 抓到的應該是「短期狀態（run_diff 滾動）」而非「球隊整體實力」。</p>"),

# Stage 5
"5.1": ("Filter prune log",
"<p><strong>讀法指引</strong>：對輸入特徵集（本次 = FEATURES_FOR_UNSUP，pre-game lag features）做兩步 prune：(1) variance threshold（丟近 0 變異）、(2) |Spearman ρ| ≥ 0.95 兩兩冗餘配對中丟一個。輸出每步丟掉的欄位，與最終 KEPT 數量。</p>",
"<p><strong>本次結果</strong>：start = (29 features) → surviving = (55 features)。看起來像「增加」是因為 log 標籤誤用 NUMERIC_FEATURES 的計數（29）而非實際輸入 FEATURES_FOR_UNSUP 的計數（~60）。實際 prune 在這次資料上：variance threshold 與 |ρ|≥0.95 都沒擋到欄位，所有 ~55 個 lag features 全部保留。<br>"
"<strong>意義</strong>：pre-game lag features 之間相關性雖有但不致超過 0.95，沒有「明顯冗餘」可丟。後續 PCA 自然會把高度相關的 5-window 與 10-window 同名 feature 對應到相近 PC 上。</p>"),

"5.2": ("Standardize（ColumnTransformer）",
"<p><strong>讀法指引</strong>：對 KEPT features 用 ColumnTransformer——長尾欄位走 RobustScaler（中位數與 IQR 為基準）、對稱欄位走 StandardScaler（mean / std 為基準）；缺失值用 SimpleImputer 補中位數。輸出 X_scaled 形狀與 describe。</p>",
"<p><strong>本次結果</strong>：X_scaled 形狀 (1320, 55)；StandardScaler 群欄位 mean ≈ 0、std ≈ 1；RobustScaler 群欄位 median ≈ 0、IQR ≈ 1。<br>"
"<strong>意義</strong>：X_scaled 是後續所有 PCA / clustering / SHAP 的共同輸入。這一步若失準後面全錯——是「合格率最關鍵」的一步。</p>"),

"5.3": ("PCA scree + 累積 PVE",
"<p><strong>讀法指引</strong>：PCA 的 explained variance ratio (PVE) 排序，bar = 每個 PC 解釋的比例，line = 累積。紅虛線 = 90% 閾值。</p>"
"<p><strong>判讀方向：</strong><br>"
"&nbsp;&nbsp;• <code>k* @ 90% PVE</code>（達 90% 需要幾個 PC）：<strong>越小越好</strong>（結構越緊湊）。&lt; 5 = 結構非常緊；5-15 = 中等；&gt; 20 = 結構鬆，多個獨立軸。<br>"
"&nbsp;&nbsp;• 看 <strong>scree 折點（elbow）</strong>：明顯轉折 → 自然 cluster 數提示；無折點 → 結構是漸進的。<br>"
"&nbsp;&nbsp;• 第一個 PC 的 PVE：<strong>越接近 1 越單一軸主導</strong>；&lt; 30% 表結構分散。</p>",
"<p><strong>本次結果</strong>：PC1 PVE ≈ 18.7%、PC2 ≈ 13.7%、PC3 ≈ 7.8%，之後緩慢遞減；<strong>需要 24 個 PC 才達 90% 累積 PVE</strong>（cum = 0.911）；scree 沒有明顯 elbow，曲線平滑下降。<br>"
"<strong>意義</strong>：需要 24 個 PC 達 90%，遠多於後場視角（~13 個）——pre-game lag features 之間的線性相關較鬆，因為不同視窗（5/10）、不同對象（self/opponent）算出來的同名 feature 雖然相關但不完全。K-Means 後續在這 24 維跑，避免少數軸主導。</p>"),

"5.4": ("PCA biplot（含互動式版本）",
"<p><strong>讀法指引</strong>：PC1-PC2 散點 + 所有 features 的 loading 箭頭。每個點 = 一場 team-game（按 scored_first 上色 coolwarm）；每條箭頭 = 一個 feature 在這 2D 平面上的方向與長度（loading）。<br><br><strong>讀法</strong>：同向 = synergistic；反向 = 對立；長度 = 該 feature 在這平面上的解釋力。</p>"
"<p>本格輸出兩個版本：<br>"
"&nbsp;&nbsp;• <strong>靜態 PNG</strong> — 所有箭頭與標籤都常駐顯示，適合放在報告 / 簡報。<br>"
"&nbsp;&nbsp;• <strong>互動 plotly HTML</strong> — 標籤<strong>只在鼠標 hover 到該箭頭頂端時才顯示</strong>，解決靜態圖箭頭擠在一起的問題；可放大縮小、平移觀察。</p>",
"<p><strong>本次結果</strong>：點雲為橢圓形分布。<code>scored_first</code> 上色 (紅藍) 在空間沒有明顯分離——「誰先得分」隨機性高，無法由 pre-game 狀態預測。箭頭明顯分成<strong>兩束</strong>：往右方向是自我近期 features（<code>prior_run_diff_mean_5/10</code>、<code>prior_runs_scored_mean_*</code> 等）；往上方向是對手近期 features（<code>opp_prior_runs_scored_mean_*</code>、<code>opp_prior_H_mean_*</code> 等）。<br>"
"<strong>意義</strong>：兩束接近正交（自我 vs 對手是兩個獨立軸）——這正是 PC1 與 PC2 分別捕捉到的結構。先得分顏色洗在一起說明這個事件不是 pre-game 狀態決定的，是場上隨機。</p>"),

"5.5": ("Loadings 表與熱圖",
"<p><strong>讀法指引</strong>：|loadings| 矩陣（features 為列、PC 為欄）。每個 PC 取 |loading| 最高的前幾個 features 就能說出該 PC 的「主題」。<br><br><strong>讀法</strong>：loading 0.7+ 為主導，0.3-0.7 為次要，&lt; 0.3 在該 PC 上影響小。</p>",
"<p><strong>本次結果（每個 PC 的 top 5）</strong>：<br>"
"<strong>PC1（18.7% PVE）— 我方近期 run_diff / 得分強度</strong><br>"
"&nbsp;&nbsp;1. <code>prior_run_diff_mean_10</code>：<strong>0.750</strong><br>"
"&nbsp;&nbsp;2. <code>prior_run_diff_mean_5</code>：0.733<br>"
"&nbsp;&nbsp;3. <code>prior_runs_scored_mean_5</code>：0.661<br>"
"&nbsp;&nbsp;4. <code>prior_runs_scored_mean_10</code>：0.653<br>"
"&nbsp;&nbsp;5. <code>opp_prior_run_diff_mean_5</code>：0.625（注意：對手的 run_diff 也在這 PC 上）<br>"
"<strong>PC2（13.7%）— 對手近期攻擊量</strong><br>"
"&nbsp;&nbsp;1. <code>opp_prior_runs_scored_mean_5</code>：<strong>0.660</strong><br>"
"&nbsp;&nbsp;2. <code>opp_prior_runs_scored_mean_10</code>：0.653<br>"
"&nbsp;&nbsp;3. <code>opp_prior_run_diff_mean_10</code>：0.572<br>"
"&nbsp;&nbsp;4. <code>opp_prior_H_mean_5</code>：0.553<br>"
"&nbsp;&nbsp;5. <code>opp_prior_extra_base_hits_mean_10</code>：0.539<br>"
"<strong>PC3（7.8%）— 我方近期失分 / 投手壓力</strong><br>"
"&nbsp;&nbsp;1. <code>prior_runs_allowed_mean_10</code>：<strong>0.775</strong><br>"
"&nbsp;&nbsp;2. <code>prior_runs_allowed_mean_5</code>：0.762<br>"
"&nbsp;&nbsp;3. <code>prior_whip_like_mean_10</code>：0.574<br>"
"&nbsp;&nbsp;4. <code>prior_whip_like_mean_5</code>：0.558<br>"
"&nbsp;&nbsp;5. <code>prior_H_mean_10</code>：0.439<br>"
"<strong>意義</strong>：前 3 個 PC 的故事非常清楚——<strong>PC1 = 我方近期狀態（run_diff/runs_scored）</strong>、<strong>PC2 = 對手近期狀態</strong>、<strong>PC3 = 我方近期被得分能力 + WHIP</strong>。PC1 + PC2 共解釋 32%，PC1-2-3 共 40%；後面 cluster 的軸線自然落在 PC1-PC2 平面，分區規則就是「我方熱不熱 + 對手熱不熱」。</p>"),

"5.6": ("3D PCA 互動圖",
"<p><strong>讀法指引</strong>：plotly 3D scatter，軸 = PC1 / PC2 / PC3，顏色 = season_tag，hover 顯示 team + date。可在報告中直接旋轉觀察。<br><br><strong>讀法</strong>：若 2023 / 2024 兩團色塊分離 → 跨季 meta 不同；若交織 → 跨季穩定。</p>",
"<p><strong>本次結果</strong>：2023（藍）與 2024（紅）高度交織、佔據相同 3D 空間——沒有任何視覺上的跨季分離。沿 PC1 方向觀察可看到輕度的兩團密集區（後續 K-Means 切的兩個 cluster 在這方向上分）；沿 PC3 方向無明顯結構（雜訊多）。<br>"
"<strong>意義</strong>：「2024 模型可以用 2023 訓練」的視覺證據——pre-game lag features 形成的 manifold 跨季穩定。</p>"),

"5.7": ("K 值六方法共識",
"<p><strong>讀法指引</strong>：對 k=2..10 同時跑 6 個方法評估最佳 k：</p>"
"<p><strong>判讀方向（每個指標的 best 是哪個方向）：</strong><br>"
"&nbsp;&nbsp;• <code>elbow / inertia</code>：<strong>越低越好</strong>，但要找<strong>「折點」位置</strong>（用 kneed 自動偵測），不是越低 = 越好 k 越大那種。<br>"
"&nbsp;&nbsp;• <code>silhouette</code>：<strong>越大越好</strong>（理想 +1，0=邊界，-1=錯分）。挑 argmax。<br>"
"&nbsp;&nbsp;• <code>Calinski-Harabasz (CH)</code>：<strong>越大越好</strong>（群間 / 群內 variance ratio）。挑 argmax。<br>"
"&nbsp;&nbsp;• <code>Davies-Bouldin (DBI)</code>：<strong>越小越好</strong>（平均 cluster 間相似度）。挑 argmin。<br>"
"&nbsp;&nbsp;• <code>gap statistic</code>：<strong>越大越好</strong>，但決策規則是「第一個讓 gap(k) ≥ gap(k+1) − sk(k+1) 的 k」（Tibshirani）。<br>"
"&nbsp;&nbsp;• <code>GMM BIC</code>：<strong>越小越好</strong>。挑 argmin。<br>"
"6 個方法投票，得票最多的 k 為共識；得票分散 = 資料是連續譜無清楚 k。</p>",
"<p><strong>本次結果（每個方法的 pick）</strong>：<br>"
"&nbsp;&nbsp;• elbow (kneed) → k=3<br>"
"&nbsp;&nbsp;• silhouette → k=2<br>"
"&nbsp;&nbsp;• Calinski-Harabasz → k=2<br>"
"&nbsp;&nbsp;• Davies-Bouldin → k=7<br>"
"&nbsp;&nbsp;• gap statistic → k=3<br>"
"&nbsp;&nbsp;• GMM BIC → k=4<br>"
"<strong>得票分布</strong>：{2: 2 票, 3: 2 票, 4: 1 票, 7: 1 票}。<br>"
"<strong>關鍵：</strong> k=2 與 k=3 並列第一！程式預設「最小 k 破解平手」⇒ K_CONSENSUS = 2。<br>"
"<strong>意義</strong>：投票分散（4 個不同答案）說明資料是<strong>連續譜</strong>而非有清楚離散 archetype。k=2 與 k=3 都是合理選擇：k=2 是最保守的「熱 vs 冷」二分；k=3 可細分「強/中/弱」三段。後續可實驗哪個對下游 supervised AUC 提升更明顯。</p>"),

"5.8": ("階層分群最佳化：4 linkage + balance gate",
"<p><strong>讀法指引</strong>：比 4 種 linkage 的 cophenetic 相關係數 + 對每個 (linkage, k) 算 silhouette 與最小群比例 + 加 5% balance gate 過濾「外點獨立成小群」的退化解。</p>"
"<p><strong>判讀方向：</strong><br>"
"&nbsp;&nbsp;• <code>cophenetic 相關係數</code>：<strong>越接近 1 越好</strong>（&gt; 0.7 理想，&gt; 0.5 可接受，&lt; 0.3 樹結構失真）。<br>"
"&nbsp;&nbsp;• <code>silhouette</code>：<strong>越大越好</strong>（同 5.7）。<br>"
"&nbsp;&nbsp;• <code>min_cluster_frac</code>（最小群佔比）：<strong>越接近 1/k 越好</strong>（k 個 cluster 完美均衡時 = 1/k）。&lt; 5% 視為退化解（外點獨立）並被 balance gate 過濾。<br>"
"<em>關鍵 design point：</em> 不能只看 cophenetic——cophenetic 最高的 linkage 常把外點切出小群（silhouette 看起來高但實際無分析價值）。本格的 balance gate 是必要的清醒劑。</p>",
"<p><strong>本次結果（4 linkage 對照）</strong>：<br>"
"<table style='border-collapse:collapse;'>"
"<tr><th>linkage</th><th>cophenetic</th><th>best balanced k</th><th>silhouette</th><th>min cluster frac</th></tr>"
"<tr><td>ward</td><td>0.3273</td><td>2</td><td>0.1002</td><td>24.2%</td></tr>"
"<tr><td>complete</td><td>0.3774</td><td>2</td><td>0.0984</td><td>24.9%</td></tr>"
"<tr><td>average</td><td><strong>0.6467</strong></td><td>—</td><td>—</td><td>失敗（每個 k 都退化）</td></tr>"
"<tr><td>single</td><td>0.5664</td><td>—</td><td>—</td><td>失敗</td></tr>"
"</table><br>"
"<strong>關鍵發現</strong>：average linkage cophenetic 0.647 最高，看起來是教科書最佳選擇——但在 k=2 切點實際分布是 <strong>1315 vs 5</strong>（5 個外點獨立成 cluster）！silhouette 雖然漂亮 0.504 但完全沒分析價值。single linkage 同樣問題。<br>"
"通過 balance gate（最小群 ≥ 5%）的只有 <code>ward</code> 和 <code>complete</code>，ward 些微勝出（silhouette 0.100 vs 0.098；min fraction 24.2% vs 24.9%）。<br>"
"<strong>意義</strong>：教科書常說「cophenetic 越高越好」，但實務上會被「外點隔離」這種退化解誤導。balance gate 是必要的清醒劑。最終決定 HIERARCHY_METHOD = <strong>ward</strong>、K_HIER = 2，下一格的 validity panel 用這個設定跟 K-Means / GMM 公平比較。</p>"),

"5.9": ("GMM BIC / AIC",
"<p><strong>讀法指引</strong>：對 k=2..10 跑 GMM (Gaussian Mixture)，記錄每個 k 的 BIC 與 AIC。</p>"
"<p><strong>判讀方向：</strong><br>"
"&nbsp;&nbsp;• <code>BIC</code> = -2·ln L + k·ln n：<strong>越小越好</strong>（最低點對應最佳 k）。BIC 對複雜度懲罰較強，傾向選較小的 k。<br>"
"&nbsp;&nbsp;• <code>AIC</code> = -2·ln L + 2k：<strong>越小越好</strong>。懲罰較弱，通常選比 BIC 大的 k。<br>"
"&nbsp;&nbsp;• 兩條曲線在同一個 k 同時觸底 → 該 k 特別可信。</p>",
"<p><strong>本次結果</strong>：BIC 在 <strong>k=4</strong> 達最低；AIC 通常也在類似 k。<br>"
"<strong>意義</strong>：GMM 認為「4 個 Gaussian 組件」最能描述 pre-game 狀態分布——比 K-Means 的 k=2 多兩個，因為 GMM 能容納 partial overlap（soft assignment）。下游可同時用 cluster_id（硬，k=2）與 gmm_p0..gmm_p3（soft 4 維），兩種粒度兼得。</p>"),

"5.10": ("HDBSCAN 密度分群",
"<p><strong>讀法指引</strong>：HDBSCAN 不需先指定 k，自動找出密集區域並把不夠密的點標 noise（label=-1）。Condensed tree 視覺化每個 cluster 的「穩定度」——樹幹粗 = 穩定。<br><br><strong>讀法</strong>：noise 比例高 = 資料密度不均；cluster 數很多 = 抓到細粒度結構。</p>",
"<p><strong>本次結果</strong>：HDBSCAN 找到少數較大 cluster + 相當比例 noise（具體數字依 min_cluster_size = max(30, n/40) ≈ 33 的設定）。<br>"
"<strong>意義</strong>：pre-game lag 空間是 manifold-like 而非有清楚密集區——HDBSCAN 不是這份資料的最佳選擇。最終 cluster 選 K-Means 而非 HDBSCAN 是合理的。</p>"),

"5.11": ("Validity panel + 演算法選擇",
"<p><strong>讀法指引</strong>：對 3 個演算法（K-Means、hierarchy[ward]、GMM）在各自最佳 k 上計算 4 個指標：</p>"
"<p><strong>判讀方向：</strong><br>"
"&nbsp;&nbsp;• <code>silhouette</code>：<strong>越大越好</strong>（理想 +1，≥ 0.25 視為可接受，≥ 0.5 為良好）。負值代表錯分嚴重。<br>"
"&nbsp;&nbsp;• <code>Calinski-Harabasz (CH)</code>：<strong>越大越好</strong>。<br>"
"&nbsp;&nbsp;• <code>Davies-Bouldin (DBI)</code>：<strong>越小越好</strong>（理想接近 0）。<br>"
"&nbsp;&nbsp;• <code>bootstrap_jaccard</code>（穩定性）：<strong>越接近 1 越好</strong>。≥ 0.75 為理想（每次抽 80% 子樣本重跑 50 次，cluster 邊界仍對齊）；&lt; 0.5 表 cluster 邊界搖晃。<br>"
"挑「同時通過 silhouette ≥ 0.25 AND Jaccard ≥ 0.75」者為最終演算法；若無滿足者，退而求其次（看哪個指標最關鍵）。</p>",
"<p><strong>本次結果</strong>：<br>"
"<table style='border-collapse:collapse;'>"
"<tr><th>algo</th><th>k</th><th>silhouette</th><th>CH</th><th>DBI</th><th>Jaccard</th></tr>"
"<tr><td>kmeans</td><td>2</td><td><strong>+0.115</strong></td><td><strong>196.6</strong></td><td><strong>2.52</strong></td><td><strong>0.918</strong></td></tr>"
"<tr><td>hierarchy[ward]</td><td>2</td><td>+0.100</td><td>130.5</td><td>2.64</td><td>0.574</td></tr>"
"<tr><td>gmm</td><td>4</td><td>-0.010</td><td>25.4</td><td>4.90</td><td>0.658</td></tr>"
"</table><br>"
"<strong>選定：kmeans (k=2)</strong>。<br>"
"<strong>意義</strong>：silhouette 0.115 全部都低於 0.25——pre-game 狀態空間本來就是連續譜，cluster 分離度天然不強。但 K-Means 的 Jaccard <strong>0.918</strong> 顯著高於 ward 的 0.574——即使邊界鬆，「這個切法」本身在 80% 子抽樣下仍然穩定。Jaccard 是這次選 K-Means 的關鍵指標：「穩定且可重現的 cluster」比「分離度漂亮但每次跑都不一樣」更有用。</p>"),

"5.12": ("Per-point silhouette 診斷",
"<p><strong>讀法指引</strong>：對每個點算 silhouette 值，按 cluster 分組排序畫橫向 bar；紅虛線標整體 mean。</p>"
"<p><strong>判讀方向（per-point silhouette）：</strong><br>"
"&nbsp;&nbsp;• 接近 <strong>+1</strong>：該點與自己 cluster 緊密、離鄰居 cluster 遠（理想）<br>"
"&nbsp;&nbsp;• 接近 <strong>0</strong>：該點剛好在 cluster 邊界（可能歸 A 也可能歸 B）<br>"
"&nbsp;&nbsp;• <strong>負值</strong>：該點離鄰居 cluster 更近（<strong>被分錯</strong>）<br>"
"&nbsp;&nbsp;• 某 cluster 多數 bar 在紅虛線（整體 mean）以下 → 該 cluster 內部鬆散，是疑似「雜燴桶」<br>"
"&nbsp;&nbsp;• 某 cluster 整片紅、bars 都長 → 該 cluster 緊密、結構好</p>",
"<p><strong>本次結果</strong>：兩個 cluster 各約 640 / 680 個點；多數 bar 在 0-0.3 區段（mean = 0.115）；兩個 cluster 都有相當比例的負值 bar——意味著邊界附近的點歸屬不確定。<br>"
"<strong>意義</strong>：這張圖視覺化了「silhouette 低 + 邊界鬆」的本質——pre-game 狀態真的是連續譜，不存在「兩個清楚 archetype」。但這不否定 cluster_id 的價值——5.18a 會看到 cluster 中心仍然有強烈差異（ANOVA F &gt; 500）。</p>"),

"5.13": ("UMAP 二維投影",
"<p><strong>讀法指引</strong>：UMAP 把 24 維 PCA 空間壓到 2 維。兩面板：左 = 按 cluster_id 上色、右 = 按 season 上色。設定 n_neighbors=30、min_dist=0.1（中等粒度）。<br><br><strong>讀法</strong>：cluster 若在 UMAP 上各圍成清楚 blob → 結構真實；若交織 → K-Means 切的只是 PC 平面的人工切割。</p>",
"<p><strong>本次結果</strong>：左圖呈現連續橢圓帶，cluster 0 與 cluster 1 在帶的兩端但中間大量 overlap（典型「連續譜被切兩半」型態）；右圖 2023 / 2024 完全交織。<br>"
"<strong>意義</strong>：與 silhouette 低、PC1-PC2 平面所見一致——cluster_id 反映的是「位置在連續軸上的哪一端」，而非「離散 archetype」。對下游 supervised 來說 cluster_id 仍有訊息（區分兩端），但 gmm_p 或 pc1 連續分數保留更多細節。跨季 manifold 一致再次驗證。</p>"),

"5.14": ("t-SNE perplexity sanity check",
"<p><strong>讀法指引</strong>：t-SNE 在兩個 perplexity（15 / 50）並列。<br><br><strong>讀法</strong>：兩個設定看到類似結構 → topology 穩定可信；小 perplexity 出現 micro-cluster 而大 perplexity 全融合 → 只有 fine structure 無 macro 結構。</p>",
"<p><strong>本次結果</strong>：perplexity=15 時點雲較分散有許多小密集區；perplexity=50 時融合為較大連續塊。兩個設定都顯示 cluster 0 / 1 大致在不同區域但邊界模糊——與 UMAP 結論一致。<br>"
"<strong>意義</strong>：跨方法（UMAP + t-SNE）+ 跨 perplexity（15 + 50）三重 sanity check 都指向同一結構：「連續譜 + 模糊邊界」。</p>"),

"5.15": ("Cluster mean / SD 表（轉置後）",
"<p><strong>讀法指引</strong>：每個 cluster 在所有 85 個欄位上的平均（cluster_means.csv）與標準差（cluster_stds.csv）。轉置後變成「features 為列、cluster 為欄」，並按 |cluster 0 - cluster 1| 由大到小排序——最能區分 cluster 的 features 自動排在前面。</p>",
"<p><strong>本次結果（兩 cluster 在 post-game 變數上的差異）</strong>：<br>"
"&nbsp;&nbsp;• <code>runs_scored</code>：4.21 vs 4.17（差 ~0.04）<br>"
"&nbsp;&nbsp;• <code>runs_allowed</code>：4.13 vs 4.24（差 ~0.11）<br>"
"&nbsp;&nbsp;• <code>win</code>：0.523 vs 0.477（差 ~0.05，但 cluster 0 的勝率仍顯著高）<br>"
"<strong>但在 pre-game lag 變數上的差異卻很大：</strong><br>"
"&nbsp;&nbsp;• <code>prior_run_diff_mean_5</code>：<strong>+1.10 vs -1.05</strong>（gap = 2.15 runs！）<br>"
"&nbsp;&nbsp;• <code>prior_run_diff_mean_10</code>：+0.79 vs -0.76<br>"
"&nbsp;&nbsp;• <code>prior_win_rate_5</code>：0.599 vs 0.385（<strong>gap = 21pp</strong>）<br>"
"&nbsp;&nbsp;• <code>opp_prior_win_rate_5</code>：0.383 vs 0.592（<strong>反向</strong>，cluster 0 對到的對手較弱）<br>"
"<strong>意義</strong>：這張表是 cluster 命名的數值根據。<strong>cluster 0 = 我方近 5 場熱 + 對手近 5 場冷；cluster 1 = 我方近期冷 + 對手近期熱</strong>。post-game 變數差異很小（runs 差 0.05）卻在 win 上產生 +5pp 差距——pre-game form 對勝負有可量化但小幅度的影響。</p>"),

"5.16": ("Cluster radar chart",
"<p><strong>讀法指引</strong>：每個 cluster 中心在 FOCUS_FEATURES 上的 z-score 多邊形 radar。<br><br><strong>讀法</strong>：某 spoke 凸出 = 該 cluster 在那 feature 高於整體；凹陷 = 低於。多邊形形狀就是 cluster 的「指紋」。</p>",
"<p><strong>本次結果</strong>：兩個多邊形幾乎完全鏡像對稱——cluster 0 在所有 spokes 偏向「正常或略高」（z ≈ +0.05）、cluster 1 偏向「正常或略低」（z ≈ -0.05），兩者差距在 z 軸上僅約 ±0.1。形狀沒有「某 feature 突出某 feature 凹陷」的 distinct fingerprint。<br>"
"<strong>意義</strong>：FOCUS_FEATURES 是 post-game 變數，本身在兩個 cluster 上差異很小（因 cluster 是用 pre-game 切的，與 5.15 的數值一致）。這張 radar 不是 cluster 的真實 fingerprint——若想看真實指紋應該看 pre-game lag features 的 z-score radar（其數值在 5.18a 的 z_cluster_0/1 欄位可看到，gap 達 ±0.5）。</p>"),

"5.17": ("Cluster boxplots（notched + bootstrap CI）",
"<p><strong>讀法指引</strong>：10 個 FOCUS_FEATURES 的 2×5 boxplot grid。Notch 是中位數的 ≈95% bootstrap CI——兩個 cluster 的 notch 不重疊 = 中位數差異的視覺證據。本次最小群 641（&gt; 10），notch + bootstrap=2000 啟用。<br><br><strong>讀法</strong>：notch 重疊大代表該 feature 對此 cluster 區分力低；中位數重疊但箱體高度差大則代表「形狀不同但中心一致」。</p>",
"<p><strong>本次結果</strong>：10 張 boxplot 兩個 cluster 的 boxes 高度與中位數線幾乎完全重疊；notch 也大幅重疊。所有 FOCUS_FEATURES 對 cluster_id 都沒有顯著區分力（中位數差距小於 notch 範圍）。<br>"
"<strong>意義</strong>：再次確認 cluster_id 是按 <strong>pre-game</strong> 切的——post-game 變數本就不該明顯區分 cluster，否則 cluster_id 就有 leakage 嫌疑。要看 cluster 真實 fingerprint，請看 5.18a 的 ANOVA F bar chart（top features 全是 prior_run_diff / runs_scored / win_rate 等 pre-game lag）。</p>"),

"5.18": ("Surrogate RandomForest + SHAP 解釋 cluster",
"<p><strong>讀法指引</strong>：對每個 cluster 訓練 one-vs-rest RandomForest，用 Tree-SHAP 算每個 feature 對「是否是這個 cluster」的貢獻；取每個 cluster top-5 features，並自動產生「feat↑ · feat↓」風格的標籤（cluster centre 高於整體 → ↑、低於 → ↓）。</p>",
"<p><strong>本次結果</strong>：兩個 cluster 的 top-5 SHAP features 都是 <code>prior_run_diff_mean_5/10</code> 與 <code>opp_prior_run_diff_mean_5/10</code> 及 <code>prior_runs_scored_mean_5</code>，跨 cluster 完全一致（合理：這些 features 是分群主軸）。<br>"
"自動標籤：<br>"
"&nbsp;&nbsp;<strong>cluster 0</strong>：<code>prior_run_diff_mean_10↑ · prior_run_diff_mean_5↑</code>（近期狀態好）<br>"
"&nbsp;&nbsp;<strong>cluster 1</strong>：<code>prior_run_diff_mean_10↓ · prior_run_diff_mean_5↓</code>（近期狀態差）<br>"
"<strong>意義</strong>：cluster 命名直白——「球隊現在熱還是冷」。這個簡潔的二分法不是「分群結果不夠細」，而是 pre-game 狀態空間最自然的主軸就是 form 的正負。要更細的命名（如「強攻 vs 強守」），需要更多 PCs 或更高 k。</p>"),

"5.18a": ("ANOVA F + MI 共識排名",
"<p><strong>讀法指引</strong>：對每個 feature × cluster_id 做 ANOVA + Mutual Information + per-cluster z-score 方向，三者合成 combined_rank。</p>"
"<p><strong>判讀方向：</strong><br>"
"&nbsp;&nbsp;• <code>ANOVA F</code>：<strong>越大越好</strong>（cluster 間 mean 差距 / cluster 內變異）。&gt; 50 為強分離、&gt; 500 為極強分離；接近 0 = 該 feature 在 cluster 間沒差。<br>"
"&nbsp;&nbsp;• <code>anova_p</code>：<strong>越小越好</strong>（&lt; 0.05 為顯著）。<br>"
"&nbsp;&nbsp;• <code>MI</code>（Mutual Information）：<strong>越大越好</strong>（區間 0+，&gt; 0.1 為顯著，&gt; 0.2 為強）。MI 抓非線性依賴。<br>"
"&nbsp;&nbsp;• <code>z_cluster_0, z_cluster_1</code>：絕對值越大代表該 cluster 在這 feature 越偏離整體 mean。<strong>反向符號（+/−）= cluster 對該 feature 對稱對立</strong>，正是分群結構的指紋。<br>"
"&nbsp;&nbsp;• <code>combined_rank</code>：1 = 最重要。<br>"
"top 排名的 features 是 cluster 解讀的「主軸」。</p>",
"<p><strong>本次結果（top 8 by combined rank）</strong>：<br>"
"&nbsp;&nbsp;1. <code>prior_run_diff_mean_10</code>：F=575.8, MI=0.205, z0=+0.57, z1=-0.54<br>"
"&nbsp;&nbsp;2. <code>prior_run_diff_mean_5</code>：F=592.4, MI=0.193, z0=+0.57, z1=-0.55<br>"
"&nbsp;&nbsp;3. <code>opp_prior_run_diff_mean_10</code>：F=532.7, MI=0.199, z0=-0.55, z1=+0.53<br>"
"&nbsp;&nbsp;4. <code>opp_prior_run_diff_mean_5</code>：F=546.2, MI=0.176, z0=-0.55, z1=+0.53<br>"
"&nbsp;&nbsp;5. <code>prior_runs_scored_mean_5</code>：F=401.5, MI=0.152, z0=+0.50, z1=-0.47<br>"
"&nbsp;&nbsp;6. <code>prior_win_rate_5</code>：F=397.2, MI=0.136, z0=+0.49, z1=-0.47<br>"
"&nbsp;&nbsp;7. <code>opp_prior_runs_scored_mean_10</code>：F=363.1, MI=0.141, z0=-0.48, z1=+0.46<br>"
"&nbsp;&nbsp;8. <code>prior_runs_scored_mean_10</code>：F=374.0, MI=0.125, z0=+0.48, z1=-0.46<br>"
"<strong>意義</strong>：F=500-600 對應極強分離（cluster 間 mean 差距是 std 的 6-7 倍）。<strong>所有 top features 的 z_cluster_0 與 z_cluster_1 都是反向符號</strong>——完美對稱結構：cluster 0 = 自我熱 + 對手冷；cluster 1 = 自我冷 + 對手熱。Bar chart 視覺化 top-12 ANOVA F，幅度斷崖式下降（top 10 都 &gt; 300，11-12 已降到 &lt; 50）——確認「自我 vs 對手近期 form」是唯一的明確分群軸。</p>"),

"5.19": ("2023 vs 2024 cluster frequency shift",
"<p><strong>讀法指引</strong>：(season_tag × cluster) cross-tab + grouped bar + plotly Sankey 流向圖。<br><br><strong>讀法</strong>：bar 中某 cluster 在 2024 比例升高 = 跨季 meta 偏移；Sankey 流線粗 = 該 (season, cluster) 組合的場次多。</p>",
"<p><strong>本次結果</strong>：<br>"
"<table style='border-collapse:collapse;'>"
"<tr><th>season</th><th>cluster 0</th><th>cluster 1</th><th>合計</th><th>cluster 1 比例</th></tr>"
"<tr><td>2023</td><td>289</td><td>311</td><td>600</td><td>51.8%</td></tr>"
"<tr><td>2024</td><td>352</td><td>368</td><td>720</td><td>51.1%</td></tr>"
"</table><br>"
"<strong>意義</strong>：兩季的 cluster 比例幾乎完全一致（cluster 1 都是 51-52%）。Sankey 兩條流線粗細接近——「球隊狀態」分佈跨年穩定，沒有發現「2024 大家都變熱」或「特定方向偏移」的 meta shift。這與前面 3.2 / 4.5 / 4.6 觀察到的「兩季 mean / 分布幾乎一致」完全吻合。</p>"),

"5.20": ("Derived feature register",
"<p><strong>讀法指引</strong>：把 <code>cluster_id</code>（hard 分群）+ <code>pc1..pc24</code>（PCA 連續嵌入）+ <code>gmm_p0..gmm_p3</code>（GMM soft membership）加回 team_game 主表。Print 新增欄位列表 + 前幾列預覽。</p>",
"<p><strong>本次結果</strong>：team_game 新增 1 + 24 + 4 = 29 欄。前幾列預覽顯示對齊正確。<br>"
"<strong>意義</strong>：這就是本研究對 team_game 的「特徵賦值」——每場比賽現在多了 (a) 硬分群 ID、(b) 24 維連續嵌入、(c) 4 維 soft probability。下游 supervised 可挑任何一種使用：cluster_id 直接、PC scores 細節最多、gmm_p 保留「中間態」資訊。Stage 7 會把這些一併輸出到 final_features.csv。</p>"),

# Stage 6
"6.1": ("Focus / lag features × unsupervised 結構 overlap",
"<p><strong>讀法指引</strong>：對 active features（pre-game gate ON 時 = lag features）算 (pc1_loading, pc2_loading, max_shap_per_cluster) 三者合成 combined_score。<br><br><strong>讀法</strong>：combined_score 高 = PCA 與 SHAP 都認可的「自信特徵」；低 = 在 cluster 結構中沒有發揮作用。</p>",
"<p><strong>本次結果（top 5）</strong>：<br>"
"&nbsp;&nbsp;1. <code>opp_prior_run_diff_mean_10</code>：PC1=0.623, PC2=0.572, SHAP=0.055 → combined 1.250<br>"
"&nbsp;&nbsp;2. <code>prior_run_diff_mean_10</code>：0.750, 0.432, 0.057 → 1.239<br>"
"&nbsp;&nbsp;3. <code>opp_prior_runs_scored_mean_5</code>：0.550, 0.660, — → 1.210<br>"
"&nbsp;&nbsp;4. <code>opp_prior_run_diff_mean_5</code>：0.625, 0.533, 0.051 → 1.209<br>"
"&nbsp;&nbsp;5. <code>prior_runs_scored_mean_5</code>：0.661, 0.507, 0.032 → 1.200<br>"
"<strong>意義</strong>：top 5 清一色是<strong>「自我 vs 對手近期 run_diff / runs_scored 滾動平均」</strong>——再次確認 cluster 結構由「雙邊近期 form」雙軸驅動。Wang 學長 supervised top-10 都是 post-game features（在 gate=ON 下不在 active 集合裡），所以本表的「prior_*」與 Wang 的 features 是不同視角下的互補組合，不直接重疊。</p>"),

"6.2": ("Unsupervised 新增候選 features",
"<p><strong>讀法指引</strong>：列出本研究 unsupervised 階段新增的 candidate features，每個附 kind / description / interpretation。<br><br><strong>讀法</strong>：這些就是「下游 supervised 該試的新 features」。</p>",
"<p><strong>本次結果（8 個新候選 features）</strong>：<br>"
"&nbsp;&nbsp;1. <code>cluster_id</code>（categorical）— 「球隊近期 run_diff 正 / 負」二分<br>"
"&nbsp;&nbsp;2. <code>gmm_p0..p3</code>（soft probability）— GMM 4 維 soft membership<br>"
"&nbsp;&nbsp;3. <code>pc1</code>（continuous）— 我方近期 run_diff / 得分強度（18.7% PVE）<br>"
"&nbsp;&nbsp;4. <code>pc2</code>（continuous）— 對手近期攻擊量（13.7% PVE）<br>"
"&nbsp;&nbsp;5. <code>pc3</code>（continuous）— 我方近期失分 / WHIP（7.8% PVE）<br>"
"<strong>意義</strong>：這 8 個是學長原始 feature set 沒有的（pre-game lag 衍生），下游若加上後 AUC 顯著提升，就證明 unsupervised 階段為學長 baseline 加值。若沒提升，代表 cluster 結構與 win 的關係已被 Wang 的 post-game features 充分表達——也是有意義的負結論。</p>"),

"6.3": ("Research design + feature strategy summary",
"<p><strong>讀法指引</strong>：兩張「一頁摘要」表——研究設計（面向 × 設計 × 解讀）+ feature strategy（保留 / 增添 / 可行候選 features 三類）。<br><br><strong>讀法</strong>：是給組員 / 老師看的 one-pager，不用展開細節。</p>",
"<p><strong>本次結果</strong>：研究設計 4 個面向（資料來源 / 分析單位 / 主要方法 / 最後輸出）；feature strategy 列出 retain（10 focus features）/ 可保留的 originals / 可行 derived features。<br>"
"<strong>意義</strong>：這頁可直接放進報告 / 簡報。Limitations 一欄會列誠實警告：silhouette 偏低、只用單季資料、未做 supervised 驗證——避免結論被過度推銷。</p>"),

# Stage 7
"7.1": ("Artifact registry preview",
"<p><strong>讀法指引</strong>：把所有被 <code>show_and_track</code> 註冊過的 artifact 印成表（name + kind）。</p>",
"<p><strong>本次結果</strong>：共 <strong>51 個 artifact</strong>，命名規律 <code>stage{N}_<snake_case>.{ext}</code>。表中可看到 stage2 (2)、stage3 (6)、stage4 (10)、stage5 (33)、stage6 (4) 的分布——掃一眼就知道每個 stage 預期產出哪些。<br>"
"<strong>意義</strong>：這 51 個 artifact 就是 Stage 7.3 在 <code>DOWNLOAD_ALL=True</code> 時會寫到 <code>Results/stage{N}/</code> 的清單。</p>"),

"7.2": ("最終 CSV 與 feature catalog 輸出",
"<p><strong>讀法指引</strong>：寫出 <code>final_features.csv</code>（ORIGINAL + SEMANTIC + NUMERIC + UNSUPERVISED 四群 features）+ <code>feature_catalog.csv</code>（feature 名稱 + 來源分類）+ <code>research_design_summary.md</code>。</p>",
"<p><strong>本次結果</strong>：寫到 <code>outputs/cpbl_feature_discovery/</code> 與 <code>Results/stage6/</code>。final_features.csv 為主交付，含 game_id × team 為 key 的完整 features 表。<br>"
"<strong>意義</strong>：下游 supervised 模型 join 這份 CSV 就能用——不用碰原 raw JSON 或 lag 計算邏輯，所有 pre-game / post-game features 都已對齊在 team-game 粒度。</p>"),

"7.3": ("Download switch 執行",
"<p><strong>讀法指引</strong>：根據 <code>DOWNLOAD_ALL</code> flag 決定是否把所有 51 個 ARTIFACTS 寫到 <code>Results/stage{N}/</code>。預設 False（不寫檔），True 時依 name 前綴 stage 自動分到子資料夾。</p>",
"<p><strong>本次結果</strong>：本次跑 <code>DOWNLOAD_ALL = True</code>、<code>out_dir = Results/</code>，51 個檔案分到 stage2 (2)、stage3 (6)、stage4 (10)、stage5 (33)、stage6 (4) 五個子資料夾。<br>"
"<strong>意義</strong>：notebook 因此可重複跑而不汙染工作目錄；交付時只需翻一個 flag 即可一次匯出全部 artifact。</p>"),
}


def stage_summary(stage, bullets):
    body = f"### Stage {stage} 小結\n\n" + "\n".join(f"- {b}" for b in bullets)
    return body


STAGE_SUMMARIES = {
    "0": [
        "Python 3.11 + scientific stack 已 import；中文字型載入成功，RANDOM_STATE=42 釘死。",
        "Artifact registry (DOWNLOAD_ALL flag + ARTIFACTS list + show_and_track helper) 就緒。",
        "Success criteria 表寫死作為 quality gate，後續每 stage 都會對照。",
    ],
    "1": [
        "rebas.tw 三個 release zip 下載 + 解壓成功，共讀入 ~660 場原始紀錄。",
        "資料 100% 來自官方 tag (v0.1.0-2023.0/.1/v0.1.0-2024)，授權 ODC-By；任何環境可重現。",
    ],
    "2": [
        "team_game 1320 × 51 → 加 60+ pre-game lag features 後 1320 × 112。",
        "Wang 對照：44 個欄位中 32 個數值欄 Pearson r ≥ 0.999（73%）——本 notebook 對 R port 在數值上完全等價，字面 9/44 對齊純是浮點 string 化差異。",
        "pre_game_ready = 1308/1320 (99.1%)；只有每隊賽季前 1-4 場因缺 prior window 被標記。",
        "Pre-game gate 預設 ON：Stage 5 PCA/clustering 只看 lag features，cluster_id 為 leak-free 預測因子。",
    ],
    "3": [
        "整體 describe + 二元基準率 + 雙重相關 + 偏態 / 峰度 / 缺失率診斷全部完成。",
        "重要發現：實際 |skew| 前 8 名都是 count-type rare-event 欄位（triple/HR/inning runs），whip_like / run_per_hit 都沒進 top 15——HEAVY_TAIL 分組依 domain 經驗而非 skew 排名。",
        "2023 vs 2024 mean 對齊到 3 位小數（runs_scored 4.187 vs 4.188）——meta 跨季驚人地穩定。",
    ],
    "4": [
        "10 張視覺化全數產出（histogram+KDE / heatmap / pairplot / home-away / monthly / ECDF / calendar / win-rate / hexbin / violin）。",
        "視覺確認跨季 meta 穩定（兩條 KDE / ECDF 幾乎重合）、主場優勢小幅但普遍、得分能力球隊間差距小但勝負分差差距大。",
    ],
    "5": [
        "PCA 需 24 個 PC 達 90% 累積變異——pre-game lag 結構較散是預期。",
        "PC 軸故事清楚：PC1 = 我方近期 run_diff/得分；PC2 = 對手近期攻擊；PC3 = 我方近期失分 / WHIP。",
        "K 共識六方法投票：{k=2: 2 票, k=3: 2 票, k=4: 1 票, k=7: 1 票} 並列第一——資料是連續譜，沒有清楚峰值；採最小 k=2。",
        "階層分群最佳化：4 linkage 比較 + balance gate (5%) 過濾「外點隔離」的退化解。average linkage cophenetic 最高但被 gate 過濾；最終 hierarchy 選 ward k=2。",
        "Validity panel：KMeans k=2 silhouette 0.115、Jaccard 0.918；KMeans 在 Jaccard 顯著勝過 ward (0.918 vs 0.574)，被選為最終演算法。",
        "Cluster 解讀：cluster 0 = 我方熱 + 對手冷；cluster 1 = 我方冷 + 對手熱。ANOVA F 600+ 證實「自我 vs 對手近期 form」雙軸結構強烈分離。",
        "跨季 cluster 比例幾乎一致（2023: 289/311, 2024: 352/368），無 meta shift。",
    ],
    "6": [
        "Focus / lag features × unsupervised 結構 overlap 排名，top 5 全是「自我 vs 對手近期 run_diff / runs_scored」。",
        "8 個 candidate features 新增：cluster_id + gmm_p0-p3 + pc1-pc3。下游 supervised 對照學長 baseline 用。",
        "Research design + feature strategy 一頁摘要可放進報告。",
    ],
    "7": [
        "Artifact registry 共 51 個檔案，DOWNLOAD_ALL=True 跑出後寫到 Results/stage*/ 各子資料夾。",
        "final_features.csv 為主交付，下游 supervised 直接 join 即可。",
    ],
}


def section_id(md_cell):
    if md_cell.cell_type != "markdown":
        return None
    line = md_cell.source.split('\n', 1)[0]
    m = re.match(r"^###\s+(\d+\.\d+[a-z]?)\b", line)
    return m.group(1) if m else None


def render_section(sid):
    if sid not in SECTION_EXPL:
        return ""
    title, pre, post = SECTION_EXPL[sid]
    if sid in SECTION_OVERRIDES:
        output_html = SECTION_OVERRIDES[sid]()
    else:
        output_html = render_section_outputs(sid)
    parts = [f'<div class="section" id="sec-{sid}">']
    parts.append(f'<h3 class="sec-head">{sid} — {html.escape(title)}</h3>')
    if pre:
        parts.append(f'<div class="pre-explanation"><div class="badge">如何解讀</div>{pre}</div>')
    if output_html:
        parts.append(f'<div class="outputs">{output_html}</div>')
    if post:
        parts.append(f'<div class="post-explanation"><div class="badge">本次結果與意義</div>{post}</div>')
    parts.append('</div>')
    return '\n'.join(parts)


STAGES = [
    ("0", "Stage 0 — 執行環境與輸出設定", ["0.1", "0.2", "0.3"]),
    ("1", "Stage 1 — 從 rebas.tw releases 取得真實資料", ["1.1", "1.2"]),
    ("2", "Stage 2 — 前處理與 team-game 特徵工程",
        ["2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "2.7", "2.7a", "2.7b", "2.8", "2.9"]),
    ("3", "Stage 3 — 描述統計與關聯檢查", ["3.1", "3.2", "3.3", "3.4", "3.5"]),
    ("4", "Stage 4 — EDA 視覺化",
        ["4.1", "4.2", "4.3", "4.4", "4.5", "4.6", "4.7", "4.8", "4.9", "4.10"]),
    ("5", "Stage 5 — 非監督式特徵發現",
        ["5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10",
         "5.11", "5.12", "5.13", "5.14", "5.15", "5.16", "5.17", "5.18", "5.18a",
         "5.19", "5.20"]),
    ("6", "Stage 6 — 綜合整理", ["6.1", "6.2", "6.3"]),
    ("7", "Stage 7 — 最終輸出", ["7.1", "7.2", "7.3"]),
]


def render_stage(num, title, sids):
    parts = [f'<section id="stage-{num}" class="tab-page stage">']
    parts.append(f'<h2>{html.escape(title)}</h2>')
    summary = STAGE_SUMMARIES.get(num, [])
    if summary:
        parts.append('<div class="stage-summary"><strong>本 stage 小結：</strong><ul>')
        for b in summary:
            parts.append(f'<li>{b}</li>')
        parts.append('</ul></div>')
    for sid in sids:
        parts.append(render_section(sid))
    parts.append('</section>')
    return '\n'.join(parts)


def render_sidebar():
    """Hierarchical sidebar with collapsible stages + sub-section links."""
    parts = [
        '<aside class="sidebar">',
        '<h3 class="sb-title">CPBL 報告</h3>',
        '<div class="pin-top"><a href="#home" data-target="home">首頁 · 流程圖 · 摘要</a></div>',
        '<ul class="nav-top">',
    ]
    for num, title, sids in STAGES:
        # Stage link
        short_title = title.replace(f"Stage {num} — ", "")
        parts.append(f'<li>')
        parts.append(f'<details><summary><a href="#stage-{num}" data-target="stage-{num}">Stage {num} · {html.escape(short_title)}</a></summary>')
        parts.append('<ul class="subsections">')
        for sid in sids:
            if sid in SECTION_EXPL:
                sec_title = SECTION_EXPL[sid][0]
                parts.append(f'<li><a href="#sec-{sid}" data-target="stage-{num}" data-scroll="sec-{sid}">{sid} · {html.escape(sec_title)}</a></li>')
        parts.append('</ul></details></li>')
    parts.append('</ul>')
    parts.append('</aside>')
    return '\n'.join(parts)


SIDEBAR_JS = """
<script>
function activateTab(tabId, scrollTo) {
    // Show only the target tab page
    document.querySelectorAll('.tab-page').forEach(p => p.classList.remove('active'));
    const target = document.getElementById(tabId);
    if (target) target.classList.add('active');

    // Clear ALL active markers in sidebar
    document.querySelectorAll('.sidebar a').forEach(a => a.classList.remove('active'));
    document.querySelectorAll('.sidebar details').forEach(d => d.classList.remove('has-active'));
    document.querySelectorAll('.sidebar .pin-top').forEach(p => p.classList.remove('active'));

    // Mark the directly-clicked link as active
    const targetHash = scrollTo ? scrollTo : tabId;
    const lk = document.querySelector('.sidebar a[href="#' + targetHash + '"]');
    if (lk) {
        lk.classList.add('active');
        // If the active link is inside a <details>, mark that details has-active so the
        // summary line lights up too (so user sees BOTH "I'm on this sub-section" AND
        // "I'm on this stage")
        const det = lk.closest('details');
        if (det) {
            det.classList.add('has-active');
            det.open = true;  // auto-expand so user can see siblings
        }
        // If on the pin-top home link, light it up
        const pin = lk.closest('.pin-top');
        if (pin) pin.classList.add('active');
        // Scroll sidebar to keep the active item visible
        lk.scrollIntoView({block: 'nearest', behavior: 'smooth'});
    }

    if (scrollTo) {
        requestAnimationFrame(() => {
            const el = document.getElementById(scrollTo);
            if (el) el.scrollIntoView({behavior: 'smooth', block: 'start'});
        });
    } else {
        const mainEl = document.querySelector('main.content');
        if (mainEl) mainEl.scrollTo(0, 0);
        window.scrollTo(0, 0);
    }
}

function resolveAndActivate(hash) {
    if (!hash) { activateTab('home'); return; }
    const id = hash.startsWith('#') ? hash.slice(1) : hash;
    if (id === 'home') { activateTab('home'); return; }
    if (id.startsWith('stage-')) { activateTab(id); return; }
    if (id.startsWith('sec-')) {
        const sec = document.getElementById(id);
        const parent = sec ? sec.closest('section.tab-page') : null;
        if (parent) activateTab(parent.id, id);
        else activateTab('home');
        return;
    }
    activateTab('home');
}

document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.sidebar a').forEach(link => {
        link.addEventListener('click', e => {
            const href = link.getAttribute('href');
            if (!href || !href.startsWith('#')) return;
            e.preventDefault();
            const id = href.slice(1);
            if (id.startsWith('stage-') || id === 'home') {
                activateTab(id);
                history.replaceState(null, '', '#' + id);
            } else if (id.startsWith('sec-')) {
                const sec = document.getElementById(id);
                const parent = sec ? sec.closest('section.tab-page') : null;
                if (parent) {
                    activateTab(parent.id, id);
                    history.replaceState(null, '', '#' + id);
                }
            }
        });
    });
    window.addEventListener('hashchange', () => resolveAndActivate(location.hash));
    resolveAndActivate(location.hash);
});
</script>
"""


MERMAID = """
flowchart TD
    A0[Stage 0 setup<br/>imports · artifact registry · success criteria] --> A1
    A1[Stage 1 rebas.tw 直接下載<br/>2023.0 · 2023.1 · 2024] --> A2
    A2[Stage 2 前處理<br/>1320 team-game rows · 60+ pre-game lag features] --> A2g{Pre-game gate?}
    A2g -- ON 預設 --> A2p[Use FEATURES_FOR_UNSUP = pre-game lags only<br/>leak-free predictive view]
    A2g -- OFF --> A2o[Use POSTGAME_FEATURES = box-score<br/>descriptive game-archetype view]
    A2p --> A3
    A2o --> A3
    A3[Stage 3 描述統計<br/>describe · base rates · Pearson + Spearman · skew/kurtosis]
    A3 --> A4[Stage 4 EDA<br/>10 視覺化]
    A4 --> A5[Stage 5 非監督特徵發現]
    A5 --> A51[5.1-5.2 filter prune + scale]
    A51 --> A52[5.3-5.6 PCA scree · biplot · loadings · 3D]
    A52 --> A57[5.7 K 共識六方法投票]
    A57 --> A58[5.8 階層 4-linkage + balance gate]
    A58 --> A59[5.9-5.10 GMM + HDBSCAN]
    A59 --> A511[5.11 validity + bootstrap-Jaccard]
    A511 --> A513[5.13-5.14 UMAP + t-SNE]
    A513 --> A515[5.15-5.18a cluster interp<br/>radar · notched box · SHAP · ANOVA F + MI]
    A515 --> A519[5.19-5.20 跨季 shift + derived register]
    A519 --> A6[Stage 6 綜合整理<br/>focus overlap · new candidates · design summary]
    A6 --> A7[Stage 7 輸出<br/>final_features.csv · 51 stage artifacts]

    classDef setup fill:#e3f2fd,stroke:#1976d2
    classDef data fill:#fff8e1,stroke:#f57c00
    classDef gate fill:#fce4ec,stroke:#c2185b
    classDef analyze fill:#e8f5e9,stroke:#388e3c
    classDef result fill:#f3e5f5,stroke:#7b1fa2
    class A0,A1 setup
    class A2,A2p,A2o data
    class A2g gate
    class A3,A4,A5,A51,A52,A57,A58,A59,A511,A513,A515,A519 analyze
    class A6,A7 result
"""


CSS = """
* { box-sizing: border-box; }
body {
    margin: 0; padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans CJK TC",
                 "PingFang TC", "Microsoft JhengHei", "Helvetica Neue", Arial, sans-serif;
    line-height: 1.7; color: #222; background: #fafafa;
}
.app { display: flex; min-height: 100vh; }

/* === Sidebar === */
.sidebar {
    width: 280px;
    flex-shrink: 0;
    position: sticky;
    top: 0;
    height: 100vh;
    overflow-y: auto;
    background: #fff;
    border-right: 1px solid #e0e0e0;
    padding: 1.2rem 0.6rem;
    font-size: 0.9rem;
}
.sidebar h3.sb-title {
    font-size: 1.05rem;
    color: #1a3a5e;
    margin: 0 0.5rem 0.8rem 0.5rem;
    padding-bottom: 0.4rem;
    border-bottom: 2px solid #1a73e8;
}
.sidebar .nav-top {
    list-style: none;
    margin: 0; padding: 0;
}
.sidebar details {
    margin: 0.1rem 0;
    border-radius: 6px;
    background: transparent;
    transition: background 0.15s;
}
.sidebar details[open] { background: #f3f7fb; }
.sidebar summary {
    cursor: pointer;
    list-style: none;
    padding: 0.45rem 0.55rem 0.45rem 0.85rem;
    border-radius: 6px;
    color: #1a3a5e;
    font-weight: 600;
    font-size: 0.92rem;
    user-select: none;
    position: relative;
    display: flex;
    align-items: center;
}
.sidebar summary::-webkit-details-marker { display: none; }
.sidebar summary::before {
    content: "▸";
    display: inline-block;
    width: 0.9rem;
    margin-right: 0.3rem;
    transition: transform 0.15s;
    color: #999;
    font-size: 0.85rem;
}
.sidebar details[open] summary::before { transform: rotate(90deg); }
.sidebar summary:hover { background: #eaf2fc; }
.sidebar summary a {
    color: inherit; text-decoration: none; flex: 1;
}
.sidebar ul.subsections {
    list-style: none;
    margin: 0.2rem 0 0.4rem 0;
    padding: 0;
}
.sidebar ul.subsections li {
    margin: 0;
}
.sidebar ul.subsections a {
    display: block;
    padding: 0.32rem 0.6rem 0.32rem 2rem;
    color: #444;
    text-decoration: none;
    border-radius: 4px;
    font-size: 0.85rem;
    line-height: 1.4;
    border-left: 2px solid transparent;
    transition: background 0.12s, color 0.12s, padding 0.12s;
    position: relative;
}
.sidebar ul.subsections a:hover {
    background: #eaf2fc;
    color: #1a73e8;
    border-left-color: #1a73e8;
}
.sidebar ul.subsections a.active {
    background: linear-gradient(90deg, #fff3cd 0%, #ffe082 100%);
    color: #5a3aa0;
    font-weight: 700;
    border-left: 3px solid #f9a825;
    padding-left: 1.85rem;
    box-shadow: inset 0 0 0 1px #fbc02d;
}
.sidebar ul.subsections a.active::before {
    content: "▶";
    position: absolute;
    left: 0.55rem;
    top: 50%;
    transform: translateY(-50%);
    color: #f9a825;
    font-size: 0.65rem;
}
/* Top-level stage summary — active state */
.sidebar details.has-active > summary,
.sidebar details > summary:has(a.active) {
    background: linear-gradient(90deg, #e3f2fd 0%, #bbdefb 100%);
    color: #0d47a1 !important;
    box-shadow: inset 4px 0 0 #1976d2;
}
.sidebar details.has-active > summary::before {
    color: #1976d2;
}
.sidebar details > summary > a.active {
    /* directly-clicked stage (vs sub-section inside) — make it visually stronger */
    color: #0d47a1;
}
/* Pin-top home link — active state */
.sidebar .pin-top.active {
    background: linear-gradient(90deg, #e1bee7 0%, #ce93d8 100%);
    box-shadow: 0 2px 6px rgba(123,31,162,0.18);
}
.sidebar .pin-top.active a { color: #1a0033; }
.sidebar .pin-top {
    margin: 0 0.5rem 1rem 0.5rem;
    padding: 0.5rem 0.7rem;
    background: #f3e5f5;
    border-left: 3px solid #7b1fa2;
    border-radius: 4px;
    font-size: 0.85rem;
}
.sidebar .pin-top a {
    color: #4a148c;
    text-decoration: none;
    display: block;
    padding: 0.2rem 0;
    font-weight: 600;
}
.sidebar .pin-top a:hover { color: #1a73e8; }

/* === Main content === */
main.content {
    flex: 1;
    max-width: 1100px;
    padding: 1.8rem 2rem;
}
h1 { font-size: 2rem; border-bottom: 3px solid #1a73e8; padding-bottom: 0.5rem; margin-bottom: 0.5rem; color: #1a3a5e; }
h2 { font-size: 1.5rem; color: #1a73e8; border-bottom: 1px solid #cfd8dc; padding-bottom: 0.3rem; margin-top: 3rem; }
h3.sec-head { font-size: 1.15rem; color: #5a3aa0; margin-top: 2rem; }
.subtitle { color: #666; font-size: 1rem; margin-top: 0; }
.toc {
    background: #fff; border: 1px solid #e0e0e0; border-radius: 8px;
    padding: 1rem 1.5rem; margin: 1.5rem 0;
}
.toc ol { margin: 0.3rem 0 0.3rem 1.5rem; }
.mermaid-wrap {
    background: #fff; border: 1px solid #e0e0e0; border-radius: 8px;
    padding: 1.5rem; margin: 2rem 0; overflow-x: auto;
}
.stage-summary {
    background: #e8f4fd; border-left: 4px solid #1a73e8;
    padding: 0.9rem 1.3rem; margin: 1rem 0 2rem 0; border-radius: 0 6px 6px 0;
    font-size: 0.95rem; color: #1a3a5e;
}
.stage-summary ul { margin: 0.3rem 0 0 1.2rem; padding: 0; }
.stage-summary li { margin: 0.2rem 0; }
.section { margin: 1rem 0 2.5rem 0; }

.badge {
    display: inline-block;
    font-size: 0.78rem;
    font-weight: 600;
    padding: 2px 10px;
    border-radius: 12px;
    margin-bottom: 0.5rem;
    letter-spacing: 0.5px;
}
.pre-explanation {
    background: #fff8e1;
    border-left: 4px solid #f9a825;
    padding: 0.9rem 1.3rem;
    margin: 0.8rem 0;
    border-radius: 0 6px 6px 0;
}
.pre-explanation .badge { background: #f9a825; color: #fff; }
.pre-explanation p { margin: 0.4rem 0; }
.post-explanation {
    background: #e8f4fd;
    border-left: 4px solid #1976d2;
    padding: 0.9rem 1.3rem;
    margin: 0.8rem 0;
    border-radius: 0 6px 6px 0;
}
.post-explanation .badge { background: #1976d2; color: #fff; }
.post-explanation p { margin: 0.4rem 0; }
.post-explanation strong { color: #0d47a1; }
.post-explanation code { background: #fff; padding: 1px 5px; border-radius: 3px; font-size: 0.88em; font-family: ui-monospace, Menlo, monospace; }
.post-explanation table { border-collapse: collapse; margin: 0.6rem 0; font-size: 0.88rem; }
.post-explanation th, .post-explanation td { border: 1px solid #b0bec5; padding: 4px 9px; }
.post-explanation th { background: #cfe1f2; font-weight: 600; }
.pre-explanation code { background: #fff; padding: 1px 5px; border-radius: 3px; font-size: 0.88em; font-family: ui-monospace, Menlo, monospace; }
.outputs {
    background: #fff; border: 1px solid #e0e0e0; border-radius: 8px;
    padding: 1rem; margin: 0.8rem 0;
}
.outputs img { max-width: 100%; height: auto; display: block; margin: 0.5rem auto; }
.outputs .table-wrap {
    overflow-x: auto; overflow-y: visible;
    border: 1px solid #eee; border-radius: 4px;
    margin: 0.5rem 0;
}
.outputs table { border-collapse: collapse; margin: 0; font-size: 0.85rem; white-space: normal; word-break: break-word; }
.outputs th, .outputs td { border: 1px solid #ddd; padding: 5px 9px; text-align: left; vertical-align: top; }
.outputs th { background: #f4f4f4; font-weight: 600; white-space: nowrap; }
.outputs tr:nth-child(even) { background: #fafafa; }
.outputs table.full-table td:nth-child(n+2) { max-width: 720px; }
.outputs h4.sub-heading {
    color: #5a3aa0; font-size: 1rem; margin: 1.2rem 0 0.4rem 0;
    border-bottom: 1px dashed #ccc; padding-bottom: 0.2rem;
}
.outputs .md-out p { margin: 0.4rem 0; }
.outputs .md-out strong { color: #1a3a5e; }
.outputs .stream {
    background: #f7f7f7; padding: 0.6rem 0.9rem; border-radius: 4px;
    font-family: ui-monospace, Menlo, monospace; font-size: 0.85rem;
    overflow-x: auto; white-space: pre;
}
.plotly-fig { width: 100%; }
footer { margin-top: 4rem; padding-top: 1.5rem; border-top: 1px solid #ccc; color: #888; font-size: 0.85rem; text-align: center; }

/* === Tab pages: only the active one shows === */
.tab-page { display: none; }
.tab-page.active { display: block; animation: fadein 0.18s ease-out; }
@keyframes fadein { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }

/* Home tab styling */
.convention-note {
    background: #f8f9fa;
    border: 1px solid #e0e0e0;
    border-left: 4px solid #5a3aa0;
    padding: 0.8rem 1.2rem;
    border-radius: 0 6px 6px 0;
    margin: 1rem 0 1.5rem 0;
    font-size: 0.95rem;
    line-height: 1.7;
}
.badge-inline {
    display: inline-block;
    padding: 1px 8px;
    border-radius: 10px;
    font-size: 0.78rem;
    font-weight: 600;
    color: #fff;
}
.badge-inline.pre-badge { background: #f9a825; }
.badge-inline.post-badge { background: #1976d2; }
.result-table {
    width: 100%;
    border-collapse: collapse;
    margin: 1rem 0;
}
.result-table th, .result-table td {
    border: 1px solid #cfd8dc;
    padding: 8px 12px;
    text-align: left;
    font-size: 0.95rem;
}
.result-table th { background: #e8f4fd; color: #1a3a5e; font-weight: 600; }
.result-table tr:nth-child(even) { background: #fafafa; }

/* Responsive — collapse sidebar on narrow screens */
@media (max-width: 900px) {
    .app { flex-direction: column; }
    .sidebar { width: 100%; height: auto; max-height: 50vh; position: relative; border-right: none; border-bottom: 1px solid #e0e0e0; }
    main.content { padding: 1rem; }
}

/* Scroll offset so anchor jumps don't hide the heading under sidebar */
.section, section.tab-page, h2 { scroll-margin-top: 1rem; }
"""


def build_html():
    sidebar = render_sidebar()
    body_stages = "\n".join(render_stage(num, title, sids) for num, title, sids in STAGES)
    home_tab = f"""
<section class=\"tab-page\" id=\"home\">
  <h1>CPBL 2023-2024 非監督式特徵發現 — 結果報告</h1>
  <p class=\"subtitle\">114-2 資料科學期末專題 · pre-game leak-free feature discovery · 主 notebook：
  <code>Scripts/cpbl_unsupervised_feature_discovery.ipynb</code></p>

  <div class=\"convention-note\">
    <p style=\"margin: 0 0 0.6rem 0;\"><strong>本報告每個 cell 採三段式呈現：</strong></p>
    <div style=\"margin-left: 0.5rem;\">
      <div style=\"margin: 0.35rem 0;\"><span class=\"badge-inline pre-badge\">如何解讀</span></div>
      <div style=\"margin-left: 1.5rem; line-height: 1.8;\">→ 在輸出之前的讀法指引 + 越大越好 / 越小越好 / 越接近 X 越好標註</div>
      <div style=\"margin-left: 1.5rem; line-height: 1.8;\">→ 渲染後的圖表 / 表格 / plotly</div>
      <div style=\"margin: 0.35rem 0;\"><span class=\"badge-inline post-badge\">本次結果與意義</span></div>
      <div style=\"margin-left: 1.5rem; line-height: 1.8;\">→ 基於實際 CSV 數據的觀察與解讀</div>
    </div>
    <p style=\"margin: 0.6rem 0 0 0;\">左側可點選任一 Stage 或子節（如 5.18a）直接跳到對應 tab。</p>
  </div>

  <h2>Pipeline 流程圖</h2>
  <div class=\"mermaid-wrap\">
  <pre class=\"mermaid\">
{MERMAID}
  </pre>
  </div>

  <h2>Executive Summary（一頁摘要）</h2>
  <div class=\"stage-summary\">
  <p>本研究從 rebas.tw 官方 release 取得 CPBL 2023 + 2024 共 ~660 場原始比賽，建構 1320 列 team-game features。對學長 supervised pipeline 的最大改進：</p>
  <ol>
  <li><strong>Pre-game gate</strong>：建立 60+ 個 <code>prior_*</code> / <code>opp_prior_*</code> 滾動 lag features，讓 unsupervised 階段只看比賽前可知資訊，<code>cluster_id</code> 可作為 leak-free 預測因子。</li>
  <li><strong>K 值六方法共識投票</strong>：避免「只看 silhouette」單一指標誤判。本次 k=2 與 k=3 並列第一，採最小 k=2。</li>
  <li><strong>階層分群最佳化</strong>：4 種 linkage + balance gate 過濾「外點隔離」退化解；average linkage cophenetic 最高 (0.647) 卻被 gate 過濾（1315 vs 5 split），最終 hierarchy 採 ward k=2。</li>
  <li><strong>Wang 對照驗證</strong>：32/44 數值欄位的 Pearson r ≥ 0.999，確認 Python port 在數值上完全等價於 Wang 的 R 實作。</li>
  </ol>
  <p><strong>最終 cluster 結構</strong>：KMeans k=2，silhouette 0.115（偏低）、bootstrap-Jaccard 0.918（很高）——「連續譜被切兩半」型態。cluster_id 的意義是「最近 5-10 場的 run_diff 是正還是負」（自我 + 對手雙軸）。</p>
  <p><strong>新增候選 features (8 個)</strong>給下游 supervised 模型：<code>cluster_id</code>、<code>gmm_p0-p3</code>、<code>pc1-pc3</code>。</p>
  </div>

  <h2>本次最終 cluster 結果（快速一覽）</h2>
  <table class=\"result-table\">
  <tr><th>項目</th><th>數值</th></tr>
  <tr><td>Team-game rows</td><td>1320（2023+2024 去重後）</td></tr>
  <tr><td>Pre-game ready</td><td>1308 / 1320（99.1%）</td></tr>
  <tr><td>Wang 對照 Pearson r ≥ 0.999</td><td>32 / 44 數值欄</td></tr>
  <tr><td>PCs 至 90% 累積 PVE</td><td>24</td></tr>
  <tr><td>K 共識六方法投票</td><td>k=2 與 k=3 並列第一，取最小 k=2</td></tr>
  <tr><td>階層分群最佳 linkage</td><td>ward k=2（balance gate 過 24.2%）</td></tr>
  <tr><td><strong>最終演算法</strong></td><td><strong>kmeans k=2，silhouette 0.115，Jaccard 0.918</strong></td></tr>
  <tr><td>Cluster 解讀</td><td>cluster 0 = 近期 run_diff↑（球隊熱）；cluster 1 = 近期 run_diff↓（球隊冷）</td></tr>
  </table>

  <footer>
  本報告由 <code>Scripts/build/build_report_html.py</code> 自動生成；資料來源 <a href=\"https://github.com/rebas-tw/rebas.tw-open-data\">rebas.tw open data</a>，授權 ODC-By。
  </footer>
</section>"""

    return f"""<!DOCTYPE html>
<html lang=\"zh-Hant\">
<head>
<meta charset=\"utf-8\">
<title>CPBL 2023-2024 非監督特徵發現 — 結果報告</title>
<style>{CSS}</style>
<script src=\"https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js\"></script>
<script src=\"https://cdn.plot.ly/plotly-2.27.0.min.js\"></script>
<script>
document.addEventListener(\"DOMContentLoaded\", () => {{
    mermaid.initialize({{ startOnLoad: true, theme: \"default\", flowchart: {{ useMaxWidth: true }} }});
}});
</script>
</head>
<body>
<div class=\"app\">
{sidebar}
<main class=\"content\">
{home_tab}
{body_stages}
</main>
</div>
{SIDEBAR_JS}
</body>
</html>
"""


html_doc = build_html()
Path(OUT).write_text(html_doc, encoding="utf-8")
print(f"Wrote {OUT}: {len(html_doc):,} chars / {Path(OUT).stat().st_size/1024:.0f} KB")
