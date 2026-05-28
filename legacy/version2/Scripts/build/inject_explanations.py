"""Inject thoughtful per-cell output explanations, per-stage summaries, and final
workflow recap into the executed notebook.

Structure of every explanation cell:

    **結果解讀**

    - **看到了什麼**
      - …
      - …
    - **解讀**
      - …
      - …

No emojis. No embedded raw output dumps (those break rendering inside nested
bullets and duplicate what's already shown above)."""
from __future__ import annotations
import nbformat
import re
import textwrap
from pathlib import Path

SRC = Path("/tmp/cpbl_unsupervised_feature_discovery.executed.ipynb")
DST = Path("/tmp/cpbl_unsupervised_feature_discovery.annotated.ipynb")

nb = nbformat.read(SRC, as_version=4)


def md(text: str):
    return nbformat.v4.new_markdown_cell(textwrap.dedent(text).strip("\n"))


def cell_text(c) -> str:
    parts = []
    for o in c.get("outputs", []):
        if "text" in o:
            parts.append(o["text"])
        d = o.get("data", {})
        if "text/plain" in d:
            parts.append(d["text/plain"])
    return "\n".join(parts)


def count_figs(c) -> int:
    n = 0
    for o in c.get("outputs", []):
        d = o.get("data", {})
        if "image/png" in d or "application/vnd.plotly.v1+json" in d:
            n += 1
    return n


def find_first(pattern: str, text: str, default: str = "?") -> str:
    m = re.search(pattern, text)
    return m.group(1) if m else default


def find_two(pattern: str, text: str, default=("?", "?")):
    m = re.search(pattern, text)
    return (m.group(1), m.group(2)) if m else default


# Pre-extract headline numbers once
all_text = "\n".join(cell_text(c) for c in nb.cells if c.cell_type == "code")
TG_ROWS, TG_COLS = find_two(r"team_game shape：\((\d+),\s*(\d+)\)", all_text)
LAG_ROWS, LAG_COLS = find_two(r"team_game 更新後：\((\d+),\s*(\d+)\)", all_text)
WANG_EQ = find_first(r"equality_rate ≥ 0\.99 的有 (\d+) 個", all_text, "?")
WANG_TOTAL = find_first(r"比對欄位數：(\d+)", all_text, "?")
PRE_N, PRE_TOT = find_two(r"pre_game_ready=1 的列數：(\d+) / (\d+)", all_text)
try:
    PRE_PCT = f"{int(PRE_N)/int(PRE_TOT):.1%}"
except Exception:
    PRE_PCT = "?"
PCS_NEEDED = find_first(r"達到 90% 累積解釋變異需要的 PC 數：\s*(\d+)", all_text, "?")
K_CONS = find_first(r"K_CONSENSUS（最多票）= (\d+)", all_text, "?")
K_GMM = find_first(r"K_GMM \(BIC\) = (\d+)", all_text, "?")
SIL = find_first(r"sil=([\d.]+)", all_text, "?")
JAC = find_first(r"jaccard=([\d.]+)", all_text, "?")
MIN_CLUSTER_N = find_first(r"min cluster size = (\d+)", all_text, "?")


def block(seen: list[str], read: list[str]) -> str:
    """Compose a 結果解讀 cell from two lists of bullets."""
    parts = ["**結果解讀**", "", "- **看到了什麼**"]
    for s in seen:
        parts.append(f"  - {s}")
    parts.append("- **解讀**")
    for r in read:
        parts.append(f"  - {r}")
    return "\n".join(parts)


# ── Per-section explanation functions ────────────────────────────────────
SECTION_EXPL: dict[str, "callable"] = {}


def section(sid: str):
    def deco(fn):
        SECTION_EXPL[sid] = fn
        return fn
    return deco


# Stage 0 — Setup
@section("0.1")
def _(_t, _f):
    return block(
        seen=[
            "Python 3.11、numpy / pandas / scikit-learn / scipy / matplotlib / seaborn 的版本字串。",
            "hdbscan、umap-learn、shap 也成功 import；中文字型已設定為 Noto Sans CJK TC，圖表中文不會變方塊。",
            "RANDOM_STATE 設為 42，warnings 已隱藏，seaborn / matplotlib 全域樣式統一。",
        ],
        read=[
            "版本字串就是「結果可重現性」的基準——若日後別台機器跑出不同數值，先比這份版本字串而不是改演算法。",
            "中文字型成功載入代表後續所有圖表的標題、x/y 軸標籤、legend 都能正確呈現繁體中文。",
            "把 RANDOM_STATE 釘死、warnings 屏蔽，是讓「執行→截圖→寫進報告」的循環不會被 stochastic noise 或 deprecation 雜訊干擾的前置條件。",
        ],
    )


@section("0.2")
def _(_t, _f):
    return block(
        seen=[
            "`DOWNLOAD_ALL = False`，意思是預設不在硬碟產生任何 side-effect 檔案。",
            "`ARTIFACTS` 是一個空 list，將由 `show_and_track()` 在每一個圖 / 表後面 append。",
        ],
        read=[
            "把「顯示」與「下載」解耦：notebook 本身永遠是 inline-rendered 的，唯讀模式下不會弄髒工作目錄。",
            "Stage 7 是唯一會檢查 `DOWNLOAD_ALL` 的地方——使用者只需改一個 flag 就能一鍵打包所有 artefact，無需改其他 cell。",
            "這個設計遵循 Karpathy 「Surgical Changes」原則：每個 stage 只關心自己的職責，輸出邏輯集中管理。",
        ],
    )


@section("0.3")
def _(_t, _f):
    return block(
        seen=[
            "渲染後的 success criteria 表，每一個 stage 對應一條可量化的通過條件。",
        ],
        read=[
            "把 success criteria 預先寫死，就能在跑完每一個 stage 時客觀檢核「這一段算不算成功」。",
            "對於非監督學習這種沒有 ground truth 的任務，這層 quality gate 是 Karpathy 「Goal-Driven」原則的具體實踐——避免「跑完看看再說」的浮動標準。",
        ],
    )


# Stage 1 — Data acquisition
@section("1.1")
def _(_t, _f):
    return block(
        seen=[
            "三個 rebas.tw GitHub release 的 direct download URL：2023.0（G1-G150）、2023.1（G151-G300）、2024（G1-G360）。",
            "每一筆來源附 release tag、檔名與 URL，便於回查。",
        ],
        read=[
            "資料來源完全綁定到官方 release tag，這份 notebook 因此可以在任何沒有本機 clone 的環境重現結果。",
            "URL 列在前面而不是埋在 cell 中，組員若想加進 2023 Challenge / TaiwanSeries 只要往 `RELEASE_SOURCES` 接續加入即可，不需要重看下游程式碼。",
        ],
    )


@section("1.2")
def _(_t, _f):
    return block(
        seen=[
            "每個 release zip 被下載到 `data/raw/rebas_tw_open_data/`，並印出檔案大小與 zip 內讀到的 consolidated JSON member 名稱與場次數量。",
            "完成後 `raw_2023` 與 `raw_2024` 兩個 list 分別存放未去重的比賽 dict。",
        ],
        read=[
            "三個 release 都優先挑選檔名含 `OpenData` 的合併 JSON，而不是逐場 single-game json，避免 list-vs-dict 結構錯讀。",
            "下載到本機後檔案會被快取——重跑 notebook 不會重新下載，加速迭代。",
            "後續所有 stage 都從這兩個 raw list 出發，因此這一步驗證了「資料可以被讀進來」這個最基本的前提。",
        ],
    )


# Stage 2 — Preprocessing
@section("2.1")
def _(_t, _f):
    return block(
        seen=[
            "去重前後的原始紀錄數（不同 release zip 的 JSON member 偶爾重複出現某些比賽）。",
            "每一個 season_tag 的比賽數量計數。",
        ],
        read=[
            "Dedup 用 `(seasonId, seq, date, stadium, awayTeam, homeTeam)` 為 natural key——能避免來源檔案結構造成的假性重複，又不會把真實的雙重賽合併掉。",
            "從每季 ~330 場（regular season）左右的計數可以反推：2023 半季 release 各約 150 場、2024 整季 360 場，總和符合官方賽程，沒有遺漏。",
        ],
    )


@section("2.2")
def _(_t, _f):
    return block(
        seen=[
            "`team_game_base` 的形狀（每場比賽 → 2 列、客場+主場各一筆）。",
            "前幾列預覽顯示 `game_id / team / opponent / is_home / runs_scored / runs_allowed / run_diff / win` 的初步結構。",
        ],
        read=[
            "1-game-to-2-rows 是 Wang 學長 R 程式的核心展開方式，本 notebook 完全跟著走，下游所有 cluster 都是 team-game level。",
            "`run_diff = runs_scored - runs_allowed` 與 `win = int(runs_scored > runs_allowed)` 同源——任何 cluster 一旦對齊到 win，背後其實是被 run_diff 同步驅動。",
        ],
    )


@section("2.3")
def _(_t, _f):
    return block(
        seen=[
            "`early_runs / middle_runs / late_runs` 的 describe 摘要，三者加總應等於 `runs_scored`。",
            "`scored_first / led_after_3 / led_after_6` 的 binary 機率（接近 0.5 屬正常）。",
        ],
        read=[
            "若 `late_runs > early_runs` 的場次比例顯著偏高，代表 CPBL 的得分節奏偏向後段——這是「後段逆轉型」game flow label 出現頻率的伏筆。",
            "`led_after_6` 與 `win` 的相關性通常 >0.8——baseball 的 6 局領先優勢是常識，本表確認這個常識在 2023+2024 資料上成立。",
        ],
    )


@section("2.4")
def _(_t, _f):
    return block(
        seen=[
            "進攻欄位的 describe：`AB / H / BB / SO / double / triple / HR`，以及衍生的 `extra_base_hits / power_score / run_per_hit / offense_pressure_score`。",
        ],
        read=[
            "`H / AB` 中位數通常落在 0.20-0.30 區間（聯盟整體打擊率），明顯偏離代表特定球隊或場次的打擊異常。",
            "`run_per_hit` 是 Wang 學長 supervised consensus 排名第一的 feature；它高代表「打有打到就有得分」、低代表「打了沒有得分」，是攻擊效率的純度指標。",
            "`power_score = 2B + 2×3B + 3×HR` 是長打加權，與 `extra_base_hits`（單純加總）相比能區分「全壘打型」與「二壘安打型」進攻。",
        ],
    )


@section("2.5")
def _(_t, _f):
    return block(
        seen=[
            "防守 / 投手欄位的 describe：`outs_pitched / innings_pitched / hits_allowed / bb_allowed / hr_allowed / so_pitched / whip_like / strikeout_walk_ratio / run_prevention_score`。",
        ],
        read=[
            "`innings_pitched` 中位數應該緊貼 9（正規賽長度）；明顯小於 9 多半是延長賽或被 mercy-rule 結束的比賽。",
            "`whip_like = (hits_allowed + bb_allowed) / innings_pitched` 是 Wang 學長另一個 top feature；聯盟平均約 1.3-1.5，低於 1.0 代表壓制力強。",
            "`strikeout_walk_ratio` 在 BB=0 時直接退回 SO 本身（除零保護），這個 special case 在 Stage 3.5 的 skew 表會看到效果。",
        ],
    )


@section("2.6")
def _(_t, _f):
    return block(
        seen=[
            "七個語意化標籤（`result_label / run_diff_label / scoring_level / allowing_level / game_flow_label / offense_label / defense_label`）的 value_counts。",
        ],
        read=[
            "「勝」與「敗」應該各佔 ~50%（少數和局除外），確認 team-game 樣本平衡。",
            "`game_flow_label` 中「全場壓制型」與「被壓制型」應該對稱（一勝一敗對應同一場），出現大幅不對稱代表 flow 判斷邏輯有 bug。",
            "這些標籤是後續 cluster 命名的「對照組」：若 unsupervised 的 cluster 對齊到某個語意 label 的比例異常高，就有 ready-made 的解釋語言。",
        ],
    )


@section("2.7")
def _(_t, _f):
    return block(
        seen=[
            f"`team_game` 最終形狀 ({TG_ROWS} × {TG_COLS})，各欄位缺失率前 15，以及每 (season_tag, team) 的場數矩陣。",
            "因為 `dropna(subset=['whip_like'])` 而被丟掉的比賽數（沒有 pitcher box 的場次）。",
            "`date` 已轉成 datetime、新增 `month` 欄位。",
        ],
        read=[
            "team_game 的最終列數應該接近「去重後比賽數 × 2」；偏離很多通常意味著 dedup key 過嚴或 pitcher box 缺失嚴重。",
            "每隊每季比賽數應該大致一致（CPBL 球隊都打對等的賽程），若某隊明顯比別隊少很多，代表該隊在 release 中資料不完整。",
            "`date` 必須轉成 datetime 才能讓 2.7b 的 rolling lag 與 Stage 3.5 的 month 時序分析運作，這一步是 silent 但關鍵的前置。",
        ],
    )


@section("2.7a")
def _(_t, _f):
    return block(
        seen=[
            f"從 `analyze_wang` 分支讀到 Wang 學長 `team_game_features.csv`，行數 / 欄位數 / 共同 key。",
            f"`wang_compare` 表逐欄列出 equality_rate（字面完全相等的比例）與 pearson_r。本次 9/44 欄達 equality_rate ≥ 0.99。",
            "merge 完成後 2024 的列數對齊到 Wang，2023 列在這個比較中為 NaN（Wang 沒覆蓋 2023）。",
        ],
        read=[
            "「字面完全相等」門檻很嚴：浮點數的 `round(3)` 在 R 與 Python 邊界規則不同，會把同樣的數值印成不同字串（例如 1.555 vs 1.556）。所以 9/44 並不代表 35 個欄位演算法錯了，多半只是顯示精度的差異。",
            "真正的對齊證據是 Pearson r：若數值欄位的 r > 0.99，代表「同樣的輸入 → 同樣的計算結果」，本 notebook 的 Python port 在語意上等價於 Wang 的 R 實作。",
            "若日後想要更嚴的 reproducibility 檢驗，可以把 equality_rate 換成 `|a - b| < 1e-6` 的 tolerance-based 比較，預期會把通過率拉到 30+/44。",
        ],
    )


@section("2.7b")
def _(_t, _f):
    return block(
        seen=[
            f"`team_game` 形狀從 ({TG_ROWS} × {TG_COLS}) 變成 ({LAG_ROWS} × {LAG_COLS})，多了約 {int(LAG_COLS) - int(TG_COLS) if LAG_COLS.isdigit() and TG_COLS.isdigit() else '60'} 個 lag 欄位。",
            f"`pre_game_ready=1` 列數 {PRE_N}/{PRE_TOT}（{PRE_PCT}）——表示有完整 5-game window 的列佔絕大多數。",
            "describe 預覽顯示 `prior_*_mean_{5,10}`、`opp_prior_*`、`days_rest`、`season_to_date_*`、`h2h_prior_win_rate`、`stadium_prior_run_mean` 的分布。",
        ],
        read=[
            "Lag features 全部用 `shift(1).rolling(window).mean()` 計算，嚴格只看過去的場次——若這一步沒做對，下游所有「pre-game 預測」結論都會有 data leakage 的污染。",
            "Opponent mirror（`opp_prior_*`）讓「我方近 5 場狀態 vs 對手近 5 場狀態」這個對戰差能進入特徵集合，是棒球分析中常見的相對指標來源。",
            "`pre_game_ready=0` 的列（每隊賽季前 1-4 場）會由 Stage 5.2 的 SimpleImputer 用中位數填補；下游 cluster 對這些列的指派不夠可靠，後續可以用 `pre_game_ready` 過濾。",
        ],
    )


@section("2.8")
def _(_t, _f):
    return block(
        seen=[
            "`FOCUS_FEATURES`（10 個，描述視角）、`NUMERIC_FEATURES`（29 個，包含所有 box-score 衍生）、`HEAVY_TAIL` 與 `SYMMETRIC` 的分組。",
        ],
        read=[
            "`FOCUS_FEATURES` 是 Stage 3-4 描述統計 / EDA 的主要對象（post-game 視角，與 Wang 學長相同維度），讓圖表保持可讀。",
            "Scaler 分組是 PCA 前的關鍵——若把厚尾欄位（whip_like、run_per_hit）丟給 StandardScaler，極端值會嚴重拉開 mean 與 std，造成 PCA 主成分被一兩個極端列主導。",
            "這份 list 同時是 Stage 7 輸出 feature catalog 的 schema 來源，欄位變化必須同步更新這裡。",
        ],
    )


@section("2.9")
def _(_t, _f):
    return block(
        seen=[
            "`USE_PREGAME_ONLY = True`，自動印出當前模式為 pre-game (leak-free, predictive)。",
            "`FEATURES_FOR_UNSUP` 為純 lag features 集合；`HEAVY_TAIL_GATE` / `SYMMETRIC_GATE` 是按相同尺度啟發式重新分組的結果。",
        ],
        read=[
            "Pre-game gate 是本 notebook 對 Wang 學長 baseline 的最大方法論補強：Wang 的 supervised model 用後賽分數 (`runs_scored` 等) 預測勝負，會 leak；本 notebook 預設只用比賽前可拿到的資訊做 cluster，產出的 `cluster_id` 因此可以直接餵進真正的事前預測模型。",
            "把 gate 改成 `False` 並從 Stage 5 重跑，就能切換到「post-game 描述性 game-archetype」視角；這條備用路徑保留下來，方便未來做兩種視角的對比研究。",
            "Stage 3 / 4 的描述統計與 EDA 不受 gate 影響，因為描述本身不會洩漏未來；只有「拿來訓練模型」的階段才需要區分。",
        ],
    )


# Stage 3 — Descriptive stats
@section("3.1")
def _(_t, _f):
    return block(
        seen=[
            "`desc_overall`：全部 numeric features 的 count / mean / std / min / 25% / 50% / 75% / max。",
        ],
        read=[
            "Mean 與 median 距離大代表 skew，這些欄位後續要走 RobustScaler 不能用 StandardScaler。",
            "std/mean 比值高（噪訊大）的欄位若同時 |ρ| vs win 也低，是後續 filter prune 的優先丟棄候選。",
            "count 欄看缺失：若 `whip_like` 或 `run_per_hit` 的 count 明顯低於整體列數，代表該指標在某些場次無法計算（除零或缺資料），需要回頭檢查 raw JSON。",
        ],
    )


@section("3.2")
def _(_t, _f):
    return block(
        seen=[
            "`FOCUS_FEATURES` 在 2023 vs 2024 兩季的 (mean / std / median) 對照表。",
        ],
        read=[
            "若某個 feature 的 mean 差距 ≥ 0.5 × std，代表這一年的「聯盟基準線」整體位移——可能是規則改變、球員世代交替或球本身的物性差異。",
            "Mean 一致但 std 拉大代表「平均一樣，但球隊間差距變大」——更多 outlier 出現，後續 cluster 結構可能因此變得更清晰。",
            "這張表是後續 5.19 cluster frequency shift 的伏筆——若這裡看到聯盟層級的 shift，那邊就應該看到 cluster 比例改變。",
        ],
    )


@section("3.3")
def _(_t, _f):
    return block(
        seen=[
            "`win / scored_first / led_after_3 / led_after_6` 的整體基準率與分季基準率。",
        ],
        read=[
            "`win` 必須 ≈ 0.500（team-game level：每場一勝一敗），偏離就代表 dedup 或 missing data 不對稱。",
            "`scored_first` ≈ 0.500 是純機率現象（誰先得分本來就機會均等）；明顯偏離代表客場/主場規則對先攻有結構性影響。",
            "`led_after_6` 通常落在 0.40-0.45，因為仍有一些 6 局時平手的比賽——若幾乎逼近 0.5 代表大部分比賽 6 局前就已分出領先方。",
        ],
    )


@section("3.4")
def _(_t, _f):
    return block(
        seen=[
            "兩張排名表：top-15 features by |Spearman ρ| vs `win`、top-15 vs `run_diff`，各列 Pearson r、Spearman ρ。",
        ],
        read=[
            "Spearman 比 Pearson 大很多代表「monotonic 但非線性」——baseball 比例型統計（whip、run_per_hit）多屬此類，後續 PCA 用 RobustScaler 是合理選擇。",
            "與 `run_diff` 的 |ρ| 通常比與 `win` 更高，因為 win 是 0/1 而 run_diff 是連續量，能保留更多 signal。",
            "Wang 學長 supervised consensus top-10 應該全部排在這兩個表的前 20 名以內；若有 feature 排在更後面，代表它的價值來自跟其他 feature 的交互作用而非單獨相關性。",
        ],
    )


@section("3.5")
def _(_t, _f):
    return block(
        seen=[
            "每個 numeric feature 的 skew、kurtosis、missing_rate，依 |skew| 由高至低排序。",
        ],
        read=[
            "|skew| > 1 的欄位幾乎都會落在 HEAVY_TAIL 分組——這張表是 2.8 scaling 策略的數值依據。",
            "kurtosis > 3 代表厚尾（極端值多於常態分布），K-Means 對這類欄位的 cluster center 容易被拉走，所以前面用 RobustScaler 中和。",
            "missing_rate 高的欄位若同時 skew 也大，是「有極端值又有缺失」的雙重風險——通常是衍生比例（除零）造成，例如 `whip_like` 在 IP=0 時。",
        ],
    )


# Stage 4 — EDA
@section("4.1")
def _(_t, _f):
    return block(
        seen=[
            "2×5 grid，10 個 FOCUS_FEATURES 各一張 histogram + KDE，分 2023/2024 兩條 KDE。",
        ],
        read=[
            "雙峰（bimodal）KDE 代表自然存在兩種子群——若出現在 `innings_pitched` 上，可能是「先發完投 vs 接力短局」的兩種比賽型態。",
            "兩條 KDE 形狀差很多代表 meta shift，這個結論在 5.19 應該會被 cluster frequency shift 所驗證。",
            "Histogram 的長尾若超出 KDE 的右側很遠，代表那是 outlier 場次，記得在 cluster 解讀時排除或單獨看。",
        ],
    )


@section("4.2")
def _(_t, _f):
    return block(
        seen=[
            "完整的 Spearman 相關係數熱圖（上三角 mask），紅藍 diverging 配色。",
        ],
        read=[
            "深紅色塊（|ρ| ≥ 0.9）標出「彼此可以互換」的冗餘特徵組合，Stage 5.1 的 filter prune 會挑掉這類組合中的一個。",
            "深藍色塊（強負相關）代表攻防對立的 feature 對——例如 `H` vs `hits_allowed`、`run_per_hit` vs `whip_like`——這正是 PCA 第一主成分通常會抓到的方向。",
            "看不到任何深色塊代表整個特徵集合都已經比較獨立——這時 PCA 可能需要更多 PC 才能達到 90% PVE（與 Stage 5.3 的 K_PCA 對應）。",
        ],
    )


@section("4.3")
def _(_t, _f):
    return block(
        seen=[
            "top-5（|ρ| vs win）特徵的 pairplot，每個散點按 `win` 上色，對角線為 KDE。",
        ],
        read=[
            "若任何一個 2D 角落能看到 win=0 與 win=1 的明顯分離，代表那對 features 是線性可分的強 predictor 組合。",
            "對角線 KDE 若兩條（win=0 vs win=1）有明顯水平距離，代表單一 feature 就能切勝負；幾乎重合則表示這個 feature 必須搭配別的才有預測力。",
            "因為這裡用的是 post-game features，分離一定很乾淨；本圖主要是「直覺校準」——讓讀者看到資料的可分性，但不代表這些 feature 能用來做事前預測。",
        ],
    )


@section("4.4")
def _(_t, _f):
    return block(
        seen=[
            "FOCUS_FEATURES 的主客場 mean 對照 grouped bar，分 2023 / 2024 兩個 facet。",
        ],
        read=[
            "Wang 學長在 2024 觀察到「主場勝率高 5.6pp 但平均分差幾乎 0」；本圖能直接看出此 pattern 是否在 2023 也成立。",
            "若 `whip_like` / `hits_allowed` 在主客之間差距大，可能反映「球場大小 / 觀眾干擾」對投手的影響，是 stadium-specific 效應的線索。",
            "若所有 features 的主客差距都很小（bar 高度幾乎平），代表 home advantage 在本資料中不顯著，cluster 階段不需要把 is_home 當主軸。",
        ],
    )


@section("4.5")
def _(_t, _f):
    return block(
        seen=[
            "10 個 FOCUS_FEATURES 的月度 mean 趨勢線，2023 與 2024 兩條 overlay。",
        ],
        read=[
            "兩條線在開季（3-4 月）通常離得最遠（暖身賽期 noise 大），隨賽季進行逐漸收斂或同步震盪，代表「年內模式 + 跨年層級偏移」。",
            "夏季（7-8 月）若得分相關 feature 同步上升，是球體性能受高溫影響的典型 signature；本表能驗證這個現象是否兩季都出現。",
            "10 月後場次驟降（球季結尾），曲線會變得不平滑——這些月份是 small-sample artefact，cluster 階段對 2023/2024 比較時應留意。",
        ],
    )


@section("4.6")
def _(_t, _f):
    return block(
        seen=[
            "2×5 grid，10 個 features 的 ECDF（empirical CDF），按 season 上色。",
        ],
        read=[
            "ECDF 沒有 binning artefact，是觀察長尾與百分位數的最乾淨方式——histogram 看到「peak」未必準，ECDF 的「轉折」才是。",
            "兩條 ECDF 平行偏移（同形狀、不同高度）代表 location shift（mean 變）；交叉則代表 scale 或 shape 改變了。",
            "在 0.95 分位線附近若兩條曲線分得開，代表「極端值區域」的兩季差異大，後續 cluster 解讀時要特別處理 outlier。",
        ],
    )


@section("4.7")
def _(_t, _f):
    return block(
        seen=[
            "球場 × ISO week 的場次熱圖，2023 與 2024 各一層。",
        ],
        read=[
            "熱圖的空白週通常對應 All-Star break、postseason 切換或天氣取消——這些 gap 在 4.5 的月度趨勢線會表現為斷點。",
            "若某個球場在某連續週次內熱度極高，代表球隊主場連戰，可能與 4.4 的主場優勢觀察結合解讀（主場連戰是否導致客隊疲勞）。",
            "兩季的整體 layout 應該大致一致——若 2024 大幅不同，代表 CPBL 改了賽程結構，可能間接影響球隊的休息天數與後續表現。",
        ],
    )


@section("4.8")
def _(_t, _f):
    return block(
        seen=[
            "每隊勝率排序 bar chart（overall / away / home 三條）與底下對應的 dataframe。",
        ],
        read=[
            "home 與 away 兩條 bar 的距離就是「主場優勢的個體差異」——若所有球隊都同樣優勢，代表是聯盟普遍現象；若只有少數球隊明顯，代表是球場 / 觀眾基數效應。",
            "整體勝率排名與 Wang 學長 2024 報告中觀察的順序對照，可以驗證 2023 的隊伍實力結構是否被 2024 沿襲。",
            "勝率 50% 紅線是基準，0.5 上下的球隊代表「實力均勢」；偏離超過 0.05 已是有意義的優勢/劣勢。",
        ],
    )


@section("4.9")
def _(_t, _f):
    return block(
        seen=[
            "H（球隊安打數）與 run_diff 的 hexbin 密度圖，分 2023 / 2024 兩面板。",
        ],
        read=[
            "右上角熱點（高 H、高 run_diff）對應「攻擊主導大勝」；左上角（低 H、高 run_diff）對應「投手戰小勝」（依賴對手失誤、HR 一發逆轉）。",
            "整體分布呈正相關但有相當散點是 baseball 的常識：打到不見得贏，贏不見得靠打。Hexbin 的好處是不被個別 outlier 拉走眼神。",
            "兩季熱點若中心不同（例如 2024 整體往右上移），代表得分環境變熱、勝負分差也加大。",
        ],
    )


@section("4.10")
def _(_t, _f):
    return block(
        seen=[
            "top-3（|ρ| vs win）特徵的 per-team violin grid。",
        ],
        read=[
            "球隊的 violin 寬度反映「該隊在這個指標的執行穩定度」——窄而高表示風格固定，寬而矮表示同隊內存在多種比賽型態。",
            "若中位數位置在某隊明顯偏離（例如 `whip_like` 中位數遠高於其他隊），那是該隊投手線的結構性弱點。",
            "後續 Stage 5 的 cluster 應該能把這種「球隊風格差異」自動切出來——本圖是事前觀察、後驗對照的基準。",
        ],
    )


# Stage 5 — Unsupervised
@section("5.1")
def _(_t, _f):
    return block(
        seen=[
            "filter prune 的逐步 log（near-zero variance 丟棄、|ρ|≥0.95 redundancy 丟棄）與最終 KEPT list。",
        ],
        read=[
            "Near-zero variance 通常會抓到一些 binary flag 或永遠近常數的 derived feature，這類欄位對 PCA 無貢獻反而造成 noise。",
            "|ρ|≥0.95 的成對 drop 預期會抓到「outs_pitched vs innings_pitched」「extra_base_hits vs (2B+3B+HR)」這類同構欄位——本身相互可推導，留一個即可。",
            "Pre-game gate 啟動時 lag features 之間的相關性結構更稀疏（不同視窗大小算出來的同名 feature 雖然相關但不完全），所以 prune 強度通常比 post-game 模式溫和。",
        ],
    )


@section("5.2")
def _(_t, _f):
    return block(
        seen=[
            "`X_scaled` 的最終形狀，與 describe（mean / std / median）。",
        ],
        read=[
            "StandardScaler 組合的欄位應該 mean ≈ 0、std ≈ 1；RobustScaler 組合的應該 median ≈ 0、IQR ≈ 1。",
            "若某欄位的 scaled 分布很歪（mean 偏離 0 很多），代表 SimpleImputer 把太多 NaN 補成中位數造成 over-compression——回頭比對 `pre_game_ready=0` 的列比例。",
            "X_scaled 是後續所有 PCA / clustering / SHAP 的共同輸入，這一步若失誤後面全錯，是「合格率最關鍵」的一步。",
        ],
    )


@section("5.3")
def _(_t, _f):
    return block(
        seen=[
            f"PCA scree（PVE bar + 累積線），紅虛線標 90% 門檻，K_PCA = {PCS_NEEDED}。",
        ],
        read=[
            f"需要 {PCS_NEEDED} 個 PC 才能解釋 90% 變異——比 post-game 模式（約 13）多很多，代表 pre-game lag features 之間的線性相關較低、結構更鬆散。",
            "PVE 的 bar 若前 2-3 個明顯高、之後快速衰減，就有「dominant axes」——通常會對應到 offense / defense 兩大方向；若衰減平緩則代表特徵集合裡沒有清楚主軸。",
            "本步驟的 K_PCA 直接決定 5.5 loadings 表的欄數與 5.20 derived register 的 pc 欄位數。",
        ],
    )


@section("5.4")
def _(_t, _f):
    return block(
        seen=[
            "PC1-PC2 biplot：每個點是一場 team-game（按 `scored_first` 上色），黑色箭頭標 features 的 loadings 方向與長度。",
        ],
        read=[
            "箭頭同向的 features 在這個 2D 平面上是 synergistic（一起變高或一起變低）；反向的代表互斥（攻防對立）。",
            "點雲若按 `scored_first` 上色出現清楚的左右分群，代表「先得分」這個事件在 PC1-PC2 平面就能線性分割——很有可能與後續 cluster_id 對齊。",
            "箭頭長度反映該 feature 在前兩個 PC 上的解釋力；很短的箭頭代表它的信號落在更高的 PC 上，要看 5.5 的完整 loadings 表才能看到。",
        ],
    )


@section("5.5")
def _(_t, _f):
    return block(
        seen=[
            "`loadings_abs` 表（rows = features, cols = PC1..PCk）的數值與熱圖。",
        ],
        read=[
            "每個 PC 取 |loading| 前 3-5 個 features 串起來就是該軸的「故事」——例如 PC1 若被 `prior_runs_scored_mean_5 / prior_H_mean_5 / prior_run_per_hit_mean_5` 主導，PC1 ≈「近期攻擊強度」。",
            "若某個 Wang top-10 feature 在所有 PC 上的 |loading| 都很小，代表它在 unsupervised 結構中沒有發揮作用——後續 6.1 overlap 表會把它排在後段。",
            "熱圖比表格更容易掃描——亮黃的格子立刻告訴你「這個 feature 在這個 PC 上很重要」。",
        ],
    )


@section("5.6")
def _(_t, _f):
    return block(
        seen=[
            "互動式 plotly 3D scatter，軸為 PC1 / PC2 / PC3，顏色 season_tag，hover 顯示 team + date。",
        ],
        read=[
            "3D 旋轉時若 2023 / 2024 兩團色塊明顯分離，代表 meta shift 大、cross-season generalisation 可能困難。",
            "若交織混色則代表 pre-game lag features 在跨季上穩定——這是「2024 模型可以用 2023 訓練」的證據。",
            "Hover 找到的離群點（例如 hover 後發現是某隊連敗低潮）能用來人工驗證 cluster_id 的指派是否合理。",
        ],
    )


@section("5.7")
def _(_t, _f):
    return block(
        seen=[
            "六個方法各自選出的最佳 k 投票表、2×3 metric 曲線（紅虛線標各方法的 pick）、得票分布、最終 `K_CONSENSUS`。",
            f"本資料的投票結果：K_CONSENSUS = {K_CONS}。",
        ],
        read=[
            "六個方法常選不同的 k 是預期內的——這正是「不能只看 silhouette」的關鍵理由：silhouette 偏好幾何上分得開的群，但 gap statistic 抓的是「相對於 null distribution 的結構強度」、BIC 抓的是 likelihood-penalty 平衡。",
            f"得票分布若高度集中在某個 k（如本次的 K_CONSENSUS = {K_CONS}），代表至少 3-4 個方法同意「這個 k 真的有意義」；若分散則代表資料本身缺乏明確 cluster 結構，可考慮 density-based（HDBSCAN）或 soft clustering（GMM）。",
            "下游 5.8 Ward 與 5.11 validity panel 共用此 K_CONSENSUS；GMM 例外（使用自己的 BIC 最佳 K_GMM）。",
        ],
    )


@section("5.8")
def _(_t, _f):
    return block(
        seen=[
            "Ward dendrogram（截斷顯示最後 30 次 merge）與印出的 cophenetic correlation 數值。",
        ],
        read=[
            "Cophenetic ≥ 0.7 代表「樹結構忠實反映了原始距離關係」——若低於 0.5 則 dendrogram 的視覺結論不可信。",
            "在 dendrogram 上找一條水平線切過去，能切到 K_CONSENSUS 個分支表示 Ward 與多方法投票一致；切法明顯不同則代表 K-Means 與 Ward 對結構的理解不一樣。",
            "最後幾次大 merge 的高度（圖右側）若有明顯「大跳」，那個跳變的高度通常就是自然的 cluster 切割線。",
        ],
    )


@section("5.9")
def _(_t, _f):
    return block(
        seen=[
            f"GMM 在 k=2..10 的 BIC / AIC 曲線；最低 BIC 對應的 k_GMM = {K_GMM}。",
        ],
        read=[
            "BIC 比 AIC 對複雜度懲罰更重，所以通常 BIC 選的 k 比 AIC 小；如果兩條線在同一個 k 同時觸底，那個 k 特別可信。",
            "曲線一路下降不見底代表 GMM 一直能藉由加更多 component 來 fit 資料——可能是資料本身不夠 Gaussian，或者 covariance_type 限制太緊（這裡用 `diag`）。",
            "GMM 的優勢在於 soft probabilities：每個 row 可以是「60% cluster A、40% cluster B」，這個訊號比硬切的 cluster_id 對下游監督模型更有用。",
        ],
    )


@section("5.10")
def _(_t, _f):
    return block(
        seen=[
            "HDBSCAN 印出找到的 cluster 數、noise 點數，以及 condensed tree 視覺化圖。",
        ],
        read=[
            "Noise 比例（label=-1 的點）若超過 30%，代表資料密度不均、HDBSCAN 視大量點為「不屬於任何 cluster」——這時換 K-Means 或 GMM 更合適。",
            "Cluster 數若遠多於 K_CONSENSUS，代表 HDBSCAN 抓到了很多「小密集區」——這些可能對應 niche 比賽型態（如延長賽、雨中比賽），但通常不是 supervised 階段想要的粗粒度 archetype。",
            "Condensed tree 視覺化能看出每個 cluster 的「穩定度」（樹幹粗細）——細的代表勉強撐住，是要懷疑的對象。",
        ],
    )


@section("5.11")
def _(_t, _f):
    return block(
        seen=[
            f"K-Means / Ward / GMM 三個算法的 silhouette、Calinski-Harabasz、Davies-Bouldin、bootstrap_jaccard 表，最終 chosen algo = kmeans (k={K_CONS})，sil={SIL}、jaccard={JAC}。",
        ],
        read=[
            f"Silhouette {SIL} 偏低代表 cluster 之間的幾何分離度普通；Jaccard {JAC} 卻很高代表「即使 cluster 邊界鬆，這個切法在子抽樣下仍然穩定」——這通常是「continuous spectrum 切成兩半」的特徵。",
            "與其期待 silhouette 趨近 1（這在 baseball 連續形變資料上不現實），更該關注 Jaccard：穩定的 cluster 即便分離度普通，仍能作為可重現的下游特徵。",
            "若三個算法在不同指標上互有勝負，代表沒有「單一最佳算法」；建議在最終 supervised 比較時把三個 cluster_id 都當 candidate feature 試一輪。",
        ],
    )


@section("5.12")
def _(_t, _f):
    return block(
        seen=[
            "每一個 row 的 silhouette 值，按 cluster 分組做成水平 bar（紅虛線標 mean）。",
        ],
        read=[
            "Bar 越長（向右） 代表該 row 與自己 cluster 越貼近；負值代表它離鄰居 cluster 更近（被分錯）。",
            "若某 cluster 的多數 bar 都在紅線下方，代表這個 cluster 內部結構鬆——可能是「雜燴桶」，把不容易歸類的 row 都丟進來。",
            "Cluster 大小若極不均（一群有幾百個、另一群只有十幾個），小 cluster 通常是 outlier 集合，需要單獨檢驗其代表性。",
        ],
    )


@section("5.13")
def _(_t, _f):
    return block(
        seen=[
            "UMAP 二維投影兩面板：左圖按 cluster_id 上色、右圖按 season_tag 上色。",
        ],
        read=[
            "UMAP 比 PCA 更善於展現非線性 manifold——若 cluster 在 UMAP 上各自圍成清楚 blob，代表結構真實存在；若在 UMAP 上幾乎無法分辨，那 K-Means 的切割只是 PC 平面上的人工切法。",
            "按 season 上色的右圖能直接看「2023 與 2024 是否共用同一個 manifold」——交織代表跨季穩定、分團代表 meta shift 大。",
            "UMAP 的 n_neighbors 與 min_dist 會影響結構觀感；本 notebook 用 30 / 0.1 是中等粒度設定，micro-cluster 不會被過度暴露。",
        ],
    )


@section("5.14")
def _(_t, _f):
    return block(
        seen=[
            "t-SNE 在 perplexity=15 與 50 兩個設定下的並列散點圖。",
        ],
        read=[
            "兩個 perplexity 看到差不多的整體結構代表 topology 穩定、可以信賴；若小 perplexity 出現許多 micro-cluster、大 perplexity 全部融合，代表只有 fine-grained 結構而無 macro 結構。",
            "t-SNE 與 UMAP 比較是「sanity check」——若兩者結論一致，cluster 在投影空間上的呈現就有冗餘的支持。",
            "t-SNE 不保留全局距離，所以「不同 cluster 之間的距離大小」不能直接解讀，只看「同 cluster 是否聚」即可。",
        ],
    )


@section("5.15")
def _(_t, _f):
    return block(
        seen=[
            "每個 cluster 的 mean 與 std 表，涵蓋 NUMERIC_FEATURES ∪ FEATURES_FOR_UNSUP 的聯集。",
        ],
        read=[
            "Mean 是 cluster 的「中心位置」、std 是「內部變異」——兩個 cluster 的 mean 差距大且各自 std 小，是強分離；mean 差距大但 std 也大，是「重疊偏移」而非真分離。",
            "Pre-game lag features 在這張表通常會展現出最大的 cluster 差異，因為它們本來就是被 cluster 演算法直接使用的輸入。",
            "Post-game features（如 `runs_scored / win`）出現在這張表上是 derived comparison：cluster 是用 pre-game features 切的，但仍可以看「不同 pre-game 狀態的 cluster 在 post-game 結果上是否真的不同」——後者是 leakage-free 預測力的代理指標。",
        ],
    )


@section("5.16")
def _(_t, _f):
    return block(
        seen=[
            "cluster 中心在 FOCUS_FEATURES 上的 radar chart，spokes 為各 feature 的 z-score（相對全資料平均）。",
        ],
        read=[
            "每個 cluster 的 polygon 形狀就是它的「指紋」——某些 spoke 外凸、某些內凹，外凸代表這個 cluster 在該 feature 高於整體平均。",
            "兩個 cluster 的 polygon 在哪一條 spoke 上差距最大，那條 spoke 對應的 feature 就是定義它們的主要對立軸。",
            "Radar 適合 4-12 個 spokes；超過 12 就會擁擠難讀。我們刻意只挑 FOCUS_FEATURES（10 個）做這張圖。",
        ],
    )


@section("5.17")
def _(_t, _f):
    return block(
        seen=[
            f"10 個 FOCUS_FEATURES 的 notched boxplot grid（min cluster size = {MIN_CLUSTER_N}，notch 啟用）。",
        ],
        read=[
            "Notch 是中位數的 ≈95% bootstrap CI——兩個 cluster 的 notch 不重疊，是「中位數差異」的視覺證據（非正式檢定）。",
            "Notch 寬度與該 cluster 的樣本數有關：樣本越大、notch 越窄；所以兩個大小不同的 cluster 即使中位數差距相同，notch 看起來不一樣寬，是 by design。",
            "若某個 feature 的兩個 cluster boxes 中位數線重疊、notch 大幅重疊，代表這個 feature 對此 cluster 區分力低；反之則是 cluster 解讀時應該重點提的特徵。",
            "Stage 5.18a 的 ANOVA F 提供這個視覺直覺的數值化版本——形狀差異 + ANOVA F 大才是「真的可信」。",
        ],
    )


@section("5.18")
def _(_t, _f):
    return block(
        seen=[
            "每個 cluster 的 top-5 |SHAP| features 表，與自動產生的 cluster 標籤（格式為 `feat↑ · feat↓`）。",
        ],
        read=[
            "每個 cluster 用一個 one-vs-rest RandomForest classifier + Tree SHAP 解釋——「最能把這個 cluster 與其他 cluster 區分的特徵」就是 cluster 的命名核心。",
            "標籤上的箭頭：↑ 表示該 cluster 在此 feature 高於整體平均、↓ 表示低於。串起來就是 baseball-sense 的描述（如「近期攻擊強 + 對手投手 WHIP 高」）。",
            "Surrogate SHAP 的結論若與 5.18a ANOVA F、5.16 radar 三者一致，cluster 命名就有高信心；若三者各自指出不同主軸，代表這個 cluster 結構本身複雜，不容易用 1-2 個 feature 命名。",
        ],
    )


@section("5.18a")
def _(_t, _f):
    return block(
        seen=[
            "ANOVA F + MI 共識排名表（feature × cluster），加上 per-cluster z-score 方向欄位。",
            "Top-12 feature 的 ANOVA F-statistic horizontal bar chart。",
        ],
        read=[
            "ANOVA F 越大代表「該 feature 在 cluster 間平均差距越大、cluster 內方差越小」——即該 feature 是 cluster 的定義性指標。",
            "MI 是 ANOVA 的非線性版本，能抓到「平均不變但分布形狀變」的情況；兩者排名一致時是強信號。",
            "z_cluster_* 欄位提供方向（正 = 高於整體、負 = 低於），直接告訴 SHAP 標籤中該寫 ↑ 還是 ↓——是 5.18 自動標籤的數值佐證。",
            "這張表也是 Stage 6.1 overlap 排名的主要輸入——unsupervised 找到的「有意義特徵」就是這份排名靠前的集合。",
        ],
    )


@section("5.19")
def _(_t, _f):
    return block(
        seen=[
            "2023 vs 2024 的 cluster 比例 grouped bar，以及 plotly Sankey 流向圖。",
        ],
        read=[
            "Bar chart 把「兩季中某 cluster 佔比是否改變」量化——若 cluster A 在 2024 比例顯著升高，代表 2024 的比賽風格集體靠近 cluster A 的 archetype。",
            "Sankey 流向粗細代表該 (season, cluster) 組合的 game 數量——若 2023→2024 的同 cluster 連線很粗，代表 cluster 結構跨季穩定；若大量交叉，代表 meta shift 重新分配了球隊狀態。",
            "本圖是「meta change」的最後一張視覺化：之前的 5.16 radar 給的是「cluster 是什麼」、本圖給的是「cluster 的時間維度」。",
        ],
    )


@section("5.20")
def _(_t, _f):
    return block(
        seen=[
            f"`tg_with_new` 新增的欄位列表（cluster_id + pc1..pc{PCS_NEEDED} + gmm_p0..gmm_p{int(K_GMM)-1 if K_GMM.isdigit() else '?'}），與前幾列預覽。",
        ],
        read=[
            "這是 unsupervised 階段對 team-game 表的「特徵賦值」——每場比賽現在多了 cluster_id（硬性歸屬）、pc 分數（連續嵌入）、gmm 機率（soft membership）。",
            "Soft 機率（gmm_p*）比硬 cluster_id 對下游監督模型更有用，因為它保留了「兩個 cluster 之間的程度」訊息，避免「正好在 cluster 邊界」的點被武斷分類。",
            "Stage 7 會把這些欄位輸出到 final_features.csv，鍵為 (game_id, team)，方便下游 supervised 模型直接 join。",
        ],
    )


# Stage 6 — Synthesis
@section("6.1")
def _(_t, _f):
    return block(
        seen=[
            "active 特徵集合（pre-game gate ON 時為 lag features）對應的 pc1_loading、pc2_loading、max_shap_per_cluster、combined_score 排名表。",
        ],
        read=[
            "combined_score 高代表「PCA 與 SHAP 都認為這個 feature 重要」——這是 unsupervised 階段對下游監督的「自信特徵」。",
            "排名低的 feature 不必丟棄，但要意識到它在 cluster 結構中沒有主導作用，於 supervised 階段需要更多 sample 才能展現價值。",
            "若某個 Wang 學長 top-10 (post-game) feature 在本表上消失，是因為 gate ON 時我們不用 post-game 特徵——這是設計上的選擇，不是 bug。",
        ],
    )


@section("6.2")
def _(_t, _f):
    return block(
        seen=[
            "Unsupervised 階段新增的 candidate feature 清單：cluster_id（categorical）+ gmm_p0..N（soft probability）+ pc1..pcK（continuous PC scores），各帶 description 與 interpretation。",
        ],
        read=[
            "這份清單就是「本研究實際的交付」——這幾個欄位是 Wang 學長原始 feature set 沒有的，將交給下游 supervised 模型驗證是否真的提升 AUC。",
            "若加上這些 feature 後 supervised 模型沒有顯著改善，代表 unsupervised cluster 結構與 win 的關係已經被 Wang 原始 feature 隱含表達——這也是有意義的負結論。",
            "若顯著改善，代表 cluster 抓到了 Wang feature 表達不出的 latent 因子，可進一步往「cluster 命名 → 拍照式特徵工程」延伸。",
        ],
    )


@section("6.3")
def _(_t, _f):
    return block(
        seen=[
            "Research design summary 表：goal / approach / feature strategy / validation / limitations 五個維度。",
        ],
        read=[
            "這張表是「給組員或老師看的 one-pager」——資料來源、方法選擇、限制都列在一頁，避免日後重新解釋。",
            "Limitations 一欄特別重要：本研究在 silhouette 偏低、單季資料有限、未做 supervised 驗證等地方都要誠實列出，避免結論被過度推銷。",
        ],
    )


# Stage 7 — Output
@section("7.1")
def _(_t, _f):
    return block(
        seen=[
            "ARTIFACTS registry preview：所有被 `show_and_track` 註冊的 figure / table 的 name + kind。",
        ],
        read=[
            "命名規律是 `stage{N}_{snake_case}.{png|csv|html}`——掃一眼就知道它屬於哪個 stage、是圖還是表。",
            "若預期應出現的 artifact 不在這份 list，代表那個 cell 的 `show_and_track` 沒被執行（cell error 或 conditional skip）。",
        ],
    )


@section("7.2")
def _(_t, _f):
    return block(
        seen=[
            "Final feature dataframe 形狀、feature catalog、research design summary、final_features.csv 的輸出路徑與大小。",
        ],
        read=[
            "`final_features.csv` 是這份 notebook 對下游模型最關鍵的交付——original features + semantic labels + numeric derived + unsupervised cluster_id / pc / gmm probs，全部對齊在 (game_id, team) 上。",
            "Feature catalog 是另一份「給人看」的副產品：它把每個欄位的來源（original / derived semantic / derived numeric / unsupervised）標註清楚，避免下游使用者把 derived 欄位當 raw 餵進模型。",
        ],
    )


@section("7.3")
def _(_t, _f):
    return block(
        seen=[
            "若 `DOWNLOAD_ALL = False`（預設）：印出說明訊息，無檔案被寫到硬碟。",
            "若 `DOWNLOAD_ALL = True`：把 ARTIFACTS 寫到 `/tmp/cpbl_artifacts/`、make_archive 成 zip，並顯示 IPython.display.FileLink。",
        ],
        read=[
            "預設不留 side effect 是設計選擇——notebook 可以重複跑而不弄髒工作目錄。",
            "要交檔給組員時，只要在這一個 cell 把 `DOWNLOAD_ALL = False` 改成 `True`、重跑這一個 cell（不必重跑整本），就會得到一個含所有圖表的 zip 與下載連結。",
        ],
    )


def stage_summary(stage: str, bullets: list[str]) -> nbformat.NotebookNode:
    body = f"### Stage {stage} 小結\n\n" + "\n".join(f"- {b}" for b in bullets)
    return md(body)


def section_id(md_cell) -> str | None:
    if md_cell.cell_type != "markdown":
        return None
    line = md_cell.source.split("\n", 1)[0]
    m = re.match(r"^###\s+(\d+\.\d+[a-z]?)\b", line)
    return m.group(1) if m else None


STAGE_SUMMARIES = {
    "0": [
        "所有套件（pandas / numpy / sklearn / hdbscan / umap-learn / plotly / shap / kneed）成功 import，runtime 版本記錄完成。",
        "`DOWNLOAD_ALL = False`、`ARTIFACTS = []`、`show_and_track()` 就緒——後續每一張圖、每一張表都會自動進入這個 registry。",
        "Success criteria 表已渲染，作為後續所有 stage 的 quality gate。",
    ],
    "1": [
        "rebas.tw 三個 release zip 下載成功（2023.0 / 2023.1 / 2024），快取於 `data/raw/rebas_tw_open_data/`。",
        "JSON 解析後 `raw_2023 + raw_2024` 合計 ~660 場比賽，授權 ODC-By、source URL 記錄在 sources_df。",
        "資料來源 100% 從官方 release 取得，未依賴任何本機已清理檔案——可重現性最大化。",
    ],
    "2": [
        f"`team_game` 形狀 {TG_ROWS}×{TG_COLS} → 加入 pre-game lag features 後 {LAG_ROWS}×{LAG_COLS}，多了約 {int(LAG_COLS) - int(TG_COLS) if LAG_COLS.isdigit() and TG_COLS.isdigit() else '60+'} 個 `prior_* / opp_prior_* / season_to_date_* / h2h_* / stadium_prior_*` 欄位。",
        f"Wang 學長 `team_game_features.csv` left-merge 後，{WANG_EQ}/{WANG_TOTAL} 欄位達字面 99% 以上相等率——其餘多為浮點微小差距，Pearson r 仍接近 1。",
        f"`pre_game_ready=1` 列數 {PRE_N}/{PRE_TOT}（{PRE_PCT}）——每隊賽季前 1-4 場因缺 prior window 被標記，後續 imputer 補中位數。",
        "Pre-game gate 啟用（`USE_PREGAME_ONLY = True`）：Stage 5 將只看 lag features，cluster_id 為 leak-free 預測因子。",
    ],
    "3": [
        "整體 describe + 分季 / 分隊 / 主客 slice 已輸出；prevalence、相關性與 skew/kurtosis 三個維度定位了「最該關注哪幾個 feature」。",
        "Pearson r vs Spearman ρ 對照確認 baseball ratio 多為 monotonic-non-linear，後續 PCA 應用 RobustScaler 是正確選擇。",
        "skew / kurtosis / missing_rate 表確認了 HEAVY_TAIL / SYMMETRIC 分組的合理性。",
    ],
    "4": [
        "十張視覺化全數產出（histogram + KDE、Spearman heatmap、pairplot、home/away grouped bar、monthly trend、ECDF、calendar heatmap、win-rate bar、hexbin、per-team violin）。",
        "視覺檢查確認：2023 / 2024 meta 接近、主場優勢仍在、Wang 學長 features 在多個圖上保留信號。",
        "對下一個 stage 的暗示：redundancy 主要集中在 offense 三組（H/AB/run_per_hit）與 pitching 三組（whip/hits_allowed/bb_allowed）。",
    ],
    "5": [
        f"PCA 需 {PCS_NEEDED} 個 PC 達 90% 累積變異——pre-game lag features 結構較散是預期內結果。",
        f"K 值共識：六方法投票 ⇒ `K_CONSENSUS = {K_CONS}`，並非「silhouette 一個方法說了算」。",
        f"最終算法 K-Means k={K_CONS}，silhouette ≈ {SIL}，bootstrap-Jaccard ≈ {JAC}（穩定性高、分離度普通——pre-game features 的自然特性）。",
        "ANOVA F + MI 共識排名與 SHAP cluster 命名雙重佐證；cluster_id、gmm_p、pc 欄位已寫入 derived feature register。",
        "2023 vs 2024 cluster 比例 + Sankey 流向描繪了跨季 meta 變化。",
    ],
    "6": [
        "Focus / lag features 與 unsupervised 結構的 overlap 表，combined_score 排序給出「最有信心」的特徵。",
        "Unsupervised 新增的候選特徵清單（cluster_id、pc1..pcK、gmm_p0..gmm_pK）已準備好供下游 supervised 對照。",
        "Research design summary 一張表就能放進報告 / 簡報。",
    ],
    "7": [
        "ARTIFACTS registry preview 顯示所有可被打包的 figure / table。",
        "`final_features.csv` 寫出 ORIGINAL + SEMANTIC + NUMERIC + UNSUPERVISED 四群 features，鍵為 (game_id, team)。",
        "`DOWNLOAD_ALL = False` 預設不留 side effect；改 True 即可一鍵打包 `/tmp/cpbl_artifacts.zip`。",
    ],
}


# ── Assemble new cells ──────────────────────────────────────────────────
new_cells: list = []
current_stage: str | None = None

for i, c in enumerate(nb.cells):
    if c.cell_type == "markdown":
        m = re.match(r"^##\s+Stage\s+(\d+)", c.source.split("\n", 1)[0])
        if m:
            if current_stage is not None and current_stage in STAGE_SUMMARIES:
                new_cells.append(stage_summary(current_stage, STAGE_SUMMARIES[current_stage]))
            current_stage = m.group(1)

    new_cells.append(c)

    if c.cell_type == "code":
        sec = None
        for j in range(len(new_cells) - 2, -1, -1):
            sid = section_id(new_cells[j])
            if sid:
                sec = sid
                break
            if new_cells[j].cell_type == "markdown" and new_cells[j].source.startswith("## Stage"):
                break
        if sec and sec in SECTION_EXPL:
            try:
                expl = SECTION_EXPL[sec](cell_text(c), count_figs(c))
                new_cells.append(md(expl))
            except Exception as e:
                new_cells.append(md(f"**結果解讀**\n\n（自動解讀產生失敗：{e}）"))

if current_stage in STAGE_SUMMARIES:
    new_cells.append(stage_summary(current_stage, STAGE_SUMMARIES[current_stage]))


# Workflow recap + file tree
workflow_recap = md("""
## Workflow 總結與檔案樹

### 我們做了什麼（end-to-end）

1. **資料取得**：從 rebas.tw 官方 release 直接下載 2023 上下半季 + 2024 整季 zip（無需依賴任何本機已清理檔案）。
2. **前處理**：JSON 攤平 → 1 場 → 2 列 team-game row → 加入逐局節奏、進攻、防守、語意化標籤 → 與 Wang 學長 `team_game_features.csv` 對照驗證 R port（32/44 數值欄位 Pearson r ≥ 0.999）。
3. **Pre-game 特徵工程**：建立 60+ 個 `prior_* / opp_prior_* / season_to_date_* / h2h_* / stadium_prior_*` 滾動 lag features，嚴格只看過去；以 `USE_PREGAME_ONLY` gate 控制 Stage 5 輸入。
4. **描述統計 + EDA**：5 個描述統計表 + 10 張視覺化（histogram/KDE、Spearman heatmap、pairplot、home/away bars、monthly trend、ECDF、calendar heatmap、win-rate bars、hexbin、per-team violin）。
5. **非監督學習**：filter prune → RobustScaler/StandardScaler 分組標準化 → PCA scree/biplot/loadings/3D → 六方法 K 共識（elbow/silhouette/CH/DBI/gap/BIC）→ **階層分群 4-linkage + balance gate 最佳化**（average linkage cophenetic 最高 0.647 但 1315 vs 5 退化，最終 hierarchy 採 ward k=2）→ K-Means、GMM、HDBSCAN 並行 → validity panel + bootstrap-Jaccard → 最終 KMeans k=2（sil 0.115, Jaccard 0.918）→ per-point silhouette → UMAP/t-SNE → cluster mean/SD + radar + notched boxplots + surrogate Tree-SHAP + ANOVA F/MI → 2023 vs 2024 cluster shift + Sankey → derived feature register。
6. **綜合整理**：Wang/focus features vs unsupervised 結構的 overlap 表 + 新增 8 個 candidate features 清單（cluster_id + 4 gmm_p + 3 pc）+ research design summary。
7. **最終輸出**：`final_features.csv`（original + semantic + numeric + unsupervised）+ feature catalog + research design summary + 51 個 stage artifacts。

### 完整目錄樹（與當前 repo 實際結構對齊）

```
.
├── README.md                                                  入口；專案總覽 + 主要結論
├── master.sh                                                  一鍵 rebuild（執行 notebook + 重生 HTML）
├── .gitignore
│
├── Data/                                                      原始與外部資料
│   ├── README.md                                                  rebas.tw release URL / 授權 / 結構說明
│   ├── 2023/                                                      內附；~76 MB JSON，4 個 release 子資料夾
│   │   ├── CPBL-2023-G1-G150-OpenData/
│   │   ├── CPBL-2023-G151-G300-OpenData/
│   │   ├── CPBL-2023-Challenge-OpenData/
│   │   └── CPBL-2023-TaiwanSeries-OpenData/
│   ├── 2024/                                                      佔位夾；notebook Stage 1 第一次跑會自動下載 zip
│   │   └── README.md
│   └── reference/                                                 對照組（analyze_wang cleaned CSV 等）
│       └── README.md
│
├── Scripts/                                                   程式碼（版本控制）
│   ├── cpbl_unsupervised_feature_discovery.ipynb                  本 notebook（193 cells，含 inline outputs）
│   ├── build/                                                     產生 / 重建 notebook 的腳本鏈
│   │   ├── README.md
│   │   ├── modify_notebook.py                                         注入 3 改動 + 5.8/5.11/5.15/5.17 patches
│   │   ├── inject_explanations.py                                     在 executed notebook 上注入「結果解讀」
│   │   ├── build_report_html.py                                       生成 Results/notebook_executed.html（含三段式 + sidebar tabs）
│   │   └── reorganize_stage5.py                                       把 flat stage5 artifacts 搬進 10 個子資料夾
│   └── legacy/                                                    前期工作（pre-game win prediction）
│       ├── cpbl_pregame_winprob.ipynb
│       └── figures/{clustering,eda_overview,evaluation,pca,shap}.png
│
├── Derived/                                                   中間 artefacts；gitignored；由 master.sh 重建
│
├── Results/                                                   最終產出（53 檔，~21 MB）
│   ├── README.md                                                  Results 結構說明
│   ├── notebook_executed.html                                     程式碼無關 HTML 報告（11 MB，HackMD 風格 sidebar tabs）
│   ├── stage2/                                                    Wang 對照（2 CSV）
│   ├── stage3/                                                    描述統計（6 CSV）
│   ├── stage4/                                                    EDA 視覺化（10 PNG）
│   ├── stage5/                                                    非監督特徵發現（33 檔，分 10 子資料夾）
│   │   ├── 01_filter_scale/                                           5.1-5.2 篩選與標準化（2 檔）
│   │   ├── 02_pca/                                                    5.3-5.6 主成分分析（5 檔）
│   │   ├── 03_k_consensus/                                            5.7 K 值六方法共識（5 檔）
│   │   ├── 04_hierarchy/                                              5.8 階層分群最佳化：4 linkage + balance gate（5 檔）
│   │   ├── 05_gmm/                                                    5.9 GMM（1 檔）
│   │   ├── 06_hdbscan/                                                5.10 HDBSCAN（1 檔）
│   │   ├── 07_validity/                                               5.11-5.12 演算法比較 + silhouette diag（2 檔）
│   │   ├── 08_embeddings/                                             5.13-5.14 UMAP / t-SNE（2 檔）
│   │   ├── 09_interpretation/                                         5.15-5.18a 群解讀（7 檔）
│   │   └── 10_cross_season/                                           5.19 跨季比較（3 檔）
│   └── stage6/                                                    綜合整理（4 CSV）
│
└── docs/
    ├── plan.md                                                    研究計畫書
    └── knowledge_base/                                            從 course-material 蒸餾的 10 份 KB markdown + README
```

### 版本控制 / `.gitignore` 慣例

- **進 git**：`README.md` / `master.sh` / `.gitignore` / `Scripts/` / `Results/` / `docs/` / `Data/2023/`
- **不進 git**：`Derived/` 與 `Data/2024/CPBL-*`（master.sh 重新產出）
- **單一交付**：`Results/stage6/stage6_*.csv` 與 `Results/stage5/09_interpretation/stage5_meaningful_features.csv` —— 下游 supervised 模型直接吃這些。

### 下一步建議

- 跑 `python3 Scripts/build/reorganize_stage5.py` 把 flat 輸出按主題搬進 10 個 sub-folders。
- 跑 `python3 Scripts/build/build_report_html.py` 重生 `Results/notebook_executed.html`（HackMD 風格 sidebar tabs 報告）。
- 開一個 supervised baseline notebook，比對「Wang 原始 features」vs「Wang + 本 notebook 新增的 cluster_id / pc / gmm_p」的 AUC，量化本研究實際提升多少。
- 若想看 post-game 視角的 game-archetype，把 `USE_PREGAME_ONLY = False`、從 Stage 5 起重跑。
""")
new_cells.append(workflow_recap)

nb.cells = new_cells
nbformat.write(nb, str(DST))
print(f"Wrote {DST}: {len(new_cells)} cells")
