#!/bin/zsh
#
# Script: optimizar
# Descripción:
#   Optimiza imágenes manteniendo la estructura de carpetas.
#   Conserva el formato original (JPG/JPEG o PNG) y opcionalmente genera WebP.
#   Muestra progreso, tamaños antes/después y % de ahorro por archivo y total.
#
# Requisitos:
#   - zsh
#   - ImageMagick (magick)
#
# Uso:
#   optimizar ORIGEN DESTINO [MAX_LADO=1920] [--webp]
#
# Ejemplos:
#   optimizar ~/imagenes ~/imagenes_opt
#   optimizar ~/imagenes ~/imagenes_opt 1600
#   optimizar ~/imagenes ~/imagenes_opt 1600 --webp

#!/bin/zsh
# optimizar ORIGEN DESTINO [MAX_LADO=1920] [--webp]

set -euo pipefail
SRC="${1:-}"; DST="${2:-}"; MAX="${3:-1920}"
MAKE_WEBP=false; [[ "${4:-}" == "--webp" ]] && MAKE_WEBP=true
[[ -z "$SRC" || -z "$DST" ]] && { echo "Uso: $0 ORIGEN DESTINO [MAX_LADO=1920] [--webp]"; exit 1; }

# Colores mínimos
autoload -U colors && colors || true
G="$fg_bold[green]"; C="$fg_bold[cyan]"; B="$fg_bold[white]"; N="$reset_color"

# Normaliza rutas
SRC="$(cd "$SRC" && pwd)"
mkdir -p "$DST"
DST="$(cd "$DST" && pwd)"

# Cabecera
print -P "%F{240}────────────────────────────────────────────────────────────${N}"
print -P "${B}Optimización de imágenes${N}"
print -P "${B}Origen:${N} $SRC"
print -P "${B}Destino:${N} $DST"
print -P "${B}Lado máx:${N} ${MAX}px"
print -P "${B}WebP extra:${N} $([[ $MAKE_WEBP == true ]] && echo 'sí' || echo 'no')"

# Contadores
TOTAL=0 BEFORE=0 AFTER=0 WEBP_TOTAL=0

# Recorre ficheros de forma segura (espacios, acentos)
find "$SRC" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 |
while IFS= read -r -d '' file; do
  (( TOTAL++ )) || true
  rel="${file#$SRC/}"
  outdir="$DST/$(dirname "$rel")"
  mkdir -p "$outdir"

  ext_lc="$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')"
  base="$(basename "$rel" .${file##*.})"
  out_main="$outdir/${base}.$([[ "$ext_lc" == jpg || "$ext_lc" == jpeg ]] && echo jpg || echo png)"

  # Tamaño inicial
  if stat -f%z "$file" >/dev/null 2>&1; then sz_before=$(stat -f%z "$file"); else sz_before=$(stat -c%s "$file"); fi
  BEFORE=$(( BEFORE + sz_before ))

  print -P "${C}→${N} $rel"

  # Redimensiona una vez
  tmp="$(mktemp -t optimg.XXXXXX).png"
  magick "$file" -resize "${MAX}x${MAX}>" -strip "$tmp"

  if [[ "$ext_lc" == "jpg" || "$ext_lc" == "jpeg" ]]; then
    magick "$tmp" -sampling-factor 4:2:0 -interlace Plane -quality 78 "$out_main"
  else
    magick "$tmp" -define png:compression-level=9 -define png:compression-strategy=2 -strip "$out_main"
  fi

  if stat -f%z "$out_main" >/dev/null 2>&1; then sz_after=$(stat -f%z "$out_main"); else sz_after=$(stat -c%s "$out_main"); fi
  AFTER=$(( AFTER + sz_after ))

  # WebP opcional
  if $MAKE_WEBP; then
    out_webp="$outdir/${base}.webp"
    alpha="$(magick identify -format '%[alpha]' "$tmp" 2>/dev/null || echo '')"
    if [[ "$alpha" == "on" || "$alpha" == "True" ]]; then
      magick "$tmp" -strip -quality 85 -define webp:method=6 -define webp:auto-filter=true "$out_webp"
    else
      magick "$tmp" -strip -quality 80 -define webp:method=6 -define webp:auto-filter=true "$out_webp"
    fi
    if stat -f%z "$out_webp" >/dev/null 2>&1; then wsz=$(stat -f%z "$out_webp"); else wsz=$(stat -c%s "$out_webp"); fi
    WEBP_TOTAL=$(( WEBP_TOTAL + wsz ))
  fi

  rm -f "$tmp"
  print -P "   ${G}OK${N}"
done

# Resumen
[[ $TOTAL -eq 0 ]] && { echo "No se encontraron imágenes en $SRC"; exit 0; }
ahorro=$(( BEFORE>0 ? ( (BEFORE-AFTER)*100/BEFORE ) : 0 ))
echo "────────────────────────────────────────────────────────────"
echo "Archivos: $TOTAL"
echo "Total origen: $BEFORE bytes"
echo "Total salida: $AFTER bytes  Ahorro: ${ahorro}%"
$MAKE_WEBP && echo "Peso total WebP: $WEBP_TOTAL bytes"
echo "Hecho."