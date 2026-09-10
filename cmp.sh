#!/bin/bash
set -e

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS="$BASE/data/transcripts"
cd "$BASE"

[ -z "$3" ] && { echo "usage: ./cmp.sh <file> <variant_a> <variant_b>"; echo; echo "варіант = модель або модель_мітка, напр. large-v3 або large-v3_vad15"; echo; echo "наявні:"; ls -1 "$RESULTS" 2>/dev/null | sed 's/^/  /'; exit 1; }

name=$(basename "${1%.*}")
a="$RESULTS/${name}_$2/$name.txt"
b="$RESULTS/${name}_$3/$name.txt"
res="$RESULTS/diff_${name}_$2_vs_$3.txt"

[ -f "$a" ] || { echo "немає: $a"; exit 1; }
[ -f "$b" ] || { echo "немає: $b"; exit 1; }

{
  echo "=== $2 vs $3 ==="
  echo "файл: $1"
  echo "дата: $(date '+%Y-%m-%d %H:%M')"
  echo
  echo "$2: $(wc -l < "$a") рядків, $(wc -w < "$a") слів"
  echo "$3: $(wc -l < "$b") рядків, $(wc -w < "$b") слів"
  echo
  echo "--- розбіжності (ліворуч $2, праворуч $3) ---"
  echo
  diff -y --width=200 --suppress-common-lines "$a" "$b" || true
} > "$res"

echo "записано: $res"