import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import cross_val_score

PCA_PATH = Path(__file__).parent / "pca_scores.csv"
CSV_PATH = Path(__file__).parent / "team_game_features.csv"

PC_COLS  = ["Off_PC1", "Off_PC2", "Off_PC3", "Def_PC1", "Def_PC2", "Def_PC3"]
FEATURES = ["Off_PC1", "Off_PC2", "Off_PC3", "Def_PC1", "Def_PC2", "Def_PC3",
            "is_home", "led_after_3", "led_after_6"]

# 用於過濾與 R 相同的 valid rows
OFFENSE_COLS = ["AB", "H", "BB", "SO", "double", "triple", "HR",
                "extra_base_hits", "power_score", "run_per_hit", "offense_pressure_score"]
DEFENSE_COLS = ["outs_pitched", "innings_pitched", "hits_allowed", "bb_allowed",
                "hr_allowed", "so_pitched", "whip_like", "strikeout_walk_ratio",
                "run_prevention_score"]

BOOL_MAP = {"TRUE": 1, "FALSE": 0, True: 1, False: 0}


def _load():
    pca = pd.read_csv(PCA_PATH)
    pca["win"]     = pca["win"].map(BOOL_MAP).astype(int)
    pca["is_home"] = pca["is_home"].map(BOOL_MAP).astype(int)

    # 從原始 CSV 取 led_after_3 / led_after_6（與 R 相同過濾順序）
    orig = pd.read_csv(CSV_PATH)
    orig = orig.dropna(subset=OFFENSE_COLS + DEFENSE_COLS).reset_index(drop=True)
    orig["led_after_3"] = orig["led_after_3"].map(BOOL_MAP).astype(int)
    orig["led_after_6"] = orig["led_after_6"].map(BOOL_MAP).astype(int)

    if len(pca) == len(orig):
        pca["led_after_3"] = orig["led_after_3"].values
        pca["led_after_6"] = orig["led_after_6"].values
        pca["team"]        = orig["team"].values
        pca["opponent"]    = orig["opponent"].values
    else:
        pca["led_after_3"] = 0.5
        pca["led_after_6"] = 0.5

    return pca


def _train(df: pd.DataFrame):
    X = df[FEATURES].values
    y = df["win"].values
    clf = RandomForestClassifier(
        n_estimators=300, max_depth=6,
        min_samples_leaf=10, random_state=42, n_jobs=-1
    )
    cv_acc = cross_val_score(clf, X, y, cv=5, scoring="accuracy")
    clf.fit(X, y)
    return clf, {
        "cv_mean": round(float(cv_acc.mean()) * 100, 1),
        "cv_std":  round(float(cv_acc.std())  * 100, 1),
        "importances": {f: round(float(v), 4)
                        for f, v in zip(FEATURES, clf.feature_importances_)},
    }


def _safe_mean(series):
    v = series.mean()
    return 0.5 if pd.isna(v) else float(v)


def predict_matchup(home: str, away: str, phase: str) -> dict:
    """
    phase: 'led3' → 假設主場3局後領先
           'led6' → 假設主場6局後領先

    先嘗試用對戰紀錄（主場隊 vs 客場隊）的 PCA 特徵與局段領先條件機率，
    若對戰場數不足則 fallback 至該隊主/客場全體紀錄。
    """
    # 主場隊：在主場對上 away 的場次
    home_sub = pca_df[
        (pca_df["team"] == home) & (pca_df["is_home"] == 1) &
        (pca_df["opponent"] == away)
    ]
    if home_sub.empty:
        home_sub = pca_df[(pca_df["team"] == home) & (pca_df["is_home"] == 1)]
    if home_sub.empty:
        home_sub = pca_df[pca_df["team"] == home]

    # 客場隊：在客場對上 home 的場次
    away_sub = pca_df[
        (pca_df["team"] == away) & (pca_df["is_home"] == 0) &
        (pca_df["opponent"] == home)
    ]
    if away_sub.empty:
        away_sub = pca_df[(pca_df["team"] == away) & (pca_df["is_home"] == 0)]
    if away_sub.empty:
        away_sub = pca_df[pca_df["team"] == away]

    home_pc = home_sub[PC_COLS].mean().values
    away_pc = away_sub[PC_COLS].mean().values

    if phase == "led3":
        # 主場3局後領先 → 客場3局後落後
        home_led3 = 1
        home_led6 = _safe_mean(home_sub[home_sub["led_after_3"] == 1]["led_after_6"])
        away_led3 = 0
        away_led6 = _safe_mean(away_sub[away_sub["led_after_3"] == 0]["led_after_6"])
    else:  # led6
        # 主場6局後領先 → 客場6局後落後
        home_led3 = _safe_mean(home_sub[home_sub["led_after_6"] == 1]["led_after_3"])
        home_led6 = 1
        away_led3 = _safe_mean(away_sub[away_sub["led_after_6"] == 0]["led_after_3"])
        away_led6 = 0

    home_feat = list(home_pc) + [1, home_led3, home_led6]
    away_feat = list(away_pc) + [0, away_led3, away_led6]

    X = pd.DataFrame([home_feat, away_feat], columns=FEATURES)
    proba = clf.predict_proba(X)[:, 1]

    home_prob = round(float(proba[0]) * 100, 1)
    away_prob = round(float(proba[1]) * 100, 1)
    return {
        "home_win_prob":    home_prob,
        "away_win_prob":    away_prob,
        "predicted_winner": home if home_prob >= away_prob else away,
        "winner_is_home":   home_prob >= away_prob,
    }


pca_df = _load()
clf, model_info = _train(pca_df)
