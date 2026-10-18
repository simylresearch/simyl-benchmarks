# Results — 2026-10-18-ryzen7-pro-7840u

- CPU: AMD Ryzen 7 PRO 7840U w/ Radeon 780M Graphics (8 cores, 16 threads, L3 16 MiB (1 instance)); memory 61348416 kB; Ubuntu 24.04.5 LTS, kernel 6.8.0-146-generic.
- Power: driver amd-pstate-epp, governor powersave, EPP balance_performance, platform profile balanced, boost None, AC 1.
- Toolchain: go version go1.24.4 linux/amd64; c++ (GCC) 13.2.0; cmake version 3.28.3.
- Sources: gateway_cache github.com/geniussportsgroup/gateway_cache/v3 v3.1.0; cpp-cache 5bfaf38; Aleph-w d37658b; harness ab6988f.
- Protocol: each cell is the median of 3 runs of 3.0 s after a warm-up; percentiles come from a log-linear histogram (≈6 % resolution); throughput shows min–max across runs. Total wall time 452 s.

## cold-herd

| impl | workers | req/s (median) | min–max | p50 µs | p99 µs | p99.9 µs | max µs | solver calls | hits | misses | RSS MB |
|---|---|---|---|---|---|---|---|---|---|---|---|
| cpp-cache | 64 | 2,714,211 | 2,620,305–2,718,391 | 3.3 | 213 | 852 | 50,446 | 100 | 8,147,852 | 100 | 21.5 |
| gateway_cache | 64 | 2,312,450 | 2,310,634–2,329,708 | 0.3 | 459 | 885 | 51,016 | 100 | 6,937,657 | 100 | 56.7 |

## eviction-churn

| impl | workers | req/s (median) | min–max | p50 µs | p99 µs | p99.9 µs | max µs | solver calls | hits | misses | RSS MB |
|---|---|---|---|---|---|---|---|---|---|---|---|
| cpp-cache | 16 | 134,057 | 133,192–134,106 | 147 | 172 | 213 | 3,807 | 1,030,871 | 309,710 | 1,030,887 | 24.0 |
| gateway_cache | 16 | 19,975 | 19,834–19,994 | 1,049 | 1,180 | 1,966 | 4,487 | 153,684 | 46,082 | 153,684 | 52.7 |

## hits-throughput

| impl | workers | req/s (median) | min–max | p50 µs | p99 µs | p99.9 µs | max µs | solver calls | hits | misses | RSS MB |
|---|---|---|---|---|---|---|---|---|---|---|---|
| cpp-cache | 1 | 3,334,988 | 3,207,506–3,456,887 | 0.1 | 1.1 | 2.7 | 265 | 0.0 | 33,350,100 | 0.0 | 51.4 |
| gateway_cache | 1 | 1,770,343 | 1,711,301–1,782,996 | 0.4 | 1.9 | 4.4 | 1,023 | 437 | 17,702,987 | 437 | 124 |
| cpp-cache | 4 | 1,788,965 | 1,784,439–1,853,505 | 0.7 | 16.4 | 34.8 | 6,267 | 218 | 17,889,582 | 218 | 51.5 |
| gateway_cache | 4 | 1,522,866 | 1,484,897–1,543,046 | 0.5 | 69.6 | 139 | 5,312 | 1,109 | 15,227,566 | 1,109 | 141 |
| cpp-cache | 8 | 1,814,716 | 1,726,606–1,926,104 | 2.0 | 26.6 | 61.4 | 7,471 | 310 | 18,146,975 | 310 | 51.6 |
| gateway_cache | 8 | 1,489,638 | 1,487,556–1,542,091 | 0.5 | 147 | 311 | 8,684 | 1,226 | 14,895,008 | 1,226 | 135 |
| cpp-cache | 16 | 1,751,786 | 1,695,201–1,763,021 | 4.1 | 57.3 | 127 | 9,863 | 650 | 17,517,419 | 650 | 51.7 |
| gateway_cache | 16 | 1,525,590 | 1,504,512–1,563,779 | 0.5 | 328 | 623 | 5,936 | 997 | 15,254,997 | 997 | 141 |

## hot-cold-ttl

| impl | workers | req/s (median) | min–max | p50 µs | p99 µs | p99.9 µs | max µs | solver calls | hits | misses | RSS MB |
|---|---|---|---|---|---|---|---|---|---|---|---|
| cpp-cache | 16 | 3,278,038 | 3,169,457–3,294,904 | 2.0 | 38.9 | 94.2 | 14,713 | 0.0 | 32,780,609 | 0.0 | 21.2 |
| gateway_cache | 16 | 2,377,348 | 2,279,551–2,405,683 | 0.4 | 139 | 279 | 6,167 | 0.0 | 23,773,650 | 0.0 | 65.5 |
