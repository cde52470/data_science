"""
build_pa_player_features.py

Build a PA-level dataset from CPBL 2024 open data.
Each row represents one plate appearance (PA).
Output: data/cleaned/pa_features_2024.csv
"""

import json
import pandas as pd
from pathlib import Path

INPUT_PATH = Path("data/raw/CPBL-2024-OpenData/CPBL-2024-OpenData.json")
OUTPUT_PATH = Path("data/cleaned/pa_features_2024.csv")

# Results that count as on-base
ON_BASE_RESULTS = {"1B", "2B", "3B", "HR", "IHR", "uBB", "IBB", "HBP", "E"}
HIT_RESULTS = {"1B", "2B", "3B", "HR", "IHR"}
EXTRA_BASE_RESULTS = {"2B", "3B", "HR", "IHR"}
WALK_RESULTS = {"uBB", "IBB", "HBP"}


def load_games(path: Path) -> list:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def parse_pa_list(pa_list: list, half: str, game_info: dict) -> list:
    rows = []
    away_team = game_info["awayTeam"]
    home_team = game_info["homeTeam"]

    batting_team = away_team if half == "top" else home_team
    fielding_team = home_team if half == "top" else away_team

    for pa in pa_list:
        try:
            away_scores = pa.get("awayScores", None)
            home_scores = pa.get("homeScores", None)

            # score_diff from batting team's perspective
            if away_scores is not None and home_scores is not None:
                if half == "top":
                    score_diff = int(away_scores) - int(home_scores)
                else:
                    score_diff = int(home_scores) - int(away_scores)
            else:
                score_diff = None

            row = {
                # game-level
                "season": game_info.get("season"),
                "seq": game_info.get("seq"),
                "date": game_info.get("date"),
                "stadium": game_info.get("stadium"),
                "awayTeam": away_team,
                "homeTeam": home_team,
                # PA-level
                "batting_team": batting_team,
                "fielding_team": fielding_team,
                "inning": pa.get("inning"),
                "half_inning": half,
                "batterName": pa.get("batterName"),
                "batterHand": pa.get("batterHand"),
                "pitcherName": pa.get("pitcherName"),
                "pitcherHand": pa.get("pitcherHand"),
                "balls": pa.get("balls"),
                "strikes": pa.get("strikes"),
                "outs": pa.get("outs"),
                "bases": pa.get("bases"),
                "awayScores": away_scores,
                "homeScores": home_scores,
                "score_diff_from_batting_team_view": score_diff,
                "RE": pa.get("RE"),
                "WPA": pa.get("WPA"),
                "RE24": pa.get("RE24"),
                "result": pa.get("result"),
                "RBI": pa.get("RBI"),
                "scored": pa.get("scored"),
                "endAwayScores": pa.get("endAwayScores"),
                "endHomeScores": pa.get("endHomeScores"),
                "endOuts": pa.get("endOuts"),
                "endBases": pa.get("endBases"),
                "locationCode": pa.get("locationCode"),
                "trajectory": pa.get("trajectory"),
                "hardness": pa.get("hardness"),
            }
            rows.append(row)
        except Exception as e:
            print(f"[WARN] Skipped PA due to error: {e} | game seq={game_info.get('seq')}")

    return rows


def build_dataset(games: list) -> pd.DataFrame:
    all_rows = []

    for game in games:
        game_info = {
            "season": game.get("season"),
            "seq": game.get("seq"),
            "date": game.get("date"),
            "stadium": game.get("stadium"),
            "awayTeam": game.get("awayTeam"),
            "homeTeam": game.get("homeTeam"),
        }

        away_pa = game.get("awayPAList", [])
        home_pa = game.get("homePAList", [])

        all_rows.extend(parse_pa_list(away_pa, "top", game_info))
        all_rows.extend(parse_pa_list(home_pa, "bottom", game_info))

    df = pd.DataFrame(all_rows)
    return df


def cast_types(df: pd.DataFrame) -> pd.DataFrame:
    # Numeric conversions
    for col in ["RE", "WPA", "RE24"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    # Integer conversions (allow NA via Int64)
    int_cols = [
        "balls", "strikes", "outs", "bases",
        "awayScores", "homeScores",
        "endAwayScores", "endHomeScores", "endOuts", "endBases",
        "RBI", "seq",
    ]
    for col in int_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")

    int_direct = ["inning", "score_diff_from_batting_team_view"]
    for col in int_direct:
        df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")

    return df


def add_labels(df: pd.DataFrame) -> pd.DataFrame:
    result = df["result"].fillna("")

    df["on_base"] = result.isin(ON_BASE_RESULTS).astype(int)
    df["is_hit"] = result.isin(HIT_RESULTS).astype(int)
    df["is_extra_base_hit"] = result.isin(EXTRA_BASE_RESULTS).astype(int)
    df["is_strikeout"] = (result == "SO").astype(int)
    df["is_walk"] = result.isin(WALK_RESULTS).astype(int)
    df["rbi_positive"] = (df["RBI"].fillna(0) > 0).astype(int)

    return df


def main():
    print(f"Loading data from {INPUT_PATH} ...")
    try:
        games = load_games(INPUT_PATH)
    except FileNotFoundError:
        print(f"[ERROR] File not found: {INPUT_PATH}")
        return
    except json.JSONDecodeError as e:
        print(f"[ERROR] JSON parse error: {e}")
        return

    print(f"Loaded {len(games)} games.")

    df = build_dataset(games)
    print(f"Total PA rows before processing: {len(df)}")

    df = cast_types(df)
    df = add_labels(df)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUTPUT_PATH, index=False, encoding="utf-8-sig")
    print(f"\nSaved to {OUTPUT_PATH}")

    print("\n--- df.head() ---")
    print(df.head())

    print("\n--- df.info() ---")
    df.info()

    print("\n--- result value counts ---")
    print(df["result"].value_counts())


if __name__ == "__main__":
    main()
