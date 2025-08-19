#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, sys, time, curses, heapq, signal, argparse
from collections import deque
from stat import S_ISREG

SPINNER = deque("|/-\\")
REFRESH_EVERY = 200
EXCLUDE_DIRS = {
    "/System/Volumes/Data/.Spotlight-V100",
    "/System/Volumes/Data/.fseventsd",
    "/System/Volumes/Data/.DocumentRevisions-V100",
    "/System/Volumes/Data/.TemporaryItems",
    "/System/Volumes/Data/private/var/db/dyld",
    "/System/Volumes/Preboot",
    "/System/Volumes/Update",
    "/System/Volumes/VM",
    "/dev", "/proc", "/net", "/Network",
}

def human(b):
    units = ["B","KB","MB","GB","TB","PB"]
    for i,u in enumerate(units):
        if b < 1024**(i+1):
            return f"{b/1024**i:.2f} {u}"
    return f"{b/1024**(len(units)-1):.2f} {units[-1]}"

class TopN:
    def __init__(self, n): self.n, self.h = n, []
    def push(self, size, path):
        if len(self.h) < self.n: heapq.heappush(self.h, (size, path))
        elif size > self.h[0][0]: heapq.heapreplace(self.h, (size, path))
    def sorted(self): return sorted(self.h, key=lambda x: x[0], reverse=True)

stop = False
def handle_sigint(sig, frame):
    global stop; stop = True

def walk_files(root, root_dev, ui):
    stack, seen = [root], set()  # seen -> dedup por (st_dev, st_ino)
    while stack and not stop:
        d = stack.pop()
        if os.path.islink(d) or d in EXCLUDE_DIRS: continue
        try:
            if os.stat(d, follow_symlinks=False).st_dev != root_dev:  # evita montajes externos
                continue
        except (PermissionError, FileNotFoundError):
            ui['denied'] += 1; continue
        try:
            with os.scandir(d) as it:
                for e in it:
                    if stop: return
                    try:
                        st = e.stat(follow_symlinks=False)
                    except (PermissionError, FileNotFoundError):
                        ui['denied'] += 1; continue
                    if st.st_dev != root_dev:  # ignora otros discos/volúmenes
                        continue
                    key = (st.st_dev, st.st_ino)
                    if key in seen:  # dedup hardlinks/rutas espejo APFS
                        continue
                    seen.add(key)
                    if e.is_dir(follow_symlinks=False):
                        stack.append(e.path)
                    elif e.is_file(follow_symlinks=False):
                        ui['current'] = e.path
                        yield e, st
        except (PermissionError, FileNotFoundError):
            ui['denied'] += 1; continue

def draw_ui(stdscr, width, topn, files_scanned, bytes_total, ui, bar_w, bar_pos, spin, done=False):
    stdscr.erase()
    elapsed = time.time() - ui['start']
    stdscr.addstr(0, 0, f"Escaneo {spin if not done else '✓'} | Archivos: {files_scanned:,}  Ocupado: {human(bytes_total)}  Denegados: {ui['denied']:,}  Tiempo: {elapsed:,.1f}s")
    bar = [" "] * bar_w; bar[bar_pos] = "#"
    stdscr.addstr(2, 0, "[" + "".join(bar) + "]")
    stdscr.addstr(4, 0, "Analizando:")
    stdscr.addstr(5, 0, (ui.get('current','')[:max(10, width-1)]))
    stdscr.addstr(7, 0, f"Top {len(topn.h)} ficheros más grandes (ocupación real):")
    stdscr.addstr(8, 0, f"{'Tamaño':>12}  Ruta")
    row = 9
    for size, path in topn.sorted():
        line = f"{human(size):>12}  {path[:max(10, width-15)]}"
        if row < curses.LINES - 1: stdscr.addstr(row, 0, line); row += 1
    stdscr.addstr(curses.LINES-1, 0, "Pulsa 'q' para salir." if not done else "Finalizado.")
    stdscr.refresh()

def run_scan(stdscr, start_path, N):
    curses.curs_set(0); stdscr.nodelay(True)
    _, width = stdscr.getmaxyx()
    root_dev = os.stat(start_path, follow_symlinks=False).st_dev
    topn = TopN(N); files_scanned = 0; bytes_total = 0
    ui = {'current':'','denied':0,'start':time.time()}
    last = 0; bar_w = max(10, min(50, width-20)); bar_pos = 0

    for e, st in walk_files(start_path, root_dev, ui):
        try:
            if S_ISREG(st.st_mode):
                # tamaño REAL ocupado; fallback a tamaño lógico
                size = (st.st_blocks * 512) if getattr(st, "st_blocks", 0) else st.st_size
                bytes_total += size
                topn.push(size, e.path)
                files_scanned += 1
        except Exception:
            ui['denied'] += 1; continue
        if files_scanned % REFRESH_EVERY == 0 or (time.time()-last) > 0.2:
            bar_pos = (bar_pos + 1) % bar_w; SPINNER.rotate(1)
            draw_ui(stdscr, width, topn, files_scanned, bytes_total, ui, bar_w, bar_pos, SPINNER[0])
            last = time.time()
        try:
            ch = stdscr.getch()
            if ch in (ord('q'), ord('Q')): break
        except curses.error:
            pass
    draw_ui(stdscr, width, topn, files_scanned, bytes_total, ui, bar_w, bar_pos, SPINNER[0], done=True)
    time.sleep(0.2)
    return topn.sorted(), files_scanned, bytes_total, ui

def main():
    signal.signal(signal.SIGINT, handle_sigint)
    p = argparse.ArgumentParser(description="Top N ficheros más grandes por ocupación real en el mismo sistema de ficheros.")
    p.add_argument("path", nargs="?", default="/", help="Ruta inicial. Por defecto '/'.")
    p.add_argument("-n", type=int, default=10, help="Número de ficheros a mostrar. Por defecto 10.")
    args = p.parse_args()

    start_path = args.path
    if not os.path.exists(start_path): print("Ruta no válida.", file=sys.stderr); sys.exit(1)
    if not sys.stdout.isatty(): print("Ejecuta en un terminal interactivo.", file=sys.stderr); sys.exit(1)

    results, count, total, ui = curses.wrapper(lambda stdscr: run_scan(stdscr, start_path, args.n))

    print(f"\n=== Top {args.n} ficheros más grandes (mismo disco, espacio ocupado) ===")
    if not results: print("Sin resultados."); sys.exit(0)
    size_col = 12
    print(f"{'Tamaño':>{size_col}}  Ruta")
    print("-" * 100)
    for size, path in results:
        print(f"{human(size):>{size_col}}  {path}")
    print("\nResumen:")
    print(f"- Ficheros escaneados: {count:,}")
    print(f"- Ocupación total:     {human(total)}")
    print(f"- Rutas denegadas:     {ui['denied']:,}")
    print(f"- Tiempo total:        {time.time() - ui['start']:.1f}s")

if __name__ == "__main__":
    main()