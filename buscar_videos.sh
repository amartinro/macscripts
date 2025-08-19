#!/bin/bash

# Carpeta origen y destino
ORIG="combined"
DEST="viral"

# Crear carpeta destino si no existe
mkdir -p "$DEST"

# Buscar y copiar vídeos de 10MB o menos
find "$ORIG" -type f \
    \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.webm" -o -iname "*.mpeg" -o -iname "*.mpg" -o -iname "*.m4v" \) \
    -size -10M -print0 | while IFS= read -r -d '' file; do
    echo "Copiando: $file"
    cp "$file" "$DEST/"
done

echo "Copia completada." 