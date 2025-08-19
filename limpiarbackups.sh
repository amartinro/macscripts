#!/bin/zsh
# Borra TODAS las snapshots locales de Time Machine en "/" sin preguntar.
# Muestra recuento, espacio liberado y usa iconos para feedback visual.

set -o pipefail
autoload -U colors && colors

vol="/"

# Función para humanizar KB
human_kb() {
  local kb="$1"
  if (( kb >= 1048576 )); then
    awk -v k="$kb" 'BEGIN{printf "%.2f GB", k/1048576}'
  elif (( kb >= 1024 )); then
    awk -v k="$kb" 'BEGIN{printf "%.2f MB", k/1024}'
  else
    echo "${kb} KB"
  fi
}

# Libre antes
kb_before=$(df -kP "$vol" | awk 'NR==2{print $4}')

# Capturar snapshots válidas
snapshots=("${(@f)$(tmutil listlocalsnapshotdates "$vol" \
  | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$')}")

if (( ${#snapshots} == 0 )); then
  print -P "🟡 %F{yellow}No hay snapshots locales en $vol.%f"
  exit 0
fi

print -P "📸 %F{cyan}Encontradas ${#snapshots} snapshots en $vol:%f"
printf '   • %s\n' "${snapshots[@]}"

ok=() fail=()
ts_start=$(date +%s)

for s in "${snapshots[@]}"; do
  if tmutil deletelocalsnapshots "$s" >/dev/null 2>&1; then
    ok+=("$s")
    print -P "   ✅ %F{green}$s%f"
  else
    fail+=("$s")
    print -P "   ❌ %F{red}$s%f"
  fi
done

# Libre después
kb_after=$(df -kP "$vol" | awk 'NR==2{print $4}')
kb_freed=$(( kb_after - kb_before ))
(( kb_freed < 0 )) && kb_freed=0

dur=$(( $(date +%s) - ts_start ))

print -P "\n📊 %F{cyan}Resumen:%f"
print -P "   🟢 Borradas: %F{green}${#ok}%f   🔴 Fallidas: %F{red}${#fail}%f   ⏱ Tiempo: ${dur}s"
print -P "   💾 Libre antes:   $(human_kb "$kb_before")"
print -P "   💽 Libre después: $(human_kb "$kb_after")"
print -P "   🧹 Espacio liberado: %F{green}$(human_kb "$kb_freed")%f"