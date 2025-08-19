#!/bin/zsh

#INSTALODER="/opt/homebrew/bin/instaloader"
INSTALODER="/Users/amartin/.local/pipx/venvs/instaloader/bin/instaloader"
FFMPEG="/opt/homebrew/bin/ffmpeg"

# Función para mostrar el uso del script
mostrar_ayuda() {
    echo "Uso: $0 <cuenta_instagram> <login_instagram> <directorio_destino> [proxy]"
    echo "Ejemplo: $0 usuario_instagram mi_login_instagram /ruta/destino/"
    echo "Ejemplo con proxy: $0 usuario_instagram mi_login_instagram /ruta/destino/ http://usuario:contraseña@direccion:puerto"
    exit 1
}

# Verificar que se han proporcionado los parámetros necesarios
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "ERROR: Número incorrecto de parámetros"
    mostrar_ayuda
fi

CUENTA_INSTAGRAM="$1"
LOGIN_INSTAGRAM="$2"
DIRNAME="$3"
PROXY=""

# Si se proporciona un proxy, lo configuramos
if [ $# -eq 4 ]; then
    PROXY="--proxy $4"
    echo "Usando proxy: $4"
fi

# Verifica que existan las herramientas necesarias
if [ ! -f "$INSTALODER" ]; then
    echo "ERROR: No se encuentra instaloader en $INSTALODER"
    echo "Por favor, instala instaloader usando: brew install instaloader"
    exit 1
fi

# Array de user agents de dispositivos móviles

USER_AGENTS=(
    "Mozilla/5.0 (iPhone14,7; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1 Instagram 310.0.0.41.100"
    "Mozilla/5.0 (Linux; Android 13; CPH2413 Nothing Phone 2A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36 Instagram 310.0.0.41.100"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.7049.115 Safari/537.36"
)

# Selecciona un user agent aleatorio
RANDOM_INDEX=$((RANDOM % ${#USER_AGENTS[@]}))
SELECTED_USER_AGENT="${USER_AGENTS[$RANDOM_INDEX]}"

if [ ! -f "$FFMPEG" ]; then
    echo "ERROR: No se encuentra ffmpeg en $FFMPEG"
    echo "Por favor, instala ffmpeg usando: brew install ffmpeg"
    exit 1
fi

# Verifica que el directorio de destino existe
if [ ! -d "$DIRNAME" ]; then
    echo "ERROR: El directorio de destino no existe: $DIRNAME"
    echo "Por favor, crea el directorio o verifica la ruta"
    exit 1
fi

# Función para limpiar archivos antiguos
limpiar_archivos_antiguos() {
    echo "Comprobando archivos antiguos..."
    
    # Obtiene la fecha actual en formato epoch
    fecha_actual=$(date +%s)
    
    # Establece nullglob para que los patrones que no coincidan se expandan a una lista vacía
    setopt nullglob 2>/dev/null || shopt -s nullglob 2>/dev/null
    
    # Procesa los archivos MP4
    for archivo in "$DIRNAME"/*.mp4; do
        procesar_archivo "$archivo"
    done
    
    # Procesa los archivos JPG
    for archivo in "$DIRNAME"/*.jpg; do
        procesar_archivo "$archivo"
    done
    
    # Restaura la configuración original
    unsetopt nullglob 2>/dev/null || shopt -u nullglob 2>/dev/null
}

# Función auxiliar para procesar cada archivo
procesar_archivo() {
    local archivo="$1"
    
    # Verifica que el archivo existe
    [ -f "$archivo" ] || return
    
    # Extrae la fecha del nombre del archivo
    nombre_archivo=$(basename "$archivo")
    fecha_archivo="${nombre_archivo:0:10} ${nombre_archivo:11:2}:${nombre_archivo:14:2}:${nombre_archivo:17:2}"
    fecha_archivo_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$fecha_archivo" +%s 2>/dev/null)
    
    # Verifica si se pudo procesar la fecha
    if [ $? -ne 0 ]; then
        echo "AVISO: No se pudo procesar la fecha del archivo: $nombre_archivo"
        return
    fi
    
    # Calcula la diferencia en horas
    diferencia_segundos=$((fecha_actual - fecha_archivo_epoch))
    diferencia_horas=$((diferencia_segundos / 3600))
    
    # Si el archivo tiene más de 25 horas, lo borra
    if [ $diferencia_horas -gt 25 ]; then
        extension="${nombre_archivo##*.}"
        echo "Eliminando archivo antiguo ($diferencia_horas horas): $nombre_archivo"
        rm "$archivo"
        ((archivos_eliminados++))
    fi
}

# Inicializa contador de archivos eliminados
archivos_eliminados=0

# Ejecuta la limpieza
limpiar_archivos_antiguos

# Función para introducir retrasos aleatorios entre peticiones
introducir_retraso() {
    # Genera un retraso aleatorio entre 2 y 10 segundos
    local retraso=$(( (RANDOM % 8) + 2 ))
    echo "Esperando $retraso segundos antes de continuar..."
    sleep $retraso
}

# Eliminar la sesión existente (opcional, descomentar si necesario)
# rm -f ~/.config/instaloader/session-${LOGIN_INSTAGRAM}

# Introducir retraso inicial aleatorio
introducir_retraso

# Ejecuta instaloader con las opciones configuradas
COMANDO="$INSTALODER $CUENTA_INSTAGRAM --stories --no-pictures --no-video-thumbnails --no-captions --no-metadata-json --no-posts --no-profile-pic --login=$LOGIN_INSTAGRAM --dirname-pattern \"$DIRNAME\" --user-agent=\"$SELECTED_USER_AGENT\" --request-timeout=60 --max-connection-attempts=3 $PROXY"

echo "Ejecutando: $COMANDO"

if eval $COMANDO; then
    
    # Si instaloader se ejecuta correctamente, organiza y convierte los archivos .mp4
    if ! cd "$DIRNAME"; then
        echo "ERROR: No se pudo acceder al directorio $DIRNAME"
        exit 1
    fi

    # Verifica si hay archivos MP4 para procesar
    if ! ls *.mp4 >/dev/null 2>&1; then
        echo "AVISO: No se encontraron archivos MP4 para procesar"
        fecha_actual=$(date +"%Y-%m-%d %H:%M:%S")
        echo "Ejecución completada sin archivos: $fecha_actual" > "$DIRNAME/ultimaejecucion.txt"
        exit 0
    fi

    # Crea el directorio converted si no existe
    mkdir -p "converted" || {
        echo "ERROR: No se pudo crear el directorio 'converted'"
        exit 1
    }

    # Inicializa contador de archivos omitidos
    archivos_omitidos=0

    # Itera sobre cada archivo .mp4
    for f in *.mp4; do
        fecha="${f:0:10}"
        
        # Crea la carpeta con el nombre de la fecha
        if ! mkdir -p "converted/$fecha"; then
            echo "ERROR: No se pudo crear el directorio converted/$fecha"
            continue
        fi

        archivo_convertido="converted/$fecha/${f%.mp4}.mp4"

        if [ ! -f "$archivo_convertido" ]; then
            echo "Convirtiendo: $f -> $archivo_convertido"
            if ! $FFMPEG -n -i "$f" -r 24 "$archivo_convertido"; then
                echo "ERROR: Falló la conversión de $f"
                continue
            fi
            echo "Conversión exitosa: $f"
        else
            echo "AVISO: El archivo '$archivo_convertido' ya existe, omitiendo conversión."
            ((archivos_omitidos++))
        fi
    done

    # Genera el log de ejecución exitosa
    fecha_actual=$(date +"%Y-%m-%d %H:%M:%S")
    echo "Última ejecución exitosa: $fecha_actual" > "$DIRNAME/ultimaejecucion.txt"
    
    # Cuenta el número de archivos procesados
    num_archivos=$(ls -1 *.mp4 2>/dev/null | wc -l)
    num_convertidos=$(find converted -name "*.mp4" 2>/dev/null | wc -l)
    
    # Mensaje de éxito detallado
    echo "┌────────────────────────────────────────┐"
    echo "│         PROCESO COMPLETADO             │"
    echo "├────────────────────────────────────────┤"
    echo "│ ✓ Descarga de stories completada      │"
    echo "│ ✓ Archivos antiguos eliminados: $archivos_eliminados    │"
    echo "│ ✓ Archivos encontrados: $num_archivos        │"
    echo "│ ✓ Archivos convertidos: $((num_archivos - archivos_omitidos))        │"
    echo "│ ✓ Archivos omitidos: $archivos_omitidos          │"
    echo "│ ✓ Total en converted: $num_convertidos        │"
    echo "│ ✓ Fecha: $fecha_actual    │"
    echo "└────────────────────────────────────────┘"

else
    # Si instaloader falla, registra el error en el log
    fecha_error=$(date +"%Y-%m-%d %H:%M:%S")
    echo "ERROR: Falló la descarga de stories de Instagram"
    echo "Error en la ejecución: $fecha_error" > "$DIRNAME/ultimaejecucion.txt"
    exit 1
fi