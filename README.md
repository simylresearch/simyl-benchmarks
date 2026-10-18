# simyl-benchmarks

Reproducible, in-process benchmarks of two single-flight caches, run and published by
[SIMYL Research](https://simylresearch.com):

| Implementation | Language | Source measured |
|---|---|---|
| `gateway_cache` | Go | `github.com/geniussportsgroup/gateway_cache/v3` **v3.1.0** (MIT) |
| `cpp-cache` | C++20 | `lrleon/cpp-cache` **5bfaf38** + `lrleon/Aleph-w` **d37658b** (MIT), fetched by commit hash |

Both implement the same concurrency protocol (at most one computation per key at any time;
concurrent requests for the same key wait for and share the result). These are **new measurements
taken in 2026 of the libraries alone, on one declared machine**. They are not the 2023 load tests of
the full gateway architecture described in
[100K requests per second](https://simylresearch.com/en/blog/simyl-blog-100k-rps/), and nothing
here is production traffic. Go results describe the Go library; C++ results describe the C++ library.
Numbers depend on hardware, power settings and load; treat them as a comparison protocol you can
re-run, not as guaranteed performance.

## Protocol

1. A request trace of 4,000,000 key indices is generated once per scenario from a fixed seed
   (`scripts/gen_trace.py`, Zipf distribution). Every implementation replays the same trace.
2. `W` workers (goroutines / `std::thread`) start at different offsets of the trace and loop over
   it. Each request calls the cache's "get or compute" operation with the key as a string.
3. The miss solver counts its calls and sleeps for the scenario's simulated backend latency.
4. Per-request latency is recorded in a log-linear histogram (16 sub-buckets per power of two,
   ≈6 % resolution); hits and misses come from the library's own counters.
5. Each run has a warm-up (not measured) and a measured period; each configuration is repeated
   3 times, alternating implementations so that both share thermal conditions. Results report
   the median of the repetitions and the min–max spread of throughput.
6. `scripts/env.sh` records CPU, memory, OS, CPU-frequency driver and governor, platform power
   profile, compiler and runtime versions and the pinned source commits next to the raw data.

Scenarios are defined in `scenarios.json` (each one states its purpose). Raw results are one JSON
object per run in `results/<run-id>/raw/results.jsonl`; `RESULTS.md` and `summary.json` in the same
folder are derived from them by `scripts/summarize.py`.

## Running it

Requirements: Linux x86-64 or arm64, Go ≥ 1.21 (the module pins `toolchain go1.24.4`, which the
`go` command downloads automatically), CMake ≥ 3.22, a C++20 compiler (GCC 13+ or Clang 16+),
Python 3.8+, and the libraries Aleph-w links against: on Debian/Ubuntu
`sudo apt install libgsl-dev libgmp-dev libmpfr-dev`. Network access is needed once, to fetch the
pinned sources.

```bash
scripts/run.sh                 # full protocol: 3 repetitions, 10 s runs -> results/<timestamp>/
scripts/run.sh my-run --quick  # 1 repetition, 3 s runs, to check the pipeline
scripts/env.sh                 # print the environment description only
```

Set `ALEPH_SRC` and `CPPCACHE_SRC` to local copies of the pinned commits to skip the downloads.
Wall time of the full protocol on the reference machine is recorded in each `RESULTS.md`.

## Reading the results

- `throughput_rps`: requests completed per second by all workers.
- `p50_us`, `p99_us`, `p999_us`, `max_us`: per-request latency percentiles in microseconds (bucket
  lower bounds, ≈6 % resolution).
- `solver_calls`: how many times the backend was actually called during the measured period. In
  single-flight caches this should stay close to the number of distinct keys that needed computing,
  regardless of how many workers asked for them.
- `hits` / `misses`: the library's own counters; their exact meaning differs slightly between
  implementations (for example, a request that waits for an in-flight computation is a hit in
  `gateway_cache`), so compare `solver_calls` across implementations, not hit ratios.
- `rss_mb`: resident memory of the process at the end of the run.

Semantics that affect the numbers: both libraries renew an entry's TTL on every hit (sliding
expiration), so a key requested at least once per TTL is never recomputed; `gateway_cache` also
launches a goroutine per request to report hits and misses to its reporter, and keeps values by
copy, while `cpp-cache` hands out `shared_ptr` values. The `hot-cold-ttl` scenario mixes hits
with recomputations of rarely requested keys.

## License and attribution

The harness and the results are MIT-licensed, © 2026 SIMYL Research S.A.S. `gateway_cache` is
published by Genius Sports Group under MIT; `cpp-cache` and `Aleph-w` are published by Leandro
Rabindranath León under MIT. This repository only downloads and measures them.
