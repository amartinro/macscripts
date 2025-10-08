import os
import re
from yt_dlp import YoutubeDL

# Lista de propietarios y URLs
videos = [
    ("Daniel Morales @danielhipnosisconfianza", "https://youtu.be/oknWHxIDnAk"),
    ("Emerson Benítez @emerson__benitez", "https://youtu.be/iHXaYCa6Z98"),
    ("Belén Soto @belensototrafficker", "https://youtu.be/ZTCB5IKfhC4"),
    ("Alejandro Castillo (Rasta)", "https://youtu.be/d_tH_B_B3AE"),
    ("Shahid Khan", "https://youtu.be/flu-JPRxaM8"),  # el linktw.in no sirve para yt-dlp
    ("Iñaut", "https://youtu.be/flu-JPRxaM8"),
    ("@sanaconisa", "https://youtu.be/zoW_dYF2k3s"),
    ("@antoniorodriguez.fit", "https://youtu.be/kyoqCmLvhQo"),
    ("Víctor entrenadores fútbol", "https://youtu.be/qh2qHEl0lk0"),
    ("@sebasmindset_", "https://youtu.be/6WkgVzho6wo"),
    ("@nidiadiazcoach", "https://youtu.be/ptLUM5BkBX4"),
    ("@oscarjmedina85", "https://youtu.be/4NxRG-5Vyvw"),
    ("@vasquezfitness_", "https://youtu.be/t2Tthh_Shnc"),
    ("@michaelmensoza191998", "https://youtu.be/CVqkO8Xv_Pc"),
    ("@paolo_inostroza", "https://youtu.be/iGQfsudZ0FE"),
    ("@zunigadespierta", "https://youtu.be/Mkg0vaALtBA"),
    ("@marcfitnessx", "https://youtu.be/VdNen1QPbB8"),
    ("@bruno.massfitness", "https://youtu.be/vXJtg2fmMXY"),
    ("@nestorperdomo_", "https://youtu.be/aBmBTmSLKS0"),
    ("@angespinoza_", "https://youtu.be/B_3aZEBcMxA"),
    ("Samuel Franco @samuelfranco.oficial", "https://youtu.be/W9wWqh0gdxY"),
    ("Álvaro de la piedra", "https://youtu.be/V4Md5sF1PeE"),
    ("@sergiomendez.psicorienta", "https://youtu.be/YnhG-Nnznu4"),
    ("Sebastián", "https://youtu.be/9tTjPMm2hGE"),
    ("@mateosip", "https://youtu.be/eiuW1YpiNPI"),
    ("@pollomauri", "https://youtu.be/a2nRi_06kyY"),
    ("@elliotsindeart", "https://youtu.be/Hr6HUTZTWVM"),
    ("@suyaymainero", "https://youtu.be/rNwG6wp08ok"),
    ("@alejandroflo851", "https://youtu.be/TIV_gNsTHsQ"),
    ("@bruno.masfitness", "https://youtu.be/vXJtg2fmMXY"),
    ("@sergiobustamantej", "https://youtu.be/0z3BpDs6g4U")
]

# Carpeta de salida
output_path = "videos"
os.makedirs(output_path, exist_ok=True)

# Limpiar caracteres problemáticos
def clean_text(text):
    text = re.sub(r'[^\w\s\.-]', '', text)  # quita símbolos raros
    return text.strip()

# Progreso
def progress(d):
    if d['status'] == 'downloading':
        print(f"⬇ {d.get('_percent_str','')} | {d.get('_speed_str','')} | ETA {d.get('_eta_str','')}", end="\r")
    elif d['status'] == 'finished':
        print(f"\n✔ Descarga completada: {d['filename']}")

# Config base de yt-dlp
base_opts = {
    "format": "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b",
    "merge_output_format": "mp4",
    "progress_hooks": [progress],
    "quiet": True
}

try:
    with YoutubeDL(base_opts) as ydl:
        for owner, url in videos:
            owner_clean = clean_text(owner)
            info = ydl.extract_info(url, download=False)
            title = clean_text(info.get("title", "video"))
            filename = f"{owner_clean} - {title}.mp4"
            ydl_opts = base_opts.copy()
            ydl_opts["outtmpl"] = os.path.join(output_path, filename)
            with YoutubeDL(ydl_opts) as ydl2:
                print(f"\n▶ Descargando: {filename}")
                ydl2.download([url])
except KeyboardInterrupt:
    print("\n⛔ Interrumpido por el usuario (Cmd+C).")