#!/usr/bin/env bash
# One-click rebuild: execute the converge notebook + refresh the HTML report.
# Per-cell tables and figures stay inline in the .ipynb itself.
#
# Usage:  ./master.sh
#
# Optional env switches (read by the notebook):
#   CONVERGE_SEASONS=2024              # default "2023+2024"; single-season run
#   CONVERGE_EXPORT=false              # default "true"; skip writing Results/stage*/
#   CONVERGE_USE_TIME_LAG=false        # default "true"; turn off stage-4b leak-free gate

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NB="$HERE/Scripts/converge_analysis.ipynb"
HTML_OUT="$HERE/Results/notebook_executed.html"
BUILDER="$HERE/Scripts/build/build_converge_report.py"

if ! command -v jupyter >/dev/null 2>&1; then
  echo "[master.sh] jupyter not found. Install with: pip install jupyter nbconvert" >&2
  exit 1
fi

echo "[master.sh] Executing notebook in-place (cell timeout 20 min)..."
jupyter nbconvert \
  --to notebook \
  --execute "$NB" \
  --output "$(basename "$NB")" \
  --ExecutePreprocessor.timeout=1200

echo "[master.sh] Rebuilding styled HTML report from executed notebook..."
python3 "$BUILDER"

echo "[master.sh] Done."
echo "  - Re-executed $NB"
echo "  - Refreshed   $HTML_OUT"
