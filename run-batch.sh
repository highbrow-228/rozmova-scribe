#!/bin/bash
set -u

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INBOX="$BASE/data/wav_need_to_run"
DONE="$BASE/data/wav_done"
cd "$BASE"

model="${1:-large-v2}"
tag="${2:-}"

mkdir -p "$INBOX" "$DONE"

shopt -s nullglob nocaseglob
files=("$INBOX"/*.wav)
shopt -u nocaseglob

total=${#files[@]}

log() { echo "[$(date '+%H:%M:%S')] $*"; }

if [ "$total" -eq 0 ]; then
  log "у $INBOX немає .wav файлів"
  exit 0
fi

log "знайдено файлів: $total, модель: $model${tag:+, мітка: $tag}"
echo

t_all=$(date +%s)
ok=0
fail=0
failed=()

i=0
for f in "${files[@]}"; do
  i=$((i + 1))
  echo "═══════════════════════════════════════════════"
  log "[$i/$total] $(basename "$f")"
  echo "═══════════════════════════════════════════════"

  if ./run-wav.sh "$f" "$model" $tag; then
    ok=$((ok + 1))
    mv "$f" "$DONE/"
    log "[$i/$total] готово, файл перенесено в data/wav_done/"
  else
    fail=$((fail + 1))
    failed+=("$(basename "$f")")
    log "[$i/$total] ПОМИЛКА, файл лишився в inbox"
  fi
  echo
done

echo "═══════════════════════════════════════════════"
log "оброблено: $ok з $total, помилок: $fail"
if [ "$fail" -gt 0 ]; then
  log "не вдалося:"
  printf '           %s\n' "${failed[@]}"
fi
log "результати: $BASE/data/transcripts/"
log "загальний час: $(( ($(date +%s) - t_all) / 60 ))хв $(( ($(date +%s) - t_all) % 60 ))с"