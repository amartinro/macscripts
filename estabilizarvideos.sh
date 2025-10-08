

#!/usr/bin/env bash
set -euo pipefail

# ===== Config =====
SUFFIX="_estabilizado"
OUTDIR="estabilizado"
LOGDIR="$OUTDIR/_logs"
TARGET_CODEC="source"   # "source" | "prores" | "hevc" | "h264"
FALLBACK_PRESET=""      # .gyroflow para clips sin gyro (opcional)
LENS_PROFILE=""         # .json de lente (opcional)
TARGET_DIR="."          # directorio a escanear (por defecto, actual)
DEBUG_MODE=0
NO_PROGRESS=0
META_TIMEOUT=20          # segundos para timeout de metadatos
CPU_DECODE=0

# ===== Flags =====
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prores) TARGET_CODEC="prores"; shift ;;
    --hevc)   TARGET_CODEC="hevc";   shift ;;
    --h264)   TARGET_CODEC="h264";   shift ;;
    --fallback-preset) FALLBACK_PRESET="$2"; shift 2 ;;
    --lens)            LENS_PROFILE="$2";   shift 2 ;;
    --dir)             TARGET_DIR="$2";     shift 2 ;;
    --no-progress)     NO_PROGRESS=1;        shift ;;
    --debug)           DEBUG_MODE=1;         shift ;;
    --meta-timeout)    META_TIMEOUT="$2";    shift 2 ;;
    --cpu-decode)      CPU_DECODE=1;         shift ;;
    --*) echo "Uso: $0 [--prores|--hevc|--h264] [--fallback-preset preset.gyroflow] [--lens lente.json] [--dir DIR] [DIR]"; exit 1 ;;
    *)
      if [[ -d "$1" ]]; then TARGET_DIR="$1"; shift; else
        echo "Uso: $0 [--prores|--hevc|--h264] [--fallback-preset preset.gyroflow] [--lens lente.json] [--dir DIR] [DIR]"; exit 1
      fi
      ;;
  esac
done

# ===== Helpers =====
need(){ command -v "$1" >/dev/null 2>&1 || { echo "Falta '$1' (brew install $1)"; exit 1; }; }
abs(){ case "$1" in /*) printf "%s\n" "$1";; *) printf "%s/%s\n" "$(pwd -P)" "${1#./}";; esac; }
codec_label(){
  local c; c="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nk=1:nw=1 "$1" | tr 'A-Z' 'a-z')"
  case "$c" in h264|avc|mpeg4) echo "H.264/AVC";; hevc|h265) echo "H.265/HEVC";; prores) echo "ProRes";; dnxhd|dnxhr) echo "DNxHD";; *) echo "H.264/AVC";; esac
}

# Ejecuta un comando con timeout en segundos; si expira, devuelve 124
timeout_run(){
  local seconds="$1"; shift
  local flag
  flag="$(mktemp)" || return 1
  (
    set +e
    "$@" &
    local cmd_pid=$!
    (
      sleep "$seconds"
      if kill -0 "$cmd_pid" 2>/dev/null; then
        touch "$flag"
        kill "$cmd_pid" 2>/dev/null || true
      fi
    ) &
    local timer_pid=$!
    wait "$cmd_pid"
    local status=$?
    kill -0 "$timer_pid" 2>/dev/null && kill "$timer_pid" 2>/dev/null || true
    if [[ -f "$flag" ]]; then rm -f "$flag"; exit 124; fi
    exit "$status"
  )
}

need ffmpeg; need ffprobe; need jq
[[ "$DEBUG_MODE" -eq 1 ]] && set -x
GYRO="gyroflow"
if ! command -v "$GYRO" >/dev/null 2>&1; then
  if [[ -x "/Applications/Gyroflow.app/Contents/MacOS/Gyroflow" ]]; then GYRO="/Applications/Gyroflow.app/Contents/MacOS/Gyroflow"
  else echo "No encuentro Gyroflow (App Store o brew --cask gyroflow)."; exit 1; fi
fi

# Resolver rutas de preset/lente antes de cambiar de directorio
[[ -n "$FALLBACK_PRESET" ]] && FALLBACK_PRESET="$(abs "$FALLBACK_PRESET")"
[[ -n "$LENS_PROFILE"   ]] && LENS_PROFILE="$(abs "$LENS_PROFILE")"

# Cambiar al directorio objetivo
TARGET_DIR_ABS="$(abs "$TARGET_DIR")"
cd "$TARGET_DIR_ABS"

mkdir -p "$OUTDIR" "$LOGDIR"

# macOS: render en GPU Apple
OS="$(uname -s)"; RENDER_FLAG=()
[[ "$OS" == "Darwin" ]] && RENDER_FLAG=( -r "apple m" )

TOTAL=$(find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.m4v" -o -iname "*.avi" \) -print | wc -l | tr -d ' ')
[[ "$TOTAL" -eq 0 ]] && { echo "No se encontraron vídeos."; exit 0; }

echo "▶ Estabilizando $TOTAL archivo(s) en '$(pwd -P)' → '$OUTDIR/' (códec: $TARGET_CODEC)"
[[ -n "$FALLBACK_PRESET" ]] && echo "   Fallback preset: $FALLBACK_PRESET"
[[ -n "$LENS_PROFILE"   ]] && echo "   Lens profile: $LENS_PROFILE"
echo

i=0
find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.m4v" -o -iname "*.avi" \) -print0 | \
while IFS= read -r -d '' inrel; do
  ((i++))
  inabs="$(abs "$inrel")"; inname="$(basename "$inabs")"; base="${inname%.*}"; indir="$(dirname "$inabs")"
  echo "[$i/$TOTAL] $inname"

  # ¿Gyro embebido?
  has_gyro="false"
  tmpjson="$(mktemp)"
  if [[ "$DEBUG_MODE" -eq 1 ]]; then echo "[debug] meta cmd: $GYRO --export-metadata 3:$tmpjson --export-metadata-fields '{\"original\":{\"gyroscope\":true}}' $inabs"; fi
  if timeout_run "$META_TIMEOUT" "$GYRO" --export-metadata 3:"$tmpjson" --export-metadata-fields '{"original":{"gyroscope":true}}' "$inabs" >/dev/null 2>&1; then
    jq -e '.original and (.original.gyroscope != null)' "$tmpjson" >/dev/null 2>&1 && has_gyro="true"
  else
    echo "   ⚠ Timeout leyendo metadatos ("$META_TIMEOUT"s). Asumiendo sin gyro.)" | tee -a "$LOGDIR/${base}.log"
  fi; rm -f "$tmpjson"

  # Códec salida
  case "$TARGET_CODEC" in
    prores) out_codec="ProRes" ;;
    hevc)   out_codec="H.265/HEVC" ;;
    h264)   out_codec="H.264/AVC" ;;
    *)      out_codec="$(codec_label "$inabs")" ;;
  esac

  # Comando base (ABS) + overwrite (-f) + progreso
  CMD=( "$GYRO" -f --stdout-progress -j 1 "${RENDER_FLAG[@]}" -t "$SUFFIX" )
  [[ -n "$LENS_PROFILE" ]] && CMD+=( "$inabs" "$LENS_PROFILE" ) || CMD+=( "$inabs" )
  if [[ "$has_gyro" != "true" ]]; then
    [[ -n "$FALLBACK_PRESET" ]] && CMD+=( --preset "$FALLBACK_PRESET" )
    CMD+=( -s '{"processing_resolution":720,"search_size":3}' )
  fi
  if [[ "$CPU_DECODE" -eq 1 ]]; then CMD+=( --no-gpu-decoding ); fi

  logfile="$LOGDIR/${base}.log"
  [[ "$has_gyro" == "true" ]] && MSG="Gyroflow (gyro)" || MSG="Gyroflow (optico)"
  start=$(date +%s)

  # Render con barra 0–100% (convertimos \r a \n para que awk vea porcentajes)
  if [[ "$NO_PROGRESS" -eq 1 ]]; then
    printf 'CMD: ' >> "$logfile"; for x in "${CMD[@]}"; do printf '%q ' "$x" >> "$logfile"; done; printf '\n' >> "$logfile"
    "${CMD[@]}" -p "{\"codec\":\"$out_codec\",\"use_gpu\":true,\"audio\":true}" 2>&1 | tee -a "$logfile"
  else
    "${CMD[@]}" -p "{\"codec\":\"$out_codec\",\"use_gpu\":true,\"audio\":true}" \
      2>&1 | tr '\r' '\n' | tee -a "$logfile" | awk -v msg="$MSG" -v start="$start" '
        BEGIN{w=28;p=-1}
        function fmt(s){h=int(s/3600);m=int((s%3600)/60);x=s%60;return sprintf("%02d:%02d:%02d",h,m,x)}
        {
          if (match($0,/([0-9]{1,3})%/,m)) {
            np=m[1]+0; if(np>100)np=100;
            if (np!=p){f=int(np*w/100);bar="";
              for(i=0;i<f;i++)bar=bar"#"; for(i=f;i<w;i++)bar=bar"-";
              printf "\r   [%s] %3d%%  %s  %s", bar, np, fmt(systime()-start), msg; fflush()}
            p=np
          }
        }
        END{
          if(p<0){w=28;bar="";for(i=0;i<w;i++)bar=bar"#";
            printf "\r   [%s] 100%%  %s  %s\n",bar,fmt(systime()-start),msg}
          else {print ""}
        }'
  fi

  echo

  # Mover salida
  out_guess="$(ls -t "$indir/${base}${SUFFIX}."* 2>/dev/null | head -n1 || true)"
  if [[ -n "${out_guess:-}" ]]; then
    mv -f "$out_guess" "$OUTDIR/"
    echo "   ✅ -> $OUTDIR/$(basename "$out_guess")"
  else
    echo "   ⚠ No encuentro la salida. Log: $logfile"
  fi
  echo

done

echo "✔ Terminado. Archivos en '$OUTDIR/'"
