#!/usr/bin/env bash
# Corrida de verificación SPIN del modelo formal/cache_model.pml de cpp-cache (commit fijado), con los mismos
# comandos que formal/run_spin.sh del repositorio, más las dos propiedades LTL que ese script omite.
set -u
S=/tmp/claude-1000/-home-lrleon-simyl/5b48e757-6a08-4c3e-9e2b-14c849c06ca9/scratchpad
SRC="$S/cpp-cache-src"
OUT="$S/spin-run/out"
WORK="$S/spin-run/work"
rm -rf "$WORK" && mkdir -p "$WORK" "$OUT"
cp "$SRC/formal/cache_model.pml" "$WORK/"
cd "$WORK"
TIME=/usr/bin/time; [ -x "$TIME" ] || TIME=""
{
  echo "fecha_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repositorio: https://github.com/lrleon/cpp-cache"
  echo "commit: $(git -C "$SRC" rev-parse HEAD)"
  echo "modelo: formal/cache_model.pml sha256=$(sha256sum cache_model.pml | cut -d' ' -f1) lineas=$(wc -l < cache_model.pml)"
  echo "spin: $(spin -V)"
  echo "cc: $(cc --version | head -1)"
  echo "so: $(. /etc/os-release && echo "$PRETTY_NAME") kernel=$(uname -r) arch=$(uname -m)"
  echo "cpu: $(lscpu | grep 'Model name' | sed 's/.*: *//') nucleos=$(nproc)"
  echo "ram_total_gib: $(free -g | awk '/Mem:/{print $2}')"
  echo "energia: $(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo '?') gobernador=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo '?')"
  echo "comandos: spin -a cache_model.pml; cc -O2 -DNFAIR=8 -DMEMLIM=4096 -o pan pan.c; ./pan -m100000 -n -E (seguridad); ./pan -m100000 -n -E -a -f -N <propiedad> (cada LTL)"
} > "$OUT/environment.txt"
cat "$OUT/environment.txt"
echo "=== 1. script del repositorio: formal/run_spin.sh ==="
( cd "$SRC" && bash formal/run_spin.sh ) > "$OUT/run_spin.sh.txt" 2>&1; echo "run_spin.sh exit=$?" | tee -a "$OUT/run_spin.sh.txt"
echo "=== 2. corrida detallada (mismos comandos, salida completa por propiedad) ==="
spin -a cache_model.pml > "$OUT/spin-a.txt" 2>&1 || { echo "spin -a falló"; cat "$OUT/spin-a.txt"; exit 1; }
cc -O2 -DNFAIR=8 -DMEMLIM=4096 -o pan pan.c > "$OUT/cc.txt" 2>&1 || { echo "cc falló"; cat "$OUT/cc.txt"; exit 1; }
run_one() { # nombre, args...
  local name=$1; shift
  echo "--- $name: ./pan $*"
  if [ -n "$TIME" ]; then $TIME -v ./pan "$@" > "$OUT/$name.txt" 2> "$OUT/$name.time"; else { time ./pan "$@"; } > "$OUT/$name.txt" 2> "$OUT/$name.time"; fi
  echo "exit=$?" >> "$OUT/$name.time"
  grep -E 'errors:|State-vector|states, stored|states, matched|transitions|atomic steps|total actual memory|elapsed time|pan: |depth reached|out of memory|max search depth' "$OUT/$name.txt" | head -12
  grep -E 'Maximum resident|Elapsed \(wall|exit=' "$OUT/$name.time" | sed 's/^\s*/    /'
}
run_one safety -m100000 -n -E
for prop in every_requested_key_eventually_materializes no_starvation_thread0 no_starvation_thread1 no_starvation_thread2 no_starvation_thread3 no_starvation_thread4 no_starvation_thread5 all_terminate no_orphaned_computing saturation_transient; do
  run_one "ltl-$prop" -m100000 -n -E -a -f -N "$prop"
done
echo "fin_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT/environment.txt"
