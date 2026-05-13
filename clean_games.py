import json
import pandas as pd
from pathlib import Path

# ── Path Configuration ────────────────────────────────────
INPUT_PATH = Path("data/raw/CPBL-2024-OpenData")
OUTPUT_DIR = Path("data/cleaned")
OUTPUT_PATH = OUTPUT_DIR / "cpbl_games_cleaned.csv"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ── Load Raw JSON Data ────────────────────────────────────
raw = []

for json_path in INPUT_PATH.glob("*.json"):
    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)

    if isinstance(data, list):
        raw.extend(data)
    else:
        raw.append(data)


# ── Helper Functions ──────────────────────────────────────
def sum_scores(scores: list) -> int:
    """Sum inning-by-inning scores into a total integer score."""
    return sum(int(s) for s in scores if str(s).lstrip("-").isdigit())


def sum_batter_stat(batter_box: list, stat: str) -> int:
    """Aggregate a specific batting statistic from batterBox."""
    return sum(b.get(stat, 0) or 0 for b in batter_box)


# ── Transform Game Records ────────────────────────────────
rows = []

for game in raw:
    away_scores = game.get("awayScores", [])
    home_scores = game.get("homeScores", [])
    away_box = game.get("awayBatterBox", [])
    home_box = game.get("homeBatterBox", [])

    away_total = sum_scores(away_scores)
    home_total = sum_scores(home_scores)
    total = away_total + home_total

    # Aggregate team batting statistics
    stat_cols = ["H", "HR", "2B", "3B", "BB", "SO"]

    team_stats = {
        stat: sum_batter_stat(away_box, stat) + sum_batter_stat(home_box, stat)
        for stat in stat_cols
    }

    row = {
        "season": game.get("season"),
        "date": game.get("date"),
        "stadium": game.get("stadium"),
        "awayTeam": game.get("awayTeam"),
        "homeTeam": game.get("homeTeam"),

        # Preserve original inning score arrays for reference
        "awayScores": str(away_scores),
        "homeScores": str(home_scores),

        "away_total_score": away_total,
        "home_total_score": home_total,
        "total_score": total,

        # Derived features
        "high_score": int(total >= 10),
        "home_win": int(home_total > away_total),

        **team_stats,
    }

    rows.append(row)


# ── Create DataFrame ──────────────────────────────────────
df = pd.DataFrame(rows)

# Remove duplicated game records
df = df.drop_duplicates(
    subset=[
        "date",
        "stadium",
        "awayTeam",
        "homeTeam",
        "awayScores",
        "homeScores",
    ]
)

# Data type conversion
df["date"] = pd.to_datetime(df["date"], errors="coerce")

int_cols = [
    "away_total_score",
    "home_total_score",
    "total_score",
    "high_score",
    "home_win",
    *stat_cols,
]

df[int_cols] = df[int_cols].astype(int)


# ── Export CSV ────────────────────────────────────────────
df.to_csv(OUTPUT_PATH, index=False, encoding="utf-8-sig")

print(f"✓ Saved: {OUTPUT_PATH} ({len(df)} games)\n")


# ── Preview ───────────────────────────────────────────────
print("=== head() ===")
print(df.head().to_string())

print("\n=== info() ===")
df.info()