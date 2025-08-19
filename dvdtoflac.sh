#!/bin/bash

# Script para extraer pistas de audio individuales de un DVD/MKV con metadatos
# Uso: ./extract_audio.sh archivo.mkv

input_file="$1"
output_dir="${2:-./pistas_audio}"
base_name=$(basename "${input_file%.*}")

# Crear directorio de salida si no existe
mkdir -p "$output_dir"

echo "Analizando pistas de audio en $input_file..."

# Obtener información sobre todas las pistas de audio
ffprobe -i "$input_file" -show_entries stream=index:stream_tags=language,title -select_streams a -v 0 -of json > /tmp/audio_tracks.json

# Obtener el número de pistas de audio
num_tracks=$(ffprobe -i "$input_file" -show_entries stream=index -select_streams a -v 0 -of compact | wc -l)
echo "Se encontraron $num_tracks pistas de audio"

# Extraer cada pista de audio con sus metadatos correspondientes
for ((i=0; i<num_tracks; i++)); do
  # Obtener idioma
  lang=$(ffprobe -i "$input_file" -show_entries stream_tags=language -select_streams a:$i -v 0 -of compact | grep -o "tag:language=[^|]*" | cut -d'=' -f2)
  if [ -z "$lang" ]; then
    lang="unknown"
  fi
  
  # Obtener título
  title=$(ffprobe -i "$input_file" -show_entries stream_tags=title -select_streams a:$i -v 0 -of compact | grep -o "tag:title=[^|]*" | cut -d'=' -f2)
  if [ -z "$title" ]; then
    title="Track $i"
  fi
  
  # Eliminar caracteres problemáticos del título para el nombre de archivo
  clean_title=$(echo "$title" | tr -cd '[:alnum:][:space:]._-')
  
  # Obtener codec de audio y tasa de bits
  codec=$(ffprobe -i "$input_file" -show_entries stream=codec_name -select_streams a:$i -v 0 -of compact | grep -o "codec_name=[^|]*" | cut -d'=' -f2)
  bitrate=$(ffprobe -i "$input_file" -show_entries stream=bit_rate -select_streams a:$i -v 0 -of compact | grep -o "bit_rate=[^|]*" | cut -d'=' -f2)
  
  # Nombre de archivo final
  output_file="${output_dir}/${base_name}_${i}_${lang}_${clean_title}.flac"
  
  echo "Extrayendo pista $i: $title ($lang, $codec)"
  
  # Extraer la pista de audio y mantener los metadatos
  ffmpeg -i "$input_file" -map 0:a:$i \
    -metadata title="$title" \
    -metadata track="$i" \
    -metadata language="$lang" \
    -c:a flac -compression_level 8 \
    "$output_file"
  
  echo "  → Guardado como: $output_file"
done

echo "¡Extracción completada! Todos los archivos FLAC se guardaron en $output_dir"