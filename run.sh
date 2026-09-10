#!/bin/bash
set -e

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS="$BASE/data/transcripts"
cd "$BASE"

[ -z "$1" ] && { echo "usage: ./run.sh <file.mkv> [model] [tag]"; exit 1; }
[ -f "$1" ] || { echo "немає такого файлу: $1"; exit 1; }

# значення, задані у команді, мають пріоритет над .env
cli_LANGUAGE="${LANGUAGE:-}"
cli_SPEAKER_NUM="${SPEAKER_NUM:-}"
cli_OUTPUT_FORMAT="${OUTPUT_FORMAT:-}"
cli_HOTWORDS="${HOTWORDS:-}"
cli_INITIAL_PROMPT="${INITIAL_PROMPT:-}"

set -a; source "$BASE/.env"; set +a

LANGUAGE="${cli_LANGUAGE:-${LANGUAGE:-uk}}"
SPEAKER_NUM="${cli_SPEAKER_NUM:-${SPEAKER_NUM:-2}}"
OUTPUT_FORMAT="${cli_OUTPUT_FORMAT:-${OUTPUT_FORMAT:-txt}}"
HOTWORDS="${cli_HOTWORDS:-${HOTWORDS:-}}"
INITIAL_PROMPT="${cli_INITIAL_PROMPT:-${INITIAL_PROMPT:-}}"

# порожні підказки не передаємо взагалі, а не порожнім рядком
hints=()
if [ -n "$HOTWORDS" ]; then hints+=(--hotwords "$HOTWORDS"); fi
if [ -n "$INITIAL_PROMPT" ]; then hints+=(--initial_prompt "$INITIAL_PROMPT"); fi

model="${2:-large-v2}"
tag="${3:+_$3}"
name=$(basename "${1%.*}")
wav="$BASE/$name.wav"
out="$RESULTS/${name}_${model}${tag}"

mkdir -p "$RESULTS"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
t0=$(date +%s)

log "файл: $1. Розмір: $(du -h "$1" | cut -f1)"
log "модель: $model${tag:+, мітка: ${tag#_}}"
log "мова: $LANGUAGE, спікерів: $SPEAKER_NUM, формат: $OUTPUT_FORMAT"
h_state=немає; [ -n "$HOTWORDS" ] && h_state=задано
p_state=немає; [ -n "$INITIAL_PROMPT" ] && p_state=задано
log "підказки: hotwords — $h_state, initial_prompt — $p_state"

source "$BASE/.venv/bin/activate"
export LD_LIBRARY_PATH=$(find "$VIRTUAL_ENV" -type d -path '*/nvidia/*' -name lib | tr '\n' ':')
export HF_HOME="$BASE/cache/hf-cache"
export PYTHONWARNINGS="ignore::UserWarning"

log "CUDA-пристроїв: $(python3 -c 'import ctranslate2; print(ctranslate2.get_cuda_device_count())')"
if [ -n "$HF_TOKEN" ]; then
  log "токен HF: ${HF_TOKEN:0:2}...${HF_TOKEN: -3}"
else
  log "токен HF: ВІДСУТНІЙ"
fi

if [ -f "$wav" ]; then
  log "аудіо вже є, пропускаю витяг: $(du -h "$wav" | cut -f1)"
else
  log "витягую аудіо"
  ffmpeg -y -loglevel warning -stats -i "$1" -vn \
    -af "highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=11" \
    -ac 1 -ar 16000 -c:a pcm_s16le "$wav"
  log "аудіо готове: $(du -h "$wav" | cut -f1)"
fi

log "діаризація + транскрипція (перший етап без прогресу, це нормально)"
whisper-ctranslate2 "$wav" \
  --model "$model" \
  --language "$LANGUAGE" \
  --compute_type float16 \
  --beam_size 5 \
  --condition_on_previous_text False \
  --vad_filter True \
  --vad_threshold 0.3 \
  --vad_max_speech_duration_s 15 \
  --vad_min_speech_duration_ms 100 \
  --vad_min_silence_duration_ms 300 \
  --no_speech_threshold 0.6 \
  --word_timestamps True \
  --hallucination_silence_threshold 2 \
  "${hints[@]}" \
  --hf_token "$HF_TOKEN" \
  --speaker_num "$SPEAKER_NUM" \
  --verbose True \
  --output_format "$OUTPUT_FORMAT" \
  --output_dir "$out"

result="$out/$name.txt"

# статистика рахується по .txt; за інших форматів його може не бути
if [ -f "$result" ]; then
  log "рядків: $(wc -l < "$result"), слів: $(wc -w < "$result")"
  log "розподіл по спікерах:"
  grep -o '^\[SPEAKER_[0-9]*\]' "$result" | sort | uniq -c | sed 's/^/           /'
else
  result="$out"
fi
log "загальний час: $(( ($(date +%s) - t0) / 60 ))хв $(( ($(date +%s) - t0) % 60 ))с"

rm -f "$wav"
log "тимчасове аудіо видалено"

log "готово: $result"
log "аудіо лишив: $wav (видали вручну, коли закінчиш порівняння)"