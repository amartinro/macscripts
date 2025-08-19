#!/bin/zsh

#INSTALODER="/opt/homebrew/bin/instaloader"
INSTALODER="/Users/amartin/.local/pipx/venvs/instaloader/bin/instaloader"
FFMPEG="/opt/homebrew/bin/ffmpeg"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis
EMOJI_INFO="ℹ️"
EMOJI_SUCCESS="✅"
EMOJI_WARNING="⚠️"
EMOJI_ERROR="❌"
EMOJI_DOWNLOAD="📥"
EMOJI_CONVERT="🔄"
EMOJI_CLEAN="🧹"
EMOJI_DONE="🎉"

###############################################################################
# Utilidades de caja con borde derecho alineado usando CHA (\e[<N>G)
###############################################################################
BOX_WIDTH=65                                   # columnas totales de la caja
_box_line_chars() { printf '%s' "$(printf '─%.0s' $(seq 1 $1))"; }

BOX_TOP="┌$(_box_line_chars $((BOX_WIDTH-2)))┐"
BOX_SEP="├$(_box_line_chars $((BOX_WIDTH-2)))┤"
BOX_BOT="└$(_box_line_chars $((BOX_WIDTH-2)))┘"
BOX_RIGHT_COL=${#BOX_TOP}                      # columna absoluta del borde derecho

box_top() { printf "%b%s%b\n" "$GREEN" "$BOX_TOP" "$NC"; }
box_sep() { printf "%b%s%b\n" "$GREEN" "$BOX_SEP" "$NC"; }
box_bot() { printf "%b%s%b\n" "$GREEN" "$BOX_BOT" "$NC"; }
# Imprime una fila y coloca la barra derecha siempre en la misma columna
box_row() {
  local s="$1"
  printf "%b│%b %b" "$GREEN" "$NC" "$s"
  printf "\e[%dG%b│%b\n" "$BOX_RIGHT_COL" "$GREEN" "$NC"
}
###############################################################################

mostrar_ayuda() {
    echo "${CYAN}${EMOJI_INFO} Uso: $0 <cuenta_instagram> <login_instagram> <directorio_destino>${NC}"
    echo "${CYAN}Ejemplo: $0 usuario_instagram mi_login_instagram /ruta/destino/${NC}"
    exit 1
}

# Verificar parámetros
if [ $# -ne 3 ]; then
    echo "${RED}${EMOJI_ERROR} ERROR: Número incorrecto de parámetros${NC}"
    mostrar_ayuda
fi

CUENTA_INSTAGRAM="$1"
LOGIN_INSTAGRAM="$2"
DIRNAME="$3"

echo "${BLUE}${EMOJI_INFO} Iniciando descarga de stories de Instagram...${NC}"
echo "${BLUE}Cuenta: ${CYAN}$CUENTA_INSTAGRAM${NC}"
echo "${BLUE}Directorio: ${CYAN}$DIRNAME${NC}"
echo ""

# Verifica herramientas
if [ ! -f "$INSTALODER" ]; then
    echo "${RED}${EMOJI_ERROR} ERROR: No se encuentra instaloader${NC}"
    echo "${RED}Ruta esperada: $INSTALODER${NC}"
    echo ""
    echo "${YELLOW}${EMOJI_WARNING} POSIBLES SOLUCIONES:${NC}"
    echo "${CYAN}1. Homebrew:${NC} brew install instaloader"
    echo "${CYAN}2. pip:${NC} pip install instaloader"
    echo "${CYAN}3. pipx:${NC} pipx install instaloader"
    echo "${CYAN}4. Ajusta la ruta en el script${NC}"
    echo ""
    echo "${BLUE}${EMOJI_INFO} Comprobar ruta:${NC} which instaloader"
    exit 1
fi

# User agents
USER_AGENTS=(
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/106.0.5249.92 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (iPad; CPU OS 16_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (Linux; Android 13; SM-S908B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    "Mozilla/5.0 (Linux; Android 13; SM-A536B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    "Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    "Mozilla/5.0 (Linux; Android 12; SM-G998U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 278.0.0.19.115"
)
RANDOM_INDEX=$((RANDOM % ${#USER_AGENTS[@]}))
SELECTED_USER_AGENT="${USER_AGENTS[$RANDOM_INDEX]}"

if [ ! -f "$FFMPEG" ]; then
    echo "${RED}${EMOJI_ERROR} ERROR: No se encuentra ffmpeg${NC}"
    echo "${RED}Ruta esperada: $FFMPEG${NC}"
    echo ""
    echo "${YELLOW}${EMOJI_WARNING} POSIBLES SOLUCIONES:${NC}"
    echo "${CYAN}1. Homebrew:${NC} brew install ffmpeg"
    echo "${CYAN}2. MacPorts:${NC} sudo port install ffmpeg"
    echo "${CYAN}3. https://ffmpeg.org/download.html${NC}"
    echo "${CYAN}4. Ajusta la ruta en el script${NC}"
    echo ""
    echo "${BLUE}${EMOJI_INFO} Comprobar ruta:${NC} which ffmpeg"
    exit 1
fi

# Directorio destino
if [ ! -d "$DIRNAME" ]; then
    echo "${RED}${EMOJI_ERROR} ERROR: El directorio de destino no existe${NC}"
    echo "${RED}Ruta: $DIRNAME${NC}"
    echo ""
    echo "${YELLOW}${EMOJI_WARNING} SOLUCIONES:${NC}"
    echo "${CYAN}mkdir -p \"$DIRNAME\"${NC}"
    exit 1
fi

# Limpieza de archivos antiguos
limpiar_archivos_antiguos() {
    echo "${PURPLE}${EMOJI_CLEAN} Comprobando archivos antiguos...${NC}"
    fecha_actual=$(date +%s)
    setopt nullglob 2>/dev/null || shopt -s nullglob 2>/dev/null
    for archivo in "$DIRNAME"/*.mp4; do procesar_archivo "$archivo"; done
    for archivo in "$DIRNAME"/*.jpg;  do procesar_archivo "$archivo"; done
    unsetopt nullglob 2>/dev/null || shopt -u nullglob 2>/dev/null
}

procesar_archivo() {
    local archivo="$1"
    [ -f "$archivo" ] || return
    nombre_archivo=$(basename "$archivo")
    fecha_archivo="${nombre_archivo:0:10} ${nombre_archivo:11:2}:${nombre_archivo:14:2}:${nombre_archivo:17:2}"
    fecha_archivo_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$fecha_archivo" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "${YELLOW}${EMOJI_WARNING} No se pudo leer fecha: $nombre_archivo${NC}"
        return
    fi
    diferencia_segundos=$((fecha_actual - fecha_archivo_epoch))
    diferencia_horas=$((diferencia_segundos / 3600))
    if [ $diferencia_horas -gt 25 ]; then
        echo "${YELLOW}${EMOJI_CLEAN} Eliminando ($diferencia_horas h): $nombre_archivo${NC}"
        rm "$archivo"
        ((archivos_eliminados++))
    fi
}

archivos_eliminados=0
limpiar_archivos_antiguos

echo "${BLUE}${EMOJI_DOWNLOAD} Descargando stories de Instagram...${NC}"
echo "${BLUE}${EMOJI_INFO} Usando sesión: $LOGIN_INSTAGRAM${NC}"
echo "${BLUE}${EMOJI_INFO} User Agent: ${CYAN}${SELECTED_USER_AGENT:0:50}...${NC}"
echo ""

log_file="$DIRNAME/instaloader.log"
set -o pipefail
if $INSTALODER $CUENTA_INSTAGRAM --stories --no-pictures --no-video-thumbnails --no-captions --no-metadata-json --no-posts --no-profile-pic --login=$LOGIN_INSTAGRAM --dirname-pattern "$DIRNAME" --user-agent="$SELECTED_USER_AGENT" 2>&1 | tee "$log_file"; then
    echo "${GREEN}${EMOJI_SUCCESS} Descarga completada${NC}"
    echo ""
    if ! cd "$DIRNAME"; then
        echo "${RED}${EMOJI_ERROR} ERROR: No se pudo acceder a $DIRNAME${NC}"
        exit 1
    fi
    if ! ls *.mp4 >/dev/null 2>&1; then
        echo "${YELLOW}${EMOJI_WARNING} No hay MP4 para procesar${NC}"
        fecha_actual=$(date +"%Y-%m-%d %H:%M:%S")
        echo "Ejecución completada sin archivos: $fecha_actual" > "$DIRNAME/ultimaejecucion.txt"
        exit 0
    fi

    mkdir -p "converted" || { echo "${RED}${EMOJI_ERROR} ERROR: No se pudo crear 'converted'${NC}"; exit 1; }

    archivos_omitidos=0
    archivos_procesados=0
    total_archivos=$(ls -1 *.mp4 2>/dev/null | wc -l)
    echo "${BLUE}${EMOJI_CONVERT} Procesando $total_archivos archivos...${NC}"
    echo ""

    for f in *.mp4; do
        fecha="${f:0:10}"
        ((archivos_procesados++))
        if ! mkdir -p "converted/$fecha"; then
            echo "${RED}${EMOJI_ERROR} ERROR: No se pudo crear converted/$fecha${NC}"
            continue
        fi
        archivo_convertido="converted/$fecha/${f%.mp4}.mp4"
        if [ ! -f "$archivo_convertido" ]; then
            printf "${CYAN}[%d/%d] ${EMOJI_CONVERT} Convirtiendo: ${NC}%s" "$archivos_procesados" "$total_archivos" "$(basename "$f")"
            if $FFMPEG -loglevel quiet -n -i "$f" -r 24 "$archivo_convertido" 2>/dev/null; then
                echo " ${GREEN}${EMOJI_SUCCESS}${NC}"
            else
                echo " ${RED}${EMOJI_ERROR}${NC}"
                echo "${RED}  ERROR: Falló la conversión de $f${NC}"
                continue
            fi
        else
            echo "${YELLOW}[$archivos_procesados/$total_archivos] ${EMOJI_WARNING} Omitiendo: $(basename "$f") (ya existe)${NC}"
            ((archivos_omitidos++))
        fi
    done

    echo ""
    echo "${GREEN}${EMOJI_DONE} Procesamiento completado${NC}"

    fecha_actual=$(date +"%Y-%m-%d %H:%M:%S")
    echo "Última ejecución exitosa: $fecha_actual" > "$DIRNAME/ultimaejecucion.txt"

    num_archivos=$(ls -1 *.mp4 2>/dev/null | wc -l)
    num_convertidos=$(find converted -name "*.mp4" 2>/dev/null | wc -l)

    # Caja final con bordes alineados
    echo ""
    box_top
    box_row " ${EMOJI_DONE} PROCESO COMPLETADO ${EMOJI_DONE}"
    box_sep
    box_row " ${EMOJI_DOWNLOAD} Descarga de stories completada"
    box_row " ${EMOJI_CLEAN} Archivos antiguos eliminados: ${CYAN}$archivos_eliminados${NC}"
    box_row " ${EMOJI_CONVERT} Archivos encontrados: ${CYAN}$num_archivos${NC}"
    box_row " ${EMOJI_CONVERT} Archivos convertidos: ${CYAN}$((num_archivos - archivos_omitidos))${NC}"
    box_row " ${EMOJI_WARNING} Archivos omitidos: ${CYAN}$archivos_omitidos${NC}"
    box_row " ${EMOJI_SUCCESS} Total en converted: ${CYAN}$num_convertidos${NC}"
    box_row " ${EMOJI_INFO} Fecha: ${CYAN}$fecha_actual${NC}"
    box_bot

else
    fecha_error=$(date +"%Y-%m-%d %H:%M:%S")
    echo "${RED}${EMOJI_ERROR} ERROR: Falló la descarga de stories${NC}"
    echo ""
    echo "${YELLOW}${EMOJI_WARNING} DETALLES:${NC}"
    echo "${CYAN}Cuenta:${NC} $CUENTA_INSTAGRAM"
    echo "${CYAN}Sesión:${NC} $LOGIN_INSTAGRAM"
    echo "${CYAN}Directorio:${NC} $DIRNAME"
    echo ""
    echo "${YELLOW}${EMOJI_WARNING} POSIBLES CAUSAS:${NC}"
    echo "${CYAN}- Autenticación${NC}"
    echo "${CYAN}- Red/Instagram${NC}"
    echo "${CYAN}- Permisos${NC}"
    echo "${CYAN}- Rate limiting${NC}"
    echo ""
    echo "${BLUE}${EMOJI_INFO} Diagnóstico rápido:${NC}"
    echo "$INSTALODER $CUENTA_INSTAGRAM --stories --login=$LOGIN_INSTAGRAM --test-login"
    echo ""
    echo "${RED}${EMOJI_ERROR} LOG:${NC}"
    if [ -f "$log_file" ]; then cat "$log_file"; fi
    echo ""
    echo "Error en la ejecución: $fecha_error" > "$DIRNAME/ultimaejecucion.txt"
    exit 1
fi
