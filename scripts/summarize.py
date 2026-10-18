#!/usr/bin/env python3
"""Aggregates raw/results.jsonl of a run into RESULTS.md and summary.json:
median across repetitions per (scenario, workers, implementation), with min–max throughput."""
import json, statistics, sys
from pathlib import Path

run = Path(sys.argv[1])
wall = None
if "--wall-seconds" in sys.argv:
    wall = int(sys.argv[sys.argv.index("--wall-seconds") + 1])
rows = [json.loads(l) for l in (run / "raw" / "results.jsonl").read_text().splitlines() if l.strip()]
env = json.loads((run / "environment.json").read_text())
groups = {}
for r in rows:
    groups.setdefault((r["scenario"], r["workers"], r["impl"]), []).append(r)

def med(rs, k):
    return statistics.median(x[k] for x in rs)

summary = []
for (scenario, workers, impl), rs in sorted(groups.items()):
    summary.append({
        "scenario": scenario, "workers": workers, "impl": impl, "runs": len(rs),
        "throughput_rps": med(rs, "throughput_rps"), "throughput_min": min(x["throughput_rps"] for x in rs),
        "throughput_max": max(x["throughput_rps"] for x in rs),
        "p50_us": med(rs, "p50_us"), "p99_us": med(rs, "p99_us"), "p999_us": med(rs, "p999_us"), "max_us": med(rs, "max_us"),
        "solver_calls": med(rs, "solver_calls"), "solver_mean_us": med(rs, "solver_mean_us"), "hits": med(rs, "hits"), "misses": med(rs, "misses"),
        "errors": sum(x["errors"] for x in rs), "rss_mb": med(rs, "rss_mb"), "duration_s": med(rs, "duration_s"),
        "version": rs[0]["version"], "runtime": rs[0]["runtime"],
    })
(run / "summary.json").write_text(json.dumps({"environment": env, "wall_seconds": wall, "results": summary}, indent=2))

def fmt(v):
    return f"{v:,.0f}" if v >= 100 else f"{v:,.1f}"

cpu, power = env["cpu"], env["power"]
lines = [f"# Results — {run.name}", "",
         f"- CPU: {cpu['model']} ({cpu['cores_per_socket']} cores, {cpu['cpus']} threads, L3 {cpu['l3']}); memory {env['memory']['total']}; {env['os']['name']}, kernel {env['os']['kernel']}.",
         f"- Power: driver {power['scaling_driver']}, governor {power['governor']}, EPP {power['energy_performance_preference']}, platform profile {power['platform_profile']}, boost {power['boost']}, AC {power['ac_online']}.",
         f"- Toolchain: {env['toolchain']['go']}; {env['toolchain']['cxx']}; {env['toolchain']['cmake']}.",
         f"- Sources: gateway_cache {env['sources']['gateway_cache']}; cpp-cache {env['sources'].get('CPPCACHE_COMMIT','?')[:7]}; Aleph-w {env['sources'].get('ALEPH_COMMIT','?')[:7]}; harness {env['sources']['simyl_benchmarks_commit']}.",
         f"- Protocol: each cell is the median of {max(s['runs'] for s in summary)} runs of {fmt(summary[0]['duration_s'])} s after a warm-up; percentiles come from a log-linear histogram (≈6 % resolution); throughput shows min–max across runs." + (f" Total wall time {wall} s." if wall else ""),
         ""]
for scenario in dict.fromkeys(s["scenario"] for s in summary):
    lines += [f"## {scenario}", "", "| impl | workers | req/s (median) | min–max | p50 µs | p99 µs | p99.9 µs | max µs | solver calls | solver mean µs | hits | misses | RSS MB |", "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for s in [x for x in summary if x["scenario"] == scenario]:
        lines.append(f"| {s['impl']} | {s['workers']} | {fmt(s['throughput_rps'])} | {fmt(s['throughput_min'])}–{fmt(s['throughput_max'])} | {fmt(s['p50_us'])} | {fmt(s['p99_us'])} | {fmt(s['p999_us'])} | {fmt(s['max_us'])} | {fmt(s['solver_calls'])} | {fmt(s['solver_mean_us'])} | {fmt(s['hits'])} | {fmt(s['misses'])} | {fmt(s['rss_mb'])} |")
    lines.append("")
(run / "RESULTS.md").write_text("\n".join(lines))
print("\n".join(lines))
