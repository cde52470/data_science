#!/usr/bin/env bash
# One-click rebuild: execute the main notebook and refresh the HTML export.
# Anything else (per-cell tables and figures) stays inline in the .ipynb itself.
#
# Usage:  ./master.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NB="$HERE/Scripts/cpbl_unsupervised_feature_discovery.ipynb"
HTML_OUT="$HERE/Results/notebook_executed.html"

if ! command -v jupyter >/dev/null 2>&1; then
  echo "[master.sh] jupyter not found. Install with: pip install jupyter nbconvert" >&2
  exit 1
fi

echo "[master.sh] Executing notebook (cell timeout 20 min)..."
jupyter nbconvert \
  --to notebook \
  --execute "$NB" \
  --output "$(basename "$NB")" \
  --ExecutePreprocessor.timeout=1200

echo "[master.sh] Exporting HTML to Results/..."
jupyter nbconvert --to html "$NB" --output "$HTML_OUT"

echo "[master.sh] Done."
echo "  - Updated $NB"
echo "  - Updated $HTML_OUT"
