#!/usr/bin/env bash
# Intento exhaustivo: la corrida con los parámetros del repositorio alcanzó el límite de 4 GB en las once verificaciones.
# Aquí se repiten dos búsquedas con compresión COLLAPSE y 40 GB de límite, con tope de 90 minutos cada una (SIGINT para que pan imprima su informe parcial).
set -u
S=/tmp/claude-1000/-home-lrleon-simyl/5b48e757-6a08-4c3e-9e2b-14c849c06ca9/scratchpad
OUT="$S/spin-run/out"; WORK="$S/spin-run/work"
cd "$WORK"
echo "extra_inicio_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT/environment.txt"
echo "extra_comandos: cc -O2 -DNOCLAIM -DSAFETY -DCOLLAPSE -DMEMLIM=40960 -o pan_safety pan.c; ./pan_safety -m100000 -n -E (seguridad exhaustiva, sin claim); cc -O2 -DNFAIR=8 -DCOLLAPSE -DMEMLIM=40960 -o pan_collapse pan.c; ./pan_collapse -m100000 -n -E -a -f -N every_requested_key_eventually_materializes; tope de 90 min por búsqueda (SIGINT)" | tee -a "$OUT/environment.txt"
cc -O2 -DNOCLAIM -DSAFETY -DCOLLAPSE -DMEMLIM=40960 -o pan_safety pan.c > "$OUT/cc-safety-noclaim.txt" 2>&1 || { echo "cc (safety) falló"; cat "$OUT/cc-safety-noclaim.txt"; exit 1; }
echo "--- safety-noclaim-collapse-40g"
/usr/bin/time -v timeout -s INT 5400 ./pan_safety -m100000 -n -E > "$OUT/safety-noclaim-collapse-40g.txt" 2> "$OUT/safety-noclaim-collapse-40g.time"; echo "exit=$?" >> "$OUT/safety-noclaim-collapse-40g.time"
grep -E 'errors:|states, stored|transitions|total actual memory|elapsed time|reached -DMEMLIM|interrupted|pan: ' "$OUT/safety-noclaim-collapse-40g.txt" | head -8; grep -E 'Maximum resident|Elapsed \(wall|exit=' "$OUT/safety-noclaim-collapse-40g.time"
cc -O2 -DNFAIR=8 -DCOLLAPSE -DMEMLIM=40960 -o pan_collapse pan.c > "$OUT/cc-collapse.txt" 2>&1 || { echo "cc (collapse) falló"; cat "$OUT/cc-collapse.txt"; exit 1; }
echo "--- ltl-every_requested_key_eventually_materializes-collapse-40g"
/usr/bin/time -v timeout -s INT 5400 ./pan_collapse -m100000 -n -E -a -f -N every_requested_key_eventually_materializes > "$OUT/ltl-every_requested_key_eventually_materializes-collapse-40g.txt" 2> "$OUT/ltl-every_requested_key_eventually_materializes-collapse-40g.time"; echo "exit=$?" >> "$OUT/ltl-every_requested_key_eventually_materializes-collapse-40g.time"
grep -E 'errors:|states, stored|transitions|total actual memory|elapsed time|reached -DMEMLIM|interrupted|pan: ' "$OUT/ltl-every_requested_key_eventually_materializes-collapse-40g.txt" | head -8; grep -E 'Maximum resident|Elapsed \(wall|exit=' "$OUT/ltl-every_requested_key_eventually_materializes-collapse-40g.time"
echo "extra_fin_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT/environment.txt"
