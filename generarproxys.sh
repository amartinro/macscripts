#!/bin/zsh

# Script para generar proxies de videos en Apple ProRes con audio PCM
# Búsqueda recursiva en todas las carpetas y subcarpetas
# Optimizado para detección automática en DaVinci Resolve Studio 19

# Comprobar si ffmpeg está instalado
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg no está instalado. Por favor, instálalo primero."
    exit 1
fi

# Extensiones de video comunes
extensiones_video=(mp4 mov avi mkv mxf m4v wmv flv 3gp webm)

# Obtener el número de núcleos de CPU disponibles
num_cores=$(sysctl -n hw.ncpu)
echo "Utilizando $num_cores núcleos de CPU para la codificación"

# Función para procesar un archivo de video
procesar_video() {
    local archivo="$1"
    local directorio_base=$(dirname "$archivo")
    local nombre_archivo=$(basename "$archivo")
    local nombre_base="${nombre_archivo%.*}"
    local extension="${nombre_archivo##*.}"
    local extension_lower="${extension:l}"
    
    # Crear la carpeta "Proxy" en la misma ubicación que el archivo original
    local directorio_proxy="$directorio_base/Proxy"
    mkdir -p "$directorio_proxy"
    
    # Definir ruta del archivo proxy con el mismo nombre base pero extensión .mov
    local nombre_seguro
    nombre_seguro=$(echo "$nombre_base" | tr -d '\"'\''`\\:*?<>|')
    local archivo_proxy="$directorio_proxy/${nombre_seguro}.mov"
    
    echo "Procesando video: $archivo"
    echo "Guardando proxy como: $archivo_proxy"
    
    # Eliminar archivo proxy existente si existe
    if [[ -f "$archivo_proxy" ]]; then
        echo "Eliminando proxy existente..."
        rm -f "$archivo_proxy"
    fi
    
    # Extraer timecode y frame rate del archivo original para mantenerlos idénticos
    local timecode_info=$(ffprobe -v error -select_streams v:0 -show_entries stream_tags=timecode -of default=noprint_wrappers=1:nokey=1 "$archivo" 2>/dev/null)
    local framerate=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$archivo" 2>/dev/null)
    
    # Preparar opciones de preservación de timecode
    local timecode_opts=""
    if [[ -n "$timecode_info" ]]; then
        echo "Preservando timecode: $timecode_info"
        timecode_opts="-timecode $timecode_info"
    fi
    
    # Usar codec Apple ProRes Proxy (perfil 0) con audio PCM
    # Reducir resolución a la mitad para ahorrar espacio pero mantener proporción exacta
    # Preservar timecode, metadatos y framerate exactos
    ffmpeg -y -i "$archivo" \
           -c:v prores_ks -profile:v 0 -vendor apl0 -pix_fmt yuv422p \
           $timecode_opts \
           -vf "scale=iw/2:ih/2" \
           -threads $num_cores \
           -c:a pcm_s16le \
           -map_metadata 0 \
           -movflags +faststart \
           -vsync cfr \
           -metadata "Original File"="$nombre_archivo" \
           -metadata "Original Path"="$archivo" \
           -metadata "Proxy"="true" \
           "$archivo_proxy"
    
    local resultado=$?
    if [ $resultado -eq 0 ]; then
        # Mostrar tamaño del original y del proxy para comparar
        local original_size=$(du -h "$archivo" | cut -f1)
        local proxy_size=$(du -h "$archivo_proxy" | cut -f1)
        echo "Proxy generado con éxito: $archivo_proxy"
        echo "Tamaño original: $original_size → Tamaño proxy: $proxy_size"
        return 0
    else
        echo "Error al procesar $archivo (código: $resultado)"
        echo "Eliminando archivo proxy incompleto..."
        rm -f "$archivo_proxy"
        return 1
    fi
}

# Función para encontrar videos recursivamente
buscar_videos() {
    local directorio="$1"
    local archivos_encontrados

    echo "Buscando en directorio: $directorio"
    
    # Listar todos los archivos y directorios en el directorio actual
    for item in "$directorio"/*; do
        # Si es un directorio y no se llama "Proxy", buscar recursivamente en él
        if [[ -d "$item" && "$(basename "$item")" != "Proxy" ]]; then
            buscar_videos "$item"
        # Si es un archivo, verificar si es un archivo de video
        elif [[ -f "$item" ]]; then
            local extension="${item##*.}"
            local extension_lower="${extension:l}"
            
            # Comprobar si la extensión está en la lista de extensiones de video
            for ext in "${extensiones_video[@]}"; do
                if [[ "$extension_lower" == "$ext" ]]; then
                    echo "Encontrado archivo potencial: $item"
                    archivos_video+=("$item")
                    break
                fi
            done
        fi
    done
}

# Variable para contar archivos procesados
total_procesados=0
total_exitosos=0
archivos_video=()

# Recorrer recursivamente buscando archivos de video
echo "Buscando archivos de video en el directorio actual y sus subdirectorios..."

# Usar búsqueda recursiva nativa de zsh
buscar_videos "."

# Mostrar número de archivos encontrados
echo "Se encontraron ${#archivos_video[@]} archivos potencialmente de video"

# Procesar cada archivo encontrado
for archivo in "${archivos_video[@]}"; do
    # Verificar si realmente es un video
    if ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 "$archivo" 2>/dev/null | grep -q "video"; then
        echo "Archivo de video válido: $archivo"
        # Es un archivo de video, procesarlo
        procesar_video "$archivo"
        
        if [ $? -eq 0 ]; then
            total_exitosos=$((total_exitosos + 1))
        fi
        total_procesados=$((total_procesados + 1))
    else
        echo "No es un archivo de video válido: $archivo"
    fi
done

echo "Proceso completado. Se procesaron $total_procesados archivos de video."
echo "Se generaron $total_exitosos proxies con éxito."
echo ""
echo "IMPORTANTE: Para DaVinci Resolve Studio 19"
echo "1. En Preferences, ve a 'Media Storage'"
echo "2. Asegúrate de que las carpetas que contienen tus archivos originales estén agregadas"
echo "3. En la página Project Settings, ve a 'Master Settings'"
echo "4. Activa la opción 'Automatically match source timecode' para mejor asociación"
echo "5. Configura 'Optimized Media/Proxy Media Resolution' a 'Half'"
echo "6. Activa la opción 'Use Proxy Media if Available' en el menú Playback"
echo "7. Si aún no funciona, intenta seleccionar los clips y hacer clic derecho → 'Relink clips' → seleccionando la carpeta Proxy"
