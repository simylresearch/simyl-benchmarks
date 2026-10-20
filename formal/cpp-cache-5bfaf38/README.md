# SPIN verification run of the cpp-cache Promela model (commit 5bfaf38)

**What.** The Promela model `formal/cache_model.pml` of [`lrleon/cpp-cache`](https://github.com/lrleon/cpp-cache) at commit `5bfaf38` (March 30, 2026), checked with SPIN 6.5.2 exactly as the repository's `formal/run_spin.sh` does it, plus the two LTL properties that script omits, plus an attempt with more memory. The article that explains the model and this run: [Formal verification of a C++ cache with SPIN/Promela](https://simylresearch.com/en/blog/formal-verification-cpp-cache-spin-promela/) ([Spanish](https://simylresearch.com/es/blog/verificacion-formal-cache-cpp-spin-promela/)).

**Where and when.** October 19, 2026, on the machine declared in [How we measure](https://simylresearch.com/en/method/): AMD Ryzen 7 PRO 7840U, 58 GiB of RAM, Ubuntu 24.04, laptop on mains power with the `balanced` profile and the `powersave` governor. Exact versions, SHA-256 of the model and timestamps are in `raw/environment.txt`.

**Result in one line.** With the repository parameters (`-DMEMLIM=4096`), all eleven searches (safety and the ten LTL properties) report `errors: 0` for the explored part, but every one of them stopped at the 4 GB memory bound before exhausting the state space; the repository script reports PASSED anyway: it greps `errors: 0` for the LTL searches and prints PASSED for the safety search as soon as `pan` exits. Note that its safety search runs with the first LTL claim of the model active (no `-N`, no `-DNOCLAIM`). The second attempt (COLLAPSE compression, 40 GB, 90-minute cap per search) is reported in `summary.md`. These are results for the bounded model, not a proof of correctness of the C++ code.

## Files

| File | Content |
|---|---|
| `summary.md`, `summary.json` | Tables with stored states, transitions, depth, memory, time and status per search, in English and Spanish |
| `run.sh` | The driver we ran: environment capture, the repository script, then each search separately with full output |
| `run-extra.sh` | The second attempt: safety without claim (`-DNOCLAIM -DSAFETY -DCOLLAPSE -DMEMLIM=40960`) and one LTL property with COLLAPSE |
| `raw/environment.txt` | Date, commit, SHA-256 of the model, SPIN and compiler versions, OS, CPU, RAM, power profile, commands |
| `raw/run_spin.sh.txt` | Output of the repository script as is (PASSED lines) |
| `raw/safety.txt`, `raw/ltl-*.txt` | Full `pan` output of each search with the repository parameters |
| `raw/*-collapse-40g.txt` | Full `pan` output of the second attempt |
| `raw/*.time` | `/usr/bin/time -v` of each search (wall clock, peak resident memory, exit code) |
| `raw/cache_model.pml` | Copy of the model as verified (same SHA-256 as the commit) |

## How to reproduce

```bash
git clone https://github.com/lrleon/cpp-cache && cd cpp-cache && git checkout 5bfaf38
sudo apt install spin            # Ubuntu 24.04 ships 6.5.2
bash formal/run_spin.sh          # repository parameters: 4 GB, 8 of the 10 LTL properties
# each search separately, with full output (see run.sh):
cd formal && spin -a cache_model.pml && cc -O2 -DNFAIR=8 -DMEMLIM=4096 -o pan pan.c
./pan -m100000 -n -E                                  # "safety" as the script runs it (first claim active)
./pan -m100000 -n -E -a -f -N no_orphaned_computing   # one LTL property
# assertions only, with compression and more memory (see run-extra.sh):
cc -O2 -DNOCLAIM -DSAFETY -DCOLLAPSE -DMEMLIM=40960 -o pan_safety pan.c && ./pan_safety -m100000 -n -E
```

Read the end of each `pan` output: `reached -DMEMLIM bound` means the search was truncated, whatever `errors:` says.

---

# Corrida de verificación SPIN del modelo Promela de cpp-cache (commit 5bfaf38)

**Qué.** El modelo Promela `formal/cache_model.pml` de [`lrleon/cpp-cache`](https://github.com/lrleon/cpp-cache) en el commit `5bfaf38` (30 de marzo de 2026), comprobado con SPIN 6.5.2 tal como lo hace `formal/run_spin.sh` del repositorio, más las dos propiedades LTL que ese script omite, más un intento con más memoria. El artículo que explica el modelo y esta corrida: [Verificación formal de una caché C++ con SPIN/Promela](https://simylresearch.com/es/blog/verificacion-formal-cache-cpp-spin-promela/).

**Dónde y cuándo.** 19 de octubre de 2026, en la máquina declarada en [Cómo medimos](https://simylresearch.com/es/metodo/): AMD Ryzen 7 PRO 7840U, 58 GiB de RAM, Ubuntu 24.04, portátil conectado a la corriente con perfil `balanced` y gobernador `powersave`. Versiones exactas, SHA-256 del modelo y marcas de tiempo en `raw/environment.txt`.

**Resultado en una línea.** Con los parámetros del repositorio (`-DMEMLIM=4096`), las once búsquedas (seguridad y las diez propiedades LTL) informan `errors: 0` en la parte explorada, pero todas se detuvieron en el límite de 4 GB antes de agotar el espacio de estados; el script del repositorio las declara PASSED igual: busca `errors: 0` en las búsquedas LTL e imprime PASSED en la de seguridad en cuanto `pan` termina. Su búsqueda de seguridad corre con el primer *claim* LTL del modelo activo (sin `-N` ni `-DNOCLAIM`). El segundo intento (compresión COLLAPSE, 40 GB, tope de 90 minutos por búsqueda) está en `summary.md`. Son resultados del modelo acotado, no una demostración de corrección del código C++.

Los archivos y la forma de reproducirlo están descritos arriba, en inglés.
