#!/usr/bin/env bash
# Runs every scenario of scenarios.json for both implementations and writes
# results/<run-id>/{environment.json,raw/results.jsonl,RESULTS.md,summary.json}.
# Usage: scripts/run.sh [run-id] [--quick]   (--quick: 1 repetition, 3 s runs, for checking the pipeline)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
RUN_ID=${1:-$(date -u +%Y-%m-%dT%H%M%SZ)}
QUICK=${2:-}
OUT="$ROOT/results/$RUN_ID"
mkdir -p "$OUT/raw" build/traces

echo "== building"
(cd go && go build -o ../build/cachebench-go ./cmd/cachebench)
cmake -S cpp -B build/cpp -DCMAKE_BUILD_TYPE=Release ${ALEPH_SRC:+-DALEPH_SRC="$ALEPH_SRC"} ${CPPCACHE_SRC:+-DCPPCACHE_SRC="$CPPCACHE_SRC"} > build/cmake-configure.log
cmake --build build/cpp -j"$(nproc)" --target cachebench-cpp > build/cmake-build.log

echo "== environment -> $OUT/environment.json"
scripts/env.sh > "$OUT/environment.json"

T0=$(date +%s)
python3 scripts/plan.py scenarios.json ${QUICK:+--quick} | while IFS='|' read -r name keys zipf capacity ttl lat workers rep warmup duration; do
  trace="build/traces/${name}-k${keys}-z${zipf}.u32"
  if [ ! -f "$trace" ]; then
    python3 scripts/gen_trace.py --keys "$keys" --requests "$(python3 -c "import json;print(json.load(open('scenarios.json'))['trace_requests'])")" --zipf "$zipf" --seed "$(python3 -c "import json;print(json.load(open('scenarios.json'))['seed'])")" --out "$trace"
  fi
  for impl in go cpp; do
    bin="build/cachebench-go"; [ "$impl" = cpp ] && bin="build/cpp/cachebench-cpp"
    echo "-- $name workers=$workers rep=$rep impl=$impl"
    "$bin" -trace "$trace" -keys "$keys" -workers "$workers" -capacity "$capacity" -ttl "$ttl" \
      -solver-latency "$lat" -warmup "$warmup" -duration "$duration" -scenario "$name" -out "$OUT/raw/results.jsonl"
  done
done
T1=$(date +%s)
echo "== total wall time: $((T1 - T0)) s"
python3 scripts/summarize.py "$OUT" --wall-seconds "$((T1 - T0))"
echo "== done: $OUT/RESULTS.md"
