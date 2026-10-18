#!/usr/bin/env python3
"""Expands scenarios.json into one line per run: name|keys|zipf|capacity|ttl|solver_latency|workers|rep|warmup|duration.
Repetitions are the outer loop so both implementations alternate and share thermal conditions."""
import json, signal, sys
signal.signal(signal.SIGPIPE, signal.SIG_DFL)
cfg = json.load(open(sys.argv[1]))
quick = "--quick" in sys.argv
reps = 1 if quick else cfg["repetitions"]
for rep in range(1, reps + 1):
    for s in cfg["scenarios"]:
        warmup = s.get("warmup", "1s" if quick else f"{cfg['warmup_s']}s")
        duration = s.get("duration", "3s" if quick else f"{cfg['duration_s']}s")
        if quick and duration.endswith("s") and float(duration[:-1]) > 3:
            duration = "3s"
        for w in s["workers"]:
            print("|".join(str(x) for x in [s["name"], s["keys"], s["zipf"], s["capacity"], s["ttl"], s["solver_latency"], w, rep, warmup, duration]))
