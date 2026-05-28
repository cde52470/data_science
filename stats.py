import pandas as pd
from scipy.stats import fisher_exact
from pathlib import Path

CSV_PATH = Path(__file__).parent / "team_game_features.csv"
df = pd.read_csv(CSV_PATH)

RESULT_ORDER = ["大勝", "小勝", "平手", "小敗", "大敗"]
RESULT_COLORS = ["#1b5e20", "#66bb6a", "#bdbdbd", "#ef9a9a", "#b71c1c"]


def get_result_breakdown(home: str, opponent: str) -> dict:
    """主場球隊 vs 客場球隊的勝負結果分佈（大勝/小勝/平手/小敗/大敗）"""
    filtered = df[
        (df["team"] == home) &
        (df["is_home"] == True) &
        (df["opponent"] == opponent)
    ]
    counts = {label: 0 for label in RESULT_ORDER}
    for label, count in filtered["run_diff_label"].value_counts().items():
        if label in counts:
            counts[label] = int(count)
    return {
        "labels": RESULT_ORDER,
        "colors": RESULT_COLORS,
        "counts": [counts[l] for l in RESULT_ORDER],
    }


def get_win_rate(home: str, opponent: str) -> dict:
    """主場球隊對上客場球隊的勝率"""
    filtered = df[
        (df["team"] == home) &
        (df["is_home"] == True) &
        (df["opponent"] == opponent)
    ]
    if filtered.empty:
        return {"win_rate": "N/A", "win_record": "無對戰紀錄", "avg_run_diff": "N/A", "diff_range": ""}
    total = len(filtered)
    wins = int(filtered["win"].sum())
    avg_diff = filtered["run_diff"].mean()
    min_diff = int(filtered["run_diff"].min())
    max_diff = int(filtered["run_diff"].max())
    return {
        "win_rate": f"{wins / total:.1%}",
        "win_record": f"{wins} 勝 {total - wins} 敗（共 {total} 場）",
        "avg_run_diff": f"{avg_diff:+.1f}",
        "diff_range": f"最小 {min_diff:+d} / 最大 {max_diff:+d}",
    }


PHASE_MAP = {
    "early":  ("early_runs",  "1-3 局"),
    "middle": ("middle_runs", "4-6 局"),
    "late":   ("late_runs",   "7-9 局"),
}


def get_inning_stats(home: str, opponent: str) -> dict:
    """三個局段（1-3/4-6/7-9）有得分 vs 未得分的勝率"""
    base = df[
        (df["team"] == home) &
        (df["is_home"] == True) &
        (df["opponent"] == opponent)
    ]

    def phase_info(col: str, label: str) -> dict:
        if base.empty:
            return {"label": label, "scored": "N/A", "not_scored": "N/A",
                    "scored_games": 0, "not_scored_games": 0}
        s  = base[base[col] > 0]
        ns = base[base[col] == 0]

        def wr(sub):
            if sub.empty:
                return "N/A"
            return f"{int(sub['win'].sum()) / len(sub):.1%}"

        return {
            "label": label,
            "scored":           wr(s),
            "not_scored":       wr(ns),
            "scored_games":     len(s),
            "not_scored_games": len(ns),
        }

    return {
        "early":  phase_info("early_runs",  "1-3 局"),
        "middle": phase_info("middle_runs", "4-6 局"),
        "late":   phase_info("late_runs",   "7-9 局"),
    }


def get_team_inning_stats(home: str) -> dict:
    """主場球隊所有主場比賽的局段得分勝率（1-3 / 4-6 / 7-9 局）"""
    base = df[(df["team"] == home) & (df["is_home"] == True)]

    def phase_info(col: str, label: str) -> dict:
        if base.empty:
            return {"label": label, "scored": "N/A", "not_scored": "N/A",
                    "scored_games": 0, "not_scored_games": 0}
        s  = base[base[col] > 0]
        ns = base[base[col] == 0]
        def wr(sub):
            if sub.empty:
                return "N/A"
            return f"{int(sub['win'].sum()) / len(sub):.1%}"
        return {
            "label": label,
            "scored":           wr(s),
            "not_scored":       wr(ns),
            "scored_games":     len(s),
            "not_scored_games": len(ns),
        }

    return {
        "early":  phase_info("early_runs",  "1-3 局"),
        "middle": phase_info("middle_runs", "4-6 局"),
        "late":   phase_info("late_runs",   "7-9 局"),
    }


def get_scored_first_fisher(team: str) -> dict:
    """Fisher 精確檢定：先得分與勝負的關聯性（全部比賽）"""
    t = df[df["team"] == team]
    sf  = t[t["scored_first"] == True]
    nsf = t[t["scored_first"] == False]

    sf_w  = int((sf["win"]  == True).sum())
    sf_l  = int((sf["win"]  == False).sum())
    nsf_w = int((nsf["win"] == True).sum())
    nsf_l = int((nsf["win"] == False).sum())

    odds_ratio, p_value = fisher_exact([[sf_w, sf_l], [nsf_w, nsf_l]], alternative="two-sided")
    p_value    = float(p_value)
    odds_ratio = float(odds_ratio)

    sf_odds  = round(sf_w  / sf_l,  3) if sf_l  > 0 else float("inf")
    nsf_odds = round(nsf_w / nsf_l, 3) if nsf_l > 0 else float("inf")

    if p_value < 0.05:
        conclusion = "先得分顯著有利" if odds_ratio > 1 else "後得分顯著有利"
    else:
        conclusion = "先後得分與勝負無顯著差異"

    return {
        "table": {"sf_w": sf_w, "sf_l": sf_l, "nsf_w": nsf_w, "nsf_l": nsf_l},
        "sf_odds":  sf_odds,
        "nsf_odds": nsf_odds,
        "p_value":  round(p_value, 4),
        "significant": p_value < 0.05,
        "conclusion": conclusion,
    }


def get_fisher_result(team: str) -> dict:
    """Fisher 精確檢定：計算指定球隊主客場與勝負的關聯性"""
    team_df = df[df["team"] == team]
    home_df = team_df[team_df["is_home"] == True]
    away_df = team_df[team_df["is_home"] == False]

    hw = int((home_df["win"] == True).sum())
    hl = int((home_df["win"] == False).sum())
    aw = int((away_df["win"] == True).sum())
    al = int((away_df["win"] == False).sum())

    odds_ratio, p_value = fisher_exact([[hw, hl], [aw, al]], alternative="two-sided")
    p_value = float(p_value)
    odds_ratio = float(odds_ratio)

    if p_value < 0.05:
        conclusion = "主場顯著有利" if odds_ratio > 1 else "客場顯著有利"
    else:
        conclusion = "主客場無顯著差異"

    home_odds = round(hw / hl, 3) if hl > 0 else float("inf")
    away_odds = round(aw / al, 3) if al > 0 else float("inf")

    return {
        "table": {"hw": hw, "hl": hl, "aw": aw, "al": al},
        "home_odds": home_odds,
        "away_odds": away_odds,
        "odds_ratio": round(odds_ratio, 3),
        "p_value": round(p_value, 4),
        "significant": p_value < 0.05,
        "conclusion": conclusion,
    }
