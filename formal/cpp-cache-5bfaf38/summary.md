# Resumen de la corrida / Run summary

- Fecha (UTC) / date: 2026-10-19T22:01:23Z → 2026-10-19T23:49:56Z
- Commit del modelo / model commit: 5bfaf38d328a799ba94f8ce64f61155df18d06ee
- formal/cache_model.pml sha256=f8c872d01284e91bc00f1d95b662152961862719d2f2a6de2b5446cb6f70e1c5 lineas=813
- Spin Version 6.5.2 -- 6 December 2019
- cc (Ubuntu 14.3.0-12ubuntu1~24~ppa1) 14.3.0
- AMD Ryzen 7 PRO 7840U w/ Radeon 780M Graphics; 58 GiB RAM; Ubuntu 24.04.5 LTS, kernel 6.8.0-146-generic; balanced gobernador=powersave
- Comandos / commands: spin -a cache_model.pml; cc -O2 -DNFAIR=8 -DMEMLIM=4096 -o pan pan.c; ./pan -m100000 -n -E (seguridad); ./pan -m100000 -n -E -a -f -N <propiedad> (cada LTL)

## Corrida con los parámetros del repositorio (4 GB) / Run with the repository parameters (4 GB)

| Verificación / check | Estados almacenados / stored states | Transiciones / transitions | Profundidad / depth | Memoria / memory | Tiempo / time | Errores / errors |
|---|---|---|---|---|---|---|
| Safety (30 assertions, first claim active) | 33,102,381 | 140,042,560 | 500 | 4,096 MB | 106 s | 0 in the explored part; truncated by the memory limit |
| `every_requested_key_eventually_materializes` | 11,492,902 | 867,351,390 | 642 | 4,096 MB | 437 s | 0 in the explored part; truncated by the memory limit |
| `no_starvation_thread0` | 11,526,987 | 771,590,620 | 632 | 4,096 MB | 414 s | 0 in the explored part; truncated by the memory limit |
| `no_starvation_thread1` | 11,522,188 | 763,167,620 | 673 | 4,096 MB | 446 s | 0 in the explored part; truncated by the memory limit |
| `no_starvation_thread2` | 12,052,001 | 582,464,840 | 643 | 2,187 MB | 285 s | 0 in the explored part; truncated by the memory limit |
| `no_starvation_thread3` | 12,057,439 | 615,664,660 | 642 | 2,196 MB | 358 s | 0 in the explored part; truncated by the memory limit |
| `no_starvation_thread4` | 14,828,227 | 660,781,670 | 596 | 2,555 MB | 355 s | 0 in the explored part; truncated by the memory limit |
| `no_starvation_thread5` | 14,828,228 | 660,781,670 | 594 | 2,666 MB | 361 s | 0 in the explored part; truncated by the memory limit |
| `all_terminate` | 11,601,511 | 1,047,505,700 | 683 | 4,096 MB | 474 s | 0 in the explored part; truncated by the memory limit |
| `no_orphaned_computing` | 27,012,836 | 250,906,790 | 540 | 4,096 MB | 126 s | 0 in the explored part; truncated by the memory limit |
| `saturation_transient` | 27,018,914 | 483,344,210 | 645 | 4,096 MB | 336 s | 0 in the explored part; truncated by the memory limit |

Las once búsquedas terminaron sin errores **en lo explorado**, pero 11 de las once alcanzaron el límite de 4 GB que fija el script del repositorio (`-DMEMLIM=4096`) y se detuvieron antes de agotar el espacio de estados: `pan` lo anuncia con «reached -DMEMLIM bound» y aun así imprime «errors: 0», que es lo que `run_spin.sh` comprueba para declarar PASSED en las ocho búsquedas LTL; en la de seguridad imprime PASSED en cuanto `pan` termina, sin mirar la salida. El vector de estado es de 168 bytes; «estados almacenados» cuenta estados distintos hasta la parada y «transiciones» los pasos explorados. En total, 62 minutos de verificador.

All eleven searches finished with no errors **in the explored part**, but 11 of the eleven hit the 4 GB limit set by the repository script (`-DMEMLIM=4096`) and stopped before exhausting the state space: `pan` announces it with "reached -DMEMLIM bound" and still prints "errors: 0", which is what `run_spin.sh` checks to declare PASSED for the eight LTL searches; for the safety search it prints PASSED as soon as `pan` exits, without reading the output. The state vector is 168 bytes; "stored states" counts distinct states until the stop and "transitions" the explored steps. In total, 62 minutes of verifier time.

## Intento exhaustivo con COLLAPSE y 40 GB / Exhaustive attempt with COLLAPSE and 40 GB

- cc -O2 -DNOCLAIM -DSAFETY -DCOLLAPSE -DMEMLIM=40960 -o pan_safety pan.c; ./pan_safety -m100000 -n -E (seguridad exhaustiva, sin claim); cc -O2 -DNFAIR=8 -DCOLLAPSE -DMEMLIM=40960 -o pan_collapse pan.c; ./pan_collapse -m100000 -n -E -a -f -N every_requested_key_eventually_materializes; tope de 90 min por búsqueda (SIGINT)

| Verificación / check | Estados almacenados / stored states | Transiciones / transitions | Profundidad / depth | Memoria / memory | Tiempo / time | Errores / errors |
|---|---|---|---|---|---|---|
| Safety (30 assertions), no claim, COLLAPSE, 40 GB | 537,000,000 | 2,530,000,000 | 467 | 31,841 MB | 2270 s | 0 in the explored part; process stopped by the operating system for lack of memory, no final `pan` report |

Seguridad (30 aserciones), sin *claim*, COLLAPSE, 40 GB: el sistema operativo detuvo el proceso por falta de memoria a los 38 minutos, con 537.000.000 estados almacenados, 2.530.000.000 transiciones y 31.1 GB ocupados según la última línea de progreso de `pan`; sin errores hasta ahí y sin informe final.

Safety (30 assertions), no claim, COLLAPSE, 40 GB: the operating system stopped the process for lack of memory after 38 minutes, with 537,000,000 stored states, 2,530,000,000 transitions and 31.1 GB in use according to `pan`'s last progress line; no errors up to that point and no final report.

## Corrección / Correction

20 de octubre de 2026: el modelo tiene 30 sentencias `assert`. La primera versión de este resumen decía 33, porque contaba las líneas que contienen la palabra, entre ellas un comentario, la definición de `assert_consistent()` y su llamada. Las cifras de la corrida no cambian.

October 20, 2026: the model has 30 `assert` statements. The first version of this summary said 33 because it counted the lines that contain the word, including a comment, the definition of `assert_consistent()` and its call. The run figures do not change.
